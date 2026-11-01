extends SceneTree

# Production policy exercised directly; only the test subclass adds counters.
# These counters are monotonic owner operations, never sampled event-array size.
class ObservedWorker extends CyberSimulationWorker:
	var counts: Dictionary = {}
	var pending_high_water: int = 0
	var pending_metadata_high_water: int = 0

	func _count(event: String) -> void:
		counts[event] = int(counts.get(event, 0)) + 1

	func _append_native_render_packet(packet: Dictionary) -> void:
		var serial_before: int = _pending_render_snapshot_serial
		var full_before: bool = _pending_render_full_refresh
		var recovery_before: bool = _pending_render_recovery_required
		super._append_native_render_packet(packet)
		if _pending_render_snapshot_serial > serial_before:
			_count("append")
			if bool(packet.get("full_refresh", false)):
				_count("full")
			elif full_before:
				_count("dirty_onto_full")
		if _pending_render_recovery_required and not recovery_before:
			_count("preflight_recovery")
		pending_high_water = maxi(pending_high_water, _pending_render_patch_cells.size())
		pending_metadata_high_water = maxi(pending_metadata_high_water, _pending_render_patch_rectangles.size())

	func _pending_render_exceeds_budget() -> bool:
		var required: bool = super._pending_render_exceeds_budget()
		if required:
			_count("forced_retry")
		return required

	func _clear_pending_render_patches() -> void:
		if not _pending_render_patch_cells.is_empty():
			_count("ack_clear")
		super._clear_pending_render_patches()

	func acknowledge_render_snapshot(serial: int) -> void:
		_count("ack_issue")
		super.acknowledge_render_snapshot(serial)

	func request_render_full_refresh() -> void:
		_count("full_request")
		super.request_render_full_refresh()

	func _publish_snapshot(step_ms: float, paused: bool, interval: int, force: bool = false,
			bodies: PackedFloat32Array = PackedFloat32Array(), epoch: int = 0) -> void:
		if (_acknowledged_render_snapshot_serial > 0
			and _acknowledged_render_snapshot_serial < _pending_render_snapshot_serial
			and not _pending_render_patch_cells.is_empty()):
			_count("ack_stale")
		var refreshed_before: int = _last_render_snapshot_usec
		super._publish_snapshot(step_ms, paused, interval, force, bodies, epoch)
		if _last_render_snapshot_usec != refreshed_before:
			_count("refresh")
		_count("owner_complete")

# Bounded transport fault injection around a real native World. The ordinary
# worker still executes its actual publication/ACK/recovery implementation.
# All simulation properties and valid packets come from the native adapter.
class PacketFaultWorld extends RefCounted:
	var native: Object
	var inject: bool = false
	var forced_only: bool = false
	var response: Dictionary = {}
	var calls: int = 0
	var forced_calls: int = 0
	var injected_calls: int = 0

	func _init(world: Object) -> void:
		native = world

	func _get(property: StringName) -> Variant:
		return native.get(property)

	func take_render_snapshot(force: bool) -> Dictionary:
		calls += 1
		if force:
			forced_calls += 1
		if inject and (force or not forced_only):
			injected_calls += 1
			return response.duplicate(true)
		return native.take_render_snapshot(force)

	func rigid_body_results() -> PackedFloat32Array:
		return native.rigid_body_results()

	func get_hard_surface_chunk_rectangles() -> PackedInt32Array:
		return native.get_hard_surface_chunk_rectangles()

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
	return int(worker.counts.get(event, 0))

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
	var worker = ObservedWorker.new()
	worker._append_native_render_packet(_full(1, channels))
	# Model the base publication's transport-generation commit after accumulation.
	worker._pending_render_world_generation = worker._world_generation
	return worker

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_test_baseline_and_byte_budget()
	_test_rectangle_budget()
	_test_no_baseline_and_empty_outcomes()
	_test_invalid_state()
	_test_rejected_upload()
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native E oracle requires actual native owner")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		_test_real_native_owner()
		_test_world_replacement()
		_test_publication_cadence()
		_test_recovery_survives_covering_ack()
		_test_forced_response_contract()
	print("RENDER_RETAINED_BASELINE: %d assertions, %d failures" % [assertions, failures])
	quit(failures)

func _test_publication_cadence() -> void:
	var worker = ObservedWorker.new()
	worker._publish_snapshot(0.0, true, 1000000, true)
	var refreshes: int = _count(worker, "refresh")
	worker._world.emit_disc(400, 250, 0, CyberCellWorld.WATER)
	worker._last_render_snapshot_usec = Time.get_ticks_usec()
	worker._publish_snapshot(0.0, true, 1000000)
	_expect(_count(worker, "refresh") == refreshes and worker._published_snapshot.world_revision != worker._published_snapshot.simulation_world_revision,
		"deferred publication cadence did not retain an older render revision")
	worker._last_render_snapshot_usec -= 1000001
	worker._publish_snapshot(0.0, true, 1000000)
	_expect(_count(worker, "refresh") == refreshes + 1 and worker._published_snapshot.world_revision == worker._published_snapshot.simulation_world_revision,
		"ordinary elapsed cadence did not publish the deferred dirty edit")
	_expect(_count(worker, "forced_retry") == 0 and _count(worker, "ack_issue") == 0,
		"cadence catch-up introduced a forced full or artificial ACK")

func _test_baseline_and_byte_budget() -> void:
	var worker = _synthetic()
	worker._append_native_render_packet(_dirty())
	_expect(worker._has_qualified_render_baseline(), "exact current RG8 baseline lost qualification")
	_expect(not worker._pending_render_exceeds_budget(), "full+dirty charged baseline against dirty budget")
	_expect(_count(worker, "dirty_onto_full") == 1 and _count(worker, "forced_retry") == 0,
		"full+dirty census is not monotonic actual append/retry accounting")
	worker._refresh_published_render_payload()
	var old_cells: PackedByteArray = worker._published_render_patch_cells
	var frozen_cells: PackedByteArray = old_cells.duplicate()
	var old_rectangles: PackedInt32Array = worker._published_render_patch_rectangles
	var frozen_rectangles: PackedInt32Array = old_rectangles.duplicate()
	var changed: Dictionary = _dirty(3)
	changed.cells.fill(123)
	worker._append_native_render_packet(changed)
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2 + 4 and old_cells.size() == FRAME * 2 + 2,
		"successive dirty append mutated old packed payload or dropped baseline")
	worker._refresh_published_render_payload()
	_expect(old_cells == frozen_cells and old_rectangles == frozen_rectangles,
		"later append/publication changed retained bytes or metadata")
	var baseline_serial: int = worker._pending_render_baseline_serial
	_expect(baseline_serial == 1 and worker._pending_render_snapshot_serial == 3, "dirty append rebased baseline serial")
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
	_expect(_count(worker, "preflight_recovery") == 1, "one-over byte preflight was not counted")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 3 and worker.pending_high_water == FRAME * 3,
		"one-over packet exceeded baseline plus dirty budget before recovery")
	_expect(worker._pending_render_baseline_serial == 1, "overflow dropped baseline before full recovery")

func _test_rectangle_budget() -> void:
	var worker = _synthetic(1)
	var rectangles := PackedInt32Array()
	for index: int in range(256):
		rectangles.append_array(PackedInt32Array([index, 0, 1, 1, index, 1]))
	worker._append_native_render_packet(_packet(2, 1, false, rectangles, 256))
	_expect(not worker._pending_render_exceeds_budget(), "exact dirty rectangle threshold rejected")
	_expect(worker._pending_render_patch_rectangles.size() == 257 * 6, "full record not separately accounted")
	worker._append_native_render_packet(_dirty(3, 1))
	_expect(worker._pending_render_exceeds_budget() and _count(worker, "preflight_recovery") == 1,
		"one dirty rectangle over cap did not request recovery")
	_expect(worker._pending_render_patch_rectangles.size() == 257 * 6, "rectangle preflight allowed transient over-cap retention")

func _test_no_baseline_and_empty_outcomes() -> void:
	var worker = ObservedWorker.new()
	worker._append_native_render_packet(_packet(1, 1, false, PackedInt32Array([
		0, 0, 1024, 1024, 0, 1024, 0, 0, 1024, 1024, FRAME, 1024]), FRAME * 2))
	worker._pending_render_world_generation = worker._world_generation
	_expect(not worker._has_qualified_render_baseline() and not worker._pending_render_exceeds_budget()
		and worker._pending_render_patch_cells.size() == FRAME * 2,
		"ordinary dirty stream did not retain its exact original byte budget")
	worker._append_native_render_packet(_dirty(2, 1))
	_expect(worker._pending_render_exceeds_budget() and worker.pending_high_water == FRAME * 2,
		"ordinary dirty stream acquired a baseline exemption or transient excess")
	worker = ObservedWorker.new()
	var rectangles := PackedInt32Array()
	for index: int in range(256):
		rectangles.append_array(PackedInt32Array([index, 0, 1, 1, index, 1]))
	worker._append_native_render_packet(_packet(1, 1, false, rectangles, 256))
	worker._pending_render_world_generation = worker._world_generation
	_expect(not worker._pending_render_exceeds_budget(), "ordinary dirty exact rectangle budget rejected")
	worker._append_native_render_packet(_dirty(2, 1))
	_expect(worker._pending_render_exceeds_budget() and worker.pending_metadata_high_water == 256 * 6,
		"ordinary dirty stream acquired an extra full metadata allowance")
	worker = _synthetic()
	for status: int in [0, 2]:
		var empty: Dictionary = _packet(0, 2, false, PackedInt32Array(), 0)
		empty.status = status
		worker._append_native_render_packet(empty)
		_expect(worker._has_qualified_render_baseline() and not worker._pending_render_exceeds_budget()
			and _count(worker, "append") == 1 and _count(worker, "ack_clear") == 0,
			"NoChanges/backpressure changed retained identity or acknowledged bytes")
	var mismatched: Dictionary = _packet(0, 1, false, PackedInt32Array(), 0)
	mismatched.status = 0
	worker._append_native_render_packet(mismatched)
	_expect(not worker._has_qualified_render_baseline() and worker._pending_render_exceeds_budget(),
		"empty channel-mismatched envelope retained an exemption")
	var serial: int = worker._pending_render_snapshot_serial
	worker._append_native_render_packet(_dirty(2))
	_expect(worker._pending_render_snapshot_serial == serial and worker._pending_render_recovery_required,
		"dirty packet cleared a required full recovery")
	worker._append_native_render_packet(_full(3))
	_expect(worker._has_qualified_render_baseline() and not worker._pending_render_recovery_required,
		"valid full recovery failed to reestablish retained state")

func _test_invalid_state() -> void:
	for field: String in ["channels", "full_refresh", "cells", "rectangles", "failed", "serial", "status"]:
		var invalid_type = _synthetic()
		var coerced: Dictionary = _full(2)
		match field:
			"channels": coerced.channels = "2"
			"full_refresh": coerced.full_refresh = 1
			"cells": coerced.cells = []
			"rectangles": coerced.rectangles = [0, 0, 1024, 1024, 0, 2048]
			"failed": coerced.failed = ""
			"serial": coerced.serial = "2"
			"status": coerced.status = "1"
		invalid_type._append_native_render_packet(coerced)
		_expect(not invalid_type._has_qualified_render_baseline() and invalid_type._pending_render_exceeds_budget(), "coerced full identity received exemption: " + field)
	for full_flag: bool in [true, false]:
		var empty_invalid = _synthetic()
		empty_invalid._append_native_render_packet(_packet(2, 2, full_flag, PackedInt32Array(), 0))
		_expect(not empty_invalid._has_qualified_render_baseline() and empty_invalid._pending_render_exceeds_budget(), "empty Published/full envelope retained exemption")
	for field: String in ["failed", "status", "serial"]:
		var invalid = _synthetic()
		var full_packet: Dictionary = _full(2)
		full_packet[field] = true if field == "failed" else -1
		invalid._append_native_render_packet(full_packet)
		_expect(not invalid._has_qualified_render_baseline() and invalid._pending_render_exceeds_budget(), "invalid full envelope received exemption: " + field)
	var failed_dirty = _synthetic()
	var dirty_packet: Dictionary = _dirty()
	dirty_packet.failed = true
	failed_dirty._append_native_render_packet(dirty_packet)
	_expect(not failed_dirty._has_qualified_render_baseline() and failed_dirty._pending_render_exceeds_budget(), "failed dirty envelope received exemption")
	for known_status: int in [0, 1, 2, 3]:
		var known = _synthetic()
		var complete: Dictionary = _full(0)
		complete.status = known_status
		known._append_native_render_packet(complete)
		_expect(known._has_qualified_render_baseline(), "complete forced full copy wrongly denied for known native status")
	var worker = _synthetic()
	worker._append_native_render_packet(_dirty(2, 1))
	_expect(not worker._has_qualified_render_baseline() and worker._pending_render_exceeds_budget(), "channel mismatch received exemption")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2, "channel mismatch appended incompatible pixels")
	worker = _synthetic()
	worker._world_generation += 1
	worker._append_native_render_packet(_dirty())
	_expect(not worker._has_qualified_render_baseline() and worker._pending_render_exceeds_budget(), "old-generation baseline received exemption")
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
		_expect(not worker._has_qualified_render_baseline() and worker._pending_render_exceeds_budget(), "malformed full metadata received exemption")
	for size_delta: int in [-1, 1]:
		worker = _synthetic()
		var bad: Dictionary = _full(2)
		bad.cells.resize(FRAME * 2 + size_delta)
		worker._append_native_render_packet(bad)
		_expect(not worker._has_qualified_render_baseline() and worker._pending_render_exceeds_budget(), "non-exact full payload received exemption")
	for channels: int in [0, 3]:
		worker = _synthetic()
		worker._append_native_render_packet(_full(2, channels))
		_expect(not worker._has_qualified_render_baseline() and worker._pending_render_exceeds_budget(), "unsupported full channel count received exemption")
	worker = _synthetic()
	worker._pending_render_patch_rectangles[5] = 2047
	_expect(not worker._has_qualified_render_baseline(), "changed retained metadata remained qualified")
	worker = _synthetic()
	worker._pending_render_world_generation = 0
	_expect(not worker._has_qualified_render_baseline(), "uncommitted/mismatched publication generation received exemption")
	worker = _synthetic()
	worker._append_native_render_packet(_packet(2, 2, false, PackedInt32Array([0, 0, 1, 1, 1, 2]), 3))
	_expect(not worker._has_qualified_render_baseline() and _count(worker, "preflight_recovery") == 1,
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
	bad.serial = 1
	bad.render_snapshot_serial = 9
	bad.render_world_generation = 1
	bad.render_channels = 2
	bad.render_patch_rectangles = PackedInt32Array([0, 0, 1, 1, 0, 2])
	# Suppress only the duplicate-rejection log; invoke the actual production
	# consumer, validator and failed-upload/full-request branch without overrides.
	controller.last_rejected_render_snapshot_serial = 9
	worker._published_snapshot = bad
	controller.consume_worker_snapshot()
	_expect(controller.rejected_render_snapshot_count == 1, "malformed real consumer upload was not rejected")
	_expect(worker._acknowledged_render_snapshot_serial == 0 and _count(worker, "ack_issue") == 0,
		"rejected production upload issued ACK")
	_expect(_count(worker, "full_request") == 1 and worker._render_full_refresh_requested,
		"rejected production upload omitted full refresh request")
	_expect(worker._pending_render_baseline_serial == 1 and worker._pending_render_patch_cells.size() == FRAME * 2,
		"rejected upload cleared retained baseline")
	controller.free()

func _test_real_native_owner() -> void:
	var worker = ObservedWorker.new()
	worker._publish_snapshot(0.0, true, 0, true)
	var first_serial: int = worker._pending_render_snapshot_serial
	_expect(worker._has_qualified_render_baseline(), "real initial native full frame did not qualify")
	worker._world.emit_disc(400, 250, 0, CyberCellWorld.WATER)
	worker._publish_snapshot(0.0, true, 0)
	worker._world.emit_disc(401, 250, 0, CyberCellWorld.SAND)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "dirty_onto_full") == 2 and _count(worker, "forced_retry") == 0,
		"real native full+dirty path retried or was not exercised")
	_expect(worker._published_snapshot.cells.size() == FRAME * 2, "legacy cells included appended dirty bytes")
	_expect(worker._pending_render_baseline_serial == first_serial, "real dirty stream dropped/rebased baseline")
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
	_expect(worker._pending_render_baseline_serial == 0, "ACK clear retained exemption tag")
	# Exercise the same synchronous reset primitive and generation increment used
	# by the owner loop; existing async reset regression remains separately required.
	_expect(bool(worker._world.reset_demo_world()), "native reset failed")
	worker._world_generation += 1
	worker._publish_snapshot(0.0, true, 0)
	_expect(worker._pending_render_baseline_generation == worker._world_generation and worker._pending_render_snapshot_serial > latest_serial,
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
	_expect(_count(worker, "forced_retry") == 1 and _count(worker, "preflight_recovery") == 1,
		"one-over native exchange did not use existing forced-full retry")
	_expect(worker._pending_render_patch_cells.size() == FRAME * 2 and not worker._pending_render_recovery_required,
		"forced recovery did not replace with one complete native full frame")
	_expect(worker.pending_high_water == FRAME * 4 and worker.pending_metadata_high_water <= 257 * 6,
		"candidate transient or retained pending high-water exceeded one baseline plus dirty budget")

func _test_world_replacement() -> void:
	var worker = ObservedWorker.new()
	worker._publish_snapshot(0.0, true, 0, true)
	worker._world.emit_disc(405, 250, 0, CyberCellWorld.WATER)
	worker._publish_snapshot(0.0, true, 0)
	var old_snapshot: CyberSimulationSnapshot = worker._published_snapshot
	var old_bytes: PackedByteArray = old_snapshot.render_patch_cells.duplicate()
	var old_rectangles: PackedInt32Array = old_snapshot.render_patch_rectangles.duplicate()
	var old_serial: int = old_snapshot.render_snapshot_serial
	# Replace the actual native adapter/World, including its restarting exchange
	# serial. The exclusive owner's accepted-replacement fence stays monotonic.
	worker._world = worker._create_world()
	worker._world_generation += 1
	worker._publish_snapshot(0.0, true, 0)
	_expect(worker._has_qualified_render_baseline()
		and worker._pending_render_snapshot_serial > old_serial
		and worker._pending_render_patch_cells.size() == FRAME * 2
		and worker._pending_render_patch_rectangles.size() == 6,
		"World replacement combined old dirty data or restarted worker ACK serials")
	worker.acknowledge_render_snapshot(old_serial)
	worker._world.emit_disc(406, 250, 0, CyberCellWorld.SAND)
	worker._publish_snapshot(0.0, true, 0)
	_expect(_count(worker, "ack_clear") == 0 and _count(worker, "ack_stale") == 1
		and worker._pending_render_patch_cells.size() > FRAME * 2,
		"old-World ACK cleared the replacement baseline or dirty suffix")
	_expect(old_snapshot.render_patch_cells == old_bytes and old_snapshot.render_patch_rectangles == old_rectangles
		and old_snapshot.render_world_generation + 1 == worker._world_generation,
		"World replacement mutated a previously published immutable generation")

func _fault_packet(kind: String, serial: int) -> Dictionary:
	match kind:
		"malformed":
			return _packet(serial, 2, true, PackedInt32Array([0, 0, 1, 1, 0, 2]), 2)
		"dirty":
			return _dirty(serial)
	var empty: Dictionary = _packet(0, 2, false, PackedInt32Array(), 0)
	empty.status = 0 if kind == "no_changes" else 2
	return empty

func _test_recovery_survives_covering_ack() -> void:
	for kind: String in ["malformed", "no_changes", "backpressure", "dirty"]:
		var worker = ObservedWorker.new()
		var source := PacketFaultWorld.new(worker._world)
		worker._world = source
		worker._publish_snapshot(0.0, true, 0, true)
		var old: CyberSimulationSnapshot = worker._published_snapshot
		var old_bytes: PackedByteArray = old.render_patch_cells.duplicate()
		var old_metadata: PackedInt32Array = old.render_patch_rectangles.duplicate()
		source.native.emit_disc(410, 250, 0, CyberCellWorld.WATER)
		source.response = _fault_packet("malformed", old.render_snapshot_serial + 1)
		source.inject = true
		worker._publish_snapshot(0.0, true, 0)
		_expect(worker._pending_render_recovery_required and worker._snapshot_world_revision == old.world_revision,
			kind + ": rejected dirty/full recovery falsely advanced rendered revision")
		# A real consumer may now finish uploading the old accepted packet. Its
		# covering ACK can release those bytes, but cannot repair rejected edits.
		worker.acknowledge_render_snapshot(old.render_snapshot_serial)
		source.response = _fault_packet(kind, old.render_snapshot_serial + 1)
		var forced_before: int = source.forced_calls
		worker._publish_snapshot(0.0, true, 0)
		_expect(worker._pending_render_recovery_required and _count(worker, "ack_clear") == 1,
			kind + ": covering old-pixel ACK disarmed required full recovery")
		_expect(worker._published_snapshot.world_revision == old.world_revision
			and worker._published_snapshot.render_snapshot_serial == old.render_snapshot_serial
			and worker._published_snapshot.render_world_generation == old.render_world_generation,
			kind + ": unsuccessful forced response certified newer pixels or generation")
		_expect(source.forced_calls == forced_before + 2,
			kind + ": primary forced request and bounded retry did not both execute")
		# The same monotonic ACK is observed again on the following owner pass.
		worker._publish_snapshot(0.0, true, 0)
		_expect(worker._pending_render_recovery_required
			and worker._published_snapshot.world_revision == old.world_revision,
			kind + ": repeated covering ACK/no-full response lost recovery")
		source.inject = false
		var calls_before: int = source.calls
		worker._publish_snapshot(0.0, true, 0)
		_expect(source.calls == calls_before + 1 and not worker._pending_render_recovery_required
			and worker._has_qualified_render_baseline()
			and worker._published_snapshot.world_revision == int(source.native.revision)
			and worker._published_snapshot.render_snapshot_serial > old.render_snapshot_serial,
			kind + ": ordinary subsequent valid full did not recover")
		var fresh: Dictionary = source.native.take_render_snapshot(true)
		_expect(worker._published_snapshot.render_patch_cells == fresh.cells
			and old.render_patch_cells == old_bytes and old.render_patch_rectangles == old_metadata,
			kind + ": recovered native bytes differ or older published payload mutated")

func _test_forced_response_contract() -> void:
	for trigger: String in ["initial", "explicit", "reset", "replacement", "overflow"]:
		for kind: String in ["malformed", "no_changes", "backpressure", "dirty"]:
			var label: String = trigger + "/" + kind
			var worker = ObservedWorker.new()
			var source := PacketFaultWorld.new(worker._world)
			worker._world = source
			var old: CyberSimulationSnapshot
			var old_bytes := PackedByteArray()
			if trigger != "initial":
				worker._publish_snapshot(0.0, true, 0, true)
				old = worker._published_snapshot
				old_bytes = old.render_patch_cells.duplicate()
			match trigger:
				"explicit":
					source.native.emit_disc(411, 250, 0, CyberCellWorld.WATER)
					worker.request_render_full_refresh()
				"reset":
					_expect(bool(source.native.reset_demo_world()), label + ": native reset failed")
					worker._world_generation += 1
				"replacement":
					source.native = worker._create_world()
					worker._world_generation += 1
				"overflow":
					worker._append_native_render_packet(_packet(worker._pending_render_snapshot_serial + 1,
						2, false, PackedInt32Array([0, 0, 1024, 1024, 0, 2048]), FRAME * 2))
					source.native.emit_disc(412, 250, 0, CyberCellWorld.WATER)
			if old != null and trigger != "overflow":
				worker.acknowledge_render_snapshot(old.render_snapshot_serial)
			var expected_serial: int = worker._pending_render_snapshot_serial
			var expected_revision: int = worker._snapshot_world_revision
			var expected_generation: int = worker._pending_render_world_generation
			source.inject = true
			source.forced_only = true
			source.response = _fault_packet(kind, expected_serial + 1)
			worker._publish_snapshot(0.0, true, 0)
			_expect(source.injected_calls > 0 and worker._pending_render_recovery_required,
				label + ": forced request accepted a response without a complete full frame")
			_expect(worker._published_snapshot.world_revision == expected_revision
				and worker._published_snapshot.render_world_generation == expected_generation
				and worker._published_snapshot.render_snapshot_serial == expected_serial,
				label + ": failed full response certified revision/generation/serial")
			source.inject = false
			var forced_before: int = source.forced_calls
			worker._publish_snapshot(0.0, true, 0)
			_expect(source.forced_calls == forced_before + 1 and worker._has_qualified_render_baseline()
				and not worker._pending_render_recovery_required
				and worker._published_snapshot.world_revision == int(source.native.revision)
				and worker._published_snapshot.render_world_generation == worker._world_generation,
				label + ": later ordinary full response failed to recover")
			if old != null:
				_expect(old.render_patch_cells == old_bytes,
					label + ": full recovery changed an older immutable publication")
