extends "res://tests/support/sol_chamber_experiment.gd"
const NormalPolicy = preload("res://tests/support/sol_active_normal_policy.gd")

func configure_fresh_world(world: Variant, mode: String, report: Dictionary) -> bool:
	report["live_registration"]="SOL-ACTIVE-NORMAL-LIVE-001"
	report["normal_policy"]=NormalPolicy.desired()
	return NormalPolicy.configure(world,mode)

func coupling_result(world: Variant) -> Dictionary:
	var packet: Dictionary = NormalPolicy.result(world,OS.get_environment("SOL_CHAMBER_ARM"))
	check(not packet.has("policy_refusal"),"native policy readback before application")
	return packet
