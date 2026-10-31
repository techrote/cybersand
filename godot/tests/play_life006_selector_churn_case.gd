extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-LIFE-006 / #269: integrated selector and real scene-navigation churn.
# Main, its existing worker/native World and main-thread Rapier are unmodified.
# UI button signals and Viewport F2 key events are automated; no physical input,
# OS-focus, rendered-pacing or general allocator/leak qualification is claimed.
const TOTAL_BUDGET_MS: int = 160000
const OPERATION_BUDGET_MS: int = 15000
var deadline_ms: int = 0
var builds_completed: int = 0
var resets_completed: int = 0
var graphs_retired: int = 0
var workers_destroyed: int = 0
var adapters_destroyed: int = 0
var rows: Array[Dictionary] = []


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE006: " + message)


# First draw can hold the frame for the cold palette compile (ANGLE: tens of seconds).
const SETUP_ALLOWANCE_MS: int = 60000

func wait_for(predicate: Callable, timeout_ms: int = OPERATION_BUDGET_MS) -> bool:
	var end_ms: int = mini(deadline_ms, Time.get_ticks_msec() + timeout_ms)
	while Time.get_ticks_msec() < end_ms:
		if predicate.call(): return true
		await process_frame
	return false


func is_launcher() -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://feature_launcher.tscn"


func entered_host() -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://main.tscn" \
		and current_scene.playable_session_panel != null and current_scene.playable_session_panel.visible


func installed_after(desktop: Control, rig: StringName, epoch: int, generation: int) -> bool:
	return actor_ready(desktop, rig) and desktop._physical_epoch > epoch \
		and desktop.latest_snapshot.render_world_generation > generation


func live_clocks(desktop: Control, rig: StringName, native_tick: int, physical_tick: int) -> bool:
	# Headless windows need not report OS focus. Do not bypass Main's real focus
	# predicate or mislabel neutral completed physics as human-control acceptance.
	return actor_ready(desktop, rig) and not desktop.simulation_worker.has_failed() \
		and desktop.latest_snapshot.tick_index > native_tick \
		and desktop.physical_actor_session.tick >= physical_tick + 3


func retained_payload(snapshot: CyberSimulationSnapshot) -> Dictionary:
	return {"serial":snapshot.serial, "tick":snapshot.tick_index,
		"generation":snapshot.render_world_generation, "epoch":snapshot.rigid_body_epoch,
		"cells":snapshot.cells.duplicate(), "render_serial":snapshot.render_snapshot_serial,
		"rectangles":snapshot.render_patch_rectangles.duplicate(),
		"patch_cells":snapshot.render_patch_cells.duplicate(),
		"terrain":snapshot.hard_surface_chunk_rectangles.duplicate(),
		"context":snapshot.lab_context.duplicate(true),
		"effects":snapshot.physical_actor_effects.duplicate(true)}


func graph(desktop: Control) -> Dictionary:
	if desktop.physical_actor_session == null: return {}
	return {"session":desktop.physical_actor_session,
		"bodies":desktop.physical_actor_session.bodies().duplicate(),
		"bridge":desktop.rapier_bridge, "candidate":desktop._accepted_physical_candidate,
		"viewport":desktop._accepted_physical_candidate.viewport \
			if desktop._accepted_physical_candidate != null else null}


func verify_retired(previous: Dictionary, context: String) -> void:
	if previous.is_empty(): return
	var bodies_gone: bool = true
	for body: Variant in previous.bodies:
		bodies_gone = bodies_gone and not is_instance_valid(body)
	var closed: bool = not is_instance_valid(previous.session) and bodies_gone \
		and not previous.bridge.is_initialized() \
		and previous.bridge.hard_surface_shape_count() == 0 \
		and previous.bridge.pending_hard_surface_chunks() == 0 \
		and previous.bridge._body_rids.is_empty() \
		and not is_instance_valid(previous.viewport)
	if previous.candidate != null:
		closed = closed and previous.candidate.session == null and previous.candidate.viewport == null
	expect(closed, context + "old session/bodies/private viewport and bridge collider state retire")
	if closed: graphs_retired += 1


func configure(desktop: Control, rig: StringName, parity: int) -> Dictionary:
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(rig))
	panel.control_choice.select(parity)
	panel.rule_choice.select(parity)
	panel.camera_choice.select(parity)
	panel.policy_editor.select_preset(2 if parity == 0 else 0)
	return {"selection":panel.selection(), "policy":panel.policy_editor.requested_policy.duplicate()}


func verify_composition(desktop: Control, request: Dictionary, context: String) -> void:
	var selection: Dictionary = request.selection
	var options: Dictionary = {"controls":selection.controls, "rules":selection.rules, "camera":selection.camera}
	var policy: Dictionary = desktop.tower_context.get("liquid_solver_policy", {})
	var receipt: Dictionary = desktop.tower_context.get("liquid_construction_receipt", {})
	var recipe: Dictionary = Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0)
	expect(desktop.playable_session_options == options and desktop.physical_rig_id == StringName(selection.actor)
		and policy.get("envelope", PackedInt32Array()) == request.policy
		and receipt.get("kind", "") == "applied_run"
		and receipt.get("policy_hash", "") == policy.get("policy_hash", "missing"),
		context + "accepted actor/options and native policy receipt match this composed request")
	expect(desktop.microscenario_definition.source_recipe_hash == recipe.source_recipe_hash
		and desktop.microscenario_definition.rectangles == recipe.rectangles
		and desktop._physical_terrain_ready and desktop.rapier_bridge.pending_hard_surface_chunks() == 0
		and desktop.rapier_bridge.hard_surface_shape_count() > 0,
		context + "actual authored course and nonempty terrain are ready before live physics")
	expect(desktop.camera_follow_enabled == (selection.camera == "follow")
		and desktop.current_view_size == (Vector2i(256, 128) if selection.camera == "follow" else Course.VIEW.size),
		context + "camera profile follows the committed request")
	expect(not desktop._playable_course_progress.started and desktop._playable_course_progress.elapsed_ticks == 0
		and desktop.physical_actor_session._button_edges[0].is_empty(),
		context + "new incarnation starts with neutral lap and button-edge state")


func build(desktop: Control, request: Dictionary, worker: CyberSimulationWorker, context: String) -> bool:
	var previous: Dictionary = graph(desktop)
	var epoch: int = desktop._physical_epoch
	var generation: int = desktop.latest_snapshot.render_world_generation if desktop.latest_snapshot != null else -1
	var options: Dictionary = desktop.playable_session_options.duplicate(true)
	var serial: int = desktop._microscenario_request_serial
	var panel = desktop.playable_session_panel
	var started: int = Time.get_ticks_usec()
	var queued: bool = panel.build_selected()
	expect(queued, context + "integrated Build admits one prepared transaction")
	if not queued: return false
	var candidate = desktop._pending_physical_candidate
	expect(candidate != null and desktop._microscenario_request_serial == serial + 1
		and desktop.playable_session_options == options
		and (previous.is_empty() or desktop.physical_actor_session == previous.session),
		context + "pending candidate cannot relabel or retire the accepted owner")
	expect(not panel.build_selected() and desktop._microscenario_request_serial == serial + 1
		and desktop._pending_physical_candidate == candidate,
		context + "immediate duplicate Build refuses without replacing the pending candidate")
	var rig := StringName(str(request.selection.actor))
	var ready: bool = await wait_for(Callable(self, "installed_after").bind(desktop, rig, epoch, generation))
	expect(ready, context + "matching actor/World/terrain installation completes within the bounded wait")
	if not ready: return false
	builds_completed += 1
	verify_retired(previous, context)
	verify_composition(desktop, request, context)
	expect(desktop.simulation_worker == worker and worker._thread.is_started() and not worker.has_failed(),
		context + "reconstruction retains the same healthy exclusive worker")
	rows.append({"kind":"build", "rig":str(rig), "elapsed_usec":Time.get_ticks_usec()-started,
		"actor_epoch":desktop._physical_epoch, "world_generation":desktop.latest_snapshot.render_world_generation,
		"options":desktop.playable_session_options.duplicate(true),
		"policy_hash":str(desktop.tower_context.liquid_solver_policy.policy_hash)})
	return true


func resume(desktop: Control, context: String) -> bool:
	var native_tick: int = desktop.latest_snapshot.tick_index
	var physical_tick: int = desktop.physical_actor_session.tick
	desktop.playable_session_panel.resume_play()
	var advanced: bool = await wait_for(Callable(self, "live_clocks").bind(
		desktop, desktop.physical_rig_id, native_tick, physical_tick))
	expect(advanced, context + "actual native and main-thread Rapier clocks advance after resume")
	return advanced


func reset_applied(desktop: Control, request: Dictionary, context: String) -> bool:
	var previous: Dictionary = graph(desktop)
	var epoch: int = desktop._physical_epoch
	var generation: int = desktop.latest_snapshot.render_world_generation
	var serial: int = desktop._microscenario_request_serial
	var panel = desktop.playable_session_panel
	panel.show_selection()
	# All five pending controls differ, and none is submitted. Restart must use
	# accepted state, including the policy, instead of current form contents.
	panel.actor_choice.select((panel.actor_choice.selected + 1) % Course.MECHANICAL_PRESETS.size())
	panel.control_choice.select(1 - panel.control_choice.selected)
	panel.rule_choice.select(1 - panel.rule_choice.selected)
	panel.camera_choice.select(1 - panel.camera_choice.selected)
	panel.policy_editor.select_preset(0 if request.selection.rules == "lap" else 2)
	var started: int = Time.get_ticks_usec()
	panel.restart_applied()
	var candidate = desktop._pending_physical_candidate
	expect(candidate != null and desktop._microscenario_request_serial == serial + 1,
		context + "Restart applied queues a fresh real reconstruction")
	panel.restart_applied()
	expect(desktop._microscenario_request_serial == serial + 1 and desktop._pending_physical_candidate == candidate,
		context + "immediate repeated Restart cannot enqueue a second reconstruction")
	var rig := StringName(str(request.selection.actor))
	var ready: bool = await wait_for(Callable(self, "installed_after").bind(desktop, rig, epoch, generation))
	expect(ready, context + "applied-session reset completes with newer identities")
	if not ready: return false
	resets_completed += 1
	verify_retired(previous, context)
	verify_composition(desktop, request, context)
	rows.append({"kind":"reset", "rig":str(rig), "elapsed_usec":Time.get_ticks_usec()-started,
		"actor_epoch":desktop._physical_epoch, "world_generation":desktop.latest_snapshot.render_world_generation})
	return true


func run_cycle(rig: StringName, cycle: int) -> bool:
	var started: int = Time.get_ticks_usec()
	var context: String = "%s cycle %02d: " % [rig, cycle]
	release_controls()
	expect(is_launcher(), context + "previous exit leaves the actual feature launcher")
	if not is_launcher(): return false
	var launcher: Node = current_scene
	var entry: Button
	for button: Button in launcher.find_children("*", "Button", true, false):
		if button.text.begins_with("Play session"): entry = button
	expect(entry != null, context + "actual launcher contains integrated Play entry")
	if entry == null: return false
	entry.pressed.emit()
	var ready: bool = await wait_for(entered_host)
	expect(ready and not is_instance_valid(launcher), context + "Play entry replaces launcher with real Main and selector")
	if not ready: return false
	var desktop: Control = current_scene
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(), context + "exclusive worker starts")
	var first: Dictionary = configure(desktop, rig, cycle % 2)
	ready = await build(desktop, first, worker, context + "first: ")
	if ready: ready = await resume(desktop, context + "first: ")
	var retained: CyberSimulationSnapshot = desktop.latest_snapshot
	var payload: Dictionary = retained_payload(retained) if retained != null else {}
	var other: StringName = Course.MECHANICAL_PRESETS[(Course.MECHANICAL_PRESETS.find(rig) + 1 + cycle % 4) % 5]
	var second: Dictionary = {}
	if ready:
		second = configure(desktop, other, 1 - cycle % 2)
		ready = await build(desktop, second, worker, context + "replacement: ")
	if ready: ready = await resume(desktop, context + "replacement: ")
	if ready: ready = await reset_applied(desktop, second, context + "reset: ")
	if ready: ready = await resume(desktop, context + "reset: ")
	if retained != null:
		expect(retained_payload(retained) == payload, context + "replacement/reset cannot mutate retained snapshot bytes or identities")
	var final_graph: Dictionary = graph(desktop)
	var shutdown_started: int = Time.get_ticks_usec()
	parse_key(KEY_F2, true)
	parse_key(KEY_F2, false)
	var exited: bool = await wait_for(is_launcher)
	expect(exited and not is_instance_valid(desktop) and not has_meta("cybersand_feature"),
		context + "real Viewport F2 returns to launcher and retires Main's selection")
	var shutdown_usec: int = Time.get_ticks_usec() - shutdown_started
	# Cleanup also runs on a failed assertion, so the test never deliberately
	# leaves a started worker behind. This is not an alternate passing exit.
	if is_instance_valid(desktop):
		desktop.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	var joined: bool = not worker._thread.is_started()
	expect(joined, context + "scene navigation joins the exclusive simulation owner")
	if joined: joined_workers += 1
	verify_retired(final_graph, context + "F2: ")
	if retained != null:
		expect(retained_payload(retained) == payload, context + "retained copied snapshot survives full scene retirement")
	if not joined: return false
	# Inspect only object lifetime after exclusive-owner join; never read the
	# mutable native World while the worker is live.
	var worker_weak: WeakRef = weakref(worker)
	var adapter_weak: WeakRef = weakref(worker._world)
	worker = null
	desktop = null
	for _frame: int in range(3): await process_frame
	var worker_gone: bool = worker_weak.get_ref() == null
	var adapter_gone: bool = adapter_weak.get_ref() == null
	expect(worker_gone and adapter_gone, context + "dropping retained owner destroys worker and native adapter")
	if worker_gone: workers_destroyed += 1
	if adapter_gone: adapters_destroyed += 1
	if ready and exited and worker_gone and adapter_gone: completed_cycles += 1
	var duration_ms: int = (Time.get_ticks_usec() - started) / 1000
	cycle_durations_ms.append(duration_ms)
	print("PLAY_LIFE006_CYCLE ", JSON.stringify({"rig":str(rig), "cycle":cycle,
		"replacement_rig":str(other), "elapsed_ms":duration_ms, "shutdown_usec":shutdown_usec,
		"completed":ready and exited, "worker_joined":joined,
		"worker_destroyed":worker_gone, "native_adapter_destroyed":adapter_gone,
		"assertions":assertions, "failures":failures}))
	return ready and exited and worker_gone and adapter_gone and failures == 0


func run() -> void:
	var started: int = Time.get_ticks_msec()
	deadline_ms = started + TOTAL_BUDGET_MS
	var rig: StringName = target_rig()
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects one supported mechanical rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	var launcher: Control = load("res://feature_launcher.tscn").instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await process_frame
	for cycle: int in range(CYCLES_PER_RIG):
		if not await run_cycle(rig, cycle): break
	expect(completed_cycles == CYCLES_PER_RIG and builds_completed == CYCLES_PER_RIG * 2
		and resets_completed == CYCLES_PER_RIG and graphs_retired == CYCLES_PER_RIG * 3,
		"all ten real selector/replace/reset/F2 lifetimes complete with three graph retirements each")
	expect(joined_workers == CYCLES_PER_RIG and workers_destroyed == CYCLES_PER_RIG
		and adapters_destroyed == CYCLES_PER_RIG, "every worker joins and every retained owner/adapter dies")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	print("PLAY_LIFE006_RESULT ", JSON.stringify({"rig":str(rig), "assertions":assertions,
		"failures":failures, "cycles_requested":CYCLES_PER_RIG, "cycles_completed":completed_cycles,
		"builds_completed":builds_completed, "resets_completed":resets_completed,
		"graphs_retired":graphs_retired, "workers_joined":joined_workers,
		"workers_destroyed":workers_destroyed, "native_adapters_destroyed":adapters_destroyed,
		"elapsed_ms":Time.get_ticks_msec()-started, "internal_budget_ms":TOTAL_BUDGET_MS,
		"cycle_durations_ms":cycle_durations_ms, "rows":rows,
		"host":"main.tscn+CyberSimulationWorker+main-thread-Rapier", "real_host":true,
		"automated_input":"button signals and Viewport F2 events", "synthetic_world":false,
		"retries":0, "native_jobs_held":false, "rendered_pacing_measured":false,
		"physical_controller_qualified":false, "os_focus_qualified":false,
		"human_feel_qualified":false}))
	quit(0 if failures == 0 else 1)
