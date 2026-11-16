extends SceneTree

const Journal = preload("res://scripts/render_pending_journal.gd")
const Worker = preload("res://scripts/simulation_worker.gd")

class NativeOwner extends CyberSimulationWorker:
	var source_packets: Array[Dictionary] = []
	var full_requests: int = 0
	func _take_native_render_snapshot(force_full: bool) -> Dictionary:
		if force_full:
			full_requests += 1
		var packet: Dictionary = super._take_native_render_snapshot(force_full)
		if not packet.get("cells", PackedByteArray()).is_empty():
			source_packets.append(packet.duplicate(true))
		return packet

var checks: int = 0
var failures: int = 0


func _init() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_run.call_deferred()


func _run() -> void:
	for count: int in [1, 2]:
		_test_single_packet_isolation(count)
		_test_prefix_and_overlap(count)
		_test_cache_and_recovery(count)
	_test_capacity_without_full_base()
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native runtime is required")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		_test_native_owner()
		_test_fallback_owner()
	print("RENDER_PENDING_COMPACTION: %d checks, %d failures" % [checks, failures])
	quit(failures)


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("RENDER_PENDING_COMPACTION: " + message)


func _patch(region: Rect2i, count: int, value: int, full: bool = false, padding: int = 0) -> Dictionary:
	var row_stride: int = region.size.x * count + padding
	var data := PackedByteArray()
	data.resize(row_stride * region.size.y)
	for y: int in region.size.y:
		for x: int in region.size.x:
			data[y * row_stride + x * count] = value
			if count == 2:
				data[y * row_stride + x * count + 1] = (value * 7 + y) % 256
	return {"rectangles": PackedInt32Array([region.position.x, region.position.y,
		region.size.x, region.size.y, 0, row_stride]), "cells": data,
		"channels": count, "full_refresh": full}


func _apply(image: Image, packet: Dictionary) -> void:
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	var count: int = int(packet.get("channels", 2))
	for offset: int in range(0, rectangles.size(), 6):
		var region := Rect2i(rectangles[offset], rectangles[offset + 1], rectangles[offset + 2], rectangles[offset + 3])
		var data := PackedByteArray()
		for y: int in region.size.y:
			var first: int = rectangles[offset + 4] + y * rectangles[offset + 5]
			data.append_array(cells.slice(first, first + region.size.x * count))
		image.blit_rect(Image.create_from_data(region.size.x, region.size.y, false,
			Image.FORMAT_RG8 if count == 2 else Image.FORMAT_R8, data),
			Rect2i(Vector2i.ZERO, region.size), region.position)


func _test_single_packet_isolation(count: int) -> void:
	var journal := Journal.new()
	journal.configure(Vector2i(128, 128), 1)
	var packet: Dictionary = _patch(Rect2i(0, 0, 128, 128), count, 11, true)
	var original_cells: PackedByteArray = packet.cells.duplicate()
	var original_rectangles: PackedInt32Array = packet.rectangles.duplicate()
	_expect(journal.append(packet, 10), "single complete packet admitted")
	# Mutating the producer's arrays must never alter retained source authority.
	packet.cells[0] = 201
	packet.rectangles[0] = 37
	var first: Dictionary = journal.payload()
	_expect(first.cells == original_cells and first.rectangles == original_rectangles
		and first.full_refresh, "single payload isolates producer mutations")
	# The payload is a separate packed-array value, not the retained batch's
	# mutable wrapper. An older ACK rebuild must still recover the original.
	first.cells[1] = 202
	first.rectangles[1] = 23
	journal.retire(5)
	var rebuilt: Dictionary = journal.payload()
	_expect(rebuilt.cells == original_cells and rebuilt.rectangles == original_rectangles,
		"older ACK rebuild isolates consumer mutations")
	var held_cells: PackedByteArray = rebuilt.cells
	var held_rectangles: PackedInt32Array = rebuilt.rectangles
	var replacement: Dictionary = _patch(Rect2i(0, 0, 128, 128), count, 19, true)
	_expect(journal.append(replacement, 11), "next complete packet replaces pending source")
	var latest: Dictionary = journal.payload()
	_expect(latest.cells == replacement.cells and held_cells == original_cells
		and held_rectangles == original_rectangles, "later capture preserves retained publication values")
	journal.retire(11)
	_expect(journal.payload().cells.is_empty() and held_cells == original_cells,
		"latest ACK drains journal without changing retained publication")
	# One sparse packet can retain padding and nonzero offsets without repacking.
	var sparse: Dictionary = _patch(Rect2i(4, 7, 3, 2), count, 29, false, 5)
	var prefixed := PackedByteArray([90, 91, 92])
	prefixed.append_array(sparse.cells)
	sparse.cells = prefixed
	sparse.rectangles[4] = 3
	_expect(journal.append(sparse, 12), "single padded nonzero-offset packet admitted")
	var sparse_payload: Dictionary = journal.payload()
	var expected := Image.create(128, 128, false, Image.FORMAT_RG8 if count == 2 else Image.FORMAT_R8)
	var actual: Image = expected.duplicate()
	_apply(expected, sparse)
	_apply(actual, sparse_payload)
	_expect(actual.get_data() == expected.get_data() and not sparse_payload.full_refresh,
		"single sparse payload preserves exact offsets and row padding")


func _test_prefix_and_overlap(count: int) -> void:
	var journal := Journal.new()
	_expect(journal.configure(Vector2i(192, 128), 1), "bounded extent admitted")
	var first: Dictionary = _patch(Rect2i(0, 0, 192, 128), count, 1, true)
	_expect(journal.append(first, 1), "initial full admitted")
	journal.retire(1)
	var a: Dictionary = _patch(Rect2i(3, 5, 3, 2), count, 2, false, 3)
	var b: Dictionary = _patch(Rect2i(4, 5, 3, 2), count, 3)
	var c: Dictionary = _patch(Rect2i(130, 70, 1, 1), count, 4)
	for pair: Array in [[a, 2], [b, 3], [c, 4]]:
		_expect(journal.append(pair[0], int(pair[1])), "distinct source capture admitted")
	var held: Dictionary = journal.payload().duplicate(true)
	var reference := Image.create(192, 128, false, Image.FORMAT_RG8 if count == 2 else Image.FORMAT_R8)
	_apply(reference, first)
	_apply(reference, a)
	var after_two: Image = reference.duplicate()
	_apply(reference, b)
	_apply(reference, c)
	journal.retire(2)
	var pending: Dictionary = journal.payload()
	_expect(pending.rectangles.size() == 12, "older ACK retires only its prefix")
	_apply(after_two, pending)
	_expect(after_two.get_data() == reference.get_data(), "prefix retirement retains overlapping latest bytes")
	var latest: Dictionary = _patch(Rect2i(4, 5, 3, 2), count, 7)
	_expect(journal.append(latest, 5), "exact-shape latest overwrite admitted")
	_expect(journal.payload().rectangles.size() == 12, "exact-shape overwrite coalesces one batch")
	_apply(reference, latest)
	_apply(after_two, journal.payload())
	_expect(after_two.get_data() == reference.get_data(), "replacement remains after overlapping prior captures")
	_expect(held.rectangles.size() == 18 and held.cells != journal.payload().cells,
		"retained publication keeps original arrays")
	var version: int = journal.payload_version
	journal.retire(2)
	_expect(journal.payload_version == version, "repeated ACK does no payload rebuild")
	journal.retire(5)
	_expect(journal.payload().cells.is_empty(), "latest accepted ACK drains pending values")
	var bad: Dictionary = _patch(Rect2i(190, 2, 4, 1), count, 9)
	_expect(not journal.append(bad, 6) and journal.last_serial == 5,
		"out-of-bounds capture refuses without advancing accepted source")
	_expect(journal.needs_full_capture, "refusal requests explicit native resync")
	journal.retire(5)
	_expect(journal.needs_full_capture, "ACK of preceding accepted capture cannot clear refusal recovery")
	_expect(not journal.append({"status": 2}, 6) and journal.last_serial == 5,
		"backpressure cannot invent accepted bytes or a serial")
	_expect(journal.append(first, 6), "explicit complete capture recovers refusal")
	_expect(not journal.needs_full_capture, "recovery clears full request")
	var rejected := Journal.new()
	rejected.configure(Vector2i(192, 128), 1)
	rejected.append(first, 1)
	rejected.append(bad, 2)
	rejected.retire(1)
	_expect(rejected.needs_full_capture and rejected.payload().cells.is_empty(),
		"newly arriving ACK drains accepted bytes but preserves later refusal recovery")


func _test_cache_and_recovery(count: int) -> void:
	var journal := Journal.new()
	journal.configure(Vector2i(130, 129), 1)
	var source := Image.create(130, 129, false, Image.FORMAT_RG8 if count == 2 else Image.FORMAT_R8)
	var initial: Dictionary = _patch(Rect2i(0, 0, 130, 129), count, 1, true)
	journal.append(initial, 10)
	_apply(source, initial)
	var initial_bytes: PackedByteArray = journal.payload().cells.duplicate()
	for serial: int in range(11, 50):
		var packet: Dictionary = _patch(Rect2i(128, 127, 2, 2), count, serial, false, 2)
		_expect(journal.append(packet, serial), "unacknowledged sparse source remains fresh")
		_apply(source, packet)
		var current: Dictionary = journal.payload()
		_expect(current.cells == source.get_data() and current.full_refresh,
			"missing-ACK cached full bytes equal every native state")
		_expect(not journal.needs_full_capture, "complete cache never requests repeated native full")
	_expect(journal.statistics().cache_activations == 1, "one bounded cache activated")
	_expect(journal.statistics().cache_bytes == 130 * 129 * count, "cache allocation bounded to canvas")
	_expect(initial_bytes == initial.cells, "old full publication bytes remain immutable")
	journal.retire(10)
	var sparse: Dictionary = journal.payload()
	_expect(not sparse.full_refresh and sparse.cells.size() < source.get_data().size(),
		"older accepted full ACK restores sparse publication without waiting for latest")
	var receiver := Image.create_from_data(130, 129, false,
		Image.FORMAT_RG8 if count == 2 else Image.FORMAT_R8, initial_bytes)
	_apply(receiver, sparse)
	_expect(receiver.get_data() == source.get_data(), "tile repair includes boundary/padded exact bytes")
	journal.retire(49)
	_expect(journal.statistics().cache_bytes == 0 and journal.payload().cells.is_empty(),
		"latest ACK releases complete cache and journal")
	var old_generation: int = journal.generation
	journal.configure(Vector2i(130, 129), 2)
	_expect(journal.generation == old_generation + 1 and journal.payload().cells.is_empty(),
		"World replacement cannot retain stale material values")
	var replacement: Dictionary = _patch(Rect2i(0, 0, 130, 129), count, 5, true)
	_expect(journal.append(replacement, 50), "new World uses monotonic desktop serial")
	_expect(journal.payload().cells == replacement.cells, "new World replacement exact")
	_expect(not journal.configure(Vector2i(2049, 129), 3), "oversized cache refuses explicitly")


func _test_capacity_without_full_base() -> void:
	var journal := Journal.new()
	journal.configure(Vector2i(512, 512), 1)
	var full: Dictionary = _patch(Rect2i(0, 0, 512, 512), 2, 1, true)
	journal.append(full, 1)
	journal.retire(1)
	var source := Image.create_from_data(512, 512, false, Image.FORMAT_RG8, full.cells)
	for index: int in 257:
		var packet: Dictionary = _patch(Rect2i(index % 128, index / 128, 1, 1), 2, index % 200)
		journal.append(packet, index + 2)
		_apply(source, packet)
	_expect(journal.needs_full_capture and journal.statistics().full_capture_requests == 1,
		"a genuinely over-capacity sparse journal requests one complete source baseline")
	var baseline: Dictionary = {"rectangles": full.rectangles, "cells": source.get_data(),
		"channels": 2, "full_refresh": true}
	journal.append(baseline, 259)
	_expect(not journal.needs_full_capture and journal.statistics().cache_activations == 1,
		"capacity recovery enters bounded latest-state cache")
	for serial: int in range(260, 300):
		var packet: Dictionary = _patch(Rect2i(serial - 260, 100, 1, 1), 2, serial % 200)
		journal.append(packet, serial)
		_apply(source, packet)
	_expect(journal.payload().cells == source.get_data(), "cache preserves all post-recovery states")
	_expect(journal.statistics().full_capture_requests == 1, "missing ACK causes no native refresh storm")
	journal.retire(259)
	var receiver := Image.create_from_data(512, 512, false, Image.FORMAT_RG8, baseline.cells)
	_apply(receiver, journal.payload())
	_expect(receiver.get_data() == source.get_data() and not journal.payload().full_refresh,
		"delayed ACK immediately narrows recovery payload")


func _snapshot_packet(snapshot: CyberSimulationSnapshot) -> Dictionary:
	return {"rectangles": snapshot.render_patch_rectangles, "cells": snapshot.render_patch_cells,
		"channels": snapshot.render_channels, "full_refresh": snapshot.render_full_refresh}


func _test_native_owner() -> void:
	var outcomes: Array[Dictionary] = []
	for compact: bool in [false, true]:
		var worker := NativeOwner.new()
		worker._workbench_extent = Vector2i(1024, 1024)
		worker.set_render_pending_compaction_enabled(compact)
		worker._publish_snapshot(0.0, true, 0, true)
		var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		var initial_bytes: PackedByteArray = initial.render_patch_cells.duplicate()
		var source := Image.create(1024, 1024, false, Image.FORMAT_RG8)
		_apply(source, _snapshot_packet(initial))
		var receiver: Image = source.duplicate()
		worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
		var consumed: int = worker.source_packets.size()
		var delayed: CyberSimulationSnapshot
		var delayed_image: Image
		var latest: CyberSimulationSnapshot = initial
		for index: int in 320:
			var previous_render_serial: int = latest.render_snapshot_serial
			worker._world.emit_disc(100 + (index % 30) * 20, 100 + (index / 30) * 20,
				0, CyberCellWorld.WALL if index % 2 == 0 else CyberCellWorld.STONE)
			worker._publish_snapshot(0.0, true, 0)
			latest = worker.take_latest_snapshot(-1)
			_expect(latest.render_snapshot_serial > previous_render_serial,
				"each changed source capture advances immediately despite missing ACK")
			for packet_index: int in range(consumed, worker.source_packets.size()):
				_apply(source, worker.source_packets[packet_index])
			consumed = worker.source_packets.size()
			_apply(receiver, _snapshot_packet(latest))
			if index % 20 == 0 or index == 319:
				_expect(receiver.get_data() == source.get_data(),
					"every sampled native/CPU material state agrees, compact=%s index=%d" % [compact, index])
			_expect(latest.render_world_generation == initial.render_world_generation,
				"unacknowledged transport never changes World generation")
			_expect(latest.hard_surface_revision == int(worker._world.hard_surface_revision),
				"collider invalidation remains current without graphical ACK")
			if index == 290:
				delayed = latest
				delayed_image = source.duplicate()
		_expect(initial.render_patch_cells == initial_bytes, "native retained initial snapshot immutable")
		var fulls_before_recovery: int = worker.full_requests
		worker.acknowledge_render_snapshot(delayed.render_snapshot_serial)
		worker._publish_snapshot(0.0, true, 0)
		var older_ack: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		_apply(delayed_image, _snapshot_packet(older_ack))
		_expect(delayed_image.get_data() == source.get_data(), "older-ACK recovery preserves exact latest source")
		if compact:
			_expect(not older_ack.render_full_refresh, "older native ACK makes outstanding cache sparse")
			_expect(fulls_before_recovery == 2, "320 missing ACK edits need initial full and one bounded recovery only")
			_expect(latest.lab_context.render_pending.cache_activations == 1, "actual worker activated one cache")
			_expect(latest.lab_context.render_pending.captures == 322,
				"initial plus all 320 edits and one recovery captured; none gated or skipped")
		else:
			_expect(fulls_before_recovery > 20, "baseline reproduces repeated full-refresh amplification")
		worker.acknowledge_render_snapshot(latest.render_snapshot_serial)
		worker._publish_snapshot(0.0, true, 0)
		_expect(worker.take_latest_snapshot(-1).render_patch_cells.is_empty(), "latest ACK drains actual pending packet")
		worker.request_render_full_refresh()
		worker._publish_snapshot(0.0, true, 0)
		var resync: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		_expect(resync.render_full_refresh and resync.render_snapshot_serial > latest.render_snapshot_serial,
			"explicit full refresh remains honored")
		worker._world_generation += 1
		worker._world.reset_demo_world()
		worker._publish_snapshot(0.0, true, 0)
		var replacement: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		_expect(replacement.render_world_generation == initial.render_world_generation + 1 and replacement.render_full_refresh
			and replacement.render_snapshot_serial > resync.render_snapshot_serial,
			"actual new World replaces cache and keeps desktop serial monotonic")
		outcomes.append({"compact": compact, "native_fulls_before_recovery": fulls_before_recovery,
			"latest_capture": latest.render_snapshot_serial, "source_hash": source.get_data().hex_encode().sha256_text(),
			"diagnostics": latest.lab_context.get("render_pending", {})})
	_expect(outcomes[0].source_hash == outcomes[1].source_hash, "baseline/candidate exact native material authority equal")
	print("RENDER_PENDING_NATIVE ", JSON.stringify(outcomes))


func _test_fallback_owner() -> void:
	var worker := Worker.new()
	worker._world = CyberCellWorld.new()
	worker.set_render_pending_compaction_enabled(true)
	worker._publish_snapshot(0.0, true, 0, true)
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	_expect(initial.render_channels == 1 and initial.render_full_refresh, "R8 fallback full publication preserved")
	_expect(not worker._render_pending_compaction_active, "R8 compatibility owner keeps original whole-image transport")
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	worker._world.emit_disc(500, 200, 0, CyberCellWorld.STONE)
	worker._publish_snapshot(0.0, true, 0)
	var painted: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	_expect(painted.render_channels == 1 and painted.render_full_refresh and
		painted.render_snapshot_serial > initial.render_snapshot_serial, "R8 native-independent paint remains fresh")
