extends "res://tools/qualify_workbench_strata3.gd"

## External observation only. The application project is the immutable
## fd0830ab checkout. This script is never copied into that project.
const SUSTAINED_PROFILES := ["classic", "architectural", "gameplay_clarity", "cinematic_deep_focus"]
const WINDOW_COUNT := 12
const WINDOW_USEC := 25000000
const SLIDER_OFFSETS_USEC := [2000000, 6000000, 10000000, 14000000, 18000000, 22000000]
const CAMERA_OFFSETS_USEC := [0, 5000000, 10000000, 15000000, 20000000]
const OBSERVER_CAP := 8192

var _live_ui: Node
var _tonal_slider: HSlider
var _tonal_callback: Callable
var _sustained_timing := false
var _active_window: Dictionary = {}
var _pending_draws: Array[Dictionary] = []
var _retained_step_count := 0


func _slider_visibility() -> Dictionary:
	var slider_rect := _tonal_slider.get_global_rect()
	var viewport_rect: Rect2 = _live_ui._page.get_global_rect()
	return {"slider_rect":[slider_rect.position.x,slider_rect.position.y,slider_rect.size.x,slider_rect.size.y],
		"viewport_rect":[viewport_rect.position.x,viewport_rect.position.y,viewport_rect.size.x,viewport_rect.size.y],
		"window_visible":bool(strata._window.visible),"slider_visible":_tonal_slider.is_visible_in_tree(),
		"fully_enclosed":viewport_rect.encloses(slider_rect),"scroll_vertical":int(_live_ui._page.scroll_vertical)}


func _slider_is_visible() -> bool:
	var state := _slider_visibility()
	return bool(state.window_visible) and bool(state.slider_visible) and bool(state.fully_enclosed)


func _resource_state() -> Dictionary:
	return {"tracked_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"resource_count":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"node_count":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count":int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"observer_retained_completed_steps":_retained_step_count,
		"optics":strata.presenter.optics_statistics()}


func _observe_tonal_callback(value: float) -> void:
	# The original live UI Callable is invoked exactly once. Instrumentation
	# surrounds its synchronous authored-state mutation; it does not replace it.
	var began := Time.get_ticks_usec()
	_tonal_callback.call(value)
	var authored := float(_configuration().tonal)
	var ended := Time.get_ticks_usec()
	if not _sustained_timing: return
	var response := {"requested":value,"authored":authored,"callback_entry_usec":began,
		"authored_observed_usec":ended,"callback_to_authored_usec":ended-began,
		"original_callback_invocations":1,"draw_completed_usec":0,"callback_to_next_completed_draw_usec":0,
		"native_edit_target":str(strata.active_layer()),"physical_paused":host.paused,
		"callback_visibility":_slider_visibility()}
	_active_window.slider_responses.append(response)
	if not diagnostic_headless: _pending_draws.append(response)


func _observe_completed_draw() -> void:
	if not _sustained_timing or _pending_draws.is_empty(): return
	var completed := Time.get_ticks_usec()
	for response: Dictionary in _pending_draws:
		response.draw_completed_usec = completed
		response.callback_to_next_completed_draw_usec = completed-int(response.callback_entry_usec)
		response.draw_visibility = _slider_visibility()
	_pending_draws.clear()


func _mount_live_controls() -> bool:
	strata.open_panel()
	var panel: PanelContainer = strata._panel
	_live_ui = panel.find_child("StrataOpticsLab",true,false)
	if not check(_live_ui != null,"sustained ordinary Optics Lab exists"): return false
	var found := false
	for index: int in panel._tabs.get_tab_count():
		if panel._tabs.get_tab_title(index) == "Optics":
			panel._tabs.current_tab = index
			found = true
	if not check(found,"sustained ordinary Optics tab selected"): return false
	await settle()
	_tonal_slider = _live_ui._global_controls.tonal.slider
	# Visibility in the scene tree alone does not mean the row is inside the
	# scroll viewport. Center the real control, leaving room for profile text
	# reflow. Both ordinary widget layout and the screenshot settle before time.
	_live_ui._page.ensure_control_visible(_tonal_slider)
	await settle()
	_live_ui._page.scroll_vertical += int(_tonal_slider.get_global_rect().get_center().y - _live_ui._page.get_global_rect().get_center().y)
	await settle()
	record.live_ui_before = _slider_visibility()
	if not check(_slider_is_visible(),"actual tonal control enclosed by its visible scroll viewport"): return false
	if not diagnostic_headless:
		var frame: Image = strata._window.get_texture().get_image()
		if not check(frame != null and not frame.is_empty() and frame.save_png(output.path_join("sustained-optics-lab.png")) == OK,"actual visible tonal-slider window captured before timing"): return false
		record.lab_capture = {"filename":"sustained-optics-lab.png","sha256":FileAccess.get_sha256(output.path_join("sustained-optics-lab.png")),
			"actual_image_size":[frame.get_width(),frame.get_height()],"captured_usec":Time.get_ticks_usec(),
			"outside_timed_windows":true,"visibility":record.live_ui_before}
	var connections := _tonal_slider.value_changed.get_connections()
	if not check(connections.size() == 1 and int(connections[0].flags) == 0,
		"instrument exactly the one original synchronous tonal-slider callback"): return false
	_tonal_callback = connections[0].callable
	_tonal_slider.value_changed.disconnect(_tonal_callback)
	_tonal_slider.value_changed.connect(_observe_tonal_callback)
	RenderingServer.frame_post_draw.connect(_observe_completed_draw)
	return check(_tonal_slider.is_visible_in_tree(),"live tonal slider remains visible during observation")


func _restore_live_controls() -> void:
	if is_instance_valid(_tonal_slider) and _tonal_callback.is_valid():
		if _tonal_slider.value_changed.is_connected(_observe_tonal_callback):
			_tonal_slider.value_changed.disconnect(_observe_tonal_callback)
		_tonal_slider.value_changed.connect(_tonal_callback)
	if RenderingServer.frame_post_draw.is_connected(_observe_completed_draw):
		RenderingServer.frame_post_draw.disconnect(_observe_completed_draw)


func _pan_zoom(window_index: int, event_index: int, state: Dictionary) -> void:
	var size := Vector2i(240,135) if (window_index+event_index)%2 == 0 else Vector2i(480,270)
	var center: Vector2 = state.position + Vector2(-18.0 if event_index%2 == 0 else 18.0,-12.0)
	wb._set_view(center-Vector2(size)*0.5,size)
	var mapped: Vector2 = strata.presenter.layer_to_screen(state.position,"play")
	var picked: Vector2 = strata.presenter.screen_to_layer(mapped,"play")
	_active_window.camera_events.append({"observed_usec":Time.get_ticks_usec(),"camera":_camera_state(),
		"actor_state":_actor_state(),"picking_error":picked.distance_to(state.position),"ordinary_set_view":true,
		"submitted_action":{"move":[host.qualification_action.move.x,host.qualification_action.move.y],
			"primary":bool(host.qualification_action.primary),"effort":float(host.qualification_action.effort)}})


func _retained_capture(name: String) -> void:
	if diagnostic_headless: return
	var frame: Image = await capture(name)
	record.captures.append({"filename":name+".png","sha256":FileAccess.get_sha256(output.path_join(name+".png")),
		"actual_image_size":[frame.get_width(),frame.get_height()],"camera":_camera_state(),"actor_state":_actor_state(),
		"configuration":_configuration(),"captured_usec":Time.get_ticks_usec(),"outside_timed_windows":true})


func _run_uninterrupted() -> void:
	var capture_before: int = strata.layer_owner.stats().native_snapshot_calls
	var upload_before: int = strata.presenter.diagnostics().full_rg8_uploads
	var owner_before := play_identity()
	var decorative_before := _decorative_identity()
	var actor: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	var altitude_hold: Vector2 = actor.position
	host.optics_observe = true
	host.optics_observer_overflow = false
	_sustained_timing = true
	var session_start := Time.get_ticks_usec()
	var boundary := session_start
	record.session_started_unix_seconds = Time.get_unix_time_from_system()
	record.windows = []
	check(wb.toggle_pause(),"start one uninterrupted native play session")
	for index: int in WINDOW_COUNT:
		# No await, pause, scene install or native readback occurs at boundaries.
		# Completed-step capture remains enabled while bounded arrays are cleared.
		host.optics_completed.clear()
		host.optics_publications.clear()
		host.optics_last_native_tick = -1
		host.optics_observer_overflow = false
		var before := play_identity()
		var initial_actor := _actor_state()
		var initial_resources := _resource_state()
		var selected: String = SUSTAINED_PROFILES[index%SUSTAINED_PROFILES.size()]
		_active_window = {"index":index,"selected_profile":selected,"quality":"balanced","start_usec":boundary,
			"before":before,"actor_before":initial_actor,"resources_before":initial_resources,
			"slider_responses":[],"camera_events":[],"callbacks":[],"paused_callbacks":0,
			"slider_visibility_checks":0,"slider_visibility_failures":0}
		var profile_began := Time.get_ticks_usec()
		check(strata.select_optics_profile(selected),"sustained ordinary live profile "+selected)
		_active_window.profile_callback_usec = Time.get_ticks_usec()-profile_began
		_active_window.configuration_before = _configuration()
		_active_window.configuration_before_json = _canonical(_active_window.configuration_before)
		_active_window.configuration_before_sha256 = str(_active_window.configuration_before_json).sha256_text()
		var slider_event := 0
		var camera_event := 0
		var previous_callback := boundary
		while Time.get_ticks_usec()-boundary < WINDOW_USEC:
			var now := Time.get_ticks_usec()
			actor = host.physical_actor_session.workbench_actor_state(wb.selected_id())
			var direction := Vector2.RIGHT if index%2 == 0 else Vector2.LEFT
			if actor.position.x < 180.0: direction = Vector2.RIGHT
			elif actor.position.x > 820.0: direction = Vector2.LEFT
			host.qualification_action = _route_action(actor,direction,altitude_hold)
			if camera_event < CAMERA_OFFSETS_USEC.size() and now-boundary >= CAMERA_OFFSETS_USEC[camera_event]:
				_pan_zoom(index,camera_event,actor)
				camera_event += 1
			if slider_event < SLIDER_OFFSETS_USEC.size() and now-boundary >= SLIDER_OFFSETS_USEC[slider_event]:
				# Assign the actual visible HSlider; its original callback performs
				# the ordinary authored edit. Alternating values always emit a change.
				_tonal_slider.value = 0.31 if slider_event%2 == 0 else 0.67
				slider_event += 1
			await process_frame
			now = Time.get_ticks_usec()
			if _active_window.callbacks.size() >= OBSERVER_CAP:
				check(false,"bounded sustained callback population overflow")
				break
			_active_window.callbacks.append({"observed_usec":now,"interval_usec":now-previous_callback,
				"process_ms":float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0})
			previous_callback = now
			if host.paused: _active_window.paused_callbacks += 1
			_active_window.slider_visibility_checks += 1
			if not _slider_is_visible(): _active_window.slider_visibility_failures += 1
		var ended := Time.get_ticks_usec()
		var after := play_identity()
		var completed: Array = host.optics_completed.duplicate(true)
		var publications: Array = host.optics_publications.duplicate(true)
		var intervals: Array[int] = []
		for offset: int in range(1,completed.size()):
			intervals.append(int(completed[offset].completed_usec)-int(completed[offset-1].completed_usec))
		check(completed.size() >= 2 and completed.size() == int(after.rapier_tick)-int(before.rapier_tick),"sustained complete actual physical population "+str(index))
		for offset: int in completed.size():
			check(int(completed[offset].rapier_tick) == int(before.rapier_tick)+offset+1,"sustained actual completed-step order")
		check(not host.optics_observer_overflow and not publications.is_empty(),"bounded sustained native-publication observer")
		check(_pending_draws.is_empty(),"all live-slider completed draws observed within window")
		check(_active_window.paused_callbacks == 0 and not host.paused,"native play was uninterrupted")
		check(_active_window.slider_visibility_failures == 0,"live tonal control stays in viewport through profile changes")
		stable_identity(owner_before,after,"sustained native owner "+str(index))
		check(decorative_before == _decorative_identity(),"sustained static decorative owners and revisions")
		check(strata.layer_owner.stats().native_snapshot_calls == capture_before and strata.presenter.diagnostics().full_rg8_uploads == upload_before,"sustained optics recapture/upload isolation")
		_retained_step_count += completed.size()
		_active_window.merge({"end_usec":ended,"elapsed_usec":ended-boundary,"after":after,
			"decorative_identity":_decorative_identity(),
			"completed_physical_steps":completed,"physical_intervals_usec":intervals,
			"native_publications":publications,"actor_after":_actor_state(),"resources_after":_resource_state(),
			"configuration_after":_configuration(),"configuration_after_json":_canonical(_configuration()),
			"configuration_after_sha256":_canonical(_configuration()).sha256_text(),
			"native_capture_delta":strata.layer_owner.stats().native_snapshot_calls-capture_before,
			"decorative_upload_delta":strata.presenter.diagnostics().full_rg8_uploads-upload_before,
			"observer_overflow":host.optics_observer_overflow,"native_edit_target":str(strata.active_layer())})
		record.windows.append(_active_window)
		boundary = ended
		print("STRATA3_SUSTAINED_WINDOW ",JSON.stringify({"index":index,"profile":selected,"elapsed_usec":_active_window.elapsed_usec,"completed_steps":completed.size(),"native_ticks":int(after.native_tick)-int(before.native_tick)}))
	# The observation ends at the final boundary. Pause and readbacks are outside
	# all twelve windows and have separate final owner witnesses.
	_sustained_timing = false
	host.optics_observe = false
	host.qualification_action = {}
	record.session = {"start_usec":session_start,"end_usec":boundary,"elapsed_usec":boundary-session_start,
		"before":owner_before,"after":play_identity(),"decorative_before":decorative_before,"decorative_after":_decorative_identity(),
		"native_capture_delta":strata.layer_owner.stats().native_snapshot_calls-capture_before,
		"decorative_upload_delta":strata.presenter.diagnostics().full_rg8_uploads-upload_before,
		"completed_step_count":_retained_step_count,"native_edit_target":str(strata.active_layer())}
	check(wb.toggle_pause(),"pause only after complete five-minute observation")
	await until(idle,"final sustained pause settles")
	record.owner_after_pause = play_identity()
	stable_identity(owner_before,record.owner_after_pause,"sustained final pause retains owners")


func run() -> void:
	scene_id = "optics-readability-challenge"
	phase = "sustained-session"
	output = OS.get_environment("STRATA_EVIDENCE")
	diagnostic_headless = DisplayServer.get_name() == "headless" and OS.get_environment("STRATA3_DIAGNOSTIC_HEADLESS") == "1"
	record = {"schema":"strata3-sustained-observation-v2","scene":scene_id,"phase":phase,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"observer_sha256":OS.get_environment("STRATA3_DRIVER_SHA256"),
		"observer_source_revision":OS.get_environment("STRATA3_OBSERVER_SOURCE_REVISION"),"completed":false,
		"process_id":OS.get_process_id(),"display_server":DisplayServer.get_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"rendering_adapter":RenderingServer.get_video_adapter_name(),
		"diagnostic_headless":diagnostic_headless,"admission_target_ms":45000,"captures":[],
		"registration":{"window_count":WINDOW_COUNT,"window_usec":WINDOW_USEC,"total_minimum_usec":WINDOW_COUNT*WINDOW_USEC,
			"profiles":SUSTAINED_PROFILES,"quality":"balanced","slider_offsets_usec":SLIDER_OFFSETS_USEC,
			"camera_offsets_usec":CAMERA_OFFSETS_USEC,"per_window_observer_cap":OBSERVER_CAP,
			"resource_and_node_range_bound_after_first_cycle":16,
			"image_readbacks_during_windows":0,"native_material_readbacks_during_windows":0,
			"geometry_resets_during_windows":0,"pose_injections":0,"extra_native_turns":0,"extra_worlds":0,
			"scope":"One five-minute hosted session; no physical Windows/NVIDIA acceptance or long-duration leak claim.",
			"slider_scope":"Transparent wrapper invokes the original live UI callback exactly once. Authored-state response and next frame_post_draw are separate; completed draw is not input-to-photon.",
			"native_scope":"Already published immutable snapshot observations may coalesce native ticks. Every actual completed Rapier step is timestamped by the existing completion hook.",
			"memory_scope":"Whole-process CPU/RSS includes the external observer and retained evidence arrays. Each bounded live array is cleared between adjacent windows; no image readback occurs inside them."}}
	if not check(not output.is_empty() and (DisplayServer.get_name() != "headless" or diagnostic_headless),"explicit sustained graphical execution identity"):
		finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(OpticsObservedHost)
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	var bootstrap := Time.get_ticks_msec()
	if not await until(idle,"sustained ordinary Workbench bootstrap",180000): finish(); return
	record.bootstrap_elapsed_ms = Time.get_ticks_msec()-bootstrap
	check(wb.strata == null,"sustained ordinary default-OFF startup")
	record.ordinary_workbench = wb.get_script().resource_path == "res://scripts/shared_workbench.gd"
	strata = wb.ensure_strata()
	var fixture: Script = load("res://scripts/depth/strata_optics_fixtures.gd")
	_loaded_source = fixture.make(PackedInt32Array(wb.applied.liquid_policy))
	var admission := Time.get_ticks_msec()
	if not check(not _loaded_source.has("error") and strata.load_document(_loaded_source),"sustained authoritative native fixture admission"): finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,"sustained four native planes",180000): finish(); return
	record.admission_elapsed_ms = Time.get_ticks_msec()-admission
	record.admission_target_met = int(record.admission_elapsed_ms) <= 45000
	record.world_count = {"play_borrowed":1,"decorative_owned":int(strata.layer_owner.stats().native_world_count)}
	record.extent = [Setup.extent_of(wb.applied).x,Setup.extent_of(wb.applied).y]
	check(record.world_count.decorative_owned == 3 and not strata.layer_owner.stats().owns_play_world,"sustained unchanged four-plane ownership")
	check(host.paused and strata.select_layer("play") and strata.reset_optics() and strata.set_optics_quality("balanced"),"sustained initial exact Classic and ordinary Play authority")
	wb.set_camera(2)
	await settle()
	record.plane_native_hashes_before = await all_native_hashes()
	await _retained_capture("sustained-before")
	if not await _mount_live_controls(): finish(); return
	await _run_uninterrupted()
	_restore_live_controls()
	record.plane_native_hashes_after = await _evolved_native_hashes()
	for plane: String in ["scripted","effects","background"]:
		check(record.plane_native_hashes_before[plane] == record.plane_native_hashes_after[plane],"sustained actual static material bytes "+plane)
	await _retained_capture("sustained-after")
	record.final_optics = strata.optics_state()
	record.final_diagnostics = strata.diagnostics()
	finish()
