extends SceneTree

const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Source=preload("res://scripts/gcr_painting_powder_source.gd")
var checks: int=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures.append(why);push_error(why);quit(1)
func options(response: String) -> Dictionary:
	return {"response":response,"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0}
func _run() -> void:
	var runtime=Runtime.new();root.add_child(runtime);await process_frame
	for response: String in ["LA","LA-EVENT-OFF","LA-SELECTIVE"]:
		for index: int in range(7):
			check(runtime.configure_review_fleet(index,options(response)),"normal full roster construction")
			var arena=runtime._arena
			var body: RigidBody2D=arena.session.bodies()[0]
			var before_pose: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
			var before_epoch: int=runtime.epoch
			check(is_equal_approx(body.gravity_scale,38.0/980.0),"live source retains ordinary gravity")
			var source=Source.new()
			check(not source.armed and source.before_step(arena) and source.attempted==0,"source starts off")
			check(arena._world.diagnostic_fill_rect(Vector2i(600,70),Vector2i(4,24),0),"prepare empty source region")
			var before: Dictionary=arena._world.diagnostic_snapshot(Vector2i(600,70),Vector2i(4,24),false,false)
			check(source.configure(Vector2i(600,70),2) and source.queue_burst(),"arm and queue without editing cells")
			check(arena._world.diagnostic_snapshot(Vector2i(600,70),Vector2i(4,24),false,false).cells==before.cells,"queued burst does not emit before owner step")
			runtime.set_paused(true)
			check(source.before_step(arena) and source.attempted==0 and source.burst_queued,"pause retains pending burst and freezes source")
			runtime.set_paused(false)
			check(source.before_step(arena),"bounded live burst")
			var after: Dictionary=arena._world.diagnostic_snapshot(Vector2i(600,70),Vector2i(4,24),false,false)
			check(source.attempted==96 and source.inserted==96 and source.blocked==0 and after.counts[2]==96,"actual96-cell native burst ledger")
			check(runtime.epoch==before_epoch and runtime.tick==0 and PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)==before_pose,"source leaves selected craft pose/session intact")
			check(source.queue_burst() and source.before_step(arena) and source.attempted==96,"same boundary cannot emit twice")
			source.stop()
			check(source.before_step(arena) and not source.burst_queued and not source.stream_enabled,"stop revokes queued source")
			check(runtime.submit_action({"move":Vector2.UP,"aim":Vector2.UP,"effort":1.0,"trim":0.0,"primary":true,"secondary":false,"auxiliary":false}),"normal pilot remains admitted")
			runtime.step()
			check(not runtime.failed and runtime.tick==1 and arena.session._rigs[0]._last_impulse.length()>0,"normal flight continues with source feature")
			check(arena._world.gcr_diagnostics().granular_events=={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}[response],"source preserves actual response selection")
	check(runtime.configure_review_fleet(2,options("LA-SELECTIVE")),"material policy fixture")
	var arena=runtime._arena
	var source=Source.new()
	for material: int in Source.MATERIALS:
		arena._world.diagnostic_fill_rect(Vector2i(650,70),Vector2i(4,24),0)
		check(source.configure(Vector2i(650,70),material) and source.queue_burst(),"all granular materials admitted")
		check(source.before_step(arena),"real native granular source")
		var snapshot: Dictionary=arena._world.diagnostic_snapshot(Vector2i(650,70),Vector2i(4,24),false,false)
		check(snapshot.counts[material]==96,"source writes selected granular material")
		runtime.step();check(not runtime.failed,"granular material retains existing native law")
	for bad: int in [0,3,58,-1,999]:
		var before: String=arena._world.get_physical_state_hash()
		check(not source.configure(Vector2i(650,70),bad) and not source.armed,"non-granular material refused")
		check(arena._world.get_physical_state_hash()==before,"refusal has no world mutation")
	check(not source.configure(Vector2i(10,70),2) and not source.configure(Vector2i(650,470),2),"complete source must fit room bounds")
	check(runtime.configure_review_fleet(2,options("LA-SELECTIVE")),"occupied source fixture")
	arena=runtime._arena;source.clear()
	arena._world.diagnostic_fill_rect(Vector2i(600,70),Vector2i(4,24),58)
	check(source.configure(Vector2i(600,70),2) and source.queue_burst() and source.before_step(arena),"occupied source attempts close")
	check(source.inserted==0 and source.blocked==96 and arena._world.material_at(600,70)==58,"source never overwrites hard terrain")
	runtime.step()
	arena._world.diagnostic_fill_rect(Vector2i(600,70),Vector2i(4,24),0)
	var body: RigidBody2D=arena.session.bodies()[0]
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(.7853981633974483,Vector2(601.5,70.5)))
	check(source.configure(Vector2i(600,70),2) and source.queue_burst() and source.before_step(arena),"actual rotated hull source guard")
	check(arena._world.material_at(601,70)==0 and source.blocked>96,"current hull refuses source beyond previous native mask")
	check(runtime.configure_review_fleet(0,options("LA")),"stream duration fixture")
	arena=runtime._arena;source.clear()
	arena._world.diagnostic_fill_rect(Vector2i(650,70),Vector2i(4,24),0)
	check(source.configure(Vector2i(650,70),14) and source.set_stream(true),"stream starts explicitly")
	for tick: int in range(600):
		check(source.before_step(arena),"bounded stream owner boundary")
		runtime.step();check(not runtime.failed,"stream does not replace or fail native owner")
	check(not source.stream_enabled and source.stream_ticks==600 and source.attempted==2400 and source.attempted==source.inserted+source.blocked,"stream has600-tick2400-attempt bound")
	var attempts: int=source.attempted
	check(source.before_step(arena) and source.attempted==attempts,"expired stream does not emit again")
	check(source.receipt().ledger.size()==Source.MAX_LEDGER and source.receipt().ledger_dropped>0,"source receipts have bounded ring capacity")
	check(source.set_stream(true) and source.stream_ticks==0,"new explicit stream toggle renews bounded duration")
	check(source.before_step(arena),"fresh stream renews on same owner")
	var old_attempts: int=source.attempted
	check(runtime.configure_review_fleet(1,options("LA")),"replace source owner")
	check(not source.before_step(runtime._arena) and not source.armed and source.attempted==old_attempts,"pending source cannot cross owner replacement")
	check(source.configure(Vector2i(650,70),14) and source.set_stream(true) and source.before_step(runtime._arena),"fresh configure authorizes replacement owner")
	source.stop();runtime.close();runtime.free()
	print("GCR_PAINTING_SOURCE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
