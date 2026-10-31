extends "res://tests/play_life006_selector_churn_case.gd"

# Actual native capacity failure in all five composed SetP sessions. Only
# construction-time capacity is injected, then restored BEFORE the first Main
# enters the tree. The fresh host uses the original application setting:
# recovery after removal of a fault, not a cure for an unchanged bad limit.
const Session = preload("res://scripts/physical_actor_session.gd")
const Profiles = preload("res://scripts/player_environment_profiles.gd")
const CAPACITY_SETTING: String = "cybersand/native_active_core_capacity"
var recovery_rows: Array[Dictionary] = []

class FailureHost:
	extends "res://scripts/main.gd"
	var completed_main_callbacks: int = 0
	var completed_physics_callbacks: int = 0

	func _process(delta: float) -> void:
		super._process(delta)
		completed_main_callbacks += 1

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		completed_physics_callbacks += 1


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE007: " + message)


func replacement_ready(previous_id: int, rig: StringName) -> bool:
	return current_scene != null and current_scene.get_instance_id() != previous_id \
		and current_scene.scene_file_path == "res://main.tscn" and actor_ready(current_scene, rig)


func exercise(index: int) -> bool:
	var rig: StringName = Course.MECHANICAL_PRESETS[index]
	var started: int = Time.get_ticks_usec()
	var prior_capacity: Variant = ProjectSettings.get_setting(CAPACITY_SETTING, null)
	ProjectSettings.set_setting(CAPACITY_SETTING, 1)
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(FailureHost)
	ProjectSettings.set_setting(CAPACITY_SETTING, prior_capacity)
	desktop.paused = true
	root.add_child(desktop)
	current_scene = desktop
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(), str(rig) + ": real owner starts")
	var profile: Dictionary = Profiles.preset(Profiles.PRESET_EARTH_FEEL)
	expect(worker.queue_player_environment_profile(profile), str(rig) + ": copied nondefault profile admitted")
	var ready: bool = await wait_for(func() -> bool: return desktop.active_player_environment_profile == profile, SETUP_ALLOWANCE_MS)
	expect(ready, str(rig) + ": nondefault profile actually publishes before construction")
	desktop.simulation_margin_index = 0
	desktop.simulation_margin = desktop.SIMULATION_MARGIN_PRESETS[0]
	desktop.render_snapshot_hz_index = 0
	desktop.render_snapshot_hz = desktop.RENDER_SNAPSHOT_HZ_PRESETS[0]
	worker.set_render_snapshot_hz(desktop.render_snapshot_hz)
	desktop.liquid_surface_adhesion_enabled = false
	desktop.update_worker_frame_state()
	var requested: Dictionary = configure(desktop, rig, index % 2)
	# A static decoration tests exact accepted recipe retention, rather than
	# regenerating catalogue content from the same course ID.
	var definition: Dictionary = Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0)
	definition.rectangles.append_array([100, 8, 1, 1, 1])
	expect(desktop.microscenario_apply_exploratory_liquid(definition, requested.policy,
		false, "Play", desktop._playable_actor_configuration(rig)), str(rig) + ": real prepared course queues")
	desktop.pending_microscenario_apply.playable_options = {
		"controls":requested.selection.controls, "rules":requested.selection.rules, "camera":requested.selection.camera}
	ready = ready and await wait_for(Callable(self, "actor_ready").bind(desktop, rig), SETUP_ALLOWANCE_MS)
	expect(ready, str(rig) + ": native construction and actual terrain install before fault")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, "setup cleanup: ")
		current_scene = null
		return false
	var accepted_definition: Dictionary = desktop.microscenario_definition.duplicate(true)
	var accepted_mode: String = str(desktop.tower_context.microscenario.mode)
	var accepted_options: Dictionary = desktop.playable_session_options.duplicate(true)
	var accepted_setup: Dictionary = desktop.microscenario_liquid_setup.duplicate(true)
	var accepted_policy: Dictionary = desktop.tower_context.liquid_solver_policy.duplicate(true)
	var old_graph: Dictionary = graph(desktop)
	var old_session = desktop.physical_actor_session
	old_session.set_suspended(false)
	var observation: Dictionary = old_session.observation(0)
	var stale: Dictionary = Session.make_command(observation, int(observation.last_sequence)+1, {"move":Vector2.RIGHT})
	# Direct admission proves the old typed packet was accepted while native
	# remains paused. This bounded seam is not physical human-input evidence.
	expect(old_session.submit(stale, &"human"), str(rig) + ": old owner admits retained typed command")
	old_session.set_suspended(true)
	desktop.playable_session_panel.resume_play()
	ready = await wait_for(func() -> bool: return desktop.latest_snapshot.simulation_failed and worker.has_failed())
	expect(ready, str(rig) + ": actual capacity fault reaches Main")
	if not ready:
		await close_cycle(desktop, worker, old_session, "fault cleanup: ")
		current_scene = null
		return false
	var failed: CyberSimulationSnapshot = desktop.latest_snapshot
	var payload: Dictionary = retained_payload(failed)
	var image_before: PackedByteArray = desktop.image.get_data().duplicate()
	var stopped_tick: int = old_session.tick
	var stopped_step: int = desktop.rapier_bridge.manual_step_count()
	var main_before: int = desktop.completed_main_callbacks
	var physics_before: int = desktop.completed_physics_callbacks
	expect(failed.last_tick_error.contains("active scheduling-core capacity exhausted")
		and failed.tick_failure_count == 1 and failed.failed_tick_index == failed.tick_index+1,
		str(rig) + ": exact native failure and completed/attempted tick boundary")
	expect(not worker.queue_emit_disc(20,20,0,2), str(rig) + ": quarantined public emission refuses")
	ready = await wait_for(func() -> bool: return (desktop.completed_main_callbacks >= main_before+8
		and desktop.completed_physics_callbacks >= physics_before+8))
	expect(old_session.tick == stopped_tick and desktop.rapier_bridge.manual_step_count() == stopped_step
		and desktop.image.get_data() == image_before and worker.has_failed(),
		str(rig) + ": actual Rapier and last valid presentation stay frozen")
	expect(ready and desktop.latest_snapshot.tick_index == failed.tick_index
		and desktop.latest_snapshot.tick_failure_count == 1,
		str(rig) + ": actual Main process and physics callbacks complete without retrying the failed native tick")
	var pending_graph: Dictionary = {}
	if index % 2 == 0:
		# A real candidate at the historical failed-preparation boundary must
		# retire on whole-scene recovery along with the accepted failed graph.
		expect(desktop._apply_microscenario_definition(accepted_definition, "Inspect", {},
			requested.policy, accepted_setup), str(rig) + ": pending failed-owner candidate is present")
		var candidate = desktop._pending_physical_candidate
		pending_graph = {"session":candidate.session, "bodies":candidate.session.bodies().duplicate(),
			"bridge":candidate.session.bridge, "candidate":candidate, "viewport":candidate.viewport}
		for _frame: int in range(4): await process_frame
		expect(desktop.microscenario_mode == "Inspect" and accepted_mode == "Play"
			and desktop.tower_context.microscenario.mode == accepted_mode,
			str(rig) + ": unaccepted pending mode differs from completed worker context")
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select((index + 1) % Course.MECHANICAL_PRESETS.size())
	panel.rule_choice.select(1 - panel.rule_choice.selected)
	panel.camera_choice.select(1 - panel.camera_choice.selected)
	panel.policy_editor.select_preset(0 if index % 2 == 0 else 2)
	panel.refresh()
	expect(not panel.reset_button.disabled and panel.resume_button.disabled and panel.build_button.disabled
		and panel.status_label.text.contains("World stopped.")
		and panel.status_label.text.contains("initial state"), str(rig) + ": stopped UI offers explicit recovery, not a pending build")
	if index == 0:
		# Synthetic SceneTree-error PRESENTATION state only. The preceding
		# native capacity fault and the following whole-scene recovery are real.
		# Do not force an engine loader error or suppress runner diagnostics.
		var reload_error: String = "Fresh session restart failed (%d); return to the launcher with F2." % ERR_CANT_OPEN
		desktop._playable_recovery_error = reload_error
		panel.refresh()
		expect(desktop.playable_session_unavailable_reason() == reload_error
			and panel.status_label.text == reload_error and not panel.reset_button.disabled
			and panel.resume_button.disabled and panel.build_button.disabled,
			"synthetic reload-error presentation stays visible without reopening stopped-world admission")
	var old_id: int = desktop.get_instance_id()
	var recovery_started: int = Time.get_ticks_usec()
	panel.restart_applied()
	panel.restart_applied()
	expect(desktop._playable_recovery_queued and desktop._playable_recovery_error.is_empty(),
		str(rig) + ": repeated Restart latches one replacement and clears prior reload error")
	ready = await wait_for(Callable(self, "replacement_ready").bind(old_id, rig))
	expect(ready, str(rig) + ": fresh Main rebuilds matching actor and terrain")
	if not ready:
		if current_scene != null:
			var failed_host: Control = current_scene
			await close_cycle(failed_host, failed_host.simulation_worker, failed_host.physical_actor_session, "recovery cleanup: ")
			current_scene = null
		return false
	var recovery_usec: int = Time.get_ticks_usec()-recovery_started
	var recovered: Control = current_scene
	expect(not is_instance_valid(desktop) and not worker._thread.is_started()
		and recovered.simulation_worker != worker and recovered.simulation_worker._thread.is_started(),
		str(rig) + ": old owner joined before observed fresh owner")
	if worker._thread.is_started():
		# Never inspect/destroy owner-held native values after a failed join
		# assertion. The external process watchdog remains the failure bound.
		quit(1)
		return false
	verify_retired(old_graph, str(rig) + ": accepted graph: ")
	verify_retired(pending_graph, str(rig) + ": pending graph: ")
	expect(not has_meta(recovered.PLAYABLE_RECOVERY_META) and recovered.paused
		and recovered.latest_snapshot.tick_index == 0 and not recovered.simulation_worker.has_failed(),
		str(rig) + ": recovery envelope consumed; fresh session paused at tick zero")
	expect(recovered.microscenario_definition == accepted_definition
		and recovered.microscenario_mode == accepted_mode
		and recovered.tower_context.microscenario.mode == accepted_mode
		and recovered.playable_session_options == accepted_options
		and recovered.microscenario_liquid_setup == accepted_setup
		and recovered.tower_context.liquid_solver_policy.policy_hash == accepted_policy.policy_hash
		and recovered.tower_context.liquid_solver_policy.envelope == requested.policy,
		str(rig) + ": exact accepted recipe/policy/options survive pending form edits")
	expect(recovered.active_player_environment_profile == profile
		and recovered.simulation_margin_index == 0 and recovered.simulation_margin == recovered.SIMULATION_MARGIN_PRESETS[0]
		and recovered.render_snapshot_hz_index == 0 and recovered.render_snapshot_hz == recovered.RENDER_SNAPSHOT_HZ_PRESETS[0]
		and not recovered.liquid_surface_adhesion_enabled,
		str(rig) + ": nondefault profile and owner settings survive")
	expect(recovered.physical_actor_session.run_id != observation.run_id
		and recovered.physical_actor_session._commands[0].is_empty()
		and recovered.physical_actor_session._button_edges[0].is_empty()
		and not recovered._playable_course_progress.started and recovered._playable_course_progress.elapsed_ticks == 0,
		str(rig) + ": fresh run has no old command/button/lap history")
	recovered.playable_session_panel.resume_play()
	ready = await wait_for(Callable(self, "live_clocks").bind(recovered, rig, 0, 0))
	expect(ready, str(rig) + ": recovered native and Rapier clocks actually advance")
	var accepted: int = recovered.physical_actor_session.accepted_commands
	expect(not recovered.physical_actor_session.submit(stale, &"human")
		and recovered.physical_actor_session.last_error == "run_or_epoch"
		and recovered.physical_actor_session.accepted_commands == accepted,
		str(rig) + ": old admitted command reaches run fence despite local counter reuse")
	expect(retained_payload(failed) == payload, str(rig) + ": retained failed packet stays immutable")
	var worker_weak: WeakRef = weakref(worker)
	var adapter_weak: WeakRef = weakref(worker._world) # Only after verified join.
	worker = null
	desktop = null
	for _frame: int in range(3): await process_frame
	expect(worker_weak.get_ref() == null and adapter_weak.get_ref() == null,
		str(rig) + ": old worker/native adapter destroyed after references drop")
	var fresh_worker: CyberSimulationWorker = recovered.simulation_worker
	var final_graph: Dictionary = graph(recovered)
	await close_cycle(recovered, fresh_worker, recovered.physical_actor_session, str(rig) + ": final exit: ")
	current_scene = null
	verify_retired(final_graph, str(rig) + ": recovered graph: ")
	recovery_rows.append({"rig":str(rig), "recovery_usec":recovery_usec,
		"elapsed_usec":Time.get_ticks_usec()-started, "old_failed_tick":failed.failed_tick_index,
		"policy_hash":str(accepted_policy.policy_hash), "pending_candidate_retired":not pending_graph.is_empty(),
		"old_worker_joined":true, "old_worker_destroyed":worker_weak.get_ref()==null,
		"old_adapter_destroyed":adapter_weak.get_ref()==null, "recovered_owner_joined":not fresh_worker._thread.is_started()})
	return ready and failures == 0


func run() -> void:
	deadline_ms = Time.get_ticks_msec() + 150000
	for index: int in range(Course.MECHANICAL_PRESETS.size()):
		if not await exercise(index): break
	expect(recovery_rows.size() == 5, "all five native-failed composed sessions recover through fresh Main")
	print("PLAY_LIFE007_RESULT ", JSON.stringify({"assertions":assertions,"failures":failures,
		"rows":recovery_rows,"real_native_failure":true,"native_active_core_capacity_injected":1,
		"injected_setting_restored_before_first_ready":true,"recovery":"whole-scene reload; accepted values only",
		"native_healthy_guard_changed":false,"synthesized_failure":false,"physical_input_qualified":false,
		"synthetic_reload_error_presentation_cases":1,"engine_reload_refusal_injected":false,
		"internal_budget_ms":150000,"retries":0}))
	quit(0 if failures==0 else 1)
