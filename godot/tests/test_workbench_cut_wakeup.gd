extends SceneTree

const Cut=preload("res://scripts/workbench_cut.gd")
const Wakeup=preload("res://scripts/workbench_cut_wakeup.gd")
var checks: int=0
var failures: int=0
var answers: Array[Dictionary]=[]

class FakeWorker extends RefCounted:
	var pending: RefCounted
	var reply: Dictionary={}
	var discovery: bool=false
	var calls: int=0
	func queue_workbench_cut(command: Dictionary, wakeup: RefCounted=null) -> int:
		calls+=1
		pending=wakeup;wakeup.serial=1;wakeup.generation=7
		if discovery:
			if command.action=="begin":
				reply={"ok":true,"roster_session":1,"roster_epoch":1,"request_id":1,"world_generation":7}
				wakeup.resolve.call_deferred("Reply",wakeup)
			else: wakeup.resolve.call_deferred("Worker stopped; clocks remain held",wakeup)
			return 1
		if command.action=="admission": return 0
		if command.action=="reply" or command.action=="stale":
			reply={"ok":true,"request_id":1,"world_generation":7 if command.action=="reply" else 6}
			wakeup.resolve.call_deferred("Reply",wakeup)
		elif command.action=="stop": wakeup.resolve.call_deferred("Worker stopped; clocks remain held",wakeup)
		return 1
	func take_workbench_cut_reply(_serial: int) -> Dictionary:
		var value: Dictionary=reply;reply={};return value
class Host extends Node:
	var physical_actor_session: RefCounted
	var simulation_worker: RefCounted=FakeWorker.new()
class TestPanel extends Node:
	var host: Node
	var refusal: String=""
	func refuse(reason: String) -> bool: refusal=reason;return false

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("CUT_WAKEUP "+why)

func request(cut: RefCounted, action: String) -> void:
	answers.append(await cut._rpc({"action":action}))

func run() -> void:
	var panel:=TestPanel.new();panel.host=Host.new();root.add_child(panel);panel.add_child(panel.host)
	var cut=Cut.new();cut.panel=panel;cut.busy=true
	for action: String in ["reply","stale","stop","admission"]:
		var reply: Dictionary=await cut._rpc({"action":action})
		check(reply.get("ok",false)==(action=="reply"),"exact reply/stale/stop/admission disposition")
		check(cut.busy and cut._waiting==null,"transport never releases hold and waiter detached")
		var late: RefCounted=panel.host.simulation_worker.pending
		late.resolve("Reply");late.resolve("Timeout")
		check(late.done,"late/repeated notification harmless")
	request(cut,"pending")
	await process_frame
	var old: RefCounted=panel.host.simulation_worker.pending
	cut.retire()
	check(answers.size()==1 and answers[0].outcome=="Retired","retirement wakes pending coroutine synchronously")
	old.resolve.call_deferred("Reply",old)
	await process_frame
	check(answers.size()==1 and cut.panel==null and cut._waiting==null,"late retired delivery cannot resume a new owner")
	var next=Cut.new();next.panel=panel;next.busy=true
	var started: int=Time.get_ticks_msec()
	var timed: Dictionary=await next._rpc({"action":"pending"})
	check(timed.get("transport_failure",false) and str(timed.outcome).contains("timeout") and Time.get_ticks_msec()-started>=19500,"unchanged20-second timeout completes without polling")
	check(next.busy and next._waiting==null,"timeout fail-stop retains clocks and releases waiter")
	panel.host.simulation_worker.pending.resolve("Reply")
	next.retire()
	panel.host.simulation_worker=FakeWorker.new();panel.host.simulation_worker.discovery=true
	var discovery=Cut.new();discovery.panel=panel;discovery.busy=true
	await discovery._run(PackedInt32Array())
	check(panel.host.simulation_worker.calls==2 and discovery.busy,"discovery transport failure stops once without retry/end")
	check(discovery.receipts.size()==1 and panel.refusal.contains("stopped"),"transport failure is not an eligibility refusal")
	discovery.retire();panel.queue_free();await process_frame
	print("CUT_WAKEUP ",checks," checks / ",failures," failures")
	quit(int(failures>0))

func _initialize() -> void: run.call_deferred()
