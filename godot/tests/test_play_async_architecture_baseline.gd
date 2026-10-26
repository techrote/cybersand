extends SceneTree

# PLAY-ASYNC-001 source-bound **short-run** synchronous mechanical baseline.
# Actual Godot physics-frame cadence and full Playground.advance_frame path,
# including presentation packet preparation, with no production behavior edit.
# A headless run DOES NOT measure rendered/GPU presentation or human feel.
const Playground = preload("res://player_playground.tscn")
const Course = preload("res://scripts/player_playground_course.gd")
const WARM_FRAMES: int = 30
const SAMPLE_FRAMES: int = 120

func _initialize() -> void:
	_run.call_deferred()


static func _stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"count": 0}
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in samples:
		total += value
	var n: int = samples.size()
	return {
		"count": n,
		"mean": total / float(n),
		"p50": ordered[clampi(ceili(float(n) * 0.50) - 1, 0, n - 1)],
		"p95": ordered[clampi(ceili(float(n) * 0.95) - 1, 0, n - 1)],
		"p99": ordered[clampi(ceili(float(n) * 0.99) - 1, 0, n - 1)],
		"max": ordered[n - 1],
	}


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("PLAY_ASYNC_BASELINE: source-matched native extension required")
		quit(1)
		return
	var scene: Control = Playground.instantiate()
	root.add_child(scene)
	# Drive the identical public frame method exactly once per physics frame.
	# Its normal callback would otherwise step a second time.
	scene.set_physics_process(false)
	var rows: Array = []
	for index: int in [0, 1, 2, 3, 6]:
		if not scene.select_preset(index):
			push_error("PLAY_ASYNC_BASELINE: preset setup failed for index %d" % index)
			quit(1)
			return
		var id: StringName = Course.PRESETS[index]
		var main_ms: Array[float] = []
		var native_ms: Array[float] = []
		var rapier_ms: Array[float] = []
		var frame_ms: Array[float] = []
		var previous_frame_usec: int = -1
		var action: Dictionary = {
			"move": Vector2.RIGHT if id == &"acrobat" else Vector2.UP,
			"aim": Vector2(0.8, -0.6),
			"effort": 1.0,
		}
		for tick_index: int in range(WARM_FRAMES + SAMPLE_FRAMES):
			await physics_frame
			var frame_usec: int = Time.get_ticks_usec()
			if tick_index >= WARM_FRAMES and previous_frame_usec >= 0:
				frame_ms.append(float(frame_usec - previous_frame_usec) / 1000.0)
			previous_frame_usec = frame_usec
			var step_start_usec: int = Time.get_ticks_usec()
			# Neutral warm-up opens the release-to-rearm gate; sampled phase actuates.
			scene.advance_frame({} if tick_index < WARM_FRAMES else action, true)
			var duration: float = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
			if scene.runtime.failed or not scene.runtime.active():
				push_error("PLAY_ASYNC_BASELINE: failed during %s: %s" %
					[id, scene.runtime.last_error])
				quit(1)
				return
			if tick_index >= WARM_FRAMES:
				main_ms.append(duration)
				native_ms.append(float(scene.runtime._arena._world.get_simulation_time_ms()))
				rapier_ms.append(scene.runtime._arena.session.bridge.last_step_time_ms())
		var world: Object = scene.runtime._arena._world
		var row: Dictionary = {
			"preset": str(id),
			"scope": "existing synchronous player arena; paced Godot physics frames; headless raster NOT measured",
			"native_workers": int(world.get_worker_threads()),
			"physics_frames": WARM_FRAMES + SAMPLE_FRAMES,
			"native_completed_ticks": int(world.get_tick_index()),
			"physical_completed_ticks": scene.runtime.tick,
			"main_advance_frame_ms": _stats(main_ms),
			"native_simulation_tick_ms": _stats(native_ms),
			"rapier_step_ms": _stats(rapier_ms),
			"headless_physics_frame_interval_ms": _stats(frame_ms),
		}
		if int(row.native_completed_ticks) != WARM_FRAMES + SAMPLE_FRAMES 				or int(row.physical_completed_ticks) != WARM_FRAMES + SAMPLE_FRAMES 				or int(row.native_workers) != 1:
			push_error("PLAY_ASYNC_BASELINE: unexpected synchronous owner identity " +
				JSON.stringify(row))
			quit(1)
			return
		rows.append(row)
		print("PLAY_ASYNC_BASELINE_CASE ", JSON.stringify(row))
	var result: Dictionary = {
		"schema": "play-async-001-current-sync-headless-v1",
		"platform": OS.get_name(),
		"engine": Engine.get_version_info(),
		"logical_processors": OS.get_processor_count(),
		"project_requested_native_workers": int(
			ProjectSettings.get_setting("cybersand/native_worker_threads", 0)
		),
		"warm_frames_per_preset": WARM_FRAMES,
		"sample_frames_per_preset": SAMPLE_FRAMES,
		"presets": rows,
		"limitations": "Headless physics callback timing is not rendered FPS; this is current one-worker sync baseline only.",
	}
	print("PLAY_ASYNC_BASELINE ", JSON.stringify(result))
	scene.queue_free()
	await process_frame
	quit(0)
