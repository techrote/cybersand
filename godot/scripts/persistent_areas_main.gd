extends "res://scripts/main.gd"

# Opt-in host: the ordinary Main scene and worker remain the gameplay owner.
const PersistentController = preload("res://scripts/persistent_areas_controller.gd")
var persistent_areas: Node
var _persistent_auto_accept_quit := true


func _ready() -> void:
	_persistent_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_tree().set_meta("cybersand_feature","shared_workbench")
	# This profile explicitly selects the CYPS-supported Current/FreeMass
	# domain. The ordinary Workbench's accepted gameplay Water defaults stay
	# unchanged in its own scene and launch path.
	workbench_water_options = {"workbench_wave_flow":false,"workbench_ballistic":false,
		"workbench_face_release":false,"workbench_inertial_signed":false,
		"workbench_wave_spill":false,"workbench_wave_spill_parcels":false,
		"workbench_wave_spill_full_face":false}
	paused = true
	super._ready()
	get_tree().set_meta("cybersand_feature","persistent_areas")
	persistent_areas = PersistentController.new()
	add_child(persistent_areas)
	persistent_areas.setup(self)


func persistent_bootstrap_pending() -> bool:
	return persistent_areas == null or not persistent_areas.active_ready


func persistent_operation_allowed(action: String, payload: Dictionary = {}) -> String:
	if persistent_areas == null: return "The persistent-area controller is opening its isolated profile."
	return persistent_areas.operation_allowed(action,payload)


func request_persistent_exit(destination: String = "launcher") -> bool:
	if persistent_areas == null: return false
	return persistent_areas.request_exit(destination)


func finish_persistent_exit(destination: String) -> void:
	if destination == "quit":
		get_tree().quit()
		return
	if get_tree().has_meta("cybersand_feature"): get_tree().remove_meta("cybersand_feature")
	get_tree().change_scene_to_file.call_deferred("res://feature_launcher.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and persistent_areas != null:
		request_persistent_exit("quit")
	super._notification(what)


func _exit_tree() -> void:
	get_tree().auto_accept_quit = _persistent_auto_accept_quit
	super._exit_tree()
