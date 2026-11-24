extends SceneTree

## Real Main/worker/owner methods with copied identity fields. No configured
## body, native World execution, GPU upload or completed Rapier step exists.
const Main = preload("res://scripts/main.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Bridge = preload("res://scripts/workbench_physics_bridge.gd")
var checks: int = 0
var failures: Array[String] = []
var cancelled_cases: Array[String] = []

class AckProbe extends "res://scripts/simulation_worker.gd":
	var serials: Array[int] = []
	func acknowledge_render_snapshot(serial: int) -> void:
		serials.append(serial)
		super.acknowledge_render_snapshot(serial)


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("MATERIAL_STEPS_IDENTITY: " + detail)


func _packet() -> CyberSimulationSnapshot:
	var result := CyberSimulationSnapshot.new()
	result.rigid_body_epoch = 11
	result.physics_world_generation = 42
	result.render_world_generation = 42
	result.render_snapshot_serial = 20
	result.render_full_refresh = true
	result.render_generated_usec = 99999
	result.render_context = {"workbench_display":{"session":7, "epoch":11, "world_generation":42}}
	return result


func _arm(host: Control, worker: AckProbe) -> void:
	var snapshot := _packet()
	host.latest_snapshot = snapshot
	worker._published_snapshot = snapshot
	host._offer_material_snapshot(snapshot, 100000)
	check(host.material_step_status().pending_count == 1, "matching owner retains one pre-mutation offer")


func _cancelled(host: Control, worker: AckProbe, reason: String) -> void:
	host._drain_material_steps(999999)
	var state: Dictionary = host.material_step_status()
	check(state.pending_count == 0 and state.consumptions == 0 and state.accepted_uploads == 0 \
		and worker.serials.is_empty() and host.last_uploaded_render_snapshot_serial == 19,
		reason + " retires pending material before upload or ACK")
	cancelled_cases.append(reason)


func _paint_admission(host: Control, worker: AckProbe) -> void:
	# These are accepted command values in the actual queue API, not completed
	# edits. The fixture clears the queue without executing native material work
	# to model a fast command already idle when the first Main sample occurs.
	worker._workbench_extent = Vector2i(33, 19)
	host.world_extent = worker._workbench_extent
	var unchanged_hard_revision: int = host.last_hard_surface_revision
	for path: String in ["disc_compatibility", "disc_footprint", "cell_footprint"]:
		host._material_steps.cancel("paint_case")
		var admitted: bool = false
		if path == "disc_compatibility":
			admitted = host.queue_brush_mutation(5, 5, 1, CyberCellWorld.SAND)
		else:
			host.brush_shape = "circle" if path == "disc_footprint" else "square"
			host.brush_size_px = 3
			admitted = host.queue_brush_footprint_mutation(5, 5, CyberCellWorld.SAND)
		check(admitted and host.material_step_status().paint_force,
			path + " successful soft Sand admission forces presentation")
		worker._pending_emissions.clear()
		worker._pending_cell_emissions.clear()
		worker._legacy_edit_inflight = false
		var state: Dictionary = worker.paint_state()
		check(not state.legacy_busy and not state.busy and not state.art_busy,
			path + " is already idle at first Main observation")
		host._material_steps.observe_paint_busy(false, 100001)
		check(host.material_step_status().paint_force and host.material_step_status().paint_idle_usec == 100001 \
			and host.last_hard_surface_revision == unchanged_hard_revision,
			path + " cannot lose fast soft paint through missed busy samples or unchanged hard revision")
		worker._paint_busy = true
		var count_before: int = host.material_step_status().edit_requests
		var refused: bool = host.queue_brush_mutation(5, 5, 1, CyberCellWorld.SAND) if path == "disc_compatibility" \
			else host.queue_brush_footprint_mutation(5, 5, CyberCellWorld.SAND)
		check(not refused and host.material_step_status().edit_requests == count_before,
			path + " refused edit does not arm another admission")
		worker._paint_busy = false
	host._material_steps.cancel("paint_case_end")
	host.brush_shape = "square"
	host.brush_size_px = 0 # Explicit empty-footprint defensive branch, not a UI brush setting.
	var before_empty: int = host.material_step_status().edit_requests
	check(not host.queue_brush_footprint_mutation(-1000, -1000, CyberCellWorld.SAND) \
		and host.material_step_status().edit_requests == before_empty, "empty footprint does not arm priority")


func _run() -> void:
	OS.set_environment("CYBERSAND_MATERIAL_PUBLICATION", "full")
	OS.set_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS", "2")
	var host = Main.new()
	var worker := AckProbe.new()
	var session := Session.new()
	var bridge := Bridge.new()
	bridge._session = 7
	bridge._epoch = 11
	session.bridge = bridge
	host.simulation_worker = worker
	host.shared_workbench = Control.new()
	host.physical_actor_session = session
	host.rapier_bridge = bridge
	host._physical_epoch = 11
	host.last_uploaded_world_generation = 42
	host.last_uploaded_render_snapshot_serial = 19
	host._material_step_interval = 2
	host._configure_material_steps()
	check(host.material_step_status().enabled, "explicit Full2 count2 Main configuration")
	var exact_identity: Array = [7, 11, 42, bridge.get_instance_id()]
	check(host._material_step_identity(_packet()) == exact_identity, "identity binds actual bridge object as well as numeric owner values")
	check(host._material_step_completed_witness(exact_identity).is_empty(), "inactive/uninitialized physical owner supplies no completion witness")

	_arm(host, worker)
	bridge._epoch = 12
	_cancelled(host, worker, "changed actor epoch")
	bridge._epoch = 11
	_arm(host, worker)
	bridge._session = 8
	_cancelled(host, worker, "changed actor session")
	bridge._session = 7
	_arm(host, worker)
	var recreated := Bridge.new()
	recreated._session = 7
	recreated._epoch = 11
	session.bridge = recreated
	_cancelled(host, worker, "recreated bridge with equal session and epoch")
	session.bridge = bridge
	_arm(host, worker)
	var malformed := _packet()
	malformed.render_context = {"workbench_display":{"session":7, "epoch":11}}
	host.latest_snapshot = malformed
	_cancelled(host, worker, "missing World in material identity")
	_arm(host, worker)
	var wrong_world := _packet()
	wrong_world.physics_world_generation = 43
	host.latest_snapshot = wrong_world
	_cancelled(host, worker, "material versus authoritative World mismatch")
	_arm(host, worker)
	host._actor_reset_receipt = 1
	_cancelled(host, worker, "pending actor reset")
	host._actor_reset_receipt = 0
	_arm(host, worker)
	host._pending_physical_candidate = RefCounted.new()
	_cancelled(host, worker, "pending physical replacement")
	host._pending_physical_candidate = null
	_arm(host, worker)
	host.pending_microscenario_apply = {"pending":true}
	_cancelled(host, worker, "pending World transaction")
	host.pending_microscenario_apply.clear()
	_arm(host, worker)
	var failed := _packet()
	failed.simulation_failed = true
	worker._published_snapshot = failed
	_cancelled(host, worker, "native failure before drain")
	_arm(host, worker)
	host.latest_snapshot = failed
	_cancelled(host, worker, "failed latest snapshot")
	_arm(host, worker)
	host._offer_material_snapshot(failed, 100001)
	_cancelled(host, worker, "failed offer retires old packet")
	_arm(host, worker)
	host._close_physical_actors()
	_cancelled(host, worker, "actual owner close")
	check(host.physical_actor_session == null and not bridge.is_initialized() \
		and bridge.manual_step_count() == 0 and host.rapier_bridge.manual_step_count() == 0,
		"owner identity tests configured no body and completed no step")

	# A stale selected serial must not count an upload merely because it is
	# already equal to Main's last serial. No texture path executes here.
	var stale := _packet()
	stale.rigid_body_epoch = 0
	stale.render_context = {}
	host.latest_snapshot = stale
	worker._published_snapshot = stale
	host._offer_material_snapshot(stale, 100002)
	host.last_uploaded_render_snapshot_serial = 20
	host._drain_material_steps(100002)
	check(host.material_step_status().accepted_uploads == 0 \
		and host.material_step_status().last_cancel == "upload_refused" and worker.serials.is_empty(),
		"already-accepted serial cannot earn duplicate count-policy upload credit")
	var refused_packet := _packet()
	refused_packet.rigid_body_epoch = 0
	refused_packet.render_snapshot_serial = 21
	refused_packet.render_context = {}
	host.latest_snapshot = refused_packet
	worker._published_snapshot = refused_packet
	# Exercise the real repeated-rejection diagnostic throttle; absent textures
	# refuse before any GPU action, while the original full-resync request runs.
	host.last_rejected_render_snapshot_serial = 21
	host._offer_material_snapshot(refused_packet, 100003)
	host._drain_material_steps(100003)
	check(host.rejected_render_snapshot_count == 1 and worker._render_full_refresh_requested \
		and host.material_step_status().accepted_uploads == 0 and worker.serials.is_empty(),
		"real upload refusal requests refresh and gives no accepted credit or ACK")
	_paint_admission(host, worker)

	host._material_deadline.configure(30)
	host._configure_material_steps()
	check(not host.material_step_status().enabled \
		and host.material_step_status().disabled_reason == "material_deadline_selected" \
		and host.material_deadline_status().enabled, "count policy cannot stack with selected time policy")
	host._material_deadline.configure(0)
	OS.set_environment("CYBERSAND_MATERIAL_PUBLICATION", "auto")
	host._configure_material_steps()
	check(not host.material_step_status().enabled \
		and host.material_step_status().disabled_reason == "full_publication_required", "auto backend is outside count arm scope")
	OS.set_environment("CYBERSAND_MATERIAL_PUBLICATION", "full")
	OS.set_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS", "3")
	host._configure_material_steps()
	check(not host.material_step_status().enabled \
		and host.material_step_status().disabled_reason == "two_slot_publication_required", "three-slot backend is outside count arm scope")
	OS.set_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS", "2")
	host._configure_material_steps()
	var pending := _packet()
	pending.rigid_body_epoch = 0
	pending.render_context = {}
	pending.render_snapshot_serial = 22
	host.latest_snapshot = pending
	worker._published_snapshot = pending
	host._offer_material_snapshot(pending, 100004)
	worker._render_full_refresh_requested = false
	host._material_publication_mode = "auto"
	host._drain_material_steps(100005)
	check(not host.material_step_status().enabled and host.material_step_status().pending_count == 0 \
		and host.material_step_status().disabled_reason == "publisher_changed" \
		and worker._render_full_refresh_requested and worker.serials.is_empty(),
		"live backend change cancels pending packet and requests a fresh unacknowledged publication")
	host.shared_workbench.free()
	host.shared_workbench = null
	host.free()
	print("MATERIAL_STEPS_IDENTITY_RESULT ", JSON.stringify({"schema":"pubpres-material-steps-main-identity-v1",
		"checks":checks, "complete":failures.is_empty(), "failures":failures,
		"cancelled_cases":cancelled_cases, "synthetic_identity_fields":true,
		"native_edits_executed":0, "actual_rapier_steps":0, "gpu_uploads":0, "physical_credit":false,
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"fixture_sha256":FileAccess.get_sha256(get_script().resource_path)}))
	quit(int(not failures.is_empty()))
