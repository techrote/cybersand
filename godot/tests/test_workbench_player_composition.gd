extends "res://tests/test_workbench_player_roster.gd"

class FocusCompositionHost extends "res://scripts/main.gd":
	var focus_allowed := true
	func _actor_window_has_focus() -> bool: return focus_allowed

const EQUIPPED: int = 4
var metrics := {}

func equipment() -> Dictionary:
	return host.workbench_equipment_observation(EQUIPPED)

# Main predicts regeneration per Rapier step. Custody belongs to the material
# owner's ledger, so compare that copied inventory with exact identity fences.
func inventory() -> Dictionary:
	var session = host.physical_actor_session
	var feedback: Dictionary = host.latest_snapshot.physical_usables
	if feedback.get("run_id") != session.run_id or feedback.get("epoch") != session.epoch: return {}
	var slot: int = session.slot_for_instance(EQUIPPED)
	var current := equipment()
	for row: Dictionary in feedback.get("actors",[]):
		if row.get("actor_id") != slot: continue
		for key_name: String in ["instance_id","equipment_epoch","usable_index","body_id"]:
			if row.get(key_name) != current.get(key_name): return {}
		return {"charge":row.charge,"cooldown":row.cooldown,"tick":feedback.tick,"frame_tick":feedback.frame_tick}
	return {}

func held_part_motion() -> Dictionary:
	var session = host.physical_actor_session
	var slot: int = session.slot_for_instance(EQUIPPED)
	var index: int = int(equipment().body_id)-int(session._body_offsets[slot])-1
	return session.export_workbench_motion(EQUIPPED).parts[index].duplicate(true)

func acknowledged(label: String) -> bool:
	var serial: int = int(ui._pending_request_serial)
	if not await wait_for(ready,label): return false
	var actual: int = int(host.tower_context.get("scenario_request_serial",-1))
	var applied: bool = bool(host.tower_context.get("scenario_request_applied",false))
	metrics[label] = {"requested":serial,"actual":actual,"applied":applied,"error":host.microscenario_error}
	return check(serial > 0 and actual == serial and applied,label+" matching native acknowledgement / "+host.microscenario_error)

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusCompositionHost)
	root.add_child(host); current_scene = host; ui = host.shared_workbench
	if await wait_for(ready,"blank installed"):
		await compose()
		if not host.simulation_worker.has_failed(): await native_only()
	for code: Key in [KEY_M,KEY_N,KEY_U,KEY_D,KEY_SPACE,KEY_SHIFT,KEY_CTRL]: key(code,false)
	host.queue_free(); await process_frame; await process_frame
	print("WORKBENCH_PLAYER_COMPOSITION "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)

func compose() -> void:
	var models: Array[String] = ["scooper","stuntbuggy","trialsbike","acrobat","arcadelander","jetbarrel","dryswarm","liquidswarm"]
	var points := [Vector2(180,200),Vector2(350,200),Vector2(520,200),Vector2(1150,200),Vector2(700,200),Vector2(900,200),Vector2(1280,340),Vector2(1400,340)]
	var start := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(1536,512))
	for index: int in models.size(): start.actors.append(Setup.instance(models[index],index+1,points[index]))
	start.next_id = 9; start.selected = EQUIPPED
	if not check(ui.apply(start),"submit mixed1536x512 canvas"): return
	if not await acknowledged("mixed composition acknowledged"): return
	check(host.physical_actor_session._definitions.size() == 6 and host.physical_actor_session.bodies().size() > 8,"articulation coexists beyond eight actual bodies")
	check(ui.pilot_slot == 3 and ui.body_state(EQUIPPED).position.x > 1024,"selected nonfirst Acrobat is beyond historical effect bounds")
	check(host._playable_course_gamepad_active(),"shared first-pad event bridge admits selected mechanical player")
	var frame: Dictionary = host.physical_actor_session.equipment_frame()
	var eq := equipment()
	var aliases: Array = []
	for actor_frame: Dictionary in frame.actors:
		if actor_frame.actor_id != ui.pilot_slot: continue
		for part: Dictionary in actor_frame.parts:
			if part.body_id == eq.body_id: aliases = Array(part.get("proxy_ids",[]))
	check(not aliases.is_empty() and aliases[0] != eq.body_id,"compound predecessor supplies explicit shifted mask alias")
	var seed: Dictionary = host.tower_context.get("workbench_material_seed",{})
	check(seed.get("players",[]).size() == 2,"two material players seeded through same prepared World")
	for row: Dictionary in seed.get("players",[]): check(row.inserted == 256 and row.refused == 0,"actual native seed receipt256")
	ui._usable.select(1); ui._usable_power.set_value_no_signal(0.6)
	if not check(ui.request_usable(),"paused live Sand Scatter selection admitted"): return
	check(not ui._pending_usable.is_empty() and ui.actor(ui.applied,EQUIPPED).usable_index == -1,"paused submission is not an equipment acknowledgement")
	check(ui.select_instance(1),"select peer while retool is pending")
	ui._fields.mass_multiplier.value = 1.05
	if not check(ui.apply_settings(),"peer rebuild during paused pending retool"): return
	if not await acknowledged("pending retool peer acknowledged"): return
	check(ui.select_instance(EQUIPPED) and ui.usable_selection().usable_index == 0 and is_equal_approx(ui.usable_selection().power,0.6),"pending retool index/power survives retained peer rebuild")
	check(ui.toggle_pause(),"play pending selection")
	if not await wait_for(func(): return equipment().get("usable_index",-1) == 0 and ui._pending_usable.is_empty(),"live retool acknowledged"): return
	check(ui.actor(ui.applied,EQUIPPED).usable_index == 0 and is_equal_approx(ui.actor(ui.applied,EQUIPPED).usable_power,0.6),"acknowledged retool remains the authored choice")
	if not await wait_for(func(): return not host._actor_input_rearm,"neutral controller rearmed"): return
	var uses: int = int(equipment().get("accepted_uses",0))
	key(KEY_M,true); key(KEY_M,false)
	if not await wait_for(func(): return int(equipment().get("accepted_uses",0)) > uses,"short M use acknowledged"): return
	eq = equipment()
	check(int(eq.last_receipt.get("changed_cells",0)) > 0,"real powder insertion outside1024 boundary")
	check(float(eq.charge) < 100.0 and eq.last_receipt.get("accepted",false),"worker charge/readback consumed successful use")
	metrics["tool"] = eq.last_receipt.duplicate(true)
	if not await pause_clean(): return
	await retention()

func pause_clean() -> bool:
	if not host.paused and not check(ui.toggle_pause(),"pause actual session"): return false
	return await wait_for(func(): return host.physical_actor_session._suspended and host.latest_snapshot.paused and not equipment().get("pending",false) and not inventory().is_empty(),"paused published equipment custody quiescent")

func retention() -> void:
	var before := equipment()
	var ledger_before := inventory()
	var slot: int = host.physical_actor_session.slot_for_instance(EQUIPPED)
	var part: RigidBody2D = host.physical_actor_session._rigs[slot].bodies()[1]
	var transform: Transform2D = PhysicsServer2D.body_get_state(part.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	transform = Transform2D(transform.get_rotation()+0.2,transform.origin+Vector2(0.5,0.5))
	PhysicsServer2D.body_set_state(part.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,transform)
	PhysicsServer2D.body_set_state(part.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(1.25,-0.75))
	PhysicsServer2D.body_set_state(part.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,0.15)
	var motion: Dictionary = host.physical_actor_session.export_workbench_motion(EQUIPPED)
	var profile: Dictionary = ui._profile("acrobat")
	profile.options.mass_multiplier = 1.1
	if not check(ui.apply_flyer_profile(profile),"rebuild player settings with live equipment custody"): return
	if not await acknowledged("player tuning retained"): return
	var ledger_after := inventory()
	check(not ledger_after.is_empty() and ledger_after.charge == ledger_before.charge and ledger_after.cooldown == ledger_before.cooldown and equipment().accepted_uses == before.accepted_uses,"settings retain authoritative charge/cooldown and use history")
	var after: Dictionary = host.physical_actor_session.export_workbench_motion(EQUIPPED)
	check(after.parts.size() == motion.parts.size() and Vector2(after.parts[1].position).is_equal_approx(motion.parts[1].position) and is_equal_approx(after.parts[1].rotation,motion.parts[1].rotation),"articulated part pose survives setting replacement")
	check(Vector2(after.parts[1].linear_velocity).is_equal_approx(motion.parts[1].linear_velocity) and is_equal_approx(after.parts[1].angular_velocity,motion.parts[1].angular_velocity),"articulated part momentum state survives replacement")
	metrics["retained_seed"] = host.tower_context.get("workbench_material_seed",{}).duplicate(true)
	metrics["retained_field"] = host.workbench_material_player_state(7).duplicate(true)
	check(host.tower_context.get("workbench_material_seed",{}).get("players",[]).is_empty(),"retained rebuild does not reseed native players")
	if not check(ui.toggle_pause(),"resume drop test"): return
	if not await wait_for(func(): return not host._actor_input_rearm,"drop controls rearmed"): return
	key(KEY_N,true); key(KEY_N,false)
	if not await wait_for(func(): return equipment().get("state") == "released","short N releases actual chassis"): return
	if not await pause_clean(): return
	before = equipment()
	ledger_before = inventory()
	metrics["peer_before"] = {"display_charge":before.charge,"state":before.state,"inventory":ledger_before}
	ui.select_instance(1)
	ui._fields.mass_multiplier.value = 1.2
	if not check(ui.apply_settings(),"peer settings keep released equipment"): return
	if not await acknowledged("peer replacement acknowledged"): return
	ledger_after = inventory()
	metrics["peer_after"] = {"display_charge":equipment().charge,"state":equipment().state,"inventory":ledger_after}
	check(equipment().state == "released" and not ledger_after.is_empty() and ledger_after.charge == ledger_before.charge and ledger_after.cooldown == ledger_before.cooldown,"peer rebuild preserves release and authoritative inventory")
	ui.select_instance(EQUIPPED)
	check(not host.workbench_select_usable(EQUIPPED,1,1.0),"released chassis refuses remote retool")
	var loose := held_part_motion()
	var original_spawn := Setup.point(ui.actor(ui.applied,EQUIPPED).spawn)
	ui._position[0].value = original_spawn.x-64.0; ui._position[1].value = original_spawn.y
	check(ui.save_spawn(),"author far reset spawn while gear is released")
	if not check(ui.reset_selected(),"reset controlled assembly while retaining dropped object"): return
	if not await acknowledged("released-gear reset acknowledged"): return
	check(Vector2(ui.body_state(EQUIPPED).position).is_equal_approx(original_spawn-Vector2(64,0)),"controlled root returns to authored reset spawn")
	var retained := held_part_motion()
	check(equipment().state == "released" and Vector2(retained.position).is_equal_approx(loose.position),"actor reset does not remotely teleport or attach dropped gear")
	check(Vector2(retained.linear_velocity).is_equal_approx(loose.linear_velocity) and is_equal_approx(retained.angular_velocity,loose.angular_velocity),"dropped object momentum survives actor reset")
	ui._position[0].value = original_spawn.x; ui._position[1].value = original_spawn.y
	check(ui.save_spawn(),"restore actor spawn near dropped gear")
	if not check(ui.reset_selected(),"return controlled assembly for physical pickup"): return
	if not await acknowledged("nearby actor reset acknowledged"): return
	if not check(ui.toggle_pause(),"resume pickup test"): return
	if not await wait_for(func(): return not host._actor_input_rearm,"pickup controls rearmed"): return
	key(KEY_U,true); key(KEY_U,false)
	if not await wait_for(func(): return equipment().get("state") == "held","short U reattaches nearby actual chassis"): return
	await pause_clean()
	before = equipment()
	ledger_before = inventory()
	var policy := PackedInt32Array()
	for option: Dictionary in ui._liquids.bridge.liquid_policy_assignment_choices(PackedInt32Array(ui.applied.liquid_policy),CyberCellWorld.WATER):
		if option.accepted and option.family == "inertial_cellular_v1" and option.variant == "reference": policy = option.request; break
	if not check(not policy.is_empty(),"admitted IN Water comparison choice"): return
	ui._liquids.requested_policy = policy
	ui._liquids.normalize_water.set_pressed_no_signal(false)
	if not check(ui.apply_liquids(),"liquid reconstruction with equipment custody"): return
	if not await acknowledged("liquid reconstruction acknowledged"): return
	var family := ""
	for row: Dictionary in host.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(row.material) == CyberCellWorld.WATER: family = str(row.applied_family)
	check(family == "inertial_cellular_v1","actual IN Water family readback")
	metrics["water_policy"] = {"family":family,"radius":int(ui.applied.rule_radius)}
	ledger_after = inventory()
	check(equipment().state == "held" and not ledger_after.is_empty() and ledger_after.charge == ledger_before.charge and ledger_after.cooldown == ledger_before.cooldown and equipment().accepted_uses == before.accepted_uses,"liquid reconstruction retains authoritative equipment custody")
	for response: String in ["LA","LA-EVENT-OFF","RFT","LA-SELECTIVE"]:
		ui._requested_response = response
		if not check(ui.apply_settings(),"response comparison "+response): return
		if not await acknowledged("response acknowledged "+response): return
		check(host.tower_context.get("workbench_gcr",{}).get("response") == response,"native response readback "+response)
		ledger_after = inventory()
		check(equipment().state == "held" and not ledger_after.is_empty() and ledger_after.charge == ledger_before.charge and ledger_after.cooldown == ledger_before.cooldown,"response change retains authoritative charged chassis")

func native_only() -> void:
	var start := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(1536,512))
	start.rule_radius = int(ui.applied.rule_radius)
	start.actors = [Setup.instance("dryswarm",1,Vector2(1120,220)),Setup.instance("liquidswarm",2,Vector2(1360,220))]
	start.next_id = 3; start.selected = 1
	if not check(ui.apply(start),"native-only authored start"): return
	if not await acknowledged("native-only World acknowledged"): return
	check(host.physical_actor_session == null,"native-only players share worker World without physical session")
	var seed: Dictionary = host.tower_context.get("workbench_material_seed",{})
	check(seed.get("players",[]).size() == 2,"native-only seed receipt has two players")
	for row: Dictionary in seed.get("players",[]): check(row.inserted == 256 and row.refused == 0,"native-only256-cell seed")
	for id: int in [1,2]:
		check(ui.select_instance(id),"select native-only instance")
		check(ui.body_state(id).position.x > 1024 and ui.pilot_slot == -1,"native field beyond1024 has no fake rig")
		if not host.paused: ui.toggle_pause()
		var initial_epoch: int = host._physical_epoch
		if not check(ui.toggle_pause(),"start native field controls"): return
		if not await wait_for(func(): return not host._actor_input_rearm,"native controls rearmed"): return
		var before_sequence: int = int(ui.body_state(id).get("last_sequence",-1))
		key(KEY_D,true); key(KEY_SPACE,true)
		if not await wait_for(func(): return int(ui.body_state(id).get("last_sequence",-1)) > before_sequence and int(ui.body_state(id).get("field",{}).get("moved_cells",0)) > 0,"native field moves authoritative material"): return
		check(ui.body_state(id).get("field",{}).get("accepted",false),"native material API accepted selected field")
		var generation: int = int(ui.body_state(id).control_generation)
		host.focus_allowed = false; host._publish_workbench_keyboard()
		if not await wait_for(func(): return int(ui.body_state(id).control_generation) > generation and int(ui.body_state(id).lease_remaining) == 0,"focus loss retires native input"): return
		host.focus_allowed = true; host._publish_workbench_keyboard()
		check(host._actor_input_rearm,"held native controls cannot rearm on focus return")
		key(KEY_D,false); key(KEY_SPACE,false)
		host._publish_workbench_keyboard()
		if not host.paused: check(ui.toggle_pause(),"pause native field")
		if not check(ui.reset_selected(),"reset native field centre"): return
		var spawn: Vector2 = Setup.point(ui.actor(ui.applied,id).spawn)
		if not await wait_for(func(): return Vector2(ui.body_state(id).position).is_equal_approx(spawn),"native centre returns to saved spawn"): return
		check(host._physical_epoch == initial_epoch,"field reset does not replace World or seed again")
	check(host.tower_context.get("workbench_material_seed",{}) == seed,"native control/reset retains original explicit seed ledger")
	var previous_radius: int = int(ui.applied.rule_radius)
	if not check(ui.new_canvas(),"New blank with current liquid execution requirements"): return
	if not await acknowledged("New blank acknowledged"): return
	check(ui.applied.actors.is_empty() and int(ui.applied.rule_radius) >= previous_radius,"New blank clears roster without narrowing execution radius")
