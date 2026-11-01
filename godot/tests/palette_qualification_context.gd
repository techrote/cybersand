extends RefCounted

# Test-only runtime/source receipt. It changes no shader input or visual oracle.
const Policy = preload("res://tests/support/ci_execution_policy.gd")
const Selector = preload("res://scripts/palette_shader_selector.gd")

static func identity(fixture: String, shader: Shader = null) -> Dictionary:
	return {"schema":"palette-qualification-context-v1", "fixture":fixture,
		"fixture_sha256":FileAccess.get_sha256(fixture),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"nonce":OS.get_environment("CYBERSAND_SHADER_NONCE"), "process_id":OS.get_process_id(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"engine_path":OS.get_executable_path(),
		"platform":OS.get_name(), "godot":Engine.get_version_info(),
		"display_server":DisplayServer.get_name(),
		"backend":RenderingServer.get_current_rendering_driver_name(),
		"video_adapter":RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "headless",
		"user_data_dir":OS.get_user_data_dir(), "cache_state":OS.get_environment("CYBERSAND_SHADER_CACHE_STATE"),
		"execution_policy":Policy.identity(), "shader":Selector.provenance(shader) if shader != null else {}}

static func emit(fixture: String, shader: Shader = null) -> void:
	print("PALETTE_QUALIFICATION_CONTEXT ", JSON.stringify(identity(fixture, shader)))

static func capture(image: Image, label: String) -> Dictionary:
	var folder: String = OS.get_environment("CYBERSAND_SHADER_CAPTURE")
	if folder.is_empty(): folder = OS.get_environment("CYBERSAND_PALETTE_CROSSFADE_OUTPUT")
	if folder.is_empty(): return {}
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return {"error":"capture directory"}
	var raw_path: String = folder.path_join(label + ".raw")
	var raw: FileAccess = FileAccess.open(raw_path, FileAccess.WRITE)
	if raw == null: return {"error":"capture raw file"}
	raw.store_buffer(image.get_data())
	raw.close()
	var display: Image = image.duplicate()
	display.convert(Image.FORMAT_RGBA8)
	var png_path: String = folder.path_join(label + ".png")
	if display.save_png(png_path) != OK: return {"error":"capture PNG"}
	var record: Dictionary = {"label":label, "size":[image.get_width(),image.get_height()],
		"format":image.get_format(), "raw":label+".raw", "png":label+".png",
		"raw_sha256":FileAccess.get_sha256(raw_path), "png_sha256":FileAccess.get_sha256(png_path)}
	print("PALETTE_QUALIFICATION_CAPTURE ", JSON.stringify(record))
	return record
