extends SceneTree

# Run-only observer for the actual, unchanged source Main scene. No physics
# callback, native step, input action, World edit or publication is replaced.
# The signal disconnects after startup; ordinary owner play has no poll cost.
var app: Control
var receipt_path := ""
var deadline_msec := 0
var ready_frames := 0


func _initialize() -> void:
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
	var actor_count: int = app.shared_workbench.applied.get("actors",[]).size()
	if (actor_count > 0) != (app.physical_actor_session != null): return
	if actor_count > 0 and (not app.rapier_bridge.is_initialized() or not app._physical_terrain_ready \
		or app._actor_reset_receipt != 0): return
	ready_frames += 1
	if ready_frames < 2: return
	var material: Variant = app.call("material_publication_status") if app.has_method("material_publication_status") else null
	var receipt := {"schema":"pubpres-playability-owner-start-v2","ready":true,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
		"rapier_sha256":FileAccess.get_sha256("res://addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"observer_sha256":FileAccess.get_sha256(get_script().resource_path),
		"project_sha256":FileAccess.get_sha256("res://project.godot"),
		"override_sha256":FileAccess.get_sha256("res://override.cfg"),
		"world_generation":app.last_uploaded_world_generation,"material_revision":app.last_uploaded_revision,
		"native_tick":app.latest_snapshot.tick_index,"authored_actor_count":actor_count,
		"material_publication":material,
		"same_frame_continuation":app.call("same_frame_continuation_status") if app.has_method("same_frame_continuation_status") else null,
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"render_driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"platform":OS.get_name(),"process_id":OS.get_process_id(),
		"profile":OS.get_user_data_dir(),"physical_acceptance":"HOLD",
		"scope":"Observed ordinary installed native World and uploaded material; no gameplay or physical-device acceptance."}
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
