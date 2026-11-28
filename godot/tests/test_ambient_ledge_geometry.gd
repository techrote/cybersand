extends SceneTree

# Independent physical-owner regression. These are real Rapier collision queries
# against explicit static fixtures, not material sensing or full gameplay proof.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
var checks := 0
var failures: Array[String] = []
var owner: Node2D
var rig: Node2D
var bridge: RefCounted
var completed := false


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_LEDGE_GEOMETRY: " + label)


func box(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	body.add_child(collider)
	owner.add_child(body)
	return body


func sample() -> Dictionary:
	bridge.step()
	rig.refresh_observation()
	return rig.ambient_ledge_observation(12.0,16.0,Vector2i(256,256))


func geometry_cases() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	rig = Rig.new()
	owner.add_child(rig)
	check(rig.configure(Catalog.entry(&"runner"),Vector2(100,80),0,1)==OK,
		"accepted articulated actor configured")
	if not rig.configured: return
	bridge = Bridge.new()
	check(bridge.initialize(owner.get_world_2d().space,rig.bodies(),rig.body_sizes())==OK,
		"actual manually stepped Rapier bridge configured")
	if not bridge.is_initialized(): return
	var empty := sample()
	check(empty.ray_queries==2 and bool(empty.left.available) and bool(empty.right.available),
		"two separate bounded probes in empty interior are admitted")
	check(not empty.left.support_found and not empty.right.support_found and empty.right.lower_bound,
		"no physical support gives a searched-depth lower bound")
	check(empty.right.drop_cells>16.0 and is_equal_approx(empty.right.searched_drop_cells,16.0),
		"empty full-depth ray reports only the admitted drop lower bound")
	var bottom: float = Vector2(empty.right.origin).y+2.0
	var floor := box(Vector2(128,bottom+6.0),Vector2(256,4))
	var flat := sample()
	check(flat.left.available and flat.right.available and flat.left.support_found and flat.right.support_found,
		"real flat static support detected at both lookahead points")
	check(float(flat.right.drop_cells)>2.5 and float(flat.right.drop_cells)<5.0,
		"physical support drop measured relative to current attached-part hull")
	var wall := box(Vector2(Vector2(flat.right.origin).x,bottom+6.0),Vector2(8,32))
	var embedded := sample()
	check(not bool(embedded.right.available) and not bool(embedded.right.support_found),
		"probe originating inside a taller block is unavailable, never a false ledge")
	check(not bool(embedded.right.lower_bound) and not embedded.right.has("drop_cells") \
		and str(embedded.right.reason).contains("inside"),
		"occluded origin has an explicit reason and no fabricated drop distance")
	check(bool(embedded.left.available) and bool(embedded.left.support_found),
		"opposite unobstructed support remains independently available")
	var clipped_x: Dictionary = rig.ambient_ledge_observation(12.0,16.0,
		Vector2i(floori(Vector2(embedded.right.origin).x),256))
	check(not clipped_x.right.available and clipped_x.right.boundary and clipped_x.ray_queries==1,
		"canvas crossing is unavailable boundary coverage and spends no physical ray")
	wall.free()
	var clipped_y: Dictionary = rig.ambient_ledge_observation(12.0,16.0,Vector2i(256,ceili(bottom+8.0)))
	check(clipped_y.left.available and clipped_y.left.support_found,
		"support found before canvas clipping remains a valid copied measurement")
	floor.free()
	var missing := sample()
	var bottom_now: float = Vector2(missing.left.origin).y+2.0
	var clipped_empty: Dictionary = rig.ambient_ledge_observation(12.0,16.0,Vector2i(256,ceili(bottom_now+8.0)))
	check(not clipped_empty.left.available and clipped_empty.left.boundary,
		"empty ray cut by canvas cannot claim an observed physical ledge")
	var malformed: Dictionary = rig.ambient_ledge_observation(NAN,16.0,Vector2i(256,256))
	check(not malformed.available and malformed.ray_queries==0,"invalid query bounds spend no rays")
	completed = true


func run() -> void:
	geometry_cases()
	check(completed,"physical probe cases completed without early script abort")
	if bridge!=null: bridge.shutdown()
	if is_instance_valid(rig): rig.close()
	if is_instance_valid(owner): owner.free()
	print("AMBIENT_LEDGE_GEOMETRY ",JSON.stringify({"checks":checks,"failures":failures,
		"scope":"actual Rapier terrain rays; no native material or Windows playfeel claim"}))
	quit(0 if failures.is_empty() else 1)
