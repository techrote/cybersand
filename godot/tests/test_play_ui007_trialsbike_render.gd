extends "res://tests/test_play_ui007_trialsbike.gd"

# The complete platform runner discovers *_render as graphical. Reuse the
# actual Main/native/Rapier lifetime and pointer assertions from the rig case.
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PLAY_UI007 graphical wrapper requires an actual display")
		quit(1)
		return
	super._initialize()
