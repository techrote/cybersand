extends "res://scripts/player_playground_overlay.gd"

# Targets only. Main supplies an already fenced copy of lap progress; this
# renderer never advances a checkpoint, queries Rapier or reads a native World.
const Course = preload("res://scripts/player_playground_course.gd")
var course_identity: Dictionary = {}


func present_course(identity: Dictionary, origin: Vector2, view_size: Vector2i, content: Rect2) -> void:
	var rig := StringName(str(identity.get("rig", "")))
	if rig not in Course.MECHANICAL_PRESETS or int(identity.get("actor_epoch", -1)) < 0 \
		or int(identity.get("world_generation", -1)) < 0 or int(identity.get("source_tick", -1)) < 0 \
		or int(identity.get("physics_tick", -1)) < 0 or view_size.x <= 0 or view_size.y <= 0 \
		or content.size.x <= 0.0 or content.size.y <= 0.0 or not origin.is_finite():
		clear_course()
		return
	var points: PackedVector2Array = Course.checkpoints(rig)
	var completed: int = int(identity.get("target_index", -1))
	if completed < 0 or completed > points.size():
		clear_course()
		return
	course_identity = identity.duplicate(true)
	targets = points
	target_index = completed
	accent = Course.COLORS[Course.PRESETS.find(rig)]
	_origin = origin.floor()
	_view_size = Vector2(view_size)
	position = content.position
	size = content.size
	visible = true
	queue_redraw()


func clear_course() -> void:
	course_identity = {}
	targets = PackedVector2Array()
	target_index = 0
	visible = false


func _draw() -> void:
	if not course_identity.is_empty() and _view_size.x > 0.0 and _view_size.y > 0.0:
		draw_target_markers()
