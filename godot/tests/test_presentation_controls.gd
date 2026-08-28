extends SceneTree

# Focused scene-level check for presentation controls that must not touch the
# simulation/render payload contract.

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://main.tscn") as PackedScene
	var main: Control = packed_scene.instantiate() as Control
	get_root().add_child(main)
	await process_frame

	var status: Label = main.get_node("Layout/Status") as Label
	_expect(status.visible, "debug stats did not start visible")
	var toggle: InputEventKey = InputEventKey.new()
	toggle.keycode = KEY_F3
	toggle.pressed = true
	main._unhandled_key_input(toggle)
	_expect(not status.visible, "F3 did not hide the debug stats readout")
	main._unhandled_key_input(toggle)
	_expect(status.visible, "F3 did not restore the debug stats readout")

	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920 and
			int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080 and
			int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1920 and
			int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 1080,
		"project output settings are not 1920x1080"
	)

	main.queue_free()
	await process_frame
	if _failures == 0:
		print("Presentation controls regression passed; F3 stats and 1920x1080")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
