extends SceneTree

# Godot --headless --path godot --script res://examples/thunderbowl/run_thunderbowl.gd --
#   --match=res://examples/thunderbowl/matches/mixed.json --ticks=600 --output=/tmp/match.json
# Optional external mock/model adapter: --smart-dir=/tmp/link --realtime
const Contract = preload("res://scripts/thunderbowl_contract.gd")
const Driver = preload("res://examples/thunderbowl/thunderbowl_driver.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = {"match": "res://examples/thunderbowl/matches/mixed.json",
		"ticks": "", "seed": "", "output": "user://thunderbowl-result.json", "smart-dir": ""}
	var realtime: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--realtime":
			realtime = true
			continue
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or pair.size() != 2 or not options.has(pair[0]):
			_fail("Use --match=JSON --ticks=1..36000 --seed=INT --output=JSON [--smart-dir=DIR --realtime]")
			return
		options[pair[0]] = pair[1]
	var config: Dictionary = Contract.load_json(options.match)
	for key: String in ["ticks", "seed"]:
		if str(options[key]).is_empty():
			continue
		if not str(options[key]).is_valid_int():
			_fail("Invalid integer option: " + key)
			return
		config["max_ticks" if key == "ticks" else "seed"] = int(options[key])
	if not str(options["smart-dir"]).is_empty() and not DirAccess.dir_exists_absolute(options["smart-dir"]):
		_fail("Smart-link directory must already exist")
		return
	var driver := Driver.new()
	driver.smart_directory = options["smart-dir"]
	if not driver.configure(config):
		_fail(driver.last_error)
		return
	var start: int = Time.get_ticks_usec()
	var next_tick: int = start
	var report: Dictionary = driver.snapshot()
	while not report.finished:
		report = driver.step()
		if realtime:
			next_tick += 16667
			var remaining: int = next_tick - Time.get_ticks_usec()
			if remaining > 0:
				OS.delay_usec(remaining)
	var elapsed: int = Time.get_ticks_usec() - start
	report["runner"] = {"match": options.match, "config": config, "requested_ticks": config.max_ticks,
		"elapsed_usec": elapsed, "realtime": realtime, "smart_link": driver.smart_statistics(),
		"controller_rejections": driver.controller_rejections,
		"controller_rejection_reasons": driver.controller_rejection_reasons.duplicate(),
		"adapter_error": driver.last_error, "godot_version": Engine.get_version_info().string,
		"scope": "real native workers=1; current rigs, 10 Hz scripted decisions, 60 Hz motors/materials; virtual tags; no render or interactive hardware acceptance",
		"timing_scope": "driver loop with observations/controllers/native/snapshots and optional external file I/O; setup/final JSON excluded"}
	if not Driver.write_json(options.output, report):
		driver.close()
		_fail("Cannot write result; the output parent directory must exist")
		return
	print("THUNDERBOWL_RESULT ", options.output, " / tick=", report.tick, " / reason=", report.reason,
		" / hp=", report.hp, " / rewards=", report.rewards, " / elapsed_usec=", elapsed)
	driver.close()
	quit(1 if report.failed else 0)


func _fail(message: String) -> void:
	printerr("THUNDERBOWL_ERROR: ", message)
	quit(2)
