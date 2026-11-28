extends SceneTree

var checks: int = 0
var failures: int = 0
var evidence: Array[Dictionary] = []
var navigation: Node

func _init() -> void:
	Engine.max_fps = 0
	call_deferred("_run")

func _expect(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks += 1
	evidence.append({"check": label, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		push_error(label + " " + JSON.stringify(detail))

func _scene(path: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return true
	return false

func _ready_owner() -> bool:
	current_scene.launch("objectshard_m3")
	if not await _scene("res://object_shard_worker_rehearsal.tscn"):
		return false
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene.host.failed:
			return false
		if not current_scene.loading and current_scene.host.state == "Idle":
			return true
	return false

func _f2() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_F2
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.keycode = KEY_F2
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()

func _run() -> void:
	navigation = root.get_node("FeatureNavigation")
	change_scene_to_file("res://feature_launcher.tscn")
	_expect(await _scene("res://feature_launcher.tscn"), "actual launcher starts for completion controls")
	_expect(not navigation.complete_feature_launcher_navigation(current_scene), "current launcher without async readiness cannot forge a completion")
	for prior: bool in [false, true]:
		auto_accept_quit = prior
		_expect(await _ready_owner(), "actual owner opens with prior close policy " + str(prior))
		var worker_witness: WeakRef = weakref(current_scene.host.worker)
		var owner_id: int = current_scene.get_instance_id()
		var thread_before: int = int(current_scene.host.worker.diagnostics().owner_thread)
		_expect(current_scene.previous_auto_accept_quit == prior and not auto_accept_quit, "owner records exact prior policy before handling close requests")
		_f2()
		_expect(current_scene.get_instance_id() == owner_id and current_scene.closing and current_scene.host.state == "Closing", "actual F2 retains current owner while native disposal is pending")
		_expect(not navigation.complete_feature_launcher_navigation(current_scene), "early completion cannot bypass the native disposal/worker join barrier")
		_f2()
		_expect(current_scene.get_instance_id() == owner_id and current_scene.close_destination == "launcher" and int(current_scene.host.worker.diagnostics().owner_thread) == thread_before, "repeated real F2 preserves one closing owner and destination")
		_expect(await _scene("res://feature_launcher.tscn"), "acknowledged close finishes actual launcher navigation")
		var worker = worker_witness.get_ref()
		_expect(worker == null or worker.diagnostics().stopped, "old worker is stopped or released before launcher is visible")
		_expect(auto_accept_quit == prior, "successful launcher handoff restores the exact prior close policy", {"prior": prior, "actual": auto_accept_quit})
		worker = null
	# Use a real owner, but explicitly finish its native/RID disposal before
	# forcing a successor. This tests a stale deferred handoff, not unsupported
	# arbitrary scene replacement of a still-live owner.
	auto_accept_quit = true
	_expect(await _ready_owner(), "actual owner starts for deferred successor fencing")
	current_scene.host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while current_scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
		current_scene.host.poll()
		await process_frame
	_expect(current_scene.host.state == "Closed", "native owner and RIDs are actually disposed before successor-control injection")
	var old_scene: Node = current_scene
	var old_id: int = old_scene.get_instance_id()
	old_scene.request_feature_launcher_navigation()
	_expect(navigation.complete_feature_launcher_navigation(old_scene), "only an actually closed current owner admits the deferred launcher handoff")
	change_scene_to_file("res://tests/review_navigation_successor.tscn")
	_expect(not navigation.complete_feature_launcher_navigation(old_scene), "late completion refuses once the owner is no longer current")
	_expect(await _scene("res://tests/review_navigation_successor.tscn"), "independent successor enters despite already queued old-owner completion")
	for i: int in range(4):
		await process_frame
	_expect(current_scene.scene_file_path == "res://tests/review_navigation_successor.tscn", "deferred callback rechecks identity and does not replace its successor")
	navigation._finish_return_if_current(old_id)
	await process_frame
	_expect(current_scene.scene_file_path == "res://tests/review_navigation_successor.tscn", "explicit stale scene-instance callback remains a no-op")
	_expect(not navigation.complete_feature_launcher_navigation(current_scene), "successor without readiness method cannot complete an async handoff")
	_f2()
	_expect(await _scene("res://feature_launcher.tscn"), "ordinary scene F2 continues to use the direct navigation route")
	var report: Dictionary = {"schema": "independent-navigation-completion-fences-v1", "checks": checks, "failures": failures,
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "evidence": evidence,
		"limits": "Controlled F2/close handoff only. Direct externally forced replacement of a still-live owner is not claimed to have universal cleanup."}
	var file := FileAccess.open("res://../review-navigation-fences-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
