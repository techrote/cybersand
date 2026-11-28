extends SceneTree

# Actual ordinary authoring without a reference actor: no helper body, private
# native World or simulated pose is allowed to make this canvas playable.
const Scenes = preload("res://scripts/object_shard_workbench_scenes.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var bench: Control
var checks: int = 0
var failures: Array[String] = []
var steady_window: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("M4_MATERIAL_ONLY: "+label)
	return value

func _until(predicate: Callable, label: String) -> bool:
	print("M4_MATERIAL_ONLY_WAIT ",label)
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		if host != null and host.object_shard_m4_runtime.enabled \
			and not host.object_shard_m4_runtime.held_reason.is_empty(): break
		await process_frame
	var result: bool = _check(predicate.call(),label)
	if not result and host != null: print("M4_MATERIAL_ONLY_STATE ",host.object_shard_m4_runtime.diagnostics())
	return result

func _installed() -> bool:
	return host.shared_workbench != null and not host.shared_workbench.applied.is_empty() \
		and not host.shared_workbench.busy() and host.pending_microscenario_apply.is_empty()

func _ready() -> bool:
	return host.object_shard_m4_runtime.physics_ready()

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await _until(_installed,"ordinary Workbench installed"):
		await _finish(); return
	bench = host.shared_workbench
	var authored: Dictionary = Scenes.create("tower",PackedInt32Array(bench.applied.liquid_policy))
	authored.actors = []
	authored.selected = 0
	authored.next_id = 1
	if not _check(bench.apply(authored),"actorless authored canvas admitted"):
		await _finish(); return
	bench.enable_object_shard()
	if not await _until(_installed,"actorless native World committed"):
		await _finish(); return
	_check(host.physical_actor_session == null,"no actor session was invented")
	_check(bench.toggle_pause(),"ordinary Play accepted")
	if not await _until(_ready,"material-only native owner and Main Rapier bound"):
		await _finish(); return
	_check(host.rigid_bodies.is_empty(),"no reference actor substitutes for material bodies")
	_check(host.object_shard_m4_runtime.bridge.space == host.rapier_bridge.shared_space(),"material bodies use ordinary Main space")
	_check(bench.toggle_pause(),"ordinary Pause accepted")
	await _until(_ready,"already admitted interval drained")
	bench._brush.value = 3
	for cut: Rect2i in Scenes.manifest("tower").cut_rects:
		var centers: Array[int] = []
		for y: int in range(cut.position.y+3,cut.end.y-3,4): centers.append(y)
		if centers.is_empty() or centers.back()!=cut.end.y-4: centers.append(cut.end.y-4)
		for y: int in centers:
			_check(bench.paint(Vector2i(cut.position.x+cut.size.x/2,y),0),"ordinary brush cuts the complete lower support stem")
			await process_frame
	_check(bench.toggle_pause(),"Resume after support cut")
	if not await _until(func(): return host.object_shard_m4_runtime.bridge.bodies.size()>0 and _ready(),"coherent native inventory detached without actors"):
		await _finish(); return
	var before_controls: int = host.object_shard_m4_runtime.controls_completed
	var before_steps: int = host.object_shard_m4_runtime.physical_steps
	var before_intervals: int = host.object_shard_m4_runtime.physical_intervals
	var before_suppressed: int = host.object_shard_m4_runtime.redundant_readiness_receipts_suppressed
	var before_snapshots: int = host.simulation_worker.object_shard_owner_profile().snapshot_calls
	var native_tick: int = int(host.object_shard_m4_runtime.frame.tick)
	if not await _until(func(): return int(host.object_shard_m4_runtime.frame.tick)>=native_tick+30,"30 native chemistry ticks accompany real material motion"):
		await _finish(); return
	_check(host.object_shard_m4_runtime.native_pose_acknowledgements>30,"real material poses acknowledged by native owner")
	_check(host.physical_actor_session == null and host.rigid_bodies.is_empty(),"continued play remains actorless")
	_check(bench.toggle_pause(),"Pause before authored restore")
	await _until(_ready,"final admitted interval drained")
	var completed_intervals: int = host.object_shard_m4_runtime.physical_intervals-before_intervals
	steady_window = {"intervals":completed_intervals,"steps":host.object_shard_m4_runtime.physical_steps-before_steps,
		"owner_controls":host.object_shard_m4_runtime.controls_completed-before_controls,
		"owner_snapshots":int(host.simulation_worker.object_shard_owner_profile().snapshot_calls)-before_snapshots,
		"redundant_readiness_suppressed":host.object_shard_m4_runtime.redundant_readiness_receipts_suppressed-before_suppressed}
	_check(host.object_shard_m4_runtime.redundant_readiness_receipts_suppressed-before_suppressed>=completed_intervals,
		"each completed actorless native tick synchronizes without another zero-lease readiness receipt")
	_check(host.object_shard_m4_runtime.controls_completed-before_controls \
		==host.object_shard_m4_runtime.physical_steps-before_steps+completed_intervals,
		"unchanged actorless play consumes exactly one native control per actual segment and leased interval completion")
	var generation: int = int(host.object_shard_m4_runtime.diagnostics().world_generation)
	_check(bench.restore_start(),"whole-World authored restore admitted")
	await _until(_installed,"fresh actorless authored start installed")
	_check(bench.toggle_pause(),"restored ordinary Play accepted")
	await _until(func(): return _ready() and int(host.object_shard_m4_runtime.diagnostics().world_generation)>generation,"fresh material-only owner replaces prior generation")
	await _finish()

func _finish() -> void:
	var result: Dictionary = {"schema":"objectshard-m4-material-only-workbench-v1",
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":checks,"failures":failures,"readiness_window":steady_window,
		"scope":"actual ordinary actorless Workbench native and Rapier"}
	if host != null:
		result["runtime"] = host.object_shard_m4_runtime.diagnostics()
		host.queue_free()
		await process_frame
		await process_frame
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
