extends "res://oil_impinge_replay_base.gd"

# Drive the normal Play button. Collect frame timestamps in memory and write the
# raw series only after playback pauses so file I/O stays outside measurements.
func time_play(label: String, seconds: int) -> void:
	var times := PackedInt64Array()
	var ticks := PackedInt64Array()
	var focus_frames := 0
	var start_tick := tick()
	if not host.paused or not bench.toggle_pause():
		report.failures.append("Play refused for " + label)
		return
	var start_us := Time.get_ticks_usec()
	var prev_us := start_us
	while prev_us - start_us < 1000000 * seconds:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(now - prev_us)
		ticks.append(tick())
		if root.has_focus():
			focus_frames += 1
		prev_us = now
	if not bench.toggle_pause() or tick() <= start_tick:
		report.failures.append("Playback did not advance and pause: " + label)
		return
	report.playback[label] = {"frame_us": times, "published_ticks": ticks, "start_tick": start_tick,
		"end_tick": tick(), "elapsed_us": prev_us - start_us, "focused_frames": focus_frames}
	print("PLAYBACK ", label, " ticks ", start_tick, "..", tick(), " frames ", times.size())

func replay() -> void:
	root.size = Vector2i(1920, 1080)
	root.position = Vector2i(0, 32)
	bench._set_view(Vector2(15, 0), Vector2i(245, 172))
	for i in 30:
		await process_frame
	report.playback = {}
	report.window = [root.size.x, root.size.y]
	report.refresh_hz = DisplayServer.screen_get_refresh_rate()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.gpu = RenderingServer.get_video_adapter_name()
	report.vsync_mode = DisplayServer.window_get_vsync_mode()
	report.engine_max_fps = Engine.max_fps
	await time_play("initial_impact", 12)
	if not await advance(900):
		return
	await time_play("settled", 6)
	if not await advance(1500):
		return
	bench._brush.value = 9
	if not await paint(75, 68, 3):
		return
	await time_play("fresh_wave", 9)
