extends SceneTree

# Standalone LCB-005 binding qualification. No prepared-token host or UI is used.
const Contract = preload("res://scripts/microscenario_contract.gd")
const SECTIONS: Array[String] = ["oracle_parameters", "instance_readback", "radius_transaction",
	"mixed_workers", "cyps_continuation", "default_preservation"]
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
const FRAME: Vector2i = Vector2i(1024, 1024)
var water_policy: PackedInt32Array = PackedInt32Array([1, 8, 12, 0])
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var bridge: Variant
var defaults: PackedInt32Array
var profile: PackedInt32Array
var oracle: Dictionary

func _initialize() -> void:
	for section: String in SECTIONS: completed[section] = false
	_run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("LCB_INERTIAL_ADAPTER: " + message)
	return value

func section(name: String, body: Callable) -> void:
	var before: int = failures
	body.call()
	completed[name] = failures == before

func _run() -> void:
	if not expect(ClassDB.class_exists(&"CyberDemoBridge") and ClassDB.class_exists(&"CyberNativeCellWorld"), "native classes required"):
		_finish(); return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	var probe: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not expect(probe.has_method(&"inspect_inertial_cell") and probe.has_method(&"get_physical_state_format_version"), "fresh standalone IN bindings required"):
		_finish(); return
	defaults = bridge.default_liquid_policy()
	oracle = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/lcb/inertial-adapter-parameters.json"))
	if not expect(oracle.get("schema", "") == "lcb-inertial-adapter-vectors-v1", "independent adapter vectors required"):
		_finish(); return
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"))
	var checked: Dictionary = Contract.validate(definition)
	if not expect(checked.get("ok", false), "registered Current transport required"):
		_finish(); return
	profile = checked.transport.packed
	section("oracle_parameters", _oracle_parameters)
	section("instance_readback", _instance_readback)
	section("radius_transaction", _radius_transaction)
	section("mixed_workers", _mixed_workers)
	section("cyps_continuation", _cyps_continuation)
	section("default_preservation", _default_preservation)
	_finish()

func _finish() -> void:
	print("LCB_INERTIAL_ADAPTER: %d assertions; %d failures; completed=%s" % [assertions, failures, JSON.stringify(completed)])
	quit(1 if failures else 0)

func _with(request: PackedInt32Array, material: int, family: int, variant: int = 0) -> PackedInt32Array:
	var words: PackedInt32Array = request.duplicate()
	words[20 + LIQUIDS.find(material) * 3 + 1] = family
	words[20 + LIQUIDS.find(material) * 3 + 2] = variant
	return words

func _policy(numerator: int = 1) -> PackedInt32Array:
	return PackedInt32Array(oracle.damping_cases[numerator].words)

func _build(world: Variant, request: PackedInt32Array, rectangles: PackedInt32Array, radius: int = 3) -> bool:
	return bridge.build_liquid_policy_world(world, rectangles, profile, water_policy, PackedInt32Array(), request, radius)

func _box() -> PackedInt32Array:
	return PackedInt32Array([0, 0, 96, 1, 1, 0, 80, 96, 1, 1, 0, 0, 1, 80, 1, 95, 0, 1, 80, 1,
		28, 60, 8, 6, 3, 36, 60, 8, 6, 16, 32, 40, 8, 6, 24])

func _oracle_parameters() -> void:
	for vector: Dictionary in oracle.native_cases:
		var result: Dictionary = bridge.validate_liquid_policy(PackedInt32Array(vector.words))
		expect(result.accepted == vector.accepted, "native admission matches frozen independent case " + vector.name)
		if vector.accepted:
			expect(result.receipt.policy_hash == vector.policy_hash and result.receipt.family_parameters.inertial_cellular_v1.extension_identity == vector.extension_identity,
				"canonical request and actual law identity match frozen oracle")
		else:
			expect(result.refusal.code == vector.refusal, "invalid block retains exact typed refusal")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var identities: Dictionary = {}
	for vector: Dictionary in oracle.damping_cases:
		var validation: Dictionary = bridge.validate_liquid_policy(PackedInt32Array(vector.words))
		expect(validation.accepted and validation.receipt.maximum_rule_radius == null
			and validation.receipt.family_parameters.inertial_cellular_v1.readback_source == "validated_policy", "validation is prediction rather than applied geometry")
		if not expect(_build(world, PackedInt32Array(vector.words), _box()), "all17 values construct at explicit radius3: " + bridge.get_last_error()): return
		var readback: Dictionary = world.get_liquid_solver_policy()
		var parameters: Dictionary = readback.family_parameters.inertial_cellular_v1
		expect(readback.policy_hash == vector.policy_hash and readback.envelope == PackedInt32Array(vector.words), "applied envelope/hash match independent Python bytes")
		expect(parameters.damping_numerator == vector.damping_numerator and parameters.damping_denominator == 16
			and parameters.block_version == 2 and parameters.family_version == 1 and parameters.minimum_rule_radius == 3
			and parameters.extension_identity == vector.extension_identity and parameters.readback_source == "applied_world", "actual applied parameters and extension match independent oracle")
		expect(readback.physical_state_hash_version == 3 and readback.physical_state_format_version == 3
			and readback.maximum_rule_radius == 3 and world.get_physical_state_hash_version() == 3 and world.get_physical_state_format_version() == 3, "actual IN instance uses hash3/CYPS3")
		var receipt: Dictionary = world.get_liquid_run_receipt({"setup_hash":"standalone-in"})
		expect(receipt.components.physical_state_hash_version == "3" and receipt.components.inertial_parameter_identity == vector.extension_identity
			and receipt.receipt_hash == _dictionary_identity(receipt.components), "older dictionary identity binds actual instance and IN law without claiming typed host proof")
		identities[parameters.extension_identity] = true
		expect(world.simulation_tick(), "each damping value executes an actual native tick")
	expect(identities.size() == 17, "all17 effective laws have distinct identities")

func _dictionary_identity(components: Dictionary) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	_put(hash, "lcb-run-receipt-v1")
	var keys: Array[String] = ["policy_hash", "water_policy", "transport_profile", "interaction_policy", "workers", "backend", "scheduler", "diagnostic_physics", "execution", "simulation_region", "physical_state_hash_version"]
	if components.has("inertial_parameter_identity"): keys.append("inertial_parameter_identity")
	keys.append_array(["setup_hash", "seed", "normalization_receipt", "source_revision", "native_binary_sha256", "catalogue_digest"])
	for key: String in keys:
		_put(hash, key); _put(hash, str(components[key]))
	return hash.finish().hex_encode()

func _put(hash: HashingContext, text: String) -> void:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	var length: PackedByteArray = PackedByteArray(); length.resize(4); length.encode_u32(0, bytes.size())
	hash.update(length); hash.update(bytes)

func _instance_readback() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(_build(world, _policy(7), _box()), "readback fixture constructs")
	var before: String = world.get_physical_state_hash()
	var saved: PackedByteArray = bridge.export_physical_state(world)
	var state: Dictionary = world.inspect_inertial_cell(Vector2i(32, 40))
	expect(state.ok and state.available and state.inertial_family and state.material == 24
		and state.vx == 0 and state.vy == 0 and state.ax == 0 and state.ay == 0, "new IN cells expose exact zero motion")
	state.vx = 31
	var readback: Dictionary = world.get_liquid_solver_policy()
	readback.family_parameters.inertial_cellular_v1.damping_numerator = 16
	expect(world.inspect_inertial_cell(Vector2i(32, 40)).vx == 0
		and world.get_liquid_solver_policy().family_parameters.inertial_cellular_v1.damping_numerator == 7, "returned cell/parameter dictionaries own their copies")
	var empty: Dictionary = world.inspect_inertial_cell(Vector2i(50, 50))
	expect(empty.ok and empty.available and not empty.inertial_family and empty.vx == 0 and empty.vy == 0, "foreign/Empty slots contain no IN motion")
	expect(not world.inspect_inertial_cell(Vector2i(-1, 0)).ok and not world.inspect_inertial_cell(FRAME).ok, "out-of-domain copies refuse")
	expect(world.get_physical_state_hash() == before and bridge.export_physical_state(world) == saved, "all copied readbacks preserve exact native authority and continuation")

func _radius_transaction() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.build_liquid_policy_world(world, _box(), profile, water_policy, PackedInt32Array(), defaults), "legacy six-argument Current construction remains valid")
	var before: String = world.get_physical_state_hash()
	var saved: PackedByteArray = bridge.export_physical_state(world)
	var generation: int = world.get_liquid_policy_session_generation()
	expect(not bridge.build_liquid_policy_world(world, _box(), profile, water_policy, PackedInt32Array(), _policy()), "IN never silently upgrades the legacy radius2 factory")
	for radius: int in [2, 0, 1, 4, 9223372036854775807]:
		expect(not _build(world, _policy(), _box(), radius), "unsupported/insufficient explicit execution radius refuses")
		expect(world.get_physical_state_hash() == before and bridge.export_physical_state(world) == saved
			and world.get_liquid_policy_session_generation() == generation, "radius refusal preserves complete retained World and generation")
	expect(_build(world, _policy(), _box(), 3), "explicit radius3 constructs actual IN")
	expect(world.get_liquid_solver_policy().maximum_rule_radius == 3, "construction reports actual selected radius")

func _census(world: Variant) -> Dictionary:
	var result: Dictionary = {"water":0, "oil":0, "brine":0, "motion":false}
	for y: int in range(81):
		for x: int in range(480):
			var material: int = world.material_at(x, y)
			if material == 3: result.water += 1
			if material == 16: result.oil += 1
			if material == 24:
				result.brine += 1
				var state: Dictionary = world.inspect_inertial_cell(Vector2i(x, y))
				result.motion = result.motion or state.vx != 0 or state.vy != 0 or state.ax != 0 or state.ay != 0
	return result

func _mixed_workers() -> void:
	var rectangles: PackedInt32Array = PackedInt32Array()
	for offset: int in [0, 128, 256, 384]:
		var room: PackedInt32Array = _box()
		for index: int in range(0, room.size(), 5): room[index] += offset
		rectangles.append_array(room)
	# The merged source must execute IN beside each admitted PF implementation,
	# as well as protected FreeMass. A separate-lane pass cannot prove this union.
	for water_variant: int in [-1, 0, 1, 2]:
		var policy: PackedInt32Array = _with(_policy(), 3, 3, water_variant) if water_variant >= 0 else _policy()
		var worlds: Array = []
		for workers: int in [1, 4]:
			var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
			expect(world.diagnostic_reset({"workers":workers}), "native configured worker count constructs")
			world.set_simulation_window_enabled(false)
			expect(_build(world, policy, rectangles) and world.get_worker_threads() == workers, "three families construct in one actual World")
			worlds.append(world)
		var motion: bool = false
		var parallel: bool = false
		for tick: int in range(30):
			for world: Variant in worlds: expect(world.simulation_tick(), "mixed native tick succeeds")
			parallel = parallel or worlds[1].get_scheduler_parallel_phases_last_tick() > 0
			if tick == 3: motion = _census(worlds[0]).motion
			expect(worlds[0].get_physical_state_hash() == worlds[1].get_physical_state_hash(), "complete mixed continuation agrees at every tick for configured1/4")
		var totals: Dictionary = _census(worlds[0])
		print("LCB_INERTIAL_ADAPTER_MIXED: ", JSON.stringify({"water_family":"pressure_flow_v1" if water_variant >= 0 else "freemass_v1", "water_variant":water_variant, "motion":motion,
			"parallel":parallel, "totals":totals, "water_integer":worlds[0].water_experiment_observation(Vector2i.ZERO, FRAME).water_integer,
			"worker4":worlds[1].get_worker_threads(), "backend":worlds[1].get_backend_name()}))
		# FreeMass/PF Water can split its conserved quantity across more cells;
		# only whole-cell Oil/Brine populations are fixed by this fixture.
		expect(motion and parallel and totals.water > 0 and totals.oil == 192 and totals.brine == 192
			and worlds[0].water_experiment_observation(Vector2i.ZERO, FRAME).water_integer == 192 * 255, "all three actual families execute with exact quantity/populations and real parallel dispatch")
		# A closed three-cell tube proves actual density exchanges, not coexistence.
		for workers: int in [1, 4]:
			var contact: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
			expect(contact.diagnostic_reset({"workers":workers}), "contact worker geometry")
			contact.set_simulation_window_enabled(false)
			var tube: PackedInt32Array = PackedInt32Array([19, 19, 3, 5, 1, 20, 20, 1, 1, 24, 20, 21, 1, 1, 16, 20, 22, 1, 1, 3])
			expect(_build(contact, policy, tube), "closed mixed density tube constructs")
			for tick: int in range(30): expect(contact.simulation_tick(), "density contact tick succeeds")
			expect(contact.material_at(20, 22) == 24 and contact.material_at(20, 21) == 3 and contact.material_at(20, 20) == 16, "Brine exchanges through Oil and Water under every admitted Water substitution")
	_resting_body_contacts()

func _resting_body_contacts() -> void:
	# Mandatory part of mixed_workers: copied static masks isolate the native
	# material contact hook. This is not an actual Rapier trajectory or timing test.
	var origins: Array[Vector2i] = [Vector2i(20, 20), Vector2i(148, 20), Vector2i(20, 148), Vector2i(148, 148)]
	for numerator: int in [1, 16]:
		for normal: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, 1), Vector2i(1, 1)]:
			var rectangles: PackedInt32Array = PackedInt32Array()
			for origin: Vector2i in origins:
				rectangles.append_array(PackedInt32Array([origin.x - 2, origin.y - 2, 5, 5, 1,
					origin.x, origin.y, 1, 1, 24, origin.x + normal.x, origin.y + normal.y, 1, 1, 0]))
			var worlds: Array = []
			for workers: int in [1, 4]:
				var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
				expect(world.diagnostic_reset({"workers":workers, "contact":1.0}), "resting contact worker/gain controls construct")
				world.set_simulation_window_enabled(false)
				if not expect(_build(world, _policy(numerator), rectangles), "resting IN body fixture constructs"): return
				worlds.append(world)
			var contacts: Array[int] = [0, 0]
			var impulse: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
			var traces: Array[Array] = [[], []]
			var parallel: bool = false
			for tick: int in range(32):
				for arm: int in range(worlds.size()):
					var world: Variant = worlds[arm]
					var states: PackedFloat32Array = PackedFloat32Array()
					for body: int in range(origins.size()):
						var point: Vector2i = origins[body] + normal
						states.append_array(PackedFloat32Array([body + 1, point.x + 0.5, point.y + 0.5, 0, 1, 1, 0, 0, 0, 1, tick + 1]))
					world.prepare_rigid_body_coupling(states, false)
					expect(world.simulation_tick() and world.get_scanned_last_tick() >= 4, "no-motion contact still executes material work")
					var results: PackedFloat32Array = world.rigid_body_results()
					if not expect(results.size() == 4 * 9, "copied contact results contain all four exact body records"): return
					for body: int in range(origins.size()):
						var offset: int = body * 9
						if not expect(results[offset] == body + 1 and results[offset + 5] == 1
							and is_equal_approx(results[offset + 1], normal.x * 1.12) and is_equal_approx(results[offset + 2], normal.y * 1.12),
							"one resting target/normal reports actual Brine density-scaled signed feedback"): return
						expect(results[offset + 3] == 0 and results[offset + 4] == 0 and results[offset + 6] == 0 and results[offset + 7] == 0
							and results[offset + 8] == tick + 1, "mask-only contact has no displacement/correction and retains the consumed sample serial")
						var origin: Vector2i = origins[body]
						var state: Dictionary = world.inspect_inertial_cell(origin)
						expect(world.material_at(origin.x, origin.y) == 24 and state.vx == 0 and state.vy == 0 and state.ax == 0 and state.ay == 0
							and world.rigid_body_id_at(origin.x + normal.x, origin.y + normal.y) == body + 1, "resting contact retains the exact cell/motion and intended mask")
						contacts[arm] += int(results[offset + 5])
						impulse[arm] += Vector2(results[offset + 1], results[offset + 2])
					traces[arm].append(Array(results))
				parallel = parallel or worlds[1].get_scheduler_parallel_phases_last_tick() > 0
				expect(worlds[0].get_physical_state_hash() == worlds[1].get_physical_state_hash()
					and traces[0][-1] == traces[1][-1], "resting contacts and complete continuation agree for configured1/4 each tick")
			expect(contacts == [128, 128] and parallel, "all resting contacts execute and configured-four uses an actual multi-job dispatch")
			print("LCB_INERTIAL_BODY_CONTACTS: ", JSON.stringify({"damping_numerator":numerator, "normal":[normal.x, normal.y], "ticks":32, "bodies":4,
				"contacts_per_arm":contacts, "impulse_x_per_arm":[impulse[0].x, impulse[1].x], "impulse_y_per_arm":[impulse[0].y, impulse[1].y],
				"trace_sha256":JSON.stringify(traces[0]).sha256_text(), "configured_workers":[1, 4], "actual_multijob_dispatch":parallel}))

func _cyps_continuation() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(_build(world, _policy(7), _box()), "CYPS3 running fixture constructs")
	for tick: int in range(7): expect(world.simulation_tick(), "pre-save motion tick")
	var saved: PackedByteArray = bridge.export_physical_state(world)
	expect(not saved.is_empty() and saved.decode_u32(4) == 3, "IN export uses actual CYPS3")
	var restored: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.import_physical_state(restored, saved) and restored.get_physical_state_hash() == world.get_physical_state_hash()
		and restored.get_liquid_solver_policy().maximum_rule_radius == 3 and restored.get_physical_state_format_version() == 3, "CYPS3 restores actual geometry/parameter/slot state into Current adapter")
	for tick: int in range(8):
		expect(world.simulation_tick() and restored.simulation_tick() and world.get_physical_state_hash() == restored.get_physical_state_hash(), "CYPS3 retained motion continues exactly")
	var current: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var current_saved: PackedByteArray = bridge.export_physical_state(current)
	expect(current_saved.decode_u32(4) == 2 and bridge.import_physical_state(restored, current_saved)
		and restored.get_liquid_solver_policy().maximum_rule_radius == 2 and restored.get_physical_state_hash_version() == 2
		and restored.get_physical_state_format_version() == 2 and restored.get_physical_state_hash() == current.get_physical_state_hash(), "non-IN CYPS2 restores radius2 rather than inheriting IN radius3")

func _default_preservation() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var legacy: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(_build(legacy, defaults, _box(), 2), "Current comparator retains the same explicit transport/Water settings")
	for operation: int in range(6):
		expect(_build(world, _policy(7), _box()), "restore IN predecessor before each default constructor")
		var ok: bool = false
		var reference_ok: bool = false
		match operation:
			0: ok = world.reset_demo_world(); reference_ok = legacy.reset_demo_world()
			1: ok = bridge.build_world(world, _box()); reference_ok = bridge.build_world(legacy, _box())
			2: ok = bridge.build_tuned_world(world, _box(), profile); reference_ok = bridge.build_tuned_world(legacy, _box(), profile)
			3: ok = bridge.build_water_feel_world(world, _box(), profile, water_policy, PackedInt32Array()); reference_ok = bridge.build_water_feel_world(legacy, _box(), profile, water_policy, PackedInt32Array())
			4:
				var bytes: PackedByteArray = bridge.export_level(legacy)
				ok = bridge.import_level(world, bytes); reference_ok = bridge.import_level(legacy, bytes)
			5: ok = bridge.build_liquid_policy_world(world, _box(), profile, water_policy, PackedInt32Array(), defaults); reference_ok = bridge.build_liquid_policy_world(legacy, _box(), profile, water_policy, PackedInt32Array(), defaults)
		expect(ok and reference_ok and world.get_liquid_solver_policy().maximum_rule_radius == 2
			and world.get_physical_state_hash_version() == 2 and world.get_physical_state_format_version() == 2, "ordinary/default/CYSD constructors restore radius2 and non-IN versions")
		expect(world.get_physical_state_hash() == legacy.get_physical_state_hash(), "default reconstruction after IN equals original Current constructor")
		var receipt: Dictionary = world.get_liquid_run_receipt({"setup_hash":"standalone-in"})
		expect(receipt.components.physical_state_hash_version == "2" and not receipt.components.has("inertial_parameter_identity")
			and receipt.receipt_hash == _dictionary_identity(receipt.components), "non-IN older receipt identity retains its exact field stream")
		var state: Dictionary = world.inspect_inertial_cell(Vector2i(32, 40))
		expect(state.ok and not state.available and not state.inertial_family, "ordinary Current has no IN sidecar")
