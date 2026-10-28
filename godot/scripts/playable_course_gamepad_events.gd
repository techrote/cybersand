extends Node

# Event bridge only: the existing desktop host still owns sampling, focus,
# neutral rearm, equipment, producer/epoch admission and the bounded edge FIFO.
# Polling alone loses a gamepad press+release between two physical callbacks.
# No native World, Rapier step, actor reference or replacement queue lives here.
const ACTION_BUTTONS: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]


func _selected_joypad() -> int:
	# Match CyberPlayerPlaygroundInput.sample(): only the first connected pad
	# controls this single-player course. Never mix another device's edges in.
	var pads: Array[int] = Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton or event.button_index not in ACTION_BUTTONS:
		return
	if event.device != _selected_joypad():
		return
	var host: Node = get_parent()
	if host == null or not host.has_method("_playable_course_controls_active") \
		or not bool(host.call("_playable_course_controls_active")):
		return
	# Let Controls handle events first. Both edges which reach gameplay take the
	# SAME production publisher as keyboard events; its normal refusal/rearm
	# path remains authoritative while paused, unfocused, resetting or faulted.
	host.call("publish_actor_keyboard_input")
	get_viewport().set_input_as_handled()
