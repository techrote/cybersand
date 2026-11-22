extends SceneTree

# ENGINE-LAB-001: real Workbench host, real simulation-worker and UI callbacks.
const WindowPolicy = preload("res://scripts/workbench_lab_window_policy.gd")
const Publisher = preload("res://scripts/blit_material_publisher.gd")
const TIMEOUT_MS: int = 90000
var assertions: int = 0
var failures: Array[String] = []
var host: Control
var menu: Window
var observations: Array[Dictionary] = []
var root_settings: Dictionary = {}
var marker_clicks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, explanation: String) -> void:
	assertions += 1
	if not ok:
		failures.append(explanation)
		push_error("ENGINE_LAB_001: "+explanation)

func _settle() -> void:
	for frame: int in range(3): await process_frame


func _root_configuration() -> Dictionary:
	return {"content_scale_size":root.content_scale_size,
		"content_scale_mode":root.content_scale_mode,
		"content_scale_factor":root.content_scale_factor,
		"gui_embed_subwindows":root.gui_embed_subwindows}


func _queue_receipt() -> bool:
	var completed := Semaphore.new()
	# This bound callback invokes only the native Semaphore on the render owner.
	RenderingServer.call_on_render_thread(completed.post.unbind(1).bind(completed))
	var end: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < end:
		if completed.try_wait(): return true
		await process_frame
	return false


func _image_hash(pixels: Image) -> String:
	var copy: Image = pixels.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(copy.get_data())
	return context.finish().hex_encode()


func _layout_observation(label: String, requested: Vector2i) -> void:
	var separate: bool = WindowPolicy.uses_separate_rendering()
	var menu_scale: Vector2 = menu.get_screen_transform().get_scale()
	var field: SpinBox = menu._widgets["fps"]
	# CanvasItem.get_screen_transform is a popup-placement transform here;
	# it stops at the embedding root. Window's full transform includes root stretch.
	var field_popup_scale: Vector2 = field.get_screen_transform().get_scale()
	var field_scale: Vector2 = (menu.get_screen_transform()*field.get_global_transform_with_canvas()).get_scale()
	var root_rect: Rect2 = root.get_screen_transform() * Rect2(Vector2.ZERO,root.get_visible_rect().size)
	var menu_rect: Rect2 = menu.get_screen_transform() * Rect2(Vector2.ZERO,menu.get_visible_rect().size)
	var framebuffer: Image = menu.get_texture().get_image()
	check(framebuffer != null and not framebuffer.is_empty(),label+" actual GPU framebuffer can be read")
	var texture_size: Vector2 = Vector2(framebuffer.get_size()) if framebuffer != null else Vector2.ZERO
	var placement: Dictionary = menu.get_meta("lab_window_placement",{})
	check(field_scale.is_equal_approx(Vector2.ONE),label+" controls retain one physical pixel per UI unit")
	check(is_equal_approx(menu.get_oversampling(),1.0),label+" font rasterization matches the actual physical 1x scale")
	check(texture_size.x >= 739 and texture_size.y >= 519,
		label+" framebuffer retains the declared minimum physical client")
	if separate:
		check(menu.is_embedded() and menu.get_window_id()==root.get_window_id(),
			label+" uses the existing root surface without a native child")
		check(root_rect.grow(1.0).encloses(menu_rect),label+" actual physical client fits inside root")
		var scale: float = float(placement.get("parent_scale",0.0))
		var title_height: float = float(menu.get_theme_constant("title_height"))*scale
		check(title_height >= 34.0 and title_height <= 38.0,
			label+" embedded title retains a readable physical height")
		var decorated := Rect2(menu_rect.position-Vector2(2,title_height),menu_rect.size+Vector2(4,title_height+2))
		check(root_rect.grow(1.0).encloses(decorated),label+" title and borders fit inside the root")
		check(bool(placement.get("admitted",false)),label+" has an explicit capacity admission")
		check(absf(texture_size.x-menu_rect.size.x)<=2.0 and absf(texture_size.y-menu_rect.size.y)<=2.0,
			label+" actual framebuffer dimensions agree with physical client bounds")
	check(_root_configuration()==root_settings,label+" leaves parent canvas and embedding policy unchanged")
	var glyph_regions: Dictionary = {}
	if framebuffer != null:
		for key: String in ["fps","render","pixel"]:
			var title_label: Label = menu._widgets[key].get_parent().get_child(0)
			var region := Rect2i(title_label.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,framebuffer.get_size()))
			glyph_regions[key] = {"size":[region.size.x,region.size.y],
				"sha256":_image_hash(framebuffer.get_region(region)),"font_size":title_label.get_theme_font_size("font_size")}
	observations.append({"case":label,"requested_physical":[requested.x,requested.y],
		"separate":separate,"embedded":menu.is_embedded(),"native_windows":DisplayServer.get_window_list().size(),
		"root_size":[root.size.x,root.size.y],"popup_size":[menu.size.x,menu.size.y],
		"client_physical":[menu_rect.position.x,menu_rect.position.y,menu_rect.size.x,menu_rect.size.y],
		"framebuffer_size":[texture_size.x,texture_size.y],"popup_screen_scale":[menu_scale.x,menu_scale.y],
		"control_popup_scale":[field_popup_scale.x,field_popup_scale.y],
		"control_physical_scale":[field_scale.x,field_scale.y],"content_scale_factor":menu.content_scale_factor,
		"root_stretch_scale":root.get_stretch_transform().get_scale(),"placement":placement,
		"font_oversampling":menu.get_oversampling(),"glyph_regions":glyph_regions})


func _marker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		marker_clicks += 1


func _validate_composited_pixels_and_input() -> void:
	var separate: bool = WindowPolicy.uses_separate_rendering()
	var marker := ColorRect.new()
	marker.color = Color(1,0,1,1)
	marker.position = Vector2(35,35)
	marker.size = Vector2(23,11)
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	marker.gui_input.connect(_marker_input)
	menu.add_child(marker)
	await _settle()
	await RenderingServer.frame_post_draw
	var viewport: Window = root if separate else menu
	var pixels: Image = viewport.get_texture().get_image()
	check(pixels != null and not pixels.is_empty(),"composited window framebuffer is available")
	if pixels != null and not pixels.is_empty():
		var transform: Transform2D = menu.get_screen_transform()*marker.get_global_transform_with_canvas()
		var expected_rect: Rect2 = transform*Rect2(Vector2.ZERO,marker.size)
		var region := Rect2i(expected_rect.grow(3.0)).intersection(Rect2i(Vector2i.ZERO,pixels.get_size()))
		var minimum := Vector2i(2147483647,2147483647)
		var maximum := Vector2i(-1,-1)
		var count: int = 0
		for y: int in range(region.position.y,region.end.y):
			for x: int in range(region.position.x,region.end.x):
				var color: Color = pixels.get_pixel(x,y)
				if color.r>0.99 and color.g<0.01 and color.b>0.99:
					minimum = minimum.min(Vector2i(x,y))
					maximum = maximum.max(Vector2i(x,y))
					count += 1
		var extent := maximum-minimum+Vector2i.ONE if count>0 else Vector2i.ZERO
		check(extent==Vector2i(23,11) and count==23*11,
			"actual root/native pixels preserve the 23×11 UI-unit marker exactly")
		var before: int = marker_clicks
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = Vector2(minimum)+Vector2(extent)*0.5
		viewport.push_input(event)
		event = event.duplicate()
		event.pressed = false
		viewport.push_input(event)
		await process_frame
		check(marker_clicks==before+1,"physical framebuffer point maps through the actual popup input route once")
		observations.append({"case":"composited physical marker","separate":separate,
			"framebuffer_size":[pixels.get_width(),pixels.get_height()],"pixel_extent":[extent.x,extent.y],
			"pixel_count":count,"mapped_input_count":marker_clicks-before,
			"expected_rect":[expected_rect.position.x,expected_rect.position.y,expected_rect.size.x,expected_rect.size.y]})
	marker.queue_free()
	await process_frame
	var selector: OptionButton = menu._widgets["vsync"]
	var windows: int = DisplayServer.get_window_list().size()
	selector.show_popup()
	await _settle()
	var popup: PopupMenu = selector.get_popup()
	var scale: Vector2 = popup.get_screen_transform().get_scale()
	check(popup.visible and scale.is_equal_approx(Vector2.ONE),
		"ordinary VSync dropdown retains readable physical scaling")
	if separate:
		check(popup.is_embedded() and popup.get_window_id()==root.get_window_id() and
			DisplayServer.get_window_list().size()==windows,
			"VSync dropdown also uses the root rendering surface")
	var popup_pixels: Image = popup.get_texture().get_image()
	check(popup_pixels != null and not popup_pixels.is_empty(),"actual dropdown framebuffer is readable")
	observations.append({"case":"VSync dropdown","embedded":popup.is_embedded(),
		"physical_scale":[scale.x,scale.y],"content_scale_factor":popup.content_scale_factor,
		"font_oversampling":popup.get_oversampling(),"framebuffer_sha256":_image_hash(popup_pixels) if popup_pixels != null else "",
		"framebuffer_size":popup_pixels.get_size() if popup_pixels != null else Vector2i.ZERO})
	check(is_equal_approx(popup.get_oversampling(),1.0),"dropdown glyphs also rasterize at physical 1x scale")
	popup.hide()
	await _settle()


func _validate_native_vsync_and_input() -> void:
	var original: int = DisplayServer.window_get_vsync_mode()
	for requested: int in [DisplayServer.VSYNC_DISABLED,DisplayServer.VSYNC_ENABLED]:
		var before: int = DisplayServer.window_get_vsync_mode()
		menu._widgets["vsync"].item_selected.emit(requested)
		check(await _queue_receipt(),"native VSync request returns before its native queue receipt")
		var reported: int = DisplayServer.window_get_vsync_mode()
		check(reported >= DisplayServer.VSYNC_DISABLED and reported <= DisplayServer.VSYNC_MAILBOX,
			"VSync readback remains a valid cached display-server mode")
		if OS.get_name()=="Windows" and DisplayServer.get_name()!="headless":
			check(reported==requested,"Windows Disabled/Enabled request updates the accepted mode after native dispatch")
		observations.append({"case":"native VSync dispatch","requested":requested,"before":before,
			"reported":reported,"separate":WindowPolicy.uses_separate_rendering(),
			"scope":"Native setter returned on rendering owner; cached mode is not physical scanout proof."})
	WindowPolicy.request_vsync(original)
	check(await _queue_receipt(),"VSync restore finishes through the same native queue")
	var paused: bool = host.paused
	var steps: int = host.shared_workbench.step_serial
	var edits: Array = host.shared_workbench.applied.edits.duplicate(true)
	var camera: int = host.shared_workbench._camera.selected
	var field: SpinBox = menu._widgets["fps"]
	field.get_line_edit().grab_focus()
	field.get_line_edit().select_all()
	for character: String in ["8","3"]:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = character.unicode_at(0)
		key.keycode = character.unicode_at(0)
		menu.push_input(key)
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	menu.push_input(enter)
	await process_frame
	check(int(field.value)==83 and Engine.max_fps==83,
		"actual popup keyboard input edits the live FPS control")
	field.get_line_edit().release_focus()
	for code: Key in [KEY_P,KEY_PERIOD,KEY_F]:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = code
		menu.push_input(key)
		key = key.duplicate()
		key.pressed = false
		menu.push_input(key)
	await _settle()
	check(host.paused==paused and host.shared_workbench.step_serial==steps,
		"Lab shortcuts do not pause, resume or single-step the underlying Workbench")
	check(host.shared_workbench.applied.edits==edits and host.shared_workbench._camera.selected==camera,
		"Lab input does not paint or change the underlying camera")
	menu.reset_baseline()
	check(await _queue_receipt(),"baseline VSync reset is ordered before cleanup")


func _validate_visible_layout() -> void:
	# Regress the owner's collapsed-label screenshot and the Separate renderer's
	# native-window GL context failure, using actual physical framebuffer bounds.
	var separate: bool = WindowPolicy.uses_separate_rendering()
	var initial_windows: int = DisplayServer.get_window_list().size()
	var original_root_size: Vector2i = root.size
	root_settings = _root_configuration()
	if DisplayServer.get_name() != "headless": root.size = Vector2i(1280,720)
	await _settle()
	menu.open()
	await _settle()
	check(menu.visible,"Engine Lab opens through the ordinary button target")
	check(menu.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,
		"Engine Lab layout uses physical-pixel scaling")
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web") \
			and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		check(menu.force_native==(not separate),
			"Safe retains native Labs and Separate selects the embedded policy")
		check(DisplayServer.get_window_list().size()==initial_windows+(0 if separate else 1),
			"actual native-window inventory matches the selected policy")
	for width: int in [900,760]:
		if separate: WindowPolicy.fit_embedded(menu,Vector2i(width,650))
		else: menu.size = Vector2i(width,650)
		await _settle()
		for key: String in ["fps","render","ack","pixel","rapier","workers"]:
			var field: SpinBox = menu._widgets[key]
			var row: Control = field.get_parent()
			var title_label: Label = row.get_child(0) as Label
			check(row is HBoxContainer,"%s uses a nonwrapping horizontal field row" % key)
			check(title_label != null and title_label.autowrap_mode == TextServer.AUTOWRAP_OFF and
				title_label.size.x >= 300.0 and title_label.size.y <= 48.0,
				"%s label remains horizontal at window width %d" % [key,width])
			check(field.size.x >= 145.0 and field.size.y <= 50.0,
				"%s SpinBox is bounded, not full-height" % key)
			check(field.position.x >= title_label.position.x + title_label.size.x - 1.0,
				"%s input follows label without overlap" % key)
			check(field.position.x + field.size.x <= row.size.x + 2.0,
				"%s input fits the content column" % key)
		var vsync: OptionButton = menu._widgets["vsync"]
		check(vsync.get_parent() is HBoxContainer and vsync.size.y <= 50.0 and vsync.size.x >= 200.0,
			"VSync selector keeps normal one-row dimensions")
		if DisplayServer.get_name() != "headless": _layout_observation("client-%d" % width,Vector2i(width,650))
	if separate:
		root.size = Vector2i(1600,900)
		await _settle()
		_layout_observation("parent-resize",Vector2i(760,650))
		var identity: int = menu.get_instance_id()
		menu.close_requested.emit()
		check(not menu.visible,"embedded close uses the existing ordinary close seam")
		menu.open()
		await _settle()
		check(menu.visible and menu.get_instance_id()==identity,"embedded Lab reopens its retained controls")
		_layout_observation("reopen",Vector2i(760,650))
		root.size = Vector2i(500,400)
		await _settle()
		menu.open()
		check(not menu.visible and not menu.get_meta("lab_window_placement",{}).get("admitted",true),
			"insufficient parent capacity refuses the declared physical minimum")
		check(_root_configuration()==root_settings,"capacity refusal does not change the parent scale or embedding")
		root.size = Vector2i(1280,720)
		await _settle()
		menu.open()
		await _settle()
		check(menu.visible,"Lab recovers when the parent again has sufficient capacity")
		_layout_observation("recovered",Vector2i(760,650))
	if DisplayServer.get_name() != "headless": await _validate_composited_pixels_and_input()
	await _validate_native_vsync_and_input()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot_path: String = OS.get_environment("CYBERSAND_ENGINE_LAB_SCREENSHOT")
		if not screenshot_path.is_empty():
			var capture: Image = menu.get_texture().get_image()
			check(capture != null and not capture.is_empty(),"actual Engine Lab framebuffer is readable")
			if capture != null and not capture.is_empty():
				check(capture.save_png(screenshot_path)==OK,"graphical Engine Lab screenshot saved")
				if separate:
					var root_capture: Image = root.get_texture().get_image()
					check(root_capture != null and not root_capture.is_empty() and
						root_capture.save_png(screenshot_path.get_basename()+"-root.png")==OK,
						"embedded title, controls and surrounding Workbench framebuffer saved")
	menu.hide()
	if DisplayServer.get_name() != "headless": root.size = original_root_size
	await _settle()
	check(_root_configuration()==root_settings,"Lab teardown preserves parent canvas and embedding state")


func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	var end: int = Time.get_ticks_msec()+TIMEOUT_MS
	while Time.get_ticks_msec()<end:
		if host.shared_workbench != null and not host.shared_workbench.applied.is_empty():
			break
		if host.simulation_worker.has_failed(): break
		await process_frame
	check(host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),
		"real native Workbench installed")
	if host.shared_workbench != null:
		menu = host.shared_workbench.engine_lab
	check(menu != null and menu.has_method("reset_baseline"),
		"second-layer performance menu mounted")
	if menu != null:
		check(menu._widgets.has("fps") and menu._widgets.has("vsync") and
			menu._widgets.has("render") and menu._widgets.has("ack") and
			menu._widgets.has("pixel") and menu._widgets.has("rapier") and
			menu._widgets.has("workers") and menu._widgets.has("wait_sample") and
			menu._widgets.has("sample_wake") and menu._widgets.has("publication"),"all requested controls exist")
		check(host.engine_lab_wait_native_sample and
			host.engine_lab_ack_delay_frames==0 and
			int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==60,
			"default coupling, ACK, and native tick unchanged")
		var before_publication_revision: int = host.last_uploaded_revision
		menu._widgets["publication"].item_selected.emit(1)
		check(host.material_publication_status().requested_mode=="full" and
			host.material_publication_status().backend=="full" and
			host.material_publication_status().policy=="" and
			host.last_uploaded_revision==before_publication_revision,
			"live full texture control retains the accepted material revision")
		menu._widgets["publication"].item_selected.emit(0)
		check(host.material_publication_status().requested_mode=="auto" and
			host.last_uploaded_revision==before_publication_revision,
			"live automatic publication restores selection without a native edit")
		menu._widgets["publication"].item_selected.emit(2)
		var publication_state: Dictionary = host.material_publication_status()
		check(publication_state.requested_mode == "blit" and host.last_uploaded_revision == before_publication_revision
			and "Requested: Incremental GPU" in menu._publication_status.text,
			"incremental request is displayed separately from its effective backend")
		check(publication_state.policy == "" and not "Windows software renderer" in menu._publication_status.text,
			"current publication has no automatic software-renderer override or obsolete explanation")
		if Publisher.supported_driver():
			check(publication_state.backend == "blit" and publication_state.fallback_reason == ""
				and "Active: Incremental GPU" in menu._publication_status.text
				and not "could not be changed" in menu._status.text,
				"supported graphical backend executes the requested sparse publisher and displays it")
		else:
			check(publication_state.backend == "full" and not publication_state.fallback_reason.is_empty()
				and "Active: Full texture" in menu._publication_status.text,
				"unsupported renderer reports its actual full fallback and reason")
		menu._widgets["publication"].item_selected.emit(0)
		menu._widgets["fps"].value = 144
		check(Engine.max_fps==144,"UI changes live render FPS cap")
		menu._widgets["pixel"].value = 30
		check(int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==30,
			"Pixel tick target reaches worker")
		menu._widgets["sample_wake"].button_pressed = false
		check(not bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake),
			"native sample wake can be uncoupled")
		menu._widgets["wait_sample"].button_pressed = false
		check(not host.engine_lab_wait_native_sample,
			"Rapier native-sample wait can be uncoupled")
		menu._widgets["rapier"].value = 120
		check(Engine.physics_ticks_per_second==120,
			"Rapier callback target changes live")
		menu._widgets["render"].value = 90
		check(host.render_snapshot_hz==90,
			"render snapshot target changes live")
		menu._widgets["ack"].value = 2
		check(host.engine_lab_ack_delay_frames==2,
			"render ACK delay changes live")
		var preview: Dictionary = menu.configuration()
		check(int(preview.pixel_target_hz)==30 and
			not bool(preview.rapier_waits_for_native_sample) and
			int(preview.render_target_hz)==90,
			"configuration readback reflects the actual controls")
		menu.reset_baseline()
		check(Engine.physics_ticks_per_second==60 and
			host.render_snapshot_hz==60 and
			host.engine_lab_ack_delay_frames==0 and
			host.engine_lab_wait_native_sample,
			"reset restores baseline physics, render and sync")
		check(bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake)
			and int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==60,
			"reset restores worker wake and Pixel target")
		check(not host.engine_lab_set_scripted_input(true),
			"scripted benchmark cannot seize a paused flyer")
		await _validate_visible_layout()
	host.queue_free()
	await process_frame
	await process_frame
	var report := {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":assertions,"failures":failures,"observations":observations,
		"runtime":"real Main/Workbench/natively built World",
		"render_thread":"separate" if WindowPolicy.uses_separate_rendering() else "safe",
		"controls":"fps,vsync,render,pixel,rapier,ack,native_sample_gate,native_wake,workers,benchmark"}
	var output: String = OS.get_environment("CYBERSAND_ENGINE_LAB_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		check(file != null,"Engine Lab receipt output opens")
		report.checks = assertions
		if file != null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ENGINE_LAB_RESULT ",JSON.stringify(report))
	quit(int(not failures.is_empty()))
