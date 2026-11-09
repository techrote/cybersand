extends Control
## #528 presentation only: actual human-authorized scope and protection.
## Native #526 validates/rechecks all edits; a coloured rectangle is not an
## authority, does not alter cells, and cannot protect walls against physics.
var _project: Callable
var _active: bool = false
var _authorized: Rect2i = Rect2i()
var _protected_regions: Array[Rect2i] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func set_world_to_screen(project: Callable) -> void:
	_project = project
	_refresh()

func set_active(enabled: bool) -> void:
	_active = enabled
	_refresh()

func set_scope(authorized: Rect2i, protections: Array[Rect2i]) -> void:
	_authorized = authorized
	_protected_regions = protections.duplicate()
	_refresh()

func _refresh() -> void:
	visible = _active and _project.is_valid() and _authorized.has_area()
	queue_redraw()

func _draw() -> void:
	if not visible or not _project.is_valid():
		return
	var outline: Variant = _project.call(_authorized)
	if outline is Rect2:
		draw_rect(outline,Color(0.22,0.85,1.0,0.85),false,2.0)
	for protection: Rect2i in _protected_regions:
		var projected: Variant = _project.call(protection)
		if projected is Rect2:
			draw_rect(projected,Color(1.0,0.24,0.21,0.22),true)
			draw_rect(projected,Color(1.0,0.27,0.19,0.92),false,2.0)
