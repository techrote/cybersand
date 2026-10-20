class_name CyberPhysicalUsableScript
extends RefCounted

# A policy producer, not an equipment owner. The physical session admits every
# output against the copied instance/epoch and applies all ownership changes.
const Usables = preload("res://scripts/usable_catalog.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const MAX_PATCH_CELLS: int = 289
const MAX_DELTA: float = 0.25

var _rig_id: StringName = &""
var _loadout: Dictionary = {}
var _time: float = 0.0
var _next_use: float = 0.7
var _next_alternate: float = 0.0
var _equipment_epoch: int = -1
var _last_state: String = ""
var _state_since: float = 0.0
var _last_refusal: String = ""
var _phase: String = "travel"
var _home: Vector2 = Vector2.ZERO
var _direction: float = 1.0
var _deployments: int = 0
var _recoveries: int = 0
var _use_attempts: int = 0


func configure(rig_id: StringName, origin: Vector2, actor_index: int = 0) -> bool:
	_loadout = Loadouts.entry(rig_id)
	if _loadout.is_empty() or not origin.is_finite() or actor_index < 0:
		return false
	_rig_id = rig_id
	_home = origin
	_direction = 1.0 if actor_index % 2 == 0 else -1.0
	_time = 0.0
	_next_use = 0.7 + float(actor_index % 7) * 0.11
	_next_alternate = 0.0
	_equipment_epoch = -1
	_last_state = ""
	_state_since = 0.0
	_last_refusal = ""
	_phase = "travel"
	_deployments = 0
	_recoveries = 0
	_use_attempts = 0
	return true


func cancel() -> void:
	_next_use = maxf(_next_use, _time + 0.3)
	_next_alternate = maxf(_next_alternate, _time + 0.3)
	_phase = "rearm"


func diagnostics() -> Dictionary:
	return {"version": 1, "rig_id": str(_rig_id), "phase": _phase,
		"use_attempts": _use_attempts, "deployments_observed": _deployments,
		"pickups_observed": _recoveries, "last_refusal": _last_refusal,
		"strategy": str(_loadout.get("strategy", ""))}


func apply(observation: Dictionary, locomotion: Dictionary, delta: float) -> Dictionary:
	var action: Dictionary = locomotion.duplicate(true)
	# Player movement demonstrations never decide when an equipped tool fires.
	# A later explicit human/policy equipment command retains its normal owner.
	if str(_loadout.get("strategy", "")) == "human":
		return action
	var equipment: Variant = observation.get("equipment", {})
	if _loadout.is_empty() or not equipment is Dictionary or equipment.is_empty() \
		or not is_finite(delta) or delta <= 0.0 or delta > MAX_DELTA:
		return action
	if bool(observation.get("suspended", false)) or not str(observation.get("fault", "")).is_empty():
		cancel()
		return action
	var index: int = int(equipment.get("usable_index", -1))
	if index < 0 or index >= Usables.count():
		return action
	var position: Variant = observation.get("position", observation.get("centre", Vector2.INF))
	var velocity: Variant = observation.get("velocity", Vector2.INF)
	if not position is Vector2 or not velocity is Vector2 \
		or not position.is_finite() or not velocity.is_finite():
		return action
	_time += delta
	var state: String = str(equipment.get("state", "none"))
	var epoch: int = int(equipment.get("equipment_epoch", -1))
	var request: Dictionary = {"usable_index": index,
		"instance_id": str(equipment.get("instance_id", "")), "equipment_epoch": epoch,
		"trigger": false, "alternate": false, "drop": false, "attach": false,
		"power": float(_loadout.power), "aim": Vector2(_direction, 0.0)}
	# Equipment has its own aim: steering a nozzle must not retarget a flight
	# thruster, rocket-jump impulse or rope cast in the locomotion controller.
	action["equipment"] = request
	action["tool"] = false
	action["release_usable"] = false
	action["attach_usable"] = false
	if state != _last_state:
		if state in ["released", "deployed", "fixed"] and _last_state == "held":
			_deployments += 1
		elif state == "held" and _last_state in ["released", "deployed", "fixed"]:
			_recoveries += 1
			_next_use = _time + 2.5
		_last_state = state
		_state_since = _time
	if epoch != _equipment_epoch:
		_equipment_epoch = epoch
		_phase = "rearm"
		return action
	var result: String = str(equipment.get("last_result", ""))
	if result in ["blocked", "no-charge", "cooldown", "not-ready", "source_blocked", "blocked-output"]:
		_last_refusal = result
	var definition: Dictionary = Usables.entry(index)
	if state in ["released", "deployed", "fixed"]:
		_recover_device(observation, equipment, action, request, position, velocity)
		return action
	if not bool(equipment.get("attached", state == "held")):
		return action
	if str(definition.category) == "object":
		_processor(observation, equipment, action, request, position, velocity)
		return action
	_phase = "patrol"
	var move: Vector2 = action.get("move", Vector2.ZERO)
	if absf(move.x) > 0.2:
		_direction = signf(move.x)
	var target: Vector2 = _target(observation, definition, position)
	var aim: Vector2 = target - Vector2(equipment.get("muzzle", position))
	if aim.length_squared() < 0.001:
		aim = Vector2(_direction, 0.15)
	var strategy: String = str(_loadout.strategy)
	var is_drop: bool = strategy == "drop"
	if is_drop:
		# A downward launch from the physical port represents a released payload;
		# reserve forward speed for flight instead of firing along propulsion aim.
		aim = Vector2(clampf(velocity.x * 0.007, -0.35, 0.35), 1.0)
	elif str(definition.category) == "projectile":
		var flight_time: float = minf(0.65, aim.length() / maxf(40.0, float(definition.get("speed", 120.0))))
		aim.y -= 0.5 * float(definition.get("gravity", 0.0)) * flight_time * flight_time
	request.aim = aim.normalized()
	var angular_speed: float = absf(float(observation.get("angular_velocity", 0.0)))
	var upright: bool = absf(wrapf(float(observation.get("rotation", 0.0)), -PI, PI)) < 1.0
	var steady: bool = angular_speed < 3.5 and (upright or not is_drop)
	var clearance: float = float(observation.get("ground_distance", 0.0))
	var drop_window: bool = not is_drop or (not bool(observation.get("grounded", false)) and clearance >= 6.0)
	if bool(equipment.get("pending", false)):
		_phase = "wait-ready"
		return action
	# Early activation controls an already committed payload. Its launch cost,
	# launch cooldown and current muzzle clearance do not apply a second time.
	if _time >= _next_alternate and _eligible_alternate(equipment, definition):
		request.alternate = true
		_next_alternate = _time + 1.0
		_phase = "activate-payload"
		return action
	if not bool(equipment.get("ready", false)) \
		or float(equipment.get("charge", 0.0)) < float(definition.get("cost", 0.0)):
		_phase = "wait-ready"
		return action
	if _time >= _next_use and steady and drop_window:
		request.trigger = true
		_use_attempts += 1
		_phase = "use"
		var interval: float = 1.1 if str(definition.category) == "projectile" else 0.65
		if strategy == "excavate" and bool(observation.get("blocked", false)):
			interval = 0.3
		_next_use = _time + maxf(interval, float(definition.get("cooldown", 0.1)) + 0.2)
		_next_alternate = _time + 0.3
	return action


func _processor(observation: Dictionary, equipment: Dictionary, action: Dictionary,
		request: Dictionary, position: Vector2, velocity: Vector2) -> void:
	if _time < _next_use or _time - _state_since < float(_loadout.get("transport_seconds", 1.4)):
		_phase = "transport"
		return
	# Let the locomotion producer finish an in-progress charged jump before
	# taking a low-speed placement window. Cancelling its held primary here
	# would itself release an impulse and undermine the placement decision.
	if float(observation.get("charge", 0.0)) > 0.001:
		_phase = "finish-charge"
		return
	_phase = "lower-and-place"
	var flight: bool = bool(observation.get("flight_mode", false)) \
		or _rig_id in [&"heavylift", &"tandem", &"qwen"]
	var grounded: bool = bool(observation.get("grounded", false))
	var clearance: float = float(observation.get("ground_distance", 99.0))
	# Arrest translation using normal actuator input. A lowered suspended load
	# remains physically simulated; the policy never pins or moves it directly.
	action.move.x = clampf(-velocity.x * 0.07, -0.65, 0.65)
	if flight and not grounded:
		action.move.y = clampf((clearance - 13.0) * 0.035 - velocity.y * 0.05, -0.5, 0.45)
	# A traversal boost chosen before this placement correction must not fight
	# the descent. Assisted flight and stabilization remain ordinary channels.
	action.primary = false
	if flight:
		action.secondary = true
		action.trim = clampf(-float(observation.get("rotation", 0.0)) * 0.6 \
			- float(observation.get("angular_velocity", 0.0)) * 0.15, -0.75, 0.75)
	request.aim = Vector2.DOWN
	if (grounded or clearance < 24.0) and velocity.length() < 22.0 \
		and absf(float(observation.get("angular_velocity", 0.0))) < 1.7 \
		and bool(equipment.get("ready", false)) and not bool(equipment.get("pending", false)):
		request.trigger = true
		_next_use = _time + 1.0
		_use_attempts += 1
		_phase = "deploy"
	elif _time - _state_since > 8.0 and position.distance_to(_home) > 80.0:
		# A failed delivery is recoverable: steer back toward the local start.
		action.move.x = clampf((_home.x - position.x) * 0.025 - velocity.x * 0.04, -0.7, 0.7)


func _recover_device(observation: Dictionary, equipment: Dictionary, action: Dictionary,
		request: Dictionary, position: Vector2, velocity: Vector2) -> void:
	var device: Variant = equipment.get("position", Vector2.INF)
	if not device is Vector2 or not device.is_finite():
		return
	var state: String = str(equipment.get("state", "released"))
	if bool(observation.get("flight_mode", false)):
		action.primary = false
		action.secondary = true
	if state == "released" and bool(equipment.get("deploy_intent", false)):
		_phase = "wait-for-settle"
		action.move.x = clampf((device.x - position.x) * 0.018 - velocity.x * 0.035, -0.35, 0.35)
		return
	var processor: Variant = equipment.get("processor_state", {})
	var jammed: bool = processor is Dictionary and str(processor.get("state", "")) in ["blocked", "jammed", "blocked-output"]
	var service_wait: float = 2.2 if jammed else 4.0
	if state != "released" and _time - _state_since < service_wait:
		_phase = "inspect-processor"
		action.move.x = clampf((device.x - position.x) * 0.018 - velocity.x * 0.035, -0.35, 0.35)
		return
	_phase = "recover"
	var target: Vector2 = device
	var grip: Variant = equipment.get("grip_position")
	var parts: Variant = observation.get("parts", [])
	var host_index: int = int(equipment.get("host_part", 0))
	if grip is Vector2 and grip.is_finite():
		target -= grip - position
	elif parts is Array and host_index >= 0 and host_index < parts.size():
		var host: Variant = parts[host_index]
		if host is Dictionary and host.get("position") is Vector2:
			# Approach using the actual mount's owner, not an axis-aligned hull.
			target -= Vector2(host.position) - position
	action.move.x = clampf((target.x - position.x) * 0.075 - velocity.x * 0.07, -0.8, 0.8)
	if _rig_id in [&"heavylift", &"tandem", &"qwen"]:
		action.move.y = clampf((target.y - position.y - 4.0) * 0.045 - velocity.y * 0.065, -0.6, 0.5)
	else:
		action.primary = bool(observation.get("blocked", false)) and bool(observation.get("grounded", false))
	request.aim = (device - position).normalized()
	if bool(equipment.get("reattach_ready", false)) and not bool(equipment.get("pending", false)):
		request.attach = true
		_phase = "pickup"


func _eligible_alternate(equipment: Dictionary, definition: Dictionary) -> bool:
	var id: String = str(definition.id)
	if id not in ["sticky_delay_charge", "timer_airburst", "oil_igniter"]:
		return false
	var projectiles: Variant = equipment.get("projectiles", [])
	if not projectiles is Array or projectiles.size() > 64:
		return false
	for projectile: Variant in projectiles:
		if not projectile is Dictionary or int(projectile.get("usable_index", -1)) != Usables.index_for(StringName(id)):
			continue
		var state: String = str(projectile.get("state", ""))
		if (id == "sticky_delay_charge" and state == "stuck") \
			or (id == "oil_igniter" and state == "primed") \
			or (id == "timer_airburst" and state == "flight" and float(projectile.get("age", 0.0)) > 0.2):
			return true
	return false


func _target(observation: Dictionary, definition: Dictionary, origin: Vector2) -> Vector2:
	# Near-contact excavation should approach the seam ahead of the carrier;
	# aiming below its low nozzle would repeatedly hit the protected floor.
	var fallback := origin + Vector2(_direction * 28.0,
		0.0 if str(definition.get("operation", "")) in ["bore", "line_cut", "glass_cut"] else 8.0)
	var patch: Variant = observation.get("cell_patch", {})
	if not patch is Dictionary or not patch.get("origin") is Vector2i or not patch.get("size") is Vector2i:
		return fallback
	var size: Vector2i = patch.size
	var materials: Variant = patch.get("materials", PackedByteArray())
	if not materials is PackedByteArray or size.x < 1 or size.y < 1 \
		or size.x * size.y > MAX_PATCH_CELLS or materials.size() != size.x * size.y:
		return fallback
	var operation: String = str(definition.get("operation", ""))
	var best: float = INF
	var selected: Vector2 = fallback
	for index: int in range(materials.size()):
		var material: int = materials[index]
		var suitable: bool = material > 1
		if operation == "powder_sink":
			suitable = material in [2, 14, 23, 26, 27]
		elif operation == "liquid_sink":
			suitable = material in [3, 8, 12, 16, 20, 21, 24, 32, 33, 36]
		elif operation == "glass_cut":
			suitable = material in [35, 55, 71, 72]
		elif str(definition.category) == "tool" and operation not in ["line_cut", "bore"]:
			suitable = material == 0
		if not suitable:
			continue
		var point := Vector2(patch.origin) + Vector2(index % size.x, floori(float(index) / float(size.x))) + Vector2(0.5, 0.5)
		var distance: float = origin.distance_squared_to(point)
		if distance < 16.0 or (point.x - origin.x) * _direction < -2.0:
			continue
		if distance < best:
			best = distance
			selected = point
	return selected
