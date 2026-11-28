extends SceneTree

## Fixed nine-action diagnostic. No production state injection, policy search,
## oracle replacement, arbitrary input script, network operation or owner save.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const BASE_GAME_SOURCE := "5ee5dffc78d59a721f62be49fd51d24b870556c7"
const ENTRYPOINT := "res://goblin/diagnostics/retained_clock.gd"
const OUTPUT := "user://goblin/retained-clock-diagnostic.json"
const CELL_REGION := Rect2i(48, 48, 48, 48)
const VARIANT_MODE := "LA-EVENT-OFF"
const CONTROL_ACTIONS := [
	{"id": "play", "args": {"ticks": 16}},
	{"id": "pause", "args": {}},
	{"id": "save_layout", "args": {}},
	{"id": "reopen_layout", "args": {}},
]
const VARIANT_ACTIONS := [
	{"id": "play", "args": {"ticks": 16}},
	{"id": "pause", "args": {}},
	{"id": "response_mode", "args": {"mode": VARIANT_MODE}},
	{"id": "save_layout", "args": {}},
	{"id": "reopen_layout", "args": {}},
]

var controller: Variant
var report: Dictionary = {}
var _deadline_msec := 0
var _case_finished := false
var _case_tape: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func _write_checkpoint() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://goblin"))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(Adapter.json_value(report), "", true))
	file.flush()
	return true


func _wait_until(predicate: Callable, limit_msec: int) -> bool:
	var deadline: int = mini(_deadline_msec, Time.get_ticks_msec() + limit_msec)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return predicate.call()


func _same_numbers(actual: Variant, expected: Array) -> bool:
	if not actual is Array or actual.size() != expected.size(): return false
	for index: int in range(expected.size()):
		if not (actual[index] is int or actual[index] is float) or not is_finite(float(actual[index])) \
			or float(actual[index]) != float(expected[index]): return false
	return true


func _source_fenced_capture(captured: Dictionary, expected_region: Array, observation: Dictionary = {}) -> bool:
	if captured.has("error") or captured.get("source_matches") != true: return false
	if not _same_numbers(captured.get("region"), expected_region): return false
	if captured.get("count") != int(expected_region[2]) * int(expected_region[3]): return false
	var fingerprint: Variant = captured.get("material_sha256")
	if not fingerprint is String or fingerprint.length() != 64 or not fingerprint.is_valid_hex_number(): return false
	for field: String in ["admission", "native_receipt", "source_before", "source_after"]:
		if not captured.get(field) is Dictionary: return false
	var admission: Dictionary = captured.get("admission", {})
	var receipt: Dictionary = captured.get("native_receipt", {})
	var first: Dictionary = captured.get("source_before", {})
	var last: Dictionary = captured.get("source_after", {})
	if admission.get("status") != "queued" or receipt.get("status") != "completed" \
		or receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld" \
		or receipt.get("operation_id") != admission.get("operation_id") \
		or receipt.get("observed_generation") != first.get("generation") \
		or not _same_numbers(receipt.get("region"), expected_region): return false
	if first.get("paused") != true or last.get("paused") != true \
		or first.get("failed") != false or last.get("failed") != false: return false
	for key: String in ["generation", "revision", "tick"]:
		if not first.has(key) or first[key] != last.get(key) or first[key] != receipt.get(key): return false
		if not observation.is_empty() and first[key] != observation.get("native", {}).get(key): return false
	return true


func _valid_capture(captured: Dictionary) -> bool:
	if not _source_fenced_capture(captured, [48, 48, 48, 48]): return false
	var values: Variant = captured.get("materials")
	if not values is Array or values.size() != 2304: return false
	var data := PackedInt32Array()
	for value: Variant in values:
		if not value is int or value < 0 or value > 131: return false
		data.append(value)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(data.to_byte_array())
	return hash.finish().hex_encode() == captured.get("material_sha256")


func _disarmed_receipt(receipt: Variant) -> bool:
	if not receipt is Dictionary: return false
	if receipt.get("armed") != false or receipt.get("burst_queued") != false \
		or receipt.get("stream_enabled") != false or not _same_numbers(receipt.get("origin"), [0, 0]): return false
	for key: String in ["material", "attempted", "inserted", "blocked", "stream_ticks"]:
		if not receipt.get(key) is int or receipt[key] != 0: return false
	return true


func _actor_free(observation: Dictionary) -> bool:
	# The queue proof is part of this exact observation. Its count, copied
	# commands, owner generation/paused state and current receipt are produced
	# inside one existing adapter owner-mutex interval. Never substitute a
	# later callback's empty queue for a command missing from the action row.
	var source: Variant = observation.get("source")
	var native: Variant = observation.get("native")
	if not source is Dictionary or not native is Dictionary: return false
	if observation.get("actor_ids") != [] or observation.get("actors") != [] \
		or source.get("authored") != [] or not _disarmed_receipt(source.get("receipt", {})): return false
	var count: Variant = source.get("pending_commands")
	var proof: Variant = source.get("queue_evidence")
	if not count is int or count < 0 or count > 16 or not proof is Dictionary: return false
	if proof.get("schema") != "cybersand-goblin-source-queue-v1" or proof.get("copy_complete") != true \
		or not proof.get("command_count") is int or proof.command_count != count \
		or not proof.get("owner_generation") is int or not native.get("generation") is int \
		or proof.owner_generation != native.generation or native.generation < 0 \
		or native.get("failed") != false or not proof.get("owner_paused") is bool \
		or not _disarmed_receipt(proof.get("current_source_receipt", {})): return false
	# Running empty-queue observations may advance the local clock. A positive
	# queue is accepted only as the actual fully observed inert cancellation
	# Stop while both owner and published action observation are paused.
	if count > 0 and (observation.get("paused") != true or native.get("paused") != true \
		or proof.owner_paused != true): return false
	var commands: Variant = proof.get("commands")
	if not commands is Array or commands.size() != count: return false
	for command: Variant in commands:
		if not command is Dictionary or command.size() != 3 or command.get("command") != "stop" \
			or not command.get("material") is int or command.material != 0 \
			or not _same_numbers(command.get("origin"), [0, 0]): return false
	return true


func _authored_file_matches(readback: Dictionary, mode: String) -> bool:
	if readback.has("error") or not readback.get("setup") is Dictionary: return false
	var saved: Dictionary = readback.setup
	if not _same_numbers(saved.get("extent"), [512, 512]) or saved.get("response") != mode \
		or not saved.get("actors", [1]).is_empty() or not saved.get("source", [1]).is_empty(): return false
	var expected: Array = report.initial_authored_fixture.edits
	var actual: Variant = saved.get("edits")
	if not actual is Array or actual.size() != expected.size(): return false
	for index: int in range(expected.size()):
		if not _same_numbers(actual[index], expected[index]): return false
	return true


func _authored_plane(captured: Dictionary) -> bool:
	if not _valid_capture(captured): return false
	# Independently transcribed fixture geometry: hard wall ID58 enclosure,
	# Sand ID2 in its upper interior. No fixture builder or oracle helper call.
	for y: int in range(48):
		for x: int in range(48):
			var expected := 0
			if x < 2 or x >= 46 or y < 2 or y >= 46: expected = 58
			elif x >= 16 and x < 24 and y >= 8 and y < 16: expected = 2
			if int(captured.materials[y * 48 + x]) != expected: return false
	return true


func _same_plane(first: Dictionary, last: Dictionary) -> bool:
	if not _valid_capture(first) or not _valid_capture(last): return false
	for index: int in range(2304):
		if int(first.materials[index]) != int(last.materials[index]): return false
	return true


func _sand_moved(captured: Dictionary) -> bool:
	if not _valid_capture(captured): return false
	var sand := 0
	var walls := 0
	var vertical_sum := 0
	for index: int in range(2304):
		var material: int = int(captured.materials[index])
		if material == 2:
			sand += 1
			vertical_sum += floori(float(index) / 48.0)
		elif material == 58: walls += 1
	return sand == 64 and walls == 368 and vertical_sum > 736 and not _authored_plane(captured)


func _capture(label: String, captures: Dictionary) -> Dictionary:
	var captured: Dictionary = await controller.adapter.capture(CELL_REGION)
	captures[label] = captured.duplicate(true)
	report["pending_captures"] = captures.duplicate(true)
	_write_checkpoint()
	return captured


func _campaign_async(configuration: Dictionary, provenance: Dictionary, plan: Dictionary) -> void:
	_case_tape = await controller.run_campaign(configuration, provenance, {}, plan)
	_case_finished = true


func _case(name: String, actions: Array, header: Dictionary, provenance: Dictionary) -> Dictionary:
	var result := {"case": name, "prescribed_actions": actions.duplicate(true), "captures": {},
		"status": "in_progress", "classification": "unresolved_observation", "gameplay_defect_confirmed": false}
	var configuration := {"fixture_id": "conservation_cell", "policy": "CONTROL", "seed": 13,
		"budget": actions.size(), "pacing_ms": 0, "evidence_kind": "headless_godot",
		"start_paused": true, "reuse_memory": false, "execution_limit_msec": 30000, "absolute_limit_msec": 35000}
	var plan := {"schema": "cybersand-goblin-action-fixture-v1", "header": header.duplicate(true), "actions": actions.duplicate(true)}
	_case_finished = false
	_case_tape = {}
	result["source_evidence_kind"] = "actual_observation_embedded_owner_mutex_snapshot"
	report["pending_case"] = name
	report["pending_prescribed_actions"] = actions.duplicate(true)
	_write_checkpoint()
	_campaign_async.call_deferred(configuration, provenance, plan)
	if not await _wait_until(func() -> bool: return _case_finished or (controller.running and controller.state == "paused" and controller.attempted == 0), 15000):
		controller.stop()
		result.status = "setup_deadline"
		return result
	if _case_finished:
		result.status = "setup_refused"
		result["transcript"] = _case_tape.duplicate(true)
		return result
	var initial: Dictionary = controller.adapter.observe()
	result["initial_observation"] = initial.duplicate(true)
	var mode_offered := false
	for offered: Dictionary in controller.adapter.available_actions():
		if offered.get("id") == "response_mode" and offered.get("args", {}).get("mode") == VARIANT_MODE:
			mode_offered = true
	result["variant_response_actually_offered"] = mode_offered
	var initial_ok: bool = _actor_free(initial) and initial.get("paused") == true \
		and initial.get("native", {}).get("tick") == 0 and initial.get("native", {}).get("failed") == false
	var initial_capture: Dictionary = await _capture("authored_start", result.captures)
	if not initial_ok or not _authored_plane(initial_capture) or (name == "retained_zero_tick_variant" and not mode_offered):
		controller.stop()
		await _wait_until(func() -> bool: return _case_finished, 5000)
		result.status = "setup_unqualified"
		result["transcript"] = _case_tape.duplicate(true)
		return result
	for index: int in range(actions.size()):
		controller.step_decision()
		if not await _wait_until(func() -> bool: return _case_finished or (controller.attempted > index and controller.state == "paused"), 15000):
			controller.stop()
			result["incomplete_reason"] = "action_deadline_at_" + str(index)
			break
		if controller.attempted != index + 1:
			controller.stop()
			result["incomplete_reason"] = "unexpected_attempt_count_at_" + str(index)
			break
		if controller.attempted > index:
			var row: Dictionary = controller.transcript.steps[index]
			if row.get("status") == "completed" and row.action.id in ["pause", "response_mode"]:
				await _capture("paused_after_play" if row.action.id == "pause" else "retained_after_response", result.captures)
			if row.get("status") == "completed" and row.action.id == "save_layout":
				# Read only the adapter's fixed disposable named Save, through the
				# ordinary file decoder. Expectations come from the installed recipe.
				result["saved_authored_file"] = Setup.read_named(Adapter.SAVE_NAME)
		if _case_finished: break
	if not _case_finished:
		controller.stop()
		await _wait_until(func() -> bool: return _case_finished, 5000)
	result["transcript"] = _case_tape.duplicate(true)
	result["validation"] = Transcript.validate(_case_tape)
	if not _case_finished or _case_tape.get("steps", []).size() != actions.size():
		result.status = "incomplete_action_sequence"
		return result
	var rows: Array = _case_tape.steps
	var all_completed := true
	var actor_free := true
	var failures: Array[Dictionary] = []
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		if row.action.id != actions[index].id or row.action.args != actions[index].args \
			or row.get("status") != "completed" or row.get("admission", {}).get("accepted") != true: all_completed = false
		if not _actor_free(row.get("before", {})) or not _actor_free(row.get("after", {})): actor_free = false
		for assertion: Dictionary in row.get("assertions", []):
			if assertion.get("status") == "fail": failures.append({"step": index, "assertion": assertion.duplicate(true)})
	result["recorded_failed_assertions"] = failures
	if not all_completed or result.validation.get("ok") != true:
		result.status = "unqualified_action_sequence"
		return result
	var save: Dictionary = rows[rows.size() - 2]
	var reopen: Dictionary = rows.back()
	for row: Dictionary in [save, reopen]:
		if not row.get("persistence") is Dictionary or not row.get("persistence_capture") is Dictionary:
			result.status = "missing_persistence_evidence"
			return result
	var reopened_capture: Dictionary = await _capture("reopened_authored_start", result.captures)
	var saved_file: Dictionary = result.get("saved_authored_file", {})
	var expected_mode := VARIANT_MODE if name == "retained_zero_tick_variant" else "LA-SELECTIVE"
	var checks := {
		"exact_completed_action_sequence": all_completed,
		"native_transcript_valid": result.validation.get("ok", false),
		"actor_and_source_free_throughout": actor_free,
		"authored_initial_plane": _authored_plane(initial_capture),
		"actual_sand_movement": _sand_moved(result.captures.get("paused_after_play", {})),
		"authored_reopen_plane": _authored_plane(reopened_capture),
		"authored_save_file_keeps_original_recipe": _authored_file_matches(saved_file, expected_mode),
		"same_authored_file_identity": not str(save.get("persistence", {}).get("read_authored_digest", "")).is_empty() \
			and save.persistence.get("read_authored_digest") == save.after.get("authored_digest") \
			and save.persistence.get("read_authored_digest") == reopen.after.get("authored_digest") \
			and save.persistence.get("read_authored_digest") == Adapter.digest(saved_file.get("setup", {})),
		"full_material_captures_match_native_sources": _source_fenced_capture(save.persistence_capture, [0, 0, 512, 512], save.after) \
			and _source_fenced_capture(reopen.persistence_capture, [0, 0, 512, 512], reopen.after),
		"regional_captures_match_native_sources": _source_fenced_capture(initial_capture, [48, 48, 48, 48], initial) \
			and _source_fenced_capture(result.captures.get("paused_after_play", {}), [48, 48, 48, 48], rows[1].after) \
			and _source_fenced_capture(reopened_capture, [48, 48, 48, 48], reopen.after),
	}
	result["checks"] = checks
	var supported_terminal: bool = _case_tape.summary.termination in ["budget_complete", "assertion_failure"]
	checks["supported_terminal"] = supported_terminal
	if name == "positive_tick_control":
		checks["positive_saved_clock"] = int(save.after.native.tick) >= 16
		checks["evolved_material_equality_inapplicable"] = save.persistence.get("native_material_equality_applicable") == false \
			and reopen.persistence.get("native_material_equality_applicable") == false
		checks["control_runtime_assertions_pass"] = failures.is_empty() and _case_tape.summary.termination == "budget_complete"
		result.status = "qualified_control" if checks.values().all(func(value: Variant) -> bool: return value == true) else "control_unqualified"
	else:
		var mode: Dictionary = rows[2]
		checks["retained_generation_with_zero_local_clock"] = int(mode.before.native.tick) >= 16 \
			and int(mode.after.native.generation) > int(mode.before.native.generation) and int(mode.after.native.tick) == 0
		checks["mode_preserves_actual_evolved_cells"] = _same_plane(result.captures.get("paused_after_play", {}), result.captures.get("retained_after_response", {}))
		checks["mode_capture_matches_native_source"] = _source_fenced_capture(result.captures.get("retained_after_response", {}), [48, 48, 48, 48], mode.after)
		checks["saved_retained_plane_differs_from_authored_reopen"] = save.persistence_capture.get("material_sha256") != reopen.persistence_capture.get("material_sha256")
		var product_relations_observed: bool = checks.values().all(func(value: Variant) -> bool: return value == true)
		var target_only: bool = failures.size() == 1 and failures[0].step == rows.size() - 1 \
			and failures[0].assertion.id == "authored_reopen_materials" and _case_tape.summary.termination == "assertion_failure"
		var applicability: bool = save.persistence.get("native_material_equality_applicable") == true \
			and reopen.persistence.get("native_material_equality_applicable") == true
		result["hypothesis_reproduced"] = product_relations_observed and target_only and applicability
		result.status = "hypothesis_reproduced" if result.hypothesis_reproduced else ("not_reproduced" if product_relations_observed and failures.is_empty() else "unresolved_observation")
		result.classification = "test_oracle_applicability_candidate" if result.hypothesis_reproduced else "unresolved_observation"
		var candidate_path: String = str(_case_tape.get("controller", {}).get("automatic_candidate_bundle", ""))
		result["automatic_candidate_bundle"] = {"path": candidate_path,
			"exists": not candidate_path.is_empty() and FileAccess.file_exists(candidate_path),
			"sha256": FileAccess.get_sha256(candidate_path) if not candidate_path.is_empty() and FileAccess.file_exists(candidate_path) else ""}
		if result.hypothesis_reproduced and not result.automatic_candidate_bundle.exists: result.status = "candidate_capture_failure"
	return result


func _finish(exit_code: int) -> void:
	if controller != null:
		controller.stop()
		if await _wait_until(func() -> bool: return not controller.running, 5000):
			await controller.close()
			controller.queue_free()
	report["elapsed_msec"] = Time.get_ticks_msec() - int(report.get("started_msec", Time.get_ticks_msec()))
	report["diagnostic_exit_code"] = exit_code
	if not _write_checkpoint(): exit_code = 2
	print("GOBLIN_RETAINED_CLOCK_COMPLETE ", JSON.stringify({"status": report.get("status"),
		"hypothesis_reproduced": report.get("hypothesis_reproduced", false), "output": OUTPUT,
		"diagnostic_exit_code": exit_code, "production_defect_claim": false}))
	quit(exit_code)


func run() -> void:
	var start: int = Time.get_ticks_msec()
	_deadline_msec = start + 75000
	var launch: Dictionary = Controller.read_launch()
	report = {"schema": "goblin-retained-clock-diagnostic-v1", "status": "initializing", "started_msec": start,
		"base_game_source": BASE_GAME_SOURCE, "instrumentation_sha256": FileAccess.get_sha256(ENTRYPOINT),
		"adapter_instrumentation_sha256": FileAccess.get_sha256("res://goblin/goblin_adapter.gd"),
		"actual_source_provenance": launch.get("provenance", {}), "evidence_kind": "headless_godot_diagnostic",
		"instrumentation_scope": "Fixed diagnostic plus exact read-only adapter queue-evidence delta; launcher retains both changed sources and all unchanged game inputs",
		"prescribed_action_limit": 9, "internal_wall_msec": 75000, "cases": [],
		"gameplay_defect_confirmed": false, "production_defect_claim": false}
	if not launch.get("ok", false):
		report.status = "isolated_launch_refused"
		report["launch_error"] = launch
		await _finish(2)
		return
	# Bootstrap is ordinary native fixture installation and zero action attempts.
	# It obtains real installation identity; it does not forge the replay fence.
	var bootstrap = Adapter.new()
	root.add_child(bootstrap)
	var mounted: Dictionary = await bootstrap.mount()
	if not mounted.get("ok", false):
		report.status = "bootstrap_mount_refused"
		report["bootstrap"] = mounted
		await bootstrap.close()
		bootstrap.queue_free()
		await _finish(2)
		return
	var fixture: Dictionary = Fixtures.build("conservation_cell", bootstrap.policy())
	var installed: Dictionary = await bootstrap.install_fixture("conservation_cell", fixture)
	report["bootstrap"] = installed.duplicate(true)
	report["initial_authored_fixture"] = fixture.duplicate(true)
	var header := {"fixture_id": "conservation_cell", "fixture_version": Fixtures.VERSION,
		"fixture_sha256": Adapter.digest(fixture), "initial_scene_identity": str(installed.get("observation", {}).get("scene_identity", "")),
		"policy": "CONTROL", "seed": 13, "pacing_ms": 0, "evidence_kind": "headless_godot", "provenance": launch.provenance.duplicate(true)}
	await bootstrap.close()
	bootstrap.queue_free()
	if not installed.get("ok", false) or str(header.initial_scene_identity).is_empty():
		report.status = "bootstrap_fixture_refused"
		await _finish(2)
		return
	report["actual_fixture_header"] = header.duplicate(true)
	_write_checkpoint()
	controller = Controller.new()
	root.add_child(controller)
	var control: Dictionary = await _case("positive_tick_control", CONTROL_ACTIONS, header, launch.provenance)
	report.cases.append(control)
	_write_checkpoint()
	if control.status != "qualified_control":
		report.status = "control_unqualified"
		await _finish(2)
		return
	var variant: Dictionary = await _case("retained_zero_tick_variant", VARIANT_ACTIONS, header, launch.provenance)
	report.cases.append(variant)
	report["hypothesis_reproduced"] = variant.get("hypothesis_reproduced", false)
	report.status = variant.status
	report.erase("pending_case")
	report.erase("pending_captures")
	report.erase("pending_prescribed_actions")
	await _finish(0 if variant.status in ["hypothesis_reproduced", "not_reproduced"] else 2)
