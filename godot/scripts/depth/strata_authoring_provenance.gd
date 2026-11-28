extends RefCounted

## Strict bounded historical records. These metadata never authorize a write,
## resume a queue, or attest that a reopened native World is still the source.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const MAX_RECORDS := 64
const MAX_BYTES := 256 * 1024
const RECORD_KEYS := ["version", "id", "kind", "plane", "scene_id", "owner_id", "generation", "before_revision", "after_revision", "status", "requested_cells", "applied_cells", "changed_cells", "requested_chunks", "completed_chunks", "source_sha256", "proposal_sha256", "geometry_sha256", "before_sha256", "projected_sha256", "actual_sha256", "published", "metadata", "error", "historical", "scope"]
const STATUSES := ["completed", "partial", "cancelled", "refused", "failed", "committed_stale_pixels"]


static func defaults() -> Dictionary:
	return {"version": 1, "records": []}


static func default_configuration() -> Dictionary:
	return defaults()


static func canonical(value: Variant) -> Dictionary:
	if not validate(value).is_empty(): return {}
	return Module.canonical(value)


static func _text(value: Variant, maximum: int, allow_empty: bool = false) -> bool:
	return value is String and value.length() <= maximum and (allow_empty or not value.strip_edges().is_empty())


static func validate_record(record: Variant) -> String:
	if not Module.keys(record, RECORD_KEYS) or not Module.integer(record.version, 1, 1): return "Unsupported Strata authoring record fields or version."
	if not Module.identifier(record.id) or not record.kind is String or record.kind not in ["raster_import", "native_module", "construction", "harvest"] or not record.plane is String or record.plane not in ["play", "scripted", "effects", "background"]: return "Invalid historical operation identity, kind or plane."
	if not _text(record.scene_id, 128) or not _text(record.owner_id, 256) or not Module.integer(record.generation, 0, 2147483647): return "Invalid historical scene or owner identity."
	if not Module.integer(record.before_revision, 0, 2147483647) or not Module.integer(record.after_revision, int(record.before_revision), 2147483647): return "Invalid historical authored revision interval."
	if not record.status is String or record.status not in STATUSES or not record.published is bool or not record.historical is bool or record.historical != true or not record.scope is String or record.scope != "authored-material-operation-history": return "Authoring records must be explicit historical terminal outcomes."
	if not Module.integer(record.requested_cells, 0, 262144) or not Module.integer(record.applied_cells, 0, int(record.requested_cells)) or not Module.integer(record.changed_cells, 0, int(record.applied_cells)): return "Invalid native applied-prefix counts."
	if not Module.integer(record.requested_chunks, 0, 64) or not Module.integer(record.completed_chunks, 0, int(record.requested_chunks)): return "Invalid bounded chunk outcome."
	for key: String in ["source_sha256", "proposal_sha256", "geometry_sha256", "before_sha256", "projected_sha256", "actual_sha256"]:
		if not record[key] is String or (record[key] != "" and not Module.hex_digest(record[key])): return "Invalid historical source, proposal or native material hash."
	if not Module.hex_digest(record.proposal_sha256) or not Module.hex_digest(record.geometry_sha256): return "Historical records require exact proposal and geometry identities."
	if record.status in ["completed", "committed_stale_pixels"]:
		if int(record.applied_cells) != int(record.requested_cells) or int(record.completed_chunks) != int(record.requested_chunks) or not Module.hex_digest(record.actual_sha256) or record.actual_sha256 != record.projected_sha256: return "A completed operation needs the complete acknowledged prefix and agreeing final native readback."
		if record.status == "completed" and not record.published: return "A completed displayed record must have a valid publication."
		if record.status == "committed_stale_pixels" and record.published: return "Stale-pixel records cannot claim current display admission."
	if record.status in ["refused", "cancelled"] and int(record.applied_cells) > 0: return "A cancelled/refused suffix with native writes is an explicit partial outcome."
	if not record.metadata is Dictionary or not Module.safe_json(record.metadata) or Module.json_bytes(record.metadata).size() > 8192: return "Historical source/mapping metadata exceeds its bounded JSON contract."
	if not _text(record.error, 2048, true): return "Invalid historical outcome explanation."
	return ""


static func validate(value: Variant) -> String:
	if not Module.keys(value, ["version", "records"]) or not Module.integer(value.version, 1, 1) or not value.records is Array or value.records.size() > MAX_RECORDS: return "Unsupported Strata authoring metadata or 64-record capacity exceeded."
	var seen: Dictionary = {}
	for record: Variant in value.records:
		var error := validate_record(record)
		if not error.is_empty(): return error
		if seen.has(record.id): return "Repeated historical authoring record identity."
		seen[record.id] = true
	if Module.json_bytes(value).size() > MAX_BYTES: return "Strata authoring metadata exceeds 256 KiB."
	return ""


static func append(value: Dictionary, record: Dictionary) -> Dictionary:
	var error := validate(value)
	if not error.is_empty(): return Module.failure(error)
	error = validate_record(record)
	if not error.is_empty(): return Module.failure(error)
	var result := value.duplicate(true)
	var replaced := false
	for i: int in result.records.size():
		if result.records[i].id == record.id:
			result.records[i] = record.duplicate(true)
			replaced = true
			break
	if not replaced:
		if result.records.size() >= MAX_RECORDS: return Module.failure("Authoring provenance is full; existing records are never silently evicted.")
		result.records.append(record.duplicate(true))
	error = validate(result)
	if not error.is_empty(): return Module.failure(error)
	return {"ok": true, "authoring": result, "error": ""}
