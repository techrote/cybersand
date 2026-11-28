extends SceneTree

## Positive authored regression: real Sand motion in a sealed Wood cup.
## This is ordinary gameplay evidence, not a discovered-defect claim.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Controller = preload("res://goblin/goblin_controller.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const REGION := Rect2i(96, 48, 48, 48)
var adapter: Node
var oracle := Assertions.new()
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var report: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_GAMEPLAY " + label)
	return ok

func act(id: String, args: Dictionary = {}) -> bool:
	var row: Dictionary = await adapter.execute({"id":id,"args":args})
	row.assertions = oracle.evaluate(row)
	records.append(row)
	var ok: bool = check(row.status == "completed", "completed " + id + ": " + str(row.get("error", "")))
	for assertion: Dictionary in row.assertions:
		if assertion.status != "not_applicable": ok = check(assertion.status == "pass", id + "/" + assertion.id) and ok
	return ok

func material_positions(captured: Dictionary, material: int) -> Array[int]:
	var positions: Array[int] = []
	var values: Array = captured.get("materials", [])
	for index: int in range(values.size()):
		if int(values[index]) == material: positions.append(index)
	return positions

func vertical_sum(positions: Array[int]) -> int:
	var total := 0
	for index: int in positions: total += int(index / REGION.size.x)
	return total

func run() -> void:
	var launch: Dictionary = Controller.read_launch()
	if not check(launch.get("ok", false), "dedicated test profile before game mount"):
		await finish()
		return
	report = {"schema":"cybersand-goblin-material-gameplay-v1","evidence_kind":"headless_godot",
		"fixture_id":"construction","authored_regression":"sealed Wood cup with sixteen Sand cells",
		"naturally_discovered_defect":false,"provenance":launch.provenance,"region":Adapter.json_value(REGION)}
	adapter = Adapter.new()
	root.add_child(adapter)
	var mounted: Dictionary = await adapter.mount()
	if not check(mounted.get("ok", false), "ordinary Workbench mounted"):
		await finish()
		return
	var installed: Dictionary = await adapter.install_fixture("construction", Fixtures.build("construction", adapter.policy()))
	if not check(installed.get("ok", false), "committed construction fixture installed"):
		await finish()
		return
	oracle.reset(installed)
	var setup: Array[Dictionary] = [{"id":"pause","args":{}},
		{"id":"camera","args":{"x":0,"y":0,"width":480,"height":270}},
		{"id":"select_material","args":{"material":0}},
		{"id":"rectangle","args":{"x0":96,"y0":48,"x1":143,"y1":95}},
		{"id":"select_material","args":{"material":Setup.WOOD}},
		{"id":"outline","args":{"x0":96,"y0":48,"x1":143,"y1":95}},
		{"id":"select_material","args":{"material":Setup.SAND}},
		{"id":"rectangle","args":{"x0":116,"y0":56,"x1":119,"y1":59}}]
	for action: Dictionary in setup:
		if not await act(action.id, action.args):
			await finish()
			return
	var before: Dictionary = await adapter.capture(REGION)
	report.before_capture = before
	if not check(not before.has("error") and before.get("materials", []).size() == REGION.get_area(), "complete bounded native before capture"):
		await finish()
		return
	var before_sand: Array[int] = material_positions(before, Setup.SAND)
	var before_wood: Array[int] = material_positions(before, Setup.WOOD)
	check(before_sand.size() == 16, "sixteen independently captured Sand cells before Play")
	check(before_wood.size() == 188, "sealed 48 by 48 Wood boundary before Play")
	if not await act("play", {"ticks":16}) or not await act("pause"):
		await finish()
		return
	var after: Dictionary = await adapter.capture(REGION)
	report.after_capture = after
	if check(not after.has("error") and after.get("materials", []).size() == REGION.get_area(), "complete bounded native after capture"):
		var after_sand: Array[int] = material_positions(after, Setup.SAND)
		var after_wood: Array[int] = material_positions(after, Setup.WOOD)
		check(after_sand.size() == before_sand.size(), "Sand count conserved inside the closed cup")
		check(after_sand != before_sand, "Sand occupies different actual native cells after Play")
		check(vertical_sum(after_sand) > vertical_sum(before_sand), "Sand moved downward in the native simulation")
		check(after_wood == before_wood, "Wood boundary remained in the same actual native cells")
		check(int(after.native_receipt.tick) > int(before.native_receipt.tick), "captures bracket genuine native tick progression")
		report.motion = {"sand_before":before_sand.size(),"sand_after":after_sand.size(),
			"sand_vertical_sum_before":vertical_sum(before_sand),"sand_vertical_sum_after":vertical_sum(after_sand),
			"wood_cells":before_wood.size(),"native_tick_before":before.native_receipt.tick,"native_tick_after":after.native_receipt.tick}
	await finish()

func finish() -> void:
	report.checks = checks
	report.failures = failures
	report.records = records
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute("user://goblin")
		var file := FileAccess.open("user://goblin/gameplay-test.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t", true) + "\n")
			file.close()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		await process_frame
	print("GOBLIN_GAMEPLAY_RESULT ", JSON.stringify({"checks":checks,"failures":failures,
		"evidence_kind":"headless_godot","positive_authored_regression":true,"naturally_discovered_defect":false}))
	quit(0 if failures.is_empty() else 1)
