extends SceneTree

# Call the ordinary public compiler. Timings are observations, never a test
# threshold or a native/physical progression counter.
func _initialize() -> void:
	var results := []
	for preset in range(3):
		var profile := CyberTransportProfiles.preset(preset)
		for repetition in range(6):
			var started := Time.get_ticks_usec()
			var value := CyberTransportProfiles.resolve(profile)
			var elapsed := Time.get_ticks_usec()-started
			if not value.get("ok",false): push_error(str(value));quit(1);return
			results.append({"preset":preset,"repetition":repetition,"elapsed_usec":elapsed,
				"hash":value.hash,"values":value.packed.size()})
	var report := {"schema":"pubpres-transport-resolution-cost-v1","results":results,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"script_sha256":FileAccess.get_sha256("res://scripts/transport_profiles.gd"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path())}
	var destination := OS.get_environment("CYBERSAND_TRANSPORT_COST_RECEIPT")
	if not destination.is_empty():
		var file := FileAccess.open(destination,FileAccess.WRITE)
		if file == null: quit(2);return
		file.store_string(JSON.stringify(report,"  ")+"\n")
		file.close()
	print("PUBPRES_TRANSPORT_RESOLUTION_COST "+JSON.stringify(report))
	quit()
