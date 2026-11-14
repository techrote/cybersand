extends Window

# ENG-LAB-001 Phase A: passive current-World clock comparison.
# No source World, Rapier RID or simulation setting is ever modified here.
const Recorder = preload("res://scripts/engine_lab_passive_recorder.gd")
const DURATION_USEC: int = 10000000
const REFRESH_USEC: int = 250000

var host: Control
# Tests can shorten an otherwise unchanged passive observation; UI remains 10s.
var benchmark_duration_usec: int = DURATION_USEC
var recorder: CyberEngineLabPassiveRecorder = Recorder.new()
var _live: Label
var _message: Label
var _test_it_button: Button
var _capture_button: Button
var _cancel_button: Button
var _last_refresh_usec: int = 0
var _last_wall_usec: int = 0
var _last_native_tick: int = -1
var _last_rapier_step: int = -1
var _last_report_path: String = ""
var _report_written: bool = false


func _ready() -> void:
	name = "EngineLabPassive"
	title = "CyberSand / Engine Lab — clocks & benchmark"
	size = Vector2i(680, 430)
	min_size = Vector2i(520, 330)
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(hide)
	visibility_changed.connect(_on_visibility_changed)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := Label.new()
	header.text = "Read-only clocks • Native World and Rapier settings remain unchanged"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(header)
	_live = Label.new()
	_live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_live)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_test_it_button = Button.new()
	_test_it_button.text = "Test it → ZIP"
	_test_it_button.tooltip_text = "Runs the exact 2048-square owner gate canvas in fresh processes with physics-tick-scripted Needle inputs; writes one evidence ZIP."
	_test_it_button.pressed.connect(_start_test_it)
	buttons.add_child(_test_it_button)
	_capture_button = Button.new()
	_capture_button.text = "Passive 10s"
	_capture_button.pressed.connect(begin_benchmark)
	buttons.add_child(_capture_button)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.disabled = true
	_cancel_button.pressed.connect(cancel_benchmark)
	buttons.add_child(_cancel_button)
	var explain := Label.new()
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.text = ("Test it runs a SEPARATE, source-matched, scripted reference-canvas benchmark; "
		+ "its tick-addressed Needle inputs are automatic and its reports are bundled as one ZIP. "
		+ "Passive 10s measures only the current World with no injected input.")
	column.add_child(explain)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text = "Ready • no benchmark has been recorded"
	column.add_child(_message)
	set_process(false)


func open_for(controller: Control) -> void:
	host = controller
	popup_centered_clamped(Vector2i(680, 430), 0.90)
	set_process(true)
	_last_wall_usec = 0
	_last_native_tick = -1
	_last_rapier_step = -1
	_refresh_readout(Time.get_ticks_usec())


func _on_visibility_changed() -> void:
	if not visible and recorder.running:
		_stop_benchmark("engine_lab_window_closed")
	if not visible:
		set_process(false)
	elif host != null:
		set_process(true)


func _exit_tree() -> void:
	if recorder.running:
		_stop_benchmark("engine_lab_owner_disposed")


func _valid_owner() -> bool:
	return host != null and is_instance_valid(host) and host.simulation_worker != null 		and host.latest_snapshot != null and not host.simulation_worker.has_failed()


func _native_path() -> String:
	return "res://addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows"
		else "libcybersand_native.linux.x86_64.so")


func _identity() -> Dictionary:
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	var workbench: Control = host.shared_workbench
	var starter: Dictionary = workbench.applied if workbench != null else {}
	var policy: Variant = starter.get("liquid_policy", [])
	var policy_hash: String = JSON.stringify(policy).sha256_text()
	var requested: PackedStringArray = OS.get_cmdline_user_args()
	var source: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	return {
		"source_revision":source if not source.is_empty() else "unreported",
		"main_script_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"worker_script_sha256":FileAccess.get_sha256("res://scripts/simulation_worker.gd"),
		"native_runtime_sha256":FileAccess.get_sha256(_native_path()),
		"engine":Engine.get_version_info().get("string", "unknown"),
		"os":OS.get_name(), "cpu":OS.get_processor_name(),
		"logical_processors":OS.get_processor_count(),
		"video_adapter":RenderingServer.get_video_adapter_name(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"window_size":[host.get_window().size.x, host.get_window().size.y],
		"world_extent":[host.world_extent.x, host.world_extent.y],
		"world_generation":snapshot.render_world_generation,
		"native_backend":snapshot.backend_name,
		"native_workers_requested":snapshot.native_worker_request,
		"native_workers_configured":snapshot.scheduler_thread_capacity_hint,
		"native_target_hz":60,
		"rapier_callback_target_hz":Engine.physics_ticks_per_second,
		"rapier_manual_dt_seconds":host.rapier_bridge.fixed_delta(),
		"render_snapshot_target_hz":host.render_snapshot_hz,
		"render_ack_policy":"baseline" if not requested.has("--render-ack-policy=gated") else "gated-requested-unverified",
		"source_workbench_start_name":str(workbench._name.text) if workbench != null else "",
		"workbench_start_recipe_unverified":true,
		"liquid_policy_sha256":policy_hash,
		"liquid_solver_policy":snapshot.lab_context.get("liquid_solver_policy",{}),
		"baseline_comparable_only_after_owner_reset":true,
		"input_policy":"no_input_injected_by_benchmark-human_input_uncontrolled",
	}


func _read_sample(now_usec: int) -> Dictionary:
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	var age: int = now_usec - snapshot.render_generated_usec if snapshot.render_generated_usec > 0 else -1
	return {
		"at_usec":now_usec,
		"paused":host.paused,
		"simulation_failed":snapshot.simulation_failed,
		"world_generation":snapshot.render_world_generation,
		"world_revision":snapshot.world_revision,
		"native_world_revision":snapshot.simulation_world_revision,
		"native_tick":snapshot.tick_index,
		"native_sim_ms":snapshot.simulation_time_ms,
		"worker_step_ms":snapshot.worker_step_time_ms,
		"worker_overruns":snapshot.worker_overruns,
		"rapier_steps":host.rapier_bridge.manual_step_count(),
		"rapier_owner_id":host.rapier_bridge.get_instance_id(),
		"rapier_step_ms":host.rapier_bridge.last_step_time_ms(),
		"render_serial":host.last_uploaded_render_snapshot_serial,
		"render_full":host.last_render_was_full_refresh,
		"render_age_usec":age,
		"render_upload_ms":host.upload_time_ms,
		"hold_counts":host.engine_lab_coupling_counts(),
	}


func _start_test_it() -> void:
	# A single click launches the isolated owner-GPU harness; this Workbench
	# retains its own World. The runner creates fresh independent native owners.
	# Source checkout / non-Windows stays read-only until a qualified package
	# places the launcher beside the pinned Godot executable.
	if OS.get_name() != "Windows":
		_message.text = "Test it launcher is packaged for Windows 11 NVIDIA only."
		return
	var base: String = OS.get_executable_path().get_base_dir()
	var runner: String = base.path_join("Run-Test-It.ps1")
	if not FileAccess.file_exists(runner):
		_message.text = "Run-Test-It.ps1 not installed beside the packaged Godot executable."
		return
	var pid: int = OS.create_process("powershell.exe",[
		"-NoProfile","-ExecutionPolicy","Bypass","-File",runner],true)
	if pid <= 0:
		_message.text = "Windows refused the isolated PowerShell Test it launcher."
		return
	_message.text = "Test it launched (PID %d). The script runs without your inputs. One ZIP will appear under:\n%s" % [
		pid, base.path_join("Benchmark-Results")]
	print("ENGINE_LAB_TEST_IT_LAUNCHED ",pid," ",base.path_join("Benchmark-Results"))


func begin_benchmark() -> void:
	if recorder.running:
		return
	if not _valid_owner():
		_message.text = "Refused: no healthy active World"
		return
	if host.paused:
		_message.text = "Refused: press Play and allow the scene to run first"
		return
	if not recorder.begin(_identity(), Time.get_ticks_usec(), benchmark_duration_usec):
		_message.text = "Refused: recorder not in a valid state"
		return
	host.engine_lab_benchmark_active = true
	_report_written = false
	_capture_button.disabled = true
	_cancel_button.disabled = false
	_message.text = "Sampling current World; do not touch controls or change solvers"


func cancel_benchmark() -> void:
	_stop_benchmark("cancelled_by_owner")


func _stop_benchmark(reason: String) -> void:
	if not recorder.running:
		return
	if is_instance_valid(host):
		host.engine_lab_benchmark_active = false
	recorder.abort(reason, Time.get_ticks_usec())
	_save_report()


func _save_report() -> void:
	if _report_written or not recorder.finished:
		return
	_report_written = true
	if is_instance_valid(host):
		host.engine_lab_benchmark_active = false
	_capture_button.disabled = false
	_cancel_button.disabled = true
	var report: Dictionary = recorder.outcome
	var file_path: String = "user://engine-lab-%d-%d.json" % [OS.get_process_id(), recorder.started_usec]
	var target: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if target == null:
		_message.text = "Benchmark finished but report write refused: " + str(FileAccess.get_open_error())
		return
	target.store_string(JSON.stringify(report, "\t") + "\n")
	target.close()
	_last_report_path = ProjectSettings.globalize_path(file_path)
	_message.text = "%s • %s\nNative %.1f ticks/s • Rapier %.1f steps/s • %d frame samples" % [
		str(report.get("status", "unknown")), _last_report_path,
		float(report.get("actual_native_hz", 0.0)),
		float(report.get("actual_rapier_hz", 0.0)),
		int(report.get("frame_count", 0))]
	print("ENGINE_LAB_PASSIVE_REPORT ", _last_report_path)


func _refresh_readout(now_usec: int) -> void:
	if not _valid_owner():
		_live.text = "No healthy native Worker or snapshot is attached"
		return
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	var rapier_steps: int = host.rapier_bridge.manual_step_count()
	var observed_native_hz: float = 0.0
	var observed_rapier_hz: float = 0.0
	if _last_wall_usec > 0 and now_usec > _last_wall_usec and snapshot.tick_index >= _last_native_tick and rapier_steps >= _last_rapier_step:
		var elapsed: float = float(now_usec - _last_wall_usec) / 1000000.0
		observed_native_hz = float(snapshot.tick_index - _last_native_tick) / elapsed
		observed_rapier_hz = float(rapier_steps - _last_rapier_step) / elapsed
	_last_wall_usec = now_usec
	_last_native_tick = snapshot.tick_index
	_last_rapier_step = rapier_steps
	var holds: Dictionary = host.engine_lab_coupling_counts()
	_live.text = (
		"Renderer: %s / %s\n"
		+ "Display: %s • %d×%d • frame %.2f ms\n"
		+ "Native: 60 Hz target • %.1f ticks/s recent • tick %d • %.2f ms last solve\n"
		+ "Rapier: %d Hz callback target • %.1f steps/s recent • %d steps • %.2f ms last step\n"
		+ "Rapier manual dt: %.5f s • Workbench sample holds %d • terrain holds %d\n"
		+ "Workbench no-snapshot holds %d • non-Workbench lockstep holds %d\n"
		+ "Render snapshot target %d Hz • accepted material serial %d • payload age %.1f ms\n"
		+ "Recording: %s"
	) % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(),
		host.get_window().size.x, host.get_window().size.y,
		host.frame_time_ms,
		observed_native_hz, snapshot.tick_index, snapshot.simulation_time_ms,
		Engine.physics_ticks_per_second, observed_rapier_hz, rapier_steps,
		host.rapier_bridge.last_step_time_ms(),
		host.rapier_bridge.fixed_delta(),
		int(holds.get("workbench_sample", 0)),
		int(holds.get("workbench_terrain", 0)),
		int(holds.get("workbench_no_snapshot", 0)),
		int(holds.get("lockstep", 0)),
		host.render_snapshot_hz, host.last_uploaded_render_snapshot_serial,
		float(maxi(0, now_usec - snapshot.render_generated_usec)) / 1000.0 if snapshot.render_generated_usec > 0 else -1.0,
		"active" if recorder.running else "off",
	]


func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	if recorder.running:
		if not _valid_owner():
			_stop_benchmark("native_owner_unavailable")
		else:
			recorder.observe(_read_sample(now_usec))
			if recorder.finished:
				_save_report()
	if now_usec - _last_refresh_usec >= REFRESH_USEC:
		_last_refresh_usec = now_usec
		_refresh_readout(now_usec)
