extends "res://tests/test_workbench_combined_authoring.gd"

# Retain the complete original generation, PAINT, actor, Save and fresh-process
# reopen transaction tape. Only the named publication-control observation changes
# from the older blit profile to the evaluator's ordinary Full/two-slot profile.
func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/pubpres_task_completion_barrier",false)
	super._initialize()


func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	result["tests/pubpres_final_authoring.gd"] = FileAccess.get_sha256(get_script().resource_path)
	result["engine_sha256"] = FileAccess.get_sha256(OS.get_executable_path())
	result["render_thread_inline"] = RenderingServer.is_on_render_thread()
	result["user_data_directory"] = OS.get_user_data_dir()
	return result


func observe_continuation_configuration() -> Dictionary:
	check(same_frame_configuration.mode == "off","final evaluator authoring keeps continuation OFF")
	var expected := {"CYBERSAND_DIAG_SAME_FRAME_CONTINUATION":"0","CYBERSAND_DIAG_NATIVE_RENDEZVOUS":"0",
		"CYBERSAND_DIAG_PHYSICS_PUBLICATION":"early","CYBERSAND_DIAG_PRESENTATION":"coherent",
		"CYBERSAND_DIAG_MATERIAL_TIMING":"measured","CYBERSAND_DIAG_RENDER_CADENCE":"repaired",
		"CYBERSAND_MATERIAL_PUBLICATION":"full","CYBERSAND_MATERIAL_QUEUE_THREAD":OS.get_environment("CYBERSAND_MATERIAL_QUEUE_THREAD"),
		"CYBERSAND_DIAG_MATERIAL_POOL_POLICY":"eager","CYBERSAND_DIAG_FULL_IMAGE_SLOTS":"2",
		"CYBERSAND_DIAG_WATER_COMPOSITION":OS.get_environment("CYBERSAND_DIAG_WATER_COMPOSITION"),
		"CYBERSAND_DIAG_ACTUAL_SUBMISSION":OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION"),
		"CYBERSAND_ENGINE_RENDER_LOOKAHEAD":OS.get_environment("CYBERSAND_ENGINE_RENDER_LOOKAHEAD"),
		"CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL":"0","CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE":"0",
		"CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER":"0"}
	var selectors := {}
	for key: String in expected: selectors[key] = OS.get_environment(key)
	check(selectors == expected,"exact ordinary Full/two-slot authoring selectors")
	check(expected.CYBERSAND_MATERIAL_QUEUE_THREAD in ["safe","separate"] \
		and expected.CYBERSAND_DIAG_ACTUAL_SUBMISSION in ["0","1"] \
		and expected.CYBERSAND_ENGINE_RENDER_LOOKAHEAD in ["0","4"],"registered rendering selectors")
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
	check(expected.CYBERSAND_DIAG_WATER_COMPOSITION in ["0","1"],"explicit selected Water composition")
	var submission: Dictionary = host.workbench_presentation_submission_status()
	var idle: Dictionary = host.simulation_worker.workbench_sample_idle_status()
	var recovery := {"water_enabled":host._workbench_water_composition_enabled(),
		"actual_submission_enabled":bool(submission.get("enabled",false)),"sample_idle_enabled":bool(idle.get("enabled",false))}
	check(recovery.water_enabled == (expected.CYBERSAND_DIAG_WATER_COMPOSITION == "1") \
		and recovery.actual_submission_enabled == (expected.CYBERSAND_DIAG_ACTUAL_SUBMISSION == "1") \
		and not recovery.sample_idle_enabled,"effective recovery policies during author and reopen")
	return {"selectors":selectors,"status":status.duplicate(true),"material":observed,"recovery":recovery}
