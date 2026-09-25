class_name CyberSampledCharacter
extends RefCounted

# This is deliberately an ordinary entity rather than a cluster of cells. It
# samples the cellular occupancy field and can later be replaced by a Godot
# CharacterBody2D or native rigid body without changing the cell representation.
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

const RECOVERY_RADIUS: int = 32
const RECOVERY_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.DOWN,
]


func configure_runtime_enclosure_recovery(enabled: bool) -> void:
	runtime_enclosure_recovery_enabled = enabled


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
		velocity.y = maxf(-JETPACK_MAX_RISE_SPEED, velocity.y - JETPACK_ACCELERATION * delta)
		grounded = false
	else:
		velocity.y = minf(MAX_FALL_SPEED, velocity.y + GRAVITY * delta)
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
	var remaining: float = distance
	while absf(remaining) > 0.0001:
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(movement, 0.0)
		if world.character_box_collides(candidate, BODY_SIZE, 2):
			var step: Vector2 = candidate + Vector2.UP
			if (
				grounded
				and not world.box_collides(step, BODY_SIZE)
				and world.character_box_collides(
					step + Vector2(0, 0.5),
					BODY_SIZE,
					1
				)
			):
				position = step
				remaining -= movement
				continue
			velocity.x = 0.0
			return
		position = candidate
		remaining -= movement


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
					granular_disturbance_last = int(
						world.character_disturb_granular(
							candidate,
							BODY_SIZE,
							velocity.y
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
