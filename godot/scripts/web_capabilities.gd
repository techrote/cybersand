class_name CyberWebCapabilities
extends RefCounted

const RAPIER_CLASS: StringName = &"RapierPhysicsServer2D"
const REQUIRED: Array[StringName] = [
	&"space_step", &"space_get_active_bodies", &"space_get_bodies_transform", &"space_flush_queries"
]

static func native_available() -> bool:
	return ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge")

static func rapier_probe() -> Dictionary:
	if not ClassDB.class_exists(RAPIER_CLASS):
		return {"ok": false, "reason": "Rapier extension unavailable"}
	if str(ProjectSettings.get_setting("physics/2d/physics_engine", "")) != "Rapier2D":
		return {"ok": false, "reason": "Rapier not selected"}
	var methods: Array[StringName] = []
	for method: Dictionary in ClassDB.class_get_method_list(RAPIER_CLASS):
		methods.append(StringName(method.name))
	for required: StringName in REQUIRED:
		if required not in methods:
			return {"ok": false, "reason": "Missing Rapier method: " + str(required)}
	# Isolated fixture: two rectangle shapes on one static body, a dynamic
	# rectangle, state writes/reads, impulse, CCD, manual stepping and batched
	# active transforms. It cannot change the application's World2D.
	var space: RID = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(space, false)
	var floor_shape: RID = PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(floor_shape, Vector2(64, 0.5))
	var wall_shape: RID = PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(wall_shape, Vector2(0.5, 30))
	var body_shape: RID = PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(body_shape, Vector2(4, 7))
	var floor_body: RID = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(floor_body, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_add_shape(floor_body, floor_shape, Transform2D(0, Vector2(64, 80)))
	PhysicsServer2D.body_add_shape(floor_body, wall_shape, Transform2D(0, Vector2(120, 50)))
	PhysicsServer2D.body_set_space(floor_body, space)
	var body: RID = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_RIGID)
	PhysicsServer2D.body_add_shape(body, body_shape)
	PhysicsServer2D.body_set_space(body, space)
	PhysicsServer2D.body_set_param(body, PhysicsServer2D.BODY_PARAM_MASS, 1.0)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, Vector2(64, 30)))
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(0, 300))
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	PhysicsServer2D.body_set_continuous_collision_detection_mode(body, PhysicsServer2D.CCD_MODE_CAST_SHAPE)
	PhysicsServer2D.body_apply_central_impulse(body, Vector2(2, 0))
	var impulse_velocity: Vector2 = PhysicsServer2D.body_get_state(body, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var saw_active: bool = false
	var batch_ok: bool = true
	for i: int in range(24):
		ClassDB.class_call_static(RAPIER_CLASS, &"space_step", space, 1.0 / 60.0)
		var active: Variant = ClassDB.class_call_static(RAPIER_CLASS, &"space_get_active_bodies", space)
		if not active is Array:
			batch_ok = false
			break
		var transforms: Variant = ClassDB.class_call_static(RAPIER_CLASS, &"space_get_bodies_transform", space, active)
		if not transforms is Array or transforms.size() != active.size():
			batch_ok = false
			break
		saw_active = saw_active or active.has(body)
		ClassDB.class_call_static(RAPIER_CLASS, &"space_flush_queries", space)
	var pose: Transform2D = PhysicsServer2D.body_get_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var moved: bool = pose.origin.y > 35.0
	var floor_holds: bool = pose.origin.y <= 74.0
	var passed: bool = moved and floor_holds and saw_active and batch_ok and impulse_velocity.x > 0.0
	PhysicsServer2D.free_rid(body)
	PhysicsServer2D.free_rid(floor_body)
	PhysicsServer2D.free_rid(body_shape)
	PhysicsServer2D.free_rid(wall_shape)
	PhysicsServer2D.free_rid(floor_shape)
	PhysicsServer2D.free_rid(space)
	return {"ok": passed, "reason": "Manual-step/CCD probe passed" if passed else "Rapier behavioural probe failed", "y": pose.origin.y}

static func status(world: Variant, rapier: bool) -> String:
	var runtime: String = "WASM" if OS.has_feature("web") else "NATIVE"
	return "CYBERSAND/%s · COMPAT · %d WORKER · %s" % [
		runtime, int(world.get_worker_threads()), "RAPIER2D" if rapier else "RIGID PHYSICS OFF"
	]
