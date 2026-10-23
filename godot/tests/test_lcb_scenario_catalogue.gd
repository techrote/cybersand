extends SceneTree

# LCB-003 scenario catalogue regression. For every registry scenario (the two
# PR #215 protected fixtures plus the v1 catalogue) it checks, on the current
# native runtime: contract admission and pinned canonical hash, the
# Python-derived initial inventory, the measured tick-30 content/state hashes,
# and identical 1/4-worker results. It also checks that no blocked arm claims
# to be executable. It does not run full horizons or any non-default family.
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const REGISTRY: String = "res://tests/fixtures/lcb/lcb-scenario-registry.json"
const NAME_TO_ID: Dictionary = {"sand":2, "water":3, "oil":16, "paste":20, "slush":21, "salt":23,
	"brine":24, "sodium":25, "mercury":33}
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

func _check_arms(entry: Dictionary) -> void:
	for arm: Dictionary in entry.arms:
		var executable: bool = bool(arm.get("executable_today", false))
		var status: String = str(arm.status)
		expect(executable == status.begins_with("measured"),
			entry.id + "/" + str(arm.id) + ": executable flag disagrees with status " + status)
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
	var counts: Dictionary = Runner.material_counts(installed.world, inventory.material_region)
	for name: String in inventory.cells:
		expect(int(counts.get(NAME_TO_ID[name], 0)) == int(inventory.cells[name]),
			entry.id + ": initial " + name + " cells differ from the derived inventory")
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
