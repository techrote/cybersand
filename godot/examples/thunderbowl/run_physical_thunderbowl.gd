extends SceneTree

# Offline reproducible-config exercise of the real native/Rapier environment.
# Optional action schedules are host-side policy producers using freshly issued
# observations. They do not claim to model network delay or LLM inference time.
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const MAX_INPUT_BYTES: int = 4194304
var _error: String = ""


func _init() -> void:
	call_deferred("_run")


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_INPUT_BYTES:
		_error = "Cannot read bounded JSON input: " + path
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_error = "Invalid JSON input: " + path
		return null
	return parser.data


func _options() -> Dictionary:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--help":
			print("Physical Thunderbowl v2: --rig=ripper --actors=4 --ticks=600 --seed=0 --output=result.json [--course=usables-v1]")
			print("Or --config=config.json [--ticks=N]. Optional --actions=actions.json accepts [{tick,actor_id,action,lease_ticks?}].")
			print("Actions require producer=policy for that actor. Engine and native state remain synchronous at 60 Hz; no competition score.")
			return {"help": true}
		var separator: int = argument.find("=")
		if not argument.begins_with("--") or separator < 3:
			_error = "Expected a named --option=value"
			return {}
		var key: String = argument.substr(2, separator - 2)
		if key not in ["rig", "actors", "ticks", "seed", "config", "actions", "output", "course"] or options.has(key):
			_error = "Unknown or repeated option: " + key
			return {}
		var value: String = argument.substr(separator + 1)
		if value.is_empty():
			_error = "Empty option: " + key
			return {}
		if key in ["actors", "ticks", "seed"]:
			if not value.is_valid_int():
				_error = "Expected integer option: " + key
				return {}
			options[key] = int(value)
		else:
			options[key] = value
	return options


func _schedule(value: Variant, config: Dictionary) -> Dictionary:
	if not value is Array or value.size() > Arena.MAX_TICKS * Session.MAX_ACTORS:
		_error = "Action schedule must be a bounded array"
		return {}
	var schedule: Dictionary = {}
	for record: Variant in value:
		if not record is Dictionary or record.size() < 3 or record.size() > 4:
			_error = "Action schedule record schema"
			return {}
		for key: Variant in record:
			if str(key) not in ["tick", "actor_id", "action", "lease_ticks"]:
				_error = "Unknown action schedule field"
				return {}
		if not Session._integer(record.get("tick"), 0, int(config.max_ticks) - 1) \
			or not Session._integer(record.get("actor_id"), 0, config.actors.size() - 1) \
			or not Session._integer(record.get("lease_ticks", 12), 1, Session.MAX_LEASE) \
			or Session.normalized_action(record.get("action")).is_empty():
			_error = "Invalid action schedule value"
			return {}
		var actor_id: int = int(record.actor_id)
		if str(config.actors[actor_id].producer) != "policy":
			_error = "Action schedule actor must be owned by a policy producer"
			return {}
		var tick: int = int(record.tick)
		var batch: Array = schedule.get(tick, [])
		for previous: Dictionary in batch:
			if int(previous.actor_id) == actor_id:
				_error = "Duplicate actor at an action schedule tick"
				return {}
		batch.append(record.duplicate(true))
		schedule[tick] = batch
	return schedule


func _finish(result: Dictionary, output: String, code: int) -> void:
	var serialized: String = JSON.stringify(Arena.json_value(result))
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write physical lab result: " + output)
			quit(2)
			return
		file.store_string(serialized + "\n")
	print(serialized)
	quit(code)


func _run() -> void:
	var options: Dictionary = _options()
	if options.has("help"):
		quit(0)
		return
	if not _error.is_empty():
		_finish({"version": 2, "failed": true, "reason": _error}, "", 2)
		return
	var config: Variant
	if options.has("config"):
		if options.has("rig") or options.has("actors") or options.has("seed") or options.has("course"):
			_finish({"version": 2, "failed": true, "reason": "Config already specifies actors and seed"}, str(options.get("output", "")), 2)
			return
		config = _load_json(str(options.config))
	else:
		var rig := StringName(str(options.get("rig", "ripper")))
		if not Catalog.has_rig(rig) or not Session._integer(options.get("actors", 4), 1, 8):
			_finish({"version": 2, "failed": true, "reason": "Unknown rig or invalid actor count"}, str(options.get("output", "")), 2)
			return
		if options.has("course") and str(options.course) != "usables-v1":
			_finish({"version": 2, "failed": true, "reason": "Unknown usable course"}, str(options.get("output", "")), 2)
			return
		config = Arena.usable_course_config(rig, int(options.get("actors", 4))) if options.has("course") else Arena.default_config(rig, int(options.get("actors", 4)))
		config.seed = options.get("seed", 0)
		config.max_ticks = 600
	if not config is Dictionary or not _error.is_empty():
		_finish({"version": 2, "failed": true, "reason": _error if not _error.is_empty() else "Config must be a dictionary"}, str(options.get("output", "")), 2)
		return
	if options.has("ticks"):
		config.max_ticks = options.ticks
	var arena := Arena.new()
	root.add_child(arena)
	if not arena.configure(config):
		_finish({"version": 2, "failed": true, "reason": arena.last_error}, str(options.get("output", "")), 2)
		arena.free()
		return
	var schedule: Dictionary = {}
	if options.has("actions"):
		var records: Variant = _load_json(str(options.actions))
		if _error.is_empty():
			schedule = _schedule(records, arena.config)
	if not _error.is_empty():
		_finish({"version": 2, "failed": true, "reason": _error}, str(options.get("output", "")), 2)
		arena.free()
		return
	var start_usec: int = Time.get_ticks_usec()
	var state: Dictionary = arena.snapshot()
	while not bool(state.finished):
		var commands: Array = []
		for record: Dictionary in schedule.get(int(state.tick), []):
			var view: Dictionary = arena.observation(int(record.actor_id))
			commands.append(Session.make_command(view, int(view.last_sequence) + 1,
				record.action, int(record.get("lease_ticks", 12))))
		state = arena.step(commands)
	state["config"] = arena.config.duplicate(true)
	state["runner"] = {"godot": Engine.get_version_info().string,
		"physics_engine": str(ProjectSettings.get_setting("physics/2d/physics_engine", "")),
		"elapsed_ms": float(Time.get_ticks_usec() - start_usec) / 1000.0,
		"policy_schedule": "fresh issued observations at listed ticks; no inference or transport delay",
		"reproducibility": "fixed config, layout seed and tick budget; cross-platform bit identity is not promised"}
	var exit_code: int = 1 if bool(state.failed) else 0
	arena.close()
	arena.free()
	_finish(state, str(options.get("output", "")), exit_code)
