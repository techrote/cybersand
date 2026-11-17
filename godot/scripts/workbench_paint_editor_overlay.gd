extends Control

# Presentation only: pointer/World authority remains with the existing host.
# Preview IDs come from the copied native-material packet, never RG8 pixels.
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const MAX_PREVIEW_CELLS: int = 16384
const MAX_MATERIAL_SPANS: int = 16384
const PREVIEW := Color(0.35, 0.85, 1.0, 0.36)
const EDGE := Color(0.6, 0.92, 1.0, 0.95)
const ERASE := Color(1.0, 0.38, 0.35, 0.32)
const SELECTION := Color(1.0, 0.8, 0.3, 0.95)

var editor: Control
var _content := Rect2()
var _camera := Vector2.ZERO
var _scale := Vector2.ONE
var _extent := Vector2i.ZERO
var _line_key: Array = []
var _line_spans: Array[Rect2i] = []
var _line_bounds_only: bool = false
var _clipboard: Dictionary = {}
var _clipboard_spans: Array[Dictionary] = []
var _clipboard_bounds_only: bool = false
var _stroke_seen: int = 0
var _stroke_radius: int = -1
var _stroke_first := Vector2i(-1, -1)
var _stroke_cells: Dictionary = {}
var _stroke_spans: Array[Rect2i] = []
var _stroke_bounds := Rect2i()
var _stroke_bounds_only: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 80
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true


func _process(_delta: float) -> void:
	# All expensive previews are cached. A redraw reflects pan/zoom and clears
	# cancellation immediately, including a cancelled drag over another panel.
	queue_redraw()


func invalidate() -> void:
	_line_key.clear()
	_clipboard = {}
	_reset_stroke()
	queue_redraw()


func _draw() -> void:
	if editor == null or not is_instance_valid(editor) or not editor.paint_mode_active():
		_reset_stroke()
		return
	var host: Control = editor.host
	if host == null or editor.bench.applied.is_empty():
		return
	_content = host.view_content_rect()
	var view_size: Vector2i = host.current_view_size
	if not _content.has_area() or view_size.x <= 0 or view_size.y <= 0:
		return
	_camera = host.presentation_camera_origin()
	_scale = _content.size / Vector2(view_size)
	_extent = editor.extent()
	var selection: Rect2i = editor.selection
	if selection.has_area():
		_draw_region(selection, Color(SELECTION, 0.05), SELECTION)
	var cursor: Vector2i = editor.cursor
	if cursor.x < 0 or cursor.y < 0 or cursor.x >= _extent.x or cursor.y >= _extent.y:
		if not editor.dragging:
			_reset_stroke()
		return
	var tool: String = editor.tool_name()
	var erasing: bool = tool == "Eraser" or editor.drag_erase
	var tint: Color = ERASE if erasing else PREVIEW
	var edge: Color = Color(1.0, 0.6, 0.5, 0.95) if erasing else EDGE
	var radius: int = editor.radius()
	if tool == "Paste":
		_draw_paste(cursor, editor.clipboard)
		_reset_stroke()
		return
	if editor.dragging and tool in ["Rectangle", "Outline", "Select"]:
		var region: Rect2i = editor.drag_region()
		if tool == "Rectangle":
			_draw_region(region, tint, edge)
		elif tool == "Outline":
			_draw_outline_cells(region, tint)
			_draw_region(region, Color.TRANSPARENT, edge)
		else:
			_draw_region(region, Color(SELECTION, 0.08), SELECTION)
		_reset_stroke()
		return
	if editor.dragging and tool in ["Brush", "Eraser"]:
		_draw_stroke(editor.stroke, radius, tint, edge)
	else:
		_reset_stroke()
	if tool in ["Brush", "Eraser", "Line"]:
		var from_cell: Vector2i = editor.anchor if editor.dragging and tool == "Line" else cursor
		_draw_line_preview(from_cell, cursor, radius, tint, edge)
	elif tool == "Fill":
		var centre: Vector2 = _point(Vector2(cursor) + Vector2(0.5, 0.5))
		draw_line(centre - Vector2(6, 0), centre + Vector2(6, 0), edge, 1.0)
		draw_line(centre - Vector2(0, 6), centre + Vector2(0, 6), edge, 1.0)
		_draw_region(Rect2i(cursor, Vector2i.ONE), tint, edge)
	else:
		_draw_region(Rect2i(cursor, Vector2i.ONE), Color.TRANSPARENT, edge)


func _point(cell: Vector2) -> Vector2:
	return _content.position + (cell - _camera) * _scale


func _screen_region(region: Rect2i) -> Rect2:
	var bounded: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, _extent))
	if not bounded.has_area():
		return Rect2()
	return Rect2(_point(Vector2(bounded.position)), Vector2(bounded.size) * _scale).intersection(_content)


func _draw_region(region: Rect2i, fill: Color, edge: Color = Color.TRANSPARENT) -> void:
	var screen: Rect2 = _screen_region(region)
	if not screen.has_area():
		return
	if fill.a > 0.0:
		draw_rect(screen, fill, true)
	if edge.a > 0.0:
		draw_rect(screen, Color(0.03, 0.05, 0.07, 0.85), false, 3.0)
		draw_rect(screen, edge, false, 1.0)


func _draw_outline_cells(region: Rect2i, tint: Color) -> void:
	if not region.has_area():
		return
	_draw_region(Rect2i(region.position, Vector2i(region.size.x, 1)), tint)
	if region.size.y > 1:
		_draw_region(Rect2i(region.position + Vector2i(0, region.size.y - 1), Vector2i(region.size.x, 1)), tint)
	if region.size.y > 2:
		_draw_region(Rect2i(region.position + Vector2i(0, 1), Vector2i(1, region.size.y - 2)), tint)
		if region.size.x > 1:
			_draw_region(Rect2i(region.position + Vector2i(region.size.x - 1, 1), Vector2i(1, region.size.y - 2)), tint)


func _line_bounds(a: Vector2i, b: Vector2i, radius: int) -> Rect2i:
	var start := Vector2i(mini(a.x, b.x), mini(a.y, b.y)) - Vector2i(radius, radius)
	var finish := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y)) + Vector2i(radius + 1, radius + 1)
	return Rect2i(start, finish - start)


func _reasonable_preview(a: Vector2i, b: Vector2i, radius: int) -> bool:
	# Conservative cost guard before entering the canonical rasterizer. This
	# is a preview limit only; it never changes the committed operation.
	var diameter: int = radius * 2 + 1
	return (absi(a.x - b.x) + absi(a.y - b.y) + diameter) * diameter <= MAX_PREVIEW_CELLS


func _draw_line_preview(a: Vector2i, b: Vector2i, radius: int, tint: Color, edge: Color) -> void:
	var key: Array = [a, b, radius, _extent]
	if key != _line_key:
		_line_key = key
		_line_spans.clear()
		_line_bounds_only = not _reasonable_preview(a, b, radius)
		if not _line_bounds_only:
			var plan: Dictionary = Shapes.line(a, b, radius, _extent, MAX_PREVIEW_CELLS)
			_line_bounds_only = not plan.get("accepted", false)
			if not _line_bounds_only:
				_line_spans = _cell_spans(plan.cells)
	if _line_bounds_only:
		_draw_region(_line_bounds(a, b, radius), Color.TRANSPARENT, edge)
		_note(b, "bounds preview")
		return
	for span: Rect2i in _line_spans:
		_draw_region(span, tint)
	if a == b:
		_draw_region(Rect2i(b, Vector2i.ONE), Color.TRANSPARENT, edge)


func _cell_spans(cells: PackedInt32Array) -> Array[Rect2i]:
	var spans: Array[Rect2i] = []
	for offset: int in range(0, cells.size(), 2):
		var x: int = cells[offset]
		var y: int = cells[offset + 1]
		if not spans.is_empty():
			var last: Rect2i = spans.back()
			if last.position.y == y and last.end.x == x:
				last.size.x += 1
				spans[spans.size() - 1] = last
				continue
		spans.append(Rect2i(Vector2i(x, y), Vector2i.ONE))
	return spans


func _reset_stroke() -> void:
	_stroke_seen = 0
	_stroke_radius = -1
	_stroke_first = Vector2i(-1, -1)
	_stroke_cells.clear()
	_stroke_spans.clear()
	_stroke_bounds = Rect2i()
	_stroke_bounds_only = false


func _draw_stroke(points: Array[Vector2i], radius: int, tint: Color, edge: Color) -> void:
	if points.is_empty():
		return
	if _stroke_radius != radius or _stroke_first != points[0] or points.size() < _stroke_seen:
		_reset_stroke()
		_stroke_radius = radius
		_stroke_first = points[0]
	var changed: bool = points.size() != _stroke_seen
	for i: int in range(_stroke_seen, points.size()):
		var a: Vector2i = points[maxi(0, i - 1)]
		var b: Vector2i = points[i]
		var bounds: Rect2i = _line_bounds(a, b, radius)
		_stroke_bounds = bounds if not _stroke_bounds.has_area() else _stroke_bounds.merge(bounds)
		if _stroke_bounds_only:
			continue
		if not _reasonable_preview(a, b, radius):
			_stroke_bounds_only = true
			continue
		var plan: Dictionary = Shapes.line(a, b, radius, _extent, MAX_PREVIEW_CELLS)
		if not plan.get("accepted", false):
			_stroke_bounds_only = true
			continue
		var cells: PackedInt32Array = plan.cells
		for offset: int in range(0, cells.size(), 2):
			var cell_key: int = cells[offset + 1] * _extent.x + cells[offset]
			_stroke_cells[cell_key] = true
			if _stroke_cells.size() > MAX_PREVIEW_CELLS:
				_stroke_bounds_only = true
				break
	_stroke_seen = points.size()
	if _stroke_bounds_only:
		_stroke_cells.clear()
		_stroke_spans.clear()
		_draw_region(_stroke_bounds, Color.TRANSPARENT, edge)
		_note(points.back(), "bounds preview")
		return
	if changed:
		var keys: Array = _stroke_cells.keys()
		keys.sort()
		var cells := PackedInt32Array()
		cells.resize(keys.size() * 2)
		for i: int in range(keys.size()):
			cells[i * 2] = int(keys[i]) % _extent.x
			cells[i * 2 + 1] = int(int(keys[i]) / _extent.x)
		_stroke_spans = _cell_spans(cells)
	for span: Rect2i in _stroke_spans:
		_draw_region(span, tint)


func _draw_paste(cursor: Vector2i, clipboard: Dictionary) -> void:
	var stamp_size: Vector2i = clipboard.get("size", Vector2i.ZERO)
	var materials: PackedInt32Array = clipboard.get("materials", PackedInt32Array())
	if stamp_size.x <= 0 or stamp_size.y <= 0 or materials.size() != stamp_size.x * stamp_size.y:
		return
	if not is_same(_clipboard, clipboard):
		_clipboard = clipboard
		_clipboard_spans.clear()
		_clipboard_bounds_only = false
		for y: int in range(stamp_size.y):
			var x: int = 0
			while x < stamp_size.x:
				var material_id: int = materials[y * stamp_size.x + x]
				var start: int = x
				x += 1
				while x < stamp_size.x and materials[y * stamp_size.x + x] == material_id:
					x += 1
				if _clipboard_spans.size() >= MAX_MATERIAL_SPANS:
					_clipboard_bounds_only = true
					break
				_clipboard_spans.append({"region": Rect2i(start, y, x - start, 1), "material": material_id})
			if _clipboard_bounds_only:
				_clipboard_spans.clear()
				break
	var valid: bool = cursor.x + stamp_size.x <= _extent.x and cursor.y + stamp_size.y <= _extent.y
	var edge: Color = EDGE if valid else Color(1.0, 0.35, 0.3, 0.95)
	if not _clipboard_bounds_only:
		for span: Dictionary in _clipboard_spans:
			var region: Rect2i = span.region
			region.position += cursor
			_draw_region(region, _material_tint(int(span.material)))
	_draw_region(Rect2i(cursor, stamp_size), Color.TRANSPARENT, edge)
	if not valid:
		_note(cursor, "paste exceeds world")
	elif _clipboard_bounds_only:
		_note(cursor, "bounds preview")


func _material_tint(material_id: int) -> Color:
	if material_id == 0:
		return Color(0.8, 0.85, 0.9, 0.16)
	# Distinct-ID preview tint, not an alternative material appearance catalogue.
	return Color.from_hsv(fposmod(float(material_id) * 0.61803398875, 1.0), 0.58, 1.0, 0.52)


func _note(cell: Vector2i, text: String) -> void:
	var position: Vector2 = _point(Vector2(cell)) + Vector2(10, -8)
	position.x = clampf(position.x, _content.position.x + 6, maxf(_content.position.x + 6, _content.end.x - 165))
	position.y = clampf(position.y, _content.position.y + 18, _content.end.y - 6)
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0.03, 0.05, 0.07, 0.95))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EDGE)
