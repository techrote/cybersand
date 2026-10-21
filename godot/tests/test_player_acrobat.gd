extends SceneTree

# Observation-sequence regressions for the player movement grammar. They target
# repeatable input/landing exploits and cancel behavior; real Rapier motion is
# exercised separately by test_player_acrobat_physics.gd.
const Controller = preload("res://scripts/player_acrobat_controller.gd")
const DT: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_ACROBAT: " + message)


func observed(grounded: bool = false, velocity: Vector2 = Vector2.ZERO,
		normal: Vector2 = Vector2.UP) -> Dictionary:
	return {"grounded": grounded, "velocity": velocity,
		"contact_normal": normal, "rotation": 0.0, "gravity": 156.0}


func settle(controller) -> void:
	for tick: int in range(4):
		controller.calculate(observed(true), {}, DT)


func neutral(controller, count: int = 12, grounded: bool = false) -> void:
	for tick: int in range(count):
		controller.calculate(observed(grounded), {}, DT)


func test_ground_jump_double_and_landing() -> void:
	var controller = Controller.new()
	settle(controller)
	var first: Dictionary = controller.calculate(observed(true), {"primary": true}, DT)
	expect(Vector2(first.delta_velocity).y < -70.0, "floor jump supplies useful bounded upward impulse")
	expect(controller.observation().last_move == "jump", "floor jump uses floor token")
	expect(controller.observation().air_jump_available, "floor jump preserves the separate double jump")
	for tick: int in range(14):
		var held: Dictionary = controller.calculate(observed(false, Vector2(0, -40)), {"primary": true}, DT)
		expect(Vector2(held.delta_velocity).y >= 0.0, "holding jump never repeats takeoff")
	controller.calculate(observed(), {}, DT)
	var second: Dictionary = controller.calculate(observed(), {"primary": true}, DT)
	expect(Vector2(second.delta_velocity).y < -60.0, "second press supplies a double jump")
	expect(not controller.observation().air_jump_available, "double jump spends airborne inventory")
	for press: int in range(8):
		controller.calculate(observed(), {}, DT)
		var denied: Dictionary = controller.calculate(observed(), {"primary": true}, DT)
		expect(Vector2(denied.delta_velocity).y >= 0.0, "extra airborne jump press refused")
	# Let the last intentional buffer expire before validating normal landing.
	neutral(controller, 15)
	settle(controller)
	expect(controller.observation().air_jump_available, "stable physical landing restores double jump")
	var next: Dictionary = controller.calculate(observed(true), {"primary": true}, DT)
	expect(Vector2(next.delta_velocity).y < -70.0, "a fresh grounded takeoff remains available")


func test_stale_support_and_wall_cannot_refill() -> void:
	var controller = Controller.new()
	settle(controller)
	controller.calculate(observed(true), {"primary": true}, DT)
	controller.calculate(observed(), {}, DT)
	controller.calculate(observed(), {"primary": true}, DT)
	for tick: int in range(30):
		controller.calculate(observed(true, Vector2(0, -30)), {}, DT)
	expect(not controller.observation().air_jump_available,
		"lingering support ray during ascent cannot restore double jump")
	for tick: int in range(30):
		controller.calculate(observed(true, Vector2.ZERO, Vector2.LEFT), {}, DT)
	expect(not controller.observation().air_jump_available,
		"wall contact without upward normal cannot restore double jump")
	var plan: Dictionary = controller.calculate(observed(false), {"primary": true}, DT)
	expect(Vector2(plan.delta_velocity).y >= 0.0, "stale support cannot fund an extra airborne jump")


func test_coyote_and_landing_buffer() -> void:
	var coyote = Controller.new()
	settle(coyote)
	neutral(coyote, 4)
	var plan: Dictionary = coyote.calculate(observed(), {"primary": true}, DT)
	expect(Vector2(plan.delta_velocity).y < -70.0 and coyote.observation().last_move == "jump",
		"short ledge departure preserves floor jump")
	expect(coyote.observation().air_jump_available, "coyote jump does not spend double jump")
	var expired = Controller.new()
	settle(expired)
	neutral(expired, 10)
	expired.calculate(observed(), {"primary": true}, DT)
	expect(expired.observation().last_move == "double-jump", "late ledge press consumes airborne jump")
	var buffered = Controller.new()
	settle(buffered)
	buffered.calculate(observed(true), {"primary": true}, DT)
	neutral(buffered)
	buffered.calculate(observed(), {"primary": true}, DT)
	neutral(buffered)
	var queued: Dictionary = buffered.calculate(observed(false, Vector2(0, 30)), {"primary": true}, DT)
	expect(Vector2(queued.delta_velocity).y == 0.0, "exhausted airborne jump waits for landing")
	var launched: bool = false
	for tick: int in range(4):
		plan = buffered.calculate(observed(true, Vector2(0, 2)), {"primary": true}, DT)
		launched = launched or Vector2(plan.delta_velocity).y < -70.0
	expect(launched, "fresh prelanding press fires after stable support")
	expect(buffered.observation().jump_buffer_remaining == 0.0, "landing consumes buffer exactly once")


func test_bullet_jump_inventory_and_cancels() -> void:
	var controller = Controller.new()
	settle(controller)
	controller.calculate(observed(true, Vector2(80, 0)), {"secondary": true, "move": Vector2.RIGHT}, DT)
	var burst: Dictionary = controller.calculate(observed(true, Vector2(80, 0)),
		{"primary": true, "secondary": true, "move": Vector2.RIGHT, "aim": Vector2.RIGHT}, DT)
	expect(controller.observation().last_move == "bullet-jump", "slide plus jump becomes bullet jump")
	expect(Vector2(burst.delta_velocity).y < -25.0, "floor bullet jump lifts even with horizontal aim")
	expect(not controller.observation().bullet_jump_available, "bullet jump spends landing-scoped inventory")
	expect(controller.observation().roll_remaining == 0.0, "bullet jump cancels prior roll or slide")
	neutral(controller)
	var second: Dictionary = controller.calculate(observed(), {"primary": true, "secondary": true}, DT)
	expect(controller.observation().last_move == "double-jump" and Vector2(second.delta_velocity).y < -60.0,
		"after bullet jump, another press becomes the remaining double jump")
	neutral(controller)
	var third: Dictionary = controller.calculate(observed(), {"primary": true, "secondary": true}, DT)
	expect(Vector2(third.delta_velocity).y >= 0.0, "holding slide cannot create unlimited bullet jumps")
	controller.cancel()
	expect(not controller.observation().bullet_jump_available and not controller.observation().air_jump_available,
		"input cancellation does not refill spent air moves")
	var cancelled: Dictionary = controller.calculate(observed(), {}, DT)
	expect(Vector2(cancelled.delta_velocity) == Vector2.ZERO, "cancel does not replay a buffered takeoff")


func test_roll_slide_brake_and_air_inventory() -> void:
	var controller = Controller.new()
	settle(controller)
	for tick: int in range(14):
		controller.calculate(observed(true, Vector2(90, 0)), {"secondary": true, "move": Vector2.RIGHT}, DT)
	expect(controller.observation().mode == "slide", "held Shift enters sustained slide")
	var tweak: Dictionary = controller.calculate(observed(true, Vector2(90, 0)),
		{"secondary": true, "move": Vector2.LEFT}, DT)
	expect(Vector2(tweak.delta_velocity).x < 0.0, "slide steering applies a bounded reversal impulse")
	var release: Dictionary = controller.calculate(observed(true, Vector2(90, 0)), {}, DT)
	expect(not bool(release.spin), "releasing a held slide does not cause an unwanted roll")
	controller.calculate(observed(true), {"secondary": true}, DT)
	var roll: Dictionary = controller.calculate(observed(true), {}, DT)
	expect(bool(roll.spin) and Vector2(roll.delta_velocity).x != 0.0, "quick Shift tap starts a physical ground roll")
	var cancel: Dictionary = controller.calculate(observed(true, Vector2(60, 0)), {"auxiliary": true}, DT)
	expect(not bool(cancel.spin) and Vector2(cancel.delta_velocity).x < -10.0,
		"C cancels ground roll and supplies strong bounded brake")
	var suppressed = Controller.new()
	settle(suppressed)
	suppressed.calculate(observed(true), {"secondary": true}, DT)
	suppressed.calculate(observed(true), {"secondary": true, "auxiliary": true}, DT)
	var after_cancel: Dictionary = suppressed.calculate(observed(true), {}, DT)
	expect(not bool(after_cancel.spin), "releasing a C-cancelled short slide cannot create a late roll")
	var air = Controller.new()
	var first: Dictionary = air.calculate(observed(), {"secondary": true}, DT)
	expect(bool(first.spin), "fresh airborne Shift starts an air roll")
	air.calculate(observed(), {"auxiliary": true}, DT)
	neutral(air, 24)
	var denied: Dictionary = air.calculate(observed(), {"secondary": true}, DT)
	expect(not bool(denied.spin) and not air.observation().air_roll_available,
		"cancelling air roll does not purchase another before landing")


func test_glide_reserve_and_variable_jump() -> void:
	var glide = Controller.new()
	var first: Dictionary = glide.calculate(observed(false, Vector2(30, 35)), {"auxiliary": true}, DT)
	expect(Vector2(first.delta_velocity).y < 0.0 and glide.observation().mode == "glide",
		"C supplies airglide fall resistance")
	for tick: int in range(130):
		glide.calculate(observed(false, Vector2(30, 35)), {"auxiliary": true}, DT)
	expect(is_zero_approx(float(glide.observation().glide_remaining)), "glide reserve is finite")
	glide.cancel()
	var empty: Dictionary = glide.calculate(observed(false, Vector2(30, 35)), {"auxiliary": true}, DT)
	expect(Vector2(empty.delta_velocity).y == 0.0, "pause/cancel cannot replenish exhausted glide")
	settle(glide)
	expect(float(glide.observation().glide_remaining) > 1.5, "physical landing restores glide reserve")
	var jump = Controller.new()
	settle(jump)
	jump.calculate(observed(true), {"primary": true}, DT)
	var cut: Dictionary = jump.calculate(observed(false, Vector2(0, -65)), {}, DT)
	expect(Vector2(cut.delta_velocity).y > 0.0 and Vector2(cut.delta_velocity).y < 10.0,
		"early jump release cuts ascent through bounded impulse")
	var held = Controller.new()
	settle(held)
	held.calculate(observed(true), {"primary": true}, DT)
	var full: Dictionary = held.calculate(observed(false, Vector2(0, -65)), {"primary": true}, DT)
	expect(Vector2(full.delta_velocity).y == 0.0, "held jump retains full rising momentum")


func test_bounds_and_revocation() -> void:
	var controller = Controller.new()
	for tick: int in range(240):
		var plan: Dictionary = controller.calculate(observed(false, Vector2(500, 900)),
			{"primary": tick % 2 == 0, "secondary": tick % 3 == 0, "auxiliary": tick % 5 == 0,
			"move": Vector2(-100, 100), "aim": Vector2(100, -100)}, 0.7, 100.0)
		expect(Vector2(plan.delta_velocity).is_finite() and Vector2(plan.delta_velocity).length() <= 96.0001,
			"adversarial input remains within total per-step impulse budget")
	var invalid: Dictionary = controller.calculate(observed(false, Vector2(INF, 0)), {"primary": true}, DT)
	expect(Vector2(invalid.delta_velocity) == Vector2.ZERO, "nonfinite observation produces no actuation")
	expect(controller.observation().jump_buffer_remaining == 0.0, "invalid observation clears pending input")
	invalid = controller.calculate(observed(), {"primary": true}, NAN)
	expect(Vector2(invalid.delta_velocity) == Vector2.ZERO, "nonfinite timestep produces no actuation")
	var ground = Controller.new()
	settle(ground)
	ground.calculate(observed(true), {"secondary": true}, DT)
	ground.cancel()
	var neutral_plan: Dictionary = ground.calculate(observed(), {}, DT)
	expect(Vector2(neutral_plan.delta_velocity) == Vector2.ZERO and not bool(neutral_plan.spin),
		"revocation is not a deliberate short-slide release")


func run() -> void:
	test_ground_jump_double_and_landing()
	test_stale_support_and_wall_cannot_refill()
	test_coyote_and_landing_buffer()
	test_bullet_jump_inventory_and_cancels()
	test_roll_slide_brake_and_air_inventory()
	test_glide_reserve_and_variable_jump()
	test_bounds_and_revocation()
	print("PLAYER_ACROBAT: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
