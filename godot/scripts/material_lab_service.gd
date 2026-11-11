extends Node

# Copied source-authoring requests cross this worker boundary. No scene object
# enters the job, and no authoring process can modify the running native World.
signal completed(result: Dictionary)
var _thread: Thread
var _serial: int = 0
var busy: bool = false

func source_tool() -> String:
	return ProjectSettings.globalize_path("res://../tools/material_catalogue/lab.py").simplify_path()

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
	var response_path: String = ProjectSettings.globalize_path(directory.path_join("response.json"))
	var file := FileAccess.open(request_path,FileAccess.WRITE)
	if file == null:
		completed.emit({"ok":false,"errors":["Cannot write the authoring request."]})
		return false
	file.store_string(JSON.stringify(value,"\t") + "\n")
	file.close()
	if python.strip_edges().is_empty(): python = "python" if OS.get_name() == "Windows" else "python3"
	busy = true
	_thread = Thread.new()
	var error: Error = _thread.start(_execute.bind(python,source_tool(),request_path,response_path))
	if error != OK:
		busy = false
		_thread = null
		completed.emit({"ok":false,"errors":["Could not start the authoring worker: %s" % error]})
		return false
	return true

static func _execute(python: String, tool: String, request_path: String, response_path: String) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute(python,PackedStringArray([tool,"--request",request_path,"--response",response_path]),output,true)
	if FileAccess.file_exists(response_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(response_path))
		if parsed is Dictionary:
			parsed["process_exit_code"] = code
			return parsed
	return {"ok":false,"errors":["Authoring process failed (exit %d). Check the Python executable and compiler installation. %s" % [code,"\n".join(output).left(3000)]],"process_exit_code":code}

func _process(_delta: float) -> void:
	if busy and _thread != null and not _thread.is_alive():
		var result: Dictionary = _thread.wait_to_finish()
		_thread = null
		busy = false
		completed.emit(result)

func _exit_tree() -> void:
	# The backend bounds compiler execution. Join before releasing the worker.
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
