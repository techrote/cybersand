extends RefCounted

## Bounded value-only tape. No paths, dispatch, subprocesses or game authority.
const SCHEMA := "cybersand-goblin-transcript-v1"
const MAX_ACTIONS := 1024
const ExpandedActions = preload("res://goblin/goblin_gameplay_actions.gd")
const MAX_BYTES := 33554432
const POLICIES := ["CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM", "STATEFUL", "NOVELTY", "COVERAGE_HUNTER", "DISASTER_ARTIST", "BOUNDARY_GOBLIN", "HISTORY_GOBLIN", "MATERIAL_ALCHEMIST", "ACTOR_ENTHUSIAST", "IMPATIENT_SWITCHER", "OBSESSIVE_REPRODUCER"]
const FIXTURES := ["material_playground", "actor_workshop", "construction", "liquid_channel", "save_reopen", "history_edges", "boundary_lab", "alchemy", "mixed_stress", "conservation_cell"]
const STATUS := ["proposed", "accepted", "refused", "partial", "completed"]
const CLASSIFICATIONS := ["game_observation", "not_applicable", "invalid_action", "timeout", "cancelled", "native_failure", "adapter_failure"]
const EMPTY_ACTIONS := ["pause", "copy", "undo", "redo", "save_layout", "reopen_layout", "reset_fixture", "actor_reset", "single_step"]
const SHAPES := ["rectangle", "outline", "line", "select_region"]


static func integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return integer(value) and value >= minimum and value <= maximum


static func _hex(value: Variant, count: int) -> bool:
	if not value is String or value.length() != count: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true


static func _valid_replay_identity(provenance: Dictionary) -> bool:
	var value: Variant = provenance.get("replay_identity")
	if not value is Dictionary or not _keys_exact(value, ["schema", "source_commit", "source_tree", "platform",
		"godot_sha256", "native_sha256", "rapier_sha256", "game_sources_sha256", "game_source_files", "import_normalization"]): return false
	if value.schema != "cybersand-goblin-replay-identity-v1" or value.platform not in ["linux", "windows"] \
		or value.import_normalization != "existing-four-rapier-import-descriptors-crlf-to-lf" \
		or typeof(provenance.get("source_dirty")) != TYPE_BOOL or not _in_range(value.game_source_files, 1, 100000): return false
	for key: String in ["source_commit", "source_tree", "platform", "godot_sha256", "native_sha256", "rapier_sha256"]:
		if value[key] != provenance.get(key): return false
	for key: String in ["source_commit", "source_tree"]:
		if not _hex(value[key], 40): return false
	for key: String in ["godot_sha256", "native_sha256", "rapier_sha256", "game_sources_sha256"]:
		if not _hex(value[key], 64): return false
	return true


static func same_execution_identity(first: Variant, second: Variant) -> bool:
	if not first is Dictionary or not second is Dictionary: return false
	if first.has("replay_identity") or second.has("replay_identity"):
		return _valid_replay_identity(first) and _valid_replay_identity(second) \
			and first.source_dirty == second.source_dirty \
			and JSON.stringify(_json_value(first.replay_identity), "", true) == JSON.stringify(_json_value(second.replay_identity), "", true)
	# Legacy evidence retains its original exact-provenance contract.
	return JSON.stringify(_json_value(first), "", true) == JSON.stringify(_json_value(second), "", true)


static func _keys_exact(args: Dictionary, required: Array, optional: Array = []) -> bool:
	for key: Variant in args:
		if key not in required and key not in optional: return false
	for key: String in required:
		if not args.has(key): return false
	return true


static func validate_action(action: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not action is Dictionary: return {"ok": false, "errors": ["Action is not an object."]}
	if not _keys_exact(action, ["id", "args"], ["goal"]): errors.append("Unknown or missing action fields.")
	if not action.get("id") is String or not action.get("args") is Dictionary:
		return {"ok": false, "errors": ["Action requires a string id and object args."]}
	if action.has("goal") and (not action.goal is String or action.goal.length() > 240): errors.append("Goal exceeds 240 characters.")
	var id: String = action.id
	var args: Dictionary = action.args
	var valid := false
	if id in EMPTY_ACTIONS:
		valid = args.is_empty()
	elif id == "play":
		valid = _keys_exact(args, [], ["ticks"]) and _in_range(args.get("ticks", 4), 1, 32)
	elif id == "wait_ticks":
		valid = _keys_exact(args, ["ticks"]) and _in_range(args.get("ticks"), 1, 32)
	elif id == "select_material":
		valid = _keys_exact(args, ["material"]) and integer(args.get("material")) and int(args.material) in [0, 2, 3, 7, 8, 9, 12, 13, 14, 16, 19, 23, 25, 26, 27, 28, 29, 58]
	elif id in ["brush", "erase"]:
		valid = _keys_exact(args, ["x", "y", "radius"]) and _in_range(args.get("x"), 8, 503) \
			and _in_range(args.get("y"), 8, 503) and _in_range(args.get("radius"), 0, 4)
	elif id in SHAPES:
		valid = _keys_exact(args, ["x0", "y0", "x1", "y1"])
		for key: String in ["x0", "y0", "x1", "y1"]:
			valid = valid and _in_range(args.get(key), 8, 503)
		if valid:
			valid = absi(int(args.x1) - int(args.x0)) < 64 and absi(int(args.y1) - int(args.y0)) < 64
	elif id in ["fill", "paste"]:
		valid = _keys_exact(args, ["x", "y"]) and _in_range(args.get("x"), 8, 503) and _in_range(args.get("y"), 8, 503)
	elif id == "camera":
		valid = _keys_exact(args, ["x", "y", "width", "height"]) and _in_range(args.get("x"), 0, 256) \
			and _in_range(args.get("y"), 0, 256) and integer(args.get("width")) and integer(args.get("height")) \
			and int(args.get("width")) in [240, 480] and int(args.get("height")) in [135, 270]
	elif id in ["actor_select", "actor_pilot"]:
		valid = _keys_exact(args, ["actor_id"]) and _in_range(args.get("actor_id"), 1, 64)
	elif id == "actor_place":
		valid = _keys_exact(args, ["model", "x", "y"]) and args.get("model") in ["kestrel", "reference_barrel", "runner", "crawler", "monowheel", "stuntbuggy"] \
			and _in_range(args.get("x"), 32, 448) and _in_range(args.get("y"), 32, 224)
	elif id == "actor_drive":
		valid = _keys_exact(args, ["direction", "ticks"]) and args.get("direction") in ["left", "right", "up", "down"] \
			and _in_range(args.get("ticks"), 1, 16)
	elif id == "panel":
		valid = _keys_exact(args, ["panel", "open"]) and args.get("panel") == "details" and args.get("open") is bool
	elif id in ExpandedActions.IDS:
		valid = bool(ExpandedActions.validate_action(action).get("ok", false))
	if not valid: errors.append("Unknown action or arguments outside the finite goblin vocabulary.")
	return {"ok": errors.is_empty(), "errors": errors}


static func _json_value(value: Variant, depth: int = 0) -> Variant:
	if depth > 32: return null
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = _json_value(value[key], depth + 1)
		return result
	if value is Array or value is PackedInt32Array or value is PackedInt64Array \
		or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray or value is PackedByteArray:
		var result := []
		for item: Variant in value: result.append(_json_value(item, depth + 1))
		return result
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Rect2 or value is Rect2i: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value == null or value is bool or value is int or value is String: return value
	if value is float and is_finite(value): return int(value) if value == floor(value) else value
	return null


static func create(metadata: Dictionary) -> Dictionary:
	# This estimate only avoids repeated whole-tape serialization while playing.
	# Validators and the controller writer still enforce the actual encoded limit.
	return {"schema": SCHEMA, "header": _json_value(metadata), "steps": [], "summary": {},
		"storage_estimate_bytes": JSON.stringify(_json_value(metadata)).to_utf8_buffer().size() + 2097152}


static func semantic_projection(record: Dictionary) -> Dictionary:
	var raw_after: Variant = record.get("after", {})
	var after: Dictionary = raw_after if raw_after is Dictionary else {}
	var state := {}
	for key: String in ["paused", "material", "tool", "fixture_id", "selection", "camera", "panels", "details_open", "authored_digest", "selected_actor", "pilot_actor"]:
		if after.has(key): state[key] = after[key]
	var assertions := []
	var raw_assertions: Variant = record.get("assertions", [])
	if raw_assertions is Array:
		for assertion: Variant in raw_assertions:
			if assertion is Dictionary:
				assertions.append({"id": assertion.get("id"), "status": assertion.get("status"), "kind": assertion.get("kind")})
	var materials := {}
	for key: String in ["capture_before", "capture_after"]:
		var raw_capture: Variant = record.get(key, {})
		var capture: Dictionary = raw_capture if raw_capture is Dictionary else {}
		materials[key] = {"region": capture.get("region", []), "materials": capture.get("materials", [])}
	var raw_action: Variant = record.get("action", {})
	var action: Dictionary = raw_action if raw_action is Dictionary else {}
	var raw_receipt: Variant = record.get("native_receipt", {})
	var receipt: Dictionary = raw_receipt if raw_receipt is Dictionary else {}
	var accounting := {}
	for key: String in ["kind", "status", "applied", "changed", "requested_cells", "backend"]:
		if receipt.has(key): accounting[key] = receipt[key]
	var raw_delivery: Variant = record.get("actor_delivery", {})
	var delivery: Dictionary = raw_delivery if raw_delivery is Dictionary else {}
	var raw_ports: Variant = delivery.get("sampled_ports", {})
	var ports: Dictionary = raw_ports if raw_ports is Dictionary else {}
	var actor_input := {"instance_id": delivery.get("instance_id"), "requested_direction": delivery.get("requested_direction"),
		"sampled_command": delivery.get("sampled_command", {}), "sampled_ports": ports.get("ports", {})}
	var persistence := {}
	var raw_persistence: Variant = record.get("persistence", {})
	if raw_persistence is Dictionary:
		for key: String in ["read_authored_digest", "expected_authored_digest", "reopened_authored_digest", "material_sha256", "saved_material_sha256", "reopened_material_sha256", "native_material_equality_applicable", "native_material_equality_reason"]:
			if raw_persistence.has(key): persistence[key] = raw_persistence[key]
	var capture_outcome := {}
	var raw_persistence_capture: Variant = record.get("persistence_capture", {})
	if raw_persistence_capture is Dictionary and raw_persistence_capture.get("native_receipt", {}) is Dictionary:
		var capture_receipt: Dictionary = raw_persistence_capture.get("native_receipt", {})
		for key: String in ["kind", "status", "reason", "requested_cells", "applied", "changed"]:
			if capture_receipt.has(key): capture_outcome[key] = capture_receipt[key]
	return {"action": {"id": action.get("id"), "args": action.get("args", {})},
		"status": record.get("status"), "classification": record.get("classification"),
		"state": state, "captures": materials, "receipt_accounting": accounting, "actor_input": actor_input,
		"persistence": persistence, "persistence_capture_outcome": capture_outcome, "assertions": assertions}


static func observation_projection(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate(true)
	for key: String in ["index", "observation_sha256", "semantic_sha256"]: result.erase(key)
	return result


static func append(transcript: Dictionary, record: Dictionary, assertions: Array) -> Dictionary:
	if transcript.get("schema") != SCHEMA or not transcript.get("steps") is Array:
		return {"ok": false, "error": "Not a goblin transcript."}
	if transcript.steps.size() >= MAX_ACTIONS or transcript.steps.size() >= int(transcript.get("header", {}).get("budget", 0)):
		return {"ok": false, "error": "Transcript action budget exhausted."}
	var row: Dictionary = _json_value(record)
	row.index = transcript.steps.size()
	row.assertions = _json_value(assertions)
	row.observation_sha256 = JSON.stringify(_json_value(observation_projection(row))).sha256_text()
	row.semantic_sha256 = JSON.stringify(_json_value(semantic_projection(row))).sha256_text()
	var row_bytes: int = JSON.stringify(row).to_utf8_buffer().size() + 2
	var previous_bytes: int = int(transcript.get("storage_estimate_bytes", 0))
	if previous_bytes <= 0:
		previous_bytes = JSON.stringify(transcript).to_utf8_buffer().size() + 2097152
	if previous_bytes + row_bytes > MAX_BYTES:
		return {"ok": false, "error": "Transcript byte budget exhausted."}
	transcript.steps.append(row)
	transcript.storage_estimate_bytes = previous_bytes + row_bytes
	return {"ok": true, "index": row.index}


static func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


static func summarize(transcript: Dictionary, termination: String) -> Dictionary:
	var states := {}
	var classifications := {}
	var attempts := {}
	var completed := {}
	var pairs := {}
	var triples := {}
	var failures := []
	var total_usec := 0
	var previous: Array[String] = []
	var assertions := {"pass": 0, "fail": 0, "not_applicable": 0}
	for row: Dictionary in transcript.get("steps", []):
		var id: String = str(row.get("action", {}).get("id", ""))
		_increment(attempts, id)
		_increment(states, str(row.get("status", "")))
		_increment(classifications, str(row.get("classification", "")))
		total_usec += int(row.get("duration_usec", 0))
		if row.get("status") == "completed":
			_increment(completed, id)
			if previous.size() >= 1: _increment(pairs, previous[-1] + " -> " + id)
			if previous.size() >= 2: _increment(triples, previous[-2] + " -> " + previous[-1] + " -> " + id)
			previous.append(id)
			if previous.size() > 2: previous.pop_front()
		else:
			previous.clear()
		for assertion: Dictionary in row.get("assertions", []):
			_increment(assertions, str(assertion.get("status", "")))
			if assertion.get("status") == "fail":
				failures.append({"step": row.get("index"), "id": assertion.get("id"), "kind": assertion.get("kind")})
	return {"termination": termination, "attempted_actions": transcript.get("steps", []).size(),
		"completed_actions": int(states.get("completed", 0)), "status_counts": states,
		"classification_counts": classifications, "action_attempts": attempts,
		"completed_features": completed, "distinct_completed_features": completed.size(),
		"completed_adjacent_pairs": pairs, "completed_triples": triples,
		"assertions": assertions, "failures": failures, "duration_usec": total_usec}


static func finish(transcript: Dictionary, termination: String) -> Dictionary:
	transcript.summary = summarize(transcript, termination)
	return transcript.summary


static func _validate_capture(capture: Variant, errors: Array[String], label: String) -> void:
	if not capture is Dictionary:
		errors.append(label + " is not an object.")
		return
	if capture.is_empty(): return
	if capture.has("error"):
		if not capture.error is String or capture.error.is_empty(): errors.append(label + " has an invalid capture failure.")
		for key: String in ["native_receipt", "admission", "source_before", "source_after"]:
			if capture.has(key) and not capture[key] is Dictionary: errors.append(label + " has malformed " + key + ".")
		return # Retain refused capture evidence; no completed readback is claimed.
	var region: Variant = capture.get("region")
	var materials: Variant = capture.get("materials")
	if not region is Array or region.size() != 4 or not materials is Array:
		errors.append(label + " lacks a region/material array.")
		return
	for value: Variant in region:
		if not integer(value):
			errors.append(label + " region is not integral.")
			return
	if region[0] < 0 or region[1] < 0 or region[2] <= 0 or region[3] <= 0 \
		or region[0] + region[2] > 512 or region[1] + region[3] > 512 or region[2] * region[3] > 4096:
		errors.append(label + " exceeds bounded fixture capture.")
	if materials.size() != int(region[2]) * int(region[3]): errors.append(label + " incomplete material capture.")
	for material: Variant in materials:
		if not _in_range(material, 0, 131) or material == 10:
			errors.append(label + " contains an invalid material ID.")
			break


static func _validate_persistence_capture(capture: Variant, errors: Array[String], label: String) -> void:
	if not capture is Dictionary:
		errors.append(label + " is not an object.")
		return
	for key: String in ["native_receipt", "admission", "source_before", "source_after"]:
		if capture.has(key) and not capture[key] is Dictionary: errors.append(label + " has malformed " + key + ".")
	if capture.has("region"):
		var region: Variant = capture.region
		if not region is Array or region.size() != 4:
			errors.append(label + " has malformed region.")
			return
		for value: Variant in region:
			if not _in_range(value, 0, 512): errors.append(label + " has out-of-bounds region.")
	if capture.has("error") and not capture.error is String: errors.append(label + " has malformed error.")


static func validate(transcript: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not transcript is Dictionary or transcript.get("schema") != SCHEMA:
		return {"ok": false, "errors": ["Unknown transcript schema."]}
	if not transcript.get("header") is Dictionary or not transcript.get("steps") is Array or not transcript.get("summary") is Dictionary:
		return {"ok": false, "errors": ["Missing header, steps or summary."]}
	if JSON.stringify(transcript).to_utf8_buffer().size() > MAX_BYTES: errors.append("Transcript exceeds byte bound.")
	var header: Dictionary = transcript.header
	if header.get("fixture_id") not in FIXTURES: errors.append("Unknown committed fixture ID.")
	var no_installed_scene: bool = header.get("fixture_state") == "not_installed" and transcript.steps.is_empty() \
		and transcript.summary.get("termination") in ["stopped", "initialization_failure", "fixture_failure"]
	if not no_installed_scene and (not header.get("initial_scene_identity") is String \
		or header.get("initial_scene_identity", "").is_empty()): errors.append("Missing initial authored scene identity.")
	if not _in_range(header.get("fixture_version"), 1, 2): errors.append("Unknown committed fixture version.")
	if header.get("policy") not in POLICIES: errors.append("Unknown policy.")
	if header.has("pacing_ms") and not _in_range(header.pacing_ms, 0, 3000): errors.append("Invalid recorded pacing.")
	if not _in_range(header.get("seed"), -2147483648, 2147483647): errors.append("Seed must be a signed int32.")
	if not _in_range(header.get("budget"), 1, MAX_ACTIONS): errors.append("Invalid action budget.")
	if transcript.steps.size() > MAX_ACTIONS or transcript.steps.size() > int(header.get("budget", 0)): errors.append("Too many actions.")
	if header.get("evidence_kind") not in ["unit_fixture", "headless_godot", "graphical_godot", "packaged_evaluator"]:
		errors.append("Evidence kind is not explicit.")
	var provenance: Variant = header.get("provenance", {})
	if not provenance is Dictionary: provenance = {}
	for key: String in ["source_commit", "source_tree"]:
		if not _hex(provenance.get(key), 40): errors.append("Missing full " + key + ".")
	for key: String in ["godot_sha256", "native_sha256", "rapier_sha256"]:
		if not _hex(provenance.get(key), 64): errors.append("Missing runtime " + key + ".")
	if provenance.has("replay_identity") and not _valid_replay_identity(provenance): errors.append("Invalid portable replay identity.")
	for index: int in range(transcript.steps.size()):
		var row: Variant = transcript.steps[index]
		if not row is Dictionary:
			errors.append("Step %d is not an object." % index)
			continue
		if row.get("index") != index: errors.append("Step index is not contiguous.")
		var action_check: Dictionary = validate_action(row.get("action"))
		if not action_check.ok: errors.append("Step %d action is invalid: %s" % [index, str(action_check.errors)])
		if row.get("status") not in STATUS or row.get("classification") not in CLASSIFICATIONS: errors.append("Step %d has an unknown disposition." % index)
		if not _in_range(row.get("duration_usec"), 0, 3600000000): errors.append("Step %d duration invalid." % index)
		for key: String in ["before", "after", "admission", "native_receipt", "interval"]:
			if not row.get(key) is Dictionary: errors.append("Step %d lacks %s evidence." % [index, key])
		_validate_capture(row.get("capture_before", {}), errors, "Step %d before" % index)
		_validate_capture(row.get("capture_after", {}), errors, "Step %d after" % index)
		if row.has("persistence_capture"): _validate_persistence_capture(row.persistence_capture, errors, "Step %d persistence capture" % index)
		if row.has("persistence"):
			if not row.persistence is Dictionary:
				errors.append("Step %d malformed persistence." % index)
			elif row.persistence.has("saved_capture"):
				_validate_persistence_capture(row.persistence.saved_capture, errors, "Step %d saved capture" % index)
		if not row.get("assertions") is Array:
			errors.append("Step %d lacks assertions." % index)
			continue
		if row.assertions.is_empty(): errors.append("Step %d has no independent assertions or explicit applicability result." % index)
		for assertion: Variant in row.assertions:
			if not assertion is Dictionary or assertion.get("status") not in ["pass", "fail", "not_applicable"] \
				or assertion.get("kind") not in ["gameplay", "evidence"] or not assertion.get("id") is String:
				errors.append("Step %d malformed assertion." % index)
		if row.get("observation_sha256") != JSON.stringify(_json_value(observation_projection(row))).sha256_text(): errors.append("Step %d observation fingerprint differs." % index)
		if row.get("semantic_sha256") != JSON.stringify(_json_value(semantic_projection(row))).sha256_text(): errors.append("Step %d semantic fingerprint differs." % index)
	if errors.is_empty() and not transcript.summary.is_empty():
		if JSON.stringify(_json_value(transcript.summary)) != JSON.stringify(_json_value(summarize(transcript,
			str(transcript.summary.get("termination", ""))))): errors.append("Summary does not match all attempted steps.")
	return {"ok": errors.is_empty(), "errors": errors}


static func replay_actions(transcript: Dictionary) -> Array:
	if not validate(transcript).ok or transcript.get("header", {}).get("fixture_state") == "not_installed": return []
	var actions := []
	for row: Dictionary in transcript.steps:
		var action: Dictionary = row.action.duplicate(true)
		for key: String in action.args:
			if integer(action.args[key]): action.args[key] = int(action.args[key])
		actions.append(action)
	return actions


static func compare(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var first: Dictionary = validate(expected)
	var second: Dictionary = validate(actual)
	if not first.ok or not second.ok:
		return {"semantic_match": false, "exact_observation_match": false, "classification": "invalid_evidence",
			"expected_errors": first.errors, "actual_errors": second.errors}
	if expected.header.get("fixture_state") == "not_installed" or actual.header.get("fixture_state") == "not_installed":
		return {"semantic_match": false, "exact_observation_match": false, "classification": "uninstalled_fixture_not_replayable"}
	var same_header: bool = expected.header.fixture_id == actual.header.fixture_id \
		and expected.header.seed == actual.header.seed \
		and expected.header.get("initial_scene_identity", "") == actual.header.get("initial_scene_identity", "") \
		and expected.header.get("fixture_version", 1) == actual.header.get("fixture_version", 1) \
		and expected.header.get("fixture_sha256") == actual.header.get("fixture_sha256") \
		and expected.header.get("pacing_ms", 0) == actual.header.get("pacing_ms", 0) \
		and same_execution_identity(expected.header.provenance, actual.header.provenance)
	var same_count: bool = expected.steps.size() == actual.steps.size()
	var semantic_match: bool = same_header and same_count
	var exact_match: bool = semantic_match
	var differences := []
	for index: int in range(mini(expected.steps.size(), actual.steps.size())):
		var semantic_equal: bool = expected.steps[index].semantic_sha256 == actual.steps[index].semantic_sha256
		var exact_equal: bool = expected.steps[index].observation_sha256 == actual.steps[index].observation_sha256
		semantic_match = semantic_match and semantic_equal
		exact_match = exact_match and exact_equal
		if not semantic_equal or not exact_equal:
			differences.append({"step": index, "semantic_match": semantic_equal, "exact_observation_match": exact_equal})
	return {"semantic_match": semantic_match, "exact_observation_match": exact_match,
		"classification": "matched" if semantic_match else "replay_divergence", "same_source_runtime": same_header,
		"same_action_count": same_count, "differences": differences}
