extends SceneTree

const Controller = preload("res://scripts/main.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var value := int(OS.get_environment("CYBERSAND_OBSERVATION_VALUE"))
	var controller := Controller.new()
	controller.tower_floor = 2
	controller.tower_context = {"status":"Disposable Tower observation fixture", "fixture_value":value,
		"controls":[{"action":"step", "tick":12},{"action":"release", "tube":1, "tick":13}]}
	var returned: Variant = controller.call("tower_observation")
	var path := ProjectSettings.globalize_path("user://tower-observation.json")
	var bytes := FileAccess.get_file_as_bytes(path)
	var parser := JSON.new()
	var parsed: Variant = parser.data if parser.parse(bytes.get_string_from_utf8()) == OK else null
	print("TOWER_OBSERVATION_BEFORE ", JSON.stringify({"path":path,"requested_value":value,
		"returned_value":returned,"bytes":bytes.size(),"sha256":FileAccess.get_sha256(path),
		"json_loadable":parsed is Dictionary,"loaded_value":parsed.context.fixture_value if parsed is Dictionary else null,
		"clipboard_available":DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)}))
	controller.free()
	quit()
