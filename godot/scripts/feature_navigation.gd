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
	# The opt-in persistent-area host must publish its last authoritative state
	# before leaving. Its controller owns retry/cancel and performs the eventual
	# navigation itself. Ordinary scenes retain the existing immediate route.
	if scene != null and scene.has_method("request_persistent_exit"):
		scene.request_persistent_exit("launcher")
		return
	# A failed-session reload may have removed old Main but not yet entered
	# its replacement. Navigation must cancel that pending recovery as well.
	if (scene != null and scene.scene_file_path != "res://feature_launcher.tscn") \
		or tree.has_meta("cybersand_playable_recovery"):
		# An asynchronous owner must remain in the tree until its worker has
		# disposed native inventory and main has released its physics RIDs.
		# Other scenes retain their existing navigation path.
		if scene != null and scene.has_method("request_feature_launcher_navigation"):
			scene.request_feature_launcher_navigation()
			return
		_queue_return_to_launcher(tree, scene)


func complete_feature_launcher_navigation(expected_scene: Node) -> bool:
	if OS.has_feature("web") or bool(ProjectSettings.get_setting("cybersand/web_demo", false)):
		return false
	var tree: SceneTree = get_tree()
	# A late completion from a retired scene cannot replace its successor.
	if not is_instance_valid(expected_scene) or tree.current_scene != expected_scene:
		return false
	if not expected_scene.has_method("feature_launcher_navigation_ready") \
		or not expected_scene.feature_launcher_navigation_ready():
		return false
	_queue_return_to_launcher(tree, expected_scene, true)
	return true


func _queue_return_to_launcher(tree: SceneTree, scene: Node, fence_completion: bool = false) -> void:
	if scene != null and scene.has_method("cancel_playable_session_recovery"):
		scene.cancel_playable_session_recovery()
	if tree.has_meta("cybersand_playable_recovery"):
		tree.remove_meta("cybersand_playable_recovery")
	if tree.has_meta("cybersand_feature"): tree.remove_meta("cybersand_feature")
	if fence_completion:
		_finish_return_if_current.call_deferred(scene.get_instance_id() if scene != null else 0)
	else:
		# Preserve ordinary recovery/navigation ordering. The new current-scene
		# fence belongs only to the asynchronous owner's completion callback.
		tree.change_scene_to_file.call_deferred("res://feature_launcher.tscn")


func _finish_return_if_current(expected_scene_id: int) -> void:
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene
	var current_id: int = scene.get_instance_id() if scene != null else 0
	if current_id != expected_scene_id:
		return
	tree.change_scene_to_file("res://feature_launcher.tscn")
