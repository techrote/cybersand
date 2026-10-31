extends "res://tests/play_life001_shared_host_case.gd"

# LIFE011 v1 supplements the fifty-real-lifetime baseline. Only OS-focus truth
# is overridden; Main callbacks, native transactions and Rapier are unchanged.
const Session = preload("res://scripts/physical_actor_session.gd")
const LiquidEditor = preload("res://scripts/liquid_comparison_panel.gd")
const MATERIALS: Array[int] = [3,8,12,16,20,21,24,30,32,33,36]
var TOTAL_USEC: int = Watchdogs.microseconds("complex_fixture_seconds")
var OPERATION_USEC: int = Watchdogs.microseconds("operation_seconds")
var FIRST_MAIN_USEC: int = Watchdogs.microseconds("main_ack_seconds")
var desktop: Control
var started_usec: int = 0
var waits: Array[Dictionary] = []
var cohorts: Array[Dictionary] = []
var retired_graphs: int = 0
var next_phase: int = 0
var first_main_ack: Dictionary = {}


class ObservedMain:
	extends "res://scripts/main.gd"
	var phase: String = ""
	var phase_records: Array[Dictionary] = []
	var physics_callbacks: int = 0
	var first_main_process_usec: int = 0

	func _actor_window_has_focus() -> bool:
		return true

	func _process(delta: float) -> void:
		super._process(delta)
		if first_main_process_usec == 0:
			first_main_process_usec = Time.get_ticks_usec()

	func copied_state() -> Dictionary:
		if physical_actor_session == null or latest_snapshot == null:
			return {}
		var view: Dictionary = physical_actor_session.snapshot().actors[0]
		var move: Vector2 = view.get("action", {}).get("move", Vector2.ZERO)
		var position: Vector2 = view.get("position", Vector2.ZERO)
		return {"time_usec":Time.get_ticks_usec(), "worker":simulation_worker.get_instance_id(),
			"session":physical_actor_session.get_instance_id(), "bridge":rapier_bridge.get_instance_id(),
			"run_id":str(view.run_id), "epoch":int(view.epoch),
			"world_generation":int(latest_snapshot.render_world_generation),
			"session_generation":int(tower_context.get("liquid_solver_policy", {}).get("session_generation", -1)),
			"request_serial":_microscenario_request_serial, "native_tick":int(latest_snapshot.tick_index),
			"physics_tick":int(view.tick), "bridge_step":rapier_bridge.manual_step_count(),
			"snapshot_serial":int(latest_snapshot.serial), "backend":str(latest_snapshot.backend_name),
			"native_paused":bool(latest_snapshot.paused), "paused":paused, "suspended":bool(view.suspended),
			"rearm":_actor_input_rearm, "control_generation":int(view.control_generation),
			"sequence":int(view.last_sequence), "accepted_commands":physical_actor_session.accepted_commands,
			"rejected_commands":physical_actor_session.rejected_commands,
			"pending_edges":int(view.pending_input_edges), "move":[move.x, move.y],
			"position":[position.x, position.y], "fault":str(view.get("fault", "")),
			"body_count":physical_actor_session.bodies().size(), "terrain_ready":_physical_terrain_ready,
			"terrain_shapes":rapier_bridge.hard_surface_shape_count(),
			"terrain_pending":rapier_bridge.pending_hard_surface_chunks(), "physics_callbacks":physics_callbacks}

	func _physics_process(delta: float) -> void:
		var before: Dictionary = copied_state() if not phase.is_empty() and phase_records.size() < 3 else {}
		physics_callbacks += 1
		super._physics_process(delta)
		if before.is_empty() or physical_actor_session == null:
			return
		var after: Dictionary = copied_state()
		if after.physics_tick == before.physics_tick + 1 and after.bridge_step == before.bridge_step + 1:
			phase_records.append({"phase":phase, "before":before, "after":after})


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE011: " + message)


func bounded(predicate: Callable, label: String) -> bool:
	var begun: int = Time.get_ticks_usec()
	var deadline: int = mini(begun + OPERATION_USEC, started_usec + TOTAL_USEC)
	var passed: bool = false
	while Time.get_ticks_usec() < deadline:
		if predicate.call():
			passed = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	waits.append({"label":label, "begun":begun, "deadline":deadline,
		"ended":Time.get_ticks_usec(), "passed":passed})
	expect(passed, label)
	return passed


func identity() -> Dictionary:
	if desktop.physical_actor_session != null:
		return desktop.copied_state()
	return {"worker":desktop.simulation_worker.get_instance_id(), "session":0,
		"epoch":desktop._physical_epoch, "world_generation":desktop.latest_snapshot.render_world_generation
			if desktop.latest_snapshot != null else -1, "request_serial":desktop._microscenario_request_serial}


func installed(prior: Dictionary) -> bool:
	return (actor_ready(desktop, target_rig()) and desktop._physical_epoch > int(prior.epoch)
		and desktop.latest_snapshot.render_world_generation > int(prior.world_generation)
		and desktop.rapier_bridge.pending_hard_surface_chunks() == 0
		and desktop.rapier_bridge.hard_surface_shape_count() > 0)


func request_done() -> bool:
	return desktop.pending_microscenario_apply.is_empty()


func rearmed() -> bool:
	return actor_ready(desktop, target_rig()) and not desktop.paused and not desktop._actor_input_rearm \
		and not desktop.physical_actor_session.snapshot().actors[0].suspended


func phase_complete(initial_tick: int) -> bool:
	return desktop.phase_records.size() == 3 and desktop.latest_snapshot.tick_index > initial_tick


func graph() -> Dictionary:
	if desktop.physical_actor_session == null:
		return {}
	return {"session":desktop.physical_actor_session, "bodies":desktop.physical_actor_session.bodies().duplicate(),
		"bridge":desktop.rapier_bridge, "candidate":desktop._accepted_physical_candidate,
		"viewport":desktop._accepted_physical_candidate.viewport if desktop._accepted_physical_candidate != null else null}


func retire_receipt(previous: Dictionary, label: String) -> Dictionary:
	if previous.is_empty():
		return {"prior_graph":false}
	var bodies_retired: bool = true
	for body: Variant in previous.bodies:
		bodies_retired = bodies_retired and not is_instance_valid(body)
	var receipt: Dictionary = {"prior_graph":true, "session_retired":not is_instance_valid(previous.session),
		"bodies_retired":bodies_retired, "body_count":previous.bodies.size(),
		"bridge_shutdown":not previous.bridge.is_initialized(),
		"terrain_shapes":previous.bridge.hard_surface_shape_count(),
		"terrain_pending":previous.bridge.pending_hard_surface_chunks(),
		"body_rids":previous.bridge._body_rids.size(), "viewport_retired":not is_instance_valid(previous.viewport),
		"candidate_retired":previous.candidate == null or (previous.candidate.session == null and previous.candidate.viewport == null)}
	var retired: bool = receipt.session_retired and receipt.bodies_retired and receipt.bridge_shutdown \
		and receipt.terrain_shapes == 0 and receipt.terrain_pending == 0 and receipt.body_rids == 0 \
		and receipt.viewport_retired and receipt.candidate_retired
	expect(retired, label + " prior actual graph and terrain retired")
	if retired:
		retired_graphs += 1
	return receipt


func copied_receipt() -> Dictionary:
	var receipt: Dictionary = desktop.tower_context.get("liquid_construction_receipt", {}).duplicate(true)
	var canonical: PackedByteArray = receipt.get("canonical_bytes", PackedByteArray())
	receipt.erase("canonical_bytes")
	receipt.canonical_hex = canonical.hex_encode()
	return receipt


func applied() -> Dictionary:
	return {"identity":identity(), "policy":desktop.tower_context.get("liquid_solver_policy", {}).duplicate(true),
		"receipt":copied_receipt(), "setup":desktop.microscenario_liquid_setup.duplicate(true),
		"options":desktop.playable_session_options.duplicate(true), "rig":str(desktop.physical_rig_id),
		"recipe_hash":str(desktop.microscenario_definition.get("source_recipe_hash", ""))}


func configure(preset: int, radius: int, normalize: bool) -> Dictionary:
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(target_rig()))
	panel.control_choice.select(1)
	panel.rule_choice.select(0)
	panel.camera_choice.select(0)
	panel.policy_editor.select_preset(preset)
	panel.policy_editor.geometry_picker.select(1 if radius == 3 else 0)
	panel.policy_editor.normalize_water.button_pressed = normalize
	return {"selection":panel.selection(), "policy":panel.policy_editor.requested_policy.duplicate(),
		"preset":preset, "radius":radius, "normalize":normalize,
		"label":str(LiquidEditor.PRESETS[preset].label)}


func verify_applied(request: Dictionary, value: Dictionary, label: String) -> void:
	var policy: Dictionary = value.policy
	var receipt: Dictionary = value.receipt
	expect(policy.get("envelope", PackedInt32Array()) == request.policy
		and policy.get("policy_hash", "") == receipt.get("policy_hash", "missing")
		and receipt.get("kind", "") == "applied_run", label + " actual policy and receipt bind requested envelope")
	var expected: Dictionary = {}
	for material: int in MATERIALS:
		expected[material] = ["freemass_v1" if material == 3 else "cellular_yield_v1", "reference"]
	for assignment: Array in LiquidEditor.PRESETS[int(request.preset)].assignments:
		expected[int(assignment[0])] = [assignment[1], assignment[2]]
	var materials: Array[int] = []
	for assignment: Dictionary in policy.get("assignments", []):
		materials.append(int(assignment.material))
		var wanted: Array = expected.get(int(assignment.material), [])
		expect(wanted.size() == 2 and assignment.requested_family == wanted[0]
			and assignment.applied_family == wanted[0] and assignment.applied_variant == wanted[1],
			label + " material " + str(assignment.material) + " exact requested and applied family/variant")
	expect(materials == MATERIALS and policy.get("refusal") == null, label + " complete admitted material policy")
	expect(int(policy.get("maximum_rule_radius", -1)) == int(request.radius)
		and int(receipt.get("maximum_rule_radius", -1)) == int(request.radius)
		and int(value.setup.get("maximum_rule_radius", -1)) == int(request.radius)
		and value.setup.get("normalization", "") == ("water-normalize-v1" if request.normalize else ""),
		label + " geometry and explicit normalization remain applied")
	expect(int(policy.get("session_generation", -1)) == int(receipt.get("session_generation", -2))
		and int(policy.get("session_generation", -1)) == int(value.identity.world_generation),
		label + " native session receipt and current publication generation agree")
	var has_inertial: bool = int(request.preset) >= 5
	expect(int(policy.get("physical_state_hash_version", -1)) == (3 if has_inertial else 2)
		and int(policy.get("physical_state_format_version", -1)) == (3 if has_inertial else 2)
		and int(receipt.get("physical_state_hash_version", -1)) == (3 if has_inertial else 2),
		label + " actual instance hash/CYPS law identity")
	if has_inertial:
		expect(policy.get("family_parameters", {}).get("inertial_cellular_v1", {}).get("readback_source", "") == "applied_world",
			label + " IN parameters are read from applied World")
	expect(value.rig == str(target_rig()) and value.options == {"controls":"keyboard", "rules":"lap", "camera":"follow"}
		and value.recipe_hash == str(Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0).source_recipe_hash)
		and desktop.microscenario_definition.rectangles == Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0).rectangles,
		label + " authored rig course and composed options survive")
	expect(receipt.get("run_intent", "") == "exploratory" and not bool(receipt.get("eligible_for_full_matched_evidence", true))
		and int(receipt.get("initial_body_count", 0)) == int(value.identity.body_count),
		label + " actual initial masks remain exploratory without full scientific qualification")


func live_progress(label: String) -> Dictionary:
	var before: Dictionary = identity()
	release_controls()
	desktop.playable_session_panel.resume_play()
	if not await bounded(rearmed, label + ": neutral rearm"):
		return {}
	var first: Dictionary = identity()
	var code: Key = KEY_D if target_rig() == &"acrobat" else KEY_W
	var movement: Array = [1.0, 0.0] if target_rig() == &"acrobat" else [0.0, -1.0]
	next_phase += 1
	desktop.phase = "%02d:%s" % [next_phase, label]
	desktop.phase_records.clear()
	parse_key(code, true)
	var ready: bool = await bounded(Callable(self, "phase_complete").bind(int(first.native_tick)), label + ": completed native and nonneutral Rapier steps")
	var records: Array = desktop.phase_records.duplicate(true)
	desktop.phase = ""
	parse_key(code, false)
	var after: Dictionary = identity()
	expect(ready and records.size() == 3 and after.native_tick > first.native_tick
		and after.physics_tick >= first.physics_tick + 3, label + " actual automatic progress completes")
	for record: Dictionary in records:
		expect(record.after.move == movement and not record.after.rearm and not record.after.paused
			and not record.after.suspended and record.after.accepted_commands > record.before.accepted_commands,
			label + " completed physical step carries admitted nonneutral input")
	return {"before":before, "started":first, "after":after, "records":records, "expected_move":movement, "completed":ready}


func reject_packet(packet: Dictionary, reason: String) -> Dictionary:
	var before: Dictionary = identity()
	var accepted: bool = desktop.physical_actor_session.submit(packet, &"human")
	var actual: String = desktop.physical_actor_session.last_error
	var after: Dictionary = identity()
	expect(not accepted and actual == reason and after.accepted_commands == before.accepted_commands
		and after.rejected_commands == before.rejected_commands + 1 and after.sequence == before.sequence,
		"stale packet rejected specifically: " + reason)
	return {"packet":packet.duplicate(true), "accepted":accepted, "reason":actual, "before":before, "after":after}


func refusal(request: Dictionary, kind: String) -> Dictionary:
	var before: Dictionary = applied()
	var old_graph: Dictionary = graph()
	var submitted: PackedInt32Array = request.policy.duplicate()
	var radius: int = int(request.radius)
	var expected_reason: String = "malformed_policy: inertial_cellular_v1 requires complete execution radius three"
	if kind == "oil_pressure":
		# Public host bypass of the disabled UI choice exercises native refusal.
		submitted[20 + MATERIALS.find(16) * 3 + 1] = 3
		submitted[20 + MATERIALS.find(16) * 3 + 2] = 0
		expected_reason = "combination_rejected"
	else:
		radius = 2
	var queued: bool = desktop.apply_playable_session(request.selection, submitted, bool(request.normalize), radius)
	expect(queued, kind + " reaches existing native construction transaction")
	if not queued:
		return {}
	var candidate = desktop._pending_physical_candidate
	var candidate_session = candidate.session if candidate != null else null
	var candidate_viewport = candidate.viewport if candidate != null else null
	expect(candidate != null and candidate_session != old_graph.session
		and desktop.physical_actor_session == old_graph.session, kind + " stages graph while valid owner remains installed")
	var finished: bool = await bounded(request_done, kind + ": native terminal refusal")
	var after: Dictionary = applied()
	var error: String = desktop.microscenario_error
	var candidate_retired: bool = not is_instance_valid(candidate_session) and not is_instance_valid(candidate_viewport)
	expect(finished and error.contains(expected_reason), kind + " intended native refusal reason")
	expect(candidate_retired and desktop._pending_physical_candidate == null
		and desktop.physical_actor_session == old_graph.session
		and before.identity.epoch == after.identity.epoch
		and before.identity.world_generation == after.identity.world_generation
		and before.policy == after.policy and before.receipt == after.receipt
		and before.setup == after.setup and before.options == after.options,
		kind + " refused graph retires and accepted World graph policy receipt and options survive")
	return {"kind":kind, "requested_policy":submitted, "radius":radius, "normalize":request.normalize,
		"before":before, "after":after, "queued":queued, "finished":finished,
		"error":error, "candidate_retired":candidate_retired}


func exercise(preset: int) -> bool:
	var failures_before: int = failures
	var request: Dictionary = configure(preset, 3 if preset >= 5 else 2, preset in [1,5])
	var row: Dictionary = {"preset":preset, "request":request, "before":identity(), "refusals":[]}
	cohorts.append(row)
	var old_graph: Dictionary = graph()
	var retained: CyberSimulationSnapshot = desktop.latest_snapshot
	var retained_context: Dictionary = retained.lab_context.duplicate(true) if retained != null else {}
	var retained_serial: int = retained.serial if retained != null else -1
	var queued: bool = desktop.playable_session_panel.build_selected()
	expect(queued, "preset%d composed build queues" % preset)
	if not queued or not await bounded(Callable(self, "installed").bind(row.before), "preset%d build acknowledgement" % preset):
		return false
	row.build_retirement = retire_receipt(old_graph, "preset%d build" % preset)
	row.build = applied()
	verify_applied(request, row.build, "preset%d build" % preset)
	row.build_progress = await live_progress("preset%d build" % preset)
	if row.build_progress.is_empty() or failures != failures_before:
		return false
	var view: Dictionary = desktop.physical_actor_session.observation(0)
	var old_packet: Dictionary = Session.make_command(view, int(view.last_sequence) + 1, {"move":Vector2.RIGHT})
	row.before_reset = identity()
	old_graph = graph()
	# Unsubmitted policy/geometry/normalization changes cannot affect Restart.
	row.unsubmitted = configure(0 if preset != 0 else 6, 2 if preset >= 5 else 3, not bool(request.normalize))
	desktop.playable_session_panel.restart_applied()
	if not await bounded(Callable(self, "installed").bind(row.before_reset), "preset%d reset acknowledgement" % preset):
		return false
	row.reset_retirement = retire_receipt(old_graph, "preset%d reset" % preset)
	row.reset = applied()
	verify_applied(request, row.reset, "preset%d reset" % preset)
	expect(row.reset.policy.policy_hash == row.build.policy.policy_hash, "reset retains exact selected policy identity")
	row.reset_progress = await live_progress("preset%d reset" % preset)
	if row.reset_progress.is_empty():
		return false
	row.old_owner = reject_packet(old_packet, "run_or_epoch")
	view = desktop.physical_actor_session.observation(0)
	var stale_generation: Dictionary = Session.make_command(view, int(view.last_sequence) + 1, {"move":Vector2.RIGHT})
	row.generation_before_cancel = identity()
	desktop.cancel_playable_course_input()
	row.generation_after_cancel = identity()
	expect(row.generation_after_cancel.control_generation > row.generation_before_cancel.control_generation,
		"actual host revokes the existing input generation")
	row.old_generation = reject_packet(stale_generation, "observation_not_issued")
	view = desktop.physical_actor_session.observation(0)
	var fresh: Dictionary = Session.make_command(view, int(view.last_sequence) + 1, {"move":Vector2.RIGHT})
	var before_fresh: Dictionary = identity()
	var fresh_admitted: bool = desktop.physical_actor_session.submit(fresh, &"human")
	row.fresh_control = {"packet":fresh, "before":before_fresh, "after":identity(), "accepted":fresh_admitted}
	expect(fresh_admitted and row.fresh_control.after.accepted_commands == before_fresh.accepted_commands + 1,
		"fresh same-owner observation is admitted as the matched positive control")
	desktop.playable_session_panel.show_selection()
	var refused: Dictionary = await refusal(request, "oil_pressure")
	row.refusals.append(refused)
	if refused.is_empty():
		return false
	if preset >= 5:
		refused = await refusal(request, "inertial_radius_two")
		row.refusals.append(refused)
		if refused.is_empty():
			return false
	row.retained_progress = await live_progress("preset%d after refusal" % preset)
	row.retained_snapshot_unchanged = retained == null or (retained.serial == retained_serial and retained.lab_context == retained_context)
	expect(row.retained_snapshot_unchanged, "older published snapshot policy and receipt remain immutable")
	row.complete = failures == failures_before and not row.retained_progress.is_empty()
	print("PLAY_LIFE011_PROGRESS preset=", preset, " complete=", row.complete, " assertions=", assertions, " failures=", failures)
	return row.complete


func run() -> void:
	started_usec = Time.get_ticks_usec()
	release_controls()
	var main_origin: int = Time.get_ticks_usec()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	root.add_child(desktop)
	var main_deadline: int = main_origin + FIRST_MAIN_USEC
	while desktop.first_main_process_usec == 0 and Time.get_ticks_usec() < main_deadline:
		await process_frame
	first_main_ack = {"origin":"before-main-scene-load", "event":"first-inherited-Main-process-return",
		"origin_usec":main_origin, "deadline_usec":main_deadline,
		"acknowledged_usec":desktop.first_main_process_usec, "observed_usec":Time.get_ticks_usec()}
	var acknowledged: bool = first_main_ack.acknowledged_usec > main_origin \
		and first_main_ack.acknowledged_usec <= main_deadline and first_main_ack.observed_usec <= main_deadline
	first_main_ack.passed = acknowledged
	expect(acknowledged, "first actual Main callback acknowledged within configured Main acknowledgement watchdog")
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = acknowledged and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready and target_rig() in Course.MECHANICAL_PRESETS, "real exclusive worker and registered mechanical wrapper")
	if ready:
		for preset: int in range(LiquidEditor.PRESETS.size()):
			if not await exercise(preset):
				ready = false
				break
	expect(ready and cohorts.size() == 8 and not worker.has_failed(), "all eight preset construction/reset/refusal cohorts finish")
	var final_graph: Dictionary = graph()
	var final_state: Dictionary = identity()
	var close_started: int = Time.get_ticks_usec()
	var final_session = desktop.physical_actor_session
	await close_cycle(desktop, worker, final_session, "LIFE011: ")
	var retirement: Dictionary = retire_receipt(final_graph, "final shutdown")
	var joined: bool = not worker._thread.is_started()
	var destroyed: bool = false
	var adapter_destroyed: bool = false
	if joined:
		# Native adapter identity is read only after join; no World method call.
		var worker_weak: WeakRef = weakref(worker)
		var adapter_weak: WeakRef = weakref(worker._world)
		worker = null
		desktop = null
		for _frame: int in range(3):
			await process_frame
		destroyed = worker_weak.get_ref() == null
		adapter_destroyed = adapter_weak.get_ref() == null
	var close_ended: int = Time.get_ticks_usec()
	expect(joined and destroyed and adapter_destroyed, "joined exclusive owner and native adapter are destroyed")
	expect(close_ended - close_started <= OPERATION_USEC, "teardown within configured operation watchdog")
	expect(close_ended - started_usec <= TOTAL_USEC, "whole fixture within configured fixture watchdog")
	var artifact_dir: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	expect(not artifact_dir.is_empty(), "runner supplies original raw artifact directory")
	var result: Dictionary = {"schema":"play-life011-v1", "source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"fixture_sha256":FileAccess.get_sha256("res://tests/play_life011_solver_case.gd"),
		"preset_source_sha256":FileAccess.get_sha256("res://scripts/liquid_comparison_panel.gd"),
		"rig":str(target_rig()), "platform":OS.get_name(), "godot":Engine.get_version_info(), "display_server":DisplayServer.get_name(),
		"started_usec":started_usec, "ended_usec":close_ended, "elapsed_usec":close_ended-started_usec,
		"operation_limit_usec":OPERATION_USEC, "fixture_limit_usec":TOTAL_USEC,
		"first_main_ack_limit_usec":FIRST_MAIN_USEC, "first_main_ack":first_main_ack,
		"assertions":assertions, "failures":failures, "waits":waits, "cohorts":cohorts,
		"retired_graphs":retired_graphs, "final_state":final_state,
		"teardown":{"started_usec":close_started, "ended_usec":close_ended, "worker_joined":joined,
			"worker_destroyed":destroyed, "adapter_destroyed":adapter_destroyed, "retirement":retirement},
		"host":"main.tscn+CyberSimulationWorker+main-thread-Rapier", "real_host":true,
		"automatic_callbacks":true, "manual_physics_calls":0, "focus_seam":true,
		"physical_devices_qualified":false, "rendered_fps_measured":false, "retries":0}
	var artifact: String = str(target_rig()) + "-life011.json"
	var output: String = artifact_dir.path_join(artifact)
	if not artifact_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(artifact_dir)
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result) + "\n")
			file.close()
		else:
			expect(false, "original raw result is written")
	print("PLAY_LIFE011_RESULT ", JSON.stringify({"schema":"play-life011-summary-v1", "rig":str(target_rig()),
		"assertions":assertions, "failures":failures, "source_revision":result.source_revision,
		"artifact":artifact, "sha256":FileAccess.get_sha256(output) if FileAccess.file_exists(output) else "",
		"cohorts":cohorts.size(), "elapsed_usec":result.elapsed_usec}))
	quit(0 if failures == 0 else 1)
