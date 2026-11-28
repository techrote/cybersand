extends SceneTree

## Resource/constant evaluation only. Graphical execution is qualified separately.
const Renderer = preload("res://scripts/depth/strata_optical_renderer.gd")
const SeparatelyPreloaded = preload("res://shaders/strata_optical_plane.gdshader")
const APPLICATION := "fd0830abcfadd9ae19162e5677943bb131223e59"
const ORIGINAL := "b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb"
const CANDIDATE := "50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f"

func _initialize() -> void:
	var path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--optical-shader-override="):
			path = argument.trim_prefix("--optical-shader-override=")
	var original := FileAccess.get_file_as_string("res://shaders/strata_optical_plane.gdshader")
	var candidate := FileAccess.get_file_as_string(path)
	if original.sha256_text() != ORIGINAL or candidate.sha256_text() != CANDIDATE:
		push_error("Identity diagnostic requires the exact frozen original and candidate")
		quit(2)
		return
	var renderer = Renderer.new()
	var live: Shader = renderer.OPTICAL_SHADER
	var separate: Shader = SeparatelyPreloaded
	var material := ShaderMaterial.new()
	material.shader = live
	var record := {"schema":"strata3-live-shader-identity-v1","application":APPLICATION,
		"scope":"Headless resource/constant evaluation diagnostic; not graphical or performance qualification",
		"version":Engine.get_version_info(),"diagnostic_sha256":FileAccess.get_sha256(get_script().resource_path),
		"display_server":DisplayServer.get_name(),"same_resource":live == separate,
		"live_id":str(live.get_instance_id()),"separate_id":str(separate.get_instance_id()),
		"before":{"runtime_code_sha256":live.code.sha256_text(),"statistics_sha256":renderer.statistics().shader_sha256}}
	live.code = candidate
	record.after = {"runtime_code_sha256":live.code.sha256_text(),
		"separate_runtime_code_sha256":separate.code.sha256_text(),
		"material_runtime_code_sha256":material.shader.code.sha256_text(),
		"statistics_sha256":renderer.statistics().shader_sha256,
		"script_constant_property_sha256":Renderer.OPTICAL_SHADER.code.sha256_text()}
	live.code = original
	record.restored = live.code.sha256_text()
	print("STRATA3_SHADER_RESOURCE_DIAGNOSTIC ",JSON.stringify(record))
	quit(0)
