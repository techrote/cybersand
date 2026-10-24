class_name CyberPhysicalActorOverlay
extends Control

# Filled polygons use the actual rectangle or circle shape and the bridge's
# authoritative physics transform. This node owns no gameplay or collision.
var outlines: bool = true
var _parts: Array = []
var _origin: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func present(parts: Array, origin: Vector2, view_size: Vector2i, content: Rect2) -> void:
	_parts = parts.duplicate(true)
	_origin = origin.floor()
	_view_size = Vector2(view_size)
	position = content.position
	size = content.size
	visible = not _parts.is_empty()
	queue_redraw()


func polygon(part: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var half: Vector2 = part.size * 0.5
	var transform: Transform2D = part.transform
	var corners := PackedVector2Array()
	if str(part.get("shape", "rectangle")) == "circle":
		for index: int in range(24):
			corners.append(Vector2.from_angle(float(index) * TAU / 24.0) * half.x)
	else:
		corners = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	for corner: Vector2 in corners:
		result.append((transform * corner - _origin) * size / _view_size)
	return result


func _draw() -> void:
	if _view_size.x <= 0.0 or _view_size.y <= 0.0:
		return
	for part: Dictionary in _parts:
		var vertices: PackedVector2Array = polygon(part)
		var color: Color = part.color
		draw_colored_polygon(vertices, color.darkened(0.18))
		if outlines:
			vertices.append(vertices[0])
			draw_polyline(vertices, color.lightened(0.35), 1.0, false)
		# Cues derive exclusively from the admitted/applied actuator receipt
		# and the real Rapier transform. They never integrate a separate pose.
		if bool(part.get("flight_live", false)):
			var centre: Vector2 = (part.transform.origin - _origin) * size / _view_size
			var force: Vector2 = part.get("flight_force", Vector2.ZERO)
			if force.length_squared() > 1.0:
				draw_line(centre, centre - force.normalized() * clampf(force.length() * 0.025, 2.0, 10.0),
					color.lightened(0.5), 2.0, true)
			var intent: Vector2 = part.get("flight_intent", Vector2.ZERO)
			if intent.length_squared() > 1.0:
				draw_line(centre, centre + intent.normalized() * clampf(intent.length() * 0.075, 2.0, 6.0),
					color.darkened(0.55), 1.0, true)
