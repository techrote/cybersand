extends "res://tests/test_workbench_actor_composition.gd"

# Real viewport events, native worker, prepared-owner adoption and patched Rapier.
# Inherit the accepted fixture's focus predicate and explicit preparation fault.
var placement_receipts: Array = []
var grab_receipts: Array = []
const SAVED_PAINT := Vector2i(438,160)


func wait_state() -> Dictionary:
	return {"message":ui.message if ui != null else "opening", "native_tick":native_tick(),
		"rapier_tick":physical_tick(),"busy":ui.busy() if ui != null else true,
		"worker_failed":host.simulation_worker.has_failed() if host != null else false}


func canvas_position(point: Vector2) -> Vector2:
	var frame: Dictionary = host.workbench_presentation_frame
	var screen: Vector2 = frame.camera_mapping * point
	var local: Vector2 = host._world_view_screen_transform().affine_inverse() * screen
	return host.world_view.get_global_transform_with_canvas()*local


func displayed_part_position(actor_id: int, part: int) -> Vector2:
	var session = host.physical_actor_session
	var slot: int = session.bridge.actor_body_index(session.slot_for_instance(actor_id)) + part
	var pose: Variant = host.workbench_presentation_frame.poses.get(slot)
	return pose.origin if pose is Transform2D else Vector2.INF


func pointer(point: Vector2, pressed: bool, outside: bool = false) -> void:
	if not outside and not check(point.is_finite(),"requested pointer point is visible"): return
	var event := InputEventMouseButton.new()
	event.position = Vector2(4,4) if outside else canvas_position(point)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	host.world_view.get_viewport().push_input(event,true)
	await process_frame


func motion(point: Vector2, fine: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = canvas_position(point)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.shift_pressed = fine
	host.world_view.get_viewport().push_input(event,true)
	await process_frame


func placement_key(code: Key, fine: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = fine
	host.get_viewport().push_input(event,true)
	await process_frame
	event.pressed = false
	host.get_viewport().push_input(event,true)


func pause_owners() -> bool:
	if not host.paused and not check(ui.toggle_pause(),"Pause requested"): return false
	var serial: int = host.simulation_worker.workbench_pause_request_serial()
	return await until(func() -> bool: return host.paused and host.latest_snapshot.paused \
		and int(host.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1)) >= serial \
		and host.physical_actor_session._suspended,"native and Rapier acknowledge Pause")


func install_cast() -> bool:
	var data := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	Setup._box(data.edits,Vector2i(0,420),Vector2i(512,432),Setup.WALL)
	Setup._box(data.edits,Vector2i(370,394),Vector2i(430,420),Setup.SAND)
	data.actors = [Setup.instance(Setup.Fleet.stable_id(0),1,Vector2(90,170)),
		Setup.instance("runner",2,Vector2(190,340)),Setup.instance(Setup.BARREL,3,Vector2(350,260))]
	data.selected = 1
	data.next_id = 4
	data["sandbox_capacity"] = {"version":1,"logical_limit":64,"body_limit":128,"proxy_limit":128}
	if not check(ui.apply(data),"physical interaction cast admitted"): return false
	if not await until(installed,"interaction cast native/Rapier owners installed"): return false
	ui.set_camera(2)
	await process_frame
	return true


func idle_camera_pan() -> void:
	for mode: String in ["paint","grab","place"]:
		ui.actor_interaction.set_mode(mode)
		ui._set_view(Vector2(80,80),Vector2i(480,270))
		await process_frame
		var before: Vector2 = host.camera_origin
		var point: Vector2 = host.world_view.get_global_transform_with_canvas()*host.view_content_rect().get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_MIDDLE
		press.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		press.position = point
		press.global_position = point
		press.pressed = true
		host.world_view.get_viewport().push_input(press,true)
		var move := InputEventMouseMotion.new()
		move.position = point+Vector2(-30,-20)
		move.global_position = move.position
		move.relative = Vector2(-30,-20)
		move.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		host.world_view.get_viewport().push_input(move,true)
		check(ui._pan and host.camera_origin.distance_to(before)>1.0,"idle middle-drag camera works in "+mode)
		press.position = move.position
		press.global_position = move.position
		press.pressed = false
		press.button_mask = 0
		host.world_view.get_viewport().push_input(press,true)
		check(not ui._pan,"middle release ends "+mode+" camera gesture")
	ui.actor_interaction.set_mode("paint")


func poses_match(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size(): return false
	for index: int in actual.size():
		if Vector2(actual[index].position).distance_to(expected[index].position) > 0.002: return false
		if absf(angle_difference(float(actual[index].rotation),float(expected[index].rotation))) > 0.00001: return false
	return true


func authored_match(actual: Array, expected: Array) -> bool:
	if actual.size()!=expected.size(): return false
	for index: int in actual.size():
		var a: Dictionary = actual[index].duplicate(true)
		var b: Dictionary = expected[index].duplicate(true)
		# JSON prints finite decimal numbers; a radians/degrees conversion can
		# differ below 1e-12 degrees after its text round trip.
		if absf(float(a.get("spawn_rotation_degrees",0))-float(b.get("spawn_rotation_degrees",0)))>1e-10: return false
		a.erase("spawn_rotation_degrees")
		b.erase("spawn_rotation_degrees")
		if a!=b: return false
	return true


func paused_placement() -> void:
	var interaction = ui.actor_interaction
	interaction.set_mode("place")
	var original: Dictionary = host.physical_actor_session.capture_workbench_assembly(2)
	var old_rids := body_rids(2)
	var pilot: int = ui.pilot_id()
	await pointer(displayed_part_position(2,0),true)
	if not check(not interaction.placement.is_empty(),"canvas click picks complete multipart actor"): return
	check(ui.selected_id()==2 and ui.pilot_id()==pilot,"canvas selection preserves human piloting authority")
	await motion(Vector2(original.parts[0].position)+Vector2(38,-42))
	await placement_key(KEY_E)
	check(is_equal_approx(float(interaction.placement.rotation_degrees),15.0),"E rotates the complete copied assembly clockwise")
	await placement_key(KEY_Q)
	check(absf(float(interaction.placement.rotation_degrees))<0.01,"Q rotates the complete assembly back")
	await placement_key(KEY_E,true)
	check(is_equal_approx(float(interaction.placement.rotation_degrees),1.0),"Shift E gives one-degree rotation")
	check(body_rids(2)==old_rids and host.physical_actor_session.capture_workbench_assembly(2).parts==original.parts,
		"preview never teleports bodies or creates a prepared owner")
	check(host.pending_microscenario_apply.is_empty(),"mouse movement has not prepared a native replacement")
	await screenshot("sandbox-01-preview","Copied current multipart pose, one-degree rotation and precise coordinates before a single prepared commit.")
	await placement_key(KEY_ESCAPE)
	check(interaction.placement.is_empty() and body_rids(2)==old_rids,"Escape cancels placement without replacing bodies")
	var settings: Dictionary = interaction.settings.duplicate()
	settings.snap_enabled = true
	settings.grid_size = 8.0
	check(interaction.configure(settings),"optional grid configuration admitted")
	await pointer(displayed_part_position(2,0),true)
	await motion(Vector2(original.parts[0].position)+Vector2(37,-37))
	check(Vector2(interaction.placement.position).is_equal_approx(Vector2(interaction.placement.position).snapped(Vector2(8,8))),
		"drag preview snaps the assembly origin to configured grid")
	await motion(Vector2(original.parts[0].position)+Vector2(37.25,-37.5),true)
	check(not Vector2(interaction.placement.position).is_equal_approx(Vector2(interaction.placement.position).snapped(Vector2(8,8))),
		"Shift drag bypasses snapping for fine position")
	var fine_before: Vector2 = interaction.placement.position
	await placement_key(KEY_RIGHT,true)
	check(Vector2(interaction.placement.position).is_equal_approx(fine_before+Vector2(1,0)),"Shift arrow applies configured fine position increment")
	await placement_key(KEY_E)
	var proposed: Dictionary = interaction.placement.duplicate(true)
	var before_epoch: int = host._physical_epoch
	var begin := Time.get_ticks_usec()
	await placement_key(KEY_ENTER)
	if not await until(func() -> bool: return installed() and host._physical_epoch>before_epoch,"rotated multipart prepared placement committed"): return
	var moved: Dictionary = host.physical_actor_session.capture_workbench_assembly(2)
	check(poses_match(moved.parts,proposed.parts),"real Rapier part transforms match rotated current-pose preview")
	check(moved.joint_count==original.joint_count and moved.parts.size()==original.parts.size(),"placement preserves actual joint and body counts")
	check(ui.actor(ui.applied,2).spawn==[proposed.position.x,proposed.position.y] \
		and is_equal_approx(float(ui.actor(ui.applied,2).spawn_rotation_degrees),float(proposed.rotation_degrees)),
		"committed position and orientation become authored data")
	check(ui.pilot_id()==pilot and host.paused,"placement retains pilot and Pause")
	placement_receipts.append({"elapsed_usec":Time.get_ticks_usec()-begin,"parts":moved.parts.size(),"joints":moved.joint_count,
		"position":moved.position,"rotation":moved.rotation,"epoch":host._physical_epoch})
	var retained: Dictionary = ui.applied.duplicate(true)
	var retained_session = host.physical_actor_session
	check(not interaction.place_exact(2,Vector2(-8,30),0),"out-of-bounds assembly placement refuses")
	check(ui.applied==retained and host.physical_actor_session==retained_session,"bounds refusal preserves authored and native owner")
	await pointer(displayed_part_position(2,0),true)
	await pointer(Vector2.ZERO,false,true)
	check(interaction.placement.is_empty() and host.physical_actor_session==retained_session,"release outside canvas cancels preview")
	host.reject_next_preparation = true
	check(interaction.place_exact(2,Vector2(225,290),-20),"native refusal fixture stages a valid placement")
	if not await until(installed,"failed placement releases preparation fences"): return
	check(host.rejected_preparations.size()==1 and ui.applied==retained and host.physical_actor_session==retained_session,
		"failed native preparation keeps every existing actor and authored coordinate")
	check(poses_match(retained_session.capture_workbench_assembly(2).parts,moved.parts),"native refusal leaves the original multipart pose intact")
	for index: int in 3:
		check(interaction.place_exact(3,Vector2(330+index*8,240),float(index*15)),"repeated whole-barrel placement admitted")
		if not await until(installed,"repeated placement owner settles"): return
		check(host.physical_actor_session.bodies().size()==8,"repeated placement retains exactly eight real physical parts")


func live_interactions() -> void:
	var interaction = ui.actor_interaction
	interaction.set_mode("grab")
	if not check(ui.toggle_pause(),"Play resumes manipulated assembly"): return
	if not await phase("native masks and Rapier progress after rotation",8): return
	var session = host.physical_actor_session
	var run_id: String = session.run_id
	var initial: Dictionary = session.capture_workbench_assembly(3)
	var before_edits: int = ui.applied.edits.size()
	var old_rids := body_rids(3)
	var npc_before: int = session.workbench_control(2).accepted
	await pointer(displayed_part_position(3,0),true)
	if not check(interaction.grab_state().active and int(interaction.grab_state().instance_id)==3,"actual viewport grabs passive physical barrel"): return
	var target: Vector2 = Vector2(initial.parts[0].position)+Vector2(-65,-70)
	await motion(target)
	if not await phase("barrel mouse force and NPC coexist with native materials",30): return
	var after: Dictionary = session.capture_workbench_assembly(3)
	check(Vector2(after.parts[0].position).x<Vector2(initial.parts[0].position).x-5,"real barrel responds to moving mouse target")
	check(body_rids(3)==old_rids and session.run_id==run_id,"live grab retains exact body identities and owner")
	check(session.workbench_control(2).accepted>npc_before,"other actor decisions continue during barrel grab")
	check(ui.applied.edits.size()==before_edits and not ui.paint_editor.dragging and not host.actor_equipment_active(),
		"Grab pointer does not leak into PAINT or human equipment")
	grab_receipts.append({"before":initial.parts[0].position,"after":after.parts[0].position,
		"force":interaction.grab_state().force,"native_tick":native_tick(),"rapier_tick":physical_tick()})
	await screenshot("sandbox-02-physical-grab","A real barrel follows bounded mouse forces while the runner and native materials continue; the amber line shows the physical anchor and target.")
	await pointer(Vector2.ZERO,false,true)
	check(not interaction.grab_state().active,"mouse release outside canvas ends force ownership")
	if not await phase("released body continues ordinary simulation",6): return
	var runner: Dictionary = session.capture_workbench_assembly(2)
	var limb: Dictionary = runner.parts.back()
	var last_part: int = runner.parts.size()-1
	var displayed_limb := displayed_part_position(2,last_part)
	if not check(displayed_limb.is_finite(),"runner limb is present in the displayed frame"): return
	await pointer(displayed_limb,true)
	if check(interaction.grab_state().active and int(interaction.grab_state().instance_id)==2,"canvas picks a real articulated runner part"):
		var chosen: int = interaction.grab_state().part_index
		check(chosen==last_part,"the displayed runner limb receives the live grab")
		var accepted: int = session.workbench_control(2).accepted
		await motion(Vector2(limb.position)+Vector2(28,-60))
		await phase("limb force propagates through retained Rapier joints",18)
		var pulled: Dictionary = session.capture_workbench_assembly(2)
		check(pulled.joint_count==runner.joint_count and pulled.parts.size()==runner.parts.size(),"part grabbing keeps actual joint graph")
		check(Vector2(pulled.parts[0].position).distance_to(runner.parts[0].position)>1.0,"connected root responds while another part is pulled")
		check(session.workbench_control(2).accepted==accepted,"only grabbed actor decisions are suppressed")
		grab_receipts.append({"instance_id":2,"picked_part":chosen,"parts":pulled.parts.size(),"joints":pulled.joint_count})
		await pointer(limb.position,false)
		await phase("released runner resumes its original controller",12)
		check(session.workbench_control(2).accepted>accepted,"release resumes previous scripted producer")
	for reason: String in ["focus","panel","pause","save"]:
		await pointer(displayed_part_position(3,0),true)
		if not check(interaction.grab_state().active,"repeat grab before "+reason): continue
		match reason:
			"focus":
				host.test_focus = false
				await process_frame
				await process_frame
				host.test_focus = true
			"panel":
				ui.open_actor_composition()
				await process_frame
				check(not host.paused,"configuration does not pause unrelated NPCs")
				ui._actor_panel.hide()
			"pause":
				await pause_owners()
				ui.toggle_pause()
			"save":
				ui._name.text = save_name
				check(ui.save_setup(),"Save stores authored start during temporary manipulation")
		check(not interaction.grab_state().active,reason+" safely revokes temporary force")
		await pointer(Vector2.ZERO,false,true)
	interaction.set_mode("paint")
	ui.paint_editor.select_tool("Brush")
	ui.paint_editor.select_material(58)
	var points: Array[Vector2i] = [Vector2i(398,160),Vector2i(418,160),SAVED_PAINT]
	if fast_canvas_stroke(points):
		await until(func() -> bool: return points.all(func(point: Vector2i) -> bool: return host.image.get_pixelv(point).r8==58),
			"existing running Brush includes distinct final release endpoint")
	if await click_canvas(points[0],MOUSE_BUTTON_RIGHT):
		await until(func() -> bool: return host.image.get_pixelv(points[0]).r8==0,"right-click Eraser remains live")
	await phase("accepted live paint and independent NPC progression",12)
	check(ui.pilot_id()==1,"inspection and manipulation never implicitly transfer pilot")
	await pause_owners()
	ui._name.text = save_name
	check(ui.save_setup(),"authored orientation, capacity, controllers and accepted paint save together")
	var saved := Setup.read_named(save_name)
	check(saved.has("setup") and saved.setup.sandbox_capacity.logical_limit==64,"expanded configured capacity survives serialization")
	check(saved.has("setup") and authored_match(saved.setup.actors,ui.applied.actors),"actor configuration and authored angle precision survive JSON")
	check(not FileAccess.get_file_as_string(Setup._path(save_name)).contains("retained_parts"),"Save does not serialize live deformation or grab state")
	check(not host.simulation_worker.has_failed() and host.sample_refusals.is_empty(),"native worker has no unexpected physical publication refusals")
	# Save an actual large composition as a separate authored start. The fresh
	# process below must reconstruct all64 bodies, not merely retain a budget.
	if not check(ui.load_actor_sandbox("barrels",64),"64-barrel named example prepares for persistence"): return
	if not await until(installed,"all64 actual barrel bodies adopted before Save"): return
	check(ui.applied.actors.size()==64 and host.physical_actor_session.bodies().size()==64,
		"saved crowd contains64 real actors and bodies")
	ui._name.text = save_name+"-crowd"
	check(ui.save_setup(),"save complete64-actor composition with versioned budgets")


func reopen() -> void:
	ui._name.text = save_name
	var saved := Setup.read_named(save_name)
	if not check(saved.has("setup"),"fresh process finds saved sandbox authored start"): return
	if not check(ui.load_setup(),"fresh process requests saved ordinary Workbench"): return
	if not await until(installed,"fresh-process orientation and capacity prepared owners"): return
	check(ui.applied.actors==saved.setup.actors and ui.applied.sandbox_capacity==saved.setup.sandbox_capacity,
		"fresh process retains all authored actors, controllers, orientations and budgets")
	for actor: Dictionary in ui.applied.actors:
		var pose: Dictionary = host.physical_actor_session.capture_workbench_assembly(int(actor.id))
		check(Vector2(pose.position).distance_to(Setup.point(actor.spawn))<0.002 \
			and absf(angle_difference(float(pose.rotation),deg_to_rad(float(actor.get("spawn_rotation_degrees",0)))))<0.00001,
			"authored spawn orientation reconstructs actual colliders for #"+str(actor.id))
	check(host.image.get_pixelv(SAVED_PAINT).r8==58,"fresh process retains accepted authored live Brush endpoint")
	check(not ui.actor_interaction.grab_state().active and host.paused,"fresh reopen is paused with no temporary mouse ownership")
	ui.toggle_pause()
	await phase("fresh saved composition remains physically playable",12)
	await screenshot("sandbox-03-reopen","A fresh process reconstructs the rotated authored assembly and accepted paint; evolved pose and temporary grabbing are not checkpoints.")
	if not await pause_owners(): return
	ui._name.text = save_name+"-crowd"
	if not check(ui.load_setup(),"fresh process requests saved64-barrel composition"): return
	if not await until(installed,"fresh process reconstructs entire saved crowd"): return
	check(ui.applied.actors.size()==64 and host.physical_actor_session.bodies().size()==64,
		"fresh reopen never truncates64 actors to the old default")
	check(int(ui.applied.sandbox_capacity.logical_limit)>=64,"crowd restores its required configured limit")
	ui.set_camera(2)
	ui.toggle_pause()
	await phase("fresh64-barrel composition progresses both owners",12)
	var native: Dictionary = host.latest_snapshot.lab_context.get("workbench_gcr",{})
	check(int(native.get("active_bodies",0))==64 and int(native.get("active_proxies",0))==64,
		"fresh saved crowd has64 actual native response owners and occupancy proxies")


func run() -> void:
	root.size = Vector2i(1920,1080)
	save_name = OS.get_environment("CYBERSAND_ACTOR_SANDBOX_NAME")
	if save_name.is_empty(): save_name = "actor-sandbox-737-evaluation"
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	if await until(func() -> bool: return host.shared_workbench != null,"ordinary sandbox opens"):
		ui = host.shared_workbench
		host.world_view.gui_input.connect(observe_canvas_input)
		if await until(installed,"ordinary native owner installed"):
			if OS.get_environment("CYBERSAND_ACTOR_SANDBOX_REOPEN")=="1": await reopen()
			else:
				await idle_camera_pan()
				if await install_cast():
					await paused_placement()
					if failures.is_empty(): await live_interactions()
	finish()


func finish() -> void:
	var record := {"case":"WB-ACTOR-COMPOSE-002R actual viewport/native/Rapier", "checks":checks,"failures":failures,
		"headless":DisplayServer.get_name()=="headless","elapsed_msec":Time.get_ticks_msec()-started_msec,
		"placements":placement_receipts,"grabs":grab_receipts,"phases":phases,"screenshots":screenshots,
		"injected_preparation_refusals":host.rejected_preparations if host != null else []}
	print("WB_ACTOR_SANDBOX_INTERACTION ",JSON.stringify(Catalog._json_value(record)))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
