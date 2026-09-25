extends RefCounted

# PENV-001 player/environment tuning profile schema. These values are gameplay
# tuning inputs, not calibrated SI units. The exact-current preset intentionally
# mirrors the pre-PENV CyberSampledCharacter constants.
const VERSION: int = 1
const PRESET_CURRENT: int = 0
const PRESET_EARTH_FEEL: int = 1

const CURRENT_BASELINE: Dictionary = {
	"version": VERSION,
	"id": "current-baseline",
	"label": "Current baseline",
	"effective_mass": 1.0,
	"gravity_acceleration": 92.0,
	"terminal_fall_speed": 86.0,
	"jetpack_acceleration": 180.0,
	"jetpack_max_rise_speed": 60.0,
	"granular_response_sensitivity": 1.0,
	"granular_response_identity": "rem003-c1-impact-speed-scale-v1",
	"liquid_response_sensitivity": 1.0,
	"liquid_response_identity": "player-side-only/no-water-semantic-hook",
	"step_height": 1,
	"knee_height": 1,
	"clamber_height": 1,
	"knee_slowdown": 0.65,
	"clamber_slowdown": 0.35,
}

const EARTH_FEEL_CANDIDATE: Dictionary = {
	"version": VERSION,
	"id": "earth-feel-2x-gravity",
	"label": "Earth-feel candidate (~2x gravity)",
	"effective_mass": 1.0,
	"gravity_acceleration": 184.0,
	"terminal_fall_speed": 86.0,
	"jetpack_acceleration": 180.0,
	"jetpack_max_rise_speed": 60.0,
	"granular_response_sensitivity": 1.0,
	"granular_response_identity": "rem003-c1-impact-speed-scale-v1",
	"liquid_response_sensitivity": 1.0,
	"liquid_response_identity": "player-side-only/no-water-semantic-hook",
	"step_height": 1,
	"knee_height": 1,
	"clamber_height": 1,
	"knee_slowdown": 0.65,
	"clamber_slowdown": 0.35,
}

const NUMERIC_LIMITS: Dictionary = {
	"effective_mass": [0.05, 20.0],
	"gravity_acceleration": [0.0, 2000.0],
	"terminal_fall_speed": [1.0, 2000.0],
	"jetpack_acceleration": [0.0, 4000.0],
	"jetpack_max_rise_speed": [0.0, 2000.0],
	"granular_response_sensitivity": [0.0, 8.0],
	"liquid_response_sensitivity": [0.0, 8.0],
	"knee_slowdown": [0.05, 1.0],
	"clamber_slowdown": [0.05, 1.0],
}


static func preset(index: int) -> Dictionary:
	match index:
		PRESET_EARTH_FEEL:
			return _finalize(EARTH_FEEL_CANDIDATE.duplicate(true))
		_:
			return _finalize(CURRENT_BASELINE.duplicate(true))


static func preset_names() -> PackedStringArray:
	return PackedStringArray([
		str(CURRENT_BASELINE.label),
		str(EARTH_FEEL_CANDIDATE.label),
		"Custom",
	])


static func resolve(candidate: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = CURRENT_BASELINE.duplicate(true)
	profile.merge(candidate, true)
	profile.version = VERSION

	for key: String in NUMERIC_LIMITS:
		if not profile.has(key):
			return {"ok": false, "error": "missing numeric field " + key}
		var value: float = float(profile[key])
		var limits: Array = NUMERIC_LIMITS[key]
		if value != value or value < float(limits[0]) or value > float(limits[1]):
			return {"ok": false, "error": "%s outside allowed range" % key}
		profile[key] = value

	for key: String in ["step_height", "knee_height", "clamber_height"]:
		if not profile.has(key):
			return {"ok": false, "error": "missing traversal field " + key}
		var height: int = int(profile[key])
		if height < 0 or height > 32:
			return {"ok": false, "error": "%s outside 0..32" % key}
		profile[key] = height

	if int(profile.step_height) > int(profile.knee_height):
		return {"ok": false, "error": "step height must be <= knee height"}
	if int(profile.knee_height) > int(profile.clamber_height):
		return {"ok": false, "error": "knee height must be <= clamber height"}

	profile.id = str(profile.get("id", "custom")).strip_edges()
	if profile.id.is_empty():
		profile.id = "custom"
	profile.label = str(profile.get("label", profile.id)).strip_edges()
	if profile.label.is_empty():
		profile.label = profile.id
	profile.granular_response_identity = str(
		profile.get("granular_response_identity", CURRENT_BASELINE.granular_response_identity)
	)
	profile.liquid_response_identity = str(
		profile.get("liquid_response_identity", CURRENT_BASELINE.liquid_response_identity)
	)
	return {"ok": true, "profile": _finalize(profile)}


static func custom_from(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var candidate: Dictionary = base.duplicate(true)
	candidate.merge(overrides, true)
	candidate.id = "custom"
	candidate.label = "Custom"
	var resolved: Dictionary = resolve(candidate)
	return resolved.profile if resolved.get("ok", false) else {}


static func _finalize(profile: Dictionary) -> Dictionary:
	profile.erase("hash")
	var canonical: String = JSON.stringify(profile, "", true)
	profile.hash = canonical.sha256_text()
	return profile
