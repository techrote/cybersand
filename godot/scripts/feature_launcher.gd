extends Control

const Trial = preload("res://scripts/physical_actor_trial.gd")

func _ready() -> void:
	# Keep existing direct-launch arguments compatible with the desktop wrapper.
	var first_launch: bool = not get_tree().has_meta("cybersand_launch_args_consumed")
	get_tree().set_meta("cybersand_launch_args_consumed", true)
	if first_launch and "--depth-lab" in OS.get_cmdline_user_args():
		get_tree().set_meta("cybersand_depth_lab_visited", true)
		get_tree().change_scene_to_file.call_deferred("res://depth_lab.tscn")
		return
	if first_launch and ("--blacksite-nine" in OS.get_cmdline_user_args() or "--showcase" in OS.get_cmdline_user_args()):
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")
		return
	var background := ColorRect.new()
	background.color = Color(0.025, 0.035, 0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 48
	scroll.offset_top = 32
	scroll.offset_right = -48
	scroll.offset_bottom = -32
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_label(column, "CYBERSAND / PLAY & EXPERIMENT", 30)
	_label(column, "Choose a feature. F2 returns here; returning closes the current session. Showcase maps start paused. F5 selects Sampled rigs or Rapier barrel/Ripper in the sandbox and showcase maps.", 18)
	_button(column, "Blacksite Nine — connected industrial complex", "blacksite")
	_button(column, "Neon Reliquary — four showcase districts", "showcase")
	_button(column, "Actor sandbox — F5 selects sampled rigs or physical Rapier bodies", "actors")
	_button(column, "Materials sandbox / Experiment Tower — F9", "sandbox")
	_button(column, "Thunderbowl — actor control arena", "thunderbowl")
	_button(column, "World generation workbench — terrain authoring preview", "worldgen")
	_button(column, "Strata Theatre — layering and parallax depth lab", "depth")
	_label(column, "BLACKSITE COMPARISONS / fresh reset for each arm", 22)
	_label(column, "Real Rapier barrel and low rectangular Ripper: A/D drive, Q/E torque, Space short upward pulse.\nRipper is an initial single-body trial; articulated tracks, tools and granular tuning remain follow-up work.", 17)
	for arm: String in Trial.ARMS:
		_button(column, "Blacksite / " + arm, Trial.PREFIX + arm)

func _label(parent: Node, text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func _button(parent: Node, text: String, destination: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(func() -> void: launch(destination))
	parent.add_child(button)

func launch(destination: String) -> void:
	var scene: String = "res://main.tscn"
	if destination == "thunderbowl": scene = "res://examples/thunderbowl/thunderbowl.tscn"
	elif destination == "worldgen": scene = "res://worldgen_workbench.tscn"
	elif destination == "depth": scene = "res://depth_lab.tscn"
	get_tree().set_meta("cybersand_feature", destination)
	get_tree().change_scene_to_file(scene)
