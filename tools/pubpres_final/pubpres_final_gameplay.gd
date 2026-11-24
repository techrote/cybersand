extends "res://tests/pubpres003_causal_gameplay.gd"

# Add identity and requested-treatment observations only. All physical samples,
# callbacks, native/terrain admission, input and drawing use the frozen parent.
func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	for path: String in ["res://tests/pubpres_final_gameplay.gd",
		"res://scripts/full_image_ring_publisher.gd"]:
		result.files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else null
	return result

func effective_selectors() -> Dictionary:
	var result: Dictionary = super.effective_selectors()
	result.requested["CYBERSAND_DIAG_FULL_IMAGE_SLOTS"] = OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS")
	return result
