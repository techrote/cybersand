extends "res://tools/qualify_workbench_strata2.gd"

## Integrated optical qualification. Reuses source helpers, never predecessor
## pass claims. Capture and native readback are excluded from timed windows.
const COMPARATIVE_PROFILES := ["classic","gameplay_clarity","architectural","cinematic_deep_focus","diorama"]
const PROGRESSION_REPEATS := 3
const PROGRESSION_CALLBACKS := 90
const PROGRESSION_WATCHDOG_USEC := 90000000

class OpticsObservedHost extends RouteHost:
	var optics_observe := false
	var optics_completed: Array[Dictionary] = []
	var optics_publications: Array[Dictionary] = []
	var optics_last_native_tick := -1
	var optics_observer_overflow := false
	func _record_completed_playable_course_step() -> void:
		super._record_completed_playable_course_step()
		# This existing hook is called immediately after actual complete_step.
		# No extra physics/native work or snapshot request is performed here.
		if optics_observe and physical_actor_session != null:
			if optics_completed.size() >= 8192:
				optics_observer_overflow = true
				return
			optics_completed.append({"completed_usec":Time.get_ticks_usec(),"rapier_tick":physical_actor_session.tick})
	func _process(delta: float) -> void:
		super._process(delta)
		if optics_observe and latest_snapshot != null and int(latest_snapshot.tick_index) != optics_last_native_tick:
			if optics_publications.size() >= 8192:
				optics_observer_overflow = true
				return
			optics_last_native_tick = int(latest_snapshot.tick_index)
			optics_publications.append({"observed_usec":Time.get_ticks_usec(),
				"native_tick":int(latest_snapshot.tick_index),"published_usec":int(latest_snapshot.published_usec),
				"serial":int(latest_snapshot.serial),"world_revision":int(latest_snapshot.simulation_world_revision),
				"render_revision":int(latest_snapshot.world_revision),"worker_step_ms":float(latest_snapshot.worker_step_time_ms)})

var _classic_image: Image
var _profile_ids: Array[String] = []
var _native_hashes: Dictionary = {}
var _geometry_group := ""
var _loaded_source: Dictionary = {}


func _configuration() -> Dictionary:
	return strata.optics_state().configuration.duplicate(true)


func _canonical(value: Variant) -> String:
	return JSON.stringify(value,"",true,true)


func _camera_state() -> Dictionary:
	return {"origin":[host.camera_origin.x,host.camera_origin.y],
		"view_size":[host.current_view_size.x,host.current_view_size.y],
		"world_rect":_world_pixel_rect(),"window_size":[root.size.x,root.size.y],
		"content_scale_factor":root.content_scale_factor}


func _actor_state() -> Dictionary:
	var value: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	return {"position":[value.position.x,value.position.y],"rotation":float(value.rotation),
		"linear_velocity":[value.linear_velocity.x,value.linear_velocity.y],
		"rapier_tick":int(host.physical_actor_session.tick)}


func _freeze_visual_motion() -> void:
	check(host.paused,"matched visual corpus is physically paused")
	check(strata.set_atmosphere_settings({"paused":true}),"freeze authored atmosphere phase for matched comparisons")
	# Existing accepted capture uniform is shared with the material-emission pass.
	host.world_shader.set_shader_parameter("presentation_time_override",0.0)
	if host.glow_source_shader != null: host.glow_source_shader.set_shader_parameter("presentation_time_override",0.0)
	record.visual_time = {"material_presentation_time_override":0.0,"atmosphere_paused":true,"physical_paused":true}


func _settle_focus() -> void:
	await until(func() -> bool: return not bool(strata.presenter.optics_statistics().get("transitioning",false)),"optical transition settles",15000)
	await settle()


func _exact_difference(a: Image, b: Image) -> Dictionary:
	var raw: Array = _world_pixel_rect()
	var region := Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
	region = region.intersection(Rect2i(Vector2i.ZERO,a.get_size())).intersection(Rect2i(Vector2i.ZERO,b.get_size()))
	var first := a.get_region(region)
	var second := b.get_region(region)
	first.convert(Image.FORMAT_RGBA8)
	second.convert(Image.FORMAT_RGBA8)
	var bytes_a := first.get_data()
	var bytes_b := second.get_data()
	var changed := 0
	var largest := 0
	if bytes_a != bytes_b:
		for offset: int in range(0,bytes_a.size(),4):
			var difference := 0
			for channel: int in 4: difference = maxi(difference,absi(int(bytes_a[offset+channel])-int(bytes_b[offset+channel])))
			if difference > 0: changed += 1
			largest = maxi(largest,difference)
	return {"world_rect":[region.position.x,region.position.y,region.size.x,region.size.y],
		"pixels":region.size.x*region.size.y,"changed_pixels":changed,"max_channel_difference_u8":largest,
		"exact_equal":bytes_a == bytes_b,"scope":"actual unresampled RGBA8 world-view framebuffer; UI excluded"}


func _image_metrics(image: Image) -> Dictionary:
	var raw: Array = _world_pixel_rect()
	var region := Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3])).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var luminance_sum := 0.0
	var edge_sum := 0.0
	var dark := 0
	var bright := 0
	var count := 0
	for y: int in range(region.position.y+2,region.end.y-2,4):
		for x: int in range(region.position.x+2,region.end.x-2,4):
			var colour := image.get_pixel(x,y)
			var value := colour.r*0.2126+colour.g*0.7152+colour.b*0.0722
			var other := image.get_pixel(x+2,y)
			var next := other.r*0.2126+other.g*0.7152+other.b*0.0722
			luminance_sum += value
			edge_sum += absf(value-next)
			if value < 0.03: dark += 1
			if value > 0.97: bright += 1
			count += 1
	return {"sample_count":count,"sample_stride_pixels":4,"mean_srgb_luma":luminance_sum/maxi(1,count),
		"mean_horizontal_two_pixel_luma_difference":edge_sum/maxi(1,count),
		"near_black_fraction":float(dark)/maxi(1,count),"near_white_fraction":float(bright)/maxi(1,count),
		"scope":"supporting composited image statistics in encoded sRGB; includes all planes; not human readability or linear-light photometry"}


func _profile_gallery() -> void:
	record.profile_captures = []
	var camera := _camera_state()
	var actor := _actor_state()
	for id: String in _profile_ids:
		check(strata.select_optics_profile(id),"select editable optical profile "+id)
		await _settle_focus()
		check(_camera_state() == camera,"profile retains exact ordinary camera "+id)
		check(_actor_state() == actor,"profile retains exact paused actor state "+id)
		var configuration := _configuration()
		var serialized := _canonical(configuration)
		var entry := {"profile":id,"filename":"profile-"+id+".png","configuration":configuration,
			"configuration_canonical_json":serialized,"configuration_json":serialized,"configuration_sha256":serialized.sha256_text(),
			"camera":camera.duplicate(true),"actor_state":actor.duplicate(true),
			"geometry_group_sha256":_geometry_group,"optics_statistics":strata.presenter.optics_statistics()}
		if not diagnostic_headless:
			var image: Image = await capture("profile-"+id)
			entry.sha256 = FileAccess.get_sha256(output.path_join(entry.filename))
			entry.image_metrics = _image_metrics(image)
			if id == "classic": _classic_image = image
		record.profile_captures.append(entry)
		print("STRATA3_PROGRESS profile captured ",scene_id," ",id)


func _extra_capture(id: String, scope: String) -> Image:
	if diagnostic_headless: return null
	var picture: Image = await capture(id)
	if not record.has("additional_captures"): record.additional_captures = []
	record.additional_captures.append({"id":id,"filename":id+".png",
		"sha256":FileAccess.get_sha256(output.path_join(id+".png")),"scope":scope,
		"camera":_camera_state(),"geometry_group_sha256":_geometry_group})
	return picture


func _optics_controls() -> void:
	var owner_before := play_identity()
	var captures_before: int = strata.layer_owner.stats().native_snapshot_calls
	var uploads_before: int = strata.presenter.diagnostics().full_rg8_uploads
	check(strata.select_optics_profile("gameplay_clarity"),"readability profile selected for comparison")
	var authored := _canonical(_configuration())
	check(strata.set_optics_inspection({"bypass":true,"clarity":true}),"bypass with simultaneous assistance request")
	await _settle_focus()
	if not diagnostic_headless:
		var bypassed: Image = await _extra_capture("classic-return","Classic bypass wins over other transient effects; same geometry, camera, actor and frozen visual time.")
		record.classic_return = _exact_difference(_classic_image,bypassed)
		check(record.classic_return.exact_equal,"Classic bypass exactly restores every world-view framebuffer pixel")
	check(_canonical(_configuration()) == authored,"bypass does not rewrite authored optics")
	check(strata.set_optics_inspection({"bypass":false,"clarity":false,"wipe":0.5}),"single-draw wipe comparison")
	await _extra_capture("compare-wipe","One-draw Classic/processed wipe; optical parallax temporarily matches Classic.")
	check(strata.set_optics_inspection({"wipe":1.0,"clarity":true}),"temporary non-colour-only Play assistance")
	await _extra_capture("clarity-assistance","Temporary decorative suppression; physical Play material remains unchanged.")
	check(strata.set_optics_inspection({"clarity":false}),"release assistance")
	var edit_target := str(strata.active_layer())
	check(strata.select_optics_profile("optical_lens"),"lens profile for optical focus inspection")
	for id: String in IDS:
		check(strata.set_optics_inspection({"focus_override":id}),"inspect focal plane "+id)
		await _settle_focus()
		check(strata.active_layer() == edit_target,"optical focus preserves native edit target "+id)
		await _extra_capture("focus-"+id,"Temporary inspection focus on "+id+"; native edit target stays "+edit_target+".")
	check(strata.set_optics_inspection({"focus_override":""}),"return to authored focus")
	check(strata.set_optics({"focus_mode":"authoring"}),"explicit authoring focus mode")
	check(strata.select_layer("scripted"),"existing layer selector changes authoritative edit target explicitly")
	await _settle_focus()
	check(strata.active_layer() == "scripted","focus following never silently changes explicit edit target")
	check(strata.select_layer(edit_target),"restore explicit edit target")
	var old := _canonical(_configuration())
	check(not strata.set_optics({"defocus":NAN}) and _canonical(_configuration()) == old,"nonfinite optic refused without changing scene")
	check(not strata.set_plane_optics("play",{"participates":true}) and _canonical(_configuration()) == old,"Play optical processing refused")
	for tier: String in ["low","balanced","high"]:
		check(strata.set_optics_quality(tier),"application optical quality "+tier)
		check(_canonical(_configuration()) == old,"quality preference excluded from authored scene "+tier)
	check(strata.set_optics_quality("balanced"),"restore balanced application preference")
	var material_counts: Array[int] = []
	for index: int in 33:
		check(strata.select_optics_profile(_profile_ids[index%_profile_ids.size()]),"repeated profile transition "+str(index))
		var count := int(strata.presenter.optics_statistics().get("material_count",-1))
		material_counts.append(count)
		check(count >= 0 and count <= 3,"optical material resource bound "+str(index))
	var captures_after: int = strata.layer_owner.stats().native_snapshot_calls
	var uploads_after: int = strata.presenter.diagnostics().full_rg8_uploads
	check(captures_after == captures_before,"optical controls issue zero decorative native captures")
	check(uploads_after == uploads_before,"optical controls issue zero decorative RG8 uploads")
	stable_identity(owner_before,play_identity(),"optical controls and repeated switching")
	record.optical_controls = {"identity_before":owner_before,"identity_after":play_identity(),
		"decorative_capture_delta":captures_after-captures_before,"decorative_upload_delta":uploads_after-uploads_before,
		"profile_switch_material_counts":material_counts,"native_edit_target_retained":strata.active_layer() == edit_target}


func _lab_witness() -> void:
	strata.open_panel()
	var panel: PanelContainer = strata._panel
	var ui: Node = panel.find_child("StrataOpticsLab",true,false)
	if not check(ui != null,"ordinary Strata contains the integrated Optics Lab"): return
	var tab_index := -1
	for index: int in panel._tabs.get_tab_count():
		if panel._tabs.get_tab_title(index) == "Optics": tab_index = index
	if not check(tab_index >= 0,"Optics tab is reachable in ordinary Strata"): return
	panel._tabs.current_tab = tab_index
	await settle()
	check(ui._enabled.is_visible_in_tree() and ui._profile.is_visible_in_tree(),"actual optical profile controls visible")
	var initial: Dictionary = strata.optics_state()
	ui._enabled.button_pressed = true
	check(_configuration().enabled,"actual optical master control reaches renderer adapter")
	ui._global_controls.tonal.slider.value = 0.41
	check(is_equal_approx(float(_configuration().tonal),0.41),"actual live optical slider reaches authored state")
	var target := str(strata.active_layer())
	ui._plane_picker.select(2)
	ui._plane_picker.item_selected.emit(2)
	check(strata.active_layer() == target,"actual optical plane picker leaves native edit target unchanged")
	ui._preset_name.text = "Strata3 evaluated "+scene_id
	ui._save_named()
	check(strata.optics_state().custom_presets.size() > 0,"actual named custom preset is retained")
	if not diagnostic_headless:
		await settle()
		var picture: Image = strata._window.get_texture().get_image()
		check(picture != null and not picture.is_empty() and picture.save_png(output.path_join("optics-lab.png")) == OK,"actual integrated optical window captured")
		if not record.has("additional_captures"): record.additional_captures = []
		record.additional_captures.append({"id":"optics-lab","filename":"optics-lab.png","sha256":FileAccess.get_sha256(output.path_join("optics-lab.png")),"scope":"Actual separate Strata window and controls; not a matched world capture.","camera":_camera_state(),"geometry_group_sha256":_geometry_group})
	record.lab = {"tab_count":panel._tabs.get_tab_count(),"optics_tab_index":tab_index,
		"master_visible":ui._enabled.is_visible_in_tree(),"profile_count":ui._profile.item_count,
		"native_target_before":target,"native_target_after":strata.active_layer(),"custom_presets":strata.optics_state().custom_presets}
	strata._window.hide()
	check(strata.select_optics_profile(str(initial.configuration.profile)),"restore optical scene profile after UI exercise")


func _fixture_native_probes() -> void:
	if scene_id != "optics-readability-challenge": return
	var fixture: Script = load("res://scripts/depth/strata_optics_fixtures.gd")
	var metadata: Dictionary = fixture.metadata()
	var bytes := await play_bytes()
	var extent: Vector2i = Setup.extent_of(wb.applied)
	var probes: Array = []
	for specification: Dictionary in metadata.probes:
		var point := Vector2i(specification.point[0],specification.point[1])
		var observed := {}
		for id: String in specification.materials:
			observed[id] = int(bytes.decode_u16((point.y*extent.x+point.x)*2)) if id == "play" else int(strata.layer_owner.material_at(id,point))
			check(observed[id] == int(specification.materials[id]),"actual native readability truth "+specification.id+" "+id)
		probes.append({"id":specification.id,"point":specification.point,"expected":specification.materials,"observed":observed})
	record.readability_native_probes = probes


func _save_optics() -> void:
	check(strata.select_optics_profile("architectural"),"save deliberate balanced authored treatment")
	check(strata.set_optics({"focus_mode":"manual","focus_distance":0.27,"dof_width":0.62,"tonal":0.63}),"save nondefault editable lens settings")
	check(strata.set_plane_optics("scripted",{"depth":0.47,"contrast":0.83}),"save nondefault per-plane optical settings")
	var authored := _canonical(_configuration())
	check(strata.set_optics_inspection({"bypass":true,"focus_override":"background","wipe":0.35,"clarity":true}),"temporary inspection active during authored Save")
	wb._name.text = save_name
	check(wb.save_setup(),"ordinary Save persists authored optics with four native planes")
	record.saved_optics = {"configuration":_configuration(),"configuration_canonical_json":authored,"sha256":authored.sha256_text(),
		"inspection_at_save":strata.optics_state().inspection,"quality":strata.optics_state().quality}
	record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
	check(strata.set_optics_inspection({"bypass":false,"focus_override":"","wipe":1.0,"clarity":false}),"restore presentation after Save without reauthoring")


func _reopen_witness() -> void:
	var config := _configuration()
	check(strata.document().version == 3,"fresh process restores versioned authored optics")
	check(config.profile == "architectural" and config.focus_mode == "manual" and is_equal_approx(float(config.focus_distance),0.27)
		and is_equal_approx(float(config.dof_width),0.62) and is_equal_approx(float(config.tonal),0.63),"fresh process restores exact custom global settings")
	check(is_equal_approx(float(config.planes.scripted.depth),0.47) and is_equal_approx(float(config.planes.scripted.contrast),0.83),"fresh process restores exact per-plane settings")
	var inspection: Dictionary = strata.optics_state().inspection
	check(inspection == {"bypass":false,"clarity":false,"wipe":1.0,"focus_override":""},"fresh process excludes temporary inspection state")
	record.saved_optics = {"configuration":config,"configuration_canonical_json":_canonical(config),"sha256":_canonical(config).sha256_text(),"inspection_after_reopen":inspection}
	record.fresh_process_reopen = true
	record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
	await _extra_capture("fresh-reopen","Actual fresh-process native scene with restored authored lens settings; temporary inspection reset.")


func _percentiles(values: Array[int]) -> Dictionary:
	if values.is_empty(): return {"count":0,"p50":0,"p95":0,"p99":0,"max":0}
	var ordered := values.duplicate()
	ordered.sort()
	var stalls := {}
	for threshold: int in [100000,250000,500000,1000000]:
		var count := 0
		for value: int in values:
			if value >= threshold: count += 1
		stalls[str(threshold)] = count
	return {"count":values.size(),"p50":ordered[int(ceil(ordered.size()*0.50))-1],
		"p95":ordered[int(ceil(ordered.size()*0.95))-1],"p99":ordered[int(ceil(ordered.size()*0.99))-1],
		"max":ordered.back(),"stalls_at_least_usec":stalls}


func _progression_sample(id: String, repeat_index: int) -> Dictionary:
	# A fresh authored install makes every timed profile begin from the same
	# native geometry and actor state. Admission cost is retained separately.
	var previous_generation := int(host.latest_snapshot.render_world_generation)
	var admission_start := Time.get_ticks_msec()
	if scene_id == "optics-readability-challenge":
		check(strata.load_document(_loaded_source),"fresh matched native progression fixture")
	else:
		check(strata.load_demo(scene_id),"fresh matched native progression scene")
	await until(func() -> bool: return idle() and strata.has_document() and int(host.latest_snapshot.render_world_generation) != previous_generation and host.physical_actor_session != null,"matched progression scene replacement",180000)
	var admission_elapsed := Time.get_ticks_msec()-admission_start
	wb.set_camera(2)
	await settle()
	check(strata.set_atmosphere_settings({"paused":true}),"matched progression atmosphere phase")
	var initial_play := await play_bytes()
	var expected_play := reference_bytes(wb.applied.edits,Setup.extent_of(wb.applied))
	check(initial_play == expected_play,"timed sample starts from exact authored native Play material bytes")
	check(strata.select_optics_profile(id),"comparative live profile "+id)
	await _settle_focus()
	var actor: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	var start_position: Vector2 = actor.position
	var identity := play_identity()
	var capture_count: int = strata.layer_owner.stats().native_snapshot_calls
	var upload_count: int = strata.presenter.diagnostics().full_rg8_uploads
	host.qualification_action = _route_action(actor,Vector2.RIGHT if repeat_index%2 == 0 else Vector2.LEFT,start_position)
	check(wb.toggle_pause(),"start real physical progression sample")
	for _index: int in 6: await process_frame
	host.optics_completed = []
	host.optics_publications = []
	host.optics_last_native_tick = -1
	host.optics_observer_overflow = false
	var start_usec := Time.get_ticks_usec()
	var before := play_identity()
	var callback_usec: Array[int] = []
	var process_ms: Array[float] = []
	var previous := start_usec
	host.optics_observe = true
	for _index: int in PROGRESSION_CALLBACKS:
		await process_frame
		var now := Time.get_ticks_usec()
		callback_usec.append(now-previous)
		previous = now
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
		var state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
		host.qualification_action = _route_action(state,Vector2.RIGHT if repeat_index%2 == 0 else Vector2.LEFT,start_position)
		if now-start_usec > PROGRESSION_WATCHDOG_USEC: break
	host.optics_observe = false
	var elapsed := Time.get_ticks_usec()-start_usec
	var after := play_identity()
	var end_state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	var completed: Array = host.optics_completed.duplicate(true)
	var publications: Array = host.optics_publications.duplicate(true)
	host.qualification_action = {}
	check(wb.toggle_pause(),"pause real physical progression sample")
	await until(idle,"physical pause completes after comparative sample")
	var intervals: Array[int] = []
	for index: int in range(1,completed.size()): intervals.append(int(completed[index].completed_usec)-int(completed[index-1].completed_usec))
	var publication_intervals: Array[int] = []
	for index: int in range(1,publications.size()): publication_intervals.append(int(publications[index].published_usec)-int(publications[index-1].published_usec))
	stable_identity(identity,play_identity(),"comparative live sample "+id)
	check(int(after.rapier_tick) > int(before.rapier_tick) and int(after.native_tick) > int(before.native_tick),"actual Rapier and native progress "+id)
	check(not host.optics_observer_overflow,"bounded completed-step observer retains full sample")
	check(strata.layer_owner.stats().native_snapshot_calls == capture_count,"timed optical sample no decorative native captures")
	check(strata.presenter.diagnostics().full_rg8_uploads == upload_count,"timed optical sample no decorative material uploads")
	return {"profile":id,"repeat":repeat_index,"configuration":_configuration(),"quality":strata.optics_state().quality,
		"elapsed_usec":elapsed,"scene_admission_elapsed_ms":admission_elapsed,"scene_admission_target_met":admission_elapsed <= 45000,"initial_native_play_sha256":digest(initial_play),"callbacks":callback_usec.size(),"callback_intervals_usec":callback_usec,
		"callback_distribution_usec":_percentiles(callback_usec),"godot_process_ms":process_ms,
		"before":before,"after":after,"completed_physical_steps":completed,"physical_intervals_usec":intervals,
		"physical_distribution_usec":_percentiles(intervals),"native_publications":publications,
		"native_publication_interval_distribution_usec":_percentiles(publication_intervals),
		"native_ticks_per_second":float(int(after.native_tick)-int(before.native_tick))*1000000.0/maxi(1,elapsed),
		"rapier_ticks_per_second":float(int(after.rapier_tick)-int(before.rapier_tick))*1000000.0/maxi(1,elapsed),
		"actor_position_before":[start_position.x,start_position.y],"actor_position_after":[end_state.position.x,end_state.position.y],
		"actor_distance_cells":start_position.distance_to(end_state.position),
		"native_capture_delta":strata.layer_owner.stats().native_snapshot_calls-capture_count,
		"decorative_upload_delta":strata.presenter.diagnostics().full_rg8_uploads-upload_count,
		"godot_tracked_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"resource_count":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"optical_statistics":strata.presenter.optics_statistics(),
		"observer_scope":"Existing actual completed Rapier hook timestamps every step. Native publication observations can coalesce ticks; they do not reconstruct unobserved individual native completion intervals. No image readback/native material capture inside timed window.",
		"physical_gpu_acceptance":false}


func _progression() -> void:
	record.progression_samples = []
	for repeat_index: int in PROGRESSION_REPEATS:
		var order := COMPARATIVE_PROFILES.duplicate()
		if repeat_index%2 == 1: order.reverse()
		for id: String in order:
			print("STRATA3_PROGRESS timed sample ",id," ",repeat_index)
			record.progression_samples.append(await _progression_sample(id,repeat_index))
	record.progression_registration = {"repeats":PROGRESSION_REPEATS,"callbacks_per_sample":PROGRESSION_CALLBACKS,
		"per_sample_watchdog_usec":PROGRESSION_WATCHDOG_USEC,"order":"forward/reverse/forward",
		"geometry_reset_between_samples":true,
		"confound":"Fresh authored scene and native Play hash per sample; same input control observer and callback budget. Wall-clock phase and shared hosted CPU load can vary, so repeat spread and software-renderer limitations remain material.",
		"physical_scope":"Hosted renderer; physical owner acceptance remains open."}


func run() -> void:
	scene_id = OS.get_environment("STRATA_SCENE")
	phase = OS.get_environment("STRATA_PHASE")
	output = OS.get_environment("STRATA_EVIDENCE")
	save_name = "strata3-qualified-"+scene_id
	diagnostic_headless = DisplayServer.get_name() == "headless" and OS.get_environment("STRATA3_DIAGNOSTIC_HEADLESS") == "1"
	record = {"schema":"strata3-workbench-execution-v1","scene":scene_id,"phase":phase,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"completed":false,
		"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_adapter":RenderingServer.get_video_adapter_name(),"process_id":OS.get_process_id(),
		"diagnostic_headless":diagnostic_headless,"admission_target_ms":45000}
	if not check(DisplayServer.get_name() != "headless" or diagnostic_headless,"actual display required unless explicitly diagnostic") \
		or not check(phase in ["install","reopen","progression"] and not scene_id.is_empty() and not output.is_empty(),"explicit optics execution identity"):
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
	var startup := Time.get_ticks_msec()
	if not await until(idle,"ordinary Workbench bootstrap",180000): finish(); return
	record.bootstrap_elapsed_ms = Time.get_ticks_msec()-startup
	record.ordinary_workbench = wb.get_script().resource_path == "res://scripts/shared_workbench.gd"
	check(wb.strata == null,"ordinary default-OFF startup has no Strata or optics owners")
	strata = wb.ensure_strata()
	var admission := Time.get_ticks_msec()
	if phase == "reopen":
		wb._name.text = save_name
		if not check(wb.load_setup(),"ordinary fresh-process optical scene load"): finish(); return
	else:
		if scene_id == "optics-readability-challenge":
			var fixture: Script = load("res://scripts/depth/strata_optics_fixtures.gd")
			_loaded_source = fixture.make(PackedInt32Array(wb.applied.liquid_policy))
			if not check(not _loaded_source.has("error") and strata.load_document(_loaded_source),"admit native adversarial composition"): finish(); return
		else:
			if not check(strata.load_demo(scene_id),"admit native optical corpus scene"): finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,"four native planes and actor admitted",180000): finish(); return
	record.admission_elapsed_ms = Time.get_ticks_msec()-admission
	record.admission_target_met = int(record.admission_elapsed_ms) <= 45000
	record.extent = [Setup.extent_of(wb.applied).x,Setup.extent_of(wb.applied).y]
	record.world_count = {"play_borrowed":1,"decorative_owned":int(strata.layer_owner.stats().native_world_count)}
	check(record.world_count.decorative_owned == 3 and not strata.layer_owner.stats().owns_play_world,"four existing native plane owners only")
	wb.set_camera(2)
	await settle()
	if not check(strata.has_method("optics_state"),"source exposes integrated optical adapter"): finish(); return
	for item: Dictionary in strata.optics_profiles():
		if not bool(item.get("custom",false)): _profile_ids.append(str(item.id))
	check(_profile_ids.size() >= 8 and _profile_ids[0] == "classic","substantial editable catalogue retains Classic first")
	if phase == "progression":
		await _progression()
	else:
		_freeze_visual_motion()
		_native_hashes = await all_native_hashes()
		_geometry_group = _canonical(_native_hashes).sha256_text()
		record.plane_native_hashes_before = _native_hashes.duplicate(true)
		record.native_hashes_canonical_json = _canonical(_native_hashes)
		record.geometry_group_sha256 = _geometry_group
		if phase == "install":
			await _fixture_native_probes()
			await _profile_gallery()
			await _optics_controls()
			await mode_identity()
			await transform_matrix()
			await _lab_witness()
			await _save_optics()
		else:
			await _reopen_witness()
		record.plane_native_hashes_after = await all_native_hashes()
		check(record.plane_native_hashes_after == record.plane_native_hashes_before,"complete actual native material bytes unchanged by optical campaign")
	record.document_version = int(strata.document().version)
	record.final_diagnostics = strata.diagnostics()
	record.final_optics = strata.optics_state()
	print("STRATA3_WORKBENCH ",JSON.stringify({"scene":scene_id,"phase":phase,"checks":checks,"failures":failures,"admission_elapsed_ms":record.admission_elapsed_ms}))
	finish()
