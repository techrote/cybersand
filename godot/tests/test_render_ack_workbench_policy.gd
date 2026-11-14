extends "res://tests/test_workbench_desktop_interest.gd"

# RENDER-ACK-002: reuse the existing real 2048² Main/Workbench/Rapier
# acceptance. Worker count and policy are fixed before Main._ready().
func _initialize() -> void:
	var worker_count: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--worker-count="):
			worker_count = int(argument.trim_prefix("--worker-count="))
	if worker_count not in [1, 4]:
		push_error("RENDER_ACK_WORKBENCH: invalid worker-count")
		quit(1)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", worker_count)
	print("RENDER_ACK_WORKBENCH: workers=", worker_count)
	super._initialize()
