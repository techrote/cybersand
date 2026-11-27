extends SceneTree

# Mounted Main/native/Rapier qualification. All physical movement and material
# edits use ordinary production owners. The temporary Water-policy off/on is
# a declared framebuffer visibility control while physics remains paused;
# it is never a performance arm or a source of physical completion credit.
const Setup = preload("res://scripts/workbench_setup.gd")
const Trace = preload("res://scripts/workbench_pose_trace.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const WAIT_MS := 60000

class FocusHost extends "res://scripts/main.gd":
	var dependency_witnesses: Dictionary = {}
	func _actor_window_has_focus() -> bool: return true
	func _capture_workbench_water_dependencies(native_snapshot: CyberSimulationSnapshot) -> void:
		super._capture_workbench_water_dependencies(native_snapshot)
		if physical_actor_session == null or native_snapshot == null: return
		var bridge: Variant = physical_actor_session.bridge
		for action: Dictionary in bridge.last_application.get("bodies",[]):
			var slot: int = int(action.get("id",0))-1
			if slot < 0 or slot >= bridge._members.size(): continue
			var identity := str(native_snapshot.physics_world_generation)+":"+str(bridge._session)+":" \
				+str(bridge._epoch)+":"+str(physical_actor_session.tick)+":"+str(slot)
			dependency_witnesses[identity] = {"world":native_snapshot.physics_world_generation,
				"session":bridge._session,"epoch":bridge._epoch,"step":physical_actor_session.tick,
				"manual_steps":bridge.manual_step_count(),"native_tick":native_snapshot.tick_index,
				"sample":native_snapshot.last_native_tick_body_sample,
				"native_completed_usec":native_snapshot.last_native_tick_completed_usec,
				"completed_usec":_workbench_completed_step_usec,"output_pose":bridge.body_transform(slot),
				"accepted":bridge.last_application.get("accepted",false),
				"refusal":bridge.last_application.get("refusal","missing"),"body_action":action.duplicate(true),
				"snapshot_serial":native_snapshot.serial,"applied_snapshot":bridge.last_application.get("snapshot",-1)}

var host: Control
var ui: Control
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var lifecycle: Array[Dictionary] = []
var framebuffer: Array[Dictionary] = []
var stage := "startup":
	set(value):
		stage = value
		print("WATER_STAGE ",value," ",Time.get_ticks_msec())
var output := ""
var graphical := false
var framebuffer_control := false
var observed_frames := 0
var composed_frames := 0
var hidden_body_frames := 0
var native_identity_valid := true
var last_step_by_body: Dictionary = {}
var selected_compound := ""
var omitted_by_stage: Dictionary = {}
var stored_by_stage: Dictionary = {}
var omission_reasons: Dictionary = {}
var observed_frames_by_stage: Dictionary = {}
var omitted_observations: Array[Dictionary] = []
var omitted_observations_dropped := 0
var transition_observations: Array[Dictionary] = []
var transition_observations_dropped := 0
var restoring_epoch := -1
var restoring_world := -1
var staged_water_material_vetoes := 0

func transition_identity(frame: Dictionary, bridge: Variant) -> Dictionary:
	# Read actual owners and the already-selected frame. This observer does not
	# call the Water prover, publish a sample or manufacture a completion.
	return {"time_usec":Time.get_ticks_usec(),"frame":Engine.get_process_frames(),"stage":stage,
		"frame_valid":frame.get("valid",false),"frame_world":frame.get("world_generation",-1),
		"uploaded_world":host.last_uploaded_world_generation,"uploaded_revision":host.last_uploaded_revision,
		"upload_serial":host.last_uploaded_render_snapshot_serial,
		"bridge":bridge.get_instance_id(),"session":bridge._session,"epoch":bridge._epoch,
		"physical_step":host.physical_actor_session.tick,"manual_steps":bridge.manual_step_count(),
		"completed_step":host._workbench_completed_step,"completed_usec":host._workbench_completed_step_usec,
		"pending_apply_serial":int(host.pending_microscenario_apply.get("serial",0)),
		"pending_apply":not host.pending_microscenario_apply.is_empty(),
		"pending_owner":host._pending_physical_candidate.get_instance_id() if host._pending_physical_candidate != null else 0,
		"prepared_owner_ready":host._prepared_physical_ready_sent,"terrain_ready":host._physical_terrain_ready,
		"reset_receipt":host._actor_reset_receipt,"frame_error":host._workbench_frame_error,
		"visible_slots":frame.get("poses",{}).keys(),"reasons":frame.get("reasons",{}).duplicate(),
		"guard":host.workbench_presentation_last.duplicate(),
		"selection_usec":frame.get("selection_usec",-1),"upload_cache_usec":frame.get("upload_cache_usec",-1)}

func _initialize() -> void:
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	output = OS.get_environment("CYBERSAND_WATER_COMPOSITION_OUTPUT")
	graphical = DisplayServer.get_name() != "headless"
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("WATER_COMPOSITION_NATIVE: "+label)
	return value

func until(predicate: Callable, limit_ms: int = WAIT_MS) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): return false
		await process_frame
		if not graphical: observe_frame()
	return false

func snapshot() -> CyberSimulationSnapshot:
	return host.simulation_worker.take_latest_snapshot(0)

func pause_owner() -> bool:
	if not host.paused and not check(ui.toggle_pause(),stage+" ordinary Pause admitted"): return false
	host.update_worker_frame_state()
	var serial: int = host.simulation_worker.workbench_pause_request_serial()
	return check(await until(func() -> bool:
		return snapshot() != null and snapshot().lab_context.get("workbench_pause_ack_serial",-1) >= serial),
		stage+" actual native owner acknowledges Pause")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func footprint(pose: Transform2D, rectangles: Array, pixels: Image) -> Dictionary:
	var result := {"cells":0,"empty":0,"water":0,"other":0,"materials":{}}
	if pixels == null or pixels.is_empty(): return result
	var seen: Dictionary = {}
	for rectangle: Dictionary in rectangles:
		var half: Vector2 = Vector2(rectangle.size)*0.5
		var center: Vector2 = pose*Vector2(rectangle.center)
		var extent: Vector2 = pose.x.abs()*half.x+pose.y.abs()*half.y
		for y: int in range(maxi(0,floori(center.y-extent.y)-1),mini(pixels.get_height(),ceili(center.y+extent.y)+1)):
			for x: int in range(maxi(0,floori(center.x-extent.x)-1),mini(pixels.get_width(),ceili(center.x+extent.x)+1)):
				var point := Vector2i(x,y)
				if seen.has(point): continue
				var local: Vector2 = pose.affine_inverse()*Vector2(x+0.5,y+0.5)-Vector2(rectangle.center)
				if absf(local.x)>half.x or absf(local.y)>half.y: continue
				seen[point] = true
				var material: int = pixels.get_pixel(x,y).r8
				result.cells += 1
				result.materials[material] = int(result.materials.get(material,0))+1
				if material == 0: result.empty += 1
				elif material == 3: result.water += 1
				else: result.other += 1
	return result

func observe_frame() -> void:
	if not is_instance_valid(host) or host.physical_actor_session == null or framebuffer_control: return
	var frame: Dictionary = host.workbench_presentation_frame
	var bridge: Variant = host.physical_actor_session.bridge
	if stage in ["restore","restored_paused","restored_step"]:
		if transition_observations.size() < 512:
			transition_observations.append(transition_identity(frame,bridge))
		else: transition_observations_dropped += 1
	if not frame.get("valid",false): return
	observed_frames += 1
	observed_frames_by_stage[stage] = int(observed_frames_by_stage.get(stage,0))+1
	for slot: int in range(bridge._members.size()):
		if not frame.get("poses",{}).has(slot):
			hidden_body_frames += 1
			var omission_key := stage+":"+str(slot)
			omitted_by_stage[omission_key] = int(omitted_by_stage.get(omission_key,0))+1
			var reason_key := omission_key+":"+str(frame.get("reasons",{}).get(slot,"missing"))
			omission_reasons[reason_key] = int(omission_reasons.get(reason_key,0))+1
			if stage == "restore" and bridge._epoch == restoring_epoch and host.last_uploaded_world_generation == restoring_world \
					and host._pending_physical_candidate != null and not host.pending_microscenario_apply.is_empty() \
					and frame.get("reasons",{}).get(slot) == "material_in_swept_mask":
				var cells := footprint(bridge.body_transform(slot),bridge._rects[slot],host.image)
				if cells.other == 0 and cells.water > 0: staged_water_material_vetoes += 1
			if omitted_observations.size() < 512:
				var hidden: Dictionary = transition_identity(frame,bridge)
				hidden["slot"] = slot
				hidden["reason"] = frame.get("reasons",{}).get(slot,"missing")
				hidden["response"] = bridge.last_application.duplicate(true)
				hidden["completion"] = host._workbench_water_completion_context.duplicate()
				hidden["entry"] = frame.get("mask_frame",{}).get("instances",{}).get(bridge._members[slot].instance_id,{}).duplicate()
				hidden["coverage"] = frame.get("previous_blend_active",false)
				hidden["pose"] = Trace.pose_json(bridge.body_transform(slot))
				hidden["footprint"] = footprint(bridge.body_transform(slot),bridge._rects[slot],host.image)
				omitted_observations.append(hidden)
			else: omitted_observations_dropped += 1
			continue
		var member: Dictionary = bridge._members[slot]
		var identity := str(frame.get("world_generation",-1))+":"+str(bridge._session)+":"+str(member.instance_id)
		var selected: int = int(frame.get("selected_steps",{}).get(slot,-1))
		if selected < int(last_step_by_body.get(identity,-1)): native_identity_valid = false
		last_step_by_body[identity] = selected
		var proof: Dictionary = frame.get("water_proofs",{}).get(slot,{})
		if proof.is_empty(): continue
		composed_frames += 1
		var entry: Dictionary = frame.get("mask_frame",{}).get("instances",{}).get(int(member.instance_id),{})
		var kind: String = str(proof.get("kind",""))
		var visible: Dictionary = proof.get("visible_material",{})
		var witness: Dictionary = {}
		if proof.get("step",-1) != selected or proof.get("instance_id",-1) != member.instance_id \
				or proof.get("generation",-1) != member.generation:
			native_identity_valid = false
		var pose: Transform2D = frame.poses[slot]
		var selected_observation: Dictionary = frame.get("selected_observations",{}).get(slot,{})
		if kind == "current_completed_native_dependency":
			var key := str(frame.world_generation)+":"+str(bridge._session)+":"+str(bridge._epoch)+":"+str(selected)+":"+str(slot)
			witness = host.dependency_witnesses.get(key,{})
			if proof.get("consumed_by_step") != true or proof.get("physical_completion_claim") != true \
					or witness.get("accepted") != true or witness.get("refusal") != "" \
					or witness.get("snapshot_serial",-1) != witness.get("applied_snapshot",-2) \
					or witness.get("output_pose") != pose or witness.get("completed_usec",-1) != selected_observation.get("completed_usec",-2):
				native_identity_valid = false
			for key_name: String in ["sample","native_tick","native_completed_usec","completed_usec"]:
				if proof.get(key_name,-1) != witness.get(key_name,-2): native_identity_valid = false
		else:
			if proof.get("sample",-1) != entry.get("sample",-2) \
					or proof.get("native_tick",-1) != frame.get("mask_native_tick",-2) \
					or proof.get("consumed_by_step") != (kind == "consumed_native_dependency"):
				native_identity_valid = false
			if kind == "initialized_authoring_closure" and (selected != 0 \
					or proof.get("physical_completion_claim") != false or proof.get("completed_usec") != 0 \
					or selected_observation.get("completed_usec") != 0):
				native_identity_valid = false
		if not visible.is_empty() and (visible.get("world",-1) != frame.world_generation \
				or visible.get("revision",-1) != frame.material_revision \
				or visible.get("upload_serial",-1) != frame.upload_serial \
				or visible.get("native_tick",-1) != frame.mask_native_tick \
				or visible.get("native_sample",-1) != entry.get("sample",-2)):
			native_identity_valid = false
		if observations.size() >= 1200 or int(stored_by_stage.get(stage,0)) >= 128: continue
		stored_by_stage[stage] = int(stored_by_stage.get(stage,0))+1
		var direct := PhysicsServer2D.body_get_direct_state(bridge._body_rids[slot])
		observations.append({"stage":stage,"graphical_submission_observed":graphical,
			"frame":Engine.get_process_frames(),"world":frame.world_generation,"session":bridge._session,
			"epoch":bridge._epoch,"slot":slot,"instance_id":member.instance_id,
			"selected_step":selected,"actual_session_step":host.physical_actor_session.tick,
			"actual_manual_steps":bridge.manual_step_count(),"pose":Trace.pose_json(pose),
			"proof":proof.duplicate(true),"native_dependency_witness":witness.duplicate(true),
			"current":footprint(pose,bridge._rects[slot],host.image),
			"previous":footprint(pose,bridge._rects[slot],host._presentation_previous_image),
			"previous_active":frame.previous_blend_active,"upload_serial":frame.upload_serial,
			"direct_local_com":Trace.xy(direct.center_of_mass_local) if direct != null else [],
			"selected_is_actual_completed_pose":selected_observation.get("pose") == pose \
				and selected_observation.get("step",-1) == selected \
				and int(selected_observation.get("completed_usec",0)) > 0,
			"live_pose_still_equals_selection":pose == bridge.body_transform(slot),
			"layer_visible":is_instance_valid(host.physical_actor_overlay._water_layer) \
				and host.physical_actor_overlay._water_layer.is_visible_in_tree()})

func install() -> bool:
	stage = "install"
	if not await pause_owner(): return false
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	host.engine_lab_set_render_hz(60)
	host.workbench_water_options.clear()
	host.workbench_water_options.merge(ClassDB.class_call_static(&"CyberNativeCellWorld",&"gameplay_water_options"),true)
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors = [Setup.instance("needle",1,Vector2(120,430)),
		Setup.instance("reference_barrel",2,Vector2(220,430)),Setup.instance("needle",3,Vector2(180,180))]
	for index: int in range(Fleet.count()):
		if Fleet.uses_compound(index):
			selected_compound = Fleet.stable_id(index)
			setup.actors.append(Setup.instance(selected_compound,4,Vector2(350,430)))
			break
	setup.next_id = 5
	setup.selected = 1
	setup.edits = [[0,496,512,16,58],[0,0,16,512,58],[496,0,16,512,58],
		[16,272,480,224,Setup.WATER],[400,460,50,36,Setup.SAND]]
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"ordinary mixed Water/Sand World applies"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch > epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		"actual native material, terrain and multiple actor owner installed"): return false
	check(not selected_compound.is_empty(),"supported compound COM-origin actor is included")
	check(await until(func() -> bool:
		return host.workbench_presentation_frame.get("valid",false) \
			and host.workbench_presentation_frame.get("world_generation",-1) == host.last_uploaded_world_generation),
		"actual current owner presentation reaches the initialized authoring frame")
	var initial_frame: Dictionary = host.workbench_presentation_frame
	var initial_rows: Array[Dictionary] = []
	for slot: int in [0,1,3]:
		if slot >= host.physical_actor_session.bridge._members.size(): continue
		initial_rows.append({"slot":slot,"pose":Trace.pose_json(host.physical_actor_session.bridge.body_transform(slot)),
			"footprint":footprint(host.physical_actor_session.bridge.body_transform(slot),
				host.physical_actor_session.bridge._rects[slot],host.image),
			"shown":initial_frame.get("poses",{}).has(slot),"proof":initial_frame.get("water_proofs",{}).get(slot,{}).duplicate(true),
			"reason":initial_frame.get("reasons",{}).get(slot,"missing")})
	lifecycle.append({"stage":"initial_paused_full_submersion","session_step":host.physical_actor_session.tick,
		"manual_steps":host.physical_actor_session.bridge.manual_step_count(),"completed_step":host._workbench_completed_step,
		"completed_usec":host._workbench_completed_step_usec,"rows":initial_rows})
	check(host.physical_actor_session.tick == 0 and host.physical_actor_session.bridge.manual_step_count() == 0,
		"initial paused authored submerged state has no fabricated physical completion")
	check(initial_frame.get("poses",{}).has(0),"ordinary initial paused submerged Needle is visibly admitted")
	check(ui.pilot_instance(1),"ordinary Needle input ownership admitted")
	root.gui_release_focus()
	ui._camera.select(1)
	ui.set_camera(1)
	ui._set_view(Vector2(70,380),Vector2i(160,100))
	return true

func paused_history_retention(label: String) -> void:
	stage = label
	if not await pause_owner(): return
	var bridge: Variant = host.physical_actor_session.bridge
	var first_sample: int = bridge._serial
	var first_step: int = host.physical_actor_session.tick
	var first_frames: int = observed_frames
	var first_coverage_hits: int = host._workbench_water_coverage_cache_hits
	var first_omitted: int = int(omitted_by_stage.get(stage+":0",0))
	check(await until(func() -> bool: return observed_frames >= first_frames+280),
		label+" 280 actual presentation frames complete while paused")
	check(host.physical_actor_session.tick == first_step,label+" long paused presentation creates no physical steps")
	check(host.workbench_presentation_frame.get("water_proofs",{}).has(0),label+" exact submerged Needle authority survives paused presentation")
	check(int(omitted_by_stage.get(stage+":0",0)) == first_omitted,label+" paused submerged Needle is never omitted during retained authority")
	var paused_sample: int = bridge._serial
	check(paused_sample == first_sample,label+" ordinary Pause does not manufacture fresh body samples")
	# A separate deliberate adversary calls the legitimate body-publication
	# API on actual unchanged poses. Ordinary paused frames above do not do this.
	# Every admitted sample is real; none authorizes a native/Rapier step.
	var sample_capacity: int = host.PRESENTATION_SAMPLE_HISTORY
	for ignored: int in range(sample_capacity+8):
		host._publish_physical_body_state()
		await process_frame
		if not graphical: observe_frame()
	var last_sample: int = bridge._serial
	check(last_sample >= first_sample+sample_capacity,label+" explicit real-publication adversary turns over actual bounded sample history")
	check(host._workbench_sample_steps.get(first_sample%sample_capacity,{}).get("serial",-1) != first_sample,
		label+" original sample entry is actually evicted, not inferred from elapsed frames")
	check(host._workbench_sample_steps.get(last_sample%host.PRESENTATION_SAMPLE_HISTORY,{}).get("serial",-1) == last_sample,
		label+" final adversarial body sample has genuine owner admission")
	check(host.physical_actor_session.tick == first_step,label+" repeated body publication creates no physical completion")
	check(host.workbench_presentation_frame.get("water_proofs",{}).has(0),label+" retained authority survives actual publication-history eviction")
	var before_serial: int = host.last_uploaded_render_snapshot_serial
	host.simulation_worker.request_render_full_refresh()
	check(await until(func() -> bool: return host.last_uploaded_render_snapshot_serial > before_serial \
		and host.workbench_presentation_frame.get("upload_serial",-1) == host.last_uploaded_render_snapshot_serial),
		label+" transport resync actually publishes a new immutable image")
	check(host.workbench_presentation_frame.get("water_proofs",{}).has(0),label+" full refresh preserves independently valid paused native authority")
	check(host.physical_actor_session.tick == first_step,label+" full refresh creates no physical credit")
	check(host._workbench_water_coverage_cache_hits > first_coverage_hits,
		label+" actual fully proved immutable coverage is reused during unchanged presentation")
	lifecycle.append({"stage":label,"sample_before":first_sample,"sample_after_ordinary_pause":paused_sample,
		"sample_history_capacity":sample_capacity,
		"sample_after_explicit_publication_stress":last_sample,
		"step":first_step,"frames_observed":observed_frames-first_frames,
		"omitted_needle_frames":int(omitted_by_stage.get(stage+":0",0))-first_omitted,
		"upload_before":before_serial,"upload_after":host.last_uploaded_render_snapshot_serial,
		"proof":host.workbench_presentation_frame.get("water_proofs",{}).get(0,{}).duplicate(true),
		"closure_cache_hits":host._workbench_water_closure_cache_hits,
		"coverage_cache_hits":host._workbench_water_coverage_cache_hits-first_coverage_hits})

func movement() -> bool:
	stage = "moving_submerged"
	var before: Transform2D = host.physical_actor_session.bridge.body_transform(0)
	var dry_before: Dictionary = footprint(host.physical_actor_session.bridge.body_transform(2),
		host.physical_actor_session.bridge._rects[2],host.image)
	check(dry_before.water == 0,"second Needle starts in actual dry material coverage")
	var native_before: int = snapshot().tick_index
	if not check(ui.toggle_pause(),"ordinary Play admitted"): return false
	var start: int = host.physical_actor_session.tick
	if not check(await until(func() -> bool: return host.physical_actor_session.tick >= start+3),"initial native-dependent Rapier movement"): return false
	key(KEY_D,true)
	var moved: bool = await until(func() -> bool: return host.physical_actor_session.tick >= start+25)
	key(KEY_D,false)
	if not check(moved,"ordinary keyboard flight completes real physical steps"): return false
	key(KEY_W,true)
	moved = await until(func() -> bool: return host.physical_actor_session.tick >= start+45)
	key(KEY_W,false)
	if not check(moved,"submerged keyboard climb progresses"): return false
	check(host.physical_actor_session.bridge.body_transform(0).origin.distance_to(before.origin)>0.1,
		"actual Needle pose moves under ordinary control")
	check(snapshot().tick_index > native_before,"required native material turns actually complete")
	stage = "dry_to_wet_entry"
	if not check(await until(func() -> bool:
		return footprint(host.physical_actor_session.bridge.body_transform(2),
			host.physical_actor_session.bridge._rects[2],host.image).water > 0 \
			or host.physical_actor_session.tick >= start+300),
		"multiple ordinary actors continue into active Water"): return false
	var wet_after: Dictionary = footprint(host.physical_actor_session.bridge.body_transform(2),
		host.physical_actor_session.bridge._rects[2],host.image)
	lifecycle.append({"stage":"dry_to_wet_entry","initial":dry_before,"after":wet_after,
		"actual_pose":Trace.pose_json(host.physical_actor_session.bridge.body_transform(2)),
		"actual_completed_step":host.physical_actor_session.tick})
	check(wet_after.water > 0,"previously dry actual actor enters retained native Water")
	if not await pause_owner(): return false
	var step: int = host.physical_actor_session.tick
	for ignored: int in range(4): await process_frame
	check(host.physical_actor_session.tick == step,"acknowledged Pause preserves completed physical count")
	return true

func color_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

# A real atomic admission is bound to a CPU draw, while a deferred post-draw
# notification on a separate renderer may describe an older queued frame.
func control_frame_ready(slot: int, enabled: bool, after_serial: int) -> bool:
	var frame: Dictionary = host.workbench_presentation_frame
	if after_serial>=0 and int(frame.get("submission_serial",-1))<=after_serial: return false
	return frame.get("valid",false) and frame.get("water_proofs",{}).has(slot)==enabled \
		and float(frame.get("snapshot_blend",0.0))>=1.0

func read_control_frame() -> Image:
	if host.workbench_presentation_submission_enabled():
		# The predicate had to observe a newer frozen receipt in process_frame,
		# after admission returned to the engine. Drain the already-enqueued draw
		# before the first read. This never forces an additional atomic draw.
		RenderingServer.force_sync()
	else:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func framebuffer_visibility(label: String, requested_slot: int = -1) -> void:
	stage = label
	if not graphical: return
	if not check(await until(func() -> bool: return not host.workbench_presentation_frame.get("water_proofs",{}).is_empty()),
		label+" actual Water-composed submission available"): return
	var frame: Dictionary = host.workbench_presentation_frame
	var slot: int = requested_slot if requested_slot >= 0 else int(frame.water_proofs.keys()[0])
	if not check(frame.water_proofs.has(slot),label+" requested member has an actual Water proof"): return
	var selected: Transform2D = frame.poses[slot]
	ui._camera.select(0)
	ui.set_camera(0)
	ui._set_view(selected.origin-Vector2(80,50),Vector2i(160,100))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	frame = host.workbench_presentation_frame
	var bridge: Variant = host.physical_actor_session.bridge
	var member: Dictionary = bridge._members[slot]
	var entry: Dictionary = host.workbench_display_frame().get("instances",{}).get(int(member.instance_id),{})
	var sample_serial: int = int(entry.get("sample",-1))
	lifecycle.append({"stage":label+"_after_camera","slot":slot,"proof_present":frame.get("water_proofs",{}).has(slot),
		"reason":frame.get("reasons",{}).get(slot,"missing"),"source":frame.get("sources",{}).get(slot,"missing"),
		"guard":host.workbench_presentation_last.duplicate(true),"uploaded_sample":sample_serial,
		"wrench_history_sample":bridge._history[sample_serial%bridge._history.size()].get("serial",-1) if sample_serial>=0 else -1,
		"presentation_sample":host._workbench_bound_sample(entry).duplicate(true),
		"actual_step":host.physical_actor_session.tick,"actual_pose":Trace.pose_json(bridge.body_transform(slot)),
		"uploaded_pose":Trace.pose_json(entry.get("pose")),"uploaded_native_tick":host.workbench_display_frame().get("tick",-1),
		"consumed_dependency":host._workbench_water_dependencies.get(slot,{}).duplicate(true)})
	if not check(frame.get("water_proofs",{}).has(slot),label+" selected submerged actor remains admitted after Free camera"): return
	selected = frame.poses[slot]
	var overlay: Control = host.physical_actor_overlay
	var layer: Control = overlay._water_layer
	if not check(is_instance_valid(layer) and layer.is_visible_in_tree(),label+" actual Water draw layer is visible"): return
	ui._pick(Vector2i(selected.origin))
	check(ui.selected_id() == int(host.physical_actor_session.bridge._members[slot].actor_instance_id),
		label+" ordinary picking uses the presented submerged actor")
	var actor_slot: int = host.physical_actor_session.slot_for_instance(int(member.actor_instance_id))
	# UI selection is admitted immediately, but the ordinary actor-label owner
	# refreshes on its150ms status cadence. Its visible selection ring must be
	# the SAME state on all framebuffer controls, not a later confounder.
	if not check(await until(func() -> bool:
		return overlay.actor_labels.get(actor_slot,{}).get("selected",false)),
		label+" actual ordinary selection label reaches the overlay before pixel control"): return
	framebuffer_control = true
	# The material shaders continue animating Water while physics is paused.
	# Use the existing capture clock for every pixel control, with the live
	# policy, full material histories and actual rendered actor left in place.
	var clock_serial: int = int(host.workbench_presentation_frame.get("submission_serial",-1))
	var materials: Array = [host.world_shader,host.glow_source_shader]
	materials.append_array(host.vapour_trail_shaders)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("presentation_time_override",4.0)
	# Finish a genuine publication fade, then compare actual submitted pixels
	# through ordinary policy transitions. Keeping Main processing alive is
	# necessary for the atomic engine's real prepared-submission contract.
	if not check(await until(func() -> bool: return control_frame_ready(slot,true,clock_serial)),
		label+" paused actual image history fade completes"):
		framebuffer_control = false
		return
	var material_bytes: PackedByteArray = host.image.get_data()
	var old_bytes: PackedByteArray = host._presentation_previous_image.get_data()
	var physical_step: int = host.physical_actor_session.tick
	var shown: Image = await read_control_frame()
	var shown_identity: Dictionary = framebuffer_identity(slot)
	var shown_serial: int = int(host.workbench_presentation_frame.get("submission_serial",-1))
	var local: Vector2 = overlay._point(selected.origin)
	var viewport_point: Vector2 = overlay.get_global_transform_with_canvas()*local
	var point := Vector2i((viewport_point*Vector2(shown.get_size())/root.get_visible_rect().size).floor())
	OS.set_environment("CYBERSAND_DIAG_WATER_COMPOSITION","0")
	if not check(await until(func() -> bool: return control_frame_ready(slot,false,shown_serial)),
		label+" ordinary disabled Water policy submits its conservative control"):
		OS.set_environment("CYBERSAND_DIAG_WATER_COMPOSITION","1")
		framebuffer_control = false
		return
	var hidden: Image = await read_control_frame()
	var hidden_identity: Dictionary = framebuffer_identity(slot)
	var hidden_serial: int = int(host.workbench_presentation_frame.get("submission_serial",-1))
	OS.set_environment("CYBERSAND_DIAG_WATER_COMPOSITION","1")
	if not check(await until(func() -> bool: return control_frame_ready(slot,true,hidden_serial)),
		label+" ordinary enabled Water policy restores exact paused actor authority"):
		framebuffer_control = false
		return
	var restored: Image = await read_control_frame()
	var restored_identity: Dictionary = framebuffer_identity(slot)
	var restored_serial: int = int(host.workbench_presentation_frame.get("submission_serial",-1))
	check(shown_identity == hidden_identity and shown_identity == restored_identity,
		label+" all pixel reads retain identical actual label, mapping, owner, pose and material identities")
	var greatest: float = 0.0
	var repeat_error: float = 0.0
	var pixels: Array[Dictionary] = []
	for y: int in range(point.y-2,point.y+3):
		for x: int in range(point.x-2,point.x+3):
			if not Rect2i(Vector2i.ZERO,shown.get_size()).has_point(Vector2i(x,y)): continue
			var a := shown.get_pixel(x,y)
			var b := hidden.get_pixel(x,y)
			var c := restored.get_pixel(x,y)
			greatest = maxf(greatest,color_error(a,b))
			repeat_error = maxf(repeat_error,color_error(a,c))
			pixels.append({"pixel":[x,y],"shown":[a.r,a.g,a.b],"hidden":[b.r,b.g,b.b],"restored":[c.r,c.g,c.b]})
	check(greatest > 0.025,label+" first framebuffer read contains actual submerged actor pixels")
	check(repeat_error < 0.025,label+" restored same-state draw reproduces those pixels")
	check(material_bytes == host.image.get_data() and old_bytes == host._presentation_previous_image.get_data(),
		label+" visibility control preserves both actual material histories")
	check(physical_step == host.physical_actor_session.tick,label+" visibility control invents no physical progress")
	if not output.is_empty():
		for artifact: Array in [["shown",shown],["hidden-control",hidden],["restored",restored]]:
			check(artifact[1].save_png(output.get_base_dir().path_join(label+"-"+str(artifact[0])+".png")) == OK,label+" framebuffer artifact "+str(artifact[0]))
	framebuffer.append({"label":label,"slot":slot,"proof":frame.water_proofs[slot].duplicate(true),
		"shown_identity":shown_identity,"hidden_identity":hidden_identity,"restored_identity":restored_identity,
		"selected_pose":Trace.pose_json(selected),"viewport_point":Trace.xy(viewport_point),
		"policy_order":["1","0","1"],"control_scope":"ordinary presentation policy transition, no physical/material mutation",
		"control_submission_serials":[clock_serial,shown_serial,hidden_serial,restored_serial],
		"pixel_point":[point.x,point.y],"size":[shown.get_width(),shown.get_height()],
		"maximum_visible_difference":greatest,"maximum_restored_error":repeat_error,"pixels":pixels})
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("presentation_time_override",-1.0)
	framebuffer_control = false

func framebuffer_identity(slot: int) -> Dictionary:
	var bridge: Variant = host.physical_actor_session.bridge
	return {"labels":host.physical_actor_overlay.actor_labels.duplicate(true),
		"mapping":host.workbench_presentation_frame.get("camera_mapping"),
		"screen_transform":host.workbench_presentation_frame.get("screen_transform"),
		"overlay_origin":host.physical_actor_overlay._origin,"overlay_view_size":host.physical_actor_overlay._view_size,
		"overlay_position":host.physical_actor_overlay.position,"overlay_size":host.physical_actor_overlay.size,
		"bridge":bridge.get_instance_id(),"session":bridge._session,"epoch":bridge._epoch,
		"physical_step":host.physical_actor_session.tick,"pose":bridge.body_transform(slot),
		"world":host.last_uploaded_world_generation,"revision":host.last_uploaded_revision,
		"upload_serial":host.last_uploaded_render_snapshot_serial,
		"current_content":host._presentation_current_content_id,"previous_content":host._presentation_previous_content_id}

func ordinary_step(label: String) -> bool:
	stage = label
	var before: int = host.physical_actor_session.tick
	if not check(ui.step_once(),label+" ordinary Step admitted"): return false
	if not check(await until(func() -> bool: return not ui.step_pending and host.physical_actor_session.tick > before),
		label+" actual native and Rapier Step complete"): return false
	check(host.physical_actor_session.tick == before+1 and host.paused,label+" Step advances exactly once and remains paused")
	return check(await until(func() -> bool: return host._valid_workbench_mask_frame(host.workbench_display_frame())),
		label+" actual published material/pose frame rejoins")

func paint_patch(center: Vector2i, half: int, material: int, label: String) -> bool:
	stage = label
	var cells := PackedInt32Array()
	for y: int in range(maxi(16,center.y-half),mini(496,center.y+half)):
		for x: int in range(maxi(16,center.x-half),mini(496,center.x+half)):
			cells.append_array(PackedInt32Array([x,y,material]))
	var worker: Variant = host.simulation_worker
	var state: Dictionary = worker.paint_state()
	var request: Dictionary = worker.paint_queue({"kind":"edit","cells":cells,
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick,
		"expected_authoring_generation":state.authoring_generation})
	if not check(request.get("status","") == "queued",label+" ordinary native authoring queue admits edit"): return false
	if not check(await until(func() -> bool: return worker.paint_state().receipt_ready),label+" actual material edit receipt completes"): return false
	var result: Dictionary = worker.paint_take_result()
	lifecycle.append({"stage":label,"material":material,"cells":cells.size()/3,
		"generation":worker.paint_state().generation,"revision":worker.paint_state().revision,
		"receipt_status":result.get("status","missing"),"receipt_reason":result.get("reason",""),
		"actual_applied":result.get("applied",-1),"actual_changed":result.get("changed",-1)})
	return check(result.get("status","") == "completed" \
		and result.get("after",PackedInt32Array()).size() == cells.size()/3,
		label+" all admitted cells have actual write results: "+str(result.get("reason","")))

func edits_and_lifecycle() -> void:
	stage = "single_step"
	if not await ordinary_step(stage): return
	# Authoring must obey the ordinary transient-body protection. Edit the
	# basin beside the actors, never bypass that protection to manufacture a
	# Water/Sand overlap under a body. The dry-to-wet actor transition above
	# comes from ordinary completed physical movement instead.
	var position := Vector2i(64,350)
	if not await paint_patch(position,28,0,"dry_large_erase") or not await ordinary_step("dry_step"): return
	check(host.image.get_pixelv(position).r8 == 0,"ordinary large erase produces actual Empty basin cells")
	if not await paint_patch(position,28,3,"wet_large_fill") or not await ordinary_step("wet_step"): return
	await framebuffer_visibility("water_refill_framebuffer")
	if not await paint_patch(position,2,Setup.SAND,"mixed_sand_small_edit") or not await ordinary_step("mixed_step"): return
	var frame: Dictionary = host.workbench_presentation_frame
	var mixed: Dictionary = footprint(host.physical_actor_session.bridge.body_transform(0),
		host.physical_actor_session.bridge._rects[0],host.image)
	var sand_cells := 0
	for y: int in range(position.y-4,position.y+8):
		for x: int in range(position.x-4,position.x+5):
			if host.image.get_pixel(x,y).r8 == Setup.SAND: sand_cells += 1
	check(sand_cells > 0,"actual Sand evolves in contact with the Water basin after small edit")
	if int(mixed.other)>0:
		check(not frame.get("water_proofs",{}).has(0),"actual other-material overlap never receives Water-only admission")
	lifecycle.append({"stage":"mixed_footprint","footprint":mixed,"water_admitted":frame.get("water_proofs",{}).has(0)})
	if not await paint_patch(position,2,3,"water_small_repair") or not await ordinary_step("repair_step"): return
	var before_epoch: int = host._physical_epoch
	var before_world: int = host.last_uploaded_world_generation
	restoring_epoch = before_epoch
	restoring_world = before_world
	stage = "restore"
	if not check(ui.restore_start(),"ordinary Restore start admitted"): return
	if not check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
		and host._physical_epoch > before_epoch and host.last_uploaded_world_generation > before_world \
		and host.physical_actor_session != null and host._physical_terrain_ready),"Restore replaces exact World and actor owner"): return
	check(host._workbench_water_dependencies.is_empty(),"Restore retires consumed Water authority")
	# This is the old session during preparation. The new owner is checked
	# independently below. Legacy empty-only clearance rejected each such
	# submerged footprint for every draw until the replacement was adopted.
	check(staged_water_material_vetoes == 0,
		"restoring a second owner never turns the installed owner's retained Water into a hard-material veto")
	stage = "restored_paused"
	check(await until(func() -> bool:
		return host.workbench_presentation_frame.get("world_generation",-1) == host.last_uploaded_world_generation \
			and host.workbench_presentation_frame.get("water_proofs",{}).has(0)),
		"new restored owner admits initialized Water presentation before any Step")
	var restored_step: int = host.physical_actor_session.tick
	var restored_manual: int = host.physical_actor_session.bridge.manual_step_count()
	check(restored_step == 0 and restored_manual == 0 and host._workbench_completed_step_usec == 0,
		"restored initialized presentation has no fabricated physical completion")
	for ignored: int in range(32): await process_frame
	for slot: int in range(host.physical_actor_session.bridge._members.size()):
		check(int(omitted_by_stage.get(stage+":"+str(slot),0)) == 0,
			"restored paused owner keeps actual member "+str(slot)+" visible")
	check(host.physical_actor_session.tick == restored_step \
		and host.physical_actor_session.bridge.manual_step_count() == restored_manual,
		"restored paused visibility creates no physical steps")
	await framebuffer_visibility("restored_authoring_framebuffer")
	if not await ordinary_step("restored_step"): return
	check(ui.toggle_pause(),"restored ordinary resume admitted")
	var first: int = host.physical_actor_session.tick
	check(await until(func() -> bool: return host.physical_actor_session.tick >= first+8),"restored native-dependent simulation progresses")
	await pause_owner()

func moving_multipart() -> void:
	stage = "multipart_install"
	var recipe := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.actors = [Setup.instance("runner",12,Vector2(256,350))]
	recipe.next_id = 13
	recipe.selected = 12
	recipe.edits = [[0,496,512,16,58],[16,272,480,224,Setup.WATER],[40,445,30,45,Setup.SAND]]
	var old_epoch: int = host._physical_epoch
	if not check(ui.apply(recipe),"ordinary submerged articulated Runner setup admitted"): return
	if not check(await until(func() -> bool: return host._physical_epoch > old_epoch \
			and host.pending_microscenario_apply.is_empty() and host._physical_terrain_ready \
			and host.physical_actor_session != null and host.physical_actor_session.bridge.actor_body_count(0) >= 5 \
			and host.workbench_presentation_frame.get("water_proofs",{}).size() == host.physical_actor_session.bridge._members.size()),
			"all submerged Runner members acquire initialized proofs"): return
	var bridge: Variant = host.physical_actor_session.bridge
	var initial: Transform2D = bridge.body_transform(4)
	check(bridge.actor_body_count(0) == bridge._members.size() and bridge._members[4].actor_instance_id == 12,
		"articulated foot belongs to authored actor 12")
	ui._camera.select(0)
	ui.set_camera(0)
	ui._set_view(Vector2(176,300),Vector2i(160,100))
	stage = "multipart_motion"
	if not check(ui.toggle_pause(),"ordinary Play moves the submerged articulated actor"): return
	var deadline := Time.get_ticks_msec()+WAIT_MS
	var moving_frame: Dictionary = {}
	while Time.get_ticks_msec() < deadline and not host.simulation_worker.has_failed():
		if graphical: await RenderingServer.frame_post_draw
		else: await process_frame
		var draw_frame: Dictionary = host.workbench_presentation_frame
		var drawn_limb: Variant = draw_frame.get("poses",{}).get(4)
		# Join observations to the draw's sampled physical step. A later
		# physics callback may already have completed by the next process_frame.
		if draw_frame.get("rapier_step",-1) >= 8 and draw_frame.get("water_proofs",{}).size() == bridge._members.size() \
				and draw_frame.get("selected_steps",{}).get(4,-1) == draw_frame.rapier_step \
				and drawn_limb is Transform2D and drawn_limb.origin.distance_to(initial.origin) > 0.1:
			moving_frame = draw_frame
			break
	if not check(not moving_frame.is_empty(),
			"moving articulated limb reaches a distinct real completed pose with every member composed"): return
	if graphical:
		if not output.is_empty():
			check(root.get_texture().get_image().save_png(output.get_base_dir().path_join("moving-runner.png"))==OK,
				"first-read moving multipart framebuffer saved")
		lifecycle.append({"stage":stage,"step":host.physical_actor_session.tick,
			"steps":moving_frame.get("selected_steps",{}).duplicate(),"origins":moving_frame.get("poses",{}).duplicate(),
			"camera_mapping":moving_frame.get("camera_mapping"),"upload_serial":moving_frame.get("upload_serial",-1)})
	if not await pause_owner(): return
	await framebuffer_visibility("multipart_limb_framebuffer",4)

func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(FocusHost)
	host = loaded
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if graphical: RenderingServer.frame_post_draw.connect(observe_frame)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),90000),
			"ordinary Workbench startup with real native runtime"):
		ui = host.shared_workbench
		check(Setup.SAND == 2 and Setup.MATERIAL_NAMES[Setup.MATERIALS.find(Setup.SAND)] == "Sand",
			"fixture Sand is the actual supported Workbench material2, not Wall1")
		check(host._workbench_water_composition_enabled(),"explicit Water composition treatment is active")
		if failures.is_empty() and await install():
			await paused_history_retention("initialized_paused_history")
			if not host.workbench_presentation_frame.get("water_proofs",{}).is_empty():
				await framebuffer_visibility("initial_authoring_framebuffer")
			if await movement():
				await paused_history_retention("completed_paused_history")
				await framebuffer_visibility("submerged_framebuffer")
				await edits_and_lifecycle()
				if failures.is_empty(): await moving_multipart()
	check(not host.simulation_worker.has_failed(),"native World remains healthy")
	check(native_identity_valid,"every observed proof joins real actor/native/selected-step identity without time regression")
	var kinds: Dictionary = {}
	var moving_wet_poses: Dictionary = {}
	for row: Dictionary in observations:
		kinds[row.proof.kind] = int(kinds.get(row.proof.kind,0))+1
		if row.stage == "moving_submerged" and row.slot == 0 and int(row.current.water)>0 \
				and row.selected_is_actual_completed_pose and row.layer_visible:
			moving_wet_poses[JSON.stringify(row.pose)] = true
	check(moving_wet_poses.size() >= 3,"moving submerged actor has multiple distinct actual completed poses in composed submissions")
	check(composed_frames > 0 and not observations.is_empty(),"Water treatment actually executes on mounted native Workbench")
	if graphical: check(framebuffer.size() == 5,"initialized, completed, rewet, restored and multipart limb framebuffer controls all execute")
	key(KEY_D,false)
	key(KEY_W,false)
	if graphical: RenderingServer.frame_post_draw.disconnect(observe_frame)
	var inputs: Dictionary = {}
	for path: String in [get_script().resource_path,"res://scripts/main.gd","res://scripts/simulation_worker.gd",
			"res://scripts/workbench_water_composition.gd","res://scripts/workbench_presentation_coherence.gd",
			"res://scripts/workbench_physics_bridge.gd","res://scripts/physical_actor_session.gd",
			"res://scripts/physical_actor_overlay.gd","res://shaders/workbench_water_actor_composition.gdshader",
			"res://scripts/shared_workbench.gd","res://scripts/workbench_setup.gd"]:
		inputs[path] = FileAccess.get_sha256(path)
	var runtime_path := "res://addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so")
	inputs[runtime_path] = FileAccess.get_sha256(runtime_path)
	var report := {"schema":"pubpres-water-composition-native-v1","source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display":DisplayServer.get_name(),"graphical":graphical,"input_hashes":inputs,"checks":checks,"failures":failures,
		"selectors":{"water_composition":OS.get_environment("CYBERSAND_DIAG_WATER_COMPOSITION"),
			"actual_submission":OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION"),
			"actual_submission_status":host.workbench_presentation_submission_status() \
				if host.has_method("workbench_presentation_submission_status") else {}},
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"observed_frames":observed_frames,"composed_body_frames":composed_frames,"hidden_body_frames":hidden_body_frames,
		"omitted_by_stage_and_slot":omitted_by_stage,"omission_reasons":omission_reasons,
		"observed_frames_by_stage":observed_frames_by_stage,
		"staged_water_material_vetoes":staged_water_material_vetoes,
		"omitted_observations":omitted_observations,"omitted_observations_dropped":omitted_observations_dropped,
		"transition_observations":transition_observations,"transition_observations_dropped":transition_observations_dropped,
		"proof_kinds":kinds,"moving_wet_distinct_poses":moving_wet_poses.size(),"compound_model":selected_compound,
		"observations":observations,"lifecycle":lifecycle,"framebuffer":framebuffer,
		"scope":"Actual mounted Main/native/Rapier and first-read framebuffer visibility controls; explicit injected ordinary keyboard input. No comparative performance, compositor, physical scanout or owner NVIDIA acceptance."}
	host.simulation_worker.stop_worker()
	host.queue_free()
	await process_frame
	await process_frame
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")+"\n")
		else: check(false,"native Water evidence output opens")
	print("PUBPRES_WATER_COMPOSITION_NATIVE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
