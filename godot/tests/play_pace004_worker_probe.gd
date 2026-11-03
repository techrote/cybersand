extends "res://tests/play_wait001_snapshot_probe.gd"

# Opt-in fixture observer of the ONE production owner. The owner is the only
# writer. Main may read native_rows only after stop_worker() has actually joined.
# These copied statistics never become gameplay authority or a mutable World view.
const MAX_NATIVE_ROWS: int = 12000
var native_rows: Array[Dictionary] = []
var publication_rows: Array[Dictionary] = []
var native_overflow: bool = false
var stop_join_usec: int = -1
var _observer: Variant
var _seen_generation: int = -1
var _seen_tick: int = -1
var observe_brush_load: bool = false # Configured before the worker starts.


func _publish_snapshot(worker_step_time_ms: float, paused: bool,
		render_snapshot_interval_usec: int, force_render_full_refresh: bool = false,
		rigid_body_states: PackedFloat32Array = PackedFloat32Array(),
		rigid_body_epoch: int = 0) -> void:
	var completed: int = Time.get_ticks_usec()
	super._publish_snapshot(worker_step_time_ms, paused, render_snapshot_interval_usec,
		force_render_full_refresh, rigid_body_states, rigid_body_epoch)
	# Copy the immutable packet just produced by this exclusive owner. Include
	# paused and pre-window packets: Main can consume a boundary publication
	# after the measured interval begins. Never synthesize that missing receipt.
	if publication_rows.size() >= MAX_NATIVE_ROWS:
		native_overflow = true
		return
	var packet: CyberSimulationSnapshot = _published_snapshot
	if packet != null:
		var is_completion: bool = _world != null and not _simulation_failed and not paused \
			and int(packet.tick_index) > 0 \
			and (_seen_generation != _world_generation or _seen_tick != int(packet.tick_index))
		publication_rows.append({"worker":get_instance_id(), "serial":int(packet.serial),
			"tick":int(packet.tick_index), "epoch":int(packet.rigid_body_epoch),
			"generation":int(packet.render_world_generation), "paused":bool(packet.paused),
			"published_usec":int(packet.published_usec), "render_usec":int(packet.render_generated_usec),
			"render_serial":int(packet.render_snapshot_serial), "render_tick":int(packet.render_tick_index),
			"render_revision":int(packet.world_revision),
			"simulation_revision":int(packet.simulation_world_revision),
			"failed":bool(packet.simulation_failed), "native_completed":is_completion,
			"completed_usec":completed if is_completion else 0})
	if _world == null or _simulation_failed or paused:
		return
	var tick: int = int(_world.tick_index)
	if tick <= 0 or (_seen_generation == _world_generation and _seen_tick == tick):
		return
	_seen_generation = _world_generation
	_seen_tick = tick
	if native_rows.size() >= MAX_NATIVE_ROWS:
		native_overflow = true
		return
	var started: int = Time.get_ticks_usec()
	if _observer == null:
		_observer = ClassDB.instantiate(&"CyberDemoBridge")
	var stats: Dictionary = _observer.inspect_statistics(_world)
	var values: Dictionary = stats.get("values", {})
	var row: Dictionary = {"completed_usec":completed, "tick":tick,
		"generation":_world_generation, "epoch":rigid_body_epoch,
		"statistics_ok":bool(stats.get("ok", false)),
		"statistics_tick":int(stats.get("completed_tick", -1)),
		"native_ms":float(_world.simulation_time_ms), "worker_step_ms":worker_step_time_ms,
		"capacity":int(_world.get_worker_threads()),
		"participants":int(values.get("worker_threads_observed", 0)),
		"jobs":int(_world.scheduler_jobs_last_tick),
		"parallel_phases":int(_world.scheduler_parallel_phases_last_tick),
		"phase_jobs":stats.get("phase_jobs_last_tick", []).duplicate(),
		"visited_cells":int(values.get("visited_cells", -1)),
		"moved_cells":int(values.get("moved_cells", -1)),
		"overruns":_worker_overruns, "serial":_snapshot_serial}
	native_rows.append(row)
	row["observer_usec"] = Time.get_ticks_usec() - started
	if observe_brush_load:
		# Small copied observations made only by the existing exclusive owner.
		# Main first reads these after join. These are observed cell values, not
		# invented per-command acknowledgements of the ordinary paint queue.
		var cells_started: int = Time.get_ticks_usec()
		var cells: Array[Dictionary] = []
		for point: Vector2i in [Vector2i(396,176),Vector2i(576,176)]:
			cells.append(_observer.inspect_cell(_world,point))
		row["brush_cells"] = cells
		row["brush_observer_usec"] = Time.get_ticks_usec() - cells_started


func stop_worker() -> void:
	var started: int = Time.get_ticks_usec()
	super.stop_worker()
	stop_join_usec = Time.get_ticks_usec() - started
