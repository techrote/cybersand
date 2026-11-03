extends Node

# Event bridge only: the existing desktop host still owns sampling, focus,
# neutral rearm, equipment, producer/epoch admission and the bounded edge FIFO.
# Polling alone loses a gamepad press+release between two physical callbacks.
# No native World, Rapier step, actor reference or replacement queue lives here.
const ACTION_BUTTONS: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]
var _selected_device: int = -1


func _ready() -> void:
	_selected_device = _selected_joypad()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _on_joy_connection_changed(device: int, _connected: bool) -> void:
	var selected: int = _selected_joypad()
	var changed: bool = selected != _selected_device or device == _selected_device
	_selected_device = selected
	var host: Node = get_parent()
	if changed and _gamepad_active(host) and host.has_method("cancel_playable_course_input"):
		# A disconnected pad can leave queued button edges or a held command.
		# Revoke through the original owner, including pending native effects;
		# the newly selected pad/keyboard must be neutral before rearming.
		host.call("cancel_playable_course_input")


func _gamepad_active(host: Node) -> bool:
	if host == null or not host.has_method("_playable_course_controls_active"):
		return false
	if host.has_method("_playable_course_gamepad_active"):
		return bool(host.call("_playable_course_gamepad_active"))
	return bool(host.call("_playable_course_controls_active"))


func _selected_joypad() -> int:
	# Match CyberPlayerPlaygroundInput.sample(): only the first connected pad
	# controls this single-player course. Never mix another device's edges in.
	var pads: Array[int] = Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton:
		return
	if event.device != _selected_joypad():
		return
	var host: Node = get_parent()
	if not _gamepad_active(host):
		return
	if event.button_index == JOY_BUTTON_START:
		if event.pressed and host.has_method("toggle_playable_course_pause"):
			host.call("toggle_playable_course_pause")
		get_viewport().set_input_as_handled()
		return
	if event.button_index not in ACTION_BUTTONS:
		return
	# Let Controls handle events first. Both edges which reach gameplay take the
	# SAME production publisher as keyboard events; its normal refusal/rearm
	# path remains authoritative while paused, unfocused, resetting or faulted.
	host.call("publish_actor_keyboard_input")
	get_viewport().set_input_as_handled()
