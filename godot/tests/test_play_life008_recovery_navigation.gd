extends "res://tests/play_life006_selector_churn_case.gd"

# Real failed native Main + prepared candidate + actual Viewport F2 events.
# The three deterministic same-frame orderings exercise SceneTree's deferred
# replacement boundary; they are not OS-focus or physical-keyboard evidence.
const CAPACITY_SETTING: String = "cybersand/native_active_core_capacity"
const RECOVERY_META: StringName = &"cybersand_playable_recovery"
const ORDERINGS: Array[String] = ["restart_then_f2", "f2_then_restart", "pending_reload_then_f2"]
var navigation_rows: Array[Dictionary] = []
var observed_workers: Array[CyberSimulationWorker] = []
var ready_hosts: int = 0
var maximum_live_owners: int = 0
var pending_reload_observed: bool = false
var pending_reload_owner_joined: bool = false


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE008: " + message)


func observe_added(node: Node) -> void:
	if node.scene_file_path == "res://main.tscn":
		node.ready.connect(observe_ready.bind(node), CONNECT_ONE_SHOT)


func observe_ready(desktop: Control) -> void:
	ready_hosts += 1
	observed_workers.append(desktop.simulation_worker)
	var live: int = 0
	for worker: CyberSimulationWorker in observed_workers:
		if worker._thread.is_started(): live += 1
	maximum_live_owners = maxi(maximum_live_owners, live)
	expect(live == 1, "each Main ready observes exactly one started exclusive owner")


func f2() -> void:
	parse_key(KEY_F2, true)
	parse_key(KEY_F2, false)


func f2_after_pending_reload(worker: CyberSimulationWorker) -> void:
	# Deferred AFTER Main's deferred reload, but BEFORE SceneTree flushes its
	# pending scene. A pending Main has not entered the tree or started a worker.
	pending_reload_observed = current_scene == null and has_meta(RECOVERY_META)
	pending_reload_owner_joined = not worker._thread.is_started()
	f2()


func native_failure_observed(desktop: Control) -> bool:
	return desktop.latest_snapshot.simulation_failed and desktop.simulation_worker.has_failed()


func exercise_navigation(index: int) -> bool:
	var started: int = Time.get_ticks_usec()
	var context: String = ORDERINGS[index] + ": "
	var rig: StringName = Course.MECHANICAL_PRESETS[index]
	var hosts_before: int = ready_hosts
	pending_reload_observed = false
	pending_reload_owner_joined = false
	release_controls()
	set_meta("cybersand_feature", "play_session")
	var prior_capacity: Variant = ProjectSettings.get_setting(CAPACITY_SETTING, null)
	ProjectSettings.set_setting(CAPACITY_SETTING, 1)
	var desktop: Control = load("res://main.tscn").instantiate()
	ProjectSettings.set_setting(CAPACITY_SETTING, prior_capacity)
	desktop.paused = true
	root.add_child(desktop)
	current_scene = desktop
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var request: Dictionary = configure(desktop, rig, index % 2)
	expect(desktop.playable_session_panel.build_selected(), context + "real prepared course queues")
	var ready: bool = await wait_for(Callable(self, "actor_ready").bind(desktop, rig), SETUP_ALLOWANCE_MS)
	expect(ready, context + "real native actor and terrain install before capacity fault")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, context + "setup cleanup: ")
		current_scene = null
		observed_workers.clear()
		return false
	desktop.playable_session_panel.resume_play()
	ready = await wait_for(Callable(self, "native_failure_observed").bind(desktop))
	expect(ready and desktop.latest_snapshot.last_tick_error.contains("active scheduling-core capacity exhausted"),
		context + "actual native capacity exception reaches the composed host")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, context + "fault cleanup: ")
		current_scene = null
		observed_workers.clear()
		return false
	var accepted_graph: Dictionary = graph(desktop)
	var failed: CyberSimulationSnapshot = desktop.latest_snapshot
	var payload: Dictionary = retained_payload(failed)
	expect(desktop._apply_microscenario_definition(desktop.microscenario_definition, "Play", {},
		request.policy, desktop.microscenario_liquid_setup), context + "real failed-owner pending candidate stages")
	var candidate = desktop._pending_physical_candidate
	expect(candidate != null, context + "pending candidate exists before navigation")
	if candidate == null:
		await close_cycle(desktop, worker, desktop.physical_actor_session, context + "candidate cleanup: ")
		current_scene = null
		observed_workers.clear()
		return false
	var pending_graph: Dictionary = {"session":candidate.session, "bodies":candidate.session.bodies().duplicate(),
		"bridge":candidate.session.bridge, "candidate":candidate, "viewport":candidate.viewport}
	for _frame: int in range(4): await process_frame
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.refresh()
	expect(not panel.reset_button.disabled, context + "failed applied session offers explicit recovery")
	var navigation_started: int = Time.get_ticks_usec()
	if index == 0:
		panel.restart_applied()
		f2()
		expect(desktop._playable_recovery_cancelled and not desktop._playable_recovery_queued,
			context + "immediate F2 fences the queued restart before reload")
	elif index == 1:
		f2()
		panel.restart_applied()
		expect(desktop._playable_recovery_cancelled and not desktop._playable_recovery_queued,
			context + "Restart cannot undo the earlier F2 navigation intent")
	else:
		panel.restart_applied()
		f2_after_pending_reload.call_deferred(worker)
		expect(desktop._playable_recovery_queued, context + "reload is queued before deferred F2")
	var exited: bool = await wait_for(is_launcher)
	expect(exited and not is_instance_valid(desktop) and not has_meta(RECOVERY_META)
		and not has_meta("cybersand_feature"), context + "F2 reaches launcher and removes all recovery intent")
	if index == 2:
		expect(pending_reload_observed and pending_reload_owner_joined,
			context + "actual no-current-scene boundary occurs after old owner joins")
	if is_instance_valid(desktop):
		desktop.queue_free()
		if current_scene == desktop: current_scene = null
		await process_frame
		await process_frame
	expect(not worker._thread.is_started(), context + "old failed worker joins before launcher")
	verify_retired(accepted_graph, context + "accepted graph: ")
	verify_retired(pending_graph, context + "pending graph: ")
	expect(retained_payload(failed) == payload, context + "failed snapshot remains immutable across cancellation")
	var navigation_usec: int = Time.get_ticks_usec() - navigation_started
	if not exited or worker._thread.is_started():
		observed_workers.clear()
		return false
	var launcher: Node = current_scene
	var entry: Button
	for button: Button in launcher.find_children("*", "Button", true, false):
		if button.text.begins_with("Play session"): entry = button
	expect(entry != null, context + "actual launcher retains the Play entry")
	if entry == null:
		observed_workers.clear()
		return false
	entry.pressed.emit()
	ready = await wait_for(entered_host)
	expect(ready, context + "re-entry opens the normal selector in a new Main")
	if not ready:
		observed_workers.clear()
		return false
	var reentered: Control = current_scene
	var fresh_worker: CyberSimulationWorker = reentered.simulation_worker
	for _frame: int in range(4): await process_frame
	expect(reentered.pending_microscenario_apply.is_empty() and reentered._microscenario_request_serial == 0
		and reentered.microscenario_definition.is_empty() and reentered.physical_actor_session == null
		and not reentered._playable_recovery_queued and not has_meta(RECOVERY_META),
		context + "unrelated Play entry inherits no recipe, actor or automatic recovery build")
	expect(ready_hosts == hosts_before + 2 and fresh_worker != worker
		and not worker._thread.is_started() and fresh_worker._thread.is_started(),
		context + "only the failed Main and later manual re-entry reach ready; owners never overlap")
	f2()
	var reentered_exited: bool = await wait_for(is_launcher)
	expect(reentered_exited and not is_instance_valid(reentered) and not fresh_worker._thread.is_started(),
		context + "normal re-entry also exits through F2 and joins")
	if is_instance_valid(reentered):
		await close_cycle(reentered, fresh_worker, reentered.physical_actor_session, context + "re-entry cleanup: ")
		current_scene = null
	var old_weak: WeakRef = weakref(worker)
	var adapter_weak: WeakRef = weakref(worker._world) # Only after verified join.
	observed_workers.clear()
	worker = null
	desktop = null
	for _frame: int in range(3): await process_frame
	expect(old_weak.get_ref() == null and adapter_weak.get_ref() == null,
		context + "cancelled recovery releases its worker and native adapter")
	navigation_rows.append({"ordering":ORDERINGS[index], "rig":str(rig), "navigation_usec":navigation_usec,
		"elapsed_usec":Time.get_ticks_usec()-started, "actual_pending_reload_observed":pending_reload_observed,
		"old_owner_joined":true, "accepted_and_pending_graphs_retired":true,
		"old_worker_destroyed":old_weak.get_ref()==null, "old_adapter_destroyed":adapter_weak.get_ref()==null,
		"normal_selector_reentry":ready, "ready_hosts":ready_hosts-hosts_before})
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	return failures == 0


func run() -> void:
	deadline_ms = Time.get_ticks_msec() + 150000
	node_added.connect(observe_added)
	for index: int in range(ORDERINGS.size()):
		if not await exercise_navigation(index): break
	expect(navigation_rows.size() == 3 and maximum_live_owners == 1 and ready_hosts == 6,
		"all three navigation orderings complete with no extra ready host or overlapping live owner")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	print("PLAY_LIFE008_RESULT ", JSON.stringify({"assertions":assertions,"failures":failures,
		"rows":navigation_rows,"maximum_observed_live_owners":maximum_live_owners,"ready_hosts":ready_hosts,
		"real_native_failure":true,"native_active_core_capacity_injected":1,
		"injected_setting_restored_before_first_ready":true,"native_jobs_held":false,
		"automated_input":"Viewport F2 events and UI button signals", "synthetic_world":false,
		"physical_input_qualified":false,"internal_budget_ms":150000,"retries":0}))
	quit(0 if failures == 0 else 1)
