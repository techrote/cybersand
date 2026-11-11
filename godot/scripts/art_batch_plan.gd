extends RefCounted
## Lazy exact geometry; only a native-sized chunk is materialized at a time.
const SHAPES := ["rectangle","disc","line","pixels","polyline","polygon","airbrush"]
const Setup = preload("res://scripts/workbench_setup.gd")
var operations: Array = []
var index := 0
var cursor := 0
var line: Array[Vector2i] = []
var error := ""

func configure(value: Variant, bounds: Rect2i) -> bool:
	if not value is Array or value.is_empty(): error = "Use a nonempty JSON array of drawing operations."; return false
	for raw: Variant in value:
		if not raw is Dictionary or raw.get("shape") not in SHAPES: error = "Unknown shape. Choose a shape from Tools."; return false
		var op: Dictionary = raw.duplicate(true)
		if not integer(op.get("material")) or int(op.material) not in Setup.MATERIALS: error = "Use a material ID from the workbench paint palette."; return false
		op.material = int(op.material)
		var keys: Array = ["x","y","radius"] if op.shape in ["disc","airbrush"] else ["x0","y0","x1","y1"]
		if op.shape in ["pixels","polyline","polygon"]:
			var minimum := 1
			if op.shape == "polyline": minimum = 2
			elif op.shape == "polygon": minimum = 3
			if not op.get("points") is Array or op.points.size() < minimum:
				error = "%s needs at least %d points." % [op.shape,minimum]
				return false
			for pair: Variant in op.points:
				if not pair is Array or pair.size()!=2 or not integer(pair[0]) or not integer(pair[1]): error = "Pixel coordinates must be integers."; return false
				if not inside(pair[0],pair[1],bounds): error = "Pixel outside canvas."; return false
			if op.shape == "polyline":
				var segments: Array = []
				for i: int in range(1,op.points.size()):
					var start: Array = op.points[i-1]
					var end: Array = op.points[i]
					segments.append({"shape":"line","material":op.material,"width":op.get("width",1),
						"x0":start[0],"y0":start[1],"x1":end[0],"y1":end[1]})
				if not configure(segments,bounds): return false
				continue
			if op.shape == "polygon":
				var vertices := PackedVector2Array()
				var box := Rect2i(Vector2i(op.points[0][0],op.points[0][1]),Vector2i.ONE)
				for pair: Array in op.points:
					var point := Vector2i(pair[0],pair[1])
					vertices.append(Vector2(point))
					box = box.merge(Rect2i(point,Vector2i.ONE))
				op.vertices = vertices
				op.polygon_bounds = box
		else:
			for key: String in keys:
				if not integer(op.get(key)): error = "Missing integer: "+key; return false
				op[key] = int(op[key])
			if op.shape in ["disc","airbrush"]:
				if op.radius < 0 or op.radius > maxi(bounds.size.x,bounds.size.y) or not inside(op.x-op.radius,op.y-op.radius,bounds) or not inside(op.x+op.radius,op.y+op.radius,bounds): error = "Disc outside canvas."; return false
			elif not inside(op.x0,op.y0,bounds) or not inside(op.x1,op.y1,bounds) or (op.shape == "rectangle" and (op.x1<op.x0 or op.y1<op.y0)): error = "Invalid or outside rectangle/line."; return false
		if op.shape == "airbrush":
			for parameter: String in ["density","hardness"]:
				var value_in: Variant = op.get(parameter,1.0 if parameter == "density" else 0.0)
				if not (value_in is float or value_in is int) or not is_finite(float(value_in)) or value_in < 0 or value_in > 1:
					error = "Airbrush %s must be between 0 and 1." % parameter
					return false
				op[parameter] = float(value_in)
			if not integer(op.get("seed",0)):
				error = "Airbrush seed must be an integer."
				return false
			op.seed = int(op.get("seed",0))
		if op.shape == "line":
			var stroke_width: Variant = op.get("width",1)
			if not integer(stroke_width) or stroke_width < 1 or stroke_width > maxi(bounds.size.x,bounds.size.y):
				error = "Line width must be a positive integer within the canvas dimensions."
				return false
			op.width = int(stroke_width)
			if op.width > 1:
				var start := Vector2i(mini(op.x0,op.x1),mini(op.y0,op.y1))
				var end := Vector2i(maxi(op.x0,op.x1),maxi(op.y0,op.y1))
				op.stroke_bounds = Rect2i(start,end-start+Vector2i.ONE).grow(op.width/2).intersection(bounds)
		operations.append(op)
	return true

static func integer(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and floor(float(v))==float(v) and abs(float(v))<=2147483647
static func inside(x: Variant,y: Variant,b: Rect2i) -> bool:
	return x>=b.position.x and y>=b.position.y and x<b.end.x and y<b.end.y

func make_line(op: Dictionary) -> void:
	var x: int = op.x0
	var y: int = op.y0
	var dx: int = absi(op.x1-x)
	var dy: int = -absi(op.y1-y)
	var sx := 1 if x<op.x1 else -1
	var sy := 1 if y<op.y1 else -1
	var e := dx+dy
	while true:
		line.append(Vector2i(x,y))
		if x==op.x1 and y==op.y1: break
		var twice := 2*e
		if twice>=dy: e+=dy; x+=sx
		if twice<=dx: e+=dx; y+=sy

var pending := PackedInt32Array()
var pending_material := -1
var pending_since := 0

func exhausted() -> bool:
	return index >= operations.size() and pending.is_empty()

func next_chunk(capacity: int = 4096) -> Dictionary:
	# Budget candidates, including misses. A thin diagonal can reject nearly
	# its entire bounding box before it fills one native chunk.
	var started := Time.get_ticks_usec()
	var deadline := started+2500
	var visited := 0
	var points := pending
	var material := pending_material
	while index < operations.size() and points.size()/2 < capacity:
		var op: Dictionary = operations[index]
		if not points.is_empty() and op.material != material: break
		material = op.material
		if op.shape == "airbrush" and op.density == 0.0:
			index += 1
			continue
		var total := 0
		var width := 0
		match op.shape:
			"pixels": total = op.points.size()
			"rectangle": width = op.x1-op.x0+1; total = width*(op.y1-op.y0+1)
			"disc","airbrush": width = 2*op.radius+1; total = width*width
			"polygon":
				width = op.polygon_bounds.size.x
				total = width*op.polygon_bounds.size.y
			"line":
				if op.width == 1:
					if line.is_empty(): make_line(op)
					total = line.size()
				else:
					width = op.stroke_bounds.size.x
					total = width*op.stroke_bounds.size.y
		var stroke_start := Vector2.ZERO
		var stroke_end := Vector2.ZERO
		var radius_squared := 0.0
		if op.shape == "line" and op.width > 1:
			stroke_start = Vector2(op.x0,op.y0)
			stroke_end = Vector2(op.x1,op.y1)
			if op.width % 2 == 0:
				var axis := (stroke_end-stroke_start).normalized()
				if axis.x < 0 or (axis.x == 0 and axis.y < 0): axis = -axis
				var offset := Vector2(-axis.y,axis.x)*0.5 if axis != Vector2.ZERO else Vector2(0,0.5)
				stroke_start += offset
				stroke_end += offset
			radius_squared = pow(op.width*0.5,2)
		while cursor < total and points.size()/2 < capacity:
			if (visited & 63) == 0 and visited > 0 and Time.get_ticks_usec() >= deadline:
				# Sparse drawings must show progress without waiting for 4096 hits.
				if not points.is_empty():
					if pending_since == 0: pending_since = started
					if started-pending_since >= 33000:
						pending = PackedInt32Array()
						pending_since = 0
						return {"points":points,"material":material}
				pending = points
				pending_material = material
				return {}
			visited += 1
			var point: Vector2i
			if op.shape == "pixels": point = Vector2i(int(op.points[cursor][0]),int(op.points[cursor][1]))
			elif op.shape == "line":
				if op.width == 1:
					point = line[cursor]
				else:
					# Limit each row to the segment's conservative radius envelope.
					if cursor % width == 0:
						var row_y: int = op.stroke_bounds.position.y + cursor/width
						var radius: float = op.width*0.5
						var dy := stroke_end.y-stroke_start.y
						if dy != 0:
							var a := clampf((row_y-radius-stroke_start.y)/dy,0,1)
							var b := clampf((row_y+radius-stroke_start.y)/dy,0,1)
							var left := minf(lerpf(stroke_start.x,stroke_end.x,a),lerpf(stroke_start.x,stroke_end.x,b))
							cursor += clampi(floori(left-radius)-op.stroke_bounds.position.x,0,width-1)
					point = op.stroke_bounds.position+Vector2i(cursor%width,cursor/width)
					var dy := stroke_end.y-stroke_start.y
					if dy != 0:
						var radius: float = op.width*0.5
						var t := clampf((point.y+radius*signf((stroke_end.x-stroke_start.x)*dy)-stroke_start.y)/dy,0,1)
						if point.x > ceilf(lerpf(stroke_start.x,stroke_end.x,t)+radius):
							cursor += width-cursor%width
							continue
					var closest := stroke_start
					if stroke_start != stroke_end:
						closest = Geometry2D.get_closest_point_to_segment(Vector2(point),stroke_start,stroke_end)
					if Vector2(point).distance_squared_to(closest) >= radius_squared:
						cursor += 1
						continue
			elif op.shape == "polygon": point = op.polygon_bounds.position+Vector2i(cursor%width,cursor/width)
			elif op.shape == "rectangle": point = Vector2i(op.x0+cursor%width,op.y0+cursor/width)
			else: point = Vector2i(op.x-op.radius+cursor%width,op.y-op.radius+cursor/width)
			cursor += 1
			if op.shape == "polygon" and not Geometry2D.is_point_in_polygon(Vector2(point),op.vertices): continue
			if op.shape in ["disc","airbrush"]:
				var distance_squared := point.distance_squared_to(Vector2i(op.x,op.y))
				if distance_squared > op.radius*op.radius: continue
				if op.shape == "airbrush":
					var normalized := sqrt(distance_squared)/maxi(1,op.radius)
					var falloff := 1.0
					if normalized > op.hardness:
						falloff = 1.0-smoothstep(op.hardness,1.0,normalized)
					var sample := float(hash(Vector3i(point.x-op.x,point.y-op.y,op.seed)) & 0xffffff)/16777216.0
					if sample >= op.density*falloff: continue
			points.append(point.x);points.append(point.y)
		if cursor == total: index+=1;cursor=0;line.clear()
	pending = PackedInt32Array()
	pending_since = 0
	if points.is_empty(): return {}
	return {"points":points,"material":material}
