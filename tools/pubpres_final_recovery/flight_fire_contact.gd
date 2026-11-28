extends "res://tests/flight_visibility.gd"

# Mount this driver and flight_visibility.gd beside the shipped owner_start.gd.
# Keep the authored terrain and every other actor; the ordinary paused Move
# control brings the Needle within flying distance of the deep room's pool.
var nozzles := {}
var fire_writes := {}
var witnesses := {}
var source_counts := {}
var contact_draws := {"wall":0,"water":0}
var missing := {"dry":0,"wall":0,"water":0}
var fire_skin_draws := 0
var fire_hull_draws := 0
var hidden_fire_draws := 0
var trace: Array = []
var held := {}
var fire_requested := true
var rearming_after_pick := false
var previous_pose := Vector2.INF
var previous_live := Vector2.INF
var last_change_usec := 0
var last_change_step := -1
var live_at_change := Vector2.ZERO
var timing := {"repeat_while_moving":0,"stale_moving_draws":0,"worst_frozen_usec":0,
	"worst_frozen_travel_cells":0.0,"max_lag_cells":0.0,"max_draw_jump_cells":0.0,
	"max_excess_jump_cells":0.0,"catchups":0,"max_step_lag":0}


# Sample after real draws on the independent Rapier clock. Ordinary repeats
# between completions and stationary contact are valid. Two or more steps
# travelling beyond two cells behind a frozen draw constitute a moving stall.
func _chronology(shown: Variant, live: Vector2, step: int, selected: int, now: int) -> void:
	if not shown is Transform2D:
		previous_pose = Vector2.INF
	elif previous_pose.is_finite():
		var jump := previous_pose.distance_to(shown.origin)
		var physical_delta := previous_live.distance_to(live)
		var excess := jump-physical_delta
		timing.max_draw_jump_cells = maxf(timing.max_draw_jump_cells,jump)
		timing.max_excess_jump_cells = maxf(timing.max_excess_jump_cells,excess)
		if last_change_step >= 0 and jump <= 0.01:
			var drift := live_at_change.distance_to(live)
			if step > last_change_step and drift > 0.1:
				timing.repeat_while_moving += 1
				timing.worst_frozen_usec = maxi(timing.worst_frozen_usec,now-last_change_usec)
				timing.worst_frozen_travel_cells = maxf(timing.worst_frozen_travel_cells,drift)
				if step-last_change_step >= 2 and drift > 2.0:
					timing.stale_moving_draws += 1
		if jump > 0.01:
			if excess > 8.0 and previous_pose.distance_to(previous_live)>8.0: timing.catchups += 1
			last_change_step = -1
	if shown is Transform2D:
		if not previous_pose.is_finite() or last_change_step < 0:
			last_change_step = step
			last_change_usec = now
			live_at_change = live
		previous_pose = shown.origin
		timing.max_lag_cells = maxf(timing.max_lag_cells,shown.origin.distance_to(live))
		timing.max_step_lag = maxi(timing.max_step_lag,step-selected)
	previous_live = live


func _controls(states: Dictionary) -> void:
	for code: Key in states:
		if held.get(code,false) != states[code]: _key(code,states[code])
	held = states


func _emissions(session: Variant) -> void:
	for value: Variant in app.tower_context.get("workbench_emitters",[]):
		if not value is Dictionary or not value.has("nozzle"): continue
		var id := int(value.instance_id)
		var key := "%s/%d/%d/%d/%d/%s" % [session.run_id,value.epoch,id,value.sequence,value.tick,value.nozzle]
		if nozzles.has(key): continue
		nozzles[key] = value.duplicate(true)
		if id == 1 and value.epoch == session.epoch and value.nozzle in ["main-fire","side-fire"] \
				and value.material == 6 and value.changed_cells > 0:
			fire_writes[key] = value.duplicate(true)


func _wall(body: RigidBody2D) -> Dictionary:
	var direct := PhysicsServer2D.body_get_direct_state(body.get_rid())
	if direct != null:
		for i in direct.get_contact_count():
			var p := direct.get_contact_collider_position(i)
			if absf(p.x-16.0) < 2.0:
				return {"point":[p.x,p.y],"collider_rid":direct.get_contact_collider(i).get_id()}
	return {}


# Count uploaded material at cell centres inside the union or within one
# cell of its skin. Distance to the actual oriented rectangle excludes the
# diagonal corners of its expanded box. Never read the worker's live World.
func _skin(pose: Transform2D, rects: Array) -> Dictionary:
	var water := {}
	var fire := {}
	var hull := {}
	var nearest: Variant = null
	var distance := INF
	var inverse := pose.affine_inverse()
	for rect: Dictionary in rects:
		var shape: Vector2 = Vector2(rect.size)*0.5
		var half := shape+Vector2.ONE
		var centre: Vector2 = rect.center
		var box := Rect2(pose*(centre-half),Vector2.ZERO)
		for corner: Vector2 in [Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
			box = box.expand(pose*(centre+corner))
		var area := Rect2i(box.grow(1)).intersection(Rect2i(Vector2i.ZERO,app.world_extent))
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				var local := (inverse*Vector2(x+0.5,y+0.5)-centre).abs()
				var separation := (local-shape).max(Vector2.ZERO).length()
				if separation > 1.0: continue
				var at := Vector2i(x,y)
				var material: int = app.image.get_pixel(x,y).r8
				if material == 3: water[at] = true
				if material == 6:
					fire[at] = true
					if separation == 0: hull[at] = true
					if separation < distance:
						distance = separation
						nearest = at
	return {"water":water.size(),"fire_skin":fire.size(),"fire_hull":hull.size(),
		"nearest_fire":nearest,"distance":distance if nearest != null else -1.0}


func _contact_pixels(kind: String, slot: int, frame: Dictionary, movement: float, fire_cell: Variant = null) -> Dictionary:
	var pose: Transform2D = frame.poses[slot]
	var overlay: Control = app.physical_actor_overlay
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var scale := Vector2(image.get_size())/root.get_visible_rect().size
	var fire_pixel := Vector2.INF
	var fire_rgb: Array = []
	if fire_cell is Vector2i:
		var in_overlay: Vector2 = (Vector2(fire_cell)+Vector2(0.5,0.5)-overlay._origin)*overlay.size/overlay._view_size
		fire_pixel = (overlay.get_global_transform_with_canvas()*in_overlay)*scale
		if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(Vector2i(fire_pixel)): return {}
		var color := image.get_pixelv(Vector2i(fire_pixel))
		fire_rgb = [color.r8,color.g8,color.b8]
	for part: Dictionary in overlay._parts:
		if int(part.get("physical_body_index",part.get("water_body_index",-1))) != slot: continue
		var polygon: PackedVector2Array = overlay.polygon(part)
		for i in polygon.size(): polygon[i] = (overlay.get_global_transform_with_canvas()*polygon[i])*scale
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for p: Vector2 in polygon: bounds = bounds.expand(p)
		var area := Rect2i(bounds.grow(1)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		var fill := Color(part.color).darkened(0.18)
		var pixels: Array = []
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				if fire_pixel.is_finite() and fire_pixel.distance_to(Vector2(x+0.5,y+0.5)) > 6.0: continue
				if not Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon): continue
				var got := image.get_pixel(x,y)
				if maxi(absi(got.r8-fill.r8),maxi(absi(got.g8-fill.g8),absi(got.b8-fill.b8))) <= 2:
					pixels.append([x,y,got.r8,got.g8,got.b8])
					if pixels.size() >= 4: break
			if pixels.size() >= 4: break
		if pixels.size() < 2: continue
		var local: Vector2 = app._world_view_screen_transform().affine_inverse()*(frame.camera_mapping*pose.origin)
		var ui: Control = app.shared_workbench
		var cell: Vector2i = app.world_cell_from_local_point(local,true)
		var hit: Dictionary = ui.presented_part_at(Vector2(cell),2.0)
		var member: Dictionary = app.physical_actor_session.bridge._members[slot]
		if hit.get("member_id",-1) != member.instance_id or hit.get("member_generation",-1) != member.generation \
				or hit.get("epoch",-1) != frame.epoch or not ui.select_instance(0): continue
		rearming_after_pick = true
		ui._tool.select(2)
		var down := InputEventMouseButton.new()
		down.pressed = true
		down.button_index = MOUSE_BUTTON_LEFT
		down.position = local
		ui._world_input(down)
		down.pressed = false
		ui._world_input(down)
		if hit.get("instance_id",0) != 1 or ui.selected_id() != 1: continue
		var filename := kind+"-moving.png"
		var path := receipt_path.get_base_dir().path_join(filename)
		if image.save_png(path) != OK: return {}
		return {"file":filename,"sha256":FileAccess.get_sha256(path),"samples_xy_rgb":pixels,
			"fill_rgb":[fill.r8,fill.g8,fill.b8],"part":part.part_id,"pick":hit,"selected":ui.selected_id(),
			"pose":str(pose),"step":frame.selected_steps[slot],"upload":frame.upload_serial,
			"revision":frame.material_revision,"world":frame.world_generation,"session":frame.session,
			"epoch":frame.epoch,"camera":str(frame.camera_mapping),"movement_cells":movement,
			"fire_cell":fire_cell,"fire_pixel":Vector2i(fire_pixel) if fire_pixel.is_finite() else null,
			"fire_pixel_rgb":fire_rgb}
	return {}


func _exercise() -> void:
	var ui: Control = app.shared_workbench
	var old_epoch: int = app._physical_epoch
	var y0: int = app.world_extent.y-256
	ui._position[0].value = 42
	ui._position[1].value = y0
	if not app.paused or not ui.move_selected():
		push_error("Ordinary paused Move refused")
		quit(2)
		return
	var deadline := Time.get_ticks_msec()+50000
	while (app._physical_epoch == old_epoch or ui.busy() or not app._physical_terrain_ready) and Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
	var session: Variant = app.physical_actor_session
	if app._physical_epoch == old_epoch or ui.fire_enabled or not ui.pilot_instance(1):
		push_error("Placed owner / Pilot refused or Fire already on")
		quit(2)
		return
	fire_requested = OS.get_environment("CYBERSAND_CONTACT_FIRE") != "0"
	ui._fire.set_pressed(fire_requested)
	if ui.fire_enabled != fire_requested or ui.applied.fire != fire_requested or not ui.toggle_pause():
		push_error("Thruster fire toggle or Play refused")
		quit(2)
		return
	ui._camera.select(1)
	ui.set_camera(1)
	for i in 3: await RenderingServer.frame_post_draw
	var actor_slot: int = session.slot_for_instance(1)
	var slot: int = session.bridge.actor_body_index(actor_slot)
	var body: RigidBody2D = session._rigs[actor_slot].bodies()[0]
	var start_step: int = session.tick
	var initial: Transform2D = session.bridge.body_transform(slot)
	var previous_shown: Vector2 = initial.origin
	var first_wall := -1
	var first_water := -1
	var travel := 0.0
	var previous := initial.origin
	var draws := 0
	var key_steps := {}
	var time_start := Time.get_ticks_msec()
	deadline = time_start+180000
	while session.tick-start_step < 360 and Time.get_ticks_msec()<deadline:
		var elapsed: int = session.tick-start_step
		var at: Transform2D = session.bridge.body_transform(slot)
		var vel: Vector2 = session.bridge.body_linear_velocity(slot)
		var lead := at.origin+vel*0.32
		var west: bool = first_wall < 0 or elapsed-first_wall < 16
		var keys := {KEY_C:true,KEY_W:lead.y > y0 if west else (first_water >= 0 and elapsed-first_water > 18),
			KEY_E:elapsed < 8 or (not west and lead.x < 63),KEY_Q:west and elapsed >= 8 or (not west and lead.x > 75)}
		# The actual Select action deliberately cancels pilot input. Release
		# all keys until Main observes neutral, then resume the same course.
		if rearming_after_pick:
			keys = {KEY_C:false,KEY_W:false,KEY_E:false,KEY_Q:false}
			rearming_after_pick = app._actor_input_rearm
		_controls(keys)
		for code: Key in keys:
			if keys[code]: key_steps[OS.get_keycode_string(code)]=true
		await RenderingServer.frame_post_draw
		draws += 1
		_emissions(session)
		at = session.bridge.body_transform(slot)
		travel += at.origin.distance_to(previous)
		previous = at.origin
		var wall := _wall(body)
		var skin := _skin(at,session.bridge._rects[slot])
		var water := int(skin.water)
		var frame: Dictionary = app.workbench_presentation_frame
		var shown: Variant = frame.get("poses",{}).get(slot)
		var reason: String = str(frame.get("reasons",{}).get(slot,"missing"))
		var source: String = str(frame.get("sources",{}).get(slot,"missing"))
		var uploaded: bool = frame.get("material_revision",-1)==app.last_uploaded_revision \
				and frame.get("upload_serial",-1)==app.last_uploaded_render_snapshot_serial \
				and frame.get("world_generation",-1)==app.last_uploaded_world_generation
		var now := Time.get_ticks_usec()
		var selected := int(frame.get("selected_steps",{}).get(slot,-1))
		_chronology(shown,at.origin,session.tick,selected,now)
		source_counts[reason] = int(source_counts.get(reason,0))+1
		var kind := "water" if water > 0 else ("wall" if not wall.is_empty() else "dry")
		if not wall.is_empty():
			if first_wall < 0: first_wall = elapsed
			contact_draws.wall += 1
		if water > 0:
			if first_water < 0: first_water = elapsed
			contact_draws.water += 1
		if skin.fire_skin > 0:
			fire_skin_draws += 1
			if skin.fire_hull > 0: fire_hull_draws += 1
			if not shown is Transform2D: hidden_fire_draws += 1
		if shown is Transform2D:
			var distance := previous_shown.distance_to(shown.origin)
			previous_shown = shown.origin
			var shown_skin: Dictionary = skin if shown == at else _skin(shown,session.bridge._rects[slot])
			if kind != "dry" and source == "live" and distance > 0.01 and uploaded and not witnesses.has(kind) \
					and (kind != "water" or shown_skin.water > 0):
				var witness := _contact_pixels(kind,slot,frame,distance)
				if not witness.is_empty():
					witness.merge({"water_skin_cells":water,"shown_water_skin_cells":shown_skin.water,
						"rapier_wall":wall,"physical_step":session.tick,"physical_xy":[at.origin.x,at.origin.y]})
					witnesses[kind] = witness
			if skin.fire_skin > 0 and shown_skin.fire_skin > 0 and uploaded and source == "live" and distance > 0.01 and not witnesses.has("fire"):
				var fire := _contact_pixels("fire",slot,frame,distance,shown_skin.nearest_fire)
				if not fire.is_empty():
					fire.merge({"fire_cells":skin.fire_skin,"fire_hull_cells":skin.fire_hull,
						"skin_distance_cells":shown_skin.distance,"shown_fire_hull_cells":shown_skin.fire_hull,
						"physical_step":session.tick,"physical_xy":[at.origin.x,at.origin.y]})
					witnesses.fire = fire
		else:
			missing[kind] += 1
		var dependency: Dictionary = app._workbench_water_dependencies.get(slot,{})
		var member_id: int = session.bridge._members[slot].instance_id
		var entry: Dictionary = frame.original_mask_frame.get("instances",{}).get(member_id,{})
		trace.append([session.tick,at.origin.x,at.origin.y,water,wall,shown is Transform2D,source,reason,
			frame.upload_serial,now,selected,[shown.origin.x,shown.origin.y] if shown is Transform2D else null,
			frame.material_revision,frame.epoch,frame.world_generation,dependency.get("step",-1),
			dependency.get("sample",-1),entry.get("sample",-1),frame.water_proofs.get(slot,{}).get("kind",""),
			frame.get("contact_cells",{}).get(slot),frame.get("contact_clips",{}).has(slot),
			skin.fire_skin,skin.fire_hull,skin.nearest_fire,skin.distance,
			frame.get("upload_cache_usec",-1),app.workbench_presentation_last.get("cells_examined",-1),
			frame.get("resolve_usec",-1),frame.get("deadline_usec",0)-frame.get("draw_usec",0),ui.pilot_slot,
			frame.get("previous_blend_active",false),frame.get("current_texture_id",0),frame.get("previous_texture_id",0),
			app.last_uploaded_render_snapshot_serial,frame.get("contact_budget",{}).get(slot,{})])
		if elapsed%20 == 0 and (draws==1 or trace[-2][0]!=session.tick):
			print("FIRE_CONTACT_PROGRESS ",[elapsed,at.origin,source,reason,water,wall,fire_writes.size()])
		if first_wall >= 0 and first_water >= 0 and elapsed-maxi(first_wall,first_water)>35 \
				and witnesses.has("wall") and witnesses.has("water") and (not fire_requested or witnesses.has("fire")): break
	_controls({KEY_C:false,KEY_W:false,KEY_E:false,KEY_Q:false})
	var ok: bool = (not fire_writes.is_empty()) == fire_requested and key_steps.size()==4 \
			and witnesses.has("wall") and witnesses.has("water") and witnesses.has("fire") == fire_requested \
			and missing.wall==0 and missing.water==0 and missing.dry==0 and timing.stale_moving_draws==0 and timing.catchups==0
	var result := {"pass":ok,"scene":scene_name,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"root_member":session.bridge._members[slot],"logical_pilot":ui.pilot_id(),"fire":ui.fire_enabled,"keys":key_steps,
		"initial_position":str(initial.origin),"root_slot":slot,"draws":draws,"steps":session.tick-start_step,"travel_cells":travel,
		"first_wall_step":first_wall,"first_water_step":first_water,"contact_draws":contact_draws,"missing":missing,
		"elapsed_msec":Time.get_ticks_msec()-time_start,"reason_counts":source_counts,"emitters":nozzles,"fire_writes":fire_writes.size(),
		"witnesses":witnesses,"timing":timing,"fire_skin_draws":fire_skin_draws,"fire_hull_draws":fire_hull_draws,
		"hidden_fire_draws":hidden_fire_draws,"trace_columns":["step","x","y","water_skin_cells","rapier_wall",
			"presented","source","reason","upload","clock_usec","shown_step","shown_xy","revision","epoch","world",
			"completed_dependency_step","completed_dependency_sample","uploaded_member_sample","water_proof",
			"contact_cell","contact_clip","fire_skin_cells","fire_hull_cells","nearest_fire_cell","fire_distance",
			"upload_cache_usec","shared_cells_examined","resolve_usec","frame_budget_at_entry_usec","pilot_actor_slot",
			"previous_blend_active","current_texture_id","previous_texture_id","latest_uploaded_serial","member_budget"],
		"trace":trace}
	var out := FileAccess.open(receipt_path.get_base_dir().path_join("fire-contact.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(result))
	out.close()
	print("FIRE_CONTACT_RESULT ",[ok,scene_name,draws,session.tick-start_step,fire_writes.size(),contact_draws,missing])
	quit(0 if ok else 1)
