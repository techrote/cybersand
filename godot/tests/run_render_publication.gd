extends SceneTree

# Fresh-process rendered campaign. Uses real Main scene, ordinary _process,
# production validator/ImageTexture submission/ACK and ordinary worker pacing.
const Worker = preload("res://tests/render_publication_worker.gd")
const EWorker = preload("res://tests/render_publication_e.gd")
const Consumer = preload("res://tests/render_publication_consumer.gd")
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
	for arg: String in args:
		if arg.begins_with("--receipt="): output = arg.trim_prefix("--receipt=")
		if arg.begins_with("--arm="): arm = arg.trim_prefix("--arm=")
		if arg.begins_with("--candidate="): candidate = arg.trim_prefix("--candidate=")
	_expect(DisplayServer.get_name() != "headless", "rendered evidence requires a graphical DisplayServer")
	_expect(not output.is_empty(), "explicit fresh receipt path required")
	_expect(arm in ["N", "W"], "unknown arm")
	_expect(candidate in ["control", "E"], "unknown candidate")
	if failures > 0:
		quit(failures)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	set_meta("cybersand_feature", "render_publication_diagnostic")
	var worker = EWorker.new() if candidate == "E" else Worker.new()
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
	# confounds. Every pulse is a different cell; frame schedule is identical N/W.
	var previous := Time.get_ticks_usec()
	for frame: int in range(240):
		if frame % 2 == 0:
			worker.queue_emit_disc(400 + (frame / 2) % 120, 250, 0, CyberCellWorld.WATER if frame % 4 == 0 else CyberCellWorld.SAND)
		if frame == 120:
			worker.queue_reset(Vector2(150, 145))
		worker.trace.record("frame", {"frame": frame})
		await process_frame
		var now := Time.get_ticks_usec()
		frame_usec.append(now - previous)
		previous = now
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
	var cpu_equal: bool = host.image.get_data() == fresh.get("cells", PackedByteArray())
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
	result.merge({"arm": arm, "candidate": candidate, "owner_script": worker.get_script().resource_path,
		"frame_usec": frame_usec, "pending_high_water": worker.pending_high_water,
		"final_cpu_native_equal": cpu_equal, "final_texture_image_equal": texture_equal,
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"os": OS.get_name(), "failures": failures, "png_error": png_error,
		"workload": "paused real Main; 120 radius-zero alternating Sand/Water pulses; reset at frame120; 240 process frames"})
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	host.queue_free()
	await process_frame
	print("RENDER_PUBLICATION: arm=%s failures=%d counts=%s" % [arm, failures, result.counts])
	quit(failures)
