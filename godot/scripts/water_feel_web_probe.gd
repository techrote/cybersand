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


static func run_controller(host: Control, presentation: ShaderMaterial) -> Dictionary:
	var result: Dictionary=run(host.native_world,host.demo_bridge,presentation)
	var failures: Array=result.failures
	var base: Dictionary=Profiles.resolve({},{},{"mass_bits":8,
		"coherence_ticks":12,"scenario_id":"shallow-pool","seed":401})
	host.water_lab_apply_result(base)
	if not host.tower_context.get("water_active",false):
		failures.append("controller Apply + Reset did not enter Water Feel")
	var reset_before: Dictionary=host._water_observe_web()
	host.water_lab_reset()
	if host._water_observe_web()!=reset_before:
		failures.append("controller deterministic reset changed initial state")
	host.ui.close_menu()
	var tick_before: int=int(host.native_world.get_tick_index())
	host.tower_command({"step":true})
	host._physics_process(1.0/60.0)
	if int(host.native_world.get_tick_index())!=tick_before+1:
		failures.append("controller pause + single-step was not exact")
	host.water_lab_reset()
	var blind_candidates: Array[int]=[3,5]
	if not host.water_lab_prepare_blind(blind_candidates,402):
		failures.append("controller blind preparation failed")
	var mapping: Dictionary=host.water_blind_set.get("hidden_mapping",{}).duplicate(true)
	var label: String=host.water_active_blind_label
	var nested_candidates: Array[int]=[7,8]
	if host.water_lab_prepare_blind(nested_candidates,403):
		failures.append("controller accepted nested blind preparation")
	var hidden_hash: String=str(host.water_policy_resolved.get("hash",""))
	host.water_lab_apply_result(base)
	if str(host.water_policy_resolved.get("hash",""))!=hidden_hash:
		failures.append("controller accepted unblinded apply during blind")
	if (host.queue_brush_mutation(200,200,0,CyberCellWorld.WALL)
		or host.tower_command({"release":0}) or host.tower_command({"schedule":0})
		or host.set_quality((host.quality+1)%3)
		or host.set_liquid_surface_adhesion(not host.liquid_surface_adhesion_enabled)
		or host.queue_explosion_mutation(200,200,20)
		or bool(host._encode_current().get("ok",true))):
		failures.append("controller accepted an ordinary Water-mode control")
	if not host.water_lab_apply_blind(1):
		failures.append("controller blind candidate switch failed")
	var switched_label: String=host.water_active_blind_label
	host.water_lab_reset()
	if (host.water_blind_set.get("hidden_mapping",{})!=mapping
		or host.water_active_blind_label!=switched_label
		or switched_label==label):
		failures.append("controller blind reset/candidate lifecycle changed mapping")
	host.tower_observation()
	host.select_demo("waterworks",false)
	var ordinary_policy: Dictionary=host.native_world.get_water_experiment_policy()
	if (not host.water_blind_set.is_empty()
		or not host.water_active_blind_label.is_empty()
		or int(ordinary_policy.get("mass_bits",-1))!=8
		or int(ordinary_policy.get("coherence_ticks",-1))!=12):
		failures.append("controller ordinary-demo exit retained blind/default policy state")
	result["controller_lifecycle"]={"apply_reset":true,"single_step":true,
		"blind_mapping_size":mapping.size(),"ordinary_exit":true}
	result["failures"]=failures
	result["ok"]=failures.is_empty()
	return result
