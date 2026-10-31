extends "res://tests/play_life001_shared_host_case.gd"

# Explicit 40-event tape; each item is ONE real InputEventKey, never a grouped
# intention or a count inferred from elapsed time. Automatic production callbacks
# own all native and Rapier progress. The sole positive-path OS seam is focus.
const Probe = preload("res://tests/play_pace004_worker_probe.gd")
const MAX_ROWS: int = 8192
const PacingPolicy = preload("res://tests/support/ci_execution_policy.gd")
const PaletteSelector = preload("res://scripts/palette_shader_selector.gd")
var fixture_limit_usec: int = PacingPolicy.microseconds("complex_fixture_seconds")
const SAMPLE_USEC: int = 15000000
var rig: StringName = &"acrobat"
var workers: int = 0
var policy_preset: int = 0
var workload_mode: String = "none"
var desktop: Control
var fixture_started: int = 0
var waits: Array[Dictionary] = []
var event_id: int = 0
var measurement: Dictionary = {}
var captures: Dictionary = {}


class ObservedMain:
	extends "res://scripts/main.gd"
	const Observer = preload("res://tests/play_pace004_worker_probe.gd")
	const BrushLoad = preload("res://tests/play_pace004_brush_load.gd")
	var workload_mode: String = "none"
	var brush_load = BrushLoad.new()
	var focus_allowed: bool = true
	var capture_active: bool = false
	var sampling: bool = false
	var overflow: bool = false
	var trace: Array[Dictionary] = []
	var main_rows: Array[Dictionary] = []
	var draw_usec: Array[int] = []
	var draw_count: int = 0
	var current_event: int = 0
	var event_handlers: int = 0
	var event_admissions: Array[Dictionary] = []
	var physics_admission: Dictionary = {}
	var in_physics: bool = false
	var setup_predicate: Callable
	var setup_ack_usec: int = 0
	var setup_deadline_usec: int = 0

	func _ready() -> void:
		# Replace an UNSTARTED allocation. Only this inherited production worker
		# starts; the fixture introduces no second live owner or stepping loop.
		simulation_worker = Observer.new()
		simulation_worker.observe_brush_load = workload_mode != "none"
		super._ready()
		RenderingServer.frame_post_draw.connect(_draw_completed)

	func _exit_tree() -> void:
		if RenderingServer.frame_post_draw.is_connected(_draw_completed):
			RenderingServer.frame_post_draw.disconnect(_draw_completed)
		super._exit_tree()

	func _actor_window_has_focus() -> bool:
		return focus_allowed

	func _draw_completed() -> void:
		if DisplayServer.get_name() == "headless":
			return
		draw_count += 1
		if sampling:
			if draw_usec.size() >= 8192:
				overflow = true
			else:
				draw_usec.append(Time.get_ticks_usec())

	static func action_values(action: Dictionary) -> Dictionary:
		var movement: Vector2 = action.get("move", Vector2.ZERO)
		return {"move":[movement.x, movement.y], "trim":float(action.get("trim", 0.0)),
			"primary":bool(action.get("primary", false)),
			"secondary":bool(action.get("secondary", false)),
			"auxiliary":bool(action.get("auxiliary", false))}

	func state() -> Dictionary:
		if physical_actor_session == null or latest_snapshot == null:
			return {}
		var view: Dictionary = physical_actor_session.snapshot().actors[0]
		var position: Vector2 = view.get("position", Vector2.INF)
		var impulse: Vector2 = view.get("applied_impulse", Vector2.ZERO)
		return {"time_usec":Time.get_ticks_usec(), "worker":simulation_worker.get_instance_id(),
			"session":physical_actor_session.get_instance_id(), "bridge":rapier_bridge.get_instance_id(),
			"run_id":str(view.run_id), "epoch":int(view.epoch),
			"generation":int(view.control_generation), "world_generation":int(latest_snapshot.render_world_generation),
			"sequence":int(view.last_sequence), "tick":int(view.tick), "step":rapier_bridge.manual_step_count(),
			"native_tick":int(latest_snapshot.tick_index), "serial":int(latest_snapshot.serial),
			"backend":str(latest_snapshot.backend_name), "native_paused":bool(latest_snapshot.paused),
			"paused":paused, "suspended":bool(view.suspended), "focus":focus_allowed,
			"rearm":_actor_input_rearm, "pending":not pending_microscenario_apply.is_empty(),
			"accepted":physical_actor_session.accepted_commands, "rejected":physical_actor_session.rejected_commands,
			"edges":physical_actor_session._button_edges[0].duplicate(true),
			"action":action_values(view.get("action", {})), "position":[position.x, position.y],
			"impulse":[impulse.x, impulse.y], "torque_impulse":float(view.get("applied_torque_impulse", 0.0)),
			"lap_ticks":int(_playable_course_progress.elapsed_ticks), "fault":str(view.get("fault", "")),
			"render_rejections":rejected_render_snapshot_count}

	func append_trace(row: Dictionary) -> void:
		if not capture_active:
			return
		if trace.size() >= 8192:
			overflow = true
			return
		row["ordinal"] = trace.size() + 1
		trace.append(row)

	func _unhandled_key_input(event: InputEvent) -> void:
		if current_event > 0 and event is InputEventKey:
			event_handlers += 1
		super._unhandled_key_input(event)

	func _publish_physical_keyboard_input(trigger_override: Variant = null,
			alternate_override: Variant = null) -> void:
		if not capture_active or physical_actor_session == null:
			super._publish_physical_keyboard_input(trigger_override, alternate_override)
			return
		var before: Dictionary = state()
		super._publish_physical_keyboard_input(trigger_override, alternate_override)
		var after: Dictionary = state()
		var row: Dictionary = {"before":before, "after":after,
			"command":action_values(physical_actor_session._commands[0])}
		if current_event > 0:
			event_admissions.append(row)
		if in_physics:
			physics_admission = row

	func _physics_process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		var before: Dictionary = state() if capture_active else {}
		physics_admission = {}
		in_physics = true
		super._physics_process(delta)
		in_physics = false
		var ended: int = Time.get_ticks_usec()
		var after: Dictionary = state() if capture_active else {}
		if not before.is_empty() and not after.is_empty():
			append_trace({"kind":"physics", "before":before, "after":after,
				"admission":physics_admission.duplicate(true), "started_usec":started,
				"ended_usec":ended, "rapier_ms":rapier_bridge.last_step_time_ms(), "sampling":sampling})

	func _process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super._process(delta)
		var ended: int = Time.get_ticks_usec()
		# Observe acknowledgement INSIDE Main after production work, before a
		# slow graphics call can delay the SceneTree coroutine's next poll.
		if setup_ack_usec == 0 and setup_predicate.is_valid() and setup_predicate.call():
			setup_ack_usec = ended
		if not sampling or latest_snapshot == null:
			return
		if main_rows.size() >= 8192:
			overflow = true
			return
		main_rows.append({"started_usec":started, "ended_usec":ended,
			"serial":int(latest_snapshot.serial), "tick":int(latest_snapshot.tick_index),
			"generation":int(latest_snapshot.render_world_generation), "epoch":int(latest_snapshot.rigid_body_epoch),
			"published_usec":int(latest_snapshot.published_usec), "render_usec":int(latest_snapshot.render_generated_usec),
			"render_serial":int(latest_snapshot.render_snapshot_serial), "render_tick":int(latest_snapshot.render_tick_index),
			"render_revision":int(latest_snapshot.world_revision),
			"simulation_revision":int(latest_snapshot.simulation_world_revision),
			"copy_ms":float(latest_snapshot.snapshot_copy_time_ms), "failed":bool(latest_snapshot.simulation_failed),
			"rejected_render_snapshots":rejected_render_snapshot_count})
		# Fixture enqueue work is timed separately, outside the production Main
		# callback measurement; callback cadence still includes its real cost.
		brush_load.pump(self)


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_PACE004: " + message)


func bounded(predicate: Callable, name: String, limit_usec: int = -1) -> bool:
	if limit_usec < 0:
		limit_usec = PacingPolicy.microseconds("operation_seconds")
	var started: int = Time.get_ticks_usec()
	var deadline: int = mini(started + limit_usec, fixture_started + fixture_limit_usec)
	var passed: bool = false
	while Time.get_ticks_usec() <= deadline:
		if predicate.call():
			passed = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	waits.append({"name":name, "started_usec":started, "ended_usec":Time.get_ticks_usec(),
		"deadline_usec":deadline, "limit_usec":limit_usec, "passed":passed})
	expect(passed, name)
	return passed


func time_reached(target: int) -> bool:
	return Time.get_ticks_usec() >= target


func observe_usec(duration: int, name: String) -> bool:
	return await bounded(Callable(self, "time_reached").bind(Time.get_ticks_usec() + duration), name)


func steps_completed(before: Dictionary, count: int = 1) -> bool:
	var after: Dictionary = desktop.state()
	return (not after.is_empty() and after.run_id == before.run_id and after.epoch == before.epoch
		and after.tick >= before.tick + count and after.step >= before.step + count)


func edges_consumed() -> bool:
	return not desktop.state().is_empty() and desktop.state().edges.is_empty()


func controls_ready() -> bool:
	return actor_ready(desktop, rig) and not desktop._actor_input_rearm and not desktop.paused


func load_owner_running() -> bool:
	var current: Dictionary = desktop.state()
	return controls_ready() and not current.is_empty() and not current.native_paused \
		and not current.suspended and int(current.native_tick) > 0


func pause_ack(before: Dictionary) -> bool:
	var value: Dictionary = desktop.state()
	return not value.is_empty() and value.paused and value.native_paused and value.suspended \
		and value.serial > before.serial and value.generation > before.generation


func setup_acknowledged() -> bool:
	return desktop.setup_ack_usec > 0


func wait_setup_acknowledgement(started: int) -> bool:
	# Main owns the acknowledgement deadline. A later render can delay the
	# coroutine poll; retain both times without moving the original deadline.
	while Time.get_ticks_usec() < desktop.setup_deadline_usec and desktop.setup_ack_usec == 0:
		await process_frame
	var passed: bool = desktop.setup_ack_usec >= started and desktop.setup_ack_usec > 0 \
		and desktop.setup_ack_usec <= desktop.setup_deadline_usec
	waits.append({"name":"Main construction acknowledgement", "started_usec":started,
		"ended_usec":Time.get_ticks_usec(), "acknowledged_usec":desktop.setup_ack_usec,
		"deadline_usec":desktop.setup_deadline_usec, "limit_usec":PacingPolicy.microseconds("main_ack_seconds"), "passed":passed})
	expect(passed, "Main construction acknowledgement")
	return passed


func draw_after(count: int) -> bool:
	return desktop.draw_count >= count


func control_key(code: Key) -> void:
	parse_key(code, true)
	parse_key(code, false)


func event(code: Key, key_name: String, pressed: bool, disposition: String) -> Dictionary:
	event_id += 1
	var before: Dictionary = desktop.state()
	desktop.current_event = event_id
	desktop.event_handlers = 0
	desktop.event_admissions.clear()
	parse_key(code, pressed)
	desktop.current_event = 0
	var row: Dictionary = {"kind":"event", "id":event_id, "key":key_name,
		"pressed":pressed, "expected":disposition, "before":before, "after":desktop.state(),
		"handler_calls":desktop.event_handlers, "admissions":desktop.event_admissions.duplicate(true)}
	desktop.append_trace(row)
	expect(desktop.event_handlers == 1 and desktop.event_admissions.size() == 1,
		"event %02d has exactly one production handler/admission attempt" % event_id)
	return before


func applied_key(code: Key, key_name: String, pressed: bool, hold_usec: int = 0) -> bool:
	var before: Dictionary = event(code, key_name, pressed, "applied")
	if not await bounded(Callable(self, "steps_completed").bind(before, 1), "event %02d completed step" % event_id):
		return false
	if hold_usec > 0:
		return await observe_usec(hold_usec, "event %02d held observation" % event_id)
	return true


func quick_pair(code: Key, key_name: String, disposition: String = "applied") -> bool:
	var before: Dictionary = event(code, key_name, true, disposition)
	event(code, key_name, false, disposition)
	if disposition != "applied":
		return true
	if not await bounded(Callable(self, "steps_completed").bind(before, 2), "quick pair completed steps"):
		return false
	return await bounded(Callable(self, "edges_consumed"), "ordered quick pair consumed")


func transition(name: String, before: Dictionary, details: Dictionary = {}) -> void:
	desktop.append_trace({"kind":"transition", "name":name, "before":before,
		"after":desktop.state(), "details":details.duplicate(true)})


func resumed_owners_progressed(before: Dictionary) -> bool:
	var current: Dictionary = desktop.state()
	return steps_completed(before, 2) and int(current.native_tick) > int(before.native_tick) \
		and not bool(current.native_paused) and not bool(current.paused)


func execute_tape() -> bool:
	var move_key: Key = KEY_D if rig == &"acrobat" else KEY_W
	var back_key: Key = KEY_A if rig == &"acrobat" else KEY_S
	desktop.capture_active = true
	desktop.sampling = true
	var measured_start: int = desktop.simulation_worker.begin_measurement()
	measurement = {"started_usec":measured_start, "initial":desktop.state()}
	desktop.brush_load.begin(desktop,workload_mode,measurement.started_usec,measurement.initial)
	# IDs 1..16: the loaded gameplay window contains real movement, trim and
	# six quick button edges, with analogue state held until a completed step.
	if not await applied_key(move_key, "forward", true, 3000000): return false
	if not await applied_key(move_key, "forward", false, 250000): return false
	if not await applied_key(KEY_Q, "trim_left", true, 2000000): return false
	if not await applied_key(KEY_Q, "trim_left", false, 250000): return false
	if not await quick_pair(KEY_SPACE, "primary"): return false
	if not await observe_usec(500000, "primary observation"): return false
	if not await quick_pair(KEY_SHIFT, "secondary"): return false
	if not await observe_usec(500000, "secondary observation"): return false
	if not await quick_pair(KEY_C, "auxiliary"): return false
	if not await observe_usec(500000, "auxiliary observation"): return false
	if not await applied_key(back_key, "back", true, 3000000): return false
	if not await applied_key(back_key, "back", false, 250000): return false
	if not await applied_key(KEY_E, "trim_right", true, 2000000): return false
	if not await applied_key(KEY_E, "trim_right", false, 250000): return false
	if not await quick_pair(KEY_SPACE, "primary"): return false
	if not await bounded(Callable(self, "time_reached").bind(measurement.started_usec + SAMPLE_USEC), "15 second gameplay sample"):
		return false
	measurement["ended_usec"] = desktop.simulation_worker.finish_measurement()
	measurement["final"] = desktop.state()
	desktop.brush_load.stop(desktop)
	desktop.sampling = false
	desktop.simulation_worker.end_sample()
	var before: Dictionary = desktop.state()
	control_key(KEY_P)
	if not await bounded(Callable(self, "pause_ack").bind(before), "actual native pause acknowledgement"): return false
	transition("pause_acknowledged", before)
	before = desktop.state()
	if not await observe_usec(350000, "acknowledged pause observation"): return false
	transition("paused_window", before)
	before = desktop.state()
	control_key(KEY_P)
	if not await bounded(Callable(self, "controls_ready"), "resume neutral rearm"): return false
	if not await bounded(Callable(self, "resumed_owners_progressed").bind(before), "resume completed native and Rapier steps"): return false
	transition("resume_completed", before)
	# IDs 17..22: pause/resume inside ONE Main turn must retire pending edges,
	# even when no physics callback observes paused=true. Held input stays inert.
	await quick_pair(KEY_SPACE, "primary", "cancelled")
	before = desktop.state()
	control_key(KEY_P)
	control_key(KEY_P)
	transition("rapid_pause", before)
	expect(desktop.state().generation > before.generation and desktop.state().edges.is_empty(),
		"rapid pause revokes pending input before the next callback")
	before = event(move_key, "forward", true, "refused")
	if not await bounded(Callable(self, "steps_completed").bind(before, 2), "held after rapid pause stays neutral"): return false
	if not await applied_key(move_key, "forward", false): return false
	if not await applied_key(move_key, "forward", true): return false
	if not await applied_key(move_key, "forward", false): return false
	# IDs 23..28: synthetic OS focus changes exercise real automatic admission.
	await quick_pair(KEY_SPACE, "primary", "cancelled")
	before = desktop.state()
	desktop.focus_allowed = false
	transition("focus_lost", before)
	if not await bounded(Callable(self, "steps_completed").bind(before, 2), "focus cancellation physical steps"): return false
	event(move_key, "forward", true, "refused")
	event(move_key, "forward", false, "refused")
	before = desktop.state()
	desktop.focus_allowed = true
	if not await bounded(Callable(self, "controls_ready"), "focus regained neutral rearm"): return false
	transition("focus_regained", before)
	if not await applied_key(move_key, "forward", true): return false
	if not await applied_key(move_key, "forward", false): return false
	# IDs 29..40: pending edges cannot escape retirement into a reset owner.
	await quick_pair(KEY_SPACE, "primary", "cancelled")
	before = desktop.state()
	var old_session: WeakRef = weakref(desktop.physical_actor_session)
	control_key(KEY_R)
	transition("reset_requested", before)
	if not await bounded(Callable(self, "reset_installed").bind(desktop, rig,
		int(before.epoch), int(before.world_generation)), "ordinary accepted session reset"): return false
	transition("reset_completed", before, {"old_session_retired":old_session.get_ref() == null})
	event(move_key, "forward", true, "refused")
	event(move_key, "forward", false, "refused")
	control_key(KEY_P)
	if not await bounded(Callable(self, "controls_ready"), "reset owner neutral rearm"): return false
	if not await applied_key(move_key, "forward", true): return false
	if not await applied_key(move_key, "forward", false): return false
	if not await quick_pair(KEY_SPACE, "primary"): return false
	if not await quick_pair(KEY_SHIFT, "secondary"): return false
	if not await quick_pair(KEY_C, "auxiliary"): return false
	expect(event_id == 40, "exactly 40 individual input events executed")
	return failures == 0


func save_frame(label: String) -> Dictionary:
	var image: Image = root.get_texture().get_image()
	var directory: String = OS.get_environment("CYBERSAND_PACE004_CAPTURE")
	var path: String = directory.path_join(label + ".png")
	var saved: bool = image != null and not image.is_empty() and image.get_size() == root.size \
		and not directory.is_empty() and image.save_png(path) == OK
	expect(saved, "actual graphical frame saved: " + label)
	return {"file":label + ".png", "saved":saved, "sha256":FileAccess.get_sha256(path) if saved else "",
		"draw_count":desktop.draw_count, "time_usec":Time.get_ticks_usec()}


func visual_controls() -> bool:
	if DisplayServer.get_name() == "headless":
		captures = {"executed":false, "reason":"headless"}
		return true
	# Reconstruct at the authored spawn before visual controls: a legitimate
	# flight may otherwise have left the camera. No pose injection is used.
	var prior: Dictionary = desktop.state()
	control_key(KEY_R)
	if not await bounded(Callable(self, "reset_installed").bind(desktop, rig,
		int(prior.epoch), int(prior.world_generation)), "visual reset at authored spawn"): return false
	if not await observe_usec(100000, "paused authored presentation"): return false
	var overlay = desktop.physical_actor_overlay
	var parts: Array = desktop.physical_actor_session.render_parts()
	var polygons: Array[Dictionary] = []
	for part: Dictionary in parts:
		var vertices: Array = []
		for vertex: Vector2 in overlay.polygon(part):
			var global: Vector2 = overlay.get_global_transform() * vertex
			vertices.append([global.x, global.y])
		var color: Color = part.color.darkened(0.18)
		polygons.append({"vertices":vertices, "color":[color.r,color.g,color.b]})
	# Stop presentation updates only for bounded diagnostic layer-removal
	# controls AFTER actual gameplay. Normal RenderingServer drawing continues.
	desktop.set_process(false)
	var frames: Dictionary = {}
	if not await bounded(Callable(self, "draw_after").bind(desktop.draw_count + 2), "baseline actual draw"): return false
	frames["baseline"] = save_frame("baseline")
	if not await bounded(Callable(self, "draw_after").bind(desktop.draw_count + 2), "unchanged actual draw"): return false
	frames["unchanged"] = save_frame("unchanged")
	overlay.visible = false
	if not await bounded(Callable(self, "draw_after").bind(desktop.draw_count + 2), "actor removal actual draw"): return false
	frames["without_actor"] = save_frame("without_actor")
	overlay.visible = true
	var original_texture: Texture2D = desktop.world_view.texture
	var original_rect: Rect2 = desktop.world_view.get_global_rect()
	var removable: bool = original_texture != null and overlay.get_parent() == desktop.world_view \
		and overlay.is_visible_in_tree()
	expect(removable, "terrain control retains an actual texture and visible actor child")
	if not removable: return false
	# The production palette fragment writes COLOR, so self_modulate alpha does
	# not remove its draw. An empty TextureRect skips only its own draw command;
	# its actor-overlay child stays visible and EXPAND_IGNORE_SIZE keeps layout.
	desktop.world_view.texture = null
	var terrain_draw_ready: bool = await bounded(Callable(self, "draw_after").bind(desktop.draw_count + 2), "terrain removal actual draw")
	expect(desktop.world_view.texture == null and desktop.world_view.get_global_rect() == original_rect,
		"terrain removal clears only the texture without changing the world rect")
	expect(desktop.world_view.is_visible_in_tree() and overlay.get_parent() == desktop.world_view \
		and overlay.is_visible_in_tree(), "terrain removal preserves the visible actor child")
	if terrain_draw_ready:
		frames["without_terrain"] = save_frame("without_terrain")
	# Restore the identical resource even when the draw wait failed.
	desktop.world_view.texture = original_texture
	if not terrain_draw_ready: return false
	if not await bounded(Callable(self, "draw_after").bind(desktop.draw_count + 2), "restored actual draw"): return false
	expect(desktop.world_view.texture == original_texture and desktop.world_view.get_global_rect() == original_rect,
		"terrain restoration retains the exact texture resource and world rect")
	expect(overlay.get_parent() == desktop.world_view and overlay.is_visible_in_tree(),
		"terrain restoration preserves the visible actor child")
	frames["restored"] = save_frame("restored")
	var area: Rect2 = desktop.world_view.get_global_rect()
	captures = {"executed":true, "frames":frames, "actor_polygons":polygons,
		"world_rect":[area.position.x,area.position.y,area.size.x,area.size.y],
		"state":desktop.state(), "physics_pose_injected":false,
		"layer_removal_after_measurement":true, "width":root.size.x, "height":root.size.y}
	desktop.set_process(true)
	return failures == 0


func run() -> void:
	fixture_started = Time.get_ticks_usec()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rig="): rig = StringName(argument.trim_prefix("--rig="))
		elif argument.begins_with("--workers="): workers = argument.trim_prefix("--workers=").to_int()
		elif argument.begins_with("--policy="): policy_preset = argument.trim_prefix("--policy=").to_int()
		elif argument.begins_with("--workload="): workload_mode = argument.trim_prefix("--workload=")
		else: expect(false, "unknown fixture argument")
	expect(rig in Course.MECHANICAL_PRESETS and workers in [0,1] and policy_preset in [0,2],
		"registered rig/worker/policy combination")
	expect(workload_mode in ["none","brush_rain_v1","idle_control_v1"], "registered workload mode")
	if failures > 0:
		quit(1)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	desktop.workload_mode = workload_mode
	desktop.brush_load.mode = workload_mode
	root.add_child(desktop)
	await process_frame
	var worker: Probe = desktop.simulation_worker as Probe
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "actual exclusive production worker started")
	if worker == null:
		# No source-bound owner receipt exists, so this case cannot authorize
		# continuation. End promptly and preserve the failed startup log.
		desktop.queue_free()
		await process_frame
		quit(1)
		return
	var setup_started: int = Time.get_ticks_usec()
	if ready:
		var panel = desktop.playable_session_panel
		panel.show_selection()
		panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(rig))
		panel.control_choice.select(1)
		panel.rule_choice.select(0)
		panel.camera_choice.select(0)
		panel.policy_editor.select_preset(policy_preset)
		setup_started = Time.get_ticks_usec()
		desktop.setup_deadline_usec = setup_started + PacingPolicy.microseconds("main_ack_seconds")
		desktop.setup_predicate = Callable(self, "actor_ready").bind(desktop, rig)
		ready = panel.build_selected()
		expect(ready, "actual integrated selector admitted")
		if ready:
			ready = await wait_setup_acknowledgement(setup_started)
			expect(desktop.setup_ack_usec >= setup_started and desktop.setup_ack_usec <= desktop.setup_deadline_usec,
				"actual Main acknowledged within source-bound execution allowance")
	var setup: Dictionary = {"started_usec":setup_started, "acknowledged_usec":desktop.setup_ack_usec,
		"deadline_usec":desktop.setup_deadline_usec}
	var recipe: String = str(desktop.microscenario_definition.get("source_recipe_hash", ""))
	var policy: Dictionary = desktop.tower_context.get("liquid_solver_policy", {}).duplicate(true)
	var receipt: Dictionary = desktop.tower_context.get("liquid_construction_receipt", {}).duplicate(true)
	if ready:
		desktop.playable_session_panel.resume_play()
		ready = await bounded(Callable(self, "controls_ready"), "initial neutral input rearm")
	if ready and workload_mode != "none":
		# Main readiness can precede the first native unpaused publication. Begin
		# the opt-in load only after that actual acknowledgement, without paint
		# priming, manual stepping or a time-based warmup. Normal cases unchanged.
		ready = await bounded(Callable(self, "load_owner_running"), "initial loaded owner native progress")
	if ready:
		ready = await execute_tape()
	desktop.sampling = false
	desktop.brush_load.stop(desktop)
	var workload: Dictionary = desktop.brush_load.report()
	if workload_mode != "none":
		expect(workload.errors.is_empty(), "all bounded ordinary brush requests accounted for")
	worker.finish_measurement()
	worker.end_sample()
	desktop.capture_active = false
	if ready:
		ready = await visual_controls()
	var palette_identity: Dictionary = PaletteSelector.provenance(desktop.world_shader.shader)
	var trace: Array = desktop.trace.duplicate(true)
	var main_rows: Array = desktop.main_rows.duplicate(true)
	var draws: Array = desktop.draw_usec.duplicate()
	var overflow: bool = desktop.overflow
	var session = desktop.physical_actor_session
	var shutdown_started: int = Time.get_ticks_usec()
	await close_cycle(desktop, worker, session, "PACE004: ")
	var shutdown_usec: int = Time.get_ticks_usec() - shutdown_started
	var joined: bool = not worker._thread.is_started()
	expect(joined and shutdown_usec <= PacingPolicy.microseconds("operation_seconds"), "real worker join and retirement within operation watchdog")
	var native_rows: Array = []
	var publication_rows: Array = []
	if joined:
		# This is the first Main read of owner-written rows. Join transfers their
		# lifetime; only the one production owner queried native statistics.
		for row: Dictionary in worker.native_rows:
			if int(row.completed_usec) >= int(measurement.get("started_usec", 0)) \
				and int(row.completed_usec) < int(measurement.get("ended_usec", 0)):
				native_rows.append(row.duplicate(true))
		for row: Dictionary in worker.capture_buffer.publications:
			if int(row.epoch) == int(measurement.get("initial", {}).get("epoch", -1)) \
				and int(row.generation) == int(measurement.get("initial", {}).get("world_generation", -1)):
				publication_rows.append(row.duplicate(true))
	var result: Dictionary = {"schema":"play-pace004-v2", "source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"execution_policy":PacingPolicy.identity(), "palette_shader":palette_identity,
		"publication_retention":worker.capture_buffer.report() if joined else {},
		"process_nonce":OS.get_environment("CYBERSAND_PACE004_PROCESS_NONCE"), "process_id":OS.get_process_id(),
		"fixture_sha256":FileAccess.get_sha256("res://tests/play_pace004_input_tape.gd"),
		"probe_sha256":FileAccess.get_sha256("res://tests/play_pace004_worker_probe.gd"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"rig":str(rig), "workers_requested":workers, "policy_preset":policy_preset,
		"platform":OS.get_name(), "cpu_name":OS.get_processor_name(), "logical_processors":OS.get_processor_count(),
		"display_server":DisplayServer.get_name(), "physics_engine":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"video_adapter":RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "headless",
		"rendering_method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"rendering_driver":str(RenderingServer.call("get_current_rendering_driver_name")) \
			if RenderingServer.has_method("get_current_rendering_driver_name") else "unavailable",
		"godot":Engine.get_version_info(), "recipe_hash":recipe, "policy":policy, "receipt":receipt,
		"setup":setup, "measurement":measurement, "waits":waits, "trace":trace,
		"main_rows":main_rows, "draw_usec":draws, "native_rows":native_rows, "publication_rows":publication_rows,
		"workload":workload,
		"snapshot_mutex_wait_usec":worker.mutex_acquire_wait_usec.duplicate(),
		"snapshot_mutex_critical_usec":worker.mutex_critical_section_usec.duplicate(),
		"snapshot_returns_new":worker.returned_new_snapshots, "snapshot_returns_none":worker.returned_no_new_snapshot,
		"visual":captures, "capture_overflow":overflow, "native_overflow":worker.native_overflow,
		"worker_joined":joined, "sessions_retired":retired_sessions, "shutdown_usec":shutdown_usec,
		"stop_join_usec":worker.stop_join_usec, "events":event_id, "assertions":assertions, "failures":failures,
		"completed":ready and failures == 0, "elapsed_usec":Time.get_ticks_usec()-fixture_started,
		"scope":{"real_host":true, "automatic_callbacks":true, "synthetic_focus":true,
			"physical_devices":false, "human_feel":false, "scanout_fps":false,
			"manual_physics_calls":0, "pose_injection":false, "retries":0,
			"native_samples_read_after_join":true, "test_only_observer":true,
			"input_tape":"40 individual key events; analogue holds and FIFO button edges",
			"main_wait":"snapshot mutex only; other locks unmeasured",
			"participation":"maximum distinct task-claiming workers per native dispatch; not utilization"}}
	print("PLAY_PACE004_RESULT ", JSON.stringify(result))
	quit(0 if ready and failures == 0 else 1)
