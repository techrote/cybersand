class_name CyberInToolsLiquidController
extends RefCounted

# #361 worker-owned experimental controller. It does not own a World; it may
# execute only while CyberPhysicalUsableRuntime is running on the exclusive
# simulation worker. Selection/reselection never refills its finite nozzle stock.
const PROFILE_NOZZLE: String = "in-tools-in-nozzle-v1"
const PROFILE_LEAK: String = "in-tools-leak-v1"
const CONTROLLER: String = "in-tools-liquid-v1"
const WATER: int = 3
const EMPTY: int = 0
const WALL: int = 1
const NOZZLE_USABLE: int = 1 # Existing U02 Water Lance identity.
const LEAK_USABLE: int = 9   # Existing U10 Liquid Drain identity.
const STOCK_CELLS: int = 32
const MAX_VELOCITY_Q: int = 32

var terminal: bool = false
var terminal_evidence: Dictionary = {}
var _world_instance_id: int = 0
var _native_generation: int = -1
var _policy_hash: String = ""
var _maximum: int = 0
var _mass_bits: int = -1
var _available: bool = false
var _reason: String = "native_owner_unavailable"
var _water_initial: int = 0
var _water_remaining: int = 0
var _water_admitted: int = 0
var _apertures: Dictionary = {}


func refresh(world: Object) -> Dictionary:
	if world == null or not world.is_class("CyberNativeCellWorld") \
		or not world.has_method(&"in_tools_inject_water_source") \
		or not world.has_method(&"in_tools_set_aperture"):
		_available = false
		_reason = "native_owner_unavailable"
		return observation(-1)
	var instance: int = int(world.get_instance_id())
	var generation: int = int(world.get_liquid_policy_session_generation())
	if instance != _world_instance_id or generation != _native_generation:
		_world_instance_id = instance
		_native_generation = generation
		terminal = false
		terminal_evidence.clear()
		_apertures.clear()
		var policy: Dictionary = world.get_liquid_solver_policy()
		var water: Dictionary = world.get_water_experiment_policy()
		_policy_hash = str(policy.get("policy_hash", ""))
		_mass_bits = int(water.get("mass_bits", -1))
		_maximum = int(water.get("maximum", 0))
		_available = _policy_hash.length() == 64 and _mass_bits >= 3 and _mass_bits <= 8 \
			and _maximum == (1 << _mass_bits) - 1
		_reason = "" if _available else "invalid_policy_readback"
		_water_initial = STOCK_CELLS * _maximum if _available else 0
		_water_remaining = _water_initial
		_water_admitted = 0
	if bool(world.has_failed()):
		_available = false
		_reason = "native_world_failed"
	return observation(-1)


func observation(owner: int) -> Dictionary:
	var aperture: Variant = _apertures.get(owner, null)
	return {
		"controller": CONTROLLER,
		"available": _available and not terminal,
		"reason": "owner_terminal" if terminal else _reason,
		"terminal": terminal,
		"world_instance_id": _world_instance_id,
		"native_generation": _native_generation,
		"policy_hash": _policy_hash,
		"mass_bits": _mass_bits,
		"maximum": _maximum,
		"allowed_profiles": [PROFILE_NOZZLE, PROFILE_LEAK],
		"water_units_initial": _water_initial,
		"water_units_remaining": _water_remaining,
		"water_units_admitted": _water_admitted,
		"aperture_open": aperture != null,
		"aperture_point": aperture if aperture != null else Vector2i.ZERO,
	}


func _identity_error(request: Dictionary) -> String:
	if not _available or terminal:
		return "owner_terminal" if terminal else (_reason if not _reason.is_empty() else "owner_unavailable")
	if int(request.get("world_instance_id", 0)) != _world_instance_id:
		return "world_instance"
	if int(request.get("native_generation", -1)) != _native_generation:
		return "native_generation"
	if str(request.get("policy_hash", "")) != _policy_hash:
		return "policy_hash"
	return ""


func apply_nozzle(world: Object, pose: Dictionary, request: Dictionary,
		direction: Vector2, effective_power: float, frame_tick: int) -> Dictionary:
	var result: Dictionary = _base_outcome(request, frame_tick)
	result["kind"] = "directed_in_nozzle"
	result["transport_mode"] = "inertial_cellular_source_v1"
	result["ballistic_transport"] = false
	result["water_units_added"] = 0
	result["source_credit"] = 0
	result["sink_debit"] = 0
	result["budget_before"] = _water_remaining
	result["remaining_budget"] = _water_remaining
	var error: String = _identity_error(request)
	if error.is_empty() and request.get("profile") != PROFILE_NOZZLE:
		error = "profile"
	if error.is_empty() and int(request.get("material", 0)) != WATER:
		error = "material"
	if error.is_empty() and _water_remaining < _maximum:
		error = "experimental_budget_exhausted"
	if error.is_empty() and int(request.get("quantity_budget", -1)) != _water_remaining:
		error = "quantity_budget"
	if not error.is_empty():
		result.reason = error
		return result

	var aim: Vector2 = direction.normalized()
	if aim.length_squared() < 0.999:
		result.reason = "direction"
		return result
	var speed: int = clampi(roundi(lerpf(8.0, float(MAX_VELOCITY_Q), clampf(effective_power, 0.0, 1.0))), 1, MAX_VELOCITY_Q)
	var velocity := Vector2i(roundi(aim.x * speed), roundi(aim.y * speed))
	if velocity == Vector2i.ZERO:
		result.reason = "direction"
		return result
	var point := Vector2i(Vector2(pose.get("muzzle", Vector2.ZERO)).floor()) + Vector2i(signi(velocity.x), signi(velocity.y))
	var native: Dictionary = world.in_tools_inject_water_source(point, velocity)
	result["point"] = point
	result["velocity_q"] = velocity
	result["native"] = native.duplicate(true)
	if not bool(native.get("accepted", false)):
		result.reason = str(native.get("reason", "native_refused"))
		return result
	var added: int = int(native.get("quantity_added", 0))
	if added != _maximum or added > _water_remaining:
		terminal = true
		terminal_evidence = {
			"reason": "source_accounting_mismatch",
			"request_id": request.get("request_id", ""),
			"expected": _maximum,
			"observed": added,
			"native": native.duplicate(true),
		}
		result.status = "fault"
		result.reason = "source_accounting_mismatch"
		result["water_units_added"] = maxi(0, added)
		result["source_credit"] = maxi(0, added)
		return result
	_water_remaining -= added
	_water_admitted += added
	result.status = "applied"
	result.reason = "applied"
	result["water_units_added"] = added
	result["source_credit"] = added
	result["remaining_budget"] = _water_remaining
	return result


func apply_leak(world: Object, owner: int, request: Dictionary, target: Vector2i,
		open: bool, frame_tick: int) -> Dictionary:
	var result: Dictionary = _base_outcome(request, frame_tick)
	result["kind"] = "reversible_leak"
	result["source_credit"] = 0
	result["sink_debit"] = 0
	result["quantity_delta"] = 0
	var error: String = _identity_error(request)
	if error.is_empty() and request.get("profile") != PROFILE_LEAK:
		error = "profile"
	if error.is_empty() and int(request.get("material", -1)) != 0:
		error = "material"
	if not error.is_empty():
		result.reason = error
		return result

	var point: Vector2i = target
	if not open:
		if not _apertures.has(owner):
			result.reason = "no_owned_aperture"
			return result
		point = _apertures[owner]
	var native: Dictionary = world.in_tools_set_aperture(point, open)
	result["point"] = point
	result["open"] = open
	result["native"] = native.duplicate(true)
	if not bool(native.get("accepted", false)):
		result.reason = str(native.get("reason", "native_refused"))
		return result
	if open and str(native.get("reason", "")) == "already_open" and not _apertures.has(owner):
		result.reason = "unowned_open_aperture"
		return result
	if open:
		_apertures[owner] = point
	else:
		_apertures.erase(owner)
	result.status = "applied"
	result.reason = str(native.get("reason", "applied"))
	result["aperture_open"] = open
	return result


func _base_outcome(request: Dictionary, frame_tick: int) -> Dictionary:
	return {
		"schema": "in-tools-liquid-outcome-v1",
		"status": "refused",
		"reason": "",
		"request_id": str(request.get("request_id", "")),
		"profile": str(request.get("profile", "")),
		"material": int(request.get("material", 0)),
		"world_instance_id": _world_instance_id,
		"native_generation": _native_generation,
		"policy_hash": _policy_hash,
		"physical_frame_tick": frame_tick,
	}
