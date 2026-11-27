extends SceneTree

# Actual ordinary Workbench, native worker, prepared owner and patched Rapier.
# Headless mode substitutes only the OS window-focus predicate.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var wb: Control
var panel: Window
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {}
var pilot_drive_evidence: Dictionary = {}


func _initialize() -> void: run.call_deferred()


func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("WB_ACTOR_CONFIGURATION_NATIVE: "+reason)
	return ok


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false,label+" / "+str(wb.message if wb != null else "Workbench unavailable"))


func ticks(count: int, label: String) -> bool:
	var session = host.physical_actor_session
	var target: int = session.tick+count
	return await until(func() -> bool: return host.physical_actor_session == session and session.tick >= target,label)


func find_button(root_node: Node, caption: String) -> Button:
	if root_node is Button and root_node.text == caption: return root_node
	for child: Node in root_node.get_children():
		var found := find_button(child,caption)
		if found != null: return found
	return null


func install() -> bool:
	var data := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	Setup._box(data.edits,Vector2i(0,300),Vector2i(512,312),Setup.WALL)
	data.actors = [Setup.instance("monowheel",1,Vector2(120,220)),
		Setup.instance("runner",2,Vector2(270,276)),Setup.instance(Setup.BARREL,3,Vector2(400,240))]
	data.actors[0].control = Catalog.default_control("monowheel")
	data.actors[0].control.source = "human"
	data.next_id = 4
	data.selected = 1
	if not check(wb.apply(data),"small physical interaction cast admitted"): return false
	return await until(func() -> bool: return not wb.busy() and wb.applied.actors.size() == 3,"small cast installed")


func keyboard_edge(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	# Headless skips normal DisplayServer event pumping; the graphical
	# regression still flushes to make the sampled key state deterministic.
	Input.flush_buffered_events()


func exercise_pilot_input() -> void:
	# Real configuration button -> sampled keyboard -> live Rapier actuator.
	# Mock-only signal and submit_workbench_action tests miss the input gate.
	if not check(not host.paused and not wb.busy(),"piloting regression starts playing"): return
	wb.select_instance(2)
	wb.open_actor_composition()
	panel = wb._actor_panel
	panel.tabs.current_tab = 1
	var pilot_button := find_button(panel,"Pilot inspected")
	if not check(pilot_button != null,"actual Controllers pilot button"): return
	var session = host.physical_actor_session
	var run_id: String = session.run_id
	var slot: int = session.slot_for_instance(2)
	if not check(slot >= 0,"Runner has a real actor slot"): return
	var rid: RID = session._rigs[slot].bodies()[0].get_rid()
	pilot_button.pressed.emit()
	check(wb.pilot_id() == 2 and wb.pilot_slot == slot and session.workbench_control(2).source == "human",
		"panel handoff installs human controller and slot")
	check(session.run_id == run_id and session._rigs[slot].bodies()[0].get_rid() == rid,
		"handoff keeps the same actual Rapier body and native owner")
	panel.close_requested.emit()
	keyboard_edge(KEY_D,false)
	if not await ticks(3,"keyboard idle after closing configuration"): return
	check(not host._actor_input_rearm,"Configuration close requires a fresh neutral keyboard sample")
	wb.actor_interaction.set_mode("grab")
	check(not wb.actor_interaction.blocks_human_input(),
		"selected Grab mode does not disable an idle pilot")
	if not await ticks(3,"idle Grab mode stays playable"): return
	check(not host._actor_input_rearm,"idle Grab retains keyboard rearm state")
	var physical_before: Dictionary = session.workbench_actor_state(2)
	var before: Vector2 = Vector2(physical_before.position)
	var velocity_before: Vector2 = Vector2(physical_before.linear_velocity)
	var accepted: int = int(session.workbench_control(2).accepted)
	var tick_before: int = session.tick
	keyboard_edge(KEY_D,true)
	check(host._workbench_key(KEY_D),"Godot Input receives real D event, not a mocked command")
	if await ticks(48,"sustained native/Rapier pilot drive while holding D"):
		var drive: Dictionary = session._rigs[slot]._action
		var physical_after: Dictionary = session.workbench_actor_state(2)
		var after: Vector2 = Vector2(physical_after.position)
		var velocity_after: Vector2 = Vector2(physical_after.linear_velocity)
		pilot_drive_evidence = {"before_x":before.x,"after_x":after.x,"delta_x":after.x-before.x,
			"before_velocity_x":velocity_before.x,"after_velocity_x":velocity_after.x,
			"ticks":session.tick-tick_before,"accepted_delta":int(session.workbench_control(2).accepted)-accepted,
			"command_x":Vector2(drive.get("move",Vector2.ZERO)).x,
			"same_rid":session._rigs[slot].bodies()[0].get_rid()==rid}
		check(int(session.workbench_control(2).accepted) > accepted 			and Vector2(drive.get("move",Vector2.ZERO)).x > 0.5,
			"sampled keyboard D reaches real active physical controller")
		check(after.x > before.x + 0.1,
			"piloted Rapier body actually moves right (dx=%.3f, v0=%.3f, v1=%.3f, ticks=%d)" %
			[after.x-before.x,velocity_before.x,velocity_after.x,session.tick-tick_before])
	keyboard_edge(KEY_D,false)
	if not await ticks(3,"key release before live grab"): return
	var pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var grab = session.manipulator()
	var started: Dictionary = grab.begin_grab(pose.origin)
	if check(bool(started.get("active",false)) and int(started.get("instance_id",-1)) == 2,
		"actual human-piloted body can be grabbed"):
		check(wb.actor_interaction.blocks_human_input(),
			"active physical grab suppresses pilot drive")
		if await ticks(3,"active grab across repeated physics input polls"):
			check(grab.active() and session._rigs[slot].bodies()[0].get_rid() == rid,
				"pilot neutralization does not cancel grab or replace body")
		grab.end_grab("pilot_input_regression")
	wb.actor_interaction.set_mode("paint")
	wb.open_actor_composition()
	panel = wb._actor_panel
	var back_button := find_button(panel,"Hand back")
	if check(back_button != null,"actual Controllers Hand back button"):
		back_button.pressed.emit()
	check(session.workbench_control(2).source == "scripted" and wb.pilot_id() == 0,
		"Hand back restores autonomous Runner and releases human pilot")
	panel.close_requested.emit()


func exercise() -> void:
	if not await install(): return
	check(wb.pilot_instance(1),"explicitly pilot initial monowheel")
	if not check(wb.toggle_pause(),"Play starts installed session"): return
	if not await ticks(8,"NPC starts before configuration"): return
	# Pilot the real Runner while it is still near the authored clear-space spawn.
	# Running the pilot probe after multiple owner restarts allowed autonomous
	# patrol to collide with distant terrain on hosted software-rendered Windows.
	# We still require physical rightward displacement, not merely a routed command.
	await exercise_pilot_input()
	check(wb.pilot_instance(1),"restore explicit monowheel pilot after Runner hand-back")
	var session = host.physical_actor_session
	var run_id: String = session.run_id
	var accepted_before := int(session.workbench_control(2).accepted)
	var native_before: int = host.latest_snapshot.tick_index
	wb.open_actor_composition()
	panel = wb._actor_panel
	if not check(panel != null and panel.visible,"actual unified configuration mounted"): return
	check(not host.paused and session.run_id == run_id,"opening configuration retains running owner")
	check(wb.pilot_id() == 1,"opening configuration preserves explicit pilot")
	if not await ticks(12,"Rapier progresses while configuration is open"): return
	check(int(session.workbench_control(2).accepted) > accepted_before,"independent NPC keeps receiving decisions with configuration open")
	check(host.latest_snapshot.tick_index > native_before,"native materials progress with configuration open")
	panel.instances.select(panel.instances.get_item_index(2))
	panel.instances.item_selected.emit(panel.instances.selected)
	check(wb.selected_id() == 2 and wb.pilot_id() == 1,"inspector changes actor without taking pilot")
	panel.tabs.current_tab = 3
	await process_frame
	panel.stiffness.get_line_edit().grab_focus()
	panel.stiffness.get_line_edit().text = "425"
	panel.refresh()
	check(panel.stiffness.get_line_edit().text == "425","live diagnostics preserve focused uncommitted force field")
	find_button(panel,"Apply manipulation settings").pressed.emit()
	check(is_equal_approx(float(wb.actor_interaction.settings.stiffness),425.0),"real Workbench button commits child-window SpinBox before applying")
	check(panel.apply_info.text.contains("Accepted") and not panel._settings_dirty,
		"real synchronous settings adoption acknowledges applied state, not just signal")
	panel.interaction_mode.select(1)
	panel.interaction_mode.item_selected.emit(1)
	check(wb.actor_interaction.mode() == "grab" and not host.paused,"mode signal selects live Grab without pausing")
	var before: Dictionary = wb.actor(wb.applied,2).duplicate(true)
	panel.placement_x.value = 320
	find_button(panel,"Apply authored placement (paused)").pressed.emit()
	check(wb.actor(wb.applied,2) == before and host.pending_microscenario_apply.is_empty(),"running authored placement refuses without changing composition")
	check(wb.message.to_lower().contains("pause"),"running placement explains Pause requirement")
	panel.refresh()
	check(panel.placement_x.value == 320 and panel._placement_dirty and panel.apply_info.text.contains("Refused"),
		"running paused-only placement refusal preserves visible staged field and status")
	if not check(wb.toggle_pause(),"Pause for exact placement"): return
	wb.select_instance(1)
	panel.refresh(true)
	var pose: Dictionary = session.capture_workbench_assembly(1)
	var chassis: Dictionary = wb.body_state(1)
	check(Vector2(pose.position).distance_to(chassis.position) > 1.0,"fixture exercises nonzero first-part offset")
	panel._read_current_pose()
	check(Vector2(panel.placement_x.value,panel.placement_y.value).distance_to(pose.position) <= 0.18,
		"current-pose fields read assembly origin, not offset chassis")
	panel.tabs.current_tab = 0
	await process_frame
	panel.placement_x.get_line_edit().grab_focus()
	panel.placement_x.get_line_edit().text = "160.25"
	panel.placement_y.value = 210.5
	panel.placement_angle.value = 30.25
	var previous_epoch: int = host._physical_epoch
	find_button(panel,"Apply authored placement (paused)").pressed.emit()
	if not await until(func() -> bool: return not wb.busy() and host._physical_epoch > previous_epoch,"precision placement preparation completes"): return
	var actor: Dictionary = wb.actor(wb.applied,1)
	check(actor.spawn == [160.25,210.5] and is_equal_approx(float(actor.spawn_rotation_degrees),30.25),"precision Apply commits position/orientation to authored data")
	check(wb.pilot_id() == 1 and wb.applied.actors.size() == 3,"placement keeps actor identities and pilot selection")
	check(panel.visible and host.paused,"placement leaves configuration open and simulation paused")
	panel.tabs.current_tab = 4
	panel.logical_limit.value = 17
	panel.body_limit.value = 128
	panel.proxy_limit.value = 128
	previous_epoch = host._physical_epoch
	find_button(panel,"Apply capacity").pressed.emit()
	if not await until(func() -> bool: return not wb.busy() and host._physical_epoch > previous_epoch,"versioned capacity request prepares replacement owner"): return
	check(wb.applied.sandbox_capacity.logical_limit == 17 and wb.applied.sandbox_capacity.version == 1,
		"actual configuration Apply admits nonpreset logical capacity")
	check(wb.applied.sandbox_capacity.body_limit == 128 and wb.applied.sandbox_capacity.proxy_limit == 128,
		"actual configuration preserves independent body and native-mask budgets")
	check(wb.applied.actors.size() == 3 and wb.pilot_id() == 1,"capacity adoption retains cast and pilot")
	panel.refresh()
	check(panel.logical_limit.value == 17 and not panel._capacity_dirty and panel._apply_requests.capacity.phase == "accepted",
		"real asynchronous capacity adoption acknowledges actual installed owner, then clears staging")
	var original_mass: float = wb.body_state(1).mass
	panel.tabs.current_tab = 3
	await process_frame
	panel.tuning.mass_multiplier.get_line_edit().grab_focus()
	panel.tuning.mass_multiplier.get_line_edit().text = "2"
	previous_epoch = host._physical_epoch
	find_button(panel,"Apply actor tuning / restart").pressed.emit()
	if not await until(func() -> bool: return not wb.busy() and host._physical_epoch > previous_epoch,"actor tuning prepares replacement owner"): return
	check(is_equal_approx(float(wb.actor(wb.applied,1).options.mass_multiplier),2.0),"unified tuning commits focused numeric value to authored actor")
	check(is_equal_approx(float(wb.body_state(1).mass),original_mass*2.0),"unified tuning changes actual Rapier body mass")
	check(wb.pilot_id() == 1 and wb.applied.actors.size() == 3,"tuning keeps actor identities and explicit pilot")
	panel.refresh()
	check(not panel._tuning_dirty and panel._apply_requests.tuning.phase == "accepted",
		"real asynchronous physical tuning adopts only after the correct actor options are accepted")
	panel.interaction_mode.select(0)
	panel.interaction_mode.item_selected.emit(0)
	panel.hide()
	check(wb.actor_interaction.mode() == "paint","return to existing live PAINT mode")
	if check(wb.toggle_pause(),"resume after exact placement"):
		await ticks(8,"new owner and NPC resume after precision placement")
	# An independently installed 64-barrel population exercises the exact
	# reported failure in the ordinary Workbench, not a mocked signal handler.
	if not check(wb.toggle_pause(),"pause before population acceptance test"): return
	if not check(wb.load_actor_sandbox("barrels",64),"request a real 64-barrel playground"): return
	if not await until(func() -> bool: return not wb.busy() and wb.applied.actors.size() == 64,
		"64 barrels installed in real native/Rapier owner"): return
	check(host.physical_actor_session.bodies().size() == 64,
		"64 installed barrels are 64 real physical bodies")
	wb.open_actor_composition()
	panel = wb._actor_panel
	panel.tabs.current_tab = 4
	panel.refresh()
	var original_capacity: int = int(wb.applied.sandbox_capacity.logical_limit)
	var original_pilot: int = wb.pilot_id()
	var original_epoch: int = host._physical_epoch
	check(original_capacity >= 64,"playground has a legitimate budget for all 64 installed actors")
	panel.logical_limit.value = 32
	find_button(panel,"Apply capacity").pressed.emit()
	check(wb.message.begins_with("Refused") and not wb.busy(),"real 64-to-32 capacity reduction refused synchronously")
	await create_timer(0.3).timeout
	panel.refresh()
	check(panel.logical_limit.value == 32 and panel._capacity_dirty,
		"rejected 32 is still visible after the 200-ms UI diagnostic refresh")
	check(panel._apply_requests.capacity.phase == "rejected" and panel.apply_info.text.contains("Refused"),
		"real rejected Apply retains explicit refusal acknowledgement")
	check(wb.applied.actors.size() == 64 and int(wb.applied.sandbox_capacity.logical_limit) == original_capacity
		and host._physical_epoch == original_epoch,"rejected Apply never mutates real owner or accepted capacity")
	check(wb.pilot_id() == original_pilot and host.paused,"refusal neither transfers pilot nor changes pause state")
	panel.logical_limit.value = original_capacity+16
	var accepted_target: int = int(panel.logical_limit.value)
	find_button(panel,"Apply capacity").pressed.emit()
	check(not host.pending_microscenario_apply.is_empty() and panel._capacity_dirty
		and panel._apply_requests.capacity.phase == "pending",
		"real admitted capacity remains pending until the prepared owner has installed")
	if not await until(func() -> bool: return not wb.busy() and host._physical_epoch > original_epoch \
		and int(wb.applied.sandbox_capacity.logical_limit) == accepted_target,
		"accepted 64-barrel capacity change completes asynchronously"): return
	panel.refresh()
	check(panel.logical_limit.value == accepted_target and not panel._capacity_dirty
		and panel._apply_requests.capacity.phase == "accepted",
		"real accepted capacity clears staging only after installed configuration matches")
	check(wb.applied.actors.size() == 64 and wb.pilot_id() == original_pilot and host.paused,
		"successful capacity preserves all 64 actors, pilot identity, and pause state")
	panel.hide()
	report = {"native_tick":host.latest_snapshot.tick_index,"rapier_tick":host.physical_actor_session.tick,
		"actors":wb.applied.actors.size(),"source":"actual-ordinary-workbench","renderer":DisplayServer.get_name(),
		"pilot_drive":pilot_drive_evidence}


func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	wb = host.shared_workbench
	if await until(func() -> bool: return wb != null and not wb.applied.is_empty() and not wb.busy(),"ordinary Workbench starts"):
		await exercise()
	host.queue_free()
	await process_frame
	await process_frame
	report.merge({"checks":checks,"failures":failures})
	print("WB_ACTOR_CONFIGURATION_NATIVE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
