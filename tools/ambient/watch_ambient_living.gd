extends "res://tests/capture_ambient_living_examples.gd"

# External observer. This file lives outside the frozen Godot project and uses
# only ordinary Workbench authoring/camera controls and copied owner views.
# It never submits actor commands, teleports bodies, steps World directly or
# changes a profile. Render samples are not a continuous-rate video recording.
const WATCH_SCHEMA := "ambient-living-sustained-watch/v1"
const WATCH_SCENES := {
	"ambient2-courtyard":1,
	"ambient2-refinery":5,
	"ambient2-settlement":7,
}
const MAX_WATCH_SAMPLES := 121
const MAX_WATCH_ACTORS := 8
var _watch_scene := ""
var _watch_seconds := 60
var _watch_actor := 1
var _watch_first_tick := 0
var _watch_first_native := 0
var _watch_first_time := 0.0
var _watch_wall_begin := 0
var _watch_samples: Array = []
var _watch_camera_events: Array = []
var _watch_draws: Dictionary = {}
var _watch_mode := "overview"


func _watch_json(value: Variant, depth: int = 0) -> Variant:
	if depth > 10: return "bounded observer depth exceeded"
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		var copied := {}
		for key: Variant in value: copied[str(key)] = _watch_json(value[key], depth + 1)
		return copied
	if value is Array:
		var copied: Array = []
		for entry: Variant in value: copied.append(_watch_json(entry, depth + 1))
		return copied
	if value is StringName: return str(value)
	return value


func _watch_keys(value: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key: String in keys:
		if value.has(key): result[key] = _watch_json(value[key])
	return result


func _watch_memory(memory: Dictionary) -> Dictionary:
	var result := _watch_keys(memory, ["enabled", "available", "reason", "identity", "cell_size",
		"lifetime_seconds", "capacity", "interest_capacity", "obstruction_capacity",
		"visit_admissions", "reentries", "failure_events", "evictions", "forgotten"])
	for key: String in ["visited", "interests", "obstructions"]:
		var entries: Array = memory.get(key, [])
		result[key + "_count"] = entries.size()
		# Small copied tails support interpretation without copying every cell.
		var retained: Array = []
		for index: int in range(maxi(0, entries.size() - 8), entries.size()):
			retained.append(_watch_json(entries[index]))
		result[key + "_tail"] = retained
	return result


func _watch_environment(environment: Dictionary) -> Dictionary:
	var result := _watch_keys(environment, ["available", "reason", "position", "tick", "world_generation"])
	var materials: Dictionary = environment.get("materials", {})
	var targets: Dictionary = materials.get("targets", {})
	result["materials"] = _watch_keys(materials, ["available", "reason", "coverage", "sample_tick",
		"revision", "world_generation", "sample_count", "query_count", "sample_budget"])
	result.materials["target_count"] = targets.size()
	var retained_targets: Dictionary = {}
	for key: Variant in targets:
		if retained_targets.size() >= 8: break
		retained_targets[str(key)] = _watch_keys(targets[key], ["available", "present", "reason", "nearest",
			"distance", "count", "radius_cells", "coverage", "coverage_complete", "absence_scope",
			"sample_tick", "revision", "incomplete", "stale"])
	result.materials["targets"] = retained_targets
	var neighbors: Dictionary = environment.get("neighbors", {})
	result["neighbors"] = _watch_keys(neighbors, ["available", "reason", "coverage", "incomplete", "examined", "invalid"])
	var peers: Array = neighbors.get("actors", [])
	var retained_peers: Array = []
	for index: int in mini(peers.size(), 16):
		retained_peers.append(_watch_keys(peers[index], ["id", "position", "distance", "compatible",
			"affinity", "tags", "velocity", "velocity_available", "sample_tick"]))
	result.neighbors["actors"] = retained_peers
	var navigation: Dictionary = environment.get("navigation", {})
	result["navigation"] = _watch_keys(navigation, ["available", "reason", "source", "semantics", "ray_queries", "ray_budget"])
	var rays: Array = navigation.get("directions", [])
	var retained_rays: Array = []
	for index: int in mini(rays.size(), 8):
		retained_rays.append(_watch_keys(rays[index], ["available", "direction", "hit", "clearance_cells",
			"boundary", "origin", "position", "reason"]))
	result.navigation["directions"] = retained_rays
	return result


func _watch_actor_view(actor: Dictionary) -> Dictionary:
	var view: Dictionary = host.physical_actor_session.workbench_control(int(actor.id))
	var observation: Dictionary = view.get("observation", {})
	var diagnostics: Dictionary = view.get("diagnostics", {})
	var ambient: Dictionary = diagnostics.get("ambient", {})
	var result := _watch_keys(view, ["instance_id", "actor_id", "run_id", "epoch", "tick", "generation",
		"status", "accepted", "rejected", "error", "lease_remaining", "decision_usec", "sensor_usec", "simulation_time_seconds"])
	result["model"] = str(actor.model)
	result["profile_id"] = str(actor.control.get("ambient", {}).get("id", ""))
	result["profile_name"] = str(actor.control.get("ambient", {}).get("name", ""))
	result["observation"] = _watch_keys(observation, ["position", "velocity", "rotation", "grounded",
		"energy", "charge", "blocked", "stuck_time", "flight_mode", "action", "fault"])
	result["decisions"] = int(ambient.get("decisions", 0))
	result["elapsed_seconds"] = float(ambient.get("elapsed_seconds", 0.0))
	result["intent"] = _watch_keys(ambient.get("intent", {}), ["direction", "pace", "effort", "reason",
		"active_override", "remaining_seconds", "selected_goal", "goal_target", "goal_phase", "goal_key",
		"commitment_remaining_seconds", "phase_selected_seconds"])
	result["drives"] = _watch_json(ambient.get("drives", {}))
	result["memory"] = _watch_memory(ambient.get("memory", {}))
	var recent: Array = ambient.get("recent_decisions", [])
	var tail: Array = []
	for index: int in range(maxi(0, recent.size() - 8), recent.size()): tail.append(_watch_json(recent[index]))
	result["recent_decisions_tail"] = tail
	result["environment"] = _watch_environment(diagnostics.get("environment", {}))
	return result


func _watch_time() -> float:
	if host == null or host.physical_actor_session == null: return 0.0
	var view: Dictionary = host.physical_actor_session.workbench_control(_watch_actor)
	return float(view.get("simulation_time_seconds", 0.0))


func _watch_capture(second: int) -> void:
	if not check(_watch_samples.size() < MAX_WATCH_SAMPLES, "bounded sustained sample capacity"): return
	var previous_count := captures.size()
	await capture("frame-%04d" % second,
		"Actual ordinary Workbench sample at requested simulation second %d; camera %s. Not a continuous video frame." % [second, _watch_mode])
	if captures.size() != previous_count + 1: return
	var actors: Array = []
	for actor: Dictionary in wb.applied.get("actors", []):
		if not check(actors.size() < MAX_WATCH_ACTORS, "authoritative eight physical actors"): break
		actors.append(_watch_actor_view(actor))
	_watch_samples.append({"requested_simulation_second":second, "camera_mode":_watch_mode,
		"focus_actor":_watch_actor, "wall_seconds_since_play":float(Time.get_ticks_usec() - _watch_wall_begin) / 1000000.0,
		"simulation_seconds_since_play":_watch_time() - _watch_first_time,
		"diagnostics_physical_tick":physical_tick(), "diagnostics_native_tick":native_tick(),
		"capture":_watch_json(captures[-1]), "actors":actors})
	_watch_flush("running")


func _watch_report(status: String) -> Dictionary:
	var script_path: String = get_script().resource_path
	return {"schema":WATCH_SCHEMA, "status":status, "scene":_watch_scene, "follow_actor":_watch_actor,
		"requested_simulation_seconds":_watch_seconds, "requested_sample_interval_seconds":1.0,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"observer_script_sha256":FileAccess.get_sha256(script_path),
		"godot":Engine.get_version_info().string, "platform":OS.get_name(), "display":DisplayServer.get_name(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"renderer":RenderingServer.get_video_adapter_name(), "renderer_vendor":RenderingServer.get_video_adapter_vendor(),
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"actual_framebuffer_size":[root.size.x, root.size.y], "physics_ticks_per_second":Engine.physics_ticks_per_second,
		"first_physical_tick":_watch_first_tick, "first_native_tick":_watch_first_native,
		"physical_ticks":physical_tick() - _watch_first_tick, "native_ticks":native_tick() - _watch_first_native,
		"actual_simulation_seconds":_watch_time() - _watch_first_time,
		"elapsed_wall_seconds":float(Time.get_ticks_msec() - started) / 1000.0,
		"draw_intervals":_watch_draws, "camera_events":_watch_camera_events,
		"failures":failures, "samples":_watch_samples, "owner_playfeel_accepted":false,
		"limits":["An external observer follows ordinary owned physics and native progression; no actor commands are submitted.",
			"Samples are approximately one per simulation second. Their actual tick/time identities are retained; rendered poses can lag current copied poses.",
			"PNG encoding and copied diagnostic collection are observer overhead. Draw timings are not a no-observer benchmark or monitor latency.",
			"No physical NVIDIA/display acceptance and no cross-platform trajectory bit-determinism claim."]}


func _watch_flush(status: String) -> void:
	if folder.is_empty(): return
	var file := FileAccess.open(folder.path_join("watch-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_watch_report(status), "  ") + "\n")
		file.close()


func show_example(example: Dictionary) -> void:
	if not host.paused: wb.toggle_pause()
	if not check(wb.load_ambient_example(str(example.id)), "ordinary sustained example admission"): return
	if not await until(installed, "ordinary native and physical acknowledgement"): return
	if not check(host.physical_actor_session != null, "ordinary physical owner admitted"): return
	if not check(not wb.actor(wb.applied, _watch_actor).is_empty(), "requested inspected actor exists"): return
	wb.select_instance(_watch_actor)
	wb._camera.select(2)
	wb.set_camera(2)
	_watch_first_tick = physical_tick()
	_watch_first_native = native_tick()
	_watch_first_time = _watch_time()
	_watch_wall_begin = Time.get_ticks_usec()
	_watch_camera_events.append({"requested_second":0, "mode":"overview", "actor":_watch_actor})
	await _watch_capture(0)
	if not failures.is_empty(): return
	if not check(wb.toggle_pause(), "ordinary sustained Play"): return
	_watch_wall_begin = Time.get_ticks_usec()
	_begin_draw_sampling()
	for second: int in range(1, _watch_seconds + 1):
		var wanted_native := _watch_first_native + second * Engine.physics_ticks_per_second - 1
		if not await until(func() -> bool:
			return _watch_time() + 0.000001 >= _watch_first_time + float(second) and native_tick() >= wanted_native,
			"ordinary progression to simulation second %d" % second): break
		if second == 5:
			wb._camera.select(1)
			wb.set_camera(1)
			_watch_mode = "follow_selected"
			_watch_camera_events.append({"requested_second":second, "mode":_watch_mode, "actor":_watch_actor})
		if second == maxi(6, _watch_seconds - 10):
			wb.set_ambient_overlay(_watch_actor, true)
			_watch_mode = "follow_selected_with_copied_overlay"
			_watch_camera_events.append({"requested_second":second, "mode":_watch_mode, "actor":_watch_actor})
		await _watch_capture(second)
		if not failures.is_empty(): break
	_watch_draws = _end_draw_sampling()
	check(_watch_samples.size() == _watch_seconds + 1, "complete actual sustained frame inventory")
	check(_watch_time() + 0.000001 >= _watch_first_time + float(_watch_seconds), "requested actual simulation horizon completed")
	check(native_tick() - _watch_first_native >= _watch_seconds * Engine.physics_ticks_per_second - 1,
		"native owner completed the sustained horizon")


func run() -> void:
	folder = OS.get_environment("CYBERSAND_AMBIENT_LIVING_WATCH")
	_watch_scene = OS.get_environment("CYBERSAND_AMBIENT_WATCH_SCENE")
	_watch_seconds = OS.get_environment("CYBERSAND_AMBIENT_WATCH_SECONDS").to_int()
	if not check(not folder.is_empty(), "external observer output directory supplied") \
		or not check(WATCH_SCENES.has(_watch_scene), "supported ordinary observation scene") \
		or not check(_watch_seconds >= 10 and _watch_seconds <= 120, "bounded 10-120 simulation second horizon") \
		or not check(DisplayServer.get_name() != "headless", "actual graphical display required"):
		await finish(); return
	_watch_actor = int(WATCH_SCENES[_watch_scene])
	DirAccess.make_dir_recursive_absolute(folder)
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null, "ordinary Workbench opens"):
		await finish(); return
	wb = host.shared_workbench
	if not await until(installed, "ordinary startup native owner ready"):
		await finish(); return
	for example: Dictionary in Examples.entries():
		if str(example.id) == _watch_scene:
			await show_example(example)
			break
	check(not _watch_samples.is_empty(), "actual sustained samples were captured")
	await finish()


func finish() -> void:
	if _sample_draws: _watch_draws = _end_draw_sampling()
	_watch_flush("passed" if failures.is_empty() else "failed")
	print("AMBIENT_LIVING_WATCH ", JSON.stringify({"scene":_watch_scene, "failures":failures,
		"samples":_watch_samples.size(), "actual_simulation_seconds":_watch_time() - _watch_first_time}))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
