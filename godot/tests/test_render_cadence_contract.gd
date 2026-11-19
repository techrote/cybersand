extends SceneTree

# Causal supplement to the original 2048² Needle Test It matrix. A genuine
# native full-refresh publication changes neither World bytes nor the actual
# Rapier body, yet the legacy large-patch history loses local occupancy and
# alternates mask/live presentation as its blend timer expires. Compare both
# implementations against the same immutable native receipt and RID pose.
# This frozen-state control is not a claim about live-flight/GPU acceptance.
const Setup = preload("res://scripts/workbench_setup.gd")
const Trace = preload("res://scripts/workbench_pose_trace.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const LIMIT_MSEC: int = 90000
const VIEW := Vector2i(240,135)
var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var output: String = ""
var original_cadence: String = ""
var original_pose: String = ""
var original_presentation: String = ""
var source_bytes: PackedByteArray = PackedByteArray()
var source_tick: int = -1
var native_edits: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--render-cadence-evidence="):
			output = arg.trim_prefix("--render-cadence-evidence=")
	if output.is_empty(): output = ProjectSettings.globalize_path("user://render-cadence-contract")
	DirAccess.make_dir_recursive_absolute(output)
	original_cadence = OS.get_environment("CYBERSAND_DIAG_RENDER_CADENCE")
	original_pose = OS.get_environment("CYBERSAND_DIAG_FLYER_POSE")
	original_presentation = OS.get_environment("CYBERSAND_DIAG_PRESENTATION")
	# This retained causal control isolates the earlier texture-history repair.
	# Keep its original mask fallback; the temporal fixture tests its successor.
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy")
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
	_run.call_deferred()

func check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("RENDER_CADENCE: "+description)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+LIMIT_MSEC
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func shown_pose() -> Transform2D:
	var parts: Array = host.physical_actor_overlay._parts
	return parts[0].transform if not parts.is_empty() else Transform2D(0,Vector2.INF)

func capture(label: String) -> Dictionary:
	var graphical: bool = DisplayServer.get_name() != "headless"
	var result: Dictionary = {"label":label,"graphical":graphical,
		"process_frame":Engine.get_process_frames(),"capture_path":""}
	if graphical:
		await RenderingServer.frame_post_draw
		var screen: Image = root.get_texture().get_image()
		if check(screen!=null and not screen.is_empty(),label+" actual framebuffer available"):
			var path: String = output.path_join(label+".png")
			check(screen.save_png(path)==OK,label+" original framebuffer written")
			result.capture_path=path
			result.capture_sha256=FileAccess.get_sha256(path)
	else:
		await process_frame
	return result

func _arm(mode: String) -> bool:
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE",mode)
	host.paused=true
	host.update_worker_frame_state()
	host.set_process(true)
	host.set_physics_process(true)
	var old_serial: int = host.last_uploaded_render_snapshot_serial
	host.simulation_worker.request_render_full_refresh()
	if not check(await until(func() -> bool:
		return host.last_uploaded_render_snapshot_serial>old_serial \
			and host.last_render_was_full_refresh \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		mode+" genuine native full-refresh receipt uploaded"):
		return false
	check(host.last_render_patch_bytes>host.PRESENTATION_PREVIOUS_PATCH_LIMIT,
		mode+" full native patch exceeds legacy global occupancy budget")
	check(host.image.get_data()==source_bytes,mode+" full refresh leaves material bytes identical")
	host.set_process(false)
	host.set_physics_process(false)
	# Main's presentation-only paused guard is opened, while the worker and
	# physics callbacks remain paused. No fabricated mask receipt is admitted.
	host.paused=false
	return true

func _exercise(mode: String) -> void:
	if not await _arm(mode): return
	var bridge = host.physical_actor_session.bridge
	var receipt: Dictionary = host.workbench_display_frame().duplicate(true)
	var bound: Transform2D = receipt.instances[1].pose
	var live := Transform2D(bound.get_rotation(),bound.origin+Vector2(0,-4))
	bridge.reset_body(0,live.origin,live.get_rotation())
	check(bridge.body_transform(0).is_equal_approx(live),mode+" actual Rapier RID pose controlled")
	check(host._valid_workbench_mask_frame(receipt),mode+" original native receipt still valid")
	var cpu_old: Image = host._presentation_previous_image
	check(host._presentation_previous_unknown if mode=="legacy" else \
		(cpu_old!=null and not host._presentation_previous_unknown),
		mode+" occupancy history has expected old/current contract")
	if mode!="legacy" and cpu_old!=null:
		check(cpu_old.get_data()==source_bytes,"retained previous CPU image equals actual native material")
		if DisplayServer.get_name()!="headless":
			var gpu_old: Image = host.previous_texture.get_image()
			check(gpu_old!=null and gpu_old.get_data()==cpu_old.get_data(),
				"previous GPU texture matches retained CPU image exactly")
	check(host.begin_workbench_pose_trace({"test":"render-cadence-contract","arm":mode}),
		mode+" original per-submission tracer armed")
	for camera: String in ["free","follow"]:
		ui._camera.select(0 if camera=="free" else 1)
		ui._set_view(bound.origin-Vector2(VIEW)*0.5,VIEW)
		host.update_camera(1.0/60.0)
		var before: Dictionary = {}
		for phase: String in ["active","expired"]:
			await process_frame
			# Both arms use the same documented timer positions. Real publication
			# and texture identity are fixed, so only availability of exact old
			# occupancy can explain an actor pose change.
			host.snapshot_blend_start_usec=Time.get_ticks_usec() \
				if phase=="active" else Time.get_ticks_usec()-2000000
			host._present_physical_actor_overlay(receipt)
			host.update_shader_parameters()
			var selected: Transform2D = shown_pose()
			var expect: Transform2D = bound if mode=="legacy" and phase=="active" else live
			check(selected.is_equal_approx(expect),"%s %s %s expected actual submitted pose" % [mode,camera,phase])
			var row: Dictionary = await capture("%s-%s-%s" % [mode,camera,phase])
			row.merge({"mode":mode,"camera":camera,"phase":phase,
				"native_tick":host.latest_snapshot.tick_index,"rapier_step":host.physical_actor_session.tick,
				"render_serial":host.last_uploaded_render_snapshot_serial,
				"render_revision":host.last_uploaded_revision,
				"selected":Trace.pose_json(selected),"live":Trace.pose_json(live),"bound":Trace.pose_json(bound),
				"camera_requested":Trace.xy(host.camera_origin),
				"camera_presented":Trace.xy(host.presentation_camera_origin()),
				"guard":host.workbench_presentation_last.duplicate(true),
				"projection":Trace.projection(selected,host.presentation_camera_origin(),
					host.view_content_rect(),host.current_view_size,host._world_view_screen_transform(),
					host.presentation_camera_screen_transform())})
			check(float(row.projection.residual_magnitude_px)<0.01,
				"%s %s %s shader/overlay projection agrees" % [mode,camera,phase])
			if phase=="active":
				before=row
				check(int(row.guard.get("blocked_unknown",0))==1 if mode=="legacy" else \
					int(row.guard.get("safe_live",0))==1,
					mode+" active blend identifies old-history refusal versus proven clearance")
			else:
				var jump: float = Vector2(row.projection.overlay_px[0],row.projection.overlay_px[1]).distance_to(
					Vector2(before.projection.overlay_px[0],before.projection.overlay_px[1]))
				row["phase_only_screen_jump_px"]=jump
				check(jump>4.0 if mode=="legacy" else jump<0.01,
					mode+" phase-only actor jump isolated with unchanged camera/material/physics")
			observations.append(row)
		check(host.image.get_data()==source_bytes and host.physical_actor_session.tick==source_tick,
			mode+" presentation comparison preserves World bytes and completed physical tick")
	var trace: Dictionary = host.finish_workbench_pose_trace()
	check(trace.get("status","")=="saved",mode+" original trace saved")
	if trace.get("status","")=="saved":
		var target: String = output.path_join(mode+"-poses.jsonl")
		check(DirAccess.copy_absolute(str(trace.path),target)==OK,mode+" original trace retained with captures")
	if mode!="legacy":
		# Removing the false global unknown must not bypass genuine material.
		bridge.reset_body(0,Vector2(258,360),0.0)
		host.snapshot_blend_start_usec=Time.get_ticks_usec()
		host._present_physical_actor_overlay(receipt)
		check(int(host.workbench_presentation_last.get("blocked_material",0))==1 \
			and shown_pose().is_equal_approx(bound),
			"repair still refuses live pose whose sweep crosses real native Wall")
	bridge.reset_body(0,bound.origin,bound.get_rotation())
	host.paused=true
	host.update_worker_frame_state()
	host.set_process(true)
	host.set_physics_process(true)

func _native_edit(cell: Vector2i, material: int) -> bool:
	var state: Dictionary = host.simulation_worker.paint_state()
	var queued: Dictionary = host.simulation_worker.paint_queue({"kind":"edit",
		"cells":PackedInt32Array([cell.x,cell.y,material]),
		"expected_generation":int(state.generation),"expected_revision":int(state.revision),
		"expected_tick":int(state.tick)})
	if not check(queued.get("status","")=="queued","real native PAINT queued material "+str(material)):
		return false
	if not check(await until(func() -> bool: return host.simulation_worker.paint_state().receipt_ready),
			"real native PAINT completes material "+str(material)):
		return false
	var receipt: Dictionary = host.simulation_worker.paint_take_result()
	native_edits.append({"material":material,"status":receipt.get("status",""),
		"after":Array(receipt.get("after",PackedInt32Array()))})
	return check(receipt.get("status","")=="completed" \
		and receipt.get("after",PackedInt32Array())==PackedInt32Array([material]),
		"actual native readback verifies edited material "+str(material))

func _old_material_safety() -> void:
	# Unlike the no-change full refresh above, genuine PAINT changes Image
	# bytes. This proves retained history is immutable across CPU patch mutation,
	# and that the new direct-image oracle still blocks old visible material.
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","repair")
	var cell := Vector2i(240,368)
	if not await _native_edit(cell,6): return
	if not check(await until(func() -> bool: return host.image.get_pixel(cell.x,cell.y).r8==6),
			"real native Fire reaches current material image"): return
	if not await _native_edit(cell,0): return
	if not check(await until(func() -> bool:
		return host.image.get_pixel(cell.x,cell.y).r8==0 \
			and host._presentation_previous_image!=null \
			and host._presentation_previous_image.get_pixel(cell.x,cell.y).r8==6),
			"native erase retains actual old-only Fire in immutable previous image"): return
	host.set_process(false)
	host.set_physics_process(false)
	var previous: Image = host._presentation_previous_image
	var current_bytes: PackedByteArray = host.image.get_data()
	check(previous!=host.image and previous.get_pixel(cell.x,cell.y).r8==6 \
		and host.image.get_pixel(cell.x,cell.y).r8==0,
		"old image remains distinct after mutating the current native image")
	if DisplayServer.get_name()!="headless":
		var gpu: Image = host.previous_texture.get_image()
		check(gpu!=null and gpu.get_pixel(cell.x,cell.y).r8==6,
			"actual GPU old-only Fire equals retained CPU history after native erase")
	var bridge = host.physical_actor_session.bridge
	var bound: Transform2D = bridge.body_transform(0)
	var live := Transform2D(bound.get_rotation(),Vector2(cell))
	var active: Dictionary = Clearance.assess(bound,live,bridge._rects[0],host.image,
		{},false,true,Clearance.MAX_SCAN_CELLS,0,previous)
	var expired: Dictionary = Clearance.assess(bound,live,bridge._rects[0],host.image,
		{},false,false,Clearance.MAX_SCAN_CELLS,0,previous)
	check(not active.safe and active.reason=="material_in_swept_mask",
		"exact previous image still rejects sweep through old visible native Fire")
	check(expired.safe,"expired old material stops blocking an otherwise clear current World")
	check(host.image.get_data()==current_bytes and host.physical_actor_session.tick==source_tick,
		"old-image safety observation preserves current material and physical tick")
	host.set_process(true)
	host.set_physics_process(true)

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
	root.size=Vector2i(1280,800)
	ui=host.shared_workbench
	if check(await until(func() -> bool: return ui!=null and not ui.applied.is_empty()),
			"actual native Workbench ready"):
		var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
		recipe.actors=[Setup.instance("kestrel",1,Vector2(240,360))]
		recipe.next_id=2
		recipe.selected=1
		recipe.edits.append([260,345,5,58,58])
		var epoch: int=host._physical_epoch
		if check(ui.apply(recipe),"actual native Wall and real Kestrel requested") \
				and check(await until(func() -> bool:
					return host.pending_microscenario_apply.is_empty() \
						and host._physical_epoch>epoch and host._physical_terrain_ready \
						and host._valid_workbench_mask_frame(host.workbench_display_frame())),
					"source-owned native material/mask frame installed"):
			check(host.paused,"real native World starts paused for controlled presentation comparison")
			source_bytes=host.image.get_data()
			source_tick=host.physical_actor_session.tick
			host.render_snapshot_hz=1 # observation window; no physics delta changed
			check(host.image.get_pixel(260,360).r8==58,"real native Wall material at negative-control location")
			await _exercise("legacy")
			await _exercise("repair")
			await _old_material_safety()
	var result: Dictionary={"schema":"render-cadence-contract-v1","checks":checks,
		"failures":failures,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"platform":OS.get_name(),"display_server":DisplayServer.get_name(),
		"video_adapter":RenderingServer.get_video_adapter_name(),
		"scope":"Actual native full refresh and Rapier RID; physically paused causal control. Live mismatched-clock reference matrix is a separate test.",
		"observations":observations,"native_edits":native_edits}
	var writer: FileAccess=FileAccess.open(output.path_join("contract.json"),FileAccess.WRITE)
	if writer!=null:
		writer.store_string(JSON.stringify(result,"  ")+"\n")
		writer.close()
	else:
		check(false,"contract evidence could not be written")
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE",original_cadence)
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE",original_pose)
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION",original_presentation)
	host.queue_free()
	await process_frame
	await process_frame
	print("RENDER_CADENCE_CONTRACT_RESULT ",JSON.stringify({"checks":checks,
		"failures":failures,"platform":OS.get_name(),"observations":observations.size()}))
	quit(int(not failures.is_empty()))
