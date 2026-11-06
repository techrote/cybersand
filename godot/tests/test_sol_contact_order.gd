extends SceneTree
const Session=preload("res://scripts/solid_detachment_session.gd")
const Worker=preload("res://scripts/solid_detachment_worker.gd")
const Bridge=preload("res://scripts/rapier_physics_bridge.gd")
class DispatchBridge:
	extends Bridge
	var actions: Array[String]=[]
	var callback: Callable
	var advance: bool=true
	var pending: int=0
	var current_seen: int=-1
	func pending_hard_surface_chunks() -> int:return pending
	func process_hard_surface_collider_budget(_maximum: int=16,_time: int=0) -> int:return 0
	func step() -> void:
		actions.append("step")
		if advance:_manual_step_count+=1
		if callback.is_valid():callback.call()
	func apply_solid_sand_contact(_observation: Dictionary,_index: int,_snapshot: int,_tick: int,
			_revision: int,_epoch: int,_token: String,_generation: int,_sample: int,
			current: int,_centres: PackedVector2Array,_sizes: PackedVector2Array) -> Dictionary:
		actions.append("sand");current_seen=current
		return {"accepted":false,"outcome":"DispatchOnlyRefusal"}
class DispatchSession:
	extends Session
	var captured: Dictionary={}
	var publications: int=0
	var publish_ok: bool=true
	var source_age: int=0
	var capture_enabled: bool=true
	func envelope() -> Dictionary:
		return {"observation":{},"snapshot":1,"tick":19,"revision":31,"epoch":physics_epoch,
			"token":str(source_receipt.token),"generation":generation,"worker":worker.get_instance_id(),
			"bridge":bridge.get_instance_id(),"body":body.get_instance_id(),"rid":body.get_rid().get_id(),
			"sample":(_coupling_sample_serial-source_age+1000000)%1000000,"current":_coupling_sample_serial,"manual_step":bridge.manual_step_count()}
	func _consume_compound_results() -> Dictionary:
		captured=envelope()
		if bridge is DispatchBridge:(bridge as DispatchBridge).actions.append("ordinary")
		if not capture_enabled:return {}
		return captured
	func _publish_compound_states() -> bool:
		publications+=1
		if bridge is DispatchBridge:(bridge as DispatchBridge).actions.append("publish")
		if publish_ok:_coupling_sample_serial=(_coupling_sample_serial+1)%1000000
		return publish_ok
class FaultBridge:
	extends Bridge
	var reads: int=0
	var inject_fault: bool=true
	func _read_solid_contact_result(rid: RID,v: Vector2,w: float,m: float,i: float) -> Dictionary:
		reads+=1
		var d: Dictionary=super._read_solid_contact_result(rid,v,w,m,i)
		if inject_fault:d.actual_energy_after=NAN
		return d
class FaultSession:
	extends DispatchSession
	func _consume_compound_results() -> Dictionary:
		var e: Dictionary=envelope();var contacts: Array=[]
		for x: int in [19,20,21]:
			contacts.append({"proxy":1,"face":2,"cell":Vector2i(x,21),"point":Vector2(x+.5,21.25),
				"normal":Vector2.DOWN,"a":Vector2(x+1.,21.25),"b":Vector2(x,21.25),"depth":.25,"area":.25,"weight":1.})
		e.observation={"schema":"cybersand.sol281.sand-contact.v1","ok":true,"complete":true,
			"token":e.token,"body_generation":str(e.generation),"revision":str(e.revision),"sample_serial":e.sample,
			"tick":e.tick,"snapshot_serial":e.snapshot,"physics_epoch":e.epoch,"published_usec":Time.get_ticks_usec(),
			"source_transform":Transform2D(0.,Vector2(20.5,20.25)),"contacts":contacts}
		captured=e.duplicate(true);return e
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("ORDER_DISPATCH ",why)
func setup(s: DispatchSession,b: CyberRapierPhysicsBridge,body: RigidBody2D) -> void:
	s.worker=Worker.new();s.bridge=b;s.body=body;s.active=true;s.physics_paused=false
	s.generation=7;s.physics_epoch=2;s.source_receipt={"token":"23:1"};s.sand_contact_order="post"
	s._coupling_sample_serial=1;s._coupling_local_centers=PackedVector2Array([Vector2.ZERO]);s._coupling_sizes=PackedVector2Array([Vector2(4,2)])
	s._contact_metrics={"response_attempts":0,"response_ms_all_attempts":0.,"response_ms_max_attempt":0.,
		"response_rid_state_ms_all_attempts":0.,"response_planner_ms_all_attempts":0.,"response_impulse_apply_ms_all_attempts":0.,
		"response_readback_ms_all_attempts":0.,"response_other_ms_all_attempts":0.,"response_refusals":{},"response_failures":{},"energy_violations":0}
func retire(s: DispatchSession) -> void:
	# The actual scene body is owned by this test, not the synthetic dispatch session.
	s.body=null;s.bridge=null;s.close()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
	var body:=RigidBody2D.new();body.gravity_scale=0.;body.mass=520.;body.inertia=520.*20./12.
	body.position=Vector2(20.5,20.25);body.linear_damp=0.;body.angular_damp=0.
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(4,2);shape.shape=rectangle;body.add_child(shape);viewport.add_child(body)
	await process_frame
	for serial: int in [1,999999]:
		var b:=DispatchBridge.new();var s:=DispatchSession.new();setup(s,b,body);s._coupling_sample_serial=serial
		s.physics_step();check(b.actions==["ordinary","step","sand","publish"],"single ordered dispatch")
		check(b.current_seen==(serial+1)%1000000 and s._coupling_sample_serial==b.current_seen,"physical age and single publication wrap")
		retire(s)
	var no_capture:=DispatchSession.new();var no_capture_bridge:=DispatchBridge.new();setup(no_capture,no_capture_bridge,body);no_capture.capture_enabled=false
	no_capture.physics_step();check(no_capture_bridge.actions==["ordinary","step","publish"],"no admitted ordinary observation gives no Sand")
	retire(no_capture)
	for key: String in ["generation","epoch","token","worker","bridge","body","paused","failed","busy","nonadvance","terrain"]:
		var b:=DispatchBridge.new();var s:=DispatchSession.new();setup(s,b,body)
		match key:
			"generation":b.callback=func():s.generation+=1
			"epoch":b.callback=func():s.physics_epoch+=1
			"token":b.callback=func():s.source_receipt.token="retired"
			"worker":b.callback=func():s.worker=null
			"bridge":b.callback=func():s.bridge=null
			"body":b.callback=func():s.body=null
			"paused":b.callback=func():s.physics_paused=true
			"failed":b.callback=func():s._failed=true
			"busy":b.callback=func():s.transaction_busy=true
			"nonadvance":b.advance=false
			"terrain":b.pending=1
		s.physics_step();check(not b.actions.has("sand") and s.publications==0,key+" prevents Sand and publication")
		check(not s.captured.is_empty(),key+" captured work remains in test denominator")
		retire(s)
	var default_session:=Session.new();default_session.sand_contact_order="post";default_session.close()
	check(default_session.sand_contact_order=="pre","teardown resets opt-in")
	var actual:=FaultBridge.new();var bodies: Array[RigidBody2D]=[body]
	check(actual.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(4,2)]))==OK,"actual Rapier fault owner")
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0,12))
	var stale:=FaultSession.new();setup(stale,actual,body);stale.source_age=1
	stale.physics_step();check(stale.last_contact_response.get("outcome")=="StaleContactSample" and actual.reads==0 and stale.publications==1,"age one becomes two and refuses before readback")
	retire(stale)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.,Vector2(20.5,20.25)))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0,12))
	var s:=FaultSession.new();setup(s,actual,body);var before: int=actual.manual_step_count()
	s.physics_step();check(actual.manual_step_count()==before+1,"one actual step before failed Sand")
	check(s.last_contact_response.get("failed",false) and actual.reads==1 and s.last_contact_response.get("mutation_may_have_occurred",false),"real impulse precedes copied readback fault")
	check(s._failed and s.physics_paused and s.publications==0 and s._coupling_sample_serial==1,"failed post application prevents publication")
	var e: Dictionary=s.captured
	var duplicate: Dictionary=actual.apply_solid_sand_contact(e.observation,0,e.snapshot,e.tick,e.revision,e.epoch,e.token,e.generation,e.sample,2,s._coupling_local_centers,s._coupling_sizes)
	check(duplicate.get("outcome")=="DuplicateOrOldContact" and actual.reads==1,"failed application lease retained")
	s.set_paused(false);s.physics_step();check(actual.manual_step_count()==before+1 and s.publications==0,"unpause cannot retry or step")
	retire(s);actual.shutdown()
	var finite:=FaultBridge.new();finite.inject_fault=false
	check(finite.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(4,2)]))==OK,"finite publication-fault owner")
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.,Vector2(20.5,20.25)))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0,12))
	var publication:=FaultSession.new();setup(publication,finite,body);publication.publish_ok=false
	publication._contact_metrics.merge({"response_accepts":0,"impulse_magnitude_sum":0.,"max_impulse_magnitude":0.,"impulse_x_sum":0.,"impulse_y_sum":0.,"angular_momentum_change_sum":0.,"torque_impulse_sum":0.,"energy_change_sum":0.,"response_ms_total":0.,"latency_ms_total":0.})
	publication.physics_step();check(publication.last_contact_response.get("accepted",false) and publication._failed and publication.publications==1,"successful actual Sand retained when publication fails")
	publication.set_paused(false);publication.physics_step();check(finite.manual_step_count()==1 and publication.publications==1,"publication failure stops without retry")
	retire(publication);finite.shutdown();viewport.queue_free();await process_frame
	print("SOL_ORDER_DISPATCH checks=",checks," failures=",failures.size());quit(int(not failures.is_empty()))
