extends "res://tools/qualify_workbench_strata3.gd"

## External A/B research only; the application's on-disk shader is unchanged.
const PROBE_CASES := [
	["classic-original","classic","original"],
	["architectural-original","architectural","original"],
	["architectural-empty-coverage","architectural","empty-coverage"],
	["clarity-original","gameplay_clarity","original"],
	["clarity-empty-coverage","gameplay_clarity","empty-coverage"]]
var _probe_shader: Shader = preload("res://shaders/strata_optical_plane.gdshader")
var _original_code := ""
var _candidate_code := ""
var _active_tag := ""
var _active_capture: Dictionary = {}
var _paired_images: Dictionary = {}


func _settle_focus() -> void:
	await super._settle_focus()
	if _active_tag.is_empty(): return
	_freeze_visual_motion()
	await settle()
	_active_capture = {"tag":_active_tag,"camera":_camera_state(),"actor":_actor_state(),
		"configuration":_configuration(),"configuration_json":_canonical(_configuration()),
		"configuration_sha256":_canonical(_configuration()).sha256_text(),
		"shader_sha256":_probe_shader.code.sha256_text(),"physical_paused":host.paused,
		"outside_timed_window":true}
	_active_capture.plane_native_hashes = await all_native_hashes()
	if diagnostic_headless: return
	var frame: Image = await capture(_active_tag)
	_active_capture.filename = _active_tag+".png"
	_active_capture.sha256 = FileAccess.get_sha256(output.path_join(_active_capture.filename))
	_active_capture.actual_image_size = [frame.get_width(),frame.get_height()]
	_active_capture.captured_usec = Time.get_ticks_usec()
	_paired_images[_active_tag] = frame


func _progression() -> void:
	record.schema = "strata3-shader-cost-observation-v1"
	record.observer_source_revision = OS.get_environment("STRATA3_OBSERVER_SOURCE_REVISION")
	record.observer_sha256 = OS.get_environment("STRATA3_DRIVER_SHA256")
	_original_code = _probe_shader.code
	_candidate_code = FileAccess.get_file_as_string(OS.get_environment("STRATA3_SHADER_OVERRIDE_PATH"))
	if not check(_original_code.sha256_text() == "b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb", "exact immutable original shader loaded"): return
	if not check(_candidate_code.sha256_text() == "50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f" and _candidate_code.sha256_text() == OS.get_environment("STRATA3_SHADER_OVERRIDE_SHA256"),"exact external candidate shader supplied"): return
	record.original_shader_sha256 = _original_code.sha256_text()
	record.candidate_shader_sha256 = _candidate_code.sha256_text()
	record.probe_registration = {"cases":PROBE_CASES,"repeats":3,"callbacks_per_sample":90,
		"order":"forward/reverse/forward","quality":"balanced","geometry_reset_between_samples":true,
		"per_sample_watchdog_usec":90000000,"shader_compilation_and_captures_before_timing":true,
		"minimum_native_rate_ratio_to_classic":0.90,"minimum_rapier_rate_ratio_to_classic":0.90,
		"p95_ratio":1.20,"p95_allowance_usec":10000,
		"scope":"Same immutable fd0830ab application with separately hashed runtime shader override. Hosted experimental evidence; no application adoption or physical GPU acceptance."}
	record.probe_samples = []
	record.pixel_equivalence = []
	for repeat_index: int in 3:
		var order := PROBE_CASES.duplicate(true)
		if repeat_index%2 == 1: order.reverse()
		for item: Array in order:
			_active_tag = str(item[0])+"-"+str(repeat_index)
			_probe_shader.code = _original_code if item[2] == "original" else _candidate_code
			print("STRATA3_COST_PROBE ",_active_tag," ",_probe_shader.code.sha256_text())
			var sample: Dictionary = await _progression_sample(str(item[1]),repeat_index)
			sample.variant = item[2]
			sample.case_id = item[0]
			sample.shader_sha256 = _probe_shader.code.sha256_text()
			sample.paused_capture = _active_capture.duplicate(true)
			check(sample.callbacks == 90 and sample.completed_physical_steps.size() >= 2,"complete cost probe physical population")
			record.probe_samples.append(sample)
		if not diagnostic_headless:
			for prefix: String in ["architectural","clarity"]:
				var first := prefix+"-original-"+str(repeat_index)
				var second := prefix+"-empty-coverage-"+str(repeat_index)
				var comparison := _exact_difference(_paired_images[first],_paired_images[second])
				comparison.original = first
				comparison.candidate = second
				comparison.repeat = repeat_index
				check(comparison.exact_equal,"original and candidate actual world RGBA exact "+prefix+" "+str(repeat_index))
				record.pixel_equivalence.append(comparison)
		_paired_images.clear()
	_active_tag = ""
	_probe_shader.code = _original_code
	record.original_shader_restored = _probe_shader.code.sha256_text() == record.original_shader_sha256
	check(record.original_shader_restored and record.probe_samples.size() == 15,"all probe windows complete and original shader restored")
