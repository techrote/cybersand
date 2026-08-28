extends SceneTree

# Minimal stage-2 fixture: ordinary Godot RigidBody2D and RectangleShape2D
# advance through Rapier2D before the project-specific manual-step bridge is used.
const PHYSICS_FRAMES: int = 8
const POSITION_EPSILON: float = 0.0001

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_root: Node2D = Node2D.new()
	root.add_child(fixture_root)
	var body: RigidBody2D = RigidBody2D.new()
	body.gravity_scale = 0.094
	body.position = Vector2(100.0, 40.0)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(8.0, 14.0)
	collision.shape = shape
	body.add_child(collision)
	fixture_root.add_child(body)
	await process_frame

	var start_y: float = body.position.y
	for _frame: int in range(PHYSICS_FRAMES):
		await physics_frame
	_expect(
		body.position.y > start_y + POSITION_EPSILON,
		"ordinary RigidBody2D did not advance under Rapier2D automatic stepping"
	)

	fixture_root.queue_free()
	await process_frame
	if _failures == 0:
		print("Rapier2D drop-in RigidBody2D fixture passed")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
