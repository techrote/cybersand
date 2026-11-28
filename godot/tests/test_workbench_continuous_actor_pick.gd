extends "res://tests/test_workbench_water_composition_native.gd"

# Exact pose/geometry from the original d906 Windows Water failure. This
# separate witness installs that authored pose, then uses ordinary Play/Pause
# to obtain a genuinely completed clipped contact before testing mouse input.
# It does not replace or shorten the broad Water fixture's movement/history arm.
const REPLAY_POSITION := Vector2(349.966766357422,492.289581298828)
const REPLAY_ANGLE := -8.25898553102888e-7
var pick_records: Array[Dictionary] = []
var admission_records: Array[Dictionary] = []
var input_physical_step := -1
var input_manual_steps := -1
var final_input_physical_step := -1
var final_input_manual_steps := -1

func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if not check(graphical,"continuous picking witness requires actual graphical drawing"):
		quit(1)
		return
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(FocusHost)
	host = loaded
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),90000),
		"ordinary Workbench starts with native and Rapier owners"):
		ui = host.shared_workbench
		if await pause_owner():
			var data: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
			var actor: Dictionary = Setup.instance("scooper",4,REPLAY_POSITION)
			actor.spawn_rotation_degrees = rad_to_deg(REPLAY_ANGLE)
			data.actors = [actor]
			data.selected = 4
			data.next_id = 5
			data.edits = [[0,496,512,16,58],[0,0,16,512,58],[496,0,16,512,58],
				[16,272,480,224,Setup.WATER],[400,460,50,36,Setup.SAND]]
			var old_epoch: int = host._physical_epoch
			var old_world: int = host.last_uploaded_world_generation
			check(ui.apply(data),"ordinary authored setup accepts the exact failed Windows pose")
			if check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
				and host._physical_epoch>old_epoch and host._physical_terrain_ready \
				and host.physical_actor_session != null and host.latest_snapshot != null \
				and host.last_uploaded_world_generation>=0 and host.last_uploaded_world_generation!=old_world \
				and host.last_uploaded_world_generation==host.latest_snapshot.render_world_generation),
				"native material and the authored Scooper owner are installed"):
				admission_records.append(admission_state("authored"))
				check(host.physical_actor_session.bridge.body_transform(0).origin.distance_to(REPLAY_POSITION)<0.0001,
					"actual authored start matches the recorded Windows position")
				ui._camera.select(0)
				ui.set_camera(0)
				ui._set_view(Vector2(270,412),Vector2i(160,100))
				root.gui_release_focus()
				# Initial authoring closure does not authorize opaque contact clipping.
				# Obtain genuine native/Rapier completion through the ordinary owner.
				if check(ui.toggle_pause(),"ordinary Play requests real contact admission"):
					var admitted: bool = await until(func() -> bool: return host.physical_actor_session.tick>0 \
						and host.workbench_presentation_frame.get("valid",false) \
						and host.workbench_presentation_frame.get("world_generation",-1)==host.last_uploaded_world_generation \
						and host.workbench_presentation_frame.get("contact_clips",{}).has(0) \
						and host.workbench_presentation_frame.get("water_proofs",{}).get(0,{}).get("kind")=="current_completed_native_dependency")
					admission_records.append(admission_state("completed_contact"))
					if check(admitted,"real completed native contact is graphically admitted") and await pause_owner():
						if check(await until(func() -> bool: return host.workbench_presentation_frame.get("contact_clips",{}).has(0) \
							and host.workbench_presentation_frame.get("selected_steps",{}).get(0,-1)==host.physical_actor_session.tick),
							"ordinary Pause retains the actual completed clipped frame"):
							await RenderingServer.frame_post_draw
							await replay_clicks()
	admission_records.append(admission_state("finished"))
	check(not host.simulation_worker.has_failed(),"native World remains healthy after picking controls")
	var inputs: Dictionary = {}
	for path: String in [get_script().resource_path,"res://scripts/main.gd","res://scripts/shared_workbench.gd",
		"res://scripts/physical_actor_session.gd","res://scripts/physical_actor_rig.gd",
		"res://scripts/workbench_presentation_coherence.gd","res://tests/test_workbench_water_composition_native.gd"]:
		inputs[path] = FileAccess.get_sha256(path)
	for path: String in ["res://addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"),
		"res://addons/godot-rapier2d/bin/"+("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if OS.get_name()=="Windows" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")]:
		inputs[path] = FileAccess.get_sha256(path)
	var receipt := {"schema":"pubpres-continuous-actor-pick-v1","checks":checks,"failures":failures,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"input_hashes":inputs,
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine":Engine.get_version_info(),
		"display":DisplayServer.get_name(),"records":pick_records,"admission":admission_records,
		"input_physical_step":input_physical_step,"input_manual_steps":input_manual_steps,
		"final_input_physical_step":final_input_physical_step,"final_input_manual_steps":final_input_manual_steps,
		"selected_owner_readback":{"flight_pacing":host._flight_pacing and host.simulation_worker._notify_sample_completion,
			"coupling_clock":host.simulation_worker._independent_coupling,"empty_effects":host._check_ambient_sources},
		"scope":"Exact recorded Windows Scooper start authored through ordinary native owner, then ordinary Play obtains a real completed contact and Pause retains that accepted frame. Actual Select mouse events at its exposed continuous edge, opaque padded-hit and foreign-owner refusal controls. Mouse controls preserve the positive admitted physical count. No physical display or comparative performance claim."}
	host.simulation_worker.stop_worker()
	host.queue_free()
	await process_frame
	await process_frame
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(receipt,"\t")+"\n")
		else: check(false,"continuous picking receipt opens")
	print("PUBPRES_CONTINUOUS_ACTOR_PICK_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))

func admission_state(label: String) -> Dictionary:
	var frame: Dictionary = host.workbench_presentation_frame
	var session: Variant = host.physical_actor_session
	return {"label":label,"paused":host.paused,"pending_apply":not host.pending_microscenario_apply.is_empty(),
		"terrain_ready":host._physical_terrain_ready,"world":host.last_uploaded_world_generation,
		"revision":host.last_uploaded_revision,"frame_valid":frame.get("valid",false),
		"reason":frame.get("reasons",{}).get(0,"missing"),"visible":frame.get("poses",{}).has(0),
		"contact_clipped":frame.get("contact_clips",{}).has(0),
		"proof_kind":frame.get("water_proofs",{}).get(0,{}).get("kind","missing"),
		"selected_step":frame.get("selected_steps",{}).get(0,-1),
		"physical_step":session.tick if session != null else -1,
		"manual_steps":session.bridge.manual_step_count() if session != null else -1}

func replay_clicks() -> void:
	var frame: Dictionary = host.workbench_presentation_frame
	var pose: Transform2D = frame.poses[0]
	var rig: Node2D = host.physical_actor_session._rigs[0]
	var clipped: Dictionary = frame.contact_clips[0]
	# Use a fixed interior point on the first collider's exposed left edge.
	# The real settled pose may differ from the authored failure reproduction;
	# the same integer-rounding defect must be independently witnessed here.
	var rectangle: Dictionary = rig.collision_rects(0)[0]
	var visible: Vector2 = pose*(Vector2(rectangle.center)+Vector2(-float(rectangle.size.x)*0.5+0.05,0))
	check(not rig.pick_part(visible,{0:pose},0.0).is_empty(),"actual continuous pointer is inside the unpadded accepted collider")
	check(rig.pick_part(Vector2(Vector2i(visible)),{0:pose},0.0).is_empty(),
		"integer truncation moves the actual visible pointer outside that same collider")
	check(preload("res://scripts/workbench_presentation_coherence.gd").contact_point_visible(visible,clipped),
		"continuous pointer addresses genuinely visible Water in the accepted material clip")
	input_physical_step = host.physical_actor_session.tick
	input_manual_steps = host.rapier_bridge.manual_step_count()
	check(input_physical_step>0 and input_manual_steps==input_physical_step,
		"mouse controls begin after actual matching native/Rapier contact admission")
	ui._tool.select(2)
	actual_click("visible_continuous_edge",visible,4)
	# The ordinary two-cell selection aid reaches into the opaque basin below
	# the same member. Its unchanged material clip must still refuse that hit.
	var opaque := Vector2(pose.origin.x,496.5)
	check(not rig.pick_part(opaque,{0:pose},2.0).is_empty(),"opaque control lies inside the ordinary padded hit envelope")
	check(not preload("res://scripts/workbench_presentation_coherence.gd").contact_point_visible(opaque,clipped),
		"opaque control addresses rejected accepted material")
	actual_click("opaque_member_pixel",opaque,0)
	# Explicit immutable-identity adversary. No physical/native owner is edited.
	var saved: Dictionary = host.workbench_presentation_frame
	var foreign := saved.duplicate(true)
	foreign.mask_frame.session = int(foreign.mask_frame.session)+1
	host.workbench_presentation_frame = foreign
	actual_click("foreign_owner",visible,0)
	host.workbench_presentation_frame = saved
	actual_click("restored_original_owner",visible,4)
	final_input_physical_step = host.physical_actor_session.tick
	final_input_manual_steps = host.rapier_bridge.manual_step_count()
	check(final_input_physical_step==input_physical_step and final_input_manual_steps==input_manual_steps,
		"all mouse and refusal controls preserve the positive actual physical completion count")
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		var png := output.get_base_dir().path_join("continuous-pick.png")
		check(root.get_texture().get_image().save_png(png)==OK,"actual accepted Scooper framebuffer is saved")
		pick_records.append({"framebuffer":"continuous-pick.png","sha256":FileAccess.get_sha256(png)})

func actual_click(label: String, world_point: Vector2, expected: int) -> void:
	var frame: Dictionary = host.workbench_presentation_frame
	check(ui.select_instance(0),label+" begins with empty ordinary selection")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = host._world_view_screen_transform().affine_inverse()*(frame.camera_mapping*world_point)
	var mapped: Vector2 = host.world_position_from_local_point(click.position,true)
	var cell: Vector2i = host.world_cell_from_local_point(click.position,true)
	ui._world_input(click)
	check(ui.selected_id()==expected,label+" actual Select mouse route preserves accepted geometry and ownership")
	pick_records.append({"label":label,"world_point":Trace.xy(world_point),"mapped":Trace.xy(mapped),
		"material_cell":[cell.x,cell.y],"selected":ui.selected_id(),"expected":expected,
		"session":frame.session,"epoch":frame.epoch,"world":frame.world_generation,
		"mask_session":frame.mask_frame.session,
		"physical_step":host.physical_actor_session.tick})
