class_name CyberUsableRuntime
extends RefCounted

const Catalog = preload("res://scripts/usable_catalog.gd")
const MAX_ACTORS: int = 8
const MAX_PROJECTILES: int = 64
const MAX_OBJECTS: int = 16
const MAX_OBJECTS_PER_ACTOR: int = 4
const MAX_EFFECTS: int = 64
const MAX_HITS: int = 64
const MAX_READS: int = 2048
const MAX_WRITES: int = 128
const MAX_TRACE_STEPS: int = 96
const MAX_CHARGE: float = 100.0
const CHARGE_PER_SECOND: float = 6.0
const MAX_DELTA: float = 1.0 / 15.0
const SENSOR_RADIUS: int = 3
const EMPTY: int = 0
const WALL: int = 1
const POWDERS: Array[int] = [2, 14, 23, 26, 27]
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 32, 33, 36]
const GLASSES: Array[int] = [35, 55, 71, 72]

var _actors: Array = []
var _projectiles: Array = []
var _objects: Array = []
var _effects: Array = []
var _hits_last: Array = []
var _next_entity_id: int = 1
var _tick: int = 0
var read_count_last: int = 0
var write_count_last: int = 0
var source_slots_last: int = 0
var sink_slots_last: int = 0
var refused_reads_last: int = 0
var refused_writes_last: int = 0
var _centres: PackedVector2Array = PackedVector2Array()
var _bounds: Array[Rect2] = []

func _new_actor() -> Dictionary:
	return {
		"usable_index": -1,
		"charge": MAX_CHARGE,
		"cooldown": 0.0,
		"last_result": "none",
		"last_effect_id": 0,
		"trigger_armed": true,
		"alternate_armed": true,
		"position": Vector2.ZERO,
	}

func configure(actor_count: int) -> bool:
	if actor_count < 0 or actor_count > MAX_ACTORS:
		return false
	_actors.clear()
	for _i: int in range(actor_count):
		_actors.append(_new_actor())
	_projectiles.clear()
	_objects.clear()
	_effects.clear()
	_hits_last.clear()
	_tick = 0
	_next_entity_id = 1
	return true

func clear() -> void:
	configure(0)

func actor_count() -> int:
	return _actors.size()

func step(delta: float, world, centres: PackedVector2Array, bounds: Array, actions: Array) -> void:
	_reset_budget()
	if not is_finite(delta) or delta <= 0.0 or actions.size() != _actors.size():
		return
	if world == null or (world.has_method(&"has_failed") and bool(world.has_failed())):
		return
	_tick += 1
	var dt: float = minf(delta, MAX_DELTA)
	_centres = centres.duplicate()
	_bounds.clear()
	for value in bounds:
		if value is Rect2:
			_bounds.append(value)
		else:
			_bounds.append(Rect2())
	while _bounds.size() < _actors.size():
		_bounds.append(Rect2())
	_age_effects(dt)
	_step_projectiles(dt, world)
	_step_objects(dt, world)
	for index: int in range(_actors.size()):
		_advance_actor(index, dt, world, actions[index] if actions[index] is Dictionary else {})

func _reset_budget() -> void:
	read_count_last = 0
	write_count_last = 0
	source_slots_last = 0
	sink_slots_last = 0
	refused_reads_last = 0
	refused_writes_last = 0
	_hits_last.clear()

func _advance_actor(index: int, dt: float, world, action: Dictionary) -> void:
	var actor: Dictionary = _actors[index]
	actor.cooldown = maxf(0.0, float(actor.cooldown) - dt)
	actor.charge = minf(MAX_CHARGE, float(actor.charge) + CHARGE_PER_SECOND * dt)
	if index < _centres.size() and _centres[index].is_finite():
		actor.position = _centres[index]
	var requested: int = int(action.get("usable_index", actor.usable_index))
	if requested < -1 or requested >= Catalog.count():
		requested = -1
	var switched: bool = requested != int(actor.usable_index)
	if switched:
		actor.usable_index = requested
		actor.trigger_armed = not bool(action.get("trigger", false))
		actor.alternate_armed = not bool(action.get("alternate", false))
		actor.last_result = "equipped" if requested >= 0 else "unequipped"
	if requested < 0:
		_actors[index] = actor
		return
	var definition: Dictionary = Catalog.entry(requested)
	var aim: Vector2 = action.get("aim", Vector2.RIGHT)
	if not aim.is_finite() or aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	else:
		aim = aim.normalized()
	var power: float = clampf(float(action.get("power", 1.0)), 0.0, 1.0)
	if not is_finite(power):
		power = 0.0
	var held: bool = bool(action.get("trigger", false))
	var pressed: bool = bool(action.get("trigger_pressed", false))
	var alternate_pressed: bool = bool(action.get("alternate_pressed", false))
	if bool(action.get("cancel", false)):
		held = false
		pressed = false
		alternate_pressed = false
	if alternate_pressed:
		var alternate_result: String = _alternate(index, definition, world)
		if alternate_result != "unsupported":
			actor.last_result = alternate_result
			_actors[index] = actor
			return
	var activate: bool = (held or pressed or alternate_pressed) if StringName(str(definition.category)) == Catalog.CATEGORY_TOOL else pressed
	if activate and float(actor.cooldown) <= 0.0:
		var cost: float = float(definition.get("cost", 0.0))
		if float(actor.charge) + 0.0001 < cost:
			actor.last_result = "no-charge"
		else:
			var result: String = "blocked"
			match StringName(str(definition.category)):
				Catalog.CATEGORY_TOOL:
					var actual_power: float = power
					if alternate_pressed:
						actual_power *= 0.35
					result = _apply_tool(index, definition, aim, actual_power, world)
				Catalog.CATEGORY_PROJECTILE:
					result = _launch(index, definition, aim, power, world)
				Catalog.CATEGORY_OBJECT:
					result = _deploy(index, definition, aim, power, world)
			if result in ["applied", "launched", "deployed"]:
				actor.charge = maxf(0.0, float(actor.charge) - cost)
				actor.cooldown = float(definition.get("cooldown", 0.0))
			actor.last_result = result
	_actors[index] = actor

func _alternate(owner: int, definition: Dictionary, world) -> String:
	var category: StringName = StringName(str(definition.category))
	if category == Catalog.CATEGORY_TOOL:
		return "unsupported"
	if category == Catalog.CATEGORY_OBJECT:
		for i: int in range(_objects.size()):
			var obj: Dictionary = _objects[i]
			if int(obj.owner) == owner and int(obj.usable_index) == Catalog.index_for(StringName(str(definition.id))):
				_objects.remove_at(i)
				return "retrieved"
		return "nothing-to-retrieve"
	var id: StringName = StringName(str(definition.id))
	if not id in [&"sticky_delay_charge", &"timer_airburst", &"oil_igniter"]:
		return "unsupported"
	var candidate: int = -1
	var candidate_id: int = 1 << 30
	for i: int in range(_projectiles.size()):
		var p: Dictionary = _projectiles[i]
		if int(p.owner) != owner or int(p.usable_index) != Catalog.index_for(id):
			continue
		var eligible: bool = false
		if id == &"sticky_delay_charge":
			eligible = str(p.state) == "stuck"
		elif id == &"timer_airburst":
			eligible = str(p.state) == "flight"
		else:
			eligible = str(p.state) == "primed"
		if eligible and int(p.entity_id) < candidate_id:
			candidate = i
			candidate_id = int(p.entity_id)
	if candidate < 0:
		return "nothing-to-activate"
	var p: Dictionary = _projectiles[candidate]
	if id == &"timer_airburst":
		_airburst(candidate, p, world)
	elif id == &"sticky_delay_charge":
		_excavate(p.position, int(definition.radius), world)
		_add_effect(p.position, definition.color, float(definition.radius) + 1.0, "burst")
		_projectiles.remove_at(candidate)
	else:
		_write_if_empty(Vector2i(roundi(p.position.x), roundi(p.position.y)), 6, world)
		_add_effect(p.position, Color(1.0, 0.32, 0.10), 3.0, "ignite")
		_projectiles.remove_at(candidate)
	return "activated"

func _apply_tool(owner: int, definition: Dictionary, aim: Vector2, power: float, world) -> String:
	var origin: Vector2 = _centres[owner] if owner < _centres.size() else Vector2.ZERO
	var reach: float = float(definition.get("range", 20.0)) * lerpf(0.35, 1.0, power)
	var operation: StringName = StringName(str(definition.operation))
	var changed: int = 0
	if operation == &"fan_deposit":
		var rays: int = int(definition.get("rays", 3))
		var steps: int = int(definition.get("steps", 6))
		var spread: float = float(definition.get("spread", 0.3))
		var stride: int = int(definition.get("stride", 1))
		for ray: int in range(rays):
			var t: float = 0.0 if rays == 1 else float(ray) / float(rays - 1) * 2.0 - 1.0
			var direction: Vector2 = aim.rotated(t * spread)
			var previous: Vector2 = origin
			for s: int in range(1, steps + 1):
				var target: Vector2 = origin + direction * reach * float(s) / float(steps)
				var segment: Dictionary = _trace_contact(previous, target, world)
				if segment.get("hit", false) or segment.get("out_of_bounds", false) or segment.get("budget_refused", false):
					break
				previous = target
				if s % stride != 0:
					continue
				var point: Vector2i = Vector2i(target.floor())
				if not _inside_any_actor(Vector2(point) + Vector2(0.5, 0.5)):
					if _write(point, int(definition.material), world):
						changed += 1
	elif operation == &"line_deposit":
		var points: Array[Vector2i] = _line_points(origin, origin + aim * reach, int(definition.get("steps", 12)))
		for point: Vector2i in points:
			var material: int = _read(point, world)
			if material != EMPTY:
				break
			if not _inside_any_actor(Vector2(point) + Vector2(0.5, 0.5)):
				if _write(point, int(definition.material), world):
					changed += 1
	elif operation == &"bead":
		var target_position: Vector2 = origin + aim * reach
		var trace: Dictionary = _trace_contact(origin, target_position, world)
		if trace.get("budget_refused", false) or trace.get("out_of_bounds", false):
			return "blocked"
		var target: Vector2i = trace.get("previous", Vector2i(target_position.floor())) if trace.get("hit", false) else Vector2i(target_position.floor())
		var normal := Vector2(-aim.y, aim.x)
		for offset: int in [-2, -1, 0, 1, 2]:
			var point := Vector2i((Vector2(target) + normal * float(offset)).round())
			if _read(point, world) == EMPTY and not _inside_any_actor(Vector2(point) + Vector2(0.5, 0.5)):
				if _write(point, int(definition.material), world):
					changed += 1
	elif operation == &"stamp":
		var target_position: Vector2 = origin + aim * reach
		var trace: Dictionary = _trace_contact(origin, target_position, world)
		if trace.get("budget_refused", false) or trace.get("out_of_bounds", false):
			return "blocked"
		var target: Vector2i = trace.get("previous", Vector2i(target_position.floor())) if trace.get("hit", false) else Vector2i(target_position.floor())
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
			var point: Vector2i = target + offset
			if _read(point, world) == EMPTY and not _inside_any_actor(Vector2(point) + Vector2(0.5, 0.5)):
				if _write(point, int(definition.material), world):
					changed += 1
	elif operation in [&"line_cut", &"glass_cut"]:
		var points: Array[Vector2i] = _line_points(origin, origin + aim * reach, int(definition.get("steps", 13)))
		for point: Vector2i in points:
			var material: int = _read(point, world)
			if material == WALL:
				break
			if material != EMPTY and (operation == &"line_cut" or GLASSES.has(material)):
				if _write(point, EMPTY, world):
					changed += 1
	elif operation == &"bore":
		var target_position: Vector2 = origin + aim * reach
		var trace: Dictionary = _trace_contact(origin, target_position, world)
		if trace.get("budget_refused", false) or trace.get("out_of_bounds", false):
			return "blocked"
		var target: Vector2i = trace.get("point", Vector2i(target_position.floor())) if trace.get("hit", false) else Vector2i(target_position.floor())
		changed = _edit_disc(target, int(definition.get("radius", 3)), [], world)
	elif operation in [&"powder_sink", &"liquid_sink"]:
		var target_position: Vector2 = origin + aim * reach
		var trace: Dictionary = _trace_contact(origin, target_position, world)
		if trace.get("budget_refused", false) or trace.get("out_of_bounds", false):
			return "blocked"
		var target: Vector2i = trace.get("point", Vector2i(target_position.floor())) if trace.get("hit", false) else Vector2i(target_position.floor())
		var allowed: Array[int] = POWDERS if operation == &"powder_sink" else LIQUIDS
		changed = _edit_disc(target, int(definition.get("radius", 4)), allowed, world)
	if changed <= 0:
		return "blocked"
	_add_effect(origin + aim * reach, definition.color, 2.0 + power * 2.0, str(operation))
	return "applied"

func _launch(owner: int, definition: Dictionary, aim: Vector2, power: float, world) -> String:
	if _projectiles.size() >= MAX_PROJECTILES:
		return "capacity"
	var muzzle: Vector2 = _projectile_muzzle(owner, aim)
	if _inside_foreign_actor(muzzle, owner) >= 0 or _read(Vector2i(muzzle.floor()), world) != EMPTY:
		return "blocked"
	var projectile: Dictionary = {
		"entity_id": _allocate_id(),
		"owner": owner,
		"usable_index": Catalog.index_for(StringName(str(definition.id))),
		"position": muzzle,
		"velocity": aim * float(definition.speed) * lerpf(0.55, 1.0, power),
		"age": 0.0,
		"ttl": float(definition.ttl),
		"gravity": float(definition.gravity),
		"state": "flight",
		"fuse_remaining": float(definition.get("fuse", -1.0)),
		"penetrations": int(definition.get("penetrations", 0)),
		"bounces": int(definition.get("bounces", 0)),
		"color": definition.color,
	}
	_projectiles.append(projectile)
	return "launched"

# Geometry hooks keep catalogue semantics shared by the sampled and physical
# owners. The physical adapter supplies a real published muzzle and body ports.
func _projectile_muzzle(owner: int, aim: Vector2) -> Vector2:
	var origin: Vector2 = _centres[owner] if owner < _centres.size() else Vector2.ZERO
	return origin + aim * 3.0

func _object_ports(obj: Dictionary, output: bool) -> Array[Vector2i]:
	var center := Vector2i(Vector2(obj.position).round())
	var x: int = 2 if output else -2
	return [center + Vector2i(x, -1), center + Vector2i(x, 1)]

func _write_read_cost() -> int:
	return 1

func _deploy(owner: int, definition: Dictionary, aim: Vector2, power: float, world) -> String:
	if _objects.size() >= MAX_OBJECTS or _owned_object_count(owner) >= MAX_OBJECTS_PER_ACTOR:
		return "capacity"
	var origin: Vector2 = _centres[owner] if owner < _centres.size() else Vector2.ZERO
	var distance: float = lerpf(8.0, 20.0, power)
	var center := Vector2i((origin + aim * distance).round())
	var placement_trace: Dictionary = _trace_contact(origin, Vector2(center), world)
	if placement_trace.get("hit", false) or placement_trace.get("out_of_bounds", false) or placement_trace.get("budget_refused", false):
		return "blocked"
	for y: int in range(center.y - 2, center.y + 3):
		for x: int in range(center.x - 2, center.x + 3):
			if _read(Vector2i(x,y), world) != EMPTY or _inside_any_actor(Vector2(x + 0.5, y + 0.5)):
				return "blocked"
	var obj: Dictionary = {
		"entity_id": _allocate_id(),
		"owner": owner,
		"usable_index": Catalog.index_for(StringName(str(definition.id))),
		"position": Vector2(center),
		"age": 0.0,
		"lifetime": float(definition.get("lifetime", 45.0)),
		"cooldown": 0.0,
		"stock": int(definition.get("stock", 16)),
		"cycles": 0,
		"status": "waiting",
		"color": definition.color,
	}
	_objects.append(obj)
	_add_effect(Vector2(center), definition.color, 3.0, "deploy")
	return "deployed"

func _step_projectiles(dt: float, world) -> void:
	var i: int = 0
	while i < _projectiles.size():
		var p: Dictionary = _projectiles[i]
		var definition: Dictionary = Catalog.entry(int(p.usable_index))
		p.age = float(p.age) + dt
		if str(p.state) in ["stuck", "primed"]:
			p.fuse_remaining = float(p.fuse_remaining) - dt
			if float(p.fuse_remaining) <= 0.0:
				if str(p.state) == "stuck":
					_excavate(p.position, int(definition.radius), world)
					_add_effect(p.position, definition.color, float(definition.radius) + 1.0, "burst")
				else:
					_write_if_empty(Vector2i(roundi(p.position.x), roundi(p.position.y)), 6, world)
					_add_effect(p.position, Color(1.0,0.32,0.10), 3.0, "ignite")
				_projectiles.remove_at(i)
				continue
			_projectiles[i] = p
			i += 1
			continue
		if str(p.state) == "armed":
			if _sensor_has(Vector2i(Vector2(p.position).round()), [3,24], int(definition.get("sensor_radius", 4)), world):
				_write_if_empty(Vector2i(roundi(p.position.x), roundi(p.position.y)), 6, world)
				_add_effect(p.position, definition.color, 3.0, "wet-trigger")
				_projectiles.remove_at(i)
				continue
			if float(p.age) >= float(p.ttl):
				_projectiles.remove_at(i)
				continue
			_projectiles[i] = p
			i += 1
			continue
		# Fuse time is simulation-time authority and advances even if movement reads saturate.
		if StringName(str(definition.operation)) == &"airburst":
			p.fuse_remaining = float(p.fuse_remaining) - dt
			if float(p.fuse_remaining) <= 0.0:
				_projectiles[i] = p
				_airburst(i, p, world)
				continue
		if float(p.age) >= float(p.ttl):
			_projectiles.remove_at(i)
			continue
		p.velocity = Vector2(p.velocity) + Vector2(0.0, float(p.gravity) * dt)
		var start: Vector2 = p.position
		var finish: Vector2 = start + Vector2(p.velocity) * dt
		var actor_hit: int = _first_actor_segment_hit(start, finish, int(p.owner))
		if actor_hit >= 0:
			_record_hit(p, actor_hit)
			_projectiles.remove_at(i)
			continue
		var contact: Dictionary = _trace_contact(start, finish, world)
		if contact.get("budget_refused", false):
			_projectiles[i] = p
			i += 1
			continue
		if contact.get("hit", false):
			var keep: bool = _impact_projectile(i, p, definition, contact, world)
			if keep:
				i += 1
			continue
		if contact.get("out_of_bounds", false):
			_projectiles.remove_at(i)
			continue
		p.position = finish
		_projectiles[i] = p
		i += 1

func _impact_projectile(index: int, p: Dictionary, definition: Dictionary, contact: Dictionary, world) -> bool:
	var operation: StringName = StringName(str(definition.operation))
	var point: Vector2i = contact.point
	var reachable: Vector2 = Vector2(contact.previous) + Vector2(0.5,0.5)
	p.position = Vector2(point) + Vector2(0.5,0.5)
	if operation == &"penetrate":
		if int(contact.material) != WALL and _write(point, EMPTY, world):
			p.penetrations = int(p.penetrations) - 1
			if int(p.penetrations) > 0:
				p.velocity = Vector2(p.velocity) * 0.72
				p.position = Vector2(contact.previous) + Vector2(p.velocity).normalized() * 1.05
				_projectiles[index] = p
				return true
	elif operation == &"ricochet" and int(p.bounces) > 0:
		p.bounces = int(p.bounces) - 1
		var prev: Vector2i = contact.previous
		var delta: Vector2i = point - prev
		var velocity: Vector2 = p.velocity
		if delta.x != 0:
			velocity.x = -velocity.x
		if delta.y != 0:
			velocity.y = -velocity.y
		if delta == Vector2i.ZERO:
			velocity = -velocity
		p.velocity = velocity * 0.72
		p.position = Vector2(prev) + Vector2(0.5,0.5)
		_projectiles[index] = p
		return true
	elif operation == &"sticky_delayed":
		p.position = reachable
		p.state = "stuck"
		p.velocity = Vector2.ZERO
		p.fuse_remaining = float(definition.fuse)
		_projectiles[index] = p
		return true
	elif operation == &"staged_igniter":
		_payload(point, int(definition.material), int(definition.radius), world)
		p.position = reachable
		p.state = "primed"
		p.velocity = Vector2.ZERO
		p.fuse_remaining = float(definition.fuse)
		_projectiles[index] = p
		return true
	elif operation == &"water_sensor":
		p.position = reachable
		p.state = "armed"
		p.velocity = Vector2.ZERO
		_projectiles[index] = p
		return true
	elif operation == &"material_payload":
		_payload(point, int(definition.material), int(definition.radius), world)
	elif operation == &"impact_chip":
		if int(contact.material) != WALL:
			_edit_disc(point, int(definition.radius), [], world)
	_add_effect(p.position, definition.color, float(definition.get("radius",1)) + 1.0, str(operation))
	_projectiles.remove_at(index)
	return false

func _airburst(index: int, p: Dictionary, world) -> void:
	var available: int = MAX_PROJECTILES - (_projectiles.size() - 1)
	var children: int = mini(int(Catalog.entry(int(p.usable_index)).get("children", 5)), available)
	var owner: int = int(p.owner)
	var base_angle: float = Vector2(p.velocity).angle()
	_projectiles.remove_at(index)
	for child: int in range(children):
		var angle: float = base_angle + lerpf(-0.52, 0.52, float(child) / maxf(1.0, float(children - 1)))
		var d: Vector2 = Vector2.RIGHT.rotated(angle)
		_projectiles.append({
			"entity_id": _allocate_id(), "owner": owner,
			"usable_index": Catalog.index_for(&"impact_slug"),
			"position": p.position, "velocity": d * 135.0,
			"age": 0.0, "ttl": 0.8, "gravity": 18.0, "state": "flight",
			"fuse_remaining": -1.0, "penetrations": 0, "bounces": 0,
			"color": Color(1.0,0.82,0.30),
		})
	_add_effect(p.position, Color(1.0,0.76,0.22), 4.0, "airburst")

func _step_objects(dt: float, world) -> void:
	var i: int = 0
	while i < _objects.size():
		var obj: Dictionary = _objects[i]
		obj.age = float(obj.age) + dt
		obj.cooldown = maxf(0.0, float(obj.cooldown) - dt)
		if float(obj.age) >= float(obj.lifetime) or int(obj.stock) <= 0:
			_objects.remove_at(i)
			continue
		if float(obj.cooldown) <= 0.0:
			var definition: Dictionary = Catalog.entry(int(obj.usable_index))
			var result: String = _object_cycle(obj, definition, world)
			obj.status = result
			if result == "processed":
				obj.stock = int(obj.stock) - 1
				obj.cycles = int(obj.cycles) + 1
				obj.cooldown = float(definition.get("cooldown",0.35))
		_objects[i] = obj
		i += 1

func _object_cycle(obj: Dictionary, definition: Dictionary, world) -> String:
	var center := Vector2i(Vector2(obj.position).round())
	var outputs: Array[Vector2i] = _object_ports(obj, true)
	if StringName(str(definition.operation)) == &"firewarden":
		if not _sensor_has(center, [int(definition.sensor_material)], SENSOR_RADIUS, world):
			return "waiting-condition"
		if _read(outputs[0], world) != EMPTY:
			return "blocked-output"
		if write_count_last + 1 > MAX_WRITES or read_count_last + _write_read_cost() > MAX_READS:
			refused_writes_last += 1
			return "capacity"
		if _write(outputs[0], 3, world):
			_add_effect(Vector2(center), definition.color, 2.0, "firewarden")
			return "processed"
		return "capacity"
	var required: Array[int] = []
	for recipe in definition.get("inputs", []):
		for _n: int in range(int(recipe[1])):
			required.append(int(recipe[0]))
	var inputs: Array[Vector2i] = _object_ports(obj, false)
	if required.size() > inputs.size():
		return "invalid-recipe"
	for ri: int in range(required.size()):
		if _read(inputs[ri], world) != required[ri]:
			return "waiting-input"
	var catalyst: Array = definition.get("catalyst_any", [])
	if not catalyst.is_empty():
		var cats: Array[int] = []
		for value in catalyst:
			cats.append(int(value))
		if not _sensor_has(center, cats, SENSOR_RADIUS, world):
			return "waiting-condition"
	var produced: Array[int] = []
	for recipe in definition.get("outputs", []):
		for _n: int in range(int(recipe[1])):
			produced.append(int(recipe[0]))
	if produced.size() > outputs.size():
		return "invalid-recipe"
	for oi: int in range(produced.size()):
		if _read(outputs[oi], world) != EMPTY:
			return "blocked-output"
	var writes_needed: int = required.size() + produced.size()
	if write_count_last + writes_needed > MAX_WRITES or read_count_last + writes_needed * _write_read_cost() > MAX_READS:
		refused_writes_last += writes_needed
		return "capacity"
	for ri: int in range(required.size()):
		if not _write(inputs[ri], EMPTY, world):
			return "capacity"
	for oi: int in range(produced.size()):
		if not _write(outputs[oi], produced[oi], world):
			return "capacity"
	_add_effect(Vector2(center), definition.color, 2.5, "process")
	return "processed"

func _payload(center: Vector2i, material: int, radius: int, world) -> int:
	var changed: int = 0
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var point := Vector2i(x,y)
			if Vector2(point - center).length() > float(radius) + 0.25:
				continue
			if _read(point, world) == EMPTY and not _inside_any_actor(Vector2(point) + Vector2(0.5,0.5)):
				if _write(point, material, world):
					changed += 1
	return changed

func _excavate(position: Vector2, radius: int, world) -> int:
	return _edit_disc(Vector2i(position.round()), radius, [], world)

func _edit_disc(center: Vector2i, radius: int, allowed: Array[int], world) -> int:
	var changed: int = 0
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var point := Vector2i(x,y)
			if Vector2(point - center).length() > float(radius) + 0.25:
				continue
			if _inside_any_actor(Vector2(point) + Vector2(0.5,0.5)):
				continue
			var material: int = _read(point, world)
			if material in [EMPTY, WALL]:
				continue
			if not allowed.is_empty() and not allowed.has(material):
				continue
			if _write(point, EMPTY, world):
				changed += 1
	return changed

func _trace_contact(start: Vector2, finish: Vector2, world) -> Dictionary:
	var distance: float = start.distance_to(finish)
	var steps: int = clampi(ceili(distance * 2.0), 1, MAX_TRACE_STEPS)
	var previous := Vector2i(start.floor())
	var last_t: float = 0.0
	for step_index: int in range(1, steps + 1):
		var t: float = float(step_index) / float(steps)
		var point := Vector2i(start.lerp(finish, t).floor())
		if point == previous:
			last_t = t
			continue
		if point.x != previous.x and point.y != previous.y:
			for corner: Vector2i in [Vector2i(point.x, previous.y), Vector2i(previous.x, point.y)]:
				if not _inside_world(corner):
					return {"out_of_bounds":true,"hit":false,"previous":previous}
				var side: int = _read(corner, world)
				if side == -2:
					return {"budget_refused":true}
				if side != EMPTY:
					return {"hit":true,"point":corner,"previous":previous,"material":side,"t":last_t}
		if not _inside_world(point):
			return {"out_of_bounds":true,"hit":false,"previous":previous}
		var material: int = _read(point, world)
		if material == -2:
			return {"budget_refused":true}
		if material != EMPTY:
			return {"hit":true,"point":point,"previous":previous,"material":material,"t":t}
		previous = point
		last_t = t
	return {"hit":false,"out_of_bounds":false,"previous":previous}

func _line_points(start: Vector2, finish: Vector2, _max_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var distance: float = start.distance_to(finish)
	var steps: int = clampi(maxi(1, ceili(distance * 2.0)), 1, MAX_TRACE_STEPS)
	var last := Vector2i(1 << 29, 1 << 29)
	for i: int in range(1, steps + 1):
		var point := Vector2i(start.lerp(finish, float(i) / float(steps)).floor())
		if point != last:
			result.append(point)
			last = point
	return result

func _sensor_has(center: Vector2i, materials: Array[int], radius: int, world) -> bool:
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var material: int = _read(Vector2i(x,y), world)
			if material == -2:
				return false
			if materials.has(material):
				return true
	return false

func _read(point: Vector2i, world) -> int:
	if read_count_last >= MAX_READS:
		refused_reads_last += 1
		return -2
	if not _inside_world(point):
		return WALL
	read_count_last += 1
	return int(world.material_at(point.x, point.y))

func _write(point: Vector2i, material: int, world) -> bool:
	if write_count_last >= MAX_WRITES or not _inside_world(point):
		refused_writes_last += 1
		return false
	var before: int = _read(point, world)
	if before == -2 or before == material:
		return false
	if before == WALL:
		return false
	world.emit_disc(point.x, point.y, 0, material)
	write_count_last += 1
	if before == EMPTY and material != EMPTY:
		source_slots_last += 1
	elif before != EMPTY and material == EMPTY:
		sink_slots_last += 1
	elif before != EMPTY and material != EMPTY:
		sink_slots_last += 1
		source_slots_last += 1
	return true

func _write_if_empty(point: Vector2i, material: int, world) -> bool:
	return _read(point, world) == EMPTY and _write(point, material, world)

func _inside_world(point: Vector2i) -> bool:
	return point.x >= 0 and point.y >= 0 and point.x < 1024 and point.y < 1024

func _inside_any_actor(point: Vector2) -> bool:
	for rect: Rect2 in _bounds:
		if rect.has_point(point):
			return true
	return false

func _inside_foreign_actor(point: Vector2, owner: int) -> int:
	for i: int in range(_bounds.size()):
		if i != owner and _bounds[i].has_point(point):
			return i
	return -1

func _first_actor_segment_hit(start: Vector2, finish: Vector2, owner: int) -> int:
	var best: int = -1
	var best_t: float = 2.0
	for i: int in range(_bounds.size()):
		if i == owner:
			continue
		var t: float = _segment_rect_t(start, finish, _bounds[i])
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	return best

func _segment_rect_t(start: Vector2, finish: Vector2, rect: Rect2) -> float:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return -1.0
	var delta: Vector2 = finish - start
	var t_min: float = 0.0
	var t_max: float = 1.0
	for axis: int in [0,1]:
		var s: float = start.x if axis == 0 else start.y
		var d: float = delta.x if axis == 0 else delta.y
		var lo: float = rect.position.x if axis == 0 else rect.position.y
		var hi: float = rect.end.x if axis == 0 else rect.end.y
		if absf(d) < 0.000001:
			if s < lo or s > hi:
				return -1.0
		else:
			var inv: float = 1.0 / d
			var t1: float = (lo - s) * inv
			var t2: float = (hi - s) * inv
			if t1 > t2:
				var swap: float = t1
				t1 = t2
				t2 = swap
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return -1.0
	return t_min

func _record_hit(projectile: Dictionary, target: int) -> void:
	if _hits_last.size() >= MAX_HITS:
		return
	_hits_last.append({
		"tick": _tick,
		"owner": int(projectile.owner),
		"target": target,
		"projectile": int(projectile.entity_id),
		"usable_index": int(projectile.usable_index),
	})

func _add_effect(position: Vector2, color: Color, radius: float, kind: String) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append({
		"id": _allocate_id(),
		"position": position,
		"color": color,
		"radius": radius,
		"kind": kind,
		"age": 0.0,
		"ttl": 0.24,
	})

func _age_effects(dt: float) -> void:
	var i: int = _effects.size() - 1
	while i >= 0:
		var effect: Dictionary = _effects[i]
		effect.age = float(effect.age) + dt
		if float(effect.age) >= float(effect.ttl):
			_effects.remove_at(i)
		else:
			_effects[i] = effect
		i -= 1

func _owned_object_count(owner: int) -> int:
	var count: int = 0
	for obj: Dictionary in _objects:
		if int(obj.owner) == owner:
			count += 1
	return count

func _allocate_id() -> int:
	var value: int = _next_entity_id
	_next_entity_id += 1
	if _next_entity_id <= 0:
		_next_entity_id = 1
	return value

func snapshot() -> Dictionary:
	var actors: Array = []
	for actor: Dictionary in _actors:
		actors.append(actor.duplicate(true))
	var projectiles: Array = []
	for p: Dictionary in _projectiles:
		projectiles.append(p.duplicate(true))
	var objects: Array = []
	for obj: Dictionary in _objects:
		objects.append(obj.duplicate(true))
	var effects: Array = []
	for effect: Dictionary in _effects:
		effects.append(effect.duplicate(true))
	var hits: Array = []
	for hit: Dictionary in _hits_last:
		hits.append(hit.duplicate(true))
	return {
		"version": 1,
		"tick": _tick,
		"catalogue_size": Catalog.count(),
		"actor_count": _actors.size(),
		"actors": actors,
		"projectiles": projectiles,
		"objects": objects,
		"effects": effects,
		"hits_last": hits,
		"read_count_last": read_count_last,
		"write_count_last": write_count_last,
		"source_slots_last": source_slots_last,
		"sink_slots_last": sink_slots_last,
		"refused_reads_last": refused_reads_last,
		"refused_writes_last": refused_writes_last,
		"capacities": {
			"actors": MAX_ACTORS, "projectiles": MAX_PROJECTILES,
			"objects": MAX_OBJECTS, "objects_per_actor": MAX_OBJECTS_PER_ACTOR,
			"effects": MAX_EFFECTS, "hits": MAX_HITS,
			"reads_per_tick": MAX_READS, "writes_per_tick": MAX_WRITES,
		},
		"accounting_unit": "authored-cell-slots",
	}
