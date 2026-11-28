extends SceneTree

# Representative support-contact sequence; the owner's pointer trace is not
# available. All cuts use ordinary Workbench Erase and all poses come from the
# actual Main-owned Rapier body, with native ownership still active.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var evidence: Dictionary = {}
var facade_id: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _facade() -> Dictionary:
	for body: Dictionary in f.diagnostics().get("physics",{}).get("bodies",[]):
		if int(body.id)==facade_id: return body
	return {}

func _remaining_posts() -> Array:
	var rows: Array = []
	var bytes: PackedByteArray = f.host.image.get_data()
	var channels: int = bytes.size()/(512*512)
	for x: int in [138,139,140,141,194,195,196,197]:
		var ys: Array = []
		for y: int in range(364,464):
			if int(bytes[(y*512+x)*channels])==1: ys.append(y)
		rows.append({"x":x,"world_wall_ys":ys})
	return rows

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	await f.pause()
	var wood: int = f.material_count(7)
	var brick: int = f.material_count(43)
	f.bench._brush.value = 3
	for x: int in [140,196]:
		if not f.expect(f.bench.paint(Vector2i(x,370),0),"ordinary Erase severs one complete support band"):
			await _finish(); return
		await process_frame
	f.play()
	if not await f.until(func(): return f.body_count()>0,"facade obtains an actual native-owned rigid body"):
		await _finish(); return
	var largest_mass: float = 0.0
	for body: Dictionary in f.diagnostics().physics.bodies:
		if float(body.mass)>largest_mass:
			facade_id = int(body.id)
			largest_mass = float(body.mass)
	var initial: Dictionary = _facade()
	var initial_tick: int = f.tick()
	var rid: RID = f.runtime().bridge.bodies[facade_id].rid
	if not await f.until(func(): return f.tick()>=initial_tick+120 and bool(_facade().get("sleeping",false)),
		"detached facade naturally rests on the remaining physical stumps",15000):
		evidence.failed_rest = f.diagnostics()
		await _finish(); return
	await f.pause()
	var resting: Dictionary = _facade()
	var resting_pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var query := PhysicsTestMotionParameters2D.new()
	query.from = resting_pose
	query.motion = Vector2(0,.1)
	query.margin = .001
	query.recovery_as_collision = true
	var collision := PhysicsTestMotionResult2D.new()
	var hit: bool = PhysicsServer2D.body_test_motion(rid,query,collision)
	var native_terrain: bool = false
	if hit:
		for chunk: Dictionary in f.runtime().bridge.terrain.values():
			if chunk.rid==collision.get_collider_rid(): native_terrain = true
	var point: Vector2 = collision.get_collision_point() if hit else Vector2.ZERO
	f.expect(f.runtime().bridge.bodies[facade_id].rid==rid and bool(resting.sleeping),
		"one native-owned physical facade retains its RID and solver-generated rest")
	f.expect(float(resting.y)>float(initial.y)+1.0 and float(resting.y)<float(initial.y)+15.0,
		"detached facade makes a real short fall before becoming stationary")
	f.expect(hit and native_terrain and collision.get_collision_normal().y<-.9 and point.y>370.0 and point.y<390.0,
		"actual nonmutating collision query identifies remaining native stump contact above the floor")
	evidence.contact = {"hit":hit,"native_terrain":native_terrain,"point":[point.x,point.y],
		"normal":[collision.get_collision_normal().x,collision.get_collision_normal().y] if hit else []}
	f.play()
	if not await f.advance(60,"native simulation continues while the detached facade rests"):
		await _finish(); return
	await f.pause()
	var after_rest: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	f.expect(after_rest.origin.distance_to(resting_pose.origin)<.1 and bool(_facade().sleeping),
		"stationary facade is genuine supported rest during ongoing native progression")
	evidence.initial = initial
	evidence.resting = resting
	evidence.support_before = _remaining_posts()
	evidence.native_ticks_while_resting = 60
	if not await f.cut_supports("tower",2):
		await _finish(); return
	f.play()
	if not await f.advance(120,"removing the grounded stumps permits renewed actual structural motion"):
		await _finish(); return
	await f.pause()
	var after_removal: Dictionary = _facade()
	evidence.support_after = _remaining_posts()
	evidence.paint_state_after = f.host.simulation_worker.paint_state()
	f.expect(not after_removal.is_empty() and f.runtime().bridge.bodies[facade_id].rid==rid,
		"support removal preserves the already detached facade owner")
	if not after_removal.is_empty():
		var displacement := Vector2(float(after_removal.x)-float(resting.x),float(after_removal.y)-float(resting.y))
		f.expect(displacement.length()>10.0 and displacement.y>5.0,
			"the same formerly stationary facade falls after remaining native support removal")
		evidence.after_support_removal = after_removal
		evidence.renewed_displacement = [displacement.x,displacement.y]
	f.expect(f.material_count(7)==wood and f.material_count(43)==brick,
		"both support stages conserve all facade Wood and Brick")
	await f.validate_quantity_ledger()
	f.validate_physics()
	await _finish()

func _finish() -> void:
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-supported-tower-v1","checks":f.checks,
		"failures":f.failures,"evidence":evidence,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual ordinary Tower and native-owned Rapier facade rests on retained native stumps then falls after their removal; representative sequence, not owner pointer reconstruction"}))
	quit(0 if f.failures.is_empty() else 1)
