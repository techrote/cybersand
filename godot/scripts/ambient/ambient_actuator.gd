extends RefCounted

# AMBIENT-001 value-only adapter. The existing physical rig and command owner
# retain every force, resource, contact, lease and motor decision. In particular,
# 4LY accepts exactly one move key; a ground rig never acquires a vertical motor.
const Physical = preload("res://scripts/physical_actor_catalog.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")

var _model: String = ""
var _capabilities: Dictionary = {}
var _profile: Dictionary = {}
var _last: Dictionary = {}


static func capabilities(model: String) -> Dictionary:
	var result := {"version":"ambient-capabilities/v1", "model":model,
		"supported":false, "horizontal":false, "ground":false, "vertical":false,
		"jump":false, "effort_channel":false,
		"family":"unavailable", "reason":"No qualified ambient adapter for this rig."}
	if not Physical.has_rig(StringName(model)) or model == str(Physical.PASSIVE_BARREL):
		return result
	if StringName(model) in Flight.IDS:
		result.merge({"supported":true, "horizontal":true, "vertical":true,
			"family":"assisted_flight",
			"reason":"Existing 4LY world-frame desired velocity uses pace; effort is not an action channel. Live neutral brakes and hovers."}, true)
		return result
	var profile: Dictionary = Physical.entry(StringName(model)).get("profile", {})
	var family := str(profile.get("movement", ""))
	if profile.has("player_controller") or family not in ["ground", "walk", "roll"]:
		return result
	result.merge({"supported":true, "horizontal":true, "ground":true, "effort_channel":true,
		"family":"wheeled" if family == "roll" else "ground",
		"jump":str(profile.get("primary", "")) == "jump",
		"reason":"Existing horizontal propulsion and ordinary supported jump only; vertical intent is projected away."}, true)
	return result


static func supports(model: String) -> bool:
	return bool(capabilities(model).supported)


func configure(model: String) -> bool:
	var caps := capabilities(model)
	if not bool(caps.supported): return false
	_model = model
	_capabilities = caps
	_profile = Physical.entry(StringName(model)).get("profile", {}).duplicate(true)
	_last.clear()
	return true


func reset() -> void:
	_last.clear()


func next_action(intent: Dictionary, view: Dictionary) -> Dictionary:
	_last.clear()
	if _model.is_empty() or view.get("representation") != "articulated-rapier" \
		or str(view.get("model", "")) != _model or bool(view.get("suspended", true)) \
		or not str(view.get("fault", "")).is_empty(): return {}
	var direction: Variant = intent.get("direction")
	var velocity: Variant = view.get("velocity")
	if not direction is Vector2 or not direction.is_finite() \
		or not velocity is Vector2 or not velocity.is_finite(): return {}
	for key: String in ["pace", "effort"]:
		var number: Variant = intent.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) \
			or float(number) < 0.0 or float(number) > 1.0: return {}
	if intent.has("primary") and not intent.primary is bool: return {}
	direction = direction.limit_length(1.0)
	var pace: float = float(intent.pace)
	if bool(_capabilities.vertical):
		# The admitted 4LY controller owns physical velocity tracking, braking,
		# gravity compensation, thrust slew and attitude. No legacy keys here.
		_last = {"move":Vector2(direction) * pace}
		return _last.duplicate(true)
	var rotation: Variant = view.get("rotation")
	var angular: Variant = view.get("angular_velocity")
	if not (rotation is int or rotation is float) or not is_finite(float(rotation)) \
		or not (angular is int or angular is float) or not is_finite(float(angular)): return {}
	var horizontal: float = Vector2(direction).x
	var move := 0.0
	var trim := 0.0
	var effort := float(intent.effort)
	if pace > 0.0 and absf(horizontal) > 0.00001 and effort > 0.0:
		# Same local velocity feedback and attitude feedback as the accepted
		# physical script. Pace is a request, never a guaranteed travel speed.
		var speed := maxf(1.0, float(_profile.get("speed", 1.0)))
		move = clampf((horizontal * pace * speed - velocity.x * 0.30) / (speed * 0.72), -1.0, 1.0)
		var tilt := wrapf(float(rotation), -PI, PI)
		trim = clampf(-tilt * 0.45 - float(angular) * 0.18, -0.85, 0.85)
		if str(_capabilities.family) == "wheeled":
			trim = clampf(signf(horizontal) * 0.2 - float(angular) * 0.10, -0.7, 0.7)
	else:
		effort = 0.0
	var jump := bool(intent.get("primary", false)) and bool(_capabilities.jump) \
		and bool(view.get("grounded", false)) and effort > 0.0
	_last = {"move":Vector2(move, 0.0), "aim":Vector2(signf(horizontal), 0.0),
		"effort":effort, "trim":trim, "primary":jump}
	return _last.duplicate(true)


func diagnostics() -> Dictionary:
	return {"version":"ambient-actuator/v1", "capabilities":_capabilities.duplicate(true),
		"last_action":_last.duplicate(true), "motor_tuning_changed":false,
		"equipment_actions":false, "teleport_authority":false}
