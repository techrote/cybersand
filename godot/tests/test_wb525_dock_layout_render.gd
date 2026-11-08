extends "res://tests/test_wb525_capacity_and_camera_render.gd"
## Actual viewport GUI dispatch, real native paint readback, original frames.

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame

func rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)

func mouse(p: Vector2, index: int = 0, pressed: bool = false, delta: Vector2 = Vector2.ZERO) -> void:
	var event: InputEventMouse
	if index == 0:
		var motion := InputEventMouseMotion.new()
		motion.relative = delta
		motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE if pressed else 0
		event = motion
	else:
		var button := InputEventMouseButton.new()
		button.button_index = index
		button.pressed = pressed
		event = button
	event.position = p
	event.global_position = p
	root.push_input(event,true)
	await process_frame

func inspect_layout(screen: Vector2i, sequence: int) -> void:
	root.content_scale_size = screen
	root.size = screen
	mount._toggle.button_pressed = false
	await settle()
	wb._zoom = 1
	wb._set_view(Vector2(600.25+sequence*200,600.75),Vector2i(480,270))
	var origin: Vector2 = host.camera_origin
	var view: Vector2i = host.current_view_size
	var hidden: Rect2 = rect(host.world_view)
	mount._toggle.button_pressed = true
	await settle()
	var shown: Rect2 = rect(host.world_view)
	var dock: Rect2 = rect(mount._dock)
	check(shown.size.y >= hidden.size.y-2 and shown.size.y > screen.y*0.45,"agent form crushed canvas height")
	check(shown.size.x > screen.x*0.55 and root.get_visible_rect().encloses(shown),"canvas too small or outside window")
	check(dock.size.x <= 360 and not dock.intersects(shown),"dock overlaps or expands across canvas")
	check(host.camera_origin == origin and host.current_view_size == view,"dock toggle changed camera")
	check(absf(rect(panel._start).position.y - rect(panel._stop).position.y) < 2,"Start/Stop not in one row")
	check(rect(panel._task).size.y >= 189,"prompt shrunk")
	check(absf(rect(panel._region[0]).position.y - rect(panel._region[3]).position.y) < 2,"scope coordinates wrapped")
	check(absf(rect(panel._guard_region[0]).position.y - rect(panel._guard_region[3]).position.y) < 2,"Protect coordinates wrapped")
	check(not panel._log.is_inside_tree() and not panel._signed_frame.is_inside_tree(),"legacy controls consume space")
	check(not panel._traffic.visible,"traffic opened uninvited")
	var stop_rect: Rect2 = rect(panel._stop)
	var stop_relative := Rect2(stop_rect.position-dock.position,stop_rect.size)
	panel._form_scroll.scroll_vertical = 100000
	await settle()
	var stop_after: Rect2 = rect(panel._stop)
	var stop_after_relative := Rect2(stop_after.position-rect(mount._dock).position,stop_after.size)
	var scroll_bar: VScrollBar = panel._form_scroll.get_v_scroll_bar()
	var scroll_limit: float = maxf(0.0,scroll_bar.max_value-scroll_bar.page)
	# Async toolbar wrapping may move the entire dock after a window resize.
	# Scrolling must leave Stop pinned inside that dock and inside the viewport.
	check(stop_after_relative.is_equal_approx(stop_relative) \
		and root.get_visible_rect().encloses(stop_after) \
		and (scroll_limit <= 0.0 or panel._form_scroll.scroll_vertical > 0),"Stop scrolled out of reach or form did not scroll")
	print("WB525_DOCK_STOP "+JSON.stringify({"logical_size":[screen.x,screen.y],
		"before":str(stop_rect),"after":str(stop_after),"relative_before":str(stop_relative),
		"relative_after":str(stop_after_relative),"visible":str(root.get_visible_rect()),
		"scroll":panel._form_scroll.scroll_vertical,"scroll_limit":scroll_limit}))
	panel._form_scroll.scroll_vertical = 0
	dock = rect(mount._dock)
	var p: Vector2 = dock.position+Vector2(3,3)
	var edits: int = wb.applied.edits.size()
	await mouse(p)
	await mouse(p,MOUSE_BUTTON_WHEEL_UP,true)
	await mouse(p,MOUSE_BUTTON_MIDDLE,true)
	await mouse(p+Vector2(2,2),0,true,Vector2(2,2))
	await mouse(p+Vector2(2,2),MOUSE_BUTTON_MIDDLE,false)
	await mouse(p,MOUSE_BUTTON_LEFT,true)
	await mouse(p,MOUSE_BUTTON_LEFT,false)
	check(host.camera_origin == origin and host.current_view_size == view,"dock input changed camera")
	check(wb.applied.edits.size() == edits and not wb._pan,"dock input painted or captured pan")
	p = host.world_view.get_global_transform_with_canvas()*host.view_content_rect().get_center()
	var center: Vector2 = origin+Vector2(view)*0.5
	await mouse(p)
	await mouse(p,MOUSE_BUTTON_WHEEL_UP,true)
	await settle()
	check(host.current_view_size == Vector2i(240,135),"actual canvas wheel did not zoom")
	check((host.camera_origin+Vector2(host.current_view_size)*0.5).distance_to(center)<0.01,"zoom lost world-space center")
	p = host.world_view.get_global_transform_with_canvas()*host.view_content_rect().get_center()
	origin = host.camera_origin
	var delta := Vector2(24,12)
	var expected: Vector2 = origin-delta*Vector2(host.current_view_size)/host.view_content_rect().size
	await mouse(p)
	await mouse(p,MOUSE_BUTTON_MIDDLE,true)
	await mouse(p+delta,0,true,delta)
	await mouse(p+delta,MOUSE_BUTTON_MIDDLE,false)
	check(host.camera_origin.distance_to(expected)<0.02 and not wb._pan,"pan used wrong canvas scale")
	var cell: Vector2i = Vector2i(host.camera_origin.floor())+host.current_view_size/2
	var projected: Variant = mount.project_cell(cell)
	check(projected is Rect2,"projection missing after pan")
	if projected is Rect2:
		check(Vector2i(host.camera_origin.floor())+host.view_pixel_from_local_point(projected.get_center()) == cell,"fractional camera shifted native-cell preview")
		wb.applied.material = 58
		wb._brush.value = 2
		p = host.world_view.get_global_transform_with_canvas()*projected.get_center()
		await mouse(p)
		await mouse(p,MOUSE_BUTTON_LEFT,true)
		await mouse(p,MOUSE_BUTTON_LEFT,false)
		await until(Callable(self,"_ready_native"),"human brush ACK")
		var auth: Dictionary = await mount.authorize({"region":{"x":cell.x-10,"y":cell.y-10,"width":21,"height":21},"protected_regions":[],"allowed_materials":["Hard Wall","Empty"]})
		check(auth.get("status") == "authorized","paint readback authorization failed")
		var observed: Dictionary = await mount._bridge.call_tool("observe",{"region":null,"detail":"cells"})
		var ids: Array = Array(observed.get("native_material_ids",[]))
		check(observed.get("status") == "observed" and ids.size() == 441,"native paint observation missing")
		if ids.size() == 441: check(ids[220] == 58 and ids[228] == 0,"dispatched paint missed target or changed distant control")
		var png: Variant = observed.get("framebuffer_png",null)
		if png is PackedByteArray and not evidence_dir.is_empty():
			var file: FileAccess = FileAccess.open(evidence_dir.path_join("dock-%d-original.png" % screen.x),FileAccess.WRITE)
			check(file != null,"original PNG unavailable")
			if file != null: file.store_buffer(png)
		var retired: Dictionary = await mount.retire()
		check(retired.get("status") == "retired","native test retirement failed")
	print("WB525_DOCK_LAYOUT "+JSON.stringify({"logical_size":[screen.x,screen.y],"canvas":str(shown),"dock":str(dock),"native_tick":host.latest_snapshot.tick_index}))
	var saved_origin: Vector2 = host.camera_origin
	var saved_edits: int = wb.applied.edits.size()
	panel._traffic._filters["Raw"].button_pressed = true
	panel._traffic._tabs.current_tab = 1
	panel.client.record_diagnostic("ui.raw.test",{"body":"raw body marker"})
	panel._show_traffic()
	await settle()
	check(panel._traffic.visible and panel._traffic._body.text.contains("raw body marker"),"raw Traffic content unavailable")
	var traffic_point: Vector2 = panel._traffic._body.get_global_rect().get_center()
	for button: int in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_MIDDLE]:
		for down: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.window_id = panel._traffic.get_window_id()
			event.position = traffic_point
			event.global_position = traffic_point
			event.button_index = button
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await settle()
	check(host.camera_origin == saved_origin and wb.applied.edits.size() == saved_edits and not wb._pan,"Traffic input leaked into World")
	panel._traffic.hide()
	mount._toggle.button_pressed = false
	await settle()
	check(absf(rect(host.world_view).size.x-hidden.size.x)<2,"opt-out did not restore canvas width")

func _run() -> void:
	evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if not await until(Callable(self,"_ready_native"),"native startup"):
		_finish()
		return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
	if check(wb.apply(fresh),"blank UI fixture") and await until(Callable(self,"_ready_blank"),"native blank canvas"):
		mount = wb._agent_mount
		panel = mount.panel()
		await inspect_layout(Vector2i(1920,1080),0)
		await inspect_layout(Vector2i(1280,720),1)
	_finish()
