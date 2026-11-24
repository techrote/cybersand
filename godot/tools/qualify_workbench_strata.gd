extends SceneTree

# Actual ordinary Main/Workbench host. Separate OS processes handle author and
# reopen phases. The harness never instantiates a standalone depth host or a
# second play World, and reads native stored materials for every claimed edit.
const Setup = preload("res://scripts/workbench_setup.gd")
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Scenes = preload("res://scripts/depth/workbench_strata_scenes.gd")
const IDS := ["play","scripted","effects","background"]

var host: Control
var wb: Control
var strata: Node
var checks := 0
var failures: Array[String] = []
var record: Dictionary = {}
var scene_id := ""
var phase := ""
var save_name := ""
var output := ""
var measuring := false
var frame_intervals: Array[int] = []
var process_times: Array[float] = []
var previous_frame_usec := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func _process(_delta: float) -> bool:
	if measuring:
		var now := Time.get_ticks_usec()
		if previous_frame_usec > 0: frame_intervals.append(now-previous_frame_usec)
		previous_frame_usec = now
		process_times.append(float(Performance.get_monitor(Performance.TIME_PROCESS)))
	return false

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("STRATA_WORKBENCH " + label)
	return ok

func until(predicate: Callable, label: String, limit_ms: int = 45000) -> bool:
	var started := Time.get_ticks_msec()
	var deadline := started+limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	# A software-driver cold shader frame may finish after the callback deadline.
	# Recheck the actual predicate once; the external OS-process bound remains.
	if predicate.call():
		if not record.has("deadline_rechecks"): record.deadline_rechecks = []
		record.deadline_rechecks.append({"label":label,"limit_ms":limit_ms,"elapsed_ms":Time.get_ticks_msec()-started})
		return true
	if not record.has("timeouts"): record.timeouts = []
	record.timeouts.append({"label":label,"limit_ms":limit_ms,"elapsed_ms":Time.get_ticks_msec()-started,
		"workbench_message":str(wb.message) if wb != null else "no Workbench",
		"applied":not wb.applied.is_empty() if wb != null else false,
		"busy":wb.busy() if wb != null else false,"pending":host.pending_microscenario_apply if host != null else {},
		"worker_failed":host.simulation_worker.has_failed() if host != null else true,
		"snapshot_generation":int(host.latest_snapshot.render_world_generation) if host != null and host.latest_snapshot != null else -1})
	return check(false,label+" / "+str(wb.message if wb != null else "no Workbench"))

func idle() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hashing.update(bytes)
	return hashing.finish().hex_encode()

func play_identity() -> Dictionary:
	var bodies: Array[String] = []
	if host.physical_actor_session != null:
		for body: RigidBody2D in host.physical_actor_session.bodies(): bodies.append(str(body.get_instance_id()))
	return {"world_generation":int(host.latest_snapshot.render_world_generation),
		"physical_epoch":int(host._physical_epoch),"worker_id":str(host.simulation_worker.get_instance_id()),
		"actor_session_id":str(host.physical_actor_session.get_instance_id()) if host.physical_actor_session != null else "0",
		"actor_body_ids":bodies,"native_tick":int(host.latest_snapshot.tick_index),
		"rapier_tick":int(host.physical_actor_session.tick) if host.physical_actor_session != null else 0}

func stable_identity(before: Dictionary, after: Dictionary, label: String) -> bool:
	var ok := true
	for key: String in ["world_generation","physical_epoch","worker_id","actor_session_id","actor_body_ids"]:
		ok = check(before[key] == after[key],label+" preserves actual "+key) and ok
	return ok

func settle() -> void:
	for _i: int in 3:
		await process_frame
		await RenderingServer.frame_post_draw

func capture(label: String) -> Image:
	await settle()
	var image: Image = root.get_texture().get_image()
	if check(image != null and not image.is_empty(),"actual framebuffer exists: "+label):
		if not record.has("framebuffers"): record.framebuffers = {}
		record.framebuffers[label] = {"pixels":[image.get_width(),image.get_height()],
			"window_size":[root.size.x,root.size.y],"content_scale_factor":root.content_scale_factor}
		check(image.save_png(output.path_join(label+".png")) == OK,"actual framebuffer saved: "+label)
	return image

func play_bytes() -> PackedByteArray:
	var extent: Vector2i = Setup.extent_of(wb.applied)
	var request: Dictionary = host.simulation_worker.material_capture_request(
		int(host.latest_snapshot.render_world_generation),extent.x*extent.y*2)
	if not check(request.get("ok",false),"read-only play stored-material capture admitted"): return PackedByteArray()
	var token := int(request.token)
	if not await until(func() -> bool: return not host.simulation_worker.material_capture_poll(token).is_empty(),"play native capture complete"):
		host.simulation_worker.material_capture_cancel(token)
		return PackedByteArray()
	var reply: Dictionary = host.simulation_worker.material_capture_poll(token)
	host.simulation_worker.material_capture_finish(token,false)
	if not check(reply.get("ok",false) and reply.get("cells") is PackedByteArray
			and reply.cells.size() == extent.x*extent.y*2,"play native complete LE16 readback"): return PackedByteArray()
	check(digest(reply.cells) == reply.sha256,"play native digest independently recomputes")
	return reply.cells

func decorative_bytes(id: String) -> PackedByteArray:
	var extent: Vector2i = Setup.extent_of(wb.applied)
	var cells := PackedByteArray()
	cells.resize(extent.x*extent.y*2)
	# Read bounded native tiles through the existing paint executor. This is
	# stored-material authority, not a visual packet or authored JSON echo.
	var height: int = maxi(1,16384/extent.x)
	for y: int in range(0,extent.y,height):
		var rows: int = mini(height,extent.y-y)
		var reply: Dictionary = strata.layer_owner.capture_region(id,Rect2i(0,y,extent.x,rows))
		if not check(reply.get("ok",false) and reply.get("materials") is PackedInt32Array
				and reply.materials.size() == extent.x*rows,"bounded native stored-material readback "+id): return PackedByteArray()
		for index: int in reply.materials.size(): cells.encode_u16((y*extent.x+index)*2,int(reply.materials[index]))
	return cells

func reference_bytes(rectangles: Array, extent: Vector2i) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(extent.x*extent.y*2)
	for rectangle: Array in rectangles:
		if rectangle.size() == 5:
			for y: int in range(int(rectangle[1]),int(rectangle[1])+int(rectangle[3])):
				for x: int in range(int(rectangle[0]),int(rectangle[0])+int(rectangle[2])):
					cells.encode_u16((y*extent.x+x)*2,int(rectangle[4]))
		else:
			var radius := int(rectangle[2])
			for y: int in range(maxi(0,int(rectangle[1])-radius),mini(extent.y,int(rectangle[1])+radius+1)):
				for x: int in range(maxi(0,int(rectangle[0])-radius),mini(extent.x,int(rectangle[0])+radius+1)):
					if (x-int(rectangle[0]))**2+(y-int(rectangle[1]))**2 <= radius*radius:
						cells.encode_u16((y*extent.x+x)*2,int(rectangle[3]))
	return cells

func all_native_hashes() -> Dictionary:
	var result := {}
	var extent: Vector2i = Setup.extent_of(wb.applied)
	var play: PackedByteArray = await play_bytes()
	check(play == reference_bytes(wb.applied.edits,extent),"complete native Play equals independently replayed authored geometry")
	result.play = digest(play)
	for id: String in ["scripted","effects","background"]:
		var cells := decorative_bytes(id)
		var expected := reference_bytes(Document.plane(strata.document(),id).rectangles,extent)
		check(cells == expected,"complete native "+id+" equals independently replayed authored geometry")
		result[id] = digest(cells)
	return result

func gesture(layer: String, tool: String, from: Vector2i, to: Vector2i, material: int = 131, radius: int = 0) -> void:
	check(strata.select_layer(layer),"select edit target "+layer)
	wb.paint_editor.select_tool(tool)
	wb.paint_editor.select_material(material)
	wb._brush.value = radius
	strata.presenter.sync_view()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	press.position = strata.presenter.layer_to_screen(Vector2(from)+Vector2(0.5,0.5),layer)
	wb._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = strata.presenter.layer_to_screen(Vector2(to)+Vector2(0.5,0.5),layer)
	motion.relative = motion.position-press.position
	wb._world_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false; release.position = motion.position
	wb._world_input(release)
	await until(idle,"ordinary gesture completes on "+layer)

func backtracking_gesture() -> void:
	check(strata.select_layer("scripted"),"backtracking brush target")
	wb.paint_editor.select_tool("Brush")
	wb.paint_editor.select_material(131)
	wb._brush.value = 2
	var points: Array[Vector2i] = [Vector2i(564,286),Vector2i(564,298),Vector2i(553,286),Vector2i(561,292)]
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	event.position = strata.presenter.layer_to_screen(Vector2(points[0])+Vector2(0.5,0.5),"scripted")
	wb._world_input(event)
	for point: Vector2i in points.slice(1):
		var motion := InputEventMouseMotion.new()
		motion.position = strata.presenter.layer_to_screen(Vector2(point)+Vector2(0.5,0.5),"scripted")
		wb._world_input(motion)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = false
	event.position = strata.presenter.layer_to_screen(Vector2(points.back())+Vector2(0.5,0.5),"scripted")
	wb._world_input(event)
	await until(idle,"backtracking brush terminates")
	for point: Vector2i in points:
		check(strata.layer_owner.material_at("scripted",point) == 131,"backtracking path native target "+str(point))
	record.backtracking_gesture = {"points":4,"native_targets_correct":true}

func ordinary_disabled_baseline() -> void:
	check(wb.strata == null,"ordinary disabled baseline allocates no decorative controller")
	frame_intervals = []; process_times = []; previous_frame_usec = 0
	var snapshot_before: int = host.consumed_snapshot_serial
	var tick_before: int = host.latest_snapshot.tick_index
	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	measuring = true
	for _i: int in 30: await process_frame
	measuring = false
	var baseline_extent: Vector2i = Setup.extent_of(wb.applied)
	record.ordinary_disabled_baseline = {"extent":[baseline_extent.x,baseline_extent.y],"strata_initialized":wb.strata != null,
		"native_tick_before":tick_before,"native_tick_after":host.latest_snapshot.tick_index,
		"snapshot_serial_before":snapshot_before,"snapshot_serial_after":host.consumed_snapshot_serial,
		"godot_tracked_static_memory_before":memory_before,
		"godot_tracked_static_memory_after":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"callback_intervals_usec":frame_intervals.duplicate(),"godot_process_seconds":process_times.duplicate(),
		"scope":"ordinary bootstrap before Strata allocation; diagnostic baseline is not matched scene cost"}

func decorative_publication_hashes() -> Dictionary:
	var values := {}
	for id: String in ["scripted","effects","background"]:
		var packet: Dictionary = strata.layer_owner.snapshot_layer(id,true)
		values[id] = {"cells_sha256":digest(packet.cells),"native_revision":strata.layer_owner.stats().layers[id].native_revision,
			"native_owner":str(strata.layer_owner.stats().layers[id].native_instance_id)}
	return values

func framebuffer_colour(image: Image, point: Vector2i, layer: String) -> Color:
	var local: Vector2 = strata.presenter.layer_to_screen(Vector2(point)+Vector2(0.5,0.5),layer)
	var screen: Vector2 = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()*local
	var pixel := Vector2i(screen.floor())
	if not check(Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel),"material readback pixel lies inside actual framebuffer"):
		return Color.TRANSPARENT
	return image.get_pixelv(pixel)

func all_plane_authoring_and_guards() -> void:
	var view: Dictionary = strata.document().presentation.duplicate(true)
	var checks_by_plane := {}
	var unchanged_play: PackedByteArray = await play_bytes()
	var identity_before := play_identity()
	for id: String in ["scripted","effects","background"]:
		var opacity: float = Document.plane(strata.document(),id).opacity
		check(strata.set_presentation({"enabled":true,"mode":"flat","active":id,"solo":"","fog_strength":0.0,
			"parallax_strength":0.0}),"flat author inspection "+id)
		check(strata.set_layer_option(id,"opacity",1.0),"opaque author inspection "+id)
		var target := Vector2i(596,246)
		var original_material: int = strata.layer_owner.material_at(id,target)
		var marker: int = 131 if original_material != 131 else 58
		var other_planes := decorative_publication_hashes()
		var before: Image = await capture("before-brush-"+id)
		await gesture(id,"Brush",target,target,marker,4)
		check(strata.layer_owner.material_at(id,target) == marker,"actual "+id+" brush reaches native target")
		var painted: Image = await capture("brush-"+id)
		var colour_before := framebuffer_colour(before,target,id)
		var colour_after := framebuffer_colour(painted,target,id)
		var delta := colour_distance(colour_before,colour_after)
		check(delta > 0.025,"actual selected-plane material pixel changes on "+id)
		var after_planes := decorative_publication_hashes()
		for other: String in ["scripted","effects","background"]:
			if other != id: check(other_planes[other] == after_planes[other],"brush leaves complete native "+other+" publication/owner unchanged")
		check(strata.undo_layer(),"Undo "+id+" brush")
		check(strata.layer_owner.material_at(id,target) == original_material,"Undo "+id+" native material")
		check(strata.redo_layer(),"Redo "+id+" brush")
		await gesture(id,"Eraser",target,target,0,4)
		check(strata.layer_owner.material_at(id,target) == 0,"actual "+id+" eraser reaches native target")
		var erased: Image = await capture("erase-"+id)
		check(colour_distance(framebuffer_colour(erased,target,id),colour_after) > 0.025,"actual "+id+" erase pixel differs")
		check(strata.undo_layer(),"Undo "+id+" erase")
		check(strata.layer_owner.material_at(id,target) == marker,"Undo erase restores actual material "+id)
		strata.selection = Rect2i(target-Vector2i(2,2),Vector2i(5,5))
		check(strata.set_layer_option(id,"locked",true),"lock "+id)
		check(strata.copy_selection(),"visible locked "+id+" remains copyable without mutation")
		var copied: PackedInt32Array = strata.clipboard.materials
		check(copied.size() == 25 and copied[12] == marker,"locked copy reads actual selected native cells")
		check(not strata.paste_at(target+Vector2i(16,0)),"locked "+id+" rejects paste")
		await gesture(id,"Eraser",target,target,0,4)
		check(strata.layer_owner.material_at(id,target) == marker,"locked "+id+" rejects actual eraser gesture")
		check(strata.set_layer_option(id,"locked",false),"unlock "+id)
		check(strata.set_layer_option(id,"visible",false),"hide "+id)
		await gesture(id,"Eraser",target,target,0,4)
		check(strata.layer_owner.material_at(id,target) == marker and not strata.copy_selection(),"hidden "+id+" rejects actual gesture/copy")
		check(strata.set_layer_option(id,"visible",true),"show "+id)
		check(strata.set_layer_option(id,"opacity",0.0),"zero opacity "+id)
		await gesture(id,"Eraser",target,target,0,4)
		check(strata.layer_owner.material_at(id,target) == marker and not strata.copy_selection(),"transparent "+id+" rejects gesture/copy")
		check(strata.set_layer_option(id,"opacity",1.0),"restore author opacity "+id)
		check(strata.set_presentation({"mode":"stack","solo":"play"}),"solo excludes "+id)
		await gesture(id,"Eraser",target,target,0,4)
		check(strata.layer_owner.material_at(id,target) == marker and not strata.copy_selection(),"solo-excluded "+id+" rejects gesture/copy")
		check(strata.set_presentation({"solo":""}),"clear solo "+id)
		var boundary_before: String = digest(strata.layer_owner.snapshot_layer(id,true).cells)
		await gesture(id,"Brush",Vector2i(0,246),Vector2i(0,246),marker,4)
		check(digest(strata.layer_owner.snapshot_layer(id,true).cells) == boundary_before,"clipped "+id+" brush is refused completely")
		check(strata.set_layer_option(id,"opacity",opacity),"restore "+id+" scene opacity")
		checks_by_plane[id] = {"brush_native":true,"erase_native":true,"undo_native":true,"pixel_delta":delta,
			"other_native_planes_unchanged":true,"locked_copy_read_only":true,"hidden_input_refused":true,"bounds_refused":true}
	check(strata.set_presentation({"mode":"stack","active":"play","solo":""}),"guard ordinary Play input")
	var before_guards := await play_bytes()
	for guard: String in ["locked","visible","opacity","solo"]:
		if guard == "solo": check(strata.set_presentation({"solo":"background"}),"exclude Play by solo")
		else: check(strata.set_layer_option("play",guard,false if guard == "visible" else (0.0 if guard == "opacity" else true)),"guard Play "+guard)
		await gesture("play","Rectangle",Vector2i(620,240),Vector2i(624,244),131)
		check(await play_bytes() == before_guards,"actual guarded Play "+guard+" gesture changes no native cell")
		if guard == "solo": check(strata.set_presentation({"solo":""}),"clear Play solo guard")
		else: check(strata.set_layer_option("play",guard,true if guard == "visible" else (1.0 if guard == "opacity" else false)),"restore Play "+guard)
	check(await play_bytes() == unchanged_play,"all decorative brush/erase/guards leave complete native Play unchanged")
	stable_identity(identity_before,play_identity(),"all-plane authoring and guards")
	record.all_plane_authoring = checks_by_plane
	record.play_input_guards = ["locked","hidden","opacity_zero","solo_excluded"]
	check(strata.set_presentation(view),"restore sample visual settings")

func panel_controls() -> void:
	var before := play_identity()
	wb.open_strata()
	await settle()
	var panel: PanelContainer = strata._panel
	check(strata._window.visible and panel.is_visible_in_tree(),"actual Strata window and controls mounted")
	panel._active.select(2)
	panel._active.item_selected.emit(2)
	check(strata.active_layer() == "effects","actual panel selection signal selects Effects")
	panel._locked.button_pressed = true
	check(Document.plane(strata.document(),"effects").locked,"actual panel lock signal guards Effects")
	panel._visible.button_pressed = false
	check(not Document.plane(strata.document(),"effects").visible,"actual panel visibility signal hides Effects")
	panel._visible.button_pressed = true
	panel._locked.button_pressed = false
	await settle()
	var frame: Image = strata._window.get_texture().get_image()
	check(not frame.is_empty() and frame.save_png(output.path_join("strata-panel.png")) == OK,"actual Strata panel framebuffer saved")
	record.panel_controls = {"active_target":strata.active_layer(),"target_label":panel._target.text,
		"size":[frame.get_width(),frame.get_height()],"selection_visibility_lock_signals":true,
		"input_scope":"automated Godot control signals; physical owner interaction remains separate"}
	panel._active.select(0)
	panel._active.item_selected.emit(0)
	strata._window.hide()
	stable_identity(before,play_identity(),"panel controls")

func _visibility_fixture_view() -> bool:
	# Preserve the predecessor fixture's Overview unless a successor explicitly
	# requests a controlled native-pixel inspection using the existing camera.
	wb.set_camera(2)
	return false

func play_visibility_pixels() -> void:
	var original: Dictionary = strata.document().presentation.duplicate(true)
	var original_camera_origin: Vector2 = host.camera_origin
	var original_view_size: Vector2i = host.current_view_size
	var background_opacity: float = Document.plane(strata.document(),"background").opacity
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":"","parallax_strength":0.0,"fog_strength":0.0}),"pixel fixture neutral view")
	check(strata.set_layer_option("background","opacity",1.0),"pixel fixture opaque background")
	var requires_native_pixels: bool = _visibility_fixture_view()
	var point := Vector2i(620,240)
	var background_point := Vector2i(596,246)
	var emission_point := Vector2i(650,240)
	var halo_point := emission_point+Vector2i(8,0)
	var play_before := await play_bytes()
	# The background point was independently painted by the all-plane test.
	check(strata.layer_owner.material_at("background",background_point) == 131,"background visibility fixture has actual native material")
	for id: String in ["scripted","effects","background"]:
		await gesture(id,"Eraser",point,point,0,9)
		check(strata.layer_owner.material_at(id,point) == 0,"Play-only point has no rear native material "+id)
		await gesture(id,"Eraser",emission_point,emission_point,0,14)
	check(host.glow_enabled,"ordinary material glow is enabled for its visibility witness")
	var original_glow: Material = strata.presenter._original_glow_shader
	var original_play: Material = strata.presenter._original_shader
	host.set_glow_enabled(false)
	check(strata.set_enabled(false),"disable layers while ordinary glow is off")
	check(not host.glow_enabled and not host.glow_overlay.visible 		and host.glow_overlay.material == original_glow and host.glow_composite_shader == original_glow 		and host.world_view.material == original_play and host.world_shader == original_play,
		"disable restores exact ordinary materials and preserves glow-off selection")
	check(strata.set_enabled(true),"enable layers while ordinary glow is off")
	check(not host.glow_enabled and not host.glow_overlay.visible,"layer enable preserves ordinary glow-off selection")
	host.set_glow_enabled(true)
	check(strata.set_presentation({"active":"background","solo":"background"}),"capture rear-only halo baseline")
	var no_emission: Image = await capture("visibility-before-emissive-marker")
	var halo_baseline := framebuffer_colour(no_emission,halo_point,"play")
	check(strata.set_presentation({"active":"play","solo":""}),"restore Play for emissive fixture")
	await gesture("play","Eraser",background_point,background_point,0,9)
	await gesture("play","Rectangle",point-Vector2i(5,5),point+Vector2i(5,5),58)
	await gesture("play","Rectangle",emission_point-Vector2i(5,5),emission_point+Vector2i(5,5),77)
	var actual: PackedByteArray = await play_bytes()
	check(actual.decode_u16((emission_point.y*Setup.extent_of(wb.applied).x+emission_point.x)*2) == 77,"emissive marker is native Neon cyan77")
	strata.cancel_gesture()
	check(strata.set_presentation({"active":"play","solo":"play"}),"solo Play actual pixel")
	var visible_frame: Image = await capture("visibility-play-solo")
	var visible_colour := framebuffer_colour(visible_frame,point,"play")
	var halo_visible := framebuffer_colour(visible_frame,halo_point,"play")
	var halo_strength := colour_distance(halo_visible,halo_baseline)
	check(halo_strength > 0.01,"ordinary Neon creates an actual halo beyond its native cells")
	check(strata.set_presentation({"solo":"background","active":"background"}),"solo background actual pixel")
	var hidden_frame: Image = await capture("visibility-background-solo")
	var hidden_colour := framebuffer_colour(hidden_frame,point,"play")
	var hidden_delta := colour_distance(visible_colour,hidden_colour)
	check(hidden_delta > 0.04,"background solo actually removes Play-only pixels")
	check(colour_distance(framebuffer_colour(hidden_frame,halo_point,"play"),halo_baseline) < 0.02,"background solo removes additive Play glow")
	var surface: Image = strata.presenter._surfaces.background.get_texture().get_image()
	var rear_colour := framebuffer_colour(hidden_frame,background_point,"background")
	var expected_colour: Color = surface.get_pixelv(background_point)
	var source_colour_error: float = colour_distance(rear_colour,expected_colour)
	var background_visible: bool = source_colour_error < 0.08
	var physical_transform: Transform2D = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()
	var native_centre := Vector2(background_point)+Vector2(0.5,0.5)
	var physical_centre: Vector2 = physical_transform*strata.presenter.layer_to_screen(native_centre,"background")
	var sampled_pixel := Vector2i(physical_centre.floor())
	var pixel_centre_local: Vector2 = physical_transform.affine_inverse()*(Vector2(sampled_pixel)+Vector2(0.5,0.5))
	var sampled_cell := Vector2i(strata.presenter.screen_to_layer(pixel_centre_local,"background").floor())
	var next_x: Vector2 = physical_transform*strata.presenter.layer_to_screen(native_centre+Vector2.RIGHT,"background")
	var next_y: Vector2 = physical_transform*strata.presenter.layer_to_screen(native_centre+Vector2.DOWN,"background")
	var pixels_per_cell := Vector2(physical_centre.distance_to(next_x),physical_centre.distance_to(next_y))
	var sampled_material: int = strata.layer_owner.material_at("background",sampled_cell)
	if requires_native_pixels:
		check(pixels_per_cell.x >= 1.0 and pixels_per_cell.y >= 1.0,"visibility source-colour inspection resolves every native texel")
		check(sampled_cell == background_point and sampled_material == 131,"visibility physical pixel samples the intended native HeatShieldTile texel")
	check(background_visible,"background remains visible with exact opaque source colour")
	var background_probe := {"native_inspection_required":requires_native_pixels,
		"requested_cell":[background_point.x,background_point.y],"sampled_native_cell":[sampled_cell.x,sampled_cell.y],
		"sampled_material":sampled_material,"physical_pixel":[sampled_pixel.x,sampled_pixel.y],
		"projected_native_centre":[physical_centre.x,physical_centre.y],"pixels_per_cell":[pixels_per_cell.x,pixels_per_cell.y],
		"camera_origin":[host.camera_origin.x,host.camera_origin.y],"view_size":[host.current_view_size.x,host.current_view_size.y],
		"expected_rgba":[expected_colour.r,expected_colour.g,expected_colour.b,expected_colour.a],
		"observed_rgba":[rear_colour.r,rear_colour.g,rear_colour.b,rear_colour.a],"max_rgb_error":source_colour_error,"tolerance":0.08,
		"scope":"Actual framebuffer pixel and copied baked native texel; no threshold relaxation."}
	print("STRATA2_PIXEL_ORACLE ",JSON.stringify(background_probe))
	check(strata.set_presentation({"solo":"","mode":"flat"}),"flat nonplay actual pixel")
	var flat_frame: Image = await capture("visibility-flat-background")
	check(colour_distance(framebuffer_colour(flat_frame,point,"play"),hidden_colour) < 0.03,"flat nonplay actually removes Play-only pixels")
	check(colour_distance(framebuffer_colour(flat_frame,halo_point,"play"),halo_baseline) < 0.02,"flat nonplay removes additive Play glow")
	check(strata.set_presentation({"mode":"stack","active":"play"}),"restore stack for Play visibility")
	check(strata.set_layer_option("play","visible",false),"hide Play actual pixel")
	var invisible: Image = await capture("visibility-play-hidden")
	check(colour_distance(framebuffer_colour(invisible,point,"play"),hidden_colour) < 0.03,"hidden Play pixels are absent")
	check(colour_distance(framebuffer_colour(invisible,halo_point,"play"),halo_baseline) < 0.02,"hidden Play glow is absent")
	check(strata.set_layer_option("play","visible",true),"show Play actual pixel")
	check(strata.set_layer_option("play","opacity",0.0),"zero Play opacity")
	var zero: Image = await capture("visibility-play-zero")
	check(colour_distance(framebuffer_colour(zero,point,"play"),hidden_colour) < 0.03,"zero Play opacity actually removes pixels")
	check(colour_distance(framebuffer_colour(zero,halo_point,"play"),halo_baseline) < 0.02,"zero Play opacity removes additive glow")
	check(strata.set_layer_option("play","opacity",0.5),"half Play opacity")
	var half: Image = await capture("visibility-play-half")
	var half_colour := framebuffer_colour(half,point,"play")
	var half_halo := colour_distance(framebuffer_colour(half,halo_point,"play"),halo_baseline)
	check(half_halo > 0.003 and half_halo < halo_strength*0.95,"half Play opacity fades actual additive halo")
	check(colour_distance(half_colour,hidden_colour) > 0.02 and colour_distance(half_colour,visible_colour) > 0.02,
		"half Play opacity is distinct from zero and opaque")
	for channel: int in 3:
		check(half_colour[channel] >= minf(hidden_colour[channel],visible_colour[channel])-0.03 			and half_colour[channel] <= maxf(hidden_colour[channel],visible_colour[channel])+0.03,"half opacity lies between endpoints")
	check(strata.set_layer_option("play","opacity",1.0),"restore opaque Play")
	var opaque: Image = await capture("visibility-play-opaque")
	check(colour_distance(framebuffer_colour(opaque,point,"play"),visible_colour) < 0.03,"opaque Play restores original material colour")
	check(strata.set_enabled(false),"ordinary disabled pixel route")
	var disabled: Image = await capture("visibility-disabled")
	check(colour_distance(framebuffer_colour(disabled,point,"play"),visible_colour) < 0.03,"disabled presentation restores ordinary Play colour")
	check(strata.set_enabled(true),"restore enabled pixel route")
	for _i: int in 3:
		check(wb.paint_editor.undo(),"remove temporary Play visibility fixture")
		await until(idle,"Play visibility fixture Undo")
	for id: String in ["scripted","effects","background"]:
		check(strata.select_layer(id) and strata.undo_layer() and strata.undo_layer(),"restore temporary rear visibility fixture "+id)
	check(await play_bytes() == play_before,"pixel fixture cleanup restores every original Play material")
	check(strata.set_layer_option("background","opacity",background_opacity),"restore background opacity")
	check(strata.set_presentation(original),"restore authored view after visibility proof")
	record.play_visibility_pixels = {"play_only_delta":hidden_delta,"background_remains_visible":background_visible,"background_probe":background_probe,
		"solo_flat_hidden_zero_absent":true,"half_opacity_intermediate":true,"ordinary_restored":true,
		"emissive_material":77,"halo_visible_delta":halo_strength,"halo_half_delta":half_halo,"hidden_halo_absent":true}
	if requires_native_pixels: wb._set_view(original_camera_origin,original_view_size)

func immediate_view_input() -> void:
	var presentation: Dictionary = strata.document().presentation.duplicate(true)
	var opacity: float = Document.plane(strata.document(),"scripted").opacity
	check(strata.set_presentation({"enabled":true,"mode":"flat","active":"scripted","solo":"","fog_strength":0.0,"parallax_strength":0.8}),"scaled pan/zoom target")
	check(strata.set_layer_option("scripted","opacity",1.0),"scaled native target opacity")
	root.content_scale_factor = 1.25
	await settle()
	wb.paint_editor.select_tool("Brush")
	wb.paint_editor.select_material(131)
	wb._brush.value = 5
	strata.presenter.sync_view()
	# Deliberately no presenter refresh or frame between changing the accepted
	# ordinary camera and delivering the next mouse event.
	wb._set_view(Vector2(350.8,177.4),Vector2i(480,270))
	var target := Vector2i(600,300)
	var centre := Vector2(target)+Vector2(0.5,0.5)
	var area: Rect2 = host.view_content_rect()
	var view: Vector2 = Vector2(host.current_view_size)
	var origin: Vector2 = Vector2(host.camera_origin).floor()
	var extent: Vector2 = Vector2(Setup.extent_of(wb.applied))
	var factor: float = 1.0-float(Document.plane(strata.document(),"scripted").depth)*0.8
	var camera_centre := extent*0.5+(origin+view*0.5-extent*0.5)*factor
	var local := area.position+(centre-camera_centre+view*0.5)/view*area.size
	var mapped: Vector2 = strata.presenter.screen_to_layer(local,"scripted")
	check(mapped.distance_to(centre) < 0.01,"same-event camera change maps independently computed target")
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		event.position = host.world_view.get_global_transform_with_canvas()*local
		event.global_position = event.position
		root.push_input(event,true)
	await until(idle,"scaled actual viewport mouse event completes")
	check(strata.layer_owner.material_at("scripted",target) == 131,"actual viewport input paints independent pan/zoom/parallax/scale target")
	strata.cancel_gesture()
	var frame: Image = await capture("scaled-pan-zoom-input")
	var source: Image = strata.presenter._surfaces.scripted.get_texture().get_image()
	var difference := colour_distance(framebuffer_colour(frame,target,"scripted"),source.get_pixelv(target))
	check(difference < 0.08,"opacity1 haze0 composition preserves source material colour at scale1.25")
	check(strata.undo_layer(),"remove scaled input fixture")
	root.content_scale_factor = 1.0
	wb.set_camera(2)
	check(strata.set_layer_option("scripted","opacity",opacity),"restore scaled target opacity")
	check(strata.set_presentation(presentation),"restore view after actual scaled input")
	await settle()
	record.immediate_view_input = {"scale":1.25,"target":[600,300],"native_material":131,
		"inverse_error":mapped.distance_to(centre),"source_colour_error":difference,"viewport_event_injection":true}

func transform_matrix() -> void:
	var samples := 0
	var max_error := 0.0
	for scale: float in [1.0,1.25]:
		root.content_scale_factor = scale
		for view: Array in [[Vector2(0,0),Vector2i(1024,768)],[Vector2(101.8,75.3),Vector2i(640,360)],
				[Vector2(407.4,300.9),Vector2i(480,270)]]:
			wb._set_view(view[0],view[1])
			await settle()
			strata.presenter.sync_view()
			var area: Rect2 = host.view_content_rect()
			for strength: float in [0.0,0.8,1.6]:
				check(strata.set_presentation({"parallax_strength":strength}),"parallax admitted")
				for id: String in IDS:
					for fraction: Vector2 in [Vector2(0.25,0.25),Vector2(0.5,0.5),Vector2(0.75,0.75)]:
						var local := area.position+area.size*fraction
						var cell: Vector2 = strata.presenter.screen_to_layer(local,id)
						var roundtrip: Vector2 = strata.presenter.layer_to_screen(cell,id)
						var error := roundtrip.distance_to(local)
						max_error = maxf(max_error,error)
						samples += 1
						check(error < 0.01,"pan/zoom/parallax/scale roundtrip "+id)
		root.size = Vector2i(1280,800) if scale == 1.0 else Vector2i(1600,1000)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	wb.set_camera(2)
	check(strata.set_presentation({"parallax_strength":0.75}),"restore controlled parallax")
	await settle()
	record.transforms = {"samples":samples,"max_error":max_error,"scales":[1.0,1.25],
		"viewports":[[1600,1000],[1280,800]],"camera_floor_matches_host":true}

func mode_identity() -> void:
	record.transitions = []
	for iteration: int in 3:
		for mode: String in ["disabled","stack","flat","stack"]:
			var before := play_identity()
			if mode == "disabled": check(strata.set_enabled(false),"disable view")
			else:
				check(strata.set_enabled(true),"enable view")
				check(strata.set_mode(mode),"select "+mode)
			await settle()
			var after := play_identity()
			stable_identity(before,after,"toggle "+mode)
			record.transitions.append({"iteration":iteration,"mode":mode,"before":before,"after":after})
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"restore stack")

func author_and_refuse() -> void:
	wb.set_camera(2)
	await settle()
	var play_before := await play_bytes()
	var play_history: int = wb.paint_editor._undo_stack.size()
	var target := Vector2i(514,286)
	var before: int = strata.layer_owner.material_at("scripted",target)
	await gesture("scripted","Rectangle",target,target+Vector2i(7,7),131)
	check(strata.layer_owner.material_at("scripted",target) == 131,"actual native selected-plane write")
	check(wb.paint_editor._undo_stack.size() == play_history,"decorative edit preserves existing play history")
	var played := await play_bytes()
	check(played == play_before,"decorative gesture changes no play cell")
	record.edit_readback = {"material":131,"target_after":strata.layer_owner.material_at("scripted",target),
		"play_hash_before":digest(play_before),"play_hash_after":digest(played),"target":[target.x,target.y]}
	check(strata.undo_layer(),"decorative Undo admitted")
	var undone: bool = strata.layer_owner.material_at("scripted",target) == before
	check(undone,"Undo restores native source material")
	check(strata.redo_layer(),"decorative Redo admitted")
	var redone: bool = strata.layer_owner.material_at("scripted",target) == 131
	check(redone,"Redo restores native result")
	record.undo_redo = {"undo_native":undone,"redo_native":redone}
	# Copy and paste exact native materials, including Empty, through mounted controls.
	strata.selection = Rect2i(target,Vector2i(8,8))
	check(strata.copy_selection(),"bounded native selection copied")
	check(strata.paste_at(target+Vector2i(12,0)),"bounded native clipboard pasted")
	check(strata.layer_owner.material_at("scripted",target+Vector2i(12,0)) == 131,"paste native target readback")
	await backtracking_gesture()
	var refusals := {}
	check(strata.set_layer_option("scripted","locked",true),"lock selected plane")
	refusals.locked = not strata.edit_cells("scripted",PackedInt32Array([target.x,target.y,58]))
	check(refusals.locked and strata.layer_owner.material_at("scripted",target) == 131,"locked edit is nonmutating")
	check(strata.set_layer_option("scripted","locked",false),"unlock")
	check(strata.set_layer_option("scripted","visible",false),"hide selected plane")
	refusals.hidden = not strata.edit_cells("scripted",PackedInt32Array([target.x,target.y,58]))
	check(refusals.hidden and strata.layer_owner.material_at("scripted",target) == 131,"hidden edit is nonmutating")
	check(strata.set_layer_option("scripted","visible",true),"show selected plane")
	refusals.outside = not strata.edit_cells("scripted",PackedInt32Array([-1,target.y,58]))
	check(refusals.outside,"out-of-bounds exact edit refused")
	var native_before: Dictionary = strata.layer_owner.stats()
	var saved_doc: Dictionary = strata.document()
	var malformed := saved_doc.duplicate(true)
	malformed.planes[2].id = "scripted"
	refusals.invalid_document = not strata.load_document({"setup":wb.applied,"document":malformed}) \
		and not strata.load_document({"setup":wb.applied,"document":{}})
	check(refusals.invalid_document and strata.document() == saved_doc,"invalid complete scene retains authored document")
	check(strata.layer_owner.stats().generation == native_before.generation,"invalid scene retains native generation")
	# Reject a packet from the retired owner even if serial is made very large.
	var packet: Dictionary = strata.layer_owner.snapshot_layer("scripted",true)
	var surface: SubViewport = strata.presenter._surfaces.scripted
	var image_before := digest(surface.cell_image.get_data())
	packet.reset_generation -= 1; packet.serial += 100000
	refusals.stale_generation = not strata.presenter.apply_layer_packet("scripted",packet)
	check(refusals.stale_generation and digest(surface.cell_image.get_data()) == image_before,"stale packet changes no copied pixels")
	for field: String in ["owner_id","revision","extent"]:
		packet = strata.layer_owner.snapshot_layer("scripted",true)
		if field == "owner_id": packet[field] = "unrelated-owner"
		elif field == "revision": packet[field] = int(packet[field])+1000
		else: packet[field] = Vector2i(512,512)
		packet.serial += 100000
		check(not strata.presenter.apply_layer_packet("scripted",packet)
			and digest(surface.cell_image.get_data()) == image_before,"forged "+field+" publication leaves pixels intact")
	for variant: String in ["numeric_owner","float_revision","float_generation","empty_cells","truncated_cells","missing_full","false_full"]:
		packet = strata.layer_owner.snapshot_layer("scripted",true)
		packet.serial += 100000
		match variant:
			"numeric_owner": packet.owner_id = 7
			"float_revision": packet.revision = float(packet.revision)
			"float_generation": packet.reset_generation = float(packet.reset_generation)
			"empty_cells": packet.cells = PackedByteArray()
			"truncated_cells": packet.cells = packet.cells.slice(0,16)
			"missing_full": packet.erase("full_refresh")
			"false_full": packet.full_refresh = false
		var accepted_before: Dictionary = strata.presenter.diagnostics().layers.scripted.identity.duplicate(true)
		check(not strata.presenter.apply_layer_packet("scripted",packet)
			and digest(surface.cell_image.get_data()) == image_before
			and strata.presenter.diagnostics().layers.scripted.identity == accepted_before,
			"malformed "+variant+" cannot advance publication or pixels")
	record.refusals = refusals
	# Ordinary play edits remain the existing mounted paint executor and history.
	check(strata.select_layer("play"),"return to Play edit target")
	var play_target := Vector2i(514,246)
	await gesture("play","Rectangle",play_target,play_target+Vector2i(3,3),58)
	check(wb.paint_editor.history_available("undo"),"ordinary play Undo retained")
	check(wb.paint_editor.undo(),"ordinary play Undo admitted")
	await until(idle,"play Undo settles")
	check(wb.paint_editor.redo(),"ordinary play Redo admitted")
	await until(idle,"play Redo settles")
	check(strata.has_document() and strata.layer_owner.stats().generation == native_before.generation,
		"ordinary play paint/history does not retire decorative composition")
	check(strata.set_presentation({"mode":"stack","active":"play","solo":""}),"restore inspectable stack")

func colour_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func pixels_and_scenes() -> void:
	check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":"","fog_strength":0.2}),"stack for scene capture")
	wb.set_camera(2)
	await capture("composite")
	for id: String in IDS:
		check(strata.set_presentation({"solo":id,"active":id}),"solo "+id)
		var frame: Image = await capture("plane-"+id)
		check(frame.get_data().size() > 0,"plane framebuffer has pixels "+id)
	check(strata.set_presentation({"solo":"","mode":"stack","active":"play"}),"restore composite")
	# The same composed region must actually differ from ordinary Play display.
	var stack: Image = await capture("stack")
	check(strata.set_enabled(false),"disable for matched flat inspection")
	var flat: Image = await capture("disabled")
	var changed := 0
	var area: Rect2 = host.view_content_rect()
	var image_transform: Transform2D = root.get_stretch_transform()*host.world_view.get_global_transform_with_canvas()
	var image_area: Rect2 = image_transform*area
	for y: int in range(maxi(0,int(image_area.position.y)+5),mini(flat.get_height(),int(image_area.end.y)-5),9):
		for x: int in range(maxi(0,int(image_area.position.x)+5),mini(flat.get_width(),int(image_area.end.x)-5),9):
			if colour_distance(flat.get_pixel(x,y),stack.get_pixel(x,y)) > 0.025: changed += 1
	check(changed > 100,"four planes visibly change actual composite region")
	record.changed_composite_samples = changed
	check(strata.set_enabled(true),"restore layered view")

func cost(mode: String) -> Dictionary:
	if mode == "disabled": strata.set_enabled(false)
	else:
		strata.set_enabled(true)
		strata.set_presentation({"mode":mode,"active":"play","solo":""})
	await settle()
	frame_intervals = []; process_times = []; previous_frame_usec = 0
	var start := Time.get_ticks_usec()
	var uploads: int = strata.presenter.diagnostics().full_rg8_uploads
	var native_snapshots: int = strata.layer_owner.stats().native_snapshot_calls
	measuring = true
	for _i: int in 45: await process_frame
	measuring = false
	var ordered := frame_intervals.duplicate(); ordered.sort()
	var wall := Time.get_ticks_usec()-start
	check(strata.presenter.diagnostics().full_rg8_uploads == uploads,"static "+mode+" frames make no uploads")
	check(strata.layer_owner.stats().native_snapshot_calls == native_snapshots,"static "+mode+" frames take no native snapshots")
	return {"mode":mode,"elapsed_usec":wall,"callback_intervals_usec":frame_intervals.duplicate(),
		"callback_p50_usec":ordered[ordered.size()/2] if not ordered.is_empty() else 0,
		"callback_p95_usec":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)] if not ordered.is_empty() else 0,
		"callback_max_usec":ordered.back() if not ordered.is_empty() else 0,
		"godot_process_seconds":process_times.duplicate(),"godot_tracked_static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"native_snapshots_during_sample":strata.layer_owner.stats().native_snapshot_calls-native_snapshots,
		"decorative_uploads_during_sample":strata.presenter.diagnostics().full_rg8_uploads-uploads,
		"resource_state":"composition resources retained in disabled, flat and stack",
		"scope":"main callbacks and Godot tracked memory; not presented physical GPU FPS or total native RSS"}

func actual_play() -> void:
	var before := play_identity()
	var position: Vector2 = host.physical_actor_session.workbench_actor_state(wb.selected_id()).position
	check(wb.toggle_pause(),"ordinary actor play resumes")
	var target := int(host.physical_actor_session.tick)+10
	await until(func() -> bool: return int(host.physical_actor_session.tick) >= target,"actual retained Rapier progression")
	check(strata.set_enabled(false) and strata.set_enabled(true),"toggle presentation during ordinary play")
	var after := play_identity()
	var moved: Vector2 = host.physical_actor_session.workbench_actor_state(wb.selected_id()).position
	stable_identity(before,after,"live play toggle")
	check(int(after.rapier_tick) > int(before.rapier_tick) and moved.distance_to(position) > 0.0001,
		"actual actor pose and Rapier ticks progress")
	check(wb.toggle_pause(),"ordinary actor play pauses")
	await until(idle,"pause settles")
	record.actual_play = {"before":before,"after":after,"position_before":[position.x,position.y],
		"position_after":[moved.x,moved.y],"distance":moved.distance_to(position)}

func run() -> void:
	scene_id = OS.get_environment("STRATA_SCENE")
	phase = OS.get_environment("STRATA_PHASE")
	output = OS.get_environment("STRATA_EVIDENCE")
	save_name = "strata-qualified-"+scene_id
	record = {"schema":"strata-workbench-execution-v1","scene":scene_id,"phase":phase,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"completed":false,
		"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_adapter":RenderingServer.get_video_adapter_name(),"process_id":OS.get_process_id()}
	if not check(DisplayServer.get_name() != "headless","qualification requires an actual rendering display") \
		or not check(scene_id in Scenes.IDS and phase in ["install","reopen"] and not output.is_empty(),"explicit scene/phase/evidence inputs"):
		finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	set_meta("cybersand_feature","shared_workbench")
	var bootstrap_start := Time.get_ticks_msec()
	host = load("res://main.tscn").instantiate()
	print("STRATA_PROGRESS instantiate ordinary Main")
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	# Configure the ordinary extent controls before deferred New Canvas starts.
	# This bounds bootstrap memory; every real scene still adopts its own extent.
	for control: SpinBox in wb._extent: control.value = 512
	record.startup_extent = [512,512]
	print("STRATA_PROGRESS ordinary Main ready; wait for512canvas")
	if not await until(idle,"ordinary Workbench startup",180000): finish(); return
	record.bootstrap_elapsed_ms = Time.get_ticks_msec()-bootstrap_start
	check(wb.strata == null,"disabled ordinary startup has no Strata owners or presentation")
	record.ordinary_workbench = wb.get_script().resource_path == "res://scripts/shared_workbench.gd"
	print("STRATA_PROGRESS ordinary Workbench admitted")
	await ordinary_disabled_baseline()
	strata = wb.ensure_strata()
	if phase == "install":
		check(not FileAccess.file_exists(Setup._path(save_name)),"install uses a pristine user profile")
		if not check(strata.load_demo(scene_id),"native sample scene requested"): finish(); return
	else:
		wb._name.text = save_name
		if not check(wb.load_setup(),"ordinary named scene loader requested"): finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,
			"play and all three decorative native owners adopted"): finish(); return
	check(host.paused,"authored composition begins paused")
	var owners: Dictionary = strata.layer_owner.stats()
	check(owners.native_world_count == 3 and not owners.owns_play_world,"exactly three decorative owners and borrowed Play")
	record.world_count = {"play_borrowed":1,"decorative_owned":owners.native_world_count}
	print("STRATA_PROGRESS four native planes admitted")
	if phase == "install":
		await capture("reference-composite")
		await panel_controls()
		print("STRATA_PROGRESS mode identity")
		await mode_identity()
		print("STRATA_PROGRESS transforms")
		await transform_matrix()
		print("STRATA_PROGRESS author and refuse")
		await author_and_refuse()
		print("STRATA_PROGRESS all-plane actual brush/erase guards")
		await all_plane_authoring_and_guards()
		print("STRATA_PROGRESS actual visibility and scaled input")
		await play_visibility_pixels()
		await immediate_view_input()
		print("STRATA_PROGRESS actual pixels")
		await pixels_and_scenes()
		print("STRATA_PROGRESS bounded costs")
		record.cost_samples = []
		for mode: String in ["disabled","flat","stack"]: record.cost_samples.append(await cost(mode))
		check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"save complete stack")
		print("STRATA_PROGRESS all native material cells")
		record.plane_native_hashes = await all_native_hashes()
		var undo_before: int = wb.paint_editor._undo_stack.size()
		wb._name.text = save_name
		check(wb.save_setup(),"ordinary Save start persists all four planes")
		check(wb.paint_editor._undo_stack.size() == undo_before,"Save preserves play Undo")
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
		await actual_play()
	else:
		check(strata.set_presentation({"enabled":true,"mode":"stack","active":"play","solo":""}),"reopened stack is inspectable")
		print("STRATA_PROGRESS all native material cells")
		record.plane_native_hashes = await all_native_hashes()
		record.fresh_process_reopen = true
		record.save = {"path":ProjectSettings.globalize_path(Setup._path(save_name)),"sha256":FileAccess.get_sha256(Setup._path(save_name))}
		await capture("fresh-reopen")
	record.final_diagnostics = strata.diagnostics()
	finish()

func finish() -> void:
	var retained_owner: RefCounted = strata.layer_owner if is_instance_valid(strata) else null
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	if retained_owner != null:
		var retired: Dictionary = retained_owner.stats()
		check(retired.native_world_count == 0 and retired.pending_native_world_count == 0,"ordinary host teardown retires all decorative native owners")
		record.teardown = retired
	record.checks = checks
	record.failures = failures
	record.completed = true
	var path := OS.get_environment("STRATA_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(record,"\t")+"\n")
			file.close()
	print("STRATA_WORKBENCH ",JSON.stringify({"checks":checks,"failures":failures,"scene":scene_id,"phase":phase}))
	quit(0 if failures.is_empty() else 1)
