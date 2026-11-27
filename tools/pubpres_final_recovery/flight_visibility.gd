extends "res://tests/pubpres_playability_owner_start.gd"

# Mount with the shipped owner_start.gd. Use the ordinary scene, Pilot, Follow,
# Play and input handlers; the private display supplies keyboard focus only.
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

const MEASURE_USEC := 20000000
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


func _exercise() -> void:
	var ui: Control = app.shared_workbench
	var session: Variant = app.physical_actor_session
	if not ui.pilot_instance(1) or not app.paused or not ui.toggle_pause():
		push_error("Ordinary pilot or Play refused")
		quit(3)
		return
	ui._camera.select(1)
	ui.set_camera(1)
	# Rearm normal keyboard handling with real neutral draws after Play.
	for neutral in range(3): await RenderingServer.frame_post_draw
	var slot: int = session.bridge.actor_body_index(session.slot_for_instance(1))
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
	while Time.get_ticks_usec()-began < MEASURE_USEC:
		var next_phase := int((Time.get_ticks_usec()-began)/2500000)%4
		if next_phase != phase:
			phase = next_phase
			_key(KEY_D,phase == 0)
			_key(KEY_W,phase == 1 or phase == 3)
			_key(KEY_A,phase == 2)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var pose: Transform2D = session.bridge.body_transform(slot)
		var frame: Dictionary = app.workbench_presentation_frame
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
		samples.append({"time_usec":now,"tick":session.tick,"position":[pose.origin.x,pose.origin.y],
			"visible":presented is Transform2D,"dry_if_hidden":dry,"reason":reason,"source":source,
			"upload":frame.get("upload_serial",-1),"cache_usec":frame.get("upload_cache_usec",-1),
			"resolve_usec":frame.get("resolve_usec",-1),"cells":guard.get("cells_examined",-1),
			"world":frame.get("world_generation",-1),"epoch":frame.get("epoch",-1)})
		prior = pose
	for code: Key in [KEY_A,KEY_D,KEY_W]: _key(code,false)
	var elapsed := Time.get_ticks_usec()-began
	var steps: int = session.tick-tick0
	ui.toggle_pause()
	var report := {"scene":scene_name,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"elapsed_usec":elapsed,"physical_steps":steps,"flight_seconds_per_wall_second":steps/60.0/(elapsed/1000000.0),
		"travel_cells":travel,"moved_draws":moved_draws,"sampled_draws":samples.size(),"hidden_draws":hidden,
		"conservatively_dry_hidden":dry_hidden,"invalid_frames":invalid_frames,"sources":source_counts,"reasons":reasons}
	print("WORKBENCH_FLIGHT_VISIBILITY ",JSON.stringify(report))
	report["samples"] = samples
	var out := FileAccess.open(receipt_path.get_base_dir().path_join("flight.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report))
	out.close()
	quit(0 if steps >= 12 and travel > 2.0 and moved_draws >= 6 and dry_hidden == 0 and invalid_frames == 0 else 1)
