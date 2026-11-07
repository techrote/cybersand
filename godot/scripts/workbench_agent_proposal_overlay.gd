extends Control
## WB-AGENT #528: presentation-only overlay of ACTUAL #526 prepared footprint.
## Needs host-provided world-to-viewport projection; does not grant edit authority.

var _cells: Array = []
var _project: Callable

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func set_world_to_screen(project: Callable) -> void:
	_project = project
	visible = _project.is_valid() and not _cells.is_empty()
	queue_redraw()

func set_footprint(cells: Array) -> void:
	_cells.clear()
	# No synthesized raster: display only native-validated coordinates.
	for value: Variant in cells:
		if value is Vector2i:
			_cells.append(value)
		elif value is Dictionary and value.has("x") and value.has("y"):
			if typeof(value.x) == TYPE_INT and typeof(value.y) == TYPE_INT:
				_cells.append(Vector2i(value.x, value.y))
	visible = _project.is_valid() and not _cells.is_empty()
	queue_redraw()

func _draw() -> void:
	if not _project.is_valid():
		return
	for position: Vector2i in _cells:
		var rect: Variant = _project.call(position)
		# Host must return an EXACT screen-space cell rectangle for its current
		# camera/render revision. Refuse to guess scale or camera origin.
		if rect is Rect2:
			draw_rect(rect, Color(0.2, 0.75, 1.0, 0.28), true)
			draw_rect(rect, Color(0.3, 0.9, 1.0, 0.75), false, 1.0)
