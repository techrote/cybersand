extends SceneTree

const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Behaviour = preload("res://scripts/ambient/ambient_engine.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")

var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var completed: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_PERCEPTION: " + label)


func view(position := Vector2(32.5, 32.5), model := "runner") -> Dictionary:
	return {"representation":"articulated-rapier", "run_id":"fixture", "epoch":7,
		"actor_id":0, "instance_id":100, "control_generation":3, "tick":12,
		"model":model, "producer":"policy", "suspended":false, "fault":"",
		"position":position, "velocity":Vector2.ZERO, "rotation":0.0, "angular_velocity":0.0,
		"grounded":true, "wall_left":30.0, "wall_right":7.0, "energy":0.8}


func publication(extent: Vector2i, points: Dictionary = {}, serial := 1, generation := 3) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.rigid_body_epoch = 7
	snapshot.render_world_generation = generation
	snapshot.backend_name = "native-phased"
	snapshot.render_snapshot_serial = serial
	snapshot.render_tick_index = serial
	snapshot.tick_index = serial
	snapshot.world_revision = serial
	snapshot.simulation_world_revision = serial
	snapshot.render_channels = 2
	snapshot.render_full_refresh = true
	snapshot.render_patch_rectangles = PackedInt32Array([0, 0, extent.x, extent.y, 0, extent.x * 2])
	snapshot.render_patch_cells.resize(extent.x * extent.y * 2)
	snapshot.render_patch_cells.fill(0)
	for point: Vector2i in points:
		var offset := (point.y * extent.x + point.x) * 2
		snapshot.render_patch_cells[offset] = int(points[point])
		snapshot.render_patch_cells[offset + 1] = 211
	return snapshot


func context(model := "runner") -> Dictionary:
	return {"capabilities":Actuator.capabilities(model), "bounds":Rect2(0, 0, 128, 128),
		"home":Vector2(32.5, 32.5), "simulation_time_seconds":0.2, "neighbors":[]}


func sense(sensor: RefCounted, actor: Dictionary, radius := 50.0) -> Dictionary:
	return sensor.observe(actor, [{"material_id":16, "radius_cells":radius},
		{"material_id":3, "radius_cells":radius}], context()).materials


func geometry_and_availability() -> void:
	var sensor := Perception.new()
	check(sensor.configure(Vector2i(128, 128), 7), "bounded sensor configuration")
	check(sensor.wants_full_refresh(), "new sensor explicitly requests baseline")
	check(not sense(sensor, view()).available, "missing snapshot is unavailable, not absent")
	var snapshot := publication(Vector2i(128, 128), {Vector2i(72, 32):16, Vector2i(84, 32):3})
	check(sensor.ingest_snapshot(snapshot, Vector2i(128, 128), 7), "native-ID baseline admitted")
	var result := sense(sensor, view())
	check(result.available and result.targets["16"].present, "Oil acquired inside 50-cell circle")
	check(is_equal_approx(float(result.targets["16"].distance), 40.0), "distance measures exact cell-center coordinate")
	check(result.targets["16"].direction == Vector2.RIGHT, "direction toward observed Oil")
	check(not result.targets["3"].present, "Water at52cells excluded from radius50")
	check(not result.targets["3"].has("distance"), "absence does not invent zero distance")
	check(result.sample_count > 0 and result.sample_count <= Perception.MAX_QUERY_SAMPLES, "bounded sample count")
	var tiny := sense(sensor, view(Vector2(34.5,34.5)), 1)
	check(not tiny.available and not tiny.targets["16"].available and tiny.sample_count == 0,
		"circle with no admitted sparse samples is unavailable, never absent")
	var mixed: Dictionary = sensor.observe(view(Vector2(34.5,34.5)),
		[{"material_id":16,"radius_cells":1},{"material_id":3,"radius_cells":50}],context()).materials
	check(mixed.available and not mixed.targets["16"].available and mixed.targets["3"].available,
		"each material radius retains independent coverage availability")
	var boundary_view := view(Vector2(34.5, 32.5))
	check(sense(sensor, boundary_view).targets["3"].present, "radius50 includes exact boundary")
	boundary_view.position.x = 34.499
	check(not sense(sensor, boundary_view).targets["3"].present, "just beyond circle is excluded")
	check(sense(sensor, view(Vector2(0.5, 0.5)), 96).sample_count < result.sample_count * 4,
		"canvas clipping keeps sampling bounded at corner")
	var diagonal := publication(Vector2i(128, 128), {Vector2i(72, 72):16}, 2)
	check(sensor.ingest_snapshot(diagonal, Vector2i(128, 128), 7), "new native full publication")
	check(not sense(sensor, view()).targets["16"].present, "square corner outside circle is excluded")
	var sparse := publication(Vector2i(128, 128), {Vector2i(73, 32):16}, 3)
	check(sensor.ingest_snapshot(sparse, Vector2i(128, 128), 7), "sparse-grid fixture installed")
	result = sense(sensor, view())
	check(not result.targets["16"].present and "unsampled" in result.nearest_semantics,
		"single off-grid cell correctly documented as unobserved")
	var moved := publication(Vector2i(128, 128), {Vector2i(12, 32):16, Vector2i(52, 32):3}, 4)
	check(sensor.ingest_snapshot(moved, Vector2i(128, 128), 7), "relocated native material publication")
	result = sense(sensor, view())
	check(result.targets["16"].direction.x < 0.0 and result.targets["3"].direction.x > 0.0,
		"Oil relocation and Water arrival change actual sensed directions")
	# A retained publication may remain current for arbitrarily many static ticks.
	moved.serial = 40
	moved.tick_index = 1000
	check(sensor.ingest_snapshot(moved, Vector2i(128, 128), 7), "unchanged material revision stays current")
	check(sense(sensor, view()).available, "static tick age is not false staleness")
	moved.simulation_world_revision = 999
	moved.serial = 41
	check(not sensor.ingest_snapshot(moved, Vector2i(128, 128), 7), "changed world with old material is stale")
	result = sense(sensor, view())
	check(not result.available and not result.targets["16"].available, "stale sensor never supplies an absence claim")
	var recovered := publication(Vector2i(128, 128), {}, 5)
	recovered.serial = 42
	recovered.tick_index = 1001
	recovered.render_tick_index = 1001
	recovered.world_revision = 1000
	recovered.simulation_world_revision = 1000
	check(sensor.ingest_snapshot(recovered, Vector2i(128, 128), 7), "fresh publication restores availability")
	var bad_epoch := publication(Vector2i(128, 128), {}, 6)
	bad_epoch.rigid_body_epoch = 8
	check(not sensor.ingest_snapshot(bad_epoch, Vector2i(128, 128), 7), "foreign physical epoch refused")
	check(not sense(sensor, view()).available, "epoch refusal disables old material authority")
	check(sensor.ingest_snapshot(recovered, Vector2i(128, 128), 7), "valid owner publication can restore retained view")
	var paused := view()
	paused.suspended = true
	check(not sensor.observe(paused, [], context()).available, "suspended actor has no ambient observation")
	var foreign := view()
	foreign.epoch = 8
	check(not sensor.observe(foreign, [], context()).available, "copied observation cannot cross physical epoch")
	evidence.geometry = sensor.diagnostics()
	completed.append("geometry")


func patches_and_identity() -> void:
	var sensor := Perception.new()
	var extent := Vector2i(128, 128)
	var full := publication(extent)
	check(sensor.ingest_snapshot(full, extent, 7), "patch-test native baseline")
	var delta := publication(extent, {}, 2)
	delta.render_full_refresh = false
	delta.render_patch_rectangles = PackedInt32Array([40, 32, 4, 2, 0, 12])
	delta.render_patch_cells = PackedByteArray([16, 23, 0, 0, 0, 0, 0, 0, 131, 0, 131, 0,
		3, 255, 0, 0, 0, 0, 0, 0])
	check(sensor.ingest_snapshot(delta, extent, 7), "clipped patch with wider native row stride")
	var result := sense(sensor, view())
	check(result.targets["16"].present and result.targets["16"].nearest == Vector2(40.5, 32.5),
		"raw material channel decoded independently of visual byte and row padding")
	var bad := publication(extent, {}, 3)
	bad.render_full_refresh = false
	bad.render_patch_rectangles = PackedInt32Array([40, 32, 4, 2, 0, 12])
	bad.render_patch_cells = PackedByteArray([3, 255])
	check(not sensor.ingest_snapshot(bad, extent, 7), "truncated patch is refused before mutation")
	check(sensor.wants_full_refresh() and not sense(sensor, view()).available,
		"missed delta invalidates coverage until complete refresh")
	check(not sensor.ingest_snapshot(delta, extent, 7), "incremental delta cannot bootstrap invalidated coverage")
	check(sensor.ingest_snapshot(publication(extent, {}, 4), extent, 7), "complete refresh repairs coverage")
	var replacement := publication(extent, {Vector2i(60, 32):3}, 5, 4)
	check(sensor.ingest_snapshot(replacement, extent, 7), "replacement World accepts fresh generation")
	check(not sense(sensor, view()).targets["16"].present and sense(sensor, view()).targets["3"].present,
		"replacement retires previous-world material")
	check(not sensor.ingest_snapshot(full, extent, 7), "older World generation cannot replace new one")
	check(not sense(sensor, view()).available, "generation mismatch is unavailable")
	check(sensor.ingest_snapshot(replacement, extent, 7), "current generation reestablishes availability")
	check(not sensor.observe(view(), [{"material_id":16,"radius_cells":97}], context()).materials.available,
		"radius above96 is not silently clamped")
	check(not sensor.observe(view(), [{"material_id":16,"radius_cells":50.5}], context()).materials.available,
		"noninteger radius refused")
	check(not sensor.observe(view(), [{"material_id":NAN,"radius_cells":50}], context()).materials.available,
		"nonfinite material ID refused")
	for unknown: int in [0,10,132,253]:
		check(not sensor.observe(view(), [{"material_id":unknown,"radius_cells":50}], context()).materials.available,
			"empty, reserved or unknown accepted-catalogue material ID refused: "+str(unknown))
	var newest := publication(extent,{},7,4)
	newest.render_snapshot_serial = replacement.render_snapshot_serial
	newest.render_tick_index = replacement.render_tick_index
	newest.world_revision = replacement.world_revision
	newest.tick_index = 40
	newest.simulation_world_revision = 40
	check(not sensor.ingest_snapshot(newest,extent,7),"new physical envelope exposes stale retained material bytes")
	check(not sensor.ingest_snapshot(replacement,extent,7) and not sense(sensor,view()).available,
		"older render callback cannot roll native tick/revision back to fresh")
	check(sensor.diagnostics().current_tick==40 and sensor.diagnostics().owner_snapshot_serial==7,
		"newest native progression metadata retained after older envelope")
	var contradictory := publication(extent,{},7,4)
	check(not sensor.ingest_snapshot(contradictory,extent,7) and not sense(sensor,view()).available,
		"same envelope identity cannot silently describe an earlier native state")
	var refresh := publication(extent,{},8,4)
	refresh.tick_index = 41
	refresh.render_tick_index = 41
	refresh.world_revision = 41
	refresh.simulation_world_revision = 41
	check(sensor.ingest_snapshot(refresh,extent,7),"matching newer full publication restores material authority")
	var requests: Array = []
	for index: int in range(9): requests.append({"material_id":index + 1,"radius_cells":50})
	check(not sensor.observe(view(), requests, context()).materials.available, "query material capacity enforced")
	var fallback := publication(extent, {}, 9, 4)
	fallback.tick_index = 42
	fallback.simulation_world_revision = 42
	fallback.backend_name = "gdscript-serial-fallback"
	check(not sensor.ingest_snapshot(fallback, extent, 7), "fallback data never advertised as native identity")
	check(not sense(sensor, view()).available, "unsupported backend is unavailable")
	completed.append("patches")


func spatial_and_actuation() -> void:
	var sensor := Perception.new()
	check(sensor.ingest_snapshot(publication(Vector2i(128, 128)), Vector2i(128, 128), 7), "spatial fixture baseline")
	var copied_context := context()
	copied_context.spatial = {"left":{"available":true,"support_found":true,"drop_cells":0.5},
		"right":{"available":true,"support_found":false,"drop_cells":64.001}}
	var neighbor := view(Vector2(45, 32))
	neighbor.instance_id = 101
	copied_context.neighbors = [neighbor]
	var environment: Dictionary = sensor.observe(view(), [], copied_context)
	check(environment.ledges.available and not environment.ledges.right.support_found,
		"copied no-support ray remains distinct from local right wall")
	check(environment.obstacles.right_distance == 7.0 and environment.bounds.rect == Rect2(0,0,128,128),
		"wall and authored boundary channels remain distinct")
	check(environment.neighbors.actors.size() == 1, "compatible copied nearby actor admitted")
	copied_context.neighbors[0].tick = 11
	check(sensor.observe(view(), [], copied_context).neighbors.actors.is_empty(), "stale neighbor position excluded")
	check(Actuator.capabilities("runner").ground and Actuator.capabilities("crawler").horizontal,
		"accepted ground families reported")
	check(Actuator.capabilities("monowheel").family == "wheeled", "articulated roll family reported")
	check(Actuator.capabilities("4ly_trainer").vertical and not Actuator.capabilities("4ly_trainer").ground,
		"assisted-flight affordance differs from grounded ledge")
	check(not Actuator.capabilities("4ly_trainer").effort_channel and Actuator.capabilities("runner").effort_channel,
		"strict flight pace command explicitly reports no separate effort action channel")
	check(not Actuator.supports("reference_barrel") and not Actuator.supports("stuntbuggy"),
		"passive and differently mapped player motors rejected explicitly")
	var adapter := Actuator.new()
	check(adapter.configure("runner"), "ground actuator configured")
	var intent := {"direction":Vector2(1, -1), "pace":0.4, "effort":0.7, "primary":true}
	var action: Dictionary = adapter.next_action(intent, view())
	check(action.move.x > 0.0 and action.move.y == 0.0 and action.primary, "ground projection with real supported jump")
	check(not Session.normalized_action(action).is_empty(), "ground output passes real command normalizer")
	var airborne := view()
	airborne.grounded = false
	check(not adapter.next_action(intent, airborne).primary, "ground jump requires actual support")
	intent.direction = Vector2.ZERO
	intent.pace = 0.0
	action = adapter.next_action(intent, view())
	check(action.move == Vector2.ZERO and action.effort == 0.0 and not action.primary, "neutral intent safe on ground")
	check(adapter.configure("4ly_trainer"), "flight actuator configured")
	intent.direction = Vector2(0.6, -0.8)
	intent.pace = 0.5
	action = adapter.next_action(intent, view(Vector2(32,32), "4ly_trainer"))
	check(action.size() == 1 and action.has("move") and action.move.y < 0.0, "flight emits only supported desired velocity")
	check(not Session.normalized_flight_action(action).is_empty(), "flight output passes strict real normalizer")
	intent.pace = NAN
	check(adapter.next_action(intent, view(Vector2(32,32), "4ly_trainer")).is_empty(), "nonfinite intent rejected")
	completed.append("actuation")


func native_source() -> void:
	check(ClassDB.class_exists("CyberNativeCellWorld"), "actual source-matched native runtime available")
	if not ClassDB.class_exists("CyberNativeCellWorld"): return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var sensor := Perception.new()
	var profile := Profile.blank("actual-native-response")
	profile.modules=[Profile.make_module("seek_material","oil"),Profile.make_module("avoid_material","water")]
	var core := Behaviour.new()
	check(core.configure(profile,{"actor_id":100,"home":Vector2(500.5,200.5),
		"capabilities":Actuator.capabilities("runner")}).ok,"actual-native decision composition configured")
	var actuator := Actuator.new()
	check(actuator.configure("runner"),"actual-native preference has a supported normalized actuator")
	var decisions: Array = []
	var extent := Vector2i(1024,1024)
	var packet: Dictionary = world.take_render_snapshot(true)
	var snapshot := publication(extent)
	from_native(snapshot, world, packet)
	check(sensor.ingest_snapshot(snapshot, extent, 7), "actual native raw material baseline accepted")
	check(world.simulation_tick(),"actual native progression before first material decision")
	world.emit_disc(540,200,3,16)
	packet = world.take_render_snapshot(false)
	snapshot = publication(extent, {}, 2)
	from_native(snapshot, world, packet)
	check(sensor.ingest_snapshot(snapshot, extent, 7), "actual native Oil edit delta accepted")
	var result := sense(sensor, view(Vector2(500.5,200.5)))
	check(result.targets["16"].present and result.targets["16"].direction.x > 0.0,
		"real native Oil identity changes perception toward the right")
	var initial: Dictionary = native_decision(sensor,core,actuator,world,profile,"Oil right")
	decisions.append(initial)
	check(initial.intent_direction.x>0.0 and initial.action_move.x>0.0 and initial.active_override.is_empty(),
		"real native Oil right produces rightward decision and legitimate actuator preference")
	check(world.simulation_tick(),"actual native progression before Oil relocation")
	world.emit_disc(540,200,8,0)
	world.emit_disc(472,200,3,16)
	packet = world.take_render_snapshot(false)
	snapshot = publication(extent, {}, 3)
	from_native(snapshot, world, packet)
	check(sensor.ingest_snapshot(snapshot, extent, 7), "real native erase and relocated fluids published")
	result = sense(sensor, view(Vector2(500.5,200.5)))
	check(result.targets["16"].present and result.targets["16"].direction.x < 0.0,
		"native Oil relocation reverses observed direction")
	var relocated: Dictionary = native_decision(sensor,core,actuator,world,profile,"Oil relocated left")
	decisions.append(relocated)
	check(relocated.intent_direction.x<0.0 and relocated.action_move.x<0.0 and relocated.active_override.is_empty(),
		"actual native erase and opposite-side paint reverse core and actuator preference")
	var serial := 4
	var prior_water_x := -1
	for water_x: int in [524,544,548,544,536,-1]:
		check(world.simulation_tick(),"actual native progression between Water condition decisions")
		if prior_water_x>=0: world.emit_disc(prior_water_x,200,8,0)
		if water_x>=0: world.emit_disc(water_x,200,3,3)
		prior_water_x=water_x
		packet=world.take_render_snapshot(false)
		snapshot=publication(extent,{},serial)
		serial+=1
		from_native(snapshot,world,packet)
		check(sensor.ingest_snapshot(snapshot,extent,7),"source-matched native Water edit publication")
		decisions.append(native_decision(sensor,core,actuator,world,profile,"Water x="+str(water_x)))
	check(decisions[2].active_override=="water" and decisions[2].intent_direction.x<0.0,
		"native Water arrival activates higher-priority retreat in actual composed decision")
	check(decisions[3].active_override=="water" and float(decisions[3].water.distance)>36.0 \
		and float(decisions[3].water.distance)<46.0,"native Water holds avoidance in real exit hysteresis band")
	check(decisions[4].active_override.is_empty() and float(decisions[4].water.distance)>46.0,
		"native Water beyond exit46 releases urgent avoidance")
	check(decisions[5].active_override.is_empty() and float(decisions[5].water.distance)>36.0,
		"native Water returning only into hysteresis band does not reacquire")
	check(decisions[6].active_override=="water" and float(decisions[6].water.distance)<=36.0,
		"native Water at inclusive entry36 reacquires avoidance")
	check(decisions[7].active_override.is_empty() and not decisions[7].water.present,
		"native Water erasure releases material override without a scripted route")
	for ignored: int in range(12): check(world.simulation_tick(), "actual native material progression")
	packet = world.take_render_snapshot(true)
	snapshot = publication(extent, {}, serial)
	from_native(snapshot, world, packet)
	check(sensor.ingest_snapshot(snapshot, extent, 7), "post-progression actual native publication accepted")
	check(sense(sensor, view(Vector2(500.5,200.5))).sample_tick == int(world.tick_index),
		"sensor timestamp equals actual native sample tick")
	var benchmarks: Array = []
	for count: int in [1,4,8]:
		var start := Time.get_ticks_usec()
		for iteration: int in range(100):
			for actor: int in range(count):
				var actor_view := view(Vector2(500.5+actor,200.5))
				actor_view.instance_id += actor
				sense(sensor,actor_view)
		benchmarks.append({"actors":count,"decisions_each":100,"elapsed_usec":Time.get_ticks_usec()-start,
			"radius_cells":50,"maximum_actor_capacity":8})
	evidence.native = {"sensor":sensor.diagnostics(), "benchmarks":benchmarks,
		"native_tick":int(world.tick_index), "native_revision":int(world.revision),
		"composed_decisions":decisions,"fixed_actor_pose":Vector2(500.5,200.5),
		"decision_scope":"actual native material and progression; fixed copied actor pose, no Rapier motion in this phase"}
	completed.append("native")


func from_native(snapshot: CyberSimulationSnapshot, world: Object, packet: Dictionary) -> void:
	snapshot.backend_name=world.get_backend_name()
	snapshot.render_channels = int(packet.channels)
	snapshot.render_full_refresh = bool(packet.full_refresh)
	snapshot.render_patch_rectangles = packet.rectangles
	snapshot.render_patch_cells = packet.cells
	snapshot.world_revision = int(world.revision)
	snapshot.simulation_world_revision = int(world.revision)
	snapshot.render_tick_index = int(world.tick_index)
	snapshot.tick_index = int(world.tick_index)


func native_decision(sensor: RefCounted, core: RefCounted, actuator: RefCounted,
		world: Object, profile: Dictionary, label: String) -> Dictionary:
	var actor := view(Vector2(500.5,200.5))
	actor.tick=int(world.tick_index)
	var copied := context()
	copied.home=actor.position
	copied.simulation_time_seconds=float(world.tick_index)/60.0
	var environment: Dictionary = sensor.observe(actor,Perception.requests(profile),copied)
	var elapsed := 0.0 if int(core.diagnostics().decisions)==0 else 1.0/60.0
	var intent: Dictionary = core.step(environment,elapsed)
	var action: Dictionary = actuator.next_action(intent,actor)
	check(bool(intent.get("available",false)) and not Session.normalized_action(action).is_empty(),
		"actual native decision admitted and normalized: "+label)
	return {"label":label,"native_tick":int(world.tick_index),"native_revision":int(world.revision),
		"owner_epoch":environment.epoch,"world_generation":environment.materials.world_generation,
		"publication_serial":environment.materials.publication_serial,"material_tick":environment.materials.sample_tick,
		"oil":environment.materials.targets.get("16",{}).duplicate(true),
		"water":environment.materials.targets.get("3",{}).duplicate(true),
		"intent_direction":intent.get("direction",Vector2.ZERO),"active_override":intent.get("active_override",""),
		"action_move":action.get("move",Vector2.ZERO)}


func run() -> void:
	geometry_and_availability()
	patches_and_identity()
	spatial_and_actuation()
	native_source()
	check(completed == ["geometry","patches","actuation","native"], "all required phases reached completion; no helper abort can pass")
	var result := {"case":"AMBIENT-001 perception and value actuation", "checks":checks, "failures":failures,
		"evidence":evidence, "renderer":DisplayServer.get_name(), "physical_trajectory_evidence":false}
	var path := OS.get_environment("CYBERSAND_AMBIENT_PERCEPTION_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"\t"))
	print("AMBIENT_PERCEPTION ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
