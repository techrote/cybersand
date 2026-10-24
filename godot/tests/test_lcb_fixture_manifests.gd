extends SceneTree

# LCB-000 Gate E fixture protection. Both definitions are frozen MicroScenario
# schema-2 data run on unchanged Current native liquids. This checks contract
# admission, the pinned canonical hashes, initial-state proofs and a short
# deterministic prefix; it is not a solver-family or performance claim.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const DAM_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const MIX_PATH: String = "res://tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json"
const DAM_HASH: String = "494a017b0c7c9afed6923c84608f6fbd913b7040cf40e92fb18392f2d11119bf"
const MIX_HASH: String = "208d488fbc3a218d61ab4468bd6fb31ddcdfde4cc44d5b2f43061dcd6f2036cc"
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var dam: Dictionary = _load(DAM_PATH)
	var mix: Dictionary = _load(MIX_PATH)
	expect(dam.get("ok", false), "Protected Dam Break definition rejected: " + str(dam.get("error", "")))
	expect(mix.get("ok", false), "Mixed-liquid definition rejected: " + str(mix.get("error", "")))
	if failures == 0:
		expect(dam.hash == DAM_HASH, "Protected Dam Break definition changed; register a new version instead")
		expect(mix.hash == MIX_HASH, "Mixed-liquid definition changed; register a new version instead")
		for checked: Dictionary in [dam, mix]:
			var definition: Dictionary = checked.definition
			expect(definition.maturity == "reference" and definition.execution.policy == "fixed",
				definition.id + " is not a fixed reference setup")
			expect(not definition.player_enabled and not definition.body_enabled and definition.tools.is_empty(),
				definition.id + " controlled setup admits uncontrolled input")
			expect(definition.water_semantics == [1, 8, 12, 0], definition.id + " is not default mass8/coherence12 Water")
			expect(definition.transport_profile.name == "Baseline", definition.id + " is not Baseline transport")
		if ClassDB.class_exists(&"CyberNativeCellWorld"):
			_run_dam(dam.definition)
			_run_mix(mix.definition)
		else:
			expect(false, "Current native extension is required for the initial-state proofs")
	print("LCB fixture manifests: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)

func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false, "error":"missing " + path}
	return Contract.parse(file.get_as_text())

func _observed(definition: Dictionary, workers: int, ticks: int) -> Dictionary:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}), "Native worker configuration rejected")
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world, definition, "Benchmark", true):
		expect(false, definition.id + " install failed: " + host.last_error)
		return {}
	for tick: int in range(ticks):
		if not host.advance():
			expect(false, definition.id + " failed at tick %d: %s" % [tick, host.last_error])
			return {}
	var values: Dictionary = {}
	for entry: Dictionary in host.capture(CyberMicroScenarioIdentity.current("unavailable")).observations:
		values[entry.id] = entry.value
	return values

func _run_dam(definition: Dictionary) -> void:
	var one: Dictionary = _observed(definition, 1, 60)
	expect(int(one.get("total-t0", -1)) == 192 * 160 * 255, "Dam Break initial full-cell reservoir mass differs")
	# Measured 2026-10-23 on Current native Water (Windows, Linux expected identical integer outcome).
	expect(int(one.get("band-a-t30", -1)) == 197287, "Current Dam Break near-band discharge at tick 30 changed")
	expect(int(one.get("downstream-t60", -1)) == 387600, "Current Dam Break downstream mass at tick 60 changed")
	expect(_observed(definition, 4, 60) == one, "Dam Break 1/4-worker observations differ")

func _run_mix(definition: Dictionary) -> void:
	var one: Dictionary = _observed(definition, 1, 30)
	expect(int(one.get("water-t0", -1)) == (224 * 120 - 64) * 255, "Mixed initial Water mass differs")
	expect(int(one.get("oil-t0", -1)) == 224 * 120 and int(one.get("brine-t0", -1)) == 224 * 120,
		"Mixed initial Oil/Brine cells differ")
	expect(int(one.get("salt-t0", -1)) == 64, "Mixed initial Salt strip differs")
	var consumed: int = 64 - int(one.get("salt-t30", -1))
	expect(consumed == 29, "Current Water/Salt dissolution count by tick 30 changed")
	expect(int(one.get("water-t30", -1)) == int(one.get("water-t0", -1)) - consumed * 255,
		"Water/Salt reaction ledger no longer removes exactly one full Water cell per Salt cell")
	expect(_observed(definition, 4, 30) == one, "Mixed 1/4-worker observations differ")
