extends SceneTree

# Synthetic versioned native receipts, actual main-thread Rapier application.
# Zero cellular trajectories: this is protocol/energy accounting, not efficacy.
var checks: int = 0
var failures: Array[String] = []
var held: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		printerr("FAIL REST BRIDGE ",message)

func near(a: float,b: float,message: String) -> void:
	check(absf(a-b)<1e-5*maxf(1.,absf(b)),message+" actual="+str(a)+" expected="+str(b))

func fresh(mode: String = "", velocity: Vector2 = Vector2(1,2), omega: float = .25) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.world_2d=World2D.new()
	root.add_child(viewport)
	var body := RigidBody2D.new()
	body.mass=2.
	body.inertia=2.
	body.gravity_scale=0.
	body.position=Vector2(50,50)
	body.linear_damp=0.
	body.angular_damp=0.
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(2,2)
	collision.shape=shape
	body.add_child(collision)
	viewport.add_child(body)
	await process_frame
	var bridge := CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	check(bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(2,2)]))==OK,"real Rapier bridge initializes")
	if not mode.is_empty(): check(bridge.configure_gcr_rest(mode,20.,0.),"fresh explicit rest configuration")
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocity)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,omega)
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	check(states.size()==17,"one intended packed sample")
	var context: Dictionary = bridge.gcr_rest_context_for_states(states,false,true) if not mode.is_empty() else {}
	var value: Dictionary = {"body":body,"viewport":viewport,"bridge":bridge,"states":states,"context":context}
	held.append(value)
	return value

func result(value: Dictionary, impulse: Vector2, torque: float, correction: Vector2 = Vector2.ZERO) -> PackedFloat64Array:
	var s: PackedFloat64Array = value.states
	return PackedFloat64Array([1,impulse.x,impulse.y,correction.x,correction.y,1,0,0,s[10],torque,s[12],s[13],1,s[16]])

func receipt(value: Dictionary, mode: String, impulse: Vector2, torque: float, caught: bool = false) -> Dictionary:
	var s: PackedFloat64Array = value.states
	return {"version":1,"mode":mode,"session":int(s[16]),"bodies":[{"id":1,"sample":int(s[10]),"session":int(s[16]),
		"catch_applied":caught,"correction_mode":mode in ["R","PRC"],"gravity_certified":caught,"overlap_measured":true,"post_overlap":0 if caught else 1,"quiet_count":30 if caught else 0,
		"uncaught_impulse":Vector2.ZERO if caught else impulse,"uncaught_torque":0.0 if caught else torque,
		"catch_delta_impulse":impulse if caught else Vector2.ZERO,"catch_delta_torque":torque if caught else 0.,
		"sample_velocity":Vector2(s[6],s[7]),"sample_omega":s[8],"mass":s[9],"inertia":s[11],"gravity":0.,"dt":s[15]}]}

func _run() -> void:
	var baseline: Dictionary = await fresh()
	var correction := Vector2(0,-.1)
	var impulse := Vector2(0,-.25)
	check(baseline.bridge.apply_gcr_results(1,result(baseline,impulse,.1,correction))==1,"old unconfigured GCR remains accepted")
	near(PhysicsServer2D.body_get_state(baseline.body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY).y,-.125,"old correction zeroing behavior preserved")
	var corrected: Dictionary = await fresh("R")
	var r: Dictionary = receipt(corrected,"R",impulse,.1)
	var before: Vector2 = PhysicsServer2D.body_get_state(corrected.body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	check(corrected.bridge.apply_gcr_results(1,result(corrected,impulse,.1,correction))==0,"configured rest cannot use missing receipt")
	check(PhysicsServer2D.body_get_state(corrected.body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)==before,"missing receipt makes no partial velocity mutation")
	check(corrected.bridge.apply_gcr_results(1,result(corrected,impulse,.1,correction),r)==1,"R receipt accepted")
	var actual: Dictionary = corrected.bridge.gcr_application_diagnostics().bodies[0]
	near(actual.velocity_after_wrench.y,1.875,"R retains sampled velocity before original impulse")
	near(actual.zeroing_removed_energy,0.,"R removes no energy by velocity zeroing")
	near(actual.old_zeroing_counterfactual_velocity.y,0.,"old zeroing counterfactual kept separately")
	check(actual.correction_applied and actual.physical_wrench_applications==1,"translation plus one physical J/L pair")
	near(actual.kinetic_after_wrench,.5*2.*actual.velocity_after_wrench.length_squared()+.5*2.*actual.omega_after_wrench*actual.omega_after_wrench,"actual kinetic ledger closes")
	check(not corrected.bridge.configure_gcr_rest("C",20.,0.),"configuration cannot change on sampled live bridge")
	var caught: Dictionary = await fresh("C",Vector2(.01,.05),.005)
	var arrest := Vector2(-.02,-.1)
	var c: Dictionary = receipt(caught,"C",arrest,-.01,true)
	check(caught.bridge.apply_gcr_results(1,result(caught,arrest,-.01),c)==1,"valid synthetic catch uses one native total wrench")
	actual=caught.bridge.gcr_application_diagnostics().bodies[0]
	if absf(float(actual.catch_removed_energy)-.002625)>.00001: print("REST_CATCH_LEDGER_DETAIL ",actual)
	check(actual.velocity_after_wrench.is_zero_approx(),"actual linear arrest measured")
	near(actual.omega_after_wrench,0.,"actual angular arrest measured")
	near(actual.catch_removed_energy,.002625,"catch energy removed equals same-state uncaught counterfactual")
	check(actual.physical_wrench_applications==1,"catch is not a second application path")
	var stale: Dictionary = await fresh("C",Vector2(.01,.05),.005)
	c=receipt(stale,"C",arrest,-.01,true)
	stale.bridge.pack_gcr_body_states()
	check(stale.bridge.apply_gcr_results(1,result(stale,arrest,-.01),c)==0,"caught sample age1 refuses despite ordinary GCR age allowance")
	check(stale.bridge.gcr_application_diagnostics().refusal=="rest_catch_age","caught stale refusal is explicit")
	var driven: Dictionary = await fresh("C",Vector2(.01,.05),.005)
	c=receipt(driven,"C",arrest,-.01,true)
	check(driven.bridge.apply_trial_impulses(0,Vector2(.1,0),0.),"known external driving impulse")
	check(driven.bridge.apply_gcr_results(1,result(driven,arrest,-.01),c)==0,"late drive vetoes catch")
	check(driven.bridge.gcr_application_diagnostics().refusal=="rest_catch_drive","late drive cannot be averaged away")
	var mismatch: Dictionary = await fresh("C",Vector2(.01,.05),.005)
	c=receipt(mismatch,"C",arrest,-.01,true)
	c.bodies[0].catch_delta_impulse=Vector2.ZERO
	check(mismatch.bridge.apply_gcr_results(1,result(mismatch,arrest,-.01),c)==0,"catch decomposition must equal actual packed wrench")
	check(mismatch.bridge.gcr_application_diagnostics().refusal=="rest_wrench","decomposition refusal explicit")
	var worker := CyberSimulationWorker.new()
	worker._gcr_experiment=true
	var valid: Dictionary = mismatch.context.duplicate(true)
	check(worker.set_gcr_body_states(mismatch.states,1,valid),"copied context accepted atomically with sample")
	valid.gravity=10.
	check(worker._gcr_rest_context.gravity==0.,"caller mutation cannot alter worker-owned context")
	var invalid: Dictionary = mismatch.context.duplicate(true)
	invalid.external_drive="false"
	check(not worker.set_gcr_body_states(mismatch.states,1,invalid),"nonvalue authority type refuses before publication")
	for value: Dictionary in held:
		value.bridge.shutdown()
		value.viewport.queue_free()
	await process_frame
	print("GCR_REST_BRIDGE ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"scope":"synthetic versioned receipts; actual Rapier correction/wrench/energy only; zero native candidate trajectories"}))
	quit(0 if failures.is_empty() else 1)
