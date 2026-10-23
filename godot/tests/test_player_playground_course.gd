extends SceneTree

# Focused traversability checks against the authored native course and actual
# mounted Rapier assemblies. Controls use admitted action packets; no body pose
# or velocity is assigned. Local tunnel staging is an ordinary arena spawn.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")

var assertions: int = 0
var failures: int = 0
var owner: Node2D
var runtime
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_COURSE: " + message)


func configure(id: StringName, staging: Vector2 = Vector2.ZERO) -> bool:
	var accepted: bool = runtime.configure(id)
	expect(accepted, "course configures " + str(id))
	if accepted and staging != Vector2.ZERO:
		# This isolated fixture starts next to the tunnel so it measures physical
		# clearance without requiring an autopilot to solve the earlier ramp.
		accepted = runtime._arena.configure({"version": Arena.VERSION, "seed": 0,
			"max_ticks": Arena.MAX_TICKS, "local_patch_radius": 0, "course": Course.ID,
			"actors": [{"model": str(id), "producer": "human", "position": staging}]})
		expect(accepted, "ordinary local tunnel staging is admitted")
	return accepted


func extent() -> Rect2:
	var bounds := Rect2()
	var first: bool = true
	for part: Dictionary in runtime.render_parts():
		var pose: Transform2D = part.transform
		var half: Vector2 = Vector2(part.size) * 0.5
		var points: Array[Vector2] = []
		if str(part.shape) == "circle":
			for index: int in range(32):
				points.append(pose.origin + Vector2.from_angle(float(index) * TAU / 32.0) * half.x)
		else:
			for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
				points.append(pose * corner)
		for point: Vector2 in points:
			bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
			first = false
	return bounds


func step(action: Dictionary) -> Dictionary:
	var packet: Dictionary = action.duplicate(true)
	packet.effort = 1.0
	expect(runtime.submit_action(packet), "course action is admitted")
	runtime.step()
	return runtime.observation()


func test_spawn_coupling() -> void:
	for id: StringName in Catalog.rigs_in_set(&"setP"):
		if not configure(id):
			continue
		var view: Dictionary = runtime.observation()
		var bounds: Rect2 = extent()
		expect(bounds.end.y <= Course.FLOOR_Y and bounds.position.y > Course.VIEW.position.y + 4,
			"complete mounted spawn clears floor and ceiling: " + str(id))
		expect(bounds.position.x > Course.VIEW.position.x + 4 and bounds.end.x < 224,
			"complete mounted spawn clears wall and ramp: " + str(id))
		expect(int(view.part_count) == Catalog.entry(id).parts.size() + 1 and int(view.part_count) <= 8,
			"spawn includes the actual permanent equipment mount within capacity")
		for part: Dictionary in runtime.render_parts():
			var point := Vector2i(Transform2D(part.transform).origin.floor())
			expect(int(runtime._arena._world.rigid_body_id_at(point.x, point.y)) > 0,
				"native coupling owns each initial physical part centre")
		for tick: int in range(20):
			step({})
		expect(not runtime.failed and runtime.tick == int(runtime._arena._world.get_tick_index()),
			"spawn advances native and physical ownership together")


func test_vehicle_approach(id: StringName) -> void:
	if not configure(id):
		return
	var gates: PackedVector2Array = Course.checkpoints(id)
	var nearest: Vector2 = Vector2(INF, INF)
	var highest: float = 1000.0
	var furthest: float = 178.0
	for tick: int in range(300):
		var view: Dictionary = step({"move": Vector2.UP})
		var position: Vector2 = view.position
		nearest.x = minf(nearest.x, position.distance_to(gates[0]))
		nearest.y = minf(nearest.y, position.distance_to(gates[1]))
		furthest = maxf(furthest, position.x)
		if position.x >= 250.0:
			highest = minf(highest, position.y)
		if nearest.x <= 15.0 and nearest.y <= 15.0 and position.x > 306.0:
			break
	expect(not runtime.failed, "vehicle ramp traversal remains healthy: " + str(id))
	expect(nearest.x <= 15.0, "ordinary throttle reaches first vehicle checkpoint: " + str(id))
	expect(nearest.y <= 15.0 and furthest > 306.0 and highest < 322.0,
		"ordinary throttle climbs the launch ramp and reaches its checkpoint: " + str(id))
	metrics[str(id)] = {"nearest_first": nearest.x, "nearest_ramp": nearest.y,
		"furthest_x": furthest, "highest_ramp_y": highest, "ticks": runtime.tick}


func test_tunnel() -> void:
	var data: Dictionary = Equipment.definition(Catalog.entry(&"acrobat"))
	if not configure(&"acrobat", Vector2(358.0, Course.FLOOR_Y - float(data.spawn_floor_clearance))):
		return
	for tick: int in range(60):
		step({})
	var standing_height: float = extent().size.y
	# Slide is a moving posture. Establish a short run-up before holding it;
	# do not mistake a stationary crouch request for the fully settled slide.
	for tick: int in range(16):
		step({"move": Vector2.RIGHT})
	var furthest: float = 358.0
	var tunnel_height: float = 0.0
	var minimum_slide_height: float = standing_height
	var entered: bool = false
	var left: bool = false
	var tucked_inside: bool = false
	for tick: int in range(150):
		var view: Dictionary = step({"move": Vector2.RIGHT, "secondary": true})
		var position: Vector2 = view.position
		furthest = maxf(furthest, position.x)
		minimum_slide_height = minf(minimum_slide_height, extent().size.y)
		if position.x > 392.0 and position.x < 426.0:
			entered = true
			tunnel_height = maxf(tunnel_height, extent().size.y)
			tucked_inside = tucked_inside or str(view.player_movement.stance) == "tucked"
		if extent().position.x > 442.0:
			left = true
			break
	expect(not runtime.failed, "tunnel controls retain healthy physical ownership")
	expect(entered and left and tucked_inside, "running slide clears the low tunnel with the complete mounted Acrobat")
	expect(minimum_slide_height < standing_height - 1.0 and tunnel_height <= 12.5,
		"the tunnel traversal uses a lower actual articulated collision silhouette")
	# Natural impacts can also fold a running rig. This is a low-clearance route,
	# not an artificial rule that refuses every non-slide input sequence.
	metrics["acrobat_tunnel"] = {"standing_height": standing_height,
		"minimum_slide_height": minimum_slide_height, "tunnel_height": tunnel_height,
		"furthest_x": furthest, "complete_exit": left, "ticks": runtime.tick}


func flight_action(view: Dictionary, target: Vector2) -> Dictionary:
	var position: Vector2 = view.position
	var velocity: Vector2 = view.velocity
	var desired := Vector2(clampf((target.x - position.x) * 2.4 - velocity.x * 4.0, -140.0, 140.0),
		clampf((target.y - position.y) * 3.2 - velocity.y * 4.0 - 32.0, -260.0, 60.0))
	var angle_error: float = wrapf(desired.angle() + PI * 0.5 - float(view.rotation), -PI, PI)
	var lean: float = clampf(angle_error * 0.9 - float(view.angular_velocity) * 0.25, -1.0, 1.0)
	var throttle: float = minf(desired.length() / 440.0, 0.85)
	if cos(angle_error) < 0.3:
		throttle = 0.0
	return {"move": Vector2(lean, -throttle).limit_length(1.0)}


func test_lander_gate() -> void:
	if not configure(&"arcadelander"):
		return
	# Stage before the first slalom, then cross its actual gap. This deliberately
	# proves a short feasible path rather than testing a whole-course autopilot.
	var points: Array[Vector2] = [Course.checkpoints(&"arcadelander")[0], Vector2(304, 195), Vector2(358, 195)]
	var reached: int = 0
	var nearest_gate: float = INF
	for tick: int in range(900):
		var view: Dictionary = step(flight_action(runtime.observation(), points[reached]))
		var position: Vector2 = view.position
		nearest_gate = minf(nearest_gate, position.distance_to(Course.checkpoints(&"arcadelander")[1]))
		if position.distance_to(points[reached]) < 9.0:
			reached += 1
			if reached == points.size():
				break
	expect(not runtime.failed, "lander slalom retains healthy real physical ownership")
	expect(reached == points.size() and nearest_gate <= 15.0,
		"bounded thruster and torque controls can reach and cross the first flight gate")
	expect(runtime._arena._world.material_at(337, 150) == 62 and runtime._arena._world.material_at(337, 240) == 62,
		"flight navigation preserves both native gate walls")
	metrics["lander_gate"] = {"staging_points_reached": reached, "nearest_gate": nearest_gate,
		"position": runtime.observation().position, "ticks": runtime.tick}


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	runtime = Runtime.new()
	owner.add_child(runtime)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or "--spawn" in args:
		test_spawn_coupling()
	if args.is_empty() or "--vehicles" in args:
		for id: StringName in [&"stuntbuggy", &"trialsbike"]:
			test_vehicle_approach(id)
	if args.is_empty() or "--tunnel" in args:
		test_tunnel()
	if args.is_empty() or "--flight" in args:
		test_lander_gate()
	runtime.close()
	owner.free()
	await process_frame
	print("PLAYER_COURSE_METRICS ", JSON.stringify(metrics))
	print("PLAYER_COURSE: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
