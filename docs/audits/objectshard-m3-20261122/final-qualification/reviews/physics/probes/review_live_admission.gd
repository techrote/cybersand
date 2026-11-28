extends SceneTree

var scene
var checks: int = 0
var failures: int = 0
var evidence: Array[Dictionary] = []

func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")

func _expect(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks += 1
	evidence.append({"check": label, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		push_error(label + " " + JSON.stringify(detail))

func _idle() -> bool:
	var until: int = Time.get_ticks_msec() + 30000
	await process_frame
	while Time.get_ticks_msec() < until:
		if scene.host.failed or scene.setup_failed:
			return false
		if not scene.loading and not scene.replacing_owner and scene.host.state == "Idle" and scene.host.actions.is_empty() and scene.queued_cuts.is_empty() and not scene.host._tick_requested:
			return true
		await process_frame
	return false

func _manual_idle() -> bool:
	var until: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < until:
		scene.host.poll()
		scene.host.pump_receipts(4000)
		if scene.host.failed:
			return false
		if scene.host.state == "Idle" and scene.host.actions.is_empty() and scene.host.pending.is_empty() and not scene.host._tick_requested:
			return true
		await process_frame
	return false

func _pointer(position: Vector2i) -> void:
	var down := InputEventMouseButton.new()
	down.position = scene.view.offset + (Vector2(position) + Vector2.ONE * 0.5) * scene.view.zoom
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	scene.view._gui_input(down)
	down.pressed = false
	scene.view._gui_input(down)

func _run() -> void:
	scene = load("res://object_shard_worker_rehearsal.tscn").instantiate()
	root.add_child(scene)
	_expect(await _idle(), "real scene completes native setup")
	if scene.host.failed:
		await _finish()
		return
	await _timestamp_backpressure()
	scene.set_process(true)
	_expect(await _idle(), "scene resumes after independent input-clock probe")
	scene._cut_support()
	_expect(await _idle(), "actual support tool executes ordinary native erasures")
	for attempt: int in range(12):
		if not scene.host.bridge.bodies.is_empty():
			break
		scene._single_step()
		if not await _idle():
			break
	_expect(scene.host.bridge.bodies.size() == 1 and not scene.host.failed, "actual awake shard is promoted for continuous admission test")
	if scene.host.bridge.bodies.is_empty() or scene.host.failed:
		await _finish()
		return
	for budget: int in [0, 4000]:
		await _live_cut(budget)
	await _finish()

func _timestamp_backpressure() -> void:
	scene.set_process(false)
	for index: int in range(32):
		var queued: Dictionary = scene.host.queue_action("edit", {"position": Vector2i(10 + index, 18), "material": 2})
		if not queued.get("ok", false):
			_expect(false, "fill actual host queue", queued)
			return
	_expect(scene.host.actions.size() == 32, "host admission pressure is real and bounded")
	scene.brush_select.select(2)
	_pointer(Vector2i(80, 18))
	_expect(scene.queued_cuts.size() == 1, "actual pointer handler captures one UI intent before host admission")
	var captured: int = int(scene.queued_cuts[0].input_usec)
	var exact_target: Dictionary = scene.queued_cuts[0].parameters.target.duplicate(true)
	scene._dispatch_pointer_intents()
	_expect(scene.queued_cuts.size() == 1 and int(scene.queued_cuts[0].input_usec) == captured and scene.queued_cuts[0].parameters.target == exact_target,
		"backpressure preserves the original timestamp and exact target")
	var wait_until: int = Time.get_ticks_usec() + 25000
	while Time.get_ticks_usec() < wait_until:
		await process_frame
	scene.host.poll(false)
	scene._dispatch_pointer_intents()
	_expect(scene.queued_cuts.is_empty() and scene.host.actions.size() == 32, "one real queue slot admits the retained pointer")
	var retained: Dictionary = scene.host.actions[-1].duplicate(true)
	var admission_delay: int = int(retained.admitted_usec) - captured
	_expect(int(retained.captured_usec) == captured and retained.input_observation == "scene_intent" and admission_delay >= 20000,
		"host receives actual original-input time including the UI wait", {"admission_delay_usec": admission_delay})
	var id: int = int(retained.action_id)
	_expect(await _manual_idle(), "all real queued native edits complete")
	var result: Dictionary = scene.host.action_results[-1]
	_expect(int(result.action_id) == id and result.ok and int(result.captured_usec) == captured and int(result.admitted_usec) == int(retained.admitted_usec),
		"terminal result retains both clocks without rewriting original input time")
	for stage: String in ["result", "publication"]:
		var enclosing: int = int(scene.host.timings["input_to_" + stage + "_usec"][-1])
		var host_only: int = int(scene.host.timings["host_admission_to_" + stage + "_usec"][-1])
		_expect(enclosing - host_only == admission_delay, "input-to-" + stage + " includes exactly the retained UI delay", {"original_input_usec": enclosing, "host_admission_usec": host_only})
	var rows_before: int = scene.host.actions.size()
	var future: Dictionary = scene.host.queue_action("edit", {"position": Vector2i(82, 18), "material": 2}, Time.get_ticks_usec() + 1000000)
	var negative: Dictionary = scene.host.queue_action("edit", {"position": Vector2i(82, 18), "material": 2}, -1)
	_expect(future.get("outcome") == "InvalidInputObservationTime" and negative.get("outcome") == "InvalidInputObservationTime" and scene.host.actions.size() == rows_before,
		"invalid observational clocks cannot enter the material queue")
	scene.view.present(scene.host.publication, [])
	scene.last_publication = scene.host.publication_sequence
	scene._mark_visible(scene.host, scene.last_publication)
	await process_frame
	_expect(DisplayServer.get_name() == "headless" and not scene.host.timings.has("input_to_presented_usec"),
		"headless scene does not fabricate a real rendered-frame timing receipt")

func _owned_point() -> Dictionary:
	for shard: Dictionary in scene.view.frame.get("shards", []):
		if not shard.get("owns_inventory", false):
			continue
		var pose := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		for cell: int in range(shard.materials.size()):
			if int(shard.roles[cell]) != 1:
				continue
			var center: Vector2 = pose * (Vector2(cell % int(shard.width), cell / int(shard.width)) + Vector2.ONE * 0.5)
			var point := Vector2i(floori(center.x), floori(center.y))
			var target: Dictionary = scene.host.capture_target(point, scene.view.frame)
			if int(target.get("owner", 0)) == int(shard.id) and int(target.get("cell", -1)) == cell:
				return {"position": point, "id": shard.id, "structural": shard.structural, "target": target}
	return {}

func _inventory(id: int) -> int:
	for shard: Dictionary in scene.host.publication.get("shards", []):
		if int(shard.id) == id:
			return int(shard.structural)
	return -1

func _live_cut(budget: int) -> void:
	scene._select_receipt_pump(0 if budget == 0 else 1)
	var initial: Dictionary = _owned_point()
	_expect(not initial.is_empty() and scene.receipt_pump_usec == budget, "a displayed owner starts the chosen actual receipt-pump mode", {"pump_usec": budget})
	if initial.is_empty():
		return
	var before: int = scene.host.completed_ticks
	var old_inventory: int = _inventory(int(initial.id))
	var attempts: int = 0
	var awake: bool = false
	var until: int = Time.get_ticks_msec() + 20000
	scene._toggle_run()
	scene.brush_select.select(0)
	while Time.get_ticks_msec() < until and not scene.host.failed and _inventory(int(initial.id)) == old_inventory:
		for body: Dictionary in scene.host.bridge.diagnostics().bodies:
			if int(body.id) == int(initial.id) and not body.sleeping and Vector2(body.vx, body.vy).length() > 0.1:
				awake = true
		if awake and scene.queued_cuts.is_empty() and scene.host.actions.is_empty() and attempts < 64:
			var current: Dictionary = _owned_point()
			if not current.is_empty():
				_pointer(current.position)
				attempts += 1
		await process_frame
	var remaining: int = _inventory(int(initial.id))
	_expect(scene.running and not scene.host.failed and awake and remaining == old_inventory - 1,
		"awake moving owner accepts exactly one displayed pointer cell while running", {"pump_usec": budget, "attempts": attempts, "before_inventory": old_inventory, "after_inventory": remaining, "awake_motion": awake})
	until = Time.get_ticks_msec() + 10000
	while scene.host.completed_ticks <= before and not scene.host.failed and Time.get_ticks_msec() < until:
		await process_frame
	_expect(scene.running and scene.host.completed_ticks > before, "successful live pointer admission preserves real semantic and physical progression", {"pump_usec": budget, "intervals": scene.host.completed_ticks - before})
	scene._toggle_run()
	_expect(await _idle(), "pause finishes only admitted work after live input", {"pump_usec": budget})

func _finish() -> void:
	if scene != null:
		scene.running = false
		scene.set_process(true)
		scene.host.close()
		var until: int = Time.get_ticks_msec() + 10000
		while scene.host.state != "Closed" and Time.get_ticks_msec() < until:
			await process_frame
		_expect(scene.host.state == "Closed", "scene closes actual worker and physics ownership cleanly")
		scene.queue_free()
		await process_frame
	var report: Dictionary = {"schema": "independent-live-admission-review-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "checks": checks, "failures": failures, "observations": evidence,
		"scope": "Actual native/Rapier scene and pointer-handler execution, headless. Original-time backpressure probe and continuous awake pointer cuts at pump0 and4000. No displayed-frame timing or physical GPU acceptance."}
	var output := FileAccess.open("res://../review-live-admission-result.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  ") + "\n")
		output.close()
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
