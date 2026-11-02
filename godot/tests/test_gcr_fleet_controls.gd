extends SceneTree

# Actual synchronous fleet owner/API controls, not a physical acceptance matrix.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
var failures: int = 0
var checks: int = 0
func _init() -> void: call_deferred("_run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("Fleet controls: "+reason)
func options(budget: float=20.0, mass: float=1.0, inertia: float=1.0, response: String="LA") -> Dictionary:
	return {"response":response,"budget":budget,"mass_multiplier":mass,"inertia_multiplier":inertia}
func limits(thrust: Variant, torque: Variant, response: String="LA") -> Dictionary:
	var result: Dictionary = options(20,1,1,response)
	result["thrust_multiplier"]=thrust
	result["torque_multiplier"]=torque
	return result
func _check_actuator_limits(runtime) -> void:
	var previous = runtime._arena
	for key: String in ["thrust_multiplier","torque_multiplier"]:
		for value: Variant in [-.01,64.01,NAN,INF,true,"1"]:
			var invalid: Dictionary = limits(1.0,1.0)
			invalid[key]=value
			check(not runtime.configure_review_fleet(0,invalid),"invalid actuator limit refused: "+key)
			check(runtime._arena==previous and runtime.active(),"invalid actuator limit preserves live owner")
	for index: int in range(7):
		for factor: float in [0.0,.01,64.0]:
			var requested: Dictionary = limits(factor,factor)
			check(runtime.configure_review_fleet(index,requested),"fresh actuator ceiling controls")
			var arena = runtime._arena
			var rig = arena.session._rigs[0]
			var body: RigidBody2D = arena.session.bodies()[0]
			var force_cap: float = float(Fleet.ROWS[index][8])*factor
			var torque_cap: float = float(Fleet.ROWS[index][9])*factor
			check(is_equal_approx(float(rig._profile.fleet_force),force_cap) and is_equal_approx(float(rig._profile.fleet_torque),torque_cap),"actual copied profile ceilings scale")
			check(is_equal_approx(body.mass,float(Fleet.ROWS[index][1])) and is_equal_approx(body.inertia,body.mass*Vector2(Fleet.ROWS[index][0]).length_squared()/12.0),"actuator settings do not rewrite actual mass/inertia")
			# Moderate real backend motion exercises both braking and hoverboard
			# compensation, below the retained extreme-motion safety guards. No
			# world/Rapier step occurs here, isolating actual controller delivery
			# from gravity and the independent native contact wrench.
			PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(.4,Vector2(178,304)))
			PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(5,2))
			PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,1.0)
			var before_v: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var before_w: float = float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
			rig.advance({"move":Vector2(.7,-1),"aim":Vector2.UP,"trim":.8,"primary":true,"secondary":true,"auxiliary":true},1.0/60.0,true)
			var observation: Dictionary = rig._player_controller.observation()
			check(Vector2(observation.applied_force).length()<=force_cap+.00001 and absf(float(observation.applied_torque))<=torque_cap+.00001,"combined controller request respects actual ceilings")
			if factor==0.0:
				check(observation.applied_force==Vector2.ZERO and observation.applied_torque==0.0,"zero limits remove thrust, brake and hover/level requests")
				check(rig._last_impulse==Vector2.ZERO and rig._last_torque_impulse==0.0,"zero limits issue no actuator impulse")
				check(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)==before_v and float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))==before_w,"zero limits preserve real backend velocity during actuator delivery")
			else:
				check(Vector2(observation.applied_force).length()>0.0 and absf(float(observation.applied_torque))>0.0,"nonzero ceiling exercises actual controller requests")
			check(arena.reset() and arena.config.review_options==requested,"fresh reset preserves actuator ceilings")
			check(is_equal_approx(float(arena.session._rigs[0]._profile.fleet_force),force_cap) and is_equal_approx(float(arena.session._rigs[0]._profile.fleet_torque),torque_cap),"reset reconstructs actual actuator ceilings")
	check(runtime.configure_review_fleet(3,limits(0.0,0.0,"RFT")),"zero limits also accepted by retained reference")
	check(runtime._arena._world.get_gcr_admission_variant()=="R2","actuator limits do not change RFT material response")
func _run() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	await process_frame
	check(runtime.configure_review_fleet(0),"retained RFT default route")
	check(runtime._arena._world.get_gcr_admission_variant()=="R2","retained RFT identity")
	var invalid: Array = [options(4),options(81),options(20,64.01),options(20,.009),options(20,1,64.01),options(20,1,.009),options(40,1,1,"RFT"),options(20,1,1,"PRC"),options(NAN),options(20,INF)]
	var extra: Dictionary = options(); extra["sleep"]=true; invalid.append(extra)
	var missing: Dictionary = options(); missing.erase("mass_multiplier"); invalid.append(missing)
	var boolean: Dictionary = options(); boolean.mass_multiplier=true; invalid.append(boolean)
	var original = runtime._arena
	for value: Dictionary in invalid:
		check(not runtime.configure_review_fleet(0,value),"malformed/out-of-range options refused")
		check(runtime._arena==original and runtime.active(),"refusal retains live owner")
	var authored: Dictionary = Fleet.definition(6)
	authored.parts[0].mass=20.48
	check(not Rig.validate_definition(authored).is_empty(),"ordinary authored mass envelope unchanged")
	var malformed_session = preload("res://scripts/physical_actor_session.gd").new()
	root.add_child(malformed_session)
	check(not malformed_session.configure([42],RID(),1,0,options()),"malformed review definition refuses without a script exception")
	malformed_session.free()
	_check_actuator_limits(runtime)
	for fleet_index: int in range(7):
		for multipliers: Array in [[.01,.01],[1.0,1.0],[64.0,64.0]]:
			var admitted: bool = runtime.configure_review_fleet(fleet_index,options(40,multipliers[0],multipliers[1]))
			check(admitted,"fresh bounded mass/inertia override index=%d scales=%s error=%s" % [fleet_index,multipliers,runtime.last_error])
			if not admitted: continue
			var arena = runtime._arena
			var rig = arena.session._rigs[0]
			var body: RigidBody2D = arena.session.bodies()[0]
			var size: Vector2 = Fleet.ROWS[fleet_index][0]
			var expected_mass: float = float(Fleet.ROWS[fleet_index][1])*float(multipliers[0])
			var expected_inertia: float = body.mass*size.length_squared()/12.0*float(multipliers[1])
			check(arena.session.bodies().size()==1,"one body, no hidden equipment")
			check(is_equal_approx(body.mass,expected_mass),"actual scaled mass")
			check(is_equal_approx(body.inertia,expected_inertia),"actual independently scaled inertia")
			check(is_equal_approx(rig._total_mass,body.mass) and is_equal_approx(rig._assembly_inertia,body.inertia) and is_equal_approx(rig._inertias[0],body.inertia),"all rig caches match physical properties")
			check(rig._profile.fleet_force==Fleet.ROWS[fleet_index][8] and rig._profile.fleet_torque==Fleet.ROWS[fleet_index][9],"authored actuator ceilings retained")
			# First setup already packs the initial boundary exactly once. Read the
			# actual native sample's copied mass and I without making another pack.
			var receipt: Dictionary = arena._world.gcr_rest_receipt()
			check(receipt.mode=="control" and receipt.base_budget==40,"actual control budget readback")
			check(receipt.bodies.size()==1 and is_equal_approx(float(receipt.bodies[0].mass),body.mass) and is_equal_approx(float(receipt.bodies[0].inertia),body.inertia),"native packed sample uses actual m/I")
			check(not receipt.bodies[0].catch_applied,"no catch enabled")
	for budget: float in [20.0,40.0,80.0]:
		check(runtime.configure_review_fleet(6,options(budget,64,1)),"actual maximum-mass budget arm")
		var arena = runtime._arena
		check(arena._world.diagnostic_fill_rect(Vector2i(145,310),Vector2i(70,42),2),"bounded granular fixture")
		for tick: int in range(60):
			var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.UP,"primary":false,"secondary":false,"auxiliary":false,"trim":0.0}
			check(runtime.submit_action(action),"actual leased neutral command")
			runtime.step()
			check(not runtime.failed,"actual owner step healthy")
			var applied: Dictionary = arena.session.bridge.gcr_application_diagnostics()
			check(applied.get("accepted",false),"native control receipt admitted by one bridge")
			for body: Dictionary in applied.get("bodies",[]):
				check(int(body.get("physical_wrench_applications",0))<=1 and not body.get("catch_applied",false),"one accumulated wrench, no catch")
		var receipt: Dictionary = arena._world.gcr_rest_receipt()
		check(receipt.base_budget==budget and receipt.mode=="control","budget retained through live stepping")
		var diagnostics: Dictionary = arena._world.gcr_diagnostics()
		check(diagnostics.get("load_aware",false) and diagnostics.get("rest_mode","")=="control","actual native load-aware control law selected")
		check(diagnostics.get("bodies",[]).size()==1 and is_equal_approx(float(diagnostics.bodies[0].global_capacity),budget*maxf(1.0,arena.session.bodies()[0].mass)),"actual shared capacity follows budget and physical mass")
		check(arena.gcr_stats.responses>0 and arena.gcr_stats.granular_frames>0,"real granular response exercised")
		check(arena.reset(),"fresh arena reset retains admitted controls")
		check(arena.config.review_options==options(budget,64,1) and is_equal_approx(arena.session.bodies()[0].mass,.32*64),"reset retains selected scaling and law")
		check(arena._world.gcr_rest_receipt().base_budget==budget,"reset readback retains budget")
	check(runtime.configure_review_fleet(0,options(20,1,1,"RFT")),"explicit RFT reference")
	check(runtime._arena._world.get_gcr_admission_variant()=="R2","explicit reference keeps R2 admission")
	runtime.close()
	runtime.queue_free()
	await process_frame
	print("GCR_FLEET_CONTROLS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual native/Rapier developer controls; no human or production acceptance"}))
	quit(0 if failures==0 else 1)
