extends SceneTree

const Profiles = preload("res://scripts/player_environment_profiles.gd")

var _failed: bool = false


class FreeWorld:
	extends RefCounted

	func box_collides(_origin: Vector2, _size: Vector2) -> bool:
		return false

	func character_box_collides(_origin: Vector2, _size: Vector2, _mode: int) -> bool:
		return false


class TraversalWorld:
	extends RefCounted

	var obstacle_height: int = 1

	func _init(height: int) -> void:
		obstacle_height = height

	func box_collides(origin: Vector2, _size: Vector2) -> bool:
		return (
			origin.x > 0.0001
			and origin.y > -float(obstacle_height) + 0.0001
		)

	func character_box_collides(origin: Vector2, size: Vector2, mode: int) -> bool:
		if mode == 1:
			return true
		if mode == 2:
			return box_collides(origin, size)
		return false


class ImpactWorld:
	extends RefCounted

	var received_impact_speed: float = -1.0

	func box_collides(_origin: Vector2, _size: Vector2) -> bool:
		return false

	func character_box_collides(_origin: Vector2, _size: Vector2, mode: int) -> bool:
		return mode == 1

	func character_disturb_granular(
		_origin: Vector2,
		_size: Vector2,
		impact_speed: float
	) -> int:
		received_impact_speed = impact_speed
		return 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PENV-001: " + message)


func _run() -> void:
	_test_profiles()
	_test_gravity_and_terminal_independence()
	_test_mass_and_granular_sensitivity()
	_test_traversal_bands()
	quit(1 if _failed else 0)


func _test_profiles() -> void:
	var baseline: Dictionary = Profiles.preset(Profiles.PRESET_CURRENT)
	_expect(float(baseline.effective_mass) == 1.0, "baseline mass drifted")
	_expect(float(baseline.gravity_acceleration) == 92.0, "baseline gravity drifted")
	_expect(float(baseline.terminal_fall_speed) == 86.0, "baseline terminal speed drifted")
	_expect(float(baseline.jetpack_acceleration) == 180.0, "baseline jetpack acceleration drifted")
	_expect(float(baseline.jetpack_max_rise_speed) == 60.0, "baseline jetpack rise limit drifted")
	_expect(int(baseline.step_height) == 1, "baseline one-pixel step drifted")
	_expect(int(baseline.knee_height) == 1, "baseline knee threshold must not widen behavior")
	_expect(int(baseline.clamber_height) == 1, "baseline clamber threshold must not widen behavior")
	_expect(str(baseline.hash).length() == 64, "baseline profile lacks stable hash identity")

	var earth: Dictionary = Profiles.preset(Profiles.PRESET_EARTH_FEEL)
	_expect(float(earth.gravity_acceleration) == 184.0, "Earth-feel candidate is not 2x baseline gravity")
	_expect(
		float(earth.terminal_fall_speed) == float(baseline.terminal_fall_speed),
		"Earth-feel candidate coupled terminal speed to gravity"
	)

	var invalid: Dictionary = baseline.duplicate(true)
	invalid.step_height = 4
	invalid.knee_height = 2
	_expect(
		not Profiles.resolve(invalid).get("ok", false),
		"invalid traversal ordering was accepted"
	)

	var liquid_custom: Dictionary = baseline.duplicate(true)
	liquid_custom.id = "liquid-identity-check"
	liquid_custom.liquid_response_sensitivity = 3.0
	var liquid_resolved: Dictionary = Profiles.resolve(liquid_custom)
	_expect(liquid_resolved.get("ok", false), "liquid sensitivity custom profile rejected")
	if liquid_resolved.get("ok", false):
		_expect(
			float(liquid_resolved.profile.liquid_response_sensitivity) == 3.0,
			"liquid sensitivity was not independently retained"
		)
		_expect(
			"no-water-semantic-hook" in str(liquid_resolved.profile.liquid_response_identity),
			"liquid profile identity no longer marks the Water semantic boundary"
		)


func _test_gravity_and_terminal_independence() -> void:
	var baseline_character := CyberSampledCharacter.new()
	baseline_character.configure_profile(Profiles.preset(Profiles.PRESET_CURRENT))
	baseline_character.reset(Vector2.ZERO)
	baseline_character.simulate(0.1, 0.0, false, FreeWorld.new())
	_expect(
		absf(baseline_character.velocity.y - 9.2) < 0.0001,
		"baseline gravity no longer reproduces the pre-PENV acceleration"
	)

	var earth_character := CyberSampledCharacter.new()
	earth_character.configure_profile(Profiles.preset(Profiles.PRESET_EARTH_FEEL))
	earth_character.reset(Vector2.ZERO)
	earth_character.simulate(0.1, 0.0, false, FreeWorld.new())
	_expect(
		absf(earth_character.velocity.y - 18.4) < 0.0001,
		"Earth-feel candidate did not apply independent 2x gravity"
	)

	var custom: Dictionary = Profiles.preset(Profiles.PRESET_EARTH_FEEL)
	custom.id = "terminal-independent"
	custom.terminal_fall_speed = 10.0
	var resolved: Dictionary = Profiles.resolve(custom)
	_expect(resolved.get("ok", false), "independent terminal-speed profile rejected")
	if not resolved.get("ok", false):
		return
	var capped_character := CyberSampledCharacter.new()
	capped_character.configure_profile(resolved.profile)
	capped_character.reset(Vector2.ZERO)
	capped_character.velocity.y = 9.0
	capped_character.simulate(0.1, 0.0, false, FreeWorld.new())
	_expect(
		absf(capped_character.velocity.y - 10.0) < 0.0001,
		"terminal speed did not remain independently adjustable"
	)


func _test_mass_and_granular_sensitivity() -> void:
	var base: Dictionary = Profiles.preset(Profiles.PRESET_CURRENT)
	var character := CyberSampledCharacter.new()
	var world := ImpactWorld.new()

	var compensated: Dictionary = base.duplicate(true)
	compensated.id = "mass-2-sensitivity-half"
	compensated.effective_mass = 2.0
	compensated.granular_response_sensitivity = 0.5
	var resolved: Dictionary = Profiles.resolve(compensated)
	_expect(resolved.get("ok", false), "mass/sensitivity profile rejected")
	if not resolved.get("ok", false):
		return
	character.configure_profile(resolved.profile)
	character.reset(Vector2.ZERO)
	character.velocity.y = 30.0
	character.move_vertical(1.0, world)
	_expect(
		absf(world.received_impact_speed - 30.0) < 0.0001,
		"mass and granular sensitivity are not separate multiplicative inputs"
	)

	var heavy: Dictionary = compensated.duplicate(true)
	heavy.granular_response_sensitivity = 1.0
	resolved = Profiles.resolve(heavy)
	character.configure_profile(resolved.profile)
	character.reset(Vector2.ZERO)
	character.velocity.y = 30.0
	world.received_impact_speed = -1.0
	character.move_vertical(1.0, world)
	_expect(
		absf(world.received_impact_speed - 60.0) < 0.0001,
		"effective mass did not increase the existing bounded granular response request"
	)


func _test_traversal_bands() -> void:
	var baseline: Dictionary = Profiles.preset(Profiles.PRESET_CURRENT)
	var character := CyberSampledCharacter.new()
	character.configure_profile(baseline)
	character.position = Vector2.ZERO
	character.velocity.x = 10.0
	character.grounded = true
	character.move_horizontal(1.0, TraversalWorld.new(1))
	_expect(
		character.position.is_equal_approx(Vector2(1.0, -1.0)),
		"one-pixel baseline step no longer follows the historical full-speed path"
	)

	character.position = Vector2.ZERO
	character.velocity.x = 10.0
	character.grounded = true
	character.move_horizontal(1.0, TraversalWorld.new(2))
	_expect(
		character.position.is_equal_approx(Vector2.ZERO),
		"exact-current profile unexpectedly traversed a two-pixel obstacle"
	)

	var traversal: Dictionary = baseline.duplicate(true)
	traversal.id = "step-knee-clamber-fixture"
	traversal.step_height = 1
	traversal.knee_height = 2
	traversal.clamber_height = 4
	traversal.knee_slowdown = 0.5
	traversal.clamber_slowdown = 0.25
	var resolved: Dictionary = Profiles.resolve(traversal)
	_expect(resolved.get("ok", false), "step/knee/clamber profile rejected")
	if not resolved.get("ok", false):
		return
	character.configure_profile(resolved.profile)

	character.position = Vector2.ZERO
	character.velocity.x = 10.0
	character.grounded = true
	character.move_horizontal(1.0, TraversalWorld.new(2))
	_expect(
		character.position.is_equal_approx(Vector2(0.5, -2.0)),
		"knee-height obstacle did not use the configured stair-like slowdown"
	)

	character.position = Vector2.ZERO
	character.velocity.x = 10.0
	character.grounded = true
	character.move_horizontal(1.0, TraversalWorld.new(4))
	_expect(
		character.position.is_equal_approx(Vector2(0.25, -4.0)),
		"clamber-height obstacle did not use the configured climbing slowdown"
	)

	character.position = Vector2.ZERO
	character.velocity.x = 10.0
	character.grounded = true
	character.move_horizontal(1.0, TraversalWorld.new(5))
	_expect(
		character.position.is_equal_approx(Vector2.ZERO),
		"above-clamber obstacle was not blocked"
	)
