extends "res://tests/run_art_owner_evaluator.gd"
## Exercise the real optional evaluator through Godot's input event pipeline.
## Press and release occur within one frame; no handler or signal is fabricated.
var fixture_checks := 0
var fixture_failures: Array[String] = []
var routed_windows: Array[String] = []
var test_started := false


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	OS.set_environment("WB_ART_EVALUATOR_SMOKE_SECONDS","0")
	OS.set_environment("WB_ART_DIAGNOSTIC_PATH","user://art-evaluator-input-"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	super._initialize()
	_run_fixture.call_deferred()


func fixture_check(ok: bool, label: String) -> void:
	fixture_checks += 1
	print("ART_EVALUATOR_INPUT_CHECK ",label," ",ok)
	if not ok:
		fixture_failures.append(label)
		push_error(label)


func checkpoints() -> int:
	var count := 0
	for event: Dictionary in events:
		if event.event=="manual_checkpoint": count += 1
	return count


func short_tap(window: Window, label: String) -> void:
	var observed := {"presses":0,"releases":0}
	var observer := func(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode==KEY_F12:
			if event.pressed: observed.presses += 1
			else: observed.releases += 1
	window.window_input.connect(observer)
	window.grab_focus()
	for _index in range(3): await process_frame
	var before := checkpoints()
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.window_id = window.get_window_id()
		event.keycode = KEY_F12
		event.physical_keycode = KEY_F12
		event.ctrl_pressed = true
		event.pressed = pressed
		Input.parse_input_event(event)
	for _index in range(3): await process_frame
	window.window_input.disconnect(observer)
	fixture_check(observed.presses==1 and observed.releases==1,label+" receives the real same-frame key press and release")
	fixture_check(checkpoints()==before+1,label+" produces exactly one diagnostic checkpoint")
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path))
	fixture_check(report is Dictionary and report.events[-1].event=="manual_checkpoint",label+" saves the actual checkpoint report")
	if observed.presses==1 and observed.releases==1: routed_windows.append(label)


func _run_fixture() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while not is_instance_valid(panel) and Time.get_ticks_msec()<deadline: await process_frame
	fixture_check(is_instance_valid(panel),"real native evaluator Workbench becomes ready")
	if not is_instance_valid(panel):
		await _finish()
		return
	test_started = true
	panel.hide()
	for _index in range(3): await process_frame
	await short_tap(root,"root Workbench")
	panel.show()
	for _index in range(3): await process_frame
	await short_tap(panel,"Art window")
	panel._open_key_dialog()
	for _index in range(3): await process_frame
	await short_tap(panel.key_dialog,"Key child dialog")
	panel.key_dialog.hide()
	for _index in range(3): await process_frame
	panel._open_conversation()
	for _index in range(3): await process_frame
	await short_tap(panel.conversation_editor,"Conversation child dialog")
	panel.conversation_editor.hide()
	fixture_check(panel.provider.serial==0 and panel.provider.log_path.is_empty(),"input checks make no model request or session audit")
	fixture_check(root.title.contains("Timing saved"),"visible title acknowledges a saved checkpoint")
	await _finish()


func _finish() -> void:
	if finishing: return
	await super._finish()
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path))
	fixture_check(report is Dictionary and report.get("teardown_completed",false),"actual evaluator records completed teardown")
	if report is Dictionary:
		var kinds: Array = report.events.map(func(event: Dictionary) -> String: return str(event.event))
		fixture_check(kinds.has("before_teardown") and kinds.has("teardown_completed"),"before and after teardown evidence is preserved")
	fixture_check(test_started and routed_windows.size()==4,"root and both child dialog routes all executed")
	print("ART_EVALUATOR_INPUT_RESULT ",JSON.stringify({"checks":fixture_checks,"failures":fixture_failures,
		"routed_windows":routed_windows,"display":DisplayServer.get_name(),"embedded":root.gui_embed_subwindows,
		"interaction":"Input.parse_input_event; not physical keyboard acceptance","report":output_path}))
	quit(0 if fixture_failures.is_empty() else 1)
