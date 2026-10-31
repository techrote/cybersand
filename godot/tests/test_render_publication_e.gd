extends SceneTree

const EWorker = preload("res://tests/render_publication_e.gd")
const ControlWorker = preload("res://tests/render_publication_worker.gd")
const Main = preload("res://scripts/main.gd")
const FRAME: int = 1024 * 1024
var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _count(worker, event: String) -> int:
	return int(worker.trace.result().counts.get(event, 0))

func _packet(serial: int, channels: int, full: bool, rectangles: PackedInt32Array, bytes: int) -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(bytes)
	return {"status": 1, "serial": serial, "channels": channels, "full_refresh": full,
		"rectangles": rectangles, "cells": cells}

func _full(serial: int = 1, channels: int = 2) -> Dictionary:
	return _packet(serial, channels, true, PackedInt32Array([0, 0, 1024, 1024, 0, 1024 * channels]), FRAME * channels)

func _dirty(serial: int = 2, channels: int = 2) -> Dictionary:
	return _packet(serial, channels, false, PackedInt32Array([5, 6, 1, 1, 0, channels]), channels)

func _synthetic(channels: int = 2):
	var worker = EWorker.new()
	worker._append_native_render_packet(_full(1, channels))
	# Model the base publication's transport-generation commit after accumulation.
	worker._pending_render_world_generation = worker._world_generation
	return worker

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_test_baseline_and_byte_budget()
	_test_rectangle_budget()
	_test_invalid_state()
	_test_rejected_upload()
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native E oracle requires actual native owner")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		_test_real_native_owner()
	print("RENDER_PUBLICATION_E: %d assertions, %d failures" % [assertions, failures])
	quit(failures)

func _test_baseline_and_byte_budget() -> void:
	var worker = _synthetic()
	worker._append_native_render_packet(_dirty())
	_expect(worker._e_has_qualified_baseline(), "exact current RG8 baseline lost qualification")
	_expect(not worker._pending_render_exceeds_budget(), "full+dirty charged baseline against dirty budget")
	_expect(_count(worker, "dirty_onto_full") == 1 and _count(worker, "forced_retry") == 0,
		"full+dirty census is not monotonic actual append/retry accounting")
	worker._refresh_published_render_payload()
	var old_cells: PackedByteArray = worker._published_render_patch_cells
	worker._append_native_render_packet(_dirty(3))
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2 + 4 and old_cells.size() == FRAME * 2 + 2,
		"successive dirty append mutated old packed payload or dropped baseline")
	var baseline_serial: int = worker.e_baseline_serial
	_expect(baseline_serial == 1 and worker._pending_render_snapshot_serial == 3, "dirty append rebased baseline serial")
	var control = ControlWorker.new()
	control._append_native_render_packet(_full())
	control._append_native_render_packet(_dirty())
	_expect(control._pending_render_exceeds_budget(), "default control no longer uses original full-sized cap")
	# R8 makes the exact byte cap and one-byte-over cases representable without
	# malformed half-pixel RG8 data. Two complete dirty rectangles consume 2MiB.
	worker = _synthetic(1)
	var at_limit := _packet(2, 1, false, PackedInt32Array([
		0, 0, 1024, 1024, 0, 1024, 0, 0, 1024, 1024, FRAME, 1024]), FRAME * 2)
	worker._append_native_render_packet(at_limit)
	_expect(not worker._pending_render_exceeds_budget(), "exact dirty byte threshold rejected")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 3, "exact threshold omitted dirty bytes")
	worker._append_native_render_packet(_dirty(3, 1))
	_expect(worker._pending_render_exceeds_budget(), "one byte over dirty cap did not request recovery")
	_expect(_count(worker, "e_preflight_recovery") == 1, "one-over byte preflight was not counted")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 3 and worker.e_retained_high_water == FRAME * 3,
		"one-over packet exceeded baseline plus dirty budget before recovery")
	_expect(worker.e_baseline_serial == 1, "overflow dropped baseline before full recovery")

func _test_rectangle_budget() -> void:
	var worker = _synthetic(1)
	var rectangles := PackedInt32Array()
	for index: int in range(256):
		rectangles.append_array(PackedInt32Array([index, 0, 1, 1, index, 1]))
	worker._append_native_render_packet(_packet(2, 1, false, rectangles, 256))
	_expect(not worker._pending_render_exceeds_budget(), "exact dirty rectangle threshold rejected")
	_expect(worker._pending_render_patch_rectangles.size() == 257 * 6, "full record not separately accounted")
	worker._append_native_render_packet(_dirty(3, 1))
	_expect(worker._pending_render_exceeds_budget() and _count(worker, "e_preflight_recovery") == 1,
		"one dirty rectangle over cap did not request recovery")
	_expect(worker._pending_render_patch_rectangles.size() == 257 * 6, "rectangle preflight allowed transient over-cap retention")

func _test_invalid_state() -> void:
	for field: String in ["failed", "status", "serial"]:
		var invalid = _synthetic()
		var full_packet: Dictionary = _full(2)
		full_packet[field] = true if field == "failed" else -1
		invalid._append_native_render_packet(full_packet)
		_expect(not invalid._e_has_qualified_baseline() and invalid._pending_render_exceeds_budget(), "invalid full envelope received exemption: " + field)
	var failed_dirty = _synthetic()
	var dirty_packet: Dictionary = _dirty()
	dirty_packet.failed = true
	failed_dirty._append_native_render_packet(dirty_packet)
	_expect(not failed_dirty._e_has_qualified_baseline() and failed_dirty._pending_render_exceeds_budget(), "failed dirty envelope received exemption")
	for known_status: int in [0, 1, 2, 3]:
		var known = _synthetic()
		var complete: Dictionary = _full(0)
		complete.status = known_status
		known._append_native_render_packet(complete)
		_expect(known._e_has_qualified_baseline(), "complete forced full copy wrongly denied for known native status")
	var worker = _synthetic()
	worker._append_native_render_packet(_dirty(2, 1))
	_expect(not worker._e_has_qualified_baseline() and worker._pending_render_exceeds_budget(), "channel mismatch received exemption")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2, "channel mismatch appended incompatible pixels")
	worker = _synthetic()
	worker._world_generation += 1
	worker._append_native_render_packet(_dirty())
	_expect(not worker._e_has_qualified_baseline() and worker._pending_render_exceeds_budget(), "old-generation baseline received exemption")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2, "new-generation dirty packet appended to old baseline")
	var bad_rectangles: Array[PackedInt32Array] = [
		PackedInt32Array([1, 0, 1024, 1024, 0, 2048]),
		PackedInt32Array([0, 1, 1024, 1024, 0, 2048]),
		PackedInt32Array([0, 0, 1023, 1024, 0, 2048]),
		PackedInt32Array([0, 0, 1024, 1023, 0, 2048]),
		PackedInt32Array([0, 0, 1024, 1024, 1, 2048]),
		PackedInt32Array([0, 0, 1024, 1024, 0, 2049]),
		PackedInt32Array([0, 0, 1024, 1024, 0, 2048, 0]),
	]
	for rectangles: PackedInt32Array in bad_rectangles:
		worker = _synthetic()
		worker._append_native_render_packet(_packet(2, 2, true, rectangles, FRAME * 2))
		_expect(not worker._e_has_qualified_baseline() and worker._pending_render_exceeds_budget(), "malformed full metadata received exemption")
	for size_delta: int in [-1, 1]:
		worker = _synthetic()
		var bad: Dictionary = _full(2)
		bad.cells.resize(FRAME * 2 + size_delta)
		worker._append_native_render_packet(bad)
		_expect(not worker._e_has_qualified_baseline() and worker._pending_render_exceeds_budget(), "non-exact full payload received exemption")
	for channels: int in [0, 3]:
		worker = _synthetic()
		worker._append_native_render_packet(_full(2, channels))
		_expect(not worker._e_has_qualified_baseline() and worker._pending_render_exceeds_budget(), "unsupported full channel count received exemption")
	worker = _synthetic()
	worker._pending_render_patch_rectangles[5] = 2047
	_expect(not worker._e_has_qualified_baseline(), "changed retained metadata remained qualified")
	worker = _synthetic()
	worker._append_native_render_packet(_packet(2, 2, false, PackedInt32Array([0, 0, 1, 1, 1, 2]), 3))
	_expect(not worker._e_has_qualified_baseline() and _count(worker, "e_preflight_recovery") == 1,
		"ambiguous dirty offset received exemption")

func _test_rejected_upload() -> void:
	var worker = _synthetic()
	var controller: Control = Main.new()
	controller.simulation_worker = worker
	controller.render_channels = 2
	controller.render_image_format = Image.FORMAT_RG8
	controller.image = Image.create(1024, 1024, false, Image.FORMAT_RG8)
	controller.texture = ImageTexture.create_from_image(controller.image)
	controller.previous_texture = ImageTexture.create_from_image(controller.image)
	var bad := CyberSimulationSnapshot.new()
	bad.render_snapshot_serial = 9
	bad.render_world_generation = 1
	bad.render_channels = 2
	bad.render_patch_rectangles = PackedInt32Array([0, 0, 1, 1, 0, 2])
	# Suppress only the duplicate-rejection log; invoke the actual production
	# consumer, validator and failed-upload/full-request branch without overrides.
	controller.last_rejected_render_snapshot_serial = 9
	controller.consume_render_snapshot(bad)
	_expect(controller.rejected_render_snapshot_count == 1, "malformed real consumer upload was not rejected")
	_expect(worker._acknowledged_render_snapshot_serial == 0 and _count(worker, "ack_issue") == 0,
		"rejected production upload issued ACK")
	_expect(_count(worker, "full_request") == 1 and worker._render_full_refresh_requested,
		"rejected production upload omitted full refresh request")
	_expect(worker.e_baseline_serial == 1 and worker._pending_render_patch_cells.size() == FRAME * 2,
		"rejected upload cleared retained baseline")
	controller.free()

func _test_real_native_owner() -> void:
	var worker = EWorker.new()
	worker._publish_snapshot(0.0, true, 0, true)
	var first_serial: int = worker._pending_render_snapshot_serial
	_expect(worker._e_has_qualified_baseline(), "real initial native full frame did not qualify")
	worker._world.emit_disc(400, 250, 0, CyberCellWorld.WATER)
	worker._publish_snapshot(0.0, true, 0)
	worker._world.emit_disc(401, 250, 0, CyberCellWorld.SAND)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "dirty_onto_full") == 2 and _count(worker, "forced_retry") == 0,
		"real native full+dirty path retried or was not exercised")
	_expect(worker._published_snapshot.cells.size() == FRAME * 2, "legacy cells included appended dirty bytes")
	_expect(worker.e_baseline_serial == first_serial, "real dirty stream dropped/rebased baseline")
	var controller: Control = Main.new()
	controller.render_channels = 2
	controller.render_image_format = Image.FORMAT_RG8
	controller.image = Image.create(1024, 1024, false, Image.FORMAT_RG8)
	_expect(controller.apply_render_patches_to_image(worker._pending_render_patch_rectangles,
		worker._pending_render_patch_cells, 2), "real retained full+dirty CPU image application failed")
	var fresh: Dictionary = worker._world.take_render_snapshot(true)
	_expect(controller.image.get_data() == fresh.cells, "full+dirty reconstruction differs from fresh native RG8 frame")
	controller.free()
	var latest_serial: int = worker._pending_render_snapshot_serial
	worker.acknowledge_render_snapshot(first_serial)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "ack_clear") == 0 and _count(worker, "ack_stale") > 0
		and worker._pending_render_patch_cells.size() > FRAME * 2, "stale baseline ACK cleared later retained dirty pixels")
	worker.acknowledge_render_snapshot(latest_serial)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "ack_clear") == 1 and worker._pending_render_patch_cells.is_empty(), "latest exact ACK failed to clear")
	_expect(worker.e_baseline_serial == 0, "ACK clear retained exemption tag")
	# Exercise the same synchronous reset primitive and generation increment used
	# by the owner loop; existing async reset regression remains separately required.
	_expect(bool(worker._world.reset_demo_world()), "native reset failed")
	worker._world_generation += 1
	worker._publish_snapshot(0.0, true, 0)
	_expect(worker.e_baseline_generation == worker._world_generation and worker._pending_render_snapshot_serial > latest_serial,
		"reset did not fence baseline generation and worker-lifetime serial")
	worker.acknowledge_render_snapshot(latest_serial)
	worker._world.emit_disc(402, 250, 0, CyberCellWorld.WATER)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "ack_clear") == 1 and worker._pending_render_patch_cells.size() > FRAME * 2,
		"previous-generation ACK cleared new baseline")
	# Exact byte-budget synthetic pending state, followed by a real native dirty
	# exchange: prove preflight invokes existing second native forced-full recovery.
	var budget_packet: Dictionary = _packet(worker._pending_render_snapshot_serial + 1, 2, false,
		PackedInt32Array([0, 0, 1024, 1024, 0, 2048]), FRAME * 2)
	# Fresh valid full replaces earlier dirty before filling the exact dirty budget.
	worker._append_native_render_packet(worker._world.take_render_snapshot(true))
	worker._pending_render_world_generation = worker._world_generation
	worker._append_native_render_packet(budget_packet)
	_expect(not worker._pending_render_exceeds_budget(), "real owner exact post-baseline byte budget rejected")
	worker._world.emit_disc(403, 250, 0, CyberCellWorld.SAND)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "forced_retry") == 1 and _count(worker, "e_preflight_recovery") == 1,
		"one-over native exchange did not use existing forced-full retry")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2 and not worker.e_recovery_required,
		"forced recovery did not replace with one complete native full frame")
	_expect(worker.pending_high_water <= FRAME * 4 and worker.e_retained_high_water <= FRAME * 4,
		"candidate transient or retained pending high-water exceeded one baseline plus dirty budget")
