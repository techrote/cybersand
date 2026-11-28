extends SceneTree

## Actual production Main/worker/image/ACK transactions. Only the read-only
## completion witness is overridden with declared synthetic counter inputs;
## no native or Rapier step occurs. This fixture cannot qualify playability.
const Context = preload("res://tests/palette_qualification_context.gd")
const EXTENT := Vector2i(33, 19)
const PATCHES := [
	[1, 2, 5, 3, 4, 81], [3, 3, 6, 4, 9, 77], [0, 0, 2, 19, 12, 63],
	[4, 4, 3, 2, 18, 42], [20, 10, 4, 4, 19, 33],
]
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var transactions: Array[Dictionary] = []
var output: String = ""
var generated_usec: int = 0

class FixtureMain extends "res://scripts/main.gd":
	var fixture_witness: Dictionary = {}
	func _material_step_completed_witness(_identity: Array) -> Dictionary:
		return fixture_witness.duplicate()

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
		push_error("MATERIAL_STEPS_MAIN: " + detail)


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
	worker._append_native_render_packet({"serial":serial, "channels":2, "full_refresh":full,
		"rectangles":PackedInt32Array([rect[0], rect[1], rect[2], rect[3], 0, rect[2] * 2]),
		"cells":_plane(rect[4], rect[5], Vector2i(rect[2], rect[3]))})
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
	# A real past source clock keeps the unchanged material timeline valid;
	# scheduling offsets below are explicitly synthetic, independent inputs.
	result.render_generated_usec = generated_usec
	result.render_patch_rectangles = worker._published_render_patch_rectangles
	result.render_patch_cells = worker._published_render_patch_cells
	worker._published_snapshot = result
	return result


func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _transaction(host: FixtureMain, worker: AckProbe, label: String) -> void:
	transactions.append({"label":label, "acks":worker.serials.duplicate(),
		"cpu_current_sha256":_hash(host.image.get_data()),
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation,
		"status":host.material_step_status(), "synthetic_witness":host.fixture_witness.duplicate(),
		"actual_rapier_steps":host.rapier_bridge.manual_step_count()})


func _histories(host: FixtureMain, current: PackedByteArray, previous: PackedByteArray, label: String) -> void:
	var actual_current: Image = host.texture.get_image()
	var actual_previous: Image = host.previous_texture.get_image()
	var current_ok: bool = actual_current != null and actual_current.get_size() == EXTENT \
		and actual_current.get_format() == Image.FORMAT_RG8 and actual_current.get_data() == current
	var previous_ok: bool = actual_previous != null and actual_previous.get_size() == EXTENT \
		and actual_previous.get_format() == Image.FORMAT_RG8 and actual_previous.get_data() == previous
	check(current_ok, label + " exact first GPU current")
	check(previous_ok, label + " exact first GPU previous")
	observations.append({"label":label, "current_verified":current_ok, "previous_verified":previous_ok,
		"current_sha256":_hash(actual_current.get_data()) if actual_current != null else "",
		"previous_sha256":_hash(actual_previous.get_data()) if actual_previous != null else "",
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation})


func _body() -> void:
	var host := FixtureMain.new()
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
	check(host._material_steps.configure(2) and not host._material_deadline.enabled(), "count-only explicit fixture policy")
	generated_usec = Time.get_ticks_usec()
	var now: int = generated_usec + 1
	host.fixture_witness = {"session_step":10, "rapier_step":110, "completed_usec":generated_usec}
	var baseline: PackedByteArray = _plane(3, 137)
	var first := _packet(worker, 20, 42)
	host.latest_snapshot = first
	host._offer_material_snapshot(first, now)
	host._drain_material_steps(now)
	_histories(host, baseline, _plane(0, 0), "initial20")
	_transaction(host, worker, "initial20")
	check(worker.serials == [20], "initial material has exactly one actual ACK")
	worker._clear_pending_render_patches()
	host.fixture_witness.session_step = 11
	host.fixture_witness.rapier_step = 111
	var second := _packet(worker, 21, 42, 0)
	host.latest_snapshot = second
	host._offer_material_snapshot(second, now + 1)
	host._drain_material_steps(now + 1)
	_transaction(host, worker, "deferred21")
	check(host.image.get_data() == baseline and worker.serials == [20], "held21 mutates neither CPU material nor ACK")
	var third := _packet(worker, 22, 42, 1)
	host.latest_snapshot = third
	host._offer_material_snapshot(third, now + 2)
	_transaction(host, worker, "replaced22")
	var fourth := _packet(worker, 24, 42, 2)
	host.latest_snapshot = fourth
	host._offer_material_snapshot(fourth, now + 3)
	host._drain_material_steps(now + 3)
	_transaction(host, worker, "held24")
	check(host.material_step_status().pending_count == 1 \
		and host.material_step_status().deadline_usec == now + 1 + 16667,
		"replacement preserves one pending packet and first deadline")
	check(second.render_patch_rectangles.size() == 6 \
		and second.render_patch_cells == _plane(4, 81, Vector2i(5, 3)), "old offered bytes remain immutable")
	host.fixture_witness.session_step = 12
	host.fixture_witness.rapier_step = 112
	host._drain_material_steps(now + 4)
	var plane24: PackedByteArray = _expected(baseline, 3)
	_histories(host, plane24, baseline, "coalesced24")
	_transaction(host, worker, "coalesced24")
	check(worker.serials == [20, 24], "replaced21 and22 receive no ACK")
	var timing: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec())
	check(timing.current.serial == 24 and timing.previous.serial == 20,
		"material timeline follows actual accepted20 to24 packets")
	# ACK24 remains unobserved by the owner; the next packet must replay the
	# accumulated prefix and still produce previous24/current25 exactly.
	var fifth := _packet(worker, 25, 42, 3)
	host.latest_snapshot = fifth
	host._offer_material_snapshot(fifth, now + 5)
	_transaction(host, worker, "pending25")
	check(fifth.render_patch_rectangles.size() == 24, "unobserved ACK24 retains21/22/24/25 journal")
	var expired: int = now + 5 + 16667 + 1000
	host._drain_material_steps(expired)
	var plane25: PackedByteArray = _expected(baseline, 4)
	_histories(host, plane25, plane24, "expired25")
	_transaction(host, worker, "expired25")
	check(host.material_step_status().last_deadline_overrun_usec == 1000 \
		and host.material_step_status().anchor_session_step == 12, "late drain exposes overrun without new completion credit")

	var pending := _packet(worker, 26, 42, 4)
	host.latest_snapshot = pending
	host._offer_material_snapshot(pending, expired + 1)
	_transaction(host, worker, "pending26")
	var replacement := _packet(worker, 30, 43, -1, 6, 120)
	host.latest_snapshot = replacement
	host._offer_material_snapshot(replacement, expired + 2)
	host._drain_material_steps(expired + 2)
	_histories(host, _plane(6, 120), plane25, "same_size_world30")
	_transaction(host, worker, "same_size_world30")
	timing = host.material_presentation_timeline.frame(Time.get_ticks_usec())
	check(timing.current.generation == 43 and timing.previous.is_empty() \
		and not timing.previous_blend_active, "new World clears old-World blend authority")
	var teardown := _packet(worker, 31, 43, 0)
	host.latest_snapshot = teardown
	host._offer_material_snapshot(teardown, expired + 3)
	_transaction(host, worker, "pending31")
	host._close_physical_actors()
	host._drain_material_steps(expired + 4)
	_transaction(host, worker, "closed")
	check(worker.serials == [20, 24, 25, 30] and host.material_step_status().pending_count == 0,
		"physical owner close retires pending31 without ACK")

	var recovered := _packet(worker, 33, 43, -1, 8, 103)
	host.latest_snapshot = recovered
	host._offer_material_snapshot(recovered, expired + 5)
	host._drain_material_steps(expired + 5)
	_histories(host, _plane(8, 103), _plane(6, 120), "recovered33")
	_transaction(host, worker, "recovered33")
	host.paused = true
	var paused_packet := _packet(worker, 34, 43, -1, 9, 101)
	host.latest_snapshot = paused_packet
	host._offer_material_snapshot(paused_packet, expired + 6)
	host._drain_material_steps(expired + 6)
	_histories(host, _plane(9, 101), _plane(8, 103), "paused34")
	_transaction(host, worker, "paused34")
	check(host.material_step_status().last_consumption_reason == "paused", "paused packet bypasses count gate")
	host.paused = false
	host.fixture_witness.clear()
	var no_owner := _packet(worker, 35, 43, -1, 10, 99)
	host.latest_snapshot = no_owner
	host._offer_material_snapshot(no_owner, expired + 7)
	host._drain_material_steps(expired + 7)
	_histories(host, _plane(10, 99), _plane(9, 101), "no_owner35")
	_transaction(host, worker, "no_owner35")
	check(host.material_step_status().anchor_session_step == -1 \
		and host.material_step_status().last_consumption_reason == "no_compatible_completed_step",
		"absent physical owner preserves immediate material progress without a step anchor")
	check(worker.serials == [20, 24, 25, 30, 33, 34, 35], "only seven actual upload transactions are acknowledged")
	check(host.rapier_bridge.manual_step_count() == 0, "fixture made zero actual Rapier steps")
	host.shared_workbench.free()
	host.shared_workbench = null
	host.free()


func _run() -> void:
	check(DisplayServer.get_name() != "headless", "graphical backend required")
	check(OS.get_environment("CYBERSAND_MATERIAL_PUBLICATION") == "full", "explicit Full material selection")
	check(OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") in ["", "2"], "two-slot publisher required")
	if failures.is_empty(): _body()
	var result := {"schema":"pubpres-material-steps-main-history-v1", "checks":checks,
		"complete":failures.is_empty(), "failures":failures, "observations":observations,
		"transactions":transactions, "synthetic_scheduling_clocks_and_completion_witness":true,
		"actual_rapier_steps":0, "performance_claim":false, "physical_credit":false,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"), "pid":OS.get_process_id(),
		"context":Context.identity(get_script().resource_path),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"worker_sha256":FileAccess.get_sha256("res://scripts/simulation_worker.gd"),
		"policy_sha256":FileAccess.get_sha256("res://scripts/material_publication_steps.gd"),
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
	print("MATERIAL_STEPS_MAIN_RESULT ", JSON.stringify(result))
	quit(int(not failures.is_empty()))
