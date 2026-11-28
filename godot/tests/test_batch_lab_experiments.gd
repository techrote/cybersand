extends SceneTree
## Pure experiment/metric contracts; actual native execution is qualified separately.
const Experiments = preload("res://scripts/batch_lab/batch_lab_experiments.gd")
const Plan = preload("res://scripts/art_batch_plan.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	for family: String in Experiments.FAMILIES:
		for side: int in [2, 4]:
			var grid: Array[Dictionary] = Experiments.make_grid(family, side, 19301)
			_check(grid.size() == side * side, "%s %dx%d registered attempts" % [family, side, side])
			for index: int in range(grid.size()):
				var config: Dictionary = grid[index]
				_check(not config.has("error"), "configuration produced")
				var plan := Plan.new()
				_check(plan.configure(config.operations, Rect2i(0, 0, 128, 128)), "accepted Art parser admits %s" % family)
				_check(config.source_rectangles.size() == 4 and config.protection.size() == 1, "real source and protection fixtures declared")
				_check(config.evidence_kind == "deterministic-procedural-control" and not config.model_quality_claim, "control has no model-quality claim")
				_check(JSON.stringify(config.operations) == JSON.stringify(grid[(index / 4) * 4].operations), "matched variants do not alter control geometry")
				_check(config.budget_cells == 65536 and config.materials == [0,58], "equal explicit host budgets and permissions")
			var replay: Array[Dictionary] = Experiments.make_grid(family, side, 19301)
			_check(JSON.stringify(grid) == JSON.stringify(replay), "same config replay is deterministic")
		var a := Experiments.make_attempt(family, "P0", 19301, 128, 128)
		var b := Experiments.make_attempt(family, "P0", 19302, 128, 128)
		_check(JSON.stringify(a.operations) != JSON.stringify(b.operations), family + " seed changes construction")
		var random := Experiments.make_attempt(family, "P0", 19301, 128, 128, "seeded_random")
		_check(random.operations.size() == a.operations.size(), "random control retains component count")
		_check(JSON.stringify(random.operations) != JSON.stringify(a.operations), "random control relocates geometry")
		for i: int in range(a.operations.size()):
			var original: Dictionary = a.operations[i]
			var moved: Dictionary = random.operations[i]
			_check(original.x1 - original.x0 == moved.x1 - moved.x0 and original.y1 - original.y0 == moved.y1 - moved.y0, "random control retains component area")
		var random_plan := Plan.new()
		_check(random_plan.configure(random.operations, Rect2i(0,0,128,128)), "random control retains valid Art geometry")
		var p0 := Experiments.prompt_for(family, "P0", [128,128], 1)
		var p2 := Experiments.prompt_for(family, "P2", [128,128], 1)
		var p3 := Experiments.prompt_for(family, "P3", [128,128], 1)
		_check(p0.tool_contract == p3.tool_contract, "P3 does not add capabilities")
		_check(p0.reference_delivery == "none" and p2.reference_delivery == "grounded-card-only", "reference delivery is explicit")
		_check("visible_observations" in p2.text and "native_proposal" in p2.text, "observation/inference boundary retained")
		_check(not "final-" in str(a.group_id), "held-out structural families absent from example picker")
	_check(Experiments.make_grid("architecture", 3, 1).is_empty(), "unsupported grid refuses")
	_check(Experiments.make_attempt("architecture", "P9", 1, 128,128).has("error"), "unknown prompt refuses")
	_check(Experiments.make_attempt("architecture", "P0", 1, 513,128).has("error"), "oversized template refuses")
	_metrics_controls()
	print("Batch Lab experiment/metric script contracts: %d checks, %d failures. Not native execution evidence." % [checks, failures])
	quit(1 if failures else 0)

func _metrics_controls() -> void:
	var config := {"extent": [16,16], "source_region": [0,0,16,16], "protection": [[1,1,1,1]],
		"metrics_targets": {"structural_materials": [58], "require_connected": true,
		"route": [[2,13],[13,13]], "clearance_radius": 1,
		"features": [{"name":"pipe", "rect":[2,5,12,1], "minimum_fraction":1.0}], "minimum_empty_fraction":0.5}}
	var before := PackedInt32Array()
	before.resize(256)
	before[17] = 28
	var after := before.duplicate()
	for x: int in range(2,14): after[5 * 16 + x] = 58
	var good := Experiments.evaluate_materials(config, before, after)
	_check(good.valid and good.structural_checks_pass, "connected pipe plus clear route passes geometric diagnostics")
	_check(good.changed_cells == 12 and good.structural_components == 1, "exact count/components on known plane")
	after[5 * 16 + 7] = 0
	var broken := Experiments.evaluate_materials(config, before, after)
	_check(broken.structural_components == 2 and not broken.structural_checks_pass, "disconnected pipe negative retained")
	after[17] = 58
	var protection := Experiments.evaluate_materials(config, before, after)
	_check(protection.protected_changed_cells == 1 and not protection.structural_checks_pass, "protected-source corruption detected")
	for y: int in range(16): after[y * 16 + 8] = 58
	var blocked := Experiments.evaluate_materials(config, before, after)
	_check(not blocked.clearance.connected and not blocked.structural_checks_pass, "clearance barrier detected")
	config.source_region = [0,0,4,16]
	var scope := Experiments.evaluate_materials(config, before, after)
	_check(scope.outside_scope_changed_cells == 0, "input source region cannot redefine local result coordinates")
	_check(not Experiments.evaluate_materials(config, before, PackedInt32Array()).valid, "truncated native plane refuses")
