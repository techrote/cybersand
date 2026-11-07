extends RefCounted

# LCB-FEEL #360 exclusive-owner observation helpers. Call only from the owner
# of the supplied World (headless harness or the desktop simulation owner).
# Every value is copied; nothing wakes cells, consumes dirty state or enters a
# native pool worker. Authoritative Water quantity uses stored state_a plus
# PressureFlow overfill; the render cell copy is used only for non-Water
# materials because it dithers fractional Water for presentation.
const WORLD_SIDE: int = 1024
const WATER: int = 3
const BRINE: int = 24
const EMPTY: int = 0
# v2: the material census no longer assumes a catalogue size (v1 counted IDs
# 1..131 and folded any other byte into the Empty remainder).
const SCHEMA: String = "lcb-feel-probe-v2"
const CATALOGUE_SCHEMA: String = "lcb-feel-material-catalogue-v1"
const CENSUS_SCHEMA: String = "lcb-feel-material-census-v1"
# Native material identities are byte-sized (material.hpp static_assert), so the
# copied material cells can only hold 0..255. The census histograms that whole
# domain; admission is a separate question answered by the catalogue.
const BYTE_DOMAIN: int = 256
static var _native_catalogue: Dictionary = {}

static func identity_digest(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()

# Admitted material catalogue. `admitted` lists every identity a readback may
# legitimately contain (Empty and Water included). Identities below the highest
# admitted one that are not admitted are reserved; identities above it are
# unknown. `bound_water_carriers` maps str(material) -> "state_b" for materials
# whose state_b holds Water bound outside the free-Water ledger; it is a
# capability the readback must then supply, never inferred from the ID range.
static func catalogue_from(admitted: Array, authority: String, bound_water_carriers: Dictionary = {}) -> Dictionary:
	var ids: Array[int] = []
	for value: Variant in admitted:
		if typeof(value) != TYPE_INT or int(value) < 0 or int(value) >= BYTE_DOMAIN or ids.has(int(value)):
			return {"ok":false, "schema":CATALOGUE_SCHEMA, "authority":authority,
				"error":"admitted identity %s is not a unique byte" % str(value)}
		ids.append(int(value))
	ids.sort()
	if not ids.has(EMPTY) or not ids.has(WATER):
		return {"ok":false, "schema":CATALOGUE_SCHEMA, "authority":authority,
			"error":"catalogue must admit Empty and Water"}
	var carriers: Dictionary = {}
	for key: Variant in bound_water_carriers:
		var id: int = int(str(key)) if str(key).is_valid_int() else -1
		if not ids.has(id) or id == EMPTY or id == WATER or str(bound_water_carriers[key]) != "state_b":
			return {"ok":false, "schema":CATALOGUE_SCHEMA, "authority":authority,
				"error":"bound-water carrier %s is not an admitted non-Water state_b material" % str(key)}
		carriers[str(id)] = "state_b"
	var end: int = ids.back() + 1
	var reserved: Array[int] = []
	for id: int in end:
		if not ids.has(id): reserved.append(id)
	var keys: Array = carriers.keys()
	keys.sort()
	var digest: String = identity_digest(JSON.stringify({"admitted":ids, "bound_water_carriers":keys}))
	return {"ok":true, "schema":CATALOGUE_SCHEMA, "authority":authority, "admitted":ids,
		"admitted_count":ids.size(), "end":end, "reserved_ids":reserved,
		"bound_water_carriers":carriers, "sha256":digest}

# The admitted catalogue of the loaded native artifact. Each byte identity is
# offered once to a private 1x1 diagnostic fill on a scratch World that is never
# ticked; the native fill accepts exactly kLastMaterial-bounded valid_material
# identities. The cell_world.gd mirror (LAST_MATERIAL, reserved 10) must agree,
# otherwise every census refuses instead of trusting either side. Cached per
# process; the scratch World never sees an observed World.
static func native_catalogue() -> Dictionary:
	if not _native_catalogue.is_empty(): return _native_catalogue.duplicate(true)
	var scratch: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if scratch == null or not bool(scratch.diagnostic_reset({"workers":1})):
		return {"ok":false, "schema":CATALOGUE_SCHEMA, "error":"native admission probe World unavailable"}
	var admitted: Array = []
	for id: int in BYTE_DOMAIN:
		if bool(scratch.diagnostic_fill_rect(Vector2i.ZERO, Vector2i.ONE, id, 0)): admitted.append(id)
	scratch = null
	var result: Dictionary = catalogue_from(admitted, "native diagnostic_fill_rect admission (valid_material, kLastMaterial)")
	var mirror: Array[int] = []
	for id: int in CyberCellWorld.LAST_MATERIAL + 1:
		if id != 10: mirror.append(id)
	result["mirror"] = {"source":"cell_world.gd", "last_material":CyberCellWorld.LAST_MATERIAL, "reserved_ids":[10],
		"agrees":result.get("ok", false) and result.admitted == mirror}
	if result.get("ok", false) and not result.mirror.agrees:
		result.ok = false
		result.error = "native admitted catalogue disagrees with the cell_world.gd mirror"
	_native_catalogue = result
	return result.duplicate(true)

static func _catalogue_summary(catalogue: Dictionary) -> Dictionary:
	var summary: Dictionary = {}
	for key: String in ["schema", "authority", "admitted_count", "end", "reserved_ids", "bound_water_carriers", "sha256", "mirror"]:
		if catalogue.has(key): summary[key] = catalogue[key]
	return summary

# Complete material inventory from one copied readback, checked against an
# admitted catalogue. Readback fields:
#   area                  cell count the copy must cover exactly
#   material_cells        copied material bytes; Water may be dithered to Empty
#                         (native copy_material_cells), nothing else is altered
#   stored_water_cells    authoritative stored Water cell count
#   carrier_states        optional [[material, state_a, state_b], ...] for every
#                         bound-water carrier cell, required when one is present
# Every observed byte is histogrammed. Any reserved or unknown identity refuses
# the census (no counts, never folded into Empty). True Empty is derived only
# after all non-Empty identities are validated and the stored Water count is
# reconciled with the Water/Empty bytes of the copy.
static func material_census(readback: Dictionary, catalogue: Dictionary) -> Dictionary:
	var area: int = int(readback.get("area", -1))
	var result: Dictionary = {"schema":CENSUS_SCHEMA, "complete":false, "area":area,
		"catalogue":_catalogue_summary(catalogue),
		"sources":"identities: full byte-domain histogram of copied material cells checked against the admitted catalogue; Water: stored census; Empty: copy Empty+Water minus stored Water"}
	if not bool(catalogue.get("ok", false)):
		result.refused = true
		result.error = "catalogue unavailable: " + str(catalogue.get("error", "not ok"))
		return result
	var cells: PackedByteArray = readback.get("material_cells", PackedByteArray())
	if area <= 0 or cells.size() != area:
		result.error = "material cell copy has unexpected size %d" % cells.size()
		return result
	var observed: Dictionary = {}
	var covered: int = 0
	for id: int in BYTE_DOMAIN:
		var count: int = cells.count(id)
		if count == 0: continue
		observed[id] = count
		covered += count
		if covered == area: break
	if covered != area:
		result.error = "byte histogram covers %d of %d cells" % [covered, area]
		return result
	var admitted: Dictionary = {}
	for id: int in catalogue.admitted: admitted[id] = true
	var refusals: Array = []
	for id: int in observed:
		if admitted.has(id): continue
		refusals.append({"material":id, "cells":int(observed[id]),
			"reason":"reserved identity" if id < int(catalogue.end) else "unknown identity"})
	if not refusals.is_empty():
		result.refused = true
		result.refusals = refusals
		result.error = "readback contains %d reserved/unknown identities" % refusals.size()
		return result
	var stored_water: int = int(readback.get("stored_water_cells", -1))
	var copy_water: int = int(observed.get(WATER, 0))
	var copy_empty: int = int(observed.get(EMPTY, 0))
	var dithered: bool = bool(readback.get("water_dithered", false))
	result.water_reconciliation = "dithered copy: stored Water within copy Water..Water+Empty" if dithered \
		else "stored copy: Water bytes equal stored Water exactly"
	if stored_water < copy_water or stored_water > copy_water + copy_empty or (not dithered and stored_water != copy_water):
		result.error = "inventory sources disagree: stored Water %d, copy Water %d, copy Empty %d" % [stored_water, copy_water, copy_empty]
		return result
	var counts: Dictionary = {}
	var ids: Array = observed.keys()
	ids.sort()
	for id: int in ids:
		if id != EMPTY and id != WATER: counts[str(id)] = int(observed[id])
	if stored_water > 0: counts[str(WATER)] = stored_water
	counts[str(EMPTY)] = copy_empty + copy_water - stored_water
	var total: int = 0
	for key: String in counts: total += int(counts[key])
	result.counts = counts
	result.counted_cells = total
	var bound: Dictionary = _bound_water(readback, catalogue, counts)
	result.bound_water = bound
	result.complete = total == area and bool(bound.complete)
	if not bool(bound.complete): result.error = str(bound.error)
	return result

# Bound Water stays separate from free Water. Only declared carriers count, and
# only from an explicit per-cell state readback covering every carrier cell.
static func _bound_water(readback: Dictionary, catalogue: Dictionary, counts: Dictionary) -> Dictionary:
	var carriers: Dictionary = catalogue.get("bound_water_carriers", {})
	if carriers.is_empty():
		return {"complete":true, "declared":false, "scope":"catalogue declares no bound-water carriers"}
	var present: int = 0
	for key: String in carriers: present += int(counts.get(key, 0))
	var by_material: Dictionary = {}
	for key: String in carriers:
		if counts.has(key): by_material[key] = {"cells":0, "bound_quantity":0}
	if present == 0:
		return {"complete":true, "declared":true, "total":0, "by_material":by_material}
	if not readback.has("carrier_states"):
		return {"complete":false, "declared":true, "error":"%d bound-water carrier cells present without a state readback" % present}
	var seen: int = 0
	var total: int = 0
	for entry: Variant in readback.carrier_states:
		var valid: bool = typeof(entry) == TYPE_ARRAY and (entry as Array).size() == 3
		var key: String = str(int(entry[0])) if valid else ""
		if not valid or not by_material.has(key) or int(entry[2]) < 0 or int(entry[2]) > 255:
			return {"complete":false, "declared":true, "error":"carrier state readback entry %s is not an observed declared carrier" % str(entry)}
		var slot: Dictionary = by_material[key]
		slot["cells"] = int(slot["cells"]) + 1
		slot["bound_quantity"] = int(slot["bound_quantity"]) + int(entry[2])
		seen += 1
		total += int(entry[2])
	for key: String in by_material:
		if int(by_material[key]["cells"]) != int(counts.get(key, 0)):
			return {"complete":false, "declared":true, "error":"carrier %s state readback covers %d of %d cells" % [key, int(by_material[key]["cells"]), int(counts.get(key, 0))]}
	return {"complete":seen == present, "declared":true, "total":total, "by_material":by_material,
		"scope":"sum of carrier state_b; never part of free Water"}

# Uncached stored-material bytes. get_cells() is a render cache refreshed only
# when the adapter revision changes (simulation_tick bumps it only for moved
# cells or deferred events) and it dithers fractional Water. diagnostic_snapshot
# reads World::stored_material directly, consumes no dirty state, and is bounded
# to 512x768 per call, so the World is read as four 512x512 tiles in one owner
# turn. Tile order is irrelevant to a histogram. Diagnostic-fixture Worlds only.
const SNAPSHOT_TILE: int = 512
static func stored_material_readback(world: Variant) -> Dictionary:
	var bytes := PackedByteArray()
	var native_counts: Array[int] = []
	var water_state_a: int = 0
	var completed: Array[int] = []
	for tile_y: int in range(0, WORLD_SIDE, SNAPSHOT_TILE):
		for tile_x: int in range(0, WORLD_SIDE, SNAPSHOT_TILE):
			var snapshot: Dictionary = world.diagnostic_snapshot(Vector2i(tile_x, tile_y), Vector2i(SNAPSHOT_TILE, SNAPSHOT_TILE), false)
			if not snapshot.has("cells") or bool(snapshot.get("failed", true)):
				return {"ok":false, "error":"diagnostic_snapshot unavailable (non-diagnostic or failed World)"}
			bytes.append_array(snapshot.cells)
			water_state_a += int(snapshot.water_mass)
			completed.append(int(snapshot.completed_ticks))
			var counts: Array = snapshot.counts
			if native_counts.is_empty(): native_counts.resize(counts.size())
			for id: int in counts.size(): native_counts[id] += int(counts[id])
	if completed.min() != completed.max():
		return {"ok":false, "error":"tiles observed different completed ticks %s" % str(completed)}
	return {"ok":true, "cells":bytes, "native_counts":native_counts, "water_state_a":water_state_a,
		"completed_tick":completed[0], "tiles":completed.size()}

# Complete 1024x1024 material inventory of a live World against the loaded
# native catalogue (v1-compatible fields: complete, area, counts). The census is
# cross-checked against the native per-tile histogram and the stored Water
# state_a sum of the same observation; any disagreement leaves it incomplete.
static func inventory(world: Variant, water: Dictionary) -> Dictionary:
	var area: int = WORLD_SIDE * WORLD_SIDE
	var stored: Dictionary = stored_material_readback(world)
	if not bool(stored.ok):
		return {"schema":CENSUS_SCHEMA, "complete":false, "area":area, "error":str(stored.error),
			"material_source":{"kind":"unavailable", "uncached":false}}
	var census: Dictionary = material_census({"area":area, "material_cells":stored.cells,
		"stored_water_cells":int(water.get("water_cells", -1)), "water_dithered":false}, native_catalogue())
	var histogram_agrees: bool = true
	var native_counts: Array[int] = stored.native_counts
	for id: int in native_counts.size():
		var counted: int = int(census.get("counts", {}).get(str(id), 0))
		if bool(census.complete) and counted != native_counts[id]: histogram_agrees = false
	var water_agrees: bool = int(stored.water_state_a) == int(water.get("visible", -2))
	census.material_source = {"kind":"stored", "api":"diagnostic_snapshot", "tiles":int(stored.tiles), "uncached":true,
		"completed_tick":int(stored.completed_tick), "native_histogram_agrees":histogram_agrees,
		"water_state_a_agrees":water_agrees}
	if bool(census.complete) and not (histogram_agrees and water_agrees):
		census.complete = false
		census.error = "stored-material cross-check failed (native histogram %s, Water state_a %s)" % [histogram_agrees, water_agrees]
	return census

static func water(world: Variant) -> Dictionary:
	var observed: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE))
	return {"visible":int(observed.get("water_visible", -1)), "overfill":int(observed.get("water_overfill", -1)),
		"quantity":int(observed.get("water_integer", -1)), "water_cells":int(observed.get("water_cells", -1)),
		"content_hash":str(observed.get("content_hash", "")), "state_hash":str(observed.get("state_hash", "")),
		"scope":"complete World stored Water state_a plus pressure overfill"}

static func health(world: Variant) -> Dictionary:
	return {"failed":bool(world.has_failed()), "tick_failure_count":int(world.get_tick_failure_count()),
		"last_tick_error":str(world.get_last_tick_error()), "attempted_tick":int(world.get_attempted_tick_index()),
		"tick_index":int(world.get_tick_index())}

# Retained-motion census over a bounded region. Complete only when every
# stored Water cell of the World was inside the scanned region. The digest is
# over ordered (x, y, material, vx, vy, ax, ay) tuples of inertial cells.
static func inertial(world: Variant, region: Rect2i, water_cells_total: int) -> Dictionary:
	var probe: Dictionary = world.inspect_inertial_cell(Vector2i(region.position))
	if not probe.get("ok", false) or not probe.get("available", false): return {"available":false}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var scanned_water: int = 0
	var inertial_cells: int = 0
	var moving: int = 0
	var nonzero_accumulator: int = 0
	var sum_abs_vx: int = 0
	var sum_vy: int = 0
	var max_abs_vx: int = 0
	var max_vy: int = 0
	var negative_vy: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var material: int = int(world.material_at(x, y))
			if material != WATER and material != BRINE: continue
			if material == WATER: scanned_water += 1
			var cell: Dictionary = world.inspect_inertial_cell(Vector2i(x, y))
			if not cell.get("inertial_family", false): continue
			inertial_cells += 1
			var vx: int = int(cell.vx)
			var vy: int = int(cell.vy)
			var ax: int = int(cell.ax)
			var ay: int = int(cell.ay)
			if vx != 0 or vy != 0: moving += 1
			if ax != 0 or ay != 0: nonzero_accumulator += 1
			if vy < 0: negative_vy += 1
			sum_abs_vx += absi(vx)
			sum_vy += vy
			max_abs_vx = maxi(max_abs_vx, absi(vx))
			max_vy = maxi(max_vy, vy)
			context.update(("%d,%d,%d,%d,%d,%d,%d;" % [x, y, material, vx, vy, ax, ay]).to_utf8_buffer())
	return {"available":true, "region":[region.position.x, region.position.y, region.size.x, region.size.y],
		"water_cells_scanned":scanned_water, "complete":scanned_water == water_cells_total,
		"inertial_cells":inertial_cells, "moving_cells":moving, "nonzero_accumulator_cells":nonzero_accumulator,
		"sum_abs_vx":sum_abs_vx, "sum_vy":sum_vy, "max_abs_vx":max_abs_vx, "max_vy":max_vy,
		"negative_vy_cells":negative_vy, "tuple_sha256":context.finish().hex_encode(),
		"units":"16 quanta per cell; vx -32..32, vy 0..32"}

static func pressure(world: Variant) -> Dictionary:
	var ledger: Dictionary = world.get_pressure_flow_ledger()
	if not ledger.get("available", false): return {"available":false}
	var gas: Dictionary = world.inspect_gas_compartments()
	var book: Dictionary = gas.get("ledger", {})
	return {"available":true, "ledger":ledger.duplicate(true), "gas_enabled":gas.get("gas_enabled", null),
		"atmospheric_head_rows":gas.get("atmospheric_head_rows", null),
		"topology_revision":gas.get("topology_revision", null),
		"compartments":(gas.get("compartments", []) as Array).size(),
		"history":(gas.get("history", []) as Array).size(), "gas_ledger":book.duplicate(true),
		"gas_ledger_closes":bool(book.get("closes", false))}

# Apparent-bubble classification inside a region. An Empty cell with stored
# Water above it in the same column is "submerged". Under PressureFlow each
# submerged Empty cell is further classified by its native gas label; other
# families have no gas state, so their submerged Empty cells are plain voids.
static func voids(world: Variant, region: Rect2i) -> Dictionary:
	var pressure_enabled: bool = bool(world.get_pressure_flow_ledger().get("available", false))
	var water_cells: int = 0
	var submerged: int = 0
	var labels: Dictionary = {}
	var deepest: int = -1
	for x: int in range(region.position.x, region.end.x):
		var seen_water: bool = false
		for y: int in range(region.position.y, region.end.y):
			var material: int = int(world.material_at(x, y))
			if material == WATER:
				water_cells += 1
				seen_water = true
			elif material == EMPTY and seen_water:
				submerged += 1
				deepest = maxi(deepest, y)
				if pressure_enabled:
					var label: String = str(world.inspect_pressure_cell(Vector2i(x, y)).get("gas", "unavailable"))
					labels[label] = int(labels.get(label, 0)) + 1
	return {"completed_tick":int(world.get_tick_index()),
		"region":[region.position.x, region.position.y, region.size.x, region.size.y], "water_cells":water_cells,
		"submerged_empty_cells":submerged, "deepest_submerged_row":deepest,
		"pressure_gas_labels":labels if pressure_enabled else null,
		"enclosed":enclosed_voids(world, region),
		"scope":"Empty cells below stored Water in the same column; PF labels only when PressureFlow is enabled"}

# Connected-region cavity definition (additive to the column definition above,
# which marks every Empty cell under any Water film or droplet). A cavity is a
# 4-connected Empty component inside the region that touches no region edge;
# it is Water-bounded when at least one 4-neighbour of the component is Water.
# Apparent geometry only: no gas, pressure or bubble-dynamics claim.
static func enclosed_voids(world: Variant, region: Rect2i) -> Dictionary:
	var width: int = region.size.x
	var height: int = region.size.y
	var grid := PackedByteArray()
	grid.resize(width * height)
	for y: int in height:
		for x: int in width:
			grid[y * width + x] = int(world.material_at(region.position.x + x, region.position.y + y))
	var seen := PackedByteArray()
	seen.resize(width * height)
	seen.fill(0)
	var components: int = 0
	var cells: int = 0
	var largest: int = 0
	var water_bounded_components: int = 0
	var water_bounded_cells: int = 0
	var stack := PackedInt32Array()
	for start: int in width * height:
		if seen[start] != 0 or grid[start] != EMPTY: continue
		seen[start] = 1
		stack.clear()
		stack.append(start)
		var size: int = 0
		var touches_edge: bool = false
		var touches_water: bool = false
		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			var x: int = index % width
			var y: int = index / width
			if x == 0 or y == 0 or x == width - 1 or y == height - 1: touches_edge = true
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height: continue
				var neighbour: int = ny * width + nx
				if grid[neighbour] == WATER: touches_water = true
				if grid[neighbour] == EMPTY and seen[neighbour] == 0:
					seen[neighbour] = 1
					stack.append(neighbour)
		if touches_edge: continue
		components += 1
		cells += size
		largest = maxi(largest, size)
		if touches_water:
			water_bounded_components += 1
			water_bounded_cells += size
	return {"definition":"4-connected Empty components touching no region edge", "components":components,
		"cells":cells, "largest_component":largest, "water_bounded_components":water_bounded_components,
		"water_bounded_cells":water_bounded_cells}

static func census(world: Variant, region: Rect2i) -> Dictionary:
	var water_value: Dictionary = water(world)
	return {"schema":SCHEMA, "completed_tick":int(world.get_tick_index()), "health":health(world),
		"water":water_value, "inventory":inventory(world, water_value),
		"physical_state_hash":str(world.get_physical_state_hash()),
		"physical_state_hash_version":int(world.get_physical_state_hash_version()),
		"physical_state_format_version":int(world.get_physical_state_format_version()),
		"inertial":inertial(world, region, int(water_value.water_cells)),
		"pressure":pressure(world)}

# One completed native tick. Timing is the native World::tick() duration only.
static func tick_sample(world: Variant, bridge: Variant, wall_us: int, with_hash: bool = true) -> Dictionary:
	var statistics: Dictionary = bridge.inspect_statistics(world)
	var values: Dictionary = statistics.get("values", {})
	var observed: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE))
	return {"tick":int(world.get_tick_index()), "native_tick_ms":float(world.get_simulation_time_ms()),
		"host_advance_us":wall_us, "statistics_ok":bool(statistics.get("ok", false)),
		"worker_threads_observed":int(values.get("worker_threads_observed", -1)),
		"phase_jobs":Array(statistics.get("phase_jobs_last_tick", [])),
		"scheduler_jobs":int(world.get_scheduler_jobs_last_tick()),
		"scheduler_parallel_phases":int(world.get_scheduler_parallel_phases_last_tick()),
		"moved_cells":int(values.get("moved_cells", -1)), "visited_cells":int(values.get("visited_cells", -1)),
		"active_chunks":int(values.get("active_chunks", -1)), "resident_chunks":int(values.get("resident_chunks", -1)),
		"chunk_allocations":int(values.get("chunk_allocations", -1)),
		"temperature_field_allocations":int(values.get("temperature_field_allocations", -1)),
		"water_quantity":int(observed.get("water_integer", -1)),
		"water_overfill":int(observed.get("water_overfill", -1)),
		"physical_state_hash":str(world.get_physical_state_hash()) if with_hash else "",
		"failed":bool(world.has_failed())}
