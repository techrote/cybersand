class_name CyberWorldGenerationPreview
extends Control

# A copied-cell authoring view. This node never owns or queries simulation World.
signal stroke_finished(points: PackedVector2Array)
signal pan_requested(delta_cells: Vector2)
signal zoom_requested(factor: float)
signal point_inspected(world_point: Vector2)

const MAX_STROKE_POINTS: int = 128
var camera_origin := Vector2.ZERO
var view_size := Vector2(384, 256)
var chunk_size: int = 128
var chunks: Dictionary = {}
var recipe: Dictionary = {}
var grid_visible: bool = true
var guides_visible: bool = true
var diagnostic_channel: String = ""
var diagnostic_opacity: float = 1.0
var tool_mode: int = 0
var brush_radius: float = 48.0
var _points := PackedVector2Array()
var _drawing: bool = false
var _panning: bool = false
var _pointer := Vector2(-10000, -10000)

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	mouse_exited.connect(func() -> void:
		_pointer = Vector2(-10000, -10000)
		queue_redraw())

func content_rect() -> Rect2:
	if size.x <= 0 or size.y <= 0 or view_size.x <= 0 or view_size.y <= 0:
		return Rect2()
	var scale_factor: float = minf(size.x / view_size.x, size.y / view_size.y)
	var extent: Vector2 = view_size * scale_factor
	return Rect2((size - extent) * 0.5, extent)

func screen_to_world(point: Vector2) -> Vector2:
	var content: Rect2 = content_rect()
	if content.size.x <= 0 or content.size.y <= 0:
		return camera_origin
	return camera_origin + (point - content.position) * view_size / content.size

func world_to_screen(point: Vector2) -> Vector2:
	var content: Rect2 = content_rect()
	return content.position + (point - camera_origin) * content.size / view_size

func cancel_gesture() -> void:
	_drawing = false
	_panning = false
	_points.clear()
	queue_redraw()

func _append_point(point: Vector2) -> void:
	if _points.is_empty() or point.distance_squared_to(_points[-1]) >= 4.0:
		if _points.size() < MAX_STROKE_POINTS:
			_points.append(point)
		else:
			_points[MAX_STROKE_POINTS - 1] = point

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mouse.pressed and content_rect().has_point(mouse.position):
				zoom_requested.emit(0.8 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25)
				accept_event()
			return
		if mouse.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] or (
			mouse.button_index == MOUSE_BUTTON_LEFT and tool_mode == 5):
			_panning = mouse.pressed and content_rect().has_point(mouse.position)
			accept_event()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed and content_rect().has_point(mouse.position):
			grab_focus()
			_drawing = true
			_points = PackedVector2Array([screen_to_world(mouse.position)])
		elif not mouse.pressed and _drawing:
			_append_point(screen_to_world(mouse.position))
			var completed: PackedVector2Array = _points.duplicate()
			cancel_gesture()
			stroke_finished.emit(completed)
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_pointer = motion.position
		if _panning:
			var content: Rect2 = content_rect()
			if content.size.x > 0 and content.size.y > 0:
				pan_requested.emit(-motion.relative * view_size / content.size)
		elif _drawing:
			_append_point(screen_to_world(motion.position))
		point_inspected.emit(screen_to_world(motion.position))
		queue_redraw()
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_gesture()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.026, 0.038))
	var content: Rect2 = content_rect()
	if content.size.x <= 0 or content.size.y <= 0:
		return
	draw_rect(content, Color(0.029, 0.043, 0.064))
	var visible_world := Rect2(camera_origin, view_size)
	for coordinate: Vector2i in chunks:
		var bounds := Rect2(Vector2(coordinate) * chunk_size, Vector2.ONE * chunk_size)
		if not visible_world.intersects(bounds):
			continue
		var entry: Dictionary = chunks[coordinate]
		var shown: Rect2 = bounds.intersection(visible_world)
		var screen_bounds := Rect2(world_to_screen(shown.position), shown.size * content.size / view_size)
		draw_texture_rect_region(entry.texture, screen_bounds, Rect2(shown.position - bounds.position, shown.size))
		if not diagnostic_channel.is_empty() and entry.has("diagnostic_texture"):
			draw_texture_rect_region(entry.diagnostic_texture, screen_bounds, Rect2(shown.position - bounds.position, shown.size), Color(1, 1, 1, diagnostic_opacity))
	if guides_visible:
		_draw_authored_guides()
	if grid_visible:
		_draw_chunk_grid(content)
	if _drawing and not _points.is_empty():
		if tool_mode in [3, 4]:
			var start: Vector2 = world_to_screen(_points[0])
			var finish: Vector2 = world_to_screen(_points[-1])
			draw_rect(Rect2(start, finish - start).abs(), Color(1.0, 0.75, 0.36, 0.15))
			draw_rect(Rect2(start, finish - start).abs(), Color(1.0, 0.8, 0.48), false, 2.0)
		else:
			_draw_path(_points, Color(0.38, 0.95, 0.84, 0.85), 2.0)
	if content.has_point(_pointer) and tool_mode in [0, 1, 2, 6, 7, 8, 9, 10]:
		var radius: float = brush_radius * content.size.x / view_size.x
		draw_arc(_pointer, radius, 0, TAU, 64, Color(0.65, 1.0, 0.89, 0.85), 1.5, true)
	draw_rect(content, Color(0.25, 0.38, 0.47), false, 1.0)

func _draw_chunk_grid(content: Rect2) -> void:
	var first := Vector2i(floori(camera_origin.x / chunk_size), floori(camera_origin.y / chunk_size))
	var last := Vector2i(floori((camera_origin.x + view_size.x - 0.001) / chunk_size), floori((camera_origin.y + view_size.y - 0.001) / chunk_size))
	var font: Font = ThemeDB.fallback_font
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var coordinate := Vector2i(x, y)
			var start: Vector2 = world_to_screen(Vector2(coordinate) * chunk_size)
			var bounds := Rect2(start, Vector2.ONE * chunk_size * content.size / view_size)
			draw_rect(bounds.intersection(content), Color(0.35, 0.68, 0.72, 0.22), false, 1.0)
			var text_pos: Vector2 = bounds.position.max(content.position) + Vector2(7, 20)
			var label_text: String = "%d, %d%s" % [x, y, "" if chunks.has(coordinate) else "  · queued"]
			draw_string(font, text_pos + Vector2.ONE, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.0, 0.0, 0.0, 0.95))
			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.64, 0.88, 0.89))

func _draw_authored_guides() -> void:
	for field: String in ["strokes", "paths", "modifiers"]:
		for item: Dictionary in recipe.get(field, []):
			var points := PackedVector2Array()
			for point: Array in item.get("points", []):
				points.append(Vector2(point[0], point[1]))
			_draw_path(points, Color(0.4, 0.96, 0.82, 0.68), 1.5)
	for field: String in ["overrides", "modules", "modifiers"]:
		for item: Dictionary in recipe.get(field, []):
			var bounds: Array = item.get("bounds", [])
			if bounds.size() != 4:
				continue
			var rect := Rect2(world_to_screen(Vector2(bounds[0], bounds[1])), Vector2(bounds[2], bounds[3]) * content_rect().size / view_size)
			var tint := Color(1.0, 0.71, 0.33, 0.7) if field == "overrides" else Color(0.7, 0.63, 1.0, 0.8)
			draw_rect(rect, tint, false, 1.5)

func _draw_path(points: PackedVector2Array, tint: Color, width: float) -> void:
	if points.is_empty():
		return
	var screen_points := PackedVector2Array()
	for point: Vector2 in points:
		screen_points.append(world_to_screen(point))
	if screen_points.size() == 1:
		draw_circle(screen_points[0], 3.0, tint)
	else:
		draw_polyline(screen_points, tint, width, true)
