extends Control
## Pixel-accurate inspection of an immutable, native-backed attempt image.
## Framing is shareable between comparison panes; this never edits a World.
signal framing_changed(center: Vector2, zoom: float)
signal cell_hovered(position: Vector2i, material: int)

var texture: Texture2D
var extent := Vector2i.ONE
var reference_extent := Vector2i.ONE
var native_cells := PackedByteArray()
var center := Vector2(0.5, 0.5)
var zoom := 1.0
var caption := "No native result yet"
var _dragging := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	clip_contents = true
	resized.connect(queue_redraw)


func set_result(value: Texture2D, result_extent: Vector2i, cells: PackedByteArray,
		label: String, common_extent := Vector2i.ZERO) -> void:
	texture = value
	extent = result_extent.max(Vector2i.ONE)
	reference_extent = common_extent.max(extent)
	native_cells = cells
	caption = label
	queue_redraw()


func set_framing(value_center: Vector2, value_zoom: float) -> void:
	center = value_center
	zoom = clampf(value_zoom, _minimum_zoom(), 32.0)
	queue_redraw()


func fit() -> void:
	set_framing(Vector2(reference_extent) * 0.5, 1.0)
	framing_changed.emit(center, zoom)


func native_scale() -> void:
	var base := _base_scale()
	if base > 0.0:
		set_framing(center, 1.0 / base)
		framing_changed.emit(center, zoom)


func _base_scale() -> float:
	return maxf(0.0001, minf(size.x / float(reference_extent.x), size.y / float(reference_extent.y)))


func _minimum_zoom() -> float:
	# Small native footprints in a large inspector still need a true 1:1 view.
	return minf(0.25, 1.0 / _base_scale())


func pixels_per_cell() -> float:
	return _base_scale() * zoom


func material_at(point: Vector2i) -> int:
	if point.x < 0 or point.y < 0 or point.x >= extent.x or point.y >= extent.y:
		return -1
	var offset := (point.y * extent.x + point.x) * 2
	return int(native_cells.decode_u16(offset)) if offset + 1 < native_cells.size() else -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101622"))
	if texture != null:
		var scale := pixels_per_cell()
		var origin := size * 0.5 - center * scale
		draw_texture_rect(texture, Rect2(origin, Vector2(extent) * scale), false)
		draw_rect(Rect2(origin, Vector2(extent) * scale), Color("607086"), false, 1.0)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(12, 25), caption,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 14, Color("a8b5ca"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before: Vector2 = center + (event.position - size * 0.5) / pixels_per_cell()
			zoom = clampf(zoom * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), _minimum_zoom(), 32.0)
			center = before - (event.position - size * 0.5) / pixels_per_cell()
			framing_changed.emit(center, zoom)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			center -= event.relative / pixels_per_cell()
			framing_changed.emit(center, zoom)
			queue_redraw()
			accept_event()
		var cell := Vector2i((center + (event.position - size * 0.5) / pixels_per_cell()).floor())
		cell_hovered.emit(cell, material_at(cell))
