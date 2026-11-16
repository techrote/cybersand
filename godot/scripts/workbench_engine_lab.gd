extends Window

# RENDER-UPLOAD-577: a focused adaptation of #609's second-layer Engine Lab.
# Accepted main has no independent-clock/coherence apparatus. This panel retains
# its existing simulation laws and exposes only supported presentation controls.
const SAMPLE_SECONDS := 10.0
const MAX_SAMPLES := 12000
var host: Control
var _status: Label
var _result: TextEdit
var _strategy: OptionButton
var _capturing := false
var _samples: Array[Dictionary] = []
var _dropped := 0


func mount(controller: Control, _workbench: Control) -> void:
	hide()
	host = controller
	title = "CyberSand / Engine Lab"
	size = Vector2i(820, 620)
	min_size = Vector2i(640, 440)
	transient = true
	force_native = not OS.has_feature("web") and DisplayServer.get_name() != "headless" \
		and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
	content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	handle_input_locally = true
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_note(column, "Material publication · opt-in evaluation")
	_note(column, "Baseline submits the compact full image. Hybrid uses compact full uploads for dense changes and region updates after sustained sparse changes.")
	var row := HBoxContainer.new()
	column.add_child(row)
	_strategy = OptionButton.new()
	_strategy.add_item("Baseline / full image", 0)
	_strategy.add_item("Candidate / sparse-dense hybrid", 1)
	_strategy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_strategy)
	_strategy.item_selected.connect(_select_strategy)
	_note(column, "Changing strategy keeps the current world and texture history. First candidate activation prepares material shaders and can take several seconds. Use the separate launchers for comparisons from the same fresh start.")
	var fps := SpinBox.new()
	fps.min_value = 0
	fps.max_value = 240
	fps.value = Engine.max_fps
	fps.prefix = "Frame cap (0 = uncapped): "
	column.add_child(fps)
	fps.value_changed.connect(func(value: float) -> void: Engine.max_fps = int(value))
	var vsync := CheckButton.new()
	vsync.text = "VSync"
	vsync.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	column.add_child(vsync)
	vsync.toggled.connect(func(enabled: bool) -> void:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED))
	var cadence := SpinBox.new()
	cadence.min_value = 1
	cadence.max_value = 240
	cadence.value = host.render_snapshot_hz
	cadence.prefix = "Material publication target (Hz): "
	column.add_child(cadence)
	cadence.value_changed.connect(func(value: float) -> void:
		host.render_snapshot_hz = int(value)
		host.simulation_worker.set_render_snapshot_hz(int(value)))
	var capture := Button.new()
	capture.text = "Measure 10 seconds while I paint or play"
	column.add_child(capture)
	capture.pressed.connect(_capture)
	_status = _note(column, "Ready")
	_result = TextEdit.new()
	_result.editable = false
	_result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result.custom_minimum_size.y = 140
	column.add_child(_result)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	set_process(false)
	_refresh()


func _note(parent: Control, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func open() -> void:
	popup_centered_clamped(Vector2i(820, 620), 0.95)
	_refresh()


func _select_strategy(index: int) -> void:
	if not host.set_render_upload_strategy("hybrid" if index == 1 else "full"):
		_result.text = "The strategy could not be changed safely. The accepted display is retained; retry after the pending refresh or use the matching launcher."
	_refresh()


func _refresh() -> void:
	if host == null or _status == null:
		return
	var active: String = str(host.render_upload_status.get("active", "full"))
	_strategy.select(1 if active == "hybrid" else 0)
	var state := _sample()
	_status.text = "%s · native tick %d · Rapier step %d · accepted material %d\n%s · last publication %.3f ms" % [
		active, state.native_tick, state.rapier_step, state.render_serial,
		str(host.render_upload_metrics.get("mode", "initial")), host.upload_time_ms]


func _sample() -> Dictionary:
	return {"time_usec": Time.get_ticks_usec(), "process_frame": Engine.get_process_frames(),
		"native_tick": int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else 0,
		"rapier_step": int(host.physical_actor_session.tick) if host.physical_actor_session != null else 0,
		"render_serial": host.last_uploaded_render_snapshot_serial,
		"accepted_publications": host.accepted_render_publications,
		"generation": host.last_uploaded_world_generation, "revision": host.last_uploaded_revision}


func _process(delta: float) -> void:
	if not _capturing:
		return
	if _samples.size() >= MAX_SAMPLES:
		_dropped += 1
		return
	var row := _sample()
	row["frame_ms"] = delta * 1000.0
	row["publication_ms"] = host.upload_time_ms
	row["upload"] = host.render_upload_metrics.duplicate(true)
	_samples.append(row)


func _capture() -> void:
	if _capturing:
		return
	_capturing = true
	_samples.clear()
	_dropped = 0
	var before := _sample()
	var strategy: Dictionary = host.render_upload_status.duplicate(true)
	_result.text = "Measuring ten seconds…"
	set_process(true)
	await get_tree().create_timer(SAMPLE_SECONDS).timeout
	set_process(false)
	var after := _sample()
	var seconds: float = maxf(0.001, float(after.time_usec - before.time_usec) / 1000000.0)
	var report := {"schema": "render-upload-577-manual-v1", "strategy": strategy,
		"elapsed_seconds": seconds, "before": before, "after": after,
		"frames_per_second": float(after.process_frame - before.process_frame) / seconds,
		"native_ticks_per_second": float(after.native_tick - before.native_tick) / seconds,
		"rapier_steps_per_second": float(after.rapier_step - before.rapier_step) / seconds,
		"accepted_material_updates_per_second": float(after.accepted_publications - before.accepted_publications) / seconds,
		"dropped_samples": _dropped, "samples": _samples,
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "headless",
		"gpu_completion_measured": false, "scanout_measured": false}
	var name := "user://render-upload-577-" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(name, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report) + "\n")
		file.close()
	report.erase("samples")
	_result.text = JSON.stringify(report, "  ") + "\n" + (ProjectSettings.globalize_path(name) if file != null else "Could not save the capture.")
	_capturing = false
	_samples.clear()
	_refresh()
