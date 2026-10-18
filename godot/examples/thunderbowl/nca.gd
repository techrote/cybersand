extends "res://examples/thunderbowl/controller_base.gd"

# NCA-inspired neural update on an actor communication graph, not a regular
# terrain lattice. The included weights are UNTRAINED authored initialization.
# One shared 12->8->4 residual MLP, old delivered neighbor state, one round.
var _state: Array = [0.0, 0.0, 0.0, 0.0]
var _weights: Dictionary = {}
var weight_sha256: String = ""


func _init() -> void:
	set_weights(Contract.load_json("res://examples/thunderbowl/nca_seed_weights.json"))


func set_weights(value: Dictionary) -> bool:
	if not Contract.exact_keys(value, ["version", "architecture", "training_status", "weights_in", "bias_in", "weights_out", "bias_out"]) \
		or not value.architecture is String or not value.training_status is String \
		or not Contract.integer(value.version, 1, 1) or value.architecture != "graph_residual_12_8_4" \
		or not ["untrained", "trained_external"].has(value.training_status) \
		or not Contract.vector(value.weights_in, 96, -4.0, 4.0) \
		or not Contract.vector(value.bias_in, 8, -4.0, 4.0) \
		or not Contract.vector(value.weights_out, 32, -4.0, 4.0) \
		or not Contract.vector(value.bias_out, 4, -4.0, 4.0):
		return false
	_weights = value.duplicate(true)
	weight_sha256 = JSON.stringify(_weights, "", true).sha256_text()
	_state = [0.0, 0.0, 0.0, 0.0]
	return true


func _reset() -> void:
	_state = [0.0, 0.0, 0.0, 0.0]


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	if _weights.is_empty():
		return _packet(view, Contract.neutral_wire(), false, [], true)
	var mean: Array = [0.0, 0.0, 0.0, 0.0]
	var count: int = 0
	for received: Dictionary in view.messages:
		if received.kind != "latent_state": continue
		count += 1
		for channel: int in range(4): mean[channel] += received.payload[channel]
	if count > 0:
		for channel: int in range(4): mean[channel] /= float(count)
	var enemy: Dictionary = _visible_enemy(view)
	var relative: Vector2 = Vector2.ZERO
	if not enemy.is_empty(): relative = Vector2(enemy.relative_position[0], enemy.relative_position[1])
	var inputs: Array = _state.duplicate()
	inputs.append_array(mean)
	inputs.append_array([clampf(relative.x / 64.0, -1.0, 1.0), clampf(relative.y / 64.0, -1.0, 1.0),
		clampf(view.self_state[2] / 160.0, -1.0, 1.0), clampf(view.self_state[6], 0.0, 1.0)])
	var hidden: Array = []
	for unit: int in range(8):
		var total: float = _weights.bias_in[unit]
		for channel: int in range(12): total += _weights.weights_in[unit * 12 + channel] * inputs[channel]
		hidden.append(maxf(0.0, total))
	var next_state: Array = _state.duplicate()
	for channel: int in range(4):
		var total: float = _weights.bias_out[channel]
		for unit: int in range(8): total += _weights.weights_out[channel * 8 + unit] * hidden[unit]
		next_state[channel] = clampf(_state[channel] + 0.1 * tanh(total), -1.0, 1.0)
	_state = next_state
	var action: Dictionary = Contract.neutral_wire()
	action.movement = [_state[0], _state[1]]
	action.aim = Contract.normalized([relative.x, relative.y])
	action.effort = clampf(0.5 + _state[2] * 0.5, 0.0, 1.0)
	action.primary = _state[3] > 0.5
	return _packet(view, action, not enemy.is_empty() and _shot(view, relative), _state, false, "latent_state")
