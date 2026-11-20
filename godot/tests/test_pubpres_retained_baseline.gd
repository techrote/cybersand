extends SceneTree

class ObservedWorker extends CyberSimulationWorker:
	var forced := 0
	var refuse_next_full := false

	func _take_native_render_snapshot(force_full: bool) -> Dictionary:
		if force_full:
			forced += 1
			if refuse_next_full:
				refuse_next_full = false
				return {"full_refresh":true,"channels":2,"cells":PackedByteArray([1,2]),
					"rectangles":PackedInt32Array([0,0,1,1,0,2])}
		return super._take_native_render_snapshot(force_full)

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PUBPRES retained baseline: " + detail)

func run() -> void:
	for extent: Vector2i in [Vector2i(1024,1024),Vector2i(2048,1024),Vector2i(2048,2048)]:
		var worker := ObservedWorker.new()
		if not worker._world.has_method(&"diagnostic_reset"):
			require(false,"source-matched native World required")
			break
		if not worker._world.diagnostic_reset({"extent":extent,"workers":1}):
			require(false,"diagnostic native extent " + str(extent))
			continue
		worker._workbench_extent = extent
		worker._publish_snapshot(0.0,true,0,true)
		var first: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		var baseline_bytes: int = extent.x * extent.y * 2
		require(first.render_patch_cells.size() == baseline_bytes,"exact initial RG8 baseline")
		var original_baseline: PackedByteArray = first.render_patch_cells.duplicate()
		worker._world.emit_disc(400,250,0,CyberCellWorld.WATER)
		worker._publish_snapshot(0.0,true,0)
		var second: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		require(worker.forced == 1 and second.render_patch_cells.size() == baseline_bytes + 2,
			"first dirty update consumes the separate byte budget")
		worker.acknowledge_render_snapshot(second.render_snapshot_serial + 100)
		worker.acknowledge_render_snapshot(first.render_snapshot_serial)
		worker.acknowledge_render_snapshot(first.render_snapshot_serial)
		worker._world.emit_disc(401,250,0,CyberCellWorld.SAND)
		worker._publish_snapshot(0.0,true,0)
		var third: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		require(worker.forced == 1 and third.render_patch_cells.size() == baseline_bytes + 4,
			"future, stale and duplicate acknowledgments preserve newer accumulated pixels")
		require(first.render_patch_cells.size() == baseline_bytes and second.render_patch_cells.size() == baseline_bytes + 2,
			"retained publications remain immutable")
		require(first.cells == original_baseline and first.render_patch_cells == original_baseline and second.cells == original_baseline
			and third.cells == original_baseline and second.render_patch_cells[baseline_bytes] == CyberCellWorld.WATER
			and third.render_patch_cells[baseline_bytes+2] == CyberCellWorld.SAND,
			"appended deltas preserve every retained full packet and its separate material updates")
		var stale: int = third.render_snapshot_serial
		worker.request_render_full_refresh()
		worker.refuse_next_full = true
		worker._publish_snapshot(0.0,true,0)
		var refused: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		require(refused.render_snapshot_serial == stale and worker._pending_render_recovery_required,
			"incomplete full reply preserves the previous serial and recovery request")
		worker.acknowledge_render_snapshot(stale)
		worker._publish_snapshot(0.0,true,0)
		var recovered: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		require(worker.forced == 3 and recovered.render_snapshot_serial > stale and recovered.render_patch_cells.size() == baseline_bytes,
			"covering ACK releases old bytes but cannot clear an unfulfilled full request")
		require(first.cells == original_baseline and first.render_patch_cells == original_baseline,
			"full replacement leaves the previously published array intact")
	print("PUBPRES_RETAINED_BASELINE checks=%d failures=%d" % [checks,failures])
	quit(int(failures > 0))
