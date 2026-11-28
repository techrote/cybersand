extends SceneTree
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
 for vx: float in [0.7,1.0,1.3,1.6,2.0]:
  var b=Bridge.new();var s: RID=PhysicsServer2D.space_create();PhysicsServer2D.space_set_active(s,false)
  b.initialize(5001,s)
  b.install_terrain([{"id":0,"session":5001,"revision":1,"digest":"ledge","rectangles":PackedInt32Array([20,40,8,2])}])
  var d={"session":5001,"id":1,"generation":1,"body_generation":1,"transaction":1,"geometry_revision":1,"geometry_digest":"one","rectangles":PackedInt32Array([1,1,1,1]),"width":3,"height":3,"origin_x":26,"origin_y":3,"position_x":26.0,"position_y":3.0,"rotation":0.0,"mass":1.0,"com_x":1.5,"com_y":1.5,"inertia":1.0/6.0,"vx":vx}
  b.reserve_body(d);b.activate(d)
  var maxa=0.0;var maxr=0.0;var prev=0.0;var last={}
  for n in range(240):
   ClassDB.class_call_static(&"RapierPhysicsServer2D",&"space_step",s,1.0/240.0)
   ClassDB.class_call_static(&"RapierPhysicsServer2D",&"space_flush_queries",s)
   maxa=maxf(maxa,absf(PhysicsServer2D.body_get_state(b.bodies[1].rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)))
   last=b.capture_completed_main_step(n+1,1.0/240.0)
   if not last.get("ok",false):break
   maxr=maxf(maxr,absf(last.poses[0].rotation-prev));prev=last.poses[0].rotation
  print(JSON.stringify({"vx":vx,"peak":maxa,"maxr":maxr,"last":last}))
  b.shutdown();PhysicsServer2D.free_rid(s)
 quit()
