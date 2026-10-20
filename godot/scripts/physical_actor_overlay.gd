class_name CyberPhysicalActorOverlay
extends Control

# Filled polygons use the actual rectangle collision shape and the bridge's
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
