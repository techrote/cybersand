extends SceneTree

var failures: int = 0
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world unavailable")
	var scene: PackedScene = load("res://depth_lab.tscn")
	_expect(scene != null, "depth_lab.tscn did not load")
	if failures != 0:
		quit(failures)
		return
	var lab: Control = scene.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	_expect(not lab.faulted, "depth lab faulted on startup")
	_expect(lab.runtime.generation() == 1, "lab did not build its four worlds")
	for index: int in range(5):
		lab.select_mode(index)
		_expect(lab.mode_index == index, "mode selection failed for %d" % index)
	lab.toggle_pause()
	_expect(lab.paused, "pause control failed")
	var before: int = lab.runtime.layer_tick("play")
	lab.runtime.advance(1.0, lab.paused)
	_expect(lab.runtime.layer_tick("play") == before, "paused lab advanced play world")
	lab.runtime.step_once()
	_expect(lab.runtime.layer_tick("play") == before + 1, "single-step did not advance play world")
	lab.run_reactor_sequence()
	for _i: int in range(70):
		lab._advance_sequence(1.0 / 60.0)
	lab.runtime.advance(0.0, true)
	_expect(lab._sequence_phase == -1, "rear reactor sequence did not complete")
	var negative: Dictionary = lab.runtime.route_event("scripted", "play", "blast", Vector2i(366, 218), 8, 6, lab.runtime.generation())
	_expect(str(negative.get("error", "")) == "route_not_allowed", "lab reverse-route negative control failed")
	var generation_before: int = lab.runtime.generation()
	_expect(lab.reset_lab(), "lab reset failed")
	_expect(lab.runtime.generation() == generation_before + 1, "lab reset did not retire prior generation")
	_expect(lab.runtime.layer_tick("background") == 0, "far city became active after reset")
	if failures == 0:
		print("Depth lab integration regression passed; ", checks, " checks")
	lab.queue_free()
	await process_frame
	quit(failures)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error(message)
