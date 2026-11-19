class_name CyberSampledCharacter
extends RefCounted

# This is deliberately an ordinary entity rather than a cluster of cells. It
# samples the cellular occupancy field and can later be replaced by a Godot
# CharacterBody2D or native rigid body without changing the cell representation.
# These constants remain the exact pre-PENV baseline and are used whenever no
# explicit player/environment profile has been applied.
const BODY_SIZE: Vector2 = Vector2(8.0, 14.0)
const WALK_SPEED: float = 42.0
const GROUND_ACCELERATION: float = 230.0
const AIR_ACCELERATION: float = 95.0
const GROUND_DECELERATION: float = 280.0
const GRAVITY: float = 92.0
const MAX_FALL_SPEED: float = 86.0
const JETPACK_ACCELERATION: float = 180.0
const JETPACK_MAX_RISE_SPEED: float = 60.0

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var grounded: bool = false
var recovery_blocked: bool = false
var granular_disturbance_last: int = 0
var granular_disturbance_total: int = 0

# PCHAR-001 separates invalid-spawn repair from runtime enclosure response. The
# historical sampled-player baseline keeps runtime recovery enabled; the
# burial-safe experiment can disable it without changing the bounded spawn path.
var runtime_enclosure_recovery_enabled: bool = true
var runtime_enclosed: bool = false
var runtime_recovery_attempts: int = 0
var runtime_recovery_successes: int = 0
var runtime_recovery_upward_cells: int = 0
var invalid_spawn_recovery_attempts: int = 0
var invalid_spawn_recovery_successes: int = 0
var last_recovery_kind: String = ""
var last_recovery_offset: Vector2 = Vector2.ZERO

# PENV-001 runtime tuning values. Defaults reproduce the old constants and the
# historical one-pixel traversal envelope exactly.
var effective_mass: float = 1.0
var gravity_acceleration: float = GRAVITY
var terminal_fall_speed: float = MAX_FALL_SPEED
var jetpack_acceleration: float = JETPACK_ACCELERATION
var jetpack_max_rise_speed: float = JETPACK_MAX_RISE_SPEED
var granular_response_sensitivity: float = 1.0
var liquid_response_sensitivity: float = 1.0
var step_height: int = 1
var knee_height: int = 1
var clamber_height: int = 1
var knee_slowdown: float = 0.65
var clamber_slowdown: float = 0.35

# PENV-002 traversal diagnostics. These describe the most recent horizontal
# collision/traversal attempt and are deliberately separate from physics tuning
# inputs so tests/debug UI can tell which band actually fired.
var last_traversal_band: String = "none"
var last_traversal_ledge_height: int = 0
var last_traversal_clearance_height: int = 0
var last_traversal_horizontal_progress: float = 0.0

var _profile_identity: Dictionary = {
	"version": 1,
	"id": "current-baseline",
	"label": "Current baseline",
	"effective_mass": 1.0,
	"gravity_acceleration": GRAVITY,
	"terminal_fall_speed": MAX_FALL_SPEED,
	"jetpack_acceleration": JETPACK_ACCELERATION,
	"jetpack_max_rise_speed": JETPACK_MAX_RISE_SPEED,
	"granular_response_sensitivity": 1.0,
	"granular_response_identity": "rem003-c1-impact-speed-scale-v1",
	"liquid_response_sensitivity": 1.0,
	"liquid_response_identity": "player-side-only/no-water-semantic-hook",
	"step_height": 1,
	"knee_height": 1,
	"clamber_height": 1,
	"knee_slowdown": 0.65,
	"clamber_slowdown": 0.35,
}

const RECOVERY_RADIUS: int = 32
const TRAVERSAL_PROBE_INSET: float = 0.01
const TRAVERSAL_PROBE_SIZE: float = 0.98
const RECOVERY_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.DOWN,
]


func configure_runtime_enclosure_recovery(enabled: bool) -> void:
	runtime_enclosure_recovery_enabled = enabled


func configure_profile(profile: Dictionary) -> void:
	effective_mass = float(profile.get("effective_mass", 1.0))
	gravity_acceleration = float(profile.get("gravity_acceleration", GRAVITY))
	terminal_fall_speed = float(profile.get("terminal_fall_speed", MAX_FALL_SPEED))
	jetpack_acceleration = float(profile.get("jetpack_acceleration", JETPACK_ACCELERATION))
	jetpack_max_rise_speed = float(profile.get("jetpack_max_rise_speed", JETPACK_MAX_RISE_SPEED))
	granular_response_sensitivity = float(profile.get("granular_response_sensitivity", 1.0))
	liquid_response_sensitivity = float(profile.get("liquid_response_sensitivity", 1.0))
	step_height = int(profile.get("step_height", 1))
	knee_height = int(profile.get("knee_height", step_height))
	clamber_height = int(profile.get("clamber_height", knee_height))
	knee_slowdown = float(profile.get("knee_slowdown", 0.65))
	clamber_slowdown = float(profile.get("clamber_slowdown", 0.35))
	_profile_identity = profile.duplicate(true)


func active_profile() -> Dictionary:
	return _profile_identity.duplicate(true)


func reset(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	grounded = false
	recovery_blocked = false
	granular_disturbance_last = 0
	granular_disturbance_total = 0
	runtime_enclosed = false
	runtime_recovery_attempts = 0
	runtime_recovery_successes = 0
	runtime_recovery_upward_cells = 0
	invalid_spawn_recovery_attempts = 0
	invalid_spawn_recovery_successes = 0
	last_recovery_kind = ""
	last_recovery_offset = Vector2.ZERO
	_clear_traversal_observation()


func simulate(delta: float, horizontal_input: float, jetpack_active: bool, world) -> void:
	# At most nine one-cell movement steps per axis at the configured speeds.
	granular_disturbance_last = 0
	delta = clampf(delta, 0.0, 0.1)
	if not resolve_runtime_enclosure(world):
		return
	var target_speed: float = clampf(horizontal_input, -1.0, 1.0) * WALK_SPEED
	var acceleration: float = GROUND_ACCELERATION if grounded else AIR_ACCELERATION
	if absf(horizontal_input) < 0.001 and grounded:
		acceleration = GROUND_DECELERATION
	velocity.x = approach_float(velocity.x, target_speed, acceleration * delta)

	if jetpack_active:
		velocity.y = maxf(-jetpack_max_rise_speed, velocity.y - jetpack_acceleration * delta)
		grounded = false
	else:
		velocity.y = minf(terminal_fall_speed, velocity.y + gravity_acceleration * delta)
	move_horizontal(velocity.x * delta, world)
	move_vertical(velocity.y * delta, world)

	if not grounded:
		grounded = world.character_box_collides(
			position + Vector2(0.0, 0.5),
			BODY_SIZE,
			1
		)


func resolve_runtime_enclosure(world) -> bool:
	runtime_enclosed = world.box_collides(position, BODY_SIZE)
	if not runtime_enclosed:
		recovery_blocked = false
		return true
	if not runtime_enclosure_recovery_enabled:
		# Burial-safe PCHAR mode has no runtime vertical or lateral reordering.
		# The actor can remain buried/immobilized until the material state changes
		# or an explicit future escape action is invoked.
		velocity = Vector2.ZERO
		grounded = false
		recovery_blocked = true
		return false
	return _recover_enclosure(world, "runtime")


func recover_invalid_spawn(world) -> bool:
	# Explicit reset/spawn repair remains available even when runtime recovery is
	# disabled. This is never called from ordinary movement.
	return _recover_enclosure(world, "invalid-spawn")


func recover_enclosure(world) -> bool:
	# Compatibility entry point retains the historical runtime meaning.
	return _recover_enclosure(world, "runtime")


func _recover_enclosure(world, kind: String) -> bool:
	recovery_blocked = false
	if not world.box_collides(position, BODY_SIZE):
		runtime_enclosed = false
		return true

	if kind == "runtime":
		runtime_recovery_attempts += 1
	else:
		invalid_spawn_recovery_attempts += 1

	var origin: Vector2 = position
	# Bounded axis search, upward first at equal distance. No cell deletion and
	# no material/body authority transfer: only this sampled character moves.
	for distance: int in range(1, RECOVERY_RADIUS + 1):
		for direction: Vector2 in RECOVERY_DIRECTIONS:
			var candidate: Vector2 = origin + direction * float(distance)
			if not world.box_collides(candidate, BODY_SIZE):
				position = candidate
				velocity = Vector2.ZERO
				grounded = false
				runtime_enclosed = false
				last_recovery_kind = kind
				last_recovery_offset = candidate - origin
				if kind == "runtime":
					runtime_recovery_successes += 1
					if candidate.y < origin.y:
						runtime_recovery_upward_cells += roundi(
							origin.y - candidate.y
						)
				else:
					invalid_spawn_recovery_successes += 1
				return true

	velocity = Vector2.ZERO
	grounded = false
	recovery_blocked = true
	runtime_enclosed = true
	last_recovery_kind = kind
	last_recovery_offset = Vector2.ZERO
	return false


func move_horizontal(distance: float, world) -> void:
	_clear_traversal_observation()
	var remaining: float = distance
	while absf(remaining) > 0.0001:
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(movement, 0.0)
		if world.character_box_collides(candidate, BODY_SIZE, 2):
			if grounded:
				var traversal_progress: float = _try_traverse_horizontal(movement, world)
				if absf(traversal_progress) > 0.0001:
					# Step consumes the full intended movement. Knee/clamber are
					# intentionally slower and therefore consume only this tick's
					# admitted band progress.
					if absf(traversal_progress) + 0.0001 < absf(movement):
						return
					remaining -= traversal_progress
					continue
			if last_traversal_band == "none":
				last_traversal_band = "blocked"
			velocity.x = 0.0
			return
		position = candidate
		remaining -= movement


func _clear_traversal_observation() -> void:
	last_traversal_band = "none"
	last_traversal_ledge_height = 0
	last_traversal_clearance_height = 0
	last_traversal_horizontal_progress = 0.0


func _leading_ledge_height(movement: float, world) -> int:
	if clamber_height <= 0 or absf(movement) <= 0.0001:
		return 0

	# Classify the terrain at the *leading foot cell* after the requested
	# horizontal move. This is intentionally not the old whole-body clearance
	# search: an 8px-wide actor on a smooth 1px staircase can need several pixels
	# of total box clearance while the local ledge is still only one pixel high.
	var candidate_x: float = position.x + movement
	var probe_x: float = (
		candidate_x + TRAVERSAL_PROBE_INSET
		if movement < 0.0
		else (
			candidate_x
			+ BODY_SIZE.x
			- 1.0
			+ TRAVERSAL_PROBE_INSET
		)
	)
	var foot_y: float = position.y + BODY_SIZE.y
	var ledge_height: int = 0
	# One extra row distinguishes "at clamber limit" from "above clamber".
	for rise: int in range(1, clamber_height + 2):
		var probe_origin := Vector2(
			probe_x,
			foot_y - float(rise) + TRAVERSAL_PROBE_INSET
		)
		if not world.character_box_collides(
			probe_origin,
			Vector2(TRAVERSAL_PROBE_SIZE, TRAVERSAL_PROBE_SIZE),
			2
		):
			break
		ledge_height = rise
	return ledge_height


func _required_vertical_clearance(horizontal_progress: float, world) -> int:
	for clearance: int in range(1, clamber_height + 1):
		var candidate: Vector2 = position + Vector2(
			horizontal_progress,
			-float(clearance)
		)
		if world.box_collides(candidate, BODY_SIZE):
			continue
		if not world.character_box_collides(
			candidate + Vector2(0.0, 0.5),
			BODY_SIZE,
			1
		):
			continue
		return clearance
	return 0


func _try_traverse_horizontal(movement: float, world) -> float:
	if clamber_height <= 0:
		last_traversal_band = "blocked"
		return 0.0

	var ledge_height: int = _leading_ledge_height(movement, world)
	last_traversal_ledge_height = ledge_height
	if ledge_height <= 0 or ledge_height > clamber_height:
		last_traversal_band = "blocked"
		return 0.0

	var speed_factor: float = 1.0
	if ledge_height <= step_height:
		last_traversal_band = "step"
	elif ledge_height <= knee_height:
		last_traversal_band = "knee"
		speed_factor = knee_slowdown
	else:
		last_traversal_band = "clamber"
		speed_factor = clamber_slowdown

	var horizontal_progress: float = movement * speed_factor
	if absf(horizontal_progress) <= 0.0001:
		last_traversal_band = "blocked"
		return 0.0

	# A slowdown can leave the actor short of the actual edge this tick. In that
	# case move only horizontally and wait for a later tick to climb; do not
	# teleport upward before collision clearance is actually required.
	var flat_candidate: Vector2 = position + Vector2(horizontal_progress, 0.0)
	if not world.character_box_collides(flat_candidate, BODY_SIZE, 2):
		position = flat_candidate
		last_traversal_horizontal_progress = horizontal_progress
		return horizontal_progress

	var clearance_height: int = _required_vertical_clearance(
		horizontal_progress,
		world
	)
	last_traversal_clearance_height = clearance_height
	if clearance_height <= 0:
		last_traversal_band = "blocked"
		last_traversal_horizontal_progress = 0.0
		return 0.0

	var candidate: Vector2 = position + Vector2(
		horizontal_progress,
		-float(clearance_height)
	)
	position = candidate
	last_traversal_horizontal_progress = horizontal_progress
	return horizontal_progress


func move_vertical(distance: float, world) -> void:
	var remaining: float = distance
	grounded = false
	while absf(remaining) > 0.0001:
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(0.0, movement)
		if world.character_box_collides(
			candidate,
			BODY_SIZE,
			1 if movement > 0 else 3
		):
			if movement > 0.0:
				if world.has_method(&"character_disturb_granular"):
					# REM-003 C1 still owns the bounded relocation hook. PENV-001
					# scales only the player-side request, leaving packing and cell
					# ownership semantics unchanged.
					var response_impact_speed: float = (
						velocity.y * effective_mass * granular_response_sensitivity
					)
					granular_disturbance_last = int(
						world.character_disturb_granular(
							candidate,
							BODY_SIZE,
							response_impact_speed
						)
					)
					granular_disturbance_total += granular_disturbance_last
				grounded = true
			velocity.y = 0.0
			return
		position = candidate
		remaining -= movement


func centre() -> Vector2:
	return position + BODY_SIZE * 0.5


func approach_float(value: float, target: float, amount: float) -> float:
	if value < target:
		return minf(value + amount, target)
	return maxf(value - amount, target)
