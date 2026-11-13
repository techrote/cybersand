extends Node

# Source authoring is a polled process. No scene object crosses the boundary;
# closing the Lab never joins an unbounded OS.execute thread.
signal completed(result: Dictionary)
const MAX_RESPONSE_BYTES: int = 8 * 1024 * 1024
const MAX_OUTPUT_CHARS: int = 8192
const CANCEL_GRACE_MSEC: int = 2000
var job_timeout_msec: int = 300000
var busy: bool = false
var _serial: int = 0
var _handle: Dictionary = {}
var _pid: int = -1
var _response_path: String = ""
var _cancel_path: String = ""
var _deadline: int = 0
var _cancel_deadline: int = 0
var _cancel_reason: String = ""
var _output: String = ""
var _forced_termination: bool = false

func source_tool() -> String:
	return ProjectSettings.globalize_path("res://../tools/material_catalogue/lab.py").simplify_path()

func process_id() -> int:
	return _pid

func request(value: Dictionary, python: String = "") -> bool:
	if busy: return false
	if not FileAccess.file_exists(source_tool()):
		completed.emit({"ok":false,"errors":["Source authoring needs the repository checkout, including tools/material_catalogue/lab.py. Open its godot project."]})
		return false
	_serial += 1
	var directory: String = "user://materials_lab/jobs/%d-%d" % [Time.get_ticks_usec(),_serial]
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		completed.emit({"ok":false,"errors":["Cannot create the Materials Lab job directory."]})
		return false
	var request_path: String = ProjectSettings.globalize_path(directory.path_join("request.json"))
	_response_path = ProjectSettings.globalize_path(directory.path_join("response.json"))
	_cancel_path = ProjectSettings.globalize_path(directory.path_join("cancel"))
	var file := FileAccess.open(request_path,FileAccess.WRITE)
	if file == null:
		completed.emit({"ok":false,"errors":["Cannot write the authoring request."]})
		return false
	file.store_string(JSON.stringify(value,"\t") + "\n")
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		completed.emit({"ok":false,"errors":["Writing the authoring request failed: %s" % write_error]})
		return false
	if python.strip_edges().is_empty(): python = "python" if OS.get_name() == "Windows" else "python3"
	_output = ""
	_forced_termination = false
	_cancel_reason = ""
	_cancel_deadline = 0
	_handle = OS.execute_with_pipe(python,PackedStringArray([source_tool(),"--request",request_path,"--response",_response_path,"--cancel-file",_cancel_path]),false)
	_pid = int(_handle.get("pid",-1))
	if _pid <= 0:
		_close_pipes()
		completed.emit({"ok":false,"errors":["Could not start the authoring process. Check the Python executable path."]})
		return false
	busy = true
	_deadline = Time.get_ticks_msec() + clampi(job_timeout_msec,100,300000)
	return true

func cancel(reason: String = "Authoring cancelled; the current candidate has not been qualified by this job.") -> bool:
	if not busy: return false
	if not _cancel_reason.is_empty(): return true
	_cancel_reason = reason
	_cancel_deadline = Time.get_ticks_msec() + CANCEL_GRACE_MSEC
	var file := FileAccess.open(_cancel_path,FileAccess.WRITE)
	if file != null:
		file.store_string("cancelled\n")
		file.close()
	return true

func _drain_pipes() -> void:
	# Nonblocking pipes and a byte budget bound work and retained diagnostics.
	for key: String in ["stdio","stderr"]:
		var pipe: FileAccess = _handle.get(key)
		if pipe == null: continue
		for _chunk: int in range(4):
			var bytes: PackedByteArray = pipe.get_buffer(4096)
			if bytes.is_empty(): break
			_output = (_output + bytes.get_string_from_utf8()).right(MAX_OUTPUT_CHARS)

func _close_pipes() -> void:
	for key: String in ["stdio","stderr"]:
		var pipe: FileAccess = _handle.get(key)
		if pipe != null: pipe.close()
	_handle.clear()

func _response_error(value: Dictionary) -> String:
	# Refuse malformed protocol values before a scene consumer can promote a
	# candidate or dereference nested response fields. Native receipts have their
	# own consumer-specific admission in the corresponding view.
	if typeof(value.get("state")) != TYPE_STRING or value.state not in ["draft","validated_candidate","compiled_tested"]:
		return "Authoring response has an unsupported or missing candidate state."
	if typeof(value.get("runtime_active")) != TYPE_BOOL or value.runtime_active:
		return "Authoring response cannot claim runtime activation."
	if not value.ok:
		var errors: Variant = value.get("errors")
		if not errors is Array or errors.is_empty(): return "Authoring failure must include an actionable error list."
		for error: Variant in errors:
			if typeof(error) != TYPE_STRING: return "Authoring error entries must be text."
		return ""
	if value.has("candidate") and not value.candidate is Dictionary: return "Authoring candidate response must be an object."
	if value.has("receipt") and not value.receipt is Dictionary: return "Authoring native receipt must be an object."
	if value.state == "compiled_tested" and not value.has("receipt"): return "Compiled/tested status requires a native execution receipt."
	for key: String in ["digest","boundary","output_dir"]:
		if value.has(key) and typeof(value[key]) != TYPE_STRING: return "Authoring %s response must be text." % key
	if value.has("changes"):
		if not value.changes is Array: return "Authoring changes must be a list."
		for change: Variant in value.changes:
			if not change is Dictionary or typeof(change.get("path")) != TYPE_STRING or not change.has_all(["before","after"]):
				return "Authoring change entries must identify a path and before/after values."
	return ""

func _read_result(code: int) -> Dictionary:
	if not _cancel_reason.is_empty():
		return {"ok":false,"state":"draft","runtime_active":false,"cancelled":true,"forced_termination":_forced_termination,"errors":[_cancel_reason],"process_exit_code":code}
	if FileAccess.file_exists(_response_path):
		var file := FileAccess.open(_response_path,FileAccess.READ)
		if file != null:
			if file.get_length() > MAX_RESPONSE_BYTES:
				file.close()
				return {"ok":false,"errors":["Authoring response exceeds the 8 MiB limit; no tested status was recorded."]}
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary and typeof(parsed.get("ok")) == TYPE_BOOL:
				var problem: String = _response_error(parsed)
				if not problem.is_empty():
					return {"ok":false,"state":"draft","runtime_active":false,"errors":[problem + " No tested status was recorded."],"process_exit_code":code}
				if parsed.ok and code != 0:
					return {"ok":false,"errors":["Authoring process exited with %d after reporting success; no tested status was recorded." % code],"process_exit_code":code}
				parsed["process_exit_code"] = code
				return parsed
	return {"ok":false,"errors":["Authoring process failed or returned an invalid response (exit %d). Check the Python executable and compiler installation. %s" % [code,_output]],"process_exit_code":code}

func _process(_delta: float) -> void:
	if not busy: return
	_drain_pipes()
	if OS.is_process_running(_pid):
		if Time.get_ticks_msec() >= _deadline and _cancel_reason.is_empty():
			cancel("Authoring exceeded its bounded %d ms deadline; no tested status was recorded." % clampi(job_timeout_msec,100,300000))
		if _cancel_deadline > 0 and Time.get_ticks_msec() >= _cancel_deadline:
			var error: Error = OS.kill(_pid)
			if error != OK:
				_cancel_reason += " The process could not be terminated (error %s); inspect process %d." % [error,_pid]
			else:
				_forced_termination = true
			# OS.kill reaps its handle; querying it again is invalid on Unix.
			_finish(-1)
		return
	_finish(OS.get_process_exit_code(_pid))

func _finish(code: int) -> void:
	_drain_pipes()
	var result: Dictionary = _read_result(code)
	_close_pipes()
	_pid = -1
	busy = false
	completed.emit(result)

func _exit_tree() -> void:
	if busy and _pid > 0:
		cancel("Materials Lab closed; authoring cancelled.")
		# Python polls the marker and reaps its compiler group. Cleanup has a
		# fixed limit even when the selected executable ignores the protocol.
		var until: int = Time.get_ticks_msec() + CANCEL_GRACE_MSEC
		while OS.is_process_running(_pid) and Time.get_ticks_msec() < until:
			_drain_pipes()
			OS.delay_msec(10)
		if OS.is_process_running(_pid): OS.kill(_pid)
	_close_pipes()
	_pid = -1
	busy = false
