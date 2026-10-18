class_name CyberActorPrototypeOverlay
extends Control

# Bounded presentation of immutable owner-published rigs. No World/Input reads,
# articulated bodies or presentation-derived collisions live here.
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const STRIDE: int = 16
const RIG_STRIDE: int = 40
const MAX_ACTORS: int = 8
var _states: PackedFloat32Array = PackedFloat32Array()
var _rig_states: PackedFloat32Array = PackedFloat32Array()
var _origin: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2(320, 180)
var _definitions: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)


func present(context: Dictionary, origin: Vector2, view_size: Vector2i, content_rect: Rect2) -> void:
	_states = context.get("states", PackedFloat32Array())
	_rig_states = context.get("rig_states", PackedFloat32Array())
	_origin = origin.floor()
	_view_size = Vector2(view_size)
	position = content_rect.position
	size = content_rect.size
	visible = not _states.is_empty()
	if _definitions.is_empty():
		for rig_id: StringName in Catalog.RIG_IDS:
			_definitions.append(Catalog.entry(rig_id))
	if visible:
		queue_redraw()


func world_to_overlay(point: Vector2) -> Vector2:
	if _view_size.x <= 0.0 or _view_size.y <= 0.0:
		return Vector2.ZERO
	return (point - _origin) * size / _view_size


func _value(index: int, field: int) -> float:
	if index < 0 or index >= MAX_ACTORS:
		return 0.0
	if _rig_states.size() >= (index + 1) * RIG_STRIDE:
		return _rig_states[index * RIG_STRIDE + field]
	if field < STRIDE and _states.size() >= (index + 1) * STRIDE:
		return _states[index * STRIDE + field]
	if field == 35:
		return CyberSampledCharacter.BODY_SIZE.x
	if field == 36:
		return CyberSampledCharacter.BODY_SIZE.y
	return 0.0


func _dimensions(index: int) -> Vector2:
	return Vector2(_value(index, 35), _value(index, 36))


func _centre(index: int) -> Vector2:
	return Vector2(_value(index, 0), _value(index, 1)) + _dimensions(index) * 0.5


func _local_point(index: int, unit: Vector2) -> Vector2:
	return world_to_overlay(_centre(index) + (unit * _dimensions(index)).rotated(_value(index, 16)))


func body_polygon(index: int) -> PackedVector2Array:
	return PackedVector2Array([
		_local_point(index, Vector2(-0.5, -0.5)), _local_point(index, Vector2(0.5, -0.5)),
		_local_point(index, Vector2(0.5, 0.5)), _local_point(index, Vector2(-0.5, 0.5)),
	])


func anchor_line(index: int) -> PackedVector2Array:
	var mode: int = int(_value(index, 20))
	if mode != 2 and mode != 3 and mode != 4:
		return PackedVector2Array()
	return PackedVector2Array([world_to_overlay(_centre(index)),
		world_to_overlay(Vector2(_value(index, 21), _value(index, 22)))])


func _line(index: int, first: Vector2, last: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(_local_point(index, first), _local_point(index, last), color, width)


func _hull(index: int, units: PackedVector2Array, color: Color) -> void:
	var polygon: PackedVector2Array = PackedVector2Array()
	polygon.resize(units.size())
	for vertex: int in range(units.size()):
		polygon[vertex] = _local_point(index, units[vertex])
	draw_colored_polygon(polygon, color.darkened(0.58))
	polygon.append(polygon[0])
	draw_polyline(polygon, color, 1.0)


func _draw() -> void:
	if _view_size.x <= 0.0 or _view_size.y <= 0.0:
		return
	var scale_pixels: Vector2 = size / _view_size
	for index: int in range(mini(_states.size() / STRIDE, MAX_ACTORS)):
		var rig_index: int = clampi(int(_value(index, 13)), 0, Catalog.RIG_IDS.size() - 1)
		var definition: Dictionary = _definitions[rig_index]
		var color: Color = definition.color
		if _value(index, 5) > 0.5:
			color = color.darkened(0.4)
		var rope: PackedVector2Array = anchor_line(index)
		if not rope.is_empty():
			var rope_color: Color = color.lerp(Color.WHITE, clampf(_value(index, 24), 0.0, 1.0) * 0.6)
			draw_line(rope[0], rope[1], rope_color, 1.5 if int(_value(index, 20)) == 3 else 1.0)
			draw_line(rope[1] - Vector2(3, 0), rope[1] + Vector2(3, 0), rope_color)
			draw_line(rope[1] - Vector2(0, 3), rope[1] + Vector2(0, 3), rope_color)
		if _value(index, 31) > 0.0:
			var effect_center: Vector2 = world_to_overlay(Vector2(_value(index, 32), _value(index, 33)))
			var effect_color: Color = Color(1.0, 0.67, 0.2, 0.8) if int(_value(index, 31)) == 2 else color
			draw_arc(effect_center, maxf(1.0, _value(index, 37) * scale_pixels.x), 0.0, TAU, 16, effect_color, 1.0)
		var bounds: PackedVector2Array = body_polygon(index)
		var screen_bounds: Rect2 = Rect2(bounds[0], Vector2.ZERO)
		for vertex: Vector2 in bounds:
			screen_bounds = screen_bounds.expand(vertex)
		if not screen_bounds.grow(8.0).intersects(Rect2(Vector2.ZERO, size)):
			continue
		_draw_shape(index, StringName(str(definition.visual)), color)
		if _value(index, 20) == 1.0:
			var normal: Vector2 = Vector2(_value(index, 18), _value(index, 19))
			draw_line(world_to_overlay(_centre(index)), world_to_overlay(_centre(index) - normal * 6.0), color.lightened(0.6), 2.0)
		if index == 0:
			bounds.append(bounds[0])
			draw_polyline(bounds, Color(0.93, 0.99, 1.0, 0.75), 1.0)
		var bar_origin: Vector2 = Vector2(screen_bounds.position.x, screen_bounds.position.y - 4.0)
		var bar_width: float = maxf(8.0, screen_bounds.size.x)
		draw_rect(Rect2(bar_origin, Vector2(bar_width, 2.0)), Color(0.02, 0.03, 0.05, 0.85))
		draw_rect(Rect2(bar_origin, Vector2(bar_width * clampf(_value(index, 6), 0.0, 1.0), 2.0)), color)
		if _value(index, 25) > 0.0:
			draw_rect(Rect2(bar_origin - Vector2(0, 3), Vector2(bar_width * clampf(_value(index, 25), 0.0, 1.0), 1.0)), Color(1.0, 0.91, 0.59))


func _draw_shape(index: int, visual: StringName, color: Color) -> void:
	var phase: float = sin(_value(index, 39) * TAU) * 0.06
	match visual:
		&"tripod":
			_hull(index, PackedVector2Array([Vector2(-0.28, -0.28), Vector2(0.28, -0.28), Vector2(0.3, 0.12), Vector2(-0.3, 0.12)]), color)
			# Exactly three authored legs, all contained in the sampled hull.
			_line(index, Vector2(-0.2, 0), Vector2(-0.5, 0.43 + phase), color, 2.0)
			_line(index, Vector2(0, 0.05), Vector2(phase, 0.5), color, 2.0)
			_line(index, Vector2(0.2, 0), Vector2(0.5, 0.43 - phase), color, 2.0)
		&"tracks", &"crawler":
			_hull(index, PackedVector2Array([Vector2(-0.45, -0.32), Vector2(0.35, -0.32), Vector2(0.5, 0.25), Vector2(-0.5, 0.25)]), color)
			_line(index, Vector2(-0.45, 0.4), Vector2(0.45, 0.4), color, 3.0)
			for tread: int in range(4):
				var x: float = -0.35 + float(tread) * 0.23 + phase * 0.4
				_line(index, Vector2(x, 0.3), Vector2(x, 0.5), color.lightened(0.3))
		&"hover":
			_hull(index, PackedVector2Array([Vector2(-0.4, -0.35), Vector2(0.4, -0.35), Vector2(0.5, 0.15), Vector2(-0.5, 0.15)]), color)
			_line(index, Vector2(-0.35, 0.4), Vector2(0.35, 0.4), color.lightened(0.3), 2.0)
		&"drill", &"blade", &"rocket":
			_hull(index, PackedVector2Array([Vector2(-0.38, -0.45), Vector2(0.38, -0.45), Vector2(0.28, 0.18), Vector2(0, 0.5), Vector2(-0.28, 0.18)]), color)
			_line(index, Vector2(-0.25, -0.25), Vector2(0.25, 0.05), color.lightened(0.5), 2.0)
			_line(index, Vector2(-0.25, 0.02), Vector2(0.22, 0.25), color)
		&"rotor", &"twin_rotor":
			_hull(index, PackedVector2Array([Vector2(-0.26, -0.05), Vector2(0.26, -0.05), Vector2(0.35, 0.4), Vector2(-0.35, 0.4)]), color)
			_line(index, Vector2(-0.5, -0.25), Vector2(0.5, -0.25), color, 2.0)
			if visual == &"twin_rotor":
				_line(index, Vector2(-0.3, -0.45), Vector2(-0.3, 0), color.lightened(0.4))
				_line(index, Vector2(0.3, -0.45), Vector2(0.3, 0), color.lightened(0.4))
			else:
				_line(index, Vector2(phase * 3.0, -0.45), Vector2(phase * -3.0, -0.1), color.lightened(0.4))
		&"quadruped", &"climber":
			_hull(index, PackedVector2Array([Vector2(-0.25, -0.4), Vector2(0.25, -0.4), Vector2(0.3, 0.3), Vector2(-0.3, 0.3)]), color)
			for side: int in [-1, 1]:
				_line(index, Vector2(side * 0.18, -0.12), Vector2(side * 0.5, -0.35 + side * phase), color, 2.0)
				_line(index, Vector2(side * 0.18, 0.17), Vector2(side * 0.47, 0.44 - side * phase), color, 2.0)
		&"wheel", &"winch":
			_hull(index, PackedVector2Array([Vector2(-0.35, -0.5), Vector2(0.35, -0.5), Vector2(0.5, -0.3), Vector2(0.5, 0.3), Vector2(0.3, 0.5), Vector2(-0.3, 0.5), Vector2(-0.5, 0.3), Vector2(-0.5, -0.3)]), color)
			_line(index, Vector2(-0.35, -0.35), Vector2(0.35, 0.35), color)
			_line(index, Vector2(0.35, -0.35), Vector2(-0.35, 0.35), color)
		&"piston", &"bellows":
			_hull(index, PackedVector2Array([Vector2(-0.35, -0.45), Vector2(0.35, -0.45), Vector2(0.4, 0.4), Vector2(-0.4, 0.4)]), color)
			for pleat: int in range(4):
				var y: float = -0.3 + float(pleat) * 0.19
				_line(index, Vector2(-0.34, y), Vector2(0.34, y + 0.08), color.lightened(0.25))
		&"sail":
			_hull(index, PackedVector2Array([Vector2(-0.35, 0.32), Vector2(0, -0.5), Vector2(0.45, 0.32)]), color)
			_line(index, Vector2(-0.5, 0.46), Vector2(0.5, 0.46), color, 2.0)
		_:
			_hull(index, PackedVector2Array([Vector2(-0.35, -0.45), Vector2(0.35, -0.45), Vector2(0.35, 0.2), Vector2(-0.35, 0.2)]), color)
			_line(index, Vector2(-0.2, 0.15), Vector2(-0.32, 0.5), color, 2.0)
			_line(index, Vector2(0.2, 0.15), Vector2(0.32, 0.5), color, 2.0)
			if visual == &"jet" and _value(index, 6) > 0.0:
				_line(index, Vector2(-0.4, 0.12), Vector2(-0.45, 0.43), Color(1.0, 0.7, 0.3), 2.0)
				_line(index, Vector2(0.4, 0.12), Vector2(0.45, 0.43), Color(1.0, 0.7, 0.3), 2.0)
	# A common bright facing mark makes every silhouette readable when tumbling.
	var facing: float = _value(index, 12)
	_line(index, Vector2(facing * 0.06, -0.18), Vector2(facing * 0.28, -0.18), color.lightened(0.6), 2.0)
