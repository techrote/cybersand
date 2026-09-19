class_name CyberMicroScenarioContract
extends RefCounted

# Pure, JSON-round-trippable setup data. Validation completes before native
# replacement. No callbacks, scripts, live nodes or arbitrary per-tick writes.
const VERSION: int = 2
const SIDE: int = 1024
const MATERIAL_COUNT: int = 81
const MAX_RECORDS: int = 4096
const MAX_EVENTS: int = 24
const MAX_OBSERVATIONS: int = 24
const MAX_TICK: int = 3600
const MAX_JSON_BYTES: int = 1_048_576
const MODES: Array[String] = ["Play", "Inspect", "Benchmark"]
const ROOT_KEYS: Array[String] = ["schema_version", "id", "recipe_version", "seed",
	"maturity", "rectangles", "partial_water_fills", "transport_profile",
	"water_semantics", "player_start", "camera_origin", "player_enabled",
	"body_enabled", "tools", "interest", "execution", "events", "observations", "conditions",
	"source_recipe", "source_recipe_hash"]
const EVENT_KEYS: Array[String] = ["tick", "kind", "x", "y", "width", "height",
	"material", "normalized_mass", "coherence"]
const OBSERVATION_KEYS: Array[String] = ["id", "tick", "metric", "region", "material"]
const CONDITION_KEYS: Array[String] = ["observation", "comparison", "value", "outcome"]

static func base(scenario_id: String, recipe_version: int = 1, seed: int = 0) -> Dictionary:
	return {"schema_version":1, "id":scenario_id, "recipe_version":recipe_version,
		"seed":seed, "maturity":"exploratory", "rectangles":[], "partial_water_fills":[],
		"transport_profile":CyberTransportProfiles.preset(0), "water_semantics":[1,8,12,0],
		"player_start":[24,222], "camera_origin":[0,0], "player_enabled":false,
		"body_enabled":false, "tools":[], "interest":{"policy":"owner", "region":[0,0,SIDE,SIDE]},
		"execution":{"policy":"owner", "cadence_lod_enabled":true, "liquid_surface_adhesion_enabled":true},
		"events":[], "observations":[], "conditions":[], "source_recipe":"",
		"source_recipe_hash":""}

static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		return _error("Definition exceeds JSON byte budget")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _error("Invalid JSON: " + parser.get_error_message())
	return validate(parser.data)

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or not _integer(value.get("schema_version"), 1, VERSION):
		return _error("Unsupported scenario schema")
	var version: int = int(value.schema_version)
	var keys: Array = ROOT_KEYS.duplicate()
	if version == 2: keys.append("presentation")
	if not _keys(value, keys):
		return _error("Missing or unknown scenario field")
	var presentation: Variant = _presentation(value.presentation) if version == 2 else {}
	if presentation == null: return _error("Invalid presentation or presentation capacity exceeded")
	if not _identifier(value.id) or not _integer(value.recipe_version, 1, 0x7FFFFFFF):
		return _error("Invalid scenario identity")
	if not _integer(value.seed, 0, 0x7FFFFFFF):
		return _error("Invalid deterministic seed")
	if not value.maturity in ["exploratory", "reference"]:
		return _error("Invalid scenario maturity")
	for key: String in ["source_recipe", "source_recipe_hash"]:
		if not value[key] is String or str(value[key]).length() > 256:
			return _error("Invalid source recipe identity")
	if not value.source_recipe_hash.is_empty() and not _hex_digest(value.source_recipe_hash):
		return _error("Invalid source recipe digest")
	for key: String in ["player_enabled", "body_enabled"]:
		if not value[key] is bool: return _error("Expected boolean: " + key)
	for key: String in ["player_start", "camera_origin"]:
		if not _integers(value[key], 2, 0, SIDE - 1):
			return _error("Invalid position: " + key)
	if not value.tools is Array or value.tools.size() > 3:
		return _error("Invalid tool list")
	var tools: Array = []
	for tool: Variant in value.tools:
		if not tool is String or not tool in ["paint", "erase", "player"] or tool in tools:
			return _error("Unknown or duplicate tool")
		tools.append(tool)
	if not value.interest is Dictionary or not _keys(value.interest, ["policy", "region"]):
		return _error("Invalid interest contract")
	if not value.interest.policy in ["owner", "fixed"] or not _region(value.interest.region):
		return _error("Invalid interest region")
	if (not value.execution is Dictionary or not _keys(value.execution,
		["policy", "cadence_lod_enabled", "liquid_surface_adhesion_enabled"])):
		return _error("Invalid execution settings")
	if (not value.execution.policy in ["owner", "fixed"]
		or not value.execution.cadence_lod_enabled is bool
		or not value.execution.liquid_surface_adhesion_enabled is bool):
		return _error("Invalid execution policy")
	if not _integers(value.water_semantics, 4, 0, 12):
		return _error("Invalid Water semantics")
	if (int(value.water_semantics[0]) != 1 or int(value.water_semantics[1]) < 3
		or int(value.water_semantics[1]) > 8 or int(value.water_semantics[3]) != 0):
		return _error("Unsupported Water semantics")
	if not value.transport_profile is Dictionary:
		return _error("Invalid transport profile")
	var transport: Dictionary = CyberTransportProfiles.resolve(value.transport_profile)
	if not transport.get("ok", false): return _error("Transport profile rejected")

	var rectangles: Variant = _records(value.rectangles, 5, 8 * SIDE * SIDE)
	var fills: Variant = _records(value.partial_water_fills, 6, SIDE * SIDE)
	if rectangles == null or fills == null:
		return _error("Invalid setup rectangle/fill or setup capacity exceeded")
	if not value.events is Array or value.events.size() > MAX_EVENTS:
		return _error("Scheduled event capacity exceeded")
	var events: Array = []
	var previous_tick: int = -1
	var event_area: int = 0
	for entry: Variant in value.events:
		if not entry is Dictionary or not _keys(entry, EVENT_KEYS):
			return _error("Invalid event fields")
		if not _integer(entry.tick, 0, MAX_TICK - 1) or int(entry.tick) < previous_tick:
			return _error("Events must be tick-ordered and within the horizon")
		if not entry.kind in ["fill", "erase", "sample"]:
			return _error("Unsupported event; unrestricted scripting is not admitted")
		if not _region([entry.x, entry.y, entry.width, entry.height]):
			return _error("Invalid event region")
		if (not _integer(entry.material, 0, MATERIAL_COUNT - 1)
			or not _integer(entry.normalized_mass, 0, 255)
			or not _integer(entry.coherence, 0, 12)):
			return _error("Invalid event payload")
		if entry.kind == "fill":
			if int(entry.material) != 3: return _error("Fractional fill currently supports Water only")
			if int(entry.normalized_mass) == 0: return _error("Scheduled fill requires positive mass; use erase explicitly")
		elif (int(entry.normalized_mass) != 0 or int(entry.coherence) != 0
			or int(entry.material) == 10
			or (entry.kind == "erase" and int(entry.material) != 0)):
			return _error("Non-fill event has an unexpected payload")
		# Legacy Mercury sample events carry their observed material identity.
		# It remains read-only metadata, not a fill or a material-specific rule.
		event_area += int(entry.width) * int(entry.height)
		if event_area > SIDE * SIDE: return _error("Scheduled event area budget exceeded")
		var event: Dictionary = {}
		for key: String in EVENT_KEYS:
			event[key] = str(entry[key]) if key == "kind" else int(entry[key])
		events.append(event)
		previous_tick = int(entry.tick)

	if not value.observations is Array or value.observations.size() > MAX_OBSERVATIONS:
		return _error("Observation capacity exceeded")
	var observations: Array = []
	var observation_ids: Array = []
	var observation_area: int = 0
	previous_tick = -1
	for entry: Variant in value.observations:
		if not entry is Dictionary or not _keys(entry, OBSERVATION_KEYS):
			return _error("Invalid observation fields")
		if not _identifier(entry.id) or entry.id in observation_ids:
			return _error("Invalid or duplicate observation identity")
		if not _integer(entry.tick, 0, MAX_TICK) or int(entry.tick) < previous_tick:
			return _error("Observations must be tick-ordered and bounded")
		if value.body_enabled and entry.metric == "material_cells":
			return _error("Material-cell counts require an unmasked, body-disabled fixture")
		if not entry.metric in ["water_integer", "material_cells", "tick", "cell_state"]:
			return _error("Unsupported observation metric")
		if entry.metric == "cell_state" and (version != 2 or not _region(entry.region)
			or int(entry.region[2]) != 1 or int(entry.region[3]) != 1):
			return _error("Cell-state inspection requires schema 2 and exactly one cell")
		if (not _region(entry.region) or not _integer(entry.material, 0, MATERIAL_COUNT - 1)
			or int(entry.material) == 10):
			return _error("Invalid observation region/material")
		observation_area += int(entry.region[2]) * int(entry.region[3])
		if observation_area > SIDE * SIDE: return _error("Observation area budget exceeded")
		observations.append({"id":str(entry.id), "tick":int(entry.tick), "metric":str(entry.metric),
			"region":_int_array(entry.region), "material":int(entry.material)})
		observation_ids.append(entry.id)
		previous_tick = int(entry.tick)
	if not value.conditions is Array or value.conditions.size() > MAX_OBSERVATIONS:
		return _error("Condition capacity exceeded")
	var conditions: Array = []
	for entry: Variant in value.conditions:
		if not entry is Dictionary or not _keys(entry, CONDITION_KEYS):
			return _error("Invalid condition fields")
		if not entry.observation in observation_ids or not entry.comparison in ["eq", "le", "ge"]:
			return _error("Unknown observation or comparison")
		for observation: Dictionary in observations:
			if observation.id == entry.observation and observation.metric == "cell_state":
				return _error("Structured cell-state observations are not numeric conditions")
		if not _integer(entry.value, 0, SIDE * SIDE * 255) or not entry.outcome in ["complete", "fail"]:
			return _error("Invalid condition threshold/outcome")
		conditions.append({"observation":str(entry.observation), "comparison":str(entry.comparison),
			"value":int(entry.value), "outcome":str(entry.outcome)})

	var definition: Dictionary = base(str(value.id), int(value.recipe_version), int(value.seed))
	definition.schema_version = version
	if version == 2: definition["presentation"] = presentation
	for key: String in ["maturity", "player_enabled", "body_enabled", "source_recipe", "source_recipe_hash"]:
		definition[key] = value[key]
	definition.rectangles = rectangles
	definition.partial_water_fills = fills
	definition.transport_profile = _normalize_numbers(transport.profile)
	definition.water_semantics = _int_array(value.water_semantics)
	definition.player_start = _int_array(value.player_start)
	definition.camera_origin = _int_array(value.camera_origin)
	definition.tools = tools
	definition.interest = {"policy":str(value.interest.policy), "region":_int_array(value.interest.region)}
	definition.execution = value.execution.duplicate(true)
	definition.events = events
	definition.observations = observations
	definition.conditions = conditions
	var canonical: String = JSON.stringify(definition, "", true)
	if canonical.to_utf8_buffer().size() > MAX_JSON_BYTES: return _error("Definition byte budget exceeded")
	return {"ok":true, "definition":definition, "hash":canonical.sha256_text(),
		"canonical_json":canonical, "transport":transport}

static func _presentation(value: Variant) -> Variant:
	if not value is Dictionary or not _keys(value, ["title", "instructions", "duration_ticks", "baseline", "profile", "regions"]):
		return null
	for key: String in ["title", "instructions", "baseline", "profile"]:
		if not value[key] is String or str(value[key]).is_empty(): return null
		if str(value[key]).length() > (4096 if key == "instructions" else 128): return null
	if not _integer(value.duration_ticks, 1, MAX_TICK) or not value.regions is Array or value.regions.size() > 12:
		return null
	var regions: Array = []
	var ids: Array = []
	for region: Variant in value.regions:
		if not region is Dictionary or not _keys(region, ["id", "label", "region"]): return null
		if not _identifier(region.id) or region.id in ids or not _region(region.region): return null
		if not region.label is String or region.label.is_empty() or region.label.length() > 96: return null
		ids.append(region.id)
		regions.append({"id":str(region.id), "label":str(region.label), "region":_int_array(region.region)})
	return {"title":str(value.title), "instructions":str(value.instructions),
		"duration_ticks":int(value.duration_ticks), "baseline":str(value.baseline),
		"profile":str(value.profile), "regions":regions}

static func _records(value: Variant, stride: int, area_limit: int) -> Variant:
	if not value is Array or value.size() % stride != 0 or value.size() / stride > MAX_RECORDS:
		return null
	var result: Array[int] = []
	var area: int = 0
	for offset: int in range(0, value.size(), stride):
		if not _region(value.slice(offset, offset + 4)): return null
		area += int(value[offset + 2]) * int(value[offset + 3])
		if area > area_limit: return null
		if not _integer(value[offset + 4], 0, MATERIAL_COUNT - 1 if stride == 5 else 255): return null
		if stride == 5 and int(value[offset + 4]) == 10: return null
		if stride == 6 and not _integer(value[offset + 5], 0, 12): return null
		for index: int in range(stride): result.append(int(value[offset + index]))
	return result

static func _region(value: Variant) -> bool:
	return (_integers(value, 4, 0, SIDE) and int(value[2]) > 0 and int(value[3]) > 0
		and int(value[0]) + int(value[2]) <= SIDE and int(value[1]) + int(value[3]) <= SIDE)

static func _integers(value: Variant, count: int, minimum: int, maximum: int) -> bool:
	if not value is Array or value.size() != count: return false
	for entry: Variant in value:
		if not _integer(entry, minimum, maximum): return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	if value is float and (not is_finite(value) or floor(value) != value): return false
	return value >= minimum and value <= maximum

static func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 96: return false
	for character: String in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-._/": return false
	return true

static func _hex_digest(value: String) -> bool:
	if value.length() != 64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true

static func _keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size(): return false
	for key: Variant in value:
		if not key is String or not key in allowed: return false
	return true

static func _int_array(value: Array) -> Array[int]:
	var out: Array[int] = []
	for entry: Variant in value: out.append(int(entry))
	return out

static func _error(message: String) -> Dictionary:
	return {"ok":false, "error":message}

static func _normalize_numbers(value: Variant) -> Variant:
	# Transport validation has already bounded this tree and admitted only
	# integral numeric values. JSON parses numbers as floats; canonical metadata
	# must not turn that representation detail into a different recipe identity.
	if value is float: return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = _normalize_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_normalize_numbers(entry))
		return result
	return value
