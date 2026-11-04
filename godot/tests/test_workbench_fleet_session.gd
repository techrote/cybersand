extends SceneTree

const Session = preload("res://scripts/physical_actor_session.gd")
const Prepared = preload("res://scripts/prepared_physical_session.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
var failures: int = 0
var checks: int = 0
var host: Node2D
var session: CyberPhysicalActorSession


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("Workbench fleet: " + message)
		failures += 1


func actor(model: String, identity: int, position: Vector2) -> Dictionary:
	return {"model":model,"instance_id":identity,"position":position,"canvas_extent":Vector2i(2048,2048),
		"producer":"passive" if model == "reference_barrel" else "human",
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
			"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}


func instantiate(definitions: Array, epoch: int) -> bool:
	if session != null: session.free()
	session = Session.new()
	host.add_child(session)
	return session.configure(definitions,host.get_world_2d().space,epoch)


func packet_for(sample: Dictionary) -> Dictionary:
	var rows: Array = []
	for member: Dictionary in sample.bodies:
		var offset: int = (member.first_proxy-1)*17
		rows.append({"id":member.id, "generation":member.generation,"instance_id":member.instance_id,"budget":member.budget,
			"sample":int(sample.states[offset+10]),"com":Vector2(sample.states[offset+12],sample.states[offset+13]),
			"mass":sample.states[offset+9],"inertia":sample.states[offset+11],"gravity":member.gravity,"external_drive":member.external_drive,
			"impulse":Vector2(0.03,0.01)*member.id,"torque":0.002,"correction":Vector2.ZERO})
	return {"valid":true,"epoch":sample.epoch,"session":sample.session,"response":"LA-SELECTIVE","rows":rows}


func run() -> void:
	host = Node2D.new()
	root.add_child(host)
	var fleet: Array = []
	for index: int in range(Fleet.count()):
		fleet.append(actor(Fleet.stable_id(index),101+index,Vector2(1100+index*100,1300)))
	check(fleet.size() == 8 and instantiate(fleet,5), "all eight authored rigs in one actual space")
	if not session.active(): quit(1); return
	fleet.append(actor("reference_barrel",300,Vector2(300,200)))
	check(not Session.valid_definitions(fleet),"ninth actor refuses")
	fleet.pop_back()
	for index: int in range(Fleet.count()):
		var state: Dictionary = session.workbench_actor_state(101+index)
		var record: Dictionary = Fleet.authoring_record(index)
		check(state.model == record.id and state.definition_hash == Fleet.definition_hash(index),"stable model and authoring hash")
		check(is_equal_approx(state.mass,float(record.physics.mass)) and is_equal_approx(state.gravity,float(record.physics.gravity)),
			"actual authored mass/gravity " + str(record.id))
		check(is_equal_approx(state.force_limit,float(record.flight.force_limit)) and is_equal_approx(state.torque_limit,float(record.flight.torque_limit)),
			"actual authored limits")
		check(session.submit_workbench_action(101+index,{"move":Vector2(0.4,-1),"trim":0.4,"primary":true},
			{"q":true,"e":false,"s":true,"boost":true},true),"per-instance command")
	session.advance(1.0/60.0)
	var sample: Dictionary = session.pack_workbench_sample()
	check(sample.bodies.size()==8 and sample.states.size()==12*17,"five U proxies and seven single hulls")
	for index: int in range(Fleet.count()):
		var state: Dictionary = session.workbench_actor_state(101+index)
		check(state.controller.applied_force.length()>0 and state.controller.applied_force.length()<=state.force_limit*2.00001,"authored boosted controller "+state.model)
		check(absf(state.controller.applied_torque)<=state.torque_limit+0.00001,"per-body torque ceiling")
	var kestrel_powder: bool = false
	for nozzle: Dictionary in sample.emitters:
		if nozzle.instance_id == 103 and nozzle.nozzle=="s-rear" and nozzle.material==26: kestrel_powder = true
	check(kestrel_powder, "Kestrel leased S powder stream")
	session.bridge.step()
	session.complete_step()
	check(session.tick==1,"actual Rapier integration")
	var one := actor("scooper",30,Vector2(1450,1100))
	one.workbench_options.mass_multiplier=3.5
	one.workbench_options.inertia_multiplier=2.0
	one.workbench_options.budget=80.0
	var two := actor("needle",90,Vector2(300,1100))
	two.workbench_options.budget=5.0
	var barrel := actor("reference_barrel",20,Vector2(1452,1050))
	var mixed: Array = [two,barrel,one]
	check(instantiate(mixed,6),"two flyers and actual passive barrel")
	if not session.active(): quit(1); return
	check(not session.submit_workbench_action(20,{"move":Vector2.RIGHT},{"q":false,"e":false,"s":false,"boost":false},false),"passive command refused")
	check(session.submit_workbench_action(30,{"primary":true},{"q":false,"e":false,"s":false,"boost":true},false),"pilot Scooper independent of order")
	session.advance(1.0/60.0)
	sample=session.pack_workbench_sample()
	check(sample.bodies[2].budget==80 and sample.bodies[2].count==5 and sample.bodies[0].budget==5 and sample.bodies[1].gravity>90,"per-body geometry, budget, actual gravity")
	check(sample.bodies[2].external_drive and not sample.bodies[0].external_drive and not sample.bodies[1].external_drive,"per-body actuation")
	var packet: Dictionary = packet_for(sample)
	var stale: Dictionary = packet.duplicate(true)
	stale.rows[1].instance_id=30
	check(session.apply_workbench_results(1,stale)==0 and session.bridge.last_application.refusal=="identity","wrong identity refused atomically")
	packet.rows.reverse()
	check(session.apply_workbench_results(2,packet)==3,"reordered physical wrenches each applied once")
	check(session.apply_workbench_results(3,packet)==0 and not session.bridge.last_application.accepted,"duplicate sample refused")
	session.cancel_input(2,6,&"human")
	check(not session._rigs[2].review_boost_held() and session.pack_workbench_sample().emitters.is_empty(),"revoke booster and emission")
	session.pack_workbench_sample()
	check(session.apply_workbench_results(4,packet)==0,"delayed sample dropped")
	check(instantiate([barrel,two],7),"replace/reorder after retirement")
	check(session.apply_workbench_results(5,packet)==0 and session.bridge.last_application.refusal=="owner_or_response","retired owner has no authority")
	mixed[2]["retained_motion"] = {"rotation":0.45,"linear_velocity":Vector2(9,-6),"angular_velocity":-0.25}
	var provisional := Prepared.new()
	check(provisional.prepare(host,mixed,8),"prepared frozen Rapier graph supports compound priming")
	if provisional.session != null:
		var initial: Dictionary = provisional.initial_workbench_sample()
		check(initial.bodies.size()==3 and initial.states.size()==7*17 and initial.emitters.is_empty(),"frozen owner publishes complete immutable mask")
		var state: Dictionary = provisional.session.workbench_actor_state(30)
		check(is_equal_approx(state.rotation,0.45) and state.linear_velocity == Vector2.ZERO,"retained attitude frozen before acceptance")
		check(is_equal_approx(initial.states[2*17+3],0.45),"prepared native mask uses retained U angle")
		provisional.adopt()
		state = provisional.session.workbench_actor_state(30)
		check(is_equal_approx(state.rotation,0.45) and state.linear_velocity == Vector2(9,-6) and is_equal_approx(state.angular_velocity,-0.25),"adoption restores retained velocities")
		provisional.close()
	session.free()
	host.free()
	await process_frame
	await process_frame
	print("WORKBENCH_FLEET checks=",checks," failures=",failures)
	quit(int(failures>0))
