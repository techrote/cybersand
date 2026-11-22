extends SceneTree

# The actual project.godot autoload, FeatureNavigation._input and launcher are
# unchanged exact candidate sources. WeakRef witnesses avoid retaining owners.
var checks: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []
var baseline_auto_accept: bool = true
var retained_witnesses: Array[Dictionary] = []
var no_cleanup: bool = false

func _init() -> void:
	Engine.max_fps = 0
	no_cleanup = "--leave-orphan" in OS.get_cmdline_user_args()
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
		if not scene.loading and scene.host.state == "Idle" and scene.queued_cuts.is_empty() and scene.host.actions.is_empty() and scene.host.pending.is_empty() and not scene.host._tick_requested:
			return true
	return false

func _step() -> bool:
	var before: int = int(current_scene.host.frame.tick)
	if not current_scene.host.request_tick().get("ok", false):
		return false
	return await _idle() and int(current_scene.host.frame.tick) == before + 1

func _launch() -> bool:
	current_scene.launch("objectshard_m3")
	return await _await_scene("res://object_shard_worker_rehearsal.tscn") and await _idle()

func _witness() -> Dictionary:
	var host = current_scene.host
	var bodies: Array[Dictionary] = []
	var cleanup_rids: Array[RID] = []
	for row: Dictionary in host.bridge.bodies.values():
		bodies.append({"rid": row.rid, "space": PhysicsServer2D.body_get_space(row.rid),
			"shapes": PhysicsServer2D.body_get_shape_count(row.rid),
			"sleeping": bool(PhysicsServer2D.body_get_state(row.rid, PhysicsServer2D.BODY_STATE_SLEEPING))})
		cleanup_rids.append(row.rid)
		for shape: RID in row.shapes:
			cleanup_rids.append(shape)
	for row: Dictionary in host.bridge.terrain.values():
		cleanup_rids.append(row.rid)
		for shape: RID in row.shapes:
			cleanup_rids.append(shape)
	cleanup_rids.append(host.bridge.space)
	return {"scene": weakref(current_scene), "host": weakref(host), "worker": weakref(host.worker),
		"bridge": weakref(host.bridge), "body_rids": bodies, "cleanup_rids": cleanup_rids,
		"before": {"host_state": host.state, "pending": host.pending.duplicate(true),
			"worker": host.worker.diagnostics(), "physics": host.bridge.diagnostics(), "auto_accept_quit": auto_accept_quit}}

func _observe_after(witness: Dictionary) -> Dictionary:
	var worker = witness.worker.get_ref()
	var host = witness.host.get_ref()
	var bridge = witness.bridge.get_ref()
	var wd: Dictionary = worker.diagnostics() if worker != null else {}
	var live_rids: Array[Dictionary] = []
	# Query only the demonstrated orphan path. A corrected, stopped owner may
	# have freed these RIDs and must not be probed with invalid handles.
	if worker != null and not wd.get("stopped", true) and not wd.get("stop_requested", true):
		for body: Dictionary in witness.body_rids:
			var space: RID = PhysicsServer2D.body_get_space(body.rid)
			live_rids.append({"space_live": space.is_valid(), "same_space": space == body.space,
				"shape_count": PhysicsServer2D.body_get_shape_count(body.rid),
				"sleeping": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING),
				"transform": str(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM))})
	return {"old_scene_destroyed": witness.scene.get_ref() == null, "old_host_destroyed": host == null,
		"old_bridge_destroyed": bridge == null, "worker_alive": worker != null, "worker": wd,
		"live_body_readbacks": live_rids, "current_scene": current_scene.scene_file_path,
		"auto_accept_quit": auto_accept_quit}

func _press_f2() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = KEY_F2
	release.pressed = false
	Input.parse_input_event(release)

func _navigate(label: String) -> Dictionary:
	var witness: Dictionary = _witness()
	retained_witnesses.append(witness)
	_press_f2()
	_expect(await _await_scene("res://feature_launcher.tscn"), label + " real autoload F2 returns to real feature launcher")
	for i: int in range(8):
		await process_frame
	var after: Dictionary = _observe_after(witness)
	observations.append({"label": label, "before": witness.before, "after": after})
	_expect(after.old_scene_destroyed, label + " old scene actually destroyed")
	_expect(not after.worker_alive or after.worker.get("stopped", false), label + " navigation stops and joins the previous native worker", after)
	_expect(after.live_body_readbacks.is_empty(), label + " navigation releases old active or sleeping RIDs", after)
	_expect(auto_accept_quit == baseline_auto_accept, label + " navigation restores prior SceneTree close handling", {"baseline": baseline_auto_accept, "actual": auto_accept_quit})
	return witness

func _orphan_observe(witness: Dictionary) -> void:
	var worker = witness.worker.get_ref()
	if worker == null or worker.diagnostics().stopped:
		return
	var before: Dictionary = worker.diagnostics()
	var ticket: Dictionary = worker.submit("observe", {}, int(before.session), int(before.transport_generation))
	var receipt: Dictionary = {}
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and receipt.is_empty():
		for row: Dictionary in worker.take_results(40):
			if int(row.sequence) == int(ticket.get("sequence", -1)):
				receipt = row
		if receipt.is_empty():
			await process_frame
	var owned_cells: int = 0
	for shard: Dictionary in receipt.get("frame", {}).get("shards", []):
		if shard.get("owns_inventory", false):
			owned_cells += int(shard.get("structural", 0))
	observations.append({"orphan_native_owner_readback": {"ticket": ticket, "result": receipt.get("result", {}),
		"tick": receipt.get("frame", {}).get("tick", -1), "still_owned_structural_cells": owned_cells,
		"worker": worker.diagnostics()}})

func _cleanup(witness: Dictionary) -> void:
	var host = witness.host.get_ref()
	if host != null:
		host.close()
		var deadline: int = Time.get_ticks_msec() + 10000
		while host.state != "Closed" and Time.get_ticks_msec() < deadline:
			host.poll()
			await process_frame
		return
	var worker = witness.worker.get_ref()
	if worker != null and not worker.diagnostics().stopped:
		worker.request_stop()
		var deadline: int = Time.get_ticks_msec() + 10000
		while not worker.diagnostics().stopped and Time.get_ticks_msec() < deadline:
			await process_frame
		var terminal: Dictionary = worker.join_if_stopped()
		observations.append({"reviewer_only_cleanup_after_evidence": terminal})
		if terminal.get("ok", false):
			var bridge = witness.bridge.get_ref()
			if bridge != null:
				bridge.shutdown()
			else:
				for rid: RID in witness.cleanup_rids:
					PhysicsServer2D.free_rid(rid)

func _run() -> void:
	baseline_auto_accept = auto_accept_quit
	_expect(root.has_node("FeatureNavigation"), "real project autoload is instantiated")
	change_scene_to_file("res://feature_launcher.tscn")
	_expect(await _await_scene("res://feature_launcher.tscn") and await _launch(), "actual launcher opens actual native rehearsal")
	current_scene._cut_support()
	_expect(await _idle(), "actual support-cut input drains")
	for i: int in range(20):
		if not current_scene.host.bridge.bodies.is_empty():
			break
		if not await _step():
			break
	_expect(current_scene.host.bridge.bodies.size() == 1 and not bool(current_scene.host.bridge.diagnostics().bodies[0].sleeping), "actual active awake owner exists before F2")
	current_scene.delay_box.button_pressed = true
	current_scene.host.request_tick()
	current_scene.host.poll(false)
	_expect(not current_scene.host.pending.is_empty(), "actual tick receipt is pending at F2 navigation")
	var active: Dictionary = await _navigate("active_pending")
	if no_cleanup:
		await _finish()
		return
	_expect(await _launch(), "real launcher re-entry opens a new native worker")
	var orphan = active.worker.get_ref()
	var reentry: Dictionary = {"old": orphan.diagnostics() if orphan != null else {}, "new": current_scene.host.worker.diagnostics()}
	observations.append({"active_reentry_workers": reentry})
	_expect(orphan == null or orphan.diagnostics().stopped, "re-entry never overlaps old and new live native owners", reentry)
	orphan = null
	await _orphan_observe(active)
	await _cleanup(active)
	current_scene._cut_support()
	_expect(await _idle(), "second actual support cut drains")
	var sleeping: bool = false
	for i: int in range(600):
		if not await _step():
			break
		var bodies: Array = current_scene.host.bridge.diagnostics().bodies
		if not bodies.is_empty() and bool(bodies[0].sleeping):
			sleeping = true
			break
	_expect(sleeping, "second owner reaches natural Rapier sleep before navigation")
	var rest: Dictionary = await _navigate("naturally_sleeping")
	_expect(await _launch(), "re-entry after sleeping owner exit opens the rehearsal")
	orphan = rest.worker.get_ref()
	reentry = {"old": orphan.diagnostics() if orphan != null else {}, "new": current_scene.host.worker.diagnostics()}
	observations.append({"sleeping_reentry_workers": reentry})
	_expect(orphan == null or orphan.diagnostics().stopped, "sleeping navigation never overlaps live native owners", reentry)
	orphan = null
	await _orphan_observe(rest)
	await _cleanup(rest)
	current_scene.host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while current_scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
		current_scene.host.poll()
		await process_frame
	_expect(current_scene.host.state == "Closed", "reviewer explicitly cleans the final healthy owner")
	await _finish()

func _finish() -> void:
	var report: Dictionary = {"schema": "independent-f2-navigation-lifecycle-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks": checks, "failures": failures, "leave_orphan_for_exit_diagnostics": no_cleanup,
		"scope": "Actual exact-source project autoload, F2 InputEvent route, deferred change_scene, launcher re-entry and real native/Rapier ownership. Weak references observe old owners; cleanup is explicitly later reviewer-only activity.", "observations": observations}
	var suffix: String = "-no-cleanup" if no_cleanup else ""
	var file := FileAccess.open("res://../review-navigation-result" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures, "source_revision": report.source_revision, "leave_orphan": no_cleanup}))
	quit(0 if failures == 0 else 1)
