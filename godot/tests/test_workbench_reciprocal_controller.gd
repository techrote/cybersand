extends SceneTree

# Mechanical controller fixture only. It enters the private retained transaction
# seam with three known native cells; document.can_apply stays false throughout.
# This is NOT a native reciprocal generation or interactive Apply acceptance.
const Setup=preload("res://scripts/workbench_setup.gd")
const History=preload("res://scripts/workbench_paint_editor_history.gd")
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
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

func verify_art_admission()->bool:
	var source:=await capture()
	var cells:=PackedInt32Array([50,50,58])
	var staged:=History.prepare(bench.applied,cells,bench._generated_active,bench._material_baseline)
	if not check(staged.accepted,"a native patch can be staged before Art admission"): return false
	panel._capture=source
	panel.prepared={"guards":PackedInt32Array()}
	panel.proposal={"proposal_sha256":"4".repeat(64)}
	var patch:Dictionary=panel._patch("build",cells,PackedInt32Array([0]))
	var art:RefCounted=bench._ensure_art_batches().executor
	var submitted:Dictionary=art.submit([{"shape":"pixels","material":58,"points":[[84,84]]}],Rect2i(84,84,1,1),[],[58])
	if not check(submitted.status=="queued" and art.active,"Art holds a real admitted writer before its first native chunk"): return false
	if not check(not panel._request_capture("generate") and not panel._submit(staged.setup,patch,"build")
			and art.active and not art.stopping and host.pending_microscenario_apply.is_empty(),
			"reciprocal capture and submission preserve the pending Art operation"): return false
	if not await until(func()->bool:return not art.active,"independent Art writer settles"): return false
	var after:=await capture()
	if not check(art.result.status=="completed" and int(art.result.changed)==1
			and after.cells.decode_u16((84*512+84)*2)==58 and after.cells.decode_u16((50*512+50)*2)==0,
			"original Art write is acknowledged and refused reciprocal patch makes no native change"): return false
	panel.invalidate("Art edit completed.")
	return true

func exercise()->void:
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"finite fixture blank source admitted"):return
	if not await until(settled,"fixture source installed"):return
	bench.open_reciprocal();panel=bench.reciprocal_panel
	if not await verify_art_admission(): return
	var baseline:=await capture()
	check(not panel.gentek_controls.frame.enabled.button_pressed and not panel.gentek_controls.mosaic.enabled.button_pressed \
		and not panel.controls.shared_ownership.button_pressed,"new owner controls use the selected fixed-territory default")
	# Exercise retained V1 compatibility explicitly; it is no longer the dock default.
	panel.controls.shared_ownership.button_pressed=true
	panel.activation.assign([Vector2i(64,48)])
	var linked_recipe:Dictionary=panel._recipe()
	var linked:Dictionary=Protocol.prepare(linked_recipe,baseline)
	check(linked.ok and linked.text.begins_with("SWARM004 1\n"),"explicit legacy shared controls retain the original native request protocol")
	panel.gentek_controls.frame.enabled.button_pressed=true
	check(panel.gentek_controls.frame.values.destruction.value==panel.controls.destruction.value \
		and panel.gentek_controls.frame.values.clutter.value==panel.controls.clutter.value,
		"enabling independent controls copies separate decoration and destruction without coupling them")
	panel.gentek_controls.frame.values.branching.value=0.05
	var independent:Dictionary=panel._recipe()
	check(independent.gentek_parameters.frame.branching==0.05 and independent.parameters.branching==linked_recipe.parameters.branching \
		and not independent.gentek_parameters.has("mosaic"),"FRAME override leaves shared and MOSAIC controls unchanged")
	panel.controls.shared_ownership.button_pressed=false
	var fixed:Dictionary=Protocol.prepare(panel._recipe(),baseline)
	check(fixed.ok and fixed.text.begins_with("SWARM004 2\n") and fixed.interface==linked.shared and not 1 in fixed.shared \
		and fixed.frame_eligible==linked.frame_eligible and fixed.mosaic_eligible==linked.mosaic_eligible,
		"fixed territory disables shared ownership without erasing transition hints or changing masks")
	panel.gentek_controls.frame.enabled.button_pressed=false;panel.controls.shared_ownership.button_pressed=true
	check(Protocol.prepare(panel._recipe(),baseline).text==linked.text,"returning to linked controls restores exact original request bytes")
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
	# A previous, genuine controller Undo receipt cannot be reused while a saved
	# inspection owns the panel. This is a negative authority-seam check, not a
	# fabricated native-positive composition.
	panel._historical_only=true;panel.proposal["historical_only"]=true
	panel._refresh()
	check(panel._apply.disabled and panel._undo_button.disabled,"historical authority disables Apply and an otherwise available live Undo")
	check(not panel.undo_construction() and not panel._submit(staged.setup,panel._patch("build",cells,panel.proposal.before),"build")
		and panel.phase=="installed","historical authority refuses Undo and direct transaction submission before changing phase")
	panel.phase="submitting";panel._pending_setup=staged.setup;panel._pending_patch={"operation":"build"}
	check(not panel.attests(panel._pending_setup,panel._pending_patch),"matching pending fields cannot attest through historical authority")
	panel.phase="installed";panel._pending_setup={};panel._pending_patch={}
	panel.invalidate("mechanical historical invalidation")
	check(panel._read_only_evidence() and panel.proposal.is_empty() and panel._undo_button.disabled,
		"cancel and control invalidation cannot discard the historical authority latch")
	check(not panel.undo_construction() and (await capture()).cells==expected and bench.applied.edits==staged.setup.edits,
		"historical refusals retain the exact native plane and settled authored history")
	# Restore this private mechanical fixture's original authority to finish its
	# independent Undo seam test. Production clears the latch only after Generate.
	panel._historical_only=false
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
