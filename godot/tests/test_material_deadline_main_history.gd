extends SceneTree

## Actual Main CPU/GPU history and ACK transactions, using the production
## worker's cumulative journal. Scheduling clocks are synthetic; GPU reads
## are actual first reads. This is correctness, not a physical/timing benchmark.
const Main = preload("res://scripts/main.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const EXTENT := Vector2i(33, 19)
const PATCHES := [
	[1, 2, 5, 3, 4, 81],
	[3, 3, 6, 4, 9, 77],
	[0, 0, 2, 19, 12, 63],
	[4, 4, 3, 2, 18, 42],
	[20, 10, 4, 4, 19, 33],
]
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var transactions: Array[Dictionary] = []
var rates: Array[Dictionary] = []
var output: String = ""

class AckProbe extends "res://scripts/simulation_worker.gd":
	var serials: Array[int] = []
	func acknowledge_render_snapshot(serial: int) -> void:
		serials.append(serial)
		super.acknowledge_render_snapshot(serial)


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="): output = argument.trim_prefix("--receipt=")
	_run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("MATERIAL_DEADLINE_MAIN: " + detail)


func _plane(material: int, condition: int, size: Vector2i = EXTENT) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y * 2)
	for i: int in range(0, bytes.size(), 2):
		bytes[i] = material
		bytes[i + 1] = condition
	return bytes


func _expected(base: PackedByteArray, count: int) -> PackedByteArray:
	var bytes := base.duplicate()
	for index: int in range(count):
		var patch: Array = PATCHES[index]
		for y: int in range(patch[1], patch[1] + patch[3]):
			for x: int in range(patch[0], patch[0] + patch[2]):
				bytes[(y * EXTENT.x + x) * 2] = patch[4]
				bytes[(y * EXTENT.x + x) * 2 + 1] = patch[5]
	return bytes


func _packet(worker: AckProbe, serial: int, generation: int,
		patch_index: int = -1, material: int = 3, condition: int = 137) -> CyberSimulationSnapshot:
	var full: bool = patch_index < 0
	var rect: Array = [0, 0, EXTENT.x, EXTENT.y, material, condition] if full else PATCHES[patch_index]
	var bytes: PackedByteArray = _plane(rect[4], rect[5], Vector2i(rect[2], rect[3]))
	worker._append_native_render_packet({"serial":serial, "channels":2, "full_refresh":full,
		"rectangles":PackedInt32Array([rect[0], rect[1], rect[2], rect[3], 0, rect[2] * 2]), "cells":bytes})
	worker._refresh_published_render_payload()
	var result := CyberSimulationSnapshot.new()
	result.serial = serial
	result.physics_world_generation = generation
	result.render_world_generation = generation
	result.world_revision = serial
	result.render_tick_index = serial
	result.render_snapshot_serial = worker._pending_render_snapshot_serial
	result.render_channels = 2
	result.render_full_refresh = worker._pending_render_full_refresh
	result.render_generated_usec = Time.get_ticks_usec()
	result.render_patch_rectangles = worker._published_render_patch_rectangles
	result.render_patch_cells = worker._published_render_patch_cells
	worker._published_snapshot = result
	return result


func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _transaction(host: Control, worker: AckProbe, hz: int, label: String) -> void:
	# These are observed transaction facts, independently reduced outside Godot.
	# No extra GPU read is introduced into the eight first-read history checks.
	transactions.append({"hz":hz, "label":label, "acks":worker.serials.duplicate(),
		"cpu_current_sha256":_hash(host.image.get_data()),
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation,
		"status":host.material_deadline_status(),
		"actual_rapier_steps":host.rapier_bridge.manual_step_count()})


func _histories(host: Control, current: PackedByteArray, previous: PackedByteArray,
		label: String, hz: int) -> void:
	var actual_current: Image = host.texture.get_image()
	var actual_previous: Image = host.previous_texture.get_image()
	var current_ok: bool = actual_current != null and actual_current.get_size() == EXTENT \
		and actual_current.get_format() == Image.FORMAT_RG8 and actual_current.get_data() == current
	var previous_ok: bool = actual_previous != null and actual_previous.get_size() == EXTENT \
		and actual_previous.get_format() == Image.FORMAT_RG8 and actual_previous.get_data() == previous
	check(current_ok, label + " exact first GPU current")
	check(previous_ok, label + " exact first GPU previous")
	observations.append({"hz":hz, "label":label,
		"current_verified":current_ok, "previous_verified":previous_ok,
		"current_sha256":_hash(actual_current.get_data()) if actual_current != null else "",
		"previous_sha256":_hash(actual_previous.get_data()) if actual_previous != null else "",
		"expected_current_sha256":_hash(current), "expected_previous_sha256":_hash(previous),
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation})


func _rate(hz: int) -> void:
	var host = Main.new()
	var worker := AckProbe.new()
	host.simulation_worker = worker
	host.shared_workbench = Control.new()
	host.world_extent = EXTENT
	host.render_channels = 2
	host.render_image_format = Image.FORMAT_RG8
	host.image = Image.create(EXTENT.x, EXTENT.y, false, Image.FORMAT_RG8)
	host.cadence_lod_enabled = true
	host.create_render_textures()
	worker._workbench_extent = EXTENT
	check(host._material_deadline.configure(hz), "registered Main deadline configuration")
	var interval: int = host.material_deadline_status().interval_usec
	var baseline: PackedByteArray = _plane(3, 137)
	var first := _packet(worker, 20, 42)
	host.latest_snapshot = first
	host._offer_material_snapshot(first, 100000)
	host._drain_material_deadline(100000)
	_histories(host, baseline, _plane(0, 0), "initial20", hz)
	_transaction(host, worker, hz, "initial20")
	check(worker.serials == [20] and worker._acknowledged_render_snapshot_serial == 20,
		"initial accepted upload issues real worker ACK20")
	# The owner observes ACK20 before its next native exchange, matching the
	# production journal retirement condition. Later ACK24 is deliberately
	# not observed before native delta25 is appended.
	worker._clear_pending_render_patches()
	var second := _packet(worker, 21, 42, 0)
	host.latest_snapshot = second
	host._offer_material_snapshot(second, 100001)
	host._drain_material_deadline(100001)
	_transaction(host, worker, hz, "deferred21")
	check(host.image.get_data() == baseline and worker.serials == [20],
		"deferred21 mutates no visible CPU plane and gives no ACK")
	var third := _packet(worker, 22, 42, 1)
	host.latest_snapshot = third
	host._offer_material_snapshot(third, 100002)
	_transaction(host, worker, hz, "replaced22")
	var fourth := _packet(worker, 24, 42, 2)
	host.latest_snapshot = fourth
	host._offer_material_snapshot(fourth, 100000 + interval - 1)
	host._drain_material_deadline(100000 + interval - 1)
	_transaction(host, worker, hz, "before_deadline24")
	check(host.image.get_data() == baseline and worker.serials == [20],
		"latest cumulative24 remains deferred until fixed first deadline")
	check(host.material_deadline_status().deadline_usec == 100000 + interval \
		and host.material_deadline_status().pending_count == 1, "one fixed-deadline pending packet")
	check(second.render_patch_rectangles.size() == 6 and second.render_patch_cells == _plane(4, 81, Vector2i(5, 3)),
		"earlier published journal bytes remain immutable while later deltas append")
	# No new mailbox publication or offer occurs at this boundary.
	host._drain_material_deadline(100000 + interval)
	var plane24: PackedByteArray = _expected(baseline, 3)
	_histories(host, plane24, baseline, "coalesced24", hz)
	_transaction(host, worker, hz, "coalesced24")
	check(worker.serials == [20, 24], "skipped21/22 receive no ACK")
	var timing: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec())
	check(timing.current.serial == 24 and timing.previous.serial == 20,
		"timeline records actual uploaded20 to24")
	var fifth := _packet(worker, 25, 42, 3)
	host.latest_snapshot = fifth
	host._offer_material_snapshot(fifth, 100001 + interval)
	_transaction(host, worker, hz, "pending25")
	check(fifth.render_patch_rectangles.size() == 24, "unobserved ACK24 preserves accumulated21/22/24/25 patches")
	host._drain_material_deadline(100000 + 2 * interval)
	var plane25: PackedByteArray = _expected(baseline, 4)
	_histories(host, plane25, plane24, "delayed_ack25", hz)
	_transaction(host, worker, hz, "delayed_ack25")
	check(worker.serials == [20, 24, 25], "replayed accumulated prefix issues only actual ACK25")

	var pending := _packet(worker, 26, 42, 4)
	host.latest_snapshot = pending
	host._offer_material_snapshot(pending, 100001 + 2 * interval)
	_transaction(host, worker, hz, "pending26")
	var replacement := _packet(worker, 30, 43, -1, 6, 120)
	host.latest_snapshot = replacement
	host._offer_material_snapshot(replacement, 100002 + 2 * interval)
	host._drain_material_deadline(100002 + 2 * interval)
	_histories(host, _plane(6, 120), plane25, "same_size_world30", hz)
	_transaction(host, worker, hz, "same_size_world30")
	timing = host.material_presentation_timeline.frame(Time.get_ticks_usec())
	check(timing.current.generation == 43 and timing.previous.is_empty() and not timing.previous_blend_active,
		"same-size new World gives previous World no blend authority")
	check(worker.serials == [20, 24, 25, 30], "replacement bypasses delay without acknowledging old pending26")
	var teardown := _packet(worker, 31, 43, 0)
	host.latest_snapshot = teardown
	host._offer_material_snapshot(teardown, 100003 + 2 * interval)
	_transaction(host, worker, hz, "pending31")
	host._close_physical_actors()
	host._drain_material_deadline(999999)
	_transaction(host, worker, hz, "closed")
	check(worker.serials == [20, 24, 25, 30] and host.material_deadline_status().pending_count == 0,
		"physical-owner close cancels retained offer before deadline drain")
	check(host.rapier_bridge.manual_step_count() == 0, "material scheduling invents no actual Rapier step")
	rates.append({"hz":hz, "acks":worker.serials.duplicate(),
		"status":host.material_deadline_status(), "actual_rapier_steps":host.rapier_bridge.manual_step_count(),
		"full_image_slots":host.material_publication_status().full_image_slots})
	host.shared_workbench.free()
	host.shared_workbench = null
	host.free()


func _run() -> void:
	check(DisplayServer.get_name() != "headless", "graphical backend required")
	check(OS.get_environment("CYBERSAND_MATERIAL_PUBLICATION") == "full", "explicit Full material selection")
	if failures.is_empty():
		for hz: int in [30, 60]: _rate(hz)
	var result := {"schema":"pubpres-material-deadline-main-history-v1", "checks":checks,
		"complete":failures.is_empty(), "failures":failures, "observations":observations, "rates":rates,
		"transactions":transactions,
		"synthetic_scheduling_clocks":true, "performance_claim":false,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"), "pid":OS.get_process_id(),
		"context":Context.identity(get_script().resource_path),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"worker_sha256":FileAccess.get_sha256("res://scripts/simulation_worker.gd"),
		"policy_sha256":FileAccess.get_sha256("res://scripts/material_publication_deadline.gd"),
		"publisher_sha256":FileAccess.get_sha256("res://scripts/full_image_ring_publisher.gd"),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"render_thread_inline":RenderingServer.is_on_render_thread()}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			check(false, "cannot write receipt")
		else:
			file.store_string(JSON.stringify(result) + "\n")
			file.close()
	print("MATERIAL_DEADLINE_MAIN_RESULT ", JSON.stringify(result))
	quit(int(not failures.is_empty()))
