extends SceneTree

# Focused contract check for the dirty RG8 RenderBridge. This intentionally
# avoids a broad simulation fixture: it verifies one full recovery packet and
# one compact delta, including Water's projected fixed-point mass.

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if _failures != 0:
		quit(_failures)
		return

	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var full: Dictionary = world.take_render_snapshot(true)
	var full_cells: PackedByteArray = full.get("cells", PackedByteArray())
	var full_rectangles: PackedInt32Array = full.get("rectangles", PackedInt32Array())
	_expect(bool(full.get("full_refresh", false)), "initial packet was not a full refresh")
	_expect(int(full.get("channels", 0)) == 2, "native render projection is not RG8")
	_expect(full_rectangles.size() == 6, "full packet metadata is malformed")
	_expect(
		full_cells.size() == CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2,
		"full RG8 packet has the wrong byte count"
	)

	var empty: Dictionary = world.take_render_snapshot(false)
	_expect(
		PackedByteArray(empty.get("cells", PackedByteArray())).is_empty(),
		"unchanged world emitted a spurious delta"
	)

	world.emit_disc(500, 200, 1, CyberCellWorld.WATER)
	var delta: Dictionary = world.take_render_snapshot(false)
	var delta_cells: PackedByteArray = delta.get("cells", PackedByteArray())
	var delta_rectangles: PackedInt32Array = delta.get("rectangles", PackedInt32Array())
	_expect(not bool(delta.get("full_refresh", true)), "ordinary edit forced a full refresh")
	_expect(not delta_rectangles.is_empty(), "ordinary edit emitted no dirty rectangle")
	_expect(delta_cells.size() < full_cells.size(), "ordinary edit copied the full world")
	_expect(
		_contains_material_state(delta_rectangles, delta_cells, CyberCellWorld.WATER, 255),
		"Water delta omitted material ID or projected mass"
	)

	if _failures == 0:
		print(
			"Native RenderBridge regression passed; full %d bytes, delta %d bytes/%d patches" % [
				full_cells.size(),
				delta_cells.size(),
				delta_rectangles.size() / 6,
			]
		)
	quit(_failures)


func _contains_material_state(
	rectangles: PackedInt32Array,
	cells: PackedByteArray,
	material_id: int,
	visual_state: int
) -> bool:
	for metadata_offset: int in range(0, rectangles.size(), 6):
		var width: int = rectangles[metadata_offset + 2]
		var height: int = rectangles[metadata_offset + 3]
		var data_offset: int = rectangles[metadata_offset + 4]
		var stride: int = rectangles[metadata_offset + 5]
		for row: int in range(height):
			for column: int in range(width):
				var offset: int = data_offset + row * stride + column * 2
				if cells[offset] == material_id and cells[offset + 1] == visual_state:
					return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
