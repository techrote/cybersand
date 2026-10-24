extends SceneTree

# LCB-001 (#200) liquid solver policy foundation through the real GDExtension
# adapter and MicroScenario host: applied readback, transactional refusal with
# the live session intact, explicit-default equivalence at 1 and 4 workers, and
# CYSD1 import on default families. This build admits only current defaults.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const BASE_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const ASSIGNMENTS_AT: int = 20 # magic, versions, two 8-word digests, count
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
const PARITY_TICKS: int = 40
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false, "current native extension unavailable")
		_finish()
		return
	var source: Dictionary = Runner.read_text(BASE_PATH)
	expect(source.ok, "protected Dam Break definition unavailable")
	if not source.ok:
		_finish()
		return
	var checked: Dictionary = Contract.parse(source.text)
	expect(checked.get("ok", false), "protected Dam Break definition must validate")
	var definition: Dictionary = checked.definition
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var receipt: Dictionary = _validation(bridge, request)
	completed["validation"] = not receipt.is_empty()
	if receipt.is_empty():
		_finish()
		return
	_default_readback(bridge, definition, request, receipt)
	_transactional_refusals(bridge, definition, request, receipt)
	_default_parity(definition, request)
	_cysd1_import_defaults(bridge, definition, request, receipt)
	_finish()

func _finish() -> void:
	print("LIQUID_SOLVER_POLICY: %d assertions; %d failures; completed=%s" % [
		assertions, failures, JSON.stringify(completed)])
	quit(1 if failures > 0 else 0)

func _with(request: PackedInt32Array, material: int, family: int, variant: int = 0) -> PackedInt32Array:
	var words: PackedInt32Array = request.duplicate()
	var row: int = LIQUIDS.find(material)
	words[ASSIGNMENTS_AT + row * 3 + 1] = family
	words[ASSIGNMENTS_AT + row * 3 + 2] = variant
	return words

func _validation(bridge: Variant, request: PackedInt32Array) -> Dictionary:
	expect(request.size() == ASSIGNMENTS_AT + 3 * LIQUIDS.size() + 2, "default envelope length")
	expect(request[0] == 0x4C435057 and request[1] == 1 and request[2] == 1, "default envelope header")
	var result: Dictionary = bridge.validate_liquid_policy(request)
	expect(result.accepted and result.refusal == null, "native default request refused: " + str(result.refusal))
	if not result.accepted: return {}
	var receipt: Dictionary = result.receipt
	expect(str(receipt.policy_hash).length() == 64 and receipt.envelope == request,
		"validation receipt does not re-encode the request")
	expect(receipt.assignments.size() == LIQUIDS.size(), "receipt must assign all eleven liquids")
	for entry: Dictionary in receipt.assignments:
		var expected: String = "freemass_v1" if int(entry.material) == 3 else "cellular_yield_v1"
		expect(entry.applied_family == expected and entry.applied_variant == "reference"
			and entry.requested_family == expected, "default assignment differs: " + str(entry))
	expect(receipt.admission == "current_defaults_only" and receipt.normalization == null
		and receipt.refusal == null, "receipt admission/normalization/refusal fields")
	# Request-only code 0 normalizes to the same applied identity.
	var zeros: PackedInt32Array = request.duplicate()
	for row: int in range(LIQUIDS.size()): zeros[ASSIGNMENTS_AT + row * 3 + 1] = 0
	var normalized: Dictionary = bridge.validate_liquid_policy(zeros)
	expect(normalized.accepted and normalized.receipt.policy_hash == receipt.policy_hash
		and normalized.receipt.envelope == request
		and normalized.receipt.assignments[0].requested_family == "material_default",
		"material-default request did not normalize to the explicit default")
	return receipt

func _install(workers: int, definition: Dictionary, policy: Variant) -> Dictionary:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}), "native worker configuration rejected")
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	var ok: bool = host.install(world, definition, "Benchmark", true, policy)
	expect(ok, "install refused: " + host.last_error)
	return {"world":world, "host":host}

func _default_readback(bridge: Variant, definition: Dictionary, request: PackedInt32Array,
		receipt: Dictionary) -> void:
	var fresh: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var initial: Dictionary = fresh.get_liquid_solver_policy()
	expect(initial.policy_hash == receipt.policy_hash, "fresh World does not report the default policy")
	var run: Dictionary = _install(1, definition, request)
	var readback: Dictionary = run.host.liquid_solver_policy()
	expect(readback.policy_hash == receipt.policy_hash and readback.envelope == request
		and readback.catalogue_digest == receipt.catalogue_digest
		and readback.capability_matrix_digest == receipt.capability_matrix_digest,
		"installed World readback differs from the validated receipt")
	expect(int(readback.session_generation) == int(run.world.get_liquid_policy_session_generation())
		and int(readback.session_generation) >= 2, "session generation must count diagnostic reset and install")
	expect(run.host.last_liquid_policy_refusal.is_empty(), "accepted install reported a refusal")
	completed["default_readback"] = true

func _snapshot(run: Dictionary) -> Dictionary:
	var observation: Dictionary = run.world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024))
	return {"tick":int(run.world.get_tick_index()), "state_hash":observation.state_hash,
		"content_hash":observation.content_hash, "water_integer":int(observation.water_integer),
		"definition_hash":str(run.host.summary().get("definition_hash", "")),
		"policy":run.world.get_liquid_solver_policy()}

func _transactional_refusals(bridge: Variant, definition: Dictionary, request: PackedInt32Array,
		receipt: Dictionary) -> void:
	var run: Dictionary = _install(1, definition, request)
	for tick: int in range(5): expect(run.host.advance(), "live session failed to advance")
	var before: Dictionary = _snapshot(run)
	var stale: PackedInt32Array = request.duplicate()
	stale[3] = stale[3] ^ 1
	var truncated: PackedInt32Array = request.slice(0, request.size() - 1)
	var cases: Array = [
		["NC-1 Oil inertial", _with(request, 16, 4), "combination_rejected", 16],
		["NC-2 Water pressure", _with(request, 3, 3), "family_unavailable", 3],
		["NC-2 Water pressure cached_dormant", _with(request, 3, 3, 2), "family_unavailable", 3],
		["NC-2 Water inertial", _with(request, 3, 4), "family_unavailable", 3],
		["Water whole-cell CellularYield", _with(request, 3, 2), "family_unavailable", 3],
		["Brine inertial", _with(request, 24, 4), "family_unavailable", 24],
		["Toxic Sludge alternate", _with(request, 32, 4), "not_selectable", 32],
		["Oil pressure", _with(request, 16, 3), "combination_rejected", 16],
		["Water FreeMass cached", _with(request, 3, 1, 1), "variant_unsupported", 3],
		["stale catalogue digest", stale, "stale_capability_matrix", null],
		["truncated envelope", truncated, "malformed_policy", null],
		["empty envelope", PackedInt32Array(), "malformed_policy", null],
	]
	for item: Array in cases:
		var validation: Dictionary = bridge.validate_liquid_policy(item[1])
		expect(not validation.accepted and validation.refusal.code == item[2] and validation.refusal.material == item[3],
			item[0] + ": validation " + str(validation.refusal))
		var refused: bool = not run.host.install(run.world, definition, "Benchmark", true, item[1])
		var refusal: Dictionary = run.host.last_liquid_policy_refusal
		expect(refused and refusal.get("code", "") == item[2] and refusal.get("material") == item[3]
			and not str(refusal.get("detail", "")).is_empty(), item[0] + ": host refusal " + str(refusal))
		expect(run.host.last_error.contains("running world preserved") and run.host.last_error.contains(item[2]),
			item[0] + ": refusal is not visible: " + run.host.last_error)
		expect(_snapshot(run) == before, item[0] + ": refusal changed the live session")
	expect(not run.host.install(run.world, definition, "Benchmark", true, [3, 1, 0]),
		"a non-PackedInt32Array policy must be refused")
	expect(_snapshot(run) == before, "type refusal changed the live session")
	expect(run.host.active() and run.host.advance() and int(run.world.get_tick_index()) == before.tick + 1,
		"live session does not continue after refusals")
	# An unrelated World keeps its own policy session through those refusals.
	var other: Dictionary = _install(1, definition, null)
	var other_generation: int = int(other.world.get_liquid_policy_session_generation())
	expect(not other.host.install(other.world, definition, "Benchmark", true, _with(request, 3, 3)),
		"independent World admitted pressure_flow_v1")
	expect(int(other.world.get_liquid_policy_session_generation()) == other_generation
		and other.world.get_liquid_solver_policy().policy_hash == receipt.policy_hash
		and int(run.world.get_liquid_policy_session_generation()) == int(before.policy.session_generation),
		"refusal in one World affected another World's session")
	completed["refusals"] = cases.size()

func _default_parity(definition: Dictionary, request: PackedInt32Array) -> void:
	var implicit: Dictionary = _install(1, definition, null)
	var explicit: Dictionary = _install(1, definition, request)
	var workers: Dictionary = _install(4, definition, request)
	expect(int(workers.world.get_worker_threads()) == 4, "four-worker World was not constructed")
	var checked: int = 0
	for tick: int in range(PARITY_TICKS + 1):
		if tick > 0:
			for run: Dictionary in [implicit, explicit, workers]: expect(run.host.advance(), "parity run faulted")
		if tick % 10 != 0: continue
		var a: Dictionary = _snapshot(implicit)
		var b: Dictionary = _snapshot(explicit)
		var c: Dictionary = _snapshot(workers)
		expect(a.state_hash == b.state_hash and a.content_hash == b.content_hash and a.water_integer == b.water_integer,
			"explicit default policy changed Dam Break at tick %d" % tick)
		expect(a.state_hash == c.state_hash and a.content_hash == c.content_hash,
			"four-worker explicit default diverged at tick %d" % tick)
		expect(a.policy.policy_hash == b.policy.policy_hash and b.policy.policy_hash == c.policy.policy_hash,
			"readback differs between implicit and explicit defaults")
		checked += 1
	completed["parity_checkpoints"] = checked

func _cysd1_import_defaults(bridge: Variant, definition: Dictionary, request: PackedInt32Array,
		receipt: Dictionary) -> void:
	var run: Dictionary = _install(1, definition, request)
	var bytes: PackedByteArray = bridge.export_level(run.world)
	expect(not bytes.is_empty(), "CYSD1 export failed: " + str(bridge.get_last_error()))
	var generation: int = int(run.world.get_liquid_policy_session_generation())
	expect(bridge.import_level(run.world, bytes), "CYSD1 import failed: " + str(bridge.get_last_error()))
	var readback: Dictionary = run.world.get_liquid_solver_policy()
	expect(readback.policy_hash == receipt.policy_hash and int(readback.session_generation) == generation + 1,
		"NC-10: CYSD1 import must reconstruct on default families with a new session")
	var corrupt: PackedByteArray = bytes.slice(0, 16)
	expect(not bridge.import_level(run.world, corrupt)
		and int(run.world.get_liquid_policy_session_generation()) == generation + 1,
		"rejected import replaced the session")
	completed["cysd1_defaults"] = true
