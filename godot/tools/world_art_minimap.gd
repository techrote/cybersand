extends Control
## Aspect-correct navigation overview for the presentation-only World Art Preview.
## Draws geometry, not an extra raster copy of the material-cell world.
signal navigate_requested(world_centre: Vector2)

const INSET: float = 9.0

var native_size := Vector2i.ONE
var view_origin := Vector2.ZERO
var view_size := Vector2.ONE
var _dragging := false


func _map_rect() -> Rect2:
	var room: Vector2 = (size - Vector2.ONE * (INSET * 2.0)).max(Vector2.ONE)
	var world: Vector2 = Vector2(native_size.max(Vector2i.ONE))
	var factor: float = minf(room.x / world.x, room.y / world.y)
	var dimensions: Vector2 = world * factor
	return Rect2((size - dimensions) * 0.5, dimensions)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.051, 0.068, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.45, 0.54), false, 1.0)
	if native_size.x <= 0 or native_size.y <= 0:
		return
	var frame: Rect2 = _map_rect()
	draw_rect(frame, Color(0.14, 0.20, 0.25, 1.0))
	draw_rect(frame, Color(0.61, 0.73, 0.80, 1.0), false, 1.0)
	var dimensions: Vector2 = Vector2(native_size)
	var upper_left: Vector2 = (view_origin / dimensions).clamp(Vector2.ZERO, Vector2.ONE)
	var lower_right: Vector2 = ((view_origin + view_size) / dimensions).clamp(Vector2.ZERO, Vector2.ONE)
	var visible: Vector2 = (lower_right - upper_left).max(Vector2.ZERO)
	if visible.x > 0.0 and visible.y > 0.0:
		var indicator := Rect2(frame.position + upper_left * frame.size, visible * frame.size)
		draw_rect(indicator, Color(0.48, 0.84, 0.95, 0.22))
		draw_rect(indicator, Color(0.48, 0.84, 0.95, 1.0), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse.pressed
			if mouse.pressed:
				_request_navigate(mouse.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		_request_navigate(motion.position)
		accept_event()


func _request_navigate(local_position: Vector2) -> void:
	if native_size.x <= 0 or native_size.y <= 0:
		return
	var frame: Rect2 = _map_rect()
	var uv: Vector2 = ((local_position - frame.position) / frame.size).clamp(Vector2.ZERO, Vector2.ONE)
	navigate_requested.emit(uv * Vector2(native_size))
