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
var actor_origin_experiments: Array[Dictionary] = []


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


func same_point(actual: Variant, expected: Array) -> bool:
	# Authored JSON numbers and actual Vector2 coordinates can use different
	# Variant numeric types. Compare exact finite values, never array type tags.
	if not actual is Array or actual.size() != 2 or expected.size() != 2: return false
	for index: int in range(2):
		if not (actual[index] is int or actual[index] is float) \
			or not (expected[index] is int or expected[index] is float): return false
		if not is_finite(float(actual[index])) or not is_finite(float(expected[index])) \
			or float(actual[index]) != float(expected[index]): return false
	return true


func check_origin(row: Dictionary, model: String, spawn: Array) -> void:
	# Independent native gate expectation, deliberately not the oracle helper.
	# The finite supported catalogue has one eccentric root: monowheel's cab.
	var expected: Array = [float(spawn[0]), float(spawn[1]) + (1.5 if model == "monowheel" else 0.0)]
	var selected: Dictionary = {}
	for actor: Dictionary in row.get("after", {}).get("actors", []):
		if actor.get("id") == row.after.get("selected_actor"): selected = actor
	var parts: Array = selected.get("state", {}).get("retained_parts", [])
	check(selected.get("model") == model and same_point(selected.get("authored_spawn"), spawn),
		"actual authored assembly origin / " + model + " / " + str(row.action.id))
	check(same_point(selected.get("position"), expected) and same_point(selected.get("state", {}).get("position"), expected),
		"actual first body matches independently expected root offset / " + model)
	check(not parts.is_empty() and same_point(parts[0].get("position"), expected),
		"actual retained first part matches root / " + model)
	if model == "monowheel":
		check(parts.size() >= 2 and same_point(parts[1].get("position"), spawn), "actual monowheel rim remains at assembly origin")
	check(row.after.get("actor_tick") == 0 and row.after.get("native", {}).get("tick") == 0 \
		and row.after.get("paused") == true, "origin relation observed before physical progression")
	actor_origin_experiments.append({"action_record": records.size() - 1, "action": row.action.duplicate(true),
		"model": model, "expected_authored_origin": spawn.duplicate(), "expected_physical_root": expected,
		"observed_physical_root": selected.get("position"), "observed_parts": parts.duplicate(true),
		"classification": "legal_unusual_gameplay", "gameplay_defect_confirmed": false})


func actor_origin_gate() -> void:
	var installed: Dictionary = await adapter.install_fixture("history_edges", Fixtures.build("history_edges", adapter.policy()))
	check(installed.get("ok", false), "actor-origin gate installs an actual paused disposable fixture")
	if not installed.get("ok", false): return
	oracle.reset(installed)
	for model: String in ["kestrel", "reference_barrel", "runner", "crawler", "monowheel", "stuntbuggy"]:
		var placed := await action("actor_place", {"model": model, "x": 256, "y": 96})
		check_origin(placed, model, [256, 96])
		var moved := await action("actor_move", {"x": 264, "y": 112})
		check_origin(moved, model, [264, 112])
		var reset := await action("actor_reset")
		check_origin(reset, model, [264, 112])
		var spawn: Array = [264, 112]
		if model == "monowheel":
			var capture := await action("actor_capture_spawn")
			check(capture.before.actors[0].position == capture.after.actors[0].position,
				"ordinary Capture changes only saved reset coordinates")
			spawn = [264.0, 113.5]
			var captured_reset := await action("actor_reset")
			check_origin(captured_reset, model, spawn)
			actor_origin_experiments.back()["capture_reset_observation"] = {
				"authored_origin_before_capture": [264, 112], "captured_physical_root": [264.0, 113.5],
				"reset_physical_root": [264.0, 115.0], "idempotence_contract_established": false,
				"scope": "existing Capture reads the first body; Reset interprets that saved value as assembly origin"}
		# The ordinary compact picker includes a placed non-flyer, not every
		# supported placement model. Same-model Replace creates a new instance
		# through that real picker; Runner -> Kestrel is exercised above.
		var replaced := await action("actor_replace", {"model": model})
		check_origin(replaced, model, spawn)
		await action("actor_remove")


func run() -> void:
	check(same_point([256.0, 96.0], [256, 96]), "test origin comparison admits equal numeric coordinates")
	check(not same_point([264.0, 113.50001], [264, 113.5]), "test origin comparison rejects any unequal coordinate")
	check(not same_point([true, 96], [1, 96]) and not same_point(["256", 96], [256, 96]),
		"test origin comparison rejects nonnumeric coordinates")
	check(not same_point([INF, 96], [INF, 96]) and not same_point([256], [256, 96]),
		"test origin comparison rejects nonfinite and malformed coordinates")
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
	oracle.reset(installed)
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
	await actor_origin_gate()
	for id: String in Gameplay.IDS:
		check(observed.has(id), "actual completed action observed: " + id)
	await finish()


func finish() -> void:
	var report := {"evidence_kind": "actual_headless_godot", "checks": checks, "failures": failures,
		"records": records, "completed_actions": observed.keys(), "godot": Engine.get_version_info(),
		"actor_origin_experiments": actor_origin_experiments,
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
