extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var requested: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg in ["--blacksite-nine", "--showcase", "--depth-lab", "--deepworks"]: requested = true
	if not requested:
		print("Direct feature arguments require an explicit scene argument; ordinary navigation has its own regression")
		quit()
		return
	change_scene_to_file("res://feature_launcher.tscn")
	var deadline: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path in ["res://main.tscn", "res://depth_lab.tscn", "res://deepworks.tscn"]: break
	if current_scene == null or current_scene.scene_file_path == "res://feature_launcher.tscn":
		push_error("Direct argument did not open its scene")
		quit(1)
		return
	if "--deepworks" in OS.get_cmdline_user_args() and (current_scene.scene_file_path != "res://deepworks.tscn" or current_scene.faulted):
		push_error("Deepworks argument did not open its complete native exhibition")
		quit(1)
		return
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.pressed = true
	root.get_node("FeatureNavigation")._input(event)
	for frame: int in range(8): await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://feature_launcher.tscn":
		push_error("Returning to launcher reapplied the startup argument")
		quit(1)
		return
	current_scene.launch("sandbox")
	for frame: int in range(8): await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://main.tscn" or not current_scene.microscenario_definition.is_empty() or not current_scene.pending_microscenario_apply.is_empty():
		push_error("Choosing ordinary sandbox reapplied a showcase argument")
		quit(1)
		return
	print("Direct feature argument and return regression passed")
	quit()
