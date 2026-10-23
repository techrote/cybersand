extends SceneTree

# 4LY-002 representative gameplay screenshots, never synthetic body locations:
# install each real drone through the ordinary main.tscn/F5 selection contract,
# run the real native worker + Rapier owner, and screenshot submitted GL frames.
# This _render fixture is intentionally Linux-display-only; Windows headless
# regression covers the same selection and physical state without GL claims.
const Session = preload("res://scripts/physical_actor_session.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
var desktop: Control
var checks: int = 0
var failures: int = 0
var records: Array = []


func _initialize() -> void:
	_run.call_deferred()


func expect(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("4LY_GAMEPLAY_RENDER: " + reason)


func wait_for(predicate: Callable, timeout_ms: int = 60000) -> bool:
	var until: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < until:
		await process_frame
		if predicate.call():
			return true
	return false


func captured() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = desktop.get_viewport().get_texture().get_image()
	if result != null:
		result.convert(Image.FORMAT_RGBA8)
	return result


func nonblank_samples(image: Image) -> int:
	var unique: Dictionary = {}
	var w: int = image.get_width()
	var h: int = image.get_height()
	for iy: int in range(12):
		for ix: int in range(16):
			var colour: Color = image.get_pixel(clampi((ix * 2 + 1) * w / 32, 0, w - 1),
				clampi((iy * 2 + 1) * h / 24, 0, h - 1))
			var rounded := Vector3i(roundi(colour.r * 31.0), roundi(colour.g * 31.0), roundi(colour.b * 31.0))
			unique[rounded] = true
	return unique.size()


func run_profile(id: StringName, evidence_dir: String) -> void:
	var selected: StringName = StringName("rapier/" + str(id))
	expect(desktop.apply_actor_prototype_configuration(selected, &"policy", false),
		str(id) + " installed via ordinary sandbox selector")
	if not await wait_for(func() -> bool:
		return desktop._actor_reset_receipt == 0 and desktop.pending_microscenario_apply.is_empty()):
		expect(false, str(id) + " timed out awaiting native reset")
		return
	desktop.paused = false
	if not await wait_for(func() -> bool: return desktop._physical_terrain_ready):
		expect(false, str(id) + " failed to publish admitted terrain")
		return
	var start: Dictionary = desktop.physical_actor_session.observation(0)
	var old_tick: int = int(start.tick)
	var admissions: int = 0
	for step_id: int in range(90):
		# This is the same v2 observation-issued, lease-fenced policy path that
		# receives real gameplay commands. No direct velocity/pose override.
		if step_id % 3 == 0:
			var view: Dictionary = desktop.physical_actor_session.observation(0)
			var packet: Dictionary = Session.make_command(view, int(view.last_sequence) + 1,
				{"move": [0.6, -0.8]}, 6)
			if desktop.submit_physical_actor_command(packet):
				admissions += 1
		await physics_frame
	var final: Dictionary = desktop.physical_actor_session.observation(0)
	var actual_parts: Array = desktop.physical_actor_session.render_parts()
	expect(int(final.tick) >= old_tick + 60, str(id) + " real Rapier host advances at least 60 physical steps")
	expect(admissions >= 15, str(id) + " follows ordinary policy wire admission")
	expect(str(final.fault).is_empty() and str(final.flight.step_fault).is_empty(),
		str(id) + " retains healthy 4LY owner/bridge state")
	expect(final.flight.capabilities.profile_hash == Profile.profile_hash(Profile.entry(id)),
		str(id) + " screenshots identify the measured physical plant")
	expect(actual_parts.size() == 1 and desktop.physical_actor_overlay.visible,
		str(id) + " has one visible actual collider")
	expect(Vector2(final.centre).distance_to(Vector2(start.centre)) > 4.0
		and Vector2(final.velocity).is_finite(),
		str(id) + " screenshot depicts physical motion, not static reference artwork")
	var screen: Image = await captured()
	expect(screen != null and screen.get_width() >= 640 and screen.get_height() >= 360,
		str(id) + " requires a live sizable GL framebuffer")
	if screen == null:
		return
	var colors: int = nonblank_samples(screen)
	expect(colors >= 6, str(id) + " must capture actual nonblank gameplay pixels")
	var record: Dictionary = {
		"id": str(id), "profile_hash": str(final.flight.capabilities.profile_hash),
		"controller_hash": str(final.flight.capabilities.controller_hash),
		"host_tick": int(final.tick), "admitted_packets": admissions,
		"centre": [float(final.centre.x), float(final.centre.y)],
		"velocity": [float(final.velocity.x), float(final.velocity.y)],
		"flight_mode": str(final.flight.mode), "observed_one_body": actual_parts.size() == 1,
		"framebuffer": [screen.get_width(), screen.get_height()],
		"sampled_colour_buckets": colors,
		"render_note": "Unaltered ordinary-game viewport with real physics/transform, HUD and cellular map; not human feel approval"}
	if not evidence_dir.is_empty():
		var location: String = evidence_dir.path_join(str(id) + "-gameplay.png")
		expect(screen.save_png(location) == OK, str(id) + " persisted raw rendered gameplay pixels")
		record["screenshot"] = location.get_file()
	records.append(record)
	desktop.paused = true


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("4LY_GAMEPLAY_RENDER requires a real rendering display; headless output is not qualification")
		quit(1)
		return
	desktop = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	expect(desktop.actor_prototypes_allowed(), "ordinary sandbox actor picker is available")
	var evidence_dir: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if not evidence_dir.is_empty():
		expect(DirAccess.make_dir_recursive_absolute(evidence_dir) == OK,
			"retained screenshot evidence directory exists")
	for id: StringName in Profile.IDS:
		await run_profile(id, evidence_dir)
	desktop.paused = true
	desktop.queue_free()
	await process_frame
	await process_frame
	if not evidence_dir.is_empty():
		var file: FileAccess = FileAccess.open(evidence_dir.path_join("4ly002-gameplay-render.json"), FileAccess.WRITE)
		expect(file != null, "capture ledger writable")
		if file != null:
			file.store_string(JSON.stringify({"source_commit": OS.get_environment("GITHUB_SHA"),
				"host":"actual Godot main sandbox + real native worker + Rapier, graphical GL framebuffer",
				"record_kind":"descriptive gameplay capture, not owner-feel approval",
				"profiles":records}, "\t", false) + "\n")
			file.close()
	print("4LY_GAMEPLAY_RENDER ", JSON.stringify({"assertions":checks,"failures":failures,"profiles":records}))
	quit(0 if failures == 0 and records.size() == Profile.IDS.size() else 1)
