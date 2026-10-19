class_name CyberUsableOverlay
extends Control

var _context: Dictionary = {}
var _origin: Vector2 = Vector2.ZERO
var _view_size: Vector2i = Vector2i(320, 180)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)

func present(context: Dictionary, origin: Vector2, view_size: Vector2i, content_rect: Rect2) -> void:
	_context = context.duplicate(true)
	_origin = origin.floor()
	_view_size = view_size
	position = content_rect.position
	size = content_rect.size
	visible = not context.is_empty() and content_rect.size.x > 0.0 and content_rect.size.y > 0.0
	queue_redraw()

func world_to_overlay(point: Vector2) -> Vector2:
	if _view_size.x <= 0 or _view_size.y <= 0:
		return Vector2.ZERO
	return (point - _origin) * size / Vector2(_view_size)

func _draw() -> void:
	if _context.is_empty():
		return
	for p in _context.get("projectiles", []):
		if not p is Dictionary:
			continue
		var at: Vector2 = world_to_overlay(p.get("position", Vector2.ZERO))
		var color: Color = p.get("color", Color.WHITE)
		draw_circle(at, 2.2, color)
		var velocity: Vector2 = p.get("velocity", Vector2.ZERO)
		if velocity.length_squared() > 0.001:
			draw_line(at, at - velocity.normalized() * 8.0, color, 1.0)
	for obj in _context.get("objects", []):
		if not obj is Dictionary:
			continue
		var at: Vector2 = world_to_overlay(obj.get("position", Vector2.ZERO))
		var color: Color = obj.get("color", Color(0.7,0.8,0.9))
		var scale: Vector2 = size / Vector2(_view_size)
		var physical: bool = obj.has("body_id") and obj.has("half_extents")
		var rotation: float = float(obj.get("rotation", 0.0)) if physical else 0.0
		var offset: float = ceilf(Vector2(obj.half_extents).x + 2.0) if physical else 2.0
		if physical:
			var status: String = str(obj.get("status", "waiting"))
			var indicator := Color(0.4, 0.95, 0.65) if status == "processed" else Color(1.0, 0.65, 0.2)
			if status in ["output-blocked", "blocked-output", "blocked", "jammed"]:
				indicator = Color(1.0, 0.25, 0.2)
			draw_arc(at, maxf(3.0, Vector2(obj.half_extents).length() * scale.x + 2.0), 0, TAU, 20, indicator, 1.2)
		else:
			var half := Vector2(2.5 * scale.x, 2.5 * scale.y)
			draw_rect(Rect2(at - half, half * 2.0), color, false, 1.2)
		var input_a: Vector2 = world_to_overlay(Vector2(obj.position) + Vector2(-offset,-1.0).rotated(rotation))
		var input_b: Vector2 = world_to_overlay(Vector2(obj.position) + Vector2(-offset,1.0).rotated(rotation))
		var output_a: Vector2 = world_to_overlay(Vector2(obj.position) + Vector2(offset,-1.0).rotated(rotation))
		var output_b: Vector2 = world_to_overlay(Vector2(obj.position) + Vector2(offset,1.0).rotated(rotation))
		draw_circle(input_a, 1.5, Color(0.45,0.9,1.0))
		draw_circle(input_b, 1.5, Color(0.45,0.9,1.0))
		draw_circle(output_a, 1.5, Color(1.0,0.72,0.3))
		draw_circle(output_b, 1.5, Color(1.0,0.72,0.3))
	for effect in _context.get("effects", []):
		if not effect is Dictionary:
			continue
		var ttl: float = maxf(0.001, float(effect.get("ttl",0.2)))
		var life: float = 1.0 - clampf(float(effect.get("age",0.0)) / ttl, 0.0, 1.0)
		var radius: float = maxf(1.0, float(effect.get("radius",2.0))) * (size.x / maxf(1.0,float(_view_size.x)))
		var color: Color = effect.get("color", Color.WHITE)
		color.a *= life
		draw_arc(world_to_overlay(effect.get("position",Vector2.ZERO)), radius, 0.0, TAU, 16, color, 1.2)
