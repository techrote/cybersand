extends SceneTree

# Identical external apparatus for accepted main and the integrated camera source.
# It mounts the real application and uses its existing owner/receipt interfaces.
# No second World, model request, solver policy or presentation default is added.
const Setup = preload("res://scripts/workbench_setup.gd")
const Stats = preload("res://scripts/worker_benchmark.gd")
const Context = preload("res://tests/palette_qualification_context.gd")

class ProfileHost extends "res://scripts/main.gd":
	var measured_main_usec := 0
	var measured_shader_usec := 0
	var measured_consume_usec := 0
	var measured_frame_state_usec := 0
	var pilot_action: Dictionary = {}
	func _actor_window_has_focus() -> bool: return true
	func _process(delta: float) -> void:
		measured_shader_usec = 0
		measured_consume_usec = 0
		measured_frame_state_usec = 0
		var started := Time.get_ticks_usec()
		super._process(delta)
		measured_main_usec = Time.get_ticks_usec() - started
	func update_shader_parameters() -> void:
		var started := Time.get_ticks_usec()
		super.update_shader_parameters()
		measured_shader_usec = Time.get_ticks_usec() - started
	func consume_worker_snapshot() -> void:
		var started := Time.get_ticks_usec()
		super.consume_worker_snapshot()
		measured_consume_usec = Time.get_ticks_usec() - started
	func update_worker_frame_state() -> void:
		var started := Time.get_ticks_usec()
		super.update_worker_frame_state()
		measured_frame_state_usec = Time.get_ticks_usec() - started
	func _publish_workbench_keyboard() -> void:
		if pilot_action.is_empty():
			super._publish_workbench_keyboard()
			return
		if paused or shared_workbench == null or physical_actor_session == null: return
		physical_actor_session.submit_workbench_action(shared_workbench.selected_id(),pilot_action,
			{"q":false,"e":false,"s":false,"boost":false},false)

var config: Dictionary = {}
var host: Control
var bench: Control
var editor: Control
var art: RefCounted
var failures: Array[String] = []
var frames: Array[Dictionary] = []
var publications: Array[Dictionary] = []
var uploads: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var participation: Array[Dictionary] = []
var pending_action: Dictionary = {}
var next_action := 0
var uploaded_serial := -1
var publication_serial := -1
var measurement_start_tick := -1
var measurement_world_generation := -1
var participation_sequence := -1
var started_usec := 0
var fixture_hash := ""
var setup_usec := 0
var initial_material_plane_sha256 := ""
var smoke_only := false
var base_origin := Vector2(64,64)
var base_view := Vector2i(240,135)
var actor_positions: Array[Vector2] = []

func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	print("INTEGRATED_CAMERA_PERF_PID ",OS.get_process_id())
	smoke_only = OS.get_environment("CYBERSAND_CAMERA_PERF_HEADLESS_SMOKE") == "1"
	var parsed: Variant = JSON.parse_string(OS.get_environment("CYBERSAND_CAMERA_PERF_CASE"))
	if parsed is Dictionary: config = parsed
	ProjectSettings.set_setting("cybersand/native_worker_threads",int(config.get("workers",1)))
	Engine.max_fps = 0
	run.call_deferred()

func require(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(label)
		push_error("INTEGRATED_CAMERA_PERF " + label)
	return ok

func next_frame() -> void:
	if smoke_only: await process_frame
	else: await RenderingServer.frame_post_draw

func until(predicate: Callable, label: String, limit_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	return require(false,label + " / " + str(host.microscenario_error if host != null else "no host"))

func settled() -> bool:
	return not editor.busy() and not host.simulation_worker.paint_state().busy and not art.active \
		and art.manual.is_empty() and art.manual_inflight.is_empty()

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and settled()

func fixture() -> Dictionary:
	var side: int = int(config.side)
	var value := Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(side,side))
	var edits: Array = value.edits
	edits.append_array([[0,0,side,2,58],[0,0,2,side,58],
		[side-2,0,2,side,58],[0,side-2,side,2,58]])
	var occupancy: String = config.occupancy
	if occupancy == "sparse":
		for y: int in range(24,side-40,128):
			for x: int in range(24,side-40,128): edits.append([x,y,24,16,58])
	elif occupancy == "dense":
		for y: int in range(8,side-8,32):
			edits.append([8,y,side-16,mini(24,side-8-y),58 if (y/32)%2 == 0 else 28])
	elif occupancy == "mixed":
		var materials := [58,28,35,81,98,120,123,127]
		for y: int in range(16,side-32,48):
			for x: int in range(16,side-32,48):
				edits.append([x,y,28,24,materials[((x-16)/48+(y-16)/48)%materials.size()]])
	else:
		# Reuse the established interleaved falling Sand/Water reference recipe.
		var rectangles: PackedInt32Array = Stats.fixture(side)
		for i: int in range(20,rectangles.size(),5):
			edits.append([rectangles[i],rectangles[i+1],rectangles[i+2],rectangles[i+3],rectangles[i+4]])
	if config.camera == "follow":
		# The ordinary retained physical session controls this actual flyer.
		# Clear its flight chamber through the authored setup, never live cells.
		edits.append([16,16,side-32,side-64,0])
		value.actors = [Setup.instance("kestrel",1,Vector2(side*0.5,side*0.35))]
		value.selected = 1
		value.next_id = 2
	fixture_hash = JSON.stringify(value).sha256_text()
	return value

func set_camera(frame: int) -> void:
	var mode: String = config.camera
	if mode == "follow":
		var state: Dictionary = bench.body_state(1)
		if not state.is_empty():
			var position: Vector2 = state.position
			actor_positions.append(position)
			var target := Vector2(float(config.side)*0.5+60*sin(float(frame)*0.025),
				float(config.side)*0.35+20*sin(float(frame)*0.017))
			host.pilot_action = {"move":((target-position)*0.05).limit_length(1.0),
				"trim":0.0,"primary":true,"effort":1.0}
		return
	var offset := Vector2.ZERO
	if mode == "slow_pan": offset = Vector2(float(frame%300)*0.1,0)
	elif mode == "pan": offset = Vector2(30*sin(float(frame)*0.025),18*sin(float(frame)*0.018))
	if mode == "zoom":
		# The accepted and integrated Workbench both expose this one-argument
		# centre zoom. Cursor-anchored overloads are camera-specific APIs.
		if frame%30 == 0: bench.zoom_by(1 if (frame/30)%2 == 0 else -1)
	else: bench._set_view(base_origin+offset,base_view)

func local(cell: Vector2i) -> Vector2:
	var area: Rect2 = host.view_content_rect()
	var origin: Vector2 = host.presentation_camera_origin() if host.has_method("presentation_camera_origin") else host.camera_origin.floor()
	return area.position+(Vector2(cell)+Vector2(0.5,0.5)-origin)*area.size/Vector2(host.current_view_size)

func begin_action(frame: int) -> void:
	if config.activity == "idle" or frame%24 != 0 or not pending_action.is_empty() or not settled(): return
	var material := 58 if next_action%2 == 0 else 0
	var anchor := Vector2i(96+((next_action/2)%4)*24,96)
	var start := Time.get_ticks_usec()
	pending_action = {"index":next_action,"frame":frame,"kind":config.activity,
		"start_usec":start,"material":material,"receipt_usec":0,"presented_usec":0}
	if config.activity == "manual":
		editor.select_tool("Brush")
		editor.select_material(material)
		bench._brush.value = 8
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = local(anchor)
		bench._world_input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = local(anchor)
		bench._world_input(release)
	else:
		var admission: Dictionary = art.submit([{"shape":"rectangle","x0":anchor.x,"y0":anchor.y,
			"x1":anchor.x+127,"y1":anchor.y+127,"material":material}],
			Rect2i(0,0,int(config.side),int(config.side)),[],[0,58])
		require(admission.get("status") == "queued","native batch accepted: "+str(admission))
	pending_action.submit_usec = Time.get_ticks_usec()-start
	next_action += 1

func observe_action() -> void:
	if pending_action.is_empty(): return
	if int(pending_action.receipt_usec) == 0 and settled():
		var receipt: Dictionary = editor.last_receipt if pending_action.kind == "manual" else art.result
		require(receipt.get("status") == "completed","authoring receipt completed: "+str(receipt))
		pending_action.receipt_usec = Time.get_ticks_usec()
		pending_action.native_revision = int(host.simulation_worker.paint_state().revision)
		pending_action.changed = int(receipt.get("changed",receipt.get("applied",0)))
		pending_action.status = str(receipt.get("status","missing"))
	if int(pending_action.receipt_usec) > 0 and host.last_uploaded_revision >= int(pending_action.native_revision):
		pending_action.presented_usec = Time.get_ticks_usec()
		pending_action.receipt_latency_ms = float(pending_action.receipt_usec-pending_action.start_usec)/1000.0
		pending_action.presentation_latency_ms = float(pending_action.presented_usec-pending_action.start_usec)/1000.0
		actions.append(pending_action.duplicate())
		pending_action.clear()

func observe_publication(frame: int) -> void:
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	if snapshot == null: return
	if snapshot.serial != publication_serial:
		publication_serial = snapshot.serial
		publications.append({"frame":frame,"serial":snapshot.serial,"tick":snapshot.tick_index,
			"world_generation":snapshot.render_world_generation,
			"native_tick_ms":snapshot.simulation_time_ms,"worker_step_ms":snapshot.worker_step_time_ms,
			"snapshot_copy_ms":snapshot.snapshot_copy_time_ms,"render_exchange_ms":snapshot.render_exchange_time_ms,
			"hard_surface_packet_ms":snapshot.hard_surface_packet_time_ms,
			"snapshot_publication_ms":snapshot.snapshot_publication_time_ms,
			"world_revision":snapshot.world_revision,"worker_overruns":snapshot.worker_overruns,
			"moves":snapshot.moves_last_tick,"scanned":snapshot.scanned_last_tick,
			"active_blocks":snapshot.active_blocks_last_tick,"scheduler_jobs":snapshot.scheduler_jobs_last_tick,
			"sparse_flight_moves":snapshot.sparse_flight_moves_last_tick})
	var sample: Dictionary = snapshot.native_worker_participation
	if not sample.is_empty() and int(sample.sequence) != participation_sequence:
		participation_sequence = int(sample.sequence)
		participation.append(sample.duplicate(true))
	if host.last_uploaded_render_snapshot_serial != uploaded_serial:
		uploaded_serial = host.last_uploaded_render_snapshot_serial
		uploads.append({"frame":frame,"serial":uploaded_serial,"upload_ms":host.upload_time_ms,
			"patch_bytes":host.last_render_patch_bytes,"patch_count":host.last_render_patch_count,
			"full_refresh":host.last_render_was_full_refresh,
			"submitted_texture_bytes":int(config.side)*int(config.side)*host.render_channels})

func frame_record(frame: int, elapsed_usec: int) -> Dictionary:
	var scale := physical_pixel_scale()
	var row := {"frame":frame,"frame_ms":float(elapsed_usec)/1000.0,
		"main_process_ms":float(host.measured_main_usec)/1000.0,
		"shader_update_ms":float(host.measured_shader_usec)/1000.0,
		"snapshot_consume_ms":float(host.measured_consume_usec)/1000.0,
		"worker_frame_state_ms":float(host.measured_frame_state_usec)/1000.0,
		"godot_process_ms":float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0,
		"godot_physics_ms":float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0,
		"godot_static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"godot_static_memory_peak_bytes":OS.get_static_memory_peak_usage(),
		"render_video_memory_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"camera":[host.camera_origin.x,host.camera_origin.y],"view":[host.current_view_size.x,host.current_view_size.y],
		"physical_pixel_scale":[scale.x,scale.y],
		"tick":host.latest_snapshot.tick_index if host.latest_snapshot != null else -1,
		"action_active":not pending_action.is_empty()}
	if RenderingServer.has_method("viewport_get_measured_render_time_cpu"):
		if not smoke_only:
			row.viewport_render_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			row.viewport_render_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	return row

func physical_view_transform() -> Transform2D:
	# CanvasItem.get_screen_transform() can omit root stretch when subwindows
	# are embedded. Use the actual viewport raster composition for BOTH source
	# subjects, including accepted main which has no camera transform helper.
	return host.world_view.get_viewport_transform()*host.world_view.get_global_transform()

func physical_pixel_scale() -> Vector2:
	var transform := physical_view_transform()
	return host.view_content_rect().size*Vector2(transform.x.length(),transform.y.length())/Vector2(host.current_view_size)

func transform_values(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]

func observed_camera_motion() -> Dictionary:
	var maximum := 0.0
	var distinct_views: Dictionary = {}
	if not frames.is_empty():
		var first := Vector2(float(frames[0].camera[0]),float(frames[0].camera[1]))
		for row: Dictionary in frames:
			maximum=maxf(maximum,first.distance_to(Vector2(float(row.camera[0]),float(row.camera[1]))))
			distinct_views[str(row.view)] = true
	return {"maximum_camera_displacement_cells":maximum,"distinct_view_sizes":distinct_views.size()}

func describe(values: Array[Dictionary], key: String) -> Dictionary:
	var numbers: Array[float] = []
	for value: Dictionary in values: numbers.append(float(value[key]))
	return Stats.statistics(numbers)

func completed_native_ticks() -> Array[Dictionary]:
	var seen: Dictionary = {}
	var completed: Array[Dictionary] = []
	for observation: Dictionary in publications:
		if not require(int(observation.world_generation) == measurement_world_generation,
			"measured phase retains its installed World generation"): continue
		var tick := int(observation.tick)
		if tick <= maxi(0,measurement_start_tick) or seen.has(tick): continue
		seen[tick] = true
		completed.append(observation)
	return completed

func finish() -> void:
	var native_ticks := completed_native_ticks()
	var result := {"schema":"integrated-camera-performance-v1","ok":failures.is_empty(),
		"failures":failures,"config":config,"fixture_sha256":fixture_hash,"smoke_only":smoke_only,
		"initial_material_plane_sha256":initial_material_plane_sha256,
		"elapsed_ms":float(Time.get_ticks_usec()-started_usec)/1000.0,"setup_ms":float(setup_usec)/1000.0,
		"context":Context.identity(get_script().resource_path,host.world_shader.shader if host != null else null),
		"frames":frames,"publications":publications,"uploads":uploads,"actions":actions,
		"measurement_start":{"tick":measurement_start_tick,"world_generation":measurement_world_generation},
		"camera_motion":observed_camera_motion(),
		"worker_participation":participation,
		"scope":"Real mounted Workbench; rendered-frame waits include test scheduling; Main timers include nested work; native tick summary deduplicates observed completed ticks after measurement start, not every native tick. Raw publications can repeat the last tick's values while paused/fenced. GPU timer zero means unavailable, not zero GPU cost. RSS/CPU observation is external. No inference requests.",
		"measurement_gaps":["No reliable allocation-rate counter","No hardware GPU utilization","Root render timer excludes separate effect viewports; shader timer is CPU submission, not fragment execution",
			"Godot TIME_PROCESS and TIME_PHYSICS_PROCESS are roughly one-second maximum gauges, not per-frame CPU samples"]}
	if host != null:
		result.world_extent = [host.world_extent.x,host.world_extent.y]
		result.worker_capacity = host.latest_snapshot.scheduler_thread_capacity_hint if host.latest_snapshot != null else 0
		result.native_backend = host.latest_snapshot.backend_name if host.latest_snapshot != null else "unavailable"
		result.view_content_rect = [host.view_content_rect().position.x,host.view_content_rect().position.y,
			host.view_content_rect().size.x,host.view_content_rect().size.y]
		result.actual_window = [root.size.x,root.size.y]
		var screen := physical_view_transform()
		var scale := physical_pixel_scale()
		result.actual_pixel_scale = [scale.x,scale.y]
		result.physical_view_transform = transform_values(screen)
		result.canvas_item_screen_transform = transform_values(host.world_view.get_screen_transform())
		result.root_final_transform = transform_values(root.get_final_transform())
		result.root_content_scale_size = [root.content_scale_size.x,root.content_scale_size.y]
		result.root_content_scale_mode = root.content_scale_mode
		result.root_content_scale_aspect = root.content_scale_aspect
		result.root_embed_subwindows = root.is_embedding_subwindows()
		result.root_framebuffer_size = [root.get_texture().get_width(),root.get_texture().get_height()]
		var physical_content: Rect2 = screen*host.view_content_rect()
		result.physical_content_rect = [physical_content.position.x,physical_content.position.y,
			physical_content.size.x,physical_content.size.y]
	if not frames.is_empty():
		result.summary = {}
		for key: String in ["frame_ms","main_process_ms","shader_update_ms","snapshot_consume_ms",
			"worker_frame_state_ms","godot_process_ms","godot_physics_ms","godot_static_memory_bytes"]:
			result.summary[key] = describe(frames,key)
		result.summary.upload_ms = describe(uploads,"upload_ms")
		result.summary.native_tick_ms = describe(native_ticks,"native_tick_ms")
		result.summary.publication_last_native_tick_ms = describe(publications,"native_tick_ms")
		result.summary.action_receipt_ms = describe(actions,"receipt_latency_ms")
		result.summary.action_presentation_ms = describe(actions,"presentation_latency_ms")
		result.tick_progress = int(frames.back().tick)-int(frames.front().tick)
	if actor_positions.size() > 1:
		var maximum := 0.0
		for position: Vector2 in actor_positions: maximum=maxf(maximum,position.distance_to(actor_positions[0]))
		result.actor_displacement_cells = maximum
	var output := OS.get_environment("CYBERSAND_CAMERA_PERF_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"\t")+"\n")
		else: require(false,"cannot write output receipt")
	print("INTEGRATED_CAMERA_PERF_RESULT ",JSON.stringify({"ok":failures.is_empty(),"case":config.get("id",""),
		"frames":frames.size(),"actions":actions.size(),"failures":failures}))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(int(not failures.is_empty()))

func run() -> void:
	if not require(not config.is_empty(),"case configuration supplied") or not require(DisplayServer.get_name() != "headless" or smoke_only,
		"graphical display required"):
		await finish()
		return
	if not smoke_only: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(int(config.window[0]),int(config.window[1]))
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(ProfileHost)
	root.add_child(host)
	bench = host.shared_workbench
	editor = bench.paint_editor
	art = bench.art_batches.executor
	if not await until(ready,"ordinary Workbench ready"):
		await finish()
		return
	if not require(host.latest_snapshot.backend_name == "native-phased","source-built native backend required"):
		await finish()
		return
	if not host.paused: bench.toggle_pause()
	var recipe := fixture()
	if not require(bench.apply(recipe),"benchmark fixture admitted") or not await until(ready,"benchmark fixture installed"):
		await finish()
		return
	if not await until(func() -> bool:
		return host.last_uploaded_revision == int(host.simulation_worker.paint_state().revision),"initial native material plane presented"):
		await finish()
		return
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(host.image.get_data())
	initial_material_plane_sha256 = hasher.finish().hex_encode()
	host.set_glow_enabled(bool(config.effects))
	host.set_vapour_trail_enabled(bool(config.effects))
	# Both subjects expose the same bounded opt-in native participation sampler.
	host.simulation_worker.set_worker_participation_sampling(true)
	base_view = Vector2i(int(config.view[0]),int(config.view[1]))
	# Fit the requested integer/fractional magnification to the real mounted UI.
	# The exact resulting physical scale is retained in the receipt; no render
	# surface is substituted for the ordinary Workbench control.
	if config.has("zoom"):
		await process_frame
		await process_frame
		var screen := physical_view_transform()
		var available: Vector2 = host.world_view.size*Vector2(screen.x.length(),screen.y.length())
		base_view = Vector2i((available/float(config.zoom)).floor()).max(Vector2i.ONE)
		base_view = base_view.min(Vector2i(int(config.side),int(config.side)))
	base_origin = Vector2(64,64)
	bench._camera.select(1 if config.camera == "follow" else 0)
	bench._set_view(base_origin,base_view)
	if not smoke_only and RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if bool(config.active): require(bench.toggle_pause(),"active fixture starts through Workbench")
	var warmup: int = int(config.get("warmup",32))
	for index: int in range(warmup):
		set_camera(index)
		await next_frame()
	setup_usec = Time.get_ticks_usec()-started_usec
	uploaded_serial = host.last_uploaded_render_snapshot_serial
	publication_serial = host.latest_snapshot.serial
	measurement_start_tick = host.latest_snapshot.tick_index
	measurement_world_generation = host.latest_snapshot.render_world_generation
	var sample_count: int = int(config.get("samples",180))
	var previous := Time.get_ticks_usec()
	for index: int in range(sample_count):
		set_camera(index)
		begin_action(index)
		await next_frame()
		var now := Time.get_ticks_usec()
		frames.append(frame_record(index,now-previous))
		previous = now
		observe_publication(index)
		observe_action()
		if host.simulation_worker.has_failed():
			require(false,"native failure during measurement: "+str(host.latest_snapshot.last_tick_error))
			break
	if not pending_action.is_empty():
		await until(func() -> bool:
			observe_action()
			return pending_action.is_empty(),"final action receipt/presentation",30000)
	require(frames.size() == sample_count,"complete requested sample count")
	if config.activity != "idle": require(not actions.is_empty(),"at least one acknowledged authoring action")
	if bool(config.active): require(int(frames.back().tick) > int(frames.front().tick),"native simulation advances")
	if config.camera == "follow":
		var moved := false
		for position: Vector2 in actor_positions:
			if position.distance_to(actor_positions[0]) > 1.0: moved=true
		require(moved,"follow workload contains a moving physical actor")
	var motion := observed_camera_motion()
	if config.camera in ["slow_pan","pan","follow"]:
		require(float(motion.maximum_camera_displacement_cells)>0.01,
			"requested camera workload actually moves inside the World bounds")
	if config.camera == "zoom":
		require(int(motion.distinct_view_sizes)>1,"zoom workload contains distinct actual view sizes")
	await finish()
