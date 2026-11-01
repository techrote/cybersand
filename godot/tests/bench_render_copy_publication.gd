extends SceneTree

# Fresh-process rendered campaign. Uses real Main scene, ordinary _process,
# production validator/ImageTexture submission/ACK and ordinary worker pacing.
const Worker = preload("res://tests/support/render_copy_worker.gd")
const Policy = preload("res://tests/support/ci_execution_policy.gd")
const Consumer = preload("res://tests/support/render_copy_consumer.gd")
var failures: int = 0
var frame_usec: Array[int] = []

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := ""
	var arm := "N"
	var candidate := "control"
	var expected_runtime := ""
	var runtime_path := ""
	for arg: String in args:
		if arg.begins_with("--receipt="): output = arg.trim_prefix("--receipt=")
		if arg.begins_with("--arm="): arm = arg.trim_prefix("--arm=")
		if arg.begins_with("--candidate="): candidate = arg.trim_prefix("--candidate=")
		if arg.begins_with("--runtime-sha256="): expected_runtime = arg.trim_prefix("--runtime-sha256=")
		if arg.begins_with("--runtime-path="): runtime_path = arg.trim_prefix("--runtime-path=")
	_expect(DisplayServer.get_name() != "headless", "rendered evidence requires a graphical DisplayServer")
	_expect(not output.is_empty(), "explicit fresh receipt path required")
	_expect(arm in ["N", "W"], "unknown arm")
	_expect(candidate in ["control", "R"], "unknown candidate")
	_expect(not runtime_path.is_empty() and expected_runtime.length() == 64, "explicit runtime identity required")
	var actual_runtime: String = FileAccess.get_sha256(runtime_path)
	_expect(actual_runtime == expected_runtime, "installed runtime does not match selected candidate")
	if failures > 0:
		quit(failures)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	set_meta("cybersand_feature", "render_copy_publication_benchmark")
	var worker = Worker.new()
	worker.withhold_ack = arm == "W"
	var host: Control = load("res://main.tscn").instantiate()
	host.set_script(Consumer)
	host.trace = worker.trace
	host.simulation_worker = worker
	host.paused = true
	root.add_child(host)
	_expect(host.worker_start_error == OK, "worker failed to start")
	_expect(host.latest_snapshot != null and host.latest_snapshot.render_channels == 2, "native RG8 owner required")
	# A fixed small emission stream while paused avoids simulation/physical-policy
	# confounds. Queue acceptance is recorded; pre-reset backlog may be discarded
	# by the ordinary reset. All 60 post-reset cells are checked after joining.
	var accepted_pulses: int = 0
	var previous := Time.get_ticks_usec()
	for frame: int in range(240):
		if frame == 120:
			worker.queue_reset(Vector2(150, 145))
			worker.trace.record("reset_request", {"frame": frame})
		if frame % 2 == 0:
			var material_id: int = CyberCellWorld.WATER if frame % 4 == 0 else CyberCellWorld.SAND
			var x: int = 400 + (frame / 2) % 120
			var accepted: bool = worker.queue_emit_disc(x, 250, 0, material_id)
			_expect(accepted, "workload emission was refused")
			accepted_pulses += 1 if accepted else 0
			worker.trace.record("emission_queued", {"frame": frame, "x": x, "y": 250,
				"material": material_id, "accepted": accepted})
		worker.trace.record("frame_begin", {"frame": frame, "start_usec": previous})
		await process_frame
		var now := Time.get_ticks_usec()
		frame_usec.append(now - previous)
		worker.trace.record("frame_end", {"frame": frame, "start_usec": previous, "end_usec": now, "duration_usec": now - previous})
		previous = now
	# A join is not a render flush. Drain through normal cadence with no new
	# emissions; two completions cover an iteration already in flight at entry.
	var tail_start: int = Time.get_ticks_usec()
	var owner_start: int = worker.trace.total("owner_end")
	worker.trace.record("tail_begin", {"owner_count": owner_start})
	var tail_drained: bool = false
	var tail_deadline: int = Time.get_ticks_msec() + Policy.milliseconds("main_ack_seconds")
	while Time.get_ticks_msec() < tail_deadline:
		await process_frame
		var completed: int = worker.trace.total("owner_end")
		var candidate_snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		if (completed >= owner_start + 2 and candidate_snapshot != null
			and candidate_snapshot.render_world_generation == 2
			and candidate_snapshot.world_revision == candidate_snapshot.simulation_world_revision):
			tail_drained = true
			worker.trace.record("tail_caught_up", {"owner_count": completed,
				"generation": candidate_snapshot.render_world_generation,
				"revision": candidate_snapshot.world_revision, "simulation_revision": candidate_snapshot.simulation_world_revision})
			break
	_expect(tail_drained, "ordinary publication did not drain before final comparison")
	var tail_elapsed: int = Time.get_ticks_usec() - tail_start
	# Join the owner before the final independent native oracle. No mutable
	# native access crosses the live ownership boundary. Consume its final
	# immutable publication through the same production upload/ACK function.
	host.set_process(false)
	host.set_physics_process(false)
	worker.stop_worker()
	var final_snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	_expect(final_snapshot != null and not final_snapshot.simulation_failed, "final publication missing or failed")
	if final_snapshot != null:
		host.consume_render_snapshot(final_snapshot)
	var fresh: Dictionary = worker._world.take_render_snapshot(true)
	var fresh_cells: PackedByteArray = fresh.get("cells", PackedByteArray())
	var post_reset_cells_correct: int = 0
	if fresh_cells.size() == CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2:
		for pulse: int in range(60, 120):
			var expected_material: int = CyberCellWorld.WATER if pulse % 2 == 0 else CyberCellWorld.SAND
			if fresh_cells[(250 * CyberCellWorld.WORLD_WIDTH + 400 + pulse) * 2] == expected_material:
				post_reset_cells_correct += 1
	_expect(accepted_pulses == 120 and post_reset_cells_correct == 60,
		"post-reset workload was not fully applied")
	var cpu_equal: bool = host.image.get_data() == fresh_cells
	_expect(cpu_equal, "final CPU image differs from fresh native full snapshot")
	await RenderingServer.frame_post_draw
	worker.trace.record("frame_post_draw")
	var uploaded: Image = host.texture.get_image()
	uploaded.convert(Image.FORMAT_RG8)
	var texture_equal: bool = uploaded.get_data() == host.image.get_data()
	_expect(texture_equal, "final texture readback differs from CPU image")
	var witness := root.get_texture().get_image()
	var png_error := witness.save_png(output + ".png")
	var result: Dictionary = worker.trace.result()
	_expect(not worker._world.has_failed(), "final native owner failed")
	_expect(result.dropped == 0, "trace capacity exceeded")
	_expect(int(result.counts.get("texture_success", 0)) > 20, "too few real uploads")
	_expect(int(result.counts.get("reject", 0)) == 0, "render upload rejected")
	_expect(png_error == OK and not witness.is_empty(), "framebuffer witness unavailable")
	result.merge({"schema_version": 1, "arm": arm, "candidate": candidate, "owner_script": worker.get_script().resource_path,
		"runtime_sha256": actual_runtime, "runtime_path": runtime_path, "process_id": OS.get_process_id(),
		"watchdog_policy": Policy.identity(),
		"tail_drained": tail_drained, "tail_elapsed_usec": tail_elapsed,
		"frame_usec": frame_usec, "pending_high_water": worker.pending_high_water,
		"accepted_pulses": accepted_pulses, "post_reset_cells_correct": post_reset_cells_correct,
		"final_cpu_native_equal": cpu_equal, "final_texture_image_equal": texture_equal,
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"os": OS.get_name(), "failures": failures, "png_error": png_error,
		"workload": "paused real Main; 120 accepted radius-zero Sand/Water commands; ordinary reset before frame120 emission may discard older backlog; all 60 post-reset cells verified; 240 process frames"})
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	host.queue_free()
	await process_frame
	print("RENDER_COPY_PUBLICATION: arm=%s failures=%d counts=%s" % [arm, failures, result.counts])
	quit(failures)
