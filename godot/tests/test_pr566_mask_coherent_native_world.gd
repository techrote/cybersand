extends SceneTree

# Source-qualified real native World fixture: the blocked predicate is tested
# against an authored hard Wall uploaded through the actual Workbench, not
# synthesized into a standalone Image and never injected through a fake mask.
const Setup = preload("res://scripts/workbench_setup.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const WATCHDOG_MS: int = 90000
var host: Control
var ui: Control
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		errors.append(description)
		push_error("PR566_WORLD_CLEARANCE: "+description)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+WATCHDOG_MS
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	ui = host.shared_workbench
	if require(await until(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"initial native World ready"):
		var recipe: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
		recipe.actors=[Setup.instance("kestrel",1,Vector2(240,360))]
		recipe.next_id=2
		recipe.selected=1
		recipe.edits.append([260,345,5,58])
		if not host.paused: ui.toggle_pause()
		var old_epoch: int = host._physical_epoch
		if require(ui.apply(recipe),"real World with authored Wall accepted"):
			if require(await until(func() -> bool:
					return host.pending_microscenario_apply.is_empty() and
						host._physical_epoch>old_epoch and host.physical_actor_session != null and
						host._physical_terrain_ready),
					"native World, actor and Rapier graph adopted"):
				# ImageTexture's accepted copied bytes are the actual material
				# visible behind the actor, not a synthetic test canvas.
				var uploaded: bool = await until(func() -> bool:
					return host.latest_snapshot != null and
						host.last_uploaded_world_generation == host.latest_snapshot.render_world_generation and
						host.last_uploaded_revision == host.latest_snapshot.world_revision and
						host.image != null and host.image.get_pixel(260,345).r8 == 58)
				require(uploaded,"authored Wall present in accepted GPU material image")
				if uploaded:
					var bridge = host.physical_actor_session.bridge
					var original: Transform2D = bridge.body_transform(0)
					var rects: Array = bridge._rects[0]
					var blocked_pose := Transform2D(original.get_rotation(),Vector2(260,345))
					var blocked: Dictionary = Clearance.assess(
						original,blocked_pose,rects,host.image,{},false,false)
					require(not blocked.safe and blocked.reason=="material_in_swept_mask",
						"real stored hard Wall vetoes interpolated actor pose")
					var free_pose := Transform2D(original.get_rotation(),
						original.origin+Vector2(1.0,-1.0))
					var clear: Dictionary = Clearance.assess(
						original,free_pose,rects,host.image,{},false,false)
					require(clear.safe,"unchanged original World admits nearby clear flight")
					var unknown: Dictionary = Clearance.assess(
						original,free_pose,rects,host.image,{},true,true)
					require(not unknown.safe and unknown.reason=="previous_texture_unbounded",
						"unbounded previous texture vetoes even if current World is clear")
					print("PR566_WORLD_CLEARANCE_RECEIPT ",JSON.stringify({
						"world_generation":host.last_uploaded_world_generation,
						"material_revision":host.last_uploaded_revision,
						"wall_id":host.image.get_pixel(260,345).r8,
						"baseline_position":[original.origin.x,original.origin.y],
						"blocked":blocked,"clear":clear,"previous_unknown":unknown}))
	host.queue_free()
	await process_frame
	await process_frame
	print("PR566_WORLD_CLEARANCE_RESULT ",JSON.stringify({
		"checks":checks,"failures":errors,"native_runtime":"real Workbench World and Rapier"}))
	quit(int(not errors.is_empty()))
