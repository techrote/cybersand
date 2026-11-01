extends SceneTree

const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("Y1 envelope: " + message)

func sample(speed: float = 30.0, serial: int = 1) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(states,1,Vector2(104,93),0.0,Vector2(8,14),Vector2(0,speed),0.0,1.0,serial)
	return states

func controls() -> void:
	var magnitudes: Dictionary = {}
	for arm: String in ["B0","Y1"]:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		check(world.diagnostic_reset({"bearing_candidate":arm,"bearing_experiment":Fixture.TOKEN}),"fresh selector")
		check(world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(16,16),2),"support fill")
		world.prepare_rigid_body_coupling(sample())
		var row: Array = world.diagnostic_body_metrics()[0]
		magnitudes[arm] = -float(row[18])
		check(row[20].candidate == arm,"selector receipt")
		check(int(row[20].raw_support) == 8,"one support query per exposed boundary")
		check(int(row[20].boundaries) == 8,"one packed rectangle, no duplicate boundary")
		var before: String = world.get_physical_state_hash()
		for invalid: Dictionary in [{"bearing_candidate":"Y1"},{"bearing_experiment":Fixture.TOKEN},{"bearing_candidate":"A2","bearing_experiment":Fixture.TOKEN},{"bearing_candidate":1,"bearing_experiment":Fixture.TOKEN},{"bearing_candidate":"Y1","bearing_experiment":"wrong"}]:
			check(not world.diagnostic_reset(invalid),"invalid selector admitted")
			check(world.get_physical_state_hash() == before,"refusal replaced current authority")
		check(world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(8,16),0),"asymmetric excavation")
		world.prepare_rigid_body_coupling(sample(1,2))
		row = world.diagnostic_body_metrics()[0]
		check(int(row[20].left_support) == 0 and int(row[20].right_support) > 0,"asymmetric support census")
		check(world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(16,16),0),"full excavation")
		world.prepare_rigid_body_coupling(sample(1,3))
		row = world.diagnostic_body_metrics()[0]
		check(int(row[20].raw_support) == 0 and float(row[18]) == 0.0,"support release")
		check(float(world.rigid_body_results()[4]) == 0.0,"correction after release")
		for material: int in [1,3]:
			check(world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(16,16),material),"negative fill")
			world.prepare_rigid_body_coupling(sample(30,4+material))
			check(float(world.diagnostic_body_metrics()[0][18]) == 0.0,"hard/Water bearing")
		check(world.diagnostic_reset({}),"default reset")
		check(world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(16,16),2),"default support")
		world.prepare_rigid_body_coupling(sample())
		check(world.diagnostic_body_metrics()[0][20].candidate == "B0","default retained Y1")
		var with_hash: Dictionary = world.diagnostic_snapshot(Vector2i(96,90),Vector2i(16,30))
		var without_hash: Dictionary = world.diagnostic_snapshot(Vector2i(96,90),Vector2i(16,30),false,false)
		check(with_hash.has("hash") and not without_hash.has("hash"),"optional observation hash")
		with_hash.erase("hash")
		check(with_hash == without_hash,"hash omission changed copied observation")
	check(float(magnitudes.Y1) == 16.0 and float(magnitudes.B0) < 7.0,"capacity-limited Y1 or B0 law changed")
	print("Y1_ENVELOPE_CONTROLS ",JSON.stringify(magnitudes))

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: arguments[pair[0]] = pair[1]
	if not arguments.has("case"):
		controls()
		quit(1 if failed else 0)
		return
	var manifest_path: String = str(arguments.get("protocol",""))
	var protocol: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var spec: Dictionary = {}
	for value: Dictionary in protocol.cases:
		if value.id == arguments["case"]: spec = value
	check(not spec.is_empty(),"unknown registered case")
	var arm: String = str(arguments.get("candidate","B0"))
	var fixture = Fixture.new()
	var telemetry: bool = str(arguments.get("telemetry","on")) != "off"
	check(await fixture.setup(root,spec,arm,telemetry),"fixture setup")
	if failed:
		fixture.close()
		quit(1)
		return
	var rows: Array = []
	for _step: int in range(int(spec.ticks)):
		rows.append_array(fixture.step(telemetry))
		if not fixture.error.is_empty():
			check(false,fixture.error)
			break
	var final: Dictionary = fixture.observation()
	var report: Dictionary = {"schema":1,"ok":not failed,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"runtime":{"engine":FileAccess.get_sha256(OS.get_executable_path()),"native":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"rapier":FileAccess.get_sha256("res://addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if OS.get_name()=="Windows" else "res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")},
		"godot":Engine.get_version_info().string,"backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"platform":OS.get_name(),
		"protocol_sha256":FileAccess.get_sha256(manifest_path),"case":spec,"candidate":arm,"telemetry":telemetry,"rows":rows,"edits":fixture.edits,"final":final}
	var output: String = str(arguments.get("output",""))
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file != null,"output unavailable")
	if file != null:
		file.store_string(JSON.stringify(report))
		file.close()
	print("Y1_ENVELOPE_CAPTURE ",spec.id," ",arm," rows=",rows.size()," conserved=",fixture.conserved(final))
	fixture.close()
	await process_frame
	quit(1 if failed else 0)
