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
var conversation: Array = []
var context_mode := OptionButton.new()
var turn_limit := SpinBox.new()
var guidance := TextEdit.new()
var remaining_turns := 0
var sent_turns := 0
var traffic_filter := LineEdit.new()
var task_prompt := ""
var run_mode := 1
var last_image := ""
var full_image := CheckBox.new()
var last_result := ""
var request_scanline := false
var run_epoch := 0
var next_request_ms := 0
var provider_wait_ms := 0
var provider_wait_url := ""
var request_url := ""
var run_deadline_ms := 0
var run_seconds := SpinBox.new()
var spend_limit := SpinBox.new()
var input_price := SpinBox.new()
var output_price := SpinBox.new()
var run_spend := 0.0
var spend_status := ""
var run_spend_limit := 0.0
var sent_input_price := 0.0
var sent_output_price := 0.0

var waiting_until_ms := 0
var minimum_interval := SpinBox.new()
var stencil_guidance := TextEdit.new()
var stencil_prompt := ""
const STENCIL_INSTRUCTIONS := "Return a JSON array of rows. Each row is {y, repeat, scale, spans}. y is the local row index. repeat and scale default to 1. Each span is [x,length,material]. Scale multiplies x, y, length and repeat. Material 58 draws, 0 erases. Omitted spans preserve existing cells. Use local coordinates inside the stated area. Return [] when finished."


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
	input_mode.add_item("Scanline")
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
	if run_deadline_ms > 0 and Time.get_ticks_msec() >= run_deadline_ms:
		if provider.active or capturing or executor.active or remaining_turns > 0: stop_all("Run time limit reached")
		run_deadline_ms = 0
	draw.disabled = executor.active
	stop.disabled = not executor.active and not provider.active and not capturing and remaining_turns == 0
	if provider.active and wb.host.simulation_worker.art_state().epoch != request_epoch: stop_all("Canvas changed")
	draw.disabled = executor.active or provider.active or capturing or remaining_turns > 0
	draw.text = "Draw" if input_mode.selected==0 else "Send"
	for row: Control in rows: row.visible = input_mode.selected!=0
	key_button.text = "Key ✓" if not str(keys.get(current_provider,"")).is_empty() else "Key…"
	help.text = "Turns limits requests per Send. Image attaches a canvas crop. Select a vision model to use it." if input_mode.selected!=0 else "Ordered JSON: rectangle / disc / line / pixels. Material 58 = Hard Wall; 0 = erase. Large drawings stream in native-sized chunks."
	if log_draw and not executor.active:
		provider.log_event("native_result",executor.result)
		log_draw = false
		model_feedback(JSON.stringify(executor.result))
	if remaining_turns == 0 and not provider.active and not capturing and not log_draw:
		run_deadline_ms = 0
	var status_text := "Idle"
	if provider.active: status_text = "Waiting for model · Stop available"
	elif waiting_until_ms > Time.get_ticks_msec():
		status_text = "Waiting to send · %.1fs · Stop available" % ((waiting_until_ms-Time.get_ticks_msec())/1000.0)
	elif capturing: status_text = "Capturing current view · Stop available"
	elif not input_error.is_empty():
		status_text = input_error.left(500)+(" … See Traffic for full details." if input_error.length()>500 else "")
	elif executor.active or executor.result.status != "idle":
		var r: Dictionary = executor.result
		status_text = "%s · %d checked · %d changed · %d protected/outside skipped%s" % [str(r.status).capitalize(),r.checked,r.changed,r.excluded," · "+str(r.reason) if not str(r.reason).is_empty() else ""]

	if input_mode.selected != 0 and not provider.requested_model.is_empty():
		var u: Dictionary = provider.usage
		status_text += " · In %s Out %s · Cost ?" % [str(u.get("input_tokens",u.get("prompt_tokens","?"))),str(u.get("output_tokens",u.get("completion_tokens","?")))]
	if run_spend_limit > 0: status_text += " · Est. $%.4f / $%.4f" % [run_spend,run_spend_limit]
	if input_mode.selected != 0 and not spend_status.is_empty(): status_text += " · "+spend_status
	if not provider.log_warning.is_empty(): status_text += " · "+provider.log_warning
	if state.text != status_text: state.text = status_text

func _exit_tree() -> void:
	if wb != null: stop_all("Workbench closed")

func mount_provider_controls(column: VBoxContainer) -> void:
	settings.load("user://art-provider.cfg")
	conversation = provider.resume_traffic(settings.get_value("session","traffic_path",""))
	for entry: Dictionary in conversation:
		var content: String = entry.get("content","")
		if content.begins_with("Canvas result ("): last_result = content
	add_child(provider)
	provider.finished.connect(provider_finished)
	executor.native_receipt.connect(func(receipt: Dictionary) -> void:
		if log_draw: provider.log_event("native_receipt",receipt))
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
	full_image.text = "Full view"
	full_image.tooltip_text = "Send the whole visible canvas instead of its intersection with the work area."
	row.add_child(full_image)
	column.add_child(row); rows.append(row)
	row = HBoxContainer.new()
	for label: String in ["Full","Compacted","Custom","None"]: context_mode.add_item(label)
	context_mode.select(clampi(int(settings.get_value("session","context",1)),0,3))
	context_mode.tooltip_text = "Conversation context for the next request. Custom currently uses Compacted."
	row.add_child(context_mode)
	turn_limit.prefix = "Turns"
	turn_limit.min_value = 1
	turn_limit.max_value = 1000
	row.add_child(turn_limit)
	minimum_interval.prefix = "Gap s"
	minimum_interval.max_value = 3600
	minimum_interval.step = 0.1
	minimum_interval.tooltip_text = "Minimum seconds between model requests. Zero disables local pacing."
	row.add_child(minimum_interval)
	run_seconds.prefix = "Run s"
	run_seconds.max_value = 86400
	run_seconds.tooltip_text = "Maximum seconds for this run. Zero disables the limit."
	row.add_child(run_seconds)
	var spending := Window.new()
	spending.title = "Estimated spending"
	add_child(spending)
	spending.hide()
	spending.close_requested.connect(spending.hide)
	var spending_fields := VBoxContainer.new()
	spending.add_child(spending_fields)
	spending_fields.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var spending_help := Label.new()
	spending_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spending_help.text = "Enter your own rates. A zero ceiling disables spending control. The estimate uses reported tokens after each response and can exceed the ceiling by one request."
	spending_fields.add_child(spending_help)
	for field: SpinBox in [spend_limit,input_price,output_price]:
		field.min_value = 0
		field.max_value = 1000000
		field.step = 0.001
		spending_fields.add_child(field)
	spend_limit.prefix = "Run USD"
	input_price.prefix = "Input USD / 1M"
	output_price.prefix = "Output USD / 1M"
	var spending_button := Button.new()
	spending_button.text = "Spend…"
	spending_button.pressed.connect(func() -> void: spending.popup_centered(Vector2i(400,220)))
	row.add_child(spending_button)
	var clear := Button.new()
	clear.text = "Clear conversation"
	clear.pressed.connect(func() -> void:
		stop_all("Conversation cleared")
		conversation.clear()
		log_draw = false
		last_result = ""
		last_image = ""
		provider.log_event("conversation_cleared",{})
		persist_traffic_path())
	row.add_child(clear)
	var guidance_window := Window.new()
	guidance_window.title = "Drawing guidance"
	add_child(guidance_window)
	guidance_window.hide()
	guidance_window.close_requested.connect(guidance_window.hide)
	guidance_window.add_child(guidance)
	guidance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guidance.text = settings.get_value("session","guidance",Provider.INSTRUCTIONS)
	var stencil_window := Window.new()
	stencil_window.title = "Scanline guidance"
	add_child(stencil_window)
	stencil_window.hide()
	stencil_window.close_requested.connect(stencil_window.hide)
	stencil_window.add_child(stencil_guidance)
	stencil_guidance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stencil_guidance.text = settings.get_value("session","scanline_guidance",STENCIL_INSTRUCTIONS)
	var edit_guidance := Button.new()
	edit_guidance.text = "Guidance…"
	edit_guidance.pressed.connect(func() -> void:
		var window := stencil_window if input_mode.selected == 2 else guidance_window
		window.popup_centered(Vector2i(700,400)))
	row.add_child(edit_guidance)
	column.add_child(row)
	rows.append(row)
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
	traffic_filter.placeholder_text = "Filter traffic"
	traffic_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traffic_filter.text_changed.connect(func(_value: String) -> void: refresh_traffic())
	actions.add_child(traffic_filter)
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

var previous_mode := 1

func change_mode(index: int) -> void:
	match previous_mode:
		0: json_text = input.text
		1: prompt_text = input.text
		2: stencil_prompt = input.text
	match index:
		0: input.text = json_text
		1: input.text = prompt_text
		2: input.text = stencil_prompt
	previous_mode = index
	input_error = ""

func save_profile() -> void:
	settings.set_value(current_provider,"endpoint",endpoint.text)
	settings.set_value(current_provider,"model",model.text)
	settings.set_value(current_provider,"tokens",int(tokens.value))
	settings.set_value(current_provider,"seconds",int(seconds.value))
	var names: Array = settings.get_value(current_provider,"history",[])
	if not model.text.is_empty() and not names.has(model.text): names.append(model.text)
	settings.set_value(current_provider,"history",names)
	settings.set_value("session","context",context_mode.selected)
	settings.set_value("session","guidance",guidance.text)
	settings.set_value("session","scanline_guidance",stencil_guidance.text)
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
	remaining_turns = 0
	run_deadline_ms = 0
	waiting_until_ms = 0
	ui_epoch += 1; capturing = false
	provider.cancel(reason)
	executor.stop(reason)
	provider_message = reason
	input_error = reason

func model_context() -> Array:
	if context_mode.selected == 3: return []
	var full := context_mode.selected == 0
	var first := 0 if full else maxi(0,conversation.size()-12)
	var context: Array = []
	if first > 0:
		context.append({"role":"user","content":"Earlier turns omitted from this request; latest confirmed result: "+last_result})
	for entry: Dictionary in conversation.slice(first):
		var message := {"role":entry.role,"content":entry.content}
		if full and entry.has("image_offset") and not image_input.button_pressed:
			message.content += "\nHistorical image omitted because Image is off."
		elif full and entry.has("image_offset"):
			var url := provider.historical_image(int(entry.image_offset))
			if url.is_empty():
				message.content += "\nThis turn's image is unavailable in saved traffic."
			elif current_provider == "OpenAI":
				message.content = [{"type":"input_text","text":entry.content},{"type":"input_image","image_url":url}]
			else:
				message.content = [{"type":"text","text":entry.content},{"type":"image_url","image_url":{"url":url}}]
		context.append(message)
	return context

func model_feedback(feedback: String) -> void:
	last_result = feedback
	remember_turn("user","Canvas result (world epoch %d): %s" % [request_epoch,feedback])
	if remaining_turns > 0:
		send_next.call_deferred(ui_epoch)

func remember_turn(role: String, content: String, image_offset: int = -1) -> void:
	var entry := {"role":role,"content":provider.redact(content)}
	if image_offset >= 0: entry.image_offset = image_offset
	conversation.append(entry)
	provider.log_event("conversation",entry)
	persist_traffic_path()

func persist_traffic_path() -> void:
	if not provider.log_path.is_empty() and settings.get_value("session","traffic_path","") != provider.log_path:
		settings.set_value("session","traffic_path",provider.log_path)
		settings.save("user://art-provider.cfg")

func send_prompt() -> void:
	if executor.active or provider.active or capturing or remaining_turns > 0: return
	if wb.busy() or wb.applied.is_empty():
		input_error = "Canvas is not ready."
		return
	sent_turns = 0
	run_spend = 0.0
	spend_status = ""
	run_spend_limit = spend_limit.value
	if run_spend_limit > 0 and (input_price.value <= 0 and output_price.value <= 0):
		input_error = "Set a token rate in Spend, or set the spending ceiling to zero."
		return
	task_prompt = input.text
	run_mode = input_mode.selected
	run_epoch = wb.host.simulation_worker.art_state().epoch
	last_image = ""
	remaining_turns = int(turn_limit.value)
	run_deadline_ms = Time.get_ticks_msec()+int(run_seconds.value*1000) if run_seconds.value > 0 else 0
	send_next(ui_epoch)

func send_next(expected_epoch: int) -> void:
	if expected_epoch != ui_epoch or remaining_turns <= 0: return
	if run_epoch != wb.host.simulation_worker.art_state().epoch:
		stop_all("Canvas changed")
		return
	var due := next_request_ms
	if endpoint.text.strip_edges() == provider_wait_url: due = maxi(due,provider_wait_ms)
	var delay := due - Time.get_ticks_msec()
	if delay > 0:
		waiting_until_ms = due
		provider.log_event("pace_wait",{"milliseconds":delay})
		await get_tree().create_timer(delay/1000.0).timeout
		if expected_epoch == ui_epoch:
			waiting_until_ms = 0
			send_next(expected_epoch)
		return
	if executor.active or provider.active or capturing: return
	if wb.busy() or wb.applied.is_empty():
		remaining_turns = 0
		input_error = "Canvas is not ready."
		return
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
	var observation := ""
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
		var rect: Rect2 = wb.host.view_content_rect()
		rect.position += wb.host.world_view.get_global_rect().position
		var visible_cells := Rect2(Vector2(wb.host.camera_origin.floor()),Vector2(wb.host.current_view_size))
		var image_cells := visible_cells
		if not full_image.button_pressed:
			var intersection := visible_cells.intersection(Rect2(request_area))
			if intersection.has_area(): image_cells = intersection
		var pixels_per_cell := rect.size/visible_cells.size
		var image_rect := Rect2(rect.position+(image_cells.position-visible_cells.position)*pixels_per_cell,image_cells.size*pixels_per_cell)
		var crop := Rect2i(image_rect.position*scale,image_rect.size*scale).intersection(Rect2i(Vector2i.ZERO,frame.get_size()))
		if not crop.has_area(): capturing = false; input_error = "Canvas capture is empty."; return
		var view := frame.get_region(crop)
		if maxi(view.get_width(),view.get_height())>768:
			var ratio := 768.0/maxi(view.get_width(),view.get_height())
			view.resize(maxi(1,int(view.get_width()*ratio)),maxi(1,int(view.get_height()*ratio)),Image.INTERPOLATE_NEAREST)
		png = Marshalls.raw_to_base64(view.save_png_to_buffer())
		observation = "Image world rectangle x=%d y=%d w=%d h=%d, image %d by %d pixels, world epoch %d." % [image_cells.position.x,image_cells.position.y,image_cells.size.x,image_cells.size.y,view.get_width(),view.get_height(),request_epoch]
		provider.log_event("observation",{"mapping":observation,"sha256":png.sha256_text()})
		capturing = false
	if epoch != ui_epoch or request_epoch != wb.host.simulation_worker.art_state().epoch: return
	save_profile()
	var instructions := guidance.text+" Work area XYWH="+JSON.stringify([request_area.position.x,request_area.position.y,request_area.size.x,request_area.size.y])+"; allowed materials="+JSON.stringify(request_materials)+"; protected rectangles="+str(request_guards)+"."
	request_scanline = run_mode == 2
	request_local = current_provider == "LM Studio" or request_scanline
	if request_local:
		instructions = guidance.text+" Coordinates are LOCAL: top-left is (0,0), never add a world offset. XYWH="+JSON.stringify([0,0,request_area.size.x,request_area.size.y])+". Allowed materials="+JSON.stringify(request_materials)+". Use compact rectangles, discs and lines. Every rectangle and line requires all four endpoint fields. Do not enumerate filled areas as pixels."
	if request_scanline:
		instructions = stencil_guidance.text+" Local area width %d, height %d. Allowed materials %s." % [request_area.size.x,request_area.size.y,str(request_materials)]
	instructions += "\nReturn [] when the drawing is finished."
	var context := model_context()
	var prompt := task_prompt
	if not observation.is_empty(): prompt += "\n"+observation
	if sent_turns > 0:
		prompt += "\nContinue revising the current artwork. Latest confirmed result: "+last_result+"\nReturn [] when finished."
	var image_hash := png.sha256_text()
	if not png.is_empty() and image_hash == last_image and context_mode.selected != 3:
		png = ""
		prompt += "\nThe current view matches the last capture. Image bytes omitted from this request."
	last_image = image_hash
	next_request_ms = Time.get_ticks_msec() + int(minimum_interval.value*1000)
	remaining_turns -= 1
	sent_turns += 1
	request_url = endpoint.text.strip_edges()
	sent_input_price = input_price.value
	sent_output_price = output_price.value
	input_error = provider.send(current_provider,request_url,model.text.strip_edges(),keys.get(current_provider,""),prompt,instructions,int(tokens.value),seconds.value,png,context)
	if input_error.is_empty(): remember_turn("user",prompt,provider.last_request_offset if not png.is_empty() else -1)
	else: remaining_turns = 0

func provider_finished(_id: int, text: String, _response: Dictionary, error: String) -> void:
	if request_epoch != wb.host.simulation_worker.art_state().epoch:
		provider.log_event("discarded","Canvas changed or Stop requested; no drawing")
		return
	var received_input: Variant = provider.usage.get("input_tokens",provider.usage.get("prompt_tokens"))
	var received_output: Variant = provider.usage.get("output_tokens",provider.usage.get("completion_tokens"))
	if ArtPlan.integer(received_input) and ArtPlan.integer(received_output) and received_input >= 0 and received_output >= 0 and (sent_input_price > 0 or sent_output_price > 0):
		run_spend += (float(received_input)*sent_input_price+float(received_output)*sent_output_price)/1000000.0
		provider.log_event("estimated_spend",{"run_usd":run_spend,"ceiling_usd":run_spend_limit})
		if run_spend_limit > 0 and run_spend >= run_spend_limit:
			remaining_turns = 0
			spend_status = "Estimated spending ceiling reached"
			provider.log_event("run_limit",spend_status)
	elif run_spend_limit > 0 and error.is_empty():
		remaining_turns = 0
		spend_status = "Provider usage unavailable; spending ceiling cannot be tracked"
		provider.log_event("run_limit",spend_status)
	if not error.is_empty():
		if provider.retry_after_seconds > 0:
			provider_wait_ms = Time.get_ticks_msec()+int(provider.retry_after_seconds*1000)
			provider_wait_url = request_url
			provider.log_event("provider_rate_wait",{"seconds":provider.retry_after_seconds})
			if remaining_turns > 0:
				send_next.call_deferred(ui_epoch)
				return
		input_error = error
		remaining_turns = 0
		remember_turn("user","Request failed: "+error)
		return
	provider.log_event("message",text)
	remember_turn("assistant",text)
	var operations: Variant = Provider.operations(text)
	if request_scanline and operations is Array and not operations.is_empty():
		operations = stencil_operations(operations)
		if operations.is_empty():
			input_error = "No usable scanline spans. Check y, repeat, scale, x, length and material."
			model_feedback(input_error)
			return
	if operations is Array and operations.is_empty():
		remaining_turns = 0
		input_error = "Model finished."
		return
	if request_local and operations is Array:
		var fitted := local_operations(operations)
		provider.log_event("local_geometry",{"accepted":fitted.size(),"returned":operations.size(),"origin":str(request_area.position)})
		if fitted.is_empty():
			input_error = "No usable shapes in the local response. See Traffic."
			model_feedback(input_error)
			return
		operations = fitted
	var answer: Dictionary = executor.submit(operations,request_area,request_guards,request_materials)
	provider.log_event("drawing_admission",answer)
	if answer.status=="refused":
		input_error = answer.reason+" · See Traffic."
		model_feedback(input_error)
	else: log_draw = true

func stencil_operations(rows_data: Array) -> Array:
	var operations: Array = []
	for row: Variant in rows_data:
		if not row is Dictionary or not row.get("spans") is Array: continue
		var y: Variant = row.get("y")
		var repeat: Variant = row.get("repeat",1)
		var scale: Variant = row.get("scale",1)
		if not ArtPlan.integer(y) or not ArtPlan.integer(repeat) or not ArtPlan.integer(scale): continue
		if y < 0 or repeat < 1 or scale < 1: continue
		var top := int(y)*int(scale)
		var bottom := (int(y)+int(repeat))*int(scale)-1
		for span: Variant in row.spans:
			if not span is Array or span.size() != 3: continue
			if not ArtPlan.integer(span[0]) or not ArtPlan.integer(span[1]) or span[0] < 0 or span[1] < 1: continue
			var material: Variant = span[2]
			if material is String and material in ["0","58"]: material = int(material)
			operations.append({"shape":"rectangle","x0":int(span[0])*int(scale),"x1":(int(span[0])+int(span[1]))*int(scale)-1,"y0":top,"y1":bottom,"material":material})
	return operations

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
	var content: String = provider.traffic if raw_traffic.button_pressed else provider.readable
	var query := traffic_filter.text.strip_edges()
	if not query.is_empty():
		var matches := PackedStringArray()
		for line: String in content.split("\n"):
			if line.containsn(query): matches.append(line)
		content = "\n".join(matches)
	traffic_text.text = content
	traffic_path.text = ProjectSettings.globalize_path(provider.log_path)+(" · "+provider.log_warning if not provider.log_warning.is_empty() else "")
