extends SceneTree

# Run only after the pinned Rapier2D addon has been copied into res://addons.
# Keeping activation separate prevents project.godot from selecting a server
# that is not yet registered by its GDExtension.
const ENGINE_SETTING: StringName = &"physics/2d/physics_engine"
const EXPECTED_ENGINE: String = "Rapier2D"
const EXPECTED_SERVER_CLASS: StringName = &"RapierPhysicsServer2D"
const EXPECTED_GODOT_MAJOR: int = 4
const EXPECTED_GODOT_MINOR: int = 7


func _init() -> void:
	call_deferred("_activate")


func _activate() -> void:
	var version: Dictionary = Engine.get_version_info()
	if (
		int(version.get("major", 0)) != EXPECTED_GODOT_MAJOR
		or int(version.get("minor", 0)) != EXPECTED_GODOT_MINOR
	):
		_fail(
			"Rapier2D lock expects Godot %d.%d.x; found %s"
			% [EXPECTED_GODOT_MAJOR, EXPECTED_GODOT_MINOR, version.get("string", "unknown")]
		)
		return
	if not ClassDB.class_exists(EXPECTED_SERVER_CLASS):
		_fail(
			"RapierPhysicsServer2D is not registered; install and load the pinned addon first"
		)
		return

	ProjectSettings.set_setting(ENGINE_SETTING, EXPECTED_ENGINE)
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		_fail("Could not save Rapier2D project selection: error %d" % int(save_error))
		return

	print("Rapier2D selected. Restart Godot before running the backend preflight.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
