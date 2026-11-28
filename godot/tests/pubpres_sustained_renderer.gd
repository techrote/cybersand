extends "res://tests/pubpres_source_gameplay.gd"

## The original observer still delegates actual native and Rapier turns. This
## separate tape drives one ordinary mounted current-Wave Workbench for at least
## 65 wall seconds, including explicit native RG8 resyncs amid live editing.
const EXTENT := Vector2i(2048, 1024)
const MIN_SUSTAINED_USEC := 65000000
const MAX_SUSTAINED_USEC := 95000000
const PULSE_COUNT := 10
const PULSE_INTERVAL_USEC := 6000000
const SAMPLE_INTERVAL_USEC := 2000000
const LATE_USEC := 45000000

var pulses: Array[Dictionary] = []
var resident: Array[Dictionary] = []
var live_tape: Array[Dictionary] = []
var backend := ""
var initial_manual_steps := 0


func identity() -> Dictionary:
	var result := super.identity()
	result.files[get_script().resource_path] = FileAccess.get_sha256(get_script().resource_path)
	return result


func _run() -> void:
	await process_frame
	source_before = identity()
	if not check(DisplayServer.get_name() != "headless" and RenderingServer.is_on_render_thread(),
			"a real inline graphical renderer is required"):
		await _finish_sustained()
		return
	root.size = Vector2i(1280, 800)
	RenderingServer.call_on_render_thread(Callable(DisplayServer,"window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(ObservedMain)
	host = loaded
	root.add_child(host)
	if not check(await until(func() -> bool: return host.shared_workbench != null \
			and not host.shared_workbench.applied.is_empty()), "ordinary Workbench starts"):
		await _finish_sustained()
		return
	var ui: Control = host.shared_workbench
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy), EXTENT)
	setup.actors = [Setup.instance("needle",1,Vector2(230,228)), Setup.instance(Setup.BARREL,2,Vector2(312,218))]
	setup.next_id = 3
	setup.selected = 1
	setup.edits = [[0,992,2048,32,58],[0,0,24,1024,58],[2024,0,24,1024,58],
		[136,352,16,208,58],[336,352,16,208,58],[136,560,216,16,58],
		[152,370,72,146,3],[224,528,112,32,3]]
	fixture_identity = {"name":"ordinary_wave_sustained_2048x1024", "extent":[EXTENT.x,EXTENT.y],
		"setup_sha256":JSON.stringify(setup).sha256_text(), "workers":workers,
		"active_actor":"needle", "second_actor":"barrel", "capture_min_usec":MIN_SUSTAINED_USEC,
		"capture_max_usec":MAX_SUSTAINED_USEC, "resync_interval_usec":PULSE_INTERVAL_USEC}
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"ordinary Apply admits the authored Wave and actor setup") \
			or not check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
				and host._physical_epoch > epoch and host._physical_terrain_ready and host.physical_actor_session != null \
				and host.latest_snapshot != null \
				and host.last_uploaded_world_generation == host.latest_snapshot.render_world_generation \
				and host.last_uploaded_revision == host.latest_snapshot.world_revision),"native World, terrain and material ready"):
		await _finish_sustained()
		return
	ui._camera.select(1)
	ui.set_camera(1)
	ui._set_view(Vector2(92,94),Vector2i(480,270))
	await process_frame
	wave_before = water_identity()
	check_water_ledger(wave_before,"Initial")
	check(wave_before.policy.get("effective_water_solver","") == "wave_flow_v1" \
		and wave_before.wave_flow.get("healthy",false),"ordinary defaults installed healthy current Wave")
	selectors_before = effective_selectors()
	backend = selectors_before.material.backend
	check(backend in ["full","blit"],"known material publication backend")
	check(backend != "blit" or selectors_before.material.get("retirement_source") == "target", "blit retains target retirement")
	await capture("before")
	live_tape = TAPE.duplicate(true)
	live_tape.append({"tick":144,"move":[0.0,0.0]})
	host.common_tape = live_tape
	host.common_tick_zero = host.physical_actor_session.tick
	initial_manual_steps = host.rapier_bridge.manual_step_count()
	host.common_epoch = host.physical_actor_session.epoch
	host.common_generation = host.latest_snapshot.render_world_generation
	for item: Dictionary in host.latest_snapshot.get_property_list(): host.common_snapshot_properties[str(item.name)] = true
	host.simulation_worker.set_worker_participation_sampling(true)
	host.simulation_worker.call("begin_common_probe")
	host.common_active = true
	RenderingServer.frame_post_draw.connect(draw_observed)
	capture_start = Time.get_ticks_usec()
	check(ui.toggle_pause(),"ordinary Workbench Play starts sustained capture")
	while Time.get_ticks_usec()-capture_start < MAX_SUSTAINED_USEC:
		var elapsed: int = Time.get_ticks_usec()-capture_start
		if host.simulation_worker.has_failed() or not host.common_input_error.is_empty(): break
		if pulses.size() < PULSE_COUNT and elapsed >= (pulses.size()+1)*PULSE_INTERVAL_USEC:
			_pulse(ui,elapsed)
		if elapsed >= resident.size()*SAMPLE_INTERVAL_USEC: _resident(elapsed)
		if elapsed >= MIN_SUSTAINED_USEC and host.physical_actor_session.tick-host.common_tick_zero > TARGET_STEPS: break
		await process_frame
	capture_end = Time.get_ticks_usec()
	host.common_active = false
	check(capture_end-capture_start >= MIN_SUSTAINED_USEC and capture_end-capture_start <= MAX_SUSTAINED_USEC,
		"sustained wall capture completes within its declared window")
	check(pulses.size() == PULSE_COUNT and not pulses.any(func(row: Dictionary) -> bool: return not row.paint_admitted),
		"all native resync and live brush intervals were issued")
	check(host.common_tape_events.size() == live_tape.size() and not host.common_tape_events.any(func(row: Dictionary) -> bool:
		return row.requested_physical_tick != row.accepted_physical_tick), "all inputs including neutral at 144 hit their actual step")
	check(host.common_input_error.is_empty() and not host.simulation_worker.has_failed(),"native and actor ownership remain healthy")
	await _finish_sustained()


func _pulse(ui: Control, elapsed: int) -> void:
	var index: int = pulses.size()
	# A real brush operation and explicit native recovery request travel through
	# the existing owner queues. The render trace determines actual coverage.
	var point := Vector2i(362+index*4,322)
	var material: int = CyberCellWorld.FIRE if index%2 == 0 else CyberCellWorld.SMOKE
	var accepted: bool = host.queue_brush_mutation(point.x,point.y,9,material)
	host.simulation_worker.request_render_full_refresh()
	var follow: bool = index%2 == 0
	ui.zoom_by(1 if follow else -1)
	ui._camera.select(1 if follow else 0)
	ui.set_camera(1 if follow else 0)
	if not follow:
		ui._set_view(Vector2(108+index*5,142),host.current_view_size)
	pulses.append({"sequence":index,"elapsed_usec":elapsed,"render_serial_before":host.last_uploaded_render_snapshot_serial,
		"real_step_before":host.physical_actor_session.tick,"camera":"follow" if follow else "free",
		"cell":[point.x,point.y],"material":material,"paint_admitted":accepted})


func _resident(elapsed: int) -> void:
	var material: Dictionary = host.material_publication_status()
	var publisher: Variant = host._material_blit_publisher
	var rids: Array[int] = [host.texture.get_rid().get_id(),host.previous_texture.get_rid().get_id()]
	rids.sort()
	resident.append({"elapsed_usec":elapsed,"world_generation":host.last_uploaded_world_generation,
		"real_step":host.physical_actor_session.tick,"render_serial":host.last_uploaded_render_snapshot_serial,
		"camera_mode":host.shared_workbench._camera.selected,
		"view_size":[host.current_view_size.x,host.current_view_size.y],
		"texture_rids":rids,"publisher_rids":publisher.resource_identity() if publisher != null else [],
		"owned_gpu_logical_bytes":material.get("allocated_gpu_bytes",0),"backend":material.backend,
		"cached_publisher_cpu_bytes":material.get("retained_cpu_picture_bytes",0),
		"godot_static_bytes":OS.get_static_memory_usage(),"godot_static_peak_bytes":OS.get_static_memory_peak_usage(),
		"reported_video_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))})


func _finish_sustained() -> void:
	var transition_receipts: Array[Dictionary] = []
	var history := {}
	var final_water := {}
	var worker := {"events":[],"overflow":false}
	var actual_steps := 0
	var late_steps := 0
	if host != null and capture_start > 0:
		RenderingServer.frame_post_draw.disconnect(draw_observed)
		worker = host.simulation_worker.call("end_common_probe")
		check(not host.common_overflow and not worker.overflow,"bounded observer retained all events")
		var last_dense_serial := 0
		for row: Dictionary in host.common_events:
			if row.event == "rapier_step":
				actual_steps += 1
				if int(row.time_usec)-capture_start >= LATE_USEC: late_steps += 1
				check(int(row.step) == host.common_tick_zero+actual_steps and int(row.manual_steps) == initial_manual_steps+actual_steps \
					and absf(float(row.fixed_delta)-1.0/60.0) < 0.000000000001 and row.pending_hard_chunks == 0 \
					and row.required_hard_revision == row.installed_hard_revision and row.response_accepted,
					"actual completed step has exact feedback and installed terrain")
			elif row.event == "texture_upload":
				if row.full_refresh:
					last_dense_serial = int(row.render_serial)
				elif last_dense_serial > 0 and int(row.patch_bytes) < EXTENT.x*EXTENT.y*2:
					transition_receipts.append({"dense_serial":last_dense_serial,"sparse_serial":row.render_serial,
						"sparse_packet_bytes":row.patch_bytes,"publisher_history_copy":row.material.get("history_copy",false),
						"publisher_submitted_bytes":row.material.get("submitted_bytes",0),"elapsed_usec":int(row.time_usec)-capture_start})
					last_dense_serial = 0
		check(actual_steps >= TARGET_STEPS and late_steps >= 12,"actual physics advances beyond startup")
		check(transition_receipts.size() >= 6,"native publications make repeated accepted dense-to-sparse transitions")
		check(resident.size() >= 30 and resident.all(func(row: Dictionary) -> bool:
			return row.texture_rids.size() == 2 and row.texture_rids[0] != row.texture_rids[1] \
				and row.texture_rids == resident[0].texture_rids and row.publisher_rids == resident[0].publisher_rids \
				and row.owned_gpu_logical_bytes == resident[0].owned_gpu_logical_bytes and row.backend == backend \
				and row.world_generation == host.common_generation),"ordinary play retains a fixed material resource set in one World")
		check(resident.any(func(row: Dictionary) -> bool: return row.camera_mode == 0) \
			and resident.any(func(row: Dictionary) -> bool: return row.camera_mode == 1),"Free and Follow run during sustained capture")
		if not host.paused: check(host.shared_workbench.toggle_pause(),"ordinary Pause accepted after timing")
		check(await until(func() -> bool: return host.simulation_worker.paint_state().paused),"native pause acknowledged")
		final_water = water_identity()
		check_water_ledger(final_water,"Final")
		check(final_water.wave_flow.get("healthy",false) \
			and final_water.wave_flow.get("session_generation",-1) == wave_before.wave_flow.get("session_generation",-2) \
			and int(final_water.wave_flow.get("rounds",0)) > int(wave_before.wave_flow.get("rounds",0)),"same healthy Wave World completed native rounds")
		await capture("after")
		var current: Image = host.texture.get_image()
		var previous: Image = host.previous_texture.get_image()
		if current != null: current.convert(Image.FORMAT_RG8)
		if previous != null: previous.convert(Image.FORMAT_RG8)
		var current_ok: bool = current != null and current.get_data() == host.image.get_data()
		var previous_ok: bool = previous != null and previous.get_data() == host._presentation_previous_bytes
		history = {"current_matches":current_ok,"previous_matches":previous_ok,
			"current_sha256":hash_bytes(current.get_data()) if current != null else "",
			"previous_sha256":hash_bytes(previous.get_data()) if previous != null else ""}
		check(current_ok and previous_ok,"first GPU reads match both terminal CPU histories")
	check(source_before == identity(),"source and runtime remained fixed")
	var trace_path := output.trim_suffix(".json")+"-events.jsonl"
	var trace := FileAccess.open(trace_path,FileAccess.WRITE)
	if check(trace != null,"raw trace opens"):
		trace.store_line(JSON.stringify({"event":"identity","source":source_before,"fixture":fixture_identity}))
		if host != null:
			for row: Dictionary in host.common_events: trace.store_line(JSON.stringify(row))
		for row: Dictionary in worker.events: trace.store_line(JSON.stringify(row))
		trace.close()
	var receipt := FileAccess.open(output,FileAccess.WRITE)
	if check(receipt != null,"sustained receipt opens"):
		receipt.store_string(JSON.stringify({"schema":"pubpres-sustained-renderer-v1","complete":problems.is_empty(),
			"failures":problems,"source_identity":source_before,"fixture":fixture_identity,"process_id":OS.get_process_id(),
			"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
			"capture_start_usec":capture_start,"capture_end_usec":capture_end,"actual_rapier_steps":actual_steps,
			"late_rapier_steps":late_steps,"input_tape":live_tape,"pulses":pulses,"resident_samples":resident,
			"transition_receipts":transition_receipts,"gpu_history":history,"framebuffers":images,"water_before":wave_before,
			"water_after":final_water,"selectors_before":selectors_before,"trace_sha256":FileAccess.get_sha256(trace_path),
			"scope":"Mounted ordinary Workbench with explicit native resyncs. Frame intervals use callback delivery and logical texture/engine report bytes."},"\t")+"\n")
		receipt.close()
	print("PUBPRES_SUSTAINED_RESULT ",JSON.stringify({"complete":problems.is_empty(),"failures":problems,
		"steps":actual_steps,"late_steps":late_steps,"dense_to_sparse":transition_receipts.size()}))
	if host != null: host.queue_free()
	await process_frame
	await process_frame
	quit(int(not problems.is_empty()))
