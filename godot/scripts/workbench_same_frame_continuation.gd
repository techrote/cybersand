extends RefCounted

# One withheld, genuinely scheduled physics callback may finish at Main's
# process entry in the SAME engine frame. A permit is neither accumulated time
# nor a new callback. The next physics callback replaces it; every take spends
# it before polling. No loop, sleep, render synchronization or payload copy.
const VERSION: int = 1
const MAX_ACTORS: int = 8
const MAX_BODIES: int = 64
const OWNERS := ["owner", "bridge", "worker"]
const SCALARS := ["epoch", "session", "tick",
	"manual_steps", "sample", "bridge_sample", "installed_revision", "accepted_commands"]
const ARRAYS := ["sequences", "generations", "deadlines"]
var callback_serial: int = 0
var callback_frame: int = -1
var callback_physics_frame: int = -1
var callback_started_usec: int = 0
var attempted_frame: int = -1
var pending: Dictionary = {}


func begin_callback(frame: int, physics_frame: int, started_usec: int) -> void:
	callback_serial += 1
	callback_frame = frame
	callback_physics_frame = physics_frame
	callback_started_usec = started_usec
	pending = {}


func discard() -> void:
	pending = {}


static func valid_identity(value: Dictionary) -> bool:
	if value.size() != OWNERS.size() + SCALARS.size() + ARRAYS.size(): return false
	for key: String in OWNERS:
		if not value.get(key) is String or str(value[key]).length() > 20 \
			or not str(value[key]).is_valid_int() or str(int(value[key])) != value[key] or int(value[key]) == 0: return false
	for key: String in SCALARS:
		if not value.get(key) is int or int(value[key]) < 0: return false
	var count: int = -1
	for key: String in ARRAYS:
		var row: Variant = value.get(key)
		if not row is PackedInt64Array or row.is_empty() or row.size() > MAX_ACTORS: return false
		if count >= 0 and row.size() != count: return false
		count = row.size()
	return value.epoch > 0 and value.session > 0 and value.sample == value.bridge_sample


func arm(identity: Dictionary, world_generation: int, required_revision: int,
		delta: float, held_usec: int) -> bool:
	if callback_serial <= 0 or callback_frame < 0 or callback_frame == attempted_frame or callback_physics_frame < 0 \
		or callback_started_usec <= 0 or held_usec < callback_started_usec \
		or not valid_identity(identity) or world_generation <= 0 \
		or required_revision != int(identity.installed_revision) \
		or not is_finite(delta) or delta <= 0.0: return false
	pending = {"callback_serial":callback_serial,"process_frame":callback_frame,
		"physics_frame":callback_physics_frame,"callback_started_usec":callback_started_usec,
		"held_usec":held_usec,"delta":delta,"identity":identity.duplicate(true),
		"world_generation":world_generation,"required_revision":required_revision}
	return true


func take_ready(frame: int, identity: Dictionary, read_mailbox: Callable) -> Dictionary:
	var ticket: Dictionary = pending
	pending = {} # Consume before any return or callback. Failed attempts cannot retry.
	if ticket.is_empty(): return {"status":"empty","polls":0}
	var result: Dictionary = ticket.duplicate()
	result["polls"] = 0
	result["status"] = "frame_expired"
	if frame != int(ticket.process_frame) or callback_serial != int(ticket.callback_serial): return result
	result.status = "frame_spent"
	if attempted_frame == frame: return result
	attempted_frame = frame
	result.status = "owner_or_input_changed"
	if not valid_identity(identity) or identity != ticket.identity: return result
	result.polls = 1
	return validate_mailbox(result, ticket, identity, read_mailbox.call())


static func validate_mailbox(result: Dictionary, ticket: Dictionary, identity: Dictionary, mailbox: Dictionary) -> Dictionary:
	result.status = str(mailbox.get("status", "invalid"))
	if result.status != "active": return result
	result.status = "owner_changed"
	if mailbox.get("epoch") != identity.epoch or mailbox.get("session") != identity.session: return result
	var snapshot: CyberSimulationSnapshot = mailbox.get("snapshot")
	if snapshot == null: return result
	if snapshot.rigid_body_epoch != identity.epoch or snapshot.physics_world_generation != ticket.world_generation: return result
	result.status = "failed"
	if snapshot.simulation_failed: return result
	result.status = "native_refusal"
	if not str(snapshot.lab_context.get("workbench_refusal", "")).is_empty(): return result
	result.status = "native_sample"
	if snapshot.lab_context.get("workbench_completed_sample", -1) != identity.sample: return result
	result.status = "terrain_changed"
	if not snapshot.hard_surface_chunk_rectangles_valid \
		or snapshot.hard_surface_revision != ticket.required_revision \
		or snapshot.lab_context.get("workbench_hard_surface_revision", -1) != ticket.required_revision: return result
	result.status = "native_refusal"
	var packet: Dictionary = snapshot.lab_context.get("workbench_gcr", {})
	if packet.get("epoch") != identity.epoch or packet.get("session") != identity.session \
		or not packet.get("valid", false): return result
	var rows: Variant = packet.get("rows")
	if not rows is Array or rows.is_empty() or rows.size() > MAX_BODIES: return result
	for row: Variant in rows:
		if not row is Dictionary or row.get("sample") != identity.sample: return result
	# Full native response/wrench/history validation still belongs to the
	# existing Workbench bridge. This gate grants no alternate response receipt.
	result.status = "ready"
	result["snapshot"] = snapshot
	return result
