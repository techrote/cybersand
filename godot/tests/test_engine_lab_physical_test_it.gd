extends SceneTree

# One fresh real World and Needle per process. This is the same owner-provided
# 2048-square source and eight tick-addressed actions as ENG-LAB Test It;
# the active overlay trace is on PR609 and has no physics ownership.
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

var family: String = ""
var camera_mode: String = ""
var pose_mode: String = ""
var workers: int = 1
var repeat_id: int = 1
var pixel_hz: int = 60
var render_hz: int = 60
var output: String = ""
var problems: Array[String] = []
var assertions: int = 0
var host: Control
var initial_sample: Dictionary = {}
var fixture: Dictionary = {}
var native_radius: int = 2
var started_usec: int = 0
var _waiting_epoch: int = -1


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--family="): family=arg.trim_prefix("--family=")
		if arg.begins_with("--camera="): camera_mode=arg.trim_prefix("--camera=")
		if arg.begins_with("--pose="): pose_mode=arg.trim_prefix("--pose=")
		if arg.begins_with("--workers="): workers=int(arg.trim_prefix("--workers="))
		if arg.begins_with("--repeat="): repeat_id=int(arg.trim_prefix("--repeat="))
		if arg.begins_with("--pixel-hz="): pixel_hz=int(arg.trim_prefix("--pixel-hz="))
		if arg.begins_with("--render-hz="): render_hz=int(arg.trim_prefix("--render-hz="))
		if arg.begins_with("--receipt="): output=arg.trim_prefix("--receipt=")
	if not OS.get_cmdline_user_args().has("--engine-lab-scripted") or \
			family not in FAMILIES or camera_mode not in ["free","follow"] or \
			pose_mode not in ["guarded","mask"] or workers not in [1,4] or \
			repeat_id not in [1,2] or pixel_hz not in [30,60,120] or \
			render_hz not in [30,60,120] or output.is_empty():
		push_error("TEST_IT: explicit verified graphical Test It arguments required")
		quit(2)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	Engine.max_fps=60
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


func _finish(ui: Control) -> void:
	var trace_receipt: Dictionary = {}
	var trace_dest: String = output.trim_suffix(".json")+"-poses.jsonl"
	if host!=null and is_instance_valid(host):
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
	var tape: Dictionary=host.engine_lab_tape_receipt() \
		if host!=null and is_instance_valid(host) else {}
	var events: Array=tape.get("events",[])
	var tape_complete: bool=events.size()==Tape.size()
	if tape_complete:
		for i: int in Tape.size():
			if int(events[i].get("requested_physical_tick",-1))!=int(Tape[i].tick) or \
					int(events[i].get("accepted_physical_tick",-1))!=int(Tape[i].tick):
				tape_complete=false
	if not check(tape_complete,"all 8 requested actions accepted at exactly intended physics ticks"):
		pass
	var end_tick: int=host.physical_actor_session.tick if host!=null and \
		is_instance_valid(host) and host.physical_actor_session!=null else 0
	check(end_tick>=PHYSICS_TARGET,"at least 24 completed Rapier steps")
	var native_ticks: int=host.latest_snapshot.tick_index if host!=null and \
		is_instance_valid(host) and host.latest_snapshot!=null else -1
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
		"camera":camera_mode,"pose_mode":pose_mode,
		"requested_pixel_hz":pixel_hz,"requested_render_hz":render_hz,
		"fixed_physics_step_seconds":1.0/60.0,
		"world_size":[WORLD.x,WORLD.y],"view_size":[VIEW.x,VIEW.y],
		"reference":{"json_sha256":Reference.FILE_SHA256,
			"generated_material_sha256":str(fixture.get("material_sha256","")),
			"native_receipts":int(fixture.get("generation_receipt_count",0)),
			"generation_seconds":float(fixture.get("generation_seconds",0)),
			"installed_generated_sha256":str(actual_generation.get("sha256",""))},
		"input_tape":{"script":Tape,"observed":events,
			"clock":"completed_Rapier_physics_ticks_since_first_unpaused_step",
			"complete":tape_complete,"error":tape.get("error","")},
		"native_ticks":native_ticks,"rapier_steps":end_tick,
		"uploaded_render_serial":host.last_uploaded_render_snapshot_serial \
			if host!=null and is_instance_valid(host) else -1,
		"trace_file":trace_dest,
		"trace":trace_receipt,
		"actor_initial":initial_sample,
		"actor_last":_actor_snapshot(ui) if ui!=null and is_instance_valid(ui) else {},
		"godot":Engine.get_version_info().get("string",""),
		"video_adapter":RenderingServer.get_video_adapter_name(),
		"render_driver":RenderingServer.get_current_rendering_driver_name(),
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


func _run() -> void:
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
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
	ui._set_view(Vector2.ZERO,VIEW)
	var want_follow: bool=camera_mode=="follow"
	ui._camera.select(1 if want_follow else 0)
	ui.set_camera(1 if want_follow else 0)
	host.simulation_worker.set_engine_lab_pixel_pacing(pixel_hz,true)
	host.engine_lab_set_render_hz(render_hz)
	initial_sample=_actor_snapshot(ui)
	if not check(host.engine_lab_begin_tape(Tape),
			"exact eight-action tick tape armed inside real Workbench command owner"):
		await _finish(ui)
		return
	if not check(host.begin_workbench_pose_trace({
			"test_it":true,"family":family,"workers":workers,"camera":camera_mode,
			"pose":pose_mode,"pixel_hz":pixel_hz,"render_hz":render_hz}),
			"bounded actual overlay pose trace armed"):
		await _finish(ui)
		return
	if not check(ui.toggle_pause(),"unpause real Native World and Rapier"):
		await _finish(ui)
		return
	var start: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<CAPTURE_MSEC:
		if host.simulation_worker.has_failed(): 
			check(false,"native simulation failed during scripted input")
			break
		if not host.engine_lab_replay_error.is_empty():
			check(false,"tick script refused: "+host.engine_lab_replay_error)
			break
		await process_frame
	await _finish(ui)
