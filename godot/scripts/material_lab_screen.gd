extends Control

var _window: Window
var _previous_scale_mode: int = Window.CONTENT_SCALE_MODE_DISABLED

func _ready() -> void:
	_window = get_window()
	_previous_scale_mode = _window.content_scale_mode
	# The game scales a 1920x1080 canvas. Desktop authoring uses actual window
	# pixels so a 13px control remains readable at a smaller window size.
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var background := ColorRect.new()
	background.color = Color(0.025,0.035,0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,12)
	add_child(margin)
	var lab := preload("res://scripts/material_lab_panel.gd").new()
	lab.name = "MaterialsLabPanel"
	margin.add_child(lab)
	lab.close_requested.connect(func() -> void: get_tree().change_scene_to_file("res://feature_launcher.tscn"))

func _exit_tree() -> void:
	if is_instance_valid(_window): _window.content_scale_mode = _previous_scale_mode
