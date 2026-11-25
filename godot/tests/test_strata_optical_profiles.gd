extends SceneTree

const Profiles = preload("res://scripts/depth/strata_optical_profiles.gd")
const Configuration = preload("res://scripts/depth/strata_optics_configuration.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var ids := Profiles.ids()
	check(ids.size() >= 8, "catalogue includes at least eight independent editable treatments")
	check(Profiles.configuration("classic") == Configuration.defaults(), "Classic is the exact disabled default configuration")
	check(Profiles.configuration("../unknown").is_empty(), "unknown profile identity is refused")
	var signatures: Array[String] = []
	var methods: Array[String] = []
	var no_defocus := 0
	for id: String in ids:
		var config := Profiles.configuration(id)
		check(Configuration.validate(config).is_empty(), id + " satisfies the complete strict authored schema")
		check(not config.planes.play.participates, id + " never processes physical Play materials")
		check(config.planes.play == Configuration.defaults().planes.play, id + " keeps Play optical fields unchanged")
		var independent := Profiles.configuration(id)
		config.planes.scripted.tint[0] = 1.75
		config.shadow_offset[0] = -29.0
		config.effects.tonal = not config.effects.tonal
		check(Profiles.configuration(id) == independent, id + " returned mutable controls cannot alter shared catalogue defaults")
		var reopened: Variant = JSON.parse_string(JSON.stringify(independent, "", true, true))
		check(Configuration.validate(reopened).is_empty(), id + " JSON preset survives strict revalidation")
		check(Configuration.canonical(reopened) == Configuration.canonical(independent), id + " canonical preset roundtrip retains all artistic values")
		var appearance := independent.duplicate(true)
		appearance.erase("profile")
		var signature := JSON.stringify(appearance, "", true, true).sha256_text()
		check(signature not in signatures, id + " changes actual controls, not only the profile name")
		signatures.append(signature)
		if independent.defocus_method not in methods: methods.append(independent.defocus_method)
		if not independent.effects.defocus: no_defocus += 1
	check(methods.size() >= 2, "catalogue exercises distinct pixel and diffusion methods")
	check(no_defocus >= 4, "several profiles deliberately preserve full decorative sharpness")
	var clarity := Profiles.configuration("gameplay_clarity")
	check(clarity.clarity > 0.0 and clarity.tonal > clarity.chromatic,
		"Gameplay Clarity combines non-colour assistance and stronger tonal than chromatic response")
	check(not clarity.effects.defocus, "Gameplay Clarity does not rely on background blur")
	var meta := Profiles.list_profiles()
	check(meta.size() == ids.size(), "metadata and configuration catalogue align")
	meta[0].recommended_scenes.append("mutated")
	check("mutated" not in Profiles.list_profiles()[0].recommended_scenes,
		"metadata nested lists are independently mutable")
	for entry: Dictionary in Profiles.list_profiles():
		check(entry.id in ids and not entry.label.is_empty() and not entry.description.is_empty()
			and not entry.intent.is_empty() and not entry.recommended_scenes.is_empty(),
			entry.id + " includes practical artistic guidance")
	print("STRATA_OPTICAL_PROFILES ", JSON.stringify({"checks":checks,"failures":failures,"profiles":ids}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
