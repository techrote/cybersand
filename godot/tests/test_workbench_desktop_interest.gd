extends SceneTree

# Actual Main, worker and Rapier. Render reads use the uploaded owned image,
# never the mutable cellular World. The two test piles lie in separate regions.
const Setup = preload("res://scripts/workbench_setup.gd")
const DISTANT := Vector2i(1570,1350)
const NEAR := Vector2i(94,140)
var host
var panel
var report := {}
var failures := PackedStringArray()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, claim: String) -> bool:
	if not ok:
		failures.append(claim)
		push_error(claim)
	return ok

func wait_for(predicate: Callable, millis: int = 30000) -> bool:
	var end := Time.get_ticks_msec() + millis
	while Time.get_ticks_msec() < end:
		await process_frame
		if predicate.call(): return true
	return false

func cell(point: Vector2i) -> int:
	if host.image == null or host.image.get_size() != Vector2i(2048,2048): return -1
	return roundi(host.image.get_pixelv(point).r*255.0)

func edit_terrain_without_render(material: int) -> bool:
	# Main physics callbacks are driven explicitly so we can check every
	# advancing step during installation of the worker's changed terrain.
	const POINT := Vector2i(1150,730)
	var previous_revision: int = host.last_hard_surface_revision
	var previous_shapes: int = host.rapier_bridge.hard_surface_shape_count()
	var previous_step: int = host.rapier_bridge.manual_step_count()
	host.set_process(false)
	host.set_physics_process(false)
	var edited: bool = panel.paint(POINT,material) and await wait_for(func():
		var value: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
		return value != null and value.lab_context.get("workbench_hard_surface_revision",-1) > previous_revision)
	var advanced := false
	if edited and panel.toggle_pause():
		var deadline := Time.get_ticks_msec()+10000
		while not advanced and Time.get_ticks_msec()<deadline:
			host._physics_process(1.0/60.0)
			advanced = host.rapier_bridge.manual_step_count() > previous_step
			await process_frame
		panel.toggle_pause()
	var final: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
	var shapes: int = host.rapier_bridge.hard_surface_shape_count()
	var correct: bool = advanced and host.latest_snapshot.hard_surface_revision == previous_revision and final != null \
		and host.last_hard_surface_revision == final.lab_context.get("workbench_hard_surface_revision",-1) \
		and host.rapier_bridge.pending_hard_surface_chunks() == 0 \
		and (shapes > previous_shapes if material != 0 else shapes < previous_shapes)
	host.set_physics_process(true)
	host.set_process(true)
	return check(correct,"first Rapier step after terrain edit uses the installed current shapes with render held")

func finish() -> void:
	if host != null:
		report.worker_step_ms = host.latest_snapshot.worker_step_time_ms
		report.last_native_ms = host.latest_snapshot.simulation_time_ms
		report.native_tick = host.latest_snapshot.tick_index
		report.godot_peak_static_bytes = OS.get_static_memory_peak_usage()
		report.visited = host.latest_snapshot.scanned_last_tick
		report.active_blocks = host.latest_snapshot.active_blocks_last_tick
		report.status = panel.message if panel != null else "no panel"
		report.error = host.microscenario_error
		host.free()
	print("WORKBENCH_INTEREST ",JSON.stringify({"failures":Array(failures),"observations":report}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	panel = host.shared_workbench
	if not check(await wait_for(func(): return not panel.applied.is_empty()),"paused blank canvas failed to install"):
		finish()
		return
	check(host.paused and host.physical_actor_session == null and host.world_extent == Vector2i(2048,2048),"blank owner and extent")
	check(panel.step_once(),"blank owner step requested")
	check(await wait_for(func(): return not panel.step_pending and host.latest_snapshot.tick_index == 1),"empty worker step acknowledgement")
	panel.set_camera(2)
	var fit: Rect2 = host.view_content_rect()
	var pixel: Vector2i = host.view_pixel_from_local_point(fit.position + (Vector2(DISTANT)+Vector2(0.5,0.5))/2048.0*fit.size)
	check(pixel == DISTANT,"overview pointer must resolve to far cell")
	check(panel.paint(DISTANT,58),"actual distant hard paint")
	if not check(await wait_for(func(): return cell(DISTANT) == 58),"uploaded hard cell must survive beyond 1024"):
		finish()
		return
	var setup: Dictionary = panel.applied.duplicate(true)
	setup.actors = [Setup.instance("scooper",1,Vector2(1400,1250)),Setup.instance("needle",2,Vector2(88,110)),
		Setup.instance(Setup.BARREL,3,Vector2(1480,1250))]
	setup.actors[1].options.mass_multiplier = 2
	setup.actors[1].options.budget = 40
	setup.selected = 1
	setup.next_id = 4
	setup.source = [DISTANT.x-4,DISTANT.y-36,2]
	if not check(panel.apply(setup,true),"three-body owner requested") or not check(await wait_for(
		func(): return host.pending_microscenario_apply.is_empty() and host.physical_actor_session != null),"three-body adoption"):
		finish()
		return
	check(cell(DISTANT) == 58,"body replacement retains painted cell")
	check(await wait_for(func(): return host.tower_context.get("workbench_source",{}).get("armed",false)),"source armed on acknowledged installation")
	panel.set_camera(0)
	panel._set_view(Vector2.ZERO,Vector2i(240,135))
	check(panel.paint(NEAR,14),"near Dust insertion")
	check(await wait_for(func(): return cell(NEAR)==14),"near uploaded powder")
	var near_before: Vector2 = panel.body_state(2).position
	var far_before: Vector2 = panel.body_state(1).position
	host.simulation_worker.set_worker_participation_sampling(true)
	check(panel.toggle_pause() and panel.burst() and panel.stream(true),"start ordinary play, burst and stream")
	# Delay Main's render consumer without suspending its physics callbacks.
	# Freezing the render-side ack used to stall Rapier at the next sample.
	var retained_tick: int = host.latest_snapshot.tick_index
	var retained_render: int = host.last_uploaded_render_snapshot_serial
	host.set_process(false)
	var advanced := await wait_for(func():
		var latest: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
		return latest != null and latest.tick_index >= retained_tick+5 and host.physical_actor_session.tick >= 5)
	check(host.latest_snapshot.tick_index == retained_tick and host.last_uploaded_render_snapshot_serial == retained_render,
		"renderer retains its independent publication")
	host.set_process(true)
	if not check(advanced,"mixed physics consumes completed samples while render publication is held"):
		finish()
		return
	if not check(await wait_for(func(): return host.latest_snapshot.tick_index >= 14 and host.tower_context.workbench_source.inserted > 0),"both owners advance with camera away"):
		finish()
		return
	check(await wait_for(func():
		var sample: Dictionary = host.latest_snapshot.native_worker_participation
		return sample.get("native_tick_ms",0.0) > 0.0 and sample.get("completed_tick",0) > retained_tick),
		"sampled native duration is bound to a completed workbench tick")
	host.simulation_worker.set_worker_participation_sampling(false)
	check(panel.toggle_pause(),"pause")
	check(await wait_for(func(): return not host.tower_context.workbench_source.stream_enabled),"pause cancels active source")
	var stepped: int = host.latest_snapshot.tick_index
	check(panel.step_once(),"one Rapier + native step queued")
	check(await wait_for(func(): return not panel.step_pending and host.latest_snapshot.tick_index == stepped+1),
		"single-step on paused multi-body owner receives native completion")
	var rows: Array = host.tower_context.workbench_gcr.get("rows",[])
	check(rows.size()==3 and host.tower_context.workbench_gcr.get("response")=="LA-SELECTIVE","per-body response packet")
	check(panel.body_state(2).position.y > near_before.y and panel.body_state(1).position.y > far_before.y,"distant physical actors continue falling")
	var near_dust := false
	var far_sand := false
	for y: int in range(NEAR.y+1,NEAR.y+70):
		if cell(Vector2i(NEAR.x,y)) == 14: near_dust = true
	for y: int in range(DISTANT.y-35,DISTANT.y+70):
		for x: int in range(DISTANT.x-14,DISTANT.x+10):
			if cell(Vector2i(x,y)) == 2: far_sand = true
	check(near_dust and far_sand,"native material present at both separated coordinates")
	var stamp_count: int = panel.applied.edits.size()
	check(panel.paint(NEAR,14),"same authored stamp still reaches the live worker")
	check(await wait_for(func(): return cell(NEAR)==14),"repaint after powder moved")
	check(panel.applied.edits.size() == stamp_count,"repaint coalesces only the saved recipe")
	if not await edit_terrain_without_render(58) or not check(await wait_for(func(): return cell(Vector2i(1150,730)) == 58),"resume render after hard paint"):
		finish()
		return
	if not await edit_terrain_without_render(0) or not check(await wait_for(func(): return cell(Vector2i(1150,730)) == 0),"resume render after erasure"):
		finish()
		return
	report.near_actor = panel.body_state(2).position
	report.distant_actor = panel.body_state(1).position
	report.source = host.tower_context.workbench_source
	report.body_rows = rows
	report.camera = host.camera_origin
	var edge: Dictionary = panel.applied.duplicate(true)
	edge.actors[2].spawn = [1700.0,2040.5]
	edge.selected = 3
	check(panel.apply(edge,true,3),"prepare body at finite edge")
	if not check(await wait_for(func(): return host.pending_microscenario_apply.is_empty() and panel.selected_id()==3),"edge scene committed"):
		finish()
		return
	check(panel.toggle_pause(),"approach finite edge")
	check(await wait_for(func(): return host.paused and not host.tower_context.get("workbench_refusal","").is_empty()),
		"crossing unsimulated space stops both owners")
	report.edge_refusal = host.tower_context.get("workbench_refusal","")
	check(not panel.step_once() and not panel.step_pending, "edge refusal does not leave Step pending")
	var recovery: Dictionary = panel.applied.duplicate(true)
	recovery.actors[2].spawn = [1700.0,1800.0]
	check(panel.apply(recovery,true,3),"move out-of-region actor back into workspace")
	check(await wait_for(func(): return host.pending_microscenario_apply.is_empty() and host.tower_context.get("workbench_refusal","").is_empty()),
		"fresh epoch retires edge refusal")
	finish()
