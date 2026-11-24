extends SceneTree

# Pure policy/recipe unit fixtures. The observations and result states supplied
# below are deliberately synthetic and provide NO native/gameplay evidence.
const Policy = preload("res://goblin/goblin_policy.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Setup = preload("res://scripts/workbench_setup.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("GOBLIN_POLICY_UNIT " + label)


func _run() -> void:
	_fixture_tests()
	_policy_tests()
	_observation_tests()
	print("GOBLIN_POLICY_UNIT " + JSON.stringify({"evidence_kind":"synthetic_unit_fixtures",
		"checks":checks, "failures":failures, "native_gameplay_evidence":false,
		"personality_count":Policy.PERSONALITIES.size(), "fixture_count":Fixtures.ids().size(),
		"tested_action_budgets":[64, 128, 256]}))
	quit(0 if failures.is_empty() else 1)


func _fixture_tests() -> void:
	# Setup.validate checks authoring shape, not the native liquid-policy law.
	# Actual fixture installation is separately qualified by the game adapter.
	var placeholder_policy := PackedInt32Array([123])
	var distinct: Dictionary = {}
	for fixture_id: String in Fixtures.ids():
		var first: Dictionary = Fixtures.build(fixture_id, placeholder_policy)
		var second: Dictionary = Fixtures.build(fixture_id, placeholder_policy)
		var shape_error := Setup.validate(first)
		_check(shape_error.is_empty(), fixture_id + " has ordinary Setup-v2 authoring shape: " + shape_error)
		_check(JSON.stringify(first, "", true) == JSON.stringify(second, "", true), fixture_id + " is a repeatable recipe")
		_check(first.extent == [512, 512], fixture_id + " stays in the disposable 512-cell scene")
		_check(first.edits.size() <= 20, fixture_id + " has a small initial construction")
		_check(Fixtures.describe(fixture_id).get("fill_probe") == [380, 44], fixture_id + " declares the shared fill pocket")
		distinct[JSON.stringify(first, "", true).sha256_text()] = true
		first.edits.clear()
		_check(not Fixtures.build(fixture_id, placeholder_policy).edits.is_empty(), fixture_id + " returns independent owned values")
	_check(distinct.size() == Fixtures.ids().size(), "all five authored scenes differ")
	_check(Fixtures.build("../owner-save", placeholder_policy).is_empty(), "unknown fixture ID refuses")
	_check(Fixtures.build("material_playground", PackedInt32Array()).is_empty(), "no fabricated native policy envelope")
	_check(Fixtures.describe("unknown").is_empty(), "unknown fixture metadata refuses")


func _policy_tests() -> void:
	var menu := _menu()
	var observation := _observation(0)
	var menu_before := JSON.stringify(menu, "", true)
	var observation_before := JSON.stringify(observation, "", true)
	var signatures: Dictionary = {}
	for name: String in Policy.PERSONALITIES:
		for budget: int in [64, 128, 256]:
			var a: RefCounted = Policy.new()
			var b: RefCounted = Policy.new()
			_check(a.configure(name, 1701) and b.configure(name, 1701), name + " configures")
			var actions: Array = []
			var exact := true
			var bounded := true
			for step: int in range(budget):
				var supplied := _observation(step)
				var aa: Dictionary = a.next_action(supplied, menu)
				var bb: Dictionary = b.next_action(supplied, menu)
				exact = exact and JSON.stringify(aa, "", true) == JSON.stringify(bb, "", true)
				bounded = bounded and _bounded(aa)
				actions.append(aa)
				var unit_record := {"action":aa, "before":supplied, "after":_observation(step + 1),
					"status":"refused" if step % 11 == 0 else "completed"}
				a.observe_result(unit_record)
				b.observe_result(unit_record.duplicate(true))
			_check(exact, "%s seed1701 is identical over %d supplied-observation decisions" % [name, budget])
			_check(bounded, "%s stays in the finite parameter ranges for %d decisions" % [name, budget])
			_check(int(a.summary().actions_observed) == budget, name + " accounts for every supplied result")
			_check(a.summary().recent_observations.size() <= Policy.HISTORY_LIMIT, name + " keeps bounded recent history")
			if budget == 64:
				signatures[JSON.stringify(actions, "", true).sha256_text()] = true
	_check(signatures.size() == Policy.PERSONALITIES.size(), "all six personalities produce distinct 64-action sequences")
	_check(JSON.stringify(menu, "", true) == menu_before, "policy never mutates the adapter menu")
	_check(JSON.stringify(observation, "", true) == observation_before, "policy never mutates supplied observation")
	var without_actors: Dictionary = observation.duplicate(true)
	without_actors.actor_ids = []
	without_actors.controllable_actor_ids = []
	var hopeful: RefCounted = Policy.new()
	hopeful.configure("CONTROL", 13)
	var imaginary_actor_selected := false
	for _step: int in range(64):
		var proposed: Dictionary = hopeful.next_action(without_actors, menu)
		imaginary_actor_selected = imaginary_actor_selected or proposed.id in ["actor_select", "actor_pilot"]
	_check(not imaginary_actor_selected, "proposed placement never fabricates an observed actor ID")
	var builder: RefCounted = Policy.new()
	builder.configure("BUILDER", 13)
	var first_goal := ""
	var all_one_goal := true
	var kinds: Array[String] = []
	for _step: int in range(12):
		var proposal: Dictionary = builder.next_action(observation, menu)
		if first_goal.is_empty(): first_goal = str(proposal.goal)
		all_one_goal = all_one_goal and str(proposal.goal) == first_goal
		kinds.append(str(proposal.id))
	_check(all_one_goal and kinds.count("rectangle") == 5, "Builder keeps a twelve-step construction experiment")
	_check(kinds.has("play") and kinds.has("wait_ticks"), "Builder observes its construction after Play")
	var constrained: RefCounted = Policy.new()
	constrained.configure("CONTROL", 13)
	var pause_only := [{"id":"pause", "args":{}}]
	for _step: int in range(4):
		_check(constrained.next_action(observation, pause_only).id == "pause", "unavailable goal actions never escape the legal vocabulary")
	_check(constrained.next_action(observation, []).is_empty(), "empty availability gives no proposal")
	_check(int(constrained.summary().unavailable_goal_steps_skipped) > 0, "unavailable goal steps are visible in the policy summary")
	var invalid: RefCounted = Policy.new()
	_check(not invalid.configure("NETWORK_AGENT", 1), "unknown personality refuses")
	_check(invalid.next_action(observation, menu).is_empty(), "unknown personality performs no action")
	_check(invalid.configure("CONTROL", -2147483648), "minimum signed int32 seed configures")
	_check(not invalid.configure("CONTROL", -2147483649), "seed below signed int32 refuses")
	_check(invalid.next_action(observation, menu).is_empty(), "refused seed performs no action")
	_check(not invalid.configure("CONTROL", 2147483648), "seed above signed int32 refuses")
	var random_a: RefCounted = Policy.new()
	var random_b: RefCounted = Policy.new()
	random_a.configure("RANDOM", 13)
	random_b.configure("RANDOM", 605)
	var differs := false
	for _step: int in range(32):
		differs = differs or random_a.next_action(observation, menu) != random_b.next_action(observation, menu)
	_check(differs, "different RANDOM seeds change the decision sequence")
	var resetter: RefCounted = Policy.new()
	resetter.configure("TINKERER", 13)
	var first: Dictionary = resetter.next_action(observation, menu)
	for _step: int in range(20): resetter.next_action(observation, menu)
	resetter.configure("TINKERER", 13)
	_check(resetter.next_action(observation, menu) == first, "reconfiguration clears RNG and persistent goal state")


func _observation_tests() -> void:
	var policy: RefCounted = Policy.new()
	policy.configure("CURIOSITY", 13)
	var supplied := _observation(0)
	var proposed: Dictionary = policy.next_action(supplied, _menu())
	_check(policy.summary().actions_observed == 0, "proposing an action cannot fabricate an observed result")
	policy.observe_result({"action":proposed, "status":"refused", "before":supplied, "after":supplied})
	policy.observe_result({"action":proposed, "status":"partial", "before":supplied, "after":supplied})
	var report: Dictionary = policy.summary()
	_check(report.observed_status_counts == {"refused":1, "partial":1}, "policy retains independent refusal/partial verdicts without upgrading them")
	_check(report.distinct_observed_transitions == 1, "identical observed transitions share one coverage entry")
	_check(report.actions_observed == 2, "refused and partial attempts remain counted")
	for _step: int in range(100):
		policy.observe_result({"action":{"id":"pause", "args":{}}, "status":"completed", "before":supplied, "after":supplied})
	_check(policy.summary().recent_observations.size() == Policy.HISTORY_LIMIT, "compact history retires oldest unit observations")
	var preference: RefCounted = Policy.new()
	preference.configure("CURIOSITY", 7)
	preference.observe_result({"action":{"id":"pause", "args":{}}, "status":"completed", "before":supplied, "after":supplied})
	var selected: Dictionary = preference.next_action(supplied,
		[{"id":"pause", "args":{}}, {"id":"panel", "args":{"panel":"details", "open":true}}])
	_check(selected.id == "panel", "Curiosity prefers an under-exercised available control")
	var state_aware: RefCounted = Policy.new()
	state_aware.configure("CURIOSITY", 7)
	var other: Dictionary = supplied.duplicate(true)
	other.material = 58
	state_aware.observe_result({"action":{"id":"panel", "args":{}}, "status":"completed", "before":supplied, "after":supplied})
	state_aware.observe_result({"action":{"id":"pause", "args":{}}, "status":"completed", "before":other, "after":other})
	state_aware.observe_result({"action":{"id":"camera", "args":{}}, "status":"completed", "before":other, "after":other})
	var new_transition: Dictionary = state_aware.next_action(supplied,
		[{"id":"pause", "args":{}}, {"id":"panel", "args":{"panel":"details", "open":true}}])
	_check(new_transition.id == "pause", "Curiosity favors an unobserved action from the current supplied state")
	# Deliberately supplied passive-actor unit data: this exercises policy
	# selection only, and is not evidence that an application actor was made.
	var passive: Dictionary = supplied.duplicate(true)
	passive.actor_ids = [1]
	passive.controllable_actor_ids = []
	var inspect_only: RefCounted = Policy.new()
	inspect_only.configure("CURIOSITY", 13)
	var inspect_menu := [{"id":"actor_select", "args":{"actor_id":1}},
		{"id":"pause", "args":{}}, {"id":"panel", "args":{"panel":"details", "open":true}}]
	inspect_only.observe_result({"action":{"id":"pause", "args":{}}, "status":"completed", "before":passive, "after":passive})
	inspect_only.observe_result({"action":{"id":"panel", "args":{}}, "status":"completed", "before":passive, "after":passive})
	var passive_plan: Array[Dictionary] = []
	for _step: int in range(4): passive_plan.append(inspect_only.next_action(passive, inspect_menu))
	_check(passive_plan[0].id == "pause" and passive_plan[1].id == "actor_select" \
		and passive_plan[1].args.actor_id == 1,
		"Curiosity selects an observed passive actor without requiring movement capability")
	_check(passive_plan[2].id == "panel" and passive_plan[2].args.open == true \
		and passive_plan[3].id == "panel" and passive_plan[3].args.open == false,
		"passive-actor curiosity pursues an inspection instead of repeated Play/Pause")


func _observation(index: int) -> Dictionary:
	return {"evidence_kind":"synthetic_unit_input", "paused":index % 3 != 0,
		"material":[2, 3, 7, 58][index % 4], "tool":"Brush",
		"selected_actor":1, "actor_ids":[1, 2], "controllable_actor_ids":[1],
		"undo_available":index % 2 == 0, "redo_available":index % 4 == 0,
		"native":{"generation":7, "revision":index, "tick":index * 2}}


func _menu() -> Array:
	return [{"id":"pause", "args":{}}, {"id":"play", "args":{"ticks":4}},
		{"id":"wait_ticks", "args":{"ticks":4}}, {"id":"select_material", "args":{"material":7}},
		{"id":"brush", "args":{"x":80, "y":80, "radius":2}},
		{"id":"erase", "args":{"x":80, "y":80, "radius":2}},
		{"id":"rectangle", "args":{"x0":48, "y0":48, "x1":63, "y1":63}},
		{"id":"outline", "args":{"x0":48, "y0":48, "x1":63, "y1":63}},
		{"id":"line", "args":{"x0":48, "y0":48, "x1":63, "y1":55}},
		{"id":"select_region", "args":{"x0":48, "y0":48, "x1":63, "y1":63}},
		{"id":"fill", "args":{"x":380, "y":44}}, {"id":"copy", "args":{}},
		{"id":"paste", "args":{"x":200, "y":80}}, {"id":"undo", "args":{}},
		{"id":"redo", "args":{}}, {"id":"camera", "args":{"x":0, "y":0, "width":480, "height":270}},
		{"id":"actor_select", "args":{"actor_id":1}},
		{"id":"actor_pilot", "args":{"actor_id":1}},
		{"id":"actor_place", "args":{"model":"kestrel", "x":224, "y":128}},
		{"id":"actor_reset", "args":{}}, {"id":"single_step", "args":{}},
		{"id":"actor_drive", "args":{"direction":"right", "ticks":8}},
		{"id":"panel", "args":{"panel":"details", "open":true}},
		{"id":"save_layout", "args":{}}, {"id":"reopen_layout", "args":{}},
		{"id":"reset_fixture", "args":{}}]


func _bounded(action: Dictionary) -> bool:
	if not action.has_all(["id", "args", "goal"]): return false
	var arguments: Dictionary = action.args
	match str(action.id):
		"pause", "copy", "undo", "redo", "save_layout", "reopen_layout", "reset_fixture", "actor_reset", "single_step":
			return arguments.is_empty()
		"play", "wait_ticks":
			return arguments.size() == 1 and int(arguments.get("ticks", 0)) in range(1, 33)
		"select_material":
			return arguments.size() == 1 and arguments.get("material") in [0, 2, 3, 7, 58]
		"brush", "erase":
			return arguments.size() == 3 and _point(arguments) and int(arguments.get("radius", -1)) in range(0, 5)
		"rectangle", "outline", "line", "select_region":
			return arguments.size() == 4 and _coordinate(arguments.get("x0", -1)) and _coordinate(arguments.get("y0", -1)) \
				and _coordinate(arguments.get("x1", -1)) and _coordinate(arguments.get("y1", -1)) \
				and absi(int(arguments.x1) - int(arguments.x0)) < 64 and absi(int(arguments.y1) - int(arguments.y0)) < 64
		"fill", "paste":
			return arguments.size() == 2 and _point(arguments)
		"camera":
			return arguments.size() == 4 and int(arguments.get("x", -1)) in range(0, 257) \
				and int(arguments.get("y", -1)) in range(0, 257) \
				and [arguments.get("width"), arguments.get("height")] in [[240, 135], [480, 270]]
		"actor_select", "actor_pilot":
			return arguments.size() == 1 and int(arguments.get("actor_id", 0)) in range(1, 9)
		"actor_place":
			return arguments.size() == 3 and arguments.get("model") in ["kestrel", "reference_barrel"] \
				and int(arguments.get("x", 0)) in range(32, 449) and int(arguments.get("y", 0)) in range(32, 225)
		"actor_drive":
			return arguments.size() == 2 and arguments.get("direction") in ["left", "right", "up", "down"] \
				and int(arguments.get("ticks", 0)) in range(1, 17)
		"panel":
			return arguments.size() == 2 and arguments.get("panel") == "details" and arguments.get("open") is bool
	return false


func _coordinate(value: Variant) -> bool:
	return value is int and value >= 8 and value <= 503


func _point(arguments: Dictionary) -> bool:
	return _coordinate(arguments.get("x", -1)) and _coordinate(arguments.get("y", -1))
