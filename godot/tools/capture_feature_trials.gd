extends SceneTree

var output: String = ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("A rendering display and --output directory are required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	change_scene_to_file("res://feature_launcher.tscn")
	await process_frame
	await capture("launcher")
	for arm: String in ["barrel", "ripper"]:
		set_meta("cybersand_feature", "experimental/blacksite/" + arm)
		change_scene_to_file("res://main.tscn")
		await process_frame
		while current_scene == null: await process_frame
		var desktop: Control = current_scene
		var deadline: int = Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			if desktop.physical_trial_arm == arm and desktop.pending_microscenario_apply.is_empty(): break
		if desktop.physical_trial_arm != arm:
			push_error("Trial failed to install: " + arm)
			quit(1)
			return
		desktop.blacksite_nine_presentation.follow_player()
		await capture("blacksite-" + arm)
	print("Rendered launcher and physical trial captures: " + output)
	quit()
