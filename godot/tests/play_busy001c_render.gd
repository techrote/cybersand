extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-BUSY-001C / #270: actual submitted gameplay pixels while >=2 jobs in
# one real World::tick_phased() dispatch remain deliberately held. This reuses
# the source-matched 001B native test hook; no second World or render mock.
const RIG: StringName = &"jetbarrel"
const HOLD_TIMEOUT_MS: int = 12000
const PHYSICS_FRAMES_UNDER_HOLD: int = 30
const SETUP_WAIT_TIMEOUT_MS: int = 30000
const FRAME_DRAW_TIMEOUT_MS: int = 2500

var desktop: Control
var frame_post_draw_seen: bool = false
var progress_serial: int = 0


class RenderHarness:
	extends DesktopHarness
	var completed_main_callbacks: int = 0
	var completed_physics_callbacks: int = 0
	var completed_input_callbacks: int = 0

	func _process(delta: float) -> void:
		super._process(delta)
		completed_main_callbacks += 1

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		completed_physics_callbacks += 1

	func _unhandled_key_input(event: InputEvent) -> void:
		super._unhandled_key_input(event)
		if event is InputEventKey and not event.echo:
			completed_input_callbacks += 1


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_BUSY001C_RENDER: " + message)


func render_host_ready() -> bool:
	return (actor_ready(desktop, RIG) and not desktop.paused
		and not desktop._actor_input_rearm
		and desktop.latest_snapshot != null
		and int(desktop.latest_snapshot.scheduler_thread_capacity_hint) >= 2
		and int(desktop.latest_snapshot.scheduler_parallel_phases_last_tick) > 0
		and desktop.physical_actor_session.tick >= 3
		and desktop.physical_actor_overlay.visible)


func gate_held(gate: Variant, generation: int) -> bool:
	var status: Dictionary = gate.status()
	return (int(status.get("generation", 0)) == generation
		and bool(status.get("selected", false))
		and not bool(status.get("released", true))
		and not bool(status.get("timed_out", true))
		and int(status.get("waiting", 0)) >= 2
		and int(status.get("active", 0)) >= 2
		and int(status.get("distinct_threads", 0)) >= 2
		and int(status.get("completed", 0)) == 0
		and int(status.get("dispatch_return_sequence", 0)) == 0)


func gate_returned(gate: Variant, generation: int) -> bool:
	var status: Dictionary = gate.status()
	return (int(status.get("generation", 0)) == generation
		and int(status.get("dispatch_return_sequence", 0)) > 0
		and int(status.get("completed", -1)) == int(status.get("expected_tasks", -2))
		and int(status.get("active", -1)) == 0
		and int(status.get("waiting", -1)) == 0)


func progress(stage: String, extra: Dictionary = {}) -> void:
	progress_serial += 1
	var row: Dictionary = {"stage":stage, "elapsed_ms":Time.get_ticks_msec()}
	for key: Variant in extra:
		row[key] = extra[key]
	print("PLAY_BUSY001C_PROGRESS ", JSON.stringify(row))
	var marker: Dictionary = {"case":"play_busy001c_render", "phase":stage,
		"sequence":progress_serial, "elapsed_ms":Time.get_ticks_msec()}
	print("CYBERSAND_PROGRESS ", JSON.stringify(marker))


func _frame_post_draw_seen() -> void:
	frame_post_draw_seen = true


func captured() -> Image:
	frame_post_draw_seen = false
	var callback := Callable(self, "_frame_post_draw_seen")
	if RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.disconnect(callback)
	RenderingServer.frame_post_draw.connect(callback)
	# force_draw is main-thread only and still produces the ordinary
	# RenderingServer frame_post_draw signal. The bounded loop prevents a
	# graphical-driver stall from consuming the 120 s outer process deadline.
	RenderingServer.force_draw()
	var deadline: int = Time.get_ticks_msec() + FRAME_DRAW_TIMEOUT_MS
	while not frame_post_draw_seen and Time.get_ticks_msec() < deadline:
		await process_frame
	if RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.disconnect(callback)
	if not frame_post_draw_seen:
		progress("frame_post_draw_timeout", {"timeout_ms":FRAME_DRAW_TIMEOUT_MS})
		return null
	var image: Image = desktop.get_viewport().get_texture().get_image()
	if image != null:
		image.convert(Image.FORMAT_RGBA8)
	return image


func sampled_colour_buckets(image: Image) -> int:
	if image == null or image.is_empty():
		return 0
	var unique: Dictionary = {}
	var width: int = image.get_width()
	var height: int = image.get_height()
	for iy: int in range(18):
		for ix: int in range(32):
			var x: int = clampi((ix * 2 + 1) * width / 64, 0, width - 1)
			var y: int = clampi((iy * 2 + 1) * height / 36, 0, height - 1)
			var colour: Color = image.get_pixel(x, y)
			var bucket := Vector3i(
				roundi(colour.r * 31.0),
				roundi(colour.g * 31.0),
				roundi(colour.b * 31.0))
			unique[bucket] = true
	return unique.size()


func changed_samples(first: Image, second: Image) -> int:
	if first == null or second == null or first.is_empty() or second.is_empty():
		return 0
	if first.get_size() != second.get_size():
		return -1
	var width: int = first.get_width()
	var height: int = first.get_height()
	var changed: int = 0
	# Dense enough to see a moving SetP rig/HUD without turning this into a
	# screenshot benchmark. The raw PNGs remain the authoritative pixels.
	for y: int in range(0, height, 4):
		for x: int in range(0, width, 4):
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.04:
				changed += 1
	return changed


func save_capture(image: Image, path: String) -> bool:
	return image != null and not image.is_empty() and image.save_png(path) == OK


func finish(worker: CyberSimulationWorker, session: Variant) -> void:
	release_controls()
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	await process_frame
	expect(worker != null and not worker._thread.is_started(),
		"scene exit joins the exclusive simulation worker")
	expect(session == null or not is_instance_valid(session),
		"scene exit retires the accepted SetP/Rapier session")
	expect(not is_instance_valid(desktop), "actual Main scene owner is freed")


func run() -> void:
	var started_ms: int = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		expect(false, "actual rendering display required; headless output is not qualification")
		print("PLAY_BUSY001C_RENDER_RESULT ", JSON.stringify({
			"assertions": assertions, "failures": failures,
			"display_server": DisplayServer.get_name(),
			"rendered_frame_during_real_native_hold": false,
		}))
		quit(1)
		return
	expect(ClassDB.class_exists(&"CyberPlayBusyTestGate"),
		"source-matched special runtime exposes the copied-value phase gate")
	if not ClassDB.class_exists(&"CyberPlayBusyTestGate"):
		quit(1)
		return

	progress("display_ready", {"display_server":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name()})
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(RenderHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(),
		"existing asynchronous native owner starts")
	if desktop.worker_start_error != OK or not worker._thread.is_started():
		await finish(worker, null)
		quit(1)
		return

	progress("worker_started")
	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"authored Player Playground admits through normal Main route")
	progress("course_queued")
	var ready: bool = await wait_for(
		Callable(self, "course_installed").bind(desktop), SETUP_WAIT_TIMEOUT_MS)
	expect(ready, "native worker acknowledges authored course within graphical setup budget")
	if ready:
		progress("course_installed", {"native_tick":int(desktop.latest_snapshot.tick_index)})
		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(RIG)), &"human", false),
			"ordinary SetP route constructs the real Jet Barrel")
		ready = await wait_for(
			Callable(self, "actor_ready").bind(desktop, RIG), SETUP_WAIT_TIMEOUT_MS)
		expect(ready, "actual actor, native epoch and hard terrain are ready within graphical setup budget")
	if ready:
		progress("actor_ready", {"actor_epoch":desktop._physical_epoch})
	if not ready:
		await finish(worker, desktop.physical_actor_session)
		quit(1)
		return

	desktop.paused = false
	ready = await wait_for(Callable(self, "render_host_ready"), 30000)
	expect(ready, "real native/Rapier host reaches parallel rendered gameplay")
	if ready:
		progress("parallel_render_host_ready", {
			"native_tick":int(desktop.latest_snapshot.tick_index),
			"rapier_tick":desktop.physical_actor_session.tick})
	if not ready:
		await finish(worker, desktop.physical_actor_session)
		quit(1)
		return

	var evidence_dir: String = OS.get_environment("CYBERSAND_PLAY_BUSY_RENDER_EVIDENCE")
	expect(not evidence_dir.is_empty(), "retained raw-pixel evidence directory is configured")
	if not evidence_dir.is_empty():
		expect(DirAccess.make_dir_recursive_absolute(evidence_dir) == OK,
			"retained raw-pixel evidence directory exists")

	var gate: Variant = ClassDB.instantiate(&"CyberPlayBusyTestGate")
	var generation: int = int(gate.arm(2, HOLD_TIMEOUT_MS))
	expect(generation > 0, "bounded gate arms for the next complete real pool dispatch")
	if generation <= 0:
		await finish(worker, desktop.physical_actor_session)
		quit(1)
		return

	var held: bool = await wait_for(Callable(self, "gate_held").bind(gate, generation), 5000)
	expect(held, "at least two distinct real World phase jobs are held before rendering")
	if held:
		progress("native_phase_held", gate.status())
	if not held:
		gate.release(generation)
		await finish(worker, desktop.physical_actor_session)
		quit(1)
		return

	var held_start: Dictionary = gate.status()
	var retained_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var retained_serial: int = retained_snapshot.serial
	var retained_tick: int = retained_snapshot.tick_index
	var retained_world_generation: int = retained_snapshot.render_world_generation
	var session: CyberPhysicalActorSession = desktop.physical_actor_session
	var actor_before: Vector2 = Vector2(session.observation(0).get("position", Vector2.ZERO))
	var main_before: int = desktop.completed_main_callbacks
	var physics_before: int = desktop.completed_physics_callbacks
	var input_before: int = desktop.completed_input_callbacks
	var rapier_before: int = desktop.rapier_bridge.manual_step_count()
	var command_before: int = session.accepted_commands

	progress("first_capture_begin")
	var first: Image = await captured()
	var first_gate: Dictionary = gate.status()
	progress("first_capture_end", {"ok":first != null and not first.is_empty()})
	expect(first != null and first.get_width() >= 640 and first.get_height() >= 360,
		"frame_post_draw yields a sizable actual gameplay framebuffer while native jobs are held")
	expect(sampled_colour_buckets(first) >= 6,
		"first held framebuffer contains nonblank gameplay pixels")
	expect(int(first_gate.waiting) >= 2 and not bool(first_gate.released)
		and int(first_gate.dispatch_return_sequence) == 0,
		"first submitted framebuffer occurs before native gate release")

	parse_key(KEY_D, true)
	for _step: int in range(PHYSICS_FRAMES_UNDER_HOLD):
		await physics_frame
	parse_key(KEY_D, false)
	for _step: int in range(3):
		await physics_frame

	progress("second_capture_begin")
	var second: Image = await captured()
	var second_gate: Dictionary = gate.status()
	progress("second_capture_end", {"ok":second != null and not second.is_empty()})
	var actor_after: Vector2 = Vector2(session.observation(0).get("position", Vector2.ZERO))
	var changed: int = changed_samples(first, second)
	var main_delta: int = desktop.completed_main_callbacks - main_before
	var physics_delta: int = desktop.completed_physics_callbacks - physics_before
	var input_delta: int = desktop.completed_input_callbacks - input_before
	var rapier_delta: int = desktop.rapier_bridge.manual_step_count() - rapier_before
	var actor_delta: float = actor_after.distance_to(actor_before)

	expect(second != null and second.get_size() == first.get_size(),
		"second held frame uses the same real viewport")
	expect(sampled_colour_buckets(second) >= 6,
		"second held framebuffer contains nonblank gameplay pixels")
	expect(changed > 20,
		"submitted framebuffer visibly changes while the same native phase remains blocked")
	expect(main_delta >= 2 and physics_delta >= PHYSICS_FRAMES_UNDER_HOLD,
		"actual Main process and physics callbacks progress during the held native phase")
	expect(input_delta >= 2 and session.accepted_commands > command_before,
		"real Viewport key edges reach the existing gameplay command path during the hold")
	expect(rapier_delta >= PHYSICS_FRAMES_UNDER_HOLD and actor_delta > 0.25,
		"main-thread Rapier advances the actual SetP actor while native phase jobs remain held")
	expect(int(second_gate.waiting) >= 2 and int(second_gate.active) >= 2
		and int(second_gate.distinct_threads) >= 2
		and int(second_gate.completed) == 0
		and not bool(second_gate.released) and not bool(second_gate.timed_out)
		and int(second_gate.dispatch_return_sequence) == 0,
		"both rendered frames are bracketed by the same genuinely outstanding native dispatch")
	expect(desktop.latest_snapshot == retained_snapshot
		and desktop.latest_snapshot.serial == retained_serial
		and desktop.latest_snapshot.tick_index == retained_tick
		and desktop.latest_snapshot.render_world_generation == retained_world_generation,
		"rendered UI/Rapier progress consumes the exact last immutable native snapshot; no partial newer packet leaks")

	var first_path: String = evidence_dir.path_join("held-before.png")
	var second_path: String = evidence_dir.path_join("held-after.png")
	if not evidence_dir.is_empty():
		expect(save_capture(first, first_path), "first raw held-frame PNG persists")
		expect(save_capture(second, second_path), "second raw held-frame PNG persists")

	progress("manual_gate_release_begin")
	var released: bool = bool(gate.release(generation))
	expect(released, "manual render-test release succeeds before the safety deadline")
	var returned: bool = await wait_for(Callable(self, "gate_returned").bind(gate, generation), 5000)
	expect(returned, "all selected real phase jobs drain and production dispatch returns")
	progress("native_dispatch_returned", gate.status())
	var final_gate: Dictionary = gate.status()
	expect(not bool(final_gate.timed_out)
		and int(final_gate.completed) == int(final_gate.expected_tasks)
		and int(final_gate.dispatch_return_sequence) > int(final_gate.drained_sequence),
		"positive rendered hold is manual and fully drained, not watchdog substitution")

	var snapshot_unchanged: bool = (
		desktop.latest_snapshot == retained_snapshot
		and desktop.latest_snapshot.serial == retained_serial
		and desktop.latest_snapshot.tick_index == retained_tick
		and desktop.latest_snapshot.render_world_generation == retained_world_generation)
	var framebuffer: Array[int] = [second.get_width(), second.get_height()] if second != null else [0, 0]
	var first_buckets: int = sampled_colour_buckets(first)
	var second_buckets: int = sampled_colour_buckets(second)
	await finish(worker, session)
	var result: Dictionary = {
		"assertions": assertions,
		"failures": failures,
		"elapsed_ms": Time.get_ticks_msec() - started_ms,
		"display_server": DisplayServer.get_name(),
		"rig": str(RIG),
		"native_phase_tick": int(held_start.tick),
		"native_phase": int(held_start.phase),
		"native_phase_jobs_held": int(held_start.waiting),
		"native_phase_tasks": int(final_gate.expected_tasks),
		"main_callbacks_during_hold": main_delta,
		"physics_callbacks_during_hold": physics_delta,
		"input_callbacks_during_hold": input_delta,
		"rapier_steps_during_hold": rapier_delta,
		"actor_motion_pixels": actor_delta,
		"framebuffer": framebuffer,
		"first_colour_buckets": first_buckets,
		"second_colour_buckets": second_buckets,
		"changed_samples_4px_grid": changed,
		"source_snapshot_unchanged_during_hold": snapshot_unchanged,
		"rendered_frame_during_real_native_hold": true,
		"actual_frame_post_draw": true,
		"gate_receipt": final_gate,
		"retries": 0,
		"physical_gamepad_qualified": false,
		"human_feel_qualified": false,
	}
	print("PLAY_BUSY001C_RENDER_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
