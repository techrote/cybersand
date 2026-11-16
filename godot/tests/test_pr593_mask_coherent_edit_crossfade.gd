extends SceneTree

# Real native PAINT edits -> GPU old/new textures -> production Main/overlay.
# Physical stepping stays disabled only for deterministic observation.
const Setup = preload("res://scripts/workbench_setup.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const WATCHDOG_MS: int = 90000
const CELL: Vector2i = Vector2i(240,368)
var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var receipts: Array[Dictionary] = []

func _initialize() -> void:
	# This fixture owns the original policy; the temporal fixture covers its successor.
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy")
	_run.call_deferred()

func require(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PR593_NATIVE_CROSSFADE: " + label)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+WATCHDOG_MS
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func _native_edit(id: int) -> bool:
	var worker: RefCounted = host.simulation_worker
	var state: Dictionary = worker.paint_state()
	var edit: Dictionary = {"kind":"edit","cells":PackedInt32Array([CELL.x,CELL.y,id]),
		"expected_generation":int(state.generation),
		"expected_revision":int(state.revision),
		"expected_tick":int(state.tick)}
	var queued: Dictionary = worker.paint_queue(edit)
	if not require(queued.get("status")=="queued",
			"actual native PAINT edit queued: "+str(id)): return false
	if not require(await until(func() -> bool: return worker.paint_state().receipt_ready),
			"native material edit complete: "+str(id)): return false
	var receipt: Dictionary = worker.paint_take_result()
	receipts.append({"id":id,"status":receipt.get("status"),"after":str(receipt.get("after"))})
	return require(receipt.get("status")=="completed"
		and receipt.get("after",PackedInt32Array())==PackedInt32Array([id]),
		"native World confirms material "+str(id))

# Match the production history selection. The exact retained image supersedes
# the bounded legacy dictionary whenever it is available.
func _previous_occupied(pixel: Vector2i) -> bool:
	var retained: Image = host._presentation_previous_image
	if retained != null:
		return retained.get_pixel(pixel.x,pixel.y).r8 != 0
	return host._presentation_previous_occupied.has(pixel.y*host.image.get_width()+pixel.x)

func _shown() -> Vector2:
	var parts: Array = host.physical_actor_overlay._parts
	return parts[0].transform.origin if parts.size()==1 else Vector2.INF

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	ui = host.shared_workbench
	if require(await until(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"initial native Workbench mounted"):
		var recipe: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
		recipe.actors=[Setup.instance("kestrel",1,Vector2(240,360))]
		recipe.next_id=2
		recipe.selected=1
		if not host.paused: ui.toggle_pause()
		var prior_epoch: int = host._physical_epoch
		if require(ui.apply(recipe),"actual authored World and Kestrel installed"):
			if require(await until(func() -> bool:
					return host.pending_microscenario_apply.is_empty() \
						and host._physical_epoch>prior_epoch \
						and host.physical_actor_session != null and host._physical_terrain_ready \
						and host.image!=null \
						and host._valid_workbench_mask_frame(host.workbench_display_frame())),
					"actual native material and bound actor frame uploaded"):
				require(host.paused,"native editing while physics paused")
				require(host.cadence_lod_enabled,"real material crossfade enabled")
				host.render_snapshot_hz=1
				var original_frame: Dictionary = host.workbench_display_frame().duplicate(true)
				if await _native_edit(6):
					if require(await until(func() -> bool:
							return host.image.get_pixel(CELL.x,CELL.y).r8==6),
							"real Fire pixel uploaded after native PAINT edit"):
						if await _native_edit(0):
							if require(await until(func() -> bool:
									return host.image.get_pixel(CELL.x,CELL.y).r8==0 \
										and _previous_occupied(CELL) \
										and not host._presentation_previous_unknown),
									"native erase creates tracked old-only Fire pixel"):
								# A headless DisplayServer cannot establish actual GPU texture
								# readback. The bounded old-material capture is independently
								# verified above. Demand real texture pixels only graphically.
								var graphical: bool = DisplayServer.get_name() != "headless"
								var old: Image = host.previous_texture.get_image() if graphical else null
								var old_pixel: int = -1
								if graphical:
									require(old!=null and not old.is_empty()
										and old.get_size()==host.image.get_size(),
										"graphical previous GPU texture has the actual World extent")
									if old != null and not old.is_empty():
										old_pixel=old.get_pixel(CELL.x,CELL.y).r8
									# A subsequent accepted texture upload can advance
									# the previous GPU slot again. Old CPU occupancy
									# may therefore overestimate GPU occupancy but
									# must never omit a nonempty previous pixel.
									require(old_pixel==0 or old_pixel==6,
										"graphical old GPU readback is empty or prior Fire")
									require(old_pixel==0
										or _previous_occupied(CELL),
										"visible prior GPU Fire is covered by guard history")
								else:
									require(_previous_occupied(CELL) \
										and not host._presentation_previous_unknown,
										"headless previous material captured from pre-patch CPU image")
								var frame: Dictionary = host.workbench_display_frame().duplicate(true)
								var bound: Transform2D = original_frame.instances[1].pose
								require(bound.origin.distance_to(Vector2(240,360))<0.1,
									"original native Kestrel pose retained across paused PAINT edits")
								var bytes: PackedByteArray = host.image.get_data()
								var tick: int = host.physical_actor_session.tick
								var bridge = host.physical_actor_session.bridge
								host.set_physics_process(false)
								host.set_process(false)
								host.paused=false # worker remains physically paused
								var proposed_pose := Transform2D(0.0,Vector2(CELL))
								bridge.reset_body(0,proposed_pose.origin,proposed_pose.get_rotation())
								# An edit while physically paused may invalidate the old pose
								# receipt. Never synthesize a matching receipt to force admission.
								var valid_after_edit: bool = host._valid_workbench_mask_frame(frame)
								var pixel_clearance: Dictionary = Clearance.assess(bound,proposed_pose,
									bridge._rects[0],host.image,host._presentation_previous_occupied,
									host._presentation_previous_unknown,true,Clearance.MAX_SCAN_CELLS,0,
									host._presentation_previous_image)
								require(not pixel_clearance.safe and pixel_clearance.reason=="material_in_swept_mask",
									"actual previous GPU Fire cell blocks the geometrically swept native mask")
								host.snapshot_blend_start_usec=Time.get_ticks_usec()
								host._present_physical_actor_overlay(frame)
								var blocked: Dictionary=host.workbench_presentation_last.duplicate(true)
								if valid_after_edit:
									require(int(blocked.get("blocked_material",0))>0
										and int(blocked.get("safe_live",0))==0
										and _shown().distance_to(bound.origin)<0.001,
										"bound actor refuses old GPU Fire during active crossfade")
								else:
									require(str(blocked.get("status"))=="invalid_frame"
										and host.physical_actor_overlay._parts.is_empty(),
										"paused PAINT revision change hides actor instead of using stale Rapier pose")
								host.snapshot_blend_start_usec=Time.get_ticks_usec()-2000000
								var after_blend: Dictionary = Clearance.assess(bound,proposed_pose,
									bridge._rects[0],host.image,host._presentation_previous_occupied,
									host._presentation_previous_unknown,false,Clearance.MAX_SCAN_CELLS,0,
									host._presentation_previous_image)
								require(after_blend.safe,
									"after crossfade expiry old-only Fire no longer blocks empty swept World")
								host._present_physical_actor_overlay(frame)
								var released: Dictionary=host.workbench_presentation_last.duplicate(true)
								if valid_after_edit:
									require(int(released.get("safe_live",0))>0
										and _shown().distance_to(Vector2(CELL))<0.001,
										"elapsed blend admits live actor when display receipt is current")
								else:
									require(str(released.get("status"))=="invalid_frame"
										and host.physical_actor_overlay._parts.is_empty(),
										"expired blend does not override still-stale native display receipt")
								require(host.image.get_data()==bytes
									and host.physical_actor_session.tick==tick,
									"render safety never mutated World or advanced Rapier tick")
								print("PR593_NATIVE_EDIT_CROSSFADE_CASE ",JSON.stringify({
									"old_gpu_material":old_pixel,"gpu_readback_verified":graphical,
									"new_cpu_material":host.image.get_pixel(CELL.x,CELL.y).r8,
									"revision":host.last_uploaded_revision,"frame_current":valid_after_edit,
									"pixel_clearance":pixel_clearance,"expired_clearance":after_blend,
									"blocked":blocked,"released":released,"receipts":receipts}))
	host.queue_free()
	await process_frame
	await process_frame
	print("PR593_NATIVE_EDIT_CROSSFADE_RESULT ",JSON.stringify({
		"checks":checks,"failures":failures,"platform":OS.get_name(),"native_receipts":receipts}))
	quit(int(not failures.is_empty()))
