extends SceneTree

# Issue #24 prerequisite: Space belongs to navigation, not a focused launcher.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var controller: Control = scene.instantiate()
	root.add_child(controller)
	await process_frame
	var launcher: Button
	for child: Node in controller.get_node("Layout").get_children():
		if child is Button and child.text == "Experiment Tower / F9":
			launcher = child
	var ok: bool = launcher != null and launcher.focus_mode == Control.FOCUS_NONE
	if launcher != null:
		launcher.pressed.emit()
		await process_frame
		ok = ok and controller.tower_active and not launcher.has_focus()
	controller.queue_free()
	await process_frame
	if not ok: push_error("Tower launcher retained keyboard focus or failed to launch")
	print("Tower launcher focus: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
