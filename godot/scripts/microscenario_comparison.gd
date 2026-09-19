class_name CyberMicroScenarioComparison
extends RefCounted

# Two complete validated definitions and at most one retained capture per slot.
# No World/worker reference, live profile setter, timer, or implicit replay.
const Contract = preload("res://scripts/microscenario_contract.gd")
var _slots: Dictionary = {}
var _reports: Dictionary = {}
var last_error: String = ""

func store(slot: String, value: Variant) -> bool:
	if not slot in ["A", "B"]:
		last_error = "Only A and B slots are supported"
		return false
	var checked: Dictionary = Contract.validate(value)
	if not checked.get("ok", false):
		last_error = str(checked.error)
		return false
	_slots[slot] = {"definition":checked.definition.duplicate(true), "hash":str(checked.hash)}
	_reports.erase(slot)
	last_error = ""
	return true

func definition(slot: String) -> Dictionary:
	return _slots.get(slot, {}).get("definition", {}).duplicate(true)

func retain(report: Dictionary) -> void:
	# The owner capture already carries its definition hash and completed tick.
	# Refuse unrelated/partial captures, and never expose a caller-owned record.
	if report.get("failed", true) or report.get("native", {}).is_empty(): return
	for slot: String in ["A", "B"]:
		if _slots.has(slot) and str(report.get("definition_hash", "")) == str(_slots[slot].hash):
			_reports[slot] = report.duplicate(true)

func summary() -> Dictionary:
	var out: Dictionary = {"slots":{}, "reports":{}, "matched_runtime_tick_seed":false,
		"scope":"Necessary comparison checks only; organic user inputs are not replayed or proven matched"}
	for slot: String in ["A", "B"]:
		if _slots.has(slot):
			var value: Dictionary = _slots[slot].definition
			out.slots[slot] = {"id":value.id, "seed":value.seed, "recipe_version":value.recipe_version,
				"definition_hash":_slots[slot].hash, "profile":value.get("presentation", {}).get("profile", "legacy")}
		if _reports.has(slot):
			var report: Dictionary = _reports[slot]
			out.reports[slot] = {"completed_tick":report.completed_tick, "outcome":report.outcome,
				"observations":report.observations.duplicate(true), "native":report.native.duplicate(true),
				"runtime_identity":report.runtime_identity.duplicate(true), "worker_count":report.worker_count}
	if _reports.has("A") and _reports.has("B"):
		var a: Dictionary = _reports.A
		var b: Dictionary = _reports.B
		var identity: Dictionary = a.runtime_identity
		out.matched_runtime_tick_seed = (a.completed_tick == b.completed_tick and a.seed == b.seed
			and a.worker_count == b.worker_count and identity == b.runtime_identity
			and str(identity.get("native_sha256", "unavailable")) != "unavailable"
			and str(identity.get("script_set_sha256", "unavailable")) != "unavailable")
	return out
