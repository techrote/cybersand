class_name CyberPhysicalActorRig
extends Node2D

# ACT-004's main-thread articulation and actuation owner. The bridge, not this
# node, steps the Rapier space. Only copied observations/effect requests leave
# this owner. Legacy rectangles share collider, drawing and native mask. New
# player wheels explicitly use round Rapier collision and a square native mask.
# Assistance is an authored game mechanic; no flywheel momentum model is implied.
const MAX_PARTS: int = 8
const MAX_JOINTS: int = 14
const MAX_MOUNTS: int = 3
const MAX_RAYS: int = 24
const MAX_CONTACTS_PER_PART: int = 8
const MAX_DELTA: float = 1.0 / 30.0
const MAX_ACCELERATION: float = 1200.0
const MAX_ANGULAR_ACCELERATION: float = 100.0
const MAX_IMPULSE_PER_MASS: float = 100.0
const MAX_ROPE_LENGTH: float = 96.0
const MIN_ROPE_LENGTH: float = 6.0
const PROFILE_VERSION: int = 1
const TERRAIN_MASK: int = 1
const PlayerVehicle = preload("res://scripts/player_vehicle_controller.gd")
const PlayerAcrobat = preload("res://scripts/player_acrobat_controller.gd")
const FlightProfile = preload("res://scripts/physical_flight_profile.gd")
const FlightController = preload("res://scripts/physical_flight_controller.gd")

var rig_id: StringName = &""
var actor_slot: int = 0
var epoch: int = 0
var configured: bool = false
var fault: String = ""
var energy: float = 1.0
var charge: float = 0.0
var cooldown: float = 0.0
var gait_phase: float = 0.0
var rope_attached: bool = false
var anchor: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var tension: float = 0.0
var gripped: bool = false

var _definition: Dictionary = {}
var _profile: Dictionary = {}
var _parts: Array[RigidBody2D] = []
var _sizes: PackedVector2Array = PackedVector2Array()
var _part_defs: Array = []
var _joints: Array[Dictionary] = []
var _mounts: Array[Dictionary] = []
var _exclusions: Array[RID] = []
var _effects: Array[Dictionary] = []
var _transforms: Array[Transform2D] = []
var _velocities: PackedVector2Array = PackedVector2Array()
var _angular_velocities: PackedFloat32Array = PackedFloat32Array()
var _inertias: PackedFloat32Array = PackedFloat32Array()
var _thrusters: PackedInt32Array = PackedInt32Array()
var _thruster_levels: Vector2 = Vector2.ZERO
var _thrust_weights: PackedFloat32Array = PackedFloat32Array()
var _detached: Dictionary = {}
var _total_mass: float = 1.0
var _assembly_inertia: float = 1.0
var _observation: Dictionary = {}
var _action: Dictionary = {}
var _previous_buttons: Vector3i = Vector3i.ZERO
var _smoothed_move: Vector2 = Vector2.ZERO
var _smoothed_trim: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _facing: float = 1.0
var _gravity: float = 156.0
var _power_enabled: bool = true
var _flight_mode: bool = false
var _coast_mode: bool = false
var _air_jumps: int = 0
var _grip_normal: Vector2 = Vector2.UP
var _grip_local_offset: Vector2 = Vector2.ZERO
var _support: Dictionary = {}
var _sensors: Dictionary = {}
var _ray_count: int = 0
var _tick: int = 0
var _effect_sequence: int = 0
var _tool_cooldown: float = 0.0
var _last_impulse: Vector2 = Vector2.ZERO
var _last_torque_impulse: float = 0.0
var _last_energy_used: float = 0.0
var _movement_limited: bool = false
var _charge_armed: bool = false
var _last_centre: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _support_age: float = 1.0
var _equipment_aim: Vector2 = Vector2.RIGHT
var _equipment_aim_enabled: bool = false
var _equipment_state: Dictionary = {}
var _fixed_equipment: Dictionary = {}
var _player_controller: RefCounted
var _player_joint_targets: Dictionary = {}
var _player_wheel_speeds: Dictionary = {}
var _player_free_joints: Dictionary = {}
var _flight_controller: RefCounted
var _flight_capabilities: Dictionary = {}
var _flight_mode_name: String = "passive_no_lease"


static func validate_definition(definition: Dictionary) -> String:
	if str(definition.get("id", "")).is_empty():
		return "missing rig id"
	var parts = definition.get("parts", null)
	var joints = definition.get("joints", [])
	var mounts = definition.get("mounts", [])
	if not parts is Array or parts.is_empty() or parts.size() > MAX_PARTS:
		return "part capacity (1..8 including held parts)"
	if not joints is Array or joints.size() > MAX_JOINTS:
		return "joint capacity"
	if not mounts is Array or mounts.size() > MAX_MOUNTS:
		return "mount capacity"
	var names: Dictionary = {}
	for item in parts:
		if not item is Dictionary:
			return "part is not an object"
		var id: String = str(item.get("id", ""))
		if id.is_empty() or names.has(id):
			return "missing or duplicate part id"
		names[id] = true
		if str(item.get("shape", "rectangle")) not in ["rectangle", "rect", "circle"]:
			return "unsupported collider shape"
		if not _finite_vector(item.get("offset", null)) or not _finite_vector(item.get("size", null)):
			return "nonfinite part geometry"
		var size: Vector2 = item.size
		var offset: Vector2 = item.offset
		if str(item.get("shape", "rectangle")) == "circle" and (not is_equal_approx(size.x, size.y) \
			or str(item.get("native_mask", "")) != "circumscribed_rectangle"):
			return "circle requires equal diameters and declared circumscribed native mask"
		if size.x < 0.5 or size.y < 0.5 or size.x > 64.0 or size.y > 64.0 or offset.length() > 64.0:
			return "part geometry outside authored envelope"
		if not _finite_number(item.get("mass", 1.0)) or float(item.get("mass", 1.0)) < 0.02 \
			or float(item.get("mass", 1.0)) > 20.0:
			return "invalid part mass"
		for key: String in ["angle", "friction", "bounce"]:
			if item.has(key) and not _finite_number(item[key]):
				return "nonfinite part parameter"
		if absf(float(item.get("angle", 0.0))) > TAU * 4.0:
			return "part angle outside authored envelope"
	var connected: Dictionary = {0: true}
	for item in joints:
		if not item is Dictionary:
			return "joint is not an object"
		if typeof(item.get("a", null)) != TYPE_INT or typeof(item.get("b", null)) != TYPE_INT:
			return "joint body index is not an integer"
		var a: int = int(item.a)
		var b: int = int(item.b)
		if a < 0 or b < 0 or a >= parts.size() or b >= parts.size() or a == b:
			return "invalid joint body pair"
		if str(item.get("type", "")) not in ["rotary", "slide", "spring"]:
			return "unsupported joint type"
		if not _finite_vector(item.get("anchor", null)):
			return "invalid joint anchor"
		if Vector2(item.anchor).length() > 96.0:
			return "joint anchor outside authored envelope"
		if item.has("limits") and not _finite_vector(item.limits):
			return "invalid joint limits"
		if item.has("limits") and item.limits.x > item.limits.y:
			return "reversed joint limits"
		if item.has("limits") and maxf(absf(float(item.limits.x)), absf(float(item.limits.y))) > 64.0:
			return "joint limits outside authored envelope"
		if str(item.type) != "rotary":
			if not _finite_vector(item.get("axis", null)) or item.axis.length_squared() < 0.00001 \
				or item.axis.length_squared() > 1000000.0:
				return "invalid slide axis"
		for key: String in ["rest_length", "stiffness", "damping", "motor_speed", "max_force", "phase", "softness", "deployment_sign"]:
			if item.has(key) and not _finite_number(item[key]):
				return "nonfinite joint parameter"
		if item.has("deployment_sign") and absf(float(item.deployment_sign)) != 1.0:
			return "joint deployment sign must be -1 or 1"
		if float(item.get("max_force", 180.0)) <= 0.0 or float(item.get("max_force", 180.0)) > 5000.0:
			return "joint effort outside bounded profile"
		if float(item.get("motor_speed", 8.0)) < 0.0 or float(item.get("motor_speed", 8.0)) > 80.0:
			return "joint speed outside bounded profile"
	# Reject accidental cosmetic/unconnected parts before allocating any bodies.
	for _pass: int in range(MAX_PARTS):
		for item in joints:
			if connected.has(int(item.a)) or connected.has(int(item.b)):
				connected[int(item.a)] = true
				connected[int(item.b)] = true
	if connected.size() != parts.size():
		return "disconnected assembly"
	for item in mounts:
		if not item is Dictionary or typeof(item.get("part", null)) != TYPE_INT:
			return "invalid mount"
		if int(item.part) < 0 or int(item.part) >= parts.size() or not _finite_vector(item.get("offset", null)):
			return "invalid mount part or offset"
		if Vector2(item.offset).length() > 64.0:
			return "mount offset outside authored envelope"
		if item.has("held_part") and (typeof(item.held_part) != TYPE_INT or int(item.held_part) <= 0 or int(item.held_part) >= parts.size()):
			return "invalid held-part index"
		if item.has("held_part") and int(item.held_part) == int(item.part):
			return "held part cannot attach to itself"
		if item.has("limits") and (not _finite_vector(item.limits) or item.limits.x > item.limits.y):
			return "invalid mount aiming limits"
		for key: String in ["angle", "reach", "radius", "recoil", "cooldown"]:
			if item.has(key) and not _finite_number(item[key]):
				return "nonfinite mount parameter"
	var profile = definition.get("profile", {})
	if not profile is Dictionary:
		return "invalid gameplay profile"
	for value in profile.values():
		if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and not is_finite(float(value)):
			return "nonfinite gameplay profile"
	if StringName(str(definition.id)) in FlightProfile.IDS or definition.has("flight_profile"):
		var flight: Variant = definition.get("flight_profile")
		var invalid: String = FlightProfile.validate(flight)
		if not invalid.is_empty():
			return "invalid flight profile: " + invalid
		if str(flight.id) != str(definition.id) or definition.get("action_profile") != FlightProfile.ACTION_PROFILE:
			return "flight profile identity mismatch"
		if parts.size() != 1 or not joints.is_empty() or not mounts.is_empty() \
			or definition.get("equipment_preparation") != "none":
			return "flight requires one chassis without joints or equipment"
		var part: Dictionary = parts[0]
		var size := Vector2(float(flight.collider_size[0]), float(flight.collider_size[1]))
		if Vector2(part.offset) != Vector2.ZERO or Vector2(part.size) != size \
			or str(part.get("shape", "")) != "rectangle" \
			or float(part.mass) != float(flight.mass) \
			or not _finite_number(part.get("inertia")) or float(part.inertia) != float(flight.inertia) \
			or part.get("friction") != flight.friction or part.get("bounce") != flight.bounce:
			return "flight chassis does not match resolved profile"
		if profile.size() != 4 or profile.get("movement") != "4ly_velocity" \
			or profile.get("gravity") != flight.gravity or profile.get("air_drag") != flight.linear_drag \
			or profile.get("angular_drag") != flight.angular_drag:
			return "flight physics settings do not match resolved profile"
	return ""


static func _finite_vector(value) -> bool:
	return typeof(value) == TYPE_VECTOR2 and value.is_finite()


static func _finite_number(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func valid_action(action: Dictionary) -> bool:
	for key: String in ["move", "aim"]:
		if action.has(key) and not _finite_vector(action[key]):
			return false
	for key: String in ["effort", "trim", "reel"]:
		if action.has(key) and not _finite_number(action[key]):
			return false
	for key: String in ["primary", "secondary", "auxiliary", "tool", "release_usable", "attach_usable"]:
		if action.has(key) and typeof(action[key]) != TYPE_BOOL:
			return false
	return true


func configure(definition: Dictionary, origin: Vector2, slot: int = 0, incarnation: int = 1) -> Error:
	if configured:
		return ERR_ALREADY_IN_USE
	if not is_inside_tree() or not origin.is_finite() or slot < 0 or slot >= 8 or incarnation <= 0:
		return ERR_INVALID_PARAMETER
	var invalid: String = validate_definition(definition)
	if not invalid.is_empty():
		fault = invalid
		return ERR_INVALID_DATA
	var flight_gravity_scale: float = 0.0
	if definition.has("flight_profile"):
		var environment_gravity: Variant = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
		var environment_direction: Variant = ProjectSettings.get_setting("physics/2d/default_gravity_vector", Vector2.DOWN)
		var environment_hz: Variant = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)
		if not _finite_number(environment_gravity) or float(environment_gravity) <= 0.0 \
			or not _finite_vector(environment_direction) or environment_direction != Vector2.DOWN \
			or not _finite_number(environment_hz) or float(environment_hz) != 60.0:
			fault = "flight requires 60 Hz and positive downward project gravity"
			return ERR_INVALID_DATA
		var backend_gravity: float = Vector2(float(environment_gravity), 0.0).x
		if not is_finite(backend_gravity) or backend_gravity <= 0.0:
			fault = "flight project gravity is not representable by the physics backend"
			return ERR_INVALID_DATA
		# Validate the backend's real_t representation before allocating a body.
		# The legacy minimum divisor would silently halve authored gravity when
		# the project default is 0.5; flight must preserve its resolved profile.
		flight_gravity_scale = Vector2(float(definition.flight_profile.gravity) / backend_gravity, 0.0).x
		if not is_finite(flight_gravity_scale) \
			or not is_equal_approx(flight_gravity_scale * backend_gravity, float(definition.flight_profile.gravity)):
			fault = "flight gravity scale is not representable by the physics backend"
			return ERR_INVALID_DATA
	_definition = definition.duplicate(true)
	_profile = _definition.get("profile", {})
	_part_defs = _definition.parts
	_player_controller = null
	_flight_controller = null
	_flight_capabilities.clear()
	_flight_mode_name = "passive_no_lease"
	if _definition.has("flight_profile"):
		_flight_controller = FlightController.new()
		if not _flight_controller.configure(_definition.flight_profile):
			return ERR_INVALID_DATA
		_flight_capabilities = FlightProfile.descriptor(_definition.flight_profile)
		_flight_capabilities["controller_hash"] = FlightController.controller_hash()
	if str(_profile.get("player_controller", "")) == "acrobat":
		_player_controller = PlayerAcrobat.new()
	elif str(_profile.get("player_controller", "")) == "vehicle":
		_player_controller = PlayerVehicle.new()
	rig_id = StringName(str(_definition.id))
	actor_slot = slot
	epoch = incarnation
	_gravity = clampf(float(_profile.get("gravity", 156.0)), 0.0, 500.0)
	_total_mass = 0.0
	_assembly_inertia = 0.0
	for index: int in range(_part_defs.size()):
		var part: Dictionary = _part_defs[index]
		var body: RigidBody2D = RigidBody2D.new()
		body.name = "Part_%s" % str(part.id)
		body.position = to_local(origin + Vector2(part.offset))
		body.rotation = float(part.get("angle", 0.0))
		body.mass = float(part.get("mass", 1.0))
		body.inertia = maxf(0.01, body.mass * Vector2(part.size).length_squared() / 12.0)
		if _flight_controller != null:
			body.inertia = float(_definition.flight_profile.inertia)
		if str(part.get("shape", "rectangle")) == "circle":
			body.inertia = maxf(0.01, body.mass * pow(float(part.size.x) * 0.5, 2.0) * 0.5)
		body.gravity_scale = _gravity / maxf(1.0, float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)))
		if _flight_controller != null:
			body.gravity_scale = flight_gravity_scale
		body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		body.linear_damp = clampf(float(_profile.get("air_drag", 0.10)), 0.0, 3.0)
		body.angular_damp = clampf(float(_profile.get("angular_drag", 0.25)), 0.0, 8.0)
		body.max_contacts_reported = MAX_CONTACTS_PER_PART
		body.contact_monitor = true
		body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		body.collision_layer = TERRAIN_MASK
		body.collision_mask = TERRAIN_MASK
		var material: PhysicsMaterial = PhysicsMaterial.new()
		material.friction = clampf(float(part.get("friction", 0.8)), 0.0, 1.0)
		material.bounce = clampf(float(part.get("bounce", 0.02)), 0.0, 0.6)
		body.physics_material_override = material
		var collider: CollisionShape2D = CollisionShape2D.new()
		if str(part.get("shape", "rectangle")) == "circle":
			var circle := CircleShape2D.new()
			circle.radius = float(part.size.x) * 0.5
			collider.shape = circle
		else:
			var rectangle: RectangleShape2D = RectangleShape2D.new()
			rectangle.size = part.size
			collider.shape = rectangle
		body.add_child(collider)
		add_child(body)
		_parts.append(body)
		_sizes.append(part.size)
		_inertias.append(body.inertia)
		if str(part.get("role", "")) in ["thruster", "rotor"]:
			_thrusters.append(index)
		_exclusions.append(body.get_rid())
		_total_mass += body.mass
		_assembly_inertia += body.inertia + body.mass * Vector2(part.offset).length_squared()
	for a: int in range(_parts.size()):
		for b: int in range(a + 1, _parts.size()):
			_parts[a].add_collision_exception_with(_parts[b])
			_parts[b].add_collision_exception_with(_parts[a])
	for joint: Dictionary in _definition.get("joints", []):
		_create_joint(joint, origin)
	for mount: Dictionary in _definition.get("mounts", []):
		var instance: Dictionary = mount.duplicate(true)
		instance["attached"] = true
		_mounts.append(instance)
	_transforms.resize(_parts.size())
	_velocities.resize(_parts.size())
	_angular_velocities.resize(_parts.size())
	configured = true
	fault = ""
	energy = 1.0
	charge = 0.0
	cooldown = 0.0
	gait_phase = 0.0
	_tick = 0
	_effect_sequence = 0
	_tool_cooldown = 0.0
	_power_enabled = true
	_coast_mode = false
	_previous_buttons = Vector3i.ZERO
	_smoothed_move = Vector2.ZERO
	_smoothed_trim = 0.0
	_thruster_levels = Vector2.ZERO
	_aim = Vector2.RIGHT
	_facing = 1.0
	_stuck_time = 0.0
	_support_age = 1.0
	_last_impulse = Vector2.ZERO
	_last_torque_impulse = 0.0
	_last_energy_used = 0.0
	_flight_mode = str(_profile.get("movement", "ground")) in ["flight", "4ly_velocity"]
	_air_jumps = 1 if rig_id == &"scout" else 0
	refresh_observation()
	_last_centre = _transforms[0].origin
	return OK


func _create_joint(definition: Dictionary, origin: Vector2) -> void:
	var joint: Dictionary = definition.duplicate(true)
	var a: int = int(joint.a)
	var b: int = int(joint.b)
	var pivot: Vector2 = origin + Vector2(joint.anchor)
	var node: Joint2D
	var type: String = str(joint.type)
	if type == "rotary":
		var pin: PinJoint2D = PinJoint2D.new()
		pin.position = to_local(pivot)
		pin.softness = clampf(float(joint.get("softness", 0.015)), 0.0, 1.0)
		if joint.has("limits") and bool(joint.get("limits_enabled", true)):
			var initial_angle: float = float(_part_defs[b].get("angle", 0.0)) - float(_part_defs[a].get("angle", 0.0))
			pin.angular_limit_enabled = true
			# Rapier's revolute limits use the absolute body-angle difference;
			# catalogue limits are relative to the authored neutral assembly.
			pin.angular_limit_lower = float(joint.limits.x) + initial_angle
			pin.angular_limit_upper = float(joint.limits.y) + initial_angle
		pin.motor_enabled = false
		node = pin
	else:
		var axis: Vector2 = Vector2(joint.axis).normalized()
		var limits: Vector2 = joint.get("limits", Vector2(-2.0, 2.0))
		var groove: GrooveJoint2D = GrooveJoint2D.new()
		groove.position = to_local(pivot + axis * limits.x)
		groove.rotation = axis.angle() - PI * 0.5
		groove.length = maxf(0.05, limits.y - limits.x)
		groove.initial_offset = clampf(-limits.x, 0.0, groove.length)
		node = groove
		joint["axis_local"] = axis.rotated(-float(_part_defs[a].get("angle", 0.0)))
		joint["rest_separation"] = Vector2(_part_defs[b].offset) - Vector2(_part_defs[a].offset)
		# Two spaced pin-in-slot constraints emulate a guided rail. One groove
		# alone leaves a piston free to turn over under a foot strike; the second
		# guide preserves the travel axis while adjacent rotary pads retain play.
		var guide: GrooveJoint2D = GrooveJoint2D.new()
		var spacing: float = clampf(_sizes[b].length() * 0.30, 0.8, 2.5)
		guide.position = to_local(pivot + axis * (limits.x + spacing))
		guide.rotation = groove.rotation
		guide.length = groove.length
		guide.initial_offset = groove.initial_offset
		_attach_joint_node(guide, a, b, float(joint.get("max_force", 180.0)))
		joint["guide_node"] = guide
		if type == "spring":
			var spring: DampedSpringJoint2D = DampedSpringJoint2D.new()
			var start: Vector2 = origin + Vector2(_part_defs[a].offset)
			var separation: Vector2 = (origin + Vector2(_part_defs[b].offset)) - start
			spring.position = to_local(start)
			spring.rotation = separation.angle() - PI * 0.5
			spring.length = maxf(0.1, separation.length())
			spring.rest_length = maxf(0.1, float(joint.get("rest_length", separation.length())))
			spring.stiffness = clampf(float(joint.get("stiffness", 45.0)), 1.0, 800.0)
			spring.damping = clampf(float(joint.get("damping", 0.8)), 0.05, 1.0)
			_attach_joint_node(spring, a, b, float(joint.get("max_force", 180.0)))
			joint["spring_node"] = spring
	_attach_joint_node(node, a, b, float(joint.get("max_force", 180.0)))
	joint["node"] = node
	joint["enabled"] = true
	joint["target"] = 0.0
	joint["initial_relative_angle"] = float(_part_defs[b].get("angle", 0.0)) - float(_part_defs[a].get("angle", 0.0))
	joint["anchor_a_local"] = (Vector2(joint.anchor) - Vector2(_part_defs[a].offset)).rotated(-float(_part_defs[a].get("angle", 0.0)))
	joint["anchor_b_local"] = (Vector2(joint.anchor) - Vector2(_part_defs[b].offset)).rotated(-float(_part_defs[b].get("angle", 0.0)))
	# Mirrored fins deploy in opposite directions. Gait phase is independently
	# authored and commonly zero, so it cannot also serve as an orientation sign.
	var outboard: Vector2 = Vector2(_part_defs[b].offset) - Vector2(joint.anchor)
	joint["deployment_sign"] = float(joint.get("deployment_sign", -1.0 if outboard.x < -0.001 else 1.0))
	_joints.append(joint)


func _attach_joint_node(node: Joint2D, a: int, b: int, maximum: float) -> void:
	node.disable_collision = true
	add_child(node)
	node.node_a = node.get_path_to(_parts[a])
	node.node_b = node.get_path_to(_parts[b])
	PhysicsServer2D.joint_set_param(node.get_rid(), PhysicsServer2D.JOINT_PARAM_MAX_FORCE, maximum)


func bodies() -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	result.assign(_parts)
	return result


func body_sizes() -> PackedVector2Array:
	return _sizes.duplicate()


func centre() -> Vector2:
	return _transforms[0].origin if not _transforms.is_empty() else Vector2.ZERO


func advance(action: Dictionary, delta: float, allowed: bool = true) -> void:
	if not configured or not fault.is_empty():
		return
	if _flight_controller != null:
		_advance_flight(action, delta, allowed)
		return
	if not is_finite(delta) or delta <= 0.0:
		cancel()
		refresh_observation()
		return
	var dt: float = minf(delta, MAX_DELTA)
	# The released object's short collision grace is passive simulation state.
	# Revoking a producer must not leave its item phasing through the owner forever.
	_update_detached(dt)
	if not allowed or not valid_action(action):
		cancel()
		refresh_observation()
		return
	_tick += 1
	_effects.clear()
	_last_impulse = Vector2.ZERO
	_last_torque_impulse = 0.0
	_last_energy_used = 0.0
	_movement_limited = delta > MAX_DELTA
	cooldown = maxf(0.0, cooldown - dt)
	_tool_cooldown = maxf(0.0, _tool_cooldown - dt)
	_refresh_states()
	if not fault.is_empty():
		return
	_sense()
	_refresh_equipment_state()
	_action = action.duplicate(true)
	var movement: Vector2 = Vector2(action.get("move", Vector2.ZERO)).limit_length(1.0)
	if movement.length_squared() < 0.0025:
		movement = Vector2.ZERO
	var slew: float = clampf(float(_profile.get("slew", 10.0)), 2.0, 40.0)
	_smoothed_move = _smoothed_move.move_toward(movement, slew * dt)
	_smoothed_trim = move_toward(_smoothed_trim, clampf(float(action.get("trim", 0.0)), -1.0, 1.0), slew * dt)
	if absf(movement.x) > 0.1:
		_facing = signf(movement.x)
	var desired_aim: Vector2 = action.get("aim", Vector2(_facing, -0.2))
	if desired_aim.length_squared() > 0.00001:
		_aim = desired_aim.normalized()
	var effort: float = clampf(float(action.get("effort", 1.0)), 0.15, 1.5)
	var buttons: Vector3i = Vector3i(int(bool(action.get("primary", false))),
		int(bool(action.get("secondary", false))), int(bool(action.get("auxiliary", false))))
	var pressed: Vector3i = Vector3i(int(buttons.x > _previous_buttons.x),
		int(buttons.y > _previous_buttons.y), int(buttons.z > _previous_buttons.z))
	var released_primary: bool = buttons.x == 0 and _previous_buttons.x != 0
	if _player_controller == null:
		_apply_auxiliary(buttons.z != 0, pressed.z != 0, dt, effort)
	var supported: bool = not _support.is_empty() or gripped
	_support_age = 0.0 if supported else _support_age + dt
	if supported:
		_air_jumps = 1 if rig_id == &"scout" else 0
	var family: String = str(_profile.get("movement", "ground"))
	if str(_profile.get("auxiliary", "")) == "mode" and rig_id == &"qwen":
		family = "flight" if _flight_mode else "ground"
	if _player_controller != null:
		_player_joint_targets.clear()
		_player_wheel_speeds.clear()
		_player_free_joints.clear()
		_player_controller.advance(self, action, dt, effort)
	else:
		_apply_locomotion(family, buttons, dt, effort)
		_apply_secondary(buttons.y != 0, pressed.y != 0, family, dt, effort)
		_apply_primary(buttons.x != 0, pressed.x != 0, released_primary, dt, effort)
	_apply_attachment_forces(float(action.get("reel", 0.0)), dt, effort)
	_drive_joints(buttons, dt, effort)
	if bool(action.get("release_usable", false)) and not bool(_definition.get("equipment_managed", false)):
		release_usable()
	if bool(action.get("attach_usable", false)) and not bool(_definition.get("equipment_managed", false)):
		attach_usable()
	if bool(action.get("tool", false)):
		fire_mount(0, effort)
	_limit_extreme_motion(dt)
	# A burst capacitor, not a simulated fuel tank: ordinary movement has a
	# small sustained supply, while boost and repeated tool/pulse actions draw
	# down its reserve. Held demand at zero no longer creates a recharge flicker.
	var recharge: float = float(_profile.get("sustained_recharge", 0.10))
	if _last_energy_used < 0.000001:
		recharge = float(_profile.get("recharge", 0.45))
	energy = minf(1.0, energy + maxf(0.0, recharge) * dt)
	if (str(_profile.get("primary", "")) == "grip_lunge" or rig_id == &"bellows") and buttons.x == 0:
		charge = minf(1.0, charge + (1.1 if gripped else 0.42) * dt)
	if _smoothed_move.length() > 0.25 and centre().distance_to(_last_centre) < 0.07:
		_stuck_time += dt
	else:
		_stuck_time = maxf(0.0, _stuck_time - dt * 2.0)
	_last_centre = centre()
	_previous_buttons = buttons
	_publish_observation()
	queue_redraw()


func set_propulsion_enabled(enabled: bool) -> bool:
	if not configured or _flight_controller == null:
		return false
	cancel()
	_power_enabled = enabled
	_flight_mode_name = "passive_no_lease" if enabled else "power_off"
	_publish_observation()
	return true


func _advance_flight(action: Dictionary, delta: float, allowed: bool) -> void:
	# Deliberately separate from legacy abilities, gyro, energy, ground sensing
	# feedback and the emergency high-speed brake. The blind helper owns the
	# complete assistance budget, and receives no pose position, goal or world.
	if not is_finite(delta) or absf(delta - FlightProfile.FIXED_DELTA) > 0.000000001 \
		or not allowed or action.size() != 1 or not action.has("move") \
		or not _finite_vector(action.move) or absf(action.move.x) > 1.0 or absf(action.move.y) > 1.0:
		cancel()
		refresh_observation()
		return
	_refresh_states()
	if not fault.is_empty():
		return
	_tick += 1
	_action = {"move": Vector2(action.move).limit_length(1.0)}
	var response: Dictionary = _flight_controller.advance(_action.move, _velocities[0],
		_transforms[0].get_rotation(), _angular_velocities[0], delta, _power_enabled)
	_last_impulse = Vector2(response.applied_force) * delta
	_last_torque_impulse = float(response.applied_torque) * delta
	_last_energy_used = 0.0
	if not bool(response.valid):
		cancel()
		return
	# Own this force channel for exactly one host step. Sustained thrust must
	# participate in Rapier's force/substep integration, not be a pre-step
	# impulse: the latter can drift in position even at zero sampled velocity.
	# Replacement/cancel can revoke an unconsumed force without undoing momentum.
	PhysicsServer2D.body_set_constant_force(_parts[0].get_rid(), Vector2(response.applied_force))
	PhysicsServer2D.body_set_constant_torque(_parts[0].get_rid(), float(response.applied_torque))
	_flight_mode_name = "power_off" if not _power_enabled else ("neutral" if _action.move == Vector2.ZERO else "velocity")
	_movement_limited = bool(response.thrust_saturated) or bool(response.acceleration_limited)
	# Sensors belong to publication/producer input only, never to stabilization.
	_sense()
	_publish_observation()
	queue_redraw()


func complete_step() -> void:
	if _flight_controller != null and not _parts.is_empty():
		PhysicsServer2D.body_set_constant_force(_parts[0].get_rid(), Vector2.ZERO)
		PhysicsServer2D.body_set_constant_torque(_parts[0].get_rid(), 0.0)


func _apply_locomotion(family: String, buttons: Vector3i, dt: float, effort: float) -> void:
	var velocity: Vector2 = _velocities[0]
	var angle: float = _transforms[0].get_rotation()
	var speed: float = clampf(float(_profile.get("speed", 65.0)) * effort, 5.0, 240.0)
	var acceleration: float = clampf(float(_profile.get("accel", 260.0)) * effort, 5.0, MAX_ACCELERATION)
	var moving: bool = _smoothed_move.length_squared() > 0.0001
	var family_ground: bool = family in ["ground", "walk", "hop", "roll", "rope", "sail", "drill", "pulse"]
	if family_ground and not _support.is_empty() and absf(_smoothed_move.x) > 0.01:
		var normal: Vector2 = _support.normal
		var tangent: Vector2 = Vector2(-normal.y, normal.x)
		if tangent.x < 0.0:
			tangent = -tangent
		var target: float = _smoothed_move.x * speed
		var correction: float = clampf(target - velocity.dot(tangent), -acceleration * dt, acceleration * dt)
		var scale: float = _spend(0.06 * dt * absf(_smoothed_move.x))
		# Traction is a bounded contact-conditioned gameplay force. In free air
		# these rigs have no horizontal drive; limb motors still exchange torque.
		_apply_rig_impulse(tangent * correction * _total_mass * scale)
		_react_support(-tangent * correction * _total_mass * scale)
	if family == "roll":
		if moving:
			_angular_target(_smoothed_move.x * speed / maxf(3.0, _sizes[0].y * 0.5), dt, 45.0)
	elif family == "hover":
		var distance: float = float(_sensors.get("ground_distance", MAX_ROPE_LENGTH))
		var clearance: float = clampf(float(_profile.get("ground_clearance", 12.0)) - _smoothed_move.y * 5.0, 4.0, 30.0)
		if distance < float(_profile.get("hover_range", 38.0)) and _power_enabled:
			var lift: float = clampf(_gravity + (clearance - distance) * 24.0 - velocity.y * 9.0,
				0.0, float(_profile.get("thrust", 340.0)))
			var scale: float = _spend(0.08 * dt)
			_apply_rig_impulse(Vector2(clampf(_smoothed_move.x * speed - velocity.x,
				-acceleration * dt, acceleration * dt), -lift * dt) * _total_mass * scale)
		_gyro(0.12 * _smoothed_move.x, dt)
	elif family == "flight":
		if _power_enabled and not _coast_mode:
			var scale: float = _spend(0.08 * dt)
			var thrust: float = clampf(float(_profile.get("thrust", 350.0)), _gravity, MAX_ACCELERATION)
			if str(_profile.get("primary", "")) == "left_thrust":
				# First-order pod spooling preserves a PWM duty cycle's mean; a
				# slew limiter would drift toward full output above 50 percent duty.
				# Script and human held buttons still exercise the same two motors.
				var response: float = 1.0 - exp(-dt / 0.35)
				_thruster_levels = _thruster_levels.lerp(Vector2(buttons.x, buttons.y), response)
				var left: float = _thruster_levels.x * thrust * 0.62
				var right: float = _thruster_levels.y * thrust * 0.62
				_apply_differential_thrust(left * _total_mass * dt * scale,
					right * _total_mass * dt * scale)
				var target: float = clampf((_smoothed_move.x * speed - velocity.x) * 2.0 / maxf(_gravity, 60.0), -0.5, 0.5)
				_gyro(target, dt, 0.5)
			elif bool(_profile.get("vector_thrust", rig_id in [&"skimmer", &"astra", &"luna"])):
				var desired: Vector2 = _smoothed_move * speed
				var change: Vector2 = (desired - velocity).limit_length(acceleration * dt)
				var vector_impulse: Vector2 = (change + Vector2.UP * _gravity * dt).limit_length(thrust * dt)
				# Omnidirectional vector rigs have a declared central vectored
				# assist; body-oriented rotor rigs below load their actual pods.
				_apply_rig_impulse(vector_impulse * _total_mass * scale)
				_gyro(_smoothed_move.x * 0.25, dt)
			else:
				var target_angle: float = clampf((_smoothed_move.x * speed - velocity.x) * 2.8 / maxf(_gravity, 60.0), -0.6, 0.6)
				target_angle += sin(float(_tick) * dt * 3.7 + float(actor_slot)) * float(_profile.get("wobble", 0.0))
				var lift: float = clampf((_gravity + (velocity.y - _smoothed_move.y * speed) * 3.0)
					/ maxf(0.5, cos(angle)), 0.0, thrust)
				# The assisted collective waits for a useful thrust direction
				# during a tumble, leaving the bounded attitude servo room to right
				# a grounded craft. An explicit boost still follows its real axis.
				lift *= clampf((cos(angle) - 0.10) / 0.35, 0.0, 1.0)
				_apply_thrust_impulse(Vector2.UP.rotated(angle) * lift * _total_mass * dt * scale, true)
				_gyro(target_angle, dt, 0.65 if rig_id == &"copter" else 1.0)
		else:
			_gyro(0.0, dt, 0.25)
	elif family == "drill":
		if buttons.x != 0:
			var scale: float = _spend(0.12 * dt)
			var target_direction: Vector2 = _aim
			_apply_rig_impulse(target_direction * acceleration * _total_mass * dt * scale)
			_gyro(target_direction.angle() - PI * 0.5, dt)
		else:
			_gyro(0.0, dt, 0.6)
	else:
		var lean: float = _smoothed_move.x * (0.20 if family == "walk" else 0.08)
		if not _support.is_empty() and family in ["ground", "walk", "sail"]:
			lean += clampf(Vector2(_support.normal).angle() + PI * 0.5, -0.8, 0.8)
		_gyro(lean, dt, 0.65 if _support.is_empty() else 1.0)
	gait_phase = fmod(gait_phase + dt * float(_profile.get("gait_rate", 8.0))
		* maxf(absf(_smoothed_move.x), 0.08), TAU)
	if absf(_smoothed_trim) > 0.01:
		_apply_angular_impulse(0, _smoothed_trim * _inertias[0] * float(_profile.get("gyro", 22.0)) * dt)


func _apply_primary(held: bool, pressed: bool, released: bool, dt: float, effort: float) -> void:
	var ability: String = str(_profile.get("primary", "jump"))
	var supported: bool = not _support.is_empty() or gripped
	match ability:
		"jump":
			if pressed and cooldown <= 0.0 and (supported or _air_jumps > 0):
				_jump(_jump_direction(), effort, supported)
				if not supported:
					_air_jumps -= 1
		"charge_jump":
			if held and supported:
				_charge_armed = true
				charge = minf(1.0, charge + dt / maxf(0.15, float(_profile.get("charge_seconds", 0.7))))
			if released and _charge_armed:
				if cooldown <= 0.0 and (supported or _support_age < 0.12):
					_jump(_jump_direction(), effort * lerpf(0.55, 1.55, charge), true)
				charge = 0.0
				_charge_armed = false
		"boost":
			if held:
				var direction: Vector2 = _smoothed_move.normalized() if _smoothed_move.length() > 0.1 else Vector2.UP
				if bool(_profile.get("body_thrust", false)):
					direction = Vector2.UP.rotated(_transforms[0].get_rotation())
				var scale: float = _spend(0.16 * dt)
				_apply_thrust_impulse(direction * _total_mass * 180.0 * effort * dt * scale,
					bool(_profile.get("body_thrust", false)))
		"pulse":
			if pressed and cooldown <= 0.0 and (rig_id != &"bellows" or charge >= 0.12):
				var stored: float = charge
				_jump(_aim, effort * ((0.5 + stored * 0.7) if rig_id == &"bellows" else 1.0), true)
				charge = 0.0
		"grip_lunge":
			if pressed and cooldown <= 0.0 and charge >= 0.12 and (supported or _support_age < 0.12):
				_jump(_aim, effort * (0.8 + charge * 0.5), true)
				charge = 0.0
		"rope":
			if pressed and cooldown <= 0.0:
				cast_rope(_aim)
		"drill", "cut":
			if held:
				fire_mount(0, effort)
			if ability == "cut" and pressed and supported and cooldown <= 0.0:
				_jump(Vector2(_facing, -0.25).normalized(), effort * 0.45, true)
		"blast":
			if pressed and cooldown <= 0.0:
				var hit: Dictionary = _ray(centre(), centre() + _aim * 18.0)
				if not hit.is_empty():
					var scale: float = _spend(0.22)
					if scale > 0.0:
						_apply_rig_impulse(-_aim * float(_profile.get("jump", 95.0)) * effort * _total_mass * scale)
						_queue_effect("blast", Vector2(hit.position) + Vector2(hit.normal) * 1.25,
							centre(), 3, effort, 0, "rocket_charge", 0)
						cooldown = float(_profile.get("cooldown", 0.55))
		"pogo":
			if held and not bool(_action.get("secondary", false)) and supported and cooldown <= 0.0:
				_jump(Vector2(_smoothed_move.x * 0.35, -1.0).normalized(), effort * (1.0 + charge * 0.4), true)
				charge = 0.0
		"spin":
			if held:
				charge = minf(1.0, charge + dt * 0.7)
				_angular_target(_facing * (5.0 + charge * 12.0), dt, 40.0 * effort)
		"left_thrust":
			pass # Differential thrusters are solved together in locomotion.
		_:
			if pressed and cooldown <= 0.0:
				_jump(_aim, effort, true)


func _apply_secondary(held: bool, pressed: bool, family: String, dt: float, effort: float) -> void:
	var ability: String = str(_profile.get("secondary", "brake"))
	match ability:
		"pulse":
			if pressed and cooldown <= 0.0:
				_jump(Vector2(_facing, 0.0), effort * 0.7, true)
		"brake":
			if held:
				if family in ["flight", "hover"] or not _support.is_empty() or gripped:
					var change: Vector2 = -_velocities[0] * minf(1.0, 8.0 * dt)
					_apply_rig_impulse(change.limit_length(400.0 * dt) * _total_mass)
				_gyro(0.0, dt, 1.5)
		"stabilize":
			pass # _gyro increases damping around the requested flight attitude.
		"glide":
			if held and _velocities[0].y > 0.0:
				_apply_rig_impulse(Vector2(0.0, -minf(_velocities[0].y * 5.0, _gravity * 0.82)) * _total_mass * dt)
				_gyro(_smoothed_move.x * 0.20, dt)
		"grip":
			if held and energy > 0.01:
				if not gripped:
					_attempt_grip()
			elif gripped:
				gripped = false
		"rope_release":
			if pressed:
				release_rope(true)
		"preload":
			if held:
				charge = minf(1.0, charge + dt * 1.2)
				if not _support.is_empty():
					_apply_rig_impulse(-_velocities[0] * _total_mass * minf(dt * 5.0, 1.0))
		"hop":
			if pressed and not _support.is_empty() and cooldown <= 0.0:
				_jump(Vector2(_smoothed_move.x * 0.3, -1.0).normalized(), effort * (0.7 + charge), true)
				charge = 0.0
		"inhale":
			if held:
				charge = minf(1.0, charge + dt * 1.8)
				_apply_rig_impulse(-_velocities[0] * _total_mass * minf(2.5 * dt, 1.0))
		"sail":
			if held:
				var speed_squared: float = _velocities[0].x * _velocities[0].x
				var lift: float = minf(speed_squared * 0.035, _gravity * 0.92)
				_apply_rig_impulse(Vector2(-_velocities[0].x * 0.3, -lift) * _total_mass * dt)
		"rebound":
			if held and not _support.is_empty() and cooldown <= 0.0 and _velocities[0].length() > 18.0:
				var normal: Vector2 = _support.normal
				if _velocities[0].dot(normal) < -5.0:
					_apply_rig_impulse(-normal * _velocities[0].dot(normal) * 1.5 * _total_mass)
					cooldown = 0.25
		"right_thrust":
			pass


func _apply_auxiliary(held: bool, pressed: bool, dt: float, effort: float) -> void:
	match str(_profile.get("auxiliary", "self_right")):
		"self_right", "tuck", "stabilize":
			if held:
				_gyro(0.0, dt, 1.8)
		"toggle_power":
			if pressed:
				_power_enabled = not _power_enabled
		"mode":
			if pressed:
				if rig_id == &"qwen":
					_flight_mode = not _flight_mode
				else:
					_coast_mode = not _coast_mode
		"coast":
			if pressed:
				_coast_mode = not _coast_mode
		"rope_release":
			if pressed:
				release_rope(true)
		"grip_release":
			if held:
				gripped = false
		"dive":
			if held:
				_apply_rig_impulse(Vector2.DOWN * _total_mass * 170.0 * dt)
				_apply_angular_impulse(0, _inertias[0] * _facing * 8.0 * dt)
		"paired_burst":
			if pressed and cooldown <= 0.0:
				_jump(Vector2.UP.rotated(_transforms[0].get_rotation()), effort, true)
		"vent":
			if held:
				charge = 0.0
		"brake":
			if held and not _support.is_empty():
				_apply_rig_impulse((-_velocities[0] * minf(1.0, 7.0 * dt)).limit_length(300.0 * dt) * _total_mass)


func _jump_direction() -> Vector2:
	var direction: Vector2 = Vector2(_smoothed_move.x * 0.35, -1.0)
	if gripped:
		direction = (_grip_normal + _aim * 0.6).normalized()
	elif rig_id in [&"walljumper", &"pouncer", &"bonsai", &"dropbot", &"jev"]:
		direction = _aim
		if direction.y > -0.15 and not _support.is_empty():
			direction = Vector2(direction.x, -0.7)
	return direction.normalized()


func _jump(direction: Vector2, effort: float, admitted: bool) -> void:
	if not admitted or cooldown > 0.0 or direction.length_squared() < 0.00001:
		return
	var cost: float = 0.11 * clampf(effort, 0.25, 2.0)
	if energy < cost:
		return
	var scale: float = _spend(cost)
	if scale <= 0.0:
		return
	var jump: float = clampf(float(_profile.get("jump", 72.0)) * effort, 8.0, MAX_IMPULSE_PER_MASS)
	_apply_rig_impulse(direction.normalized() * jump * _total_mass * scale)
	gripped = false
	cooldown = clampf(float(_profile.get("cooldown", 0.40)), 0.1, 2.0)


func _gyro(target_angle: float, dt: float, gain: float = 1.0) -> void:
	var stabilized: bool = str(_profile.get("secondary", "")) == "stabilize" \
		and bool(_action.get("secondary", false))
	if stabilized:
		gain *= 1.5
	var maximum: float = clampf(float(_profile.get("gyro", 22.0)) * gain, 0.0, MAX_ANGULAR_ACCELERATION)
	if maximum <= 0.0:
		return
	var error: float = wrapf(target_angle - _transforms[0].get_rotation(), -PI, PI)
	var play: float = clampf(float(_profile.get("play", 0.05)), 0.0, 0.3)
	error = signf(error) * maxf(0.0, absf(error) - play)
	var stiffness: float = float(_profile.get("gyro_kp", 12.0))
	var damping: float = float(_profile.get("damping", 4.0))
	if stabilized:
		stiffness *= 1.2
		damping *= 1.5
	var acceleration: float = clampf(stiffness * error - damping * _angular_velocities[0], -maximum, maximum)
	_apply_angular_impulse(0, acceleration * _assembly_inertia * dt)


func _angular_target(target: float, dt: float, maximum: float) -> void:
	var acceleration: float = clampf((target - _angular_velocities[0]) * 5.0, -maximum, maximum)
	_apply_angular_impulse(0, acceleration * _inertias[0] * dt)


func _drive_joints(buttons: Vector3i, dt: float, effort: float) -> void:
	for index: int in range(_joints.size()):
		var joint: Dictionary = _joints[index]
		if not bool(joint.enabled):
			continue
		var a: int = int(joint.a)
		var b: int = int(joint.b)
		var role: String = str(joint.get("role", "passive"))
		var relative: float = wrapf(_transforms[b].get_rotation() - _transforms[a].get_rotation()
			- float(joint.initial_relative_angle), -PI, PI)
		var relative_speed: float = _angular_velocities[b] - _angular_velocities[a]
		var target: float = 0.0
		if str(joint.type) == "rotary":
			var pin: PinJoint2D = joint.node
			var drive: bool = role in ["wheel", "track", "leg", "aim", "rotor", "wing", "sail", "grip", "tool", "foot", "thruster", "tilt_thruster", "fin", "equipment"]
			drive = drive or _player_joint_targets.has(str(joint.id))
			if bool(joint.get("equipment_aim", false)):
				drive = _equipment_aim_enabled
			if role in ["wheel", "track"]:
				target = _smoothed_move.x * float(joint.get("motor_speed", 12.0))
				if _player_wheel_speeds.has(str(joint.id)):
					target = clampf(float(_player_wheel_speeds[str(joint.id)]), -float(joint.get("motor_speed", 12.0)), float(joint.get("motor_speed", 12.0)))
			elif role == "rotor":
				target = float(joint.get("motor_speed", 14.0)) * (1.0 if _power_enabled else 0.0)
			elif drive:
				var desired: float = 0.0
				if role == "leg":
					desired = sin(gait_phase + float(joint.get("phase", 0.0))) \
						* float(_profile.get("gait_amplitude", 0.48)) * absf(_smoothed_move.x)
					desired += _smoothed_move.x * 0.16
				elif role in ["aim", "tool", "equipment"]:
					var aim_axis: Vector2 = joint.get("aim_axis", Vector2.RIGHT)
					var joint_aim: Vector2 = _equipment_aim if bool(joint.get("equipment_aim", false)) else _aim
					desired = wrapf(joint_aim.angle() - aim_axis.angle() - _transforms[a].get_rotation()
						- float(joint.initial_relative_angle), -PI, PI)
					if bool(joint.get("equipment_aim", false)) and joint.has("limits"):
						desired = _bounded_equipment_angle(joint, desired, relative)
				elif role in ["wing", "sail"]:
					desired = (0.48 if buttons.y != 0 else -0.18) * float(joint.deployment_sign)
				elif role == "grip":
					desired = -0.25 if gripped else 0.15
				elif role == "tilt_thruster":
					desired = _smoothed_move.x * 0.40
				elif role == "thruster" and bool(_profile.get("vector_thrust", rig_id in [&"skimmer", &"astra", &"luna"])):
					# The omnidirectional assist keeps its declared vector authority,
					# while actual pod motors steer through their limited trim arc.
					# Both pods exchange real joint torque with the chassis; they are
					# not rigid decorations held at a permanent zero-angle target.
					desired = _smoothed_move.x * 0.20 + _smoothed_trim * 0.10
				if _player_joint_targets.has(str(joint.id)):
					desired = float(_player_joint_targets[str(joint.id)])
				if joint.has("limits"):
					desired = clampf(desired, joint.limits.x + 0.03, joint.limits.y - 0.03)
				var error: float = desired - relative
				var play: float = float(_profile.get("play", 0.05))
				error = signf(error) * maxf(0.0, absf(error) - play)
				target = clampf(error * 9.0 - relative_speed * 0.25,
					-float(joint.get("motor_speed", 8.0)), float(joint.get("motor_speed", 8.0)))
			pin.motor_enabled = drive and not _player_free_joints.has(str(joint.id))
			# Rate limiting applies to the requested velocity, not the body state.
			# Reversals retain a little mechanical play without one-tick kicks.
			# Equipment aiming has its own command authority. A carrier may set
			# locomotion effort to zero while continuing to turn its held nozzle.
			var motor_effort: float = 1.0 if bool(joint.get("equipment_aim", false)) else minf(effort, 1.2)
			pin.motor_target_velocity = move_toward(pin.motor_target_velocity,
				target * motor_effort, 20.0 * dt)
			joint.target = target
		else:
			var axis: Vector2 = Vector2(joint.axis_local).rotated(_transforms[a].get_rotation())
			var rest: Vector2 = Vector2(joint.rest_separation).rotated(_transforms[a].get_rotation()
				- float(_part_defs[a].get("angle", 0.0)))
			var displacement: float = (_transforms[b].origin - _transforms[a].origin - rest).dot(axis)
			var speed: float = (_velocities[b] - _velocities[a]).dot(axis)
			var limits: Vector2 = joint.get("limits", Vector2(-2.0, 2.0))
			if role in ["leg", "slider", "piston"]:
				target = sin(gait_phase + float(joint.get("phase", 0.0))) * 0.6 * absf(_smoothed_move.x)
				if buttons.x != 0:
					target += 0.8
				if buttons.y != 0:
					target -= 0.8
				target = clampf(target, limits.x * 0.7, limits.y * 0.7)
			if _player_joint_targets.has(str(joint.id)):
				target = clampf(float(_player_joint_targets[str(joint.id)]), limits.x * 0.85, limits.y * 0.85)
			var force: float = clampf((target - displacement) * float(joint.get("stiffness", 45.0))
				- speed * 8.0, -float(joint.get("max_force", 180.0)), float(joint.get("max_force", 180.0)))
			_apply_part_impulse(b, axis * force * dt)
			_apply_part_impulse(a, -axis * force * dt)
			var equivalent_inertia: float = 1.0 / (1.0 / _inertias[a] + 1.0 / _inertias[b])
			var torque: float = clampf((-relative * 120.0 - relative_speed * 18.0) * equivalent_inertia,
				-float(joint.get("max_force", 180.0)), float(joint.get("max_force", 180.0))) * dt
			torque = clampf(torque, -minf(_inertias[a], _inertias[b]) * 4.0,
				minf(_inertias[a], _inertias[b]) * 4.0)
			_apply_angular_impulse(b, torque)
			_apply_angular_impulse(a, -torque)
			joint.target = target


func _bounded_equipment_angle(joint: Dictionary, desired: float, relative: float) -> float:
	var limits: Vector2 = joint.limits
	var lower: float = limits.x + minf(0.03, (limits.y - limits.x) * 0.1)
	var upper: float = limits.y - minf(0.03, (limits.y - limits.x) * 0.1)
	var previous: float = float(joint.get("equipment_target_angle", relative))
	if desired >= lower and desired <= upper:
		joint["equipment_target_angle"] = desired
		return desired
	var best: float = clampf(desired, lower, upper)
	var best_score: float = absf(wrapf(best - desired, -PI, PI)) + 0.35 * absf(best - previous)
	# A target behind a limited wrist has two equally close end stops. Tiny
	# chassis rotations across +/-pi must not reverse the motor every sample.
	for equivalent: float in [desired + TAU, desired - TAU]:
		var candidate: float = clampf(equivalent, lower, upper)
		var score: float = absf(wrapf(candidate - desired, -PI, PI)) + 0.35 * absf(candidate - previous)
		if score + 0.025 < best_score:
			best = candidate
			best_score = score
	joint["equipment_target_angle"] = best
	return best


func cast_rope(direction: Vector2) -> bool:
	if not configured or direction.length_squared() < 0.00001 or cooldown > 0.0:
		return false
	var hit: Dictionary = _ray(centre(), centre() + direction.normalized() * MAX_ROPE_LENGTH)
	if hit.is_empty() or not _static_hit(hit):
		return false
	if _spend(0.04) <= 0.0:
		return false
	anchor = hit.position
	rope_length = clampf(centre().distance_to(anchor), MIN_ROPE_LENGTH, MAX_ROPE_LENGTH)
	if rig_id == &"lineshank":
		rope_length *= 0.82
	rope_attached = true
	tension = 0.0
	cooldown = 0.22
	return true


func release_rope(deliberate: bool = false) -> void:
	if deliberate and rope_attached and rig_id == &"lineshank" and tension > 0.0:
		var direction: Vector2 = (anchor - centre()).normalized()
		_apply_rig_impulse(Vector2(direction.x, -0.15) * minf(tension * 0.12, 18.0) * _total_mass)
	rope_attached = false
	tension = 0.0
	rope_length = 0.0
	anchor = Vector2.ZERO


func _attempt_grip() -> bool:
	var hit: Dictionary = _ray(centre(), centre() + _aim * 18.0)
	if hit.is_empty() or centre().distance_to(hit.position) > maxf(_sizes[0].x, _sizes[0].y) * 0.6 + 4.0:
		hit = _support
	if hit.is_empty() or not _static_hit(hit):
		return false
	gripped = true
	anchor = hit.position
	_grip_normal = Vector2(hit.normal).normalized()
	_grip_local_offset = centre() - anchor
	return true


func _apply_attachment_forces(reel: float, dt: float, effort: float) -> void:
	if rope_attached:
		var direction: Vector2 = anchor - centre()
		var length: float = direction.length()
		if length > MAX_ROPE_LENGTH * 1.6 or not _anchor_still_present():
			release_rope(false)
		else:
			rope_length = clampf(rope_length - clampf(reel, -1.0, 1.0) * 22.0 * dt,
				MIN_ROPE_LENGTH, MAX_ROPE_LENGTH)
			if length > 0.001:
				direction /= length
				var stretch: float = maxf(0.0, length - rope_length - 0.5)
				tension = clampf(stretch * 38.0 - _velocities[0].dot(direction) * 5.0, 0.0, 500.0) if stretch > 0.0 else 0.0
				_apply_rig_impulse(direction * tension * _total_mass * dt)
				if not _support.is_empty():
					_gyro(0.0, dt, 0.5)
	if gripped:
		if not _anchor_still_present() or _spend(0.09 * dt) <= 0.0:
			gripped = false
		else:
			var tangent: Vector2 = Vector2(-_grip_normal.y, _grip_normal.x)
			var along: float = _smoothed_move.dot(tangent) * float(_profile.get("speed", 42.0)) * 0.45
			var candidate: Vector2 = anchor + tangent * along * dt
			var next_contact: Dictionary = _ray(candidate + _grip_normal * 3.0, candidate - _grip_normal * 2.0)
			if not next_contact.is_empty() and _static_hit(next_contact):
				anchor = next_contact.position
				_grip_normal = next_contact.normal
			var error: Vector2 = anchor + _grip_local_offset - centre()
			var acceleration: Vector2 = error * 55.0 - _velocities[0] * 9.0 + Vector2.UP * _gravity
			_apply_rig_impulse(acceleration.limit_length(650.0 * effort) * _total_mass * dt)


func _anchor_still_present() -> bool:
	var direction: Vector2 = (anchor - centre()).normalized()
	if direction.length_squared() < 0.00001:
		return false
	var hit: Dictionary = _ray(anchor - direction * 2.5, anchor + direction * 2.5)
	return not hit.is_empty() and _static_hit(hit) and Vector2(hit.position).distance_to(anchor) <= 3.0


func _static_hit(hit: Dictionary) -> bool:
	if not hit.has("rid") or not hit.rid is RID or not hit.rid.is_valid():
		return false
	return PhysicsServer2D.body_get_mode(hit.rid) == PhysicsServer2D.BODY_MODE_STATIC


func _spend(amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	var scale: float = minf(1.0, energy / amount)
	var used: float = amount * scale
	energy = maxf(0.0, energy - used)
	_last_energy_used += used
	return scale


func _apply_rig_impulse(impulse: Vector2) -> void:
	if not impulse.is_finite():
		return
	var bounded: Vector2 = impulse.limit_length(_total_mass * MAX_IMPULSE_PER_MASS)
	_last_impulse += bounded
	for index: int in range(_parts.size()):
		if not _detached.has(index):
			_apply_part_impulse(index, bounded * _parts[index].mass / _total_mass)


func _apply_thrust_impulse(impulse: Vector2, body_oriented: bool) -> void:
	if _thrusters.is_empty():
		_apply_rig_impulse(impulse)
		return
	if impulse.length_squared() < 0.000001:
		return
	var mass_centre: Vector2 = Vector2.ZERO
	for index: int in range(_parts.size()):
		if not _detached.has(index):
			mass_centre += _transforms[index].origin * _parts[index].mass / _total_mass
	var directions: PackedVector2Array = PackedVector2Array()
	var levers: PackedFloat32Array = PackedFloat32Array()
	var mean_lever: float = 0.0
	for index: int in _thrusters:
		var direction: Vector2 = impulse.normalized()
		if body_oriented:
			direction = direction.rotated(_transforms[index].get_rotation() - _transforms[0].get_rotation())
		directions.append(direction)
		var lever: float = (_transforms[index].origin - mass_centre).cross(direction)
		levers.append(lever)
		mean_lever += lever / float(_thrusters.size())
	var variance: float = 0.0
	for lever: float in levers:
		variance += (lever - mean_lever) * (lever - mean_lever)
	_thrust_weights.resize(_thrusters.size())
	var total_weight: float = 0.0
	for ordinal: int in range(_thrusters.size()):
		var weight: float = 1.0 / float(_thrusters.size())
		if variance > 0.0001:
			weight -= mean_lever * (levers[ordinal] - mean_lever) / variance
		# A small bounded mixer supplies persistent trim for an offset payload.
		# A saturated or folded layout retains residual torque for the gyro;
		# this never creates negative thrust or relocates a force application.
		weight = clampf(weight, 0.02, 0.80) if _thrusters.size() > 1 else 1.0
		_thrust_weights[ordinal] = weight
		total_weight += weight
	for ordinal: int in range(_thrusters.size()):
		var index: int = _thrusters[ordinal]
		_thrust_weights[ordinal] /= total_weight
		var share: Vector2 = directions[ordinal] * impulse.length() * _thrust_weights[ordinal]
		# Thrust is applied to the actual pod, so joint flex, offsets, payload
		# and asymmetric contact all affect its transfer to the assembly.
		_last_impulse += _apply_part_impulse(index, share)


func _apply_differential_thrust(left: float, right: float) -> void:
	if _thrusters.size() < 2:
		_apply_rig_impulse(Vector2.UP.rotated(_transforms[0].get_rotation()) * (left + right))
		return
	var first: int = _thrusters[0]
	var last: int = _thrusters[_thrusters.size() - 1]
	if Vector2(_part_defs[first].offset).x > Vector2(_part_defs[last].offset).x:
		var temporary: int = first
		first = last
		last = temporary
	_last_impulse += _apply_part_impulse(first, Vector2.UP.rotated(_transforms[first].get_rotation()) * left)
	_last_impulse += _apply_part_impulse(last, Vector2.UP.rotated(_transforms[last].get_rotation()) * right)


func _apply_part_impulse(index: int, impulse: Vector2, position_offset: Vector2 = Vector2.ZERO) -> Vector2:
	if not impulse.is_finite() or not position_offset.is_finite() or impulse.length_squared() < 0.00000001:
		return Vector2.ZERO
	var bounded: Vector2 = impulse.limit_length(_parts[index].mass * MAX_IMPULSE_PER_MASS)
	PhysicsServer2D.body_apply_impulse(_parts[index].get_rid(), bounded, position_offset)
	return bounded


func _apply_angular_impulse(index: int, impulse: float) -> void:
	if not is_finite(impulse) or absf(impulse) < 0.00000001:
		return
	var bounded: float = clampf(impulse, -_inertias[index] * 4.0, _inertias[index] * 4.0)
	PhysicsServer2D.body_apply_torque_impulse(_parts[index].get_rid(), bounded)
	_last_torque_impulse += bounded


func _react_support(impulse: Vector2) -> void:
	if _support.is_empty() or not _support.has("rid"):
		return
	var rid: RID = _support.rid
	if rid.is_valid() and PhysicsServer2D.body_get_mode(rid) == PhysicsServer2D.BODY_MODE_RIGID:
		var transform: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		PhysicsServer2D.body_apply_impulse(rid, impulse, Vector2(_support.position) - transform.origin)


func _limit_extreme_motion(dt: float) -> void:
	for index: int in range(_parts.size()):
		var speed: float = _velocities[index].length()
		if speed > 300.0:
			_movement_limited = true
			_apply_part_impulse(index, -_velocities[index].normalized()
				* minf(speed - 300.0, 700.0 * dt) * _parts[index].mass)
		if absf(_angular_velocities[index]) > 24.0:
			_movement_limited = true
			_apply_angular_impulse(index, -signf(_angular_velocities[index])
				* minf(absf(_angular_velocities[index]) - 24.0, 70.0 * dt) * _inertias[index])


func _refresh_states() -> void:
	for index: int in range(_parts.size()):
		var rid: RID = _parts[index].get_rid()
		_transforms[index] = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		_velocities[index] = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		_angular_velocities[index] = float(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
		if not _transforms[index].origin.is_finite() or not _velocities[index].is_finite() \
			or not is_finite(_transforms[index].get_rotation()) or not is_finite(_angular_velocities[index]):
			fault = "nonfinite Rapier state; actor quarantined"
			cancel()
			for body: RigidBody2D in _parts:
				body.freeze = true
			return


func _sense() -> void:
	_ray_count = 0
	_support = {}
	var ground_distance: float = MAX_ROPE_LENGTH
	for index: int in range(_parts.size()):
		if _detached.has(index):
			continue
		var pose: Transform2D = _transforms[index]
		var half: Vector2 = _sizes[index] * 0.5
		var angle: float = pose.get_rotation()
		var vertical_half: float = absf(sin(angle)) * half.x + absf(cos(angle)) * half.y
		if str(_part_defs[index].get("shape", "rectangle")) == "circle":
			vertical_half = half.x
		var hit: Dictionary = _ray(pose.origin, pose.origin + Vector2.DOWN * (vertical_half + 2.5))
		if not hit.is_empty() and Vector2(hit.normal).y < -0.35:
			var clearance: float = maxf(0.0, Vector2(hit.position).y - pose.origin.y - vertical_half)
			ground_distance = minf(ground_distance, clearance)
			if clearance <= 1.1:
				_support = hit
				_support["part"] = index
	var origin: Vector2 = centre()
	var bottom: float = absf(sin(_transforms[0].get_rotation())) * _sizes[0].x * 0.5 \
		+ absf(cos(_transforms[0].get_rotation())) * _sizes[0].y * 0.5
	var ground: Dictionary = _ray(origin, origin + Vector2.DOWN * (MAX_ROPE_LENGTH + bottom))
	if not ground.is_empty():
		ground_distance = minf(ground_distance, maxf(0.0, origin.distance_to(ground.position) - bottom))
	var left: Dictionary = _ray(origin, origin + Vector2.LEFT * 30.0)
	var right: Dictionary = _ray(origin, origin + Vector2.RIGHT * 30.0)
	var ceiling: Dictionary = _ray(origin, origin + Vector2.UP * 45.0)
	_sensors = {"ground_distance": ground_distance,
		"wall_left": origin.distance_to(left.position) if not left.is_empty() else 30.0,
		"wall_right": origin.distance_to(right.position) if not right.is_empty() else 30.0,
		"ceiling_distance": origin.distance_to(ceiling.position) if not ceiling.is_empty() else 45.0}
	if _support.is_empty():
		# Actual contact readback covers vertical/rotated feet which miss a
		# centre ray. Contact normals are local to the reporting body.
		for index: int in range(_parts.size()):
			if _detached.has(index):
				continue
			var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(_parts[index].get_rid())
			if direct == null:
				continue
			for contact: int in range(mini(direct.get_contact_count(), MAX_CONTACTS_PER_PART)):
				var rid: RID = direct.get_contact_collider(contact)
				if rid in _exclusions:
					continue
				var normal: Vector2 = direct.get_contact_local_normal(contact).rotated(_transforms[index].get_rotation())
				if normal.y < -0.35:
					_support = {"position": direct.get_contact_collider_position(contact), "normal": normal, "rid": rid, "part": index}
					break


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	if _ray_count >= MAX_RAYS or not from.is_finite() or not to.is_finite():
		_movement_limited = true
		return {}
	_ray_count += 1
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, TERRAIN_MASK, _exclusions)
	query.hit_from_inside = false
	return get_world_2d().direct_space_state.intersect_ray(query)


func refresh_observation() -> void:
	if not configured:
		return
	_refresh_states()
	if not fault.is_empty():
		return
	_sense()
	_refresh_equipment_state()
	_publish_observation()
	queue_redraw()


func _publish_observation() -> void:
	var part_states: Array[Dictionary] = []
	for index: int in range(_parts.size()):
		part_states.append({"id": str(_part_defs[index].id), "index": index,
			"position": _transforms[index].origin, "rotation": _transforms[index].get_rotation(),
			"velocity": _velocities[index], "angular_velocity": _angular_velocities[index],
			"size": _sizes[index], "mass": _parts[index].mass, "detached": _detached.has(index),
			"shape": str(_part_defs[index].get("shape", "rectangle")),
			"native_mask": str(_part_defs[index].get("native_mask", "matching_rectangle"))})
	var joint_states: Array[Dictionary] = []
	for joint: Dictionary in _joints:
		var a: int = int(joint.a)
		var b: int = int(joint.b)
		var state: Dictionary = {"id": str(joint.get("id", "")), "type": str(joint.type),
			"a": a, "b": b, "enabled": bool(joint.enabled), "target": float(joint.target),
			"angle": wrapf(_transforms[b].get_rotation() - _transforms[a].get_rotation()
				- float(joint.initial_relative_angle), -PI, PI),
			"speed": _angular_velocities[b] - _angular_velocities[a],
			"limits": joint.get("limits", Vector2(-PI, PI)),
			"limits_enabled": bool(joint.get("limits_enabled", true))}
		var separation: Vector2 = (_transforms[b] * Vector2(joint.anchor_b_local)) \
			- (_transforms[a] * Vector2(joint.anchor_a_local))
		if str(joint.type) == "rotary":
			state["anchor_error"] = separation.length()
		else:
			var axis: Vector2 = Vector2(joint.axis_local).rotated(_transforms[a].get_rotation())
			state["travel"] = separation.dot(axis)
			state["anchor_error"] = absf(separation.cross(axis))
		joint_states.append(state)
	_observation = {"version": PROFILE_VERSION, "representation": "articulated-rapier",
		"rig_id": str(rig_id), "actor_slot": actor_slot, "epoch": epoch, "tick": _tick,
		"position": centre(), "centre": centre(), "velocity": _velocities[0],
		"rotation": _transforms[0].get_rotation(), "angular_velocity": _angular_velocities[0],
		"grounded": not _support.is_empty(), "contact_normal": _support.get("normal", Vector2.ZERO),
		"energy": energy, "charge": charge, "cooldown": cooldown, "gravity": _gravity,
		"rope_attached": rope_attached, "anchor": anchor, "rope_length": rope_length, "tension": tension,
		"gripped": gripped, "gait_phase": gait_phase, "facing": _facing,
		"blocked": _stuck_time >= 0.6, "stuck_time": _stuck_time,
		"parts": part_states, "joints": joint_states, "part_count": _parts.size(),
		"tool_ready": _tool_cooldown <= 0.0 and not _mounts.is_empty(),
		"power_enabled": _power_enabled, "powered": _power_enabled,
		"flight_mode": _flight_mode, "mode": int(_flight_mode), "coast_mode": _coast_mode,
		"action": _action.duplicate(true), "applied_impulse": _last_impulse,
		"thruster_levels": _thruster_levels, "thrust_weights": _thrust_weights.duplicate(),
		"applied_torque_impulse": _last_torque_impulse, "energy_used": _last_energy_used,
		"ray_queries": _ray_count, "movement_limited": _movement_limited, "fault": fault}
	_observation.merge(_sensors)
	if _player_controller != null:
		_observation["player_movement"] = _player_controller.observation()
	if _flight_controller != null:
		_observation["action_profile"] = FlightProfile.ACTION_PROFILE
		_observation["flight"] = {"mode": _flight_mode_name, "propulsion_enabled": _power_enabled,
			"capabilities": _flight_capabilities.duplicate(true), "controller": _flight_controller.observation()}


func observation() -> Dictionary:
	var result: Dictionary = _observation.duplicate(true)
	result["fault"] = fault
	if _flight_controller != null:
		# Fault quarantine preserves the last finite pose, while current command
		# and assistance publication must reflect cancellation immediately.
		result["action"] = _action.duplicate(true)
		result["applied_impulse"] = _last_impulse
		result["applied_torque_impulse"] = _last_torque_impulse
		result["energy_used"] = _last_energy_used
		result["flight"] = {"mode": _flight_mode_name, "propulsion_enabled": _power_enabled,
			"capabilities": _flight_capabilities.duplicate(true), "controller": _flight_controller.observation()}
	if not fault.is_empty():
		result["suspended"] = true
	return result


func capabilities() -> Dictionary:
	var result: Dictionary = {"version": PROFILE_VERSION, "rig_id": str(rig_id), "representation": "articulated-rapier",
		"parts": _part_defs.duplicate(true), "joints": _definition.get("joints", []).duplicate(true),
		"mounts": _definition.get("mounts", []).duplicate(true), "profile": _profile.duplicate(true),
		"maximum_parts": MAX_PARTS, "maximum_rays": MAX_RAYS,
		"native_geometry": "oriented-rectangles", "circle_native_mask": "circumscribed_rectangle",
		"gyro_semantics": "bounded-authored-assistance",
		"slide_semantics": "paired-slot-guide-with-spring-and-endstops", "learned_controller": false}
	result["equipment_preparation"] = str(_definition.get("equipment_preparation", "mounted"))
	if _flight_controller != null:
		result["flight"] = _flight_capabilities.duplicate(true)
		result["action_profile"] = FlightProfile.ACTION_PROFILE
	return result


func fire_mount(index: int = 0, effort: float = 1.0) -> bool:
	if not configured or not is_finite(effort) or effort <= 0.0 or index < 0 or index >= _mounts.size() \
		or _tool_cooldown > 0.0 or not _effects.is_empty() or bool(_definition.get("equipment_managed", false)):
		return false
	var mount: Dictionary = _mounts[index]
	if not bool(mount.get("attached", true)):
		return false
	var part: int = int(mount.get("held_part", mount.part))
	var pose: Transform2D = _transforms[part]
	var local_angle: float = wrapf(_aim.angle() - pose.get_rotation() - float(mount.get("angle", 0.0)), -PI, PI)
	var limits: Vector2 = mount.get("limits", Vector2(-PI, PI))
	local_angle = clampf(local_angle, limits.x, limits.y)
	var direction: Vector2 = Vector2.RIGHT.rotated(pose.get_rotation() + float(mount.get("angle", 0.0)) + local_angle)
	var grip_position: Vector2 = pose * Vector2(mount.offset)
	var reach: float = clampf(float(mount.get("reach", 9.0)), 1.0, 30.0)
	var muzzle: Vector2 = grip_position + direction * reach
	# Sweep from the real part centre, including an offset mount, so an authored
	# muzzle cannot appear beyond a thin wall without a clearance check.
	var obstruction: Dictionary = _ray(pose.origin, muzzle)
	if not obstruction.is_empty():
		muzzle = obstruction.position
	var usable: String = str(mount.get("usable", "cutter"))
	if usable in ["launcher", "depositor"] and not obstruction.is_empty() \
		and pose.origin.distance_to(muzzle) < _sizes[part].length() * 0.25:
		return false
	var scale: float = _spend(0.04 * clampf(effort, 0.25, 1.5))
	if scale <= 0.0:
		return false
	var radius: int = clampi(roundi(float(mount.get("radius", 2.0))), 1, 4)
	var kind: String = "deposit" if usable == "depositor" else ("blast" if usable == "launcher" else "dig")
	_queue_effect(kind, muzzle, pose.origin, radius, effort * scale,
		int(mount.get("material", 2)), "disc", part)
	var recoil: float = clampf(float(mount.get("recoil", 2.5)) * effort, 0.0, 24.0)
	_apply_part_impulse(part, -direction * recoil * scale, grip_position - pose.origin)
	_last_impulse -= direction * recoil * scale
	_tool_cooldown = clampf(float(mount.get("cooldown", 0.18)), 0.05, 2.0)
	return true


func _queue_effect(kind: String, origin: Vector2, source: Vector2, radius: int,
		strength: float, material: int, pattern: String, source_part: int) -> void:
	if not _effects.is_empty() or not origin.is_finite() or not source.is_finite():
		return
	_effect_sequence += 1
	_effects.append({"actor_slot": actor_slot, "epoch": epoch, "sequence": _effect_sequence, "source_part": source_part,
		"kind": kind, "origin": origin, "source": source, "radius": clampi(radius, 1, 4),
		"strength": clampf(strength, 0.0, 1.0), "material": material, "pattern": pattern})


func drain_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect: Dictionary in _effects:
		result.append(effect.duplicate(true))
	_effects.clear()
	return result


func release_usable(index: int = 0) -> bool:
	if index < 0 or index >= _mounts.size():
		return false
	var mount: Dictionary = _mounts[index]
	if not mount.has("held_part") or not bool(mount.get("attached", true)):
		return false
	var part: int = int(mount.held_part)
	for joint: Dictionary in _joints:
		if int(joint.b) == part or int(joint.a) == part:
			joint.enabled = false
			PhysicsServer2D.joint_clear(joint.node.get_rid())
			if joint.has("spring_node"):
				PhysicsServer2D.joint_clear(joint.spring_node.get_rid())
			if joint.has("guide_node"):
				PhysicsServer2D.joint_clear(joint.guide_node.get_rid())
	mount.attached = false
	_detached[part] = 0.0
	_total_mass -= _parts[part].mass
	_assembly_inertia = maxf(_inertias[0], _assembly_inertia - _inertias[part]
		- _parts[part].mass * Vector2(_part_defs[part].offset).length_squared())
	_refresh_equipment_state()
	return true


func attach_usable(index: int = 0) -> bool:
	if index < 0 or index >= _mounts.size():
		return false
	var mount: Dictionary = _mounts[index]
	if not mount.has("held_part") or bool(mount.get("attached", true)):
		return false
	var part: int = int(mount.held_part)
	var host: int = int(mount.part)
	var grip_position: Vector2 = _transforms[host] * Vector2(mount.offset)
	if grip_position.distance_to(_transforms[part].origin) > 8.0:
		return false
	if not _ray(grip_position, _transforms[part].origin).is_empty():
		return false
	# A fixed processor may resume dynamics only after pickup has passed the
	# same local proximity/clearance checks as every other released object.
	if _fixed_equipment.has(part):
		_parts[part].freeze = false
		_fixed_equipment.erase(part)
	# Reattach the existing body at its current pose. No new part is allocated
	# and no teleport/velocity reset turns a pickup into an invisible launch.
	var pin: PinJoint2D = PinJoint2D.new()
	pin.position = to_local(grip_position)
	pin.softness = 0.015
	pin.angular_limit_enabled = true
	var relative_angle: float = _transforms[part].get_rotation() - _transforms[host].get_rotation()
	var pickup_limits: Vector2 = mount.get("physical_limits", Vector2(-0.8, 0.8))
	pin.angular_limit_lower = relative_angle + pickup_limits.x
	pin.angular_limit_upper = relative_angle + pickup_limits.y
	_attach_joint_node(pin, host, part, 180.0)
	for joint: Dictionary in _joints:
		if int(joint.b) == part or int(joint.a) == part:
			joint.node.queue_free()
			for extra: String in ["spring_node", "guide_node"]:
				if joint.has(extra):
					if is_instance_valid(joint[extra]):
						joint[extra].queue_free()
					joint.erase(extra)
			joint.node = pin
			joint.type = "rotary"
			joint.enabled = true
			joint.a = host
			joint.b = part
			joint.initial_relative_angle = _transforms[part].get_rotation() - _transforms[host].get_rotation()
			joint.limits = pickup_limits
			joint.anchor_a_local = _transforms[host].affine_inverse() * grip_position
			joint.anchor_b_local = _transforms[part].affine_inverse() * grip_position
			break
	for body: RigidBody2D in _parts:
		if body != _parts[part]:
			body.add_collision_exception_with(_parts[part])
			_parts[part].add_collision_exception_with(body)
	mount.attached = true
	_detached.erase(part)
	_total_mass += _parts[part].mass
	_assembly_inertia += _inertias[part] + _parts[part].mass * Vector2(_part_defs[part].offset).length_squared()
	_refresh_equipment_state()
	return true


func set_equipment_aim(direction: Vector2, enabled: bool) -> void:
	_equipment_aim_enabled = enabled and direction.is_finite() and direction.length_squared() > 0.00001
	if _equipment_aim_enabled:
		_equipment_aim = direction.normalized()


func _refresh_equipment_state() -> void:
	_equipment_state.clear()
	if not configured or _mounts.is_empty() or _transforms.size() != _parts.size():
		return
	var mount: Dictionary = _mounts[0]
	if not mount.has("held_part"):
		return
	var held: int = int(mount.held_part)
	var host: int = int(mount.part)
	var pose: Transform2D = _transforms[held]
	var axis: Vector2 = Vector2(mount.get("aim_axis", Vector2.RIGHT)).normalized()
	var direction: Vector2 = axis.rotated(pose.get_rotation())
	var half: Vector2 = _sizes[held] * 0.5
	var along: float = minf(half.x / absf(axis.x) if absf(axis.x) > 0.00001 else 1000.0,
		half.y / absf(axis.y) if absf(axis.y) > 0.00001 else 1000.0)
	var muzzle: Vector2 = pose.origin + direction * (along + 1.25)
	var grip: Vector2 = _transforms[host] * Vector2(mount.offset)
	var vertical: float = absf(sin(pose.get_rotation())) * half.x + absf(cos(pose.get_rotation())) * half.y
	# At most three additional bounded rays per refresh. Observers consume this
	# copied result, rather than initiating new space queries on every read.
	var clearance: bool = _ray(pose.origin, muzzle).is_empty()
	var supported: Dictionary = _ray(pose.origin, pose.origin + Vector2.DOWN * (vertical + 1.3))
	var pickup_clear: bool = grip.distance_to(pose.origin) <= 8.0 and _ray(grip, pose.origin).is_empty()
	_equipment_state = {"held_part": held, "host_part": host, "mount_id": str(mount.get("id", "usable")),
		"mount_type": str(mount.get("type", "mounted")), "aim_limits": mount.get("physical_limits", mount.get("limits", Vector2(-PI, PI))),
		"position": pose.origin, "rotation": pose.get_rotation(), "velocity": _velocities[held],
		"angular_velocity": _angular_velocities[held], "half_extents": half, "aim_direction": direction,
		"muzzle": muzzle, "owner_origin": _transforms[host].origin, "grip_position": grip,
		"attached": bool(mount.get("attached", true)), "clearance": clearance,
		"supported": not supported.is_empty() and Vector2(supported.get("normal", Vector2.ZERO)).y < -0.35,
		"release_age": float(_detached.get(held, 0.0)), "reattach_distance": grip.distance_to(pose.origin),
		"reattach_ready": not bool(mount.get("attached", true)) and pickup_clear,
		"fixed": _fixed_equipment.has(held)}


func equipment_mount_state() -> Dictionary:
	return _equipment_state.duplicate(true)


func fix_usable(index: int = 0) -> bool:
	if index < 0 or index >= _mounts.size():
		return false
	var mount: Dictionary = _mounts[index]
	if not mount.has("held_part") or bool(mount.get("attached", true)):
		return false
	var part: int = int(mount.held_part)
	if _fixed_equipment.has(part):
		return false
	_parts[part].freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	_parts[part].freeze = true
	_fixed_equipment[part] = true
	_refresh_equipment_state()
	return true


func apply_equipment_recoil(magnitude: float) -> Vector2:
	if not is_finite(magnitude) or magnitude <= 0.0 or _equipment_state.is_empty() \
		or not bool(_equipment_state.attached):
		return Vector2.ZERO
	var held: int = int(_equipment_state.held_part)
	var reaction: Vector2 = -Vector2(_equipment_state.aim_direction) * clampf(magnitude, 0.0, 24.0)
	var actual: Vector2 = _apply_part_impulse(held, reaction,
		Vector2(_equipment_state.muzzle) - _transforms[held].origin)
	_last_impulse += actual
	return actual


func _update_detached(dt: float) -> void:
	for part in _detached.keys():
		var previous: float = float(_detached[part])
		_detached[part] = previous + dt
		if previous < 0.2 and float(_detached[part]) >= 0.2:
			for body: RigidBody2D in _parts:
				if body != _parts[int(part)]:
					body.remove_collision_exception_with(_parts[int(part)])
					_parts[int(part)].remove_collision_exception_with(body)


func cancel() -> void:
	# Revocation discards future work/charge; it never performs a release action,
	# erases momentum, resets a spring, or launches a charged leap.
	charge = 0.0
	if _flight_controller != null:
		_flight_controller.cancel()
		complete_step()
		_flight_mode_name = "passive_no_lease" if _power_enabled else "power_off"
		_last_impulse = Vector2.ZERO
		_last_torque_impulse = 0.0
		_last_energy_used = 0.0
		_movement_limited = false
	if _player_controller != null:
		_player_controller.cancel()
	_player_joint_targets.clear()
	_player_wheel_speeds.clear()
	_player_free_joints.clear()
	_charge_armed = false
	_previous_buttons = Vector3i.ZERO
	_smoothed_move = Vector2.ZERO
	_smoothed_trim = 0.0
	_thruster_levels = Vector2.ZERO
	_equipment_aim_enabled = false
	_action.clear()
	_effects.clear()
	gripped = false
	release_rope(false)
	for joint: Dictionary in _joints:
		joint.target = 0.0
		if joint.node is PinJoint2D:
			joint.node.motor_enabled = false
			joint.node.motor_target_velocity = 0.0
	# A fresh same-tick observation must describe the revoked charge, attachment
	# and motor state. Reuse copied physics samples; cancellation takes no step.
	if configured and fault.is_empty() and not _transforms.is_empty():
		_publish_observation()
		queue_redraw()


func draw_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(_parts.size()):
		var half: Vector2 = _sizes[index] * 0.5
		var polygon: PackedVector2Array = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)])
		if str(_part_defs[index].get("shape", "rectangle")) == "circle":
			polygon.clear()
			for vertex: int in range(32):
				polygon.append(Vector2.RIGHT.rotated(TAU * float(vertex) / 32.0) * half.x)
		for vertex: int in range(polygon.size()):
			polygon[vertex] = _transforms[index] * polygon[vertex]
		result.append({"id": str(_part_defs[index].id), "polygon": polygon,
			"shape": str(_part_defs[index].get("shape", "rectangle")),
			"colour": _part_defs[index].get("colour", _part_defs[index].get("color", Color(0.24, 0.85, 0.91))),
			"position": _transforms[index].origin, "rotation": _transforms[index].get_rotation()})
	return result


func _draw() -> void:
	if not configured or not fault.is_empty():
		return
	for part: Dictionary in draw_parts():
		var polygon: PackedVector2Array = part.polygon
		for index: int in range(polygon.size()):
			polygon[index] = to_local(polygon[index])
		var colour: Color = part.colour if part.colour is Color else Color(str(part.colour))
		draw_colored_polygon(polygon, colour)
		var outline: PackedVector2Array = polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, colour.darkened(0.65), 0.6, false)
	if rope_attached:
		draw_line(to_local(centre()), to_local(anchor), Color(0.84, 0.91, 0.65), 0.6, false)


func close() -> void:
	cancel()
	_player_controller = null
	_flight_controller = null
	_flight_capabilities.clear()
	configured = false
	for joint: Dictionary in _joints:
		if is_instance_valid(joint.node):
			joint.node.free()
		if joint.has("spring_node") and is_instance_valid(joint.spring_node):
			joint.spring_node.free()
		if joint.has("guide_node") and is_instance_valid(joint.guide_node):
			joint.guide_node.free()
	_joints.clear()
	for part: RigidBody2D in _parts:
		if is_instance_valid(part):
			part.free()
	_parts.clear()
	_sizes.clear()
	_part_defs.clear()
	_exclusions.clear()
	_mounts.clear()
	_detached.clear()
	_fixed_equipment.clear()
	_equipment_state.clear()
	_transforms.clear()
	_velocities.clear()
	_angular_velocities.clear()
	_inertias.clear()
	_thrusters.clear()
	_thrust_weights.clear()
	_observation.clear()

