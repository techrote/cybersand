extends RefCounted

# Offline/review owner only. Same setup and step are used by CLI and playable scene.
# Native material authority and main-thread Rapier authority remain separate.
const TOKEN := "Y1-ENVELOPE-2026-11-01"
const SURFACE := 192
var spec: Dictionary
var candidate: String
var world: Object
var viewport: SubViewport
var bridge: CyberRapierPhysicsBridge
var bodies: Array[RigidBody2D] = []
var body_size := Vector2(8, 14)
var left: int
var width: int
var floor_y: int
var tick: int = 0
var expected: Dictionary
var edits: Array = []
var error: String = ""

func fill(x: int, y: int, w: int, h: int, material: int) -> void:
	if w > 0 and h > 0 and not world.diagnostic_fill_rect(Vector2i(x,y), Vector2i(w,h), material):
		error = "fixture fill refused"

func observation(include_cells: bool = false) -> Dictionary:
	var value: Dictionary = world.diagnostic_snapshot(Vector2i(left-1,0), Vector2i(width+2,floor_y+1), false, false)
	if not include_cells: value.erase("cells")
	return value

func setup(host: Node, configuration: Dictionary, arm: String, telemetry: bool = true) -> bool:
	spec = configuration.duplicate(true)
	candidate = arm
	if arm not in ["B0", "Y1"] or int(spec.get("ticks",1800)) > 1800: return false
	left = int(spec.get("left",96))
	width = int(spec.width)
	floor_y = SURFACE + int(spec.depth)
	body_size *= float(spec.size)
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	if world == null or not world.diagnostic_reset({"workers":1,"telemetry":telemetry,
		"bearing_candidate":arm,"bearing_experiment":TOKEN}): return false
	world.set_simulation_window(Vector2i(left-4,0), Vector2i(width+8,floor_y+4),0,0)
	fill(left-1,0,1,floor_y+1,1)
	fill(left+width,0,1,floor_y+1,1)
	fill(left-1,floor_y,width+2,1,1)
	fill(left-1,0,width+2,1,1)
	var layout: String = spec.layout
	var material: int = int(spec.material)
	if layout in ["slope","slope-slide"]:
		for x: int in range(width):
			var offset: int = x/4
			fill(left+x,SURFACE+offset,1,int(spec.depth)-offset,material)
	elif layout in ["edge","edge-exit"]:
		fill(left,SURFACE,width/2,int(spec.depth),material)
	elif layout == "loose":
		fill(left,SURFACE+16,width,int(spec.depth)-16,material)
		fill(left,SURFACE,width,1,material)
	else:
		fill(left,SURFACE,width,int(spec.depth),material)
	expected = observation()
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1024,768)
	host.add_child(viewport)
	var sizes := PackedVector2Array()
	var initial_centres := PackedVector2Array()
	var angle: float = float(spec.angle)
	var extent: float = absf(cos(angle))*body_size.y + absf(sin(angle))*body_size.x
	var body_x: float = left + width/2.0
	if layout in ["edge","edge-exit"]: body_x -= 2.0
	var local_surface: float = SURFACE
	if layout in ["slope","slope-slide"]: local_surface += floorf((body_x-left)/4.0)
	for index: int in range(int(spec.get("body_count",1))):
		var body := RigidBody2D.new()
		body.mass = float(spec.mass)
		body.gravity_scale = 0.094
		body.linear_damp = 0.15
		body.angular_damp = 0.35
		body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		body.position = Vector2(body_x + (index-.5)*float(spec.get("separation",0)), local_surface-extent/2.0-float(spec.gap))
		initial_centres.append(body.position)
		body.rotation = angle
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = body_size
		collision.shape = rectangle
		body.add_child(collision)
		viewport.add_child(body)
		bodies.append(body)
		sizes.append(body_size)
	await host.get_tree().process_frame
	bridge = CyberRapierPhysicsBridge.new()
	if bridge.initialize(viewport.world_2d.space,bodies,sizes) != OK: return false
	bridge.enable_diagnostics()
	for i: int in range(bodies.size()):
		bridge.reset_body(i,initial_centres[i],angle)
		PhysicsServer2D.body_set_param(bodies[i].get_rid(),PhysicsServer2D.BODY_PARAM_FRICTION,0.78)
		PhysicsServer2D.body_set_state(bodies[i].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0,float(spec.speed)))
		PhysicsServer2D.body_set_state(bodies[i].get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,float(spec.spin))
	bridge.refresh_all_states()
	bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	return error.is_empty()

func edit_at(step_index: int) -> void:
	if step_index == 600:
		var before: Dictionary = observation()
		match String(spec.layout):
			"excavate": fill(left,SURFACE,width,floor_y-SURFACE,0)
			"side-excavate": fill(left,SURFACE,width/2,floor_y-SURFACE,0)
			"collapse": fill(left,SURFACE+3,width,8,0)
			"reentry": world.set_simulation_window(Vector2i(768,768),Vector2i(64,64),0,0)
		var after: Dictionary = observation()
		if before.counts != after.counts or int(before.water_mass) != int(after.water_mass):
			edits.append({"tick":step_index,"before":before.counts,"after":after.counts,"water_before":before.water_mass,"water_after":after.water_mass})
			expected = after
	if step_index == 720 and spec.layout == "reentry":
		world.set_simulation_window(Vector2i(left-4,0),Vector2i(width+8,floor_y+4),0,0)

func pose(index: int) -> Array:
	var transform: Transform2D = bridge.body_transform(index)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(bodies[index].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	return [transform.origin.x,transform.origin.y,transform.get_rotation(),velocity.x,velocity.y,
		float(PhysicsServer2D.body_get_state(bodies[index].get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))]

func overlap(value: Dictionary, body_pose: Array) -> int:
	var extent_x: float = absf(cos(body_pose[2]))*body_size.x/2.0 + absf(sin(body_pose[2]))*body_size.y/2.0
	var extent_y: float = absf(cos(body_pose[2]))*body_size.y/2.0 + absf(sin(body_pose[2]))*body_size.x/2.0
	var result: int = 0
	var cells: PackedByteArray = value.cells
	for y: int in range(maxi(0,floori(body_pose[1]-extent_y)),mini(floor_y+1,ceili(body_pose[1]+extent_y))):
		for x: int in range(maxi(left-1,floori(body_pose[0]-extent_x)),mini(left+width+1,ceili(body_pose[0]+extent_x))):
			var delta := Vector2(x+.5-body_pose[0],y+.5-body_pose[1]).rotated(-float(body_pose[2]))
			if absf(delta.x) <= body_size.x/2 and absf(delta.y) <= body_size.y/2:
				var material: int = cells[y*(width+2)+x-left+1]
				if material != 0 and material != 1: result += 1
	return result

func conserved(value: Dictionary) -> bool:
	if int(value.water_mass) != int(expected.water_mass): return false
	for id: int in range(1,value.counts.size()):
		# Water cell count can vary; authoritative integer quantity must remain exact.
		if id != 3 and int(value.counts[id]) != int(expected.counts[id]): return false
	return true

func step(telemetry: bool = true) -> Array:
	edit_at(tick)
	var start: int = Time.get_ticks_usec()
	for i: int in range(bodies.size()):
		bridge.apply_horizontal_control(i,float(spec.horizontal) if tick >= 120 and tick < 480 else 0.0,24.0,80.0,3.0,1.0/60.0)
	bridge.step()
	var step_us: int = Time.get_ticks_usec()-start
	var states: PackedFloat32Array = bridge.pack_body_states() # exactly once per intended boundary
	var incoming: Array = []
	for i: int in range(bodies.size()): incoming.append(pose(i))
	var before: Dictionary = observation(true)
	start = Time.get_ticks_usec()
	world.prepare_rigid_body_coupling(states,true)
	var coupling_us: int = Time.get_ticks_usec()-start
	var after: Dictionary = observation(true)
	var diagnostics: Array = world.diagnostic_body_metrics() if telemetry else []
	start = Time.get_ticks_usec()
	if not world.simulation_tick(): error = "native tick failed"
	var tick_us: int = Time.get_ticks_usec()-start
	var results: PackedFloat32Array = world.rigid_body_results()
	start = Time.get_ticks_usec()
	bridge.apply_cellular_results(tick+1,results)
	var apply_us: int = Time.get_ticks_usec()-start
	var post: Dictionary = observation(true)
	var valid_conservation: bool = conserved(before) and conserved(after) and conserved(post)
	var rows: Array = []
	for i: int in range(bodies.size()):
		var outgoing: Array = pose(i)
		var row: Dictionary = {"tick":tick,"body":i+1,"in":incoming[i],"out":outgoing,
			"pre_overlap":overlap(before,incoming[i]),"post_overlap":overlap(after,incoming[i]),"tick_overlap":overlap(post,outgoing),
			"conserved":valid_conservation,"water":post.water_mass,"material_count":post.counts[int(spec.material)],
			"times_us":[step_us,coupling_us,tick_us,apply_us],"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()],
			"result":Array(results.slice(i*9,i*9+9)),"age":int(bridge.diagnostic_applications[i*6])}
		if telemetry:
			row["bearing_y"] = diagnostics[i][18]
			row["support"] = diagnostics[i][20]
		rows.append(row)
	tick += 1
	return rows

func close() -> void:
	if bridge != null: bridge.shutdown()
	if viewport != null: viewport.queue_free()
	world = null
