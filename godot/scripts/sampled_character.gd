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


func reset(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	grounded = false


func simulate(delta: float, horizontal_input: float, jetpack_active: bool, world) -> void:
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
		grounded = world.box_collides(position + Vector2(0.0, 0.5), BODY_SIZE)


func move_horizontal(distance: float, world) -> void:
	var remaining: float = distance
	while absf(remaining) > 0.0001:
		var movement: float = clampf(remaining, -1.0, 1.0)
		var candidate: Vector2 = position + Vector2(movement, 0.0)
		if world.box_collides(candidate, BODY_SIZE):
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
		if world.box_collides(candidate, BODY_SIZE):
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
