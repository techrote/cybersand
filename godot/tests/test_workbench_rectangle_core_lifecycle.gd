extends "res://tests/test_workbench_cut_lifecycle.gd"

func _initialize() -> void:
	OS.set_environment("CYBERSAND_RECTANGLE_CORE_LIFECYCLE","1")
	super._initialize()
