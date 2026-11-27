extends SceneTree

# Independent examination of the worker/host lease. Native state is real;
# production owner requests and a real worker thread exercise every transition.
const Worker = preload("res://scripts/simulation_worker.gd")
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
var failures: Array[String] = []
var assertions: int = 0
var worker: CyberSimulationWorker
var fixture: Dictionary

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	assertions += 1
	if not ok:
		failures.append(detail)
		push_error("GEN006 owner adversarial: "+detail)

func wait_for(predicate: Callable) -> bool:
	var until: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<until:
		await process_frame
		if predicate.call(): return true
	return false

func latest() -> CyberSimulationSnapshot:
	return worker.take_latest_snapshot(0)

func command(source: Dictionary, serial: int, options: Dictionary) -> Dictionary:
	return {"scenario_reset":source,"scenario_request_serial":serial,"scenario_mode":"Inspect",
		"sampled_character_enabled":false,"runtime_enclosure_recovery_enabled":false,
		"exploratory_actor_definitions":[],"liquid_policy":fixture.bridge.default_liquid_policy(),
		"controlled_liquid_setup":options}

func installed(serial: int) -> bool:
	var s: CyberSimulationSnapshot = latest()
	return s != null and int(s.lab_context.get("scenario_request_serial",-1))==serial and \
		bool(s.lab_context.get("scenario_request_applied",false))

func request(kind: String, operation: String, extra: Dictionary = {}) -> Dictionary:
	var value: Dictionary = extra.duplicate(true)
	value["kind"]=kind; value["operation_id"]=operation
	var admitted: Dictionary = worker.persistent_request(value)
	if not admitted.get("ok",false): return {"ok":false,"error":admitted.get("error","")}
	var token: int = int(admitted.token)
	var completed: bool = await wait_for(func() -> bool:
		return worker.persistent_poll(token).get("status","") != "pending")
	if not completed: return {"ok":false,"error":"owner timeout"}
	return worker.persistent_poll(token)

func start(source: Dictionary) -> bool:
	worker=Worker.new(false)
	worker.set_physical_actor_epoch(21)
	worker.set_frame_state(0,false,true,Vector2i(256,256),Vector2i.ZERO,Vector2i(512,512),0,0,true,false,true)
	if worker.start_worker(Vector2(24,222)) != OK: return false
	var previous_body := PackedFloat32Array([1,100,100,0,3,3,0,0,0,1,1])
	worker.set_rigid_body_states(previous_body,21)
	worker._mutex.lock()
	var prior_packet := worker._rigid_body_states.duplicate()
	worker._mutex.unlock()
	check(prior_packet == previous_body,"the original Main body packet reaches the worker before replacement")
	worker.queue_lab(command(source,1,fixture.options))
	if not await wait_for(func() -> bool: return installed(1)): return false
	worker._mutex.lock()
	var retired := worker._rigid_body_states.is_empty()
	worker._mutex.unlock()
	check(retired,"the acknowledged actor-free Workbench retires the original Main body packet")
	return true

func freeze_and_cancel() -> void:
	check(await start(fixture.checked.definition),"real actor-free Workbench owner installs")
	if not installed(1):
		var s: CyberSimulationSnapshot=latest()
		print("GEN006_OWNER_INSTALL_DIAGNOSTIC ",{} if s==null else s.lab_context)
		worker.stop_worker(); return
	var captured: Dictionary = await request("capture","owner-1")
	check(captured.get("ok",false),"real owner capture: "+str(captured.get("error","")))
	if not captured.get("ok",false): worker.stop_worker(); return
	var saved: Dictionary = captured.result.capsule
	var fence: Dictionary = captured.result.owner_fence
	check(not worker.queue_emit_disc(90,90,2,1),"legacy paint refused while captured")
	check(not worker.queue_water_spray({"enabled":true}),"spray request refused while captured")
	check(not worker.queue_player_environment_profile({}),"environment request refused while captured")
	var body_packet := PackedFloat32Array([1,100,100,0,3,3,0,0,0,1,1])
	var physical_frame := {"version":1,"run_id":"stale-physical-frame","epoch":21,
		"tick":0,"suspended":false,"actors":[],"devices":[]}
	var usable: Dictionary = worker.set_physical_usable_state(physical_frame,[],body_packet)
	check(not usable.get("frame_admitted",false) and worker._rigid_body_states.is_empty(),
		"physical-usable publication cannot bypass captured owner body fence")
	check(not worker.persistent_request({"kind":"capture","operation_id":"owner-1"}).ok,
		"second capture cannot replace captured operation")
	check(not worker.persistent_request({"kind":"release","operation_id":"old-operation"}).ok,
		"stale operation cannot release another lease")
	worker.set_frame_state(0,false,false,Vector2i(64,64),Vector2i(32,32),Vector2i(64,64),0,0,false,true,false)
	worker.queue_reset(Vector2(30,30),false,false)
	worker.queue_lab({"step":true})
	for i: int in 8: await process_frame
	var state: Dictionary = await request("status","owner-1")
	check(state.get("ok",false) and state.result.owner_fence==fence,
		"captured native tick/hash/generation unchanged under refused commands")
	var options: Dictionary = Fixture.restore_options(fixture,saved,"owner-1")
	options["persistent_operation_id"]="owner-1"; options["persistent_stage"]=true
	var staging: Dictionary = command(fixture.checked.definition,2,options)
	worker.queue_lab(staging)
	var prepared := false
	for i: int in 100:
		state=await request("status","owner-1")
		if state.get("ok",false) and state.result.get("prepared",false):
			prepared=true; break
		await process_frame
	check(prepared,"private candidate staged through normal host: "+str(state))
	if not prepared:
		worker.stop_worker(); return
	# A rapid repeat must not retire the native token behind the existing
	# copied prepared publication. It is not an authorized replacement operation.
	worker.queue_lab(staging)
	for i: int in 5: await process_frame
	var advanced: Dictionary = await request("advance","owner-1",{"max_ticks":4,"max_us":100000})
	check(advanced.get("ok",false) and int(advanced.get("result",{}).get("completed_ticks",0))>0,
		"duplicate stage leaves original private candidate usable")
	var candidate: Dictionary = await request("capture_prepared","owner-1")
	check(candidate.get("ok",false) and int(candidate.result.capsule.completed_tick)>int(saved.completed_tick),
		"private native ticks are present in complete candidate capture")
	state=await request("status","owner-1")
	check(state.get("ok",false) and state.result.owner_fence==fence,
		"private native progression never mutates captured retained World")
	check((await request("discard","owner-1")).get("ok",false),"safe private cancellation")
	check((await request("release","owner-1")).get("ok",false),"release after cancellation")
	var again: Dictionary = await request("capture","owner-2")
	check(again.get("ok",false) and again.result.capsule.bytes==saved.bytes,
		"cancelled catch-up adds no ticks or edits to source World")
	if again.get("ok",false): await request("release","owner-2")
	var pending: Dictionary = worker.persistent_request({"kind":"capture","operation_id":"stop-owner"})
	check(pending.get("ok",false),"admit stop-race native capture")
	worker.stop_worker()
	var stopped: Dictionary = worker.persistent_poll(int(pending.get("token",-1)))
	check(stopped.get("status","")!="pending" and not worker._persistent_lease and
		worker._persistent_operation_id.is_empty() and worker._persistent_candidate.is_empty(),
		"stop retires request, lease and private candidate")
	# Simulate delivery of a stale completion value after the real worker joined.
	worker._persistent_finish(int(pending.get("token",-1)),{"late":true})
	stopped=worker.persistent_poll(int(pending.get("token",-1)))
	check(stopped.get("status","")=="failed" and not stopped.get("ok",true),
		"late completion cannot acknowledge after stopped owner")
	check(not worker._world.has_failed(),"old native World remains healthy after cancellation and stop")

func unsupported_host_cursor() -> void:
	var value: Dictionary = Fixture.definition()
	value.events=[{"tick":30,"kind":"erase","x":40,"y":385,"width":8,"height":8,
		"material":0,"normalized_mass":0,"coherence":0}]
	var validated: Dictionary = Contract.validate(value)
	check(validated.get("ok",false),"future-event source is a valid ordinary Workbench definition")
	if not validated.get("ok",false): return
	check(await start(validated.definition),"ordinary future-event Workbench installs")
	if not installed(1): worker.stop_worker(); return
	var captured: Dictionary = await request("capture","event-owner")
	check(not captured.get("ok",true) and "cursor" in str(captured.get("error","")),
		"unsupported host cursor pins source before durable departure")
	check(not worker._persistent_lease,"refused capture releases lease")
	worker.stop_worker()
	check(not worker._world.has_failed() and worker._scenario_host.definition().events.size()==1,
		"refusal retains actual native World and scheduled host event")

func run() -> void:
	fixture=Fixture.create()
	if fixture.has("error"):
		check(false,"native fixture: "+str(fixture.error)); quit(1); return
	await freeze_and_cancel()
	await unsupported_host_cursor()
	print("GEN006_OWNER_ADVERSARIAL assertions=%d failures=%d" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
