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

func prepare_reference(parent: Node, templates: Array[RigidBody2D], size: Vector2) -> bool:
	if viewport != null or templates.size() != 3 or not size.is_finite() or size.x <= 0 or size.y <= 0:
		last_error = "Invalid reference body owner configuration"
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
		body.position = Vector2(160+index*52,176)
		body.rotation = 0.0;body.linear_velocity = Vector2.ZERO;body.angular_velocity = 0.0
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
	for index: int in range(3): _bridge.reset_body(index,Vector2(160+index*52,176),0.0)
	return _capture_frozen_pose()

func _close_prepared_owner() -> void:
	_bridge.shutdown()
	_bodies.clear()
