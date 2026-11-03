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
const MATERIAL_SLOTS: int = 132
const SCHEMA: String = "lcb-feel-probe-v1"

static func identity_digest(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()

# Complete 1024x1024 material inventory. Non-Water counts come from the copied
# material cells; Water count comes from the stored census; Empty is the exact
# remainder. The three sources must sum to the World area or the census is
# reported incomplete rather than repaired.
static func inventory(world: Variant, water: Dictionary) -> Dictionary:
	var cells: PackedByteArray = world.get_cells()
	var counts: Dictionary = {}
	var non_water_non_empty: int = 0
	if cells.size() != WORLD_SIDE * WORLD_SIDE:
		return {"complete":false, "error":"material cell copy has unexpected size %d" % cells.size()}
	for material: int in range(1, MATERIAL_SLOTS):
		if material == WATER: continue
		var count: int = cells.count(material)
		if count > 0:
			counts[str(material)] = count
			non_water_non_empty += count
	var water_cells: int = int(water.get("water_cells", -1))
	var empty: int = WORLD_SIDE * WORLD_SIDE - non_water_non_empty - water_cells
	if water_cells < 0 or empty < 0:
		return {"complete":false, "error":"inventory sources disagree", "counts":counts}
	if water_cells > 0: counts[str(WATER)] = water_cells
	counts[str(EMPTY)] = empty
	var total: int = 0
	for key: String in counts: total += int(counts[key])
	return {"complete":total == WORLD_SIDE * WORLD_SIDE, "area":WORLD_SIDE * WORLD_SIDE,
		"counts":counts, "sources":"non-Water: copied material cells; Water: stored census; Empty: exact remainder"}

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
		"scope":"Empty cells below stored Water in the same column; PF labels only when PressureFlow is enabled"}

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
