extends SceneTree

# Prospectively bounded, single-host, NO LEARNING flight throughput pilot.
# Run explicitly on a GitHub-hosted Godot/Rapier/native checkout. This is not
# simulated throughput and never consumes a neural training allocation.
const Episode = preload("res://scripts/physical_flight_episode.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const MAX_TICKS_PER_PROFILE: int = 240
const TOTAL_BUDGET_TICKS: int = 960
var episode: CyberPhysicalFlightEpisode


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		push_error("4LY003_PILOT: no actual native/Rapier host")
		quit(1)
		return
	var parent := Node2D.new()
	root.add_child(parent)
	episode = Episode.new()
	parent.add_child(episode)
	var start_wall_usec: int = Time.get_ticks_usec()
	var physics_ticks: int = 0
	var decisions: int = 0
	var serialized: int = 0
	var serialization_usec: int = 0
	var reset_usec: int = 0
	var reports: Array = []
	for model: StringName in Profile.IDS:
		if not episode.reset(model, "horizontal_reach", 103, "development", &"teacher"):
			push_error("4LY003_PILOT: real host refused " + str(model) + ": " + episode.last_error)
			quit(1)
			return
		reset_usec += int(episode.record().reset_microseconds)
		var current: int = 0
		while current < MAX_TICKS_PER_PROFILE and not bool(episode.transition(0).episode_done):
			var view: Dictionary = episode.observe()
			var action: Variant = null
			var observed_id: String = ""
			if current % Episode.DECISION_TICKS == 0:
				action = episode.reference_action()
				observed_id = str(view.observation_id)
				var serialization_start: int = Time.get_ticks_usec()
				var as_json: String = JSON.stringify(Arena.json_value(view))
				serialization_usec += Time.get_ticks_usec() - serialization_start
				serialized += as_json.length()
				decisions += 1
			var transition: Dictionary = episode.tick(action, observed_id, 1)
			if bool(transition.failed) or int(transition.ticks_consumed) != 1:
				push_error("4LY003_PILOT: failed actual-host tick " + str(model) + " " + str(transition.reason))
				quit(1)
				return
			current += int(transition.ticks_consumed)
			physics_ticks += int(transition.ticks_consumed)
		reports.append({"profile_id": str(model), "metrics": episode.metrics(),
			"manifest": episode.manifest(), "reset_microseconds": episode.record().reset_microseconds})
	var wall_sec: float = float(Time.get_ticks_usec() - start_wall_usec) / 1000000.0
	var report: Dictionary = {
		"schema": "4ly-throughput-pilot/v1",
		"claim": "actual native+Rapier stepped single-host development pilot, no neural learning",
		"prospective_tick_budget": TOTAL_BUDGET_TICKS, "ticks_consumed": physics_ticks,
		"decision_interval_ticks": Episode.DECISION_TICKS, "decisions": decisions,
		"physical_ticks_per_wall_second": float(physics_ticks) / maxf(wall_sec, 0.0001),
		"decisions_per_wall_second": float(decisions) / maxf(wall_sec, 0.0001),
		"json_serialization_bytes": serialized,
		"json_serialization_microseconds": serialization_usec,
		"reset_microseconds_total": reset_usec,
		"host_concurrency": 1, "transport_overhead_microseconds": null,
		"inference_overhead_microseconds": null,
		"godot": str(Engine.get_version_info().get("string", "")),
		"os": OS.get_name(), "processor": OS.get_processor_name(),
		"logical_processors": OS.get_processor_count(),
		"static_memory_bytes": OS.get_static_memory_usage(),
		"static_memory_peak_bytes": OS.get_static_memory_peak_usage(),
		"github_checkout_sha": OS.get_environment("GITHUB_SHA"),
		"github_ref": OS.get_environment("GITHUB_REF"),
		"elapsed_wall_seconds": wall_sec,
		"reports": reports
	}
	var stored := FileAccess.open("user://4ly003_pilot_report.json", FileAccess.WRITE)
	if stored != null:
		stored.store_string(JSON.stringify(Arena.json_value(report), "\t"))
		stored.close()
	var retained_dir: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if not retained_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(retained_dir)
		var archive: FileAccess = FileAccess.open(retained_dir.path_join("4ly003_actual_host_pilot.json"), FileAccess.WRITE)
		if archive != null:
			archive.store_string(JSON.stringify(Arena.json_value(report)))
			archive.close()
	print("4LY003_ACTUAL_HOST_PILOT ", JSON.stringify(Arena.json_value(report)))
	episode.close()
	parent.free()
	await process_frame
	quit(0)
