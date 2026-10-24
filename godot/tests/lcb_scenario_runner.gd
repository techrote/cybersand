extends RefCounted

# Shared LCB controlled-run helper for run_lcb_scenario_suite.gd and the LCB
# regressions. Native-only and fixed-tick: no player, Rapier body or render.
# Every result carries an explicit status; only "completed" is a physics run.
#   refused          - definition or setup rejected before any tick
#   faulted          - host/native fault after installation
#   failed_condition - a preregistered fail condition fired
#   completed        - every requested tick ran without fault
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const CHECKPOINTS: Array[int] = [0, 30, 120, 600, 1200, 1800, 2400, 3600]
const STAT_KEYS: Array[String] = ["active_blocks_after", "active_chunks", "scheduled_cores",
	"visited_cells", "moved_cells", "resident_chunks", "deferred_events_processed",
	"chunk_allocations", "temperature_field_allocations"]

static func read_text(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false, "error":"definition unavailable: " + path}
	if file.get_length() > Contract.MAX_JSON_BYTES: return {"ok":false, "error":"definition exceeds byte budget"}
	return {"ok":true, "text":file.get_as_text()}

static func horizon_of(definition: Dictionary) -> int:
	var horizon: int = int(definition.get("presentation", {}).get("duration_ticks", 0))
	for observation: Dictionary in definition.observations: horizon = maxi(horizon, int(observation.tick))
	return horizon

# ticks < 0 runs the definition's own horizon.
static func run_text(text: String, workers: int, ticks: int = -1, source_sha: String = "unavailable") -> Dictionary:
	var checked: Dictionary = Contract.parse(text)
	if not checked.get("ok", false):
		return {"status":"refused", "error":str(checked.get("error", "rejected"))}
	var definition: Dictionary = checked.definition
	if definition.player_enabled or definition.body_enabled:
		return {"status":"refused", "id":definition.id, "error":"native-only runner refuses player/body definitions"}
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		return {"status":"refused", "id":definition.id, "error":"current native extension unavailable"}
	var horizon: int = horizon_of(definition) if ticks < 0 else ticks
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not world.diagnostic_reset({"workers":workers}):
		return {"status":"refused", "id":definition.id, "error":"native worker configuration rejected"}
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world, definition, "Benchmark", true):
		return {"status":"refused", "id":definition.id, "error":host.last_error}
	var checkpoints: Array = [checkpoint(world, bridge)]
	var maxima: Dictionary = {}
	var moved_total: int = 0
	var last_active_tick: int = 0
	var status: String = "completed"
	var error: String = ""
	for tick: int in range(1, horizon + 1):
		if not host.advance():
			status = "faulted"
			error = host.last_error
			break
		var values: Dictionary = bridge.inspect_statistics(world)["values"]
		for key: String in STAT_KEYS: maxima[key] = maxi(int(maxima.get(key, 0)), int(values.get(key, 0)))
		moved_total += int(values.get("moved_cells", 0))
		if int(values.get("active_chunks", 0)) > 0: last_active_tick = tick
		if tick in CHECKPOINTS or tick == horizon: checkpoints.append(checkpoint(world, bridge))
	var capture: Dictionary = host.capture(CyberMicroScenarioIdentity.current(source_sha))
	if status == "completed" and bool(capture.get("failed", false)):
		status = "faulted"
		error = str(capture.get("error", "host fault"))
	elif status == "completed" and str(capture.get("outcome", "")) == "fail":
		status = "failed_condition"
	return {"status":status, "error":error, "id":definition.id, "definition_hash":checked.hash,
		"workers":workers, "horizon":horizon, "checkpoints":checkpoints,
		"work":{"maxima":maxima, "moved_cells_total":moved_total, "last_active_tick":last_active_tick},
		"capture":capture}

# Install without ticking, for tick-0 inventory inspection by regressions.
static func install(text: String, workers: int) -> Dictionary:
	var checked: Dictionary = Contract.parse(text)
	if not checked.get("ok", false): return {"ok":false, "error":str(checked.get("error", "rejected"))}
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers":workers}): return {"ok":false, "error":"native worker configuration rejected"}
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world, checked.definition, "Benchmark", true): return {"ok":false, "error":host.last_error}
	return {"ok":true, "world":world, "host":host, "hash":checked.hash, "definition":checked.definition}

static func checkpoint(world: Variant, bridge: Variant) -> Dictionary:
	var observation: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024))
	var stats: Dictionary = bridge.inspect_statistics(world)
	return {"tick":int(observation.tick), "content_hash":observation.content_hash,
		"state_hash":observation.state_hash, "water_integer":int(observation.water_integer),
		"water_cells":int(observation.water_cells),
		"active_chunks":int(stats["values"].get("active_chunks", 0)),
		"resident_chunks":int(stats["values"].get("resident_chunks", 0))}

# Whole-cell counts inside a region, used for independent inventory checks.
static func material_counts(world: Variant, region: Array) -> Dictionary:
	var counts: Dictionary = {}
	for y: int in range(int(region[1]), int(region[1]) + int(region[3])):
		for x: int in range(int(region[0]), int(region[0]) + int(region[2])):
			var material: int = int(world.material_at(x, y))
			if material > 1: counts[material] = int(counts.get(material, 0)) + 1
	return counts
