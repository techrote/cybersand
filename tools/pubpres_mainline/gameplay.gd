extends "res://tests/pubpres_recovery_gameplay.gd"

# The entire frozen native/physical/input/framebuffer observer is inherited.
# This adds only scalar evidence for the physically evaluated launch policy.
func identity() -> Dictionary:
	var value: Dictionary = super.identity()
	value.files["res://tests/pubpres_mainline_gameplay.gd"] = FileAccess.get_sha256("res://tests/pubpres_mainline_gameplay.gd")
	return value

func effective_selectors() -> Dictionary:
	var value: Dictionary = super.effective_selectors()
	for key: String in ["CYBERSAND_WORKBENCH_FLIGHT_PACING","CYBERSAND_WORKBENCH_COUPLING_CLOCK","CYBERSAND_WORKBENCH_EMPTY_EFFECTS"]:
		value.requested[key] = OS.get_environment(key)
	value["mainline_selected_policy"] = {"flight_pacing":host.get("_flight_pacing"),
		"empty_effects":host.get("_check_ambient_sources"),
		"coupling_clock":host.simulation_worker.get("_independent_coupling")}
	return value
