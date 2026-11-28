extends "res://tools/qualify_workbench_strata3.gd"

## External A/B research only; the application's on-disk shader is unchanged.
const PROBE_CASES := [
	["classic-original","classic","original"],
	["architectural-original","architectural","original"],
	["architectural-empty-coverage","architectural","empty-coverage"],
	["clarity-original","gameplay_clarity","original"],
	["clarity-empty-coverage","gameplay_clarity","empty-coverage"]]
var _probe_shader: Shader
var _touched_shaders: Array[Shader] = []
var _original_code := ""
var _candidate_code := ""
var _desired_code := ""
var _active_profile := ""
var _active_tag := ""
var _active_capture: Dictionary = {}
var _paired_images: Dictionary = {}


func _live_binding() -> Dictionary:
	var renderer = strata.presenter._optics
	var actual: Shader = renderer.OPTICAL_SHADER
	var statistics: Dictionary = strata.presenter.optics_statistics()
	var expected := _desired_code.sha256_text()
	check(actual == _probe_shader and actual.code.sha256_text() == expected,
		"actual renderer Shader resource has the selected experiment code")
	# The frozen script's constant/property hash expression preserves its
	# original compiled-source value under a runtime code override. A separate
	# per-host diagnostic proves that behaviour; actual attachments below are
	# the mandatory runtime-code witness, never this source-provenance field.
	check(str(statistics.shader_sha256) == _original_code.sha256_text() and str(statistics.profile) == _active_profile,
		"frozen presenter source provenance and active profile remain exact")
	var receipt := {"shader_instance_id":str(actual.get_instance_id()),
		"shader_sha256":actual.code.sha256_text(),"statistics_shader_sha256":str(statistics.shader_sha256),
		"profile":str(statistics.profile),"cached_material_count":renderer._materials.size(),
		"classic_materials_restored":true,"materials":{}}
	for id: String in ["background","effects","scripted"]:
		var drawable: TextureRect = renderer._drawables[id]
		if drawable.material != renderer._classic[id]: receipt.classic_materials_restored = false
		if _active_profile == "classic": continue
		if not check(renderer._materials.has(id),"optical cache contains actual active plane "+id): continue
		var cached: ShaderMaterial = renderer._materials[id]
		check(drawable.material == cached and cached.shader == actual,
			"actual drawable and cached optical material bind the live shader "+id)
		receipt.materials[id] = {"material_instance_id":str(cached.get_instance_id()),
			"cached_shader_instance_id":str(cached.shader.get_instance_id()),
			"drawable_shader_instance_id":str(drawable.material.shader.get_instance_id()),
			"shader_sha256":cached.shader.code.sha256_text(),"cache_is_drawable_material":drawable.material == cached}
	if _active_profile == "classic":
		check(receipt.cached_material_count == 0 and receipt.classic_materials_restored,
			"fresh Classic binds only original materials")
	else:
		check(receipt.cached_material_count == 3 and receipt.materials.size() == 3,
			"all three actual optical material attachments witnessed")
	return receipt


func _settle_focus() -> void:
	await super._settle_focus()
	if _active_tag.is_empty(): return
	# Fresh native scene admission creates the live presenter. Mutating a
	# separate preload of the same path is not evidence of its attachment.
	_probe_shader = strata.presenter._optics.OPTICAL_SHADER
	if not check(_probe_shader.code.sha256_text() in [_original_code.sha256_text(),_candidate_code.sha256_text()],
		"live renderer contains only the registered original or candidate shader"):
		quit(1)
		return
	if _probe_shader not in _touched_shaders: _touched_shaders.append(_probe_shader)
	_probe_shader.code = _desired_code
	await settle()
	var failures_before := failures.size()
	var binding := _live_binding()
	if failures.size() != failures_before:
		quit(1)
		return
	_freeze_visual_motion()
	await settle()
	_active_capture = {"tag":_active_tag,"camera":_camera_state(),"actor":_actor_state(),
		"configuration":_configuration(),"configuration_json":_canonical(_configuration()),
		"configuration_sha256":_canonical(_configuration()).sha256_text(),
		"shader_sha256":_probe_shader.code.sha256_text(),"physical_paused":host.paused,
		"outside_timed_window":true,"live_shader_binding":binding}
	_active_capture.plane_native_hashes = await all_native_hashes()
	if diagnostic_headless: return
	var frame: Image = await capture(_active_tag)
	_active_capture.filename = _active_tag+".png"
	_active_capture.sha256 = FileAccess.get_sha256(output.path_join(_active_capture.filename))
	_active_capture.actual_image_size = [frame.get_width(),frame.get_height()]
	_active_capture.captured_usec = Time.get_ticks_usec()
	_paired_images[_active_tag] = frame


func _progression() -> void:
	record.schema = "strata3-shader-cost-observation-v2"
	record.observer_source_revision = OS.get_environment("STRATA3_OBSERVER_SOURCE_REVISION")
	record.observer_sha256 = OS.get_environment("STRATA3_DRIVER_SHA256")
	_original_code = FileAccess.get_file_as_string("res://shaders/strata_optical_plane.gdshader")
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
			_active_profile = str(item[1])
			_desired_code = _original_code if item[2] == "original" else _candidate_code
			print("STRATA3_COST_PROBE ",_active_tag," ",_desired_code.sha256_text())
			var sample: Dictionary = await _progression_sample(str(item[1]),repeat_index)
			sample.variant = item[2]
			sample.case_id = item[0]
			sample.shader_sha256 = _probe_shader.code.sha256_text()
			sample.paused_capture = _active_capture.duplicate(true)
			sample.live_shader_binding_after = _live_binding()
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
	record.restored_shader_resources = []
	for shader: Shader in _touched_shaders:
		shader.code = _original_code
		record.restored_shader_resources.append({"shader_instance_id":str(shader.get_instance_id()),
			"shader_sha256":shader.code.sha256_text()})
	record.original_shader_restored = _touched_shaders.all(func(shader: Shader) -> bool: return shader.code.sha256_text() == _original_code.sha256_text())
	check(record.original_shader_restored and record.probe_samples.size() == 15,"all probe windows complete and original shader restored")
