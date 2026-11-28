extends SceneTree

# PR593 P2: full Main._process -> _safe_workbench_presentation_poses ->
# CyberPhysicalActorSession.render_parts -> PhysicalActorOverlay.present.
# Both material and pose receipts originate in the real native Workbench.
# Only the *test* positions the actual Rapier RID to discriminate decisions;
# no simulated/synthetic pixel image, stub bridge or fabricated display frame.
const Setup = preload("res://scripts/workbench_setup.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const WATCHDOG_MS: int = 90000

var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var source_frame: Dictionary = {}
var bridge
var rid: RID
var original_environment: String = ""
var original_timing: String = ""


func _initialize() -> void:
	# Preserve the historical guard's oracle as an explicit baseline control.
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy")
	_run.call_deferred()


func require(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("PR593_PRODUCTION_POSE: "+description)
	return ok


func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+WATCHDOG_MS
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false


func _refresh_same_world_history() -> bool:
	var prior: int = host.last_uploaded_render_snapshot_serial
	var generation: int = host.last_uploaded_world_generation
	host.simulation_worker.request_render_full_refresh()
	return await until(func() -> bool:
		var previous: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec()).previous
		return host.last_uploaded_render_snapshot_serial > prior and host.last_uploaded_world_generation == generation \
			and previous.get("serial",-1) == prior and previous.get("generation",-1) == generation \
			and host._valid_workbench_mask_frame(host.workbench_display_frame()))


func _set_actual_rapier_pose(pose: Transform2D) -> bool:
	# The production bridge retains the last *measured* Rapier pose in its
	# _transforms cache; modifying only BODY_STATE_TRANSFORM on the RID would
	# leave body_transform() stale until a physical step. Use its real
	# reset_body() operation, which updates BOTH the RID and this canonical
	# cache without touching native World material or display-frame bytes.
	bridge.reset_body(0,pose.origin,pose.get_rotation())
	var observed: Transform2D = bridge.body_transform(0)
	var rid_pose: Transform2D = PhysicsServer2D.body_get_state(
		rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	return observed.origin.distance_to(pose.origin)<0.001 \
		and rid_pose.origin.distance_to(pose.origin)<0.001 \
		and absf(wrapf(observed.get_rotation()-pose.get_rotation(),-PI,PI))<0.001 \
		and absf(wrapf(rid_pose.get_rotation()-pose.get_rotation(),-PI,PI))<0.001


func _render_scene(label: String, expected: Transform2D,
		expected_mode: String, reason: String) -> void:
	# The production callback is invoked as usual: it chooses the overlay pose
	# and calls the real render_parts and overlay.present implementations.
	host._process(0.0)
	var parts: Array = host.physical_actor_overlay._parts
	var drawn: Vector2 = Vector2.INF
	var angle: float = -10000.0
	if not parts.is_empty():
		drawn = parts[0].transform.origin
		angle = parts[0].transform.get_rotation()
	var summary: Dictionary = host.workbench_presentation_last.duplicate(true)
	var current_frame: Dictionary = host.workbench_display_frame()
	var accepted: bool = drawn.distance_to(expected.origin)<0.001 \
		and absf(wrapf(angle-expected.get_rotation(),-PI,PI))<0.001
	require(not parts.is_empty() and accepted,
		label+" final actual drawn physical part has expected "+expected_mode+" transform")
	if reason=="clear":
		require(int(summary.get("safe_live",0))>0,
			label+" production admission actually chose safe live Rapier pose")
	elif reason=="material":
		require(int(summary.get("blocked_material",0))>0 and int(summary.get("safe_live",0))==0,
			label+" production admission detected real native material obstruction")
	elif reason=="previous":
		require(int(summary.get("blocked_unknown",0))>0 and int(summary.get("safe_live",0))==0,
			label+" production admission vetoed unbounded previous material during crossfade")
	observations.append({
		"label":label,"rendered_parts":parts.size(),"expected_mode":expected_mode,
		"expected_pose":[expected.origin.x,expected.origin.y,expected.get_rotation()],
		"drawn_pose":[drawn.x,drawn.y,angle],
		"Rapier_pose":[bridge.body_transform(0).origin.x,bridge.body_transform(0).origin.y],
		"native_frame_sample":current_frame.get("sample",-1),
		"uploaded_revision":host.last_uploaded_revision,
		"frame_revision":current_frame.get("revision",-1),
		"native_world_generation":host.last_uploaded_world_generation,
		"guard":summary
	})


func _run() -> void:
	original_environment = OS.get_environment("CYBERSAND_DIAG_FLYER_POSE")
	original_timing = OS.get_environment("CYBERSAND_DIAG_MATERIAL_TIMING")
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","")
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	ui = host.shared_workbench
	if require(await until(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"initial Workbench World installed"):
		var recipe: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
		recipe.actors=[Setup.instance("kestrel",1,Vector2(240,360))]
		recipe.next_id=2
		recipe.selected=1
		# First is ordinary real-Wall obstruction; second cell is the
		# 9x6 Kestrel continuous rotating-and-translating counterexample.
		recipe.edits.append([260,345,5,1,58])
		recipe.edits.append([237,355,1,1,58])
		if not host.paused: ui.toggle_pause()
		var old_epoch: int = host._physical_epoch
		if require(ui.apply(recipe),"real World and Kestrel actor recipe accepted"):
			if require(await until(func() -> bool:
					return host.pending_microscenario_apply.is_empty() and host._physical_epoch>old_epoch and host.physical_actor_session != null and host._physical_terrain_ready),
					"actual Rapier actor and native World adopted"):
				var ready: bool = await until(func() -> bool:
					return host.image != null and host.latest_snapshot != null and host.last_uploaded_world_generation==host.latest_snapshot.render_world_generation and host.last_uploaded_revision==host.latest_snapshot.world_revision and host.image.get_pixel(260,345).r8==58 and host.image.get_pixel(237,355).r8==58 and not host.workbench_display_frame().is_empty())
				if require(ready,"real native Wall cells acknowledged in uploaded material texture") \
						and require(await _refresh_same_world_history(),"native refresh supplies a real same-World predecessor"):
					bridge = host.physical_actor_session.bridge
					rid = bridge._body_rids[0]
					source_frame = host.workbench_display_frame().duplicate(true)
					var frame_actor: Dictionary = source_frame.get("instances",{}).get(1,{})
					var member: Dictionary = bridge._members[0]
					var bound: Transform2D = frame_actor.get("pose",Transform2D.IDENTITY)
					var identity_ok: bool = (
						source_frame.get("session",-1)==bridge._session and
						source_frame.get("epoch",-1)==bridge._epoch and
						source_frame.get("world_generation",-1)==host.last_uploaded_world_generation and
						source_frame.get("revision",-1)==host.last_uploaded_revision and
						frame_actor.get("generation",-1)==member.generation)
					require(identity_ok,"actual native-upload identity matches session/epoch/generation/revision")
					require(rid.is_valid() and bridge._rects.size()==1 and bridge._rects[0].size()==1 and
						Vector2(bridge._rects[0][0].size).is_equal_approx(Vector2(9,6)),
						"actual Rapier Kestrel body is the 9x6 collider in native mask")
					require(bound.origin.distance_to(Vector2(240,360))<0.1,
						"native published starting pose is the authored Kestrel spawn")
					# Disable automatic physics stepping, but still use the full
					# live production Main._process presentation callback.
					host.set_physics_process(false)
					host.set_process(false)
					var original_world_bytes: PackedByteArray = host.image.get_data()
					var original_session_tick: int = host.physical_actor_session.tick
					if host.paused: ui.toggle_pause()
					require(not host.paused,"production admission is active during play")
					var original_blend_hz: int = host.render_snapshot_hz
					host.snapshot_blend_start_usec = Time.get_ticks_usec()-1000000
					var clear_pose := Transform2D(bound.get_rotation(),bound.origin+Vector2(0,1))
					if require(_set_actual_rapier_pose(clear_pose),"actual Rapier RID moved through free space"):
						_render_scene("clear_ahead",clear_pose,"live","clear")
					# A user can force the existing conservative mask baseline
					# without changing the same actual physical RID.
					OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","mask")
					_render_scene("mask_baseline",bound,"bound","baseline")
					require(host.workbench_presentation_last.get("status")=="mask_baseline"
						and int(host.workbench_presentation_last.get("safe_live",-1))==0,
						"mask baseline reports inactive admission, never stale safe-live statistics")
					OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
					# Active previous-texture crossfade: unknown old material
					# must fall back even though today's World is clear.
					host._presentation_previous_unknown=true
					host.render_snapshot_hz=1
					host.snapshot_blend_start_usec=Time.get_ticks_usec()
					_render_scene("previous_texture_unknown",bound,"bound","previous")
					host.render_snapshot_hz=original_blend_hz
					host.snapshot_blend_start_usec=Time.get_ticks_usec()-1000000
					host._presentation_previous_unknown=false
					_render_scene("previous_texture_expired",clear_pose,"live","clear")
					# Obstruction: the target body intersects a real painted
					# Wall at (260,345) in the original native World.
					var obstructed := Transform2D(bound.get_rotation(),Vector2(260,345))
					if require(_set_actual_rapier_pose(obstructed),"actual Rapier RID moved to native Wall obstruction"):
						_render_scene("real_wall_obstruction",bound,"bound","material")
					# Now exercise a *different* real Wall that a sampled-only
					# 9x6 Kestrel sweep would miss between the four samples.
					var adversarial := Transform2D(bound.get_rotation()+0.5,
						bound.origin+Vector2(2,-2))
					var rects: Array = bridge._rects[0]
					var cell: Vector2 = Vector2(237.5,355.5)
					var missed_by_old_samples: bool = true
					for j: int in range(4):
						var fraction: float = float(j)/3.0
						var sampled := Transform2D(bound.get_rotation()+0.5*fraction,
							bound.origin.lerp(adversarial.origin,fraction))
						if Clearance._touches_body(cell,sampled,rects):
							missed_by_old_samples=false
					require(missed_by_old_samples,
						"actual Kestrel 9x6 authored Wall centre missed by old discrete samples")
					var mid := Transform2D(bound.get_rotation()+0.25,
						bound.origin.lerp(adversarial.origin,0.5))
					require(Clearance._touches_body(cell,mid,rects),
						"actual Kestrel intermediate rotating sweep contains native Wall centre")
					if require(_set_actual_rapier_pose(adversarial),"actual Rapier RID moved to adversarial rotated endpoint"):
						_render_scene("adversarial_continuous_wall",bound,"bound","material")
					# Fail closed on an invalid frame identity without ever
					# allowing the visual override into render_parts().
					if require(_set_actual_rapier_pose(clear_pose),"restore clear actual Rapier RID"):
						var invalid_frame: Dictionary = source_frame.duplicate(true)
						invalid_frame["epoch"]=int(invalid_frame.get("epoch",0))+1
						require(host._safe_workbench_presentation_poses(invalid_frame,false).is_empty(),
							"real production admission rejects mismatched native epoch")
						host._present_physical_actor_overlay(invalid_frame)
						require(host.physical_actor_overlay._parts.is_empty(),
							"invalid epoch hides final overlay rather than leaking unchecked live pose")
						require(host.workbench_presentation_last.get("status")=="invalid_frame",
							"invalid epoch produces an explicit diagnostic")
						var bad_generation: Dictionary = source_frame.duplicate(true)
						bad_generation.instances[1].generation = member.generation + 1
						host._present_physical_actor_overlay(bad_generation)
						require(host.physical_actor_overlay._parts.is_empty(),
							"invalid actor generation cannot draw live Rapier pose")
						var bad_revision: Dictionary = source_frame.duplicate(true)
						bad_revision.revision = int(bad_revision.revision) + 1
						host._present_physical_actor_overlay(bad_revision)
						require(host.physical_actor_overlay._parts.is_empty(),
							"wrong uploaded revision cannot draw actor through material")
						host._present_physical_actor_overlay({})
						require(host.physical_actor_overlay._parts.is_empty(),
							"missing display frame cannot draw unchecked live pose")
						host._present_physical_actor_overlay(source_frame)
						require(not host.physical_actor_overlay._parts.is_empty(),
							"valid bound frame restores the original actor overlay")
					require(host.physical_actor_session.render_parts().size()>0,
						"receipt-free geometry inspection API remains available")
					require(host.image.get_data()==original_world_bytes,
						"full renderer admission and scripted RID poses did not mutate displayed material bytes")
					require(host.physical_actor_session.tick==original_session_tick,
						"presentation-only test never advances authoritative Rapier simulation")
					_set_actual_rapier_pose(bound)
	host.queue_free()
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE",original_environment)
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING",original_timing)
	await process_frame
	await process_frame
	print("PR593_PRODUCTION_POSE_RESULT ",JSON.stringify({
		"schema":"pr593-full-production-pose-admission-v1",
		"checks":checks,"failures":failures,
		"cases":observations,"platform":OS.get_name(),
		"native_world":"genuine uploaded material; real Kestrel Rapier RID",
		"render_path":"Main._process -> _safe_workbench_presentation_poses -> render_parts -> PhysicalActorOverlay.present"}))
	quit(int(not failures.is_empty()))
