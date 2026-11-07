extends SceneTree
const Order=preload("res://tests/test_sol_workbench_order.gd")
const Production=preload("res://scripts/workbench_physics_bridge.gd")
var checks: int=0
var failures: Array[String]=[]
func bits(values: Array) -> String:
	var bytes:=PackedByteArray();bytes.resize(values.size()*8)
	for i: int in values.size():bytes.encode_double(i*8,float(values[i]))
	return bytes.hex_encode()
func plain(value: Variant) -> Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var out: Dictionary={}
		for key: Variant in value:out[str(key)]=plain(value[key])
		return out
	if value is Array:
		var out: Array=[]
		for x: Variant in value:out.append(plain(x))
		return out
	return value
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("SOL_ORDER_ADAPTER ",message)
func read(body: RigidBody2D) -> Dictionary:
	var rid: RID=body.get_rid();var d:=PhysicsServer2D.body_get_direct_state(rid)
	var pose: Transform2D=d.transform;var v: Vector2=d.linear_velocity;var w: float=d.angular_velocity
	var server_pose: Transform2D=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var server_v: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var server_w: float=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var mass: float=PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float=PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)
	return {"bits":bits([pose.x.x,pose.x.y,pose.y.x,pose.y.y,pose.origin.x,pose.origin.y,v.x,v.y,w,mass,inertia]),
		"server_bits":bits([server_pose.x.x,server_pose.x.y,server_pose.y.x,server_pose.y.y,server_pose.origin.x,server_pose.origin.y,server_v.x,server_v.y,server_w,mass,inertia]),
		"local_com":[d.center_of_mass_local.x,d.center_of_mass_local.y],"mass":mass,"inertia":inertia}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output: String=OS.get_environment("SOL_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):printerr("SOL_ORDER_ADAPTER refuses output");quit(1);return
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/sol_workbench_order_001.json"))
	var geometry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/sol_mass_initialization_002.json"))
	var cases: Array=[]
	for structure: String in ["tree","building"]:
		var fixture: Dictionary=geometry.fixtures[structure]
		for action_case: Dictionary in profile.adapter_cases:
			var reference: Dictionary={}
			for implementation: String in ["production","correction-first","impulse-first"]:
				var viewport:=SubViewport.new();viewport.world_2d=World2D.new();viewport.size=Vector2i(160,128);root.add_child(viewport)
				var body:=RigidBody2D.new();body.freeze=true;body.collision_layer=0;body.collision_mask=0
				body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_AUTO;body.mass=fixture.mass;body.inertia=fixture.inertia
				body.gravity_scale=0.;body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE
				body.linear_damp=0.;body.angular_damp=0.;body.position=Vector2(fixture.center[0],fixture.center[1])
				var shapes: Array[CollisionShape2D]=[]
				for i: int in range(0,fixture.rectangles.size(),4):
					var a: Array=fixture.rectangles;var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new()
					rectangle.size=Vector2(a[i+2],a[i+3]);shape.shape=rectangle;shape.position=Vector2(a[i],a[i+1])+rectangle.size*.5-body.position
					shape.disabled=true;body.add_child(shape);shapes.append(shape)
				viewport.add_child(body);await process_frame
				var bridge: Production=Production.new() if implementation=="production" else Order.OrderingBridge.new()
				if implementation!="production":(bridge as Order.OrderingBridge).application_order=implementation
				var bodies: Array[RigidBody2D]=[body];check(bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(29,38)]))==OK,"fresh private Rapier")
				for shape: CollisionShape2D in shapes:shape.disabled=false
				body.freeze=false;body.sleeping=false
				var rid: RID=body.get_rid();PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(action_case.velocity[0],action_case.velocity[1]))
				PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,float(action_case.omega));bridge.refresh_all_states()
				var action: Dictionary={"id":1,"instance_id":body.get_instance_id(),"sample":0,"age":0,
					"impulse":Vector2(action_case.impulse[0],action_case.impulse[1]),"torque":float(action_case.torque),"correction":Vector2(action_case.correction[0],action_case.correction[1])}
				var before: Dictionary=read(body);bridge._apply(0,action);var after: Dictionary=read(body)
				check(before.bits==before.server_bits and after.bits==after.server_bits,"direct/server readback agree")
				check(bridge.manual_step_count()==0 and before.mass==fixture.mass and after.mass==fixture.mass,"no physical warmstep or mass change")
				if implementation=="production":reference=after
				elif implementation=="correction-first":check(after==reference,"copied control exactly matches production final state")
				var stages: Array=[] if implementation=="production" else (bridge as Order.OrderingBridge).stage_values
				cases.append({"structure":structure,"case":action_case.name,"implementation":implementation,"action":plain(action),"before":before,"after":after,"stages":plain(stages)})
				bridge.shutdown();viewport.queue_free();await process_frame
	check(cases.size()==60,"complete fixed adapter oracle")
	var report: Dictionary={"registration":"SOL-WORKBENCH-ORDER-001-ADAPTER","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"platform":OS.get_name(),"checks":checks,"failures":failures,"cases":cases,"scope":"Actual private Rapier primitive-action oracle; no nativeWorld, cut trajectory or settling efficacy"}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(1);return
	file.store_string(JSON.stringify(report,"",true,true));file.flush();var error: Error=file.get_error();file.close()
	print("SOL_ORDER_ADAPTER checks=",checks," failures=",failures.size());quit(int(not failures.is_empty() or error!=OK))
