extends SceneTree

# Specialist B's independent audit of A's core. Compose the real value adapters
# around copied publication fixtures; no World, Rapier motion or visual claim.
const Behaviour = preload("res://scripts/ambient/ambient_engine.gd")
const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
var checks := 0
var failures: Array[String] = []
var completed: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_INDEPENDENT: " + label)


func actor(tick: int, point := Vector2(80.5,80.5)) -> Dictionary:
	return {"representation":"articulated-rapier","model":"runner","run_id":"independent-audit",
		"epoch":6,"actor_id":0,"instance_id":17,"control_generation":2,"tick":tick,
		"position":point,"velocity":Vector2.ZERO,"rotation":0.0,"angular_velocity":0.0,
		"grounded":true,"wall_left":30.0,"wall_right":30.0,"fault":"","suspended":false}


func publication(serial: int, oil_x: int, water_x: int = -1) -> CyberSimulationSnapshot:
	var value := CyberSimulationSnapshot.new()
	value.serial = serial
	value.rigid_body_epoch = 6
	value.render_world_generation = 3
	value.backend_name = "native-phased"
	value.render_snapshot_serial = serial
	value.render_tick_index = serial
	value.tick_index = serial
	value.world_revision = serial
	value.simulation_world_revision = serial
	value.render_channels = 2
	value.render_full_refresh = true
	value.render_patch_rectangles = PackedInt32Array([0,0,160,160,0,320])
	value.render_patch_cells.resize(160*160*2)
	value.render_patch_cells.fill(0)
	if oil_x>=0: value.render_patch_cells[(80*160+oil_x)*2]=16
	if water_x>=0: value.render_patch_cells[(80*160+water_x)*2]=3
	return value


func context(tick: int) -> Dictionary:
	return {"capabilities":Actuator.capabilities("runner"),"home":Vector2(80.5,80.5),
		"bounds":Rect2(0,0,160,160),"neighbors":[],"simulation_time_seconds":float(tick)*0.1}


func bind(profile: Dictionary):
	var engine := Behaviour.new()
	check(engine.configure(profile,{"actor_id":17,"home":Vector2(80.5,80.5),
		"capabilities":Actuator.capabilities("runner")}).ok,"independent admitted profile configured")
	return engine


func material_pipeline() -> void:
	var profile := Profile.blank("independent-materials")
	profile.modules = [Profile.make_module("seek_material","oil"),Profile.make_module("avoid_material","water")]
	var core = bind(profile)
	var sensor := Perception.new()
	var actuator := Actuator.new()
	check(actuator.configure("runner"),"existing ground capability adapter configured")
	var first := publication(1,112)
	check(sensor.ingest_snapshot(first,Vector2i(160,160),6),"source-bound raw-ID fixture admitted")
	var view := actor(0)
	var environment: Dictionary = sensor.observe(view,Perception.requests(profile),context(0))
	var intent: Dictionary = core.step(environment,0.0)
	check(intent.direction.x>0.0 and intent.active_override.is_empty(),"native-ID Oil preference propagates through reusable core")
	check(actuator.next_action(intent,view).move.x>0.0,"selected intent becomes legitimate horizontal action")
	var conflict := publication(2,112,100)
	check(sensor.ingest_snapshot(conflict,Vector2i(160,160),6),"independent conflicting raw-ID publication admitted")
	view=actor(1)
	intent=core.step(sensor.observe(view,Perception.requests(profile),context(1)),0.1)
	check(intent.active_override=="water" and intent.direction.x<0.0,
		"higher-priority avoidance wins in composed sensor/core/actuator pipeline")
	check(actuator.next_action(intent,view).move.x<0.0,"Water decision actually reverses actuator preference")
	var stale := publication(3,112,100)
	stale.render_snapshot_serial=conflict.render_snapshot_serial
	stale.render_tick_index=conflict.render_tick_index
	stale.world_revision=conflict.world_revision
	stale.tick_index=50
	stale.simulation_world_revision=50
	check(not sensor.ingest_snapshot(stale,Vector2i(160,160),6),"newer physical metadata declares retained bytes stale")
	view=actor(2)
	intent=core.step(sensor.observe(view,Perception.requests(profile),context(2)),0.1)
	var neutral: Dictionary = actuator.next_action(intent,view)
	check(intent.direction==Vector2.ZERO and intent.active_override.is_empty(),
		"unavailable material disables dependent modules without borrowing prior retreat")
	check(neutral.move==Vector2.ZERO and neutral.effort==0.0,
		"neutral applicable-module result yields zero ground actuation")
	var latest := publication(4,48)
	latest.tick_index=51
	latest.render_tick_index=51
	latest.world_revision=51
	latest.simulation_world_revision=51
	check(sensor.ingest_snapshot(latest,Vector2i(160,160),6),"fresh relocation restores independently admitted coverage")
	view=actor(3)
	intent=core.step(sensor.observe(view,Perception.requests(profile),context(3)),0.1)
	check(intent.direction.x<0.0 and intent.active_override.is_empty(),"fresh opposite-side Oil is reacquired as Oil preference")
	var snapshot: Dictionary = core.diagnostics()
	intent.direction=Vector2.RIGHT
	intent.candidates.clear()
	var observed_copy: Dictionary = core.diagnostics()
	observed_copy.module_state.clear()
	check(core.diagnostics()==snapshot,"mutating returned intent and inspector copies cannot change core state")
	profile.modules[0].params.material_id=3
	profile.seed=999
	view=actor(4)
	intent=core.step(sensor.observe(view,[{"material_id":16,"radius_cells":50},{"material_id":3,"radius_cells":50}],context(4)),0.1)
	check(intent.direction.x<0.0 and core.diagnostics().seed!=999,"authored mutable caller data cannot rewrite admitted profile")
	var no_rules := Profile.blank("independent-neutral")
	var neutral_core = bind(no_rules)
	var blank: Dictionary = neutral_core.step(sensor.observe(actor(0),[],context(0)),0.0)
	check(blank.direction==Vector2.ZERO and blank.pace==0.0 and blank.effort==0.0,
		"empty admitted profile is explicitly neutral")
	completed.append("material_pipeline")


func module_stream_isolation() -> void:
	var profile := Profile.blank("independent-streams")
	profile.seed=90210
	var first := Profile.make_module("wander","amber")
	var second := Profile.make_module("wander","blue")
	first.params.turn_seconds=0.3
	second.params.turn_seconds=0.5
	profile.modules=[first,second]
	var changed_order: Dictionary = profile.duplicate(true)
	changed_order.modules.reverse()
	var original = bind(profile)
	var reordered = bind(changed_order)
	var sensor := Perception.new()
	check(sensor.configure(Vector2i(160,160),6),"stream-isolation pose adapter configured without material allocation")
	for tick: int in range(80):
		var environment: Dictionary = sensor.observe(actor(tick),[],context(tick))
		var result: Dictionary = original.step(environment,0.0 if tick==0 else 0.1)
		reordered.step(environment,0.0 if tick==0 else 0.1)
		var states_a: Dictionary = original.diagnostics().module_state
		var states_b: Dictionary = reordered.diagnostics().module_state
		for module_id: String in ["amber","blue"]:
			check(states_a[module_id]==states_b[module_id],"per-module state is independent of evaluation order: "+module_id)
		if tick%5==0:
			var before: Dictionary = original.diagnostics()
			for ignored: int in range(5): original.diagnostics()
			check(original.step(environment,0.0)==result and original.diagnostics()==before,
				"repeated UI inspection and duplicate tick draw no random values")
	completed.append("module_stream_isolation")


func obstruction_source_semantics() -> void:
	var profile := Profile.blank("independent-obstruction")
	var seek := Profile.make_module("seek_material","oil")
	var escape := Profile.make_module("escape_obstruction","escape")
	escape.params.stall_seconds=0.1
	escape.params.wall_distance=29.0
	escape.params.jump=true
	profile.modules=[seek,escape]
	var core = bind(profile)
	var sensor := Perception.new()
	check(sensor.ingest_snapshot(publication(1,112),Vector2i(160,160),6),"wall contract fixture admitted")
	for tick: int in range(12):
		var output: Dictionary = core.step(sensor.observe(actor(tick),Perception.requests(profile),context(tick)),
			0.0 if tick==0 else 0.1)
		check(output.active_override.is_empty(),"actual 30-cell no-hit wall sentinel cannot manufacture contact")
	var view := actor(12)
	view.wall_right=2.0
	var intent: Dictionary = core.step(sensor.observe(view,Perception.requests(profile),context(12)),0.1)
	check(intent.active_override=="escape" and intent.direction.x<0.0 and intent.primary,
		"actual copied wall plus previous failed progress activates bounded supported recovery")
	var adapter := Actuator.new()
	adapter.configure("runner")
	check(adapter.next_action(intent,view).primary,"grounded compatible recovery pulse reaches legitimate primary action")
	view.grounded=false
	check(not adapter.next_action(intent,view).primary,"lost support prevents a fabricated grounded jump")
	completed.append("obstruction_source_semantics")


func run() -> void:
	material_pipeline()
	module_stream_isolation()
	obstruction_source_semantics()
	check(completed==["material_pipeline","module_stream_isolation","obstruction_source_semantics"],
		"all independent audit phases completed without script abort")
	print("AMBIENT_INDEPENDENT ",JSON.stringify({"checks":checks,"failures":failures,
		"scope":"independent pure-data source-adapter composition; no physical trajectory claim"}))
	quit(0 if failures.is_empty() else 1)
