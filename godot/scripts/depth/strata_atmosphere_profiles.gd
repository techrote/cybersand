extends RefCounted

## Authored visual motifs, never native material state or physical lighting.
## Seeds and settings persist. Presentation phase deliberately does not.
const VERSION := 1
const MAX_EFFECTS := 12
const MAX_MOTIFS := 384
const MAX_PER_EFFECT := 96
const PLANES := ["scripted", "effects", "background"]
const KINDS := ["haze", "steam", "rain", "dust", "beacon", "machinery", "light_shaft", "light_pool"]
const CONFIG_KEYS := ["version", "enabled", "paused", "seed", "effects"]
const EFFECT_KEYS := ["id", "plane", "kind", "region", "seed", "count", "speed", "strength", "direction", "colour", "enabled"]


static func default_configuration() -> Dictionary:
	return {"version": VERSION, "enabled": false, "paused": false, "seed": 1701, "effects": []}


static func presets() -> Array[Dictionary]:
	return [
		{"id":"drifting_haze", "label":"Drifting haze", "kind":"haze", "description":"Slow pixel bands reveal depth; visual colour only, no native gas."},
		{"id":"vent_steam", "label":"Vent steam", "kind":"steam", "description":"Rising fading puffs in a chosen region; no Steam mass or hazard."},
		{"id":"slant_rain", "label":"Slant rain", "kind":"rain", "description":"Sparse directional streaks behind the Play plane; no native Water."},
		{"id":"suspended_dust", "label":"Suspended dust", "kind":"dust", "description":"Small seeded motes for scale and quiet movement; no native Dust."},
		{"id":"warning_beacons", "label":"Warning beacons", "kind":"beacon", "description":"Low-frequency colour pulses; no physical light transport."},
		{"id":"conveyor_lights", "label":"Conveyor lights", "kind":"machinery", "description":"Repeating travelling signal bars; no moving collision geometry."},
		{"id":"architectural_light_shafts", "label":"Architectural light shafts", "kind":"light_shaft", "description":"Eight clipped native-grid bands per ray suggest light through openings; static by default, no native light transport."},
		{"id":"local_light_pools", "label":"Local light pools", "kind":"light_pool", "description":"Four restrained diffusion bands around fixed sources, behind Play; static by default, no screen-wide bloom."}
	]


static func make_effect(preset_id: String, plane: String, region: Rect2i,
		seed: int, effect_id: String) -> Dictionary:
	var choices := {
		"drifting_haze": ["haze", 18, 5.0, 0.35, [1.0, 0.08], [0.45, 0.65, 0.75, 0.50]],
		"vent_steam": ["steam", 22, 18.0, 0.55, [0.12, -1.0], [0.65, 0.78, 0.83, 0.60]],
		"slant_rain": ["rain", 72, 44.0, 0.60, [0.18, 1.0], [0.46, 0.70, 0.86, 0.60]],
		"suspended_dust": ["dust", 40, 3.0, 0.45, [0.70, -0.16], [0.84, 0.65, 0.36, 0.70]],
		"warning_beacons": ["beacon", 4, 1.0, 0.55, [1.0, 0.0], [1.0, 0.33, 0.10, 0.70]],
		"conveyor_lights": ["machinery", 12, 14.0, 0.60, [1.0, 0.0], [0.20, 0.76, 0.85, 0.60]],
		"architectural_light_shafts": ["light_shaft", 3, 0.0, 0.55, [0.18, 1.0], [1.0, 0.82, 0.51, 0.45]],
		"local_light_pools": ["light_pool", 3, 0.0, 0.65, [0.0, 0.0], [0.35, 0.82, 0.95, 0.45]]
	}
	if not choices.has(preset_id): return {}
	var value: Array = choices[preset_id]
	return {"id": effect_id, "plane": plane, "kind": value[0],
		"region": [region.position.x, region.position.y, region.size.x, region.size.y],
		"seed": seed, "count": value[1], "speed": value[2], "strength": value[3],
		"direction": value[4].duplicate(), "colour": value[5].duplicate(), "enabled": true}


static func validate(configuration: Variant, extent: Vector2i) -> String:
	if not _keys(configuration, CONFIG_KEYS) or not _integer(configuration.version, VERSION, VERSION):
		return "Unsupported atmosphere fields or version."
	if not configuration.enabled is bool or not configuration.paused is bool \
			or not _integer(configuration.seed, 0, 2147483647):
		return "Atmosphere enable, pause or seed is invalid."
	if extent.x < 1 or extent.y < 1 or extent.x > 2048 or extent.y > 2048:
		return "Atmosphere requires an admitted native canvas extent."
	if not configuration.effects is Array or configuration.effects.size() > MAX_EFFECTS:
		return "Atmosphere supports at most twelve authored regions."
	var ids: Array[String] = []
	var motifs := 0
	for effect: Variant in configuration.effects:
		if not _keys(effect, EFFECT_KEYS) or not effect.id is String or not _valid_id(effect.id) or effect.id in ids:
			return "Atmosphere effect identities must be unique, bounded identifiers."
		ids.append(effect.id)
		if not effect.plane is String or effect.plane not in PLANES \
				or not effect.kind is String or effect.kind not in KINDS:
			return "Atmosphere requires an explicit decorative plane and supported visual kind."
		if not effect.region is Array or effect.region.size() != 4:
			return "Atmosphere region must contain x, y, width and height."
		for index: int in 4:
			if not _integer(effect.region[index], 0 if index < 2 else 1, 2048):
				return "Atmosphere region coordinates must be bounded integers."
		if int(effect.region[0]) + int(effect.region[2]) > extent.x \
				or int(effect.region[1]) + int(effect.region[3]) > extent.y:
			return "Atmosphere region exceeds the admitted canvas."
		if not effect.enabled is bool or not _integer(effect.seed, 0, 2147483647) \
				or not _integer(effect.count, 0, MAX_PER_EFFECT) \
				or not _number(effect.speed, 0.0, 64.0) or not _number(effect.strength, 0.0, 1.0):
			return "Atmosphere density, speed, strength, seed or enabled state is invalid."
		if not effect.direction is Array or effect.direction.size() != 2:
			return "Atmosphere direction requires two explicit components."
		for component: Variant in effect.direction:
			if not _number(component, -1.0, 1.0): return "Atmosphere direction components must be within -1..1."
		if not effect.colour is Array or effect.colour.size() != 4:
			return "Atmosphere colour requires explicit RGBA components."
		for component: Variant in effect.colour:
			if not _number(component, 0.0, 1.0): return "Atmosphere RGBA components must be within 0..1."
		motifs += int(effect.count)
		if motifs > MAX_MOTIFS: return "Atmosphere exceeds the shared 384-motif budget."
	return ""


static func canonical(configuration: Dictionary) -> Dictionary:
	var result := configuration.duplicate(true)
	result.version = int(result.version)
	result.seed = int(result.seed)
	for effect: Dictionary in result.effects:
		effect.seed = int(effect.seed)
		effect.count = int(effect.count)
		effect.region = Array(PackedInt32Array(effect.region))
		# Integer-valued JSON numbers and float32 UI colours must share one
		# authored representation. Preserve each admitted value without rounding.
		effect.speed = float(effect.speed)
		effect.strength = float(effect.strength)
		effect.direction = Array(PackedFloat64Array(effect.direction))
		effect.colour = Array(PackedFloat64Array(effect.colour))
	return result


static func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 48: return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or code == 45 or code == 95): return false
	return true


static func _keys(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary or value.size() != allowed.size(): return false
	for key: Variant in value:
		if not key is String or key not in allowed: return false
	return value.has_all(allowed)


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))
