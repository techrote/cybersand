extends SceneTree

# LCB-FEEL #360 full desktop-host cohort arm. One process runs one arm through
# the ordinary launcher feature, Main, the asynchronous simulation owner, its
# native World, Rapier bridge and (when not --headless) the real renderer. The
# construction-time worker setting is applied before Main exists, exactly as
# the fresh-owner relaunch does. Per Main frame it records copied snapshot and
# host values; at the end it requests the owner's capture. No feel claim.
# Usage: -- --scenario=ID --family=F --workers=N --ticks=T --output=FILE
const Catalogue = preload("res://scripts/liquid_feel_catalogue.gd")
var _options: Dictionary = {"scenario":"", "family":"", "variant":"reference", "workers":"0", "ticks":"600",
	"output":"", "radius-index":"1", "wall-seconds":"240"}
var desktop: Control

func _initialize() -> void:
	run.call_deferred()

func _fail(message: String) -> void:
	printerr("LCB_FEEL_HOST_ERROR: ", message)
	if desktop != null and is_instance_valid(desktop):
		desktop.simulation_worker.stop_worker()
		desktop.rapier_bridge.shutdown()
	quit(2)

func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty(): return -1.0
	var ordered: Array = values.duplicate()
	ordered.sort()
	return float(ordered[clampi(int(ceil(fraction * ordered.size())) - 1, 0, ordered.size() - 1)])

func _summary(values: Array) -> Dictionary:
	return {"count":values.size(), "p50":_percentile(values, 0.5), "p95":_percentile(values, 0.95),
		"p99":_percentile(values, 0.99), "max":_percentile(values, 1.0)}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2 or not _options.has(pair[0]):
			_fail("unknown argument " + argument); return
		_options[pair[0]] = pair[1]
	var index: int = Catalogue.index_of(str(_options.scenario))
	if index < 0 or str(_options.output).is_empty():
		_fail("registered catalogue scenario and --output are required"); return
	var workers: int = int(_options.workers)
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	root.size = Vector2i(1600, 1000)
	set_meta("cybersand_feature", "liquid_comparison")
	change_scene_to_file("res://main.tscn")
	var deadline: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.has_method(&"liquid_feel_relaunch") \
			and current_scene.pending_microscenario_apply.is_empty() and current_scene.tower_context.get("micro_active", false): break
	desktop = current_scene
	if desktop == null or not desktop.has_method(&"liquid_feel_relaunch"):
		_fail("desktop host unavailable"); return
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.feel_controls.use_capture_directory("user://lcb-feel-host-cohort")
	panel.setup_picker.select(panel.SETUP_BUILTIN_COUNT + index)
	panel.geometry_picker.select(int(_options["radius-index"]))
	panel.normalize_water.button_pressed = true
	var generation: int = int(desktop.tower_context.liquid_solver_policy.session_generation)
	if not panel.feel_controls.select_water_family(str(_options.family)) or not panel.load_selected():
		_fail("comparison request refused: " + str(desktop.microscenario_error)); return
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		panel.refresh(desktop.tower_context)
		if desktop.pending_microscenario_apply.is_empty() and int(desktop.tower_context.liquid_solver_policy.session_generation) > generation: break
	var applied: Dictionary = desktop.tower_context.liquid_solver_policy
	if int(applied.session_generation) <= generation:
		_fail("comparison rebuild not acknowledged"); return
	# Dock-closed measurement: the world view is unobstructed while it runs.
	desktop.microscenario_panel.liquid_dialog.hide()
	var target: int = int(_options.ticks)
	var frames: Array = []
	var native_ms: Array = []
	var step_ms: Array = []
	var age_ms: Array = []
	var rapier_ms: Array = []
	var participation: Array = []
	var last_serial: int = -1
	var last_sequence: int = -1
	var start_tick: int = int(desktop.latest_snapshot.tick_index)
	var started_usec: int = Time.get_ticks_usec()
	var previous_frame: int = started_usec
	desktop.paused = false
	var wall_limit: int = Time.get_ticks_msec() + int(_options["wall-seconds"]) * 1000
	var censored: bool = false
	while int(desktop.latest_snapshot.tick_index) - start_tick < target:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - previous_frame) / 1000.0)
		previous_frame = now
		var snapshot: Variant = desktop.latest_snapshot
		if int(snapshot.serial) != last_serial:
			last_serial = int(snapshot.serial)
			native_ms.append(float(snapshot.simulation_time_ms))
			step_ms.append(float(snapshot.worker_step_time_ms))
			age_ms.append(maxf(0.0, float(now - int(snapshot.published_usec)) / 1000.0))
		rapier_ms.append(float(desktop.rapier_bridge.last_step_time_ms()))
		var sample: Dictionary = snapshot.native_worker_participation
		if not sample.is_empty() and int(sample.sequence) != last_sequence:
			last_sequence = int(sample.sequence)
			participation.append(sample.duplicate(true))
		if desktop.latest_snapshot.simulation_failed:
			break
		if Time.get_ticks_msec() > wall_limit:
			censored = true
			break
	var elapsed_s: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	var completed: int = int(desktop.latest_snapshot.tick_index) - start_tick
	desktop.paused = true
	var capture_serial: int = int(desktop.tower_context.get("micro_capture_serial", 0))
	desktop.microscenario_capture()
	deadline = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and int(desktop.tower_context.get("micro_capture_serial", 0)) <= capture_serial:
		await process_frame
	var report: Dictionary = desktop.tower_context.get("micro_capture", {})
	var observed: Array = []
	for sample: Dictionary in participation: observed.append(int(sample.workers_observed))
	var water: Dictionary = {}
	for assignment: Dictionary in applied.assignments:
		if int(assignment.material) == 3: water = assignment
	var record: Dictionary = {"schema":"lcb-feel-host-arm-v1", "catalogue":Catalogue.VERSION,
		"scenario":str(_options.scenario), "requested":{"family":str(_options.family), "variant":str(_options.variant),
			"workers":workers, "ticks":target, "radius_index":int(_options["radius-index"])},
		"applied":{"water_family":str(water.get("applied_family", "")), "water_variant":str(water.get("applied_variant", "")),
			"maximum_rule_radius":int(applied.maximum_rule_radius), "policy_hash":str(applied.policy_hash),
			"session_generation":int(applied.session_generation)},
		"renderer":{"display_server":DisplayServer.get_name(), "rendering_method":str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			"adapter":RenderingServer.get_video_adapter_name(), "vsync":DisplayServer.window_get_vsync_mode()},
		"godot_version":Engine.get_version_info(), "os":OS.get_name(), "processor_name":OS.get_processor_name(),
		"workers":{"requested":int(desktop.latest_snapshot.native_worker_request),
			"configured_capacity":int(desktop.latest_snapshot.scheduler_thread_capacity_hint),
			"participation_samples":participation.size(), "max_observed":observed.max() if not observed.is_empty() else -1,
			"samples_with_multiple":observed.filter(func(value: int) -> bool: return value > 1).size()},
		"outcome":{"completed_native_ticks":completed, "elapsed_seconds":elapsed_s,
			"native_ticks_per_second":float(completed) / maxf(elapsed_s, 0.000001), "censored_by_wall_limit":censored,
			"simulation_failed":bool(desktop.latest_snapshot.simulation_failed)},
		"main_frame_ms":_summary(frames), "publication_native_tick_ms":_summary(native_ms),
		"owner_step_ms":_summary(step_ms), "snapshot_age_ms":_summary(age_ms), "rapier_step_ms":_summary(rapier_ms),
		"owner_capture":{"completed_tick":report.get("completed_tick", -1), "native_timing":report.get("timing", {}),
			"water_ledger":report.get("water_ledger", {}), "native":report.get("native", {}),
			"observations":report.get("observations", []), "budget_outcome":report.get("budget_outcome", "")},
		"scope":"Real desktop host. main_frame_ms is the Main callback interval; native tick values are World::tick per publication and the owner capture; rapier_step_ms is the main-thread bridge step (actor-free scenes carry no bodies). Not a feel rating; headless runs are not GPU FPS."}
	var file := FileAccess.open(str(_options.output), FileAccess.WRITE)
	if file == null:
		_fail("cannot write output"); return
	file.store_string(JSON.stringify(record, "  ") + "\n")
	file.close()
	print("LCB_FEEL_HOST ", _options.scenario, " ", _options.family, " w", workers, " ticks=", completed, " tps=%.1f" % record.outcome.native_ticks_per_second)
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	quit(0)
