extends "res://tests/pubpres003_causal_gameplay.gd"

# Add identity and requested-treatment observations only. All physical samples,
# callbacks, native/terrain admission and input use the frozen parent. The draw
# hook records the same notification clock, but explicitly refuses a serial
# identity for Separate's deferred Main delivery.
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


func draw_observed() -> void:
	if host == null or not host.common_active or not host.common_detailed: return
	var inline: bool = RenderingServer.is_on_render_thread()
	host.append_common({"event":"framebuffer_draw", "time_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames(), "rendered_frames":Engine.get_frames_drawn(),
		"render_serial":host.last_uploaded_render_snapshot_serial if inline else -1,
		"inline_main":inline,
		"draw_identity_scope":"inline Main publication serial" if inline else "unknown: Separate notification deferred to Main"})
