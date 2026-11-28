extends "res://tests/test_workbench_combined_authoring.gd"

# Retain the complete original generation, PAINT, actor, Save and fresh-process
# reopen transaction tape. Only the named publication-control observation changes
# from the older blit profile to the evaluator's ordinary Full/two-slot profile.
func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	result["tests/pubpres_final_authoring.gd"] = FileAccess.get_sha256(get_script().resource_path)
	result["engine_sha256"] = FileAccess.get_sha256(OS.get_executable_path())
	result["render_thread_inline"] = RenderingServer.is_on_render_thread()
	return result


func observe_continuation_configuration() -> Dictionary:
	check(same_frame_configuration.mode == "off","final evaluator authoring keeps continuation OFF")
	var expected := {"CYBERSAND_DIAG_SAME_FRAME_CONTINUATION":"0","CYBERSAND_DIAG_NATIVE_RENDEZVOUS":"0",
		"CYBERSAND_DIAG_PHYSICS_PUBLICATION":"early","CYBERSAND_DIAG_PRESENTATION":"coherent",
		"CYBERSAND_DIAG_MATERIAL_TIMING":"measured","CYBERSAND_DIAG_RENDER_CADENCE":"repaired",
		"CYBERSAND_MATERIAL_PUBLICATION":"full","CYBERSAND_MATERIAL_QUEUE_THREAD":"safe",
		"CYBERSAND_DIAG_MATERIAL_POOL_POLICY":"eager","CYBERSAND_DIAG_FULL_IMAGE_SLOTS":"2"}
	var selectors := {}
	for key: String in expected: selectors[key] = OS.get_environment(key)
	check(selectors == expected,"exact ordinary Full/two-slot authoring selectors")
	var status: Dictionary = host.same_frame_continuation_status()
	var expected_status := {"version":1,"requested":false,"enabled":false,"disabled_reason":"","mode":"off",
		"maximum_attempts_per_process_frame":1,"maximum_mailbox_reads_per_attempt":1,"wait_usec":0,
		"new_physics_callbacks":0,"carried_time_credit":false}
	check(status == expected_status,"actual continuation OFF bounds")
	var material: Dictionary = host.material_publication_status()
	var observed := {"requested_mode":material.requested_mode,"backend":material.backend,
		"full_image_slots":material.full_image_slots,"fallback_reason":material.fallback_reason}
	check(observed == {"requested_mode":"full","backend":"full","full_image_slots":2,"fallback_reason":""},
		"actual two-slot Full material owner")
	return {"selectors":selectors,"status":status.duplicate(true),"material":observed}
