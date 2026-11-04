extends SceneTree

# LCB-FEEL #360 material-census contract (#358 independent audit P1-03).
# The v1 observer counted IDs 1..131 and folded every other byte into the Empty
# remainder, so a combined #358 source (IDs 132..137) would have been reported
# complete with wrong counts. This test consumes the published #358 observer
# fixture byte-identically, checks the census against the fixture's own expected
# values (never against a recomputation by the census), refuses reserved and
# unknown identities, keeps bound Water separate from free Water, and checks a
# live native World against geometry-derived counts. #358's native materials are
# not imported: the new-ID case is a synthetic readback through the same census.
const Probe = preload("res://scripts/liquid_feel_probe.gd")
const FIXTURE: String = "res://tests/fixtures/lcb/feel/pr358.observer-fixture.json"
# Git blob 3619d3a2 at PR #358 077f9c52 and 7383946a.
const FIXTURE_SHA256: String = "0b487ede7608d83f5a685ede60348bd2544c22397698d94d96a14b17922c1438"
const PR358_CATALOGUE_SLOTS: int = 138
const PR358_RESERVED: Array[int] = [10]
const PR358_BOUND_CARRIERS: Dictionary = {"136":"state_b", "137":"state_b"}
const SPARE_CELL: Vector2i = Vector2i(17, 1)
var assertions: int = 0
var failures: int = 0
var report: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_FEEL_CENSUS: " + message)

func run() -> void:
	var fixture: Dictionary = load_fixture()
	if not fixture.is_empty():
		check_fixture_census(fixture)
		check_fixture_adversaries(fixture)
		check_defect_reproduction(fixture)
		check_native_catalogue_against_fixture(fixture)
	check_catalogue_contract()
	check_live_world()
	print("LIQUID_FEEL_CENSUS: %d assertions; %d failures; report=%s" % [assertions, failures, JSON.stringify(report)])
	quit(1 if failures else 0)

func load_fixture() -> Dictionary:
	var digest: String = FileAccess.get_sha256(FIXTURE)
	expect(digest == FIXTURE_SHA256, "fixture bytes match the published #358 observer fixture (got %s)" % digest)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	expect(typeof(parsed) == TYPE_DICTIONARY, "fixture parses")
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	var fixture: Dictionary = parsed
	expect(str(fixture.schema) == "paired-material-observer-coordination.v1" and int(fixture.world_extent[0]) == 1024 \
		and int(fixture.world_extent[1]) == 1024 and int(fixture.mass_bits) == 8 and str(fixture.water_family) == "FreeMass" \
		and int(fixture.tick) == 0 and int(fixture.admitted_material_slots) == PR358_CATALOGUE_SLOTS,
		"fixture declares the registered 1024x1024 8-bit FreeMass tick-0 world with 138 slots")
	report.fixture = {"sha256":digest, "pr358_source":str(fixture.pr358_source), "reviewed_pr370":str(fixture.pr370_reviewed_source)}
	return fixture

# Synthetic #358 readback: the fixture's cells on an Empty 1024x1024 copy. Free
# Water follows water_experiment_observation (Water state_a plus overfill only);
# carrier state comes from an explicit per-cell readback.
func fixture_readback(fixture: Dictionary, water_visible: bool, extra: Array = []) -> Dictionary:
	var width: int = int(fixture.world_extent[0])
	var height: int = int(fixture.world_extent[1])
	var cells := PackedByteArray()
	cells.resize(width * height)
	cells.fill(0)
	var stored_water: int = 0
	var free_water: int = 0
	var carrier_states: Array = []
	for cell: Dictionary in fixture.cells:
		var material: int = int(cell.material_id)
		var byte: int = material
		if material == Probe.WATER:
			stored_water += 1
			free_water += int(cell.stored_water_quantity) + int(cell.pressure_overfill)
			if not water_visible: byte = Probe.EMPTY
		if PR358_BOUND_CARRIERS.has(str(material)):
			carrier_states.append([material, int(cell.get("state_a", 0)), int(cell.get("state_b", 0))])
		cells[int(cell.y) * width + int(cell.x)] = byte
	for material: int in extra:
		cells[SPARE_CELL.y * width + SPARE_CELL.x] = material
	return {"area":width * height, "material_cells":cells, "stored_water_cells":stored_water,
		"water_dithered":not water_visible, "carrier_states":carrier_states, "free_water":free_water}

func pr358_catalogue() -> Dictionary:
	var admitted: Array = []
	for id: int in PR358_CATALOGUE_SLOTS:
		if not PR358_RESERVED.has(id): admitted.append(id)
	return Probe.catalogue_from(admitted, "synthetic PR358 observer-fixture adapter", PR358_BOUND_CARRIERS)

func expected_counts(fixture: Dictionary) -> Dictionary:
	var expected: Dictionary = {}
	for key: String in fixture.expected.counts: expected[key] = int(fixture.expected.counts[key])
	return expected

func same_counts(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key: String in expected:
		if not actual.has(key) or typeof(actual[key]) != TYPE_INT or int(actual[key]) != int(expected[key]): return false
	return true

func check_fixture_census(fixture: Dictionary) -> void:
	var catalogue: Dictionary = pr358_catalogue()
	expect(catalogue.ok and catalogue.end == 138 and catalogue.reserved_ids == [10], "synthetic PR358 catalogue admits 0..137 except reserved 10")
	var expected: Dictionary = expected_counts(fixture)
	for water_visible: bool in [true, false]:
		var label: String = "Water %s in the copy" % ("visible" if water_visible else "dithered to Empty")
		var readback: Dictionary = fixture_readback(fixture, water_visible)
		var census: Dictionary = Probe.material_census(readback, catalogue)
		expect(bool(census.complete) and not census.has("refused"), label + ": fixture census is complete")
		expect(same_counts(census.get("counts", {}), expected),
			label + ": counts equal the fixture expectation %s (got %s)" % [JSON.stringify(expected), JSON.stringify(census.get("counts", {}))])
		expect(int(census.get("counted_cells", -1)) == int(fixture.expected.counted_cells), label + ": counted cells 1,048,576")
		expect(census.get("counts", {}).size() == expected.size(), label + ": no other valid material has a count")
		var bound: Dictionary = census.get("bound_water", {})
		expect(bool(bound.get("complete", false)) and int(bound.get("total", -1)) == int(fixture.expected.bound_water_separate_from_free_water),
			label + ": bound Water 510 reported separately")
		expect(int(bound.get("by_material", {}).get("136", {}).get("bound_quantity", -1)) == 255 \
			and int(bound.get("by_material", {}).get("137", {}).get("bound_quantity", -1)) == 255,
			label + ": Activated Binder and Binder Crust each carry 255 bound")
		expect(int(readback.free_water) == int(fixture.expected.stored_free_water),
			label + ": free Water is stored Water state_a plus overfill only (7), not 7+510")
		if water_visible: report.fixture_census = census
	var states: Array = fixture_readback(fixture, true).carrier_states
	expect(states.has([136, 180, 255]) and states.has([137, 0, 255]),
		"synthetic internal states Activated Binder 180/255 and Binder Crust 0/255 reach the census")
	# A carrier present without its state readback cannot be accounted.
	var missing: Dictionary = fixture_readback(fixture, true)
	missing.erase("carrier_states")
	var unaccounted: Dictionary = Probe.material_census(missing, catalogue)
	expect(not bool(unaccounted.complete) and str(unaccounted.get("error", "")).contains("without a state readback"),
		"bound-water carriers without a state readback are not complete")
	var partial: Dictionary = fixture_readback(fixture, true)
	partial.carrier_states = [[136, 180, 255]]
	expect(not bool(Probe.material_census(partial, catalogue).complete), "partial carrier state readback is not complete")
	var foreign: Dictionary = fixture_readback(fixture, true)
	foreign.carrier_states = [[136, 180, 255], [137, 0, 255], [2, 0, 9]]
	expect(not bool(Probe.material_census(foreign, catalogue).complete), "a non-carrier state entry is refused")

func check_fixture_adversaries(fixture: Dictionary) -> void:
	var catalogue: Dictionary = pr358_catalogue()
	var adversaries: Array = []
	for item: Dictionary in fixture.adversaries:
		var material: int = int(item.observed_material_id)
		adversaries.append(material)
		var census: Dictionary = Probe.material_census(fixture_readback(fixture, true, [material]), catalogue)
		var refusals: Array = census.get("refusals", [])
		var reason: String = "reserved identity" if str(item.expected).contains("reserved") else "unknown identity"
		expect(bool(census.get("refused", false)) and not bool(census.complete), "ID %d refuses the census" % material)
		expect(not census.has("counts"), "ID %d yields no counts, so nothing is folded into Empty" % material)
		expect(refusals.size() == 1 and int(refusals[0].material) == material and int(refusals[0].cells) == 1 \
			and str(refusals[0].reason) == reason, "ID %d refusal names one %s cell (got %s)" % [material, reason, JSON.stringify(refusals)])
	expect(adversaries == [10, 138, 255], "fixture adversaries are reserved 10 and unknown 138/255")
	# Water sources that cannot be reconciled with the copy are not complete.
	var phantom: Dictionary = fixture_readback(fixture, true)
	phantom.stored_water_cells = 0
	expect(not bool(Probe.material_census(phantom, catalogue).complete), "a visible Water byte without stored Water is not complete")
	var hidden: Dictionary = fixture_readback(fixture, true)
	hidden.stored_water_cells = 2
	expect(not bool(Probe.material_census(hidden, catalogue).complete),
		"an undithered stored copy must show every stored Water cell as Water")
	hidden.water_dithered = true
	var reconciled: Dictionary = Probe.material_census(hidden, catalogue)
	expect(bool(reconciled.complete) and int(reconciled.counts["3"]) == 2 and int(reconciled.counts["0"]) == 1048567,
		"a dithered copy reconciles a hidden stored Water cell out of the Empty bytes")
	var surplus: Dictionary = fixture_readback(fixture, true)
	var full := PackedByteArray()
	full.resize(int(surplus.area))
	full.fill(2)
	surplus.material_cells = full
	expect(not bool(Probe.material_census(surplus, catalogue).complete), "stored Water with no Water/Empty byte to occupy is not complete")
	var truncated: Dictionary = fixture_readback(fixture, true)
	truncated.material_cells = (truncated.material_cells as PackedByteArray).slice(0, 4096)
	expect(not bool(Probe.material_census(truncated, catalogue).complete), "a short material copy is not complete")

# The v1 algorithm, kept here only as the regression witness: IDs 1..131 counted,
# Empty as remainder. On the fixture it reports complete=true with Empty
# 1,048,574, which is the defect the fixture discriminates.
func check_defect_reproduction(fixture: Dictionary) -> void:
	var readback: Dictionary = fixture_readback(fixture, true)
	var legacy: Dictionary = legacy_v1(readback.material_cells, int(readback.stored_water_cells))
	expect(bool(legacy.complete) and int(legacy.counts["0"]) == 1048574 and not legacy.counts.has("132"),
		"v1 census reproduces the defect: complete=true, IDs 132..137 absorbed into Empty")
	expect(not same_counts(legacy.counts, expected_counts(fixture)), "fixture discriminates v1 from the corrected census")

func legacy_v1(cells: PackedByteArray, water_cells: int) -> Dictionary:
	var counts: Dictionary = {}
	var non_water_non_empty: int = 0
	for material: int in range(1, 132):
		if material == Probe.WATER: continue
		var count: int = cells.count(material)
		if count > 0:
			counts[str(material)] = count
			non_water_non_empty += count
	var empty: int = cells.size() - non_water_non_empty - water_cells
	if water_cells > 0: counts[str(Probe.WATER)] = water_cells
	counts[str(Probe.EMPTY)] = empty
	var total: int = 0
	for key: String in counts: total += int(counts[key])
	return {"complete":empty >= 0 and total == cells.size(), "counts":counts}

# The loaded native artifact decides admission. On current main IDs 132..137
# are unknown and the fixture refuses; on a combined #358 source they are
# admitted and the fixture counts must hold (no bound-water readback declared).
func check_native_catalogue_against_fixture(fixture: Dictionary) -> void:
	var catalogue: Dictionary = Probe.native_catalogue()
	if not bool(catalogue.get("ok", false)): return
	var native_ids: Dictionary = {}
	for id: int in catalogue.admitted: native_ids[id] = true
	var not_admitted: Array = []
	for cell: Dictionary in fixture.cells:
		if not native_ids.has(int(cell.material_id)): not_admitted.append(int(cell.material_id))
	not_admitted.sort()
	var census: Dictionary = Probe.material_census(fixture_readback(fixture, true), catalogue)
	if not_admitted.is_empty():
		expect(bool(census.complete) and same_counts(census.counts, expected_counts(fixture)),
			"combined-source native catalogue counts the fixture exactly")
	else:
		var refused: Array = []
		for item: Dictionary in census.get("refusals", []):
			refused.append(int(item.material))
			expect(str(item.reason) == "unknown identity", "ID %d beyond the native catalogue is unknown" % int(item.material))
		refused.sort()
		expect(bool(census.get("refused", false)) and not bool(census.complete) and not census.has("counts") and refused == not_admitted,
			"native catalogue refuses exactly the fixture IDs it does not admit %s (got %s)" % [str(not_admitted), str(refused)])
	report.native_fixture = {"not_admitted":not_admitted, "refused":census.get("refused", false), "complete":census.complete}

func check_catalogue_contract() -> void:
	var catalogue: Dictionary = Probe.native_catalogue()
	expect(bool(catalogue.get("ok", false)), "native catalogue probe succeeds: " + str(catalogue.get("error", "")))
	var mirror: Array[int] = []
	for id: int in CyberCellWorld.LAST_MATERIAL + 1:
		if id != 10: mirror.append(id)
	expect(catalogue.get("admitted", []) == mirror and catalogue.get("reserved_ids", []) == [10] \
		and int(catalogue.get("end", -1)) == CyberCellWorld.LAST_MATERIAL + 1 and bool(catalogue.get("mirror", {}).get("agrees", false)),
		"native admission equals the cell_world.gd mirror 0..LAST_MATERIAL without reserved 10")
	expect(Probe.native_catalogue().get("sha256", "") == catalogue.get("sha256", "x"), "native catalogue is stable within the process")
	report.native_catalogue = {"admitted_count":catalogue.get("admitted_count", -1), "end":catalogue.get("end", -1),
		"reserved_ids":catalogue.get("reserved_ids", []), "sha256":catalogue.get("sha256", "")}
	expect(not Probe.catalogue_from([0, 3, 3], "duplicate").ok, "duplicate admitted identity refuses the catalogue")
	expect(not Probe.catalogue_from([0, 2], "no Water").ok, "a catalogue without Water refuses")
	expect(not Probe.catalogue_from([0, 3, 256], "wide").ok, "a non-byte identity refuses the catalogue")
	expect(not Probe.catalogue_from([0, 3, 4], "carrier Water", {"3":"state_b"}).ok, "Water cannot be a bound-water carrier")
	expect(not Probe.catalogue_from([0, 3, 4], "carrier unknown", {"5":"state_b"}).ok, "an unadmitted carrier refuses")
	var unavailable: Dictionary = Probe.material_census({"area":4, "material_cells":PackedByteArray([0, 0, 0, 0]), "stored_water_cells":0},
		{"ok":false, "error":"test"})
	expect(bool(unavailable.get("refused", false)) and not bool(unavailable.complete), "an unavailable catalogue refuses the census")

# Live native World: counts derived from the filled geometry, not from a census.
func check_live_world() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world != null and bool(world.diagnostic_reset({"workers":1})), "diagnostic World constructs")
	if world == null: return
	world.set_simulation_window_enabled(false)
	var last: int = CyberCellWorld.LAST_MATERIAL
	expect(bool(world.diagnostic_fill_rect(Vector2i(100, 100), Vector2i(10, 10), CyberCellWorld.SAND, 0)), "fill Sand")
	expect(bool(world.diagnostic_fill_rect(Vector2i(200, 100), Vector2i(5, 4), CyberCellWorld.STONE, 0)), "fill Stone")
	expect(bool(world.diagnostic_fill_rect(Vector2i(250, 100), Vector2i(3, 3), last, 0)), "fill the highest admitted identity")
	expect(not bool(world.diagnostic_fill_rect(Vector2i(260, 100), Vector2i(1, 1), 10, 0)), "native refuses reserved 10")
	expect(not bool(world.diagnostic_fill_rect(Vector2i(260, 100), Vector2i(1, 1), last + 1, 0)), "native refuses LAST_MATERIAL+1")
	expect(bool(world.water_experiment_fill_rect(Vector2i(300, 300), Vector2i(20, 5), 40, 0)), "fill partial Water")
	expect(bool(world.water_experiment_fill_rect(Vector2i(400, 300), Vector2i(10, 10), 255, 0)), "fill full Water")
	var area: int = Probe.WORLD_SIDE * Probe.WORLD_SIDE
	var expected: Dictionary = {str(CyberCellWorld.SAND):100, str(CyberCellWorld.STONE):20, str(last):9, "3":200, "0":area - 329}
	var water: Dictionary = Probe.water(world)
	expect(int(water.water_cells) == 200, "stored Water census counts 200 cells (got %d)" % int(water.water_cells))
	var cells: PackedByteArray = world.get_cells()
	expect(cells.count(Probe.WATER) < 200, "partial Water is dithered in the cached get_cells copy")
	var started: int = Time.get_ticks_usec()
	var inventory: Dictionary = Probe.inventory(world, water)
	var census_us: int = Time.get_ticks_usec() - started
	expect(bool(inventory.complete) and same_counts(inventory.counts, expected),
		"live census equals the geometry %s (got %s)" % [JSON.stringify(expected), JSON.stringify(inventory.get("counts", {}))])
	var source: Dictionary = inventory.get("material_source", {})
	expect(str(source.get("kind", "")) == "stored" and bool(source.get("uncached", false)) and int(source.get("tiles", 0)) == 4 \
		and bool(source.get("native_histogram_agrees", false)) and bool(source.get("water_state_a_agrees", false)),
		"live census reads uncached stored materials in four tiles and agrees with the native histogram and Water state_a")
	var stored: Dictionary = Probe.stored_material_readback(world)
	expect(bool(stored.ok) and (stored.cells as PackedByteArray).count(Probe.WATER) == 200,
		"stored readback shows every stored Water cell (no presentation dither)")
	expect(bool(inventory.bound_water.complete) and not bool(inventory.bound_water.declared), "native catalogue declares no bound-water carriers")
	var legacy: Dictionary = legacy_v1(cells, int(water.water_cells))
	expect(same_counts(legacy.counts, inventory.counts) and bool(legacy.complete),
		"admitted-only World: corrected census equals the v1 result (original preflight behaviour retained)")
	var census: Dictionary = Probe.census(world, Rect2i(0, 0, 1, 1))
	expect(str(census.schema) == "lcb-feel-probe-v2" and bool(census.inventory.complete), "full census reports schema v2 and a complete inventory")
	report.live = {"census_us":census_us, "cached_copy_water_bytes":cells.count(Probe.WATER), "counts":inventory.counts}
	check_enclosed_voids(world)
	# A World without the diagnostic fixture has no uncached stored readback;
	# the cached render copy is not accepted as a complete inventory.
	var ordinary: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var refused: Dictionary = Probe.inventory(ordinary, {"water_cells":0, "visible":0})
	expect(not bool(refused.complete) and str(refused.material_source.kind) == "unavailable",
		"non-diagnostic World inventory is incomplete rather than read from the cached copy")

# A 12-cell pocket inside a Water block and a 4-cell dry pocket inside Stone are
# cavities; the air column under a one-row Water film reaches the region edge
# and is not, although the column definition counts it as submerged.
func check_enclosed_voids(world: Variant) -> void:
	var origin := Vector2i(500, 500)
	expect(bool(world.water_experiment_fill_rect(origin + Vector2i(10, 10), Vector2i(20, 20), 255, 0)), "fill Water block")
	expect(bool(world.water_experiment_erase_rect(origin + Vector2i(18, 18), Vector2i(4, 3))), "erase Water pocket")
	expect(bool(world.diagnostic_fill_rect(origin + Vector2i(32, 2), Vector2i(6, 6), CyberCellWorld.STONE, 0)), "fill Stone block")
	expect(bool(world.water_experiment_erase_rect(origin + Vector2i(34, 4), Vector2i(2, 2))), "erase dry pocket")
	expect(bool(world.water_experiment_fill_rect(origin + Vector2i(2, 30), Vector2i(8, 1), 255, 0)), "fill Water film")
	var voids: Dictionary = Probe.voids(world, Rect2i(origin, Vector2i(40, 40)))
	var enclosed: Dictionary = voids.enclosed
	expect(int(enclosed.components) == 2 and int(enclosed.cells) == 16 and int(enclosed.largest_component) == 12 \
		and int(enclosed.water_bounded_components) == 1 and int(enclosed.water_bounded_cells) == 12,
		"enclosed cavities are the Water pocket (12, Water-bounded) and the dry Stone pocket (4) (got %s)" % JSON.stringify(enclosed))
	expect(int(voids.submerged_empty_cells) > int(enclosed.cells), "column definition also counts the open air under the film")
	report.voids = {"submerged_empty_cells":voids.submerged_empty_cells, "enclosed":enclosed}
