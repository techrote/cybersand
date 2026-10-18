extends SceneTree

# Producer-level feedback histories. Real body motion and joint bounds remain
# covered by test_physical_actor_rigs; these histories isolate the decisions
# that a physical fixture cannot reliably place at an exact phase.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Pilot = preload("res://scripts/physical_actor_script.gd")
var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_ACTOR_SCRIPT: " + message)


func _observation(id: StringName) -> Dictionary:
	return {"rig_id": id, "epoch": 1, "centre": Vector2(100, 80), "position": Vector2(100, 80),
		"velocity": Vector2.ZERO, "rotation": 0.0, "angular_velocity": 0.0,
		"grounded": true, "contact_normal": Vector2.UP, "ground_distance": 0.5,
		"wall_left": false, "wall_right": false, "ceiling_distance": 80.0,
		"gripped": false, "energy": 1.0, "charge": 1.0, "cooldown": 0.0,
		"rope_attached": false, "anchor": Vector2(100, 40), "rope_length": 40.0,
		"tension": 0.0, "blocked": false, "powered": true, "mode": 0,
		"tool_ready": true, "gravity": 156.0, "parts": [], "joints": []}


func _pilot(id: StringName):
	var pilot = Pilot.new()
	_check(pilot.configure(id, Vector2(100, 80)), "pilot configuration refused " + str(id))
	return pilot


func _test_failed_vault_and_route_progress() -> void:
	var pilot = _pilot(&"runner")
	var blocked: Dictionary = _observation(&"runner")
	blocked.wall_right = 2.0
	var reversed_at: int = -1
	var reversals: int = 0
	var previous_direction: float = 1.0
	for tick: int in range(28):
		# A seven-decision ascent followed by descent makes the body move a
		# substantial distance in every progress window without passing a wall.
		var phase: int = tick % 14
		var height: float = float(phase if phase <= 7 else 14 - phase) * 3.0
		blocked.centre = Vector2(100, 80 - height)
		blocked.position = blocked.centre
		blocked.velocity = Vector2(0, -30 if phase < 7 else 30)
		blocked.grounded = phase == 0
		blocked.contact_normal = Vector2.UP if blocked.grounded else Vector2.ZERO
		var action: Dictionary = pilot.next_action(blocked, 0.1)
		var direction: float = pilot.diagnostics().direction
		if direction != previous_direction:
			reversals += 1
		previous_direction = direction
		if action.move.x < -0.5 and reversed_at < 0:
			reversed_at = tick
	_check(reversed_at >= 5 and reversed_at < 20,
		"repeated failed vaults need a deliberate escape after allowing an initial attempt")
	_check(reversals == 1, "a stationary wall contact causes indecisive direction chatter")

	var advancing = _pilot(&"runner")
	var retreating = _pilot(&"runner")
	var forward: Dictionary = _observation(&"runner")
	var backward: Dictionary = forward.duplicate(true)
	for tick: int in range(20):
		forward.centre.x = 100.0 + float(tick) * 0.4
		forward.position = forward.centre
		forward.velocity = Vector2(4, 0)
		backward.centre.x = 100.0 - float(tick) * 0.4
		backward.position = backward.centre
		backward.velocity = Vector2(-4, 0)
		advancing.next_action(forward, 0.1)
		retreating.next_action(backward, 0.1)
	_check(int(advancing.diagnostics().recovery_count) == 0,
		"successful low-speed strides are mistaken for a stall")
	_check(float(retreating.diagnostics().direction) < 0.0,
		"being carried away from the patrol target counts as successful progress")

	var winch = _pilot(&"winchbug")
	var hauling: Dictionary = _observation(&"winchbug")
	hauling.rope_attached = true
	hauling.grounded = false
	hauling.contact_normal = Vector2.ZERO
	hauling.wall_right = 2.0
	hauling.velocity = Vector2(0, -5)
	for tick: int in range(20):
		hauling.centre.y = 80.0 - float(tick) * 0.5
		hauling.position = hauling.centre
		winch.next_action(hauling, 0.1)
	_check(int(winch.diagnostics().recovery_count) == 0,
		"useful attached upward hauling is mistaken for failed horizontal travel")


func _test_charge_pilots() -> void:
	for id: StringName in [&"pouncer", &"bonsai", &"inchworm"]:
		var pilot = _pilot(id)
		var observation: Dictionary = _observation(id)
		var previous_hold: bool = false
		var hold_length: int = 0
		var longest_hold: int = 0
		var releases: int = 0
		for tick: int in range(24):
			observation.centre.x = 100.0 + float(tick) * 0.4
			observation.position = observation.centre
			observation.velocity.x = 4.0
			var action: Dictionary = pilot.next_action(observation, 0.1)
			if action.primary:
				hold_length += 1
				longest_hold = maxi(longest_hold, hold_length)
			else:
				releases += int(previous_hold)
				hold_length = 0
			previous_hold = action.primary
		_check(longest_hold >= 3 and releases >= 1,
			str(id) + " needs a visible committed coil followed by an intentional release")
		pilot.reset(Vector2(100, 80))
		observation = _observation(id)
		observation.energy = 0.05
		var spent: bool = false
		for _tick: int in range(10):
			spent = bool(pilot.next_action(observation, 0.1).primary) or spent
		_check(not spent, str(id) + " repeatedly arms expensive leaps with a depleted reserve")
		observation.energy = 0.5
		var recovered: bool = false
		for _tick: int in range(8):
			recovered = bool(pilot.next_action(observation, 0.1).primary) or recovered
		_check(recovered, str(id) + " never resumes its characteristic action after recharge")
		pilot.cancel()
		observation.suspended = true
		_check(pilot.next_action(observation, 0.1) == Pilot.neutral_action(),
			str(id) + " cancellation preserves a charged action")


func _test_rope_and_flight_choices() -> void:
	var takeoff = _pilot(&"swinger")
	var low_line: Dictionary = _observation(&"swinger")
	low_line.rope_attached = true
	var first_pull: Dictionary = takeoff.next_action(low_line, 0.1)
	_check(first_pull.reel > 0.5, "a floor-start rope pilot pays out slack instead of establishing lift")
	low_line.grounded = false
	low_line.contact_normal = Vector2.ZERO
	low_line.centre.y = 78.0
	low_line.position = low_line.centre
	low_line.velocity = Vector2(24, -10)
	var early_release: bool = false
	for _tick: int in range(6):
		early_release = bool(takeoff.next_action(low_line, 0.1).secondary) or early_release
	_check(not early_release, "a floor-start rope pilot drops the line before its initial lift is useful")
	var swinger = _pilot(&"swinger")
	var winch = _pilot(&"winchbug")
	var swinging: Dictionary = _observation(&"swinger")
	swinging.grounded = false
	swinging.contact_normal = Vector2.ZERO
	swinging.rope_attached = true
	swinging.velocity = Vector2(24, -10)
	var hauling: Dictionary = swinging.duplicate(true)
	hauling.rig_id = &"winchbug"
	var release: bool = false
	var winch_release: bool = false
	var winch_reel: float = 0.0
	for tick: int in range(8):
		swinging.centre = Vector2(100 + tick, 80 - tick)
		swinging.position = swinging.centre
		hauling.centre = swinging.centre
		hauling.position = hauling.centre
		var swing_action: Dictionary = swinger.next_action(swinging, 0.1)
		var winch_action: Dictionary = winch.next_action(hauling, 0.1)
		release = release or swing_action.secondary
		winch_release = winch_release or winch_action.auxiliary
		winch_reel = winch_action.reel
	_check(release, "Swinger misses a useful rising launch window")
	_check(not winch_release and winch_reel > 0.5,
		"Winchbug copies the swing launch instead of deliberately hauling")

	var copter = _pilot(&"copter")
	var ceiling: Dictionary = _observation(&"copter")
	ceiling.grounded = false
	ceiling.contact_normal = Vector2.ZERO
	ceiling.ceiling_distance = 2.0
	ceiling.velocity = Vector2(15, -20)
	var clearance: Dictionary = copter.next_action(ceiling, 0.1)
	_check(clearance.move.y > 0.0 and not clearance.primary,
		"Copter keeps boosting upward into its observed ceiling")
	ceiling.rotation = 1.2
	ceiling.angular_velocity = 3.0
	var recovery: Dictionary = copter.next_action(ceiling, 0.1)
	_check(recovery.trim < 0.0 and recovery.secondary and absf(recovery.move.x) < 0.5,
		"Copter does not trade translation for a controlled recovery")
	var duet = _pilot(&"gemini")
	var inverted: Dictionary = _observation(&"gemini")
	inverted.rotation = PI - 0.1
	var safe_thrust: Dictionary = duet.next_action(inverted, 0.1)
	_check(not safe_thrust.primary and not safe_thrust.secondary and not safe_thrust.auxiliary,
		"Duet commands inverted thrust instead of recovering its attitude")


func _payload_observation(offset: Vector2, relative_velocity: Vector2) -> Dictionary:
	var observation: Dictionary = _observation(&"heavylift")
	observation.grounded = false
	observation.contact_normal = Vector2.ZERO
	observation.centre = Vector2(100, 52)
	observation.position = observation.centre
	observation.parts = [{"id": "payload", "index": 6, "detached": false,
		"position": observation.centre + offset, "velocity": relative_velocity}]
	observation.joints = [{"id": "sling_pivot", "enabled": true, "a": 0, "b": 5},
		{"id": "payload_pin", "enabled": true, "a": 5, "b": 6}]
	return observation


func _payload_action(observation: Dictionary) -> Dictionary:
	var pilot = _pilot(&"heavylift")
	return pilot.next_action(observation, 0.1)


func _test_payload_feedback() -> void:
	var right: Dictionary = _payload_observation(Vector2(4, 8), Vector2(12, 0))
	var left: Dictionary = _payload_observation(Vector2(-4, 8), Vector2(-12, 0))
	var still: Dictionary = _payload_observation(Vector2(0, 8), Vector2.ZERO)
	var right_action: Dictionary = _payload_action(right)
	var left_action: Dictionary = _payload_action(left)
	var still_action: Dictionary = _payload_action(still)
	_check(right_action.move.x > left_action.move.x + 0.2,
		"Heavylift ignores the direction of its outward payload swing")
	_check(left_action.move.x < still_action.move.x,
		"Heavylift accelerates away from a swinging load without easing its route demand")
	var passing_right: Dictionary = _payload_observation(Vector2(0, 8), Vector2(12, 0))
	var passing_left: Dictionary = _payload_observation(Vector2(0, 8), Vector2(-12, 0))
	_check(_payload_action(passing_right).move.x > _payload_action(passing_left).move.x + 0.15,
		"payload rate feedback disappears when the sling crosses the vertical")
	var fast: Dictionary = _payload_observation(Vector2(7, 3), Vector2(100000, -100000))
	var bounded: Dictionary = _payload_action(fast)
	_check(bounded.move.is_finite() and absf(bounded.move.x) <= 0.8,
		"extreme optional payload velocity creates an unbounded flight request")
	var absent: Dictionary = _observation(&"heavylift")
	absent.centre = Vector2(100, 52)
	absent.position = absent.centre
	absent.grounded = false
	absent.contact_normal = Vector2.ZERO
	var fallback: Dictionary = _payload_action(absent)
	for invalid: String in ["released", "connection", "nonfinite", "missing_velocity"]:
		var observation: Dictionary = right.duplicate(true)
		match invalid:
			"released": observation.parts[0].detached = true
			"connection": observation.joints[1].enabled = false
			"nonfinite": observation.parts[0].position = Vector2(NAN, 60)
			"missing_velocity": observation.parts[0].erase("velocity")
		_check(_payload_action(observation) == fallback,
			invalid + " cargo still steers its former carrier or poisons ordinary flight")
	var saved: Dictionary = right.duplicate(true)
	_payload_action(right)
	_check(right == saved, "payload feedback mutates a copied observation")


func _run() -> void:
	_test_failed_vault_and_route_progress()
	_test_charge_pilots()
	_test_rope_and_flight_choices()
	_test_payload_feedback()
	print("PHYSICAL_ACTOR_SCRIPT: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
