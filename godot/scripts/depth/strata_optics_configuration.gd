extends RefCounted

## Strict authored optics values. These are presentation parameters, never
## native geometry, a simulation depth or an edit destination. Application
## quality and temporary comparisons deliberately live outside this schema.
const Setup = preload("res://scripts/workbench_setup.gd")
const VERSION := 1
const IDS := ["play", "scripted", "effects", "background"]
const EFFECTS := ["defocus", "tonal", "chromatic", "atmosphere", "illumination", "shadows", "detail"]
const KEYS := ["version", "profile", "enabled", "strength", "focus_mode", "focal_plane",
	"focus_distance", "dof_width", "defocus", "transition_speed", "atmosphere", "tonal",
	"chromatic", "illumination", "shadow", "shadow_offset", "shadow_softness", "detail",
	"clarity", "scattering_color", "defocus_method", "effects", "planes"]
const PLANE_KEYS := ["participates", "depth", "contrast", "saturation", "tint", "brightness",
	"defocus", "atmosphere", "glow", "opacity", "parallax"]
const GLOBAL_RANGES := {
	"strength":[0.0,1.0], "focus_distance":[-1.0,2.0], "dof_width":[0.0,2.0],
	"defocus":[0.0,3.0], "transition_speed":[0.0,12.0], "atmosphere":[0.0,2.0],
	"tonal":[0.0,1.0], "chromatic":[0.0,1.0], "illumination":[0.0,2.0],
	"shadow":[0.0,1.0], "shadow_softness":[0.0,4.0], "detail":[0.0,1.0], "clarity":[0.0,1.0]}
const PLANE_RANGES := {
	"depth":[-1.0,2.0], "contrast":[0.25,1.5], "saturation":[0.0,1.5],
	"brightness":[0.25,2.0], "defocus":[0.0,2.0], "atmosphere":[0.0,2.0],
	"glow":[0.0,2.0], "opacity":[0.0,1.0], "parallax":[0.0,2.0]}
const INSPECTION_KEYS := ["bypass", "clarity", "wipe", "focus_override"]
const QUALITIES := ["low", "balanced", "high"]


static func defaults() -> Dictionary:
	var planes := {}
	var depths := [0.0, 0.4, 0.65, 1.0]
	for index: int in IDS.size():
		planes[IDS[index]] = {"participates":index != 0, "depth":depths[index],
			"contrast":1.0, "saturation":1.0, "tint":[1.0,1.0,1.0], "brightness":1.0,
			"defocus":1.0, "atmosphere":1.0, "glow":1.0, "opacity":1.0, "parallax":1.0}
	return {"version":VERSION, "profile":"classic", "enabled":false, "strength":1.0,
		"focus_mode":"play", "focal_plane":"play", "focus_distance":0.0,
		"dof_width":0.35, "defocus":0.35, "transition_speed":5.0,
		"atmosphere":0.35, "tonal":0.5, "chromatic":0.5, "illumination":0.35,
		"shadow":0.25, "shadow_offset":[6.0,8.0], "shadow_softness":1.0,
		"detail":0.25, "clarity":0.0, "scattering_color":[0.18,0.22,0.28],
		"defocus_method":"pixel",
		"effects":{"defocus":true,"tonal":true,"chromatic":true,"atmosphere":true,
			"illumination":true,"shadows":true,"detail":true}, "planes":planes}


static func inspection_defaults() -> Dictionary:
	return {"bypass":false,"clarity":false,"wipe":1.0,"focus_override":""}


static func _vector(value: Variant, size: int, low: float, high: float) -> bool:
	if not value is Array or value.size() != size: return false
	for component: Variant in value:
		if not Setup._number(component,low,high): return false
	return true


static func validate(configuration: Variant) -> String:
	if not Setup._keys(configuration,KEYS) or not Setup._integer(configuration.version,VERSION,VERSION):
		return "Unsupported optical configuration fields or version."
	if not configuration.profile is String or configuration.profile.is_empty() or configuration.profile.length() > 64:
		return "The optical profile identity must contain 1–64 characters."
	if not configuration.enabled is bool:
		return "Optical processing enablement must be a boolean."
	if not configuration.focus_mode is String or configuration.focus_mode not in ["play","manual","plane","authoring"] \
			or not configuration.focal_plane is String or configuration.focal_plane not in IDS:
		return "Unsupported optical focus mode or focal plane."
	if not configuration.defocus_method is String or configuration.defocus_method not in ["pixel","diffusion","detail"]:
		return "Unsupported optical defocus technique."
	for key: String in GLOBAL_RANGES:
		var limits: Array = GLOBAL_RANGES[key]
		if not Setup._number(configuration[key],limits[0],limits[1]):
			return "Optical %s must be finite and within %.2f–%.2f." % [key,limits[0],limits[1]]
	if not _vector(configuration.shadow_offset,2,-32.0,32.0) \
			or not _vector(configuration.scattering_color,3,0.0,1.0):
		return "Invalid optical shadow offset or scattering colour."
	if not Setup._keys(configuration.effects,EFFECTS): return "Unsupported optical effect switches."
	for key: String in EFFECTS:
		if not configuration.effects[key] is bool: return "Every optical effect switch must be a boolean."
	if not Setup._keys(configuration.planes,IDS): return "Optics requires the four existing plane identities."
	for id: String in IDS:
		var plane: Variant = configuration.planes[id]
		if not Setup._keys(plane,PLANE_KEYS) or not plane.participates is bool:
			return "Unsupported optical plane fields."
		if id == "play" and plane.participates:
			return "Play retains its exact material renderer; optical processing addresses decoration."
		for key: String in PLANE_RANGES:
			var limits: Array = PLANE_RANGES[key]
			if not Setup._number(plane[key],limits[0],limits[1]):
				return "Optical %s %s is outside its finite range." % [id,key]
		if not _vector(plane.tint,3,0.0,2.0): return "Optical tint requires three finite channels from 0 to 2."
	return ""


static func canonical(configuration: Dictionary) -> Dictionary:
	# Callers must validate first. Canonical numeric types and complete copies
	# prevent UI/preset dictionaries from becoming shared mutable scene state.
	var result := configuration.duplicate(true)
	result.version = VERSION
	for key: String in GLOBAL_RANGES: result[key] = float(result[key])
	for key: String in ["shadow_offset","scattering_color"]:
		for index: int in result[key].size(): result[key][index] = float(result[key][index])
	for id: String in IDS:
		for key: String in PLANE_RANGES: result.planes[id][key] = float(result.planes[id][key])
		for index: int in 3: result.planes[id].tint[index] = float(result.planes[id].tint[index])
	return result


static func patched(configuration: Dictionary, patch: Dictionary, plane: String = "") -> Dictionary:
	var error := validate(configuration)
	if not error.is_empty(): return {"error":error}
	var result := configuration.duplicate(true)
	if not plane.is_empty() and plane not in IDS: return {"error":"Unknown optical plane."}
	var target: Dictionary = result if plane.is_empty() else result.planes[plane]
	for key: Variant in patch:
		if not key is String or not target.has(key) or (plane.is_empty() and key in ["version","planes"]):
			return {"error":"An optical patch cannot replace schema or plane ownership."}
		target[key] = patch[key].duplicate(true) if patch[key] is Dictionary or patch[key] is Array else patch[key]
	error = validate(result)
	if not error.is_empty(): return {"error":error}
	return {"configuration":canonical(result)}


static func validate_inspection(value: Variant) -> String:
	if not Setup._keys(value,INSPECTION_KEYS) or not value.bypass is bool or not value.clarity is bool \
			or not Setup._number(value.wipe,0.0,1.0) or not value.focus_override is String \
			or value.focus_override not in IDS + [""]:
		return "Unsupported temporary optical comparison settings."
	return ""


static func fingerprint(configuration: Dictionary) -> String:
	if not validate(configuration).is_empty(): return ""
	return JSON.stringify(canonical(configuration),"",true,true).sha256_text()
