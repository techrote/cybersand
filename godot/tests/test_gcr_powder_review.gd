extends SceneTree

var failures: Array[String] = []
var checks := 0
var runs: Array = []
func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures.append(why); push_error(why); quit(1)
func pose(scene) -> Array:
	var body: RigidBody2D=scene.runtime._arena.session.bodies()[0]
	var rid: RID=body.get_rid()
	var t: Transform2D=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var v: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	return [t.origin.x,t.origin.y,t.get_rotation(),v.x,v.y,PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)]
func hostile() -> Dictionary:
	return {"move":Vector2(1,-1),"aim":Vector2.UP,"effort":1.0,"trim":1.0,"primary":true,"secondary":true,"auxiliary":true}
func advance(scene, ticks: int) -> Array:
	var states: Array=[]
	for tick: int in range(ticks):
		scene.advance_frame(hostile(),true)
		var rig=scene.runtime._arena.session._rigs[0]
		check(rig._last_impulse==Vector2.ZERO and rig._last_torque_impulse==0.0,"scripted run has no pilot/airbrake/level impulse")
		check(not scene.runtime.failed,"real synchronous owner remains healthy")
		states.append(pose(scene))
	return states
func _run() -> void:
	var scene=load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene);scene.set_physics_process(false);await process_frame
	check(scene.applied_controls.response=="LA","ordinary LA default retained")
	var same_initial: Dictionary={}
	for response: int in [0,2,3]:
		scene.return_to_painting()
		scene.response_select.select(response)
		check(scene.apply_controls(),"apply response")
		for mode: String in ["burst","stream"]:
			check(scene.start_powder_test(mode),"fresh repeatable "+mode)
			var receipt: Dictionary=scene.powder_test_receipt()
			check(scene.selected==2 and scene.runtime.paused,"fixed Kestrel starts paused")
			check(receipt.initial.gravity==0.0 and receipt.native_gravity==0.0,"actual body and native/bridge setup gravity agree")
			check(receipt.initial.position==Vector2(512,256) and receipt.initial.velocity==Vector2.ZERO and receipt.initial.omega==0.0 and receipt.initial.rotation==0.0,"exact initial pose and zero motion")
			check(is_equal_approx(receipt.initial.mass,.1) and is_equal_approx(receipt.initial.inertia,.975),"authored Kestrel mass/inertia retained")
			if not same_initial.has(mode):same_initial[mode]=receipt.initial.duplicate(true)
			else:check(receipt.initial==same_initial[mode],"all three responses share starting material hash/pose/properties")
			check(receipt.ticks==0 and receipt.inserted==(96 if mode=="burst" else 0),"exact initial source schedule")
			var paused_hash: String=scene.runtime._arena._world.get_physical_state_hash()
			scene.advance_frame(hostile(),true)
			check(scene.powder_test_receipt().ticks==0 and scene.runtime._arena._world.get_physical_state_hash()==paused_hash,"pause freezes native/source clocks")
			scene._toggle_pause()
			var first: Array=advance(scene,120)
			var first_receipt: Dictionary=scene.powder_test_receipt()
			check(first_receipt.ticks==120,"one source clock per actual tick")
			check(first_receipt.attempted==first_receipt.inserted+first_receipt.blocked,"actual source ledger closes")
			check(first_receipt.inserted>0,"real material supplied")
			check(scene.start_powder_test(mode),"fresh same-arm replay")
			check(scene.powder_test_receipt().initial==receipt.initial,"reset restores starting pose/hash")
			scene._toggle_pause()
			check(advance(scene,120)==first,"same-arm all120 poses replay exactly")
			var repeated: Dictionary=scene.powder_test_receipt()
			check(repeated.ledger==first_receipt.ledger,"same-arm source edit ledger replays exactly")
			runs.append({"response":scene.applied_controls.response,"mode":mode,"initial_hash":receipt.initial.native_hash,"inserted120":repeated.inserted,"last_pose":pose(scene)})
			check(scene.apply_controls() and scene.powder_test.mode==mode and scene.runtime.paused and scene.powder_test_receipt().initial==receipt.initial,"Apply preserves current canned mode and restarts identically")
	var old_arena=scene.runtime._arena
	scene.response_select.select(1)
	check(not scene.apply_controls() and scene.runtime._arena==old_arena and scene.powder_test.active() and not scene.control_error.is_empty(),"RFT refusal preserves active loading owner and explains choice")
	scene.response_select.select(3)
	check(scene.start_powder_test("stream"),"stream duration witness")
	scene._toggle_pause();advance(scene,600)
	var end_source: Dictionary=scene.powder_test_receipt()
	check(end_source.ticks==600 and end_source.attempted==2400,"stream exactly600 four-cell attempts")
	advance(scene,2)
	check(scene.powder_test_receipt().attempted==2400,"source stops after fixed schedule")
	advance(scene,1198)
	check(scene.powder_test_receipt().ticks==1800 and scene.runtime.paused,"test auto-pauses at fixed1800ticks")
	var stopped_tick: int=scene.runtime.tick
	scene.advance_frame(hostile(),true)
	check(scene.runtime.tick==stopped_tick,"completed test does not advance")
	# Block the nozzle deliberately. A source must never overwrite authored cells.
	check(scene.start_powder_test("stream"),"blocked source witness")
	scene.runtime._arena._world.diagnostic_fill_rect(Vector2i(514,224),Vector2i(4,1),58)
	scene._toggle_pause();advance(scene,1)
	var blocked: Dictionary=scene.powder_test_receipt()
	check(blocked.inserted==0 and blocked.blocked==4,"blocked nozzle cannot teleport/overwrite through hard material")
	check(scene.start_powder_test("stream"),"current hull authoring witness")
	var body: RigidBody2D=scene.runtime._arena.session.bodies()[0]
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0,Vector2(516,224)))
	check(scene.powder_test.before_step(scene.runtime._arena._world),"current-pose guard evaluates before a new native mask")
	check(scene.powder_test_receipt().inserted==0 and scene.powder_test_receipt().blocked==4,"current hull prevents source placement despite previous mask")
	check(scene.start_powder_test("burst"),"manual edit witness")
	check(scene.paint_at(Vector2i(600,300),23),"manual painting retained")
	check(scene.powder_test_receipt().modified and scene.runtime.paused,"manual edit labels and pauses repeatability")
	var before_tick: int=scene.runtime.tick
	scene._toggle_pause();scene.advance_frame(hostile(),true)
	check(scene.runtime.tick==before_tick,"modified run cannot silently continue as repeatable")
	check(scene.start_powder_test("burst") and not scene.powder_test_receipt().modified,"reset clears modified status")
	check(scene.start_powder_test("bad-mode")==false,"unknown test refuses")
	check(scene.start_powder_test("burst"),"focus pause witness")
	scene._toggle_pause();scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(scene.runtime.paused,"focus loss pauses automated source")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(scene.runtime.paused,"focus gain cannot resume source automatically")
	scene.control_fields.budget.value=40
	scene.control_fields.mass_multiplier.value=2
	scene.control_fields.inertia_multiplier.value=3
	check(scene.apply_controls() and scene.powder_test.active() and scene.runtime.paused,"Apply repeats test with staged controls")
	var scaled: Dictionary=scene.powder_test_receipt()
	check(is_equal_approx(scaled.initial.mass,.2) and is_equal_approx(scaled.initial.inertia,5.85),"test retains requested actual mass/inertia scaling")
	scene._restart()
	check(scene.powder_test_receipt().initial==scaled.initial and scene.runtime.paused,"R repeats current test setup")
	check(scene.return_to_painting(),"ordinary painting returns")
	check(not scene.powder_test.active() and is_equal_approx(scene.runtime._arena.session.bodies()[0].gravity_scale,38.0/980.0),"normal room restores gravity and controls")
	scene.queue_free();await process_frame
	print("GCR_POWDER_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"runs":runs}))
	quit(0 if failures.is_empty() else 1)
