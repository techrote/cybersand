extends SceneTree

# Every accepted deferred human gesture gets one terminal result, including
# pre-native cancellation/refusal. Success is emitted after authored recording.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var bench: Control
var editor: Control
var worker: RefCounted
var outcomes: Array = []
var checks := 0
var failures: Array[String] = []
var completed := false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WB_DEFERRED_PAINT "+label)
	return ok

func until(predicate: Callable,label: String) -> bool:
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return check(false,label)

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and not worker.paint_state().busy \
		and host.pending_microscenario_apply.is_empty()

func received(token: int) -> Array:
	return outcomes.filter(func(row: Dictionary) -> bool: return int(row.token)==token)

func terminal(token: int,status: String) -> Dictionary:
	if not await until(func() -> bool: return not received(token).is_empty(),"terminal callback for token %d" % token): return {}
	var matches := received(token)
	check(matches.size()==1,"one terminal callback for token %d" % token)
	var row: Dictionary = matches.front()
	check(row.receipt.status==status,"token %d truthful terminal status %s" % [token,status])
	return row

func cell(point: Vector2i) -> int:
	var source: Dictionary = worker.paint_state()
	var admission: Dictionary = worker.paint_queue({"kind":"capture","region":Rect2i(point,Vector2i.ONE),
		"expected_generation":int(source.generation),"expected_revision":int(source.revision),"expected_tick":int(source.tick)})
	if not check(admission.status=="queued","independent native capture admitted"): return -1
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"independent capture completion"): return -1
	var receipt: Dictionary = worker.paint_take_result()
	if not check(receipt.status=="completed" and receipt.materials.size()==1,"independent stored native value available"): return -1
	return int(receipt.materials[0])

func rejected_replacement_prefix() -> bool:
	var panel: Window = bench.art_batches
	var art: RefCounted = panel.executor
	# Hold main-thread receipt consumption, not native execution. This creates
	# a real applied prefix whose authoring record is not yet acknowledged.
	panel.set_process(false)
	var admission: Dictionary = art.submit([{"shape":"pixels","points":[[90,90]],"material":58}],
		Rect2i(0,0,512,512),[],[0,58])
	if not check(admission.status=="queued","replacement-failure fixture admits agent prefix"):
		panel.set_process(true)
		return false
	art.poll()
	if not await until(func() -> bool: return worker.art_state().receipt_ready,"agent prefix reaches native completion before replacement"):
		panel.set_process(true)
		return false
	var generation := int(worker.paint_state().generation)
	var old_policy: Array = bench.applied.liquid_policy.duplicate()
	var malformed := Setup.fresh(PackedInt32Array([1]),Vector2i(512,512))
	check(Setup.validate(malformed).is_empty(),"malformed policy passes authored document shape validation")
	if not check(bench.apply(malformed),"replacement reaches actual asynchronous native policy validation"):
		panel.set_process(true)
		return false
	if not await until(func() -> bool: return host.pending_microscenario_apply.is_empty(),"native invalid-policy replacement is refused"):
		panel.set_process(true)
		return false
	check(not host.microscenario_error.is_empty() and int(worker.paint_state().generation)==generation
		and bench.applied.liquid_policy==old_policy,"rejected replacement retains the old native World and authored policy")
	art.poll()
	check(not art.active and int(art.last_receipt.get("changed",0))==1,
		"retained native prefix still produces its truthful Stop receipt")
	check(bench.applied.edits.any(func(stamp: Array) -> bool: return stamp==[90,90,1,1,58]),
		"failed replacement retains the confirmed agent prefix in authored history")
	panel.set_process(true)
	check(await cell(Vector2i(90,90))==58,"old World actually retains the confirmed agent cell after failed replacement")
	bench._name.text = "wb-rejected-replacement-prefix"
	check(bench.save_setup(),"old authored start remains savable after failed replacement")
	var saved: Dictionary = Setup.read_named(bench._name.text)
	check(not saved.has("error") and saved.setup.edits.any(func(stamp: Array) -> bool: return stamp==[90,90,1,1,58]),
		"saved start preserves the agent cell after rejected replacement")
	DirAccess.remove_absolute(Setup._path(bench._name.text))
	return true

func exercise() -> void:
	if not await until(ready,"Workbench ready"): return
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"blank test start admitted"): return
	if not await until(ready,"blank start installed"): return
	editor.deferred_brush_finished.connect(func(token: int,receipt: Dictionary) -> void:
		outcomes.append({"token":token,"receipt":receipt.duplicate(true),
			"recorded_edits":bench.applied.edits.duplicate(true),"undo_count":editor._undo_stack.size()}))
	if not check(editor.begin_deferred_brush(Vector2i(40,40),58,0,1),"valid deferred gesture admitted"): return
	var outcome: Dictionary = await terminal(1,"completed")
	if outcome.is_empty(): return
	check(outcome.receipt.get("recorded",false) and outcome.receipt.applied==1 and outcome.receipt.changed==1,
		"completion confirms one native changed cell and authored recording")
	check(not outcome.recorded_edits.is_empty() and outcome.undo_count==1,
		"terminal callback observes completed authored record and history")
	check(await cell(Vector2i(40,40))==58,"completed gesture changed actual native stored material")

	# Geometry rejection happens asynchronously after the request was accepted.
	if not check(editor.begin_deferred_brush(Vector2i(-1,-1),58,0,2),"out-of-bounds gesture enters bounded planner"): return
	outcome = await terminal(2,"refused")
	if outcome.is_empty(): return
	check(int(outcome.receipt.get("applied",0))==0,"planner refusal reports no native writes")

	if not check(editor.begin_deferred_brush(Vector2i(50,50),58,24,3),"cancellable deferred planner admitted"): return
	editor.cancel()
	outcome = await terminal(3,"cancelled")
	if outcome.is_empty(): return
	check(int(outcome.receipt.get("applied",0))==0 and await cell(Vector2i(50,50))==0,
		"cancelled planner neither hangs nor paints")

	# Hold only main-thread plan consumption. A real legacy mutation changes the
	# native source before the frozen plan is submitted, exercising its fence.
	editor.set_process(false)
	var revision: int = worker.paint_state().revision
	if not check(editor.begin_deferred_brush(Vector2i(60,60),58,0,4),"deferred source-fence fixture admitted"):
		editor.set_process(true)
		return
	check(worker.queue_emit_cells(PackedInt32Array([61,61]),2),"outside legacy mutation admitted before native PAINT lease")
	if not await until(func() -> bool: return int(worker.paint_state().revision)>revision,"real native source changed while planner waits"):
		editor.set_process(true)
		return
	editor.set_process(true)
	outcome = await terminal(4,"invalidated")
	if outcome.is_empty(): return
	check(int(outcome.receipt.get("applied",0))==0 and await cell(Vector2i(60,60))==0,
		"stale deferred plan terminates without writing its target")

	bench.applied.source = [70,70,2]
	if not check(editor.begin_deferred_brush(Vector2i(71,71),58,0,5),"protected-cell gesture enters planner"): return
	outcome = await terminal(5,"refused")
	if outcome.is_empty(): return
	check(outcome.receipt.applied==0 and outcome.receipt.get("backend")=="CyberNativeCellWorld",
		"native protection refusal reaches deferred completion callback")
	bench.applied.source = []
	check(await cell(Vector2i(71,71))==0,"native refusal preserves covered source cell")
	if not check(await rejected_replacement_prefix(),"failed-replacement native prefix workflow completed"): return

	# Real tree teardown must terminate an accepted planning token as well.
	editor.set_process(false)
	if not check(editor.begin_deferred_brush(Vector2i(80,80),58,0,6),"deferred planner admitted before application shutdown"): return
	host.queue_free()
	await process_frame
	await process_frame
	host = null
	var closed := received(6)
	check(closed.size()==1 and closed.front().receipt.status=="cancelled",
		"actual Workbench shutdown emits one cancelled planning completion")
	check(outcomes.size()==6,"all six accepted gestures produced exactly one terminal callback")
	completed = true

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench = host.shared_workbench
	editor = bench.paint_editor
	worker = host.simulation_worker
	await exercise()
	check(completed,"all deferred terminal paths actually executed")
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	print("WB_DEFERRED_PAINT ",JSON.stringify({"checks":checks,"failures":failures,"completed":completed,"outcomes":outcomes}))
	quit(1 if not failures.is_empty() else 0)
