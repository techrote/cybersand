extends Node

# One Main-owned prepared value, consumed by engine admission after the flush
# and before any draw signal/token. frame_pre_draw only notifies the acceptance.
# This CPU journal never grants physical steps, claims render-owner return/GPU
# completion, or waits on a rendering resource.
const META: StringName = &"cybersand_actual_submission_v1"
const SCHEMA: String = "pubpres-actual-submission-v1"
const ATOMIC_META: StringName = &"cybersand_actual_submission_v2"
const ATOMIC_SCHEMA: String = "cybersand-actual-submission-v2"
const PREPARE_PRIORITY: int = 100000
var host: Node
var candidate: Dictionary = {}
var prepared_count: int = 0
var committed_count: int = 0
var superseded_count: int = 0
var rejected_count: int = 0
var unprepared_attempts: int = 0
var admission_attempts: int = 0
var preparation_samples: int = 0
var preparation_total_usec: int = 0
var preparation_max_usec: int = 0
var last_preparation_usec: int = 0
var last_preparation_candidate_serial: int = 0
var last_rejection: String = ""
var source_revision: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
var _alive: bool = true
var _flushed_candidate_serial: int = 0


func bind(owner: Node) -> void:
	host = owner
	process_priority = PREPARE_PRIORITY
	# This late idle callback runs after ordinary Workbench/UI processing but
	# before Main's message flush. Canvas queue_redraw and shader/node updates
	# are therefore already staged when the engine calls actual draw admission.
	process_mode = Node.PROCESS_MODE_INHERIT


func _process(delta: float) -> void:
	if _alive and is_instance_valid(host) and host.is_processing() \
			and host.shared_workbench != null:
		host._prepare_workbench_presentation_candidate(delta)


static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: freeze(child)
		value.make_read_only()


static func atomic_admission_supported() -> bool:
	var capability: Variant = RenderingServer.get_meta(ATOMIC_META,{})
	return capability is Dictionary and capability.get("schema",null) is String \
		and capability.schema == ATOMIC_SCHEMA \
		and capability.get("engine_owned_admission",null) is bool \
		and capability.engine_owned_admission


static func revision_is_valid(revision: String) -> bool:
	if revision.length() != 40: return false
	for code: int in revision.to_ascii_buffer():
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)): return false
	return true


func source_valid() -> bool:
	return revision_is_valid(source_revision) and OS.get_environment("CYBERSAND_SOURCE_REVISION") == source_revision


func connected() -> bool:
	return _alive and is_instance_valid(host) and host.is_inside_tree() \
		and RenderingServer.frame_pre_draw.is_connected(host._commit_workbench_presentation_submission)


func stage(frame: Dictionary, next_state: Dictionary, fence: Dictionary) -> void:
	if not candidate.is_empty(): superseded_count += 1
	prepared_count += 1
	var copied: Dictionary = frame.duplicate(true)
	copied["candidate_serial"] = prepared_count
	copied["prepared_process_frame"] = Engine.get_process_frames()
	copied["prepared_usec"] = Time.get_ticks_usec()
	candidate = {"frame":copied,"next_state":next_state.duplicate(true),
		"fence":fence.duplicate(true)}
	freeze(candidate)
	_flushed_candidate_serial = 0
	_publish_handshake()
	# This marker follows ALL staged CanvasItem queue_redraw callbacks. A manual
	# force_draw from an earlier process/deferred callback cannot admit a journal
	# for canvas commands that Main has not flushed yet. Superseded markers are
	# ignored, so an older candidate cannot certify its replacement's commands.
	_mark_candidate_flushed.call_deferred(prepared_count)


func _mark_candidate_flushed(serial: int) -> void:
	if not _alive or candidate.is_empty() or int(candidate.frame.candidate_serial) != serial: return
	if int(candidate.frame.prepared_process_frame) != Engine.get_process_frames():
		retire("flush_process_frame_changed")
		return
	_flushed_candidate_serial = serial
	_publish_handshake()


func candidate_ready() -> bool:
	return not candidate.is_empty() and source_valid() \
		and _flushed_candidate_serial == int(candidate.frame.candidate_serial)


func record_preparation_cost(elapsed_usec: int) -> void:
	# Counts real CPU preparation, including superseded/refused work. These
	# scalar costs grant no draw, physical or fairness credit and perform no I/O.
	preparation_samples += 1
	last_preparation_usec = maxi(0,elapsed_usec)
	last_preparation_candidate_serial = prepared_count
	preparation_total_usec += last_preparation_usec
	preparation_max_usec = maxi(preparation_max_usec,last_preparation_usec)


func take(current_fence: Dictionary) -> Dictionary:
	admission_attempts += 1
	if candidate.is_empty():
		unprepared_attempts += 1
		_publish_handshake()
		return {}
	var staged: Dictionary = candidate
	candidate = {}
	var refusal: String = ""
	if not connected(): refusal = "owner_retired"
	elif not atomic_admission_supported(): refusal = "atomic_admission_unavailable"
	elif not source_valid(): refusal = "source_identity_invalid"
	elif _flushed_candidate_serial != int(staged.frame.candidate_serial): refusal = "candidate_not_flushed"
	elif int(staged.frame.prepared_process_frame) != Engine.get_process_frames(): refusal = "process_frame_changed"
	else:
		# Exact values, not inferred pose age or a render notification from a
		# different frame. All relevant authority/mapping identities are captured
		# after staging and compared again on Main at actual admission.
		for key: String in staged.fence:
			if not current_fence.has(key) or current_fence[key] != staged.fence[key]:
				refusal = key+"_changed"
				break
	if not refusal.is_empty():
		rejected_count += 1
		last_rejection = refusal
		_publish_handshake()
		return {}
	committed_count += 1
	var accepted: Dictionary = staged.duplicate(true)
	accepted.frame["submission_serial"] = committed_count
	accepted.frame["submitted_process_frame"] = Engine.get_process_frames()
	accepted.frame["submitted_usec"] = Time.get_ticks_usec()
	accepted.frame["submission_scope"] = "actual_cpu_draw_admission_no_gpu_or_display_completion"
	freeze(accepted.frame)
	last_rejection = ""
	_publish_handshake()
	return accepted


func retire(reason: String) -> void:
	if not candidate.is_empty():
		rejected_count += 1
		last_rejection = reason
	candidate = {}
	_flushed_candidate_serial = 0
	_publish_handshake()


func close() -> void:
	retire("owner_retired")
	_alive = false
	if is_instance_valid(host) and RenderingServer.frame_pre_draw.is_connected(host._commit_workbench_presentation_submission):
		RenderingServer.frame_pre_draw.disconnect(host._commit_workbench_presentation_submission)
	# A retiring owner cannot erase a replacement owner's handshake.
	var previous: Variant = RenderingServer.get_meta(META,{})
	if previous is Dictionary and int(previous.get("owner_instance",0)) == host.get_instance_id():
		RenderingServer.remove_meta(META)
	set_process(false)


func _publish_handshake() -> void:
	if not is_instance_valid(host): return
	var metadata: Dictionary = {"schema":SCHEMA,"enabled":_alive,"connected":connected(),
		"candidate_ready":candidate_ready(),
		"owner_instance":host.get_instance_id(),"source_revision":source_revision,
		"process_frame":Engine.get_process_frames()}
	metadata.make_read_only()
	RenderingServer.set_meta(META,metadata)


func status() -> Dictionary:
	return {"schema":SCHEMA,"enabled":_alive,"connected":connected(),
		"candidate_ready":candidate_ready(),"flushed_candidate_serial":_flushed_candidate_serial,
		"owner_instance":host.get_instance_id() if is_instance_valid(host) else 0,
		"source_revision":source_revision,"source_valid":source_valid(),
		"process_frame":Engine.get_process_frames(),"prepared_count":prepared_count,
		"committed_count":committed_count,"superseded_count":superseded_count,
		"rejected_count":rejected_count,"unprepared_attempts":unprepared_attempts,
		"preparation_samples":preparation_samples,"preparation_total_usec":preparation_total_usec,
		"preparation_max_usec":preparation_max_usec,"last_preparation_usec":last_preparation_usec,
		"last_preparation_candidate_serial":last_preparation_candidate_serial,
		"admission_attempts":admission_attempts,"engine_atomic_admission":atomic_admission_supported(),
		"last_rejection":last_rejection}
