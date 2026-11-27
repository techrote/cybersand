extends RefCounted

# Owner evaluator only. Producers copy scalar values on Main. Only the writer
# thread formats JSON and opens, rotates, flushes or closes the files.
const DIRECTORY := "user://workbench/pubpres-gameplay"
const SEGMENTS := 4
const SEGMENT_BYTES := 2 * 1024 * 1024
const BODY_LIMIT := 32
const PART_SCAN_LIMIT := 256
const BATCH_ROWS := 32
const QUEUE_BATCHES := 4
const BATCH_USEC := 250000
const SCHEMA := "pubpres-owner-gameplay-v1"
const FIELDS := {
	"step":["type","usec","process_frame","physics_frame","session","epoch","physics_world","step","manual_steps","gap_usec","fixed_delta_sec","native_tick","worker_handoff_usec","native_completed_usec","completed_body_sample","solver_usec","flush_usec","single_step","selected_actor_instance","selected_root_body_slot","physical_xy","velocity_cells_per_sec","native_started_usec","native_tick_body_sample","native_tick_world","native_start_lateness_usec","first_physics_handoff_usec"],
	"hold":["type","usec","process_frame","physics_frame","session","epoch","physics_world","step","reason","paused","wanted_sample","completed_sample","native_tick","worker_handoff_usec","required_hard_revision","packet_hard_revision","queued_hard_revision","pending_chunks"],
	"upload":["type","completed_usec","start_usec","process_frame","world","revision","render_serial","material_tick","generated_usec","native_completed_usec","patch_bytes"],
	"presentation":["type","usec","process_frame","boundary","local_presentation_serial","submission_serial","session","epoch","material_world","revision","render_serial","material_tick","mask_sample_tick","physical_step","paused","camera_mode","camera_xy","view_wh","extent_wh","pilot_slot","whole_frame_valid","whole_frame_reason","resolve_usec","upload_cache_usec","total_bodies","total_parts","scanned_parts","bodies"],
	"body":["body_slot","body_instance","generation","actor_instance","actor_slot","part_index","selected_pose","overlay_part","source","reason","selected_step","selected_completed_usec","hold_age_usec","world_xy","inside_camera_center","selected_angle_rad","water_composed","flight_command_live","flight_desired_velocity_xy"],
	"draw":["type","usec","callback_process_frame","frames_drawn_at_delivery","render_thread_inline","inline_last_local_presentation_serial"],
	"loss":["type","last_drop_usec","first_drop_usec","dropped_counts_by_type"],
	"close":["type","usec"]
}

var _identity: Dictionary
var _where: String
var _thread := Thread.new()
var _lock := Mutex.new()
var _wake := Semaphore.new()
var _queue: Array = []
var _ending := false
var _batch: Array = []
var _last_transfer_usec := 0
var _loss_counts: Dictionary = {}
var _loss_first := 0
var _loss_last := 0
var _presentation_serial := 0
var _previous_session := -1
var _previous_epoch := -1
var _previous_world := -1
var _previous_completion := -1
var _selected_instance := -1
var _selected_root := -1


func start(owner_id: int) -> bool:
	var receipt := OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_RECEIPT")
	if receipt.is_empty(): return false
	_where = ProjectSettings.globalize_path(DIRECTORY)
	_identity = {"schema":SCHEMA,"launch_receipt":receipt.replace("\\","/").get_file(),
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scene":OS.get_environment("CYBERSAND_FINAL_SCENE"),"pid":OS.get_process_id(),
		"main_instance":owner_id,"start_usec":Time.get_ticks_usec(),"start_unix_sec":Time.get_unix_time_from_system(),
		"physics_ticks_per_second":Engine.physics_ticks_per_second}
	if _thread.start(_write_loop) != OK:
		push_warning("PUBPRES gameplay recorder could not start its writer")
		return false
	return true


func physics_step(host: Node, completed_usec: int, snapshot: CyberSimulationSnapshot, single_step: bool) -> void:
	var bridge: Variant = host.rapier_bridge
	var world: int = snapshot.physics_world_generation
	var same_owner: bool = bridge._session == _previous_session and bridge._epoch == _previous_epoch and world == _previous_world
	var gap := completed_usec - _previous_completion if same_owner else -1
	# Only a selection or ownership change needs the session's authored ID lookup.
	var selected_id: int = host.shared_workbench.selected_id()
	if not same_owner or _selected_instance != selected_id:
		_selected_instance = selected_id
		var selected_slot: int = host.physical_actor_session.slot_for_instance(selected_id)
		_selected_root = bridge.actor_body_index(selected_slot)
	_previous_session = bridge._session
	_previous_epoch = bridge._epoch
	_previous_world = world
	_previous_completion = completed_usec
	var xy: Variant = null
	var velocity: Variant = null
	if _selected_root >= 0:
		var physical: Transform2D = bridge.body_transform(_selected_root)
		var linear: Vector2 = bridge.body_linear_velocity(_selected_root)
		xy = [physical.origin.x,physical.origin.y]
		velocity = [linear.x,linear.y]
	_append(["step",completed_usec,Engine.get_process_frames(),Engine.get_physics_frames(),bridge._session,
		bridge._epoch,world,host.physical_actor_session.tick,bridge.manual_step_count(),gap,bridge.fixed_delta(),
		snapshot.tick_index,snapshot.physics_handoff_usec,snapshot.last_native_tick_completed_usec,
		snapshot.lab_context.get("workbench_completed_sample",-1),roundi(bridge.last_step_time_ms()*1000.0),
		roundi(bridge.last_flush_time_ms()*1000.0),single_step,selected_id,_selected_root,xy,velocity,
		snapshot.last_native_tick_started_usec,snapshot.last_native_tick_body_sample,snapshot.last_native_tick_world_generation,
		snapshot.last_native_tick_lateness_usec,snapshot.first_physics_handoff_usec])


func physics_hold(host: Node, reason: String, snapshot: CyberSimulationSnapshot) -> void:
	var session: Variant = host.physical_actor_session
	var context: Dictionary = snapshot.lab_context if snapshot != null else {}
	_append(["hold",Time.get_ticks_usec(),Engine.get_process_frames(),Engine.get_physics_frames(),
		session.bridge._session if session != null else -1,host._physical_epoch,
		snapshot.physics_world_generation if snapshot != null else -1,session.tick if session != null else -1,
		reason,host.paused,host._workbench_wait_sample,context.get("workbench_completed_sample",-1),
		snapshot.tick_index if snapshot != null else -1,snapshot.physics_handoff_usec if snapshot != null else -1,
		context.get("workbench_hard_surface_revision",-1),snapshot.hard_surface_revision if snapshot != null else -1,
		host.last_hard_surface_revision,host.rapier_bridge.pending_hard_surface_chunks()])


func upload(packet: Dictionary) -> void:
	_append(["upload",packet.completed_usec,packet.start_usec,Engine.get_process_frames(),packet.world_generation,
		packet.revision,packet.render_serial,packet.native_tick,packet.generated_usec,packet.native_completed_usec,packet.patch_bytes])


func presentation(host: Node, frame: Dictionary, boundary: String) -> void:
	var session: Variant = host.physical_actor_session
	var members: Array = session.bridge._members if session != null and session.bridge._session == frame.session \
		and session.bridge._epoch == frame.epoch else []
	var parts: Array = frame.parts
	var scanned := mini(parts.size(),PART_SCAN_LIMIT)
	var drawn := {}
	for i in range(scanned):
		var part: Dictionary = parts[i]
		var slot := int(part.get("physical_body_index",part.get("water_body_index",-1)))
		if slot >= 0: drawn[slot] = part
	var bodies := []
	var camera := Vector2(frame.camera_origin)
	var view := Vector2i(frame.view_size)
	var camera_rect := Rect2(camera,Vector2(view))
	for slot in range(mini(members.size(),BODY_LIMIT)):
		var member: Dictionary = members[slot]
		var pose: Variant = frame.poses.get(slot)
		var selected := pose is Transform2D
		var observed: Dictionary = frame.selected_observations.get(slot,{})
		var part_status := 1 if drawn.has(slot) else (0 if scanned == parts.size() else -1)
		var first_part: Dictionary = drawn.get(slot,{})
		var intent: Variant = first_part.get("flight_intent")
		bodies.append([slot,member.instance_id,member.generation,member.actor_instance_id,member.actor_slot,
			member.part_index,selected,part_status,frame.sources.get(slot,"hidden"),
			frame.reasons.get(slot,frame.reason),frame.selected_steps.get(slot,-1),
			observed.get("completed_usec",-1),frame.hold_age_usec.get(slot,-1),
			[pose.origin.x,pose.origin.y] if selected else null,camera_rect.has_point(pose.origin) if selected else null,
			pose.get_rotation() if selected else null,frame.water_proofs.has(slot),
			first_part.get("flight_live"),[intent.x,intent.y] if intent is Vector2 else null])
	_presentation_serial += 1
	_append(["presentation",Time.get_ticks_usec(),Engine.get_process_frames(),boundary,_presentation_serial,frame.get("submission_serial",-1),
		frame.session,frame.epoch,frame.world_generation,frame.material_revision,frame.upload_serial,
		frame.material_native_tick,frame.mask_sample_tick,frame.rapier_step,host.paused,host.shared_workbench._camera.selected,
		[camera.x,camera.y],[view.x,view.y],[host.world_extent.x,host.world_extent.y],host.shared_workbench.pilot_slot,
		frame.valid,frame.reason,frame.resolve_usec,frame.upload_cache_usec,members.size(),parts.size(),scanned,bodies])


func draw() -> void:
	var inline_render := RenderingServer.is_on_render_thread()
	_append(["draw",Time.get_ticks_usec(),Engine.get_process_frames(),Engine.get_frames_drawn(),inline_render,
		_presentation_serial if inline_render and _presentation_serial > 0 else -1])


func close() -> void:
	var closed_usec := Time.get_ticks_usec()
	_lock.lock()
	if not _loss_counts.is_empty(): _batch.append(_loss_row())
	_batch.append(["close",closed_usec])
	_queue.append(_batch)
	_batch = []
	_ending = true
	_lock.unlock()
	_wake.post()
	_thread.wait_to_finish()


func _loss_row() -> Array:
	var counts := _loss_counts
	_loss_counts = {}
	return ["loss",_loss_last,_loss_first,counts]


func _append(row: Array) -> void:
	var now := int(row[1])
	if _batch.size() >= BATCH_ROWS or now - _last_transfer_usec >= BATCH_USEC:
		if _lock.try_lock():
			if not _batch.is_empty() and _queue.size() < QUEUE_BATCHES:
				if not _loss_counts.is_empty(): _batch.append(_loss_row())
				_queue.append(_batch)
				_batch = []
				_last_transfer_usec = now
				_wake.post()
			_lock.unlock()
	if _batch.size() < BATCH_ROWS:
		_batch.append(row)
	else:
		if _loss_counts.is_empty(): _loss_first = now
		_loss_last = now
		_loss_counts[row[0]] = int(_loss_counts.get(row[0],0))+1


func _segment_path(sequence: int) -> String:
	return _where.path_join("segment-%d.jsonl" % (sequence % SEGMENTS))


func _next_sequence() -> int:
	var highest := -1
	for slot in range(SEGMENTS):
		var path := _segment_path(slot)
		if not FileAccess.file_exists(path): continue
		var prior := FileAccess.open(path,FileAccess.READ)
		if prior == null: continue
		var header: Variant = JSON.parse_string(prior.get_buffer(2048).get_string_from_utf8().get_slice("\n",0))
		if header is Dictionary and header.get("schema") == SCHEMA:
			highest = maxi(highest,int(header.get("sequence",-1)))
		prior.close()
	return highest+1


func _open_segment(sequence: int) -> FileAccess:
	var file := FileAccess.open(_segment_path(sequence),FileAccess.WRITE)
	if file == null: return null
	var header := _identity.duplicate()
	header["sequence"] = sequence
	file.store_line(JSON.stringify(header))
	file.store_line(JSON.stringify({"fields":FIELDS,"body_limit":BODY_LIMIT,"segment_bytes":SEGMENT_BYTES,
		"segment_count":SEGMENTS,"timestamps":"Godot monotonic microseconds since process start",
		"scope":"Stock applies overlay on Main. Atomic records accepted submission. Draw signals are CPU delivery; deferred delivery has no exact draw-to-frame identity. Overlay inclusion is upstream of clipping, material occlusion and physical scanout."}))
	file.flush()
	return file


func _write_loop() -> void:
	var ok := DirAccess.make_dir_recursive_absolute(_where) == OK
	var sequence := _next_sequence() if ok else 0
	var file := _open_segment(sequence) if ok else null
	if file == null: push_warning("PUBPRES gameplay recorder could not open "+_where)
	while true:
		_wake.wait()
		_lock.lock()
		var pending := _queue
		_queue = []
		var ending := _ending
		_lock.unlock()
		for batch: Array in pending:
			for row: Array in batch:
				if file == null: break
				var bytes := (JSON.stringify(row)+"\n").to_utf8_buffer()
				if file.get_position()+bytes.size() > SEGMENT_BYTES:
					file.close()
					sequence += 1
					file = _open_segment(sequence)
					if file == null:
						push_warning("PUBPRES gameplay recorder could not rotate "+_where)
						break
				if not file.store_buffer(bytes):
					push_warning("PUBPRES gameplay recorder write failed in "+_where)
					file.close()
					file = null
					break
		if file != null and not pending.is_empty(): file.flush()
		if ending: break
	if file != null: file.close()
