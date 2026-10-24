extends SceneTree

# LCB-003 scenario catalogue regression. For every registry scenario (the two
# PR #215 protected fixtures plus the v1 catalogue) it checks, on the current
# native runtime: contract admission and pinned canonical hash, the
# Python-derived initial inventory against the complete native tick-0 material
# map over the whole frame (H2: every species both ways, and the occupied
# bounding box), the measured tick-30 content/state hashes, and identical
# 1/4-worker results. It independently checks that only Current-default
# mappings can be executable (H1). It does not run full horizons or any
# non-default family.
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const REGISTRY: String = "res://tests/fixtures/lcb/lcb-scenario-registry.json"
const NAME_TO_ID: Dictionary = {"sand":2, "water":3, "smoke":4, "fire":6, "oil":16, "paste":20, "slush":21,
	"steam":22, "salt":23, "brine":24, "sodium":25, "mercury":33}
const SIDE: int = 1024
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var source: Dictionary = Runner.read_text(REGISTRY)
	expect(source.ok, "Scenario registry unavailable")
	if not source.ok:
		quit(1)
		return
	var registry: Dictionary = JSON.parse_string(source.text)
	expect(str(registry.get("schema", "")) == "lcb-scenario-registry-v1", "Unexpected registry schema")
	var ids: Dictionary = {}
	for entry: Dictionary in registry.scenarios:
		expect(not ids.has(entry.id), "Duplicate scenario id " + str(entry.id))
		ids[entry.id] = true
		_check_arms(entry)
		_check_scenario(entry)
	expect(ids.size() >= 27, "Registry lost scenarios")
	print("LCB scenario catalogue: %d scenarios, %d assertions, %d failures" % [ids.size(), assertions, failures])
	quit(1 if failures > 0 else 0)

# Independent of the registry builder (H1): water defaults to freemass_v1 and
# every other liquid to cellular_yield_v1, both with the reference variant.
func _current_mapping(mapping: Dictionary) -> bool:
	for material: Variant in mapping:
		var value: String = str(mapping[material])
		var family: String = value.get_slice("/", 0)
		var variant: String = value.get_slice("/", 1) if value.contains("/") else "reference"
		var expected: String = "freemass_v1" if str(material) == "water" else "cellular_yield_v1"
		if family != expected or variant != "reference": return false
	return true

func _check_arms(entry: Dictionary) -> void:
	for arm: Dictionary in entry.arms:
		var executable: bool = bool(arm.get("executable_today", false))
		var status: String = str(arm.status)
		expect(executable == status.begins_with("measured"),
			entry.id + "/" + str(arm.id) + ": executable flag disagrees with status " + status)
		var current: bool = _current_mapping(arm.get("mapping", {}))
		expect(current or (not executable and status == "blocked"),
			entry.id + "/" + str(arm.id) + ": candidate mapping is not blocked (status " + status + ")")
		if status == "blocked":
			expect(not arm.get("depends_on", []).is_empty(), entry.id + "/" + str(arm.id) + ": blocked arm has no dependency")

func _check_scenario(entry: Dictionary) -> void:
	var source: Dictionary = Runner.read_text(str(entry.definition.res_path))
	expect(source.ok, entry.id + ": definition unavailable")
	if not source.ok: return
	var installed: Dictionary = Runner.install(source.text, 1)
	expect(installed.ok, entry.id + ": install refused: " + str(installed.get("error", "")))
	if not installed.ok: return
	expect(installed.hash == entry.definition.canonical_hash, entry.id + ": canonical definition hash changed")
	var inventory: Dictionary = entry.setup.initial_inventory
	_check_inventory(entry.id, installed.world, inventory)
	var tick0: Dictionary = installed.world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024))
	expect(int(tick0.water_integer) == int(inventory.water_integer), entry.id + ": initial Water quantity differs")
	installed.clear()
	var goldens: Variant = entry.get("goldens")
	expect(goldens != null and goldens.tick30 != null, entry.id + ": no measured tick-30 golden")
	if goldens == null or goldens.tick30 == null: return
	var one: Dictionary = Runner.run_text(source.text, 1, 30)
	var four: Dictionary = Runner.run_text(source.text, 4, 30)
	expect(one.status == "completed" and four.status == "completed", entry.id + ": prefix run did not complete")
	if one.status != "completed" or four.status != "completed": return
	var last: Dictionary = one.checkpoints[-1]
	expect(int(last.tick) == 30, entry.id + ": prefix ended at the wrong tick")
	expect(last.content_hash == goldens.tick30.content_hash and last.state_hash == goldens.tick30.state_hash
		and int(last.water_integer) == int(goldens.tick30.water_integer),
		entry.id + ": tick-30 Current hashes differ from the measured control")
	expect(one.checkpoints == four.checkpoints and one.capture.observations == four.capture.observations,
		entry.id + ": 1/4-worker prefix results differ")

# H2: the derived inventory must equal the complete native tick-0 material map.
# One bounded whole-frame scan (Empty and Wall excluded) checks every species in
# both directions and the occupied bounding box, so an omitted or extra species,
# or a shrunken region, cannot pass.
func _check_inventory(id: String, world: Variant, inventory: Dictionary) -> void:
	var counts: Dictionary = {}
	var low := Vector2i(SIDE, SIDE)
	var high := Vector2i(-1, -1)
	for y: int in range(SIDE):
		for x: int in range(SIDE):
			var material: int = int(world.material_at(x, y))
			if material > 1:
				counts[material] = int(counts.get(material, 0)) + 1
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	var expected: Dictionary = {}
	for name: String in inventory.cells:
		expect(NAME_TO_ID.has(name), id + ": derived inventory names an unmapped material " + name)
		if NAME_TO_ID.has(name): expected[NAME_TO_ID[name]] = int(inventory.cells[name])
	for material: int in counts:
		expect(expected.has(material), id + ": native tick 0 has material %d absent from the derived inventory" % material)
	for material: int in expected:
		expect(int(counts.get(material, 0)) == int(expected[material]),
			id + ": initial material %d cells differ from the derived inventory" % material)
	var box: Array = [low.x, low.y, high.x - low.x + 1, high.y - low.y + 1] if high.x >= 0 else [0, 0, 0, 0]
	expect(box == Array(inventory.material_region).map(func(v: Variant) -> int: return int(v)),
		id + ": native occupied region %s differs from the derived material_region" % str(box))
