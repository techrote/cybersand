extends SceneTree

const Profiles = preload("res://scripts/player_environment_profiles.gd")

var _failed: bool = false


class FreeWorld:
	extends RefCounted

	func box_collides(_origin: Vector2, _size: Vector2) -> bool:
		return false

	func character_box_collides(_origin: Vector2, _size: Vector2, _mode: int) -> bool:
		return false


class ContourWorld:
	extends RefCounted

	const FLOOR_Y: float = 40.0
	const STEP_X: int = 18

	var rise_per_step: int = 1
	var run_width: int = 1000000
	var maximum_height: int = 1
	var overhang: Rect2 = Rect2()

	static func isolated(height: int) -> ContourWorld:
		var world := ContourWorld.new()
		world.rise_per_step = height
		world.maximum_height = height
		return world

	static func staircase(rise: int, run: int, maximum: int = 32) -> ContourWorld:
		var world := ContourWorld.new()
		world.rise_per_step = rise
		world.run_width = maxi(1, run)
		world.maximum_height = maximum
		return world

	static func with_overhang() -> ContourWorld:
		var world := ContourWorld.new()
		world.rise_per_step = 0
		world.maximum_height = 0
		world.overhang = Rect2(18.0, 26.0, 4.0, 4.0)
		return world

	func surface_height(x: int) -> int:
		if x < STEP_X or rise_per_step <= 0:
			return 0
		var step_index: int = int((x - STEP_X) / run_width) + 1
		return mini(maximum_height, step_index * rise_per_step)

	func box_collides(origin: Vector2, size: Vector2) -> bool:
		var actor := Rect2(origin, size)
		if overhang.size.x > 0.0 and actor.intersects(overhang):
			return true
		var first_x: int = floori(origin.x + 0.001)
		var last_x: int = ceili(origin.x + size.x - 0.001) - 1
		var bottom: float = origin.y + size.y
		for x: int in range(first_x, last_x + 1):
			var surface_y: float = FLOOR_Y - float(surface_height(x))
			if bottom > surface_y + 0.001:
				return true
		return false

	func character_box_collides(origin: Vector2, size: Vector2, _mode: int) -> bool:
		return box_collides(origin, size)


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


func _place_on_flat(character: CyberSampledCharacter) -> void:
	character.position = Vector2(
		10.0,
		ContourWorld.FLOOR_Y - CyberSampledCharacter.BODY_SIZE.y
	)
	character.velocity.x = 10.0
	character.grounded = true


func _test_traversal_bands() -> void:
	var baseline: Dictionary = Profiles.preset(Profiles.PRESET_CURRENT)
	var character := CyberSampledCharacter.new()
	character.configure_profile(baseline)

	_place_on_flat(character)
	character.move_horizontal(1.0, ContourWorld.isolated(1))
	_expect(
		character.last_traversal_band == "step",
		"one-pixel baseline obstacle did not classify as step"
	)
	_expect(
		absf(character.last_traversal_horizontal_progress - 1.0) < 0.0001,
		"step band lost horizontal progress"
	)
	_expect(
		character.last_traversal_ledge_height == 1,
		"one-pixel baseline ledge height was not measured locally"
	)

	_place_on_flat(character)
	var baseline_x: float = character.position.x
	character.move_horizontal(1.0, ContourWorld.isolated(2))
	_expect(
		absf(character.position.x - baseline_x) < 0.0001
			and character.last_traversal_band == "blocked",
		"exact-current profile unexpectedly admitted a two-pixel local ledge"
	)

	# Owner explicitly tested 2/4/6 and rejected the old whole-box model. This
	# profile is the primary PENV-002 owner-rejected-case classification regression.
	var traversal: Dictionary = baseline.duplicate(true)
	traversal.id = "step-knee-clamber-2-4-6"
	traversal.step_height = 2
	traversal.knee_height = 4
	traversal.clamber_height = 6
	traversal.knee_slowdown = 0.5
	traversal.clamber_slowdown = 0.25
	var resolved: Dictionary = Profiles.resolve(traversal)
	_expect(resolved.get("ok", false), "2/4/6 traversal profile rejected")
	if not resolved.get("ok", false):
		return
	character.configure_profile(resolved.profile)

	for height: int in [1, 2]:
		_place_on_flat(character)
		character.move_horizontal(1.0, ContourWorld.isolated(height))
		_expect(
			character.last_traversal_band == "step",
			"%dpx ledge escaped the configured step band" % height
		)
		_expect(
			absf(character.last_traversal_horizontal_progress - 1.0) < 0.0001,
			"%dpx step applied deliberate horizontal slowdown" % height
		)

	for height: int in [3, 4]:
		_place_on_flat(character)
		character.move_horizontal(1.0, ContourWorld.isolated(height))
		_expect(
			character.last_traversal_band == "knee"
				and character.last_traversal_ledge_height == height,
			"%dpx ledge did not stay in the knee band" % height
		)
		_expect(
			absf(character.last_traversal_horizontal_progress - 0.5) < 0.0001,
			"%dpx knee ledge ignored its own slowdown" % height
		)

	for height: int in [5, 6]:
		_place_on_flat(character)
		character.move_horizontal(1.0, ContourWorld.isolated(height))
		_expect(
			character.last_traversal_band == "clamber"
				and character.last_traversal_ledge_height == height,
			"%dpx ledge did not stay in the clamber band" % height
		)
		_expect(
			absf(character.last_traversal_horizontal_progress - 0.25) < 0.0001,
			"%dpx clamber ledge ignored its own slowdown" % height
		)

	_place_on_flat(character)
	var blocked_x: float = character.position.x
	character.move_horizontal(1.0, ContourWorld.isolated(7))
	_expect(
		character.last_traversal_band == "blocked"
			and absf(character.position.x - blocked_x) < 0.0001,
		"above-clamber local ledge was admitted"
	)

	# The key remediation case: an 8px-wide actor traversing a long shoulder can
	# need >1px total box clearance even though each *local* rise is only 1px.
	# The old algorithm classified that whole-box clearance as knee/clamber and
	# made the entire shoulder sluggish.
	_place_on_flat(character)
	var staircase := ContourWorld.staircase(1, 3, 12)
	var start_x: float = character.position.x
	for _step: int in range(12):
		character.grounded = true
		character.move_horizontal(1.0, staircase)
		_expect(
			character.last_traversal_band in ["none", "step"],
			"1px shoulder leaked into knee/clamber slowdown"
		)
	_expect(
		absf(character.position.x - (start_x + 12.0)) < 0.0001,
		"1px shoulder lost horizontal progress under 2/4/6"
	)

	# A repeated 2px stair remains in step because the configured step threshold
	# explicitly admits two pixels.
	_place_on_flat(character)
	var two_px_stairs := ContourWorld.staircase(2, 3, 24)
	start_x = character.position.x
	for _step: int in range(9):
		character.grounded = true
		character.move_horizontal(1.0, two_px_stairs)
		_expect(
			character.last_traversal_band in ["none", "step"],
			"2px staircase leaked into knee/clamber slowdown"
		)
	_expect(
		absf(character.position.x - (start_x + 9.0)) < 0.0001,
		"2px staircase lost horizontal progress under step-height 2"
	)

	# A head-height obstruction has no contiguous ledge at the foot. It must not
	# be reinterpreted as a climbable step.
	_place_on_flat(character)
	blocked_x = character.position.x
	character.move_horizontal(1.0, ContourWorld.with_overhang())
	_expect(
		character.last_traversal_band == "blocked"
			and character.last_traversal_ledge_height == 0
			and absf(character.position.x - blocked_x) < 0.0001,
		"overhang/head obstruction was misclassified as traversal"
	)
