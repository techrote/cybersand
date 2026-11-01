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
	ablation_value_regression()
	if args.has("ablation-unit-only"):
		quit(1 if failed else 0)
		return
	var protocol_path: String = str(args.get("protocol",ProjectSettings.globalize_path("res://../docs/audits/gcr001-2026-11-01/protocol.json")))
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not protocol is Dictionary or not protocol.has("cases"):
		fail("registered protocol unavailable")
		quit(1)
		return
	if not args.has("case"):
		await control_regression(protocol)
		quit(1 if failed else 0)
		return
	var spec: Dictionary = {}
	var registered: Array = protocol.cases.duplicate()
	registered.append_array(protocol.get("controls",[]))
	for value: Dictionary in registered:
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
	var report: Dictionary = {"schema":1,"ok":not failed,"mode":"synchronous","experiment":Fixture.ADMISSION_TOKEN if arm == "GCR-A1" else Fixture.GCR_TOKEN,
		"registration":str(protocol.get("registration","")),"granular_identity":fixture.runtime_identity(),
		"protocol_version":CyberRigidBodyCoupling.GCR_POLICY_VERSION if fixture.is_gcr() else 0,
		"abi":{"input_stride":CyberRigidBodyCoupling.GCR_INPUT_STRIDE if fixture.is_gcr() else CyberRigidBodyCoupling.INPUT_STRIDE,
			"result_stride":CyberRigidBodyCoupling.GCR_RESULT_STRIDE if fixture.is_gcr() else CyberRigidBodyCoupling.RESULT_STRIDE},
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"input_identity":OS.get_environment("CYBERSAND_INPUT_IDENTITY"),
		"runtime":runtime_identity(),"godot":Engine.get_version_info().string,
		"backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"platform":OS.get_name(),
		"protocol_sha256":FileAccess.get_sha256(protocol_path),"case":spec,"candidate":arm,"ablation":fixture.ablation_receipt(),"telemetry":telemetry,
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

func control_regression(protocol: Dictionary) -> void:
	var completed: int = 0
	for spec: Dictionary in protocol.get("controls",[]):
		for arm: String in ["Y1","GCR"]:
			var fixture = Fixture.new()
			if not await fixture.setup(root,spec,arm):
				fail("negative-control construction refused: "+str(spec.id)+" "+arm)
				fixture.close()
				return
			for _step: int in range(int(spec.ticks)):
				var rows: Array = fixture.step()
				if not fixture.error.is_empty():
					fail(fixture.error)
					break
				for row: Dictionary in rows:
					if not row.conserved: fail("negative-control quantity drift: "+str(spec.id))
					if arm == "GCR":
						var gcr: Dictionary = row.get("gcr",{})
						if gcr.is_empty(): fail("missing GCR negative-control ledger")
						for key: String in ["normal_accepted","tangent_accepted","passive_torque","event_budget_cost"]:
							if absf(float(gcr.get(key,0))) > 0.000001: fail("new granular response in "+str(spec.id)+": "+key)
			fixture.close()
			await process_frame
			completed += 1
	if completed != 6: fail("expected all three registered controls in both arms")
	print("GCR_NEGATIVE_CONTROLS completed=",completed," failed=",failed)

func ablation_value_regression() -> void:
	var fixture = Fixture.new()
	var input := PackedFloat64Array()
	input.resize(CyberRigidBodyCoupling.GCR_INPUT_STRIDE)
	for i: int in range(input.size()): input[i] = float(i+1)
	fixture.candidate = "GCR-MU0"
	var zero_mu: PackedFloat64Array = fixture.gcr_input_for_arm(input)
	for i: int in range(input.size()):
		if zero_mu[i] != (0.0 if i == CyberRigidBodyCoupling.GCR_INPUT_FRICTION else input[i]):
			fail("zero-mu ablation changed an unrelated field")
	if input[CyberRigidBodyCoupling.GCR_INPUT_FRICTION] == 0: fail("zero-mu mutated immutable input")
	var computed := PackedFloat64Array()
	computed.resize(CyberRigidBodyCoupling.GCR_RESULT_STRIDE)
	for i: int in range(computed.size()): computed[i] = float(i+1)
	fixture.candidate = "GCR-CENTRAL"
	var central: PackedFloat64Array = fixture.application_results(computed)
	for i: int in range(computed.size()):
		if central[i] != (0.0 if i == CyberRigidBodyCoupling.GCR_RESULT_ANGULAR_IMPULSE else computed[i]):
			fail("central ablation changed an unrelated field/session")
	if computed[CyberRigidBodyCoupling.GCR_RESULT_ANGULAR_IMPULSE] == 0: fail("central ablation mutated native result")
	fixture.candidate = "GCR"
	if fixture.gcr_input_for_arm(input) != input or fixture.application_results(computed) != computed:
		fail("full GCR arm changed the wire values")
	print("GCR_ABLATION_VALUES failed=",failed)
