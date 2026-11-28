extends RefCounted

## Default-off presentation scheduling only. The retained object is the
## worker's immutable cumulative material publication, never a native delta.
## No World, renderer, Rapier, callback or upload acknowledgement lives here.

var _hz: int = 0
var _interval_usec: int = 0
var _identity: Array = []
var _pending: RefCounted
var _deadline_usec: int = -1
var _next_upload_usec: int = -1
var _taken_serial: int = -1
var _taken_generation: int = -1
var _offers: int = 0
var _replacements: int = 0
var _consumptions: int = 0
var _accepted_uploads: int = 0
var _cancellations: int = 0
var _last_cancel: String = ""
var _last_offer_result: String = ""


static func requested_hz(value: String) -> int:
	return int(value) if value in ["30", "60"] else 0


func configure(hz: int) -> bool:
	if hz not in [0, 30, 60]:
		return false
	cancel("configuration")
	_hz = hz
	_interval_usec = ceili(1000000.0 / float(hz)) if hz > 0 else 0
	return true


func enabled() -> bool:
	return _hz > 0


func cancel(reason: String) -> void:
	if _pending != null or _taken_serial >= 0:
		_cancellations += 1
	_pending = null
	_identity.clear()
	_deadline_usec = -1
	_next_upload_usec = -1
	_taken_serial = -1
	_taken_generation = -1
	_last_cancel = reason


func offer(packet: RefCounted, identity: Array, now_usec: int,
		uploaded_generation: int, uploaded_serial: int) -> bool:
	if not enabled() or packet == null:
		_last_offer_result = "disabled_or_missing"
		return false
	if now_usec <= 0 or identity.size() != 3 or packet.simulation_failed:
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
		cancel("identity_changed")
		_identity = identity.duplicate()
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
		# Keep the first offer's deadline. Replacing a packet cannot postpone
		# presentation forever while new native samples continue arriving.
	else:
		_deadline_usec = now_usec if new_world or _next_upload_usec < 0 \
			else maxi(now_usec, _next_upload_usec)
	_pending = packet
	_last_offer_result = "offered"
	return true


func take_due(identity: Array, now_usec: int) -> RefCounted:
	if not enabled() or _pending == null:
		return null
	if identity != _identity:
		cancel("identity_retired")
		return null
	if now_usec < _deadline_usec:
		return null
	var result: RefCounted = _pending
	_pending = null
	_deadline_usec = -1
	_taken_serial = result.render_snapshot_serial
	_taken_generation = result.render_world_generation
	_consumptions += 1
	return result


func complete(packet: RefCounted, accepted: bool, now_usec: int) -> bool:
	if packet == null or int(packet.render_snapshot_serial) != _taken_serial \
			or int(packet.render_world_generation) != _taken_generation:
		return false
	_taken_serial = -1
	_taken_generation = -1
	if not accepted or now_usec <= 0:
		cancel("upload_refused")
		return false
	_accepted_uploads += 1
	_next_upload_usec = now_usec + _interval_usec
	return true


func status() -> Dictionary:
	return {"schema":"pubpres-material-deadline-v1", "requested_hz":_hz,
		"enabled":enabled(), "interval_usec":_interval_usec,
		"pending_count":int(_pending != null),
		"pending_serial":int(_pending.render_snapshot_serial) if _pending != null else -1,
		"pending_generation":int(_pending.render_world_generation) if _pending != null else -1,
		"deadline_usec":_deadline_usec, "next_upload_usec":_next_upload_usec,
		"offers":_offers, "replaced_offers":_replacements, "consumptions":_consumptions,
		"accepted_uploads":_accepted_uploads, "cancellations":_cancellations,
		"last_cancel":_last_cancel, "last_offer_result":_last_offer_result,
		"physical_credit":false}
