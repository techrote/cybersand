extends "res://tests/test_ambient2_episodes.gd"

# External, source-bound experiment. The production project and base physical
# apparatus remain byte-identical to a725. Only ordinary authored inputs and
# copied diagnostic output are specialized; no controller or actuator is added.
func registry() -> Array:
	var result: Array = []
	for seed: int in [605,1701,2909]:
		for arm: String in ["low_curiosity","high_curiosity"]:
			result.append(make_case("curiosity_contrast","opposed_interest","runner",arm,seed,1,30))
	return result


func profile_for(item: Dictionary, _slot: int) -> Dictionary:
	var profile: Dictionary = Profile.blank("curiosity_contrast")
	profile.name = "Discovery versus routine"
	profile.description = "An editable Oil investigation competes with an ordinary left-side patrol."
	profile.seed = int(item.seed)
	profile.personality.curiosity = 1.0 if item.arm == "high_curiosity" else 0.0
	var discovery: Dictionary = Profile.make_module("investigate_material","discovery")
	discovery.priority = 30
	discovery.weight = 1.0
	# All remaining investigation values are ordinary catalogue defaults:
	# radius64, standoff12, pace0.45, effort0.7, approach12s, inspect2s,
	# habituation12s, cooldown8s, finite commitment3s.
	var routine: Dictionary = Profile.make_module("patrol_route","routine")
	routine.priority = 30
	routine.weight = 0.5
	routine.params.points = [[-48.0,0.0],[-8.0,0.0]]
	routine.params.pace = 0.45
	routine.params.effort = 0.7
	routine.params.arrival_radius = 6.0
	routine.params.leg_seconds = 12.0
	profile.modules = [discovery,routine]
	return profile


func geometry(_item: Dictionary) -> PackedInt32Array:
	# Ordinary native Stone floor/walls and a small contained Oil pocket.
	# Oil lies to the right of the unchanged Runner spawn (220,175).
	return PackedInt32Array([
		0,200,512,8,1, 0,0,8,200,1, 504,0,8,200,1,
		258,190,4,10,1, 286,190,4,10,1, 262,190,24,10,16])


func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	result["external_diagnostic_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	result["supplementary_scope"] = "Six curiosity-only contrasts; excluded from the primary194 registry."
	return result


func record_decisions(session: Node, evaluator: RefCounted, item: Dictionary, rows: Array) -> void:
	super.record_decisions(session,evaluator,item,rows)
	for slot: int in range(rows.size()):
		var control: Dictionary = session.workbench_control(100+slot)
		var diagnostic: Dictionary = control.diagnostics
		var ambient: Dictionary = diagnostic.get("ambient",{})
		var intent: Dictionary = ambient.get("intent",{})
		var environment: Dictionary = diagnostic.get("environment",{})
		var materials: Dictionary = environment.get("materials",{})
		var record: Dictionary = rows[slot].trace.back()
		record["policy_oil"] = sampled_target(materials.get("targets",{}).get("16",{}))
		record["policy_material_sample_tick"] = int(materials.get("sample_tick",-1))
		record["goal_key"] = str(intent.get("goal_key",""))
		record["goal_target"] = intent.get("goal_target",Vector2.ZERO)
		record["candidates"] = intent.get("candidates",[]).duplicate(true)
		record["world_generation"] = int(ambient.get("world_generation",-1))


func checkpoint_report(report: Dictionary) -> void:
	report["supplementary_scope"] = "Curiosity-only ordinary-profile contrast; not the primary194 programme."
	report["qualifies_primary_programme"] = false
	super.checkpoint_report(report)
