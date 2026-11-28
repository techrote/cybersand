extends RefCounted
## Pure authored detail selection from prior exact operation raster. No World access.
## A projected material face is a geometric attachment, not structural-strength proof.
const ArtPlan = preload("res://scripts/art_batch_plan.gd")
const MAX_SIDE := 512
const MAX_OPERATIONS := 2048
const MAX_SCAN_BOUND := 1048576
const SUPPORT_MATERIALS := [58,28,13,7]
const ZONE_EXPANSION := 8

static func build(structure_ops: Array, service_ops: Array, extent: Vector2i, zones: Array, clearance_rects: Array, seed: int, max_detail_cells: int = 512) -> Dictionary:
	if extent.x<1 or extent.y<1 or extent.x>MAX_SIDE or extent.y>MAX_SIDE or max_detail_cells<2 or max_detail_cells>4096:
		return _failure("Context detail requires a 1–512-cell extent and 2–4096-cell detail budget.")
	if zones.is_empty() or zones.size()>128 or clearance_rects.size()>128: return _failure("Declare bounded detail zones and clearance regions.")
	var bounds := Rect2i(Vector2i.ZERO,extent)
	var allowed := PackedByteArray()
	allowed.resize(extent.x*extent.y)
	var expanded_zones: Array = []
	for value: Variant in zones:
		var box := _rect(value)
		if box.size.x<1 or box.size.y<1 or not bounds.encloses(box): return _failure("Detail zone must fit the local recipe extent.")
		box = box.grow(ZONE_EXPANSION).intersection(bounds)
		expanded_zones.append([box.position.x,box.position.y,box.size.x,box.size.y])
		for y: int in range(box.position.y,box.end.y):
			for x: int in range(box.position.x,box.end.x): allowed[y*extent.x+x]=1
	for value: Variant in clearance_rects:
		var box := _rect(value)
		if box.size.x<1 or box.size.y<1 or not bounds.encloses(box): return _failure("Clearance must fit the local recipe extent.")
		for y: int in range(box.position.y,box.end.y):
			for x: int in range(box.position.x,box.end.x): allowed[y*extent.x+x]=0
	var operations := structure_ops.duplicate(true)
	operations.append_array(service_ops.duplicate(true))
	if operations.is_empty() or operations.size()>MAX_OPERATIONS: return _failure("Prior structure/service operations exceed their finite budget.")
	var raster := ArtPlan.new()
	if not raster.configure(operations,bounds): return _failure(raster.error)
	var scan_bound := 0
	for op: Dictionary in raster.operations:
		match op.shape:
			"pixels": scan_bound+=op.points.size()
			"rectangle": scan_bound+=(int(op.x1)-int(op.x0)+1)*(int(op.y1)-int(op.y0)+1)
			"polygon": scan_bound+=op.polygon_bounds.get_area()
			"disc","airbrush": scan_bound+=(int(op.radius)*2+1)*(int(op.radius)*2+1)
			"line": scan_bound+=op.stroke_bounds.get_area() if int(op.width)>1 else maxi(absi(int(op.x1)-int(op.x0)),absi(int(op.y1)-int(op.y0)))+1
		if scan_bound>MAX_SCAN_BOUND: return _failure("Prior raster scan bound exceeds 1048576 candidates.")
	var cells := PackedInt32Array()
	cells.resize(extent.x*extent.y)
	while not raster.exhausted():
		var chunk: Dictionary = raster.next_chunk(4096)
		if chunk.is_empty(): continue
		for offset: int in range(0,chunk.points.size(),2):
			cells[int(chunk.points[offset+1])*extent.x+int(chunk.points[offset])]=int(chunk.material)
	var candidates: Array = []
	var unique := {}
	var eligible := {}
	for y: int in range(extent.y):
		for x: int in range(extent.x):
			var at := y*extent.x+x
			if cells[at]!=0 or allowed[at]==0: continue
			var point := Vector2i(x,y)
			for normal: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var host := point+normal
				if not bounds.has_point(host) or cells[host.y*extent.x+host.x] not in SUPPORT_MATERIALS: continue
				var tangent := Vector2i(-normal.y,normal.x)
				var other := point+tangent
				var other_host := other+normal
				if not bounds.has_point(other) or not bounds.has_point(other_host): continue
				var next := other.y*extent.x+other.x
				if cells[next]!=0 or allowed[next]==0 or cells[other_host.y*extent.x+other_host.x] not in SUPPORT_MATERIALS: continue
				var key := str(mini(at,next))+":"+str(maxi(at,next))
				if unique.has(key): continue
				unique[key]=true
				eligible[at]=true; eligible[next]=true
				candidates.append([at,next])
	if candidates.is_empty(): return _failure("No empty two-cell faces match declared context; revise zones or supporting structure.")
	var random := RandomNumberGenerator.new()
	random.seed=seed
	for index: int in range(candidates.size()-1,0,-1):
		var swap := random.randi_range(0,index)
		var held: Variant = candidates[index]
		candidates[index]=candidates[swap]
		candidates[swap]=held
	var reserved := {}
	var points: Array = []
	# A sparse perimeter sample; every emitted cell touches the prior source,
	# and bars have a one-cell separation. Newly added detail never supplies support.
	var target := mini(max_detail_cells,maxi(2,eligible.size()/6))
	for candidate: Array in candidates:
		if points.size()+2>target: break
		if reserved.has(candidate[0]) or reserved.has(candidate[1]): continue
		for at: int in candidate:
			points.append([at%extent.x,at/extent.x])
			reserved[at]=true
			var point := Vector2i(at%extent.x,at/extent.x)
			for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next := point+delta
				if bounds.has_point(next): reserved[next.y*extent.x+next.x]=true
	if points.is_empty(): return _failure("No nonoverlapping contextual detail survived the finite budget.")
	return {"ok":true,"operations":[{"shape":"pixels","material":28,"points":points}],
		"emitted_cells":points.size(),"eligible_faces":eligible.size(),"conservative_scan_bound":scan_bound,
		"expanded_detail_zones":expanded_zones,"zone_expansion_cells":ZONE_EXPANSION,
		"scope":"Seeded authored two-cell bars touching existing projected structural material; exact native application and readback remain separate."}

static func _rect(value: Variant) -> Rect2i:
	if not value is Array or value.size()!=4: return Rect2i()
	for number: Variant in value:
		if not ArtPlan.integer(number): return Rect2i()
	return Rect2i(int(value[0]),int(value[1]),int(value[2]),int(value[3]))

static func _failure(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"operations":[],"emitted_cells":0,"eligible_faces":0}
