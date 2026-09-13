class_name CyberSolidingProbe
extends RefCounted

# Opt-in isolated stationary geometry experiment; all live Rapier calls stay here.
# Never attach these colliders on top of the production terrain partition.
static func wall_candidate(packet: Dictionary) -> Dictionary:
	for candidate: Dictionary in packet.get("candidates", []):
		if candidate.material == 1:
			return candidate
	return {}

static func run(host: Node, workers: int = 1) -> Dictionary:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	await host.get_tree().process_frame
	if not world.diagnostic_reset({"workers":workers}):
		return {"ok":false,"error":"reset"}
	await host.get_tree().process_frame
	world.diagnostic_fill_rect(Vector2i(36,52),Vector2i(8,8),1)
	world.diagnostic_fill_rect(Vector2i(32,60),Vector2i(32,2),40)
	if not world.diagnostic_soliding_configure(Vector2i(32,32),Vector2i(32,32)):
		return {"ok":false,"error":"configure"}
	var packet: Dictionary
	for tick: int in range(310):
		if not world.simulation_tick():
			return {"ok":false,"error":"tick"}
		packet = world.diagnostic_soliding_snapshot()
	var candidate: Dictionary = wall_candidate(packet)
	if not candidate.get("stationary",false):
		return {"ok":false,"error":"candidate did not qualify","candidate":candidate}
	var source: Dictionary = world.diagnostic_snapshot(Vector2i(32,32),Vector2i(32,32))
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(64,64)
	host.add_child(viewport)
	var body: RigidBody2D = RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.094
	body.position = Vector2(40,48)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(2,2)
	shape.shape = rectangle
	body.add_child(shape)
	viewport.add_child(body)
	await host.get_tree().process_frame
	var bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
	if bridge.initialize(viewport.world_2d.space,[body],PackedVector2Array([Vector2(2,2)])) != OK:
		viewport.queue_free()
		return {"ok":false,"error":"Rapier"}
	# The whole isolated partition contains exactly one island and this foundation.
	var proxy_rectangles: PackedInt32Array = candidate.rectangles.duplicate()
	proxy_rectangles.append_array(PackedInt32Array([32,60,32,2]))
	bridge.rebuild_hard_surface_colliders_from_rectangles(proxy_rectangles)
	bridge.reset_body(0,Vector2(40,48),0.0)
	for tick: int in range(120):
		bridge.step()
	var landed: float = bridge.body_transform(0).origin.y
	var conserved: Dictionary = world.diagnostic_snapshot(Vector2i(32,32),Vector2i(32,32))
	var ok: bool = landed < 52.1 and source.hash == conserved.hash and bridge.hard_surface_shape_count() == 2
	# Support loss invalidates this optimization; cells still own the static Wall.
	world.diagnostic_fill_rect(Vector2i(32,60),Vector2i(32,2),0)
	packet = world.diagnostic_soliding_snapshot()
	var invalid: Dictionary = wall_candidate(packet)
	ok = ok and not invalid.get("stationary",true) and invalid.revision > candidate.revision and invalid.id == candidate.id
	bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	ok = ok and bridge.hard_surface_shape_count() == 1
	# Excavating the authoritative island removes the sole remaining hard collider.
	world.diagnostic_fill_rect(Vector2i(36,52),Vector2i(8,8),0)
	packet = world.diagnostic_soliding_snapshot()
	ok = ok and wall_candidate(packet).is_empty()
	bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	ok = ok and bridge.hard_surface_shape_count() == 0
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_SLEEPING,false)
	for tick: int in range(30):
		bridge.step()
	var released: float = bridge.body_transform(0).origin.y
	ok = ok and released > landed + 3.0
	bridge.shutdown()
	viewport.queue_free()
	world = null
	await host.get_tree().process_frame
	return {"ok":ok,"workers":workers,"landed_y":landed,"released_y":released,"identity":candidate.id,"revision":candidate.revision,"invalidation_revision":invalid.revision,"material_authority":"cells","additional_support_solver":false,"invalidation_latency_steps":0}
