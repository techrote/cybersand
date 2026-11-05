extends SceneTree

# Exercise a real retained edit with the same pressure-producing cells as the
# native regression, through Main, its worker, and the workbench Apply button.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var main: Control
var panel
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error("WORKBENCH_LIVE_LIQUID: %s / %s / %s" % [label,main.microscenario_error,panel.message])
	return ok

func wait_for(predicate: Callable, label: String) -> bool:
	var end := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec() < end:
		if main.pending_microscenario_apply.is_empty() and (not main.microscenario_error.is_empty() or main.simulation_worker.has_failed()):
			break
		await process_frame
	return check(predicate.call(),label)

func family(name_text: String, material: int = CyberCellWorld.WATER) -> PackedInt32Array:
	var request := PackedInt32Array(panel.applied.liquid_policy)
	for option: Dictionary in panel._liquids.bridge.liquid_policy_assignment_choices(request,material):
		if option.accepted and option.family == name_text and option.variant == "reference":
			return option.request
	return PackedInt32Array()

func applied_water() -> String:
	for a: Dictionary in main.tower_context.liquid_solver_policy.assignments:
		if a.material == CyberCellWorld.WATER: return a.applied_family
	return ""

func exercise() -> void:
	var pressure := family("pressure_flow_v1")
	var data := Setup.fresh(pressure,Vector2i(512,512))
	data.normalize = true
	var cells := [3,1,1,400,3, 2,400,1,1,1, 5,400,1,1,1, 2,401,4,1,1, 4,400,1,1,3, 155,155,5,5,58]
	if not check(main.workbench_apply(data,[],cells,Vector2i(512,512),pressure,true,2,"LA-SELECTIVE"),"create column"):
		return
	if not await wait_for(func(): return main.pending_microscenario_apply.is_empty() and applied_water()=="pressure_flow_v1","installed pressure"):
		return
	if not check(panel.step_once(),"advance actual pressure simulation"): return
	if not await wait_for(func(): return not panel.step_pending and main.latest_snapshot.tick_index>0,"transfer completed"): return

	# Body edits preserve same-solver inventory, even over painted hard material.
	if not check(panel.place("midge",Vector2(156,156)),"place into live hard cells"): return
	if not await wait_for(func(): return main.pending_microscenario_apply.is_empty() and panel.applied.actors.size()==1,"body and pressure retained"): return
	var retained: Dictionary = main.tower_context.liquid_construction_receipt.workbench_conversion
	check(retained.preserved_water_overfill>0 and retained.water_before==retained.water_after and retained.normalization_consumed==0 and retained.normalization_produced==0,
		"actor edit preserves visible and overfill inventory after normalized starting recipe")
	# Overlapping initial actor coordinates are an experiment input too.
	if not check(panel.place("scooper",Vector2(156,156)),"place overlapping second body"): return
	if not await wait_for(func(): return main.pending_microscenario_apply.is_empty() and panel.applied.actors.size()==2,"both instances installed"): return
	check(not panel._liquids.normalize_water.button_pressed,"normalization opt-in expired after construction")
	panel._liquids.requested_policy = family("inertial_cellular_v1",24)
	if not check(panel.apply_liquids(),"apply Brine IN independently"): return
	if not await wait_for(func(): return main.pending_microscenario_apply.is_empty(),"Brine change completed"): return
	var brine: Dictionary = main.tower_context.liquid_construction_receipt.workbench_conversion
	check(brine.requested and brine.water_before==brine.water_after and brine.preserved_water_overfill==retained.preserved_water_overfill and brine.normalization_consumed==0 and brine.normalization_produced==0,
		"Brine switch in a fractional pressure World preserves all Water")
	panel._liquids.requested_policy = family("cellular_yield_v1")
	panel._liquids.normalize_water.set_pressed_no_signal(false)
	if not check(panel.toggle_pause(),"return to ordinary play"): return
	if not check(panel.apply_liquids(),"apply whole-cell Water over a live pressure column"): return
	if not await wait_for(func(): return main.pending_microscenario_apply.is_empty() and applied_water()=="cellular_yield_v1","native changed solver"): return
	var conversion: Dictionary = main.tower_context.liquid_construction_receipt.get("workbench_conversion",{})
	check(conversion.get("discarded_water_overfill",0)>0,"force retained visible Water and reported positive overfill loss")
	check(int(conversion.get("water_after",0))>0,"remaining Water installed")
	check(main.physical_actor_session.bodies().size()==2,"same two instances survive conversion")
	check(not main.paused and panel.message.contains(str(conversion.discarded_water_overfill)),
		"workbench resumes play and displays the accounted overfill loss")
	print("WORKBENCH_LIVE_CONVERSION ",JSON.stringify(conversion))

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	panel = main.shared_workbench
	if await wait_for(func(): return not panel.applied.is_empty(),"blank workbench installed"):
		await exercise()
	main.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_LIVE_LIQUID failures=",failures)
	quit(1 if failures else 0)
