extends "res://tests/test_granular_bearing_candidates.gd"

# Observation duration only. Inherits the exact fixture and response owner.
func _capture_horizon() -> int:
	return 1800


func _run() -> void:
	# Ordinary test discovery supplies no acquisition arguments. Exercise only
	# copied boundary controls in that entry point; never launch an unregistered arm.
	if _argument("--mode=") == "controls" or (_argument("--mode=").is_empty() and _argument("--candidate=").is_empty()):
		_watchdog = WATCHDOG.new()
		_check(_watchdog.start("post-arrest-controls",120000) == OK,"watchdog")
		_check(_capture_horizon() == 1800,"fixed observation bound")
		await _bearing_controls()
		_check(_watchdog.stop(),"watchdog stop")
		print("POST_ARREST_CONTROLS ",JSON.stringify({"ok":not _failed,"horizon":1800}))
		quit(1 if _failed else 0)
		return
	if _argument("--mode=") != "replay":
		if not _argument("--arm=") in ["speed30","speed90"] or not _argument("--candidate=") in ["B0","Y1"]:
			push_error("Only preregistered B0/Y1 speed30/speed90 observations admitted")
			quit(1)
			return
		if _argument("--details=") != "on":
			push_error("Complete detailed observations required")
			quit(1)
			return
	await super._run()
