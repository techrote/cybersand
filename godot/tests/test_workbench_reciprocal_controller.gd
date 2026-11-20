extends SceneTree

# Mechanical controller fixture only. It enters the private retained transaction
# seam with three known native cells; document.can_apply stays false throughout.
# This is NOT a native reciprocal generation or interactive Apply acceptance.
const Setup=preload("res://scripts/workbench_setup.gd")
const History=preload("res://scripts/workbench_paint_editor_history.gd")
var host:Control
var bench:Control
var panel:Control
var checks:=0
var failures:Array[String]=[]
var completed:=false
var saved_path:=""

func _initialize()->void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value:bool,label:String)->bool:
	checks+=1
	if not value:failures.append(label);push_error("SWARM004_CONTROLLER "+label)
	return value

func until(predicate:Callable,label:String)->bool:
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await process_frame
	return check(false,label)

func settled()->bool:
	return not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func capture()->Dictionary:
	var state:Dictionary=host.simulation_worker.paint_state()
	var admitted:Dictionary=host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not check(admitted.get("ok",false),"independent native capture admitted"):return {}
	var result:Dictionary={};var deadline:=Time.get_ticks_msec()+15000
	while result.is_empty() and Time.get_ticks_msec()<deadline:
		result=host.simulation_worker.material_capture_poll(int(admitted.token));await process_frame
	var released:Dictionary=host.simulation_worker.material_capture_finish(int(admitted.token),false)
	check(result.get("ok",false) and released.get("ok",false),"native capture completed and lease released")
	return result

func exercise()->void:
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"finite fixture blank source admitted"):return
	if not await until(settled,"fixture source installed"):return
	var baseline:=await capture()
	bench.open_reciprocal();panel=bench.reciprocal_panel
	panel.document={"can_apply":false}
	check(not panel.apply_construction(),"ordinary Apply refuses the unqualified mechanical fixture")
	check((await capture()).cells==baseline.cells,"refused ordinary Apply makes no native write")
	var cells:=PackedInt32Array([50,50,58,51,50,43,52,50,13])
	var staged:=History.prepare(bench.applied,cells,bench._generated_active,bench._material_baseline)
	if not check(staged.accepted,"existing authored history helper stages the three known native materials"):return
	var old_history:Array=bench.applied.edits.duplicate(true)
	panel._capture=baseline;panel._pending_before_edits=old_history.duplicate(true)
	panel.proposal={"cells":cells,"before":PackedInt32Array([0,0,0]),"proposal_sha256":"1".repeat(64)}
	panel.prepared={"guards":PackedInt32Array(),"request_sha256":"2".repeat(64),"recipe":{"layout":"left_right","border":0}}
	panel._runtime={"source":"mechanical-controller-fixture-only","sha256":"3".repeat(64)}
	panel._job_dir=ProjectSettings.globalize_path("user://swarm004/controller-fixture-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(panel._job_dir)
	var file:=FileAccess.open(panel._job_dir+"/result.json",FileAccess.WRITE)
	file.store_string('{"scope":"mechanical fixture only; not generated architecture","can_apply":false}');file.close()
	if not check(panel._submit(staged.setup,panel._patch("build",cells,panel.proposal.before),"build"),"private mechanical transaction seam submits the tested native patch"):return
	check(bench.applied.edits==old_history,"history is unchanged before native acknowledgement")
	if not await until(func()->bool:return panel.completed_applies==1,"mechanical transaction acknowledged"):return
	var expected:PackedByteArray=baseline.cells.duplicate()
	for at:int in range(0,cells.size(),3):expected.encode_u16((cells[at+1]*512+cells[at])*2,cells[at+2])
	check((await capture()).cells==expected,"private seam installs exactly all three native cells")
	check(bench.applied.edits==staged.setup.edits,"acknowledgement adopts the complete staged history once")
	check(panel.document.can_apply==false,"native reciprocal Apply authority was never fabricated")
	# This fixture is not a native assembly receipt; do not attach it to a map.
	panel._accepted.clear()
	bench._name.text="swarm004-controller-fixture-%d" % OS.get_process_id()
	saved_path=Setup._path(bench._name.text)
	check(bench.save_setup(),"ordinary Save accepts acknowledged mechanical history")
	var saved:=Setup.read_named(bench._name.text)
	check(not saved.has("error") and saved.setup.edits==staged.setup.edits,"saved map has exact staged native cell stamps")
	# A changed preview must not substitute its identity/guards in construction Undo.
	panel.prepared={"guards":PackedInt32Array([50,50]),"request_sha256":"4".repeat(64)}
	panel.proposal={"proposal_sha256":"5".repeat(64),"cells":PackedInt32Array(),"before":PackedInt32Array()}
	if not check(panel.undo_construction(),"inverse uses its own receipt despite a different provisional preview"):return
	if not await until(func()->bool:return panel.completed_undos==1,"fresh inverse native transaction acknowledged"):return
	check((await capture()).cells==baseline.cells and bench.applied.edits==old_history,"Undo exactly restores native cells and prior history")
	check(panel.last_receipt.proposal_sha256=="1".repeat(64),"Undo keeps the applied construction identity")
	if not check(bench.load_setup(),"ordinary saved map is admitted again"):return
	if not await until(settled,"saved mechanical setup installed"):return
	check((await capture()).cells==expected,"ordinary map reconstruction reproduces exact native materials")
	completed=true

func run()->void:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate();root.add_child(host);bench=host.shared_workbench
	if await until(settled,"Main and native worker initialized"):await exercise()
	check(completed,"complete controller-only sequence reached its final assertion")
	if host!=null:host.queue_free();await process_frame;await process_frame
	if not saved_path.is_empty():DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	print("SWARM004_CONTROLLER ",JSON.stringify({"checks":checks,"failures":failures,"completed":completed,
		"reciprocal_acceptance":false,"scope":"private mechanical transaction/history/Undo/Save seam; can_apply=false"}))
	quit(0 if failures.is_empty() else 1)
