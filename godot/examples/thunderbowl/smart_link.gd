extends "res://examples/thunderbowl/controller_base.gd"

# Async adapter only. No model SDK, HTTP, image capture or inference is called
# by the motor/arena. Slow intentions are converted using each fresh local view.
const PLAN_TTL: int = 120
const REQUEST_INTERVAL: int = 30
var _pending: Dictionary = {}
var _goal: Dictionary = {}
var _goal_deadline: int = -1
var _latest_tick: int = 0
var _last_request_tick: int = -REQUEST_INTERVAL
var _request_sequence: int = 0
var accepted_results: int = 0
var rejected_results: int = 0


func _reset() -> void:
	_pending = {}
	_goal = {}
	_goal_deadline = -1
	_latest_tick = 0
	_last_request_tick = -REQUEST_INTERVAL
	_request_sequence = 0
	accepted_results = 0
	rejected_results = 0


func request(view: Dictionary) -> Dictionary:
	_begin(view)
	_latest_tick = int(view.tick)
	if not _pending.is_empty() and int(_pending.expires_tick) > _latest_tick:
		return {}
	if _latest_tick - _last_request_tick < REQUEST_INTERVAL:
		return {}
	_request_sequence += 1
	_last_request_tick = _latest_tick
	_pending = {"version": 1, "request_id": "%s:%d" % [view.observation_id, _request_sequence],
		"run_id": view.run_id, "actor_id": view.actor_id, "epoch": view.epoch,
		"observation_id": view.observation_id, "observed_tick": view.tick,
		"expires_tick": int(view.tick) + PLAN_TTL, "observation": view.duplicate(true)}
	return _pending.duplicate(true)


func submit_decision(response: Dictionary) -> bool:
	if not _valid_response(response):
		rejected_results += 1
		return false
	_goal = response.intent.duplicate(true)
	_goal_deadline = int(response.observed_tick) + int(response.valid_for_ticks)
	_pending = {}
	accepted_results += 1
	return true


func _valid_response(response: Dictionary) -> bool:
	if _pending.is_empty() or not Contract.exact_keys(response, ["version", "request_id", "run_id", "actor_id", "epoch",
		"observation_id", "observed_tick", "valid_for_ticks", "intent"]) \
		or not Contract.integer(response.version, 1, 1) \
		or not response.request_id is String or response.request_id.length() > 160 \
		or not response.run_id is String or response.run_id.length() > 64 \
		or not response.observation_id is String or response.observation_id.length() > 128 \
		or not Contract.integer(response.actor_id, 0, 7) \
		or not Contract.integer(response.epoch, 1, Contract.MAX_SEQUENCE) \
		or not Contract.integer(response.observed_tick, 0, 36000) \
		or not Contract.integer(response.valid_for_ticks, 1, PLAN_TTL):
		return false
	for key: String in ["request_id", "run_id", "actor_id", "epoch", "observation_id", "observed_tick"]:
		if response[key] != _pending[key]: return false
	if int(response.observed_tick) + int(response.valid_for_ticks) <= _latest_tick:
		return false
	var intent: Variant = response.intent
	return Contract.exact_keys(intent, ["mode", "goal", "speed", "engage"]) \
		and intent.mode is String \
		and ["hold", "move_to", "pursue_visible"].has(intent.mode) \
		and Contract.vector(intent.goal, 2, 0.0, 1024.0) \
		and Contract.number(intent.speed, 0.0, 1.0) and intent.engage is bool


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	_latest_tick = int(view.tick)
	if _goal.is_empty() or _goal_deadline <= _latest_tick:
		_goal = {}
		# Missing/expired model output cancels charged actions and coasts under
		# passive physics. It does not secretly brake, hover or pursue a target.
		return _packet(view, Contract.neutral_wire(), false, [], true)
	var enemy: Dictionary = _visible_enemy(view)
	var relative: Vector2 = Vector2(_goal.goal[0], _goal.goal[1]) - _self_centre(view)
	if _goal.mode == "hold" or float(_goal.speed) <= 0.0:
		return _packet(view, Contract.neutral_wire(), false, [], true)
	if _goal.mode == "pursue_visible":
		if enemy.is_empty(): return _packet(view, Contract.neutral_wire(), false, [], true)
		relative = Vector2(enemy.relative_position[0], enemy.relative_position[1])
	var action: Dictionary = _wire_toward(view, relative, _goal.speed)
	# Normalized demand scales the movement axes as well as rig effort. SetA
	# ignores effort, so an effort-only speed mapping would be misleading.
	action.movement[0] *= float(_goal.speed)
	action.movement[1] *= float(_goal.speed)
	var fire: bool = false
	if _goal.engage and not enemy.is_empty():
		var aim: Vector2 = Vector2(enemy.relative_position[0], enemy.relative_position[1])
		action.aim = Contract.normalized([aim.x, aim.y])
		fire = _shot(view, aim)
	return _packet(view, action, fire)
