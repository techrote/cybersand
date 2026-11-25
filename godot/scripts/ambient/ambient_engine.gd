extends RefCounted

# Pure procedural decision engine. Authoring remains immutable; all timers,
# random streams and latches belong to this one actor incarnation. It cannot
# call a World, move a body, submit a lease or inspect a scene tree.
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
const Memory = preload("res://scripts/ambient/ambient_memory.gd")
const VERSION := "ambient-engine/v2"
const OBSERVATION_VERSION := "ambient-observation/v1"
const INTENT_VERSION := "ambient-intent/v1"

var _profile: Dictionary = {}
var _context: Dictionary = {}
var _states: Dictionary = {}
var _effective_modules: Dictionary = {}
var _specs: Dictionary = {}
var _elapsed: float = 0.0
var _last_tick: int = -1
var _last_clock: float = -1.0
var _decisions: int = 0
var _last_intent: Dictionary = {}
var _last_steering_id: String = ""
var _reset_reason: String = "unconfigured"
var _identity: Dictionary = {}
var _memory = Memory.new()
var _personality: Dictionary = {}
var _drives: Dictionary = {}
var _world_generation: int = -1
var _goal_id: String = ""
var _goal_key: String = ""
var _goal_until: float = 0.0
var _recent: Array = []
var _last_position := Vector2.ZERO
var _has_position: bool = false


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


static func _stable_seed(seed: int, actor_id: int, module_id: String) -> int:
	# Hash distinct fields rather than XORing seed and actor identity: correlated
	# user seeds (seed == actor ID) must not cancel into synchronized streams.
	var text: String = "%d:%d:%s" % [seed,actor_id,module_id]
	var result: int = 2166136261 & 0x7fffffff
	for index: int in text.length():
		result = ((result ^ text.unicode_at(index)) * 16777619) & 0x7fffffff
	return result


func configure(profile: Dictionary, context: Dictionary) -> Dictionary:
	var capabilities: Variant = context.get("capabilities")
	var origin: Variant = context.get("home")
	if not capabilities is Dictionary or not bool(capabilities.get("supported",false)):
		return {"ok":false,"error":"Explicit supported locomotion capabilities are required."}
	for capability: String in ["horizontal","vertical","ground","jump"]:
		if not capabilities.get(capability) is bool:
			return {"ok":false,"error":"Locomotion capability flags must be explicit booleans."}
	if not origin is Vector2 or not origin.is_finite(): return {"ok":false,"error":"Finite authored home is required."}
	if not _integer(context.get("actor_id")) or int(context.actor_id) < 0:
		return {"ok":false,"error":"Stable nonnegative authored actor identity is required."}
	var error: String = Profile.validate(profile,[],capabilities)
	if not error.is_empty(): return {"ok":false,"error":error}
	var canonical: Dictionary = Profile.canonicalize(profile)
	if canonical.is_empty(): return {"ok":false,"error":"Profile canonicalization refused."}
	# Commit only after every check: invalid edits preserve the usable producer.
	_profile = canonical
	_context = {"actor_id":int(context.actor_id),"home":origin,"spawn_home":origin,
		"capabilities":capabilities.duplicate(true),"regions":_profile.get("regions",[]).duplicate(true),
		"relations":_profile.get("relations",{}).duplicate(true)}
	for region: Dictionary in _profile.get("regions",[]):
		if str(region.kind) == "home":
			_context.home = Vector2(float(region.x) + float(region.width) * 0.5,float(region.y) + float(region.height) * 0.5)
	_specs = Modules.module_specs()
	reset("profile_applied")
	return {"ok":true,"error":"","profile_id":str(_profile.id),"actor_id":int(_context.actor_id)}


func reset(reason: String = "explicit_reset") -> void:
	_states.clear()
	_effective_modules.clear()
	_identity.clear()
	_elapsed = 0.0
	_last_tick = -1
	_last_clock = -1.0
	_decisions = 0
	_last_steering_id = ""
	_reset_reason = reason
	_last_intent = {}
	_goal_id = ""
	_goal_key = ""
	_goal_until = 0.0
	_recent.clear()
	_world_generation = -1
	_has_position = false
	_personality = Profile.personality_defaults()
	var authored_traits: Dictionary = _profile.get("personality",{})
	if bool(authored_traits.get("enabled",false)): _personality = authored_traits.duplicate(true)
	else: _personality.enabled = false
	_drives = {"exploration":0.85,"social":0.45}
	_memory.configure(_profile.get("memory",{"enabled":false}))
	if _profile.is_empty(): return
	var actor_seed: int = 0 if bool(_profile.shared_seed) else int(_context.actor_id)
	for module: Dictionary in _profile.modules:
		_states[str(module.id)] = {"rng":_stable_seed(int(_profile.seed),actor_seed,str(module.id))}
		_effective_modules[str(module.id)] = _effective_module(module)


func _neutral(reason: String, available: bool = false) -> Dictionary:
	return {"version":INTENT_VERSION,"available":available,"direction":Vector2.ZERO,
		"pace":0.0,"effort":0.0,"primary":false,"reason":reason,"active_override":"",
		"active_modules":[],"candidates":[],"elapsed_seconds":_elapsed,"remaining_seconds":0.0,
		"decision":_decisions,"observed_tick":_last_tick,"selected_module":"","selected_goal":"",
		"goal_phase":"","goal_key":"","goal_target":Vector2.ZERO,"phase_selected_seconds":0.0,
		"commitment_remaining_seconds":0.0}


func _observation_error(observation: Dictionary, delta: float, world_changed: bool = false) -> String:
	if _profile.is_empty(): return "ambient engine is unconfigured"
	if str(observation.get("version","")) != OBSERVATION_VERSION: return "unsupported environment observation"
	if not bool(observation.get("available",false)): return "environment observation unavailable"
	if bool(observation.get("suspended",false)): return "ambient actor is suspended"
	if not is_finite(delta) or delta < 0.0 or not is_finite(_elapsed + delta): return "invalid simulation progression delta"
	var position: Variant = observation.get("position")
	var velocity: Variant = observation.get("velocity")
	if not position is Vector2 or not velocity is Vector2 or not position.is_finite() or not velocity.is_finite():
		return "finite copied pose and velocity required"
	if not _integer(observation.get("tick")) or int(observation.tick) < 0: return "invalid physical sampling tick"
	if not world_changed and int(observation.tick) < _last_tick: return "physical sampling tick regressed; explicit reset required"
	if _integer(observation.get("world_generation")) and int(observation.world_generation) >= 0 \
		and _world_generation >= 0 and int(observation.world_generation) < _world_generation:
		return "World generation regressed; older observations cannot restore knowledge"
	if not _integer(observation.get("instance_id")) or int(observation.instance_id) != int(_context.actor_id):
		return "authored actor identity mismatch"
	if not observation.get("run_id") is String or str(observation.run_id).is_empty() \
		or not _integer(observation.get("epoch")) or int(observation.epoch) < 0 \
		or not _integer(observation.get("actor_id")) or int(observation.actor_id) < 0:
		return "source-bound run, epoch and physical slot are required"
	for field: String in _identity:
		if observation.get(field) != _identity[field]: return "actor incarnation changed; explicit reset required"
	if observation.has("simulation_time_seconds"):
		var value: Variant = observation.simulation_time_seconds
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
			return "invalid explicit simulation clock"
		if not world_changed and _last_clock >= 0.0 and absf((float(value) - _last_clock) - delta) > 0.000001:
			return "simulation clock and supplied progression disagree"
	return ""


func step(observation: Dictionary, delta_seconds: float) -> Dictionary:
	# Validate every copied field before committing a World transition. A
	# malformed newer-generation sample cannot erase valid state or clock fences.
	var world_changed: bool = _integer(observation.get("world_generation")) \
		and _world_generation >= 0 and int(observation.world_generation) > _world_generation
	var error: String = _observation_error(observation,delta_seconds,world_changed)
	if not error.is_empty(): return _neutral(error)
	if world_changed: reset("World generation changed")
	var observed_tick: int = int(observation.tick)
	if observed_tick == _last_tick:
		if delta_seconds > 0.0: return _neutral("duplicate sampling tick cannot advance gameplay time")
		# Inspection, repaint or an unchanged pause/resume sample must not draw
		# randomness or consume timers. The owner still obtains a fresh lease.
		return _last_intent.duplicate(true)
	if _identity.is_empty():
		_identity = {"run_id":observation.run_id,"epoch":observation.epoch,"actor_id":observation.actor_id}
	_elapsed += delta_seconds
	if _integer(observation.get("world_generation")) and int(observation.world_generation) >= 0:
		_world_generation = int(observation.world_generation)
	_last_tick = observed_tick
	if observation.has("simulation_time_seconds"): _last_clock = float(observation.simulation_time_seconds)
	_decisions += 1
	var context: Dictionary = _context.duplicate(true)
	context.profile_version = int(_profile.version)
	context.last_selected_module = str(_last_intent.get("selected_module",""))
	context.last_goal_phase = str(_last_intent.get("goal_phase",""))
	context.last_goal_key = str(_last_intent.get("goal_key",""))
	context.last_direction = _last_intent.get("direction",Vector2.RIGHT)
	context.last_pace = float(_last_intent.get("pace",0.0))
	# Missing decisions cannot prove continuous support/contact. Persistent
	# intentions still expire in actual simulation time, not wall time.
	context.observation_gap = delta_seconds > 0.25
	context.continuity_delta = 0.0 if context.observation_gap else delta_seconds
	_update_drives(observation,delta_seconds)
	_memory.advance(observation,_elapsed,delta_seconds,_last_intent)
	context.personality = _personality.duplicate(true)
	context.drives = _drives.duplicate(true)
	context.memory = _memory.snapshot()
	context.selected_goal = _goal_id
	var candidates: Array = []
	for module: Dictionary in _profile.modules:
		var candidate: Dictionary
		if not bool(module.enabled): candidate = {"active":false,"reason":"disabled"}
		elif float(module.weight) <= 0.0: candidate = {"active":false,"reason":"zero module weight"}
		else:
			var effective: Dictionary = _effective_modules[str(module.id)]
			candidate = Modules.evaluate(effective,observation,_states[str(module.id)],_elapsed,delta_seconds,context)
			if int(_profile.version) >= 2 and str(candidate.get("mode","steer")) != "override":
				candidate.pace = clampf(float(candidate.get("pace",0.0)) * (0.6 + 0.8 * float(_personality.activity)),0.0,1.0)
			if int(_profile.version) >= 2 and str(module.type) == "follow_actor":
				candidate.strength = float(candidate.get("strength",1.0)) * (0.2 + 1.6 * float(_personality.sociability))
		candidate["id"] = str(module.id)
		candidate["type"] = str(module.type)
		candidate["priority"] = int(module.priority)
		candidate["weight"] = float(module.weight)
		candidate["score"] = float(module.weight) * float(candidate.get("strength",1.0)) if bool(candidate.get("active",false)) else 0.0
		candidates.append(candidate)
	_last_intent = _arbitrate(candidates)
	_record_decision(_last_intent)
	return _last_intent.duplicate(true)


func _arbitrate(candidates: Array) -> Dictionary:
	var result := _neutral("no applicable modules",true)
	result.candidates = candidates.duplicate(true)
	result.observed_tick = _last_tick
	result.decision = _decisions
	var overrides: Array = []
	var steering: Array = []
	var goals: Array = []
	var selected_goal: Dictionary = {}
	for candidate: Dictionary in candidates:
		if not bool(candidate.get("active",false)): continue
		result.active_modules.append(str(candidate.id))
		if str(candidate.get("mode","steer")) == "override": overrides.append(candidate)
		elif str(candidate.get("mode","steer")) == "goal": goals.append(candidate)
		else: steering.append(candidate)
	if not overrides.is_empty():
		# Authored order breaks equal priority ties. Reordering modules is an
		# explicit authored change, never an inspector-driven random event.
		var chosen: Dictionary = overrides[0]
		for candidate: Dictionary in overrides:
			if int(candidate.priority) > int(chosen.priority): chosen = candidate
		result.direction = chosen.get("direction",Vector2.ZERO)
		result.pace = float(chosen.get("pace",0.0)) if result.direction != Vector2.ZERO else 0.0
		result.effort = float(chosen.get("effort",0.0))
		result.primary = bool(chosen.get("primary",false))
		result.reason = str(chosen.reason)
		result.active_override = str(chosen.id)
		result.selected_module = str(chosen.id)
		result.remaining_seconds = maxf(0.0,float(chosen.get("remaining_seconds",0.0)))
		return result
	if not goals.is_empty():
		selected_goal = _select_goal(goals)
		result.selected_goal = str(selected_goal.id)
		result.selected_module = str(selected_goal.id)
		result.goal_phase = str(selected_goal.get("phase","approach"))
		result.goal_key = str(selected_goal.get("goal_key",""))
		result.phase_selected_seconds = float(selected_goal.get("phase_selected_seconds",0.0))
		result.goal_target = selected_goal.get("target",Vector2.ZERO)
		result.commitment_remaining_seconds = maxf(0.0,_goal_until - _elapsed)
		result.remaining_seconds = float(selected_goal.get("remaining_seconds",0.0))
		if bool(selected_goal.get("hold",false)):
			result.reason = str(selected_goal.reason)
			return result
		var influence: Dictionary = selected_goal.duplicate(true)
		influence.score = float(influence.score) * 2.5
		steering.append(influence)
	else:
		_goal_id = ""
		_goal_key = ""
		_goal_until = 0.0
	if steering.is_empty(): return result
	var combined := Vector2.ZERO
	var total_weight: float = 0.0
	var effort_sum: float = 0.0
	var dominant: Dictionary = {}
	var retained: Dictionary = {}
	for candidate: Dictionary in steering:
		var score: float = float(candidate.score)
		var direction: Vector2 = candidate.get("direction",Vector2.ZERO)
		combined += direction * float(candidate.get("pace",0.0)) * score
		total_weight += score
		effort_sum += float(candidate.get("effort",0.0)) * score
		if direction == Vector2.ZERO: continue
		if dominant.is_empty() or score > float(dominant.score) \
			or (is_equal_approx(score,float(dominant.score)) and int(candidate.priority) > int(dominant.priority)):
			dominant = candidate
		if str(candidate.id) == _last_steering_id: retained = candidate
	if total_weight <= 0.0: return result
	combined /= total_weight
	if combined.length() < 0.04 and not dominant.is_empty():
		# Close cancellation chooses a stable dominant preference. A prior
		# winner within 10% retains the tie, avoiding numerical sign chatter.
		if not retained.is_empty() and float(retained.score) >= float(dominant.score) * 0.9: dominant = retained
		combined = (dominant.direction as Vector2) * float(dominant.get("pace",0.0))
		result.reason = "stable dominant steering after near cancellation"
		_last_steering_id = str(dominant.id)
	else:
		result.reason = "weighted local steering" if combined != Vector2.ZERO else "intentional idle"
		if not dominant.is_empty(): _last_steering_id = str(dominant.id)
	result.direction = combined.normalized() if combined.length_squared() > 0.000001 else Vector2.ZERO
	result.pace = clampf(combined.length(),0.0,1.0)
	result.effort = clampf(effort_sum / total_weight,0.0,1.0)
	if not selected_goal.is_empty(): result.reason = str(selected_goal.reason)
	elif not dominant.is_empty(): result.selected_module = str(dominant.id)
	return result


func _effective_module(module: Dictionary) -> Dictionary:
	if int(_profile.version) < 2 or not bool(_personality.get("enabled",false)): return module
	var result: Dictionary = module.duplicate(true)
	if str(result.type) == "avoid_material":
		result.params.enter_distance = minf(float(result.params.exit_distance),
			float(result.params.enter_distance) * (0.7 + 0.6 * float(_personality.caution)))
	elif str(result.type) == "wander":
		result.params.idle_probability = clampf(float(result.params.idle_probability) * (1.5 - float(_personality.activity)),0.0,1.0)
	return result


func _rest_recharge_radius() -> float:
	# Recharge the completed interval of the actually selected home-rest instance.
	# Other candidates cannot lend it a larger arrival region; ordinary neutral
	# behavior keeps its existing radius. Current geometry is checked by the caller.
	var selected: String = str(_last_intent.get("selected_module",""))
	if selected.is_empty() or str(_last_intent.get("selected_goal","")) != selected \
		or str(_last_intent.get("goal_phase","")) != "home_rest" \
		or not str(_last_intent.get("active_override","")).is_empty():
		return 16.0
	var module: Dictionary = _effective_modules.get(selected,{})
	if str(module.get("type","")) != "seek_home_drive" \
		or not bool(module.get("enabled",false)) or float(module.get("weight",0.0)) <= 0.0:
		return 16.0
	return float(module.params.arrival_radius)


func _update_drives(observation: Dictionary, delta: float) -> void:
	if int(_profile.version) < 2: return
	if not bool(_profile.get("drives_enabled",true)):
		_drives = {"exploration":0.65,"social":0.5}
		_last_position = observation.position
		_has_position = true
		return
	var home_delta: Vector2 = observation.position - _context.home
	if not bool(_context.capabilities.get("vertical",false)): home_delta.y = 0.0
	var at_home: bool = home_delta.length() <= _rest_recharge_radius()
	var moving: bool = _has_position and delta > 0.0 and delta <= 0.25 \
		and (observation.position as Vector2).distance_to(_last_position) / delta > 1.0
	var restful: bool = float(_last_intent.get("pace",0.0)) <= 0.05 \
		or str(_last_intent.get("goal_phase","")) == "home_rest"
	if at_home and restful:
		_drives.exploration = clampf(float(_drives.exploration) + delta * 0.09,0.0,1.0)
	else:
		var depletion: float = 0.006 + float(_personality.activity) * 0.018
		_drives.exploration = clampf(float(_drives.exploration) - delta * depletion * (1.0 if moving else 0.35),0.0,1.0)
	var near_peer: bool = false
	var peers: Variant = observation.get("neighbors",{}).get("actors",[])
	if bool(observation.get("neighbors",{}).get("available",false)) and peers is Array:
		for index: int in mini(31,peers.size()):
			var peer: Variant = peers[index]
			if not peer is Dictionary or not bool(peer.get("compatible",false)) or float(peer.get("affinity",0.0)) < 0.0: continue
			var position: Variant = peer.get("position")
			if position is Vector2 and position.is_finite() and (observation.position as Vector2).distance_to(position) <= float(_personality.preferred_distance) * 2.0:
				near_peer = true
				break
	_drives.social = clampf(float(_drives.social) + delta * (-0.06 if near_peer else 0.005 + float(_personality.sociability) * 0.01),0.0,1.0)
	_last_position = observation.position
	_has_position = true


func _select_goal(goals: Array) -> Dictionary:
	var selected: Dictionary = goals[0]
	var retained: Dictionary = {}
	for candidate: Dictionary in goals:
		if float(candidate.score) > float(selected.score) or (is_equal_approx(float(candidate.score),float(selected.score)) \
			and int(candidate.priority) > int(selected.priority)):
			selected = candidate
		if str(candidate.id) == _goal_id and str(candidate.get("goal_key","")) == _goal_key: retained = candidate
	if not retained.is_empty() and _elapsed < _goal_until:
		var margin: float = 1.25 + 0.75 * float(_personality.get("persistence",0.5))
		if float(retained.score) * margin >= float(selected.score): selected = retained
	var key: String = str(selected.get("goal_key",""))
	if str(selected.id) != _goal_id or key != _goal_key:
		_goal_id = str(selected.id)
		_goal_key = key
		_goal_until = _elapsed + clampf(float(selected.get("commit_seconds",3.0)) * (0.5 + float(_personality.get("persistence",0.5))),0.05,45.0)
	return selected


func _record_decision(intent: Dictionary) -> void:
	var selected: String = str(intent.get("selected_module",""))
	var phase: String = str(intent.get("goal_phase",""))
	if not _recent.is_empty() and str(_recent[-1].selected) == selected and str(_recent[-1].phase) == phase: return
	_recent.append({"time":_elapsed,"selected":selected,"reason":str(intent.reason),"phase":phase,
		"target":intent.get("goal_target",Vector2.ZERO)})
	if _recent.size() > 32: _recent.pop_front()


func diagnostics() -> Dictionary:
	return {"engine":VERSION,"profile_id":str(_profile.get("id","")),
		"actor_id":int(_context.get("actor_id",-1)),"identity":_identity.duplicate(true),"decisions":_decisions,
		"elapsed_seconds":_elapsed,"last_observed_tick":_last_tick,"reset_reason":_reset_reason,
		"intent":_last_intent.duplicate(true),"module_state":_states.duplicate(true),
		"seed":int(_profile.get("seed",0)),"shared_seed":bool(_profile.get("shared_seed",false)),
		"world_generation":_world_generation,"memory":_memory.snapshot(),
		"personality":_personality.duplicate(true),"drives":_drives.duplicate(true),
		"drives_enabled":bool(_profile.get("drives_enabled",false)),
		"recent_decisions":_recent.duplicate(true),"effective_home":_context.get("home",Vector2.ZERO),
		"authored_regions":_profile.get("regions",[]).duplicate(true),
		"clock":"explicit completed physical progression; pause consumes no time",
		"determinism":"same admitted profile, actor identity and copied observation stream only"}
