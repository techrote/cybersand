extends RefCounted

# Proposes only bounded in-game actions. It never infers native progress,
# decides action success, reads a file, or performs an application operation.
# The adapter remains the range/capability authority; the independent oracle
# judges the returned application observations.
const Coverage = preload("res://goblin/goblin_coverage.gd")
const State = preload("res://goblin/goblin_state.gd")
const BASELINE_PERSONALITIES := ["CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM"]
const PERSONALITIES := ["CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM",
	"STATEFUL", "NOVELTY", "COVERAGE_HUNTER", "DISASTER_ARTIST", "BOUNDARY_GOBLIN", "HISTORY_GOBLIN",
	"MATERIAL_ALCHEMIST", "ACTOR_ENTHUSIAST", "IMPATIENT_SWITCHER", "OBSESSIVE_REPRODUCER"]
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
var _coverage: RefCounted = Coverage.new()
var _corpus: RefCounted
var _last_novelty: Dictionary = {}
var _memory_result: Dictionary = {}
var _reuse_prefix: Array[Dictionary] = []
var _reuse_requested := false
var _reused_actions := 0
var _reuse_queued_actions := 0
var _reuse_remaining := 0
var _last_family := ""
var _intention: Dictionary = {}
var _intentions_started: Dictionary = {}
var _repeat_location := Vector2i(64, 48)


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
	_coverage.reset()
	_corpus = null
	_last_novelty.clear()
	_memory_result.clear()
	_reuse_prefix.clear()
	_reuse_requested = false
	_reused_actions = 0
	_reuse_queued_actions = 0
	_reuse_remaining = 0
	_last_family = ""
	_intention.clear()
	_intentions_started.clear()
	_repeat_location = Vector2i(64, 48)
	_configured = personality in PERSONALITIES and seed_value >= -2147483648 and seed_value <= 2147483647
	goal = "Ready to explore" if _configured else "Unsupported personality or seed"
	return _configured


func next_action(observation: Dictionary, legal_actions: Array) -> Dictionary:
	if not _configured or legal_actions.is_empty():
		goal = "No applicable in-game action"
		return {}
	if _emitted == 0 and not _reuse_prefix.is_empty():
		goal = "Revisit an explicitly selected matching authored prefix"
		_set_intention("retained_prefix", "revisit", _reuse_prefix.size())
		_queue = _reuse_prefix.duplicate(true)
		_reuse_prefix.clear()
		_reuse_queued_actions = _queue.size()
		_reuse_remaining = _queue.size()
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
		var retained_candidate: bool = _reuse_remaining > 0
		if retained_candidate: _reuse_remaining -= 1
		if _has_id(legal_actions, str(candidate.id)) and _observed_preconditions(candidate, observation):
			if retained_candidate: _reused_actions += 1
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
	_last_novelty = _coverage.observe(record)
	if _corpus != null:
		_memory_result = _corpus.observe(record, _last_novelty)
	_intention["actions_observed"] = int(_intention.get("actions_observed", 0)) + 1


func summary() -> Dictionary:
	return {"personality":personality, "seed":campaign_seed, "goal":goal,
		"goals_started":_goal_number, "actions_proposed":_emitted, "actions_observed":_observed,
		"unavailable_goal_steps_skipped":_skipped, "observed_action_counts":_action_counts.duplicate(true),
		"observed_status_counts":_status_counts.duplicate(true), "distinct_observed_pairs":_pair_counts.size(),
		"distinct_observed_transitions":_transition_counts.size(), "recent_observations":_recent.duplicate(true),
		"coverage":_coverage.summary(), "last_novelty":_last_novelty.duplicate(true),
		"intention":_intention.duplicate(true), "intentions_started":_intentions_started.duplicate(true),
		"memory":_corpus.summary() if _corpus != null else {"records":0, "enabled":false},
		"memory_result":_memory_result.duplicate(true), "prefix_reuse_requested":_reuse_requested,
		"retained_prefix_actions_proposed":_reused_actions, "retained_prefix_actions_queued":_reuse_queued_actions,
		"decision_contract":"seeded supplied-observation decisions; no predicted action success"}


func _emit(action: Dictionary) -> Dictionary:
	var result := {"id":str(action.get("id", "")), "args":Dictionary(action.get("args", {})).duplicate(true), "goal":goal}
	_emitted += 1
	_last_family = _family(str(result.id))
	if not _intention.is_empty():
		_intention["remaining_actions"] = _queue.size()
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
		_: _modern_goal(observation, legal_actions)


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


func bind_memory(corpus: RefCounted, context: Dictionary, reuse_prefix: bool = false) -> bool:
	if not _configured or _emitted != 0 or corpus == null or not corpus.begin_episode(context): return false
	_corpus = corpus
	_coverage.load_memory(corpus.search_hints())
	_reuse_requested = reuse_prefix
	# Matching context binds the authored fixture, fixture version and exact
	# provenance. This is a proposed action prefix, never a physics checkpoint.
	if reuse_prefix and personality not in BASELINE_PERSONALITIES:
		_reuse_prefix = corpus.reuse_actions(context, posmod(campaign_seed, 64))
	return true


func coverage_memory() -> Dictionary:
	return _coverage.memory()


static func describe(name: String) -> Dictionary:
	var entries := {
		"CONTROL":["Control", "Preserved deterministic tour of the predecessor controls.", "baseline"],
		"WANDERER":["Wanderer", "Visits waypoints, leaves material trails and tries an observed pilot.", "baseline"],
		"BUILDER":["Builder", "Builds little cups, watches them and removes their supporting ledges.", "baseline"],
		"TINKERER":["Tinkerer", "Edits, copies, revisits history and reopens authored starts.", "baseline"],
		"CURIOSITY":["Curiosity", "Preserved least-exercised control search from the predecessor.", "baseline"],
		"RANDOM":["Seeded random", "Samples the adapter's currently offered legal actions.", "baseline"],
		"STATEFUL":["Stateful explorer", "Chooses finite construction, editing and actor intentions from actual observations.", "stateful"],
		"NOVELTY":["Novelty seeker", "Prefers unseen state/action combinations and parameter variants.", "novelty"],
		"COVERAGE_HUNTER":["Coverage hunter", "Balances admitted action, transition and parameter coverage.", "coverage"],
		"DISASTER_ARTIST":["Disaster artist", "Builds bounded reservoirs, introduces materials and breaches their walls.", "stateful"],
		"BOUNDARY_GOBLIN":["Boundary goblin", "Visits fixture edges and probes legal geometry and view limits.", "coverage"],
		"HISTORY_GOBLIN":["History goblin", "Repeats reversible edits, copy/paste and authored persistence experiments.", "stateful"],
		"MATERIAL_ALCHEMIST":["Material alchemist", "Places different admitted materials together and observes their development.", "novelty"],
		"ACTOR_ENTHUSIAST":["Actor enthusiast", "Selects observed actors and explores available controls and equipment.", "coverage"],
		"IMPATIENT_SWITCHER":["Impatient switcher", "Alternates action families, controls and simulation states.", "coverage"],
		"OBSESSIVE_REPRODUCER":["Obsessive reproducer", "Revisits a small edit relationship; can explicitly reuse a retained prefix.", "stateful"],
	}
	if not entries.has(name): return {}
	return {"id":name, "label":entries[name][0], "description":entries[name][1], "search_mode":entries[name][2]}


func _modern_goal(observation: Dictionary, menu: Array) -> void:
	match personality:
		"DISASTER_ARTIST": _reservoir_intention(observation, menu, true)
		"BOUNDARY_GOBLIN": _boundary_intention(menu)
		"HISTORY_GOBLIN": _history_intention(menu, false)
		"MATERIAL_ALCHEMIST": _reservoir_intention(observation, menu, false)
		"ACTOR_ENTHUSIAST": _actor_intention(observation, menu)
		"IMPATIENT_SWITCHER":
			goal = "Switch from " + _last_family + " to another ordinary game control"
			_queue.append(_choose(menu, observation, "coverage", true))
			_set_intention("switch_family", "ui", _queue.size())
		"OBSESSIVE_REPRODUCER": _history_intention(menu, true)
		"STATEFUL":
			if observation.get("paused") == false:
				goal = "Watch the running experiment and pause to inspect it"
				_append_available(menu, "wait_ticks")
				_append_available(menu, "pause")
				_set_intention("observe_running", "simulation", _queue.size())
			elif _goal_number % 4 == 1:
				_reservoir_intention(observation, menu, false)
			elif _goal_number % 4 == 2:
				_history_intention(menu, false)
			elif _goal_number % 4 == 3:
				_actor_intention(observation, menu)
			else:
				goal = "Use the observed state to choose the next ordinary control"
				_queue.append(_choose(menu, observation, "stateful"))
				_set_intention("state_sensitive_choice", "exploration", _queue.size())
		_:
			var mode := "novelty" if personality == "NOVELTY" else "coverage"
			goal = "Explore an under-observed " + mode + " transition"
			_queue.append(_choose(menu, observation, mode))
			_set_intention(mode + "_choice", "exploration", _queue.size())
	if _queue.size() > 128: _queue.resize(128)


func _set_intention(id: String, family: String, planned: int) -> void:
	_intention = {"id":id, "family":family, "sequence":_goal_number,
		"planned_actions":planned, "remaining_actions":planned, "actions_observed":0, "goal":goal}
	_intentions_started[id] = int(_intentions_started.get(id, 0)) + 1


func _choose(menu: Array, observation: Dictionary, mode: String, change_family: bool = false) -> Dictionary:
	var weights: Array[float] = []
	var total := 0.0
	for candidate: Dictionary in menu:
		var id := str(candidate.get("id", ""))
		var family := _family(id)
		var weight: float = _coverage.score(candidate, observation, mode) * _personality_weight(family)
		if change_family and family == _last_family: weight *= 0.06
		# Context-sensitive weights use actual observer facts. They never turn a
		# proposed actor, history edit or save into an admitted capability.
		if id == "actor_place" and observation.get("actors", []).size() >= 6: weight *= 0.1
		if id in ["reset_fixture", "replace_fixture", "restore_start"] and _observed < 16: weight *= 0.1
		if id == "pause" and observation.get("paused") == true: weight *= 0.12
		if id == "select_material" and candidate.get("args", {}).get("material") == observation.get("material"): weight *= 0.12
		if id == "select_tool" and candidate.get("args", {}).get("tool") == observation.get("tool"): weight *= 0.12
		if id == "actor_pilot" and candidate.get("args", {}).get("actor_id") == observation.get("pilot_actor"): weight *= 0.12
		weight = maxf(weight, 0.001)
		weights.append(weight)
		total += weight
	var choice: float = _rng.randf() * total
	for index: int in range(menu.size()):
		choice -= weights[index]
		if choice <= 0.0: return menu[index].duplicate(true)
	return menu.back().duplicate(true)


func _personality_weight(family: String) -> float:
	var favored := {
		"DISASTER_ARTIST":["material", "construction", "simulation"],
		"BOUNDARY_GOBLIN":["navigation", "construction", "lifecycle"],
		"HISTORY_GOBLIN":["history", "construction"],
		"MATERIAL_ALCHEMIST":["material", "construction", "simulation"],
		"ACTOR_ENTHUSIAST":["actor"],
		"IMPATIENT_SWITCHER":["ui", "actor", "lifecycle"],
		"OBSESSIVE_REPRODUCER":["history", "construction"],
	}
	return 4.0 if family in favored.get(personality, []) else 1.0


static func _family(id: String) -> String:
	if id.begins_with("actor_"): return "actor"
	if id.begins_with("camera"): return "navigation"
	if id.begins_with("source_") or id == "select_material": return "material"
	if id in ["brush", "erase", "rectangle", "outline", "line", "fill", "stroke", "live_stroke", "interrupt_stroke"]: return "construction"
	if id in ["undo", "redo", "copy", "paste", "select_region", "save_layout", "reopen_layout"]: return "history"
	if id in ["play", "pause", "wait_ticks", "single_step"]: return "simulation"
	if id in ["reset_fixture", "replace_fixture", "restore_start"]: return "lifecycle"
	return "ui"


func _available_materials(menu: Array) -> Array[int]:
	var values: Array[int] = []
	for candidate: Dictionary in menu:
		if candidate.get("id") == "select_material":
			var value := int(candidate.get("args", {}).get("material", -1))
			if value > 0 and value != 58 and value != 7 and value not in values: values.append(value)
	return values


func _append_available(menu: Array, id: String) -> bool:
	var choices: Array[Dictionary] = []
	for candidate: Dictionary in menu:
		if candidate.get("id") == id: choices.append(candidate)
	if choices.is_empty(): return false
	_queue.append(choices[_rng.randi_range(0, choices.size() - 1)].duplicate(true))
	return true


func _reservoir_intention(observation: Dictionary, menu: Array, breach: bool) -> void:
	if observation.get("paused") == false:
		goal = "Pause before constructing the next material experiment"
		_append_available(menu, "pause")
		_set_intention("pause_for_construction", "simulation", _queue.size())
		return
	var materials := _available_materials(menu)
	if materials.is_empty():
		goal = "Inspect the available material controls for " + personality.to_lower()
		_queue.append(_choose(menu, observation, "coverage" if breach else "novelty"))
		_set_intention("material_inspection", "material", _queue.size())
		return
	var x := 32 + _rng.randi_range(0, 5) * 64
	var y := 40 + _rng.randi_range(0, 2) * 52
	var first := materials[_rng.randi_range(0, materials.size() - 1)]
	var second := materials[_rng.randi_range(0, materials.size() - 1)]
	goal = "Build a cup, combine materials %d and %d, %s and observe" % [first, second, "breach its gate" if breach else "compare after stepping"]
	_step("pause")
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_step("select_material", {"material":58})
	_container(x, y, 36, 30)
	_step("select_material", {"material":first})
	_box("rectangle", x + 4, y + 14, x + 15, y + 22)
	_step("select_material", {"material":second})
	_box("rectangle", x + 20, y + 4, x + 29, y + 11)
	_step("play", {"ticks":8})
	_step("wait_ticks", {"ticks":8})
	_step("pause")
	if breach:
		_step("erase", {"x":x + 34, "y":y + 23, "radius":3})
		_step("play", {"ticks":12})
		_step("pause")
		_step("select_material", {"material":58})
		_box("rectangle", x + 33, y + 18, x + 35, y + 29)
	else:
		_step("single_step")
		_step("undo")
		_step("redo")
	_set_intention("reservoir_breach_repair" if breach else "material_pair", "material", _queue.size())


func _container(x: int, y: int, width: int, height: int) -> void:
	_box("rectangle", x, y + height - 3, x + width - 1, y + height - 1)
	_box("rectangle", x, y, x + 2, y + height - 4)
	_box("rectangle", x + width - 3, y, x + width - 1, y + height - 4)


func _history_intention(menu: Array, repeat: bool) -> void:
	if not _has_id(menu, "rectangle"):
		goal = "Pause to investigate reversible editing"
		if not _append_available(menu, "pause"): _queue.append(menu[0].duplicate(true))
		_set_intention("history_prepare", "history", _queue.size())
		return
	if not repeat or _goal_number % 4 == 1:
		_repeat_location = Vector2i(32 + _rng.randi_range(0, 12) * 24, 32 + _rng.randi_range(0, 5) * 24)
	var x := _repeat_location.x
	var y := _repeat_location.y
	goal = "Revisit edit, Undo, Redo, copy and authored reopen at (%d, %d)" % [x, y]
	_step("pause")
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_step("select_material", {"material":58})
	_box("rectangle", x, y, x + 11, y + 7)
	_step("undo")
	_step("redo")
	_box("select_region", x, y, x + 11, y + 7)
	_step("copy")
	_step("paste", {"x":x + 16, "y":y + 12})
	_step("undo")
	_step("redo")
	_step("save_layout")
	_step("reopen_layout")
	_step("single_step")
	_set_intention("repeat_edit_relationship" if repeat else "history_roundtrip", "history", _queue.size())


func _boundary_intention(menu: Array) -> void:
	if not _has_id(menu, "brush"):
		goal = "Pause before inspecting a world edge"
		if not _append_available(menu, "pause"): _queue.append(menu[0].duplicate(true))
		_set_intention("edge_prepare", "navigation", _queue.size())
		return
	var side := posmod(_goal_number - 1, 4)
	var x := 8 if side in [0, 2] else 480
	var y := 8 if side in [0, 1] else 480
	goal = "Inspect the admitted corner near (%d, %d), then undo the small mark" % [x, y]
	_step("pause")
	_step("camera", {"x":0 if x < 256 else 256, "y":0 if y < 256 else 256, "width":480, "height":270})
	_step("select_material", {"material":58})
	_box("outline", x, y, x + 15, y + 15)
	_step("brush", {"x":x + 7, "y":y + 7, "radius":0})
	_step("erase", {"x":x + 7, "y":y + 7, "radius":4})
	_step("undo")
	_step("redo")
	_step("single_step")
	_step("camera", {"x":0, "y":0, "width":480, "height":270})
	_set_intention("bounded_corner_probe", "navigation", _queue.size())


func _actor_intention(observation: Dictionary, menu: Array) -> void:
	goal = "Investigate an observed actor and its admitted capabilities"
	if observation.get("paused") == false:
		var actor_choices: Array[Dictionary] = []
		for action: Dictionary in menu:
			if _family(str(action.id)) == "actor": actor_choices.append(action)
		if not actor_choices.is_empty(): _queue.append(_choose(actor_choices, observation, "coverage"))
		_append_available(menu, "pause")
	elif observation.get("actors", []).is_empty():
		if not _append_available(menu, "actor_place"): _queue.append(_choose(menu, observation, "coverage"))
	else:
		var preferred: Array[Dictionary] = []
		for action: Dictionary in menu:
			if _family(str(action.id)) == "actor": preferred.append(action)
		if not preferred.is_empty(): _queue.append(_choose(preferred, observation, "coverage"))
		if _goal_number % 2 == 0: _append_available(menu, "play")
		if _queue.is_empty(): _queue.append(_choose(menu, observation, "coverage"))
	_set_intention("actor_capability_experiment", "actor", _queue.size())
