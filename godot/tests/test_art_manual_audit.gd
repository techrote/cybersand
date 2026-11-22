extends SceneTree
## Real native Direct JSON audit: overlap, Stop, and orderly close.
## This runs inside an isolated Godot user-data root; no model provider is used.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_MANUAL_AUDIT_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func read_events(path: String, kind: String) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(path): return result
	for line: String in FileAccess.get_file_as_string(path).split("\n",false):
		var value: Variant = JSON.parse_string(line)
		if value is Dictionary and value.get("kind","") == kind:
			result.append(value.get("data",{}))
	return result

func wait_for_world(host: Control) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		var wb: Control = host.shared_workbench
		if not wb.applied.is_empty() and not wb.busy() and wb.paint_editor != null and not wb.paint_editor.busy() and host.pending_microscenario_apply.is_empty():
			return true
		await process_frame
	return false

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	var host: Control = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await wait_for_world(host):
		check(false,"native Workbench installed")
		quit(1)
		return
	var panel: Window = host.shared_workbench._ensure_art_batches()
	panel.input_mode.select(0)
	var extent: Vector2i = host.shared_workbench.Setup.extent_of(host.shared_workbench.applied)
	var side: int = mini(512,mini(extent.x,extent.y))
	check(side >= 256,"large native fixture footprint available")
	panel.fields[0].value = 0
	panel.fields[1].value = 0
	panel.fields[2].value = side
	panel.fields[3].value = side
	panel.input.text = JSON.stringify([{"shape":"rectangle","x0":8,"y0":8,
		"x1":side-9,"y1":side-9,"material":58}])
	panel.submit_text()
	var first_submission: int = panel._manual_active_submission
	var first_batch: int = panel._manual_active_batch_sequence
	check(panel._manual_log_pending and panel.executor.active and first_submission > 0 and first_batch > 0,
		"initial Direct JSON run is queued with a stable audit identity")
	var log_path: String = str(panel.provider.log_path)
	check(not log_path.is_empty(),"Direct JSON creates the one-session audit")
	panel.submit_text()
	check(panel._manual_log_pending and panel._manual_active_submission == first_submission
		and panel._manual_active_batch_sequence == first_batch and panel.executor.batch_sequence == first_batch,
		"overlapping Draw refusal never retires the first batch or changes its identity")
	var admissions: Array = read_events(log_path,"manual_admission")
	check(admissions.size() == 2 and int(admissions[0].get("batch_sequence",-1)) == first_batch
		and str(admissions[0].get("result",{}).get("status","")) == "queued"
		and str(admissions[1].get("result",{}).get("status","")) == "refused",
		"queued and rejected submissions have distinct admission records")
	panel.stop_all("Review fixture Stop")
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and (panel.executor.active or panel._manual_log_pending):
		await process_frame
	check(not panel.executor.active and not panel._manual_log_pending,
		"Stop settles to a native terminal outcome and emits audit")
	var results: Array = read_events(log_path,"manual_result")
	check(results.size() == 1 and int(results[0].get("submission_id",-1)) == first_submission
		and int(results[0].get("batch_sequence",-1)) == first_batch
		and bool(results[0].get("native_terminal",false))
		and str(results[0].get("audit_state","")) == "terminal",
		"only the admitted batch gets a terminal result; rejected overlap cannot erase it")
	check(str(results[0].get("result",{}).get("status","")) in ["cancelled","partial","completed","refused"],
		"native outcome is recorded instead of invented from queued status")
	# A second genuine native submission must not depend on the old audit state.
	panel.submit_text()
	var closing_submission: int = panel._manual_active_submission
	var closing_batch: int = panel._manual_active_batch_sequence
	check(panel._manual_log_pending and panel.executor.active and closing_batch > first_batch,
		"fresh manual batch queued for shutdown qualification")
	host.queue_free()
	await process_frame
	await process_frame
	results = read_events(log_path,"manual_result")
	check(results.size() == 2 and int(results[1].get("submission_id",-1)) == closing_submission
		and int(results[1].get("batch_sequence",-1)) == closing_batch,
		"orderly game shutdown records an outcome for the in-flight batch")
	check(str(results[1].get("audit_state","")) == "shutdown_cancel_requested_unconfirmed"
		and not bool(results[1].get("native_terminal",true))
		and str(results[1].get("result",{}).get("status","")) != "completed",
		"shutdown audit explicitly refuses to claim unacknowledged native completion")
	check(read_events(log_path,"manual_admission").size() == 3 and read_events(log_path,"manual_program").size() == 3,
		"all three submissions retained in the same independent JSONL")
	print("ART_MANUAL_AUDIT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"log":log_path}))
	quit(0 if failures.is_empty() else 1)
