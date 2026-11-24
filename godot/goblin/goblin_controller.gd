extends Node

## Opt-in campaign owner. The policy proposes; the adapter acts; independent
## assertions inspect copied application evidence. No normal scene loads this.
signal changed
signal action_started(action: Dictionary)
signal action_observed(record: Dictionary)
signal finished(transcript: Dictionary)

const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Policy = preload("res://goblin/goblin_policy.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const OUTPUT_DIR := "user://goblin"
const TRANSCRIPT_PATH := "user://goblin/transcript.json"
const SUMMARY_PATH := "user://goblin/summary.json"
const REPLAY_RESULT_PATH := "user://goblin/replay-result.json"
const MAX_CAMPAIGN_MSEC := 150000
const MAX_PROFILE_RUNS := 64

var adapter: Node
var policy: RefCounted
var assertions: RefCounted
var transcript: Dictionary = {}
var replay_result: Dictionary = {}
var state := "idle"
var goal := "Choose a fixture and let goblin explore"
var latest_action := ""
var latest_observation: Dictionary = {}
var last_error := ""
var running := false
var decisions_paused := false
var stop_requested := false
var completed := 0
var attempted := 0
var budget := 0
var export_path := ""
var _started_msec := 0
var _frame_previous_usec := 0
var _frame_samples: Array[int] = []
var _run_serial := 0
var _run_archive := ""
var _decision_pause_msec := 0
var _pacing_msec := 0


static func read_launch() -> Dictionary:
	var profile: Dictionary = Adapter.verify_profile()
	if not profile.get("ok", false): return profile
	var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(profile.root).path_join("goblin-profile.json")))
	if not marker is Dictionary or not marker.get("launch") is Dictionary or not marker.get("provenance") is Dictionary:
		return {"ok": false, "error": "isolated profile does not contain a launch record"}
	return {"ok": true, "launch": marker.launch, "provenance": marker.provenance, "profile": profile}


static func same_identity(recorded: Variant, current: Variant) -> bool:
	# JSON numbers re-enter Godot as floats; an in-memory tape normalizes whole
	# numbers to ints. Compare every identity field in the same canonical form.
	if not recorded is Dictionary or not current is Dictionary: return false
	return JSON.stringify(Transcript._json_value(recorded), "", true) \
		== JSON.stringify(Transcript._json_value(current), "", true)


static func read_replay() -> Dictionary:
	var profile: Dictionary = Adapter.verify_profile()
	if not profile.get("ok", false): return profile
	var path: String = str(profile.root).path_join("goblin-replay.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "error": "No selected transcript in this isolated profile"}
	if file.get_length() > Transcript.MAX_BYTES:
		return {"ok": false, "error": "Selected transcript exceeds the fixed byte budget"}
	var tape: Variant = JSON.parse_string(file.get_as_text())
	var valid: Dictionary = Transcript.validate(tape)
	if not valid.ok: return {"ok": false, "error": "Transcript validation failed", "details": valid.errors}
	return {"ok": true, "transcript": tape}


static func read_reproduction(provenance: Dictionary) -> Dictionary:
	var profile: Dictionary = Adapter.verify_profile()
	if not profile.get("ok", false): return profile
	var file := FileAccess.open(str(profile.root).path_join("goblin-reproduction.json"), FileAccess.READ)
	if file == null or file.get_length() > Transcript.MAX_BYTES:
		return {"ok": false, "error": "bounded reproduction fixture is missing or oversized"}
	var plan: Variant = JSON.parse_string(file.get_as_text())
	if not plan is Dictionary or plan.get("schema") != "cybersand-goblin-action-fixture-v1" \
		or not plan.get("header") is Dictionary or not plan.get("actions") is Array:
		return {"ok": false, "error": "unknown reproduction fixture format"}
	if not same_identity(plan.header.get("provenance", {}), provenance) or int(plan.header.get("fixture_version", -1)) != Fixtures.VERSION:
		return {"ok": false, "error": "reproduction source/runtime/fixture identity differs"}
	if plan.actions.is_empty() or plan.actions.size() > 256:
		return {"ok": false, "error": "reproduction requires 1..256 bounded game actions"}
	for action: Variant in plan.actions:
		if not Transcript.validate_action(action).ok or not Adapter.validate_action(action).ok:
			return {"ok": false, "error": "reproduction contains an invalid game action"}
	return {"ok": true, "plan": plan}


func _process(_delta: float) -> void:
	if not running: return
	var now: int = Time.get_ticks_usec()
	if _frame_previous_usec > 0 and _frame_samples.size() < 50000:
		_frame_samples.append(now - _frame_previous_usec)
	_frame_previous_usec = now


func run_campaign(configuration: Dictionary, provenance: Dictionary, replay: Dictionary = {}, reproduction: Dictionary = {}) -> Dictionary:
	if running: return {"error": "goblin already has a campaign"}
	var config := configuration.duplicate(true)
	var replay_actions: Array = []
	if not replay.is_empty() and not reproduction.is_empty(): return {"error": "choose one replay mode"}
	if not replay.is_empty():
		var valid: Dictionary = Transcript.validate(replay)
		if not valid.ok: return {"error": "selected transcript is invalid", "details": valid.errors}
		if replay.header.get("fixture_state", "installed") != "installed" or replay.steps.is_empty():
			return {"error": "selected transcript did not install a fixture and dispatch game actions"}
		if not same_identity(replay.header.get("provenance", {}), provenance):
			return {"error": "exact replay requires the recorded source snapshot and runtime identities"}
		if int(replay.header.get("fixture_version", -1)) != Fixtures.VERSION:
			return {"error": "exact replay requires the recorded fixture version"}
		replay_actions = Transcript.replay_actions(replay)
		config.fixture_id = replay.header.fixture_id
		config.policy = replay.header.policy
		config.seed = int(replay.header.seed)
		config.budget = maxi(1, replay_actions.size())
	if not reproduction.is_empty():
		if reproduction.get("schema") != "cybersand-goblin-action-fixture-v1" \
			or not reproduction.get("header") is Dictionary or not reproduction.get("actions") is Array \
			or not same_identity(reproduction.header.get("provenance", {}), provenance) \
			or int(reproduction.header.get("fixture_version", -1)) != Fixtures.VERSION:
			return {"error": "reproduction identity differs"}
		for action: Variant in reproduction.actions:
			if not Transcript.validate_action(action).ok or not Adapter.validate_action(action).ok:
				return {"error": "invalid bounded reproduction action"}
		replay_actions = reproduction.actions.duplicate(true)
		config.fixture_id = reproduction.header.get("fixture_id", "")
		config.policy = reproduction.header.get("policy", "CONTROL")
		config.seed = reproduction.header.get("seed", 0)
		config.budget = replay_actions.size()
	var prescribed: bool = not replay.is_empty() or not reproduction.is_empty()
	if _run_serial >= MAX_PROFILE_RUNS:
		return {"error": "this disposable profile reached its 64-campaign budget; launch a fresh profile"}
	if config.get("fixture_id") not in Fixtures.ids() or config.get("policy") not in Policy.PERSONALITIES:
		return {"error": "unknown committed fixture or personality"}
	if not Adapter._integer(config.get("budget"), 1, 256) \
		or not Adapter._integer(config.get("seed"), -2147483648, 2147483647) \
		or not Adapter._integer(config.get("pacing_ms", 0), 0, 3000):
		return {"error": "campaign options are outside their fixed bounds"}
	running = true
	decisions_paused = false
	stop_requested = false
	completed = 0
	attempted = 0
	budget = int(config.budget)
	last_error = ""
	replay_result.clear()
	export_path = ""
	_frame_samples.clear()
	_frame_previous_usec = 0
	_decision_pause_msec = 0
	_pacing_msec = 0
	_run_serial += 1
	_run_archive = OUTPUT_DIR + ("/run-%03d.json" % _run_serial)
	_started_msec = Time.get_ticks_msec()
	state = "initializing"
	goal = "Preparing the disposable " + str(config.fixture_id) + " scene"
	changed.emit()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
	adapter = Adapter.new()
	add_child(adapter)
	adapter.action_admitted.connect(_on_action_admitted)
	policy = Policy.new()
	policy.configure(str(config.policy), int(config.seed))
	assertions = Assertions.new()
	assertions.reset()
	var metadata := {"fixture_id": config.fixture_id, "fixture_version": Fixtures.VERSION,
		"fixture_state": "not_installed",
		"policy": config.policy, "seed": int(config.seed), "budget": budget,
		"evidence_kind": config.get("evidence_kind", "headless_godot"), "provenance": provenance.duplicate(true),
		"replay": not replay.is_empty(), "pacing_ms": int(config.get("pacing_ms", 0)),
		"reproduction_fixture": not reproduction.is_empty(),
		"native_worker_threads": 1, "campaign_timeout_msec": MAX_CAMPAIGN_MSEC}
	transcript = Transcript.create(metadata)
	var mounted: Dictionary = await adapter.mount()
	if not mounted.get("ok", false):
		last_error = str(mounted.get("error", "Workbench mount failed"))
		transcript["initialization"] = mounted
		return await _finish("stopped" if stop_requested else "initialization_failure", replay)
	if stop_requested: return await _finish("stopped", replay)
	var fixture: Dictionary = Fixtures.build(str(config.fixture_id), adapter.policy())
	var installed: Dictionary = await adapter.install_fixture(str(config.fixture_id), fixture)
	transcript["initialization"] = installed
	transcript.header["fixture_sha256"] = Adapter.digest(fixture)
	transcript.header["initial_scene_identity"] = str(installed.get("observation", {}).get("scene_identity", ""))
	if not installed.get("ok", false):
		last_error = str(installed.get("error", "fixture installation failed"))
		return await _finish("stopped" if stop_requested else "fixture_failure", replay)
	transcript.header["fixture_state"] = "installed"
	if stop_requested: return await _finish("stopped", replay)
	if not replay.is_empty() and (str(replay.header.get("fixture_sha256", "")) != str(transcript.header.fixture_sha256) \
		or str(replay.header.get("initial_scene_identity", "")) != str(transcript.header.initial_scene_identity)):
		last_error = "the installed authored fixture differs from the selected transcript"
		return await _finish("replay_fixture_mismatch", replay)
	if not reproduction.is_empty() and str(reproduction.header.get("initial_scene_identity", "")) != str(transcript.header.initial_scene_identity):
		last_error = "reproduction fixture identity differs from the actual installed scene"
		return await _finish("replay_fixture_mismatch", replay)
	latest_observation = adapter.observe()
	state = "running"
	changed.emit()
	var termination := "budget_complete"
	while attempted < budget:
		if stop_requested:
			termination = "stopped"
			break
		if Time.get_ticks_msec() - _started_msec - _decision_pause_msec - _pacing_msec > MAX_CAMPAIGN_MSEC:
			termination = "campaign_timeout"
			last_error = "goblin reached its bounded campaign deadline"
			break
		var paused_at: int = Time.get_ticks_msec()
		while decisions_paused and not stop_requested:
			state = "paused"
			await get_tree().process_frame
		_decision_pause_msec += Time.get_ticks_msec() - paused_at
		if stop_requested:
			termination = "stopped"
			break
		state = "running"
		var action: Dictionary
		if prescribed:
			if attempted >= replay_actions.size(): break
			action = replay_actions[attempted].duplicate(true)
			goal = "Replay step " + str(attempted + 1) + ": " + str(action.get("goal", action.id))
		else:
			var available: Array = adapter.available_actions()
			if available.is_empty():
				latest_observation = adapter.observe()
				if latest_observation.get("native", {}).get("failed", false):
					termination = "native_failure"
					last_error = "the native worker reported failure between game actions"
					break
				# Busy is an observation, not a completed operation. Yield a frame
				# while the normal application consumes its outstanding receipt.
				await get_tree().process_frame
				continue
			action = policy.next_action(adapter.observe(), available)
			goal = policy.goal
		if action.is_empty():
			termination = "no_applicable_actions"
			break
		latest_action = str(action.id)
		transcript["pending_action"] = {"index": attempted, "action": action.duplicate(true),
			"status": "proposed", "before": adapter.observe(), "started_msec": Time.get_ticks_msec()}
		Transcript.finish(transcript, "in_progress")
		if not _write_fixed(TRANSCRIPT_PATH, transcript):
			termination = "evidence_write_failure"
			break
		action_started.emit(action)
		changed.emit()
		var row: Dictionary = await adapter.execute(action)
		var checks: Array = assertions.evaluate(row)
		var added: Dictionary = Transcript.append(transcript, row, checks)
		if not added.ok:
			last_error = str(added.error)
			termination = "evidence_capacity"
			break
		attempted += 1
		transcript.erase("pending_action")
		if row.status == "completed": completed += 1
		policy.observe_result(row)
		latest_observation = row.after.duplicate(true)
		action_observed.emit(transcript.steps.back())
		changed.emit()
		# Persist all attempted actions, including the failing or partial step.
		Transcript.finish(transcript, "in_progress")
		if not _write_fixed(TRANSCRIPT_PATH, transcript):
			termination = "evidence_write_failure"
			break
		if checks.any(func(check: Dictionary) -> bool: return check.get("status") == "fail"):
			termination = "assertion_failure"
			break
		if row.classification in ["timeout", "native_failure", "adapter_failure"]:
			termination = str(row.classification)
			last_error = str(row.error)
			break
		var pacing_started: int = Time.get_ticks_msec()
		var pacing_until: int = pacing_started + int(config.get("pacing_ms", 0))
		while not stop_requested and Time.get_ticks_msec() < pacing_until:
			await get_tree().process_frame
		_pacing_msec += Time.get_ticks_msec() - pacing_started
	return await _finish(termination, replay)


func _finish(termination: String, replay: Dictionary) -> Dictionary:
	if adapter != null: adapter.request_stop()
	Transcript.finish(transcript, termination)
	transcript["policy_summary"] = policy.summary() if policy != null else {}
	transcript["controller"] = {"termination": termination, "error": last_error,
		"elapsed_msec": Time.get_ticks_msec() - _started_msec, "frame_timing": frame_timing(),
		"decision_pause_msec": _decision_pause_msec, "pacing_msec": _pacing_msec,
		"run_serial": _run_serial, "run_archive": _run_archive,
		"final_observation": adapter.observe() if adapter != null else {},
		"stop_requested": stop_requested, "export_location": TRANSCRIPT_PATH}
	var replay_exported := true
	if not replay.is_empty():
		replay_result = Transcript.compare(replay, transcript)
		transcript["replay_result"] = replay_result
		replay_exported = _write_fixed(REPLAY_RESULT_PATH, replay_result)
	var exported: bool = _write_fixed(TRANSCRIPT_PATH, transcript)
	var archived: bool = _write_fixed(_run_archive, transcript)
	var summary_exported: bool = _write_fixed(SUMMARY_PATH, {"header": transcript.header, "summary": transcript.summary,
		"controller": transcript.controller, "replay_result": replay_result})
	export_path = ProjectSettings.globalize_path(TRANSCRIPT_PATH) if exported and archived and summary_exported and replay_exported else ""
	if export_path.is_empty() and last_error.is_empty(): last_error = "the final evidence files could not all be retained"
	running = false
	decisions_paused = false
	state = "evidence_write_failure" if export_path.is_empty() else ("finished" if termination == "budget_complete" else termination)
	goal = "Finished " + str(completed) + " observed game operations"
	changed.emit()
	finished.emit(transcript)
	return transcript


func _on_action_admitted(action: Dictionary, admission: Dictionary, observation: Dictionary) -> void:
	if not transcript.has("pending_action"): return
	if transcript.pending_action.action != action: return
	transcript.pending_action.status = "accepted"
	transcript.pending_action.admission = admission.duplicate(true)
	transcript.pending_action.observed_after_admission = observation.duplicate(true)
	if not _write_fixed(TRANSCRIPT_PATH, transcript):
		last_error = "could not retain the actual action admission"
		stop_requested = true
		adapter.request_stop()


func frame_timing() -> Dictionary:
	if _frame_samples.is_empty(): return {"samples": 0, "scope": "process-frame observation only"}
	var samples: Array[int] = _frame_samples.duplicate()
	samples.sort()
	return {"samples": samples.size(), "median_usec": samples[int(samples.size() / 2)],
		"p95_usec": samples[mini(samples.size() - 1, int(samples.size() * 0.95))],
		"maximum_usec": samples.back(), "scope": "Godot process-frame intervals on this test host; no physical GPU acceptance"}


func pause_decisions() -> void:
	if not running: return
	decisions_paused = not decisions_paused
	state = "paused" if decisions_paused else "running"
	changed.emit()


func stop() -> void:
	stop_requested = true
	decisions_paused = false
	if adapter != null: adapter.request_stop()
	changed.emit()


func close() -> void:
	stop()
	while running: await get_tree().process_frame
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		adapter = null


func _write_fixed(path: String, value: Dictionary) -> bool:
	if path not in [TRANSCRIPT_PATH, SUMMARY_PATH, REPLAY_RESULT_PATH, _run_archive] or path.is_empty(): return false
	if not Adapter.verify_profile().get("ok", false): return false
	if DirAccess.make_dir_recursive_absolute(OUTPUT_DIR) != OK: return false
	var pending: String = path + ".partial"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		last_error = "could not export to the fixed test output location"
		return false
	file.store_string(JSON.stringify(value, "\t", true) + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(pending, path) != OK:
		last_error = "could not atomically retain the observed transcript"
		return false
	return true
