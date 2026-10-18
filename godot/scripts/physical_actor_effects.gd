class_name CyberPhysicalActorEffects
extends RefCounted

# Exclusive cellular-owner consumer for value-only physical usable requests.
# Recoil belongs to the main-thread actor rig; these receipts report only the
# cells actually changed through the existing adapter, including refusals.
const MAX_ACTORS: int = 8
const MAX_REQUESTS: int = 8
const MAX_WRITES: int = 64
const MAX_READS: int = 1024
const MAX_REACH: float = 32.0
const MAX_TRACE_CELLS: int = 100
const WORLD_LIMIT: int = 1024
const DEPOSIT_MATERIALS: Array[int] = [2] # Authored Sand depositor.
const REQUEST_KEYS: Array[String] = [
	"actor_slot", "epoch", "sequence", "kind", "source", "origin", "source_body_id",
	"source_part", "radius", "strength", "material", "pattern",
]

var _epoch: int = -1
var _sequences: PackedInt64Array = PackedInt64Array()
var _effect := CyberActorRigEffects.new()


class EffectWorld extends RefCounted:
	var target: Object
	var reads: int = 0
	var attempted_writes: int = 0
	var changed_cells: int = 0
	var exhausted: bool = false
	var changed_positions: Dictionary = {}

	func material_at(x: int, y: int) -> int:
		if reads >= MAX_READS:
			exhausted = true
			return 1
		reads += 1
		return int(target.material_at(x, y))

	func rigid_body_id_at(x: int, y: int) -> int:
		if reads >= MAX_READS:
			exhausted = true
			return -1
		reads += 1
		return int(target.rigid_body_id_at(x, y))

	func has_failed() -> bool:
		return target.has_method(&"has_failed") and bool(target.has_failed())

	func emit_disc(x: int, y: int, radius: int, material: int) -> void:
		if radius != 0 or attempted_writes >= MAX_WRITES or reads + 2 > MAX_READS:
			exhausted = true
			return
		if x < 0 or y < 0 or x >= WORLD_LIMIT or y >= WORLD_LIMIT or has_failed():
			return
		var before: int = material_at(x, y)
		if before == material:
			return
		attempted_writes += 1
		target.emit_disc(x, y, 0, material)
		if material_at(x, y) == material:
			changed_positions[Vector2i(x, y)] = true
			changed_cells = changed_positions.size()


func _init() -> void:
	reset()


func reset(epoch: int = -1) -> void:
	_epoch = epoch
	_sequences.resize(MAX_ACTORS)
	_sequences.fill(-1)
	_effect.clear()


func apply(world: Object, requests: Array, epoch: int) -> Array:
	var receipts: Array = []
	if epoch < 0 or epoch < _epoch:
		return [_receipt({}, epoch, false, "epoch", 0)]
	if epoch != _epoch:
		reset(epoch)
	if requests.size() > MAX_REQUESTS:
		return [_receipt({}, epoch, false, "request_capacity", 0)]
	if world == null or not world.has_method(&"material_at") \
		or not world.has_method(&"rigid_body_id_at") or not world.has_method(&"emit_disc"):
		return [_receipt({}, epoch, false, "adapter", 0)]
	if world.has_method(&"has_failed") and bool(world.has_failed()):
		return [_receipt({}, epoch, false, "world_failed", 0)]
	var admitted_actors: int = 0
	for value: Variant in requests:
		if typeof(value) != TYPE_DICTIONARY:
			receipts.append(_receipt({}, epoch, false, "request_type", 0))
			continue
		var request: Dictionary = value
		var error: String = _request_error(request, epoch)
		if not error.is_empty():
			receipts.append(_receipt(request, epoch, false, error, 0))
			continue
		var actor: int = request["actor_slot"]
		var sequence: int = request["sequence"]
		if sequence <= _sequences[actor]:
			receipts.append(_receipt(request, epoch, false, "sequence", 0))
			continue
		if admitted_actors & (1 << actor):
			receipts.append(_receipt(request, epoch, false, "actor_budget", 0))
			continue
		# An admitted but obstructed attempt is consumed. Removing the obstruction
		# cannot make a delayed duplicate produce an unrequested later effect.
		_sequences[actor] = sequence
		admitted_actors |= 1 << actor
		var proxy := EffectWorld.new()
		proxy.target = world
		var source: Vector2 = request["source"]
		var origin: Vector2 = request["origin"]
		var source_id: int = request["source_body_id"]
		var source_cell := Vector2i(floori(source.x), floori(source.y))
		var source_mask: int = proxy.rigid_body_id_at(source_cell.x, source_cell.y)
		if source_mask != 0 and source_mask != source_id:
			receipts.append(_receipt(request, epoch, true, "source_identity", 0))
			continue
		if not _path_clear(proxy, source, origin, source_id):
			receipts.append(_receipt(request, epoch, true, "blocked", 0))
			continue
		var power: float = float(request.get("strength", 1.0))
		if power <= 0.0:
			receipts.append(_receipt(request, epoch, true, "zero_strength", 0))
			continue
		var kind: String = str(request["kind"])
		var radius: int = request["radius"]
		if kind == "deposit":
			_deposit(proxy, origin, radius, int(request["material"]), false)
		else:
			_effect.clear()
			_effect.apply(proxy, CyberActorRigEffects.DIG if kind == "dig" \
				else CyberActorRigEffects.BLAST, origin, radius, power)
			if kind == "blast" and str(request.get("pattern", "disc")) == "rocket_charge":
				# Existing blast first supplies its protected Fire centre; a sparse
				# radius-at-most-two Gunpowder ring may occupy only empty cells.
				var centre := Vector2i(floori(origin.x), floori(origin.y))
				if proxy.material_at(centre.x, centre.y) == 6:
					_deposit(proxy, origin, mini(radius, 2), 26, true)
		var receipt: Dictionary = _receipt(request, epoch, true,
			"read_or_write_budget" if proxy.exhausted else "", proxy.changed_cells)
		receipt["attempted_writes"] = proxy.attempted_writes
		receipt["reads"] = proxy.reads
		receipts.append(receipt)
	return receipts


func _request_error(request: Dictionary, epoch: int) -> String:
	if request.size() > REQUEST_KEYS.size():
		return "request_fields"
	for key: Variant in request:
		if (typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME) \
			or str(key) not in REQUEST_KEYS:
			return "request_fields"
	for key: String in ["actor_slot", "epoch", "sequence", "source_body_id", "radius"]:
		if typeof(request.get(key)) != TYPE_INT:
			return "integer_field"
	if request["actor_slot"] < 0 or request["actor_slot"] >= MAX_ACTORS:
		return "actor_slot"
	if request["epoch"] != epoch:
		return "epoch"
	if request["sequence"] < 0:
		return "sequence"
	if request["source_body_id"] < 1 or request["source_body_id"] > CyberRigidBodyCoupling.MAX_BODIES:
		return "source_identity"
	if request.has("source_part") and (typeof(request["source_part"]) != TYPE_INT \
		or request["source_part"] < 0 or request["source_part"] > 7):
		return "source_part"
	if request["radius"] < 1 or request["radius"] > CyberActorRigEffects.MAX_RADIUS:
		return "radius"
	for key: String in ["source", "origin"]:
		if typeof(request.get(key)) != TYPE_VECTOR2:
			return "position_type"
		var point: Vector2 = request[key]
		if not point.is_finite() or point.x < 0.0 or point.y < 0.0 \
			or point.x >= WORLD_LIMIT or point.y >= WORLD_LIMIT:
			return "position"
	var source: Vector2 = request["source"]
	var origin: Vector2 = request["origin"]
	if source.distance_squared_to(origin) > MAX_REACH * MAX_REACH:
		return "reach"
	var strength: Variant = request.get("strength", 1.0)
	if (typeof(strength) != TYPE_FLOAT and typeof(strength) != TYPE_INT) \
		or not is_finite(float(strength)) or float(strength) < 0.0 or float(strength) > 1.0:
		return "strength"
	if typeof(request.get("kind")) != TYPE_STRING and typeof(request.get("kind")) != TYPE_STRING_NAME:
		return "kind"
	var kind: String = str(request["kind"])
	if kind not in ["dig", "blast", "deposit"]:
		return "kind"
	var pattern: Variant = request.get("pattern", "disc")
	if (typeof(pattern) != TYPE_STRING and typeof(pattern) != TYPE_STRING_NAME) \
		or str(pattern) not in ["disc", "rocket_charge"] \
		or (str(pattern) == "rocket_charge" and kind != "blast"):
		return "pattern"
	if kind == "deposit" and (typeof(request.get("material")) != TYPE_INT \
		or int(request["material"]) not in DEPOSIT_MATERIALS):
		return "material"
	if request.has("material") and typeof(request["material"]) != TYPE_INT:
		return "material"
	return ""


func _receipt(request: Dictionary, epoch: int, consumed: bool, reason: String, changed: int) -> Dictionary:
	return {
		"actor_slot": request.get("actor_slot", -1) if typeof(request.get("actor_slot")) == TYPE_INT else -1,
		"epoch": epoch,
		"sequence": request.get("sequence", -1) if typeof(request.get("sequence")) == TYPE_INT else -1,
		"consumed": consumed,
		"status": "applied" if changed > 0 else ("no_change" if consumed and reason.is_empty() else "refused"),
		"reason": reason,
		"changed_cells": changed,
		"attempted_writes": 0,
		"reads": 0,
	}


func _cell_clear(proxy: EffectWorld, cell: Vector2i, source_id: int, own_prefix: bool) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= WORLD_LIMIT or cell.y >= WORLD_LIMIT:
		return false
	var mask: int = proxy.rigid_body_id_at(cell.x, cell.y)
	if mask != 0:
		return own_prefix and mask == source_id
	return not CyberActorRigEffects.protected_material(proxy.material_at(cell.x, cell.y))


func _path_clear(proxy: EffectWorld, source: Vector2, target: Vector2, source_id: int) -> bool:
	var cell := Vector2i(floori(source.x), floori(source.y))
	var end := Vector2i(floori(target.x), floori(target.y))
	var own_prefix: bool = source_id > 0 and proxy.rigid_body_id_at(cell.x, cell.y) == source_id
	if not _cell_clear(proxy, cell, source_id, own_prefix):
		return false
	var ray: Vector2 = target - source
	var step := Vector2i(signi(end.x - cell.x), signi(end.y - cell.y))
	var delta_x: float = 1.0 / absf(ray.x) if step.x != 0 else INF
	var delta_y: float = 1.0 / absf(ray.y) if step.y != 0 else INF
	var next_x: float = ((float(cell.x + 1) - source.x) if step.x > 0 \
		else (source.x - float(cell.x))) * delta_x if step.x != 0 else INF
	var next_y: float = ((float(cell.y + 1) - source.y) if step.y > 0 \
		else (source.y - float(cell.y))) * delta_y if step.y != 0 else INF
	for _index: int in range(MAX_TRACE_CELLS):
		if cell == end:
			return true
		if absf(next_x - next_y) < 0.000001:
			# Corner crossings touch both side cells as well as the diagonal.
			if not _cell_clear(proxy, cell + Vector2i(step.x, 0), source_id, own_prefix) \
				or not _cell_clear(proxy, cell + Vector2i(0, step.y), source_id, own_prefix):
				return false
			cell += step
			next_x += delta_x
			next_y += delta_y
		elif next_x < next_y:
			cell.x += step.x
			next_x += delta_x
		else:
			cell.y += step.y
			next_y += delta_y
		if not _cell_clear(proxy, cell, source_id, own_prefix):
			return false
		if proxy.rigid_body_id_at(cell.x, cell.y) != source_id:
			own_prefix = false
	return false


func _deposit(proxy: EffectWorld, target: Vector2, radius: int, material: int, ring: bool) -> void:
	var centre := Vector2i(floori(target.x), floori(target.y))
	var centre_point: Vector2 = Vector2(centre) + Vector2(0.5, 0.5)
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var squared: int = x * x + y * y
			if squared > radius * radius or (ring and squared < maxi(1, radius * radius - 1)):
				continue
			if proxy.exhausted:
				return
			var cell: Vector2i = centre + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= WORLD_LIMIT or cell.y >= WORLD_LIMIT:
				continue
			if proxy.material_at(cell.x, cell.y) != 0 or proxy.rigid_body_id_at(cell.x, cell.y) != 0:
				continue
			if not _path_clear(proxy, centre_point, Vector2(cell) + Vector2(0.5, 0.5), 0):
				continue
			proxy.emit_disc(cell.x, cell.y, 0, material)
