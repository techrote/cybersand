extends SceneTree

# Read-only causal reproduction, not a performance or graphical qualification.
# Main/native/Rapier scheduling is inherited unchanged. Extra guard observations
# are deliberately charged to this diagnostic, never an ordinary timing arm.
const Setup = preload("res://scripts/workbench_setup.gd")
const Trace = preload("res://scripts/workbench_pose_trace.gd")

class DiagnosticHost extends "res://scripts/main.gd":
	var endpoint_queries: Array[Dictionary] = []
	var endpoint_last: Dictionary = {}
	var endpoint_reason_counts: Dictionary = {}
	var endpoint_frames: int = 0
	func _assess_workbench_presented_sweep(start: Transform2D, target: Transform2D,
			rectangles: Array, context: Dictionary, summary: Dictionary) -> Dictionary:
		var result: Dictionary = super._assess_workbench_presented_sweep(start,target,rectangles,context,summary)
		var slot: int = -1
		for candidate: int in physical_actor_session.bridge._rects.size():
			if is_same(rectangles,physical_actor_session.bridge._rects[candidate]):
				slot = candidate
				break
		endpoint_queries.append({"slot":slot,"start":Trace.pose_json(start),"target":Trace.pose_json(target),
			"endpoint_only":start==target,"result":result.duplicate(true)})
		return result
	func _resolve_workbench_presentation_frame(frame: Dictionary) -> Dictionary:
		endpoint_queries.clear()
		var result: Dictionary = super._resolve_workbench_presentation_frame(frame)
		endpoint_frames += 1
		if physical_actor_session == null: return result
		for query: Dictionary in endpoint_queries:
			var key: String = str(query.slot)+":"+str(query.endpoint_only)+":"+str(query.result.reason)
			endpoint_reason_counts[key] = int(endpoint_reason_counts.get(key,0))+1
		endpoint_last = {"time_usec":Time.get_ticks_usec(),"step":physical_actor_session.tick,
			"queries":endpoint_queries.duplicate(true),"reasons":result.reasons.duplicate(true),
			"sources":result.sources.duplicate(true),"selected_steps":result.selected_steps.duplicate(true),
			"previous_blend_active":result.previous_blend_active,"serial":result.upload_serial,
			"native_frame":frame.duplicate(true),"guard":workbench_presentation_last.duplicate(true)}
		return result

var host: DiagnosticHost
var output: String = ""
var failures: Array[String] = []
var captures: Array[Dictionary] = []

func _initialize() -> void:
	output = OS.get_environment("CYBERSAND_ENDPOINT_DIAGNOSTIC_OUTPUT")
	ProjectSettings.set_setting("cybersand/native_worker_threads",4)
	Engine.max_fps = 60
	for key: String in ["CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ","CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL"]:
		OS.set_environment(key,"0")
	OS.set_environment("CYBERSAND_MATERIAL_PUBLICATION","full")
	OS.set_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS","2")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","measured")
	OS.set_environment("CYBERSAND_DIAG_PHYSICS_PUBLICATION","early")
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()

func until(predicate: Callable, milliseconds: int = 60000) -> bool:
	var deadline: int = Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("ENDPOINT_DIAGNOSTIC: "+message)
	return ok

func footprint(pose: Transform2D, rectangles: Array, pixels: Image) -> Dictionary:
	var occupied: Array[Dictionary] = []
	var cells: int = 0
	var crops: Array[Dictionary] = []
	for rectangle: Dictionary in rectangles:
		var half: Vector2 = Vector2(rectangle.size)*0.5
		var centre: Vector2 = pose*Vector2(rectangle.center)
		var extent: Vector2 = pose.x.abs()*half.x+pose.y.abs()*half.y
		var low := Vector2i(maxi(0,floori(centre.x-extent.x)-1),maxi(0,floori(centre.y-extent.y)-1))
		var high := Vector2i(mini(pixels.get_width(),ceili(centre.x+extent.x)+1),mini(pixels.get_height(),ceili(centre.y+extent.y)+1))
		var crop: Image = pixels.get_region(Rect2i(low,high-low))
		var bytes: PackedByteArray = crop.get_data()
		crops.append({"rect":[low.x,low.y,high.x-low.x,high.y-low.y],"format":crop.get_format(),
			"bytes_base64":Marshalls.raw_to_base64(bytes),"sha256":hash_bytes(bytes),
			"local_center":Trace.xy(rectangle.center),"size":Trace.xy(rectangle.size)})
		for y: int in range(maxi(0,floori(centre.y-extent.y)-1),mini(pixels.get_height(),ceili(centre.y+extent.y)+1)):
			for x: int in range(maxi(0,floori(centre.x-extent.x)-1),mini(pixels.get_width(),ceili(centre.x+extent.x)+1)):
				var local: Vector2 = pose.affine_inverse()*Vector2(x+0.5,y+0.5)-Vector2(rectangle.center)
				if absf(local.x)>half.x+0.0001 or absf(local.y)>half.y+0.0001: continue
				cells += 1
				var pixel: Color = pixels.get_pixel(x,y)
				if pixel.r8 != 0:
					occupied.append({"x":x,"y":y,"material":pixel.r8,"state":pixel.g8})
	return {"cells":cells,"occupied":occupied,"crops":crops}

func hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func capture(label: String) -> void:
	var snapshot: Variant = host.latest_snapshot
	var bridge: Variant = host.physical_actor_session.bridge
	var bodies: Array[Dictionary] = []
	for slot: int in bridge._members.size():
		var pose: Transform2D = bridge.body_transform(slot)
		var rid_pose: Transform2D = PhysicsServer2D.body_get_state(bridge._body_rids[slot],PhysicsServer2D.BODY_STATE_TRANSFORM)
		var old: Image = host._presentation_previous_image
		bodies.append({"slot":slot,"live":Trace.pose_json(pose),"rid":str(bridge._body_rids[slot].get_id()),
			"actual_rid_pose":Trace.pose_json(rid_pose),
			"current":footprint(pose,bridge._rects[slot],host.image),
			"previous":footprint(pose,bridge._rects[slot],old) if old != null else {},
			"state":host._workbench_presentation_state.get(slot,{}).duplicate(true)})
	var row: Dictionary = {"label":label,"time_usec":Time.get_ticks_usec(),"step":host.physical_actor_session.tick,
		"actual_manual_steps":bridge.manual_step_count(),
		"latest":host.endpoint_last.duplicate(true),"bodies":bodies,
		"gcr":snapshot.lab_context.get("workbench_gcr",{}).duplicate(true),
		"native_tick":snapshot.tick_index,"world_generation":host.last_uploaded_world_generation,
		"current_sha256":hash_bytes(host.image.get_data()),
		"previous_sha256":hash_bytes(host._presentation_previous_image.get_data()) if host._presentation_previous_image != null else null,
		"image_hash_scope":"SHA256 of actual copied RG8 CPU image bytes used by guard; no GPU identity claim",
		"unresolved":snapshot.rigid_body_unresolved_last_tick,"displaced":snapshot.rigid_body_displaced_last_tick}
	captures.append(row)
	print("ENDPOINT_CAPTURE ",label," step=",row.step," unresolved=",row.unresolved)

func _run() -> void:
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(DiagnosticHost)
	host = loaded
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty()),"mounted Workbench"):
		await run_case()
	var identity: Dictionary = {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display":DisplayServer.get_name(),
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path())}
	for path: String in [get_script().resource_path,"res://scripts/main.gd","res://scripts/workbench_presentation_coherence.gd",
			"res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
			"res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"]:
		identity[path] = FileAccess.get_sha256(path)
	var result: Dictionary = {"schema":"pubpres-endpoint-causal-diagnostic-v1","scope":"Headless actual Main/native/Rapier causal reproduction; neutral controls, no live painting; not matched gameplay or GPU qualification.",
		"identity":identity,"failures":failures,"captures":captures,"query_reasons":host.endpoint_reason_counts,
		"frames":host.endpoint_frames}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"  ")+"\n")
		else: check(false,"evidence output open")
	host.queue_free()
	await process_frame
	await process_frame
	print("ENDPOINT_DIAGNOSTIC_RESULT ",JSON.stringify({"failures":failures,"captures":captures.size()}))
	quit(int(not failures.is_empty()))

func run_case() -> void:
	var ui: Control = host.shared_workbench
	host.paused = true
	host.update_worker_frame_state()
	var api: Variant = ui._liquids.bridge
	var carrier: PackedInt32Array = api.default_liquid_policy()
	for row: Dictionary in api.liquid_policy_assignment_choices(carrier,3):
		if str(row.get("family","")) == "freemass_v1" and str(row.get("variant","")) == "reference" and row.get("accepted",false):
			carrier = row.request
			break
	host.workbench_water_options.clear()
	host.workbench_water_options.merge(ClassDB.class_call_static(&"CyberNativeCellWorld",&"gameplay_water_options"),true)
	var setup: Dictionary = Setup.fresh(carrier,Vector2i(512,512))
	for entry: Array in [[1,"needle",200,160],[2,"needle",72,80],[3,"needle",144,80],[4,"needle",216,80],
			[5,"needle",288,80],[6,"needle",360,80],[7,"needle",432,80],[8,"reference_barrel",176,220]]:
		setup.actors.append(Setup.instance(str(entry[1]),int(entry[0]),Vector2(entry[2],entry[3])))
	setup.next_id = 9
	setup.selected = 1
	setup.edits = [[0,496,512,16,58],[0,0,16,512,58],[496,0,16,512,58],
		[32,272,112,224,3],[160,432,144,64,3],[320,464,176,32,3],[256,400,8,96,58],[112,240,112,8,58]]
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"eight-actor authored World accepted"): return
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch and host.physical_actor_session != null \
			and host._physical_terrain_ready and host._valid_workbench_mask_frame(host.workbench_display_frame())),"native material and complete terrain/actor receipts installed"): return
	ui._camera.select(1)
	ui.set_camera(1)
	ui._set_view(Vector2.ZERO,Vector2i(480,270))
	capture("paused_initial")
	host.paused = false
	host.update_worker_frame_state()
	for target: int in [120,240,360,480,600]:
		if not check(await until(func() -> bool: return host.physical_actor_session.tick>=target,20000),"ordinary physical progression reaches "+str(target)): return
		capture("ordinary_step_"+str(target))
	host.paused = true
	host.update_worker_frame_state()
	await until(func() -> bool: return host.latest_snapshot.paused,5000)
	ui.select_instance(5)
	ui._set_view(Vector2(40,240),Vector2i(480,270))
	for ignored: int in range(4): await process_frame
	capture("paused_camera_return")
