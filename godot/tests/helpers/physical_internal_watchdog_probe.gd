extends SceneTree

const Guard = preload("res://tests/helpers/physical_internal_watchdog.gd")
const Progress = preload("res://tests/helpers/physical_progress.gd")
var guard: Guard

func _init() -> void:
	if not Progress.begin("internal_watchdog_probe"):
		quit(2)
		return
	Progress.mark("probe_setup")
	if not Progress.finish():
		quit(2)
		return
	guard = Guard.new()
	var blocked: bool = "--blocked-main" in OS.get_cmdline_user_args()
	if guard.start("internal_watchdog_probe", 50 if blocked else 2000) != OK:
		quit(2)
		return
	guard.publish("probe_main_block")
	var started: int = Time.get_ticks_msec()
	# Deliberately no process_frame/timer yield: the independent thread must fire
	# while main is inside a blocking builtin call.
	OS.delay_msec(1000 if blocked else 10)
	print("INTERNAL_WATCHDOG_PROBE main_returned_ms=", Time.get_ticks_msec() - started)
	var passed: bool = guard.stop()
	print("INTERNAL_WATCHDOG_PROBE joined=", guard.joined(), " passed=", passed)
	quit(0 if passed else 1)
