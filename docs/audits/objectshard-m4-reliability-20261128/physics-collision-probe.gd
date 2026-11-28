extends SceneTree
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const RAPIER: StringName = &"RapierPhysicsServer2D"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: int = 1000
	for x: float in [27.0,27.2,27.4,27.6,27.8]:
		for speed: float in [60.0,100.0,140.0,180.0]:
			session += 1
			var bridge = Bridge.new()
			var space: RID = PhysicsServer2D.space_create()
			PhysicsServer2D.space_set_active(space,false)
			bridge.initialize(session,space)
			bridge.install_terrain([{"id":0,"session":session,"revision":1,"digest":"ledge","rectangles":PackedInt32Array([20,40,8,2])}])
			var body: Dictionary = {"session":session,"id":1,"generation":1,"body_generation":1,"transaction":1,"geometry_revision":1,"geometry_digest":"unit",
				"rectangles":PackedInt32Array([0,0,1,1]),"width":3,"height":3,"origin_x":27,"origin_y":38,"position_x":x,"position_y":38.6,"rotation":0.0,
				"mass":1.0,"com_x":0.5,"com_y":0.5,"inertia":1.0/6.0,"vy":speed}
			bridge.reserve_body(body)
			bridge.activate(body)
			var peak_omega: float = 0.0
			var result: Dictionary = {}
			for step: int in range(6):
				ClassDB.class_call_static(RAPIER,&"space_step",space,1.0/240.0)
				ClassDB.class_call_static(RAPIER,&"space_flush_queries",space)
				peak_omega = maxf(peak_omega,absf(float(PhysicsServer2D.body_get_state(bridge.bodies[1].rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))))
				result = bridge.capture_completed_main_step(step+1,1.0/240.0)
				if not result.get("ok",false): break
			print(JSON.stringify({"x":x,"initial_speed":speed,"peak_omega":peak_omega,"capture":result}))
			bridge.shutdown()
			PhysicsServer2D.free_rid(space)
	quit()
