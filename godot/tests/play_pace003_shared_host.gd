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
var scene_startup: Dictionary = {}


class MeasurementHost:
	extends "res://scripts/main.gd"
	const WorkerProbe = preload("res://tests/play_pace003_worker_probe.gd")
	const MAX_SETUP_SAMPLES: int = 8192
	var setup_sampling: bool = true
	var setup_started_usec: int = 0
	var setup_ended_usec: int = 0
	var setup_ready_usec: int = 0
	var setup_main_calls: int = 0
	var setup_physics_calls: int = 0
	var setup_render_calls: int = 0
	var setup_main_started_usec: Array[int] = []
	var setup_main_callback_usec: Array[int] = []
	var setup_physics_started_usec: Array[int] = []
	var setup_physics_callback_usec: Array[int] = []
	var setup_rendered_usec: Array[int] = []
	var setup_readiness_predicate: Callable
	var setup_form_started_usec: int = 0
	var setup_request_started_usec: int = 0
	var setup_deadline_usec: int = 0
	var setup_acknowledged_usec: int = 0
	var setup_acknowledged_identity: Dictionary = {}
	var setup_observed_poll_usec: int = 0
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
		setup_started_usec = Time.get_ticks_usec()
		print("CYBERSAND_PROGRESS ", JSON.stringify({"case":"play_pace003", "stage":"main_ready_started",
			"monotonic_usec":setup_started_usec}))
		# Replace the default-created, UNSTARTED worker only. No second live owner.
		simulation_worker = WorkerProbe.new()
		super._ready()
		setup_ready_usec = Time.get_ticks_usec()
		print("CYBERSAND_PROGRESS ", JSON.stringify({"case":"play_pace003", "stage":"main_ready_completed",
			"monotonic_usec":setup_ready_usec}))
		RenderingServer.frame_post_draw.connect(_record_render)

	func _exit_tree() -> void:
		if RenderingServer.frame_post_draw.is_connected(_record_render):
			RenderingServer.frame_post_draw.disconnect(_record_render)
		super._exit_tree()

	func _actor_window_has_focus() -> bool:
		return true # Synthetic focus predicate, never physical-focus qualification.

	func end_setup_observation() -> void:
		setup_sampling = false
		setup_ended_usec = Time.get_ticks_usec()
		setup_readiness_predicate = Callable()

	func arm_setup_readiness(predicate: Callable, form_started: int, request_started: int) -> void:
		setup_readiness_predicate = predicate
		setup_form_started_usec = form_started
		setup_request_started_usec = request_started
		setup_deadline_usec = request_started + SETUP_TIMEOUT_MS * 1000

	func setup_acknowledgement() -> Dictionary:
		return {"predicate":"actor_ready", "observer":"after_actual_Main_process",
			"form_started_usec":setup_form_started_usec,
			"request_started_usec":setup_request_started_usec, "deadline_usec":setup_deadline_usec,
			"acknowledged_usec":setup_acknowledged_usec, "polled_usec":setup_observed_poll_usec,
			"poll_elapsed_usec":setup_observed_poll_usec - setup_request_started_usec,
			"identity":setup_acknowledged_identity.duplicate(true)}

	func setup_observation() -> Dictionary:
		return {"started_usec":setup_started_usec, "ended_usec":setup_ended_usec,
			"ready_completed_usec":setup_ready_usec, "max_samples_per_series":MAX_SETUP_SAMPLES,
			"main_calls":setup_main_calls, "physics_calls":setup_physics_calls,
			"render_submissions":setup_render_calls,
			"main_samples_truncated":setup_main_calls > MAX_SETUP_SAMPLES,
			"physics_samples_truncated":setup_physics_calls > MAX_SETUP_SAMPLES,
			"render_samples_truncated":setup_render_calls > MAX_SETUP_SAMPLES,
			"main_started_usec":setup_main_started_usec.duplicate(),
			"main_callback_usec":setup_main_callback_usec.duplicate(),
			"physics_started_usec":setup_physics_started_usec.duplicate(),
			"physics_callback_usec":setup_physics_callback_usec.duplicate(),
			"rendered_usec":setup_rendered_usec.duplicate()}

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
		if DisplayServer.get_name() == "headless":
			return
		var now: int = Time.get_ticks_usec()
		if setup_sampling:
			setup_render_calls += 1
			if setup_rendered_usec.size() < MAX_SETUP_SAMPLES:
				setup_rendered_usec.append(now)
		if sampling:
			rendered_usec.append(now)

	func _process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super._process(delta)
		# SceneTree.process_frame runs before Main._process. Retain when the exact
		# existing predicate first becomes true, so a later slow render cannot
		# turn an in-deadline acknowledgement into a polling-order false negative.
		# A late acknowledgement is still recorded and MUST fail the deadline.
		var acknowledged_now: bool = setup_sampling and setup_acknowledged_usec == 0 \
			and setup_readiness_predicate.is_valid() and setup_readiness_predicate.call()
		var ended: int = Time.get_ticks_usec()
		if acknowledged_now:
			setup_acknowledged_usec = ended
			setup_acknowledged_identity = {"rig":str(physical_rig_id), "actor_epoch":_physical_epoch,
				"generation":latest_snapshot.render_world_generation}
			print("CYBERSAND_PROGRESS ", JSON.stringify({"case":"play_pace003", "stage":"main_acknowledged",
				"monotonic_usec":ended, "request_deadline_usec":setup_deadline_usec,
				"within_deadline":ended <= setup_deadline_usec}))
		if setup_sampling:
			setup_main_calls += 1
			if setup_main_started_usec.size() < MAX_SETUP_SAMPLES:
				setup_main_started_usec.append(started)
				setup_main_callback_usec.append(ended - started)
		if not sampling:
			return
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
		var ended: int = Time.get_ticks_usec()
		if setup_sampling:
			setup_physics_calls += 1
			if setup_physics_started_usec.size() < MAX_SETUP_SAMPLES:
				setup_physics_started_usec.append(started)
				setup_physics_callback_usec.append(ended - started)
		if sampling:
			physics_callback_usec.append(float(ended - started))


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_PACE003: " + message)


func emit_stage(stage: String) -> void:
	print("CYBERSAND_PROGRESS ", JSON.stringify({"case":"play_pace003", "stage":stage,
		"monotonic_usec":Time.get_ticks_usec()}))


func mark_scene_startup(stage: String) -> void:
	var now: int = Time.get_ticks_usec()
	scene_startup[stage + "_usec"] = now
	print("CYBERSAND_PROGRESS ", JSON.stringify({"case":"play_pace003", "stage":stage,
		"monotonic_usec":now}))


func presentation_shader_identity(desktop: Control) -> Array[Dictionary]:
	# Read after the timed window (or after a setup failure). Identify the actual
	# attached resources, so a diagnostic replacement cannot pass from a nonblank UI.
	var identities: Array[Dictionary] = []
	var materials: Array[ShaderMaterial] = [desktop.world_shader,
		desktop.glow_source_shader, desktop.glow_composite_shader]
	materials.append_array(desktop.vapour_trail_shaders)
	for material: ShaderMaterial in materials:
		if material == null or material.shader == null:
			identities.append({"missing":true})
			continue
		var shader: Shader = material.shader
		identities.append({"resource_path":shader.resource_path,
			"file_sha256":FileAccess.get_sha256(shader.resource_path),
			"loaded_code_sha256":shader.code.sha256_text()})
	return identities


func cache_paths() -> Dictionary:
	# Compatibility stores generated shaders under user://, not only .godot/.
	# The runner must bind these actual engine paths to this process's private root.
	var user_data: String = OS.get_user_data_dir()
	return {"user_data_dir":user_data, "shader_cache_dir":user_data.path_join("shader_cache")}


func new_actor(desktop: Control, rig: StringName, epoch: int) -> bool:
	return actor_ready(desktop, rig) and desktop._physical_epoch > epoch


func wait_for_setup_acknowledgement(desktop: Control) -> bool:
	# The deadline was fixed BEFORE Build. Polling can return later because a
	# graphical frame blocks this coroutine. Only a retained actual Main-side
	# acknowledgement at/before that original deadline permits success.
	while Time.get_ticks_usec() < desktop.setup_deadline_usec:
		if desktop.setup_acknowledged_usec > 0:
			break
		await process_frame
	desktop.setup_observed_poll_usec = Time.get_ticks_usec()
	return desktop.setup_acknowledged_usec >= desktop.setup_request_started_usec \
		and desktop.setup_acknowledged_usec <= desktop.setup_deadline_usec \
		and desktop.setup_acknowledged_usec > 0 and actor_ready(desktop, requested_rig)


func emit_setup_failure(desktop: Control, stage: String, construction_started: int) -> void:
	# Main-owned candidate fields and immutable copied publications only. Never
	# inspect the live native World or the worker-owned completion arrays here.
	desktop.end_setup_observation()
	var pending: Dictionary = desktop.pending_microscenario_apply
	var accepted: Dictionary = desktop.tower_context
	var candidate: RefCounted = desktop._pending_physical_candidate
	var candidate_state: Dictionary = {"present":candidate != null}
	if candidate != null:
		candidate_state.merge({"instance_id":candidate.get_instance_id(),
			"script":candidate.get_script().resource_path, "last_error":candidate.last_error,
			"terrain_installed":candidate._terrain_installed,
			"terrain_ready":candidate._terrain_ready,
			"verified_physics_frames":candidate._verified_physics_frames,
			"last_verified_physics_frame":candidate._last_physics_frame,
			"adopted":candidate._adopted, "has_session":is_instance_valid(candidate.session)})
		var bridge: CyberRapierPhysicsBridge = candidate.physics_bridge()
		candidate_state["pending_terrain_chunks"] = bridge.pending_hard_surface_chunks() if bridge != null else -1
	var snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var snapshot_state: Dictionary = {"present":snapshot != null}
	if snapshot != null:
		snapshot_state.merge({"serial":snapshot.serial, "published_usec":snapshot.published_usec,
			"tick":snapshot.tick_index, "actor_epoch":snapshot.rigid_body_epoch,
			"generation":snapshot.render_world_generation, "paused":snapshot.paused,
			"simulation_failed":snapshot.simulation_failed, "failed_tick":snapshot.failed_tick_index,
			"last_tick_error":snapshot.last_tick_error, "hard_surface_revision":snapshot.hard_surface_revision,
			"terrain_chunk_snapshot_valid":snapshot.hard_surface_chunk_rectangles_valid,
			"terrain_chunk_value_count":snapshot.hard_surface_chunk_rectangles.size(),
			"world_revision":snapshot.world_revision, "simulation_world_revision":snapshot.simulation_world_revision})
	var identity: Dictionary = desktop._prepared_physical_identity
	print("PLAY_PACE003_SETUP_FAILURE ", JSON.stringify({
		"schema":"play-pace003-setup-failure-v1", "source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"stage":stage, "requested_rig":str(requested_rig), "requested_workers":requested_workers,
		"installation_limit_ms":SETUP_TIMEOUT_MS,
		"construction_elapsed_usec":Time.get_ticks_usec() - construction_started,
		"scene_startup":scene_startup.duplicate(true),
		"presentation_shaders":presentation_shader_identity(desktop),
		"cache_paths":cache_paths(),
		"display_server":DisplayServer.get_name(), "graphical_scanout_measured":false,
		"observation":desktop.setup_observation(), "acknowledgement":desktop.setup_acknowledgement(),
		"engine_physics_frames":Engine.get_physics_frames(),
		"tree_paused":paused, "host_can_process":desktop.can_process(), "host_paused":desktop.paused,
		"worker_start_error":desktop.worker_start_error, "course_installed":course_installed(desktop),
		"actor_ready":actor_ready(desktop, requested_rig), "accepted_rig":str(desktop.physical_rig_id),
		"accepted_epoch":desktop._physical_epoch, "accepted_terrain_ready":desktop._physical_terrain_ready,
		"actor_reset_receipt":desktop._actor_reset_receipt, "microscenario_error":desktop.microscenario_error,
		"pending":{"present":not pending.is_empty(), "serial":pending.get("serial",-1),
			"route":pending.get("route",""), "hash":pending.get("hash","")},
		"prepared_identity":{"present":not identity.is_empty(), "serial":identity.get("serial",-1),
			"instance_id":identity.get("instance_id",-1), "ready_sent":desktop._prepared_physical_ready_sent},
		"copied_accepted_context":{"scenario_request_serial":accepted.get("scenario_request_serial",-1),
			"scenario_request_applied":accepted.get("scenario_request_applied",false),
			"micro_active":accepted.get("micro_active",false), "status":accepted.get("status",""),
			"microscenario_id":accepted.get("microscenario",{}).get("id",""),
			"microscenario_mode":accepted.get("microscenario",{}).get("mode",""),
			"microscenario_failed":accepted.get("microscenario",{}).get("failed",false),
			"microscenario_error":accepted.get("microscenario",{}).get("error",""),
			"construction_receipt":accepted.get("liquid_construction_receipt",{}).duplicate(true)},
		"candidate":candidate_state, "snapshot":snapshot_state}))


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
	mark_scene_startup("scene_load_started")
	var packed_scene: PackedScene = load("res://main.tscn")
	mark_scene_startup("scene_load_completed")
	mark_scene_startup("scene_instantiate_started")
	var desktop: Control = packed_scene.instantiate()
	mark_scene_startup("scene_instantiate_completed")
	desktop.set_script(MeasurementHost)
	mark_scene_startup("scene_add_child_started")
	root.add_child(desktop)
	mark_scene_startup("scene_add_child_completed")
	await process_frame
	var worker: Probe = desktop.simulation_worker as Probe
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "actual shared desktop owner starts")
	emit_stage("worker_started")
	var construction_started: int = Time.get_ticks_usec()
	var setup_stage: String = "worker_start"
	if ready:
		setup_stage = "selector_admission"
		var panel = desktop.playable_session_panel
		panel.show_selection()
		panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(requested_rig))
		panel.control_choice.select(1)
		panel.rule_choice.select(1)
		panel.camera_choice.select(1)
		panel.policy_editor.select_preset(requested_policy)
		emit_stage("selection_form_ready")
		desktop.arm_setup_readiness(Callable(self, "actor_ready").bind(desktop, requested_rig),
			construction_started, Time.get_ticks_usec())
		ready = panel.build_selected()
		expect(ready, "integrated selector admits actual native-backed composed session")
		if ready:
			emit_stage("selector_admitted")
			setup_stage = "course_actor_terrain_acknowledgement"
			ready = await wait_for_setup_acknowledgement(desktop)
		expect(ready, "actual authored course/SetP actor/terrain acknowledged within 30 seconds")
	var construction_usec: int = desktop.setup_observed_poll_usec - construction_started \
		if desktop.setup_observed_poll_usec > 0 else Time.get_ticks_usec() - construction_started
	if ready:
		setup_stage = "neutral_rearm_and_completed_clocks"
		emit_stage("session_installed")
		var before_native: int = desktop.latest_snapshot.tick_index
		var before_physics: int = desktop.physical_actor_session.tick
		desktop.playable_session_panel.resume_play()
		ready = await wait_for(Callable(self, "clocks_advanced").bind(desktop, requested_rig,
			before_physics, before_native))
		expect(ready, "neutral rearm followed by both completed native/Rapier clocks")
	if not ready:
		emit_setup_failure(desktop, setup_stage, construction_started)
		await close_cycle(desktop, worker, desktop.physical_actor_session, "PACE003 setup: ")
		quit(1)
		return
	desktop.end_setup_observation()
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
		"scene_startup":scene_startup.duplicate(true),
		"presentation_shaders":presentation_shader_identity(desktop),
		"cache_paths":cache_paths(),
		"setup_observation":desktop.setup_observation(), "setup_acknowledgement":desktop.setup_acknowledgement(),
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
