extends RefCounted

# Finite recipe metadata and an independent post-raster clearance oracle. This
# helper never changes generated material, fixtures or their native decisions.
const RECIPE: String = "res://../examples/worldgen/gen007-deepworks.json"
const MANIFEST: String = "res://../examples/worldgen/gen007-qualification.json"
const SEEDS: Array[int] = [19301, 19317, 19337, 19361]
const PLANES: Array[String] = ["play", "scripted", "effects", "background"]
const SIDE: int = 1024

static func recipe(seed: int = 19301) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECIPE))
	if not value is Dictionary: return {}
	value.seed = seed
	return value

static func manifest() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return value if value is Dictionary else {}

static func feature_map(bundle: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for feature: Dictionary in bundle.get("features", []): result[feature.id] = feature
	return result

static func tagged(bundle: Dictionary, tag: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature: Dictionary in bundle.get("features", []):
		if tag in feature.get("tags", []): result.append(feature)
	return result

static func structural_receipt(bundle: Dictionary, grammar: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if bundle.get("bounds") != Rect2i(0, 0, SIDE, SIDE):
		return {"ok":false,"complete":false,"errors":["Expected one complete 1024-square map"]}
	var regions: Array[Dictionary] = tagged(bundle, "major-region")
	var halls: Array[Dictionary] = tagged(bundle, "named-subregion")
	var micros: Array[Dictionary] = tagged(bundle, "micro-feature")
	var loops: Array[Dictionary] = tagged(bundle, "optional-loop")
	var exhibits: Array[Dictionary] = tagged(bundle, "paired-native-exhibit")
	if regions.size() != 4: errors.append("Four major regions required")
	if halls.size() != 8: errors.append("Eight named galleries required")
	if micros.size() < 24: errors.append("At least twenty-four identifiable micro-features required")
	if loops.size() < 2: errors.append("At least two optional material loops required")
	if exhibits.size() != 4 or bundle.get("fixtures", []).size() != 8: errors.append("Four paired native exhibits required")
	var cross_chunk: int = 0
	var ids: Dictionary = {}
	for feature: Dictionary in bundle.features:
		if ids.has(feature.id): errors.append("Duplicate semantic ID " + str(feature.id))
		ids[feature.id] = true
		var rect: Rect2i = feature.bounds
		if feature.kind in ["district", "complex", "room"] and (rect.position / 64 != (rect.end - Vector2i.ONE) / 64): cross_chunk += 1
	if cross_chunk < 2: errors.append("Two cross-chunk structures required")
	var coverage: Dictionary = {}
	for hall: Dictionary in halls:
		var record: Dictionary = {}
		var rect: Rect2i = hall.bounds
		for plane: String in PLANES:
			var bytes: PackedByteArray = bundle.materials[plane]
			var nonempty: int = 0
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					if bytes[y * SIDE + x] != 0: nonempty += 1
			record[plane] = {"nonempty":nonempty,"intentional_empty":rect.size.x * rect.size.y - nonempty}
			if nonempty < 8: errors.append("Missing " + plane + " treatment in " + str(hall.id))
		coverage[hall.id] = record
	var routes: Dictionary = route_receipt(bundle, grammar)
	for message: String in routes.get("errors", []): errors.append(message)
	return {"ok":errors.is_empty(),"complete":true,"errors":errors,"major_regions":regions.size(),
		"named_subregions":halls.size(),"micro_features":micros.size(),"cross_chunk_structures":cross_chunk,
		"optional_loops":loops.size(),"paired_exhibits":exhibits.size(),"stable_ids":ids.keys(),
		"coverage":coverage,"routes":routes,"operations":bundle.get("operations",0)}

static func route_paths(bundle: Dictionary, grammar: Dictionary) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	for route: Dictionary in grammar.get("routes", []):
		if route.type != "passage": continue
		var points: Array[Vector2i] = []
		for point: Array in route.points: points.append(Vector2i(int(point[0]),int(point[1])))
		paths.append({"id":route.id,"points":points,"kind":"primary"})
	for loop: Dictionary in tagged(bundle,"optional-loop"):
		var b: Rect2i = loop.bounds
		var a: Vector2i = b.position + Vector2i(6,6)
		var z: Vector2i = b.end - Vector2i(7,7)
		paths.append({"id":str(loop.id)+"/ring","points":[a,Vector2i(z.x,a.y),z,Vector2i(a.x,z.y),a],"kind":"optional-loop"})
		# Derived from the accepted owned loop-exit and secondary-shaft projections.
		var parent: Dictionary = feature_map(bundle).get(loop.parent,{})
		var origin: Vector2i = parent.get("bounds",Rect2i()).position
		paths.append({"id":str(loop.id)+"/exit","points":[Vector2i(z.x,origin.y+410),Vector2i(origin.x+457,origin.y+410),Vector2i(origin.x+457,origin.y+108),Vector2i(origin.x+464,origin.y+108)],"kind":"secondary"})
		paths.append({"id":str(loop.id)+"/lower-entry","points":[Vector2i(origin.x+457,origin.y+360),Vector2i(origin.x+464,origin.y+360)],"kind":"secondary"})
	return paths

static func route_receipt(bundle: Dictionary, grammar: Dictionary) -> Dictionary:
	var bytes: PackedByteArray = bundle.materials.play
	var network := PackedByteArray()
	var tested := PackedByteArray()
	network.resize(SIDE * SIDE)
	tested.resize(SIDE * SIDE)
	var errors: Array[String] = []
	var paths: Array[Dictionary] = route_paths(bundle, grammar)
	var checked: int = 0
	var blocked: int = 0
	for path: Dictionary in paths:
		var points: Array = path.points
		for i: int in range(1,points.size()):
			var a: Vector2i = points[i-1]
			var b: Vector2i = points[i]
			if a.x != b.x and a.y != b.y:
				errors.append("Nonrectilinear path " + str(path.id))
				continue
			var direction: Vector2i = Vector2i(signi(b.x-a.x),signi(b.y-a.y))
			var length: int = absi(b.x-a.x)+absi(b.y-a.y)
			for step: int in range(length+1):
				var p: Vector2i = a+direction*step
				# External ports are truncated at the finite map boundary. Every
				# admitted interior centre retains the declared seven-cell square.
				if p.x < 3 or p.y < 3 or p.x >= SIDE-3 or p.y >= SIDE-3: continue
				var index: int = p.y*SIDE+p.x
				if tested[index] == 0:
					var clear: bool = true
					for y: int in range(p.y-3,p.y+4):
						for x: int in range(p.x-3,p.x+4):
							if bytes[y*SIDE+x] != 0: clear = false
					tested[index] = 1 if clear else 2
					checked += 1
					if not clear:
						blocked += 1
						if errors.size() < 12: errors.append("Final material blocks seven-cell clearance at %s on %s" % [p,path.id])
				if tested[index] == 1: network[index] = 1
	var queue := PackedInt32Array()
	var reached := PackedByteArray()
	reached.resize(SIDE*SIDE)
	var start: int = 512*SIDE+512
	if network[start] == 1:
		queue.append(start)
		reached[start] = 1
	var cursor: int = 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for next: int in [index-1,index+1,index-SIDE,index+SIDE]:
			if next >= 0 and next < network.size() and network[next] == 1 and reached[next] == 0:
				reached[next] = 1
				queue.append(next)
	var region_reach: Dictionary = {}
	var hall_reach: Dictionary = {}
	var reached_loops: int = 0
	for hall: Dictionary in tagged(bundle,"named-subregion"):
		var bounds: Rect2i = hall.bounds
		var p := Vector2i(bounds.end.x,bounds.position.y+84)
		var connected: bool = reached[p.y*SIDE+p.x] == 1
		hall_reach[hall.id] = connected
		region_reach[hall.parent] = region_reach.get(hall.parent,false) or connected
		if not connected: errors.append("Gallery is disconnected after rasterization: " + str(hall.id))
	for loop: Dictionary in tagged(bundle,"optional-loop"):
		var p: Vector2i = loop.bounds.position + Vector2i(6,6)
		if reached[p.y*SIDE+p.x] == 1: reached_loops += 1
		else: errors.append("Optional loop disconnected after rasterization: " + str(loop.id))
	return {"ok":errors.is_empty(),"complete":true,"errors":errors,"profile":"seven-cell square clearance on every explicit final-material path centre; no actor dynamics claim",
		"checked_centres":checked,"blocked_centres":blocked,"connected_centres":queue.size(),
		"regions":region_reach,"galleries":hall_reach,"connected_optional_loops":reached_loops,
		"temporary_grid_bytes":network.size()+tested.size()+reached.size()+queue.size()*4}

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
