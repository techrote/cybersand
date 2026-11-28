extends RefCounted

## Bounded observation memory for material persistence applicability. This never
## changes gameplay. A replacement owner's tick zero does not erase earlier simulation exposure.
## Assertions and the external reader independently reconstruct applicability.
const SCHEMA := "cybersand-goblin-material-lineage-v1"
const FRESH := ["reset_fixture", "replace_fixture", "restore_start", "reopen_layout"]
const RETAINING := ["actor_place", "actor_reset", "actor_remove", "actor_move", "actor_replace",
	"actor_equipment", "response_mode", "actor_settings"]
var _state := "unknown"
var _source: Dictionary = {}
var _witness: Dictionary = {}


static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(value)


static func source_of(native: Dictionary) -> Dictionary:
	return {"generation": native.get("generation", -1), "revision": native.get("revision", -1),
		"tick": native.get("tick", -1)}


static func valid_native(native: Dictionary) -> bool:
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(native.get(key)) or native[key] < 0: return false
	return native.get("failed") == false


static func construction_receipt(receipt: Dictionary, native: Dictionary) -> bool:
	if not valid_native(native) or receipt.get("kind") != "applied_run" \
		or not _integer(receipt.get("schema_version")) or receipt.schema_version != 1 \
		or not _integer(receipt.get("session_generation")) or receipt.session_generation != native.generation \
		or not _integer(receipt.get("completed_tick")) or receipt.completed_tick != 0: return false
	var bytes: Variant = receipt.get("canonical_bytes")
	if not bytes is Array or bytes.size() < 52 or bytes.size() > 1048576: return false
	for value: Variant in bytes:
		if not _integer(value) or value < 0 or value > 255: return false
	# Native build_applied_run_receipt writes a little-endian u32 text length,
	# the24-byte domain, u16 schema, two u8 modes, u32 qualifications, u64
	# committed generation, then u64 completed tick0. Bind the hashed header
	# itself; relabelling an old receipt's outer generation is insufficient.
	var domain := "cybersand-run-receipt-v1".to_utf8_buffer()
	if bytes[0] != domain.size() or bytes[1] != 0 or bytes[2] != 0 or bytes[3] != 0 \
		or bytes[28] != 1 or bytes[29] != 0: return false
	for index: int in range(domain.size()):
		if bytes[4 + index] != domain[index]: return false
	var generation := 0
	for index: int in range(8):
		generation |= int(bytes[36 + index]) << (8 * index)
		if bytes[44 + index] != 0: return false
	if generation != int(native.generation): return false
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(PackedByteArray(bytes))
	return digest.finish().hex_encode() == receipt.get("receipt_hash")


func _unknown(kind: String, native: Dictionary) -> void:
	_state = "unknown"
	_witness = {"kind": kind, "source": source_of(native)}


func observe(native: Dictionary, paused: bool) -> Dictionary:
	if not valid_native(native):
		_unknown("invalid_source", native)
	elif int(native.tick) > 0:
		# Latest actual positive observation, not an unrecorded first sample.
		# A row refreshes this to its own source; retaining tick0 keeps it.
		_witness = {"kind": "native_progress", "source": source_of(native)}
		_state = "simulation_exposed"
	elif _source.is_empty() or _source.get("generation") != native.generation:
		_unknown("unobserved_generation", native)
	elif not paused or native.get("paused") != true:
		if _state != "simulation_exposed": _unknown("unobserved_running", native)
	elif native.tick < _source.get("tick", 0) or native.revision < _source.get("revision", 0):
		_unknown("nonmonotonic_source", native)
	_source = source_of(native)
	return {"schema": SCHEMA, "state": _state, "source": _source.duplicate(true), "witness": _witness.duplicate(true)}


func authored(native: Dictionary, receipt: Dictionary, action: String, paused: bool) -> bool:
	if not paused or native.get("paused") != true or native.get("tick") != 0 \
		or not construction_receipt(receipt, native):
		observe(native, paused)
		return false
	_state = "authored_compatible"
	_source = source_of(native)
	_witness = {"kind": "authored_construction", "action": action, "source": _source.duplicate(true),
		"receipt_hash": receipt.receipt_hash}
	return true


func finish(record: Dictionary, native: Dictionary, paused: bool) -> void:
	var before: Dictionary = record.get("before", {})
	var first: Dictionary = before.get("native", {})
	var prior: Dictionary = before.get("material_lineage", {})
	var id: String = str(record.get("action", {}).get("id", ""))
	var complete: bool = record.get("status") == "completed" and record.get("admission", {}).get("accepted") == true
	var replaced: bool = valid_native(first) and valid_native(native) and int(native.generation) > int(first.generation)
	var receipt: Dictionary = record.get("native_receipt", {})
	if replaced and complete and id in FRESH:
		if authored(native, receipt, id, paused): return
		_unknown("unacknowledged_replacement", native)
	elif replaced and complete and id in RETAINING and construction_receipt(receipt, native):
		if prior.get("schema") == SCHEMA and prior.get("source") == source_of(first) \
			and prior.get("state") in ["authored_compatible", "simulation_exposed", "unknown"]:
			if prior.state == "simulation_exposed":
				_state = "simulation_exposed"
				_witness = prior.get("witness", {}).duplicate(true)
			elif prior.state == "authored_compatible" and _state != "simulation_exposed" and paused \
				and before.get("paused") == true and first.get("paused") == true \
				and native.get("paused") == true and first.tick == 0 and native.tick == 0:
				_state = "authored_compatible"
				_witness = prior.get("witness", {}).duplicate(true)
			else:
				_unknown("unproven_retained_lineage", native)
			_source = source_of(native)
	elif replaced:
		# A failed/cancelled fresh construction cannot manufacture a completed
		# authored lifecycle acknowledgement, even if installation was observed.
		_unknown("unacknowledged_replacement", native)
	elif not complete and valid_native(first) and valid_native(native) and native.revision != first.revision:
		if _state != "simulation_exposed": _unknown("partial_native_effect", native)
	observe(native, paused)
