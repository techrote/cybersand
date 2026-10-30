extends "res://tests/play_life001_shared_host_case.gd"

# A bounded measurement apparatus, deliberately not test_*.gd auto-discovery.
# The Python campaign runner supplies one fresh process for each worker request.
# Actual frame_post_draw submissions are separate from Main callbacks and from
# physical display scanout. OS focus is explicitly synthetic; controls are real
# InputEventKey events delivered through the integrated keyboard-only session.
const Probe = preload("res://tests/play_pace003_worker_probe.gd")
const SAMPLE_MIN_SECONDS: int = 15
const SAMPLE_MAX_SECONDS: int = 30
const SETUP_TIMEOUT_MS: int = 30000

var requested_workers: int = 0
var sample_seconds: int = 15
var requested_rig: StringName = &"jetbarrel"
var requested_policy: int = 0
var result: Dictionary = {}


class MeasurementHost:
	extends "res://scripts/main.gd"
	const WorkerProbe = preload("res://tests/play_pace003_worker_probe.gd")
	var sampling: bool = false
	var main_started_usec: Array[int] = []
	var main_callback_usec: Array[float] = []
	var physics_callback_usec: Array[float] = []
	var rendered_usec: Array[int] = []
	var snapshot_rows: Array[Dictionary] = []
	var input_tape: Array[Dictionary] = []
	var initial_physics_tick: int = 0
	var input_phase: int = -1
	var input_lift: bool = false
	var input_tap: int = -1

	func _ready() -> void:
		# Replace the default-created, UNSTARTED worker only. No second live owner.
		simulation_worker = WorkerProbe.new()
		super._ready()
		RenderingServer.frame_post_draw.connect(_record_render)

	func _exit_tree() -> void:
		if RenderingServer.frame_post_draw.is_connected(_record_render):
			RenderingServer.frame_post_draw.disconnect(_record_render)
		super._exit_tree()

	func _actor_window_has_focus() -> bool:
		return true # Synthetic focus predicate, never physical-focus qualification.

	func _key(code: Key, pressed: bool) -> void:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

	func begin_measurement() -> void:
		main_started_usec.clear()
		main_callback_usec.clear()
		physics_callback_usec.clear()
		rendered_usec.clear()
		snapshot_rows.clear()
		input_tape.clear()
		initial_physics_tick = physical_actor_session.tick
		input_phase = -1
		input_lift = false
		input_tap = -1
		simulation_worker.begin_sample()
		sampling = true

	func end_measurement() -> void:
		sampling = false
		simulation_worker.end_sample()

	func _record_render() -> void:
		if sampling and DisplayServer.get_name() != "headless":
			rendered_usec.append(Time.get_ticks_usec())

	func _process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super._process(delta)
		if not sampling:
			return
		var ended: int = Time.get_ticks_usec()
		main_started_usec.append(started)
		main_callback_usec.append(float(ended - started))
		if latest_snapshot != null:
			snapshot_rows.append({"observed_usec":ended, "serial":latest_snapshot.serial,
				"tick":latest_snapshot.tick_index, "epoch":latest_snapshot.rigid_body_epoch,
				"generation":latest_snapshot.render_world_generation,
				"published_usec":latest_snapshot.published_usec,
				"render_generated_usec":latest_snapshot.render_generated_usec,
				"render_serial":latest_snapshot.render_snapshot_serial,
				"render_tick":latest_snapshot.render_tick_index,
				"overruns":latest_snapshot.worker_overruns,
				"failed":latest_snapshot.simulation_failed})

	func _physics_process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		if sampling and physical_actor_session != null:
			# The same intended tape is indexed by completed Rapier ticks, not
			# rendering speed. Native/Rapier admission skew remains real and recorded.
			var tick: int = physical_actor_session.tick - initial_physics_tick
			var phase: int = floori(float(tick) / 120.0)
			var lift: bool = tick % 120 < 30
			var tap: int = floori(float(tick) / 60.0)
			if phase != input_phase:
				_key(KEY_D, phase % 2 == 0)
				_key(KEY_A, phase % 2 != 0)
				input_tape.append({"kind":"direction", "tick":tick, "phase":phase})
				input_phase = phase
			if lift != input_lift:
				_key(KEY_W, lift)
				input_tape.append({"kind":"lift", "tick":tick, "pressed":lift})
				input_lift = lift
			if tap != input_tap:
				_key(KEY_SPACE, true)
				_key(KEY_SPACE, false)
				input_tape.append({"kind":"primary_tap", "tick":tick})
				input_tap = tap
		super._physics_process(delta)
		if sampling:
			physics_callback_usec.append(float(Time.get_ticks_usec() - started))


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_PACE003: " + message)


func emit_stage(stage: String) -> void:
	print("CYBERSAND_PROGRESS ", JSON.stringify({"case":"play_pace003", "stage":stage,
		"monotonic_usec":Time.get_ticks_usec()}))


func new_actor(desktop: Control, rig: StringName, epoch: int) -> bool:
	return actor_ready(desktop, rig) and desktop._physical_epoch > epoch


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="): requested_workers = argument.trim_prefix("--workers=").to_int()
		elif argument.begins_with("--seconds="): sample_seconds = argument.trim_prefix("--seconds=").to_int()
		elif argument.begins_with("--rig="): requested_rig = StringName(argument.trim_prefix("--rig="))
		elif argument.begins_with("--policy="): requested_policy = argument.trim_prefix("--policy=").to_int()
		else: expect(false, "unsupported apparatus argument: " + argument)
	expect(requested_workers in [0,1] and sample_seconds >= SAMPLE_MIN_SECONDS
		and sample_seconds <= SAMPLE_MAX_SECONDS and requested_rig in Course.MECHANICAL_PRESETS
		and requested_policy in [0,2], "bounded requested worker/sample/rig/policy configuration")
	if failures > 0:
		quit(1)
		return
	# One isolated fresh process contains no live World when this launch setting
	# is selected. Never mutate the worker policy of an already-running owner.
	ProjectSettings.set_setting("cybersand/native_worker_threads", requested_workers)
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	release_controls()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(MeasurementHost)
	root.add_child(desktop)
	await process_frame
	var worker: Probe = desktop.simulation_worker as Probe
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "actual shared desktop owner starts")
	emit_stage("worker_started")
	var construction_started: int = Time.get_ticks_usec()
	if ready:
		var panel = desktop.playable_session_panel
		panel.show_selection()
		panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(requested_rig))
		panel.control_choice.select(1)
		panel.rule_choice.select(1)
		panel.camera_choice.select(1)
		panel.policy_editor.select_preset(requested_policy)
		ready = panel.build_selected()
		expect(ready, "integrated selector admits actual native-backed composed session")
		if ready:
			ready = await wait_for(Callable(self, "actor_ready").bind(desktop, requested_rig), SETUP_TIMEOUT_MS)
		expect(ready, "actual authored course/SetP actor/terrain acknowledged within 30 seconds")
	var construction_usec: int = Time.get_ticks_usec() - construction_started
	if ready:
		emit_stage("session_installed")
		var before_native: int = desktop.latest_snapshot.tick_index
		var before_physics: int = desktop.physical_actor_session.tick
		desktop.playable_session_panel.resume_play()
		ready = await wait_for(Callable(self, "clocks_advanced").bind(desktop, requested_rig,
			before_physics, before_native))
		expect(ready, "neutral rearm followed by both completed native/Rapier clocks")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, "PACE003 setup: ")
		quit(1)
		return
	# Fixed, bounded warm-up; no rendering call is forced and no frame is invented.
	var warmup_started: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - warmup_started < 2000000:
		await process_frame
	var generation: int = desktop.latest_snapshot.render_world_generation
	var epoch: int = desktop._physical_epoch
	var initial_native: int = desktop.latest_snapshot.tick_index
	var initial_physics: int = desktop.physical_actor_session.tick
	var recipe_hash: String = desktop.microscenario_definition.source_recipe_hash
	var policy: Dictionary = desktop.tower_context.liquid_solver_policy.duplicate(true)
	var receipt: Dictionary = desktop.tower_context.liquid_construction_receipt.duplicate(true)
	desktop.begin_measurement()
	var started: int = Time.get_ticks_usec()
	emit_stage("measurement_started")
	while Time.get_ticks_usec() - started < sample_seconds * 1000000:
		await process_frame
	var ended: int = Time.get_ticks_usec()
	desktop.end_measurement()
	release_controls()
	var native_delta: int = desktop.latest_snapshot.tick_index - initial_native
	var physics_delta: int = desktop.physical_actor_session.tick - initial_physics
	expect(native_delta > 0 and physics_delta > 0 and not worker.has_failed(),
		"both real clocks advance without native failure")
	expect(desktop.latest_snapshot.render_world_generation == generation and desktop._physical_epoch == epoch
		and desktop.tower_context.liquid_solver_policy == policy
		and desktop.tower_context.liquid_construction_receipt == receipt,
		"measured World/actor/policy/receipt identities remain fixed")
	expect(desktop.main_callback_usec.size() > 1
		and desktop.snapshot_rows.size() == desktop.main_callback_usec.size(),
		"every measured Main callback has one immutable publication observation")
	expect(worker.mutex_acquire_wait_usec.size() == desktop.main_callback_usec.size(),
		"exactly one timed snapshot acquisition occurs per measured Main callback")
	var graphical: bool = DisplayServer.get_name() != "headless"
	expect((graphical and desktop.rendered_usec.size() > 1) or
		(not graphical and desktop.rendered_usec.is_empty()),
		"graphical frame submissions are observed, or explicitly absent for headless")
	result = {"schema":"play-pace003-shared-host-v1", "source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"rig":str(requested_rig), "requested_workers":requested_workers, "policy_preset":requested_policy,
		"sample_seconds":sample_seconds, "started_usec":started, "ended_usec":ended,
		"elapsed_usec":ended - started, "generation":generation, "actor_epoch":epoch,
		"initial_main_native_tick":initial_native, "final_main_native_tick":desktop.latest_snapshot.tick_index,
		"initial_rapier_tick":initial_physics, "final_rapier_tick":desktop.physical_actor_session.tick,
		"native_ticks_observed_by_main":native_delta, "rapier_ticks":physics_delta,
		"native_hz_observed_by_main":float(native_delta) * 1000000.0 / float(ended - started),
		"rapier_hz":float(physics_delta) * 1000000.0 / float(ended - started),
		"construction_usec":construction_usec, "course_recipe_hash":recipe_hash,
		"policy":policy, "receipt":receipt, "platform":OS.get_name(), "os_version":OS.get_version(),
		"cpu_name":OS.get_processor_name(), "logical_processors":OS.get_processor_count(),
		"godot":Engine.get_version_info(), "display_server":DisplayServer.get_name(),
		"rendering_method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"requested_rendering_driver":OS.get_environment("CYBERSAND_PACE003_RENDERING_DRIVER"),
		"reported_rendering_driver":str(RenderingServer.call("get_current_rendering_driver_name")) \
			if RenderingServer.has_method("get_current_rendering_driver_name") else "unavailable",
		"video_adapter":RenderingServer.get_video_adapter_name() if graphical else "headless",
		"viewport":[root.size.x,root.size.y], "canvas":[root.content_scale_size.x,root.content_scale_size.y],
		"scope":{"actual_shared_host":true, "synthetic_focus":true, "physical_devices":false,
			"human_feel":false, "native_jobs_held":false, "frame_submissions_measured":graphical,
			"physical_scanout_measured":false, "synchronous_reference_measured":false,
			"input_tape_basis":"Rapier ticks; intended script equal, native admission skew not fixed",
			"main_wait":"test-only equivalent snapshot mutex acquisition; other Main locks unmeasured",
			"native_timer":"every distinct native completion in sample; exclusive-owner copied statistics after publication",
			"instrumentation_cost":"worker copied-statistics probe and bounded arrays included in wall pacing, excluded from native timer",
			"external_load":"uncontrolled; no positive speedup required"},
		"raw":{"main_started_usec":desktop.main_started_usec.duplicate(),
			"main_callback_usec":desktop.main_callback_usec.duplicate(),
			"physics_callback_usec":desktop.physics_callback_usec.duplicate(),
			"rendered_usec":desktop.rendered_usec.duplicate(),
			"snapshot_rows":desktop.snapshot_rows.duplicate(true),
			"input_tape":desktop.input_tape.duplicate(true),
			"snapshot_mutex_wait_usec":worker.mutex_acquire_wait_usec.duplicate(),
			"snapshot_mutex_critical_usec":worker.mutex_critical_section_usec.duplicate()}}
	# Ordinary graphical capture AFTER timing ends. Do not force a render or
	# wait on native completion. A nonblank image is still not visual review.
	result.framebuffer = {"captured":false, "reason":"headless"}
	if graphical:
		var captured: Image = root.get_texture().get_image()
		var capture_ok: bool = captured != null and not captured.is_empty() \
			and captured.get_size() == root.size
		expect(capture_ok, "ordinary graphical viewport has its actual 960x540 image")
		if capture_ok:
			var first_color: Color = captured.get_pixel(0,0)
			var differing_samples: int = 0
			var total_samples: int = 0
			for y: int in range(0, captured.get_height(), 16):
				for x: int in range(0, captured.get_width(), 16):
					var pixel: Color = captured.get_pixel(x,y)
					if absf(pixel.r - first_color.r) + absf(pixel.g - first_color.g) \
						+ absf(pixel.b - first_color.b) > 0.03:
						differing_samples += 1
					total_samples += 1
			var capture_path: String = OS.get_environment("CYBERSAND_PACE003_CAPTURE")
			var saved: Error = captured.save_png(capture_path) if not capture_path.is_empty() else ERR_INVALID_PARAMETER
			expect(differing_samples > 25 and saved == OK,
				"ordinary post-window image is nonblank and original PNG is retained")
			result.framebuffer = {"captured":saved == OK, "width":captured.get_width(),
				"height":captured.get_height(), "sample_step":16, "samples":total_samples,
				"different_from_top_left_rgb":differing_samples, "captured_after_sample":true,
				"path":capture_path.get_file(), "png_sha256":FileAccess.get_sha256(capture_path) if saved == OK else ""}
	emit_stage("measurement_completed")
	var reset_started: int = Time.get_ticks_usec()
	desktop.microscenario_reset()
	ready = await wait_for(Callable(self, "new_actor").bind(desktop, requested_rig, epoch), SETUP_TIMEOUT_MS)
	expect(ready, "ordinary applied-session reset completes within 30 seconds")
	result.reset_usec = Time.get_ticks_usec() - reset_started
	var last_session = desktop.physical_actor_session
	var shutdown_started: int = Time.get_ticks_usec()
	await close_cycle(desktop, worker, last_session, "PACE003: ")
	# A failed retirement assertion does not transfer ownership. Never inspect
	# worker-owned rows unless the actual stop/join has finished.
	if worker._thread.is_started():
		quit(1)
		return
	result.scene_retirement_usec = Time.get_ticks_usec() - shutdown_started
	result.stop_join_usec = worker.stop_join_usec
	# Ownership transfer is the actual join above; no worker-owned row was read
	# while the native owner could still append it.
	var native_samples: Array[Dictionary] = []
	for row: Dictionary in worker.native_rows:
		if int(row.completed_usec) >= started and int(row.completed_usec) < ended \
			and int(row.generation) == generation and int(row.actor_epoch) == epoch:
			native_samples.append(row.duplicate(true))
	expect(not worker.native_rows_overflow and not native_samples.is_empty(),
		"bounded exclusive-owner native records survive stop/join")
	result.raw.native_rows = native_samples
	result.native_completion_count = native_samples.size()
	result.native_vs_main_boundary_difference = native_samples.size() - native_delta
	result.native_count_boundary_note = "Owner rows are timestamped just after native tick returns and before publication. Main counts use last consumed publications at the two boundaries; delivery/coalescing can make them differ. Native quantiles use all consecutive owner completions in [started_usec, ended_usec), read only after join."
	result.native_rows_overflow = worker.native_rows_overflow
	result.assertions = assertions
	result.failures = failures
	result.workers_joined = joined_workers
	result.rapier_sessions_retired = retired_sessions
	result.retries = 0
	print("PLAY_PACE003_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
