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
const RECOVERY_RADIUS: int = 32
const RECOVERY_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]


func reset(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	grounded = false
	recovery_blocked = false


func simulate(delta: float, horizontal_input: float, jetpack_active: bool, world) -> void:
	# At most nine one-cell movement steps per axis at the configured speeds.
	delta = clampf(delta, 0.0, 0.1)
	if not recover_enclosure(world):
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
		grounded = world.character_box_collides(position + Vector2(0.0, 0.5), BODY_SIZE, 1)


func recover_enclosure(world) -> bool:
	recovery_blocked = false
	if not world.box_collides(position, BODY_SIZE):
		return true
	# Bounded axis search, upward first at equal distance. No cell deletion and
	# no authority/body teleport: only this sampled character is repositioned.
	for distance: int in range(1, RECOVERY_RADIUS + 1):
		for direction: Vector2 in RECOVERY_DIRECTIONS:
			var candidate: Vector2 = position + direction * float(distance)
			if not world.box_collides(candidate, BODY_SIZE):
				position = candidate
				velocity = Vector2.ZERO
				grounded = false
				return true
	velocity = Vector2.ZERO
	grounded = false
	recovery_blocked = true
	return false


func move_horizontal(distance: float, world) -> void:
	var remaining: float = distance
	while absf(remaining) > 0.0001:
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(movement, 0.0)
		if world.character_box_collides(candidate, BODY_SIZE, 2):
			var step: Vector2 = candidate + Vector2.UP
			if grounded and not world.box_collides(step, BODY_SIZE) and world.character_box_collides(step + Vector2(0, 0.5), BODY_SIZE, 1):
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
		if world.character_box_collides(candidate, BODY_SIZE, 1 if movement > 0 else 3):
			if movement > 0.0:
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
