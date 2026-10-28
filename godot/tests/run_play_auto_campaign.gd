extends SceneTree

# One fresh reference World per process. The Python campaign owns repeat/order,
# source/runtime identity, process timeout, raw log retention and parity checks.
# This is the existing native benchmark apparatus, not a gameplay scheduler.
var options: Dictionary = {"workers": 0, "side": 480, "ticks": 120, "warmup": 60,
	"repeat": 0, "order": 0}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not options.has(parts[0]) or not parts[1].is_valid_int():
			push_error("PLAY_AUTO_CAMPAIGN: invalid argument " + argument)
			quit(1)
			return
		options[parts[0]] = int(parts[1])
	if int(options.repeat) < 0 or int(options.order) < 0:
		push_error("PLAY_AUTO_CAMPAIGN: invalid repeat/order identity")
		quit(1)
		return
	var result: Dictionary = await CyberWorkerBenchmark.sample(self,
		int(options.workers), int(options.side), int(options.ticks),
		func(_message: String) -> void: pass, func() -> bool: return false,
		int(options.warmup), true)
	print("PLAY_AUTO_CAMPAIGN_ROW ", JSON.stringify({
		"schema": "play-auto-campaign-row-v1",
		"repeat": int(options.repeat), "order": int(options.order),
		"side": int(options.side), "requested_workers": int(options.workers),
		"cpu_name": OS.get_processor_name(),
		"logical_processors": OS.get_processor_count(),
		"os": OS.get_name(), "os_version": OS.get_version(),
		"godot": Engine.get_version_info(),
		"result": result,
		"rendered_gameplay_fps_measured": false,
		"concurrent_execution_measured": false,
		"worker_creation_count_measured": false
	}))
	quit(0 if bool(result.get("ok", false)) else 1)
