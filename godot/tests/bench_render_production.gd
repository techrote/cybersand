extends SceneTree

# Explicit graphical qualification, never an ordinary application entry point.
# Variant labels describe the authenticated checkout; they do not select policy.
const Worker = preload("res://tests/support/render_production_worker.gd")
const Consumer = preload("res://tests/support/render_production_consumer.gd")
const Policy = preload("res://tests/support/ci_execution_policy.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const MARKER_X: int = 900
const MARKER_Y: int = 32

var failures: int = 0
var assertions: int = 0
var receipt_path: String = ""
var variant: String = ""
var workload: String = ""
var arm: String = ""
var frame_count: int = 240
var consumer_usec: int = 0
var runtime_path: String = ""
var runtime_sha256: String = ""
var frame_usec: Array[int] = []
var host: Control
var worker: RefCounted
var lifecycle: Array[Dictionary] = []
var accepted_pulses: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("RENDER_PRODUCTION: " + message)

func play_ready() -> bool:
	return (host.pending_microscenario_apply.is_empty()
		and host.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID
		and host.physical_rig_id == &"jetbarrel" and host.physical_actor_session != null
		and host._physical_terrain_ready and host._actor_reset_receipt == 0
		and host.latest_snapshot != null
		and int(host.latest_snapshot.rigid_body_epoch) == int(host._physical_epoch))

func wait_play_ready(previous_generation: int = -1) -> bool:
	var deadline: int = Time.get_ticks_msec() + Policy.milliseconds("main_ack_seconds")
	while Time.get_ticks_msec() < deadline:
		if play_ready() and int(host.latest_snapshot.render_world_generation) > previous_generation:
			return true
		await process_frame
	return false

func record_play(kind: String) -> Dictionary:
	var row: Dictionary = {"kind": kind,
		"generation": int(host.latest_snapshot.render_world_generation),
		"native_tick": int(host.latest_snapshot.tick_index),
		"physics_tick": int(host.physical_actor_session.tick), "epoch": int(host._physical_epoch),
		"recipe_hash": str(host.microscenario_definition.get("source_recipe_hash", "")),
		"rig": str(host.physical_rig_id)}
	lifecycle.append(row)
	worker.trace.record("play_lifecycle", row)
	return row

func finish(result: Dictionary) -> void:
	result.merge({"schema_version": 1, "schema": "render-production-graphical-v1",
		"variant": variant, "workload": workload, "arm": arm,
		"consumer_interval_usec": consumer_usec, "frame_count": frame_count,
		"frame_usec": frame_usec, "assertions": assertions, "failures": failures,
		"runtime_path": runtime_path, "runtime_sha256": runtime_sha256,
		"process_id": OS.get_process_id(), "engine": Engine.get_version_info(),
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "os": OS.get_name(),
		"watchdog_policy": Policy.identity(), "lifecycle": lifecycle,
		"accepted_pulses": accepted_pulses,
		"owner_script": "res://tests/support/render_production_worker.gd",
		"consumer_script": "res://tests/support/render_production_consumer.gd",
		"gpu_completion_latency_measured": false, "human_pacing_qualified": false}, true)
	if not receipt_path.is_empty():
		var file: FileAccess = FileAccess.open(receipt_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result))
			file.close()
		else:
			failures += 1
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
	print("RENDER_PRODUCTION: %d assertions, %d failures; variant=%s workload=%s arm=%s consumer_usec=%d" % [assertions, failures, variant, workload, arm, consumer_usec])
	quit(failures)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="): receipt_path = arg.trim_prefix("--receipt=")
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--workload="): workload = arg.trim_prefix("--workload=")
		if arg.begins_with("--arm="): arm = arg.trim_prefix("--arm=")
		if arg.begins_with("--frames="): frame_count = int(arg.trim_prefix("--frames="))
		if arg.begins_with("--consumer-usec="): consumer_usec = int(arg.trim_prefix("--consumer-usec="))
		if arg.begins_with("--runtime-path="): runtime_path = arg.trim_prefix("--runtime-path=")
		if arg.begins_with("--runtime-sha256="): runtime_sha256 = arg.trim_prefix("--runtime-sha256=")
	expect(DisplayServer.get_name() != "headless", "real graphical DisplayServer required")
	expect(not receipt_path.is_empty(), "fresh explicit receipt required")
	expect(variant in ["control", "E", "R", "ER"], "unknown source-identity label")
	expect(workload in ["paused", "play"] and arm in ["N", "W"], "unknown registered workload")
	expect(frame_count >= 120 and frame_count <= 600 and frame_count % 4 == 0, "frame window must be bounded and divisible by four")
	expect(consumer_usec in [0, 50000], "consumer cadence must be ordinary or explicitly 50ms")
	expect(not runtime_path.is_empty() and runtime_sha256.length() == 64
		and FileAccess.get_sha256(runtime_path) == runtime_sha256, "installed runtime identity mismatch")
	if failures > 0:
		await finish({})
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	set_meta("cybersand_feature", "render_production_qualification")
	worker = Worker.new()
	worker.withhold_ack = arm == "W"
	host = load("res://main.tscn").instantiate()
	host.set_script(Consumer)
	host.trace = worker.trace
	host.consumer_interval_usec = consumer_usec
	host.simulation_worker = worker
	host.paused = true
	root.add_child(host)
	expect(host.worker_start_error == OK and host.latest_snapshot != null
		and int(host.latest_snapshot.render_channels) == 2, "ordinary native RG8 owner startup failed")
	if failures > 0:
		worker.stop_worker()
		await finish(worker.trace.result())
		return
	var segment_start: Dictionary = {}
	if workload == "play":
		var panel: PopupPanel = host.playable_session_panel
		panel.show_selection()
		panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(&"jetbarrel"))
		panel.control_choice.select(1)
		panel.rule_choice.select(1)
		panel.camera_choice.select(1)
		expect(panel.build_selected(), "ordinary composed PLAY selection refused")
		var ready: bool = await wait_play_ready()
		expect(ready, "composed PLAY native/Rapier installation did not finish")
		if not ready:
			worker.stop_worker()
			await finish(worker.trace.result())
			return
		panel.hide()
		segment_start = record_play("installed")
		expect(host.set_playable_course_paused(false), "ordinary PLAY resume refused")
	var previous: int = Time.get_ticks_usec()
	worker.trace.record("measurement_begin", {"frames": frame_count})
	for frame: int in range(frame_count):
		if frame == frame_count / 2:
			var old_generation: int = int(host.latest_snapshot.render_world_generation)
			worker.trace.record("reset_request", {"frame": frame, "generation": old_generation})
			if workload == "play":
				var advanced: Dictionary = record_play("before_reset")
				expect(int(advanced.native_tick) > int(segment_start.native_tick)
					and int(advanced.physics_tick) > int(segment_start.physics_tick), "active PLAY native and Rapier clocks did not both advance")
				host.microscenario_reset()
				var reset_ready: bool = await wait_play_ready(old_generation)
				expect(reset_ready, "ordinary PLAY reset did not replace both owners")
				if not reset_ready: break
				segment_start = record_play("reset_installed")
				expect(host.set_playable_course_paused(false), "ordinary post-reset resume refused")
			else:
				worker.queue_reset(Vector2(150, 145))
		if frame % 2 == 0:
			var material_id: int = CyberCellWorld.WATER if frame % 4 == 0 else CyberCellWorld.SAND
			var x: int = 400 + (frame / 2) % 120
			var accepted: bool = worker.queue_emit_disc(x, 250, 0, material_id)
			expect(accepted, "registered radius-zero emission refused")
			accepted_pulses += 1 if accepted else 0
			worker.trace.record("emission_queued", {"frame": frame, "x": x, "y": 250, "material": material_id, "accepted": accepted})
		worker.trace.record("frame_begin", {"frame": frame, "start_usec": previous})
		await process_frame
		var now: int = Time.get_ticks_usec()
		frame_usec.append(now - previous)
		worker.trace.record("frame_end", {"frame": frame, "start_usec": previous, "end_usec": now, "duration_usec": now - previous})
		previous = now
	worker.trace.record("measurement_end")
	if workload == "play" and play_ready():
		var final_play: Dictionary = record_play("active_end")
		expect(int(final_play.native_tick) > int(segment_start.native_tick)
			and int(final_play.physics_tick) > int(segment_start.physics_tick), "post-reset PLAY clocks did not both advance")
		expect(host.set_playable_course_paused(true), "ordinary tail pause refused")
	else:
		host.paused = true
	# A stable final marker proves a queued late mutation reached the consumer.
	# It is an ordinary edit; no resync or ACK is manufactured for the tail.
	var marker_accepted: bool = worker.queue_emit_disc(MARKER_X, MARKER_Y, 0, CyberCellWorld.CONCRETE)
	expect(marker_accepted, "tail marker edit refused")
	worker.trace.record("tail_marker_queued", {"x": MARKER_X, "y": MARKER_Y,
		"material": CyberCellWorld.CONCRETE, "accepted": marker_accepted})
	var tail_start: int = Time.get_ticks_usec()
	var owner_start: int = worker.trace.total("owner_end")
	worker.trace.record("tail_begin", {"owner_count": owner_start})
	var tail_drained: bool = false
	var deadline: int = Time.get_ticks_msec() + Policy.milliseconds("main_ack_seconds")
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var completed: int = worker.trace.total("owner_end")
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		if (completed >= owner_start + 2 and snapshot != null and not snapshot.simulation_failed
			and snapshot.world_revision == snapshot.simulation_world_revision
			and host.last_uploaded_world_generation == snapshot.render_world_generation
			and host.last_uploaded_revision == snapshot.simulation_world_revision
			and host.last_uploaded_render_snapshot_serial >= snapshot.render_snapshot_serial
			and host.image.get_pixel(MARKER_X, MARKER_Y).r8 == CyberCellWorld.CONCRETE):
			tail_drained = true
			worker.trace.record("tail_caught_up", {"owner_count": completed,
				"generation": snapshot.render_world_generation, "revision": snapshot.world_revision,
				"simulation_revision": snapshot.simulation_world_revision,
				"uploaded_generation": host.last_uploaded_world_generation,
				"uploaded_revision": host.last_uploaded_revision,
				"render_serial": snapshot.render_snapshot_serial,
				"uploaded_serial": host.last_uploaded_render_snapshot_serial})
			break
	expect(tail_drained, "ordinary worker and consumer cadence did not drain")
	var tail_elapsed: int = Time.get_ticks_usec() - tail_start
	host.set_process(false)
	host.set_physics_process(false)
	worker.stop_worker()
	worker.trace.record("owner_joined", {"thread_started": worker._thread.is_started()})
	# Independent full-native oracle after join. This packet is never uploaded,
	# acknowledged or used to repair the already-consumed CPU image.
	var fresh: Dictionary = worker._world.take_render_snapshot(true)
	var fresh_cells: PackedByteArray = fresh.get("cells", PackedByteArray())
	var cpu_equal: bool = host.image.get_data() == fresh_cells
	expect(cpu_equal, "already-consumed CPU image differs from final native bytes")
	await RenderingServer.frame_post_draw
	var uploaded: Image = host.texture.get_image()
	uploaded.convert(Image.FORMAT_RG8)
	var texture_equal: bool = uploaded.get_data() == host.image.get_data()
	expect(texture_equal, "texture readback differs from already-consumed CPU image")
	var witness: Image = root.get_texture().get_image()
	var png_error: int = witness.save_png(receipt_path + ".png")
	expect(png_error == OK and not witness.is_empty(), "framebuffer witness missing")
	var result: Dictionary = worker.trace.result()
	expect(int(result.dropped) == 0, "bounded trace capacity exceeded")
	expect(int(result.counts.get("texture_success", 0)) > 10, "insufficient real graphical uploads")
	expect(int(result.counts.get("reject", 0)) == 0, "unexpected ordinary upload rejection")
	expect(not worker._world.has_failed(), "native owner failed")
	result.merge({"tail_drained": tail_drained, "tail_elapsed_usec": tail_elapsed,
		"pending_high_water": worker.pending_high_water,
		"pending_rectangle_high_water": worker.pending_rectangle_high_water,
		"final_cpu_native_equal": cpu_equal, "final_texture_image_equal": texture_equal,
		"final_marker_equal": host.image.get_pixel(MARKER_X, MARKER_Y).r8 == CyberCellWorld.CONCRETE,
		"final_oracle_after_join": true, "post_join_consumer_calls": 0,
		"png_error": png_error, "scripted_input": "none; active Jet Barrel gravity and native material ticks",
		"rejected_upload_scope": "separate focused production consumer regression"}, true)
	await finish(result)
