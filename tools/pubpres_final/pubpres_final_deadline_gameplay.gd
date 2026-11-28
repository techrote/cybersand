extends "res://tests/pubpres_final_gameplay.gd"

## Add one bounded, separately hashed scheduling observation stream. Every
## native operation, physical callback, input and original V3 trace is inherited.
## No unknown event is inserted into the frozen primary physical trace.
const DEADLINE_CAPACITY := 6000
var deadline_rows: Array[Dictionary] = []
var deadline_overflow := false
var deadline_proof: Dictionary = {}


func deadline_uploaded_identity() -> Dictionary:
	return {"serial":host.last_uploaded_render_snapshot_serial,
		"generation":host.last_uploaded_world_generation,
		"generated_usec":host.common_uploaded_generated_usec} if host != null else {}


func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	for path: String in ["res://tests/pubpres_final_deadline_gameplay.gd",
		"res://tests/pubpres_final_deadline_registration.json",
		"res://scripts/material_publication_deadline.gd"]:
		result.files[path] = FileAccess.get_sha256(path)
	return result


func effective_selectors() -> Dictionary:
	var result: Dictionary = super.effective_selectors()
	result.requested["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"] = OS.get_environment("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ")
	result["material_deadline"] = host.material_deadline_status()
	result["material_deadline_uploaded"] = deadline_uploaded_identity()
	result["material_deadline_observer"] = deadline_proof.duplicate(true)
	return result


func draw_observed() -> void:
	super.draw_observed()
	if host == null or not host.common_active or not host.common_detailed:
		return
	if deadline_rows.size() >= DEADLINE_CAPACITY:
		deadline_overflow = true
		return
	var started := Time.get_ticks_usec()
	# The inherited hook just appended this actual draw notification. Reading
	# its record binds the supplementary poll to that notification without a
	# guessed display identity or another renderer/GPU query.
	var draw: Dictionary = host.common_events.back()
	if draw.get("event","") != "framebuffer_draw":
		deadline_overflow = true
		return
	var status: Dictionary = host.material_deadline_status()
	var observed := Time.get_ticks_usec()
	deadline_rows.append({"event":"material_deadline_delivery", "time_usec":observed,
		"delivered_draw_usec":draw.time_usec, "process_frame":draw.process_frame,
		"rendered_frames":draw.rendered_frames, "inline_main":draw.inline_main,
		"draw_render_serial":draw.render_serial,
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation,
		"uploaded_generated_usec":host.common_uploaded_generated_usec,
		"observer_usec":observed-started, "status":status})


func finish() -> void:
	# Capture the policy counters before the parent's out-of-timing pause,
	# framebuffer reads and teardown can produce another material consumption.
	var status: Dictionary = host.material_deadline_status() if host != null else {}
	var path := output.trim_suffix(".json") + "-deadline-events.jsonl"
	var header := {"event":"material_deadline_identity", "schema":"pubpres-material-deadline-observer-v1",
		"source":source_before, "case_nonce":OS.get_environment("CYBERSAND_SHADER_NONCE"),
		"capture_start_usec":capture_start, "capture_end_usec":capture_end,
		"start_status":selectors_before.get("material_deadline",{}), "end_status":status,
		"start_material":selectors_before.get("material_deadline_uploaded",{}),
		"end_material":deadline_uploaded_identity(),
		"maximum_samples":DEADLINE_CAPACITY, "overflow":deadline_overflow,
		"samples":deadline_rows.size(),
		"clock_scope":"Status poll following delivered Main frame_post_draw, not a GPU fence or scanout. Pending samples are observed deferral opportunities, not completed physical work."}
	check(not deadline_overflow,"bounded material deadline observer retained every poll")
	var writer := FileAccess.open(path,FileAccess.WRITE)
	if writer == null:
		check(false,"material deadline trace could not be written")
	else:
		writer.store_line(JSON.stringify(header))
		for row: Dictionary in deadline_rows:
			writer.store_line(JSON.stringify(row))
		writer.close()
		deadline_proof = {"schema":"pubpres-material-deadline-sidecar-v1", "path":path,
			"sha256":FileAccess.get_sha256(path), "samples":deadline_rows.size(),
			"maximum_samples":DEADLINE_CAPACITY, "overflow":deadline_overflow}
	await super.finish()
