extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-LIFE-002 / #269: supplement the accepted fifty fresh lifetimes with
# actual desktop construction transactions. Reuse the same host, focus seam,
# main-thread input route, identity predicates and joined teardown apparatus.
# No mutable worker World is inspected, and no injected delay or FPS is claimed.
const LIQUID_MATERIALS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
const ASSIGNMENTS_AT: int = 20

var desktop: Control
var rig: StringName
var recipe: Dictionary
var accepted_rebuilds: int = 0
var accepted_resets: int = 0
var controlled_refusals: int = 0
var native_refusals: int = 0
var construction_rows: Array[Dictionary] = []


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE002: " + message)


func policy_values() -> Dictionary:
	return desktop.tower_context.get("liquid_solver_policy", {})


func receipt_values() -> Dictionary:
	return desktop.tower_context.get("liquid_construction_receipt", {})


func identities() -> Dictionary:
	return {"actor_epoch":desktop._physical_epoch,
		"world_generation":int(desktop.latest_snapshot.render_world_generation),
		"session_generation":int(policy_values().get("session_generation", -1))}


func installed_after(previous: Dictionary) -> bool:
	return (actor_ready(desktop, rig)
		and desktop._physical_epoch > int(previous.actor_epoch)
		and int(desktop.latest_snapshot.render_world_generation) > int(previous.world_generation)
		and int(policy_values().get("session_generation", -1)) > int(previous.session_generation))


func request_finished() -> bool:
	return desktop.pending_microscenario_apply.is_empty()


func unchanged_owner(previous: Dictionary, session: Variant, policy: Dictionary,
		receipt: Dictionary) -> bool:
	return (actor_ready(desktop, rig) and desktop.physical_actor_session == session
		and identities() == previous and policy_values() == policy
		and receipt_values() == receipt and desktop._pending_physical_candidate == null)


func water_assignment(policy: Dictionary) -> Dictionary:
	for assignment: Dictionary in policy.get("assignments", []):
		if int(assignment.material) == 3:
			return assignment
	return {}


func verify_applied(requested: PackedInt32Array, family: String, context: String) -> void:
	var applied: Dictionary = policy_values()
	var receipt: Dictionary = receipt_values()
	var water: Dictionary = water_assignment(applied)
	expect(applied.get("envelope", PackedInt32Array()) == requested
		and not str(applied.get("policy_hash", "")).is_empty()
		and receipt.get("policy_hash", "") == applied.get("policy_hash", ""),
		context + "native requested/applied policy envelope and typed receipt agree")
	expect(water.get("requested_family", "") == family
		and water.get("applied_family", "") == family
		and water.get("applied_variant", "") == "reference",
		context + "Water requested/applied family and variant remain explicit")
	expect(receipt.get("kind", "") == "applied_run"
		and receipt.get("run_intent", "") == "exploratory"
		and not bool(receipt.get("eligible_for_full_matched_evidence", true)),
		context + "construction receipt records exploratory intent without full-host qualification")
	expect(desktop.microscenario_definition.rectangles == recipe.rectangles
		and desktop.microscenario_definition.source_recipe_hash == recipe.source_recipe_hash
		and desktop.physical_rig_id == rig and desktop._physical_terrain_ready,
		context + "exact authored recipe, selected SetP rig and acknowledged terrain survive")


func exercise_live_owner(context: String) -> bool:
	var native_tick: int = desktop.latest_snapshot.tick_index
	var physical_tick: int = desktop.physical_actor_session.tick
	desktop.paused = false
	var advanced: bool = await wait_for(Callable(self, "clocks_advanced").bind(
		desktop, rig, physical_tick, native_tick))
	expect(advanced, context + "accepted native and main-thread Rapier clocks advance")
	if advanced:
		parse_key(KEY_SPACE, true)
		parse_key(KEY_SPACE, false)
		var edges: Array = desktop.physical_actor_session._button_edges[0]
		expect(edges.size() == 2 and bool(edges[0].pressed) and not bool(edges[1].pressed),
			context + "production input still preserves an ordered primary tap")
	desktop.paused = true
	await physics_frame
	return advanced


func reconstruct(preset: int, family: String) -> bool:
	var context: String = "%s %s: " % [rig, family]
	var prior: Dictionary = identities()
	var old_session = desktop.physical_actor_session
	var retained: CyberSimulationSnapshot = desktop.latest_snapshot
	var retained_policy: Dictionary = retained.lab_context.get("liquid_solver_policy", {}).duplicate(true)
	var retained_receipt: Dictionary = retained.lab_context.get("liquid_construction_receipt", {}).duplicate(true)
	var retained_tick: int = retained.tick_index
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1)
	panel.select_preset(preset)
	panel.refresh(desktop.tower_context)
	var requested: PackedInt32Array = panel.requested_policy.duplicate()
	expect(bool(panel._validation.get("accepted", false)) and not panel.apply_button.disabled,
		context + "existing panel admits supported policy reconstruction")
	var queued: bool = panel.apply_active()
	expect(queued, context + "existing panel queues actual prepared owner replacement")
	if not queued:
		return false
	expect(desktop.physical_actor_session == old_session
		and desktop._pending_physical_candidate != null,
		context + "old Rapier owner remains live until worker commit and main adoption")
	var applied: bool = await wait_for(Callable(self, "installed_after").bind(prior))
	expect(applied, context + "construction commits newer native session/World and actor identities")
	if not applied:
		return false
	accepted_rebuilds += 1
	expect(not is_instance_valid(old_session), context + "successful adoption retires old Rapier session")
	verify_applied(requested, family, context)
	expect(desktop.physical_actor_session._button_edges[0].is_empty()
		and not desktop._playable_course_progress.started,
		context + "replacement cannot inherit pending controls or the previous lap")
	if not await exercise_live_owner(context):
		return false

	var before_reset: Dictionary = identities()
	var reset_old_session = desktop.physical_actor_session
	var accepted_hash: String = str(policy_values().policy_hash)
	desktop.microscenario_reset()
	var reset_ok: bool = await wait_for(Callable(self, "installed_after").bind(before_reset))
	expect(reset_ok, context + "R/reset commits another native World and actual Rapier incarnation")
	if not reset_ok:
		return false
	accepted_resets += 1
	expect(not is_instance_valid(reset_old_session), context + "R/reset retires old actual session")
	verify_applied(requested, family, context + "reset: ")
	expect(str(policy_values().policy_hash) == accepted_hash,
		context + "R/reset retains selected policy hash")
	expect(retained.tick_index == retained_tick
		and int(retained.render_world_generation) == int(prior.world_generation)
		and retained.lab_context.get("liquid_solver_policy", {}) == retained_policy
		and retained.lab_context.get("liquid_construction_receipt", {}) == retained_receipt,
		context + "retained earlier snapshot, native receipt and envelope are immutable")
	construction_rows.append({"family":family,"before":prior,"applied":before_reset,
		"reset":identities(),"policy_hash":accepted_hash,
		"receipt_hash":str(receipt_values().get("receipt_hash", "")),
		"recipe_hash":str(recipe.source_recipe_hash)})
	return await refusals(requested, context)


func refusals(requested: PackedInt32Array, context: String) -> bool:
	var prior: Dictionary = identities()
	var session = desktop.physical_actor_session
	var policy: Dictionary = policy_values().duplicate(true)
	var receipt: Dictionary = receipt_values().duplicate(true)
	var serial: int = desktop._microscenario_request_serial
	expect(not desktop.microscenario_apply_controlled_liquid(
		desktop.microscenario_definition, requested, false, "Play", 2),
		context + "fixed actor-free/controlled route explicitly refuses a playable actor")
	expect(unchanged_owner(prior, session, policy, receipt)
		and desktop._microscenario_request_serial == serial,
		context + "synchronous route refusal keeps the accepted World, owner and receipt")
	controlled_refusals += 1

	# Unsupported Oil/PF is deliberately submitted through the public host API:
	# unlike the panel's disabled choice, this reaches native capability refusal
	# after a separate actual graph has been staged. The old owner must survive.
	var unsupported: PackedInt32Array = requested.duplicate()
	var oil: int = LIQUID_MATERIALS.find(16)
	unsupported[ASSIGNMENTS_AT + oil * 3 + 1] = 3
	unsupported[ASSIGNMENTS_AT + oil * 3 + 2] = 1
	var queued: bool = desktop.microscenario_apply_exploratory_liquid(
		desktop.microscenario_definition, unsupported, false, "Play")
	expect(queued, context + "unsupported material/family request reaches existing owner transaction")
	if not queued:
		return false
	var candidate = desktop._pending_physical_candidate
	var candidate_session = candidate.session if candidate != null else null
	expect(candidate != null and is_instance_valid(candidate_session)
		and desktop.physical_actor_session == session,
		context + "negative request stages a distinct graph without retiring accepted owner")
	var finished: bool = await wait_for(Callable(self, "request_finished"))
	expect(finished and desktop.microscenario_error.contains("combination_rejected"),
		context + "native unsupported combination returns explicit terminal refusal")
	expect(unchanged_owner(prior, session, policy, receipt)
		and not is_instance_valid(candidate_session),
		context + "native refusal closes staged graph and retains accepted World/actor/receipt")
	if not finished:
		return false
	native_refusals += 1
	return await exercise_live_owner(context + "after refusal: ")


func run() -> void:
	rig = target_rig()
	var started: int = Time.get_ticks_msec()
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects a supported SetP mechanical rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(), "existing worker starts")
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	if ready:
		expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0), "authored course admits")
		ready = await wait_for(Callable(self, "course_installed").bind(desktop))
		expect(ready, "actual worker acknowledges authored course")
	if ready:
		recipe = desktop.microscenario_definition.duplicate(true)
		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(rig)), &"human", false), "F5 admits selected actual SetP rig")
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, rig))
		expect(ready, "selected actor, native epoch and terrain are ready")
	if ready:
		ready = await reconstruct(2, "pressure_flow_v1")
	if ready:
		ready = await reconstruct(0, "freemass_v1")
	expect(ready and accepted_rebuilds == 2 and accepted_resets == 2
		and controlled_refusals == 2 and native_refusals == 2,
		"both supported policy reconstructions/resets and all four explicit refusals complete")
	expect(not worker.has_failed(), "worker stays outside failure quarantine")
	var final_session = desktop.physical_actor_session
	await close_cycle(desktop, worker, final_session, str(rig) + ": ")
	print("PLAY_LIFE002_RESULT ", JSON.stringify({
		"rig":str(rig),"real_host":true,"host":"main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"assertions":assertions,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,
		"policy_reconstructions":accepted_rebuilds,"policy_retaining_resets":accepted_resets,
		"controlled_refusals":controlled_refusals,"native_capability_refusals":native_refusals,
		"workers_joined":joined_workers,"rapier_sessions_retired":retired_sessions,
		"construction_rows":construction_rows,"retries":0,"slow_native_injection":false,
		"rendered_fps_measured":false,"physical_gamepad_qualified":false}))
	quit(0 if failures == 0 else 1)
