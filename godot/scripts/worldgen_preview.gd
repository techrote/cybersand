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
var inspection_only: bool = false
var extra_overlay: int = 0
var semantic_plan: Dictionary = {}
var route_report: Dictionary = {}
var selected_feature: String = ""
const MAX_VECTOR_ARROWS: int = 256
const MAX_STREAMLINES: int = 24
const MAX_STREAMLINE_STEPS: int = 64
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
		if inspection_only or mouse.ctrl_pressed:
			if mouse.pressed and content_rect().has_point(mouse.position): point_inspected.emit(screen_to_world(mouse.position))
			accept_event()
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
	if extra_overlay == 1: _draw_semantics()
	elif extra_overlay == 2: _draw_vectors()
	elif extra_overlay == 3: _draw_streamlines()
	elif extra_overlay == 4: _draw_density()
	elif extra_overlay in [5, 6]: _draw_cost()
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

# Each overlay consumes bounded copied native results. Geometry overlays are
# metadata views, not claims that a route is physically traversable by an actor.
func _draw_semantics() -> void:
	var view := Rect2(camera_origin, view_size)
	var font: Font = ThemeDB.fallback_font
	for feature: Dictionary in semantic_plan.get("features", []):
		var bounds: Array = feature.get("bounds", [])
		if bounds.size() != 4: continue
		var rect := Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		if not view.intersects(rect): continue
		var start: Vector2 = world_to_screen(rect.position)
		var extent: Vector2 = rect.size * content_rect().size / view_size
		var selected: bool = str(feature.id) == selected_feature
		var colour := Color(1.0, 0.8, 0.35, 0.9) if selected else Color(0.45, 0.8, 1.0, 0.45)
		draw_rect(Rect2(start, extent), colour, false, 2.0 if selected else 1.0)
		if extent.x > 75 and extent.y > 24:
			draw_string(font, start + Vector2(3, 14), str(feature.get("kind", "feature")), HORIZONTAL_ALIGNMENT_LEFT, extent.x - 6, 11, colour)
	var checked: Dictionary = {}
	for route: Dictionary in route_report.get("routes", []): checked[str(route.id)] = bool(route.get("passed", false))
	for route: Dictionary in semantic_plan.get("routes", []):
		var points := PackedVector2Array()
		for point: Array in route.get("points", []): points.append(Vector2(float(point[0]), float(point[1])))
		var colour := Color(0.65, 0.68, 0.75, 0.8)
		if checked.has(str(route.id)): colour = Color(0.35, 1.0, 0.65, 0.9) if checked[str(route.id)] else Color(1.0, 0.25, 0.25, 0.95)
		_draw_path(points, colour, 2.0 if route.get("required", false) else 1.0)
	for socket: Dictionary in semantic_plan.get("sockets", []):
		var point := Vector2(float(socket.x), float(socket.y))
		if not view.has_point(point): continue
		var position: Vector2 = world_to_screen(point)
		var colour := Color(0.4, 1.0, 0.75) if not str(socket.get("matched", "")).is_empty() or socket.get("shared", false) else Color(1.0, 0.4, 0.2)
		draw_circle(position, 3.0, colour)
		var direction: Vector2 = {"north":Vector2.UP, "south":Vector2.DOWN, "west":Vector2.LEFT, "east":Vector2.RIGHT}.get(str(socket.get("direction", "")), Vector2.ZERO)
		draw_line(position, position + direction * 8, colour, 1.5)
	_overlay_notice("Base routes: green pass / red fail / grey unchecked; projected-plane clearance is unchecked.")

func _vector_at(point: Vector2) -> Dictionary:
	var x: int = floori(point.x)
	var y: int = floori(point.y)
	var coordinate := Vector2i(floori(float(x) / chunk_size), floori(float(y) / chunk_size))
	if not chunks.has(coordinate): return {"ok":false}
	var packet: Dictionary = chunks[coordinate]
	if str(packet.get("diagnostic_info", {}).get("type", "")) != "vector2": return {"ok":false}
	var index: int = (y - coordinate.y * chunk_size) * chunk_size + x - coordinate.x * chunk_size
	var values: PackedFloat64Array = packet.get("diagnostic_values", PackedFloat64Array())
	if index < 0 or index * 2 + 1 >= values.size(): return {"ok":false}
	var x_value: float = values[index * 2]
	var y_value: float = values[index * 2 + 1]
	var scale: float = maxf(absf(x_value), absf(y_value))
	if scale <= 0.0: return {"ok":true, "value":Vector2.ZERO}
	# Normalize double components before entering Godot's float Vector2 so a
	# finite 1e60 native vector cannot overflow the visualization carrier.
	return {"ok":true, "value":Vector2(x_value / scale, y_value / scale)}

func _overlay_notice(message: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var start: Vector2 = content_rect().position + Vector2(8, 18)
	draw_style_box(_notice_box(), Rect2(start - Vector2(5, 14), Vector2(minf(content_rect().size.x - 8, 620), 24)))
	draw_string(font, start, message, HORIZONTAL_ALIGNMENT_LEFT, content_rect().size.x - 16, 12, Color(0.9, 0.95, 1))

func _notice_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	return style

func _draw_vectors() -> void:
	if not diagnostic_channel.begins_with("spatial:"):
		_overlay_notice("Select a native vector2 spatial diagnostic for arrows.")
		return
	var step: float = maxf(4.0, maxf(view_size.x, view_size.y) / 16.0)
	var count: int = 0
	var y: float = camera_origin.y + step * 0.5
	while y < camera_origin.y + view_size.y and count < MAX_VECTOR_ARROWS:
		var x: float = camera_origin.x + step * 0.5
		while x < camera_origin.x + view_size.x and count < MAX_VECTOR_ARROWS:
			var sample: Dictionary = _vector_at(Vector2(x, y))
			if sample.get("ok", false) and sample.value.length_squared() > 0.000001:
				var start: Vector2 = world_to_screen(Vector2(x, y))
				var delta: Vector2 = sample.value.normalized() * minf(step * content_rect().size.x / view_size.x * 0.4, 18)
				var finish: Vector2 = start + delta
				draw_line(start, finish, Color(1, 1, 0.75), 1.3)
				draw_line(finish, finish - delta.rotated(0.55) * 0.3, Color(1, 1, 0.75), 1.3)
				draw_line(finish, finish - delta.rotated(-0.55) * 0.3, Color(1, 1, 0.75), 1.3)
				count += 1
			x += step
		y += step
	_overlay_notice("%d/%d arrows · native samples; display lengths normalized" % [count, MAX_VECTOR_ARROWS])

func _draw_streamlines() -> void:
	var lines: int = 0
	var points: int = 0
	var view := Rect2(camera_origin, view_size)
	var step: float = maxf(1, minf(view_size.x, view_size.y) / 96)
	for seed: int in range(MAX_STREAMLINES):
		var point := camera_origin + Vector2(float(seed % 6 + 1) / 7.0 * view_size.x, float(seed / 6 + 1) / 5.0 * view_size.y)
		var line := PackedVector2Array([point])
		for _iteration: int in range(MAX_STREAMLINE_STEPS):
			var sample: Dictionary = _vector_at(point)
			if not sample.get("ok", false) or sample.value.length_squared() < 0.000001: break
			point += sample.value.normalized() * step
			if not view.has_point(point): break
			line.append(point)
		if line.size() > 1:
			_draw_path(line, Color(0.95, 1, 0.7, 0.8), 1.1)
			lines += 1
			points += line.size()
	_overlay_notice("%d/%d streamlines · %d points · native cached vectors; bounded display integration" % [lines, MAX_STREAMLINES, points])

func _draw_density() -> void:
	var bins: Array[int] = []
	bins.resize(16 * 16)
	bins.fill(0)
	var view := Rect2(camera_origin, view_size)
	for feature: Dictionary in semantic_plan.get("features", []):
		var bounds: Array = feature.get("bounds", [])
		if bounds.size() != 4: continue
		var center := Vector2(float(bounds[0]) + float(bounds[2]) * 0.5, float(bounds[1]) + float(bounds[3]) * 0.5)
		if not view.has_point(center): continue
		var local: Vector2 = (center - camera_origin) / view_size * 16.0
		bins[clampi(int(local.y), 0, 15) * 16 + clampi(int(local.x), 0, 15)] += 1
	var maximum: int = 1
	for count: int in bins: maximum = maxi(maximum, count)
	for index: int in range(bins.size()):
		if bins[index] == 0: continue
		var position := camera_origin + Vector2(index % 16, index / 16) * view_size / 16
		var rect := Rect2(world_to_screen(position), content_rect().size / 16)
		var value: float = float(bins[index]) / maximum
		draw_rect(rect, Color(value, 0.45, 1.0 - value, 0.6))
	_overlay_notice("Feature centres per 16×16 viewport bin · actual copied semantic records · peak %d" % maximum)

func _draw_cost() -> void:
	var key: String = "compute_usec" if extra_overlay == 5 else "operations"
	var maximum: float = 1.0
	for entry: Dictionary in chunks.values(): maximum = maxf(maximum, float(entry.get(key, 0)))
	var view := Rect2(camera_origin, view_size)
	for coordinate: Vector2i in chunks:
		var rect := Rect2(Vector2(coordinate) * chunk_size, Vector2.ONE * chunk_size)
		if not view.intersects(rect): continue
		var value: float = float(chunks[coordinate].get(key, 0))
		var clipped: Rect2 = rect.intersection(view)
		draw_rect(Rect2(world_to_screen(clipped.position), clipped.size * content_rect().size / view_size), Color(value / maximum, 0.25, 1.0 - value / maximum, 0.65))
		var label: String = "%.2f ms" % (value / 1000.0) if extra_overlay == 5 else "%.0f ops" % value
		draw_string(ThemeDB.fallback_font, world_to_screen(clipped.position) + Vector2(5, 35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	_overlay_notice("Measured native calls per chunk (local host)" if extra_overlay == 5 else "Conservative logical work charged per chunk; not measured instructions")
