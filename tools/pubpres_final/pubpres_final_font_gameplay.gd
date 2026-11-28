extends "res://tests/pubpres_final_gameplay.gd"

# Additive actual default-off deadline proof for this separate engine cohort.
# Sole-worker/callback/Rapier methods remain inherited without replacement.
func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	for path: String in ["res://tests/pubpres_final_font_gameplay.gd",
		"res://scripts/material_publication_deadline.gd"]:
		result.files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else null
	return result

func effective_selectors() -> Dictionary:
	var result: Dictionary = super.effective_selectors()
	result.requested["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"] = OS.get_environment("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ")
	result["font_cohort_material_deadline"] = host.call("material_deadline_status") \
		if host.has_method("material_deadline_status") else null
	return result
