extends SceneTree

# RENDER-UPLOAD-577. Two explicitly separate cohorts: deterministic renderer
# seam fixtures and the real mounted native Workbench. Mounting/fixture helpers
# derive from PR566 run_integrated_camera_performance.gd at 90838045; its original
# evidence remains attributed to its own source. No camera code is imported.
const Host = preload("res://tests/support/render_upload_577_profile_host.gd")
const ProfileWorker = preload("res://tests/support/render_upload_577_profile_worker.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Stats = preload("res://scripts/worker_benchmark.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const PRESSURE_DAM_SOURCE := "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const SYNTHETIC := ["sparse","regions","dense","full","repeated","coverage","transition"]
var config := {"strategy":"full","size":512,"workload":"sparse","frames":240,"warmup":30,"workers":1,"family":"freemass_v1","channels":2,"ack":"normal","fixture":"workload_v1","output":""}
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
var start_native_tick := 0
var start_rapier_step := 0
var start_native_capture_counters: Dictionary = {}
var native_capture_result: Dictionary = {}
var camera_stress_samples: Array[Dictionary] = []
var ack_recovery: Dictionary = {}
var shader_preparation_at_measurement: Dictionary = {}
var fixture_identity: Dictionary = {}
var native_play_requested := false
var worker_running_observed := false
var native_health := {"schema":"render-upload-577-native-health-v1","applicable":false,
	"before":{},"after_timing":{},"final":{},"first_failure":{},"failure_observations":0,
	"scope":"Read-only worker.has_failed and latest immutable worker publication, independently of Main consumption; no native World access"}

func _initialize() -> void:
	start_usec = Time.get_ticks_usec()
	print("RENDER_UPLOAD_PID ",OS.get_process_id())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair := arg.substr(2).split("=",true,1)
			if pair[0] in ["size","frames","warmup","workers","channels"]: config[pair[0]]=int(pair[1])
			elif config.has(pair[0]): config[pair[0]]=pair[1]
	synthetic = str(config.workload) in SYNTHETIC
	native_health.applicable=not synthetic
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
		if host != null and host.simulation_worker.has_failed():
			observe_native_health("setup_or_recovery",-1)
			break
		await process_frame
	return require(false,message)

func snapshot_health(snapshot: CyberSimulationSnapshot) -> Dictionary:
	if snapshot==null: return {"available":false}
	return {"available":true,"snapshot_serial":snapshot.serial,"published_usec":snapshot.published_usec,
		"tick_index":snapshot.tick_index,"simulation_world_revision":snapshot.simulation_world_revision,
		"world_revision":snapshot.world_revision,"render_world_generation":snapshot.render_world_generation,
		"render_snapshot_serial":snapshot.render_snapshot_serial,"render_tick_index":snapshot.render_tick_index,
		"backend_name":snapshot.backend_name,"simulation_failed":snapshot.simulation_failed,
		"failed_tick_index":snapshot.failed_tick_index,"tick_failure_count":snapshot.tick_failure_count,
		"last_tick_error":snapshot.last_tick_error,"paused":snapshot.paused,
		"workbench_refusal":str(snapshot.lab_context.get("workbench_refusal",""))}

func observe_native_health(stage: String, frame: int) -> Dictionary:
	if synthetic or host==null: return {}
	# Main may still hold a healthy snapshot on the frame when the worker first
	# publishes failure. Neither the consumed snapshot nor final tick alone is
	# an adequate health oracle. This API returns an immutable value and does
	# not remove/consume the worker publication or change native timing laws.
	var worker_failed: bool=host.simulation_worker.has_failed()
	var owner_state: Dictionary=host.simulation_worker.profile_owner_state()
	var published: Dictionary=snapshot_health(host.simulation_worker.take_latest_snapshot(-1))
	var consumed: Dictionary=snapshot_health(host.latest_snapshot)
	var previously_running:=worker_running_observed
	if bool(owner_state.thread_running) and not bool(owner_state.requested_paused):
		worker_running_observed=true
	var row: Dictionary={"stage":stage,"frame":frame,"observed_usec":Time.get_ticks_usec(),
		"expect_running":native_play_requested,"worker_has_failed":worker_failed,
		"worker_owner_state":owner_state,
		"worker_running_observed_before":previously_running,"worker_running_observed":worker_running_observed,
		"main_paused":host.paused,"main_error":host.microscenario_error,
		"workbench_refusal":str(host.tower_context.get("workbench_refusal","")),
		"workbench_message":str(bench.message) if bench!=null else "",
		"worker_snapshot":published,"main_snapshot":consumed,"reasons":[]}
	if worker_failed: row.reasons.append("worker_has_failed")
	for key: String in ["worker_snapshot","main_snapshot"]:
		var value: Dictionary=row[key]
		if not bool(value.get("available",false)):
			row.reasons.append(key+"_missing")
			continue
		if bool(value.simulation_failed) or int(value.tick_failure_count)>0 or not str(value.last_tick_error).is_empty():
			row.reasons.append(key+"_native_failure")
		if not str(value.workbench_refusal).is_empty(): row.reasons.append(key+"_workbench_refusal")
	if not str(row.workbench_refusal).is_empty(): row.reasons.append("main_workbench_refusal")
	if not str(row.main_error).is_empty(): row.reasons.append("main_apparatus_error")
	if native_play_requested and host.paused: row.reasons.append("unexpected_main_pause")
	# Snapshot.paused can be a normal actor-sample handoff. Only the separate
	# mutex-owned requested pause intent confirms a stopped owner. The initial
	# Play handshake may still carry the prior paused intent.
	if native_play_requested and previously_running and bool(owner_state.requested_paused):
		row.reasons.append("unexpected_worker_pause")
	if stage!="final_after_worker_join" and not bool(owner_state.thread_running):
		row.reasons.append("unexpected_worker_stop")
	row.healthy=row.reasons.is_empty()
	if not row.healthy:
		native_health.failure_observations=int(native_health.failure_observations)+1
		if native_health.first_failure.is_empty():
			native_health.first_failure=row.duplicate(true)
			require(false,"native owner failed or stopped; see native_health.first_failure")
	return row

func settled() -> bool:
	return not editor.busy() and not host.simulation_worker.paint_state().busy and not art.active \
		and art.manual.is_empty() and art.manual_inflight.is_empty()

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty() and settled()

func create_synthetic() -> void:
	host=Host.new()
	host.render_upload_strategy_override=str(config.strategy)
	host.world_extent=Vector2i(int(config.size),int(config.size))
	host.render_channels=int(config.channels)
	host.render_image_format=Image.FORMAT_RG8 if config.channels==2 else Image.FORMAT_R8
	host.image=Image.create_empty(config.size,config.size,false,host.render_image_format)
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
		"player_origin_px":Vector2(-1000,-1000),"condition_projection_enabled":1.0 if config.channels==2 else 0.0,
		"presentation_time_override":4.0,"snapshot_blend":1.0,
		"current_world_texture":host.texture,"previous_world_texture":host.previous_texture,
		"material_lut":CyberMaterialAppearanceLut.create_texture(),
		"material_program_lut":CyberMaterialAppearanceLut.create_program_texture()}
	for key: String in uniforms: host.world_shader.set_shader_parameter(key,uniforms[key])
	root.add_child(host.world_view)
	fixture_sha=digest(host.image.get_data())

func native_fixture() -> Dictionary:
	var side: int=config.size
	var policy: PackedInt32Array=PackedInt32Array(bench.applied.liquid_policy)
	var policy_found := false
	for choice: Dictionary in bench._liquids.bridge.liquid_policy_assignment_choices(policy,3):
		if str(choice.get("family",""))==str(config.family) and bool(choice.get("accepted",false)):
			var wanted := "cached_dormant" if config.family=="pressure_flow_v1" else "reference"
			if str(choice.get("variant","")) != wanted: continue
			policy=PackedInt32Array(choice.request)
			policy_found=true
			break
	require(policy_found,"native admitted requested Water family "+str(config.family))
	var setup: Dictionary=Setup.fresh(policy,Vector2i(side,side))
	if config.family=="inertial_cellular_v1": setup.rule_radius=3
	var edits: Array=setup.edits
	fixture_identity={"id":str(config.fixture),"geometry":"original workload-specific recipe",
		"source":"res://scripts/worker_benchmark.gd" if config.workload in ["active","actor"] else get_script().resource_path}
	if config.fixture=="pressure_dam_v1":
		# Geometry-only derivative of the registered Dam Break. Keep the native
		# Workbench policy/capacities and default material laws unchanged. The
		# original gate is already open, exactly as after its tick-zero erase.
		var source_text:=FileAccess.get_file_as_string(PRESSURE_DAM_SOURCE)
		var source: Dictionary=JSON.parse_string(source_text)
		var scale:=side/1024
		for index: int in range(0,35,5):
			edits.append([int(source.rectangles[index])*scale,int(source.rectangles[index+1])*scale,
				int(source.rectangles[index+2])*scale,int(source.rectangles[index+3])*scale,int(source.rectangles[index+4])])
		var water: Array=source.partial_water_fills
		require(int(water[4])==255 and int(water[5])==0,"registered dam uses full Water cells with zero coherence")
		edits.append([int(water[0])*scale,int(water[1])*scale,int(water[2])*scale,int(water[3])*scale,3])
		fixture_identity={"id":"pressure_dam_v1","source":PRESSURE_DAM_SOURCE,
			"source_sha256":FileAccess.get_sha256(PRESSURE_DAM_SOURCE),
			"canonical_source_sha256":source_text.replace("\r\n","\n").sha256_text(),
			"geometry":"registered 1024 dam scaled uniformly; gate already open; Workbench policy/laws unchanged",
			"scale":scale,"water_cells":int(water[2])*int(water[3])*scale*scale,"base_edits":edits.duplicate(true),
			"comparison_scope":"distinct fixture; never compare against legacy scattered PressureFlow performance"}
	else:
		edits.append_array([[0,0,side,2,58],[0,0,2,side,58],[side-2,0,2,side,58],[0,side-2,side,2,58]])
	if config.workload in ["active","actor"] and config.fixture!="pressure_dam_v1":
		var rectangles: PackedInt32Array=Stats.fixture(side)
		for index: int in range(20,rectangles.size(),5):
			edits.append([rectangles[index],rectangles[index+1],rectangles[index+2],rectangles[index+3],rectangles[index+4]])
	elif config.workload in ["dormant","burst"]:
		# Isolated active area in an otherwise mostly dormant finite World.
		edits.append_array([[80,80,28,24,2],[120,80,28,24,3],[72,180,100,3,58]])
	elif config.workload not in ["active","actor"]:
		for y: int in range(24,side-40,128):
			for x: int in range(24,side-40,128): edits.append([x,y,24,16,58])
	if config.workload=="actor":
		setup.actors=[Setup.instance("kestrel",1,Vector2(220,190)),Setup.instance(Setup.BARREL,2,Vector2(300,200))]
		setup.selected=1
		setup.next_id=3
		edits.append([100,300,300,4,58])
	fixture_sha=JSON.stringify(setup).sha256_text()
	return setup

func create_native() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(Host)
	host.simulation_worker=ProfileWorker.new()
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
		"transition":
			# Alternating dense/sparse bursts exercise both transfer directions
			# and the candidate's cooldown. Inputs are strategy-independent.
			rects.append(Rect2i(0,0,side,side) if frame%12<2 else Rect2i(96,96,8,8))
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
		var patch:=Image.create_empty(rect.size.x,rect.size.y,false,host.render_image_format)
		patch.fill(Color(float(3 if frame%2==0 else 58)/255.0,float((frame*37)%256)/255.0,0,1))
		metadata.append_array(PackedInt32Array([rect.position.x,rect.position.y,rect.size.x,rect.size.y,payload.size(),rect.size.x*int(config.channels)]))
		payload.append_array(patch.get_data())
	require(host.upload_texture_patches(metadata,payload,frame+1,int(config.channels)),"synthetic complete publication")
	# Full frame includes frame scheduling and shader drawing; upload stages
	# exclude fixture construction and include only the real Main handoff path.
	host.world_shader.set_shader_parameter("snapshot_blend",0.5 if frame%3==0 else 1.0)

func local(cell: Vector2i) -> Vector2:
	var area: Rect2=host.view_content_rect()
	return area.position+(Vector2(cell)+Vector2(0.5,0.5)-host.camera_origin.floor())*area.size/Vector2(host.current_view_size)

func native_action(frame: int) -> void:
	if config.workload=="actor":
		# Camera movement is separately labelled frame-paced rendering stress.
		# Actor input is selected by completed Rapier step in the Host callback.
		if frame%20==0:
			var origin:=Vector2(64+frame%100,64)
			bench._set_view(origin,Vector2i(320,180))
			camera_stress_samples.append({"frame":frame,"origin":[origin.x,origin.y]})
		return
	if config.workload not in ["manual","burst"]: return
	var target_actions:=mini(16,ceili(float(config.frames)/8.0)) if config.workload=="manual" else mini(8,maxi(1,int(config.frames)/8))
	if config.workload=="burst" and action_index>=target_actions:
		if settled() and host.paused:
			native_play_requested=require(bench.toggle_pause(),"burst resumes simulation") or native_play_requested
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

func frame_record(index: int, duration: int, before_uploads: int, health: Dictionary) -> Dictionary:
	return {"frame":index,"frame_ms":float(duration)/1000.0,
		"native_health":health,
		"coverage_fraction":coverage_fraction,"coverage_phase_frame":coverage_phase_frame,
		"upload_count":host.upload_samples.size()-before_uploads,
		"main_ms":float(host.main_usec)/1000.0,"shader_update_ms":float(host.shader_usec)/1000.0,
		"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"video_memory_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tick":host.latest_snapshot.tick_index if host.latest_snapshot!=null else -1,
		"rapier_step":host.physical_actor_session.tick if host.physical_actor_session!=null else 0,
		"accepted_render_serial":host.last_uploaded_render_snapshot_serial,
		"displayed_material_age_ms":float(Time.get_ticks_usec()-host.last_accepted_generated_usec)/1000.0 if host.last_accepted_generated_usec>0 else null}

func terminal_progress_observations() -> Dictionary:
	if synthetic or frames.is_empty(): return {}
	var elapsed_ms:=0.0
	var last_native_advance_ms:=0.0
	var last_physical_advance_ms:=0.0
	var last_native_advance_frame:=-1
	var last_physical_advance_frame:=-1
	var tick:=start_native_tick
	var step:=start_rapier_step
	for frame: Dictionary in frames:
		elapsed_ms+=float(frame.frame_ms)
		if int(frame.tick)>tick:
			last_native_advance_ms=elapsed_ms
			last_native_advance_frame=int(frame.frame)
		if int(frame.rapier_step)>step:
			last_physical_advance_ms=elapsed_ms
			last_physical_advance_frame=int(frame.frame)
		tick=int(frame.tick)
		step=int(frame.rapier_step)
	return {"last_observed_native_tick":tick,"last_observed_rapier_step":step,
		"last_native_advance_frame":last_native_advance_frame,"last_physical_advance_frame":last_physical_advance_frame,
		"trailing_native_unchanged_frames":frames.size()-1-last_native_advance_frame,
		"trailing_physical_unchanged_frames":frames.size()-1-last_physical_advance_frame,
		"terminal_native_unchanged_observed_ms":elapsed_ms-last_native_advance_ms,
		"terminal_physical_unchanged_observed_ms":elapsed_ms-last_physical_advance_ms,
		"last_displayed_material_age_ms":frames.back().displayed_material_age_ms,
		"scope":"Rendered-frame counter observations and retained terminal intervals; not hidden/suppressed frames, GPU scanout or a universal starvation threshold"}

func finish() -> void:
	if host!=null and not synthetic:
		# Joining is outside the measured window. Retain any in-flight tick's
		# failure before writing the receipt; no owner can fail after this check.
		host.set_process(false)
		host.simulation_worker.stop_worker()
		native_health.final=observe_native_health("final_after_worker_join",-1)
	var result: Dictionary={"schema":"render-upload-577-benchmark-v1","ok":failures.is_empty(),"failures":failures,
		"config":config,"strategy":config.strategy,"size":config.size,"workload":config.workload,"workers":config.workers,
		"context":Context.identity(get_script().resource_path,host.world_shader.shader if host!=null else null),
		"fixture_sha256":fixture_sha,"fixture_identity":fixture_identity,"initial_image_sha256":initialized_image_sha,
		"native_health":native_health,
		"terminal_progress_observations":terminal_progress_observations(),
		"cohort":"deterministic_renderer_seam" if synthetic else "mounted_native_workbench",
		"requested_workers":config.workers,
		"initial_native_tick":start_native_tick,"initial_rapier_step":start_rapier_step,
		"setup_ms":float(setup_usec)/1000.0,"elapsed_ms":float(Time.get_ticks_usec()-start_usec)/1000.0,
		"shader_preparation":host.render_shader_preparation.duplicate(true) if host!=null else {},
		"shader_preparation_at_measurement":shader_preparation_at_measurement,
		"preparation_scope":"Detached renderer seam uses the declared unchanged fixture warmup; no Main startup preparation." if synthetic else "Actual Main initialization; all preparation cost is included in setup and complete process time.",
		"frames":frames,"uploads":host.upload_samples if host!=null else [],
		"publications":host.publication_samples if host!=null else [],"actions":actions,
		"actor_input_tape":"completed-physical-step: 60 powered / 60 neutral; period 120" if config.workload=="actor" else "none",
		"actor_input_samples":host.pilot_samples if host!=null else [],
		"camera_stress_scope":"frame-paced camera motion only; does not select actor controls",
		"camera_stress_samples":camera_stress_samples,
		"ack_recovery_outside_timing":ack_recovery,
		"measurement_limits":["CPU elapsed intervals are not GPU transfer time or physical bandwidth.",
			"Frame intervals include benchmark scheduling and fixture/action generation.",
			"Native workloads are asynchronous: compare tick throughput and observed publications, not identical final states.",
			"Requested native worker count can be clamped to host capacity; actual immutable capacity is reported separately.",
			"Publication observed latency ends at a frame event after accepted texture submission; physical scanout is unmeasured.",
			"Static/video monitors are engine counters; process RSS is recorded separately by orchestrator."]}
	if host!=null:
		result.final_image_sha256=digest(host.image.get_data())
		result.final_strategy=host.render_upload_status
		# This readback is outside timing and uses the actual accepted texture.
		var current_image: Image=host.texture.get_image()
		if current_image!=null and current_image.get_format()!=host.render_image_format: current_image.convert(host.render_image_format)
		result.final_current_texture_matches_cpu=current_image!=null and current_image.get_data()==host.image.get_data()
		require(result.final_current_texture_matches_cpu,"final current GPU texture equals validated CPU material image")
		result.native_backend=host.latest_snapshot.backend_name if host.latest_snapshot!=null else "fixture-only"
		result.actual_native_worker_capacity=host.latest_snapshot.scheduler_thread_capacity_hint if host.latest_snapshot!=null and not synthetic else null
		result.world_extent=[host.world_extent.x,host.world_extent.y]
		result.rejected_publications=host.rejected_render_snapshot_count
		result.transport_full_publications=host.transport_full_publications
		result.transport_full_scope="Unique accepted material serial/generation full-coverage packets; not native capture calls"
		result.native_full_refreshes=null
		if not native_capture_result.is_empty():
			var capture_delta: Dictionary={}
			for key: String in start_native_capture_counters:
				capture_delta[key]=int(native_capture_result.counters[key])-int(start_native_capture_counters[key])
			result.native_capture={"scope":"Actual native adapter calls completed between benchmark counter snapshots; calls crossing a window boundary belong to their completion window",
				"before":start_native_capture_counters,"after":native_capture_result.counters,
				"delta":capture_delta,"samples":native_capture_result.samples,
				"dropped_samples":native_capture_result.dropped_samples}
			result.native_full_refreshes=capture_delta.full_packets
			result.ack_during_timing=native_capture_result.ack
		result.pending_policy=host.simulation_worker.render_pending_policy() if not synthetic and host.simulation_worker.has_method("render_pending_policy") else "unreported"
		if not frames.is_empty() and not synthetic:
			var measured_seconds:=0.0
			for frame: Dictionary in frames: measured_seconds+=float(frame.frame_ms)/1000.0
			result.measured_seconds=measured_seconds
			result.tick_progress=int(frames.back().tick)-start_native_tick
			result.observed_ticks_per_second=float(result.tick_progress)/maxf(measured_seconds,0.000001)
			result.rapier_steps_per_second=float(int(frames.back().rapier_step)-start_rapier_step)/maxf(measured_seconds,0.000001)
			result.accepted_updates_per_second=float(host.upload_samples.size())/maxf(measured_seconds,0.000001)
			var seen_ticks: Dictionary={}
			var observed_tick_times: Array[float]=[]
			for publication: Dictionary in host.publication_samples:
				var key:=str(publication.generation)+":"+str(publication.tick)
				if int(publication.tick)>0 and not seen_ticks.has(key):
					seen_ticks[key]=true
					observed_tick_times.append(float(publication.native_tick_ms))
			result.distinct_observed_native_tick_ms=Stats.statistics(observed_tick_times)
	result.ok=failures.is_empty()
	var path: String=config.output
	if not path.is_empty():
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(result,"\t")+"\n")
		else: require(false,"output file writable")
	print("RENDER_UPLOAD_RESULT ",JSON.stringify({"ok":failures.is_empty(),"config":config,"frames":frames.size(),"uploads":result.uploads.size(),"actions":actions.size(),"failures":failures}))
	if host!=null:
		if synthetic:
			host.world_view.queue_free()
			if host._render_upload_hybrid!=null: host._render_upload_hybrid.close()
			host.free()
		else: host.queue_free()
		await process_frame
		await process_frame
	quit(int(not failures.is_empty()))

func run() -> void:
	if not require(DisplayServer.get_name()!="headless","graphical display required") or not require(config.size in [512,1024,2048],"supported dimensions"):
		await finish()
		return
	if not require(str(config.workload) in SYNTHETIC or config.workload in ["manual","burst","active","dormant","actor"],"declared workload") or not require(config.strategy in ["full","hybrid"],"declared strategy"):
		await finish()
		return
	if not require(config.ack in ["normal","delayed150","withheld"] and (config.ack=="normal" or config.workload=="manual"),"ACK faults use the paused fixed-edit workload"):
		await finish()
		return
	if not require(config.fixture in ["workload_v1","pressure_dam_v1","legacy_scatter_v1"],"declared fixture") or \
		not require(config.fixture!="pressure_dam_v1" or (config.family=="pressure_flow_v1" and config.workload in ["active","actor"] and config.size in [1024,2048]),"pressure dam fixture family/size/workload") or \
		not require(config.fixture!="legacy_scatter_v1" or config.workload in ["active","actor"],"legacy scatter fixture workload"):
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
	shader_preparation_at_measurement=host.render_shader_preparation.duplicate(true)
	if not synthetic and config.strategy=="hybrid":
		require(bool(shader_preparation_at_measurement.get("prepared",false)),"mounted hybrid completed explicit startup shader preparation")
	else:
		require(shader_preparation_at_measurement.is_empty(),"baseline and detached fixtures perform no Main shader preparation")
	if not failures.is_empty():
		await finish()
		return
	if not synthetic and config.workload in ["active","dormant","actor"]:
		native_play_requested=require(bench.toggle_pause(),"native simulation starts after identical paused warmup")
	start_native_tick=host.latest_snapshot.tick_index if host.latest_snapshot!=null else 0
	start_rapier_step=host.physical_actor_session.tick if host.physical_actor_session!=null else 0
	if not synthetic: start_native_capture_counters=host.simulation_worker.profile_begin(str(config.ack))
	if not synthetic: native_health.before=observe_native_health("before",-1)
	if config.workload=="actor":
		host.pilot_start_step=start_rapier_step
		host.pilot_enabled=true
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
		var health: Dictionary=observe_native_health("frame",index)
		frames.append(frame_record(index,now-previous_frame_usec,before_uploads,health))
		previous_frame_usec=now
		if not synthetic: observe_action()
		if not failures.is_empty(): break
	if not synthetic and config.workload in ["manual","burst"]:
		require(pending_action.is_empty(),"all native edit acknowledgements completed inside measured frames")
	host.measuring=false
	require(host.render_shader_preparation==shader_preparation_at_measurement,"shader preparation did not change inside the measured window")
	if not synthetic:
		native_health.after_timing=observe_native_health("after_timing",-1)
		native_capture_result=host.simulation_worker.profile_end()
		require(native_capture_result.dropped_samples==0,"all native capture observations retained")
	if not failures.is_empty():
		await finish()
		return
	if config.workload=="actor":
		require(not host.pilot_samples.is_empty(),"physical input tape observed")
		require(not frames.is_empty() and int(frames.back().rapier_step)>start_rapier_step,"actor completed physical steps during timing")
		for sample: Dictionary in host.pilot_samples:
			require(bool(sample.accepted),"physical step input admitted")
	if not synthetic and not pending_action.is_empty():
		await until(func() -> bool:
			observe_action()
			return pending_action.is_empty(),"final native edit and render acknowledgement",90000)
	require(frames.size()==config.frames,"all frame samples collected")
	if synthetic:
		require(host.upload_samples.size()==config.frames,"one accepted synthetic publication per measured input")
	if not synthetic and config.workload in ["active","dormant","actor"]:
		require(frames.back().tick>frames.front().tick,"native simulation progressed")
	if not synthetic and config.workload in ["manual","burst"]:
		var expected_actions:=mini(16,ceili(float(config.frames)/8.0)) if config.workload=="manual" else mini(8,maxi(1,int(config.frames)/8))
		require(actions.size()==expected_actions,"all fixed-count native edits completed")
	if not synthetic and config.ack!="normal":
		ack_recovery=host.simulation_worker.profile_recover_acknowledgements()
		# These fault cohorts stay paused and perform a fixed edit tape. Recovery
		# is deliberately outside the timing window and cannot improve its tails.
		var recovered: bool=await until(func() -> bool:
			var acknowledged: Dictionary=host.simulation_worker.profile_ack_snapshot()
			return int(acknowledged.observed_serial)>=host.last_uploaded_render_snapshot_serial \
				and host.last_uploaded_revision==int(host.simulation_worker.paint_state().revision) \
				and settled(),"ACK recovery and latest authored material convergence")
		ack_recovery.converged=recovered
		ack_recovery.finished_usec=Time.get_ticks_usec()
		ack_recovery.final=host.simulation_worker.profile_ack_snapshot()
		ack_recovery.accepted_material_serial=host.last_uploaded_render_snapshot_serial
		ack_recovery.accepted_revision=host.last_uploaded_revision
		ack_recovery.authoritative_revision=int(host.simulation_worker.paint_state().revision)
	if config.strategy=="hybrid": require(host._render_upload_hybrid!=null,"experimental path remained active")
	if not synthetic:
		# Freeze only after the measured window to make final readback stable.
		host.set_process(false)
	await finish()
