extends SceneTree

var checks: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []

func _init() -> void:
	Engine.max_fps = 0
	call_deferred("_run")

func _expect(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks += 1
	observations.append({"check": label, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		push_error(label + " " + JSON.stringify(detail))

func _await_scene(path: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return true
	return false

func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var scene = current_scene
		if scene == null or not "host" in scene or scene.host.failed:
			return false
		if not scene.loading and scene.host.state == "Idle" and scene.queued_cuts.is_empty() and scene.host.actions.is_empty() and scene.host.pending.is_empty():
			return true
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

func _pump_close(host) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	return host.state == "Closed"

func _run() -> void:
	change_scene_to_file("res://feature_launcher.tscn")
	_expect(await _await_scene("res://feature_launcher.tscn"), "real launcher opens")
	var held_reached: bool = false
	for attempt: int in range(8):
		current_scene.launch("objectshard_m3")
		_expect(await _await_scene("res://object_shard_worker_rehearsal.tscn") and await _idle(), "actual owner ready for accelerated shutdown deadline")
		var scene = current_scene
		scene.set_process(false)
		var host = scene.host
		var worker = host.worker
		var bridge = host.bridge
		host.request_tick()
		host.poll(false)
		_press_f2()
		scene.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_expect(scene.closing and scene.close_destination == "quit", "window close upgrades already requested F2 exit")
		var before: Dictionary = worker.diagnostics()
		# Advance only main's elapsed-time witness. The worker and its native
		# disposal operation continue running unchanged on the actual owner.
		host._closing_started_usec = Time.get_ticks_usec() - host.RECEIPT_DEADLINE_USEC - 1
		host.poll(false)
		observations.append({"attempt": attempt, "state_after_accelerated_deadline": host.state, "worker_before": before, "worker_after": worker.diagnostics()})
		if host.state == "ShutdownHeld":
			held_reached = true
			scene._process(0.0)
			_expect(current_scene == scene and not scene.closing and bridge.space.is_valid() and not auto_accept_quit, "ShutdownHeld retains actual scene and RIDs with close interception active")
			var requested_before_retry: String = scene.close_destination
			_press_f2()
			_expect(scene.close_destination == "quit", "explicit F2 retry preserves previously requested quit priority", {"before_retry": requested_before_retry, "after_retry": scene.close_destination, "host_state": host.state})
			_expect(await _pump_close(host), "explicit retry joins completed real worker and closes host")
			_expect(worker.diagnostics().stopped and not worker._thread.is_started() and bridge.bodies.is_empty() and not bridge.space.is_valid(), "retry releases the same actual native owner and RIDs")
			# Reviewer-only cleanup chooses launcher so the test can report. The
			# destination assertion above observed the unmodified product choice.
			scene.close_destination = "launcher"
			scene._finish_exit()
			_expect(await _await_scene("res://feature_launcher.tscn"), "reviewer cleanup returns disposed scene to launcher")
			break
		else:
			scene.close_destination = "launcher"
			if host.state != "Closed":
				await _pump_close(host)
			scene._finish_exit()
			await _await_scene("res://feature_launcher.tscn")
	_expect(held_reached, "actual shutdown deadline fault reached retained ShutdownHeld")
	var report: Dictionary = {"schema": "independent-navigation-held-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "fault": "Only elapsed main shutdown deadline accelerated; native owner/disposal results unmodified", "checks": checks, "failures": failures, "observations": observations}
	var output := FileAccess.open("res://../review-navigation-held-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
