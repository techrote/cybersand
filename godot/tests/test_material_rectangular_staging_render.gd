extends "res://tests/test_material_tile_publication.gd"

# Focused real-GPU boundary/transfer gate. The explicit control flag is for
# running this same fixture against the recorded pre-128-class helper only.
# Production selection has no diagnostic bypass or new runtime setting.
func _run() -> void:
	check(DisplayServer.get_name() != "headless","rectangular staging requires graphical GPU readback")
	var control: bool = OS.get_environment("CYBERSAND_MATERIAL_RECTANGULAR_CONTROL") == "1"
	if DisplayServer.get_name() != "headless":
		check(_rectangular_staging_contract(not control) == true,"rectangular contract reached completion")
	check(observations.size() == (6 if control else 7),"every rectangular boundary emitted a GPU receipt")
	var report := {"godot":Engine.get_version_info(),"display":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"control":control,
		"assertions":assertions,"failures":failures,"observations":observations,
		"scope":"GPU history and bounded transfer sizes; measured wall-call scopes include waits/descheduling and exclude later readbacks. Not end-to-end gameplay or physical GPU acceptance."}
	var output: String = OS.get_environment("CYBERSAND_MATERIAL_RECTANGULAR_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
		check(file != null,"rectangular receipt opened")
		if file != null:
			report.assertions = assertions
			report.failures = failures
			file.store_string(JSON.stringify(report,"\t"))
	print("MATERIAL_RECTANGULAR_STAGING: %d assertions, %d failures"%[assertions,failures])
	quit(failures)
