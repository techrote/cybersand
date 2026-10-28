extends SceneTree

# SOL281 opt-in render coalescing through the REAL exclusive worker owner and
# native RG8 exchange: stale/exact ACK, reset generation and the monotonic
# census, plus candidates P (partial ACK), E (exemption only) and R (per-run
# copy). Paused World, so only the scripted paints change cells. No Rapier, scene-tree physics or
# GPU upload. Configured native workers 1 and 4.
const Consumer = preload("res://scripts/solid_detachment_render_consumer.gd")
const PAINT_Y: int = 300
var checks: int = 0
var failures: Array[String] = []
var cohorts: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 RENDER OWNER ", message)

func _init() -> void:
	call_deferred("_run")

func _wait_for(worker: CyberSimulationWorker, after: int, predicate: Callable) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(after)
		if snapshot != null and predicate.call(snapshot):
			return snapshot
		await process_frame
	return null

func _paint(worker: CyberSimulationWorker, after: CyberSimulationSnapshot, x: int) -> CyberSimulationSnapshot:
	worker.queue_emit_disc(x, PAINT_Y, 0, CyberCellWorld.STEAM)
	return await _wait_for(worker, after.serial, func(s: CyberSimulationSnapshot) -> bool:
		return s.render_snapshot_serial > after.render_snapshot_serial)

func _single_full(s: CyberSimulationSnapshot) -> bool:
	if s == null:
		return false
	var r: PackedInt32Array = s.render_patch_rectangles
	return (s.render_full_refresh and r.size() == 6 and r[0] == 0 and r[1] == 0
		and r[2] == CyberCellWorld.WORLD_WIDTH and r[3] == CyberCellWorld.WORLD_HEIGHT
		and r[4] == 0 and r[5] == CyberCellWorld.WORLD_WIDTH * 2
		and s.render_patch_cells.size() == CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2)

func _material(s: CyberSimulationSnapshot, x: int) -> int:
	return int(s.render_patch_cells[(PAINT_Y * CyberCellWorld.WORLD_WIDTH + x) * 2])

func _run() -> void:
	check(ClassDB.class_exists(&"CyberNativeCellWorld"), "native RG8 owner is available")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		for workers: int in [1, 4]:
			await _cohort(workers)
		for workers: int in [1, 4]:
			await _partial_cohort(workers)
		for workers: int in [1, 4]:
			await _exemption_cohort(workers)
	print("SOL281_RENDER_OWNER ", JSON.stringify({"checks":checks, "failures":failures,
		"platform":OS.get_name(), "cohorts":cohorts}))
	quit(0 if failures.is_empty() else 1)

func _cohort(workers: int) -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	var label: String = "workers=%d " % workers
	var worker := CyberSimulationWorker.new()
	worker._experimental_render_full_coalescing = true
	worker.set_frame_state(0.0, false, true, Vector2i(160, 90), Vector2i.ZERO,
		Vector2i(320, 180), 0, 0, false, false, true)
	check(worker.start_worker(Vector2(150, 145)) == OK, label + "worker started")
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	check(initial != null and _single_full(initial), label + "first native publication is one full RG8 frame")
	if initial == null or not _single_full(initial):
		worker.stop_worker()
		return
	var before: int = _material(initial, 500)
	# Never ACK the initial frame: the dirty paint must coalesce onto it.
	var first: CyberSimulationSnapshot = await _paint(worker, initial, 500)
	check(first != null and _single_full(first)
		and first.render_world_generation == initial.render_world_generation
		and first.snapshot_render_coalesced_total > initial.snapshot_render_coalesced_total
		and first.snapshot_render_forced_full_retry_total == 0,
		label + "unacknowledged full frame absorbs the dirty paint without a forced-full retry")
	if first == null or not _single_full(first):
		worker.stop_worker()
		return
	check(before != CyberCellWorld.STEAM and _material(first, 500) == CyberCellWorld.STEAM
		and _material(initial, 500) == before,
		label + "coalesced pixel is new and the earlier publication is untouched")
	# A stale ACK of the older full serial must not discard the coalesced patch.
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	var second: CyberSimulationSnapshot = await _paint(worker, first, 510)
	check(second != null and _single_full(second)
		and second.snapshot_render_ack_clear_total == first.snapshot_render_ack_clear_total
		and second.snapshot_render_coalesced_total > first.snapshot_render_coalesced_total
		and _material(second, 500) == CyberCellWorld.STEAM
		and _material(second, 510) == CyberCellWorld.STEAM,
		label + "stale ACK cannot clear a newer coalesced frame or lose its patch")
	if second == null:
		worker.stop_worker()
		return
	# The exact latest serial clears it; later paints publish dirty patches only.
	worker.acknowledge_render_snapshot(second.render_snapshot_serial)
	var third: CyberSimulationSnapshot = await _paint(worker, second, 520)
	check(third != null and not third.render_full_refresh
		and third.render_patch_cells.size() < CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2
		and third.snapshot_render_ack_clear_total > second.snapshot_render_ack_clear_total
		and third.snapshot_render_coalesced_total == second.snapshot_render_coalesced_total,
		label + "exact ACK clears the retained frame and dirty-only publication resumes")
	if third == null:
		worker.stop_worker()
		return
	# Reset between coalesces: the new World never inherits the old image.
	worker.queue_reset(Vector2(150, 145))
	var reset: CyberSimulationSnapshot = await _wait_for(worker, third.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_world_generation > third.render_world_generation)
	check(reset != null and _single_full(reset)
		and reset.render_world_generation == third.render_world_generation + 1
		and reset.snapshot_render_coalesced_total == third.snapshot_render_coalesced_total,
		label + "reset publishes a full frame of the new World, never a coalesced one")
	if reset == null:
		worker.stop_worker()
		return
	var after_reset: CyberSimulationSnapshot = await _paint(worker, reset, 530)
	check(after_reset != null and _single_full(after_reset)
		and after_reset.render_world_generation == reset.render_world_generation
		and after_reset.snapshot_render_coalesced_total > reset.snapshot_render_coalesced_total
		and _material(after_reset, 530) == CyberCellWorld.STEAM
		and _material(after_reset, 500) == _material(reset, 500),
		label + "post-reset paint coalesces only onto the new generation's frame")
	var last: CyberSimulationSnapshot = after_reset if after_reset != null else reset
	cohorts.append({"workers":workers, "mode":"coalescing",
		"refreshes":last.snapshot_render_refresh_total,
		"dirty_onto_full":last.snapshot_render_dirty_onto_full_total,
		"coalesced":last.snapshot_render_coalesced_total,
		"forced_full_retries":last.snapshot_render_forced_full_retry_total,
		"ack_clears":last.snapshot_render_ack_clear_total})
	worker.stop_worker()

# Candidate P (partial ACK), workers 1 without and 4 WITH candidate R. The
# CPU image built from the full baseline plus rebased patches must equal a
# fresh native full frame byte for byte.
func _partial_cohort(workers: int) -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	var copy_by_run: bool = workers == 4
	var label: String = "P workers=%d copy_by_run=%s " % [workers, copy_by_run]
	var worker := CyberSimulationWorker.new()
	worker._experimental_render_partial_ack = true
	worker._experimental_render_copy_by_run = copy_by_run
	worker.set_frame_state(0.0, false, true, Vector2i(160, 90), Vector2i.ZERO,
		Vector2i(320, 180), 0, 0, false, false, true)
	check(worker.start_worker(Vector2(150, 145)) == OK, label + "worker started")
	var image = Consumer.new()
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	check(initial != null and _single_full(initial) and image.consume(initial),
		label + "first full frame consumed as the CPU baseline")
	if initial == null or not _single_full(initial):
		worker.stop_worker()
		return
	var first: CyberSimulationSnapshot = await _paint(worker, initial, 500)
	check(first != null and first.render_full_refresh
		and first.render_patch_rectangles.size() > 6
		and first.render_patch_cells.size() > CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2
		and first.snapshot_render_forced_full_retry_total == 0
		and first.snapshot_render_coalesced_total == 0,
		label + "dirty paint appends behind the unacknowledged baseline without a retry")
	if first == null:
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	var dropped: CyberSimulationSnapshot = await _wait_for(worker, first.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_snapshot_serial > first.render_snapshot_serial)
	check(dropped != null and not dropped.render_full_refresh
		and dropped.render_patch_cells.size() < CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2
		and dropped.snapshot_render_baseline_drop_total > first.snapshot_render_baseline_drop_total,
		label + "baseline ACK drops the full frame and republishes only appended patches")
	if dropped == null:
		worker.stop_worker()
		return
	check(image.consume(dropped), label + "strict consumer applies the rebased patches onto its baseline")
	var second: CyberSimulationSnapshot = await _paint(worker, dropped, 510)
	check(second != null and not second.render_full_refresh and image.consume(second),
		label + "a later dirty paint publishes and applies patches only")
	if second == null:
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(second.render_snapshot_serial)
	worker.request_render_full_refresh()
	var fresh: CyberSimulationSnapshot = await _wait_for(worker, second.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_snapshot_serial > second.render_snapshot_serial and s.render_full_refresh)
	var oracle = Consumer.new()
	check(fresh != null and _single_full(fresh) and oracle.consume(fresh)
		and oracle._image.get_data() == image._image.get_data(),
		label + "patched CPU image equals a fresh native full frame byte for byte")
	var last: CyberSimulationSnapshot = fresh if fresh != null else second
	cohorts.append({"workers":workers, "mode":"partial_ack", "copy_by_run":copy_by_run,
		"baseline_drops":last.snapshot_render_baseline_drop_total,
		"forced_full_retries":last.snapshot_render_forced_full_retry_total,
		"full_publications":last.snapshot_render_full_publication_total,
		"refreshes":last.snapshot_render_refresh_total})
	worker.stop_worker()

# Candidate E: P's overflow exemption without the baseline drop. Patches append
# behind the unacknowledged baseline; a baseline-only ACK changes nothing, and
# the CPU image must still equal a fresh native full frame byte for byte.
func _exemption_cohort(workers: int) -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	var label: String = "E workers=%d " % workers
	var worker := CyberSimulationWorker.new()
	worker._experimental_render_partial_ack = true
	worker._experimental_render_baseline_drop = false
	worker.set_frame_state(0.0, false, true, Vector2i(160, 90), Vector2i.ZERO,
		Vector2i(320, 180), 0, 0, false, false, true)
	check(worker.start_worker(Vector2(150, 145)) == OK, label + "worker started")
	var image = Consumer.new()
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	check(initial != null and _single_full(initial) and image.consume(initial),
		label + "first full frame consumed as the CPU baseline")
	if initial == null or not _single_full(initial):
		worker.stop_worker()
		return
	var first: CyberSimulationSnapshot = await _paint(worker, initial, 500)
	check(first != null and first.render_full_refresh
		and first.render_patch_rectangles.size() > 6
		and first.snapshot_render_forced_full_retry_total == 0
		and image.consume(first),
		label + "dirty paint appends behind the baseline without a retry and is consumed")
	if first == null:
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	var second: CyberSimulationSnapshot = await _paint(worker, first, 510)
	check(second != null and second.render_full_refresh
		and second.snapshot_render_baseline_drop_total == 0
		and second.snapshot_render_forced_full_retry_total == 0
		and image.consume(second),
		label + "baseline-only ACK drops nothing; full frame plus patches is republished")
	if second == null:
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(second.render_snapshot_serial)
	worker.request_render_full_refresh()
	var fresh: CyberSimulationSnapshot = await _wait_for(worker, second.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_snapshot_serial > second.render_snapshot_serial and s.render_full_refresh)
	var oracle = Consumer.new()
	check(fresh != null and _single_full(fresh) and oracle.consume(fresh)
		and oracle._image.get_data() == image._image.get_data(),
		label + "CPU image equals a fresh native full frame byte for byte")
	var last: CyberSimulationSnapshot = fresh if fresh != null else second
	cohorts.append({"workers":workers, "mode":"exemption_only",
		"baseline_drops":last.snapshot_render_baseline_drop_total,
		"forced_full_retries":last.snapshot_render_forced_full_retry_total,
		"full_publications":last.snapshot_render_full_publication_total,
		"refreshes":last.snapshot_render_refresh_total})
	worker.stop_worker()
