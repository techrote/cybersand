extends SceneTree
## Optional interactive evaluator. The ordinary Workbench owns every UI and edit.
## Keep diagnostic samples in memory; write only on Ctrl+F12 or orderly exit.
const EVENT_LIMIT := 256
const FRAME_BOUNDS_USEC := [1000, 2000, 4000, 8000, 16667, 33334, 50000, 100000, 250000, 500000, 1000000, 2500000]
var host: Control
var panel: Window
var began_usec := 0
var previous_usec := 0
var previous_phase := "startup"
var frame_groups := {}
var component_max_usec := {}
var events: Array[Dictionary] = []
var dropped_events := 0
var observed_request := {}
var observed_close := {}
var observed_stop := {}
var previous_visible := false
var previous_manual_edit := false
var checkpoint_queued := false
var finishing := false
var ready_usec := 0
var output_path := ""
var teardown_usec := -1

func _initialize() -> void:
	began_usec = Time.get_ticks_usec()
	previous_usec = began_usec
	output_path = OS.get_environment("WB_ART_DIAGNOSTIC_PATH")
	if output_path.is_empty(): output_path = "user://art-responsiveness.json"
	auto_accept_quit = false
	root.close_requested.connect(_finish)
	node_added.connect(_diagnostic_node_added)
	_diagnostic_node_added(root)
	set_meta("cybersand_feature", "shared_workbench")
	_start.call_deferred()

func _start() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	root.title = "CyberSand · Art evaluation · Ctrl+F12 saves timing"
	print("ART_OWNER_EVALUATOR ", JSON.stringify({"godot":Engine.get_version_info().string,
		"display":DisplayServer.get_name(), "source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"automatic_requests":false, "report":output_path}))

func _process(_delta: float) -> bool:
	if finishing: return false
	var now := Time.get_ticks_usec()
	_record_frame(previous_phase, now - previous_usec)
	previous_usec = now
	if not is_instance_valid(host):
		_finish()
		return false
	if not is_instance_valid(panel):
		var workbench: Node = host.get("shared_workbench")
		if is_instance_valid(workbench) and not workbench.applied.is_empty() and not workbench.busy():
			panel = workbench._ensure_art_batches()
			# The evaluator starts with the owner's text-only no-server protocol.
			# This is an isolated launch setting, not a production default.
			panel.image_input.button_pressed = false
			panel.show()
			panel.position = Vector2i(32, 130)
			ready_usec = now
			_event("workbench_ready")
		else:
			previous_phase = "startup"
			return false
	var provider: Node = panel.provider
	for name: String in ["last_visible_ui_usec", "last_native_poll_usec", "last_request_epoch_usec"]:
		var value: Variant = panel.get(name)
		if value is int: component_max_usec[name] = maxi(int(component_max_usec.get(name, 0)), value)
	for name: String in ["last_list_slice_usec", "max_list_slice_usec"]:
		var value: Variant = panel.conversation_editor.get(name)
		if value is int: component_max_usec[name] = maxi(int(component_max_usec.get(name, 0)), value)
	if panel.visible != previous_visible:
		previous_visible = panel.visible
		_event("art_shown" if panel.visible else "art_hidden")
	var request: Dictionary = provider.get("last_request_timing")
	# The callback fills its metrics after emitting finished; compare next frame.
	if request != observed_request:
		observed_request = request.duplicate(true)
		if not request.is_empty() and str(request.get("status", "")) != "pending":
			_event("request_state")
	var close: Dictionary = panel.last_close_timing
	if close != observed_close:
		observed_close = close.duplicate(true)
		_event("ordinary_x_hide")
	var stopped: Dictionary = panel.last_stop_timing
	if stopped != observed_stop:
		observed_stop = stopped.duplicate(true)
		_event("explicit_stop")
	var manual_edit := _manual_edit_active()
	if manual_edit != previous_manual_edit:
		previous_manual_edit = manual_edit
		_event("manual_edit_started" if manual_edit else "manual_edit_finished")
	var phase := "visible" if panel.visible else "hidden"
	if provider.active:
		var request_phase := str(request.get("status", ""))
		phase += "_"+request_phase if request_phase in ["preparing_request", "preparing_response"] else "_request"
	elif panel.executor.active: phase += "_native_edit"
	elif not manual_edit: phase += "_idle"
	if manual_edit: phase += "_manual_edit"
	previous_phase = phase
	var smoke_seconds := OS.get_environment("WB_ART_EVALUATOR_SMOKE_SECONDS").to_float()
	if smoke_seconds > 0.0 and ready_usec > 0 and float(now - ready_usec) / 1000000.0 >= smoke_seconds:
		_finish()
	return false

func _diagnostic_node_added(node: Node) -> void:
	# Traffic, Note, Key and other dialogs can own keyboard focus independently.
	if node is Window and not node.window_input.is_connected(_diagnostic_input):
		node.window_input.connect(_diagnostic_input)

func _diagnostic_input(event: InputEvent) -> void:
	# Input events preserve quick key taps that can begin and end between two
	# process frames. Deduplicate delivery through embedded window routing.
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed \
			and (event.keycode == KEY_F12 or event.physical_keycode == KEY_F12):
		if not checkpoint_queued and not finishing:
			checkpoint_queued = true
			_checkpoint.call_deferred()

func _checkpoint() -> void:
	checkpoint_queued = false
	if not finishing: _write_report("manual_checkpoint")

func _manual_edit_active() -> bool:
	if not is_instance_valid(panel): return false
	var editor: Control = panel.wb.paint_editor
	# Read the existing GDScript owner flags without adding another native lock
	# or filesystem query to the frame being measured.
	return is_instance_valid(editor) and (editor.busy() or editor.dragging)

func _record_frame(phase: String, elapsed: int) -> void:
	if not frame_groups.has(phase):
		var buckets: Array[int] = []
		buckets.resize(FRAME_BOUNDS_USEC.size() + 1)
		buckets.fill(0)
		frame_groups[phase] = {"count":0, "total_usec":0, "max_usec":0, "histogram":buckets}
	var group: Dictionary = frame_groups[phase]
	group.count += 1
	group.total_usec += elapsed
	group.max_usec = maxi(int(group.max_usec), elapsed)
	var bucket := 0
	while bucket < FRAME_BOUNDS_USEC.size() and elapsed > int(FRAME_BOUNDS_USEC[bucket]): bucket += 1
	group.histogram[bucket] += 1

func _timing(value: Variant) -> Dictionary:
	# Timings may gain fields later. Accept numerical counters and fixed enums
	# only, never URLs, configuration, prompts, errors or response text.
	var result := {}
	if not value is Dictionary: return result
	for key: Variant in value:
		var item: Variant = value[key]
		if item is int or item is float or item is bool:
			result[str(key)] = item
		elif key == "status" and item in ["pending", "preparing", "preparing_request", "in_flight", "preparing_response", "completing", "start_failed", "started", "completed", "cancelled", "failed", "request_error", "transport_error", "http_error", "malformed", "oversized"]:
			result[str(key)] = item
	return result

func _event(kind: String) -> void:
	var record := {"event":kind, "elapsed_usec":Time.get_ticks_usec() - began_usec}
	if is_instance_valid(panel):
		record["visible"] = panel.visible
		record["provider_active"] = panel.provider.active
		record["native_edit_active"] = panel.executor.active
		record["manual_edit_active"] = _manual_edit_active()
		record["simulation_running"] = not host.paused
		for name: String in ["last_close_timing", "last_stop_timing", "last_send_timing", "last_finished_timing"]:
			record[name] = _timing(panel.get(name))
		for name: String in ["last_visible_ui_usec", "last_native_poll_usec", "last_request_epoch_usec", "last_send_epoch_usec"]:
			var sample: Variant = panel.get(name)
			if sample is int: record[name] = sample
		record["provider"] = _timing(panel.provider.last_request_timing)
		record["audit"] = _timing(panel.provider.get("last_audit_timing"))
	if events.size() == EVENT_LIMIT:
		events.pop_front()
		dropped_events += 1
	events.append(record)

func _write_report(reason: String) -> void:
	_event(reason)
	var report := {"schema":"art-owner-responsiveness-v1", "godot":Engine.get_version_info().string,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"), "display":DisplayServer.get_name(),
		"platform":OS.get_name(), "duration_usec":Time.get_ticks_usec() - began_usec,
		"window_size":[root.size.x, root.size.y], "screen_dpi":DisplayServer.screen_get_dpi(),
		"frame_histogram_upper_bounds_usec":FRAME_BOUNDS_USEC, "frame_groups":frame_groups,
		"component_max_usec":component_max_usec,
		"events":events, "events_dropped":dropped_events,
		"teardown_completed":teardown_usec >= 0, "teardown_usec":teardown_usec,
		"automatic_requests":false, "contains_provider_config":false,
		"interpretation":"Adjacent main-loop gaps include Workbench rendering and native activity. This is diagnostic evidence, not proof of physical playability or a fixed no-server freeze."}
	var path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		root.title = "CyberSand · Art evaluation · Could not save timing"
		push_warning("Could not save Art timing report.")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	if reason == "manual_checkpoint":
		root.title = "CyberSand · Art evaluation · Timing saved · Ctrl+F12 saves again"
	print("ART_OWNER_TIMING_SAVED ", path)

func _finish() -> void:
	if finishing: return
	# Preserve a report even if an engine/native teardown stalls. Successful
	# destruction replaces it with a measured completion receipt.
	_write_report("before_teardown")
	finishing = true
	var teardown_began := Time.get_ticks_usec()
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	teardown_usec = Time.get_ticks_usec() - teardown_began
	_write_report("teardown_completed")
	quit()
