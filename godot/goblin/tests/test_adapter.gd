extends SceneTree

## Explicit profile-only Godot/native integration; excluded from ordinary discovery.
## Invoke through tools/gip014/run_goblin.py
## so the fixed-name normal Workbench save belongs to a disposable test profile.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
var adapter: Node
var assertions: RefCounted
var checks := 0
var failures: Array[String] = []
var records: Array = []
var stop_when_editor_busy := false
var probe_reentry_when_busy := false
var reentry_checked := false
var admissions: Array = []
var stop_on_admission_id := ""

func _initialize() -> void:
	run.call_deferred()

func _process(_delta: float) -> bool:
	if probe_reentry_when_busy and adapter != null and adapter.editor != null and adapter.editor.busy():
		probe_reentry_when_busy = false
		# Hold only editor receipt consumption, as established editor tests do.
		# This is a deliberately controlled adapter-concurrency fixture.
		adapter.editor.set_process(false)
		_probe_reentry.call_deferred()
	if stop_when_editor_busy and adapter != null and adapter.editor != null and adapter.editor.busy():
		stop_when_editor_busy = false
		adapter.request_stop()
	return false

func _probe_reentry() -> void:
	var first: Dictionary = await adapter.execute({"id": "select_material", "args": {"material": 7}})
	check(first.status == "refused" and adapter.executing, "reentrant refusal preserves the actual in-flight action owner")
	var second: Dictionary = await adapter.execute({"id": "play", "args": {"ticks": 4}})
	check(second.status == "refused" and adapter.executing and adapter.host.paused,
		"second reentry cannot slip past the first refusal or start simulation")
	reentry_checked = true
	adapter.editor.set_process(true)

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("GOBLIN_ADAPTER " + label)
	return value

func action(id: String, args: Dictionary = {}, expected_status: String = "completed") -> Dictionary:
	print("GOBLIN_ADAPTER_PROPOSED ", JSON.stringify({"index": records.size(), "id": id, "args": args}))
	var admission_count: int = admissions.size()
	var row: Dictionary = await adapter.execute({"id": id, "args": args})
	if row.admission.get("accepted", false):
		check(admissions.size() == admission_count + 1, id + " emits exactly one genuine admission checkpoint")
	row["assertions"] = assertions.evaluate(row)
	records.append(row)
	print("GOBLIN_ADAPTER_OBSERVED ", JSON.stringify({"index": records.size() - 1, "id": id,
		"status": row.status, "classification": row.classification, "native": row.after.get("native", {})}))
	check(row.status == expected_status, "%s terminal %s, got %s: %s" % [id, expected_status, row.status, row.error])
	for result: Dictionary in row.assertions:
		check(result.status != "fail", "%s / %s / expected=%s actual=%s" % [id, result.id, str(result.expected), str(result.actual)])
	return row

func run() -> void:
	check(Adapter.validate_action({"id": "brush", "args": {"x": 40, "y": 40, "radius": 0}}).ok, "typed valid brush")
	check(Adapter.validate_action(JSON.parse_string('{"id":"camera","args":{"x":0,"y":0,"width":480,"height":270}}')).ok,
		"JSON numeric camera arguments preserve the finite integer vocabulary")
	for invalid: Dictionary in [
		{"id": "pause"},
		{"id": "brush", "args": {"x": 40, "y": 40, "radius": 5}},
		{"id": "brush", "args": {"x": 40.5, "y": 40, "radius": 0}},
		{"id": "rectangle", "args": {"x0": 10, "y0": 10, "x1": 100, "y1": 30}},
		{"id": "save_layout", "args": {"name": "outside"}},
		{"id": "panel", "args": {"panel": "unknown", "open": true}},
		{"id": "unknown", "args": {}},
	]: check(not Adapter.validate_action(invalid).ok, "invalid finite action refused: " + invalid.id)
	adapter = Adapter.new()
	root.add_child(adapter)
	adapter.action_admitted.connect(func(proposed: Dictionary, admitted: Dictionary, observation: Dictionary) -> void:
		admissions.append({"action": proposed, "admission": admitted, "observation": observation})
		if proposed.id == stop_on_admission_id:
			stop_on_admission_id = ""
			adapter.request_stop())
	assertions = Assertions.new()
	var mounted: Dictionary = await adapter.mount()
	if not check(mounted.get("ok", false), "actual Workbench mounted: " + str(mounted.get("error", ""))):
		await finish()
		return
	var installed: Dictionary = await adapter.install_fixture("construction", Fixtures.build("construction", adapter.policy()))
	if not check(installed.get("ok", false), "committed construction fixture installed: " + str(installed.get("error", ""))):
		await finish()
		return
	assertions.reset(installed)
	await action("pause")
	await action("select_material", {"material": 58})
	probe_reentry_when_busy = true
	await action("brush", {"x": 48, "y": 48, "radius": 2})
	check(reentry_checked, "in-flight reentry fixture actually executed")
	await action("rectangle", {"x0": 64, "y0": 40, "x1": 71, "y1": 47})
	await action("undo")
	await action("redo")
	await action("erase", {"x": 66, "y": 42, "radius": 0})
	await action("undo")
	await action("undo")
	await action("redo")
	await action("select_region", {"x0": 64, "y0": 40, "x1": 71, "y1": 47})
	await action("copy")
	await action("paste", {"x": 96, "y": 64})
	await action("select_material", {"material": 7})
	await action("outline", {"x0": 128, "y0": 48, "x1": 143, "y1": 63})
	await action("select_region", {"x0": 128, "y0": 48, "x1": 143, "y1": 63})
	await action("select_material", {"material": 2})
	await action("fill", {"x": 132, "y": 52})
	await action("line", {"x0": 160, "y0": 48, "x1": 172, "y1": 55})
	await action("panel", {"panel": "details", "open": true})
	await action("panel", {"panel": "details", "open": false})
	await action("camera", {"x": 128, "y": 64, "width": 240, "height": 135})
	await action("camera", {"x": 0, "y": 0, "width": 480, "height": 270})
	await action("save_layout")
	await action("brush", {"x": 48, "y": 48, "radius": 0})
	await action("reopen_layout")
	await action("play", {"ticks": 4})
	await action("wait_ticks", {"ticks": 4})
	await action("pause")
	await action("single_step")
	await action("pause")
	var invalid: Dictionary = await adapter.execute({"id": "brush", "args": {"x": -1, "y": 40, "radius": 0}})
	check(invalid.status == "refused" and invalid.classification == "invalid_action", "out-of-range refusal stays a harness validation result")
	var unsupported: Dictionary = await adapter.execute({"id": "unsupported_fixture_action", "args": {}})
	check(unsupported.status == "refused" and unsupported.classification == "not_applicable", "unsupported vocabulary is not an application defect")
	installed = await adapter.install_fixture("actor_workshop", Fixtures.build("actor_workshop", adapter.policy()))
	assertions.reset(installed)
	if check(installed.get("ok", false), "actual native/Rapier actor workshop installed"):
		var protected_edit: Dictionary = await action("brush", {"x": 96, "y": 160, "radius": 0}, "refused")
		check(protected_edit.classification == "not_applicable" and protected_edit.admission.is_empty(),
			"body-covered readback refuses bounded editing before native mutation admission")
		check(protected_edit.capture_before.get("native_receipt", {}).get("reason", "") == Adapter.BODY_CAPTURE_REFUSAL,
			"bounded refusal retains the actual native body-protection receipt")
		var actor_saved: Dictionary = await action("save_layout")
		check(actor_saved.persistence.native_material_equality_applicable == false \
			and actor_saved.persistence.native_material_equality_reason == "native_body_protection",
			"normal authored actor Save succeeds with explicitly unavailable full material comparison")
		check(actor_saved.persistence_capture.native_receipt.get("reason", "") == Adapter.BODY_CAPTURE_REFUSAL \
			and actor_saved.persistence_capture.native_receipt.get("status", "") == "refused",
			"actor Save retains genuine full-canvas native protection refusal")
		var actor_reopened: Dictionary = await action("reopen_layout")
		check(actor_reopened.persistence.native_material_equality_applicable == false \
			and actor_reopened.persistence.saved_capture == actor_saved.persistence_capture,
			"actor Reopen retains prior capture evidence while authored identity remains independently checked")
		await action("actor_select", {"actor_id": 1})
		await action("actor_place", {"model": "kestrel", "x": 280, "y": 96})
		await action("actor_pilot", {"actor_id": 3})
		await action("play", {"ticks": 4})
		var driven: Dictionary = await action("actor_drive", {"direction": "up", "ticks": 8})
		check(not driven.get("actor_input_observation", {}).get("actors", []).is_empty(), "actual actor input observations retained")
		for direction: String in ["left", "right", "down"]:
			await action("actor_drive", {"direction": direction, "ticks": 3})
		await action("pause")
		await action("actor_reset")
		await action("single_step")
		await action("actor_select", {"actor_id": 2})
		var passive: Dictionary = await adapter.execute({"id": "actor_pilot", "args": {"actor_id": 2}})
		check(passive.status == "refused" and passive.classification == "not_applicable", "passive barrel is not a player-controlled actor")
		check(adapter.observe().pilot_actor == 3, "passive selection/refusal preserves actual pilot authority")
	installed = await adapter.install_fixture("construction", Fixtures.build("construction", adapter.policy()))
	assertions.reset(installed)
	if check(installed.get("ok", false), "fresh fixture for in-flight Stop"):
		stop_when_editor_busy = true
		var interrupted: Dictionary = await adapter.execute({"id": "brush", "args": {"x": 80, "y": 80, "radius": 4}})
		records.append(interrupted)
		check(not stop_when_editor_busy, "Stop actually issued while an ordinary editor operation was pending")
		check(interrupted.classification == "cancelled" and interrupted.status in ["refused", "partial"],
			"in-flight Stop reports real cancellation/partial completion, not success")
		check(not adapter.editor.busy() and not bool(adapter.worker.paint_state().get("busy", true)), "Stop drains the real native/editor operation")
		check(not interrupted.get("editor_receipt", {}).is_empty(), "in-flight Stop retains its actual terminal editor receipt")
		if not interrupted.native_receipt.is_empty():
			check(interrupted.native_receipt.get("backend", "") == "CyberNativeCellWorld", "native Stop receipt identifies its actual backend")
		adapter.resume_actions()
		await action("pause")
		await action("select_region", {"x0": 64, "y0": 40, "x1": 71, "y1": 47})
		await action("copy")
		for planned: Dictionary in [
			{"id": "paste", "args": {"x": 96, "y": 64}},
			{"id": "brush", "args": {"x": 120, "y": 80, "radius": 2}},
		]:
			# The acceptance callback stops the real editor planner before its
			# first process frame. This tests receipt custody, not a product defect.
			stop_on_admission_id = planned.id
			var cancelled: Dictionary = await action(planned.id, planned.args, "refused")
			check(stop_on_admission_id.is_empty() and cancelled.classification == "cancelled", planned.id + " pre-native Stop was actually delivered")
			check(cancelled.native_receipt.is_empty(), planned.id + " pre-native Stop cannot borrow an earlier native receipt")
			for identity: String in ["generation", "revision", "tick"]:
				check(cancelled.before.native[identity] == cancelled.after.native[identity], planned.id + " pre-native Stop preserves native " + identity)
			if planned.id == "brush":
				check(cancelled.editor_receipt.get("status", "") == "cancelled", "brush records genuine application-only planner cancellation")
			adapter.resume_actions()
		var refused_fill: Dictionary = await adapter.execute({"id": "select_region", "args": {"x0": 400, "y0": 140, "x1": 415, "y1": 155}})
		check(refused_fill.status == "completed", "open-space selection for bounded Fill guard")
		refused_fill = await adapter.execute({"id": "fill", "args": {"x": 408, "y": 148}})
		check(refused_fill.status == "refused" and refused_fill.classification == "not_applicable", "unbounded connected Fill refused before native edit")
	adapter.request_stop()
	var stopped: Dictionary = await adapter.execute({"id": "play", "args": {"ticks": 4}})
	check(stopped.status == "refused" and stopped.classification == "cancelled", "Stop refuses further actions")
	check(adapter.observe().paused, "Stop leaves ordinary Workbench paused")
	await finish()

func finish() -> void:
	var report := {"evidence_kind": "actual_headless_godot", "checks": checks, "failures": failures,
		"records": records, "admissions": admissions, "godot": Engine.get_version_info(), "profile": Adapter.verify_profile()}
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute("user://goblin")
		var file := FileAccess.open("user://goblin/adapter-test.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		await process_frame
	print("GOBLIN_ADAPTER ", JSON.stringify({"checks": checks, "failures": failures, "records": records.size(), "evidence_kind": "actual_headless_godot"}))
	quit(1 if not failures.is_empty() else 0)
