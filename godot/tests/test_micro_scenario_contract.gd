extends SceneTree

const Contract = preload("res://scripts/micro_scenario_contract.gd")
const Catalogue = preload("res://scripts/micro_scenario_catalogue.gd")
const Host = preload("res://scripts/micro_scenario_host.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error(message)

func _run() -> void:
	for id: String in Catalogue.ids():
		var raw: Dictionary = Catalogue.definition(id, 0)
		var checked: Dictionary = Contract.validate(raw)
		expect(checked.get("ok", false), "%s contract rejected: %s" % [id, checked.get("error", "")])
		if not checked.get("ok", false): continue
		var roundtrip: Dictionary = Contract.validate(JSON.parse_string(JSON.stringify(checked.definition)))
		expect(roundtrip.get("ok", false) and roundtrip.get("hash") == checked.hash,
			"JSON round-trip changed %s" % id)
		if id.begins_with("water/"):
			var recipe: Dictionary = CyberWaterFeelScenarios.recipe(id.trim_prefix("water/"), 0)
			expect(checked.definition.legacy.recipe_hash == CyberWaterFeelScenarios.recipe_hash(recipe), "legacy hash changed")
			expect(PackedInt32Array(checked.definition.rectangles) == recipe.rectangles, "legacy rectangles changed")
			expect(PackedInt32Array(checked.definition.partial_water_fills) == recipe.partial_water_fills, "legacy fills changed")
			expect(checked.definition.events == recipe.actions, "legacy event order changed")
	var base: Dictionary = Catalogue.definition("communicating-reservoirs", 17)
	for edit: Dictionary in [ {"schema_version": 2}, {"seed": -1}, {"seed": 1.5},
		{"id": "../invalid."}, {"player_start": [-1,0]}, {"tools": ["write_cell"]},
		{"body_enabled": "true"}, {"rectangles": [0,0,1025,1,1]}, {"rectangles": [0,0,1,1,81]},
		{"transport": {"version": 999}}, {"water_policy": {"mass_bits": 2}},
		{"events": [{"kind": "arbitrary_script"}]} ]:
		var bad: Dictionary = base.duplicate(true)
		bad.merge(edit, true)
		expect(not Contract.validate(bad).ok, "invalid contract admitted: %s" % edit)
	var unknown: Dictionary = base.duplicate(true)
	unknown["per_tick_callback"] = "not-permitted"
	expect(not Contract.validate(unknown).ok, "unknown callback field accepted")
	var unsorted: Dictionary = base.duplicate(true)
	unsorted.events[0].tick = 121
	expect(not Contract.validate(unsorted).ok, "unsorted events accepted")
	var overflow: Dictionary = base.duplicate(true)
	for i: int in range(25): overflow.events.append(base.events[-1].duplicate())
	expect(not Contract.validate(overflow).ok, "event overflow accepted")
	var bad_condition: Dictionary = base.duplicate(true)
	bad_condition.conditions[0].event_index = 0
	expect(not Contract.validate(bad_condition).ok, "mutation event used as objective probe")
	expect(Catalogue.definition("experiment-tower", 1).is_empty(), "Tower's fixed seed changed")
	expect(Catalogue.definition("issue20-ballistics", 0).is_empty(), "unadmitted #20 fixture exists")
	print("MS-000 contract: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
