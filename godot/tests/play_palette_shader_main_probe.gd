extends "res://tests/play_life001_shared_host_case.gd"

# Two actual sequential Main lifetimes exercise shared ShaderMaterial/resource
# reuse. Separate cold/warm processes are orchestrated outside this fixture.
const Policy = preload("res://tests/support/ci_execution_policy.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const Selector = preload("res://scripts/palette_shader_selector.gd")
const RIG: StringName = &"acrobat"
var fixture_started: int = 0
var submitted_frames: int = 0
var lifetimes: Array[Dictionary] = []
var selected_resource: Shader
var waits: Array[Dictionary] = []

class FocusMain:
	extends "res://scripts/main.gd"
	func _actor_window_has_focus() -> bool:
		return true

func _frame_submitted() -> void:
	submitted_frames += 1

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PALETTE_MAIN_PROBE: " + message)

func bounded(predicate: Callable, label: String, started: int, allowance: int) -> bool:
	var deadline: int = mini(started+allowance, fixture_started+Policy.microseconds("complex_fixture_seconds"))
	var passed: bool = false
	while Time.get_ticks_usec() <= deadline:
		if predicate.call():
			passed = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	waits.append({"label":label, "started_usec":started, "deadline_usec":deadline,
		"ended_usec":Time.get_ticks_usec(), "allowance_usec":allowance, "passed":passed})
	expect(passed, label)
	return passed

func one_lifetime(index: int) -> bool:
	var started: int = Time.get_ticks_usec()
	print("PALETTE_MAIN_STAGE ", JSON.stringify({"lifetime":index,"stage":"construct_requested","usec":started}))
	release_controls()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(FocusMain)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "actual exclusive Main worker started")
	if not ready:
		await close_cycle(desktop,worker,null,"shader startup: ")
		return false
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(RIG))
	panel.control_choice.select(1)
	panel.rule_choice.select(0)
	panel.camera_choice.select(0)
	panel.policy_editor.select_preset(0)
	ready = panel.build_selected()
	expect(ready,"actual integrated Play selector admitted")
	if ready:
		ready = await bounded(Callable(self,"actor_ready").bind(desktop,RIG),
			"Main construction acknowledgement",started,Policy.microseconds("main_ack_seconds"))
	var acknowledged: int = Time.get_ticks_usec()
	var entry: Dictionary = {"index":index,"started_usec":started,"acknowledged_usec":acknowledged,
		"main_ack_seconds":float(acknowledged-started)/1000000.0,"worker_id":worker.get_instance_id(),
		"ready":ready,"cache_state":OS.get_environment("CYBERSAND_SHADER_CACHE_STATE")}
	if ready:
		var initial_native: int = desktop.latest_snapshot.tick_index
		var initial_rapier: int = desktop.physical_actor_session.tick
		panel.resume_play()
		ready = await bounded(Callable(self,"clocks_advanced").bind(desktop,RIG,initial_rapier,initial_native),
			"automatic native and Rapier progress",Time.get_ticks_usec(),Policy.microseconds("operation_seconds"))
		entry["initial_native_tick"] = initial_native
		entry["initial_rapier_tick"] = initial_rapier
		entry["native_tick"] = desktop.latest_snapshot.tick_index
		entry["rapier_tick"] = desktop.physical_actor_session.tick
		entry["world_generation"] = desktop.latest_snapshot.render_world_generation
		entry["epoch"] = desktop.latest_snapshot.rigid_body_epoch
		entry["session_id"] = desktop.physical_actor_session.get_instance_id()
		entry["camera_origin"] = [desktop.camera_origin.x,desktop.camera_origin.y]
		entry["shader"] = Selector.provenance(desktop.world_shader.shader)
		entry["shader_instance_id"] = desktop.world_shader.shader.get_instance_id()
		entry["bounded_define_count"] = desktop.world_shader.shader.code.count(Selector.BOUNDED_CROSSFADE_DEFINE)
		entry["world_surface_visible"] = desktop.world_view.is_visible_in_tree()
		entry["world_material_bound"] = desktop.world_view.material == desktop.world_shader
		entry["world_texture_bound"] = (desktop.world_view.texture != null
			and desktop.world_shader.get_shader_parameter("current_world_texture") == desktop.world_view.texture)
		expect(entry.world_surface_visible and entry.world_material_bound and entry.world_texture_bound,
			"the actual visible World surface binds the selected shader and current texture")
		var angle: bool = RenderingServer.get_current_rendering_driver_name() == "opengl3_angle"
		expect(entry.shader.source_bound and entry.shader.source_file_bound,
			"actual Main material retains original source custody")
		expect(entry.shader.variant == ("angle_bounded_crossfade" if angle else "full_crossfade"),
			"actual backend selected its registered variant")
		expect(desktop.world_shader.shader.code.count(Selector.BOUNDED_CROSSFADE_DEFINE) == (1 if angle else 0),
			"Main recreation accumulated or lost its bounded define")
		if selected_resource == null:
			selected_resource = desktop.world_shader.shader
		else:
			expect(selected_resource == desktop.world_shader.shader,
				"Main recreation did not reuse the source-bound cached shader resource")
		var before_draw: int = submitted_frames
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var readback: Image = root.get_texture().get_image()
		entry["readback_usec"] = Time.get_ticks_usec()
		entry["frames_after_ready"] = submitted_frames-before_draw
		entry["capture"] = Context.capture(readback,"main_%d" % index)
		expect(entry.frames_after_ready >= 2 and readback.get_width() > 0 and readback.get_height() > 0,
			"Main did not complete actual graphical readback")
		expect(not entry.capture.is_empty() and not entry.capture.has("error"),"Main image custody")
	var session = desktop.physical_actor_session
	var shutdown_started: int = Time.get_ticks_usec()
	await close_cycle(desktop,worker,session,"shader Main: ")
	entry["shutdown_usec"] = Time.get_ticks_usec()-shutdown_started
	entry["retired_usec"] = Time.get_ticks_usec()
	entry["worker_joined"] = not worker._thread.is_started()
	entry["session_retired"] = session == null or not is_instance_valid(session)
	expect(entry.shutdown_usec <= Policy.microseconds("operation_seconds"),"Main retirement operation allowance")
	lifetimes.append(entry)
	print("PALETTE_MAIN_STAGE ",JSON.stringify({"lifetime":index,"stage":"retired","usec":Time.get_ticks_usec()}))
	return ready and entry.worker_joined and entry.session_retired

func run() -> void:
	fixture_started = Time.get_ticks_usec()
	Context.emit(get_script().resource_path)
	if DisplayServer.get_name() == "headless":
		expect(false,"actual graphical backend required")
		quit(1)
		return
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	RenderingServer.frame_post_draw.connect(_frame_submitted)
	for index: int in range(2):
		if not await one_lifetime(index): break
	var fixture_finished: int = Time.get_ticks_usec()
	var record: Dictionary = {"schema":"palette-main-recreation-v1", "context":Context.identity(get_script().resource_path),
		"assertions":assertions,"failures":failures,"lifetimes":lifetimes,"waits":waits,
		"joined_workers":joined_workers,"retired_sessions":retired_sessions,"submitted_frames":submitted_frames,
		"fixture_started_usec":fixture_started,"fixture_finished_usec":fixture_finished,
		"elapsed_usec":fixture_finished-fixture_started,"rig":str(RIG),"workers_requested":1,
		"scope":"actual sequential Main/native/Rapier and rendered readback; synthetic focus; no physical-device or timing acceptance"}
	print("PALETTE_MAIN_PROBE_RESULT ",JSON.stringify(record))
	quit(0 if failures == 0 and lifetimes.size() == 2 else 1)
