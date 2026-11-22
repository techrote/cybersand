extends SceneTree

# Independent read-only review probe. Does not patch the owner implementation.
const Worker = preload("res://scripts/simulation_worker.gd")
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Protocol = preload("res://scripts/persistent_area_worker_protocol.gd")

class ScriptErrorCollector extends Logger:
	var mutex := Mutex.new()
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT: return
		mutex.lock()
		errors.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
		mutex.unlock()
	func snapshot() -> Array:
		mutex.lock()
		var result := errors.duplicate(true)
		mutex.unlock()
		return result

const MALFORMED_MODES := ["missing_setup","wrong_setup_types","wrong_execution_type","missing_worker_type"]
const IDENTITY_ATTACK_MODES := ["runtime_mismatch","session_mismatch","source_identity_mismatch",
	"physics_mismatch","policy_mismatch","authoring_changed","warm_corruption","warm_wrong_tick",
	"short_native_reservation","short_transient_reservation","oversized_metadata"]
var error_collector := ScriptErrorCollector.new()
var worker: CyberSimulationWorker
var fixture: Dictionary
var failures: Array[String] = []
var checks := 0
var mode := "healthy"
var capsule: Dictionary
var authoring: Dictionary
var native_bound := 0
var observed: Array = []

func _initialize() -> void:
	OS.add_logger(error_collector)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--independent-mode="): mode = argument.trim_prefix("--independent-mode=")
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("INDEPENDENT_NATIVE_REVIEW: "+label)
	return value

func wait_for(predicate: Callable, milliseconds: int = 15000) -> bool:
	var deadline := Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return false

func request(kind: String, operation: String, extra: Dictionary = {}) -> Dictionary:
	var value := extra.duplicate(true)
	value.kind = kind
	value.operation_id = operation
	var admitted: Dictionary = worker.persistent_request(value)
	if not admitted.get("ok",false): return admitted
	var token := int(admitted.token)
	if not await wait_for(func() -> bool: return worker.persistent_poll(token).get("status","")!="pending"):
		return {"ok":false,"error":"request watchdog","kind":kind}
	return worker.persistent_poll(token)

func identity(area: String) -> Dictionary:
	return {"session_id":"1".repeat(32),"area_id":area,"incarnation":area.repeat(32),
		"runtime_sha256":"2".repeat(64),"authored_source_sha256":fixture.checked.hash}

func paused(value: bool) -> void:
	worker.set_frame_state(0,false,value,Vector2i(256,256),Vector2i.ZERO,Vector2i(512,512),0,0,true,false,true)

func installed(serial: int) -> bool:
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	return snapshot != null and int(snapshot.lab_context.get("scenario_request_serial",-1))==serial \
		and bool(snapshot.lab_context.get("scenario_request_applied",false))

func prediction() -> Dictionary:
	return {"identity":identity("b"),"operation_id":"4".repeat(32),"authoring":authoring.duplicate(true),
		"capture":capsule.duplicate(true),"max_ticks":2,"max_us":100000,
		"max_native_bytes":native_bound,"reservation_bytes":3*native_bound+64*1024*1024}

func wait_prediction(token: int, milliseconds: int = 15000) -> Dictionary:
	var completed := await wait_for(func() -> bool: return worker.persistent_prefetch_poll(token).get("status","")!="pending",milliseconds)
	var result: Dictionary = worker.persistent_prefetch_poll(token)
	result["watchdog_completed"] = completed
	return result

func run() -> void:
	fixture = Fixture.create()
	if not check(not fixture.has("error"),"native fixture created"): finish(); return
	worker = Worker.new(false)
	worker.set_physical_actor_epoch(57)
	paused(true)
	if not check(worker.start_worker(Vector2(24,222))==OK,"actual native owner Thread started"): finish(); return
	worker.queue_lab({"scenario_reset":fixture.checked.definition,"scenario_request_serial":1,"scenario_mode":"Inspect",
		"sampled_character_enabled":false,"runtime_enclosure_recovery_enabled":false,"exploratory_actor_definitions":[],
		"liquid_policy":fixture.bridge.default_liquid_policy(),"controlled_liquid_setup":fixture.options})
	if not check(await wait_for(func() -> bool: return installed(1)),"native Workbench installed"): finish(); return
	var lease := "3".repeat(32)
	var capture := await request("capture",lease)
	if not check(capture.get("ok",false),"source captured through owner API"): finish(); return
	capsule = capture.result.capsule
	var bound := await request("resident_bind",lease,{"identity":identity("a")})
	if not check(bound.get("ok",false),"source admitted into native residency"): finish(); return
	native_bound = int(bound.result.receipt.native_reservation_bytes)
	authoring = {"setup":Setup.fresh(fixture.bridge.default_liquid_policy(),Vector2i(512,512)),
		"definition":fixture.checked.definition,"generated_packet":{},"material_baseline":{},
		"camera":{"origin":Vector2i.ZERO,"view_size":Vector2i(512,512),"zoom":1.0,"mode":"overview"}}
	check((await request("release",lease)).get("ok",false),"initial owner lease released")
	paused(false)
	if not check(await wait_for(func() -> bool: return int(worker.paint_state().tick)>=3),"active native gameplay proceeds"): finish(); return
	var value := prediction()
	match mode:
		"missing_setup": value.authoring.setup = {}
		"wrong_setup_types": value.authoring.setup.rule_radius = []
		"wrong_execution_type": value.capture.execution = "not-an-execution-dictionary"
		"missing_worker_type": value.capture.execution.worker_threads = {}
		"runtime_mismatch": value.identity.runtime_sha256 = "9".repeat(64)
		"session_mismatch": value.identity.session_id = "9".repeat(32)
		"source_identity_mismatch": value.identity.authored_source_sha256 = "9".repeat(64)
		"physics_mismatch": value.capture.physics_profile_sha256 = "9".repeat(64)
		"policy_mismatch": value.capture.policy_sha256 = "9".repeat(64)
		"authoring_changed": value.authoring.definition.rectangles[-1] = 58
		"warm_corruption":
			var damaged: PackedByteArray = value.capture.bytes.duplicate()
			damaged[int(damaged.size()/2)] ^= 1
			value.capture.bytes = damaged
		"warm_wrong_tick": value.capture.completed_tick += 1
		"short_native_reservation": value.max_native_bytes = native_bound-1
		"short_transient_reservation": value.reservation_bytes -= 1
		"oversized_metadata":
			var padding := PackedByteArray()
			padding.resize(5*1024*1024)
			value.capture.execution["ignored_padding_a"] = padding
			value.capture.execution["ignored_padding_b"] = padding.duplicate()
			var metadata: Dictionary = value.capture.duplicate(false)
			metadata.erase("bytes")
			observed.append({"phase":"metadata-size","encoded_bytes":var_to_bytes(metadata).size(),
				"admitted_metadata_limit":Protocol.Store.MAX_METADATA_BYTES})
	var protocol_error: String = Protocol.prefetch_error(value)
	var before_tick := int(worker.paint_state().tick)
	var started_before := int(worker.persistent_prefetch_poll(0).private_preparations_started)
	var admitted: Dictionary = worker.persistent_prefetch_request(value)
	observed.append({"phase":"admission","mode":mode,"protocol_error":protocol_error,"reply":admitted,
		"native_bound":native_bound,"active_tick":before_tick})
	if mode in MALFORMED_MODES or mode in IDENTITY_ATTACK_MODES:
		if mode in MALFORMED_MODES:
			check(not protocol_error.is_empty() and not admitted.get("ok",false),"malformed dereferenced fields refuse before private Thread creation")
		if mode=="oversized_metadata":
			check(not protocol_error.is_empty() and not admitted.get("ok",false),"oversized checkpoint metadata refuses before crossing the owner boundary")
		if admitted.get("ok",false):
			var refused := await wait_prediction(int(admitted.token))
			observed.append({"phase":"malformed-completion","result":refused})
			check(refused.watchdog_completed and not refused.get("ok",true),"malformed prefetch returns an explicit bounded refusal")
		else: check(true,"malformed request rejected before thread transfer")
		check(await wait_for(func() -> bool: return int(worker.paint_state().tick)>before_tick,2000),"active native gameplay remains live after malformed speculation")
		var state := await request("resident_status","5".repeat(32))
		check(state.get("ok",false) and state.get("result",{}).get("entries",[]).size()==1,"malformed preparation retains only the active native owner")
		if mode in MALFORMED_MODES or mode in ["short_native_reservation","short_transient_reservation"]:
			check(int(worker.persistent_prefetch_poll(0).private_preparations_started)==started_before,"rejected shape or reservation never starts a private native owner")
		finish(); return
	if not check(admitted.get("ok",false),"valid destination request admitted"): finish(); return
	var token := int(admitted.token)
	if mode=="stop":
		check(await wait_for(func() -> bool: return int(worker.persistent_prefetch_poll(token).private_preparations_started)>started_before),"private native preparation really started before stop")
		var stop_started := Time.get_ticks_usec()
		worker.stop_worker()
		var stopped := worker.persistent_prefetch_poll(token)
		observed.append({"phase":"stop-complete","elapsed_us":Time.get_ticks_usec()-stop_started,"poll":stopped})
		check(stopped.get("status","") in ["cancelled","failed","stopped"],"stopped owner publishes a terminal outcome for its former pending token")
		check(not worker.persistent_prefetch_request(prediction()).get("ok",true),"stopped owner refuses new preparation")
		worker = null
		finish(); return
	var prepared := await wait_prediction(token)
	if not check(prepared.get("ok",false) and prepared.get("status","")=="ready","private native destination prepared and imported"): observed.append(prepared); finish(); return
	var target: Dictionary = prepared.result.receipt
	if mode=="wrong_incarnation":
		var stale := target.duplicate(true)
		stale.identity.incarnation = "9".repeat(32)
		var stale_step := await request("resident_advance","6".repeat(32),{"receipt":stale,"max_ticks":1,"max_us":100000})
		check(not stale_step.get("ok",true),"wrong-incarnation receipt cannot tick the actual retained native World")
		var second := prediction()
		second.identity.incarnation = "9".repeat(32)
		var collision := worker.persistent_prefetch_request(second)
		if check(collision.get("ok",false),"well-shaped competing incarnation reaches native admission"):
			var refused := await wait_prediction(int(collision.token))
			observed.append({"phase":"competing-incarnation","result":refused})
			check(refused.watchdog_completed and not refused.get("ok",true),"already resident area refuses another incarnation")
		var current := await request("resident_status","5".repeat(32))
		check(current.get("ok",false) and current.result.entries.size()==2,"incarnation attacks retain exactly the two original native owners")
		var retained: Dictionary = {}
		for entry: Dictionary in current.get("result",{}).get("entries",[]):
			if int(entry.get("handle",0))==int(target.handle): retained = entry
		check(retained==target,"incarnation attacks preserve all original inactive receipt fences")
		finish(); return
	for slice: int in 3:
		var prior := target.duplicate(true)
		var step := await request("resident_advance","6".repeat(32),{"receipt":target,"max_ticks":2,"max_us":100000})
		if not check(step.get("ok",false),"inactive imported native owner advances independently"): finish(); return
		target = step.result.receipt
		check(not (await request("resident_advance","6".repeat(32),{"receipt":prior,"max_ticks":1,"max_us":100000})).get("ok",true),"superseded native completion refuses without repeating work")
	paused(true)
	lease = "7".repeat(32)
	var frozen := await request("freeze",lease)
	for attempt: int in 100:
		if frozen.get("ok",false) or not frozen.get("retryable",false): break
		await process_frame
		frozen = await request("freeze",lease)
	if not check(frozen.get("ok",false),"active source frozen for ticketed ownership transfer"): observed.append({"phase":"freeze-refusal","result":frozen}); finish(); return
	var state := await request("resident_status",lease)
	var handoff := {"operation_id":lease,"serial":2,"expected_generation":int(state.result.owner_fence.world_generation),"target_receipt":target}
	var ticket: Dictionary = worker.persistent_stage_resident_handoff(handoff)
	if not check(ticket.get("ok",false),"fresh Main handoff ticket admitted"): finish(); return
	var transfer := await request("activate_resident",lease,{"target_receipt":target,"active_receipt":state.result.active,
		"serial":2,"expected_generation":handoff.expected_generation,"worker_ticket":ticket.ticket})
	if not check(transfer.get("ok",false),"private imported World and retained host transfer together"): observed.append(transfer); finish(); return
	var advanced := await request("advance_active",lease,{"max_ticks":1,"max_us":100000})
	if not check(advanced.get("ok",false) and advanced.result.completed_ticks==1,"retained private host resumes at exact catch-up frontier"): observed.append(advanced); finish(); return
	var active := await request("resident_status",lease)
	var completed := int(active.result.active.completed_tick)
	var actual := await request("resident_capture",lease,{"receipt":active.result.active})
	for tick: int in completed: check(fixture.world.simulation_tick(),"independent uninterrupted reference tick")
	var reference: Dictionary = fixture.bridge.capture_workbench_continuation(fixture.world)
	check(actual.get("ok",false) and actual.result.capsule.bytes==reference.bytes,"import plus inactive catch-up plus first active tick is complete byte-exact continuation")
	observed.append({"phase":"exact-reference","native_tick":completed,"reference_sha256":reference.sha256,
		"actual_sha256":actual.get("result",{}).get("capsule",{}).get("sha256",""),"native_counters":active.result.counters})
	check((await request("release",lease)).get("ok",false),"final lease released")
	finish()

func finish() -> void:
	if worker != null: worker.stop_worker()
	var script_errors := error_collector.snapshot()
	OS.remove_logger(error_collector)
	check(script_errors.is_empty(),"no engine script runtime errors occurred")
	print("GEN006_INDEPENDENT_NATIVE_REVIEW "+JSON.stringify({"mode":mode,"checks":checks,"failures":failures,"script_errors":script_errors,"observed":observed}))
	quit(0 if failures.is_empty() else 1)
