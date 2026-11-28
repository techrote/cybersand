extends SceneTree

# Representative remote-actor regression, not a reconstruction of the owner's
# unrecorded pointer sequence. The existing Tower's passive barrel is >150 cells
# from the support cuts and never contacts the detached facade in this window.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var barrel: RID
var reference := Vector2.ZERO
var monitor: bool = false
var maximum_displacement: float = 0.0
var maximum_upward_speed: float = 0.0
var observations: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _sample() -> void:
	if not monitor or not barrel.is_valid(): return
	var pose: Transform2D = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	maximum_displacement = maxf(maximum_displacement,pose.origin.distance_to(reference))
	maximum_upward_speed = maxf(maximum_upward_speed,-velocity.y)
	if observations.size()<16 and (pose.origin.distance_to(reference)>.25 or velocity.y < -1.0):
		observations.append({"tick":f.tick(),"x":pose.origin.x,"y":pose.origin.y,"vx":velocity.x,"vy":velocity.y,
			"phase":f.runtime().phase,"bodies":f.body_count()})

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish()
		return
	f.play()
	if not await f.advance(180,"reference barrel naturally falls and settles before remote cuts"):
		await _finish()
		return
	await f.pause()
	var actor_bodies: Array = f.host.physical_actor_session.bodies()
	if not f.expect(actor_bodies.size()==1,"Tower has exactly its separate reference barrel"):
		await _finish()
		return
	barrel = actor_bodies[0].get_rid()
	var pose: Transform2D = PhysicsServer2D.body_get_state(barrel,PhysicsServer2D.BODY_STATE_TRANSFORM)
	reference = pose.origin
	f.expect(reference.x>350.0 and reference.y>450.0,"actual barrel has settled far from the structure")
	monitor = true
	process_frame.connect(_sample)
	# A small notch severs one support but leaves the other load-bearing. A
	# stationary supported facade is physically valid, not a simulated failure.
	f.bench._brush.value = 3
	f.expect(f.bench.paint(Vector2i(140,410),0),"ordinary Erase makes a remote support notch")
	await f.until(func(): return f.runtime().physics_ready() and f.coherent() \
		and not f.host.simulation_worker.paint_state().get("legacy_busy",true),"remote notch and collider publication finish")
	f.play()
	await f.advance(60,"single support notch leaves ordinary simulation operational")
	await f.pause()
	f.expect(maximum_displacement<.25 and maximum_upward_speed<1.0,
		"remote first support cut does not launch the reference barrel")
	await f.cut_supports("tower",2)
	f.play()
	await f.until(func(): return f.body_count()>=1,"full remote support removal detaches actual native structure")
	await f.advance(120,"remote Tower falls and collides while independent barrel remains at rest")
	await f.pause()
	f.expect(actor_bodies[0].get_rid()==barrel,"cuts and geometry publication preserve the actual barrel RID")
	f.expect(maximum_displacement<.25 and maximum_upward_speed<1.0,
		"remote detachment and collapse do not inject barrel impulse")
	f.expect(f.diagnostics().get("held_reason","").is_empty(),"remote cuts and natural collapse avoid protective Held")
	await f.validate_quantity_ledger()
	f.validate_physics()
	f.validate_display()
	await _finish()

func _finish() -> void:
	monitor = false
	if process_frame.is_connected(_sample): process_frame.disconnect(_sample)
	var result: Dictionary = {"schema":"objectshard-m4-remote-barrel-v1","checks":f.checks,"failures":f.failures,
		"maximum_displacement_cells":maximum_displacement,"maximum_upward_speed_cells_s":maximum_upward_speed,
		"anomalies":observations,"platform":OS.get_name(),"engine":Engine.get_version_info(),
		"scope":"actual ordinary Tower, ordinary Erase, live native owner and independent Main Rapier barrel; representative sequence, not original owner pointer reconstruction"}
	await f.close()
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
