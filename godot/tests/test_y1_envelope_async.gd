extends SceneTree

const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
const Observer = preload("res://tests/support/y1_envelope_worker.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: arguments[pair[0]] = pair[1]
	if not arguments.has("case"):
		print("Y1 async acquisition requires an explicit registered case; ordinary async regression remains test_physics_async.gd")
		quit(0)
		return
	var protocol: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(arguments.protocol)))
	var registered: Dictionary = {}
	for value: Dictionary in protocol.async_cases:
		if value.id == arguments["case"]: registered = value
	var spec: Dictionary = {}
	for value: Dictionary in protocol.cases:
		if value.id == registered.get("base",""): spec = value
	if spec.is_empty():
		push_error("Unknown async registration")
		quit(1)
		return
	var arm: String = str(arguments.get("candidate","B0"))
	var fixture = Fixture.new()
	if not await fixture.setup(root,spec,arm):
		push_error("Async fixture setup failed")
		quit(1)
		return
	var worker = Observer.new()
	worker._world = fixture.world
	worker.limit = 1000
	worker.excavation = spec.layout == "excavate"
	worker.expected_arm = arm
	worker.bed_left = fixture.left
	worker.bed_width = fixture.width
	worker.bed_depth = int(spec.depth)
	worker.material = int(spec.material)
	worker.prepare_trace()
	worker.set_frame_state(0,false,false,Vector2i(fixture.left,192),Vector2i(fixture.left-4,0),Vector2i(fixture.width+8,fixture.floor_y+4),0,0,true,true,true)
	worker.set_rigid_body_states(fixture.bridge.pack_body_states())
	if worker.start_worker(Vector2(fixture.left+4,100)) != OK:
		push_error("Async owner failed to start")
		quit(1)
		return
	var rows: Array = []
	var failure: String = ""
	var deadline: int = Time.get_ticks_msec()+45000
	for frame: int in range(int(registered.frames)):
		await physics_frame
		if Time.get_ticks_msec() > deadline:
			failure = "async timeout"
			break
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		if snapshot.simulation_failed:
			failure = "failed World"
			break
		var applied: bool = frame % int(registered.consume_every) == 0
		if applied: fixture.bridge.apply_cellular_results(snapshot.serial,snapshot.rigid_body_results)
		var apps: Array = Array(fixture.bridge.diagnostic_applications) if applied else []
		rows.append({"frame":frame,"cell_tick":snapshot.tick_index,"snapshot_serial":snapshot.serial,"consumed":applied,
			"pose":fixture.pose(0),"apps":apps,"result":Array(snapshot.rigid_body_results) if applied else []})
		fixture.bridge.step()
		worker.set_rigid_body_states(fixture.bridge.pack_body_states()) # once per live main boundary
		worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
	worker.stop_worker()
	var trace: Array = []
	for tick: int in range(worker.recorded_tick+1):
		var offset: int = tick*Observer.STRIDE
		if worker.trace[offset+19] != 0: trace.append(Array(worker.trace.slice(offset,offset+Observer.STRIDE)))
	var report: Dictionary = {"schema":1,"ok":failure.is_empty(),"error":failure,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"case":registered,"base":spec,"candidate":arm,"rows":rows,"owner_trace":trace,"edits":worker.edit_count,"edit_receipt":worker.edit_receipt,"selector_failures":worker.selector_failures,
		"final":fixture.observation(),"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
		"platform":OS.get_name(),"engine":Engine.get_version_info().string,"backend":ProjectSettings.get_setting("physics/2d/physics_engine")}
	var file := FileAccess.open(str(arguments.output),FileAccess.WRITE)
	if file == null: failure = "output unavailable"
	else:
		file.store_string(JSON.stringify(report))
		file.close()
	fixture.close()
	await process_frame
	print("Y1_ASYNC_CAPTURE ",registered.id," ",arm," frames=",rows.size()," owner_ticks=",trace.size()," ",failure)
	if not failure.is_empty(): push_error(failure)
	quit(0 if failure.is_empty() else 1)
