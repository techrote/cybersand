extends "res://tests/pubpres003_causal_gameplay.gd"

# Add identity and requested-treatment observations only. All physical samples,
# callbacks, native/terrain admission and input use the frozen parent. The draw
# hook records the same notification clock, but explicitly refuses a serial
# identity for Separate's deferred Main delivery.
const PresentationProbe = preload("res://tests/pubpres_final_presentation_probe.gd")
var presentation_probe = PresentationProbe.new()
var presentation_enabled := OS.get_environment("CYBERSAND_DIAG_PRESENTATION_OBSERVER") == "1"

func _initialize() -> void:
	if OS.has_environment("CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER"):
		ProjectSettings.set_setting("cybersand/pubpres_task_completion_barrier",
			OS.get_environment("CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER") == "1")
	super._initialize()
	if presentation_enabled:
		RenderingServer.frame_pre_draw.connect(_presentation_pre_draw)

func _presentation_pre_draw() -> void:
	if host != null and host.common_active and host.common_detailed:
		presentation_probe.observe_submission(host)

func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	for path: String in ["res://tests/pubpres_final_gameplay.gd",
		"res://scripts/physical_actor_overlay.gd",
		"res://scripts/material_publication_deadline.gd",
		"res://scripts/material_publication_steps.gd",
		"res://scripts/full_image_ring_publisher.gd","res://tests/pubpres_final_presentation_probe.gd"]:
		result.files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else null
	return result

func effective_selectors() -> Dictionary:
	var result: Dictionary = super.effective_selectors()
	result.requested["CYBERSAND_DIAG_FULL_IMAGE_SLOTS"] = OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS")
	result.requested["CYBERSAND_DIAG_PRESENTATION_OBSERVER"] = OS.get_environment("CYBERSAND_DIAG_PRESENTATION_OBSERVER")
	result.requested["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"] = OS.get_environment("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ")
	result.requested["CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL"] = OS.get_environment("CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL")
	result.requested["CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE"] = OS.get_environment("CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE")
	result.requested["CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER"] = OS.get_environment("CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER")
	result["task_completion"] = host.latest_snapshot.lab_context.get("wave_flow",{}).get("task_completion",null) \
		if host.latest_snapshot != null else null
	result["workbench_sample_idle"] = host.simulation_worker.workbench_sample_idle_status() \
		if host.simulation_worker.has_method("workbench_sample_idle_status") else null
	result["material_steps_api_present"] = host.has_method("material_step_status")
	result["material_steps"] = host.call("material_step_status") if host.has_method("material_step_status") else null
	result["material_deadline"] = host.call("material_deadline_status") if host.has_method("material_deadline_status") else null
	return result


func draw_observed() -> void:
	if host == null or not host.common_active or not host.common_detailed: return
	var inline: bool = RenderingServer.is_on_render_thread()
	host.append_common({"event":"framebuffer_draw", "time_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames(), "rendered_frames":Engine.get_frames_drawn(),
		"render_serial":host.last_uploaded_render_snapshot_serial if inline else -1,
		"inline_main":inline,
		"draw_identity_scope":"inline Main publication serial" if inline else "unknown: Separate notification deferred to Main"})
	if presentation_enabled: presentation_probe.observe_draw(host,inline)


func finish() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_presentation_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_presentation_pre_draw)
	if presentation_enabled:
		var proof: Dictionary = presentation_probe.write(output.trim_suffix(".json")+"-presentation.json",
			source_before,capture_start,capture_end)
		check(proof.complete,"bounded submitted presentation sidecar retained")
	await super.finish()
