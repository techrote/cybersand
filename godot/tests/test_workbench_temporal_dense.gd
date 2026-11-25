extends SceneTree

# Actual Main/World/Rapier regression for the eight-body admission starvation
# found during CAMERA-STACK-COHERENCE-001 review. Every submitted frame is kept;
# this fixture never retries a clearance-budget refusal. Controlled steps make
# the old failure deterministic; the contact phase uses ordinary Main callbacks.
const Setup = preload("res://scripts/workbench_setup.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Trace = preload("res://scripts/workbench_pose_trace.gd")
const WAIT_MS: int = 90000
const DENSE_BODIES: int = 8

class BudgetHost extends "res://scripts/main.gd":
	# Deterministic deadline pressure for one permanently unadmitted actor.
	# Other actors still use the actual production clearance guard.
	var exhaust_first_body: bool = false
	var guard_queries_in_frame: int = 0
	var exhausted_queries: int = 0
	var peer_first_turns: int = 0
	func _assess_workbench_presented_sweep(start: Transform2D, target: Transform2D,
			rectangles: Array, context: Dictionary, summary: Dictionary) -> Dictionary:
		if exhaust_first_body:
			var first_query: bool = guard_queries_in_frame==0
			guard_queries_in_frame += 1
			if rectangles==physical_actor_session.bridge._rects[0]:
				exhausted_queries += 1
				summary.cells_examined = PRESENTATION_FRAME_SCAN_BUDGET
				summary.budget_vetoes += 1
				return {"safe":false,"reason":"shared_budget","scanned":0}
			if first_query: peer_first_turns += 1
		return super._assess_workbench_presented_sweep(start,target,rectangles,context,summary)

var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var spawns: Array[Vector2] = []
var saved_environment: Dictionary = {}
var registry_before: Dictionary = {}
var source_before: Dictionary = {}
var output: String = ""
var last_steps: Dictionary = {}
var contact_slots: Dictionary = {}
var previous_max_fps: int = 0
var ordinary_progress: Dictionary = {}
var lineage_controls: Dictionary = {}
var lineage_native_edits: Array[Dictionary] = []
var budget_fairness: Dictionary = {}

func _initialize() -> void:
	previous_max_fps = Engine.max_fps
	output = OS.get_environment("CYBERSAND_TEMPORAL_DENSE_OUTPUT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--temporal-dense-evidence="):
			output = argument.trim_prefix("--temporal-dense-evidence=")
	for key: String in ["CYBERSAND_DIAG_PRESENTATION","CYBERSAND_DIAG_FLYER_POSE","CYBERSAND_DIAG_RENDER_CADENCE",
			"CYBERSAND_DIAG_MATERIAL_TIMING"]:
		saved_environment[key] = OS.get_environment(key)
		OS.set_environment(key,"")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("TEMPORAL_DENSE: "+label)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+WAIT_MS
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func identity() -> Dictionary:
	var result: Dictionary = {"commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine":Engine.get_version_info().string,"platform":OS.get_name(),
		"display":DisplayServer.get_name()}
	for path: String in ["res://scripts/main.gd","res://scripts/shared_workbench.gd",
			"res://scripts/workbench_presentation_coherence.gd","res://scripts/physical_actor_session.gd",
			"res://scripts/physical_actor_overlay.gd","res://tests/test_workbench_temporal_dense.gd"]:
		result[path] = FileAccess.get_sha256(path)
	var native_path: String = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" \
		if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	result["native_runtime_sha256"] = FileAccess.get_sha256(native_path)
	return result

func install(setup: Dictionary) -> bool:
	host.paused = true
	host.update_worker_frame_state()
	host.set_process(true)
	host.set_physics_process(true)
	host.engine_lab_set_render_hz(60)
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"authored dense World accepted"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session!=null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame()) \
			and host.workbench_display_frame().instances.size()==setup.actors.size()),
		"actual native material and complete actor receipts installed"): return false
	host.set_process(false)
	host.set_physics_process(false)
	host.engine_lab_wait_native_sample = false
	host.simulation_worker.set_engine_lab_pixel_pacing(1,false)
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	ui._camera.select(1)
	ui._set_view(Vector2.ZERO,Vector2i(512,512))
	last_steps.clear()
	return true

func install_dense() -> bool:
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	spawns.clear()
	for slot: int in range(DENSE_BODIES):
		var position := Vector2(70+(slot%4)*120,140+int(slot/4)*180)
		var model: String = "observatory" if slot%2==0 else "scooper"
		spawns.append(position)
		setup.actors.append(Setup.instance(model,slot+1,position))
		var bounds: Rect2 = Setup.bounds(model)
		setup.edits.append([int(position.x)-45,int(position.y+bounds.end.y)+2,90,5,58])
	setup.next_id = 9
	setup.selected = 8
	return await install(setup)

func controlled_step(offset: Vector2) -> void:
	var session = host.physical_actor_session
	var bridge = session.bridge
	var before: int = session.tick
	for slot: int in range(spawns.size()):
		bridge.reset_body(slot,spawns[slot]+offset,0.0)
	session.set_suspended(false)
	session.advance(bridge.fixed_delta())
	bridge.step()
	session.complete_step()
	# This controlled fixture replaces Main's callback, so stamp the real
	# completion here and retain every actual step just as Main does.
	host._workbench_completed_step = session.tick
	host._workbench_completed_step_usec = Time.get_ticks_usec()
	for slot: int in range(spawns.size()): host._observe_workbench_presentation(slot)
	check(session.tick==before+1,"controlled real Rapier step completes once")

func refresh_receipt() -> bool:
	var serial: int = host.last_uploaded_render_snapshot_serial
	host.simulation_worker.request_render_full_refresh()
	var completed: bool = await until(func() -> bool:
		host.consume_worker_snapshot()
		return host.last_uploaded_render_snapshot_serial>serial)
	if not check(completed and host.last_render_was_full_refresh,"genuine native full refresh uploaded"): return false
	check(not host._presentation_previous_unknown,"exact previous texture remains bounded after full refresh")
	var previous: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec()).previous
	check(previous.get("serial",-1) == serial and previous.get("generation",-1) == host.last_uploaded_world_generation,
		"full refresh retains a real same-World predecessor for active blend controls")
	return true

# Independent cell-centre occupancy assertion, with no swept oracle call. This
# checks only the selected footprint; the product oracle owns continuous sweeps.
func footprint_clear(pose: Transform2D, rectangles: Array, pixels: Image) -> bool:
	if pixels==null or pixels.is_empty(): return false
	var inverse: Transform2D = pose.affine_inverse()
	for rectangle: Dictionary in rectangles:
		var center: Vector2 = rectangle.center
		var half: Vector2 = Vector2(rectangle.size)*0.5
		var world_center: Vector2 = pose*center
		var extent: Vector2 = pose.x.abs()*half.x+pose.y.abs()*half.y
		var low: Vector2i = Vector2i((world_center-extent).floor())
		var high: Vector2i = Vector2i((world_center+extent).ceil())
		for y: int in range(maxi(low.y,0),mini(high.y,pixels.get_height())):
			for x: int in range(maxi(low.x,0),mini(high.x,pixels.get_width())):
				if pixels.get_pixel(x,y).r8==0: continue
				var relative: Vector2 = inverse*Vector2(x+0.5,y+0.5)-center
				if absf(relative.x)<=half.x and absf(relative.y)<=half.y: return false
	return true

func capture(label: String, submit: bool, verify_material: bool=true) -> Dictionary:
	if submit: host._process(1.0/60.0)
	var frame: Dictionary = host.workbench_presentation_frame
	var bridge = host.physical_actor_session.bridge
	var decisions: Array[Dictionary] = []
	check(frame.get("policy","")=="coherent",label+" uses coherent production policy")
	check(int(host.workbench_presentation_last.get("cells_examined",0))<=host.PRESENTATION_FRAME_SCAN_BUDGET,
		label+" respects shared charged-cell bound")
	for slot: int in range(bridge._members.size()):
		var source: String = frame.sources.get(slot,"hidden")
		var step: int = frame.selected_steps.get(slot,-1)
		var decision: Dictionary = {"slot":slot,"source":source,"reason":frame.reasons.get(slot,frame.get("reason","")),
			"step":step,"desired_step":frame.desired_steps.get(slot,-1),
			"pose":Trace.pose_json(frame.poses.get(slot)),"live":Trace.pose_json(bridge.body_transform(slot))}
		var direct = PhysicsServer2D.body_get_direct_state(bridge._body_rids[slot])
		decision["contacts"] = direct.get_contact_count() if direct!=null else 0
		if int(decision.contacts)>0: contact_slots[slot] = true
		if source!="hidden":
			check(frame.poses.has(slot),label+" visible slot has selected pose "+str(slot))
			if last_steps.has(slot):
				check(step>=int(last_steps[slot]),label+" selected timeline never rewinds slot "+str(slot))
			last_steps[slot] = step
			if verify_material:
				var pose: Transform2D = frame.poses[slot]
				check(footprint_clear(pose,bridge._rects[slot],host.image),label+" current material clear at visible slot "+str(slot))
				if frame.previous_blend_active and host._presentation_previous_image!=null:
					check(footprint_clear(pose,bridge._rects[slot],host._presentation_previous_image),
						label+" actual old material clear at visible slot "+str(slot))
		else:
			check(not frame.poses.has(slot),label+" withheld slot has no independent overlay pose "+str(slot))
		decisions.append(decision)
	var selected_slot: int = host.physical_actor_session.slot_for_instance(ui.selected_id())
	if frame.poses.has(selected_slot):
		check(Vector2(frame.follow_target).is_equal_approx(frame.poses[selected_slot].origin),
			label+" Follow target matches selected actor pose")
	var row: Dictionary = {"label":label,"process_frame":Engine.get_process_frames(),
		"time_usec":Time.get_ticks_usec(),"main_frame_ms":host.frame_time_ms,
		"session":frame.session,"epoch":frame.epoch,"rapier_step":frame.rapier_step,
		"native_tick":frame.native_tick,"upload_serial":frame.upload_serial,
		"material_revision":frame.material_revision,"valid":frame.valid,
		"previous_blend_active":frame.previous_blend_active,"selection_usec":frame.selection_usec,
		"upload_cache_usec":frame.upload_cache_usec,"resolve_usec":frame.resolve_usec,
		"guard":host.workbench_presentation_last.duplicate(true),"decisions":decisions,
		"visible_parts":host.physical_actor_overlay._parts.size(),
		"material_contents":frame.get("material_contents",[]),
		"current_content_id":content_id("current"),"previous_content_id":content_id("previous"),
		"current_texture_id":frame.get("current_texture_id",0),"previous_texture_id":frame.get("previous_texture_id",0)}
	rows.append(row)
	return row

func content_id(which: String) -> int:
	# Diagnostics are optional on the preserved pre-fix implementation. Its
	# negative must fail on actual disappearing actors, not a missing new API.
	var value: Variant = host.get("_presentation_"+which+"_content_id")
	return int(value) if value is int else -1

func exhausted_capture(label: String) -> Dictionary:
	# Controlled deadline stimulus only: the real native images, GPU slots,
	# actor receipts and physical geometry are unchanged. This models an upload
	# consuming the whole guard allowance without a machine-speed threshold.
	var charged: int = host.PRESENTATION_FRAME_TIME_BUDGET_USEC+1000
	host._presentation_pending_cache_usec = charged
	var row: Dictionary = capture(label,true)
	row["controlled_budget_exhaustion_usec"] = charged
	check(int(row.guard.cells_examined)==0,label+" performs no extra clearance scans after exhausted deadline")
	return row

func identical_refresh_budget_controls() -> void:
	print("TEMPORAL_DENSE_STAGE unchanged content and exhausted deadline")
	var prior_poses: Dictionary = host.workbench_presentation_frame.poses.duplicate(true)
	var prior_steps: Dictionary = host.workbench_presentation_frame.selected_steps.duplicate()
	var bytes: PackedByteArray = host.image.get_data()
	var revision: int = host.last_uploaded_revision
	var current: int = content_id("current")
	if not await refresh_receipt(): return
	check(host.image.get_data()==bytes and host._presentation_previous_image!=null \
		and host._presentation_previous_image.get_data()==bytes and host.last_uploaded_revision==revision,
		"actual native full refresh leaves both GPU source images byte-identical")
	if current>=0:
		check(content_id("current")==current and content_id("previous")==current,
			"unchanged upload and actual old GPU slot share the certified content identity")
	controlled_step(Vector2(0.8,0))
	host.snapshot_blend_start_usec = Time.get_ticks_usec()
	var held: Dictionary = exhausted_capture("unchanged-refresh-budget-hold")
	check(held.valid and held.previous_blend_active,"exhausted-budget control has valid native receipt and active previous texture")
	for slot: int in range(DENSE_BODIES):
		check(held.decisions[slot].source=="held" and host.workbench_presentation_frame.poses.has(slot) \
			and host.workbench_presentation_frame.poses[slot]==prior_poses.get(slot) \
			and held.decisions[slot].step==prior_steps.get(slot,-2),
			"unchanged bytes keep prior certified actor visible without scans slot "+str(slot))
	# A known image's pixels do not grant permission to ignore an explicit
	# unavailable-history state. This is a labelled provenance-fault stimulus.
	var prior_unknown: bool = host._presentation_previous_unknown
	host._presentation_previous_unknown = true
	host.snapshot_blend_start_usec = Time.get_ticks_usec()
	var unknown: Dictionary = exhausted_capture("unchanged-refresh-unknown-history")
	unknown["controlled_previous_history_unavailable"] = true
	check(unknown.valid and unknown.previous_blend_active,"unknown-history negative retains the real otherwise-valid receipt")
	for decision: Dictionary in unknown.decisions:
		check(decision.source=="hidden","unknown active old GPU history withholds even previously certified content slot "+str(decision.slot))
	host._presentation_previous_unknown = prior_unknown
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	var expired: Dictionary = exhausted_capture("unchanged-refresh-expired-after-withholding")
	check(not expired.previous_blend_active,"previous history expiry removes the old-texture obligation")
	for slot: int in range(DENSE_BODIES):
		check(expired.decisions[slot].source=="hidden",
			"history expiry cannot renew a hold after a withheld submission slot "+str(slot))
	lineage_controls["unchanged_refresh"] = {"material_revision":revision,
		"original_content_id":current,"current_content_id":content_id("current"),
		"previous_content_id":content_id("previous"),"real_upload_serial":host.last_uploaded_render_snapshot_serial,
		"controlled_deadline":true,"controlled_unknown_history":true}

func assert_clear_series(series: Array[Dictionary], label: String, same_material: bool) -> void:
	for slot: int in range(DENSE_BODIES):
		var visible: int = 0
		var first_visible: int = -1
		var last_selected: int = -1
		var advanced: int = 0
		var hidden_run: int = 0
		var max_hidden_run: int = 0
		for index: int in range(series.size()):
			var decision: Dictionary = series[index].decisions[slot]
			if decision.source!="hidden":
				visible += 1
				if first_visible<0: first_visible = index
				hidden_run = 0
				if int(decision.step)>last_selected: advanced += 1
				last_selected = int(decision.step)
			else:
				hidden_run += 1
				max_hidden_run = maxi(max_hidden_run,hidden_run)
				if same_material and first_visible>=0:
					check(false,label+" unchanged material cannot lose certified visible slot "+str(slot))
		check(first_visible>=0 and first_visible<DENSE_BODIES,label+" no permanently starved slot "+str(slot))
		check(advanced>=2,label+" clear actor timeline continues advancing slot "+str(slot))
		if not same_material:
			# A real OS scheduling interruption can consume the guard deadline.
			# Keep that refusal in evidence, but reject repeated refresh flicker.
			check(visible>=series.size()-1 and max_hidden_run<=1,
				label+" no repeated publication flicker slot "+str(slot))

func dense_series() -> void:
	print("TEMPORAL_DENSE_STAGE eight real actors")
	if not await install_dense(): return
	var steady: Array[Dictionary] = []
	for index: int in range(16):
		controlled_step(Vector2(float(index)*0.05,0))
		steady.append(capture("dense-steady-"+str(index),true))
		await process_frame
	assert_clear_series(steady,"steady",true)
	await identical_refresh_budget_controls()
	var refreshed: Array[Dictionary] = []
	for index: int in range(6):
		if not await refresh_receipt(): break
		controlled_step(Vector2(0.85+float(index)*0.05,0))
		refreshed.append(capture("dense-refresh-"+str(index),true))
		await process_frame
	check(refreshed.size()==6,"all six actual material publications exercised")
	assert_clear_series(refreshed,"refresh",false)
	# Release the controlled stimulus. Gravity, terrain contact, native receipts,
	# sampling and render cadence now run through the unmodified Main callbacks.
	var initial_tick: int = host.physical_actor_session.tick
	var initial_native: int = host.latest_snapshot.tick_index
	contact_slots.clear()
	Engine.max_fps = 60
	host.paused = false
	host.physical_actor_session.set_suspended(false)
	host.engine_lab_wait_native_sample = true
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	host._publish_physical_body_state()
	host.update_worker_frame_state()
	host.set_process(true)
	host.set_physics_process(true)
	await process_frame
	var live_visible: Dictionary = {}
	var live_steps: Dictionary = {}
	print("TEMPORAL_DENSE_STAGE ordinary Main contact")
	# The previously configured 1Hz native clock can retain its next deadline
	# for up to a second. Wait for measured work and all real contacts, with a
	# wall-clock deadline, instead of inferring progress from nominal FPS.
	var started: int = Time.get_ticks_msec()
	var index: int = 0
	var completed: bool = false
	while Time.get_ticks_msec()-started<10000:
		await process_frame
		if index==60: ui._camera.select(0)
		var row: Dictionary = capture("ordinary-contact-"+str(index),false,index%6==0)
		for decision: Dictionary in row.decisions:
			if decision.source!="hidden":
				live_visible[decision.slot] = int(live_visible.get(decision.slot,0))+1
				live_steps[decision.slot] = int(decision.step)
		index += 1
		if Time.get_ticks_msec()-started>=2000 and index>=75 \
				and host.physical_actor_session.tick>=initial_tick+24 \
				and host.latest_snapshot.tick_index>=initial_native+24 \
				and contact_slots.size()==DENSE_BODIES:
			completed = true
			break
	host.set_process(false)
	host.set_physics_process(false)
	ordinary_progress = {"elapsed_msec":Time.get_ticks_msec()-started,"observed_main_frames":index,
		"rapier_before":initial_tick,"rapier_after":host.physical_actor_session.tick,
		"native_before":initial_native,"native_after":host.latest_snapshot.tick_index,
		"contact_slots":contact_slots.keys(),"completed":completed}
	check(completed,"ordinary Main completes real step, native tick, elapsed-time and eight-body contact conditions")
	check(host.physical_actor_session.tick>=initial_tick+24,"ordinary Main advances actual Rapier simulation")
	check(host.latest_snapshot.tick_index>=initial_native+24,"ordinary Main advances actual native World")
	check(contact_slots.size()==DENSE_BODIES,"all eight unforced bodies reach actual Rapier terrain contact")
	for slot: int in range(DENSE_BODIES):
		check(int(live_visible.get(slot,0))>0 and int(live_steps.get(slot,-1))>initial_tick,
			"ordinary contact actor remains present and progresses slot "+str(slot))
		var pose: Transform2D = host.physical_actor_session.bridge.body_transform(slot)
		check(pose.origin.y>spawns[slot].y+0.1,"actual gravity displacement survives presentation for slot "+str(slot))

func lineage_native_paint(cell: Vector2i, material: int) -> bool:
	host.paused = true
	host.update_worker_frame_state()
	if not check(await until(func() -> bool:
		var value: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
		return value!=null and value.paused),"content-lineage native owner acknowledges pause"): return false
	var state: Dictionary = host.simulation_worker.paint_state()
	var queued: Dictionary = host.simulation_worker.paint_queue({"kind":"edit",
		"cells":PackedInt32Array([cell.x,cell.y,material]),"expected_generation":state.generation,
		"expected_revision":state.revision,"expected_tick":state.tick})
	if not check(queued.get("status","")=="queued","content-lineage real native PAINT queued"): return false
	if not check(await until(func() -> bool: return host.simulation_worker.paint_state().receipt_ready),
		"content-lineage native PAINT receipt completes"): return false
	var receipt: Dictionary = host.simulation_worker.paint_take_result()
	lineage_native_edits.append({"cell":[cell.x,cell.y],"material":material,"receipt":receipt})
	if not check(receipt.get("status","")=="completed" and receipt.get("after")==PackedInt32Array([material]),
		"content-lineage authoritative edit readback matches requested material"): return false
	return check(await until(func() -> bool:
		host.consume_worker_snapshot()
		return host.image.get_pixel(cell.x,cell.y).r8==material),
		"content-lineage material reaches genuine texture upload without resolving a new pose")

func lineage_renew_native_receipt() -> bool:
	# PAINT invalidates the old actor/material receipt. Obtain a genuine native
	# completion for the actual away pose, retaining the existing presentation
	# certificate by consuming snapshots without running Main's resolver.
	host.physical_actor_session.set_suspended(false)
	host.paused = false
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	host._publish_physical_body_state()
	var sample: int = host._workbench_wait_sample
	host.update_worker_frame_state()
	var ready: bool = await until(func() -> bool:
		host.consume_worker_snapshot()
		var frame: Dictionary = host.workbench_display_frame()
		return host._valid_workbench_mask_frame(frame) and frame.instances.has(1) \
			and frame.instances[1].get("sample",-1)==sample)
	host.paused = true
	host.update_worker_frame_state()
	return check(ready,"content-lineage safety query uses a new valid actual native actor/material receipt")

func changed_previous_content_controls() -> void:
	print("TEMPORAL_DENSE_STAGE actual current/previous content subset")
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	spawns.assign([Vector2(240,240)])
	setup.actors = [Setup.instance("needle",1,spawns[0])]
	setup.next_id = 2
	setup.selected = 1
	if not await install(setup): return
	ui._camera.select(0)
	controlled_step(Vector2(5,0))
	var established: Dictionary = capture("content-A-certified",true)
	if not check(established.valid and established.decisions[0].source=="live",
		"real clear Needle pose obtains initial content certificate"): return
	var anchor: Transform2D = host.workbench_presentation_frame.poses[0]
	var anchor_step: int = host.workbench_presentation_frame.selected_steps[0]
	var continuously_visible_certificate: Dictionary = host._workbench_presentation_state[0].duplicate(true)
	var clear_bytes: PackedByteArray = host.image.get_data()
	var content_a: int = content_id("current")
	controlled_step(Vector2(30,0))
	var away: Transform2D = host.physical_actor_session.bridge.body_transform(0)
	var physical_tick: int = host.physical_actor_session.tick
	# This cell is inside the certified visual pose, outside both the old native
	# mask at x240 and actual away RID at x270. Ordinary native PAINT admits it.
	var cell := Vector2i(246,240)
	if not await lineage_native_paint(cell,98): return
	if not await lineage_renew_native_receipt(): return
	check(host._workbench_presentation_state[0].pose==anchor,
		"renewing actual native receipt does not overwrite retained visual certificate")
	var rectangles: Array = host.physical_actor_session.bridge._rects[0]
	check(not footprint_clear(anchor,rectangles,host.image) and footprint_clear(away,rectangles,host.image),
		"actual painted B obstructs certified anchor footprint while leaving actual away body clear")
	var content_b: int = content_id("current")
	if content_a>=0:
		check(content_b!=content_a,"actual newly painted material has a distinct content identity")
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	var changed: Dictionary = exhausted_capture("content-B-current-exhausted")
	changed["expected_safety_withholding"] = true
	check(changed.valid and changed.decisions[0].source=="hidden",
		"new material under certified footprint withholds despite valid actual native receipt")
	if not await lineage_native_paint(cell,0): return
	if not await lineage_renew_native_receipt(): return
	check(host.image.get_data()==clear_bytes and host._presentation_previous_image!=null \
		and host._presentation_previous_image.get_pixel(cell.x,cell.y).r8==98,
		"native erase restores exact clear A while genuine previous GPU source retains obstructing B")
	check(footprint_clear(anchor,rectangles,host.image) \
		and not footprint_clear(anchor,rectangles,host._presentation_previous_image),
		"actual anchor footprint is clear in current A and obstructed by genuine previous B")
	if DisplayServer.get_name()!="headless":
		var gpu_old: Image = host.previous_texture.get_image()
		check(gpu_old!=null and gpu_old.get_pixel(cell.x,cell.y).r8==98,
			"actual previous GPU texture retains erased Marble in content-B negative")
	if content_a>=0:
		check(content_id("current")==content_a and content_id("previous")==content_b,
			"A-to-B-to-A upload reuses exact current A identity and preserves genuine previous B identity")
	host.render_snapshot_hz = 1
	host.snapshot_blend_start_usec = Time.get_ticks_usec()
	var old: Dictionary = exhausted_capture("content-A-current-B-previous-exhausted")
	old["expected_safety_withholding"] = true
	check(old.valid and old.previous_blend_active and old.decisions[0].source=="hidden",
		"valid clear-current receipt cannot reuse A-only certificate while actual obstructing B remains visible")
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	var expired: Dictionary = exhausted_capture("content-A-previous-B-expired-after-withholding")
	check(expired.valid and not expired.previous_blend_active and expired.decisions[0].source=="hidden",
		"expired B cannot revive a previously withheld pose at exhausted deadline")
	# The same retained certificate covers A once B expires, but it is only
	# sufficient for a hold when there was no intervening withheld submission.
	host._workbench_presentation_state[0] = continuously_visible_certificate
	var continuously_visible: Dictionary = exhausted_capture("content-A-previous-B-expired-continuous-control")
	check(continuously_visible.valid and continuously_visible.decisions[0].source=="held" \
		and host.workbench_presentation_frame.poses.get(0)==anchor and continuously_visible.decisions[0].step==anchor_step,
		"continuously visible current-origin A can hold when B expires")
	check(host.physical_actor_session.tick==physical_tick and host.physical_actor_session.bridge.body_transform(0)==away,
		"content publication and certificate holds leave completed Rapier state untouched")
	check(Vector2(host.workbench_presentation_frame.follow_target)==anchor.origin,
		"Follow targets held certified A rather than independently sampled away body")
	lineage_controls["changed_previous"] = {"content_a":content_a,"content_b":content_b,
		"current_content_id":content_id("current"),"previous_content_id":content_id("previous"),
		"certified_step":anchor_step,"actual_rapier_step":physical_tick,"all_receipts_native":true}

func supported_compound() -> void:
	print("TEMPORAL_DENSE_STAGE supported 128-square compound")
	# This goes through the shipped bounded registry validation, normal setup,
	# real Rapier geometry and native proxy receipts. No authoring bypass.
	var registry: Dictionary = registry_before.duplicate(true)
	var record: Dictionary = Fleet.authoring_record(Fleet.index_for_id("scooper"))
	record.id = "temporal_dense_128"
	record.name = "Temporal 128 compound"
	record.hull = {"kind":"rect_union","rects":[[-64,-64,128,4],[-64,-60,4,124],[60,-60,4,124]]}
	registry.records.append(record)
	if not check(Fleet.restore_registry(registry),"existing authoring admits bounded 128-square compound"): return
	var index: int = Fleet.index_for_id(record.id)
	check(Fleet.bounds(index).size.is_equal_approx(Vector2(128,128)) and Fleet.collision_rects(index).size()==3,
		"validated compound has real 128-square bounds and three native proxies")
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	spawns.assign([Vector2(256,256)])
	setup.actors = [Setup.instance(record.id,1,spawns[0])]
	setup.next_id = 2
	setup.selected = 1
	if not await install(setup): return
	var admitted: bool = false
	for sample: int in range(8):
		controlled_step(Vector2(float(sample)*0.1,0))
		var row: Dictionary = capture("compound-128-"+str(sample),true)
		var decision: Dictionary = row.decisions[0]
		if decision.source!="hidden": admitted = true
		elif admitted: check(false,"large clear compound keeps its safe visible certificate")
		await process_frame
	check(admitted and int(last_steps.get(0,-1))>=6,"supported large compound does not permanently disappear at fine-scan cap")

func permanent_budget_refusal() -> void:
	print("TEMPORAL_DENSE_STAGE permanent bootstrap budget refusal")
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	# Distinct real shapes identify the faulted actor without changing any RID.
	setup.actors = [Setup.instance("scooper",1,Vector2(180,180)),Setup.instance("needle",2,Vector2(300,180))]
	setup.next_id = 3
	setup.selected = 2
	if not await install(setup): return
	for index: int in range(4):
		host._process(1.0/60.0)
		await process_frame
	if not check(host._workbench_presentation_state.has(1),"budget peer initially has actual safe certificate"): return
	var bridge = host.physical_actor_session.bridge
	var physical_step: int = host.physical_actor_session.tick
	var physical_pose: Transform2D = bridge.body_transform(1)
	host.exhaust_first_body = true
	host._workbench_presentation_state.erase(0)
	var visible: int = 0
	var hidden_run: int = 0
	var max_hidden_run: int = 0
	var decisions: Array[Dictionary] = []
	for index: int in range(12):
		# This presentation-only invalidation models revalidation after upload.
		# Native bytes and physical state are unchanged, and the peer's real
		# clearance must succeed again before it is allowed to appear.
		host._workbench_presentation_state[1].material_contents = []
		host.guard_queries_in_frame = 0
		host._process(1.0/60.0)
		var frame: Dictionary = host.workbench_presentation_frame
		var shown: bool = frame.poses.has(1)
		if shown:
			visible += 1
			hidden_run = 0
		else:
			hidden_run += 1
			max_hidden_run = maxi(max_hidden_run,hidden_run)
		check(not frame.poses.has(0),"unproven expensive body remains suppressed "+str(index))
		check(int(host.workbench_presentation_last.cells_examined)<=host.PRESENTATION_FRAME_SCAN_BUDGET,
			"faulted shared guard budget remains bounded "+str(index))
		if shown:
			check(frame.poses[1].is_equal_approx(physical_pose) and int(frame.selected_steps[1])==physical_step,
				"budget peer retains proven actual pose and monotonic step "+str(index))
		decisions.append({"frame":index,"visible":shown,"source":frame.sources.get(1,"hidden"),
			"reason":frame.reasons.get(1,""),"peer_first_turns":host.peer_first_turns})
		await process_frame
	host.exhaust_first_body = false
	check(host.exhausted_queries>=12,"bootstrap fault consumes guard budget in every frame")
	# Opportunity is deterministic; an OS interruption can still refuse an
	# individual real query at the normal 2 ms deadline. Do not turn that
	# legitimate refusal into a machine-speed-dependent scheduling oracle.
	check(host.peer_first_turns==6,"retained suppressed peer gets first budget opportunity once per full actor rotation")
	check(visible>=2,"recurring budget opportunities produce actual guarded peer presentations")
	check(host.physical_actor_session.tick==physical_step and bridge.body_transform(1).is_equal_approx(physical_pose),
		"guard scheduling leaves stopped authoritative physical state unchanged")
	budget_fairness = {"frames":decisions,"peer_first_turns":host.peer_first_turns,
		"visible_frames":visible,"max_hidden_run":max_hidden_run,
		"scope":"Deterministic exhaustion for permanently unadmitted body; retained peer uses unchanged actual clearance guard."}

func timing_summary() -> Dictionary:
	var costs: Array[int] = []
	var counts: Dictionary = {}
	var hidden: int = 0
	var visible: int = 0
	for row: Dictionary in rows:
		costs.append(int(row.resolve_usec))
		for decision: Dictionary in row.decisions:
			counts[decision.reason] = int(counts.get(decision.reason,0))+1
			if decision.source=="hidden": hidden += 1
			else: visible += 1
	costs.sort()
	return {"sample_count":costs.size(),"resolve_median_usec":costs[costs.size()/2] if not costs.is_empty() else 0,
		"resolve_p95_usec":costs[mini(costs.size()-1,ceili(costs.size()*0.95)-1)] if not costs.is_empty() else 0,
		"resolve_max_usec":costs.back() if not costs.is_empty() else 0,"visible_body_frames":visible,
		"hidden_body_frames":hidden,"reasons":counts,"contact_slots":contact_slots.keys(),
		"scope":"Observed production-stage cost; qualification includes observer work and is not a frame-rate benchmark."}

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	source_before = identity()
	check(str(source_before.native_runtime_sha256).length()==64,"actual native runtime identity recorded")
	registry_before = Fleet.registry_snapshot()
	host = load("res://main.tscn").instantiate()
	host.set_script(BudgetHost)
	root.add_child(host)
	root.size = Vector2i(1280,800)
	ui = host.shared_workbench
	if check(await until(func() -> bool: return ui!=null and not ui.applied.is_empty()),"mounted real Workbench ready"):
		await dense_series()
		await changed_previous_content_controls()
		await permanent_budget_refusal()
		await supported_compound()
	check(Fleet.restore_registry(registry_before),"authored registry restored after bounded fixture")
	check(source_before==identity(),"executed source and native runtime unchanged during fixture")
	var summary: Dictionary = timing_summary()
	var file: FileAccess
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		file = FileAccess.open(output.path_join("temporal-dense.json"),FileAccess.WRITE)
		check(file!=null,"dense evidence file opens")
	var result: Dictionary = {"schema":"workbench-temporal-dense-v1","checks":checks,"failures":failures,
		"source_identity":source_before,"summary":summary,"ordinary_progress":ordinary_progress,"observations":rows,
		"budget_fairness":budget_fairness,
			"lineage_controls":lineage_controls,"lineage_native_edits":lineage_native_edits,
		"scope":"Actual mounted Main/native World/Rapier. Eight-body near-contact, native full refresh, ordinary callbacks and authored compound; labelled exhausted-deadline/history controls and native A-to-B-to-A safety; no clearance retries or physical GPU claim."}
	if file!=null:
		file.store_string(JSON.stringify(result,"  ")+"\n")
		file.close()
	for key: String in saved_environment: OS.set_environment(key,str(saved_environment[key]))
	Engine.max_fps = previous_max_fps
	host.queue_free()
	await process_frame
	await process_frame
	print("TEMPORAL_DENSE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"observations":rows.size(),"summary":summary,"budget_fairness":budget_fairness}))
	quit(int(not failures.is_empty()))
