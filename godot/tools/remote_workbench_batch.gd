extends SceneTree
## REMOTE-WB-001: file/JSONL transport over the EXISTING #526/#527 native owner.
## No key, socket, shell, duplicate World, direct native mutation or model policy.
const Bridge = preload("res://scripts/workbench_agent_four_tool_bridge.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const PROTOCOL_VERSION: int = 1
const MAX_COMMANDS: int = 96
const MAX_INPUT_BYTES: int = 262144
const MAX_TOTAL_TICKS: int = 480
const MAX_PNG_BYTES: int = 8388608
const LIVE_DEADLINE_MSEC: int = 1800000

var _main: Control
var _workbench: Control
var _bridge: RefCounted
var _output: String = ""
var _authority_path: String = ""
var _commands_path: String = ""
var _mode: String = "batch"
var _authority: Dictionary = {}
var _manifest: Dictionary = {}
var _results: FileAccess
var _last_observation: String = ""
var _last_proposal: String = ""
var _last_png: PackedByteArray = PackedByteArray()
var _stopped: bool = false
var _authorized: bool = false
var _failures: Array = []
var _count: int = 0
var _total_ticks: int = 0
var _previous_seq: int = 0
var _consumed_input: String = ""
var _start_msec: int = 0


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()


func _fail(reason: String) -> void:
	_failures.append(reason)
	push_error("REMOTE_WB: " + reason)


func _cli() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--authorization="):
			_authority_path = arg.trim_prefix("--authorization=")
		elif arg.begins_with("--commands="):
			_commands_path = arg.trim_prefix("--commands=")
		elif arg.begins_with("--output="):
			_output = arg.trim_prefix("--output=")
		elif arg == "--live":
			_mode = "live"
		else:
			_fail("unknown_command_line_option")
			return false
	if _authority_path.is_empty() or _commands_path.is_empty() or _output.is_empty():
		_fail("required_authorization_commands_output")
		return false
	if not _authority_path.is_absolute_path() or not _commands_path.is_absolute_path() 			or not _output.is_absolute_path():
		_fail("all_paths_must_be_absolute")
		return false
	return true


## Godot's JSON parser reports JSON numeric literals as float, including 1,
## 512 and 58. Convert ONLY exactly integral, 32-bit-bounded values to native
## int before checking the schema or calling the actual worker. Fractional,
## nonfinite, out-of-range and boolean values never become native integers.
static func _canonical_json(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number >= -2147483648.0 and number <= 2147483647.0 \
				and floorf(number) == number:
			return int(number)
		return value
	if value is Array:
		var mapped: Array = []
		for item: Variant in value:
			mapped.append(_canonical_json(item))
		return mapped
	if value is Dictionary:
		var mapped: Dictionary = {}
		for key: Variant in value.keys():
			mapped[key] = _canonical_json(value[key])
		return mapped
	return value


static func _region(value: Variant) -> Variant:
	if not value is Dictionary or value.size() != 4:
		return null
	for key: String in ["x","y","width","height"]:
		if not value.has(key) or typeof(value[key]) != TYPE_INT:
			return null
	var x: int = value.x
	var y: int = value.y
	var w: int = value.width
	var h: int = value.height
	if w < 1 or h < 1 or x < -2147483648 or y < -2147483648 			or x > 2147483647 or y > 2147483647 			or w > 2147483647 or h > 2147483647:
		return null
	return Rect2i(x,y,w,h)


func _read_authorization() -> bool:
	if not FileAccess.file_exists(_authority_path):
		_fail("host_authorization_missing")
		return false
	var raw: String = FileAccess.get_file_as_string(_authority_path)
	if raw.length() > MAX_INPUT_BYTES or raw.is_empty():
		_fail("invalid_host_authorization_size")
		return false
	var value: Variant = _canonical_json(JSON.parse_string(raw))
	if not value is Dictionary:
		_fail("host_authorization_is_not_json_object")
		return false
	_authority = value
	if _authority.get("version") != PROTOCOL_VERSION or 			typeof(_authority.get("task_id")) != TYPE_STRING or 			str(_authority.task_id).is_empty() or str(_authority.task_id).length() > 128:
		_fail("invalid_host_authorization_version_or_task")
		return false
	if not _authority.get("extent",null) is Array or _authority.extent.size() != 2:
		_fail("invalid_host_canvas")
		return false
	for side: Variant in _authority.extent:
		if typeof(side) != TYPE_INT or side < 32 or side > 2048:
			_fail("invalid_host_canvas_extent")
			return false
	if _region(_authority.get("scope")) == null:
		_fail("invalid_host_scope")
		return false
	if not _authority.get("protected",null) is Array or _authority.protected.size() > 32:
		_fail("invalid_host_protection")
		return false
	for guard: Variant in _authority.protected:
		if _region(guard) == null:
			_fail("invalid_host_protection_region")
			return false
	if not _authority.get("allowed_materials",null) is Array 			or _authority.allowed_materials.is_empty():
		_fail("invalid_host_allowlist")
		return false
	for material: Variant in _authority.allowed_materials:
		if typeof(material) != TYPE_INT or material not in [0,58]:
			_fail("disallowed_host_agent_material")
			return false
	var stamps: Variant = _authority.get("start_edits",[])
	if not stamps is Array or stamps.size() > 128:
		_fail("invalid_host_authored_start")
		return false
	var extent: Vector2i = Vector2i(_authority.extent[0],_authority.extent[1])
	for stamp: Variant in stamps:
		if not stamp is Array or stamp.size() != 5:
			_fail("invalid_host_start_stamp")
			return false
		for field: Variant in stamp:
			if typeof(field) != TYPE_INT:
				_fail("noninteger_host_start_stamp")
				return false
		if stamp[0] < 0 or stamp[1] < 0 or stamp[2] < 1 or stamp[3] < 1 				or stamp[0] + stamp[2] > extent.x or stamp[1] + stamp[3] > extent.y 				or stamp[4] not in Setup.MATERIALS:
			_fail("host_start_stamp_outside_canvas_or_material_policy")
			return false
	return true


func _ready_native() -> bool:
	return _main != null and is_instance_valid(_main) 			and _main.shared_workbench != null 			and not _main.shared_workbench.applied.is_empty() 			and _main.latest_snapshot != null and _main.paused 			and not _main.shared_workbench.busy() 			and _main.pending_microscenario_apply.is_empty()


func _wait_until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func _start_world() -> bool:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	if not await _wait_until(Callable(self,"_ready_native")):
		_fail("shared_workbench_initialization_timeout")
		return false
	_workbench = _main.shared_workbench
	var old_generation: int = _main.latest_snapshot.render_world_generation
	var extent := Vector2i(_authority.extent[0],_authority.extent[1])
	var start: Dictionary = Setup.fresh(
		PackedInt32Array(_workbench.applied.liquid_policy),extent)
	start.edits = _authority.get("start_edits",[]).duplicate(true)
	if not _workbench.apply(start):
		_fail("host_authored_start_refused")
		return false
	if not await _wait_until(func() -> bool:
		return _ready_native() and _main.world_extent == extent 			and _main.latest_snapshot.render_world_generation != old_generation 			and _main.latest_snapshot.tick_index == 0 and _main.latest_snapshot.paused):
		_fail("host_authored_start_unacknowledged")
		return false
	var camera: Variant = _authority.get("camera_origin",null)
	if camera is Array and camera.size() == 2 and typeof(camera[0]) == TYPE_INT 			and typeof(camera[1]) == TYPE_INT:
		_workbench._set_view(Vector2(camera[0],camera[1]),
			_main.current_view_size)
	_bridge = Bridge.new()
	if not _bridge.bind(_main):
		_fail("native_four_tool_bridge_bind_refused")
		return false
	var protection: Array = []
	for item: Dictionary in _authority.protected:
		protection.append(_region(item))
	var auth: Dictionary = await _bridge.authorize_task(
		_authority.task_id,_region(_authority.scope),protection,
		_authority.allowed_materials.duplicate(),
		str(_authority.get("coordinate_frame_id","")))
	_append({"version":PROTOCOL_VERSION,"type":"authorization","status":auth.get("status",""),
		"result":_json_safe(auth)})
	if auth.get("status") != "authorized":
		_fail("native_host_authorization_refused:" + str(auth.get("reason","")))
		return false
	_authorized = true
	_manifest["world_generation"] = auth.get("generation",-1)
	return true


static func _json_safe(value: Variant) -> Variant:
	if value is Vector2i or value is Vector2:
		return {"x":value.x,"y":value.y}
	if value is Rect2i:
		return {"x":value.position.x,"y":value.position.y,
			"width":value.size.x,"height":value.size.y}
	if value is Rect2:
		return {"x":value.position.x,"y":value.position.y,
			"width":value.size.x,"height":value.size.y}
	if value is Array:
		var mapped: Array = []
		for item: Variant in value:
			mapped.append(_json_safe(item))
		return mapped
	if value is Dictionary:
		var mapped: Dictionary = {}
		for key: Variant in value:
			mapped[str(key)] = _json_safe(value[key])
		return mapped
	if value is PackedInt32Array or value is PackedInt64Array 			or value is PackedStringArray or value is PackedByteArray:
		return Array(value)
	return value


func _append(value: Dictionary) -> void:
	if _results != null:
		_results.store_string(JSON.stringify(value) + "\n")
		_results.flush()


func _capture_png(answer: Dictionary, seq: int, name: String) -> Dictionary:
	var observation: Dictionary = answer
	if name == "step":
		var nested: Variant = answer.get("observation",null)
		if not nested is Dictionary:
			return {"status":"none"}
		observation = nested
	var bytes: Variant = observation.get("framebuffer_png",null)
	observation.erase("framebuffer_png")
	if not bytes is PackedByteArray:
		return {"status":"none"}
	if bytes.size() < 8 or bytes.size() > MAX_PNG_BYTES 			or bytes[0] != 137 or bytes[1] != 80 or bytes[2] != 78 or bytes[3] != 71:
		_fail("invalid_original_framebuffer_png")
		return {"status":"invalid"}
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		_fail("original_png_failed_pixel_decode")
		return {"status":"invalid"}
	var changed: Variant = null
	if not _last_png.is_empty():
		var previous := Image.new()
		if previous.load_png_from_buffer(_last_png) == OK:
			changed = previous.get_width() != image.get_width() 				or previous.get_height() != image.get_height() 				or previous.get_data() != image.get_data()
	_last_png = bytes
	var relative: String = "frames/%03d-%s.png" % [seq,name]
	var absolute: String = _output.path_join(relative)
	var file := FileAccess.open(absolute,FileAccess.WRITE)
	if file == null:
		_fail("cannot_write_original_png")
		return {"status":"invalid"}
	file.store_buffer(bytes)
	file.close()
	var record: Dictionary = {"status":"original_post_draw","path":relative,
		"sha256":FileAccess.get_sha256(absolute),"bytes":bytes.size(),
		"width":image.get_width(),"height":image.get_height(),
		"pixels_changed_from_previous_frame":changed}
	_manifest["frames"].append(record.duplicate(true))
	return record


func _execute_command(command: Dictionary) -> void:
	_count += 1
	var seq: Variant = command.get("seq",null)
	var tool: Variant = command.get("tool",null)
	var args: Variant = command.get("args",{})
	if typeof(seq) != TYPE_INT or seq <= _previous_seq 			or typeof(tool) != TYPE_STRING or not args is Dictionary:
		_fail("invalid_or_nonmonotonic_command_envelope")
		return
	_previous_seq = seq
	if _count > MAX_COMMANDS:
		_fail("session_command_budget_exhausted")
		return
	var allowed_keys := ["seq","tool","args","expect_status","version"]
	for key: Variant in command.keys():
		if key not in allowed_keys:
			_fail("unexpected_command_envelope_key")
			return
	if command.get("version") != PROTOCOL_VERSION:
		_fail("unsupported_command_schema_version")
		return
	var name: String = tool
	if name not in ["observe","prepare_edit","apply_edit","step","stop"]:
		_fail("command_not_a_workbench_tool")
		return
	var data: Dictionary = args.duplicate(true)
	if name == "prepare_edit" and data.get("observation_id",null) == "@last":
		data["observation_id"] = _last_observation
	if name == "apply_edit" and data.get("proposal_id",null) == "@last":
		data["proposal_id"] = _last_proposal
	var reply: Dictionary
	if name == "stop":
		if not data.is_empty():
			reply = {"status":"refused","reason":"stop_takes_no_model_arguments"}
		else:
			reply = await _bridge.stop()
			if reply.get("status") == "stopped":
				_stopped = true
	elif name == "step":
		var ticks: Variant = data.get("ticks",null)
		if typeof(ticks) == TYPE_INT and ticks > 0 				and _total_ticks + ticks > MAX_TOTAL_TICKS:
			reply = {"status":"refused","reason":"remote_session_total_tick_budget"}
		else:
			reply = await _bridge.call_tool(name,data)
			_total_ticks += int(reply.get("completed",0))
	else:
		reply = await _bridge.call_tool(name,data)
	if name == "observe" and reply.get("status") == "observed":
		_last_observation = str(reply.get("observation_id",""))
	if name == "prepare_edit" and reply.get("status") == "proposed":
		_last_proposal = str(reply.get("proposal_id",""))
	var frame: Dictionary = _capture_png(reply,seq,name)
	var result := {"version":PROTOCOL_VERSION,"type":"tool_result","seq":seq,
		"tool":name,"status":reply.get("status",""),"result":_json_safe(reply),
		"frame":frame,"completed_native_ticks_total":_total_ticks}
	_append(result)
	if command.has("expect_status") and command.expect_status != reply.get("status"):
		_fail("unexpected_status_seq_%d:%s" % [seq,str(reply.get("status",""))])
	if reply.get("status") == "unconfirmed":
		_fail("uncertain_native_mutation_seq_%d" % seq)
	if name == "step" and reply.get("status") == "completed":
		var matched: Variant = reply.get("observation",{})
		if not matched is Dictionary or matched.get("status") != "observed" 				or matched.get("image_status") != "matched_post_draw" 				or int(matched.get("identity",{}).get("completed_tick",-1)) 					!= int(reply.get("after_tick",-2)) 				or frame.get("status") != "original_post_draw":
			_fail("step_without_matched_native_frame_seq_%d" % seq)
	if name == "observe" and reply.get("status") == "observed" 			and frame.get("status") != "original_post_draw":
		_fail("observed_without_original_png_seq_%d" % seq)


func _process_jsonl(line: String) -> void:
	if line.strip_edges().is_empty():
		return
	if _count >= MAX_COMMANDS:
		_fail("max_session_commands_exceeded")
		return
	var parsed: Variant = _canonical_json(JSON.parse_string(line))
	if not parsed is Dictionary:
		_fail("invalid_jsonl_command")
		return
	await _execute_command(parsed)


func _run_commands() -> void:
	var deadline: int = Time.get_ticks_msec() + LIVE_DEADLINE_MSEC
	while _failures.is_empty():
		if Time.get_ticks_msec() >= deadline:
			_fail("live_session_deadline_reached")
			break
		if not FileAccess.file_exists(_commands_path):
			_fail("commands_file_missing")
			break
		var text_now: String = FileAccess.get_file_as_string(_commands_path)
		if text_now.length() > MAX_INPUT_BYTES 				or not text_now.begins_with(_consumed_input):
			_fail("command_stream_changed_or_over_budget")
			break
		var unconsumed: String = text_now.substr(_consumed_input.length())
		var split: PackedStringArray = unconsumed.split("\n")
		for index: int in range(split.size()-1):
			var line: String = split[index]
			_consumed_input += line + "\n"
			await _process_jsonl(line)
			if not _failures.is_empty():
				break
		if not _failures.is_empty():
			break
		if _mode == "batch":
			if not unconsumed.is_empty() and not unconsumed.ends_with("\n"):
				_fail("batch_commands_missing_trailing_newline")
			break
		if _stopped:
			# Permit one already buffered late-mutation refusal, then close.
			if _consumed_input == text_now:
				break
		await process_frame


func _run() -> void:
	_start_msec = Time.get_ticks_msec()
	if not _cli():
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(_output.path_join("frames")) != OK:
		_fail("output_directory_unavailable")
		quit(2)
		return
	_results = FileAccess.open(_output.path_join("results.jsonl"),FileAccess.WRITE)
	if _results == null:
		_fail("results_file_unavailable")
		quit(2)
		return
	_manifest = {"version":PROTOCOL_VERSION,"mode":_mode,"task":{},
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_SHA"),
		"source_tree":OS.get_environment("CYBERSAND_SOURCE_TREE"),
		"native_runtime_sha256":OS.get_environment("CYBERSAND_NATIVE_SHA256"),
		"rapier_runtime_sha256":OS.get_environment("CYBERSAND_RAPIER_SHA256"),
		"godot_runtime_sha256":OS.get_environment("CYBERSAND_GODOT_SHA256"),
		"godot_version":Engine.get_version_info(),"platform":OS.get_name(),
		"frames":[]}
	if _read_authorization():
		_manifest["task"] = {"task_id":_authority.task_id,
			"authorization_sha256":FileAccess.get_sha256(_authority_path),
			"extent":_authority.extent,"scope":_authority.scope,
			"allowed_materials":_authority.allowed_materials}
		if await _start_world():
			await _run_commands()
	if _authorized and not _stopped and _bridge != null:
		var stop_result: Dictionary = await _bridge.stop()
		_append({"version":PROTOCOL_VERSION,"type":"forced_stop",
			"status":stop_result.get("status",""),"result":_json_safe(stop_result)})
		if stop_result.get("status") != "stopped":
			_fail("native_retirement_not_acknowledged")
		elif _failures.is_empty():
			_fail("missing_explicit_stop")
	_manifest["command_count"] = _count
	_manifest["completed_native_ticks_total"] = _total_ticks
	_manifest["stopped"] = _stopped
	_manifest["result"] = "passed" if _failures.is_empty() else "failed"
	_manifest["failures"] = _failures.duplicate()
	_manifest["elapsed_msec"] = Time.get_ticks_msec() - _start_msec
	var report := FileAccess.open(_output.path_join("manifest.json"),FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(_manifest,"  ") + "\n")
		report.close()
	_results.close()
	if is_instance_valid(_main):
		_main.queue_free()
		await process_frame
		await process_frame
	print("REMOTE_WB_RESULT " + JSON.stringify({"status":_manifest.result,
		"commands":_count,"completed_native_ticks":_total_ticks,
		"frames":_manifest.frames.size(),"failures":_failures}))
	quit(0 if _failures.is_empty() else 1)
