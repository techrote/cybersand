extends RefCounted
## WB-AGENT-002 (#527): bounded main-thread driver over the EXISTING shared
## workbench's acknowledged single-step path. This does not own a native World,
## add a physics scheduler, or replace #526's authoring/proposal dispatcher.
##
## Kept in a separate file until #526 hands off its tested worker interface.
## An ACK means the existing native workbench_step_serial was published with
## precisely one new completed World tick, not merely UI queue admission.

signal step_completed(receipt: Dictionary)
signal finished(receipt: Dictionary)

const MAX_STEP_TICKS: int = 120
const DEFAULT_ACK_TIMEOUT_MS: int = 20000

var _active: bool = false
var _stop_requested: bool = false
var _uncertain: bool = false
var _run_epoch: int = 0
var _host: Control
var _workbench: Control
var _last_result: Dictionary = {}


func active() -> bool:
	return _active


func last_result() -> Dictionary:
	return _last_result.duplicate(true)


func request_stop() -> void:
	# Never clear step_requested/step_pending: an already admitted tick must
	# reach its existing native/physical owner boundary before Stop can ACK.
	_stop_requested = true


func retire() -> void:
	# Scene/session exit: fence this driver's continuation. No delayed callback
	# is permitted to submit another step; unresolved in-flight work is not ACKed.
	_stop_requested = true
	_run_epoch += 1
	if _active:
		_uncertain = true


func _snapshot() -> CyberSimulationSnapshot:
	if not is_instance_valid(_host):
		return null
	return _host.latest_snapshot


func _manual_revision() -> int:
	if not is_instance_valid(_host) or _host.simulation_worker == null:
		return -1
	if _host.simulation_worker.has_method("agent_manual_intent_revision"):
		return int(_host.simulation_worker.agent_manual_intent_revision())
	return -1 # #526 revision fencing is not part of the accepted base yet.


func _invalid_owner() -> String:
	if not is_instance_valid(_host) or not is_instance_valid(_workbench):
		return "owner_destroyed"
	if _host.shared_workbench != _workbench:
		return "workbench_owner_changed"
	if _host.simulation_worker == null or _host.simulation_worker.has_failed():
		return "failed_native_owner"
	if not _host.pending_microscenario_apply.is_empty():
		return "owner_transition_pending"
	if not _host.paused or not _workbench.applied is Dictionary \
			or _workbench.applied.is_empty():
		return "not_acknowledged_paused_workbench"
	if not str(_host.tower_context.get("workbench_refusal","")).is_empty():
		return "workbench_refusal"
	return ""


func _record(status: String, reason: String, requested: int, completed: int,
		before_tick: int, after_tick: int, generation: int, serial: int) -> Dictionary:
	return {
		"status":status, "reason":reason, "requested":requested,
		"completed":completed, "before_tick":before_tick,
		"after_tick":after_tick, "world_generation":generation,
		"last_workbench_step_serial":serial,
		"still_paused":is_instance_valid(_host) and bool(_host.paused)
	}


func _end(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	_active = false
	finished.emit(_last_result.duplicate(true))
	return _last_result.duplicate(true)


func stop() -> Dictionary:
	# A pending single step is *not* cancelable by resetting UI flags. Wait
	# for the in-progress acknowledged boundary; timeout is UNCONFIRMED, not ACK.
	request_stop()
	if not _active:
		return {"status":"refused","reason":"no_active_step_sequence"}
	while _active:
		if not is_instance_valid(_host):
			return {"status":"unconfirmed","reason":"owner_destroyed_before_stop_ack"}
		await _host.get_tree().process_frame
	return _last_result.duplicate(true)


func step(host: Control, workbench: Control, requested: Variant,
		timeout_ms: int = DEFAULT_ACK_TIMEOUT_MS) -> Dictionary:
	if typeof(requested) != TYPE_INT or requested < 1 or requested > MAX_STEP_TICKS:
		return {"status":"refused","reason":"invalid_step_count",
			"requested":requested,"completed":0}
	if timeout_ms < 1 or timeout_ms > 120000:
		return {"status":"refused","reason":"invalid_step_timeout","completed":0}
	if _active:
		return {"status":"refused","reason":"step_sequence_busy","completed":0}
	if _uncertain:
		return {"status":"refused","reason":"prior_step_result_unconfirmed","completed":0}
	_host = host
	_workbench = workbench
	var invalid: String = _invalid_owner()
	if not invalid.is_empty():
		return {"status":"refused","reason":invalid,"completed":0}
	if _workbench.step_pending or _workbench.step_requested or _workbench.busy():
		return {"status":"refused","reason":"owner_step_or_edit_busy","completed":0}
	var initial: CyberSimulationSnapshot = _snapshot()
	if initial == null or not initial.paused or initial.simulation_failed \
			or initial.render_world_generation <= 0:
		return {"status":"refused","reason":"paused_native_publication_unavailable","completed":0}
	_active = true
	_stop_requested = false
	_run_epoch += 1
	var epoch: int = _run_epoch
	var generation: int = initial.render_world_generation
	var manual_revision: int = _manual_revision()
	var before_tick: int = initial.tick_index
	var observed_tick: int = before_tick
	var last_serial: int = int(_host.tower_context.get("workbench_step_serial",0))
	var completed: int = 0
	var reason: String = ""
	while completed < requested:
		if epoch != _run_epoch:
			reason = "lifecycle_retired_unconfirmed"
			_uncertain = true
			break
		if _stop_requested:
			reason = "human_stop"
			break
		invalid = _invalid_owner()
		if not invalid.is_empty():
			reason = invalid
			break
		if _workbench.step_pending or _workbench.step_requested or _workbench.busy():
			reason = "owner_step_or_edit_busy"
			break
		var current: CyberSimulationSnapshot = _snapshot()
		if current == null or current.render_world_generation != generation \
				or not current.paused or current.tick_index != observed_tick:
			reason = "native_identity_or_tick_changed"
			break
		if manual_revision >= 0 and _manual_revision() != manual_revision:
			reason = "manual_intent_changed"
			break
		if not _workbench.step_once():
			reason = "native_step_admission_refused"
			break
		var expected_serial: int = _workbench.step_serial
		var deadline: int = Time.get_ticks_msec() + timeout_ms
		var acknowledged: bool = false
		while Time.get_ticks_msec() < deadline:
			if not is_instance_valid(_host) or not is_instance_valid(_workbench):
				reason = "owner_destroyed_mid_step"
				break
			await _host.get_tree().process_frame
			current = _snapshot()
			if epoch != _run_epoch:
				reason = "lifecycle_retired_mid_step"
				break
			if current == null or current.simulation_failed \
					or current.render_world_generation != generation:
				reason = "native_world_failed_or_replaced"
				break
			# The existing single-step owner temporarily runs its *one*
			# native tick with a nonpaused worker publication. That is NOT
			# human Play: main.paused remains true. Refuse only an actual
			# host resume, and require paused again at the final ACK.
			if not _host.paused:
				reason = "human_play_during_step"
				break
			if not str(_host.tower_context.get("workbench_refusal","")).is_empty():
				reason = "workbench_refusal_mid_step"
				break
			if not _workbench.step_pending and int(_host.tower_context.get(
					"workbench_step_serial",-1)) == expected_serial:
				# Wait for the matching paused native publication, not a
				# transient between single-step execution and re-pause.
				if not current.paused:
					continue
				if current.tick_index != observed_tick + 1:
					reason = "native_tick_delta_not_exactly_one"
					break
				acknowledged = true
				break
		if not acknowledged:
			if reason.is_empty():
				reason = "native_step_ack_timeout"
			# Native may have executed the tick without publishing the matched
			# receipt. Never automatically retry an ambiguous command.
			_uncertain = true
			break
		last_serial = expected_serial
		observed_tick = current.tick_index
		completed += 1
		step_completed.emit({
			"completed":completed,"requested":requested,
			"before_tick":observed_tick-1,"after_tick":observed_tick,
			"world_generation":generation, "workbench_step_serial":last_serial
		})
	if reason.is_empty():
		reason = "requested_steps_completed"
	var status: String = "completed" if completed == requested else (
		"unconfirmed" if _uncertain else (
		"stopped" if reason == "human_stop" else "refused"))
	return _end(_record(status,reason,requested,completed,before_tick,
		observed_tick,generation,last_serial))
