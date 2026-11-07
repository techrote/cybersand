extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	await scene_changed
	var host: Control=current_scene
	var deadline: int=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and (host.shared_workbench==null or host.shared_workbench.busy() or host.shared_workbench.applied.get("actors",[]).size()!=4):
		await process_frame
	var ok: bool=host.shared_workbench!=null and host.shared_workbench.applied.get("actors",[]).size()==4 and host.paused and host.rigid_bodies.size()==4
	if ok:ok=host.physical_actor_session.bridge.manual_step_count()==0 and host.tower_context.workbench_gcr.response=="LA-SELECTIVE"
	await create_timer(0.4).timeout
	var capture: String=OS.get_environment("CYBERSAND_CANVAS_CAPTURE")
	if ok and not capture.is_empty():
		await RenderingServer.frame_post_draw
		ok=root.get_texture().get_image().save_png(capture)==OK
	print("CANVAS_START ","PASS" if ok else "FAIL"," actual_bodies=",host.rigid_bodies.size())
	host.queue_free();await process_frame;await process_frame
	quit(int(not ok))
