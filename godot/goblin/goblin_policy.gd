extends RefCounted

# Proposes only bounded in-game actions. It never infers native progress,
# decides action success, reads a file, or performs an application operation.
# The adapter remains the range/capability authority; the independent oracle
# judges the returned application observations.
const PERSONALITIES := ["CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM"]
const MATERIALS := [2, 3, 7, 58]
const HISTORY_LIMIT := 64
const WAYPOINTS := [[64, 60], [224, 80], [128, 160], [336, 144]]

var goal := "Waiting for a campaign"
var personality := "CONTROL"
var campaign_seed := 0
var _rng := RandomNumberGenerator.new()
var _configured := false
var _queue: Array[Dictionary] = []
var _goal_number := 0
var _emitted := 0
var _observed := 0
var _skipped := 0
var _last_observed_id := ""
var _action_counts: Dictionary = {}
var _pair_counts: Dictionary = {}
var _transition_counts: Dictionary = {}
var _status_counts: Dictionary = {}
var _recent: Array[Dictionary] = []


func configure(name: String, seed_value: int) -> bool:
	personality = name.to_upper()
	campaign_seed = seed_value
	_rng.seed = seed_value
	_queue.clear()
	_goal_number = 0
	_emitted = 0
	_observed = 0
	_skipped = 0
	_last_observed_id = ""
	_action_counts.clear()
	_pair_counts.clear()
	_transition_counts.clear()
	_status_counts.clear()
	_recent.clear()
	_configured = personality in PERSONALITIES and seed_value >= -2147483648 and seed_value <= 2147483647
	goal = "Ready to explore" if _configured else "Unsupported personality or seed"
	return _configured


func next_action(observation: Dictionary, legal_actions: Array) -> Dictionary:
	if not _configured or legal_actions.is_empty():
		goal = "No applicable in-game action"
		return {}
	if personality == "RANDOM":
		goal = "Try one seeded legal action"
		return _emit(legal_actions[_rng.randi_range(0, legal_actions.size() - 1)])
	# A goal keeps its remaining steps between calls. Availability is refreshed
	# before each proposal, so an unavailable history/actor feature is skipped
	# instead of being reported as an application defect.
	for _attempt: int in range(96):
		if _queue.is_empty():
			_make_goal(observation, legal_actions)
		if _queue.is_empty():
			break
		var candidate: Dictionary = _queue.pop_front()
		if _has_id(legal_actions, str(candidate.id)) and _observed_preconditions(candidate, observation):
			return _emit(candidate)
		_skipped += 1
	goal = "Inspect an available control"
	return _emit(legal_actions[_rng.randi_range(0, legal_actions.size() - 1)])


func observe_result(record: Dictionary) -> void:
	# These are adapter-reported outcomes, not policy verdicts. Keep refused,
	# partial and timed-out operations in the same observation history.
	var action: Dictionary = record.get("action", record.get("proposed", {}))
	var action_id := str(action.get("id", ""))
	if action_id.is_empty():
		return
	var receipt: Dictionary = record.get("receipt", {})
	var status := str(record.get("status", receipt.get("status", "unreported")))
	var before: Dictionary = record.get("before", {})
	var after: Dictionary = record.get("after", record.get("observation", {}))
	var pair := _last_observed_id + ">" + action_id
	var transition := _state_key(before) + ">" + action_id + ">" + _state_key(after)
	_action_counts[action_id] = int(_action_counts.get(action_id, 0)) + 1
	_pair_counts[pair] = int(_pair_counts.get(pair, 0)) + 1
	_transition_counts[transition] = int(_transition_counts.get(transition, 0)) + 1
	_status_counts[status] = int(_status_counts.get(status, 0)) + 1
	_recent.append({"id":action_id, "status":status, "transition":transition})
	if _recent.size() > HISTORY_LIMIT:
		_recent.pop_front()
	_last_observed_id = action_id
	_observed += 1


func summary() -> Dictionary:
	return {"personality":personality, "seed":campaign_seed, "goal":goal,
		"goals_started":_goal_number, "actions_proposed":_emitted, "actions_observed":_observed,
		"unavailable_goal_steps_skipped":_skipped, "observed_action_counts":_action_counts.duplicate(true),
		"observed_status_counts":_status_counts.duplicate(true), "distinct_observed_pairs":_pair_counts.size(),
		"distinct_observed_transitions":_transition_counts.size(), "recent_observations":_recent.duplicate(true)}


func _emit(action: Dictionary) -> Dictionary:
	var result := {"id":str(action.get("id", "")), "args":Dictionary(action.get("args", {})).duplicate(true), "goal":goal}
	_emitted += 1
	return result


func _has_id(menu: Array, action_id: String) -> bool:
	for item: Dictionary in menu:
		if str(item.get("id", "")) == action_id:
			return true
	return false


func _observed_preconditions(action: Dictionary, observation: Dictionary) -> bool:
	# A queued goal may mention the actor a preceding Place hoped to create.
	# Only a subsequent real observation can make that ID selectable/pilotable.
	if action.id == "actor_select":
		return int(action.args.actor_id) in observation.get("actor_ids", [])
	if action.id == "actor_pilot":
		return int(action.args.actor_id) in _actor_ids(observation)
	return true


func _step(action_id: String, arguments: Dictionary = {}) -> void:
	_queue.append({"id":action_id, "args":arguments.duplicate(true)})


func _box(action_id: String, x0: int, y0: int, x1: int, y1: int) -> void:
	_step(action_id, {"x0":x0, "y0":y0, "x1":x1, "y1":y1})


func _make_goal(observation: Dictionary, legal_actions: Array) -> void:
	_goal_number += 1
	match personality:
		"CONTROL": _control_goal(observation)
		"WANDERER": _wanderer_goal(observation)
		"BUILDER": _builder_goal(observation)
		"TINKERER": _tinkerer_goal(observation)
		"CURIOSITY": _curiosity_goal(observation, legal_actions)


func _control_goal(observation: Dictionary) -> void:
	goal = "Rehearse paint, copy, history, persistence and real Play"
	_step("pause")
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_step("select_material", {"material":58})
	_box("rectangle", 32, 32, 39, 39)
	_step("select_material", {"material":7})
	_step("brush", {"x":48, "y":40, "radius":2})
	_box("select_region", 32, 32, 39, 39)
	_step("copy")
	_step("paste", {"x":64, "y":32})
	_step("undo")
	_step("redo")
	_step("select_material", {"material":58})
	_box("outline", 96, 40, 111, 55)
	_box("select_region", 96, 40, 111, 55)
	_step("select_material", {"material":3})
	_step("fill", {"x":104, "y":48})
	_step("save_layout")
	_step("reopen_layout")
	_step("camera", {"x":24, "y":16, "width":240, "height":135})
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_step("panel", {"panel":"details", "open":true})
	_step("panel", {"panel":"details", "open":false})
	var actors: Array = _actor_ids(observation)
	if actors.is_empty() and _next_actor_id(observation) > 0:
		_step("actor_place", {"model":"kestrel", "x":224, "y":128})
		actors.append(_next_actor_id(observation))
	if not actors.is_empty():
		_step("actor_select", {"actor_id":int(actors[0])})
		_step("actor_pilot", {"actor_id":int(actors[0])})
	_step("play", {"ticks":8})
	if not actors.is_empty():
		_step("actor_drive", {"direction":"right", "ticks":6})
	_step("wait_ticks", {"ticks":8})
	_step("pause")
	_step("single_step")
	if not actors.is_empty():
		_step("actor_reset")


func _wanderer_goal(observation: Dictionary) -> void:
	var waypoint: Array = WAYPOINTS[(_goal_number - 1) % WAYPOINTS.size()]
	var x := int(waypoint[0])
	var y := int(waypoint[1])
	goal = "Visit (%d, %d), leave a little trail, then watch it" % [x, y]
	_step("pause")
	_step("camera", {"x":clampi(x - 60, 0, 256), "y":clampi(y - 45, 0, 256), "width":240, "height":135})
	_step("select_material", {"material":MATERIALS[_rng.randi_range(0, MATERIALS.size() - 1)]})
	for offset: int in [0, 7, 14]:
		_step("brush", {"x":x + offset, "y":y + _rng.randi_range(-3, 3), "radius":1})
	var actors: Array = _actor_ids(observation)
	if actors.is_empty() and _next_actor_id(observation) > 0:
		_step("actor_place", {"model":"kestrel", "x":x + 20, "y":y + 20})
		actors.append(_next_actor_id(observation))
	if not actors.is_empty():
		_step("actor_select", {"actor_id":int(actors[(_goal_number - 1) % actors.size()])})
		_step("actor_pilot", {"actor_id":int(actors[(_goal_number - 1) % actors.size()])})
	_step("play", {"ticks":6})
	if not actors.is_empty():
		_step("actor_drive", {"direction":"right" if _goal_number % 2 else "left", "ticks":8})
	_step("wait_ticks", {"ticks":6})
	_step("pause")


func _builder_goal(observation: Dictionary) -> void:
	var x := 40 + ((_goal_number - 1) % 5) * 72
	var y := 72 + (floori(float(_goal_number - 1) / 5.0) % 3) * 48
	goal = "Build cup %d, add Sand, then remove its Wood ledge" % _goal_number
	_step("pause")
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_step("select_material", {"material":58})
	_box("rectangle", x, y + 26, x + 31, y + 29)
	_box("rectangle", x, y, x + 2, y + 25)
	_box("rectangle", x + 29, y, x + 31, y + 25)
	_step("select_material", {"material":7})
	_box("rectangle", x + 3, y + 16, x + 28, y + 18)
	_step("select_material", {"material":2})
	_box("rectangle", x + 9, y + 3, x + 21, y + 9)
	_step("play", {"ticks":12})
	_step("wait_ticks", {"ticks":8})
	_step("pause")
	_step("erase", {"x":x + 15, "y":y + 17, "radius":4})
	_step("play", {"ticks":16})
	_step("pause")
	if _goal_number % 4 == 0 and _next_actor_id(observation) > 0:
		_step("actor_place", {"model":"reference_barrel", "x":x + 15, "y":y - 12})


func _tinkerer_goal(observation: Dictionary) -> void:
	var x := _rng.randi_range(24, 300)
	var y := _rng.randi_range(24, 150)
	goal = "Make a small edit, undo it, redo it and reopen the authored start"
	_step("pause")
	_step("panel", {"panel":"details", "open":true})
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_step("select_material", {"material":MATERIALS[(_goal_number - 1) % MATERIALS.size()]})
	_box("line", x, y, x + 12, y + 5)
	_step("undo")
	_step("redo")
	_box("select_region", x, y, x + 12, y + 5)
	_step("copy")
	_step("paste", {"x":x + 20, "y":y + 10})
	_step("save_layout")
	_step("reopen_layout")
	_step("panel", {"panel":"details", "open":false})
	_step("play", {"ticks":4})
	_step("pause")
	_step("single_step")
	var actors: Array = _actor_ids(observation)
	if _goal_number % 3 == 0 and not actors.is_empty():
		_step("actor_select", {"actor_id":int(actors[0])})
		_step("actor_reset")
	if _goal_number % 6 == 0:
		_step("reset_fixture")


func _curiosity_goal(observation: Dictionary, legal_actions: Array) -> void:
	# Seeded tie-breaking keeps equal observations reproducible. Scores use
	# observed attempts and transitions; proposed actions are not successes.
	var candidates: Array[Dictionary] = []
	var lowest := 2147483647
	var current_state := _state_key(observation)
	for candidate: Dictionary in legal_actions:
		var action_id := str(candidate.get("id", ""))
		var pair := _last_observed_id + ">" + action_id
		var prefix := current_state + ">" + action_id + ">"
		var from_this_state := 0
		for transition: String in _transition_counts:
			if transition.begins_with(prefix):
				from_this_state += int(_transition_counts[transition])
		var score := int(_action_counts.get(action_id, 0)) * 8 \
			+ int(_pair_counts.get(pair, 0)) * 3 + from_this_state * 5
		if score < lowest:
			lowest = score
			candidates.clear()
		if score == lowest:
			candidates.append(candidate)
	if candidates.is_empty():
		return
	var target: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var target_id := str(target.id)
	goal = "Investigate the under-exercised %s control" % target_id
	match target_id:
		"fill":
			_step("pause")
			_step("camera", {"x":0, "y":0, "width":480, "height":270})
			_step("select_material", {"material":58})
			_box("outline", 280, 40, 303, 63)
			_box("select_region", 280, 40, 303, 63)
			_step("select_material", {"material":3})
			_step("fill", {"x":292, "y":52})
		"copy", "paste":
			_step("pause")
			_step("camera", {"x":0, "y":0, "width":480, "height":270})
			_box("select_region", 368, 32, 391, 55)
			_step("copy")
			_step("paste", {"x":400, "y":64})
		"save_layout", "reopen_layout":
			_step("pause")
			_step("save_layout")
			_step("reopen_layout")
		"brush", "rectangle", "outline", "line", "erase":
			_step("pause")
			_step("select_material", {"material":MATERIALS[_rng.randi_range(0, MATERIALS.size() - 1)]})
			_queue.append(target.duplicate(true))
			_step("undo")
			_step("redo")
		"actor_select":
			# Passive objects are still selectable. Inspect the concrete legal
			# target without requiring a movement capability or inventing a pilot.
			_step("pause")
			_queue.append(target.duplicate(true))
			_step("panel", {"panel":"details", "open":true})
			_step("panel", {"panel":"details", "open":false})
		"actor_drive", "actor_pilot":
			var actors: Array = _actor_ids(observation)
			if not actors.is_empty():
				var actor_id := int(actors[_rng.randi_range(0, actors.size() - 1)])
				_step("pause")
				_step("actor_select", {"actor_id":actor_id})
				_step("actor_pilot", {"actor_id":actor_id})
			_step("play", {"ticks":4})
			if target_id == "actor_drive":
				_queue.append(target.duplicate(true))
			_step("pause")
		"actor_place", "actor_reset":
			_step("pause")
			_queue.append(target.duplicate(true))
			_step("play", {"ticks":4})
			_step("pause")
		_:
			_queue.append(target.duplicate(true))


func _actor_ids(observation: Dictionary) -> Array:
	var result: Array = []
	# Prefer controllable IDs if the real adapter supplies them. Passive objects
	# remain observable/selectable but do not invent a movement capability.
	if observation.has("controllable_actor_ids"):
		for actor_id: Variant in observation.controllable_actor_ids:
			result.append(int(actor_id))
	elif observation.has("actor_ids"):
		for actor_id: Variant in observation.actor_ids:
			result.append(int(actor_id))
	else:
		for actor: Dictionary in observation.get("actors", []):
			if str(actor.get("model", "")) != "reference_barrel":
				result.append(int(actor.get("id", 0)))
	result.sort()
	return result


func _next_actor_id(observation: Dictionary) -> int:
	# There is no actor-removal action in this vocabulary. IDs in a fresh
	# committed fixture plus successful placements therefore increase densely;
	# prefer the adapter's actual next ID when supplied.
	var proposed := int(observation.get("next_actor_id", 1))
	for actor_id: Variant in observation.get("actor_ids", []):
		proposed = maxi(proposed, int(actor_id) + 1)
	return proposed if proposed <= 8 else 0


func _state_key(observation: Dictionary) -> String:
	# A compact description of supplied observations, deliberately excluding
	# wall-clock/tick values whose cadence differs between identical actions.
	return "%s/%s/%s/%s/%s/%s" % [str(observation.get("paused", "unknown")),
		str(observation.get("material", "unknown")), str(observation.get("tool", "unknown")),
		str(observation.get("selected_actor", "unknown")),
		str(observation.get("undo_available", observation.get("can_undo", "unknown"))),
		str(observation.get("redo_available", observation.get("can_redo", "unknown")))]
