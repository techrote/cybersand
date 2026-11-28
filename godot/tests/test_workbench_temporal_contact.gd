extends SceneTree

# Recorded Needle/Marble counterexamples from the source-matched 2048-square
# fixture. Regenerate its real native chunk, apply the exact authored edits,
# then install those bytes through a small ordinary native Workbench recipe.
# Controlled RID poses reproduce the guard query; this is not a second flight
# simulation or permission to change authoritative physical trajectories.
const Setup = preload("res://scripts/workbench_setup.gd")
const Reference = preload("res://scripts/engine_lab_reference_fixture.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const Trace = preload("res://scripts/workbench_pose_trace.gd")
const COMPOSITED_SHA := "7d719ff951991ea9290a20cb62801ddaadde3c2b5dc68bd679320971c32f7884"
const CHUNK_RECEIPT := "4f7bd7d50e7456f4"
const CASES := [
	{"name":"needle-64-to-72","before":Transform2D(1.9279533624649,Vector2(200.014709472656,220.216430664062)),
		"after":Transform2D(2.43390607833862,Vector2(200.992767333984,224.778594970703))},
	{"name":"needle-96-to-104","before":Transform2D(-2.88728547096252,Vector2(202.664947509766,234.123870849609)),
		"after":Transform2D(3.04979228973389,Vector2(201.755477905273,234.575927734375))}]
var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var native_receipts: Array[Dictionary] = []
var source_before: Dictionary = {}
var saved_environment: Dictionary = {}
var output: String = ""
var native_pixels := PackedByteArray()

func _initialize() -> void:
	output = OS.get_environment("CYBERSAND_TEMPORAL_CONTACT_OUTPUT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--temporal-contact-evidence="):
			output = argument.trim_prefix("--temporal-contact-evidence=")
	for key: String in ["CYBERSAND_DIAG_PRESENTATION","CYBERSAND_DIAG_RENDER_CADENCE","CYBERSAND_DIAG_FLYER_POSE",
			"CYBERSAND_DIAG_MATERIAL_TIMING"]:
		saved_environment[key] = OS.get_environment(key)
		OS.set_environment(key,"")
	_run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("TEMPORAL_CONTACT: "+reason)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func identity() -> Dictionary:
	var result: Dictionary = {"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"godot":Engine.get_version_info().string,"display":DisplayServer.get_name()}
	for path: String in ["res://scripts/main.gd","res://scripts/workbench_presentation_coherence.gd",
			"res://scripts/physical_actor_session.gd","res://scripts/workbench_physics_bridge.gd",
			"res://tests/test_workbench_temporal_contact.gd",Reference.PATH]:
		result[path] = FileAccess.get_sha256(path)
	var native: String = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" \
		if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	result.native_sha256 = FileAccess.get_sha256(native)
	return result

func material_recipe() -> Dictionary:
	if not check(FileAccess.get_sha256(Reference.PATH)==Reference.FILE_SHA256,"exact owner fixture JSON identity"): return {}
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Reference.PATH))
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(raw.generation.recipe)
	if not check(configured.get("ok",false),"real native generator configured"): return {}
	var chunk: Dictionary = generator.generate_chunk(Vector2i(1,1))
	if not check(chunk.get("ok",false) and chunk.get("receipt_hash","")==CHUNK_RECEIPT \
		and chunk.receipt_hash==raw.generation.receipt_hashes[17],"native chunk agrees with exact original receipt"): return {}
	native_pixels = chunk.cells.duplicate()
	check(native_pixels.size()==128*128 and raw.starting_setup.edits.size()==705,
		"original chunk and complete 705-edit source available")
	for edit: Array in raw.starting_setup.edits:
		for y: int in range(maxi(128,int(edit[1])),mini(256,int(edit[1])+int(edit[3]))):
			for x: int in range(maxi(128,int(edit[0])),mini(256,int(edit[0])+int(edit[2]))):
				native_pixels[(y-128)*128+x-128] = int(edit[4])
	if not check(Store.digest(native_pixels)==COMPOSITED_SHA,"exact native material plus authored edits reproduced"): return {}
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors = [Setup.instance("needle",1,Vector2(210,220))]
	setup.next_id = 2
	setup.selected = 1
	for y: int in range(128):
		var x: int = 0
		while x<128:
			var material: int = native_pixels[y*128+x]
			var start: int = x
			while x<128 and native_pixels[y*128+x]==material: x += 1
			if material!=0: setup.edits.append([128+start,128+y,x-start,1,material])
	native_receipts.append({"chunk":[1,1],"receipt_hash":chunk.receipt_hash,"authored_edits":705,
		"composited_sha256":Store.digest(native_pixels),"native_constructor_runs":setup.edits.size()})
	return setup

func install(setup: Dictionary, preserve: bool=false) -> bool:
	host.paused = true
	host.update_worker_frame_state()
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	host.engine_lab_set_render_hz(60)
	host.set_process(true)
	host.set_physics_process(true)
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup,preserve),"ordinary Workbench construction requested"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session!=null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		"native World, real Needle and valid material-bound receipt adopted"): return false
	host.set_process(false)
	host.set_physics_process(false)
	host.engine_lab_wait_native_sample = false
	host.simulation_worker.set_engine_lab_pixel_pacing(1,false)
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	ui._camera.select(1)
	ui._set_view(Vector2(80,155),Vector2i(240,135))
	return true

func place_exact(pose: Transform2D, completed_steps: int=0) -> void:
	var session = host.physical_actor_session
	var bridge = session.bridge
	session.set_suspended(false)
	var before: int = session.tick
	for tick: int in range(completed_steps):
		session.advance(bridge.fixed_delta())
		bridge.step()
		session.complete_step()
	bridge.reset_body(0,pose.origin,pose.get_rotation())
	var direct: Transform2D = PhysicsServer2D.body_get_state(bridge._body_rids[0],PhysicsServer2D.BODY_STATE_TRANSFORM)
	check(direct.is_equal_approx(pose) and bridge.body_transform(0).is_equal_approx(pose),
		"controlled recorded pose exists in actual Rapier RID and bridge")
	check(session.tick==before+completed_steps,"only completed real Rapier steps advance presentation clock")

func prime_start(pose: Transform2D) -> bool:
	place_exact(pose)
	# Retain current terrain and actual RID rotation through the normal owner
	# transaction. Its new native sample genuinely binds the exact start pose.
	if not await install(ui.applied.duplicate(true),true): return false
	var entry: Dictionary = host.workbench_display_frame().instances.get(1,{})
	return check(entry.get("pose") is Transform2D and Transform2D(entry.pose).is_equal_approx(pose),
		"native receipt contains recorded start orientation and position")

func capture(label: String, legacy: bool=false) -> Dictionary:
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy" if legacy else "coherent")
	host.paused = false
	host._process(1.0/60.0)
	host.paused = true
	host.update_worker_frame_state()
	var frame: Dictionary = host.workbench_presentation_frame
	var row: Dictionary = {"label":label,"policy":frame.policy,"valid":frame.valid,
		"source":frame.sources.get(0,"hidden"),"reason":frame.reasons.get(0,frame.reason),
		"selected":Trace.pose_json(frame.poses.get(0)),"selected_step":frame.selected_steps.get(0,-1),
		"desired_step":frame.desired_steps.get(0,-1),"follow":Trace.xy(frame.follow_target),
		"session":frame.session,"epoch":frame.epoch,"native_tick":frame.native_tick,
		"material_revision":frame.material_revision,"upload_serial":frame.upload_serial,
		"previous_active":frame.previous_blend_active,"guard":host.workbench_presentation_last.duplicate(true),
		"resolve_usec":frame.resolve_usec}
	observations.append(row)
	check(int(row.guard.get("cells_examined",0))<=host.PRESENTATION_FRAME_SCAN_BUDGET,
		label+" shared cell bound retained")
	if not legacy and frame.poses.has(0):
		check(Vector2(frame.follow_target).is_equal_approx(frame.poses[0].origin),label+" Follow tracks selected pose")
		check(not host.physical_actor_overlay._parts.is_empty() \
			and Transform2D(host.physical_actor_overlay._parts[0].transform).is_equal_approx(frame.poses[0]),
			label+" actual overlay uses resolved pose")
	return row

func oracle(before: Transform2D, after: Transform2D, refine: bool, old: Image=null,
		capacity: int=24000, deadline: int=0, unknown: bool=false) -> Dictionary:
	return Clearance.assess(before,after,host.physical_actor_session.bridge._rects[0],host.image,{},unknown,
		old!=null or unknown,mini(capacity,Clearance.MAX_SCAN_CELLS),deadline,old,true,
		host.image.get_data(),old.get_data() if old!=null else PackedByteArray(),capacity,refine)

func recorded_motion(case: Dictionary) -> void:
	print("TEMPORAL_CONTACT_STAGE ",case.name)
	if not await prime_start(case.before): return
	var anchor: Dictionary = capture(case.name+"-anchor")
	# Initial certification may legitimately defer on the shared frame budget.
	# Keep each actual submission; retry only that explicit bounded deferral.
	for attempt: int in range(2):
		if anchor.source=="live" or anchor.reason not in ["shared_budget","time_budget","scan_budget"]: break
		await process_frame
		anchor = capture(case.name+"-anchor-attempt-"+str(attempt+2))
	if not check(anchor.source=="live","recorded initial footprint is visibly certified"): return
	var coarse: Dictionary = oracle(case.before,case.after,false)
	var refined: Dictionary = oracle(case.before,case.after,true)
	check(not coarse.safe and coarse.reason=="material_in_swept_mask",case.name+" original coarse proof refuses actual Marble")
	check(refined.safe and refined.reason=="refined_swept_mask" and refined.get("refined",false),
		case.name+" bounded conservative refinement clears actual native material")
	check(refined.steps==Clearance.MAX_SWEEP_STEPS and refined.steps==32 \
		and refined.coarse_steps<refined.steps and refined.dilation_cells<refined.coarse_dilation_cells,
		case.name+" same coverage proof narrows dilation within 32-interval cap")
	check(refined.scanned>=coarse.scanned and refined.scanned<=host.PRESENTATION_FRAME_SCAN_BUDGET,
		case.name+" both passes charged to shared cell budget")
	place_exact(case.after,8)
	var selected: Dictionary = capture(case.name+"-coherent")
	check(selected.valid and selected.source=="live" and selected.reason=="refined_swept_mask",
		case.name+" real Main advances directly to desired live pose")
	check(int(selected.guard.get("refined_queries",0))==1 and int(selected.guard.get("refined_clear",0))==1,
		case.name+" Main records its bounded refinement")
	check(selected.selected_step==selected.desired_step and selected.selected_step>anchor.selected_step,
		case.name+" no introduced visual hold or temporal fallback")
	var legacy: Dictionary = capture(case.name+"-original",true)
	check(legacy.valid and legacy.source=="mask_bound" and legacy.reason=="material_in_swept_mask" \
		and int(legacy.guard.get("blocked_material",0))>0,
		case.name+" retained actual Main original mode reproduces coarse material veto")
	check(host.workbench_presentation_frame.poses[0].is_equal_approx(case.before),
		case.name+" original mode falls back to real older native start pose")
	observations.append({"label":case.name+"-proof","coarse":coarse,"refined":refined})

func bounded_and_collision_controls() -> void:
	var before: Transform2D = CASES[0].before
	var after: Transform2D = CASES[0].after
	var refused_refinement: bool = false
	for capacity: int in [1,8,16,32,64,96,128,160,192,224,256,384,512,1024,12000,24000]:
		var result: Dictionary = oracle(before,after,true,null,capacity)
		check(int(result.scanned)<=capacity,"cumulative refined work respects capacity "+str(capacity))
		if result.get("refined",false) and not result.safe and result.reason=="scan_budget": refused_refinement = true
		if result.safe: check(result.steps<=32,"successful bounded proof never exceeds sample cap")
		observations.append({"label":"capacity-"+str(capacity),"oracle":result})
	check(refused_refinement,"insufficient remaining budget vetoes a second proof rather than granting clearance")
	var expired: Dictionary = oracle(before,after,true,null,24000,Time.get_ticks_usec()-1)
	check(not expired.safe and expired.reason=="time_budget" and not expired.get("refined",false),
		"expired common deadline is never retried as refinement")
	var unknown: Dictionary = oracle(before,after,true,null,24000,0,true)
	check(not unknown.safe and unknown.reason=="previous_texture_unbounded" and not unknown.get("refined",false),
		"unknown previous GPU texture is never bypassed or retried")
	var crossing_pose := Transform2D(0,Vector2(190,230))
	var crossing: Dictionary = oracle(CASES[1].before,crossing_pose,true)
	check(not crossing.safe and crossing.reason=="material_in_swept_mask",
		"genuine continuous crossing of actual Marble still refuses")
	observations.append({"label":"negative-controls","expired":expired,"unknown":unknown,"crossing":crossing})
	place_exact(CASES[1].before)
	var anchor: Dictionary = capture("true-collision-anchor")
	check(anchor.valid and anchor.source=="live","true crossing begins at certified actual native pose")
	place_exact(crossing_pose,1)
	var rejected: Dictionary = capture("true-collision-rejected")
	check(rejected.valid and rejected.source=="held" and rejected.reason=="material_in_swept_mask",
		"real Main with valid receipt vetoes true collision and retains safe pose")
	check(host.workbench_presentation_frame.poses[0].is_equal_approx(CASES[1].before),
		"true collision never draws desired intersecting pose")

func paint(cell: Vector2i, material: int) -> bool:
	host.paused = true
	host.update_worker_frame_state()
	host.set_process(true)
	var state: Dictionary = host.simulation_worker.paint_state()
	var queued: Dictionary = host.simulation_worker.paint_queue({"kind":"edit",
		"cells":PackedInt32Array([cell.x,cell.y,material]),"expected_generation":state.generation,
		"expected_revision":state.revision,"expected_tick":state.tick})
	if not check(queued.get("status","")=="queued","real native obstruction edit queued"): return false
	if not check(await until(func() -> bool: return host.simulation_worker.paint_state().receipt_ready),
		"real native obstruction edit completes"): return false
	var receipt: Dictionary = host.simulation_worker.paint_take_result()
	native_receipts.append({"cell":[cell.x,cell.y],"material":material,"receipt":receipt})
	if not check(receipt.get("status","")=="completed" and receipt.get("after")==PackedInt32Array([material]),
		"authoritative native edit readback matches obstruction"): return false
	if not check(await until(func() -> bool: return host.image.get_pixel(cell.x,cell.y).r8==material),
		"native obstruction edit reaches actual texture upload"): return false
	host.set_process(false)
	return true

func changed_material_controls() -> void:
	print("TEMPORAL_CONTACT_STAGE current and genuine previous material")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	var before: Transform2D = CASES[1].before
	var after: Transform2D = CASES[1].after
	var cell := Vector2i(201,234)
	var away := Transform2D(0,Vector2(220,220))
	# Native PAINT correctly refuses body-covered cells. Move and retain the
	# actual actor first, so both RID and the native mask permit ordinary edits.
	if not await prime_start(away): return
	check(host.image.get_pixel(cell.x,cell.y).r8==0,"native obstruction control begins Empty")
	if not await paint(cell,98): return
	place_exact(after)
	var current: Dictionary = oracle(before,after,true)
	check(not current.safe and current.reason=="material_in_swept_mask",
		"refinement rejects newly painted actual Marble in true footprint")
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	var occupied: Dictionary = capture("actual-current-obstruction")
	check(occupied.source=="hidden","Main withholds visually obstructed or invalidated native receipt")
	place_exact(away)
	if not await paint(cell,0): return
	place_exact(after)
	var previous: Image = host._presentation_previous_image
	if not check(previous!=null and previous!=host.image and previous.get_pixel(cell.x,cell.y).r8==98,
		"erasure retains genuine old-only Marble in distinct GPU previous source"): return
	check(host.image.get_pixel(cell.x,cell.y).r8==0,"current texture is genuinely cleared")
	if DisplayServer.get_name()!="headless":
		var gpu: Image = host.previous_texture.get_image()
		check(gpu!=null and gpu.get_pixel(cell.x,cell.y).r8==98,"actual old GPU texture contains erased Marble")
	host.render_snapshot_hz = 1
	host.snapshot_blend_start_usec = Time.get_ticks_usec()
	var previous_receipt: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec()).previous
	check(previous_receipt.get("generation",-1) == host.last_uploaded_world_generation,
		"actual previous-texture obstruction has a native same-World receipt")
	var old: Dictionary = oracle(before,after,true,previous)
	check(not old.safe and old.reason=="material_in_swept_mask",
		"refinement rejects genuine previous-texture obstruction despite current clearance")
	var active: Dictionary = capture("actual-previous-obstruction")
	check(active.previous_active and active.source=="hidden","Main keeps unsafe previous-texture state withheld")
	var expired: Dictionary = oracle(before,after,true)
	check(expired.safe and expired.reason=="refined_swept_mask","cleared contact becomes provable only after old texture expires")
	observations.append({"label":"native-paint-guard","current":current,"previous":old,"expired":expired})
	await frozen_original_blend_control(after,cell)

func original_guard_attempts(frame: Dictionary, blend_active: bool) -> Dictionary:
	# A descheduled host can exhaust the unchanged 2 ms production allowance
	# before reaching the branch under test. Retry only explicit budget refusals;
	# a wrong admission or any other reason remains an immediate test failure.
	var result: Dictionary = {"poses":{},"reason":"","attempts":[]}
	for attempt: int in range(3):
		result.poses = host._safe_workbench_presentation_poses(frame,blend_active)
		result.reason = host._workbench_pose_trace_reasons.get(0,"")
		result.attempts.append({"attempt":attempt+1,"admitted":result.poses.has(0),
			"reason":result.reason,"cells_examined":host.workbench_presentation_last.cells_examined,
			"elapsed_usec":host.workbench_presentation_last.elapsed_usec})
		if result.reason not in ["shared_budget","time_budget","scan_budget"]: break
		if attempt<2: await process_frame
	return result

func frozen_original_blend_control(bound: Transform2D, cell: Vector2i) -> void:
	# A real replacement receipt supplies validity. Explicit previous-texture
	# uncertainty isolates the frozen-clock contract; the genuine old-only GPU
	# material witness is the separate PAINT/erase case above.
	if not await prime_start(bound): return
	var frame: Dictionary = host.workbench_display_frame()
	var material_hash: String = Store.digest(host.image.get_data())
	var previous_unknown: bool = host._presentation_previous_unknown
	host._presentation_previous_unknown = true
	# Tiny clear translation avoids the unrelated coarse near-contact veto.
	var desired := Transform2D(bound.get_rotation(),bound.origin+Vector2(0.02,0))
	place_exact(desired)
	host.snapshot_blend_start_usec = Time.get_ticks_usec()-2000000
	var wall_clock_active: bool = host.cadence_lod_enabled and host.render_snapshot_hz>0 \
		and float(Time.get_ticks_usec()-host.snapshot_blend_start_usec)<1000000.0/float(host.render_snapshot_hz)
	host.paused = false # The original guard's ordinary admission condition.
	var active: Dictionary = await original_guard_attempts(frame,true)
	var inactive: Dictionary = await original_guard_attempts(frame,false)
	host.paused = true
	host._presentation_previous_unknown = previous_unknown
	check(host._valid_workbench_mask_frame(frame),"frozen-blend control uses genuine valid native receipt")
	check(not wall_clock_active,"frozen-blend control wall clock has genuinely expired")
	check(not active.poses.has(0) and active.reason=="previous_texture_unbounded",
		"Original guard preserves frozen active previous-texture veto after wall-clock expiry")
	check(inactive.poses.has(0) and inactive.reason=="empty_swept_mask" \
		and Transform2D(inactive.poses[0]).is_equal_approx(desired),
		"Original guard admits the same actual clear pose when frozen blend is inactive")
	check(Store.digest(host.image.get_data())==material_hash,
		"frozen blend decision does not modify authoritative uploaded material")
	observations.append({"label":"original-frozen-blend-expiry","wall_clock_active":wall_clock_active,
		"previous_uncertainty_control":true,"current_material_sha256":material_hash,
		"active_admitted":active.poses.has(0),"active_reason":active.reason,"active_attempts":active.attempts,
		"inactive_admitted":inactive.poses.has(0),"inactive_reason":inactive.reason,"inactive_attempts":inactive.attempts,
		"session":frame.session,"epoch":frame.epoch,"world_generation":frame.world_generation,
		"material_revision":frame.revision,"native_tick":frame.tick,"native_sample":frame.instances[1].sample,
		"upload_serial":host.last_uploaded_render_snapshot_serial,
		"current_material_id":host.image.get_pixel(cell.x,cell.y).r8})

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	source_before = identity()
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	root.size = Vector2i(1280,800)
	ui = host.shared_workbench
	if check(await until(func() -> bool: return ui!=null and not ui.applied.is_empty()),"real Workbench ready"):
		var setup: Dictionary = material_recipe()
		if not setup.is_empty() and await install(setup):
			var installed := PackedByteArray()
			for y: int in range(128,256):
				for x: int in range(128,256): installed.append(host.image.get_pixel(x,y).r8)
			check(installed==native_pixels,"real native World upload matches every source chunk material ID")
			var rectangles: Array = host.physical_actor_session.bridge._rects[0]
			check(rectangles.size()==1 and Vector2(rectangles[0].size)==Vector2(7,3),"actual authored Needle hull is 7 by 3")
			for case: Dictionary in CASES: await recorded_motion(case)
			bounded_and_collision_controls()
			await changed_material_controls()
	check(source_before==identity(),"tested source and runtime remain unchanged")
	var file: FileAccess
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		file = FileAccess.open(output.path_join("temporal-contact.json"),FileAccess.WRITE)
		check(file!=null,"contact evidence file opens")
	var result: Dictionary = {"schema":"workbench-temporal-contact-v1","checks":checks,"failures":failures,
		"source_identity":source_before,"native_receipts":native_receipts,"observations":observations,
		"scope":"Actual Main/native World/Needle receipts, controlled recorded RID poses, coarse negative and conservative refinement positive; no application physics changes or physical GPU acceptance."}
	if file!=null:
		file.store_string(JSON.stringify(result,"  ")+"\n")
		file.close()
	for key: String in saved_environment: OS.set_environment(key,str(saved_environment[key]))
	host.queue_free()
	await process_frame
	await process_frame
	print("TEMPORAL_CONTACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"observations":observations.size()}))
	quit(int(not failures.is_empty()))
