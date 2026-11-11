extends RefCounted

signal native_receipt(receipt: Dictionary)
signal manual_receipt(receipt: Dictionary)
## Main-thread direct drawing interface shared by the Stage-1 panel and future models.
const Plan = preload("res://scripts/art_batch_plan.gd")
var wb: Node
var plan: RefCounted
var active := false
var stopping := false
var waiting := false
var epoch := 0
var area: Rect2i
var guards: Array = []
var materials: Array = [0,58]
var result := {"status":"idle","checked":0,"changed":0,"unchanged":0,"excluded":0,"refused":0,"human_pending":0,"human_admitted":0,"human_refused":0,"reason":""}
var record: Dictionary = {}
var manual: Array = []
var delivering_manual := false
var last_receipt: Dictionary = {}
var raster_frame := -1
var native_refused := false

func submit(operations: Variant, scope: Rect2i, protection: Array, allowed: Array = [0,58]) -> Dictionary:
	poll()
	if active: return {"status":"refused","reason":"Finish or Stop the current batch first."}
	if wb.busy() or wb.applied.is_empty(): return {"status":"refused","reason":"Canvas is not ready."}
	var candidate := Plan.new()
	if not candidate.configure(operations,Rect2i(Vector2i.ZERO,wb.Setup.extent_of(wb.applied))): return {"status":"refused","reason":candidate.error}
	for op: Dictionary in candidate.operations:
		if op.material not in allowed: return {"status":"refused","reason":"Enable the requested material first."}
	materials = allowed.duplicate()
	plan = candidate
	area = scope
	guards = protection.duplicate()
	epoch = wb.host.simulation_worker.art_state().epoch
	record = wb.applied
	result = {"status":"queued","checked":0,"changed":0,"unchanged":0,"excluded":0,"refused":0,"human_pending":0,"human_admitted":0,"human_refused":0,"reason":""}
	active = true
	stopping = false
	waiting = false
	native_refused = false
	return result.duplicate()

func stop(reason: String = "Human Stop") -> void:
	if wb == null: return
	wb.host.simulation_worker.art_stop()
	if active:
		stopping = true
		result.reason = reason

func canvas_changed() -> void:
	stop("Canvas replaced")
	record = {}
	_refuse_manual("Canvas changed before deferred human strokes could be applied.")

func _refuse_manual(reason: String) -> void:
	if manual.is_empty(): return
	var count := manual.size()
	manual.clear()
	result.human_pending = 0
	result.human_refused = int(result.get("human_refused",0)) + count
	wb.refuse("%d deferred human stroke(s) refused: %s" % [count, reason])
	manual_receipt.emit({"status":"refused","count":count,"reason":reason})

func _deliver_manual() -> void:
	# A queued human gesture is not proof of native application. Remove it
	# only after admission, or after recording an explicit visible refusal.
	# On this repair branch paint() is the legacy admission API; integration
	# routes the same gesture through PAINT's native completion boundary.
	delivering_manual = true
	while not manual.is_empty():
		if wb.applied.is_empty():
			_refuse_manual("No installed canvas.")
			break
		var stroke: Array = manual.front()
		var brush: int = wb.applied.brush
		wb.applied.brush = stroke[2]
		var admitted: bool = wb.paint(stroke[0],stroke[1])
		wb.applied.brush = brush
		manual.pop_front()
		result.human_pending = manual.size()
		var receipt := {"status":"queued" if admitted else "refused","point":stroke[0],"material":stroke[1],"radius":stroke[2],"count":1}
		if admitted:
			result.human_admitted = int(result.get("human_admitted",0)) + 1
		else:
			result.human_refused = int(result.get("human_refused",0)) + 1
			receipt.reason = "Worker did not admit the deferred human stroke; retry the stroke."
			wb.refuse(receipt.reason)
		manual_receipt.emit(receipt)
	delivering_manual = false

func defer_manual(point: Vector2i, material: int) -> int:
	if not active or delivering_manual: return 0
	if manual.size() >= wb.host.simulation_worker.MAX_PENDING_BRUSH_COMMANDS:
		wb.refuse("Current drawing chunk is busy; retry this brush stroke.")
		result.human_refused = int(result.get("human_refused",0)) + 1
		manual_receipt.emit({"status":"refused","point":point,"material":material,"count":1,"reason":"Deferred human queue is full."})
		return -1
	manual.append([point,material,int(wb.applied.brush)])
	result.human_pending = manual.size()
	manual_receipt.emit({"status":"deferred","point":point,"material":material,"radius":int(wb.applied.brush),"count":1})
	return 1

func add_run(x: int,y: int,width: int,material: int) -> void:
	if record.is_empty(): return
	var edits: Array = record.edits
	if not edits.is_empty():
		var previous: Array = edits.back()
		if previous.size()==5 and previous[0]==x and previous[2]==width and previous[4]==material and previous[1]+previous[3]==y:
			previous[3] += 1
			return
	edits.append([x,y,width,1,material])

func remember(rows: Array) -> void:
	var start := Vector2i(-1,-1)
	var length := 0
	var material := -1
	for row: Array in rows:
		if row[2]==row[3]: continue
		var point := Vector2i(row[0],row[1])
		if length>0 and (point.y!=start.y or point.x!=start.x+length or material!=row[3]):
			add_run(start.x,start.y,length,material)
			length = 0
		if length==0: start = point; material = row[3]
		length += 1
	if length>0: add_run(start.x,start.y,length,material)

func poll() -> void:
	if wb == null: return
	var worker: RefCounted = wb.host.simulation_worker
	var receipt: Dictionary = worker.art_take_result()
	if not receipt.is_empty() and active:
		last_receipt = receipt
		waiting = false
		remember(receipt.get("readback",[]))
		for key: String in ["checked","changed","unchanged","excluded","refused"]: result[key] = int(result.get(key,0)) + int(receipt.get(key,0))
		native_receipt.emit(receipt)
		if receipt.get("status") in ["partial","refused"]:
			native_refused = receipt.get("status") == "refused"
			stop(str(receipt.get("reason","Native write incomplete")))
	if not active: return
	var state: Dictionary = worker.art_state()
	if state.executing: result.status = "executing"
	if state.epoch != epoch: stopping = true
	if wb.host.simulation_worker.has_failed(): stop("Native simulation failed")
	if waiting and not state.executing and not state.queued and state.epoch != epoch: waiting = false
	if not waiting:
		_deliver_manual()
	if stopping:
		if not state.executing and not state.queued and not waiting:
			active = false
			result.status = "refused" if native_refused and result.changed == 0 else ("partial" if result.checked>0 else "cancelled")
		return
	if waiting: return
	var frame := Engine.get_process_frames()
	if raster_frame == frame: return
	raster_frame = frame
	var chunk: Dictionary = plan.next_chunk(worker.MAX_BRUSH_FOOTPRINT_CELLS)
	if chunk.is_empty():
		if not plan.exhausted():
			result.status = "rasterizing"
			return
		result.status = "completed"
		active = false
		return
	var admitted: Dictionary = worker.art_queue(chunk.points,chunk.material,area,guards,epoch,materials)
	if admitted.status == "queued":
		waiting = true
		result.status = "queued"
	else:
		result.status = "partial" if result.checked>0 else "refused"
		result.reason = admitted.reason
		active = false
