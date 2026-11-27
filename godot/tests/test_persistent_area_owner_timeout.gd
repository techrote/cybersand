extends SceneTree

# Real Main/native owner regression for a late capture completion. The marker
# is emitted only after the timed-out operation is retired, the original
# unsaved material edit is retained and a fresh durable Save succeeds.
const PersistentScene = preload("res://persistent_areas.tscn")
const DelayedWorker = preload("res://tests/persistent_area_delayed_worker.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var host: Control
var controller: Node
var bench: Control
var worker: RefCounted
var output := ""
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {}


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--persistent-evidence="):
			output = argument.trim_prefix("--persistent-evidence=")
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GEN006_OWNER_TIMEOUT: "+label)
	return ok


func until(predicate: Callable, label: String, timeout_msec: int = 30000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_msec
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(predicate.call(),label)


func settled() -> bool:
	return controller != null and controller.active_ready and not controller.busy \
		and host.pending_microscenario_apply.is_empty() and not bench.busy() \
		and not worker.paint_state().get("busy",false) and not worker.paint_state().get("legacy_busy",false)


func run() -> void:
	if not check("--persistent-start-paused" in OS.get_cmdline_user_args(),"explicit paused qualification profile"):
		await finish()
		return
	host = PersistentScene.instantiate()
	host.simulation_worker = DelayedWorker.new(false)
	root.add_child(host)
	current_scene = host
	controller = host.persistent_areas
	bench = host.shared_workbench
	worker = host.simulation_worker
	if not await until(func() -> bool: return not controller.busy,"real native profile initialization finishes",180000):
		await finish()
		return
	if not check(controller.active_ready,"real native profile is active: "+str(controller.message)):
		await finish()
		return
	if not await until(settled,"paused native authoring boundary"):
		await finish()
		return
	controller.qualification_measurement_tag = "owner_timeout_fault"
	await exercise_timeout()
	controller.qualification_measurement_tag = ""
	await finish()


func exercise_timeout() -> void:
	var point := Vector2i(480,72)
	var original_material := await native_cell(point)
	if not check(original_material == 0,"chosen unsaved edit starts as actual Empty material"): return
	var durable_before: Dictionary = controller.manifest.areas[controller.active_area].duplicate(true)
	var revision_before := int(controller.manifest.revision)
	if not check(bench.paint(point,Setup.WALL),"ordinary material authoring admits an unsaved Wall edit"): return
	if not await until(settled,"unsaved material edit reaches native owner"): return
	check(await native_cell(point)==Setup.WALL,"unsaved edit exists in actual native cells")
	# Capture an exact reference without publishing it. This retains the old
	# durable checkpoint, so a mistaken restore during Retry is detectable.
	controller._begin("qualification_reference",controller.active_area)
	var reference: Dictionary = await controller._capture_live()
	if not check(reference.get("ok",false),"full native reference capture succeeds"):
		await controller._fail(str(reference.get("error","reference capture failed")))
		return
	var expected: Dictionary = reference.result.capsule
	await controller._finish("Qualification reference captured without saving.")
	check(controller.manifest.revision==revision_before,"reference capture does not publish unsaved edits")
	check(expected.physical_hash!=durable_before.physical_hash,"unsaved edit changes full native physical identity")
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before_authoring: Dictionary = host.persistent_authoring_state()
	worker.qualification_delay_next_capture = true
	var started := Time.get_ticks_msec()
	if not check(controller.request_save(),"real Save capture starts before injected 31.5 s owner delay"): return
	if not await until(func() -> bool: return not controller.busy,"native capture reaches its real host deadline",45000): return
	report.timeout_elapsed_msec = Time.get_ticks_msec()-started
	report.after_timeout = controller.status()
	check(report.timeout_elapsed_msec>=30000,"test exercised the production thirty-second deadline")
	check(not controller.active_ready and controller._quarantined and host.paused,
		"timeout keeps the retained live World paused and visibly quarantined")
	var unresolved: Dictionary = controller._unresolved_worker.duplicate(true)
	if not check(int(unresolved.get("token",0))>0 and unresolved.get("kind","")=="capture",
		"exact capture token and operation identity remain unresolved"): return
	var token := int(unresolved.token)
	var pending: Dictionary = worker.persistent_poll(token)
	check(pending.get("status","")=="pending" and pending.get("lease_held",false) \
		and pending.get("operation_id","")==unresolved.operation_id,"native pending request retains that same actual lease")
	check(not controller.request_save() and not controller.request_travel("b"),"new writes and travel refuse while owner completion is unknown")
	check(not controller.request_exit("launcher"),"leaving cannot discard an unresolved owner")
	if not check(controller.request_retry(),"Retry remains accessible while the old native request is pending"): return
	if not await until(func() -> bool: return not controller.busy,"pending Retry is bounded",1000): return
	check(not controller.active_ready and controller._unresolved_worker==unresolved and host.paused,
		"early Retry keeps the same token and never invents native cancellation")
	if not await until(func() -> bool: return worker.persistent_poll(token).get("status","")!="pending",
		"the actual delayed native capture completes",10000): return
	var completed: Dictionary = worker.persistent_poll(token)
	if not check(completed.get("ok",false) and completed.get("status","")=="complete","late native capture has a positive completion"): return
	var late: Dictionary = completed.result.capsule
	check(late.sha256==expected.sha256 and late.physical_hash==expected.physical_hash \
		and late.completed_tick==expected.completed_tick,"late capture preserves exact native bytes, hash and completed tick")
	if not check(controller.request_retry(),"Retry consumes the completed original operation"): return
	if not await until(settled,"same-operation cleanup restores normal live editing",10000): return
	check(controller.last_result.get("ok",false) and not controller._lease_held \
		and controller._unresolved_worker.is_empty() and not controller._owner_cleanup_required,
		"native release is acknowledged before controller becomes active")
	var released: Dictionary = worker.persistent_poll(int(worker._persistent_sequence))
	check(released.get("status","")=="complete" and not released.get("lease_held",true),
		"matching native completion confirms no stranded owner lease")
	check(controller.clock==before_clock and int(worker.paint_state().tick)==int(expected.completed_tick),
		"retry neither loses native time nor credits the interval twice")
	check(host.persistent_authoring_state()==before_authoring,"retry retains the unsaved authored definition and editing state")
	check(await native_cell(point)==Setup.WALL,"retry retains the unsaved actual native edit instead of loading the older checkpoint")
	check(controller.manifest.revision==revision_before,"owner recovery alone does not publish or replace the durable area")
	if not check(controller.request_save(),"a new Save is admitted after the old owner retires"): return
	if not await until(settled,"new Save completes normally",30000): return
	check(controller.last_result.get("ok",false),"new Save receives positive durable acknowledgement")
	check(controller.manifest.areas[controller.active_area].physical_hash==expected.physical_hash \
		and int(controller.manifest.areas[controller.active_area].completed_tick)==int(expected.completed_tick),
		"new durable checkpoint has the original unsaved native hash and tick")
	check(controller.clock==before_clock,"successful retry Save introduces no duplicated game time")
	report.reference = {"sha256":expected.sha256,"physical_hash":expected.physical_hash,"completed_tick":expected.completed_tick}
	report.after_recovery = controller.status()
	report.native_generation = int(worker.paint_state().generation)
	report.final_revision = controller.manifest.revision


func native_cell(point: Vector2i) -> int:
	if not await until(settled,"native material readback boundary"): return -1
	var source: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":Rect2i(point,Vector2i.ONE),
		"expected_generation":int(source.generation),"expected_revision":int(source.revision),"expected_tick":int(source.tick),
		"expected_authoring_generation":int(source.authoring_generation)})
	if not check(admitted.get("status","")=="queued","actual stored-cell readback admitted"): return -1
	if not await until(func() -> bool: return worker.paint_state().get("receipt_ready",false),"stored-cell readback completes"): return -1
	var receipt: Dictionary = worker.paint_take_result()
	if not check(receipt.get("status","")=="completed" and receipt.get("materials",PackedInt32Array()).size()==1,
		"actual stored-cell readback has one validated material"): return -1
	return int(receipt.materials[0])


func finish() -> void:
	if controller != null: report["performance_evidence"] = controller.evidence()
	if controller != null and worker != null:
		if controller.active_ready and not controller.busy:
			if check(controller.request_exit("launcher"),"durable test exit admitted"):
				await until(func() -> bool: return current_scene!=null and current_scene.scene_file_path=="res://feature_launcher.tscn",
					"durable test exit acknowledged",30000)
		else:
			worker.stop_worker()
			await controller._io("close_profile",[])
	report.merge({"schema":1,"checks":checks,"failures":failures.size(),"errors":failures,
		"graphical":DisplayServer.get_name()!="headless","process_id":OS.get_process_id(),"godot":Engine.get_version_info()},true)
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("owner-timeout.json"),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report,"  "))
			file.close()
		else:
			check(false,"owner timeout evidence can be written")
	print("GEN006_OWNER_TIMEOUT ",JSON.stringify({"checks":checks,"failures":failures.size(),
		"graphical":DisplayServer.get_name()!="headless","process_id":OS.get_process_id(),
		"native_generation":report.get("native_generation",-1)}))
	quit(0 if failures.is_empty() else 1)
