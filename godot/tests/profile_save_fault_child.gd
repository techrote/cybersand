extends SceneTree

# Real public profile writers and their format readers. The runner gives every
# invocation disposable outputs and an isolated user profile. This headless
# caller test does not claim a rendered or browser workflow.
const Generation = preload("res://scripts/worldgen_workbench.gd")
const LabPanel = preload("res://scripts/material_lab_panel.gd")
const LabExperiment = preload("res://scripts/material_lab_experiment.gd")
const TransportPanel = preload("res://scripts/transport_profile_panel.gd")
const Controller = preload("res://scripts/main.gd")

class TransportHost extends Control:
	var applications := 0
	func material_name(id: int) -> String:
		return "Fixture material %d" % id
	func tower_apply_profile(_profile: Dictionary) -> void:
		applications += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var kind := OS.get_environment("CYBERSAND_PROFILE_KIND")
	var value := int(OS.get_environment("CYBERSAND_PROFILE_VALUE"))
	var invalid := OS.get_environment("CYBERSAND_PROFILE_INVALID") == "1"
	var path := OS.get_environment("CYBERSAND_PROFILE_PATH")
	var acknowledged := false
	var status := ""
	var details := {}
	match kind:
		"worldgen":
			var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../examples/worldgen/hilbert-seams.json"))
			recipe.seed = value
			var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
			var configured: Dictionary = generator.call(&"configure", recipe)
			if not configured.get("ok", false):
				push_error("PROFILE_FIXTURE: native generation configuration failed: " + str(configured))
				quit(2)
				return
			var app := Generation.new()
			app.active_recipe = generator.call(&"get_configuration")
			app.active_revision = -1 if invalid else int(configured.revision)
			app.profile_status = Label.new()
			app.status_label = Label.new()
			app.add_child(app.profile_status)
			app.add_child(app.status_label)
			app.last_error = "Profile save: previous refusal"
			var accepted_before := JSON.stringify(app.active_recipe)
			acknowledged = app.save_profile(path)
			status = app.profile_status.text if acknowledged else app.last_error
			details = {"accepted_recipe_unchanged":JSON.stringify(app.active_recipe) == accepted_before,
				"outer_status":app.status_label.text, "last_error":app.last_error}
			app.free()
		"material-lab":
			var panel := LabPanel.new()
			root.add_child(panel)
			if not invalid and not panel.experiment.start(LabExperiment.definition_for_pair(23,3,value,120)):
				push_error("PROFILE_FIXTURE: native experiment preparation failed: " + panel.experiment.last_error)
				panel.free()
				quit(2)
				return
			panel._file_action = "export_test"
			panel._file_selected(path)
			status = panel._status.text
			acknowledged = status.begins_with("Saved reproducible test case: ")
			details = {"experiment_active":panel.experiment.active(),
				"experiment_tick":panel.experiment.completed_tick() if panel.experiment.active() else -1}
			panel.free()
		"transport":
			path = ProjectSettings.globalize_path(CyberTransportProfiles.LOCAL_PATH)
			var host := TransportHost.new()
			var panel := TransportPanel.new()
			host.add_child(panel)
			panel.setup(host)
			var candidate := CyberTransportProfiles.preset(0)
			candidate.families.powder.mixing = value
			panel.editor.text = "{invalid" if invalid else JSON.stringify(candidate)
			var editor_before: String = panel.editor.text
			var draft_before := JSON.stringify(panel.draft)
			panel.save_copy()
			status = panel.status.text
			acknowledged = status.begins_with("User copy saved to ")
			details = {"editor_unchanged":panel.editor.text == editor_before,
				"draft_unchanged":JSON.stringify(panel.draft) == draft_before,
				"applications":host.applications,
				"draft_value":panel.draft.families.powder.mixing}
			host.free()
		"water":
			path = ProjectSettings.globalize_path("user://water-experiment-policy.json")
			var controller: Control = Controller.new()
			controller.water_policy_resolved = CyberWaterExperimentProfiles.resolve({}, {}, {"seed":value})
			controller.water_policy_available = true
			controller.water_active_blind_label = "A" if invalid else ""
			controller.microscenario_error = "Unrelated retained diagnostic"
			var panel := CyberTowerPanel.new()
			controller.add_child(panel)
			panel.setup(controller)
			panel.water_save_button.pressed.emit()
			status = controller.water_policy_save_status
			acknowledged = status.begins_with("Water policy saved to ")
			details = {"visible_status":panel.water_save_status.text,
				"status_label_visible":panel.water_save_status.visible,
				"unrelated_error":controller.microscenario_error,
				"resolved_seed":controller.water_policy_resolved.policy.seed}
			controller.free()
		_:
			push_error("PROFILE_FIXTURE: unsupported writer")
			quit(2)
			return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	var loadable := false
	var loaded_value: Variant = null
	match kind:
		"worldgen":
			var reader: Object = ClassDB.instantiate(&"CyberWorldGenerator")
			var checked: Dictionary = reader.call(&"configure", parsed) if parsed is Dictionary else {}
			loadable = checked.get("ok", false)
			if loadable: loaded_value = reader.call(&"get_configuration").seed
		"material-lab":
			var reader := LabExperiment.new()
			loadable = reader.start_case_json(text)
			if loadable: loaded_value = parsed.definition.seed
			reader.close()
		"transport":
			var checked := CyberTransportProfiles.parse(text)
			loadable = checked.get("ok", false)
			if loadable: loaded_value = checked.profile.families.powder.mixing
		"water":
			var checked := CyberWaterExperimentProfiles.parse_profile(text)
			loadable = checked.get("ok", false)
			if loadable: loaded_value = checked.values.seed
	print("PROFILE_SAVE_RESULT ", JSON.stringify({"kind":kind,"path":path,
		"requested_value":value,"invalid_input":invalid,"acknowledged":acknowledged,
		"status":status,"format_loadable":loadable,"loaded_value":loaded_value,
		"bytes":FileAccess.get_file_as_bytes(path).size(),"sha256":FileAccess.get_sha256(path),
		"details":details}))
	quit()
