extends SceneTree

# RENDER-UPLOAD-001. Two explicitly separate cohorts: deterministic renderer
# seam fixtures and the real mounted native Workbench. Mounting/fixture helpers
# derive from PR566 run_integrated_camera_performance.gd at 90838045; its original
# evidence remains attributed to its own source. No camera code is imported.
const Host = preload("res://tests/support/render_upload_profile_host.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Stats = preload("res://scripts/worker_benchmark.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const SYNTHETIC := ["sparse","regions","dense","full","repeated","coverage"]
var config := {"strategy":"full","size":512,"workload":"sparse","frames":240,"warmup":30,"workers":1,"output":""}
var host: Control
var bench: Control
var editor: Control
var art: RefCounted
var frames: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var failures: Array[String] = []
var pending_action: Dictionary = {}
var action_index := 0
var initialized_image_sha := ""
var fixture_sha := ""
var start_usec := 0
var setup_usec := 0
var render_plane: Image
var synthetic := false
var coverage_fraction := -1.0
var coverage_phase_frame := -1

func _initialize() -> void:
	start_usec = Time.get_ticks_usec()
	print("RENDER_UPLOAD_PID ",OS.get_process_id())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair := arg.substr(2).split("=",true,1)
			if pair[0] in ["size","frames","warmup","workers"]: config[pair[0]]=int(pair[1])
			elif config.has(pair[0]): config[pair[0]]=pair[1]
	synthetic = str(config.workload) in SYNTHETIC
	ProjectSettings.set_setting("cybersand/native_worker_threads",int(config.workers))
	Engine.max_fps=0
	run.call_deferred()

func require(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("RENDER_UPLOAD_BENCH: "+message)
	return ok

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func until(predicate: Callable, message: String, timeout_ms := 90000) -> bool:
	var end := Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	return require(false,message)

func settled() -> bool:
	return not editor.busy() and not host.simulation_worker.paint_state().busy and not art.active \
		and art.manual.is_empty() and art.manual_inflight.is_empty()

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty() and settled()

func create_synthetic() -> void:
	host=Host.new()
	host.render_upload_strategy_override=str(config.strategy)
	host.world_extent=Vector2i(int(config.size),int(config.size))
	host.render_channels=2
	host.render_image_format=Image.FORMAT_RG8
	host.image=Image.create_empty(config.size,config.size,false,Image.FORMAT_RG8)
	# Static structural and condition-bearing material strips; this Image is a
	# test fixture only, not a second authoritative World or live mutation path.
	for y: int in range(8,config.size,64):
		host.image.fill_rect(Rect2i(0,y,config.size,16),Color(58.0/255.0,0,0,1))
	host.world_view=TextureRect.new()
	host.world_view.size=Vector2(640,360)
	host.world_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	host.world_view.stretch_mode=TextureRect.STRETCH_SCALE
	host.world_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	host.world_shader=ShaderMaterial.new()
	host.world_shader.shader=CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	host.world_view.material=host.world_shader
	host.current_view_size=Vector2i(320,180)
	host.create_render_textures()
	host.world_view.texture=host.texture
	var uniforms := {"world_size_px":Vector2(host.world_extent),"view_size_px":Vector2(320,180),
		"view_rect_uv":Vector4(0,0,1,1),"camera_origin_px":Vector2(32,32),
		"player_origin_px":Vector2(-1000,-1000),"condition_projection_enabled":1.0,
		"presentation_time_override":4.0,"snapshot_blend":1.0,
		"current_world_texture":host.texture,"previous_world_texture":host.previous_texture,
		"material_lut":CyberMaterialAppearanceLut.create_texture(),
		"material_program_lut":CyberMaterialAppearanceLut.create_program_texture()}
	for key: String in uniforms: host.world_shader.set_shader_parameter(key,uniforms[key])
	root.add_child(host.world_view)
	fixture_sha=digest(host.image.get_data())

func native_fixture() -> Dictionary:
	var side: int=config.size
	var setup: Dictionary=Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(side,side))
	var edits: Array=setup.edits
	edits.append_array([[0,0,side,2,58],[0,0,2,side,58],[side-2,0,2,side,58],[0,side-2,side,2,58]])
	if config.workload=="active":
		var rectangles: PackedInt32Array=Stats.fixture(side)
		for index: int in range(20,rectangles.size(),5):
			edits.append([rectangles[index],rectangles[index+1],rectangles[index+2],rectangles[index+3],rectangles[index+4]])
	elif config.workload in ["dormant","burst"]:
		# Isolated active area in an otherwise mostly dormant finite World.
		edits.append_array([[80,80,28,24,2],[120,80,28,24,3],[72,180,100,3,58]])
	else:
		for y: int in range(24,side-40,128):
			for x: int in range(24,side-40,128): edits.append([x,y,24,16,58])
	fixture_sha=JSON.stringify(setup).sha256_text()
	return setup

func create_native() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(Host)
	host.render_upload_strategy_override=str(config.strategy)
	root.add_child(host)
	bench=host.shared_workbench
	editor=bench.paint_editor
	art=bench.art_batches.executor
	if not await until(ready,"initial Workbench ready"): return false
	if not require(host.latest_snapshot.backend_name=="native-phased","native backend required"): return false
	if not host.paused: bench.toggle_pause()
	if not require(bench.apply(native_fixture()),"fixture accepted") or not await until(ready,"fixture installed"): return false
	if not await until(func() -> bool: return host.last_uploaded_revision==int(host.simulation_worker.paint_state().revision),"fixture render revision"): return false
	bench._camera.select(0)
	bench._set_view(Vector2(64,64),Vector2i(320,180))
	return true

func synthetic_update(frame: int) -> void:
	var side: int=config.size
	var rects: Array[Rect2i]=[]
	match str(config.workload):
		"sparse": rects=[Rect2i(32+(frame*13)%(side-64),32+(frame*7)%(side-64),1,1)]
		"repeated": rects=[Rect2i(96,96,8,8)]
		"regions":
			for i: int in range(12): rects.append(Rect2i((31+i*137+frame*3)%(side-16),(47+i*97)%(side-16),8,8))
			rects.append(Rect2i(1,side/2,side-2,1))
		"dense": rects=[Rect2i(0,0,side,side*3/4)]
		"full": rects=[Rect2i(0,0,side,side)]
		"coverage":
			var phase_frames:=maxi(16,int(config.frames)/6)
			var sample_frame:=maxi(0,frame-int(config.warmup))
			var phase:=mini(5,sample_frame/phase_frames)
			coverage_fraction=[0.01,0.05,0.1,0.25,0.5,1.0][phase]
			coverage_phase_frame=sample_frame%phase_frames
			rects=[Rect2i(0,0,side,maxi(1,roundi(side*coverage_fraction)))]
	var metadata:=PackedInt32Array()
	var payload:=PackedByteArray()
	for rect: Rect2i in rects:
		var patch:=Image.create_empty(rect.size.x,rect.size.y,false,Image.FORMAT_RG8)
		patch.fill(Color(float(3 if frame%2==0 else 58)/255.0,float((frame*37)%256)/255.0,0,1))
		metadata.append_array(PackedInt32Array([rect.position.x,rect.position.y,rect.size.x,rect.size.y,payload.size(),rect.size.x*2]))
		payload.append_array(patch.get_data())
	require(host.upload_texture_patches(metadata,payload,frame+1,2),"synthetic complete publication")
	# Full frame includes frame scheduling and shader drawing; upload stages
	# exclude fixture construction and include only the real Main handoff path.
	host.world_shader.set_shader_parameter("snapshot_blend",0.5 if frame%3==0 else 1.0)

func local(cell: Vector2i) -> Vector2:
	var area: Rect2=host.view_content_rect()
	return area.position+(Vector2(cell)+Vector2(0.5,0.5)-host.camera_origin.floor())*area.size/Vector2(host.current_view_size)

func native_action(frame: int) -> void:
	if config.workload not in ["manual","burst"]: return
	var target_actions:=mini(16,ceili(float(config.frames)/8.0)) if config.workload=="manual" else mini(8,maxi(1,int(config.frames)/8))
	if config.workload=="burst" and action_index>=target_actions:
		if settled() and host.paused: require(bench.toggle_pause(),"burst resumes simulation")
		return
	if action_index>=target_actions: return
	if not pending_action.is_empty() or not settled() or frame%(8 if config.workload=="manual" else 2)!=0: return
	var material:=58 if action_index%2==0 else 0
	var anchor:=Vector2i(96+((action_index/2)%4)*24,110)
	pending_action={"index":action_index,"frame":frame,"start_usec":Time.get_ticks_usec(),"receipt_usec":0,"native_revision":-1,
		"before_revision":int(host.simulation_worker.paint_state().revision),
		"before_operation_id":int(editor.last_receipt.get("operation_id",-1))}
	if config.workload=="manual":
		editor.select_tool("Brush")
		editor.select_material(material)
		bench._brush.value=8
		var press:=InputEventMouseButton.new()
		press.button_index=MOUSE_BUTTON_LEFT
		press.pressed=true
		press.position=local(anchor)
		bench._world_input(press)
		var release:=InputEventMouseButton.new()
		release.button_index=MOUSE_BUTTON_LEFT
		release.position=press.position
		bench._world_input(release)
	else:
		var receipt: Dictionary=art.submit([{"shape":"rectangle","x0":anchor.x,"y0":anchor.y,"x1":anchor.x+31,"y1":anchor.y+31,"material":material}],Rect2i(0,0,config.size,config.size),[],[0,58])
		require(receipt.get("status")=="queued","native Art batch queued")
	action_index+=1

func observe_action() -> void:
	if pending_action.is_empty(): return
	if int(pending_action.receipt_usec)==0 and settled():
		# A no-op/missed GUI event must not reuse an old completed editor receipt.
		if int(host.simulation_worker.paint_state().revision)<=int(pending_action.before_revision): return
		var receipt: Dictionary=editor.last_receipt if config.workload=="manual" else art.result
		require(receipt.get("status")=="completed","native edit receipt completed")
		if config.workload=="manual":
			require(int(receipt.get("operation_id",-1))!=int(pending_action.before_operation_id),"new PAINT operation identity")
			pending_action.operation_id=int(receipt.get("operation_id",-1))
		pending_action.receipt_usec=Time.get_ticks_usec()
		pending_action.native_revision=int(host.simulation_worker.paint_state().revision)
		pending_action.changed=int(receipt.get("changed",receipt.get("applied",0)))
		require(pending_action.changed>0,"new native edit changed stored cells")
	if int(pending_action.receipt_usec)>0 and host.last_uploaded_revision>=int(pending_action.native_revision):
		pending_action.upload_observed_usec=Time.get_ticks_usec()
		pending_action.receipt_ms=float(pending_action.receipt_usec-pending_action.start_usec)/1000.0
		pending_action.publication_observed_ms=float(pending_action.upload_observed_usec-pending_action.start_usec)/1000.0
		actions.append(pending_action.duplicate())
		pending_action.clear()

func frame_record(index: int, duration: int, before_uploads: int) -> Dictionary:
	return {"frame":index,"frame_ms":float(duration)/1000.0,
		"coverage_fraction":coverage_fraction,"coverage_phase_frame":coverage_phase_frame,
		"upload_count":host.upload_samples.size()-before_uploads,
		"main_ms":float(host.main_usec)/1000.0,"shader_update_ms":float(host.shader_usec)/1000.0,
		"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"video_memory_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tick":host.latest_snapshot.tick_index if host.latest_snapshot!=null else -1}

func finish() -> void:
	var result: Dictionary={"schema":"render-upload-001-benchmark-v1","ok":failures.is_empty(),"failures":failures,
		"config":config,"strategy":config.strategy,"size":config.size,"workload":config.workload,"workers":config.workers,
		"context":Context.identity(get_script().resource_path,host.world_shader.shader if host!=null else null),
		"fixture_sha256":fixture_sha,"initial_image_sha256":initialized_image_sha,
		"cohort":"deterministic_renderer_seam" if synthetic else "mounted_native_workbench",
		"requested_workers":config.workers,
		"setup_ms":float(setup_usec)/1000.0,"elapsed_ms":float(Time.get_ticks_usec()-start_usec)/1000.0,
		"frames":frames,"uploads":host.upload_samples if host!=null else [],
		"publications":host.publication_samples if host!=null else [],"actions":actions,
		"measurement_limits":["CPU elapsed intervals are not GPU transfer time or physical bandwidth.",
			"Frame intervals include benchmark scheduling and fixture/action generation.",
			"Native workloads are asynchronous: compare tick throughput and observed publications, not identical final states.",
			"Requested native worker count can be clamped to host capacity; actual immutable capacity is reported separately.",
			"Publication observed latency ends at a frame event after accepted texture submission; physical scanout is unmeasured.",
			"Static/video monitors are engine counters; process RSS is recorded separately by orchestrator."]}
	if host!=null:
		result.final_image_sha256=digest(host.image.get_data())
		result.final_strategy=host.render_upload_status
		result.native_backend=host.latest_snapshot.backend_name if host.latest_snapshot!=null else "fixture-only"
		result.actual_native_worker_capacity=host.latest_snapshot.scheduler_thread_capacity_hint if host.latest_snapshot!=null and not synthetic else null
		result.world_extent=[host.world_extent.x,host.world_extent.y]
		result.rejected_publications=host.rejected_render_snapshot_count
		if not frames.is_empty() and not synthetic:
			var measured_seconds:=0.0
			for frame: Dictionary in frames: measured_seconds+=float(frame.frame_ms)/1000.0
			result.measured_seconds=measured_seconds
			result.tick_progress=int(frames.back().tick)-int(frames.front().tick)
			result.observed_ticks_per_second=float(result.tick_progress)/maxf(measured_seconds,0.000001)
			var seen_ticks: Dictionary={}
			var observed_tick_times: Array[float]=[]
			for publication: Dictionary in host.publication_samples:
				var key:=str(publication.generation)+":"+str(publication.tick)
				if int(publication.tick)>0 and not seen_ticks.has(key):
					seen_ticks[key]=true
					observed_tick_times.append(float(publication.native_tick_ms))
			result.distinct_observed_native_tick_ms=Stats.statistics(observed_tick_times)
	var path: String=config.output
	if not path.is_empty():
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(result,"\t")+"\n")
		else: require(false,"output file writable")
	print("RENDER_UPLOAD_RESULT ",JSON.stringify({"ok":failures.is_empty(),"config":config,"frames":frames.size(),"uploads":result.uploads.size(),"actions":actions.size(),"failures":failures}))
	if host!=null:
		if synthetic:
			host.world_view.queue_free()
			if host._render_upload_experiment!=null: host._render_upload_experiment.close()
			host.free()
		else: host.queue_free()
		await process_frame
		await process_frame
	quit(int(not failures.is_empty()))

func run() -> void:
	if not require(DisplayServer.get_name()!="headless","graphical display required") or not require(config.size in [512,1024,2048],"supported dimensions"):
		await finish()
		return
	if not require(str(config.workload) in SYNTHETIC or config.workload in ["manual","burst","active","dormant"],"declared workload") or not require(config.strategy in ["full","drawable"],"declared strategy"):
		await finish()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(960,720)
	if synthetic: create_synthetic()
	elif not await create_native():
		await finish()
		return
	initialized_image_sha=digest(host.image.get_data())
	for i: int in range(config.warmup):
		if synthetic: synthetic_update(i)
		await RenderingServer.frame_post_draw
	setup_usec=Time.get_ticks_usec()-start_usec
	if not synthetic and config.workload in ["active","dormant"]: require(bench.toggle_pause(),"native simulation starts after identical paused warmup")
	host.measuring=true
	var previous_frame_usec:=Time.get_ticks_usec()
	for index: int in range(config.frames):
		var before_uploads: int=host.upload_samples.size()
		if synthetic: synthetic_update(index+int(config.warmup))
		else: native_action(index)
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		for upload_index: int in range(before_uploads,host.upload_samples.size()):
			var upload: Dictionary=host.upload_samples[upload_index]
			upload.post_draw_observed_usec=now
			upload.submit_to_post_draw_ms=float(now-int(upload.end_usec))/1000.0
			upload.material_to_post_draw_ms=float(now-int(upload.material_generated_usec))/1000.0 if int(upload.material_generated_usec)>0 else null
		frames.append(frame_record(index,now-previous_frame_usec,before_uploads))
		previous_frame_usec=now
		if not synthetic: observe_action()
		if not failures.is_empty(): break
	if not synthetic and config.workload in ["manual","burst"]:
		require(pending_action.is_empty(),"all native edit acknowledgements completed inside measured frames")
	host.measuring=false
	if not synthetic and not pending_action.is_empty():
		await until(func() -> bool:
			observe_action()
			return pending_action.is_empty(),"final native edit and render acknowledgement",90000)
	require(frames.size()==config.frames,"all frame samples collected")
	if not synthetic and config.workload in ["active","dormant"]:
		require(frames.back().tick>frames.front().tick,"native simulation progressed")
	if not synthetic and config.workload in ["manual","burst"]:
		var expected_actions:=mini(16,ceili(float(config.frames)/8.0)) if config.workload=="manual" else mini(8,maxi(1,int(config.frames)/8))
		require(actions.size()==expected_actions,"all fixed-count native edits completed")
	if config.strategy=="drawable": require(host._render_upload_experiment!=null,"experimental path remained active")
	await finish()
