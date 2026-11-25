extends RefCounted

## Pure bounded experiment memory. The controller owns profile verification and
## fixed-path IO; this class accepts no path and executes no action. Imported
## records are unverified hints until the separate replay pipeline reproduces them.
const Coverage = preload("res://goblin/goblin_coverage.gd")
const State = preload("res://goblin/goblin_state.gd")
const GameplayOracles = preload("res://goblin/goblin_gameplay_oracles.gd")
const SCHEMA := "cybersand-goblin-corpus-v1"
const MAX_RECORDS := 64
const MAX_PREFIX := 128
const MAX_BYTES := 2097152
const CLASSIFICATIONS := ["unresolved_observation", "legal_unusual_gameplay", "expected_refusal", "unsupported_action",
	"confirmed_harness_defect", "test_oracle_defect", "infrastructure_failure", "deliberate_negative_control", "confirmed_production_gameplay_defect"]
var _records: Array[Dictionary] = []
var _context: Dictionary = {}
var _prefix: Array[Dictionary] = []
var _episode_index := 0
var _sequence := 0
var _total_observed := 0
var _evicted := 0
var _all_completed := true
var _record_bytes := 0
var _last_completed_hint := ""
var _hints: Dictionary = {"schema": Coverage.SCHEMA, "action": {}, "state_action": {}, "action_transition": {}, "variants": {}}

func clear() -> void:
	_records.clear()
	_context.clear()
	_prefix.clear()
	_episode_index = 0
	_sequence = 0
	_total_observed = 0
	_evicted = 0
	_all_completed = true
	_record_bytes = 0
	_last_completed_hint = ""
	_hints = {"schema": Coverage.SCHEMA, "action": {}, "state_action": {}, "action_transition": {}, "variants": {}}

func begin_episode(context: Dictionary) -> bool:
	if not _context_valid(context): return false
	_context = context.duplicate(true)
	_prefix.clear()
	_episode_index = 0
	_all_completed = true
	_last_completed_hint = ""
	return true

func observe(record: Dictionary, novelty: Dictionary) -> Dictionary:
	if _context.is_empty(): return {"retained": false, "reason": "no exact episode context"}
	var action: Variant = record.get("action", record.get("proposed"))
	if not _action_shape(action): return {"retained": false, "reason": "invalid proposed action"}
	_episode_index += 1
	_total_observed += 1
	var admission: Dictionary = record.get("admission", {})
	var factual: bool = State.observed(record.get("before", {})) and State.observed(record.get("after", {}))
	var completed: bool = record.get("status") == "completed" and factual \
		and (admission.get("accepted") == true or admission.get("status") in ["queued", "accepted"])
	_all_completed = _all_completed and completed
	if _episode_index <= MAX_PREFIX: _prefix.append(action.duplicate(true))
	var failures: Array[String] = []
	for item: Variant in record.get("assertions", []):
		if item is Dictionary and item.get("status") == "fail": failures.append(str(item.get("id", "")).left(120))
	if completed:
		var id := str(action.id)
		_hint("action", id)
		_hint("state_action", str(novelty.get("before_state", "")) + ":" + id)
		_hint("variants", Coverage.variant_key(action))
		if not _last_completed_hint.is_empty(): _hint("action_transition", _last_completed_hint + ">" + id)
		_last_completed_hint = id
	else:
		_last_completed_hint = ""
	var novelty_score: int = clampi(int(novelty.get("score", 0)), 0, 1024)
	if not factual or (novelty_score <= 0 and failures.is_empty()): return {"retained": false, "reason": "no independently observed new outcome"}
	var classification := _classification(record, failures)
	var complete_prefix: bool = _episode_index <= MAX_PREFIX
	var entry := {"id": "", "sequence": _sequence + 1, "context": _context.duplicate(true),
		"step": _episode_index, "seed": int(_context.get("seed", 0)), "personality": str(_context.get("personality", "")),
		"classification": classification, "verification": "observed_candidate", "status": str(record.get("status", "")),
		"before_state": str(novelty.get("before_state", "")), "after_state": str(novelty.get("after_state", "")),
		"score": novelty_score + (100 if not failures.is_empty() else 0), "failed_assertions": failures,
		"prefix_complete": complete_prefix, "reusable": complete_prefix and _all_completed and failures.is_empty(),
		"actions": _prefix.duplicate(true) if complete_prefix else [],
		"native_observation_identity": State.identity(record.get("after", {})),
		"semantic_sha256": str(record.get("semantic_sha256", "")),
		"observation_sha256": str(record.get("observation_sha256", "")),
		"retention_scope": "action prefix from installed authored fixture" if complete_prefix else "observation only; setup prefix exceeded 128 actions"}
	entry.id = _entry_id(entry)
	for existing: Dictionary in _records:
		if existing.id == entry.id: return {"retained": false, "reason": "already retained", "id": entry.id}
	_sequence += 1
	if _records.size() >= MAX_RECORDS:
		var retire := _retire_index()
		if int(_records[retire].score) > int(entry.score):
			return {"retained": false, "reason": "bounded corpus retains higher-priority observations"}
		_record_bytes -= JSON.stringify(_records[retire]).to_utf8_buffer().size()
		_records.remove_at(retire)
		_evicted += 1
	_records.append(entry)
	_record_bytes += JSON.stringify(entry).to_utf8_buffer().size()
	while _record_bytes > MAX_BYTES - 262144 and not _records.is_empty():
		var retire := _retire_index()
		_record_bytes -= JSON.stringify(_records[retire]).to_utf8_buffer().size()
		_records.remove_at(retire)
		_evicted += 1
	var retained := _records.any(func(item: Dictionary) -> bool: return item.id == entry.id)
	return {"retained": retained, "id": entry.id, "classification": classification, "reusable": entry.reusable}

func export_data() -> Dictionary:
	return {"schema": SCHEMA, "records": _records.duplicate(true), "sequence": _sequence,
		"total_observed": _total_observed, "evicted": _evicted, "search_hints": _hints.duplicate(true),
		"contract": "bounded authored prefixes and observations, not asynchronous physics checkpoints"}

func import_data(value: Variant, action_validator: Callable) -> Dictionary:
	# Validate everything before replacing memory. No partly accepted import.
	if not action_validator.is_valid(): return {"ok": false, "error": "finite adapter action validator required"}
	if not _plain(value, 0) or not value is Dictionary or value.get("schema") != SCHEMA:
		return {"ok": false, "error": "unsupported or malformed corpus"}
	if JSON.stringify(value).to_utf8_buffer().size() > MAX_BYTES: return {"ok": false, "error": "corpus exceeds 2 MiB"}
	if not value.get("records") is Array or value.records.size() > MAX_RECORDS: return {"ok": false, "error": "corpus record bound"}
	if not State._integer(value.get("sequence"), 0, 1000000) or not State._integer(value.get("total_observed"), 0, 1000000) \
		or not State._integer(value.get("evicted"), 0, 1000000): return {"ok": false, "error": "corpus counters invalid"}
	var hints: Variant = value.get("search_hints")
	var hint_checker: RefCounted = Coverage.new()
	if not hints is Dictionary or not hint_checker.load_memory(hints): return {"ok": false, "error": "malformed search hints"}
	var staged: Array[Dictionary] = []
	var ids: Dictionary = {}
	for item: Variant in value.records:
		var checked := _validate_entry(item, action_validator)
		if not checked.ok: return checked
		if ids.has(item.id): return {"ok": false, "error": "duplicate corpus identity"}
		if int(item.sequence) > int(value.sequence): return {"ok": false, "error": "record exceeds sequence counter"}
		ids[item.id] = true
		var copy: Dictionary = item.duplicate(true)
		copy.verification = "imported_unverified"
		# A serialized label is not independent confirmation. Imported confirmed
		# findings stay unresolved until reproduced by the separate evidence path.
		if str(copy.classification).begins_with("confirmed_"):
			copy.classification = "unresolved_observation"
			copy.reusable = false
		staged.append(copy)
	_records = staged
	_record_bytes = 0
	for item: Dictionary in _records: _record_bytes += JSON.stringify(item).to_utf8_buffer().size()
	_sequence = int(value.sequence)
	_total_observed = int(value.total_observed)
	_evicted = int(value.evicted)
	_hints = hints.duplicate(true)
	for dimension: String in ["state_action", "action_transition", "variants"]:
		if not _hints.has(dimension): _hints[dimension] = {}
	_last_completed_hint = ""
	_context.clear()
	_prefix.clear()
	_episode_index = 0
	_all_completed = true
	return {"ok": true, "records": _records.size(), "verification": "imported hints only"}

func reuse_actions(context: Dictionary, offset: int = 0) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for item: Dictionary in _records:
		if item.get("reusable", false) and item.get("prefix_complete", false) and compatible_context(item.context, context):
			candidates.append(item)
	if candidates.is_empty(): return []
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.score) > int(b.score) if int(a.score) != int(b.score) else int(a.sequence) < int(b.sequence))
	var selected: Dictionary = candidates[posmod(offset, candidates.size())]
	var actions: Array[Dictionary] = []
	for item: Dictionary in selected.actions: actions.append(item.duplicate(true))
	return actions

func search_hints() -> Dictionary:
	return _hints.duplicate(true)

func summary() -> Dictionary:
	var counts: Dictionary = {}
	var reusable := 0
	var imported := 0
	var observations: Array[Dictionary] = []
	for entry: Dictionary in _records:
		var kind := str(entry.classification)
		counts[kind] = int(counts.get(kind, 0)) + 1
		if entry.reusable: reusable += 1
		if entry.verification == "imported_unverified": imported += 1
		observations.append({"id": entry.id, "classification": kind, "step": entry.step, "score": entry.score,
			"fixture_id": entry.context.fixture_id, "personality": entry.personality, "reusable": entry.reusable,
			"verification": entry.verification, "failed_assertions": entry.failed_assertions.duplicate()})
	return {"schema": SCHEMA, "records": _records.size(), "capacity": MAX_RECORDS, "maximum_prefix_actions": MAX_PREFIX,
		"total_observed": _total_observed, "evicted": _evicted, "reusable_prefixes": reusable, "imported_unverified": imported,
		"classifications": counts, "observations": observations, "physical_checkpoint_resume": false,
		"prior_hint_keys": {"action": _hints.action.size(), "state_action": _hints.state_action.size(),
			"action_transition": _hints.action_transition.size(), "variants": _hints.variants.size()}}

static func compatible_context(first: Dictionary, second: Dictionary) -> bool:
	if not _context_valid(first) or not _context_valid(second): return false
	for key: String in ["fixture_id", "fixture_version", "fixture_sha256", "provenance_sha256"]:
		if first[key] != second[key]: return false
	return true

static func _context_valid(value: Dictionary) -> bool:
	return value.get("fixture_id") is String and value.fixture_id.length() in range(1, 81) \
		and State._integer(value.get("fixture_version"), 1, 1024) \
		and _hash(value.get("fixture_sha256")) and _hash(value.get("provenance_sha256")) \
		and State._integer(value.get("seed", 0), -2147483648, 2147483647) \
		and value.get("personality", "") is String and str(value.get("personality", "")).length() <= 80

static func _classification(record: Dictionary, failures: Array[String]) -> String:
	if not failures.is_empty() or record.get("classification") in ["timeout", "native_failure", "adapter_failure"]:
		return "unresolved_observation"
	if GameplayOracles.expected_boundary_refusal(record): return "expected_refusal"
	if record.get("admission", {}).get("unsupported") == true: return "unsupported_action"
	if record.get("classification") == "invalid_action" or record.get("status") == "partial": return "unresolved_observation"
	if record.get("status") == "refused":
		return "expected_refusal" if record.get("classification") in ["not_applicable", "cancelled"] else "unresolved_observation"
	return "legal_unusual_gameplay"

func _retire_index() -> int:
	var chosen := 0
	for index: int in range(1, _records.size()):
		if int(_records[index].score) < int(_records[chosen].score) \
			or (int(_records[index].score) == int(_records[chosen].score) and int(_records[index].sequence) < int(_records[chosen].sequence)): chosen = index
	return chosen

static func _validate_entry(item: Variant, validator: Callable) -> Dictionary:
	if not item is Dictionary or not _hash(item.get("id")) or not item.get("context") is Dictionary \
		or not _context_valid(item.context) or item.get("classification") not in CLASSIFICATIONS:
		return {"ok": false, "error": "invalid corpus record identity or classification"}
	if item.get("verification") not in ["observed_candidate", "imported_unverified"] or item.get("status") not in ["completed", "partial", "refused"]:
		return {"ok": false, "error": "invalid observation status"}
	if not State._integer(item.get("sequence"), 1, 1000000) or not State._integer(item.get("step"), 1, 1024) \
		or not State._integer(item.get("score"), 0, 1124) or not State._integer(item.get("seed"), -2147483648, 2147483647):
		return {"ok": false, "error": "corpus record counters invalid"}
	if not item.get("personality") is String or item.personality.length() > 80 or not _hash(item.get("before_state")) or not _hash(item.get("after_state")):
		return {"ok": false, "error": "invalid state or personality"}
	if typeof(item.get("prefix_complete")) != TYPE_BOOL or typeof(item.get("reusable")) != TYPE_BOOL \
		or not item.get("actions") is Array or item.actions.size() > MAX_PREFIX:
		return {"ok": false, "error": "invalid bounded prefix"}
	if item.prefix_complete:
		if item.actions.size() != int(item.step) or item.actions.is_empty(): return {"ok": false, "error": "incomplete prefix claimed complete"}
	elif not item.actions.is_empty() or item.reusable: return {"ok": false, "error": "observation-only record cannot be reused"}
	if not item.get("failed_assertions") is Array or item.failed_assertions.size() > 64: return {"ok": false, "error": "invalid assertion references"}
	for failure: Variant in item.failed_assertions:
		if not failure is String or failure.is_empty() or failure.length() > 120: return {"ok": false, "error": "invalid assertion identity"}
	if item.reusable and (item.status != "completed" or not item.failed_assertions.is_empty()): return {"ok": false, "error": "failed or partial prefix cannot be reused"}
	if not item.get("native_observation_identity") is Dictionary or not item.get("retention_scope") is String: return {"ok": false, "error": "missing observation custody"}
	for key: String in ["semantic_sha256", "observation_sha256"]:
		if item.get(key) != "" and not _hash(item.get(key)): return {"ok": false, "error": "invalid transcript fingerprint"}
	for action: Variant in item.actions:
		if not _action_shape(action): return {"ok": false, "error": "invalid action shape"}
		var result: Variant = validator.call(action)
		if not result is Dictionary or result.get("ok") != true: return {"ok": false, "error": "unsupported finite game action"}
	if _entry_id(item) != item.id: return {"ok": false, "error": "corpus semantic identity differs"}
	return {"ok": true}

static func _entry_id(item: Dictionary) -> String:
	return JSON.stringify(_canonical({"context": item.context, "step": item.step, "before_state": item.before_state,
		"after_state": item.after_state, "actions": item.actions, "failed_assertions": item.failed_assertions}), "", true).sha256_text()

static func _action_shape(action: Variant) -> bool:
	if not action is Dictionary or not action.get("id") is String or action.id.is_empty() or action.id.length() > 80 \
		or not action.get("args") is Dictionary or action.args.size() > 16: return false
	for key: Variant in action:
		if key not in ["id", "args", "goal"]: return false
	if action.has("goal") and (not action.goal is String or action.goal.length() > 240): return false
	for key: Variant in action.args:
		if not key is String or key.length() > 80: return false
		var value: Variant = action.args[key]
		if value is String:
			if value.length() > 120: return false
		elif typeof(value) != TYPE_BOOL and not State._number(value): return false
	return true

static func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for index: int in range(value.length()):
		if value[index] not in "0123456789abcdef": return false
	return true

static func _plain(value: Variant, depth: int) -> bool:
	if depth > 10: return false
	if value == null or typeof(value) == TYPE_BOOL: return true
	if value is String: return value.length() <= 4096
	if State._number(value): return true
	if value is Array:
		if value.size() > 1024: return false
		for item: Variant in value:
			if not _plain(item, depth + 1): return false
		return true
	if value is Dictionary:
		if value.size() > 256: return false
		for key: Variant in value:
			if not key is String or key.length() > 128 or not _plain(value[key], depth + 1): return false
		return true
	return false


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_canonical(item))
		return result
	if value is float and is_finite(value) and value == floor(value): return int(value)
	return value



func _hint(dimension: String, key: String) -> void:
	var values: Dictionary = _hints[dimension]
	if not values.has(key) and values.size() >= Coverage.MAX_PRIOR_KEYS: return
	values[key] = mini(1000000, int(values.get(key, 0)) + 1)
