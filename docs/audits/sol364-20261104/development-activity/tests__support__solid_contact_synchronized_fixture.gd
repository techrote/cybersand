extends RefCounted

# Test-only synchronous owner. The production asynchronous worker is not
# replaced or invoked here. After the one ordinary initialization tick and
# source handoff, contact measurement does not advance the native world.
const C = preload("res://scripts/rigid_body_coupling.gd")
const GENERATION: int = 7
const PHYSICS_EPOCH: int = 17

static func rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))

static func create(definition: Dictionary, fixture: Dictionary, workers: int) -> Dictionary:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if world == null or not bool(world.diagnostic_reset({"workers":workers,
		"telemetry":false,"conservative_displacement":true})):
		return {"error":"native reset"}
	world.set_simulation_window_enabled(false)
	for item: Array in definition.tree:
		if not bool(world.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4])):
			return {"error":"retained tree authoring"}
	var kind: String = fixture.get("surroundings", "empty")
	if kind != "empty":
		for x: int in [30,119]:
			if not bool(world.diagnostic_fill_rect(Vector2i(x,34),Vector2i(1,38),1)):
				return {"error":"bank wall authoring"}
		var top: int = 48 if kind == "embedded_sand" else 58
		for y: int in range(top,72):
			for x: int in range(31,119):
				if int(world.material_at(x,y)) != 0 or (kind == "offcenter_sand" and x < 54):
					continue
				if not bool(world.diagnostic_fill_rect(Vector2i(x,y),Vector2i.ONE,2)):
					return {"error":"bank Sand authoring"}
	for item: Array in fixture.get("pre_tick_rectangles",[]):
		if not bool(world.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4])):
			return {"error":"independent pre-tick support control authoring"}
	if not bool(world.simulation_tick()):
		return {"error":"native initialization tick"}
	var configured: Dictionary = world.solid_detachment_command({"action":"configure","members":1024,"shapes":128})
	if not configured.get("ok",false):
		return {"error":"native configuration","receipt":configured}
	var source: Dictionary = world.solid_detachment_command({"action":"cut_prepare",
		"domain":rect(definition.domain),"anchors":rect(definition.anchors),
		"cut":rect(definition.cut),"seed":Vector2i(definition.seed[0],definition.seed[1])})
	if not source.get("ok",false):
		return {"error":"native cut preparation","receipt":source}
	return {"world":world,"source":source}

static func activate(fixture: Dictionary) -> Dictionary:
	var world: Object = fixture.world
	var source: Dictionary = fixture.source
	var acknowledged: Dictionary = world.solid_detachment_command({"action":"acknowledge",
		"token":source.token,"body_id":1,"body_generation":GENERATION,
		"shape_count":source.shape_count,"payload_digest":source.payload_digest,"shape_digest":source.shape_digest})
	if not acknowledged.get("ok",false):
		return {"error":"exact body acknowledgment","receipt":acknowledged}
	var committed: Dictionary = world.solid_detachment_command({"action":"commit","token":source.token})
	if not committed.get("ok",false):
		return {"error":"exclusive source commit","receipt":committed}
	var finalized: Dictionary = world.solid_detachment_command({"action":"finalize","token":source.token,
		"body_id":1,"body_generation":GENERATION,"terrain_revision":committed.commit_revision,"physics_epoch":PHYSICS_EPOCH})
	if not finalized.get("ok",false):
		return {"error":"native collision receipt","receipt":finalized}
	return {"committed":committed,"finalized":finalized}

static func shape_data(source: Dictionary) -> Dictionary:
	var centers := PackedVector2Array()
	var sizes := PackedVector2Array()
	var rectangles: PackedInt32Array = source.rectangles
	for index: int in range(0,rectangles.size(),4):
		var size := Vector2(rectangles[index+2],rectangles[index+3])
		sizes.append(size)
		centers.append(Vector2(rectangles[index],rectangles[index+1])+size*0.5-(source.center as Vector2))
	return {"centers":centers,"sizes":sizes}

static func observe(world: Object, shapes: Dictionary, pose: Transform2D,
		velocity: Vector2, omega: float, sample: int) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var states := PackedFloat32Array()
	var centers: PackedVector2Array = shapes.centers
	var sizes: PackedVector2Array = shapes.sizes
	for index: int in range(centers.size()):
		var offset: Vector2 = pose.x*centers[index].x + pose.y*centers[index].y
		var point_velocity: Vector2 = velocity + Vector2(-offset.y,offset.x)*omega
		C.append_input(states,index+1,pose*centers[index],pose.get_rotation(),sizes[index],
			point_velocity,omega,sizes[index].x*sizes[index].y,sample)
	world.prepare_rigid_body_coupling(states,false)
	var prepared: int = Time.get_ticks_usec()
	var observation: Dictionary = world.solid_detachment_contact_observation()
	var measured: int = Time.get_ticks_usec()
	observation["snapshot_serial"] = sample
	observation["physics_epoch"] = PHYSICS_EPOCH
	observation["published_usec"] = measured
	freeze(observation)
	var finished: int = Time.get_ticks_usec()
	return {"observation":observation,"owner_ms":float(finished-started)/1000.0,
		"prepare_ms":float(prepared-started)/1000.0,"observation_ms":float(measured-prepared)/1000.0,
		"envelope_freeze_ms":float(finished-measured)/1000.0}

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for nested: Variant in value.values(): freeze(nested)
		value.make_read_only()
	elif value is Array:
		for nested: Variant in value: freeze(nested)
		value.make_read_only()

static func pose_values(pose: Transform2D) -> Array:
	return [pose.x.x,pose.x.y,pose.y.x,pose.y.y,pose.origin.x,pose.origin.y]

static func json_value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return [value.x,value.y]
	if value is Transform2D:
		return pose_values(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = json_value(value[key])
		return result
	if value is Array or value is PackedInt32Array or value is PackedFloat32Array \
			or value is PackedFloat64Array or value is PackedVector2Array or value is PackedByteArray:
		var result: Array = []
		for item: Variant in value: result.append(json_value(item))
		return result
	return value

static func partition(source: Dictionary, holes: Array) -> Dictionary:
	var members: PackedInt32Array = source.members
	var rectangles: PackedInt32Array = source.rectangles
	var occupied: Dictionary = {}
	for index: int in range(0,members.size(),6): occupied[Vector2i(members[index],members[index+1])] = true
	var covered: Dictionary = {}
	var valid: bool = occupied.size() == 520
	for index: int in range(0,rectangles.size(),4):
		for y: int in range(rectangles[index+1],rectangles[index+1]+rectangles[index+3]):
			for x: int in range(rectangles[index],rectangles[index]+rectangles[index+2]):
				var cell := Vector2i(x,y)
				valid = valid and occupied.has(cell) and not covered.has(cell)
				covered[cell] = true
	var hole_valid: bool = true
	for hole: Array in holes: hole_valid = hole_valid and not covered.has(Vector2i(hole[0],hole[1]))
	return {"valid":valid and covered.size()==occupied.size(),"member_count":occupied.size(),
		"covered_count":covered.size(),"shape_count":rectangles.size()/4,"holes_empty":hole_valid}

static func corners(pose: Transform2D, center: Vector2, size: Vector2) -> Array:
	var result: Array = []
	for sign_value: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var point: Vector2 = pose*(center+sign_value*size*0.5)
		result.append([point.x,point.y])
	return result

static func geometry(observation: Dictionary, source: Dictionary, shapes: Dictionary, holes: Array) -> Dictionary:
	var contacts: Array = []
	for contact: Dictionary in observation.get("contacts",[]):
		contacts.append([contact.proxy,contact.face,contact.cell.x,contact.cell.y,
			contact.point.x,contact.point.y,contact.normal.x,contact.normal.y,
			contact.a.x,contact.a.y,contact.b.x,contact.b.y,contact.depth,contact.area,contact.weight])
	var pose: Transform2D = observation.source_transform
	var proxies: Array = []
	for index: int in range(shapes.centers.size()):
		proxies.append(corners(pose,shapes.centers[index],shapes.sizes[index]))
	var hole_witnesses: Array = []
	for hole: Array in holes:
		var local: Vector2 = Vector2(hole[0]+0.5,hole[1]+0.5)-(source.center as Vector2)
		var overlap_area: int = 0
		var rectangles: PackedInt32Array = source.rectangles
		for index: int in range(0,rectangles.size(),4):
			var width: int = maxi(0,mini(int(hole[0])+1,rectangles[index]+rectangles[index+2])-maxi(int(hole[0]),rectangles[index]))
			var height: int = maxi(0,mini(int(hole[1])+1,rectangles[index+1]+rectangles[index+3])-maxi(int(hole[1]),rectangles[index+1]))
			overlap_area += width*height
		hole_witnesses.append({"source_cell":hole,"corners":corners(pose,local,Vector2.ONE),
			"proxy_area":overlap_area,"method":"exact_source_partition_under_common_rigid_transform"})
	var metrics: Array = []
	for proxy: Dictionary in observation.proxies:
		metrics.append([proxy.proxy,proxy.area,proxy.max_depth,proxy.overlap_cells])
	return {"pose":pose_values(pose),"proxies":proxies,"hole_witnesses":hole_witnesses,
		"contacts":contacts,"proxy_metrics":metrics,"overlap_cells":observation.overlap_cells,
		"overlap_area":observation.overlap_area,"sand_overlap_area":observation.sand_overlap_area,
		"max_penetration":observation.max_penetration,"max_sand_penetration":observation.max_sand_penetration}
