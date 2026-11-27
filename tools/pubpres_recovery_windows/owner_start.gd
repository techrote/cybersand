extends SceneTree

# Run-only observer for the actual, unchanged source Main scene. No physics
# callback, native step, input action, World edit or publication is replaced.
# The signal disconnects after startup; ordinary owner play has no poll cost.
const Setup = preload("res://scripts/workbench_setup.gd")
var scene_name := "ordinary"
var scene_requested: bool = false
var scene_epoch: int = -1
var app: Control
var receipt_path := ""
var deadline_msec := 0
var ready_frames := 0


func _initialize() -> void:
	if OS.get_environment("CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER") != "0":
		push_error("PUBPRES owner package has no selected task-completion treatment")
		quit(2)
		return
	ProjectSettings.set_setting("cybersand/pubpres_task_completion_barrier",false)
	scene_name = OS.get_environment("CYBERSAND_FINAL_SCENE")
	if scene_name not in ["ordinary","wave512","wave1024","wave2048","mixed2048"]:
		push_error("PUBPRES unknown owner scene")
		quit(2)
		return
	receipt_path = OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_RECEIPT")
	if receipt_path.is_empty():
		push_error("PUBPRES owner launch requires an explicit receipt destination")
		quit(2)
		return
	set_meta("cybersand_feature","shared_workbench")
	_start.call_deferred()


func _start() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	deadline_msec = Time.get_ticks_msec()+240000
	process_frame.connect(_poll)


func _poll() -> void:
	if Time.get_ticks_msec() > deadline_msec:
		push_error("PUBPRES ordinary Workbench startup timed out")
		quit(3)
		return
	if app == null or app.latest_snapshot == null: return
	if app.latest_snapshot.simulation_failed or app.simulation_worker.has_failed():
		push_error("PUBPRES native owner failed during startup")
		quit(4)
		return
	if app.shared_workbench == null or app.shared_workbench.applied.is_empty() \
		or not app.pending_microscenario_apply.is_empty() or app._pending_physical_candidate != null \
		or app.worker_start_error != OK or app.rapier_start_error != OK \
		or app.last_uploaded_revision < 0 or app.last_uploaded_world_generation < 0 \
		or app.last_uploaded_world_generation != app.latest_snapshot.render_world_generation \
		or app.rapier_bridge.pending_hard_surface_chunks() != 0:
		ready_frames = 0
		return
	if scene_name != "ordinary" and not scene_requested:
		scene_requested = true
		scene_epoch = app._physical_epoch
		var setup := _representative_setup(PackedInt32Array(app.shared_workbench.applied.liquid_policy))
		if not app.shared_workbench.apply(setup,false,0,false,false,{},{},false):
			push_error("PUBPRES representative scene refused: "+str(app.shared_workbench.message))
			quit(6)
		return
	if scene_requested and app._physical_epoch <= scene_epoch: return
	if scene_requested:
		if not app.tower_context.get("wave_flow",{}).get("enabled",false):
			push_error("PUBPRES representative scene lacks active native Wave Flow")
			quit(7)
			return
		app.shared_workbench._camera.select(1)
		app.shared_workbench.set_camera(1)
	var actor_count: int = app.shared_workbench.applied.get("actors",[]).size()
	if (actor_count > 0) != (app.physical_actor_session != null): return
	if actor_count > 0 and (not app.rapier_bridge.is_initialized() or not app._physical_terrain_ready \
		or app._actor_reset_receipt != 0): return
	ready_frames += 1
	if ready_frames < 2: return
	if OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION") == "1":
		var submitted: Dictionary = app.workbench_presentation_submission_status()
		if not bool(submitted.get("enabled",false)) or not bool(submitted.get("engine_atomic_admission",false)) \
			or int(submitted.get("committed_count",0)) <= 0 \
			or int(app.workbench_presentation_frame.get("world_generation",-1)) != app.last_uploaded_world_generation:
			return
	var scene_material_witness: Dictionary = {}
	if scene_name == "mixed2048":
		# Read the already accepted Main CPU image produced by the native owner.
		# No live World access or extra GPU readback is introduced by startup.
		var sand_cell := Vector2i(864,app.world_extent.y-104)
		var observed_material: int = app.image.get_pixelv(sand_cell).r8
		if observed_material != CyberCellWorld.SAND:
			push_error("PUBPRES mixed start lacks published Sand at the registered witness cell")
			quit(8)
			return
		scene_material_witness = {"cell":[sand_cell.x,sand_cell.y],
			"expected_material":CyberCellWorld.SAND,"observed_material":observed_material,
			"uploaded_serial":app.last_uploaded_render_snapshot_serial,
			"world_generation":app.last_uploaded_world_generation,
			"scope":"Already uploaded native material image; paused authored Sand, not a physics-step witness."}
	var material: Variant = app.call("material_publication_status") if app.has_method("material_publication_status") else null
	var receipt := {"schema":"pubpres-recovery-owner-start-v1","ready":true,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
			if OS.get_name() == "Linux" else "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
		"rapier_sha256":FileAccess.get_sha256("res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
			if OS.get_name() == "Linux" else "res://addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"observer_sha256":FileAccess.get_sha256(get_script().resource_path),
		"project_sha256":FileAccess.get_sha256("res://project.godot"),
		"override_sha256":FileAccess.get_sha256("res://override.cfg"),
		"scene":scene_name,"extent":[app.world_extent.x,app.world_extent.y],
		"scene_material_witness":scene_material_witness,
		"authored_setup_sha256":JSON.stringify(app.shared_workbench.applied).sha256_text(),
		"wave_flow":app.tower_context.get("wave_flow",{}).duplicate(true),
		"world_generation":app.last_uploaded_world_generation,"material_revision":app.last_uploaded_revision,
		"native_tick":app.latest_snapshot.tick_index,"authored_actor_count":actor_count,
		"material_publication":material,
		"recovery":_recovery_readback(),
		"material_deadline":app.call("material_deadline_status") if app.has_method("material_deadline_status") else null,
		"same_frame_continuation":app.call("same_frame_continuation_status") if app.has_method("same_frame_continuation_status") else null,
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"render_driver":RenderingServer.get_current_rendering_driver_name(),
		"display_server":DisplayServer.get_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"platform":OS.get_name(),"process_id":OS.get_process_id(),
		"profile":OS.get_user_data_dir(),
		"user_directory_policy":{"application_name":ProjectSettings.get_setting("application/config/name"),
			"use_custom_user_dir":ProjectSettings.get_setting("application/config/use_custom_user_dir",false)},
		"physical_acceptance":"HOLD",
		"scope":"Observed ordinary installed native World and uploaded material; no gameplay or physical-device acceptance."}
	var pacing_request := OS.get_environment("CYBERSAND_WORKBENCH_FLIGHT_PACING")
	if not pacing_request.is_empty():
		receipt.flight_pacing_requested = pacing_request
		receipt.flight_pacing_enabled = app.get("_flight_pacing")
	var effects_request := OS.get_environment("CYBERSAND_WORKBENCH_EMPTY_EFFECTS")
	if not effects_request.is_empty():
		receipt.empty_effects_requested = effects_request
		receipt.empty_effects_enabled = app.get("_check_ambient_sources")
		receipt.ambient_sources_absent = app.get("_ambient_sources_absent")
	var clock_request := OS.get_environment("CYBERSAND_WORKBENCH_COUPLING_CLOCK")
	if not clock_request.is_empty():
		receipt.coupling_clock_requested = clock_request
		receipt.coupling_clock_enabled = app.simulation_worker.get("_independent_coupling")
		var physics_packet: Variant = app.simulation_worker.take_latest_physics_snapshot()
		receipt.coupling_only_completions = physics_packet.lab_context.get("coupling_only_completions") if physics_packet != null else null
	var writer := FileAccess.open(receipt_path,FileAccess.WRITE)
	if writer == null:
		push_error("PUBPRES could not write startup receipt")
		quit(5)
		return
	writer.store_string(JSON.stringify(receipt,"  ")+"\n")
	writer.close()
	process_frame.disconnect(_poll)
	print("PUBPRES_PLAYABILITY_OWNER_READY ",JSON.stringify(receipt))
	if OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_QUIT_AFTER_READY") == "1": quit()


func _recovery_readback() -> Dictionary:
	var water_available: bool = app.has_method("_workbench_water_composition_enabled")
	var submission_available: bool = app.has_method("workbench_presentation_submission_status")
	var idle_available: bool = app.simulation_worker.has_method("workbench_sample_idle_status")
	var submission: Dictionary = app.call("workbench_presentation_submission_status") if submission_available else {}
	var idle: Dictionary = app.simulation_worker.call("workbench_sample_idle_status") if idle_available else {}
	return {"schema":"pubpres-recovery-owner-readback-v1",
		"water_api_available":water_available,"actual_submission_api_available":submission_available,
		"sample_idle_api_available":idle_available,
		"water_requested":OS.get_environment("CYBERSAND_DIAG_WATER_COMPOSITION"),
		"water_enabled":bool(app.call("_workbench_water_composition_enabled")) if water_available else false,
		"actual_submission_requested":OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION"),
		"actual_submission_enabled":bool(submission.get("enabled",false)),
		"submission":submission.duplicate(true),
		"engine_capability":RenderingServer.get_meta(&"cybersand_actual_submission_v2",{}),
		"render_lookahead_requested":OS.get_environment("CYBERSAND_ENGINE_RENDER_LOOKAHEAD"),
		"material_step_interval_requested":OS.get_environment("CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL"),
		"sample_idle_requested":OS.get_environment("CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE"),
		"sample_idle_enabled":bool(idle.get("enabled",false)),
		"task_completion_requested":OS.get_environment("CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER"),
		"task_completion":app.latest_snapshot.lab_context.get("wave_flow",{}).get("task_completion",{}).duplicate(true),
		"scope":"Observed effective application policy after native startup, not physical performance or display acceptance."}


func _representative_setup(policy: PackedInt32Array) -> Dictionary:
	var side := 512 if scene_name == "wave512" else (1024 if scene_name == "wave1024" else 2048)
	var setup: Dictionary = Setup.fresh(policy,Vector2i(side,side))
	setup.rule_radius = 2
	setup.actors = [Setup.instance("needle",1,Vector2(200,160))]
	if scene_name in ["wave1024","mixed2048"]:
		setup.actors.append(Setup.instance(Setup.BARREL,2,Vector2(340,160)))
		setup.actors.append(Setup.instance("needle",3,Vector2(480,160)))
		setup.actors.append(Setup.instance(Setup.BARREL,4,Vector2(620,160)))
	setup.next_id = setup.actors.size()+1
	setup.selected = 1
	setup.edits = [[0,side-16,side,16,58],[0,0,16,side,58],[side-16,0,16,side,58],
		[32,side-240,112,224,3],[160,side-80,144,64,3],[320,side-48,side-336,32,3],
		[256,side-112,8,96,58],[112,side-272,112,8,58]]
	if scene_name == "mixed2048":
		setup.edits.append([768,side-192,192,176,CyberCellWorld.SAND])
		setup.edits.append([1104,side-256,16,240,58])
		setup.edits.append([1120,side-224,224,208,3])
	return setup
