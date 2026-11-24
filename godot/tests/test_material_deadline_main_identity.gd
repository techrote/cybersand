extends SceneTree

## Actual Main identity/cancellation methods with real owner classes and copied
## identity fields. No body is configured, no texture is uploaded, and no native
## or Rapier step is attempted. These are authority checks, not gameplay proof.
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
		push_error("MATERIAL_DEADLINE_IDENTITY: " + detail)


func _packet() -> CyberSimulationSnapshot:
	var result := CyberSimulationSnapshot.new()
	result.rigid_body_epoch = 11
	result.physics_world_generation = 42
	result.render_world_generation = 42
	result.render_snapshot_serial = 20
	result.render_full_refresh = true
	result.render_context = {"workbench_display":{"session":7, "epoch":11, "world_generation":42}}
	return result


func _arm(host: Control, worker: AckProbe) -> void:
	var snapshot := _packet()
	host.latest_snapshot = snapshot
	worker._published_snapshot = snapshot
	host._offer_material_snapshot(snapshot, 100000)
	check(host.material_deadline_status().pending_count == 1,
		"matching actual owner classes retain one pending offer")


func _cancelled(host: Control, worker: AckProbe, reason: String) -> void:
	host._drain_material_deadline(999999)
	var state: Dictionary = host.material_deadline_status()
	check(state.pending_count == 0 and state.consumptions == 0 and state.accepted_uploads == 0 \
		and worker.serials.is_empty() and host.last_uploaded_render_snapshot_serial == 19,
		reason + " cancels before upload, history mutation or ACK")
	cancelled_cases.append(reason)


func _run() -> void:
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
	host._physical_epoch = 11
	host.last_uploaded_world_generation = 42
	host.last_uploaded_render_snapshot_serial = 19
	check(host._material_deadline.configure(30), "explicit policy configured")
	check(host._material_deadline_identity(_packet()) == [7, 11, 42],
		"actual WorkbenchBridge session and epoch accepted")

	_arm(host, worker)
	bridge._epoch = 12
	_cancelled(host, worker, "changed actor epoch")
	bridge._epoch = 11
	_arm(host, worker)
	bridge._session = 8
	_cancelled(host, worker, "changed actor session")
	bridge._session = 7

	_arm(host, worker)
	var malformed := _packet()
	malformed.render_context = {"workbench_display":{"session":7, "epoch":11}}
	host.latest_snapshot = malformed
	_cancelled(host, worker, "incomplete material frame identity")
	_arm(host, worker)
	var wrong_world := _packet()
	wrong_world.physics_world_generation = 43
	host.latest_snapshot = wrong_world
	_cancelled(host, worker, "material and authoritative World disagreement")

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
	# Publish a separate failed status value; the retained healthy packet is
	# immutable. has_failed() reads the real worker's protected status path.
	worker._published_snapshot = failed
	_cancelled(host, worker, "native failure before deadline drain")
	_arm(host, worker)
	host.latest_snapshot = failed
	_cancelled(host, worker, "failed latest snapshot before deadline drain")
	_arm(host, worker)
	host._offer_material_snapshot(failed, 100001)
	_cancelled(host, worker, "failed offer invalidates pending packet")

	_arm(host, worker)
	host._close_physical_actors()
	_cancelled(host, worker, "actual physical owner closure")
	check(host.physical_actor_session == null and not bridge.is_initialized() \
		and bridge.manual_step_count() == 0 and host.rapier_bridge.manual_step_count() == 0,
		"identity fixtures create no active body owner or actual step")
	host.shared_workbench.free()
	host.shared_workbench = null
	host.free()
	print("MATERIAL_DEADLINE_IDENTITY_RESULT ", JSON.stringify({
		"schema":"pubpres-material-deadline-main-identity-v1", "checks":checks,
		"complete":failures.is_empty(), "failures":failures, "cancelled_cases":cancelled_cases,
		"synthetic_identity_fields":true, "physical_credit":false, "gpu_uploads":0,
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"fixture_sha256":FileAccess.get_sha256(get_script().resource_path)}))
	quit(int(not failures.is_empty()))
