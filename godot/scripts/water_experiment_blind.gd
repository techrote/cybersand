class_name CyberWaterExperimentBlind
extends RefCounted

const Profiles = preload("res://scripts/water_experiment_profiles.gd")
const VERSION: int = 1
const MAX_CANDIDATES: int = 26


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _next(state: int) -> int:
	# Local 31-bit LCG: deterministic, bounded, and independent of both the
	# simulation recipe seed and Godot's global random-number state.
	return (state * 1_103_515_245 + 12_345) & 0x7fff_ffff


static func create(candidates: Array, blind_seed: int) -> Dictionary:
	if blind_seed < 0 or blind_seed > Profiles.MAX_SEED:
		return _failure("blind seed must be an unsigned 31-bit integer")
	if candidates.size() < 2 or candidates.size() > MAX_CANDIDATES:
		return _failure("blind set must contain between 2 and 26 candidates")
	var normalized: Array[Dictionary] = []
	var hashes: Dictionary = {}
	for candidate: Variant in candidates:
		var resolved: Dictionary
		if candidate is Dictionary and candidate.get("ok", false) and candidate.has("policy"):
			resolved = Profiles.resolve({}, {}, candidate.policy)
			if resolved.ok and candidate.has("hash") and candidate.hash != resolved.hash:
				return _failure("blind candidate hash does not match its effective policy")
			if resolved.ok and candidate.has("source") and candidate.has("provenance"):
				resolved.source = candidate.source
				resolved.provenance = candidate.provenance.duplicate(true)
		else:
			resolved = Profiles.resolve({}, {}, candidate)
		if not resolved.ok:
			return _failure("invalid blind candidate: %s" % str(resolved.error))
		if hashes.has(resolved.hash):
			return _failure("blind candidates must have distinct effective policies")
		hashes[resolved.hash] = true
		normalized.append(resolved)

	var order: Array[int] = []
	for index: int in range(normalized.size()):
		order.append(index)
	var state: int = blind_seed
	for index: int in range(order.size() - 1, 0, -1):
		state = _next(state)
		var swap_index: int = state % (index + 1)
		var held: int = order[index]
		order[index] = order[swap_index]
		order[swap_index] = held

	var labels: Array[String] = []
	var hidden_mapping: Dictionary = {}
	for label_index: int in range(order.size()):
		var label: String = String.chr(65 + label_index)
		var candidate: Dictionary = normalized[order[label_index]]
		labels.append(label)
		hidden_mapping[label] = {
			"hash": candidate.hash,
			"canonical_json": candidate.canonical_json,
			"policy": candidate.policy.duplicate(true),
			"semantic": candidate.semantic.duplicate(),
			"source": candidate.source,
			"provenance": candidate.provenance.duplicate(true),
		}
	return {
		"ok": true,
		"version": VERSION,
		"blind_seed": blind_seed,
		"labels": labels,
		"hidden_mapping": hidden_mapping,
	}


static func visible_record(
	blind_set: Dictionary, label: String, run_controls: Dictionary = {}
) -> Dictionary:
	if not blind_set.get("ok", false) or not label in blind_set.get("labels", []):
		return _failure("unknown blind candidate label")
	var hidden: Dictionary = blind_set.hidden_mapping[label]
	return {
		"ok": true,
		"label": label,
		"scenario_id": hidden.policy.scenario_id,
		"seed": hidden.policy.seed,
		"run_controls": run_controls.duplicate(true),
		"revealed": false,
	}


static func export_metadata(blind_set: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not blind_set.get("ok", false):
		return _failure("cannot export an invalid blind set")
	if not blind_set.has("labels") or not blind_set.has("hidden_mapping"):
		return _failure("blind set is incomplete")
	for label: Variant in blind_set.labels:
		if not label is String or not blind_set.hidden_mapping.has(label):
			return _failure("blind mapping is incomplete")
		var hidden: Variant = blind_set.hidden_mapping[label]
		if not hidden is Dictionary or not hidden.has("policy") or not hidden.has("hash"):
			return _failure("blind candidate metadata is incomplete")
		var resolved: Dictionary = Profiles.resolve({}, {}, hidden.policy)
		if (
			not resolved.ok
			or resolved.hash != hidden.hash
			or resolved.canonical_json != hidden.get("canonical_json", "")
			or resolved.semantic != hidden.get("semantic", PackedInt32Array())
		):
			return _failure("blind candidate metadata does not reconstruct")
	var metadata: Dictionary = {
		"version": VERSION,
		"blind_seed": int(blind_set.blind_seed),
		"labels": blind_set.labels.duplicate(),
		"hidden_mapping": blind_set.hidden_mapping.duplicate(true),
		"context": context.duplicate(true),
	}
	return {"ok": true, "metadata": metadata}
