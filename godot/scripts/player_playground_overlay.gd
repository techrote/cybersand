extends "res://scripts/physical_actor_overlay.gd"

var targets := PackedVector2Array()
var target_index: int = 0
var accent := Color("7be5ff")
var actor_position := Vector2.ZERO
var material_field: bool = false
var field_radius: float = 32.0
var movement: Dictionary = {}
var preset: StringName = &""


func _point(world: Vector2) -> Vector2:
	return (world - _origin) * size / _view_size


func _draw() -> void:
	if _view_size.x <= 0 or _view_size.y <= 0:
		return
	# Quiet world-space grid and labelled obstacles stay underneath live bodies.
	for x: int in range(128, 641, 32):
		draw_line(_point(Vector2(x, 128)), _point(Vector2(x, 384)), Color(0.23, 0.42, 0.52, 0.10), 1.0)
	for y: int in range(128, 385, 32):
		draw_line(_point(Vector2(128, y)), _point(Vector2(640, y)), Color(0.23, 0.42, 0.52, 0.10), 1.0)
	for index: int in range(targets.size()):
		var point: Vector2 = _point(targets[index])
		var radius: float = 13.0 * size.x / _view_size.x
		var color: Color = accent if index == target_index else Color(0.5, 0.65, 0.72, 0.24)
		if index < target_index:
			color = Color(0.5, 0.95, 0.7, 0.55)
		draw_arc(point, radius, 0.0, TAU, 40, color, 2.0, true)
		var label: String = str(index + 1) if index >= target_index else "✓"
		draw_string(ThemeDB.fallback_font, point + Vector2(-4, -radius - 7), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, color)
	if material_field:
		var point: Vector2 = _point(actor_position)
		draw_arc(point, field_radius * size.x / _view_size.x, 0.0, TAU, 64, Color(accent, 0.20), 1.0, true)
		draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), Color(accent, 0.7), 1.0)
		draw_line(point + Vector2(0, -5), point + Vector2(0, 5), Color(accent, 0.7), 1.0)
	# Exhaust is a presentation cue driven by accepted controller telemetry.
	# It never adds a collider or changes the authoritative physical hull.
	if preset in [&"arcadelander", &"jetbarrel"]:
		for part: Dictionary in _parts:
			if str(part.part_id) in ["chassis", "barrel"]:
				var thrust: float = float(movement.get("thrust", 0.0))
				if absf(thrust) > 0.01:
					var pose: Transform2D = part.transform
					var base: float = Vector2(part.size).y * 0.5 * signf(thrust)
					var tip: float = base + signf(thrust) * (5.0 + 7.0 * absf(thrust))
					draw_colored_polygon(PackedVector2Array([_point(pose * Vector2(-2.1, base)),
						_point(pose * Vector2(2.1, base)), _point(pose * Vector2(0, tip))]), Color("ff9855"))
					draw_colored_polygon(PackedVector2Array([_point(pose * Vector2(-1.0, base)),
						_point(pose * Vector2(1.0, base)), _point(pose * Vector2(0, lerpf(base, tip, 0.55)))]), Color("e9faff"))
	super._draw()
	# A spoke makes actual wheel rotation legible without hiding its collider.
	for part: Dictionary in _parts:
		if str(part.get("shape", "")) == "circle":
			var pose: Transform2D = part.transform
			var radius: float = Vector2(part.size).x * 0.42
			draw_line(_point(pose.origin), _point(pose * Vector2(radius, 0)), Color(1, 1, 1, 0.65), 1.5, true)
		elif preset == &"jetbarrel" and str(part.part_id) == "barrel":
			var pose: Transform2D = part.transform
			var half: Vector2 = Vector2(part.size) * 0.5
			for band: float in [-0.62, 0.62]:
				draw_line(_point(pose * Vector2(-half.x, half.y * band)),
					_point(pose * Vector2(half.x, half.y * band)), Color("405364"), 2.0, true)
			draw_line(_point(pose * Vector2(-half.x * 0.55, -half.y * 0.85)),
				_point(pose * Vector2(-half.x * 0.55, half.y * 0.85)), Color(1, 0.9, 0.65, 0.55), 1.0, true)
