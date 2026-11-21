extends SceneTree

# PAINT-END2END-002 owner-thread burst pilot: actual GDExtension World and
# exclusive simulation worker; no mock native cell objects or altered receipts.
# CYBERSAND_PAINT_BURST_SLICES={1,2,4,8}
# CYBERSAND_PAINT_BURST_PROFILE=1
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var workbench: Control
var worker: RefCounted
var failures: Array[String] = []
var rows: Array = []
var checks := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PAINT_BURST_PILOT " + label)
	return ok

func wait_for(predicate: Callable, limit_ms: int = 120000) -> bool:
	var deadline: int = Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if worker != null and worker.has_failed(): return false
		await process_frame
	return false

func ready() -> bool:
	return not workbench.applied.is_empty() and not workbench.busy() and not bool(worker.paint_state().busy)

func request(values: Dictionary) -> Dictionary:
	var state: Dictionary = worker.paint_state()
	var job: Dictionary = values.duplicate(true)
	job.expected_generation = int(state.generation)
	job.expected_revision = int(state.revision)
	job.expected_tick = int(state.tick)
	job.expected_authoring_generation = int(state.get("authoring_generation",1))
	return job

func finished() -> Dictionary:
	if not check(await wait_for(func()->bool:return bool(worker.paint_state().receipt_ready)),
			"native worker published complete owned receipt"): return {}
	return worker.paint_take_result()

func submit(values: Dictionary) -> Dictionary:
	var admitted: Dictionary = worker.paint_queue(request(values))
	if not check(admitted.get("status","") == "queued","real worker admitted request"):
		return admitted
	return await finished()

func fresh() -> bool:
	var old_generation: int = int(worker.paint_state().generation)
	var configuration: Dictionary = Setup.fresh(PackedInt32Array(workbench.applied.liquid_policy),Vector2i(512,512))
	if not check(workbench.apply(configuration),"fresh 512 native Workbench admitted"): return false
	return check(await wait_for(func()->bool:return ready() and int(worker.paint_state().generation)>old_generation),
		"fresh native World and workbench ready")

func square_cells(side: int, desired: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(side*side*3)
	for y: int in side:
		for x: int in side:
			var index: int = (y*side+x)*3
			cells[index] = x
			cells[index+1] = y
			cells[index+2] = desired
	return cells

func profile(result: Dictionary, kind: String, expected_cells: int) -> void:
	if not check(result.get("status","")=="completed",
			kind+" completed against real native world"): return
	check(int(result.get("requested_cells",-1)) == expected_cells,
		kind+" exact cell count")
	var witness: Dictionary = result.get("paint_throughput_profile",{})
	if not check(witness.get("schema","") == "paint-end2end-002-worker-profile-v1",
		kind+" complete opt-in worker profiling"): return
	check(str(witness.get("kind",""))==kind,kind+" profile kind matches")
	check(int(witness.get("executor_steps",-1))==int(result.get("slices",-2)),
		kind+" every bounded native step counted")
	check(int(witness.get("worker_cycles",0))>0,kind+" worker cycle count recorded")
	check(int(witness.get("max_chunks_per_cycle",0)) in range(1,9),
		kind+" hard maximum eight chunks per cycle")
	check(int(witness.get("worker_cpu_wall_usec",0))>=0,kind+" CPU work recorded")
	rows.append(witness)

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	var configured := maxi(1,int(OS.get_environment("CYBERSAND_PAINT_BURST_SLICES")))
	var source_sha := FileAccess.get_sha256("res://scripts/simulation_worker.gd")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	workbench=host.shared_workbench
	worker=host.simulation_worker
	if not check(workbench!=null and worker!=null,"real Workbench mounted"):
		quit(1)
		return
	if not check(await wait_for(ready,60000),"ordinary native Workbench ready"):
		quit(1)
		return
	if not await fresh():
		quit(1)
		return

	var maximum: int = 512*512
	var captured: Dictionary = await submit({"kind":"capture","region":Rect2i(0,0,512,512)})
	profile(captured,"capture",maximum)
	var values: PackedInt32Array = captured.get("materials",PackedInt32Array())
	check(values.size()==maximum and values.count(0)==maximum,
		"262k native source capture returned exact Empty IDs")
	var edited: Dictionary = await submit({"kind":"edit","cells":square_cells(512,58)})
	profile(edited,"edit",maximum)
	check(int(edited.get("applied",0))==maximum and int(edited.get("changed",0))==maximum,
		"262k stored native materials actually changed")
	check(edited.get("before",PackedInt32Array()).size()==maximum and
		edited.get("after",PackedInt32Array()).count(58)==maximum,
		"complete edit receipt has all exact before and after IDs")

	var refused: Dictionary = await submit({"kind":"edit",
		"cells":PackedInt32Array([1,1,2,2,1,2]),
		"protected":[Rect2i(2,1,1,1)]})
	check(refused.get("status","")=="refused" and int(refused.get("applied",-1))==0,
		"whole-request protected-source refusal remains atomic")

	if not await fresh():
		quit(1)
		return
	var cancellation_cells := square_cells(512,58)
	var first: Dictionary = worker.paint_queue(request({"kind":"edit","cells":cancellation_cells}))
	if check(first.get("status","")=="queued","preflight cancellation admitted"):
		worker.paint_stop()
		var stopped: Dictionary = await finished()
		check(stopped.get("status","")=="cancelled" and int(stopped.get("applied",-1))==0,
			"Stop before first write has no hidden material prefix")

	first = worker.paint_queue(request({"kind":"edit","cells":cancellation_cells}))
	if check(first.get("status","")=="queued","late cancellation admitted"):
		if check(await wait_for(func()->bool:return int(worker.paint_state().get("applied",0))>=4096,
			90000),"observe acknowledged native write prefix"):
			worker.paint_stop()
			var interrupted: Dictionary = await finished()
			var applied: int = int(interrupted.get("applied",0))
			check(interrupted.get("status","")=="partial" and applied>=4096 and applied<maximum,
				"late Stop reports exact bounded partial prefix")
			var inverse: PackedInt32Array = interrupted.get("cells",PackedInt32Array()).duplicate()
			var before: PackedInt32Array = interrupted.get("before",PackedInt32Array())
			var after: PackedInt32Array = interrupted.get("after",PackedInt32Array())
			if check(inverse.size()==applied*3 and before.size()==applied and after.size()==applied,
				"cancellation receipt exact prefix data"):
				for index: int in applied: inverse[index*3+2]=before[index]
				var undone: Dictionary=await submit({"kind":"edit","cells":inverse,"expected_before":after})
				check(undone.get("status","")=="completed" and int(undone.get("applied",0))==applied,
					"partial prefix recovers by exact reverse native edit")
				var after_recovery: Dictionary = await submit({"kind":"capture","region":Rect2i(0,0,512,512)})
				values=after_recovery.get("materials",PackedInt32Array())
				check(after_recovery.get("status","")=="completed" and values.size()==maximum and
					values.count(0)==maximum,"recovery has no hidden native edits")
	if source_sha != FileAccess.get_sha256("res://scripts/simulation_worker.gd"):
		check(false,"source changed during test")
	print("PAINT_BURST_PILOT ",JSON.stringify({"schema":"paint-end2end-002-pilot-v1",
		"source_sha256":source_sha,"mode_slices":configured,
		"checks":checks,"failures":failures,"profiles":rows}))
	host.queue_free()
	await process_frame
	quit(int(not failures.is_empty()))
