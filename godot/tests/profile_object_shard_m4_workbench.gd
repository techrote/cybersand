extends SceneTree

# Render submission callbacks, native progress and physical segment counts are
# recorded independently. None of these is a physical monitor-present witness.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Runtime = preload("res://scripts/object_shard_m4_runtime.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
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
var recording_override: String = ""
var recording_enabled: bool = true

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_id = arg.trim_prefix("--scene=")
		elif arg.begins_with("--camera="): camera = arg.trim_prefix("--camera=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--sampling="): sampling = arg.trim_prefix("--sampling=")
		elif arg.begins_with("--recording="): recording_override = arg.trim_prefix("--recording=")
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

func _authored_support_witness() -> Dictionary:
	var result: Dictionary = {"scope":"actual coherent native material image before ordinary support cuts; authored recipe populations are reported separately",
		"native_tick":f.tick(),"material_bodies_before_cut":f.body_count(),"support_cells":0,"missing_support_cells":0,
		"authored_material_populations":{}}
	f.expect(f.body_count()==0,"intact authored structure has no detached material body before support removal")
	var bytes: PackedByteArray = f.host.image.get_data()
	var channels: int = bytes.size()/(512*512)
	if not f.expect(channels in [1,2,4],"pre-cut support witness uses a complete ordinary native image"): return result
	for rect: Rect2i in Fixture.Scenes.manifest(scene_id).support_rects:
		# Include the first floor row: the actual full native post reaches its
		# rooted foundation rather than terminating in overwritten liquid.
		for y: int in range(rect.position.y,rect.end.y+1):
			for x: int in range(rect.position.x,rect.end.x):
				result.support_cells += 1
				if int(bytes[(y*512+x)*channels]) != Fixture.Scenes.WALL: result.missing_support_cells += 1
	f.expect(int(result.missing_support_cells)==0,"every declared support is actual native Wall continuously connected to the floor")
	var recipe: Dictionary = Setup.rectangles(f.bench.applied)
	if not f.expect(not recipe.has("error"),"authored start compiles to non-overlapping ordinary native rectangles"): return result
	for i: int in range(0,recipe.runs.size(),5):
		var material: int = int(recipe.runs[i+4])
		result.authored_material_populations[material] = int(result.authored_material_populations.get(material,0)) \
			+ int(recipe.runs[i+2])*int(recipe.runs[i+3])
	if scene_id=="mixed":
		f.expect(int(result.authored_material_populations.get(3,0))==2992 \
			and int(result.authored_material_populations.get(2,0))==1632,
			"mixed authored footprint preserves exactly 2992 Water and 1632 Sand cells around intact posts")
	elif scene_id=="viaduct":
		f.expect(int(result.authored_material_populations.get(3,0))==5120,
			"viaduct authored footprint preserves exactly 5120 Water cells around intact posts")
	return result

func _run() -> void:
	f = Fixture.new(self)
	recording_enabled = sampling != "light" if recording_override.is_empty() else recording_override == "on"
	var result: Dictionary = {"schema":"objectshard-m4-workbench-profile-v1","scene":scene_id,"camera":camera,"sampling":sampling,
		"recording_enabled":recording_enabled,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display_driver":DisplayServer.get_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"platform":OS.get_name(),
		"performance_scope":"process callbacks and actual renderer frame_post_draw submissions; physical GPU presentation OWNER-PENDING"}
	if not f.expect(sampling in ["cohorts","light"] and recording_override in ["","on","off"],"profile sampling and recording options are explicitly valid"):
		await _finish(result); return
	if not await f.open(scene_id):
		await _finish(result)
		return
	f.expect(f.bench.set_object_shard_diagnostics_enabled(recording_enabled),"profile explicitly selects its declared diagnostic recording")
	await f.pause()
	await f.until(f.whole_canvas_coherent,"baseline whole canvas material+pose coherence")
	result.before_cut_supports = _authored_support_witness()
	await f.validate_quantity_ledger()
	result.inventory_before = {"wood":f.material_count(7),"brick":f.material_count(43)}
	result.material_populations_before = {"wood":f.material_count(7),"brick":f.material_count(43),
		"sand":f.material_count(2),"water":f.material_count(3),"fire":f.material_count(6)}
	result.material_population_scope = "displayed material pixels plus owned material; Water pixels may include ballistic projection; raw grid census and exact quantity are in inventory_witnesses"
	f.expect(int(result.inventory_before.wood)>0,"complete independent baseline inventory available")
	if camera == "zoom": f.bench._set_view(Vector2(96,256),Vector2i(256,256))
	await f.cut_supports(scene_id)
	var expected: int = int(Fixture.Scenes.manifest(scene_id).expected_min_bodies)
	f.play()
	if not await f.until(func(): return f.body_count() >= expected,"native promotion reaches authored body count"):
		await _finish(result)
		return
	# A reserved RID precedes native inventory activation. Start the measured
	# workload only after the actual ownership/geometry barrier is complete.
	await f.pause()
	await f.until(func(): return f.runtime().physics_ready() and f.coherent(),"profile begins with installed native inventory and exact Rapier geometry")
	if scene_id == "timber":
		result.ignition_witnesses = await f.ignite_exposed_wood()
		f.expect(result.ignition_witnesses.size() == 4,"timber profile genuinely ignites four exposed source-bound Wood cells")
		result.products_before = int(f.frame().get("metrics",{}).get("products_created",0))
	var first: Dictionary = f.diagnostics()
	active_max = _active_count(first)
	active_bodies = -1 if sampling == "light" else active_max
	if sampling == "light": active_cohorts[-1] = {"scope":"unclassified awake state; no per-callback physics readback","render_submissions":0}
	var first_native_metrics: Dictionary = f.frame().get("metrics",{}).duplicate(true)
	var first_accounting: Dictionary = f.frame().get("accounting",{}).duplicate(true)
	result.shard_dimensions = []
	for shard: Dictionary in f.frame().get("shards",[]):
		if shard.get("owns_inventory",false): result.shard_dimensions.append({"width":shard.width,"height":shard.height})
	f.expect(result.shard_dimensions.size()>=expected,"timed workload has actual native inventory dimensions for every promoted body")
	var initial_tick: int = f.tick()
	var started: int = Time.get_ticks_usec()
	var next_heartbeat_usec: int = started+5000000
	var previous_usec: int = started
	var previous_tick: int = initial_tick
	var previous_steps: int = int(first.physical_steps)
	var previous_acknowledgements: int = int(first.native_pose_acknowledgements)
	var target: int = initial_tick + 180
	var deadline: int = Time.get_ticks_msec()+Fixture.Watchdogs.milliseconds("operation_seconds")
	f.play()
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.connect(_post_draw)
	while f.tick() < target and Time.get_ticks_msec() < deadline and str(f.runtime().held_reason) == "":
		await process_frame
		var now: int = Time.get_ticks_usec()
		callbacks.append(now)
		body_counts.append(f.body_count())
		if sampling != "light":
			# Exactly one full diagnostic readback per sampled callback. The
			# fresh-scene light controls omit this readback. Recording is an
			# independent option so matched light controls isolate its cost.
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
		if now >= next_heartbeat_usec:
			# Reuse already observed values; a heartbeat does not add native
			# snapshots or physics readbacks to the measured workload.
			print("M4_PROFILE_PROGRESS ",JSON.stringify({"scene":scene_id,"camera":camera,"sampling":sampling,
				"elapsed_usec":now-started,"native_tick":f.tick(),"completed_semantic_ticks":f.tick()-initial_tick,
				"render_submissions":submitted,"observed_awake_bodies":active_bodies,
				"process_callbacks":callbacks.size(),"material_body_count":f.body_count()}))
			next_heartbeat_usec = now+5000000
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
	result.completed_physical_intervals = int(last.physical_intervals)-int(first.physical_intervals)
	result.simulated_physical_seconds = float(result.completed_physical_intervals)*Runtime.PHYSICS_DELTA
	result.simulated_physical_seconds_per_wall_second = float(result.simulated_physical_seconds)*1000000.0/float(elapsed)
	result.physical_progress_scope = "completed actual 1/60-second Main intervals; partial in-flight segments excluded"
	f.expect(absi(int(result.completed_physical_intervals)-int(result.completed_semantic_ticks))<=1,
		"actual completed physics and native semantic intervals stay within the one pending boundary")
	result.native_pose_acknowledgements = int(last.native_pose_acknowledgements)-int(first.native_pose_acknowledgements)
	result.native_pose_echo_checks = int(last.get("native_pose_echo_checks",0))-int(first.get("native_pose_echo_checks",0))
	result.diagnostics = last
	result.native_cost_deltas = {}
	result.native_metrics_before = first_native_metrics
	result.native_metrics_after = f.frame().get("metrics",{}).duplicate(true)
	for key: String in first_native_metrics:
		if (key.ends_with("_ns") and not key.begins_with("maximum_")) or key in ["chemistry_cells","sweep_samples","mask_cells", "composed_reuses", "relocation_probes", "relocation_probe_limit_hits"]:
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
	for counter: String in ["sand_ingested","products_created","output_blocked", "relocated_cells", "relocated_water_cells", "relocated_sand_cells"]:
		result.material_contact_deltas[counter] = int(f.frame().get("metrics",{}).get(counter,0))-int(first_native_metrics.get(counter,0))
	if scene_id in ["mixed","viaduct"]:
		f.expect(int(result.material_contact_deltas.relocated_water_cells)>0,
			"falling authored structure commits real conservative native Water displacement")
	if scene_id=="mixed":
		f.expect(int(result.material_contact_deltas.relocated_sand_cells)>0,
			"mixed falling structure commits real conservative native Sand displacement")
	result.material_interaction_scope = "committed native carrier relocation, source-bound chemistry/exposure and optional Sand custody; no cellular fluid force or buoyancy transfer to Rapier is implemented"
	result.instrumentation_scope = ("one diagnostic state readback per callback" if sampling != "light" else "no per-callback physics readback; callback timestamps retained") \
		+ ("; ordinary latency probe enabled" if recording_enabled else "; ordinary latency probe disabled")
	if f.host.has_method("object_shard_m4_latency_report"):
		result.latency = f.host.object_shard_m4_latency_report()
		f.expect(bool(result.latency.enabled) == recording_enabled,"profile instrumentation state matches declared recording")
		if recording_enabled:
			f.expect(int(result.latency.events_retained)>0 and not result.latency.cadence.native_progress_delivery.is_empty(),
				"enabled profile actually records bounded timing events and native progression")
	await f.pause()
	f.bench.set_camera(2)
	# Ordinary Workbench keeps its complete native canvas active and uploaded
	# across camera transforms. A paused camera change should not force a
	# redundant native render packet or advance the material publication.
	await f.until(func(): return f.whole_canvas_coherent() and f.host.current_view_size==Vector2i(512,512) \
		and f.host.camera_origin==Vector2.ZERO,"profile overview reuses the complete coherent native canvas")
	var final_world_counts: PackedInt64Array = f.runtime().publication.get("world_material_counts",PackedInt64Array())
	result.final_boundary = {"latest_publication_sequence":f.frame().get("publication_sequence"),
		"displayed_publication_sequence":f.runtime().publication.get("publication_sequence"),
		"displayed_world_revision":f.runtime().publication.get("world_revision"),
		"uploaded_world_revision":f.host.last_uploaded_revision,"image_format":f.host.image.get_format(),
		"latest_native_tick":f.tick(),"displayed_native_tick":f.runtime().publication.get("tick"),
		"world_water_ledger":final_world_counts[3] if final_world_counts.size()>3 else -1,
		"rendered_water_pixels":f.material_count(3),"physics":f.diagnostics().get("physics",{}).get("bodies",[]),
		"displayed_poses":[]}
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if shard.get("owns_inventory",false): result.final_boundary.displayed_poses.append({"id":shard.id,"pose_serial":shard.get("pose_serial"),
			"position_x":shard.position_x,"position_y":shard.position_y,"rotation":shard.rotation})
	f.validate_physics()
	await f.validate_quantity_ledger()
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
	result.inventory_witnesses = f.inventory_witnesses
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
