extends SceneTree

# Contract/refusal tests against a real, ordinary CyberSimulationWorker.
# NO second World, NO mock physics, NO claim of native M4 integration.
const Worker = preload("res://scripts/simulation_worker.gd")
const Port = preload("res://scripts/object_shard_m4_workbench_port.gd")

var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var worker: CyberSimulationWorker = Worker.new()
	var original_world: Variant = worker._world
	var original_world_instance: int = original_world.get_instance_id()
	var port: CyberObjectShardM4WorkbenchPort = Port.new()
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.render_world_generation = 7
	snapshot.world_revision = 90
	snapshot.lab_context = {"workbench_gcr": {"response": "LA-SELECTIVE"}}
	_expect(port.interface_status(worker, snapshot).outcome == "FeatureDisabled",
		"Default-off M4 cannot adopt a World")
	port.enabled = true
	_expect(port.interface_status(null, snapshot).outcome == "OrdinaryWorkerRequired",
		"Foreign or absent worker must refuse")
	_expect(port.interface_status(worker, null).outcome == "LiveSnapshotRequired",
		"An absent owner publication must refuse")
	snapshot.simulation_failed = true
	_expect(port.interface_status(worker, snapshot).outcome == "LiveSnapshotRequired",
		"Failed native publication must refuse")
	snapshot.simulation_failed = false
	snapshot.lab_context.workbench_refusal = "Native owner quarantined"
	_expect(port.interface_status(worker, snapshot).outcome == "WorkbenchOwnerRefused",
		"Actual Workbench quarantine has priority")
	snapshot.lab_context.erase("workbench_refusal")
	snapshot.lab_context.erase("workbench_gcr")
	_expect(port.interface_status(worker, snapshot).outcome == "OrdinaryWorkbenchRequired",
		"Non-Workbench scenes cannot borrow an ObjectShard attachment")
	snapshot.lab_context.workbench_gcr = {"response": "LA-SELECTIVE"}
	var capability: Dictionary = port.interface_status(worker, snapshot)
	_expect(not capability.ready and capability.outcome == "SameWorldAdapterMissing",
		"Current ordinary Workbench refuses an absent same-World native/worker interface")
	_expect(worker._world == original_world and worker._world.get_instance_id() == original_world_instance,
		"Refusal preserves the exact already-owned ordinary native World")
	_expect(port.pending_count() == 0, "No input was silently queued in a detached owner")
	_expect(port.results.is_empty(), "No fictitious native result was fabricated")

	var observed: Dictionary = {"world_generation": 7, "world_revision": 90,
		"render_serial": 8, "session": 12, "owner_epoch": 9,
		"shard_session": 14, "world_incarnation": 5,
		"transport_generation": 3, "publication_sequence": 45}
	var uploaded: Dictionary = {"world_generation": 7, "world_revision": 90, "render_serial": 8}
	_expect(Port.visible_error(observed, uploaded).is_empty(),
		"Value-only visible publication contract accepts a matching displayed receipt")
	uploaded.render_serial = 9
	_expect(Port.visible_error(observed, uploaded) == "VisiblePublicationChanged",
		"Worker receiving a newer packet does not advance the uploaded frame")
	uploaded.render_serial = 8
	observed.erase("publication_sequence")
	_expect(Port.visible_error(observed, uploaded) == "MissingObservationIdentity",
		"Missing observed publication identity must refuse")
	observed.publication_sequence = 45

	var position := Vector2i(61, 42)
	var target: Dictionary = {"position": position, "session": 12, "owner_epoch": 9,
		"shard_session": 14, "world_incarnation": 5, "transport_generation": 3,
		"publication_sequence": 45, "owner": 4, "cell": 61, "generation": 2,
		"body_generation": 2, "geometry_revision": 3, "applied_physics_revision": 4,
		"pose_serial": 15, "material_revision": 9, "incarnation": 21,
		"expected": {"material": 7, "state_a": 2, "state_b": 0, "temperature": 240}}
	_expect(Port.target_error(target, position, observed).is_empty(),
		"Value-only exact moving-cell witness has all native identity dimensions")
	var stale: Dictionary = target.duplicate(true)
	stale.pose_serial = "15"
	_expect(Port.target_error(stale, position, observed) == "IncompleteMovingTarget",
		"Non-integer pose witness cannot be converted into new target authority")
	stale = target.duplicate(true)
	stale.world_incarnation = 4
	_expect(Port.target_error(stale, position, observed) == "TargetObservationChanged",
		"Previous native World incarnation cannot target the new owner")
	stale = target.duplicate(true)
	stale.publication_sequence = 44
	_expect(Port.target_error(stale, position, observed) == "TargetObservationChanged",
		"Stale visible-frame sequence refuses without remapping a moving cell")
	stale = target.duplicate(true)
	stale.owner = 0
	_expect(Port.target_error(stale, position, observed) == "MovingTargetRequired",
		"World terrain and moving material cannot be conflated")
	stale = target.duplicate(true)
	stale.expected.erase("temperature")
	_expect(Port.target_error(stale, position, observed) == "IncompleteMovingTarget",
		"Exact material incarnation witness includes temperature and states")

	var queued: Dictionary = port.queue_intent(worker, snapshot, uploaded, observed,
		"erase", position, target, Time.get_ticks_usec())
	_expect(not queued.ok and queued.outcome == "SameWorldAdapterMissing",
		"An edit cannot silently fall through to existing terrain painting")
	_expect(port.pending_count() == 0 and worker._world == original_world,
		"Failed moving-cell admission changes neither queue nor World")
	_expect(port.consume_receipt({"action_id": 1, "outcome": "Applied"}).outcome == "UnknownOrRetiredAction",
		"A fabricated or delayed applied receipt cannot mutate ownership")
	var first_generation: int = port.generation
	port.retire("Navigation")
	_expect(port.generation == first_generation + 1 and port.pending_count() == 0,
		"F2/reset epoch retirement invalidates old port identities")
	_expect(worker._world.get_instance_id() == original_world_instance,
		"Port shutdown never destroys or replaces the running Workbench World")
	worker.stop_worker()
	worker = null
	print(JSON.stringify({"schema": "objectshard-m4-workbench-contract-v1",
		"checks": checks, "failures": failures,
		"scope": "real ordinary worker identity, negative same-World admission and value-only witness validation",
		"same_world_mutation_integration": "BLOCKED_UNTIL_NATIVE_ADAPTER",
		"real_physics_assertions": 0}))
	quit(0 if failures == 0 else 1)
