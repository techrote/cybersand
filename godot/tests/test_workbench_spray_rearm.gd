extends SceneTree

# Impact spray requested while the running World lacks ballistic Water is
# refused natively. Once a rebuild installs ballistic Water, the panel must
# re-send the staged request so spray actually applies (no second toggle).
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var main: Control
var panel
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("WORKBENCH_SPRAY_REARM: " + label)
	return ok

func until(test: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while not test.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(test.call(), label + " / " + main.microscenario_error)

func installed() -> bool:
	return not panel.applied.is_empty() and not panel.busy() and main.pending_microscenario_apply.is_empty()

func spray() -> Dictionary:
	return main.tower_context.get("water_spray", {})

func run() -> void:
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	if not await until(installed, "workbench installed"): return finish()
	if not await until(func(): return not spray().is_empty(), "spray status published"): return finish()
	check(not spray().get("ballistic_enabled", true), "default World has no ballistic Water")
	check(panel.water_spray.request({"enabled": true}), "spray request queued")
	panel.toggle_pause()
	await until(func(): return str(spray().get("receipt", {}).get("refusal", "")).contains("ballistic"),
		"spray refused without ballistic Water")
	check(not bool(spray().get("settings", {}).get("enabled", true)), "refused spray stays off")
	panel.toggle_pause()
	if not await until(installed, "paused before rebuild"): return finish()
	main.workbench_water_options["workbench_ballistic"] = true
	check(panel.apply_liquids(), "rebuild with ballistic Water requested")
	if not await until(installed, "ballistic World installed"): return finish()
	panel.toggle_pause()
	await until(func(): return spray().get("ballistic_enabled", false) and bool(spray().get("settings", {}).get("enabled", false)),
		"staged spray applies after the ballistic rebuild")
	if not main.paused: panel.toggle_pause()
	finish()

func finish() -> void:
	print("WORKBENCH_SPRAY_REARM %d checks, %d failures" % [checks, failures])
	quit(failures)
