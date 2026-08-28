extends SceneTree

# Dependency/selection preflight. This does not claim that cellular coupling is
# correct; the existing three-body scene remains the behavioral migration fixture.
const ENGINE_SETTING: StringName = &"physics/2d/physics_engine"
const EXPECTED_ENGINE: String = "Rapier2D"
const EXPECTED_SERVER_CLASS: StringName = &"RapierPhysicsServer2D"
const EXPECTED_EXTENSION: String = (
	"res://addons/godot-rapier2d/godot-rapier2d.gdextension"
)

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ClassDB.class_exists(EXPECTED_SERVER_CLASS),
		"RapierPhysicsServer2D class is not registered"
	)
	_expect(
		FileAccess.file_exists(EXPECTED_EXTENSION),
		"pinned Rapier2D GDExtension is not vendored at the expected path"
	)
	_expect(
		str(ProjectSettings.get_setting(ENGINE_SETTING, "")) == EXPECTED_ENGINE,
		"physics/2d/physics_engine is not Rapier2D"
	)
	var version: Dictionary = Engine.get_version_info()
	_expect(
		int(version.get("major", 0)) == 4 and int(version.get("minor", 0)) == 7,
		"pinned migration expects Godot 4.7.x"
	)

	if _failures == 0:
		print("Rapier2D dependency and project selection preflight passed")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
