extends Control

func _ready() -> void:
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
