extends SceneTree

# Real owner-issued terrain rays plus adversarial copied-publication contracts.
# Synthetic publication cases certify the value boundary; physical campaigns
# separately establish material/actuator interaction in fresh native Worlds.
const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
var checks := 0
var failures: Array[String] = []
var completed: Array[String] = []
var measurements: Array = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("AMBIENT2_SPATIAL: " + label)


func view(position: Vector2 = Vector2(32.5,32.5)) -> Dictionary:
	return {"representation":"articulated-rapier", "run_id":"ambient2-spatial", "epoch":7,
		"actor_id":0, "instance_id":100, "control_generation":3, "tick":12,
		"suspended":false, "fault":"", "position":position, "velocity":Vector2.ZERO,
		"grounded":true, "wall_left":30.0, "wall_right":30.0}


func context() -> Dictionary:
	return {"capabilities":Actuator.capabilities("runner"), "bounds":Rect2(0,0,256,256),
		"home":Vector2(32.5,32.5), "simulation_time_seconds":0.2, "neighbors":[],
		"perception":{"spacing_cells":4, "near_radius_cells":8, "refine_boundaries":true}}


func publication(points: Dictionary = {}, serial: int = 1, generation: int = 3) -> CyberSimulationSnapshot:
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
	snapshot.render_patch_rectangles = PackedInt32Array([0,0,256,256,0,512])
	snapshot.render_patch_cells.resize(256 * 256 * 2)
	snapshot.render_patch_cells.fill(0)
	for cell: Vector2i in points:
		snapshot.render_patch_cells[(cell.y * 256 + cell.x) * 2] = int(points[cell])
		snapshot.render_patch_cells[(cell.y * 256 + cell.x) * 2 + 1] = 217
	return snapshot


func sample(sensor: RefCounted, position: Vector2, radius: int, options: Dictionary) -> Dictionary:
	return sensor.observe(view(position),[{"material_id":16,"radius_cells":radius}],options)


func material_cases() -> void:
	var sensor := Perception.new()
	check(sensor.ingest_snapshot(publication({Vector2i(33,32):16,Vector2i(73,32):16}),Vector2i(256,256),7),
		"bounded raw-ID full publication admitted")
	var adaptive := sample(sensor,Vector2(32.5,32.5),50,context())
	var legacy_context := context()
	legacy_context.erase("perception")
	var legacy := sample(sensor,Vector2(32.5,32.5),50,legacy_context)
	check(not legacy.materials.targets["16"].present,"legacy qualified lattice remains unchanged")
	check(adaptive.materials.targets["16"].present and adaptive.materials.targets["16"].nearest == Vector2(33.5,32.5),
		"exact near field detects thin off-grid material")
	check(adaptive.materials.near_sample_count > 0 and adaptive.materials.sample_count <= 4096,
		"near/coarse/refinement reads share one explicit finite budget")
	check(adaptive.world_generation == 3,"observation publishes actual native World generation")
	check(adaptive.materials.targets["16"].status == "observed","positive sampled presence distinguished from absence")
	var narrow := context()
	narrow.perception = {"spacing_cells":1,"near_radius_cells":0,"refine_boundaries":false}
	var exhaustive: Dictionary = sample(sensor,Vector2(32.5,32.5),4,narrow).materials
	check(exhaustive.coverage_complete and exhaustive.sample_spacing_cells == 1,"small exact query admits full local cell-center coverage")
	var capped: Dictionary = sample(sensor,Vector2(128.5,128.5),96,narrow).materials
	check(capped.resolution_limited and capped.requested_spacing_cells == 1 and capped.sample_spacing_cells > 1,
		"large requested dense query explicitly coarsens to fit budget")
	check(capped.sample_count <= 4096 and not capped.budget_exhausted and not capped.coverage_complete,
		"radius96 query remains bounded without biased partial raster truncation")
	check(capped.targets["16"].status == "unobserved_in_incomplete_coverage",
		"no sampled match under incomplete coverage is not exact material absence")
	var native_points := {}
	for y: int in range(24,41):
		for x: int in range(40,49): native_points[Vector2i(x,y)] = 16
	check(sensor.ingest_snapshot(publication(native_points,2),Vector2i(256,256),7),"bounded material patch replaced")
	var boundary: Dictionary = sample(sensor,Vector2(32.5,32.5),50,context()).materials.targets["16"].boundary
	check(boundary.available and boundary.normal.x < -0.5 and absf(boundary.tangent.y) > 0.5,
		"local material boundary normal/tangent arise from actual adjacent differing IDs")
	var far_thin := publication({Vector2i(73,32):16},3)
	check(sensor.ingest_snapshot(far_thin,Vector2i(256,256),7),"far thin feature installed")
	var missed: Dictionary = sample(sensor,Vector2(32.5,32.5),50,context()).materials.targets["16"]
	check(not missed.present and not missed.coverage_complete,
		"negative result retained: remote thin cells between coarse sites can remain unseen")
	var empty_exact: Dictionary = sample(sensor,Vector2(32.5,32.5),4,narrow).materials.targets["16"]
	check(empty_exact.available and not empty_exact.present and empty_exact.status == "absent",
		"complete local empty circle reports actual observed absence")
	far_thin.serial = 20
	far_thin.tick_index = 100
	far_thin.simulation_world_revision = 20
	check(not sensor.ingest_snapshot(far_thin,Vector2i(256,256),7),"changed World with old IDs becomes stale")
	var stale: Dictionary = sample(sensor,Vector2(32.5,32.5),50,context()).materials
	check(not stale.available and stale.status == "stale" and not stale.targets["16"].available,
		"stale publication is never returned as absent material")
	check(sensor.ingest_snapshot(publication({},21,4),Vector2i(256,256),7),"new generation receives a new full baseline")
	check(sample(sensor,Vector2(32.5,32.5),50,context()).world_generation == 4,"replacement generation is visible to memory owner")
	for invalid: Variant in [0,5,2.5,NAN]:
		var malformed := context()
		malformed.perception.spacing_cells = invalid
		check(not sample(sensor,Vector2(32.5,32.5),50,malformed).materials.available,
			"invalid requested spacing refuses measurement " + str(invalid))
	var requested := Perception.requests({"modules":[
		{"enabled":true,"type":"follow_material_boundary","params":{"material_id":16,"radius":50}},
		{"enabled":true,"type":"search_last_seen","params":{"material_id":16,"radius":80}},
		{"enabled":false,"type":"revisit_interest","params":{"material_id":3,"radius":96}}]})
	check(requested == [{"material_id":16,"radius_cells":80.0}],"generic typed material requests combine enabled new modules")
	completed.append("materials")


func peer_cases() -> void:
	var sensor := Perception.new()
	sensor.configure(Vector2i(256,256),7)
	var options := context()
	options.relations = {"tags":["worker"],"prefer_tags":["worker","kin"],"avoid_tags":["hostile"],"peer_id":-1}
	for index: int in range(8):
		options.neighbors.append({"instance_id":101+index,"run_id":"ambient2-spatial","epoch":7,
			"tick":12,"position":Vector2(40.5+index,32.5),"velocity":Vector2.RIGHT,
			"compatible":true,"tags":["kin","hostile"] if index==0 else ["worker"],"available":true})
	var sensed: Dictionary = sensor.observe(view(),[],options).neighbors
	check(sensed.available and sensed.actors.size() == 7 and sensed.incomplete,
		"bounded nearest seven peer seam declares truncated larger roster")
	check(sensed.actors[0].id == 101 and sensed.actors[0].affinity == -1,
		"avoid tag takes precedence over matching preferred tag")
	check(sensed.actors[1].affinity == 1 and sensed.actors[1].velocity_available \
		and sensed.actors[1].velocity == Vector2.RIGHT,"copied peer tags/velocity affect explicit observations")
	options.neighbors[0].epoch = 8
	options.neighbors[1].tick = 11
	options.neighbors[2].available = false
	options.neighbors[3].erase("velocity")
	var filtered: Dictionary = sensor.observe(view(),[],options).neighbors
	check(filtered.invalid == 3 and filtered.actors.size() == 5,"foreign/stale/disappeared peers are omitted with incomplete coverage")
	check(filtered.actors[0].id == 104 and not filtered.actors[0].velocity_available \
		and not filtered.actors[0].has("velocity"),"missing velocity is unavailable, never a fabricated zero vector")
	filtered.actors[0].tags.append("mutated")
	check("mutated" not in options.neighbors[3].tags,"social observations cannot mutate source tags")
	var absent := context()
	absent.erase("neighbors")
	check(not sensor.observe(view(),[],absent).neighbors.available,"missing peer observation differs from empty roster")
	var large := context()
	for index: int in range(100):
		large.neighbors.append({"instance_id":1000+index,"run_id":"ambient2-spatial","epoch":7,
			"tick":12,"position":Vector2(40.5,32.5),"compatible":true})
	var bounded: Dictionary = sensor.observe(view(),[],large).neighbors
	check(bounded.examined == 32 and bounded.incomplete and bounded.actors.size() == 7,
		"future capacity seam never performs an unbounded candidate scan")
	completed.append("peers")


func box(owner: Node2D, position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	owner.add_child(body)
	return body


func navigation_cases() -> void:
	var owner := Node2D.new()
	root.add_child(owner)
	var rig := Rig.new()
	owner.add_child(rig)
	check(rig.configure(Catalog.entry(&"runner"),Vector2(100,80),0,1)==OK,"actual articulated actor configured for terrain fan")
	if not rig.configured:
		owner.free()
		return
	var bridge := Bridge.new()
	check(bridge.initialize(owner.get_world_2d().space,rig.bodies(),rig.body_sizes())==OK,"real Rapier bridge initialized")
	if not bridge.is_initialized():
		owner.free()
		return
	bridge.step()
	rig.refresh_observation()
	var clear: Dictionary = rig.ambient_navigation_observation(32.0,Vector2i(256,256),false)
	check(clear.available and clear.ray_queries == 2 and clear.directions.size() == 2,"ground spends exactly two owner-mediated optional rays")
	check(clear.directions[0].available and not clear.directions[0].hit \
		and is_equal_approx(clear.directions[0].clearance_cells,32.0),"clear interior ray certifies only admitted local extent")
	var wall := box(owner,Vector2(122,80),Vector2(4,100))
	bridge.step()
	rig.refresh_observation()
	var blocked: Dictionary = rig.ambient_navigation_observation(32.0,Vector2i(256,256),false)
	check(blocked.directions[1].available and blocked.directions[1].hit \
		and blocked.directions[1].clearance_cells < 24.0,"real wall produces surface-relative clearance")
	check(not blocked.directions[0].hit,"opposite direction retains independent evidence")
	var fan: Dictionary = rig.ambient_navigation_observation(32.0,Vector2i(256,256),true)
	check(fan.ray_queries == 8 and fan.directions.size() == 8,"two-axis query has an explicit eight-ray limit")
	wall.free()
	bridge.step()
	rig.refresh_observation()
	var clipped: Dictionary = rig.ambient_navigation_observation(32.0,Vector2i(110,256),false)
	check(not clipped.directions[1].available and clipped.directions[1].boundary \
		and not clipped.directions[1].has("clearance_cells"),"canvas clipping without hit is unknown, not free space")
	var invalid: Dictionary = rig.ambient_navigation_observation(NAN,Vector2i(256,256),false)
	check(not invalid.available and invalid.ray_queries == 0,"invalid query consumes no terrain rays")
	bridge.shutdown()
	rig.close()
	owner.free()
	completed.append("navigation")


func cost_cases() -> void:
	var sensor := Perception.new()
	check(sensor.ingest_snapshot(publication({Vector2i(128,128):16}),Vector2i(256,256),7),"cost fixture raw native-ID cache primed once")
	for mode: String in ["legacy","adaptive"]:
		for population: int in [1,4,8]:
			var options := context()
			if mode == "legacy": options.erase("perception")
			var before: Dictionary = sensor.diagnostics()
			var start := Time.get_ticks_usec()
			for iteration: int in range(100):
				for actor: int in range(population):
					var measured: Dictionary = sample(sensor,Vector2(120.5+actor,120.5),50,options).materials
					check(measured.available and measured.sample_count <= Perception.MAX_ADAPTIVE_SAMPLES,
						"finite fresh measurement in cost fixture")
			var elapsed := Time.get_ticks_usec()-start
			var after: Dictionary = sensor.diagnostics()
			measurements.append({"mode":mode,"logical_query_population":population,"queries":100*population,
				"wall_usec":elapsed,"query_usec":int(after.query_usec_total)-int(before.query_usec_total),
				"samples":int(after.query_samples)-int(before.query_samples),
				"cache_bytes":after.cache_bytes,"scope":"copied-publication query cost; no instantiated actors in this microbenchmark"})
	completed.append("cost")


func run() -> void:
	material_cases()
	peer_cases()
	navigation_cases()
	cost_cases()
	check(completed == ["materials","peers","navigation","cost"],"all bounded spatial phases completed")
	var report := {"case":"AMBIENT-002 bounded spatial perception","checks":checks,"failures":failures,
		"completed":completed,"measurements":measurements,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"godot":Engine.get_version_info().string,"platform":OS.get_name(),
		"source_hashes":{"perception":FileAccess.get_sha256("res://scripts/ambient/ambient_perception.gd"),
			"rig":FileAccess.get_sha256("res://scripts/physical_actor_rig.gd"),
			"fixture":FileAccess.get_sha256("res://tests/test_ambient2_spatial.gd")}}
	var path := OS.get_environment("CYBERSAND_AMBIENT2_SPATIAL_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		check(file != null,"spatial report destination opened")
		report.checks = checks
		if file != null: file.store_string(JSON.stringify(report,"\t"))
	print("AMBIENT2_SPATIAL ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
