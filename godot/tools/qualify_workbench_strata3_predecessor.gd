extends "res://tools/qualify_workbench_strata2.gd"

## The same external diagnostic overlay runs against untouched Strata 002 and
## Strata 003. Only existing ordinary-host hooks are observed; no old production
## source is edited or replaced. The driver is hashed and retained separately.
const SAMPLE_CALLBACKS := 90
const SAMPLE_WATCHDOG_USEC := 90000000

class ComparisonHost extends RouteHost:
	var observing := false
	var completions: Array[Dictionary] = []
	var publications: Array[Dictionary] = []
	var last_native_tick := -1
	var observer_overflow := false
	func _record_completed_playable_course_step() -> void:
		super._record_completed_playable_course_step()
		if not observing or physical_actor_session == null: return
		if completions.size() >= 8192:
			observer_overflow = true
			return
		completions.append({"completed_usec":Time.get_ticks_usec(),"rapier_tick":int(physical_actor_session.tick)})
	func _process(delta: float) -> void:
		super._process(delta)
		if not observing or latest_snapshot == null or int(latest_snapshot.tick_index) == last_native_tick: return
		if publications.size() >= 8192:
			observer_overflow = true
			return
		last_native_tick = int(latest_snapshot.tick_index)
		publications.append({"observed_usec":Time.get_ticks_usec(),"native_tick":int(latest_snapshot.tick_index),
			"published_usec":int(latest_snapshot.published_usec),"serial":int(latest_snapshot.serial),
			"world_revision":int(latest_snapshot.simulation_world_revision),"render_revision":int(latest_snapshot.world_revision),
			"worker_step_ms":float(latest_snapshot.worker_step_time_ms)})


func _pose() -> Dictionary:
	var value: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	return {"position":[value.position.x,value.position.y],"rotation":float(value.rotation),
		"linear_velocity":[value.linear_velocity.x,value.linear_velocity.y],"angular_velocity":float(value.angular_velocity)}


func _camera() -> Dictionary:
	return {"origin":[host.camera_origin.x,host.camera_origin.y],"view_size":[host.current_view_size.x,host.current_view_size.y],
		"world_rect":_world_pixel_rect(),"window_size":[root.size.x,root.size.y],"content_scale_factor":root.content_scale_factor}


func run() -> void:
	scene_id = OS.get_environment("STRATA_SCENE")
	phase = "predecessor-comparison"
	output = OS.get_environment("STRATA_EVIDENCE")
	var role := OS.get_environment("STRATA3_COMPARISON_ROLE")
	diagnostic_headless = DisplayServer.get_name() == "headless" and OS.get_environment("STRATA3_DIAGNOSTIC_HEADLESS") == "1"
	record = {"schema":"strata3-predecessor-observation-v1","scene":scene_id,"phase":phase,"role":role,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"driver_sha256":OS.get_environment("STRATA3_DRIVER_SHA256"),
		"completed":false,"process_id":OS.get_process_id(),"display_server":DisplayServer.get_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"rendering_adapter":RenderingServer.get_video_adapter_name(),
		"diagnostic_headless":diagnostic_headless,"admission_target_ms":45000}
	if not check(role in ["predecessor","candidate"] and scene_id in Showcase.IDS and not output.is_empty(),"explicit paired source/scene identities") \
		or not check(DisplayServer.get_name() != "headless" or diagnostic_headless,"paired graphical observation requires a display"):
		finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(ComparisonHost)
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	var began := Time.get_ticks_msec()
	if not await until(idle,"paired ordinary Workbench bootstrap",180000): finish(); return
	record.bootstrap_elapsed_ms = Time.get_ticks_msec()-began
	check(wb.strata == null,"paired ordinary default-OFF startup")
	record.ordinary_workbench = wb.get_script().resource_path == "res://scripts/shared_workbench.gd"
	strata = wb.ensure_strata()
	var admission := Time.get_ticks_msec()
	if not check(strata.load_demo(scene_id),"paired original unchanged native environment"): finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,"paired four-plane admission",180000): finish(); return
	record.admission_elapsed_ms = Time.get_ticks_msec()-admission
	record.admission_target_met = int(record.admission_elapsed_ms) <= 45000
	check(host.paused,"fresh paired native scene is paused")
	record.world_count = {"play_borrowed":1,"decorative_owned":int(strata.layer_owner.stats().native_world_count)}
	check(record.world_count.decorative_owned == 3 and not strata.layer_owner.stats().owns_play_world,"paired plane ownership unchanged")
	if role == "candidate":
		if not check(strata.has_method("reset_optics"),"candidate optical control exists"): finish(); return
		check(strata.reset_optics(),"candidate exact Classic selected")
		check(not bool(strata.optics_state().configuration.enabled),"candidate optical processing disabled")
		record.optical_configuration = strata.optics_state().configuration
	else:
		check(not strata.has_method("optics_state"),"predecessor production adapter remains original")
	check(strata.set_atmosphere_settings({"paused":true}),"same paused atmosphere observer configuration")
	host.world_shader.set_shader_parameter("presentation_time_override",0.0)
	if host.glow_source_shader != null: host.glow_source_shader.set_shader_parameter("presentation_time_override",0.0)
	wb.set_camera(2)
	await settle()
	record.initial_plane_native_hashes = await all_native_hashes()
	record.initial_native_hashes_canonical_json = JSON.stringify(record.initial_plane_native_hashes,"",true,true)
	record.initial_actor = _pose()
	record.camera = _camera()
	record.extent = [Setup.extent_of(wb.applied).x,Setup.extent_of(wb.applied).y]
	if not diagnostic_headless:
		var frame: Image = await capture("classic-initial")
		var bounds: Array = _world_pixel_rect()
		var area := Rect2i(int(bounds[0]),int(bounds[1]),int(bounds[2]),int(bounds[3])).intersection(Rect2i(Vector2i.ZERO,frame.get_size()))
		var crop := frame.get_region(area)
		crop.convert(Image.FORMAT_RGBA8)
		check(crop.save_png(output.path_join("classic-world.png")) == OK,"actual paired unresampled world crop retained")
		record.classic_pixels = {"filename":"classic-world.png","sha256":FileAccess.get_sha256(output.path_join("classic-world.png")),
			"rgba8_sha256":digest(crop.get_data()),"size":[crop.get_width(),crop.get_height()],"scope":"Frozen actual Classic world-view pixels; no resampling."}
	# Only display work is warmed. Native state and actor pose remain pristine.
	for _index: int in 6: await process_frame
	var captures_before: int = strata.layer_owner.stats().native_snapshot_calls
	var uploads_before: int = strata.presenter.diagnostics().full_rg8_uploads
	var actor: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	var start_position: Vector2 = actor.position
	var before := play_identity()
	check(_pose() == record.initial_actor,"paused optical warmup preserves physical initial state")
	host.completions.clear()
	host.publications.clear()
	host.last_native_tick = -1
	host.observing = true
	var start_usec := Time.get_ticks_usec()
	var previous := start_usec
	var callbacks: Array[int] = []
	var process_ms: Array[float] = []
	host.qualification_action = _route_action(actor,Vector2.RIGHT,start_position)
	check(wb.toggle_pause(),"paired ordinary real physical progression starts")
	for _index: int in SAMPLE_CALLBACKS:
		await process_frame
		var now := Time.get_ticks_usec()
		callbacks.append(now-previous)
		previous = now
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
		var state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
		host.qualification_action = _route_action(state,Vector2.RIGHT,start_position)
		if now-start_usec > SAMPLE_WATCHDOG_USEC: break
	host.observing = false
	var elapsed := Time.get_ticks_usec()-start_usec
	var after := play_identity()
	var last_pose := _pose()
	host.qualification_action = {}
	check(wb.toggle_pause(),"paired physical observation pauses")
	await until(idle,"paired physical pause settles")
	stable_identity(before,play_identity(),"paired actual physical progression")
	var completed: Array = host.completions.duplicate(true)
	var publications: Array = host.publications.duplicate(true)
	check(callbacks.size() == SAMPLE_CALLBACKS,"complete paired display observation population")
	check(completed.size() >= 2 and completed.size() == int(after.rapier_tick)-int(before.rapier_tick),"all actual completed physical steps retained")
	for index: int in completed.size(): check(int(completed[index].rapier_tick) == int(before.rapier_tick)+index+1,"paired completed physical sequence has no gaps")
	check(not host.observer_overflow and not publications.is_empty(),"bounded native-publication observer complete")
	check(int(after.native_tick) > int(before.native_tick),"paired actual native progression")
	var distance: float = start_position.distance_to(Vector2(last_pose.position[0],last_pose.position[1]))
	check(distance > 0.01,"paired actual actor position progresses")
	check(strata.layer_owner.stats().native_snapshot_calls == captures_before,"paired timed window takes no decorative native captures")
	check(strata.presenter.diagnostics().full_rg8_uploads == uploads_before,"paired timed window takes no decorative texture uploads")
	var intervals: Array[int] = []
	for index: int in range(1,completed.size()): intervals.append(int(completed[index].completed_usec)-int(completed[index-1].completed_usec))
	record.sample = {"before":before,"after":after,"elapsed_usec":elapsed,"callbacks":callbacks.size(),
		"callback_intervals_usec":callbacks,"main_process_ms":process_ms,
		"completed_physical_steps":completed,"physical_intervals_usec":intervals,"native_publications":publications,
		"native_ticks_per_second":float(int(after.native_tick)-int(before.native_tick))*1000000.0/maxi(1,elapsed),
		"rapier_ticks_per_second":float(int(after.rapier_tick)-int(before.rapier_tick))*1000000.0/maxi(1,elapsed),
		"actor_before":record.initial_actor,"actor_after":last_pose,"actor_distance_cells":distance,
		"native_capture_delta":strata.layer_owner.stats().native_snapshot_calls-captures_before,
		"decorative_upload_delta":strata.presenter.diagnostics().full_rg8_uploads-uploads_before,
		"godot_tracked_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"resource_count":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))}
	record.optical_statistics = strata.presenter.optics_statistics() if role == "candidate" else {"original_presenter":true,"optical_api_present":false}
	record.observer_contract = {"physical":"Existing hook immediately after real Rapier complete_step; every completed step checked.",
		"native":"Already published immutable snapshots observed after ordinary Main processing; native ticks may coalesce, not a claim of individual native completion intervals.",
		"image_readbacks_during_sample":0,"extra_native_ticks":0,"extra_worlds":0,
		"warmup":"Six display callbacks while physically paused; same exact initial native material hashes and actor pose.",
		"physical_gpu_acceptance":false}
	finish()
