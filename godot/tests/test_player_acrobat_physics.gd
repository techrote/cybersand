extends SceneTree

# Real pinned Rapier checks: useful traversal, articulated posture, two distinct
# launch impulses, actual roll rotation, braking and finite glide. Numerical
# game-feel tuning still needs a human player; these are physical regressions.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const DT: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var owner: Node2D
var rig
var bridge
var floor_body: StaticBody2D
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_ACROBAT_PHYSICS: " + message)


func setup(floor_enabled: bool = true, origin: Vector2 = Vector2(120, 208)) -> bool:
	var definition: Dictionary = Catalog.entry(&"acrobat")
	expect(not definition.is_empty(), "Acrobat is available in the physical catalogue")
	if definition.is_empty():
		return false
	rig = Rig.new()
	owner.add_child(rig)
	if floor_enabled:
		floor_body = StaticBody2D.new()
		floor_body.position = Vector2(1000, 230)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(2000, 20)
		collider.shape = shape
		floor_body.add_child(collider)
		owner.add_child(floor_body)
	expect(rig.configure(definition, origin) == OK, "physical Acrobat configures")
	if not rig.configured:
		return false
	bridge = Bridge.new()
	expect(bridge.initialize(owner.get_world_2d().space, rig.bodies(), rig.body_sizes()) == OK,
		"Acrobat uses the actual Rapier bridge")
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
	await process_frame


func step(action: Dictionary = {}) -> Dictionary:
	var command: Dictionary = action.duplicate()
	command["effort"] = 1.0
	rig.advance(command, DT)
	bridge.step()
	rig.refresh_observation()
	return rig.observation()


func settle() -> void:
	for tick: int in range(100):
		step()


func extent() -> Rect2:
	var bounds := Rect2()
	var first: bool = true
	for part: Dictionary in rig.draw_parts():
		for vertex: Vector2 in part.polygon:
			if first:
				bounds = Rect2(vertex, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(vertex)
	return bounds


func test_run_slide_brake() -> void:
	if not setup():
		await close_fixture()
		return
	settle()
	var start: Vector2 = rig.centre()
	var standing: float = extent().size.y
	for tick: int in range(65):
		step({"move": Vector2.RIGHT})
	var run_view: Dictionary = rig.observation()
	var travelled: float = rig.centre().x - start.x
	expect(travelled > 35.0, "ground run travels a useful distance")
	expect(Vector2(run_view.velocity).x > 45.0, "ground run reaches an arcade traversal speed")
	for tick: int in range(50):
		step({"move": Vector2.RIGHT, "secondary": true})
	var sliding: float = extent().size.y
	var slide_view: Dictionary = rig.observation()
	expect(sliding < standing - 1.0, "slide physically folds legs into a lower collision silhouette")
	expect(slide_view.player_movement.stance == "tucked", "physical slide keeps its tuck intent")
	var brake_start: float = absf(Vector2(slide_view.velocity).x)
	for tick: int in range(25):
		step({"auxiliary": true})
	var brake_end: float = absf(Vector2(rig.observation().velocity).x)
	expect(brake_end < maxf(8.0, brake_start * 0.30), "brake actually removes forward momentum")
	expect(str(rig.observation().fault).is_empty(), "ground stance changes remain finite")
	metrics["traversal"] = {"distance": travelled, "run_speed": Vector2(run_view.velocity).x,
		"standing_height": standing, "sliding_height": sliding,
		"brake_start_speed": brake_start, "brake_end_speed": brake_end}
	await close_fixture()


func test_actual_jump_double_roll_cancel() -> void:
	if not setup():
		await close_fixture()
		return
	settle()
	expect(bool(rig.observation().grounded), "jump fixture has real floor support")
	var floor_height: float = rig.centre().y
	var takeoff: Dictionary = step({"primary": true, "move": Vector2.RIGHT})
	expect(Vector2(takeoff.velocity).y < -50.0, "jump gives real upward Rapier velocity")
	for tick: int in range(22):
		step({"primary": true, "move": Vector2.RIGHT})
	var first_height: float = rig.centre().y
	step({"move": Vector2.RIGHT})
	var before_double: float = Vector2(rig.observation().velocity).y
	var double_view: Dictionary = step({"primary": true, "move": Vector2.RIGHT})
	expect(Vector2(double_view.velocity).y < before_double - 20.0,
		"second jump changes actual airborne velocity")
	expect(not double_view.player_movement.air_jump_available, "physical double jump spends inventory")
	for tick: int in range(8):
		step({"primary": true, "move": Vector2.RIGHT})
	step({"move": Vector2.RIGHT})
	var before_roll: float = float(rig.observation().rotation)
	for tick: int in range(12):
		step({"move": Vector2.RIGHT, "secondary": true})
	var rolled: Dictionary = rig.observation()
	var rotation_change: float = absf(wrapf(float(rolled.rotation) - before_roll, -PI, PI))
	expect(rotation_change > 0.15, "air roll rotates actual articulated bodies")
	var velocity_before_cancel: Vector2 = PhysicsServer2D.body_get_state(rig.bodies()[0].get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	rig.cancel()
	var velocity_after_cancel: Vector2 = PhysicsServer2D.body_get_state(rig.bodies()[0].get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	expect(velocity_before_cancel.is_equal_approx(velocity_after_cancel), "cancelling preserves physical momentum")
	expect(not rig.observation().player_movement.air_roll_available,
		"physical cancellation retains spent airborne inventory")
	expect(float(rig.observation().player_movement.roll_remaining) == 0.0,
		"physical cancellation clears pending roll torque")
	expect(floor_height - first_height > 12.0, "first jump produces a useful actual jump arc")
	metrics["air"] = {"takeoff_speed": Vector2(takeoff.velocity).y,
		"first_arc_height": floor_height - first_height, "before_double": before_double,
		"after_double": Vector2(double_view.velocity).y, "roll_rotation": rotation_change}
	await close_fixture()


func measured_descent(glide: bool) -> float:
	if not setup(false, Vector2(120, 30)):
		await close_fixture()
		return 100000.0
	for body: RigidBody2D in rig.bodies():
		PhysicsServer2D.body_apply_central_impulse(body.get_rid(), Vector2(30, 30) * body.mass)
	for tick: int in range(45):
		step({"move": Vector2.RIGHT, "auxiliary": glide})
	var result: float = rig.centre().y - 30.0
	expect(str(rig.observation().fault).is_empty(), "fall and glide remain finite")
	await close_fixture()
	return result


func test_session_expiry() -> void:
	var session = Session.new()
	owner.add_child(session)
	expect(session.configure([{"model": &"acrobat", "producer": &"human",
		"position": Vector2(120, 30)}], owner.get_world_2d().space, 3), "human session configures Acrobat")
	if session.active():
		expect(session.submit_local(0, {"primary": true, "secondary": true, "aim": Vector2.RIGHT},
			&"human", 1), "human bullet-jump packet admitted through normal lease")
		session.advance(DT)
		session.bridge.step()
		session.complete_step()
		expect(not session.observation(0).player_movement.bullet_jump_available,
			"session action spends the real controller's bullet jump")
		for tick: int in range(3):
			session.advance(DT)
			session.bridge.step()
			session.complete_step()
		var expired: Dictionary = session.observation(0)
		expect(expired.player_movement.mode == "cancelled", "lease expiry cancels the player controller")
		expect(not expired.player_movement.bullet_jump_available and float(expired.player_movement.roll_remaining) == 0.0,
			"lease expiry neither refills burst inventory nor retains roll work")
		session.close()
	session.free()
	await process_frame


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "pinned real Rapier is present")
	if failures == 0:
		await test_run_slide_brake()
		await test_actual_jump_double_roll_cancel()
		var falling: float = await measured_descent(false)
		var gliding: float = await measured_descent(true)
		expect(gliding < falling - 8.0, "airglide meaningfully slows an actual falling assembly")
		metrics["glide"] = {"unassisted_drop": falling, "glide_drop": gliding}
		await test_session_expiry()
	owner.free()
	await process_frame
	print("PLAYER_ACROBAT_PHYSICS_METRICS ", JSON.stringify(metrics))
	print("PLAYER_ACROBAT_PHYSICS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
