extends "res://tools/qualify_workbench_strata.gd"

## Successor campaign reuses the predecessor's ordinary-host/native-readback
## helpers, never its completed evidence or a standalone Play host.
const Showcase = preload("res://scripts/depth/strata_showcase_scenes.gd")
const Profiles = preload("res://scripts/depth/strata_atmosphere_profiles.gd")

class RouteHost extends "res://scripts/main.gd":
	var qualification_action: Dictionary = {}
	func _publish_workbench_keyboard() -> void:
		if qualification_action.is_empty():
			super._publish_workbench_keyboard()
			return
		if paused or shared_workbench == null or physical_actor_session == null: return
		physical_actor_session.submit_workbench_action(shared_workbench.pilot_id(),qualification_action,
			{"q":false,"e":false,"s":false,"boost":false},false)

var diagnostic_headless := false


func settle() -> void:
	if diagnostic_headless:
		for _index: int in 3: await process_frame
	else:
		await super.settle()


func _world_difference(a: Image, b: Image, threshold: float = 0.003, stride: int = 2) -> Dictionary:
	var area: Rect2 = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()*host.view_content_rect()
	var changed := 0
	var sampled := 0
	var maximum := 0.0
	for y: int in range(maxi(0,int(area.position.y)+3),mini(a.get_height(),int(area.end.y)-3),stride):
		for x: int in range(maxi(0,int(area.position.x)+3),mini(a.get_width(),int(area.end.x)-3),stride):
			var distance := colour_distance(a.get_pixel(x,y),b.get_pixel(x,y))
			maximum = maxf(maximum,distance)
			sampled += 1
			if distance > threshold: changed += 1
	return {"changed_samples":changed,"samples":sampled,"max_channel_delta":maximum,"threshold":threshold,"stride":stride,
		"scope":"actual framebuffer pixels within the ordinary world view; UI labels excluded"}


func _atmosphere_diagnostics() -> Dictionary:
	var result := {}
	for id: String in ["scripted","effects","background"]:
		result[id] = strata.presenter._atmospheres[id].diagnostics()
	return result


func _phase_equal(a: Dictionary,b: Dictionary) -> bool:
	for id: String in a:
		if a[id].phase_seconds != b[id].phase_seconds: return false
	return true


func atmosphere_witness() -> void:
	var authored: Dictionary = strata.atmosphere_state()
	var identity_before := play_identity()
	var owners_before: Dictionary = strata.layer_owner.stats()
	var native_before := await all_native_hashes()
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"atmosphere matched stack")
	wb.set_camera(2)
	check(strata.set_atmosphere_settings({"enabled":false,"paused":true}),"atmosphere OFF control")
	var off: Image = await capture("atmosphere-off")
	check(strata.set_atmosphere_settings({"enabled":true,"paused":false}),"atmosphere ON control")
	strata.reset_atmosphere_phase()
	for _frame: int in 12: await process_frame
	var on: Image = await capture("atmosphere-on")
	var visual := _world_difference(off,on)
	check(visual.changed_samples >= 8,"scene atmosphere changes actual world pixels")
	var moving_before := _atmosphere_diagnostics()
	for _frame: int in 8: await process_frame
	var moving_after := _atmosphere_diagnostics()
	check(not _phase_equal(moving_before,moving_after),"visible unpaused visual clock advances")
	check(strata.set_atmosphere_settings({"paused":true}),"pause visual clock")
	var paused_before := _atmosphere_diagnostics()
	for _frame: int in 6: await process_frame
	var paused_after := _atmosphere_diagnostics()
	check(_phase_equal(paused_before,paused_after),"paused visual phase stays exact")
	check(strata.set_presentation({"solo":"play"}),"exclude every decorative plane")
	var excluded_enabled: Image = await capture("atmosphere-solo-play-on")
	check(strata.set_atmosphere_settings({"enabled":false}),"excluded effect OFF control")
	var excluded_disabled: Image = await capture("atmosphere-solo-play-off")
	var leakage := _world_difference(excluded_enabled,excluded_disabled,0.003,2)
	check(leakage.changed_samples == 0,"excluded decorative animation contributes no framebuffer pixels")
	check(strata.set_atmosphere_settings({"enabled":true,"paused":false}),"hidden plane clock challenge")
	var hidden_before := _atmosphere_diagnostics()
	for _frame: int in 6: await process_frame
	var hidden_after := _atmosphere_diagnostics()
	check(_phase_equal(hidden_before,hidden_after),"Solo-hidden plane clocks do not advance")
	check(strata.set_presentation({"solo":""}),"restore scene layer visibility")
	check(strata.set_atmosphere_settings({"paused":true}),"bounded deterministic visual probe")
	strata.reset_atmosphere_phase()
	var native_after := await all_native_hashes()
	var owners_after: Dictionary = strata.layer_owner.stats()
	check(native_before == native_after,"atmosphere controls leave every actual native material cell unchanged")
	for id: String in ["scripted","effects","background"]:
		check(owners_before.layers[id].undo == owners_after.layers[id].undo and owners_before.layers[id].revision == owners_after.layers[id].revision,"atmosphere does not create native history "+id)
	check(owners_before.native_snapshot_calls == owners_after.native_snapshot_calls,"atmosphere controls do not capture decorative native planes")
	stable_identity(identity_before,play_identity(),"atmosphere visibility and pause")
	record.atmosphere = {"visual_difference":visual,"solo_leakage":leakage,
		"moving_before":moving_before,"moving_after":moving_after,"paused_before":paused_before,"paused_after":paused_after,
		"hidden_before":hidden_before,"hidden_after":hidden_after,"native_hashes_before":native_before,"native_hashes_after":native_after,
		"identity_before":identity_before,"identity_after":play_identity(),"native_capture_delta":owners_after.native_snapshot_calls-owners_before.native_snapshot_calls,
		"category":"presentation-only; no native simulation, light transport or material transfer"}
	check(strata.set_atmosphere(authored),"restore exact authored scene atmosphere")


func scene_gallery() -> void:
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"native gallery stack")
	wb.set_camera(2)
	await capture("reference-composite")
	for id: String in IDS:
		check(strata.set_presentation({"solo":id,"active":id}),"native gallery plane "+id)
		await capture("reference-plane-"+id)
	check(strata.set_presentation({"solo":"","active":"play"}),"native gallery composite restored")
	var metadata: Dictionary = Showcase.metadata(scene_id)
	for view: Dictionary in metadata.detail_views:
		var centre := Vector2(float(view.center[0]),float(view.center[1]))
		var size := Vector2i(480.0/float(view.zoom),270.0/float(view.zoom))
		wb._set_view(centre-Vector2(size)*0.5,size)
		await capture("detail-"+str(view.id))
		if not record.has("detail_views"): record.detail_views = []
		record.detail_views.append({"id":view.id,"camera_origin":[host.camera_origin.x,host.camera_origin.y],
			"view_size":[host.current_view_size.x,host.current_view_size.y],"source":"actual native Godot framebuffer"})
	wb.set_camera(2)


func successor_panel() -> void:
	await panel_controls()
	strata.open_panel()
	var panel: PanelContainer = strata._panel
	check(panel._tabs.get_tab_count() == 5,"ordinary Strata exposes five coherent workflow tabs")
	for index: int in range(1,5):
		panel._tabs.current_tab = index
		await settle()
		var image: Image = strata._window.get_texture().get_image()
		check(image != null and not image.is_empty() and image.save_png(output.path_join("workflow-tab-%d.png" % index)) == OK,"actual new workflow tab pixels "+str(index))
	panel._tabs.current_tab = 0
	strata._window.hide()


func route_segment() -> void:
	var metadata: Dictionary = Showcase.metadata(scene_id)
	var proposal: Dictionary = metadata.route_probes[0]
	var destination := Vector2(proposal.to[0],proposal.to[1])
	var start_state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	var start: Vector2 = start_state.position
	var direction := (destination-start).normalized()
	var before := play_identity()
	var started := Time.get_ticks_usec()
	var callbacks := 0
	var rows: Array = []
	var ticks_target := int(before.rapier_tick)+60
	host.qualification_action = {"move":direction,"primary":direction.y < -0.25,"effort":1.0}
	check(wb.toggle_pause(),"ordinary actor begins bounded route probe")
	while int(host.physical_actor_session.tick) < ticks_target and Time.get_ticks_usec()-started < 45000000:
		await process_frame
		callbacks += 1
		if rows.size() < 64:
			var state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
			rows.append({"native_tick":int(host.latest_snapshot.tick_index),"rapier_tick":int(host.physical_actor_session.tick),
				"position":[state.position.x,state.position.y],"rotation":state.rotation})
		if callbacks == 3:
			check(strata.set_enabled(false) and strata.set_enabled(true),"presentation toggle during actual piloted motion")
			check(strata.set_atmosphere_settings({"enabled":false}) and strata.set_atmosphere_settings({"enabled":true}),"atmosphere toggle during actual piloted motion")
	host.qualification_action = {}
	check(wb.toggle_pause(),"ordinary actor pauses after route segment")
	await until(idle,"route pause settles")
	var after := play_identity()
	var end_state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	var end: Vector2 = end_state.position
	stable_identity(before,after,"bounded route and live presentation toggles")
	var progress := (end-start).dot(direction)
	check(int(after.rapier_tick) >= ticks_target and int(after.native_tick) > int(before.native_tick),"real Rapier and native progression complete the predeclared 60-tick route trial")
	check(progress > 1.0,"ordinary piloted actor makes measurable forward route progress")
	record.actual_play = {"before":before,"after":after,"position_before":[start.x,start.y],"position_after":[end.x,end.y],"distance":end.distance_to(start)}
	record.route_probe = {"id":proposal.id,"planned_from":proposal.from,"planned_to":proposal.to,
		"direction":[direction.x,direction.y],"completed_rapier_ticks":int(after.rapier_tick)-int(before.rapier_tick),
		"completed_native_ticks":int(after.native_tick)-int(before.native_tick),"elapsed_usec":Time.get_ticks_usec()-started,
		"callbacks":callbacks,"forward_cells":progress,"samples":rows,"before":before,"after":after,
		"scope":"Real actuation and initial route segment only; not full-route completion, load capacity or physical owner playfeel."}


func run() -> void:
	scene_id = OS.get_environment("STRATA_SCENE")
	phase = OS.get_environment("STRATA_PHASE")
	output = OS.get_environment("STRATA_EVIDENCE")
	save_name = "strata2-qualified-"+scene_id
	diagnostic_headless = DisplayServer.get_name() == "headless" and OS.get_environment("STRATA2_DIAGNOSTIC_HEADLESS") == "1"
	record = {"schema":"strata2-workbench-execution-v1","scene":scene_id,"phase":phase,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"completed":false,
		"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_adapter":RenderingServer.get_video_adapter_name(),"process_id":OS.get_process_id(),
		"diagnostic_headless":diagnostic_headless,"admission_target_ms":45000}
	if not check(DisplayServer.get_name() != "headless" or diagnostic_headless,"graphical campaign requires actual display") \
		or not check(scene_id in Showcase.IDS and phase in ["install","reopen"] and not output.is_empty(),"explicit successor scene and phase"):
		finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	set_meta("cybersand_feature","shared_workbench")
	print("STRATA2_PROGRESS ordinary host bootstrap ", scene_id, " ", phase)
	host = load("res://main.tscn").instantiate()
	host.set_script(RouteHost)
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	var startup := Time.get_ticks_msec()
	if not await until(idle,"ordinary Workbench startup",180000): finish(); return
	record.bootstrap_elapsed_ms = Time.get_ticks_msec()-startup
	record.ordinary_workbench = wb.get_script().resource_path == "res://scripts/shared_workbench.gd"
	check(wb.strata == null,"default ordinary startup creates no Strata owners or effects")
	await ordinary_disabled_baseline()
	strata = wb.ensure_strata()
	print("STRATA2_PROGRESS preparing four native planes ", scene_id)
	var admission := Time.get_ticks_msec()
	if phase == "install":
		check(not FileAccess.file_exists(Setup._path(save_name)),"pristine successor scene profile")
		if not check(strata.load_demo(scene_id),"source-authored showcase request"): finish(); return
	else:
		wb._name.text = save_name
		if not check(wb.load_setup(),"ordinary fresh-process authored loader request"): finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,"four-plane scene and ordinary actor adopted"):
		finish(); return
	record.admission_elapsed_ms = Time.get_ticks_msec()-admission
	record.admission_target_met = record.admission_elapsed_ms <= 45000
	record.extent = [Setup.extent_of(wb.applied).x,Setup.extent_of(wb.applied).y]
	var owners: Dictionary = strata.layer_owner.stats()
	check(owners.native_world_count == 3 and not owners.owns_play_world,"one ordinary Play plus three independent decorative owners")
	record.world_count = {"play_borrowed":1,"decorative_owned":owners.native_world_count}
	print("STRATA2_PROGRESS admitted four native planes ", record.admission_elapsed_ms, "ms")
	if phase == "install":
		record.showcase_native_hashes = await all_native_hashes()
		print("STRATA2_PROGRESS initial full native hashes complete")
		if not diagnostic_headless:
			await scene_gallery()
			await successor_panel()
		await mode_identity()
		print("STRATA2_PROGRESS ownership toggles complete")
		await transform_matrix()
		print("STRATA2_PROGRESS transforms complete")
		await author_and_refuse()
		print("STRATA2_PROGRESS native authoring and guards complete")
		if not diagnostic_headless:
			if scene_id == Showcase.IDS[0]:
				await all_plane_authoring_and_guards()
				await play_visibility_pixels()
				await immediate_view_input()
			await pixels_and_scenes()
			await atmosphere_witness()
		record.cost_samples = []
		check(strata.set_atmosphere_settings({"enabled":false}),"matched static cost control")
		for mode: String in ["disabled","flat","stack"]:
			var sample: Dictionary = await cost(mode)
			sample.atmosphere_enabled = false
			record.cost_samples.append(sample)
		check(strata.set_atmosphere_settings({"enabled":true,"paused":false}),"matched animation cost control")
		var animated: Dictionary = await cost("stack")
		animated.atmosphere_enabled = true
		animated.atmosphere = _atmosphere_diagnostics()
		record.cost_samples.append(animated)
		check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"save full scene")
		record.plane_native_hashes = await all_native_hashes()
		wb._name.text = save_name
		check(wb.save_setup(),"ordinary Save persists successor authored layout and effects")
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
		record.authored_settings_sha256 = JSON.stringify(strata.document()).sha256_text()
		print("STRATA2_PROGRESS authored save complete; actual route trial")
		await route_segment()
	else:
		record.authored_settings_sha256 = JSON.stringify(strata.document()).sha256_text()
		record.plane_native_hashes = await all_native_hashes()
		record.fresh_process_reopen = true
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
		if not diagnostic_headless: await capture("fresh-reopen")
	record.document_version = int(strata.document().version)
	record.final_diagnostics = strata.diagnostics()
	print("STRATA2_WORKBENCH ",JSON.stringify({"scene":scene_id,"phase":phase,"checks":checks,"failures":failures,"admission_elapsed_ms":record.admission_elapsed_ms}))
	finish()
