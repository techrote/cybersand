extends Control

# One native World on its exclusive worker; real Rapier RIDs on main.
# Rendering only consumes the applied material/pose publication.
const Host = preload("res://scripts/object_shard_worker_host.gd")
const View = preload("res://scripts/object_shard_lab_view.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
const Presets = preload("res://scripts/object_shard_lab_presets.gd")
const MAX_QUEUED_CUTS: int = 256
const MAX_UI_DISPATCH: int = 16
const SAMPLE_CAPACITY: int = 4096
const BRUSH_NAMES: Array[String] = ["Erase", "Wood", "Sand", "Water", "Fire", "Ignite", "Inspect"]
const BRUSH_MATERIALS: Array[int] = [0, 7, 2, 3, 6, -2, -1]
var host = Host.new()
var view
var selector: OptionButton
var brush_select: OptionButton
var status_label: Label
var metrics_label: Label
var report_label: Label
var help_label: Label
var inventory_label: RichTextLabel
var inspection_label: RichTextLabel
var run_button: Button
var delay_box: CheckBox
var burner_box: CheckBox
var config_panel: VBoxContainer
var seed_box: SpinBox
var pump_selector: OptionButton
var receipt_pump_usec: int = 8000 # Experimental evaluator default; no normal Workbench default change.
var running: bool = false
var closing: bool = false
var close_destination: String = ""
var close_dispatched: bool = false
var previous_auto_accept_quit: bool = true
var queued_cuts: Array[Dictionary] = []
var last_publication: int = -1
var opened_usec: int = 0
var last_export: String = ""
var loading: bool = true
var setup_cursor: int = 0
var setup_edits: Array[Dictionary] = []
var setup_waiting: bool = false
var setup_failed: bool = false
var pending_preset: Dictionary = {}
var selected_preset: Dictionary = {}
var replacing_owner: bool = false
var next_tick_usec: int = 0
var last_requested_visible_tick: int = -1
var last_burner_tick: int = -1
var authored_fixture_fire: int = 0
var requested_fixture_fire: int = 0
var _fixture_actions: Dictionary = {}
var _last_action_observed: int = 0
var last_inspection_serial: int = -1
var auto_exported: bool = false
var last_hud_usec: int = 0
var last_publication_usec: int = 0
var pointer_queued: int = 0
var pointer_refused: int = 0
var pointer_cancelled: int = 0
var pointer_dispatched: int = 0
var ui_samples: Dictionary = {"input_to_host_usec": [], "publication_upload_usec": [],
	"frame_callback_usec": [], "publication_interval_usec": [],
	"frame_interval_usec": [], "active_rapier_frame_interval_usec": []}
var _last_process_start_usec: int = 0
var ui_sample_totals: Dictionary = {}


func _ready() -> void:
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_window().title = "CyberSand · ObjectShard continuous play · Draft / HOLD"
	get_window().size = Vector2i(1280, 840)
	get_window().min_size = Vector2i(1000, 680)
	get_window().content_scale_size = Vector2i(1280, 840)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://ObjectShardPreflightReports"))
	_begin_owner(Presets.definition(1))


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("0c121b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 9)
	margin.add_child(panel)
	var title := Label.new()
	title.text = "OBJECTSHARD · CONTINUOUS PLAY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("b2e2e8"))
	panel.add_child(title)
	var scope := Label.new()
	scope.text = "Experimental worker / Rapier integration rehearsal · one native material owner · Draft / HOLD"
	scope.add_theme_color_override("font_color", Color("a5b5c5"))
	panel.add_child(scope)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	panel.add_child(row)
	selector = OptionButton.new()
	selector.custom_minimum_size.x = 265
	for text: String in Presets.TITLES:
		selector.add_item(text)
	row.add_child(selector)
	selector.item_selected.connect(_change_scenario)
	run_button = _button(row, "Resume", _toggle_run)
	_button(row, "Single step", _single_step)
	_button(row, "Reset", _reset)
	_button(row, "Configuration", func() -> void: config_panel.visible = not config_panel.visible)
	_button(row, "Export bug report", _export_and_open)
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 10)
	panel.add_child(tools)
	var brush_label := Label.new()
	brush_label.text = "Left drag:"
	tools.add_child(brush_label)
	brush_select = OptionButton.new()
	for text: String in BRUSH_NAMES:
		brush_select.add_item(text)
	tools.add_child(brush_select)
	_button(tools, "Cut lower support", _cut_support)
	_button(tools, "Erode resting cell", _erode_resting_cell)
	var pointer_label := Label.new()
	pointer_label.text = "Right click inspects · edit while running"
	pointer_label.add_theme_color_override("font_color", Color("a5b5c5"))
	tools.add_child(pointer_label)
	config_panel = VBoxContainer.new()
	config_panel.visible = false
	panel.add_child(config_panel)
	var settings := HFlowContainer.new()
	settings.add_theme_constant_override("h_separation", 12)
	config_panel.add_child(settings)
	var overlays := CheckBox.new()
	overlays.text = "Shapes / centre of mass / pocket"
	settings.add_child(overlays)
	overlays.toggled.connect(func(value: bool) -> void: view.overlays = value; view.queue_redraw())
	burner_box = CheckBox.new()
	burner_box.text = "External Fire burner"
	settings.add_child(burner_box)
	burner_box.toggled.connect(func(value: bool) -> void:
		last_burner_tick = -1
		if not loading and host.session > 0:
			host.capture.write("event", int(host.frame.get("tick", 0)), {"kind": "ExternalBurnerSetting", "enabled": value})
		view.fixture_enabled = value)
	delay_box = CheckBox.new()
	delay_box.text = "Hold worker receipts (diagnostic)"
	settings.add_child(delay_box)
	delay_box.toggled.connect(func(value: bool) -> void: host.set_receipt_hold(value))
	var seed_row := HBoxContainer.new()
	config_panel.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Scenario seed (applies on Reset):"
	seed_row.add_child(seed_label)
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 1000000
	seed_box.step = 1
	seed_box.value = 12
	seed_row.add_child(seed_box)
	var pump_label := Label.new()
	pump_label.text = "  Receipt work:"
	seed_row.add_child(pump_label)
	pump_selector = OptionButton.new()
	pump_selector.add_item("0 ms (control)", 0)
	pump_selector.add_item("4 ms soft budget", 4000)
	pump_selector.add_item("8 ms bounded rendezvous", 8000)
	pump_selector.add_item("12 ms bounded rendezvous", 12000)
	pump_selector.select(2)
	pump_selector.tooltip_text = "Explicit soft rendezvous budget. A handler already executing may exceed it; results include real elapsed work and host retains all motion fences."
	seed_row.add_child(pump_selector)
	pump_selector.item_selected.connect(_select_receipt_pump)
	var limits := Label.new()
	limits.text = "3 bodies · exact geometry limits · 16 motion segments maximum · diagnostic hold waits at a receipt barrier"
	limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limits.add_theme_font_size_override("font_size", 12)
	config_panel.add_child(limits)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	view = View.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(600, 360)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(view)
	view.cell_pressed.connect(_cell)
	view.stroke_requested.connect(_stroke)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 320
	body.add_child(side)
	inventory_label = RichTextLabel.new()
	inventory_label.bbcode_enabled = true
	inventory_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_label.custom_minimum_size = Vector2(320, 180)
	inventory_label.add_theme_font_size_override("normal_font_size", 13)
	side.add_child(inventory_label)
	inspection_label = RichTextLabel.new()
	inspection_label.bbcode_enabled = true
	inspection_label.custom_minimum_size = Vector2(320, 100)
	inspection_label.text = "Right click to inspect a real material owner.\nMoving cuts retain the observed cell identity."
	inspection_label.add_theme_font_size_override("normal_font_size", 13)
	side.add_child(inspection_label)
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(help_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(status_label)
	metrics_label = Label.new()
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metrics_label.add_theme_font_size_override("font_size", 12)
	metrics_label.add_theme_color_override("font_color", Color("a5b5c5"))
	panel.add_child(metrics_label)
	report_label = Label.new()
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.add_theme_font_size_override("font_size", 12)
	report_label.text = "Cut → detach → fall → settle → keep editing. Material and accepted pose publish together."
	panel.add_child(report_label)


func _select_receipt_pump(index: int) -> void:
	receipt_pump_usec = clampi(pump_selector.get_item_id(index), 0, Host.MAX_RECEIPT_PUMP_USEC)
	if host.session > 0:
		host.capture.write("event", int(host.frame.get("tick", 0)),
			{"kind": "ReceiptPumpSetting", "loop_budget_usec": receipt_pump_usec, "notifications": false})


func _begin_owner(preset: Dictionary) -> void:
	var previous_generation: int = int(host.generation)
	if host.state == "Closed":
		host = Host.new()
	close_destination = ""
	close_dispatched = false
	selected_preset = preset.duplicate(true)
	opened_usec = Time.get_ticks_usec()
	_last_process_start_usec = 0
	last_publication = -1
	last_publication_usec = 0
	last_burner_tick = -1
	last_requested_visible_tick = -1
	last_inspection_serial = -1
	authored_fixture_fire = 0
	requested_fixture_fire = 0
	_fixture_actions.clear()
	_last_action_observed = 0
	setup_cursor = 0
	setup_waiting = false
	setup_failed = false
	loading = true
	setup_edits = Presets.edits(selected_preset)
	burner_box.set_pressed_no_signal(bool(selected_preset.burner))
	help_label.text = Presets.hint(int(selected_preset.id))
	var trace: String = "user://ObjectShardPreflightReports/actions-%d-%d.jsonl" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var opened: Dictionary = host.open({"scenario": int(selected_preset.scenario), "seed": int(selected_preset.seed),
		"width": int(selected_preset.width), "height": int(selected_preset.height)},
		maxi(previous_generation + 1, Time.get_ticks_usec()), trace)
	host.set_event_driven(false)
	if not opened.get("ok", false):
		setup_failed = true
		report_label.text = "Native owner could not open: " + str(opened)


func _process(_delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	if _last_process_start_usec > 0:
		var elapsed_usec: int = started - _last_process_start_usec
		_sample("frame_interval_usec", elapsed_usec)
		if host.bridge != null and not host.bridge.bodies.is_empty():
			_sample("active_rapier_frame_interval_usec", elapsed_usec)
	_last_process_start_usec = started
	# Admit newly observed pointer intent before a poll can schedule another
	# interval. The next interval is requested once its predecessor was shown.
	if not loading and not replacing_owner and not closing and not host.failed:
		_dispatch_pointer_intents()
	host.poll(not delay_box.button_pressed or closing or replacing_owner or loading or host.state == "Resetting")
	if closing:
		if host.state == "Closed":
			_finish_exit()
		elif host.state == "ShutdownHeld":
			closing = false
			report_label.text = host.status + " · Owner retained. Export evidence, then retry F2 or window close."
		return
	if replacing_owner:
		if host.state == "Closed":
			replacing_owner = false
			_begin_owner(pending_preset)
			pending_preset = {}
		elif host.state == "ShutdownHeld":
			replacing_owner = false
			setup_failed = true
			report_label.text = host.status + " · Old owner retained; replacement did not start."
		_update_hud()
		return
	if loading:
		_finish_setup()
	elif not host.failed:
		_dispatch_pointer_intents()
		var visible_tick: int = int(view.frame.get("tick", -1))
		if (running and Time.get_ticks_usec() >= next_tick_usec and visible_tick > last_requested_visible_tick
			and visible_tick == int(host.publication.get("tick", -2))):
			var requested: Dictionary = host.request_tick()
			if requested.get("ok", false):
				last_requested_visible_tick = visible_tick
				next_tick_usec = Time.get_ticks_usec() + 16667
		_feed_burner()
	else:
		running = false
		run_button.text = "Resume"
		if not auto_exported:
			auto_exported = true
			_export()
	# Start this callback's admitted work immediately, then briefly rendezvous
	# with the exclusive worker. Neither operation grants extra semantic time.
	# The pump checks its soft budget between complete receipt handlers.
	host.poll(not delay_box.button_pressed or closing or replacing_owner or loading or host.state == "Resetting")
	host.pump_receipts(receipt_pump_usec)
	# Submit the latest coherent publication after this frame's receipt work.
	if host.publication_sequence != last_publication and not host.publication.is_empty():
		var now: int = Time.get_ticks_usec()
		if last_publication_usec > 0:
			_sample("publication_interval_usec", now - last_publication_usec)
		last_publication_usec = now
		# No live RID override: the material and pose share this applied receipt.
		view.present(host.publication, [])
		view.fixture_cells = Presets.burner_band(host.publication)
		view.fixture_enabled = burner_box.button_pressed
		last_publication = host.publication_sequence
		_sample("publication_upload_usec", Time.get_ticks_usec() - now)
		_mark_visible(host, last_publication)
	_collect_action_results()
	_update_inspection()
	_update_hud()
	_sample("frame_callback_usec", Time.get_ticks_usec() - started)


func _mark_visible(owner, sequence: int) -> void:
	# A real rendered frame receipt is distinct from CPU texture submission.
	# Headless execution cannot supply visible-frame timing.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	if owner == host and sequence == last_publication and not replacing_owner:
		host.mark_presented(sequence)


func _finish_setup() -> void:
	if setup_failed or host.failed or host.state != "Idle" or not host.actions.is_empty():
		return
	if setup_waiting:
		var result: Dictionary = host.last_author_result
		setup_waiting = false
		if not result.get("ok", false) or int(result.get("refused", 0)) > 0:
			setup_failed = true
			report_label.text = "Fixture authoring refused; exact partial owner retained. Reset to retry: " + str(result)
			return
	if setup_cursor < setup_edits.size():
		var limit: int = mini(setup_cursor + 32, setup_edits.size())
		var batch: Array[Dictionary] = []
		for operation: Dictionary in setup_edits.slice(setup_cursor, limit):
			var normalized: Dictionary = operation.duplicate(true)
			for key: String in ["state_a", "state_b", "temperature"]:
				if not normalized.has(key):
					normalized[key] = 200 if key == "temperature" else 0
			batch.append(normalized)
		var accepted: Dictionary = host.author_batch(batch)
		if accepted.get("ok", false):
			setup_waiting = true
			setup_cursor = limit
		else:
			setup_failed = true
			report_label.text = "Fixture admission refused: " + str(accepted)
		return
	loading = false
	opened_usec = Time.get_ticks_usec()
	next_tick_usec = 0
	auto_exported = false
	report_label.text = "Native material ready · Resume, then cut while it runs."
	host.capture.write("event", int(host.frame.get("tick", 0)), {"kind": "PresetReady", "preset": selected_preset, "authored_edits": setup_edits.size()})


func _dispatch_pointer_intents() -> void:
	var consumed: int = 0
	while not queued_cuts.is_empty() and consumed < MAX_UI_DISPATCH and host.actions.size() < Host.ACTION_CAPACITY:
		var intent: Dictionary = queued_cuts[0]
		var result: Dictionary = host.queue_action(str(intent.action), intent.parameters, int(intent.input_usec))
		if result.get("outcome", "") in ["ActionCapacity", "Unavailable"]:
			# Backpressure retains the exact intent until admitted or explicitly reset.
			report_label.text = "Input waiting: " + str(result.outcome) + " · %d retained" % queued_cuts.size()
			break
		queued_cuts.pop_front()
		consumed += 1
		if result.get("ok", false):
			pointer_dispatched += 1
			if bool(intent.fixture):
				_fixture_actions[int(result.action_id)] = true
			_sample("input_to_host_usec", Time.get_ticks_usec() - int(intent.input_usec))
		else:
			pointer_refused += 1
			report_label.text = "Input refused: " + str(result) + " · material remains with its owner."
			host.capture.write("event", int(host.frame.get("tick", 0)), {"kind": "PointerIntentRefused", "intent": intent, "result": result})


func _button(parent: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _toggle_run() -> void:
	if loading or replacing_owner or closing or host.failed:
		return
	running = not running
	run_button.text = "Pause" if running else "Resume"
	next_tick_usec = 0
	host.capture.action(int(host.frame.get("tick", 0)), "pause", {"paused": not running}, {"ok": true})


func _single_step() -> void:
	if loading or replacing_owner or closing:
		return
	running = false
	run_button.text = "Resume"
	var result: Dictionary = host.request_tick()
	if not result.get("ok", false):
		report_label.text = "Step waiting/refused: " + str(result)


func _change_scenario(_index: int) -> void:
	_reset()


func _reset() -> void:
	if closing or replacing_owner:
		return
	running = false
	run_button.text = "Resume"
	# An explicit Reset is a new owner decision after a held shutdown.
	close_destination = ""
	delay_box.set_pressed_no_signal(false)
	pointer_cancelled += queued_cuts.size()
	host.capture.write("event", int(host.frame.get("tick", 0)), {"kind": "ExplicitUIReset", "cancelled_pointer_intents": queued_cuts.size()})
	queued_cuts.clear()
	pending_preset = Presets.definition(selector.selected + 1)
	pending_preset.seed = int(seed_box.value)
	# Canvas changes dispose the old worker before constructing the new World.
	loading = true
	replacing_owner = true
	host.close()
	setup_failed = false


func _cell(position: Vector2i, button: int) -> void:
	if loading or replacing_owner or closing:
		return
	if button == MOUSE_BUTTON_RIGHT or brush_select.selected == 6:
		_queue_intent(position, "inspect", -1)
	elif button == MOUSE_BUTTON_LEFT:
		_stroke([position], button)


func _stroke(cells: Array[Vector2i], button: int) -> void:
	if button != MOUSE_BUTTON_LEFT or loading or replacing_owner or closing:
		return
	if brush_select.selected == 6:
		if not cells.is_empty():
			_queue_intent(cells[-1], "inspect", -1)
		return
	var material: int = BRUSH_MATERIALS[brush_select.selected]
	var action: String = "ignite" if material == -2 else "edit"
	var refused: int = 0
	for position: Vector2i in cells:
		if not _queue_intent(position, action, material):
			refused += 1
	if refused > 0:
		report_label.text = "Input capacity: %d new positions refused; %d retained. Continue after the queue drains." % [refused, queued_cuts.size()]


func _queue_intent(position: Vector2i, action: String, material: int, fixture: bool = false) -> bool:
	if not _accepting_play_input():
		pointer_refused += 1
		_refuse_unavailable_input(action)
		return false
	# Pointer intent belongs to the material snapshot the view actually observed.
	# Deferred host receipts may already have published a newer, unseen pose.
	var observed: Dictionary = host.publication if fixture else view.frame
	var parameters: Dictionary = {"position": position, "target": host.capture_target(position, observed)}
	if action == "edit":
		parameters.merge({"material": material, "state_a": 255 if material == 3 else (32 if material == 6 else 0), "state_b": 0, "temperature": 650 if material == 6 else 200})
	if fixture:
		parameters["only_if_empty"] = true
	for existing: Dictionary in queued_cuts:
		# A fresh pose at the same pixel is a distinct intention. Coalesce only
		# byte-for-byte equivalent operation values and exact observed witnesses.
		if existing.action == action and existing.parameters == parameters:
			return true
	if queued_cuts.size() >= MAX_QUEUED_CUTS:
		pointer_refused += 1
		return false
	var intent: Dictionary = {"action": action, "parameters": parameters, "input_usec": Time.get_ticks_usec(), "fixture": fixture}
	queued_cuts.append(intent)
	pointer_queued += 1
	host.capture.write("event", int(host.frame.get("tick", 0)), {"kind": "PointerIntentQueued", "intent": intent})
	return true


func _cut_support() -> void:
	if not _accepting_play_input():
		_refuse_unavailable_input("cut_support")
		return
	if host.publication.is_empty():
		return
	var source: Dictionary = host.publication
	var lowest: int = -1
	for index: int in range(source.world_materials.size()):
		if int(source.world_materials[index]) == 7:
			lowest = maxi(lowest, index / int(source.width))
	var requested: int = 0
	var accepted: int = 0
	for y: int in range(maxi(0, lowest - 11), lowest + 1):
		for x: int in range(int(source.width)):
			if int(source.world_materials[y * int(source.width) + x]) == 7:
				requested += 1
				if _queue_intent(Vector2i(x, y), "edit", 0):
					accepted += 1
	report_label.text = "Lower support: %d requested, %d admitted ordinary erases. Refused cells remain visible; repeat after pending input drains." % [requested, accepted]


func _erode_resting_cell() -> void:
	if not _accepting_play_input():
		_refuse_unavailable_input("erode_resting_cell")
		return
	if host.bridge == null:
		return
	var physical: Dictionary = host.bridge.diagnostics()
	for body: Dictionary in physical.get("bodies", []):
		if not body.get("sleeping", false):
			continue
		for shard: Dictionary in host.publication.get("shards", []):
			if int(shard.id) != int(body.id):
				continue
			var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
			for at: int in range(shard.materials.size()):
				if int(shard.roles[at]) != 1:
					continue
				var point: Vector2 = transform * Vector2(float(at % int(shard.width)) + 0.5, float(at / int(shard.width)) + 0.5)
				var cell := Vector2i(floori(point.x), floori(point.y))
				var owner: Dictionary = Host._owned_cell(host.publication, cell)
				if int(owner.get("id", 0)) == int(shard.id) and int(owner.get("cell", -1)) == at:
					_queue_intent(cell, "edit", 0)
					report_label.text = "One sleeping structural cell queued; real Rapier determines the response."
					return
	report_label.text = "No sleeping structural body yet. Let a detached structure settle naturally."


func _accepting_play_input() -> bool:
	return not loading and not replacing_owner and not closing and not close_dispatched \
		and not host.failed and host.state not in ["Closing", "Closed", "ShutdownHeld"]


func _refuse_unavailable_input(action: String) -> void:
	report_label.text = "Input refused: owner is loading, replacing, closing or held. No new material command was admitted."
	host.capture.write("event", int(host.frame.get("tick", 0)), {"kind": "UIInputUnavailable", "action": action,
		"state": host.state, "closing": closing, "replacing_owner": replacing_owner, "loading": loading, "failed": host.failed})


func _feed_burner() -> void:
	if not running or not burner_box.button_pressed or host.publication.is_empty():
		return
	var tick: int = int(host.publication.tick)
	if tick == last_burner_tick or queued_cuts.size() > 192:
		return
	last_burner_tick = tick
	var source: Dictionary = host.publication
	for point: Vector2i in Presets.burner_band(source):
		if int(source.world_materials[point.y * int(source.width) + point.x]) == 0 and Host._owned_cell(source, point).is_empty():
			if _queue_intent(point, "edit", 6, true):
				requested_fixture_fire += 1


func _collect_action_results() -> void:
	for row: Dictionary in host.action_results:
		var identity: int = int(row.action_id)
		if identity <= _last_action_observed:
			continue
		_last_action_observed = identity
		if _fixture_actions.has(identity):
			if row.get("ok", false):
				authored_fixture_fire += 1
			_fixture_actions.erase(identity)


func _update_inspection() -> void:
	if host.last_inspection.is_empty():
		return
	var result: Dictionary = host.last_inspection
	var serial: int = hash(result)
	if serial == last_inspection_serial:
		return
	last_inspection_serial = serial
	inspection_label.text = "[b]Native inspection[/b]\n" + JSON.stringify(Capture.json_value(result), "  ")
	inspection_label.scroll_to_line(0)


func _update_hud() -> void:
	var now: int = Time.get_ticks_usec()
	if now - last_hud_usec < 100000 and not host.failed:
		return
	last_hud_usec = now
	status_label.text = "Loading native fixture %d/%d · %s" % [setup_cursor, setup_edits.size(), host.state] if loading else host.status
	if setup_failed:
		status_label.text = "Fixture setup held · reset to recreate; partial owner retained"
	status_label.add_theme_color_override("font_color", Color("ff9b89") if host.failed or setup_failed else Color("7fd4b0"))
	var transport: Dictionary = host.worker.diagnostics() if host.worker != null else {}
	var physics: Dictionary = host.bridge.diagnostics() if host.bridge != null else {}
	var elapsed: float = maxf(0.001, float(now - opened_usec) / 1000000.0)
	metrics_label.text = "Display %.1f FPS · Native %d / published %d · %.1f semantic ticks/s elapsed · input %d/256 + host %d/32 · worker %d data + %d control · physics %d segments · publication age %.1f ms" % [
		Engine.get_frames_per_second(), int(host.frame.get("tick", 0)),
		int(host.publication.get("tick", 0)), float(host.completed_ticks) / elapsed,
		queued_cuts.size(), host.actions.size(), int(transport.get("pending_data", 0)), int(transport.get("pending_control", 0)),
		int(physics.get("physics_steps", 0)), float(now - last_publication_usec) / 1000.0 if last_publication_usec > 0 else 0.0]
	var source: Dictionary = host.publication
	var admission: Dictionary = source.get("admission", {})
	var text: String = "[b]ONE MATERIAL OWNER[/b]\nSession %d · transport %d\n" % [host.session, host.generation]
	text += "Canvas %d × %d · slots %d/%d\nEligible %d · deferred %d\nDiscovery %d cells · pending %d\n" % [int(source.get("width", 0)), int(source.get("height", 0)),
		int(admission.get("slots_used", 0)), int(admission.get("slot_limit", 3)), int(admission.get("eligible", 0)), int(admission.get("deferred", 0)),
		int(admission.get("work_last", 0)), int(admission.get("pending_seeds", 0))]
	if not str(admission.get("reason", "")).is_empty():
		text += "[color=#ffcf66]%s[/color]\n" % str(admission.reason)
	var shown: int = 0
	for candidate: Dictionary in admission.get("candidates", []):
		if str(candidate.get("reason", "")) == "Anchored":
			continue
		text += "Candidate %d cells · %s\n" % [int(candidate.get("cells", 0)), str(candidate.get("reason", "unknown"))]
		shown += 1
		if shown >= 3:
			break
	for shard: Dictionary in source.get("shards", []):
		text += "\n[b]Shard %d[/b] · %s\nStructure %d · products %d · cargo %d\nMaterial r%d · geometry r%d\n" % [int(shard.id), str(shard.lifecycle),
			int(shard.structural), int(shard.products), int(shard.cargo), int(shard.material_revision), int(shard.geometry_revision)]
		for body: Dictionary in physics.get("bodies", []):
			if int(body.id) == int(shard.id):
				text += "%s · installed r%d · shapes %d\nMass %.0f · COM %.1f, %.1f\nω %.3f rad/s\n" % ["Sleeping" if body.get("sleeping", false) else "Awake", int(body.get("geometry_revision", 0)),
					int(body.get("shape_count", 0)), float(body.get("mass", 0)), float(body.get("com_x", 0)), float(body.get("com_y", 0)), float(body.get("angular_velocity", 0))]
		if shard.get("split_pending", false):
			text += "[color=#ffcf66]split_pending · one compound[/color]\n"
	var accounting: Dictionary = source.get("accounting", {})
	text += "\nWater extinctions %d\nFire fixture accepted %d\nPhysics barrier %s\nWait peak %.2f ms · tick peak %.2f ms\n" % [int(accounting.get("extinguished", 0)), authored_fixture_fire,
		str(physics.get("motion_phase", "Idle")), float(host.maximum_wait_usec) / 1000.0, float(host.maximum_tick_usec) / 1000.0]
	if not host.last_action.is_empty() and not host.last_action.get("ok", true):
		text += "[color=#ffcf66]Last input: %s[/color]\n" % str(host.last_action.get("outcome", "unknown"))
	text += "Trace %.1f / 32 MiB\n" % (float(host.capture.metadata().bytes) / 1048576.0)
	inventory_label.text = text


func _sample(name: String, elapsed_usec: int) -> void:
	var rows: Array = ui_samples[name]
	if rows.size() >= SAMPLE_CAPACITY:
		rows.pop_front()
	rows.append(elapsed_usec)
	ui_sample_totals[name] = int(ui_sample_totals.get(name, 0)) + 1


static func distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0}
	var sorted: Array = values.duplicate()
	sorted.sort()
	return {"count": sorted.size(), "p50_usec": sorted[int(ceil(sorted.size() * 0.50)) - 1],
		"p95_usec": sorted[int(ceil(sorted.size() * 0.95)) - 1], "p99_usec": sorted[int(ceil(sorted.size() * 0.99)) - 1], "maximum_usec": sorted[-1]}


func _export() -> void:
	var report: Dictionary = host.diagnostics()
	report["queued_ui_intents"] = queued_cuts.duplicate(true)
	report["preset"] = selected_preset.duplicate(true)
	report["continuous_clock"] = {"last_requested_visible_tick": last_requested_visible_tick,
		"scope": "Next interval requested once the preceding completed tick is in the view; pointer admission runs before scheduling. Host fairness still advances through bounded input backlog."}
	report["scene_setup"] = {"loading": loading, "completed": setup_cursor, "total": setup_edits.size(), "failed": setup_failed}
	report["main_receipt_pump"] = {"loop_budget_usec": receipt_pump_usec, "notifications": false,
		"scope": "Soft loop budget checked between handlers; an already-started receipt may exceed it. Actual pump duration is included in host timings and the enclosing UI callback."}
	report["engine"] = Engine.get_version_info()
	report["platform"] = OS.get_name()
	report["external_burner"] = {"enabled": burner_box.button_pressed, "requested_fire_cells": requested_fixture_fire, "accepted_fire_cells": authored_fixture_fire,
		"scope": "Empty-only external Fire actions; accepted native receipts are separate from chemistry products"}
	report["pointer_input"] = {"queued": pointer_queued, "dispatched": pointer_dispatched, "refused": pointer_refused,
		"explicitly_cancelled_by_reset": pointer_cancelled, "pending": queued_cuts.size(), "scope": "UI lifetime across explicit resets; native counters remain session-scoped"}
	var timing: Dictionary = {}
	for name: String in ui_samples:
		timing[name] = distribution(ui_samples[name])
		timing[name]["total_observations"] = int(ui_sample_totals.get(name, 0))
		timing[name]["retained_values_usec"] = ui_samples[name].duplicate()
	report["presentation_timing"] = {"stages": timing, "retention_capacity_each": SAMPLE_CAPACITY,
		"scope": "Rolling UI samples. Input-to-host ends at queue admission; upload is CPU submission, not GPU completion. Frame callback includes nested host/UI work; do not sum nested stages. Publication intervals include pause and diagnostics."}
	host.capture.checkpoint(int(host.frame.get("tick", 0)), report)
	var path: String = "user://ObjectShardPreflightReports/incident-%d-%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		report_label.text = "Export failed: " + error_string(FileAccess.get_open_error())
		return
	output.store_string(JSON.stringify(Capture.json_value(report), "  ") + "\n")
	output.close()
	last_export = ProjectSettings.globalize_path(path)
	report_label.text = "Saved " + last_export + " · trace: " + ProjectSettings.globalize_path(host.capture.path)


func _export_and_open() -> void:
	_export()
	if not last_export.is_empty():
		OS.shell_open(last_export.get_base_dir())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_exit("quit")


func request_feature_launcher_navigation() -> void:
	_request_exit("launcher")


func feature_launcher_navigation_ready() -> bool:
	return closing and close_destination == "launcher" and host.state == "Closed" and not close_dispatched


func _request_exit(destination: String) -> void:
	if close_dispatched:
		return
	if closing:
		# Process exit takes precedence over an already-requested launcher handoff.
		if destination == "quit":
			close_destination = "quit"
		return
	# A retry after a held shutdown must not downgrade a window-close request.
	if close_destination != "quit" or host.state != "ShutdownHeld":
		close_destination = destination
	closing = true
	running = false
	run_button.text = "Resume"
	# Navigation supersedes a pending reset. Never open an intermediate owner
	# after the user has asked to leave this scene.
	replacing_owner = false
	pending_preset.clear()
	delay_box.set_pressed_no_signal(false)
	pointer_cancelled += queued_cuts.size()
	host.capture.write("event", int(host.frame.get("tick", 0)),
		{"kind": "ExplicitUIExit", "destination": close_destination, "cancelled_pointer_intents": queued_cuts.size()})
	queued_cuts.clear()
	host.close()
	report_label.text = "Disposing the native owner before " + ("returning to the launcher." if close_destination == "launcher" else "closing the window.")


func _finish_exit() -> void:
	if close_dispatched or host.state != "Closed":
		return
	if close_destination == "launcher":
		var navigation: Node = get_node_or_null("/root/FeatureNavigation")
		if navigation == null or get_tree().current_scene != self:
			closing = false
			report_label.text = "Owner disposed; launcher handoff refused because this is no longer the current scene."
			return
		if not navigation.complete_feature_launcher_navigation(self):
			closing = false
			report_label.text = "Owner disposed; launcher handoff refused. Retry F2."
			return
		close_dispatched = true
		get_tree().auto_accept_quit = previous_auto_accept_quit
		set_process(false)
	else:
		close_dispatched = true
		get_tree().auto_accept_quit = previous_auto_accept_quit
		get_tree().quit()
