extends "res://tests/support/sol_node_trace_authored.gd"

func application_variant_for_arm(_arm: String) -> String:
	return OS.get_environment("SOL_CONTACT_APPLICATION")

func expected_application_velocity(live: Dictionary, action: Dictionary) -> Vector2:
	# The configured experiment, independently of the action tag, selects the
	# real-RID oracle. Native/candidate decision code does not select this result.
	if OS.get_environment("SOL_CONTACT_APPLICATION")=="retain-linear-001":
		check(action.get("linear_clip_policy")=="retain-linear-001","actual retain-linear application")
		return Vector2(live.velocity)+Vector2(action.impulse)/live.mass
	check(not action.has("linear_clip_policy"),"baseline ledger unchanged")
	return super.expected_application_velocity(live,action)
