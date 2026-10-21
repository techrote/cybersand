extends SceneTree

const Runtime = preload("res://scripts/depth/semantic_plane_runtime.gd")
const Cell = preload("res://scripts/cell_world.gd")
const REV: String = "0000000000000001"
const FEATURE: String = "test/grid64/region(-1,-1)/reactor/0"
const ORIGIN := Vector2i(-64, -64)
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var mechanism_controls: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("SEMANTIC_PLANES: " + message)

func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "Native extension is mandatory")
	if failures > 0:
		quit(1)
		return
	_admission_and_events()
	_lifecycle_and_clocks()
	_native_reactions()
	_actor_owner()
	for section: String in ["admission", "events", "lifecycle", "clocks", "reactions", "actors"]:
		_expect(bool(completed.get(section, false)), section + " completed its oracle; aborting a helper cannot pass")
	var report: Dictionary = {"assertions": assertions, "failures": failures,
		"completed": completed, "mechanism_controls": mechanism_controls}
	var destination: String = OS.get_environment("CYBERSAND_GEN005_RUNTIME_REPORT")
	if not destination.is_empty():
		var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		_expect(file != null, "Requested runtime evidence is writable")
		if file != null:
			report["assertions"] = assertions
			report["failures"] = failures
			file.store_string(JSON.stringify(report, "\t"))
	print("SEMANTIC_PLANES_RUNTIME: %d assertions; %d failures; completed=%s" % [assertions, failures, str(completed)])
	quit(1 if failures else 0)

func _rect(x: int, y: int, w: int, h: int) -> Rect2i:
	return Rect2i(ORIGIN + Vector2i(x, y), Vector2i(w, h))

func _fixture(id: String, plane: String, bounds: Rect2i, material: int, first: int,
		period: int, repeat_count: int, mode: String = "source", cleanup: int = 0, products: Array = []) -> Dictionary:
	return {"id": id, "feature_id": FEATURE, "plane": plane, "bounds": bounds,
		"material": material, "first_tick": first, "period": period, "repeat": repeat_count,
		"cleanup_tick": cleanup, "mode": mode, "expected_products": products,
		"clock": plane, "lifecycle": "finite-owner-v1", "revision": REV}

func _link(id: String, family: String, classification: String, from: String, to: String,
		effect: String, material: int = Cell.EMPTY, radius: int = 0, fixture_id: String = "") -> Dictionary:
	return {"id": id, "family": family, "classification": classification,
		"source_feature": FEATURE, "target_feature": FEATURE, "source_plane": from, "target_plane": to,
		"effect": effect, "bounds": _rect(32, 20, 17, 17) if classification == "runtime" else _rect(8, 8, 48, 48), "material": material,
		"radius": radius, "max_events_per_tick": 1, "fixture_id": fixture_id,
		"lifecycle": "bundle-generation-v1", "revision": REV}

func _bundle() -> Dictionary:
	var projections: Array[Dictionary] = []
	for plane: String in ["play", "scripted", "effects", "background"]:
		projections.append({"id": "projection-" + plane, "revision": REV, "feature_id": FEATURE, "plane": plane,
			"bounds": _rect(8, 8, 48, 48), "material": Cell.EMPTY, "interior": Cell.EMPTY, "shape": "fill"})
	var result: Dictionary = {"complete": true, "schema": 1, "id": "owner-regression", "revision": REV, "bounds": _rect(0, 0, 64, 64),
		"rates": {"play": 30, "scripted": 20, "effects": 15, "background": 0},
		"features": [{"id": FEATURE, "revision": REV, "bounds": _rect(8, 8, 48, 48)}],
		"projections": projections,
		"layers": {
			"play": PackedInt32Array([8, 54, 48, 2, Cell.STEEL_PLATE, 32, 20, 17, 17, Cell.CHEMICAL_GLASS]),
			"scripted": PackedInt32Array([8, 8, 2, 48, Cell.WALL, 54, 8, 2, 48, Cell.WALL, 8, 54, 48, 2, Cell.WALL,
				14, 47, 16, 5, Cell.SALT, 32, 20, 17, 17, Cell.STEEL_PLATE]),
			"effects": PackedInt32Array(), "background": PackedInt32Array([20, 8, 8, 48, Cell.GRANITE_BLOCK]),
		},
		"fixtures": [
			_fixture("reactor-water", "scripted", _rect(20, 14, 4, 1), Cell.WATER, 1, 12, 4, "source", 0, [Cell.BRINE]),
			_fixture("reactor-setup", "scripted", _rect(10, 10, 2, 2), Cell.STEEL_PLATE, 0, 1, 1, "setup"),
			_fixture("waterfall-water", "play", _rect(15, 14, 4, 1), Cell.WATER, 1, 8, 3),
			_fixture("spray", "effects", _rect(40, 16, 3, 1), Cell.STEAM, 1, 10, 3, "source", 30),
			_fixture("drain", "effects", _rect(44, 40, 4, 4), Cell.EMPTY, 1, 8, 4, "drain"),
		],
		"links": [
			_link("blast", "explosion", "runtime", "play", "scripted", "blast", Cell.FIRE, 4),
			_link("burst", "vent", "runtime", "scripted", "effects", "burst", Cell.STEAM, 2),
			_link("window", "window", "presentation", "play", "background", "visibility"),
			_link("pipe", "pipe", "static", "play", "scripted", "correspondence"),
			_link("waterfall", "waterfall", "static", "play", "effects", "source_and_spray", Cell.EMPTY, 0, "spray"),
			_link("machine", "machinery", "static", "play", "scripted", "correspondence"),
			_link("drain-link", "vent", "static", "scripted", "effects", "drain", Cell.EMPTY, 0, "drain"),
		],
		"budgets": {"max_events_per_tick": 4, "max_fixture_cell_writes": 4096, "max_publication_bytes": 16777216}}

	_refresh_materials(result)
	return result

func _refresh_materials(bundle: Dictionary) -> void:
	var materials: Dictionary = {}
	var size: Vector2i = bundle.bounds.size
	for plane: String in Runtime.IDS:
		var values := PackedByteArray()
		values.resize(size.x * size.y)
		var rectangles: PackedInt32Array = bundle.layers[plane]
		for offset: int in range(0, rectangles.size(), 5):
			for y: int in range(rectangles[offset + 1], rectangles[offset + 1] + rectangles[offset + 3]):
				for x: int in range(rectangles[offset], rectangles[offset] + rectangles[offset + 2]):
					values[y * size.x + x] = rectangles[offset + 4]
		materials[plane] = values
	bundle["materials"] = materials

func _admission_and_events() -> void:
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	var bundle: Dictionary = _bundle()
	_expect(runtime.install_bundle(bundle), "Complete bundle installs: " + runtime.last_error)
	if runtime.generation() == 0:
		return
	var old_generation: int = runtime.generation()
	var preserved: Dictionary = runtime.snapshot_layer("background", true)
	var observation: Dictionary = runtime.event_observation("blast")
	_expect(observation.get("accepted", false), "Owner issues copied blast observation")
	var bads: Array[Dictionary] = []
	var bad: Dictionary = bundle.duplicate(true)
	bad.complete = false
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.materials.play[0] = 255
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.projections[0].shape = "unsupported_geometry"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.projections[0].density = NAN
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.projections[0].revision = "stale"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.features.clear()
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[0].target_feature = "missing"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[0].source_plane = "scripted"
	bad.links[0].target_plane = "play"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[0].bounds = _rect(63, 20, 17, 17)
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[0].family = "implicit_material_reaction"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.layers.play[4] = 10
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures[0].material = 10
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures[0].plane = "background"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures[0].repeat = 0
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures[0].first_tick = 0.5
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures[0].clock = "play"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures[1].repeat = 2
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.fixtures.append(bad.fixtures[0].duplicate(true))
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[2].classification = "runtime"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[3].target_plane = "play"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[4].target_plane = "background"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.links[5].effect = "unbounded_destroy"
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.rates.background = 1
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.budgets.max_publication_bytes = 1
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.budgets.max_fixture_cell_writes = 1
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.budgets.max_events_per_tick = 0
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.features[0].bounds = Rect2i(2147483640, 0, 128, 128)
	bads.append(bad)
	bad = bundle.duplicate(true)
	bad.layers.play[4] = Cell.WALL # Valid data cannot reuse an admitted revision.
	bads.append(bad)
	for index: int in range(bads.size()):
		_expect(not runtime.install_bundle(bads[index]), "Malformed candidate %d rejected" % index)
		_expect(runtime.generation() == old_generation and runtime.layer_tick("scripted") == 0, "Rejection preserves clocks and generation")
		_expect(runtime.lifecycle_stats().registered_fixtures == 5 and runtime.lifecycle_stats().registered_links == 7, "Rejection preserves registrations")
		_expect(runtime.snapshot_layer("background", true).cells == preserved.cells, "Rejection preserves frozen publication")
		_expect(runtime.lifecycle_stats().outstanding_observations == 1, "Rejection preserves issued owner observation")
	var existing_layers: Dictionary = {}
	for plane: String in Runtime.IDS:
		existing_layers[plane] = runtime.snapshot_layer(plane, true).cells
	for omitted_plane: String in ["scripted", "background"]:
		bad = bundle.duplicate(true)
		bad.revision = "0000000000000002"
		for projection: Dictionary in bad.projections:
			if projection.plane == omitted_plane:
				projection.shape = "omit"
				projection["omission"] = "Explicitly omitted endpoint control"
		var expected_error: String = "semantic_fixture_projection" if omitted_plane == "scripted" else "semantic_link_projection"
		_expect(not runtime.install_bundle(bad, old_generation), "Omitted " + omitted_plane + " projection cannot authorize replacement endpoints")
		_expect(runtime.last_error == expected_error, "Omission rejects at endpoint validation before revision admission")
		_expect(runtime.generation() == old_generation and runtime.layer_tick("scripted") == 0 and runtime.lifecycle_stats().outstanding_observations == 1, "Omitted endpoint rejection preserves generation, clock and observation")
		for plane: String in Runtime.IDS:
			_expect(runtime.snapshot_layer(plane, true).cells == existing_layers[plane], "Omitted endpoint rejection preserves complete " + plane + " World")
	_expect(not runtime.install_bundle(bundle, old_generation - 1), "Stale installation generation rejected")
	completed["admission"] = true
	var play_before: Dictionary = runtime.snapshot_layer("play", true)
	var rear_before: Dictionary = runtime.snapshot_layer("scripted", true)
	var cell: Vector2i = observation.cell
	var forged: Dictionary = observation.duplicate(true)
	forged.source_feature = "unobserved"
	_expect(not runtime.submit_event(forged).accepted, "Forged source identity rejected")
	forged = observation.duplicate(true)
	forged.revision = "0000000000000002"
	_expect(not runtime.submit_event(forged).accepted, "Stale revision rejected")
	forged = observation.duplicate(true)
	forged.cell = ORIGIN + Vector2i(9, 9)
	_expect(not runtime.submit_event(forged).accepted, "Effect outside link zone rejected")
	forged = observation.duplicate(true)
	forged.radius = 8
	_expect(not runtime.submit_event(forged).accepted, "Expanded effect radius rejected")
	forged = observation.duplicate(true)
	forged.material = Cell.SAND
	_expect(not runtime.submit_event(forged).accepted, "Undeclared effect material rejected")
	_expect(runtime.submit_event(observation).accepted, "Declared blast accepted")
	_expect(not runtime.submit_event(observation).accepted, "Consumed observation cannot replay")
	var second: Dictionary = runtime.event_observation("blast")
	_expect(not runtime.submit_event(second).accepted, "Per-link native-tick event rate enforced")
	_expect(runtime.advance(0.0, true).ok, "Paused owner flushes explicit admitted event")
	_expect(runtime.material_at_world("scripted", cell) == Cell.FIRE, "Native rear blast actually applied")
	_expect(runtime.snapshot_layer("scripted", true).cells != rear_before.cells, "Rear result is observable")
	_expect(runtime.snapshot_layer("play", true).cells == play_before.cells, "Rear blast leaves all play cells unchanged")
	_expect(runtime.snapshot_layer("background", true).cells == preserved.cells, "Rear blast leaves frozen background unchanged")
	var burst: Dictionary = runtime.event_observation("burst")
	_expect(runtime.submit_event(burst).accepted, "Declared atmospheric burst accepted")
	runtime.advance(0.0, true)
	_expect(runtime.material_at_world("effects", burst.cell) == Cell.STEAM, "Burst changes only separately owned effects")
	for id: String in ["window", "pipe", "waterfall", "machine", "drain-link"]:
		_expect(not runtime.event_observation(id).accepted, id + " correspondence is not runtime write authority")
	_expect(not runtime.paint_disc("background", Vector2i(30, 30), 2, Cell.FIRE).accepted, "Raw frozen writes rejected")
	_expect(not runtime.route_event("scripted", "play", "blast", Vector2i(30, 30), 4).accepted, "Unregistered reverse writes rejected")
	_expect(not runtime.scripted_blast(Vector2i(30, 30), 4).accepted, "Raw rear bypass rejected")
	_expect(not runtime.set_weather("rain"), "Unregistered infinite source rejected")
	_expect(not runtime.reset(bundle.layers, Vector2i(64, 64)), "Incomplete raw reset rejected")
	var wide: Dictionary = _bundle()
	wide.revision = "0000000000000003"
	wide.links[0].max_events_per_tick = 32
	wide.links[1].max_events_per_tick = 32
	wide.budgets.max_events_per_tick = 64
	_expect(runtime.install_bundle(wide, runtime.generation()), "Capacity fixture installs with explicit replacement generation")
	for _index: int in range(32):
		_expect(runtime.submit_event(runtime.event_observation("blast")).accepted, "Bounded queue accepts its declared capacity")
	var full: Dictionary = runtime.event_observation("burst")
	_expect(not runtime.submit_event(full).accepted and runtime.stats().pending_commands == 32, "Full queue rejects without losing earlier events")
	runtime.advance(0.0, true)
	_expect(runtime.submit_event(full).accepted, "Capacity rejection preserves observation for bounded retry")
	runtime.advance(0.0, true)
	for _index: int in range(32):
		_expect(runtime.event_observation("burst").accepted, "Observation storage admits bounded capacity")
	_expect(not runtime.event_observation("burst").accepted, "Outstanding observation capacity is enforced")
	_expect(runtime.retire_link("burst", runtime.generation(), wide.revision).accepted and runtime.lifecycle_stats().outstanding_observations == 0, "Retirement releases all outstanding observations")
	completed["events"] = true

func _lifecycle_and_clocks() -> void:
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	var bundle: Dictionary = _bundle()
	_expect(runtime.install_bundle(bundle), "Lifecycle fixture admission")
	if runtime.generation() == 0:
		return
	var initial: int = runtime.generation()
	_expect(runtime.step_once().ok, "First native tick executes each initial source")
	var state: Dictionary = runtime.lifecycle_stats()
	_expect(state.fixtures["reactor-setup"].fired == 1 and state.fixtures["reactor-setup"].retired, "One-time setup has complete receipt and retires")
	_expect(state.fixtures["reactor-setup"].receipts.has("install") and state.fixtures["reactor-setup"].receipts.has("activate") and state.fixtures["reactor-setup"].receipts.has("retire"), "Fixture lifecycle receipts retained")
	var before: Dictionary = runtime.snapshot_layer("scripted", true)
	_expect(runtime.install_bundle(bundle) and runtime.generation() == initial, "Duplicate installation is a no-op")
	_expect(runtime.snapshot_layer("scripted", true).cells == before.cells and runtime.lifecycle_stats().applications == state.applications, "Duplicate refresh neither resets worlds nor replays setup")
	_expect(runtime.activate_bundle(initial, REV).accepted, "Activation retry succeeds")
	_expect(runtime.step_once().ok and runtime.lifecycle_stats().fixtures["reactor-setup"].fired == 1, "Activation retry does not replay setup")
	bundle.fixtures[0].repeat = 9999
	_expect(runtime.bundle_metadata().fixtures[0].repeat == 4, "Caller mutation cannot change active programme")
	var copied: Dictionary = runtime.lifecycle_stats()
	copied.fixtures["reactor-water"].fired = 9999
	_expect(runtime.lifecycle_stats().fixtures["reactor-water"].fired != 9999, "Lifecycle inspection returns an independent copy")
	var observed: Dictionary = runtime.event_observation("blast")
	_expect(runtime.submit_event(observed).accepted, "Pending event before retirement")
	var rear_before: Dictionary = runtime.snapshot_layer("scripted", true)
	_expect(runtime.retire_link("blast", initial, REV).accepted, "Link retires")
	runtime.advance(0.0, true)
	_expect(runtime.snapshot_layer("scripted", true).cells == rear_before.cells, "Retirement discards already queued event")
	_expect(not runtime.event_observation("blast").accepted, "Retired link cannot issue observations")
	_expect(runtime.retire_fixture("reactor-water", initial, REV).accepted, "Source retires with owner receipt")
	var fired: int = runtime.lifecycle_stats().fixtures["reactor-water"].fired
	for _tick: int in range(15):
		_expect(runtime.step_once().ok, "Retired-source native step")
	_expect(runtime.lifecycle_stats().fixtures["reactor-water"].fired == fired, "Retired source never emits again")
	_expect(not runtime.reset_bundle(initial - 1, REV).accepted, "Stale reset cannot replace active bundle")
	_expect(not runtime.reset_bundle(initial, "0000000000000009").accepted, "Stale revision cannot reset")
	var old_observation: Dictionary = runtime.event_observation("burst")
	_expect(runtime.reset_bundle(initial, REV).accepted and runtime.generation() == initial + 1, "Explicit reset constructs a new complete generation")
	_expect(not runtime.submit_event(old_observation).accepted, "Reset retires old copied observations")
	_expect(runtime.layer_tick("scripted") == 0 and runtime.lifecycle_stats().fixtures["reactor-setup"].fired == 0, "Reset records new fixture incarnation")
	_expect(runtime.step_once().ok and runtime.lifecycle_stats().fixtures["reactor-setup"].fired == 1, "New world gets exactly one setup")
	_expect(runtime.lifecycle_stats().fixtures["reactor-setup"].receipts.has("reset") and runtime.lifecycle_stats().links.blast.receipts.has("reset"), "Reset binds fixture and link receipts to the new generation")
	var changed: Dictionary = _bundle()
	changed.revision = "0000000000000002"
	_expect(not runtime.install_bundle(changed), "Replacement requires explicit current owner generation")
	_expect(runtime.install_bundle(changed, runtime.generation()), "New semantic revision replaces atomically")
	var accepted_generation: int = runtime.generation()
	_expect(not runtime.install_bundle(_bundle()) and runtime.generation() == accepted_generation, "Retired revision replay cannot replace current bundle")
	changed.adapter_serial = 42
	_expect(runtime.install_bundle(changed) and runtime.generation() == accepted_generation, "Regeneration serial is distinct from immutable semantic content: " + runtime.last_error)
	completed["lifecycle"] = true
	_expect(runtime.reset_bundle(runtime.generation(), "0000000000000002").accepted, "Clock trial reset")
	var background: Dictionary = runtime.snapshot_layer("background", true)
	for _frame: int in range(60):
		_expect(runtime.advance(1.0 / 60.0).ok, "Independent clock advance")
	_expect(runtime.layer_tick("play") == 30 and runtime.layer_tick("scripted") == 20 and runtime.layer_tick("effects") == 15, "Native clocks follow 30/20/15 Hz independently")
	_expect(runtime.layer_tick("background") == 0 and runtime.snapshot_layer("background", true).cells == background.cells, "Background remains frozen throughout programmes")
	_expect(not runtime.configure_rates({"background": 1}), "Background rate cannot be enabled")
	var stale_tick: Dictionary = runtime.event_observation("blast")
	runtime.step_once()
	_expect(not runtime.submit_event(stale_tick).accepted, "Observation of a prior native source tick is stale")
	completed["clocks"] = true

func _native_reactions() -> void:
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	var bundle: Dictionary = _bundle()
	_expect(runtime.install_bundle(bundle), "Reaction bundle admission")
	if runtime.generation() == 0:
		return
	_expect(runtime.configure_rates({"play": 0, "scripted": 20, "effects": 0}), "Only rear native clock activated")
	var play: Dictionary = runtime.snapshot_layer("play", true)
	var effects: Dictionary = runtime.snapshot_layer("effects", true)
	var background: Dictionary = runtime.snapshot_layer("background", true)
	var initial_brine: int = _count(runtime.snapshot_layer("scripted", true).cells, Cell.BRINE, Rect2i(10, 10, 44, 44))
	var products: int = 0
	var transported: int = 0
	for tick: int in range(180):
		var result: Dictionary = runtime.step_once()
		_expect(result.ok, "Rear-only native reaction tick %d" % tick)
		if not result.ok:
			return
		if tick % 6 == 0:
			var packet: Dictionary = runtime.snapshot_layer("scripted", true)
			products = maxi(products, _count(packet.cells, Cell.BRINE, Rect2i(10, 10, 44, 44)))
			transported = maxi(transported, _count(packet.cells, Cell.WATER, Rect2i(10, 30, 21, 23)))
	var stats: Dictionary = runtime.lifecycle_stats()
	var evidence: Dictionary = {"completed": true, "initial_product": initial_brine,
		"products": products, "transported": transported, "source_fired": stats.fixtures["reactor-water"].fired,
		"expected_fired": 4, "product_painted": false}
	_expect(_reaction_oracle(evidence), "Native Water reaches Salt and creates Brine absent from generation/feed: " + str(evidence))
	var noop: Dictionary = evidence.duplicate()
	noop.products = 0
	noop.transported = 0
	_expect(not _reaction_oracle(noop), "No-op fixture cannot pass mechanism oracle")
	var aborted: Dictionary = evidence.duplicate()
	aborted.completed = false
	_expect(not _reaction_oracle(aborted), "Aborted helper cannot pass mechanism oracle")
	var painted: Dictionary = evidence.duplicate()
	painted.product_painted = true
	_expect(not _reaction_oracle(painted), "Directly painting expected products cannot qualify native reaction")
	mechanism_controls["productive"] = evidence.duplicate(true)
	var inactive: Dictionary = _native_reaction_control(false, true)
	var missing_partner: Dictionary = _native_reaction_control(true, false)
	mechanism_controls["inactive_source"] = inactive
	mechanism_controls["missing_salt"] = missing_partner
	_expect(inactive.get("completed", false) and missing_partner.get("completed", false), "Both native counterfactual helpers completed every tick and observation")
	_expect(inactive.get("initial_salt", 0) > 0 and inactive.get("source_fired", -1) == 0, "Inactive source control retains actual Salt and emits no Water")
	_expect(inactive.get("initial_product", -1) == 0 and inactive.get("products", -1) == 0 and inactive.get("transported", -1) == 0, "Inactive native source produces neither Brine nor downstream Water")
	_expect(missing_partner.get("initial_salt", -1) == 0 and missing_partner.get("source_fired", -1) == 4, "Missing-partner control has no native Salt but completes all Water feeds")
	_expect(missing_partner.get("initial_product", -1) == 0 and missing_partner.get("products", -1) == 0 and missing_partner.get("transported", 0) > 0, "Native Water transports without manufacturing Brine when Salt is absent")
	_expect(not _reaction_oracle(inactive) and not _reaction_oracle(missing_partner), "Actual inactive-source and missing-partner runs cannot pass productive reaction oracle")
	_expect(stats.fixtures["reactor-setup"].fired == 1 and stats.fixtures["reactor-water"].fired == 4 and stats.applications == 5, "Complete rear fixture accounting")
	for id: String in ["waterfall-water", "spray", "drain"]:
		_expect(stats.fixtures[id].fired == 0, id + " follows its own paused plane clock")
	_expect(runtime.snapshot_layer("play", true).cells == play.cells, "Rear reactions preserve entire play state")
	_expect(runtime.snapshot_layer("effects", true).cells == effects.cells, "Rear reactions never infer atmospheric writes")
	_expect(runtime.snapshot_layer("background", true).cells == background.cells and runtime.layer_tick("background") == 0, "Rear reactions preserve frozen distant material")
	_expect(runtime.configure_rates({"scripted": 0, "effects": 15}), "Only effects programme activated")
	for _tick: int in range(35):
		_expect(runtime.step_once().ok, "Finite atmospheric source/drain tick")
	stats = runtime.lifecycle_stats()
	_expect(stats.fixtures.spray.fired == 3 and stats.fixtures.spray.cleaned and stats.fixtures.spray.retired, "Finite atmospheric source expires with explicit cleanup")
	_expect(stats.fixtures.drain.fired == 4 and stats.fixtures.drain.retired, "Finite atmospheric drain expires")
	_expect(stats.links["drain-link"].retired and stats.links.waterfall.retired, "Programme retirement leaves no active orphan links")
	_expect(stats.fixtures["reactor-water"].fired == 4 and stats.fixtures["waterfall-water"].fired == 0, "Independent programme clocks preserve previous accounting")
	var active_drain: Dictionary = _native_atmosphere_control(true)
	var inactive_drain: Dictionary = _native_atmosphere_control(false)
	mechanism_controls["atmosphere_drain_active"] = active_drain
	mechanism_controls["atmosphere_drain_inactive"] = inactive_drain
	_expect(active_drain.get("completed", false) and inactive_drain.get("completed", false), "Both native atmosphere helpers completed")
	_expect(active_drain.get("initial_steam", -1) == 0 and active_drain.get("steam", 0) > 0 and active_drain.get("source_fired", -1) == 1, "Finite atmosphere source creates observable native Steam absent from installation")
	_expect(active_drain.get("initial_water", 0) == 4 and inactive_drain.get("initial_water", 0) == 4, "Paired drain controls begin with identical nonempty native target material")
	_expect(active_drain.get("drain_fired", -1) == 1 and active_drain.get("water", -1) == 0, "Scheduled native drain observably removes seeded Water")
	_expect(inactive_drain.get("drain_fired", -1) == 0 and inactive_drain.get("water", 0) == 4, "Retired drain control preserves Water under the same native ticks")
	completed["reactions"] = true
	print("SEMANTIC_NATIVE_REACTION ", JSON.stringify(evidence))
	print("SEMANTIC_NATIVE_CONTROLS ", JSON.stringify(mechanism_controls))

func _native_reaction_control(source_active: bool, salt_present: bool) -> Dictionary:
	var bundle: Dictionary = _bundle()
	if not salt_present:
		var rectangles: PackedInt32Array = bundle.layers.scripted
		for offset: int in range(0, rectangles.size(), 5):
			if rectangles[offset + 4] == Cell.SALT:
				rectangles[offset + 4] = Cell.EMPTY
		bundle.layers.scripted = rectangles
		_refresh_materials(bundle)
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	_expect(runtime.install_bundle(bundle), "Native counterfactual bundle installs: " + runtime.last_error)
	if runtime.generation() == 0:
		return {}
	if not source_active:
		var retired: Dictionary = runtime.retire_fixture("reactor-water", runtime.generation(), REV)
		_expect(retired.accepted, "Native source disabled through its actual owner before stepping")
		if not retired.accepted:
			return {}
	_expect(runtime.configure_rates({"play": 0, "scripted": 20, "effects": 0}), "Counterfactual runs the same rear-only native clock")
	var observation := Rect2i(10, 10, 44, 44)
	var initial: Dictionary = runtime.snapshot_layer("scripted", true)
	var result: Dictionary = {"completed": false, "initial_product": _count(initial.cells, Cell.BRINE, observation),
		"initial_salt": _count(initial.cells, Cell.SALT, observation), "products": 0, "transported": 0,
		"expected_fired": 4, "source_fired": 0, "product_painted": false}
	for tick: int in range(180):
		var stepped: Dictionary = runtime.step_once()
		_expect(stepped.ok, "Native counterfactual tick %d (source=%s, salt=%s)" % [tick, source_active, salt_present])
		if not stepped.ok:
			return result
		if tick % 6 == 0 or tick == 179:
			var packet: Dictionary = runtime.snapshot_layer("scripted", true)
			_expect(not packet.get("failed", false) and packet.cells.size() == 2097152, "Counterfactual observation is a complete successful native snapshot")
			if packet.get("failed", false) or packet.cells.size() != 2097152:
				return result
			result.products = maxi(result.products, _count(packet.cells, Cell.BRINE, observation))
			result.transported = maxi(result.transported, _count(packet.cells, Cell.WATER, Rect2i(10, 30, 21, 23)))
	result.source_fired = runtime.lifecycle_stats().fixtures["reactor-water"].fired
	result["native_ticks"] = runtime.layer_tick("scripted")
	result.completed = result.native_ticks == 180
	return result

func _native_atmosphere_control(drain_active: bool) -> Dictionary:
	var bundle: Dictionary = _bundle()
	# Seed a small Water target inside the authored drain; it remains inside its
	# bounds through the first native tick, before the tick-one drain executes.
	bundle.layers.effects = PackedInt32Array([45, 41, 2, 2, Cell.WATER])
	_refresh_materials(bundle)
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	_expect(runtime.install_bundle(bundle), "Native atmosphere control installs: " + runtime.last_error)
	if runtime.generation() == 0:
		return {}
	if not drain_active:
		var retired: Dictionary = runtime.retire_fixture("drain", runtime.generation(), REV)
		_expect(retired.accepted, "Comparison drain is disabled through its owner")
		if not retired.accepted:
			return {}
	_expect(runtime.configure_rates({"play": 0, "scripted": 0, "effects": 15}), "Atmosphere control advances only native effects")
	var region := Rect2i(8, 8, 48, 48)
	var initial: Dictionary = runtime.snapshot_layer("effects", true)
	var result: Dictionary = {"completed": false,
		"initial_water": _count(initial.cells, Cell.WATER, region), "initial_steam": _count(initial.cells, Cell.STEAM, region)}
	for tick: int in range(2):
		var stepped: Dictionary = runtime.step_once()
		_expect(stepped.ok, "Native atmosphere control tick %d" % tick)
		if not stepped.ok:
			return result
	var packet: Dictionary = runtime.snapshot_layer("effects", true)
	_expect(not packet.get("failed", false) and packet.cells.size() == 2097152, "Atmosphere control publishes complete native material state")
	if packet.get("failed", false) or packet.cells.size() != 2097152:
		return result
	var state: Dictionary = runtime.lifecycle_stats()
	result["water"] = _count(packet.cells, Cell.WATER, region)
	result["steam"] = _count(packet.cells, Cell.STEAM, region)
	result["source_fired"] = state.fixtures.spray.fired
	result["drain_fired"] = state.fixtures.drain.fired
	result["native_ticks"] = runtime.layer_tick("effects")
	result.completed = result.native_ticks == 2
	return result

func _reaction_oracle(evidence: Dictionary) -> bool:
	return bool(evidence.get("completed", false)) and int(evidence.get("initial_product", -1)) == 0 and int(evidence.get("products", 0)) > 0 and int(evidence.get("transported", 0)) > 0 and int(evidence.get("source_fired", 0)) == int(evidence.get("expected_fired", -1)) and not bool(evidence.get("product_painted", true))

func _count(bytes: PackedByteArray, material: int, bounds: Rect2i) -> int:
	if bytes.size() != 2097152:
		_expect(false, "Native copied RG8 publication required")
		return 0
	var result: int = 0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			if bytes[(y * 1024 + x) * 2] == material:
				result += 1
	return result

func _actor_action(snapshot: Dictionary, sequence: int) -> Dictionary:
	return {"actor_id": "inspector", "generation": snapshot.generation, "revision": snapshot.revision,
		"epoch": snapshot.epoch, "observed_tick": snapshot.tick, "sequence": sequence,
		"movement": Vector2.RIGHT, "primary": false, "secondary": false, "lease_ticks": 12, "producer": "policy"}

func _actor_owner() -> void:
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	var bundle: Dictionary = _bundle()
	bundle["actors"] = [{"id": "inspector", "revision": REV, "feature_id": FEATURE,
		"plane": "play", "model": "skimmer", "producer": "policy",
		"position": ORIGIN + Vector2i(12, 20), "lifecycle": "play-owner-v1"}]
	_expect(runtime.install_bundle(bundle), "Sampled play actor installs through existing session: " + runtime.last_error)
	if runtime.generation() == 0:
		return
	var initial: Dictionary = runtime.actor_snapshot()
	_expect(initial.count == 1 and initial.semantic_ids == ["inspector"] and initial.plane == "play", "Actor snapshot binds sampled slot to semantic owner")
	_expect(initial.states[0] == 12 and initial.states[1] == 20, "Absolute spawn translates once into local owner coordinates")
	var generation: int = runtime.generation()
	var play: Dictionary = runtime.snapshot_layer("play", true)
	for malformed: int in range(7):
		var bad: Dictionary = bundle.duplicate(true)
		bad.revision = "0000000000000010"
		match malformed:
			0: bad.actors[0].plane = "scripted"
			1: bad.actors[0].model = "missing-actor-model"
			2: bad.actors[0].feature_id = "missing-feature"
			3: bad.actors[0].position = ORIGIN + Vector2i(50, 50)
			4: bad.actors[0].position = ORIGIN + Vector2i(35, 22) # Material collision; staged owner fails.
			5: bad.actors.append(bad.actors[0].duplicate(true))
			6:
				bad.projections[0].shape = "omit"
				bad.projections[0]["omission"] = "No play actor endpoint"
		_expect(not runtime.install_bundle(bad, generation), "Invalid actor proposal rejected %d" % malformed)
		if malformed == 6:
			_expect(runtime.last_error == "semantic_actor_feature", "Omitted play projection cannot authorize actor ownership")
		_expect(runtime.generation() == generation and runtime.actor_snapshot().states == initial.states, "Actor admission failure preserves old session and generation")
		_expect(runtime.snapshot_layer("play", true).cells == play.cells, "Actor admission failure preserves old native play World")
	var copied: Dictionary = runtime.actor_snapshot()
	copied.states[0] = 999.0
	_expect(runtime.actor_snapshot().states[0] == 12.0, "Actor inspection has no mutable motor alias")
	_expect(runtime.configure_rates({"play": 0, "scripted": 20, "effects": 0}), "Pause actor's native clock only")
	for _tick: int in range(10):
		_expect(runtime.step_once().ok, "Rear-only tick with play actor")
	_expect(runtime.actor_snapshot().tick == 0 and runtime.actor_snapshot().states == initial.states, "Rear ticks neither advance nor collide play actor")
	_expect(not runtime.submit_actor_action(_actor_action(runtime.actor_snapshot(), 1)).accepted, "Paused play rejects actor actions")
	_expect(runtime.configure_rates({"play": 30, "scripted": 0}), "Resume sampled play owner")
	var observed: Dictionary = runtime.actor_snapshot()
	var action: Dictionary = _actor_action(observed, 1)
	_expect(runtime.submit_actor_action(action).accepted, "Existing observation-relative leased actor mailbox accepts policy")
	_expect(not runtime.submit_actor_action(action).accepted, "Existing actor sequence cannot replay")
	var forged: Dictionary = _actor_action(observed, 2)
	forged.generation -= 1
	_expect(not runtime.submit_actor_action(forged).accepted, "Old bundle generation cannot target replacement actor")
	forged = _actor_action(observed, 2)
	forged.producer = "demo"
	_expect(not runtime.submit_actor_action(forged).accepted, "Actor producer mismatch rejected")
	for _tick: int in range(10):
		_expect(runtime.step_once().ok, "Play owner advances sampled actor")
	var moved: Dictionary = runtime.actor_snapshot()
	_expect(moved.tick == 10 and moved.states[0] > 12.0, "Existing sampled skimmer actually moves against only play geometry")
	_expect(runtime.install_bundle(bundle) and runtime.actor_snapshot().states == moved.states and runtime.actor_snapshot().count == 1, "Duplicate installation neither duplicates nor resets actor")
	_expect(runtime.reset_bundle(runtime.generation(), REV).accepted, "Actor reset participates in all-plane atomic generation")
	_expect(not runtime.submit_actor_action(_actor_action(moved, 3)).accepted, "Old actor observation retired across reset even when new session epoch repeats")
	_expect(runtime.actor_snapshot().tick == 0 and runtime.actor_snapshot().states[0] == 12.0 and runtime.lifecycle_stats().registered_actors == 1, "Actor identity retained with fresh state and no duplicate owner")
	_expect(runtime.lifecycle_stats().actor_receipts.inspector.has("reset"), "Actor reset receipt records new bundle incarnation")
	completed["actors"] = true
