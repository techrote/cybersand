class_name CyberActorPrototype
extends CyberSampledCharacter

# ACT-001: provisional sampled movers. Input origin is deliberately absent:
# keyboard, scripted policy and NN adapters submit the same values. This object
# and its World must have one serialized owner. It never polls Input or infers.
const RUNNER: StringName = &"runner"
const SKIMMER: StringName = &"skimmer"
const CRAWLER: StringName = &"crawler"
const MODEL_VERSION: int = 1
const OBSERVATION_VERSION: int = 1
const OBSERVATION_SIZE: int = 16

const MAX_TIMESTEP: float = 1.0 / 30.0
const MAX_SPEED: float = 120.0
const MAX_DISPLACEMENT: float = 4.0
const MAX_SWEEP_STEPS: int = 4
const MAX_COLLISION_QUERIES: int = 32
const PROTOTYPE_GRAVITY: float = 140.0
const MOTION_EPSILON: float = 0.000001

const RUNNER_SPEED: float = 60.0
const RUNNER_GROUND_ACCELERATION: float = 900.0
const RUNNER_AIR_ACCELERATION: float = 360.0
const RUNNER_BRAKE: float = 1100.0
const RUNNER_AIR_BRAKE: float = 180.0
const RUNNER_JUMP_SPEED: float = 78.0
const RUNNER_RELEASE_RISE_SPEED: float = 32.0
const RUNNER_COYOTE_SECONDS: float = 0.10
const RUNNER_BUFFER_SECONDS: float = 0.12
const RUNNER_DASH_SPEED: float = 120.0
const RUNNER_DASH_SECONDS: float = 0.10
const RUNNER_DASH_COOLDOWN: float = 0.65

const SKIMMER_SPEED: float = 54.0
const SKIMMER_BOOST_SPEED: float = 90.0
const SKIMMER_ACCELERATION: float = 360.0
const SKIMMER_BRAKE: float = 720.0
const SKIMMER_FLIGHT_DRAIN: float = 0.10
const SKIMMER_BOOST_DRAIN: float = 0.65
const SKIMMER_GROUND_RECHARGE: float = 0.45
const SKIMMER_COAST_RECHARGE: float = 0.20
const SKIMMER_RESTART_ENERGY: float = 0.15

const CRAWLER_SPEED: float = 32.0
const CRAWLER_ACCELERATION: float = 720.0
const CRAWLER_BRAKE: float = 1200.0
const CRAWLER_JUMP_SPEED: float = 48.0
const CRAWLER_LEDGE_HEIGHT: int = 4

var model_id: StringName = RUNNER
var energy: float = 1.0
var cooldown_remaining: float = 0.0
var primary_ready: bool = false
var secondary_ready: bool = true
var primary_active: bool = false
var secondary_active: bool = false
var query_count_last: int = 0
var movement_limited: bool = false
var facing_x: float = 1.0

var _primary_held: bool = false
var _secondary_held: bool = false
var _jump_buffer_remaining: float = 0.0
var _coyote_remaining: float = 0.0
var _dash_remaining: float = 0.0
var _dash_direction: float = 1.0
var _jump_active: bool = false
var _flight_exhausted: bool = false
var _ledge_attempted: bool = false


func _init() -> void:
	runtime_enclosure_recovery_enabled = false


func configure_model(candidate: StringName) -> bool:
	if candidate != RUNNER and candidate != SKIMMER and candidate != CRAWLER:
		return false
	model_id = candidate
	# Model selection is a setup boundary. The session owner supplies a fresh
	# reset, not a conversion of a live sampled/Rapier representation.
	_reset_model_state()
	return true


func reset(spawn_position: Vector2) -> void:
	# A malformed external spawn must never reach an occupancy query as NaN.
	super.reset(spawn_position if spawn_position.is_finite() else Vector2.ZERO)
	_reset_model_state()


func _reset_model_state() -> void:
	runtime_enclosure_recovery_enabled = false
	energy = 1.0
	cooldown_remaining = 0.0
	_coyote_remaining = 0.0
	_flight_exhausted = false
	facing_x = 1.0
	_dash_direction = 1.0
	query_count_last = 0
	movement_limited = false
	_ledge_attempted = false
	clear_actions()
	_update_readiness()


func clear_actions() -> void:
	# Cancel an input lifetime without changing physical state or refunding an
	# energy/cooldown cost. In particular pausing cannot recharge a dash.
	_primary_held = false
	_secondary_held = false
	_jump_buffer_remaining = 0.0
	_dash_remaining = 0.0
	_jump_active = false
	primary_active = false
	secondary_active = false
	_update_readiness()


func simulate_action(
	delta: float,
	movement: Vector2,
	primary: bool,
	secondary: bool,
	world,
	primary_pressed: bool = false,
	secondary_pressed: bool = false
) -> void:
	query_count_last = 0
	movement_limited = false
	granular_disturbance_last = 0
	primary_active = false
	secondary_active = false
	_ledge_attempted = false
	runtime_enclosure_recovery_enabled = false
	if not velocity.is_finite():
		velocity = Vector2.ZERO
		movement_limited = true
	if not is_finite(delta) or delta <= 0.0:
		movement_limited = movement_limited or not is_finite(delta) or delta < 0.0
		return
	if delta > MAX_TIMESTEP:
		movement_limited = true
	delta = minf(delta, MAX_TIMESTEP)
	if not movement.is_finite():
		movement = Vector2.ZERO
		movement_limited = true
	else:
		movement = Vector2(clampf(movement.x, -1.0, 1.0), clampf(movement.y, -1.0, 1.0))
		if model_id == SKIMMER:
			movement = movement.limit_length(1.0)
		else:
			# Ground movers ignore the flight axis, including diagonal scaling.
			movement.y = 0.0
	var primary_edge: bool = primary_pressed or (primary and not _primary_held)
	var secondary_edge: bool = secondary_pressed or (secondary and not _secondary_held)
	_primary_held = primary
	_secondary_held = secondary
	if absf(movement.x) > MOTION_EPSILON:
		facing_x = signf(movement.x)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	if _dash_remaining <= MOTION_EPSILON:
		_dash_remaining = 0.0
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	if world == null or not position.is_finite():
		velocity = Vector2.ZERO
		runtime_enclosed = true
		recovery_blocked = true
		grounded = false
		clear_actions()
		return
	# One volume query, no inherited upward-first search. Material that closes
	# around an actor remains authoritative; reset recovery is explicitly separate.
	runtime_enclosed = _query_volume(world, position)
	recovery_blocked = runtime_enclosed
	if runtime_enclosed:
		velocity = Vector2.ZERO
		grounded = false
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_dash_remaining = 0.0
		_jump_active = false
		_update_readiness()
		return
	_bound_velocity()
	grounded = velocity.y >= 0.0 and _query_direction(world, position + Vector2(0.0, 0.5), 1)
	if grounded:
		_coyote_remaining = RUNNER_COYOTE_SECONDS if model_id == RUNNER else 0.0
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	match model_id:
		RUNNER:
			_advance_runner(delta, movement.x, primary, primary_edge, secondary_edge)
		SKIMMER:
			_advance_skimmer(delta, movement, primary, secondary)
		CRAWLER:
			_advance_crawler(delta, movement.x, primary_edge, secondary)
	_bound_velocity()
	move_horizontal(velocity.x * delta, world)
	move_vertical(velocity.y * delta, world)
	# A rising actor never gains support merely because the 0.5-cell foot probe
	# can still see its launch surface. It cannot jump/clamber repeatedly in air.
	if velocity.y < 0.0:
		grounded = false
	elif not grounded:
		grounded = _query_direction(world, position + Vector2(0.0, 0.5), 1)
	if model_id == RUNNER and grounded:
		_coyote_remaining = RUNNER_COYOTE_SECONDS
		if _jump_buffer_remaining > 0.0:
			_start_runner_jump(primary)
	if grounded or velocity.y >= 0.0:
		_jump_active = false
	if model_id != SKIMMER:
		primary_active = _jump_active
	# A buffered landing jump can be admitted after the movement sweep while a
	# horizontal dash is still active. Its combined velocity has the same cap.
	_bound_velocity()
	_update_readiness()


func _advance_runner(
	delta: float,
	horizontal: float,
	primary: bool,
	primary_edge: bool,
	secondary_edge: bool
) -> void:
	if primary_edge:
		_jump_buffer_remaining = RUNNER_BUFFER_SECONDS
	if secondary_edge and cooldown_remaining <= MOTION_EPSILON:
		_dash_direction = signf(horizontal) if absf(horizontal) > MOTION_EPSILON else facing_x
		_dash_remaining = RUNNER_DASH_SECONDS
		cooldown_remaining = RUNNER_DASH_COOLDOWN
	if _dash_remaining > 0.0:
		velocity.x = _dash_direction * RUNNER_DASH_SPEED
		secondary_active = true
	else:
		var acceleration: float = RUNNER_GROUND_ACCELERATION if grounded else RUNNER_AIR_ACCELERATION
		if absf(horizontal) <= MOTION_EPSILON:
			acceleration = RUNNER_BRAKE if grounded else RUNNER_AIR_BRAKE
		velocity.x = move_toward(velocity.x, horizontal * RUNNER_SPEED, acceleration * delta)
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		_start_runner_jump(primary)
	if _jump_active and not primary and velocity.y < -RUNNER_RELEASE_RISE_SPEED:
		velocity.y = -RUNNER_RELEASE_RISE_SPEED
	velocity.y = minf(MAX_SPEED, velocity.y + PROTOTYPE_GRAVITY * delta)


func _start_runner_jump(primary: bool) -> void:
	velocity.y = -RUNNER_JUMP_SPEED if primary else -RUNNER_RELEASE_RISE_SPEED
	grounded = false
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_jump_active = true
	primary_active = true


func _advance_skimmer(delta: float, movement: Vector2, primary: bool, secondary: bool) -> void:
	energy = clampf(energy, 0.0, 1.0) if is_finite(energy) else 0.0
	if energy <= 0.0:
		_flight_exhausted = true
	var resting: bool = grounded and movement.length_squared() <= MOTION_EPSILON and not primary
	if secondary or resting or _flight_exhausted:
		var recharge: float = SKIMMER_GROUND_RECHARGE if grounded else SKIMMER_COAST_RECHARGE
		energy = minf(1.0, energy + recharge * delta)
		if _flight_exhausted and energy >= SKIMMER_RESTART_ENERGY:
			_flight_exhausted = false
		if secondary or resting or _flight_exhausted:
			# Brake is explicit unpowered drag. Ordinary exhaustion only damps
			# horizontal motion: it must not silently cancel falling gravity.
			if secondary:
				velocity = velocity.move_toward(Vector2.ZERO, SKIMMER_BRAKE * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, SKIMMER_ACCELERATION * delta)
			velocity.y = minf(MAX_SPEED, velocity.y + PROTOTYPE_GRAVITY * delta)
			secondary_active = secondary
			return
	var drain: float = SKIMMER_FLIGHT_DRAIN + (SKIMMER_BOOST_DRAIN if primary else 0.0)
	energy = maxf(0.0, energy - drain * delta)
	if energy <= 0.0:
		_flight_exhausted = true
		velocity.y = minf(MAX_SPEED, velocity.y + PROTOTYPE_GRAVITY * delta)
		return
	var speed: float = SKIMMER_BOOST_SPEED if primary else SKIMMER_SPEED
	velocity = velocity.move_toward(movement * speed, SKIMMER_ACCELERATION * delta)
	primary_active = primary
	grounded = grounded and velocity.y >= 0.0


func _advance_crawler(delta: float, horizontal: float, primary_edge: bool, secondary: bool) -> void:
	# Brace deliberately wins over hop. No jump buffer survives bracing, and
	# strong horizontal traction does not claim a mass, Rapier force or push.
	_jump_buffer_remaining = 0.0
	if secondary:
		velocity.x = 0.0
		secondary_active = true
		_jump_active = false
	else:
		var acceleration: float = CRAWLER_BRAKE if absf(horizontal) <= MOTION_EPSILON else CRAWLER_ACCELERATION
		velocity.x = move_toward(velocity.x, horizontal * CRAWLER_SPEED, acceleration * delta)
		if primary_edge and grounded:
			velocity.y = -CRAWLER_JUMP_SPEED
			grounded = false
			_jump_active = true
	velocity.y = minf(MAX_SPEED, velocity.y + PROTOTYPE_GRAVITY * delta)


func move_horizontal(distance: float, world) -> void:
	if not is_finite(distance):
		movement_limited = true
		velocity.x = 0.0
		return
	if absf(distance) > MAX_DISPLACEMENT:
		movement_limited = true
	var remaining: float = clampf(distance, -MAX_DISPLACEMENT, MAX_DISPLACEMENT)
	for _step: int in range(MAX_SWEEP_STEPS):
		if absf(remaining) <= MOTION_EPSILON:
			return
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(movement, 0.0)
		if _query_direction(world, candidate, 2):
			if grounded and velocity.y >= 0.0 and not _ledge_attempted and model_id != SKIMMER:
				if _try_safe_ledge(movement, world):
					remaining -= movement
					continue
			velocity.x = 0.0
			_dash_remaining = 0.0
			secondary_active = secondary_active and model_id != RUNNER
			return
		position = candidate
		remaining -= movement


func _try_safe_ledge(horizontal: float, world) -> bool:
	_ledge_attempted = true
	var limit: int = CRAWLER_LEDGE_HEIGHT if model_id == CRAWLER else 1
	for height: int in range(1, limit + 1):
		var raised: Vector2 = position + Vector2(0.0, -float(height))
		# Every intermediate vertical placement must be clear. Searching a taller
		# endpoint after hitting a ceiling would tunnel through that ceiling.
		if _query_volume(world, raised):
			return false
		var candidate: Vector2 = raised + Vector2(horizontal, 0.0)
		if _query_volume(world, candidate):
			continue
		if not _query_direction(world, candidate + Vector2(0.0, 0.5), 1):
			continue
		position = candidate
		return true
	return false


func move_vertical(distance: float, world) -> void:
	grounded = false
	if not is_finite(distance):
		movement_limited = true
		velocity.y = 0.0
		return
	if absf(distance) > MAX_DISPLACEMENT:
		movement_limited = true
	var remaining: float = clampf(distance, -MAX_DISPLACEMENT, MAX_DISPLACEMENT)
	for _step: int in range(MAX_SWEEP_STEPS):
		if absf(remaining) <= MOTION_EPSILON:
			return
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(0.0, movement)
		if _query_direction(world, candidate, 1 if movement > 0.0 else 3):
			if movement > 0.0:
				grounded = true
				if world.has_method(&"character_disturb_granular"):
					# Baseline mass/sensitivity request only. The existing REM-003
					# owner still decides whether up to two grains can move.
					granular_disturbance_last = int(world.character_disturb_granular(candidate, BODY_SIZE, velocity.y))
					granular_disturbance_total += granular_disturbance_last
			velocity.y = 0.0
			return
		position = candidate
		remaining -= movement


func _bound_velocity() -> void:
	var bounded: Vector2 = Vector2(clampf(velocity.x, -MAX_SPEED, MAX_SPEED), clampf(velocity.y, -MAX_SPEED, MAX_SPEED)).limit_length(MAX_SPEED)
	if bounded != velocity:
		movement_limited = true
		velocity = bounded


func _query_volume(world, origin: Vector2) -> bool:
	if query_count_last >= MAX_COLLISION_QUERIES:
		movement_limited = true
		return true
	query_count_last += 1
	return world.box_collides(origin, BODY_SIZE)


func _query_direction(world, origin: Vector2, mode: int) -> bool:
	if query_count_last >= MAX_COLLISION_QUERIES:
		movement_limited = true
		return true
	query_count_last += 1
	return world.character_box_collides(origin, BODY_SIZE, mode)


func _update_readiness() -> void:
	if runtime_enclosed or recovery_blocked:
		primary_ready = false
		secondary_ready = false
		return
	match model_id:
		RUNNER:
			primary_ready = grounded or _coyote_remaining > 0.0
			secondary_ready = cooldown_remaining <= MOTION_EPSILON and _dash_remaining <= 0.0
		SKIMMER:
			primary_ready = energy > 0.0 and not _flight_exhausted and not secondary_active
			secondary_ready = true
		CRAWLER:
			primary_ready = grounded and not secondary_active
			secondary_ready = true


func capabilities() -> Dictionary:
	# Allocated only on inspection/publication, never by simulate_action().
	return {
		"version": MODEL_VERSION,
		"model_id": str(model_id),
		"representation": "sampled",
		"provisional": true,
		"body_size": [BODY_SIZE.x, BODY_SIZE.y],
		"movement_axes": 2 if model_id == SKIMMER else 1,
		"primary": "boost" if model_id == SKIMMER else ("hop" if model_id == CRAWLER else "jump"),
		"secondary": "air-brake" if model_id == SKIMMER else ("brace" if model_id == CRAWLER else "dash"),
		"walk_or_cruise_speed": SKIMMER_SPEED if model_id == SKIMMER else (CRAWLER_SPEED if model_id == CRAWLER else RUNNER_SPEED),
		"jump_speed": 0.0 if model_id == SKIMMER else (CRAWLER_JUMP_SPEED if model_id == CRAWLER else RUNNER_JUMP_SPEED),
		"safe_ledge_height": CRAWLER_LEDGE_HEIGHT if model_id == CRAWLER else (1 if model_id == RUNNER else 0),
		"runtime_enclosure_recovery": false,
		"gravity": PROTOTYPE_GRAVITY,
		"maximum_speed": MAX_SPEED,
		"maximum_timestep": MAX_TIMESTEP,
		"maximum_axis_sweep": MAX_DISPLACEMENT,
		"maximum_collision_queries": MAX_COLLISION_QUERIES,
		"observation_version": OBSERVATION_VERSION,
		"observation_size": OBSERVATION_SIZE,
		"granular_response": "rem003-c1-baseline-impact-request",
		"liquid_response": "no-liquid-response-hook",
	}


func observation() -> PackedFloat32Array:
	# v1: x,y,vx,vy,grounded,enclosed,energy,primary-ready,secondary-ready,
	# cooldown-seconds,primary-active,secondary-active,facing,model,queries,limited.
	# The session appends actor/generation/tick identity outside this fixed vector.
	var index: int = 1 if model_id == SKIMMER else (2 if model_id == CRAWLER else 0)
	return PackedFloat32Array([
		position.x, position.y, velocity.x, velocity.y,
		float(grounded), float(runtime_enclosed), energy,
		float(primary_ready), float(secondary_ready), cooldown_remaining,
		float(primary_active), float(secondary_active), facing_x, float(index),
		float(query_count_last), float(movement_limited),
	])
