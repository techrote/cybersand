extends SceneTree

# AMBIENT default-OFF integration regression. Runs the ordinary application,
# native owner and Rapier session. It never mutates native cells or body poses.
# Fixture creation and control handoff use the public authored Workbench paths.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var bench: Control
var checks := 0
var failures: Array[String] = []
var phases: Array = []
var begun := 0


func _initialize() -> void:
	begun = Time.get_ticks_msec()
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	set_meta("cybersand_feature", "shared_workbench")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var start := fixture(bridge.call(&"default_liquid_policy"))
	set_meta("cybersand_playable_recovery", {"workbench":start})
	run.call_deferred()


func fixture(policy: PackedInt32Array) -> Dictionary:
	var start := Setup.fresh(policy, Vector2i(512, 512))
	start.edits = [[0, 400, 512, 12, 58], [104, 380, 12, 20, 16]]
	var rows := [["runner",101,"human",80], ["crawler",202,"scripted",200],
		["runner",303,"policy",320], [Setup.BARREL,404,"passive",440]]
	for row: Array in rows:
		var actor := Setup.instance(str(row[0]), int(row[1]), Vector2(float(row[3]), 340))
		var control := Catalog.control_for(actor)
		control.source = str(row[2])
		control.usable_index = -1
		if control.source == "policy": control.policy = "external"
		actor.control = control
		start.actors.append(actor)
	start.selected = 101
	start.next_id = 405
	return start


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_DEFAULT_OFF: " + label)
	return value


func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and host.physical_actor_session != null


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	var progress_at := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec() >= progress_at:
			print("AMBIENT_DEFAULT_OFF_WAIT ", label, " ", JSON.stringify(Catalog._json_value(ambient_state())))
			progress_at = Time.get_ticks_msec() + 10000
		await process_frame
	phases.append({"phase":label + " watchdog", "ambient":ambient_state()})
	return check(false, label + " did not complete within the existing operation watchdog")


# Bounded immutable scalar observations only; no worker mutation or extra query.
func ambient_state() -> Dictionary:
	if host == null or host.physical_actor_session == null: return {}
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var snapshot: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
	var result := {"sensor":session._ambient_perception.diagnostics(),
		"sensor_active":session._ambient_sensor_active, "refresh_requested":session._ambient_refresh_requested,
		"policy_world_generation":session._ambient_world_generation, "policy_owner_serial":session._ambient_world_serial,
		"physical_tick":session.tick}
	if snapshot != null:
		result["latest_material_envelope"] = {"serial":snapshot.serial,
			"physics_world_generation":snapshot.physics_world_generation, "render_world_generation":snapshot.render_world_generation,
			"native_tick":snapshot.tick_index, "native_revision":snapshot.simulation_world_revision,
			"render_serial":snapshot.render_snapshot_serial, "render_tick":snapshot.render_tick_index,
			"material_revision":snapshot.world_revision, "patch_bytes":snapshot.render_patch_cells.size(),
			"backend":snapshot.backend_name, "failed":snapshot.simulation_failed}
	return result


func native_tick() -> int:
	var publication: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
	return int(publication.tick_index) if publication != null else -1


func progress(count: int, label: String) -> bool:
	var initial_native := native_tick()
	var initial_physical: int = host.physical_actor_session.tick
	if not await until(func() -> bool:
		return native_tick() >= initial_native + count \
			and int(host.physical_actor_session.tick) >= initial_physical + count, label): return false
	phases.append({"phase":label, "native_ticks":native_tick() - initial_native,
		"physical_ticks":int(host.physical_actor_session.tick) - initial_physical,
		"perception":host.physical_actor_session._ambient_perception.diagnostics()})
	return true


func check_off(label: String, pristine: bool) -> void:
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var perception: Dictionary = session._ambient_perception.diagnostics()
	check(not session._ambient_sensor_active and not session._ambient_refresh_requested,
		label + ": no material sensor admission or outstanding refresh")
	check(perception.cache_bytes == 0 and session._ambient_perception._cache == null,
		label + ": no retained material image allocation")
	check(not is_instance_valid(bench._ambient_profile_editor) and not is_instance_valid(bench._ambient_overlay),
		label + ": editor and overlay have not been instantiated")
	if pristine:
		check(perception.ingestions == 0 and perception.queries == 0 and perception.source_bytes == 0,
			label + ": no native publication copies or ambient queries")
		for adapter: RefCounted in session._scripts:
			check(not adapter._ambient_configured and not adapter._ambient_active,
				label + ": ordinary producer has no configured or running ambient engine")
	for actor: Dictionary in bench.applied.actors:
		var state: Dictionary = session.workbench_control(int(actor.id))
		check(state.get("diagnostics", {}).get("adapter", "") != "workbench-ambient/v1",
			label + ": ordinary actor inspection exposes no active ambient policy")


func body_ids() -> Array:
	return host.physical_actor_session.bodies().map(func(body: RigidBody2D): return body.get_rid())


func run() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	bench = host.shared_workbench
	if await until(installed, "ordinary four-producer Workbench installation"):
		await exercise()
	await finish()


func exercise() -> void:
	check(Catalog.Capacity.defaults().logical_limit == 8 and Catalog.MAX_AMBIENT_CONTROLLERS == 8,
		"ordinary defaults retain eight logical actors and eight AMBIENT slots")
	check(bench.applied.actors.size() == 4, "all four ordinary producer families installed")
	check_off("initial paused ordinary scene", true)
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var owners := {"session":session.get_instance_id(), "worker":host.simulation_worker.get_instance_id(),
		"native_generation":int(host.simulation_worker.paint_state().generation)}
	var bodies := body_ids()
	if not check(bench.toggle_pause(), "ordinary Play starts"): return
	if not await progress(30, "ordinary producers with ambient OFF"): return
	check_off("ordinary native and physical progression", true)
	check(int(session.workbench_control(202).accepted) > 0, "existing scripted actor still receives accepted commands")
	check(int(session.workbench_control(303).accepted) == 0, "external policy remains idle without an issued command")
	check(int(session.workbench_control(404).accepted) == 0, "passive body receives no automatic command")
	var external: Dictionary = session.workbench_policy_observation(303)
	check(not external.is_empty(), "external actor keeps its issued-observation authority")
	if external.is_empty(): return
	check(bench.submit_actor_policy(303, Session.make_command(external, int(external.last_sequence) + 1,
		{"move":Vector2.RIGHT,"effort":0.25}, 6)), "ordinary external command admitted through Workbench")
	if not await progress(12, "external command beside existing producers"): return
	check_off("after legitimate external command", true)
	var ordinary := Catalog.control_for(bench.actor(bench.applied, 101))
	var ambient := ordinary.duplicate(true)
	ambient.source = "policy"
	ambient.policy = "ambient"
	ambient.ambient = Profile.blank("mergedown-explicit-activation")
	ambient.ambient.modules = [Profile.make_module("seek_material")]
	check(bench.set_actor_control(101, ambient), "explicit ambient opt-in uses the existing actor owner")
	if not await until(func() -> bool:
		var state: Dictionary = session._ambient_perception.diagnostics()
		return state.cache_bytes > 0 and state.ingestions > 0 and state.queries > 0,
		"explicitly activated sensor and policy"): return
	phases.append({"phase":"explicitly activated sensor and policy", "ambient":ambient_state()})
	var active: Dictionary = session.workbench_policy_observation(101)
	var stale := Session.make_command(active, int(active.last_sequence) + 1,
		{"move":Vector2.RIGHT,"effort":0.25}, 6)
	var disabled := ambient.duplicate(true)
	disabled.enabled = false
	check(bench.set_actor_control(101, disabled), "explicit disable retires ambient producer")
	if not await progress(12, "disabled authored ambient profile"): return
	check_off("disabled authored profile", false)
	var count_before: Dictionary = session._ambient_perception.diagnostics()
	var accepted_before: int = int(session.workbench_control(101).accepted)
	if not await progress(24, "continued play after ambient disable"): return
	var count_after: Dictionary = session._ambient_perception.diagnostics()
	check(count_before.queries == count_after.queries and count_before.ingestions == count_after.ingestions \
		and count_before.source_bytes == count_after.source_bytes,
		"disabled ambient performs no continued sensing, native copies or policy sampling")
	check(int(session.workbench_control(101).accepted) == accepted_before,
		"disabled ambient issues no fresh actor commands while other actors progress")
	check(bench.set_actor_control(101, ordinary), "ordinary human producer restored through live handoff")
	check(not session.submit(stale, &"policy"), "old ambient authority cannot command the handed-back actor")
	check(session.submit_workbench_action(101, {"move":Vector2.RIGHT,"effort":0.25},
		{"q":false,"e":false,"s":false,"boost":false}, false), "restored human action remains admissible")
	if not await progress(12, "human handback with ambient OFF"): return
	check_off("human handback", false)
	check(body_ids() == bodies and session.get_instance_id() == owners.session,
		"activation, disable and handback preserve every actual physical body and session")
	check(host.simulation_worker.get_instance_id() == owners.worker \
		and int(host.simulation_worker.paint_state().generation) == owners.native_generation,
		"activation and handoff preserve native World generation and worker ownership")
	check(bench.toggle_pause(), "ordinary Pause remains available after all handoffs")


func finish() -> void:
	var result := {"checks":checks,"failures":failures,"phases":phases,
		"elapsed_msec":Time.get_ticks_msec() - begun,"godot":Engine.get_version_info(),
		"limits":["Headless native/Rapier ownership and isolation only; no physical Windows or playfeel acceptance",
			"Small pure adapter allocations and definition scans remain; no zero-allocation performance claim"]}
	print("AMBIENT_DEFAULT_OFF ", JSON.stringify(Catalog._json_value(result)))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
