extends "res://tests/run_engine_lab_physical_test_it.gd"

## Retain bounded, real task claims alongside the donor's real-Needle tape.
## The worker query is identical in every arm and has a 4 Hz source-side cap.
const MaxParticipationSamples := 400

var _sampling_enabled := false
var _participation: Array[Dictionary] = []
var _last_sample := -1
var _sampling_overflow := false


func _initialize() -> void:
	super._initialize()
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION", presentation_mode)


func _run() -> void:
	process_frame.connect(_observe_participation)
	await super._run()


func _observe_participation() -> void:
	if host == null or not is_instance_valid(host):
		return
	if not _sampling_enabled:
		host.simulation_worker.set_worker_participation_sampling(true)
		_sampling_enabled = true
	if capture_start_usec <= 0 or capture_end_usec > 0 or host.latest_snapshot == null:
		return
	var sample: Dictionary = host.latest_snapshot.native_worker_participation
	var sequence := int(sample.get("sequence", -1))
	if sequence <= _last_sample or int(sample.get("sampled_usec", -1)) < capture_start_usec:
		return
	_last_sample = sequence
	if _participation.size() == MaxParticipationSamples:
		_sampling_overflow = true
		return
	_participation.append(sample)


func _native_worker_identity() -> Dictionary:
	var result := super._native_worker_identity()
	result["completed_task_participation"] = _participation.duplicate()
	result["participation_overflow"] = _sampling_overflow
	if host != null and is_instance_valid(host):
		result["process_id"] = OS.get_process_id()
		result["case_nonce"] = OS.get_environment("CYBERSAND_SHADER_NONCE")
		result["native_rendezvous"] = host.native_rendezvous_status()
		result["static_memory_peak_bytes"] = OS.get_static_memory_peak_usage()
		result["reported_video_memory_bytes"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		if capture_end_usec > 0:
			result["engine_sha256"] = FileAccess.get_sha256(OS.get_executable_path())
	return result
