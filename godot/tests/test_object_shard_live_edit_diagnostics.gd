extends SceneTree

const Probe = preload("res://scripts/object_shard_live_edit_diagnostics.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var probe = Probe.new()
	probe.reset({"world_generation": 7, "session": 3, "transport_generation": 9})
	_expect(probe.record("attempt", {"tool": "weather", "radius": 12, "seed": 83,
		"position": Vector2i(17, 32), "world_generation": 7}), "Input exists before admission")
	_expect(probe.snapshot().recent.back().status == "input_not_yet_admitted", "Attempt never claims execution")
	for index: int in range(500):
		probe.record("wait", {"reason": "PhysicalInterval", "stroke_id": 1})
	var observed: Dictionary = probe.snapshot()
	_expect(observed.counts.wait == 500 and observed.coalesced_waits == 499
		and observed.recent.size() == 2, "Sustained admission starvation remains visible without flooding history")
	_expect(observed.recent.back().repetitions == 500
		and observed.recent.back().last_time_usec >= observed.recent.back().time_usec,
		"Coalesced waits preserve actual first/latest clocks and repetitions")
	probe.record("no_eligible", {"tool": "erase", "requested_cells": 65})
	_expect(probe.snapshot().recent.back().status == "no_eligible_visible_material", "Empty visible footprint differs from unadmitted input")
	probe.record("admitted", {"action_id": 14, "requested_cells": 65, "captured_usec": Time.get_ticks_usec()-100})
	_expect(probe.snapshot().pending_count == 1 and probe.snapshot().native_totals.is_empty(),
		"Admission does not assert changed cells")
	_expect(probe.snapshot().recent.back().get("input_to_admission_usec",0)>=100,
		"Actual input timestamp preserves waiting time before admission")
	probe.record("cancel", {"reason": "PointerReleased"})
	_expect(probe.snapshot().pending_count == 1, "Release stops future admission without pretending admitted work rolled back")
	probe.record("receipt", {"action_id": 14, "outcome": "Applied", "requested_cells": 65,
		"unique_cells": 61, "changed_cells": 50, "removed_cells": 50, "changed_owners": 1,
		"geometry_rebuilds": 1, "connectivity_passes": 1, "native_execution_usec": 102})
	observed = probe.snapshot()
	_expect(observed.pending_count == 1 and observed.recent.back().status == "applied_awaiting_publication",
		"Authenticated material execution remains distinct from presentation")
	_expect(observed.native_totals.removed_cells == 50 and observed.native_totals.geometry_rebuilds == 1,
		"Native material and rebuild counters retain batching evidence")
	_expect(observed.recent.back().has("admission_to_receipt_usec"), "Causal admitted action has measured receipt latency")
	probe.record("presented", {"action_id": 14, "publication_sequence": 52})
	_expect(probe.snapshot().pending_count == 0
		and probe.snapshot().recent.back().status == "applied_publication_installed", "Publication fence completes observer state")
	probe.record("admitted", {"action_id": 15})
	probe.record("receipt", {"action_id": 15, "outcome": "StaleTarget", "removed_cells": 1000})
	_expect(probe.snapshot().pending_count == 0 and probe.snapshot().native_totals.removed_cells == 50,
		"Refused native receipt cannot fabricate mutation accounting")
	_expect(probe.snapshot().recent.back().status == "admitted_but_refused", "Native refusal differs from non-admission")
	probe.record("admitted", {"action_id": 16})
	probe.record("uncertain", {"action_id": 16, "reason": "MalformedReceipt"})
	_expect(probe.snapshot().pending[16].status == "completion_uncertain", "Uncertain delivery stays explicitly unresolved")
	probe.record("admitted", {"action_id": 17})
	probe.record("receipt", {"action_id": 17, "outcome": "Applied"})
	probe.record("admitted", {"action_id": 18})
	probe.record("receipt", {"action_id": 18, "outcome": "Applied"})
	probe.record("admitted", {"action_id": 19})
	_expect(probe.applied_pending_ids() == [17,18],
		"Coalesced publication covers all preceding applied receipts but not uncertain or unexecuted admissions")
	for action_id: int in probe.applied_pending_ids():
		probe.record("presented", {"action_id": action_id, "publication_sequence": 60})
	_expect(probe.applied_pending_ids().is_empty() and probe.snapshot().pending.has(16)
		and probe.snapshot().pending.has(19), "Publishing the applied subset cannot resolve unknown completion")
	probe.record("uncertain", {"reason": "UnidentifiableTransportReceipt"})
	_expect(probe.snapshot().pending[16].status == "completion_uncertain"
		and probe.snapshot().pending[19].status == "completion_uncertain",
		"Transport-wide uncertainty retains and labels every outstanding observational action")
	var sequence: int = probe.snapshot().sequence
	_expect(not probe.record("receipt", {"world_generation": 8, "action_id": 16, "outcome": "Applied"}),
		"Foreign scene observations cannot enter current session")
	_expect(probe.snapshot().sequence == sequence and probe.snapshot().foreign_events_ignored == 1,
		"Foreign observations are counted separately without a current-session receipt")
	probe.record("partial", {"completed_owners": 1, "remaining_owners": 2, "reason": "Capacity"})
	_expect(not probe.snapshot().cross_owner_atomic, "Diagnostic export never promises cross-owner atomicity")
	var private_payload: Dictionary = {"tool": "slice", "targets": range(10000),
		"native_receipt": {"huge": range(10000)}, "reason": "x".repeat(1000)}
	probe.record("attempt", private_payload)
	var detail: Dictionary = probe.snapshot().recent.back().detail
	_expect(not detail.has("targets") and not detail.has("native_receipt")
		and detail.reason.length() == Probe.MAX_TEXT, "Large native payloads and text cannot grow the observer")
	var detached: Dictionary = probe.snapshot()
	detached.recent.clear()
	detached.counts.clear()
	_expect(not probe.snapshot().recent.is_empty() and not probe.snapshot().counts.is_empty(),
		"Exported copies cannot mutate diagnostic history")
	for index: int in range(600):
		probe.record("attempt", {"position": Vector2i(index, 0)})
	_expect(probe.snapshot().recent.size() == Probe.MAX_EVENTS and probe.snapshot().events_dropped > 0,
		"Recent history remains bounded while cumulative attempt counts survive")
	for index: int in range(100):
		probe.record("admitted", {"action_id": 100 + index})
	_expect(probe.snapshot().pending_count == Probe.MAX_PENDING and probe.snapshot().pending_capacity_drops > 0,
		"Even a missing-receipt sequence cannot grow observer pending storage")
	probe.record("retired", {"reason": "SceneReplaced"})
	_expect(probe.snapshot().retired and probe.snapshot().pending_count == 0
		and not probe.record("receipt", {"action_id": 16, "outcome": "Applied"}),
		"Retired session rejects late observational completions")
	var old_epoch: int = probe.snapshot().epoch
	probe.reset({"world_generation": 8, "session": 4})
	observed = probe.snapshot()
	_expect(observed.epoch == old_epoch + 1 and observed.recent.is_empty()
		and observed.counts.is_empty() and observed.native_totals.is_empty()
		and observed.identity.world_generation == 8, "Scene replacement starts a separate diagnostic identity")
	print(JSON.stringify({"schema": "objectshard-live-edit-diagnostics-test-v1", "checks": checks,
		"failures": failures, "scope": "bounded observational bookkeeping; no native or physical execution claim"}))
	quit(0 if failures == 0 else 1)
