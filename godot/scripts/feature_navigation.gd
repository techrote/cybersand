extends Node

func _input(event: InputEvent) -> void:
	if OS.has_feature("web") or bool(ProjectSettings.get_setting("cybersand/web_demo", false)): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		return_to_launcher()


func return_to_launcher() -> void:
	if OS.has_feature("web") or bool(ProjectSettings.get_setting("cybersand/web_demo", false)): return
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path != "res://feature_launcher.tscn":
		get_tree().remove_meta("cybersand_feature")
		get_tree().change_scene_to_file.call_deferred("res://feature_launcher.tscn")
