extends SceneTree

# Real prepared multipart owners, Main's ordinary presentation, Rapier and
# graphical first reads. This is correctness execution, never a timed campaign.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var picking: Array[Dictionary] = []
var framebuffer: Dictionary = {}
var mount_samples: Array[Dictionary] = []
var workshop_extent: Array = []
var finished: bool = false

func _initialize() -> void:
	Engine.max_fps = 60
	set_meta("cybersand_feature","shared_workbench")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("MEMBER_PRESENTATION: "+label)
	return value

func until(predicate: Callable, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if is_instance_valid(host) and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false,label)

func settled() -> bool:
	return ui != null and not ui.applied.is_empty() and not ui.busy() \
		and host.pending_microscenario_apply.is_empty() and host._pending_physical_candidate == null

func configure_initial_canvas() -> void:
	ui = host.shared_workbench
	if ui == null: return
	# Main has installed the ordinary New controls and deferred its first blank.
	# Prepare that blank at the actual six-actor workshop extent.
	workshop_extent = Setup.mixed_actor_workshop(PackedInt32Array()).extent
	for axis: int in range(2):
		ui._extent[axis].value = workshop_extent[axis]

func await_initial_canvas() -> bool:
	var started := Time.get_ticks_msec()
	var next_sample := started
	while true:
		ui = host.shared_workbench
		var failed: bool = host.simulation_worker.has_failed()
		var ready: bool = settled()
		var elapsed := Time.get_ticks_msec() - started
		if Time.get_ticks_msec() >= next_sample or ready or failed or elapsed >= 90000:
			var snapshot = host.simulation_worker.take_latest_snapshot(0)
			var sample := {"phase":"initial_blank","elapsed_ms":elapsed,"ready":ready,"failed":failed,
				"requested_extent":workshop_extent,"applied_extent":ui.applied.get("extent",[]) if ui!=null else [],
				"process_frame":Engine.get_process_frames(),"ui_attached":ui!=null,
				"ui_request":ui._pending_request_serial if ui!=null else 0,
				"pending_request":int(host.pending_microscenario_apply.get("serial",0)),
				"pending_owner":host._pending_physical_candidate.get_instance_id() if host._pending_physical_candidate!=null else 0,
				"installed_owner":host.physical_actor_session.get_instance_id() if host.physical_actor_session!=null else 0,
				"world":host.last_uploaded_world_generation,"upload_serial":host.last_uploaded_render_snapshot_serial,
				"snapshot_serial":snapshot.serial if snapshot!=null else -1,"native_tick":snapshot.tick_index if snapshot!=null else -1,
				"worker_error":snapshot.last_tick_error if snapshot!=null else "","message":ui.message if ui!=null else "",
				"microscenario_error":host.microscenario_error,"native_refusal":host.tower_context.get("workbench_refusal","")}
			mount_samples.append(sample)
			print("MEMBER_PRESENTATION_MOUNT ",JSON.stringify(sample))
			next_sample = Time.get_ticks_msec()+15000
		if failed: return check(false,"initial native Workbench failed")
		if ready:
			if workshop_extent.size()==2 and ui.applied.get("extent")==workshop_extent: return true
			return check(false,"initial Workbench adopted the requested workshop extent")
		if elapsed >= 90000: return check(false,"initial Workbench ready")
		await process_frame
	return false

func draw() -> void:
	if DisplayServer.get_name()=="headless":
		await process_frame
		await process_frame
	else:
		await RenderingServer.frame_post_draw
		# Explicit untimed CPU queue drain for the graphical read only.
		if RenderingServer.has_method("_force_sync"): RenderingServer.call("_force_sync")

func color_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func recipe(last_id: int = 6) -> Dictionary:
	var result: Dictionary = Setup.mixed_actor_workshop(PackedInt32Array(ui.applied.liquid_policy))
	# Preserve every actual prepared mechanism; remove terrain for a focused
	# body-index/observation witness rather than a material-coverage experiment.
	result.edits.clear()
	result.actors[5].id = last_id
	result.selected = last_id
	result.next_id = last_id+1
	return result

func install(data: Dictionary) -> bool:
	var old_epoch: int = host._physical_epoch
	if not check(ui.apply(data),"ordinary prepared multipart setup accepted"): return false
	return await until(func() -> bool:
		return settled() and host._physical_epoch>old_epoch and host.physical_actor_session != null \
			and host._physical_terrain_ready and host.workbench_presentation_frame.get("valid",false),
		"native and Rapier multipart owners become ready")

func inspect_members(label: String) -> void:
	var session: Variant = host.physical_actor_session
	var bridge: Variant = session.bridge
	var count: int = bridge._members.size()
	check(count==24 and ui.applied.actors.size()==6 and count>int(ui.applied.get("sandbox_capacity",Setup.SandboxCapacity.defaults()).logical_limit),
		"24 physical members for six logical owners exceed this setup's actor slot budget")
	for slot: int in range(count):
		var member: Dictionary = bridge._members[slot]
		var row: Dictionary = host._workbench_presentation_history.observation(slot,session.tick)
		var pose: Transform2D = bridge.body_transform(slot)
		var valid: bool = row.get("instance_id",-1)==member.instance_id \
			and row.get("generation",-1)==member.generation and row.get("step",-1)==session.tick \
			and row.get("pose") == pose
		check(valid,label+" exact actual observation for physical member "+str(slot))
		observations.append({"stage":label,"slot":slot,"actor_slot":member.actor_slot,
			"part_index":member.part_index,"instance_id":member.instance_id,"generation":member.generation,
			"step":session.tick,"manual_steps":bridge.manual_step_count(),"valid":valid,
			"completed_usec":row.get("completed_usec",-1),"pose":str(pose),"observed_pose":str(row.get("pose"))})
		if valid:
			check(row.completed_usec==0 if session.tick==0 else row.completed_usec==host._workbench_completed_step_usec,
				label+" member completion clock is real and not renewed")

func inspect_follow() -> void:
	ui._camera.select(1)
	ui.set_camera(1)
	for actor: Dictionary in ui.applied.actors:
		check(ui.select_instance(int(actor.id)),"select existing authored actor "+str(actor.id))
		for ignored: int in range(4): await draw()
		var session: Variant = host.physical_actor_session
		var actor_slot: int = session.slot_for_instance(int(actor.id))
		var body_slot: int = session.bridge.actor_body_index(actor_slot)
		var frame: Dictionary = host.workbench_presentation_frame
		check(frame.follow_instance_id==actor.id and frame.get("follow_target")==session.bridge.body_transform(body_slot).origin,
			"Follow uses selected actor's root physical body "+str(actor.id)+" / "+str(body_slot))

func first_read() -> void:
	if DisplayServer.get_name()=="headless": return
	var slot: int = host.physical_actor_session.bridge.actor_body_index(5)
	if not await until(func() -> bool: return host.workbench_presentation_frame.get("poses",{}).has(slot),
		"last multipart body receives a real presentation"): return
	await draw()
	var frame: Dictionary = host.workbench_presentation_frame
	var world: Vector2 = host.physical_actor_session.bridge.body_transform(slot).origin
	var projected: Vector2 = root.get_stretch_transform() * (root.get_screen_transform().affine_inverse() * (frame.camera_mapping*world))
	var point := Vector2i(projected.round())
	var shown: Image = root.get_texture().get_image()
	if not check(Rect2i(Vector2i.ZERO,shown.get_size()).has_point(point),"selected last body maps inside actual framebuffer"): return
	var first: Color = shown.get_pixelv(point)
	var physical_step: int = host.physical_actor_session.tick
	# present() legitimately reasserts visibility every frame. A persistent
	# alpha control actually exercises removal while leaving physics unchanged.
	host.physical_actor_overlay.modulate.a = 0.0
	await draw()
	check(host.physical_actor_overlay.modulate.a==0.0,"framebuffer removal control actually remained active")
	var hidden: Color = root.get_texture().get_image().get_pixelv(point)
	host.physical_actor_overlay.modulate.a = 1.0
	await draw()
	var restored: Image = root.get_texture().get_image()
	var after: Color = restored.get_pixelv(point)
	check(color_error(first,hidden)>0.02 and color_error(first,after)<0.005,
		"actual body beyond slot eight appears, disappears and returns in the same framebuffer pixel")
	check(host.physical_actor_session.tick==physical_step,"framebuffer control creates no physical movement")
	framebuffer = {"body_slot":slot,"pixel":[point.x,point.y],
		"shown":[first.r,first.g,first.b,first.a],"hidden":[hidden.r,hidden.g,hidden.b,hidden.a],
		"restored":[after.r,after.g,after.b,after.a]}
	var output: String = OS.get_environment("CYBERSAND_MEMBER_PRESENTATION_OUTPUT")
	if not output.is_empty():
		var png: String = output.get_basename()+".png"
		check(restored.save_png(png)==OK,"actual first-read framebuffer artifact saved")
		framebuffer["png_sha256"] = FileAccess.get_sha256(png)

func inspect_picking(label: String) -> void:
	# Drive the ordinary Select tool with local mouse coordinates derived from
	# the actual submitted camera. Actor ids, authored slots and physical body
	# slots deliberately differ in this real six-actor/24-body owner.
	ui._tool.select(2)
	ui._camera.select(1)
	ui.set_camera(1)
	for actor: Dictionary in ui.applied.actors:
		check(ui.select_instance(int(actor.id)),label+" select actual actor for camera placement")
		for ignored: int in range(4): await draw()
		var session: Variant = host.physical_actor_session
		var actor_slot: int = session.slot_for_instance(int(actor.id))
		var body_slot: int = session.bridge.actor_body_index(actor_slot)
		var member: Dictionary = session.bridge._members[body_slot]
		var frame: Dictionary = host.workbench_presentation_frame
		if not check(frame.get("poses",{}).has(body_slot),label+" root body is actually presented before clicking"):
			continue
		var pose: Transform2D = frame.poses[body_slot]
		var local: Vector2 = host._world_view_screen_transform().affine_inverse() * (frame.camera_mapping*pose.origin)
		var cell: Vector2i = host.world_cell_from_local_point(local,true)
		check(Setup.bounds(str(actor.model)).grow(2).has_point((Vector2(cell)-pose.origin).rotated(-pose.get_rotation())),
			label+" submitted camera maps the real root to its selectable footprint")
		var before_step: int = session.tick
		check(ui.select_instance(0),label+" selection starts empty before the actual click")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = local
		ui._world_input(click)
		check(ui.selected_id()==int(actor.id),label+" ordinary click selects authored actor "+str(actor.id)+" through physical body "+str(body_slot))
		check(session.tick==before_step,label+" selecting cannot invent or advance a physical step")
		picking.append({"stage":label,"kind":"ordinary_mouse_click","actor_id":int(actor.id),
			"actor_slot":actor_slot,"body_slot":body_slot,"member_id":int(member.instance_id),
			"member_generation":int(member.generation),"mask_generation":frame.mask_frame.instances.get(int(member.instance_id),{}).get("generation",-1),
			"selected_id":ui.selected_id(),"cell":[cell.x,cell.y],"local":[local.x,local.y],
			"submitted_pose":str(pose),"session":int(frame.session),"epoch":int(frame.epoch),
			"step_before":before_step,"step_after":session.tick})
	# Synchronous refusal adversaries use copies of an actual submitted frame.
	# No injected frame is drawn or counted as a new physical/presentation event.
	var original: Dictionary = host.workbench_presentation_frame
	var bridge: Variant = host.physical_actor_session.bridge
	var last_slot: int = bridge.actor_body_index(5)
	var last_member: Dictionary = bridge._members[last_slot]
	var point := Vector2i(Transform2D(original.poses[last_slot]).origin.floor())
	for kind: String in ["withheld_root","wrong_member_generation"]:
		var injected: Dictionary = original.duplicate(true)
		if kind=="withheld_root": injected.poses.erase(last_slot)
		else: injected.mask_frame.instances[int(last_member.instance_id)].generation = int(last_member.generation)+1
		if host.workbench_presentation_submission_enabled(): host.WorkbenchPresentationSubmission.freeze(injected)
		host.workbench_presentation_frame = injected
		ui.select_instance(0)
		ui._pick(point)
		check(ui.selected_id()==0,label+" refuses "+kind+" without live-pose fallback")
		picking.append({"stage":label,"kind":kind,"fixture_injected_refusal":true,
			"actor_id":int(ui.applied.actors[5].id),"body_slot":last_slot,"selected_id":ui.selected_id()})
		host.workbench_presentation_frame = original
	ui.select_instance(int(ui.applied.actors[5].id))

func member_hit(frame: Dictionary, body_slot: int, point: Vector2) -> bool:
	if not frame.get("poses",{}).has(body_slot): return false
	var bridge: Variant = host.physical_actor_session.bridge
	var local: Vector2 = Transform2D(frame.poses[body_slot]).affine_inverse()*point
	for rectangle: Dictionary in bridge._rects[body_slot]:
		if Rect2(Vector2(rectangle.center)-Vector2(rectangle.size)*0.5,Vector2(rectangle.size)).grow(2).has_point(local):
			return true
	return false

func inspect_member_picking(label: String) -> void:
	ui._tool.select(2)
	ui._camera.select(1)
	ui.set_camera(1)
	var isolated: Dictionary = {}
	for actor: Dictionary in ui.applied.actors:
		check(ui.select_instance(int(actor.id)),label+" focus logical owner for individual member picking")
		for ignored: int in range(4): await draw()
		var bridge: Variant = host.physical_actor_session.bridge
		var actor_slot: int = host.physical_actor_session.slot_for_instance(int(actor.id))
		var first: int = bridge.actor_body_index(actor_slot)
		for body_slot: int in range(first,first+bridge.actor_body_count(actor_slot)):
			var frame: Dictionary = host.workbench_presentation_frame
			if not check(frame.get("poses",{}).has(body_slot),label+" individual member is actually submitted "+str(body_slot)): continue
			var pose: Transform2D = frame.poses[body_slot]
			var center: Vector2 = pose*Vector2(bridge._rects[body_slot][0].center)
			var local: Vector2 = host._world_view_screen_transform().affine_inverse()*(frame.camera_mapping*center)
			var cell: Vector2i = host.world_cell_from_local_point(local,true)
			var step_before: int = host.physical_actor_session.tick
			check(ui.select_instance(0),label+" clear selection before actual member mouse input")
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = local
			ui._world_input(click)
			check(ui.selected_id()==int(actor.id),label+" click physical member "+str(body_slot)+" selects its logical owner "+str(actor.id))
			check(host.physical_actor_session.tick==step_before,label+" member selection invents no physical progress")
			picking.append({"stage":label,"kind":"individual_member_mouse_click","body_slot":body_slot,
				"actor_slot":actor_slot,"part_index":bridge._members[body_slot].part_index,"actor_id":int(actor.id),
				"selected_id":ui.selected_id(),"cell":[cell.x,cell.y],"local":[local.x,local.y],
				"pose":str(pose),"step_before":step_before,"step_after":host.physical_actor_session.tick})
			if body_slot==first or not isolated.is_empty(): continue
			var alone: bool = member_hit(frame,body_slot,Vector2(cell))
			for other: int in range(bridge._members.size()):
				if other!=body_slot and member_hit(frame,other,Vector2(cell)): alone = false
			if alone:
				isolated = {"body_slot":body_slot,"point":cell,"actor_id":int(actor.id),"frame":frame}
	check(not isolated.is_empty(),label+" real articulated fixture provides an independently clickable member footprint")
	if isolated.is_empty(): return
	# Synchronous copies of actual submitted poses isolate owner refusals. These
	# are never drawn and never credited as additional presentation or physics.
	var current: Dictionary = host.workbench_presentation_frame
	var bridge: Variant = host.physical_actor_session.bridge
	var slot: int = isolated.body_slot
	var member: Dictionary = bridge._members[slot]
	for kind: String in ["withheld_member","foreign_member_generation"]:
		var injected: Dictionary = isolated.frame.duplicate(true)
		if kind=="withheld_member": injected.poses.erase(slot)
		else: injected.mask_frame.instances[int(member.instance_id)].generation = int(member.generation)+1
		if host.workbench_presentation_submission_enabled(): host.WorkbenchPresentationSubmission.freeze(injected)
		host.workbench_presentation_frame = injected
		ui.select_instance(0)
		ui._pick(isolated.point)
		check(ui.selected_id()==0,label+" refuses click through "+kind+" instead of the static whole-actor bounds")
		picking.append({"stage":label,"kind":kind,"fixture_injected_refusal":true,"body_slot":slot,
			"actor_id":isolated.actor_id,"selected_id":ui.selected_id(),"point":str(isolated.point)})
	host.workbench_presentation_frame = current
	ui.select_instance(int(ui.applied.actors[5].id))

func _run() -> void:
	root.size = Vector2i(1280,900)
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	host.ready.connect(configure_initial_canvas,CONNECT_ONE_SHOT)
	root.add_child(host)
	if not await await_initial_canvas() or not await install(recipe()):
		finish();return
	for ignored: int in range(30): await draw()
	inspect_members("initialized")
	await inspect_follow()
	await first_read()
	await inspect_picking("initialized")
	await inspect_member_picking("initialized")
	check(ui.toggle_pause(),"ordinary Play admits real physical movement")
	await until(func() -> bool: return host.physical_actor_session.tick>=12,"twelve real multipart Rapier steps complete")
	check(ui.toggle_pause(),"ordinary Pause admitted")
	var pause_serial: int = host.simulation_worker.workbench_pause_request_serial()
	await until(func() -> bool:
		var state: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
		return state != null and state.lab_context.get("workbench_pause_ack_serial",-1)>=pause_serial,
		"native owner acknowledges Pause")
	for ignored: int in range(6): await draw()
	inspect_members("completed")
	await inspect_member_picking("completed")
	var old_session: int = host.physical_actor_session.bridge._session
	var old_observation: Dictionary = host._workbench_presentation_history.observation(23,host.physical_actor_session.tick)
	var retired_frame: Dictionary = host.workbench_presentation_frame
	if await install(recipe(60)):
		for ignored: int in range(30): await draw()
		check(host.physical_actor_session.bridge._session!=old_session,"replacement adopts a distinct native owner")
		inspect_members("replacement")
		check(old_observation.is_empty() or old_observation.generation != host.physical_actor_session.bridge._members[23].generation,
			"retained old immutable value cannot impersonate replacement generation")
		await inspect_follow()
		await inspect_picking("replacement")
		await inspect_member_picking("replacement")
		var current_frame: Dictionary = host.workbench_presentation_frame
		host.workbench_presentation_frame = retired_frame
		ui.select_instance(0)
		ui._pick(Vector2i(Transform2D(retired_frame.poses[23]).origin.floor()))
		check(ui.selected_id()==0,"retired actual owner frame cannot select a replacement actor")
		picking.append({"stage":"replacement","kind":"retired_owner","fixture_injected_refusal":true,
			"old_session":int(retired_frame.session),"new_session":int(current_frame.session),"selected_id":ui.selected_id()})
		host.workbench_presentation_frame = current_frame
	finish()


func selected_owner_readback() -> Dictionary:
	if not is_instance_valid(host) or host.simulation_worker == null: return {}
	return {"flight_pacing":host._flight_pacing and host.simulation_worker._notify_sample_completion,
		"coupling_clock":host.simulation_worker._independent_coupling,
		"empty_effects":host._check_ambient_sources}


func finish() -> void:
	if finished: return
	finished = true
	var hashes: Dictionary = {}
	for path: String in ["scripts/main.gd","scripts/shared_workbench.gd","scripts/workbench_presentation_history.gd",
		"scripts/physical_actor_session.gd","scripts/workbench_physics_bridge.gd","tests/test_workbench_member_presentation.gd"]:
		hashes["res://"+path] = FileAccess.get_sha256("res://"+path)
	var windows: bool = OS.get_name()=="Windows"
	var native_path: String = "res://addons/cybersand_native/bin/"+(
		"cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so")
	var rapier_path: String = "res://addons/godot-rapier2d/bin/"+(
		"libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if windows else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
	var result := {"schema":"pubpres-member-presentation-v1","checks":checks,"failures":failures,
		"selected_owner_readback":selected_owner_readback(),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"input_hashes":hashes,
		"graphical":DisplayServer.get_name()!="headless","display":DisplayServer.get_name(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"process_id":OS.get_process_id(),
		"native_sha256":FileAccess.get_sha256(native_path),"rapier_sha256":FileAccess.get_sha256(rapier_path),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"requested_render_lookahead":OS.get_environment("CYBERSAND_ENGINE_RENDER_LOOKAHEAD"),
		"actual_submission_enabled":host.workbench_presentation_submission_enabled() if is_instance_valid(host) else false,
		"mount_samples":mount_samples,"observations":observations,"framebuffer":framebuffer,"picking":picking}
	var output: String = OS.get_environment("CYBERSAND_MEMBER_PRESENTATION_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"\t"));file.close()
	print("PUBPRES_MEMBER_PRESENTATION_RESULT "+JSON.stringify(result))
	if is_instance_valid(host): host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
