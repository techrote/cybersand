extends RefCounted

# Experimental, default-off scheduling only. Godot still owns the callback
# count; this helper neither issues a physics step nor accumulates time debt.
# All callbacks in one process frame share ONE finite wall deadline. The
# optional render-overlap policy waits only while a prior render-queue marker
# remains pending. It never supplies a new callback or physical time debt.
# The caller must repeat its ordinary owner/terrain/feedback checks afterwards.
const MAX_FRAME_WAIT_USEC: int = 16667
const MAX_RENDER_OVERLAP_WAIT_USEC: int = 66667
const POLL_USEC: int = 250

var process_frame: int = -1
var callback_count: int = 0
var deadline_usec: int = 0
var total_wait_usec: int = 0
var render_overlap: bool = false
var _render_marker: Semaphore
var _render_marker_frame: int = -1
var _render_marker_complete: bool = false
var _render_marker_queued_usec: int = 0
var _render_marker_observed_complete_usec: int = 0
var _render_marker_state: String = "disabled"


static func retained_native_post(marker: Semaphore) -> Callable:
	# A standard Callable stores ObjectID, not a strong RefCounted reference.
	# The outer native bind owns a Variant reference to this Semaphore; the
	# inner native unbind removes that lease argument before Semaphore.post().
	# RenderingServer owns the copied callable until it returns. No GDScript,
	# helper state or scene object is invoked on the rendering thread, and
	# retiring this helper cannot destroy the pending callback's target.
	return marker.post.unbind(1).bind(marker)


func _separate_render_thread() -> bool:
	return not RenderingServer.is_on_render_thread()


func _queue_render_marker(callback: Callable) -> void:
	RenderingServer.call_on_render_thread(callback)


func _observe_render_marker() -> bool:
	if not _render_marker_complete and _render_marker != null and _render_marker.try_wait():
		_render_marker_complete = true
		_render_marker_observed_complete_usec = Time.get_ticks_usec()
	return _render_marker_complete


func _begin_render_overlap() -> void:
	_render_marker_state = "render_unavailable"
	# Safe mode executes call_on_render_thread inline and offers no overlap.
	# It must neither enqueue a marker nor gain a blocking window.
	if not _separate_render_thread(): return
	if _render_marker != null and not _observe_render_marker():
		# Godot's unconditional per-iteration sync normally makes this
		# impossible. Still retain only ONE outstanding marker if a caller
		# advances the frame identity without draining the render queue.
		_render_marker_state = "render_marker_backlog"
		return
	_render_marker = Semaphore.new()
	_render_marker_frame = process_frame
	_render_marker_complete = false
	_render_marker_observed_complete_usec = 0
	_render_marker_queued_usec = Time.get_ticks_usec()
	_render_marker_state = "pending"
	_queue_render_marker(retained_native_post(_render_marker))


func _render_wait_state() -> String:
	if _render_marker_state != "pending": return _render_marker_state
	if _render_marker_frame != process_frame: return "render_marker_backlog"
	if _observe_render_marker(): return "render_complete"
	return "pending"


func begin_callback(frame: int, overlap: bool = false) -> void:
	if frame != process_frame:
		process_frame = frame
		callback_count = 0
		deadline_usec = 0
		total_wait_usec = 0
		render_overlap = overlap
		if render_overlap: _begin_render_overlap()
	callback_count += 1


func _completion_time_usec() -> int:
	# Separate seam permits deterministic tests at the final decision boundary.
	# Production continues to use the same monotonic wall clock.
	return Time.get_ticks_usec()


func wait_for_sample(poll_mailbox: Callable, expected: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result := {"status":"not_catchup", "start_usec":started,
		"completed_usec":started, "deadline_usec":deadline_usec,
		"process_frame":process_frame, "callback_index":callback_count,
		"polls":0, "sleeps":0, "requested_sleep_usec":0, "lock_misses":0,
		"frame_wait_usec":total_wait_usec,
		"mode":"render-overlap" if render_overlap else "fixed16",
		"render_marker_frame":_render_marker_frame if render_overlap else -1,
		"render_marker_id":_render_marker.get_instance_id() if render_overlap and _render_marker != null else 0,
		"render_marker_queued_usec":_render_marker_queued_usec if render_overlap else 0,
		"render_marker_observed_complete_usec":_render_marker_observed_complete_usec if render_overlap else 0}
	# A lone ordinary callback never gains an artificial blocking period.
	if callback_count < 2: return result
	if render_overlap:
		var render_state: String = _render_wait_state()
		if render_state != "pending":
			result.status = render_state
			result.completed_usec = Time.get_ticks_usec()
			result.render_marker_observed_complete_usec = _render_marker_observed_complete_usec
			return result
	if deadline_usec == 0:
		deadline_usec = started + (MAX_RENDER_OVERLAP_WAIT_USEC if render_overlap else MAX_FRAME_WAIT_USEC)
	result.deadline_usec = deadline_usec
	result.status = "timeout"
	while Time.get_ticks_usec() < deadline_usec:
		if render_overlap and _render_wait_state() != "pending":
			result.status = "render_complete"
			break
		# The worker method uses try_lock; this helper never waits on its mutex.
		var observed: Dictionary = poll_mailbox.call()
		result.polls += 1
		# An OS pause or an unexpectedly slow reader cannot turn an expired
		# window into a successful wait. A later real callback may use it.
		if Time.get_ticks_usec() >= deadline_usec: break
		# A native queue receipt is only a point where earlier rendering calls
		# have returned, not GPU completion or a specific presented frame. Stop
		# adding wait as soon as that receipt is observed, even if the mailbox
		# became ready during the same read; a later callback can use it.
		if render_overlap and _render_wait_state() != "pending":
			result.status = "render_complete"
			break
		var state: String = str(observed.get("status", "invalid"))
		if state == "contended":
			result.lock_misses += 1
		elif state != "active":
			result.status = state
			break
		elif int(observed.get("epoch", -1)) != int(expected.epoch) \
				or int(observed.get("session", -1)) != int(expected.session):
			result.status = "owner_changed"
			break
		else:
			var snapshot: CyberSimulationSnapshot = observed.get("snapshot")
			if snapshot == null:
				result.status = "retired"
				break
			if snapshot.simulation_failed:
				result.status = "failed"
				break
			if snapshot.rigid_body_epoch != int(expected.epoch) \
					or snapshot.physics_world_generation != int(expected.world_generation):
				result.status = "owner_changed"
				break
			if not str(snapshot.lab_context.get("workbench_refusal", "")).is_empty():
				result.status = "native_refusal"
				break
			# snapshot.paused may be a worker status turn with no NEW sample;
			# user pause/transition is reported separately by the mailbox owner.
			if int(snapshot.lab_context.get("workbench_completed_sample", -1)) == int(expected.sample):
				var packet: Dictionary = snapshot.lab_context.get("workbench_gcr", {})
				if int(packet.get("epoch", -1)) != int(expected.epoch) \
						or int(packet.get("session", -1)) != int(expected.session) \
						or not packet.get("valid", false):
					result.status = "native_refusal"
					break
				# sample_tick is a native World tick, not the body serial. Each
				# response row must carry the exact awaited physical sample.
				var rows: Variant = packet.get("rows")
				var exact_sample: bool = rows is Array and not rows.is_empty()
				if exact_sample:
					for row: Variant in rows:
						if not row is Dictionary or int(row.get("sample", -1)) != int(expected.sample):
							exact_sample = false
							break
				if not exact_sample:
					result.status = "native_refusal"
					break
				result.status = "ready"
				result["snapshot"] = snapshot
				break
		var remaining: int = deadline_usec - Time.get_ticks_usec()
		if remaining <= 0: break
		if render_overlap and _render_wait_state() != "pending":
			result.status = "render_complete"
			break
		var delay: int = mini(POLL_USEC, remaining)
		# Godot4.7's script Semaphore has no timed wait. Sleeping between these
		# nonblocking reads yields CPU to the native owner and render thread.
		# OS descheduling can exceed the requested deadline; retain actual time.
		OS.delay_usec(delay)
		result.sleeps += 1
		result.requested_sleep_usec += delay
	result.completed_usec = _completion_time_usec()
	# Row validation itself can cross the shared deadline after the earlier
	# mailbox-read check. Refuse that completion at the final captured decision
	# time; a later genuine callback may consume the same immutable snapshot.
	# OS preemption after this capture remains possible and is not a hard
	# real-time guarantee about the instant control returns to Main.
	if result.status == "ready" and int(result.completed_usec) >= deadline_usec:
		result.status = "timeout"
		result.erase("snapshot")
	if render_overlap:
		result.render_marker_observed_complete_usec = _render_marker_observed_complete_usec
	total_wait_usec += int(result.completed_usec) - started
	result.frame_wait_usec = total_wait_usec
	return result
