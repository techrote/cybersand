class_name CyberPhysicalUsableRuntime
extends RefCounted

# The only owner of physical-equipment cellular effects. No scene node, body RID,
# controller or main-thread callback crosses this copied-value boundary.
const Catalog = preload("res://scripts/usable_catalog.gd")
const MAX_ACTORS: int = 8
const MAX_REQUESTS: int = 8
const MAX_DEVICES: int = 16
const IDENTITY_KEYS: Array[String] = ["run_id", "epoch", "actor_id", "generation",
	"equipment_epoch", "instance_id", "usable_index", "body_id"]
const REQUEST_KEYS: Array[String] = ["version", "run_id", "epoch", "actor_id", "generation",
	"equipment_epoch", "instance_id", "usable_index", "body_id", "sequence", "request_id",
	"operation", "power"]

var _engine := PhysicalEngine.new()


class PhysicalEngine extends "res://scripts/usable_runtime.gd":
	var epoch: int = -1
	var run_id: String = ""
	var frame: Dictionary = {}
	var receipts: Dictionary = {}
	var last_sequences: PackedInt64Array = PackedInt64Array()
	var body_owners: Dictionary = {}
	var device_history: Dictionary = {} # At most eight actors × ten catalogue processors.
	var active_world: Object
	var last_error: String = ""
	var source_diagnostic: Dictionary = {}

	func reset_physical(next_epoch: int = -1) -> void:
		configure(MAX_ACTORS)
		_reset_budget()
		epoch = next_epoch
		run_id = ""
		frame = {}
		receipts.clear()
		body_owners.clear()
		device_history.clear()
		last_sequences.resize(MAX_ACTORS)
		last_sequences.fill(-1)
		last_error = ""
		source_diagnostic.clear()

	func advance_physical(delta: float, world: Object, next_frame: Dictionary, requests: Array) -> void:
		var error: String = CyberPhysicalUsableRuntime.frame_error(next_frame)
		if not error.is_empty():
			last_error = error
			return
		if int(next_frame.epoch) < epoch:
			last_error = "epoch"
			return
		if int(next_frame.epoch) != epoch:
			reset_physical(int(next_frame.epoch))
		if not run_id.is_empty() and str(next_frame.run_id) != run_id:
			last_error = "run_id"
			return
		if not frame.is_empty() and int(next_frame.tick) < int(frame.tick):
			last_error = "frame_tick"
			return
		if not frame.is_empty():
			var transition_error: String = CyberPhysicalUsableRuntime.frame_transition_error(frame, next_frame)
			if not transition_error.is_empty():
				last_error = transition_error
				return
		if not is_finite(delta) or delta <= 0.0 or requests.size() > MAX_ACTORS:
			last_error = "delta_or_capacity"
			return
		if world == null or not world.has_method(&"material_at") \
			or not world.has_method(&"rigid_body_id_at") or not world.has_method(&"emit_disc") \
			or (world.has_method(&"has_failed") and bool(world.has_failed())):
			last_error = "world_unavailable"
			return
		run_id = str(next_frame.run_id)
		frame = next_frame.duplicate(true)
		last_error = ""
		_reset_budget()
		active_world = world
		body_owners.clear()
		_centres.resize(MAX_ACTORS)
		for actor: Dictionary in frame.actors:
			var owner: int = int(actor.actor_id)
			_centres[owner] = actor.muzzle
			_actors[owner].usable_index = actor.usable_index
			_actors[owner].position = actor.position
			for part: Dictionary in actor.parts:
				body_owners[int(part.body_id)] = owner
			if int(actor.body_id) > 0:
				body_owners[int(actor.body_id)] = owner
		for device: Dictionary in frame.devices:
			body_owners[int(device.body_id)] = int(device.actor_id)
		_sync_devices()
		if bool(frame.suspended):
			for request: Variant in requests:
				if request is Dictionary:
					_store_receipt(request, false, false, "suspended", 0)
			active_world = null
			return
		_tick += 1
		var dt: float = minf(delta, MAX_DELTA)
		_age_effects(dt)
		# Committed payloads and admitted deployed objects are autonomous owner
		# state. Releasing held input does not silently delete a launched fuse.
		_step_projectiles(dt, world)
		_step_objects(dt, world)
		for index: int in range(MAX_ACTORS):
			_actors[index].charge = minf(MAX_CHARGE, float(_actors[index].charge) + CHARGE_PER_SECOND * dt)
			_actors[index].cooldown = maxf(0.0, float(_actors[index].cooldown) - dt)
		var seen: Dictionary = {}
		for request: Variant in requests:
			if not request is Dictionary:
				last_error = "request_type"
				continue
			var reason: String = CyberPhysicalUsableRuntime.request_error(request, frame)
			var owner: int = int(request.get("actor_id", -1)) if request.get("actor_id") is int else -1
			if reason.is_empty() and seen.has(owner):
				reason = "actor_budget"
			if reason.is_empty() and int(request.sequence) <= last_sequences[owner]:
				reason = "sequence"
			if not reason.is_empty():
				_store_receipt(request, false, false, reason, 0)
				continue
			seen[owner] = true
			last_sequences[owner] = int(request.sequence)
			_execute(request, world)
		_observe_local(world)
		active_world = null

	func _observe_local(world: Object) -> void:
		# A small contiguous native patch is sufficient for choosing nearby
		# work. Effect/recipe work has priority over optional observation reads.
		for pose: Dictionary in frame.actors:
			var owner: int = int(pose.actor_id)
			_actors[owner]["cell_patch"] = {}
			if read_count_last + 81 > MAX_READS:
				continue
			var center: Vector2 = Vector2(pose.muzzle) + Vector2(pose.direction).normalized() * 6.0
			var origin := Vector2i(center.floor()) - Vector2i(4, 4)
			var materials := PackedByteArray()
			materials.resize(81)
			for index: int in range(81):
				var point := origin + Vector2i(index % 9, int(index / 9))
				materials[index] = clampi(_read(point, world), 0, 255)
			_actors[owner]["cell_patch"] = {"origin": origin, "size": Vector2i(9, 9),
				"materials": materials, "tick": _tick, "frame_tick": int(frame.tick)}

	func _actor_frame(owner: int) -> Dictionary:
		return CyberPhysicalUsableRuntime.actor_row(frame, owner)

	func _execute(request: Dictionary, world: Object) -> void:
		var owner: int = int(request.actor_id)
		var actor: Dictionary = _actors[owner]
		var pose: Dictionary = _actor_frame(owner)
		var definition: Dictionary = Catalog.entry(int(request.usable_index))
		var operation: String = str(request.operation)
		var category: StringName = StringName(str(definition.category))
		var writes_before: int = write_count_last
		source_diagnostic.clear()
		var reason: String = ""
		if operation == "alternate" and category == Catalog.CATEGORY_PROJECTILE:
			# A command to an already committed owned payload has no barrel
			# emission, launch charge or launch cooldown. Preserve U16/U17/U19's
			# original early-activation semantics, including a blocked muzzle.
			reason = _alternate(owner, definition, world) if str(pose.state) == "held" else "not_held"
		elif float(request.power) <= 0.0:
			reason = "zero_power"
		elif float(actor.cooldown) > 0.00001:
			reason = "cooldown"
		elif operation == "deploy":
			if category != Catalog.CATEGORY_OBJECT:
				reason = "not_processor"
			elif str(pose.state) not in ["fixed", "settled"]:
				reason = "not_settled"
			elif float(actor.charge) + 0.0001 < float(definition.cost):
				reason = "no-charge"
			else:
				reason = _accept_deployment(request, pose, definition, world)
		elif category == Catalog.CATEGORY_OBJECT:
			# Pickup/reattach belongs to the physical owner and must be nearby.
			# Never route the sampled runtime's distant logical retrieval here.
			reason = "physical_deploy_required"
		elif str(pose.state) != "held":
			reason = "not_held"
		elif not _source_clear(pose, world):
			reason = "source_blocked"
		elif float(actor.charge) + 0.0001 < float(definition.cost):
			reason = "no-charge"
		elif category == Catalog.CATEGORY_TOOL:
			reason = _apply_tool(owner, definition, Vector2(pose.direction).normalized(),
				float(request.power) * (0.35 if operation == "alternate" else 1.0), world)
		else:
			reason = _launch(owner, definition, Vector2(pose.direction).normalized(), float(request.power), world)
		var accepted: bool = reason in ["applied", "launched", "deployed", "activated"]
		if reason in ["applied", "launched", "deployed"]:
			actor.charge = maxf(0.0, float(actor.charge) - float(definition.cost))
			actor.cooldown = float(definition.cooldown)
		actor.last_result = reason
		_actors[owner] = actor
		_store_receipt(request, accepted, true, reason, write_count_last - writes_before)

	func _store_receipt(request: Dictionary, accepted: bool, consumed: bool, reason: String, changed: int) -> void:
		var receipt: Dictionary = CyberPhysicalUsableRuntime.receipt(request, accepted, consumed, reason)
		var owner: int = int(receipt.actor_id)
		receipt.changed_cells = changed
		receipt["tick"] = _tick
		if reason == "source_blocked":
			receipt["source_diagnostic"] = source_diagnostic.duplicate(true)
		if owner >= 0 and owner < _actors.size():
			receipt.charge = float(_actors[owner].charge)
			receipt.cooldown = float(_actors[owner].cooldown)
			receipts[owner] = receipt
		else:
			last_error = reason

	func _accept_deployment(request: Dictionary, pose: Dictionary, definition: Dictionary, world: Object) -> String:
		var owner: int = int(request.actor_id)
		if _objects.size() >= MAX_OBJECTS or _owned_object_count(owner) >= MAX_OBJECTS_PER_ACTOR:
			return "capacity"
		var key: String = _device_key(pose)
		for object: Dictionary in _objects:
			if str(object.physical_key) == key:
				return "already_deployed"
		var history: Dictionary = device_history.get(_history_key(pose), {})
		if not history.is_empty():
			if int(pose.equipment_epoch) <= int(history.equipment_epoch):
				return "retired_device"
			if int(history.stock) <= 0 or float(history.age) >= float(history.lifetime):
				return "exhausted_device"
		var published: Dictionary = {}
		for device: Dictionary in frame.devices:
			if _device_key(device) == key and int(device.body_id) == int(pose.body_id):
				published = device
				break
		if published.is_empty() or str(published.state) not in ["fixed", "settled", "deployed"]:
			return "device_missing"
		if _body_at(Vector2i(Vector2(pose.position).floor())) != int(pose.body_id):
			return "source_identity"
		var obj: Dictionary = {
			"entity_id": _allocate_id(), "owner": owner, "actor_id": owner,
			"usable_index": int(request.usable_index), "instance_id": str(request.instance_id),
			"equipment_epoch": int(request.equipment_epoch), "physical_key": key,
			"body_id": int(pose.body_id), "position": pose.position, "rotation": pose.rotation,
			"half_extents": pose.half_extents, "age": 0.0,
			"lifetime": float(definition.get("lifetime", 45.0)), "cooldown": 0.0,
			"stock": int(definition.get("stock", 16)), "cycles": 0,
			"status": "waiting", "color": definition.color,
		}
		for field: String in ["age", "stock", "cycles", "cooldown"]:
			if history.has(field):
				obj[field] = history[field]
		var seen_ports: Dictionary = {}
		for output: bool in [false, true]:
			for port: Vector2i in _object_ports(obj, output):
				if seen_ports.has(port) or not _inside_world(port) or _body_at(port) != 0:
					return "blocked_port"
				seen_ports[port] = true
		_objects.append(obj)
		_remember_device(obj)
		_add_effect(pose.position, definition.color, 3.0, "deploy")
		return "deployed"

	func _sync_devices() -> void:
		for index: int in range(_objects.size() - 1, -1, -1):
			var obj: Dictionary = _objects[index]
			var pose: Dictionary = {}
			for device: Dictionary in frame.devices:
				if _device_key(device) == str(obj.physical_key) and int(device.body_id) == int(obj.body_id) \
					and int(device.usable_index) == int(obj.usable_index):
					pose = device
					break
			if pose.is_empty() or str(pose.state) not in ["settled", "fixed", "deployed"]:
				_remember_device(obj)
				_objects.remove_at(index)
				continue
			obj.position = pose.position
			obj.rotation = pose.rotation
			obj.half_extents = pose.half_extents
			_objects[index] = obj

	func _step_objects(dt: float, world) -> void:
		# Keep exhausted physical objects visible and inert until the body owner
		# picks up or retires them. This also forbids an old frame refilling stock.
		for index: int in range(_objects.size()):
			var obj: Dictionary = _objects[index]
			obj.age = float(obj.age) + dt
			obj.cooldown = maxf(0.0, float(obj.cooldown) - dt)
			if float(obj.age) >= float(obj.lifetime) or int(obj.stock) <= 0:
				obj.status = "expired" if float(obj.age) >= float(obj.lifetime) else "exhausted"
			elif _body_at(Vector2i(Vector2(obj.position).floor())) != int(obj.body_id):
				obj.status = "body_missing"
			elif float(obj.cooldown) <= 0.0:
				var definition: Dictionary = Catalog.entry(int(obj.usable_index))
				obj.status = _object_cycle(obj, definition, world)
				if str(obj.status) == "processed":
					obj.stock = int(obj.stock) - 1
					obj.cycles = int(obj.cycles) + 1
					obj.cooldown = float(definition.get("cooldown", 0.35))
			_objects[index] = obj
			_remember_device(obj)

	func _device_key(value: Dictionary) -> String:
		return "%d:%s:%d" % [int(value.actor_id), str(value.instance_id), int(value.equipment_epoch)]

	func _history_key(value: Dictionary) -> String:
		return "%d:%d" % [int(value.actor_id), int(value.usable_index)]

	func _remember_device(obj: Dictionary) -> void:
		var saved: Dictionary = {}
		for field: String in ["equipment_epoch", "stock", "age", "lifetime", "cycles", "cooldown"]:
			saved[field] = obj[field]
		device_history[_history_key(obj)] = saved

	func _projectile_muzzle(owner: int, _aim: Vector2) -> Vector2:
		return _centres[owner]

	func _object_ports(obj: Dictionary, output: bool) -> Array[Vector2i]:
		var center: Vector2 = obj.position
		var offset: float = ceilf(Vector2(obj.half_extents).x + 2.0) * (1.0 if output else -1.0)
		var angle: float = float(obj.rotation)
		return [Vector2i((center + Vector2(offset, -1).rotated(angle)).round()),
			Vector2i((center + Vector2(offset, 1).rotated(angle)).round())]

	func _body_at(point: Vector2i) -> int:
		if read_count_last >= MAX_READS or active_world == null:
			refused_reads_last += 1
			return -1
		if not _inside_world(point):
			return -1
		read_count_last += 1
		return int(active_world.rigid_body_id_at(point.x, point.y))

	func _source_clear(pose: Dictionary, world: Object) -> bool:
		var source: Vector2 = pose.position
		var target: Vector2 = pose.muzzle
		var source_id: int = int(pose.body_id)
		var owner: int = int(pose.actor_id)
		if source.distance_squared_to(target) > 64.0 * 64.0:
			return false
		var cell := Vector2i(source.floor())
		var finish := Vector2i(target.floor())
		var source_mask: int = _body_at(cell)
		source_diagnostic = {"source_cell": cell, "muzzle_cell": finish,
			"expected_body_id": source_id, "source_mask": source_mask}
		# Jointed parts can overlap at native cell resolution. Another own part's
		# mask is an allowed alias only inside the held source's exact oriented
		# footprint. This cannot exempt a separately occluding own limb.
		if source_mask != source_id and (int(body_owners.get(source_mask, -1)) != owner \
			or not _inside_source_footprint(cell, pose)):
			source_diagnostic["reason"] = "source_identity"
			return false
		var own_prefix: bool = true
		var ray: Vector2 = target - source
		var direction := Vector2i(signi(finish.x - cell.x), signi(finish.y - cell.y))
		var dx: float = 1.0 / absf(ray.x) if direction.x != 0 else INF
		var dy: float = 1.0 / absf(ray.y) if direction.y != 0 else INF
		var nx: float = (float(cell.x + 1) - source.x if direction.x > 0 else source.x - float(cell.x)) * dx if direction.x != 0 else INF
		var ny: float = (float(cell.y + 1) - source.y if direction.y > 0 else source.y - float(cell.y)) * dy if direction.y != 0 else INF
		for _sample: int in range(128):
			if cell == finish:
				var free: bool = _body_at(cell) == 0 and _read(cell, world) == EMPTY
				if not free:
					source_diagnostic["reason"] = "muzzle_occupied"
				return free
			if absf(nx - ny) < 0.000001:
				for side: Vector2i in [cell + Vector2i(direction.x, 0), cell + Vector2i(0, direction.y)]:
					if not _source_cell_clear(side, pose, own_prefix, world):
						return false
				cell += direction
				nx += dx
				ny += dy
			elif nx < ny:
				cell.x += direction.x
				nx += dx
			else:
				cell.y += direction.y
				ny += dy
			if not _source_cell_clear(cell, pose, own_prefix, world):
				return false
			if _body_at(cell) == 0:
				own_prefix = false
		return false

	func _inside_source_footprint(point: Vector2i, pose: Dictionary) -> bool:
		var local: Vector2 = (Vector2(point) + Vector2(0.5, 0.5) - Vector2(pose.position)).rotated(-float(pose.rotation))
		var half: Vector2 = pose.half_extents
		return absf(local.x) <= half.x and absf(local.y) <= half.y

	func _source_cell_clear(point: Vector2i, pose: Dictionary, own_prefix: bool, world: Object) -> bool:
		var body: int = _body_at(point)
		if body != 0:
			var own: bool = own_prefix and (body == int(pose.body_id) \
				or (int(body_owners.get(body, -1)) == int(pose.actor_id) and _inside_source_footprint(point, pose)))
			if not own:
				source_diagnostic.merge({"reason": "body_occlusion", "blocked_cell": point, "blocked_body_id": body}, true)
			return own
		var material: int = _read(point, world)
		if material != EMPTY:
			source_diagnostic.merge({"reason": "material_occlusion", "blocked_cell": point, "blocked_material": material}, true)
		return material == EMPTY

	func _inside_any_actor(point: Vector2) -> bool:
		return _body_at(Vector2i(point.floor())) != 0

	func _inside_foreign_actor(point: Vector2, owner: int) -> int:
		var body: int = _body_at(Vector2i(point.floor()))
		var target: int = int(body_owners.get(body, -1))
		return target if target != owner else -1

	func _first_actor_segment_hit(_start: Vector2, _finish: Vector2, _owner: int) -> int:
		# Native composed collision determines the first contact, including walls
		# in front of actors and empty space between articulated parts.
		return -1

	func _trace_contact(start: Vector2, finish: Vector2, world) -> Dictionary:
		var result: Dictionary = super._trace_contact(start, finish, world)
		if bool(result.get("hit", false)):
			result["body_id"] = _body_at(result.point)
		return result

	func _impact_projectile(index: int, projectile: Dictionary, definition: Dictionary, contact: Dictionary, world) -> bool:
		var body: int = int(contact.get("body_id", 0))
		var target: int = int(body_owners.get(body, -1))
		if body > 0 and target >= 0 and target != int(projectile.owner):
			_record_hit(projectile, target)
			if not _hits_last.is_empty():
				_hits_last[-1]["target_body_id"] = body
			_projectiles.remove_at(index)
			return false
		return super._impact_projectile(index, projectile, definition, contact, world)

	func _write_read_cost() -> int:
		return 3

	func _write(point: Vector2i, material: int, world) -> bool:
		if write_count_last >= MAX_WRITES or read_count_last + _write_read_cost() > MAX_READS \
			or not _inside_world(point):
			refused_writes_last += 1
			return false
		if _body_at(point) != 0:
			return false
		var before: int = _read(point, world)
		if before == -2 or before == material or before == WALL:
			return false
		world.emit_disc(point.x, point.y, 0, material)
		if _read(point, world) != material:
			return false
		write_count_last += 1
		if before != EMPTY:
			sink_slots_last += 1
		if material != EMPTY:
			source_slots_last += 1
		return true

	func physical_snapshot() -> Dictionary:
		var result: Dictionary = super.snapshot()
		var actors: Array = []
		for pose: Dictionary in frame.get("actors", []):
			var actor: Dictionary = _actors[int(pose.actor_id)].duplicate(true)
			for key: String in CyberPhysicalUsableRuntime.IDENTITY_KEYS:
				actor[key] = frame.get(key) if key in ["run_id", "epoch"] else pose.get(key)
			actor["state"] = pose.state
			actor["ready"] = not bool(frame.get("suspended", true)) and bool(pose.active) \
				and str(pose.state) == "held" and int(pose.usable_index) >= 0 and float(actor.cooldown) <= 0.00001 \
				and float(actor.charge) >= float(Catalog.entry(int(pose.usable_index)).get("cost", 0.0))
			actors.append(actor)
		result.actors = actors
		result.actor_count = actors.size()
		result["epoch"] = epoch
		result["run_id"] = run_id
		result["frame_tick"] = int(frame.get("tick", -1))
		result["suspended"] = bool(frame.get("suspended", true))
		result["receipts"] = receipts.values().duplicate(true)
		result["last_error"] = last_error
		result["physical"] = true
		return result


func _init() -> void:
	reset()


func reset(epoch: int = -1) -> void:
	_engine.reset_physical(epoch)


func step(delta: float, world: Object, frame: Dictionary, requests: Array = []) -> Dictionary:
	_engine.advance_physical(delta, world, frame, requests)
	return snapshot()


func snapshot() -> Dictionary:
	return _engine.physical_snapshot()


static func actor_row(frame: Dictionary, actor_id: int) -> Dictionary:
	for row: Variant in frame.get("actors", []):
		if row is Dictionary and row.get("actor_id") is int and int(row.actor_id) == actor_id:
			return row
	return {}


static func frame_error(frame: Dictionary) -> String:
	if not _allowed_keys(frame, ["version", "run_id", "epoch", "tick", "suspended", "actors", "devices"]):
		return "frame_fields"
	if frame.get("version") != 1 or not frame.get("epoch") is int or int(frame.epoch) <= 0 \
		or not frame.get("tick") is int or int(frame.tick) < 0:
		return "frame_identity"
	if not frame.get("run_id") is String or str(frame.run_id).is_empty() or str(frame.run_id).length() > 128:
		return "run_id"
	if not frame.get("suspended") is bool or not frame.get("actors") is Array \
		or frame.actors.size() > MAX_ACTORS or not frame.get("devices") is Array \
		or frame.devices.size() > MAX_DEVICES:
		return "frame_capacity"
	var seen_actors: Dictionary = {}
	var seen_bodies: Dictionary = {}
	for row: Variant in frame.actors:
		if not row is Dictionary:
			return "actor_type"
		if not _allowed_keys(row, ["actor_id", "generation", "equipment_epoch", "instance_id", "usable_index",
			"state", "body_id", "position", "rotation", "half_extents", "muzzle", "direction", "owner_origin",
			"active", "lease_deadline", "parts"]):
			return "actor_fields"
		for key: String in ["actor_id", "generation", "equipment_epoch", "usable_index", "body_id", "lease_deadline"]:
			if not row.get(key) is int:
				return "actor_identity"
		if row.actor_id < 0 or row.actor_id >= MAX_ACTORS or seen_actors.has(row.actor_id) \
			or row.usable_index < -1 or row.usable_index >= Catalog.count() \
			or row.body_id < 0 or row.body_id > 64 or row.generation < 0 \
			or row.equipment_epoch < 0 or not row.get("instance_id") is String or str(row.instance_id).is_empty():
			return "actor_identity"
		seen_actors[row.actor_id] = true
		if not row.get("active") is bool or not row.get("state") is String:
			return "actor_state"
		for key: String in ["position", "muzzle", "direction", "owner_origin", "half_extents"]:
			if not row.get(key) is Vector2 or not Vector2(row[key]).is_finite():
				return "actor_pose"
		if not _finite_number(row.get("rotation")) or not row.get("parts") is Array or row.parts.size() > 8:
			return "actor_parts"
		var owned_parts: Dictionary = {}
		for part: Variant in row.parts:
			if not part is Dictionary or not part.get("body_id") is int or part.body_id < 1 or part.body_id > 64 \
				or not part.get("position") is Vector2 or not Vector2(part.position).is_finite() \
				or not part.get("half_extents") is Vector2 or not Vector2(part.half_extents).is_finite() \
				or not _finite_number(part.get("rotation")):
				return "part_identity"
			if not _allowed_keys(part, ["body_id", "position", "rotation", "half_extents"]):
				return "part_fields"
			if owned_parts.has(part.body_id) or Vector2(part.half_extents).x <= 0.0 or Vector2(part.half_extents).y <= 0.0:
				return "part_identity"
			owned_parts[part.body_id] = part
			if seen_bodies.has(part.body_id) and int(seen_bodies[part.body_id]) != int(row.actor_id):
				return "duplicate_body_owner"
			seen_bodies[part.body_id] = row.actor_id
		if row.body_id > 0:
			if not owned_parts.has(row.body_id):
				return "mount_part"
			var mount: Dictionary = owned_parts[row.body_id]
			if not Vector2(row.position).is_equal_approx(mount.position) \
				or not Vector2(row.half_extents).is_equal_approx(mount.half_extents) \
				or not is_equal_approx(float(row.rotation), float(mount.rotation)):
				return "mount_pose"
			if seen_bodies.has(row.body_id) and int(seen_bodies[row.body_id]) != int(row.actor_id):
				return "duplicate_body_owner"
			seen_bodies[row.body_id] = row.actor_id
	var seen_devices: Dictionary = {}
	for device: Variant in frame.devices:
		if not device is Dictionary:
			return "device_type"
		if not _allowed_keys(device, ["instance_id", "actor_id", "equipment_epoch", "usable_index", "body_id",
			"position", "rotation", "half_extents", "state"]):
			return "device_fields"
		for key: String in ["actor_id", "equipment_epoch", "usable_index", "body_id"]:
			if not device.get(key) is int:
				return "device_identity"
		if device.actor_id < 0 or device.actor_id >= MAX_ACTORS or device.body_id < 1 or device.body_id > 64 \
			or device.usable_index < 22 or device.usable_index >= Catalog.count() \
			or not device.get("instance_id") is String or str(device.instance_id).is_empty() \
			or device.equipment_epoch < 0 or seen_devices.has(device.body_id):
			return "device_identity"
		if seen_bodies.has(device.body_id) and int(seen_bodies[device.body_id]) != int(device.actor_id):
			return "duplicate_body_owner"
		seen_devices[device.body_id] = true
		if not device.get("position") is Vector2 or not Vector2(device.position).is_finite() \
			or not device.get("half_extents") is Vector2 or not Vector2(device.half_extents).is_finite() \
			or not _finite_number(device.get("rotation")) or not device.get("state") is String:
			return "device_pose"
		var owner: Dictionary = actor_row(frame, int(device.actor_id))
		if owner.is_empty():
			return "device_owner"
		for key: String in ["instance_id", "equipment_epoch", "usable_index", "body_id", "state"]:
			if device.get(key) != owner.get(key):
				return "device_owner"
		if not Vector2(device.position).is_equal_approx(owner.position) \
			or not Vector2(device.half_extents).is_equal_approx(owner.half_extents) \
			or not is_equal_approx(float(device.rotation), float(owner.rotation)) \
			or Vector2(device.half_extents).x <= 0.0 or Vector2(device.half_extents).y <= 0.0:
			return "device_pose"
	return ""


static func request_error(request: Dictionary, frame: Dictionary) -> String:
	if request.size() != REQUEST_KEYS.size():
		return "request_fields"
	for key: Variant in request:
		if str(key) not in REQUEST_KEYS:
			return "request_fields"
	for key: String in ["version", "epoch", "actor_id", "generation", "equipment_epoch", "usable_index", "body_id", "sequence"]:
		if not request.get(key) is int:
			return "request_integer"
	if request.version != 1 or request.epoch != frame.get("epoch") or request.run_id != frame.get("run_id"):
		return "epoch"
	var row: Dictionary = actor_row(frame, int(request.actor_id))
	if row.is_empty():
		return "actor_id"
	for key: String in IDENTITY_KEYS:
		if key not in ["run_id", "epoch"] and request.get(key) != row.get(key):
			return key
	if int(request.sequence) < 0 or not request.get("request_id") is String or str(request.request_id).is_empty():
		return "sequence"
	if int(request.usable_index) < 0 or int(request.body_id) < 1 or not request.get("instance_id") is String or str(request.instance_id).is_empty():
		return "not_equipped"
	if not _finite_number(request.get("power")) or float(request.power) < 0.0 or float(request.power) > 1.0:
		return "power"
	if not request.get("operation") is String or str(request.operation) not in ["use", "alternate", "deploy"]:
		return "operation"
	if bool(frame.get("suspended", true)) or not bool(row.active) or int(frame.tick) >= int(row.lease_deadline):
		return "lease_or_cancel"
	if Vector2(row.direction).length_squared() < 0.000001 \
		or Vector2(row.half_extents).x <= 0.0 or Vector2(row.half_extents).y <= 0.0:
		return "mount_pose"
	return ""


static func frame_transition_error(previous: Dictionary, current: Dictionary) -> String:
	if previous.get("epoch") != current.get("epoch") or previous.get("run_id") != current.get("run_id"):
		return "epoch"
	if int(current.get("tick", -1)) < int(previous.get("tick", -1)):
		return "frame_tick"
	for row: Dictionary in current.get("actors", []):
		var old: Dictionary = actor_row(previous, int(row.actor_id))
		if old.is_empty():
			continue
		if int(row.generation) < int(old.generation) or int(row.equipment_epoch) < int(old.equipment_epoch):
			return "stale_generation"
		if row.instance_id != old.instance_id:
			return "instance_id"
	return ""


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _allowed_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() > keys.size():
		return false
	for key: Variant in value:
		if not (key is String or key is StringName) or str(key) not in keys:
			return false
	return true


static func receipt(request: Dictionary, accepted: bool, consumed: bool, reason: String) -> Dictionary:
	var result: Dictionary = {}
	for key: String in REQUEST_KEYS:
		var value: Variant = request.get(key)
		# Invalid diagnostic packets must not leak a caller-owned object through
		# a refusal snapshot. All valid request fields are scalar values.
		result[key] = value if value is String or value is int or value is bool \
			or (value is float and is_finite(float(value))) else null
	result["actor_id"] = int(request.actor_id) if request.get("actor_id") is int else -1
	result["accepted"] = accepted
	result["consumed"] = consumed
	result["reason"] = reason
	result["changed_cells"] = 0
	result["charge"] = 0.0
	result["cooldown"] = 0.0
	return result
