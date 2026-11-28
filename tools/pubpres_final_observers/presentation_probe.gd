extends RefCounted

## Opt-in read-only evidence. A frame_pre_draw callback runs on Main before
## Godot queues Separate draw or executes Safe draw. Inspect the actual overlay
## copy and its already selected presentation state; never query World or step
## PhysicsServer. No hashing, logging or file IO occurs in the frame path.
const MAX_SUBMISSIONS: int = 6000
const MAX_NOTIFICATIONS: int = 6000
const MAX_BODIES: int = 8
const MAX_PARTS: int = 512
var submissions: Array[Dictionary] = []
var notifications: Array[Dictionary] = []
var dropped_submissions: int = 0
var dropped_notifications: int = 0
var invalid_samples: int = 0
var observer_total_usec: int = 0
var observer_max_usec: int = 0
var _last_submission_index: int = -1
var _last_process_frame: int = -1


static func _xy(value: Variant) -> Variant:
	return [value.x,value.y] if value is Vector2 and value.is_finite() else null


static func _pose(value: Variant) -> Variant:
	if not value is Transform2D or not value.is_finite(): return null
	return {"xy":[value.origin.x,value.origin.y],"angle":value.get_rotation()}


static func _transform(value: Variant) -> Variant:
	if not value is Transform2D or not value.is_finite(): return null
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]


func _geometry(session: Node, slot: int, part: Dictionary) -> Dictionary:
	# Read the actual collider node used by render_parts(). Do not ask the rig
	# to update, render, sample physics, or rebuild geometry. Unsupported cases
	# remain unavailable rather than receiving a guessed identity transform.
	if session._rigs.size() > MAX_BODIES:
		return {"available":false,"reason":"actor_bound"}
	for actor_index: int in range(session._rigs.size()):
		var rig: Node = session._rigs[actor_index]
		var part_index: int = slot-int(session._body_offsets[actor_index])
		if part_index < 0 or part_index >= rig._parts.size(): continue
		var body: RigidBody2D = rig._parts[part_index]
		var definition: Dictionary = session._catalogue[actor_index].parts[part_index]
		var declared_shape: String = str(definition.get("shape","rectangle"))
		var child: CollisionShape2D = null
		var child_index := -1
		var child_count: int = body.get_child_count()
		if child_count > MAX_PARTS: return {"available":false,"reason":"collider_bound"}
		if declared_shape == "rectangle_union":
			for candidate_index: int in range(child_count):
				var candidate: Node = body.get_child(candidate_index)
				if candidate is CollisionShape2D and candidate.shape is RectangleShape2D:
					child = candidate
					child_index = candidate_index
					break
		elif declared_shape in ["rectangle","rect","circle"] and child_count > 0 \
				and body.get_child(0) is CollisionShape2D:
			child = body.get_child(0)
			child_index = 0
		if child == null or not (child.shape is RectangleShape2D or child.shape is CircleShape2D):
			return {"available":false,"reason":"unsupported_collision_geometry"}
		var dimensions: Vector2 = Vector2.ONE*(child.shape.radius*2.0) \
			if child.shape is CircleShape2D else child.shape.size
		return {"available":true,"reason":"actual_collision_node",
			"actor_slot":actor_index,"part_index":part_index,"declared_shape":declared_shape,
			"declared_part_id":str(definition.id),"body_node_id":str(body.get_instance_id()),
			"body_rid":str(body.get_rid().get_id()),"child_index":child_index,
			"child_node_id":str(child.get_instance_id()),"child_parent_id":str(child.get_parent().get_instance_id()),
			"child_class":child.get_class(),"shape_class":child.shape.get_class(),
			"shape_instance_id":str(child.shape.get_instance_id()),"shape_size":_xy(dimensions),
			"collision_local_transform":_transform(child.transform),
			"composition":"selected_times_collision_local" if declared_shape == "rectangle_union" else "selected_direct",
			"overlay_actor_slot":int(part.get("actor_id",-1)),
			"overlay_body_slot":int(part.get("physical_body_index",-1)),
			"overlay_part_id":str(part.get("part_id","")),
			"overlay_physical_part_id":str(part.get("physical_part_id","")),
			"overlay_shape":str(part.get("shape","rectangle")),"overlay_size":_xy(part.get("size",null))}
	return {"available":false,"reason":"body_not_in_session"}


func _cost(started: int) -> int:
	var elapsed: int = maxi(0,Time.get_ticks_usec()-started)
	observer_total_usec += elapsed
	observer_max_usec = maxi(observer_max_usec,elapsed)
	return elapsed


func observe_submission(host: Control) -> void:
	var started := Time.get_ticks_usec()
	if submissions.size() >= MAX_SUBMISSIONS:
		dropped_submissions += 1
		_cost(started)
		return
	if host == null or not is_instance_valid(host) or host.physical_actor_session == null \
			or host.physical_actor_overlay == null or not host.workbench_presentation_frame is Dictionary:
		invalid_samples += 1
		_cost(started)
		return
	var frame: Dictionary = host.workbench_presentation_frame
	var session: Node = host.physical_actor_session
	var bridge: RefCounted = session.bridge
	var overlay: Control = host.physical_actor_overlay
	var first_parts: Dictionary = {}
	var part_count: int = overlay._parts.size()
	for index: int in range(mini(part_count,MAX_PARTS)):
		var part: Dictionary = overlay._parts[index]
		var slot: int = int(part.get("physical_body_index",part.get("actor_id",-1)))
		if slot >= 0 and not first_parts.has(slot): first_parts[slot] = part
	var bodies: Array[Dictionary] = []
	var member_count: int = bridge._members.size()
	for slot: int in range(mini(member_count,MAX_BODIES)):
		var member: Dictionary = bridge._members[slot]
		var selected: Variant = frame.get("poses",{}).get(slot,null)
		var observation: Dictionary = frame.get("selected_observations",{}).get(slot,{})
		var visible: bool = first_parts.has(slot)
		var first_part: Variant = first_parts[slot].get("transform",null) if visible else null
		var projection: Variant = null
		if selected is Transform2D and selected.is_finite() and overlay._view_size.x > 0 \
				and overlay._view_size.y > 0 and frame.get("screen_transform") is Transform2D \
				and frame.get("camera_mapping") is Transform2D:
			var local: Vector2 = overlay.position+(selected.origin-overlay._origin)*overlay.size/overlay._view_size
			var overlay_screen: Vector2 = frame.screen_transform*local
			var shader_screen: Vector2 = frame.camera_mapping*selected.origin
			projection = {"overlay_px":_xy(overlay_screen),"shader_px":_xy(shader_screen),
				"residual_px":(overlay_screen-shader_screen).length()}
		bodies.append({"slot":slot,"instance_id":int(member.instance_id),
			"generation":int(member.generation),"body_rid":str(bridge._body_rids[slot].get_id()),
			"selected_visible":selected is Transform2D,"overlay_visible":visible,
			"selected_pose":_pose(selected),"first_overlay_part":_pose(first_part),
			"selected_transform":_transform(selected),"first_overlay_transform":_transform(first_part),
			"geometry":_geometry(session,slot,first_parts[slot]) if visible else null,
			"selected_step":int(frame.get("selected_steps",{}).get(slot,-1)),
			"desired_step":int(frame.get("desired_steps",{}).get(slot,session.tick)),
			"selected_completed_usec":int(observation.get("completed_usec",0)),
			"selected_sampled_usec":int(observation.get("sampled_usec",0)),
			"source":str(frame.get("sources",{}).get(slot,"hidden")),
			"reason":str(frame.get("reasons",{}).get(slot,"invalid_frame")),
			"intentional_hold":bool(frame.get("intentional_holds",{}).get(slot,false)),
			"hold_age_usec":int(frame.get("hold_age_usec",{}).get(slot,0)),
			"explicit_reentry":bool(frame.get("explicit_reentries",{}).get(slot,false)),
			"timeline_reset":bool(frame.get("timeline_resets",{}).get(slot,false)),
			"projection":projection})
	var index: int = submissions.size()
	var row: Dictionary = {"event":"main_presentation_submission","index":index,"time_usec":started,
		"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
		"main_thread":OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"presentation_resolved_usec":int(frame.get("draw_usec",-1)),
		"session":int(bridge._session),"epoch":int(bridge._epoch),"physical_tick":int(session.tick),
		"frame_session":int(frame.get("session",-1)),"frame_epoch":int(frame.get("epoch",-1)),
		"frame_valid":bool(frame.get("valid",false)),"frame_reason":str(frame.get("reason","")),
		"world_generation":host.last_uploaded_world_generation,
		"material_revision":host.last_uploaded_revision,"render_serial":host.last_uploaded_render_snapshot_serial,
		"material_generated_usec":int(frame.get("material_timing",{}).get("current",{}).get("generated_usec",-1)),
		"overlay_id":str(overlay.get_instance_id()),"visible_part_count":part_count,
		"truncated_parts":maxi(0,part_count-MAX_PARTS),"body_count":member_count,
		"truncated_bodies":maxi(0,member_count-MAX_BODIES),"bodies":bodies,
		"camera_mode":host.shared_workbench._camera.selected,
		"camera_requested":_xy(host.camera_origin),"camera_submitted":_xy(overlay._origin),
		"view_size":_xy(overlay._view_size),"content_position":_xy(overlay.position),"content_size":_xy(overlay.size),
		"follow":{"instance_id":int(frame.get("follow_instance_id",-1)),
			"target":_xy(frame.get("follow_target",Vector2.INF)),
			"source_step":int(frame.get("follow_source_step",-1)),"held":bool(frame.get("follow_held",false))}}
	submissions.append(row)
	_last_submission_index = index
	_last_process_frame = Engine.get_process_frames()
	row["observer_usec"] = _cost(started)


func observe_draw(_host: Control, actual_inline: bool) -> void:
	var started := Time.get_ticks_usec()
	if notifications.size() >= MAX_NOTIFICATIONS:
		dropped_notifications += 1
		_cost(started)
		return
	# Separate delivers this signal later on Main. No live serial, frame number
	# or current pose can identify which previous queued draw triggered it.
	var associated: int = _last_submission_index if actual_inline \
		and _last_process_frame == Engine.get_process_frames() else -1
	var row: Dictionary = {"event":"draw_notification","time_usec":started,
		"callback_process_frame":Engine.get_process_frames(),"render_thread_inline":actual_inline,
		"submission_index":associated,"scope":"inline Main draw" if actual_inline else "deferred Main delivery, draw identity unknown"}
	notifications.append(row)
	row["observer_usec"] = _cost(started)


func write(path: String, source_identity: Dictionary, capture_start: int, capture_end: int) -> Dictionary:
	if FileAccess.file_exists(path): return {"complete":false,"error":"existing presentation receipt"}
	var result := {"schema":"pubpres-final-presentation-observer-v1",
		"source_identity":source_identity,"probe_sha256":FileAccess.get_sha256(get_script().resource_path),
		"process_id":OS.get_process_id(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"platform":OS.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"selector":OS.get_environment("CYBERSAND_DIAG_PRESENTATION_OBSERVER"),
		"capture_start_usec":capture_start,"capture_end_usec":capture_end,
		"max_submissions":MAX_SUBMISSIONS,"max_notifications":MAX_NOTIFICATIONS,
		"max_bodies":MAX_BODIES,"max_parts":MAX_PARTS,
		"dropped_submissions":dropped_submissions,"dropped_notifications":dropped_notifications,
		"invalid_samples":invalid_samples,"observer_total_usec":observer_total_usec,"observer_max_usec":observer_max_usec,
		"submissions":submissions,"notifications":notifications,
		"complete":capture_end > capture_start and capture_start > 0 and not submissions.is_empty() \
			and dropped_submissions == 0 and dropped_notifications == 0 and invalid_samples == 0,
		"scope":"Actual Main overlay copy, first visible part/collider geometry and selected pose/Follow state at frame_pre_draw. Read-only bounded diagnostic; no World reads, physics credit, GPU fence, display scanout or input-device latency. Unsupported geometry stays unverified. Separate draw notifications have no submission identity."}
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return {"complete":false,"error":"presentation receipt could not be written"}
	file.store_string(JSON.stringify(result)+"\n")
	file.close()
	return {"complete":result.complete,"path":path,"sha256":FileAccess.get_sha256(path),
		"submissions":submissions.size(),"notifications":notifications.size(),"observer_total_usec":observer_total_usec}
