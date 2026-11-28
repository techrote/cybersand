class_name CyberObjectShardLiveEditDiagnostics
extends RefCounted

# This observer never admits, cancels or acknowledges material work. Its small
# always-on window explains missing input even when performance recording is off.
# A receipt proves native execution; only the caller's publication fence may
# record `presented`. Neither event proves a physical monitor presentation.
const SCHEMA: String = "objectshard-live-edit-diagnostics-v1"
const MAX_EVENTS: int = 256
const MAX_PENDING: int = 32
const MAX_TEXT: int = 160
const MAX_DETAIL_FIELDS: int = 40
const KINDS: Array[String] = [
	"attempt", "wait", "refused", "admitted", "receipt", "presented",
	"cancel", "no_eligible", "uncertain", "partial", "retired",
]
const IDENTITY_KEYS: Array[String] = [
	"session", "world_generation", "world_incarnation", "owner_epoch",
	"shard_session", "transport_generation", "port_generation",
]
const NUMERIC_TOTALS: Array[String] = [
	"requested_cells", "unique_cells", "eligible_cells", "changed_cells",
	"removed_cells", "ignited_cells", "changed_owners", "geometry_rebuilds",
	"connectivity_passes", "fragments_created", "fragmentation_refusals",
]

var epoch: int = 0
var _identity: Dictionary = {}
var _events: Array[Dictionary] = []
var _counts: Dictionary = {}
var _totals: Dictionary = {}
var _pending: Dictionary = {}
var _sequence: int = 0
var _dropped_events: int = 0
var _foreign_events: int = 0
var _pending_overflow: int = 0
var _coalesced_waits: int = 0
var _retired: bool = false


func reset(identity: Dictionary = {}) -> void:
	epoch += 1
	_identity.clear()
	for key: String in IDENTITY_KEYS:
		if identity.get(key) is int:
			_identity[key] = identity[key]
	_events.clear()
	_counts.clear()
	_totals.clear()
	_pending.clear()
	_sequence = 0
	_dropped_events = 0
	_foreign_events = 0
	_pending_overflow = 0
	_coalesced_waits = 0
	_retired = false


func _copy_detail(details: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	# Bound both storage and traversal. Never duplicate a footprint, publication,
	# native owner object or nested source-target array into diagnostic history.
	var inspected: int = 0
	for raw_key: Variant in details:
		inspected += 1
		if inspected > MAX_DETAIL_FIELDS:
			break
		if not raw_key is String or raw_key.length() > 64:
			continue
		var value: Variant = details[raw_key]
		if value is int or value is bool:
			result[raw_key] = value
		elif value is float and is_finite(value):
			result[raw_key] = value
		elif value is String:
			result[raw_key] = value.left(MAX_TEXT)
		elif value is Vector2i:
			result[raw_key] = [value.x, value.y]
		elif value is Vector2 and value.is_finite():
			result[raw_key] = [value.x, value.y]
	return result


func _status(kind: String, details: Dictionary) -> String:
	match kind:
		"attempt": return "input_not_yet_admitted"
		"wait": return "input_waiting_for_admission"
		"admitted": return "admitted_awaiting_receipt"
		"no_eligible": return "no_eligible_visible_material"
		"cancel": return "future_admission_cancelled"
		"uncertain": return "completion_uncertain"
		"presented": return "applied_publication_installed"
		"partial": return "gesture_partially_completed"
		"refused": return "input_not_admitted"
		"receipt":
			return "applied_awaiting_publication" if details.get("outcome") == "Applied" else "admitted_but_refused"
	return "session_retired"


func record(kind: String, details: Dictionary = {}) -> bool:
	if kind not in KINDS or _retired:
		return false
	for key: String in IDENTITY_KEYS:
		if details.has(key) and _identity.has(key) and details[key] != _identity[key]:
			_foreign_events += 1
			return false
	var clean: Dictionary = _copy_detail(details)
	var now_usec: int = Time.get_ticks_usec()
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	_sequence += 1
	var status: String = _status(kind, clean)
	var event: Dictionary = {"sequence": _sequence, "epoch": epoch,
		"kind": kind, "status": status, "time_usec": now_usec, "detail": clean}
	var action_id: int = int(clean.get("action_id", 0))
	if kind == "admitted" and action_id > 0:
		if clean.get("captured_usec") is int and int(clean.captured_usec) >= 0 \
				and int(clean.captured_usec) <= now_usec:
			event["input_to_admission_usec"] = now_usec - int(clean.captured_usec)
		if _pending.has(action_id):
			# Duplicate observational admission cannot reset measured latency.
			event["duplicate_admission"] = true
		elif _pending.size() < MAX_PENDING:
			_pending[action_id] = {"admitted_usec": now_usec, "status": status}
		else:
			_pending_overflow += 1
	elif kind == "receipt":
		if _pending.has(action_id):
			var pending: Dictionary = _pending[action_id]
			event["admission_to_receipt_usec"] = maxi(0, now_usec - int(pending.admitted_usec))
			pending["status"] = status
			if clean.get("outcome") != "Applied":
				_pending.erase(action_id)
		if clean.get("outcome") == "Applied":
			for key: String in NUMERIC_TOTALS:
				if clean.get(key) is int and int(clean[key]) >= 0:
					_totals[key] = int(_totals.get(key, 0)) + int(clean[key])
	elif kind == "presented" and _pending.has(action_id):
		event["admission_to_publication_usec"] = maxi(0, now_usec - int(_pending[action_id].admitted_usec))
		_pending.erase(action_id)
	elif kind == "uncertain":
		if _pending.has(action_id):
			_pending[action_id]["status"] = status
		elif action_id == 0:
			# A held transport with an unidentifiable/lost receipt cannot prove
			# completion of any outstanding request. Keep the bounded set open.
			for pending_id: int in _pending:
				_pending[pending_id]["status"] = status
	elif kind == "retired":
		_retired = true
		_pending.clear()
	# A held pointer can retry every callback. Preserve its first and latest
	# wait clocks and count repetitions without crowding useful receipt history.
	if kind == "wait" and not _events.is_empty():
		var previous: Dictionary = _events.back()
		if previous.kind == "wait" and previous.detail == clean:
			previous["last_time_usec"] = now_usec
			previous["repetitions"] = int(previous.get("repetitions", 1)) + 1
			_coalesced_waits += 1
			return true
	if _events.size() >= MAX_EVENTS:
		_events.pop_front()
		_dropped_events += 1
	_events.append(event)
	return true


func applied_pending_ids() -> Array[int]:
	# The authenticated greatest-edit publication fence also covers preceding
	# applied edits in this session. Return only that small pending subset, so
	# a newer receipt cannot strand an older observer behind results.back().
	var ids: Array[int] = []
	for action_id: int in _pending:
		if _pending[action_id].status == "applied_awaiting_publication":
			ids.append(action_id)
	ids.sort()
	return ids


func snapshot() -> Dictionary:
	return {"schema": SCHEMA, "epoch": epoch, "identity": _identity.duplicate(),
		"retired": _retired, "counts": _counts.duplicate(), "native_totals": _totals.duplicate(),
		"recent": _events.duplicate(true), "pending": _pending.duplicate(true),
		"pending_count": _pending.size(), "max_pending": MAX_PENDING,
		"max_events": MAX_EVENTS, "events_dropped": _dropped_events,
		"foreign_events_ignored": _foreign_events, "pending_capacity_drops": _pending_overflow,
		"coalesced_waits": _coalesced_waits, "sequence": _sequence,
		"scope": "bounded current-session input and authenticated execution observations; no live-state checkpoint or hardware presentation proof",
		"cross_owner_atomic": false,
		"timing_scope": "monotonic Main observations; native timing fields remain separately labelled and must not be summed with enclosing spans"}
