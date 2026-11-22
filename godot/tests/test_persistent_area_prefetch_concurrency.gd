extends "res://tests/test_persistent_area_residency_owner_review.gd"
## Independent actual-native concurrency qualification, not synthetic ticks.

const Clock = preload("res://scripts/persistent_area_clock.gd")
const Cache = preload("res://scripts/persistent_area_cache.gd")
const Store = preload("res://scripts/persistent_area_store.gd")
var clock: Dictionary = Clock.fresh()
var cache := Cache.new()
var authoring: Dictionary
var original: Dictionary
var native_bound := 0
var frame_count := 0
var maximum_frame_gap_usec := 0
var phase_maximum_frame_gap_usec := 0
var previous_frame_usec := 0


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--prefetch-concurrency-evidence="):
			evidence = argument.trim_prefix("--prefetch-concurrency-evidence=")
	run.call_deferred()


func frame() -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	if previous_frame_usec>0:
		maximum_frame_gap_usec = maxi(maximum_frame_gap_usec,now-previous_frame_usec)
		phase_maximum_frame_gap_usec = maxi(phase_maximum_frame_gap_usec,now-previous_frame_usec)
	previous_frame_usec = now
	frame_count += 1
	var tick := int(worker.paint_state().get("tick",-1))
	if tick>=int(clock.areas.a.native_ticks):
		var observed := Clock.active(clock,"a",tick)
		if observed.get("ok",false): clock = observed.clock


func tick_at_least(tick: int) -> bool:
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await frame()
		if int(clock.areas.a.native_ticks)>=tick: return true
	return false


func start_frame_measurement() -> void:
	phase_maximum_frame_gap_usec = 0
	previous_frame_usec = Time.get_ticks_usec()


func set_paused(paused: bool) -> void:
	worker.set_frame_state(0,false,paused,Vector2i(256,256),Vector2i.ZERO,Vector2i(512,512),0,0,true,false,true)


func prediction(area_id: String, operation_id: String, ticks: int) -> Dictionary:
	return {"identity":identity(area_id,fixture.checked.hash),"operation_id":operation_id,
		"authoring":authoring,"capture":original,"max_ticks":ticks,"max_us":1,
		"reservation_bytes":3*native_bound+64*1024*1024,"max_native_bytes":native_bound}


func await_prediction(token: int) -> Dictionary:
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		var result: Dictionary = worker.persistent_prefetch_poll(token)
		if result.get("status","")!="pending": return result
		await frame()
	return {"ok":false,"error":"private native prefetch watchdog","status":"failed"}


func initialize_ledger(receipt: Dictionary) -> bool:
	var manifest := {"session_id":"1".repeat(32),"compatibility":"concurrency:"+"2".repeat(64),
		"revision":1,"active_area":"a","clock":Clock.fresh(),"areas":{}}
	for id: String in Clock.AREA_IDS:
		manifest.areas[id] = {"area_id":id,"incarnation":id.repeat(32),"generation":1,
			"mutation_generation":0,"completed_tick":0,"native_sha256":original.sha256,
			"authoring_sha256":Store.digest(var_to_bytes(authoring)),
			"authored_source_sha256":original.authored_source_sha256,
			"physics_profile_sha256":original.physics_profile_sha256,"policy_sha256":original.policy_sha256}
	if not check(cache.open(manifest,512*1024*1024).ok,"bounded native receipt ledger opens"): return false
	if not check(cache.admit_hot("a",receipt,authoring,0,"",true).ok,"actual active native receipt admits"): return false
	return check(cache.set_active("a").ok,"live A remains pinned")


func run() -> void:
	fixture = Fixture.create()
	if not check(not fixture.has("error"),"controlled fire/water/sand native fixture constructs"): finish(); return
	worker = Worker.new(false)
	worker.set_physical_actor_epoch(31)
	set_paused(true)
	if not check(worker.start_worker(Vector2(24,222))==OK,"actual active simulation Thread starts"): finish(); return
	worker.queue_lab(command(fixture.checked.definition,1,fixture.options))
	if not check(await wait_for(func() -> bool: return installed(1)),"actual A installs before concurrency begins"): finish(); return
	var lease := "3".repeat(32)
	var captured := await request("capture",lease)
	if not check(captured.get("ok",false),"initial native source captures at tick zero"): finish(); return
	original = captured.result.capsule
	var bound := await request("resident_bind",lease,{"identity":identity("a",fixture.checked.hash)})
	if not check(bound.get("ok",false),"A binds its real native resident handle"): finish(); return
	var original_a: Dictionary = bound.result.receipt
	native_bound = int(original_a.native_reservation_bytes)
	authoring = {"setup":Setup.fresh(fixture.bridge.default_liquid_policy(),Vector2i(512,512)),
		"definition":fixture.checked.definition,"generated_packet":{},"material_baseline":{},
		"camera":{"origin":Vector2i.ZERO,"view_size":Vector2i(512,512),"zoom":1.0,"mode":"overview"}}
	if not initialize_ledger(original_a): finish(); return
	check((await request("release",lease)).get("ok",false),"initial lease releases before gameplay")
	set_paused(false)
	if not check(await tick_at_least(4),"active A completes real native ticks before prediction"): finish(); return
	var operation_id := "4".repeat(32)
	var planned := Clock.plan_background(clock,"b",2,operation_id)
	if not check(planned.get("ok",false) and planned.plan.work_ticks==2,"B predicts an existing legitimate debt interval"): finish(); return
	var prepare_request := prediction("b",operation_id,int(planned.plan.work_ticks))
	if not check(cache.reserve(operation_id,"b",int(prepare_request.reservation_bytes),0).ok,"preparation memory reserves before allocation"): finish(); return
	var first_tick := int(clock.areas.a.native_ticks)
	var frames_before := frame_count
	start_frame_measurement()
	var admitted: Dictionary = worker.persistent_prefetch_request(prepare_request)
	if not check(admitted.get("ok",false),"private native B starts while A is playing"): finish(); return
	worker.queue_paint(65,60,0,0)
	worker.queue_paint(72,60,0,58)
	var prepared := await await_prediction(int(admitted.token))
	if not check(prepared.get("ok",false) and prepared.get("status","")=="ready",
		"real private B completes: "+str(prepared.get("error",""))): finish(); return
	check(int(clock.areas.a.native_ticks)>first_tick and frame_count>frames_before,"active native ticks and main frames continue during reconstruction")
	var receipt_b: Dictionary = prepared.result.receipt
	var actual := int(receipt_b.completed_tick)
	check(actual>0 and actual<int(planned.plan.work_ticks),"bounded private work truthfully retains partial native progress")
	check(int(clock.game_ticks)>int(planned.plan.source_game_tick),"global frontier actually advances before B completion")
	var accounted := Clock.complete_background(clock,planned.plan,actual)
	if not check(accounted.get("ok",false),"private completion admits against newer global frontier"): finish(); return
	clock = accounted.clock
	check(not Clock.complete_background(clock,planned.plan,actual).get("ok",true),"private completed interval cannot be credited twice")
	check(cache.admit_hot("b",receipt_b,authoring,int(receipt_b.mutation_generation),operation_id).ok,"prepared B is truly HOT while A remains active")
	check(cache.status().pending_reservations==0 and cache.status().hot_count==2,"promotion retires matching reservation exactly once")
	events.append({"phase":"cold-prefetch-with-live-A","active_tick_before":first_tick,
		"active_tick_after":int(clock.areas.a.native_ticks),"main_frames":frame_count-frames_before,
		"phase_maximum_frame_gap_usec":phase_maximum_frame_gap_usec,
		"native_work":prepared.result,"clock":clock.duplicate(true),"cache":cache.status(clock)})
	# Delay clock ACK until A completes additional actual ticks. Unrelated G
	# advancement must preserve useful B progress rather than cause a restart.
	var obsolete_plan := {}
	var obsolete_receipt := receipt_b.duplicate(true)
	for slice: int in 2:
		operation_id = ("5" if slice==0 else "6").repeat(32)
		planned = Clock.plan_background(clock,"b",2,operation_id)
		if slice==0: obsolete_plan = planned.plan.duplicate(true)
		first_tick = int(clock.areas.a.native_ticks)
		start_frame_measurement()
		admitted = worker.persistent_prefetch_request({"identity":receipt_b.identity,"operation_id":operation_id,
			"advance_only":true,"receipt":receipt_b,"max_ticks":2,"max_us":1})
		if not check(admitted.get("ok",false),"bounded inactive catch-up request admits"): finish(); return
		var advanced := await await_prediction(int(admitted.token))
		if not check(advanced.get("ok",false) and advanced.get("status","")=="ready","inactive World actually executes native catch-up"): finish(); return
		check(await tick_at_least(first_tick+2),"A continues gameplay before background ACK")
		actual = int(advanced.result.receipt.completed_tick)-int(receipt_b.completed_tick)
		check(actual==1,"background slice respects actual native work bound")
		accounted = Clock.complete_background(clock,planned.plan,actual)
		if not check(accounted.get("ok",false),"background completion binds unchanged target frontier"): finish(); return
		clock = accounted.clock
		receipt_b = advanced.result.receipt
		check(cache.refresh_hot("b",receipt_b,int(receipt_b.mutation_generation)).ok,"partial work updates same retained owner")
		check(not Clock.complete_background(clock,planned.plan,actual).get("ok",true),"duplicate native completion refuses")
		events.append({"phase":"background-native-slice","slice":slice,"source_game_tick":planned.plan.source_game_tick,
			"phase_maximum_frame_gap_usec":phase_maximum_frame_gap_usec,
			"game_tick_at_ack":clock.game_ticks,"completed_ticks":actual,"native_receipt":receipt_b,"remaining_debt":Clock.debt(clock,"b")})
	check(not Clock.complete_background(clock,obsolete_plan,1).get("ok",true),"superseded same-area frontier refuses stale completion")
	admitted = worker.persistent_prefetch_request({"identity":obsolete_receipt.identity,"operation_id":"7".repeat(32),
		"advance_only":true,"receipt":obsolete_receipt,"max_ticks":1,"max_us":1})
	check(admitted.get("ok",false),"syntactically valid stale receipt reaches native validator")
	if admitted.get("ok",false):
		check(not (await await_prediction(int(admitted.token))).get("ok",true),"stale native receipt refuses before repeated tick")
	var held_b := await request("resident_capture","8".repeat(32),{"receipt":receipt_b})
	if not check(held_b.get("ok",false),"inactive B captures without stopping A"): finish(); return
	for tick: int in int(receipt_b.completed_tick): check(fixture.world.simulation_tick(),"independent uninterrupted native reference tick")
	var reference: Dictionary = fixture.bridge.capture_workbench_continuation(fixture.world)
	check(reference.bytes==held_b.result.capsule.bytes,"private restore plus partial slices match full uninterrupted native continuation")
	events.append({"phase":"exact-native-reference","ticks":receipt_b.completed_tick,
		"reference_sha256":reference.sha256,"retained_sha256":held_b.result.capsule.sha256})
	# Cancel after a real separate native thread starts, including while an
	# explicit operation holds the active lease. No speculative state may leak.
	for reversal: int in 2:
		operation_id = ("9" if reversal==0 else "a").repeat(32)
		var request_c := prediction("c",operation_id,0)
		var retained_before := int(cache.status().used_bytes)
		if not check(cache.reserve(operation_id,"c",int(request_c.reservation_bytes),0).ok,"reversal reserves bounded resources"): finish(); return
		var started_before := int(worker.persistent_prefetch_poll(0).private_preparations_started)
		start_frame_measurement()
		admitted = worker.persistent_prefetch_request(request_c)
		if not check(admitted.get("ok",false),"C prediction starts before reversal"): finish(); return
		var token := int(admitted.token)
		var started_deadline := Time.get_ticks_msec()+30000
		while int(worker.persistent_prefetch_poll(token).private_preparations_started)==started_before and Time.get_ticks_msec()<started_deadline: await frame()
		check(int(worker.persistent_prefetch_poll(token).private_preparations_started)==started_before+1,"cancel follows actual private Thread start")
		check(not worker.persistent_prefetch_request(request_c).get("ok",true),"one speculative owner bounds full reconstructions")
		if reversal==1:
			lease = "b".repeat(32)
			var frozen := await request("freeze",lease,{"expected_generation":int(worker.paint_state().generation)})
			if not check(frozen.get("ok",false),"explicit transition acquires owner during private preparation"): finish(); return
		check(worker.persistent_prefetch_cancel(token),"reversal cancels exact outstanding private token")
		var cancelled := await await_prediction(token)
		check(cancelled.get("ok",false) and cancelled.get("status","")=="cancelled","cancelled private World joins and retires without adoption")
		cache.release_reservation(operation_id)
		check(cache.status().pending_reservations==0 and int(cache.status().used_bytes)==retained_before,"cancel releases reservation without cache growth")
		var state := await request("resident_status",lease if reversal==1 else "c".repeat(32))
		check(state.get("ok",false) and state.result.entries.size()==2 and int(state.result.active.handle)==int(original_a.handle),"reversal retains exactly A/B and original active A")
		if reversal==1: check((await request("release",lease)).get("ok",false),"active lease releases after obsolete candidate cleanup")
		set_paused(false)
		worker.queue_paint(80,60,0,58)
		first_tick = int(clock.areas.a.native_ticks)
		check(await tick_at_least(first_tick+2),"active gameplay and edits resume after cancellation")
		events.append({"phase":"cancelled-native-reversal","reversal":reversal,"result":cancelled,
			"phase_maximum_frame_gap_usec":phase_maximum_frame_gap_usec,
			"native_counters":state.get("result",{}).get("counters",{}),"cache":cache.status(clock)})
	set_paused(true)
	check(await wait_for(func() -> bool: return not worker.paint_state().get("legacy_busy",true)),"active edits drain before final capture")
	lease = "d".repeat(32)
	var capture_deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<capture_deadline:
		captured = await request("capture",lease)
		if captured.get("ok",false) or not captured.get("retryable",false): break
		await frame()
	if not captured.get("ok",false): events.append({"phase":"final-capture-refusal","receipt":captured})
	if not check(captured.get("ok",false),"final native capture succeeds after concurrent work: "+str(captured.get("error",""))): finish(); return
	var final_a: Dictionary = captured.result.capsule
	clock = Clock.active(clock,"a",int(final_a.completed_tick)).clock
	var current := await request("resident_status",lease)
	check(int(current.result.active.handle)==int(original_a.handle) and current.result.active.identity==original_a.identity,"speculation never replaces active native identity")
	check(cache.refresh_hot("a",current.result.active,int(current.result.active.mutation_generation)).ok,"ledger preserves final active native fences")
	var restored := Fixture.prepare(fixture,Fixture.restore_options(fixture,final_a,Store.new_nonce()))
	check(restored>0 and fixture.bridge.commit_liquid_world(fixture.world,restored),"independent native verification restores frozen A")
	check(fixture.world.material_at(65,60)==0 and fixture.world.material_at(72,60)==58 and fixture.world.material_at(80,60)==58,
		"concurrent work preserves destructive Empty and both authored material marks")
	var exact_a: Dictionary = fixture.bridge.capture_workbench_continuation(fixture.world)
	check(exact_a.bytes==final_a.bytes,"complete active continuation is exact after concurrent preparation")
	check(int(clock.game_ticks)==int(final_a.completed_tick) and int(clock.areas.b.native_ticks)==int(receipt_b.completed_tick)
		and int(clock.areas.c.native_ticks)==0,"independent clocks credit only completed native work")
	events.append({"phase":"final","clock":clock,"cache":cache.status(clock),"native_counters":current.result.counters,
		"active_native_sha256":final_a.sha256,"main_frames":frame_count,"max_observed_frame_gap_usec":maximum_frame_gap_usec,
		"measurement_scope":"headless process-frame samples; whole-run maximum includes fixture verification work; phase maxima exclude intervening full-state reference comparisons; not graphical/GPU performance"})
	check((await request("release",lease)).get("ok",false),"final native lease retires")
	finish()


func finish() -> void:
	if worker != null: worker.stop_worker()
	if not evidence.is_empty():
		var output := FileAccess.open(evidence,FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"events":events,"pid":OS.get_process_id()},"\t"))
			output.close()
	print("GEN006_RAMCACHE_PREFETCH_CONCURRENCY checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
