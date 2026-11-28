extends SceneTree

# SCRIPT-HOTPATH-LATENCY-001: ordinary Workbench, actual exclusive native
# capture/PAINT worker, Godot UI planning and uploaded/presented framebuffer.
# One isolated operation per process. No synthetic executor or planner.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var editor: Control
var failures: Array[String] = []
var frame_gaps: Array[int] = []
var last_frame_usec := 0
var collect_frames := false

func _initialize() -> void:
	run.call_deferred()

func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if collect_frames and last_frame_usec > 0 and frame_gaps.size() < 50000:
		frame_gaps.append(now - last_frame_usec)
	last_frame_usec = now
	return false

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(label)
		push_error("PAINT_FILL_TOTAL_LATENCY " + label)
	return ok

func until(predicate: Callable, label: String, limit_ms: int = 240000) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return check(false, label + " / " + str(bench.message))

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and not host.simulation_worker.paint_state().busy

func settled() -> bool:
	return not editor.busy() and not host.simulation_worker.paint_state().busy

func cell_position(cell: Vector2i) -> Vector2:
	var content: Rect2 = host.view_content_rect()
	return content.position + (Vector2(cell) + Vector2(0.5,0.5) - Vector2(host.camera_origin.floor())) \
		* content.size / Vector2(host.current_view_size)

func border(from: Vector2i, to: Vector2i) -> bool:
	# Actual input path, not direct native emission. Setup is excluded from fill latency.
	editor.select_tool("Outline")
	editor.select_material(58)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = cell_position(from)
	bench._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = cell_position(to)
	motion.relative = motion.position - press.position
	bench._world_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = cell_position(to)
	bench._world_input(release)
	if not await until(settled, "outline setup",120000): return false
	return check(editor.last_receipt.get("status","") == "completed", "outline truly applied")

func native_readback(cell: Vector2i) -> int:
	var worker: RefCounted = host.simulation_worker
	var fence: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({
		"kind":"capture","region":Rect2i(cell,Vector2i.ONE),
		"expected_generation":int(fence.generation),
		"expected_revision":int(fence.revision),"expected_tick":int(fence.tick)})
	if not check(admitted.get("status","")=="queued","independent readback queued"): return -1
	if not await until(func()->bool:return worker.paint_state().receipt_ready,"independent readback receipt",30000): return -1
	var result: Dictionary=worker.paint_take_result()
	if not check(result.get("status","")=="completed","independent readback successful"): return -1
	var cells: PackedInt32Array=result.get("materials",PackedInt32Array())
	if not check(cells.size()==1,"independent readback one native ID"): return -1
	return cells[0]

# The pointer is WorldView-local, but the root framebuffer is Window pixels.
# Sample a regular set of interior cells rather than trusting a single
# possibly occluded point. Never infer visible success from revision ACK alone.
func interior_frame_samples(seed: Vector2i, side: int, screenshot: Image) -> Array[Dictionary]:
	var locations: Array[Dictionary] = []
	var spread: int = maxi(8, int(side / 6))
	var extent := Rect2i(Vector2i.ZERO,screenshot.get_size())
	for dy: int in [-2,-1,0,1,2]:
		for dx: int in [-2,-1,0,1,2]:
			var cell: Vector2i = seed + Vector2i(dx,dy)*spread
			var local: Vector2 = cell_position(cell)
			var screen: Vector2 = host.world_view.get_global_transform_with_canvas() * local
			var pixel: Vector2i = Vector2i(screen.round())
			if not extent.has_point(pixel): continue
			locations.append({"cell":cell,"pixel":pixel,"before":screenshot.get_pixelv(pixel)})
	return locations

# The Workbench shader uses an aspect-fit presentation path that is not
# equivalent to the mouse's cell-to-screen conversion. Take the actual
# rendered WorldView content bounds and compare pixels inside that region.
func visible_world_screen_rect(screenshot: Image) -> Rect2i:
	var local: Rect2 = host.view_content_rect()
	var canvas: Transform2D = host.world_view.get_global_transform_with_canvas()
	var a: Vector2 = canvas * local.position
	var b: Vector2 = canvas * local.end
	var low: Vector2i = Vector2i(a.min(b).floor())
	var high: Vector2i = Vector2i(a.max(b).ceil())
	return Rect2i(low,high-low).intersection(Rect2i(Vector2i.ZERO,screenshot.get_size()))

func changed_world_screen_samples(before: Image, after: Image, region: Rect2i) -> Dictionary:
	var checked := 0
	var changed := 0
	for y: int in range(region.position.y+3,region.end.y,6):
		for x: int in range(region.position.x+3,region.end.x,6):
			var prev: Color = before.get_pixel(x,y)
			var drawn: Color = after.get_pixel(x,y)
			var delta: float = absf(prev.r-drawn.r)+absf(prev.g-drawn.g)+absf(prev.b-drawn.b)
			checked += 1
			if delta > 0.12: changed += 1
	return {"checked":checked,"changed":changed}

func save_failure_frames(before: Image, after: Image) -> void:
	var directory := OS.get_environment("FILL_TOTAL_CAPTURE_DIR")
	if directory.is_empty(): return
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return
	before.save_png(directory.path_join("verification-before.png"))
	after.save_png(directory.path_join("verification-after.png"))

func percentile(samples: Array[int], fraction: float) -> int:
	if samples.is_empty(): return -1
	var sorted: Array[int] = samples.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(float(sorted.size())*fraction)-1,0,sorted.size()-1)]

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	var scenario := OS.get_environment("FILL_TOTAL_CASE")
	if scenario.is_empty(): scenario = "65k"
	var side: int = int({"16k":128,"65k":256,"262k":512}.get(scenario,0))
	if not check(side>0,"supported requested benchmark size"):
		quit(1)
		return
	var mode: String = "script" if OS.get_environment("CYBERSAND_NATIVE_PAINT_FILL")=="script" else "native"
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size = Vector2i(1440,1000)
	bench = host.shared_workbench
	editor = bench.paint_editor
	if not await until(ready,"mounted Workbench ready",60000):
		quit(1)
		return
	if not check(ClassDB.class_exists(&"CyberNativePaintPlanner"),"source-matched native planner class present"):
		quit(1)
		return
	var fresh := Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	if not check(bench.apply(fresh),"fresh blank 512 canvas"):
		quit(1)
		return
	if not await until(ready,"new native 512 World installed",60000):
		quit(1)
		return
	# A square camera keeps both corners of the 256x256 closed pocket visible.
	# The older 480x270 test view would send the far wall outside the canvas UI.
	bench._set_view(Vector2.ZERO,Vector2i(512,512))
	bench._brush.value = 0
	await process_frame
	var region := Rect2i(Vector2i.ZERO,Vector2i(512,512))
	var seed := Vector2i(256,256)
	if side < 512:
		var origin := Vector2i(120,120)
		var lower := origin-Vector2i.ONE
		var upper := origin+Vector2i(side,side)
		if not await border(lower,upper):
			quit(1)
			return
		region = Rect2i(lower,Vector2i(side+2,side+2))
		seed = origin+Vector2i(side >> 1,side >> 1)
	editor.select_tool("Fill")
	editor.select_material(58)
	editor.selection = region
	if not await until(func()->bool:return host.last_uploaded_revision == int(host.simulation_worker.paint_state().revision),
			"baseline frame uploaded",30000):
		quit(1)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var before_frame: Image = root.get_texture().get_image()
	var pixels: Array[Dictionary] = interior_frame_samples(seed,side,before_frame)
	var screen_world: Rect2i = visible_world_screen_rect(before_frame)
	if not check(screen_world.size.x>=128 and screen_world.size.y>=128,
			"actual framebuffer has sufficient WorldView content area"):
		quit(1)
		return
	var raw_before: Color = host.image.get_pixelv(seed)
	if not check(await native_readback(seed)==0,"source cell initially Empty"):
		quit(1)
		return
	if not await until(ready,"post-readback owner released",30000):
		quit(1)
		return
	editor.latency_probe_enabled = true
	frame_gaps.clear()
	last_frame_usec = Time.get_ticks_usec()
	collect_frames = true
	var accepted: bool = editor.fill_at(seed)
	if not check(accepted,"real Fill capture admitted"):
		quit(1)
		return
	if not await until(settled,"full capture/plan/native edit completed",240000):
		quit(1)
		return
	var trace: Dictionary=editor.latency_trace.duplicate(true)
	var receipt: Dictionary=editor.last_receipt
	if not check(str(receipt.get("status",""))=="completed","edit receipt completed"):
		quit(1)
		return
	var requested: int = side*side
	if not check(int(receipt.get("applied",-1))==requested,"all expected connected cells applied"):
		quit(1)
		return
	if not check(trace.get("captures",[]).size()==1,"single complete native source capture"):
		quit(1)
		return
	if not await until(func()->bool:return host.last_uploaded_revision>=int(receipt.get("revision",-1)),
			"edited revision actually uploaded",60000):
		quit(1)
		return
	var upload_observed_usec: int=Time.get_ticks_usec()
	# A single post-draw event can still show the old ping-pong texture while
	# blending. Measure the first drawn frame whose actual on-screen world
	# pixels materially change. Do not accept only a texture-upload receipt.
	var first_post_draw_usec := -1
	var visible_change_usec := -1
	var changed_pixels := 0
	var screen_samples := 0
	var render_attempts := 0
	var after_frame: Image
	for attempt: int in range(12):
		await RenderingServer.frame_post_draw
		var frame_usec: int = Time.get_ticks_usec()
		if first_post_draw_usec < 0: first_post_draw_usec = frame_usec
		after_frame = root.get_texture().get_image()
		render_attempts = attempt+1
		var observed: Dictionary = changed_world_screen_samples(before_frame,after_frame,screen_world)
		changed_pixels = int(observed.changed)
		screen_samples = int(observed.checked)
		if changed_pixels >= 32:
			visible_change_usec = frame_usec
			break
	collect_frames = false
	var raw_after: Color = host.image.get_pixelv(seed)
	var raw_material_changed: bool = raw_before != raw_after
	check(raw_material_changed,"GPU-backed material image changed after native edit")
	if visible_change_usec < 0:
		print("PAINT_FILL_TOTAL_VISUAL_DIAGNOSTIC ",JSON.stringify({
			"seed":seed,"side":side,"screen_size":before_frame.get_size(),
			"world_view_rect":Rect2(host.world_view.global_position,host.world_view.size),
			"view_content":host.view_content_rect(),
			"mapped_input_samples":pixels,"screen_world_rect":screen_world,
			"screen_world_samples":screen_samples,"changed_pixels":changed_pixels,
			"render_attempts":render_attempts,
			"raw_before":raw_before,"raw_after":raw_after,
			"last_uploaded_revision":host.last_uploaded_revision,
			"receipt_revision":receipt.get("revision",-1)}))
		save_failure_frames(before_frame,after_frame)
	check(visible_change_usec >= 0,"rendered WorldView changed at least 32 actual screen samples")
	check(await native_readback(seed)==58,"independent native readback confirms painted material")
	var captures: Array=trace.get("captures",[])
	var capture: Dictionary=captures[0] if not captures.is_empty() else {}
	var started: int=int(trace.get("requested_usec",first_post_draw_usec))
	var admitted: int=int(capture.get("admitted_usec",started))
	var captured: int=int(capture.get("receipt_usec",admitted))
	var plan_start: int=int(trace.get("plan_started_usec",captured))
	var plan_done: int=int(trace.get("plan_done_usec",plan_start))
	var edit_start: int=int(trace.get("edit_admitted_usec",plan_done))
	var edit_done: int=int(trace.get("edit_receipt_usec",edit_start))
	var recorded: int=int(trace.get("edit_recorded_usec",edit_done))
	var result: Dictionary={
		"schema":"paint-fill-total-latency-v1","status":"passed" if failures.is_empty() else "failed",
		"scenario":scenario,"mode":mode,"rendered":true,
		"active_graphics_adapter":RenderingServer.get_video_adapter_name(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"display_server":DisplayServer.get_name(),
		"requested_cells":requested,"applied":int(receipt.get("applied",0)),
		"source_native":true,"source_size":region.size,
		"capture_count":captures.size(),
		"capture_wall_usec":captured-admitted,
		"capture_executor_usec":int(capture.get("executor_elapsed_usec",-1)),
		"capture_slices":int(capture.get("slices",-1)),
		"planning_wall_usec":plan_done-plan_start,
		"planning_stages_usec":trace.get("plan_stages_usec",{}),
		"queue_to_edit_receipt_usec":edit_done-edit_start,
		"native_edit_executor_usec":int(trace.get("edit_executor_usec",-1)),
		"edit_slices":int(trace.get("edit_slices",-1)),
		"maximum_slice_usec":int(trace.get("edit_max_slice_usec",-1)),
		"receipt_to_record_usec":recorded-edit_done,
		"edit_receipt_to_upload_observed_usec":upload_observed_usec-edit_done,
		"request_to_draw_usec":(visible_change_usec if visible_change_usec >= 0 else first_post_draw_usec)-started,
		"request_to_first_post_draw_usec":first_post_draw_usec-started,
		"render_upload_observed_usec":upload_observed_usec,
		"first_post_draw_usec":first_post_draw_usec,
		"first_visible_post_draw_usec":visible_change_usec,
		"render_attempts":render_attempts,
		"mapped_input_samples":pixels.size(),
		"world_screen_sample_count":screen_samples,
		"changed_world_screen_samples":changed_pixels,
		"world_screen_sample_stride":6,
		"screen_world_rect":screen_world,
		"raw_material_pixel_changed":raw_material_changed,
		"frame_gap_p95_usec":percentile(frame_gaps,0.95),
		"frame_gap_p99_usec":percentile(frame_gaps,0.99),
		"frame_samples":frame_gaps.size(),
		"render_upload_ms":host.upload_time_ms,
		"render_patch_count":host.last_render_patch_count,
		"render_patch_bytes":host.last_render_patch_bytes,
		"render_was_full_refresh":host.last_render_was_full_refresh,
		"image_pixel_changed":visible_change_usec >= 0 and changed_pixels>=32,
		"failures":failures,
		"measurement_boundary":"UI request to first visibly changed post-draw screenshot after matching uploaded revision; GPU readback verification, not physical scanout",
		"timing_note":"Stages run across threads/frames and are not assumed additive; native worker elapsed includes scheduling gaps."}
	print("PAINT_FILL_TOTAL_LATENCY ",JSON.stringify(result))
	host.queue_free()
	await process_frame
	quit(int(not failures.is_empty()))
