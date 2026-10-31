extends Node

func _input(event: InputEvent) -> void:
	handle_navigation_input(event, get_viewport())


func handle_navigation_input(event: InputEvent, viewport: Viewport) -> void:
	if OS.has_feature("web") or bool(ProjectSettings.get_setting("cybersand/web_demo", false)): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		viewport.set_input_as_handled()
		return_to_launcher()


func return_to_launcher() -> void:
	if OS.has_feature("web") or bool(ProjectSettings.get_setting("cybersand/web_demo", false)): return
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene
	# A failed-session reload may have removed old Main but not yet entered
	# its replacement. Navigation must cancel that pending recovery as well.
	if (scene != null and scene.scene_file_path != "res://feature_launcher.tscn") \
		or tree.has_meta("cybersand_playable_recovery"):
		if scene != null and scene.has_method("cancel_playable_session_recovery"):
			scene.cancel_playable_session_recovery()
		if tree.has_meta("cybersand_playable_recovery"):
			tree.remove_meta("cybersand_playable_recovery")
		if tree.has_meta("cybersand_feature"): tree.remove_meta("cybersand_feature")
		tree.change_scene_to_file.call_deferred("res://feature_launcher.tscn")
