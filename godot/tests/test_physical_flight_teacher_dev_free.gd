extends SceneTree

# GitHub-hosted real-native/Rapier DEVELOPMENT exploration. The 4LY-003 sealed
# final split is never opened by this wildcard test. Teacher failures are
# retained as data; authority, missing evidence and physical faults are errors.
const Score = preload("res://scripts/physical_flight_development_scoring.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = Score.run(root, "free")
	var summary: Dictionary = result.get("summary", {})
	var compact: Dictionary = {
		"group": "free", "ok": bool(result.get("ok", false)),
		"episodes": summary.get("episodes", -1),
		"physical_ticks": summary.get("physical_ticks", -1),
		"navigation_successes": summary.get("navigation_successes", -1),
		"physics_failures": summary.get("physics_failures", -1),
		"family_counts": summary.get("family_counts", {}),
		"individual_results": summary.get("results", []),
		"errors": result.get("errors", []),
		"evidence_directory": result.get("evidence_directory", ""),
		"summary_sha256": result.get("summary_sha256", ""),
		"developer_split_only": true,
		"elapsed_wall_seconds": float(Time.get_ticks_usec() - started) / 1000000.0
	}
	print("4LY003_DEVELOPMENT_SCORE ", JSON.stringify(compact))
	quit(0 if bool(result.get("ok", false)) else 1)
