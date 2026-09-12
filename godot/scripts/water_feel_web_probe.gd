class_name CyberWaterFeelWebProbe
extends RefCounted

const Profiles = preload("res://scripts/water_experiment_profiles.gd")
const Scenarios = preload("res://scripts/water_feel_scenarios.gd")


static func run(world: Object, bridge: Object, presentation: ShaderMaterial) -> Dictionary:
	var failures: Array[String] = []
	var transport: Dictionary = CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	var scenario_cases: int = 0
	var action_cases: int = 0
	var default_hash: String = ""
	for scenario_id: String in Scenarios.ids():
		for endpoint: Dictionary in [
			{"mass_bits": 3, "coherence_ticks": 0},
			{"mass_bits": 8, "coherence_ticks": 12},
		]:
			var resolved: Dictionary = Profiles.resolve({}, {}, {
				"mass_bits": endpoint.mass_bits,
				"coherence_ticks": endpoint.coherence_ticks,
				"scenario_id": scenario_id,
				"seed": 31,
			})
			var recipe: Dictionary = Scenarios.recipe(scenario_id, 31)
			if not resolved.get("ok", false) or recipe.is_empty():
				failures.append("resolve/recipe %s mass%d" % [scenario_id, endpoint.mass_bits])
				continue
			if not bridge.build_water_feel_world(
				world, recipe.rectangles, transport.packed,
				resolved.semantic, recipe.partial_water_fills
			):
				failures.append("build %s mass%d: %s" % [
					scenario_id, endpoint.mass_bits, bridge.get_last_error(),
				])
				continue
			scenario_cases += 1
			for action: Dictionary in recipe.actions:
				var accepted: bool = true
				match str(action.kind):
					"fill":
						var coherence: int = int((
							2 * int(action.coherence) * int(endpoint.coherence_ticks) + 12
						) / 24)
						accepted = bool(world.water_experiment_fill_rect(
							Vector2i(int(action.x), int(action.y)),
							Vector2i(int(action.width), int(action.height)),
							int(action.normalized_mass), coherence
						))
					"erase":
						accepted = bool(world.water_experiment_erase_rect(
							Vector2i(int(action.x), int(action.y)),
							Vector2i(int(action.width), int(action.height))
						))
					"sample":
						accepted = not world.water_experiment_observation(
							Vector2i(int(action.x), int(action.y)),
							Vector2i(int(action.width), int(action.height))
						).is_empty()
					_:
						accepted = false
				action_cases += 1
				if not accepted:
					failures.append("action %s/%s mass%d" % [
						scenario_id, action.kind, endpoint.mass_bits,
					])
			if scenario_id == "shallow-pool" and int(endpoint.mass_bits) == 8:
				default_hash = str(world.water_experiment_observation(
					Vector2i.ZERO,
					Vector2i(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
				).get("state_hash", ""))

	var before_invalid: Dictionary = world.water_experiment_observation(
		Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	)
	var invalid_rejected: bool = not bridge.build_water_feel_world(
		world, PackedInt32Array(), transport.packed,
		PackedInt32Array([1, 2, 12, 0]), PackedInt32Array()
	)
	var after_invalid: Dictionary = world.water_experiment_observation(
		Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	)
	if not invalid_rejected or before_invalid != after_invalid:
		failures.append("invalid policy did not preserve authoritative state")

	var before_presentation: Dictionary = after_invalid.duplicate(true)
	presentation.set_shader_parameter("water_presentation_mode", 1.0)
	presentation.set_shader_parameter("water_presentation_mode", 2.0)
	var after_presentation: Dictionary = world.water_experiment_observation(
		Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	)
	if before_presentation != after_presentation:
		failures.append("presentation mode mutated authoritative state")

	return {
		"ok": failures.is_empty(),
		"profile": "threaded" if OS.has_feature("threads") else "compat",
		"worker_count": int(world.get_worker_threads()),
		"scenario_cases": scenario_cases,
		"action_cases": action_cases,
		"catalogue_hash": Scenarios.catalogue_hash(31),
		"default_state_hash": default_hash,
		"invalid_preserved": invalid_rejected and before_invalid == after_invalid,
		"presentation_preserved": before_presentation == after_presentation,
		"failures": failures,
	}
