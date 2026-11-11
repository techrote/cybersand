extends SceneTree

const Executor = preload("res://scripts/art_batch_executor.gd")
var checks := 0
var failures := 0

class Worker extends RefCounted:
	const MAX_PENDING_BRUSH_COMMANDS := 2
	const MAX_BRUSH_FOOTPRINT_CELLS := 4096
	var epoch := 1
	var executing := false
	var receipt := {}
	func art_state() -> Dictionary:
		return {"epoch":epoch,"executing":executing,"queued":false,"receipt_ready":not receipt.is_empty()}
	func art_take_result() -> Dictionary:
		var value := receipt
		receipt = {}
		return value
	func art_stop() -> Dictionary:
		epoch += 1
		return {"epoch":epoch,"acknowledged":not executing}
	func has_failed() -> bool: return false

class Host extends Node:
	var simulation_worker := Worker.new()

class Workbench extends Node:
	const Setup = preload("res://scripts/workbench_setup.gd")
	var host := Host.new()
	var applied := {"brush":7,"edits":[],"extent":[512,512]}
	var message := ""
	var answers: Array = [false,true]
	var attempts: Array = []
	func busy() -> bool: return false
	func refuse(reason: String) -> bool:
		message = reason
		return false
	func paint(point: Vector2i, material: int) -> bool:
		attempts.append([point,material,applied.brush])
		return bool(answers.pop_front()) if not answers.is_empty() else false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var wb := Workbench.new()
	root.add_child(wb)
	wb.add_child(wb.host)
	var executor := Executor.new()
	executor.wb = wb
	executor.active = true
	executor.stopping = true
	executor.waiting = true
	executor.epoch = 1
	executor.record = wb.applied
	wb.host.simulation_worker.executing = true
	var receipts: Array = []
	executor.manual_receipt.connect(func(receipt: Dictionary) -> void: receipts.append(receipt.duplicate(true)))
	check(executor.defer_manual(Vector2i(10,10),0) == 1, "first human stroke deferred")
	wb.applied.brush = 3
	check(executor.defer_manual(Vector2i(20,20),58) == 1, "second stroke retains its own radius")
	check(executor.defer_manual(Vector2i(30,30),58) == -1 and executor.manual.size() == 2, "overflow explicitly refused without losing admitted strokes")
	executor.poll()
	check(wb.attempts.is_empty() and executor.manual.size() == 2, "human replay waits for executing native chunk")
	wb.host.simulation_worker.executing = false
	wb.host.simulation_worker.receipt = {"status":"completed","checked":1,"changed":1,"readback":[[1,1,0,58]]}
	executor.poll()
	check(wb.attempts == [[Vector2i(10,10),0,7],[Vector2i(20,20),58,3]], "both gestures replay in order with captured radii")
	check(wb.applied.brush == 3, "current human radius restored")
	check(executor.result.human_admitted == 1 and executor.result.human_refused == 2 and executor.result.human_pending == 0, "failed replay is refused, never reported as applied")
	check(wb.message.contains("retry") and receipts[-2].status == "refused" and receipts[-1].status == "queued", "visible refusal and diagnostic queue-admission receipts")
	check(wb.applied.edits == [[1,1,1,1,58]], "agent prefix recorded before human replay")
	check(not executor.active, "Stop retires after deferred outcomes")
	executor.active = true
	executor.defer_manual(Vector2i(40,40),58)
	var refused_before: int = executor.result.human_refused
	executor.canvas_changed()
	check(executor.manual.is_empty() and executor.result.human_refused == refused_before+1, "World replacement explicitly refuses remaining accepted gesture")
	check(receipts.back().status == "refused" and receipts.back().reason.contains("Canvas changed"), "replacement feedback identifies the cause")
	executor.waiting = true
	executor.native_refused = false
	executor.result = {"status":"queued","checked":0,"changed":0,"unchanged":0,"excluded":0,"refused":0,"human_pending":0,"human_admitted":0,"human_refused":0,"reason":""}
	wb.host.simulation_worker.receipt = {"status":"refused","reason":"Rebuild native stored readback API","checked":0,"changed":0,"refused":1,"readback":[]}
	executor.poll()
	check(not executor.active and executor.result.status == "refused" and executor.result.refused == 1, "stale-runtime native refusal stops without false success or retry")
	check(executor.result.reason.contains("Rebuild"), "native refusal retains corrective feedback")
	wb.queue_free()
	await process_frame
	print("ART_DEFERRED_MANUAL checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
