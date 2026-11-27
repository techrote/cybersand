extends SceneTree

## Actual graphical developer-scene controls and framebuffer capture. This is
## explicitly invoked by the isolated goblin launcher, not ordinary startup.
const Controller = preload("res://goblin/goblin_controller.gd")
var ui: Node
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_INTERACTIVE " + label)
	return ok


func until(predicate: Callable, limit_msec: int = 90000) -> bool:
	var deadline: int = Time.get_ticks_msec() + limit_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false


func run() -> void:
	if not check(DisplayServer.get_name() != "headless", "requires an actual graphical display"):
		quit(1)
		return
	if not check(Controller.read_launch().get("ok", false), "dedicated profile before any game mount"):
		quit(1)
		return
	# Use the application's ordinary 16:9 aspect and explicitly match the
	# canvas size; changing only the OS window leaves the project scale active.
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	ui = load("res://goblin/goblin.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	check(ui.start_button != null and not ui.start_button.disabled, "opt-in Start is visible and usable")
	check(ui.controller.adapter == null, "normal Workbench is not mounted until Start")
	check(ui.tab_container.get_tab_count() == 4, "Play, Discovery, Memory and Guide tabs are present")
	check(ui.personality.item_count == 16 and ui.fixture.item_count == 10, "actual personality and native scenario catalogues are available")
	check(int(ui.action_budget.max_value) == 1024, "long-horizon action budget is selectable")
	ui.fixture.select(2)
	ui.personality.select(2)
	ui.seed_value.value = -13
	ui.action_budget.value = 24
	ui.pacing.value = 80
	ui.start_button.pressed.emit()
	if not check(await until(func() -> bool: return ui.controller.attempted >= 6 or not ui.controller.running), "real Start dispatches bounded operations"):
		await finish()
		return
	if not check(ui.controller.adapter != null and ui.controller.adapter.mounted, "real ordinary Workbench mounted"):
		await finish()
		return
	check(ui.start_button.disabled and not ui.stop_button.disabled, "controls follow running state")
	ui.pause_button.pressed.emit()
	await until(func() -> bool: return not ui.controller.adapter.executing)
	var paused_count: int = ui.controller.attempted
	for _index: int in range(8): await process_frame
	check(ui.controller.decisions_paused and ui.controller.attempted == paused_count, "Pause holds decisions after the current action")
	check(ui.pause_button.text == "Resume", "Pause button reflects actual controller state")
	ui.step_button.pressed.emit()
	check(await until(func() -> bool: return ui.controller.attempted >= paused_count + 1 or not ui.controller.running), "Step dispatches one bounded game action")
	for _index: int in range(8): await process_frame
	check(ui.controller.decisions_paused and ui.controller.attempted == paused_count + 1, "Step returns to the decision pause after exactly one action")
	ui.pause_button.pressed.emit()
	check(await until(func() -> bool: return not ui.controller.running), "graphical campaign reaches a terminal result")
	var tape: Dictionary = ui.controller.transcript
	check(tape.get("summary", {}).get("termination") == "budget_complete", "graphical BUILDER completes its budget")
	check(tape.get("summary", {}).get("failures", ["missing"]).is_empty(), "graphical native observations pass independent checks")
	check(not ui.controller.export_path.is_empty() and FileAccess.file_exists(ui.controller.export_path), "fixed transcript export exists")
	check(not ui.replay_button.disabled and ui.last_tape.steps.size() == 24, "previous transcript available for replay")
	check(ui.goal_label.text.contains(str(ui.controller.completed)), "summary displays actual completed operations")
	check(root.get_visible_rect().encloses(ui.panel.get_global_rect()), "developer panel remains wholly inside the actual viewport")
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	check(not picture.is_empty() and picture.get_width() == 1600 and picture.get_height() == 900, "actual viewport framebuffer has expected dimensions")
	var colors := {}
	for y: int in range(20, picture.get_height(), 23):
		for x: int in range(20, picture.get_width(), 23): colors[picture.get_pixel(x, y).to_html()] = true
	check(colors.size() >= 12, "framebuffer contains rendered game and developer controls")
	DirAccess.make_dir_recursive_absolute("user://goblin")
	check(picture.save_png("user://goblin/interactive.png") == OK, "actual graphical capture saved")
	check(not ui.controller.discovery_summary().coverage.get("unique", {}).is_empty(), "Discovery displays actual admitted coverage")
	check(ui.controller.corpus.summary().get("records", 0) > 0, "native campaign retains experimental memory")
	for tab_index: int in [1, 2]:
		ui.tab_container.current_tab = tab_index
		await process_frame
		await RenderingServer.frame_post_draw
		var tab_picture: Image = root.get_texture().get_image()
		var filename: String = "discovery" if tab_index == 1 else "memory"
		check(tab_picture.save_png("user://goblin/interactive-" + filename + ".png") == OK, filename + " tab framebuffer retained")
		check(root.get_visible_rect().encloses(ui.panel.get_global_rect()), filename + " panel stays inside the viewport")
	ui.tab_container.current_tab = 0
	ui.replay_button.pressed.emit()
	check(ui.controller.running, "Replay accepts the in-memory transcript and current exact source identity")
	check(await until(func() -> bool: return not ui.controller.running), "Replay button reaches a terminal result")
	check(ui.controller.transcript.get("header", {}).get("replay", false), "Replay button dispatches the recorded sequence")
	check(ui.controller.state == "finished" and not ui.controller.export_path.is_empty() \
		and ui.controller.transcript.get("summary", {}).get("termination") == "budget_complete", "interactive replay retains its complete terminal evidence")
	check(ui.controller.replay_result.get("semantic_match", false), "interactive recorded sequence agrees semantically")
	check(FileAccess.file_exists("user://goblin/run-002.json"), "interactive replay retains a separate run archive")
	var capture := {"evidence_kind": "graphical_godot", "display": DisplayServer.get_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"size": [picture.get_width(), picture.get_height()], "colors_sampled": colors.size(),
		"source": tape.header.provenance, "summary": tape.summary, "replay_result": ui.controller.replay_result,
		"ui_state": ui.state_label.text, "ui_goal": ui.goal_label.text,
		"panel_rect": [ui.panel.position.x, ui.panel.position.y, ui.panel.size.x, ui.panel.size.y],
		"checks": checks, "failures": failures,
		"physical_owner_acceptance": false}
	var file := FileAccess.open("user://goblin/interactive-result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(capture, "\t", true) + "\n")
		file.close()
	await finish()


func finish() -> void:
	if ui != null:
		await ui.controller.close()
		ui.queue_free()
		await process_frame
	print("GOBLIN_INTERACTIVE_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "evidence_kind": "graphical_godot"}))
	quit(0 if failures.is_empty() else 1)
