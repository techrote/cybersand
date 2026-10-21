extends SceneTree

# These controls execute both published native-generated examples through the
# same transactional runtime owner as the scene. Products must arise from native
# kernels, and every fixture must finish its own oracle/accounting receipt.
const Runtime = preload("res://scripts/depth/semantic_plane_runtime.gd")
const Cell = preload("res://scripts/cell_world.gd")
const PROFILES: Array[String] = ["semantic-refinery", "semantic-flooded-cavern"]
var assertions: int = 0
var failures: int = 0
var verified_fixtures: int = 0
var results: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("SEMANTIC_EXAMPLES: " + message)

func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberWorldGenerator"), "Native generator required")
	if failures > 0:
		_finish()
		return
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	_expect(generator.has_method(&"generate_plane_bundle"), "Source-matched GEN-005 runtime required")
	if failures > 0:
		_finish()
		return
	for name: String in PROFILES:
		_run_example(generator, name)
	_expect(results.size() == 2, "Both example helpers returned complete results")
	_expect(verified_fixtures == 40, "Every one of forty authored fixtures completed its own oracle")
	for name: String in PROFILES:
		_expect(bool(results.get(name, {}).get("complete", false)), name + " helper completed; script aborts cannot pass")
	_finish()

func _run_example(generator: Object, name: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(
		"res://../examples/worldgen/" + name + ".json")))
	_expect(parsed is Dictionary, name + " recipe loads")
	if not parsed is Dictionary:
		return
	var configured: Dictionary = generator.configure(parsed)
	_expect(configured.get("ok", false), name + " configures: " + str(configured.get("error", "")))
	if not configured.get("ok", false):
		return
	var bundle: Dictionary = generator.generate_plane_bundle()
	_expect(bundle.get("ok", false) and bundle.get("complete", false), name + " generates complete native bundle: " + str(bundle.get("error", "")))
	if not bundle.get("ok", false):
		return
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	_expect(runtime.install_bundle(bundle), name + " admits complete bundle: " + runtime.last_error)
	if runtime.generation() == 0:
		return
	_expect(runtime.lifecycle_stats().registered_fixtures == 20, name + " registers all twenty fixture records exactly once")
	_expect(runtime.actor_snapshot().count == 4, name + " has four play-only sampled actor owners")
	var origin: Vector2i = bundle.bounds.position
	var features: Dictionary = {}
	for feature: Dictionary in bundle.features:
		features[feature.id] = feature
	var records: Dictionary = {}
	var initial_packets: Dictionary = {}
	for plane: String in Runtime.IDS:
		initial_packets[plane] = runtime.snapshot_layer(plane, true)
	for fixture: Dictionary in bundle.fixtures:
		var feature_bounds: Rect2i = features[fixture.feature_id].bounds
		var observation := Rect2i(feature_bounds.position - origin, feature_bounds.size)
		var rect: Rect2i = fixture.bounds
		var below := Rect2i(feature_bounds.position.x + 1 - origin.x, rect.end.y + 2 - origin.y,
			feature_bounds.size.x - 2, maxi(1, feature_bounds.end.y - rect.end.y - 3))
		var initial: Dictionary = {}
		var maximum: Dictionary = {}
		for product: int in fixture.expected_products:
			initial[product] = _count(initial_packets[fixture.plane].cells, product, observation)
			maximum[product] = initial[product]
		records[fixture.id] = {"adapter": fixture.adapter, "plane": fixture.plane,
			"observation": observation, "downstream": below,
			"initial": initial, "maximum": maximum, "transport_max": 0,
			"transport_initial": _count(initial_packets[fixture.plane].cells, Cell.WATER, below),
			"oracle_completed": false, "oracle_assertions": 0, "verified": false}
	_expect(runtime.configure_rates({"play": 0, "scripted": 20, "effects": 0}), name + " isolates rear native reaction clock")
	for tick: int in range(220):
		var stepped: Dictionary = runtime.step_once()
		_expect(stepped.ok, name + " rear-only step %d" % tick)
		if not stepped.ok:
			return
		if tick % 4 == 0:
			_observe(runtime, bundle, records, "scripted")
	_expect(runtime.layer_tick("scripted") == 220 and runtime.layer_tick("play") == 0 and runtime.layer_tick("effects") == 0, name + " native clocks stay independent")
	for plane: String in ["play", "effects", "background"]:
		_expect(runtime.snapshot_layer(plane, true).cells == initial_packets[plane].cells, name + " rear-only chemistry leaves complete " + plane + " material state unchanged")
	_expect(runtime.actor_snapshot().tick == 0, name + " rear reactions do not advance play actor session")
	var rear_final: Dictionary = runtime.snapshot_layer("scripted", true)
	_expect(runtime.configure_rates({"play": 30, "scripted": 0, "effects": 15}), name + " activates foreground and atmosphere clocks independently")
	for tick: int in range(240):
		var stepped: Dictionary = runtime.step_once()
		_expect(stepped.ok, name + " play/effects step %d" % tick)
		if not stepped.ok:
			return
		if tick % 4 == 0:
			_observe(runtime, bundle, records, "play")
	_expect(runtime.snapshot_layer("scripted", true).cells == rear_final.cells, name + " frozen rear is not modified by foreground or atmosphere programme")
	_expect(runtime.layer_tick("background") == 0 and runtime.snapshot_layer("background", true).cells == initial_packets.background.cells, name + " distant material stays frozen during all programmes")
	var ledger: Dictionary = runtime.lifecycle_stats()
	var total_applications: int = 0
	var expected_writes: int = 0
	var expected_cleanup: int = 0
	var reacted: int = 0
	var transported: int = 0
	for fixture: Dictionary in bundle.fixtures:
		var completed_before: int = assertions
		var failures_before: int = failures
		var record: Dictionary = records[fixture.id]
		var state: Dictionary = ledger.fixtures[fixture.id]
		_expect(state.fired == fixture.repeat, fixture.id + " complete finite repeat accounting")
		_expect(state.retired and (fixture.cleanup_tick == 0 or state.cleaned), fixture.id + " has completed retirement and required cleanup")
		var area: int = fixture.bounds.size.x * fixture.bounds.size.y
		total_applications += fixture.repeat
		expected_writes += area * fixture.repeat
		expected_cleanup += area if fixture.cleanup_tick > 0 else 0
		for product: int in fixture.expected_products:
			_expect(record.initial[product] == 0, fixture.id + " product absent in generated input")
			var painted: bool = false
			for source: Dictionary in bundle.fixtures:
				painted = painted or (source.feature_id == fixture.feature_id and source.plane == fixture.plane and source.material == product)
			_expect(not painted, fixture.id + " product never supplied as feed/setup")
			_expect(record.maximum[product] > 0, fixture.id + " native product actually observed")
			_expect(record.transport_max > record.transport_initial, fixture.id + " Water transported below its source before reaction")
			reacted += 1
		if fixture.adapter == "waterfall-feed":
			_expect(record.transport_max > record.transport_initial, fixture.id + " Water travels below authored waterfall nozzle")
			transported += 1
		record.oracle_assertions = assertions - completed_before
		record.oracle_completed = true
		record.verified = failures == failures_before and record.oracle_assertions > 0
		_expect(record.verified, fixture.id + " completed and passed explicit oracle")
		if record.verified:
			verified_fixtures += 1
	_expect(reacted == 4 and transported == 4, name + " all four regional reaction and waterfall controls executed")
	_expect(ledger.applications == total_applications and ledger.fixture_cell_writes == expected_writes and ledger.cleanup_cell_writes == expected_cleanup, name + " full source/cleanup accounting matches all authored schedules")
	for record: Dictionary in records.values():
		_expect(record.oracle_completed and record.oracle_assertions > 0 and record.verified, name + " every helper returned meaningful completion receipt")
	var receipt: Dictionary = {"complete": true, "revision": bundle.revision, "fixtures": records,
		"applications": ledger.applications, "fixture_cell_writes": ledger.fixture_cell_writes,
		"cleanup_cell_writes": ledger.cleanup_cell_writes, "rear_ticks": 220, "play_effects_ticks": 240,
		"reaction_controls": reacted, "waterfall_controls": transported}
	results[name] = receipt
	print("SEMANTIC_EXAMPLE_MECHANISMS %s reactions=%d waterfalls=%d fixtures=%d applications=%d" % [name, reacted, transported, records.size(), ledger.applications])

func _observe(runtime: CyberSemanticPlaneRuntime, bundle: Dictionary, records: Dictionary, plane: String) -> void:
	var packet: Dictionary = runtime.snapshot_layer(plane, true)
	_expect(not packet.get("failed", false) and packet.cells.size() == 2097152, "Complete copied native observation for " + plane)
	if packet.get("failed", false) or packet.cells.size() != 2097152:
		return
	for fixture: Dictionary in bundle.fixtures:
		if fixture.plane != plane:
			continue
		var record: Dictionary = records[fixture.id]
		for product: int in fixture.expected_products:
			record.maximum[product] = maxi(record.maximum[product], _count(packet.cells, product, record.observation))
		if fixture.adapter in ["reactor-water", "waterfall-feed"]:
			record.transport_max = maxi(record.transport_max, _count(packet.cells, Cell.WATER, record.downstream))

func _count(bytes: PackedByteArray, material: int, bounds: Rect2i) -> int:
	if bytes.size() != 2097152:
		return 0
	var result: int = 0
	for y: int in range(maxi(0, bounds.position.y), mini(1024, bounds.end.y)):
		for x: int in range(maxi(0, bounds.position.x), mini(1024, bounds.end.x)):
			if bytes[(y * 1024 + x) * 2] == material:
				result += 1
	return result

func _finish() -> void:
	var report: Dictionary = {"assertions": assertions, "failures": failures,
		"verified_fixtures": verified_fixtures, "examples": results}
	var destination: String = OS.get_environment("CYBERSAND_GEN005_EXAMPLES_REPORT")
	if not destination.is_empty():
		var output: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		_expect(output != null, "Requested mechanism report writable")
		if output != null:
			report["assertions"] = assertions
			report["failures"] = failures
			output.store_string(JSON.stringify(report, "\t"))
	print("SEMANTIC_PLANES_EXAMPLES: %d assertions; %d failures; verified_fixtures=%d" % [assertions, failures, verified_fixtures])
	quit(1 if failures else 0)
