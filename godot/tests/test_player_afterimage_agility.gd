extends SceneTree

# Real bare-rig Rapier checks for the responsive Afterimage stance. The comparison
# changes only the registered jump speeds; it does not replace physics with an
# integrated estimate. Airborne inventory tests remain observation based so a
# persistent support sensor cannot hide an accidental move-budget refill.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Controls = preload("res://scripts/player_playground_input.gd")
const Controller = preload("res://scripts/player_acrobat_controller.gd")
const DT: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var owner: Node2D
var rig
var bridge
var floor_body: StaticBody2D
var ceiling_body: StaticBody2D
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_AFTERIMAGE_AGILITY: " + message)


func setup(jump_speed: float = 94.0, command_slew: float = 90.0) -> bool:
	var data: Dictionary = Catalog.entry(&"acrobat")
	data.profile.jump = jump_speed
	for joint: Dictionary in data.joints:
		if command_slew > 0.0:
			joint.command_slew = command_slew
		else:
			joint.erase("command_slew")
	rig = Rig.new()
	owner.add_child(rig)
	floor_body = StaticBody2D.new()
	floor_body.position = Vector2(1000, 230)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 20)
	collision.shape = shape
	floor_body.add_child(collision)
	owner.add_child(floor_body)
	expect(rig.configure(data, Vector2(120, 208)) == OK, "actual articulated Afterimage configures")
	if not rig.configured:
		return false
	bridge = Bridge.new()
	expect(bridge.initialize(owner.get_world_2d().space, rig.bodies(), rig.body_sizes()) == OK,
		"Afterimage uses the pinned real Rapier bridge")
	for tick: int in range(120):
		step()
	return bridge.is_initialized()


func close_fixture() -> void:
	if bridge != null:
		bridge.shutdown()
		bridge = null
	if is_instance_valid(rig):
		rig.close()
		rig.free()
		rig = null
	if is_instance_valid(floor_body):
		floor_body.free()
		floor_body = null
	if is_instance_valid(ceiling_body):
		ceiling_body.free()
		ceiling_body = null
	await process_frame


func step(action: Dictionary = {}) -> Dictionary:
	rig.advance(action, DT)
	bridge.step()
	rig.refresh_observation()
	return rig.observation()


func measured_jump(speed: float) -> float:
	if not setup(speed):
		await close_fixture()
		return 0.0
	expect(bool(rig.observation().grounded), "jump begins on real support")
	var start: float = rig.centre().y
	var highest: float = start
	var takeoff: float = Vector2(step({"primary": true}).velocity).y
	for tick: int in range(110):
		step({"primary": true})
		highest = minf(highest, rig.centre().y)
	expect(str(rig.observation().fault).is_empty(), "jump retains finite physical ownership")
	metrics["jump_%d" % int(speed)] = {"height": start - highest, "takeoff_velocity": takeoff}
	await close_fixture()
	return start - highest


func test_responsive_supported_stride() -> void:
	if not setup():
		await close_fixture()
		return
	var start: float = rig.centre().x
	var max_angle: float = 0.0
	var supported: int = 0
	var distinct_targets: bool = false
	var actual_stride: float = 0.0
	var early_speed: float = 0.0
	for tick: int in range(65):
		var view: Dictionary = step({"move": Vector2.RIGHT})
		max_angle = maxf(max_angle, absf(wrapf(float(view.rotation), -PI, PI)))
		if view.player_movement.grounded:
			supported += 1
		if tick == 11:
			early_speed = Vector2(view.velocity).x
		var left: Dictionary = view.joints[0]
		var right: Dictionary = view.joints[2]
		distinct_targets = distinct_targets or absf(float(left.target) - float(right.target)) > 1.0
		actual_stride = maxf(actual_stride, absf(float(left.angle) - float(right.angle)))
	var travel: float = rig.centre().x - start
	expect(early_speed > 70.0, "running responds within twelve actual physics ticks")
	expect(travel > 85.0, "supported running traverses a useful distance")
	expect(max_angle < 0.35, "running holds a deliberate upright torso instead of trailing a ragdoll")
	expect(supported >= 35, "the moving stance retains physical support for most ticks")
	expect(distinct_targets and actual_stride > 0.10,
		"opposed leg commands produce real articulated leg motion")
	for tick: int in range(18):
		step({"move": Vector2.LEFT})
	var reverse_speed: float = Vector2(rig.observation().velocity).x
	expect(reverse_speed < -35.0, "bounded control reverses direction crisply")
	for tick: int in range(90):
		step()
	var stopped: Dictionary = rig.observation()
	expect(absf(Vector2(stopped.velocity).x) < 2.0, "released run settles without wandering")
	expect(absf(float(stopped.rotation)) < 0.15, "idle motor stance recovers upright")
	# A finite angular kick is integrated by Rapier, followed by normal bounded
	# posture assistance. No transform or velocity assignment repairs the rig.
	PhysicsServer2D.body_apply_torque_impulse(rig.bodies()[0].get_rid(), rig.bodies()[0].inertia * 2.0)
	for tick: int in range(90):
		step()
	var recovered: Dictionary = rig.observation()
	expect(absf(float(recovered.rotation)) < 0.15 and absf(float(recovered.angular_velocity)) < 0.35,
		"posture recovers from a real angular impulse without pose replacement")
	metrics["stride"] = {"early_speed": early_speed, "travel": travel,
		"max_torso_angle": max_angle, "supported_ticks": supported, "actual_leg_angle_difference": actual_stride,
		"reverse_speed": reverse_speed, "recovered_angle": recovered.rotation}
	await close_fixture()


func test_per_player_modifier_and_inventory() -> void:
	var ctrl: Dictionary = {KEY_CTRL: true}
	var old_key: Dictionary = {KEY_C: true}
	expect(Controls.from_state(ctrl, Vector2.ZERO, Vector3i.ZERO, 0.0, &"acrobat").auxiliary,
		"Ctrl selects Afterimage glide/brake/cancel")
	expect(not Controls.from_state(old_key, Vector2.ZERO, Vector3i.ZERO, 0.0, &"acrobat").auxiliary,
		"C no longer actuates Afterimage")
	for preset: StringName in [&"stuntbuggy", &"trialsbike", &"arcadelander", &"dryswarm", &"liquidswarm", &"jetbarrel"]:
		expect(Controls.from_state(old_key, Vector2.ZERO, Vector3i.ZERO, 0.0, preset).auxiliary,
			"C retains the other preset's auxiliary action: " + str(preset))
		expect(not Controls.from_state(ctrl, Vector2.ZERO, Vector3i.ZERO, 0.0, preset).auxiliary,
			"Ctrl does not replace another preset's auxiliary action: " + str(preset))
	expect(Controls.from_state({}, Vector2.ZERO, Vector3i(0, 0, 1), 0.0, &"acrobat").auxiliary,
		"gamepad X still supplies Afterimage's same auxiliary action")
	expect(Controls.active(Controls.from_state(ctrl, Vector2.ZERO, Vector3i.ZERO, 0.0, &"acrobat")),
		"held Ctrl participates in Afterimage's switch/focus release barrier")
	for location: KeyLocation in [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]:
		var event := InputEventKey.new()
		event.keycode = KEY_CTRL
		event.physical_keycode = KEY_CTRL
		event.location = location
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		expect(Controls.sample(&"acrobat").auxiliary,
			"physical Ctrl at either keyboard location reaches the actual sampler")
		var release: InputEventKey = event.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	var controller = Controller.new()
	var floor_view: Dictionary = {"velocity": Vector2.ZERO, "grounded": true,
		"contact_normal": Vector2.UP, "gravity": 156.0}
	for tick: int in range(4):
		controller.calculate(floor_view, {}, DT)
	controller.calculate(floor_view, {"primary": true}, DT)
	var air_view: Dictionary = {"velocity": Vector2(0, -30), "grounded": true,
		"contact_normal": Vector2.UP, "gravity": 156.0}
	controller.calculate(air_view, {}, DT)
	controller.calculate(air_view, {"primary": true}, DT)
	controller.calculate(air_view, {"auxiliary": true}, DT)
	controller.cancel()
	for tick: int in range(40):
		controller.calculate(air_view, {}, DT)
	expect(not controller.observation().air_jump_available,
		"upward stale support and Ctrl cancellation do not replenish double jump")
	var denied: Dictionary = controller.calculate(air_view, {"primary": true}, DT)
	expect(Vector2(denied.delta_velocity).y >= 0.0, "the higher jump does not admit extra airborne jumps")


func bounds() -> Rect2:
	var result := Rect2()
	var first: bool = true
	for part: Dictionary in rig.draw_parts():
		for vertex: Vector2 in part.polygon:
			if first:
				result = Rect2(vertex, Vector2.ZERO)
				first = false
			else:
				result = result.expand(vertex)
	return result


func test_low_clearance_slide() -> void:
	if not setup():
		await close_fixture()
		return
	var standing_height: float = bounds().size.y
	ceiling_body = StaticBody2D.new()
	ceiling_body.position = Vector2(260, 200)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 16) # Ceiling bottom208; real floor top220: 12px gap.
	collision.shape = shape
	ceiling_body.add_child(collision)
	owner.add_child(ceiling_body)
	for tick: int in range(16):
		step({"move": Vector2.RIGHT})
	var minimum_height: float = standing_height
	var inside_height: float = 0.0
	var tucked_inside: bool = false
	var exited: bool = false
	for tick: int in range(180):
		var view: Dictionary = step({"move": Vector2.RIGHT, "secondary": true})
		var silhouette: Rect2 = bounds()
		minimum_height = minf(minimum_height, silhouette.size.y)
		if rig.centre().x > 230.0 and rig.centre().x < 290.0:
			inside_height = maxf(inside_height, silhouette.size.y)
			tucked_inside = tucked_inside or view.player_movement.stance == "tucked"
		if silhouette.position.x > 300.0:
			exited = true
			break
	expect(exited and tucked_inside, "the complete bare rig still slides through a real twelve-pixel tunnel")
	expect(minimum_height < standing_height - 1.0 and inside_height <= 12.5,
		"the slide keeps actual lower clearance rather than only changing its visual pose")
	metrics["slide"] = {"standing_height": standing_height, "minimum_height": minimum_height,
		"inside_height": inside_height, "complete_exit": exited}
	await close_fixture()


func test_invalid_motor_profile_before_allocation() -> void:
	for invalid: float in [NAN, INF, -INF, -1.0, 1.99, 120.01]:
		var data: Dictionary = Catalog.entry(&"acrobat")
		data.joints[0].command_slew = invalid
		var candidate = Rig.new()
		owner.add_child(candidate)
		expect(candidate.configure(data, Vector2(120, 208)) == ERR_INVALID_DATA,
			"invalid joint command slew is explicitly refused: " + str(invalid))
		expect(not candidate.configured and candidate.bodies().is_empty()
			and candidate._joints.is_empty() and candidate.get_child_count() == 0,
			"invalid joint command slew refuses before allocating any parts or joints")
		candidate.free()


func measured_motor_slew(slew: float) -> float:
	if not setup(94.0, slew):
		await close_fixture()
		return 0.0
	var motor: PinJoint2D = rig._joints[0].node
	var before: float = motor.motor_target_velocity
	rig.advance({"move": Vector2.RIGHT, "secondary": true}, DT)
	var change: float = absf(motor.motor_target_velocity - before)
	await close_fixture()
	return change


func test_legacy_motor_default() -> void:
	var implicit: float = await measured_motor_slew(0.0)
	var explicit: float = await measured_motor_slew(20.0)
	var agile: float = await measured_motor_slew(90.0)
	expect(is_equal_approx(implicit, 20.0 * DT) and is_equal_approx(implicit, explicit),
		"omitting command_slew retains the previous twenty-per-second actuator response")
	expect(is_equal_approx(agile, 90.0 * DT) and agile > implicit * 4.0,
		"Afterimage's authored slew makes real motor requests respond faster without assigning body state")
	metrics["motor_slew"] = {"implicit_legacy": implicit, "explicit_legacy": explicit, "afterimage": agile}


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "pinned Rapier is available")
	test_per_player_modifier_and_inventory()
	test_invalid_motor_profile_before_allocation()
	if failures == 0:
		await test_legacy_motor_default()
		var previous_height: float = await measured_jump(78.0)
		var current_height: float = await measured_jump(94.0)
		expect(current_height > previous_height * 1.30 and current_height > 25.0,
			"actual jump height increases meaningfully against the former 78-speed launch")
		metrics["jump_height_ratio"] = current_height / maxf(previous_height, 0.01)
		await test_responsive_supported_stride()
		await test_low_clearance_slide()
	owner.free()
	await process_frame
	print("PLAYER_AFTERIMAGE_AGILITY_METRICS ", JSON.stringify(metrics))
	print("PLAYER_AFTERIMAGE_AGILITY: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
