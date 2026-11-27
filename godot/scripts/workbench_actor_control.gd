extends RefCounted

# Value-only producer adapter. Existing rig controllers still own every motor,
# force and tool. This object receives a copied physical observation and returns
# action values; it never receives a World, node, RID, canvas or paint pointer.
const Scripted = preload("res://scripts/physical_actor_script.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const Teacher = preload("res://scripts/physical_flight_teacher.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Reactive = preload("res://scripts/workbench_reactive_policy.gd")
const AmbientEngine = preload("res://scripts/ambient/ambient_engine.gd")
const AmbientActuator = preload("res://scripts/ambient/ambient_actuator.gd")

var _model: String = ""
var _home := Vector2.ZERO
var _direction: float = 1.0
var _script = Scripted.new()
var _teacher = Teacher.new()
var _reactive = Reactive.new()
var _reactive_supported: bool = false
var _reactive_active: bool = false
var _fleet_index: int = -1
var _fleet_profile: Dictionary = {}
var _decisions: int = 0
var _last_tick: int = -1
var _last_action: Dictionary = {}
var _ambient = AmbientEngine.new()
var _ambient_actuator = AmbientActuator.new()
var _ambient_configured := false
var _ambient_active := false
var _ambient_profile: Dictionary = {}
var _ambient_context: Dictionary = {}
var _ambient_last_seconds := -1.0
var _ambient_environment: Dictionary = {}


func configure(model: String, origin: Vector2, actor_slot: int) -> bool:
	_model = model
	_home = origin
	_direction = 1.0 if actor_slot % 2 == 0 else -1.0
	_reactive_supported = _reactive.configure(model, origin, actor_slot)
	_fleet_index = Fleet.index_for_id(model)
	if _fleet_index >= 0:
		_fleet_profile = Fleet.definition(_fleet_index).profile.duplicate(true)
		return true
	return _script.configure(StringName(model), origin, actor_slot)


func configure_ambient(profile: Dictionary, instance_id: int) -> bool:
	if not _ambient_actuator.configure(_model): return false
	var context := {"actor_id":instance_id, "home":_home,
		"capabilities":AmbientActuator.capabilities(_model)}
	var receipt: Dictionary = _ambient.configure(profile, context)
	if not bool(receipt.get("ok", false)): return false
	_ambient_profile = profile.duplicate(true)
	_ambient_context = context
	_ambient_configured = true
	_ambient_last_seconds = -1.0
	_ambient_environment.clear()
	return true


func cancel(preserve_ambient: bool = false) -> void:
	_script.cancel()
	_teacher.reset()
	_reactive.reset()
	_reactive_active = false
	_last_action.clear()
	_ambient_active = false
	_ambient_actuator.reset()
	if not preserve_ambient and _ambient_configured:
		_ambient.configure(_ambient_profile, _ambient_context)
		_ambient_last_seconds = -1.0
		_ambient_environment.clear()


func next_action(view: Dictionary, delta: float) -> Dictionary:
	if view.get("representation") != "articulated-rapier" or str(view.get("model", "")) != _model \
		or bool(view.get("suspended", true)) or not str(view.get("fault", "")).is_empty(): return {}
	if not is_finite(delta) or delta <= 0.0 or delta > 0.25: return {}
	var position: Variant = view.get("position")
	var velocity: Variant = view.get("velocity")
	if not position is Vector2 or not velocity is Vector2 or not position.is_finite() or not velocity.is_finite(): return {}
	_decisions += 1
	_last_tick = int(view.get("tick", -1))
	_ambient_active = str(view.get("producer", "")) == "policy" and str(view.get("policy_adapter", "")) == "ambient"
	if _ambient_active:
		if not _ambient_configured: return {}
		var seconds: float = float(view.get("simulation_time_seconds", -1.0))
		if not is_finite(seconds) or seconds < 0.0: return {}
		var elapsed: float = maxf(0.0, seconds - _ambient_last_seconds) if _ambient_last_seconds >= 0.0 else 0.0
		_ambient_environment = view.get("ambient_environment", {}).duplicate(true)
		var intent: Dictionary = _ambient.step(_ambient_environment, elapsed)
		if bool(intent.get("available", false)): _ambient_last_seconds = seconds
		_last_action = _ambient_actuator.next_action(intent, view)
		return _last_action.duplicate(true)
	_reactive_active = _reactive_supported and str(view.get("producer", "")) == "policy"
	if _reactive_active:
		_last_action = _reactive.next_action(view, delta)
	elif _fleet_index >= 0:
		_last_action = _fleet_feedback(view)
	elif StringName(_model) in Flight.IDS:
		# Reuse the Flight Lab reference's public goal-relative controller. The
		# Workbench supplies only authored patrol endpoints and proprioception;
		# no Flight Lab arena/evaluator or privileged map is imported.
		var goal := _home + Vector2(34.0 * _direction, 0.0)
		if position.distance_to(goal) < 8.0:
			_direction = -_direction
			goal = _home + Vector2(34.0 * _direction, 0.0)
		_last_action = _teacher.action({"version":"4ly-observation/v1",
			"goal_delta_cells":goal - position, "velocity_cells_per_second":velocity,
			"arrival_radius_cells":6.0,
			"capabilities":view.get("flight", {}).get("capabilities", {}).get("capabilities", {}).duplicate(true),
			"local_obstacles":{"available":false}})
	else:
		_last_action = _script.next_action(view, delta)
	return _last_action.duplicate(true)


func _fleet_feedback(view: Dictionary) -> Dictionary:
	var position: Vector2 = view.position
	var velocity: Vector2 = view.velocity
	if (position.x - _home.x) * _direction > 32.0 \
		or (_direction > 0.0 and float(view.get("wall_right", 30.0)) < 12.0) \
		or (_direction < 0.0 and float(view.get("wall_left", 30.0)) < 12.0):
		_direction = -_direction
	var target := _home + Vector2(34.0 * _direction, 0.0)
	var desired := (target - position) * 1.1 - velocity * 1.8
	var accel: float = maxf(1.0, float(_fleet_profile.fleet_accel))
	var gravity: float = float(view.get("gravity", _fleet_profile.gravity))
	var angle: float = wrapf(float(view.get("rotation", 0.0)), -PI, PI)
	var angular: float = float(view.get("angular_velocity", 0.0))
	if Fleet.is_hoverboard(_fleet_index):
		return {"move":Vector2(clampf(desired.x / accel, -0.7, 0.7),
			clampf((desired.y - gravity + 38.0) / (accel * 0.65), -0.9, 0.9)),
			"effort":1.0, "trim":0.0, "auxiliary":true}
	var vertical: float = clampf((gravity - desired.y) / maxf(1.0, accel * maxf(0.4, cos(angle))), 0.0, 1.0)
	if bool(_fleet_profile.get("fleet_side_thrusters", false)):
		return {"move":Vector2(0.0, -vertical), "effort":1.0,
			"trim":clampf(desired.x / (accel * 0.65), -0.7, 0.7), "auxiliary":true}
	var desired_angle: float = clampf(desired.x / maxf(gravity, 30.0), -0.32, 0.32)
	return {"move":Vector2(clampf((desired_angle - angle) * 1.8 - angular * 0.35, -0.6, 0.6), -vertical),
		"effort":1.0, "auxiliary":false}


func diagnostics() -> Dictionary:
	if _ambient_configured and (_ambient_active or not _ambient_environment.is_empty()):
		return {"adapter":"workbench-ambient/v1", "model":_model, "learned":false,
			"decisions":_decisions, "last_observed_tick":_last_tick,
			"last_action":_last_action.duplicate(true), "ambient":_ambient.diagnostics(),
			"environment":_ambient_environment.duplicate(true), "actuator":_ambient_actuator.diagnostics()}
	return {"adapter":"workbench-local-feedback/v1", "model":_model,
		"decisions":_decisions, "last_observed_tick":_last_tick,
		"last_action":_last_action.duplicate(true),
		"behavior":"Thunderbowl local reflex (physical wire adapter)" if _reactive_active else "bounded flyer patrol" if _fleet_index >= 0 else "4LY goal-relative patrol; no obstacle map" if StringName(_model) in Flight.IDS else "existing physical local feedback",
		"learned":false, "reactive":_reactive.diagnostics() if _reactive_active else {},
		"script":_script.diagnostics() if not _reactive_active and _fleet_index < 0 and StringName(_model) not in Flight.IDS else {}}
