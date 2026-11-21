extends SceneTree

# Actual ordinary Shared Workbench: its native worker, prepared owner, Rapier
# space, render path and editor execute every operation below. The focus stub
# substitutes only the unavailable OS focus predicate during headless runs.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
class FocusHost extends "res://scripts/main.gd":
	var test_focus := true
	var reject_next_preparation := false
	var rejected_preparations: Array[Dictionary] = []
	var sample_refusals: Array[Dictionary] = []
	var inspect_refused_actor := 0
	var refused_live_states: Array[Dictionary] = []
	func _actor_window_has_focus() -> bool:
		return test_focus and (DisplayServer.get_name() == "headless" or super._actor_window_has_focus())
	func _advance_prepared_physical_candidate() -> void:
		if not reject_next_preparation:
			super._advance_prepared_physical_candidate()
			return
		# Exercise the real prepared-owner refusal protocol once the actual
		# native candidate exists. No World/cells/body values are substituted.
		if _pending_physical_candidate == null or _prepared_physical_ready_sent: return
		var publication: Dictionary = simulation_worker.prepared_physical_liquid_values()
		if publication.is_empty() or int(publication.get("serial",0)) != int(pending_microscenario_apply.get("serial",-1)) \
				or int(publication.get("instance_id",0)) != _pending_physical_candidate.get_instance_id(): return
		if simulation_worker.complete_prepared_physical_liquid(publication,false,"actor-composition prepared-adoption refusal fixture"):
			rejected_preparations.append({"serial":int(publication.serial),"instance_id":int(publication.instance_id)})
			_prepared_physical_ready_sent = true
			reject_next_preparation = false
	func _publish_physical_body_state() -> void:
		super._publish_physical_body_state()
		if simulation_worker == null or physical_actor_session == null: return
		simulation_worker._mutex.lock()
		var admission: Dictionary = simulation_worker._physical_usable_admission.duplicate(true)
		simulation_worker._mutex.unlock()
		if admission.get("status","") != "refused" or admission.get("frame_admitted",true): return
		if not sample_refusals.is_empty() and sample_refusals.back().get("reason") == admission.get("reason") \
			and sample_refusals.back().get("epoch")==admission.get("epoch") \
			and sample_refusals.back().get("rapier_tick")==physical_actor_session.tick: return
		admission["rapier_tick"] = physical_actor_session.tick
		admission["waiting_sample"] = _workbench_wait_sample
		sample_refusals.append(admission)
		print("WB_ACTOR_COMPOSE_SAMPLE_REFUSAL ",JSON.stringify(admission))
	func consume_worker_snapshot() -> void:
		var watched_serial: int = pending_microscenario_apply.get("serial",0) if inspect_refused_actor>0 else 0
		super.consume_worker_snapshot()
		if watched_serial==0 or not pending_microscenario_apply.is_empty() \
			or int(tower_context.get("scenario_request_serial",0))!=watched_serial \
			or bool(tower_context.get("scenario_request_applied",true)) or physical_actor_session==null: return
		var body: Dictionary = physical_actor_session.workbench_actor_state(inspect_refused_actor)
		var view: Dictionary = physical_actor_session.workbench_control(inspect_refused_actor)
		refused_live_states.append({"serial":watched_serial,"session":physical_actor_session.get_instance_id(),
			"paused":paused,"parts":body.get("retained_parts",[]),"generation":view.get("generation",-1),
			"energy":view.get("observation",{}).get("energy",-1.0)})
		inspect_refused_actor = 0

var host: Control
var ui: Control
var checks := 0
var failures: Array[String] = []
var phases: Array = []
var actors: Dictionary = {}
var equipment_receipts: Dictionary = {}
var screenshots: Array = []
var preservation_notes: Array[String] = []
var save_name := "actor-compose-589-evaluation"
var started_msec := 0
var sample_enabled := false
var maximum_frame_gap_usec := 0
var previous_frame_usec := 0
var canvas_pointer_events := 0
var canvas_motion_events := 0
var injected_frame_refusal := false
const PAINT_POINT := Vector2i(218,344)


func _initialize() -> void:
	started_msec = Time.get_ticks_msec()
	run.call_deferred()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if previous_frame_usec > 0: maximum_frame_gap_usec = maxi(maximum_frame_gap_usec,now-previous_frame_usec)
	previous_frame_usec = now
	if sample_enabled: sample()
	return false


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WB_ACTOR_COMPOSE: " + label)
	return ok


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	var report_at := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec() >= report_at:
			print("WB_ACTOR_COMPOSE_WAIT ",label," / ",ui.message if ui != null else "opening", " / ",host.microscenario_error if host != null else "")
			print("WB_ACTOR_COMPOSE_WAIT_STATE ",JSON.stringify(wait_state()))
			report_at = Time.get_ticks_msec()+10000
		await process_frame
	return check(false,label+" / "+str(ui.message if ui != null else "no Workbench")+" / "+str(host.microscenario_error if host != null else "no host"))


func wait_state() -> Dictionary:
	if host == null or ui == null: return {}
	var snapshot: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
	var session = host.physical_actor_session
	var context: Dictionary = snapshot.lab_context if snapshot != null else {}
	var state := {"paused":host.paused,"step_pending":ui.step_pending,"step_requested":ui.step_requested,
		"terrain_ready":host._physical_terrain_ready,"actor_reset_receipt":host._actor_reset_receipt,
		"pending_transaction":not host.pending_microscenario_apply.is_empty(),
		"pending_physical_owner":host._pending_physical_candidate!=null,
		"native_tick_displayed":native_tick(),"native_tick_latest":snapshot.tick_index if snapshot != null else -1,
		"native_paused":snapshot.paused if snapshot != null else false,
		"rigid_epoch":snapshot.rigid_body_epoch if snapshot != null else -1,
		"expected_epoch":host._body_owner_epoch(),"workbench_refusal":str(context.get("workbench_refusal","")),
		"waiting_sample":host._workbench_wait_sample,"completed_sample":context.get("workbench_completed_sample",-1),
		"worker_failed":host.simulation_worker.has_failed(),"busy":ui.busy()}
	if session != null:
		state.merge({"rapier_tick":session.tick,"run_id":session.run_id,"session_suspended":session._suspended,
			"session_error":session.last_error,"manual_steps":session.bridge.manual_step_count(),
			"terrain_chunks":session.bridge.pending_hard_surface_chunks(),
			"session_generations":Array(session._generations),
			"required_hard_surface_revision":context.get("workbench_hard_surface_revision",-1),
			"published_hard_surface_revision":snapshot.hard_surface_revision if snapshot != null else -1,
			"installed_hard_surface_revision":host.last_hard_surface_revision})
	# Copy diagnostic values while holding the existing worker mutex. This does
	# not query or mutate the World or change sample/admission scheduling.
	var worker = host.simulation_worker
	worker._mutex.lock()
	var body_states: Variant = worker._workbench_sample.get("states",PackedFloat64Array())
	var equipment_rows: Array = []
	for row: Dictionary in worker._physical_usable_frame.get("actors",[]):
		equipment_rows.append({"actor_id":row.get("actor_id",-1),"generation":row.get("generation",-1),"active":row.get("active",false)})
	state.merge({"worker_sample":int(body_states[10]) if body_states.size()>10 else -1,
		"worker_prepared_sample":worker._workbench_prepared_sample,
		"worker_completed_sample":worker._workbench_completed_sample,
		"worker_paused":worker._paused,
		"usable_admission":worker._physical_usable_admission.duplicate(true),
		"usable_rows":equipment_rows,
		"cancelled_generations":Array(worker._physical_usable_cancelled_generations),
		"prepared_frame_hold":not worker._prepared_physical_frame_hold.is_empty()})
	worker._mutex.unlock()
	return state


func installed() -> bool:
	return ui != null and not ui.applied.is_empty() and not ui.busy() and host.pending_microscenario_apply.is_empty()


func native_tick() -> int:
	return int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else -1


func physical_tick() -> int:
	return int(host.physical_actor_session.tick) if host.physical_actor_session != null else -1


func sample() -> void:
	if ui == null or host.physical_actor_session == null: return
	for actor: Dictionary in ui.applied.actors:
		var id := int(actor.id)
		var view: Dictionary = ui.actor_observation(id)
		if view.is_empty(): continue
		var pos: Vector2 = view.get("position",Vector2.ZERO)
		if not actors.has(id):
			actors[id] = {"model":str(actor.model),"first":pos,"last":pos,"min":pos,"max":pos,
				"support_samples":0,"peak_speed":0.0,"accepted_uses":0,"max_recoveries":0}
		var row: Dictionary = actors[id]
		row.last = pos
		row.min = Vector2(row.min).min(pos)
		row.max = Vector2(row.max).max(pos)
		row.peak_speed = maxf(float(row.peak_speed),Vector2(view.get("velocity",Vector2.ZERO)).length())
		if bool(view.get("grounded",false)): row.support_samples += 1
		var equipment: Dictionary = view.get("equipment",{})
		row.accepted_uses = maxi(int(row.accepted_uses),int(equipment.get("accepted_uses",0)))
		var receipt: Dictionary = equipment.get("last_receipt",{})
		if not receipt.is_empty() and bool(receipt.get("accepted",false)) and bool(receipt.get("consumed",false)):
			equipment_receipts[str(receipt.get("request_id",JSON.stringify(receipt)))] = receipt.duplicate(true)
		var controller: Dictionary = host.physical_actor_session.workbench_control(id)
		row.max_recoveries = maxi(int(row.max_recoveries),int(controller.get("diagnostics",{}).get("script",{}).get("recovery_count",0)))


func phase(label: String, ticks: int) -> bool:
	var first_native := native_tick()
	var first_physical := physical_tick()
	var begin := Time.get_ticks_usec()
	# One completed native tick can still be awaiting render publication. A
	# long Rapier phase cannot pass merely because one cellular tick happened
	# before the native owner stalled on a refused actor sample.
	var required_native := maxi(1,ticks-1)
	var passed := await until(func() -> bool: return physical_tick() >= first_physical+ticks \
		and native_tick()>=first_native+required_native,label)
	phases.append({"label":label,"elapsed_usec":Time.get_ticks_usec()-begin,
		"requested_rapier_ticks":ticks,"native_ticks":native_tick()-first_native,"rapier_ticks":physical_tick()-first_physical,
		"frame_ms":float(host.frame_time_ms),"upload_ms":float(host.upload_time_ms),
		"memory_static_bytes":OS.get_static_memory_usage(),"passed":passed})
	check(native_tick()>=first_native+required_native,label+": coupled cellular owner advanced the requested interval")
	return passed


func screenshot(label: String, caption: String) -> void:
	var folder := OS.get_environment("CYBERSAND_ACTOR_COMPOSITION_CAPTURE")
	if folder.is_empty(): return
	if not check(DisplayServer.get_name() != "headless","framebuffer evidence requires graphical execution"): return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label+".png")
	if check(root.get_texture().get_image().save_png(path)==OK,"actual Workbench framebuffer: "+label):
		screenshots.append({"path":path,"caption":caption,"native_tick":native_tick(),"rapier_tick":physical_tick()})


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func observe_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton: canvas_pointer_events += 1
	elif event is InputEventMouseMotion: canvas_motion_events += 1


func click_canvas(cell: Vector2i, button: MouseButton = MOUSE_BUTTON_LEFT) -> bool:
	# Drive the real viewport so Main's input guards, TextureRect hit testing,
	# gui_input and PAINT.world_input all execute. Never call bench.paint here.
	var content: Rect2 = host.view_content_rect()
	var local: Vector2 = content.position + (Vector2(cell)+Vector2(0.5,0.5)-host.camera_origin.floor()) \
		* content.size / Vector2(host.current_view_size)
	if not check(host.view_pixel_from_local_point(local)+Vector2i(host.camera_origin.floor())==cell,
		"actual canvas pointer maps to the requested material cell"): return false
	var position: Vector2 = host.world_view.get_global_transform_with_canvas() * local
	var before := canvas_pointer_events
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if down else 0
		event.pressed = down
		host.world_view.get_viewport().push_input(event,true)
		await process_frame
	return check(canvas_pointer_events>=before+2,"pointer press/release reached the actual Workbench canvas gui_input")


func fast_canvas_stroke(points: Array[Vector2i]) -> bool:
	var content: Rect2 = host.view_content_rect()
	var screen: Array[Vector2] = []
	for cell: Vector2i in points:
		var local: Vector2 = content.position + (Vector2(cell)+Vector2(0.5,0.5)-host.camera_origin.floor()) \
			* content.size / Vector2(host.current_view_size)
		if not check(host.view_pixel_from_local_point(local)+Vector2i(host.camera_origin.floor())==cell,
			"fast gesture maps its sampled cell "+str(cell)): return false
		screen.append(host.world_view.get_global_transform_with_canvas() * local)
	var buttons_before := canvas_pointer_events
	var motion_before := canvas_motion_events
	var process_frame_before := Engine.get_process_frames()
	# All three physical pointer events enter the real viewport without yielding
	# a process frame. The endpoint is deliberately distinct from the motion.
	var press := InputEventMouseButton.new()
	press.position = screen[0]
	press.global_position = screen[0]
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	host.world_view.get_viewport().push_input(press,true)
	var motion := InputEventMouseMotion.new()
	motion.position = screen[1]
	motion.global_position = screen[1]
	motion.relative = screen[1]-screen[0]
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	host.world_view.get_viewport().push_input(motion,true)
	var release := InputEventMouseButton.new()
	release.position = screen[2]
	release.global_position = screen[2]
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	host.world_view.get_viewport().push_input(release,true)
	return check(Engine.get_process_frames()==process_frame_before and canvas_pointer_events>=buttons_before+2 \
		and canvas_motion_events>=motion_before+1,"fast press/motion/release reaches canvas within one process frame")


func body_rids(id: int) -> Array:
	var result: Array = []
	var slot: int = host.physical_actor_session.slot_for_instance(id)
	if slot >= 0:
		for body: RigidBody2D in host.physical_actor_session._rigs[slot].bodies(): result.append(body.get_rid())
	return result


func inspect_runtime() -> void:
	var session = host.physical_actor_session
	check(session != null and session.active() and host._physical_terrain_ready,"prepared mixed graph adopted against native terrain")
	var expected_bodies := 0
	var expected_joints := 0
	for actor: Dictionary in ui.applied.actors:
		var data := Catalog.definition(str(actor.model))
		expected_bodies += data.parts.size()
		expected_joints += data.joints.size()
	check(session.bodies().size()==expected_bodies and expected_bodies==24,"all 24 physical parts including equipment exist without truncation")
	var observed_joints := 0
	for rig in session._rigs: observed_joints += rig._joints.size()
	check(observed_joints==expected_joints and observed_joints>0,"authored Rapier joints exist in the one shared session")
	check(session.bridge == host.rapier_bridge,"Workbench and actors use the same Rapier authority")
	check(ui.pilot_id()==1,"authored flyer is the initial human pilot")
	check(ui.actor_observation(2).producer=="demo" and ui.actor_observation(4).producer=="demo" \
		and ui.actor_observation(5).producer=="policy","scripted ground, flight and policy retain independent producers")
	check(ui.actor_observation(6).producer=="passive","compatible barrel remains passive")
	var sample_packet: Dictionary = session.pack_workbench_sample()
	check(sample_packet.bodies.size()==expected_bodies and sample_packet.states.size()/17==expected_bodies,
		"all prepared parts have concrete native-mask publication identities")
	var masks := {}
	for offset: int in range(0,sample_packet.states.size(),17): masks[int(sample_packet.states[offset])] = true
	check(masks.size()==expected_bodies,"native body masks are distinct")


func pending_intent_lifecycle() -> void:
	# A refused named workshop must not rename/reframe a later unrelated map.
	var label := "actor-composition-intent-%d" % OS.get_process_id()
	ui._name.text = label
	ui.set_camera(0)
	var old_session = host.physical_actor_session
	var old_setup: Dictionary = ui.applied.duplicate(true)
	host.reject_next_preparation = true
	check(ui.load_mixed_actor_workshop(),"ordinary workshop action prepares before injected adoption refusal")
	check(ui._pending_actor_workshop,"workshop has a real pending presentation intent")
	if not await until(installed,"refused workshop owner settles"): return
	await process_frame
	check(host.rejected_preparations.size()==1 and not host.reject_next_preparation,
		"real native preparation received the explicit readiness refusal")
	check(host.physical_actor_session==old_session and ui.applied==old_setup,
		"refused workshop preserves old owner and complete authored map")
	check(not ui._pending_actor_workshop and ui._pending_pilot_id==-1,
		"refused workshop clears only its pending pilot and presentation intents")
	check(ui.apply(ui.applied,true),"unrelated successful preparation after workshop refusal")
	if not await until(installed,"unrelated authoring adoption"): return
	check(ui._name.text==label and ui._camera.selected==0 and ui.pilot_id()==1,
		"refused workshop cannot rename, reframe or change pilot on a later success")
	# A refused missing-model pilot would otherwise leak its reserved next ID
	# into a later independent placement of a different human-source actor.
	ui.select_instance(1)
	host.reject_next_preparation = true
	var next_id: int = ui.applied.next_id
	check(ui.pilot_model("needle"),"missing-model pilot action prepares before injected refusal")
	check(ui._pending_pilot_id==next_id,"pilot request has the candidate's pending identity")
	if not await until(installed,"refused pilot replacement settles"): return
	await process_frame
	check(host.rejected_preparations.size()==2 and ui.pilot_id()==1 and ui._pending_pilot_id==-1,
		"failed pilot replacement preserves pilot and retires the pending identity")
	check(ui.place("midge",Vector2(940,240)),"place unrelated human actor after failed pilot replacement")
	if not await until(installed,"unrelated new actor adoption"): return
	check(ui.selected_id()==next_id and ui.actor(ui.applied,next_id).model=="midge" and ui.pilot_id()==1,
		"reused authored allocation cannot inherit a refused pilot request")
	check(ui.remove_selected(),"remove temporary independently inspected actor")
	if not await until(installed,"temporary actor deletion"): return
	check(ui.actor(ui.applied,next_id).is_empty() and ui.applied.actors.size()==6 and ui.pilot_id()==1,
		"deletion retires only the temporary actor and preserves original pilot")
	ui.select_instance(1)


func first_slot_equipment_guard() -> void:
	# Slot zero used to be treated as the universal human equipment owner.
	# Reorder the same authored cast so its equipped Runner occupies that slot,
	# while Midge remains the explicit human pilot in slot one.
	var candidate: Dictionary = ui.applied.duplicate(true)
	var runner: Dictionary = candidate.actors.pop_at(1)
	candidate.actors.push_front(runner)
	check(ui.apply(candidate,true),"prepare equipped scripted NPC as the first physical slot")
	if not await until(installed,"first-slot NPC adoption"): return
	var session = host.physical_actor_session
	check(session.slot_for_instance(2)==0 and session.slot_for_instance(1)==1 and ui.pilot_id()==1,
		"equipped NPC is first slot while human pilot remains independent")
	check(ui.toggle_pause(),"run first-slot NPC pointer adversary")
	await phase("first-slot equipped NPC has active scripted authority",12)
	var before: Dictionary = ui.actor_observation(2)
	var counters: Dictionary = session.workbench_control(2)
	check(int(before.equipment.usable_index)>=0 and before.producer=="demo" and int(before.lease_remaining)>0,
		"first-slot NPC has a real item and live scripted lease")
	check(not host.actor_equipment_active(),"equipped first-slot NPC cannot claim the human PAINT pointer")
	host._publish_actor_usable_buttons(true,false)
	host._publish_actor_usable_buttons(false,true)
	host._publish_actor_usable_buttons(false,false)
	var after: Dictionary = ui.actor_observation(2)
	var later: Dictionary = session.workbench_control(2)
	check(before.control_generation==after.control_generation and before.last_sequence==after.last_sequence \
		and before.lease_remaining==after.lease_remaining and counters.accepted==later.accepted and counters.rejected==later.rejected,
		"legacy pointer adapter cannot consume or cancel first-slot NPC command authority")
	var generations: PackedInt64Array = session._generations.duplicate()
	var same_frame := Engine.get_process_frames()
	check(ui.toggle_pause() and ui.toggle_pause() and same_frame==Engine.get_process_frames(),
		"explicit Pause and Resume can occur within one process frame")
	var all_revoked := true
	for index: int in generations.size():
		all_revoked = all_revoked and session._generations[index]>generations[index]
	check(all_revoked,"same-frame pause/resume synchronously revokes every producer generation")
	if not all_revoked:
		for index: int in 3: await process_frame
		print("WB_ACTOR_COMPOSE_PAUSE_ADVERSARY ",JSON.stringify(wait_state()))
	await phase("rapid pause/resume keeps native and Rapier coupled",12)
	var retained_setup: Dictionary = ui.applied.duplicate(true)
	var retained_parts: Array = ui.body_state(2).retained_parts.duplicate(true)
	var retained_rids := body_rids(2)
	var retained_energy: float = ui.actor_observation(2).energy
	var retained_generation: int = session.workbench_control(2).generation
	host.inspect_refused_actor = 2
	host.reject_next_preparation = true
	check(ui.apply(retained_setup,true),"prepare retained actors while their controllers are running")
	if not await until(installed,"running actor preparation refusal settles"): return
	check(host.physical_actor_session==session and body_rids(2)==retained_rids and ui.applied==retained_setup,
		"refused running preparation preserves the complete authored map and existing physical owner")
	if check(not host.refused_live_states.is_empty(),"observe rollback at the actual owner-restoration boundary"):
		var refusal: Dictionary = host.refused_live_states.back()
		check(refusal.session==session.get_instance_id() and refusal.parts==retained_parts \
			and is_equal_approx(float(refusal.energy),retained_energy),
			"failed preparation restores the exact retained pose, momentum and resource state")
		check(not bool(refusal.paused) and int(refusal.generation)>retained_generation,
			"failed running preparation restores play with fresh producer authority")
	await phase("refused running preparation resumes the same coupled cast",12)
	check(ui.toggle_pause(),"pause after first-slot equipment guard")
	await until(func() -> bool: return host.latest_snapshot.paused,"first-slot guard pause acknowledgement")


func custom_item_handback_lifetime() -> void:
	var original: Dictionary = ui.applied.duplicate(true)
	check(ui.apply_actor_equipment(5,3),"author a nondefault usable on the Human-default Buggy")
	if not await until(installed,"custom starting item preparation"): return
	var control: Dictionary = Catalog.control_for(ui.actor(ui.applied,5))
	control.source = "human"
	check(ui.set_actor_control(5,control) and ui.pilot_instance(5),"pilot custom-item actor without remembered prior producer")
	check(not ui._pilot_returns.has(5) and int(ui.actor_observation(5).equipment.usable_index)==3,
		"fallback hand-back fixture has no prior-source entry and a real custom item")
	var parts := body_rids(5)
	var before: Dictionary = ui.actor_observation(5)
	check(ui.hand_back_pilot(),"Human-default actor hands back with its custom starting item")
	var after: Dictionary = ui.actor_observation(5)
	check(body_rids(5)==parts and after.producer=="demo" and int(after.equipment.usable_index)==3 \
		and after.equipment.instance_id==before.equipment.instance_id and after.energy==before.energy,
		"fallback source hand-back retains actual custom equipment, resources and body identity")
	control = Catalog.control_for(ui.actor(ui.applied,5))
	control.source = "policy"
	control.policy = "external"
	control.decision_ticks = 12
	check(ui.set_actor_control(5,control) and ui.pilot_instance(5),"remember an explicit prior policy in the current authored world")
	check(ui._pilot_returns.has(5) and ui._pilot_returns[5].source=="policy" \
		and ui._pilot_returns[5].decision_ticks==12,"current world's prior-source record is established")
	var new_start := original.duplicate(true)
	var new_control := Catalog.default_control("stuntbuggy")
	new_control.usable_index = 3
	ui.actor(new_start,5).control = new_control
	new_start.selected = 5
	check(ui.apply(new_start),"install a different authored start reusing the logical ID")
	if not await until(installed,"new authored control lifetime"): return
	check(not ui._pilot_returns.has(5) and ui.pilot_id()==5,
		"new authored installation retires transient prior-source records")
	check(ui.hand_back_pilot(),"new Human actor uses its own hand-back defaults")
	var restored: Dictionary = Catalog.control_for(ui.actor(ui.applied,5))
	check(restored.source=="scripted" and restored.policy=="fixture" and int(restored.decision_ticks)==6 \
		and int(restored.usable_index)==3,"prior world's policy and cadence cannot cross authored installation")
	check(ui.apply(original),"restore the supplied workshop composition after lifetime cases")
	if not await until(installed,"original authored cast restored"): return
	check(ui.pilot_id()==1 and ui.applied.actors==original.actors,
		"lifetime cases leave the original cast and controller configuration intact")


func handoff_and_inspection() -> void:
	var session = host.physical_actor_session
	var source_run: String = session.run_id
	var human_before: Dictionary = session.workbench_control(1)
	check(ui.select_instance(2),"select scripted runner for inspection")
	check(ui.pilot_id()==1 and ui.actor_observation(2).producer=="demo","inspection does not take over an NPC")
	ui.open_actor_composition()
	if not await phase("NPCs continue with composition panel visible",30): return
	check(ui.actor_observation(2).producer=="demo" and session.workbench_control(2).accepted>0,"visible panel retains autonomous authority")
	if ui._actor_panel != null: ui._actor_panel.hide()
	var parts := body_rids(2)
	var before: Dictionary = ui.actor_observation(2)
	var pose: Dictionary = ui.body_state(2)
	check(ui.pilot_instance(2),"take over moving runner")
	var after: Dictionary = ui.actor_observation(2)
	check(host.physical_actor_session==session and session.run_id==source_run and parts==body_rids(2),
		"takeover preserves session, run and every body RID")
	check(ui.body_state(2).retained_parts==pose.retained_parts,"takeover preserves every part pose and momentum synchronously")
	check(after.energy==before.energy and after.equipment.instance_id==before.equipment.instance_id,
		"takeover preserves resource reserve and existing equipment identity")
	check(int(after.control_generation)>int(before.control_generation) and after.producer=="human",
		"takeover revokes old controller generation")
	check(session.workbench_control(1).generation>human_before.generation,"previous human input lease cancelled")
	if not await until(func() -> bool: return not host._actor_input_rearm,
		"new human pilot observes released controls before accepting input"): return
	var human_accepted: int = session.workbench_control(2).accepted
	key(KEY_D,true)
	await phase("human ground actor coexists with flight and policy",24)
	var held: Dictionary = ui.actor_observation(2)
	check(session.workbench_control(2).accepted>human_accepted and Vector2(held.get("action",{}).get("move",Vector2.ZERO)).x>0.0,
		"held human D is admitted and applied to the intended ground actor")
	key(KEY_D,false)
	await screenshot("03-human-ground-pilot","Runner #2 is now human controlled; Skimmer #4 and policy Buggy #5 remain independent.")
	check(ui.hand_back_pilot(),"hand back physical runner to original local script")
	check(body_rids(2)==parts and ui.actor_observation(2).producer=="demo","hand-back restores script without body replacement")
	check(ui.pilot_instance(1),"return human pilot to the existing flyer")
	var control: Dictionary = Catalog.control_for(ui.actor(ui.applied,3))
	control.enabled = false
	var crawler_parts := body_rids(3)
	check(ui.set_actor_control(3,control),"stop only crawler decisions")
	var accepted_before: int = session.workbench_control(3).accepted
	var flight_before: int = session.workbench_control(4).accepted
	await phase("one stopped NPC does not block another",24)
	check(body_rids(3)==crawler_parts and session.workbench_control(3).accepted==accepted_before,
		"stopped controller leaves its body simulated without accepting autonomous actions")
	check(session.workbench_control(4).accepted>flight_before,"other flight controller keeps issuing actions")
	control.enabled = true
	check(ui.set_actor_control(3,control),"restart crawler decisions independently")
	# Use the ordinary focus cancellation hook; no command is directly mutated.
	key(KEY_W,true)
	await process_frame
	host.test_focus = false
	await process_frame
	await process_frame
	check(ui.actor_observation(1).lease_remaining==0 and host._actor_input_rearm,"focus loss cancels affected human input")
	var scripted_before: int = session.workbench_control(2).accepted
	await phase("focus loss leaves autonomous producers alive",24)
	check(session.workbench_control(2).accepted>scripted_before,"focus loss cannot retire NPCs")
	host.test_focus = true
	await process_frame
	check(ui.actor_observation(1).lease_remaining==0,"held human input cannot rearm on focus return")
	key(KEY_W,false)
	await process_frame
	# Inline Details uses a non-focusable toolbar button. Opening it must
	# retire the held human lease even when no OS or text focus event fires.
	if not await until(func() -> bool: return not host._actor_input_rearm,
		"released controls rearm before inline Details check"): return
	var details_button: Button
	for candidate: Node in ui.find_children("*","Button",true,false):
		if candidate.text == "Details": details_button = candidate
	if not check(details_button != null and not ui._details.visible,"ordinary inline Details starts closed"): return
	key(KEY_W,true)
	await phase("human pilot holds drive before opening Details",6)
	check(ui.actor_observation(1).lease_remaining>0 and not host._actor_input_rearm,
		"human lease is active before Details opens")
	var details_generation: int = session.workbench_control(1).generation
	details_button.pressed.emit()
	check(ui._details.visible and ui.actor_observation(1).lease_remaining==0 and host._actor_input_rearm
		and session.workbench_control(1).generation>details_generation,
		"opening inline Details revokes only the held human lease")
	scripted_before = session.workbench_control(2).accepted
	await phase("NPCs continue with inline Details open and human key held",12)
	check(session.workbench_control(2).accepted>scripted_before and ui.actor_observation(1).lease_remaining==0,
		"Details preserves autonomous decisions and cannot rearm a held human key")
	details_button.pressed.emit()
	await process_frame
	check(not ui._details.visible and ui.actor_observation(1).lease_remaining==0 and host._actor_input_rearm,
		"closing Details cannot authorize the still-held human key")
	key(KEY_W,false)
	if not await until(func() -> bool: return not host._actor_input_rearm,
		"Details cancellation rearms only after controls are released"): return
	var rearmed_accepted: int = session.workbench_control(1).accepted
	key(KEY_W,true)
	await phase("fresh human input after Details release",6)
	check(session.workbench_control(1).accepted>rearmed_accepted and ui.actor_observation(1).lease_remaining>0,
		"fresh human drive works after Details cancellation and neutral rearm")
	key(KEY_W,false)
	await process_frame
	for panel: Dictionary in [
		{"name":"Water Lab", "open":ui.water_lab.open, "window":ui.water_lab.window},
		{"name":"Generator", "open":ui._generated_dialog.open_new, "window":ui._generated_dialog},
		{"name":"Flatten confirmation", "open":ui._flatten_pressed, "window":ui._flatten_confirmation},
	]:
		if not await until(func() -> bool: return not host._actor_input_rearm,
			"released controls rearm before " + panel.name): return
		key(KEY_W,true)
		await phase("human drive before " + panel.name,6)
		check(ui.actor_observation(1).lease_remaining>0,"human lease is active before " + panel.name)
		var panel_generation: int = session.workbench_control(1).generation
		panel.open.call()
		check(panel.window.visible and ui.actor_observation(1).lease_remaining==0 and host._actor_input_rearm
			and session.workbench_control(1).generation>panel_generation,
			"opening " + panel.name + " explicitly retires held human authority")
		scripted_before = session.workbench_control(2).accepted
		await phase("NPCs continue with " + panel.name,12)
		check(session.workbench_control(2).accepted>scripted_before and ui.actor_observation(1).lease_remaining==0,
			panel.name + " leaves NPCs active and held human controls cancelled")
		panel.window.hide()
		await process_frame
		check(ui.actor_observation(1).lease_remaining==0 and host._actor_input_rearm,
			"closing " + panel.name + " cannot authorize held input")
		key(KEY_W,false)
		await process_frame


func external_policy() -> void:
	var session = host.physical_actor_session
	var control: Dictionary = Catalog.control_for(ui.actor(ui.applied,5))
	control.policy = "external"
	check(ui.set_actor_control(5,control),"select external adapter independently of fixture")
	var view: Dictionary = ui.actor_observation(5,true)
	if not check(not view.is_empty() and view.representation=="articulated-rapier","issue copied physical policy observation"): return
	var packet: Dictionary = Session.make_command(view,int(view.last_sequence)+1,{"move":Vector2(0,-0.7),"effort":0.8},6)
	check(not ui.submit_actor_policy(2,packet),"wrong authored instance cannot steal a policy output")
	var forged := packet.duplicate(true)
	forged.actor_id = int(ui.actor_observation(2).actor_id)
	check(not ui.submit_actor_policy(2,forged),"scripted producer refuses external policy submission")
	var sampled := packet.duplicate(true)
	sampled.kind = "actor_action"
	check(not ui.submit_actor_policy(5,sampled),"sampled actor vocabulary cannot impersonate physical action")
	check(ui.submit_actor_policy(5,packet),"fresh observed command accepted by actual policy actor")
	check(not ui.submit_actor_policy(5,packet),"duplicate action sequence refused")
	var changed := packet.duplicate(true)
	changed.action.move = Vector2(-1,1)
	check(packet.action.move != changed.action.move,"test producer retains owned packet copies")
	var late := Session.make_command(view,int(view.last_sequence)+100,{"move":Vector2.RIGHT},6)
	await phase("bounded policy lease expires while unrelated actors progress",24)
	check(ui.actor_observation(5).lease_remaining==0,"external actor lease expires without a new decision")
	check(not ui.submit_actor_policy(5,late),"delayed reply refused after observation expiry")
	var previous: Dictionary = ui.actor_observation(5,true)
	var stale := Session.make_command(previous,int(previous.last_sequence)+100,{"move":Vector2.RIGHT},12)
	var rids := body_rids(5)
	check(ui.pilot_instance(5),"human can take over external actor")
	check(not ui.submit_actor_policy(5,stale),"pre-takeover policy reply cannot regain ownership")
	check(body_rids(5)==rids,"policy takeover also preserves articulated physics")
	check(ui.hand_back_pilot(),"external actor can hand back to policy")
	check(not ui.submit_actor_policy(5,stale),"old observation stays revoked after policy returns")
	control.policy = "fixture"
	check(ui.set_actor_control(5,control),"restore deterministic fresh-observation test producer")
	check(ui.pilot_instance(1),"resume flyer as intended human actor")


func paused_editor() -> void:
	var before_serial: int = int(host.latest_snapshot.serial)
	check(ui.toggle_pause(),"pause actual mixed workshop")
	# A retained paused snapshot can predate this Pause request when rendering
	# lags worker publication. Require a NEW worker acknowledgement, not only
	# the previously cached paused bit plus immediate session suspension.
	if not await until(func() -> bool: return host.paused and int(host.latest_snapshot.serial)>before_serial
		and host.latest_snapshot.paused and bool(ui.actor_observation(2).suspended),"both simulation owners acknowledged this pause"): return
	var stopped_native := native_tick()
	var stopped_physics := physical_tick()
	for i: int in 6: await process_frame
	if native_tick()!=stopped_native or physical_tick()!=stopped_physics:
		print("WB_ACTOR_COMPOSE_PAUSE_DRIFT ",JSON.stringify({"native_before":stopped_native,
			"native_after":native_tick(),"rapier_before":stopped_physics,"rapier_after":physical_tick(),
			"host_paused":host.paused,"latest_paused":host.latest_snapshot.paused,
			"latest_serial":host.latest_snapshot.serial,"worker_paused":host.simulation_worker._paused,
			"session_suspended":host.physical_actor_session._suspended}))
	check(native_tick()==stopped_native and physical_tick()==stopped_physics,"pause freezes native and Rapier progression")
	var session = host.physical_actor_session
	var editor: Control = ui.paint_editor
	check(editor.commit_cells(PackedInt32Array([650,100,58,651,100,58]),"Actor workshop regression paint"),"ordinary PAINT edit while NPCs paused")
	if not await until(func() -> bool: return not editor.busy() and not host.simulation_worker.paint_state().busy,"paint acknowledgement"): return
	check(editor.history_available("undo"),"actor composition preserves PAINT undo authority")
	check(editor.undo(),"Undo actual paused paint")
	if not await until(func() -> bool: return not editor.busy() and not host.simulation_worker.paint_state().busy,"Undo acknowledgement"): return
	check(editor.redo(),"Redo actual paused paint")
	await until(func() -> bool: return not editor.busy() and not host.simulation_worker.paint_state().busy,"Redo acknowledgement")
	check(host.physical_actor_session==session,"paused editing does not reconstruct actors")
	check(ui.step_once(),"ordinary Step accepts the mixed roster")
	await until(func() -> bool: return not ui.step_pending and native_tick()>stopped_native,"one Step consumed")
	check(host.paused and physical_tick()>stopped_physics,"Step advances physical bodies and returns paused")
	check(ui.toggle_pause(),"resume actual mixed workshop")
	await phase("paused edit then resumed controllers",24)
	check(ui.select_instance(3),"inspect crawler while painting")
	var before: int = host.physical_actor_session.workbench_control(2).accepted
	editor.select_tool("Brush")
	editor.select_material(58)
	ui.set_camera(2)
	await process_frame
	if not await click_canvas(PAINT_POINT): return
	if not await until(func() -> bool: return host.image.get_pixelv(PAINT_POINT).r8==58,
		"live pointer Brush reaches native material publication"): return
	check(ui.applied.edits.any(func(stamp: Array) -> bool: return int(stamp[0])==PAINT_POINT.x and int(stamp[1])==PAINT_POINT.y and int(stamp[3])==58),
		"live pointer Brush is retained in the authored start")
	await phase("live terrain editing and independently scheduled NPCs",90)
	check(host.physical_actor_session.workbench_control(2).accepted>before,"NPC decisions survive terrain authoring")
	check(ui.actor_observation(3).producer=="demo" and ui.pilot_id()==1,"paint pointer inspection cannot silently take over NPC")
	check(not editor.history_available("undo"),"live simulation does not claim paused Undo snapshots")
	var fast_points: Array[Vector2i] = [Vector2i(600,160),Vector2i(630,160),Vector2i(660,160)]
	if fast_canvas_stroke(fast_points):
		await until(func() -> bool: return fast_points.all(func(cell: Vector2i) -> bool: return host.image.get_pixelv(cell).r8==58),
			"all same-frame live stroke samples and the release endpoint reach native cells")
		check(fast_points.all(func(cell: Vector2i) -> bool: return ui.applied.edits.any(func(stamp: Array) -> bool:
			return int(stamp[0])==cell.x and int(stamp[1])==cell.y and int(stamp[3])==58)),
			"fast live gesture retains every admitted sample including its release endpoint")
		check(not editor.dragging and not editor._live_stroke,"same-frame release retires live gesture state")
	var erased := Vector2i(650,100)
	editor.select_tool("Eraser")
	if await click_canvas(erased):
		await until(func() -> bool: return host.image.get_pixelv(erased).r8==0,"live pointer Eraser removes existing native material")
	editor.select_tool("Rectangle")
	var edit_count: int = ui.applied.edits.size()
	if await click_canvas(Vector2i(620,120)):
		check(ui.applied.edits.size()==edit_count and "pause" in str(editor._message).to_lower(),
			"precise shape gesture still requires paused authoring")
	editor.select_tool("Brush")
	await screenshot("04-painted-obstacle","A manually painted hard obstacle remains in the material world while scripted NPCs and the policy actor continue.")


func preparation_and_replacement() -> void:
	if not host.paused: ui.toggle_pause()
	if not await until(func() -> bool: return host.latest_snapshot.paused,"pause before authored replacement"): return
	var retained: Dictionary = ui.applied.duplicate(true)
	var session = host.physical_actor_session
	var run: String = session.run_id
	var bad := retained.duplicate(true)
	bad.actors[1].model = "unavailable-catalogue-rig"
	check(not ui.apply(bad) and host.physical_actor_session==session and ui.applied==retained,
		"invalid catalogue entry preserves the complete applied map/session")
	bad = retained.duplicate(true)
	bad.liquid_policy = [1]
	var queued: bool = ui.apply(bad,true)
	if queued: await until(func() -> bool: return host.pending_microscenario_apply.is_empty(),"native preparation refusal")
	check(host.physical_actor_session==session and session.run_id==run and ui.applied==retained,
		"failed native preparation preserves original coupled owner")
	check(ui.toggle_pause(),"resume before retaining a policy reply")
	await phase("fresh observation before replacement",6)
	var control: Dictionary = Catalog.control_for(ui.actor(ui.applied,5))
	control.policy = "external"
	check(ui.set_actor_control(5,control),"hold policy for slot-reuse adversary")
	var view: Dictionary = ui.actor_observation(5,true)
	var late := Session.make_command(view,int(view.last_sequence)+100,{"move":Vector2.RIGHT},18)
	ui.toggle_pause()
	await until(func() -> bool: return host.latest_snapshot.paused,"pause before replacing policy actor")
	ui.select_instance(5)
	var model_index: int = ui._model_ids.find("stuntbuggy")
	if not check(model_index>=0,"existing Buggy is available in the compact placement picker"): return
	ui._model.select(model_index)
	check(ui.replace_selected(),"replace one actor through ordinary authored transaction")
	if not await until(installed,"replacement adoption"): return
	# The owner settling also occurs on a safe preparation refusal. Require the
	# new authored identity before claiming that this exercised a reused slot.
	await process_frame
	var replacement: int = ui.selected_id()
	if not check(replacement!=5 and ui.actor(ui.applied,5).is_empty(),
			"replacement gets fresh authored identity / "+str(ui.message)+" / "+str(host.microscenario_error)): return
	check(ui.actor(ui.applied,replacement).model=="stuntbuggy","replacement preserves the explicitly chosen physical model")
	check(int(ui.actor_observation(replacement).actor_id)==int(view.actor_id),"physical actor slot is actually reused")
	control = Catalog.control_for(ui.actor(ui.applied,replacement))
	control.source = "policy"
	control.policy = "external"
	check(ui.set_actor_control(replacement,control),"new slot owner independently admits policy")
	ui.toggle_pause()
	check(not ui.submit_actor_policy(5,late) and not ui.submit_actor_policy(replacement,late),
		"retired authored instance and stale run cannot command the reused slot")
	control.policy = "fixture"
	check(ui.set_actor_control(replacement,control),"new actor can run its own fresh fixture")
	await phase("replacement actor and unaffected neighbours progress",18)
	ui.toggle_pause()
	await until(func() -> bool: return host.latest_snapshot.paused,"pause before Save")
	ui._name.text = save_name
	check(ui.save_setup(),"save complete authored actor arrangement: "+str(ui.message))
	var read := Setup.read_named(save_name)
	check(read.has("setup") and read.setup.actors==ui.applied.actors,"saved file retains authored identities, sources, tuning and equipment")


func frame_refusal_lifecycle() -> void:
	# Deliberately revoke an active worker equipment generation without changing
	# the session generation. This is the real cancellation/admission boundary,
	# not a forged body mask or a fake native result.
	check(host.sample_refusals.is_empty(),"ordinary control lifecycle admits every coherent body/equipment publication")
	check(ui.toggle_pause(),"run the existing cast before the frame-refusal adversary")
	await phase("healthy cast before explicit frame refusal",6)
	var session = host.physical_actor_session
	var slot: int = session.slot_for_instance(2)
	check(host.simulation_worker.cancel_physical_usable_requests(session.epoch,slot),
		"explicitly retire one active equipment frame at the actual worker boundary")
	host._publish_physical_body_state()
	injected_frame_refusal = true
	check(host.paused and session._suspended and "cancelled_generation" in host._workbench_frame_error,
		"refused replacement frame pauses both owners with a concrete visible error")
	var stopped := physical_tick()
	check(not ui.toggle_pause() and not ui.step_once() and not ui.step_pending and not ui.step_requested,
		"Play and Step refuse a failed body frame without leaving a stuck Step intent")
	for index: int in 6: await process_frame
	check(physical_tick()==stopped,"a completed old native sample cannot authorize more Rapier steps after refusal")
	check(host.sample_refusals.size()==1 and host.sample_refusals[0].reason=="cancelled_generation",
		"the deliberately cancelled frame is the only recorded publication refusal")
	check(ui.select_instance(2) and ui.reset_selected(),"explicit actor Reset prepares a replacement after the frame fault")
	if not await until(installed,"frame-fault recovery owner installed"): return
	check(host._workbench_frame_error.is_empty() and host.physical_actor_session!=session,
		"successful prepared actor reset clears the frame fault with a fresh owner")
	check(ui.toggle_pause(),"resume after explicit frame-fault recovery")
	await phase("fresh owner after frame fault progresses coherently",12)
	ui.toggle_pause()
	check(not FileAccess.get_file_as_string(Setup._path(save_name)).contains("run_id"),"save does not impersonate a live simulation checkpoint")


func reopen() -> void:
	ui._name.text = save_name
	var expected := Setup.read_named(save_name)
	if not check(expected.has("setup"),"fresh process finds authored arrangement: "+str(expected.get("error",""))): return
	check(ui.load_setup(),"fresh process loads ordinary named start")
	if not await until(installed,"fresh-process native/physical reconstruction"): return
	check(ui.applied.actors==expected.setup.actors,"fresh process preserves all authored actor configurations")
	for actor: Dictionary in ui.applied.actors:
		check(Vector2(ui.body_state(int(actor.id)).position).distance_to(Setup.point(actor.spawn))<0.01,
			"reopen reconstructs authored spawn for #"+str(actor.id))
	check(host.paused,"saved start reopens paused")
	ui.set_camera(2)
	await screenshot("05-reopened-authored-start","Fresh-process Load reconstructs the saved composition at authored spawns, including controllers and equipment; live momentum and policy memory are not serialized.")
	check(ui.toggle_pause(),"reopened composition can play")
	await phase("fresh-process reopened cast moves",60)
	ui.toggle_pause()
	check(not host.simulation_worker.has_failed(),"fresh-process reconstructed World remains healthy")


func run() -> void:
	var configured_name := OS.get_environment("CYBERSAND_ACTOR_COMPOSITION_NAME")
	if not configured_name.is_empty(): save_name = configured_name
	root.size = Vector2i(1920,1080)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	if await until(func() -> bool: return host.shared_workbench != null,"ordinary Workbench opens"):
		ui = host.shared_workbench
		host.world_view.gui_input.connect(observe_canvas_input)
		if await until(installed,"initial ordinary native owner"):
			check(ui.art_batches==null and ui._actor_panel==null,"hidden Art and Actor Composition panels are not eagerly initialized")
			if OS.get_environment("CYBERSAND_ACTOR_COMPOSITION_REOPEN") == "1":
				await reopen()
			else:
				var requested := false
				if not FileAccess.file_exists(Setup._path(Setup.MIXED_ACTOR_LABEL)):
					ui._name.text = Setup.MIXED_ACTOR_LABEL
					requested = check(ui.load_setup(),"ordinary named Load resolves Mixed Actor Workshop")
				else:
					var note := "Named built-in fallback: a user-authored mixed-actor-workshop file exists; preserved without mutation."
					preservation_notes.append(note)
					print("SKIP WB_ACTOR_COMPOSE: ",note)
					requested = check(ui.load_mixed_actor_workshop(),"explicit UI requests supplied Mixed Actor Workshop")
				if not requested or not await until(installed,"mixed native/Rapier preparation acknowledged"):
					finish.call_deferred()
					return
				inspect_runtime()
				await pending_intent_lifecycle()
				await custom_item_handback_lifetime()
				await first_slot_equipment_guard()
				ui.set_camera(2)
				await screenshot("01-mixed-workshop-paused","Ordinary Shared Workbench: Midge #1 human, Runner #2 and Crawler #3 scripted, Skimmer #4 scripted flight, Buggy #5 external-policy fixture, Barrel #6 passive.")
				sample_enabled = true
				check(ui.toggle_pause(),"run all independent controllers in ordinary Workbench")
				if await phase("heterogeneous scripts and external fixture",240):
					for id: int in [2,3,4,5]:
						check(actors.has(id) and Vector2(actors[id].max).x-Vector2(actors[id].min).x>2.0,
							"autonomous actor #%d traversed horizontally after settling" % id)
						check(host.physical_actor_session.workbench_control(id).accepted>1,"independent commands consumed for #"+str(id))
					check(int(actors.get(2,{}).get("support_samples",0))+int(actors.get(3,{}).get("support_samples",0))>0,
						"articulated ground actors contact actual cell terrain")
					check(int(actors.get(3,{}).get("support_samples",0))>0,
						"vacuum Crawler finds actual hard-terrain traction beside the granular bed")
					await screenshot("02-independent-npcs-running","The mixed cast after native and Rapier progression; local scripted controllers and the observation-leased policy fixture run independently.")
					await handoff_and_inspection()
					await external_policy()
					await paused_editor()
					var changed := 0
					for receipt: Dictionary in equipment_receipts.values(): changed += int(receipt.get("changed_cells",0))
					check(changed>0,"scripted physical equipment produced native-authorized material changes")
					check(not host.actor_equipment_active(),"autonomous equipment does not steal the human paint pointer")
					await preparation_and_replacement()
					await frame_refusal_lifecycle()
				sample_enabled = false
	check(host.sample_refusals.size()==(1 if injected_frame_refusal else 0),
		"no unexpected body/equipment publication refusal occurred")
	finish()


func finish() -> void:
	var record := {"case":"WB-ACTOR-COMPOSE-001 actual Shared Workbench", "checks":checks,"failures":failures,
		"headless":DisplayServer.get_name()=="headless","elapsed_msec":Time.get_ticks_msec()-started_msec,
		"maximum_observed_frame_gap_usec":maximum_frame_gap_usec,"actors":actors,"phases":phases,
		"equipment_receipts":equipment_receipts.values(),"screenshots":screenshots,"preservation_notes":preservation_notes,
		"canvas_pointer_events":canvas_pointer_events,
		"canvas_motion_events":canvas_motion_events,
		"sample_refusals":host.sample_refusals if host != null else [],
		"injected_frame_refusal":injected_frame_refusal,
		"refused_live_states":host.refused_live_states if host != null else [],
		"injected_preparation_refusals":host.rejected_preparations if host != null else []}
	var path := OS.get_environment("CYBERSAND_ACTOR_COMPOSITION_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(Catalog._json_value(record),"\t")); file.close()
	print("WB_ACTOR_COMPOSE ",JSON.stringify(Catalog._json_value(record)))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
