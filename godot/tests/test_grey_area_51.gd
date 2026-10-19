extends SceneTree

const Recipe = preload("res://scripts/grey_area_51.gd")
const Layout = preload("res://scripts/grey_area_51_layout.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Character = preload("res://scripts/sampled_character.gd")
const MATERIAL_TICKS: int = 120
const FIXED_DELTA: float = 1.0 / 60.0
const BODY_OFFSET := Vector2(4, 7)
const CONCRETE: int = 58
const SIDE: int = 1024

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
		expect(false, "Grey Area 51 requires the native demo classes")
		_finish()
		return
	var checked: Dictionary = _contract_checks()
	if checked.get("ok", false): _native_checks(checked.definition)
	_finish()


func _finish() -> void:
	print("GREY_AREA_51_IDENTITY: " + JSON.stringify(evidence))
	print("GREY_AREA_51: %d assertions; %d failures; %d native material ticks/1 worker; %d sampled-character steps against native geometry" % [
		assertions, failures, MATERIAL_TICKS, traversal_steps])
	quit(1 if failures else 0)


func _contract_checks() -> Dictionary:
	var rectangles: PackedInt32Array = Recipe.rectangles()
	var checked: Dictionary = Contract.validate(Recipe.definition())
	expect(checked.get("ok", false), "Grey Area 51 contract: " + str(checked.get("error", "invalid schema")))
	if not checked.get("ok", false): return checked
	var definition: Dictionary = checked.definition
	var parsed: Dictionary = Contract.parse(str(checked.canonical_json))
	expect(rectangles == Recipe.rectangles() and parsed.get("ok", false)
		and parsed.get("hash", "") == checked.hash,
		"Grey Area 51 construction or canonical JSON identity is nondeterministic")
	expect(definition.schema_version == 2 and definition.id == Recipe.SCENARIO_ID
		and definition.interest == {"policy":"fixed", "region":[32,32,960,192]}
		and definition.transport_profile == Contract.base("test/baseline").transport_profile
		and definition.water_semantics == [1,8,12,0] and definition.execution.policy == "owner"
		and definition.player_enabled and not definition.body_enabled
		and definition.tools == ["paint","erase","player"]
		and definition.events.is_empty() and definition.conditions.is_empty(),
		"Grey Area 51 changed ordinary material policies or introduced scene-owned simulation")
	var area: int = 0
	var bounded: bool = not rectangles.is_empty() and rectangles.size() % 5 == 0
	for offset: int in range(0, rectangles.size(), 5):
		var rect := Rect2i(rectangles[offset], rectangles[offset+1], rectangles[offset+2], rectangles[offset+3])
		area += rect.size.x * rect.size.y
		bounded = bounded and rect.has_area() and Rect2i(0,0,SIDE,SIDE).encloses(rect)
		bounded = bounded and rectangles[offset+4] >= 0 and rectangles[offset+4] < Contract.MATERIAL_COUNT
	expect(bounded and rectangles.size() / 5 <= Contract.MAX_RECORDS
		and area <= 8 * SIDE * SIDE
		and str(checked.canonical_json).to_utf8_buffer().size() <= Contract.MAX_JSON_BYTES,
		"Grey Area 51 exceeds native bounds or record/write/canonical-byte capacities")
	var views: Array[Dictionary] = Recipe.viewpoints()
	expect(views.size() == 6 and views[0].origin == Vector2(32,32)
		and views[0].size == Vector2i(960,192) and definition.presentation.regions.size() == 5,
		"Grey Area 51 needs one overview and five contiguous tile views")
	var local_counts: Array[int] = []
	for index: int in range(5):
		var local: PackedInt32Array = Recipe.West.tile(index) if index < 2 else (
			Recipe.East.tile(index) if index > 2 else Recipe._containment())
		var local_bounded: bool = not local.is_empty() and local.size() % 5 == 0 and local.size() / 5 <= 650
		for offset: int in range(0, local.size(), 5):
			var rect := Rect2i(local[offset],local[offset+1],local[offset+2],local[offset+3])
			local_bounded = local_bounded and rect.has_area() and Rect2i(0,0,192,192).encloses(rect)
		expect(local_bounded, "Tile escapes local bounds or its 650-record allocation: " + Layout.TITLES[index])
		local_counts.append(local.size() / 5)
		var origin: Vector2i = Layout.tile_origin(index)
		expect(views[index+1].origin == Vector2(origin) and views[index+1].size == Vector2i(192,192)
			and not str(views[index+1].name).is_empty()
			and Layout.tile_at(Vector2(origin)) == index
			and Layout.tile_at(Vector2(origin + Vector2i(191,191))) == index,
			"Tile framing or coordinate lookup is discontinuous: " + Layout.TITLES[index])
	expect(Layout.tile_at(Vector2(31,32)) == -1 and Layout.tile_at(Vector2(32,31)) == -1
		and Layout.tile_at(Vector2(992,223)) == -1 and Layout.tile_at(Vector2(991,224)) == -1,
		"Outside coordinates wrap into a valid bunker tile")
	var pairs: Dictionary = {}
	for edge: Dictionary in Layout.EDGES:
		var a: int = int(edge.a)
		var b: int = int(edge.b)
		var pair: String = "%d:%d" % [a,b]
		expect(a >= 0 and a < b and b < 5 and b == a + 1 and edge.axis == "x"
			and not pairs.has(pair) and int(edge.offset) >= 12 and int(edge.offset) < 180,
			"Shared port metadata is duplicated, nonadjacent or out of bounds: " + str(edge.name))
		pairs[pair] = true
	expect(pairs.size() == 4, "The five-tile bunker is missing a neighbouring connection")
	var tour: Array[Vector2i] = Layout.tour()
	var tour_ids: Array[int] = []
	var orthogonal: bool = tour.size() >= 5
	for index: int in range(tour.size()):
		var tile_index: int = Layout.tile_at(Vector2(tour[index]))
		if not tour_ids.has(tile_index): tour_ids.append(tile_index)
		if index > 0:
			var delta: Vector2i = tour[index] - tour[index-1]
			orthogonal = orthogonal and delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0)
	expect(orthogonal and tour_ids == [0,1,2,3,4]
		and tour[0] == Vector2i(56,176) and tour[-1] == Vector2i(960,176),
		"The authored west-to-east tour must reach all five tiles through axis-aligned routes")
	evidence = {"definition_sha256":checked.hash, "records":rectangles.size()/5,
		"write_area":area, "canonical_bytes":str(checked.canonical_json).to_utf8_buffer().size(),
		"tile_records":local_counts, "neighbour_ports":pairs.size()}
	return checked


func _rasterize(rectangles: PackedInt32Array) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(SIDE * SIDE)
	cells.fill(0)
	for offset: int in range(0, rectangles.size(), 5):
		for y: int in range(rectangles[offset+1], rectangles[offset+1] + rectangles[offset+3]):
			for x: int in range(rectangles[offset], rectangles[offset] + rectangles[offset+2]):
				cells[y * SIDE + x] = rectangles[offset+4]
	return cells


func _native_checks(definition: Dictionary) -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var host: CyberMicroScenarioHost = Host.new()
	var rectangles: PackedInt32Array = Recipe.rectangles()
	var expected: PackedByteArray = _rasterize(rectangles)
	var built: bool = bridge.build_world(world, rectangles)
	expect(built, "Native bunker construction failed: " + str(bridge.get_last_error()))
	if not built: return
	var original: PackedByteArray = bridge.export_level(world)
	var installed: bool = host.install(world, definition, "Inspect", false)
	expect(installed and original.size() == CyberDemoSaveCodec.WORLD_BYTES
		and bridge.export_level(world) == original and int(world.get_worker_threads()) == 1
		and int(world.get_tick_index()) == 0,
		"Native host disagrees with the direct recipe or initial worker identity")
	if not installed: return
	var initial: PackedByteArray = world.get_cells()
	expect(initial == expected, "Native cells differ from independent ordered-rectangle rasterization")
	# Classify every authored material through a native collision query at an
	# actual retained cell, then count those identities over the complete slab.
	var blocking: Dictionary = {}
	for y: int in range(32,224):
		for x: int in range(32,992):
			var material: int = initial[y * SIDE + x]
			if not blocking.has(material):
				blocking[material] = bool(world.character_box_collides(Vector2(x,y),Vector2.ONE,0))
	var stable_palette: bool = blocking.has(0) and not blocking[0] and blocking.get(CONCRETE,false)
	for material: int in blocking:
		stable_palette = stable_palette and (material == 0 or (material >= 38 and blocking[material]))
	expect(stable_palette, "Bunker uses a non-solid finish or live material in its structural palette")
	var raster_density: Dictionary = _density(expected, blocking)
	var native_density: Dictionary = _density(initial, blocking)
	expect(raster_density == native_density, "Native and rasterized material proportions disagree")
	expect(float(native_density.overall.solid_fraction) >= 0.75
		and float(native_density.overall.concrete_fraction) >= 0.65,
		"Bunker must retain at least 75% solid and 65% native Concrete: " + JSON.stringify(native_density.overall))
	for tile: Dictionary in native_density.tiles:
		expect(float(tile.solid_fraction) >= 0.75, "Tile loses its enclosed solid mass: " + JSON.stringify(tile))
	evidence["native_density"] = native_density
	_native_clearance(world, "initial")
	_native_seams(world, "initial")
	var supported: bool = false
	for offset: int in range(1,8):
		if world.character_box_collides(Recipe.spawn()+Vector2(0,offset), Character.BODY_SIZE, 1): supported = true
	expect(not world.character_box_collides(Recipe.spawn(),Character.BODY_SIZE,0) and supported,
		"Bunker spawn is enclosed or lacks nearby native footing")
	var progressed: bool = true
	for tick: int in range(MATERIAL_TICKS):
		if not host.advance():
			progressed = false
			break
	expect(progressed and not world.has_failed() and int(world.get_tick_index()) == MATERIAL_TICKS,
		"Bunker failed bounded native material progression: " + host.last_error)
	expect(world.get_cells() == initial, "Authored Concrete, machinery or Empty passages changed after 120 ticks")
	_native_clearance(world, "after 120 ticks")
	_native_seams(world, "after 120 ticks")
	var stats: Dictionary = bridge.inspect_statistics(world)
	expect(stats.get("ok",false), "Native bunker statistics are unavailable")
	if stats.get("ok",false):
		expect(int(stats["values"].resident_chunks) <= int(stats.limits.maximum_chunks)
			and int(stats["values"].active_chunks) <= int(stats.limits.active_chunks)
			and int(stats["values"].scheduled_cores) <= int(stats.limits.active_cores),
			"Bunker exceeded native storage or scheduling capacity")
	var progressed_bytes: PackedByteArray = bridge.export_level(world)
	_cross_every_seam(world)
	_continuous_return_tour(world)
	expect(int(world.get_tick_index()) == MATERIAL_TICKS and bridge.export_level(world) == progressed_bytes,
		"Character traversal reset or changed the native material field")
	var invalid: Dictionary = definition.duplicate(true)
	invalid.rectangles[0] = -1
	var cursor: Dictionary = host.summary()
	expect(not host.install(world,invalid) and bridge.export_level(world) == progressed_bytes
		and host.summary().definition_hash == cursor.definition_hash
		and host.summary().completed_tick == cursor.completed_tick,
		"Rejected bunker definition displaced the progressed world or host cursor")
	var point: Vector2i = Layout.edge_points(Layout.EDGES[3])[0] + Vector2i(20,0)
	world.paint_disc(point.x,point.y,0,62)
	expect(int(world.material_at(point.x,point.y)) == 62
		and world.character_box_collides(Vector2(point)-BODY_OFFSET,Character.BODY_SIZE,0),
		"A native solid seam edit failed to obstruct the sampled body")
	expect(host.install(world,definition,"Inspect",false) and int(world.get_tick_index()) == 0
		and bridge.export_level(world) == original and world.get_cells() == expected,
		"Whole-bunker reset did not restore the exact original cells and level bytes")


func _density(cells: PackedByteArray, blocking: Dictionary) -> Dictionary:
	var tiles: Array[Dictionary] = []
	var concrete_total: int = 0
	var solid_total: int = 0
	for index: int in range(5):
		var concrete: int = 0
		var solid: int = 0
		var origin: Vector2i = Layout.tile_origin(index)
		for y: int in range(origin.y,origin.y+192):
			for x: int in range(origin.x,origin.x+192):
				var material: int = cells[y * SIDE + x]
				if material == CONCRETE: concrete += 1
				if blocking.get(material,false): solid += 1
		concrete_total += concrete
		solid_total += solid
		tiles.append({"index":index,"concrete_cells":concrete,"solid_cells":solid,"total_cells":192*192,
			"concrete_fraction":float(concrete)/(192*192),"solid_fraction":float(solid)/(192*192)})
	return {"tiles":tiles,"overall":{"concrete_cells":concrete_total,"solid_cells":solid_total,
		"total_cells":960*192,"concrete_fraction":float(concrete_total)/(960*192),
		"solid_fraction":float(solid_total)/(960*192)}}


func _native_clearance(world: Variant, stage: String) -> void:
	# Overlapping 24×24 native queries cover the entire final passage volume,
	# including all turn caps, shared ports and the intake observation spur.
	for index: int in range(5):
		var blocked := Vector2i(-1,-1)
		for path: Array in Layout.paths(index):
			for segment: int in range(path.size()-1):
				var a: Vector2i = Layout.tile_origin(index) + path[segment]
				var b: Vector2i = Layout.tile_origin(index) + path[segment+1]
				var direction := Vector2i(signi(b.x-a.x),signi(b.y-a.y))
				var length: int = absi(b.x-a.x) + absi(b.y-a.y)
				for offset: int in range(0,length+4,4):
					var point: Vector2i = a + direction * mini(offset,length)
					if world.character_box_collides(Vector2(point-Vector2i(12,12)),Vector2(24,24),0):
						blocked = point
						break
				if blocked.x >= 0: break
			if blocked.x >= 0: break
		expect(blocked.x == -1, "%s loses 24-cell native clearance %s at %s" % [Layout.TITLES[index],stage,blocked])


func _native_seams(world: Variant, stage: String) -> void:
	for edge: Dictionary in Layout.EDGES:
		var points: Array[Vector2i] = Layout.edge_points(edge)
		var middle: Vector2i = (points[0] + points[1]) / 2
		var clear: bool = true
		var supported: bool = true
		for offset: int in range(-20,21):
			var point: Vector2i = middle + Vector2i(offset,0)
			clear = clear and not world.character_box_collides(Vector2(point)-BODY_OFFSET,Character.BODY_SIZE,0)
			supported = supported and world.character_box_collides(Vector2(point+Vector2i(0,12)),Vector2.ONE,0)
		var matching: bool = world.material_at(middle.x-1,middle.y+12) == world.material_at(middle.x,middle.y+12)
		expect(clear and supported and matching,
			"Native shared port is obstructed or lacks continuous footing %s: %s" % [stage,edge.name])


func _cross_every_seam(world: Variant) -> void:
	var completed: int = 0
	for edge: Dictionary in Layout.EDGES:
		var points: Array[Vector2i] = Layout.edge_points(edge)
		for reverse: bool in [false,true]:
			var character: CyberSampledCharacter = Character.new()
			character.reset(Vector2(points[1 if reverse else 0])-BODY_OFFSET)
			var result: Dictionary = _drive_to(character,Vector2(points[0 if reverse else 1])-BODY_OFFSET,world)
			var arrived: bool = result.ok and Layout.tile_at(character.position+BODY_OFFSET) == int(edge.a if reverse else edge.b)
			expect(arrived, "%s crossing %s failed: %s" % [edge.name,"reverse" if reverse else "forward",JSON.stringify(result)])
			expect(_no_recovery(character), "Shared-port crossing used enclosure/spawn recovery: " + str(edge.name))
			if arrived: completed += 1
	evidence["actual_seam_crossings"] = completed


func _continuous_return_tour(world: Variant) -> void:
	# One reset for the complete west→east→west journey. The return starts at
	# the actual arrival state; no relocation, velocity assignment or rescue.
	var character: CyberSampledCharacter = Character.new()
	character.reset(Recipe.spawn())
	var route: Array[Vector2i] = Layout.tour()
	var tour_steps: int = 0
	var jetpack_steps: int = 0
	for reverse: bool in [false,true]:
		if reverse: route.reverse()
		var visited: Array[int] = [Layout.tile_at(character.position+BODY_OFFSET)]
		var completed: bool = true
		var leg_steps: int = 0
		for index: int in range(1,route.size()):
			var result: Dictionary = _drive_to(character,Vector2(route[index])-BODY_OFFSET,world)
			leg_steps += int(result.steps)
			jetpack_steps += int(result.jetpack_steps)
			for tile_index: int in result.visited:
				if not visited.has(tile_index): visited.append(tile_index)
			if not result.ok:
				expect(false, "Continuous %s tour cannot reach %s: %s" % ["return" if reverse else "outbound",route[index],JSON.stringify(result)])
				completed = false
				break
		tour_steps += leg_steps
		var expected_visits: Array[int] = [0,1,2,3,4]
		if reverse: expected_visits.reverse()
		expect(completed and visited == expected_visits and leg_steps > 0,
			"Continuous %s tour failed to physically visit all five tiles: %s" % ["return" if reverse else "outbound",visited])
		evidence["return_tour" if reverse else "outbound_tour"] = visited
		evidence["return_steps" if reverse else "outbound_steps"] = leg_steps
		if not completed: break
	expect(tour_steps > 0 and tour_steps < 16000 and jetpack_steps > 0,
		"The continuous motor tour did not use bounded ordinary movement and jetpack controls")
	expect(_no_recovery(character), "The continuous motor tour used runtime or invalid-spawn recovery")
	evidence["tour_character_steps"] = tour_steps
	evidence["tour_jetpack_steps"] = jetpack_steps
	evidence["tour_resets"] = 1
	evidence["runtime_recovery_attempts"] = character.runtime_recovery_attempts
	evidence["invalid_spawn_recovery_attempts"] = character.invalid_spawn_recovery_attempts


func _drive_to(character: CyberSampledCharacter, target: Vector2, world: Variant) -> Dictionary:
	# Real sampled motor with discrete A/D/Space inputs. Native materials remain
	# at the progressed 120-tick state: this is geometry traversal, not live-world
	# timing, physical-actor qualification or UI-event coverage.
	var limit: int = ceili(character.position.distance_to(target) * 2.5) + 300
	var jetpack_steps: int = 0
	var visited: Array[int] = [Layout.tile_at(character.position+BODY_OFFSET)]
	for step: int in range(limit):
		var difference: Vector2 = target-character.position
		if (absf(difference.x) < 1.5 and absf(difference.y) < 1.5
			and absf(character.velocity.x) < 8.0 and absf(character.velocity.y) < 10.0):
			return {"ok":true,"steps":step,"jetpack_steps":jetpack_steps,"visited":visited}
		var desired_x: float = clampf(difference.x*5.0,-Character.WALK_SPEED,Character.WALK_SPEED)
		var horizontal: float = 0.0
		if absf(difference.x) >= 0.8 and (absf(character.velocity.x) < absf(desired_x)
			or signf(character.velocity.x) != signf(desired_x)):
			horizontal = signf(desired_x)
		var desired_y: float = clampf(difference.y*3.0,-48.0,64.0)
		var jetpack: bool = character.velocity.y > desired_y
		if jetpack: jetpack_steps += 1
		character.simulate(FIXED_DELTA,horizontal,jetpack,world)
		traversal_steps += 1
		var tile_index: int = Layout.tile_at(character.position+BODY_OFFSET)
		if not visited.has(tile_index): visited.append(tile_index)
		if not _no_recovery(character) or world.character_box_collides(character.position,Character.BODY_SIZE,0):
			return {"ok":false,"steps":step+1,"jetpack_steps":jetpack_steps,"visited":visited,
				"reason":"body enclosure or recovery","position":str(character.position),"target":str(target)}
	return {"ok":false,"steps":limit,"jetpack_steps":jetpack_steps,"visited":visited,
		"reason":"movement budget","position":str(character.position),"velocity":str(character.velocity),"target":str(target)}


func _no_recovery(character: CyberSampledCharacter) -> bool:
	return (not character.runtime_enclosed and not character.recovery_blocked
		and character.runtime_recovery_attempts == 0 and character.runtime_recovery_successes == 0
		and character.invalid_spawn_recovery_attempts == 0 and character.invalid_spawn_recovery_successes == 0)
