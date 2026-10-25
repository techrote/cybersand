extends Control

const Trial = preload("res://scripts/physical_actor_trial.gd")

func _ready() -> void:
	# Keep existing direct-launch arguments compatible with the desktop wrapper.
	var first_launch: bool = not get_tree().has_meta("cybersand_launch_args_consumed")
	get_tree().set_meta("cybersand_launch_args_consumed", true)
	if first_launch and "--semantic-depth" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://semantic_depth.tscn")
		return
	if first_launch and "--flight-lab" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://flight_lab.tscn")
		return
	if first_launch and "--player-playground" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://player_playground.tscn")
		return
	if first_launch and "--deepworks" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://deepworks.tscn")
		return
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
	_label(column, "Choose a feature. F2 returns here; returning closes the current session. Showcase maps start paused. F5 selects 46 articulated Rapier actors or sampled references in the sandbox and showcase maps.", 18)
	_button(column, "Player playground — stunt buggy, trials bike, acrobat, spacecraft, material swarms and jet barrel", "player_playground")
	_button(column, "Deepworks — 1024 × 1024 multilayer material exhibition", "deepworks")
	_button(column, "Blacksite Nine — connected industrial complex", "blacksite")
	_button(column, "Neon Reliquary — four showcase districts", "showcase")
	_button(column, "Actor sandbox — 46 articulated Rapier rigs / F5", "actors")
	_button(column, "Materials sandbox / Experiment Tower — F9", "sandbox")
	_button(column, "Liquid comparison — solver policies and protected Dam Break", "liquid_comparison")
	_button(column, "Thunderbowl — actor control arena", "thunderbowl")
	_button(column, "Physical Thunderbowl — articulated actors, tools and scripted pilots", "physical_actors")
	_button(column, "Physical usable course — 32 tools, payloads and processors", "physical_usables")
	_button(column, "4LY Flight Lab — four physical drones, real native/Rapier navigation", "flight_lab")
	_button(column, "World generation workbench — terrain authoring preview", "worldgen")
	_button(column, "Semantic depth — refinery service gallery and flooded cavern", "semantic_depth")
	_button(column, "Strata Theatre — layering and parallax depth lab", "depth")
	_label(column, "BLACKSITE COMPARISONS / fresh reset for each arm", 22)
	_label(column, "Original single-hull Rapier barrel and Ripper reference trials: A/D drive, Q/E torque, Space short upward pulse. The articulated actor versions and scripted pilots are available through F5 and Physical Thunderbowl.", 17)
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
	if destination == "flight_lab": scene = "res://flight_lab.tscn"
	elif destination == "thunderbowl": scene = "res://examples/thunderbowl/thunderbowl.tscn"
	elif destination in ["physical_actors", "physical_usables"]: scene = "res://examples/thunderbowl/physical_thunderbowl.tscn"
	elif destination == "worldgen": scene = "res://worldgen_workbench.tscn"
	elif destination == "semantic_depth": scene = "res://semantic_depth.tscn"
	elif destination == "depth": scene = "res://depth_lab.tscn"
	elif destination == "deepworks": scene = "res://deepworks.tscn"
	elif destination == "player_playground": scene = "res://player_playground.tscn"
	get_tree().set_meta("cybersand_feature", destination)
	get_tree().change_scene_to_file(scene)
