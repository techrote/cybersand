extends SceneTree

# Construct a real native capacity fault, observe the stopped worker, then
# press the workbench's actual Reset action. No UI thread reads a live World.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const CAPACITY_SETTING := "cybersand/native_active_core_capacity"
var errors := PackedStringArray()

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, claim: String) -> bool:
	if not value:
		errors.append(claim)
		push_error("WORKBENCH_FAILURE_RECOVERY: " + claim)
	return value

func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("main_ack_seconds")
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if predicate.call(): return true
	return false

func finish() -> void:
	if current_scene != null:
		var scene := current_scene
		current_scene = null
		scene.free()
	print("WORKBENCH_FAILURE_RECOVERY ",JSON.stringify({"failures":Array(errors)}))
	quit(0 if errors.is_empty() else 1)

func run() -> void:
	var prior: Variant = ProjectSettings.get_setting(CAPACITY_SETTING,null)
	ProjectSettings.set_setting(CAPACITY_SETTING,1)
	var old = load("res://main.tscn").instantiate()
	ProjectSettings.set_setting(CAPACITY_SETTING,prior)
	set_meta("cybersand_feature","shared_workbench")
	root.add_child(old)
	current_scene = old
	if not check(await wait_for(func(): return not old.shared_workbench.applied.is_empty()),"install actual workbench"):
		finish()
		return
	var ui = old.shared_workbench
	var worker = old.simulation_worker
	var data: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	data.actors = [Setup.instance("midge",4,Vector2(240,120))]
	data.next_id = 5
	data.selected = 4
	data.source = [220,50,2]
	check(ui.apply(data),"install selected flyer")
	if not check(await wait_for(func(): return old.physical_actor_session != null and old.pending_microscenario_apply.is_empty()),"prepared physical owner"):
		finish()
		return
	var old_session = old.physical_actor_session
	check(ui.paint(Vector2i(40,40),2) and ui.paint(Vector2i(440,40),14),"place separated active piles")
	if not check(await wait_for(func(): return old.image.get_pixel(440,40).r > 0.0),"paused authoring reaches old World"):
		finish()
		return
	check(ui.toggle_pause(),"enter real simulation")
	if not check(await wait_for(func(): return old.latest_snapshot.simulation_failed),"active-core limit quarantines actual native owner"):
		finish()
		return
	check(old.latest_snapshot.last_tick_error.contains("active scheduling-core capacity exhausted")
		and old.latest_snapshot.tick_failure_count==1,"record reason and failure count")
	var retained: Dictionary = ui.applied.duplicate(true)
	var old_id: int = old.get_instance_id()
	var invalid := retained.duplicate(true)
	invalid.liquid_policy = [1]
	check(not old.workbench_restart(invalid) and not old._playable_recovery_queued and ui.applied == retained,
		"invalid replacement cannot tear down the authored recovery setup")
	check(ui.reset_selected(),"Reset rebuilds the failed setup")
	if not check(await wait_for(func(): return (not is_instance_id_valid(old_id) and current_scene != null
			and current_scene.shared_workbench != null and not current_scene.shared_workbench.applied.is_empty())),
			"fresh scene accepts the authored starting setup"):
		finish()
		return
	var fresh = current_scene
	var fresh_ui = fresh.shared_workbench
	check(not worker._thread.is_started() and not is_instance_valid(old_session),"failed worker joined and old Rapier graph retired")
	check(fresh.paused and fresh.latest_snapshot.tick_index==0 and not fresh.simulation_worker.has_failed(),"fresh owner awaits play")
	check(fresh_ui.applied == retained and fresh_ui.body_state(4).position == Vector2(240,120),"selected identity, spawn, options, edits and source retained")
	check(await wait_for(func(): return fresh.image.get_pixel(440,40).r8 == 14 and fresh.image.get_pixel(40,40).r8 == 2),
		"fresh native cells restored from starting recipe")
	check(fresh_ui.step_once(),"single-step fresh owner")
	check(await wait_for(func(): return not fresh_ui.step_pending and fresh.latest_snapshot.tick_index==1),
		"healthy native and physical owners continue")
	finish()
