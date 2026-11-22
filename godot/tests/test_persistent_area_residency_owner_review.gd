extends SceneTree
## Independent adversarial tests of the real worker/host residency boundary.
## This test did not implement the worker or native handoff it challenges.

const Worker = preload("res://scripts/simulation_worker.gd")
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Protocol = preload("res://scripts/persistent_area_worker_protocol.gd")
var worker: CyberSimulationWorker
var fixture: Dictionary
var checks := 0
var failures := 0
var evidence := ""
var events: Array = []


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("RAMCACHE independent owner: "+label)
	return value


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--owner-review-evidence="): evidence = argument.trim_prefix("--owner-review-evidence=")
	run.call_deferred()


func wait_for(predicate: Callable, milliseconds: int = 30000) -> bool:
	var deadline := Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return false


func installed(serial: int) -> bool:
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	return snapshot != null and int(snapshot.lab_context.get("scenario_request_serial",-1))==serial \
		and bool(snapshot.lab_context.get("scenario_request_applied",false))


func request(kind: String, operation_id: String, extra: Dictionary = {}) -> Dictionary:
	var command := extra.duplicate(true)
	command.kind = kind
	command.operation_id = operation_id
	var admitted: Dictionary = worker.persistent_request(command)
	if not admitted.get("ok",false): return admitted
	var token := int(admitted.token)
	if not await wait_for(func() -> bool: return worker.persistent_poll(token).get("status","")!="pending"):
		return {"ok":false,"error":"independent owner request watchdog"}
	return worker.persistent_poll(token)


func command(definition: Dictionary, serial: int, options: Dictionary) -> Dictionary:
	return {"scenario_reset":definition,"scenario_request_serial":serial,"scenario_mode":"Inspect",
		"sampled_character_enabled":false,"runtime_enclosure_recovery_enabled":false,
		"exploratory_actor_definitions":[],"liquid_policy":fixture.bridge.default_liquid_policy(),"controlled_liquid_setup":options}


func identity(area_id: String, source_hash: String) -> Dictionary:
	return {"session_id":"1".repeat(32),"area_id":area_id,"incarnation":area_id.repeat(32),
		"runtime_sha256":"2".repeat(64),"authored_source_sha256":source_hash}


func same_active(expected: Dictionary, operation_id: String) -> bool:
	var state := await request("resident_status",operation_id)
	return state.get("ok",false) and state.result.active == expected


func prefetch_refuses(value: Dictionary, label: String) -> void:
	var started := int(worker.persistent_prefetch_poll(0).get("private_preparations_started",-1))
	var admitted: Dictionary = worker.persistent_prefetch_request(value)
	if admitted.get("ok",false):
		var token := int(admitted.token)
		var finished := await wait_for(func() -> bool: return worker.persistent_prefetch_poll(token).get("status","")!="pending")
		var result: Dictionary = worker.persistent_prefetch_poll(token)
		events.append({"attack":label,"admitted":true,"result_status":result.get("status",""),
			"error":result.get("error",""),"private_before":started,"private_after":result.get("private_preparations_started",-1)})
		check(finished and not result.get("ok",true),label+": refused at exclusive owner preflight")
		check(int(result.get("private_preparations_started",-2))==started,label+": zero private preparation allocations")
		if result.get("ok",false) and result.get("result",{}).get("receipt") is Dictionary:
			await request("resident_release","review-cleanup",{"receipt":result.result.receipt})
	else:
		events.append({"attack":label,"admitted":false,"error":admitted.get("error","")})
		check(true,label+": rejected before request transfer")
		check(int(worker.persistent_prefetch_poll(0).get("private_preparations_started",-2))==started,label+": zero private preparation allocations")


func run() -> void:
	fixture = Fixture.create()
	if not check(not fixture.has("error"),"native test fixture constructs"): finish(); return
	worker = Worker.new(false)
	worker.set_physical_actor_epoch(29)
	worker.set_frame_state(0,false,true,Vector2i(256,256),Vector2i.ZERO,Vector2i(512,512),0,0,true,false,true)
	if not check(worker.start_worker(Vector2(24,222))==OK,"actual simulation owner thread starts"): finish(); return
	worker.queue_lab(command(fixture.checked.definition,1,fixture.options))
	if not check(await wait_for(func() -> bool: return installed(1)),"actual actor-free Workbench A installs"): finish(); return
	var operation_id := "3".repeat(32)
	var captured := await request("capture",operation_id)
	if not check(captured.get("ok",false),"exclusive native capture acquires lease: "+str(captured.get("error",""))): finish(); return
	var original_a: Dictionary = captured.result.capsule
	var bound_a := await request("resident_bind",operation_id,{"identity":identity("a",fixture.checked.hash)})
	if not check(bound_a.get("ok",false),"actual native A receives retained handle"): finish(); return
	var definition_b := Fixture.definition()
	definition_b.rectangles[-1] = 58
	var checked_b := Contract.validate(definition_b)
	var options_b: Dictionary = fixture.options.duplicate(true)
	options_b.definition_hash = checked_b.hash
	options_b.persistent_operation_id = operation_id
	options_b.persistent_stage = true
	worker.queue_lab(command(checked_b.definition,2,options_b))
	var prepared := false
	for index: int in 100:
		var status := await request("status",operation_id)
		if status.get("ok",false) and status.result.get("prepared",false): prepared = true; break
		await process_frame
	if not check(prepared,"actual independent B native World privately stages"): finish(); return
	check((await request("commit",operation_id)).get("ok",false),"B commits through ordinary native prepared owner")
	if not check(await wait_for(func() -> bool: return installed(2)),"worker acknowledges B installation serial2"): finish(); return
	var bound_b := await request("resident_bind",operation_id,{"identity":identity("b",checked_b.hash)})
	if not check(bound_b.get("ok",false),"B native active owner binds exact independent source"): finish(); return
	var state := await request("resident_status",operation_id)
	var active_b: Dictionary = state.result.active
	var inactive_a: Dictionary = state.result.inactive[0]
	var generation := int(state.result.owner_fence.world_generation)
	var frozen_b := await request("resident_capture",operation_id,{"receipt":active_b})
	var handoff := {"operation_id":operation_id,"target_receipt":inactive_a,"serial":3,"expected_generation":generation}
	var stale := handoff.duplicate(true)
	stale.serial = 2
	check(not worker.persistent_stage_resident_handoff(stale).get("ok",true),"stale Main serial cannot acquire a handoff ticket")
	stale = handoff.duplicate(true)
	stale.erase("expected_generation")
	check(not worker.persistent_stage_resident_handoff(stale).get("ok",true),"missing active-generation fence refuses staging")
	var unsafe_handoff_node := Node.new()
	stale = handoff.duplicate(true)
	stale.target_receipt["unsafe"] = unsafe_handoff_node
	check(not worker.persistent_stage_resident_handoff(stale).get("ok",true),"target receipt cannot carry a live Object into staged ownership")
	stale = handoff.duplicate(true)
	stale["unused"] = unsafe_handoff_node
	check(not worker.persistent_stage_resident_handoff(stale).get("ok",true),"unknown handoff fields cannot smuggle a live Object")
	unsafe_handoff_node.free()
	var activate := {"target_receipt":inactive_a,"active_receipt":active_b,"serial":3,"expected_generation":generation}
	check(not (await request("activate_resident",operation_id,activate)).get("ok",true),"fresh receipts alone cannot bypass Main handoff admission")
	check(await same_active(active_b,operation_id),"missing-ticket attack leaves exact active native receipt unchanged")
	var admitted: Dictionary = worker.persistent_stage_resident_handoff(handoff)
	if not check(admitted.get("ok",false),"valid staged Main target receives one-use ticket"): finish(); return
	activate.worker_ticket = int(admitted.ticket)
	for fault: String in ["ticket","serial","generation","target","missing_generation"]:
		var forged := activate.duplicate(true)
		match fault:
			"ticket": forged.worker_ticket += 1
			"serial": forged.serial = 2
			"generation": forged.expected_generation -= 1
			"target": forged.target_receipt.identity.area_id = "c"
			"missing_generation": forged.erase("expected_generation")
		check(not (await request("activate_resident",operation_id,forged)).get("ok",true),"wrong "+fault+" cannot transfer native ownership")
		check(await same_active(active_b,operation_id),"wrong "+fault+" preserves active native authority")
	check(worker.persistent_cancel_resident_handoff(int(admitted.ticket)),"uncommitted handoff cancellation acknowledges exact ticket")
	check(not (await request("activate_resident",operation_id,activate)).get("ok",true),"cancelled one-use ticket cannot regain authority")
	var unaltered := await request("resident_capture",operation_id,{"receipt":active_b})
	check(unaltered.get("ok",false) and unaltered.result.capsule.bytes==frozen_b.result.capsule.bytes,
		"all stale handoff attacks retain complete byte-exact native B state")
	admitted = worker.persistent_stage_resident_handoff(handoff)
	activate.worker_ticket = int(admitted.get("ticket",0))
	var accepted := await request("activate_resident",operation_id,activate)
	if not check(accepted.get("ok",false),"fresh exact ticket transfers actual retained native A"): finish(); return
	check(await wait_for(func() -> bool: return installed(3)),"hot transfer publishes fresh worker Main serial")
	check(not (await request("activate_resident",operation_id,activate)).get("ok",true),"used handoff ticket cannot activate twice")
	state = await request("resident_status",operation_id)
	var active_a: Dictionary = state.result.active
	var inactive_b: Dictionary = state.result.inactive[0]
	var returned := await request("resident_capture",operation_id,{"receipt":active_a})
	check(returned.get("ok",false) and returned.result.capsule.bytes==original_a.bytes,"native A survived B departure/return without deserialization")
	events.append({"stage":"hot-return","native_counters":state.result.get("counters",{}),"active_receipt":active_a,
		"native_sha256":returned.result.capsule.sha256})
	var release_stage: Dictionary = worker.persistent_stage_resident_handoff({"operation_id":operation_id,
		"target_receipt":inactive_b,"serial":4,"expected_generation":int(state.result.owner_fence.world_generation)})
	check(release_stage.get("ok",false),"stage another target before owner lease departure")
	check((await request("release",operation_id)).get("ok",false),"owner release acknowledges")
	operation_id = "4".repeat(32)
	check((await request("freeze",operation_id,{"expected_generation":int(state.result.owner_fence.world_generation)})).get("ok",false),"new owner lease acquires after release")
	check(not (await request("activate_resident",operation_id,{"target_receipt":inactive_b,"active_receipt":active_a,
		"worker_ticket":release_stage.get("ticket",0),"serial":4,"expected_generation":int(state.result.owner_fence.world_generation)})).get("ok",true),
		"release retires prior operation's handoff ticket even when native state is unchanged")
	check((await request("release",operation_id)).get("ok",false),"new lease releases without adopting stale state")
	var authoring := {"setup":Setup.fresh(fixture.bridge.default_liquid_policy(),Vector2i(512,512)),
		"definition":fixture.checked.definition,"generated_packet":{},"material_baseline":{},
		"camera":{"origin":Vector2i.ZERO,"view_size":Vector2i(512,512),"zoom":1.0,"mode":"overview"}}
	state = await request("resident_status","review-current-bounds")
	var native_bound := int(state.result.active.native_reservation_bytes)
	var prediction := {"identity":identity("c",fixture.checked.hash),"operation_id":"5".repeat(32),
		"authoring":authoring,"capture":original_a,"max_ticks":0,"max_us":5000,
		"reservation_bytes":3*native_bound+64*1024*1024,"max_native_bytes":native_bound}
	if not check(Protocol.prefetch_error(prediction).is_empty(),"positive prefetch control satisfies public value contract: "+Protocol.prefetch_error(prediction)):
		finish(); return
	var prepared_prediction: Dictionary = worker.persistent_prefetch_request(prediction)
	if not check(prepared_prediction.get("ok",false),"positive real prefetch request admits"): finish(); return
	var prediction_token := int(prepared_prediction.token)
	check(await wait_for(func() -> bool: return worker.persistent_prefetch_poll(prediction_token).get("status","")!="pending"),
		"positive private native destination finishes before activation")
	var prepared_result: Dictionary = worker.persistent_prefetch_poll(prediction_token)
	if not check(prepared_result.get("ok",false) and prepared_result.get("status","")=="ready",
		"positive private destination becomes real inactive HOT state: "+str(prepared_result.get("error",""))): finish(); return
	check((await request("resident_release","positive-prefetch-cleanup",{"receipt":prepared_result.result.receipt})).get("ok",false),
		"positive prepared owner is safely released without active adoption")
	for fault: String in ["negative_ticks","too_many_ticks","bad_time","unknown_field","missing_reservation","small_reservation","small_native"]:
		var forged := prediction.duplicate(true)
		match fault:
			"negative_ticks": forged.max_ticks = -1
			"too_many_ticks": forged.max_ticks = 33
			"bad_time": forged.max_us = 100001
			"unknown_field": forged.unrecognized = "refuse"
			"missing_reservation": forged.erase("reservation_bytes")
			"small_reservation": forged.reservation_bytes = native_bound
			"small_native": forged.max_native_bytes = 1
		await prefetch_refuses(forged,"invalid prefetch "+fault)
	var node := Node.new()
	for field: String in ["capture","authoring"]:
		var forged := prediction.duplicate(true)
		if field == "capture": forged.capture.host_settings["unsafe"] = node
		else: forged.authoring.camera["unsafe"] = node
		await prefetch_refuses(forged,"live Object in "+field)
	# An irrelevant known field must not smuggle a scene object across threads.
	var extra_object := prediction.duplicate(true)
	extra_object.receipt = {"unsafe":node}
	await prefetch_refuses(extra_object,"live Object in irrelevant checkpoint receipt")
	var advance_only := {"identity":inactive_b.identity,"operation_id":"6".repeat(32),"advance_only":true,
		"receipt":inactive_b,"max_ticks":1,"max_us":5000,"authoring":{"unsafe":node}}
	await prefetch_refuses(advance_only,"live Object in irrelevant advance authoring")
	node.free()
	state = await request("resident_status","review-final")
	check(state.get("ok",false) and state.result.active.handle==active_a.handle,"prefetch attacks never replace active area")
	events.append({"stage":"prefetch-attacks","private_preparations_started":worker.persistent_prefetch_poll(0).get("private_preparations_started",-1),
		"native_counters":state.result.get("counters",{})})
	finish()


func finish() -> void:
	if worker != null: worker.stop_worker()
	if not evidence.is_empty():
		var output := FileAccess.open(evidence,FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":events,"pid":OS.get_process_id()},"\t"))
			output.close()
	print("GEN006_RAMCACHE_OWNER_REVIEW checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
