extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-LIFE-009: real automatic Main/native/Rapier callbacks. The only positive
# path seam is OS focus. The deliberately dropped-input phase is a negative
# control, never a gameplay success. No manual physics calls or owner rebuilds.
const Session = preload("res://scripts/physical_actor_session.gd")
const OBSERVE_USEC: int = 350000
const MAX_RECORDS: int = 512
var desktop: Control
var row: Dictionary = {}
var fixture_started_usec: int = 0


class ObservedMain:
	extends "res://scripts/main.gd"
	var phase: String = "setup"
	var drop_input: bool = false
	var main_callbacks: int = 0
	var physics_callbacks: int = 0
	var in_physics: bool = false
	var prepared: Dictionary = {}
	var records: Array[Dictionary] = []
	var overflow: bool = false
	var stale_pending: Dictionary = {}
	var stale_receipt: Dictionary = {}

	func _actor_window_has_focus() -> bool:
		return true

	func _process(delta: float) -> void:
		main_callbacks += 1
		super._process(delta)

	func _publish_physical_keyboard_input(trigger_override: Variant = null,
			alternate_override: Variant = null) -> void:
		if drop_input:
			return
		var prior: int = physical_actor_session.accepted_commands if physical_actor_session != null else -1
		super._publish_physical_keyboard_input(trigger_override, alternate_override)
		if in_physics and physical_actor_session != null and physical_actor_session.accepted_commands > prior:
			var view: Dictionary = physical_actor_session.snapshot().actors[0]
			var move: Vector2 = physical_actor_session._commands[0].get("move", Vector2.ZERO)
			prepared = {"sequence":int(view.last_sequence), "control_generation":int(view.control_generation),
				"admitted_tick":int(view.tick), "move":[move.x, move.y]}

	func state() -> Dictionary:
		if physical_actor_session == null or latest_snapshot == null:
			return {}
		# snapshot() is the copied, non-issuing observation; recording cannot
		# mint a command lease or reach across the native-worker boundary.
		var view: Dictionary = physical_actor_session.snapshot().actors[0]
		var move: Vector2 = view.get("action", {}).get("move", Vector2.ZERO)
		var position: Vector2 = view.get("position", Vector2.INF)
		return {"time_usec":Time.get_ticks_usec(), "worker":simulation_worker.get_instance_id(),
			"session":physical_actor_session.get_instance_id(), "bridge":rapier_bridge.get_instance_id(),
			"run_id":str(view.run_id), "epoch":int(view.epoch),
			"world_generation":int(latest_snapshot.render_world_generation),
			"native_backend":str(latest_snapshot.backend_name),
			"physics_tick":int(view.tick), "bridge_step":rapier_bridge.manual_step_count(),
			"native_tick":int(latest_snapshot.tick_index), "snapshot_serial":int(latest_snapshot.serial),
			"native_paused":bool(latest_snapshot.paused), "paused":paused,
			"suspended":bool(view.suspended), "rearm":_actor_input_rearm,
			"control_generation":int(view.control_generation), "sequence":int(view.last_sequence),
			"pending_edges":int(view.pending_input_edges), "move":[move.x,move.y],
			"position":[position.x,position.y], "fault":str(view.get("fault", "")),
			"main_callbacks":main_callbacks, "physics_callbacks":physics_callbacks,
			"accepted_commands":physical_actor_session.accepted_commands,
			"lap_ticks":int(_playable_course_progress.elapsed_ticks)}

	func _physics_process(delta: float) -> void:
		physics_callbacks += 1
		var before: Dictionary = state()
		prepared = {}
		in_physics = true
		super._physics_process(delta)
		in_physics = false
		if phase == "setup" or before.is_empty() or physical_actor_session == null:
			return
		var after: Dictionary = state()
		if phase == "held" and not after.suspended and not stale_pending.is_empty():
			var accepted: int = physical_actor_session.accepted_commands
			var rejected: int = physical_actor_session.rejected_commands
			var admitted: bool = physical_actor_session.submit(stale_pending, &"human")
			stale_receipt = {"accepted":admitted, "reason":physical_actor_session.last_error,
				"accepted_delta":physical_actor_session.accepted_commands-accepted,
				"rejected_delta":physical_actor_session.rejected_commands-rejected,
				"observed_tick":int(stale_pending.observed_tick), "actual_tick":int(after.physics_tick),
				"sequence_before":int(after.sequence),
				"sequence_after":int(physical_actor_session.snapshot().actors[0].last_sequence)}
			stale_pending = {}
		if records.size() >= 512:
			overflow = true
			return
		records.append({"phase":phase, "dropped_input_control":drop_input,
			"before":before, "after":after, "prepared":prepared.duplicate(true)})


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE009: " + message)


func bounded(predicate: Callable, message: String) -> bool:
	var start: int = Time.get_ticks_usec()
	var deadline: int = mini(start + WAIT_TIMEOUT_MS * 1000, fixture_started_usec + 150000000)
	var ok: bool = false
	while Time.get_ticks_usec() < deadline:
		if predicate.call():
			ok = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	row.waits.append({"name":message, "started_usec":start, "deadline_usec":deadline,
		"ended_usec":Time.get_ticks_usec(), "passed":ok})
	expect(ok, message)
	return ok


func records_for(phase: String, completed_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in desktop.records:
		if record.phase != phase:
			continue
		if not completed_only or (record.after.physics_tick == record.before.physics_tick + 1
			and record.after.bridge_step == record.before.bridge_step + 1):
			result.append(record)
	return result


func phase_complete(phase: String, count: int) -> bool:
	return records_for(phase, true).size() >= count


func pause_acknowledged() -> bool:
	var value: Dictionary = desktop.state()
	return (value.paused and value.native_paused and value.suspended and value.rearm
		and value.snapshot_serial > row.pre_pause.snapshot_serial)


func input_rearmed() -> bool:
	return not desktop._actor_input_rearm


func observe_completed(phase: String, count: int = 4) -> bool:
	var complete: bool = await bounded(Callable(self, "phase_complete").bind(phase, count),
		phase + ": automatic completed Rapier steps")
	return complete


func same_owner(reference: Dictionary, value: Dictionary) -> bool:
	for key: String in ["worker", "session", "bridge", "run_id", "epoch", "world_generation"]:
		if value.get(key) != reference.get(key):
			return false
	return true


func test_sequence(rig: StringName) -> bool:
	var course_ok: bool = desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0)
	expect(course_ok, "normal authored course admission")
	if not course_ok or not await bounded(Callable(self, "course_installed").bind(desktop), "course acceptance"):
		return false
	var actor_ok: bool = desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(rig)), &"human", false)
	expect(actor_ok, "normal SetP construction admission")
	if not actor_ok or not await bounded(Callable(self, "actor_ready").bind(desktop, rig), "actor and terrain acceptance"):
		return false
	row.identity = desktop.state()
	row.recipe_hash = str(desktop.microscenario_definition.source_recipe_hash)
	row.worker_capacity = int(desktop.latest_snapshot.scheduler_thread_capacity_hint)
	expect(desktop.paused, "new configuration starts paused")
	parse_key(KEY_P, true)
	parse_key(KEY_P, false)
	if not await bounded(Callable(self, "clocks_advanced").bind(desktop, rig,
		int(row.identity.physics_tick), int(row.identity.native_tick)), "automatic neutral start"):
		return false

	var code: Key = KEY_D if rig == &"acrobat" else KEY_W
	var expected_move: Array = [1.0, 0.0] if rig == &"acrobat" else [0.0, -1.0]
	row.expected_move = expected_move
	# Negative control: ticking bodies and a pressed key are insufficient proof
	# of input application. Suppress only publication, with neutral old commands.
	desktop.phase = "dropped"
	desktop.drop_input = true
	parse_key(code, true)
	if not await observe_completed("dropped"):
		return false
	for record: Dictionary in records_for("dropped", true):
		expect(record.prepared.is_empty() and record.after.move == [0.0, 0.0],
			"dropped-input contrast cannot claim a consumed nonneutral action")
	parse_key(code, false)
	desktop.drop_input = false
	desktop.phase = "neutral_before"
	if not await observe_completed("neutral_before", 2):
		return false

	desktop.phase = "active"
	parse_key(code, true)
	if not await observe_completed("active"):
		return false
	for record: Dictionary in records_for("active", true):
		expect(not record.prepared.is_empty() and record.prepared.move == expected_move
			and record.after.move == expected_move and record.prepared.sequence == record.after.sequence
			and record.prepared.control_generation == record.after.control_generation,
			"same automatic callback admits a nonneutral action and completes its actual Rapier step")

	var view: Dictionary = desktop.physical_actor_session.observation(0)
	desktop.stale_pending = Session.make_command(view, int(view.last_sequence) + 100000,
		{"move":Vector2.RIGHT}, Session.MAX_LEASE)
	row.pre_pause = desktop.state()
	# Populate real ordered quick-tap edges, then pause synchronously before the
	# next physics callback can consume them. The movement key stays held.
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	row.queued_edges_before_pause = desktop.physical_actor_session._button_edges[0].duplicate(true)
	expect(row.queued_edges_before_pause.size() == 2, "actual pending quick-tap edges exist before pause")
	desktop.phase = "pausing"
	parse_key(KEY_P, true)
	parse_key(KEY_P, false)
	var acknowledged: bool = await bounded(Callable(self, "pause_acknowledged"),
		"new native publication acknowledges pause")
	if not acknowledged:
		return false
	row.pause_ack = desktop.state()
	expect(row.pause_ack.pending_edges == 0 and row.pause_ack.control_generation > row.pre_pause.control_generation,
		"pause revokes prior input generation and clears queued button edges")
	desktop.phase = "paused"
	var until: int = Time.get_ticks_usec() + OBSERVE_USEC
	while Time.get_ticks_usec() < until:
		await process_frame
	row.pause_end = desktop.state()
	var paused_records: Array[Dictionary] = records_for("paused")
	expect(paused_records.size() >= 8, "pause is observed across multiple automatic physics callbacks")
	for record: Dictionary in paused_records:
		var value: Dictionary = record.after
		expect(same_owner(row.pause_ack, value) and value.paused and value.native_paused and value.suspended
			and value.physics_tick == row.pause_ack.physics_tick and value.bridge_step == row.pause_ack.bridge_step
			and value.native_tick == row.pause_ack.native_tick and value.pending_edges == 0
			and value.position == row.pause_ack.position and value.lap_ticks == row.pause_ack.lap_ticks,
			"acknowledged healthy owner remains quiescent without rebuilding or disabling callbacks")
	expect(row.pause_end.main_callbacks > row.pause_ack.main_callbacks,
		"Main continues processing while the simulation and Rapier are paused")

	desktop.phase = "held"
	parse_key(KEY_P, true)
	parse_key(KEY_P, false)
	if not await observe_completed("held"):
		return false
	for record: Dictionary in records_for("held", true):
		expect(record.after.rearm and record.prepared.is_empty() and record.after.move == [0.0, 0.0]
			and record.after.pending_edges == 0, "held pre-pause input cannot resume actuation")
	row.stale_refusal = desktop.stale_receipt.duplicate(true)
	expect(not row.stale_refusal.is_empty() and not row.stale_refusal.get("accepted", true)
		and row.stale_refusal.get("reason", "") == "observation_not_issued"
		and int(row.stale_refusal.get("accepted_delta", -1)) == 0
		and int(row.stale_refusal.get("rejected_delta", -1)) == 1,
		"still-in-range pre-pause observation is rejected by its revoked authority, not by timeout")

	desktop.phase = "neutral_after"
	parse_key(code, false)
	if not await bounded(Callable(self, "input_rearmed"), "release restores neutral input admission"):
		return false
	desktop.phase = "fresh"
	parse_key(code, true)
	if not await observe_completed("fresh"):
		return false
	for record: Dictionary in records_for("fresh", true):
		expect(not record.prepared.is_empty() and record.prepared.move == expected_move
			and record.after.move == expected_move and record.prepared.sequence == record.after.sequence
			and record.after.control_generation > row.pre_pause.control_generation,
			"fresh post-release input is applied in a completed step under the new control generation")
	row.final = desktop.state()
	expect(row.final.native_tick > row.pause_end.native_tick, "native ticks actually resume")
	for record: Dictionary in desktop.records:
		expect(same_owner(row.identity, record.after) and record.after.fault.is_empty(),
			"every observation retains the same healthy native/physical owner identity")
	expect(not desktop.overflow and not desktop.simulation_worker.has_failed(), "bounded capture and no native quarantine")
	return true


func target_rig() -> StringName:
	return &"" # Every discoverable wrapper overrides this; empty is refused.


func run() -> void:
	fixture_started_usec = Time.get_ticks_usec()
	var rig: StringName = target_rig()
	row = {"rig":str(rig), "waits":[], "expected_move":[], "records":[]}
	release_controls()
	expect(ClassDB.class_exists("CyberNativeCellWorld"), "native backend class is present")
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects a mechanical SetP rig")
	expect(Input.get_connected_joypads().is_empty(), "keyboard-only fixture refuses unexpected connected hardware")
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var success: bool = false
	if worker != null and desktop.worker_start_error == OK and worker._thread.is_started() and failures == 0:
		success = await test_sequence(rig)
	else:
		expect(false, "the real native worker must start")
	row.records = desktop.records.duplicate(true)
	row.capture_overflow = desktop.overflow
	row.completed = success and failures == 0
	desktop.phase = "setup"
	var session: Variant = desktop.physical_actor_session
	await close_cycle(desktop, worker, session, "LIFE009: ")
	print("PLAY_LIFE009_RESULT ", JSON.stringify({"schema":"play-life009-v1",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_server":DisplayServer.get_name(), "physics_engine":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"assertions":assertions, "failures":failures, "rig":str(rig), "row":row,
		"elapsed_usec":Time.get_ticks_usec()-fixture_started_usec,
		"worker_joined":joined_workers == 1, "session_retired":retired_sessions == 1,
		"real_host":true, "automatic_callbacks":true, "headless_focus_seam":true,
		"input_suppression_is_negative_control":true, "manual_physics_calls":0,
		"retries":0, "rendered_fps_measured":false, "physical_devices_qualified":false,
		"human_feel_qualified":false, "shader_startup_qualified":false}))
	quit(0 if row.completed and failures == 0 else 1)
