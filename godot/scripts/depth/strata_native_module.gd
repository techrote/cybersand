extends RefCounted

## Value-only Strata interchange. A module is proposed material geometry, never
## a World, a receipt of current authority, or a structural attachment solver.
## The narrow M3 adapter reads frozen #770 interchange, not its active planner.
const FORMAT := "cybersand-strata-module-v1"
const ARCHITECTURE_FORMAT := "cybersand-native-module-v1"
const ARCHITECTURE_SOURCE := "fe2395c7060dae736dc2e5dc8d1e4e050b2d2e52"
const MAX_SIDE := 2048
const ARCHITECTURE_MAX_SIDE := 512
const MAX_CELLS := 262144
const MAX_BYTES := 2 * 1024 * 1024
const MAX_METADATA_BYTES := 65536
const TRANSFORMS := ["identity", "mirror_x", "mirror_y", "rotate_90", "rotate_180", "rotate_270"]
const KEYS := ["format", "id", "name", "extent", "anchor", "geometry", "allowed_transforms", "roles", "clearances", "protected_regions", "provenance", "content_sha256"]
const ARCHITECTURE_KEYS := ["format", "id", "name", "tags", "part_type", "extent", "anchor", "geometry", "allowed_transforms", "attachments", "clearances", "protected_regions", "roles", "variation_regions", "provenance", "recipe", "design_card_ids", "content_sha256"]


static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "reason": message}


static func integer(value: Variant, low: int = -2147483647, high: int = 2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and float(value) >= low and float(value) <= high


static func keys(value: Variant, required: Array, optional: Array = []) -> bool:
	if not value is Dictionary or not value.has_all(required): return false
	for key: Variant in value:
		if not (key is String or key is StringName) or (str(key) not in required and str(key) not in optional): return false
	return true


static func identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for c: String in value:
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in ["-", "_"]): return false
	return true


static func hex_digest(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for c: String in value:
		if not ((c >= "a" and c <= "f") or (c >= "0" and c <= "9")): return false
	return true


static func pair(value: Variant, low: int = -2147483647, high: int = 2147483647) -> bool:
	return value is Array and value.size() == 2 and integer(value[0], low, high) and integer(value[1], low, high)


static func rectangle(value: Variant) -> Rect2i:
	if value is Rect2i: return value
	if not value is Array or value.size() != 4: return Rect2i()
	for n: Variant in value:
		if not integer(n): return Rect2i()
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))


static func rect_array(value: Rect2i) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()


static func canonical(value: Variant) -> Variant:
	if value is StringName: return str(value)
	if value is int and (value > 9007199254740991 or value < -9007199254740991): return "i64:" + str(value)
	if value is float and is_finite(value) and floor(value) == value and abs(value) <= 9007199254740991: return int(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(canonical(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = canonical(value[key])
		return result
	return value


static func json_bytes(value: Variant) -> PackedByteArray:
	return JSON.stringify(canonical(value), "", true, true).to_utf8_buffer()


static func content_digest(module: Dictionary) -> String:
	var copy := module.duplicate(true)
	copy.erase("content_sha256")
	return digest(json_bytes(copy))


static func safe_json(value: Variant, depth: int = 0) -> bool:
	if depth > 10: return false
	if value == null or value is bool or value is int: return true
	if value is float: return is_finite(value)
	if value is String: return value.length() <= 8192
	if value is Array:
		if value.size() > 1024: return false
		for item: Variant in value:
			if not safe_json(item, depth + 1): return false
		return true
	if value is Dictionary:
		if value.size() > 64: return false
		for key: Variant in value:
			if not (key is String or key is StringName) or str(key).length() > 128 or str(key).to_lower() in ["api_key", "apikey", "credential", "credentials", "authorization", "password", "secret", "access_token"] or not safe_json(value[key], depth + 1): return false
		return true
	return false


static func _regions(value: Variant, extent: Vector2i) -> bool:
	if not value is Array or value.size() > 64: return false
	for raw: Variant in value:
		if not raw is Array: return false
		var rect := rectangle(raw)
		if rect.size.x < 1 or rect.size.y < 1 or not Rect2i(Vector2i.ZERO, extent).encloses(rect): return false
	return true


static func _strings(value: Variant, maximum: int, length: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is String or item.is_empty() or item.length() > length or seen.has(item): return false
		seen[item] = true
	return true


static func _point(value: Variant, extent: Vector2i) -> bool:
	return pair(value, 0, 2047) and Rect2i(Vector2i.ZERO, extent).has_point(Vector2i(int(value[0]), int(value[1])))


static func _roles(value: Variant, admitted: PackedInt32Array) -> bool:
	if not value is Array or value.size() > 32: return false
	var names: Dictionary = {}
	var sources: Dictionary = {}
	for role: Variant in value:
		if not keys(role, ["name", "material_ids", "compatible_materials", "source"]) or not identifier(role.name) or names.has(role.name) or role.source != "authored": return false
		names[role.name] = true
		for field: String in ["material_ids", "compatible_materials"]:
			if not role[field] is Array or role[field].is_empty() or role[field].size() > 128: return false
			var seen: Dictionary = {}
			for material: Variant in role[field]:
				if not integer(material, 1, 255) or int(material) not in admitted or seen.has(int(material)): return false
				seen[int(material)] = true
		for material: Variant in role.material_ids:
			if sources.has(int(material)): return false
			sources[int(material)] = true
	return true


static func validate(raw: Variant, admitted: PackedInt32Array) -> Dictionary:
	if not keys(raw, KEYS) or raw.format != FORMAT: return failure("Unsupported Strata module format or fields.")
	if not identifier(raw.id) or not raw.name is String or raw.name.strip_edges().is_empty() or raw.name.length() > 96: return failure("Invalid module identity or name.")
	if not pair(raw.extent, 1, MAX_SIDE): return failure("Strata module sides must be 1–2048 native cells.")
	var extent := Vector2i(int(raw.extent[0]), int(raw.extent[1]))
	if extent.x * extent.y > MAX_CELLS: return failure("Strata module area exceeds 262144 native cells.")
	if not pair(raw.anchor, 0, MAX_SIDE - 1) or not Rect2i(Vector2i.ZERO, extent).has_point(Vector2i(int(raw.anchor[0]), int(raw.anchor[1]))): return failure("Module anchor lies outside its exact local extent.")
	if not raw.allowed_transforms is Array or raw.allowed_transforms.is_empty() or raw.allowed_transforms.size() > TRANSFORMS.size(): return failure("Declare supported exact-grid transforms.")
	var transforms: Dictionary = {}
	for transform: Variant in raw.allowed_transforms:
		if not transform is String or transform not in TRANSFORMS or transforms.has(transform): return failure("Unsupported or repeated exact-grid transform.")
		transforms[transform] = true
	if not keys(raw.geometry, ["encoding", "cells_base64", "write_mask_base64", "sha256", "mask_sha256"]) or raw.geometry.encoding != "uint16-le-row-major" or not raw.geometry.cells_base64 is String or not raw.geometry.write_mask_base64 is String: return failure("Invalid module material/mask encoding.")
	var count := extent.x * extent.y
	if raw.geometry.cells_base64.length() > ((count * 2 + 2) / 3) * 4 or raw.geometry.write_mask_base64.length() > ((count + 2) / 3) * 4: return failure("Encoded module exceeds its declared dimensions.")
	var cells := Marshalls.base64_to_raw(raw.geometry.cells_base64)
	var mask := Marshalls.base64_to_raw(raw.geometry.write_mask_base64)
	if cells.size() != count * 2 or mask.size() != count or Marshalls.raw_to_base64(cells) != raw.geometry.cells_base64 or Marshalls.raw_to_base64(mask) != raw.geometry.write_mask_base64: return failure("Module bytes or canonical base64 size differs.")
	if not hex_digest(raw.geometry.sha256) or digest(cells) != raw.geometry.sha256 or not hex_digest(raw.geometry.mask_sha256) or digest(mask) != raw.geometry.mask_sha256: return failure("Module material or no-write mask checksum differs.")
	if admitted.is_empty(): return failure("Current native material permissions are required.")
	for i: int in count:
		var material := cells.decode_u16(i * 2)
		if mask[i] not in [0, 1] or (mask[i] == 0 and material != 0): return failure("No-write pixels must contain canonical zero data; mask values are binary.")
		if mask[i] == 1 and material not in admitted: return failure("Module contains a material not admitted by the current native runtime.")
	if not _roles(raw.roles, admitted): return failure("Invalid authored material-role permissions.")
	if not _regions(raw.clearances, extent) or not _regions(raw.protected_regions, extent): return failure("Invalid module clearance or protection rectangles.")
	for region: Array in raw.clearances + raw.protected_regions:
		var box := rectangle(region)
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				if mask[y * extent.x + x] != 0: return failure("A declared clearance/protected region cannot also contain module writes.")
	if not raw.provenance is Dictionary or not safe_json(raw.provenance) or json_bytes(raw.provenance).size() > MAX_METADATA_BYTES: return failure("Module provenance must be bounded, finite JSON without credentials.")
	if not hex_digest(raw.content_sha256) or content_digest(raw) != raw.content_sha256: return failure("Module content identity differs.")
	if json_bytes(raw).size() > MAX_BYTES: return failure("Module exceeds the 2 MiB document budget.")
	return {"ok": true, "module": canonical(raw), "cells": cells, "mask": mask, "extent": extent, "error": ""}


static func create(identity: String, name: String, extent: Vector2i, cells: PackedByteArray, mask: PackedByteArray, provenance: Dictionary, admitted: PackedInt32Array, metadata: Dictionary = {}) -> Dictionary:
	if not keys(metadata, [], ["anchor", "allowed_transforms", "roles", "clearances", "protected_regions"]): return failure("Unsupported module metadata.")
	var module := {"format": FORMAT, "id": identity, "name": name, "extent": [extent.x, extent.y],
		"anchor": metadata.get("anchor", [0, 0]), "allowed_transforms": metadata.get("allowed_transforms", TRANSFORMS.duplicate()),
		"roles": metadata.get("roles", []), "clearances": metadata.get("clearances", []), "protected_regions": metadata.get("protected_regions", []),
		"geometry": {"encoding": "uint16-le-row-major", "cells_base64": Marshalls.raw_to_base64(cells), "write_mask_base64": Marshalls.raw_to_base64(mask), "sha256": digest(cells), "mask_sha256": digest(mask)},
		"provenance": provenance.duplicate(true)}
	module.content_sha256 = content_digest(module)
	return validate(module, admitted)


static func read_json(bytes: PackedByteArray, admitted: PackedInt32Array) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return failure("Native module JSON must contain at most 2 MiB.")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return failure("Native module JSON could not be parsed.")
	var raw: Variant = parser.data
	if raw is Dictionary and raw.get("format") == ARCHITECTURE_FORMAT: return from_architecture(raw, digest(bytes), admitted)
	return validate(raw, admitted)


static func from_architecture(raw: Dictionary, source_sha256: String, admitted: PackedInt32Array) -> Dictionary:
	if not keys(raw, ARCHITECTURE_KEYS) or raw.format != ARCHITECTURE_FORMAT or not pair(raw.extent, 1, ARCHITECTURE_MAX_SIDE): return failure("Unsupported #770 module interchange fields or its 512-side extent.")
	if not hex_digest(source_sha256): return failure("The original architecture source byte identity is required.")
	if not hex_digest(raw.content_sha256) or content_digest(raw) != raw.content_sha256: return failure("Architecture module content checksum differs.")
	if not keys(raw.geometry, ["encoding", "cells_base64", "sha256"]) or raw.geometry.encoding != "uint16-le-row-major" or not raw.geometry.cells_base64 is String: return failure("Unsupported architecture module geometry encoding.")
	var size := Vector2i(int(raw.extent[0]), int(raw.extent[1]))
	if raw.geometry.cells_base64.length() > ((size.x * size.y * 2 + 2) / 3) * 4: return failure("Architecture module encoded size exceeds its extent.")
	var original := Marshalls.base64_to_raw(raw.geometry.cells_base64)
	if original.size() != size.x * size.y * 2 or digest(original) != raw.geometry.sha256 or Marshalls.raw_to_base64(original) != raw.geometry.cells_base64: return failure("Architecture module native geometry checksum differs.")
	if not raw.attachments is Array or raw.attachments.size() > 128: return failure("Malformed architecture attachment declarations.")
	var attachment_ids: Dictionary = {}
	for attachment: Variant in raw.attachments:
		if not keys(attachment, ["id", "kind", "point", "facing", "compatibility", "required", "source"], ["end"]): return failure("Malformed architecture attachment fields.")
		if not identifier(attachment.id) or attachment_ids.has(attachment.id) or attachment.kind not in ["vertex", "line", "socket", "receptor"] or not _point(attachment.point, size) or not pair(attachment.facing, -1, 1) or absi(int(attachment.facing[0])) + absi(int(attachment.facing[1])) != 1 or not _strings(attachment.compatibility, 16, 64) or attachment.compatibility.is_empty() or not attachment.required is bool or attachment.source not in ["authored", "inferred"]: return failure("Malformed architecture attachment contract.")
		if attachment.required: return failure("Required architecture attachments need their separately owned solver; this Strata adapter refuses them.")
		if attachment.kind == "line":
			if not _point(attachment.get("end"), size) or attachment.end == attachment.point or (attachment.end[0] != attachment.point[0] and attachment.end[1] != attachment.point[1]): return failure("Malformed optional architecture attachment line.")
		elif attachment.has("end"): return failure("Only an attachment line may contain an endpoint.")
		attachment_ids[attachment.id] = true
	if not raw.variation_regions is Array or not _regions(raw.variation_regions, size): return failure("Malformed architecture variation regions.")
	if not _strings(raw.tags, 32, 64) or not _strings(raw.design_card_ids, 128, 128) or raw.part_type not in ["column_support", "beam_truss", "floor_ceiling", "viaduct_segment", "wall_facade", "window_door", "passage_clearance", "mechanical_housing", "pipework", "service_gallery", "greeble_cluster", "irregular_transition", "unclassified"] or not raw.provenance is Dictionary or not raw.recipe is Dictionary or not safe_json([raw.tags, raw.design_card_ids, raw.provenance, raw.recipe, raw.attachments]): return failure("Invalid architecture module metadata.")
	var mask := PackedByteArray()
	mask.resize(size.x * size.y)
	for i: int in mask.size(): mask[i] = 1 if original.decode_u16(i * 2) != 0 else 0
	var provenance := {"source_kind": "architecture-module", "source_sha256": source_sha256,
		"source_module_sha256": raw.content_sha256, "source_format": ARCHITECTURE_FORMAT,
		"reader_contract_source": ARCHITECTURE_SOURCE, "source_module_id": raw.id,
		"declared_attachments": raw.attachments, "variation_applied": false,
		"source_provenance": raw.provenance, "design_card_ids": raw.design_card_ids,
		"scope": "Exact stored native IDs with Empty treated as no-write; optional attachments are metadata, not solved connections."}
	return create(raw.id, raw.name, size, original, mask, provenance, admitted,
		{"anchor": raw.anchor, "allowed_transforms": raw.allowed_transforms, "roles": raw.roles,
		"clearances": raw.clearances, "protected_regions": raw.protected_regions})


static func transformed_size(size: Vector2i, transform: String) -> Vector2i:
	return Vector2i(size.y, size.x) if transform in ["rotate_90", "rotate_270"] else size


static func transform_point(point: Vector2i, size: Vector2i, transform: String) -> Vector2i:
	match transform:
		"mirror_x": return Vector2i(size.x - 1 - point.x, point.y)
		"mirror_y": return Vector2i(point.x, size.y - 1 - point.y)
		"rotate_90": return Vector2i(size.y - 1 - point.y, point.x)
		"rotate_180": return size - Vector2i.ONE - point
		"rotate_270": return Vector2i(point.y, size.x - 1 - point.x)
	return point


static func transform_rect(box: Rect2i, size: Vector2i, transform: String, origin: Vector2i) -> Rect2i:
	var lo := transform_point(box.position, size, transform)
	var hi := transform_point(box.end - Vector2i.ONE, size, transform)
	return Rect2i(origin + lo.min(hi), lo.max(hi) - lo.min(hi) + Vector2i.ONE)


static func compile(raw: Dictionary, placement: Dictionary, constraints: Dictionary, admitted: PackedInt32Array) -> Dictionary:
	var checked := validate(raw, admitted)
	if not checked.ok: return checked
	raw = checked.module
	if not keys(constraints, ["region"], ["protected", "allowed_materials"]): return failure("Module target constraints contain unsupported fields.")
	if not keys(placement, ["origin"], ["transform", "palette", "empty_mode"]) or not pair(placement.origin): return failure("Module placement requires an exact integer origin and known controls.")
	var transform: Variant = placement.get("transform", "identity")
	if not transform is String or transform not in raw.allowed_transforms: return failure("Module transform is not explicitly permitted.")
	if placement.get("empty_mode", "preserve") not in ["preserve", "clear"]: return failure("Choose preserve or explicit clear for module Empty cells.")
	var origin := Vector2i(int(placement.origin[0]), int(placement.origin[1]))
	var size: Vector2i = checked.extent
	var footprint := Rect2i(origin, transformed_size(size, transform))
	var region := rectangle(constraints.get("region"))
	if not region.encloses(footprint) or region.size.x < 1 or region.size.y < 1 or not Rect2i(0, 0, 2048, 2048).encloses(region): return failure("The complete transformed module must fit its authorized native region.")
	var guards: Variant = constraints.get("protected", [])
	var allowed: Variant = constraints.get("allowed_materials", Array(admitted))
	if not guards is Array or guards.size() > 64 or not allowed is Array or allowed.is_empty() or allowed.size() > 256: return failure("Invalid target protection or material permissions.")
	for material: Variant in allowed:
		if not integer(material, 0, 255) or int(material) not in admitted: return failure("Stage palette exceeds current native material permissions.")
	allowed = canonical(allowed)
	for guard: Variant in guards:
		var box := rectangle(guard)
		if box.size.x < 1 or box.size.y < 1: return failure("Invalid protected target rectangle.")
	var palette: Variant = placement.get("palette", {})
	if not palette is Dictionary or palette.size() > 32: return failure("Invalid material-role replacement map.")
	var replacements: Dictionary = {}
	var names: Dictionary = {}
	for role: Dictionary in raw.roles:
		names[role.name] = true
		if palette.has(role.name):
			if not integer(palette[role.name], 1, 255) or int(palette[role.name]) not in role.compatible_materials or int(palette[role.name]) not in allowed: return failure("Role replacement exceeds module or target material permission.")
			for material: Variant in role.material_ids: replacements[int(material)] = int(palette[role.name])
	for name: Variant in palette:
		if not names.has(name): return failure("Unknown authored material role.")
	var output: Dictionary = {}
	var source: PackedByteArray = checked.cells
	var mask: PackedByteArray = checked.mask
	var clearing: bool = placement.get("empty_mode", "preserve") == "clear"
	for y: int in size.y:
		for x: int in size.x:
			var index := y * size.x + x
			if mask[index] == 0 and not clearing: continue
			var local := Vector2i(x, y)
			for protected: Array in raw.protected_regions + raw.clearances:
				if rectangle(protected).has_point(local) and (mask[index] != 0 or clearing): return failure("Explicit clearing cannot overwrite module clearance/protection.")
			var material := int(replacements.get(source.decode_u16(index * 2), source.decode_u16(index * 2))) if mask[index] != 0 else 0
			if material not in allowed: return failure("Proposed material is outside the stage palette.")
			var point := origin + transform_point(local, size, transform)
			for guard: Variant in guards:
				if rectangle(guard).has_point(point): return failure("Module intersects protected target cells; partial clipping is refused.")
			output[point.y * 2048 + point.x] = [point.x, point.y, material]
	var ordered: Array = output.keys()
	ordered.sort()
	var cells := PackedInt32Array()
	for key: int in ordered: cells.append_array(PackedInt32Array(output[key]))
	var clearances: Array = []
	for box: Array in raw.clearances: clearances.append(rect_array(transform_rect(rectangle(box), size, transform, origin)))
	var protected_regions: Array = []
	for box: Array in raw.protected_regions: protected_regions.append(rect_array(transform_rect(rectangle(box), size, transform, origin)))
	return {"ok": true, "zero_writes": true, "cells": cells, "footprint": rect_array(footprint),
		"clearances": clearances, "protected_regions": protected_regions, "module_sha256": raw.content_sha256, "geometry_sha256": digest(cells.to_byte_array()),
		"anchor": origin + transform_point(Vector2i(int(raw.anchor[0]), int(raw.anchor[1])), size, transform), "error": ""}
