class_name CyberPhysicalFlightEpisode
extends Node2D

# 4LY-003 actual-host owner. The arena already performs native-material ticks,
# Rapier coupling, bounded physical control and v2 producer/lease fencing.
# This layer owns TASK observations and stopping only; it never writes a body.
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Controller = preload("res://scripts/physical_flight_controller.gd")
const Course = preload("res://scripts/physical_flight_course.gd")
const Teacher = preload("res://scripts/physical_flight_teacher.gd")
const Adapter = preload("res://scripts/physical_flight_observation_adapter.gd")
const VERSION: String = "4ly-episode/v1"
const OBS_VERSION: String = "4ly-observation/v1"
const ACTION_VERSION: String = "4ly-action/v1"
const FIXED_DELTA: float = 1.0 / 60.0
const DECISION_TICKS: int = 6
const LEASE_TICKS: int = 12
const MAX_RECORD_TICKS: int = 2400

var arena: CyberPhysicalActorArena
var scenario: Dictionary = {}
var profile_id: StringName = &""
var source: StringName = &"policy"
var last_error: String = ""
var _teacher = Teacher.new()
var _observation: Dictionary = {}
var _trace: Array[Dictionary] = []
var _terminal: bool = true
var _truncated: bool = false
var _failed: bool = false
var _success: bool = false
var _reason: String = "not_configured"
var _waypoint: int = 0
var _dwell: int = 0
var _overshoot: int = 0
var _contacts: int = 0
var _invalid_actions: int = 0
var _decisions: int = 0
var _ticks: int = 0
var _last_distance: float = INF
var _best_distance: float = INF
var _step_reward: float = 0.0
var _episode_reward: float = 0.0
var _last_reward_terms: Dictionary = {}
var _disturbance_applied: bool = false
var _disturbance_receipt: Dictionary = {}
var _start_usec: int = 0
var _reset_usec: int = 0
var _serialize_usec: int = 0


func _ready() -> void:
	if arena == null:
		arena = Arena.new()
		arena.name = "ActualRapierNativeFlightHost"
		add_child(arena)


func reset(model: StringName, scenario_id: String, seed: int = 0,
		split: String = "development", requested_source: StringName = &"policy") -> bool:
	last_error = ""
	if not is_inside_tree() or not Profile.has_rig(model) or requested_source not in [&"human", &"teacher", &"policy"]:
		last_error = "unsupported_profile_or_producer"
		return false
	var definition: Dictionary = Course.scenario(scenario_id, seed, split)
	if definition.is_empty() or int(definition.max_ticks) > MAX_RECORD_TICKS:
		last_error = "invalid_scenario"
		return false
	var started: int = Time.get_ticks_usec()
	var plant_producer: StringName = &"human" if requested_source == &"human" else &"policy"
	var config: Dictionary = {"version": Arena.VERSION, "course": Course.ID,
		"flight_scenario": scenario_id, "flight_split": split, "seed": seed,
		"max_ticks": int(definition.max_ticks), "local_patch_radius": 8,
		"actors": [{"model": str(model), "producer": str(plant_producer),
			"position": Vector2(definition.start)}]}
	if not arena.configure(config):
		last_error = "actual_host_reset: " + arena.last_error
		return false
	if bool(definition.power_off) and not arena.session.set_propulsion_enabled(0, false):
		last_error = "host_power_off_refused"
		arena.set_paused(true)
		return false
	profile_id = model
	source = requested_source
	scenario = definition.duplicate(true)
	_teacher.reset()
	_disturbance_applied = false
	_disturbance_receipt.clear()
	_trace.clear()
	_terminal = false
	_truncated = false
	_failed = false
	_success = false
	_reason = "running"
	_waypoint = 0
	_dwell = 0
	_overshoot = 0
	_contacts = 0
	_invalid_actions = 0
	_decisions = 0
	_ticks = 0
	_last_distance = INF
	_best_distance = INF
	_step_reward = 0.0
	_episode_reward = 0.0
	_last_reward_terms.clear()
	_reset_usec = Time.get_ticks_usec() - started
	_serialize_usec = 0
	_start_usec = Time.get_ticks_usec()
	_observation = _publish_observation()
	return not _observation.is_empty()


func observe() -> Dictionary:
	return _observation.duplicate(true)


func flat_observation() -> Dictionary:
	return Adapter.flatten(observe())


func reference_action() -> Dictionary:
	# No scenario, absolute target, evaluator snapshot or native World object
	# reaches this scripted producer.
	if source != &"teacher" or _terminal:
		return {}
	return _teacher.action(observe())


func active_goal() -> Vector2:
	if scenario.is_empty() or scenario.goals.is_empty():
		return Vector2.INF
	# Preserve the final *real* target even after the evaluator has completed
	# its last waypoint; never synthesize a zero-error terminal observation.
	return Vector2(scenario.goals[mini(_waypoint, scenario.goals.size() - 1)])


func _publish_observation() -> Dictionary:
	var begin: int = Time.get_ticks_usec()
	var owner: Dictionary = arena.observation(0)
	if owner.is_empty() or not owner.has("flight"):
		return {}
	var goal: Vector2 = active_goal()
	if not goal.is_finite():
		goal = Vector2(owner.centre)
	var command: Dictionary = owner.flight.get("command", {})
	var command_live: bool = bool(owner.flight.get("command_live", false))
	var static_capabilities: Dictionary = owner.flight.get("capabilities", {}).get("capabilities", {})
	var sensors: Dictionary = arena.local_flight_rays(0, 80.0)
	var valid: bool = bool(sensors.get("available", false))
	var copy: Dictionary = {
		"version": OBS_VERSION, "action_version": ACTION_VERSION,
		"run_id": str(owner.run_id), "actor_id": 0, "epoch": int(owner.epoch),
		"observed_tick": int(owner.tick), "observation_id": str(owner.observation_id),
		"control_generation": int(owner.control_generation),
		"goal_delta_cells": goal - Vector2(owner.centre),
		"arrival_radius_cells": float(scenario.arrival_radius),
		"velocity_cells_per_second": Vector2(owner.velocity),
		"orientation_sin": sin(float(owner.rotation)),
		"orientation_cos": cos(float(owner.rotation)),
		"angular_velocity_rad_per_second": float(owner.angular_velocity),
		"actuator_mode": str(owner.flight.get("mode", "unavailable")),
		"assistance_valid": command_live and bool(owner.flight.get("controller", {}).get("valid", false)),
		"command_age_ticks": int(owner.tick) - int(command.get("observed_tick", owner.tick)) if not command.is_empty() else -1,
		"command_live": command_live,
		"lease_remaining_ticks": int(owner.lease_remaining),
		"resources": {"supply": "continuous_authored_power",
			"powered": bool(owner.flight.get("propulsion_enabled", false)),
			"fuel_measurement_valid": false},
		"capabilities": static_capabilities.duplicate(true),
		"local_obstacles": sensors.duplicate(true) if valid else {
			"available": false, "distances": [], "hits": [], "valid": []}
	}
	_serialize_usec += Time.get_ticks_usec() - begin
	return copy.duplicate(true)


func tick(action: Variant = null, observation_id: String = "", repeat_ticks: int = 1) -> Dictionary:
	# One policy decision each six REAL 60-Hz ticks. An omitted action carries
	# only the already admitted lease. Each tick is evaluated independently.
	if _terminal or arena == null or arena.session == null:
		return transition(0)
	if repeat_ticks < 1 or repeat_ticks > DECISION_TICKS or _ticks % DECISION_TICKS + repeat_ticks > DECISION_TICKS:
		_fail("invalid_decision_repeat")
		return transition(0)
	var must_decide: bool = _ticks % DECISION_TICKS == 0
	if must_decide and action == null:
		# A missed fresh decision may consume only the remainder of an already
		# admitted lease. This submits no command, renews no authority and lets
		# the real session retire the lease at its physical deadline.
		var lease_owner: Dictionary = arena.observation(0)
		var lease_flight: Dictionary = lease_owner.get("flight", {})
		if lease_owner.is_empty() or not bool(lease_flight.get("command_live", false)):
			_fail("missing_decision")
			return transition(0)
	if not must_decide and action != null:
		_fail("action_outside_decision_boundary")
		return transition(0)
	_step_reward = 0.0
	_last_reward_terms.clear()
	var command: Dictionary = {}
	if action != null:
		var normalized: Dictionary = Session.normalized_flight_action(action)
		if normalized.is_empty() or observation_id != str(_observation.get("observation_id", "")):
			_invalid_actions += 1
			_fail("invalid_or_stale_action")
			return transition(0)
		var owner: Dictionary = arena.observation(0)
		if str(owner.get("observation_id", "")) != observation_id \
			or int(owner.get("control_generation", -1)) != int(_observation.get("control_generation", -2)) \
			or int(owner.get("tick", -1)) != int(_observation.get("observed_tick", -2)):
			_invalid_actions += 1
			_fail("owner_observation_fenced")
			return transition(0)
		command = Session.make_command(owner, int(owner.last_sequence) + 1, normalized, LEASE_TICKS)
		_decisions += 1
	var consumed: int = 0
	for index: int in range(repeat_ticks):
		var before: int = int(arena.session.tick)
		var requested: Dictionary = command.duplicate(true) if index == 0 else {}
		var accepted: bool = true
		if not requested.is_empty():
			accepted = arena.submit(requested, &"human" if source == &"human" else &"policy")
		if not accepted:
			# A rejected command must never advance even one real physics tick.
			_invalid_actions += 1
			_fail("action_admission: " + arena.last_error)
			break
		_disturbance_receipt.clear()
		if not _disturbance_applied and not scenario.get("disturbance", {}).is_empty() \
			and _ticks == int(scenario.disturbance.tick):
			_disturbance_applied = true
			_disturbance_receipt = arena.apply_flight_disturbance(0,
				arena.session.epoch, arena.session.tick,
				Vector2(scenario.disturbance.delta_velocity),
				float(scenario.disturbance.delta_angular_velocity))
			if not bool(_disturbance_receipt.get("accepted", false)):
				_fail("host_disturbance_admission")
				break
		var frame: Dictionary = arena.step([])
		if int(arena.session.tick) != before + 1:
			_fail("physics_tick_not_consumed")
			break
		_ticks += 1
		consumed += 1
		var owner: Dictionary = arena.observation(0)
		_assess_tick(owner, frame, requested, accepted)
		_observation = _publish_observation()
		if _terminal:
			arena.set_paused(true)
			break
	return transition(consumed)


func _assess_tick(owner: Dictionary, frame: Dictionary,
		requested: Dictionary, accepted: bool) -> void:
	var centre: Vector2 = owner.get("centre", Vector2.INF)
	var velocity: Vector2 = owner.get("velocity", Vector2.INF)
	var goal: Vector2 = active_goal()
	if not centre.is_finite() or not velocity.is_finite() or not goal.is_finite():
		_trace.append({"tick": _ticks, "world_tick": int(frame.get("world_tick", -1)),
			"physics_fault": true, "reason": "nonfinite_physical_state"})
		_fail("nonfinite_physical_state")
		return
	var distance: float = centre.distance_to(goal)
	var speed: float = velocity.length()
	var contact_count: int = arena.flight_contact_count(0)
	var contact: bool = contact_count > 0
	_contacts += int(contact)
	if distance > _last_distance + 4.0 and _last_distance < float(scenario.arrival_radius) * 2.0:
		_overshoot += 1
	# Evaluator-only reward. This value NEVER enters a policy observation or
	# the goal-blind stabilizer. Bound per-step progress and contact penalties.
	var progress: float = clampf((_last_distance - distance) / 16.0, -1.0, 1.0) * 0.30 \
		if is_finite(_last_distance) else 0.0
	_last_distance = distance
	_best_distance = minf(_best_distance, distance)
	var within: bool = distance <= float(scenario.arrival_radius) and speed <= float(scenario.speed_tolerance)
	_dwell = _dwell + 1 if within else 0
	var observed_dwell: int = _dwell
	if bool(frame.get("failed", false)):
		_fail("actual_host: " + str(frame.get("reason", "")))
	elif _dwell >= int(scenario.dwell_ticks):
		_waypoint += 1
		_dwell = 0
		_last_distance = INF
		if _waypoint >= scenario.goals.size():
			_success = true
			_terminal = true
			_reason = "low_speed_arrival_dwell"
	elif bool(frame.get("finished", false)):
		_terminal = true
		_truncated = bool(frame.get("truncated", false))
		_failed = bool(frame.get("failed", false))
		_reason = "deadline" if _truncated else str(frame.get("reason", "host_finished"))
	var bonus: float = 1.0 if _success and bool(scenario.get("navigation_credit", false)) else 0.0
	var physical_fault_penalty: float = -1.0 if bool(frame.get("failed", false)) else 0.0
	var terms: Dictionary = {
		"progress": progress, "contact": -0.02 if contact else 0.0,
		"time": -0.001, "low_speed_navigation_dwell": bonus,
		"physical_fault": physical_fault_penalty}
	var reward: float = 0.0
	for value: Variant in terms.values():
		reward += float(value)
	_step_reward += reward
	_episode_reward += reward
	_last_reward_terms = terms.duplicate(true)
	var flight: Dictionary = owner.get("flight", {})
	var received: Dictionary = flight.get("last_step", {}).duplicate(true)
	_trace.append({"tick": _ticks, "world_tick": int(frame.get("world_tick", -1)),
		"observation_id": str(owner.observation_id),
		"requested_action": requested.get("action", {}).duplicate(true) if not requested.is_empty() else {},
		"admitted": accepted if not requested.is_empty() else null,
		"authority": {"producer": str(owner.get("producer", "")),
			"control_generation": int(owner.get("control_generation", -1)),
			"command_live": bool(flight.get("command_live", false)),
			"lease_remaining_ticks": int(owner.get("lease_remaining", 0)),
			"actuator_mode": str(flight.get("mode", "unavailable")),
			"fallback_reason": str(flight.get("fallback_reason", ""))},
		"physical_receipt": received,
		"centre": centre, "velocity": velocity, "distance": distance,
		"dwell": observed_dwell, "contact": contact, "contact_count": contact_count,
		"physics_fault": bool(frame.get("failed", false)),
		"host_disturbance": _disturbance_receipt.duplicate(true),
		"reward": reward, "reward_terms": terms, "episode_terminal_tick": _terminal})

func _fail(reason: String) -> void:
	_terminal = true
	_failed = true
	_reason = reason
	last_error = reason
	if arena != null and arena.session != null:
		arena.cancel(0, &"human" if source == &"human" else &"policy")
		arena.set_paused(true)


func transition(consumed: int) -> Dictionary:
	var result: Dictionary = {
		"version": VERSION, "ticks_consumed": consumed, "physical_ticks_total": _ticks,
		"observation": observe(), "terminated": _terminal and not _truncated and not _failed,
		"truncated": _truncated, "failed": _failed, "reason": _reason,
		"success": _success, "navigation_credit": _success and bool(scenario.get("navigation_credit", false)),
		"reward": _step_reward if consumed > 0 else 0.0,
		"reward_terms_last_tick": _last_reward_terms.duplicate(true) if consumed > 0 else {},
		"episode_done": _terminal, "waypoint": _waypoint, "dwell_ticks": _dwell}
	return result.duplicate(true)


func metrics() -> Dictionary:
	var distance: float = _observation.get("goal_delta_cells", Vector2.INF).length()
	var speed: float = _observation.get("velocity_cells_per_second", Vector2.INF).length()
	return {"profile_id": str(profile_id), "scenario": str(scenario.get("id", "")),
		"split": str(scenario.get("split", "")), "seed": int(scenario.get("seed", -1)),
		"physical_ticks": _ticks, "decisions": _decisions,
		"elapsed_physical_seconds": float(_ticks) * FIXED_DELTA,
		"final_goal_error_cells": distance, "final_speed_cells_per_second": speed,
		"successful_dwell": _success, "best_error_cells": _best_distance,
		"overshoot_events": _overshoot, "contact_ticks": _contacts,
		"invalid_actions": _invalid_actions, "cumulative_evaluator_reward": _episode_reward,
		"terminated": _terminal and not _failed and not _truncated,
		"failed": _failed, "truncated": _truncated, "reason": _reason}


func manifest() -> Dictionary:
	return {"schema": VERSION, "observation": OBS_VERSION, "action": ACTION_VERSION,
		"flat_observation": Adapter.VERSION, "flat_observation_length": Adapter.LENGTH,
		"action_profile": Profile.ACTION_PROFILE, "source": str(source),
		"course_version": Course.VERSION, "split_geometry_version": Course.SPLIT_VERSION,
		"sealed_suite_sha256": scenario.get("sealed_suite_sha256", null),
		"course": str(scenario.get("id", "")),
		"seed": int(scenario.get("seed", -1)), "split": str(scenario.get("split", "")),
		"host_schedule": Arena.SCHEDULE, "physics_hz": Arena.PHYSICS_HZ,
		"decision_ticks": DECISION_TICKS, "lease_ticks": LEASE_TICKS,
		"profile_hash": Profile.profile_hash(Profile.entry(profile_id)),
		"controller_sha256": Controller.controller_hash(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"source_git_sha": OS.get_environment("GITHUB_SHA"),
		"teacher_source_sha256": FileAccess.get_file_as_string("res://scripts/physical_flight_teacher.gd").sha256_text() if source == &"teacher" else null,
		"runtime_hash_evidence": "CI regression identity.json contains the exact Git checkout, native and Rapier binary SHA-256; per-episode hashes are joined by independent readback",
		"native_coupling": true, "host_count": 1,
		"max_ticks": int(scenario.get("max_ticks", 0))}


func record() -> Dictionary:
	return {"manifest": manifest(), "metrics": metrics(), "trace": _trace.duplicate(true),
		"reset_microseconds": _reset_usec,
		"observation_serialization_microseconds": _serialize_usec,
		"process_wall_microseconds": Time.get_ticks_usec() - _start_usec}


func close() -> void:
	if arena != null:
		arena.close()
	_terminal = true
	_reason = "closed"
	_observation = {}
	_trace.clear()
