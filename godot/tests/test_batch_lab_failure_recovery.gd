extends SceneTree
## Genuine native acknowledgement with an injected deadline failure. The
## deadline injection is a control, never a native-throughput measurement.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
var controller: Node
var checks := 0
var failures: Array[String] = []
var evidence := ""

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("BATCH_RECOVERY_CHECK ",checks," ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func run() -> void:
	evidence = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	controller = Controller.new(); root.add_child(controller)
	await process_frame
	check(controller.configure_grid(1,1).ok,"isolated failure control grid")
	var config := Controller.defaults()
	config.extent=[512,512]; config.source_region=[0,0,512,512]; config.budget_cells=262144
	config.operations=[{"shape":"rectangle","x0":0,"y0":0,"x1":511,"y1":511,"material":58}]
	config["qualification_control"]="forced deadline after actual native chunk; injected clock offset excludes this result from performance analysis"
	check(controller.configure_tile(0,config).ok and controller.start().ok,"real native failure-control attempt queued")
	var owner: Node
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and controller.is_running():
		if controller._active.has(0) and controller._active[0].has("host") and not controller._active[0].has("initializing"):
			owner=controller._active[0].host
			if owner.phase=="drawing" and owner.executor.waiting:
				controller.set_process(false)
				break
		await process_frame
	if not check(owner!=null and owner.phase=="drawing" and owner.executor.waiting,"actual native chunk is in flight"):
		finish(); return
	while not owner.simulation_worker.art_state().get("receipt_ready",false) and Time.get_ticks_msec()<deadline: await process_frame
	if not check(owner.simulation_worker.art_state().get("receipt_ready",false),"actual native chunk has an unconsumed acknowledgement"):
		controller.set_process(true); finish(); return
	owner.phase_ms=Time.get_ticks_msec()-owner.OWNER_TIMEOUT_MS-1
	owner.poll()
	check(owner.phase=="capturing_result" and int(owner.result.get("changed",0))>0,"timeout drains genuine receipt and requests final native capture")
	controller.set_process(true)
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	check(not controller.is_running(),"timeout result retires recoverably")
	var tile: Dictionary = controller.tiles[0]
	var actual := 0
	for i: int in tile.material_cells.size()/2:
		if tile.material_cells.decode_u16(i*2)==58: actual+=1
	check(tile.state=="partial" and tile.material_cells.size()==512*512*2 and actual>0 and actual<512*512,"timeout retains complete native plane for its real partial prefix")
	var confirmed := 0
	for receipt: Dictionary in tile.receipts: confirmed+=int(receipt.changed)
	check(actual==confirmed and actual==int(tile.metrics.get("changed",0)),"UI counters, actual native receipts and full readback agree")
	check(tile.metrics.get("final_readback_available",false) and tile.material_sha256==Controller.TileHost.digest(tile.material_cells),"failure result carries truthful final-readback availability and digest")
	if not evidence.is_empty():
		check(controller.export_result(0,evidence.path_join("native-timeout-attempt.json")).ok,"original failure-control result retained")
	finish()

func finish() -> void:
	var summary := {"checks":checks,"failures":failures,"native_backend":"CyberNativeCellWorld",
		"control":"injected deadline after actual native acknowledgement; not a performance sample"}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("recovery-summary.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(summary,"  ")); file.close()
	print("BATCH_RECOVERY_RESULT ",JSON.stringify(summary))
	controller.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
