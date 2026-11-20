extends "res://tests/run_engine_lab_physical_test_it.gd"

## Retain bounded, real task claims alongside the donor's real-Needle tape.
## The worker query is identical in every arm and has a 4 Hz source-side cap.
const MaxParticipationSamples := 400

var _sampling_enabled := false
var _participation: Array[Dictionary] = []
var _last_sample := -1
var _sampling_overflow := false
var _wave_requested := false
var _wave_start: Dictionary = {}
var _wave_end: Dictionary = {}
var _wave_observed_tasks := 0
var _wave_observed_participants := 0


func _initialize() -> void:
	_wave_requested = "--water-law=wave_flow_v1" in OS.get_cmdline_user_args()
	super._initialize()
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION", presentation_mode)


func _run() -> void:
	process_frame.connect(_observe_participation)
	await super._run()


func _policy(ui: Control) -> PackedInt32Array:
	var carrier := super._policy(ui)
	if _wave_requested and not carrier.is_empty():
		if not check(family == "freemass", "Wave Flow uses the accepted FreeMass carrier"):
			return PackedInt32Array()
		# The donor's fresh authored Apply already accepts staged Water options.
		# This test-only, typed request reaches ordinary native construction.
		host.workbench_water_options["workbench_wave_flow"] = true
	return carrier


func _wave_identity() -> Dictionary:
	if host == null or not is_instance_valid(host) or host.latest_snapshot == null:
		return {}
	var wave: Dictionary = host.tower_context.get("wave_flow", {})
	var construction: Dictionary = host.tower_context.get("liquid_construction_receipt", {})
	var policy: Dictionary = host.tower_context.get("liquid_solver_policy", {})
	return {"enabled": wave.get("enabled",false), "healthy": wave.get("healthy",false),
		"water_solver": policy.get("effective_water_solver",""), "construction_kind": construction.get("kind",""),
		"receipt_hash": construction.get("receipt_hash",""), "construction_wave": construction.get("wave_flow",{}).get("enabled",false),
		"generation": host.latest_snapshot.render_world_generation, "ticks": wave.get("ticks",0),
		"rounds": wave.get("rounds",0), "substeps": wave.get("substeps",0),
		"last_tasks": wave.get("last_tasks",0), "maximum_participants": wave.get("maximum_participants",0),
		"water_quantity": wave.get("water_quantity","0")}


func _ready_upload() -> bool:
	if not super._ready_upload():
		return false
	if _wave_requested:
		_wave_start = _wave_identity()
		return _wave_start.get("enabled",false) and _wave_start.get("construction_wave",false) \
			and _wave_start.get("water_solver","") == "wave_flow_v1"
	return true


func _finish(ui: Control) -> void:
	if _wave_requested and capture_start_usec > 0:
		_wave_end = _wave_identity()
		if check(not _wave_start.is_empty() and not _wave_end.is_empty(), "native Wave Flow identity readback"):
			var ticks := int(_wave_end.ticks) - int(_wave_start.ticks)
			var rounds := int(_wave_end.rounds) - int(_wave_start.rounds)
			check(_wave_end.enabled and _wave_end.healthy and _wave_end.water_solver == "wave_flow_v1"
				and _wave_end.generation == _wave_start.generation and _wave_end.receipt_hash == _wave_start.receipt_hash,
				"source-qualified native Wave Flow stayed active on the measured World")
			check(ticks > 0 and int(_wave_end.substeps) > 0 and rounds == ticks * int(_wave_end.substeps)
				and int(_wave_start.water_quantity) > 0 and _wave_observed_tasks > 0 and _wave_observed_participants > 0,
				"actual Wave Flow tick, substep and native task progression")
	await super._finish(ui)


func _observe_participation() -> void:
	if host == null or not is_instance_valid(host):
		return
	if not _sampling_enabled:
		host.simulation_worker.set_worker_participation_sampling(true)
		_sampling_enabled = true
	if capture_start_usec <= 0 or capture_end_usec > 0 or host.latest_snapshot == null:
		return
	if _wave_requested and host.latest_snapshot.render_world_generation == int(_wave_start.get("generation",-1)):
		var wave: Dictionary = host.tower_context.get("wave_flow", {})
		if int(wave.get("ticks",0)) > int(_wave_start.ticks):
			_wave_observed_tasks = maxi(_wave_observed_tasks, int(wave.get("last_tasks",0)))
			_wave_observed_participants = maxi(_wave_observed_participants, int(wave.get("maximum_participants",0)))
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
	if _wave_requested:
		result["wave_flow"] = {"before": _wave_start, "after": _wave_end, "carrier": "freemass_v1",
			"observed_tasks": _wave_observed_tasks, "observed_participants": _wave_observed_participants}
	if host != null and is_instance_valid(host):
		result["process_id"] = OS.get_process_id()
		result["case_nonce"] = OS.get_environment("CYBERSAND_SHADER_NONCE")
		result["native_rendezvous"] = host.native_rendezvous_status()
		result["static_memory_peak_bytes"] = OS.get_static_memory_peak_usage()
		var video_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		result["reported_video_memory_bytes"] = video_bytes if video_bytes > 0 else null
		if capture_end_usec > 0:
			result["engine_sha256"] = FileAccess.get_sha256(OS.get_executable_path())
			result["setup_usec"] = capture_start_usec-started_usec
	return result
