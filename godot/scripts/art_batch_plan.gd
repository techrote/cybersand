extends RefCounted
## Lazy exact geometry; only a native-sized chunk is materialized at a time.
var operations: Array = []
var index := 0
var cursor := 0
var line: Array[Vector2i] = []
var error := ""

func configure(value: Variant, bounds: Rect2i) -> bool:
	if not value is Array or value.is_empty(): error = "Use a nonempty JSON array of drawing operations."; return false
	for raw: Variant in value:
		if not raw is Dictionary or raw.get("shape") not in ["rectangle","disc","line","pixels"]: error = "Shapes: rectangle, disc, line, pixels."; return false
		var op: Dictionary = raw.duplicate(true)
		if not integer(op.get("material")) or int(op.material) not in [0,58]: error = "Material must be 0 (erase) or 58 (Hard Wall)."; return false
		op.material = int(op.material)
		var keys: Array = ["x","y","radius"] if op.shape == "disc" else ["x0","y0","x1","y1"]
		if op.shape == "pixels":
			if not op.get("points") is Array or op.points.is_empty(): error = "pixels needs points:[[x,y],...]."; return false
			for pair: Variant in op.points:
				if not pair is Array or pair.size()!=2 or not integer(pair[0]) or not integer(pair[1]): error = "Pixel coordinates must be integers."; return false
				if not inside(pair[0],pair[1],bounds): error = "Pixel outside canvas."; return false
		else:
			for key: String in keys:
				if not integer(op.get(key)): error = "Missing integer: "+key; return false
				op[key] = int(op[key])
			if op.shape == "disc":
				if op.radius < 0 or op.radius > maxi(bounds.size.x,bounds.size.y) or not inside(op.x-op.radius,op.y-op.radius,bounds) or not inside(op.x+op.radius,op.y+op.radius,bounds): error = "Disc outside canvas."; return false
			elif not inside(op.x0,op.y0,bounds) or not inside(op.x1,op.y1,bounds) or (op.shape == "rectangle" and (op.x1<op.x0 or op.y1<op.y0)): error = "Invalid or outside rectangle/line."; return false
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

func next_chunk(capacity: int = 4096) -> Dictionary:
	while index < operations.size():
		var op: Dictionary = operations[index]
		var points := PackedInt32Array()
		var total := 0
		var width := 0
		match op.shape:
			"pixels": total = op.points.size()
			"rectangle": width = op.x1-op.x0+1; total = width*(op.y1-op.y0+1)
			"disc": width = 2*op.radius+1; total = width*width
			"line":
				if line.is_empty(): make_line(op)
				total = line.size()
		while cursor < total and points.size()/2 < capacity:
			var point: Vector2i
			if op.shape == "pixels": point = Vector2i(int(op.points[cursor][0]),int(op.points[cursor][1]))
			elif op.shape == "line": point = line[cursor]
			elif op.shape == "rectangle": point = Vector2i(op.x0+cursor%width,op.y0+cursor/width)
			else: point = Vector2i(op.x-op.radius+cursor%width,op.y-op.radius+cursor/width)
			cursor += 1
			if op.shape == "disc" and point.distance_squared_to(Vector2i(op.x,op.y)) > op.radius*op.radius: continue
			points.append(point.x);points.append(point.y)
		if cursor == total: index+=1;cursor=0;line.clear()
		if not points.is_empty(): return {"points":points,"material":op.material}
	return {}
