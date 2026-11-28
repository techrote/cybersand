extends "res://tests/test_workbench_water_composition_native.gd"

# A separate, small graphical fault-injection witness. Ordinary authored
# installation and manual Steps still execute. Exactly one presentation
# resolution cannot obtain its newest native pose proof. This isolates the
# observed missing-response condition; it is not a claim to reproduce its
# original scheduler cause or a comparative performance workload.
class ProbeHost extends "res://scripts/main.gd":
	var probe_revision := -1
	var probe_expired := false
	var probe_suppressed := false
	var probe_count := 0
	var probe_result: Dictionary = {}
	var probe_prior: Dictionary = {}
	var probe_wait: Dictionary = {}
	func _actor_window_has_focus() -> bool: return true
	func _workbench_water_dependency(slot: int, frame: Dictionary, entry: Dictionary,
			observation: Dictionary) -> Dictionary:
		return {} if probe_suppressed else super._workbench_water_dependency(slot,frame,entry,observation)
	func _resolve_workbench_presentation_frame(frame: Dictionary) -> Dictionary:
		if probe_revision >= 0:
			probe_wait = {"armed_revision":probe_revision,"uploaded_revision":last_uploaded_revision,
				"mask_valid":_valid_workbench_mask_frame(frame),"mask_revision":frame.get("revision",-1),
				"mask_world":frame.get("world_generation",-1),"uploaded_world":last_uploaded_world_generation,
				"step":physical_actor_session.tick,"native_tick":frame.get("tick",-1),
				"calls":int(probe_wait.get("calls",0))+1}
		if probe_revision < 0 or last_uploaded_revision <= probe_revision or not _valid_workbench_mask_frame(frame):
			return super._resolve_workbench_presentation_frame(frame)
		probe_revision = -1
		probe_prior = {"proof":workbench_presentation_frame.get("water_proofs",{}).get(0,{}).duplicate(true),
			"pose":workbench_presentation_frame.get("poses",{}).get(0),
			"state":_workbench_presentation_state.get(0,{}).duplicate(true),
			"physical_step":physical_actor_session.tick,"manual_steps":rapier_bridge.manual_step_count()}
		if probe_expired and _workbench_presentation_state.has(0):
			# Explicit clock adversary: the production hold must not renew this
			# expired timestamp even though its old endpoint is still clear.
			_workbench_presentation_state[0].hold_started_usec = Time.get_ticks_usec()-WorkbenchPresentationHistory.MAX_HOLD_USEC-1
			probe_prior["injected_hold_started_usec"] = _workbench_presentation_state[0].hold_started_usec
		probe_suppressed = true
		var result := super._resolve_workbench_presentation_frame(frame)
		probe_suppressed = false
		probe_result = result
		probe_count += 1
		return result

var probe_records: Array[Dictionary] = []
var probe_images: Array[Image] = []
var observed_probe := 0

func _initialize() -> void:
	super._initialize()
	var selected_output := OS.get_environment("CYBERSAND_RETAINED_WATER_NATIVE_OUTPUT")
	if not selected_output.is_empty(): output = selected_output

func capture_probe() -> void:
	if host.probe_count <= observed_probe: return
	observed_probe = host.probe_count
	var actual: Dictionary = host.workbench_presentation_frame
	var proposed: Dictionary = host.probe_result
	check(actual.get("draw_usec",-1)==proposed.get("draw_usec",-2),
		"faulted selection is observed on its actual first graphical draw")
	var prior: Dictionary = host.probe_prior
	var expected_hold: bool = not host.probe_expired
	if expected_hold:
		# Freeze only AFTER the genuine first draw. These two framebuffer
		# controls compare the exact submitted state without allowing a later
		# normal response, changing pose, camera or material fade to confound it.
		# The ordinary runtime is resumed immediately after the controls.
		host.set_process(false)
		host.set_physics_process(false)
	check(not prior.proof.is_empty() and prior.pose is Transform2D,
		"the witness starts with a genuine submitted Water actor")
	check(actual.get("poses",{}).has(0)==expected_hold,
		"new material retains only the unexpired submitted endpoint")
	if expected_hold and actual.get("poses",{}).has(0):
		var proof: Dictionary = actual.get("water_proofs",{}).get(0,{})
		check(actual.sources.get(0)=="held" and actual.poses[0]==prior.pose,
			"the missing current proof selects exactly the previously drawn physical pose")
		for field: String in ["kind","step","sample","native_tick","completed_usec","native_completed_usec"]:
			check(proof.get(field)==prior.proof.get(field),"the held proof preserves its original "+field)
		check(proof.has("held_material_revalidation") and proof.get("visible_material",{}).get("revision",-1)==actual.material_revision,
			"the newer material certificate is separate from original native authority")
		var old_step: int = host.physical_actor_session.tick
		ui._tool.select(2)
		check(ui.select_instance(0),"ordinary selection can be cleared before the held-frame mouse click")
		var local: Vector2 = host._world_view_screen_transform().affine_inverse()*(actual.camera_mapping*prior.pose.origin)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = local
		ui._world_input(click)
		check(ui.selected_id()==2,"ordinary mouse picking selects the Barrel shown in the retained frame")
		check(host.physical_actor_session.tick==old_step,"picking the retained frame creates no physical completion")
	elif not expected_hold:
		check(str(actual.get("reasons",{}).get(0,"")).begins_with("hold_expired:"),
			"rechecking new material cannot renew an expired 100 ms hold")
		check(int(actual.get("hold_age_usec",{}).get(0,0))>=100000 \
			and host._workbench_presentation_state.get(0,{}).get("hold_started_usec",0)==prior.get("injected_hold_started_usec",-1),
			"the actual resolver preserves the original expired hold timestamp")
	var screenshot := root.get_texture().get_image()
	probe_images.append(screenshot)
	var label := "expired" if host.probe_expired else "held"
	if not output.is_empty(): check(screenshot.save_png(output.get_base_dir().path_join(label+".png"))==OK,
		label+" actual first-read framebuffer is saved")
	probe_records.append({"label":label,"selected":actual.get("poses",{}).has(0),
		"source":actual.get("sources",{}).get(0),"reason":actual.get("reasons",{}).get(0),
		"hold_age_usec":actual.get("hold_age_usec",{}).get(0),
		"original_proof":prior.proof,"proof":actual.get("water_proofs",{}).get(0,{}).duplicate(true),
		"prior_pose":Trace.pose_json(prior.pose) if prior.pose is Transform2D else {},
		"prior_step":prior.physical_step,"actual_step":host.physical_actor_session.tick,
		"prior_hold_started_usec":prior.state.get("hold_started_usec",0),
		"injected_hold_started_usec":prior.get("injected_hold_started_usec",0),
		"manual_steps":host.physical_actor_session.bridge.manual_step_count(),
		"world":actual.world_generation,"revision":actual.material_revision,"upload":actual.upload_serial,
		"camera_mapping":actual.camera_mapping,"pixel_size":[screenshot.get_width(),screenshot.get_height()]})

func draw_once() -> void:
	await RenderingServer.frame_post_draw

func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if not check(graphical,"actual graphical display is required for the retained endpoint witness"):
		quit(1)
		return
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(ProbeHost)
	host = loaded
	root.add_child(host)
	root.size = Vector2i(1280,800)
	RenderingServer.frame_post_draw.connect(capture_probe)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),90000),
		"ordinary Workbench starts with the exact native runtime"):
		check(host._flight_pacing and host.simulation_worker._independent_coupling and host._check_ambient_sources,
			"the actual mounted runtime uses all three positively evaluated owner policies")
		ui = host.shared_workbench
		if await pause_owner():
			var data: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
			data.actors = [Setup.instance("reference_barrel",2,Vector2(220,430))]
			data.selected = 2
			data.next_id = 3
			data.edits = [[0,496,512,16,58],[16,272,480,224,Setup.WATER]]
			var old_epoch: int = host._physical_epoch
			check(ui.apply(data),"ordinary authored submerged Barrel setup is admitted")
			if check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
				and host._physical_epoch>old_epoch and host._physical_terrain_ready \
				and host.workbench_presentation_frame.get("water_proofs",{}).has(0)),
				"native material and the initial Barrel presentation are installed"):
				ui._camera.select(0)
				ui.set_camera(0)
				ui._set_view(Vector2(140,380),Vector2i(160,100))
				if await ordinary_step("ordinary_manual_step"):
					check(await until(func() -> bool: return host.workbench_presentation_frame.get("water_proofs",{}).has(0) \
						and host.workbench_presentation_frame.get("selected_steps",{}).get(0,-1)==host.physical_actor_session.tick),
						"manual Step obtains a real completed Barrel presentation before the fault")
					await probe_sequence()
	check(not host.simulation_worker.has_failed(),"native World remains healthy through the separate graphical witness")
	check(probe_records.size()==2,"both real draw probes execute, including original hold-clock expiry")
	RenderingServer.frame_post_draw.disconnect(capture_probe)
	var inputs: Dictionary = {}
	for path: String in [get_script().resource_path,"res://scripts/main.gd","res://scripts/workbench_water_composition.gd",
			"res://scripts/workbench_presentation_coherence.gd","res://scripts/workbench_physics_bridge.gd",
			"res://scripts/shared_workbench.gd","res://tests/test_workbench_water_composition_native.gd"]:
		inputs[path] = FileAccess.get_sha256(path)
	var runtime := "res://addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so")
	inputs[runtime] = FileAccess.get_sha256(runtime)
	var rapier := "res://addons/godot-rapier2d/bin/"+("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if OS.get_name()=="Windows" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
	inputs[rapier] = FileAccess.get_sha256(rapier)
	var framebuffer_files: Dictionary = {}
	if not output.is_empty():
		for name: String in ["held.png","expired.png","hidden-control.png","restored.png"]:
			var path := output.get_base_dir().path_join(name)
			if FileAccess.file_exists(path): framebuffer_files[name] = FileAccess.get_sha256(path)
	var result := {"schema":"pubpres-retained-water-native-v1","checks":checks,"failures":failures,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"input_hashes":inputs,
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine":Engine.get_version_info(),
		"display":DisplayServer.get_name(),"probes":probe_records,"framebuffer":framebuffer,
		"probe_wait":host.probe_wait,"framebuffer_files_sha256":framebuffer_files,
		"selected_owner_readback":{"flight_pacing":host._flight_pacing,
			"coupling_clock":host.simulation_worker._independent_coupling,"empty_effects":host._check_ambient_sources},
		"scope":"Mounted native/Rapier ordinary Steps and their real material publications; one resolution's newest native proof deliberately unavailable. Actual first graphical reads and ordinary mouse route; original 100 ms expiry tested with explicit clock adversary. Subsequent hidden/restored framebuffer controls freeze only the already submitted state. No scheduler-cause, performance or physical display acceptance claim."}
	host.simulation_worker.stop_worker()
	host.queue_free()
	await process_frame
	await process_frame
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"\t")+"\n")
		else: check(false,"the retained endpoint evidence file opens")
	print("PUBPRES_RETAINED_WATER_NATIVE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))

func probe_sequence() -> void:
	for ignored: int in range(4): await draw_once()
	var clock_materials: Array = [host.world_shader,host.glow_source_shader]
	clock_materials.append_array(host.vapour_trail_shaders)
	for material: ShaderMaterial in clock_materials: material.set_shader_parameter("presentation_time_override",4.0)
	var original_step: int = host.physical_actor_session.tick
	host.probe_revision = host.last_uploaded_revision
	if not check(ui.step_once(),"ordinary manual Step requests the newer native/material publication"): return
	if not check(await until(func() -> bool: return probe_records.size()==1),"first retained frame is actually observed"): return
	check(host.physical_actor_session.tick==original_step+1 \
		and host.rapier_bridge.manual_step_count()==original_step+1,
		"the first fault follows exactly one genuine additional Rapier Step")
	await frozen_framebuffer_controls()
	host.set_process(true)
	host.set_physics_process(true)
	if not check(await until(func() -> bool: return not ui.step_pending \
		and host.workbench_presentation_frame.get("water_proofs",{}).has(0) \
		and host.workbench_presentation_frame.get("selected_steps",{}).get(0,-1)==host.physical_actor_session.tick),
		"ordinary current native proof resumes after the bounded framebuffer controls"): return
	await draw_once()
	host.probe_expired = true
	host.probe_revision = host.last_uploaded_revision
	if not check(ui.step_once(),"ordinary second manual Step requests another real material publication"): return
	check(await until(func() -> bool: return probe_records.size()==2),"expired old endpoint is observed on the next real draw")
	check(host.physical_actor_session.tick==original_step+2 \
		and host.rapier_bridge.manual_step_count()==original_step+2,
		"only the two requested ordinary Steps advance real physical completion")
	for material: ShaderMaterial in clock_materials: material.set_shader_parameter("presentation_time_override",-1.0)

func frozen_framebuffer_controls() -> void:
	var frame: Dictionary = host.workbench_presentation_frame
	if not frame.get("poses",{}).has(0): return
	var overlay: Control = host.physical_actor_overlay
	var viewport_point: Vector2 = overlay.get_global_transform_with_canvas()*overlay._point(frame.poses[0].origin)
	var pixel := Vector2i((viewport_point*Vector2(probe_images[0].get_size())/root.get_visible_rect().size).floor())
	host.physical_actor_overlay.modulate.a = 0.0
	await draw_once()
	var hidden := root.get_texture().get_image()
	host.physical_actor_overlay.modulate.a = 1.0
	await draw_once()
	var restored := root.get_texture().get_image()
	var visible_difference := 0.0
	var restore_error := 0.0
	for y: int in range(pixel.y-2,pixel.y+3):
		for x: int in range(pixel.x-2,pixel.x+3):
			if not Rect2i(Vector2i.ZERO,hidden.get_size()).has_point(Vector2i(x,y)): continue
			visible_difference = maxf(visible_difference,color_error(probe_images[0].get_pixel(x,y),hidden.get_pixel(x,y)))
			restore_error = maxf(restore_error,color_error(probe_images[0].get_pixel(x,y),restored.get_pixel(x,y)))
	check(visible_difference>0.025,"the retained draw contains actual submerged Barrel pixels")
	check(restore_error<0.025,"the restored exact submitted state reproduces the retained Barrel pixels")
	if not output.is_empty():
		check(hidden.save_png(output.get_base_dir().path_join("hidden-control.png"))==OK,"hidden framebuffer control saved")
		check(restored.save_png(output.get_base_dir().path_join("restored.png"))==OK,"restored framebuffer control saved")
	framebuffer = [{"pixel":[pixel.x,pixel.y],"visible_difference":visible_difference,"restore_error":restore_error}]
