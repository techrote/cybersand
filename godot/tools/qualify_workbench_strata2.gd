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


func _visibility_fixture_view() -> bool:
	# Overview at 2048 cells across can map multiple textured native cells to
	# one display pixel. A colour oracle needs a controlled resolving view.
	# This delegates to the ordinary Workbench camera; Overview/input remain
	# separately exercised by the gallery, transforms and scaled mouse probe.
	wb._set_view(Vector2(160,80),Vector2i(1024,576))
	return true


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
	# Native Play can be paused while its Neon/LED material shader still uses
	# engine TIME. Freeze that independent animation for matched pixel evidence.
	var borrowed_shader: ShaderMaterial = host.world_shader
	var original_material_time: Variant = borrowed_shader.get_shader_parameter("presentation_time_override")
	borrowed_shader.set_shader_parameter("presentation_time_override",12.5)
	var borrowed_emission: ShaderMaterial = host.glow_source_shader
	var original_emission_time: Variant = borrowed_emission.get_shader_parameter("presentation_time_override")
	borrowed_emission.set_shader_parameter("presentation_time_override",12.5)
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
		"play_material_time":{"fixed":12.5,"original":original_material_time,"shader_instance":str(borrowed_shader.get_instance_id()),
			"emission_original":original_emission_time,"emission_shader_instance":str(borrowed_emission.get_instance_id())},
		"category":"presentation-only; no native simulation, light transport or material transfer"}
	check(strata.set_atmosphere(authored),"restore exact authored scene atmosphere")
	borrowed_shader.set_shader_parameter("presentation_time_override",original_material_time)
	borrowed_emission.set_shader_parameter("presentation_time_override",original_emission_time)
	check(borrowed_shader.get_shader_parameter("presentation_time_override") == original_material_time,"restore borrowed Play material animation clock")
	check(borrowed_emission.get_shader_parameter("presentation_time_override") == original_emission_time,"restore borrowed Play emission animation clock")
	record.atmosphere.play_material_time.restored = borrowed_shader.get_shader_parameter("presentation_time_override") == original_material_time
	record.atmosphere.play_material_time.emission_restored = borrowed_emission.get_shader_parameter("presentation_time_override") == original_emission_time


func scene_gallery() -> void:
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"native gallery stack")
	wb.set_camera(2)
	await capture("reference-composite")
	var authored: Dictionary = strata.atmosphere_state()
	check(strata.set_atmosphere_settings({"enabled":false}),"native isolated gallery excludes visual atmosphere")
	for id: String in IDS:
		check(strata.set_presentation({"solo":id,"active":id}),"native gallery plane "+id)
		await capture("reference-plane-"+id)
	check(strata.set_presentation({"solo":"","active":"play"}),"native gallery composite restored")
	check(strata.set_atmosphere(authored),"native gallery restores authored visual atmosphere")
	record.gallery = {"composite":"native geometry with authored presentation-only atmosphere",
		"isolated_planes":"native material surfaces; atmosphere disabled; no actor/collision claim for decoration"}
	var metadata: Dictionary = Showcase.metadata(scene_id)
	for view: Dictionary in metadata.detail_views:
		var centre := Vector2(float(view.center[0]),float(view.center[1]))
		var size := Vector2i(480.0/float(view.zoom),270.0/float(view.zoom))
		wb._set_view(centre-Vector2(size)*0.5,size)
		await capture("detail-"+str(view.id))
		if not record.has("detail_views"): record.detail_views = []
		record.detail_views.append({"id":view.id,"camera_origin":[host.camera_origin.x,host.camera_origin.y],
			"view_size":[host.current_view_size.x,host.current_view_size.y],
			"framebuffer_world_rect":_world_pixel_rect(),"sampling":"magnified nearest material pixels; not a one-cell/one-display-pixel claim",
			"source":"actual native Godot framebuffer"})
	await native_grid_details(Vector2(metadata.detail_views[0].center[0],metadata.detail_views[0].center[1]))
	wb.set_camera(2)


func _world_pixel_rect() -> Array:
	var area: Rect2 = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()*host.view_content_rect()
	return [area.position.x,area.position.y,area.size.x,area.size.y]


func native_grid_details(centre: Vector2) -> void:
	var presentation: Dictionary = strata.document().presentation.duplicate(true)
	var atmosphere: Dictionary = strata.atmosphere_state()
	var available: Rect2 = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,host.world_view.size)
	var view := Vector2i(available.size.floor()).min(Setup.extent_of(wb.applied))
	wb._set_view(centre-Vector2(view)*0.5,view)
	check(strata.set_atmosphere_settings({"enabled":false}),"native-resolution details exclude visual animation")
	record.native_grid_details = []
	for plane: String in ["play","scripted"]:
		var opacity: float = Document.plane(strata.document(),plane).opacity
		check(strata.set_layer_option(plane,"opacity",1.0) and strata.set_presentation({"mode":"flat","active":plane,"solo":plane,
			"parallax_strength":0.0,"fog_strength":0.0}),"one native cell per framebuffer pixel inspection "+plane)
		var frame: Image = await capture("native-grid-"+plane+"-frame")
		var transform: Transform2D = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()
		var first: Vector2 = transform*strata.presenter.layer_to_screen(centre,plane)
		var next_x: Vector2 = transform*strata.presenter.layer_to_screen(centre+Vector2.RIGHT,plane)
		var next_y: Vector2 = transform*strata.presenter.layer_to_screen(centre+Vector2.DOWN,plane)
		check(absf(first.distance_to(next_x)-1.0) < 0.01 and absf(first.distance_to(next_y)-1.0) < 0.01,
			"actual native grid maps one-to-one to captured physical framebuffer pixels "+plane)
		var area: Rect2 = transform*host.view_content_rect()
		var crop := Rect2i(Vector2i(area.position.round()),Vector2i(area.size.floor())).intersection(Rect2i(Vector2i.ZERO,frame.get_size()))
		check(frame.get_region(crop).save_png(output.path_join("native-grid-"+plane+".png")) == OK,"actual one-to-one native surface crop saved "+plane)
		record.native_grid_details.append({"plane":plane,"view_size":[view.x,view.y],"camera_origin":[host.camera_origin.x,host.camera_origin.y],
			"framebuffer_crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"pixels_per_cell_x":first.distance_to(next_x),
			"pixels_per_cell_y":first.distance_to(next_y),"source":"Actual Godot framebuffer crop; no resampling or concept-art substitution."})
		check(strata.set_layer_option(plane,"opacity",opacity),"restore native detail plane opacity")
	check(strata.set_presentation(presentation) and strata.set_atmosphere(atmosphere),"restore native detail presentation")


func _native_region_bytes(plane: String, region: Rect2i) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(region.size.x*region.size.y*2)
	for y: int in region.size.y:
		for x: int in region.size.x:
			result.encode_u16((y*region.size.x+x)*2,strata.layer_owner.material_at(plane,region.position+Vector2i(x,y)))
	return result


func _reference_projection(fixture: Dictionary, before: PackedByteArray) -> Dictionary:
	# Independent test oracle: direct RGB-byte distances and explicit white mask,
	# not the import codec or session's proposed image/material arrays.
	var source := Image.load_from_file(str(fixture.path))
	var mask := Image.load_from_file(str(fixture.options.mask_path))
	check(fixture.options.crop.size() == 4 and float(fixture.options.crop[0]) == 0.0 and float(fixture.options.crop[1]) == 0.0 \
		and float(fixture.options.crop[2]) == float(source.get_width()) and float(fixture.options.crop[3]) == float(source.get_height()) and float(fixture.options.scale) == 1.0 \
		and str(fixture.options.transform) == "identity" and str(fixture.options.alpha_mode) == "overlay",
		"specialized independent oracle admits only full-crop identity scale-one overlays")
	check(not source.detect_alpha(),"pinned reference source remains opaque RGB; mask is independently authored")
	var expected := before.duplicate()
	var geometry := PackedByteArray()
	geometry.resize(before.size())
	var write_mask := PackedByteArray()
	write_mask.resize(before.size()/2)
	var mapped := 0
	var untouched := 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var offset := y*source.get_width()+x
			var selection := mask.get_pixel(x,y)
			if selection.a8 == 0 or selection.r8+selection.g8+selection.b8 < 384:
				untouched += 1
				continue
			var pixel := source.get_pixel(x,y)
			var minimum := 195076
			var material := -1
			for row: Dictionary in fixture.options.palette:
				var dr := pixel.r8-int(row.rgb[0])
				var dg := pixel.g8-int(row.rgb[1])
				var db := pixel.b8-int(row.rgb[2])
				var distance := dr*dr+dg*dg+db*db
				if distance < minimum:
					minimum = distance
					material = int(row.material)
			if minimum > int(fixture.options.color_distance)*int(fixture.options.color_distance):
				untouched += 1
				continue
			expected.encode_u16(offset*2,material)
			geometry.encode_u16(offset*2,material)
			write_mask[offset] = 1
			mapped += 1
	return {"expected":expected,"geometry_sha256":digest(geometry),"mask_sha256":digest(write_mask),
		"mapped":mapped,"no_write":untouched}


func _capture_ready_review(button: BaseButton, preview: Control, filename: String) -> Dictionary:
	var ancestor: Node = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	var scroll: ScrollContainer = ancestor as ScrollContainer
	if not check(scroll != null,"ready proposal has an existing authoring scroll container"): return {}
	scroll.ensure_control_visible(button)
	await settle()
	var area: Rect2 = scroll.get_global_rect()
	var button_visible: bool = area.encloses(button.get_global_rect())
	var preview_visible: bool = area.encloses(preview.get_global_rect())
	check(button_visible and not button.disabled,"actual ready approval is enabled and visible after scrolling")
	check(preview_visible,"actual proposed native image is visible beside the ready approval")
	var image: Image = strata._window.get_texture().get_image()
	check(image != null and not image.is_empty() and image.save_png(output.path_join(filename)) == OK,"actual ready review pixels captured")
	return {"filename":filename,"approval_enabled":not button.disabled,"approval_visible":button_visible,
		"proposal_visible":preview_visible,"scroll_vertical":scroll.scroll_vertical,
		"scope":"Actual scrolled Workbench controls and native-ID proposal; no automatic application."}


func composition_review() -> void:
	var hashes_before: Dictionary = await all_native_hashes()
	var identity_before := play_identity()
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"review a visible layered construction")
	strata.open_panel()
	strata._panel._tabs.current_tab = 2
	var ui: Node = strata._panel._authoring
	if not check(not ui._compositions.is_empty(),"actual Compose catalogue has a reusable layered preset"): return
	ui._composition.select(0)
	for control: SpinBox in ui._module_origin: control.value = 64
	var composition_id: String = str(ui._compositions[0].id)
	ui._request_preview("preview_composition",[composition_id,{"origin":[64,64]}])
	if not await until(func() -> bool: return not strata.authoring_state().get("busy",false),"actual layered construction ready preview"): return
	ui.refresh({},"")
	var ready: Dictionary = strata.authoring_state()
	if not check(ready.get("can_approve",false) and not ui._compose_approve.disabled,"actual Compose preview requires explicit approval"): return
	check(ui._stage_previews.size() >= 2 and ui._compose_preview.image_texture != null,"actual reviewed preset has plane stages and composite native-ID proposal")
	var view: Dictionary = await _capture_ready_review(ui._compose_approve,ui._compose_preview,"composition-ready-approval.png")
	view.id = composition_id
	view.status = str(ready.status)
	view.reviewed_token = str(ui._token)
	view.backend_token = str(ready.token)
	view.backend_message = str(ready.get("message",""))
	view.displayed_status = ui._compose_status.text
	view.stage_count = ui._stage_previews.size()
	view.approved = false
	check(view.reviewed_token == view.backend_token and not view.reviewed_token.is_empty(),"Compose approval and exact reviewed backend token agree")
	check(view.displayed_status == view.backend_message.strip_edges(),"Compose visible status describes the ready proposal")
	ui._compose_stop.pressed.emit()
	if not await until(func() -> bool: return not strata.authoring_state().get("busy",false),"cancel unapproved native composition preview"): return
	var stopped: Dictionary = strata.authoring_state()
	ui.refresh({},"")
	var cancelled: bool = stopped.get("status") == "cancelled" and str(stopped.get("token","")).is_empty() \
		and not stopped.get("can_approve",true) and int(stopped.get("applied_cells",-1)) == 0 and ui._compose_approve.disabled
	check(cancelled,"actual Compose Stop retires the unapproved token and performs zero native writes")
	view.stop = {"status":str(stopped.get("status","")),"token":str(stopped.get("token","")),
		"can_approve":bool(stopped.get("can_approve",true)),"applied_cells":int(stopped.get("applied_cells",-1)),
		"approval_disabled":ui._compose_approve.disabled}
	var hashes_after: Dictionary = await all_native_hashes()
	check(hashes_before == hashes_after,"review and Stop of unapproved composition change no native material plane")
	view.native_hashes_before = hashes_before
	view.native_hashes_after = hashes_after
	view.cancelled_without_approval = cancelled
	record.composition_review = view
	stable_identity(identity_before,play_identity(),"zero-write actual Compose review")
	strata._window.hide()


func native_reference_import(id: String) -> void:
	var directory := "res://data/strata2/reference-imports/"
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+id+".fixture.json"))
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+id+".provenance.json"))
	var region := Rect2i(int(fixture.options.origin[0]),int(fixture.options.origin[1]),int(fixture.options.crop[2]),int(fixture.options.crop[3]))
	var presentation: Dictionary = strata.document().presentation.duplicate(true)
	var atmosphere: Dictionary = strata.atmosphere_state()
	var opacity: float = Document.plane(strata.document(),"scripted").opacity
	var identity_before := play_identity()
	var play_before := await play_bytes()
	var owners_before: Dictionary = strata.layer_owner.stats()
	var before := _native_region_bytes("scripted",region)
	var oracle := _reference_projection(fixture,before)
	check(oracle.geometry_sha256 == provenance.proposed_uint16le_sha256 and oracle.mask_sha256 == provenance.proposed_write_mask_sha256,
		"independent actual-source RGB/mask oracle matches pinned geometry "+id)
	check(FileAccess.get_sha256(fixture.path) == provenance.crop_file_sha256 and FileAccess.get_sha256(fixture.options.mask_path) == provenance.mask_sha256,
		"actual reference source/mask raw-byte identity "+id)
	strata.open_panel()
	var ui: Node = strata._panel._authoring
	var found := -1
	for index: int in ui._fixtures.size():
		if str(ui._fixtures[index].get("id","")) == id: found = index
	if not check(found >= 0,"actual Import controls expose source-pinned reference "+id): return
	ui._fixture.select(found)
	ui._load_fixture()
	ui._preview_import()
	if not await until(func() -> bool: return not strata.authoring_state().get("busy",false),"reference source native preview "+id): return
	ui.refresh({},"")
	var preview: Dictionary = strata.authoring_state()
	if not check(preview.get("can_approve",false) and not ui._approve.disabled,"real source requires enabled explicit Import approval "+id): return
	check(_native_region_bytes("scripted",region) == before,"reference Import preview made zero native writes "+id)
	check(int(preview.get("mapped",-1)) == oracle.mapped and int(preview.get("no_write",-1)) == oracle.no_write,
		"reference preview reports every mapped and untouched source pixel "+id)
	strata._panel._tabs.current_tab = 1
	await settle()
	var proposed_ui: Image = strata._window.get_texture().get_image()
	check(proposed_ui.save_png(output.path_join("reference-import-"+id+"-review.png")) == OK,"actual reference Import review controls captured")
	strata._window.hide()
	check(strata.set_presentation({"enabled":true,"mode":"flat","active":"scripted","solo":"scripted","parallax_strength":0.0,"fog_strength":0.0}),"inspect native reference on its sole target")
	check(strata.set_layer_option("scripted","opacity",1.0) and strata.set_atmosphere_settings({"enabled":false}),"reference native pixels exclude unrelated atmosphere")
	wb._set_view(Vector2(region.position),region.size)
	var frame_before: Image = await capture("reference-import-"+id+"-before")
	# Visual settings/active target are part of preview fences. Prepare again in
	# the actual reviewed native view, then dispatch the ordinary Approve control.
	ui._preview_import()
	if not await until(func() -> bool: return not strata.authoring_state().get("busy",false),"reference final-view preview "+id): return
	ui.refresh({},"")
	if not check(not ui._approve.disabled,"final native view has a fresh reviewed token "+id): return
	var approved_token: String = str(strata.authoring_state().get("token",""))
	strata._window.show()
	strata._panel._tabs.current_tab = 1
	var approval_view: Dictionary = await _capture_ready_review(ui._approve,ui._output_preview,"reference-import-"+id+"-approval.png")
	approval_view.status = str(strata.authoring_state().get("status",""))
	approval_view.reviewed_token = str(ui._token)
	approval_view.backend_token = approved_token
	approval_view.backend_message = str(strata.authoring_state().get("message",""))
	approval_view.displayed_status = ui._authoring_status.text
	approval_view.changed_counts = ui._preview_summary.text
	approval_view.expected_region = [region.position.x,region.position.y,region.size.x,region.size.y]
	approval_view.region_label = ui._preview_summary.text.get_slice("\n",0)
	check(approval_view.status == "ready" and approval_view.reviewed_token == approved_token,"actual Import visible approval and reviewed token agree")
	check(approval_view.displayed_status == approval_view.backend_message.strip_edges(),"Import visible status describes the ready native projection")
	check(approval_view.region_label.begins_with("Target: scripted · region ") and approval_view.region_label.contains(str(approval_view.expected_region)),
		"Import ready review states the actual approved native origin and extent")
	strata._window.hide()
	ui._approve.pressed.emit()
	if not await until(func() -> bool: return not strata.authoring_state().get("busy",false),"reference bounded native ACK/readback "+id): return
	var completed: Dictionary = strata.authoring_state()
	if not check(completed.get("status") == "completed","reference import reports committed and published native cells "+id): return
	var actual := _native_region_bytes("scripted",region)
	check(actual == oracle.expected,"actual source import target equals independent RGB/mask projection "+id)
	var frame_after: Image = await capture("reference-import-"+id+"-native-output")
	var visual := _world_difference(frame_before,frame_after)
	check(visual.changed_samples >= 8,"actual native imported materials visibly change selected plane "+id)
	var after_play := await play_bytes()
	check(after_play == play_before,"actual reference import preserved every native Play material "+id)
	var owners_after: Dictionary = strata.layer_owner.stats()
	for plane: String in ["effects","background"]:
		check(owners_before.layers[plane].native_revision == owners_after.layers[plane].native_revision \
			and owners_before.layers[plane].native_instance_id == owners_after.layers[plane].native_instance_id,
			"reference import retained unselected native owner/revision "+plane)
	var chunks := int(owners_after.layers.scripted.undo)-int(owners_before.layers.scripted.undo)
	check(chunks > 0 and chunks <= 8,"reference source admitted as bounded native history chunks")
	for _index: int in chunks: check(strata.undo_layer(),"reference native chunk Undo")
	var restored := _native_region_bytes("scripted",region)
	check(restored == before,"reference chunk history restores every actual destination cell "+id)
	stable_identity(identity_before,play_identity(),"actual source native Import/Undo")
	record.reference_import = {"id":id,"source_sha256":provenance.crop_file_sha256,"mask_sha256":provenance.mask_sha256,
		"original_source_sha256":provenance.original_sha256,"geometry_sha256":oracle.geometry_sha256,"write_mask_sha256":oracle.mask_sha256,
		"mapped":oracle.mapped,"no_write":oracle.no_write,"plane":"scripted","region":[region.position.x,region.position.y,region.size.x,region.size.y],
		"approved_token":approved_token,"completed_status":completed.status,"history_chunks":chunks,"ready_review":approval_view,
		"before_sha256":digest(before),"expected_sha256":digest(oracle.expected),"actual_sha256":digest(actual),"restored_sha256":digest(restored),
		"play_before_sha256":digest(play_before),"play_after_sha256":digest(after_play),"visual_difference":visual,
		"scope":"Actual Import controls, explicit reviewed approval, authoritative native readback, real Godot pixels and per-chunk Undo; original opaque art and explicit selection mask stay distinct."}
	check(strata.set_layer_option("scripted","opacity",opacity) and strata.set_atmosphere(atmosphere) and strata.set_presentation(presentation),"restore reference-scene visual settings")
	wb.set_camera(2)


func successor_panel() -> void:
	await panel_controls()
	strata.open_panel()
	var panel: PanelContainer = strata._panel
	check(panel._tabs.get_tab_count() == 6,"ordinary Strata retains five workflow routes and appends Optics Lab")
	for index: int in range(1,5):
		panel._tabs.current_tab = index
		await settle()
		var image: Image = strata._window.get_texture().get_image()
		check(image != null and not image.is_empty() and image.save_png(output.path_join("workflow-tab-%d.png" % index)) == OK,"actual new workflow tab pixels "+str(index))
	panel._tabs.current_tab = 0
	strata._window.hide()


func route_segment() -> void:
	var proposal := _route_definition()
	var destination := Vector2(proposal.to[0],proposal.to[1])
	var start_state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
	if not check(not start_state.is_empty(),"route probe has an actual selected native actor"): return
	var start: Vector2 = start_state.position
	var direction := (destination-start).normalized()
	var before := play_identity()
	var started := Time.get_ticks_usec()
	var callbacks := 0
	var rows: Array = []
	var live_edit: Dictionary = {}
	var ticks_target := int(before.rapier_tick)+60
	host.qualification_action = _route_action(start_state,direction,start)
	check(wb.toggle_pause(),"ordinary actor begins bounded route probe")
	while int(host.physical_actor_session.tick) < ticks_target and Time.get_ticks_usec()-started < 45000000:
		await process_frame
		callbacks += 1
		var state: Dictionary = host.physical_actor_session.workbench_actor_state(wb.selected_id())
		host.qualification_action = _route_action(state,direction,start)
		if rows.size() < 64 and (rows.is_empty() or int(rows.back().rapier_tick) != int(host.physical_actor_session.tick)):
			rows.append({"native_tick":int(host.latest_snapshot.tick_index),"rapier_tick":int(host.physical_actor_session.tick),
				"position":[state.position.x,state.position.y],"rotation":state.rotation,
				"move":[host.qualification_action.move.x,host.qualification_action.move.y],
				"applied_force":[state.controller.get("applied_force",Vector2.ZERO).x,state.controller.get("applied_force",Vector2.ZERO).y]})
		if callbacks == 3:
			check(strata.set_enabled(false) and strata.set_enabled(true),"presentation toggle during actual piloted motion")
			check(strata.set_atmosphere_settings({"enabled":false}) and strata.set_atmosphere_settings({"enabled":true}),"atmosphere toggle during actual piloted motion")
		if callbacks == 12:
			var target := Vector2i(64,64)
			var previous: int = strata.layer_owner.material_at("background",target)
			var marker := 131 if previous != 131 else 58
			var edit_before := play_identity()
			check(strata.select_layer("background"),"select decorative edit target while ordinary Play runs")
			var committed: bool = strata.edit_cells("background",PackedInt32Array([target.x,target.y,marker]))
			var receipt: Dictionary = strata.last_edit_receipt.duplicate(true)
			var native_after: int = strata.layer_owner.material_at("background",target)
			check(committed and native_after == marker,"native decorative edit commits during actual piloted Play")
			check(strata.undo_layer() and strata.layer_owner.material_at("background",target) == previous,"live decorative Undo restores native geometry")
			check(strata.select_layer("play"),"restore ordinary Play edit target during route")
			stable_identity(edit_before,play_identity(),"live decorative edit and Undo")
			live_edit = {"before":edit_before,"after":play_identity(),"plane":"background","cell":[64,64],
				"native_before":previous,"native_written":native_after,"native_restored":strata.layer_owner.material_at("background",target),
				"marker":marker,"committed":committed,"receipt":receipt}
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
	check(not live_edit.is_empty() and int(after.native_tick) > int(live_edit.after.native_tick) \
		and int(after.rapier_tick) > int(live_edit.after.rapier_tick),"actual native and actor ticks continue after decorative edit")
	record.actual_play = {"before":before,"after":after,"position_before":[start.x,start.y],"position_after":[end.x,end.y],"distance":end.distance_to(start)}
	record.route_probe = {"id":proposal.id,"planned_from":proposal.from,"planned_to":proposal.to,
		"direction":[direction.x,direction.y],"completed_rapier_ticks":int(after.rapier_tick)-int(before.rapier_tick),
		"completed_native_ticks":int(after.native_tick)-int(before.native_tick),"elapsed_usec":Time.get_ticks_usec()-started,
		"callbacks":callbacks,"forward_cells":progress,"samples":rows,"before":before,"after":after,
		"live_decorative_edit":live_edit,
		"input_semantics":"Ordinary Midge move.x is yaw; negative move.y is propulsion. Horizontal trial uses copied pose feedback and an altitude hold; no force/position injection.",
		"scope":"Real actuation and initial route segment only; not full-route completion, load capacity or physical owner playfeel."}


func _route_action(state: Dictionary, direction: Vector2, start: Vector2) -> Dictionary:
	if absf(direction.x) < 0.25:
		return {"move":Vector2(0.0,-1.0),"primary":true,"effort":1.0}
	# The existing ordinary flyer uses yaw plus a body-local upward thruster.
	# Match workbench_actor_control.gd's bounded feedback semantics, never move
	# the Rapier body directly or reinterpret keyboard X as lateral translation.
	var velocity: Vector2 = state.linear_velocity
	var position: Vector2 = state.position
	var gravity := float(state.gravity)
	var acceleration := maxf(1.0,float(state.force_limit)/maxf(0.001,float(state.mass)))
	var angle := wrapf(float(state.rotation),-PI,PI)
	var desired_x := direction.x*26.0-velocity.x*1.2
	var desired_y := (start.y-position.y)*1.1-velocity.y*1.8
	var desired_angle := clampf(desired_x/maxf(gravity,30.0),-0.32,0.32)
	var yaw := clampf((desired_angle-angle)*1.8-float(state.angular_velocity)*0.35,-0.6,0.6)
	var thrust := clampf((gravity-desired_y)/maxf(1.0,acceleration*maxf(0.4,cos(angle))),0.0,1.0)
	return {"move":Vector2(yaw,-thrust),"primary":true,"effort":1.0}


func _route_definition() -> Dictionary:
	return Showcase.metadata(scene_id).route_probes[0]


func prepare_saved_authoring_witness() -> void:
	# Leave a deliberate native edit and changed authored visual setting in the
	# saved composition. Reopening only a pristine recipe cannot satisfy this.
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"background","solo":""}),"select durable saved native edit target")
	check(strata.set_layer_option("background","visible",true) and strata.set_layer_option("background","locked",false),"saved native edit target permits authoring")
	var point := Vector2i(96,96)
	var previous: int = strata.layer_owner.material_at("background",point)
	var marker := 131 if previous != 131 else 58
	check(strata.edit_cells("background",PackedInt32Array([point.x,point.y,marker])),"commit durable native edit before Save")
	var actual: int = strata.layer_owner.material_at("background",point)
	check(actual == marker and actual != previous,"durable saved edit has actual changed native material")
	var atmosphere: Dictionary = strata.atmosphere_state()
	if not check(not atmosphere.effects.is_empty(),"authored atmosphere exists before persistence mutation"): return
	var effect: Dictionary = atmosphere.effects[0]
	var strength := 0.43 if not is_equal_approx(float(effect.strength),0.43) else 0.37
	check(strata.update_atmosphere_effect(str(effect.id),{"strength":strength}),"change authored atmosphere setting before Save")
	check(strata.set_atmosphere_settings({"paused":true}),"persist explicit paused authored atmosphere")
	record.authored_mutations = {"plane":"background","point":[point.x,point.y],"before":previous,"after":actual,
		"effect_id":effect.id,"effect_strength_before":effect.strength,"effect_strength_after":strength}
	check(strata.set_presentation({"active":"play"}),"restore Play edit selection before Save")


func saved_authoring_witness() -> Dictionary:
	var doc: Dictionary = strata.document()
	var authoring: Dictionary = doc.get("authoring",{})
	var atmosphere: Dictionary = doc.get("atmosphere",{})
	var imports: Array = []
	for entry: Dictionary in authoring.get("records",[]):
		if entry.get("kind","") == "raster_import":
			imports.append({"source_sha256":entry.source_sha256,"geometry_sha256":entry.geometry_sha256,
				"actual_sha256":entry.actual_sha256,"plane":entry.plane,"status":entry.status,"historical":entry.historical})
	if scene_id in ["orbital-terminal","neon-rain-arcology"]:
		check(not imports.is_empty(),"saved composition retains admitted reference import history")
	check(not atmosphere.get("effects",[]).is_empty() and atmosphere.get("paused",false),"saved authored atmosphere settings are present and paused")
	return {"native_marker":{"plane":"background","point":[96,96],"material":strata.layer_owner.material_at("background",Vector2i(96,96))},
		"authoring_sha256":JSON.stringify(authoring).sha256_text(),"authoring_records":authoring.get("records",[]).size(),
		"raster_imports":imports,"atmosphere_sha256":JSON.stringify(atmosphere).sha256_text(),
		"atmosphere":atmosphere.duplicate(true),"scope":"Authored native edits, historical approved import metadata and effect settings; no evolved physics or animation-phase continuation."}


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
			if scene_id == Showcase.IDS[0]: await composition_review()
			if scene_id == Showcase.IDS[0]: await native_reference_import("asteroid-service-gallery")
			if scene_id == Showcase.IDS[1]: await native_reference_import("rocket-hangar-frame")
		await mode_identity()
		print("STRATA2_PROGRESS ownership toggles complete")
		await transform_matrix()
		print("STRATA2_PROGRESS transforms complete")
		await author_and_refuse()
		print("STRATA2_PROGRESS native authoring and guards complete")
		if not diagnostic_headless:
			var pixel_atmosphere: Dictionary = strata.atmosphere_state()
			check(strata.set_atmosphere_settings({"enabled":false,"paused":true}),"inherited native-colour fixtures exclude visual atmosphere")
			if scene_id == Showcase.IDS[0]:
				await all_plane_authoring_and_guards()
				await play_visibility_pixels()
				await immediate_view_input()
			await pixels_and_scenes()
			check(strata.set_atmosphere(pixel_atmosphere),"restore authored atmosphere after native-colour fixtures")
			record.native_pixel_controls_atmosphere_disabled = true
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
		prepare_saved_authoring_witness()
		record.saved_authoring = saved_authoring_witness()
		record.plane_native_hashes = await all_native_hashes()
		wb._name.text = save_name
		check(wb.save_setup(),"ordinary Save persists successor authored layout and effects")
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
		record.authored_settings_sha256 = JSON.stringify(strata.document()).sha256_text()
		print("STRATA2_PROGRESS authored save complete; actual route trial")
		await route_segment()
	else:
		record.saved_authoring = saved_authoring_witness()
		record.authored_settings_sha256 = JSON.stringify(strata.document()).sha256_text()
		record.plane_native_hashes = await all_native_hashes()
		record.fresh_process_reopen = true
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
		if not diagnostic_headless: await capture("fresh-reopen")
	record.document_version = int(strata.document().version)
	record.final_diagnostics = strata.diagnostics()
	print("STRATA2_WORKBENCH ",JSON.stringify({"scene":scene_id,"phase":phase,"checks":checks,"failures":failures,"admission_elapsed_ms":record.admission_elapsed_ms}))
	finish()
