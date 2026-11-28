extends "res://tests/pubpres_final_gameplay.gd"

## Read-only status at each actual inherited Main draw. The physical observer,
## sole worker, callback and application admission paths remain unchanged.
const STEPS_CAPACITY := 6000
var steps_rows: Array[Dictionary] = []
var steps_overflow := false
var steps_proof: Dictionary = {}


func steps_uploaded_identity() -> Dictionary:
	return {"serial":host.last_uploaded_render_snapshot_serial,
		"generation":host.last_uploaded_world_generation,
		"generated_usec":host.common_uploaded_generated_usec} if host != null else {}


func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	for path: String in ["res://tests/pubpres_final_material_steps_gameplay.gd",
		"res://tests/pubpres_final_material_steps_registration.json",
		"res://scripts/material_publication_steps.gd"]:
		result.files[path] = FileAccess.get_sha256(path)
	return result


func effective_selectors() -> Dictionary:
	var result: Dictionary = super.effective_selectors()
	result["material_steps_uploaded"] = steps_uploaded_identity()
	result["material_steps_observer"] = steps_proof.duplicate(true)
	return result


func draw_observed() -> void:
	super.draw_observed()
	if host == null or not host.common_active or not host.common_detailed:
		return
	if steps_rows.size() >= STEPS_CAPACITY:
		steps_overflow = true
		return
	var started := Time.get_ticks_usec()
	var draw: Dictionary = host.common_events.back()
	if draw.get("event","") != "framebuffer_draw":
		steps_overflow = true
		return
	var status: Dictionary = host.material_step_status()
	var observed := Time.get_ticks_usec()
	steps_rows.append({"event":"material_steps_delivery", "time_usec":observed,
		"delivered_draw_usec":draw.time_usec, "process_frame":draw.process_frame,
		"rendered_frames":draw.rendered_frames, "inline_main":draw.inline_main,
		"draw_render_serial":draw.render_serial,
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation,
		"uploaded_generated_usec":host.common_uploaded_generated_usec,
		"observer_usec":observed-started, "status":status})


func finish() -> void:
	# End counters precede the parent's pause, GPU checks and owner teardown.
	var status: Dictionary = host.material_step_status() if host != null else {}
	var path := output.trim_suffix(".json") + "-material-steps-events.jsonl"
	var header := {"event":"material_steps_identity", "schema":"pubpres-material-steps-observer-v1",
		"source":source_before, "case_nonce":OS.get_environment("CYBERSAND_SHADER_NONCE"),
		"capture_start_usec":capture_start, "capture_end_usec":capture_end,
		"start_status":selectors_before.get("material_steps",{}), "end_status":status,
		"start_material":selectors_before.get("material_steps_uploaded",{}),
		"end_material":steps_uploaded_identity(), "maximum_samples":STEPS_CAPACITY,
		"overflow":steps_overflow, "samples":steps_rows.size(),
		"clock_scope":"Read-only status following an actual inherited Safe Main draw delivery. Actual uploaded history and real V3 Rapier events are joined independently. This is neither GPU completion nor scanout; policy counters have no physical credit."}
	check(not steps_overflow,"bounded completed-step material observer retained every draw poll")
	var writer := FileAccess.open(path,FileAccess.WRITE)
	if writer == null:
		check(false,"completed-step material trace could not be written")
	else:
		writer.store_line(JSON.stringify(header))
		for row: Dictionary in steps_rows:
			writer.store_line(JSON.stringify(row))
		writer.close()
		steps_proof = {"schema":"pubpres-material-steps-sidecar-v1", "path":path,
			"sha256":FileAccess.get_sha256(path), "samples":steps_rows.size(),
			"maximum_samples":STEPS_CAPACITY, "overflow":steps_overflow}
	await super.finish()
