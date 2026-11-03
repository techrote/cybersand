extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

# The shared MicroScenario panel also belongs to the existing synchronous
# controller. This is its ordinary Godot-scene button regression, not browser,
# Web export, rendering or PLAY promotion qualification.
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_INPUT011_LEGACY: " + message)


func run() -> void:
	var started: int = Time.get_ticks_usec()
	var controller: Control = load("res://web_main.tscn").instantiate()
	root.add_child(controller)
	await process_frame
	var acknowledged: int = Time.get_ticks_usec()
	expect(acknowledged-started <= Watchdogs.microseconds("main_ack_seconds"), "original scene startup stays within the Main acknowledgement watchdog")
	expect(controller.ready_to_play, "actual retained synchronous controller initializes")
	expect(not controller._playable_course_controls_active(),
		"legacy host remains outside the shared-course input route")
	var before: bool = controller.paused
	controller.microscenario_panel.pause_button.pressed.emit()
	expect(controller.paused != before, "same production button pauses the legacy host")
	controller.microscenario_panel.pause_button.pressed.emit()
	expect(controller.paused == before, "same production button resumes the legacy host")
	var close_started: int = Time.get_ticks_usec()
	controller.queue_free()
	await process_frame
	await process_frame
	var teardown: int = Time.get_ticks_usec()-close_started
	expect(not is_instance_valid(controller), "legacy scene actually retires")
	expect(teardown <= Watchdogs.microseconds("operation_seconds"), "legacy teardown stays within the operation watchdog")
	expect(Time.get_ticks_usec()-started <= Watchdogs.microseconds("complex_fixture_seconds"), "whole fixture stays within the fixture watchdog")
	print("PLAY_INPUT011_LEGACY: %d assertions; %d failures" % [assertions,failures])
	print("PLAY_INPUT011_LEGACY_RESULT ",JSON.stringify({"schema":"play-input011-legacy-v1",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"assertions":assertions,"failures":failures,"elapsed_usec":Time.get_ticks_usec()-started,
		"teardown_usec":teardown,"actual_browser_qualified":false,"rendered_pacing_measured":false}))
	quit(0 if failures == 0 else 1)
