extends SceneTree

## Independent, preconditioned gameplay relationships. These positive controls
## qualify the observer; they are never reported as discovered production bugs.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
var adapter: Node
var oracle: RefCounted
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var experiments: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_METAMORPHIC " + label)


func action(id: String, args: Dictionary = {}) -> Dictionary:
	var row: Dictionary = await adapter.execute({"id": id, "args": args})
	row["assertions"] = oracle.evaluate(row)
	records.append(row)
	check(row.status == "completed", id + " completed: " + str(row.error))
	for result: Dictionary in row.assertions:
		check(result.status != "fail", id + " / " + result.id + " / " + str(result.actual))
	return row


func install(id: String) -> bool:
	var result: Dictionary = await adapter.install_fixture(id, Fixtures.build(id, adapter.policy()))
	check(result.get("ok", false), "actual fixture installed: " + id)
	oracle.reset()
	return bool(result.get("ok", false))


func capture(region: Rect2i) -> Dictionary:
	var observed: Dictionary = await adapter.capture(region)
	check(not observed.has("error") and observed.get("source_matches", false), "source-matched native capture: " + str(observed.get("error", "")))
	return observed


func count_material(captured: Dictionary, material: int) -> int:
	var count := 0
	for cell: Variant in captured.get("materials", []):
		if int(cell) == material: count += 1
	return count


func run() -> void:
	adapter = Adapter.new()
	root.add_child(adapter)
	oracle = Assertions.new()
	var mounted: Dictionary = await adapter.mount()
	check(mounted.get("ok", false), "actual ordinary Workbench mounted")
	if not mounted.get("ok", false):
		await finish()
		return
	if await install("history_edges"):
		# Both empty translated regions are wholly interior, paused, actor-free
		# and have identical initial materials. Only native cell arrays compare.
		var first_region := Rect2i(200, 64, 24, 24)
		var translated_region := Rect2i(248, 112, 24, 24)
		var first_start: Dictionary = await capture(first_region)
		var second_start: Dictionary = await capture(translated_region)
		check(first_start.get("materials") == second_start.get("materials"), "translation control precondition: equal initial native planes")
		await action("select_material", {"material": 7})
		await action("outline", {"x0": 204, "y0": 68, "x1": 219, "y1": 83})
		await action("outline", {"x0": 252, "y0": 116, "x1": 267, "y1": 131})
		var first_result: Dictionary = await capture(first_region)
		var translated_result: Dictionary = await capture(translated_region)
		check(first_result.get("materials") == translated_result.get("materials"), "interior translated outline has equal relative materials")
		experiments.append({"id": "translated_paused_outline", "preconditions": "equal empty interior planes, no actors, paused",
			"before": [first_start, second_start], "after": [first_result, translated_result]})
		var expected: Array = translated_result.get("materials", []).duplicate()
		await action("undo")
		var reversed: Dictionary = await capture(translated_region)
		check(reversed.get("materials") == second_start.get("materials"), "Undo restores actual observed preimage")
		await action("redo")
		var repeated: Dictionary = await capture(translated_region)
		check(repeated.get("materials") == expected, "Redo restores actual observed postimage")
		experiments.append({"id": "undo_redo_roundtrip", "preconditions": "same paused native owner and uninterrupted history",
			"before": translated_result, "undo": reversed, "redo": repeated})
		var identity: Dictionary = adapter.observe()
		var rejected: Dictionary = await adapter.execute({"id": "stroke", "args": {"x0": -1, "y0": 64, "x1": 16, "y1": 64, "radius": 2}})
		records.append(rejected)
		var after_rejection: Dictionary = await capture(first_region)
		check(rejected.status == "refused" and rejected.admission.is_empty(), "invalid boundary action refused before gameplay admission")
		check(after_rejection.get("materials") == first_result.get("materials") and identity.native == rejected.after.native,
			"rejected action has no forbidden native mutation")
		experiments.append({"id": "invalid_action_nonmutation", "preconditions": "paused settled World, no admission",
			"record": rejected, "readback": after_rejection})
		await action("save_layout")
		var saved_native: Dictionary = await capture(first_region)
		await action("erase", {"x": 204, "y": 68, "radius": 2})
		await action("reopen_layout")
		var reopened_native: Dictionary = await capture(first_region)
		check(saved_native.get("materials") == reopened_native.get("materials"), "authored Save/Reopen at tick zero preserves native material plane")
		experiments.append({"id": "authored_roundtrip", "preconditions": "saved at native tick zero, actor-free complete capture",
			"saved": saved_native, "reopened": reopened_native})
	if await install("conservation_cell"):
		# The 48x48 hard enclosure is the entire connected local system. Sand
		# has no reactive partner, emitter, actor or open edge in this region.
		var enclosure := Rect2i(48, 48, 48, 48)
		var before: Dictionary = await capture(enclosure)
		check(count_material(before, 2) == 64, "independently counted initial Sand = 64")
		check(count_material(before, 58) == 368, "independently counted hard enclosure = 368")
		for _step: int in 16: await action("single_step")
		var after: Dictionary = await capture(enclosure)
		check(count_material(after, 2) == count_material(before, 2), "isolated nonreactive Sand cell count conserved")
		check(count_material(after, 58) == count_material(before, 58), "hard enclosure count unchanged")
		check(after.get("materials") != before.get("materials"), "native Sand actually moved during exact steps")
		var sum_y_before := 0
		var sum_y_after := 0
		for index: int in before.get("materials", []).size():
			if int(before.materials[index]) == 2: sum_y_before += int(index / 48)
			if int(after.materials[index]) == 2: sum_y_after += int(index / 48)
		check(sum_y_after > sum_y_before, "independent Sand centre of mass moves downward")
		experiments.append({"id": "closed_sand_conservation", "preconditions": "hard sealed enclosure, 64 Sand, no reactions, actors or sources",
			"before": before, "after": after, "sum_y_before": sum_y_before, "sum_y_after": sum_y_after})
	await finish()


func finish() -> void:
	var report := {"evidence_kind": "actual_headless_godot", "checks": checks, "failures": failures,
		"records": records, "experiments": experiments, "godot": Engine.get_version_info(),
		"profile": Adapter.verify_profile(), "classification": "positive metamorphic qualification"}
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute("user://goblin")
		var file := FileAccess.open("user://goblin/metamorphic-test.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		await process_frame
	print("GOBLIN_METAMORPHIC_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "experiments": experiments.size(), "records": records.size()}))
	quit(1 if not failures.is_empty() else 0)
