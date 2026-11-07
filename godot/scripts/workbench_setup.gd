extends RefCounted

# A starting construction recipe. Native runtime state and command leases are never serialized.
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const CanvasBody = preload("res://scripts/workbench_canvas_body.gd")
const BARREL := "reference_barrel"
const RESPONSES := ["LA-SELECTIVE", "LA", "LA-EVENT-OFF", "RFT"]
const MATERIALS := [2,14,29,13,19,23,25,26,27,3,58,0,43]
const MATERIAL_NAMES := ["Sand","Dust","Rust","Stone","Seed","Salt","Sodium","Gunpowder","Coal","Water","Hard wall","Erase","RedBrick"]
const MAX_BODIES := 8
const MAX_RUNS := 4096
const MAX_STAMPS := 2048
const DIRECTORY := "user://workbench"
const BYTE_LIMIT := 1024 * 1024
const DEFAULT_OPTIONS := {"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
	"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
const ROOT_KEYS := ["version","extent","actors","next_id","selected","edits","response","liquid_policy",
	"normalize","rule_radius","source","material","brush","fire"]

static func fresh(policy: PackedInt32Array, extent := Vector2i(2048,2048)) -> Dictionary:
	return {"version":2,"extent":[extent.x,extent.y],"actors":[],"next_id":1,"selected":0,"edits":[],
		"response":"LA-SELECTIVE","liquid_policy":Array(policy),"normalize":false,"rule_radius":2,
		"source":[],"material":2,"brush":8,"fire":false}

static func instance(model: String, id: int, pos: Vector2) -> Dictionary:
	var index := Fleet.index_for_id(model)
	return {"id":id,"model":model,"hash":Fleet.definition_hash(index) if index >= 0 else "reference-barrel-v1",
		"spawn":[pos.x,pos.y],"options":DEFAULT_OPTIONS.duplicate()}

static func extent_of(setup: Dictionary) -> Vector2i:
	return Vector2i(int(setup.extent[0]),int(setup.extent[1]))

static func point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1]))

static func bounds(model: String) -> Rect2:
	return Rect2(-4,-7,8,14) if model == BARREL else Fleet.bounds(Fleet.index_for_id(model))

static func actor_bounds(actor: Dictionary) -> Rect2:
	return CanvasBody.definition(actor.body).bounds if actor.model==CanvasBody.MODEL else bounds(str(actor.model))

static func _keys(obj: Variant, fields: Array) -> bool:
	return obj is Dictionary and obj.size() == fields.size() and obj.has_all(fields)

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= low and value <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and floor(value) == value

static func _actor_error(a: Variant, size: Vector2i, response: String, canvas_bodies: bool = false) -> String:
	var custom: bool = a is Dictionary and a.get("model") == CanvasBody.MODEL
	var fields: Array = ["id","model","hash","spawn","options"]
	if custom: fields.append("body")
	if not _keys(a,fields) or not _integer(a.id,1,2147483646) or not a.model is String:
		return "Invalid actor fields or instance ID."
	var model := str(a.model)
	var index := Fleet.index_for_id(model)
	if custom:
		if not canvas_bodies or not CanvasBody.error(a.body).is_empty(): return "Invalid file-local passive body."
	elif model != BARREL and index < 0:
		return "Unavailable actor definition: " + model
	if a.hash != (CanvasBody.digest(a.body) if custom else (Fleet.definition_hash(index) if index >= 0 else "reference-barrel-v1")):
		return "Definition changed for " + model + ". Reload definitions or use its original authoring records."
	if not a.spawn is Array or a.spawn.size() != 2 or not _number(a.spawn[0],0,size.x) or not _number(a.spawn[1],0,size.y):
		return "Invalid saved spawn."
	var body_bounds: Rect2 = CanvasBody.definition(a.body).bounds if custom else bounds(model)
	body_bounds.position += point(a.spawn)
	if not Rect2(Vector2.ZERO,Vector2(size)).encloses(body_bounds):
		return "Place the whole body inside the canvas."
	if not _keys(a.options,DEFAULT_OPTIONS.keys()):
		return "Missing or unknown body settings."
	for key: String in DEFAULT_OPTIONS:
		var low := 5.0 if key == "budget" else (1.0 if key == "boost_multiplier" else (0.01 if key in ["mass_multiplier","inertia_multiplier"] else 0.0))
		var high := 80.0 if key == "budget" else (8.0 if key == "boost_multiplier" else 64.0)
		if not _number(a.options[key],low,high):
			return "Body setting outside admission: " + key
	if response == "RFT" and a.options.budget != 20.0:
		return "RFT requires a budget of 20 on every body."
	return ""

static func _material(value: Variant, powders_only := false) -> bool:
	return _integer(value,0,255) and int(value) in (MATERIALS.slice(0,9) if powders_only else MATERIALS)

static func validate(value: Variant, check_starting_paint: bool = true) -> String:
	if not _keys(value,ROOT_KEYS) or not _integer(value.version,2,4):
		return "Unsupported starting setup format."
	if not value.extent is Array or value.extent.size() != 2:
		return "Invalid canvas extent."
	for side: Variant in value.extent:
		if not _integer(side,512,2048) or int(side) % 64 != 0:
			return "Each canvas side must be 512–2048 cells in multiples of 64."
	var size := extent_of(value)
	if value.response not in RESPONSES or not value.normalize is bool or not value.fire is bool:
		return "Invalid response, normalization or fire setting."
	if not _integer(value.rule_radius,2,3) or not _integer(value.brush,2,24) or not _material(value.material):
		return "Invalid brush, material or execution radius."
	if not value.actors is Array or value.actors.size() > MAX_BODIES or not _integer(value.next_id,1,2147483647):
		return "Up to eight independent bodies fit in the physical session."
	var ids := {}
	for a: Variant in value.actors:
		var error := _actor_error(a,size,str(value.response),int(value.version)>=3)
		if not error.is_empty(): return error
		if ids.has(int(a.id)) or a.id >= value.next_id: return "Duplicate or retired instance ID."
		ids[int(a.id)] = true
	if not _integer(value.selected,0,2147483646) or (value.selected != 0 and not ids.has(int(value.selected))):
		return "Selected instance does not exist."
	if not value.edits is Array: return "Invalid starting paint history."
	if check_starting_paint:
		if value.edits.size() > MAX_STAMPS: return "Starting paint capacity exhausted."
		for stamp: Variant in value.edits:
			if int(value.version)>=4 and stamp is Array and stamp.size()==5:
				if not _integer(stamp[0],0,size.x-1) or not _integer(stamp[1],0,size.y-1) or not _integer(stamp[2],1,size.x-int(stamp[0])) or not _integer(stamp[3],1,size.y-int(stamp[1])) or not _material(stamp[4]): return "Invalid rectangular stamp."
				continue
			if not stamp is Array or stamp.size() != 4 or not _integer(stamp[0],0,size.x-1) or not _integer(stamp[1],0,size.y-1) or not _integer(stamp[2],2,24) or not _material(stamp[3]):
				return "Invalid brush stamp."
	if not value.source is Array or (not value.source.is_empty() and (value.source.size() != 3 or not _integer(value.source[0],0,size.x-4) or not _integer(value.source[1],0,size.y-24) or not _material(value.source[2],true))):
		return "Place the entire 4 × 24 powder source inside the canvas."
	if not value.liquid_policy is Array or value.liquid_policy.is_empty() or value.liquid_policy.size() > 4096:
		return "Invalid liquid policy envelope."
	for word: Variant in value.liquid_policy:
		if not _integer(word,-2147483648,2147483647): return "Invalid liquid policy word."
	return ""

static func physical_definitions(setup: Dictionary) -> Array:
	var result := []
	for actor: Dictionary in setup.actors:
		var options: Dictionary = actor.options.duplicate()
		options.response = setup.response
		var item := {"model":actor.model,"instance_id":int(actor.id),"producer":"passive" if actor.model in [BARREL,CanvasBody.MODEL] else "human",
			"position":point(actor.spawn),"workbench_options":options,"canvas_extent":extent_of(setup)}
		if actor.model==CanvasBody.MODEL:item["canvas_body"]=actor.body.duplicate(true)
		result.append(item)
	return result

# Discs use the same integer circle and clipped extent as native paint_disc.
# Exact last-write-wins spans, independent of painted area. Empty writes remove
# coverage; the run budget applies only to the final recipe, as before.
static func _write_span(rows: Dictionary, y: int, left: int, right: int, material: int) -> void:
	var output: Array[Vector3i]=[]
	var inserted: bool=false
	for span: Vector3i in rows.get(y,[]):
		if span.y<=left: output.append(span);continue
		if not inserted:
			if span.x<left: output.append(Vector3i(span.x,left,span.z))
			if material!=0: output.append(Vector3i(left,right,material))
			inserted=true
		if span.x>=right: output.append(span)
		elif span.y>right: output.append(Vector3i(right,span.y,span.z))
	if not inserted and material!=0: output.append(Vector3i(left,right,material))
	var merged: Array[Vector3i]=[]
	for span: Vector3i in output:
		if not merged.is_empty() and merged.back().y==span.x and merged.back().z==span.z:
			merged[-1]=Vector3i(merged.back().x,span.y,span.z)
		else: merged.append(span)
	if merged.is_empty(): rows.erase(y)
	else: rows[y]=merged

static func rectangles(setup: Dictionary) -> Dictionary:
	var size := extent_of(setup)
	var rows := {}
	for stamp: Array in setup.edits:
		var x := int(stamp[0])
		var y := int(stamp[1])
		if stamp.size()==5:
			for row_y: int in range(y,y+int(stamp[3])):
				_write_span(rows,row_y,x,x+int(stamp[2]),int(stamp[4]))
			continue
		var radius := int(stamp[2])
		for dy: int in range(maxi(-radius,-y),mini(radius,size.y-1-y)+1):
			var half := floori(sqrt(radius*radius-dy*dy))
			_write_span(rows,y+dy,maxi(0,x-half),mini(size.x,x+half+1),int(stamp[3]))
	var runs := []
	var row_keys := rows.keys()
	row_keys.sort()
	for y: int in row_keys:
		for span: Vector3i in rows[y]:
			if runs.size() >= MAX_RUNS*5: return {"error":"Starting terrain exceeds 4096 horizontal runs."}
			runs.append_array([span.x,y,span.y-span.x,1,span.z])
	return {"runs":runs}


static func _path(label: String) -> String:
	if label.is_empty() or label.length() > 48:
		return ""
	for character: String in label:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":
			return ""
	return DIRECTORY + "/setup-" + label + ".json"

static func write_named(label: String, setup: Dictionary) -> String:
	var path := _path(label)
	if path.is_empty():
		return "Use 1–48 letters, digits, underscores or hyphens for the setup name."
	var error := validate(setup)
	if not error.is_empty():
		return error
	var content := JSON.stringify(setup)
	if content.to_utf8_buffer().size() > BYTE_LIMIT:
		return "Setup exceeds the file budget."
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		return "Cannot create the setup directory."
	var temp := path + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "Cannot create temporary setup file."
	file.store_string(content)
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(temp,path)
	if result != OK:
		DirAccess.remove_absolute(temp)
		return "Could not replace the named setup (%s)." % error_string(result)
	return ""

static func read_named(label: String) -> Dictionary:
	var path := _path(label)
	if path.is_empty():
		return {"error":"Invalid setup name."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error":"Named setup could not be opened."}
	if file.get_length() > BYTE_LIMIT:
		return {"error":"Setup exceeds the file budget."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error":"Invalid setup JSON at line %d." % parser.get_error_line()}
	var reason := validate(parser.data)
	if not reason.is_empty(): return {"error":reason}
	# JSON numbers decode as floats. Canonicalize integer fields only after
	# strict validation, before any identity or palette lookup by the host.
	var setup_data: Dictionary = parser.data
	for key: String in ["version","next_id","selected","rule_radius","material","brush"]:
		setup_data[key] = int(setup_data[key])
	for key: String in ["extent","source","liquid_policy"]:
		setup_data[key] = Array(PackedInt32Array(setup_data[key]))
	for i: int in setup_data.edits.size():
		setup_data.edits[i] = Array(PackedInt32Array(setup_data.edits[i]))
	for a: Dictionary in setup_data.actors:
		a.id = int(a.id)
	return {"setup":setup_data}
