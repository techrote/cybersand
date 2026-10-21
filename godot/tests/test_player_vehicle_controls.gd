extends SceneTree

# Real pinned Rapier execution: wheel traction, suspension, jump release,
# flight damping, torque authority, and cancellation. Native circle mask remains
# a declared conservative square and is not inferred to match round collision.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const PlayerCatalog = preload("res://scripts/player_actor_catalog.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var rig: CyberPhysicalActorRig
var bridge: CyberRapierPhysicsBridge


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, reason: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_VEHICLE: " + reason)


func setup(model: StringName, floor_present: bool = true) -> bool:
	var data: Dictionary = Catalog.entry(model)
	if not floor_present:
		data.profile.gravity = 0.0
	rig = Rig.new()
	owner.add_child(rig)
	expect(rig.configure(data, Vector2(240, 220)) == OK, "configure " + str(model))
	if not rig.configured:
		return false
	bridge = Bridge.new()
	expect(bridge.initialize(owner.get_world_2d().space, rig.bodies(), rig.body_sizes()) == OK, "bridge " + str(model))
	if floor_present:
		expect(bridge.rebuild_hard_surface_colliders_from_rectangles(PackedInt32Array([0, 260, 1024, 12])) >= 1, "floor created")
		for tick: int in range(120):
			step({})
	return bridge.is_initialized()


func step(action: Dictionary, allowed: bool = true) -> Dictionary:
	var request: Dictionary = action.duplicate(true)
	request["effort"] = 1.0
	rig.advance(request, DT, allowed)
	bridge.step()
	rig.refresh_observation()
	return rig.observation()


func finish() -> void:
	if bridge != null:
		bridge.shutdown()
		bridge = null
	if is_instance_valid(rig):
		rig.close()
		rig.free()
		rig = null
	await process_frame


func test_catalogue() -> void:
	for id: StringName in PlayerCatalog.IDS:
		var data: Dictionary = Catalog.entry(id)
		expect(Catalog.set_for(id) == &"setP", "player set " + str(id))
		expect(Rig.validate_definition(data).is_empty(), "valid definition " + str(id))
		expect(Session.valid_definitions([{"model": id, "producer": &"human", "position": Vector2(240, 220)}]), "prepared part capacity " + str(id))
		expect(not Catalog.controls_text(id).is_empty(), "visible controls " + str(id))
	var invalid: Dictionary = Catalog.entry(&"trialsbike")
	invalid.parts[2].erase("native_mask")
	expect(not Rig.validate_definition(invalid).is_empty(), "circle cannot hide its cellular approximation")
	invalid = Catalog.entry(&"trialsbike")
	invalid.parts[2].size.y += 1.0
	expect(not Rig.validate_definition(invalid).is_empty(), "ellipse refused")
	# New admission does not reinterpret the retained physical actor definitions.
	for id: StringName in [&"runner", &"ripper", &"copter", &"jev"]:
		for part: Dictionary in Catalog.entry(id).parts:
			expect(str(part.shape) == "rectangle", "legacy collider preserved " + str(id))


func test_ground_vehicle(model: StringName) -> void:
	if not setup(model):
		await finish()
		return
	var circles: int = 0
	for body: RigidBody2D in rig.bodies():
		if body.get_child(0).shape is CircleShape2D:
			circles += 1
	expect(circles == 2, str(model) + " actual round-wheel colliders")
	var start: Dictionary = rig.observation()
	expect(bool(start.grounded), str(model) + " settled support")
	for tick: int in range(90):
		step({"move": Vector2.UP})
	var driven: Dictionary = rig.observation()
	expect(float(driven.position.x) - float(start.position.x) > 22.0, str(model) + " forward drive moves vehicle")
	expect(Vector2(driven.velocity).x > 10.0, str(model) + " useful driven speed")
	expect(str(driven.fault).is_empty(), str(model) + " finite articulated motion")
	var moving_speed: float = absf(Vector2(driven.velocity).x)
	for tick: int in range(60):
		step({"secondary": true})
	var braked: Dictionary = rig.observation()
	expect(absf(Vector2(braked.velocity).x) < maxf(8.0, moving_speed * 0.35), str(model) + " brake removes horizontal speed")
	for tick: int in range(30):
		step({})
	if model == &"trialsbike":
		for tick: int in range(30):
			step({"primary": true})
		expect(float(rig.observation().player_movement.preload) > 0.8, "bike stores supported preload")
		var launch: Dictionary = step({})
		expect(Vector2(launch.velocity).y < -20.0, "bike release launches")
	else:
		var launch: Dictionary = step({"primary": true})
		expect(Vector2(launch.velocity).y < -12.0, "buggy hop launches")
	print("PLAYER_VEHICLE_METRICS ", JSON.stringify({"model": model, "start": start.position,
		"driven": driven.position, "drive_velocity": driven.velocity, "brake_velocity": braked.velocity}))
	await finish()


func test_cancelled_preload() -> void:
	if not setup(&"trialsbike"):
		await finish()
		return
	for tick: int in range(28):
		step({"primary": true})
	expect(bool(rig.observation().player_movement.preload_armed), "cancellation starts from actual preload")
	var before: Vector2 = rig.observation().velocity
	rig.cancel()
	var actual: Vector2 = PhysicsServer2D.body_get_state(rig.bodies()[0].get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	expect(actual.is_equal_approx(before), "cancel preserves physical momentum")
	expect(not bool(rig.observation().player_movement.preload_armed), "cancel discards preload")
	var released: Dictionary = step({})
	expect(Vector2(released.velocity).y > -8.0, "cancelled release does not launch")
	await finish()


func test_flight() -> void:
	if setup(&"arcadelander", false):
		var start: Vector2 = rig.observation().position
		for tick: int in range(45):
			step({"primary": true})
		var driven: Dictionary = rig.observation()
		expect(Vector2(driven.position).y < start.y - 30.0, "lander strong main engine")
		expect(Vector2(driven.velocity).y < -80.0, "lander arcade speed")
		for tick: int in range(90):
			step({})
		var damped: float = Vector2(rig.observation().velocity).length()
		expect(damped < Vector2(driven.velocity).length() * 0.25, "default lander damping settles velocity")
		step({"auxiliary": true})
		expect(bool(rig.observation().player_movement.drift), "lander drift toggles on edge")
		for tick: int in range(10):
			step({"auxiliary": true})
		expect(bool(rig.observation().player_movement.drift), "held toggle does not oscillate")
		for tick: int in range(30):
			step({"primary": true})
		for tick: int in range(45):
			step({"secondary": true})
		expect(Vector2(rig.observation().velocity).length() < 6.0, "airbrake overrides drift")
	await finish()
	if setup(&"jetbarrel", false):
		for tick: int in range(60):
			step({"trim": 1.0})
		expect(float(rig.observation().angular_velocity) > 6.0, "jet barrel strong rotational authority")
		for tick: int in range(50):
			step({"secondary": true})
		expect(absf(float(rig.observation().angular_velocity)) < 0.5, "barrel brake damps spin")
		expect(str(rig.observation().fault).is_empty(), "barrel remains finite")
	await finish()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "real pinned Rapier present")
	test_catalogue()
	await test_ground_vehicle(&"stuntbuggy")
	await test_ground_vehicle(&"trialsbike")
	await test_cancelled_preload()
	await test_flight()
	owner.free()
	await process_frame
	print("Player vehicle controls: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
