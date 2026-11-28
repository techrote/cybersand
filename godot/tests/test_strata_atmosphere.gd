extends SceneTree

const Profiles = preload("res://scripts/depth/strata_atmosphere_profiles.gd")
const Atmosphere = preload("res://scripts/depth/strata_atmosphere.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	var extent := Vector2i(1024, 1024)
	var config: Dictionary = Profiles.default_configuration()
	check(Profiles.validate(config, extent).is_empty(), "default configuration is admitted")
	config.enabled = true
	for preset: Dictionary in Profiles.presets():
		var effect: Dictionary = Profiles.make_effect(preset.id, "effects", Rect2i(24, 36, 256, 192), 17, preset.id)
		check(not effect.is_empty(), "each offered preset has an implementation")
		config.effects.append(effect)
	check(Profiles.validate(config, extent).is_empty(), "all authored presets fit the shared budget")
	var numeric: Dictionary = config.duplicate(true)
	numeric.effects[0].speed = 18
	numeric.effects[0].strength = 1
	numeric.effects[0].direction = [0.1 + 0.2, -1]
	numeric.effects[0].colour = [Color(0.17, 0.31, 0.71, 1.0).r, 0, 0.1 + 0.2, 1]
	var canonical: Dictionary = Profiles.canonical(numeric)
	check(Profiles.validate(canonical, extent).is_empty(), "mixed valid JSON and UI numeric values canonicalize safely")
	check(typeof(canonical.effects[0].speed) == TYPE_FLOAT and typeof(canonical.effects[0].strength) == TYPE_FLOAT,
		"authored continuous scalar settings have stable floating-point types")
	var vector_components_are_float := true
	for component: Variant in canonical.effects[0].direction + canonical.effects[0].colour:
		vector_components_are_float = vector_components_are_float and typeof(component) == TYPE_FLOAT
	check(vector_components_are_float, "direction and RGBA retain floating-point components even at integer values")
	check(typeof(canonical.effects[0].count) == TYPE_INT and typeof(canonical.effects[0].seed) == TYPE_INT \
		and typeof(canonical.effects[0].region[0]) == TYPE_INT, "counts, seeds and native regions retain exact integer types")
	check(typeof(numeric.effects[0].speed) == TYPE_INT and typeof(numeric.effects[0].direction[1]) == TYPE_INT,
		"canonicalization never mutates the source proposal")
	check(Profiles.canonical(canonical) == canonical, "canonicalization is idempotent")
	var parsed: Variant = JSON.parse_string(JSON.stringify(canonical, "", true, true))
	var reopened: Dictionary = Profiles.canonical(parsed)
	check(reopened == canonical, "full-precision JSON roundtrip preserves the complete authored numeric state")
	check(reopened.effects[0].direction[0] == 0.1 + 0.2 \
		and reopened.effects[0].colour[0] == Color(0.17, 0.31, 0.71, 1.0).r,
		"arithmetic floats and float32 UI colour values reopen without decimal rounding")
	for entry: Array in [["version", 2], ["enabled", 1], ["paused", "false"], ["seed", -1], ["unexpected", true]]:
		var bad: Dictionary = config.duplicate(true)
		bad[entry[0]] = entry[1]
		check(not Profiles.validate(bad, extent).is_empty(), "invalid atmosphere root field refused: " + str(entry[0]))
	for entry: Array in [["id", ""], ["plane", "play"], ["kind", "native_steam"], ["count", 97],
		["speed", INF], ["speed", 65], ["strength", -0.1], ["region", [1000, 20, 50, 20]],
		["region", [0, 0, 0, 2]], ["region", [0, 0, 1.5, 2]], ["direction", [2, 0]],
		["colour", [1, 1, 1, 1.1]], ["seed", 2147483648], ["enabled", 1], ["unexpected", 1]]:
		var bad: Dictionary = config.duplicate(true)
		bad.effects[0][entry[0]] = entry[1]
		check(not Profiles.validate(bad, extent).is_empty(), "invalid atmosphere effect refused: " + str(entry[0]))
	for preset_id: String in ["architectural_light_shafts", "local_light_pools"]:
		var lighting := Profiles.default_configuration()
		lighting.enabled = true
		lighting.effects = [Profiles.make_effect(preset_id, "effects", Rect2i(16, 32, 128, 96), 3, "light")]
		var light_node := Atmosphere.new()
		root.add_child(light_node)
		check(light_node.configure(lighting, extent, "effects"), preset_id + " bounded presentation configuration admitted")
		light_node.set_plane_active(true)
		check(not light_node.is_processing(), preset_id + " static default has no recurring callback")
		light_node.advance(1.0)
		check(light_node.diagnostics().phase_seconds == 0.0, preset_id + " static source phase remains fixed")
		lighting.effects[0].speed = 0.5
		check(light_node.configure(lighting, extent, "effects") and light_node.is_processing(), preset_id + " optional breathing starts visible presentation callback")
		light_node.advance(0.05)
		check(is_equal_approx(light_node.diagnostics().phase_seconds, 0.05), preset_id + " breathing advances only presentation phase")
		light_node.set_plane_active(false)
		check(not light_node.is_processing(), preset_id + " hidden plane stops optional breathing")
		light_node.free()
	var duplicate: Dictionary = config.duplicate(true)
	duplicate.effects[1].id = duplicate.effects[0].id
	check(not Profiles.validate(duplicate, extent).is_empty(), "duplicate effect identity refused")
	var over: Dictionary = config.duplicate(true)
	for effect: Dictionary in over.effects: effect.count = 96
	check(not Profiles.validate(over, extent).is_empty(), "aggregate motif budget is enforced")
	var many: Dictionary = Profiles.default_configuration()
	for index: int in 13:
		many.effects.append(Profiles.make_effect("suspended_dust", "effects", Rect2i(0, 0, 64, 64), index, "dust_" + str(index)))
	check(not Profiles.validate(many, extent).is_empty(), "region count budget is enforced")
	var node := Atmosphere.new()
	root.add_child(node)
	check(node.configure(config, extent, "effects"), "renderer admits the complete authored configuration")
	check(not node.is_processing(), "inactive renderer performs no recurring processing")
	node.advance(1.0)
	check(node.diagnostics().phase_seconds == 0.0, "hidden effect phase stays frozen")
	node.set_plane_active(true)
	check(node.is_processing(), "visible enabled motifs process")
	node.advance(0.05)
	check(is_equal_approx(node.diagnostics().phase_seconds, 0.05), "presentation clock advances explicitly")
	node.advance(9.0)
	check(is_equal_approx(node.diagnostics().phase_seconds, 0.15), "a stalled callback cannot create catch-up motion")
	check(is_equal_approx(node.diagnostics().clamped_seconds, 8.9), "discarded presentation time is measured")
	var before: Dictionary = node.diagnostics()
	node.advance(NAN)
	node.advance(-1.0)
	check(node.diagnostics().phase_seconds == before.phase_seconds, "non-finite and negative time are ignored")
	config.paused = true
	check(node.configure(config, extent, "effects"), "pause setting is admitted")
	node.advance(0.1)
	check(node.diagnostics().phase_seconds == before.phase_seconds and not node.is_processing(), "pause freezes clock and processing")
	var retained: Dictionary = node.diagnostics()
	var refused: Dictionary = config.duplicate(true)
	refused.effects[0].plane = "play"
	check(not node.configure(refused, extent, "effects"), "renderer refuses invalid candidate")
	check(node.diagnostics().configuration_sha256 == retained.configuration_sha256, "refused candidate retains previous configuration")
	var precise: Dictionary = config.duplicate(true)
	precise.effects[0].colour[0] = 0.3
	check(node.configure(precise, extent, "effects"), "first exact colour proposal is admitted")
	var first_precision_digest: String = node.diagnostics().configuration_sha256
	precise.effects[0].colour[0] = 0.1 + 0.2
	check(node.configure(precise, extent, "effects"), "adjacent arithmetic colour proposal is admitted")
	check(node.diagnostics().configuration_sha256 != first_precision_digest \
		and node._configuration.effects[0].colour[0] == 0.1 + 0.2,
		"renderer configuration cache never aliases distinct admitted float values")
	config.paused = false
	config.enabled = false
	node.configure(config, extent, "effects")
	node.advance(0.1)
	check(node.diagnostics().phase_seconds == before.phase_seconds and not node.is_processing(), "disabled atmosphere freezes clock and processing")
	node.reset_phase()
	check(node.diagnostics().phase_seconds == 0.0, "reset affects visual phase only")
	check(not node.configure(config, extent, "play"), "renderer has no physical Play target")
	var diagnostic: Dictionary = node.diagnostics()
	check(diagnostic.additional_native_worlds == 0 and diagnostic.native_material_writes == 0 \
		and diagnostic.native_captures == 0 and diagnostic.texture_uploads == 0, "visual renderer declares no native authority or publications")
	node.free()
	print("STRATA_ATMOSPHERE " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
