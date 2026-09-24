extends RefCounted

# WEX-004 Arm B: isolated, non-production decompression-event proof.
# This model consumes value snapshots and the existing diagnostic cell API only.
# It owns no Node, RID, PhysicsServer object, gas topology, or persistent cell field.

const MAX_EVENTS: int = 4
const MAX_CELL_MOVES_PER_STEP: int = 32
const LIFETIME_STEPS: int = 12
const HORIZON: float = 10.0
const MIN_DIFFERENTIAL_PA: float = 250.0
const GLOBAL_WORK_PER_STEP: float = 2.5
const EVENT_WORK_PER_STEP: float = 1.25
const CELL_MOVE_WORK: float = 0.04
const BODY_IMPULSE_PER_EVENT: float = 0.75
const MAX_SOURCE_BUDGET: float = 12.0
const MAX_PRESSURE_PA: float = 10000000.0
const MAX_SOURCE_AMOUNT: float = 1000000.0
const MAX_OPENING_AREA: float = 64.0

var _registered: bool = false
var _refusal_reason: String = ""
var _source_region_id: int = 0
var _source_generation: int = 0
var _initial_pressure_pa: float = 0.0
var _current_pressure_pa: float = 0.0
var _initial_amount: float = 0.0
var _remaining_amount: float = 0.0
var _initial_budget: float = 0.0
var _remaining_budget: float = 0.0
var _authority_revision: int = 0
var _last_world_revision: int = 0
var _registration_tick: int = 0
var _step_index: int = 0
var _events: Array = []
var _body_results := PackedFloat32Array()
var _metrics: Dictionary = {}


func _new_metrics() -> Dictionary:
	return {
		"registration_refusals": 0,
		"capacity_refusals": 0,
		"stale_cancellations": 0,
		"occlusion_rejections": 0,
		"field_cells_visited": 0,
		"line_cells_visited": 0,
		"cellular_attempts": 0,
		"cellular_moves": 0,
		"rapier_targets": 0,
		"cellular_work": 0.0,
		"rapier_work": 0.0,
		"offered_work": 0.0,
		"applied_work": 0.0,
		"refused_work": 0.0,
		"last_step_offered_work": 0.0,
		"last_step_applied_work": 0.0,
		"last_step_refused_work": 0.0,
	}


func reset() -> void:
	_registered = false
	_refusal_reason = ""
	_source_region_id = 0
	_source_generation = 0
	_initial_pressure_pa = 0.0
	_current_pressure_pa = 0.0
	_initial_amount = 0.0
	_remaining_amount = 0.0
	_initial_budget = 0.0
	_remaining_budget = 0.0
	_authority_revision = 0
	_last_world_revision = 0
	_registration_tick = 0
	_step_index = 0
	_events = []
	_body_results = PackedFloat32Array()
	_metrics = _new_metrics()


func _refuse(reason: String, capacity: bool = false) -> bool:
	reset()
	_refusal_reason = reason
	_metrics.registration_refusals = 1
	_metrics.capacity_refusals = 1 if capacity else 0
	return false


func _event_less(left: Dictionary, right: Dictionary) -> bool:
	return int(left.opening_id) < int(right.opening_id)


func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _cell_step(normal: Vector2) -> Vector2i:
	if not _finite_vector(normal) or normal.length() <= 0.000001:
		return Vector2i.ZERO
	var unit: Vector2 = normal.normalized()
	var result := Vector2i(roundi(unit.x), roundi(unit.y))
	if result == Vector2i.ZERO:
		if absf(unit.x) >= absf(unit.y):
			result.x = 1 if unit.x >= 0.0 else -1
		else:
			result.y = 1 if unit.y >= 0.0 else -1
	return result


func begin(world: Object, source: Dictionary, openings: Array) -> bool:
	reset()
	if (
		world == null
		or not world.has_method("get_revision")
		or not world.has_method("material_at")
		or not world.has_method("diagnostic_relocate_cell")
	):
		return _refuse("diagnostic value authority unavailable")
	if openings.is_empty():
		return _refuse("at least one opening is required")
	if openings.size() > MAX_EVENTS:
		return _refuse("opening capacity exceeded", true)

	var source_region_id: int = int(source.get("region_id", 0))
	var source_generation: int = int(source.get("generation", -1))
	var source_pressure: float = float(source.get("pressure_pa", 0.0))
	var source_amount: float = float(source.get("amount", 0.0))
	if (
		source_region_id <= 0
		or source_generation < 0
		or not is_finite(source_pressure)
		or source_pressure <= 0.0
		or source_pressure > MAX_PRESSURE_PA
		or not is_finite(source_amount)
		or source_amount <= 0.0
		or source_amount > MAX_SOURCE_AMOUNT
	):
		return _refuse("invalid source region snapshot")

	var parsed: Array = []
	for raw: Variant in openings:
		if typeof(raw) != TYPE_DICTIONARY:
			return _refuse("opening entry is not a dictionary")
		var opening: Dictionary = raw
		var raw_position: Variant = opening.get("position", Vector2.ZERO)
		var raw_normal: Variant = opening.get("normal", Vector2.ZERO)
		if typeof(raw_position) != TYPE_VECTOR2 or typeof(raw_normal) != TYPE_VECTOR2:
			return _refuse("opening position/normal must be Vector2")
		var position: Vector2 = raw_position
		var normal: Vector2 = raw_normal
		var area: float = float(opening.get("area", 0.0))
		var destination_pressure: float = float(
			opening.get("destination_pressure_pa", 0.0)
		)
		var opening_id: int = int(opening.get("id", 0))
		var opening_generation: int = int(opening.get("generation", -1))
		var destination_region_id: int = int(
			opening.get("destination_region_id", 0)
		)
		var destination_generation: int = int(
			opening.get("destination_generation", -1)
		)
		var rounded := Vector2i(roundi(position.x), roundi(position.y))
		if (
			opening_id <= 0
			or opening_generation < 0
			or destination_region_id <= 0
			or destination_generation < 0
			or not _finite_vector(position)
			or not _finite_vector(normal)
			or normal.length() <= 0.000001
			or rounded.x < 0
			or rounded.y < 0
			or rounded.x >= CyberCellWorld.WORLD_WIDTH
			or rounded.y >= CyberCellWorld.WORLD_HEIGHT
			or not is_finite(area)
			or area <= 0.0
			or area > MAX_OPENING_AREA
			or not is_finite(destination_pressure)
			or destination_pressure < 0.0
			or destination_pressure > MAX_PRESSURE_PA
		):
			return _refuse("invalid opening snapshot")
		normal = normal.normalized()
		var move_step: Vector2i = _cell_step(normal)
		if move_step == Vector2i.ZERO:
			return _refuse("opening normal has no cell direction")
		parsed.append({
			"opening_id": opening_id,
			"opening_generation": opening_generation,
			"destination_region_id": destination_region_id,
			"destination_generation": destination_generation,
			"position": position,
			"normal": normal,
			"cell_step": move_step,
			"area": area,
			"destination_pressure_pa": destination_pressure,
			"initial_budget": 0.0,
			"remaining_budget": 0.0,
			"age": 0,
			"active": false,
		})

	parsed.sort_custom(_event_less)
	for index: int in range(1, parsed.size()):
		if int(parsed[index - 1].opening_id) == int(parsed[index].opening_id):
			return _refuse("duplicate opening id")

	var area_sum: float = 0.0
	var destination_area_sum: float = 0.0
	var weights: Array[float] = []
	weights.resize(parsed.size())
	weights.fill(0.0)
	var weight_sum: float = 0.0
	for index: int in range(parsed.size()):
		var event: Dictionary = parsed[index]
		var area: float = float(event.area)
		var destination_pressure: float = float(event.destination_pressure_pa)
		area_sum += area
		destination_area_sum += area * minf(destination_pressure, source_pressure)
		var differential: float = maxf(0.0, source_pressure - destination_pressure)
		if differential >= MIN_DIFFERENTIAL_PA:
			weights[index] = area * differential
		weight_sum += weights[index]

	var effective_destination: float = (
		destination_area_sum / area_sum if area_sum > 0.0 else source_pressure
	)
	var extractable_fraction: float = clampf(
		1.0 - effective_destination / source_pressure, 0.0, 1.0
	)
	var source_budget: float = (
		minf(MAX_SOURCE_BUDGET, source_amount * extractable_fraction)
		if weight_sum > 0.0
		else 0.0
	)

	for index: int in range(parsed.size()):
		var event: Dictionary = parsed[index]
		var event_budget: float = (
			source_budget * weights[index] / weight_sum if weight_sum > 0.0 else 0.0
		)
		event.initial_budget = event_budget
		event.remaining_budget = event_budget
		event.active = event_budget > 0.0
		parsed[index] = event

	_registered = true
	_source_region_id = source_region_id
	_source_generation = source_generation
	_initial_pressure_pa = source_pressure
	_current_pressure_pa = source_pressure
	_initial_amount = source_amount
	_remaining_amount = source_amount
	_initial_budget = source_budget
	_remaining_budget = source_budget
	_authority_revision = int(world.get_revision())
	_last_world_revision = _authority_revision
	_registration_tick = int(world.get_tick_index()) if world.has_method("get_tick_index") else 0
	_events = parsed
	return true


func _is_hard_surface(material_id: int) -> bool:
	if material_id >= CyberCellWorld.LIMESTONE_BLOCK and material_id <= CyberCellWorld.LED_WHITE:
		return true
	match material_id:
		CyberCellWorld.WALL, CyberCellWorld.CLONER, CyberCellWorld.WOOD, CyberCellWorld.ICE, CyberCellWorld.METAL, CyberCellWorld.CONCRETE, CyberCellWorld.GLASS:
			return true
		_:
			return false


func _is_loose(material_id: int) -> bool:
	return material_id in [
		CyberCellWorld.SAND,
		CyberCellWorld.DUST,
		CyberCellWorld.SALT,
		CyberCellWorld.GUNPOWDER,
	]


func _line_clear(world: Object, from: Vector2, to: Vector2) -> Dictionary:
	var x: int = roundi(from.x)
	var y: int = roundi(from.y)
	var target_x: int = roundi(to.x)
	var target_y: int = roundi(to.y)
	var dx: int = absi(target_x - x)
	var sx: int = 1 if x < target_x else -1
	var dy: int = -absi(target_y - y)
	var sy: int = 1 if y < target_y else -1
	var error: int = dx + dy
	var steps: int = 0
	var visited: int = 0
	while x != target_x or y != target_y:
		var doubled: int = 2 * error
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy
		if x == target_x and y == target_y:
			break
		steps += 1
		if (
			steps > int(HORIZON) + 1
			or x < 0
			or y < 0
			or x >= CyberCellWorld.WORLD_WIDTH
			or y >= CyberCellWorld.WORLD_HEIGHT
		):
			return {"clear": false, "visited": visited, "occluded": false}
		visited += 1
		if _is_hard_surface(int(world.material_at(x, y))):
			return {"clear": false, "visited": visited, "occluded": true}
	return {"clear": true, "visited": visited, "occluded": false}


func _target_eligibility(world: Object, target: Vector2, event: Dictionary) -> Dictionary:
	var delta: Vector2 = target - Vector2(event.position)
	if (
		delta.length() > HORIZON + 0.000001
		or delta.dot(Vector2(event.normal)) > 0.5
	):
		return {"eligible": false, "visited": 0, "occluded": false}
	var line: Dictionary = _line_clear(world, target, Vector2(event.position))
	return {
		"eligible": bool(line.clear),
		"visited": int(line.visited),
		"occluded": bool(line.occluded),
	}


func _parse_bodies(states: PackedFloat32Array) -> Array:
	var bodies: Array = []
	var count: int = CyberRigidBodyCoupling.input_body_count(states)
	for body_index: int in range(count):
		var offset: int = body_index * CyberRigidBodyCoupling.INPUT_STRIDE
		var body_id: int = roundi(states[offset + CyberRigidBodyCoupling.INPUT_BODY_ID])
		if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
			continue
		bodies.append({
			"id": body_id,
			"center": Vector2(
				states[offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
				states[offset + CyberRigidBodyCoupling.INPUT_CENTER_Y]
			),
			"rotation": float(states[offset + CyberRigidBodyCoupling.INPUT_ROTATION]),
			"size": Vector2(
				states[offset + CyberRigidBodyCoupling.INPUT_SIZE_X],
				states[offset + CyberRigidBodyCoupling.INPUT_SIZE_Y]
			),
			"sample_serial": roundi(
				states[offset + CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL]
			),
		})
	bodies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.id) < int(right.id)
	)
	return bodies


func _point_inside_body(point: Vector2, body: Dictionary) -> bool:
	var local: Vector2 = (point - Vector2(body.center)).rotated(-float(body.rotation))
	var half_size: Vector2 = Vector2(body.size) * 0.5
	return absf(local.x) <= half_size.x and absf(local.y) <= half_size.y


func _cell_inside_any_body(cell: Vector2i, bodies: Array) -> bool:
	var point := Vector2(cell)
	for body: Dictionary in bodies:
		if _point_inside_body(point, body):
			return true
	return false


func _relocate_cell(world: Object, from: Vector2i, to: Vector2i, _material_id: int) -> bool:
	# The native diagnostic adapter delegates to World::relocate_stored_cell(),
	# preserving the authoritative material payload/temperature in one serialized
	# ownership operation rather than recreating the destination from a material ID.
	return bool(world.diagnostic_relocate_cell(from, to))


func _cancel_all() -> void:
	for index: int in range(_events.size()):
		var event: Dictionary = _events[index]
		if bool(event.active):
			event.active = false
			_metrics.stale_cancellations = int(_metrics.stale_cancellations) + 1
			_events[index] = event


func _append_body_result(body: Dictionary, impulse: Vector2) -> void:
	_body_results.append(float(body.id))
	_body_results.append(impulse.x)
	_body_results.append(impulse.y)
	_body_results.append(0.0)
	_body_results.append(0.0)
	_body_results.append(0.0)
	_body_results.append(0.0)
	_body_results.append(0.0)
	_body_results.append(float(body.sample_serial))


func step(
	world: Object,
	body_states: PackedFloat32Array,
	source_generation: int,
	opening_generations: PackedInt32Array
) -> Dictionary:
	_body_results = PackedFloat32Array()
	_metrics.last_step_offered_work = 0.0
	_metrics.last_step_applied_work = 0.0
	_metrics.last_step_refused_work = 0.0
	if not _registered or world == null:
		return metrics()

	_last_world_revision = int(world.get_revision())
	if (
		source_generation != _source_generation
		or _last_world_revision != _authority_revision
		or opening_generations.size() != _events.size() * 2
	):
		_cancel_all()
		_step_index += 1
		return metrics()

	for index: int in range(_events.size()):
		var event: Dictionary = _events[index]
		if not bool(event.active):
			continue
		if (
			int(opening_generations[index * 2]) != int(event.opening_generation)
			or int(opening_generations[index * 2 + 1]) != int(event.destination_generation)
		):
			event.active = false
			_metrics.stale_cancellations = int(_metrics.stale_cancellations) + 1
			_events[index] = event

	var bodies: Array = _parse_bodies(body_states)
	var body_impulses: Dictionary = {}
	var body_by_id: Dictionary = {}
	for body: Dictionary in bodies:
		body_by_id[int(body.id)] = body
		body_impulses[int(body.id)] = Vector2.ZERO

	var step_source_pressure: float = _current_pressure_pa
	var global_work_remaining: float = GLOBAL_WORK_PER_STEP
	var step_applied: float = 0.0
	var moved_destinations: Array[Vector2i] = []

	for event_index: int in range(_events.size()):
		if global_work_remaining <= 0.000001:
			break
		var event: Dictionary = _events[event_index]
		if not bool(event.active):
			continue
		var age: int = int(event.age)
		var event_remaining: float = float(event.remaining_budget)
		if age >= LIFETIME_STEPS or event_remaining <= 0.000001:
			event.active = false
			_events[event_index] = event
			continue
		var differential: float = (
			step_source_pressure - float(event.destination_pressure_pa)
		)
		if differential < MIN_DIFFERENTIAL_PA:
			event.active = false
			_events[event_index] = event
			continue

		var pre_decay_offer: float = minf(
			minf(event_remaining, _remaining_budget),
			minf(EVENT_WORK_PER_STEP, global_work_remaining)
		)
		if pre_decay_offer <= 0.000001:
			continue
		var lifetime_scale: float = float(LIFETIME_STEPS - age) / float(LIFETIME_STEPS)
		var event_grant: float = pre_decay_offer * lifetime_scale
		_metrics.offered_work = float(_metrics.offered_work) + pre_decay_offer
		_metrics.last_step_offered_work = (
			float(_metrics.last_step_offered_work) + pre_decay_offer
		)

		var body_targets: Array = []
		var body_weight_sum: float = 0.0
		for body: Dictionary in bodies:
			var eligibility: Dictionary = _target_eligibility(
				world, Vector2(body.center), event
			)
			_metrics.line_cells_visited = (
				int(_metrics.line_cells_visited) + int(eligibility.visited)
			)
			if bool(eligibility.occluded):
				_metrics.occlusion_rejections = (
					int(_metrics.occlusion_rejections) + 1
				)
			if not bool(eligibility.eligible):
				continue
			var distance: float = (
				Vector2(body.center) - Vector2(event.position)
			).length()
			var weight: float = maxf(0.0, 1.0 - distance / HORIZON)
			if weight <= 0.0:
				continue
			body_targets.append({"id": int(body.id), "weight": weight})
			body_weight_sum += weight

		var candidates: Array[Vector2i] = []
		var min_x: int = maxi(0, floori(float(event.position.x) - HORIZON))
		var max_x: int = mini(
			CyberCellWorld.WORLD_WIDTH - 1,
			ceili(float(event.position.x) + HORIZON)
		)
		var min_y: int = maxi(0, floori(float(event.position.y) - HORIZON))
		var max_y: int = mini(
			CyberCellWorld.WORLD_HEIGHT - 1,
			ceili(float(event.position.y) + HORIZON)
		)
		for y: int in range(min_y, max_y + 1):
			for x: int in range(min_x, max_x + 1):
				_metrics.field_cells_visited = int(_metrics.field_cells_visited) + 1
				var material_id: int = int(world.material_at(x, y))
				if not _is_loose(material_id):
					continue
				var cell := Vector2i(x, y)
				if cell in moved_destinations or _cell_inside_any_body(cell, bodies):
					continue
				var eligibility: Dictionary = _target_eligibility(
					world, Vector2(cell), event
				)
				_metrics.line_cells_visited = (
					int(_metrics.line_cells_visited) + int(eligibility.visited)
				)
				if bool(eligibility.occluded):
					_metrics.occlusion_rejections = (
						int(_metrics.occlusion_rejections) + 1
					)
				if not bool(eligibility.eligible):
					continue
				var destination: Vector2i = cell + Vector2i(event.cell_step)
				if (
					destination.x < 0
					or destination.y < 0
					or destination.x >= CyberCellWorld.WORLD_WIDTH
					or destination.y >= CyberCellWorld.WORLD_HEIGHT
					or int(world.material_at(destination.x, destination.y)) != CyberCellWorld.EMPTY
					or _cell_inside_any_body(destination, bodies)
				):
					continue
				candidates.append(cell)

		var has_cells: bool = (
			not candidates.is_empty()
			and moved_destinations.size() < MAX_CELL_MOVES_PER_STEP
		)
		var has_bodies: bool = not body_targets.is_empty() and body_weight_sum > 0.0
		var cell_allocation: float = 0.0
		var body_allocation: float = 0.0
		if has_cells and has_bodies:
			cell_allocation = event_grant * 0.5
			body_allocation = event_grant * 0.5
		elif has_cells:
			cell_allocation = event_grant
		elif has_bodies:
			body_allocation = event_grant

		var cell_applied: float = 0.0
		for from: Vector2i in candidates:
			if (
				moved_destinations.size() >= MAX_CELL_MOVES_PER_STEP
				or cell_applied + CELL_MOVE_WORK > cell_allocation + 0.000001
			):
				break
			var material_id: int = int(world.material_at(from.x, from.y))
			if not _is_loose(material_id):
				continue
			var destination: Vector2i = from + Vector2i(event.cell_step)
			_metrics.cellular_attempts = int(_metrics.cellular_attempts) + 1
			if not _relocate_cell(world, from, destination, material_id):
				continue
			moved_destinations.append(destination)
			_metrics.cellular_moves = int(_metrics.cellular_moves) + 1
			cell_applied += CELL_MOVE_WORK
		_metrics.cellular_work = float(_metrics.cellular_work) + cell_applied

		var body_applied: float = 0.0
		if body_allocation > 0.000001 and body_weight_sum > 0.0:
			for target: Dictionary in body_targets:
				var requested: float = (
					body_allocation * float(target.weight) / body_weight_sum
				)
				var magnitude: float = minf(BODY_IMPULSE_PER_EVENT, requested)
				if magnitude <= 0.000001:
					continue
				var body_id: int = int(target.id)
				body_impulses[body_id] = (
					Vector2(body_impulses[body_id])
					+ Vector2(event.normal) * magnitude
				)
				_metrics.rapier_targets = int(_metrics.rapier_targets) + 1
				body_applied += magnitude
		_metrics.rapier_work = float(_metrics.rapier_work) + body_applied

		var event_applied: float = minf(event_grant, cell_applied + body_applied)
		event.remaining_budget = maxf(0.0, event_remaining - event_applied)
		_remaining_budget = maxf(0.0, _remaining_budget - event_applied)
		global_work_remaining = maxf(0.0, global_work_remaining - event_applied)
		step_applied += event_applied
		var event_refused: float = maxf(0.0, pre_decay_offer - event_applied)
		_metrics.applied_work = float(_metrics.applied_work) + event_applied
		_metrics.refused_work = float(_metrics.refused_work) + event_refused
		_metrics.last_step_applied_work = (
			float(_metrics.last_step_applied_work) + event_applied
		)
		_metrics.last_step_refused_work = (
			float(_metrics.last_step_refused_work) + event_refused
		)
		event.age = age + 1
		if int(event.age) >= LIFETIME_STEPS or float(event.remaining_budget) <= 0.000001:
			event.active = false
		_events[event_index] = event

	_remaining_amount = maxf(0.0, _remaining_amount - step_applied)
	_current_pressure_pa = (
		_initial_pressure_pa * (_remaining_amount / _initial_amount)
		if _initial_amount > 0.0
		else 0.0
	)
	_authority_revision = int(world.get_revision())
	_last_world_revision = _authority_revision
	_step_index += 1

	for body: Dictionary in bodies:
		var impulse: Vector2 = Vector2(body_impulses.get(int(body.id), Vector2.ZERO))
		if impulse.length() <= 0.000001:
			continue
		_append_body_result(body, impulse)
	return metrics()


func body_results() -> PackedFloat32Array:
	return _body_results.duplicate()


func metrics() -> Dictionary:
	var event_rows: Array = []
	for event: Dictionary in _events:
		event_rows.append({
			"opening_id": int(event.opening_id),
			"opening_generation": int(event.opening_generation),
			"destination_region_id": int(event.destination_region_id),
			"destination_generation": int(event.destination_generation),
			"position": Vector2(event.position),
			"normal": Vector2(event.normal),
			"cell_step": Vector2i(event.cell_step),
			"area": float(event.area),
			"destination_pressure_pa": float(event.destination_pressure_pa),
			"initial_budget": float(event.initial_budget),
			"remaining_budget": float(event.remaining_budget),
			"age": int(event.age),
			"active": bool(event.active),
		})
	return {
		"registered": _registered,
		"refusal_reason": _refusal_reason,
		"source_region_id": _source_region_id,
		"source_generation": _source_generation,
		"initial_pressure_pa": _initial_pressure_pa,
		"current_pressure_pa": _current_pressure_pa,
		"initial_amount": _initial_amount,
		"remaining_amount": _remaining_amount,
		"initial_budget": _initial_budget,
		"remaining_budget": _remaining_budget,
		"topology_revision": _authority_revision,
		"current_topology_revision": _last_world_revision,
		"registration_tick": _registration_tick,
		"step_index": _step_index,
		"registration_refusals": int(_metrics.registration_refusals),
		"capacity_refusals": int(_metrics.capacity_refusals),
		"stale_cancellations": int(_metrics.stale_cancellations),
		"occlusion_rejections": int(_metrics.occlusion_rejections),
		"field_cells_visited": int(_metrics.field_cells_visited),
		"line_cells_visited": int(_metrics.line_cells_visited),
		"cellular_attempts": int(_metrics.cellular_attempts),
		"cellular_moves": int(_metrics.cellular_moves),
		"rapier_targets": int(_metrics.rapier_targets),
		"cellular_work": float(_metrics.cellular_work),
		"rapier_work": float(_metrics.rapier_work),
		"offered_work": float(_metrics.offered_work),
		"applied_work": float(_metrics.applied_work),
		"refused_work": float(_metrics.refused_work),
		"last_step_offered_work": float(_metrics.last_step_offered_work),
		"last_step_applied_work": float(_metrics.last_step_applied_work),
		"last_step_refused_work": float(_metrics.last_step_refused_work),
		"events": event_rows,
	}
