extends RefCounted

## Default-off material admission experiment. This object retains at most one
## immutable cumulative worker publication. It observes completed steps; it
## cannot run physics, mutate an Image, read a World, or acknowledge a packet.
## The clock is a scheduled hold deadline, not a wall/display latency promise.
const ADDED_HOLD_USEC: int = 16667
const SOURCE_AGE_GUARD_USEC: int = 1000000

var _requested: int = 0
var _interval: int = 0
var _disabled_reason: String = ""
var _identity: Array = []
var _pending: RefCounted
var _first_offer_usec: int = -1
var _deadline_usec: int = -1
var _immediate_reason: String = ""
var _anchor_step: int = -1
var _anchor_manual: int = -1
var _anchor_uploaded_serial: int = -1
var _anchor_uploaded_usec: int = -1
var _taken_serial: int = -1
var _taken_generation: int = -1
var _taken_step: int = -1
var _taken_manual: int = -1
var _taken_paint_generation: int = -1
var _paint_force: bool = false
var _paint_busy: bool = false
var _paint_idle_usec: int = -1
var _paint_generation: int = 0
var _edit_requests: int = 0
var _offers: int = 0
var _replacements: int = 0
var _deferred_turns: int = 0
var _consumptions: int = 0
var _accepted_uploads: int = 0
var _cancellations: int = 0
var _last_cancel: String = ""
var _last_offer_result: String = ""
var _last_consumption_reason: String = ""
var _last_hold_usec: int = 0
var _last_deadline_overrun_usec: int = 0
var _maximum_deadline_overrun_usec: int = 0
var _last_source_age_usec: int = -1
var _last_count_due: bool = false
var _last_deadline_due: bool = false


static func requested_interval(value: String) -> int:
	return 2 if value == "2" else 0


func configure(interval: int, disabled_reason: String = "") -> bool:
	if interval not in [0, 2]:
		return false
	cancel("configuration")
	_requested = interval
	_disabled_reason = disabled_reason if interval > 0 else ""
	_interval = interval if _disabled_reason.is_empty() else 0
	return true


func enabled() -> bool:
	return _interval > 0


func cancel(reason: String) -> void:
	if _pending != null or _taken_serial >= 0:
		_cancellations += 1
	_pending = null
	_identity.clear()
	_first_offer_usec = -1
	_deadline_usec = -1
	_immediate_reason = ""
	_anchor_step = -1
	_anchor_manual = -1
	_anchor_uploaded_serial = -1
	_anchor_uploaded_usec = -1
	_taken_serial = -1
	_taken_generation = -1
	_taken_step = -1
	_taken_manual = -1
	_taken_paint_generation = -1
	_paint_force = false
	_paint_busy = false
	_paint_idle_usec = -1
	_last_cancel = reason


func mark_edit_admitted() -> void:
	if not enabled():
		return
	# A new brush, including soft Sand, retires an older idle observation.
	# Command admission is never reported as material completion or an ACK.
	_edit_requests += 1
	_paint_generation += 1
	_paint_force = true
	_paint_idle_usec = -1


func observe_paint_busy(busy: bool, now_usec: int) -> void:
	if not enabled() or now_usec <= 0:
		return
	if busy:
		if not _paint_busy or not _paint_force or _paint_idle_usec >= 0:
			_paint_generation += 1
		_paint_force = true
		_paint_idle_usec = -1
	elif _paint_force and _paint_idle_usec < 0:
		_paint_idle_usec = now_usec
	_paint_busy = busy


func offer(packet: RefCounted, identity: Array, now_usec: int,
		uploaded_generation: int, uploaded_serial: int) -> bool:
	if not enabled() or packet == null:
		_last_offer_result = "disabled_or_missing"
		return false
	if now_usec <= 0 or identity.size() != 4 or packet.simulation_failed:
		cancel("invalid_offer")
		_last_offer_result = "invalid_offer"
		return false
	var generation: int = packet.render_world_generation
	var serial: int = packet.render_snapshot_serial
	if generation < 0 or serial <= 0 or generation != int(identity[2]):
		cancel("world_mismatch")
		_last_offer_result = "world_mismatch"
		return false
	if identity != _identity:
		if not _identity.is_empty():
			cancel("identity_changed")
		_identity = identity.duplicate()
	if _taken_serial >= 0:
		_last_offer_result = "upload_in_progress"
		return false
	if serial <= uploaded_serial:
		_last_offer_result = "already_uploaded"
		return false
	var new_world: bool = generation != uploaded_generation
	if new_world and not packet.render_full_refresh:
		cancel("new_world_requires_full")
		_last_offer_result = "new_world_requires_full"
		return false
	if _pending != null and serial <= int(_pending.render_snapshot_serial):
		_last_offer_result = "superseded"
		return false
	_offers += 1
	if _pending != null:
		_replacements += 1
	else:
		_first_offer_usec = now_usec
		_deadline_usec = now_usec + ADDED_HOLD_USEC
		_immediate_reason = "initial_or_new_world" if new_world or _anchor_step < 0 else ""
	# Replacement cannot renew either the first-offer deadline or an older
	# source-age guard. Unknown/future clocks get no artificial fresh budget.
	var generated: int = packet.render_generated_usec
	var source_deadline: int = generated + SOURCE_AGE_GUARD_USEC \
		if generated > 0 and generated <= now_usec else now_usec
	_deadline_usec = mini(_deadline_usec, source_deadline)
	_pending = packet
	_last_offer_result = "offered"
	return true


func _valid_witness(witness: Dictionary, now_usec: int) -> bool:
	for key: String in ["session_step", "rapier_step", "completed_usec"]:
		if not witness.get(key) is int:
			return false
	var step: int = int(witness.get("session_step", -1))
	var manual: int = int(witness.get("rapier_step", -1))
	var completed: int = int(witness.get("completed_usec", -1))
	if step <= 0 or manual <= 0 or completed <= 0 or completed > now_usec:
		return false
	if _anchor_step >= 0:
		# A reused bridge can have a fixed counter offset. Both counters must
		# advance equally within this exact session/epoch/World/bridge identity.
		return step >= _anchor_step and manual >= _anchor_manual \
			and step - _anchor_step == manual - _anchor_manual
	return true


func take_due(identity: Array, witness: Dictionary, now_usec: int,
		force_reason: String = "") -> RefCounted:
	if not enabled() or _pending == null:
		return null
	if identity != _identity:
		cancel("identity_retired")
		return null
	if now_usec <= 0 or now_usec < _first_offer_usec:
		return null
	var witnessed: bool = _valid_witness(witness, now_usec)
	var reason: String = force_reason
	if reason.is_empty() and _paint_force:
		reason = "paint_pending"
	if reason.is_empty() and not witnessed:
		reason = "no_compatible_completed_step"
	if reason.is_empty():
		reason = _immediate_reason
	if reason.is_empty() and _anchor_step >= 0 \
			and int(witness.session_step) - _anchor_step >= _interval:
		reason = "completed_step_interval"
	if reason.is_empty() and now_usec >= _deadline_usec:
		reason = "scheduled_hold_deadline"
	if reason.is_empty():
		_deferred_turns += 1
		return null
	var result: RefCounted = _pending
	_pending = null
	_taken_serial = result.render_snapshot_serial
	_taken_generation = result.render_world_generation
	_taken_step = int(witness.session_step) if witnessed else -1
	_taken_manual = int(witness.rapier_step) if witnessed else -1
	_taken_paint_generation = _paint_generation
	_consumptions += 1
	_last_consumption_reason = reason
	_last_count_due = witnessed and _anchor_step >= 0 \
		and int(witness.session_step) - _anchor_step >= _interval
	_last_deadline_due = now_usec >= _deadline_usec
	_last_hold_usec = now_usec - _first_offer_usec
	_last_deadline_overrun_usec = maxi(0, now_usec - _deadline_usec)
	_maximum_deadline_overrun_usec = maxi(_maximum_deadline_overrun_usec, _last_deadline_overrun_usec)
	var generated: int = result.render_generated_usec
	_last_source_age_usec = now_usec - generated if generated > 0 and generated <= now_usec else -1
	_first_offer_usec = -1
	_deadline_usec = -1
	_immediate_reason = ""
	return result


func complete(packet: RefCounted, accepted: bool, witness: Dictionary, now_usec: int) -> bool:
	if packet == null or int(packet.render_snapshot_serial) != _taken_serial \
			or int(packet.render_world_generation) != _taken_generation:
		return false
	var witnessed: bool = _valid_witness(witness, now_usec) \
		and int(witness.get("session_step", -1)) == _taken_step \
		and int(witness.get("rapier_step", -1)) == _taken_manual
	_taken_serial = -1
	_taken_generation = -1
	_taken_step = -1
	_taken_manual = -1
	if not accepted or now_usec <= 0:
		cancel("upload_refused")
		return false
	_accepted_uploads += 1
	_anchor_step = int(witness.session_step) if witnessed else -1
	_anchor_manual = int(witness.rapier_step) if witnessed else -1
	_anchor_uploaded_serial = packet.render_snapshot_serial
	_anchor_uploaded_usec = now_usec
	if _paint_force and not _paint_busy and _paint_idle_usec > 0 \
			and _taken_paint_generation == _paint_generation \
			and int(packet.render_generated_usec) >= _paint_idle_usec \
			and int(packet.render_generated_usec) <= now_usec:
		_paint_force = false
		_paint_idle_usec = -1
	_taken_paint_generation = -1
	return true


func status() -> Dictionary:
	return {"schema":"pubpres-material-steps-v1", "requested_interval":_requested,
		"effective_interval":_interval, "enabled":enabled(), "disabled_reason":_disabled_reason,
		"scheduled_added_hold_usec":ADDED_HOLD_USEC, "source_age_guard_usec":SOURCE_AGE_GUARD_USEC,
		"pending_count":int(_pending != null),
		"pending_serial":int(_pending.render_snapshot_serial) if _pending != null else -1,
		"pending_generation":int(_pending.render_world_generation) if _pending != null else -1,
		"pending_generated_usec":int(_pending.render_generated_usec) if _pending != null else -1,
		"first_offer_usec":_first_offer_usec, "deadline_usec":_deadline_usec,
		"identity":_identity.duplicate(), "anchor_session_step":_anchor_step,
		"anchor_rapier_step":_anchor_manual, "anchor_uploaded_serial":_anchor_uploaded_serial,
		"anchor_uploaded_usec":_anchor_uploaded_usec,
		"paint_force":_paint_force, "paint_busy":_paint_busy, "paint_idle_usec":_paint_idle_usec,
		"paint_generation":_paint_generation, "edit_requests":_edit_requests,
		"offers":_offers, "replaced_offers":_replacements, "deferred_turns":_deferred_turns,
		"consumptions":_consumptions, "accepted_uploads":_accepted_uploads,
		"accepted_upload_scope":"selected transactions whose policy identity survives upload; Main separately counts accepted transactions cancelled by texture recreation",
		"cancellations":_cancellations, "last_cancel":_last_cancel,
		"last_offer_result":_last_offer_result, "last_consumption_reason":_last_consumption_reason,
		"last_hold_usec":_last_hold_usec, "last_deadline_overrun_usec":_last_deadline_overrun_usec,
		"maximum_deadline_overrun_usec":_maximum_deadline_overrun_usec,
		"last_source_age_usec":_last_source_age_usec,
		"last_count_due":_last_count_due, "last_deadline_due":_last_deadline_due,
		"physical_credit":false}
