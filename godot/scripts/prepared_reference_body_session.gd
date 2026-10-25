extends "res://scripts/prepared_physical_session.gd"

# The existing three Water Feel reference rectangles retain their authored
# physical settings. Their replacement graph stays in its permanent private
# space; the ordinary sampled character remains a separate worker owner.
var _bridge := CyberRapierPhysicsBridge.new()
var _bodies: Array[RigidBody2D] = []

func owner_kind() -> String:
	return "reference_body"

func physics_bridge() -> CyberRapierPhysicsBridge:
	return _bridge

func bodies() -> Array[RigidBody2D]:
	return _bodies.duplicate()

func prepare_reference(parent: Node, templates: Array[RigidBody2D], size: Vector2,
		positions: PackedVector2Array = PackedVector2Array(), rotations: PackedFloat32Array = PackedFloat32Array()) -> bool:
	if viewport != null or templates.size() != 3 or not size.is_finite() or size.x <= 0 or size.y <= 0:
		last_error = "Invalid reference body owner configuration"
		return false
	if (not positions.is_empty() and positions.size()!=3) or (not rotations.is_empty() and rotations.size()!=3):
		last_error = "Reference body poses require exactly three positions and rotations when supplied"
		return false
	var initial_positions := PackedVector2Array([Vector2(160,176),Vector2(212,176),Vector2(264,176)]) if positions.is_empty() else positions.duplicate()
	var initial_rotations := PackedFloat32Array([0,0,0]) if rotations.is_empty() else rotations.duplicate()
	for index: int in range(3):
		if not initial_positions[index].is_finite() or not is_finite(initial_rotations[index]):
			last_error = "Reference body poses must be finite"
			return false
	viewport = SubViewport.new()
	viewport.name = "PreparedReferenceBodySpace"
	viewport.size = Vector2i(2,2)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.world_2d = World2D.new()
	parent.add_child(viewport)
	PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
	for index: int in range(3):
		var body: RigidBody2D = templates[index].duplicate()
		body.name = "ReferenceBody%d" % index
		body.freeze = true
		body.collision_layer = 1;body.collision_mask = 1
		body.position = initial_positions[index]
		body.rotation = initial_rotations[index];body.linear_velocity = Vector2.ZERO;body.angular_velocity = 0.0
		var shape := RectangleShape2D.new()
		shape.size = size
		body.get_node("CollisionShape2D").shape = shape
		viewport.add_child(body)
		_bodies.append(body)
	var sizes := PackedVector2Array()
	sizes.resize(3);sizes.fill(size)
	if _bridge.initialize(viewport.world_2d.space,_bodies,sizes) != OK:
		last_error = "Reference body Rapier initialization refused"
		close()
		return false
	for index: int in range(3): _bridge.reset_body(index,initial_positions[index],initial_rotations[index])
	return _capture_frozen_pose()

func _close_prepared_owner() -> void:
	_bridge.shutdown()
	_bodies.clear()
