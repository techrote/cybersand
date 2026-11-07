extends SceneTree

# Current-main integrated gameplay acceptance. Test/qualification only:
# production Main, CyberSimulationWorker, native World, workbench Rapier owner,
# built-in canvases and #406 ballistic Water/spray all remain unchanged.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const BASE_MAIN_SHA := "4c2c97323d862afdd3ec6730017127cc8e4ec05c"
const DURATION_SECONDS := 60
const PROFILES := [
	{"name":"my-canvas", "label":Setup.DEFAULT_LABEL, "pressure_gas":true},
	{"name":"bench-canvas", "label":Setup.BENCH_LABEL, "pressure_gas":true},
	{"name":"stress-canvas", "label":Setup.STRESS_LABEL, "pressure_gas":false},
]

var checks := 0
var failures := 0
var failure_messages: Array[String] = []
var rows: Array[Dictionary] = []
var output_dir := ""

class AcceptanceHarness:
	extends "res://scripts/main.gd"

	var measurement_active := false
	var process_interval_ms: Array[float] = []
	var physics_interval_ms: Array[float] = []
	var process_callback_ms: Array[float] = []
	var physics_callback_ms: Array[float] = []
	var snapshot_consume_ms: Array[float] = []
	var terrain_gate_ms: Array[float] = []
	var native_tick_ms: Array[float] = []
	var worker_step_ms: Array[float] = []
	var snapshot_copy_ms: Array[float] = []
	var worker_pipeline_residual_ms: Array[float] = []
	var retained_snapshot_age_ms: Array[float] = []
	var retained_render_age_ms: Array[float] = []
	var hard_packet_ints: Array[float] = []
	var hard_revision_changes := 0
	var snapshot_publications := 0
	var render_publications := 0
	var rapier_callbacks := 0
	var rapier_wait_callbacks := 0
	var water_checks := 0
	var water_mismatches := 0
	var first_water_mismatch: Dictionary = {}
	var maximum_scheduler_jobs := 0
	var maximum_parallel_phases := 0
	var maximum_worker_overruns := 0
	var _last_process_usec := 0
	var _last_physics_usec := 0
	var _last_snapshot_serial := -1
	var _last_render_serial := -1
	var _last_hard_revision := -1

	func begin_measurement() -> void:
		process_interval_ms.clear()
		physics_interval_ms.clear()
		process_callback_ms.clear()
		physics_callback_ms.clear()
		snapshot_consume_ms.clear()
		terrain_gate_ms.clear()
		native_tick_ms.clear()
		worker_step_ms.clear()
		snapshot_copy_ms.clear()
		worker_pipeline_residual_ms.clear()
		retained_snapshot_age_ms.clear()
		retained_render_age_ms.clear()
		hard_packet_ints.clear()
		hard_revision_changes = 0
		snapshot_publications = 0
		render_publications = 0
		rapier_callbacks = 0
		rapier_wait_callbacks = 0
		water_checks = 0
		water_mismatches = 0
		first_water_mismatch.clear()
		maximum_scheduler_jobs = 0
		maximum_parallel_phases = 0
		maximum_worker_overruns = 0
		_last_process_usec = 0
		_last_physics_usec = 0
		_last_snapshot_serial = latest_snapshot.serial if latest_snapshot != null else -1
		_last_render_serial = latest_snapshot.render_snapshot_serial if latest_snapshot != null else -1
		_last_hard_revision = latest_snapshot.hard_surface_revision if latest_snapshot != null else -1
		measurement_active = true

	func end_measurement() -> void:
		measurement_active = false

	func _process(delta: float) -> void:
		var entered := Time.get_ticks_usec()
		if measurement_active and _last_process_usec > 0:
			process_interval_ms.append(float(entered - _last_process_usec) / 1000.0)
		_last_process_usec = entered
		super._process(delta)
		var completed := Time.get_ticks_usec()
		if measurement_active:
			process_callback_ms.append(float(completed - entered) / 1000.0)
			_sample_publication(completed)
			_sample_water()

	func _physics_process(delta: float) -> void:
		var entered := Time.get_ticks_usec()
		if measurement_active and _last_physics_usec > 0:
			physics_interval_ms.append(float(entered - _last_physics_usec) / 1000.0)
		_last_physics_usec = entered
		var before := -1
		if physical_actor_session != null and is_instance_valid(physical_actor_session):
			before = int(physical_actor_session.tick)
		super._physics_process(delta)
		var completed := Time.get_ticks_usec()
		if measurement_active:
			physics_callback_ms.append(float(completed - entered) / 1000.0)
			if before >= 0 and physical_actor_session != null and is_instance_valid(physical_actor_session) and not paused:
				rapier_callbacks += 1
				if int(physical_actor_session.tick) == before:
					rapier_wait_callbacks += 1

	func consume_worker_snapshot() -> void:
		var entered := Time.get_ticks_usec()
		super.consume_worker_snapshot()
		if measurement_active:
			snapshot_consume_ms.append(float(Time.get_ticks_usec() - entered) / 1000.0)

	func _workbench_terrain_installed(snapshot: CyberSimulationSnapshot) -> bool:
		var entered := Time.get_ticks_usec()
		var result := super._workbench_terrain_installed(snapshot)
		if measurement_active:
			terrain_gate_ms.append(float(Time.get_ticks_usec() - entered) / 1000.0)
		return result

	func _sample_publication(now_usec: int) -> void:
		if latest_snapshot == null:
			return
		if latest_snapshot.published_usec > 0:
			retained_snapshot_age_ms.append(maxf(0.0,
				float(now_usec - latest_snapshot.published_usec) / 1000.0))
		if latest_snapshot.render_generated_usec > 0:
			retained_render_age_ms.append(maxf(0.0,
				float(now_usec - latest_snapshot.render_generated_usec) / 1000.0))
		if latest_snapshot.serial == _last_snapshot_serial:
			return
		_last_snapshot_serial = int(latest_snapshot.serial)
		snapshot_publications += 1
		native_tick_ms.append(float(latest_snapshot.simulation_time_ms))
		worker_step_ms.append(float(latest_snapshot.worker_step_time_ms))
		snapshot_copy_ms.append(float(latest_snapshot.snapshot_copy_time_ms))
		worker_pipeline_residual_ms.append(maxf(0.0,
			float(latest_snapshot.worker_step_time_ms)
			- float(latest_snapshot.simulation_time_ms)
			- float(latest_snapshot.snapshot_copy_time_ms)))
		maximum_scheduler_jobs = maxi(maximum_scheduler_jobs,
			int(latest_snapshot.scheduler_jobs_last_tick))
		maximum_parallel_phases = maxi(maximum_parallel_phases,
			int(latest_snapshot.scheduler_parallel_phases_last_tick))
		maximum_worker_overruns = maxi(maximum_worker_overruns,
			int(latest_snapshot.worker_overruns))
		if latest_snapshot.hard_surface_chunk_rectangles_valid:
			hard_packet_ints.append(float(latest_snapshot.hard_surface_chunk_rectangles.size()))
		if int(latest_snapshot.hard_surface_revision) != _last_hard_revision:
			hard_revision_changes += 1
			_last_hard_revision = int(latest_snapshot.hard_surface_revision)
		if int(latest_snapshot.render_snapshot_serial) != _last_render_serial:
			render_publications += 1
			_last_render_serial = int(latest_snapshot.render_snapshot_serial)

	func _sample_water() -> void:
		var spray: Dictionary = tower_context.get("water_spray", {})
		var water: Dictionary = spray.get("water", {})
		if water.is_empty():
			return
		water_checks += 1
		var total := int(water.get("total", -1))
		var expected := int(water.get("expected", -2))
		if total != expected:
			water_mismatches += 1
			if first_water_mismatch.is_empty():
				first_water_mismatch = {
					"total": total,
					"expected": expected,
					"snapshot_serial": latest_snapshot.serial if latest_snapshot != null else -1,
					"tick": latest_snapshot.tick_index if latest_snapshot != null else -1,
				}

func _initialize() -> void:
	print("CYBERSAND_CI_POLICY ", JSON.stringify(Watchdogs.identity()))
	run.call_deferred()

func expect(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		failure_messages.append(message)
		push_error("CURRENT_MAIN_GAMEPLAY_ACCEPTANCE: " + message)
	return ok

func wait_for(predicate: Callable, timeout_ms: int = -1) -> bool:
	if timeout_ms < 0:
		timeout_ms = Watchdogs.milliseconds("operation_seconds")
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())

func installed(desktop, panel) -> bool:
	return (is_instance_valid(desktop) and panel != null
		and not panel.applied.is_empty() and not panel.busy()
		and desktop.pending_microscenario_apply.is_empty())

func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count":0, "mean":0.0, "p50":0.0, "p95":0.0, "p99":0.0, "max":0.0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total := 0.0
	for value: float in values:
		total += value
	return {
		"count":values.size(),
		"mean":total / float(values.size()),
		"p50":ordered[clampi(ceili(values.size()*0.50)-1,0,ordered.size()-1)],
		"p95":ordered[clampi(ceili(values.size()*0.95)-1,0,ordered.size()-1)],
		"p99":ordered[clampi(ceili(values.size()*0.99)-1,0,ordered.size()-1)],
		"max":ordered[-1],
	}

func _material_present(image: Image, material: int) -> bool:
	var bytes := image.get_data()
	var channels := 2 if image.get_format() == Image.FORMAT_RG8 else 1
	for i in range(0, bytes.size(), channels):
		if int(bytes[i]) == material:
			return true
	return false

func _water_assignment(desktop) -> Dictionary:
	for row: Dictionary in desktop.tower_context.get("liquid_solver_policy", {}).get("assignments", []):
		if int(row.get("material", -1)) == Setup.WATER:
			return row.duplicate(true)
	return {}

func _stage_pressureflow(desktop, panel, gas_on: bool) -> bool:
	var bridge: Variant = panel._liquids.bridge
	var request := PackedInt32Array(panel.applied.liquid_policy)
	var selected: Dictionary = {}
	for option: Dictionary in bridge.liquid_policy_assignment_choices(request, Setup.WATER):
		if (str(option.get("family", "")) == "pressure_flow_v1"
			and str(option.get("variant", "")) == "cached_dormant"
			and bool(option.get("accepted", false))):
			selected = option
			break
	if not expect(not selected.is_empty(), "PressureFlow cached_dormant is admitted"):
		return false
	var gas: Dictionary = bridge.liquid_policy_with_pressure_gas(
		PackedInt32Array(selected.request), gas_on)
	if not expect(bool(gas.get("accepted", false)),
			"PressureFlow gas selection accepted (" + str(gas_on) + ")"):
		return false
	panel._liquids.requested_policy = PackedInt32Array(gas.request)
	desktop.workbench_water_options.merge({
		"workbench_ballistic":true,
		"workbench_face_release":true,
		"workbench_face_budget":320,
		"workbench_face_speed":288,
		"workbench_face_period":1,
		"workbench_face_min_height":4,
	}, true)
	if not expect(panel.apply_liquids(), "rebuild requested with PressureFlow + ballistic Water"):
		return false
	if not expect(await wait_for(Callable(self, "installed").bind(desktop, panel)),
			"PressureFlow + ballistic rebuild acknowledged"):
		return false
	var assignment := _water_assignment(desktop)
	return expect(str(assignment.get("applied_family", "")) == "pressure_flow_v1"
		and str(assignment.get("applied_variant", "")) == "cached_dormant",
		"native Water assignment reads back PressureFlow cached_dormant")

func _load_profile(desktop, panel, profile: Dictionary) -> bool:
	var label := str(profile.label)
	if not expect(not FileAccess.file_exists(Setup._path(label)),
			"fresh acceptance owner has no saved override for " + label):
		return false
	panel._name.text = label
	if not expect(panel.load_setup(), "load built-in " + label + " / " + panel.message):
		return false
	if not expect(await wait_for(Callable(self, "installed").bind(desktop, panel)),
			label + " installation acknowledged"):
		return false
	if not expect(desktop.physical_actor_session != null
			and desktop.physical_actor_session.bodies().size() > 0,
			label + " has active Rapier actors"):
		return false
	expect(_material_present(desktop.image, Setup.WATER), label + " contains real Water")
	expect(_material_present(desktop.image, Setup.SAND), label + " contains real Sand")
	return await _stage_pressureflow(desktop, panel, bool(profile.pressure_gas))

func _capture(name: String) -> String:
	var path := output_dir.path_join(name + ".png")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		expect(false, "graphical framebuffer available for " + name)
		return ""
	var err := image.save_png(path)
	expect(err == OK, "graphical screenshot saved for " + name)
	return path if err == OK else ""

func _profile(desktop, panel, profile: Dictionary) -> Dictionary:
	var name := str(profile.name)
	var ok := await _load_profile(desktop, panel, profile)
	if not ok:
		return {"name":name, "completed":false, "setup_failed":true}
	var spray_request_ok: bool = bool(panel.water_spray.request({"enabled":true, "jet_enabled":false}))
	expect(spray_request_ok, name + " impact-spray request queued")
	if desktop.paused:
		panel.toggle_pause()
	var spray_ready := await wait_for(func() -> bool:
		var spray: Dictionary = desktop.tower_context.get("water_spray", {})
		return bool(spray.get("ballistic_enabled", false)) 			and bool(spray.get("settings", {}).get("enabled", false)), 30000)
	expect(spray_ready, name + " ballistic Water and impact spray applied")
	if not spray_ready:
		if not desktop.paused:
			panel.toggle_pause()
		return {"name":name, "completed":false, "spray_setup_failed":true}

	var initial_native := int(desktop.latest_snapshot.tick_index)
	var initial_rapier := int(desktop.physical_actor_session.tick)
	var initial_serial := int(desktop.latest_snapshot.serial)
	var started_usec := Time.get_ticks_usec()
	var deadline := Time.get_ticks_msec() + DURATION_SECONDS * 1000
	desktop.begin_measurement()
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if desktop.simulation_worker.has_failed():
			expect(false, name + " entered worker failure quarantine")
			break
	desktop.end_measurement()
	var ended_usec := Time.get_ticks_usec()
	var final_native := int(desktop.latest_snapshot.tick_index)
	var final_rapier := int(desktop.physical_actor_session.tick)
	if not desktop.paused:
		panel.toggle_pause()
	await process_frame

	var spray: Dictionary = desktop.tower_context.get("water_spray", {}).duplicate(true)
	var water: Dictionary = spray.get("water", {})
	var coupling: Dictionary = spray.get("totals", {})
	var elapsed_ms := maxf(0.001, float(ended_usec - started_usec) / 1000.0)
	var native_ticks := final_native - initial_native
	var rapier_ticks := final_rapier - initial_rapier
	expect(native_ticks > 0, name + " native simulation made progress")
	expect(rapier_ticks > 0, name + " Rapier simulation made progress")
	expect(desktop.water_checks > 0 and desktop.water_mismatches == 0,
		name + " exact closed-system Water ledger remained conserved")
	var ballistic_ledger: Dictionary = spray.get("ledger", {})
	expect(int(ballistic_ledger.get("launched_parcels", 0)) > 0,
		name + " ballistic parcel transport was observed")
	var screenshot := await _capture(name)
	var assignment := _water_assignment(desktop)
	return {
		"name":name,
		"completed":not desktop.simulation_worker.has_failed() and native_ticks > 0 and rapier_ticks > 0,
		"duration_target_seconds":DURATION_SECONDS,
		"elapsed_wall_ms":elapsed_ms,
		"pressure_gas_requested":bool(profile.pressure_gas),
		"water_assignment":assignment,
		"actors":desktop.physical_actor_session.bodies().size(),
		"initial_snapshot_serial":initial_serial,
		"snapshot_publications":desktop.snapshot_publications,
		"render_publications":desktop.render_publications,
		"completed_native_ticks":native_ticks,
		"completed_native_hz":float(native_ticks)*1000.0/elapsed_ms,
		"completed_rapier_ticks":rapier_ticks,
		"completed_rapier_hz":float(rapier_ticks)*1000.0/elapsed_ms,
		"process_interval_ms":statistics(desktop.process_interval_ms),
		"physics_interval_ms":statistics(desktop.physics_interval_ms),
		"process_callback_ms":statistics(desktop.process_callback_ms),
		"physics_callback_ms":statistics(desktop.physics_callback_ms),
		"snapshot_consume_ms":statistics(desktop.snapshot_consume_ms),
		"native_tick_ms":statistics(desktop.native_tick_ms),
		"worker_step_ms":statistics(desktop.worker_step_ms),
		"snapshot_copy_ms":statistics(desktop.snapshot_copy_ms),
		"worker_pipeline_residual_ms":statistics(desktop.worker_pipeline_residual_ms),
		"retained_snapshot_age_ms":statistics(desktop.retained_snapshot_age_ms),
		"retained_render_age_ms":statistics(desktop.retained_render_age_ms),
		"main_workbench_terrain_gate_ms":statistics(desktop.terrain_gate_ms),
		"hard_surface_revision_changes":desktop.hard_revision_changes,
		"hard_surface_packet_ints":statistics(desktop.hard_packet_ints),
		"rapier_callbacks":desktop.rapier_callbacks,
		"rapier_wait_callbacks":desktop.rapier_wait_callbacks,
		"rapier_wait_fraction":float(desktop.rapier_wait_callbacks) / maxf(1.0, float(desktop.rapier_callbacks)),
		"maximum_scheduler_jobs":desktop.maximum_scheduler_jobs,
		"maximum_parallel_phases":desktop.maximum_parallel_phases,
		"maximum_worker_overruns":desktop.maximum_worker_overruns,
		"water_checks":desktop.water_checks,
		"water_mismatches":desktop.water_mismatches,
		"first_water_mismatch":desktop.first_water_mismatch,
		"water_final":water,
		"spray_final":spray,
		"screenshot":screenshot.get_file() if not screenshot.is_empty() else "",
		"raw":{
			"process_interval_ms":desktop.process_interval_ms.duplicate(),
			"physics_interval_ms":desktop.physics_interval_ms.duplicate(),
			"process_callback_ms":desktop.process_callback_ms.duplicate(),
			"physics_callback_ms":desktop.physics_callback_ms.duplicate(),
			"snapshot_consume_ms":desktop.snapshot_consume_ms.duplicate(),
			"native_tick_ms":desktop.native_tick_ms.duplicate(),
			"worker_step_ms":desktop.worker_step_ms.duplicate(),
			"snapshot_copy_ms":desktop.snapshot_copy_ms.duplicate(),
			"worker_pipeline_residual_ms":desktop.worker_pipeline_residual_ms.duplicate(),
			"retained_snapshot_age_ms":desktop.retained_snapshot_age_ms.duplicate(),
			"retained_render_age_ms":desktop.retained_render_age_ms.duplicate(),
			"main_workbench_terrain_gate_ms":desktop.terrain_gate_ms.duplicate(),
			"hard_surface_packet_ints":desktop.hard_packet_ints.duplicate(),
		},
	}

func _write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return true

func run() -> void:
	output_dir = OS.get_environment("CYBERSAND_GAMEPLAY_ACCEPTANCE_OUTPUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://current-main-gameplay-acceptance")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1920, 1080)
	set_meta("cybersand_feature", "shared_workbench")
	var desktop = load("res://main.tscn").instantiate()
	desktop.set_script(AcceptanceHarness)
	root.add_child(desktop)
	await process_frame
	var panel = desktop.shared_workbench
	var ready := panel != null and await wait_for(Callable(self, "installed").bind(desktop, panel))
	expect(ready, "current-main shared workbench owner installed")
	if ready:
		for profile: Dictionary in PROFILES:
			rows.append(await _profile(desktop, panel, profile))

	var worker: CyberSimulationWorker = desktop.simulation_worker
	var final_session = desktop.physical_actor_session
	desktop.queue_free()
	await process_frame
	await process_frame
	await process_frame
	var worker_joined := worker != null and not worker._thread.is_started()
	expect(worker_joined, "scene exit joined exclusive simulation worker")
	expect(final_session == null or not is_instance_valid(final_session),
		"scene exit retired main-thread Rapier session")

	var complete_rows := 0
	var screenshots := 0
	var impact_profiles := 0
	for row: Dictionary in rows:
		complete_rows += int(bool(row.get("completed", false)))
		screenshots += int(not str(row.get("screenshot", "")).is_empty())
		var totals: Dictionary = row.get("spray_final", {}).get("totals", {})
		if int(totals.get("launched", 0)) + int(totals.get("lifted", 0)) > 0:
			impact_profiles += 1
	expect(impact_profiles > 0, "body-driven impact spray was observed in at least one registered profile")
	var verdict := "ACCEPT" if failures == 0 and complete_rows == PROFILES.size() and screenshots == PROFILES.size() else "REPAIR"
	var result := {
		"schema":"cybersand-current-main-integrated-gameplay-acceptance-v1",
		"registered_main":BASE_MAIN_SHA,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"platform":OS.get_name(),
		"display_server":DisplayServer.get_name(),
		"godot":str(Engine.get_version_info().get("string", "")),
		"duration_seconds_per_profile":DURATION_SECONDS,
		"profiles":rows,
		"checks":checks,
		"failures":failures,
		"failure_messages":failure_messages,
		"worker_joined":worker_joined,
		"impact_spray_profiles":impact_profiles,
		"verdict":verdict,
		"scope":{
			"source_authority":"registered current-main production source; qualification files only differ",
			"native_rapier_path":"production shared workbench owner",
			"rendered_windows_graphics":true,
			"human_feel_qualified":false,
			"physical_input_device_qualified":false,
			"lockstep_comparison":"not substituted; #474 is a separate non-main source stack",
			"collider_extraction_isolated":false,
			"collider_measurement":"published hard-packet size/revision plus Main terrain-gate timing; worker_pipeline_residual_ms is non-isolated and must not be relabelled collider extraction",
			"performance_thresholds":"none; performance distributions are evidence, correctness gates are separate",
		},
	}
	var wrote := _write_json(output_dir.path_join("results.json"), result)
	if not wrote:
		push_error("CURRENT_MAIN_GAMEPLAY_ACCEPTANCE: results.json could not be written")
		quit(1)
		return
	print("CURRENT_MAIN_GAMEPLAY_ACCEPTANCE ", JSON.stringify(result))
	quit(0 if verdict == "ACCEPT" else 1)