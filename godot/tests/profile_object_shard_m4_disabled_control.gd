extends "res://tests/profile_object_shard_m4_render_control.gd"

# Same native tower recipe, ordinary actor, camera and pause/play controls as
# the enabled control, but no ObjectShard attachment or substitute physics.
const Setup = preload("res://scripts/workbench_setup.gd")
var owner_generation: int = -1
var authored_rectangles_sha256: String = ""
var control_view: Dictionary = {}
var pause_request_serial: int = -1
var pause_transitions: Array[Dictionary] = []

func _native_tick() -> int:
	return int(f.host.latest_snapshot.tick_index)

func _pause_boundary() -> Dictionary:
	var snapshot: CyberSimulationSnapshot = f.host.latest_snapshot
	return {"host_paused":f.host.paused,"native_paused":snapshot.paused,
		"actor_suspended":f.host.physical_actor_session._suspended,
		"requested_pause":f.host.simulation_worker.workbench_pause_request_serial(),
		"acknowledged_pause":int(snapshot.lab_context.get("workbench_pause_ack_serial",-1)),
		"native_tick":snapshot.tick_index,"snapshot_serial":snapshot.serial,
		"world_generation":snapshot.render_world_generation,"world_revision":snapshot.world_revision,
		"simulation_world_revision":snapshot.simulation_world_revision,
		"render_serial":snapshot.render_snapshot_serial,
		"uploaded_render_serial":f.host.last_uploaded_render_snapshot_serial}

static func _pause_receipt_matches(value: Dictionary, requested: int) -> bool:
	return requested >= 0 and value.host_paused and value.native_paused and value.actor_suspended \
		and int(value.acknowledged_pause) >= requested \
		and value.world_revision == value.simulation_world_revision \
		and int(value.uploaded_render_serial) >= int(value.render_serial)

func _paused_coherent() -> bool:
	return _pause_receipt_matches(_pause_boundary(),pause_request_serial)

func _pause_disabled() -> bool:
	var before: Dictionary = _pause_boundary()
	if not f.host.paused:
		if not f.expect(f.bench.toggle_pause(),"disabled control ordinary Pause admitted"): return false
		if not f.expect(f.host.simulation_worker.workbench_pause_request_serial()>int(before.requested_pause),
			"disabled control Pause sends a new monotonic worker command"): return false
	pause_request_serial = f.host.simulation_worker.workbench_pause_request_serial()
	var requested: Dictionary = _pause_boundary()
	# As in the ordinary actor-composition gate, a coherent paused snapshot can
	# be a held body sample during Play. It does not acknowledge this UI Pause.
	# Exercise that stale value without changing any owner or published input.
	var stale: Dictionary = requested.duplicate(true)
	stale.host_paused = true
	stale.native_paused = true
	stale.actor_suspended = true
	stale.world_revision = stale.simulation_world_revision
	stale.uploaded_render_serial = stale.render_serial
	stale.acknowledged_pause = pause_request_serial-1
	f.expect(not _pause_receipt_matches(stale,pause_request_serial),
		"coherent paused receipt from before this command cannot admit a disabled measurement")
	var acknowledged: bool = await f.until(_paused_coherent,
		"disabled native and actor owners acknowledge this exact Pause and its image")
	pause_transitions.append({"before":before,"requested":requested,"acknowledged":_pause_boundary(),
		"required_pause_serial":pause_request_serial,"stale_negative":stale})
	return acknowledged

func _measure_disabled(label: String) -> void:
	var first_boundary: Dictionary = _pause_boundary()
	var first_tick: int = _native_tick()
	var first_steps: int = f.host.rapier_bridge.manual_step_count()
	var first_profile: Dictionary = f.host.simulation_worker.object_shard_owner_profile()
	var callbacks: Array[int] = []
	submissions.clear()
	var started: int = Time.get_ticks_usec()
	var next_heartbeat: int = started+5000000
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.connect(_post_draw)
	while Time.get_ticks_usec()-started < int(seconds*1000000.0) and not f.host.simulation_worker.has_failed():
		await process_frame
		var now: int = Time.get_ticks_usec()
		callbacks.append(now)
		if now >= next_heartbeat:
			print("M4_DISABLED_CONTROL_PROGRESS ",JSON.stringify({"label":label,"elapsed_usec":now-started,
				"semantic_ticks":_native_tick()-first_tick,"render_submissions":submissions.size()}))
			next_heartbeat = now+5000000
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.disconnect(_post_draw)
	var elapsed: int = maxi(1,Time.get_ticks_usec()-started)
	var last_profile: Dictionary = f.host.simulation_worker.object_shard_owner_profile()
	var row: Dictionary = {"label":label,"paused":f.host.paused,"elapsed_usec":elapsed,
		"boundary_before":first_boundary,"boundary_after":_pause_boundary(),
		"semantic_ticks":_native_tick()-first_tick,"actual_physics_steps":f.host.rapier_bridge.manual_step_count()-first_steps,
		"render_submissions":submissions.size(),"process_callbacks":callbacks.size(),
		"render_submissions_per_second":float(submissions.size())*1000000.0/elapsed,
		"semantic_ticks_per_second":float(_native_tick()-first_tick)*1000000.0/elapsed,
		"render_intervals":_intervals(submissions),"callback_intervals":_intervals(callbacks),
		"worker_snapshot_calls":int(last_profile.get("snapshot_calls",0))-int(first_profile.get("snapshot_calls",0)),
		"worker_snapshot_usec":int(last_profile.get("snapshot_usec",0))-int(first_profile.get("snapshot_usec",0)),
		"objectshard_enabled":f.runtime().enabled,
		"objectshard_native_attached":bool(f.host.simulation_worker.object_shard_same_world_capabilities().get("native_attached",false)),
		"material_body_count":f.body_count(),"ordinary_actor_count":f.bench.applied.actors.size()}
	rows.append(row)
	f.expect(not f.host.simulation_worker.has_failed(),label+" retains a valid ordinary native owner")
	f.expect(int(f.host.latest_snapshot.render_world_generation)==owner_generation,label+" retains the same native World generation")
	f.expect(not row.objectshard_enabled and not row.objectshard_native_attached and row.material_body_count==0,
		label+" keeps ObjectShard disabled throughout the measurement")
	f.expect(row.worker_snapshot_calls==0 and row.worker_snapshot_usec==0,label+" performs no attached-owner snapshots")
	if f.host.paused:
		f.expect(row.semantic_ticks==0 and row.actual_physics_steps==0,label+" consumes no native or Rapier time")
	else:
		f.expect(row.semantic_ticks>0 and row.actual_physics_steps>0,label+" advances the actual ordinary native and Rapier owners")
	if DisplayServer.get_name() != "headless": f.expect(submissions.size()>0,label+" submits actual graphical frames")
	print("M4_DISABLED_CONTROL_WINDOW ",JSON.stringify(row))

func _run() -> void:
	f = Fixture.new(self)
	if not f.expect("--objectshard-m4-workbench" not in OS.get_cmdline_user_args(),"disabled control is launched without the ObjectShard flag"):
		await _finish_disabled(); return
	set_meta("cybersand_feature","shared_workbench")
	f.host = load("res://main.tscn").instantiate()
	root.add_child(f.host)
	if not await f.until(f.installed,"ordinary Workbench installed for disabled control"):
		await _finish_disabled(); return
	f.bench = f.host.shared_workbench
	var recipe: Dictionary = Fixture.Scenes.create("tower",PackedInt32Array(f.bench.applied.liquid_policy))
	if not f.expect(f.bench.apply(recipe),"same tower recipe enters ordinary native prepared authoring"):
		await _finish_disabled(); return
	if not await f.until(f.installed,"disabled tower recipe installed"):
		await _finish_disabled(); return
	f.bench.set_camera(2)
	f.bench.set_object_shard_diagnostics_enabled(false)
	owner_generation = int(f.host.latest_snapshot.render_world_generation)
	authored_rectangles_sha256 = JSON.stringify(Array(Setup.rectangles(f.bench.applied).runs)).sha256_text()
	control_view = {"origin":[f.host.camera_origin.x,f.host.camera_origin.y],
		"size":[f.host.current_view_size.x,f.host.current_view_size.y]}
	# Prime exactly the same ordinary native/actor startup path before sampling.
	var first_tick: int = _native_tick()
	f.play()
	await f.until(func(): return _native_tick()>first_tick,"disabled control performs an actual initial native tick")
	if not await _pause_disabled():
		await _finish_disabled(); return
	await _measure_disabled("disabled_intact_paused")
	f.play()
	await _measure_disabled("disabled_intact_playing")
	await _pause_disabled()
	await _finish_disabled()

func _finish_disabled() -> void:
	var result: Dictionary = {"schema":"objectshard-m4-disabled-control-v1", "source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_driver":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"scene":"tower","camera":"overview","canvas_extent":[512,512],"control_view":control_view,
		"authored_rectangles_sha256":authored_rectangles_sha256,"seconds_per_window":seconds,"windows":rows,
		"pause_transitions":pause_transitions,
		"checks":f.checks,"failures":f.failures,
		"scope":"ordinary native Workbench tower with ObjectShard disabled; renderer submissions and semantic progression are independent; physical monitor presentation owner-pending"}
	if f.host != null: await f.close()
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify(result,"\t")+"\n")
			file.close()
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
