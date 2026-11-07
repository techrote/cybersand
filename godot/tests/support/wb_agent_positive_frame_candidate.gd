extends RefCounted
## EXPERIMENTAL, PURE frame adapter for the unchanged WB-AGENT #527 v2 reference.
## This is not integrated into #526 host/worker or #528 UI. It supplies one
## reversible positive finite World mapping ONLY if the owner accepts the
## independently observed bounded transient trajectory differences.
##
## Model-visible signed logical cell (x,y) -> native World (x+512,y+512).
## Native engine remains the ONLY material authority; task/epoch/render receipts
## must bind FRAME_ID, and all native material/permission checks still apply.

const FRAME_ID: String = "wb-agent-signed-frame-candidate-v1:origin=512,512:extent=2048x2048"
const ORIGIN: Vector2i = Vector2i(512,512)
const EXTENT: Vector2i = Vector2i(2048,2048)
const MAX_PRIMITIVES: int = 8
const MAX_DISC_RADIUS: int = 36
const AUTHOR_MATERIALS: Array[int] = [0,58]


static func _refused(reason: String) -> Dictionary:
	return {"status":"refused","reason":reason}


static func _all_int(value: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not value.has(key) or typeof(value[key]) != TYPE_INT:
			return false
	return true


static func point(x: Variant, y: Variant) -> Dictionary:
	if typeof(x) != TYPE_INT or typeof(y) != TYPE_INT:
		return _refused("non_integer_coordinate")
	# Compare BEFORE addition so no enormous or out-of-range input can wrap
	# during native Vector2i construction.
	if x < -ORIGIN.x or x >= EXTENT.x - ORIGIN.x \
			or y < -ORIGIN.y or y >= EXTENT.y - ORIGIN.y:
		return _refused("outside_translated_finite_extent")
	return {
		"status":"mapped", "native":Vector2i(x + ORIGIN.x,y + ORIGIN.y),
		"frame_id":FRAME_ID
	}


static func region(logical: Variant) -> Dictionary:
	if not logical is Dictionary:
		return _refused("region_not_object")
	var r: Dictionary = logical
	if not _all_int(r,["x","y","width","height"]) or r.size()!=4:
		return _refused("malformed_integer_region")
	var w: int = r["width"]
	var h: int = r["height"]
	if w <= 0 or h <= 0 or w > EXTENT.x or h > EXTENT.y:
		return _refused("invalid_region_dimensions")
	var x: int = r["x"]
	var y: int = r["y"]
	# Validate far edge BEFORE adding origin; nothing is silently clipped.
	if x < -ORIGIN.x or y < -ORIGIN.y \
			or x > EXTENT.x - ORIGIN.x - w \
			or y > EXTENT.y - ORIGIN.y - h:
		return _refused("region_crosses_translated_extent")
	return {
		"status":"mapped",
		"native":Rect2i(x + ORIGIN.x,y + ORIGIN.y,w,h),
		"logical":Rect2i(x,y,w,h),
		"frame_id":FRAME_ID
	}


static func regions(regions_value: Variant) -> Dictionary:
	if not regions_value is Array:
		return _refused("protected_not_array")
	var out: Array = []
	for item: Variant in regions_value:
		var result: Dictionary = region(item)
		if result.status != "mapped":
			return result
		out.append(result.native)
	return {"status":"mapped","native":out,"frame_id":FRAME_ID}


static func operations(ops: Variant) -> Dictionary:
	if not ops is Array or ops.is_empty() or ops.size() > MAX_PRIMITIVES:
		return _refused("invalid_primitive_count")
	var out: Array = []
	for raw: Variant in ops:
		if not raw is Dictionary:
			return _refused("operation_not_object")
		var op: Dictionary = raw
		if not op.has("shape") or typeof(op.shape) != TYPE_STRING \
				or not _all_int(op,["material"]):
			return _refused("malformed_operation")
		if int(op.material) not in AUTHOR_MATERIALS:
			return _refused("only_empty_and_hard_wall_permitted")
		var keys: Array = ["shape","material","replace_only_material"]
		var mandatory: Array = []
		match op.shape:
			"disc":
				mandatory = ["x","y","radius"]
			"line","rectangle":
				mandatory = ["x0","y0","x1","y1"]
			_:
				return _refused("unsupported_shape")
		keys.append_array(mandatory)
		for key: Variant in op.keys():
			if key not in keys:
				return _refused("unknown_operation_field")
		if not _all_int(op,mandatory):
			return _refused("non_integer_operation")
		if op.has("replace_only_material"):
			if typeof(op.replace_only_material)!=TYPE_INT \
					or int(op.replace_only_material) not in AUTHOR_MATERIALS:
				return _refused("invalid_replace_filter")
		var mapped: Dictionary = {"shape":op.shape,"material":op.material}
		if op.has("replace_only_material"):
			mapped["replace_only_material"]=op.replace_only_material
		if op.shape == "disc":
			var radius: int = op["radius"]
			if radius<0 or radius>MAX_DISC_RADIUS:
				return _refused("disc_radius_exceeds_budget")
			var center: Dictionary = point(op["x"],op["y"])
			if center.status != "mapped":
				return center
			var c: Vector2i = center.native
			if c.x < radius or c.y < radius \
					or c.x + radius >= EXTENT.x or c.y + radius >= EXTENT.y:
				return _refused("disc_crosses_translated_extent")
			mapped["x"]=c.x
			mapped["y"]=c.y
			mapped["radius"]=radius
		else:
			if op.shape=="rectangle" and \
					(op["x1"] < op["x0"] or op["y1"] < op["y0"]):
				return _refused("reversed_rectangle")
			var a: Dictionary = point(op["x0"],op["y0"])
			var b: Dictionary = point(op["x1"],op["y1"])
			if a.status != "mapped":
				return a
			if b.status != "mapped":
				return b
			mapped["x0"]=a.native.x
			mapped["y0"]=a.native.y
			mapped["x1"]=b.native.x
			mapped["y1"]=b.native.y
		out.append(mapped)
	# The authoritative #526 raster compiler STILL must enforce <=4096
	# distinct cells, source-ID filters, protection, pending revision and
	# actual native readback after this lossless spatial conversion.
	return {"status":"mapped","native":out,"frame_id":FRAME_ID}


static func readback_to_logical(native_rows: Variant) -> Dictionary:
	if not native_rows is Array or native_rows.size()>4096:
		return _refused("invalid_readback_length")
	var rows: Array = []
	for raw: Variant in native_rows:
		if not raw is Dictionary or not _all_int(raw,["x","y"]):
			return _refused("invalid_native_readback")
		var logical: Dictionary = raw.duplicate(true)
		var p: Vector2i = Vector2i(int(raw.x),int(raw.y))
		if p.x < 0 or p.y < 0 or p.x >= EXTENT.x or p.y >= EXTENT.y:
			return _refused("native_readback_outside_extent")
		logical["x"] = p.x - ORIGIN.x
		logical["y"] = p.y - ORIGIN.y
		rows.append(logical)
	return {"status":"mapped","logical":rows,"frame_id":FRAME_ID}
