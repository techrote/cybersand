extends SceneTree

# LCB-001 (#200) liquid solver policy foundation through the real GDExtension
# adapter and MicroScenario host: applied readback, transactional refusal with
# the live session intact, explicit-default equivalence at 1 and 4 workers, and
# CYSD1 import on default families. Whole-cell Water admission is exercised
# here; pressure reference is covered by test_lcb_pressure_reference.gd.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const BASE_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const ASSIGNMENTS_AT: int = 20 # magic, versions, two 8-word digests, count
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
const PARITY_TICKS: int = 40
# Shared exact quantity-ledger continuation state requires CYPS/hash v2.
const PHYSICAL_STATE_VERSION: int = 2
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
# Separate source-bound Water evidence; the historical seven-field helper
# summary and every original control remain exact.
var water_inertial_proof: Dictionary = {"schema":"water-inertial-runtime-proof-v1",
	"cohorts":[], "restores":[], "refusals":{}, "coherence":[]}

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
	_whole_cell_water(bridge, definition, request)
	_transactional_refusals(bridge, definition, request, receipt)
	_default_parity(definition, request)
	_cysd1_import_defaults(bridge, definition, request, receipt)
	_finish()

func _finish() -> void:
	print("LIQUID_SOLVER_POLICY: %d assertions; %d failures; completed=%s" % [
		assertions, failures, JSON.stringify(completed)])
	water_inertial_proof["assertions"] = assertions
	water_inertial_proof["failures"] = failures
	print("WATER_INERTIAL_POLICY_PROOF: " + JSON.stringify(water_inertial_proof))
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

func _world_snapshot(world: Variant) -> Dictionary:
	return {"tick":int(world.get_tick_index()), "physical":world.get_physical_state_hash(),
		"generation":int(world.get_liquid_policy_session_generation()),
		"policy":world.get_liquid_solver_policy()}

func _whole_cell_census(bridge: Variant, world: Variant, maximum: int) -> Dictionary:
	var count: int = 0
	var full: bool = true
	for y: int in range(64):
		for x: int in range(64):
			if int(world.material_at(x, y)) != 3: continue
			count += 1
			var cell: Dictionary = bridge.inspect_cell(world, Vector2i(x, y))
			full = full and cell.get("ok", false) and int(cell.get("state_a", 0)) == maximum
	var observation: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64))
	return {"count":count, "full":full, "quantity":int(observation.water_integer)}

func _whole_cell_water(bridge: Variant, definition: Dictionary, request: PackedInt32Array) -> void:
	for family: int in [2, 4]:
		_whole_cell_family(bridge, definition, request, family)

func _whole_cell_family(bridge: Variant, definition: Dictionary, request: PackedInt32Array, family: int) -> void:
	var radius: int = 3 if family == 4 else 2
	var format_version: int = 3 if family == 4 else PHYSICAL_STATE_VERSION
	var whole_request: PackedInt32Array = _with(request, 3, family)
	var validation: Dictionary = bridge.validate_liquid_policy(whole_request)
	expect(validation.accepted and validation.refusal == null, "whole-cell Water policy must be admitted")
	if not validation.accepted: return
	expect(validation.receipt.assignments[0].applied_family == ("inertial_cellular_v1" if family == 4 else "cellular_yield_v1")
		and validation.receipt.admission == "qualified_candidate" and validation.receipt.normalization == null,
		"whole-cell Water validation receipt")
	var checked: Dictionary = Contract.validate(definition)
	if not checked.get("ok", false):
		expect(false, "whole-cell test transport unavailable")
		return
	var profile: PackedInt32Array = checked.transport.packed
	var basin: PackedInt32Array = PackedInt32Array([
		8, 40, 48, 1, 1, 8, 8, 1, 32, 1, 55, 8, 1, 32, 1, 12, 12, 12, 12, 3])
	for bits: int in [3, 8]:
		var runs: Array = []
		var proof_rows: Array = []
		for workers: int in [1, 4]:
			var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
			expect(world.diagnostic_reset({"workers":workers}), "whole-cell worker configuration rejected")
			world.set_simulation_window_enabled(false)
			var ok: bool = bridge.build_liquid_policy_world(world, basin, profile,
				PackedInt32Array([1, bits, 12, 0]), PackedInt32Array(), whole_request, radius)
			expect(ok, "whole-cell construction failed: " + str(bridge.get_last_error()))
			if not ok: return
			expect(int(world.get_worker_threads()) == workers
				and world.get_liquid_solver_policy().policy_hash == validation.receipt.policy_hash,
				"whole-cell constructor lost requested workers/policy")
			runs.append(world)
			if family == 4:
				var applied: Dictionary = world.get_liquid_solver_policy()
				proof_rows.append({"mass_bits":bits, "workers":int(world.get_worker_threads()),
					"family":applied.assignments[0].applied_family,
					"policy_hash":applied.policy_hash, "radius":int(applied.maximum_rule_radius),
					"hash_version":int(world.get_physical_state_hash_version()),
					"tick1_motion":false, "censuses":[],
					"initial_content_hash":str(world.water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64)).content_hash)})
		var initial_hash: String = str(runs[0].water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64)).content_hash)
		var maximum: int = (1 << bits) - 1
		for tick: int in range(21):
			if tick > 0:
				for world: Variant in runs: expect(world.simulation_tick(), "whole-cell Water tick faulted")
			if family == 4 and tick == 1:
				for world: Variant in runs:
					var retained: bool = false
					for y: int in range(8, 41):
						for x: int in range(8, 56):
							if world.material_at(x, y) != 3: continue
							var motion: Dictionary = world.inspect_inertial_cell(Vector2i(x, y))
							retained = retained or (motion.inertial_family and (motion.vx != 0 or motion.vy != 0 or motion.ax != 0 or motion.ay != 0))
					expect(retained and world.get_liquid_solver_policy().maximum_rule_radius == 3,
						"actual Water IN executes retained motion with explicit radius3, without fallback")
					proof_rows[runs.find(world)]["tick1_motion"] = retained
			if tick % 10 != 0: continue
			for world: Variant in runs:
				var census: Dictionary = _whole_cell_census(bridge, world, maximum)
				if family == 4:
					proof_rows[runs.find(world)].censuses.append({"tick":int(world.get_tick_index()),
						"count":int(census.count), "full":bool(census.full), "quantity":int(census.quantity)})
				expect(census.full and int(census.count) == 144 and int(census.quantity) == 144 * maximum,
					"whole-cell quantity/count changed at bits=%d tick=%d: %s" % [bits, tick, str(census)])
			expect(runs[0].get_physical_state_hash() == runs[1].get_physical_state_hash(),
				"whole-cell Water one/four-worker divergence at bits=%d tick=%d" % [bits, tick])
		expect(str(runs[0].water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64)).content_hash) != initial_hash,
			"whole-cell Water did not move")
		if family == 4:
			for index: int in range(runs.size()):
				var observed: Variant = runs[index]
				proof_rows[index]["completed_ticks"] = int(observed.get_tick_index())
				proof_rows[index]["physical_hash"] = str(observed.get_physical_state_hash())
				proof_rows[index]["final_content_hash"] = str(observed.water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64)).content_hash)
				water_inertial_proof.cohorts.append(proof_rows[index])
		var saved: PackedByteArray = bridge.export_physical_state(runs[0])
		expect(int(runs[0].get_physical_state_hash_version()) == format_version
			and saved.size() > 8 and saved.decode_u32(4) == format_version,
			"whole-cell quantity ledger binds the actual family CYPS/hash version")
		var restored: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(bridge.import_physical_state(restored, saved), "whole-cell family CYPS import failed")
		expect(restored.get_physical_state_hash() == runs[0].get_physical_state_hash(),
			"whole-cell family CYPS restore changed continuation state")
		var restore_proof: Dictionary = {"mass_bits":bits, "source_workers":int(runs[0].get_worker_threads()),
			"format_version":int(saved.decode_u32(4)), "saved_bytes":saved.size(),
			"source_hash":str(runs[0].get_physical_state_hash()),
			"restored_hash":str(restored.get_physical_state_hash()), "continuation":[]}
		for tick: int in range(5):
			expect(runs[0].simulation_tick() and restored.simulation_tick(), "whole-cell continuation tick failed")
			expect(restored.get_physical_state_hash() == runs[0].get_physical_state_hash(),
				"whole-cell family CYPS continuation diverged at +%d" % (tick + 1))
			restore_proof.continuation.append({"tick":int(runs[0].get_tick_index()),
				"source_hash":str(runs[0].get_physical_state_hash()), "restored_hash":str(restored.get_physical_state_hash())})
		if family == 4: water_inertial_proof.restores.append(restore_proof)
	completed["whole_cell_admission_parity"] = true
	# Final overlays decide admission. Intermediate fractional fills can be
	# overwritten; an explicit zero fill remains a no-op even over another role.
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.set_simulation_window_enabled(false)
	var rectangles: PackedInt32Array = PackedInt32Array([12, 12, 2, 1, 3, 14, 12, 1, 1, 2])
	var overlays: PackedInt32Array = PackedInt32Array([
		12, 12, 1, 1, 128, 5, 12, 12, 1, 1, 255, 7,
		13, 12, 1, 1, 255, 0, 14, 12, 1, 1, 0, 12])
	expect(bridge.build_liquid_policy_world(world, rectangles, profile, PackedInt32Array([1, 8, 12, 0]),
		overlays, whole_request, radius), "resolved full overlays must be accepted: " + str(bridge.get_last_error()))
	var selected: Dictionary = bridge.inspect_cell(world, Vector2i(12, 12))
	expect(int(selected.state_a) == 255 and int(selected.state_b) == 7
		and int(world.material_at(13, 12)) == 3 and int(world.material_at(14, 12)) == 2,
		"final fill/coherence or zero-fill no-op differs")
	expect(_whole_cell_census(bridge, world, 255) == {"count":2, "full":true, "quantity":510},
		"overlays must retain exactly two full Water cells")
	var before: Dictionary = _world_snapshot(world)
	var fractional_cases: Array = [
		PackedInt32Array([12, 12, 1, 1, 255, 7, 12, 12, 1, 1, 128, 2]),
		PackedInt32Array([12, 12, 1, 1, 128, 4, 12, 12, 1, 1, 0, 12]),
		PackedInt32Array([12, 12, 2, 1, 128, 4, 12, 12, 1, 1, 255, 0])]
	var refused_rows: Array = []
	for fills: PackedInt32Array in fractional_cases:
		expect(not bridge.build_liquid_policy_world(world, rectangles, profile, PackedInt32Array([1, 8, 12, 0]),
			fills, whole_request, radius), "final fractional Water must require explicit normalization")
		var refusal: Dictionary = bridge.get_last_liquid_policy_refusal()
		expect(refusal.get("code", "") == "normalization_required" and int(refusal.get("material", -1)) == 3
			and str(refusal.get("detail", "")).contains("water-normalize-v1"), "fractional setup needs a typed refusal")
		expect(_world_snapshot(world) == before, "fractional setup refusal changed the live session")
		refused_rows.append({"code":str(refusal.get("code", "")), "material":int(refusal.get("material", -1)),
			"unchanged_session":_world_snapshot(world) == before})
	expect(world.simulation_tick() and int(world.get_tick_index()) == int(before.tick) + 1,
		"live whole-cell session cannot continue after refusal")
	completed["whole_cell_overlay_refusals"] = true
	if family == 4:
		water_inertial_proof.refusals = {"rows":refused_rows, "tick_before":int(before.tick),
			"tick_after":int(world.get_tick_index())}
		_water_inertial_coherence(bridge, profile, whole_request)

func _water_inertial_coherence(bridge: Variant, profile: PackedInt32Array, request: PackedInt32Array) -> void:
	# Natural retained gravity proves the Water decrement remains live and
	# permits vertical travel before the positive lateral-only delay expires.
	for bits: int in [3, 8]:
		for workers: int in [1, 4]:
			var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
			expect(world.diagnostic_reset({"workers":workers}), "Water IN coherence workers refused")
			world.set_simulation_window_enabled(false)
			var maximum: int = (1 << bits) - 1
			expect(bridge.build_liquid_policy_world(world, PackedInt32Array([8, 40, 48, 1, 1, 20, 10, 1, 1, 3]),
				profile, PackedInt32Array([1, bits, 12, 0]), PackedInt32Array([20, 10, 1, 1, 255, 7]), request, 3),
				"Water IN coherent whole-cell preparation refused")
			var initial: Dictionary = bridge.inspect_cell(world, Vector2i(20, 10))
			expect(initial.get("ok", false) and int(initial.state_b) == 7 and int(initial.state_a) == maximum,
				"Water IN coherence fixture lost initial state")
			var observed: Array = []
			var vertical_before_expiry: bool = false
			var retained: bool = false
			for tick: int in range(1, 8):
				expect(world.simulation_tick(), "Water IN future coherence work faulted")
				var point: Vector2i = Vector2i(-1, -1)
				var count: int = 0
				for y: int in range(40):
					if int(world.material_at(20, y)) == 3:
						point = Vector2i(20, y)
						count += 1
				expect(count == 1, "Water IN coherence carrier is not unique")
				if count != 1: return
				var cell: Dictionary = bridge.inspect_cell(world, point)
				observed.append(int(cell.state_b))
				expect(int(cell.state_b) == 7 - tick and int(cell.state_a) == maximum,
					"Water IN coherence did not decrement exactly once with exact quantity")
				var motion: Dictionary = world.inspect_inertial_cell(point)
				retained = retained or (motion.inertial_family and (motion.vx != 0 or motion.vy != 0 or motion.ax != 0 or motion.ay != 0))
				vertical_before_expiry = vertical_before_expiry or (point.y > 10 and int(cell.state_b) > 0)
			var census: Dictionary = _whole_cell_census(bridge, world, maximum)
			expect(vertical_before_expiry and retained and census.full and census.count == 1 and census.quantity == maximum,
				"Water IN coherence suppressed vertical motion, retained state or whole-cell authority")
			water_inertial_proof.coherence.append({"mass_bits":bits, "workers":int(world.get_worker_threads()),
				"initial":int(initial.state_b), "observed":observed, "completed_ticks":int(world.get_tick_index()),
				"vertical_before_expiry":vertical_before_expiry, "retained_motion":retained,
				"count":int(census.count), "full":bool(census.full), "quantity":int(census.quantity)})

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
		# Water pressure variants are admitted; unsupported Oil assignments must
		# still refuse transactionally instead of substituting Water's solver.
		["Oil pressure cached", _with(request, 16, 3, 1), "combination_rejected", 16],
		["Oil pressure cached_dormant", _with(request, 16, 3, 2), "combination_rejected", 16],
		["NC-2 Water inertial cached", _with(request, 3, 4, 1), "variant_unsupported", 3],
		["Brine inertial cached", _with(request, 24, 4, 1), "variant_unsupported", 24],
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
	expect(not other.host.install(other.world, definition, "Benchmark", true, _with(request, 16, 3, 2)),
		"independent World admitted unsupported Oil pressure_flow_v1/cached_dormant")
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
