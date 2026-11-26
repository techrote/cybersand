extends SceneTree

# Pure data qualification: no World, physics step, renderer or inference. These
# tests deliberately distinguish selected intent from actual physical travel.
const AmbientEngine = preload("res://scripts/ambient/ambient_engine.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
var checks: int = 0
var failures: int = 0
const GROUND := {"supported":true,"horizontal":true,"vertical":false,"ground":true,"jump":true,"family":"ground"}
const FLIGHT := {"supported":true,"horizontal":true,"vertical":true,"ground":false,"jump":false,"family":"flight"}


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("AMBIENT_ENGINE: " + label)


func profile(types: Array, seed: int = 24) -> Dictionary:
	var value: Dictionary = Profile.blank("test")
	value.seed = seed
	for type: String in types: value.modules.append(Profile.make_module(type))
	return value


func engine(value: Dictionary, actor_id: int = 101, capabilities: Dictionary = GROUND):
	var instance = AmbientEngine.new()
	check(bool(instance.configure(value,{"actor_id":actor_id,"home":Vector2(100,100),"capabilities":capabilities}).ok),"valid pure engine configuration")
	return instance


func observation(tick: int = 0, actor_id: int = 101) -> Dictionary:
	return {"version":"ambient-observation/v1","available":true,"instance_id":actor_id,
		"run_id":"pure-fixture","epoch":1,"actor_id":0,"control_generation":1,"tick":tick,
		"position":Vector2(100,100),"velocity":Vector2.ZERO,"suspended":false,
		"grounded":{"available":true,"value":true},
		"materials":{"available":true,"targets":{}},
		"ledges":{"available":true,"lookahead_cells":12.0,"left":{"available":true,"support_found":true,"drop_cells":0.0,"searched_drop_cells":32.0},
			"right":{"available":true,"support_found":true,"drop_cells":0.0,"searched_drop_cells":32.0}},
		"obstacles":{"available":true,"left_distance":40.0,"right_distance":40.0,"blocked":false},
		"bounds":{"available":true,"rect":Rect2(0,0,512,256)},
		"neighbors":{"available":true,"actors":[]}}


func material(o: Dictionary, id: int, point: Vector2, radius: float = 50.0, available: bool = true, present: bool = true) -> void:
	o.materials.targets[str(id)] = {"available":available,"present":present,"nearest":point,
		"distance":(o.position as Vector2).distance_to(point),"direction":(point - o.position).normalized(),
		"count":1 if present else 0,"radius_cells":radius,"coverage":"sampled-circle","sample_spacing_cells":4,
		"sample_tick":21,"revision":3}


func _material_rules() -> void:
	var p := profile(["seek_material"])
	var e = engine(p)
	var o := observation()
	material(o,16,Vector2(150,100))
	var result: Dictionary = e.step(o,0.0)
	check(result.direction.x > 0.9 and result.pace > 0.0,"inclusive radius50 material is acquired")
	check(result.candidates[0].reason == "approaching nearest observed material","diagnostic says observed target")
	o.tick += 1
	material(o,16,Vector2(150.01,100))
	check(e.step(o,0.1).direction == Vector2.ZERO,"material beyond radius50 is not acquired")
	o.tick += 1
	material(o,16,Vector2(50,100))
	check(e.step(o,0.6).direction.x < -0.9,"relocated material changes intent direction after declared cooldown")
	o.tick += 1
	material(o,16,Vector2(50,100),49.0)
	check(e.step(o,0.1).direction == Vector2.ZERO,"undersized coverage is unavailable")
	o.tick += 1
	material(o,16,Vector2(120,100),50.0,false)
	check(e.step(o,0.1).direction == Vector2.ZERO,"stale unavailable measurement never becomes material absence or zero distance")
	o.tick += 1
	material(o,16,Vector2(120,100))
	o.materials.targets["16"].distance = 2.0
	check(e.step(o,0.1).direction == Vector2.ZERO,"contradictory target scalar refuses acquisition")
	o.tick += 1
	material(o,16,Vector2(100,70))
	check(e.step(o,0.1).direction == Vector2.ZERO,"ground actor does not infer a path to an overhead target")
	var conflicted = engine(profile(["seek_material","avoid_material"]))
	o = observation()
	material(o,16,Vector2(140,100))
	material(o,3,Vector2(125,100))
	result = conflicted.step(o,0.0)
	check(result.active_override == "avoid_material" and result.direction.x < -0.9,"higher-priority Water avoidance overrides Oil attraction")
	o.tick += 1
	material(o,3,Vector2(142,100))
	check(conflicted.step(o,0.1).active_override == "avoid_material","avoidance exit hysteresis holds beyond entry threshold")
	o.tick += 1
	material(o,3,Vector2(147,100))
	check(conflicted.step(o,0.1).direction.x > 0.9,"avoidance releases outside exit threshold")
	o.tick += 1
	material(o,3,Vector2(142,100))
	check(conflicted.step(o,0.1).active_override.is_empty(),"avoidance does not reacquire inside only the release band")
	o.tick += 1
	material(o,3,Vector2(100,100))
	result = conflicted.step(o,0.1)
	check(result.direction.length() > 0.9,"coincident observed material gets a stable seeded escape axis")
	var side: float = result.direction.x
	o.tick += 1
	check(conflicted.step(o,0.1).direction.x == side,"coincident escape does not chatter")
	var seeker = engine(profile(["seek_material"]))
	o = observation()
	material(o,16,Vector2(106,100))
	check(seeker.step(o,0.0).active_override == "seek_material","arrival starts finite standoff dwell")
	o.tick = 1
	check(seeker.step(o,1.0).active_override.is_empty(),"dwell releases without refreshing on persistent target")
	o.tick = 2
	material(o,16,Vector2(109,100))
	check(seeker.step(o,0.1).direction == Vector2.ZERO,"standoff hysteresis prevents close reacquisition jitter")
	o.tick = 3
	material(o,16,Vector2(112,100))
	check(seeker.step(o,0.1).direction.x > 0.9,"standoff reacquires beyond release band")


func _ledge_timer_and_pause() -> void:
	var e = engine(profile(["avoid_ledge"]))
	var o := observation()
	o.ledges.right = {"available":true,"support_found":false,"drop_cells":32.0,"searched_drop_cells":32.0}
	var result: Dictionary = e.step(o,0.0)
	check(result.active_override == "avoid_ledge" and result.direction == Vector2.LEFT,"physical ledge starts away retreat")
	check(is_equal_approx(result.remaining_seconds,10.0),"retreat starts with exactly ten simulated seconds")
	for index: int in range(1,51):
		o.tick = index
		o.velocity = Vector2(30,0)
		result = e.step(o,0.1)
		check(result.direction == Vector2.LEFT and result.active_override == "avoid_ledge","latched direction persists while pose and hazard remain")
	check(absf(result.remaining_seconds - 5.0) < 0.00001,"retreat timer is not renewed by repeated edge observations")
	var before: Dictionary = e.diagnostics()
	o.suspended = true
	for index: int in 12: check(e.step(o,0.0).direction == Vector2.ZERO,"suspended engine yields neutral")
	check(e.diagnostics() == before,"pause consumes no timer, RNG, decisions or mutable state")
	o.suspended = false
	o.control_generation = 2
	check(e.step(o,0.0).remaining_seconds == before.intent.remaining_seconds,"fresh authority after pause preserves temporary intention")
	for index: int in range(51,100):
		o.tick = index
		result = e.step(o,0.1)
		check(result.active_override == "avoid_ledge","retreat holds until ten seconds of actual progression")
	o.tick = 100
	result = e.step(o,0.1)
	check(result.active_override.is_empty(),"retreat releases at ten simulated seconds")
	for index: int in range(101,110):
		o.tick = index
		check(e.step(o,0.1).active_override.is_empty(),"persistent original ledge cannot retrigger before rearm")
	o.ledges.right.support_found = true
	o.ledges.right.drop_cells = 0.0
	for index: int in range(110,115):
		o.tick = index
		e.step(o,0.1)
	o.tick = 115
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 32.0
	result = e.step(o,0.1)
	check(result.active_override == "avoid_ledge" and result.candidates[0].trigger_count == 2,"safe rearm allows a distinct second trigger")
	var p := profile(["avoid_ledge"])
	p.modules[0].params.rearm_seconds = 0.0
	p.modules[0].params.duration = 0.1
	var immediate = engine(p)
	o = observation()
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 32.0
	immediate.step(o,0.0)
	o.tick = 1
	check(immediate.step(o,0.1).active_override.is_empty(),"zero rearm delay still requires genuinely safe support")
	var missing = engine(profile(["avoid_ledge"]))
	o = observation()
	o.ledges.right.available = false
	check(missing.step(o,0.0).direction == Vector2.ZERO,"missing ledge sample is not safe ground or a zero drop")
	o.tick = 1
	o.ledges.right.available = true
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 32.0
	o.grounded.value = false
	check(missing.step(o,0.1).direction == Vector2.ZERO,"airborne ground actor cannot acquire grounded ledge reflex")


func _spatial_and_obstruction() -> void:
	var p := profile(["avoid_ledge","avoid_boundary"])
	var e = engine(p)
	var o := observation()
	o.position = Vector2(10,100)
	o.obstacles.right_distance = 2.0
	check(e.step(o,0.0).active_override == "avoid_boundary","canvas boundary is distinct from ledge and wall")
	var flyer = engine(profile(["avoid_boundary"]),101,FLIGHT)
	o = observation()
	o.position = Vector2(10,10)
	var result: Dictionary = flyer.step(o,0.0)
	check(result.direction.x > 0.6 and result.direction.y > 0.6,"flying corner retreat combines inward axes")
	var wall = engine(profile(["avoid_ledge"]))
	o = observation()
	o.obstacles.right_distance = 0.0
	check(wall.step(o,0.0).direction == Vector2.ZERO,"a nearby wall alone is not classified as a ledge")
	p = profile(["seek_material","escape_obstruction"])
	p.modules[1].params.jump = true
	var stuck = engine(p)
	o = observation()
	material(o,16,Vector2(140,100))
	o.obstacles.right_distance = 2.0
	stuck.step(o,0.0)
	for index: int in range(1,10):
		o.tick = index
		check(stuck.step(o,0.1).active_override.is_empty(),"obstruction is debounced against actual nonprogress")
	o.tick = 10
	result = stuck.step(o,0.1)
	check(result.active_override == "escape_obstruction" and result.direction.x < 0.0 and result.primary,"bounded escape reverses and requests one compatible grounded jump")
	o.tick = 11
	result = stuck.step(o,0.1)
	check(not result.primary and result.active_override == "escape_obstruction","escape jump is a single decision pulse")
	var moving = engine(p)
	o = observation()
	o.obstacles.right_distance = 2.0
	for index: int in 30:
		o.tick = index
		o.position.x += 0.2
		material(o,16,o.position + Vector2(30,0))
		check(moving.step(o,0.0 if index == 0 else 0.1).active_override.is_empty(),"real forward displacement prevents a false stuck reflex")
	var unavailable = engine(p)
	o = observation()
	material(o,16,Vector2(140,100))
	o.obstacles.available = false
	for index: int in 20:
		o.tick = index
		check(unavailable.step(o,0.0 if index == 0 else 0.1).active_override.is_empty(),"unavailable obstacle distance does not cause recovery")

	var unhit_profile := profile(["seek_material","escape_obstruction"])
	unhit_profile.modules[1].params.wall_distance = 29.0
	var unhit = engine(unhit_profile)
	o = observation()
	material(o,16,Vector2(140,100))
	o.obstacles.right_distance = 30.0
	o.obstacles.maximum_distance_cells = 30.0
	for index: int in 20:
		o.tick = index
		check(unhit.step(o,0.0 if index == 0 else 0.1).active_override.is_empty(),"no-hit wall distance never becomes an observed contact")


func _state_and_seed_independence() -> void:
	var p := profile(["wander","rest"])
	p.modules[0].params.turn_seconds = 0.5
	p.modules[0].params.idle_probability = 0.3
	p.modules[0].params.idle_seconds = 0.3
	p.modules[1].params.active_seconds = 2.0
	p.modules[1].params.rest_seconds = 0.4
	var first = engine(p)
	var second = engine(p)
	var other = engine(p,102)
	var different: int = 0
	var directions: Dictionary = {}
	var idle: int = 0
	var moving: int = 0
	for index: int in 500:
		var o := observation(index)
		var a: Dictionary = first.step(o,0.0 if index == 0 else 0.1)
		var inspected: Dictionary = first.diagnostics()
		inspected.intent.direction = Vector2(999,999)
		inspected.module_state.clear()
		var b: Dictionary = second.step(o,0.0 if index == 0 else 0.1)
		check(a == b,"same seeded input stream gives identical decision including diagnostics")
		o.instance_id = 102
		var c: Dictionary = other.step(o,0.0 if index == 0 else 0.1)
		if a.direction != c.direction or a.pace != c.pace: different += 1
		if a.direction == Vector2.ZERO: idle += 1
		else:
			moving += 1
			directions[str(signf(a.direction.x))] = true
	check(different > 50,"independent authored actor seeds do not accidentally synchronize")
	check(idle > 0 and moving > 0 and directions.size() == 2,"wander genuinely varies heading and has intentional idle intervals")
	var correlated_a = engine(profile(["wander"],101),101)
	var correlated_b = engine(profile(["wander"],102),102)
	var correlated_differences: int = 0
	for index: int in 50:
		var a: Dictionary = correlated_a.step(observation(index,101),0.0 if index == 0 else 0.1)
		var b: Dictionary = correlated_b.step(observation(index,102),0.0 if index == 0 else 0.1)
		if a.direction != b.direction or a.pace != b.pace: correlated_differences += 1
	check(correlated_differences > 0,"correlated profile seeds and actor IDs cannot cancel into a shared random stream")

	p.shared_seed = true
	var shared_a = engine(p,101)
	var shared_b = engine(p,102)
	for index: int in 50:
		var a: Dictionary = shared_a.step(observation(index,101),0.0 if index == 0 else 0.1)
		var b: Dictionary = shared_b.step(observation(index,102),0.0 if index == 0 else 0.1)
		check(a.direction == b.direction and a.pace == b.pace,"explicit shared seeds reproduce matching personalities")
	var original: Dictionary = first.diagnostics()
	var duplicate: Dictionary = first.step(observation(499),0.0)
	check(first.diagnostics() == original and duplicate == original.intent,"duplicate-tick inspection leaves state unchanged")
	check(first.step(observation(499),0.1).direction == Vector2.ZERO and first.diagnostics() == original,"duplicate tick cannot advance timers")
	check(first.step(observation(498),0.1).direction == Vector2.ZERO and first.diagnostics() == original,"regressed physical tick rejected without mutation")
	check(first.step(observation(500,999),0.1).direction == Vector2.ZERO and first.diagnostics() == original,"wrong authored actor identity rejected")
	var invalid: Dictionary = p.duplicate(true)
	invalid.modules[0].params.pace = NAN
	check(not bool(first.configure(invalid,{"actor_id":101,"home":Vector2(100,100),"capabilities":GROUND}).ok),"invalid configuration refused")
	check(first.diagnostics() == original,"invalid edit leaves valid producer and runtime intact")
	first.reset("handoff")
	check(first.diagnostics().decisions == 0 and first.diagnostics().elapsed_seconds == 0.0,"handoff reset retires temporary intent and random state")
	var fresh = engine(p)
	check(first.step(observation(),0.0).direction != Vector2(999,999),"diagnostic copies cannot mutate engine intent")
	var empty = engine(profile([]))
	check(empty.step(observation(),0.0).direction == Vector2.ZERO,"empty profile is safe neutral without borrowed producer state")
	var clock = engine(profile(["wander"]))
	var timed := observation()
	timed.simulation_time_seconds = 3.0
	clock.step(timed,0.0)
	timed.tick = 6
	timed.simulation_time_seconds = 3.1
	check(clock.step(timed,0.1).available,"explicit completed simulation clock advances")
	var prior: Dictionary = clock.diagnostics()
	timed.tick = 12
	timed.simulation_time_seconds = 103.1
	check(not clock.step(timed,0.1).available and clock.diagnostics() == prior,"wall-clock stall cannot masquerade as simulation progression")
	fresh = null


func _additional_modules_and_schema() -> void:
	var home = engine(profile(["return_home"]))
	var o := observation()
	o.position = Vector2(180,100)
	check(home.step(o,0.0).direction.x < 0.0,"return-home uses authored anchor")
	o.tick = 1
	o.position = Vector2(150,100)
	check(home.step(o,0.1).direction.x < 0.0,"home hysteresis retains intention")
	o.tick = 2
	o.position = Vector2(140,100)
	check(home.step(o,0.1).direction == Vector2.ZERO,"home releases at inner radius")
	var social = engine(profile(["follow_actor"]))
	o = observation()
	o.neighbors.actors = [{"id":102,"position":Vector2(150,100),"compatible":true}]
	check(social.step(o,0.0).direction.x > 0.0,"follow uses copied compatible actor position")
	o.tick = 1
	o.neighbors.actors[0].position = Vector2(110,100)
	check(social.step(o,0.1).direction.x < 0.0,"follow preserves comfortable separation")
	o.tick = 2
	o.neighbors.actors[0].position = Vector2(180.01,100)
	check(social.step(o,0.1).direction == Vector2.ZERO,"follow never acquires beyond its declared observed radius")
	o.tick = 3
	o.neighbors.actors[0].position = Vector2(100,150)
	check(social.step(o,0.1).direction == Vector2.ZERO,"ground follow diagnoses unsupported vertical direction")
	o.neighbors.actors[0].position = Vector2(110,100)
	var crowd = engine(profile(["avoid_crowding"]))
	check(crowd.step(o,0.0).direction.x < 0.0,"crowding produces functioning repulsion")
	var air = engine(profile(["maintain_altitude"]),101,FLIGHT)
	o = observation()
	o.position.y = 120.0
	check(air.step(o,0.0).direction.y < 0.0,"legitimate flyer altitude correction points upward")
	var invalid := profile(["maintain_altitude"])
	check(not Profile.validate(invalid,[],GROUND).is_empty(),"ground actor refuses incompatible vertical module")
	invalid.modules[0].enabled = false
	check(Profile.validate(invalid,[],GROUND).is_empty(),"disabled incompatible module is retained safely for authoring")
	invalid = profile(["avoid_ledge"])
	check(not Profile.validate(invalid,[],FLIGHT).is_empty(),"flyer cannot claim grounded ledge affordance")
	invalid = profile(["seek_material"])
	invalid.modules[0].params.material_id = 10
	check(not Profile.validate(invalid).is_empty(),"reserved material ID refused")
	invalid.modules[0].params.material_id = 999
	check(not Profile.validate(invalid).is_empty(),"unknown material ID refused")
	invalid = profile(["wander"])
	invalid.modules[0].type = "teleport"
	check(not Profile.validate(invalid).is_empty(),"unknown module refused")
	invalid = profile(["avoid_material"])
	invalid.modules[0].params.exit_distance = 60.0
	check(not Profile.validate(invalid).is_empty(),"avoidance hysteresis cannot exceed sensor radius")
	invalid = profile(["escape_obstruction"])
	invalid.modules[0].params.jump = true
	var no_jump: Dictionary = GROUND.duplicate(true)
	no_jump.jump = false
	check(not Profile.validate(invalid,[],no_jump).is_empty(),"unsupported jump request explicitly refused")
	invalid = profile(["escape_obstruction"])
	invalid.modules[0].params.wall_distance = 30.0
	check(not Profile.validate(invalid).is_empty(),"wall proximity cannot include the no-hit sentinel or unsensed range")
	var all_types: Dictionary = Modules.module_specs()
	check(all_types.size() == 29,"eleven predecessor and eighteen living module types")
	for type: String in all_types:
		var single := profile([type])
		check(Profile.validate(single).is_empty(),"metadata defaults validate: " + type)


func _identity_scope_and_continuity() -> void:
	var e = engine(profile(["wander"]))
	var o := observation()
	e.step(o,0.0)
	var original: Dictionary = e.diagnostics()
	for key: String in ["run_id","epoch","actor_id"]:
		var forged := observation(1)
		forged[key] = "replaced-run" if key == "run_id" else 2
		check(not e.step(forged,0.1).available and e.diagnostics() == original,"incarnation mismatch refuses without state mutation: " + key)
	o.tick = 1
	o.control_generation = 9
	check(e.step(o,0.1).available,"new pause command generation does not reset same actor's procedural memory")
	var p := profile(["avoid_ledge"])
	p.modules[0].params.duration = 0.1
	var rearm = engine(p)
	o = observation()
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 32.0
	rearm.step(o,0.0)
	o.tick = 1
	rearm.step(o,0.1)
	o.ledges.right.support_found = true
	o.ledges.right.drop_cells = 0.0
	for index: int in range(2,4):
		o.tick = index
		rearm.step(o,0.2)
	o.tick = 4
	o.ledges.right.available = false
	rearm.step(o,0.1)
	o.tick = 5
	o.ledges.right.available = true
	rearm.step(o,0.1)
	o.tick = 6
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 32.0
	check(rearm.step(o,0.1).active_override.is_empty(),"unavailable support breaks continuous safe rearm interval")
	var depth_profile := profile(["avoid_ledge"])
	depth_profile.modules[0].params.allowed_drop = 20.0
	var depth = engine(depth_profile)
	o = observation()
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 8.001
	o.ledges.right.searched_drop_cells = 8.0
	check(depth.step(o,0.0).direction == Vector2.ZERO,"empty ray shallower than authored drop tolerance is unavailable")
	o.tick = 1
	o.ledges.lookahead_cells = 24.0
	o.ledges.right.drop_cells = 32.001
	o.ledges.right.searched_drop_cells = 32.0
	check(depth.step(o,0.1).direction == Vector2.ZERO,"different lookahead cannot stand in for requested support location")
	var multi_profile := profile([])
	var near := Profile.make_module("avoid_ledge","near")
	var far := Profile.make_module("avoid_ledge","far")
	near.params.lookahead = 4.0
	far.params.lookahead = 24.0
	far.priority = 101
	multi_profile.modules = [near,far]
	var multi = engine(multi_profile)
	o = observation()
	var close_samples: Dictionary = o.ledges.duplicate(true)
	close_samples.lookahead_cells = 4.0
	close_samples.right.support_found = false
	close_samples.right.drop_cells = 32.001
	var far_samples: Dictionary = o.ledges.duplicate(true)
	far_samples.lookahead_cells = 24.0
	o.ledges = {"available":true,"modules":{"near":close_samples,"far":far_samples}}
	check(multi.step(o,0.0).active_override == "near","each ledge module uses its own exact spatial samples")
	var long_gap = engine(profile(["avoid_ledge"]))
	o = observation()
	o.ledges.right.support_found = false
	o.ledges.right.drop_cells = 32.001
	long_gap.step(o,0.0)
	o.tick = 3660
	var result: Dictionary = long_gap.step(o,61.0)
	check(result.available and result.active_override.is_empty(),"long actual-progression gap expires a finite intention without permanent neutralization")
	var still_stuck = engine(profile(["seek_material","escape_obstruction"]))
	o = observation()
	material(o,16,Vector2(140,100))
	o.obstacles.right_distance = 1.0
	still_stuck.step(o,0.0)
	o.tick = 120
	check(still_stuck.step(o,2.0).active_override.is_empty(),"observation gap does not invent two seconds of continuously measured contact")


func _benchmark() -> void:
	var p := profile(["wander","seek_material","avoid_material","avoid_ledge","avoid_boundary","escape_obstruction","return_home","rest","follow_actor","avoid_crowding"])
	var instances: Array = []
	for index: int in 8: instances.append(engine(p,101+index))
	var start: int = Time.get_ticks_usec()
	var decisions: int = 0
	for tick: int in 300:
		for index: int in instances.size():
			var o := observation(tick,101+index)
			material(o,16,Vector2(135,100))
			material(o,3,Vector2(145,100))
			instances[index].step(o,0.0 if tick == 0 else 0.1)
			decisions += 1
	var duration: int = Time.get_ticks_usec() - start
	print("AMBIENT_ENGINE_BENCHMARK ",JSON.stringify({"scope":"pure copied-value decisions; no material readback or physics","actors":8,"modules_per_actor":10,"decisions":decisions,"elapsed_usec":duration,"mean_usec":float(duration)/decisions,"renderer":"headless","determinism":"decision outputs, not Rapier trajectories"}))


func run() -> void:
	_material_rules()
	_ledge_timer_and_pause()
	_spatial_and_obstruction()
	_state_and_seed_independence()
	_additional_modules_and_schema()
	_identity_scope_and_continuity()
	_benchmark()
	print("AMBIENT_ENGINE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"pure-data modules and arbitration"}))
	quit(1 if failures > 0 else 0)
