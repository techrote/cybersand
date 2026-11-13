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
