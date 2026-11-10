extends Window
## Stage 1: direct batch test surface. No provider, key, pricing or Git machinery.
const Executor = preload("res://scripts/art_batch_executor.gd")
var executor := Executor.new()
var wb: Node
var input := TextEdit.new()
var state := Label.new()
var fields: Array[SpinBox] = []
var protected_fields: Array[SpinBox] = []
var protect := CheckBox.new()
var draw := Button.new()
var stop := Button.new()
var input_error := ""
var wall := CheckBox.new()
var erase := CheckBox.new()

func _ready() -> void:
	title = "Direct art batches · Stage 1"
	size = Vector2i(760,500)
	min_size = Vector2i(560,380)
	transient = true
	exclusive = false
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var actions := HBoxContainer.new()
	var caption := Label.new()
	caption.text = "Direct native drawing"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(caption)
	draw.text = "Draw"
	draw.pressed.connect(submit_text)
	actions.add_child(draw)
	stop.text = "Stop"
	stop.pressed.connect(func() -> void: executor.stop())
	actions.add_child(stop)
	column.add_child(actions)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(state)
	var row := HBoxContainer.new()
	add_rectangle(row,fields,[0,0,2048,2048])
	wall.text = "Hard Wall"
	wall.button_pressed = true
	erase.text = "Erase"
	erase.button_pressed = true
	row.add_child(wall)
	row.add_child(erase)
	column.add_child(row)
	row = HBoxContainer.new()
	protect.text = "Protect"
	row.add_child(protect)
	add_rectangle(row,protected_fields,[0,0,4,4])
	column.add_child(row)
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.text = '[{"shape":"rectangle","x0":32,"y0":32,"x1":95,"y1":159,"material":58},{"shape":"disc","x":64,"y":70,"radius":12,"material":0}]'
	column.add_child(input)
	var help := Label.new()
	help.text = "JSON operations: rectangle / disc / line / pixels. World coordinates; material 58 = Hard Wall, 0 = erase. Large batches stream in native-sized chunks. Protected cells are skipped."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)

func add_rectangle(parent: Control, target: Array[SpinBox], values: Array) -> void:
	for i: int in range(4):
		var field := SpinBox.new()
		field.prefix = ["X","Y","W","H"][i]
		field.min_value = 0 if i<2 else 1
		field.max_value = 2147483647
		field.value = values[i]
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.custom_minimum_size.x = 85
		parent.add_child(field)
		target.append(field)

func rectangle(values: Array[SpinBox]) -> Rect2i:
	return Rect2i(int(values[0].value),int(values[1].value),int(values[2].value),int(values[3].value))

func submit_text() -> void:
	executor.wb = wb
	input_error = ""
	var parsed := JSON.new()
	if parsed.parse(input.text) != OK:
		input_error = "Invalid JSON at line%d: %s" % [parsed.get_error_line(),parsed.get_error_message()]
		return
	var allowed: Array = []
	if wall.button_pressed: allowed.append(58)
	if erase.button_pressed: allowed.append(0)
	var answer: Dictionary = executor.submit(parsed.data,rectangle(fields),[rectangle(protected_fields)] if protect.button_pressed else [],allowed)
	if answer.status == "refused": input_error = answer.reason

func _process(_delta: float) -> void:
	if wb == null: return
	executor.wb = wb
	executor.poll()
	draw.disabled = executor.active
	stop.disabled = not executor.active
	if not input_error.is_empty():
		state.text = input_error
	elif executor.active or executor.result.status != "idle":
		var r: Dictionary = executor.result
		state.text = "%s · %d checked · %d changed · %d protected/outside skipped%s" % [str(r.status).capitalize(),r.checked,r.changed,r.excluded," · "+str(r.reason) if not str(r.reason).is_empty() else ""]

func _exit_tree() -> void:
	if wb != null: executor.stop("Workbench closed")
