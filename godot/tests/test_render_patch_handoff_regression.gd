extends SceneTree

# Focused regression for the worker-to-main RenderBridge ownership boundary.
# It covers the crash signature where valid rectangle metadata was paired with
# an empty RG8 payload, and proves that later worker accumulation cannot mutate
# an already-published packed array.

const MAIN_SCRIPT: Script = preload("res://scripts/main.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_render_payload_validation()
	_test_published_payload_ownership()
	_test_explicit_acknowledgement()
	if _failures == 0:
		print("Render patch handoff regression passed")
	quit(_failures)


func _test_render_payload_validation() -> void:
	var controller: Control = MAIN_SCRIPT.new()
	controller.render_channels = 2
	controller.render_image_format = Image.FORMAT_RG8
	controller.image = Image.create(
		CyberCellWorld.WORLD_WIDTH,
		CyberCellWorld.WORLD_HEIGHT,
		false,
		Image.FORMAT_RG8
	)

	var crash_rect: PackedInt32Array = PackedInt32Array([
		0,
		0,
		85,
		128,
		0,
		170,
	])
	_expect(
		not controller.apply_render_patches_to_image(
			crash_rect,
			PackedByteArray(),
			2
		),
		"empty 85x128 RG8 payload was accepted"
	)
	_expect(
		controller.last_render_patch_validation_error == "patch payload is empty",
		"empty-payload rejection did not report the expected reason"
	)

	var truncated_cells: PackedByteArray = PackedByteArray()
	truncated_cells.resize(21759)
	var truncated_error: String = controller.validate_render_patch_payload(
		crash_rect,
		truncated_cells,
		2
	)
	_expect(
		truncated_error.contains("requires payload bytes [0,21760)"),
		"one-byte-short RG8 payload was not rejected with exact bounds"
	)

	var valid_rect: PackedInt32Array = PackedInt32Array([0, 0, 2, 1, 0, 4])
	var valid_cells: PackedByteArray = PackedByteArray([1, 2, 3, 4])
	_expect(
		controller.apply_render_patches_to_image(valid_rect, valid_cells, 2),
		"valid compact RG8 patch was rejected"
	)
	controller.free()


func _test_published_payload_ownership() -> void:
	var worker: CyberSimulationWorker = CyberSimulationWorker.new()
	worker._append_native_render_packet({
		"serial": 1,
		"channels": 2,
		"full_refresh": true,
		"rectangles": PackedInt32Array([0, 0, 2, 1, 0, 4]),
		"cells": PackedByteArray([1, 2, 3, 4]),
	})
	worker._refresh_published_render_payload()
	var first_rectangles: PackedInt32Array = worker._published_render_patch_rectangles
	var first_cells: PackedByteArray = worker._published_render_patch_cells

	worker._append_native_render_packet({
		"serial": 2,
		"channels": 2,
		"full_refresh": false,
		"rectangles": PackedInt32Array([2, 0, 1, 1, 0, 2]),
		"cells": PackedByteArray([5, 6]),
	})
	_expect(first_rectangles.size() == 6, "published metadata changed after worker append")
	_expect(first_cells == PackedByteArray([1, 2, 3, 4]), "published bytes changed after worker append")
	_expect(worker._pending_render_patch_rectangles.size() == 12, "worker delta was not accumulated")
	_expect(worker._pending_render_patch_cells.size() == 6, "worker payload was not accumulated")

	worker._refresh_published_render_payload()
	_expect(
		worker._published_render_patch_rectangles.size() == 12,
		"new publication omitted accumulated metadata"
	)
	_expect(
		worker._published_render_patch_cells == PackedByteArray([1, 2, 3, 4, 5, 6]),
		"new publication omitted accumulated bytes"
	)
	_expect(first_cells == PackedByteArray([1, 2, 3, 4]), "old publication changed after republish")


func _test_explicit_acknowledgement() -> void:
	var worker: CyberSimulationWorker = CyberSimulationWorker.new()
	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	snapshot.serial = 1
	snapshot.render_snapshot_serial = 7
	worker._published_snapshot = snapshot
	var taken: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	_expect(taken == snapshot, "latest snapshot was not returned")
	_expect(
		worker._acknowledged_render_snapshot_serial == 0,
		"retrieving a snapshot acknowledged it before upload"
	)
	worker.acknowledge_render_snapshot(7)
	_expect(
		worker._acknowledged_render_snapshot_serial == 7,
		"explicit post-upload acknowledgement was not recorded"
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
