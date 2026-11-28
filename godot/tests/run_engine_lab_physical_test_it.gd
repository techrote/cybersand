extends SceneTree

# One fresh real World and Needle per process. This is the same owner-provided
# 2048-square source and eight tick-addressed actions as ENG-LAB Test It;
# the active overlay trace is on PR609 and has no physics ownership.
# Cadence mode preserves those eight entries and explicitly appends three
# sustained commands; its longer tape has a separate receipt identity.
const Reference = preload("res://scripts/engine_lab_reference_fixture.gd")
const Tape: Array[Dictionary] = [
	{"tick":0,"move":[0.0,0.0]},
	{"tick":2,"move":[1.0,0.0]},
	{"tick":4,"move":[0.0,-1.0]},
	{"tick":6,"move":[-1.0,0.0]},
	{"tick":8,"move":[0.0,1.0]},
	{"tick":10,"move":[0.0,0.0]},
	{"tick":12,"move":[0.70710678,-0.70710678]},
	{"tick":14,"move":[0.0,0.0]}
]
const CadenceExtension: Array[Dictionary] = [
	{"tick":30,"move":[1.0,0.0]},
	{"tick":90,"move":[0.0,-1.0]},
	{"tick":120,"move":[1.0,0.0]}
]
const FAMILIES: Dictionary = {
	"freemass":{"family":"freemass_v1","variant":"reference"},
	"pressure":{"family":"pressure_flow_v1","variant":"cached_dormant"},
	"cellular":{"family":"cellular_yield_v1","variant":"reference"},
	"inertial":{"family":"inertial_cellular_v1","variant":"reference"}}
const WORLD := Vector2i(2048,2048)
const VIEW := Vector2i(240,135)
const MAX_SETUP_MSEC: int = 240000
const PHYSICS_TARGET: int = 24
const CAPTURE_MSEC: int = 10000
const CADENCE_MAX_CAPTURE_MSEC: int = 90000
const CADENCE_PHYSICS_TARGET: int = 144

var family: String = ""
var camera_mode: String = ""
var pose_mode: String = ""
var workers: int = 1
var repeat_id: int = 1
var pixel_hz: int = 60
var render_hz: int = 60
var fps_target: int = 60
var rapier_hz: int = 60
var ack_delay: int = 0
var ack_gated: bool = false
var wait_sample: bool = true
var sample_wake: bool = true
var smoothing: bool = true
var cadence_mode: String = "repaired"
var presentation_mode: String = "coherent"
var fire_mode: String = "unchanged"
var display_profile: String = "scripted"
var requested_view: Vector2i = VIEW
var startup_display: Dictionary = {}
var cpu_identity: Dictionary = {}
var fire_events: Array[Dictionary] = []
var cadence_tape: bool = false
var input_tape: Array[Dictionary] = []
var output: String = ""
var problems: Array[String] = []
var assertions: int = 0
var host: Control
var initial_sample: Dictionary = {}
var fixture: Dictionary = {}
var native_radius: int = 2
var started_usec: int = 0
var _waiting_epoch: int = -1
var capture_start_usec: int = 0
var capture_end_usec: int = 0
var capture_native_start: int = 0
var capture_rapier_start: int = 0
var capture_native_end: int = -1
var capture_rapier_end: int = -1
var final_sample: Dictionary = {}
var actual_view: Vector2i = Vector2i.ZERO
var captures: Array[Dictionary] = []
var _capture_images: Array[Image] = []


func _initialize() -> void:
	var invalid_boolean: bool=false
	for arg: String in OS.get_cmdline_user_args():
		for prefix: String in ["--ack-gated=","--wait-sample=","--sample-wake=","--smoothing=","--cadence-tape="]:
			if arg.begins_with(prefix) and arg.trim_prefix(prefix) not in ["0","1"]:
				invalid_boolean=true
		if arg.begins_with("--family="): family=arg.trim_prefix("--family=")
		if arg.begins_with("--camera="): camera_mode=arg.trim_prefix("--camera=")
		if arg.begins_with("--pose="): pose_mode=arg.trim_prefix("--pose=")
		if arg.begins_with("--workers="): workers=int(arg.trim_prefix("--workers="))
		if arg.begins_with("--repeat="): repeat_id=int(arg.trim_prefix("--repeat="))
		if arg.begins_with("--pixel-hz="): pixel_hz=int(arg.trim_prefix("--pixel-hz="))
		if arg.begins_with("--render-hz="): render_hz=int(arg.trim_prefix("--render-hz="))
		if arg.begins_with("--publication-hz="): render_hz=int(arg.trim_prefix("--publication-hz="))
		if arg.begins_with("--fps="): fps_target=int(arg.trim_prefix("--fps="))
		if arg.begins_with("--rapier-hz="): rapier_hz=int(arg.trim_prefix("--rapier-hz="))
		if arg.begins_with("--ack-delay="): ack_delay=int(arg.trim_prefix("--ack-delay="))
		if arg.begins_with("--ack-gated="): ack_gated=arg.trim_prefix("--ack-gated=")=="1"
		if arg.begins_with("--wait-sample="): wait_sample=arg.trim_prefix("--wait-sample=")=="1"
		if arg.begins_with("--sample-wake="): sample_wake=arg.trim_prefix("--sample-wake=")=="1"
		if arg.begins_with("--smoothing="): smoothing=arg.trim_prefix("--smoothing=")=="1"
		if arg.begins_with("--cadence="): cadence_mode=arg.trim_prefix("--cadence=")
		if arg.begins_with("--presentation="): presentation_mode=arg.trim_prefix("--presentation=")
		if arg.begins_with("--fire-mode="): fire_mode=arg.trim_prefix("--fire-mode=")
		if arg.begins_with("--display-profile="): display_profile=arg.trim_prefix("--display-profile=")
		if arg.begins_with("--cadence-tape="): cadence_tape=arg.trim_prefix("--cadence-tape=")=="1"
		if arg.begins_with("--receipt="): output=arg.trim_prefix("--receipt=")
	if invalid_boolean or not OS.get_cmdline_user_args().has("--engine-lab-scripted") or \
			family not in FAMILIES or camera_mode not in ["free","follow"] or \
			pose_mode not in ["guarded","mask"] or workers not in [0,1,4] or \
			repeat_id not in [1,2] or pixel_hz not in [2,30,60,120] or \
			render_hz not in [30,60,120] or fps_target not in [0,30,60,120] or \
			rapier_hz not in [60,120] or ack_delay not in [0,3] or \
			cadence_mode not in ["legacy","repaired"] or \
			presentation_mode not in ["legacy","coherent"] or \
			display_profile not in ["scripted","interactive-default"] or \
			fire_mode not in ["unchanged","off","on-off"] or output.is_empty():
		push_error("TEST_IT: explicit verified graphical Test It arguments required")
		quit(2)
		return
	cpu_identity={"model":OS.get_processor_name(),"logical_processors":OS.get_processor_count()}
	startup_display={"max_fps":Engine.max_fps,"rapier_callback_hz":Engine.physics_ticks_per_second,
		"project_vsync_mode":int(ProjectSettings.get_setting("display/window/vsync/vsync_mode",DisplayServer.VSYNC_ENABLED)),
		"project_window_size":[int(ProjectSettings.get_setting("display/window/size/window_width_override",0)),
			int(ProjectSettings.get_setting("display/window/size/window_height_override",0))],
		"project_native_worker_request":int(ProjectSettings.get_setting("cybersand/native_worker_threads",0))}
	# Each case has a fresh isolated user directory. Zero is the native Auto
	# request used by a fresh interactive launcher, not a request for zero tasks.
	# The owner's saved worker preference is never read or changed by this case.
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	input_tape=Tape.duplicate(true)
	if cadence_tape: input_tape.append_array(CadenceExtension.duplicate(true))
	if display_profile=="interactive-default":
		if not check(fps_target==Engine.max_fps,"interactive graphical cap is the process-start default"):
			quit(2)
			return
	else:
		Engine.max_fps=fps_target
	# The measured axes are explicit: FPS is graphical callbacks, publication
	# is immutable material delivery, Rapier remains fixed 1/60 per step.
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE",
		"legacy" if cadence_mode=="legacy" else "")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION",
		"legacy" if presentation_mode=="legacy" else "coherent")
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE",
		"mask" if pose_mode=="mask" else "")
	set_meta("cybersand_feature","shared_workbench")
	started_usec=Time.get_ticks_usec()
	_run.call_deferred()


func check(value: bool, reason: String) -> bool:
	assertions+=1
	if not value:
		problems.append(reason)
		push_error("TEST_IT: "+reason)
	return value


func _until(predicate: Callable, milliseconds: int) -> bool:
	var deadline: int = Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host!=null and is_instance_valid(host) and host.simulation_worker.has_failed():
			return false
		await process_frame
	return false


func _ready_initial() -> bool:
	return host!=null and is_instance_valid(host) and host.shared_workbench!=null and \
		not host.shared_workbench.applied.is_empty()


func _ready_native() -> bool:
	return host.pending_microscenario_apply.is_empty() and \
		host._physical_epoch>_waiting_epoch and host.physical_actor_session!=null and \
		host._physical_terrain_ready


func _ready_upload() -> bool:
	return host.latest_snapshot!=null and host.image!=null and \
		host.last_uploaded_revision==host.latest_snapshot.world_revision and \
		not host.workbench_display_frame().is_empty()


func _policy(ui: Control) -> PackedInt32Array:
	var api: Variant=ui._liquids.bridge
	var original: PackedInt32Array=api.default_liquid_policy()
	var requested: Dictionary=FAMILIES[family]
	for row: Dictionary in api.liquid_policy_assignment_choices(original,3):
		if str(row.get("family",""))!=requested.family or \
				str(row.get("variant",""))!=requested.variant:
			continue
		if not check(bool(row.get("accepted",false)),
				"native Water policy choice admitted"):
			return PackedInt32Array()
		var found: PackedInt32Array=row.request
		var validation: Dictionary=api.validate_liquid_policy(found)
		if not check(bool(validation.get("accepted",false)),
				"Water policy validation accepted"):
			return PackedInt32Array()
		native_radius=int(validation.get("receipt",{}).get("minimum_rule_radius",2))
		return found
	check(false,"requested Water solver family/variant absent")
	return PackedInt32Array()


func _actor_snapshot(ui: Control) -> Dictionary:
	if host.physical_actor_session==null: return {}
	var state: Dictionary=ui.body_state(1)
	var at: Vector2=state.get("position",Vector2.INF)
	var velocity: Vector2=state.get("linear_velocity",Vector2.INF)
	return {"step":host.physical_actor_session.tick,
		"position":[at.x,at.y] if at.is_finite() else null,
		"velocity":[velocity.x,velocity.y] if velocity.is_finite() else null,
		"angle":state.get("rotation",null),
		"last_error":str(host.physical_actor_session.last_error)}


func _native_worker_identity() -> Dictionary:
	var snapshot: CyberSimulationSnapshot=host.latest_snapshot \
		if host!=null and is_instance_valid(host) else null
	return {"requested":workers,"selection":"Auto" if workers==0 else "explicit",
		"observed_request":snapshot.native_worker_request if snapshot!=null else -1,
		"resolved_capacity":snapshot.scheduler_thread_capacity_hint if snapshot!=null else -1,
		"profile":"fresh isolated test profile; owner preference unchanged",
		"meaning":"Resolved native pool capacity, not measured task participation or CPU utilization"}


func _effective_pacing() -> Dictionary:
	if host==null or not is_instance_valid(host): return {}
	var native: Dictionary=host.simulation_worker.engine_lab_pixel_pacing()
	return {"pixel_hz":int(native.target_hz),"sample_wake":bool(native.sample_wake),
		"wait_native_sample":host.engine_lab_wait_native_sample,
		"rapier_callback_hz":Engine.physics_ticks_per_second,"graphical_fps_cap":Engine.max_fps,
		"publication_hz":host.render_snapshot_hz,"ack_delay_frames":host.engine_lab_ack_delay_frames,
		"ack_gated_publication":host.latest_snapshot.render_publication_ack_gated if host.latest_snapshot!=null else null,
		"smoothing":host.cadence_lod_enabled}


func _capture_frame(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	# Two bounded reference images, outside the measured interval. GPU readback
	# can stall, so neither image acquisition nor PNG encoding is timed as FPS.
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if not check(image!=null and not image.is_empty(),"graphical framebuffer "+label):
		return
	_capture_images.append(image)
	captures.append({"label":label,"wall_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames(),
		"rapier_step":host.physical_actor_session.tick,
		"native_tick":host.latest_snapshot.tick_index,
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"camera_origin":[host.camera_origin.x,host.camera_origin.y],
		"view_cells":[host.current_view_size.x,host.current_view_size.y],
		"width":image.get_width(),"height":image.get_height(),
		"measurement":"outside_timed_capture"})


func _finish(ui: Control) -> void:
	if physics_frame.is_connected(_fire_schedule): physics_frame.disconnect(_fire_schedule)
	var trace_receipt: Dictionary = {}
	var trace_dest: String = output.trim_suffix(".json")+"-poses.jsonl"
	if host!=null and is_instance_valid(host):
		capture_end_usec=Time.get_ticks_usec()
		capture_native_end=host.latest_snapshot.tick_index if host.latest_snapshot!=null else -1
		capture_rapier_end=host.physical_actor_session.tick if host.physical_actor_session!=null else -1
		final_sample=_actor_snapshot(ui) if ui!=null and is_instance_valid(ui) else {}
		host.engine_lab_end_tape()
		if host.workbench_pose_trace.active:
			trace_receipt=host.finish_workbench_pose_trace()
			if trace_receipt.get("status","")=="saved":
				var original: String=str(trace_receipt.get("path",""))
				var raw: PackedByteArray=FileAccess.get_file_as_bytes(original)
				if raw.is_empty():
					check(false,"pose JSONL file empty or missing")
				else:
					var file: FileAccess=FileAccess.open(trace_dest,FileAccess.WRITE)
					if file!=null:
						file.store_buffer(raw)
						file.close()
					else:
						check(false,"could not copy pose JSONL into test evidence")
			else:
				check(false,"pose trace could not save")
		if host.physical_actor_session!=null and host.latest_snapshot!=null:
			if not host.paused and ui!=null: ui.toggle_pause()
			await _capture_frame("after")
	for i: int in captures.size():
		var capture_path: String=output.trim_suffix(".json")+"-"+str(captures[i].label)+".png"
		if check(_capture_images[i].save_png(capture_path)==OK,"save framebuffer "+str(captures[i].label)):
			captures[i]["path"]=capture_path
			captures[i]["sha256"]=FileAccess.get_sha256(capture_path)
	_capture_images.clear()
	var tape: Dictionary=host.engine_lab_tape_receipt() \
		if host!=null and is_instance_valid(host) else {}
	var events: Array=tape.get("events",[])
	var tape_complete: bool=events.size()==input_tape.size()
	if tape_complete:
		for i: int in input_tape.size():
			if int(events[i].get("requested_physical_tick",-1))!=int(input_tape[i].tick) or \
					int(events[i].get("accepted_physical_tick",-1))!=int(input_tape[i].tick):
				tape_complete=false
	if not check(tape_complete,"all %d requested actions accepted at exactly intended physics ticks" % input_tape.size()):
		pass
	var end_tick: int=maxi(capture_rapier_end,0)
	check(end_tick>=(CADENCE_PHYSICS_TARGET if cadence_tape else PHYSICS_TARGET),
		"required completed Rapier steps after exact input tape")
	var native_ticks: int=capture_native_end
	check(native_ticks>0,"positive native World tick progression")
	var trace_filesize: int=FileAccess.get_file_as_bytes(trace_dest).size() \
		if FileAccess.file_exists(trace_dest) else 0
	check(trace_filesize>0,"pose JSONL copied to exact test evidence directory")
	var source_revision: String=OS.get_environment("CYBERSAND_SOURCE_REVISION")
	var actual_generation: Dictionary=host.shared_workbench._generated_active \
		if host!=null and is_instance_valid(host) and host.shared_workbench!=null else {}
	var data: Dictionary={
		"schema":"engine-lab-scripted-pose-test-it-v1",
		"status":"passed" if problems.is_empty() else "incomplete",
		"complete":problems.is_empty(),
		"source_sha":source_revision,
		"family":family,"workers":workers,"repeat":repeat_id,
		"cpu":cpu_identity,"native_workers":_native_worker_identity(),
		"effective_pacing":_effective_pacing(),
		"camera":camera_mode,"pose_mode":pose_mode,
		"requested_pixel_hz":pixel_hz,"requested_render_hz":render_hz,
		"requested_publication_hz":render_hz,"requested_graphical_fps":fps_target,
		"requested_rapier_callback_hz":rapier_hz,"ack_delay_frames":ack_delay,
		"ack_gated_publication":ack_gated,"wait_native_sample":wait_sample,
		"wake_on_rapier_sample":sample_wake,"smoothing":smoothing,
		"cadence_mode":cadence_mode,"presentation_mode":presentation_mode,
		"fire_schedule":{"mode":fire_mode,"clock":"completed_Rapier_steps","events":fire_events},
		"fixed_physics_step_seconds":1.0/60.0,
		"physics_rate_semantics":"fixed_1_over_60_per_completed_step; 120_callback_target_is_not_normalized_120Hz_physics",
		"capture_start_usec":capture_start_usec,"capture_end_usec":capture_end_usec,
		"capture_wall_seconds":float(capture_end_usec-capture_start_usec)/1000000.0,
		"capture_native_tick_start":capture_native_start,"capture_rapier_step_start":capture_rapier_start,
		"completed_simulation_seconds":float(end_tick-capture_rapier_start)/60.0,
		"world_size":[WORLD.x,WORLD.y],"requested_view_size":[requested_view.x,requested_view.y],
		"view_size":[actual_view.x,actual_view.y],"framebuffer_captures":captures,
		"reference":{"json_sha256":Reference.FILE_SHA256,
			"generated_material_sha256":str(fixture.get("material_sha256","")),
			"native_receipts":int(fixture.get("generation_receipt_count",0)),
			"generation_seconds":float(fixture.get("generation_seconds",0)),
			"installed_generated_sha256":str(actual_generation.get("sha256",""))},
		"input_tape":{"script":input_tape,"original_eight":Tape,"observed":events,
			"identity":"original8_plus_cadence_30_90_120" if cadence_tape else "original8",
			"clock":"completed_Rapier_physics_ticks_since_first_unpaused_step",
			"complete":tape_complete,"error":tape.get("error","")},
		"native_ticks":native_ticks,"rapier_steps":end_tick,
		"uploaded_render_serial":host.last_uploaded_render_snapshot_serial \
			if host!=null and is_instance_valid(host) else -1,
		"trace_file":trace_dest,
		"trace":trace_receipt,
		"actor_initial":initial_sample,
		"actor_last":final_sample,
		"godot":Engine.get_version_info().get("string",""),
		"video_adapter":RenderingServer.get_video_adapter_name(),
		"render_driver":RenderingServer.get_current_rendering_driver_name(),
		"material_publication":host.material_publication_status(),
		"physics_publication":host.simulation_worker.physics_publication_mode(),
		"display":{"profile":display_profile,"startup":startup_display,"server":DisplayServer.get_name(),
			"vsync_policy":"process-start default" if display_profile=="interactive-default" else "disabled for pacing experiment",
			"dpi":DisplayServer.screen_get_dpi(),"scale":DisplayServer.screen_get_scale(),
			"refresh_hz":DisplayServer.screen_get_refresh_rate(),
			"screen_size":[DisplayServer.screen_get_size().x,DisplayServer.screen_get_size().y],
			"window_size":[root.size.x,root.size.y],"window_content_scale":root.content_scale_factor,
			"vsync_mode":DisplayServer.window_get_vsync_mode() if DisplayServer.get_name()!="headless" else -1},
		"elapsed_seconds":float(Time.get_ticks_usec()-started_usec)/1000000.0,
		"assertions":assertions,"failures":problems.duplicate()}
	var writer: FileAccess=FileAccess.open(output,FileAccess.WRITE)
	if writer==null:
		push_error("TEST_IT: cannot write receipt "+output)
	else:
		writer.store_string(JSON.stringify(data,"  ")+"\n")
		writer.close()
	print("ENGINE_LAB_TEST_IT_RESULT ",JSON.stringify({
		"status":data.status,"events":events.size(),"native_ticks":native_ticks,
		"rapier_steps":end_tick,"trace_frames":trace_receipt.get("frames",0),
		"failures":problems}))
	if host!=null and is_instance_valid(host):
		host.queue_free()
	await process_frame
	await process_frame
	quit(int(not problems.is_empty()))


func _set_fire(enabled: bool, requested_step: int) -> void:
	var ui: Control = host.shared_workbench
	# Use the same CheckButton signal as an owner click. Do not edit native
	# cells or substitute a second input/physics owner.
	ui._fire.button_pressed = enabled
	check(ui.fire_enabled == enabled,"production Thruster fire toggle applied")
	fire_events.append({"enabled":enabled,"requested_step":requested_step,
		"observed_step":host.physical_actor_session.tick-capture_rapier_start,
		"time_usec":Time.get_ticks_usec()})


func _fire_schedule() -> void:
	# SceneTree.physics_frame fires before Main's physics callback; this sees
	# every completed-step index even when graphical FPS is lower than Rapier.
	if fire_mode != "on-off" or fire_events.size() != 1 or host.paused: return
	var step: int = host.physical_actor_session.tick-capture_rapier_start
	if step >= 60:
		check(step == 60,"Fire OFF occurs before completed-step 60 advances")
		_set_fire(false,60)


func _run() -> void:
	# SceneTree._initialize can still see a temporary 100x100 root. Observe the
	# actual started window before applying case-only display changes. The
	# requested project VSync and effective driver mode remain separate facts.
	await process_frame
	startup_display["window_size"]=[root.size.x,root.size.y]
	startup_display["vsync_mode"]=DisplayServer.window_get_vsync_mode() if DisplayServer.get_name()!="headless" else -1
	startup_display["capture_stage"]="first process frame, before case display overrides and Main construction"
	if display_profile=="scripted" and DisplayServer.get_name()!="headless":
		RenderingServer.call_on_render_thread(Callable(DisplayServer,"window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
	if display_profile=="scripted":
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1600,900)
	if not check(await _until(Callable(self,"_ready_initial"),MAX_SETUP_MSEC),
			"initial source-bound Workbench ready"):
		await _finish(null)
		return
	var ui: Control=host.shared_workbench
	var gen: CyberEngineLabReferenceFixture=Reference.new()
	fixture=await gen.materialize(self)
	if not check(bool(fixture.get("ok",false)),
			"exact 2048-square reference regenerated: "+
			str(fixture.get("error",""))):
		await _finish(ui)
		return
	var policy: PackedInt32Array=_policy(ui)
	if policy.is_empty():
		await _finish(ui)
		return
	var setup: Dictionary=fixture.setup.duplicate(true)
	setup.liquid_policy=Array(policy)
	setup.rule_radius=native_radius
	_waiting_epoch=host._physical_epoch
	if not check(ui.apply(setup,false,0,false,false,fixture.packet),
			"generated World and Needle submitted through real native preparer"):
		await _finish(ui)
		return
	if not check(await _until(Callable(self,"_ready_native"),MAX_SETUP_MSEC),
			"native material + real Needle + terrain adopted"):
		await _finish(ui)
		return
	if not check(await _until(Callable(self,"_ready_upload"),MAX_SETUP_MSEC),
			"uploaded current material and mask-bound actor receipt ready"):
		await _finish(ui)
		return
	check(ui.applied.get("extent",[]) == [2048,2048],
		"installed authored native World is 2048-square")
	check(ui.applied.actors.size()==1 and str(ui.applied.actors[0].model)=="needle" \
		and int(ui.applied.actors[0].id)==1,
		"actual reference Needle is selected")
	check(ui._generated_active.get("sha256","")==Reference.OUTPUT_SHA256,
		"actual installed generated cells preserve owner reference")
	var want_follow: bool=camera_mode=="follow"
	ui._camera.select(1 if want_follow else 0)
	ui.set_camera(1 if want_follow else 0)
	requested_view=host.current_view_size if display_profile=="interactive-default" else VIEW
	# set_camera restores the UI zoom. Apply our identical view afterwards, and
	# centre Free on the real actor rather than leaving it outside the viewport.
	var actor_state: Dictionary=ui.body_state(1)
	var actor_position: Vector2=actor_state.get("position",Vector2(200,200))
	ui._set_view(actor_position-Vector2(requested_view)*0.5,requested_view)
	await process_frame
	await process_frame
	actual_view=host.current_view_size
	check(actual_view==requested_view,"requested matched view survives production camera/layout")
	if display_profile=="interactive-default":
		check(actual_view==Vector2i(480,270),"interactive Workbench starts at its normal zoom")
		check(Engine.physics_ticks_per_second==rapier_hz and host.engine_lab_wait_native_sample==wait_sample,
			"coupled physics requests equal the untouched production defaults")
		var default_native: Dictionary=host.simulation_worker.engine_lab_pixel_pacing()
		check(int(default_native.target_hz)==pixel_hz and bool(default_native.sample_wake)==sample_wake,
			"native pacing requests equal the untouched production defaults")
	var worker_identity: Dictionary=_native_worker_identity()
	check(int(worker_identity.observed_request)==workers and int(worker_identity.resolved_capacity)>0,
		"requested native workers and resolved pool capacity recorded from real snapshot")
	host.engine_lab_wait_native_sample=wait_sample
	host.simulation_worker.set_engine_lab_pixel_pacing(pixel_hz,sample_wake)
	host.engine_lab_set_render_hz(render_hz)
	host.engine_lab_set_rapier_hz(rapier_hz)
	host.engine_lab_set_ack_delay(ack_delay)
	host.simulation_worker.set_engine_lab_ack_gated_publication(ack_gated)
	host.cadence_lod_enabled=smoothing
	await _capture_frame("before")
	initial_sample=_actor_snapshot(ui)
	if not check(host.engine_lab_begin_tape(input_tape),
			"exact tick tape armed inside real Workbench command owner"):
		await _finish(ui)
		return
	if not check(host.begin_workbench_pose_trace({
			"test_it":true,"family":family,"workers":workers,"camera":camera_mode,
			"cpu":cpu_identity,"native_workers":worker_identity,"display_profile":display_profile,
			"pose":pose_mode,"pixel_hz":pixel_hz,"render_hz":render_hz,
			"publication_hz":render_hz,"fps_target":fps_target,"rapier_callback_hz":rapier_hz,
			"fixed_physics_step_seconds":1.0/60.0,"ack_delay_frames":ack_delay,
			"ack_gated_publication":ack_gated,"wait_native_sample":wait_sample,
			"wake_on_rapier_sample":sample_wake,"smoothing":smoothing,"cadence_mode":cadence_mode,
			"presentation_mode":presentation_mode,"fire_mode":fire_mode,
			"input_tape_identity":"original8_plus_cadence_30_90_120" if cadence_tape else "original8"}),
			"bounded actual overlay pose trace armed"):
		await _finish(ui)
		return
	capture_start_usec=Time.get_ticks_usec()
	capture_native_start=host.latest_snapshot.tick_index
	capture_rapier_start=host.physical_actor_session.tick
	if fire_mode != "unchanged":
		_set_fire(fire_mode == "on-off",0)
		if fire_mode == "on-off": physics_frame.connect(_fire_schedule)
	if not check(ui.toggle_pause(),"unpause real Native World and Rapier"):
		await _finish(ui)
		return
	var start: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<(CADENCE_MAX_CAPTURE_MSEC if cadence_tape else CAPTURE_MSEC):
		if Time.get_ticks_msec()-start>=CAPTURE_MSEC and \
				(not cadence_tape or host.physical_actor_session.tick-capture_rapier_start>=CADENCE_PHYSICS_TARGET):
			break
		if host.simulation_worker.has_failed():
			check(false,"native simulation failed during scripted input")
			break
		if not host.engine_lab_replay_error.is_empty():
			check(false,"tick script refused: "+host.engine_lab_replay_error)
			break
		await process_frame
	if physics_frame.is_connected(_fire_schedule): physics_frame.disconnect(_fire_schedule)
	if fire_mode == "on-off": check(fire_events.size() == 2,"Fire ON then OFF schedule completed")
	await _finish(ui)
