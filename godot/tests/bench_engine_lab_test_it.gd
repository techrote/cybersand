extends SceneTree

# ENG-LAB Test It: owner reference 2048² generated map + tick-addressed
# actual Needle inputs, not human keypresses, never a mock physics solver.
const Reference = preload("res://scripts/engine_lab_reference_fixture.gd")
const Recorder = preload("res://scripts/engine_lab_passive_recorder.gd")
const WORLD := Vector2i(2048,2048)
const CAMERA_ORIGIN := Vector2(0,0)
const CAMERA_VIEW := Vector2i(960,540)
const CAPTURE_WINDOW_USEC: int = 20000000
const MAX_CAPTURE_WINDOWS: int = 6
const PHYSICS_END_TICK: int = 24
const PREP_TIMEOUT_MS: int = 240000
const FAMILY: Dictionary = {
	"freemass":{"family":"freemass_v1","variant":"reference"},
	"pressure":{"family":"pressure_flow_v1","variant":"cached_dormant"},
	"cellular":{"family":"cellular_yield_v1","variant":"reference"},
	"inertial":{"family":"inertial_cellular_v1","variant":"reference"}}
# Tick offsets are relative to the adopted physical actor's first unpaused
# step. The Main physics callback admits each action at precisely that tick;
# no per-frame human input, synthesised key press or timer heuristics.
const TAPE: Array[Dictionary] = [
	{"tick":0,"move":[0.0,0.0]},
	{"tick":2,"move":[1.0,0.0]},
	{"tick":4,"move":[0.0,-1.0]},
	{"tick":6,"move":[-1.0,0.0]},
	{"tick":8,"move":[0.0,1.0]},
	{"tick":10,"move":[0.0,0.0]},
	{"tick":12,"move":[0.70710678,-0.70710678]},
	{"tick":14,"move":[0.0,0.0]},
]

var family: String = ""
var workers: int = -1
var repeat_id: int = 0
var receipt_path: String = ""
var failures: Array[String] = []
var check_count: int = 0
var native_radius: int = 2
var source_reference: Dictionary = {}
var applied_policy: Dictionary = {}
var construction_receipt: Dictionary = {}
var sample_windows: Array[Dictionary] = []
var actor_ticks: Array[Dictionary] = []
var actor_first: Dictionary = {}
var actor_last: Dictionary = {}
var _host: Control
var _panel: Window


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--family="): family = arg.trim_prefix("--family=")
		if arg.begins_with("--workers="): workers = int(arg.trim_prefix("--workers="))
		if arg.begins_with("--repeat="): repeat_id = int(arg.trim_prefix("--repeat="))
		if arg.begins_with("--receipt="): receipt_path = arg.trim_prefix("--receipt=")
	if family not in FAMILY or workers not in [1,4] or repeat_id not in [1,2] 		or receipt_path.is_empty() or not OS.get_cmdline_user_args().has("--engine-lab-scripted") 		or DisplayServer.get_name() == "headless":
		push_error("ENGINE_LAB_TEST_IT: explicit real graphical scripted case required")
		quit(2)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	Engine.max_fps = 60
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	check_count += 1
	if not ok:
		failures.append(label)
		push_error("ENGINE_LAB_TEST_IT: " + label)
	return ok


func _available() -> bool:
	return is_instance_valid(_host) and _host.shared_workbench != null 		and not _host.shared_workbench.applied.is_empty() 		and _host.latest_snapshot != null and not _host.simulation_worker.has_failed()


func _applied_water() -> Dictionary:
	for assignment: Dictionary in _host.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(assignment.get("material",-1)) == 3: return assignment
	return {}


func _installed() -> bool:
	if not _available() or not _host.pending_microscenario_apply.is_empty():
		return false
	var session: CyberPhysicalActorSession = _host.physical_actor_session
	if session == null or not _host._physical_terrain_ready 		or not _host.rapier_bridge.is_initialized():
		return false
	if Setup_extent() != WORLD or not _host.shared_workbench._generated_active.has("cells"):
		return false
	var selected: Dictionary = _applied_water()
	var required: Dictionary = FAMILY[family]
	return str(selected.get("applied_family","")) == str(required.family) 		and str(selected.get("applied_variant","")) == str(required.variant)


func Setup_extent() -> Vector2i:
	var a: Array = _host.shared_workbench.applied.get("extent",[0,0])
	return Vector2i(int(a[0]),int(a[1]))


func _wait(predicate: Callable, millis: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + millis
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if _host != null and is_instance_valid(_host) and _host.simulation_worker.has_failed():
			return false
		await process_frame
	return false


func _policy() -> PackedInt32Array:
	var bridge: Variant = _host.shared_workbench._liquids.bridge
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var wanted: Dictionary = FAMILY[family]
	var found := PackedInt32Array()
	for c: Dictionary in bridge.liquid_policy_assignment_choices(request,3):
		if str(c.get("family","")) != str(wanted.family) or str(c.get("variant","")) != str(wanted.variant): continue
		if not c.get("accepted",false):
			check(false,"native solver policy selection refused: "+str(c.get("refusal",{})))
			return found
		found = c.request
		break
	if not check(not found.is_empty(),"native Water solver family/variant exists"):
		return found
	var validation: Dictionary = bridge.validate_liquid_policy(found)
	if not check(bool(validation.get("accepted",false)),"native policy admission accepted"):
		return PackedInt32Array()
	native_radius = int(validation.get("receipt",{}).get("minimum_rule_radius",2))
	if not check(native_radius in [2,3],"source-selected minimum geometry radius valid"):
		return PackedInt32Array()
	return found


func _tick_record() -> void:
	if _host == null or _host.physical_actor_session == null: return
	var session: CyberPhysicalActorSession = _host.physical_actor_session
	if not actor_ticks.is_empty() and int(actor_ticks.back().physical_tick) == session.tick:
		return
	if actor_ticks.size() >= 1024:
		check(false,"bounded physical actor tick sample cap exceeded")
		return
	var actor: Dictionary = session.workbench_actor_state(1)
	if actor.is_empty(): return
	var pos: Vector2 = actor.position
	var velocity: Vector2 = actor.linear_velocity
	var flight: Dictionary = session.observation(0).get("flight",{})
	var applied: Dictionary = flight.get("applied",{})
	var sample: Dictionary = {
		"physical_tick":session.tick,
		"native_tick":int(_host.latest_snapshot.tick_index),
		"world_generation":int(_host.latest_snapshot.render_world_generation),
		"render_accepted_serial":int(_host.last_uploaded_render_snapshot_serial),
		"wall_usec":Time.get_ticks_usec(),
		"position":[pos.x,pos.y],"velocity":[velocity.x,velocity.y],
		"angle":float(actor.rotation),"angular_velocity":float(actor.angular_velocity),
		"flight_applied_sequence":int(applied.get("sequence",-1)),
		"flight_applied_step_tick":int(applied.get("step_tick",-1)),
		"flight_fallback_reason":str(flight.get("fallback_reason","unavailable")),
		"accepted_commands":session.accepted_commands,
		"rejected_commands":session.rejected_commands}
	actor_ticks.append(sample)
	if actor_first.is_empty(): actor_first = sample.duplicate(true)
	actor_last = sample.duplicate(true)


func _combine() -> Dictionary:
	var all: Array[Dictionary] = []
	var elapsed: float = 0.0
	var ticks: int = 0
	var steps: int = 0
	var holds: Dictionary = {}
	var first_identity: Dictionary = {}
	for w: Dictionary in sample_windows:
		elapsed += float(w.get("elapsed_seconds",0.0))
		ticks += int(w.get("native_ticks",0))
		steps += int(w.get("rapier_steps",0))
		if first_identity.is_empty(): first_identity=w.get("identity",{}).duplicate(true)
		for key: String in ["workbench_sample","workbench_terrain","workbench_no_snapshot","lockstep"]:
			holds[key] = int(holds.get(key,0)) + int(w.get("coupling_held_physics_frames",{}).get(key,0))
		for row: Dictionary in w.get("raw_samples",[]): all.append(row)
	var intervals: Array[float] = []
	var native_cost: Array[float] = []
	var rapier_cost: Array[float] = []
	var render_age: Array[float] = []
	var uploads: Array[float] = []
	var prev: Dictionary = {}
	for row: Dictionary in all:
		if not prev.is_empty():
			var delta: int = int(row.at_usec)-int(prev.at_usec)
			if delta > 0 and delta <= 30000000:
				intervals.append(float(delta)/1000.0)
			if int(row.native_tick) > int(prev.native_tick):
				native_cost.append(float(row.get("native_sim_ms",0)))
			if int(row.rapier_steps) > int(prev.rapier_steps):
				rapier_cost.append(float(row.get("rapier_step_ms",0)))
		if int(row.get("render_age_usec",-1)) >= 0:
			render_age.append(float(row.render_age_usec)/1000.0)
		uploads.append(float(row.get("render_upload_ms",0.0)))
		prev = row
	var status: String = "passed" if sample_windows.size()>0 else "incomplete"
	for w: Dictionary in sample_windows:
		if w.get("status","") != "passed": status = "incomplete"
	return {"status":status,"identity":first_identity,
		"elapsed_seconds":elapsed,"native_ticks":ticks,"rapier_steps":steps,
		"actual_native_hz":float(ticks)/maxf(elapsed,0.000001),
		"actual_rapier_hz":float(steps)/maxf(elapsed,0.000001),
		"frame_count":all.size(),
		"frame_interval_ms":Recorder.distribution(intervals),
		"native_completed_tick_cost_ms":Recorder.distribution(native_cost),
		"rapier_completed_step_cost_ms":Recorder.distribution(rapier_cost),
		"render_payload_age_at_frame_ms":Recorder.distribution(render_age),
		"upload_submission_ms":Recorder.distribution(uploads),
		"coupling_held_physics_frames":holds,
		"render_accepted_serial_start":int(all.front().render_serial) if not all.is_empty() else -1,
		"render_accepted_serial_end":int(all.back().render_serial) if not all.is_empty() else -1,
		"raw_samples":all}


func _finish() -> void:
	if _host != null and is_instance_valid(_host):
		_host.engine_lab_end_tape()
	var replay: Dictionary = _host.engine_lab_tape_receipt() if _host != null and is_instance_valid(_host) else {}
	var merged: Dictionary = _combine()
	var tape_reached: bool = (replay.get("error","") == "" and replay.get("events",[]).size() == TAPE.size()
		and not actor_last.is_empty()
		and int(actor_last.physical_tick)-int(replay.get("tick_zero",0)) >= PHYSICS_END_TICK)
	if not tape_reached:
		check(false,"scripted actions or 24-physics-tick consequence horizon incomplete")
	if not check(merged.status == "passed" and merged.native_ticks > 0
		and merged.rapier_steps > 0,"wall/native/Rapier benchmark capture positive"):
		pass
	var output: Dictionary = {
		"schema":"engine-lab-test-it-scripted-v1",
		"status":"passed" if failures.is_empty() else "incomplete",
		"family":family,"workers":workers,"repeat":repeat_id,
		"reference":{"json_sha256":Reference.FILE_SHA256,
			"generated_material_sha256":Reference.OUTPUT_SHA256,
			"native_receipts":int(source_reference.get("generation_receipt_count",0)),
			"source_generation_seconds":float(source_reference.get("generation_seconds",0))},
		"input_tape":{"clock":"completed_Rapier_physics_ticks_since_first_unpaused_step",
			"script":TAPE,"contract_sha256":JSON.stringify(TAPE).sha256_text(),
			"observed":replay,"complete":tape_reached},
		"native_solver":{"requested":FAMILY[family],"applied":applied_policy,
			"minimum_rule_radius":native_radius,"construction_receipt":construction_receipt},
		"world_size":[WORLD.x,WORLD.y],
		"native_worker_request_readback":int(_host.latest_snapshot.native_worker_request) if _host != null and _host.latest_snapshot != null else -1,
		"active_actor_tick":int(actor_last.get("physical_tick",-1)),
		"viewport":[_host.current_view_size.x,_host.current_view_size.y] if _host!=null else [],
		"actual_window":[root.size.x,root.size.y],
		"camera_origin":[CAMERA_ORIGIN.x,CAMERA_ORIGIN.y],
		"actor":{"model":"needle","instance_id":1,"initial":actor_first,
			"last":actor_last,"physical_tick_samples":actor_ticks},
		"benchmark":merged,
		"capture_windows":sample_windows.size(),
		"assertions":check_count,
		"failures":failures.duplicate(),
		"disclaimer":"Tick-indexed command admission is deterministic; independent native/asynchronous World evolution and wall-clock rates are measured, not asserted bit-identical."}
	if not receipt_path.is_empty():
		var file:=FileAccess.open(receipt_path,FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(output,"\t")+"\n")
			file.close()
		else: push_error("ENGINE_LAB_TEST_IT: report not writable")
	print("ENGINE_LAB_TEST_IT: ",JSON.stringify({
		"status":output.status,"family":family,"workers":workers,
		"events":replay.get("events",[]).size(),
		"native_hz":merged.actual_native_hz,"rapier_hz":merged.actual_rapier_hz,
		"frame_p95_ms":merged.frame_interval_ms.get("p95",-1),
		"failures":failures}))
	if _host != null and is_instance_valid(_host): _host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_host=load("res://main.tscn").instantiate()
	root.add_child(_host)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1600,900)
	if not check(await _wait(Callable(self,"_available"),PREP_TIMEOUT_MS),
		"initial native Workbench owner ready"):
		await _finish()
		return
	# Regeneration is independent of the live native World and is checked
	# against the exact user's source document before any constructor request.
	var fixture: CyberEngineLabReferenceFixture = Reference.new()
	source_reference = await fixture.materialize(self)
	if not check(bool(source_reference.get("ok",false)),
		"owner gate canvas exactly regenerated: "+str(source_reference.get("error",""))):
		await _finish()
		return
	var policy: PackedInt32Array = _policy()
	if policy.is_empty():
		await _finish()
		return
	var setup: Dictionary = source_reference.setup.duplicate(true)
	setup.liquid_policy = Array(policy)
	setup.rule_radius = native_radius
	if not check(_host.shared_workbench.apply(setup,false,0,false,false,source_reference.packet),
		"generated source install accepted via actual native Workbench prepared transaction"):
		await _finish()
		return
	if not check(await _wait(Callable(self,"_installed"),PREP_TIMEOUT_MS),
		"installed original generated material + actor + native Water policy + Rapier terrain"):
		await _finish()
		return
	applied_policy = _host.tower_context.get("liquid_solver_policy",{}).duplicate(true)
	construction_receipt = _host.tower_context.get("liquid_construction_receipt",{}).duplicate(true)
	check(int(_host.latest_snapshot.native_worker_request) == workers,
		"native worker count applied to source owner")
	check(str(applied_policy.get("policy_hash","")).length() >= 16,
		"actual native family/variant policy hash exists")
	check(not construction_receipt.is_empty(),"native construction receipt present")
	var adopted: Dictionary = _host.shared_workbench.applied
	check(adopted.actors.size() == 1 and str(adopted.actors[0].model) == "needle"
		and int(adopted.actors[0].id) == 1,"exact owner reference Needle adopted")
	check(_host.shared_workbench._generated_active.get("sha256","") == Reference.OUTPUT_SHA256,
		"installed source provenance matches original full 2048² generator")
	if not failures.is_empty():
		await _finish()
		return
	_host.shared_workbench._set_view(CAMERA_ORIGIN,CAMERA_VIEW)
	_panel=_host.shared_workbench.engine_lab
	_panel.open_for(_host)
	if not check(_host.engine_lab_begin_tape(TAPE),
		"verified normal Workbench command path armed by explicit scripted opt-in"):
		await _finish()
		return
	if not check(_host.shared_workbench.toggle_pause(),"native World unpaused"):
		await _finish()
		return
	var at_start: int = Time.get_ticks_usec()
	var before_tick: int = _host.physical_actor_session.tick
	for window_idx: int in MAX_CAPTURE_WINDOWS:
		if _host.simulation_worker.has_failed(): break
		_panel.benchmark_duration_usec = CAPTURE_WINDOW_USEC
		_panel.begin_benchmark()
		if not check(_panel.recorder.running,"passive recorder arms for 20s window"):
			break
		var deadline: int = Time.get_ticks_msec() + 90000
		while not _panel.recorder.finished and Time.get_ticks_msec() < deadline 			and not _host.simulation_worker.has_failed():
			_tick_record()
			await process_frame
		_tick_record()
		if not _panel.recorder.finished:
			_panel.cancel_benchmark()
			check(false,"bounded passive window deadline or native failure")
			break
		sample_windows.append(_panel.recorder.outcome.duplicate(true))
		if _panel.recorder.outcome.get("status","") != "passed":
			check(false,"passive window incomplete: "+str(_panel.recorder.outcome.get("reason","")))
			break
		if _host.physical_actor_session.tick-before_tick >= PHYSICS_END_TICK:
			break
	if _host.physical_actor_session != null:
		_tick_record()
	if sample_windows.size() >= MAX_CAPTURE_WINDOWS 		and _host.physical_actor_session.tick-before_tick < PHYSICS_END_TICK:
		check(false,"120s bounded deterministic tape horizon exceeded under load")
	if not failures.is_empty() and _host != null:
		_host.engine_lab_end_tape()
	await _finish()
