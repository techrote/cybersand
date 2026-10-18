class_name CyberActorPrototypeOverlay
extends Control

# Bounded presentation of owner-published sampled actors. It reads no World,
# creates no physics objects, and never infers collisions from the display.
const STRIDE: int = 16
const COLORS: Array[Color] = [Color(0.24, 0.9, 0.96), Color(0.91, 0.45, 1.0), Color(1.0, 0.67, 0.25)]
var _states: PackedFloat32Array = PackedFloat32Array()
var _origin: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2(320, 180)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)


func present(context: Dictionary, origin: Vector2, view_size: Vector2i, content_rect: Rect2) -> void:
	_states = context.get("states", PackedFloat32Array())
	_origin = origin.floor()
	_view_size = Vector2(view_size)
	# Same aspect-fit inset and integer camera origin as terrain/pointer mapping.
	position = content_rect.position
	size = content_rect.size
	visible = not _states.is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	if _view_size.x <= 0.0 or _view_size.y <= 0.0:
		return
	var scale_pixels: Vector2 = size / _view_size
	for index: int in range(mini(_states.size() / STRIDE, 8)):
		var offset: int = index * STRIDE
		var point: Vector2 = (Vector2(_states[offset], _states[offset + 1]) - _origin) * scale_pixels
		var body_size: Vector2 = CyberSampledCharacter.BODY_SIZE * scale_pixels
		var rect: Rect2 = Rect2(point, body_size)
		if not rect.intersects(Rect2(Vector2.ZERO, size)):
			continue
		var model: int = clampi(int(_states[offset + 13]), 0, 2)
		var color: Color = COLORS[model]
		if _states[offset + 5] > 0.5:
			color = color.darkened(0.4)
		draw_rect(rect, Color(0.035, 0.05, 0.08))
		draw_rect(Rect2(point + scale_pixels, body_size - 2.0 * scale_pixels), color.darkened(0.45))
		var visor_y: float = 3.0 if model != 2 else 6.0
		draw_rect(Rect2(point + Vector2(1, visor_y) * scale_pixels, Vector2(6, 2) * scale_pixels), color)
		var foot_width: float = 3.0 if model == 2 else 2.0
		draw_rect(Rect2(point + Vector2(0, 12) * scale_pixels, Vector2(foot_width, 2) * scale_pixels), color)
		draw_rect(Rect2(point + Vector2(8 - foot_width, 12) * scale_pixels,
			Vector2(foot_width, 2) * scale_pixels), color)
		if model == 1 and _states[offset + 6] > 0.0:
			draw_rect(Rect2(point + Vector2(2, 14) * scale_pixels, Vector2(4, 1) * scale_pixels), color)
		if index == 0:
			draw_rect(rect.grow(1.0), Color(0.93, 0.99, 1.0), false, 1.0)
		var energy: float = clampf(_states[offset + 6], 0.0, 1.0)
		draw_rect(Rect2(point - Vector2(0, 3) * scale_pixels,
			Vector2(8.0 * energy, 1.0) * scale_pixels), color)
