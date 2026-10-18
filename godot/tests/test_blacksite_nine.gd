extends SceneTree

const Recipe = preload("res://scripts/blacksite_nine.gd")
const Layout = preload("res://scripts/blacksite_nine_layout.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Character = preload("res://scripts/sampled_character.gd")
const MATERIAL_TICKS: int = 120
const FIXED_DELTA: float = 1.0 / 60.0
const BODY_OFFSET := Vector2(4, 0)
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var assertions: int = 0
var failures: int = 0
var traversal_steps: int = 0
var evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not CyberWebCapabilities.native_available():
		expect(false, "Blacksite Nine regression requires the native demo classes")
		_finish()
		return
	var checked: Dictionary = _contract_checks()
	if checked.get("ok", false):
		_native_checks(checked.definition)
	_finish()


func _finish() -> void:
	print("BLACKSITE_NINE_IDENTITY: " + JSON.stringify(evidence))
	print("BLACKSITE_NINE: %d assertions; %d failures; %d native material ticks/1 worker; %d sampled-character steps against native geometry" % [
		assertions, failures, MATERIAL_TICKS, traversal_steps])
	quit(1 if failures else 0)


func _contract_checks() -> Dictionary:
	var rectangles: PackedInt32Array = Recipe.rectangles()
	var checked: Dictionary = Contract.validate(Recipe.definition())
	expect(checked.get("ok", false), "Connected complex contract: " + str(checked.get("error", "invalid schema")))
	if not checked.get("ok", false): return checked
	var definition: Dictionary = checked.definition
	var parsed: Dictionary = Contract.parse(str(checked.canonical_json))
	expect(rectangles == Recipe.rectangles() and parsed.get("ok", false)
		and parsed.get("hash", "") == checked.hash,
		"Connected complex construction or canonical JSON identity is nondeterministic")
	expect(CyberDemoWorlds.valid_id(Recipe.ID)
		and CyberDemoWorlds.rectangles(Recipe.ID) == rectangles
		and CyberDemoWorlds.spawn(Recipe.ID) == Recipe.spawn()
		and Recipe.SCENARIO_ID in CyberMicroScenarioCatalogue.ids()
		and CyberMicroScenarioCatalogue.definition(Recipe.SCENARIO_ID).rectangles == definition.rectangles,
		"Connected complex is not the same single-world recipe in both catalogues")
	expect(definition.schema_version == 2 and definition.id == Recipe.SCENARIO_ID
		and definition.interest == {"policy":"fixed", "region":[32,32,960,960]}
		and definition.transport_profile == Contract.base("test/baseline").transport_profile
		and definition.water_semantics == [1,8,12,0] and definition.execution.policy == "owner"
		and definition.player_enabled and not definition.body_enabled
		and definition.tools == ["paint","erase","player"]
		and definition.events.is_empty() and definition.conditions.is_empty(),
		"Connected complex changed ordinary material policies or introduced scene-owned simulation")
	var area: int = 0
	for offset: int in range(0, rectangles.size(), 5):
		area += rectangles[offset + 2] * rectangles[offset + 3]
	expect(rectangles.size() / 5 <= Contract.MAX_RECORDS and area <= 8 * 1024 * 1024
		and str(checked.canonical_json).to_utf8_buffer().size() <= Contract.MAX_JSON_BYTES,
		"Connected complex exceeds record, write-area or canonical byte capacity")
	var views: Array[Dictionary] = Recipe.viewpoints()
	expect(views.size() == 10 and views[0].origin == Vector2(32,32)
		and views[0].size == Vector2i(960,960) and definition.presentation.regions.size() == 9,
		"Connected complex needs one overview and nine contiguous tile views")
	var local_counts: Array[int] = []
	for index: int in range(9):
		var local: PackedInt32Array = Recipe.ROWS[index / 3].tile(index % 3)
		var bounded: bool = local.size() % 5 == 0 and not local.is_empty() and local.size() / 5 <= 410
		for offset: int in range(0, local.size(), 5):
			bounded = bounded and local[offset] >= 0 and local[offset + 1] >= 0
			bounded = bounded and local[offset + 2] > 0 and local[offset + 3] > 0
			bounded = bounded and local[offset] + local[offset + 2] <= 320
			bounded = bounded and local[offset + 1] + local[offset + 3] <= 320
		expect(bounded, "Tile geometry escapes its local bounds or 410-record allocation: " + Layout.CODES[index])
		local_counts.append(local.size() / 5)
		var origin: Vector2i = Layout.tile_origin(index)
		expect(views[index + 1].origin == Vector2(origin) and views[index + 1].size == Vector2i(320,320)
			and not str(views[index + 1].name).is_empty()
			and Layout.tile_at(Vector2(origin)) == index
			and Layout.tile_at(Vector2(origin + Vector2i(319,319))) == index,
			"Tile framing or world-coordinate lookup disagrees at " + Layout.CODES[index])
	expect(Layout.tile_at(Vector2(31,32)) == -1 and Layout.tile_at(Vector2(32,31)) == -1
		and Layout.tile_at(Vector2(992,991)) == -1 and Layout.tile_at(Vector2(991,992)) == -1,
		"Outside coordinates wrap into a valid complex tile")
	var tour_ids: Array[int] = Layout.TOUR.duplicate()
	tour_ids.sort()
	expect(tour_ids == [0,1,2,3,4,5,6,7,8],
		"The continuous tour must visit every native tile exactly once")
	var pairs: Dictionary = {}
	for edge: Dictionary in Layout.EDGES:
		var a: int = int(edge.a)
		var b: int = int(edge.b)
		var adjacent: bool = (b == a + 1 and a / 3 == b / 3) if edge.axis == "x" else b == a + 3
		var pair: String = "%d:%d" % [a,b]
		expect(a >= 0 and a < b and b < 9 and adjacent and not pairs.has(pair)
			and int(edge.offset) >= 14 and int(edge.offset) < 306,
			"Seam metadata is duplicated, nonadjacent or outside its shared edge: " + str(edge.name))
		pairs[pair] = true
	expect(pairs.size() == 12, "The 3×3 complex is missing an orthogonal neighbour connection")
	evidence = {"definition_sha256":checked.hash, "records":rectangles.size()/5,
		"write_area":area, "tile_records":local_counts, "neighbour_edges":pairs.size()}
	return checked


func _native_checks(definition: Dictionary) -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var host: CyberMicroScenarioHost = Host.new()
	var built: bool = bridge.build_world(world, Recipe.rectangles())
	expect(built, "Native connected-world construction failed: " + str(bridge.get_last_error()))
	if not built: return
	var original: PackedByteArray = bridge.export_level(world)
	var installed: bool = host.install(world, definition, "Inspect", false)
	expect(installed and original.size() == CyberDemoSaveCodec.WORLD_BYTES
		and bridge.export_level(world) == original and int(world.get_worker_threads()) == 1
		and int(world.get_tick_index()) == 0,
		"Native host disagrees with the ordinary recipe or requested initial worker identity")
	if not installed: return
	var initial_materials: PackedByteArray = world.get_cells()
	var graph: Dictionary = _route_graph()
	_native_clearance(world, "initial")
	_native_seams(world, "initial")
	expect(not world.character_box_collides(Recipe.spawn(), Character.BODY_SIZE, 0)
		and world.character_box_collides(Recipe.spawn() + Vector2(0,1), Character.BODY_SIZE, 1),
		"Entry spawn intersects terrain or lacks native footing")
	# Only this loop advances materials. Traversal below uses the real sampled
	# character against the resulting native field, without claiming live timing.
	var progressed: bool = true
	for tick: int in range(MATERIAL_TICKS):
		if not host.advance():
			progressed = false
			break
	expect(progressed and not world.has_failed() and int(world.get_tick_index()) == MATERIAL_TICKS,
		"Connected complex failed bounded native progression: " + host.last_error)
	var progressed_materials: PackedByteArray = world.get_cells()
	var lost_structure: Vector2i = Vector2i(-1,-1)
	var structural_cells: int = 0
	for index: int in range(initial_materials.size()):
		if initial_materials[index] == 1 or initial_materials[index] >= 38:
			structural_cells += 1
			if initial_materials[index] != progressed_materials[index] and lost_structure.x == -1:
				lost_structure = Vector2i(index % 1024, index / 1024)
	expect(lost_structure.x == -1,
		"Authored hard structure changed during ordinary native progression at " + str(lost_structure))
	evidence["stable_structural_cells"] = structural_cells
	_native_clearance(world, "after 120 ticks")
	_native_seams(world, "after 120 ticks")
	var stats: Dictionary = bridge.inspect_statistics(world)
	expect(stats.get("ok", false), "Native connected world has no valid statistics")
	if stats.get("ok", false):
		expect(int(stats["values"].resident_chunks) <= int(stats.limits.maximum_chunks)
			and int(stats["values"].active_chunks) <= int(stats.limits.active_chunks)
			and int(stats["values"].scheduled_cores) <= int(stats.limits.active_cores),
			"Connected world exceeded native storage or scheduling capacity")
	var progressed_bytes: PackedByteArray = bridge.export_level(world)
	_cross_every_seam(world)
	_continuous_tour(world, graph)
	expect(int(world.get_tick_index()) == MATERIAL_TICKS and bridge.export_level(world) == progressed_bytes,
		"Static-geometry traversal reset or changed the native material field")
	var invalid: Dictionary = definition.duplicate(true)
	invalid.rectangles[0] = -1
	var cursor: Dictionary = host.summary()
	expect(not host.install(world, invalid) and bridge.export_level(world) == progressed_bytes
		and host.summary().definition_hash == cursor.definition_hash
		and host.summary().completed_tick == cursor.completed_tick,
		"Rejected complex definition displaced the progressed world or host cursor")
	# Positive native-collision control: one solid seam edit must obstruct the
	# actual body query, and a whole-complex reset must remove it everywhere.
	var seam_point: Vector2i = Layout.edge_points(Layout.EDGES[4])[0] + Vector2i(20,0)
	world.paint_disc(seam_point.x, seam_point.y, 0, 62)
	expect(int(world.material_at(seam_point.x,seam_point.y)) == 62
		and world.character_box_collides(Vector2(seam_point) - BODY_OFFSET, Character.BODY_SIZE, 0),
		"A native solid edit inside the seam did not obstruct the sampled body")
	expect(host.install(world, definition, "Inspect", false)
		and int(world.get_tick_index()) == 0 and bridge.export_level(world) == original,
		"Whole-complex reset did not restore the exact original native bytes")


func _native_clearance(world: Variant, stage: String) -> void:
	# A 28×28 native volume, sampled every four cells, covers the complete
	# circulation reservation, including turn caps, glass and cable collision.
	for index: int in range(9):
		var blocked := Vector2i(-1,-1)
		for path: Array in Layout.paths(index):
			for segment: int in range(path.size() - 1):
				var a: Vector2i = Layout.tile_origin(index) + path[segment]
				var b: Vector2i = Layout.tile_origin(index) + path[segment + 1]
				var direction := Vector2i(signi(b.x-a.x),signi(b.y-a.y))
				var length: int = absi(b.x-a.x) + absi(b.y-a.y)
				for offset: int in range(0, length + 4, 4):
					var point: Vector2i = a + direction * mini(offset,length)
					if world.character_box_collides(Vector2(point - Vector2i(14,14)), Vector2(28,28), 0):
						blocked = point
						break
				if blocked.x >= 0: break
			if blocked.x >= 0: break
		expect(blocked.x == -1, "%s route loses native clearance %s at %s" % [Layout.CODES[index],stage,blocked])


func _native_seams(world: Variant, stage: String) -> void:
	for edge: Dictionary in Layout.EDGES:
		var points: Array[Vector2i] = Layout.edge_points(edge)
		var middle: Vector2i = (points[0] + points[1]) / 2
		var continuous: bool = true
		var structure: bool = true
		for offset: int in range(-20,21):
			var point: Vector2i = middle + (Vector2i(offset,0) if edge.axis == "x" else Vector2i(0,offset))
			continuous = continuous and not world.character_box_collides(
				Vector2(point) - BODY_OFFSET, Character.BODY_SIZE, 0)
			if edge.axis == "x":
				structure = structure and world.character_box_collides(
					Vector2(point) - BODY_OFFSET + Vector2(0,1), Character.BODY_SIZE, 1)
			elif absi(offset) <= 2:
				# A nearby elbow deliberately opens a sidewall; the shared collar
				# itself must remain solid across the neighbouring tile boundary.
				structure = structure and int(world.material_at(point.x-15,point.y)) >= 38
				structure = structure and int(world.material_at(point.x+14,point.y)) >= 38
		var matching: bool
		if edge.axis == "x":
			matching = world.material_at(middle.x-1,middle.y+14) == world.material_at(middle.x,middle.y+14)
		else:
			matching = world.material_at(middle.x-15,middle.y-1) == world.material_at(middle.x-15,middle.y)
			matching = matching and world.material_at(middle.x+14,middle.y-1) == world.material_at(middle.x+14,middle.y)
		expect(continuous and structure and matching,
			"Shared native seam is obstructed or lacks continuous footing/shaft walls %s: %s" % [stage,edge.name])


func _cross_every_seam(world: Variant) -> void:
	var completed: int = 0
	for edge: Dictionary in Layout.EDGES:
		var points: Array[Vector2i] = Layout.edge_points(edge)
		for reverse: bool in [false,true]:
			var character: CyberSampledCharacter = Character.new()
			character.reset(Vector2(points[1 if reverse else 0]) - BODY_OFFSET)
			var destination: int = int(edge.a if reverse else edge.b)
			var result: Dictionary = _drive_to(character, Vector2(points[0 if reverse else 1]) - BODY_OFFSET, world)
			var arrived: bool = result.ok and Layout.tile_at(character.position + Character.BODY_SIZE * 0.5) == destination
			expect(arrived, "%s crossing %s failed: %s" % [edge.name,"reverse" if reverse else "forward",JSON.stringify(result)])
			expect(_no_recovery(character), "Seam crossing used enclosure/spawn recovery: " + str(edge.name))
			if arrived: completed += 1
	evidence["actual_seam_crossings"] = completed


func _route_graph() -> Dictionary:
	var graph: Dictionary = {}
	for index: int in range(9):
		for path: Array in Layout.paths(index):
			for segment: int in range(path.size() - 1):
				var a: Vector2i = Layout.tile_origin(index) + path[segment]
				var b: Vector2i = Layout.tile_origin(index) + path[segment + 1]
				var direction := Vector2i(signi(b.x-a.x),signi(b.y-a.y))
				for offset: int in range(absi(b.x-a.x)+absi(b.y-a.y)+1):
					graph[a + direction * offset] = true
	return graph


func _route_between(graph: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not graph.has(start) or not graph.has(goal): return result
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start:start}
	var cursor: int = 0
	while cursor < queue.size() and not parents.has(goal):
		var point: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = point + direction
			if graph.has(next) and not parents.has(next):
				parents[next] = point
				queue.append(next)
	if not parents.has(goal): return result
	var point: Vector2i = goal
	while point != start:
		result.append(point)
		point = parents[point]
	result.append(start)
	result.reverse()
	var corners: Array[Vector2i] = [start]
	for index: int in range(1, result.size() - 1):
		if result[index] - result[index-1] != result[index+1] - result[index]:
			corners.append(result[index])
	if goal != start: corners.append(goal)
	return corners


func _continuous_tour(world: Variant, graph: Dictionary) -> void:
	var character: CyberSampledCharacter = Character.new()
	character.reset(Recipe.spawn())
	var route_start := Vector2i(Recipe.spawn() + BODY_OFFSET)
	var visited: Array[int] = [Layout.tile_at(Recipe.spawn())]
	var jetpack_steps: int = 0
	var tour_steps: int = 0
	for leg: int in range(Layout.TOUR.size()-1):
		var from: int = Layout.TOUR[leg]
		var to: int = Layout.TOUR[leg+1]
		var goal := Vector2i(-1,-1)
		for edge: Dictionary in Layout.EDGES:
			if int(edge.a) == from and int(edge.b) == to:
				goal = Layout.edge_points(edge)[1]
			elif int(edge.b) == from and int(edge.a) == to:
				goal = Layout.edge_points(edge)[0]
		var route: Array[Vector2i] = _route_between(graph, route_start, goal)
		expect(not route.is_empty(), "Continuous tour has no connected authored route from %s to %s" % [Layout.CODES[from],Layout.CODES[to]])
		if route.is_empty(): break
		var completed: bool = true
		for index: int in range(1, route.size()):
			var result: Dictionary = _drive_to(character, Vector2(route[index]) - BODY_OFFSET, world)
			tour_steps += int(result.steps)
			jetpack_steps += int(result.jetpack_steps)
			if not result.ok:
				expect(false, "Continuous tour %s to %s cannot reach turn %s: %s" % [Layout.CODES[from],Layout.CODES[to],route[index],JSON.stringify(result)])
				completed = false
				break
		if not completed: break
		var actual_tile: int = Layout.tile_at(character.position + Character.BODY_SIZE * 0.5)
		expect(actual_tile == to, "Continuous tour arrived in the wrong native tile")
		visited.append(actual_tile)
		route_start = goal
	expect(visited == Layout.TOUR and tour_steps > 0 and tour_steps < 18000 and jetpack_steps > 0,
		"The uninterrupted sampled-character tour did not visit all nine tiles within its movement budget")
	expect(_no_recovery(character), "Continuous tour used a recovery teleport or started enclosed")
	evidence["continuous_tour"] = visited
	evidence["tour_character_steps"] = tour_steps
	evidence["tour_jetpack_steps"] = jetpack_steps


func _drive_to(character: CyberSampledCharacter, target: Vector2, world: Variant) -> Dictionary:
	# Discrete A/D/Space controls only. No assignment to position, velocity,
	# acceleration, collision policy or recovery state occurs during a journey.
	var limit: int = ceili(character.position.distance_to(target) * 2.5) + 300
	var jetpack_steps: int = 0
	for step: int in range(limit):
		var difference: Vector2 = target - character.position
		if (absf(difference.x) < 1.5 and absf(difference.y) < 1.5
			and absf(character.velocity.x) < 8.0 and absf(character.velocity.y) < 10.0):
			return {"ok":true,"steps":step,"jetpack_steps":jetpack_steps}
		var desired_x: float = clampf(difference.x * 5.0, -Character.WALK_SPEED, Character.WALK_SPEED)
		var horizontal: float = 0.0
		if absf(difference.x) >= 0.8 and (absf(character.velocity.x) < absf(desired_x)
			or signf(character.velocity.x) != signf(desired_x)):
			horizontal = signf(desired_x)
		var desired_y: float = clampf(difference.y * 3.0, -48.0, 64.0)
		var jetpack: bool = character.velocity.y > desired_y
		if jetpack: jetpack_steps += 1
		character.simulate(FIXED_DELTA, horizontal, jetpack, world)
		traversal_steps += 1
		if not _no_recovery(character) or world.character_box_collides(character.position, Character.BODY_SIZE, 0):
			return {"ok":false,"steps":step+1,"jetpack_steps":jetpack_steps,
				"reason":"body enclosure or recovery","position":str(character.position),"target":str(target)}
	return {"ok":false,"steps":limit,"jetpack_steps":jetpack_steps,"reason":"movement budget",
		"position":str(character.position),"velocity":str(character.velocity),"target":str(target)}


func _no_recovery(character: CyberSampledCharacter) -> bool:
	return (not character.runtime_enclosed and not character.recovery_blocked
		and character.runtime_recovery_attempts == 0 and character.runtime_recovery_successes == 0
		and character.invalid_spawn_recovery_attempts == 0 and character.invalid_spawn_recovery_successes == 0)
