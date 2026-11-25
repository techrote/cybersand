extends SceneTree

# Untimed capability/readback preflight. An unsupported historical source is
# recorded as incomparable; it does not enter a gameplay performance trial.
const Profile = preload("res://tests/pubpres_playability_profile.gd")
const REQUIRED_READBACK := {
	"parameters":["deep_gain","floor_gain","flux_smoothing"],
	"spill":["deep_draw","sheet_rate","coyote_ticks","full_face"]}

func _initialize() -> void:
	var output := ""
	var mailbox_test := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="): output = arg.trim_prefix("--receipt=")
		if arg == "--mailbox-test": mailbox_test = true
	if output.is_empty():
		quit(2)
		return
	if mailbox_test:
		_test_mailbox_identity.call_deferred(output)
		return
	var available := ClassDB.class_exists(&"CyberNativeCellWorld")
	var profile_api := available and ClassDB.class_has_method(&"CyberNativeCellWorld",&"gameplay_water_options")
	var actual: Variant = ClassDB.class_call_static(&"CyberNativeCellWorld",&"gameplay_water_options") if profile_api else null
	var status: Dictionary = {}
	if available:
		var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		if world != null and world.has_method(&"get_wave_flow_status"):
			status = world.get_wave_flow_status()
	var missing: Array[String] = []
	for group: String in REQUIRED_READBACK:
		for key: String in REQUIRED_READBACK[group]:
			if not status.get(group,{}).has(key): missing.append(group+"."+key)
	var files := {}
	for path: String in ["res://tests/pubpres_playability_compatibility.gd","res://tests/pubpres_playability_profile.gd",
		"res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
		"res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"]:
		if FileAccess.file_exists(path): files[path] = FileAccess.get_sha256(path)
	var result := {"schema":"pubpres-playability-compatibility-v1","complete":available,
		"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"files":files,
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"profile":"gameplay_main846f",
		"profile_api_available":profile_api,"expected_options":Profile.GAMEPLAY_OPTIONS,"actual_options":actual,
		"required_readback":REQUIRED_READBACK,"unavailable_native_readback_fields":missing,
		"compatible":profile_api and actual == Profile.GAMEPLAY_OPTIONS and missing.is_empty(),
		"performance_capture_attempted":false,"scope":"Untimed native API and configuration readback. Unavailable fields fail closed; no substitute profile or invented zeroes."}
	var writer := FileAccess.open(output,FileAccess.WRITE)
	if writer == null:
		quit(2)
		return
	writer.store_string(JSON.stringify(result,"  ")+"\n")
	writer.close()
	quit(0 if available else 1)

func _test_mailbox_identity(output: String) -> void:
	# Invoke this source's real publication method. Fixture owner/clock values
	# are explicit; no simulation tick or graphical/performance claim is made.
	var worker: Variant = load("res://scripts/simulation_worker.gd").new()
	var source: Variant = load("res://scripts/simulation_snapshot.gd").new()
	var cases: Array[Dictionary] = []
	var passed := true
	var early: bool = worker.has_method("_publish_workbench_physics_snapshot")
	if early:
		worker._running = true
		worker._world_generation = 7
		worker._snapshot_serial = 41
		worker._physical_effect_epoch = 3
		worker._workbench_sample = {"epoch":3}
		worker._snapshot_hard_surface_revision = 11
		worker._workbench_completed_sample = -1
		source.rigid_body_epoch = 3
		source.physics_world_generation = 7
		source.render_world_generation = 901
		source.lab_context = {"workbench_hard_surface_revision":11}
		var packet: Variant = worker.call("_publish_workbench_physics_snapshot",source,0)
		if packet == null:
			passed = false
		else:
			var properties := Profile.snapshot_properties(packet)
			var observation := Profile.packet_observation(packet,properties)
			var bootstrap_ok: bool = packet == worker._published_physics_snapshot \
				and packet.render_world_generation == 0 and observation.world_generation == 7 \
				and observation.world_generation_field == "physics_world_generation" \
				and observation.native_completed_source_usec == -1 and observation.native_completed_usec == null \
				and observation.native_completion_world_generation == -1 and observation.native_completion_body_sample == -1 \
				and int(observation.physics_handoff_usec) > 0
			passed = passed and bootstrap_ok
			cases.append({"name":"actual_early_bootstrap","passed":bootstrap_ok,"observation":observation,
				"capabilities":Profile.snapshot_capabilities(properties),"source_render_generation":source.render_world_generation,
				"packet_render_bytes":packet.render_patch_cells.size()})
		worker._last_native_tick_world_generation = 7
		worker._last_native_tick_started_usec = 100
		worker._last_native_tick_completed_usec = 200
		worker._last_native_tick_body_sample = 2
		worker._workbench_completed_sample = 2
		source.tick_index = 1
		packet = worker.call("_publish_workbench_physics_snapshot",source,0)
		if packet == null:
			passed = false
		else:
			var properties := Profile.snapshot_properties(packet)
			var observation := Profile.packet_observation(packet,properties)
			var completed_ok: bool = packet == worker._published_physics_snapshot \
				and packet.render_world_generation == 0 and observation.world_generation == 7 \
				and observation.native_completed_usec == 200 and observation.native_completed_source_usec == 200 \
				and observation.native_completion_world_generation == 7 and observation.native_completion_body_sample == 2
			passed = passed and completed_ok
			cases.append({"name":"actual_early_completion","passed":completed_ok,"observation":observation})
			# A present but invalid physics owner must never fall back to render.
			var invalid_packet: Variant = load("res://scripts/simulation_snapshot.gd").new()
			invalid_packet.physics_world_generation = -1
			invalid_packet.render_world_generation = 901
			observation = Profile.packet_observation(invalid_packet,properties)
			var invalid_ok: bool = observation.world_generation == -1 and observation.world_generation_field == "physics_world_generation"
			passed = passed and invalid_ok
			cases.append({"name":"no_fallback_for_invalid_physics_owner","passed":invalid_ok,"observation":observation})
		worker._running = false
		worker._published_physics_snapshot = null
	else:
		source.render_world_generation = 7
		var properties := Profile.snapshot_properties(source)
		var observation := Profile.packet_observation(source,properties)
		var legacy_ok: bool = not properties.has("physics_world_generation") \
			and observation.world_generation == 7 and observation.world_generation_field == "render_world_generation" \
			and observation.native_completed_source_usec == null and observation.native_completed_usec == null
		passed = passed and legacy_ok
		cases.append({"name":"actual_legacy_snapshot_type","passed":legacy_ok,"observation":observation,
			"capabilities":Profile.snapshot_capabilities(properties)})
	var files := {}
	for path: String in ["res://scripts/simulation_worker.gd","res://scripts/simulation_snapshot.gd",
		"res://tests/pubpres_playability_compatibility.gd","res://tests/pubpres_playability_profile.gd",
		"res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
		"res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"]:
		if FileAccess.file_exists(path): files[path] = FileAccess.get_sha256(path)
	var result := {"schema":"pubpres-playability-mailbox-identity-v1","complete":passed,"cases":cases,
		"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"files":files,
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"early_mailbox_available":early,
		"scope":"Headless production GDScript publication seam with declared fixture identities/clocks. No simulation progression, graphical timing or physical acceptance."}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var writer := FileAccess.open(output,FileAccess.WRITE)
	if writer == null:
		quit(2)
		return
	writer.store_string(JSON.stringify(result,"  ")+"\n")
	writer.close()
	print("PUBPRES_MAILBOX_IDENTITY ",JSON.stringify({"complete":passed,"early_mailbox_available":early}))
	quit(0 if passed else 1)
