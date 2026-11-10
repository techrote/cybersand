extends Window
## Compact direct drawing and one-shot provider interface; no provider/Git preflight.
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
const Provider = preload("res://scripts/art_provider.gd")
var provider := Provider.new()
var input_mode := OptionButton.new()
var source := OptionButton.new()
var model := LineEdit.new()
var history := OptionButton.new()
var endpoint := LineEdit.new()
var tokens := SpinBox.new()
var seconds := SpinBox.new()
var image_input := CheckBox.new()
var key_dialog := ConfirmationDialog.new()
var key_field := LineEdit.new()
var key_button := Button.new()
var traffic_window := Window.new()
var traffic_text := TextEdit.new()
var raw_traffic := CheckBox.new()
var traffic_path := Label.new()
var settings := ConfigFile.new()
var keys: Dictionary = {}
var rows: Array[Control] = []
var prompt_text := "Draw a cyberpunk robot statue using a few rectangles, discs and lines."
var json_text := '[{"shape":"rectangle","x0":32,"y0":32,"x1":95,"y1":159,"material":58},{"shape":"disc","x":64,"y":70,"radius":12,"material":0}]'
var current_provider := "LM Studio"
var request_epoch := 0
var request_local := false
const ArtPlan = preload("res://scripts/art_batch_plan.gd")
const NVIDIA_MODELS := {
	"Qwen3 Next 80B Instruct · text": "qwen/qwen3-next-80b-a3b-instruct",
	"Qwen2.5 Coder 32B · text": "qwen/qwen2.5-coder-32b-instruct",
	"Nemotron 3.5 Lightning · text": "nvidia/nemotron-3.5-lightning-30b-a3b",
	"Nemotron 3.5 Super VL · image": "nvidia/nemotron-3.5-super-vl-120b-a12b",
}
var ui_epoch := 0
var capturing := false
var request_area: Rect2i
var request_guards: Array = []
var request_materials: Array = []
var provider_message := "Idle"
var log_draw := false
var help := Label.new()

func _ready() -> void:
	title = "Art workbench"
	size = Vector2i(790,550)
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
	caption.text = "Art workbench"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(caption)
	draw.text = "Draw"
	draw.pressed.connect(func() -> void:
		if input_mode.selected==0: submit_text()
		else: send_prompt())
	actions.add_child(draw)
	stop.text = "Stop"
	stop.pressed.connect(stop_all)
	actions.add_child(stop)
	input_mode.add_item("Direct JSON")
	input_mode.add_item("Model prompt")
	input_mode.select(1)
	input_mode.item_selected.connect(change_mode)
	actions.add_child(input_mode)
	column.add_child(actions)
	mount_provider_controls(column)
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
	input.text = prompt_text
	column.add_child(input)

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
	stop.disabled = not executor.active and not provider.active and not capturing
	if provider.active and wb.host.simulation_worker.art_state().epoch != request_epoch: stop_all("Canvas changed")
	draw.disabled = executor.active or provider.active or capturing
	draw.text = "Draw" if input_mode.selected==0 else "Send"
	for row: Control in rows: row.visible = input_mode.selected==1
	key_button.text = "Key ✓" if not str(keys.get(current_provider,"")).is_empty() else "Key…"
	help.text = "One request → direct drawing. Image sends the current canvas view; choose a vision model. Previous conversation is not sent in Stage 2." if input_mode.selected==1 else "Ordered JSON: rectangle / disc / line / pixels. Material 58 = Hard Wall; 0 = erase. Large drawings stream in native-sized chunks."
	if log_draw and not executor.active:
		provider.log_event("native_result",executor.result)
		log_draw = false
	if provider.active: state.text = "Waiting for model · Stop available"
	elif capturing: state.text = "Capturing current view · Stop available"
	elif not input_error.is_empty():
		state.text = input_error.left(500)+(" … See Traffic for full details." if input_error.length()>500 else "")
	elif executor.active or executor.result.status != "idle":
		var r: Dictionary = executor.result
		state.text = "%s · %d checked · %d changed · %d protected/outside skipped%s" % [str(r.status).capitalize(),r.checked,r.changed,r.excluded," · "+str(r.reason) if not str(r.reason).is_empty() else ""]

	if not provider.requested_model.is_empty():
		var u: Dictionary = provider.usage
		state.text += " · In %s Out %s · Cost ?" % [str(u.get("input_tokens",u.get("prompt_tokens","?"))),str(u.get("output_tokens",u.get("completion_tokens","?")))]
	if not provider.log_warning.is_empty(): state.text += " · "+provider.log_warning

func _exit_tree() -> void:
	if wb != null: stop_all("Workbench closed")

func mount_provider_controls(column: VBoxContainer) -> void:
	settings.load("user://art-provider.cfg")
	add_child(provider)
	provider.finished.connect(provider_finished)
	provider.traffic_changed.connect(refresh_traffic)
	var row := HBoxContainer.new()
	for name_text: String in ["LM Studio","OpenAI","NVIDIA"]: source.add_item(name_text)
	source.item_selected.connect(change_provider)
	row.add_child(source)
	model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model.placeholder_text = "Model ID"
	row.add_child(model)
	history.tooltip_text = "Previously used model IDs"
	history.fit_to_longest_item = false
	history.clip_text = true
	history.custom_minimum_size.x = 34
	history.item_selected.connect(func(i: int) -> void:
		if i>0: model.text = str(history.get_item_metadata(i)) if history.get_item_metadata(i) != null else history.get_item_text(i)
		history.select(0))
	row.add_child(history)
	key_button.text = "Key…"
	key_button.pressed.connect(func() -> void:
		key_dialog.title = current_provider+" key · memory only"
		key_field.text = keys.get(current_provider,"")
		key_dialog.popup_centered(Vector2i(540,100))
		key_field.grab_focus())
	row.add_child(key_button)
	var traffic_button := Button.new()
	traffic_button.text = "Traffic…"
	traffic_button.pressed.connect(func() -> void: refresh_traffic(); traffic_window.popup_centered(Vector2i(900,600)))
	row.add_child(traffic_button)
	column.add_child(row); rows.append(row)
	row = HBoxContainer.new()
	endpoint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endpoint.placeholder_text = "API base URL, including /v1"
	row.add_child(endpoint)
	tokens.prefix = "Toks"
	tokens.min_value = 1; tokens.max_value = 262144; tokens.value = 8192
	tokens.custom_minimum_size.x = 130
	row.add_child(tokens)
	seconds.prefix = "Secs"
	seconds.min_value = 1; seconds.max_value = 3600; seconds.value = 180
	seconds.custom_minimum_size.x = 110
	row.add_child(seconds)
	image_input.text = "Image"
	image_input.tooltip_text = "Send the rendered current canvas view; use a vision-capable model."
	row.add_child(image_input)
	column.add_child(row); rows.append(row)
	key_field.secret = true
	key_field.placeholder_text = "Paste API key; never saved in profiles or traffic"
	key_field.custom_minimum_size.x = 500
	key_dialog.add_child(key_field)
	key_dialog.confirmed.connect(func() -> void:
		keys[current_provider] = key_field.text.strip_edges()
		key_field.clear())
	key_dialog.canceled.connect(key_field.clear)
	add_child(key_dialog)
	traffic_window.title = "Art traffic · complete redacted requests / responses / native results"
	traffic_window.min_size = Vector2i(600,350)
	traffic_window.close_requested.connect(traffic_window.hide)
	add_child(traffic_window)
	traffic_window.hide()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	traffic_window.add_child(box)
	var actions := HBoxContainer.new()
	var copy := Button.new(); copy.text = "Copy visible"
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(traffic_text.text))
	actions.add_child(copy)
	raw_traffic.text = "Raw JSONL"
	raw_traffic.toggled.connect(func(_on: bool) -> void: refresh_traffic())
	actions.add_child(raw_traffic)
	var export_button := Button.new(); export_button.text = "Save full JSONL…"
	var save := FileDialog.new()
	save.file_mode = FileDialog.FILE_MODE_SAVE_FILE; save.access = FileDialog.ACCESS_FILESYSTEM
	save.current_file = "cybersand-art-traffic.jsonl"
	traffic_window.add_child(save)
	save.file_selected.connect(func(path: String) -> void:
		var err := DirAccess.copy_absolute(provider.log_path,path)
		traffic_path.text = "Saved full session to "+path if err==OK else "Export failed (%d); original: %s" % [err,ProjectSettings.globalize_path(provider.log_path)])
	export_button.pressed.connect(func() -> void: save.popup_centered_ratio(0.7))
	actions.add_child(export_button)
	box.add_child(actions)
	traffic_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(traffic_path)
	traffic_text.editable = false
	traffic_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	traffic_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(traffic_text)
	load_profile()

func change_mode(index: int) -> void:
	if index==0: prompt_text = input.text; input.text = json_text
	else: json_text = input.text; input.text = prompt_text
	input_error = ""

func save_profile() -> void:
	settings.set_value(current_provider,"endpoint",endpoint.text)
	settings.set_value(current_provider,"model",model.text)
	settings.set_value(current_provider,"tokens",int(tokens.value))
	settings.set_value(current_provider,"seconds",int(seconds.value))
	var names: Array = settings.get_value(current_provider,"history",[])
	if not model.text.is_empty() and not names.has(model.text): names.append(model.text)
	settings.set_value(current_provider,"history",names)
	settings.save("user://art-provider.cfg")

func change_provider(index: int) -> void:
	save_profile()
	current_provider = source.get_item_text(index)
	load_profile()

func load_profile() -> void:
	var defaults := {"LM Studio":["http://127.0.0.1:1234/v1","wb-art-instruct"],"OpenAI":["https://api.openai.com/v1","gpt-5.6-luna"],"NVIDIA":["https://integrate.api.nvidia.com/v1","qwen/qwen3-next-80b-a3b-instruct"]}
	endpoint.text = settings.get_value(current_provider,"endpoint",defaults[current_provider][0])
	model.text = settings.get_value(current_provider,"model",defaults[current_provider][1])
	tokens.value = settings.get_value(current_provider,"tokens",8192)
	seconds.value = settings.get_value(current_provider,"seconds",180)
	history.clear(); history.add_item("▾")
	if current_provider == "NVIDIA":
		for label: String in NVIDIA_MODELS:
			history.add_item(label)
			history.set_item_metadata(history.item_count-1,NVIDIA_MODELS[label])
	for name_text: String in settings.get_value(current_provider,"history",[]): history.add_item(name_text)

func stop_all(reason: String = "Human Stop") -> void:
	ui_epoch += 1; capturing = false
	provider.cancel(reason)
	executor.stop(reason)
	provider_message = reason
	input_error = reason

func send_prompt() -> void:
	if executor.active or provider.active or capturing: return
	if wb.busy() or wb.applied.is_empty(): input_error = "Canvas is not ready."; return
	executor.wb = wb
	input_error = ""
	ui_epoch += 1
	var epoch := ui_epoch
	request_epoch = wb.host.simulation_worker.art_state().epoch
	request_area = rectangle(fields)
	request_guards = [rectangle(protected_fields)] if protect.button_pressed else []
	request_materials = []
	if wall.button_pressed: request_materials.append(58)
	if erase.button_pressed: request_materials.append(0)
	var png := ""
	if image_input.button_pressed:
		if DisplayServer.get_name()=="headless": input_error = "Image capture needs a graphical window. Turn Image off for text-only inference."; return
		capturing = true
		# Capture the actual canvas without our floating windows covering it.
		var reopen := visible
		var reopen_traffic := traffic_window.visible
		hide(); traffic_window.hide()
		await RenderingServer.frame_post_draw
		var frame: Image = wb.host.get_viewport().get_texture().get_image()
		if reopen: show()
		if reopen_traffic: traffic_window.show()
		if epoch != ui_epoch: return
		var logical: Vector2 = wb.host.get_viewport().get_visible_rect().size
		var scale := Vector2(frame.get_width(),frame.get_height())/logical
		var rect: Rect2 = wb.host.world_view.get_global_rect()
		var crop := Rect2i(rect.position*scale,rect.size*scale).intersection(Rect2i(Vector2i.ZERO,frame.get_size()))
		if not crop.has_area(): capturing = false; input_error = "Canvas capture is empty."; return
		var view := frame.get_region(crop)
		if maxi(view.get_width(),view.get_height())>768:
			var ratio := 768.0/maxi(view.get_width(),view.get_height())
			view.resize(maxi(1,int(view.get_width()*ratio)),maxi(1,int(view.get_height()*ratio)),Image.INTERPOLATE_NEAREST)
		png = Marshalls.raw_to_base64(view.save_png_to_buffer())
		capturing = false
	if epoch != ui_epoch or request_epoch != wb.host.simulation_worker.art_state().epoch: return
	save_profile()
	var instructions := Provider.INSTRUCTIONS+" Work area XYWH="+JSON.stringify([request_area.position.x,request_area.position.y,request_area.size.x,request_area.size.y])+"; allowed materials="+JSON.stringify(request_materials)+"; protected rectangles="+str(request_guards)+"."
	request_local = current_provider == "LM Studio"
	if request_local:
		instructions = Provider.INSTRUCTIONS+" Coordinates are LOCAL: top-left is (0,0), never add a world offset. XYWH="+JSON.stringify([0,0,request_area.size.x,request_area.size.y])+". Allowed materials="+JSON.stringify(request_materials)+". Use compact rectangles, discs and lines. Every rectangle and line requires all four endpoint fields. Do not enumerate filled areas as pixels."
	input_error = provider.send(current_provider,endpoint.text.strip_edges(),model.text.strip_edges(),keys.get(current_provider,""),input.text,instructions,int(tokens.value),seconds.value,png)

func provider_finished(_id: int, text: String, _response: Dictionary, error: String) -> void:
	if request_epoch != wb.host.simulation_worker.art_state().epoch:
		provider.log_event("discarded","Canvas changed or Stop requested; no drawing")
		return
	if not error.is_empty(): input_error = error; return
	provider.log_event("message",text)
	var operations: Variant = Provider.operations(text)
	if request_local and operations is Array:
		var fitted := local_operations(operations)
		provider.log_event("local_geometry",{"accepted":fitted.size(),"returned":operations.size(),"origin":str(request_area.position)})
		if fitted.is_empty():
			input_error = "No usable shapes in the local response. See Traffic."
			return
		operations = fitted
	var answer: Dictionary = executor.submit(operations,request_area,request_guards,request_materials)
	provider.log_event("drawing_admission",answer)
	if answer.status=="refused": input_error = answer.reason+" · Edit prompt/JSON and retry; see Traffic."
	else: log_draw = true

func local_operations(operations: Array) -> Array:
	var fitted: Array = []
	var bounds := Rect2i(Vector2i.ZERO,request_area.size)
	for raw: Variant in operations:
		if not raw is Dictionary: continue
		var candidates: Array = [raw]
		if raw.get("shape") == "pixels" and not raw.has("points") and raw.has("x") and raw.has("y"):
			raw.points = [[raw.x,raw.y]]
		if raw.get("shape") == "line" and not raw.has("x0") and raw.get("points") is Array:
			candidates = []
			for i: int in range(1,raw.points.size()):
				var a: Variant = raw.points[i-1]
				var b: Variant = raw.points[i]
				if a is Array and b is Array and a.size()==2 and b.size()==2:
					candidates.append({"shape":"line","material":raw.material,"x0":a[0],"y0":a[1],"x1":b[0],"y1":b[1]})
		for candidate: Dictionary in candidates:
			var op := fit_local_operation(candidate,bounds)
			if not op.is_empty(): fitted.append(op)
	return fitted

func fit_local_operation(raw: Dictionary,bounds: Rect2i) -> Dictionary:
	var plan := ArtPlan.new()
	if not plan.configure([raw],bounds): return {}
	var op: Dictionary = plan.operations[0]
	if op.material not in request_materials: return {}
	match op.shape:
		"pixels":
			for pair: Array in op.points:
				pair[0] += request_area.position.x
				pair[1] += request_area.position.y
		"disc":
			op.x += request_area.position.x
			op.y += request_area.position.y
		_:
			for key: String in ["x0","x1"]: op[key] += request_area.position.x
			for key: String in ["y0","y1"]: op[key] += request_area.position.y
	return op

func refresh_traffic() -> void:
	traffic_text.text = provider.traffic if raw_traffic.button_pressed else provider.readable
	traffic_path.text = ProjectSettings.globalize_path(provider.log_path)+(" · "+provider.log_warning if not provider.log_warning.is_empty() else "")
