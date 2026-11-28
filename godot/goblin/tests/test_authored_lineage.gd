extends SceneTree

## Actual ordinary authored-persistence relationships in four disposable native
## sessions. No artificial World state, command injection or oracle replacement.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const OUTPUT := "user://goblin/authored-lineage-test.json"
const CASES := [
	{"id": "fresh_authored", "applicable": true, "actions": [
		{"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}]},
	{"id": "retained_evolved", "applicable": false, "actions": [
		{"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
		{"id": "response_mode", "args": {"mode": "LA-EVENT-OFF"}},
		{"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}]},
	{"id": "restore_authored", "applicable": true, "actions": [
		{"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
		{"id": "response_mode", "args": {"mode": "LA-EVENT-OFF"}}, {"id": "restore_start", "args": {}},
		{"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}]},
	{"id": "actor_reset_retains_evolved", "applicable": false, "actions": [
		{"id": "actor_place", "args": {"model": "kestrel", "x": 256, "y": 96}},
		{"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
		{"id": "actor_reset", "args": {}}, {"id": "actor_remove", "args": {}},
		{"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}]},
]

var controller: Variant
var report: Dictionary = {}
var _deadline := 0
var _timed_out := false
var _checks := 0


func _initialize() -> void:
	run.call_deferred()


func _process(_delta: float) -> bool:
	if _deadline > 0 and Time.get_ticks_msec() > _deadline and not _timed_out:
		_timed_out = true
		report.failures.append("internal270second_deadline")
		if controller != null: controller.stop()
	return false


func _write() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://goblin"))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(Adapter.json_value(report), "", true))
	file.flush()
	return true


func _check(item: Dictionary, key: String, condition: bool) -> void:
	_checks += 1
	item.checks[key] = condition
	if not condition:
		var label: String = str(item.id) + ":" + key
		report.failures.append(label)
		push_error("GOBLIN_AUTHORED_LINEAGE " + label)


func _numbers(actual: Variant, expected: Array) -> bool:
	if not actual is Array or actual.size() != expected.size(): return false
	for index: int in range(expected.size()):
		if typeof(actual[index]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(actual[index])) \
			or actual[index] != expected[index]: return false
	return true


func _capture(captured: Dictionary, observation: Dictionary) -> bool:
	var receipt: Dictionary = captured.get("native_receipt", {})
	var admission: Dictionary = captured.get("admission", {})
	var native: Dictionary = observation.get("native", {})
	var sha: String = str(captured.get("material_sha256", ""))
	if captured.has("error") or captured.get("source_matches") != true or captured.get("count") != 512 * 512 \
		or not _numbers(captured.get("region"), [0, 0, 512, 512]) \
		or not _numbers(receipt.get("region"), [0, 0, 512, 512]) \
		or sha.length() != 64 or not sha.is_valid_hex_number() or observation.get("paused") != true \
		or receipt.get("status") != "completed" or receipt.get("kind") != "capture" \
		or receipt.get("backend") != "CyberNativeCellWorld" or admission.get("status") != "queued" \
		or not admission.has("operation_id") or receipt.get("operation_id") != admission.operation_id \
		or receipt.get("observed_generation") != native.get("generation"): return false
	for side: String in ["source_before", "source_after"]:
		var source: Dictionary = captured.get(side, {})
		if source.get("paused") != true or source.get("failed") != false: return false
		for key: String in ["generation", "revision", "tick"]:
			if not native.has(key) or source.get(key) != native[key] or receipt.get(key) != native[key]: return false
	return true


func _authored_material_sha(fixture: Dictionary) -> String:
	# Independent direct rectangle interpretation, not Setup.rectangles or the
	# native constructor. These scenarios admit only their finite5-field recipe.
	if not _numbers(fixture.get("extent"), [512, 512]) or not fixture.get("edits") is Array \
		or fixture.edits.size() > 32: return ""
	var plane := PackedInt32Array()
	plane.resize(512 * 512)
	plane.fill(0)
	for rect: Variant in fixture.edits:
		if not rect is Array or rect.size() != 5: return ""
		for value: Variant in rect:
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value): return ""
		var x: int = int(rect[0])
		var y: int = int(rect[1])
		var width: int = int(rect[2])
		var height: int = int(rect[3])
		var material: int = int(rect[4])
		if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > 512 or y + height > 512 \
			or material < 0 or material > 131: return ""
		for yy: int in range(y, y + height):
			for xx: int in range(x, x + width): plane[yy * 512 + xx] = material
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(plane.to_byte_array())
	return hash.finish().hex_encode()


func _assertion_status(row: Dictionary, id: String, expected: String) -> bool:
	for assertion: Dictionary in row.get("assertions", []):
		if assertion.get("id") == id: return assertion.get("status") == expected
	return false


static func _same_full_provenance(first: Variant, second: Variant) -> bool:
	if not first is Dictionary or not second is Dictionary: return false
	# Transcript.create canonicalizes integral JSON floats to integers. Compare
	# every field under that same published representation, without reducing to
	# the portable replay identity subset or dropping incidental source fields.
	return JSON.stringify(Transcript._json_value(first), "", true) == JSON.stringify(Transcript._json_value(second), "", true)


static func provenance_comparison_controls() -> Dictionary:
	var original: Dictionary = {"source_commit": "a".repeat(40), "source_tree": "b".repeat(40),
		"godot_sha256": "c".repeat(64), "native_sha256": "d".repeat(64), "rapier_sha256": "e".repeat(64),
		"project_files_sha256": "f".repeat(64), "source_dirty": false, "python": "control-version",
		"native_source_input_count": 105.0, "rapier_source_input_count": 4.0,
		"replay_identity": {"game_source_files": 956.0}}
	var normalized: Dictionary = original.duplicate(true)
	normalized.native_source_input_count = 105
	normalized.rapier_source_input_count = 4
	normalized.replay_identity.game_source_files = 956
	var results: Dictionary = {"integral_json_number_representation": _same_full_provenance(original, normalized),
		"nondictionary_rejected": not _same_full_provenance(original, [])}
	for key: String in ["source_commit", "source_tree", "godot_sha256", "native_sha256", "rapier_sha256", "project_files_sha256", "python"]:
		var changed: Dictionary = normalized.duplicate(true)
		changed[key] = str(changed[key]) + "changed"
		results["changed_" + key + "_rejected"] = not _same_full_provenance(original, changed)
	var fractional: Dictionary = normalized.duplicate(true)
	fractional.native_source_input_count = 105.5
	results["fractional_count_rejected"] = not _same_full_provenance(original, fractional)
	var nested: Dictionary = normalized.duplicate(true)
	nested.replay_identity.game_source_files = 957
	results["changed_nested_count_rejected"] = not _same_full_provenance(original, nested)
	var boolean: Dictionary = normalized.duplicate(true)
	boolean.source_dirty = 0
	results["boolean_numeric_substitution_rejected"] = not _same_full_provenance(original, boolean)
	var missing: Dictionary = normalized.duplicate(true)
	missing.erase("native_source_input_count")
	results["missing_field_rejected"] = not _same_full_provenance(original, missing)
	var additional: Dictionary = normalized.duplicate(true)
	additional["unrecorded_extra"] = true
	results["extra_field_rejected"] = not _same_full_provenance(original, additional)
	return results


func _case(definition: Dictionary, header: Dictionary, provenance: Dictionary, evidence_kind: String) -> Dictionary:
	var actions: Array = definition.actions
	var item := {"id": definition.id, "status": "in_progress", "checks": {},
		"save_index": actions.size() - 2, "reopen_index": actions.size() - 1,
		"expected_equality_applicable": definition.applicable, "transcript": {}}
	var configuration := {"fixture_id": "conservation_cell", "policy": "CONTROL", "seed": 13,
		"budget": actions.size(), "pacing_ms": 0, "evidence_kind": evidence_kind,
		"reuse_memory": false, "execution_limit_msec": 60000, "absolute_limit_msec": 75000}
	var plan := {"schema": "cybersand-goblin-action-fixture-v1", "header": header.duplicate(true), "actions": actions.duplicate(true)}
	var tape: Dictionary = await controller.run_campaign(configuration, provenance, {}, plan)
	item.transcript = tape.duplicate(true)
	var valid_tape: bool = Transcript.validate(tape).get("ok", false)
	_check(item, "valid_native_tape", valid_tape)
	_check(item, "exact_source", _same_full_provenance(tape.get("header", {}).get("provenance"), provenance))
	_check(item, "budget_complete", tape.get("summary", {}).get("termination") == "budget_complete")
	var rows: Array = tape.get("steps", [])
	_check(item, "exact_action_count", rows.size() == actions.size())
	var exact := rows.size() == actions.size()
	var clean := true
	var modern := true
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		if index >= actions.size() or row.get("action") != actions[index] or row.get("status") != "completed" \
			or row.get("admission", {}).get("accepted") != true: exact = false
		if row.get("assertions", []).is_empty(): clean = false
		for assertion: Dictionary in row.get("assertions", []):
			if assertion.get("status") == "fail": clean = false
		if row.get("before", {}).get("adapter_version") != 3 or row.get("after", {}).get("adapter_version") != 3: modern = false
	_check(item, "exact_admitted_completed_actions", exact)
	_check(item, "runtime_assertions_clean", clean)
	_check(item, "lineage_contract_v3", modern)
	if not exact or not modern or not valid_tape:
		item.status = "fail"
		return item
	var save: Dictionary = rows[item.save_index]
	var reopen: Dictionary = rows[item.reopen_index]
	var saved: Dictionary = save.get("persistence", {})
	var restored: Dictionary = reopen.get("persistence", {})
	var saved_capture: Dictionary = save.get("persistence_capture", {})
	var reopened_capture: Dictionary = reopen.get("persistence_capture", {})
	var lineage: Dictionary = saved.get("saved_material_lineage", {})
	var expected_state: String = "authored_compatible" if definition.applicable else "simulation_exposed"
	_check(item, "actual_whole_plane_captures", _capture(saved_capture, save.after) and _capture(reopened_capture, reopen.after))
	_check(item, "saved_clock_is_zero", save.after.native.tick == 0 and saved.get("saved_native_tick") == 0)
	_check(item, "expected_saved_lineage", lineage.get("schema") == "cybersand-goblin-material-lineage-v1" and lineage.get("state") == expected_state)
	_check(item, "saved_lineage_custody", not lineage.is_empty() and lineage == restored.get("saved_material_lineage") and lineage == save.after.get("material_lineage"))
	_check(item, "explicit_comparison_applicability", saved.get("native_material_equality_applicable") == definition.applicable \
		and restored.get("native_material_equality_applicable") == definition.applicable)
	var reason: String = "available" if definition.applicable else "simulation_exposed_lineage"
	_check(item, "comparison_reason", saved.get("native_material_equality_reason") == reason and restored.get("native_material_equality_reason") == reason)
	_check(item, "required_assertion_disposition", _assertion_status(reopen, "authored_reopen_materials", "pass" if definition.applicable else "not_applicable"))
	_check(item, "authored_identity_passes", _assertion_status(save, "authored_save_readback", "pass") and _assertion_status(reopen, "authored_reopen_identity", "pass"))
	var equal: bool = not str(saved_capture.get("material_sha256", "")).is_empty() \
		and saved_capture.get("material_sha256") == reopened_capture.get("material_sha256")
	_check(item, "actual_material_relation", equal == definition.applicable)
	var authored_sha: String = _authored_material_sha(tape.get("initial_authored_fixture", {}))
	item["independent_authored_material_sha256"] = authored_sha
	_check(item, "independently_reconstructed_authored_plane", not authored_sha.is_empty() and authored_sha == reopened_capture.get("material_sha256"))
	if definition.id in ["retained_evolved", "restore_authored"]:
		var retained: Dictionary = rows[2]
		_check(item, "response_retains_exposure_at_zero_tick", retained.before.native.tick >= 16 \
			and retained.after.native.generation > retained.before.native.generation and retained.after.native.tick == 0 \
			and retained.after.material_lineage.state == "simulation_exposed")
	if definition.id == "restore_authored":
		var restored_row: Dictionary = rows[3]
		_check(item, "ordinary_restore_reestablishes_authored_state", restored_row.before.material_lineage.state == "simulation_exposed" \
			and restored_row.after.material_lineage.state == "authored_compatible" \
			and restored_row.after.native.generation > restored_row.before.native.generation and restored_row.after.native.tick == 0)
	if definition.id == "actor_reset_retains_evolved":
		var reset: Dictionary = rows[3]
		_check(item, "reset_selected_retains_exposure", reset.before.native.tick >= 16 and reset.after.native.tick == 0 \
			and reset.after.native.generation > reset.before.native.generation and reset.after.material_lineage.state == "simulation_exposed")
		_check(item, "ordinary_removal_clears_body_capture_precondition", rows[4].after.get("actor_ids") == [] \
			and rows[4].after.get("physical_body_count") == 0 and rows[4].after.material_lineage.state == "simulation_exposed")
	item.status = "pass" if item.checks.values().all(func(value: Variant) -> bool: return value == true) else "fail"
	return item


func _finish() -> void:
	if controller != null:
		await controller.close()
		controller.queue_free()
	var attempted := 0
	var completed := 0
	var all_cases: bool = report.native_cases.size() == 4
	for item: Dictionary in report.native_cases:
		all_cases = all_cases and item.get("status") == "pass"
		for row: Dictionary in item.get("transcript", {}).get("steps", []):
			attempted += 1
			if row.get("status") == "completed" and row.get("admission", {}).get("accepted") == true: completed += 1
	report["actual_actions"] = {"attempted": attempted, "completed": completed}
	report["checks"] = {"four_native_cases_pass": all_cases, "exact_twenty_actions": attempted == 20 and completed == 20,
		"bounded_completion": not _timed_out, "no_failed_checks": report.failures.is_empty(),
		"provenance_comparison_controls": not report.get("provenance_comparison_controls", {}).is_empty() \
			and report.provenance_comparison_controls.values().all(func(value: Variant) -> bool: return value == true)}
	report["check_count"] = _checks
	report["status"] = "pass" if report.checks.values().all(func(value: Variant) -> bool: return value == true) else "fail"
	if not _write():
		report.failures.append("report_write_failed")
		report.status = "fail"
	print("GOBLIN_AUTHORED_LINEAGE_RESULT ", JSON.stringify({"status": report.status, "failures": report.failures,
		"actual_actions": report.actual_actions, "checks": report.checks, "check_count": _checks}))
	quit(0 if report.status == "pass" else 1)


func run() -> void:
	_deadline = Time.get_ticks_msec() + 270000
	var launch: Dictionary = Controller.read_launch()
	report = {"schema": "cybersand-goblin-authored-lineage-test-v1", "status": "initializing", "checks": {},
		"failures": [], "native_cases": [], "provenance": launch.get("provenance", {}),
		"classification": "actual_authored_persistence_oracle_regression", "production_gameplay_defect_confirmed": false}
	report["provenance_comparison_controls"] = provenance_comparison_controls()
	if not report.provenance_comparison_controls.values().all(func(value: Variant) -> bool: return value == true):
		report.failures.append("provenance_comparison_controls")
		await _finish()
		return
	if not launch.get("ok", false):
		report.failures.append("isolated_launch_required")
		await _finish()
		return
	var bootstrap := Adapter.new()
	root.add_child(bootstrap)
	var mounted: Dictionary = await bootstrap.mount()
	if not mounted.get("ok", false):
		report.failures.append("ordinary_bootstrap_mount_refused")
		await bootstrap.close()
		bootstrap.queue_free()
		await _finish()
		return
	var fixture: Dictionary = Fixtures.build("conservation_cell", bootstrap.policy())
	var installed: Dictionary = await bootstrap.install_fixture("conservation_cell", fixture)
	report["bootstrap"] = installed.duplicate(true)
	var evidence_kind: String = str(launch.launch.get("evidence_kind", "headless_godot"))
	var header := {"fixture_id": "conservation_cell", "fixture_version": Fixtures.VERSION,
		"fixture_sha256": Adapter.digest(fixture), "initial_scene_identity": str(installed.get("observation", {}).get("scene_identity", "")),
		"policy": "CONTROL", "seed": 13, "pacing_ms": 0, "evidence_kind": evidence_kind, "provenance": launch.provenance.duplicate(true)}
	await bootstrap.close()
	bootstrap.queue_free()
	if not installed.get("ok", false) or str(header.initial_scene_identity).is_empty():
		report.failures.append("ordinary_fixture_bootstrap_refused")
		await _finish()
		return
	controller = Controller.new()
	root.add_child(controller)
	for definition: Dictionary in CASES:
		if _timed_out: break
		report["pending_case"] = definition.id
		_write()
		report.native_cases.append(await _case(definition, header, launch.provenance, evidence_kind))
		_write()
	report.erase("pending_case")
	await _finish()
