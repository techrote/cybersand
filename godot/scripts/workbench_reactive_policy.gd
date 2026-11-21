extends RefCounted

# Bounded reuse of Thunderbowl's pure wire steering helper. This is a physical
# action adapter, not an arena or a sampled actor owner. It deliberately imports
# no tag combat, team observations, oracle, metal actuators or model service.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Wire = preload("res://examples/thunderbowl/controller_base.gd")
const PATROL_RADIUS: float = 34.0
const TURN_DELAY: float = 0.6

var _model: String = ""
var _home := Vector2.ZERO
var _direction: float = 1.0
var _turn_delay: float = 0.0
var _stalled: float = 0.0
var _decisions: int = 0
var _turns: int = 0
var _wire = Wire.new()


static func supports(model: String) -> bool:
	if not Catalog.has_rig(StringName(model)): return false
	var profile: Dictionary = Catalog.entry(StringName(model)).get("profile", {})
	return not profile.has("player_controller") and str(profile.get("movement", "")) in ["ground", "walk"] \
		and str(profile.get("primary", "")) == "jump"


func configure(model: String, origin: Vector2, actor_slot: int) -> bool:
	if not supports(model) or not origin.is_finite(): return false
	_model = model
	_home = origin
	_direction = 1.0 if actor_slot % 2 == 0 else -1.0
	reset()
	return true


func reset() -> void:
	_turn_delay = 0.0
	_stalled = 0.0


func next_action(view: Dictionary, delta: float) -> Dictionary:
	if _model.is_empty() or view.get("representation") != "articulated-rapier" \
		or str(view.get("model", "")) != _model or view.get("producer") != "policy" \
		or bool(view.get("suspended", true)) or not str(view.get("fault", "")).is_empty(): return {}
	var position: Variant = view.get("position")
	var velocity: Variant = view.get("velocity")
	if not position is Vector2 or not velocity is Vector2 or not position.is_finite() or not velocity.is_finite() \
		or not is_finite(delta) or delta <= 0.0 or delta > 0.25 or int(view.get("tick", -1)) < 0: return {}
	var grounded: bool = bool(view.get("grounded", false))
	_turn_delay = maxf(0.0, _turn_delay - delta)
	_stalled = _stalled + delta if grounded and absf(velocity.x) < 2.0 else 0.0
	var ahead: float = float(view.get("wall_right" if _direction > 0.0 else "wall_left", 30.0))
	if _turn_delay <= 0.0 and ((position.x - _home.x) * _direction >= PATROL_RADIUS \
		or (is_finite(ahead) and ahead < 12.0) or _stalled >= 0.75):
		_direction = -_direction
		_turn_delay = TURN_DELAY
		_stalled = 0.0
		_turns += 1
	# The reusable helper reads only tick and support. A deliberately tiny local
	# value projection supplies those inputs; no sampled observation/envelope is
	# admitted to the physical session or falsely advertised to an external peer.
	var relative := Vector2(_home.x + PATROL_RADIUS * _direction - position.x, 0.0)
	var wire: Dictionary = _wire._wire_toward({"tick":int(view.tick),
		"self_state":[position.x, position.y, velocity.x, velocity.y, 1.0 if grounded else 0.0]}, relative, 0.7)
	_decisions += 1
	return {"move":Vector2(float(wire.movement[0]), 0.0),
		"aim":Vector2(float(wire.aim[0]), float(wire.aim[1])),
		"effort":float(wire.effort), "primary":bool(wire.primary)}


func diagnostics() -> Dictionary:
	return {"adapter":"thunderbowl-wire-to-physical/v1", "model":_model,
		"behavior":"Thunderbowl local reflex: bounded patrol and supported periodic jump",
		"decisions":_decisions, "turns":_turns, "learned":false,
		"source":"examples/thunderbowl/controller_base.gd::_wire_toward",
		"observation":"copied physical self motion, support and local wall distances",
		"excluded":["tag combat", "oracle", "metal actuation", "neighbors", "message passing", "NCA", "smart-link service"]}
