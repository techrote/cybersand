extends "res://tests/pubpres_source_transition_oracle.gd"

# The frozen two-slot oracle owns the entire tape and every first-read check.
# Additional observations identify the real render owner and the two retained
# resources; they neither alter a publication nor repair a failed read.
func _build_host() -> void:
	_check(strategy == "full" and OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") == "2",
		"explicit ordinary Full two-slot control required")
	super._build_host()
	_check(host.texture is ImageTexture and host.previous_texture is ImageTexture
		and host._material_full_ring == null,"ordinary two-slot ImageTexture owner required")


func _submit(index: int) -> Dictionary:
	var row: Dictionary = super._submit(index)
	row.material["two_slot_current_rid"] = host.texture.get_rid().get_id()
	row.material["two_slot_previous_rid"] = host.previous_texture.get_rid().get_id()
	return row


func _check_history() -> Dictionary:
	var result: Dictionary = super._check_history()
	result["render_thread_inline"] = RenderingServer.is_on_render_thread()
	result["publisher_sha256"] = FileAccess.get_sha256("res://scripts/full_image_ring_publisher.gd")
	return result
