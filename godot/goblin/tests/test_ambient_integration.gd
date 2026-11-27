extends SceneTree

## Resulting-source integration of the opt-in Goblin adapter and AMBIENT policy.
## All mutations use the real Workbench owner. No actor pose or native cell writes.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
var adapter: Node
var oracle: RefCounted
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var expected_ambient: Dictionary = {}
var started := 0


func _initialize() -> void:
	started = Time.get_ticks_msec()
	run.call_deferred()


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("GOBLIN_AMBIENT: " + label)
	return value


func action(id: String, args: Dictionary = {}) -> Dictionary:
	var row: Dictionary = await adapter.execute({"id":id, "args":args})
	row["assertions"] = oracle.evaluate(row)
	records.append(row)
	check(row.status == "completed" and row.admission.get("accepted", false),
		id + " completed through the ordinary owner: " + str(row.get("error", "")))
	for assertion: Dictionary in row.assertions:
		check(assertion.status != "fail", id + " / " + str(assertion.id))
	return row


func body_ids() -> Array:
	return adapter.host.physical_actor_session.bodies().map(func(body: RigidBody2D): return body.get_rid())


func ambient_control() -> Dictionary:
	return Catalog.control_for(adapter.bench.actor(adapter.bench.applied, 1))


func run() -> void:
	adapter = Adapter.new()
	root.add_child(adapter)
	oracle = Assertions.new()
	var mounted: Dictionary = await adapter.mount()
	if check(mounted.get("ok", false), "isolated Goblin mounts the ordinary Workbench"):
		await exercise()
	await finish()


func exercise() -> void:
	check(Capacity.defaults().logical_limit == 8 and Capacity.MAX_ACTORS == 4096 \
		and Catalog.MAX_ACTORS == Capacity.MAX_ACTORS and Session.MAX_ACTORS == Capacity.MAX_ACTORS,
		"eight-actor default and opt-in 4096 ceiling agree across authoring and physical session")
	var start: Dictionary = Fixtures.build("mixed_stress", adapter.policy())
	var control: Dictionary = Catalog.control_for(start.actors[0])
	control.source = "policy"
	control.policy = "ambient"
	control.enabled = true
	control.usable_index = -1
	control.ambient = Profile.blank("mergedown-goblin-ambient")
	control.ambient.modules = [Profile.make_module("wander"), Profile.make_module("seek_material")]
	start.actors[0].control = control
	expected_ambient = control.duplicate(true)
	var human: Dictionary = Catalog.control_for(start.actors[1])
	human.source = "human"
	human.usable_index = -1
	start.actors[1].control = human
	var installed: Dictionary = await adapter.install_fixture("mixed_stress", start)
	if not check(installed.get("ok", false), "explicit ambient fixture uses native authored installation"): return
	oracle.reset(installed)
	var session: CyberPhysicalActorSession = adapter.host.physical_actor_session
	var owners := {"session":session.get_instance_id(), "worker":adapter.worker.get_instance_id(),
		"generation":int(adapter.worker.paint_state().generation), "bodies":body_ids()}
	await action("play", {"ticks":16})
	check(int(session.workbench_control(1).accepted) > 0,
		"explicit ambient actor receives actual accepted commands during native play")
	check(session._ambient_perception.diagnostics().queries > 0,
		"explicit ambient policy observes actual native materials")
	check(Catalog.control_for(adapter.bench.actor(adapter.bench.applied, 2)) == human,
		"ambient progression leaves the separate human actor's authored controller intact")
	var observation: Dictionary = session.workbench_policy_observation(1)
	if not check(not observation.is_empty(), "running ambient owner supplies a source-bound issued observation"): return
	var stale := Session.make_command(observation, int(observation.last_sequence) + 1,
		{"move":Vector2.RIGHT, "effort":0.25}, 6)
	await action("pause")
	check(session.workbench_policy_observation(1).is_empty(),
		"ordinary Pause does not issue a new policy authority")
	await action("actor_pilot", {"actor_id":1})
	check(ambient_control().source == "human" and ambient_control().ambient == expected_ambient.ambient,
		"Goblin pilot changes producer while retaining the authored ambient profile")
	check(not session.submit(stale, &"policy"), "command captured before pause and pilot handoff stays fenced")
	# Handoff changes authority synchronously; the ordinary Main owner retires
	# unused publication buffers on its next process pass, including while paused.
	# Observe that acknowledgement instead of calling the sensor owner ourselves.
	check(await adapter._until(func() -> bool:
		return not session._ambient_sensor_active and session._ambient_perception.diagnostics().cache_bytes == 0,
		"operation_seconds"), "ordinary paused owner pass retires the former ambient material cache")
	await action("play", {"ticks":8})
	var driven := await action("actor_drive", {"direction":"right", "ticks":8})
	check(driven.get("actor_delivery", {}).get("instance_id") == 1,
		"Goblin drive is delivered to the actual selected human actor")
	await action("pause")
	await action("actor_hand_back")
	check(ambient_control() == expected_ambient,
		"Goblin hand-back restores the exact authored ambient producer and profile")
	check(not session.submit(stale, &"policy"), "restoring ambient does not revive its stale pre-handoff lease")
	await action("play", {"ticks":16})
	check(session.workbench_control(1).get("diagnostics", {}).get("adapter") == "workbench-ambient/v1",
		"handed-back actor resumes the real ambient adapter")
	check(Catalog.control_for(adapter.bench.actor(adapter.bench.applied, 2)) == human,
		"pilot and hand-back preserve the other human controller")
	check(int(session.workbench_control(3).accepted) == 0,
		"passive barrel receives no autonomous command during Goblin actions")
	await action("pause")
	check(body_ids() == owners.bodies and session.get_instance_id() == owners.session,
		"all real Rapier bodies and the session survive pilot, drive and hand-back")
	check(adapter.worker.get_instance_id() == owners.worker \
		and int(adapter.worker.paint_state().generation) == owners.generation,
		"all controller changes preserve the single native World and worker")
	check(not is_instance_valid(adapter.bench._ambient_profile_editor) \
		and not is_instance_valid(adapter.bench._ambient_overlay),
		"Goblin operations do not open ambient authoring or diagnostic UI")
	await action("save_layout")
	await action("reopen_layout")
	check(ambient_control() == expected_ambient,
		"Goblin authored Save/Reopen retains the ambient assignment and profile")
	check(Catalog.control_for(adapter.bench.actor(adapter.bench.applied, 2)) == human,
		"authored reopen retains the separately controlled human actor")
	var reopened: CyberPhysicalActorSession = adapter.host.physical_actor_session
	check(reopened.get_instance_id() != owners.session \
		and int(adapter.worker.paint_state().generation) > owners.generation,
		"authored reopen installs a fresh source-bound physical session and native World")
	check(not reopened.submit(stale, &"policy"), "old session command cannot operate the reopened actor")
	check(reopened.tick == 0 and adapter.host.paused,
		"authored reopen starts paused with fresh physical progression")


func finish() -> void:
	var report := {"scope":"actual native Goblin002 and AMBIENT001 integration; no long-horizon or owner acceptance",
		"checks":checks, "failures":failures, "records":records, "elapsed_msec":Time.get_ticks_msec()-started,
		"profile":Adapter.verify_profile(), "godot":Engine.get_version_info()}
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute("user://goblin")
		var file := FileAccess.open("user://goblin/ambient-integration.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		await process_frame
	print("GOBLIN_AMBIENT_INTEGRATION_RESULT ", JSON.stringify({"checks":checks, "failures":failures,
		"records":records.size(), "elapsed_msec":report.elapsed_msec}))
	quit(0 if failures.is_empty() else 1)
