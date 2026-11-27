extends SceneTree

# Actual mounted Workbench + native/Rapier + first graphical read. Deliberate
# stale-value stimuli below test rejection, not physical progression or timing.
signal render_notifications_drained
signal manual_deferred_checked

const Setup = preload("res://scripts/workbench_setup.gd")
const Transaction = preload("res://scripts/workbench_presentation_submission.gd")
var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var output: String = ""
var saved_env: Dictionary = {}
var submission_events: int = 0
var pre_draw_count: int = 0
var post_draw_count: int = 0
var refusal_framebuffers: Array[Dictionary] = []
var fallback_ui: Array[Dictionary] = []
var unsubmitted_material_picking: Dictionary = {}
var held_limb_placement: Dictionary = {}
var stock_limb_only := false
var mount_samples: Array[Dictionary] = []


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	print("ACTUAL_SUBMISSION_STARTED ",JSON.stringify({
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"script_sha256":FileAccess.get_sha256("res://tests/test_workbench_presentation_submission.gd"),
		"engine_atomic_admission":Transaction.atomic_admission_supported(),
		"requested_render_lookahead":OS.get_environment("CYBERSAND_ENGINE_RENDER_LOOKAHEAD")}))
	for key: String in ["CYBERSAND_DIAG_ACTUAL_SUBMISSION","CYBERSAND_DIAG_PRESENTATION",
			"CYBERSAND_DIAG_MATERIAL_TIMING","CYBERSAND_DIAG_FLYER_POSE"]:
		saved_env[key] = OS.get_environment(key)
	OS.set_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION","1")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","measured")
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--submission-evidence="): output = arg.trim_prefix("--submission-evidence=")
		if arg == "--stock-held-limb-placement": stock_limb_only = true
	if stock_limb_only: OS.set_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION","0")
	RenderingServer.frame_pre_draw.connect(func() -> void: pre_draw_count += 1)
	RenderingServer.frame_post_draw.connect(func() -> void: post_draw_count += 1)
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("ACTUAL_SUBMISSION: "+label)
	return ok


func until(predicate: Callable, timeout_ms: int = 60000) -> bool:
	var deadline: int = Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if is_instance_valid(host) and host.simulation_worker.has_failed(): return false
		await process_frame
	return false


# Main can attach its Workbench after this fixture receives its first scene-tree
# callback. Poll the live owner each turn. The host's first prepared World must
# still be accepted before the fixture can request its own recipe.
func _set_stock_held_canvas_extent() -> void:
	# The focused Runner fixture uses 512². Set the ordinary New width/height
	# controls after Main is ready and before the deferred New blank request.
	if host.shared_workbench != null:
		for field: SpinBox in host.shared_workbench._extent: field.value = 512


func _await_workbench_mount(label: String) -> bool:
	var started := Time.get_ticks_msec()
	var deadline := started+90000
	var next_sample := started
	while true:
		ui = host.shared_workbench
		var snapshot = host.simulation_worker.take_latest_snapshot(0)
		var ready: bool = ui != null and not ui.applied.is_empty()
		var now := Time.get_ticks_msec()
		var failed: bool = snapshot != null and snapshot.simulation_failed
		if now>=next_sample or ready or failed or now>=deadline:
			var sample := {"case":label,"elapsed_ms":now-started,"process_frame":Engine.get_process_frames(),
				"native_class":ClassDB.class_exists(&"CyberNativeCellWorld"),"feature":get_meta("cybersand_feature",""),
				"host_ready":host.is_node_ready(),"ui_attached":ui!=null,"ready":ready,"failed":failed,
				"requested_extent":[512,512] if stock_limb_only else [2048,2048],
				"applied_extent":ui.applied.get("extent",[]) if ui!=null else [],
				"worker_error":snapshot.last_tick_error if snapshot!=null else "", "has_snapshot":snapshot!=null,
				"native_tick":snapshot.tick_index if snapshot!=null else -1,"world":host.last_uploaded_world_generation,
				"snapshot_serial":snapshot.serial if snapshot!=null else -1,"upload_serial":host.last_uploaded_render_snapshot_serial,
				"ui_request":ui._pending_request_serial if ui!=null else 0,"pending_request":int(host.pending_microscenario_apply.get("serial",0)),
				"pending_owner":host._pending_physical_candidate.get_instance_id() if host._pending_physical_candidate!=null else 0,
				"installed_owner":host.physical_actor_session.get_instance_id() if host.physical_actor_session!=null else 0,
				"ready_sent":host._prepared_physical_ready_sent,"terrain_ready":host._physical_terrain_ready,
				"microscenario_error":host.microscenario_error,"native_refusal":host.tower_context.get("workbench_refusal",""),
				"frame_error":host._workbench_frame_error,"message":ui.message if ui!=null else "","draws":post_draw_count}
			mount_samples.append(sample)
			print("ACTUAL_SUBMISSION_MOUNT ",JSON.stringify(sample))
			next_sample = now+15000
		if ready or failed or now>=deadline:
			return check(ready and (not stock_limb_only or ui.applied.get("extent") == [512,512]),label)
		await process_frame
	return false


func _notification_drain_marker() -> void:
	render_notifications_drained.emit()


func _settle_render_notifications() -> void:
	# Correctness-only barrier, outside every timed workload. Separate renderer
	# post-draw signals are deferred notifications, not submission identities.
	RenderingServer.force_sync()
	_notification_drain_marker.call_deferred()
	await render_notifications_drained


func _await_actual_draw(after_submission: int) -> void:
	check(await until(func() -> bool:
		return int(host.workbench_presentation_submission_status().committed_count) > after_submission),
		"a genuine engine-admitted submission arrives")
	# Waiting through a producer turn lets the pre-draw callback return and the
	# engine enqueue its actual draw; then drain that real queue before first read.
	await _settle_render_notifications()


func _record(label: String) -> void:
	var frame: Dictionary = host.workbench_presentation_frame
	rows.append({"label":label,"status":host.workbench_presentation_submission_status(),
		"submission_serial":frame.get("submission_serial",-1),
		"process_frame":Engine.get_process_frames(),"frame_process":frame.get("submitted_process_frame",-1),
		"rapier_step":host.physical_actor_session.tick if host.physical_actor_session != null else -1,
		"world_generation":host.last_uploaded_world_generation,"material_serial":host.last_uploaded_render_snapshot_serial,
		"selected_steps":frame.get("selected_steps",{}),"visible_parts":frame.get("parts",[]).size(),
		"fairness_turn":host._workbench_presentation_turn})


func _mounted() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	root.size = Vector2i(1280,800)
	host.workbench_presentation_submitted.connect(func(_frame: Dictionary) -> void: submission_events += 1)
	if not await _await_workbench_mount("ordinary mounted native Workbench initializes"): return false
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors = [Setup.instance("needle",1,Vector2(240,160)),Setup.instance("needle",2,Vector2(280,160))]
	setup.next_id = 3
	setup.selected = 1
	setup.edits = [[0,500,512,12,58],[64,300,384,196,3]]
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"authored Wave basin and two ordinary Needles requested"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch > epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame()) \
			and host.workbench_presentation_frame.get("parts",[]).size() == 2),
		"native material, complete terrain and two actual actor submissions installed"): return false
	ui._camera.select(0)
	ui._set_view(Vector2(120,92),Vector2i(240,135))
	await _await_actual_draw(int(host.workbench_presentation_submission_status().committed_count))
	_record("initial")
	return true


func _source_identity_fallback() -> void:
	var revision: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	check(Transaction.revision_is_valid(revision) \
		and not Transaction.revision_is_valid("") \
		and not Transaction.revision_is_valid("A".repeat(40)) \
		and not Transaction.revision_is_valid("f".repeat(39)),
		"source identity accepts exact lowercase SHA and refuses malformed values")
	OS.set_environment("CYBERSAND_SOURCE_REVISION","")
	set_meta("cybersand_feature","shared_workbench")
	var before_draw: int = pre_draw_count
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	ui = host.shared_workbench
	var status: Dictionary = host.workbench_presentation_submission_status()
	check(not status.enabled and status.refusal == "source_identity_invalid" \
		and not RenderingServer.has_meta(Transaction.META),
		"missing initial source identity refuses opt-in without arming a draw-blocking handshake")
	await _await_workbench_mount("ordinary native Workbench still initializes after opt-in refusal")
	await process_frame
	await process_frame
	await _settle_render_notifications()
	var framebuffer_available: bool = not root.get_texture().get_image().is_empty()
	check(pre_draw_count > before_draw and framebuffer_available,
		"source refusal retains genuine ordinary graphical draws and recovery UI")
	fallback_ui.append({"case":"invalid_initial_source","enabled":status.enabled,
		"refusal":status.refusal,"handshake_absent":not RenderingServer.has_meta(Transaction.META),
		"pre_draw_delta":pre_draw_count-before_draw,"framebuffer_available":framebuffer_available,
		"native_workbench_initialized":ui != null and not ui.applied.is_empty()})
	host.queue_free()
	await process_frame
	host = null
	ui = null
	OS.set_environment("CYBERSAND_SOURCE_REVISION",revision)


func _freeze_normal_processing() -> void:
	host.paused = true
	host.physical_actor_session.set_suspended(true)
	host.update_worker_frame_state()
	host.set_process(false)
	host.set_physics_process(false)


func _prepare() -> void:
	host._prepare_workbench_presentation_candidate(0.0)


func _transaction_cases() -> void:
	_freeze_normal_processing()
	await process_frame
	var original: Dictionary = host._workbench_presentation_bookkeeping().duplicate(true)
	var before: Dictionary = host.workbench_presentation_submission_status()
	for unused: int in range(5): _prepare()
	check(host._workbench_presentation_bookkeeping() == original,
		"five prepared candidates do not advance any submitted history, Follow, camera or fairness state")
	check(host._workbench_submission.candidate.is_read_only() \
		and host._workbench_submission.candidate.frame.is_read_only() \
		and host._workbench_submission.candidate.frame.parts.is_read_only(),"prepared value and nested parts are immutable")
	var staged: Dictionary = host.workbench_presentation_submission_status()
	check(int(staged.prepared_count) == int(before.prepared_count)+5 \
		and int(staged.committed_count) == int(before.committed_count),"preparation counts and actual draw counts stay distinct")
	check(int(staged.preparation_samples) == int(staged.prepared_count) \
		and int(staged.last_preparation_candidate_serial) == int(staged.prepared_count) \
		and int(staged.preparation_total_usec) >= int(staged.preparation_max_usec) \
		and int(staged.preparation_max_usec) >= int(staged.last_preparation_usec) \
		and int(staged.last_preparation_usec) > 0,
		"actual candidate preparation cost is counted separately from committed draw credit")
	var candidate_serial: int = host._workbench_submission.candidate.frame.candidate_serial
	await _await_actual_draw(int(before.committed_count))
	var accepted: Dictionary = host.workbench_presentation_submission_status()
	check(int(accepted.committed_count) == int(before.committed_count)+1,
		"actual engine admission commits exactly one candidate")
	check(host.workbench_presentation_frame.candidate_serial == candidate_serial,
		"actual draw admits the latest prepared candidate")
	check(host.workbench_presentation_frame.is_read_only(),"submitted frame remains immutable")
	var committed: Dictionary = host._workbench_presentation_bookkeeping().duplicate(true)
	# An unprepared opportunity must refuse the WHOLE draw, not replay visual
	# credit or expose a rejected candidate with the preceding picking map.
	var draw_count: int = pre_draw_count
	await process_frame
	await process_frame
	check(host._workbench_presentation_bookkeeping() == committed and pre_draw_count == draw_count,
		"unprepared opportunity emits no draw and does not advance submitted histories")
	_record("superseded_and_duplicate")

	# Suppress actual drawing across several real producer opportunities.
	RenderingServer.set_render_loop_enabled(false)
	var no_draw: Dictionary = host._workbench_presentation_bookkeeping().duplicate(true)
	for unused: int in range(4):
		await process_frame
		_prepare()
	# Finish the fourth no-draw iteration before re-enabling. process_frame is
	# emitted before that iteration's idle callbacks and draw opportunity.
	await process_frame
	check(host._workbench_presentation_bookkeeping() == no_draw,
		"four genuine no-draw process opportunities leave submitted histories unchanged")
	_prepare()
	RenderingServer.set_render_loop_enabled(true)
	await _await_actual_draw(int(accepted.committed_count))
	check(int(host.workbench_presentation_submission_status().committed_count) == int(accepted.committed_count)+1,
		"draw resumption commits one fresh candidate without replaying deferred candidates")
	_record("draw_resume")
	await _manual_before_flush()
	await _manual_during_flush()

	await _stale_case("owner",func() -> Variant:
		var old: RefCounted = host.physical_actor_session.bridge
		host.physical_actor_session.bridge = host.WorkbenchBridge.new()
		return old,func(old: Variant) -> void: host.physical_actor_session.bridge = old,"bridge")
	await _stale_case("camera",func() -> Variant:
		var old: Vector2 = host.camera_origin
		host.camera_origin += Vector2(7,0)
		return old,func(old: Variant) -> void: host.camera_origin = old)
	await _stale_case("policy",func() -> Variant:
		OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","")
		return null,func(_old: Variant) -> void: OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","measured"))
	await _stale_case("material",func() -> Variant:
		var old: bool = host._presentation_previous_unknown
		host._presentation_previous_unknown = not old
		return old,func(old: Variant) -> void: host._presentation_previous_unknown = old)
	await _stale_case("lifecycle",func() -> Variant:
		host.paused = false
		return null,func(_old: Variant) -> void: host.paused = true)

	await _physical_completion_refusal()

	# Camera intent can move between draws; both continuous aim and cell pick
	# still address the last actually submitted terrain/actor mapping.
	await process_frame
	var picking_before: int = host.workbench_presentation_submission_status().committed_count
	_prepare()
	await _await_actual_draw(picking_before)
	var local: Vector2 = host.workbench_presentation_frame.content_rect.get_center()
	var prior_cell: Vector2i = host.world_cell_from_local_point(local,true)
	var prior_point: Vector2 = host.world_position_from_local_point(local)
	var camera_before: Vector2 = host.camera_origin
	host.camera_origin += Vector2(80,40)
	check(host.world_cell_from_local_point(local,true) == prior_cell \
		and host.world_cell_from_local_point(local,false) == prior_cell \
		and host.world_position_from_local_point(local) == prior_point,
		"picking and continuous aim retain actual submitted mapping while future camera request differs")
	host.camera_origin = camera_before
	_record("picking")
	await _transformed_pointer_case()


func _uploaded_material_pointer_case() -> void:
	# The worker performs a real ordinary edit and Main uploads its result,
	# while the atomic owner has no prepared draw. The last framebuffer and
	# its actor hit mapping must remain usable until the next admitted draw.
	await _settle_render_notifications()
	var submitted: Dictionary = host.workbench_presentation_frame
	var before_pixels: String = _pixels_sha256(root.get_texture().get_image())
	var count: int = host.workbench_presentation_submission_status().committed_count
	var before_draw: int = pre_draw_count
	var before_step: int = host.physical_actor_session.tick
	var actor_id: int = int(ui.applied.actors[0].id)
	var bridge: Variant = host.physical_actor_session.bridge
	var body_slot: int = bridge.actor_body_index(host.physical_actor_session.slot_for_instance(actor_id))
	if not check(submitted.get("poses",{}).has(body_slot),"unsubmitted material witness starts with a genuinely visible actor"): return
	var prior_revision: int = host.last_uploaded_revision
	var prior_serial: int = host.last_uploaded_render_snapshot_serial
	var paint_cell := Vector2i(180,120)
	check(host.image.get_pixelv(paint_cell).r8==0 and ui.paint(paint_cell,2),
		"ordinary Sand edit enters native owner while actual drawing is unprepared")
	check(await until(func() -> bool:
		host.consume_worker_snapshot()
		return host.last_uploaded_revision>prior_revision and host.last_uploaded_render_snapshot_serial>prior_serial \
			and host.image.get_pixelv(paint_cell).r8==2),
		"actual newer native material reaches the production texture upload path")
	await _settle_render_notifications()
	var held_pixels: String = _pixels_sha256(root.get_texture().get_image())
	check(host.workbench_presentation_frame==submitted and held_pixels==before_pixels \
		and host.workbench_presentation_submission_status().committed_count==count and pre_draw_count==before_draw,
		"new uploaded material grants no framebuffer, mapping or draw credit without actual admission")
	var pose: Transform2D = submitted.poses[body_slot]
	var local: Vector2 = host._world_view_screen_transform().affine_inverse()*(submitted.camera_mapping*pose.origin)
	var cell: Vector2i = host.world_cell_from_local_point(local,true)
	var selected_before: int = ui.selected_id()
	ui._tool.select(2)
	check(ui.select_instance(0),"unsubmitted material actual mouse witness clears prior selection")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = local
	ui._world_input(click)
	var selected_after: int = ui.selected_id()
	check(selected_after==actor_id,"actual mouse still selects the submitted actor while newer material remains unsubmitted")
	check(host.physical_actor_session.tick==before_step,"material authoring and submitted-actor picking invent no Rapier completion")
	var prior_camera: Vector2 = host.camera_origin
	var prior_size: Vector2i = host.current_view_size
	ui._set_view(Vector2.ZERO,Vector2i(160,90))
	ui.actor_interaction.set_mode("place")
	ui._world_input(click)
	var placed: Dictionary = ui.actor_interaction.placement
	check(not placed.is_empty() and placed.get("instance_id")==actor_id
		and ui.actor_interaction._point(local).distance_to(pose.origin)<0.001,
		"actual Place click uses the submitted camera and body through an unsubmitted camera and Sand upload")
	ui.actor_interaction.cancel()
	ui.actor_interaction.set_mode("grab")
	host.paused = false
	host.physical_actor_session.set_suspended(false)
	ui._world_input(click)
	var grabbed: Dictionary = ui.actor_interaction.grab_state()
	check(grabbed.active and grabbed.instance_id==actor_id and grabbed.part_index==0
		and grabbed.target.distance_to(pose.origin)<0.001 and host.physical_actor_session.tick==before_step,
		"actual Grab claims exactly the submitted member and anchor without stepping")
	ui.actor_interaction.cancel()
	host.paused = true
	host.physical_actor_session.set_suspended(true)
	ui._set_view(prior_camera,prior_size)
	ui._tool.select(2)
	var refused: Array[Dictionary] = []
	for kind: String in ["future_submission","foreign_world","material_join"]:
		# Frozen copies isolate one refusal fence. They are never submitted or
		# drawn and cannot replace the exact unchanged framebuffer witness.
		var injected: Dictionary = submitted.duplicate(true)
		if kind=="future_submission": injected.submission_serial = count+1
		elif kind=="foreign_world": injected.world_generation = int(submitted.world_generation)+1
		else: injected.mask_frame.revision = int(submitted.material_revision)+1
		Transaction.freeze(injected)
		host.workbench_presentation_frame = injected
		ui.select_instance(0)
		ui._pick(cell)
		check(ui.selected_id()==0,"submitted actor picking refuses copied "+kind+" identity")
		check(ui.presented_part_at(pose.origin).is_empty(),"manipulation refuses copied "+kind+" identity")
		refused.append({"kind":kind,"selected_id":ui.selected_id(),"fixture_injected_refusal":true})
		host.workbench_presentation_frame = submitted
	unsubmitted_material_picking = {"actor_id":actor_id,"body_slot":body_slot,"selected_id":selected_after,
		"cell":[cell.x,cell.y],"local":[local.x,local.y],"paint_cell":[paint_cell.x,paint_cell.y],
		"uploaded_material_id":host.image.get_pixelv(paint_cell).r8,
		"submitted_revision":int(submitted.material_revision),"previous_uploaded_revision":prior_revision,
		"uploaded_revision":host.last_uploaded_revision,"previous_uploaded_serial":prior_serial,
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"before_sha256":before_pixels,"held_sha256":held_pixels,
		"mapping_unchanged":host.workbench_presentation_frame==submitted,
		"submission_delta":host.workbench_presentation_submission_status().committed_count-count,
		"pre_draw_delta":pre_draw_count-before_draw,"step_before":before_step,"step_after":host.physical_actor_session.tick,
		"refusal_controls":refused}
	ui.select_instance(selected_before)
	_prepare()
	await _await_actual_draw(count)
	check(host.workbench_presentation_frame.material_revision==host.last_uploaded_revision,
		"next genuine draw adopts the new material with its own interaction frame")
	unsubmitted_material_picking["next_submission_delta"] = host.workbench_presentation_submission_status().committed_count-count
	unsubmitted_material_picking["next_material_revision"] = int(host.workbench_presentation_frame.material_revision)
	_record("unsubmitted_material_picking")


func _transformed_pointer_case() -> void:
	await _settle_render_notifications()
	var submitted: Dictionary = host.workbench_presentation_frame
	var local_before: Vector2 = submitted.content_rect.get_center()
	var physical_pointer: Vector2 = host._world_view_screen_transform()*local_before
	var prior_cell: Vector2i = host.world_cell_from_local_point(local_before,true)
	var prior_point: Vector2 = host.world_position_from_local_point(local_before)
	var before_pixels: String = _pixels_sha256(root.get_texture().get_image())
	var before_draw: int = pre_draw_count
	var old_position: Vector2 = host.world_view.position
	var old_rotation: float = host.world_view.rotation
	var old_scale: Vector2 = host.world_view.scale
	# A new Control transform changes Godot's input localization immediately,
	# while a refused/unprepared draw leaves the actual framebuffer unchanged.
	host.world_view.position += Vector2(17,9)
	host.world_view.rotation += 0.13
	host.world_view.scale *= Vector2(0.91,1.07)
	var current_screen: Transform2D = host._world_view_screen_transform()
	var event_local: Vector2 = current_screen.affine_inverse()*physical_pointer
	check(current_screen != submitted.screen_transform and event_local.distance_to(local_before)>1.0,
		"unsubmitted Control rotation, scale and translation change event localization")
	check(host.world_cell_from_local_point(event_local,true) == prior_cell \
		and host.world_cell_from_local_point(event_local,false) == prior_cell \
		and host.world_position_from_local_point(event_local).distance_to(prior_point)<0.001,
		"current event transform addresses the same physical pixel in the last submitted mapping")
	await process_frame
	await _settle_render_notifications()
	check(pre_draw_count == before_draw and host.workbench_presentation_frame == submitted \
		and _pixels_sha256(root.get_texture().get_image()) == before_pixels,
		"unsubmitted Control transform advances no draw, framebuffer or mapping")
	host.world_view.position = old_position
	host.world_view.rotation = old_rotation
	host.world_view.scale = old_scale
	_record("transformed_pointer")


func _pixels_sha256(image: Image) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(image.get_data())
	return digest.finish().hex_encode()


func _manual_before_flush() -> void:
	await process_frame
	var old_frame: Dictionary = host.workbench_presentation_frame
	var before_pixels: String = _pixels_sha256(root.get_texture().get_image())
	var count: int = host.workbench_presentation_submission_status().committed_count
	var before_pre: int = pre_draw_count
	var before_post: int = post_draw_count
	var before_events: int = submission_events
	host.camera_origin += Vector2(32,0)
	_prepare()
	check(not host.workbench_presentation_submission_status().candidate_ready,
		"candidate is not ready before its exact canvas-flush marker")
	RenderingServer.force_draw()
	var after_pixels: String = _pixels_sha256(root.get_texture().get_image())
	check(host.workbench_presentation_submission_status().committed_count == count \
		and host.workbench_presentation_frame == old_frame,
		"manual force_draw before flush admits no future candidate history")
	check(pre_draw_count == before_pre and post_draw_count == before_post and before_pixels == after_pixels,
		"manual force_draw before flush emits no draw and preserves actual framebuffer")
	refusal_framebuffers.append({"case":"manual_before_flush","before_sha256":before_pixels,
		"after_sha256":after_pixels,"mapping_unchanged":host.workbench_presentation_frame == old_frame,
		"pre_draw_delta":pre_draw_count-before_pre,"post_draw_delta":post_draw_count-before_post,
		"submission_delta":submission_events-before_events,
		"journal_delta":host.workbench_presentation_submission_status().committed_count-count,
		"reason":"candidate_not_flushed"})
	await _await_actual_draw(count)
	check(host.workbench_presentation_submission_status().committed_count == count+1 \
		and host.workbench_presentation_frame.camera_mapping != old_frame.camera_mapping,
		"exact flush marker then permits one genuine draw of the new mapping")
	_record("manual_before_flush")


func _manual_during_flush() -> void:
	await process_frame
	await _settle_render_notifications()
	var old_frame: Dictionary = host.workbench_presentation_frame
	var before_pixels: String = _pixels_sha256(root.get_texture().get_image())
	var count: int = host.workbench_presentation_submission_status().committed_count
	host.camera_origin += Vector2(32,0)
	_prepare()
	var serial: int = host._workbench_submission.candidate.frame.candidate_serial
	# Queue this AFTER the candidate marker. Readiness alone cannot establish
	# completion of the enclosing flush, which can still enqueue nested redraws.
	_manual_deferred_probe.call_deferred(old_frame,before_pixels,count)
	await manual_deferred_checked
	await _await_actual_draw(count)
	var after_pixels: String = _pixels_sha256(root.get_texture().get_image())
	check(host.workbench_presentation_submission_status().committed_count == count+1 \
		and host.workbench_presentation_frame.candidate_serial == serial \
		and host.workbench_presentation_frame.camera_mapping != old_frame.camera_mapping \
		and after_pixels != before_pixels,
		"same ready candidate first reaches framebuffer in the genuine post-flush draw")
	var row: Dictionary = refusal_framebuffers[-1]
	row["next_submission_delta"] = host.workbench_presentation_submission_status().committed_count-count
	row["next_candidate_serial"] = host.workbench_presentation_frame.candidate_serial
	row["staged_candidate_serial"] = serial
	row["next_framebuffer_sha256"] = after_pixels
	_record("manual_during_flush")


func _manual_deferred_probe(old_frame: Dictionary, before_pixels: String, count: int) -> void:
	var ready: bool = host.workbench_presentation_submission_status().candidate_ready
	check(ready,"deferred manual adversary runs after the exact candidate-ready marker")
	var before_pre: int = pre_draw_count
	var before_post: int = post_draw_count
	var before_events: int = submission_events
	RenderingServer.force_draw()
	var after_pixels: String = _pixels_sha256(root.get_texture().get_image())
	var journal_delta: int = host.workbench_presentation_submission_status().committed_count-count
	var mapping_unchanged: bool = host.workbench_presentation_frame == old_frame
	check(journal_delta == 0 and mapping_unchanged and pre_draw_count == before_pre \
		and post_draw_count == before_post and submission_events == before_events \
		and before_pixels == after_pixels,
		"manual draw during Main flush admits no history, signals or framebuffer even with ready marker")
	check(host.workbench_presentation_submission_status().candidate_ready,
		"during-flush refusal leaves the immutable candidate for normal post-flush admission")
	refusal_framebuffers.append({"case":"manual_during_flush","candidate_ready":ready,
		"before_sha256":before_pixels,"after_sha256":after_pixels,"mapping_unchanged":mapping_unchanged,
		"pre_draw_delta":pre_draw_count-before_pre,"post_draw_delta":post_draw_count-before_post,
		"submission_delta":submission_events-before_events,"journal_delta":journal_delta,
		"reason":"manual_draw_inside_main_flush","reason_scope":"engine_message_queue_admission"})
	manual_deferred_checked.emit()


func _stale_case(label: String, mutate: Callable, restore: Callable, expected_reason: String = "") -> void:
	await process_frame
	await _settle_render_notifications()
	var old_frame: Dictionary = host.workbench_presentation_frame
	var camera_before: Vector2 = host.camera_origin
	var before_pixels: String = _pixels_sha256(root.get_texture().get_image())
	# Make this staged candidate visibly different, so retaining the previous
	# framebuffer is a discriminating test of actual draw refusal.
	host.camera_origin += Vector2(32,0)
	_prepare()
	var staged_mapping: Transform2D = host._workbench_submission.candidate.frame.camera_mapping
	var count: int = host.workbench_presentation_submission_status().committed_count
	var before_pre: int = pre_draw_count
	var before_post: int = post_draw_count
	var before_events: int = submission_events
	var old: Variant = mutate.call()
	# A refused draw emits neither pre nor post draw. Observe the next genuine
	# Main producer turn instead of waiting on a signal that must not exist.
	await process_frame
	var status: Dictionary = host.workbench_presentation_submission_status()
	var after_pixels: String = _pixels_sha256(root.get_texture().get_image())
	var why: String = (label if expected_reason.is_empty() else expected_reason)+"_changed"
	check(int(status.committed_count) == count and host.workbench_presentation_frame == old_frame,
		label+" change refuses stale prepared bookkeeping")
	check(status.last_rejection == why,label+" exact refusal reason retained")
	check(pre_draw_count == before_pre and post_draw_count == before_post and submission_events == before_events,
		label+" rejection emits no real draw or submission notification")
	check(before_pixels == after_pixels and staged_mapping != old_frame.camera_mapping,
		label+" rejected staged camera does not reach actual first-read framebuffer")
	check(host.presentation_camera_screen_transform() == old_frame.camera_mapping,
		label+" pointer mapping remains joined to unchanged actual framebuffer")
	refusal_framebuffers.append({"case":label,"before_sha256":before_pixels,"after_sha256":after_pixels,
		"staged_mapping_different":staged_mapping != old_frame.camera_mapping,
		"mapping_unchanged":host.workbench_presentation_frame == old_frame \
			and host.presentation_camera_screen_transform() == old_frame.camera_mapping,
		"pre_draw_delta":pre_draw_count-before_pre,"post_draw_delta":post_draw_count-before_post,
		"submission_delta":submission_events-before_events,"reason":status.last_rejection})
	restore.call(old)
	host.camera_origin = camera_before
	_record("stale_"+label)


func _physical_completion_refusal() -> void:
	check(ui.toggle_pause(),"native-completion refusal stimulus uses ordinary Play admission")
	check(await until(func() -> bool:
		var snapshot = host.simulation_worker.take_latest_physics_snapshot()
		return snapshot != null and snapshot.lab_context.get("workbench_completed_sample",-1) == host._workbench_wait_sample),
		"native-completion stimulus waits for the legitimate current sample result")
	await process_frame
	await _settle_render_notifications()
	var old_frame: Dictionary = host.workbench_presentation_frame
	var camera_before: Vector2 = host.camera_origin
	var before_pixels: String = _pixels_sha256(root.get_texture().get_image())
	host.camera_origin += Vector2(32,0)
	_prepare()
	var count: int = host.workbench_presentation_submission_status().committed_count
	var tick: int = host.physical_actor_session.tick
	var steps: int = host.rapier_bridge.manual_step_count()
	var before_pre: int = pre_draw_count
	var before_post: int = post_draw_count
	var before_events: int = submission_events
	# This is the production callback with its unchanged native/terrain/sample
	# admission gates. No synthetic completion counter or stale-body step.
	host._physics_process(1.0/60.0)
	check(host.physical_actor_session.tick == tick+1 and host.rapier_bridge.manual_step_count() == steps+1,
		"post-prepare stimulus genuinely completes one admitted native/Rapier step")
	await process_frame
	var status: Dictionary = host.workbench_presentation_submission_status()
	var after_pixels: String = _pixels_sha256(root.get_texture().get_image())
	check(int(status.committed_count) == count and host.workbench_presentation_frame == old_frame \
		and status.last_rejection == "physical_completion_changed",
		"actual post-prepare physical completion refuses old candidate")
	check(pre_draw_count == before_pre and post_draw_count == before_post and submission_events == before_events,
		"physical-completion refusal emits no draw or notification")
	check(before_pixels == after_pixels and host.presentation_camera_screen_transform() == old_frame.camera_mapping,
		"physical-completion refusal preserves actual framebuffer and picking mapping")
	refusal_framebuffers.append({"case":"physical_completion","before_sha256":before_pixels,
		"after_sha256":after_pixels,"mapping_unchanged":host.workbench_presentation_frame == old_frame \
			and host.presentation_camera_screen_transform() == old_frame.camera_mapping,
		"real_step_delta":host.physical_actor_session.tick-tick,
		"real_manual_step_delta":host.rapier_bridge.manual_step_count()-steps,
		"pre_draw_delta":pre_draw_count-before_pre,"post_draw_delta":post_draw_count-before_post,
		"submission_delta":submission_events-before_events,"reason":status.last_rejection})
	check(ui.toggle_pause(),"post-prepare physical stimulus returns to ordinary Pause")
	host.camera_origin = camera_before
	_record("stale_physical_completion")


func _first_read() -> void:
	await process_frame
	var count: int = host.workbench_presentation_submission_status().committed_count
	_prepare()
	await _await_actual_draw(count)
	var frame: Dictionary = host.workbench_presentation_frame
	if not check(frame.parts.size() == 2,"first-read has two actually submitted dry actor parts"): return
	var image: Image = root.get_texture().get_image()
	if not check(image != null and not image.is_empty(),"first framebuffer read is available"): return
	var part: Dictionary = frame.parts[0]
	var physical: Transform2D = PhysicsServer2D.body_get_state(host.physical_actor_session.bridge._body_rids[0],
		PhysicsServer2D.BODY_STATE_TRANSFORM)
	check(physical.is_equal_approx(part.transform),"submitted dry actor geometry matches real paused Rapier RID")
	# The saved camera map addresses physical window pixels. The root texture
	# uses viewport pixels; apply the actual window/stretch inverse exactly once.
	# This interior point avoids the Needle's center marking and pilot ring.
	# It remains inside the actual 7x3 collider, with a full-pixel border margin.
	var interior_world: Vector2 = physical * Vector2(1.5,0.5)
	var projected: Vector2 = root.get_stretch_transform() * (root.get_screen_transform().affine_inverse() * (frame.camera_mapping * interior_world))
	var sample: Vector2i = Vector2i(projected.floor())
	var expected: Color = Color(part.color).darkened(0.18)
	var observed: Color = image.get_pixelv(sample)
	check(Vector3(observed.r,observed.g,observed.b).distance_to(Vector3(expected.r,expected.g,expected.b)) < 0.04,
		"first-read framebuffer actor interior has independently predicted solid actor colour")
	rows.append({"label":"first_read","pixel":[sample.x,sample.y],"observed":[observed.r,observed.g,observed.b],
		"expected":[expected.r,expected.g,expected.b],"submission_serial":frame.submission_serial,
		"image_size":[image.get_width(),image.get_height()],"root_size":[root.size.x,root.size.y],
		"root_screen_transform":str(root.get_screen_transform()),"root_stretch_transform":str(root.get_stretch_transform()),
		"camera_mapping":str(frame.camera_mapping)})
	if not output.is_empty(): image.save_png(output.get_base_dir().path_join("submission-first-read.png"))


func _invalid_actor_frame_ui() -> void:
	var before: int = host.workbench_presentation_submission_status().committed_count
	var before_draw: int = pre_draw_count
	host._prepare_workbench_presentation_candidate(0.0,{"deliberately_missing_actor_receipt":true})
	await _await_actual_draw(before)
	check(not host.workbench_presentation_frame.valid and host.workbench_presentation_frame.parts.is_empty() \
		and pre_draw_count == before_draw+1,
		"invalid actor receipt admits a real empty-overlay UI draw without fabricating actor authority")
	fallback_ui.append({"case":"invalid_actor_receipt","pre_draw_delta":pre_draw_count-before_draw,
		"submission_delta":host.workbench_presentation_submission_status().committed_count-before,
		"frame_valid":host.workbench_presentation_frame.valid,
		"visible_parts":host.workbench_presentation_frame.parts.size()})
	_record("invalid_actor_frame_ui")
	before = host.workbench_presentation_submission_status().committed_count
	_prepare()
	await _await_actual_draw(before)
	check(host.workbench_presentation_frame.valid and host.workbench_presentation_frame.parts.size()==2,
		"fresh genuine actor receipt restores the ordinary overlay after invalid-frame UI draw")


func _retired_physical_owner_ui() -> void:
	_freeze_normal_processing()
	await process_frame
	var prior_owner: int = host.physical_actor_session.get_instance_id()
	var pointer: Vector2 = host.workbench_presentation_frame.content_rect.get_center()
	host._close_physical_actors()
	var picking_refused: bool = host.physical_actor_session == null and host.workbench_presentation_frame.is_empty() \
		and host.world_cell_from_local_point(pointer,true) == Vector2i(-1,-1) \
		and not host.world_position_from_local_point(pointer).is_finite() \
		and host.actor_pointer_aim_at(pointer) == Vector2.ZERO
	check(picking_refused,
		"real physical-owner retirement refuses picking and aim until a new submitted mapping exists")
	var before: int = host.workbench_presentation_submission_status().committed_count
	var before_draw: int = pre_draw_count
	_prepare()
	await _await_actual_draw(before)
	check(not host.workbench_presentation_frame.valid and host.workbench_presentation_frame.parts.is_empty(),
		"retired physical owner still permits an actual safe empty-overlay UI draw")
	fallback_ui.append({"case":"retired_physical_owner","pre_draw_delta":pre_draw_count-before_draw,
		"submission_delta":host.workbench_presentation_submission_status().committed_count-before,
		"frame_valid":host.workbench_presentation_frame.valid,
		"visible_parts":host.workbench_presentation_frame.parts.size(),"picking_refused":picking_refused})
	host.set_process(true)
	host.set_physics_process(true)
	check(ui.restore_start(),"ordinary restore restarts after actual physical-owner retirement")
	check(await until(func() -> bool:
		return host.physical_actor_session != null \
			and host.physical_actor_session.get_instance_id() != prior_owner \
			and host.pending_microscenario_apply.is_empty() \
			and host.workbench_presentation_frame.get("valid",false) \
			and host.workbench_presentation_frame.get("parts",[]).size()==2),
		"fresh physical owner and real actor submissions recover after teardown")
	fallback_ui.append({"case":"physical_owner_restart","retired_owner":prior_owner,
		"new_owner":host.physical_actor_session.get_instance_id() if host.physical_actor_session != null else 0,
		"submission_delta":host.workbench_presentation_submission_status().committed_count-before,
		"frame_valid":host.workbench_presentation_frame.get("valid",false),
		"visible_parts":host.workbench_presentation_frame.get("parts",[]).size()})
	_record("physical_owner_restart")


# The displayed right foot is deliberately older than the live paused assembly.
# This moves real Rapier RIDs as an isolated fixture stimulus. It never inserts a
# synthetic accepted pose or grants the move native or physical completion credit.
func _held_limb_placement() -> void:
	var recipe: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.actors = [Setup.instance("runner",12,Vector2(240,160))]
	recipe.next_id = 13
	recipe.selected = 12
	var old_epoch: int = host._physical_epoch
	if not check(ui.apply(recipe),"ordinary paused six-member Runner requested for Place"): return
	if not check(await until(func() -> bool: return host._physical_epoch > old_epoch and host._physical_terrain_ready \
			and host.pending_microscenario_apply.is_empty() and host.workbench_presentation_frame.get("poses",{}).size() == 6),
			"six genuine Runner members mounted before pointer placement"): return
	ui._camera.select(0)
	ui._set_view(Vector2(120,92),Vector2i(240,135))
	await process_frame
	_freeze_normal_processing()
	await process_frame
	await _settle_render_notifications()
	var receipt: Dictionary = host.workbench_presentation_frame
	var session = host.physical_actor_session
	var bridge: Variant = session.bridge
	var source_epoch: int = host._physical_epoch
	var limb := 4 # Catalogue right foot is a real 4x2 part.
	var contact := Vector2(1.125,0.25)
	var accepted: Transform2D = receipt.poses[limb]
	var start: Vector2 = accepted * contact
	var finish := start+Vector2(17.25,-6.75)
	var pivot: Vector2 = receipt.poses[0].origin
	var turn := Transform2D(0.47,pivot+Vector2(12,-8)) * Transform2D(0.0,-pivot)
	var before_step: int = session.tick
	var pixels := _pixels_sha256(root.get_texture().get_image())
	for rid: RID in bridge._body_rids:
		var old: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
		PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM,turn*old)
	var newer: Transform2D = PhysicsServer2D.body_get_state(bridge._body_rids[limb],PhysicsServer2D.BODY_STATE_TRANSFORM)
	if not check((newer*contact).distance_to(start)>5.0 and absf(wrapf(newer.get_rotation()-accepted.get_rotation(),-PI,PI))>0.4 \
			and host.workbench_presentation_frame==receipt and session.tick==before_step \
			and pixels==_pixels_sha256(root.get_texture().get_image()),"live rotated right foot diverges from the actual unchanged displayed contact"): return

	var to_local: Transform2D = host._world_view_screen_transform().affine_inverse()*receipt.camera_mapping
	var global_finish: Vector2 = host.world_view.get_global_transform_with_canvas()*(to_local*finish)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = to_local*start
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = global_finish
	ui.actor_interaction.set_mode("place")
	if not check(not ui.actor_interaction.settings.snap_enabled and ui.presented_part_at(start).get("part_index",-1)==limb,
			"unsnapped pointer inside the shown right foot resolves the exact member"): return
	ui._world_input(down)
	var placed: Dictionary = ui.actor_interaction.placement
	var initial_contact := _part_contact(placed,limb,contact)
	if not check(placed.get("valid",false) and initial_contact.distance_to(start)<0.001,
			"initial preview puts the acquired foot-local contact under the displayed pointer"): return
	# Inject exactly one member-generation mismatch between press and release.
	# No source, pose or owner replacement may be staged by that release.
	var identity: Dictionary = bridge._members[limb]
	var changed: Dictionary = identity.duplicate()
	changed.generation = int(changed.generation)+1
	bridge._members[limb] = changed
	ui._input(up)
	bridge._members[limb] = identity
	if not check(ui.actor_interaction.placement.is_empty() and host.pending_microscenario_apply.is_empty() \
			and host.physical_actor_session==session and int(ui.applied.selected)==12,
			"release after member generation changes refuses the staged mutation"): return

	ui._world_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = global_finish
	ui._input(drag)
	placed = ui.actor_interaction.placement
	var dragged_contact := _part_contact(placed,limb,contact)
	if not check(placed.get("valid",false) and dragged_contact.distance_to(finish)<0.001,
			"ordinary drag preserves the rotated live limb's acquired contact at the unsnapped destination"): return
	ui._input(up)
	var released_step: int = session.tick
	if not check(not host.pending_microscenario_apply.is_empty() and released_step==before_step,
			"ordinary release stages one owner transaction without manufacturing a physical step"): return
	host.set_process(true)
	host.set_physics_process(true)
	if not check(await until(func() -> bool: return host.physical_actor_session!=null and host._physical_epoch>source_epoch \
			and host.pending_microscenario_apply.is_empty() and host._physical_terrain_ready),
			"placement release installs a new ready paused owner"): return
	var actual: Dictionary = host.physical_actor_session.capture_workbench_assembly(12)
	var live_contact := _part_contact(actual,limb,contact)
	check(live_contact.distance_to(finish)<0.002 and absf(wrapf(float(actual.parts[limb].rotation)-newer.get_rotation(),-PI,PI))<0.001,
		"installed rotated Runner foot retains its articulation and exact unsnapped release anchor")
	var newer_contact: Vector2 = newer*contact
	held_limb_placement = {"part_index":limb,"local_contact":[contact.x,contact.y],
		"accepted_contact":[start.x,start.y],"live_contact_before_press":[newer_contact.x,newer_contact.y],
		"preview_contact":[initial_contact.x,initial_contact.y],"dragged_contact":[dragged_contact.x,dragged_contact.y],
		"release_target":[finish.x,finish.y],"installed_contact":[live_contact.x,live_contact.y],
		"limb_rotations":[accepted.get_rotation(),newer.get_rotation(),actual.parts[limb].rotation],
		"epochs":[source_epoch,host._physical_epoch],"step_before":before_step,"step_after_release":released_step,
		"installed_step":host.physical_actor_session.tick,"submitted_serial":receipt.get("submission_serial",-1),
		"unchanged_framebuffer_sha256":pixels,"generation_refusal":true,
		"stimulus":"rigid real RID pose change while paused, no process/physics advancement"}


func _part_contact(assembly: Dictionary, limb: int, contact: Vector2) -> Vector2:
	var parts: Array = assembly.get("parts",[])
	if parts.size()<=limb: return Vector2.INF
	return Transform2D(float(parts[limb].rotation),parts[limb].position)*contact


func _ordinary_lifecycle() -> void:
	host.set_process(true)
	host.set_physics_process(true)
	var start_tick: int = host.physical_actor_session.tick
	check(ui.step_once(),"ordinary Step admitted")
	check(await until(func() -> bool: return not ui.step_pending and host.physical_actor_session.tick > start_tick),
		"ordinary Step completes genuine physical work with transaction enabled")
	check(host.paused,"Step retains Pause")
	check(ui.toggle_pause(),"ordinary Play admitted")
	check(await until(func() -> bool: return host.physical_actor_session.tick >= start_tick+12),
		"ordinary native/Rapier dependency path advances twelve real steps")
	check(ui.toggle_pause(),"ordinary Pause admitted")
	ui._camera.select(1)
	await _await_actual_draw(int(host.workbench_presentation_submission_status().committed_count))
	check(host.workbench_presentation_frame.follow_instance_id == ui.selected_id(),"Follow uses submitted selected actor")
	ui._camera.select(0)
	ui.zoom_by(1)
	check(ui.paint(Vector2i(70,70),2),"ordinary material paint admitted")
	check(await until(func() -> bool: return host.image.get_pixel(70,70).r8 == 2),"paint reaches actual native published image")
	var epoch: int = host._physical_epoch
	check(ui.apply(ui.applied.duplicate(true)),"ordinary authored restore requested")
	check(await until(func() -> bool: return host._physical_epoch > epoch and host.pending_microscenario_apply.is_empty() \
		and host.workbench_presentation_frame.get("epoch",-1) == host._physical_epoch),
		"new World/owner receives a fresh actual submission after restore")
	_record("ordinary_lifecycle")


func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if not stock_limb_only and not check(Transaction.atomic_admission_supported(),"actual engine-owned atomic admission required"):
		_finish()
		return
	if not check(DisplayServer.get_name() != "headless","graphical execution required for actual-submission qualification"):
		_finish()
		return
	if stock_limb_only:
		set_meta("cybersand_feature","shared_workbench")
		host = load("res://main.tscn").instantiate()
		host.ready.connect(_set_stock_held_canvas_extent,CONNECT_ONE_SHOT)
		root.add_child(host)
		root.size = Vector2i(1280,800)
		if await _await_workbench_mount("ordinary Workbench initializes without atomic submission"):
			await _held_limb_placement()
		_finish()
		return
	await _source_identity_fallback()
	if await _mounted():
		check(host.workbench_presentation_submission_status().source_valid,"exact source revision provided")
		await _transaction_cases()
		await _first_read()
		await _invalid_actor_frame_ui()
		# The additive real edit changes material dependencies while normal
		# processing is deliberately frozen. Keep the original dry first-read
		# controls before it; ordinary lifecycle processing below then reconciles
		# the real new material without inventing a physical completion here.
		await _uploaded_material_pointer_case()
		await _ordinary_lifecycle()
		await _retired_physical_owner_ui()
		await _held_limb_placement()
		var owner: int = host.get_instance_id()
		host._workbench_submission.close()
		check(not RenderingServer.frame_pre_draw.is_connected(host._commit_workbench_presentation_submission),
			"owner retirement disconnects live commit callback")
		check(not RenderingServer.has_meta(Transaction.META) or \
			int(RenderingServer.get_meta(Transaction.META).get("owner_instance",0)) != owner,
			"owner retirement removes only its own bounded-engine handshake")
	_finish()


func _finish() -> void:
	var windows: bool = OS.get_name()=="Windows"
	var native_path := "res://addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so")
	var rapier_path := "res://addons/godot-rapier2d/bin/" + (
		"libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if windows else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
	var result: Dictionary = {"schema":"workbench-stock-held-limb-placement-v1" if stock_limb_only else "workbench-actual-submission-graphical-v1","checks":checks,
		"failures":failures,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"platform":OS.get_name(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"process_id":OS.get_process_id(),
		"native_sha256":FileAccess.get_sha256(native_path),"rapier_sha256":FileAccess.get_sha256(rapier_path),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"requested_render_lookahead":OS.get_environment("CYBERSAND_ENGINE_RENDER_LOOKAHEAD"),
		"submission_events":submission_events,"observations":rows,
		"engine_atomic_admission":Transaction.atomic_admission_supported(),
		"refusal_framebuffers":refusal_framebuffers,
		"fallback_ui":fallback_ui,"mount_samples":mount_samples,
		"unsubmitted_material_picking":unsubmitted_material_picking,"held_limb_placement":held_limb_placement,
		"input_hashes":{},"scope":"stock graphical paused multipart placement" if stock_limb_only else "native mounted graphical draw admission; first framebuffer read; no GPU completion or physical NVIDIA acceptance"}
	for path: String in ["res://scripts/main.gd","res://scripts/shared_workbench.gd","res://scripts/workbench_presentation_submission.gd",
			"res://scripts/physical_actor_session.gd","res://scripts/physical_actor_rig.gd",
			"res://scripts/workbench_actor_interaction.gd","res://scripts/workbench_actor_manipulator.gd",
			"res://tests/test_workbench_presentation_submission.gd"]:
		result.input_hashes[path] = FileAccess.get_sha256(path)
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"  ")+"\n")
	for key: String in saved_env: OS.set_environment(key,str(saved_env[key]))
	if is_instance_valid(host): host.queue_free()
	print("ACTUAL_SUBMISSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
