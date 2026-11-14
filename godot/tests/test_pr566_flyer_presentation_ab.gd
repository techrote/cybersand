extends SceneTree

# PR566 presentation A/B: real Main, same native World, real Workbench Fire
# nozzle and manually stepped Rapier, *only* overlay pose source changes.
# Windows captures use real OpenGL/ANGLE RenderingServer, never fabricated frames.
const Setup = preload("res://scripts/workbench_setup.gd")
const WATCHDOG_MS: int = 120000
const SAMPLE_TICKS: int = 220
const FIRE_BEGIN: int = 40
const FIRE_END: int = 100

class PilotHost extends "res://scripts/main.gd":
	var pilot_action: Dictionary = {}
	var pilot_ports := {"q":false,"e":false,"s":false,"boost":false}

	func _publish_workbench_keyboard() -> void:
		if pilot_action.is_empty() or paused or shared_workbench == null or physical_actor_session == null:
			return
		physical_actor_session.submit_workbench_action(shared_workbench.selected_id(),
			pilot_action,pilot_ports,shared_workbench.fire_enabled)

var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var emitter_events: Array[Dictionary] = []
var emitter_seen: Dictionary = {}
var actual_fire_inserts: int = 0
var valid_native_frames: int = 0
var trial: String = "nofire"
var pose_mode: String = "mask"
var camera_mode: String = "free"
var capture_dir: String = ""
var frames: Array[Dictionary] = []
var actual_captures: int = 0
var matched_mask_samples: int = 0
var nonzero_pose_gap_samples: int = 0
var max_pose_gap: float = 0.0
var max_live_mask_xor: int = 0


func _initialize() -> void:
	_run.call_deferred()


func verify(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("PR566_RECOIL: " + reason)
	return ok


func _xy(value: Variant) -> Array:
	if value is Vector2:
		return [float(value.x),float(value.y)]
	return [0.0,0.0]


func _wait_for(predicate: Callable, timeout_ms: int = WATCHDOG_MS) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return false


func _read_emitters() -> void:
	for item: Variant in host.tower_context.get("workbench_emitters",[]):
		if not item is Dictionary or not item.has("nozzle"): continue
		var receipt: Dictionary = item
		var key: String = "%d/%d/%d/%s" % [
			int(receipt.get("epoch",-1)),int(receipt.get("sequence",-1)),
			int(receipt.get("tick",-1)),str(receipt.get("nozzle",""))]
		if emitter_seen.has(key): continue
		emitter_seen[key] = true
		var event := {"key":key,"nozzle":str(receipt.nozzle),
			"tick":int(receipt.get("tick",-1)),
			"material":int(receipt.get("material",-1)),
			"changed_cells":int(receipt.get("changed_cells",0)),
			"reason":str(receipt.get("reason",""))}
		emitter_events.append(event)
		if event.material == 6 and event.changed_cells > 0:
			actual_fire_inserts += 1


func _measure(relative_tick: int) -> Dictionary:
	var state: Dictionary = host.physical_actor_session.workbench_actor_state(1)
	var gcr: Dictionary = host.tower_context.get("workbench_gcr",{})
	var body_row: Dictionary = {}
	for item: Variant in gcr.get("rows",[]):
		if item is Dictionary and int(item.get("instance_id",-1)) == 1:
			body_row = item
			break
	if not body_row.is_empty() and bool(gcr.get("valid",false)):
		valid_native_frames += 1
	var accepted: Dictionary = {}
	var application: Dictionary = host.physical_actor_session.bridge.last_application
	for item: Variant in application.get("bodies",[]):
		if item is Dictionary and int(item.get("instance_id",-1)) == 1:
			accepted = item
			break
	var display_frame: Dictionary = host.workbench_display_frame()
	var shown: Dictionary = display_frame.get("instances",{}).get(1,{})
	var pose: Variant = shown.get("pose")
	var live_pose: Transform2D = host.physical_actor_session.bridge.body_transform(
		host.physical_actor_session.slot_for_instance(1))
	var gap: float = pose.origin.distance_to(live_pose.origin) if pose is Transform2D else 0.0
	max_pose_gap = maxf(max_pose_gap,gap)
	if gap > 0.01: nonzero_pose_gap_samples += 1
	if pose is Transform2D and display_frame.get("revision",-1) == host.last_uploaded_revision:
		matched_mask_samples += 1
	var draw_parts: Array = host.physical_actor_overlay._parts
	var drawn: Vector2 = (draw_parts[0].transform.origin
		if not draw_parts.is_empty() else Vector2.INF)
	var controller: Dictionary = state.get("controller",{})
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	return {
		"tick":relative_tick,
		"rapier_tick":host.physical_actor_session.tick,
		"timestamp_usec":Time.get_ticks_usec(),
		"fire_requested":ui.fire_enabled,
		"position":_xy(state.get("position",Vector2.ZERO)),
		"velocity":_xy(state.get("linear_velocity",Vector2.ZERO)),
		"rotation":float(state.get("rotation",0.0)),
		"angular_velocity":float(state.get("angular_velocity",0.0)),
		"controller_force":_xy(controller.get("applied_force",Vector2.ZERO)),
		"controller_thrust":float(controller.get("thrust",0.0)),
		"native_valid":bool(gcr.get("valid",false)),
		"native_sample":int(body_row.get("sample",-1)),
		"native_contacts":int(body_row.get("contacts",0)),
		"native_unresolved":int(body_row.get("unresolved",0)),
		"native_displaced":int(body_row.get("displaced",0)),
		"native_impulse":_xy(body_row.get("impulse",Vector2.ZERO)),
		"native_exhaust_fire_unresolved":int(body_row.get("diag_exhaust_unresolved_fire",-1)),
		"native_exhaust_smoke_unresolved":int(body_row.get("diag_exhaust_unresolved_smoke",-1)),
		"native_exhaust_unresolved_raw_impulse":_xy(body_row.get(
			"diag_exhaust_unresolved_raw_impulse",Vector2.ZERO)),
		"native_exhaust_recoil_suppressed":false,
		"application_sample":int(accepted.get("sample",-1)),
		"application_refusal":str(accepted.get("refusal","")),
		"applied_impulse":_xy(accepted.get("impulse",Vector2.ZERO)),
		"applied_torque":float(accepted.get("torque",0.0)),
		"camera_origin":_xy(host.presentation_camera_origin()),
		"display_frame_sample":int(shown.get("sample",-1)),
		"display_position":_xy(pose.origin if pose is Transform2D else Vector2.INF),
		"display_pose_revision":int(display_frame.get("revision",-1)),
		"live_position":_xy(live_pose.origin),
		"drawn_position":_xy(drawn),
		"mask_to_live_pose_gap":gap,
		"pose_mode":pose_mode,
		"camera_mode":camera_mode,
		"world_revision":int(snapshot.world_revision) if snapshot != null else -1,
		"uploaded_revision":int(host.last_uploaded_revision),
		"render_serial":int(host.last_uploaded_render_snapshot_serial),
		"render_hz_actual":float(host.measured_render_publication_hz)
	}


func _run() -> void:
	trial = OS.get_environment("CYBERSAND_RECOIL_TRIAL")
	if trial.is_empty(): trial = "nofire"
	pose_mode = OS.get_environment("CYBERSAND_DIAG_FLYER_POSE")
	camera_mode = OS.get_environment("CYBERSAND_POSE_AB_CAMERA")
	capture_dir = OS.get_environment("CYBERSAND_POSE_AB_CAPTURE_DIR")
	if pose_mode.is_empty(): pose_mode = "mask"
	if camera_mode.is_empty(): camera_mode = "free"
	if not verify(pose_mode in ["mask","live"] and camera_mode in ["free","follow"]
			and trial in ["nofire","fire"],"valid pose, camera and nozzle variant"):
		quit(1)
		return
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(PilotHost)
	root.add_child(host)
	ui = host.shared_workbench
	if verify(await _wait_for(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"default Workbench installed"):
		var config: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
		config.actors = [Setup.instance("kestrel",1,Vector2(240,360))]
		config.next_id = 2
		config.selected = 1
		config.fire = false
		if not host.paused: ui.toggle_pause()
		var old_epoch: int = host._physical_epoch
		if verify(ui.apply(config),"isolated clean native/Rapier flight prepared"):
			if verify(await _wait_for(func() -> bool:
					return host.pending_microscenario_apply.is_empty() and host._physical_epoch > old_epoch and host.physical_actor_session != null and host._physical_terrain_ready),
					"isolated native/Rapier World installed"):
				host.current_view_size = Vector2i(320,270)
				ui._camera.select(1 if camera_mode == "follow" else 0)
				if camera_mode == "follow":
					ui.focus_selected()
				else:
					ui._set_view(Vector2(125,105),Vector2i(320,270))
				host.pilot_action = {"move":Vector2(0.0,-0.6),"trim":0.32,
					"primary":false,"effort":1.0}
				verify(ui.toggle_pause(),"begin actual 60Hz Rapier flight")
				var starting_tick: int = host.physical_actor_session.tick
				var last_seen: int = -1
				var capture_targets: Array[int] = [45,60,75,90,110,135,165,195]
				var next_capture: int = 0
				var deadline: int = Time.get_ticks_msec() + WATCHDOG_MS
				while host.physical_actor_session.tick - starting_tick < SAMPLE_TICKS and \
						Time.get_ticks_msec() < deadline and not host.simulation_worker.has_failed():
					await process_frame
					var elapsed: int = host.physical_actor_session.tick - starting_tick
					if elapsed == last_seen: continue
					last_seen = elapsed
					var should_fire: bool = trial == "fire" and elapsed >= FIRE_BEGIN and elapsed < FIRE_END
					if ui.fire_enabled != should_fire:
						ui._fire.set_pressed(should_fire)
					_read_emitters()
					var record: Dictionary = _measure(elapsed)
					observations.append(record)
					# A real GPU readback can skip simulation ticks. Trigger on the
					# first observed tick at/after each requested capture threshold.
					if not capture_dir.is_empty() and next_capture < capture_targets.size() \
							and elapsed >= capture_targets[next_capture]:
						var target_tick: int = capture_targets[next_capture]
						next_capture += 1
						await _capture(target_tick,record)
					if elapsed % 30 == 0:
						print("PR566_RECOIL_SAMPLE ",JSON.stringify(record))
				host.pilot_action.clear()
				if ui.fire_enabled: ui._fire.set_pressed(false)
				var terminal: Dictionary = host.physical_actor_session.workbench_actor_state(1)
				print("PR566_RECOIL_TERMINAL ",JSON.stringify({
					"tick":last_seen,
					"worker_failed":host.simulation_worker.has_failed(),
					"host_paused":host.paused,
					"actor_position":_xy(terminal.get("position",Vector2.ZERO)),
					"actor_velocity":_xy(terminal.get("linear_velocity",Vector2.ZERO)),
					"native_error":str(host.latest_snapshot.last_tick_error)
						if host.latest_snapshot != null else "no_snapshot"
				}))
				verify(last_seen >= SAMPLE_TICKS,"completed controlled 220-tick real Rapier flight")
				verify(valid_native_frames > 12,"native response telemetry was actually published")
				if trial == "fire":
					verify(actual_fire_inserts > 0,"real Fire emitted by the Workbench nozzle")
				else:
					verify(actual_fire_inserts == 0,"no-Fire control emitted no Fire")
				verify(matched_mask_samples > 20,"rendered mask-pose revision tied to uploaded material")
				if not capture_dir.is_empty():
					verify(actual_captures >= 6,"actual graphical frames captured")
				verify(not observations.is_empty(),"Rapier and presentation observations exist")
	host.queue_free()
	await process_frame
	await process_frame
	var report := {
		"case":"PR566_REAL_RAPIER_EXHAUST_RECOIL",
		"source_parent":"214de85adef2aaabc8e26de8612a3bf27cc1a081",
		"trial":trial,"pose_mode":pose_mode,"camera_mode":camera_mode,
		"render_driver":RenderingServer.get_current_rendering_method(),
		"display_server":DisplayServer.get_name(),
		"source_sha":"214de85adef2aaabc8e26de8612a3bf27cc1a081",
		"godot":Engine.get_version_info().string,
		"os":OS.get_name(),"checks":checks,"failures":failures,
		"fire_begin_tick":FIRE_BEGIN,"fire_end_tick":FIRE_END,
		"intended_steps":SAMPLE_TICKS,
		"native_frames":valid_native_frames,
		"actual_fire_inserts":actual_fire_inserts,
		"matched_mask_samples":matched_mask_samples,
		"nonzero_pose_gap_samples":nonzero_pose_gap_samples,
		"max_pose_gap":max_pose_gap,
		"max_live_mask_xor":max_live_mask_xor,
		"frame_captures":frames,
		"emitters":emitter_events,"samples":observations
	}
	var output: String = OS.get_environment("CYBERSAND_RECOIL_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		verify(file != null,"diagnostic report open")
		if file != null:
			file.store_string(JSON.stringify(report,"  "))
			file.flush()
			file.close()
	print("PR566_RECOIL_END ",JSON.stringify({
		"trial":trial,"pose_mode":pose_mode,"camera_mode":camera_mode,
		"fire_inserts":actual_fire_inserts,"captures":actual_captures,
		"max_mask_to_live_gap":max_pose_gap,"samples":observations.size(),
		"native_frames":valid_native_frames,"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))


# The upload-bound display pose is an immutable World-mask witness. Compare
# its actual collider footprint against the diagnostic live-Rapier footprint;
# these are *geometry estimates*, not an independent native-mask byte readback.
func _inside_body(cell: Vector2, pose: Transform2D, rectangles: Array) -> bool:
	var local: Vector2 = pose.affine_inverse() * cell
	for item: Dictionary in rectangles:
		if Rect2(item.center-Vector2(item.size)*0.5,Vector2(item.size)).has_point(local):
			return true
	return false


func _mask_geometry_delta(mask_pose: Transform2D, live_pose: Transform2D) -> Dictionary:
	var slot: int = host.physical_actor_session.slot_for_instance(1)
	var rectangles: Array = host.physical_actor_session.bridge._rects[slot]
	var x_min: int = maxi(0,floori(minf(mask_pose.origin.x,live_pose.origin.x))-50)
	var x_max: int = mini(host.world_extent.x-1,ceili(maxf(mask_pose.origin.x,live_pose.origin.x))+50)
	var y_min: int = maxi(0,floori(minf(mask_pose.origin.y,live_pose.origin.y))-50)
	var y_max: int = mini(host.world_extent.y-1,ceili(maxf(mask_pose.origin.y,live_pose.origin.y))+50)
	var only_live: int = 0
	var only_mask: int = 0
	var common: int = 0
	var live_gas: int = 0
	var mask_gas: int = 0
	for y: int in range(y_min,y_max+1):
		for x: int in range(x_min,x_max+1):
			var centre := Vector2(float(x)+0.5,float(y)+0.5)
			var in_mask: bool = _inside_body(centre,mask_pose,rectangles)
			var in_live: bool = _inside_body(centre,live_pose,rectangles)
			if in_live and in_mask: common += 1
			elif in_live: only_live += 1
			elif in_mask: only_mask += 1
			if in_live or in_mask:
				var material: int = host.image.get_pixel(x,y).r8
				if material == 6 or material == 4:
					if in_live: live_gas += 1
					if in_mask: mask_gas += 1
	return {"only_live":only_live,"only_mask":only_mask,
		"common":common,"geometry_xor":only_live+only_mask,
		"stored_fire_smoke_inside_live":live_gas,
		"stored_fire_smoke_inside_mask":mask_gas}


func _capture(tick: int,record: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		verify(false,"graphical A/B requested but DisplayServer is headless")
		return
	if DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		verify(false,"capture directory available")
		return
	await RenderingServer.frame_post_draw
	var live_pose: Transform2D = host.physical_actor_session.bridge.body_transform(
		host.physical_actor_session.slot_for_instance(1))
	var frame: Dictionary = host.workbench_display_frame()
	var shown: Dictionary = frame.get("instances",{}).get(1,{})
	var pose: Variant = shown.get("pose")
	if not pose is Transform2D:
		verify(false,"uploaded native mask pose available for graphical comparison")
		return
	var geometry: Dictionary = _mask_geometry_delta(pose,live_pose)
	max_live_mask_xor = maxi(max_live_mask_xor,int(geometry.geometry_xor))
	var name: String = "%s-%s-%s-t%03d.png" % [trial,pose_mode,camera_mode,tick]
	var image: Image = root.get_texture().get_image()
	verify(image != null and image.get_width() > 500 and image.get_height() > 300,
		"actual Windows/GL framebuffer present")
	if image == null: return
	var error: Error = image.save_png(capture_dir.path_join(name))
	verify(error == OK,"real rendered frame saved "+name)
	if error != OK: return
	actual_captures += 1
	var chosen_parts: Array = host.physical_actor_overlay._parts
	var drawn: Vector2 = (chosen_parts[0].transform.origin
		if not chosen_parts.is_empty() else Vector2.INF)
	var selected: Vector2 = live_pose.origin if pose_mode == "live" else pose.origin
	var error_px: float = drawn.distance_to(selected)
	# _process and this image readback may straddle one physics tick.
	# Record the discrepancy instead of silently calling them the same frame.
	var receipt := {"png":name,"requested_tick":tick,
		"captured_tick":host.physical_actor_session.tick,
		"mode":pose_mode,"camera":camera_mode,
		"native_sample":int(shown.get("sample",-1)),
		"mask_revision":int(frame.get("revision",-1)),
		"uploaded_revision":host.last_uploaded_revision,
		"framebuffer":[image.get_width(),image.get_height()],
		"mask_position":_xy(pose.origin),
		"live_position":_xy(live_pose.origin),
		"drawn_position":_xy(drawn),
		"drawn_vs_selected":error_px,
		"pose_gap":pose.origin.distance_to(live_pose.origin),
		"geometry":geometry,
		"fire_requested":ui.fire_enabled,
		"physics_position_at_sample":record.position}
	frames.append(receipt)
	print("PR566_POSE_AB_CAPTURE ",JSON.stringify(receipt))
