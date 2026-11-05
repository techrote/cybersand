extends "res://tests/support/sol_active_normal_authored.gd"

var observations: Array = []

func witness(variant: String, correction: Vector2, age: int) -> void:
	var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
	var session := Session.new();viewport.add_child(session)
	var definitions: Array = [actor("reference_barrel",0,"LA-SELECTIVE",512),actor("kestrel",1,"LA-SELECTIVE",512),actor("scooper",2,"LA-SELECTIVE",512)]
	var configured: bool = session.configure(definitions,viewport.world_2d.space,1)
	check(configured,"actual three-owner analytic session: "+str(session.last_error))
	if not configured:session.close();viewport.free();return
	check(not session.bridge.configure_application_variant("unknown"),"unknown application atomic")
	check(session.bridge.configure_application_variant(variant),"fresh named application "+variant)
	var bodies: Array[RigidBody2D] = session.bodies()
	for body: RigidBody2D in bodies:body.gravity_scale=0
	session.bridge.step()
	var velocities: Array[Vector2] = [Vector2(2,1),Vector2(-1,2),Vector2(0,-2)]
	var omega: Array[float] = [0.2,-0.3,0.0]
	for slot: int in bodies.size():
		PhysicsServer2D.body_set_state(bodies[slot].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocities[slot])
		PhysicsServer2D.body_set_state(bodies[slot].get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,omega[slot])
	var drives: Array[bool] = [false,false,false]
	var sample: Dictionary = session.bridge.pack_sample(drives)
	check(not session.bridge.configure_application_variant("baseline"),"first sample locks policy")
	var rows: Array = [];var before: Array = []
	for slot: int in bodies.size():
		var state: Dictionary = body_state(bodies[slot]);before.append(state)
		var d := PhysicsServer2D.body_get_direct_state(bodies[slot].get_rid())
		var member: Dictionary = sample.bodies[slot]
		var impulse: Vector2 = Vector2(-1,-0.2)*state.mass
		var serial: int = int(sample.states[(int(member.first_proxy)-1)*17+10])
		rows.append({"id":member.id,"instance_id":member.instance_id,"generation":member.generation,
			"budget":member.budget,"sample":serial,"mass":state.mass,"inertia":state.inertia,
			"gravity":member.gravity,"external_drive":false,"com":d.transform*d.center_of_mass_local,
			"impulse":impulse,"torque":0.3*state.mass,"correction":correction,
			"passive_impulse":impulse,"passive_torque":0.3*state.mass})
	var packet: Dictionary = {"session":sample.session,"epoch":sample.epoch,"response":"LA-SELECTIVE","valid":true,"rows":rows}
	for index: int in age:session.bridge.pack_sample(drives)
	var bad: Dictionary = packet.duplicate(true);bad.rows[2].generation+=1
	check(session.apply_workbench_results(1,bad)==0,"bad peer refuses whole batch before RID changes")
	for slot: int in bodies.size():check(body_state(bodies[slot])==before[slot],"atomic peer refusal leaves body unchanged")
	bad=packet.duplicate(true);bad.epoch+=1
	check(session.apply_workbench_results(1,bad)==0,"foreign epoch refused")
	var applied: int = session.apply_workbench_results(1,packet)
	var ledger: Dictionary = session.bridge.last_application.duplicate(true)
	if age>1:
		check(applied==0 and not ledger.accepted,"stale age cannot apply")
		for slot: int in bodies.size():check(body_state(bodies[slot])==before[slot],"stale observation leaves body unchanged")
	else:
		check(applied==3 and ledger.accepted and ledger.application_variant==variant,"three actual accepted applications")
		var scale: float = 1.0/(1.0+age*0.25)
		for slot: int in bodies.size():
			var row: Dictionary = rows[slot];var action: Dictionary = ledger.bodies[slot]
			var effective: Vector2 = correction if correction.length_squared()>0.000001 else Vector2.ZERO
			var expected: Vector2 = before[slot].velocity
			if variant=="baseline":
				if expected.x*effective.x<0:expected.x=0
				if expected.y*effective.y<0:expected.y=0
			else:check(action.get("linear_clip_policy")=="retain-linear-001","actual retain clip tag")
			var expected_torque: float = (float(row.torque)-effective.cross(row.impulse))*scale
			expected+=Vector2(row.impulse)*scale/before[slot].mass
			var after: Dictionary = body_state(bodies[slot])
			check(after.velocity.distance_to(expected)<=0.00001,"independent variant-aware real RID linear reconstruction")
			check(absf(after.omega-before[slot].omega-expected_torque/before[slot].inertia)<=0.00001,"same transported angular reconstruction")
			check(action.impulse==Vector2(row.impulse)*scale and action.torque==expected_torque,"unchanged native wrench/COM transport/age scale")
			check(after.pose.origin==before[slot].pose.origin+effective,"existing positional translation")
		check(session.apply_workbench_results(1,packet)==0 and session.bridge.last_application.refusal=="duplicate_snapshot","duplicate snapshot refused")
		check(session.apply_workbench_results(2,packet)==0 and not session.bridge.last_application.accepted,"same sample cannot reapply")
	observations.append(plain({"variant":variant,"correction":correction,"age":age,"before":before,"application":ledger,
		"fixture":"synthetic copied wrenches on actual authored RIDs; not native granular eligibility or recovery"}))
	var retired: Variant = session.bridge
	session.close();check(not session.active() and session.bodies().is_empty(),"teardown before viewport free")
	check(retired.apply_packet(3,packet)==0 and retired.last_application.refusal=="retired","retired RIDs cannot receive held packet")
	viewport.free()

func run() -> void:
	for variant: String in ["baseline","retain-linear-001"]:
		for correction: Vector2 in [Vector2.ZERO,Vector2(0,-0.1),Vector2(0.1,-0.1),Vector2(0,-0.0005)]:witness(variant,correction,0)
		witness(variant,Vector2(0,-0.1),1);witness(variant,Vector2(0,-0.1),2)
	for mode: String in ["LA","LA-EVENT-OFF","RFT"]:
		var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
		var session := Session.new();viewport.add_child(session)
		check(session.configure([actor("reference_barrel",0,mode,256)],viewport.world_2d.space,1),"separate control session")
		check(not session.bridge.configure_application_variant("retain-linear-001"),"nonselective application refuses "+mode)
		session.close();viewport.free()
	var output: String = OS.get_environment("SOL_CONTACT_API_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE);check(file!=null,"analytic evidence writable")
		if file!=null:file.store_string(JSON.stringify({"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"checks":checks,"failures":failures,"observations":observations}));file.close()
	print("SOL_CONTACT_APPLICATION_API checks=",checks," failures=",failures.size());quit(int(not failures.is_empty()))
