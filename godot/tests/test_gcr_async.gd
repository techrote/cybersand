extends SceneTree

const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")

# This observer uses the production worker loop, immutable mailbox and ACK.
# Its fixture edits/observations run only on that exclusive native owner.
class Observer extends CyberSimulationWorker:
	var fixture: RefCounted
	var limit: int = 1800
	var trace: Array = []
	var recorded: int = -1
	var conservation: bool = true
	var capture_telemetry: bool = true

	func _activate_sampled_character(spawn_position: Vector2, _recovery: bool) -> void:
		_configure_sampled_character(spawn_position,false,false)

	func _publish_snapshot(step_ms: float, paused: bool, interval: int,
			force_full: bool = false, states: PackedFloat32Array = PackedFloat32Array(), epoch: int = 0) -> void:
		var tick: int = int(_world.get_tick_index())
		if tick != recorded and tick <= limit:
			var observation: Dictionary = fixture.observation()
			conservation = conservation and fixture.conserved(observation)
			var diagnostic_start: int = Time.get_ticks_usec()
			trace[tick] = {"tick":tick,"worker_step_ms":step_ms,"metrics":_world.diagnostic_body_metrics() if capture_telemetry else [],
				"scanned":_world.get_scanned_last_tick(),"moves":_world.get_moves_last_tick(),"active":_world.get_active_blocks_last_tick()}
			if fixture.is_gcr() and capture_telemetry: trace[tick]["gcr"] = fixture.json_value(_world.gcr_diagnostics())
			trace[tick]["diagnostic_copy_us"] = Time.get_ticks_usec()-diagnostic_start
			fixture.edit_at(tick)
			recorded = tick
		super._publish_snapshot(step_ms,paused,interval,force_full,states,epoch)
		if tick >= limit:
			_mutex.lock()
			_running = false
			_mutex.unlock()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not protocol is Dictionary or not str(args.get("case","")) in protocol.get("async_cases",[]):
		push_error("GCR async: unknown registered delayed-worker case")
		quit(1)
		return
	var spec: Dictionary = {}
	for value: Dictionary in protocol.cases:
		if value.id == args["case"]: spec = value
	var arm: String = str(args.get("candidate","Y1"))
	var fixture = Fixture.new()
	var telemetry: bool = str(args.get("telemetry","on")) != "off"
	if not await fixture.setup(root,spec,arm,telemetry):
		push_error("GCR async setup refused: " + fixture.error)
		fixture.close()
		quit(1)
		return
	var worker = Observer.new()
	worker._world = fixture.world
	worker.fixture = fixture
	worker.capture_telemetry = telemetry
	worker.trace.resize(int(spec.ticks)+1)
	worker.limit = int(spec.ticks)
	# Test-only transfer of the already constructed fixture authority. Calling
	# configure_granular_experiment here would reset away its cells and ledger.
	worker._gcr_experiment = fixture.is_gcr()
	worker.set_frame_state(0,false,false,Vector2i(fixture.left+fixture.width/2,Fixture.SURFACE),
		Vector2i(fixture.left-4,0),Vector2i(fixture.width+8,fixture.floor_y+4),0,0,true,true,true)
	if fixture.is_gcr(): worker.set_gcr_body_states(fixture.packed_boundary_states())
	else: worker.set_rigid_body_states(fixture.packed_boundary_states())
	if worker.start_worker(Vector2(fixture.left+16,Fixture.SURFACE-14)) != OK:
		push_error("GCR async worker start failed")
		fixture.close()
		quit(1)
		return
	var rows: Array = []
	var delivery: int = 0
	var failed: bool = false
	var deadline: int = Time.get_ticks_msec()+150000
	var snapshot: CyberSimulationSnapshot
	while true:
		await physics_frame
		snapshot = worker.take_latest_snapshot(-1)
		if snapshot.simulation_failed or Time.get_ticks_msec()>deadline:
			failed = true
			break
		delivery += 1
		# Hold every sixth physical delivery for one frame. The next mailbox
		# value remains immutable; native and Rapier clocks keep their own pace.
		if delivery % 6 != 0:
			if fixture.is_gcr(): fixture.bridge.apply_gcr_results(snapshot.serial,fixture.application_results(snapshot.gcr_body_results))
			else: fixture.bridge.apply_cellular_results(snapshot.serial,snapshot.rigid_body_results)
		var pose: Array = fixture.pose(0)
		var applications: PackedFloat64Array = fixture.bridge.diagnostic_applications
		var row: Dictionary = {"tick":snapshot.tick_index,"rapier_tick":fixture.bridge.manual_step_count(),
			"delivery":delivery,"held":delivery%6==0,"out":pose,"age":int(applications[0]),
			"vertical_depth":maxf(0.0,float(pose[1])+absf(cos(pose[2]))*fixture.body_size.y/2+absf(sin(pose[2]))*fixture.body_size.x/2-Fixture.SURFACE),
			"horizontal_depth":maxf(0.0,float(pose[0])+absf(cos(pose[2]))*fixture.body_size.x/2+absf(sin(pose[2]))*fixture.body_size.y/2-fixture.bank_x) if not is_nan(fixture.bank_x) else 0.0,
			"hard_floor_contact":float(pose[1])+absf(cos(pose[2]))*fixture.body_size.y/2+absf(sin(pose[2]))*fixture.body_size.x/2 >= fixture.floor_y-.5}
		if fixture.is_gcr():
			row["application"] = fixture.json_value(fixture.bridge.gcr_application_diagnostics())
			row["computed_result"] = Array(snapshot.gcr_body_results)
			row["result"] = Array(fixture.application_results(snapshot.gcr_body_results))
			row["ablation"] = fixture.ablation_receipt()
		rows.append(row)
		worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
		if snapshot.tick_index >= int(spec.ticks): break
		fixture.bridge.step()
		if fixture.is_gcr(): worker.set_gcr_body_states(fixture.packed_boundary_states())
		else: worker.set_rigid_body_states(fixture.packed_boundary_states())
	worker.stop_worker() # Only after join may main inspect native authority/trace.
	var final: Dictionary = fixture.observation()
	var conserved: bool = worker.conservation and fixture.conserved(final)
	failed = failed or not conserved
	for row: Dictionary in rows: row["conserved"] = conserved
	var report: Dictionary = {"schema":1,"ok":not failed,"mode":"desktop-asynchronous",
		"protocol_version":CyberRigidBodyCoupling.GCR_POLICY_VERSION if fixture.is_gcr() else 0,
		"abi":{"input_stride":CyberRigidBodyCoupling.GCR_INPUT_STRIDE if fixture.is_gcr() else CyberRigidBodyCoupling.INPUT_STRIDE,
			"result_stride":CyberRigidBodyCoupling.GCR_RESULT_STRIDE if fixture.is_gcr() else CyberRigidBodyCoupling.RESULT_STRIDE},
		"experiment":Fixture.GCR_TOKEN,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"input_identity":OS.get_environment("CYBERSAND_INPUT_IDENTITY"),
		"protocol_sha256":FileAccess.get_sha256(str(args.protocol)),"candidate":arm,"ablation":fixture.ablation_receipt(),"case":spec,
		"runtime":{"engine":FileAccess.get_sha256(OS.get_executable_path()),"native":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")},
		"rows":rows,"worker_trace":worker.trace,"completed_ticks":worker.recorded,
		"rapier_ticks":fixture.bridge.manual_step_count(),"conserved":conserved,"edits":fixture.edits,
		"final":final,"worker_overruns":snapshot.worker_overruns,"platform":OS.get_name()}
	var file := FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if file == null: failed = true
	else:
		file.store_string(JSON.stringify(report))
		file.close()
	fixture.close()
	await process_frame
	print("GCR_ASYNC ",spec.id," ",arm," native_ticks=",worker.recorded," conserved=",conserved)
	quit(1 if failed else 0)
