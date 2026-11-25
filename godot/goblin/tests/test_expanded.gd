extends SceneTree

## Ordinary Workbench execution of the successor vocabulary in an isolated profile.
## This is a positive integration qualification, not a discovered game defect.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Gameplay = preload("res://goblin/goblin_gameplay_actions.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Capabilities = preload("res://goblin/goblin_capabilities.gd")
var adapter: Node
var oracle: RefCounted
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var observed := {}


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_EXPANDED " + label)


func action(id: String, args: Dictionary = {}, expected: String = "completed") -> Dictionary:
	print("GOBLIN_EXPANDED_PROPOSED ", JSON.stringify({"index": records.size(), "id": id, "args": args}))
	var row: Dictionary = await adapter.execute({"id": id, "args": args})
	row["assertions"] = oracle.evaluate(row)
	records.append(row)
	check(row.status == expected, id + " terminal " + str(row.status) + ": " + str(row.error))
	for result: Dictionary in row.assertions:
		check(result.status != "fail", id + " / " + result.id + " / " + str(result.actual))
	if row.status == "completed" and row.admission.get("accepted", false): observed[id] = true
	print("GOBLIN_EXPANDED_OBSERVED ", JSON.stringify({"id": id, "status": row.status, "classification": row.classification}))
	return row


func run() -> void:
	check(Adapter.ACTION_IDS.size() == 55, "55 distinct bounded operations are declared")
	check(Fixtures.IDS.size() >= 8, "at least eight committed authored scenarios")
	for invalid: Dictionary in [
		{"id": "select_tool", "args": {"tool": "execute"}},
		{"id": "actor_control", "args": {"actor_id": 1, "producer": "shell", "enabled": true}},
		{"id": "source_stream", "args": {"enabled": 1}},
		{"id": "actor_settings", "args": {"field": "mass_multiplier", "value": INF}},
		{"id": "stroke", "args": {"x0": 8, "y0": 8, "x1": 80, "y1": 8, "radius": 1}},
		{"id": "replace_fixture", "args": {"fixture": "../../owner-save"}},
	]: check(not Adapter.validate_action(invalid).ok, "invalid expanded action refuses: " + invalid.id)
	for feature: Dictionary in Capabilities.negotiate().families.values():
		check(not feature.enabled and feature.actions.is_empty(), "unregistered programme adapter stays disabled")
	check(not Capabilities.validate_offer({"schema": Capabilities.SCHEMA, "version": 1, "feature": "art",
		"source": "invalid", "actions": ["send_command"]}).ok, "unpinned feature offer refused")
	adapter = Adapter.new()
	root.add_child(adapter)
	oracle = Assertions.new()
	var mounted: Dictionary = await adapter.mount()
	check(mounted.get("ok", false), "actual Workbench mounted: " + str(mounted.get("error", "")))
	if not mounted.get("ok", false):
		await finish()
		return
	for fixture: String in Fixtures.IDS:
		var data: Dictionary = Fixtures.build(fixture, adapter.policy())
		check(not data.is_empty() and Adapter.Setup.validate(data).is_empty(), "native authored recipe valid: " + fixture)
	var installed: Dictionary = await adapter.install_fixture("history_edges", Fixtures.build("history_edges", adapter.policy()))
	check(installed.get("ok", false), "history fixture actually installed")
	if not installed.get("ok", false):
		await finish()
		return
	await action("select_tool", {"tool": "Rectangle"})
	await action("brush_radius", {"radius": 2})
	await action("select_material", {"material": 7})
	await action("stroke", {"x0": 120, "y0": 48, "x1": 136, "y1": 56, "radius": 2})
	await action("undo")
	await action("redo")
	await action("preview_begin", {"x0": 160, "y0": 48, "x1": 176, "y1": 56})
	await action("preview_cancel")
	await action("interrupt_stroke", {"x0": 200, "y0": 48, "x1": 224, "y1": 64})
	await action("camera_pan", {"dx": 32, "dy": 32})
	await action("camera_zoom", {"direction": -1})
	await action("camera_mode", {"mode": "overview"})
	await action("camera_mode", {"mode": "free"})
	await action("actor_place", {"model": "runner", "x": 72, "y": 200})
	await action("actor_select", {"actor_id": 1})
	await action("camera_focus")
	await action("actor_move", {"x": 96, "y": 190})
	await action("actor_save_spawn", {"x": 112, "y": 180})
	await action("actor_capture_spawn")
	await action("actor_settings", {"field": "mass_multiplier", "value": 1.234})
	await action("actor_settings", {"field": "budget", "value": 15.4})
	for offered: Dictionary in adapter.available_actions():
		check(offered.id != "response_mode" or offered.args.mode != "RFT", "legal menu respects RFT body budget contract")
	await action("response_mode", {"mode": "RFT"}, "refused")
	for offered: Dictionary in adapter.available_actions():
		check(offered.id != "actor_settings", "legal tuning menu respects pending refused RFT form values")
	await action("response_mode", {"mode": "LA"})
	await action("actor_settings", {"field": "budget", "value": 20.0})
	await action("response_mode", {"mode": "RFT"})
	await action("actor_control", {"actor_id": 1, "producer": "scripted", "enabled": true})
	await action("actor_pilot", {"actor_id": 1})
	await action("actor_hand_back")
	await action("actor_pilot", {"actor_id": 1})
	await action("actor_release")
	await action("actor_pilot", {"actor_id": 1})
	var usable: int = Adapter.Setup.ActorCatalog.Usables.index_for(&"brick_stamper")
	check(usable >= 0 and usable < 32, "actual mounted equipment identity available")
	await action("actor_equipment", {"actor_id": 1, "usable_index": usable})
	await action("camera", {"x": 0, "y": 0, "width": 480, "height": 270})
	await action("select_material", {"material": 2})
	await action("source_place", {"x": 220, "y": 48})
	await action("source_place", {"x": 220, "y": 48})
	await action("play", {"ticks": 4})
	await action("actor_actuate", {"port": "q", "ticks": 4}, "refused")
	await action("actor_actuate", {"port": "primary", "ticks": 4})
	var trigger: Dictionary = await action("actor_trigger", {"button": "trigger", "ticks": 4})
	var effect: Dictionary = trigger.after.actors[0].control_observation.get("equipment", {}).get("last_receipt", {})
	check(effect.get("accepted", false) and effect.get("consumed", false) and int(effect.get("changed_cells", 0)) > 0,
		"ordinary Brick Stamper produced an actual accepted material-effect receipt")
	await action("live_stroke", {"x0": 260, "y0": 48, "x1": 276, "y1": 56, "radius": 2})
	await action("source_burst")
	await action("source_stream", {"enabled": true})
	await action("source_stream", {"enabled": true}, "refused")
	await action("source_place", {"x": 220, "y": 48})
	await action("source_burst")
	await action("source_stream", {"enabled": true})
	await action("source_stream", {"enabled": false})
	await action("pause")
	await action("actor_capture_spawn")
	await action("actor_replace", {"model": "kestrel"})
	await action("actor_remove")
	await action("restore_start")
	await action("replace_fixture", {"fixture": "conservation_cell"})
	for id: String in Gameplay.IDS:
		check(observed.has(id), "actual completed action observed: " + id)
	await finish()


func finish() -> void:
	var report := {"evidence_kind": "actual_headless_godot", "checks": checks, "failures": failures,
		"records": records, "completed_actions": observed.keys(), "godot": Engine.get_version_info(),
		"profile": Adapter.verify_profile(), "classification": "positive integration qualification"}
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute("user://goblin")
		var file := FileAccess.open("user://goblin/expanded-test.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		await process_frame
	print("GOBLIN_EXPANDED_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "completed_actions": observed.keys(), "records": records.size()}))
	quit(1 if not failures.is_empty() else 0)
