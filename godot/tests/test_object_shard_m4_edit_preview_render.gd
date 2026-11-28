extends SceneTree

# Production Workbench, real window mouse position, production GUI dispatch and
# actual framebuffer reads. No fabricated image or replacement preview widget.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Scenes = preload("res://scripts/object_shard_workbench_scenes.gd")
var f: RefCounted
var output: String = ""
var captures: Array[Dictionary] = []
var previews: Array[Dictionary] = []
var last_pointer := Vector2.ZERO
var mouse_mask: int = 0
var rendered_frames: int = 0
var injected_events: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _drawn() -> void:
	rendered_frames += 1

func _window_size(size: Vector2i) -> void:
	root.size = size
	# Hosted desktops can be smaller than the requested owner-size framebuffer.
	# Centre the real window, including negative positions where needed, so the
	# central canvas probes remain physically reachable by the actual OS cursor.
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	root.position = usable.position+(usable.size-root.size)/2

func _frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _select(index: int, radius: int) -> void:
	f.bench._tool.select(index)
	f.bench._tool.item_selected.emit(index)
	f.bench._brush.value = radius

func _cell_to_viewport(cell: Vector2i) -> Vector2:
	var area: Rect2 = f.host.view_content_rect()
	var local: Vector2 = area.position+(Vector2(cell)+Vector2(0.5,0.5)-f.host.camera_origin.floor()) \
		*area.size/Vector2(f.host.current_view_size)
	return f.host.world_view.get_global_transform_with_canvas()*local

func _motion(point: Vector2) -> void:
	# Warp the real viewport pointer as well as submitting its faithful event.
	# The rendered cursor reads get_local_mouse_position(), not this test value.
	root.grab_focus()
	root.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point-last_pointer
	event.button_mask = mouse_mask
	last_pointer = point
	injected_events += 1
	Input.parse_input_event(event)

func _warp(cell: Vector2i) -> void:
	_motion(_cell_to_viewport(cell))
	await _frames()

func _button(button: int, pressed: bool) -> void:
	if button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
		var bit: int = 1 << (button-1)
		mouse_mask = mouse_mask | bit if pressed else mouse_mask & ~bit
	var event := InputEventMouseButton.new()
	event.position = last_pointer
	event.global_position = last_pointer
	event.button_index = button
	event.button_mask = mouse_mask
	event.pressed = pressed
	injected_events += 1
	Input.parse_input_event(event)

func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	injected_events += 2

func _visible_cell() -> Vector2i:
	# Independently invert the actual content rectangle and camera. Do not call
	# the production footprint or pointer target-conversion helper here.
	var area: Rect2 = f.host.view_content_rect()
	var local: Vector2 = f.host.world_view.get_local_mouse_position()
	var pixel: Vector2 = (local-area.position)*Vector2(f.host.current_view_size)/area.size
	return Vector2i(f.host.camera_origin.floor()+pixel.floor())

func _capture(label: String, window: Window = null) -> Image:
	await _frames()
	var view: Window = root if window==null else window
	var image: Image = view.get_texture().get_image()
	f.expect(not image.is_empty(),label+": actual rendered framebuffer is nonempty")
	var path: String = output.path_join(label+".png")
	f.expect(image.save_png(path)==OK,label+": save actual framebuffer PNG")
	captures.append({"label":label,"path":path,"sha256":FileAccess.get_sha256(path),
		"size":[image.get_width(),image.get_height()],"window_id":view.get_window_id(),"rendered_frames":rendered_frames})
	return image

func _line_pixels(label: String, visible: Image, points: PackedVector2Array) -> void:
	# One genuine renderer submission without the cursor provides a local pixel
	# control. The ordinary paused scene stays in place and Main restores its
	# real cursor on the following callback.
	RenderingServer.frame_pre_draw.connect(func() -> void: f.host.brush_preview.hide(),CONNECT_ONE_SHOT)
	await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	var changed_samples: int = 0
	var samples: int = 0
	var raster_scale: Vector2 = Vector2(visible.get_size())/root.get_visible_rect().size
	var stride: int = maxi(1,points.size()/12)
	for index: int in range(0,points.size(),stride):
		var global: Vector2 = f.host.world_view.get_global_transform_with_canvas()*points[index]
		var at := Vector2i((global*raster_scale).round())
		var changed: bool = false
		for dy: int in range(-2,3):
			for dx: int in range(-2,3):
				var sample: Vector2i = at+Vector2i(dx,dy)
				if sample.x<0 or sample.y<0 or sample.x>=visible.get_width() or sample.y>=visible.get_height(): continue
				var a: Color = visible.get_pixelv(sample)
				var b: Color = hidden.get_pixelv(sample)
				if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>0.25: changed = true
		if changed: changed_samples += 1
		samples += 1
	f.expect(changed_samples>=mini(3,samples),label+": expected projected outline changes actual framebuffer pixels")
	previews.back()["render_control"] = {"outline_samples":samples,"changed_samples":changed_samples,
		"scope":"same paused framebuffer with production Line2D visible versus one draw hidden"}
	await _frames()

func _circle(label: String, tool: int, radius: int, cell: Vector2i) -> void:
	_select(tool,radius)
	await _warp(cell)
	var actual_cell: Vector2i = _visible_cell()
	f.expect(actual_cell==cell,label+": real mouse warp targets the intended material cell")
	var line: Line2D = f.host.brush_preview
	f.expect(line.visible and line.points.size()==49,label+": production circular preview is displayed")
	var area: Rect2 = f.host.view_content_rect()
	var scale: Vector2 = area.size/Vector2(f.host.current_view_size)
	var centre: Vector2 = area.position+(Vector2(actual_cell)+Vector2(0.5,0.5)-f.host.camera_origin.floor())*scale
	var distance: float = 0.5 if tool==7 else float(radius)+0.5
	var maximum_error: float = 0.0
	for point: Vector2 in line.points:
		maximum_error = maxf(maximum_error,absf(((point-centre)/scale).length()-distance))
	f.expect(maximum_error<0.005,label+": circle extent uses the same camera scale and cell-centre convention as execution")
	previews.append({"label":label,"tool":tool,"radius":0 if tool==7 else radius,
		"cell":[actual_cell.x,actual_cell.y],"point_count":line.points.size(),"maximum_error_cells":maximum_error,
		"camera_origin":[f.host.camera_origin.x,f.host.camera_origin.y],
		"camera_extent":[f.host.current_view_size.x,f.host.current_view_size.y],
		"world_view_size":[f.host.world_view.size.x,f.host.world_view.size.y]})
	var image: Image = await _capture(label)
	await _line_pixels(label,image,line.points.duplicate())

func _start_slice(first: Vector2i, last: Vector2i, radius: int = 1) -> void:
	_select(11,radius)
	await _warp(first)
	_button(MOUSE_BUTTON_LEFT,true)
	await _warp(last)
	f.expect(f.bench._object_shard_pointer_tool==11 and not f.bench._object_shard_slice_committing,
		"production GUI dispatch holds an uncommitted slice preview")

func _slice_preview() -> void:
	var before: int = f.bench.object_shard_m4_port._next_action
	await _start_slice(Vector2i(128,310),Vector2i(223,322),1)
	var line: Line2D = f.host.brush_preview
	f.expect(line.visible and line.points.size()==51,"slice preview displays both endcaps and the connecting stroke")
	var area: Rect2 = f.host.view_content_rect()
	var scale: Vector2 = area.size/Vector2(f.host.current_view_size)
	var first: Vector2 = Vector2(f.bench._object_shard_pointer_start)+Vector2(0.5,0.5)
	var last: Vector2 = Vector2(_visible_cell())+Vector2(0.5,0.5)
	var maximum_error: float = 0.0
	for point: Vector2 in line.points:
		var world: Vector2 = (point-area.position)/scale+f.host.camera_origin.floor()
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(world,first,last)
		maximum_error = maxf(maximum_error,absf(world.distance_to(closest)-1.5))
	f.expect(maximum_error<0.005,"slice preview is the correctly projected adjustable-width capsule")
	f.expect(f.bench.object_shard_m4_port._next_action==before,"preview motion alone never admits material mutation")
	previews.append({"label":"slice-preview","tool":11,"radius":1,"point_count":line.points.size(),
		"maximum_error_cells":maximum_error,"first":[first.x,first.y],"last":[last.x,last.y]})
	var image: Image = await _capture("slice-preview")
	await _line_pixels("slice-preview",image,line.points.duplicate())
	_escape()
	_button(MOUSE_BUTTON_LEFT,false)
	await _frames()
	f.expect(f.bench._object_shard_pointer_tool==-1 and f.bench.object_shard_m4_port._next_action==before,
		"actual Escape input cancels slice preview without native admission")

func _navigation() -> void:
	var before: int = f.bench.object_shard_m4_port._next_action
	await _start_slice(Vector2i(160,310),Vector2i(188,324))
	var extent: Vector2i = f.host.current_view_size
	_button(MOUSE_BUTTON_WHEEL_UP,true)
	await _frames()
	f.expect(f.bench._object_shard_pointer_tool==-1 and f.host.current_view_size!=extent,
		"actual canvas wheel zoom changes view and cancels the prior preview")
	_button(MOUSE_BUTTON_LEFT,false)
	var centre: Vector2i = Vector2i(f.host.camera_origin.floor())+f.host.current_view_size/2
	await _circle("zoomed-eraser",10,8,centre)
	await _start_slice(centre,centre+Vector2i(15,5))
	var origin: Vector2 = f.host.camera_origin
	_button(MOUSE_BUTTON_MIDDLE,true)
	_motion(last_pointer+Vector2(-70,-35))
	await _frames()
	_button(MOUSE_BUTTON_MIDDLE,false)
	_button(MOUSE_BUTTON_LEFT,false)
	await _frames()
	f.expect(f.bench._object_shard_pointer_tool==-1 and not f.host.camera_origin.is_equal_approx(origin),
		"actual middle-button camera pan cancels preview and moves the material view")
	centre = Vector2i(f.host.camera_origin.floor())+f.host.current_view_size/2
	await _circle("panned-drill",13,9,centre)
	await _start_slice(centre,centre+Vector2i(12,4))
	var old_view: Vector2 = f.host.world_view.size
	_window_size(Vector2i(1360,860))
	await _frames()
	f.expect(f.bench._object_shard_pointer_tool==-1 and not f.host.world_view.size.is_equal_approx(old_view),
		"real application window resize reflows the canvas and cancels stale preview coordinates")
	_button(MOUSE_BUTTON_LEFT,false)
	centre = Vector2i(f.host.camera_origin.floor())+f.host.current_view_size/2
	await _circle("resized-weathering",12,7,centre)
	f.expect(f.bench.object_shard_m4_port._next_action==before,"zoom, pan and resize cancellation admit no previous slice")
	_window_size(Vector2i(1920,1080))
	await _frames()

func _controls() -> void:
	f.bench.open_object_shard_controls()
	await _frames()
	var window: Window = f.bench._object_shard_window
	f.expect(window.visible and window.size.x<=1920 and window.size.y<=1080,
		"Structures controls fit the owner evaluation window")
	var scroll: ScrollContainer = window.get_child(0)
	var column: VBoxContainer = scroll.get_child(0)
	var labels: Array[String] = []
	for child: Node in column.get_children():
		if child is Button: labels.append(child.text)
	for label: String in Scenes.LABELS:
		f.expect(labels.has(label),"Structures controls expose demo: "+label)
	f.expect(scroll.get_h_scroll_bar().max_value-scroll.get_h_scroll_bar().page<=1.0,
		"Structures labels and controls require no horizontal scrolling")
	scroll.scroll_vertical = 0
	await _capture("structures-controls-top",window)
	scroll.ensure_control_visible(f.bench._erosion_seed)
	await _frames()
	f.expect(f.bench._erosion_density.is_visible_in_tree() and f.bench._erosion_seed.is_visible_in_tree() \
		and scroll.get_global_rect().intersects(f.bench._erosion_seed.get_global_rect()),
		"weathering density and deterministic seed remain reachable in the scrollable controls")
	f.expect(f.bench._erosion_material_only.is_visible_in_tree(),"material-filter control is visible beside density and seed")
	await _capture("structures-weathering-controls",window)
	window.hide()
	root.grab_focus()
	await _frames()

func _run() -> void:
	f = Fixture.new(self)
	if not f.expect(DisplayServer.get_name()!="headless","preview qualification has an actual window renderer"):
		await _finish(); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty(): output = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): output = "user://objectshard-edit-preview-captures"
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.frame_post_draw.connect(_drawn)
	_window_size(Vector2i(1920,1080))
	if not await f.open("editing_yard"): await _finish(); return
	f.bench._set_view(Vector2(96,240),Vector2i(256,192))
	await _frames()
	await _circle("structural-eraser",10,8,Vector2i(176,316))
	await _circle("precision-cell",7,0,Vector2i(176,316))
	await _circle("drill-opening",13,12,Vector2i(176,316))
	f.bench._erosion_density.value = 31
	f.bench._erosion_seed.value = 321
	await _circle("weathering-extent",12,10,Vector2i(176,316))
	await _circle("area-ignition",8,9,Vector2i(176,316))
	f.bench.paint_editor.select_tool("Eraser")
	await _circle("ordinary-unified-eraser",0,8,Vector2i(176,316))
	await _slice_preview()
	await _navigation()
	await _controls()
	f.expect(f.host.paused and f.runtime().held_reason.is_empty(),"preview and navigation qualification preserve a healthy paused material owner")
	f.validate_display()
	await _finish()

func _finish() -> void:
	if f!=null and f.host!=null:
		_escape()
		if mouse_mask & MOUSE_BUTTON_MASK_LEFT: _button(MOUSE_BUTTON_LEFT,false)
		if mouse_mask & MOUSE_BUTTON_MASK_MIDDLE: _button(MOUSE_BUTTON_MIDDLE,false)
		await f.close()
	if RenderingServer.frame_post_draw.is_connected(_drawn): RenderingServer.frame_post_draw.disconnect(_drawn)
	print(JSON.stringify({"schema":"objectshard-m4-edit-preview-render-v1","checks":f.checks,"failures":f.failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display_driver":DisplayServer.get_name(),
		"desktop_usable_rect":DisplayServer.screen_get_usable_rect(),"window_position":root.position,"window_size":root.size,
		"rendered_frames":rendered_frames,"injected_events":injected_events,"previews":previews,"captures":captures,
		"scope":"production Workbench GUI events, actual warped mouse, camera transforms and framebuffer pixels; no owner hardware performance claim"}))
	quit(0 if f.failures.is_empty() else 1)
