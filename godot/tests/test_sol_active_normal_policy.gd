extends "res://tests/test_la_physical_campaign.gd"

const PolicyProbe = preload("res://tests/support/sol_active_normal_policy.gd")

var native_preparer: Variant
var native_sample: Dictionary
var initial: PackedFloat32Array
var observations: Array = []

func token(world: Variant, mode: String = "LA-SELECTIVE") -> int:
	return native_preparer.prepare_liquid_world(world,PackedInt32Array(),checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),native_preparer.default_liquid_policy(),
		{"workbench_extent":Vector2i(256,256),"workbench_response":mode,"workbench_sample":native_sample,
		"region":PackedInt32Array([0,0,256,256]),"seed":0,"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":initial,"simulation_window_enabled":false})

func replace(world: Variant, mode: String = "LA-SELECTIVE") -> void:
	var prepared: int = token(world,mode)
	check(prepared>0 and native_preparer.commit_liquid_world(world,prepared),"fresh prepared owner "+mode)

func prepare_sample(world: Variant) -> bool:
	return world.prepare_workbench_coupling(native_sample.states,native_sample.geometry,native_sample.bodies,
		native_sample.session,native_sample.epoch,true)

func refused(world: Variant, policy: String, label: String) -> void:
	var before: String = world.get_physical_state_hash()
	var revision: int = world.get_revision()
	check(not world.diagnostic_set_workbench_normal_policy(policy),label)
	check(world.get_physical_state_hash()==before and world.get_revision()==revision,label+" leaves authority unchanged")

func run() -> void:
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
	var session := Session.new();viewport.add_child(session)
	check(session.configure([actor("reference_barrel",0,"LA-SELECTIVE",256)],viewport.world_2d.space,1),"actual authored owner")
	for body: RigidBody2D in session.bodies(): body.gravity_scale=0
	var neutral_drives: Array[bool] = [false]
	session.bridge.step();native_sample=session.bridge.pack_sample(neutral_drives);initial=session.bridge.pack_body_states()
	native_preparer=ClassDB.instantiate(&"CyberDemoBridge")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	refused(world,"active-normal-001","ordinary missing workbench refuses")
	replace(world);refused(world,"active-normal-001","ordinary committed World refuses")
	check(world.diagnostic_reset({"workers":1,"telemetry":false}),"fresh diagnostic owner")
	refused(world,"active-normal-001","reset retired workbench")
	var pending: int = token(world)
	check(pending>0,"pending initial constructor")
	refused(world,"active-normal-001","uncommitted World refuses")
	check(native_preparer.commit_liquid_world(world,pending),"refusal retained pending constructor")
	refused(world,"unknown","unknown selection atomic");refused(world,"","empty selection atomic")
	check(world.diagnostic_set_workbench_normal_policy("active-normal-001"),"unknown requests leave latch available")
	refused(world,"original","successful choice is one-use")
	var packet: Dictionary = world.workbench_coupling_results()
	check(packet.normal_policy=="active-normal-001" and packet.normal_policy_locked and not packet.valid and packet.rows.is_empty(),"invalid empty result reports actual policy")
	observations.append(packet)
	replace(world);packet=world.workbench_coupling_results()
	check(packet.normal_policy=="original","replacement retires candidate")
	refused(world,"active-normal-001","empty getter consumes latch")
	replace(world);check(world.diagnostic_set_workbench_normal_policy("original"),"explicit original accepted")
	packet=world.workbench_coupling_results();check(packet.normal_policy=="original","explicit original readback")
	refused(world,"active-normal-001","explicit original consumes latch")
	replace(world);check(prepare_sample(world),"successful coupling preparation")
	refused(world,"active-normal-001","prepare locks before tick")
	var duplicate: Array = native_sample.bodies.duplicate(true);duplicate.append(duplicate[0].duplicate(true))
	check(not world.prepare_workbench_coupling(native_sample.states,native_sample.geometry,duplicate,native_sample.session,native_sample.epoch,true),"duplicate owner refused")
	refused(world,"active-normal-001","invalidated sample does not reopen latch")
	packet=world.workbench_coupling_results();check(not packet.valid and packet.normal_policy=="original","invalid packet retains identity")
	replace(world)
	check(not world.prepare_workbench_coupling(PackedFloat64Array(),PackedFloat64Array(),[],0,0,true),"invalid first coupling attempt")
	refused(world,"active-normal-001","failed first prepare locks")
	replace(world);check(world.simulation_tick(),"tick before explicit coupling")
	refused(world,"active-normal-001","tick consumes latch")
	replace(world);world.prepare_rigid_body_coupling(initial,true)
	refused(world,"active-normal-001","legacy prepare refusal consumes latch")
	replace(world);check(world.rigid_body_results().is_empty(),"legacy getter refuses workbench")
	refused(world,"active-normal-001","legacy getter refusal consumes latch")
	replace(world);pending=token(world);check(pending>0,"pending replacement")
	refused(world,"active-normal-001","pending replacement blocks selection")
	check(native_preparer.commit_liquid_world(world,pending),"replacement commit retained")
	check(world.diagnostic_set_workbench_normal_policy("active-normal-001"),"replacement latch fresh")
	check(prepare_sample(world) and world.simulation_tick(),"candidate actual native solve")
	packet=world.workbench_coupling_results()
	check(packet.valid and packet.normal_policy=="active-normal-001" and packet.rows.size()==1,"native candidate packet")
	for row: Dictionary in packet.rows:
		check(row.normal_policy==packet.normal_policy and row.passive_state_f64.size()==8 and row.passive_raw_wrench_f64.size()==3,"scalar64 diagnostics")
	var held: Dictionary = packet.duplicate(true)
	observations.append(packet);refused(world,"original","live candidate cannot switch")
	for mode: String in ["LA","LA-EVENT-OFF","RFT"]:
		replace(world,mode);refused(world,"active-normal-001","incompatible mode "+mode)
		packet=world.workbench_coupling_results();check(packet.response==mode and packet.normal_policy=="original","separate control "+mode)
	check(world.diagnostic_reset({"workers":4,"telemetry":false}),"reset retires selected state")
	refused(world,"active-normal-001","reset has no workbench")
	replace(world);check(world.diagnostic_set_workbench_normal_policy("active-normal-001"),"fresh reset replay")
	# Existing capacity setting supplies a real failed owner without adding fault APIs.
	# This owner is non-diagnostic; failed-world and diagnostic guards overlap here.
	var previous_capacity: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity",null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1)
	var failed_world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",previous_capacity)
	replace(failed_world)
	failed_world.emit_disc(40,40,4,2,0);failed_world.emit_disc(220,40,4,14,0)
	check(not failed_world.simulation_tick() and failed_world.has_failed(),"real native capacity quarantine")
	check(failed_world.get_last_tick_error().contains("active scheduling-core capacity exhausted"),"actual failure reason")
	var failure_count: int = failed_world.get_tick_failure_count()
	refused(failed_world,"active-normal-001","failed owner refuses")
	check(failed_world.workbench_coupling_results().is_empty() and failed_world.get_tick_failure_count()==failure_count,"failed response unavailable, failure count unchanged")
	observations.append({"failed_world":true,"reason":failed_world.get_last_tick_error(),"failure_count":failure_count,"diagnostic_guard_also_false":true})
	var good: Dictionary = {"response":"LA-SELECTIVE","normal_policy":"original","normal_policy_locked":true,"rows":[]}
	check(PolicyProbe.matches(good,"LA-SELECTIVE","original"),"empty original identity helper")
	for bad: Dictionary in [{},{"response":"LA-SELECTIVE","normal_policy":"original","normal_policy_locked":false,"rows":[]},
		{"response":"LA-SELECTIVE","normal_policy":"active-normal-001","normal_policy_locked":true,"rows":[]},
		{"response":"LA-SELECTIVE","normal_policy":"original","normal_policy_locked":true,"rows":[{"normal_policy":"active-normal-001"}]},
		{"response":"LA-SELECTIVE","normal_policy":"original","normal_policy_locked":true,"rows":[1]},
		{"response":"LA-SELECTIVE","normal_policy":"original","normal_policy_locked":true,"rows":1}]:
		check(not PolicyProbe.matches(bad,"LA-SELECTIVE","original"),"malformed/misaligned native policy refused")
	var body_ids: Array[int] = []
	for body: RigidBody2D in session.bodies(): body_ids.append(body.get_instance_id())
	var retired_bridge: Variant = session.bridge
	world=null;failed_world=null;native_preparer=null;session.close()
	check(not session.active() and session.bodies().is_empty(),"teardown retires body roster")
	for identity: int in body_ids: check(not is_instance_id_valid(identity),"physical owner destroyed")
	check(retired_bridge.apply_packet(999,held)==0 and retired_bridge.last_application.refusal=="retired","held valid candidate packet cannot reach retired RIDs")
	observations.append(retired_bridge.last_application.duplicate(true));viewport.free()
	var output: String = OS.get_environment("SOL_POLICY_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		check(file!=null,"retained evidence path opened")
		if file!=null:
			file.store_string(JSON.stringify(plain({"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"checks":checks,"failures":failures,"observations":observations})));file.close()
	print("SOL_ACTIVE_NORMAL_POLICY checks=",checks," failures=",failures.size())
	quit(int(not failures.is_empty()))
