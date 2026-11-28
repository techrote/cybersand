extends "res://tests/pubpres_playability_owner_start.gd"

# Mount with the shipped owner_start.gd. Use the ordinary scene, Pilot, Follow,
# Play and input handlers; the private display supplies keyboard focus only.
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

const COMPARISON_SECONDS := 20
var underway := false
var samples: Array[Dictionary] = []


func _start() -> void:
	app = load("res://main.tscn").instantiate()
	app.set_script(FocusHost)
	root.add_child(app)
	deadline_msec = Time.get_ticks_msec()+240000
	process_frame.connect(_poll)


func _poll() -> void:
	super._poll()
	if not underway and FileAccess.file_exists(receipt_path):
		underway = true
		_exercise.call_deferred()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


# Independent conservative proof for an omitted dry flyer. Require both
# material bytes throughout a box enclosing the entire rigid sweep, not just
# the centre pixel. Only omitted frames pay for this diagnostic.
func _entirely_dry(start: Transform2D, finish: Transform2D, rects: Array, frame: Dictionary) -> bool:
	if not frame.get("valid",false) or app.image == null or rects.is_empty(): return false
	var radius := 0.0
	for shape: Dictionary in rects:
		radius = maxf(radius,(Vector2(shape.center).abs()+Vector2(shape.size)*0.5).length())
	var low: Vector2i = Vector2i((start.origin.min(finish.origin)-Vector2.ONE*(radius+1)).floor())
	var high: Vector2i = Vector2i((start.origin.max(finish.origin)+Vector2.ONE*(radius+1)).ceil())
	var area := Rect2i(low,high-low)
	if area.get_area() > 4096 or not Rect2i(Vector2i.ZERO,app.world_extent).encloses(area): return false
	var planes: Array[Image] = [app.image]
	if frame.get("previous_blend_active",false):
		if app._presentation_previous_unknown or app._presentation_previous_image == null: return false
		planes.append(app._presentation_previous_image)
	for plane: Image in planes:
		var region := plane.get_region(area)
		region.convert(Image.FORMAT_R8)
		if region.get_data().count(0) != area.get_area(): return false
	return true


# This readback is outside the timed interval. Capture a genuine moving draw
# while the ordinary joystick/keyboard path still owns the actor, then locate
# its actual fill colour inside a submitted polygon in that same framebuffer.
func _flight_pixels(slot: int) -> Dictionary:
	var overlay: Control = app.physical_actor_overlay
	var previous: Vector2 = app.physical_actor_session.bridge.body_transform(slot).origin
	_key(KEY_D,true)
	_key(KEY_W,true)
	var deadline := Time.get_ticks_msec()+5000
	var first_read := true
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var frame: Dictionary = app.workbench_presentation_frame
		var pose: Variant = frame.get("poses",{}).get(slot)
		if not pose is Transform2D or frame.get("sources",{}).get(slot) != "live": continue
		var moved := previous.distance_to(pose.origin)
		previous = pose.origin
		if moved <= 0.01 or not overlay.is_visible_in_tree(): continue
		var image: Image = root.get_texture().get_image()
		# Sample the actual PNG encoding. HDR get_pixel().g8 can round one code
		# higher than save_png's conversion of the same linear readback.
		image.convert(Image.FORMAT_RGBA8)
		var scale := Vector2(image.get_size())/root.get_visible_rect().size
		var hits: Array = []
		var diagnostic: Array = []
		for part: Dictionary in overlay._parts:
			if int(part.get("physical_body_index",part.get("water_body_index",-1))) != slot \
					or part.get("water_composed",false): continue
			var polygon: PackedVector2Array = overlay.polygon(part)
			for i: int in polygon.size(): polygon[i] = (overlay.get_global_transform_with_canvas()*polygon[i])*scale
			var box := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon: box = box.expand(point)
			var area := Rect2i(box.abs().grow(1)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			if area.get_area() > 10000: continue
			var fill: Color = Color(part.color).darkened(0.18)
			if first_read:
				var at := Vector2i(box.get_center())
				var rgb := image.get_pixelv(at) if Rect2i(Vector2i.ZERO,image.get_size()).has_point(at) else Color.BLACK
				diagnostic.append({"part":part.part_id,"polygon":str(polygon),"fill":fill.to_html(),"centre":rgb.to_html()})
			for y in range(area.position.y,area.end.y):
				for x in range(area.position.x,area.end.x):
					if not Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon): continue
					var rgb := image.get_pixel(x,y)
					if maxi(absi(rgb.r8-fill.r8),maxi(absi(rgb.g8-fill.g8),absi(rgb.b8-fill.b8))) <= 2:
						hits.append({"pixel":[x,y],"rgb":[rgb.r8,rgb.g8,rgb.b8],"part":part.part_id,
							"fill":[fill.r8,fill.g8,fill.b8]})
						if hits.size() >= 8: break
				if hits.size() >= 8: break
			if hits.size() >= 8: break
		if first_read and hits.size() < 2:
			var first_path := receipt_path.get_base_dir().path_join("unmatched-moving-draw.png")
			image.save_png(first_path)
			print("FLIGHT_FIRST_PIXEL_DRAW ",JSON.stringify({"expected":diagnostic,"pose":str(pose),
				"frame":frame.reasons[slot],"source":frame.sources[slot],"size":str(image.get_size())}))
			first_read = false
		if hits.size() < 2: continue
		var file := receipt_path.get_base_dir().path_join("moving-flyer.png")
		if image.save_png(file) != OK: return {}
		return {"samples":hits,"file":file.get_file(),"sha256":FileAccess.get_sha256(file),
			"pixels":[image.get_width(),image.get_height()],"world":frame.world_generation,
			"session":frame.session,"epoch":frame.epoch,"step":frame.selected_steps[slot],
			"upload":frame.upload_serial,"movement_cells":moved,"position":[pose.origin.x,pose.origin.y],
			"camera_origin":[frame.camera_origin.x,frame.camera_origin.y],"reason":frame.reasons[slot]}
	return {}


func _exercise() -> void:
	var ui: Control = app.shared_workbench
	var session: Variant = app.physical_actor_session
	var require_fire := OS.get_environment("CYBERSAND_FLIGHT_THRUSTER_FIRE") == "1"
	if require_fire:
		ui._fire.button_pressed = true
		if not ui.fire_enabled or not ui.applied.fire:
			push_error("Workbench Thruster fire control did not enable")
			quit(3)
			return
	if not ui.pilot_instance(1) or not app.paused or not ui.toggle_pause():
		push_error("Ordinary pilot or Play refused")
		quit(3)
		return
	ui._camera.select(1)
	ui.set_camera(1)
	# Rearm normal keyboard handling with real neutral draws after Play.
	for neutral in range(3): await RenderingServer.frame_post_draw
	var slot: int = session.bridge.actor_body_index(session.slot_for_instance(1))
	var pixels_requested := OS.get_environment("CYBERSAND_FLIGHT_FRAMEBUFFER") == "1"
	var pixels: Dictionary = await _flight_pixels(slot) if pixels_requested else {}
	if pixels_requested:
		for code: Key in [KEY_D,KEY_W]: _key(code,false)
		for neutral in range(2): await RenderingServer.frame_post_draw
	var start: Transform2D = session.bridge.body_transform(slot)
	var prior := start
	var last_visible := start
	var tick0: int = session.tick
	var began: int = Time.get_ticks_usec()
	var phase := -1
	var travel := 0.0
	var hidden := 0
	var dry_hidden := 0
	var invalid_frames := 0
	var moved_draws := 0
	var source_counts := {}
	var reasons := {}
	var seconds := COMPARISON_SECONDS
	if OS.get_environment("CYBERSAND_FLIGHT_SECONDS").is_valid_int():
		seconds = clampi(int(OS.get_environment("CYBERSAND_FLIGHT_SECONDS")),20,300)
	var patrol := seconds > COMPARISON_SECONDS
	var held := {}
	var airborne_draws := 0
	var last_nozzle_tick := {}
	var observed_fire_writes := 0
	var last_camera := Vector2.INF
	var camera_travel := 0.0
	var camera_moved_draws := 0
	while Time.get_ticks_usec()-began < seconds * 1000000:
		var next_phase := int((Time.get_ticks_usec()-began)/2500000)%4
		if patrol:
			# Fly a repeating course above the authored platform. Use only
			# ordinary keyboard edges; never set a pose or velocity.
			# Cross the camera's left clamp on each lap at the launcher's
			# ordinary zoom. A centred course near spawn can fly while the
			# entire 480-cell viewport stays pinned to the World boundary.
			var goal := start.origin + Vector2(110.0 if next_phase < 2 else -12.0, -8.0 if next_phase % 2 == 0 else -36.0)
			var lead: Vector2 = prior.origin + session.bridge.body_linear_velocity(slot) * 0.65
			# A/D turn the Needle; Q/E translate with its side jets and
			# C holds its authored upright assist. W counters gravity.
			var keys := {KEY_E:lead.x < goal.x-2, KEY_Q:lead.x > goal.x+2,
				KEY_W:lead.y > goal.y,KEY_C:true}
			for code: Key in keys:
				if held.get(code,false) != keys[code]: _key(code,keys[code])
			held = keys
		elif next_phase != phase:
			phase = next_phase
			_key(KEY_D,phase == 0)
			_key(KEY_W,phase == 1 or phase == 3)
			_key(KEY_A,phase == 2)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var pose: Transform2D = session.bridge.body_transform(slot)
		if pose.origin.y > 40 and pose.origin.y < start.origin.y + 20:
			airborne_draws += 1
		var frame: Dictionary = app.workbench_presentation_frame
		if require_fire:
			for nozzle: Dictionary in app.tower_context.get("workbench_emitters",[]):
				if nozzle.get("instance_id") == 1 and nozzle.get("epoch") == session.bridge._epoch \
						and nozzle.get("material") == 6 and int(nozzle.get("changed_cells",0)) > 0 \
						and nozzle.get("nozzle") in ["main-fire","side-fire"]:
					if int(nozzle.tick) > int(last_nozzle_tick.get(nozzle.nozzle,-1)):
						last_nozzle_tick[nozzle.nozzle] = nozzle.tick
						observed_fire_writes += 1
		var camera: Vector2 = frame.camera_origin
		if last_camera.is_finite():
			var pan := camera.distance_to(last_camera)
			camera_travel += pan
			if pan > 0.05: camera_moved_draws += 1
		last_camera = camera
		var presented: Variant = frame.get("poses",{}).get(slot)
		var source: String = str(frame.get("sources",{}).get(slot,"missing"))
		var reason: String = str(frame.get("reasons",{}).get(slot,frame.get("reason","missing")))
		source_counts[source] = int(source_counts.get(source,0))+1
		reasons[reason] = int(reasons.get(reason,0))+1
		var distance := prior.origin.distance_to(pose.origin)
		travel += distance
		if distance > 0.01: moved_draws += 1
		if not frame.get("valid",false): invalid_frames += 1
		var dry := false
		if presented is Transform2D:
			last_visible = presented
		else:
			hidden += 1
			dry = _entirely_dry(last_visible,pose,session.bridge._rects[slot],frame)
			if dry: dry_hidden += 1
		var guard: Dictionary = app.workbench_presentation_last
		samples.append({"time_usec":now,"tick":session.tick,"position":[pose.origin.x,pose.origin.y],"camera_xy":[camera.x,camera.y],
			"visible":presented is Transform2D,"dry_if_hidden":dry,"reason":reason,"source":source,
			"upload":frame.get("upload_serial",-1),"cache_usec":frame.get("upload_cache_usec",-1),
			"dry_region_status":frame.get("dry_region_status","unavailable"),"patch_count":frame.get("patch_count",-1),
			"resolve_usec":frame.get("resolve_usec",-1),"cells":guard.get("cells_examined",-1),
			"world":frame.get("world_generation",-1),"epoch":frame.get("epoch",-1)})
		prior = pose
	var elapsed := Time.get_ticks_usec()-began
	var steps: int = session.tick-tick0
	for code: Key in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_Q,KEY_E,KEY_C]: _key(code,false)
	var paused_step: int = session.tick
	var pause_ok: bool = ui.toggle_pause()
	var step_ok := true
	if patrol:
		for draw in range(8): await RenderingServer.frame_post_draw
		pause_ok = pause_ok and app.paused and session.tick == paused_step
		step_ok = ui.step_once()
		var timeout := Time.get_ticks_msec()+5000
		while ui.step_pending and Time.get_ticks_msec()<timeout:
			await RenderingServer.frame_post_draw
		for draw in range(4): await RenderingServer.frame_post_draw
		step_ok = step_ok and not ui.step_pending and session.tick == paused_step+1
	var report := {"scene":scene_name,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"thruster_fire":ui.fire_enabled,"observed_fire_writes":observed_fire_writes,
		"elapsed_usec":elapsed,"physical_steps":steps,"flight_seconds_per_wall_second":steps/60.0/(elapsed/1000000.0),
		"travel_cells":travel,"moved_draws":moved_draws,"camera_travel_cells":camera_travel,"camera_moved_draws":camera_moved_draws,
		"sampled_draws":samples.size(),"hidden_draws":hidden,
		"conservatively_dry_hidden":dry_hidden,"invalid_frames":invalid_frames,"sources":source_counts,"reasons":reasons,
		"native_tick":app.latest_snapshot.tick_index,"timed_start_usec":began,
		"held_callbacks_serviced":app.get("_serviced_flight_callbacks"),
		"coupling_only_completions":app.simulation_worker.take_latest_physics_snapshot().lab_context.get("coupling_only_completions",0),
		"airborne_draws":airborne_draws,"paused_ok":pause_ok,"manual_step_ok":step_ok,"patrol":patrol,"framebuffer_requested":pixels_requested,"moving_pixels":pixels}
	print("WORKBENCH_FLIGHT_VISIBILITY ",JSON.stringify(report))
	report["samples"] = samples
	var out := FileAccess.open(receipt_path.get_base_dir().path_join("flight.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report))
	out.close()
	quit(0 if steps >= 12 and travel > 2.0 and moved_draws >= 6 and dry_hidden == 0 and invalid_frames == 0
		and (not patrol or (hidden == 0 and camera_travel > 32.0 and camera_moved_draws > samples.size()*0.1
			and moved_draws > samples.size()*0.75 and airborne_draws > samples.size()*0.9))
		and (not require_fire or observed_fire_writes > 0)
		and pause_ok and step_ok and (not pixels_requested or not pixels.is_empty()) else 1)
