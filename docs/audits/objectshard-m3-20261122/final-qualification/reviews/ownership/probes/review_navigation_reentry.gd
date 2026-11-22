extends SceneTree

# Independent native integration probe. The only fault injection is elapsed
# deadline acceleration; no native result, disposal result or owner state is
# fabricated. The real project's autoload handles real F2 input events.
var checks: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []
var evidence_path: String = "res://../review-navigation-reentry-result.json"

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

func _launch() -> bool:
	current_scene.launch("objectshard_m3")
	return await _await_scene("res://object_shard_worker_rehearsal.tscn") and await _idle()

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

func _button_named(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		var found: Button = _button_named(child, text)
		if found != null:
			return found
	return null

func _pump_close(scene) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
		scene.host.poll()
		await process_frame
	return scene.host.state == "Closed"

func _run() -> void:
	change_scene_to_file("res://feature_launcher.tscn")
	_expect(await _await_scene("res://feature_launcher.tscn") and await _launch(), "actual native scene opens through real launcher")
	var scene = current_scene
	scene.set_process(false)
	var host = scene.host
	var worker = host.worker
	var bridge = host.bridge
	var initial_generation: int = host.generation
	var original_policy: bool = scene.previous_auto_accept_quit
	_expect(not root.get_node("FeatureNavigation").complete_feature_launcher_navigation(scene), "live native owner cannot claim launcher readiness")
	scene._cell(Vector2i(1, 1), MOUSE_BUTTON_LEFT)
	var queued_before: int = scene.queued_cuts.size()
	_press_f2()
	_expect(scene.closing and host.state == "Closing" and scene.queued_cuts.is_empty(), "real F2 requests close and disposes preexisting UI intents", {"queued_before": queued_before, "cancelled": scene.pointer_cancelled, "host_state": host.state})
	var cut_button: Button = _button_named(scene, "Cut lower support")
	_expect(cut_button != null and not cut_button.disabled, "actual support-cut button remains available during close")
	var previous_queued: int = scene.pointer_queued
	cut_button.pressed.emit()
	var after_button: Dictionary = {"host_state": host.state, "closing": scene.closing, "queued_intents": scene.queued_cuts.size(), "newly_admitted": scene.pointer_queued - previous_queued, "ui_message": scene.report_label.text}
	_expect(scene.queued_cuts.is_empty(), "support-cut button cannot admit unaccounted intents after explicit navigation", after_button)
	var closing_started: int = host._closing_started_usec
	_press_f2()
	_expect(host._closing_started_usec == closing_started and scene.close_destination == "launcher", "repeated F2 is idempotent before Closed")
	scene._reset()
	_expect(not scene.replacing_owner and scene.pending_preset.is_empty() and host.generation == initial_generation, "reset cannot start replacement after exit request")
	_expect(await _pump_close(scene), "real worker completes disposal and main closes host")
	_expect(worker.diagnostics().stopped and not worker._thread.is_started() and bridge.bodies.is_empty() and not bridge.space.is_valid(), "Closed witnesses stopped joined worker and released main RIDs")
	var disposed_count: int = scene.queued_cuts.size()
	var final_cancelled: int = scene.pointer_cancelled
	scene._finish_exit()
	_expect(scene.close_dispatched and auto_accept_quit == original_policy, "launcher completion restores prior quit policy only after Closed")
	_expect(await _await_scene("res://feature_launcher.tscn"), "deferred actual launcher handoff completes")
	_expect(disposed_count == 0, "navigation destroys scene with no silently discarded post-exit intent", {"unresolved_intents": disposed_count, "explicitly_cancelled": final_cancelled, "worker_terminal": worker.diagnostics().terminal})
	# Start another actual owner with a deliberately false prior policy. The
	# restoration must preserve it; setting true unconditionally is not valid.
	auto_accept_quit = false
	_expect(await _launch(), "fresh owner re-entry works with prior quit policy false")
	scene = current_scene
	scene.set_process(false)
	host = scene.host
	worker = host.worker
	scene._reset()
	var generation_before_exit: int = host.generation
	_press_f2()
	_expect(scene.closing and not scene.replacing_owner and scene.pending_preset.is_empty(), "F2 supersedes a pending preset replacement")
	_expect(await _pump_close(scene), "superseded reset disposes original native owner")
	scene._finish_exit()
	_expect(await _await_scene("res://feature_launcher.tscn"), "superseded reset returns to launcher")
	_expect(not auto_accept_quit and host.generation == generation_before_exit and worker.diagnostics().stopped, "navigation restores false quit policy and creates no intermediate owner")
	await _finish()

func _finish() -> void:
	var report: Dictionary = {"schema": "independent-navigation-reentry-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "checks": checks, "failures": failures, "observations": observations}
	var output := FileAccess.open(evidence_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
