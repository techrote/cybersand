extends RefCounted

## Observation triage, never automatic production-defect adjudication. Raw evidence
## stays in exact-source game tapes; this bounded queue stores references only.
const GameplayOracles = preload("res://goblin/goblin_gameplay_oracles.gd")
const SCHEMA := "cybersand-goblin-findings-v1"
const MAX_RECORDS := 128
const CLASSIFICATIONS := ["unresolved_observation", "legal_unusual_gameplay", "expected_refusal", "unsupported_action",
	"confirmed_harness_defect", "test_oracle_defect", "infrastructure_failure", "deliberate_negative_control", "confirmed_production_gameplay_defect"]
var records: Array[Dictionary] = []
var _context: Dictionary = {}
var _run := 0
var _evicted := 0


func begin_episode(context: Dictionary, run_serial: int) -> void:
	_context = context.duplicate(true)
	_run = run_serial


func observe(row: Dictionary, novelty: Dictionary = {}) -> void:
	var failed: Array[String] = []
	for check: Dictionary in row.get("assertions", []):
		if check.get("status") == "fail": failed.append(str(check.get("id", "")).left(120))
	var status := str(row.get("status", ""))
	var classification := "legal_unusual_gameplay"
	if not failed.is_empty(): classification = "unresolved_observation"
	elif row.get("classification") in ["timeout", "native_failure", "adapter_failure"]: classification = "unresolved_observation"
	elif GameplayOracles.expected_boundary_refusal(row): classification = "expected_refusal"
	elif row.get("admission", {}).get("unsupported", false): classification = "unsupported_action"
	elif row.get("classification") == "invalid_action": classification = "unresolved_observation"
	elif status == "refused":
		classification = "expected_refusal" if row.get("classification") in ["not_applicable", "cancelled"] else "unresolved_observation"
	elif status == "partial": classification = "unresolved_observation"
	elif int(novelty.get("score", 0)) <= 0: return
	var item := {"id": (str(_run) + ":" + str(row.get("index", -1)) + ":" + str(row.get("observation_sha256", ""))).sha256_text(),
		"run_serial": _run, "step": int(row.get("index", -1)), "action": str(row.get("action", {}).get("id", "")),
		"status": status, "classification": classification, "failed_invariants": failed,
		"reason": str(row.get("error", row.get("admission", {}).get("reason", ""))).left(320),
		"novelty_score": int(novelty.get("score", 0)), "source_sha": str(_context.get("source_sha", "")),
		"fixture_id": str(_context.get("fixture_id", "")), "observation_sha256": str(row.get("observation_sha256", "")),
		"semantic_sha256": str(row.get("semantic_sha256", "")), "independent_reproductions": 0,
		"adjudication": "automatic triage only; no production defect confirmed", "review_note": ""}
	if records.size() >= MAX_RECORDS:
		# Preserve failure candidates ahead of routine novel successful states.
		var retire := 0
		for index: int in range(records.size()):
			if records[index].failed_invariants.is_empty():
				retire = index
				break
		records.remove_at(retire)
		_evicted += 1
	records.append(item)


func classify(id: String, classification: String, note: String) -> Dictionary:
	if classification not in CLASSIFICATIONS or note.strip_edges().is_empty() or note.length() > 1000:
		return {"ok": false, "error": "classification requires a supported category and 1..1000 character review note"}
	# Confirmation is intentionally owned by an independently examined issue/test
	# record, not a menu choice or a successful reducer pass.
	if classification.begins_with("confirmed_"):
		return {"ok": false, "error": "confirmed defects require independent engineering adjudication with a durable issue and reproduction"}
	for item: Dictionary in records:
		if item.id == id:
			item.classification = classification
			item.review_note = note
			item.adjudication = "manual laboratory triage"
			return {"ok": true}
	return {"ok": false, "error": "observation is no longer in the bounded queue"}


func summary() -> Dictionary:
	var counts := {}
	for item: Dictionary in records: counts[item.classification] = int(counts.get(item.classification, 0)) + 1
	return {"records": records.size(), "capacity": MAX_RECORDS, "evicted": _evicted,
		"classifications": counts, "confirmed_production_defects": 0,
		"scope": "bounded observation triage; independent examination required"}


func export_data() -> Dictionary:
	return {"schema": SCHEMA, "records": records.duplicate(true), "summary": summary()}
