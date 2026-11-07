extends SceneTree

# Non-gating profiler for the built-in workbench canvases.
#
# Example:
#   CYBERSAND_SOURCE_SHA=<exact-head> godot --headless --path godot \
#     --script res://scripts/hard_surface_packet_profile.gd -- --workbench
#
# Timing is observational and must not be used as a CI pass/fail threshold.
# Correctness belongs to test_hard_surface_incremental_packet.gd.

const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

const WARMUP_TICKS := 30
const SAMPLE_TICKS := 180

var main: Control
var panel


func _initialize() -> void:
	_run.call_deferred()


func _until(test: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while not test.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if test.call():
		return true
	push_error("HARD_SURFACE_PROFILE: timeout: " + label)
	return false


func _installed() -> bool:
	return (
		panel != null
		and not panel.applied.is_empty()
		and not panel.busy()
		and main.pending_microscenario_apply.is_empty()
	)


func _native_binary_path() -> String:
	if OS.get_name() == "Windows":
		return "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
	return "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(round((sorted.size() - 1) * fraction)), 0, sorted.size() - 1)
	return sorted[index]


func _summary(values: Array[float], positive_only: bool = false) -> Dictionary:
	var selected: Array[float] = []
	for value: float in values:
		if not positive_only or value > 0.0:
			selected.append(value)
	if selected.is_empty():
		return {"samples": 0, "mean_ms": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	var total := 0.0
	var maximum := 0.0
	for value: float in selected:
		total += value
		maximum = maxf(maximum, value)
	return {
		"samples": selected.size(),
		"mean_ms": total / selected.size(),
		"p50_ms": _percentile(selected, 0.50),
		"p95_ms": _percentile(selected, 0.95),
		"max_ms": maximum,
	}


func _profile(label: String) -> bool:
	var policy: PackedInt32Array = panel._liquids.bridge.default_liquid_policy()
	var candidate: Dictionary = Setup.builtin(label, policy)
	if candidate.is_empty():
		push_error("HARD_SURFACE_PROFILE: missing built-in " + label)
		return false
	if not panel.apply(candidate):
		push_error("HARD_SURFACE_PROFILE: install refused: " + label + " / " + main.microscenario_error)
		return false
	if not await _until(_installed, label + " install"):
		return false

	var start_tick: int = int(main.latest_snapshot.tick_index)
	var end_tick := start_tick + WARMUP_TICKS + SAMPLE_TICKS
	var last_serial := -1
	var simulation: Array[float] = []
	var copy_total: Array[float] = []
	var render_exchange: Array[float] = []
	var hard_packet: Array[float] = []
	var publication: Array[float] = []
	var wall_started_usec := Time.get_ticks_usec()

	panel.toggle_pause()
	while int(main.latest_snapshot.tick_index) < end_tick:
		await process_frame
		if main.simulation_worker.has_failed():
			push_error("HARD_SURFACE_PROFILE: worker failed on " + label + ": " + main.microscenario_error)
			return false
		var snapshot: CyberSimulationSnapshot = main.latest_snapshot
		if snapshot == null or snapshot.serial == last_serial:
			continue
		last_serial = snapshot.serial
		if snapshot.tick_index < start_tick + WARMUP_TICKS:
			continue
		simulation.append(snapshot.simulation_time_ms)
		copy_total.append(snapshot.snapshot_copy_time_ms)
		render_exchange.append(snapshot.render_exchange_time_ms)
		hard_packet.append(snapshot.hard_surface_packet_time_ms)
		publication.append(snapshot.snapshot_publication_time_ms)
	var wall_ms := float(Time.get_ticks_usec() - wall_started_usec) / 1000.0
	panel.toggle_pause()
	if not await _until(_installed, label + " pause"):
		return false

	var extent: Vector2i = Setup.extent_of(candidate)
	var record := {
		"schema": "cybersand-hard-surface-profile-v1",
		"canvas": label,
		"extent": [extent.x, extent.y],
		"warmup_ticks": WARMUP_TICKS,
		"requested_sample_ticks": SAMPLE_TICKS,
		"observed_snapshots": publication.size(),
		"wall_ms": wall_ms,
		"simulation": _summary(simulation),
		"snapshot_copy_total": _summary(copy_total),
		"render_exchange_executed": _summary(render_exchange, true),
		"hard_surface_packet_executed": _summary(hard_packet, true),
		"publication_build": _summary(publication),
		"source_sha": OS.get_environment("CYBERSAND_SOURCE_SHA"),
		"runtime": {
			"os": OS.get_name(),
			"processor": OS.get_processor_name(),
			"logical_cpus": OS.get_processor_count(),
			"godot": Engine.get_version_info().string,
			"native_binary": _native_binary_path(),
			"native_sha256": FileAccess.get_sha256(_native_binary_path()),
			"window": [root.size.x, root.size.y],
			"headless": DisplayServer.get_name() == "headless",
		},
	}
	print("HARD_SURFACE_PROFILE ", JSON.stringify(record))
	return true


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	if "--workbench" not in OS.get_cmdline_user_args():
		current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	if panel == null or not await _until(_installed, "initial workbench"):
		quit(1)
		return

	var ok := true
	for label: String in Setup.BUILTIN_LABELS:
		if not await _profile(label):
			ok = false
			break
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if ok else 1)
