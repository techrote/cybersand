extends RefCounted

# A SINGLE central policy receives copied oracle views for its assigned actors.
# Greedy target assignment penalizes over-concentration; no path search/NN call.
const Wire = preload("res://examples/thunderbowl/wire_seek.gd")
var _actors: Array = []


func _init() -> void:
	for index: int in range(8): _actors.append(Wire.new())


func decide(view: Dictionary) -> Dictionary:
	return decide_batch([view])[0]


func decide_batch(views: Array) -> Array:
	var result: Array = []
	var assignments: Dictionary = {}
	for view: Dictionary in views:
		var centre: Vector2 = Vector2(view.self_state[0] + view.self_state[35] * 0.5,
			view.self_state[1] + view.self_state[36] * 0.5)
		var best: Vector2 = Vector2.ZERO
		var best_id: int = -1
		var best_cost: float = INF
		for target: Dictionary in view.oracle.actors:
			if not target.alive or int(target.team) == int(view.team): continue
			var relative: Vector2 = Vector2(target.state[0] + target.state[35] * 0.5,
				target.state[1] + target.state[36] * 0.5) - centre
			var cost: float = relative.length() + 32.0 * float(assignments.get(target.actor_id, 0))
			if cost < best_cost:
				best = relative
				best_id = int(target.actor_id)
				best_cost = cost
		if best_id >= 0: assignments[best_id] = int(assignments.get(best_id, 0)) + 1
		result.append(_actors[int(view.actor_id)].decide_toward(view, best, best_id >= 0))
	return result
