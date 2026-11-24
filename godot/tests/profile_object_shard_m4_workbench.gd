extends SceneTree

# Render submission callbacks, native progress and physical segment counts are
# recorded independently. None of these is a physical monitor-present witness.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var submitted: int = 0
var submission_times: Array[int] = []
var callbacks: Array[int] = []
var progress: Array[Dictionary] = []
var body_counts: Array[int] = []
var native_ticks: Array[int] = []
var active_cohorts: Dictionary = {}
var active_bodies: int = 0
var active_max: int = 0
var scene_id: String = "tower"
var camera: String = "overview"
var output: String = ""
var sampling: String = "cohorts"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_id = arg.trim_prefix("--scene=")
		elif arg.begins_with("--camera="): camera = arg.trim_prefix("--camera=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--sampling="): sampling = arg.trim_prefix("--sampling=")
	_run.call_deferred()

func _post_draw() -> void:
	submitted += 1
	submission_times.append(Time.get_ticks_usec())
	if active_cohorts.has(active_bodies): active_cohorts[active_bodies].render_submissions += 1

func _active_count(value: Dictionary) -> int:
	var count: int = 0
	for body: Dictionary in value.get("physics",{}).get("bodies",[]):
		if bool(body.get("active",false)) and not bool(body.get("sleeping",true)): count += 1
	return count

func _cohort(value: Dictionary, elapsed: int, ticks: int, steps: int, acknowledgements: int) -> void:
	active_bodies = _active_count(value)
	active_max = maxi(active_max,active_bodies)
	if not active_cohorts.has(active_bodies):
		active_cohorts[active_bodies] = {"wall_usec":0,"process_callbacks":0,"semantic_ticks":0,
			"actual_physics_steps":0,"native_pose_acknowledgements":0,"render_submissions":0}
	var row: Dictionary = active_cohorts[active_bodies]
	row.wall_usec += elapsed
	row.process_callbacks += 1
	row.semantic_ticks += ticks
	row.actual_physics_steps += steps
	row.native_pose_acknowledgements += acknowledgements

func _distribution(values: Array[int]) -> Dictionary:
	if values.size() < 2: return {"count":0,"p50_usec":0,"p95_usec":0,"maximum_usec":0}
	var intervals: Array[int] = []
	for i: int in range(1, values.size()): intervals.append(values[i]-values[i-1])
	intervals.sort()
	return {"count":intervals.size(),"p50_usec":intervals[int((intervals.size()-1)*0.5)],
		"p95_usec":intervals[int((intervals.size()-1)*0.95)],"maximum_usec":intervals.back()}

func _run() -> void:
	f = Fixture.new(self)
	var result: Dictionary = {"schema":"objectshard-m4-workbench-profile-v1","scene":scene_id,"camera":camera,"sampling":sampling,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display_driver":DisplayServer.get_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"platform":OS.get_name(),
		"performance_scope":"process callbacks and actual renderer frame_post_draw submissions; physical GPU presentation OWNER-PENDING"}
	if not await f.open(scene_id):
		await _finish(result)
		return
	if sampling == "light": f.host.object_shard_m4_probe.configure(false)
	await f.pause()
	await f.until(f.whole_canvas_coherent,"baseline whole canvas material+pose coherence")
	result.inventory_before = {"wood":f.material_count(7),"brick":f.material_count(43)}
	result.material_populations_before = {"wood":f.material_count(7),"brick":f.material_count(43),
		"sand":f.material_count(2),"water":f.material_count(3),"fire":f.material_count(6)}
	f.expect(int(result.inventory_before.wood)>0,"complete independent baseline inventory available")
	if camera == "zoom": f.bench._set_view(Vector2(96,256),Vector2i(256,256))
	await f.cut_supports(scene_id)
	var expected: int = int(Fixture.Scenes.manifest(scene_id).expected_min_bodies)
	f.play()
	if not await f.until(func(): return f.body_count() >= expected,"native promotion reaches authored body count"):
		await _finish(result)
		return
	if scene_id == "timber":
		await f.pause()
		await f.until(f.coherent,"displayed moving Wood is available for source-bound ignition")
		result.ignition_witnesses = await f.ignite_exposed_wood()
		f.expect(result.ignition_witnesses.size() == 4,"timber profile genuinely ignites four exposed source-bound Wood cells")
		result.products_before = int(f.frame().get("metrics",{}).get("products_created",0))
		f.play()
	var first: Dictionary = f.diagnostics()
	active_max = _active_count(first)
	active_bodies = -1 if sampling == "light" else active_max
	if sampling == "light": active_cohorts[-1] = {"scope":"unclassified awake state; no per-callback physics readback","render_submissions":0}
	var first_native_metrics: Dictionary = f.frame().get("metrics",{}).duplicate(true)
	var first_accounting: Dictionary = f.frame().get("accounting",{}).duplicate(true)
	result.shard_dimensions = []
	for shard: Dictionary in f.frame().get("shards",[]):
		if shard.get("owns_inventory",false): result.shard_dimensions.append({"width":shard.width,"height":shard.height})
	var initial_tick: int = f.tick()
	var started: int = Time.get_ticks_usec()
	var previous_usec: int = started
	var previous_tick: int = initial_tick
	var previous_steps: int = int(first.physical_steps)
	var previous_acknowledgements: int = int(first.native_pose_acknowledgements)
	var target: int = initial_tick + 180
	var deadline: int = Time.get_ticks_msec()+Fixture.Watchdogs.milliseconds("operation_seconds")
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.connect(_post_draw)
	while f.tick() < target and Time.get_ticks_msec() < deadline and str(f.runtime().held_reason) == "":
		await process_frame
		var now: int = Time.get_ticks_usec()
		callbacks.append(now)
		body_counts.append(f.body_count())
		if sampling != "light":
			# Exactly one full diagnostic readback per sampled callback. The
			# fresh-scene light controls omit this readback and disable the probe.
			var state: Dictionary = f.diagnostics()
			_cohort(state,now-previous_usec,f.tick()-previous_tick,int(state.physical_steps)-previous_steps,
				int(state.native_pose_acknowledgements)-previous_acknowledgements)
		previous_usec = now
		previous_tick = f.tick()
		previous_steps = int(f.runtime().physical_steps)
		previous_acknowledgements = int(f.runtime().native_pose_acknowledgements)
		if native_ticks.is_empty() or native_ticks.back() != f.tick():
			native_ticks.append(f.tick())
			progress.append({"tick":f.tick(),"usec":Time.get_ticks_usec(),"bodies":f.body_count()})
	var elapsed: int = maxi(1,Time.get_ticks_usec()-started)
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.disconnect(_post_draw)
	f.expect(f.tick() >= target,"profile completes 180 actual native semantic ticks")
	f.expect(str(f.diagnostics().get("held_reason","")) == "","no native or physical hold during profile")
	var last: Dictionary = f.diagnostics()
	f.expect(int(last.physical_steps) > int(first.physical_steps),"real Rapier steps observed")
	f.expect(int(last.native_pose_acknowledgements) > int(first.native_pose_acknowledgements),"real native pose acknowledgements observed")
	f.expect(int(last.get("native_pose_echo_checks",0)) == int(last.native_pose_acknowledgements),
		"each accepted native pose exactly echoes the actual completed Rapier segment")
	if DisplayServer.get_name() != "headless": f.expect(submitted>0,"actual graphical renderer submits frames")
	result.elapsed_usec = elapsed
	result.completed_semantic_ticks = f.tick()-initial_tick
	result.semantic_ticks_per_wall_second = float(result.completed_semantic_ticks)*1000000.0/float(elapsed)
	result.process_callbacks_per_wall_second = float(callbacks.size())*1000000.0/float(elapsed)
	result.render_submissions_per_wall_second = float(submitted)*1000000.0/float(elapsed)
	result.render_submissions = submitted
	result.process_intervals = _distribution(callbacks)
	result.render_submission_intervals = _distribution(submission_times)
	result.native_progress_observations = progress
	result.body_count_min = body_counts.min() if not body_counts.is_empty() else 0
	result.body_count_max = body_counts.max() if not body_counts.is_empty() else 0
	result.active_body_count_max = active_max
	result.active_body_cohorts = active_cohorts
	result.cohort_scope = "intervals classified by observed real Rapier awake body count at callback end; transition intervals are not exact GPU samples"
	f.expect(active_max > 0,"profile actually observes awake Rapier bodies")
	result.actual_physics_steps = int(last.physical_steps)-int(first.physical_steps)
	result.native_pose_acknowledgements = int(last.native_pose_acknowledgements)-int(first.native_pose_acknowledgements)
	result.native_pose_echo_checks = int(last.get("native_pose_echo_checks",0))-int(first.get("native_pose_echo_checks",0))
	result.diagnostics = last
	result.native_cost_deltas = {}
	result.native_metrics_before = first_native_metrics
	result.native_metrics_after = f.frame().get("metrics",{}).duplicate(true)
	for key: String in first_native_metrics:
		if (key.ends_with("_ns") and not key.begins_with("maximum_")) or key in ["chemistry_cells","sweep_samples","mask_cells"]:
			result.native_cost_deltas[key] = int(f.frame().get("metrics",{}).get(key,0))-int(first_native_metrics[key])
	result.receipt_pump_usec_delta = int(last.pump_usec_total)-int(first.pump_usec_total)
	result.main_stage_deltas = {}
	for stage: String in last.get("main_costs",{}):
		var previous: Dictionary = first.get("main_costs",{}).get(stage,{})
		var latest: Dictionary = last.main_costs[stage]
		result.main_stage_deltas[stage] = {"calls":int(latest.get("calls",0))-int(previous.get("calls",0)),
			"usec":int(latest.get("usec",0))-int(previous.get("usec",0)),"cumulative_max_usec":latest.get("max_usec",0)}
	result.worker_stage_deltas = {}
	for counter: String in last.get("worker_profile",{}):
		if counter.ends_with("_calls") or (counter.ends_with("_usec") and not counter.ends_with("_max_usec")):
			result.worker_stage_deltas[counter] = int(last.worker_profile[counter])-int(first.get("worker_profile",{}).get(counter,0))
	result.stage_scope = "window deltas; native occupancy includes relocation, and Main receipt pump includes waits and its nested stages; these counters must not be summed as independent wall time"
	result.material_contact_deltas = {}
	for counter: String in ["accepted_exposures","consumed_exposures","extinguished","external_ignitions"]:
		result.material_contact_deltas[counter] = int(f.frame().get("accounting",{}).get(counter,0))-int(first_accounting.get(counter,0))
	for counter: String in ["sand_ingested","products_created","output_blocked"]:
		result.material_contact_deltas[counter] = int(f.frame().get("metrics",{}).get(counter,0))-int(first_native_metrics.get(counter,0))
	result.instrumentation_scope = "one diagnostic state readback per callback plus enabled ordinary latency probe" if sampling != "light" else "no per-callback physics readback and ordinary latency probe disabled; callback timestamps retained"
	if f.host.has_method("object_shard_m4_latency_report"): result.latency = f.host.object_shard_m4_latency_report()
	await f.pause()
	var old_render_serial: int = int(f.host.last_uploaded_render_snapshot_serial)
	f.bench.set_camera(2)
	if camera == "zoom":
		await f.until(func(): return f.whole_canvas_coherent() and int(f.host.last_uploaded_render_snapshot_serial)>old_render_serial,
			"profile overview refresh supplies new whole canvas material+pose publication")
	else: await f.until(f.whole_canvas_coherent,"profile final whole canvas material+pose coherence")
	f.validate_physics()
	f.validate_quantity_ledger()
	result.inventory_after = {"wood":f.material_count(7),"brick":f.material_count(43)}
	f.expect(int(result.inventory_after.wood)>=0,"complete independent final inventory available")
	# No flame contacts are present in these controls, so exact structural
	# inventory must survive physics, contacts and ownership transfers.
	if scene_id in ["tower","viaduct","stress"]:
		f.expect(result.inventory_before == result.inventory_after,"independent structural inventory conserved through complete workload")
	elif scene_id == "timber":
		for witness: Dictionary in result.get("ignition_witnesses",[]):
			var source: Dictionary = witness.source
			var after: Dictionary = f.owned_cell_state(int(source.owner),int(source.cell))
			witness.after = after
			f.expect(int(result.inventory_after.wood)<int(result.inventory_before.wood) or (after.get("material") == 7 \
				and int(after.get("state_b",0))>0 and int(after.get("state_b",0))<int(witness.before.get("state_b",0))),
				"exact exposed moving timber cell continues native combustion during profile")
		f.expect(int(f.frame().get("metrics",{}).get("products_created",0))>int(result.get("products_before",0)),
			"moving timber produces authentic native reaction products")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
		if not path.is_empty():
			DirAccess.make_dir_recursive_absolute(path)
			var image: Image = root.get_texture().get_image()
			f.expect(not image.is_empty() and image.save_png(path.path_join(scene_id+"-"+camera+".png")) == OK,
				"source-bound actual ordinary Workbench screenshot retained")
	await _finish(result)

func _finish(result: Dictionary) -> void:
	f.validate_display()
	result.display_coherence = f.display_witness()
	await f.close()
	result.checks = f.checks
	result.failures = f.failures
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result,"\t")+"\n")
			file.close()
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
