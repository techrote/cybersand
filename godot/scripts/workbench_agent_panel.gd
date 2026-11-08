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
const TrafficWindow = preload("res://scripts/workbench_agent_traffic_window.gd")
const MODEL_HISTORY_PATH := "user://workbench-agent-models.cfg"
const DEFAULT_MODEL := "gpt-5.6-luna"
const MAX_MODEL_HISTORY := 12

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
var _request_limit := SpinBox.new()
var _tool_limit := SpinBox.new()
var _token_limit := SpinBox.new()
var _timeout_limit := SpinBox.new()
var _cell_limit := SpinBox.new()
var _model_history := MenuButton.new()
var _recent_models: Array[String] = []
var _traffic: Window
var _usage := Label.new()
var _dashboard_clock := 0.0
var _blocked_reason := ""
var _native_unconfirmed := false
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
	client.model_report_received.connect(_record_model_report)
	client.proposal_changed.connect(_proposal_updated)
	client.task_finished.connect(_task_finished)
	if client.has_signal("diagnostic_event"):
		client.connect("diagnostic_event", _on_diagnostic_event)
	proposal_overlay = Overlay.new()
	scope_overlay = ScopeOverlay.new()
	name = "Agent authoring (opt-in)"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",4)
	# Title and task actions stay pinned while the form scrolls.
	var actions := HBoxContainer.new()
	actions.name = "AgentActions"
	var heading := Label.new()
	heading.name = "AgentHeading"
	heading.text = "Agent authoring"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(heading)
	_start.name = "AgentStart"
	_start.text = "Start"
	_start.tooltip_text = "Authorize the task, limits, working area and allowed materials."
	_start.focus_mode = Control.FOCUS_NONE
	_start.pressed.connect(_on_start)
	_stop.name = "AgentStop"
	_stop.text = "Stop"
	_stop.focus_mode = Control.FOCUS_NONE
	_stop.disabled = true
	_stop.pressed.connect(_on_stop)
	actions.add_child(_start)
	actions.add_child(_stop)
	add_child(actions)
	var dashboard := HBoxContainer.new()
	_state.name = "AgentState"
	_state.text = "Idle · not connected"
	_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_state.clip_text = true
	dashboard.add_child(_state)
	var traffic_button := Button.new()
	traffic_button.text = "Traffic…"
	traffic_button.tooltip_text = "Open full request, response, tool and native-acknowledgement traffic. Copy or save JSONL."
	traffic_button.pressed.connect(_show_traffic)
	dashboard.add_child(traffic_button)
	add_child(dashboard)
	_usage.name = "AgentUsage"
	_usage.add_theme_font_size_override("font_size",12)
	_usage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_usage.max_lines_visible = 2
	add_child(_usage)
	_form_scroll.name = "AgentFormScroll"
	_form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_form_scroll.mouse_force_pass_scroll_events = false
	add_child(_form_scroll)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form.name = "AgentForm"
	_form.add_theme_constant_override("separation",5)
	_form_scroll.add_child(_form)
	_task.custom_minimum_size = Vector2(240,190)
	_task.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_task.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_task.placeholder_text = "What would you like to build or change?"
	_task.tooltip_text = "Describe your goal. Start authorizes the selected area and limits."
	_task.text_changed.connect(_retire_on_human_change)
	_form.add_child(_task)
	var model_row := HBoxContainer.new()
	_model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model.placeholder_text = DEFAULT_MODEL
	_model.tooltip_text = "Model ID. Type a name or choose a recently used model from the arrow."
	_load_model_history()
	_model.text = DEFAULT_MODEL
	_model.text_changed.connect(func(_value: String) -> void: _retire_on_human_change())
	model_row.add_child(_model)
	_model_history.text = "▾"
	_model_history.tooltip_text = "Recent models"
	_model_history.get_popup().id_pressed.connect(_select_model_history)
	_rebuild_model_history()
	model_row.add_child(_model_history)
	_form.add_child(model_row)
	var budgets := GridContainer.new()
	budgets.columns = 2
	budgets.add_theme_constant_override("h_separation",5)
	budgets.add_theme_constant_override("v_separation",4)
	budgets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_child(budgets)
	_add_budget_control(budgets,"API",_request_limit,Client.DEFAULT_REQUEST_BUDGET,Client.MAX_REQUEST_BUDGET,
		"Maximum API requests in this task. Higher limits can increase charges.")
	_add_budget_control(budgets,"Tools",_tool_limit,Client.DEFAULT_TOOL_BUDGET,Client.MAX_TOOL_BUDGET,
		"Maximum model tool calls in this task.")
	_add_budget_control(budgets,"Toks",_token_limit,Client.DEFAULT_TOKEN_BUDGET,Client.MAX_TOKEN_BUDGET,
		"Maximum output tokens per response, not a total token budget. Must fit the model.")
	_add_budget_control(budgets,"Time",_timeout_limit,Client.DEFAULT_REQUEST_TIMEOUT,Client.MAX_REQUEST_TIMEOUT,
		"Timeout in seconds for each API request. Stop cancels without waiting for this deadline.")
	var area_actions := HBoxContainer.new()
	_add_budget_control(area_actions,"Cells",_cell_limit,16384,65536,
		"Maximum cells in one edit or inspection; authorized at Start. This is not a task-wide edit quota.")
	_whole_canvas.text = "Whole canvas"
	_whole_canvas.tooltip_text = "Set the working area to the installed canvas. Calls stay within the Cells limit."
	_whole_canvas.disabled = true
	_whole_canvas.pressed.connect(_on_whole_canvas)
	area_actions.add_child(_whole_canvas)
	_form.add_child(area_actions)
	_add_rectangle_row(_region,["X","Y","W","H"],[0,0,32,32])
	_wall.text = "Hard Wall"
	_empty.text = "Empty"
	_wall.tooltip_text = "Allow the agent to place Hard Wall."
	_empty.tooltip_text = "Allow the agent to erase cells to Empty."
	_wall.button_pressed = true
	_empty.button_pressed = true
	_wall.toggled.connect(func(_value: bool) -> void: _retire_on_human_change())
	_empty.toggled.connect(func(_value: bool) -> void: _retire_on_human_change())
	var materials := HBoxContainer.new()
	materials.add_child(_wall)
	materials.add_child(_empty)
	_guard.text = "Protect"
	_guard.tooltip_text = "Exclude the rectangle below from agent edits."
	_guard.toggled.connect(func(_value: bool) -> void: _on_scope_change())
	materials.add_child(_guard)
	_form.add_child(materials)
	_add_rectangle_row(_guard_region,["PX","PY","PW","PH"],[0,0,4,4])
	# The translated signed fixture is a test adapter, not a normal authoring mode.
	# Keep this detached control for explicit frozen-fixture automation only.
	_signed_frame.button_pressed = false
	_signed_frame.toggled.connect(func(_value: bool) -> void: _on_scope_change())
	_sync_scope_overlay()
	_traffic = TrafficWindow.new()
	_traffic.name = "AgentTraffic"
	add_child(_traffic)
	_traffic.hide()
	_refresh_buttons()

func _process(delta: float) -> void:
	_dashboard_clock += delta
	if _dashboard_clock >= 0.2:
		_dashboard_clock = 0.0
		_refresh_dashboard()

func _add_rectangle_row(fields: Array[SpinBox], captions: Array, values: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",2)
	_form.add_child(row)
	for i: int in range(4):
		var field := SpinBox.new()
		field.min_value = -2147483648.0 if i < 2 else 1.0
		field.max_value = 2147483647.0 if i < 2 else 4096.0
		field.step = 1.0
		field.rounded = true
		field.prefix = str(captions[i])
		field.value = values[i]
		field.custom_minimum_size.x = 62
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.get_line_edit().expand_to_text_length = false
		field.tooltip_text = ["Left cell coordinate","Top cell coordinate","Width in cells","Height in cells"][i]
		field.value_changed.connect(func(_value: float) -> void: _on_scope_change())
		row.add_child(field)
		fields.append(field)

func _load_model_history() -> void:
	_recent_models.assign([DEFAULT_MODEL])
	var config := ConfigFile.new()
	if config.load(MODEL_HISTORY_PATH) != OK:
		return
	var saved: Variant = config.get_value("models","recent",[])
	if saved is Array or saved is PackedStringArray:
		for value: Variant in saved:
			var model := str(value)
			if _is_history_model(model) and not _recent_models.has(model):
				_recent_models.append(model)
			if _recent_models.size() >= MAX_MODEL_HISTORY:
				break

func _is_history_model(model: String) -> bool:
	if model.is_empty() or model.length() > 128 or model.begins_with("sk-"):
		return false
	for character: String in model:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._:/".contains(character):
			return false
	return true

func _remember_model() -> void:
	var model := _model.text.strip_edges()
	if not _is_history_model(model):
		return
	_recent_models.erase(model)
	_recent_models.push_front(model)
	while _recent_models.size() > MAX_MODEL_HISTORY:
		_recent_models.pop_back()
	var config := ConfigFile.new()
	config.set_value("models","recent",_recent_models)
	config.save(MODEL_HISTORY_PATH)
	_rebuild_model_history()

func _rebuild_model_history() -> void:
	var popup := _model_history.get_popup()
	popup.clear()
	for i: int in range(_recent_models.size()):
		popup.add_item(_recent_models[i],i)

func _select_model_history(index: int) -> void:
	if index >= 0 and index < _recent_models.size():
		_model.text = _recent_models[index]
		_retire_on_human_change()

func _refresh_dashboard() -> void:
	if client == null:
		return
	var snapshot: Dictionary = client.activity_snapshot() if client.has_method("activity_snapshot") else {}
	var stage := str(snapshot.get("stage","Ready" if _dispatcher.is_valid() else "Not connected"))
	var state := str(snapshot.get("state","Active" if client.is_active() else "Idle"))
	if _start_pending:
		state = "Starting"
		stage = "Waiting for native authorization"
	elif _retire_pending:
		state = "Stopping"
		stage = "Waiting for native acknowledgement"
	elif _native_unconfirmed:
		state = "Unconfirmed"
		stage = "Native Stop unconfirmed; reopen workbench"
	elif not _blocked_reason.is_empty():
		state = "Blocked"
		stage = _blocked_reason
	_state.text = "%s · %s" % [state.capitalize(),stage]
	_state.tooltip_text = _state.text
	_state.modulate = Color(1.0,0.78,0.35) if client.is_active() or _start_pending or _retire_pending else (Color(1.0,0.55,0.5) if not _blocked_reason.is_empty() or _native_unconfirmed else Color(0.65,0.9,0.72))
	var input_tokens := int(snapshot.get("input_tokens",-1))
	var output_tokens := int(snapshot.get("output_tokens",-1))
	var usage_text := "API %d/%d  Tools %d/%d  In %s  Out %s" % [
		int(snapshot.get("requests",0)),int(snapshot.get("request_limit",_request_limit.value)),
		int(snapshot.get("tools",0)),int(snapshot.get("tool_limit",_tool_limit.value)),
		str(input_tokens) if input_tokens >= 0 else "?",str(output_tokens) if output_tokens >= 0 else "?"]
	var complete: bool = bool(snapshot.get("usage_complete",false))
	if not complete and (input_tokens >= 0 or output_tokens >= 0):
		usage_text += " (partial)"
	_usage.text = usage_text
	_usage.tooltip_text = usage_text + "\nToken counts are provider-reported " + ("task totals." if complete else "subtotals; some usage was not supplied.") + " ? means unknown. Toks limits each response."

func _show_traffic() -> void:
	_refresh_traffic()
	_traffic.popup_centered_ratio(0.8)

func _refresh_traffic() -> void:
	if client.has_method("diagnostic_records"):
		var directory: String = client.diagnostic_directory() if client.has_method("diagnostic_directory") else ""
		var metadata: Dictionary = client.activity_snapshot() if client.has_method("activity_snapshot") else {}
		_traffic.set_records(client.diagnostic_records(),directory,metadata)
		if client.has_method("export_diagnostics"):
			_traffic.exporter = client.export_diagnostics

func _on_diagnostic_event(_record: Dictionary) -> void:
	if is_instance_valid(_traffic) and _traffic.visible:
		_refresh_traffic()
	_refresh_dashboard()

func _diagnostic(kind: String, payload: Variant) -> void:
	if client != null and client.has_method("record_diagnostic"):
		client.record_diagnostic(kind,payload)

func bind_authoritative_dispatcher(dispatcher: Callable, world_to_screen: Callable = Callable(),
		authorizer: Callable = Callable(), retirement: Callable = Callable()) -> void:
	# Expected dispatcher(name,args,epoch,call_id,client). It MUST return via
	# client.submit_tool_result after the exclusive owner supplies a native receipt.
	_dispatcher = dispatcher
	_authorizer = authorizer
	_retirement = retirement
	proposal_overlay.set_world_to_screen(world_to_screen)
	_blocked_reason = ""
	_refresh_buttons()

func set_protected_regions(regions: Array) -> void:
	# Actual scope/protection comes from the host, never from model text.
	_protected_regions = regions.duplicate(true)
	_on_scope_change()

func set_canvas_region_provider(provider: Callable) -> void:
	_canvas_region_provider = provider
	_whole_canvas.disabled = not provider.is_valid()

func _add_budget_control(parent: Container, title: String, field: SpinBox, initial: int, maximum: int, help: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",3)
	var label := Label.new()
	label.text = title
	label.tooltip_text = help
	row.add_child(label)
	field.min_value = 1
	field.max_value = maximum
	field.step = 1
	field.rounded = true
	field.value = initial
	field.custom_minimum_size.x = 88
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.get_line_edit().expand_to_text_length = false
	field.tooltip_text = help
	field.value_changed.connect(func(_value: float) -> void: _retire_on_human_change())
	row.add_child(field)
	parent.add_child(row)

func _set_budgets(requests: int, tools: int, tokens: int, timeout_seconds: int = Client.DEFAULT_REQUEST_TIMEOUT) -> void:
	for field: SpinBox in [_request_limit,_tool_limit,_token_limit,_timeout_limit]:
		field.get_line_edit().release_focus()
	_request_limit.value = requests
	_tool_limit.value = tools
	_token_limit.value = tokens
	_timeout_limit.value = timeout_seconds

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


func _on_scope_change() -> void:
	_sync_scope_overlay()
	_retire_on_human_change()

func invalidate_due_to_owner_change(reason: String) -> void:
	_start_nonce += 1
	if client != null:
		client.invalidate_after_human_change(reason)
	_refresh_buttons()

func _retire_on_human_change() -> void:
	_blocked_reason = ""
	_start_nonce += 1
	if client != null and client.is_active():
		client.invalidate_after_human_change("Task/scope/material configuration changed.")
	_refresh_buttons()

func _refresh_buttons() -> void:
	if client == null:
		return
	_start.disabled = client.is_active() or _start_pending or _retire_pending or _native_unconfirmed or not _dispatcher.is_valid()
	_stop.disabled = not client.is_active() and not _start_pending
	_refresh_dashboard()

func _on_start() -> void:
	if not _dispatcher.is_valid() or client.is_active() or _start_pending or _retire_pending or _native_unconfirmed:
		_log_status("refused", "Native Stop unconfirmed; inspect Traffic and reopen the workbench." if _native_unconfirmed else "No native dispatcher or task already active.")
		return
	# Start has FOCUS_NONE: commit typed numbers even if the edit never lost focus.
	for field: SpinBox in [_request_limit,_tool_limit,_token_limit,_timeout_limit,_cell_limit] + _region + _guard_region:
		if field.get_line_edit().has_focus():
			field.apply()
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
		"allowed_materials": materials,
		"cell_limit": int(_cell_limit.value)
	}
	if _signed_frame.button_pressed:
		# Host-only experiment; it does not add any model-visible tool.
		scope["coordinate_frame_id"] = SignedFrame.FRAME_ID
	# A blank task/model or missing local API key must not acquire native
	# authority just to fail and retire it moments later. Keep the same
	# validation in begin_task for changes during the async owner ACK.
	client.request_budget = int(_request_limit.value)
	client.tool_budget = int(_tool_limit.value)
	client.token_budget = int(_token_limit.value)
	client.request_timeout_seconds = _timeout_limit.value
	var launch_problem: String = client.launch_problem(_task.text, _model.text, scope)
	if not launch_problem.is_empty():
		_log_status("refused", launch_problem)
		return
	if _authorizer.is_valid():
		_start_pending = true
		var nonce: int = _start_nonce
		_refresh_buttons()
		_diagnostic("native_authorization_request",scope)
		var authorization: Dictionary = await _authorizer.call(scope)
		_diagnostic("native_authorization_ack",authorization)
		_start_pending = false
		if nonce != _start_nonce:
			if authorization.get("status") == "authorized" 					and _retirement.is_valid() and not _retire_pending:
				_retire_pending = true
				_diagnostic("native_retirement_request",{"reason":"superseded_authorization"})
				var obsolete_retirement: Dictionary = await _retirement.call()
				_record_retirement_ack(obsolete_retirement)
				_retire_pending = false
			_refresh_buttons()
			return
		if authorization.get("status") != "authorized":
			_log_status("refused","Native task authorization: " + str(authorization.get("reason","unknown")))
			return
	_native_unconfirmed = false
	if not client._fake_transport:
		_remember_model()
	# Recheck after native admission; the client handles a changed environment.
	if not client.begin_task(_task.text, _model.text, scope) and _retirement.is_valid():
		_retire_pending = true
		_diagnostic("native_retirement_request",{"reason":"failed_client_start"})
		var cleanup: Dictionary = await _retirement.call()
		_record_retirement_ack(cleanup)
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

func _record_model_report(report: String) -> void:
	# The actual assistant text was previously discarded at the final
	# Responses turn. Show it in Activity, explicitly NOT as native evidence.
	var plain: String = report.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	var line := "Model report (unverified; native receipts are authoritative): " + plain.substr(0, 1024)
	_lines.append(line)
	while _lines.size() > MAX_LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)
	_log.tooltip_text = line
	progress.emit("model_report_unverified", plain)

func _log_status(status: String, detail: String) -> void:
	if status == "refused":
		_diagnostic("panel.refused",{"detail":detail})
	if status in ["refused","error"] and not client.is_active():
		_blocked_reason = detail.substr(0,240)
	# Model/provider text is untrusted and never parsed as RichText markup.
	var line := "%s — %s" % [status, detail.substr(0, 240)]
	_lines.append(line)
	while _lines.size() > MAX_LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)
	progress.emit(status, detail)
	_refresh_buttons()

func _task_finished(_outcome: String) -> void:
	if _retirement.is_valid() and not _retire_pending:
		_retire_pending = true
		_complete_retirement.call_deferred()
	_refresh_buttons()

func _record_retirement_ack(result: Dictionary) -> void:
	_diagnostic("native_retirement_ack",result)
	_native_unconfirmed = result.get("status") != "retired"

func _complete_retirement() -> void:
	_diagnostic("native_retirement_request",{})
	var result: Dictionary = await _retirement.call()
	_record_retirement_ack(result)
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
	for detached: Node in [_signed_frame,_log,_protection_label]:
		if is_instance_valid(detached) and not detached.is_inside_tree():
			detached.free()
