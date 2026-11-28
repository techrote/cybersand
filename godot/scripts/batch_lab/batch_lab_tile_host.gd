extends Node
## An isolated consumer of the existing native Workbench owner and Art executor.
## Mutable World access remains exclusively inside CyberSimulationWorker.
const Worker = preload("res://scripts/simulation_worker.gd")
const Executor = preload("res://scripts/art_batch_executor.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Baseline = preload("res://scripts/workbench_material_baseline.gd")
const ARENA := Vector2i(512,512)
const OWNER_TIMEOUT_MS := 90000

class BudgetPlan extends RefCounted:
	var inner: RefCounted
	var remaining := 0
	var exhausted_budget := false
	func next_chunk(capacity: int = 4096) -> Dictionary:
		if remaining <= 0:
			exhausted_budget = not inner.exhausted()
			return {}
		var chunk: Dictionary = inner.next_chunk(mini(capacity,remaining))
		if not chunk.is_empty(): remaining -= chunk.points.size()/2
		exhausted_budget = remaining <= 0 and not inner.exhausted()
		return chunk
	func exhausted() -> bool:
		return inner.exhausted()

var host: Node
var simulation_worker: RefCounted
var executor: RefCounted
var applied: Dictionary = {}
var config: Dictionary = {}
var phase := "idle"
var reason := ""
var result: Dictionary = {}
var receipts: Array = []
var initial_cells := PackedByteArray()
var final_cells := PackedByteArray()
var render_cells := PackedByteArray()
var render_identity: Dictionary = {}
var extent := Vector2i.ZERO
var generation := 0
var snapshot_serial := -1
var snapshot: RefCounted
var capture_token := 0
var started_ms := 0
var phase_ms := 0
var initial_arena_hash := ""
var _budget: BudgetPlan
var _stopping := false
var _restore_only := false
var _timeout_stop_requested := false
var timings := {"model_ms":0.0,"compile_ms":0.0,"native_ms":0.0,"capture_ms":0.0,"total_ms":0.0}

func _init() -> void:
	host = self

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()

func busy() -> bool:
	return phase not in ["ready","drawing"]

func art_authoring_state() -> Dictionary:
	return {"busy":false,"reason":""}

func refuse(message: String) -> bool:
	reason = message
	return false

func art_record_receipt(value: RefCounted, receipt: Dictionary, _submission: int) -> void:
	# Retain exact accepted edits and native counters, with a hash of the consumed
	# original bounded readback. Final authority is the full native captured plane.
	value.remember(receipt.get("readback",[]))
	var retained: Dictionary = receipt.duplicate(true)
	retained["readback_sha256"] = digest(JSON.stringify(receipt.get("readback",[])).to_utf8_buffer())
	retained.erase("readback")
	receipts.append(retained)

func finish_art_history() -> void:
	pass # Lab history is isolated material-baseline restoration, never main Undo.

func begin(value: Dictionary, source: PackedByteArray, restore_only := false) -> Dictionary:
	if phase != "idle": return {"ok":false,"reason":"Tile native owner is already in use."}
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		return {"ok":false,"reason":"Batch Lab requires the source-matched native runtime."}
	config = value.duplicate(true)
	extent = Vector2i(int(config.extent[0]),int(config.extent[1]))
	if source.size() != extent.x*extent.y*2:
		return {"ok":false,"reason":"Tile source material plane has the wrong size."}
	initial_cells = source.duplicate()
	_restore_only = restore_only
	var arena := PackedByteArray()
	var padding := PackedByteArray()
	padding.resize((ARENA.x-extent.x)*2)
	for y: int in extent.y:
		arena.append_array(source.slice(y*extent.x*2,(y+1)*extent.x*2))
		arena.append_array(padding)
	arena.resize(ARENA.x*ARENA.y*2)
	initial_arena_hash = digest(arena)
	var baseline := {"schema":1,"extent":ARENA,"cells":arena,"sha256":initial_arena_hash}
	var validation := Baseline.validate(baseline,ARENA)
	if not validation.is_empty(): return {"ok":false,"reason":validation}
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	applied = Setup.fresh(policy,ARENA)
	var definition := Contract.base(Contract.WORKBENCH_ID)
	definition.schema_version = 2
	definition["extent"] = [ARENA.x,ARENA.y]
	definition.seed = int(config.seed)
	definition.tools = ["paint","erase"]
	definition.interest = {"policy":"fixed","region":[0,0,ARENA.x,ARENA.y]}
	definition.execution.cadence_lod_enabled = false
	definition["presentation"] = {"title":"Isolated Batch Lab attempt","instructions":"Native construction",
		"duration_ticks":1,"baseline":"workbench","profile":"batch-lab","regions":[]}
	var setup := {"intent":"exploratory","normalization":"","maximum_rule_radius":2,
		"workbench_response":"LA-SELECTIVE","workbench_worker_threads":1,
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),
			"geometry":PackedFloat64Array(),"bodies":[],"emitters":[]},
		"workbench_material_baseline":Baseline.native_packet(baseline,[])}
	simulation_worker = Worker.new(true)
	simulation_worker.set_frame_state(0.0,false,true,extent/2,Vector2i.ZERO,extent,0,0,true,false,true)
	simulation_worker.set_render_snapshot_hz(10)
	var error: Error = simulation_worker.start_worker(Vector2.ZERO)
	if error != OK:
		simulation_worker.stop_worker()
		simulation_worker = null
		return {"ok":false,"reason":"Could not start isolated native owner (%d)." % error}
	simulation_worker.queue_lab({"scenario_reset":definition,"scenario_request_serial":1,
		"scenario_mode":"Inspect","sampled_character_enabled":false,
		"liquid_policy":policy,"controlled_liquid_setup":setup})
	executor = Executor.new()
	executor.wb = self
	started_ms = Time.get_ticks_msec()
	phase_ms = started_ms
	phase = "installing"
	return {"ok":true}

func stop(message := "Human Stop") -> void:
	_stopping = true
	reason = message
	if executor != null and executor.active: executor.stop(message)
	elif simulation_worker != null: simulation_worker.art_stop()

func _terminal(status: String, message: String = "") -> void:
	phase = "finished"
	if not message.is_empty(): reason = message
	if result.is_empty(): result = {"status":status,"changed":0,"checked":0,"excluded":0,"refused":0,"confirmed":0}
	result.status = status
	result.reason = reason
	result["final_readback_available"] = not final_cells.is_empty()
	timings.total_ms = Time.get_ticks_msec()-started_ms

func _request_capture(next_phase: String) -> void:
	var answer: Dictionary = simulation_worker.material_capture_request(generation,ARENA.x*ARENA.y*2)
	if not answer.get("ok",false):
		_terminal("partial" if int(result.get("changed",0))>0 else "refused",str(answer.get("reason","Native capture refused.")))
		return
	capture_token = int(answer.token)
	phase = next_phase
	phase_ms = Time.get_ticks_msec()

func _crop(cells: PackedByteArray) -> PackedByteArray:
	if extent==ARENA: return cells.duplicate()
	var cropped := PackedByteArray()
	for y: int in extent.y:
		cropped.append_array(cells.slice(y*ARENA.x*2,(y*ARENA.x+extent.x)*2))
	return cropped

func _begin_drawing() -> void:
	if _stopping or _restore_only:
		result = {"status":"stopped" if _stopping else "completed","checked":0,"changed":0,
			"unchanged":0,"excluded":0,"refused":0,"confirmed":0}
		_request_capture("capturing_result")
		return
	phase = "ready"
	var guards: Array = []
	for rect: Array in config.protection: guards.append(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3])))
	var start := Time.get_ticks_usec()
	var answer: Dictionary = executor.submit(config.operations,Rect2i(Vector2i.ZERO,extent),guards,config.materials)
	timings.compile_ms += float(Time.get_ticks_usec()-start)/1000.0
	if answer.status != "queued":
		result = answer
		_request_capture("capturing_result")
		return
	_budget = BudgetPlan.new()
	_budget.inner = executor.plan
	_budget.remaining = int(config.budget_cells)
	executor.plan = _budget
	phase = "drawing"
	phase_ms = Time.get_ticks_msec()

func poll() -> void:
	if phase in ["idle","finished"] or simulation_worker == null: return
	var update: RefCounted = simulation_worker.take_latest_snapshot(snapshot_serial)
	if update != null:
		snapshot = update
		snapshot_serial = int(update.serial)
		simulation_worker.acknowledge_render_snapshot(int(update.render_snapshot_serial))
	if simulation_worker.has_failed():
		if executor != null:
			if executor.active: executor.stop("The isolated native owner failed."); executor.poll()
			if not executor.result.is_empty(): result = executor.result.duplicate(true)
		_terminal("partial" if int(result.get("changed",0))>0 else "refused","The isolated native owner failed.")
		return
	if Time.get_ticks_msec()-phase_ms > OWNER_TIMEOUT_MS:
		stop("Native owner phase timed out.")
		if phase == "drawing" and not _timeout_stop_requested:
			_timeout_stop_requested = true
			executor.poll()
			result = executor.result.duplicate(true)
			# A healthy owner may already hold a genuine completed chunk. Drain its
			# acknowledgement before the final capture, never discard its counters.
			if not executor.active:
				timings.native_ms += Time.get_ticks_msec()-phase_ms
				if result.status=="cancelled": result.status="stopped"
				_request_capture("capturing_result")
			else: phase_ms = Time.get_ticks_msec()
			return
		if executor != null and not executor.result.is_empty(): result = executor.result.duplicate(true)
		_terminal("partial" if int(result.get("changed",0))>0 else "refused",reason+" Final native readback is unavailable; only acknowledged prefix counters are retained.")
		return
	if phase == "installing":
		if snapshot == null: return
		var context: Dictionary = snapshot.lab_context
		if int(context.get("scenario_request_serial",0)) != 1: return
		if not context.get("scenario_request_applied",false):
			_terminal("refused",str(context.get("status","Native setup refused.")))
			return
		generation = int(snapshot.render_world_generation)
		_request_capture("capturing_source")
	elif phase in ["capturing_source","capturing_result"]:
		var capture: Dictionary = simulation_worker.material_capture_poll(capture_token)
		if capture.is_empty(): return
		var finished: Dictionary = simulation_worker.material_capture_finish(capture_token,false)
		capture_token = 0
		timings.capture_ms += Time.get_ticks_msec()-phase_ms
		if not capture.get("ok",false) or not finished.get("ok",false):
			_terminal("partial" if int(result.get("changed",0))>0 else "refused",str(capture.get("error",finished.get("reason","Capture failed."))))
			return
		if phase == "capturing_source":
			if str(capture.sha256) != initial_arena_hash:
				_terminal("refused","Native source restore differs from its immutable material baseline.")
				return
			initial_cells = _crop(capture.cells)
			_begin_drawing()
		else:
			final_cells = _crop(capture.cells)
			result["native_capture"] = {"sha256":capture.sha256,"generation":capture.generation,
				"schema":capture.schema,"byte_count":capture.cells.size(),"native_boundary_usec":capture.get("native_boundary_usec",0)}
			# Outside the authorised tile remains equal to the restored zero padding.
			var outside_clear := true
			var bottom: PackedByteArray = capture.cells.slice(extent.y*ARENA.x*2)
			if bottom.count(0)!=bottom.size(): outside_clear = false
			for y: int in extent.y:
				var tail: PackedByteArray = capture.cells.slice((y*ARENA.x+extent.x)*2,(y+1)*ARENA.x*2)
				if tail.count(0)!=tail.size(): outside_clear = false
			result["outside_unchanged"] = outside_clear
			if not outside_clear:
				_terminal("partial","Native cells outside the authorised tile changed.")
				return
			_terminal(str(result.get("status","completed")),str(result.get("reason",reason)))
	elif phase == "drawing":
		if _budget.exhausted_budget and not executor.waiting and executor.active:
			executor.stop("Cell budget exhausted; only the native-confirmed prefix is retained.")
		executor.poll()
		result = executor.result.duplicate(true)
		if not executor.active:
			timings.native_ms += Time.get_ticks_msec()-phase_ms
			if result.status == "cancelled": result.status = "stopped"
			_request_capture("capturing_result")

func close() -> void:
	if simulation_worker != null:
		if capture_token != 0: simulation_worker.material_capture_cancel(capture_token)
		simulation_worker.stop_worker()
		simulation_worker = null
	if executor != null:
		executor.wb = null
		executor = null

func _exit_tree() -> void:
	close()
