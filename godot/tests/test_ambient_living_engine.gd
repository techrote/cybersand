extends SceneTree

# Reconstructed after executor loss. Pure copied-value regressions only:
# no native World, body step or Windows execution is claimed by this suite.
const AmbientEngine = preload("res://scripts/ambient/ambient_engine.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
const Memory = preload("res://scripts/ambient/ambient_memory.gd")
const GROUND := {"supported":true,"horizontal":true,"vertical":false,"ground":true,"jump":true,"family":"ground"}
const FLIGHT := {"supported":true,"horizontal":true,"vertical":true,"ground":false,"jump":false,"family":"flight"}
const NEW_TYPES := ["investigate_material","explore_unfamiliar","revisit_interest","patrol_route",
	"prefer_region","avoid_region","search_last_seen","exploration_destination","withdraw_obstruction",
	"rest_resource","seek_home_drive","observe_actor","regroup","align_peers","disperse",
	"follow_material_boundary","steer_obstacles","avoid_peer"]
var checks: int = 0
var failures: int = 0
var failure_labels: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		failure_labels.append(label)
		push_error("AMBIENT_LIVING_ENGINE: " + label)


func profile(types: Array) -> Dictionary:
	var result: Dictionary = Profile.blank("living_test")
	result.seed = 1701
	result.personality.enabled = false
	result.drives_enabled = false
	for type: String in types: result.modules.append(Profile.make_module(type))
	return result


func engine(p: Dictionary, capabilities: Dictionary = GROUND, actor: int = 101):
	var result = AmbientEngine.new()
	check(bool(result.configure(p,{"actor_id":actor,"home":Vector2(100,100),"capabilities":capabilities}).ok),
		"valid reconstructed living profile configuration")
	return result


func observation() -> Dictionary:
	return {"version":"ambient-observation/v1","available":true,"run_id":"living-fixture",
		"epoch":1,"actor_id":0,"instance_id":101,"control_generation":1,"world_generation":7,
		"tick":0,"simulation_time_seconds":0.0,"suspended":false,
		"position":Vector2(100,100),"velocity":Vector2.ZERO,
		"grounded":{"available":true,"value":true},"resources":{"available":false},
		"materials":{"available":true,"targets":{}},
		"ledges":{"available":true,"lookahead_cells":12.0,
			"left":{"available":true,"support_found":true,"drop_cells":0.0,"searched_drop_cells":32.0},
			"right":{"available":true,"support_found":true,"drop_cells":0.0,"searched_drop_cells":32.0}},
		"obstacles":{"available":true,"left_distance":32.0,"right_distance":32.0,"maximum_distance_cells":32.0,"blocked":false},
		"navigation":{"available":true,"directions":[ray(Vector2.RIGHT,32.0,false),ray(Vector2.LEFT,32.0,false)]},
		"neighbors":{"available":true,"actors":[]},"bounds":{"available":true,"rect":Rect2(0,0,512,256)}}


func advance(e, o: Dictionary, delta: float = 0.1) -> Dictionary:
	o.tick += 6
	o.simulation_time_seconds += delta
	return e.step(o,delta)


func material(o: Dictionary, id: int, point: Vector2, available: bool = true, present: bool = true) -> void:
	o.materials.targets[str(id)] = {"available":available,"present":present,"nearest":point,
		"distance":(o.position as Vector2).distance_to(point),"radius_cells":96.0,
		"revision":3,"sample_tick":o.tick,"count":1 if present else 0}


func peer(id: int, point: Vector2, affinity: float = 0.0, velocity: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"id":id,"position":point,"velocity":velocity,"compatible":true,"affinity":affinity,"tags":[]}


func ray(direction: Vector2, clearance: float, hit: bool) -> Dictionary:
	return {"available":true,"direction":direction,"clearance_cells":clearance,
		"maximum_distance_cells":32.0,"hit":hit,"boundary":false}


func candidate(result: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in result.get("candidates",[]):
		if str(entry.id) == id: return entry
	return {}


func _schema() -> void:
	check(Profile.module_types().size() == 29,"eleven predecessor and eighteen distinct new modules")
	var presets: Array = Profile.presets()
	check(presets.size() == 16,"sixteen editable profiles")
	var old_count: int = 0
	for p: Dictionary in presets:
		check(Profile.validate(p).is_empty(),"preset schema " + str(p.id))
		var before: Dictionary = p.duplicate(true)
		var upgraded: Dictionary = Profile.upgrade(p)
		check(not upgraded.is_empty() and int(upgraded.version) == 2,"explicit upgrade " + str(p.id))
		check(p == before,"upgrade leaves original profile unchanged " + str(p.id))
		check(Profile.upgrade(upgraded) == upgraded,"upgrade is idempotent " + str(p.id))
		if int(p.version) == 1: old_count += 1
	check(old_count == 6,"all six original version-1 inhabitants remain version1")
	for type: String in NEW_TYPES:
		var p: Dictionary = profile([type])
		check(Profile.validate(p).is_empty(),"new reusable module schema " + type)
		check(not str(Profile.module_spec(type).get("description","")).is_empty(),"module has semantic description " + type)
	var p: Dictionary = profile(["patrol_route"])
	p.modules[0].params.points = [[0,0]]
	check(not Profile.validate(p).is_empty(),"one-point patrol refused")
	p = profile(["investigate_material"])
	p.modules[0].params.material_id = 10
	check(not Profile.validate(p).is_empty(),"reserved native material ID refused")
	p = profile([])
	p.memory.capacity = 129
	check(not Profile.validate(p).is_empty(),"memory maximum capacity enforced")
	p = profile([])
	p.personality.curiosity = NAN
	check(not Profile.validate(p).is_empty(),"nonfinite trait refused")
	p = profile([])
	p["unknown"] = true
	check(not Profile.validate(p).is_empty(),"unknown authored field refused")
	p = profile(["prefer_region"])
	p.modules[0].params.region_id = "missing"
	check(not Profile.validate(p).is_empty(),"unresolved authored region refused")
	p = Profile.preset("oil_moth")
	p.modules = [Profile.make_module("explore_unfamiliar")]
	check(not Profile.validate(p).is_empty(),"version1 cannot silently acquire version2 semantics")


func _world_memory() -> void:
	var p: Dictionary = profile(["explore_unfamiliar"])
	p.memory.capacity = 8
	p.memory.interest_capacity = 2
	p.memory.lifetime_seconds = 5.0
	var e = engine(p)
	var o: Dictionary = observation()
	e.step(o,0.0)
	for index: int in range(20):
		o.position = Vector2(40 + index*24,100)
		material(o,16,o.position + Vector2(30,0))
		advance(e,o)
		var memory: Dictionary = e.diagnostics().memory
		check(memory.visited.size() <= 8 and memory.interests.size() <= 2,"bounded deterministic spatial retention")
	check(int(e.diagnostics().memory.evictions) > 0,"bounded memory evicts older records")
	o.materials.targets.clear()
	o.position = Vector2(100,100)
	advance(e,o,5.1)
	check(e.diagnostics().memory.interests.is_empty() and e.diagnostics().memory.visited.size() == 1,
		"expired observations forgotten while current place is readmitted")
	var before: Dictionary = e.diagnostics()
	var bad: Dictionary
	for kind: String in ["pose","velocity","clock","identity","unavailable","suspended","version","tick"]:
		bad = o.duplicate(true)
		bad.world_generation = 8
		bad.tick = 0
		bad.simulation_time_seconds = 0.0
		match kind:
			"pose": bad.position = Vector2(NAN,0)
			"velocity": bad.velocity = Vector2(INF,0)
			"clock": bad.simulation_time_seconds = -1.0
			"identity": bad.epoch = 2
			"unavailable": bad.available = false
			"suspended": bad.suspended = true
			"version": bad.version = "wrong"
			"tick": bad.tick = -1
		check(not bool(e.step(bad,0.0).available),"malformed newer World sample refused: " + kind)
		check(e.diagnostics() == before,"refused newer World sample preserves memory, RNG and clock: " + kind)
	bad = o.duplicate(true)
	bad.world_generation = 8
	check(not bool(e.step(bad,-0.1).available) and e.diagnostics() == before,"negative delta cannot commit a World reset")
	var new_world: Dictionary = observation()
	new_world.world_generation = 8
	e.step(new_world,0.0)
	check(int(e.diagnostics().world_generation) == 8 and e.diagnostics().memory.visited.size() == 1,
		"valid newer World admits a fresh timeline and empty inherited memory")
	var fresh: Dictionary = e.diagnostics()
	bad = new_world.duplicate(true)
	bad.world_generation = 7
	check(not bool(e.step(bad,0.0).available) and e.diagnostics() == fresh,"older World never restores old knowledge")
	new_world.world_generation = -1
	advance(e,new_world)
	check(not bool(e.diagnostics().memory.available) and e.diagnostics().intent.direction == Vector2.ZERO,
		"unknown World identity suspends visited-memory use")
	new_world.world_generation = 8
	advance(e,new_world)
	before = e.diagnostics()
	e.step(new_world,0.0)
	check(e.diagnostics() == before,"duplicate observation inspection consumes no RNG or time")
	p.memory.capacity = 999
	check(not bool(e.configure(p,{"actor_id":101,"home":Vector2(100,100),"capabilities":GROUND}).ok),
		"invalid reconfiguration refused")
	check(e.diagnostics() == before,"invalid reconfiguration preserves producer state")
	p = profile(["explore_unfamiliar"])
	p.memory.enabled = false
	e = engine(p)
	o = observation()
	var result: Dictionary = e.step(o,0.0)
	check(result.selected_goal == "explore_unfamiliar" and e.diagnostics().memory.visited.is_empty(),
		"memory ablation retains finite seeded fallback without spatial records")


func _geometry_and_obstruction() -> void:
	for kind: String in ["reserved","unknown","distance","radius","stale"]:
		var e = engine(profile([]))
		var o: Dictionary = observation()
		material(o,16,Vector2(140,100))
		match kind:
			"reserved":
				o.materials.targets["10"] = o.materials.targets["16"]
				o.materials.targets.erase("16")
			"unknown":
				o.materials.targets["not_a_material"] = o.materials.targets["16"]
				o.materials.targets.erase("16")
			"distance": o.materials.targets["16"].distance = 1.0
			"radius": o.materials.targets["16"].radius_cells = 999.0
			"stale": o.materials.targets["16"].available = false
		e.step(o,0.0)
		check(e.diagnostics().memory.interests.is_empty(),"memory refuses malformed material evidence: " + kind)
	var e = engine(profile(["steer_obstacles"]))
	var o: Dictionary = observation()
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2(1,1).normalized(),32.0,false)]
	check(e.step(o,0.0).direction == Vector2.ZERO,"diagonal free ray is not horizontal ground clearance")
	e = engine(profile(["steer_obstacles"]),FLIGHT)
	check(e.step(o,0.0).direction.y > 0.5,"flying actor may use an observed diagonal alternative")
	var memory = Memory.new()
	memory.configure(Profile.memory_defaults())
	o = observation()
	o.obstacles.available = false
	o.navigation.directions = [ray(Vector2(1,1).normalized(),1.0,true)]
	var intent := {"direction":Vector2.RIGHT,"pace":0.5}
	for index: int in range(20): memory.advance(o,float(index)*0.1,0.1,intent)
	check(int(memory.snapshot().failure_events) == 0,"diagonal contact cannot become a horizontal failed approach")
	o.navigation.directions = [ray(Vector2.RIGHT,32.0,false)]
	for index: int in range(20,40): memory.advance(o,float(index)*0.1,0.1,intent)
	check(int(memory.snapshot().failure_events) == 0,"stationary pose plus no-hit sentinel does not manufacture obstruction")
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true)]
	for index: int in range(40,55): memory.advance(o,float(index)*0.1,0.1,intent)
	check(int(memory.snapshot().failure_events) > 0,"aligned observed contact and repeated lack of progress produce bounded failure memory")


func _obstacle_commitment() -> void:
	var module: Dictionary = Profile.make_module("steer_obstacles")
	var o: Dictionary = observation()
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2.LEFT,32.0,false)]
	var c: Dictionary = {"capabilities":GROUND.duplicate(true),"personality":Profile.personality_defaults(),
		"memory":{"available":false},"last_direction":Vector2.RIGHT}
	var s: Dictionary = {"rng":1}
	var first: Dictionary = Modules.evaluate(module,o,s,0.0,0.0,c)
	check(bool(first.active) and first.direction == Vector2.LEFT,"obstruction begins observed clear alternative")
	var original_deadline: float = float(s.until)
	c.last_direction = Vector2.LEFT
	for index: int in range(1,15):
		var now: float = float(index)*0.1
		var held: Dictionary = Modules.evaluate(module,o,s,now,0.1,c)
		check(bool(held.active) and held.direction == Vector2.LEFT,
			"clear escape heading remains active after its own steering response")
		check(float(s.until) == original_deadline and is_equal_approx(float(held.remaining_seconds),original_deadline-now),
			"successful clear escape never renews its finite deadline")
	check(not bool(Modules.evaluate(module,o,s,1.5,0.1,c).active) and not s.has("until"),
		"clear-heading latch expires at its authored simulation deadline")
	check(not bool(Modules.evaluate(module,o,s,1.6,0.1,c).active),"clear heading cannot rearm an expired latch")
	for invalidation: String in ["unavailable","missing","clipped","malformed","neutral"]:
		c.last_direction = Vector2.RIGHT
		s = {"rng":1}
		o = observation()
		o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2.LEFT,32.0,false)]
		Modules.evaluate(module,o,s,0.0,0.0,c)
		c.last_direction = Vector2.LEFT
		match invalidation:
			"unavailable": o.navigation.available = false
			"missing": o.navigation.directions = [ray(Vector2.RIGHT,1.0,true)]
			"clipped": o.navigation.directions[1].boundary = true
			"malformed": o.navigation.directions[1].clearance_cells = NAN
			"neutral": c.last_direction = Vector2.ZERO
		check(not bool(Modules.evaluate(module,o,s,0.1,0.1,c).active) and not s.has("until"),
			"retained alternative released immediately: " + invalidation)
		o.navigation.available = true
		o.navigation.directions = [ray(Vector2.RIGHT,32.0,false),ray(Vector2.LEFT,32.0,false)]
		c.last_direction = Vector2.LEFT
		check(not bool(Modules.evaluate(module,o,s,0.2,0.1,c).active),
			"released alternative cannot resume from old deadline: " + invalidation)
	c.last_direction = Vector2.RIGHT
	s = {"rng":1}
	o = observation()
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2.LEFT,32.0,false)]
	Modules.evaluate(module,o,s,0.0,0.0,c)
	c.last_direction = Vector2.LEFT
	o.navigation.directions = [ray(Vector2.RIGHT,32.0,false),ray(Vector2.LEFT,1.0,true)]
	var changed: Dictionary = Modules.evaluate(module,o,s,0.1,0.1,c)
	check(bool(changed.active) and changed.direction == Vector2.RIGHT,
		"new blockage releases old heading and permits a newly observed clear alternative")
	check(is_equal_approx(float(s.until),1.6),"new observed blockage starts a separate bounded maneuver")
	c.capabilities = FLIGHT.duplicate(true)
	c.last_direction = Vector2.RIGHT
	s = {"rng":1}
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2.UP,32.0,false)]
	check(Modules.evaluate(module,o,s,0.0,0.0,c).direction == Vector2.UP,"flyer selects actual clear vertical alternative")
	c.last_direction = Vector2.UP
	check(Modules.evaluate(module,o,s,0.1,0.1,c).direction == Vector2.UP,"flyer retains confirmed vertical alternative")
	var e = engine(profile(["steer_obstacles"]))
	o = observation()
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2.LEFT,32.0,false)]
	check(e.step(o,0.0).direction == Vector2.LEFT,"engine admits observed finite escape heading")
	check(advance(e,o).direction == Vector2.LEFT,"engine retains escape across actual decision progression")
	o.world_generation = 8
	o.tick = 0
	o.simulation_time_seconds = 0.0
	o.navigation.directions = [ray(Vector2.RIGHT,32.0,false),ray(Vector2.LEFT,32.0,false)]
	check(e.step(o,0.0).direction == Vector2.ZERO and not e.diagnostics().module_state.steer_obstacles.has("until"),
		"new World cannot inherit the prior obstacle maneuver")
	e = engine(profile(["steer_obstacles","avoid_material"]))
	o = observation()
	o.navigation.directions = [ray(Vector2.RIGHT,1.0,true),ray(Vector2.LEFT,32.0,false)]
	e.step(o,0.0)
	material(o,3,Vector2(90,100))
	check(advance(e,o).active_override == "avoid_material","urgent material reflex still interrupts retained steering")


func _expiry_and_sequences() -> void:
	var p: Dictionary = profile(["revisit_interest"])
	p.modules[0].params.minimum_age = 0.0
	p.memory.lifetime_seconds = 5.0
	var e = engine(p)
	var o: Dictionary = observation()
	material(o,16,Vector2(145,100))
	check(e.step(o,0.0).selected_goal == "revisit_interest","retained historical material destination may be revisited")
	o.materials.targets.clear()
	advance(e,o,5.1)
	check(not bool(candidate(e.diagnostics().intent,"revisit_interest").get("active",false)),
		"expired memory entry releases its latched historical revisit")
	p = profile(["search_last_seen"])
	p.memory.lifetime_seconds = 5.0
	e = engine(p)
	o = observation()
	material(o,16,Vector2(140,100))
	e.step(o,0.0)
	o.materials.available = false
	advance(e,o,6.0)
	o.materials.available = true
	o.materials.targets["16"].present = false
	check(advance(e,o).selected_goal.is_empty(),"unavailable gap cannot resurrect an expired last-seen search")
	for type: String in ["investigate_material","patrol_route","observe_actor","seek_home_drive"]:
		p = profile([type,"avoid_material"])
		match type:
			"investigate_material": p.modules[0].params.inspect_seconds = 0.5
			"patrol_route":
				p.modules[0].params.points = [[0,0],[50,0]]
				p.modules[0].params.dwell_seconds = 0.5
			"observe_actor": p.modules[0].params.watch_seconds = 0.5
			"seek_home_drive":
				p.modules[0].params.trigger = 0.9
				p.modules[0].params.rest_seconds = 0.5
		e = engine(p)
		o = observation()
		material(o,16,Vector2(108,100))
		material(o,3,Vector2(120,100))
		o.neighbors.actors = [peer(202,Vector2(124,100),1.0)]
		var first: Dictionary = e.step(o,0.0)
		check(first.active_override == "avoid_material","urgent reflex interrupts " + type)
		for index: int in range(4): advance(e,o)
		check(is_zero_approx(float(e.diagnostics().module_state[type].get("phase_selected_seconds",0.0))),
			"unselected phase accrues no dwell: " + type)
		o.materials.targets["3"].present = false
		var selected: Dictionary = advance(e,o)
		check(selected.selected_goal == type and selected.direction == Vector2.ZERO,
			"already-arrived sequence can request its first selected dwell: " + type)
		for index: int in range(7): advance(e,o)
		var state: Dictionary = e.diagnostics().module_state[type]
		check(int(state.get("index",0)) == 1 if type == "patrol_route" else str(state.phase) == "cooldown",
			"selected simulation intervals complete the finite phase: " + type)
	p = profile(["patrol_route","avoid_material"])
	p.modules[0].params.points = [[0,0],[50,0]]
	p.modules[0].params.dwell_seconds = 0.2
	e = engine(p)
	o = observation()
	material(o,3,Vector2(120,100))
	e.step(o,0.0)
	var expired: bool = false
	var false_completion: bool = false
	for index: int in range(15):
		var proposal: Dictionary = candidate(advance(e,o),"patrol_route")
		expired = expired or "interruption deadline" in str(proposal.reason)
		false_completion = false_completion or "selected dwell complete" in str(proposal.reason)
	check(expired and not false_completion,"suppressed phase has a finite interruption deadline without a completion claim")


func home_recharge_profile(radius: float = 20.0) -> Dictionary:
	var p: Dictionary = profile(["seek_home_drive"])
	p.drives_enabled = true
	p.modules[0].id = "authored_home"
	p.modules[0].params.trigger = 1.0
	p.modules[0].params.arrival_radius = radius
	p.modules[0].params.rest_seconds = 8.0
	return p


func _home_recharge() -> void:
	# The ordinary sustained Foundry observation settled 16.49 cells from a home
	# with arrival_radius20, selected home_rest, and nevertheless depleted drive.
	# Reproduce that composition with copied geometry, not a new physical episode.
	var p: Dictionary = home_recharge_profile()
	var e = engine(p,FLIGHT)
	var o: Dictionary = observation()
	o.position = Vector2(118,100)
	var result: Dictionary = e.step(o,0.0)
	check(result.selected_goal == "authored_home" and result.goal_phase == "home_rest",
		"configured twenty-cell home accepts an actual eighteen-cell arrival")
	var before: float = e.diagnostics().drives.exploration
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) > before,
		"selected home rest recharges inside its authored radius beyond ordinary sixteen-cell rest")
	before = e.diagnostics().drives.exploration
	o.position = Vector2(120,100)
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) > before,"selected home recharge includes its exact authored boundary")
	before = e.diagnostics().drives.exploration
	o.position = Vector2(120.01,100)
	result = advance(e,o)
	check(result.goal_phase == "home_rest" and float(e.diagnostics().drives.exploration) < before,
		"physical drift outside the selected radius cannot recharge even while finite rest remains selected")
	var paused: Dictionary = e.diagnostics().drives.duplicate(true)
	e.step(o,0.0)
	check(e.diagnostics().drives == paused,"unchanged inspection cannot replenish drive")

	# An unrelated candidate cannot widen the selected instance's smaller home.
	p = home_recharge_profile(14.0)
	var other: Dictionary = Profile.make_module("seek_home_drive")
	other.id = "unselected_wide_home"
	other.weight = 0.01
	other.params.trigger = 1.0
	other.params.arrival_radius = 60.0
	p.modules.append(other)
	e = engine(p,FLIGHT)
	o = observation()
	o.position = Vector2(112,100)
	result = e.step(o,0.0)
	check(result.selected_goal == "authored_home" and result.goal_phase == "home_rest",
		"multiple home instances retain the actual winning authored identity")
	before = e.diagnostics().drives.exploration
	o.position = Vector2(115,100)
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) < before,
		"selected fourteen-cell radius is not widened by ordinary sixteen-cell rest or a sixty-cell candidate")
	for disabled: bool in [true,false]:
		p = home_recharge_profile(60.0)
		p.modules[0].enabled = not disabled
		p.modules[0].weight = 1.0 if disabled else 0.0
		e = engine(p,FLIGHT)
		o = observation()
		o.position = Vector2(118,100)
		result = e.step(o,0.0)
		before = e.diagnostics().drives.exploration
		advance(e,o)
		check(result.selected_goal.is_empty() and float(e.diagnostics().drives.exploration) < before,
			"disabled or zero-weight home candidates cannot lend a recharge radius")

	# Resource rest is an actual neutral override, not a homeward goal. It must
	# not inherit the wider home radius after interrupting a selected home rest.
	p = home_recharge_profile()
	other = Profile.make_module("rest_resource")
	other.id = "actual_energy_rest"
	other.priority = 120
	p.modules.append(other)
	e = engine(p,FLIGHT)
	o = observation()
	o.position = Vector2(118,100)
	e.step(o,0.0)
	o.resources = {"available":true,"energy":0.1}
	result = advance(e,o)
	check(result.active_override == "actual_energy_rest" and result.pace == 0.0,
		"actual-resource neutral override can interrupt selected home rest")
	before = e.diagnostics().drives.exploration
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) < before and float(o.resources.energy) == 0.1,
		"interrupted home rest cannot recharge an unrelated neutral override or invent actual energy")

	p = profile([])
	p.drives_enabled = true
	e = engine(p,FLIGHT)
	o = observation()
	o.position = Vector2(116,100)
	e.step(o,0.0)
	before = e.diagnostics().drives.exploration
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) > before,"ordinary neutral behavior retains sixteen-cell home recharge")
	before = e.diagnostics().drives.exploration
	o.position = Vector2(116.01,100)
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) < before,"ordinary neutral behavior has no enlarged recharge radius")

	p = home_recharge_profile()
	var ground = engine(p,GROUND)
	var flyer = engine(p,FLIGHT)
	o = observation()
	o.position = Vector2(118,200)
	var grounded_home: Dictionary = ground.step(o,0.0)
	var airborne_home: Dictionary = flyer.step(o,0.0)
	check(grounded_home.goal_phase == "home_rest" and airborne_home.goal_phase == "approach",
		"ground home geometry remains horizontal while flight requires two-axis arrival")
	var copy: Dictionary = o.duplicate(true)
	advance(ground,o)
	advance(flyer,copy)
	check(float(ground.diagnostics().drives.exploration) > 0.85 and float(flyer.diagnostics().drives.exploration) < 0.85,
		"recharge uses the same capability-appropriate geometry as home arrival")

	p.drives_enabled = false
	e = engine(p,FLIGHT)
	o = observation()
	o.position = Vector2(118,100)
	e.step(o,0.0)
	before = e.diagnostics().drives.exploration
	advance(e,o)
	check(float(e.diagnostics().drives.exploration) == before,"disabled drives remain fixed even during selected home rest")

	p = home_recharge_profile()
	e = engine(p,FLIGHT)
	o = observation()
	o.position = Vector2(118,100)
	e.step(o,0.0)
	for index: int in range(30): advance(e,o)
	check(float(e.diagnostics().drives.exploration) == 1.0,"authored home recharge remains bounded to one")
	o.world_generation += 1
	o.tick = 0
	o.simulation_time_seconds = 0.0
	e.step(o,0.0)
	check(float(e.diagnostics().drives.exploration) == 0.85,"World replacement resets recharge history before a new home intention")
	p.modules[0].params.arrival_radius = 14.0
	check(bool(e.configure(p,{"actor_id":101,"home":Vector2(100,100),"capabilities":FLIGHT}).ok),
		"reconfigured narrower home is admitted")
	result = e.step(o,0.0)
	check(result.goal_phase == "approach" and float(e.diagnostics().drives.exploration) == 0.85,
		"profile handoff cannot retain the prior selected home's wider radius or accumulated drive")


func _traits_and_modules() -> void:
	var low: Dictionary = profile(["investigate_material","exploration_destination"])
	low.personality.enabled = true
	low.personality.curiosity = 0.0
	var high: Dictionary = low.duplicate(true)
	high.personality.curiosity = 1.0
	var o: Dictionary = observation()
	material(o,16,Vector2(140,100))
	var cautious = engine(low)
	var curious = engine(high)
	check(cautious.step(o,0.0).selected_goal == "exploration_destination"
		and curious.step(o,0.0).selected_goal == "investigate_material",
		"matched curiosity changes the actually selected temporary intention")
	var p: Dictionary = profile(["exploration_destination"])
	p.personality.enabled = true
	p.personality.activity = 0.0
	var quiet = engine(p)
	p.personality.activity = 1.0
	var active = engine(p)
	check(active.step(o,0.0).pace > quiet.step(o,0.0).pace,"activity changes ordinary goal pace")
	p = profile(["avoid_material"])
	p.personality.enabled = true
	p.personality.activity = 0.0
	quiet = engine(p)
	p.personality.activity = 1.0
	active = engine(p)
	material(o,3,Vector2(120,100))
	check(is_equal_approx(active.step(o,0.0).pace,quiet.step(o,0.0).pace),"urgent reflex pace stays explicitly authored")
	p = profile([])
	p.drives_enabled = true
	var e = engine(p)
	o = observation()
	e.step(o,0.0)
	var initial: float = e.diagnostics().drives.exploration
	for index: int in range(100):
		o.position = Vector2(200 + index % 2,100)
		advance(e,o)
	check(float(e.diagnostics().drives.exploration) < initial,"accumulated exploration drive dissipates during actual copied movement")
	for index: int in range(30):
		o.position = Vector2(100,100)
		advance(e,o)
	check(float(e.diagnostics().drives.exploration) >= 0.0 and float(e.diagnostics().drives.exploration) <= 1.0,
		"home rest restores finite bounded drive")
	e = engine(profile(["rest_resource"]))
	o = observation()
	check(e.step(o,0.0).active_override.is_empty(),"missing actual resource is not invented fatigue")
	o.resources = {"available":true,"energy":0.1}
	check(advance(e,o).active_override == "rest_resource","actual low normalized rig energy requests finite neutral rest")
	o.resources.energy = 0.9
	check(advance(e,o).active_override.is_empty(),"actual resource recovery releases rest")
	p = profile(["prefer_region"])
	p.regions = [{"id":"yard","name":"Yard","kind":"interest","x":180.0,"y":80.0,"width":50.0,"height":40.0}]
	p.modules[0].params.region_id = "yard"
	e = engine(p)
	o = observation()
	check(e.step(o,0.0).direction.x > 0.9,"authored preferred region creates an approach")
	p = profile(["avoid_region"])
	p.regions = [{"id":"unsafe","name":"Unsafe","kind":"avoid","x":90.0,"y":90.0,"width":30.0,"height":30.0}]
	e = engine(p)
	check(e.step(o,0.0).active_override == "avoid_region","authored avoidance region is a genuine reflex")
	p = profile(["seek_home_drive"])
	p.regions = [{"id":"home","name":"Home","kind":"home","x":180.0,"y":80.0,"width":40.0,"height":40.0}]
	p.modules[0].params.trigger = 0.9
	e = engine(p)
	check(e.step(o,0.0).direction.x > 0.9 and e.diagnostics().effective_home == Vector2(200,100),
		"authored home region changes the effective homeward target")
	var exposed: Dictionary = e.diagnostics()
	exposed.authored_regions[0].x = 0.0
	check(e.diagnostics().effective_home == Vector2(200,100),"copied region inspection cannot mutate authored runtime context")
	e = engine(profile(["follow_material_boundary"]),FLIGHT)
	o = observation()
	material(o,16,Vector2(110,100))
	o.materials.targets["16"]["boundary"] = {"available":true,"normal":Vector2.LEFT,"tangent":Vector2.DOWN}
	check(e.step(o,0.0).direction.y > 0.9,"actual observed boundary tangent creates local following")
	e = engine(profile(["exploration_destination"]))
	check(e.step(observation(),0.0).selected_goal == "exploration_destination","seeded destination is independently reusable")


func _affinity() -> void:
	var p: Dictionary = profile(["follow_actor"])
	p.relations.prefer_tags = ["settler"]
	var o: Dictionary = observation()
	o.neighbors.actors = [peer(201,Vector2(130,100),0.0),peer(202,Vector2(40,100),1.0)]
	var e = engine(p)
	var result: Dictionary = e.step(o,0.0)
	check(int(candidate(result,"follow_actor").get("target_actor",-1)) == 202 and result.direction.x < -0.9,
		"v2 follows a farther preferred peer before closer neutral")
	o.neighbors.actors = [peer(201,Vector2(130,100),0.0)]
	check(int(candidate(advance(e,o),"follow_actor").get("target_actor",-1)) == 201,"neutral peer remains a fallback")
	o.neighbors.actors = [peer(203,Vector2(75,100),-1.0),peer(201,Vector2(130,100),0.0)]
	check(int(candidate(advance(e,o),"follow_actor").get("target_actor",-1)) == 201,"avoided peer is excluded")
	p.relations.peer_id = 201
	e = engine(p)
	o = observation()
	o.neighbors.actors = [peer(201,Vector2(130,100),0.0),peer(202,Vector2(40,100),1.0)]
	check(int(candidate(e.step(o,0.0),"follow_actor").get("target_actor",-1)) == 201,"explicit companion takes precedence over another preferred peer")
	o.neighbors.actors = [peer(202,Vector2(40,100),1.0)]
	check(advance(e,o).direction == Vector2.ZERO,"missing explicit companion is not silently substituted")
	p.relations.peer_id = 203
	e = engine(p)
	o.neighbors.actors = [peer(203,Vector2(75,100),-1.0),peer(202,Vector2(40,100),1.0)]
	check(e.step(o,0.0).direction == Vector2.ZERO,"avoided explicit companion still fails affinity admission")
	p = Profile.preset("social_roamer")
	p.modules = [Profile.make_module("follow_actor")]
	e = engine(p)
	o = observation()
	o.neighbors.actors = [peer(201,Vector2(130,100),0.0),peer(202,Vector2(40,100),1.0)]
	check(int(candidate(e.step(o,0.0),"follow_actor").get("target_actor",-1)) == 201,"version1 preserves nearest-compatible following")
	for type: String in ["observe_actor","regroup","align_peers"]:
		e = engine(profile([type]))
		o = observation()
		o.neighbors.actors = [peer(201,Vector2(130,100),0.0,Vector2(5,0)),peer(202,Vector2(40,100),1.0,Vector2(-5,0))]
		check(e.step(o,0.0).direction.x < -0.9,"positive affinity changes " + type)
	p = profile(["disperse"])
	p.relations.peer_id = 202
	e = engine(p)
	o = observation()
	o.neighbors.actors = [peer(201,Vector2(110,100)),peer(202,Vector2(120,100),1.0)]
	check(e.step(o,0.0).selected_goal == "disperse","named companion does not hide a surrounding congregation")
	p = profile(["avoid_peer"])
	p.relations.peer_id = 202
	e = engine(p)
	o.neighbors.actors = [peer(203,Vector2(125,100),-1.0),peer(202,Vector2(40,100),1.0)]
	check(e.step(o,0.0).active_override == "avoid_peer","named companion does not hide a different disliked peer")


func _determinism_and_copy() -> void:
	var p: Dictionary = Profile.preset("persistent_scavenger")
	p.seed = 1701
	var first = engine(p)
	var second = engine(p)
	var o: Dictionary = observation()
	for index: int in range(300):
		o.position = Vector2(100 + sin(float(index)*0.037)*30,100)
		o.velocity = Vector2(cos(float(index)*0.037)*10,0)
		o.materials.targets.clear()
		if index % 50 < 30: material(o,16,Vector2(140,100))
		if index % 70 < 10: material(o,3,Vector2(120,100))
		o.tick = index*6
		o.simulation_time_seconds = float(index)*0.1
		var delta: float = 0.0 if index == 0 else 0.1
		var a: Dictionary = first.step(o,delta)
		var b: Dictionary = second.step(o,delta)
		check(a == b,"identical seeded admitted stream produces identical decision " + str(index))
		a.direction = Vector2(999,999)
		a.candidates.clear()
		var inspection: Dictionary = first.diagnostics()
		inspection.memory.visited.clear()
		inspection.module_state.clear()
	check(first.diagnostics() == second.diagnostics(),"mutating copied diagnostics never mutates producer state")
	p = profile(["exploration_destination"])
	first = engine(p,GROUND,101)
	second = engine(p,GROUND,102)
	o = observation()
	first.step(o,0.0)
	o.instance_id = 102
	second.step(o,0.0)
	check(first.diagnostics().module_state.exploration_destination.rng != second.diagnostics().module_state.exploration_destination.rng,
		"distinct authored actor IDs have independent deterministic procedural streams")
	p.shared_seed = true
	first = engine(p,GROUND,101)
	second = engine(p,GROUND,102)
	o = observation()
	var a: Dictionary = first.step(o,0.0)
	o.instance_id = 102
	var b: Dictionary = second.step(o,0.0)
	check(a.goal_target == b.goal_target,"explicit shared seed permits matched procedural choices")


func _benchmark() -> Dictionary:
	var p: Dictionary = Profile.preset("persistent_scavenger")
	var engines: Array = []
	var observations: Array = []
	for actor: int in range(8):
		engines.append(engine(p,GROUND,101+actor))
		var o: Dictionary = observation()
		o.instance_id = 101+actor
		material(o,16,Vector2(140,100))
		observations.append(o)
	var started: int = Time.get_ticks_usec()
	for step: int in range(120):
		for actor: int in range(8):
			var o: Dictionary = observations[actor]
			o.tick = step*6
			o.simulation_time_seconds = float(step)*0.1
			engines[actor].step(o,0.0 if step == 0 else 0.1)
	var elapsed: int = Time.get_ticks_usec()-started
	return {"actors":8,"decisions":960,"modules":p.modules.size(),"profile":p.id,
		"elapsed_usec":elapsed,"mean_usec":float(elapsed)/960.0,
		"scope":"pure copied-value decisions, not native or physical progression"}


func run() -> void:
	_schema()
	_world_memory()
	_geometry_and_obstruction()
	_obstacle_commitment()
	_expiry_and_sequences()
	_home_recharge()
	_traits_and_modules()
	_affinity()
	_determinism_and_copy()
	var benchmark: Dictionary = _benchmark()
	var report := {"checks":checks,"failures":failures,"failure_labels":failure_labels,
		"engine":AmbientEngine.VERSION,"benchmark":benchmark,
		"scope":"reconstructed pure copied-value living decisions; zero physical actor episodes"}
	var path: String = OS.get_environment("CYBERSAND_AMBIENT_LIVING_ENGINE_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file == null: check(false,"report file opens")
		else: file.store_string(JSON.stringify(report,"\t"))
	print("AMBIENT_LIVING_ENGINE_RESULT ",JSON.stringify(report))
	quit(0 if failures == 0 else 1)
