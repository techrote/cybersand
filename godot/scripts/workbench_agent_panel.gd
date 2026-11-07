extends VBoxContainer
## WB-AGENT #528: opt-in UI shell. Designed to mount inside shared_workbench.gd
## once #526/#527 hands off the authoritative dispatcher and viewport mapping.
## Never creates/owns a World or claims an edit is applied from UI admission alone.

signal progress(status: String, detail: String)

const Client = preload("res://scripts/workbench_agent_client.gd")
const Overlay = preload("res://scripts/workbench_agent_proposal_overlay.gd")
const ScopeOverlay = preload("res://scripts/workbench_agent_scope_overlay.gd")
const SignedFrame = preload("res://scripts/workbench_agent_signed_frame.gd")
const MAX_LOG_LINES := 32

var client: Node
var proposal_overlay: Control
var scope_overlay: Control
var _dispatcher: Callable
var _authorizer: Callable
var _retirement: Callable
var _start_pending := false
var _retire_pending := false
var _start_nonce := 0
var _task := TextEdit.new()
var _model := LineEdit.new()
var _signed_frame := CheckBox.new()
var _whole_canvas := Button.new()
var _canvas_region_provider: Callable
var _region: Array[SpinBox] = []
var _guard_region: Array[SpinBox] = []
var _guard := CheckBox.new()
var _wall := CheckBox.new()
var _empty := CheckBox.new()
var _start := Button.new()
var _stop := Button.new()
var _log := RichTextLabel.new()
var _state := Label.new()
var _protection_label := Label.new()
var _protected_regions: Array = []
var _lines: Array[String] = []
var _form_scroll := ScrollContainer.new()
var _form := VBoxContainer.new()

func _ready() -> void:
	client = Client.new()
	add_child(client)
	client.tool_requested.connect(_tool_request)
	client.status_changed.connect(_log_status)
	client.proposal_changed.connect(_proposal_updated)
	client.task_finished.connect(_task_finished)
	proposal_overlay = Overlay.new()
	scope_overlay = ScopeOverlay.new()
	name = "Agent authoring (opt-in)"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	var heading := Label.new()
	heading.name = "AgentHeading"
	heading.text = "Agent authoring"
	add_child(heading)
	# These controls remain visible while the bounded form scrolls.
	var actions := HBoxContainer.new()
	actions.name = "AgentActions"
	_start.name = "AgentStart"
	_start.text = "Start within scope"
	_start.tooltip_text = "Authorize the selected task region and allowed materials."
	_start.focus_mode = Control.FOCUS_NONE
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start.pressed.connect(_on_start)
	_stop.text = "Stop"
	_stop.name = "AgentStop"
	_stop.focus_mode = Control.FOCUS_NONE
	_stop.disabled = true
	_stop.pressed.connect(_on_stop)
	actions.add_child(_start)
	actions.add_child(_stop)
	add_child(actions)
	_state.text = "Native dispatcher not bound."
	_state.name = "AgentState"
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.max_lines_visible = 3
	add_child(_state)
	_form_scroll.name = "AgentFormScroll"
	_form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_form_scroll.mouse_force_pass_scroll_events = false
	add_child(_form_scroll)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.name = "AgentForm"
	_form.add_theme_constant_override("separation",8)
	_form_scroll.add_child(_form)
	var task_label := Label.new()
	task_label.text = "Task"
	_form.add_child(task_label)
	_task.custom_minimum_size = Vector2(240,110)
	_task.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_task.placeholder_text = "Describe the apparatus to build and test."
	_task.text_changed.connect(_retire_on_human_change)
	_form.add_child(_task)
	var model_label := Label.new()
	model_label.text = "Model"
	_form.add_child(model_label)
	_model.placeholder_text = "Vision-capable Responses model ID"
	_model.text_changed.connect(func(_value: String) -> void: _retire_on_human_change())
	_form.add_child(_model)
	_signed_frame.text = "Experimental signed frame (+512)"
	_signed_frame.tooltip_text = "Owner-admitted moved-hopper acceptance fixture (7 Nov 2026); 26 intermediate NORMAL trajectory differences remain. Host-only, opt-in, not strict signed-world parity. Genuine API trials and owner desktop acceptance remain separate."
	_signed_frame.toggled.connect(func(_value: bool) -> void: _on_scope_change())
	_form.add_child(_signed_frame)
	_whole_canvas.text = "Use whole canvas"
	_whole_canvas.tooltip_text = "Select the installed canvas as task scope. Each observation and edit remains limited to 4096 cells. Start authorizes the selected scope."
	_whole_canvas.disabled = true
	_whole_canvas.pressed.connect(_on_whole_canvas)
	_form.add_child(_whole_canvas)
	var scope_help := Label.new()
	scope_help.text = "Task scope may cover the canvas; each observation/edit uses at most 4096 cells."
	scope_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(scope_help)
	var row := HFlowContainer.new()
	_form.add_child(row)
	for spec: Array in [["X", -2147483648.0, 2147483647.0, 0.0],
			["Y", -2147483648.0, 2147483647.0, 0.0],
			["W", 1.0, 4096.0, 32.0], ["H", 1.0, 4096.0, 32.0]]:
		var text := Label.new()
		text.text = str(spec[0])
		row.add_child(text)
		var field := SpinBox.new()
		field.min_value = spec[1]
		field.max_value = spec[2]
		field.step = 1.0
		field.rounded = true
		field.value = spec[3]
		field.custom_minimum_size.x = 86
		field.value_changed.connect(func(_value: float) -> void: _on_scope_change())
		row.add_child(field)
		_region.append(field)
	_wall.text = "Allow Hard Wall"
	_empty.text = "Allow Empty"
	_wall.button_pressed = true
	_empty.button_pressed = true
	_wall.toggled.connect(func(_value: bool) -> void: _retire_on_human_change())
	_empty.toggled.connect(func(_value: bool) -> void: _retire_on_human_change())
	row = HFlowContainer.new()
	row.add_child(_wall)
	row.add_child(_empty)
	_form.add_child(row)
	_protection_label.text = "Protected areas: none (agent-edit exclusion)"
	_protection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(_protection_label)
	_guard.text = "Protect a rectangle"
	_guard.toggled.connect(func(_value: bool) -> void: _on_scope_change())
	_form.add_child(_guard)
	var protection_row := HFlowContainer.new()
	_form.add_child(protection_row)
	for spec: Array in [["PX",-2147483648.0,2147483647.0,0.0],
			["PY",-2147483648.0,2147483647.0,0.0],
			["PW",1.0,4096.0,4.0],["PH",1.0,4096.0,4.0]]:
		var caption := Label.new()
		caption.text = str(spec[0])
		protection_row.add_child(caption)
		var field := SpinBox.new()
		field.min_value = spec[1]
		field.max_value = spec[2]
		field.step = 1.0
		field.rounded = true
		field.value = spec[3]
		field.custom_minimum_size.x = 86
		field.value_changed.connect(func(_value: float) -> void: _on_scope_change())
		protection_row.add_child(field)
		_guard_region.append(field)
	_sync_scope_overlay()
	var activity_label := Label.new()
	activity_label.text = "Activity"
	_form.add_child(activity_label)
	_log.custom_minimum_size.y = 140
	_log.fit_content = false
	_log.scroll_following = true
	_form.add_child(_log)
	_refresh_buttons()

func bind_authoritative_dispatcher(dispatcher: Callable, world_to_screen: Callable = Callable(),
		authorizer: Callable = Callable(), retirement: Callable = Callable()) -> void:
	# Expected dispatcher(name,args,epoch,call_id,client). It MUST return via
	# client.submit_tool_result after the exclusive owner supplies a native receipt.
	_dispatcher = dispatcher
	_authorizer = authorizer
	_retirement = retirement
	proposal_overlay.set_world_to_screen(world_to_screen)
	_state.text = "Dispatcher bound; waiting for human Start."
	_refresh_buttons()

func set_protected_regions(regions: Array) -> void:
	# Actual scope/protection comes from the host, never from model text.
	_protected_regions = regions.duplicate(true)
	_on_scope_change()

func set_canvas_region_provider(provider: Callable) -> void:
	_canvas_region_provider = provider
	_whole_canvas.disabled = not provider.is_valid()

func _on_whole_canvas() -> void:
	if not _canvas_region_provider.is_valid():
		return
	var region: Variant = _canvas_region_provider.call()
	if not region is Rect2i or not region.has_area():
		_log_status("refused","Installed canvas is unavailable for the selected coordinate frame.")
		return
	_region[0].value = region.position.x
	_region[1].value = region.position.y
	_region[2].value = region.size.x
	_region[3].value = region.size.y
	_on_scope_change()

func _rect_from_fields(fields: Array[SpinBox]) -> Rect2i:
	return Rect2i(int(fields[0].value),int(fields[1].value),
		int(fields[2].value),int(fields[3].value))

func _configured_protection() -> Array:
	var result: Array = _protected_regions.duplicate(true)
	if _guard.button_pressed:
		var guard: Rect2i = _rect_from_fields(_guard_region)
		result.append({"x":guard.position.x,"y":guard.position.y,
			"width":guard.size.x,"height":guard.size.y})
	return result

func _sync_scope_overlay() -> void:
	if scope_overlay == null or _region.size() != 4 or _guard_region.size() != 4:
		return
	var protections: Array[Rect2i] = []
	for item: Variant in _configured_protection():
		if item is Rect2i:
			protections.append(item)
		elif item is Dictionary and item.has("x") and item.has("y") 				and item.has("width") and item.has("height"):
			protections.append(Rect2i(int(item.x),int(item.y),
				int(item.width),int(item.height)))
	scope_overlay.set_scope(_rect_from_fields(_region),protections)
	_protection_label.text = "Protected regions: %d; no agent edits inside" % protections.size()

func _on_scope_change() -> void:
	_sync_scope_overlay()
	_retire_on_human_change()

func invalidate_due_to_owner_change(reason: String) -> void:
	_start_nonce += 1
	if client != null:
		client.invalidate_after_human_change(reason)
	_refresh_buttons()

func _retire_on_human_change() -> void:
	_start_nonce += 1
	if client != null and client.is_active():
		client.invalidate_after_human_change("Task/scope/material configuration changed.")
	_refresh_buttons()

func _refresh_buttons() -> void:
	if client == null:
		return
	_start.disabled = client.is_active() or _start_pending or _retire_pending or not _dispatcher.is_valid()
	_stop.disabled = not client.is_active() and not _start_pending

func _on_start() -> void:
	if not _dispatcher.is_valid() or client.is_active() or _start_pending or _retire_pending:
		_log_status("refused", "No native dispatcher or task already active.")
		return
	var materials: Array[String] = []
	if _wall.button_pressed:
		materials.append("Hard Wall")
	if _empty.button_pressed:
		materials.append("Empty")
	if materials.is_empty():
		_log_status("refused", "Select at least one allowed material.")
		return
	var scope := {
		"region": {
			"x": int(_region[0].value), "y": int(_region[1].value),
			"width": int(_region[2].value), "height": int(_region[3].value)
		},
		"protected_regions": _configured_protection(),
		"allowed_materials": materials
	}
	if _signed_frame.button_pressed:
		# Host-only experiment; it does not add any model-visible tool.
		scope["coordinate_frame_id"] = SignedFrame.FRAME_ID
	if _authorizer.is_valid():
		_start_pending = true
		var nonce: int = _start_nonce
		_refresh_buttons()
		var authorization: Dictionary = await _authorizer.call(scope)
		_start_pending = false
		if nonce != _start_nonce:
			if authorization.get("status") == "authorized" 					and _retirement.is_valid() and not _retire_pending:
				_retire_pending = true
				await _retirement.call()
				_retire_pending = false
			_refresh_buttons()
			return
		if authorization.get("status") != "authorized":
			_log_status("refused","Native task authorization: " + str(authorization.get("reason","unknown")))
			return
	if not client.begin_task(_task.text, _model.text, scope) and _retirement.is_valid():
		_retire_pending = true
		var cleanup: Dictionary = await _retirement.call()
		_retire_pending = false
		_log_status("retirement",str(cleanup.get("status","unconfirmed")))
	_refresh_buttons()

func _on_stop() -> void:
	_start_nonce += 1
	# A click can precede the native authorize_task ACK and client.begin_task.
	# Immediately request #527's native Stop even without an active HTTP
	# session. The superseded _on_start continuation must not repeat Stop.
	if _start_pending and _retirement.is_valid() and not _retire_pending:
		_retire_pending = true
		_complete_retirement.call_deferred()
	# HTTP cancellation is NOT native retirement acknowledgment.
	client.stop_task("Human Stop — API dispatch revoked; native Stop ACK is separate.")
	_refresh_buttons()

func _tool_request(tool: String, args: Dictionary, epoch: int, call_id: String) -> void:
	if not _dispatcher.is_valid():
		client.stop_task("Authoritative dispatcher disconnected; no edit attempted.")
		return
	_dispatcher.call(tool, args.duplicate(true), epoch, call_id, client)

func _proposal_updated(footprint: Array) -> void:
	if proposal_overlay != null:
		proposal_overlay.set_footprint(footprint)
	if footprint.is_empty():
		_log_status("preview", "Prepared footprint cleared.")
	else:
		_log_status("proposed", "%d native-prepared cells; host viewport projection required." % footprint.size())

func _log_status(status: String, detail: String) -> void:
	# Model/provider text is untrusted and never parsed as RichText markup.
	var line := "%s — %s" % [status, detail.substr(0, 240)]
	_lines.append(line)
	while _lines.size() > MAX_LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)
	_state.text = line
	_state.tooltip_text = line
	progress.emit(status, detail)
	_refresh_buttons()

func _task_finished(_outcome: String) -> void:
	if _retirement.is_valid() and not _retire_pending:
		_retire_pending = true
		_complete_retirement.call_deferred()
	_refresh_buttons()

func _complete_retirement() -> void:
	var result: Dictionary = await _retirement.call()
	_retire_pending = false
	if is_instance_valid(self):
		_log_status("native_retirement",str(result.get("status","unconfirmed")) +
			": " + str(result.get("reason","")))
		_refresh_buttons()

func _exit_tree() -> void:
	if client != null and client.is_active():
		client.stop_task("Panel destroyed")
	if is_instance_valid(proposal_overlay):
		if proposal_overlay.is_inside_tree():
			proposal_overlay.queue_free()
		else:
			proposal_overlay.free()
	if is_instance_valid(scope_overlay):
		if scope_overlay.is_inside_tree():
			scope_overlay.queue_free()
		else:
			scope_overlay.free()
