extends VBoxContainer
## WB-AGENT #528: opt-in UI shell. Designed to mount inside shared_workbench.gd
## once #526/#527 hands off the authoritative dispatcher and viewport mapping.
## Never creates/owns a World or claims an edit is applied from UI admission alone.

signal progress(status: String, detail: String)

const Client = preload("res://scripts/workbench_agent_client.gd")
const Overlay = preload("res://scripts/workbench_agent_proposal_overlay.gd")
const MAX_LOG_LINES := 32

var client: Node
var proposal_overlay: Control
var _dispatcher: Callable
var _authorizer: Callable
var _retirement: Callable
var _start_pending := false
var _retire_pending := false
var _start_nonce := 0
var _task := TextEdit.new()
var _model := LineEdit.new()
var _region: Array[SpinBox] = []
var _wall := CheckBox.new()
var _empty := CheckBox.new()
var _start := Button.new()
var _stop := Button.new()
var _log := RichTextLabel.new()
var _state := Label.new()
var _protection_label := Label.new()
var _protected_regions: Array = []
var _lines: Array[String] = []

func _ready() -> void:
	client = Client.new()
	add_child(client)
	client.tool_requested.connect(_tool_request)
	client.status_changed.connect(_log_status)
	client.proposal_changed.connect(_proposal_updated)
	client.task_finished.connect(_task_finished)
	proposal_overlay = Overlay.new()
	name = "Agent authoring (opt-in)"
	var heading := Label.new()
	heading.text = "Agent authoring (experimental / opt-in)"
	add_child(heading)
	_task.custom_minimum_size = Vector2(240, 66)
	_task.placeholder_text = "Describe the apparatus to build and test."
	_task.text_changed.connect(_retire_on_human_change)
	add_child(_task)
	_model.placeholder_text = "Vision-capable Responses model ID (required)"
	_model.text_changed.connect(func(_value: String) -> void: _retire_on_human_change())
	add_child(_model)
	var row := HFlowContainer.new()
	add_child(row)
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
		field.value_changed.connect(func(_value: float) -> void: _retire_on_human_change())
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
	add_child(row)
	_protection_label.text = "Protection: awaiting authoritative owner regions"
	add_child(_protection_label)
	var actions := HBoxContainer.new()
	_start.text = "Start (authorize within scope)"
	_start.pressed.connect(_on_start)
	_stop.text = "Stop"
	_stop.disabled = true
	_stop.pressed.connect(_on_stop)
	actions.add_child(_start)
	actions.add_child(_stop)
	add_child(actions)
	_state.text = "Unbound: native authoring dispatcher pending #526/#527 handoff."
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_state)
	_log.custom_minimum_size.y = 96
	_log.fit_content = false
	_log.scroll_following = true
	add_child(_log)
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
	_protection_label.text = "Protected regions: %d (authoritative owner)" % regions.size()
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
		"protected_regions": _protected_regions.duplicate(true),
		"allowed_materials": materials
	}
	if scope.region.width * scope.region.height > 4096:
		_log_status("refused","Authorized scope exceeds 4096 native cells.")
		return
	if _authorizer.is_valid():
		_start_pending = true
		var nonce: int = _start_nonce
		_refresh_buttons()
		var authorization: Dictionary = await _authorizer.call(scope)
		_start_pending = false
		if nonce != _start_nonce:
			if authorization.get("status") == "authorized" and _retirement.is_valid():
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
	# #527 adapter must separately confirm stop at its bounded native boundary.
	# Client Stop cancels new API dispatch; does not claim a native Stop ACK.
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
