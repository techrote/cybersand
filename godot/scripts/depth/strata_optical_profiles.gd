extends RefCounted

## A profile is an editable authored configuration, not a separate renderer.
## Catalogue descriptions express artistic intent; qualification is source-bound.
const Configuration = preload("res://scripts/depth/strata_optics_configuration.gd")
const METADATA := [
	{"id":"classic", "label":"Classic", "description":"Exact Strata 002 presentation. New optical processing is bypassed.", "intent":"Compatibility and immediate reference comparison.", "recommended_scenes":["all"]},
	{"id":"architectural", "label":"Architectural", "description":"Crisp construction detail with restrained distant contrast and neutral atmospheric separation.", "intent":"Inspect architectural relationships without softening the native grid.", "recommended_scenes":["orbital-terminal", "vertical-transfer-spine", "industrial-underworks"]},
	{"id":"gameplay_clarity", "label":"Gameplay Clarity", "description":"Quiets rear detail and reduces decorative emphasis, preserving the unprocessed physical Play plane. Uses tonal and detail cues alongside colour.", "intent":"Prioritise physical platforms, openings and actors over decorative detail.", "recommended_scenes":["all", "optics-readability-challenge"]},
	{"id":"cinematic_deep_focus", "label":"Cinematic Deep Focus", "description":"Detailed layers separated by gentle warm/cool relationships, light diffusion and restrained atmosphere.", "intent":"Keep distant construction recognizable while suggesting a large inhabited space.", "recommended_scenes":["orbital-terminal", "neon-rain-arcology", "sunward-freight-megastructure"]},
	{"id":"optical_lens", "label":"Optical Lens", "description":"A bounded pixel-aware lens with visible distance-dependent focus and subtle luminous diffusion.", "intent":"Explore manual focal distance and aperture-like defocus on real native planes.", "recommended_scenes":["industrial-underworks", "vertical-transfer-spine"]},
	{"id":"diorama", "label":"Diorama", "description":"A shallow focal region and compressed distant detail produce an intentionally miniature-like composition.", "intent":"An optional stylised lens study; compare movement readability before sustained play.", "recommended_scenes":["neon-rain-arcology", "vertical-transfer-spine"]},
	{"id":"atmospheric_industrial", "label":"Atmospheric Industrial", "description":"Warm mineral haze, diffused machine lights and weighty rear silhouettes suggest a working industrial interior.", "intent":"Use local steam and light regions to connect layers without filling every opening.", "recommended_scenes":["industrial-underworks", "sunward-freight-megastructure"]},
	{"id":"noir", "label":"Noir", "description":"Near-monochrome rear silhouettes, lifted distant blacks and selective illumination behind the intact Play palette.", "intent":"Dramatic depth through value hierarchy, with colour available only as a secondary cue.", "recommended_scenes":["abyss-foundry", "industrial-underworks", "neon-rain-arcology"]},
	{"id":"cold_orbital", "label":"Cold Orbital", "description":"Cool graphite distance, restrained cyan machinery light and almost no lens softness.", "intent":"Large vacuum-facing spaces with clear deck edges and a quiet distant horizon.", "recommended_scenes":["orbital-terminal", "lunar-terminator-observatory"]},
	{"id":"alien_bioluminescence", "label":"Alien Bioluminescence", "description":"Muted violet rock distance and local green-cyan light suggest organic depth without a universal blue fog.", "intent":"Keep cave silhouettes readable around sparse luminous organisms and industrial intrusions.", "recommended_scenes":["abyss-foundry", "xeno-resonance-grotto"]},
	{"id":"sunlit_megastructure", "label":"Sunlit Megastructure", "description":"Pale warm scattering, crisp steel and subtle long architectural shadows suggest strong distant illumination.", "intent":"Preserve large silhouettes and negative space in bright side-elevation structures.", "recommended_scenes":["orbital-terminal", "sunward-freight-megastructure", "lunar-terminator-observatory"]}
]


static func list_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in METADATA:
		result.append(entry.duplicate(true))
	return result


static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in METADATA: result.append(str(entry.id))
	return result


static func configuration(id: String) -> Dictionary:
	if id not in ids(): return {}
	var value: Dictionary = Configuration.defaults()
	value.profile = id
	if id == "classic": return value
	value.enabled = true
	value.focus_mode = "play"
	value.focal_plane = "play"
	value.focus_distance = 0.0
	value.strength = 1.0
	value.dof_width = 0.55
	value.defocus = 0.0
	value.transition_speed = 4.0
	value.atmosphere = 0.35
	value.tonal = 0.45
	value.chromatic = 0.35
	value.illumination = 0.35
	value.shadow = 0.12
	value.shadow_offset = [5.0, 7.0]
	value.shadow_softness = 1.0
	value.detail = 0.12
	value.clarity = 0.0
	value.scattering_color = [0.19, 0.21, 0.24]
	value.defocus_method = "pixel"
	_planes(value, {"depth":0.36, "contrast":0.90, "saturation":0.92, "brightness":0.98, "atmosphere":0.45, "glow":0.7},
		{"depth":0.20, "contrast":0.95, "saturation":0.90, "brightness":1.0, "atmosphere":0.25, "glow":0.8},
		{"depth":0.95, "contrast":0.82, "saturation":0.76, "brightness":0.94, "atmosphere":0.7, "glow":0.5})
	match id:
		"architectural":
			value.effects.defocus = false
			value.tonal = 0.58
			value.chromatic = 0.18
			value.atmosphere = 0.22
			value.illumination = 0.18
			value.detail = 0.08
			value.shadow = 0.20
			value.scattering_color = [0.21, 0.22, 0.23]
		"gameplay_clarity":
			value.effects.defocus = false
			value.tonal = 0.90
			value.chromatic = 0.50
			value.atmosphere = 0.20
			value.illumination = 0.08
			value.shadow = 0.22
			value.shadow_offset = [2.0, 3.0]
			value.shadow_softness = 0.75
			value.detail = 0.35
			value.clarity = 0.48
			value.scattering_color = [0.11, 0.12, 0.13]
			_planes(value, {"contrast":0.70, "saturation":0.70, "brightness":0.78, "glow":0.35, "parallax":0.70},
				{"contrast":0.82, "saturation":0.72, "brightness":0.86, "glow":0.35, "parallax":0.70},
				{"contrast":0.62, "saturation":0.55, "brightness":0.72, "glow":0.18, "parallax":0.80})
		"cinematic_deep_focus":
			value.effects.defocus = false
			value.dof_width = 1.5
			value.atmosphere = 0.38
			value.tonal = 0.50
			value.chromatic = 0.38
			value.illumination = 0.45
			value.detail = 0.08
			value.shadow = 0.18
			value.scattering_color = [0.19, 0.25, 0.30]
			_planes(value, {"tint":[1.05, 1.00, 0.94], "contrast":0.94},
				{"tint":[0.96, 1.02, 1.06]}, {"tint":[0.88, 0.97, 1.10], "saturation":0.82, "glow":0.7})
		"optical_lens":
			value.focus_mode = "manual"
			value.dof_width = 0.24
			value.defocus = 1.25
			value.atmosphere = 0.18
			value.tonal = 0.38
			value.chromatic = 0.22
			value.illumination = 0.40
			value.detail = 0.08
			value.shadow = 0.10
			_planes(value, {"defocus":0.75}, {"defocus":0.45}, {"defocus":1.0})
		"diorama":
			value.dof_width = 0.12
			value.defocus = 2.2
			value.defocus_method = "pixel"
			value.atmosphere = 0.18
			value.tonal = 0.62
			value.chromatic = 0.45
			value.illumination = 0.25
			value.detail = 0.28
			value.shadow = 0.28
			value.shadow_offset = [7.0, 10.0]
			value.shadow_softness = 2.0
			_planes(value, {"contrast":0.83, "defocus":0.85, "parallax":0.8},
				{"defocus":0.55, "parallax":0.8}, {"contrast":0.68, "saturation":0.67, "defocus":1.0, "parallax":0.9})
		"atmospheric_industrial":
			value.dof_width = 0.40
			value.defocus = 0.65
			value.defocus_method = "diffusion"
			value.atmosphere = 0.72
			value.tonal = 0.54
			value.chromatic = 0.48
			value.illumination = 0.80
			value.detail = 0.16
			value.shadow = 0.24
			value.shadow_offset = [8.0, 6.0]
			value.shadow_softness = 2.5
			value.scattering_color = [0.33, 0.28, 0.19]
			_planes(value, {"tint":[1.04, 0.99, 0.87], "atmosphere":0.65, "glow":1.0},
				{"tint":[1.04, 1.00, 0.92], "atmosphere":0.6, "glow":1.2},
				{"tint":[0.97, 0.96, 0.83], "atmosphere":0.85, "saturation":0.63, "glow":0.8})
		"noir":
			value.effects.defocus = false
			value.tonal = 0.82
			value.chromatic = 1.0
			value.atmosphere = 0.30
			value.illumination = 0.68
			value.detail = 0.17
			value.shadow = 0.36
			value.shadow_offset = [10.0, 6.0]
			value.shadow_softness = 1.5
			value.clarity = 0.18
			value.scattering_color = [0.16, 0.17, 0.18]
			_planes(value, {"contrast":1.12, "saturation":0.12, "brightness":0.78, "glow":0.8},
				{"contrast":0.94, "saturation":0.18, "brightness":0.88, "glow":1.1},
				{"contrast":0.68, "saturation":0.06, "brightness":0.85, "atmosphere":0.85, "glow":0.4})
		"cold_orbital":
			value.effects.defocus = false
			value.tonal = 0.56
			value.chromatic = 0.42
			value.atmosphere = 0.20
			value.illumination = 0.48
			value.detail = 0.10
			value.shadow = 0.24
			value.scattering_color = [0.11, 0.17, 0.23]
			_planes(value, {"tint":[0.91, 0.99, 1.09], "saturation":0.77, "brightness":0.92},
				{"tint":[0.84, 1.03, 1.12], "glow":1.0},
				{"tint":[0.83, 0.95, 1.12], "saturation":0.60, "contrast":0.76})
		"alien_bioluminescence":
			value.dof_width = 0.55
			value.defocus = 0.45
			value.defocus_method = "diffusion"
			value.tonal = 0.62
			value.chromatic = 0.65
			value.atmosphere = 0.48
			value.illumination = 0.95
			value.detail = 0.18
			value.shadow = 0.17
			value.scattering_color = [0.22, 0.16, 0.30]
			_planes(value, {"tint":[0.91, 1.06, 0.96], "brightness":0.88, "saturation":0.78, "glow":1.0},
				{"tint":[0.86, 1.12, 1.04], "glow":1.35},
				{"tint":[1.04, 0.86, 1.13], "saturation":0.65, "atmosphere":0.9, "glow":0.55})
		"sunlit_megastructure":
			value.effects.defocus = false
			value.tonal = 0.44
			value.chromatic = 0.30
			value.atmosphere = 0.52
			value.illumination = 0.24
			value.detail = 0.10
			value.shadow = 0.30
			value.shadow_offset = [14.0, 10.0]
			value.shadow_softness = 1.25
			value.scattering_color = [0.48, 0.43, 0.31]
			_planes(value, {"tint":[1.05, 1.02, 0.94], "brightness":0.97},
				{"tint":[1.08, 1.04, 0.92], "glow":0.55},
				{"tint":[1.02, 0.98, 0.84], "atmosphere":0.85, "contrast":0.74})
	return value


static func _planes(configuration_value: Dictionary, rear: Dictionary, atmosphere_plane: Dictionary, distant: Dictionary) -> void:
	for pair: Array in [["scripted", rear], ["effects", atmosphere_plane], ["background", distant]]:
		var plane: Dictionary = configuration_value.planes[pair[0]]
		plane.participates = true
		plane.merge(pair[1], true)
	configuration_value.planes.play.participates = false
