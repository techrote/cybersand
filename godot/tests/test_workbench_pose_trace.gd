extends SceneTree

# Confirm the instrumentation sees the same Main presentation submission on
# an actual native World/Rapier Kestrel and does not change selected transforms.
const Trace = preload("res://scripts/workbench_pose_trace.gd")
const Camera = preload("res://scripts/pixel_camera_transform.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const LIMIT_MS: int = 90000
var checks: int = 0
var faults: Array[String] = []
var host: Control

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		faults.append(label)
		push_error("POSE_TRACE_001: "+label)
	return ok

func until(ready: Callable) -> bool:
	var end: int = Time.get_ticks_msec()+LIMIT_MS
	while Time.get_ticks_msec() < end:
		if ready.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func _pure_projection() -> void:
	var content := Rect2(Vector2(13,29),Vector2(960,540))
	var window := Transform2D(Vector2(1.25,0),Vector2(0,1.25),Vector2(43,61))
	var camera := Vector2(129.278,72.371)
	var size := Vector2i(320,180)
	var shader := Camera.presentation_screen_transform(camera,size,content,window)
	var snapped := Camera.screen_to_world(window*content.position,shader)
	var pose := Transform2D(0.37,Vector2(178.25,123.75))
	var proj: Variant = Trace.projection(pose,snapped,content,size,window,shader)
	check(proj is Dictionary and float(proj.residual_magnitude_px)<0.002,
		"overlay and shader projection agree despite fractional camera and window stretch")
	var wrong: Variant = Trace.projection(pose,snapped+Vector2(3,0),content,size,window,shader)
	check(wrong is Dictionary and float(wrong.residual_magnitude_px)>5.0,
		"projection residual detects a deliberately doubled/misapplied camera offset")
	var a := Trace.new()
	check(a.begin({"mode":"unit"}),"capture starts")
	a.observe({"process_frame":100,"bodies":[{"slot":0,"source":"mask_bound",
		"selected_screen":[100.0,100.0]}]})
	a.observe({"process_frame":101,"bodies":[{"slot":0,"source":"live",
		"selected_screen":[111.0,99.0]}]})
	a.observe({"process_frame":101,"bodies":[]})
	check(a.total_frames()==2 and a._duplicate_frames==1,
		"unique drawn-frame index and duplicate accounting")
	check(a._frames[1].bodies[0].source_changed and
		a._frames[1].bodies[0].screen_step_px==[11.0,-1.0],
		"source switching and apparent pixel jumps are recorded")
	var saved: Dictionary = a.finish()
	check(saved.status=="saved" and saved.frames==2 and saved.duplicates==1,
		"bounded JSON Lines export includes counts and duration")
	if saved.get("status","")=="saved":
		var file := FileAccess.open(str(saved.path),FileAccess.READ)
		var lines: Array[String] = []
		while not file.eof_reached():
			var line: String = file.get_line()
			if not line.is_empty(): lines.append(line)
		file.close()
		if lines.size()==4:
			var header: Dictionary = JSON.parse_string(lines[0])
			var first: Dictionary = JSON.parse_string(lines[1])
			var last: Dictionary = JSON.parse_string(lines[3])
			check(header.get("type","")=="header" and first.get("type","")=="frame"
				and last.get("type","")=="summary",
				"JSON Lines includes header, both frame records and footer")
		else:
			check(false,"JSON Lines must contain four lines")


func _run() -> void:
	_pure_projection()
	var existing_mode: String = OS.get_environment("CYBERSAND_DIAG_FLYER_POSE")
	var existing_presentation: String = OS.get_environment("CYBERSAND_DIAG_PRESENTATION")
	# Preserve the original tracer's live/mask source-transition control.
	# test_workbench_temporal_presentation owns the coherent timeline policy.
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy")
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	var ui: Control = host.shared_workbench
	if check(await until(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"actual native Workbench installed"):
		var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),
			Vector2i(512,512))
		setup.actors = [Setup.instance("kestrel",1,Vector2(240,360))]
		setup.next_id = 2
		setup.selected = 1
		setup.edits.append([260,345,5,1,58])
		var previous_epoch: int = host._physical_epoch
		var installed: bool = check(ui.apply(setup),
			"real authored World with real physical Kestrel requested")
		if installed:
			installed = check(await until(func() -> bool:
				return (host.pending_microscenario_apply.is_empty() and
					host._physical_epoch>previous_epoch and
					host.physical_actor_session!=null and host._physical_terrain_ready)),
				"physical native installation accepted")
		if installed:
			if check(await until(func() -> bool: return (host.image!=null and
					host.latest_snapshot!=null and
					host.last_uploaded_revision==host.latest_snapshot.world_revision and
					not host.workbench_display_frame().is_empty())),
					"uploaded texture and bound pose receipt ready"):
				host.set_process(false)
				host.set_physics_process(false)
				var bridge = host.physical_actor_session.bridge
				var bound_frame: Dictionary = host.workbench_display_frame().duplicate(true)
				var bound_pose: Transform2D = bound_frame.instances[1].pose
				var pixels: PackedByteArray = host.image.get_data()
				var tick: int = host.physical_actor_session.tick
				if host.paused: ui.toggle_pause()
				check(host.begin_workbench_pose_trace({"test":"actual-world"}),
					"host real overlay per-frame trace started")
				bridge.reset_body(0,bound_pose.origin+Vector2(0,1),
					bound_pose.get_rotation())
				host.snapshot_blend_start_usec = Time.get_ticks_usec()-1000000
				# Main's normal _process callback resolves workbench_display_frame()
				# before passing it here. Holding its exact valid receipt fixed
				# prevents asynchronous worker replacement from changing the
				# control variable between our two deliberately selected modes.
				check(host._valid_workbench_mask_frame(bound_frame),
					"real bound frame valid for uploaded material revision")
				await process_frame
				host._present_physical_actor_overlay(bound_frame)
				var first_parts: Array = host.physical_actor_overlay._parts
				if check(not first_parts.is_empty(),"real live overlay contains physical Kestrel"):
					var drawn_live: Transform2D = first_parts[0].transform
					check(drawn_live.origin.distance_to(bound_pose.origin+Vector2(0,1))<0.01,
						"overlay uses admitted cleared real Rapier pose")
				OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","mask")
				await process_frame
				host._present_physical_actor_overlay(bound_frame)
				var second_parts: Array = host.physical_actor_overlay._parts
				if check(not second_parts.is_empty(),"real mask-bound overlay contains physical Kestrel"):
					check(second_parts[0].transform.origin.distance_to(bound_pose.origin)<0.01,
						"mask baseline selects actual bound receipt")
				OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
				var tracer = host.workbench_pose_trace
				check(tracer.total_frames()==2,
					"each actual Main overlay frame recorded once, with no other polling")
				if tracer.total_frames()==2:
					var first: Dictionary = tracer._frames[0]
					var second: Dictionary = tracer._frames[1]
					check(first.bodies[0].source=="live" and
						second.bodies[0].source=="mask_bound" and
						second.bodies[0].source_changed,
						"real guard source transition captured (got %s then %s, reasons %s / %s)" %
						[first.bodies[0].source,second.bodies[0].source,
							first.bodies[0].guard_reason,second.bodies[0].guard_reason])
					var projection_a: Variant = first.bodies[0].get("screen_selected",null)
					var projection_b: Variant = second.bodies[0].get("screen_selected",null)
					check(projection_a is Dictionary and projection_b is Dictionary
						and float(projection_a.get("residual_magnitude_px",999.0))<0.01
						and float(projection_b.get("residual_magnitude_px",999.0))<0.01,
						"actual overlay and shader projection agree in both modes")
					check(first.mask_receipt_render_valid and second.mask_receipt_render_valid
						and first.uploaded_revision==second.uploaded_revision,
						"real native revision and frame identity retained across pose switch")
					check(first.camera_requested.size()==2 and
						first.camera_screen_phase_px.size()==2 and
						first.bodies[0].bound!=null and first.bodies[0].live!=null,
						"requested and presented cameras and both physical poses retained")
				var outcome: Dictionary = host.finish_workbench_pose_trace()
				check(outcome.status=="saved" and outcome.frames==2 and
					outcome.dropped==0,"real installed trace exported without dropped frames")
				check(host.image.get_data()==pixels and
					host.physical_actor_session.tick==tick,
					"trace and presentation operations preserve World bytes and Rapier tick")
				bridge.reset_body(0,bound_pose.origin,bound_pose.get_rotation())
	host.queue_free()
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE",existing_mode)
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION",existing_presentation)
	await process_frame
	await process_frame
	print("POSE_TRACE_RESULT ",JSON.stringify({"schema":"pose-trace-production-v1",
		"checks":checks,"failures":faults,"platform":OS.get_name(),
		"source":"actual Native World, actual Kestrel RID, actual Main overlay projection"}))
	quit(int(not faults.is_empty()))
