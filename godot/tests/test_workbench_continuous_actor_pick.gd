extends "res://tests/test_workbench_water_composition_native.gd"

# Exact pose/geometry from the original d906 Windows Water failure. This
# separate production-path witness installs that authored pose directly; it
# does not replace or shorten the broad Water fixture's movement/history arm.
const REPLAY_POSITION := Vector2(349.966766357422,492.289581298828)
const REPLAY_ANGLE := -8.25898553102888e-7
var pick_records: Array[Dictionary] = []

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
			check(ui.apply(data),"ordinary authored setup accepts the exact failed Windows pose")
			if check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
				and host._physical_epoch>old_epoch and host._physical_terrain_ready \
				and host.workbench_presentation_frame.get("contact_clips",{}).has(0)),
				"native material and accepted clipped Scooper presentation are installed"):
				ui._camera.select(0)
				ui.set_camera(0)
				ui._set_view(Vector2(270,412),Vector2i(160,100))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				await replay_clicks()
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
		"display":DisplayServer.get_name(),"records":pick_records,
		"selected_owner_readback":{"flight_pacing":host._flight_pacing and host.simulation_worker._notify_sample_completion,
			"coupling_clock":host.simulation_worker._independent_coupling,"empty_effects":host._check_ambient_sources},
		"scope":"Exact recorded Windows Scooper pose authored through ordinary native owner, actual accepted graphical frame and ordinary Select mouse events. Explicit opaque-material and foreign-owner refusal controls. No physical display or comparative performance claim."}
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

func replay_clicks() -> void:
	var frame: Dictionary = host.workbench_presentation_frame
	var pose: Transform2D = frame.poses[0]
	var rig: Node2D = host.physical_actor_session._rigs[0]
	var clipped: Dictionary = frame.contact_clips[0]
	check(pose.origin.distance_to(REPLAY_POSITION)<0.0001,"actual admitted pose matches the recorded Windows position")
	check(not rig.pick_part(pose.origin,{0:pose},0.0).is_empty(),"actual continuous pointer is inside the unpadded accepted collider")
	check(rig.pick_part(Vector2(Vector2i(pose.origin)),{0:pose},0.0).is_empty(),
		"integer truncation reproduces the recorded point outside that same collider")
	check(preload("res://scripts/workbench_presentation_coherence.gd").contact_point_visible(pose.origin,clipped),
		"continuous pointer addresses genuinely visible Water in the accepted material clip")
	var before_step: int = host.physical_actor_session.tick
	ui._tool.select(2)
	actual_click("visible_continuous_origin",pose.origin,4)
	# The bottom of this same accepted collider crosses opaque basin material.
	# Picking must still reject it, even though it belongs to a shown actor.
	var opaque := pose*Vector2(0,3.7185)
	check(not rig.pick_part(opaque,{0:pose},0.0).is_empty(),"opaque control lies inside the same real collider")
	check(not preload("res://scripts/workbench_presentation_coherence.gd").contact_point_visible(opaque,clipped),
		"opaque control addresses rejected accepted material")
	actual_click("opaque_member_pixel",opaque,0)
	# Explicit immutable-identity adversary. No physical/native owner is edited.
	var saved: Dictionary = host.workbench_presentation_frame
	var foreign := saved.duplicate(true)
	foreign.mask_frame.session = int(foreign.mask_frame.session)+1
	host.workbench_presentation_frame = foreign
	actual_click("foreign_owner",pose.origin,0)
	host.workbench_presentation_frame = saved
	actual_click("restored_original_owner",pose.origin,4)
	check(host.physical_actor_session.tick==before_step and host.rapier_bridge.manual_step_count()==0,
		"all mouse and refusal controls preserve actual physical completion count")
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
