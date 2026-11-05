extends "res://tests/test_sol_active_normal_policy.gd"

func trace_refused(world: Variant, mode: String, label: String) -> void:
	var physical: String = world.get_physical_state_hash()
	var revision: int = world.get_revision()
	check(not world.diagnostic_set_workbench_solver_trace(mode),label)
	check(world.get_physical_state_hash()==physical and world.get_revision()==revision,label+" leaves authority unchanged")

func run() -> void:
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
	var session := Session.new();viewport.add_child(session)
	check(session.configure([actor("reference_barrel",0,"LA-SELECTIVE",256),actor("kestrel",1,"LA-SELECTIVE",256),actor("scooper",2,"LA-SELECTIVE",256)],viewport.world_2d.space,1),"three actual authored owners")
	for body: RigidBody2D in session.bodies(): body.gravity_scale=0
	var drives: Array[bool] = [false,false,false]
	session.bridge.step();native_sample=session.bridge.pack_sample(drives);initial=session.bridge.pack_body_states()
	native_preparer=ClassDB.instantiate(&"CyberDemoBridge")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	trace_refused(world,"batch64-001","ordinary missing workbench")
	replace(world);trace_refused(world,"off","ordinary committed World")
	check(world.diagnostic_reset({"workers":1,"telemetry":false}),"fresh diagnostic reset")
	trace_refused(world,"batch64-001","reset retires workbench")
	var pending: int = token(world);check(pending>0,"pending constructor")
	trace_refused(world,"batch64-001","uncommitted constructor")
	check(native_preparer.commit_liquid_world(world,pending),"pending retained")
	trace_refused(world,"unknown","unknown selector atomic")
	trace_refused(world,"","empty selector atomic")
	var packet: Dictionary = {}
	var frozen_packets: Array[String] = []
	for trace_first: bool in [false,true]:
		replace(world)
		if trace_first:
			check(world.diagnostic_set_workbench_solver_trace("batch64-001"),"trace first")
			check(world.diagnostic_set_workbench_normal_policy("active-normal-001"),"normal after trace")
		else:
			check(world.diagnostic_set_workbench_normal_policy("original"),"normal first")
			check(world.diagnostic_set_workbench_solver_trace("batch64-001"),"trace after normal")
		trace_refused(world,"off","one-use enabled selection")
		check(prepare_sample(world) and world.simulation_tick(),"actual native frame")
		packet = world.workbench_coupling_results()
		check(packet.valid and packet.rows.size()==3 and packet.solver_trace_mode=="batch64-001" and packet.solver_trace_locked,"actual three-owner trace packet")
		for row: Dictionary in packet.rows:
			var capture: Dictionary = row.solver_trace
			check(capture.owner_id==row.id and capture.instance_id==row.instance_id and capture.generation==row.generation and capture.sample==row.sample,"owner-bound capture")
			check(capture.complete and capture.export_complete and capture.batch_count==8 and capture.total_nodes==row.nodes,"complete including empty solve")
			check(capture.body_f64==row.passive_state_f64 and capture.body_f64le.length()==128,"exact body readback")
			check(capture.nodes_f64.size()==6*capture.captured_nodes and capture.steps_f64.size()==88*capture.captured_nodes,"bounded lengths")
		var held: Dictionary = packet.duplicate(true)
		var frozen: String = JSON.stringify(plain(held))
		world.workbench_coupling_results()
		replace(world)
		check(JSON.stringify(plain(held))==frozen,"held captures immutable through reuse/replacement")
		observations.append(held)
		frozen_packets.append(frozen)
	packet = world.workbench_coupling_results()
	check(packet.solver_trace_mode=="off" and packet.solver_trace_storage_bytes==0,"replacement retires scratch")
	trace_refused(world,"batch64-001","empty getter locks trace")
	replace(world);check(world.diagnostic_set_workbench_solver_trace("off"),"explicit off accepted")
	trace_refused(world,"batch64-001","off consumes own latch")
	check(world.diagnostic_set_workbench_normal_policy("active-normal-001"),"off does not consume normal selector")
	for action: String in ["prepare","invalid-prepare","tick","legacy-prepare","legacy-getter"]:
		replace(world)
		if action=="prepare": check(prepare_sample(world),"coupling prepare")
		elif action=="invalid-prepare": check(not world.prepare_workbench_coupling(PackedFloat64Array(),PackedFloat64Array(),[],0,0,true),"failed prepare")
		elif action=="tick": check(world.simulation_tick(),"unprepared tick")
		elif action=="legacy-prepare": world.prepare_rigid_body_coupling(initial,true)
		else: check(world.rigid_body_results().is_empty(),"legacy result refusal")
		trace_refused(world,"batch64-001",action+" locks before refusal")
	replace(world);pending=token(world);check(pending>0,"pending replacement")
	trace_refused(world,"batch64-001","pending blocks admission")
	check(native_preparer.commit_liquid_world(world,pending),"replacement retained")
	for mode: String in ["LA","LA-EVENT-OFF","RFT"]:
		replace(world,mode);trace_refused(world,"batch64-001","separate response "+mode)
	check(world.diagnostic_reset({"workers":4,"telemetry":false}),"reset retires trace")
	trace_refused(world,"batch64-001","no workbench after reset")
	world=null;native_preparer=null;session.close();viewport.free()
	check(not session.active() and session.bodies().is_empty(),"teardown")
	for index: int in frozen_packets.size():check(JSON.stringify(plain(observations[index]))==frozen_packets[index],"held captures after teardown")
	var output: String = OS.get_environment("SOL_TRACE_POLICY_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE);check(file!=null,"evidence writable")
		if file!=null: file.store_string(JSON.stringify(plain({"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"checks":checks,"failures":failures,"observations":observations})));file.close()
	print("SOL_NODE_TRACE_POLICY checks=",checks," failures=",failures.size());quit(int(not failures.is_empty()))
