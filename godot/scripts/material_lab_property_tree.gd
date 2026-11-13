extends Tree

# Header dividers deliberately remain usable when the table scrolls sideways.
const DEFAULT_WIDTHS := [150,120,140,200,230,210]
var _handles: Array[Control] = []
var _drag_column: int = -1
var _drag_x: float = 0.0
var _drag_width: int = 0

func _ready() -> void:
	# A blank expanding tail absorbs spare space so even the last data column
	# can shrink independently; it contains no material property.
	columns = 7
	set_column_expand(6,true)
	set_column_custom_minimum_width(6,0)
	for column: int in range(6):
		set_column_expand(column,false)
		set_column_clip_content(column,true)
		set_column_custom_minimum_width(column,DEFAULT_WIDTHS[column])
		var handle := Control.new()
		handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		handle.tooltip_text = "Drag to resize this column. Double-click to restore its width."
		handle.gui_input.connect(_resize_input.bind(column))
		add_child(handle)
		_handles.append(handle)

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var panel: StyleBox = get_theme_stylebox("panel")
	var header: StyleBox = get_theme_stylebox("title_button_normal")
	var height: float = get_theme_font("title_button_font").get_height(get_theme_font_size("title_button_font_size")) + header.get_minimum_size().y
	var edge: float = panel.get_content_margin(SIDE_LEFT) - get_scroll().x
	for column: int in range(_handles.size()):
		edge += get_column_width(column)
		var handle: Control = _handles[column]
		handle.position = Vector2(minf(edge - 5,size.x - 10),panel.get_content_margin(SIDE_TOP))
		handle.size = Vector2(10,height)
		handle.visible = edge >= 5 and edge <= size.x

func _resize_input(event: InputEvent, column: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				set_column_custom_minimum_width(column,DEFAULT_WIDTHS[column])
				_drag_column = -1
			else:
				_drag_column = column
				_drag_x = event.global_position.x
				_drag_width = get_column_width(column)
		else: _drag_column = -1
		accept_event()
	elif event is InputEventMouseMotion and _drag_column == column:
		var scale_x: float = get_global_transform().get_scale().x
		var width: int = clampi(_drag_width + int((event.global_position.x - _drag_x) / scale_x),56,1600)
		set_column_custom_minimum_width(column,width)
		accept_event()
