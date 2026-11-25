extends RefCounted

## Current-episode coverage is earned by actual observed acknowledgements.
## Imported memory only changes search priorities; it never increments evidence.
const State = preload("res://goblin/goblin_state.gd")
const SCHEMA := "cybersand-goblin-coverage-v1"
const DIMENSIONS := ["action", "action_transition", "state_transition", "material_interaction",
	"tool_material", "actor_environment", "lifecycle", "boundary_refusal", "outcome"]
const MAX_KEYS := 2048
const MAX_PRIOR_KEYS := 256
const MAX_RECENT := 32
const EDIT_ACTIONS := ["brush", "erase", "rectangle", "outline", "line", "paste", "fill", "undo", "redo", "stroke", "live_stroke", "interrupt_stroke"]
const PAINT_TOOLS := {"brush":"Brush", "rectangle":"Rectangle", "outline":"Outline", "line":"Line", "stroke":"Brush", "fill":"Fill"}
var _counts: Dictionary = {}
var _state_actions: Dictionary = {}
var _variants: Dictionary = {}
var _refusal_variants: Dictionary = {}
var _prior: Dictionary = {}
var _last_completed := ""
var _attempts := 0
var _admitted := 0
var _completed := 0
var _partial := 0
var _refused := 0
var _unobserved := 0
var _saturated: Dictionary = {}
var _recent: Array[Dictionary] = []
var last_novelty: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	_counts.clear()
	for dimension: String in DIMENSIONS: _counts[dimension] = {}
	_state_actions.clear()
	_variants.clear()
	_refusal_variants.clear()
	_prior.clear()
	_saturated.clear()
	_recent.clear()
	_last_completed = ""
	_attempts = 0
	_admitted = 0
	_completed = 0
	_partial = 0
	_refused = 0
	_unobserved = 0
	last_novelty = {}

func observe(record: Dictionary) -> Dictionary:
	var action: Dictionary = record.get("action", record.get("proposed", {}))
	var id := str(action.get("id", ""))
	var status := str(record.get("status", "unreported"))
	var before: Dictionary = record.get("before", {})
	var after: Dictionary = record.get("after", {})
	var admission: Dictionary = record.get("admission", {})
	var accepted: bool = admission.get("accepted") == true or admission.get("status") in ["queued", "accepted"]
	var factual: bool = State.observed(before) and State.observed(after)
	_attempts += 1
	var fresh: Dictionary = {}
	for dimension: String in DIMENSIONS: fresh[dimension] = 0
	if status == "refused":
		_refused += 1
		if factual:
			_increment(_refusal_variants, variant_key(action), "refused_parameter_variant")
			_add("boundary_refusal", id + ":" + str(record.get("classification", "unclassified")) + ":" + str(record.get("error", "")).left(200).sha256_text(), fresh)
	if not accepted or not factual or status not in ["completed", "partial"]:
		if not factual: _unobserved += 1
		_last_completed = ""
		return _report(fresh, id, status, before, after, factual)
	_admitted += 1
	if status == "partial": _partial += 1
	var first := State.signature(before)
	var last := State.signature(after)
	var transition := first + ">" + id + ":" + status + ">" + last
	_add("state_transition", transition, fresh)
	_increment(_state_actions, first + ":" + id, "state_action")
	_increment(_variants, variant_key(action), "parameter_variant")
	if status == "completed":
		_completed += 1
		_add("action", id, fresh)
		if not _last_completed.is_empty(): _add("action_transition", _last_completed + ">" + id, fresh)
		_last_completed = id
	else:
		_last_completed = ""
	_material_coverage(record, action, fresh)
	_actor_coverage(after, fresh)
	_lifecycle(before, after, fresh)
	var receipt: Dictionary = record.get("native_receipt", {})
	var failed_assertions: Array[String] = []
	for item: Variant in record.get("assertions", []):
		if item is Dictionary and item.get("status") == "fail": failed_assertions.append(str(item.get("id", "")).left(120))
	failed_assertions.sort()
	var outcome := {"action": id, "status": status, "classification": str(record.get("classification", "")),
		"receipt_kind": str(receipt.get("kind", "none")), "changed": _changed_bucket(receipt.get("changed")),
		"progression": State.progression(before, after), "failed_assertions": failed_assertions}
	_add("outcome", JSON.stringify(outcome, "", true).sha256_text(), fresh)
	return _report(fresh, id, status, before, after, true)

func _material_coverage(record: Dictionary, action: Dictionary, fresh: Dictionary) -> void:
	var before: Dictionary = record.get("capture_before", {})
	var after: Dictionary = record.get("capture_after", {})
	var action_id := str(action.get("id", ""))
	var last: Dictionary = record.get("after", {})
	var native: Dictionary = last.get("native", {})
	if not State.valid_capture(after, native): return
	var cells: Array = after.materials
	var width: int = int(after.region[2])
	var contacts: Dictionary = {}
	for index: int in range(cells.size()):
		var material: int = int(cells[index])
		if material == 0: continue
		for neighbor: int in [index + 1 if (index + 1) % width != 0 else -1, index + width]:
			if neighbor < 0 or neighbor >= cells.size(): continue
			var other: int = int(cells[neighbor])
			if other == 0 or other == material: continue
			contacts["adjacent:" + str(mini(material, other)) + "+" + str(maxi(material, other))] = true
	for key: String in contacts: _add("material_interaction", key, fresh)
	if action_id not in EDIT_ACTIONS: return
	var receipt: Dictionary = record.get("native_receipt", {})
	if receipt.get("status") != "completed": return
	# Tool/material coverage requires the operation to use that observed selected
	# pair. History, clipboard and eraser edits do not use the palette material.
	# Interrupted/live operations retain their own action and effect evidence.
	var first: Dictionary = record.get("before", {})
	if record.get("status") == "completed" and PAINT_TOOLS.has(action_id) \
		and last.get("tool") == PAINT_TOOLS[action_id] \
		and State._integer(first.get("material"), 0, 65535) and State._integer(last.get("material"), 0, 65535) \
		and first.material == last.material:
		_add("tool_material", str(last.tool) + ":" + str(int(last.material)), fresh)
	if not State.valid_capture(before, record.get("before", {}).get("native", {})) or before.region != after.region or before.materials.size() != cells.size(): return
	var changes: Dictionary = {}
	for index: int in range(cells.size()):
		var old: int = int(before.materials[index])
		var new: int = int(cells[index])
		if old != new: changes["edit:" + str(old) + ">" + str(new)] = true
	for key: String in changes: _add("material_interaction", key, fresh)

func _actor_coverage(observation: Dictionary, fresh: Dictionary) -> void:
	# This is observed model/fixture/spatial-zone coverage. It explicitly makes
	# no inference about contacts, navigation success, or nearby materials.
	for item: Variant in observation.get("actors", []).slice(0, State.MAX_ACTORS):
		if not item is Dictionary or item.get("observed") != true: continue
		var zone := State.position_zone(item.get("position"), observation.get("world_size", []))
		if zone == State.UNKNOWN: continue
		var role := "pilot" if item.get("id") == observation.get("pilot_actor") else "unpiloted"
		_add("actor_environment", str(item.get("model", "")).left(64) + ":" + str(observation.get("fixture_id", "")).left(80) + ":" + zone + ":" + role, fresh)

func _lifecycle(before: Dictionary, after: Dictionary, fresh: Dictionary) -> void:
	var progression := State.progression(before, after)
	if progression == "world_replaced": _add("lifecycle", "native_world_replacement", fresh)
	if before.has("scene_identity") and after.has("scene_identity") and before.get("scene_identity") != after.get("scene_identity"): _add("lifecycle", "authored_identity_change", fresh)
	if typeof(before.get("paused")) == TYPE_BOOL and typeof(after.get("paused")) == TYPE_BOOL and before.paused != after.paused:
		_add("lifecycle", "pause_to_play" if before.paused else "play_to_pause", fresh)
	if before.has("actors") and after.has("actors"):
		if before.actors.size() < after.actors.size(): _add("lifecycle", "actor_added", fresh)
		if before.actors.size() > after.actors.size(): _add("lifecycle", "actor_retired", fresh)
	if before.has("pilot_actor") and after.has("pilot_actor") and before.get("pilot_actor") != after.get("pilot_actor"): _add("lifecycle", "control_transfer", fresh)
	if before.has("saved_authored_digest") and after.has("saved_authored_digest") and before.get("saved_authored_digest") != after.get("saved_authored_digest"): _add("lifecycle", "authored_save_changed", fresh)

func _report(fresh: Dictionary, id: String, status: String, before: Dictionary, after: Dictionary, factual: bool) -> Dictionary:
	var total := 0
	for value: int in fresh.values(): total += value
	last_novelty = {"new_keys": fresh, "score": total, "action": id, "status": status, "observation_admitted": factual,
		"before_state": State.signature(before) if factual else "", "after_state": State.signature(after) if factual else ""}
	if total > 0:
		_recent.append(last_novelty.duplicate(true))
		if _recent.size() > MAX_RECENT: _recent.pop_front()
	return last_novelty.duplicate(true)

func _add(dimension: String, key: String, fresh: Dictionary) -> void:
	var values: Dictionary = _counts[dimension]
	if not values.has(key):
		if values.size() >= MAX_KEYS:
			_saturated[dimension] = true
			return
		fresh[dimension] = int(fresh.get(dimension, 0)) + 1
	_increment(values, key, dimension)

func _increment(values: Dictionary, key: String, dimension: String) -> void:
	if not values.has(key) and values.size() >= MAX_KEYS:
		_saturated[dimension] = true
		return
	values[key] = mini(1000000, int(values.get(key, 0)) + 1)

func score(action: Dictionary, observation: Dictionary, mode: String = "coverage") -> float:
	var id := str(action.get("id", ""))
	var first := State.signature(observation)
	var action_count: float = float(_counts.action.get(id, 0)) + float(_prior.get("action", {}).get(id, 0)) * 0.25
	var transition_count: float = float(_state_actions.get(first + ":" + id, 0)) + float(_prior.get("state_action", {}).get(first + ":" + id, 0)) * 0.5
	var pair_count: float = float(_counts.action_transition.get(_last_completed + ">" + id, 0)) + float(_prior.get("action_transition", {}).get(_last_completed + ">" + id, 0)) * 0.25
	var variants: float = float(_variants.get(variant_key(action), 0)) + float(_prior.get("variants", {}).get(variant_key(action), 0)) * 0.25
	var refusal_penalty: float = 1.0 + float(_refusal_variants.get(variant_key(action), 0)) * 1.5
	if mode == "stateful": return 1.0 / ((1.0 + variants * 0.25) * refusal_penalty)
	if mode == "novelty": return (2.0 / (1.0 + action_count) + 12.0 / (1.0 + transition_count) + 5.0 / (1.0 + variants)) / refusal_penalty
	return (10.0 / (1.0 + action_count) + 5.0 / (1.0 + pair_count) + 7.0 / (1.0 + transition_count) + 3.0 / (1.0 + variants)) / refusal_penalty

func summary() -> Dictionary:
	var unique: Dictionary = {}
	for dimension: String in DIMENSIONS: unique[dimension] = _counts[dimension].size()
	return {"schema": SCHEMA, "attempted_records": _attempts, "admitted_observed_actions": _admitted,
		"completed_admitted_actions": _completed, "partial_admitted_actions": _partial, "refused_actions": _refused,
		"records_without_native_observation": _unobserved, "unique": unique,
		"parameter_variants": _variants.size(), "refused_parameter_variants": _refusal_variants.size(), "state_action_pairs": _state_actions.size(),
		"saturated_dimensions": _saturated.keys(), "capacity_per_dimension": MAX_KEYS,
		"last_novelty": last_novelty.duplicate(true), "recent_novelty": _recent.duplicate(true),
		"prior_memory_loaded": not _prior.is_empty(), "scope": "current episode actual admitted observations only",
		"material_interaction_scope": "source-matched captured-region adjacency and edit transformations; no inferred chemical reaction",
		"actor_environment_scope": "observed actor model, authored fixture, spatial zone and pilot role; no inferred route success",
		"tool_material_scope": "completed captured paint operation matching observed selected tool and unchanged selected material; excludes eraser/history/clipboard/interrupted/live edits"}

func memory() -> Dictionary:
	return {"schema": SCHEMA, "action": _bounded_hints(_counts.action),
		"state_action": _bounded_hints(_state_actions), "action_transition": _bounded_hints(_counts.action_transition),
		"variants": _bounded_hints(_variants)}

func load_memory(value: Dictionary) -> bool:
	if value.get("schema") != SCHEMA or not value.get("action") is Dictionary: return false
	var copied: Dictionary = {}
	for dimension: String in ["action", "state_action", "action_transition", "variants"]:
		var supplied: Variant = value.get(dimension, {})
		if not supplied is Dictionary or supplied.size() > MAX_PRIOR_KEYS: return false
		copied[dimension] = {}
		for key: Variant in supplied:
			if not key is String or key.length() > 170 or not State._integer(supplied[key], 0, 1000000): return false
			copied[dimension][key] = int(supplied[key])
	_prior = copied
	return true

static func _bounded_hints(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in values:
		if result.size() >= MAX_PRIOR_KEYS: break
		result[key] = values[key]
	return result

static func variant_key(action: Dictionary) -> String:
	return JSON.stringify({"id": action.get("id"), "args": action.get("args", {})}, "", true).sha256_text()

static func _changed_bucket(value: Variant) -> String:
	if not State._integer(value, 0, 16777216): return State.UNKNOWN
	return "none" if int(value) == 0 else ("small" if int(value) <= 16 else ("medium" if int(value) <= 256 else "large"))

