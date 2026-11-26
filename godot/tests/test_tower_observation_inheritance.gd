extends SceneTree

const DesktopController = preload("res://scripts/main.gd")
const WebController = preload("res://scripts/web_demo_controller.gd")

# Only the observation hooks are substituted. The actual retained subclass,
# parent export, native file replacement and boolean result remain exercised.
# This headless desktop fixture does not execute a browser or a Water World.
class RefreshProbe extends "res://scripts/web_demo_controller.gd":
	var fixture_calls: Array[String] = []
	func _water_observe_web(_action: Dictionary = {}) -> Dictionary:
		fixture_calls.append("observe")
		return {"water_integer":37}
	func _update_water_web_context() -> void:
		fixture_calls.append("refresh")
		tower_context["fixture_refreshed"] = true

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		push_error("TOWER_INHERITANCE: " + message)
	return value

func finish() -> void:
	print("TOWER_INHERITANCE_RESULT ", JSON.stringify({"checks":checks,
		"failures":failures, "scope":"Desktop inheritance/return/order fixture; Water observation hooks substituted"}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	# The qualification runner provides a fresh isolated user profile. A direct
	# invocation refuses existing data before constructing or writing a report.
	var target := ProjectSettings.globalize_path("user://tower-observation.json")
	if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
		check(false, "requires a fresh user profile; existing observation target left untouched")
		finish()
		return
	var desktop_script: Script = DesktopController
	var retained_script: Script = WebController
	if not check(desktop_script.can_instantiate() and retained_script.can_instantiate(),
			"both controller scripts instantiate"):
		finish()
		return
	var controller := RefreshProbe.new()
	controller.tower_context = {"water_active":true, "fixture_value":7}
	var saved: Variant = controller.tower_observation()
	if not check(typeof(saved) == TYPE_BOOL and saved == true, "subclass returns parent commit success"):
		controller.free()
		finish()
		return
	check(controller.fixture_calls == ["observe", "refresh"], "observation refresh precedes export")
	check(controller.water_current_integer == 37, "observed Water quantity retained")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(target))
	check(parsed is Dictionary and bool(parsed.get("context", {}).get("fixture_refreshed", false)),
		"committed report includes refreshed context")
	if not check(DirAccess.remove_absolute(target) == OK, "remove only fixture-created report"):
		controller.free()
		finish()
		return
	if not check(DirAccess.make_dir_absolute(target) == OK, "create real target-directory collision"):
		controller.free()
		finish()
		return
	controller.fixture_calls.clear()
	var refused: Variant = controller.tower_observation()
	check(typeof(refused) == TYPE_BOOL and refused == false, "subclass returns parent commit refusal")
	check(DirAccess.dir_exists_absolute(target), "refusal preserves existing directory")
	check(controller.tower_observation_status.begins_with("Observation export refused"), "refusal status is truthful")
	check(controller.fixture_calls == ["observe", "refresh"], "refused export retains observation ordering")
	check(DirAccess.remove_absolute(target) == OK, "remove only fixture-created empty directory")
	controller.free()
	finish()
