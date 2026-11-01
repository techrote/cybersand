extends SceneTree

const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func fail(message: String) -> void:
	failed = true
	push_error("GCR qualification: " + message)

func arguments() -> Dictionary:
	var result: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: result[pair[0]] = pair[1]
	return result

func runtime_identity() -> Dictionary:
	return {"engine":FileAccess.get_sha256(OS.get_executable_path()),
		"native":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"rapier":FileAccess.get_sha256("res://addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if OS.get_name()=="Windows" else "res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")}

func _run() -> void:
	var args: Dictionary = arguments()
	var protocol_path: String = str(args.get("protocol",""))
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not protocol is Dictionary or not protocol.has("cases"):
		fail("registered protocol unavailable")
		quit(1)
		return
	var spec: Dictionary = {}
	for value: Dictionary in protocol.cases:
		if value.id == args.get("case",""): spec = value
	if spec.is_empty() or int(spec.get("ticks",0)) != 1800:
		fail("unknown case or duration differs from registration")
		quit(1)
		return
	var arm: String = str(args.get("candidate","Y1"))
	var fixture = Fixture.new()
	var telemetry: bool = str(args.get("telemetry","on")) != "off"
	if not await fixture.setup(root,spec,arm,telemetry):
		fail("fixture setup refused: " + fixture.error)
		fixture.close()
		quit(1)
		return
	var rows: Array = []
	var started: int = Time.get_ticks_usec()
	for _step: int in range(int(spec.ticks)):
		rows.append_array(fixture.step(telemetry))
		if not fixture.error.is_empty():
			fail(fixture.error)
			break
	var final: Dictionary = fixture.observation()
	var conservation: bool = fixture.conserved(final)
	for row: Dictionary in rows: conservation = conservation and bool(row.conserved)
	if not conservation: fail("exact closed-fixture material or Water quantity changed")
	var report: Dictionary = {"schema":1,"ok":not failed,"mode":"synchronous","experiment":Fixture.GCR_TOKEN,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"input_identity":OS.get_environment("CYBERSAND_INPUT_IDENTITY"),
		"runtime":runtime_identity(),"godot":Engine.get_version_info().string,
		"backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"platform":OS.get_name(),
		"protocol_sha256":FileAccess.get_sha256(protocol_path),"case":spec,"candidate":arm,"telemetry":telemetry,
		"elapsed_us":Time.get_ticks_usec()-started,"initial_poses":fixture.initial_poses,
		"rows":rows,"edits":fixture.edits,"final":final,"conserved":conservation}
	var file := FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if file == null: fail("output unavailable")
	else:
		file.store_string(JSON.stringify(report))
		file.close()
	print("GCR_CAPTURE ",spec.id," ",arm," rows=",rows.size()," conserved=",conservation)
	fixture.close()
	await process_frame
	quit(1 if failed else 0)
