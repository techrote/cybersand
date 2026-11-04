extends SceneTree

# Actual constructor admission and reset controls; no physical efficacy claim.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); push_error(reason)
func options(response: String="LA") -> Dictionary:
	return {"response":response,"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0}
func pose(arena) -> Transform2D:
	return PhysicsServer2D.body_get_state(arena.session.bodies()[0].get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
func _run() -> void:
	var runtime=Runtime.new();root.add_child(runtime);await process_frame
	check(runtime.configure_review_fleet(0),"omitted position retains backward-compatible RFT construction")
	check(pose(runtime._arena).origin==Vector2(178,304),"default constructor position unchanged")
	for index: int in range(7):
		var size: Vector2=Fleet.ROWS[index][0]
		var half: Vector2=size*0.5
		for position: Vector2 in [Vector2(22,22)+half,Vector2(1002,475)-half]:
			check(Arena.valid_review_fleet_spawn(position,index),"exact zero-angle full hull boundary admitted")
		for position: Vector2 in [Vector2(22,22)+half-Vector2(.01,0),Vector2(1002,475)-half+Vector2(0,.01)]:
			check(not Arena.valid_review_fleet_spawn(position,index),"hull extent cannot cross a room wall")
		for response: String in ["LA","RFT","LA-EVENT-OFF","LA-SELECTIVE"]:
			for position: Vector2 in [Vector2(50,80),Vector2(960,80),Vector2(500,450)]:
				check(runtime.configure_review_fleet(index,options(response),position),"full roster/response admits explicit world position")
				var arena=runtime._arena
				check(pose(arena).origin==position and pose(arena).get_rotation()==0.0,"actual backend starts at authored level position")
				check(arena.config.actors[0].position==position,"reset authoring metadata records actual position")
				check(arena.session.bodies()[0].linear_velocity==Vector2.ZERO and arena.session.bodies()[0].angular_velocity==0.0,"fresh constructor retains zero initial momentum")
				var epoch: int=arena.session.epoch
				check(arena.reset(),"arena reset reconstructs explicit position")
				check(arena.session.epoch>epoch and pose(arena).origin==position,"fresh reset owner preserves exact position")
				check(arena.config.review_fleet_index==index and arena.config.review_options==options(response),"position does not alter craft/response authoring")
		var owner=runtime._arena
		var epoch: int=owner.session.epoch
		var hash_before: String=owner._world.get_physical_state_hash()
		var position_before: Vector2=pose(owner).origin
		for bad: Vector2 in [Vector2(NAN,80),Vector2(INF,80),Vector2(80,-INF),Vector2(-1,80),Vector2(1024,80),Vector2(80,512),Vector2(22,80),Vector2(1002,80),Vector2(80,22),Vector2(80,475)]:
			check(not runtime.configure_review_fleet(index,options(),bad),"nonfinite/outside/hull-crossing spawn refused")
			check(runtime._arena==owner and owner.session.epoch==epoch and runtime.active(),"invalid spawn preserves existing live owner")
			check(pose(owner).origin==position_before and owner._world.get_physical_state_hash()==hash_before,"refused spawn does not move body or edit material")
	check(not Arena.valid_review_fleet_spawn(Vector2(178,304),-1) and not Arena.valid_review_fleet_spawn(Vector2(178,304),Fleet.count()),"invalid roster indices refused before footprint lookup")
	# The expanded rectangle belongs only to the normal developer fleet route.
	var ordinary=runtime._arena
	var ordinary_config: Dictionary={"version":Arena.VERSION,"seed":0,"max_ticks":100,"local_patch_radius":0,
		"course":"player-playground-v1","actors":[{"model":"arcadelander","producer":"human","position":Vector2(960,80)}]}
	# Use the source course identity rather than assuming the UI's label.
	ordinary_config.course=preload("res://scripts/player_playground_course.gd").ID
	var ordinary_epoch: int=ordinary.session.epoch
	check(not ordinary.configure(ordinary_config),"ordinary actor route still refuses positions outside ARENA_RECT")
	check(ordinary.session.epoch==ordinary_epoch,"ordinary refusal preserves active session")
	var valid_config: Dictionary=ordinary_config.duplicate(true)
	valid_config.actors[0].position=Vector2(178,304)
	check(not ordinary._validated_config(valid_config).is_empty(),"ordinary ARENA_RECT position still valid")
	for response: String in ["LA","LA-EVENT-OFF","LA-SELECTIVE"]:
		check(runtime.configure_review_fleet(6,options(response),Vector2(960,80)),"custom normal room before isolated fixture")
		check(runtime.configure_review_powder_test(options(response)),"isolated fixture keeps separate API")
		check(pose(runtime._arena).origin==Vector2(512,256) and runtime._arena.config.powder_review,"isolated fixture ignores prior custom spawn")
		check(runtime._arena.reset() and pose(runtime._arena).origin==Vector2(512,256),"isolated reset remains canonical")
	check(runtime.configure_review_fleet(0,options()),"omitted custom position after fixture remains default")
	check(pose(runtime._arena).origin==Vector2(178,304),"runtime does not hide global spawn state")
	runtime.close();runtime.free()
	print("GCR_FLEET_SPAWN ",JSON.stringify({"checks":checks,"failures":failures,
		"scope":"Review constructor/reset admission; static authored hard geometry is checked by the UI before reset"}))
	quit(0 if failures.is_empty() else 1)
