extends RefCounted

# A bounded cell capsule, shared by freehand erasing, slices and drill previews.
# Coordinates are material-cell centres. Long live drags advance in bounded
# capsules; releasing discards an unadmitted remainder rather than replaying it.
const MAX_CELLS: int = 4096
const MAX_RADIUS: int = 24
const MAX_PROBES: int = 65536
const MAX_LINE_STEPS: int = 2048

static func disc_offsets(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0 or radius > MAX_RADIUS: return result
	for y: int in range(-radius,radius+1):
		for x: int in range(-radius,radius+1):
			if x*x+y*y <= radius*radius: result.append(Vector2i(x,y))
	return result

static func build(first: Vector2i, last: Vector2i, radius: int, extent: Vector2i,
		allow_partial: bool = true) -> Dictionary:
	if radius < 0 or radius > MAX_RADIUS or extent.x <= 0 or extent.y <= 0:
		return {"ok":false,"outcome":"InvalidFootprint","cells":[]}
	var offsets: Array[Vector2i] = disc_offsets(radius)
	var steps: int = maxi(absi(last.x-first.x),absi(last.y-first.y))
	var step_budget: int = mini(MAX_LINE_STEPS,maxi(0,MAX_PROBES/offsets.size()-1))
	# Each new centre introduces at most two diameter rows, including diagonals.
	step_budget = mini(step_budget,maxi(0,(MAX_CELLS-offsets.size())/maxi(1,4*radius+2)))
	var limited: bool = steps > step_budget
	if limited and not allow_partial:
		return {"ok":false,"outcome":"FootprintCapacity","cells":[],"requested_steps":steps,
			"maximum_steps":step_budget,"radius":radius}
	var count: int = mini(steps,step_budget)
	var seen: Dictionary = {}
	var cells: Array[Vector2i] = []
	var end: Vector2i = first
	for index: int in range(count+1):
		end = first if steps == 0 else Vector2i((Vector2(first).lerp(Vector2(last),float(index)/float(steps))).round())
		for offset: Vector2i in offsets:
			var cell: Vector2i = end+offset
			if cell.x < 0 or cell.y < 0 or cell.x >= extent.x or cell.y >= extent.y: continue
			var key: int = cell.y*extent.x+cell.x
			if seen.has(key): continue
			seen[key] = true
			cells.append(cell)
	if cells.size() > MAX_CELLS:
		return {"ok":false,"outcome":"FootprintCapacity","cells":[]}
	return {"ok":true,"outcome":"BoundedCapsule","cells":cells,"end":end,
		"partial":limited,"requested_steps":steps,"completed_steps":count,
		"radius":radius,"requested_cells":cells.size(),"probes":(count+1)*offsets.size()}

static func outline(first: Vector2, last: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if first.is_equal_approx(last):
		for i: int in range(49): points.append(first+Vector2.from_angle(TAU*float(i)/48.0)*maxf(0.5,radius+0.5))
		return points
	var angle: float = (last-first).angle()
	var visible_radius: float = maxf(0.5,radius+0.5)
	for i: int in range(25): points.append(last+Vector2.from_angle(angle-PI*0.5+PI*float(i)/24.0)*visible_radius)
	for i: int in range(25): points.append(first+Vector2.from_angle(angle+PI*0.5+PI*float(i)/24.0)*visible_radius)
	points.append(points[0])
	return points
