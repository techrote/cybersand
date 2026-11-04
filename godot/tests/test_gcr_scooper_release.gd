extends SceneTree

# Mechanical support retirement, separate from the registered24-case physical
# population. Zero actuator ceilings prevent hover/level motors hiding a fall.
const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Base=preload("res://qualification/gcr_creep_capture.gd")
const CENSUS:=Rect2i(384,200,256,200)
const BED:=Rect2i(480,252,80,64)
const FLOOR:=Rect2i(16,316,992,6)
const EXCAVATION:=Rect2i(384,224,256,92)
var checks: int=0
var failures: Array[String]=[]
var reports: Array[Dictionary]=[]

func _init() -> void: call_deferred("_run")
func check(ok: bool,why: String) -> bool:
	checks+=1
	if not ok: failures.append(why);printerr("FAIL SCOOPER RELEASE: ",why)
	return ok
func neutral() -> Dictionary:
	return {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":1.0,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
func step(runtime,arm: String) -> Dictionary:
	var arena=runtime._arena
	var before_native: int=arena._world.get_tick_index()
	var before_rapier: int=arena.session.bridge.manual_step_count()
	check(runtime.submit_review_action(neutral(),{"q":false,"e":false,"s":false,"boost":false}),"neutral zero-ceiling command "+arm)
	var snapshot: Dictionary=runtime.step()
	check(not snapshot.failed,"actual owner remains healthy "+arm)
	check(int(arena._world.get_tick_index())==before_native+1 and arena.session.bridge.manual_step_count()==before_rapier+1,"one actual native/Rapier step "+arm)
	var actuation: Dictionary=arena.session._rigs[0]._player_controller.observation()
	check(actuation.applied_force==Vector2.ZERO and float(actuation.applied_torque)==0.0,"zero motor ceilings cannot support or rotate the body "+arm)
	var application: Dictionary=arena.session.bridge.gcr_application_diagnostics()
	check(application.get("accepted",false) and application.get("bodies",[]).size()==1,"one accepted physical response "+arm)
	return arena._world.gcr_compound_diagnostics()

func release(arm: String) -> void:
	var runtime=Runtime.new()
	root.add_child(runtime)
	var options: Dictionary={"response":arm,"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":0.0,"torque_multiplier":0.0,"boost_multiplier":2.0}
	if not check(runtime.configure_review_fleet(Fleet.index_for_id("scooper"),options,Vector2(512,240)),"fresh Scooper owner "+arm):
		runtime.close();runtime.free();return
	var arena=runtime._arena
	var native: Object=arena._world
	var body: RigidBody2D=arena.session.bodies()[0]
	check(arena.session.bodies().size()==1,"one body for all six hull pieces "+arm)
	check(native.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear old course cells without replacing owner "+arm)
	check(native.diagnostic_fill_rect(FLOOR.position,FLOOR.size,58),"distant hard floor below deep support "+arm)
	check(native.diagnostic_fill_rect(BED.position,BED.size,2),"author explicit packed granular support "+arm)
	var before: Dictionary=native.diagnostic_snapshot(CENSUS.position,CENSUS.size,false,false)
	check(int(before.counts[2])==BED.size.x*BED.size.y,"exact authored Sand quantity "+arm)
	# Gravity alone creates the approach. No pose/velocity writes can overwrite
	# a queued first-step wrench or hide release; the hull starts clear of Sand.
	var positive: bool=false
	var positive_tick: int=-1
	var bearing: Dictionary={}
	var approach_before: Dictionary={}
	var approach_after: Dictionary={}
	for tick: int in range(90):
		approach_before=Base.state(body)
		var d: Dictionary=step(runtime,arm)
		approach_after=Base.state(body)
		if float(d.get("normal_accepted",0.0))>1e-6 and float(d.get("source_capacity",0.0))>0:
			positive=true;positive_tick=tick;bearing=d.duplicate(true);break
	check(positive,"real granular bearing admits downward approach before excavation "+arm)
	check(float(approach_before.velocity.y)>0 and float(approach_after.velocity.y)<float(approach_before.velocity.y),"actual granular response decelerates gravity-driven approach "+arm)
	var at_removal: Dictionary=Base.state(body)
	check(float(at_removal.position.y)+Fleet.bounds(Fleet.index_for_id("scooper")).end.y<float(FLOOR.position.y)-30.,"hard floor cannot be the observed support "+arm)
	var supported: Dictionary=native.diagnostic_snapshot(CENSUS.position,CENSUS.size,false,false)
	var hash_before: String=native.get_physical_state_hash()
	check(native.diagnostic_fill_rect(EXCAVATION.position,EXCAVATION.size,0),"explicit tracked excavation "+arm)
	var removed: Dictionary=native.diagnostic_snapshot(CENSUS.position,CENSUS.size,false,false)
	check(int(removed.counts[2])==0,"all granular support is actually absent "+arm)
	check(int(removed.counts[58])==int(supported.counts[58]) and int(removed.water_mass)==int(supported.water_mass),"excavation leaves hard floor and Water quantity unchanged "+arm)
	var first: Dictionary={}
	var max_fall: float=0.0
	var source_max: float=0.0
	var correction_max: float=0.0
	var first_fall_tick: int=-1
	for tick: int in range(60):
		var d: Dictionary=step(runtime,arm)
		if tick==0: first=d.duplicate(true)
		source_max=maxf(source_max,float(d.get("source_capacity",INF)))
		correction_max=maxf(correction_max,Vector2(d.get("correction",Vector2.INF)).length())
		check(float(d.get("normal_accepted",INF))==0.0 and float(d.get("source_capacity",INF))==0.0,"fresh removed support cannot retain bearing "+arm)
		check(d.get("correction",Vector2.INF)==Vector2.ZERO,"fresh removed support cannot retain correction "+arm)
		var current: Dictionary=Base.state(body)
		var fall: float=float(current.position.y)-float(at_removal.position.y)
		max_fall=maxf(max_fall,fall)
		if first_fall_tick<0 and fall>=1.: first_fall_tick=tick
	check(max_fall>=1. and first_fall_tick>=0,"unsupported body genuinely falls at least one cell within60ticks "+arm)
	var after: Dictionary=native.diagnostic_snapshot(CENSUS.position,CENSUS.size,false,false)
	check(Base.same_quantity(removed,after),"closed post-excavation material remains conserved "+arm)
	reports.append(Base.portable({"response":arm,"options":options,"bed":[BED.position.x,BED.position.y,BED.size.x,BED.size.y],
		"excavation":[EXCAVATION.position.x,EXCAVATION.position.y,EXCAVATION.size.x,EXCAVATION.size.y],
		"floor":[FLOOR.position.x,FLOOR.position.y,FLOOR.size.x,FLOOR.size.y],
		"positive_tick":positive_tick,"bearing_before":bearing,"at_removal":at_removal,"first_fresh_after":first,
		"approach_before":approach_before,"approach_after":approach_after,
		"max_fall":max_fall,"first_fall_tick":first_fall_tick,"source_capacity_after_max":source_max,"correction_after_max":correction_max,
		"intentional_sand_removed":int(supported.counts[2])-int(removed.counts[2]),"hash_before_excavation":hash_before,
		"before":before,"supported":supported,"removed":removed,"after":after,"final":Base.state(body)}))
	runtime.close();runtime.free()

func _run() -> void:
	for arm: String in ["LA","LA-EVENT-OFF","LA-SELECTIVE"]: release(arm)
	print("GCR_SCOOPER_RELEASE ",JSON.stringify(Base.portable({"checks":checks,"failures":failures,"reports":reports})))
	quit(0 if failures.is_empty() else 1)
