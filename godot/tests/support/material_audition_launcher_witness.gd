extends Node

# An opt-in observer for the shipped .cmd launcher. It neither constructs a
# fixture nor replaces a World. The ordinary Workbench calls attach() only after
# its real authored start has been acknowledged by the existing native owner.
# Normal interactive launches never create this observer.
var _owner: Control
var _path := ""
var _nonce := ""
var _deadline := 0
var _ending := false

static func attach(owner: Control) -> void:
	var path := OS.get_environment("MAT_AUDITION_LAUNCHER_RECEIPT")
	if path.is_empty() or owner.has_meta("material_audition_launcher_witness"): return
	owner.set_meta("material_audition_launcher_witness",true)
	var observer: Node = load("res://tests/support/material_audition_launcher_witness.gd").new()
	observer._owner = owner
	observer._path = path
	observer._nonce = OS.get_environment("MAT_AUDITION_LAUNCHER_NONCE")
	observer._deadline = Time.get_ticks_msec() + 90000
	owner.add_child(observer)

func _process(_delta: float) -> void:
	if _ending: return
	if not is_instance_valid(_owner): return
	var state: Dictionary = _owner.host.simulation_worker.material_audition_state()
	if state.get("ok",false) and not _owner.busy() and not _owner.applied.is_empty():
		_ending = true
		complete.call_deferred(state)
	elif Time.get_ticks_msec() >= _deadline:
		_ending = true
		complete.call_deferred({"ok":false,"error":"Ordinary Workbench native readiness deadline expired."})

func complete(state: Dictionary) -> void:
	var native := "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	var result := {"schema":"cybersand.material-audition.launcher","schema_version":1,"checks":1,"failures":0,
		"status":"passed","nonce":_nonce,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"native_sha256":FileAccess.get_sha256(native),"display":DisplayServer.get_name(),
		"godot":Engine.get_version_info().string,"world_id":str(state.get("world_id","")),
		"configuration_revision":int(state.get("revision",-1)),"profile":state.get("profile",{}),
		"extent":_owner.applied.get("extent",[]),"host_scene":_owner.host.scene_file_path,
		"native_tick":_owner.host.latest_snapshot.tick_index,
		"native_world_generation":_owner.host.latest_snapshot.render_world_generation,
		"workbench_visible":_owner.is_visible_in_tree(),"frame":{}}
	var valid: bool = state.get("ok",false) and not result.world_id.is_empty() and result.configuration_revision == 0 and result.workbench_visible and result.native_world_generation > 0 and _nonce.length() == 32 and _path.is_absolute_path() and _path.ends_with(".json") and not FileAccess.file_exists(_path) and result.display != "headless"
	if valid:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = _owner.get_tree().root.get_texture().get_image()
		var filename := _path.get_basename() + ".png"
		valid = frame != null and not frame.is_empty() and frame.get_width() >= 400 and frame.get_height() >= 300 and frame.save_png(filename) == OK
		if valid: result.frame = {"file":filename.get_file(),"sha256":FileAccess.get_sha256(filename),"width":frame.get_width(),"height":frame.get_height()}
	if not valid:
		result.status = "failed"
		result.failures = 1
		result.error = state.get("error","Ordinary graphical Workbench readiness or frame custody failed.")
	var file := FileAccess.open(_path,FileAccess.WRITE)
	if file == null:
		result.status = "failed"
		result.failures = 1
		result.error = "Cannot write launcher evidence."
	else:
		file.store_string(JSON.stringify(result,"\t") + "\n")
		file.close()
	print("MATERIAL_AUDITION_LAUNCHER_RESULT " + JSON.stringify(result))
	get_tree().quit(0 if result.status == "passed" else 1)
