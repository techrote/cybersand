extends SceneTree

# Disposable-profile caller test. Invoke the real controller writer without
# constructing a live scene, Rapier owner or graphical session.
const Controller = preload("res://scripts/main.gd")

class CaptureSpy extends CyberMicroScenarioWorkbench:
	var acknowledgements := 0
	func accept_capture(report: Dictionary) -> void:
		acknowledgements += 1
		retained_capture = report.duplicate(true)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var controller: Control = Controller.new()
	controller.microscenario_error = OS.get_environment("CYBERSAND_CAPTURE_INITIAL_ERROR")
	var panel := CyberMicroScenarioPanel.new()
	var acknowledgement := CaptureSpy.new()
	acknowledgement.retained_capture = {"value":"previously acknowledged"}
	panel.workbench = acknowledgement
	panel.add_child(acknowledgement)
	controller.microscenario_panel = panel
	controller.add_child(panel)
	var value := OS.get_environment("CYBERSAND_CAPTURE_VALUE")
	var report := {"format":"microscenario-capture-fixture", "value":value,
		"payload":"Complete capture bytes. ".repeat(32)}
	controller._write_microscenario_capture(report)
	print("MICROSCENARIO_CAPTURE_RESULT ", JSON.stringify({
		"error":controller.microscenario_error,
		"acknowledgements":acknowledgement.acknowledgements,
		"acknowledged_value":acknowledgement.retained_capture.get("value"),
		"path":ProjectSettings.globalize_path("user://microscenario-observation.json")}))
	controller.free()
	quit()
