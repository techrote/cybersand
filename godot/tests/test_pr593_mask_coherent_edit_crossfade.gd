extends SceneTree

# Real native PAINT edits -> GPU old/new textures -> production Main/overlay.
# Physical stepping stays disabled only for deterministic observation.
const Setup = preload("res://scripts/workbench_setup.gd")
const WATCHDOG_MS: int = 90000
const CELL: Vector2i = Vector2i(240,368)
var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var receipts: Array[Dictionary] = []

func _initialize() -> void:
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
					return host.pending_microscenario_apply.is_empty()
						and host._physical_epoch>prior_epoch
						and host.physical_actor_session != null and host._physical_terrain_ready
						and host.image!=null
						and host._valid_workbench_mask_frame(host.workbench_display_frame())),
					"actual native material and bound actor frame uploaded"):
				require(host.paused,"native editing while physics paused")
				require(host.cadence_lod_enabled,"real material crossfade enabled")
				host.render_snapshot_hz=1
				var pixel_id: int = CELL.y*host.image.get_width()+CELL.x
				if await _native_edit(6):
					if require(await until(func() -> bool:
							return host.image.get_pixel(CELL.x,CELL.y).r8==6
								and host._valid_workbench_mask_frame(host.workbench_display_frame())),
							"real Fire pixel uploaded after native PAINT edit"):
						if await _native_edit(0):
							if require(await until(func() -> bool:
									return host.image.get_pixel(CELL.x,CELL.y).r8==0
										and host._presentation_previous_occupied.has(pixel_id)
										and not host._presentation_previous_unknown
										and host._valid_workbench_mask_frame(host.workbench_display_frame())),
									"native erase creates tracked old-only Fire pixel"):
								var old: Image = host.previous_texture.get_image()
								require(old!=null and not old.is_empty()
									and old.get_pixel(CELL.x,CELL.y).r8==6,
									"actual previous GPU texture still contains Fire")
								var frame: Dictionary = host.workbench_display_frame().duplicate(true)
								var bound: Transform2D = frame.instances[1].pose
								require(bound.origin.distance_to(Vector2(240,360))<0.1,
									"bound native Kestrel unchanged by material edits")
								var bytes: PackedByteArray = host.image.get_data()
								var tick: int = host.physical_actor_session.tick
								var bridge = host.physical_actor_session.bridge
								host.set_physics_process(false)
								host.set_process(false)
								host.paused=false # worker remains physically paused
								bridge.reset_body(0,Vector2(CELL),0.0)
								host.snapshot_blend_start_usec=Time.get_ticks_usec()
								host._present_physical_actor_overlay(frame)
								var blocked: Dictionary=host.workbench_presentation_last.duplicate(true)
								require(int(blocked.get("blocked_material",0))>0
									and int(blocked.get("safe_live",0))==0
									and _shown().distance_to(bound.origin)<0.001,
									"real old GPU Fire vetoes live overlay during crossfade")
								host.snapshot_blend_start_usec=Time.get_ticks_usec()-2000000
								host._present_physical_actor_overlay(frame)
								var released: Dictionary=host.workbench_presentation_last.duplicate(true)
								require(int(released.get("safe_live",0))>0
									and _shown().distance_to(Vector2(CELL))<0.001,
									"elapsed blend releases previously blocked live pose")
								require(host.image.get_data()==bytes
									and host.physical_actor_session.tick==tick,
									"render safety never mutated World or advanced Rapier tick")
								print("PR593_NATIVE_EDIT_CROSSFADE_CASE ",JSON.stringify({
									"old_gpu_material":old.get_pixel(CELL.x,CELL.y).r8,
									"new_cpu_material":host.image.get_pixel(CELL.x,CELL.y).r8,
									"revision":host.last_uploaded_revision,"blocked":blocked,
									"released":released,"receipts":receipts}))
	host.queue_free()
	await process_frame
	await process_frame
	print("PR593_NATIVE_EDIT_CROSSFADE_RESULT ",JSON.stringify({
		"checks":checks,"failures":failures,"platform":OS.get_name(),"native_receipts":receipts}))
	quit(int(not failures.is_empty()))
