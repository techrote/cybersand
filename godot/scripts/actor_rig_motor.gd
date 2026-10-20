class_name CyberActorRigMotor
extends CyberActorPrototype

# Owner-local sampled gameplay rig. The original Set A deliberately continues
# to instantiate CyberActorPrototype, preserving its exact controller behavior.
# No live Input, scene-tree, physics server, inference or background work lives
# here. The shared action packet describes intent; this motor owns admission.
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const RigEffects = preload("res://scripts/actor_rig_effects.gd")
const Actuation = preload("res://scripts/actor_rig_actuation.gd")
const RIG_VERSION: int = 1
const RIG_OBSERVATION_SIZE: int = 40
const ACTUATION_VERSION: int = Actuation.VERSION
const ACTUATION_OBSERVATION_SIZE: int = Actuation.OBSERVATION_SIZE
const RIG_MAX_TIMESTEP: float = 1.0 / 30.0
const RIG_MAX_SPEED: float = 160.0
const RIG_MAX_TRAVEL: float = 6.0
const RIG_SWEEP_STEPS: int = 6
const RIG_MAX_QUERIES: int = 96
const RIG_MAX_RAY_QUERIES: int = 64
const RIG_MAX_ANGULAR_SPEED: float = 6.0
const RIG_ANGULAR_STEPS: int = 8
const RIG_PIVOT_CLEARANCE: float = 0.001
const RIG_GRAVITY: float = 156.0
const RIG_RAY_RANGE: float = 44.0
const ROCKET_SURFACE_REACH: float = 6.0
const CLAMBERER_ADHESION_DRAIN: float = 0.025
const LINESHANK_BLADE_DRAIN: float = 0.06
const WORLD_LIMIT: float = 1024.0

var body_size: Vector2 = Vector2(8.0, 12.0)
var rotation: float = 0.0
var angular_velocity: float = 0.0
var contact_normal: Vector2 = Vector2.ZERO
var attachment_mode: int = 0
var anchor: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var tension: float = 0.0
var charge: float = 0.0
var auxiliary_active: bool = false
var locomotion_mode: int = 0
var air_jumps_remaining: int = 0
var ray_queries_last: int = 0
var edited_cells_last: int = 0
var effect_kind: int = 0
var effect_origin: Vector2 = Vector2.ZERO
var effect_strength: float = 0.0
var effect_radius: float = 0.0
var effect_reads_last: int = 0
var gait_phase: float = 0.0
var actuation: CyberActorRigActuation = Actuation.new()

var _base_body_size: Vector2 = body_size
var _rig_index: int = -1
var _auxiliary_held: bool = false
var _secondary_cooldown: float = 0.0
var _auxiliary_cooldown: float = 0.0
var _attach_lock: float = 0.0
var _contacts: int = 0 # down=1, left=2, right=4, up=8
var _gravity_scale: float = 1.0
var _recharge_rate: float = 0.18
var _powered: bool = false
var _coast_mode: bool = false
var _flight_mode: bool = false
var _dive_armed: bool = false
var _ricochet: bool = false
var _adhesion_exhausted: bool = false
var _allow_ledge: int = 1
var _travel_x: float = 0.0
var _travel_y: float = 0.0
var _rope_created: bool = false
var _ray_hit_point: Vector2 = Vector2.ZERO
var _ray_hit_normal: Vector2 = Vector2.ZERO
var _ray_hit_distance: float = 0.0
var _ray_budget_exhausted: bool = false
var _pending_effect: int = 0
var _pending_effect_origin: Vector2 = Vector2.ZERO
var _pending_effect_radius: int = 0
var _pending_effect_strength: float = 0.0
var _effects: CyberActorRigEffects = RigEffects.new()
var _metal_control: bool = false


func configure_model(candidate: StringName) -> bool:
	var index: int = Catalog.index_of(candidate)
	if index < 3:
		return false
	var definition: Dictionary = Catalog.entry(candidate)
	var configured_body: Vector2 = definition.get("body_size", Vector2(8.0, 12.0))
	if not configured_body.is_finite() or configured_body.x < 4.0 or configured_body.y < 4.0 \
		or configured_body.length() > 24.0:
		return false
	model_id = candidate
	_rig_index = index
	_base_body_size = configured_body
	body_size = configured_body
	actuation.configure_model(candidate)
	reset(position if position.is_finite() else Vector2.ZERO)
	return true


func reset(spawn_position: Vector2) -> void:
	super.reset(spawn_position)
	body_size = _base_body_size
	rotation = 0.0
	angular_velocity = 0.0
	_secondary_cooldown = 0.0
	_auxiliary_cooldown = 0.0
	_attach_lock = 0.0
	_coast_mode = false
	_flight_mode = false
	_metal_control = false
	_adhesion_exhausted = false
	_contacts = 0
	air_jumps_remaining = 2 if model_id == &"scout" else 0
	gait_phase = fposmod(position.x * 0.071 + position.y * 0.031, 1.0)
	clear_actions()
	charge = 0.0
	_clear_telemetry()
	_update_readiness()


func clear_actions() -> void:
	super.clear_actions()
	_auxiliary_held = false
	auxiliary_active = false
	charge = 0.0
	_dive_armed = false
	_ricochet = false
	_pending_effect = 0
	contact_normal = Vector2.ZERO
	attachment_mode = 0
	anchor = Vector2.ZERO
	rope_length = 0.0
	tension = 0.0
	_rope_created = false
	if _effects != null:
		_effects.clear()
	effect_kind = 0
	effect_origin = Vector2.ZERO
	effect_strength = 0.0
	effect_radius = 0.0
	if actuation != null:
		actuation.clear_output()
		actuation.remaining_energy = clampf(energy, 0.0, 1.0) if is_finite(energy) else 0.0
	_update_readiness()


func centre() -> Vector2:
	return position + body_size * 0.5


func recover_invalid_spawn(world) -> bool:
	# Explicit setup only. The runtime path never calls a recovery search, even
	# if granular material or a Rapier mask later enters the conservative proxy.
	invalid_spawn_recovery_attempts += 1
	last_recovery_kind = "invalid-spawn"
	last_recovery_offset = Vector2.ZERO
	if world == null or not position.is_finite():
		recovery_blocked = true
		return false
	var half: Vector2 = _half_extents(rotation)
	if not world.box_collides(centre() - half, half * 2.0):
		recovery_blocked = false
		runtime_enclosed = false
		return true
	var original: Vector2 = position
	for distance: int in range(1, RECOVERY_RADIUS + 1):
		for direction: Vector2 in RECOVERY_DIRECTIONS:
			var candidate: Vector2 = original + direction * float(distance)
			if not world.box_collides(candidate + body_size * 0.5 - half, half * 2.0):
				position = candidate
				velocity = Vector2.ZERO
				angular_velocity = 0.0
				last_recovery_offset = position - original
				invalid_spawn_recovery_successes += 1
				recovery_blocked = false
				runtime_enclosed = false
				return true
	recovery_blocked = true
	runtime_enclosed = true
	return false


func simulate_action(delta: float, movement: Vector2, primary: bool, secondary: bool, world,
		primary_pressed: bool = false, secondary_pressed: bool = false) -> void:
	simulate_rig_action(delta, movement, Vector2.ZERO, 0.7, 0.0, 0.0,
		primary, secondary, false, world, primary_pressed, secondary_pressed, false)


func simulate_rig_action(delta: float, movement: Vector2, aim: Vector2, effort: float,
		trim: float, reel: float, primary: bool, secondary: bool, auxiliary: bool, world,
		primary_pressed: bool = false, secondary_pressed: bool = false,
		auxiliary_pressed: bool = false) -> void:
	_simulate_rig_step(delta, movement, aim, effort, trim, reel, primary, secondary,
		auxiliary, world, primary_pressed, secondary_pressed, auxiliary_pressed, false, Vector4.ZERO)


func simulate_actuator_action(delta: float, actuators: Vector4, world) -> bool:
	# This is a separate control lane. Invalid packets never become neutral
	# high-level actions, and zero actuators still use direct passive dynamics.
	if not Actuation.supports_model(model_id):
		_clear_telemetry()
		actuation.flags = Actuation.UNSUPPORTED
		return false
	if not is_finite(delta) or delta <= 0.0 or not Actuation.valid_command(model_id, actuators):
		_clear_telemetry()
		actuation.flags = Actuation.INVALID
		movement_limited = not is_finite(delta) or delta < 0.0 or not Actuation.valid_command(model_id, actuators)
		return false
	if world == null or (world.has_method(&"has_failed") and world.has_failed()):
		_clear_telemetry()
		clear_actions()
		actuation.requested_actuators = Actuation.clamp_command(model_id, actuators)
		actuation.flags = Actuation.BLOCKED
		return false
	var advanced: bool = _simulate_rig_step(delta, Vector2.ZERO, Vector2.ZERO, 0.0,
		0.0, 0.0, false, false, false, world, false, false, false, true, actuators)
	if not advanced:
		# A blocked/enclosed actor performs no force solve or energy spend. The
		# consumed raw request remains inspectable beside its explicit refusal.
		actuation.requested_actuators = Actuation.clamp_command(model_id, actuators)
		actuation.flags = Actuation.BLOCKED
		actuation.remaining_energy = clampf(energy, 0.0, 1.0) if is_finite(energy) else 0.0
	return advanced


func _simulate_rig_step(delta: float, movement: Vector2, aim: Vector2, effort: float,
		trim: float, reel: float, primary: bool, secondary: bool, auxiliary: bool, world,
		primary_pressed: bool, secondary_pressed: bool, auxiliary_pressed: bool,
		metal_control: bool, actuators: Vector4) -> bool:
	_clear_telemetry()
	if not is_finite(delta) or delta <= 0.0:
		movement_limited = not is_finite(delta) or delta < 0.0
		return false
	if _metal_control != metal_control:
		_metal_control = metal_control
		clear_actions()
	if delta > RIG_MAX_TIMESTEP:
		movement_limited = true
		if metal_control:
			actuation.flags |= Actuation.DELTA_CLAMPED
	delta = minf(delta, RIG_MAX_TIMESTEP)
	movement = _finite_vector(movement)
	aim = _finite_vector(aim).limit_length(1.0)
	effort = _finite_scalar(effort, 0.0, 1.0)
	trim = _finite_scalar(trim, -1.0, 1.0)
	reel = _finite_scalar(reel, -1.0, 1.0)
	if not velocity.is_finite():
		velocity = Vector2.ZERO
		movement_limited = true
	if not is_finite(rotation) or not is_finite(angular_velocity):
		rotation = 0.0
		angular_velocity = 0.0
		movement_limited = true
	energy = clampf(energy, 0.0, 1.0) if is_finite(energy) else 0.0
	charge = clampf(charge, 0.0, 1.0) if is_finite(charge) else 0.0
	if metal_control:
		# Force evaluation cannot overflow on a malformed externally assigned
		# velocity. This state guard belongs only to the new direct lane.
		_bound_rig_velocity()
	var initial_velocity: Vector2 = velocity
	var initial_angular_velocity: float = angular_velocity
	var initial_centre: Vector2 = centre()
	var initial_rotation: float = rotation
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta) if is_finite(cooldown_remaining) else 0.0
	_secondary_cooldown = maxf(0.0, _secondary_cooldown - delta)
	_auxiliary_cooldown = maxf(0.0, _auxiliary_cooldown - delta)
	_attach_lock = maxf(0.0, _attach_lock - delta)
	var primary_edge: bool = primary_pressed or (primary and not _primary_held)
	var secondary_edge: bool = secondary_pressed or (secondary and not _secondary_held)
	var auxiliary_edge: bool = auxiliary_pressed or (auxiliary and not _auxiliary_held)
	var primary_release: bool = not primary and _primary_held
	_primary_held = primary
	_secondary_held = secondary
	_auxiliary_held = auxiliary
	if absf(movement.x) > MOTION_EPSILON:
		facing_x = signf(movement.x)
	if world == null or not position.is_finite() or _rig_index < 3:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		runtime_enclosed = true
		recovery_blocked = true
		grounded = false
		clear_actions()
		return false
	runtime_enclosure_recovery_enabled = false
	runtime_enclosed = _pose_collides(world, position, rotation, 0)
	recovery_blocked = runtime_enclosed
	if runtime_enclosed:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		grounded = false
		clear_actions()
		return false
	_read_contacts(world)
	grounded = (_contacts & 1) != 0 and velocity.y >= 0.0
	_coyote_remaining = 0.10 if grounded else maxf(0.0, _coyote_remaining - delta)
	if grounded and model_id == &"scout":
		air_jumps_remaining = 2
	_gravity_scale = 1.0
	_recharge_rate = 0.30 if grounded else 0.14
	_powered = false
	_allow_ledge = 1
	_ricochet = false
	locomotion_mode = 0 if grounded else 1
	gait_phase = fposmod(gait_phase + delta * (0.9 + minf(velocity.length(), 120.0) / 36.0), 1.0)
	if metal_control:
		_advance_actuators(delta, actuators)
	else:
		_advance_rig(delta, movement, _action_direction(aim), effort, trim, reel,
			primary, secondary, auxiliary, primary_edge, secondary_edge, auxiliary_edge,
			primary_release, world)
	if not _powered:
		energy = minf(1.0, energy + _recharge_rate * delta)
	velocity.y += RIG_GRAVITY * _gravity_scale * delta
	_advance_rotation(delta, world)
	_bound_rig_velocity()
	_apply_requested_effect(world)
	_sweep_axis(velocity.x * delta, 0, world)
	_sweep_axis(velocity.y * delta, 1, world)
	if velocity.y < 0.0:
		grounded = false
	elif not grounded:
		grounded = _pose_collides(world, position + Vector2(0.0, 0.55), rotation, 1)
	# Impact-only actions are requested by the collision stage and share the
	# same single effect slot/read-write caps as tool actions earlier this tick.
	_apply_requested_effect(world)
	_bound_rig_velocity()
	_copy_effect_telemetry()
	_update_readiness()
	if metal_control:
		actuation.delta_velocity = velocity - initial_velocity
		actuation.delta_angular_velocity = angular_velocity - initial_angular_velocity
		actuation.delta_position = centre() - initial_centre
		actuation.delta_rotation = wrapf(rotation - initial_rotation, -PI, PI)
		actuation.remaining_energy = energy
		if movement_limited:
			actuation.flags |= Actuation.MOTION_LIMITED
	return true


func _advance_actuators(delta: float, actuators: Vector4) -> void:
	# No _advance_rig intent policy is evaluated here. Floor adhesion, powered
	# impulse buttons, autovaults, target speeds and stabilizers are absent.
	_allow_ledge = 0
	_gravity_scale = 0.0 # Gravity is included in the reported passive wrench.
	actuation.solve(actuators, delta, rotation, velocity, angular_velocity, grounded, energy)
	energy = actuation.remaining_energy
	_powered = actuation.power_demand
	velocity += (actuation.applied_force + actuation.passive_force) * (delta / actuation.mass)
	angular_velocity += (actuation.applied_torque + actuation.passive_torque) * (delta / actuation.inertia)
	locomotion_mode = 8 if model_id == &"ripper" else 10
	if model_id == &"ripper" and absf(actuators.x) > MOTION_EPSILON:
		facing_x = signf(actuators.x)


func _clear_telemetry() -> void:
	query_count_last = 0
	ray_queries_last = 0
	edited_cells_last = 0
	effect_reads_last = 0
	movement_limited = false
	granular_disturbance_last = 0
	primary_active = false
	secondary_active = false
	auxiliary_active = false
	_travel_x = 0.0
	_travel_y = 0.0
	_ledge_attempted = false
	_rope_created = false
	_pending_effect = 0
	effect_kind = 0
	effect_origin = Vector2.ZERO
	effect_strength = 0.0
	effect_radius = 0.0
	_effects.clear()
	actuation.clear_output()
	actuation.remaining_energy = clampf(energy, 0.0, 1.0) if is_finite(energy) else 0.0


func _finite_vector(value: Vector2) -> Vector2:
	if not value.is_finite():
		movement_limited = true
		return Vector2.ZERO
	var bounded: Vector2 = Vector2(clampf(value.x, -1.0, 1.0), clampf(value.y, -1.0, 1.0))
	movement_limited = movement_limited or bounded != value
	return bounded


func _finite_scalar(value: float, minimum: float, maximum: float) -> float:
	if not is_finite(value):
		movement_limited = true
		return 0.0
	var bounded: float = clampf(value, minimum, maximum)
	movement_limited = movement_limited or bounded != value
	return bounded


func _action_direction(aim: Vector2) -> Vector2:
	return aim.normalized() if aim.length_squared() > 0.0001 else Vector2(facing_x * 0.7, -0.7).normalized()


func _spend(amount: float) -> bool:
	if amount < 0.0 or energy + 0.000001 < amount:
		return false
	energy = maxf(0.0, energy - amount)
	_powered = true
	return true


func _drive(delta: float, horizontal: float, speed: float, acceleration: float = 300.0,
		braking: float = 400.0) -> void:
	var rate: float = acceleration if absf(horizontal) > 0.001 else braking
	if not grounded:
		rate *= 0.35
	velocity.x = move_toward(velocity.x, horizontal * speed, rate * delta)


func _jump(direction: Vector2, speed: float, cost: float, cooldown: float = 0.18) -> bool:
	if cooldown_remaining > 0.0 or not _spend(cost):
		return false
	velocity = direction.normalized() * speed
	grounded = false
	_coyote_remaining = 0.0
	attachment_mode = 0
	contact_normal = Vector2.ZERO
	_attach_lock = 0.18
	primary_active = true
	cooldown_remaining = cooldown
	return true


func _advance_rig(delta: float, movement: Vector2, aim: Vector2, effort: float,
		trim: float, reel: float, primary: bool, secondary: bool, auxiliary: bool,
		primary_edge: bool, secondary_edge: bool, auxiliary_edge: bool,
		primary_release: bool, world) -> void:
	var pace: float = 0.45 + effort * 0.55
	match model_id:
		&"scout":
			_drive(delta, movement.x, 82.0 * pace, 950.0, 1050.0)
			_allow_ledge = 4
			if primary_edge and air_jumps_remaining > 0 and cooldown_remaining <= 0.0:
				if _spend(0.08):
					velocity.y = -(70.0 + 20.0 * effort)
					air_jumps_remaining -= 1
					grounded = false
					primary_active = true
					cooldown_remaining = 0.08
			if secondary and not grounded and velocity.y > 0.0 and _spend(0.10 * delta):
				_gravity_scale = 0.22
				velocity.y = minf(velocity.y, 24.0)
				secondary_active = true
				locomotion_mode = 7
		&"scrabbler":
			_drive(delta, movement.x, 28.0 * pace, 120.0, 170.0)
			# Three planted-foot phases modulate traction, not collision authority.
			if grounded:
				velocity.x *= 1.0 - 0.045 * (0.5 + 0.5 * sin(gait_phase * TAU * 3.0))
			_cling(delta, movement, secondary, 19.0 * pace, 0.12)
			angular_velocity += trim * 16.0 * delta
			if auxiliary:
				_self_right(delta)
			if primary_edge and (grounded or attachment_mode == 1):
				_jump(_away_direction(aim), 72.0 + 52.0 * effort, 0.24, 0.65)
		&"ripper":
			var traction: float = maxf(0.18, absf(cos(rotation)))
			_drive(delta, movement.x, 40.0 * pace * traction, 380.0, 850.0)
			angular_velocity += trim * 25.0 * delta
			if auxiliary:
				_self_right(delta)
			if secondary:
				velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
				angular_velocity = move_toward(angular_velocity, 0.0, 16.0 * delta)
				secondary_active = true
			elif (primary or primary_edge) and cooldown_remaining <= 0.0 and _spend(0.035):
				var blade: Vector2 = Vector2(facing_x, 0.0).rotated(rotation)
				_request_effect(1, centre() + blade * (body_size.x * 0.5 + 1.0), 3, effort)
				if grounded and primary_edge:
					velocity += blade * (28.0 + effort * 24.0)
				cooldown_remaining = 0.12
				primary_active = true
			locomotion_mode = 8
		&"groundeffect":
			_drive(delta, movement.x, 36.0 * pace, 95.0, 100.0)
			angular_velocity += (trim * 8.0 - rotation * 7.0 - angular_velocity * 3.0) * delta
			if secondary:
				velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta)
				secondary_active = true
			elif _spend((0.035 + 0.035 * effort) * delta):
				if _cast_surface(world, centre() + Vector2(0.0, _half_extents(rotation).y), Vector2.DOWN, 22.0):
					var clearance: float = 8.0 - movement.y * 4.0
					var lift: float = clampf(RIG_GRAVITY + (clearance - _ray_hit_distance) * 27.0 - velocity.y * 5.0, 0.0, 340.0)
					velocity.y -= lift * (effort / 0.7) * delta
					locomotion_mode = 9
				if primary_edge and cooldown_remaining <= 0.0 and _spend(0.18):
					velocity.y -= 38.0
					cooldown_remaining = 0.7
					primary_active = true
		&"digger":
			_drive(delta, movement.x, 11.0 * pace, 75.0, 220.0)
			if secondary:
				velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
				secondary_active = true
			elif (primary or primary_edge) and _spend((0.12 + effort * 0.12) * delta):
				# A downward-only cone makes lateral tunnelling deliberately poor.
				var drilling: Vector2 = Vector2(clampf(aim.x, -0.24, 0.24), 1.0).normalized()
				velocity.x = move_toward(velocity.x, drilling.x * 22.0 + movement.x * 7.0, 35.0 * delta)
				velocity.y = move_toward(velocity.y, 92.0 + 56.0 * effort, 680.0 * delta)
				if cooldown_remaining <= 0.0:
					_request_effect(1, centre() + drilling * (body_size.y * 0.5), 4, effort)
					cooldown_remaining = 0.065
				primary_active = true
				locomotion_mode = 5
		&"copter":
			if auxiliary_edge:
				_coast_mode = not _coast_mode
			auxiliary_active = _coast_mode
			var wobble: float = sin(gait_phase * TAU * 2.0)
			angular_velocity += (trim * 23.0 + wobble * 1.5) * delta
			if secondary:
				angular_velocity += (-rotation * 18.0 - angular_velocity * 9.0) * delta
				secondary_active = true
			if not _coast_mode and _spend((0.07 + (0.20 if primary else 0.0)) * delta):
				var thrust: float = RIG_GRAVITY * effort / 0.7 * (1.5 if primary else 1.0)
				velocity += Vector2.UP.rotated(rotation) * thrust * delta
				velocity += (movement.limit_length(1.0) * 42.0 + Vector2(wobble * 8.0, 0.0)) * delta
				primary_active = primary
				locomotion_mode = 10
			else:
				_recharge_rate = 0.34
		&"pouncer":
			_drive(delta, movement.x, 23.0 * pace, 190.0, 210.0)
			_advance_charge_leap(delta, aim, effort, primary, primary_edge, primary_release)
			angular_velocity += trim * 18.0 * delta
			if secondary and not grounded and _spend(0.09 * delta):
				_gravity_scale = 0.28
				velocity.y = minf(velocity.y, 25.0)
				secondary_active = true
				locomotion_mode = 7
			if auxiliary_edge and not grounded:
				angular_velocity += facing_x * 3.7
				velocity.y += 24.0
				auxiliary_active = true
		&"dropbot":
			_drive(delta, movement.x, 32.0 * pace, 320.0)
			_cling(delta, movement, secondary and not _dive_armed, 34.0 * pace, 0.17)
			angular_velocity += trim * 17.0 * delta
			if secondary and attachment_mode == 0 and not _dive_armed:
				velocity.y = move_toward(velocity.y, 0.0, 190.0 * delta)
				_gravity_scale = 0.35
				secondary_active = true
			if primary_edge and (grounded or attachment_mode == 1):
				_jump(_away_direction(aim), 65.0 + effort * 28.0, 0.14)
			if auxiliary_edge and not grounded and _auxiliary_cooldown <= 0.0 and _spend(0.20):
				_detach()
				_dive_armed = true
				velocity = Vector2(aim.x * 28.0, 100.0 + 50.0 * effort)
			if _dive_armed:
				_gravity_scale = 1.5
				auxiliary_active = true
				locomotion_mode = 13
		&"lineshank", &"swinger", &"winchbug":
			_advance_rope_rig(delta, movement, aim, effort, reel, primary_edge,
				secondary, secondary_edge, auxiliary_edge, world)
		&"walljumper", &"clamberer", &"claude", &"bonsai":
			_advance_surface_rig(delta, movement, aim, effort, primary_edge, secondary, auxiliary, world)
		&"rocketjumper":
			_drive(delta, movement.x, 44.0 * pace, 350.0)
			angular_velocity += trim * 17.0 * delta
			if secondary:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
				secondary_active = true
			elif primary_edge and cooldown_remaining <= 0.0 and energy >= 0.26:
				# The surface must be within six cells of the current proxy along
				# aim. Empty-air clicks spend nothing and cannot manufacture recoil.
				var edge_distance: float = _proxy_ray_radius(aim)
				if _cast_surface(world, centre(), aim, edge_distance + ROCKET_SURFACE_REACH, true):
					var gap: float = maxf(0.0, _ray_hit_distance - edge_distance)
					var falloff: float = 1.0 - 0.70 * clampf(gap / ROCKET_SURFACE_REACH, 0.0, 1.0)
					if _spend(0.26):
						# Protected contacts can support authored recoil without
						# allowing any terrain edits through or inside the contact.
						_request_effect(2, _ray_hit_point, 4, effort)
						velocity -= aim * (78.0 + 65.0 * effort) * falloff
						cooldown_remaining = 0.55
						primary_active = true
						grounded = false
		&"springjack":
			_drive(delta, movement.x, 34.0 * pace, 260.0)
			angular_velocity += (trim * 9.0 - rotation * 10.0 - angular_velocity * 4.0) * delta
			if secondary:
				velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
				if grounded:
					charge = minf(1.0, charge + delta * 0.85)
				secondary_active = true
			elif (primary or primary_edge) and grounded and cooldown_remaining <= 0.0:
				if _jump(Vector2(movement.x * 0.25, -1.0), 60.0 + effort * 30.0 + charge * 45.0, 0.09, 0.09):
					charge = 0.0
		&"gyrocrate":
			angular_velocity += (trim * 20.0 + movement.x * 11.0) * delta
			if primary and _spend(0.10 * delta):
				angular_velocity += (signf(movement.x) if absf(movement.x) > 0.01 else facing_x) * 24.0 * effort * delta
				primary_active = true
			if grounded:
				velocity.x = move_toward(velocity.x, angular_velocity * 4.5, 320.0 * delta)
			if secondary_edge and grounded and absf(angular_velocity) > 0.8:
				if _jump(Vector2.UP, 30.0 + minf(absf(angular_velocity), 6.0) * 11.0, 0.14):
					angular_velocity *= 0.35
					secondary_active = true
			if auxiliary:
				_self_right(delta)
			locomotion_mode = 8
		&"bellows":
			velocity += movement.limit_length(1.0) * 20.0 * delta
			if secondary:
				velocity = velocity.move_toward(Vector2.ZERO, 280.0 * delta)
				charge = minf(1.0, charge + 0.85 * delta)
				_recharge_rate = 0.52
				secondary_active = true
			else:
				charge = minf(1.0, charge + 0.10 * delta)
			if auxiliary_edge:
				charge = 0.0
				auxiliary_active = true
			elif primary_edge and not secondary and cooldown_remaining <= 0.0 and _spend(0.11):
				velocity += aim * (35.0 + charge * 100.0) * pace
				charge = maxf(0.0, charge - 0.45)
				cooldown_remaining = 0.18
				primary_active = true
		&"magpie":
			_drive(delta, movement.x, 30.0 * pace)
			_cling(delta, movement, secondary and not auxiliary, 15.0 * pace, 0.10)
			charge = minf(1.0, charge + delta * (0.8 if attachment_mode == 1 else 0.08))
			if auxiliary:
				_detach()
				auxiliary_active = true
			elif primary_edge and cooldown_remaining <= 0.0 and charge >= 0.15:
				if _cast_surface(world, centre(), aim, 36.0):
					if _jump((_ray_hit_point - centre()).normalized(), 45.0 + 90.0 * charge * pace, 0.22, 0.5):
						charge = 0.0
		&"skatesail":
			_drive(delta, movement.x, 76.0 * pace, 180.0, 45.0)
			if primary_edge and grounded:
				if cooldown_remaining <= 0.0 and _spend(0.06):
					velocity.y = -48.0
					grounded = false
					cooldown_remaining = 0.15
					primary_active = true
			if secondary and not auxiliary:
				# Lift comes from retained horizontal speed and remains below
				# gravity: a stationary deployed sail cannot become a hover motor.
				var incidence: float = clampf(0.7 + trim * 0.6, 0.0, 1.1)
				velocity.y -= minf(140.0, absf(velocity.x) * 1.8) * incidence * delta
				angular_velocity += (trim * 0.5 - rotation - angular_velocity * 0.3) * 9.0 * delta
				secondary_active = true
				locomotion_mode = 7
			if auxiliary:
				velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
				auxiliary_active = true
		&"astra", &"luna":
			velocity += movement.limit_length(1.0) * (45.0 if model_id == &"astra" else 35.0) * delta
			var astra: bool = model_id == &"astra"
			if astra and auxiliary_edge:
				_coast_mode = not _coast_mode
			if not _coast_mode:
				velocity.x = move_toward(velocity.x, movement.x * 34.0, 50.0 * delta)
			_gravity_scale = 0.7 if astra else 0.6
			if secondary and _spend((0.28 if astra else 0.17) * delta):
				velocity = velocity.move_toward(Vector2.ZERO, (650.0 if astra else 850.0) * delta)
				_gravity_scale = 0.0
				secondary_active = true
			elif primary_edge and cooldown_remaining <= 0.0 and _spend(0.20 if astra else 0.075):
				velocity += aim * ((70.0 + 45.0 * effort) if astra else (34.0 + 30.0 * effort))
				cooldown_remaining = 0.40 if astra else 0.14
				primary_active = true
			auxiliary_active = _coast_mode if astra else false
		&"qwen":
			if auxiliary_edge:
				_flight_mode = not _flight_mode
				_detach()
			if _flight_mode:
				if _spend((0.14 + (0.18 if primary else 0.0)) * delta):
					_gravity_scale = 0.0
					var target: Vector2 = movement.limit_length(1.0) * ((88.0 if primary else 54.0) * pace)
					velocity = velocity.move_toward(target, 300.0 * delta)
					primary_active = primary
					angular_velocity += trim * 12.0 * delta
			else:
				_drive(delta, movement.x, 48.0 * pace, 460.0)
				if primary_edge and grounded:
					_jump(Vector2(aim.x * 0.4, -1.0), 68.0 + 20.0 * effort, 0.12)
			if secondary:
				velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
				secondary_active = true
			locomotion_mode = 1 if _flight_mode else 0
			auxiliary_active = _flight_mode
		&"jev":
			velocity += movement.limit_length(1.0) * 45.0 * delta
			angular_velocity += trim * 28.0 * delta
			if auxiliary:
				_self_right(delta)
			if primary_edge and cooldown_remaining <= 0.0 and _spend(0.18):
				velocity += aim * (92.0 + effort * 60.0)
				cooldown_remaining = 0.33
				primary_active = true
			_ricochet = secondary and energy > 0.02
			secondary_active = _ricochet
		&"gemini":
			velocity += movement.limit_length(1.0) * 24.0 * delta
			var left: float = (1.0 + trim * 0.6) if primary else 0.0
			var right: float = (1.0 - trim * 0.6) if secondary else 0.0
			if left + right > 0.0 and _spend((left + right) * 0.085 * delta):
				velocity += Vector2.UP.rotated(rotation) * RIG_GRAVITY * (effort / 1.4) * (left + right) * delta
				angular_velocity += (left - right) * effort * 21.0 * delta
				primary_active = primary
				secondary_active = secondary
			if auxiliary_edge and _auxiliary_cooldown <= 0.0 and _spend(0.22):
				velocity += aim * (70.0 + effort * 40.0)
				_auxiliary_cooldown = 0.5
				auxiliary_active = true
			locomotion_mode = 10


func _advance_charge_leap(delta: float, aim: Vector2, effort: float, primary: bool,
		primary_edge: bool, primary_release: bool) -> void:
	if primary and grounded:
		charge = minf(0.25 + effort * 0.75, charge + delta * 1.25)
		velocity.x = move_toward(velocity.x, 0.0, 140.0 * delta)
		primary_active = true
		locomotion_mode = 6
	if (primary_release or (primary_edge and not primary)) and (grounded or _coyote_remaining > 0.0):
		var launch_charge: float = maxf(charge, 0.12)
		var leap: Vector2 = Vector2(aim.x, minf(aim.y, -0.18)).normalized()
		if _jump(leap, 58.0 + launch_charge * 92.0, 0.12 + launch_charge * 0.18, 0.28):
			charge = 0.0
	elif not primary and charge > 0.0:
		charge = 0.0


func _advance_surface_rig(delta: float, movement: Vector2, aim: Vector2, effort: float,
		primary_edge: bool, secondary: bool, auxiliary: bool, world) -> void:
	var walljumper: bool = model_id == &"walljumper"
	var clamberer: bool = model_id == &"clamberer"
	var bonsai: bool = model_id == &"bonsai"
	var pace: float = 0.5 + effort * 0.5
	_drive(delta, movement.x, (42.0 if walljumper else 28.0) * pace, 450.0)
	if clamberer or bonsai:
		var previous_size: Vector2 = body_size
		_try_resize(Vector2(_base_body_size.x, 6.0) if auxiliary else _base_body_size, world)
		if body_size != previous_size:
			# Center-preserving tuck can remove a floor/ceiling contact. The
			# attachment decision must use the accepted new collision volume.
			_read_contacts(world)
			grounded = (_contacts & 1) != 0 and velocity.y >= 0.0
			locomotion_mode = 0 if grounded else 1
		auxiliary_active = body_size != _base_body_size
	var drain: float = 1.15 if walljumper else (0.035 if bonsai else (CLAMBERER_ADHESION_DRAIN if clamberer else 0.065))
	var release: bool = walljumper and auxiliary
	_cling(delta, movement, secondary and not release, (17.0 if walljumper else 22.0) * pace, drain)
	if release:
		_detach()
		auxiliary_active = true
	if bonsai and (grounded or attachment_mode == 1):
		charge = minf(1.0, charge + delta * 0.65)
	if primary_edge and (grounded or attachment_mode == 1 or _coyote_remaining > 0.0):
		var speed: float = 40.0 + 70.0 * effort if walljumper else (42.0 + 50.0 * charge if bonsai else 47.0 + effort * 15.0)
		if _jump(_away_direction(aim), speed, 0.18 if walljumper else 0.10, 0.2):
			charge = 0.0
	if model_id == &"claude":
		_allow_ledge = 4
		if auxiliary and not grounded and _spend(0.09 * delta):
			velocity.y = minf(velocity.y, 24.0)
			_gravity_scale = 0.35
			auxiliary_active = true


func _self_right(delta: float) -> void:
	angular_velocity += (-wrapf(rotation, -PI, PI) * 20.0 - angular_velocity * 7.0) * delta
	auxiliary_active = true


func _cling(delta: float, movement: Vector2, requested: bool, speed: float, drain: float) -> void:
	if _adhesion_exhausted and energy >= 0.20:
		_adhesion_exhausted = false
	if not requested or _attach_lock > 0.0 or _adhesion_exhausted:
		if attachment_mode == 1:
			_detach()
		return
	var normal: Vector2 = _select_contact(movement)
	if normal == Vector2.ZERO:
		if attachment_mode == 1:
			_detach()
		return
	if not _spend(drain * delta):
		_adhesion_exhausted = true
		_detach()
		return
	contact_normal = normal
	attachment_mode = 1
	var tangent: Vector2 = Vector2(-normal.y, normal.x)
	velocity = tangent * movement.dot(tangent) * speed - normal * 2.0
	_gravity_scale = 0.0
	secondary_active = true
	locomotion_mode = 2
	grounded = normal == Vector2.UP


func _select_contact(movement: Vector2) -> Vector2:
	if movement.x > 0.1 and (_contacts & 4) != 0:
		return Vector2.LEFT
	if movement.x < -0.1 and (_contacts & 2) != 0:
		return Vector2.RIGHT
	if movement.y < -0.1 and (_contacts & 8) != 0:
		return Vector2.DOWN
	if attachment_mode == 1 and _normal_still_supported(contact_normal):
		return contact_normal
	if movement.y < -0.1:
		if (_contacts & 2) != 0:
			return Vector2.RIGHT
		if (_contacts & 4) != 0:
			return Vector2.LEFT
	if (_contacts & 8) != 0:
		return Vector2.DOWN
	if (_contacts & 1) != 0 and velocity.y >= 0.0:
		return Vector2.UP
	if (_contacts & 2) != 0:
		return Vector2.RIGHT
	if (_contacts & 4) != 0:
		return Vector2.LEFT
	return Vector2.ZERO


func _normal_still_supported(normal: Vector2) -> bool:
	if normal == Vector2.UP:
		return (_contacts & 1) != 0 and velocity.y >= 0.0
	if normal == Vector2.RIGHT:
		return (_contacts & 2) != 0
	if normal == Vector2.LEFT:
		return (_contacts & 4) != 0
	if normal == Vector2.DOWN:
		return (_contacts & 8) != 0
	return false


func _away_direction(direction: Vector2) -> Vector2:
	if attachment_mode == 1:
		var dot: float = direction.dot(contact_normal)
		if dot < 0.25:
			direction += contact_normal * (0.40 - dot)
	elif grounded:
		direction.y = minf(direction.y, -0.20)
	return direction.normalized()


func _detach() -> void:
	attachment_mode = 0
	contact_normal = Vector2.ZERO
	anchor = Vector2.ZERO
	rope_length = 0.0
	tension = 0.0
	# Detaching changes the constraint, never erases retained linear momentum.


func _advance_rope_rig(delta: float, movement: Vector2, aim: Vector2, effort: float,
		reel: float, primary_edge: bool, secondary: bool, secondary_edge: bool,
		auxiliary_edge: bool, world) -> void:
	var bungee: bool = model_id == &"lineshank"
	var winch: bool = model_id == &"winchbug"
	_drive(delta, movement.x, 20.0 if winch else 42.0, 230.0, 120.0)
	var release: bool = auxiliary_edge if bungee or winch else secondary_edge
	if release:
		if bungee and attachment_mode == 3:
			# A bounded horizontal release kick spends the stored elastic state.
			velocity.x += facing_x * tension * 28.0
		_detach()
		auxiliary_active = bungee or winch
		secondary_active = not (bungee or winch)
	elif primary_edge and cooldown_remaining <= 0.0:
		if _cast_surface(world, centre(), aim, RIG_RAY_RANGE) and _ray_hit_distance >= 5.0:
			if _spend(0.06):
				anchor = _ray_hit_point
				rope_length = clampf(centre().distance_to(anchor) * (0.68 if bungee else 1.0), 6.0, RIG_RAY_RANGE)
				attachment_mode = 3 if bungee else 2
				_rope_created = true
				cooldown_remaining = 0.16
				primary_active = true
	if attachment_mode == 2 or attachment_mode == 3:
		if not _rope_created:
			var target: Vector2 = anchor
			var offset: Vector2 = target - centre()
			if offset.length() > RIG_RAY_RANGE + 8.0 or offset.length_squared() < 0.0001:
				_detach()
			elif not _cast_surface(world, centre(), offset.normalized(), minf(offset.length() + 1.5, RIG_RAY_RANGE + 8.0)):
				_detach()
			elif Vector2i(_ray_hit_point.floor()) != Vector2i(target.floor()):
				_detach()
		if attachment_mode != 0:
			if not _spend(0.045 * delta):
				_detach()
			else:
				var radial: Vector2 = centre() - anchor
				var distance: float = radial.length()
				var outward: Vector2 = radial / maxf(distance, 0.001)
				var reel_speed: float = (8.0 + effort * 14.0) if winch else 24.0
				rope_length = clampf(rope_length + reel * reel_speed * delta, 6.0, RIG_RAY_RANGE)
				var stretch: float = maxf(0.0, distance - rope_length)
				var stiffness: float = (24.0 + effort * 20.0) if bungee else 95.0
				var damping: float = 2.4 if bungee else (15.0 if winch and secondary else 8.0)
				var pull: float = clampf(stretch * stiffness + maxf(0.0, velocity.dot(outward)) * damping, 0.0, 1500.0)
				velocity -= outward * pull * delta
				var tangent: Vector2 = Vector2(-outward.y, outward.x)
				velocity += tangent * movement.x * (24.0 if winch else 65.0) * delta
				tension = clampf(pull / 1500.0, 0.0, 1.0)
				primary_active = true
				locomotion_mode = 4 if bungee else 3
				if winch and secondary:
					velocity = velocity.move_toward(Vector2.ZERO, 190.0 * delta)
					secondary_active = true
	if bungee and secondary_edge and _secondary_cooldown <= 0.0 and _spend(0.09):
		velocity += Vector2(aim.x * 18.0, -(28.0 + effort * 22.0))
		_request_effect(1, centre() + aim * (body_size.y * 0.5), 2, effort)
		_secondary_cooldown = 0.24
		secondary_active = true
	if bungee and secondary and _spend(LINESHANK_BLADE_DRAIN * delta):
		_advance_blade(delta, aim, effort)
		secondary_active = true
		if attachment_mode == 0:
			locomotion_mode = 7


func _advance_blade(delta: float, aim: Vector2, effort: float) -> void:
	# The long body axis is the knife. Aim requests its attitude; the same
	# bounded rotation sweep can refuse a blocked pose. Lift uses the current
	# accepted attitude and existing airspeed, so the blade cannot hover at rest.
	var requested_angle: float = aim.angle() + PI * 0.5
	var error: float = wrapf(requested_angle - rotation, -PI, PI)
	angular_velocity += clampf(error * 24.0 - angular_velocity * 7.0, -48.0, 48.0) * delta
	var airspeed: float = minf(velocity.length(), RIG_MAX_SPEED)
	if airspeed <= 0.01:
		return
	var flow: Vector2 = velocity.normalized()
	var blade_axis: Vector2 = Vector2.UP.rotated(rotation)
	var incidence: float = flow.cross(blade_axis)
	var lift_coefficient: float = 2.0 * incidence * flow.dot(blade_axis)
	var lift: float = clampf(airspeed * airspeed * lift_coefficient * (0.020 + effort * 0.015), -240.0, 240.0)
	var drag: float = minf(240.0, airspeed * airspeed * (0.002 + 0.013 * incidence * incidence))
	velocity += Vector2(-flow.y, flow.x) * lift * delta
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)


func _read_contacts(world) -> void:
	_contacts = 0
	if _pose_collides(world, position + Vector2(0.0, 0.55), rotation, 1):
		_contacts |= 1
	if _pose_collides(world, position + Vector2(-0.55, 0.0), rotation, 2):
		_contacts |= 2
	if _pose_collides(world, position + Vector2(0.55, 0.0), rotation, 2):
		_contacts |= 4
	if _pose_collides(world, position + Vector2(0.0, -0.55), rotation, 3):
		_contacts |= 8


func _half_extents(angle: float) -> Vector2:
	var cosine: float = absf(cos(angle))
	var sine: float = absf(sin(angle))
	return Vector2(body_size.x * cosine + body_size.y * sine,
		body_size.x * sine + body_size.y * cosine) * 0.5


func _proxy_ray_radius(direction: Vector2) -> float:
	var half: Vector2 = _half_extents(rotation)
	return minf(half.x / absf(direction.x) if absf(direction.x) > 0.000001 else INF,
		half.y / absf(direction.y) if absf(direction.y) > 0.000001 else INF)


func _pose_collides(world, candidate: Vector2, angle: float, mode: int) -> bool:
	return _box_query(world, candidate + body_size * 0.5, _half_extents(angle), mode)


func _box_query(world, centre_position: Vector2, half: Vector2, mode: int) -> bool:
	if query_count_last >= RIG_MAX_QUERIES:
		movement_limited = true
		return true
	query_count_last += 1
	if mode == 0:
		return world.box_collides(centre_position - half, half * 2.0)
	return world.character_box_collides(centre_position - half, half * 2.0, mode)


func _rotation_interval_half(first: float, last: float) -> Vector2:
	# Exact maximum AABB extents over this short angle interval, including an
	# interior maximum. Endpoint-only angle checks can miss a grazing thin wall.
	var half: Vector2 = _half_extents(first).max(_half_extents(last))
	var low: float = minf(first, last)
	var high: float = maxf(first, last)
	var x_peak: float = atan2(body_size.y, body_size.x)
	var y_peak: float = atan2(body_size.x, body_size.y)
	for turn: int in range(-2, 3):
		var offset: float = float(turn) * PI
		var candidate: float = offset + x_peak
		if candidate >= low and candidate <= high:
			half = half.max(_half_extents(candidate))
		candidate = offset - x_peak
		if candidate >= low and candidate <= high:
			half = half.max(_half_extents(candidate))
		candidate = offset + y_peak
		if candidate >= low and candidate <= high:
			half = half.max(_half_extents(candidate))
		candidate = offset - y_peak
		if candidate >= low and candidate <= high:
			half = half.max(_half_extents(candidate))
	return half


func _advance_rotation(delta: float, world) -> void:
	var bounded: float = clampf(angular_velocity, -RIG_MAX_ANGULAR_SPEED, RIG_MAX_ANGULAR_SPEED)
	movement_limited = movement_limited or bounded != angular_velocity
	angular_velocity = bounded
	var change: float = angular_velocity * delta
	if absf(change) <= 0.000001:
		return
	var count: int = clampi(ceili(absf(change) / 0.03), 1, RIG_ANGULAR_STEPS)
	var trial_position: Vector2 = position
	var trial_angle: float = rotation
	var support_bottom: float = centre().y + _half_extents(rotation).y
	# The half-diagonal bounds the rate of change of vertical AABB extent at
	# every angle, including quadrant cusps. Charge this conservative bound for
	# the complete pivot path, plus its small numerical clearance, before any
	# linear sweep can spend the remaining travel allowance.
	var used_y: float = body_size.length() * 0.5 * absf(change) + RIG_PIVOT_CLEARANCE if grounded else 0.0
	for index: int in range(count):
		var next_angle: float = rotation + change * float(index + 1) / float(count)
		var interval_half: Vector2 = _rotation_interval_half(trial_angle, next_angle)
		var envelope_centre: Vector2 = trial_position + body_size * 0.5
		if grounded:
			# One fixed support height avoids accumulating Float32 subtraction
			# error into the floor. This envelope covers the whole grounded
			# angular interval; the accepted endpoint uses its own true extent.
			envelope_centre.y = support_bottom - interval_half.y - RIG_PIVOT_CLEARANCE
			trial_position.y = support_bottom - _half_extents(next_angle).y - body_size.y * 0.5 - RIG_PIVOT_CLEARANCE
		if _travel_y + used_y > RIG_MAX_TRAVEL or _box_query(world, envelope_centre, interval_half, 0):
			angular_velocity = 0.0
			movement_limited = true
			if _metal_control:
				actuation.flags |= Actuation.COLLISION_CONSTRAINED
			return
		trial_angle = next_angle
	position = trial_position
	rotation = wrapf(trial_angle, -PI, PI)
	_travel_y += used_y


func _try_resize(requested: Vector2, world) -> bool:
	if requested == body_size:
		return true
	var old_size: Vector2 = body_size
	var old_centre: Vector2 = centre()
	body_size = requested
	var candidate: Vector2 = old_centre - body_size * 0.5
	if _pose_collides(world, candidate, rotation, 0):
		body_size = old_size
		return false
	position = candidate
	return true


func _sweep_axis(distance: float, axis: int, world) -> void:
	if axis == 1:
		grounded = false
	var used: float = _travel_x if axis == 0 else _travel_y
	var available: float = maxf(0.0, RIG_MAX_TRAVEL - used)
	var remaining: float = clampf(distance, -available, available)
	movement_limited = movement_limited or remaining != distance
	for _step: int in range(RIG_SWEEP_STEPS):
		if absf(remaining) <= 0.000001:
			return
		var step: float = clampf(remaining, -1.0, 1.0)
		var displacement: Vector2 = Vector2(step, 0.0) if axis == 0 else Vector2(0.0, step)
		var candidate: Vector2 = position + displacement
		var mode: int = 2 if axis == 0 else (1 if step > 0.0 else 3)
		if _pose_collides(world, candidate, rotation, mode):
			if _metal_control:
				actuation.flags |= Actuation.COLLISION_CONSTRAINED
			if axis == 0 and grounded and velocity.y >= 0.0 and attachment_mode == 0 \
				and not _ledge_attempted and _allow_ledge > 0:
				if _try_rig_ledge(step, world):
					remaining -= step
					continue
			var impact: float = velocity.x if axis == 0 else velocity.y
			var normal: Vector2 = Vector2(-signf(step), 0.0) if axis == 0 else Vector2(0.0, -signf(step))
			if _ricochet and absf(impact) > 18.0 and _spend(0.012):
				if axis == 0:
					velocity.x = -impact * 0.58
				else:
					velocity.y = -impact * 0.58
				angular_velocity += impact * 0.008
				contact_normal = normal
				return
			if axis == 0:
				velocity.x = 0.0
			else:
				velocity.y = 0.0
				if step > 0.0:
					grounded = true
					if _dive_armed and impact > 45.0:
						_dive_armed = false
						_auxiliary_cooldown = 0.7
						_request_effect(2, centre() + Vector2(0.0, _half_extents(rotation).y + 1.0), 3, 0.65)
						velocity.y = -minf(72.0, impact * 0.45)
						grounded = false
					elif world.has_method(&"character_disturb_granular"):
						var half: Vector2 = _half_extents(rotation)
						granular_disturbance_last = int(world.character_disturb_granular(
							candidate + body_size * 0.5 - half, half * 2.0, impact))
						granular_disturbance_total += granular_disturbance_last
			return
		position = candidate
		if axis == 0:
			_travel_x += absf(step)
		else:
			_travel_y += absf(step)
		remaining -= step


func _try_rig_ledge(horizontal: float, world) -> bool:
	_ledge_attempted = true
	var maximum: int = mini(_allow_ledge, floori(RIG_MAX_TRAVEL - _travel_y))
	for height: int in range(1, maximum + 1):
		var raised: Vector2 = position + Vector2(0.0, -float(height))
		if _pose_collides(world, raised, rotation, 0):
			return false
		var candidate: Vector2 = raised + Vector2(horizontal, 0.0)
		if _pose_collides(world, candidate, rotation, 0):
			continue
		if not _pose_collides(world, candidate + Vector2(0.0, 0.55), rotation, 1):
			continue
		position = candidate
		_travel_y += float(height)
		_travel_x += absf(horizontal)
		return true
	return false


func _bound_rig_velocity() -> void:
	if not velocity.is_finite():
		velocity = Vector2.ZERO
		movement_limited = true
		return
	var bounded: Vector2 = Vector2(clampf(velocity.x, -RIG_MAX_SPEED, RIG_MAX_SPEED),
		clampf(velocity.y, -RIG_MAX_SPEED, RIG_MAX_SPEED)).limit_length(RIG_MAX_SPEED)
	movement_limited = movement_limited or bounded != velocity
	velocity = bounded
	angular_velocity = clampf(angular_velocity, -RIG_MAX_ANGULAR_SPEED, RIG_MAX_ANGULAR_SPEED)


func _cast_surface(world, origin: Vector2, direction: Vector2, maximum: float,
		include_excavatable: bool = false) -> bool:
	_ray_budget_exhausted = false
	_ray_hit_point = Vector2.ZERO
	_ray_hit_normal = Vector2.ZERO
	_ray_hit_distance = 0.0
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 \
		or not world.has_method(&"material_at"):
		return false
	if origin.x < 0.0 or origin.y < 0.0 or origin.x >= WORLD_LIMIT or origin.y >= WORLD_LIMIT:
		return false
	direction = direction.normalized()
	var cell: Vector2i = Vector2i(origin.floor())
	var step_x: int = signf(direction.x)
	var step_y: int = signf(direction.y)
	var delta_x: float = 1.0 / absf(direction.x) if step_x != 0 else INF
	var delta_y: float = 1.0 / absf(direction.y) if step_y != 0 else INF
	var next_x: float = (float(cell.x + (1 if step_x > 0 else 0)) - origin.x) / direction.x if step_x != 0 else INF
	var next_y: float = (float(cell.y + (1 if step_y > 0 else 0)) - origin.y) / direction.y if step_y != 0 else INF
	var distance: float = 0.0
	var normal: Vector2 = -direction
	for _step: int in range(RIG_MAX_RAY_QUERIES):
		if distance > maximum or not _ray_cell_in_world(cell):
			return false
		var material: int = _read_ray_material(world, cell)
		if material < 0:
			return false
		if _hard_material(material) or (include_excavatable and RigEffects.editable_material(material)):
			_ray_hit_point = Vector2(cell) + Vector2(0.5, 0.5)
			_ray_hit_normal = normal
			_ray_hit_distance = distance
			return true
		if absf(next_x - next_y) < 0.000001:
			if next_x > maximum:
				return false
			# Supercover corner: either adjacent cell can block the diagonal.
			var corner_x: Vector2i = cell + Vector2i(step_x, 0)
			var corner_y: Vector2i = cell + Vector2i(0, step_y)
			if not _ray_cell_in_world(corner_x) or not _ray_cell_in_world(corner_y):
				return false
			material = _read_ray_material(world, corner_x)
			if material < 0:
				return false
			if _hard_material(material) or (include_excavatable and RigEffects.editable_material(material)):
				_ray_hit_point = Vector2(corner_x) + Vector2(0.5, 0.5)
				_ray_hit_normal = Vector2(-step_x, 0.0)
				_ray_hit_distance = next_x
				return true
			material = _read_ray_material(world, corner_y)
			if material < 0:
				return false
			if _hard_material(material) or (include_excavatable and RigEffects.editable_material(material)):
				_ray_hit_point = Vector2(corner_y) + Vector2(0.5, 0.5)
				_ray_hit_normal = Vector2(0.0, -step_y)
				_ray_hit_distance = next_y
				return true
			cell += Vector2i(step_x, step_y)
			distance = next_x
			next_x += delta_x
			next_y += delta_y
			normal = -direction
		elif next_x < next_y:
			cell.x += step_x
			distance = next_x
			next_x += delta_x
			normal = Vector2(-step_x, 0.0)
		else:
			cell.y += step_y
			distance = next_y
			next_y += delta_y
			normal = Vector2(0.0, -step_y)
	movement_limited = true
	_ray_budget_exhausted = true
	return false


func _read_ray_material(world, cell: Vector2i) -> int:
	if ray_queries_last >= RIG_MAX_RAY_QUERIES:
		movement_limited = true
		_ray_budget_exhausted = true
		return -1
	ray_queries_last += 1
	return int(world.material_at(cell.x, cell.y))


static func _ray_cell_in_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < 1024 and cell.y < 1024


static func _hard_material(material: int) -> bool:
	return material == 1 or material == 5 or material == 7 or material == 9 \
		or material == 28 or material == 31 or material == 35 \
		or (material >= 38 and material <= CyberCellWorld.LAST_MATERIAL)


func _request_effect(kind: int, origin: Vector2, radius: int, strength: float) -> void:
	if _pending_effect != 0 or _effects.kind != 0:
		return
	_pending_effect = kind
	_pending_effect_origin = origin
	_pending_effect_radius = radius
	_pending_effect_strength = strength


func _apply_requested_effect(world) -> void:
	if _pending_effect == 0:
		return
	var target: Vector2 = _pending_effect_origin
	var source: Vector2 = centre()
	var offset: Vector2 = target - source
	if offset.length_squared() > 0.0001:
		# The authored muzzle/tip may lie beyond an adjacent one-cell wall.
		# Clamp it to the first actual contact before the footprint's cached
		# occlusion pass; exhausting the shared ray budget refuses the effect.
		if _cast_surface(world, source, offset.normalized(), offset.length()):
			target = _ray_hit_point
		elif _ray_budget_exhausted:
			_pending_effect = 0
			return
	_effects.apply(world, _pending_effect, target,
		_pending_effect_radius, _pending_effect_strength)
	_pending_effect = 0


func _copy_effect_telemetry() -> void:
	effect_kind = _effects.kind
	effect_origin = _effects.origin
	effect_radius = _effects.radius
	effect_strength = _effects.strength
	effect_reads_last = _effects.reads_last
	edited_cells_last = _effects.writes_last


func _update_readiness() -> void:
	if _metal_control:
		primary_ready = false
		secondary_ready = false
		return
	if runtime_enclosed or recovery_blocked:
		primary_ready = false
		secondary_ready = false
		return
	var cost: float = 0.0
	var continuous: bool = false
	var supported: bool = grounded or attachment_mode == 1 or _coyote_remaining > 0.0
	primary_ready = true
	secondary_ready = _secondary_cooldown <= 0.0
	match model_id:
		&"scout":
			cost = 0.08
			primary_ready = air_jumps_remaining > 0
			secondary_ready = energy >= 0.10 * RIG_MAX_TIMESTEP
		&"scrabbler":
			cost = 0.24
			primary_ready = supported
			secondary_ready = energy >= 0.12 * RIG_MAX_TIMESTEP and not _adhesion_exhausted
		&"ripper":
			cost = 0.035
			primary_ready = not secondary_active
		&"groundeffect":
			cost = 0.183
			primary_ready = not secondary_active
		&"digger":
			cost = 0.24 * RIG_MAX_TIMESTEP
			continuous = true
			primary_ready = not secondary_active
		&"copter":
			cost = 0.27 * RIG_MAX_TIMESTEP
			continuous = true
			primary_ready = not _coast_mode
		&"pouncer":
			cost = 0.12 + maxf(charge, 0.12) * 0.18
			primary_ready = supported
			secondary_ready = energy >= 0.09 * RIG_MAX_TIMESTEP
		&"dropbot":
			cost = 0.14
			primary_ready = supported
		&"lineshank":
			cost = 0.06
			secondary_ready = energy >= LINESHANK_BLADE_DRAIN * RIG_MAX_TIMESTEP
		&"swinger", &"winchbug":
			cost = 0.06
			secondary_ready = attachment_mode == 2
		&"walljumper":
			cost = 0.18
			primary_ready = supported
			secondary_ready = energy >= 1.15 * RIG_MAX_TIMESTEP and not _adhesion_exhausted
		&"clamberer", &"claude", &"bonsai":
			cost = 0.10
			primary_ready = supported
			var drain: float = CLAMBERER_ADHESION_DRAIN if model_id == &"clamberer" else (0.035 if model_id == &"bonsai" else 0.065)
			secondary_ready = energy >= drain * RIG_MAX_TIMESTEP and not _adhesion_exhausted
		&"rocketjumper":
			cost = 0.26
			primary_ready = not secondary_active
		&"springjack":
			cost = 0.09
			primary_ready = supported and not secondary_active
		&"gyrocrate":
			cost = 0.10 * RIG_MAX_TIMESTEP
			continuous = true
			secondary_ready = energy >= 0.14 and grounded and absf(angular_velocity) > 0.8 and cooldown_remaining <= 0.0
		&"bellows":
			cost = 0.11
			primary_ready = not secondary_active
		&"magpie":
			cost = 0.22
			primary_ready = charge >= 0.15
			secondary_ready = energy >= 0.10 * RIG_MAX_TIMESTEP and not _adhesion_exhausted
		&"skatesail":
			cost = 0.06
			primary_ready = grounded
		&"astra":
			cost = 0.20
			primary_ready = not secondary_active
			secondary_ready = energy >= 0.28 * RIG_MAX_TIMESTEP
		&"luna":
			cost = 0.075
			primary_ready = not secondary_active
			secondary_ready = energy >= 0.17 * RIG_MAX_TIMESTEP
		&"qwen":
			continuous = _flight_mode
			cost = 0.32 * RIG_MAX_TIMESTEP if _flight_mode else 0.12
			primary_ready = _flight_mode or supported
		&"jev":
			cost = 0.18
			secondary_ready = energy > 0.02
		&"gemini":
			cost = 0.136 * RIG_MAX_TIMESTEP
			continuous = true
			secondary_ready = energy >= cost
	primary_ready = primary_ready and energy + 0.000001 >= cost and (continuous or cooldown_remaining <= 0.0)


func capabilities() -> Dictionary:
	var adhesion_drain: float = 0.0
	match model_id:
		&"scrabbler": adhesion_drain = 0.12
		&"dropbot": adhesion_drain = 0.17
		&"walljumper": adhesion_drain = 1.15
		&"clamberer": adhesion_drain = CLAMBERER_ADHESION_DRAIN
		&"claude": adhesion_drain = 0.065
		&"bonsai": adhesion_drain = 0.035
		&"magpie": adhesion_drain = 0.10
	return {
		"version": RIG_VERSION,
		"model_id": str(model_id),
		"rig_id": str(model_id),
		"set_id": str(Catalog.set_for(model_id)),
		"representation": "sampled-rig",
		"provisional": true,
		"body_size": [body_size.x, body_size.y],
		"authored_body_size": [_base_body_size.x, _base_body_size.y],
		"collision_proxy": "conservative-rotated-aabb",
		"runtime_enclosure_recovery": false,
		"maximum_speed": RIG_MAX_SPEED,
		"maximum_timestep": RIG_MAX_TIMESTEP,
		"maximum_axis_travel": RIG_MAX_TRAVEL,
		"maximum_collision_queries": RIG_MAX_QUERIES,
		"maximum_ray_queries": RIG_MAX_RAY_QUERIES,
		"maximum_effect_reads": RigEffects.MAX_READS,
		"maximum_effect_writes": RigEffects.MAX_WRITES,
		"maximum_effect_radius": RigEffects.MAX_RADIUS,
		"maximum_angular_speed": RIG_MAX_ANGULAR_SPEED,
		"maximum_rotation_placements": RIG_ANGULAR_STEPS,
		"maximum_rope_length": RIG_RAY_RANGE,
		"rocket_surface_reach": ROCKET_SURFACE_REACH if model_id == &"rocketjumper" else 0.0,
		"adhesion_energy_per_second": adhesion_drain,
		"readiness_semantics": "resource-and-local-state; target-geometry-checked-on-action",
		"charge_semantics": "cancelable-action-reserve; starts-zero; energy-is-separate",
		"observation_version": 1,
		"observation_size": OBSERVATION_SIZE,
		"rig_observation_version": 2,
		"rig_observation_size": RIG_OBSERVATION_SIZE,
		"effect_semantics": "bounded-gameplay-excavation-and-authored-recoil",
		"granular_response": "rem003-c1-baseline-impact-request",
		"rigid_body_force_feedback": false,
		"actuator_control_supported": Actuation.supports_model(model_id),
		"actuation_version": ACTUATION_VERSION,
		"actuation_observation_size": ACTUATION_OBSERVATION_SIZE,
		"actuation_profile": Actuation.profile(model_id),
	}


func actuation_observation() -> PackedFloat32Array:
	return actuation.observation()


func observation() -> PackedFloat32Array:
	return PackedFloat32Array([
		position.x, position.y, velocity.x, velocity.y,
		float(grounded), float(runtime_enclosed), energy,
		float(primary_ready), float(secondary_ready), cooldown_remaining,
		float(primary_active), float(secondary_active), facing_x, float(_rig_index),
		float(query_count_last), float(movement_limited),
	])


func rig_observation() -> PackedFloat32Array:
	return PackedFloat32Array([
		position.x, position.y, velocity.x, velocity.y,
		float(grounded), float(runtime_enclosed), energy,
		float(primary_ready), float(secondary_ready), cooldown_remaining,
		float(primary_active), float(secondary_active), facing_x, float(_rig_index),
		float(query_count_last), float(movement_limited),
		rotation, angular_velocity, contact_normal.x, contact_normal.y,
		float(attachment_mode), anchor.x, anchor.y, rope_length, tension, charge,
		float(auxiliary_active), float(locomotion_mode), float(air_jumps_remaining),
		float(ray_queries_last), float(edited_cells_last), float(effect_kind),
		effect_origin.x, effect_origin.y, effect_strength, body_size.x, body_size.y,
		effect_radius, float(effect_reads_last), gait_phase,
	])
