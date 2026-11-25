extends SceneTree

# Public controller/button calls with disposable user data. The Python runner
# supplies real OS failure boundaries; no production fault switches are used.
const Controller = preload("res://scripts/main.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var kind := OS.get_environment("CYBERSAND_OBSERVATION_KIND")
	var value := int(OS.get_environment("CYBERSAND_OBSERVATION_VALUE"))
	var through_button := OS.get_environment("CYBERSAND_OBSERVATION_BUTTON") == "1"
	var controller := Controller.new()
	controller.tower_floor = 2
	controller.tower_context = {"status":"Disposable Tower observation fixture", "fixture_value":value,
		"controls":[{"action":"step", "tick":12},{"action":"release", "tube":1, "tick":13}]}
	controller.microscenario_error = "Unrelated retained diagnostic"
	controller.water_policy_save_status = "Unrelated policy save result"
	if kind == "water-blind":
		var resolved := CyberWaterExperimentProfiles.resolve({}, {}, {"seed":value})
		var alternate := CyberWaterExperimentProfiles.resolve({}, {}, {"seed":value + 1})
		controller.water_blind_set = CyberWaterExperimentBlind.create([resolved, alternate], 42)
		if not resolved.get("ok", false) or not controller.water_blind_set.get("ok", false):
			push_error("TOWER_OBSERVATION_FIXTURE: could not construct valid Water metadata")
			controller.free()
			quit(2)
			return
		controller.tower_context.merge({"water_active":true, "water_policy":resolved.policy,
			"water_policy_hash":resolved.hash, "water_policy_provenance":resolved.provenance,
			"water_recipe_hash":"fixture-recipe-identity", "worker_count":1, "backend":"native-fixture",
			"water_actions":[{"action":"step", "tick":12}],
			"water_observations":[{"tick":12, "note":"Disposable engineering observation"}],
			"water_accounting":{"current":20, "explicit_source":0, "explicit_sink":0},
			"water_blind_label":"A"})
	elif kind != "ordinary":
		push_error("TOWER_OBSERVATION_FIXTURE: unknown context")
		controller.free()
		quit(2)
		return
	var context_before := JSON.stringify(controller.tower_context)
	var panel := CyberTowerPanel.new()
	controller.add_child(panel)
	panel.setup(controller)
	var clipboard_available := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	var old_clipboard := ""
	var sentinel := "Disposable Tower observation clipboard control"
	if clipboard_available:
		old_clipboard = DisplayServer.clipboard_get()
		DisplayServer.clipboard_set(sentinel)
	var returned: Variant = null
	if through_button:
		panel.observation_export_button.pressed.emit()
	else:
		returned = controller.tower_observation()
	var status: String = controller.tower_observation_status
	var acknowledged := status.begins_with("Observation exported to ")
	var path := ProjectSettings.globalize_path("user://tower-observation.json")
	var bytes := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var parser := JSON.new()
	var parsed: Variant = parser.data if parser.parse(bytes.get_string_from_utf8()) == OK else null
	var clipboard_matches := false
	if clipboard_available:
		clipboard_matches = DisplayServer.clipboard_get() == (bytes.get_string_from_utf8() if acknowledged else sentinel)
		DisplayServer.clipboard_set(old_clipboard)
	var keys: Array = parsed.keys() if parsed is Dictionary else []
	keys.sort()
	var blind: Dictionary = parsed.get("blind", {}) if parsed is Dictionary else {}
	print("TOWER_OBSERVATION_RESULT ", JSON.stringify({"kind":kind,"path":path,"requested_value":value,
		"through_button":through_button,"return_value":returned,"acknowledged":acknowledged,"status":status,
		"visible_status":panel.observation_export_status.text,"status_label_visible":panel.observation_export_status.visible,
		"json_loadable":parsed is Dictionary,"loaded_value":parsed.context.fixture_value if parsed is Dictionary else null,
		"report_keys":keys,"blind_mapping_size":blind.get("hidden_mapping", {}).size(),
		"reported_policy_seed":parsed.get("effective_policy", {}).get("seed", -1) if parsed is Dictionary else -1,
		"context_unchanged":JSON.stringify(controller.tower_context) == context_before,
		"unrelated_error":controller.microscenario_error,"unrelated_policy_status":controller.water_policy_save_status,
		"clipboard_available":clipboard_available,"clipboard_outcome_matches":clipboard_matches,
		"bytes":bytes.size(),"sha256":FileAccess.get_sha256(path) if not bytes.is_empty() else ""}))
	controller.free()
	quit()
