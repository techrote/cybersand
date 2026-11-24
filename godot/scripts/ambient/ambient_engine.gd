extends RefCounted

# Pure procedural decision engine. Authoring remains immutable; all timers,
# random streams and latches belong to this one actor incarnation. It cannot
# call a World, move a body, submit a lease or inspect a scene tree.
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
const VERSION := "ambient-engine/v1"
const OBSERVATION_VERSION := "ambient-observation/v1"
const INTENT_VERSION := "ambient-intent/v1"

var _profile: Dictionary = {}
var _context: Dictionary = {}
var _states: Dictionary = {}
var _specs: Dictionary = {}
var _elapsed: float = 0.0
var _last_tick: int = -1
var _last_clock: float = -1.0
var _decisions: int = 0
var _last_intent: Dictionary = {}
var _last_steering_id: String = ""
var _reset_reason: String = "unconfigured"
var _identity: Dictionary = {}


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
	_context = {"actor_id":int(context.actor_id),"home":origin,"capabilities":capabilities.duplicate(true)}
	_specs = Modules.module_specs()
	reset("profile_applied")
	return {"ok":true,"error":"","profile_id":str(_profile.id),"actor_id":int(_context.actor_id)}


func reset(reason: String = "explicit_reset") -> void:
	_states.clear()
	_identity.clear()
	_elapsed = 0.0
	_last_tick = -1
	_last_clock = -1.0
	_decisions = 0
	_last_steering_id = ""
	_reset_reason = reason
	_last_intent = {}
	if _profile.is_empty(): return
	var actor_seed: int = 0 if bool(_profile.shared_seed) else int(_context.actor_id)
	for module: Dictionary in _profile.modules:
		_states[str(module.id)] = {"rng":_stable_seed(int(_profile.seed),actor_seed,str(module.id))}


func _neutral(reason: String, available: bool = false) -> Dictionary:
	return {"version":INTENT_VERSION,"available":available,"direction":Vector2.ZERO,
		"pace":0.0,"effort":0.0,"primary":false,"reason":reason,"active_override":"",
		"active_modules":[],"candidates":[],"elapsed_seconds":_elapsed,"remaining_seconds":0.0,
		"decision":_decisions,"observed_tick":_last_tick}


func _observation_error(observation: Dictionary, delta: float) -> String:
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
	if int(observation.tick) < _last_tick: return "physical sampling tick regressed; explicit reset required"
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
		if _last_clock >= 0.0 and absf((float(value) - _last_clock) - delta) > 0.000001:
			return "simulation clock and supplied progression disagree"
	return ""


func step(observation: Dictionary, delta_seconds: float) -> Dictionary:
	var error: String = _observation_error(observation,delta_seconds)
	if not error.is_empty(): return _neutral(error)
	var observed_tick: int = int(observation.tick)
	if observed_tick == _last_tick:
		if delta_seconds > 0.0: return _neutral("duplicate sampling tick cannot advance gameplay time")
		# Inspection, repaint or an unchanged pause/resume sample must not draw
		# randomness or consume timers. The owner still obtains a fresh lease.
		return _last_intent.duplicate(true)
	if _identity.is_empty():
		_identity = {"run_id":observation.run_id,"epoch":observation.epoch,"actor_id":observation.actor_id}
	_elapsed += delta_seconds
	_last_tick = observed_tick
	if observation.has("simulation_time_seconds"): _last_clock = float(observation.simulation_time_seconds)
	_decisions += 1
	var context: Dictionary = _context.duplicate(true)
	context.last_direction = _last_intent.get("direction",Vector2.RIGHT)
	context.last_pace = float(_last_intent.get("pace",0.0))
	# Missing decisions cannot prove continuous support/contact. Persistent
	# intentions still expire in actual simulation time, not wall time.
	context.observation_gap = delta_seconds > 0.25
	context.continuity_delta = 0.0 if context.observation_gap else delta_seconds
	var candidates: Array = []
	for module: Dictionary in _profile.modules:
		var candidate: Dictionary
		if not bool(module.enabled): candidate = {"active":false,"reason":"disabled"}
		elif float(module.weight) <= 0.0: candidate = {"active":false,"reason":"zero module weight"}
		else:
			candidate = Modules.evaluate(module,observation,_states[str(module.id)],_elapsed,delta_seconds,context)
		candidate["id"] = str(module.id)
		candidate["type"] = str(module.type)
		candidate["priority"] = int(module.priority)
		candidate["weight"] = float(module.weight)
		candidate["score"] = float(module.weight) * float(candidate.get("strength",1.0)) if bool(candidate.get("active",false)) else 0.0
		candidates.append(candidate)
	_last_intent = _arbitrate(candidates)
	return _last_intent.duplicate(true)


func _arbitrate(candidates: Array) -> Dictionary:
	var result := _neutral("no applicable modules",true)
	result.candidates = candidates.duplicate(true)
	result.observed_tick = _last_tick
	result.decision = _decisions
	var overrides: Array = []
	var steering: Array = []
	for candidate: Dictionary in candidates:
		if not bool(candidate.get("active",false)): continue
		result.active_modules.append(str(candidate.id))
		if str(candidate.get("mode","steer")) == "override": overrides.append(candidate)
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
		result.remaining_seconds = maxf(0.0,float(chosen.get("remaining_seconds",0.0)))
		return result
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
	return result


func diagnostics() -> Dictionary:
	return {"engine":VERSION,"profile_id":str(_profile.get("id","")),
		"actor_id":int(_context.get("actor_id",-1)),"identity":_identity.duplicate(true),"decisions":_decisions,
		"elapsed_seconds":_elapsed,"last_observed_tick":_last_tick,"reset_reason":_reset_reason,
		"intent":_last_intent.duplicate(true),"module_state":_states.duplicate(true),
		"seed":int(_profile.get("seed",0)),"shared_seed":bool(_profile.get("shared_seed",false)),
		"clock":"explicit completed physical progression; pause consumes no time",
		"determinism":"same admitted profile, actor identity and copied observation stream only"}
