class_name CyberMicroScenarioContract
extends RefCounted

# Data, never executable callbacks. All bounds are checked before native setup.
const VERSION: int = 1
const MAX_BYTES: int = 2 * 1024 * 1024
const MAX_RECORDS: int = 4096
const MAX_EVENTS: int = 24
const MAX_TICK: int = 3600
const MAX_SEED: int = 0x7fffffff
const WORLD_SIDE: int = 1024
const MODES: Array[String] = ["play", "inspect", "benchmark"]
const KEYS: Array[String] = ["schema_version", "id", "recipe_version", "seed",
	"maturity", "rectangles", "partial_water_fills", "events", "conditions",
	"transport", "water_policy", "player_start", "camera_origin", "body_enabled",
	"tools", "legacy", "seed_scope"]
const EVENT_KEYS: Array[String] = ["tick", "kind", "x", "y", "width", "height",
	"material", "normalized_mass", "coherence", "count_material"]

static func reject(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func integer(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) == floor(float(value)) \
		and value >= low and value <= high

static func identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 96: return false
	for c: String in value:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789-_/": return false
	return true

static func exact_keys(value: Dictionary, allowed: Array) -> bool:
	for key: Variant in value:
		if not key is String or not key in allowed: return false
	return true

static func region(x: Variant, y: Variant, w: Variant, h: Variant) -> bool:
	return integer(x, 0, 1023) and integer(y, 0, 1023) \
		and integer(w, 1, 1024) and integer(h, 1, 1024) \
		and x + w <= WORLD_SIDE and y + h <= WORLD_SIDE

static func point(value: Variant) -> bool:
	return value is Array and value.size() == 2 \
		and integer(value[0], 0, 1023) and integer(value[1], 0, 1023)

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return reject("Definition must be an object")
	if not exact_keys(raw, KEYS) or raw.size() != KEYS.size():
		return reject("Definition has missing or unknown fields")
	if JSON.stringify(raw).to_utf8_buffer().size() > MAX_BYTES:
		return reject("Definition exceeds byte budget")
	if not integer(raw.schema_version, VERSION, VERSION): return reject("Unsupported schema")
	if not identifier(raw.id): return reject("Invalid scenario ID")
	if not integer(raw.recipe_version, 1, 1000000): return reject("Invalid recipe version")
	if not integer(raw.seed, 0, MAX_SEED): return reject("Invalid recipe seed")
	if not raw.maturity in ["exploratory", "reference", "regression"]:
		return reject("Invalid evidence maturity")
	if not raw.seed_scope in ["recipe-identity", "recipe-geometry"]:
		return reject("Seed scope must not imply a new native RNG contract")
	if not point(raw.camera_origin) or (raw.player_start != null and not point(raw.player_start)):
		return reject("Invalid camera/player position")
	if not raw.body_enabled is bool: return reject("Invalid body flag")
	if not raw.tools is Array or raw.tools.size() > 3: return reject("Invalid tools")
	var seen_tools: Dictionary = {}
	for tool: Variant in raw.tools:
		if not tool in ["paint", "erase", "jetpack"] or seen_tools.has(tool):
			return reject("Unknown or duplicate tool")
		seen_tools[tool] = true
	if not raw.legacy is Dictionary or not exact_keys(raw.legacy, ["family", "recipe_hash"]):
		return reject("Invalid legacy identity")
	if not raw.legacy.get("family", "") in ["", "tower", "water"]:
		return reject("Unknown legacy family")
	if not raw.legacy.get("recipe_hash", "") is String:
		return reject("Invalid legacy hash")
	if str(raw.legacy.get("recipe_hash", "")).length() > 64: return reject("Legacy hash too long")
	for field: String in ["rectangles", "partial_water_fills"]:
		var stride: int = 5 if field == "rectangles" else 6
		var records: Variant = raw[field]
		if not records is Array or records.size() % stride != 0 \
			or records.size() > MAX_RECORDS * stride:
			return reject("Invalid %s record count/stride" % field)
		var area: int = 0
		for i: int in range(0, records.size(), stride):
			if not region(records[i], records[i+1], records[i+2], records[i+3]):
				return reject("Out-of-world %s record" % field)
			area += int(records[i+2]) * int(records[i+3])
			if field == "rectangles":
				if not integer(records[i+4], 0, 80): return reject("Invalid material ID")
			elif not integer(records[i+4], 0, 255) or not integer(records[i+5], 0, 12):
				return reject("Invalid fractional Water fill")
		var budget: int = WORLD_SIDE * WORLD_SIDE * (8 if stride == 5 else 1)
		if area > budget: return reject("%s area budget exceeded" % field)
	if not raw.events is Array or raw.events.size() > MAX_EVENTS: return reject("Event budget exceeded")
	var previous: int = 0
	var event_area: int = 0
	for event: Variant in raw.events:
		if not event is Dictionary or not exact_keys(event, EVENT_KEYS): return reject("Invalid event fields")
		for key: String in EVENT_KEYS:
			if key != "count_material" and not event.has(key): return reject("Missing event field")
		if not integer(event.tick, previous, MAX_TICK): return reject("Unordered/out-of-range event tick")
		if not event.kind in ["fill", "erase", "sample"]: return reject("Unsupported event operation")
		if not region(event.x, event.y, event.width, event.height): return reject("Invalid event region")
		if not integer(event.material, 0, 80) or not integer(event.normalized_mass, 0, 255) \
			or not integer(event.coherence, 0, 12): return reject("Invalid event parameters")
		if event.kind == "fill" and (event.material != 3 or event.normalized_mass == 0):
			return reject("Runtime fill capability is explicitly Water-only")
		if not event.get("count_material", false) is bool: return reject("Invalid sample flag")
		if event.get("count_material", false) and (event.kind != "sample" \
			or event.width * event.height > 32768): return reject("Material probe exceeds budget")
		event_area += int(event.width) * int(event.height)
		previous = int(event.tick)
	if event_area > WORLD_SIDE * WORLD_SIDE: return reject("Total event area budget exceeded")
	if not raw.conditions is Array or raw.conditions.size() > 8: return reject("Condition budget exceeded")
	var condition_ids: Dictionary = {}
	for c: Variant in raw.conditions:
		if not c is Dictionary or c.size() != 6 \
			or not exact_keys(c, ["id", "event_index", "metric", "comparison", "value", "outcome"]):
			return reject("Invalid condition fields")
		if not identifier(c.id) or condition_ids.has(c.id): return reject("Invalid/duplicate condition ID")
		condition_ids[c.id] = true
		if not integer(c.event_index, 0, raw.events.size()-1): return reject("Invalid condition event")
		var event: Dictionary = raw.events[int(c.event_index)]
		if event.kind != "sample": return reject("Conditions require a declared sample event")
		if not c.metric in ["water_integer", "water_cells", "tick", "sampled_material_cells"]:
			return reject("Unsupported condition metric")
		if c.metric == "sampled_material_cells" and not event.get("count_material", false):
			return reject("Material condition requires declared counting probe")
		if not c.comparison in ["eq", "ge", "le"] or not c.outcome in ["success", "failure"] \
			or not integer(c.value, 0, 0x7fffffff): return reject("Invalid condition comparison")
	if not raw.transport is Dictionary or not raw.water_policy is Dictionary:
		return reject("Profiles must be objects")
	var transport: Dictionary = CyberTransportProfiles.resolve(raw.transport)
	if not transport.get("ok", false): return reject("Invalid transport profile")
	var water: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, raw.water_policy)
	if not water.get("ok", false): return reject("Invalid Water policy")
	if raw.water_policy.is_empty() and (not raw.partial_water_fills.is_empty() or not raw.events.is_empty()):
		return reject("Fractional fills/events require a declared Water semantic policy")
	# Re-encode only validated JSON data. JSON input's integral floats normalize
	# to ints, so file round-trips and generated definitions have one identity.
	var definition: Dictionary = canonical(raw)
	definition.transport = canonical(transport.profile)
	if not raw.water_policy.is_empty(): definition.water_policy = canonical(water.policy)
	return {"ok": true, "definition": definition, "transport": transport,
		"water": water, "hash": JSON.stringify(definition).sha256_text()}

static func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key: Variant in keys: out[key] = canonical(value[key])
		return out
	if value is Array:
		var out: Array = []
		for entry: Variant in value: out.append(canonical(entry))
		return out
	if value is float and is_finite(value) and value == floor(value): return int(value)
	return value
