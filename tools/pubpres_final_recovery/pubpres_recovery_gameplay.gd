extends "res://tests/pubpres_final_gameplay.gd"

# The physical/callback/native/input observer is inherited byte-for-byte. Only
# the presentation boundary changes: a committed transaction emits after its
# bookkeeping, avoiding frame_pre_draw signal-connection-order assumptions.
const MAX_TRANSACTIONS: int = 6000
var transaction_rows: Array[Dictionary] = []
var transaction_dropped: int = 0
var transaction_observer_usec: int = 0
var transaction_connected: bool = false


func _attach_submission_observer() -> void:
	if not presentation_enabled or transaction_connected or host == null: return
	if OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION") != "1": return
	if host.has_signal("workbench_presentation_submitted"):
		host.workbench_presentation_submitted.connect(_actual_submission)
		transaction_connected = true


func _presentation_pre_draw() -> void:
	if OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION") == "1":
		_attach_submission_observer()
	else:
		super._presentation_pre_draw()


func _actual_submission(frame: Dictionary) -> void:
	if host == null or not host.common_active or not host.common_detailed: return
	var began: int = Time.get_ticks_usec()
	if transaction_rows.size() >= MAX_TRANSACTIONS:
		transaction_dropped += 1
		transaction_observer_usec += Time.get_ticks_usec()-began
		return
	var probe_before: int = presentation_probe.submissions.size()
	var body_owner_available: bool = is_instance_valid(host.physical_actor_session)
	if body_owner_available: presentation_probe.observe_submission(host)
	var probe_index: int = probe_before if presentation_probe.submissions.size() == probe_before+1 else -1
	var status: Dictionary = host.workbench_presentation_submission_status()
	var row: Dictionary = {"index":transaction_rows.size(),"time_usec":began,
		"probe_index":probe_index,"body_owner_available":body_owner_available,
		"owner_instance":host.get_instance_id(),"source_revision":status.get("source_revision",""),
		"submission_serial":frame.get("submission_serial",-1),
		"candidate_serial":frame.get("candidate_serial",-1),
		"prepared_process_frame":frame.get("prepared_process_frame",-1),
		"submitted_process_frame":frame.get("submitted_process_frame",-1),
		"prepared_usec":frame.get("prepared_usec",-1),"submitted_usec":frame.get("submitted_usec",-1),
		"submission_scope":frame.get("submission_scope",""),
		"process_frame":Engine.get_process_frames(),"physical_tick":frame.get("rapier_step",-1),
		"committed_count":status.get("committed_count",-1),"prepared_count":status.get("prepared_count",-1),
		"superseded_count":status.get("superseded_count",-1),"rejected_count":status.get("rejected_count",-1),
		"render_serial":frame.get("upload_serial",-1),
		"world_generation":frame.get("world_generation",-1),"material_revision":frame.get("material_revision",-1)}
	for key: String in ["preparation_samples","preparation_total_usec","preparation_max_usec",
		"last_preparation_usec","last_preparation_candidate_serial"]:
		row[key] = status.get(key,-1)
	row["observer_usec"] = Time.get_ticks_usec()-began
	transaction_observer_usec += row.observer_usec
	transaction_rows.append(row)


func identity() -> Dictionary:
	var result: Dictionary = super.identity()
	for path: String in ["res://tests/pubpres_recovery_gameplay.gd",
		"res://scripts/workbench_presentation_submission.gd","res://scripts/workbench_water_composition.gd"]:
		result.files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else null
	return result


func effective_selectors() -> Dictionary:
	_attach_submission_observer()
	var result: Dictionary = super.effective_selectors()
	for key: String in ["CYBERSAND_DIAG_ACTUAL_SUBMISSION","CYBERSAND_DIAG_WATER_COMPOSITION",
		"CYBERSAND_ENGINE_RENDER_LOOKAHEAD","CYBERSAND_ENGINE_RENDER_LOOKAHEAD_TRACE"]:
		result.requested[key] = OS.get_environment(key)
	result["actual_submission"] = host.workbench_presentation_submission_status() \
		if host.has_method("workbench_presentation_submission_status") else null
	result["actual_submission_observer_connected"] = transaction_connected
	return result


func finish() -> void:
	if transaction_connected and is_instance_valid(host) \
		and host.workbench_presentation_submitted.is_connected(_actual_submission):
		host.workbench_presentation_submitted.disconnect(_actual_submission)
	if presentation_enabled and OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION") == "1":
		var data: Dictionary = {"schema":"pubpres-recovery-actual-submission-observer-v1",
			"source_identity":source_before,"process_id":OS.get_process_id(),
			"capture_start_usec":capture_start,"capture_end_usec":capture_end,
			"capacity":MAX_TRANSACTIONS,"dropped":transaction_dropped,
			"observer_total_usec":transaction_observer_usec,"rows":transaction_rows,
			"complete":transaction_connected and transaction_dropped == 0 and not transaction_rows.is_empty(),
			"scope":"Actual CPU draw admission and scalar source/owner join; no GPU completion, scanout or fabricated physics credit."}
		var file := FileAccess.open(output.trim_suffix(".json")+"-submissions.json",FileAccess.WRITE)
		check(file != null,"actual-submission sidecar opened")
		if file != null: file.store_string(JSON.stringify(data,"  ")+"\n")
		check(data.complete,"bounded actual-submission sidecar retained")
	await super.finish()
