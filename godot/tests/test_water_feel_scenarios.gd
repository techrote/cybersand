extends SceneTree

const Contract = preload("res://scripts/water_experiment_contract.gd")
const Scenarios = preload("res://scripts/water_feel_scenarios.gd")
const EXPECTED_CATALOGUE_HASH: String = \
	"36fca816b62774809b5c744b9f121afed32e01ce1691a98e3fbf64687536d96c"

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalogue_completeness_and_bounds()
	_test_deterministic_identity_and_fresh_values()
	_test_reference_isolation()
	_test_steps_downhill_fixture()
	_test_invalid_identity()
	if _failures == 0:
		print(
			"Water Feel scenarios: %d recipes, catalogue %s"
			% [Contract.SCENARIO_IDS.size(), Scenarios.catalogue_hash(0)]
		)
	quit(_failures)


func _test_catalogue_completeness_and_bounds() -> void:
	_expect(Scenarios.ids() == Contract.SCENARIO_IDS, "scenario registry diverged from contract")
	var catalogue_hash: String=Scenarios.catalogue_hash(0)
	_expect(
		catalogue_hash == EXPECTED_CATALOGUE_HASH,
		"seed-0 catalogue identity changed: "+catalogue_hash
	)
	var identities: Dictionary = {}
	for scenario_id: String in Contract.SCENARIO_IDS:
		var value: Dictionary = Scenarios.recipe(scenario_id, 0)
		_expect(not value.is_empty(), "%s recipe is empty" % scenario_id)
		_expect(int(value.get("version", 0)) == Scenarios.VERSION, "%s version changed" % scenario_id)
		_expect(str(value.get("scenario_id", "")) == scenario_id, "%s identity changed" % scenario_id)
		_expect(bool(value.get("paused", false)), "%s does not start paused" % scenario_id)
		_validate_rectangles(scenario_id, value.get("rectangles", PackedInt32Array()))
		_validate_water_fills(scenario_id, value.get("partial_water_fills", PackedInt32Array()))
		_validate_actions(scenario_id, value.get("actions", []))
		_validate_point(scenario_id, "camera", value.get("camera_origin", Vector2i(-1, -1)))
		_validate_point(scenario_id, "player", value.get("player_start", Vector2i(-1, -1)))
		var identity: String = Scenarios.recipe_hash(value)
		_expect(identity.length() == 64, "%s SHA-256 identity is malformed" % scenario_id)
		_expect(not identities.has(identity), "%s duplicated another recipe identity" % scenario_id)
		identities[identity] = scenario_id


func _test_deterministic_identity_and_fresh_values() -> void:
	for scenario_id: String in Contract.SCENARIO_IDS:
		var first: Dictionary = Scenarios.recipe(scenario_id, 7)
		var second: Dictionary = Scenarios.recipe(scenario_id, 7)
		_expect(
			Scenarios.recipe_hash(first) == Scenarios.recipe_hash(second),
			"%s did not repeat deterministically" % scenario_id
		)
		_expect(
			Scenarios.recipe_hash(first) != Scenarios.recipe_hash(Scenarios.recipe(scenario_id, 8)),
			"%s seed was absent from recipe identity" % scenario_id
		)
	var mutated: Dictionary = Scenarios.recipe("shallow-pool", 0)
	var original_hash: String = Scenarios.recipe_hash(mutated)
	var rectangles: PackedInt32Array = mutated["rectangles"]
	rectangles[0] = 99
	mutated["rectangles"] = rectangles
	_expect(
		Scenarios.recipe_hash(Scenarios.recipe("shallow-pool", 0)) == original_hash,
		"recipe calls shared mutable rectangle storage"
	)


func _test_reference_isolation() -> void:
	for scenario_id: String in Contract.SCENARIO_IDS:
		var body_enabled: bool = bool(Scenarios.recipe(scenario_id, 0).get("body_enabled", false))
		_expect(
			body_enabled == (scenario_id == "supported-body-water"),
			"%s has incorrect supported-body isolation" % scenario_id
		)

	var mercury: Dictionary = Scenarios.recipe("mercury-reference", 0)
	_expect(
		PackedInt32Array(mercury["partial_water_fills"]).is_empty(),
		"Mercury reference contains Water fill records"
	)
	_expect(
		_has_rectangle_material(mercury["rectangles"], Scenarios.MERCURY),
		"Mercury reference does not contain Mercury"
	)
	for action: Dictionary in mercury["actions"]:
		_expect(int(action["material"]) != Scenarios.WATER, "Mercury action applies Water semantics")

	var baseline: Dictionary = Scenarios.recipe("water-sand-baseline", 0)
	var metadata: Dictionary = baseline["metadata"]
	_expect(str(metadata["transport_profile"]) == "Baseline", "Water/Sand profile is not Baseline")
	_expect(bool(metadata["transport_locked"]), "Water/Sand Baseline intent is not locked")
	_expect(_has_rectangle_material(baseline["rectangles"], Scenarios.SAND), "Water/Sand lacks Sand")
	_expect(
		not PackedInt32Array(baseline["partial_water_fills"]).is_empty(),
		"Water/Sand lacks Water"
	)


func _test_steps_downhill_fixture() -> void:
	var value: Dictionary=Scenarios.recipe("steps",0)
	var rectangles: PackedInt32Array=PackedInt32Array(value["rectangles"])
	# Four world-bound rectangles plus one retaining wall precede the seven treads.
	var first_step_offset: int=5*Scenarios.RECTANGLE_STRIDE
	var previous_top: int=-1
	for index: int in range(7):
		var offset: int=first_step_offset+index*Scenarios.RECTANGLE_STRIDE
		var x: int=rectangles[offset]
		var top: int=rectangles[offset+1]
		var width: int=rectangles[offset+2]
		var height: int=rectangles[offset+3]
		_expect(x==80+index*45,"steps tread x-position changed at %d"%index)
		_expect(width==45,"steps tread width changed at %d"%index)
		_expect(top+height==256,"steps tread does not share the floor baseline at %d"%index)
		if previous_top>=0:_expect(top>previous_top,"steps terrain is not downhill left-to-right at %d"%index)
		previous_top=top
	var fills: PackedInt32Array=PackedInt32Array(value["partial_water_fills"])
	_expect(fills.size()>=Scenarios.WATER_FILL_STRIDE,"steps Water fill missing")
	if fills.size()>=Scenarios.WATER_FILL_STRIDE:
		_expect(fills[0]==82 and fills[1]==84 and fills[2]==42 and fills[3]==38,"steps Water start block changed")
		_expect(fills[1]+fills[3]==rectangles[first_step_offset+1],"steps Water does not rest on the highest tread")
	var actions: Array=value["actions"]
	_expect(actions.size()==1 and str(actions[0].get("kind",""))=="sample","steps fixture should observe downhill flow without an artificial release gate")



func _test_invalid_identity() -> void:
	_expect(Scenarios.recipe("not-registered", 0).is_empty(), "unknown scenario was accepted")
	_expect(Scenarios.recipe("shallow-pool", -1).is_empty(), "negative seed was accepted")
	_expect(
		Scenarios.recipe("shallow-pool", Scenarios.MAX_SEED + 1).is_empty(),
		"oversized seed was accepted"
	)


func _validate_rectangles(scenario_id: String, value: Variant) -> void:
	var rectangles: PackedInt32Array = PackedInt32Array(value)
	_expect(not rectangles.is_empty(), "%s has no construction rectangles" % scenario_id)
	_expect(rectangles.size() % Scenarios.RECTANGLE_STRIDE == 0, "%s rectangle stride" % scenario_id)
	for offset: int in range(0, rectangles.size(), Scenarios.RECTANGLE_STRIDE):
		_validate_region(
			scenario_id,
			rectangles[offset], rectangles[offset + 1],
			rectangles[offset + 2], rectangles[offset + 3]
		)


func _validate_water_fills(scenario_id: String, value: Variant) -> void:
	var fills: PackedInt32Array = PackedInt32Array(value)
	_expect(fills.size() % Scenarios.WATER_FILL_STRIDE == 0, "%s Water-fill stride" % scenario_id)
	if scenario_id != "mercury-reference":
		_expect(not fills.is_empty(), "%s has no Water fill record" % scenario_id)
	for offset: int in range(0, fills.size(), Scenarios.WATER_FILL_STRIDE):
		_validate_region(scenario_id, fills[offset], fills[offset + 1], fills[offset + 2], fills[offset + 3])
		_expect(fills[offset + 4] >= 1 and fills[offset + 4] <= 255, "%s Water mass out of range" % scenario_id)
		_expect(fills[offset + 5] >= 0 and fills[offset + 5] <= 12, "%s coherence out of range" % scenario_id)


func _validate_actions(scenario_id: String, value: Variant) -> void:
	var actions: Array = value as Array
	_expect(not actions.is_empty(), "%s has no tick-relative action" % scenario_id)
	_expect(actions.size() <= Scenarios.MAX_ACTIONS, "%s action list is unbounded" % scenario_id)
	var previous_tick: int = -1
	for action_value: Variant in actions:
		var action: Dictionary = action_value as Dictionary
		var tick: int = int(action.get("tick", -1))
		_expect(tick >= previous_tick, "%s actions are not tick ordered" % scenario_id)
		_expect(tick <= Scenarios.MAX_ACTION_TICK, "%s action tick is unbounded" % scenario_id)
		var kind: String = str(action.get("kind", ""))
		_expect(kind in ["fill", "erase", "sample"], "%s action kind is invalid" % scenario_id)
		_validate_region(
			scenario_id,
			int(action.get("x", -1)), int(action.get("y", -1)),
			int(action.get("width", 0)), int(action.get("height", 0))
		)
		var normalized_mass: int = int(action.get("normalized_mass", -1))
		var coherence: int = int(action.get("coherence", -1))
		_expect(normalized_mass >= 0 and normalized_mass <= 255, "%s action mass" % scenario_id)
		_expect(coherence >= 0 and coherence <= 12, "%s action coherence" % scenario_id)
		if kind == "fill":
			_expect(int(action.get("material", -1)) == Scenarios.WATER, "%s fill is not Water" % scenario_id)
			_expect(normalized_mass > 0, "%s fill has zero mass" % scenario_id)
		previous_tick = tick
		previous_tick = tick
		_expect(str(action.get("kind", "")) in ["sample", "fill", "erase"], "%s action kind" % scenario_id)
		_validate_region(
			scenario_id,
			int(action.get("x", -1)), int(action.get("y", -1)),
			int(action.get("width", 0)), int(action.get("height", 0))
		)


func _validate_region(scenario_id: String, x: int, y: int, width: int, height: int) -> void:
	_expect(
		x >= 0 and y >= 0 and width > 0 and height > 0
			and x + width <= Scenarios.WORLD_SIDE and y + height <= Scenarios.WORLD_SIDE,
		"%s contains out-of-bounds region %d,%d %dx%d" % [scenario_id, x, y, width, height]
	)


func _validate_point(scenario_id: String, label: String, value: Variant) -> void:
	var point: Vector2i = Vector2i(value)
	_expect(
		point.x >= 0 and point.y >= 0
			and point.x < Scenarios.WORLD_SIDE and point.y < Scenarios.WORLD_SIDE,
		"%s %s point is out of bounds" % [scenario_id, label]
	)


func _has_rectangle_material(value: Variant, material: int) -> bool:
	var rectangles: PackedInt32Array = PackedInt32Array(value)
	for offset: int in range(0, rectangles.size(), Scenarios.RECTANGLE_STRIDE):
		if rectangles[offset + 4] == material:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
