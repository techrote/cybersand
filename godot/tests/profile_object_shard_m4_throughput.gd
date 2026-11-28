extends SceneTree

# One common light observer for matched disabled, zero, moving and sleeping
# workloads. No per-callback full diagnostics or inventory readback occurs in
# the measured window. Display callback cadence is not physical monitor FPS.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var workload: String = "tower"
var seconds: float = 6.0
var recording: bool = false
var output: String = ""
var submissions: int = 0
var result: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--workload="): workload = arg.trim_prefix("--workload=")
		elif arg.begins_with("--seconds="): seconds = clampf(float(arg.trim_prefix("--seconds=")),3.0,30.0)
		elif arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")=="on"
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _post_draw() -> void:
	submissions += 1

func _tick() -> int:
	return int(f.host.latest_snapshot.tick_index) if workload=="disabled" else f.tick()

func _owned_counts() -> Dictionary:
	var owned: int = 0
	var awake: int = 0
	for shard: Dictionary in f.frame().get("shards",[]):
		if not shard.get("has_body",false): continue
		owned += 1
		if not shard.get("sleeping",true): awake += 1
	return {"owned":owned,"awake":awake}

func _actual_sleeping() -> bool:
	if f.body_count()!=1: return false
	for body: Dictionary in f.runtime().bridge.bodies.values():
		if not body.get("active",false) or not bool(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_SLEEPING)):
			return false
	return true

func _open_disabled() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	f.host = load("res://main.tscn").instantiate()
	root.add_child(f.host)
	if not await f.until(f.installed,"disabled ordinary Workbench installed"): return false
	f.bench = f.host.shared_workbench
	if not f.expect(f.bench.apply(Fixture.Scenes.create("tower",PackedInt32Array(f.bench.applied.liquid_policy))),
		"disabled reference uses the same ordinary tower recipe"): return false
	if not await f.until(f.installed,"disabled authored tower installed"): return false
	f.bench.set_camera(2)
	f.play()
	var start: int = _tick()
	if not await f.until(func(): return _tick()>start,"disabled reference genuinely progresses"): return false
	f.bench.toggle_pause()
	var request: int = f.host.simulation_worker.workbench_pause_request_serial()
	return await f.until(func(): return f.host.paused and f.host.latest_snapshot.paused \
		and int(f.host.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1))>=request,
		"disabled reference acknowledges the exact ordinary Pause")

func _prepare_sleeping() -> bool:
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1],
		[140,440,20,8,7],[149,448,2,16,1]]
	authored.actors = [Setup.instance(Setup.BARREL,1,Vector2(408,432))]
	authored.next_id = 2
	authored.selected = 1
	if not f.expect(f.bench.apply(authored),"sleep workload authors a supported native plank and separate barrel"): return false
	if not await f.until(f.installed,"sleep workload installed"): return false
	f.bench.set_camera(2)
	f.play()
	# Ready may exist only between Main's idle and physical callbacks while
	# playing. Wait for durable attachment, then use the exact Pause barrier.
	if not await f.until(func(): return f.runtime().owns_terrain(),"sleep workload attaches ordinary owners"): return false
	if not await f.pause(): return false
	f.bench._brush.value = 2
	for y: int in [450,454,458,461]:
		for x: int in [149,150]:
			if not f.expect(f.bench.paint(Vector2i(x,y),0),"ordinary erase removes plank support"): return false
			await process_frame
	f.play()
	if not await f.until(func(): return f.body_count()==1,"one real plank detaches"): return false
	var before: Dictionary = f.frame().shards[0].duplicate(true)
	if not await f.until(_actual_sleeping,"real gravity/contact reaches natural Rapier sleep"): return false
	if not await f.pause(): return false
	f.expect(float(f.frame().shards[0].position_y)-float(before.position_y)>8.0,
		"sleeping body genuinely fell before natural solver rest")
	return f.expect(_actual_sleeping(),"Pause retains the real solver sleep state")

func _counter_delta(after: Dictionary, before: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for key: String in after:
		if after[key] is int and before.get(key) is int:
			delta[key] = int(after[key])-int(before[key])
	return delta

func _measure() -> void:
	# Qualify coherence separately. The performance window is uniformly light
	# across enabled/disabled modes and does not run Fixture's deep observer.
	if process_frame.is_connected(f._observe_callback): process_frame.disconnect(f._observe_callback)
	if RenderingServer.frame_post_draw.is_connected(f._observe_draw): RenderingServer.frame_post_draw.disconnect(f._observe_draw)
	var first: Dictionary = f.diagnostics()
	var first_worker: Dictionary = f.host.simulation_worker.object_shard_owner_profile()
	var initial: int = _tick()
	var initial_rapier: int = f.host.rapier_bridge.manual_step_count()
	var previous_tick: int = initial
	var previous: int = Time.get_ticks_usec()
	var started: int = previous
	var callbacks: int = 0
	var cohorts: Dictionary = {}
	var generation: int = int(f.host.latest_snapshot.render_world_generation)
	f.play()
	if DisplayServer.get_name()!="headless": RenderingServer.frame_post_draw.connect(_post_draw)
	while Time.get_ticks_usec()-started<int(seconds*1000000.0) and f.runtime().held_reason.is_empty() \
		and not f.host.simulation_worker.has_failed():
		await process_frame
		var now: int = Time.get_ticks_usec()
		var tick: int = _tick()
		var counts: Dictionary = _owned_counts()
		var key: String = "%d/%d" % [counts.owned,counts.awake]
		if not cohorts.has(key): cohorts[key] = {"owned":counts.owned,"awake":counts.awake,"wall_usec":0,"semantic_ticks":0,"callbacks":0}
		cohorts[key].wall_usec += now-previous
		cohorts[key].semantic_ticks += tick-previous_tick
		cohorts[key].callbacks += 1
		previous = now
		previous_tick = tick
		callbacks += 1
	var elapsed: int = maxi(1,Time.get_ticks_usec()-started)
	if DisplayServer.get_name()!="headless": RenderingServer.frame_post_draw.disconnect(_post_draw)
	var after: Dictionary = f.diagnostics()
	var last_worker: Dictionary = f.host.simulation_worker.object_shard_owner_profile()
	var ticks: int = _tick()-initial
	result.merge({"elapsed_usec":elapsed,"semantic_ticks":ticks,
		"semantic_ticks_per_second":float(ticks)*1000000.0/elapsed,
		"process_callbacks":callbacks,"process_callbacks_per_second":float(callbacks)*1000000.0/elapsed,
		"renderer_callbacks":submissions,"renderer_callbacks_per_second":float(submissions)*1000000.0/elapsed,
		"cohorts":cohorts,"runtime_counter_deltas":_counter_delta(after,first),
		"worker_counter_deltas":_counter_delta(last_worker,first_worker),
		"rapier_segments":f.host.rapier_bridge.manual_step_count()-initial_rapier,
		"before":first,"after":after,"control_timing_deltas":{}})
	for kind: String in after.get("control_timing",{}):
		result.control_timing_deltas[kind] = {}
		for stage: String in after.control_timing[kind]:
			result.control_timing_deltas[kind][stage] = _counter_delta(after.control_timing[kind][stage],
				first.get("control_timing",{}).get(kind,{}).get(stage,{"calls":0,"usec":0,"max_usec":0}))
	f.expect(ticks>0 and result.rapier_segments>0,"measured native and actual Rapier clocks both progress")
	f.expect(int(f.host.latest_snapshot.render_world_generation)==generation,"measurement retains its exact native World")
	f.expect(f.runtime().held_reason.is_empty() and not f.host.simulation_worker.has_failed(),"measurement has no protective/native failure")
	if workload=="disabled":
		f.expect(not f.runtime().enabled and not f.host.simulation_worker.object_shard_same_world_capabilities().get("native_attached",false),
			"disabled reference remains unattached throughout")
	else:
		f.expect(int(after.native_pose_acknowledgements)==int(after.native_pose_echo_checks),"every real native pose acknowledgement retains an exact echo")
		f.expect(absi(int(result.runtime_counter_deltas.physical_intervals)-ticks)<=1,"physical intervals and native ticks differ by at most one pending boundary")
		if workload=="sleeping": f.expect(_actual_sleeping() and cohorts.has("1/0") and cohorts.size()==1,
			"entire measured sleeping cohort remains naturally asleep while native time progresses")
		if workload in ["tower","stress"]:
			var expected: int = 8 if workload=="stress" else 1
			f.expect(cohorts.has("%d/%d" % [expected,expected]),"measurement actually observes the requested active structural cohort")
		if workload=="empty": f.expect(cohorts.has("0/0") and cohorts.size()==1,"enabled zero-body reference stays without detached inventory")
	if DisplayServer.get_name()!="headless": f.expect(submissions>0,"actual renderer callbacks were observed")
	result.latency = f.host.object_shard_m4_latency_report()
	f.expect(result.latency.enabled==recording,"recording mode matches the requested paired profile")

func _run() -> void:
	f = Fixture.new(self)
	result = {"schema":"objectshard-m4-throughput-v1","workload":workload,"recording_enabled":recording,
		"requested_seconds":seconds,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_driver":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"engine_version":Engine.get_version_info().string,"process_fps_cap":Engine.max_fps,
		"scope":"actual native semantic ticks and Main Rapier intervals; renderer callbacks are not physical monitor FPS; callback-end awake cohorts; no full per-callback diagnostic/coherence observers"}
	if not f.expect(workload in ["disabled","empty","tower","stress","sleeping"],"workload is explicit"):
		await _finish(); return
	var installed: bool = false
	if workload=="disabled": installed = await _open_disabled()
	else: installed = await f.open("stress" if workload=="stress" else "tower")
	if not installed:
		await _finish(); return
	if workload=="sleeping":
		if not await _prepare_sleeping():
			await _finish(); return
	elif workload in ["tower","stress"]:
		if not await f.cut_supports(workload):
			await _finish(); return
		f.play()
		var count: int = 8 if workload=="stress" else 1
		if not await f.until(func(): return f.body_count()>=count,"requested structural inventory detaches") or not await f.pause():
			await _finish(); return
	f.bench.set_object_shard_diagnostics_enabled(recording)
	result.authored_rectangles_sha256 = JSON.stringify(Array(Setup.rectangles(f.bench.applied).runs)).sha256_text()
	result.canvas_extent = [512,512]
	result.camera_origin = [f.host.camera_origin.x,f.host.camera_origin.y]
	result.view_size = [f.host.current_view_size.x,f.host.current_view_size.y]
	await _measure()
	if workload!="disabled":
		await f.pause()
		await f.until(f.coherent,"final full native publication is coherent after throughput sampling")
		f.validate_physics()
		await f.validate_quantity_ledger()
	await _finish()

func _finish() -> void:
	if f.host!=null: await f.close()
	result.checks = f.checks
	result.failures = f.failures
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify(result,"\t")+"\n")
			file.close()
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
