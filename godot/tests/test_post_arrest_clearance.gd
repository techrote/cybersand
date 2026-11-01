extends "res://tests/test_granular_bearing_candidates.gd"

# Observation duration only. Inherits the exact fixture and response owner.
func _capture_horizon() -> int:
	return 1800


func _run() -> void:
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
