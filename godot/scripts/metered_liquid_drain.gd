class_name CyberMeteredLiquidDrain
extends RefCounted

# Owner-local U10 profile. Only CyberPhysicalUsableRuntime calls apply(), inside
# the existing cancellation/World owner interval. These are host-local verified
# observations, never a native-issued command receipt or a second World owner.
const PROFILE: String = "metered-drain-v1"
const PROVENANCE: String = "host-local-native-observation-v1"
const READ_ACCOUNTING: String = "material-work-units-v1"
const MAX_TARGETS: int = 16
const STOCK_CELLS: int = 32
const MAX_NATIVE_TICK: int = 1 << 31
const WATER: int = 3
const BRINE: int = 24
const EMPTY: int = 0
# Material-work units: every helper cell inspection plus conservative reserves
# for metadata/Object identity within apply(). This is not an all-native-getter
# cap: caller lifecycle refresh, scalar setup/health and mask preparation are
# outside this counter. Short-circuit failures may use fewer actual calls.
const IDENTITY_READS: int = 10 # refresh (at most eight), tick and hard revision
const PRE_IDENTITY_READS: int = 6
const POST_IDENTITY_READS: int = 8 # identity check plus final tick/revision copies
const REQUEST_FIELDS: Array[String] = ["profile", "material", "native_generation",
	"policy_hash", "world_instance_id", "quantity_budget"]

var terminal: bool = false
var terminal_evidence: Dictionary = {}
var _bridge: Object
var _world_instance_id: int = 0
var _native_generation: int = -1
var _context: Dictionary = {}
var _policy: Dictionary = {}
var _construction: Dictionary = {}
var _stock: Dictionary = {}
var _cache: Dictionary = {}
var _reads: int = 0
var _read_limit: int = 0
var _tick: int = -1
var _read_error: String = ""
var _started_usec: int = 0


func _init() -> void:
	_context = {"profile": PROFILE, "available": false, "reason": "native_owner_unavailable",
		"world_instance_id": 0, "native_generation": -1, "policy_hash": "",
		"completed_tick": -1,
		"mass_bits": -1, "maximum": 0, "coherence_ticks": -1,
		"allowed_materials": [], "initial_construction_receipt_available": false, "terminal": false}
	if ClassDB.class_exists(&"CyberDemoBridge"):
		_bridge = ClassDB.instantiate(&"CyberDemoBridge")


func refresh(world: Object) -> Dictionary:
	if world == null or not world.is_class("CyberNativeCellWorld") or _bridge == null:
		return {"available": false, "reason": "native_owner_unavailable"}
	var instance: int = int(world.get_instance_id())
	var generation: int = int(world.get_liquid_policy_session_generation())
	if instance != _world_instance_id or generation != _native_generation:
		# Equipment/session/reset() calls do not refill this ledger. Only an
		# actually replaced native World creates a new finite stock.
		_world_instance_id = instance
		_native_generation = generation
		_stock.clear()
		terminal = false
		terminal_evidence.clear()
		_policy = world.get_liquid_solver_policy()
		_construction = world.get_applied_liquid_construction_receipt()
		var water: Dictionary = world.get_water_experiment_policy()
		_context = {"profile": PROFILE, "available": false, "reason": "invalid_policy_readback",
			"world_instance_id": instance, "native_generation": generation,
			"policy_hash": _policy.get("policy_hash", ""),
			"mass_bits": water.get("mass_bits", -1), "maximum": water.get("maximum", 0),
			"coherence_ticks": water.get("coherence_ticks", -1),
			"allowed_materials": [], "initial_construction_receipt_available": not _construction.is_empty()}
		var reason: String = _policy_error(water)
		_context.reason = reason
		_context.available = reason.is_empty()
		if reason.is_empty():
			_context.allowed_materials = [WATER, BRINE]
	var copied: Dictionary = _context.duplicate(true)
	copied["terminal"] = terminal
	copied["completed_tick"] = int(world.get_tick_index())
	if terminal:
		copied.available = false
		copied.reason = "owner_terminal"
	elif bool(world.has_failed()):
		copied.available = false
		copied.reason = "native_world_failed"
	elif int(copied.completed_tick) > MAX_NATIVE_TICK:
		copied.available = false
		copied.reason = "fresh_owner_required"
	_context = copied.duplicate(true)
	return copied


func _policy_error(water: Dictionary) -> String:
	if not _policy.get("session_generation") is int or int(_policy.session_generation) != _native_generation \
		or not _policy.get("policy_hash") is String or str(_policy.policy_hash).length() != 64 \
		or not _policy.get("assignments") is Array or not _policy.get("maximum_rule_radius") is int \
		or not water.get("mass_bits") is int or not water.get("maximum") is int \
		or not water.get("coherence_ticks") is int:
		return "invalid_policy_readback"
	var bits: int = int(water.mass_bits)
	if bits < 3 or bits > 8 or int(water.maximum) != (1 << bits) - 1:
		return "invalid_water_precision"
	var found: Dictionary = {}
	var inertial: bool = false
	for value: Variant in _policy.assignments:
		if not value is Dictionary or not value.get("material") is int:
			return "invalid_policy_readback"
		var family: String = str(value.get("applied_family", ""))
		if family == "pressure_flow_v1":
			return "pressure_world_unsupported"
		inertial = inertial or family == "inertial_cellular_v1"
		if int(value.material) in [WATER, BRINE]:
			if found.has(value.material) or value.get("applied_variant") != "reference":
				return "unsupported_policy"
			found[value.material] = family
	if found.get(WATER, "") not in ["freemass_v1", "cellular_yield_v1", "inertial_cellular_v1"] \
		or found.get(BRINE, "") not in ["cellular_yield_v1", "inertial_cellular_v1"]:
		return "unsupported_policy"
	if int(_policy.maximum_rule_radius) not in [2, 3] or (inertial and int(_policy.maximum_rule_radius) != 3):
		return "unsupported_radius"
	if inertial:
		# CYPS import retires this identity. Hidden arbitrary imported IN ledger
		# histories have no bounded copied-counter preflight in the current ABI.
		if _construction.get("kind") != "applied_run" \
			or not _construction.get("canonical_bytes") is PackedByteArray \
			or not _construction.get("receipt_hash") is String:
			return "fresh_inertial_construction_required"
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(_construction.canonical_bytes)
		if digest.finish().hex_encode() != str(_construction.receipt_hash):
			return "invalid_construction_receipt"
	return ""


func _family(material: int) -> String:
	for value: Dictionary in _policy.get("assignments", []):
		if int(value.material) == material:
			return str(value.applied_family)
	return ""


func _stock_for(owner: int) -> Dictionary:
	if not _stock.has(owner):
		var maximum: int = int(_context.get("maximum", 0))
		_stock[owner] = {"water_units_initial": STOCK_CELLS * maximum,
			"water_units_remaining": STOCK_CELLS * maximum, "water_units_removed": 0,
			"brine_cells_initial": STOCK_CELLS, "brine_cells_remaining": STOCK_CELLS,
			"brine_cells_removed": 0}
	return _stock[owner]


func observation(owner: int, world: Object = null) -> Dictionary:
	var value: Dictionary = refresh(world) if world != null else _context.duplicate(true)
	value.merge(_stock_for(owner), true)
	value["terminal"] = terminal
	if terminal:
		value.available = false
		value.reason = "owner_terminal"
	return value.duplicate(true)


func _inspect(world: Object, point: Vector2i) -> Dictionary:
	return _bridge.inspect_cell(world, point)


func _erase(world: Object, point: Vector2i) -> void:
	world.emit_disc(point.x, point.y, 0, EMPTY)


func _valid_cell(value: Dictionary, point: Vector2i) -> bool:
	if value.get("ok") != true:
		return false
	for key: String in ["x", "y", "completed_tick", "material", "state_a", "state_b", "transient_body_id"]:
		if not value.get(key) is int:
			return false
	return int(value.x) == point.x and int(value.y) == point.y \
		and int(value.completed_tick) == _tick and int(value.material) >= 0 and int(value.material) <= 255 \
		and int(value.state_a) >= 0 and int(value.state_a) <= 255 \
		and int(value.state_b) >= 0 and int(value.state_b) <= 255 \
		and int(value.transient_body_id) >= 0 and int(value.transient_body_id) <= 64


func _read(world: Object, point: Vector2i) -> Dictionary:
	if point.x < 0 or point.y < 0 or point.x >= 1024 or point.y >= 1024:
		_read_error = "outside_bounds"
		return {}
	if _cache.has(point):
		return _cache[point]
	if _reads >= _read_limit:
		_read_error = "read_capacity"
		return {}
	_reads += 1
	var value: Dictionary = _inspect(world, point)
	if not _valid_cell(value, point):
		_read_error = "invalid_readback"
		return {}
	_cache[point] = value.duplicate(true)
	return value


static func _supercover(start: Vector2, finish: Vector2) -> Array[Vector2i]:
	# Includes both side cells at a corner; a thin hard face cannot be skipped.
	var result: Array[Vector2i] = []
	var point := Vector2i(start.floor())
	var end := Vector2i(finish.floor())
	result.append(point)
	var ray: Vector2 = finish - start
	var direction := Vector2i(signi(end.x - point.x), signi(end.y - point.y))
	var dx: float = 1.0 / absf(ray.x) if direction.x != 0 else INF
	var dy: float = 1.0 / absf(ray.y) if direction.y != 0 else INF
	var nx: float = (float(point.x + 1) - start.x if direction.x > 0 else start.x - float(point.x)) * dx if direction.x != 0 else INF
	var ny: float = (float(point.y + 1) - start.y if direction.y > 0 else start.y - float(point.y)) * dy if direction.y != 0 else INF
	for _index: int in range(128):
		if point == end:
			return result
		if absf(nx - ny) < 0.000001:
			result.append(point + Vector2i(direction.x, 0))
			result.append(point + Vector2i(0, direction.y))
			point += direction
			nx += dx
			ny += dy
		elif nx < ny:
			point.x += direction.x
			nx += dx
		else:
			point.y += direction.y
			ny += dy
		result.append(point)
	return []


func _identity_matches(world: Object, request: Dictionary, revision: int) -> bool:
	return not bool(world.has_failed()) and int(world.get_instance_id()) == int(request.world_instance_id) \
		and int(world.get_liquid_policy_session_generation()) == int(request.native_generation) \
		and int(world.get_tick_index()) == _tick and int(world.get_hard_surface_revision()) == revision \
		and world.get_liquid_solver_policy() == _policy


func _refused(out: Dictionary, reason: String) -> Dictionary:
	out.status = "refused"
	out.reason = reason
	out["quantity_complete"] = true
	out["reads_used"] = _reads
	out.command_overhead_usec = Time.get_ticks_usec() - _started_usec
	return out


func apply(world: Object, pose: Dictionary, request: Dictionary, effective_power: float,
	reads_available: int, writes_available: int, frame_tick: int) -> Dictionary:
	var start_usec: int = Time.get_ticks_usec()
	_started_usec = start_usec
	_reads = 0
	var context: Dictionary = _context.duplicate(true)
	var owner: int = int(request.actor_id)
	var material: int = int(request.material)
	var stock: Dictionary = _stock_for(owner)
	var unit: String = "water_units" if material == WATER else "brine_cells"
	var remaining: int = int(stock[unit + "_remaining"])
	var out: Dictionary = {"profile": PROFILE, "provenance": PROVENANCE,
		"status": "refused", "reason": "", "command_id": request.request_id,
		"requested_material": material, "requested_policy_hash": request.policy_hash,
		"requested_quantity_budget": request.quantity_budget, "requested_range": 29.0,
		"requested_radius": 4, "maximum_targets": MAX_TARGETS,
		"world_instance_id": request.world_instance_id, "native_generation": request.native_generation,
		"run_id": request.run_id, "epoch": request.epoch, "generation": request.generation,
		"equipment_epoch": request.equipment_epoch, "instance_id": request.instance_id,
		"body_id": request.body_id, "physical_frame_tick": frame_tick,
		"mask_provenance": "native masks prepared from the captured physical frame before owner consumption",
		"native_pose_revision_available": false,
		"water_units_removed": 0, "brine_cells_removed": 0, "sink_debit": 0,
		"budget_before": remaining, "remaining_budget": remaining,
		"targets": [], "transitions": [], "reads_used": _reads, "writes_attempted": 0,
		"read_accounting": READ_ACCOUNTING, "preflight_complete": false,
		"eligible_target_count": 0, "eligible_quantity": 0,
		"completed_tick_before": -1, "completed_tick_after": -1,
		"initial_construction_receipt": _construction.duplicate(true),
		"initial_construction_provenance": "native-initial-construction" if not _construction.is_empty() else "unavailable-legacy-construction",
		"applied_policy": _policy.duplicate(true), "command_overhead_usec": 0}
	if reads_available < IDENTITY_READS + PRE_IDENTITY_READS + POST_IDENTITY_READS + MAX_TARGETS:
		return _refused(out, "read_capacity")
	context = refresh(world)
	_reads = IDENTITY_READS
	# refresh may have retired a native generation even when this helper is
	# exercised directly. Never retain a dictionary from the retired ledger.
	stock = _stock_for(owner)
	remaining = int(stock[unit + "_remaining"])
	out.budget_before = remaining
	out.remaining_budget = remaining
	out.applied_policy = _policy.duplicate(true)
	out.initial_construction_receipt = _construction.duplicate(true)
	out.initial_construction_provenance = "native-initial-construction" if not _construction.is_empty() else "unavailable-legacy-construction"
	if not bool(context.get("available", false)):
		return _refused(out, str(context.get("reason", "native_owner_unavailable")))
	if request.profile != PROFILE or int(request.usable_index) != 9 or material not in [WATER, BRINE]:
		return _refused(out, "profile_or_material")
	if request.world_instance_id != context.world_instance_id or request.native_generation != context.native_generation \
		or request.policy_hash != context.policy_hash:
		return _refused(out, "stale_native_owner")
	if not is_finite(effective_power) or effective_power <= 0.0 or effective_power > 1.0:
		return _refused(out, "zero_power")
	var quantum: int = int(context.maximum) if material == WATER else 1
	out["applied_solver_family"] = _family(material)
	out["water_mass_bits"] = int(context.mass_bits)
	out["water_complete_cell_quantum"] = int(context.maximum)
	if int(request.quantity_budget) <= 0 or int(request.quantity_budget) > MAX_TARGETS * quantum:
		return _refused(out, "quantity_budget")
	if remaining <= 0:
		return _refused(out, "budget_exhausted")
	var cap: int = mini(MAX_TARGETS, maxi(1, ceili(float(MAX_TARGETS) * effective_power)))
	if writes_available < cap:
		return _refused(out, "write_capacity")
	# Keep complete post-readback and identity space available during preflight.
	_read_limit = reads_available - cap - PRE_IDENTITY_READS - POST_IDENTITY_READS
	if _read_limit <= _reads:
		return _refused(out, "read_capacity")
	_cache.clear()
	_read_error = ""
	_tick = int(world.get_tick_index())
	out.completed_tick_before = _tick
	out.completed_tick_after = _tick
	var hard_revision: int = int(world.get_hard_surface_revision())
	out["hard_surface_revision_before"] = hard_revision
	var origin: Vector2 = pose.muzzle
	var aim: Vector2 = Vector2(pose.direction).normalized()
	var reach: float = 29.0 * lerpf(0.35, 1.0, effective_power)
	out["effective_power"] = effective_power
	out["effective_range"] = reach
	out["origin"] = origin
	out["aim"] = aim
	var ray: Array[Vector2i] = _supercover(origin, origin + aim * reach)
	if ray.is_empty():
		return _refused(out, "invalid_footprint")
	var contact := Vector2i(-1, -1)
	for point: Vector2i in ray:
		var value: Dictionary = _read(world, point)
		if value.is_empty():
			return _refused(out, _read_error)
		if int(value.transient_body_id) != 0:
			return _refused(out, "body_masked")
		if int(value.material) == material:
			contact = point
			break
		if int(value.material) != EMPTY:
			return _refused(out, "wrong_material")
	if contact.x < 0:
		return _refused(out, "empty_intake")
	out["intake_center"] = contact
	var targets: Array[Dictionary] = []
	out.targets = targets
	var quantity: int = 0
	var budget: int = mini(remaining, int(request.quantity_budget))
	for y: int in range(contact.y - 4, contact.y + 5):
		for x: int in range(contact.x - 4, contact.x + 5):
			if targets.size() >= cap:
				break
			var point := Vector2i(x, y)
			if Vector2(point - contact).length_squared() > 4.25 * 4.25:
				continue
			var value: Dictionary = _read(world, point)
			if value.is_empty():
				return _refused(out, _read_error)
			if int(value.material) != material:
				continue
			if int(value.transient_body_id) != 0:
				return _refused(out, "body_masked")
			var dose: int = int(value.state_a) if material == WATER else 1
			if material == WATER and (dose < 1 or dose > quantum \
				or int(value.state_b) > int(context.coherence_ticks)):
				return _refused(out, "invalid_water_quantity")
			if material == WATER and _family(WATER) in ["inertial_cellular_v1", "cellular_yield_v1"] and dose != quantum:
				return _refused(out, "fractional_whole_cell_input")
			if quantity + dose > budget:
				continue
			var sight: Array[Vector2i] = _supercover(origin, Vector2(point) + Vector2(0.5, 0.5))
			if sight.is_empty():
				return _refused(out, "invalid_footprint")
			for path_point: Vector2i in sight:
				var path_value: Dictionary = _read(world, path_point)
				if path_value.is_empty():
					return _refused(out, _read_error)
				if int(path_value.transient_body_id) != 0:
					return _refused(out, "body_masked")
				if int(path_value.material) not in [EMPTY, material]:
					return _refused(out, "blocked_target")
			targets.append({"point": point, "before": value.duplicate(true), "quantity": dose})
			quantity += dose
			out.eligible_target_count = targets.size()
			out.eligible_quantity = quantity
	if targets.is_empty():
		return _refused(out, "quantity_budget")
	out.targets = targets.duplicate(true)
	out["eligible_target_count"] = targets.size()
	out["eligible_quantity"] = quantity
	if _reads + targets.size() + PRE_IDENTITY_READS + POST_IDENTITY_READS > reads_available:
		return _refused(out, "read_capacity")
	_reads += PRE_IDENTITY_READS
	if not _identity_matches(world, request, hard_revision):
		return _refused(out, "owner_changed_during_preflight")
	out["preflight_complete"] = true
	# Latch BEFORE calling a writer. An interrupted GDScript call can never
	# make a possibly applied command retryable; successful final verification
	# is the only path that clears this latch within the same native generation.
	terminal = true
	out.status = "fault"
	out.reason = "interrupted_execution"
	terminal_evidence = out.duplicate(true)
	for target: Dictionary in targets:
		out.writes_attempted = int(out.writes_attempted) + 1
		terminal_evidence = out.duplicate(true)
		_erase(world, target.point)
		_reads += 1
		var after: Dictionary = _inspect(world, target.point)
		var verified: bool = _valid_cell(after, target.point) and int(after.material) == EMPTY \
			and int(after.transient_body_id) == 0 and int(after.state_a) == 0 and int(after.state_b) == 0
		out.transitions.append({"point": target.point, "before": target.before.duplicate(true),
			"after": after.duplicate(true), "verified_removed": verified})
		if verified:
			var actual: int = int(target.quantity)
			out[unit + "_removed"] = int(out[unit + "_removed"]) + actual
			out.sink_debit = int(out.sink_debit) + actual
			stock[unit + "_remaining"] = int(stock[unit + "_remaining"]) - actual
			stock[unit + "_removed"] = int(stock[unit + "_removed"]) + actual
			out.remaining_budget = int(stock[unit + "_remaining"])
		out.reads_used = _reads
		terminal_evidence = out.duplicate(true)
		if not verified:
			out.reason = "post_readback_mismatch"
			out["quantity_complete"] = false
			out.command_overhead_usec = Time.get_ticks_usec() - start_usec
			terminal_evidence = out.duplicate(true)
			return out
	_reads += POST_IDENTITY_READS
	out.reads_used = _reads
	out.completed_tick_after = int(world.get_tick_index())
	out["hard_surface_revision_after"] = int(world.get_hard_surface_revision())
	if not _identity_matches(world, request, hard_revision):
		out.reason = "owner_changed_after_mutation"
		out["quantity_complete"] = false
		out.command_overhead_usec = Time.get_ticks_usec() - start_usec
		terminal_evidence = out.duplicate(true)
		return out
	out.status = "applied"
	out.reason = "applied"
	out["quantity_complete"] = true
	out.command_overhead_usec = Time.get_ticks_usec() - start_usec
	terminal = false
	terminal_evidence.clear()
	return out
