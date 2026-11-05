extends RefCounted

# Bounded developer authoring. All file reads occur at load/reload, never during
# a physics sample. Resolved geometry is copied before a body is constructed.
const MAX_FLYERS: int = 16
const MAX_RECTS: int = 8
const MAX_FILE_BYTES: int = 16384
const LEGACY_IDS: Array[String] = ["midge","needle","kestrel","afterglow","surveyor","cartographer","observatory"]
const RECORD_KEYS: Array[String] = ["schema_version","id","name","description","color","control_mode","markings","capabilities","physics","flight","hull"]
const PHYSICS_KEYS: Array[String] = ["mass","friction","bounce","gravity","angular_drag"]
const FLIGHT_KEYS: Array[String] = ["acceleration","speed","turn_speed","turn_acceleration","throttle_slew","linear_drag","force_limit","torque_limit","attitude_gain","attitude_damping","trim_angle"]
const CAPABILITY_KEYS: Array[String] = ["side_thrusters","reverse_thrust","dispenser_q","dispenser_e","dispenser_s"]

static func _keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size()!=expected.size(): return false
	for key: Variant in value:
		if not key is String or key not in expected: return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func _vector(value: Variant) -> bool:
	return value is Array and value.size()==2 and _number(value[0],-128,128) and _number(value[1],-128,128)

static func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length()>40: return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

static func _color(value: Variant) -> bool:
	if not value is String or value.length()!=6: return false
	for character: String in value.to_lower():
		if character not in "0123456789abcdef": return false
	return true

static func validate_record(value: Variant) -> String:
	if not value is Dictionary or not _keys(value,RECORD_KEYS): return "unknown or missing flyer field"
	if not _number(value.schema_version,1,1) or not _identifier(value.id): return "flyer schema or id"
	if not value.name is String or value.name.is_empty() or value.name.length()>48: return "flyer name"
	if not value.description is String or value.description.length()>256: return "flyer description"
	if not _color(value.color): return "flyer color"
	if value.control_mode not in ["body_thrust","hoverboard"]: return "control mode"
	if value.markings not in ["scout","board","science","scoop"]: return "markings"
	if not value.capabilities is Dictionary or not _keys(value.capabilities,CAPABILITY_KEYS): return "capabilities fields"
	for key: String in ["side_thrusters","reverse_thrust"]:
		if not value.capabilities[key] is bool: return "capability boolean"
	for key: String in ["dispenser_q","dispenser_e","dispenser_s"]:
		if not _number(value.capabilities[key],0,58) or float(value.capabilities[key])!=floorf(float(value.capabilities[key])): return "dispenser material id"
		if int(value.capabilities[key]) not in [0,3,8,12,26]: return "unsupported review dispenser material"
	if not value.physics is Dictionary or not _keys(value.physics,PHYSICS_KEYS): return "physics fields"
	for key: String in PHYSICS_KEYS:
		var high: float=64.0 if key=="mass" else 16.0 if key=="friction" else 1.0 if key=="bounce" else 256.0 if key=="gravity" else 64.0
		if not _number(value.physics[key],0.001 if key=="mass" else 0.0,high): return "physics range: "+key
	if not value.flight is Dictionary or not _keys(value.flight,FLIGHT_KEYS): return "flight fields"
	for key: String in FLIGHT_KEYS:
		var high: float=4096.0 if key in ["force_limit","torque_limit"] else PI if key=="trim_angle" else 24.0 if key=="turn_speed" else 300.0 if key=="speed" else 256.0
		if not _number(value.flight[key],0.0,high): return "flight range: "+key
	if not value.hull is Dictionary: return "hull fields"
	var hull: Dictionary=value.hull
	if hull.get("kind")=="rectangle":
		if not _keys(hull,["kind","size"]) or not _vector(hull.size): return "rectangle fields"
		if float(hull.size[0])<1 or float(hull.size[1])<1: return "rectangle size"
	elif hull.get("kind")=="rect_union":
		if not _keys(hull,["kind","rects"]) or not hull.rects is Array or hull.rects.is_empty() or hull.rects.size()>MAX_RECTS: return "compound fields or capacity"
		var rectangles: Array[Rect2]=[]
		for rectangle: Variant in hull.rects:
			if not rectangle is Array or rectangle.size()!=4: return "compound rectangle fields"
			for scalar: Variant in rectangle:
				if not _number(scalar,-128,128): return "compound rectangle finite range"
			var rect:=Rect2(float(rectangle[0]),float(rectangle[1]),float(rectangle[2]),float(rectangle[3]))
			if rect.size.x<1 or rect.size.y<1: return "compound rectangle size"
			for previous: Rect2 in rectangles:
				if rect.intersects(previous): return "compound rectangles overlap"
			rectangles.append(rect)
		var bounds: Rect2=rectangles[0]
		for rectangle: Rect2 in rectangles: bounds=bounds.merge(rectangle)
		if bounds.size.x>128 or bounds.size.y>128: return "compound bounds"
	else: return "hull kind"
	return ""

static func resolve_record(raw: Dictionary) -> Dictionary:
	var error: String=validate_record(raw)
	if not error.is_empty(): return {"error":error}
	var result: Dictionary=raw.duplicate(true)
	var rectangles: Array[Rect2]=[]
	if raw.hull.kind=="rectangle":
		var size:=Vector2(float(raw.hull.size[0]),float(raw.hull.size[1]))
		rectangles.append(Rect2(-size*0.5,size))
	else:
		for rectangle: Array in raw.hull.rects: rectangles.append(Rect2(float(rectangle[0]),float(rectangle[1]),float(rectangle[2]),float(rectangle[3])))
	var area: float=0.0
	var first_moment:=Vector2.ZERO
	for rectangle: Rect2 in rectangles:
		var parcel: float=rectangle.get_area()
		area+=parcel
		first_moment+=rectangle.get_center()*parcel
	var com: Vector2=first_moment/area
	var inertia_sum: float=0.0
	var geometry: Array[Dictionary]=[]
	var bounds:=Rect2(rectangles[0].position-com,rectangles[0].size)
	for rectangle: Rect2 in rectangles:
		var offset: Vector2=rectangle.get_center()-com
		inertia_sum+=rectangle.get_area()*((rectangle.size.x*rectangle.size.x+rectangle.size.y*rectangle.size.y)/12.0+offset.length_squared())
		geometry.append({"center":offset,"size":rectangle.size})
		bounds=bounds.merge(Rect2(rectangle.position-com,rectangle.size))
	result["resolved_rects"]=geometry
	result["resolved_bounds"]=bounds
	result["resolved_com"]=com
	result["resolved_area"]=area
	result["resolved_inertia"]=float(raw.physics.mass)*inertia_sum/area
	result["definition_hash"]=JSON.stringify(raw,"",true,true).sha256_text()
	return result

static func registry_from_records(records: Array, manifest: String = "") -> Dictionary:
	if records.size()<LEGACY_IDS.size() or records.size()>MAX_FLYERS: return {"error":"flyer population capacity"}
	var entries: Array[Dictionary]=[]
	var seen: Dictionary={}
	var digest: String=""
	for index: int in range(records.size()):
		var entry: Dictionary=resolve_record(records[index]) if records[index] is Dictionary else {"error":"record is not an object"}
		if entry.has("error"): return {"error":"flyer %d: %s" % [index,str(entry.error)]}
		if seen.has(entry.id): return {"error":"duplicate flyer id"}
		if index<LEGACY_IDS.size() and entry.id!=LEGACY_IDS[index]: return {"error":"legacy flyer order changed"}
		seen[entry.id]=true
		digest+=str(entry.id)+":"+str(entry.definition_hash)+"\n"
		entries.append(entry)
	return {"entries":entries,"records":records.duplicate(true),"registry_hash":digest.sha256_text(),"manifest":manifest,"error":""}

static func _json_file(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return {"error":"cannot open "+path}
	if file.get_length()>MAX_FILE_BYTES: return {"error":"authoring file capacity: "+path}
	var parsed: Variant=JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return {"error":"authoring JSON object: "+path}
	return {"value":parsed}

static func load_registry(manifest_path: String) -> Dictionary:
	var manifest_file: Dictionary=_json_file(manifest_path)
	if manifest_file.has("error"): return manifest_file
	var manifest: Dictionary=manifest_file.value
	if not _keys(manifest,["schema_version","flyers"]) or not _number(manifest.schema_version,1,1) or not manifest.flyers is Array or manifest.flyers.size()>MAX_FLYERS: return {"error":"manifest schema or capacity"}
	var records: Array=[]
	for basename: Variant in manifest.flyers:
		if not basename is String or not basename.ends_with(".json") or not _identifier(basename.trim_suffix(".json")): return {"error":"manifest flyer filename"}
		var loaded: Dictionary=_json_file(manifest_path.get_base_dir().path_join(basename))
		if loaded.has("error"): return loaded
		records.append(loaded.value)
	return registry_from_records(records,manifest_path)
