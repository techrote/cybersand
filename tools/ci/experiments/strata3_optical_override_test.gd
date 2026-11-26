extends "res://tests/test_strata_optical_renderer.gd"

## External experiment wrapper. The inherited frozen test runs unchanged.
## Only its shared Shader resource code is replaced in this process; no
## application file, native resource or assertion is rewritten.
const ORIGINAL_SHADER_SHA256 := "b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb"
const CANDIDATE_SHADER_SHA256 := "50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f"
const APPLICATION := "fd0830abcfadd9ae19162e5677943bb131223e59"


func _initialize() -> void:
	var candidate_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--optical-shader-override="):
			candidate_path = argument.trim_prefix("--optical-shader-override=")
	if candidate_path.is_empty() or not FileAccess.file_exists(candidate_path):
		push_error("A1 experiment requires an existing --optical-shader-override path")
		quit(2)
		return
	var source_path := "res://shaders/strata_optical_plane.gdshader"
	if FileAccess.get_sha256(source_path) != ORIGINAL_SHADER_SHA256 \
			or Renderer.OPTICAL_SHADER.code.sha256_text() != ORIGINAL_SHADER_SHA256:
		push_error("A1 experiment refused: original frozen shader identity differs")
		quit(2)
		return
	var candidate := FileAccess.get_file_as_string(candidate_path)
	if candidate.length() > 65536 or candidate.sha256_text() != CANDIDATE_SHADER_SHA256 \
			or FileAccess.get_sha256(candidate_path) != CANDIDATE_SHADER_SHA256:
		push_error("A1 experiment refused: candidate shader identity differs")
		quit(2)
		return
	var shared_shader: Shader = Renderer.OPTICAL_SHADER
	shared_shader.code = candidate
	print("STRATA003_SHADER_OVERRIDE " + JSON.stringify({
		"application":APPLICATION,
		"original_shader_sha256":ORIGINAL_SHADER_SHA256,
		"candidate_shader_sha256":CANDIDATE_SHADER_SHA256,
		"wrapper_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scope":"In-process shared Shader resource override; inherited frozen assertions unchanged"}))
	super._initialize()
