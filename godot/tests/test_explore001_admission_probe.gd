extends SceneTree

# One-off source-equivalent Godot 4.7 repro probe, not product behaviour.
# Every checkpoint is printed before the next potentially blocking operation.
const Setup = preload("res://scripts/workbench_setup.gd")
var host: Control
var panel: Control
var dialog: ConfirmationDialog
var failed := false
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func mark(label: String, data: Variant = {}) -> void:
	print("EXPLORE001_PROBE ",label," ",JSON.stringify(data))

func poll(predicate: Callable, label: String, max_ms: int = 25000) -> bool:
	var begun: int = Time.get_ticks_msec()
	var previous: int = begun
	while Time.get_ticks_msec()-begun < max_ms:
		if predicate.call():
			mark("PASS "+label,{"elapsed_ms":Time.get_ticks_msec()-begun})
			return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed():
			mark("WORKER_FAILED "+label,{"elapsed_ms":Time.get_ticks_msec()-begun})
			break
		if Time.get_ticks_msec()-previous > 2000:
			previous=Time.get_ticks_msec()
			mark("HEARTBEAT "+label,{"elapsed_ms":previous-begun,"pending":host.pending_microscenario_apply.size() if host != null else -1,
				"phase":str(dialog._phase) if dialog != null else "none"})
		await process_frame
	mark("TIMEOUT "+label,{"elapsed_ms":Time.get_ticks_msec()-begun,"host_error":str(host.microscenario_error) if host!=null else "none"})
	failed=true
	return false

func _run() -> void:
	mark("BEGIN",{"os":OS.get_name(),"godot":Engine.get_version_info().string})
	change_scene_to_file("res://feature_launcher.tscn")
	mark("LAUNCHER_REQUEST")
	await scene_changed
	mark("LAUNCHER_READY")
	current_scene.launch("shared_workbench")
	mark("WORKBENCH_REQUEST")
	await scene_changed
	host=current_scene
	panel=host.shared_workbench
	if panel == null:
		mark("FAIL no shared workbench")
		quit(1)
		return
	mark("WORKBENCH_MOUNTED",{"pending":host.pending_microscenario_apply.size(),"generator_ui":panel._generated_dialog!=null})
	dialog=panel._generated_dialog
	var ok: bool = await poll(func() -> bool:
		return not panel.applied.is_empty() and host.pending_microscenario_apply.is_empty() and not panel.busy(),"blank World acknowledgment",30000)
	if not ok:
		quit(1)
		return
	var recipe: Dictionary={"schema":1,"seed":917,"chunk_size":64,"candidate":"strata",
		"parameters":{"surface_y":0,"relief":0,"fluid_level":64},
		"themes":{"weights":{"basalt":1},"exclude":[]},
		"overrides":[{"id":"water","bounds":[320,420,150,56],"material":3},
			{"id":"floor","bounds":[304,620,464,18],"material":58}]}
	mark("DIALOG_OPEN_REQUEST")
	dialog.open_new()
	dialog._saved_recipe=recipe
	dialog._extent.select(0)
	dialog._x.set_value_no_signal(256)
	dialog._y.set_value_no_signal(256)
	mark("GENERATION_BEGIN")
	dialog._start()
	if not await poll(func() -> bool: return dialog._phase=="ready" or dialog._status.text.begins_with("Refused"),
		"512 generation native proposal",30000):
		mark("GENERATION_TIMEOUT",{"phase":dialog._phase,"status":dialog._status.text})
		quit(1)
		return
	if dialog._phase!="ready":
		mark("GENERATION_REFUSED",{"phase":dialog._phase,"status":dialog._status.text})
		quit(1)
		return
	var proposal: Dictionary=dialog._ready_packet.duplicate(true)
	mark("GENERATION_READY",{"width":proposal.extent.x,"bytes":proposal.cells.size(),"digest":proposal.sha256,
		"receipts":proposal.receipt_hashes.size()})
	var candidate: Dictionary=Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	var prev_epoch:int=host._physical_epoch
	var prev_generation:int=host.last_uploaded_world_generation
	mark("WORKBENCH_PREPARE_REQUEST",{"old_epoch":prev_epoch,"old_generation":prev_generation})
	var requested:bool=panel.install_generated_start(candidate,proposal)
	mark("WORKBENCH_PREPARE_RETURN",{"requested":requested,"status":panel.message,"host_error":host.microscenario_error,
		"pending":host.pending_microscenario_apply.size()})
	dialog.hide()
	if not requested:
		quit(1)
		return
	ok=await poll(func() -> bool: return host.pending_microscenario_apply.is_empty(),"prepared owner resolved",30000)
	mark("WORKBENCH_OWNER_RESULT",{"pending":host.pending_microscenario_apply.size(),"epoch":host._physical_epoch,
		"message":panel.message,"host_error":host.microscenario_error,
		"active_source_sha256":str(panel._generated_active.get("sha256",""))})
	if not ok or host._physical_epoch==prev_epoch or panel._generated_active.get("sha256","")!=proposal.sha256:
		mark("INSTALL_REFUSED_OR_STALE")
		quit(1)
		return
	ok=await poll(func() -> bool:
		return host.last_uploaded_world_generation>prev_generation and host.image.get_width()==512,
		"new 512 owner material publication",30000)
	mark("DONE",{"ok":ok,"elapsed_ms":Time.get_ticks_msec(),"native_worker_failed":host.simulation_worker.has_failed()})
	host.queue_free()
	await process_frame
	quit(1 if failed or not ok else 0)
