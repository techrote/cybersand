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


func exercise() -> void:
	if not await install(): return
	check(wb.pilot_instance(1),"explicitly pilot initial monowheel")
	if not check(wb.toggle_pause(),"Play starts installed session"): return
	if not await ticks(8,"NPC starts before configuration"): return
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
	panel.interaction_mode.select(1)
	panel.interaction_mode.item_selected.emit(1)
	check(wb.actor_interaction.mode() == "grab" and not host.paused,"mode signal selects live Grab without pausing")
	var before: Dictionary = wb.actor(wb.applied,2).duplicate(true)
	panel.placement_x.value = 320
	find_button(panel,"Apply authored placement (paused)").pressed.emit()
	check(wb.actor(wb.applied,2) == before and host.pending_microscenario_apply.is_empty(),"running authored placement refuses without changing composition")
	check(wb.message.to_lower().contains("pause"),"running placement explains Pause requirement")
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
	panel.interaction_mode.select(0)
	panel.interaction_mode.item_selected.emit(0)
	panel.hide()
	check(wb.actor_interaction.mode() == "paint","return to existing live PAINT mode")
	if check(wb.toggle_pause(),"resume after exact placement"):
		await ticks(8,"new owner and NPC resume after precision placement")
	report = {"native_tick":host.latest_snapshot.tick_index,"rapier_tick":host.physical_actor_session.tick,
		"actors":wb.applied.actors.size(),"source":"actual-ordinary-workbench","renderer":DisplayServer.get_name()}


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
