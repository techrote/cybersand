extends SceneTree

# WB-AGENT-001 (#526): pure integer-world rasterization / scope preflight.
# This intentionally does NOT claim worker/native receipt, render or application
# acceptance; those must be exercised by the follow-on authoritative session.
const Footprint = preload("res://scripts/workbench_agent_footprint.gd")

var failures: int = 0
var assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)


func _run() -> void:
	var extent := Vector2i(2048, 2048)
	var scope := Rect2i(Vector2i(1100, 80), Vector2i(400, 400))
	var allowed: Array = [0, 58]
	var palette: Array = [0, 2, 58]
	var protection: Array = [Rect2i(Vector2i(1200, 100), Vector2i(8, 8))]

	var disc: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1150, "y":90, "radius":1, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(disc.status == "validated_geometry", "valid >1024 coordinate disc rejected")
	_expect(disc.distinct_cells == 5, "radius-1 disc did not contain 5 integer cells")
	_expect(
		disc.footprint.has(Vector2i(1150, 90)) and disc.footprint.has(Vector2i(1151, 90)),
		"valid disc did not include center and axis pixel"
	)
	var repeat: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1150, "y":90, "radius":1, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(disc.footprint == repeat.footprint, "raster order is not deterministic")

	var overlapping: Dictionary = Footprint.compile(
		[
			{"shape":"line", "x0":1101, "y0":120, "x1":1103, "y1":120,
				"material":58},
			{"shape":"rectangle", "x0":1102, "y0":119, "x1":1103, "y1":120,
				"material":0, "replace_only_material":58}
		],
		extent, scope, protection, allowed, palette
	)
	_expect(overlapping.status == "validated_geometry", "overlapping ordered operations rejected")
	_expect(overlapping.distinct_cells == 5, "distinct footprint must deduplicate overlaps")
	_expect(overlapping.raster_operations.size() == 2, "operation ordering was collapsed")
	_expect(
		overlapping.raster_operations[1].replace_only_material == 58,
		"filter on later operation was lost"
	)
	_expect(
		overlapping.raster_operations[0].cells.has(Vector2i(1102, 120))
		and overlapping.raster_operations[1].cells.has(Vector2i(1102, 120)),
		"overlapping cell missing from an operation raster"
	)

	var protected: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1200, "y":100, "radius":0, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(protected.status == "refused" and protected.reason == "protected_region",
		"protected motif was silently clipped or admitted")
	_expect(protected.footprint.is_empty() and protected.raster_operations.is_empty(),
		"refused operation returned an apparently executable partial raster")

	var forbidden: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1150, "y":90, "radius":0, "material":2}],
		extent, scope, protection, allowed, palette
	)
	_expect(forbidden.reason == "replacement_material_not_allowed",
		"non-allowlisted Sand replacement admitted")
	var float_coordinate: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1150.0, "y":90, "radius":0, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(float_coordinate.reason == "non_integer_or_missing_field",
		"floating-point coordinate silently truncated")
	var unknown_field: Dictionary = Footprint.compile(
		[{"shape":"line", "x0":1100, "y0":90, "x1":1101, "y1":90,
			"material":58, "unchecked":true}],
		extent, scope, protection, allowed, palette
	)
	_expect(unknown_field.reason == "unknown_operation_field",
		"unknown operation argument was silently ignored")

	var outside: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1499, "y":479, "radius":1, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(outside.reason == "outside_authorized_scope",
		"partially out-of-scope disc was silently clipped")
	var large_rect: Dictionary = Footprint.compile(
		[{"shape":"rectangle", "x0":1100, "y0":80, "x1":1199, "y1":179,
			"material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(large_rect.reason == "rectangle_exceeds_cell_budget",
		"100x100 region should be rejected before raster allocation")
	var maximum_disc: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1350, "y":350, "radius":36, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(maximum_disc.status == "validated_geometry" and maximum_disc.distinct_cells == 4053,
		"maximum legal integer disc's 4053-cell geometry changed")
	var excessive_disc: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1350, "y":350, "radius":37, "material":58}],
		extent, scope, protection, allowed, palette
	)
	_expect(excessive_disc.reason == "disc_exceeds_cell_budget",
		"radius 37 exceeds 4096 integer cells")
	var repeated_disc: Dictionary = Footprint.compile(
		[
			{"shape":"disc", "x":1350, "y":350, "radius":36, "material":58},
			{"shape":"disc", "x":1350, "y":350, "radius":36, "material":0}
		],
		extent, scope, protection, allowed, palette
	)
	_expect(repeated_disc.status == "validated_geometry"
		and repeated_disc.distinct_cells == 4053
		and repeated_disc.raster_operations.size() == 2,
		"identical overlapping primitives should retain order but share footprint budget")

	var huge_line: Dictionary = Footprint.compile(
		[{"shape":"line", "x0":0, "y0":0, "x1":4096, "y1":0, "material":58}],
		Vector2i(6000, 2048), Rect2i(Vector2i.ZERO, Vector2i(5000, 2048)),
		[], allowed, palette
	)
	_expect(huge_line.reason == "line_exceeds_cell_budget",
		"4097-cell line exceeded the edit budget")
	var excess_ops: Array = []
	for i: int in range(9):
		excess_ops.append({"shape":"disc", "x":1150 + i, "y":90, "radius":0, "material":58})
	var excessive_count: Dictionary = Footprint.compile(
		excess_ops, extent, scope, protection, allowed, palette
	)
	_expect(excessive_count.reason == "invalid_primitive_count", "ninth primitive was admitted")
	var invalid_filter: Dictionary = Footprint.compile(
		[{"shape":"disc", "x":1150, "y":90, "radius":0, "material":0,
			"replace_only_material":999999}],
		extent, scope, protection, allowed, palette
	)
	_expect(invalid_filter.reason == "invalid_replace_filter", "unknown native filter admitted")

	print("WB_AGENT_FOOTPRINT: %d assertions, %d failure(s)" % [assertions, failures])
	quit(1 if failures else 0)
