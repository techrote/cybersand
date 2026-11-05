extends "res://tests/test_la_physical_campaign.gd"
const NormalPolicy = preload("res://tests/support/sol_active_normal_policy.gd")

func configure_fresh_world(world: Variant, mode: String, _report: Dictionary) -> bool:
	return NormalPolicy.configure(world,mode)

func coupling_result(world: Variant) -> Dictionary:
	var packet: Dictionary = NormalPolicy.result(world,"LA-SELECTIVE")
	check(not packet.has("policy_refusal"),"native policy readback before application")
	return packet
