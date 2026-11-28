extends SceneTree

# Paired ordinary-Workbench controls separate the renderer's standing cost
# from semantic progression and active-body receipt scheduling. No render mode,
# shader, World material, Rapier pose or simulation result is replaced.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Runtime = preload("res://scripts/object_shard_m4_runtime.gd")
var f: RefCounted
var output: String = ""
var seconds: float = 12.0
var submissions: Array[int] = []
var rows: Array[Dictionary] = []
var control_identity: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--seconds="): seconds = clampf(float(arg.trim_prefix("--seconds=")), 5.0, 60.0)
	_run.call_deferred()

func _post_draw() -> void:
	submissions.append(Time.get_ticks_usec())

func _intervals(values: Array[int]) -> Dictionary:
	var intervals: Array[int] = []
	for i: int in range(1, values.size()): intervals.append(values[i]-values[i-1])
	intervals.sort()
	if intervals.is_empty(): return {"count":0}
	return {"count":intervals.size(),"p50_usec":intervals[int((intervals.size()-1)*0.5)],
		"p95_usec":intervals[int((intervals.size()-1)*0.95)],"maximum_usec":intervals.back()}

func _awake(value: Dictionary) -> int:
	var result: int = 0
	for body: Dictionary in value.get("physics",{}).get("bodies",[]):
		if body.get("active",false) and not body.get("sleeping",true): result += 1
	return result

func _measure(label: String) -> void:
	var first: Dictionary = f.diagnostics()
	var initial_tick: int = f.tick()
	var first_generation: int = int(f.frame().world_generation)
	var started: int = Time.get_ticks_usec()
	var next_heartbeat: int = started+5000000
	var callbacks: Array[int] = []
	submissions.clear()
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.connect(_post_draw)
	while Time.get_ticks_usec()-started < int(seconds*1000000.0) and str(f.runtime().held_reason).is_empty():
		await process_frame
		var now: int = Time.get_ticks_usec()
		callbacks.append(now)
		if now >= next_heartbeat:
			print("M4_RENDER_CONTROL_PROGRESS ",JSON.stringify({"label":label,"elapsed_usec":now-started,
				"semantic_ticks":f.tick()-initial_tick,"render_submissions":submissions.size()}))
			next_heartbeat=now+5000000
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.disconnect(_post_draw)
	var elapsed: int = maxi(1,Time.get_ticks_usec()-started)
	var last: Dictionary = f.diagnostics()
	var row: Dictionary = {"label":label,"paused":f.host.paused,"elapsed_usec":elapsed,
		"semantic_ticks":f.tick()-initial_tick,"render_submissions":submissions.size(),
		"process_callbacks":callbacks.size(),"native_pose_acknowledgements":int(last.native_pose_acknowledgements)-int(first.native_pose_acknowledgements),
		"actual_physics_steps":int(last.physical_steps)-int(first.physical_steps),
		"completed_physical_intervals":int(last.physical_intervals)-int(first.physical_intervals),
		"simulated_physical_seconds":float(int(last.physical_intervals)-int(first.physical_intervals))*Runtime.PHYSICS_DELTA,
		"native_pose_echo_checks":int(last.native_pose_echo_checks)-int(first.native_pose_echo_checks),
		"body_count_before":first.body_count,"body_count_after":last.body_count,
		"awake_bodies_before":_awake(first),"awake_bodies_after":_awake(last),
		"render_submissions_per_second":float(submissions.size())*1000000.0/elapsed,
		"semantic_ticks_per_second":float(f.tick()-initial_tick)*1000000.0/elapsed,
		"render_intervals":_intervals(submissions),"callback_intervals":_intervals(callbacks),
		"receipt_pump_usec":int(last.pump_usec_total)-int(first.pump_usec_total),
		"worker_snapshot_calls":int(last.worker_profile.snapshot_calls)-int(first.worker_profile.snapshot_calls),
		"worker_snapshot_usec":int(last.worker_profile.snapshot_usec)-int(first.worker_profile.snapshot_usec)}
	rows.append(row)
	f.expect(str(last.held_reason).is_empty(),label+" has no native or physical hold")
	f.expect(int(f.frame().world_generation)==first_generation,label+" retains the same ordinary World owner")
	f.expect(int(last.native_pose_echo_checks)==int(last.native_pose_acknowledgements),label+" every accepted segment has an exact native pose echo")
	if f.host.paused:
		f.expect(int(row.semantic_ticks)==0 and int(row.actual_physics_steps)==0,label+" advances no native or physical time while paused")
	else:
		f.expect(int(row.semantic_ticks)>0 and int(row.actual_physics_steps)>0,label+" advances actual native and Rapier time")
	if DisplayServer.get_name() != "headless": f.expect(not submissions.is_empty(),label+" submits actual graphical frames")
	if label=="detached_playing":
		f.expect(_awake(first)>0 or _awake(last)>0,"detached playing control observes an actual awake Rapier body at a window boundary")
	print("M4_RENDER_CONTROL_WINDOW ",JSON.stringify(row))

func _run() -> void:
	f=Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	f.bench.set_object_shard_diagnostics_enabled(false)
	await f.pause()
	await f.until(f.whole_canvas_coherent,"render control starts with a complete paired native image")
	control_identity = {"scene":"tower","camera":"overview","canvas_extent":[512,512],
		"authored_rectangles_sha256":JSON.stringify(Array(preload("res://scripts/workbench_setup.gd").rectangles(f.bench.applied).runs)).sha256_text(),
		"control_view":{"origin":[f.host.camera_origin.x,f.host.camera_origin.y],"size":[f.host.current_view_size.x,f.host.current_view_size.y]}}
	var baseline: Dictionary = {"wood":f.material_count(7),"brick":f.material_count(43)}
	f.expect(f.body_count()==0,"intact ordinary supports keep the tower in World")
	await _measure("intact_paused")
	f.play()
	await _measure("intact_playing")
	await f.pause()
	f.expect(f.body_count()==0,"uncut supported tower creates no active shard body")
	await f.cut_supports("tower")
	f.play()
	if not await f.until(func(): return f.body_count()>0,"ordinary support removal detaches the real tower"):
		await _finish(); return
	await f.pause()
	await f.until(func(): return f.runtime().physics_ready() and f.coherent(),"detached control waits for installed native inventory and Rapier geometry")
	await _measure("detached_paused")
	f.play()
	await _measure("detached_playing")
	await f.pause()
	await f.until(f.whole_canvas_coherent,"render controls finish on one complete native publication")
	f.validate_physics()
	await f.validate_quantity_ledger()
	f.expect(baseline=={"wood":f.material_count(7),"brick":f.material_count(43)},"independent structural inventory survives every paired render control")
	await _finish()

func _finish() -> void:
	f.validate_display()
	var result: Dictionary = {"schema":"objectshard-m4-render-control-v1","source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_driver":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"seconds_per_window":seconds,"windows":rows,"display_coherence":f.display_witness(),
		"checks":f.checks,"failures":f.failures,"inventory_witnesses":f.inventory_witnesses,
		"scope":"ordinary renderer submissions and actual native progression; awake counts observed only at window boundaries; physical seconds count completed 1/60 intervals; no per-callback full diagnostics, latency probe disabled; physical monitor presentation OWNER-PENDING"}
	result.merge(control_identity)
	await f.close()
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify(result,"\t")+"\n")
			file.close()
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
