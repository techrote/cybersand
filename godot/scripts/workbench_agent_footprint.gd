extends RefCounted
## Pure, bounded geometry preflight for WB-AGENT-001 (#526).
##
## This helper NEVER reads or writes CyberCellWorld, admits a worker request,
## registers a proposal, or claims that an edit was applied. Only the existing
## exclusive simulation owner may inspect cell IDs, revalidate protection and
## revisions, perform authoring, and produce a verified native receipt.
##
## Coordinates are integer WORLD cells, including legal x/y greater than 1024.
## For overlapping operations, retain every ordered raster; do not collapse
## filters to a single final cell value before native readback.

const MAX_PRIMITIVES: int = 8
const MAX_DISTINCT_CELLS: int = 4096
# Under the inclusive integer-disc rule radius 36 has 4053 cells;
# radius 37 has 4293, already above the per-edit cell limit.
const MAX_DISC_RADIUS: int = 36


static func _refused(reason: String, operation_index: int = -1) -> Dictionary:
	return {
		"status": "refused",
		"reason": reason,
		"operation_index": operation_index,
		"distinct_cells": 0,
		"footprint": [],
		"raster_operations": []
	}


static func _valid_region(region: Rect2i, world: Rect2i) -> bool:
	return region.size.x > 0 and region.size.y > 0 \
		and world.has_point(region.position) \
		and world.has_point(region.end - Vector2i.ONE)


static func _all_fields_integer(op: Dictionary, fields: Array) -> bool:
	for field: String in fields:
		if not op.has(field) or typeof(op[field]) != TYPE_INT:
			return false
	return true


static func _rasterize_disc(op: Dictionary) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var cx: int = op["x"]
	var cy: int = op["y"]
	var radius: int = op["radius"]
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				points.append(Vector2i(cx + x, cy + y))
	return points


static func _rasterize_line(op: Dictionary) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x: int = op["x0"]
	var y: int = op["y0"]
	var end_x: int = op["x1"]
	var end_y: int = op["y1"]
	var dx: int = absi(end_x - x)
	var dy: int = -absi(end_y - y)
	var step_x: int = 1 if x < end_x else -1
	var step_y: int = 1 if y < end_y else -1
	var error: int = dx + dy
	while true:
		points.append(Vector2i(x, y))
		if x == end_x and y == end_y:
			break
		var twice: int = 2 * error
		if twice >= dy:
			error += dy
			x += step_x
		if twice <= dx:
			error += dx
			y += step_y
	return points


static func _rasterize_rectangle(op: Dictionary) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for y: int in range(op["y0"], op["y1"] + 1):
		for x: int in range(op["x0"], op["x1"] + 1):
			points.append(Vector2i(x, y))
	return points


## Validate and rasterize exact ordered operations without ANY world mutation.
##
## Inputs:
##   operations: Array[Dictionary] with shape/material + integer coordinates,
##               optionally replace_only_material (native-ID filter).
##   extent: actual finite workbench dimensions (no fixed 1024x1024 domain).
##   scope: exact authorized world-space Rect2i.
##   protection: array of protected world-space Rect2i.
##   allowed_materials: task-authorized replacement material IDs.
##   native_palette_ids: known native material IDs, supplied by a trusted caller;
##                       NEVER inferred from render colour or model text.
##
## Return status = validated_geometry or refused. On success, footprint is a
## deterministic unique Array[Vector2i], and raster_operations retain ORDER and
## filter semantics; the exclusive worker must inspect/material-check all cells,
## compute changed/excluded counts, stage proposals, fence human queued intent,
## and later read back before claiming actual application.
static func compile(
	operations: Variant,
	extent: Vector2i,
	scope: Rect2i,
	protection: Array,
	allowed_materials: Array,
	native_palette_ids: Array
) -> Dictionary:
	if not operations is Array or operations.is_empty() or operations.size() > MAX_PRIMITIVES:
		return _refused("invalid_primitive_count")
	if extent.x <= 0 or extent.y <= 0:
		return _refused("invalid_world_extent")
	var world := Rect2i(Vector2i.ZERO, extent)
	if not _valid_region(scope, world):
		return _refused("invalid_authorized_scope")
	if native_palette_ids.is_empty() or allowed_materials.is_empty():
		return _refused("empty_material_allowlist")
	for material: Variant in native_palette_ids:
		if typeof(material) != TYPE_INT or int(material) < 0:
			return _refused("invalid_native_palette")
	for material: Variant in allowed_materials:
		if typeof(material) != TYPE_INT or material not in native_palette_ids:
			return _refused("invalid_material_allowlist")
	for item: Variant in protection:
		if not item is Rect2i or not _valid_region(item, world):
			return _refused("invalid_protected_region")

	var unique: Array[Vector2i] = []
	var seen: Dictionary = {}
	var rasters: Array = []
	for index: int in range(operations.size()):
		var raw: Variant = operations[index]
		if not raw is Dictionary:
			return _refused("operation_not_object", index)
		var op: Dictionary = raw
		if not op.has("shape") or typeof(op["shape"]) != TYPE_STRING:
			return _refused("invalid_shape", index)
		var shape: String = op["shape"]
		var mandatory: Array = ["material"]
		var accepted: Array = ["shape", "material", "replace_only_material"]
		match shape:
			"disc":
				mandatory.append_array(["x", "y", "radius"])
				accepted.append_array(["x", "y", "radius"])
			"line", "rectangle":
				mandatory.append_array(["x0", "y0", "x1", "y1"])
				accepted.append_array(["x0", "y0", "x1", "y1"])
			_:
				return _refused("unsupported_shape", index)
		if not _all_fields_integer(op, mandatory):
			return _refused("non_integer_or_missing_field", index)
		for key: Variant in op.keys():
			if key not in accepted:
				return _refused("unknown_operation_field", index)
		var material: int = op["material"]
		if material not in native_palette_ids or material not in allowed_materials:
			return _refused("replacement_material_not_allowed", index)
		if op.has("replace_only_material"):
			if typeof(op["replace_only_material"]) != TYPE_INT \
					or op["replace_only_material"] not in native_palette_ids:
				return _refused("invalid_replace_filter", index)

		var points: Array[Vector2i] = []
		match shape:
			"disc":
				var radius: int = op["radius"]
				if radius < 0 or radius > MAX_DISC_RADIUS:
					return _refused("disc_exceeds_cell_budget", index)
				points = _rasterize_disc(op)
			"line":
				var span: int = maxi(absi(op["x1"] - op["x0"]), absi(op["y1"] - op["y0"])) + 1
				if span > MAX_DISTINCT_CELLS:
					return _refused("line_exceeds_cell_budget", index)
				points = _rasterize_line(op)
			"rectangle":
				if op["x1"] < op["x0"] or op["y1"] < op["y0"]:
					return _refused("reversed_rectangle_bounds", index)
				var width: int = op["x1"] - op["x0"] + 1
				var height: int = op["y1"] - op["y0"] + 1
				if width > MAX_DISTINCT_CELLS or height > MAX_DISTINCT_CELLS \
						or width * height > MAX_DISTINCT_CELLS:
					return _refused("rectangle_exceeds_cell_budget", index)
				points = _rasterize_rectangle(op)

		for point: Vector2i in points:
			if not world.has_point(point) or not scope.has_point(point):
				return _refused("outside_authorized_scope", index)
			for guarded: Rect2i in protection:
				if guarded.has_point(point):
					return _refused("protected_region", index)
			if not seen.has(point):
				seen[point] = true
				unique.append(point)
				if unique.size() > MAX_DISTINCT_CELLS:
					return _refused("distinct_cell_budget_exceeded", index)
		var ordered: Dictionary = {
			"shape": shape,
			"material": material,
			"cells": points
		}
		if op.has("replace_only_material"):
			ordered["replace_only_material"] = op["replace_only_material"]
		rasters.append(ordered)
	return {
		"status": "validated_geometry",
		"reason": "",
		"operation_index": -1,
		"distinct_cells": unique.size(),
		"footprint": unique,
		"raster_operations": rasters
	}
