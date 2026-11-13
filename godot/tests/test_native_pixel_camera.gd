extends SceneTree

## Continuous camera algebra, physical-pixel presentation and ordinary mounted
## PAINT/Art gestures. Cell identity is read back from the native World, never
## inferred from a rendered colour. No provider request is made.
const Camera = preload("res://scripts/pixel_camera_transform.gd")
const Setup = preload("res://scripts/workbench_setup.gd")

class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var checks: int = 0
var failures: Array[String] = []
var host: Control
var bench: Control
var editor: Control
var native_receipts: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("NATIVE_PIXEL_CAMERA " + label)
	return ok


func near(a: Vector2, b: Vector2, tolerance: float = 0.0002) -> bool:
	return (a - b).abs().x <= tolerance and (a - b).abs().y <= tolerance


func transforms() -> void:
	# Canvas scale and screen position are independent of world magnification.
	# The non-integral content origin also covers fitted/odd-width viewports.
	for dpi: float in [1.0, 1.25, 1.5, 2.0]:
		for zoom: float in [2.0, 2.5, 4.0, 8.0]:
			var view := Vector2i(241, 137)
			var content := Rect2(Vector2(17.25, 21.5), Vector2(view) * zoom)
			var screen := Transform2D(Vector2(dpi, 0), Vector2(0, dpi), Vector2(31, 47))
			var requested := Vector2(63.137, 64.879)
			var presented: Vector2 = Camera.presentation_origin(requested, view, content, screen)
			var physical_scale := Vector2(zoom * dpi, zoom * dpi)
			var phase: Vector2 = screen * content.position - presented * physical_scale
			var label := "scale=%s zoom=%s" % [dpi, zoom]
			check(near(phase, phase.round(), 0.001), "integer physical translation " + label)
			check(((presented-requested)*physical_scale).abs().x <= 0.501
				and ((presented-requested)*physical_scale).abs().y <= 0.501,
				"presentation changes by at most half a display pixel " + label)
			for uv: Vector2 in [Vector2(0.01,0.02), Vector2(0.23,0.77), Vector2(0.5,0.5), Vector2(0.99,0.98)]:
				var point: Vector2 = content.position + uv * content.size
				var world: Vector2 = Camera.local_to_world(point, presented, view, content)
				check(near(Camera.world_to_local(world, presented, view, content), point, 0.003),
					"screen/world inverse " + label + " " + str(uv))
				check(Camera.local_to_cell(point, presented, view, content) == Vector2i(world.floor()),
					"integer cell conversion follows continuous addition " + label)
			# One physical pixel must move the presentation exactly once even at
			# fractional zoom. No request is written back with presentation rounding.
			for delta: Vector2 in [Vector2(1,0), Vector2(0,1), Vector2(-1,-1), Vector2(7,-3)]:
				var moved: Vector2 = Camera.presentation_origin(requested + delta/physical_scale,
					view, content, screen)
				check(near((moved-presented)*physical_scale, delta, 0.002),
					"display-pixel movement " + label + " " + str(delta))
			var slow_phases: Array[Vector2] = []
			for index: int in range(25):
				var slow: Vector2 = Camera.presentation_origin(requested + Vector2(index*0.1,0)/physical_scale,
					view, content, screen)
				slow_phases.append((slow-presented)*physical_scale)
			var advanced := 0
			for index: int in range(1,slow_phases.size()):
				var step: float = slow_phases[index].x - slow_phases[index-1].x
				check(absf(step) < 0.002 or absf(step-1.0) < 0.002,
					"slow accumulation never jumps an enlarged cell " + label)
				if step > 0.5: advanced += 1
			check(advanced >= 2, "slow accumulated input makes progress " + label)

	var area := Rect2(13.5, 17.25, 1280, 720)
	var original := Vector2(63.75, 64.5)
	var point := area.position + Vector2(0.6,0.6)*4.0
	check(Camera.local_to_cell(point,original,Vector2i(320,180),area) == Vector2i(64,65),
		"fractional camera plus local fraction carries into the next world cell")
	check(Vector2i(original.floor()) + Vector2i(((point-area.position)/4.0).floor()) != Vector2i(64,65),
		"legacy separately floored conversion is a discriminating negative control")
	var anchor_local := area.position + Vector2(0.73,0.31)*area.size
	var anchor: Vector2 = Camera.local_to_world(anchor_local,original,Vector2i(320,180),area)
	for new_view: Vector2i in [Vector2i(160,90),Vector2i(240,135),Vector2i(321,181)]:
		var changed := Rect2(31.25,22.5,1231,694)
		var next: Vector2 = Camera.origin_for_anchor(anchor,anchor_local,new_view,changed)
		check(near(Camera.local_to_world(anchor_local,next,new_view,changed),anchor),
			"zoom anchor survives changed fitted rectangle " + str(new_view))

	# Input integration stays in floating-point world coordinates; presentation
	# rounding is an output, never the next frame's camera accumulator.
	var speed := Vector2(7.75,-3.25)
	for frames: int in [30,60,144]:
		var accumulated := Vector2(100,100)
		for frame: int in range(frames): accumulated += speed/float(frames)
		check(near(accumulated,Vector2(100,100)+speed,0.002),
			"time-scaled pan is frame-rate independent " + str(frames))
	var repeat := Vector2(100.125,200.375)
	for index: int in range(1000):
		repeat += Vector2(0.03125,-0.0625)
		Camera.presentation_origin(repeat,Vector2i(320,180),area,Transform2D.IDENTITY)
		repeat -= Vector2(0.03125,-0.0625)
	check(repeat == Vector2(100.125,200.375), "1000 pan/reverse pairs do not feed snapped output back into camera")
	physical_sample_mapping()


func physical_sample_mapping() -> void:
	var view := Vector2i(240,128)
	var content := Rect2(0,0,600,320)
	var first: Transform2D = Camera.presentation_screen_transform(Vector2(63.137,60.137),view,content)
	var next: Transform2D = Camera.presentation_screen_transform(Vector2(63.537,60.137),view,content)
	check(first.origin == Vector2(-158,-150) and next.origin == Vector2(-159,-150),
		"2.5x mapping retains exact integer physical phase before inverse camera rounding")
	check(first.x == Vector2(2.5,0) and first.y == Vector2(0,2.5),
		"physical mapping retains exact pixels-per-world-cell basis")
	check(Camera.world_units_per_screen_pixel(first) == Vector2(0.4,0.4),
		"CPU and shader share one precomputed world-per-display-pixel reciprocal")
	check(Camera.screen_to_cell(Vector2(349,100),first) == Vector2i(203,100)
		and Camera.screen_to_cell(Vector2(348,100),next) == Vector2i(203,100),
		"adversarial pixel349 to348 tie addresses world203 identically")
	for x: int in range(1,600):
		var old_point := Vector2(x+0.5,100.5)
		var new_point := old_point-Vector2(1,0)
		check(Camera.screen_to_world(old_point,first) == Camera.screen_to_world(new_point,next),
			"realistic 2.5x translated rays retain identical float bits at column "+str(x))
	check(Camera.screen_to_cell(Vector2(349.01,100.01),first)
		== Camera.screen_to_cell(Vector2(349.99,100.99),first),
		"all pointer positions inside one physical pixel address its one fragment sample")
	for dpi: float in [1.0,1.25,1.5,2.0]:
		var screen := Transform2D(Vector2(dpi,0),Vector2(0,dpi),Vector2(93,57))
		var fitted := Rect2(13.7,9.7,600,320)
		var requested := Vector2(61.137,63.137)
		var mapping: Transform2D = Camera.presentation_screen_transform(requested,view,fitted,screen)
		var shifted: Transform2D = Camera.presentation_screen_transform(
			requested+Vector2(1.0/(2.5*dpi),0),view,fitted,screen)
		check(mapping.origin == mapping.origin.round() and shifted.origin == mapping.origin-Vector2(1,0),
			"fitted display scaling keeps exact physical phase "+str(dpi))
		var point := Vector2(389.5,198.5)
		check(Camera.screen_to_world(point,mapping) == Camera.screen_to_world(point-Vector2(1,0),shifted),
			"display scaling preserves translated sample identity "+str(dpi))
	var fitted := Rect2(13.7,9.7,600,320)
	var maximum := Vector2(272.1,128.1)
	var at_start: Transform2D = Camera.presentation_screen_transform(Vector2.ZERO,view,fitted,
		Transform2D.IDENTITY,maximum)
	var at_end: Transform2D = Camera.presentation_screen_transform(maximum,view,fitted,
		Transform2D.IDENTITY,maximum)
	check(near(Camera.screen_to_world(fitted.position,at_start),Vector2.ZERO,0.00003),
		"outer left/top bound wins over fractional fitted-edge rounding")
	check(near(Camera.screen_to_world(fitted.position,at_end),maximum,0.00003),
		"outer right/bottom bound wins over fractional fitted-edge rounding")
	var one_bound: Transform2D = Camera.presentation_screen_transform(Vector2(60,0),view,fitted,
		Transform2D.IDENTITY,maximum)
	check(one_bound.origin.x == roundf(one_bound.origin.x) and one_bound.origin.y == fitted.position.y,
		"clamping one axis preserves the other axis's physical pixel phase")
	physical_sample_bounds()


func physical_sample_bounds() -> void:
	var content := Rect2(2.8,2.8,160,96)
	var screen := Transform2D(Vector2(1.25,0),Vector2(0,1.25),Vector2(17,17))
	var first := Vector2(20.5,20.5)
	var end := Vector2(220.5,140.5)
	check(screen*content.position == first,
		"fractional fitted edge lands exactly on an included physical sample")
	var rounding_fit := Rect2(52.3333435,0,325.333313,183)
	var rounding_screen := Transform2D(Vector2(1.5,0),Vector2(0,1.5),Vector2(251,17))
	var rounding_sample := Vector2(329.5,30.5)
	check(not rounding_fit.has_point(rounding_screen.affine_inverse()*rounding_sample)
		and Camera.content_contains_screen_sample(rounding_sample,rounding_fit,rounding_screen),
		"1.5x inverse-local clipping is a discriminating rounding-error control")
	check(Camera.content_contains_screen_sample(first,content,screen),
		"physical clipping includes the exact left/top sample without inverse rounding")
	check(Camera.content_contains_screen_sample(Vector2(first.x,80.5),content,screen)
		and Camera.content_contains_screen_sample(Vector2(80.5,first.y),content,screen),
		"physical clipping includes each exact near edge independently")
	check(not Camera.content_contains_screen_sample(Vector2(end.x,80.5),content,screen)
		and not Camera.content_contains_screen_sample(Vector2(80.5,end.y),content,screen),
		"physical clipping excludes exact right/bottom samples under half-open bounds")
	check(Camera.content_contains_screen_sample(end-Vector2.ONE,content,screen),
		"physical clipping retains the final interior pixel on both axes")
	check(not Camera.content_contains_screen_sample(first-Vector2(1,0),content,screen)
		and not Camera.content_contains_screen_sample(first-Vector2(0,1),content,screen),
		"physical clipping rejects samples in the adjacent letterbox pixels")


func until(predicate: Callable, label: String, limit_ms: int = 30000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false,label)


func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and not editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy


func local(cell: Vector2i) -> Vector2:
	return Camera.world_to_local(Vector2(cell)+Vector2(0.5,0.5),host.presentation_camera_origin(),
		host.current_view_size,host.view_content_rect())


func gesture(tool: String, first: Vector2i, last: Vector2i, material_id: int = 58) -> void:
	editor.select_tool(tool)
	editor.select_material(material_id)
	bench._tool.select(0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local(first)
	bench._world_input(press)
	var move := InputEventMouseMotion.new()
	move.position = local(last)
	move.relative = move.position - press.position
	bench._world_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = local(last)
	bench._world_input(release)
	await until(ready, tool + " completes at fractional camera")


func capture(region: Rect2i) -> PackedInt32Array:
	var worker: RefCounted = host.simulation_worker
	var state: Dictionary = worker.paint_state()
	var admission: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":int(state.generation),"expected_revision":int(state.revision),"expected_tick":int(state.tick)})
	if not check(admission.get("status") == "queued", "independent native capture admitted"): return PackedInt32Array()
	if not await until(func()->bool: return worker.paint_state().receipt_ready,"native readback arrives"): return PackedInt32Array()
	var receipt: Dictionary = worker.paint_take_result()
	check(receipt.get("status") == "completed", "independent native readback completed")
	var values: PackedInt32Array = receipt.get("materials",PackedInt32Array())
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(values.to_byte_array())
	native_receipts.append({"region":[region.position.x,region.position.y,region.size.x,region.size.y],
		"materials_sha256":digest.finish().hex_encode(),"generation":receipt.get("generation"),
		"revision":receipt.get("revision"),"backend":receipt.get("backend")})
	return values


func mounted() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size = Vector2i(1440,1000)
	bench = host.shared_workbench
	editor = bench.paint_editor
	if not await until(ready,"ordinary Workbench ready",60000): return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	if not check(bench.apply(fresh),"blank native 512 World admitted"): return
	if not await until(ready,"blank native World installed"): return
	bench._camera.select(0)
	host.camera_follow_enabled = false
	bench._zoom = 1
	bench._set_view(Vector2(24.75,20.5),Vector2i(480,270))
	await process_frame
	var area: Rect2 = host.view_content_rect()
	var anchor_local: Vector2 = area.position + area.size*Vector2(0.73,0.31)
	var anchor_before: Vector2 = Camera.local_to_world(anchor_local,host.camera_origin,host.current_view_size,area)
	var presented_before: Vector2 = host.world_position_from_local_point(anchor_local)
	var original_camera: Vector2 = host.camera_origin
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = anchor_local
	bench._world_input(wheel)
	check(host.current_view_size == Vector2i(240,135),"ordinary wheel changes magnification")
	check(editor.cursor == host.world_cell_from_local_point(anchor_local),
		"wheel updates PAINT preview target immediately without another mouse event")
	check(near(Camera.local_to_world(anchor_local,host.camera_origin,host.current_view_size,host.view_content_rect()),
		anchor_before,0.0003),"wheel preserves continuous world anchor immediately")
	var pixels_per_cell: Vector2 = host.view_content_rect().size/Vector2(host.current_view_size)
	var screen: Transform2D = host.world_view.get_screen_transform()
	pixels_per_cell *= Vector2(screen.x.length(),screen.y.length())
	check(((host.world_position_from_local_point(anchor_local)-presented_before)*pixels_per_cell).abs().x <= 1.51
		and ((host.world_position_from_local_point(anchor_local)-presented_before)*pixels_per_cell).abs().y <= 1.51,
		"displayed zoom anchor is bounded by old/new physical-pixel rounding")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	bench._world_input(wheel)
	check(near(host.camera_origin,original_camera,0.0003),"wheel in/out has no accumulating camera drift")
	hover_without_motion()
	mounted_sample_bounds()

	bench._set_view(Vector2(24.75,20.75),Vector2i(240,135))
	await process_frame
	check(not host.presentation_camera_origin().is_equal_approx(host.presentation_camera_origin().floor()),
		"mounted camera retains a fractional presented origin")
	# Test the actual physical pixel addressed by the mouse, including the
	# shader's centre-of-pixel sampling convention at a fractional zoom.
	area = host.view_content_rect()
	screen = host.world_view.get_screen_transform()
	for index: int in range(32):
		var pointer: Vector2 = area.position + Vector2(17.13+index*2.371,24.77+index*1.117)
		var pixel_centre: Vector2 = screen.affine_inverse()*((screen*pointer).floor()+Vector2(0.5,0.5))
		var expected: Vector2i = Vector2i((host.presentation_camera_origin()
			+(pixel_centre-area.position)*Vector2(host.current_view_size)/area.size).floor())
		check(host.world_cell_from_local_point(pointer) == expected,"Main pointer uses displayed pixel " + str(index))
		check(editor.local_to_cell(pointer) == expected,"PAINT pointer uses same displayed pixel " + str(index))
	check(host.world_cell_from_local_point(area.position-Vector2.ONE) == Vector2i(-1,-1),
		"letterbox/outside pointer is rejected")

	bench._brush.value = 0
	await gesture("Rectangle",Vector2i(63,63),Vector2i(65,65))
	var block: PackedInt32Array = await capture(Rect2i(62,62,5,5))
	var expected_block := PackedInt32Array()
	for y: int in range(5):
		for x: int in range(5): expected_block.append(58 if x in [1,2,3] and y in [1,2,3] else 0)
	check(block == expected_block,"fractional-camera rectangle writes exact cells across x/y chunk64 boundary")
	bench.art_batches.show()
	await gesture("Select",Vector2i(65,65),Vector2i(63,63))
	check(editor.selection == Rect2i(63,63,3,3),"reverse Select retains exact inclusive world bounds")
	check(bench.art_batches.rectangle(bench.art_batches.fields) == editor.selection,
		"Art Focus X/Y/W/H matches visible fractional-camera Select")
	bench.art_batches.hide()
	check(editor.copy_selection(),"native Copy admitted")
	await until(ready,"native Copy completes")
	await gesture("Paste",Vector2i(90,80),Vector2i(90,80))
	var pasted: PackedInt32Array = await capture(Rect2i(90,80,3,3))
	check(pasted.size() == 9 and pasted.count(58) == 9,"clipboard gesture lands at displayed target")
	await gesture("Brush",Vector2i(75,75),Vector2i(75,75),131)
	check(await capture(Rect2i(75,75,1,1)) == PackedInt32Array([131]),"Brush native target matches displayed cell")
	await gesture("Outline",Vector2i(110,90),Vector2i(116,96))
	editor.selection = Rect2i()
	await gesture("Fill",Vector2i(113,93),Vector2i(113,93),2)
	var fill: PackedInt32Array = await capture(Rect2i(110,90,7,7))
	var expected_fill := PackedInt32Array()
	for y: int in range(7):
		for x: int in range(7): expected_fill.append(58 if x in [0,6] or y in [0,6] else 2)
	check(fill == expected_fill,"Fill seed and boundary remain aligned at fractional camera")

	var pre_pan: Vector2 = host.camera_origin
	var shown_pre_pan: Vector2 = host.presentation_camera_origin()
	area = host.view_content_rect()
	screen = host.world_view.get_screen_transform()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = area.get_center()
	bench._world_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = press.position
	drag.relative = Vector2(1.0/screen.x.length(),0)
	bench._world_input(drag)
	var expected_delta: Vector2 = -drag.relative*Vector2(host.current_view_size)/area.size
	check(near(host.camera_origin-pre_pan,expected_delta),"one-pixel mouse drag preserves continuous input without frame delay")
	check(editor.cursor == host.world_cell_from_local_point(drag.position),
		"middle pan updates PAINT preview target in the same input event")
	pixels_per_cell = area.size/Vector2(host.current_view_size)*Vector2(screen.x.length(),screen.y.length())
	check(near((host.presentation_camera_origin()-shown_pre_pan)*pixels_per_cell,Vector2(-1,0),0.002),
		"one physical drag pixel moves displayed world by one physical pixel")
	press.pressed = false
	bench._world_input(press)
	bench._set_view(Vector2(-100,-100),Vector2i(240,135))
	check(host.camera_origin == Vector2.ZERO,"negative camera clamps to World origin")
	bench._set_view(Vector2(1000,1000),Vector2i(240,135))
	check(host.camera_origin == Vector2(272,377),"camera clamps to far World edge without changing view size")
	await follow_same_frame()


func hover_without_motion() -> void:
	# Keep the actual screen pointer fixed while toolbar navigation and layout
	# move the image underneath it. Refresh through the controller's ordinary
	# process callback, without synthesizing a second MouseMotion event.
	var saved_origin: Vector2 = host.camera_origin
	var saved_view: Vector2i = host.current_view_size
	var saved_zoom: int = bench._zoom
	var saved_size: Vector2 = host.world_view.size
	var saved_scale: Vector2 = host.world_view.scale
	var saved_position: Vector2 = host.world_view.position
	var native_before: Dictionary = host.simulation_worker.paint_state()
	var area: Rect2 = host.view_content_rect()
	editor.select_tool("Rectangle")
	var hover := InputEventMouseMotion.new()
	hover.position = area.position + area.size*Vector2(0.73,0.31)
	bench._world_input(hover)
	var screen_point: Vector2 = host.world_view.get_screen_transform()*hover.position
	var old_cursor: Vector2i = editor.cursor
	bench.zoom_by(-1)
	editor._process(0.0)
	var remapped: Vector2 = host.world_view.get_screen_transform().affine_inverse()*screen_point
	check(editor.cursor == host.world_cell_from_local_point(remapped) and editor.cursor != old_cursor,
		"stationary hover follows toolbar zoom without a mouse event")
	check(editor._pointer_screen == screen_point,"toolbar zoom preserves pointer screen position")

	host.world_view.scale = saved_scale*Vector2(1.25,0.9)
	host.world_view.position = saved_position+Vector2(21,13)
	host.world_view.size = saved_size-Vector2(37,19)
	editor._process(0.0)
	remapped = host.world_view.get_screen_transform().affine_inverse()*screen_point
	check(editor.cursor == host.world_cell_from_local_point(remapped) and editor.cursor.x >= 0,
		"stationary hover follows changed viewport transform and fitted size")
	check(editor._pointer_screen == screen_point,"layout changes do not reinterpret stored pointer as local coordinates")
	host.world_view.scale = saved_scale
	host.world_view.position = saved_position
	host.world_view.size = saved_size
	editor._process(0.0)
	check(editor.cursor == host.world_cell_from_local_point(hover.position),
		"restored layout returns hover to the same screen sample")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = hover.position
	bench._world_input(press)
	var drag_anchor: Vector2i = editor.anchor
	var drag_cursor: Vector2i = editor.cursor
	check(editor.dragging,"active rectangle preview admitted for hover isolation")
	bench._set_view(host.camera_origin+Vector2(0.25,0.5),host.current_view_size)
	editor._process(0.0)
	check(editor.anchor == drag_anchor and editor.cursor == drag_cursor,
		"stationary refresh cannot retarget an active drag anchor or endpoint")
	host.world_view.mouse_exited.emit()
	check(editor.dragging and editor.anchor == drag_anchor and editor.cursor == drag_cursor,
		"mouse exit preserves active drag geometry")
	editor.cancel_preview()
	host.world_view.mouse_exited.emit()
	check(editor.cursor == Vector2i(-1,-1) and not editor._pointer_screen.is_finite(),
		"mouse exit clears idle hover preview")
	editor._process(0.0)
	check(editor.cursor == Vector2i(-1,-1),"later frames cannot resurrect an exited pointer")
	bench._zoom = saved_zoom
	bench._set_view(saved_origin,saved_view)
	check(host.simulation_worker.paint_state().revision == native_before.revision,
		"hover, toolbar zoom and cancelled preview do not mutate native cells")


func mounted_sample_bounds() -> void:
	# This ordinary aspect fit is a real inverse-rounding counterexample:
	# local x=52.3333435 maps to physical x=329.5, but the inverse returns
	# x=52.333328 and formerly discarded the visible first content column.
	var saved_origin: Vector2 = host.camera_origin
	var saved_view: Vector2i = host.current_view_size
	var saved_size: Vector2 = host.world_view.size
	var saved_scale: Vector2 = host.world_view.scale
	var saved_position: Vector2 = host.world_view.position
	host.current_view_size = Vector2i(240,135)
	host.camera_origin = Vector2(63.137,60.137)
	host.world_view.size = Vector2(430,183)
	host.world_view.scale = Vector2(1.5,1.5)
	# Remove the native window's desktop translation from the fixture setup;
	# the tested screen transform itself remains the actual CanvasItem API.
	host.world_view.global_position += Vector2(251,17)-host.world_view.get_screen_transform().origin
	var content: Rect2 = host.view_content_rect()
	var screen: Transform2D = host.world_view.get_screen_transform()
	var pointer := Vector2(52.5,9)
	var sample: Vector2 = (screen*pointer).floor()+Vector2(0.5,0.5)
	check(near(screen.origin,Vector2(251,17),0.00001) and sample.x == 329.5,
		"mounted fractional-scale fixture reaches the registered physical edge")
	check(content.has_point(pointer) and not content.has_point(screen.affine_inverse()*sample),
		"mounted first-column sample discriminates the previous inverse clipping")
	var mapping: Transform2D = host.presentation_camera_screen_transform()
	var expected: Vector2i = Camera.screen_to_cell(screen*pointer,mapping)
	check(expected.x >= 0 and host.world_cell_from_local_point(pointer) == expected,
		"Main picks the rendered first column at a fractional display scale")
	check(editor.local_to_cell(pointer) == expected,
		"PAINT shares Main's included fractional fitted-edge sample")
	var pixel_corner := Vector2(content.position.x-0.05,pointer.y)
	check(not content.has_point(pixel_corner)
		and host.world_cell_from_local_point(pixel_corner) == expected,
		"a pointer just outside the mathematical fit still picks its visible physical pixel")
	check(host.world_cell_from_local_point(Vector2(content.end.x-0.01,pointer.y)) == Vector2i(-1,-1),
		"Main rejects an inside pointer whose pixel centre equals the half-open right edge")
	check(host.world_cell_from_local_point(Vector2(pointer.x,content.end.y-0.01)) == Vector2i(-1,-1),
		"Main rejects an inside pointer whose pixel centre equals the half-open bottom edge")
	host.current_view_size = saved_view
	host.camera_origin = saved_origin
	host.world_view.scale = saved_scale
	host.world_view.position = saved_position
	host.world_view.size = saved_size


func follow_same_frame() -> void:
	# A paused real Rapier actor supplies the followed pose. Invoke one parent
	# presentation callback explicitly, with the child callback disabled: this
	# discriminates the previous order that moved the camera only afterward.
	var follow_setup: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	follow_setup.actors = [Setup.instance(Setup.BARREL,1,Vector2(300.75,260.5))]
	follow_setup.next_id = 2
	follow_setup.selected = 1
	if not check(bench.apply(follow_setup),"paused follow actor admitted"): return
	if not await until(ready,"paused follow actor installed"): return
	var state: Dictionary = bench.body_state(1)
	if not check(not state.is_empty(),"real selected actor supplies follow pose"): return
	host.set_process(false)
	bench.set_process(false)
	bench._set_view(Vector2(10.25,10.25),Vector2i(240,135))
	bench._camera.select(1)
	var old_origin: Vector2 = host.camera_origin
	host._process(1.0/60.0)
	var desired: Vector2 = host.clamped_camera_origin(Vector2(state.position)-Vector2(host.current_view_size)*0.5)
	check(near(host.camera_origin,desired) and not near(host.camera_origin,old_origin),
		"parent frame resolves selected-body follow before child processing")
	var presented: Vector2 = host.presentation_camera_origin()
	check(near(host.world_shader.get_shader_parameter("camera_origin_px"),presented),
		"terrain uniform contains this frame's followed camera")
	for overlay: Control in [host.physical_actor_overlay,host.actor_prototype_overlay,host.usable_overlay]:
		check(near(overlay._origin,presented),"overlay shares same-frame followed origin: "+overlay.get_class())
	bench._process(1.0/60.0)
	check(near(host.camera_origin,desired) and near(host.world_shader.get_shader_parameter("camera_origin_px"),
		host.presentation_camera_origin()),"child processing cannot move camera behind published terrain")
	bench._camera.select(0)
	bench.set_process(true)
	host.set_process(true)


func run() -> void:
	transforms()
	await mounted()
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	var source_hashes: Dictionary = {}
	for path: String in ["res://tests/test_native_pixel_camera.gd","res://scripts/main.gd",
			"res://scripts/pixel_camera_transform.gd","res://scripts/shared_workbench.gd",
			"res://scripts/workbench_paint_editor_controller.gd","res://scripts/workbench_paint_editor_overlay.gd",
			"res://shaders/material_palette.gdshader"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	var native_path: String = "res://addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so")
	var result := {"schema":"native-pixel-camera-v1","checks":checks,"failures":failures,
		"platform":OS.get_name(),"engine":Engine.get_version_info(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"transform_sha256":FileAccess.get_sha256("res://scripts/pixel_camera_transform.gd"),
		"source_hashes":source_hashes,"native_runtime_sha256":FileAccess.get_sha256(native_path),
		"native_receipts":native_receipts}
	var folder := OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not folder.is_empty() and DirAccess.make_dir_recursive_absolute(folder) == OK:
		var receipt := FileAccess.open(folder.path_join("native-pixel-camera.json"),FileAccess.WRITE)
		if receipt != null: receipt.store_string(JSON.stringify(result,"\t")+"\n")
	print("NATIVE_PIXEL_CAMERA_RESULT ",JSON.stringify(result))
	quit(int(not failures.is_empty()))
