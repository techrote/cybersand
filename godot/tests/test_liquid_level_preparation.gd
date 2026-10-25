extends SceneTree

# Direct decoded-CYSD tuple preparation. This does not exercise a UI importer,
# browser runtime, complete host envelope or physical checkpoint reconstruction.
const Profiles = preload("res://scripts/transport_profiles.gd")
const SIDE: int = 1024
const CELL_BYTES: int = 5
const PAYLOAD_BYTES: int = SIDE * SIDE * CELL_BYTES
const WATER: Array[int] = [1, 8, 12, 0]
const SECTIONS: Array[String] = ["thermal_payload", "normalization", "refusals_atomicity",
	"token_fences", "mixed_workers", "legacy_preservation"]
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var bridge: Variant
var defaults: PackedInt32Array
var profile: PackedInt32Array
var ambient_payload: PackedByteArray

func _initialize() -> void:
	for name: String in SECTIONS: completed[name] = false
	_run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_LEVEL_PREPARATION: " + message)
	return value

func _section(name: String, body: Callable) -> void:
	var before: int = failures
	body.call()
	completed[name] = failures == before

func _run() -> void:
	if not expect(ClassDB.class_exists(&"CyberDemoBridge") and ClassDB.class_exists(&"CyberNativeCellWorld"), "native classes required"):
		_finish(); return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	if not expect(bridge.has_method(&"prepare_liquid_level"), "fresh thermal level preparation binding required"):
		_finish(); return
	defaults = bridge.default_liquid_policy()
	var resolved: Dictionary = Profiles.resolve(Profiles.preset(0))
	if not expect(resolved.get("ok", false), "retained Baseline transport resolves"):
		_finish(); return
	profile = resolved.packed
	# Doubling one canonical ambient tuple avoids a million interpreted writes.
	ambient_payload = PackedByteArray([0, 0, 0, 200, 0])
	for _power: int in range(20): ambient_payload.append_array(ambient_payload.duplicate())
	if not expect(ambient_payload.size() == PAYLOAD_BYTES, "exact finite decoded payload size"):
		_finish(); return
	_section("thermal_payload", _thermal_payload)
	_section("normalization", _normalization)
	_section("refusals_atomicity", _refusals_atomicity)
	_section("token_fences", _token_fences)
	_section("mixed_workers", _mixed_workers)
	_section("legacy_preservation", _legacy_preservation)
	_finish()

func _finish() -> void:
	print("LIQUID_LEVEL_PREPARATION: %d assertions; %d failures; completed=%s" % [assertions, failures, JSON.stringify(completed)])
	quit(1 if failures else 0)

func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _intact(receipt: Dictionary, kind: String = "applied_run") -> bool:
	return receipt.get("kind", "") == kind and receipt.get("schema_version", 0) == 1 \
		and receipt.get("canonical_bytes", PackedByteArray()).size() > 32 \
		and _sha(receipt.canonical_bytes) == receipt.get("receipt_hash", "")

func _put(bytes: PackedByteArray, x: int, y: int, material: int, a: int = 0, b: int = 0, temperature: int = 200) -> void:
	var offset: int = (y * SIDE + x) * CELL_BYTES
	bytes[offset] = material
	bytes[offset + 1] = a
	bytes[offset + 2] = b
	bytes.encode_u16(offset + 3, temperature & 65535)

func _rect(bytes: PackedByteArray, x: int, y: int, width: int, height: int, material: int, a: int = 0) -> void:
	for cy: int in range(y, y + height):
		for cx: int in range(x, x + width): _put(bytes, cx, cy, material, a)

func _options(normalization: String = "", radius: int = 2) -> Dictionary:
	return {"region":PackedInt32Array([0, 0, 96, 96]), "seed":731,
		"intent":"controlled", "pacing":"fixed_steps", "simulation_window_enabled":true,
		"cadence_lod_enabled":false, "liquid_surface_adhesion_enabled":true,
		"normalization":normalization, "maximum_rule_radius":radius}

func _new_world(workers: int = 1) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}), "isolated worker configuration admits " + str(workers))
	return world

func _prepare(world: Variant, bytes: PackedByteArray, request: PackedInt32Array,
		options: Dictionary = {}, water: Variant = WATER) -> int:
	return bridge.prepare_liquid_level(world, bytes, profile, PackedInt32Array(water), request, _options() if options.is_empty() else options)

func _install(world: Variant, bytes: PackedByteArray, request: PackedInt32Array,
		options: Dictionary = {}, water: Variant = WATER) -> bool:
	var token: int = _prepare(world, bytes, request, options, water)
	if not expect(token > 0, "decoded level prepares: " + str(bridge.get_last_error())): return false
	return expect(bridge.commit_liquid_world(world, token), "decoded level commits once: " + str(bridge.get_last_error()))

func _choose(request: PackedInt32Array, material: int, family: String, variant: String = "reference") -> PackedInt32Array:
	for value: Dictionary in bridge.liquid_policy_assignment_choices(request, material):
		if value.family == family and value.variant == variant and value.accepted: return value.request
	expect(false, "native assignment choice absent: %s/%s for %d" % [family, variant, material])
	return PackedInt32Array()

func _cell(world: Variant, point: Vector2i, material: int, a: int, b: int, temperature: int) -> void:
	var value: Dictionary = bridge.inspect_cell(world, point)
	expect(value.get("ok", false) and value.material == material and value.state_a == a and value.state_b == b
		and value.temperature_available and value.temperature_raw == temperature,
		"exact imported tuple at %s: %s" % [point, value])

func _snapshot(world: Variant) -> Dictionary:
	return {"hash":world.get_physical_state_hash(), "generation":world.get_liquid_policy_session_generation(),
		"revision":world.get_revision(), "receipt":world.get_applied_liquid_construction_receipt(),
		"policy":world.get_liquid_solver_policy(), "tick":world.get_tick_index()}

func _scope(receipt: Dictionary, bytes: PackedByteArray) -> void:
	expect(_intact(receipt) and receipt.setup_kind == "native_cell_fixture"
		and receipt.source_payload_sha256 == _sha(bytes), "native-v1 receipt binds actual decoded bytes and NativeCellFixture")
	expect(receipt.qualifications == 15 and not receipt.eligible_for_full_matched_evidence,
		"native fixture keeps all outer-v1 qualifications and false full matched eligibility")
	expect(str(receipt.prepared_setup_hash).length() == 64 and str(receipt.prepared_payload_hash).length() == 64,
		"typed native setup and sparse native payload digests accompany raw source identity")

func _thermal_bytes() -> PackedByteArray:
	var bytes: PackedByteArray = ambient_payload.duplicate()
	_put(bytes, 7, 8, 1, 17, 23, -32768)
	_put(bytes, 8, 8, 1, 211, 255, 32767)
	_put(bytes, 9, 8, 0, 0, 0, -32768)
	_put(bytes, 10, 8, 0, 0, 0, 32767)
	_put(bytes, 11, 8, 3, 255, 7, -1234)
	_put(bytes, 12, 8, 3, 0, 0, 2718)
	return bytes

func _thermal_payload() -> void:
	var bytes: PackedByteArray = _thermal_bytes()
	var expected_export: PackedByteArray = bytes.duplicate()
	_put(expected_export, 12, 8, 0, 0, 0, 2718)
	var payload_hashes: Array[String] = []
	for workers: int in [1, 4]:
		var world: Variant = _new_world(workers)
		var before: Dictionary = _snapshot(world)
		var token: int = _prepare(world, bytes, defaults)
		if not expect(token > 0, "full thermal tuple map prepares"): return
		expect(_snapshot(world) == before, "preparation leaves initial live World/receipt/revision untouched")
		var pending: Dictionary = bridge.prepared_liquid_run_capture(world, token)
		var values: Dictionary = bridge.prepared_liquid_world_values(world, token)
		expect(pending.lifecycle == "prepared" and pending.token == token, "capture is explicitly pending")
		_scope(pending.native_run_encoding, bytes)
		var canonical: PackedByteArray = pending.native_run_encoding.canonical_bytes.duplicate()
		pending.native_run_encoding.canonical_bytes[0] ^= 255
		expect(bridge.prepared_liquid_run_capture(world, token).native_run_encoding.canonical_bytes == canonical,
			"pending native byte wrapper is copied")
		expect(bridge.commit_liquid_world(world, token), "thermal candidate commits")
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		_scope(receipt, bytes)
		expect(receipt.worker_threads == workers and receipt.maximum_rule_radius == 2
			and receipt.physical_state_hash == world.get_physical_state_hash()
			and values.candidate_physical_state_hash == world.get_physical_state_hash(), "actual tick-zero identity and worker/radius readback match pending values")
		_cell(world, Vector2i(7, 8), 1, 17, 23, -32768)
		_cell(world, Vector2i(8, 8), 1, 211, 255, 32767)
		_cell(world, Vector2i(9, 8), 0, 0, 0, -32768)
		_cell(world, Vector2i(10, 8), 0, 0, 0, 32767)
		_cell(world, Vector2i(11, 8), 3, 255, 7, -1234)
		_cell(world, Vector2i(12, 8), 0, 0, 0, 2718)
		expect(bridge.export_level(world) == expected_export, "all1,048,576 exported tuples match input except documented Water-zero canonicalization")
		payload_hashes.append(receipt.prepared_payload_hash)
		expect(not bridge.commit_liquid_world(world, token), "installed thermal token cannot replay")
	expect(payload_hashes[0] == payload_hashes[1], "prepared native thermal payload identity is worker-independent")
	var original: PackedByteArray = bytes.duplicate()
	var world: Variant = _new_world()
	var token: int = _prepare(world, bytes, defaults)
	_put(bytes, 11, 8, 1, 99, 21, 919)
	expect(token > 0 and bridge.commit_liquid_world(world, token), "candidate survives caller payload mutation after preparation")
	_cell(world, Vector2i(11, 8), 3, 255, 7, -1234)
	expect(world.get_applied_liquid_construction_receipt().source_payload_sha256 == _sha(original)
		and _sha(original) != _sha(bytes), "copied candidate/receipt retains original source bytes")
	var low_precision: PackedByteArray = ambient_payload.duplicate()
	_put(low_precision, 13, 8, 3, 7, 4, -41)
	_put(low_precision, 14, 8, 3, 3, 2, 200)
	if not _install(world, low_precision, defaults, _options(), PackedInt32Array([1, 3, 4, 0])): return
	_cell(world, Vector2i(13, 8), 3, 7, 4, -41)
	_cell(world, Vector2i(14, 8), 3, 3, 2, 200)
	expect(world.water_experiment_observation(Vector2i(13, 8), Vector2i(2, 1)).water_integer == 10,
		"three-bit import retains actual native mass/coherence rather than re-scaling byte lanes")

func _fractional() -> PackedByteArray:
	var bytes: PackedByteArray = ambient_payload.duplicate()
	_put(bytes, 20, 20, 3, 127, 5, -2222)
	_put(bytes, 21, 20, 3, 128, 9, 3333)
	_put(bytes, 22, 20, 3, 0, 0, -91)
	return bytes

func _normalization() -> void:
	var whole: PackedInt32Array = _choose(defaults, 3, "cellular_yield_v1")
	var bytes: PackedByteArray = _fractional()
	var digests: Array[String] = []
	for workers: int in [1, 4]:
		var world: Variant = _new_world(workers)
		if not _install(world, _thermal_bytes(), defaults): return
		_refuse(world, bytes, whole, "fractional whole-cell without opt-in", {}, WATER, "normalization_required", true)
		if not _install(world, bytes, whole, _options("water-normalize-v1")): return
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		_scope(receipt, bytes)
		var norm: Dictionary = receipt.normalization
		expect(norm.rule == "water-normalize-v1" and norm.water_before == 255 and norm.water_after == 255
			and norm.positive_delta == 127 and norm.negative_delta == 127 and norm.net_delta == 0
			and norm.cells_up == 1 and norm.cells_down == 1 and norm.cells_unchanged == 0, "127/128 threshold keeps exact native gross/net/cell ledger")
		expect(str(norm.receipt_hash).length() == 64 and norm.payload_before_hash != norm.payload_after_hash
			and norm.setup_before_hash != norm.setup_after_hash, "normalization retains both before/after native identities")
		_cell(world, Vector2i(20, 20), 0, 0, 0, -2222)
		_cell(world, Vector2i(21, 20), 3, 255, 9, 3333)
		_cell(world, Vector2i(22, 20), 0, 0, 0, -91)
		expect(world.water_experiment_observation(Vector2i(20, 20), Vector2i(3, 1)).water_integer == 255,
			"visible normalized World quantity equals native receipt")
		expect(world.get_liquid_construction_attempt().is_empty(), "successful import retires prior typed refusal")
		digests.append(receipt.prepared_setup_hash)
	expect(digests[0] == digests[1], "normalized native setup digest is worker-independent")

func _refuse(world: Variant, bytes: PackedByteArray, request: PackedInt32Array, label: String,
		options: Dictionary = {}, water: Variant = WATER, code: String = "", typed: bool = false) -> void:
	var before: Dictionary = _snapshot(world)
	expect(_prepare(world, bytes, request, options, water) == 0 and not str(bridge.get_last_error()).is_empty(), label + ": explicit refusal")
	expect(_snapshot(world) == before, label + ": preserves exact live hash/receipt/generation/revision/policy/tick")
	if not code.is_empty(): expect(bridge.get_last_liquid_policy_refusal().get("code", "") == code, label + ": exact typed reason")
	var attempt: Dictionary = world.get_liquid_construction_attempt()
	if typed: expect(_intact(attempt, "construction_attempt"), label + ": retained native attempt is independently intact")
	elif not attempt.is_empty(): expect(_intact(attempt, "construction_attempt"), label + ": emitted attempt is intact")

func _refusals_atomicity() -> void:
	var world: Variant = _new_world()
	var valid: PackedByteArray = _thermal_bytes()
	if not _install(world, valid, defaults): return
	_refuse(world, valid.slice(0, valid.size() - 1), defaults, "short payload")
	var invalid: PackedByteArray = valid.duplicate()
	invalid.append(0)
	_refuse(world, invalid, defaults, "long payload")
	for lanes: Array in [[255, 0, 0], [0, 1, 0], [0, 0, 1]]:
		invalid = valid.duplicate()
		_put(invalid, 30, 31, lanes[0], lanes[1], lanes[2])
		_refuse(world, invalid, defaults, "invalid material or noncanonical Empty " + str(lanes))
	for water_state: Array in [[3, 8, 0], [3, 255, 0], [8, 255, 6]]:
		# Row0/1 choose lower precision to prove no silent conversion; row2
		# exceeds the selected coherence allowance despite a legal mass lane.
		var semantics := PackedInt32Array([1, water_state[0], 12 if water_state[0] == 3 else 5, 0])
		invalid = ambient_payload.duplicate()
		_put(invalid, 30, 31, 3, water_state[1], water_state[2])
		_refuse(world, invalid, defaults, "Water precision/coherence mismatch " + str(water_state), {}, semantics)
	invalid = ambient_payload.duplicate()
	_put(invalid, 30, 31, 3, 0, 6)
	_refuse(world, invalid, defaults, "zero Water validates coherence before canonicalization", {}, PackedInt32Array([1, 8, 5, 0]))
	for extra: Dictionary in [{"definition_hash":""}, {"definition_hash":"0".repeat(64)},
		{"normalization":"unknown-v2"}, {"maximum_rule_radius":1}, {"maximum_rule_radius":4},
		{"region":PackedInt32Array([1020, 0, 8, 8])}, {"seed":-1}, {"intent":"unknown"}]:
		var options: Dictionary = _options()
		options.merge(extra, true)
		_refuse(world, valid, defaults, "invalid import-only option " + str(extra), options)
	var incoherent: PackedInt32Array = PackedInt32Array([1, 8, 13, 0])
	_refuse(world, valid, defaults, "invalid Water policy", {}, incoherent)
	var malformed: PackedInt32Array = defaults.duplicate()
	malformed[0] = 99
	_refuse(world, valid, malformed, "native policy envelope refusal", {}, WATER, "", true)
	var unsupported: PackedInt32Array = _choose(defaults, 24, "inertial_cellular_v1")
	_refuse(world, valid, unsupported, "IN cannot silently upgrade explicit radius2")

func _token_fences() -> void:
	var world: Variant = _new_world()
	var bytes: PackedByteArray = _thermal_bytes()
	if not _install(world, bytes, defaults): return
	var token: int = _prepare(world, bytes, defaults)
	var newer: int = _prepare(world, bytes, defaults)
	expect(newer > token and not bridge.commit_liquid_world(world, token), "replacement monotonically retires older token")
	expect(bridge.commit_liquid_world(world, newer), "retired token leaves newer candidate consumable")
	token = _prepare(world, bytes, defaults)
	bridge.discard_liquid_world(world, token)
	expect(not bridge.commit_liquid_world(world, token) and bridge.prepared_liquid_run_capture(world, token).is_empty(), "discard retires candidate and copied capture")
	token = _prepare(world, bytes, defaults)
	_refuse(world, PackedByteArray(), defaults, "new refused preparation")
	expect(not bridge.commit_liquid_world(world, token), "a newer refusal also retires the older token")
	token = _prepare(world, bytes, defaults)
	world.paint_disc(40, 40, 0, 1, 0)
	var edited: Dictionary = _snapshot(world)
	expect(not bridge.commit_liquid_world(world, token) and _snapshot(world) == edited, "intervening actual cell edit preserves edited live state and applied receipt")
	token = _prepare(world, bytes, defaults)
	world.set_cadence_lod_enabled(true)
	edited = _snapshot(world)
	expect(not bridge.commit_liquid_world(world, token) and _snapshot(world) == edited, "execution revision change refuses before swap")
	token = _prepare(world, bytes, defaults)
	expect(world.simulation_tick(), "live native tick advances while candidate remains unexposed")
	edited = _snapshot(world)
	expect(not bridge.commit_liquid_world(world, token) and _snapshot(world) == edited, "intervening completed tick retires candidate")
	var options: Dictionary = _options()
	var bodies := PackedFloat32Array([1, 11.5, 8.5, 0, 0.5, 0.5, 0, 0, 0, 1, 1])
	options["initial_bodies"] = bodies
	token = _prepare(world, bytes, defaults, options)
	if not expect(token > 0, "initial native mask is staged before capture"): return
	var values: Dictionary = bridge.prepared_liquid_world_values(world, token)
	var pending: Dictionary = bridge.prepared_liquid_run_capture(world, token).native_run_encoding
	expect(values.initial_bodies == bodies and str(values.initial_body_state_sha256).length() == 64
		and pending.initial_body_count == 1 and pending.initial_body_state_sha256 == values.initial_body_state_sha256,
		"pending values and receipt bind actual initial native mask input")
	bodies[1] = 60.5
	options.initial_bodies[1] = 70.5
	expect(bridge.commit_liquid_world(world, token) and world.rigid_body_id_at(11, 8) == 1
		and world.rigid_body_id_at(70, 8) == 0, "caller body input mutation cannot retarget prepared mask")
	var hidden: Dictionary = bridge.inspect_cell(world, Vector2i(11, 8))
	expect(hidden.material == 3 and hidden.state_a == 255 and hidden.state_b == 7
		and not hidden.temperature_available and hidden.temperature_raw == null, "mask retains imported stored tuple and honest masked temperature observation")
	expect(world.get_physical_state_hash() == pending.physical_state_hash, "applied mask state equals prepared native capture")
	_refuse(world, _fractional(), _choose(defaults, 3, "cellular_yield_v1"), "normalization refusal with existing body", {}, WATER, "normalization_required", true)
	expect(world.rigid_body_id_at(11, 8) == 1, "refusal preserves prior initial mask")

func _mixed_bytes() -> PackedByteArray:
	var bytes: PackedByteArray = ambient_payload.duplicate()
	_rect(bytes, 0, 0, 96, 1, 1)
	_rect(bytes, 0, 80, 96, 1, 1)
	_rect(bytes, 0, 0, 1, 80, 1)
	_rect(bytes, 95, 0, 1, 80, 1)
	_rect(bytes, 28, 60, 8, 6, 3, 255)
	_rect(bytes, 36, 60, 8, 6, 16)
	_rect(bytes, 32, 40, 8, 6, 24)
	return bytes

func _authority(world: Variant) -> Dictionary:
	var ledger: Dictionary = world.get_pressure_flow_ledger()
	ledger.erase("last_tick") # Actual gas/head preparation work differs by arm.
	return {"projection":world.get_liquid_comparison_hash(1), "gas":world.inspect_gas_compartments(),
		"ledger":ledger, "water":world.water_experiment_observation(Vector2i.ZERO, Vector2i(96, 96)).water_integer}

func _mixed_workers() -> void:
	var bytes: PackedByteArray = _mixed_bytes()
	var inertial: PackedInt32Array = _choose(defaults, 24, "inertial_cellular_v1")
	var results: Array[Array] = []
	for workers: int in [1, 4]:
		var worlds: Array = []
		for variant: String in ["reference", "cached", "cached_dormant"]:
			var request: PackedInt32Array = _choose(inertial, 3, "pressure_flow_v1", variant)
			var world: Variant = _new_world(workers)
			if not _install(world, bytes, request, _options("", 3)): return
			var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
			_scope(receipt, bytes)
			var families: Array[int] = []
			for extension: Dictionary in receipt.solver_state_extensions: families.append(extension.family)
			expect(families == [3, 4] and receipt.physical_state_hash_version == 3 and receipt.maximum_rule_radius == 3,
				"combined import captures sorted actual PF+IN extensions and explicit radius3")
			worlds.append(world)
		var hashes: Array[String] = []
		var moving: bool = false
		for step: int in range(24):
			for world: Variant in worlds: expect(world.simulation_tick(), "mixed imported native tick completes")
			var reference: Dictionary = _authority(worlds[0])
			for arm: int in [1, 2]: expect(_authority(worlds[arm]) == reference, "imported PF variants preserve exact same-tick authority at " + str(step))
			if step == 3:
				for y: int in range(40, 64):
					for x: int in range(28, 44):
						if worlds[0].material_at(x, y) == 24:
							var cell: Dictionary = worlds[0].inspect_inertial_cell(Vector2i(x, y))
							moving = moving or cell.vx != 0 or cell.vy != 0 or cell.ax != 0 or cell.ay != 0
		expect(moving and _authority(worlds[0]).water == 48 * 255, "actual imported Brine motion coexists with exact conserved Water quantity")
		for world: Variant in worlds:
			var counts: Dictionary = {16:0, 24:0}
			for y: int in range(81):
				for x: int in range(96):
					var material: int = world.material_at(x, y)
					if counts.has(material): counts[material] += 1
			expect(counts[16] == 48 and counts[24] == 48, "actual imported Oil/Brine cells survive interactions")
			var saved: PackedByteArray = bridge.export_physical_state(world)
			var restored: Variant = _new_world(workers)
			expect(saved.decode_u32(4) == 3 and bridge.import_physical_state(restored, saved)
				and restored.get_physical_state_hash() == world.get_physical_state_hash(), "imported three-family continuation exports/restores actual CYPS3")
			for _step: int in range(3): expect(world.simulation_tick() and restored.simulation_tick()
				and world.get_physical_state_hash() == restored.get_physical_state_hash(), "restored mixed imported continuation is exact")
			hashes.append(world.get_physical_state_hash())
		results.append(hashes)
	expect(results[0] == results[1], "each imported PF/IN arm has identical full state at configured1/4 workers")

func _legacy_preservation() -> void:
	var bytes: PackedByteArray = _thermal_bytes()
	_put(bytes, 12, 8, 0, 0, 0, 2718)
	var world: Variant = _new_world()
	var inertial: PackedInt32Array = _choose(defaults, 24, "inertial_cellular_v1")
	if not _install(world, bytes, inertial, _options("", 3)): return
	expect(bridge.import_level(world, bytes), "legacy CYSD reconstruction still accepts valid decoded tuples")
	var applied: Dictionary = world.get_liquid_solver_policy()
	var validation: Dictionary = bridge.validate_liquid_policy(defaults)
	expect(applied.policy_hash == validation.receipt.policy_hash and applied.maximum_rule_radius == 2
		and world.get_physical_state_hash_version() == 2 and world.get_physical_state_format_version() == 2
		and world.get_applied_liquid_construction_receipt().is_empty(), "legacy import retires candidate typed identity and restores protected Current families/radius2")
	expect(bridge.export_level(world) == bytes, "legacy full decoded thermal payload roundtrip remains byte exact")
	var before: Dictionary = _snapshot(world)
	expect(not bridge.import_level(world, bytes.slice(0, 20)) and _snapshot(world) == before,
		"legacy malformed payload refusal retains actual old World")
	var token: int = _prepare(world, bytes, defaults)
	expect(world.reset_demo_world() and not bridge.commit_liquid_world(world, token), "ordinary Current reset retires pending imported candidate")
	expect(world.get_liquid_solver_policy().maximum_rule_radius == 2 and world.get_physical_state_hash_version() == 2
		and world.get_applied_liquid_construction_receipt().is_empty(), "ordinary default reset preserves Current2 and has no stale native applied receipt")
