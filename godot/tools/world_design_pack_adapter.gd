extends RefCounted
# Presentation-only pack -> immutable native-ID/condition RG8 adapter.
# No World writes, material colour approximations, simulation, or clipping.
# Coordinate and last-write-wins contracts: docs/world-design/README.md (#454).
const MATERIAL_COUNT: int = 132
const MAX_SIDE: int = 16384
const MAX_CELLS: int = 16777216
# Grounded in tests/capture_material_review.gd and native material creation states.
const INITIAL_CONDITION: Dictionary = {
	3: 255, 4: 240, 6: 240, 11: 32, 12: 255, 15: 1,
	18: 32, 22: 180, 30: 180, 34: 12, 37: 120,
}
const SYNTHETIC_MOLTEN_GLASS_HEAT: int = 200


static func condition_for(material_id: int) -> int:
	if material_id == 36:
		return SYNTHETIC_MOLTEN_GLASS_HEAT
	return int(INITIAL_CONDITION.get(material_id, 0))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _integer(value: Variant) -> bool:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return false
	var v: float = float(value)
	return not is_nan(v) and not is_inf(v) and absf(v) <= 2147483647.0 and v == float(int(v))


static func _size(value: Variant) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return Vector2i.ZERO
	if not _integer(value[0]) or not _integer(value[1]):
		return Vector2i.ZERO
	var size: Vector2i = Vector2i(int(value[0]), int(value[1]))
	if size.x <= 0 or size.y <= 0 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		return Vector2i.ZERO
	if size.x * size.y > MAX_CELLS:
		return Vector2i.ZERO
	return size


static func _material(value: Variant) -> bool:
	if not _integer(value):
		return false
	var material_id: int = int(value)
	# 10 is native Invalid/Reserved, deliberately magenta in the LUT.
	return material_id >= 0 and material_id < MATERIAL_COUNT and material_id != 10


static func _rectangle_error(rectangle: Variant, size: Vector2i) -> String:
	if typeof(rectangle) != TYPE_ARRAY or rectangle.size() != 5:
		return "expected [x,y,width,height,material_id]"
	for i: int in range(5):
		if not _integer(rectangle[i]):
			return "rectangle component %d is not an integer" % i
	var x: int = int(rectangle[0])
	var y: int = int(rectangle[1])
	var width: int = int(rectangle[2])
	var height: int = int(rectangle[3])
	if x < 0 or y < 0 or width <= 0 or height <= 0:
		return "negative origin or non-positive extent"
	if x > size.x or y > size.y or width > size.x - x or height > size.y - y:
		return "rectangle exceeds declared bounds %s" % str(size)
	if not _material(rectangle[4]):
		return "material ID %s is not a valid native material" % str(rectangle[4])
	return ""


static func _check_rectangles(rectangles: Variant, size: Vector2i, label: String) -> String:
	if typeof(rectangles) != TYPE_ARRAY:
		return "%s must be a rectangle array" % label
	for i: int in range(rectangles.size()):
		var error: String = _rectangle_error(rectangles[i], size)
		if not error.is_empty():
			return "%s rectangle %d: %s" % [label, i, error]
	return ""


static func _variant_id(value: Variant) -> String:
	if value == null:
		return ""
	if typeof(value) != TYPE_STRING:
		return "<invalid-type>"
	if value == "" or value == "base" or value == "default":
		return ""
	return value


static func _variants_error(feature: Dictionary) -> String:
	var variants: Variant = feature.get("variants", [])
	if typeof(variants) != TYPE_ARRAY:
		return "variants must be an array"
	var seen: Dictionary = {}
	for variant: Variant in variants:
		if typeof(variant) != TYPE_DICTIONARY or typeof(variant.get("id")) != TYPE_STRING:
			return "variant must have a string id"
		var key: String = variant["id"]
		if key.is_empty() or key == "base" or key == "default" or seen.has(key):
			return "duplicate/reserved variant ID " + key
		seen[key] = true
		var swap: Variant = variant.get("swap", {})
		if typeof(swap) != TYPE_DICTIONARY:
			return "variant %s swap must be a dictionary" % key
		for origin: Variant in swap:
			if typeof(origin) != TYPE_STRING or not String(origin).is_valid_int():
				return "variant %s swap key is not a decimal native ID" % key
			if not _material(int(origin)) or not _material(swap[origin]):
				return "variant %s swaps to/from an invalid native ID" % key
	return ""


static func inspect(pack: Variant) -> Dictionary:
	if typeof(pack) != TYPE_DICTIONARY:
		return _failure("top-level pack must be an object")
	var has_scene: bool = pack.has("scene")
	var has_combined: bool = pack.has("combined_scene")
	if has_scene == has_combined:
		return _failure("exactly one of scene or combined_scene is required")
	var family: String = "scene" if has_scene else "combined_scene"
	var scene: Variant = pack[family]
	if typeof(scene) != TYPE_DICTIONARY:
		return _failure("%s must be an object" % family)
	var size: Vector2i = _size(scene.get("size"))
	if size == Vector2i.ZERO:
		return _failure("%s.size must be positive integer dimensions (max %d cells)" % [family, MAX_CELLS])
	if scene.has("rectangles") and scene.has("terrain_rectangles"):
		return _failure("ambiguous scene: both rectangles and terrain_rectangles are present")
	var terrain: Variant = scene.get("rectangles", scene.get("terrain_rectangles", []))
	var error: String = _check_rectangles(terrain, size, "%s terrain" % family)
	if not error.is_empty():
		return _failure(error)
	var raw_features: Variant = pack.get("features")
	if typeof(raw_features) != TYPE_ARRAY or raw_features.is_empty():
		return _failure("features must be a non-empty array")
	var features: Dictionary = {}
	for feature: Variant in raw_features:
		if typeof(feature) != TYPE_DICTIONARY:
			return _failure("feature must be an object")
		var feature_id: Variant = feature.get("id")
		if typeof(feature_id) != TYPE_STRING or not String(feature_id).is_valid_filename() or String(feature_id).is_empty() or String(feature_id) in [".", ".."] or "/" in String(feature_id) or "\\" in String(feature_id):
			return _failure("feature ID must be a safe nonempty filename")
		if features.has(feature_id):
			return _failure("duplicate feature ID: " + feature_id)
		var feature_size: Vector2i = _size(feature.get("size"))
		if feature_size == Vector2i.ZERO:
			return _failure("feature %s has invalid size" % feature_id)
		error = _check_rectangles(feature.get("rectangles"), feature_size, "feature " + feature_id)
		if not error.is_empty():
			return _failure(error)
		error = _variants_error(feature)
		if not error.is_empty():
			return _failure("feature %s: %s" % [feature_id, error])
		features[feature_id] = feature
	var placements: Variant = scene.get("placements")
	if typeof(placements) != TYPE_ARRAY:
		return _failure("%s.placements must be an array" % family)
	var normalized: Array[Dictionary] = []
	for i: int in range(placements.size()):
		var placement: Variant = placements[i]
		if typeof(placement) != TYPE_DICTIONARY:
			return _failure("placement %d must be an object" % i)
		var feature_id: Variant = placement.get("feature" if has_scene else "feature_id")
		if typeof(feature_id) != TYPE_STRING or not features.has(feature_id):
			return _failure("placement %d references missing feature %s" % [i, str(feature_id)])
		var origin: Vector2i
		if has_scene:
			if not _integer(placement.get("x")) or not _integer(placement.get("y")):
				return _failure("placement %d requires integer x/y" % i)
			origin = Vector2i(int(placement["x"]), int(placement["y"]))
		else:
			var origin_array: Variant = placement.get("origin")
			if typeof(origin_array) != TYPE_ARRAY or origin_array.size() != 2:
				return _failure("placement %d requires origin=[x,y]" % i)
			if not _integer(origin_array[0]) or not _integer(origin_array[1]):
				return _failure("placement %d origin must contain integers" % i)
			origin = Vector2i(int(origin_array[0]), int(origin_array[1]))
		var feature_size: Vector2i = _size(features[feature_id]["size"])
		if origin.x < 0 or origin.y < 0 or origin.x > size.x - feature_size.x or origin.y > size.y - feature_size.y:
			return _failure("placement %d feature %s exceeds combined scene bounds" % [i, feature_id])
		var variant: String = _variant_id(placement.get("variant"))
		if variant == "<invalid-type>":
			return _failure("placement %d variant must be string or null" % i)
		if not variant.is_empty() and not _has_variant(features[feature_id], variant):
			return _failure("placement %d has unknown variant %s for %s" % [i, variant, feature_id])
		normalized.append({"feature": feature_id, "origin": [origin.x, origin.y], "variant": variant})
	# baseline_y is documentation, not terrain or a destructive clearing operation.
	return {"ok": true, "family": family, "scene": scene, "size": size,
		"features": features, "terrain": terrain, "placements": normalized}


static func _has_variant(feature: Dictionary, variant_id: String) -> bool:
	for variant: Dictionary in feature.get("variants", []):
		if variant["id"] == variant_id:
			return true
	return false


static func _swap(feature: Dictionary, variant_id: String) -> Dictionary:
	if variant_id.is_empty():
		return {}
	for variant: Dictionary in feature.get("variants", []):
		if variant["id"] == variant_id:
			return variant.get("swap", {})
	return {}


static func _blank(size: Vector2i) -> PackedByteArray:
	var data: PackedByteArray = PackedByteArray()
	data.resize(size.x * size.y * 2)
	# New bytes are 0: both Empty ID and zero condition, not implicit terrain.
	return data


static func _stamp(data: PackedByteArray, width: int, rect: Array, offset: Vector2i,
		swap: Dictionary = {}) -> void:
	var material_id: int = int(swap.get(str(int(rect[4])), int(rect[4])))
	var condition: int = condition_for(material_id)
	var x: int = int(rect[0]) + offset.x
	var y: int = int(rect[1]) + offset.y
	for yy: int in range(y, y + int(rect[3])):
		var index: int = (yy * width + x) * 2
		for xx: int in range(int(rect[2])):
			data[index] = material_id
			data[index + 1] = condition
			index += 2


static func _hash(data: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


static func _result(size: Vector2i, data: PackedByteArray, geometry: Dictionary) -> Dictionary:
	return {"ok": true, "size": size, "data": data, "rg8_sha256": _hash(data),
		"rg8_bytes": data.size(), "geometry": geometry}


static func build_combined(pack: Variant) -> Dictionary:
	var info: Dictionary = inspect(pack)
	if not info.ok:
		return info
	var size: Vector2i = info["size"]
	var data: PackedByteArray = _blank(size)
	for rectangle: Array in info.terrain:
		_stamp(data, size.x, rectangle, Vector2i.ZERO)
	var applied: int = info.terrain.size()
	var placements: Array[Dictionary] = []
	for placement: Dictionary in info.placements:
		var feature: Dictionary = info.features[placement.feature]
		var offset: Vector2i = Vector2i(placement.origin[0], placement.origin[1])
		var swap: Dictionary = _swap(feature, placement.variant)
		for rectangle: Array in feature.rectangles:
			_stamp(data, size.x, rectangle, offset, swap)
			applied += 1
		placements.append({"feature": placement.feature, "origin": placement.origin,
			"variant": placement.variant, "swap": swap,
			"rectangles": feature.rectangles.size()})
	return _result(size, data, {"family": info.family, "scene": info.scene.get("id", ""),
		"terrain_rectangles": info.terrain.size(), "applied_rectangles": applied,
		"placements": placements, "baseline_y_instantiated": false,
		"overlap_semantics": "ordered last-write-wins, including explicit ID 0"})


static func build_feature(pack: Variant, feature_id: String, variant_id: Variant = null) -> Dictionary:
	var info: Dictionary = inspect(pack)
	if not info.ok:
		return info
	if not info.features.has(feature_id):
		return _failure("missing feature: " + feature_id)
	var feature: Dictionary = info.features[feature_id]
	var variant: String = _variant_id(variant_id)
	if variant == "<invalid-type>" or (not variant.is_empty() and not _has_variant(feature, variant)):
		return _failure("unknown variant %s for %s" % [str(variant_id), feature_id])
	var size: Vector2i = _size(feature["size"])
	var data: PackedByteArray = _blank(size)
	var swap: Dictionary = _swap(feature, variant)
	for rectangle: Array in feature.rectangles:
		_stamp(data, size.x, rectangle, Vector2i.ZERO, swap)
	return _result(size, data, {"family": "feature", "feature": feature_id,
		"variant": variant, "swap": swap, "applied_rectangles": feature.rectangles.size(),
		"overlap_semantics": "ordered last-write-wins, including explicit ID 0"})
