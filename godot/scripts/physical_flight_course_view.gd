class_name CyberPhysicalFlightCourseView
extends Control

# Presentation ONLY: course geometry and body poses come from the native course
# and actual Rapier bridge. No drawing pose feeds the plant or a policy.
const Course = preload("res://scripts/physical_flight_course.gd")
var episode: CyberPhysicalFlightEpisode


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(640.0, 410.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _point(world: Vector2) -> Vector2:
	var bounds: Rect2i = Course.ARENA
	var unit: float = minf((size.x - 48.0) / float(bounds.size.x),
		(size.y - 48.0) / float(bounds.size.y))
	var shift: Vector2 = (size - Vector2(bounds.size) * unit) * 0.5
	return shift + (world - Vector2(bounds.position)) * unit


func _scale() -> float:
	return minf((size.x - 48.0) / float(Course.ARENA.size.x),
		(size.y - 48.0) / float(Course.ARENA.size.y))


func _draw() -> void:
	var a: Vector2 = _point(Vector2(Course.ARENA.position))
	var unit: float = _scale()
	draw_rect(Rect2(a, Vector2(Course.ARENA.size) * unit), Color(0.065, 0.10, 0.15), true)
	if episode == null or episode.scenario.is_empty():
		return
	var info: Dictionary = episode.scenario
	for rectangle: Dictionary in Course.layout(str(info.id), int(info.seed), str(info.split)):
		var top_left: Vector2 = _point(Vector2(rectangle.origin))
		draw_rect(Rect2(top_left, Vector2(rectangle.size) * unit), Color(0.35, 0.44, 0.54), true)
	var start: Vector2 = _point(Vector2(info.start))
	draw_circle(start, 5.0, Color(0.42, 0.79, 0.96))
	var goal: Vector2 = episode.active_goal()
	if goal.is_finite():
		var goal_draw: Vector2 = _point(goal)
		var radius: float = float(info.arrival_radius) * unit
		draw_arc(goal_draw, radius, 0.0, TAU, 48, Color(0.41, 0.96, 0.61), 2.5, true)
		draw_circle(goal_draw, 2.5, Color(0.41, 0.96, 0.61))
	for part: Dictionary in episode.arena.render_parts():
		var dimensions: Vector2 = Vector2(part.size)
		var body_transform: Transform2D = part.transform
		var half: Vector2 = dimensions * 0.5
		var vertices := PackedVector2Array()
		for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			vertices.append(_point(body_transform * corner))
		draw_colored_polygon(vertices, Color(0.99, 0.66, 0.27))
		vertices.append(vertices[0])
		draw_polyline(vertices, Color(1.0, 0.91, 0.67), 2.0, true)
		var view: Dictionary = episode.observe()
		var velocity: Vector2 = view.get("velocity_cells_per_second", Vector2.ZERO)
		var centre: Vector2 = body_transform.origin
		draw_line(_point(centre), _point(centre + velocity * 0.25),
			Color(0.42, 0.92, 1.0), 2.0, true)
