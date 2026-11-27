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
const Corpus = preload("res://goblin/goblin_corpus.gd")
const Findings = preload("res://goblin/goblin_findings.gd")
const FileTransaction = preload("res://scripts/workbench_file_transaction.gd")
const OUTPUT_DIR := "user://goblin"
const TRANSCRIPT_PATH := "user://goblin/transcript.json"
const SUMMARY_PATH := "user://goblin/summary.json"
const REPLAY_RESULT_PATH := "user://goblin/replay-result.json"
const CORPUS_PATH := "user://goblin/corpus.json"
const CORPUS_EXPORT_PATH := "user://goblin/corpus-export.json"
const FINDINGS_PATH := "user://goblin/findings.json"
const REPRODUCTION_PATH := "user://goblin/reproduction.json"
const REDUCTION_PATH := "user://goblin/reduction.json"
const MAX_CAMPAIGN_MSEC := 900000
const MAX_ABSOLUTE_MSEC := 5400000
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
var _candidate_archive := ""
var _decision_pause_msec := 0
var _pacing_msec := 0
var _active_limit_msec := 150000
var _absolute_limit_msec := 150000
var _step_tokens := 0
var corpus: RefCounted = Corpus.new()
var findings: RefCounted = Findings.new()
var corpus_loaded := false
var corpus_status := "Fresh experimental memory"
var maintenance_running := false
var reduction_result: Dictionary = {}
var _maintenance_stop := false
var _archive_bytes := 0
const MAX_PROFILE_EVIDENCE_BYTES := 536870912


static func read_launch() -> Dictionary:
	var profile: Dictionary = Adapter.verify_profile()
	if not profile.get("ok", false): return profile
	var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(profile.root).path_join("goblin-profile.json")))
	if not marker is Dictionary or not marker.get("launch") is Dictionary or not marker.get("provenance") is Dictionary:
		return {"ok": false, "error": "isolated profile does not contain a launch record"}
	return {"ok": true, "launch": marker.launch, "provenance": marker.provenance, "profile": profile}


static func same_identity(recorded: Variant, current: Variant) -> bool:
	# New portable records fence all executable inputs, source and runtime bytes.
	# Host labels and Python versions are preserved as evidence, but do not make
	# identical shipped code a different semantic experiment. Legacy stays strict.
	return Transcript.same_execution_identity(recorded, current)


static func evidence_digest(value: Variant) -> String:
	# JSON readers represent integer numbers as floats. Evidence identity follows
	# the transcript's canonical numeric contract across save/import boundaries.
	return Adapter.digest(Transcript._json_value(value))


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
	if plan.actions.is_empty() or plan.actions.size() > Transcript.MAX_ACTIONS:
		return {"ok": false, "error": "reproduction requires 1..1024 bounded game actions"}
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
		config.pacing_ms = int(replay.header.get("pacing_ms", 0))
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
		config.pacing_ms = int(reproduction.header.get("pacing_ms", 0))
		config.budget = replay_actions.size()
	var prescribed: bool = not replay.is_empty() or not reproduction.is_empty()
	if _run_serial >= MAX_PROFILE_RUNS:
		return {"error": "this disposable profile reached its 64-campaign budget; launch a fresh profile"}
	if config.get("fixture_id") not in Fixtures.ids() or config.get("policy") not in Policy.PERSONALITIES:
		return {"error": "unknown committed fixture or personality"}
	if not Adapter._integer(config.get("budget"), 1, Transcript.MAX_ACTIONS) \
		or not Adapter._integer(config.get("seed"), -2147483648, 2147483647) \
		or not Adapter._integer(config.get("pacing_ms", 0), 0, 3000):
		return {"error": "campaign options are outside their fixed bounds"}
	for option: String in ["start_paused", "reuse_memory"]:
		if config.has(option) and not config[option] is bool:
			return {"error": "laboratory controls require boolean values"}
	if _archive_bytes >= MAX_PROFILE_EVIDENCE_BYTES:
		return {"error": "this disposable profile reached its 512 MiB evidence budget; export and launch a fresh profile"}
	if not corpus_loaded:
		_load_corpus_input()
	running = true
	decisions_paused = bool(config.get("start_paused", false))
	_step_tokens = 0
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
	_active_limit_msec = mini(MAX_CAMPAIGN_MSEC, maxi(150000, int(config.budget) * 1200))
	if config.has("execution_limit_msec"):
		if not Adapter._integer(config.execution_limit_msec, 1000, MAX_CAMPAIGN_MSEC):
			running = false
			return {"error": "execution limit outside fixed bounds"}
		_active_limit_msec = mini(_active_limit_msec, int(config.execution_limit_msec))
	_absolute_limit_msec = mini(MAX_ABSOLUTE_MSEC, _active_limit_msec + int(config.budget) * int(config.get("pacing_ms", 0)) + 600000)
	if config.has("absolute_limit_msec"):
		if not Adapter._integer(config.absolute_limit_msec, 1000, MAX_ABSOLUTE_MSEC):
			running = false
			return {"error": "absolute session limit outside fixed bounds"}
		_absolute_limit_msec = mini(_absolute_limit_msec, int(config.absolute_limit_msec))
	_run_serial += 1
	_run_archive = OUTPUT_DIR + ("/run-%03d.json" % _run_serial)
	_candidate_archive = OUTPUT_DIR + ("/candidate-%03d.json" % _run_serial)
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
		"native_worker_threads": 1, "campaign_timeout_msec": _active_limit_msec,
		"absolute_timeout_msec": _absolute_limit_msec,
		"reuse_memory_requested": bool(config.get("reuse_memory", false)),
		"observation_contract": "native acknowledgements; authored-fixture restart, not full physical checkpoint"}
	transcript = Transcript.create(metadata)
	var mounted: Dictionary = await adapter.mount()
	if not mounted.get("ok", false):
		last_error = str(mounted.get("error", "Workbench mount failed"))
		transcript["initialization"] = mounted
		return await _finish("stopped" if stop_requested else "initialization_failure", replay)
	if stop_requested: return await _finish("stopped", replay)
	var fixture: Dictionary = Fixtures.build(str(config.fixture_id), adapter.policy())
	transcript["initial_authored_fixture"] = fixture.duplicate(true)
	var installed: Dictionary = await adapter.install_fixture(str(config.fixture_id), fixture)
	transcript["initialization"] = installed
	transcript.header["fixture_sha256"] = Adapter.digest(fixture)
	transcript.header["initial_scene_identity"] = str(installed.get("observation", {}).get("scene_identity", ""))
	if not installed.get("ok", false):
		last_error = str(installed.get("error", "fixture installation failed"))
		return await _finish("stopped" if stop_requested else "fixture_failure", replay)
	transcript.header["fixture_state"] = "installed"
	# Seed the independent material-history observer from the actual admitted
	# authored installation, before any policy decision can retain evolved cells.
	assertions.reset(installed)
	var memory_identity: Dictionary = {"replay_identity": provenance.replay_identity, "source_dirty": provenance.source_dirty} \
		if Transcript._valid_replay_identity(provenance) else provenance
	var context := {"fixture_id": str(config.fixture_id), "fixture_version": Fixtures.VERSION,
		"fixture_sha256": str(transcript.header.fixture_sha256), "provenance_sha256": evidence_digest(memory_identity),
		"source_sha": str(provenance.get("source_commit", "")), "seed": int(config.seed), "personality": str(config.policy)}
	policy.bind_memory(corpus, context, bool(config.get("reuse_memory", false)) and not prescribed)
	findings.begin_episode(context, _run_serial)
	if stop_requested: return await _finish("stopped", replay)
	if not replay.is_empty() and (str(replay.header.get("fixture_sha256", "")) != str(transcript.header.fixture_sha256) \
		or str(replay.header.get("initial_scene_identity", "")) != str(transcript.header.initial_scene_identity)):
		last_error = "the installed authored fixture differs from the selected transcript"
		return await _finish("replay_fixture_mismatch", replay)
	if not reproduction.is_empty() and (str(reproduction.header.get("fixture_sha256", "")) != str(transcript.header.fixture_sha256) \
		or str(reproduction.header.get("initial_scene_identity", "")) != str(transcript.header.initial_scene_identity)):
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
		if Time.get_ticks_msec() - _started_msec - _decision_pause_msec - _pacing_msec > _active_limit_msec \
			or Time.get_ticks_msec() - _started_msec > _absolute_limit_msec:
			termination = "campaign_timeout"
			last_error = "goblin reached its bounded campaign deadline"
			break
		var paused_at: int = Time.get_ticks_msec()
		while decisions_paused and _step_tokens == 0 and not stop_requested:
			state = "paused"
			if Time.get_ticks_msec() - _started_msec > _absolute_limit_msec:
				stop_requested = true
				last_error = "absolute laboratory session deadline reached during decision pause"
				break
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
		if _step_tokens > 0: _step_tokens -= 1
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
		policy.observe_result(transcript.steps.back())
		findings.observe(transcript.steps.back(), policy.summary().get("last_novelty", {}))
		transcript["discovery"] = discovery_summary()
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
		while not stop_requested and Time.get_ticks_msec() < pacing_until \
			and Time.get_ticks_msec() - _started_msec < _absolute_limit_msec:
			await get_tree().process_frame
		_pacing_msec += Time.get_ticks_msec() - pacing_started
	return await _finish(termination, replay)


func _finish(termination: String, replay: Dictionary) -> Dictionary:
	if adapter != null: adapter.request_stop()
	Transcript.finish(transcript, termination)
	transcript["policy_summary"] = policy.summary() if policy != null else {}
	transcript["discovery"] = discovery_summary()
	transcript["controller"] = {"termination": termination, "error": last_error,
		"elapsed_msec": Time.get_ticks_msec() - _started_msec, "frame_timing": frame_timing(),
		"decision_pause_msec": _decision_pause_msec, "pacing_msec": _pacing_msec,
		"run_serial": _run_serial, "run_archive": _run_archive,
		"final_observation": adapter.observe() if adapter != null else {},
		"stop_requested": stop_requested, "export_location": TRANSCRIPT_PATH}
	var capture_candidate: bool = termination == "assertion_failure" and _reduction_target(transcript).get("kind") == "failed_invariant"
	if capture_candidate: transcript.controller["automatic_candidate_bundle"] = _candidate_archive
	var replay_exported := true
	if not replay.is_empty():
		replay_result = Transcript.compare(replay, transcript)
		transcript["replay_result"] = replay_result
		replay_exported = _write_fixed(REPLAY_RESULT_PATH, replay_result)
	var exported: bool = _write_fixed(TRANSCRIPT_PATH, transcript)
	var archived: bool = _write_fixed(_run_archive, transcript)
	if archived:
		var archive := FileAccess.open(_run_archive, FileAccess.READ)
		if archive != null:
			_archive_bytes += archive.get_length()
			archive.close()
	var candidate_exported := true
	if capture_candidate:
		candidate_exported = _write_fixed(_candidate_archive, _reproduction_bundle(transcript, {}, {}, true))
		if candidate_exported:
			var candidate_file := FileAccess.open(_candidate_archive, FileAccess.READ)
			if candidate_file != null:
				_archive_bytes += candidate_file.get_length()
				candidate_file.close()
	var corpus_exported: bool = _write_fixed(CORPUS_PATH, corpus.export_data())
	var findings_exported: bool = _write_fixed(FINDINGS_PATH, findings.export_data())
	var summary_exported: bool = _write_fixed(SUMMARY_PATH, {"header": transcript.header, "summary": transcript.summary,
		"controller": transcript.controller, "replay_result": replay_result})
	export_path = ProjectSettings.globalize_path(TRANSCRIPT_PATH) if exported and archived and summary_exported and replay_exported and corpus_exported and findings_exported and candidate_exported else ""
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
	_step_tokens = 0
	decisions_paused = not decisions_paused
	state = "paused" if decisions_paused else "running"
	changed.emit()


func stop() -> void:
	_maintenance_stop = true
	stop_requested = true
	decisions_paused = false
	if adapter != null: adapter.request_stop()
	changed.emit()


func close() -> void:
	stop()
	while running or maintenance_running: await get_tree().process_frame
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		adapter = null


func step_decision() -> void:
	# One decision, followed by a pause at the next admission boundary. It does
	# not pretend that an asynchronous physical step is a resumable checkpoint.
	if not running: return
	decisions_paused = true
	_step_tokens = 1
	changed.emit()


func clock_summary() -> Dictionary:
	var elapsed := 0
	if running: elapsed = Time.get_ticks_msec() - _started_msec
	elif transcript.get("controller") is Dictionary: elapsed = int(transcript.controller.get("elapsed_msec", 0))
	return {"real_elapsed_msec": elapsed, "decision_pause_msec": _decision_pause_msec,
		"pacing_msec": _pacing_msec, "action_count": attempted,
		"native_tick": latest_observation.get("native", {}).get("tick", -1),
		"actor_tick": latest_observation.get("actor_tick", -1),
		"scope": "native ticks, actor ticks and real elapsed time are separate clocks"}


func discovery_summary() -> Dictionary:
	var snapshot: Dictionary = policy.summary() if policy != null else {}
	return {"schema": "cybersand-goblin-discovery-v1",
		"coverage": snapshot.get("coverage", {}), "novelty": snapshot.get("last_novelty", {}),
		"intention": snapshot.get("intention", {}),
		"memory": corpus.summary(), "findings": findings.summary(), "clocks": clock_summary(),
		"corpus_status": corpus_status, "physical_checkpoint_resume": false}


func _load_corpus_input() -> Dictionary:
	corpus_loaded = true
	var profile: Dictionary = Adapter.verify_profile()
	if not profile.get("ok", false): return {"ok": false, "error": "verified disposable profile required"}
	var path: String = str(profile.root).path_join("goblin-corpus.json")
	if not FileAccess.file_exists(path): return {"ok": true, "loaded": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Corpus.MAX_BYTES:
		corpus_status = "Corpus import refused: missing or oversized input"
		return {"ok": false, "error": corpus_status}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var result: Dictionary = corpus.import_data(value, Adapter.validate_action)
	corpus_status = "Imported unverified experiment hints" if result.get("ok", false) else "Corpus import refused: " + str(result.get("error", "invalid record"))
	return result


func import_memory() -> Dictionary:
	if running or maintenance_running: return {"ok": false, "error": "Stop the current laboratory operation before importing memory"}
	var result := _load_corpus_input()
	changed.emit()
	return result


func clear_memory() -> Dictionary:
	if running or maintenance_running: return {"ok": false, "error": "Stop the current laboratory operation before clearing memory"}
	corpus.clear()
	corpus_loaded = true
	corpus_status = "Experimental memory cleared; retained campaign tapes are unchanged"
	var saved := _write_fixed(CORPUS_PATH, corpus.export_data())
	changed.emit()
	return {"ok": saved, "path": ProjectSettings.globalize_path(CORPUS_PATH)}


func export_memory() -> Dictionary:
	if running or maintenance_running: return {"ok": false, "error": "Stop the current laboratory operation before exporting memory"}
	var saved := _write_fixed(CORPUS_EXPORT_PATH, corpus.export_data())
	return {"ok": saved, "path": ProjectSettings.globalize_path(CORPUS_EXPORT_PATH), "error": last_error if not saved else ""}


func export_reproduction(original: Dictionary, reduced: Dictionary = {}) -> Dictionary:
	if running or maintenance_running: return {"ok": false, "error": "Stop the laboratory operation before exporting a reproduction"}
	if not Transcript.validate(original).get("ok", false): return {"ok": false, "error": "No valid original tape"}
	var chosen: Dictionary = reduced if not reduced.is_empty() else original
	if not Transcript.validate(chosen).get("ok", false): return {"ok": false, "error": "Reduced tape is not valid"}
	var target := _reduction_target(original)
	if target.is_empty(): return {"ok": false, "error": "Raw tape is retained; reproduction export requires a completed or failed-invariant target"}
	var matching_reduction: bool = reduction_result.get("original_tape_sha256", "") == evidence_digest(original)
	if not reduced.is_empty():
		if not matching_reduction or not reduction_result.get("ok", false) or not _accept_reduction(reduced, target):
			return {"ok": false, "error": "reduced tape lacks a matching successful reduction acceptance record"}
		if not same_identity(chosen.header.get("provenance", {}), original.header.get("provenance", {})):
			return {"ok": false, "error": "reduced source/runtime identity differs from original"}
		for key: String in ["fixture_id", "fixture_version", "fixture_sha256", "initial_scene_identity", "policy", "seed", "pacing_ms", "evidence_kind"]:
			if JSON.stringify(Transcript._json_value(chosen.header.get(key))) != JSON.stringify(Transcript._json_value(original.header.get(key))):
				return {"ok": false, "error": "reduced source/runtime/fixture identity differs from original"}
		if evidence_digest(reduced) != evidence_digest(reduction_result.get("reduced_tape", {})):
			return {"ok": false, "error": "reduced tape differs from the recorded observed probe"}
	var bundle := _reproduction_bundle(original, reduced, reduction_result if matching_reduction else {})
	var saved := _write_fixed(REPRODUCTION_PATH, bundle)
	return {"ok": saved, "path": ProjectSettings.globalize_path(REPRODUCTION_PATH), "error": last_error if not saved else ""}


static func _reproduction_bundle(original: Dictionary, reduced: Dictionary, reduction: Dictionary, automatic: bool = false) -> Dictionary:
	var chosen: Dictionary = reduced if not reduced.is_empty() else original
	var target := _reduction_target(original)
	return {"schema": "cybersand-goblin-reproduction-bundle-v1",
		"classification": "unresolved_observation" if target.get("kind") == "failed_invariant" else "legal_unusual_gameplay",
		"captured_automatically": automatic,
		"original_tape": original, "reduced_tape": reduced, "initial_authored_fixture": original.get("initial_authored_fixture", {}),
		"exact_provenance": original.header.provenance, "required_action_ids": chosen.summary.get("action_attempts", {}).keys(),
		"expected_invariant": target,
		"observed_failures": chosen.summary.get("failures", []), "reduction": reduction,
		"action_fixture": _action_fixture(chosen, Transcript.replay_actions(chosen)),
		"instructions": "Use the committed fixed goblin reproduction entrypoint in a fresh marked test profile at the recorded source/runtime. This is an authored restart, not exact asynchronous continuation.",
		"gameplay_defect_confirmed": false}


static func _action_fixture(tape: Dictionary, actions: Array) -> Dictionary:
	return {"schema": "cybersand-goblin-action-fixture-v1", "header": tape.header.duplicate(true), "actions": actions.duplicate(true)}


static func _admission_identity(row: Dictionary) -> Dictionary:
	var admission: Dictionary = row.get("admission", {})
	return {"accepted": admission.get("accepted"), "status": admission.get("status"), "unsupported": admission.get("unsupported")}


static func _reduction_target(tape: Dictionary) -> Dictionary:
	if tape.get("summary", {}).get("termination") == "assertion_failure":
		for row: Dictionary in tape.get("steps", []):
			for assertion: Dictionary in row.get("assertions", []):
				if assertion.get("status") == "fail":
					return {"kind": "failed_invariant", "id": str(assertion.id), "assertion_kind": str(assertion.get("kind", "")),
						"action_id": str(row.get("action", {}).get("id", "")), "action_args": row.get("action", {}).get("args", {}).duplicate(true),
						"expected": assertion.get("expected"), "original_status": str(row.get("status", "")),
						"original_classification": str(row.get("classification", "")), "admission": _admission_identity(row),
						"scope": "candidate observation; reproduction alone does not establish a production defect"}
	if tape.get("summary", {}).get("termination") == "budget_complete" and not tape.get("steps", []).is_empty():
		var row: Dictionary = tape.steps.back()
		if row.get("status") == "completed":
			return {"kind": "semantic_outcome", "action_id": str(row.action.id), "semantic_sha256": str(row.get("semantic_sha256", "")),
				"scope": "last completed semantic outcome; legal gameplay, not a failing regression"}
	return {}


static func _accept_reduction(tape: Dictionary, target: Dictionary) -> bool:
	if not Transcript.validate(tape).get("ok", false) or tape.get("header", {}).get("fixture_state") != "installed": return false
	if target.get("kind") == "failed_invariant":
		if tape.get("summary", {}).get("termination") != "assertion_failure": return false
		for row: Dictionary in tape.get("steps", []):
			if row.get("action", {}).get("id") != target.get("action_id") or row.get("status") != target.get("original_status") \
				or row.get("classification") != target.get("original_classification"): continue
			if evidence_digest(_admission_identity(row)) != evidence_digest(target.get("admission")) \
				or evidence_digest(row.get("action", {}).get("args", {})) != evidence_digest(target.get("action_args")): continue
			for assertion: Dictionary in row.get("assertions", []):
				if assertion.get("id") == target.get("id") and assertion.get("kind") == target.get("assertion_kind") \
					and assertion.get("status") == "fail" and evidence_digest(assertion.get("expected")) == evidence_digest(target.get("expected")): return true
	elif target.get("kind") == "semantic_outcome" and tape.get("summary", {}).get("termination") == "budget_complete" \
		and tape.get("summary", {}).get("failures", ["missing"]).is_empty():
		for row: Dictionary in tape.get("steps", []):
			if row.get("status") == "completed" and row.get("action", {}).get("id") == target.get("action_id") \
				and row.get("semantic_sha256") == target.get("semantic_sha256"): return true
	return false


func reduce_tape(original: Dictionary, provenance: Dictionary) -> Dictionary:
	if running or maintenance_running: return {"ok": false, "error": "laboratory operation already running"}
	if not Transcript.validate(original).get("ok", false) or not same_identity(original.get("header", {}).get("provenance", {}), provenance):
		return {"ok": false, "error": "reduction requires a valid tape and exact source/runtime identity"}
	var actions: Array = Transcript.replay_actions(original)
	if actions.is_empty() or actions.size() > 128:
		return {"ok": false, "error": "interactive reduction admits 1..128 actions; use the bounded offline reducer for longer tapes"}
	if _run_serial + 12 > MAX_PROFILE_RUNS: return {"ok": false, "error": "insufficient remaining profile trials for reduction"}
	var target := _reduction_target(original)
	if target.is_empty(): return {"ok": false, "error": "tape has no supported reproducible target"}
	maintenance_running = true
	_maintenance_stop = false
	var started := Time.get_ticks_msec()
	var probes: Array[Dictionary] = []
	var best_tape := original.duplicate(true)
	var reproduced := 0
	var options := {"pacing_ms": int(original.header.get("pacing_ms", 0)),
		"evidence_kind": str(original.header.get("evidence_kind", "headless_godot")),
		"execution_limit_msec": 30000, "absolute_limit_msec": 60000}
	# Require two separate fresh-world observations before shrinking. No cached
	# expected state or old pass is allowed to stand in for these actual probes.
	for confirmation: int in range(2):
		if _maintenance_stop: break
		var replayed: Dictionary = await run_campaign(options, provenance, {}, _action_fixture(original, actions))
		var accepted := _accept_reduction(replayed, target) and not export_path.is_empty()
		probes.append({"kind": "baseline_confirmation", "actions": actions.size(), "accepted": accepted,
			"archive": _run_archive, "termination": replayed.get("summary", {}).get("termination", "refused")})
		if not accepted: break
		reproduced += 1
		best_tape = replayed.duplicate(true)
	var width := maxi(1, actions.size() / 2)
	var cursor := 0
	while reproduced == 2 and not _maintenance_stop and probes.size() < 10 and actions.size() > 1 \
		and Time.get_ticks_msec() - started < 240000:
		if cursor >= actions.size():
			if width <= 1: break
			width = maxi(1, width / 2)
			cursor = 0
		var candidate := actions.duplicate(true)
		for _remove: int in range(mini(width, candidate.size() - cursor)):
			candidate.remove_at(cursor)
		if candidate.is_empty():
			cursor += width
			continue
		var first: Dictionary = await run_campaign(options, provenance, {}, _action_fixture(original, candidate))
		var accepted := _accept_reduction(first, target) and not export_path.is_empty()
		probes.append({"kind": "remove_span", "offset": cursor, "width": width, "actions": candidate.size(),
			"accepted": accepted, "archive": _run_archive, "termination": first.get("summary", {}).get("termination", "refused")})
		if accepted and not _maintenance_stop:
			var second: Dictionary = await run_campaign(options, provenance, {}, _action_fixture(original, candidate))
			accepted = _accept_reduction(second, target) and not export_path.is_empty()
			probes.append({"kind": "confirm_reduction", "actions": candidate.size(), "accepted": accepted,
				"archive": _run_archive, "termination": second.get("summary", {}).get("termination", "refused")})
			if accepted:
				actions = candidate
				best_tape = second.duplicate(true)
				cursor = 0
				width = mini(width, maxi(1, actions.size() / 2))
			else: cursor += width
		else: cursor += width
	reduction_result = {"schema": "cybersand-goblin-interactive-reduction-v1", "ok": reproduced == 2,
		"original_tape_sha256": evidence_digest(original),
		"status": "cancelled" if _maintenance_stop else ("reproduced" if reproduced == 2 else "not_reproduced"),
		"classification": "unresolved_observation" if target.kind == "failed_invariant" else "legal_unusual_gameplay",
		"acceptance_rule": target, "original_actions": original.steps.size(), "reduced_actions": actions.size(),
		"reduction_success": reproduced == 2 and actions.size() < original.steps.size(),
		"probes": probes, "elapsed_msec": Time.get_ticks_msec() - started, "max_trials": 12,
		"max_trial_active_msec": 30000, "max_trial_absolute_msec": 60000,
		"full_physics_checkpoint": false, "gameplay_defect_confirmed": false}
	if reproduced == 2: reduction_result["reduced_tape"] = best_tape
	_write_fixed(REDUCTION_PATH, reduction_result)
	maintenance_running = false
	goal = "Reduction: %s (%d to %d actions)" % [str(reduction_result.status), original.steps.size(), actions.size()]
	changed.emit()
	return reduction_result


func _write_fixed(path: String, value: Dictionary) -> bool:
	if path not in [TRANSCRIPT_PATH, SUMMARY_PATH, REPLAY_RESULT_PATH, _run_archive, _candidate_archive,
		CORPUS_PATH, CORPUS_EXPORT_PATH, FINDINGS_PATH, REPRODUCTION_PATH, REDUCTION_PATH] or path.is_empty(): return false
	if not Adapter.verify_profile().get("ok", false): return false
	# Compact snapshots avoid repeatedly expanding long native tapes with tabs.
	# The fixed byte bound applies to the actual serialized bytes before writing.
	var serialized := JSON.stringify(value, "", true) + "\n"
	var byte_limit: int = Corpus.MAX_BYTES if path in [CORPUS_PATH, CORPUS_EXPORT_PATH] else Transcript.MAX_BYTES
	var encoded_bytes := serialized.to_utf8_buffer().size()
	if encoded_bytes > byte_limit or (path in [_run_archive, _candidate_archive] and _archive_bytes + encoded_bytes > MAX_PROFILE_EVIDENCE_BYTES):
		last_error = "fixed evidence byte budget exceeded"
		return false
	if DirAccess.make_dir_recursive_absolute(OUTPUT_DIR) != OK:
		last_error = "could not export to the fixed test output location"
		return false
	# Retain the successor's compact bytes and separate corpus/transcript/profile
	# limits before creating staging. Verify closed bytes, then replace one file
	# through the accepted native owner. Distinct evidence files are not one
	# transaction and this does not promise power-loss durability.
	var saved := FileTransaction.write_text(path, serialized, byte_limit)
	if not saved.get("ok", false):
		last_error = str(saved.get("error", "Audit output was not replaced."))
		return false
	last_error = ""
	return true
