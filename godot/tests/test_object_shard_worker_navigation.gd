extends SceneTree

# Real project autoload, F2 input and launcher re-entry. Strong host/worker/bridge
# witnesses observe completed disposal without keeping the scene alive. Faults
# below alter only delivered stop status after the actual native thread exits;
# they do not claim that a synthetic refusal came from the native material law.
const OWNER_SCENE: String = "res://object_shard_worker_rehearsal.tscn"
const LAUNCHER_SCENE: String = "res://feature_launcher.tscn"
const SCHEMA: String = "objectshard-worker-navigation-test-v1"
const CHILD_SCHEMA: String = "objectshard-worker-navigation-quit-child-v1"
var checks: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []
var cases: Array[String] = []
var witnesses: Array[Dictionary] = []
var baseline_auto_accept: bool = true
var freeze_next_owner: bool = false
var child_mode: bool = false
var child_written: bool = false
var output_path: String = ""


func _init() -> void:
	Engine.max_fps = 240
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--navigation-quit-child":
			child_mode = true
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	node_added.connect(_node_added)
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	observations.append({"check": label, "passed": value})
	if not value:
		failures += 1
		push_error(label)


func _node_added(node: Node) -> void:
	if freeze_next_owner and node.name == "ObjectShardWorkerRehearsal":
		# Keep the actual native startup receipt pending until F2 owns shutdown.
		node.ready.connect(_freeze_ready.bind(node), CONNECT_ONE_SHOT)
		freeze_next_owner = false


func _freeze_ready(node: Node) -> void:
	# Script process enablement occurs during tree entry; freeze after _ready.
	node.set_process(false)


func _await_scene(path: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == path:
			return true
		await process_frame
	return false


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var scene = current_scene
		if scene == null or scene.scene_file_path != OWNER_SCENE or scene.host.failed:
			return false
		if not scene.loading and not scene.replacing_owner and scene.host.state == "Idle" \
			and scene.queued_cuts.is_empty() and scene.host.actions.is_empty() \
			and scene.host.pending.is_empty() and not scene.host._tick_requested:
			return true
		await process_frame
	return false


func _launch(wait_ready: bool = true) -> bool:
	if current_scene == null or current_scene.scene_file_path != LAUNCHER_SCENE:
		return false
	for witness: Dictionary in witnesses:
		if not witness.worker.diagnostics().stopped or witness.worker._thread.is_started():
			_expect(false, "No new launcher entry may overlap a previous live or unjoined native owner")
			return false
	current_scene.launch("objectshard_m3")
	if not await _await_scene(OWNER_SCENE):
		return false
	return await _idle() if wait_ready else true


func _step() -> bool:
	var before: int = int(current_scene.host.frame.tick)
	if not current_scene.host.request_tick().get("ok", false):
		return false
	return await _idle() and int(current_scene.host.frame.tick) == before + 1


func _promote() -> bool:
	current_scene._cut_support()
	if not await _idle():
		return false
	for index: int in range(20):
		if not current_scene.host.bridge.bodies.is_empty():
			return true
		if not await _step():
			return false
	return false


func _press_f2() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = KEY_F2
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _button(scene: Node, label: String) -> Button:
	for node: Node in scene.find_children("*", "Button", true, false):
		if node is Button and node.text == label:
			return node
	return null


func _witness(label: String) -> Dictionary:
	var scene = current_scene
	var host = scene.host
	var witness: Dictionary = {"label": label, "scene": weakref(scene), "scene_id": scene.get_instance_id(),
		"host": host, "worker": host.worker, "bridge": host.bridge,
		"previous_quit_policy": scene.previous_auto_accept_quit,
		"before": {"host_state": host.state, "session": host.session, "generation": host.generation,
			"pending": host.pending.duplicate(true), "worker": host.worker.diagnostics(),
			"physics": host.bridge.diagnostics(), "capture": host.capture.metadata()}}
	witnesses.append(witness)
	return witness


func _closed_checks(witness: Dictionary) -> void:
	var label: String = witness.label
	var worker = witness.worker
	var bridge = witness.bridge
	_expect(witness.host.state == "Closed", label + ": host reaches Closed before handoff")
	_expect(worker.diagnostics().stopped, label + ": actual exclusive worker reports stopped")
	_expect(not worker._thread.is_started(), label + ": stopped worker was joined by the production host")
	_expect(worker.diagnostics().terminal.get("outcome") == "Stopped", label + ": terminal receipt confirms native disposal")
	_expect(bridge.bodies.is_empty() and bridge.terrain.is_empty(), label + ": body and terrain RID registries are empty")
	_expect(not bridge.space.is_valid(), label + ": main physics space was released")
	_expect(witness.host.capture.stream == null, label + ": prospective trace is closed")
	_expect(auto_accept_quit == bool(witness.previous_quit_policy), label + ": prior SceneTree quit policy is restored")
	observations.append({"case": label, "before": witness.before,
		"after": {"state": witness.host.state, "worker": worker.diagnostics(),
			"body_count": bridge.bodies.size(), "terrain_count": bridge.terrain.size(),
			"space_valid": bridge.space.is_valid(), "thread_started": worker._thread.is_started(),
			"auto_accept_quit": auto_accept_quit}})


func _navigate(witness: Dictionary, repeats: int = 1) -> bool:
	var scene = current_scene
	for index: int in range(repeats):
		_press_f2()
	_expect(current_scene == scene and scene.closing, str(witness.label) + ": F2 retains the scene while disposal is pending")
	_expect(scene.close_destination == "launcher" and not scene.running, str(witness.label) + ": navigation has an explicit paused launcher destination")
	var before_inputs: int = scene.pointer_queued
	var cut: Button = _button(scene, "Cut lower support")
	var erode: Button = _button(scene, "Erode resting cell")
	_expect(cut != null and erode != null, str(witness.label) + ": actual support and erosion controls are present")
	if cut != null:
		cut.pressed.emit()
	if erode != null:
		erode.pressed.emit()
	var cells: Array[Vector2i] = [Vector2i(20, 20)]
	scene._stroke(cells, MOUSE_BUTTON_LEFT)
	scene._cell(Vector2i(20, 20), MOUSE_BUTTON_RIGHT)
	_expect(scene.queued_cuts.is_empty() and scene.pointer_queued == before_inputs,
		str(witness.label) + ": post-exit button and pointer input cannot enter a queue that navigation will discard")
	scene.set_process(true)
	var reached: bool = await _await_scene(LAUNCHER_SCENE)
	_expect(reached, str(witness.label) + ": actual autoload completes the real launcher handoff")
	if not reached:
		return false
	await process_frame
	_expect(witness.scene.get_ref() == null, str(witness.label) + ": old scene is removed after shutdown")
	_closed_checks(witness)
	cases.append(str(witness.label))
	return true


func _active_pending() -> bool:
	_expect(await _launch(), "Actual feature launcher opens the native rehearsal")
	if current_scene == null or current_scene.scene_file_path != OWNER_SCENE:
		return false
	var scene = current_scene
	_expect(await _promote(), "Actual support removal promotes native Wood before active navigation")
	if scene.host.bridge.bodies.is_empty():
		return false
	_expect(not bool(scene.host.bridge.diagnostics().bodies[0].sleeping), "F2 active fixture contains an awake real Rapier body")
	var navigation: Node = root.get_node("FeatureNavigation")
	_expect(not navigation.complete_feature_launcher_navigation(scene), "An open owner cannot complete navigation without disposal")
	var foreign := Node.new()
	_expect(not navigation.complete_feature_launcher_navigation(foreign), "A foreign scene cannot authorize current-owner replacement")
	foreign.free()
	scene.delay_box.button_pressed = true
	_expect(scene.host.request_tick().get("ok", false), "Actual native tick is admitted before navigation")
	scene.host.poll(false)
	_expect(not scene.host.pending.is_empty(), "F2 begins with a real native receipt outstanding")
	var witness: Dictionary = _witness("active_pending_repeated")
	if not await _navigate(witness, 3):
		return false
	_expect(await _launch(), "Re-entry starts a new owner after active-body disposal")
	_expect(current_scene.host.worker != witness.worker and witness.worker.diagnostics().stopped,
		"New entry has a different worker and does not overlap the stopped old owner")
	var current_id: int = current_scene.get_instance_id()
	navigation._finish_return_if_current(int(witness.scene_id))
	await process_frame
	_expect(current_scene != null and current_scene.get_instance_id() == current_id,
		"A stale deferred navigation completion cannot replace the new scene")
	return true


func _sleeping() -> bool:
	_expect(await _promote(), "Re-entered scene promotes its own genuine component")
	var sleeping: bool = false
	for index: int in range(600):
		if not await _step():
			break
		var bodies: Array = current_scene.host.bridge.diagnostics().bodies
		if not bodies.is_empty() and bool(bodies[0].sleeping):
			sleeping = true
			break
	_expect(sleeping, "Second body reaches natural Rapier sleep without forcing sleep")
	return await _navigate(_witness("naturally_sleeping"))


func _opening() -> bool:
	freeze_next_owner = true
	_expect(await _launch(false), "Actual launcher constructs the opening owner")
	var scene = current_scene
	_expect(not scene.is_processing() and scene.host.state == "Opening", "Startup receipt remains genuinely unconsumed at F2")
	return await _navigate(_witness("opening"))


func _reset_pending() -> bool:
	_expect(await _launch(), "Reset-navigation fixture opens normally")
	var scene = current_scene
	scene.set_process(false)
	var witness: Dictionary = _witness("reset_superseded")
	scene._reset()
	_expect(scene.replacing_owner and not scene.pending_preset.is_empty(), "Real UI reset has an outstanding replacement preset")
	_press_f2()
	_expect(not scene.replacing_owner and scene.pending_preset.is_empty(), "F2 cancels the pending replacement before any new World can open")
	_expect(scene.host == witness.host, "Navigation keeps the original owner while reset disposal is outstanding")
	return await _navigate(witness, 2)


func _held_interval() -> bool:
	_expect(await _launch() and await _promote(), "Held-interval fixture contains an actual native and Rapier body")
	var scene = current_scene
	scene.delay_box.button_pressed = true
	scene.host.request_tick()
	scene.host.poll(false)
	_expect(not scene.host.pending.is_empty(), "Held fixture starts from a real pending native operation")
	if scene.host.pending.is_empty():
		return false
	scene.host.pending.sent_usec = Time.get_ticks_usec() - scene.host.RECEIPT_DEADLINE_USEC - 1
	scene.host.poll(false)
	_expect(scene.host.state == "Held" and scene.host.failed, "An expired real pending receipt enters the production Held state")
	return await _navigate(_witness("held_interval"))


func _stop_delivery_faults() -> bool:
	_expect(await _launch() and await _promote(), "Stop-delivery fixture retains actual body RIDs until acknowledgement")
	var scene = current_scene
	scene.set_process(false)
	var witness: Dictionary = _witness("stop_delivery_faults")
	_press_f2()
	var worker = witness.worker
	var deadline: int = Time.get_ticks_msec() + 10000
	while (not worker.diagnostics().stopped or worker._thread.is_alive()) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(worker.diagnostics().stopped and not worker._thread.is_alive(), "Native stop actually completes before controlled delivery faults are injected")
	if not worker.diagnostics().stopped or worker._thread.is_alive():
		return false
	var real_terminal: Dictionary = worker.diagnostics().terminal.duplicate(true)
	worker._mutex.lock()
	worker._terminal = {"ok": false, "outcome": "StopDisposalRefused", "disposal": {"outcome": "InjectedStopDeliveryRefusal"}}
	worker._mutex.unlock()
	scene.set_process(true)
	for index: int in range(4):
		await process_frame
	_expect(current_scene == scene and scene.host.state == "ShutdownHeld" and not scene.closing,
		"A refused stop receipt retains the scene and offers explicit retry")
	_expect(not witness.bridge.bodies.is_empty() and witness.bridge.space.is_valid() and worker._thread.is_started(),
		"Unaccepted terminal status retains main RIDs and the unjoined thread handle")
	_expect(not root.get_node("FeatureNavigation").complete_feature_launcher_navigation(scene),
		"ShutdownHeld cannot bypass the final navigation gate")
	scene._export()
	_expect(not scene.last_export.is_empty() and FileAccess.file_exists(scene.last_export),
		"Export remains usable while navigation is held")
	# The actual worker is already finished. Mask only its delivered stopped flag
	# to exercise the existing deadline path without blocking/sleeping15seconds.
	scene.set_process(false)
	worker._mutex.lock()
	worker._terminal = real_terminal.duplicate(true)
	worker._stopped = false
	worker._mutex.unlock()
	_press_f2()
	scene.host._closing_started_usec = Time.get_ticks_usec() - scene.host.RECEIPT_DEADLINE_USEC - 1
	scene.set_process(true)
	for index: int in range(4):
		await process_frame
	_expect(current_scene == scene and scene.host.state == "ShutdownHeld" and not scene.closing,
		"Missing stopped-status delivery reaches the bounded shutdown hold without replacing the scene")
	_expect(witness.bridge.space.is_valid() and not witness.bridge.bodies.is_empty(),
		"Deadline expiry does not release unacknowledged body resources")
	worker._mutex.lock()
	worker._stopped = true
	worker._terminal = real_terminal.duplicate(true)
	worker._mutex.unlock()
	observations.append({"fault_scope": "Real native stop completed first. Only terminal/stopped delivery status was injected under its mutex; native disposal refusal is not claimed.",
		"actual_terminal": real_terminal})
	return await _navigate(witness)


func _already_closed_policy() -> bool:
	auto_accept_quit = false
	_expect(await _launch(), "An alternate prior quit policy enters the actual scene")
	var scene = current_scene
	scene.set_process(false)
	var witness: Dictionary = _witness("already_closed_prior_policy")
	scene.host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
		scene.host.poll()
		await process_frame
	_expect(scene.host.state == "Closed", "Already-closed navigation fixture has completed real disposal")
	var result: bool = await _navigate(witness)
	_expect(not auto_accept_quit, "Navigation restores the captured false policy instead of hardcoding true")
	auto_accept_quit = baseline_auto_accept
	return result


func _child_exit(witness: Dictionary) -> void:
	if child_written:
		return
	_closed_checks(witness)
	_expect(witness.host.state == "Closed" and auto_accept_quit == baseline_auto_accept,
		"Actual process exit occurs only after disposal and policy restoration")
	_write_child()


func _write_child() -> void:
	if child_written:
		return
	child_written = true
	var report: Dictionary = {"schema": CHILD_SCHEMA, "checks": checks, "failures": failures,
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "observations": observations}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print(JSON.stringify({"schema": CHILD_SCHEMA, "checks": checks, "failures": failures}))


func _run_child() -> void:
	_expect(await _launch() and await _promote(), "Quit child opens a real moving-owner fixture")
	if current_scene == null or current_scene.scene_file_path != OWNER_SCENE:
		_write_child()
		quit(1)
		return
	var scene = current_scene
	scene.set_process(false)
	var witness: Dictionary = _witness("window_close_upgrade")
	_press_f2()
	_expect(scene.closing and scene.close_destination == "launcher", "F2 begins asynchronous launcher disposal in child")
	scene.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_expect(scene.close_destination == "quit", "Window close upgrades pending navigation to process exit")
	_press_f2()
	_expect(scene.close_destination == "quit", "Repeated F2 cannot downgrade process exit")
	var worker = witness.worker
	var stopped_deadline: int = Time.get_ticks_msec() + 10000
	while (not worker.diagnostics().stopped or worker._thread.is_alive()) and Time.get_ticks_msec() < stopped_deadline:
		await process_frame
	_expect(worker.diagnostics().stopped and not worker._thread.is_alive(), "Child native owner actually stops before delayed terminal delivery")
	if not worker.diagnostics().stopped or worker._thread.is_alive():
		await _cleanup()
		_write_child()
		quit(1)
		return
	worker._mutex.lock()
	worker._stopped = false
	worker._mutex.unlock()
	scene.host._closing_started_usec = Time.get_ticks_usec() - scene.host.RECEIPT_DEADLINE_USEC - 1
	scene.set_process(true)
	for index: int in range(4):
		await process_frame
	_expect(current_scene == scene and scene.host.state == "ShutdownHeld" and not scene.closing,
		"Child holds the scene when stopped-status delivery misses its deadline")
	scene.set_process(false)
	worker._mutex.lock()
	worker._stopped = true
	worker._mutex.unlock()
	_press_f2()
	_expect(scene.closing and scene.close_destination == "quit", "F2 retry after ShutdownHeld preserves the earlier window-close intent")
	scene.tree_exiting.connect(_child_exit.bind(witness))
	scene.set_process(true)
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(false, "Actual child window-close path must terminate its process")
	await _cleanup()
	_write_child()
	quit(1)


func _quit_subprocess() -> void:
	var result_path: String = ProjectSettings.globalize_path("user://objectshard-navigation-quit-%d.json" % Time.get_ticks_usec())
	if not output_path.is_empty():
		result_path = output_path.get_basename() + "-quit-child.json"
	var output: Array = []
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/test_object_shard_worker_navigation.gd", "--", "--navigation-quit-child", "--output=" + result_path])
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(exit_code == 0, "Actual window-close upgrade child exits successfully")
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path)) if FileAccess.file_exists(result_path) else null
	var child_ok: bool = report is Dictionary and report.get("schema") == CHILD_SCHEMA \
		and typeof(report.get("failures")) in [TYPE_INT, TYPE_FLOAT] and report.failures == 0 \
		and typeof(report.get("checks")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(report.checks)) \
		and float(report.checks) == floorf(float(report.checks)) and int(report.checks) >= 18
	_expect(child_ok, "Child receipt proves native/RID shutdown before actual process exit")
	if child_ok:
		# JSON parsing restores numbers as floats. Preserve typed assertion counts
		# only after validating their exact integral domain, including zero failures.
		report.checks = int(report.checks)
		report.failures = int(report.failures)
	var child_log: String = result_path + ".log"
	var file := FileAccess.open(child_log, FileAccess.WRITE)
	if file != null:
		for line: String in output:
			file.store_string(line)
		file.close()
	observations.append({"case": "window_close_upgrade", "child_exit_code": exit_code, "child_report": report,
		"child_output_log": child_log, "child_output_sha256": FileAccess.get_sha256(child_log)})
	cases.append("window_close_upgrade")


func _cleanup() -> void:
	# Failure cleanup follows assertions; it never manufactures a passing owner
	# disposition. Kept witnesses let a failing navigation case stop safely.
	for witness: Dictionary in witnesses:
		var host = witness.host
		if host.state == "Closed":
			continue
		host.close()
		var deadline: int = Time.get_ticks_msec() + 10000
		while host.state != "Closed" and Time.get_ticks_msec() < deadline:
			host.poll()
			await process_frame
	if current_scene != null and current_scene.scene_file_path == OWNER_SCENE:
		var scene = current_scene
		scene.set_process(false)
		scene.host.close()
		var deadline: int = Time.get_ticks_msec() + 10000
		while scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
			scene.host.poll()
			await process_frame
	auto_accept_quit = baseline_auto_accept


func _run() -> void:
	baseline_auto_accept = auto_accept_quit
	_expect(root.has_node("FeatureNavigation"), "Actual project FeatureNavigation autoload exists")
	_expect(change_scene_to_file(LAUNCHER_SCENE) == OK and await _await_scene(LAUNCHER_SCENE),
		"Actual feature launcher is the current scene")
	if child_mode:
		await _run_child()
		return
	var continuing: bool = await _active_pending()
	if continuing: continuing = await _sleeping()
	if continuing: continuing = await _opening()
	if continuing: continuing = await _reset_pending()
	if continuing: continuing = await _held_interval()
	if continuing: continuing = await _stop_delivery_faults()
	if continuing: continuing = await _already_closed_policy()
	if continuing: _quit_subprocess()
	_expect(continuing and cases.size() == 8, "Every required navigation lifecycle scenario completes")
	await _cleanup()
	var report: Dictionary = {"schema": SCHEMA, "checks": checks, "failures": failures,
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "cases": cases,
		"scope": "Actual autoload F2, real native/Rapier ownership, scene re-entry and child-process window close. Controlled stop-delivery faults are explicitly distinguished from native failures.",
		"observations": observations}
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ") + "\n")
			file.close()
	print(JSON.stringify(report))
	quit(0 if failures == 0 else 1)
