extends RefCounted
## M3 material-only native modules. This codec/compiler cannot access a World.
## A stored source receipt is provenance, not fresh native admission or physics.
const FORMAT := "cybersand-native-module-v1"
const FORMAT_V2 := "cybersand-native-module-v2"
const ENCODING := "uint16-le-row-major"
const MAX_SIDE := 512
const MAX_CELLS := 262144
const MAX_BYTES := 2*1024*1024
const MAX_METADATA_BYTES := 256*1024
const MAX_CONTACT_CELLS := 8192
const TRANSFORMS := ["identity","mirror_x","mirror_y","rotate_90","rotate_180","rotate_270"]
const PART_TYPES := ["column_support","beam_truss","floor_ceiling","viaduct_segment",
	"wall_facade","window_door","passage_clearance","mechanical_housing","pipework",
	"service_gallery","greeble_cluster","irregular_transition","unclassified"]
const ROOT_KEYS := ["format","id","name","tags","part_type","extent","anchor","geometry",
	"allowed_transforms","attachments","clearances","protected_regions","roles",
	"variation_regions","provenance","recipe","design_card_ids","content_sha256"]
const SECRET_KEYS := ["key","api_key","apikey","credential","credentials","authorization",
	"token","access_token","password","secret"]

static func failure(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and floor(float(value))==float(value) and abs(float(value))<=2147483647

static func canonical(value: Variant) -> Variant:
	if value is StringName: return str(value)
	# JSON parses numbers as double. Native object IDs can occupy signed 64 bits;
	# preserve those provenance identities as decimal text before hashing/saving.
	if value is int and (value>9007199254740991 or value< -9007199254740991): return "i64:"+str(value)
	if value is float and is_finite(value) and floor(value)==value and abs(value)<=9007199254740991: return int(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(canonical(item))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key) if key is StringName else key] = canonical(value[key])
		return result
	return value

static func json_bytes(value: Variant) -> PackedByteArray:
	return JSON.stringify(canonical(value),"",true,true).to_utf8_buffer()

static func content_digest(module: Dictionary) -> String:
	var copy := module.duplicate(true)
	copy.erase("content_sha256")
	return digest(json_bytes(copy))

static func _keys(value: Dictionary, required: Array, optional: Array = []) -> bool:
	if not value.has_all(required): return false
	for key: Variant in value:
		if not key is String or (key not in required and key not in optional): return false
	return true

static func _text(value: Variant, maximum: int, empty := false) -> bool:
	return value is String and value.length()<=maximum and (empty or not value.strip_edges().is_empty())

static func identifier(value: Variant) -> bool:
	if not _text(value,64): return false
	for character: String in value:
		if not (character>="a" and character<="z") and not (character>="0" and character<="9") and character not in ["_","-"]: return false
	return true

static func _strings(value: Variant, count: int, length: int) -> bool:
	if not value is Array or value.size()>count: return false
	var seen := {}
	for item: Variant in value:
		if not _text(item,length) or seen.has(item): return false
		seen[item] = true
	return true

static func _pair(value: Variant) -> bool:
	return value is Array and value.size()==2 and integer(value[0]) and integer(value[1])

static func rect(value: Variant) -> Rect2i:
	if value is Rect2i: return value
	if not value is Array or value.size()!=4: return Rect2i()
	for number: Variant in value:
		if not integer(number): return Rect2i()
	return Rect2i(int(value[0]),int(value[1]),int(value[2]),int(value[3]))

static func _point(value: Variant, extent: Vector2i) -> bool:
	return _pair(value) and Rect2i(Vector2i.ZERO,extent).has_point(Vector2i(int(value[0]),int(value[1])))

static func _hex(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if not (character>="0" and character<="9") and not (character>="a" and character<="f"): return false
	return true

static func _safe_json(value: Variant, depth := 0) -> bool:
	if depth>12: return false
	if value==null or value is bool or value is int: return true
	if value is float: return is_finite(value)
	if value is String or value is StringName: return str(value).length()<=65536
	if value is Array:
		if value.size()>32768: return false
		for item: Variant in value:
			if not _safe_json(item,depth+1): return false
		return true
	if value is Dictionary:
		if value.size()>256: return false
		for key: Variant in value:
			if not (key is String or key is StringName) or str(key).to_lower() in SECRET_KEYS or not _safe_json(value[key],depth+1): return false
		return true
	return false

static func _rectangles(value: Variant, extent: Vector2i) -> bool:
	if not value is Array or value.size()>128: return false
	for raw: Variant in value:
		var box := rect(raw)
		if box.size.x<=0 or box.size.y<=0 or not Rect2i(Vector2i.ZERO,extent).encloses(box): return false
	return true

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("format") not in [FORMAT,FORMAT_V2]:
		return failure("Unsupported native module format or fields.")
	var is_v2: bool = raw.format==FORMAT_V2
	if not _keys(raw,ROOT_KEYS+["fixed_regions"] if is_v2 else ROOT_KEYS):
		return failure("Unsupported native module format or fields.")
	if not identifier(raw.id) or not _text(raw.name,96) or not _strings(raw.tags,32,64) or raw.part_type not in PART_TYPES:
		return failure("Invalid module name, identifier, tags or structural vocabulary.")
	if not _pair(raw.extent) or int(raw.extent[0])<1 or int(raw.extent[1])<1 \
		or int(raw.extent[0])>MAX_SIDE or int(raw.extent[1])>MAX_SIDE:
		return failure("Module extent must be 1–512 cells on each side.")
	var extent := Vector2i(int(raw.extent[0]),int(raw.extent[1]))
	if not _point(raw.anchor,extent): return failure("Module anchor must be inside its local bounds.")
	if not _strings(raw.allowed_transforms,TRANSFORMS.size(),16) or raw.allowed_transforms.is_empty():
		return failure("Declare at least one supported exact-grid transform.")
	for transform: String in raw.allowed_transforms:
		if transform not in TRANSFORMS: return failure("Only exact orthogonal grid transforms are supported.")
	if not raw.geometry is Dictionary or not _keys(raw.geometry,["encoding","cells_base64","sha256"]) \
		or raw.geometry.encoding!=ENCODING or not raw.geometry.cells_base64 is String \
		or raw.geometry.cells_base64.length()>((extent.x*extent.y*2+2)/3)*4 or not _hex(raw.geometry.sha256):
		return failure("Invalid exact material-plane encoding.")
	var cells := Marshalls.base64_to_raw(raw.geometry.cells_base64)
	if cells.size()!=extent.x*extent.y*2 or Marshalls.raw_to_base64(cells)!=raw.geometry.cells_base64 \
		or digest(cells)!=raw.geometry.sha256:
		return failure("Module geometry size, canonical encoding or checksum differs.")
	for key: String in ["clearances","protected_regions","variation_regions"]:
		if not _rectangles(raw[key],extent): return failure("Invalid local "+key+".")
	if is_v2:
		if not _rectangles(raw.fixed_regions,extent): return failure("Invalid local fixed_regions.")
		for fixed: Array in raw.fixed_regions:
			for variable: Array in raw.variation_regions:
				if rect(fixed).intersects(rect(variable)): return failure("Fixed and variable geometry regions must be disjoint.")
	# These are declared empty spaces, not an inference that all Empty cells are a route.
	for clearance: Array in raw.clearances:
		var box := rect(clearance)
		for y: int in range(box.position.y,box.end.y):
			for x: int in range(box.position.x,box.end.x):
				if cells.decode_u16((y*extent.x+x)*2)!=0: return failure("Declared clearance contains observed material.")
	if not raw.attachments is Array or raw.attachments.size()>128: return failure("Too many attachment declarations.")
	var attachment_ids := {}
	var contact_count := 0
	var occupied_faces := {}
	for attachment: Variant in raw.attachments:
		var attachment_keys := ["id","kind","point","facing","compatibility","required","source"]
		if is_v2: attachment_keys += ["role","approach","polarity","capacity","contact"]
		if not attachment is Dictionary or not _keys(attachment,attachment_keys,["end"]):
			return failure("Invalid attachment declaration fields.")
		if not identifier(attachment.id) or attachment_ids.has(attachment.id) \
			or attachment.kind not in ["vertex","line","socket","receptor"] or not _point(attachment.point,extent) \
			or not _pair(attachment.facing) or absi(int(attachment.facing[0]))+absi(int(attachment.facing[1]))!=1 \
			or not _strings(attachment.compatibility,16,64) or attachment.compatibility.is_empty() \
			or not attachment.required is bool or attachment.source not in ["authored","inferred"]:
			return failure("Invalid attachment identity, point, facing or explicit semantic source.")
		if attachment.source=="inferred" and attachment.required: return failure("An inferred attachment cannot establish a required construction contract.")
		if attachment.kind=="line":
			if not _point(attachment.get("end"),extent) or attachment.end==attachment.point \
				or (attachment.end[0]!=attachment.point[0] and attachment.end[1]!=attachment.point[1]):
				return failure("Attachment lines must have distinct axis-aligned local endpoints.")
		elif attachment.has("end"): return failure("Only attachment lines carry an end point.")
		if is_v2:
			if not identifier(attachment.role) or attachment.approach!="face" \
				or attachment.polarity not in ["neutral","socket","receptor"] \
				or not integer(attachment.capacity) or int(attachment.capacity)<1 or int(attachment.capacity)>16:
				return failure("V2 connectors need an authored role, face approach, polarity and capacity 1–16.")
			if (attachment.kind in ["socket","receptor"] and attachment.polarity!=attachment.kind) \
				or (attachment.kind=="vertex" and attachment.polarity!="neutral"):
				return failure("V2 point connector kind and polarity disagree.")
			if not attachment.contact is Dictionary or not _keys(attachment.contact,["policy","minimum_cells","tolerance"]) \
				or attachment.contact.policy not in ["full","overlap"] or not integer(attachment.contact.minimum_cells) \
				or not integer(attachment.contact.tolerance) or int(attachment.contact.tolerance)!=0:
				return failure("V2 connector contact requires full or overlap, an integer minimum and zero grid tolerance.")
			var start := Vector2i(int(attachment.point[0]),int(attachment.point[1]))
			var end := Vector2i(int(attachment.get("end",attachment.point)[0]),int(attachment.get("end",attachment.point)[1]))
			var facing := Vector2i(int(attachment.facing[0]),int(attachment.facing[1]))
			var length := absi(end.x-start.x)+absi(end.y-start.y)+1
			if attachment.kind=="line" and (end.x-start.x)*facing.x+(end.y-start.y)*facing.y!=0:
				return failure("V2 line facing must be perpendicular to its inclusive contact span.")
			if int(attachment.contact.minimum_cells)<1 or int(attachment.contact.minimum_cells)>length \
				or (attachment.contact.policy=="full" and int(attachment.contact.minimum_cells)!=length) \
				or (attachment.kind!="line" and (attachment.contact.policy!="full" or int(attachment.capacity)!=1)):
				return failure("V2 contact minimum must fit its span; point contacts are full and exclusive.")
			contact_count += length
			if contact_count>MAX_CONTACT_CELLS: return failure("V2 module exceeds 8,192 declared contact cells.")
			var step := Vector2i(signi(end.x-start.x),signi(end.y-start.y))
			for index: int in length:
				var point := start+step*index
				var face_key := "%d,%d,%d,%d" % [point.x,point.y,facing.x,facing.y]
				if occupied_faces.has(face_key): return failure("V2 connectors cannot alias the same occupied outward face under different identifiers.")
				occupied_faces[face_key] = true
				if cells.decode_u16((point.y*extent.x+point.x)*2)==0:
					return failure("Every V2 contact cell must be grounded in observed module material.")
				var outside := point+facing
				if Rect2i(Vector2i.ZERO,extent).has_point(outside) and cells.decode_u16((outside.y*extent.x+outside.x)*2)!=0:
					return failure("V2 connectors must expose an Empty outward face in their own geometry.")
		attachment_ids[attachment.id] = true
	if not raw.roles is Array or raw.roles.size()>32: return failure("Too many material role declarations.")
	var role_names := {}
	var assigned_materials := {}
	for role: Variant in raw.roles:
		if not role is Dictionary or not _keys(role,["name","material_ids","compatible_materials","source"]) \
			or not identifier(role.name) or role_names.has(role.name) or role.source!="authored":
			return failure("Material roles must be unique explicit authored declarations.")
		for key: String in ["material_ids","compatible_materials"]:
			if not role[key] is Array or role[key].is_empty() or role[key].size()>128: return failure("Invalid material role palette.")
			var unique := {}
			for material: Variant in role[key]:
				if not integer(material) or int(material)<1 or int(material)>65535 or unique.has(int(material)):
					return failure("Material roles require distinct non-Empty uint16 identities.")
				unique[int(material)] = true
		for material: Variant in role.material_ids:
			if assigned_materials.has(int(material)): return failure("A source material cannot have ambiguous replacement roles.")
			assigned_materials[int(material)] = true
		role_names[role.name] = true
	if not _strings(raw.design_card_ids,32,128) or not raw.provenance is Dictionary or not raw.recipe is Dictionary \
		or not _safe_json(raw.provenance) or not _safe_json(raw.recipe):
		return failure("Invalid provenance, recipe or design-card references; credentials are never module data.")
	if json_bytes([raw.provenance,raw.recipe]).size()>MAX_METADATA_BYTES: return failure("Module provenance/recipe exceeds 256 KiB.")
	if not _hex(raw.content_sha256) or content_digest(raw)!=raw.content_sha256: return failure("Module content checksum differs.")
	if json_bytes(raw).size()>MAX_BYTES: return failure("Module exceeds the 2 MiB document limit.")
	return {"ok":true,"module":canonical(raw),"cells":cells,"extent":extent,
		"scope":"Material geometry and declared semantics; stored receipts are not fresh native qualification."}

static func harvest(cells: PackedByteArray, extent: Vector2i, region: Rect2i, metadata: Dictionary) -> Dictionary:
	if not metadata.get("provenance",{}) is Dictionary or not metadata.get("recipe",{}) is Dictionary:
		return failure("Harvest provenance and recipe must be bounded dictionaries.")
	if extent.x<1 or extent.y<1 or extent.x>2048 or extent.y>2048 or cells.size()!=extent.x*extent.y*2:
		return failure("Harvest needs a complete copied native material plane and its exact extent.")
	if region.size.x<1 or region.size.y<1 or region.size.x>MAX_SIDE or region.size.y>MAX_SIDE \
		or not Rect2i(Vector2i.ZERO,extent).encloses(region): return failure("Harvest region must fit its source and 512 × 512 module limit.")
	var crop := PackedByteArray()
	crop.resize(region.size.x*region.size.y*2)
	for y: int in region.size.y:
		for x: int in region.size.x:
			crop.encode_u16((y*region.size.x+x)*2,cells.decode_u16(((region.position.y+y)*extent.x+region.position.x+x)*2))
	var provenance: Dictionary = metadata.get("provenance",{}).duplicate(true)
	provenance["harvest"] = {"source_extent":[extent.x,extent.y],
		"source_region":[region.position.x,region.position.y,region.size.x,region.size.y],
		"source_plane_sha256":digest(cells),"crop_sha256":digest(crop),
		"scope":"Exact stored material identities only. No actor state, temperature, motion or physical stability."}
	var module := {"format":metadata.get("format",FORMAT),"id":metadata.get("id","module-"+digest(crop).left(16)),
		"name":metadata.get("name","Harvested native module"),"tags":metadata.get("tags",[]),
		"part_type":metadata.get("part_type","unclassified"),"extent":[region.size.x,region.size.y],
		"anchor":metadata.get("anchor",[0,region.size.y-1]),
		"geometry":{"encoding":ENCODING,"cells_base64":Marshalls.raw_to_base64(crop),"sha256":digest(crop)},
		"allowed_transforms":metadata.get("allowed_transforms",["identity"]),
		"attachments":metadata.get("attachments",[]),"clearances":metadata.get("clearances",[]),
		"protected_regions":metadata.get("protected_regions",[]),"roles":metadata.get("roles",[]),
		"variation_regions":metadata.get("variation_regions",[]),"provenance":provenance,
		"recipe":metadata.get("recipe",{}),"design_card_ids":metadata.get("design_card_ids",[])}
	if module.format==FORMAT_V2: module["fixed_regions"] = metadata.get("fixed_regions",[])
	module["content_sha256"] = content_digest(module)
	return validate(module)

static func harvest_tile(tile: Dictionary, metadata: Dictionary, region: Rect2i = Rect2i()) -> Dictionary:
	if tile.get("state")!="completed" or not tile.get("material_cells") is PackedByteArray \
		or not _pair(tile.get("result_extent")) or tile.get("material_cells",PackedByteArray()).is_empty():
		return failure("Select a completed tile with its authoritative native material readback.")
	var plane: PackedByteArray = tile.material_cells
	if digest(plane)!=tile.get("material_sha256",""): return failure("Tile readback checksum differs.")
	if not tile.get("receipts",[]) is Array or not tile.get("provenance",{}) is Dictionary \
		or not tile.get("_frozen_config",tile.get("config",{})) is Dictionary:
		return failure("Malformed native tile evidence.")
	if not tile.get("source_materials") is PackedByteArray or tile.source_materials.size()!=plane.size() \
		or digest(tile.source_materials)!=tile.provenance.get("source_material_sha256",""):
		return failure("Tile source readback is missing or its checksum differs.")
	if tile.receipts.is_empty() or tile.receipts.size()>MAX_CELLS: return failure("Harvest requires bounded completed native execution receipts.")
	var changed := 0
	var checked := 0
	for receipt: Variant in tile.get("receipts",[]):
		if not receipt is Dictionary or receipt.get("backend")!="CyberNativeCellWorld" or receipt.get("status")!="completed":
			return failure("Every harvest receipt must be a completed native acknowledgement.")
		for key: String in ["requested","checked","changed","unchanged","confirmed","excluded","refused"]:
			if not integer(receipt.get(key)) or int(receipt[key])<0 or int(receipt[key])>4096:
				return failure("Native harvest counters are missing or exceed the bounded chunk.")
		if int(receipt.checked)>int(receipt.requested) \
			or int(receipt.checked)!=int(receipt.changed)+int(receipt.unchanged)+int(receipt.excluded)+int(receipt.refused) \
			or int(receipt.confirmed)!=int(receipt.changed)+int(receipt.unchanged):
			return failure("Native harvest acknowledgement counters are inconsistent.")
		if not _hex(receipt.get("readback_sha256")): return failure("Native harvest receipt lacks its exact bounded readback hash.")
		changed += int(receipt.changed)
		checked += int(receipt.checked)
	if checked>MAX_CELLS: return failure("Native harvest receipts exceed the total attempt budget.")
	var net_changed := 0
	for index: int in plane.size()/2:
		if plane.decode_u16(index*2)!=tile.source_materials.decode_u16(index*2): net_changed+=1
	if net_changed>changed: return failure("Native plane changes exceed retained changed-cell acknowledgements.")
	var details := metadata.duplicate(true)
	details["provenance"] = {"kind":"batch-lab-native-material-harvest","attempt_id":tile.get("attempt_id",""),
		"source":tile.get("provenance",{}).duplicate(true),"receipts":tile.get("receipts",[]).duplicate(true),
		"native_acceptance":"retained-native-receipts; placement always requires fresh host admission",
		"physical_owner_acceptance":"not-established"}
	details["recipe"] = {"kind":"retained-source-program","config":tile.get("_frozen_config",tile.get("config",{})).duplicate(true)}
	# Captured source bytes are preserved by crop/provenance, not by embedding a second opaque plane.
	details.recipe.config.erase("source_cells")
	var size := Vector2i(int(tile.result_extent[0]),int(tile.result_extent[1]))
	if region==Rect2i(): region = Rect2i(Vector2i.ZERO,size)
	return harvest(plane,size,region,details)

static func transformed_size(size: Vector2i, transform: String) -> Vector2i:
	return Vector2i(size.y,size.x) if transform in ["rotate_90","rotate_270"] else size

static func transform_point(point: Vector2i, size: Vector2i, transform: String) -> Vector2i:
	match transform:
		"mirror_x": return Vector2i(size.x-1-point.x,point.y)
		"mirror_y": return Vector2i(point.x,size.y-1-point.y)
		"rotate_90": return Vector2i(size.y-1-point.y,point.x)
		"rotate_180": return Vector2i(size.x-1-point.x,size.y-1-point.y)
		"rotate_270": return Vector2i(point.y,size.x-1-point.x)
	return point

static func transform_direction(direction: Vector2i, transform: String) -> Vector2i:
	match transform:
		"mirror_x": return Vector2i(-direction.x,direction.y)
		"mirror_y": return Vector2i(direction.x,-direction.y)
		"rotate_90": return Vector2i(-direction.y,direction.x)
		"rotate_180": return -direction
		"rotate_270": return Vector2i(direction.y,-direction.x)
	return direction

static func transform_rect(box: Rect2i, size: Vector2i, transform: String, origin: Vector2i) -> Rect2i:
	var first := transform_point(box.position,size,transform)+origin
	var last := transform_point(box.end-Vector2i.ONE,size,transform)+origin
	return Rect2i(Vector2i(mini(first.x,last.x),mini(first.y,last.y)),Vector2i(absi(last.x-first.x)+1,absi(last.y-first.y)+1))

static func _array_rect(box: Rect2i) -> Array:
	return [box.position.x,box.position.y,box.size.x,box.size.y]

static func _in_regions(point: Vector2i, regions: Array) -> bool:
	for raw: Variant in regions:
		if rect(raw).has_point(point): return true
	return false

static func _attachment_cell(point: Vector2i, attachments: Array) -> bool:
	for attachment: Dictionary in attachments:
		var start := Vector2i(int(attachment.point[0]),int(attachment.point[1]))
		if point==start: return true
		if attachment.kind=="line":
			var end := Vector2i(int(attachment.end[0]),int(attachment.end[1]))
			if Rect2i(Vector2i(mini(start.x,end.x),mini(start.y,end.y)),Vector2i(absi(start.x-end.x)+1,absi(start.y-end.y)+1)).has_point(point): return true
	return false

static func compile(module: Dictionary, placement: Dictionary, constraints: Dictionary) -> Dictionary:
	var checked := validate(module)
	if not checked.ok: return checked
	if not _keys(placement,["origin"],["transform","palette","variation"]) or not _pair(placement.origin): return failure("Placement requires an integer origin and known controls.")
	var transform: Variant = placement.get("transform","identity")
	if not transform is String or transform not in module.allowed_transforms: return failure("Transform is not explicitly permitted by this module.")
	var origin := Vector2i(int(placement.origin[0]),int(placement.origin[1]))
	var size: Vector2i = checked.extent
	var region := rect(constraints.get("region"))
	var footprint := Rect2i(origin,transformed_size(size,transform))
	if region.size.x<1 or region.size.y<1 or not region.encloses(footprint): return failure("The whole transformed module must fit the authorized region.")
	var guards: Variant = constraints.get("protected",[])
	if not guards is Array or guards.size()>256: return failure("Invalid host protection boundaries.")
	for guard: Variant in guards:
		var box := rect(guard)
		if box.size.x<1 or box.size.y<1: return failure("Invalid host protected rectangle.")
	var materials: Variant = constraints.get("allowed_materials",[])
	if not materials is Array or materials.is_empty() or materials.size()>256: return failure("Host must supply an explicit allowed native material palette.")
	for material: Variant in materials:
		if not integer(material) or int(material)<0 or int(material)>65535: return failure("Invalid host material palette.")
	var maximum: Variant = constraints.get("max_cells",MAX_CELLS)
	if not integer(maximum) or int(maximum)<0 or int(maximum)>MAX_CELLS: return failure("Invalid bounded native cell budget.")
	var palette: Variant = placement.get("palette",{})
	if not palette is Dictionary or palette.size()>32: return failure("Invalid role palette substitution.")
	var replacements := {}
	var known_roles := {}
	for role: Dictionary in module.roles:
		known_roles[role.name] = true
		if not palette.has(role.name): continue
		var target: Variant = palette[role.name]
		if not integer(target) or int(target) not in role.compatible_materials or int(target) not in materials:
			return failure("Substitution is outside the authored compatible palette or host permission.")
		for material: Variant in role.material_ids: replacements[int(material)] = int(target)
	for key: Variant in palette:
		if not known_roles.has(key): return failure("Unknown semantic material role.")
	var variation: Variant = placement.get("variation",{})
	if not variation is Dictionary or not _keys(variation,[],["seed","keep_fraction"]): return failure("Unsupported bounded variation controls.")
	var seed_value: Variant = variation.get("seed",0)
	var keep: Variant = variation.get("keep_fraction",1.0)
	if not integer(seed_value) or not (keep is int or keep is float) or not is_finite(float(keep)) or float(keep)<0.0 or float(keep)>1.0:
		return failure("Variation needs an integer seed and keep_fraction between zero and one.")
	if float(keep)!=1.0 and module.variation_regions.is_empty(): return failure("This module declares no variable geometry.")
	var random := RandomNumberGenerator.new()
	random.seed = int(seed_value)
	var source: PackedByteArray = checked.cells
	var output := PackedInt32Array()
	output.resize(footprint.get_area())
	var varied := 0
	for y: int in size.y:
		for x: int in size.x:
			var material := source.decode_u16((y*size.x+x)*2)
			if material==0: continue
			var local := Vector2i(x,y)
			if float(keep)<1.0 and _in_regions(local,module.variation_regions) and not _in_regions(local,module.get("fixed_regions",[])) and not _attachment_cell(local,module.attachments) and random.randf()>=float(keep):
				varied += 1
				continue
			material = int(replacements.get(material,material))
			if material not in materials: return failure("Observed material %d is not admitted by the host paint palette." % material)
			if _in_regions(local,module.protected_regions): return failure("Module geometry intersects its declared protected region.")
			var transformed := transform_point(local,size,transform)
			var world := origin+transformed
			if _in_regions(world,guards): return failure("Placement intersects a protected cell; no clipping or partial preview is admitted.")
			output[transformed.y*footprint.size.x+transformed.x] = material
	var operations: Array = []
	var exact := PackedInt32Array()
	var occupied := 0
	for y: int in footprint.size.y:
		var x := 0
		while x<footprint.size.x:
			var material := output[y*footprint.size.x+x]
			if material==0: x+=1; continue
			var start := x
			while x<footprint.size.x and output[y*footprint.size.x+x]==material:
				exact.append(origin.x+x); exact.append(origin.y+y); exact.append(material)
				occupied+=1; x+=1
			operations.append({"shape":"rectangle","x0":origin.x+start,"y0":origin.y+y,"x1":origin.x+x-1,"y1":origin.y+y,"material":material})
	if occupied>int(maximum): return failure("Host-calculated module footprint exceeds the native cell budget.")
	var connections: Array = []
	for attachment: Dictionary in module.attachments:
		var item := attachment.duplicate(true)
		var point := origin+transform_point(Vector2i(int(item.point[0]),int(item.point[1])),size,transform)
		item.point = [point.x,point.y]
		var direction := transform_direction(Vector2i(int(item.facing[0]),int(item.facing[1])),transform)
		item.facing = [direction.x,direction.y]
		if item.has("end"):
			var end := origin+transform_point(Vector2i(int(item.end[0]),int(item.end[1])),size,transform)
			item.end = [end.x,end.y]
		item["module_format"] = module.format
		item["module_id"] = module.id
		item["module_sha256"] = module.content_sha256
		if module.format==FORMAT_V2:
			# This list is derived from this module's own exact occupied geometry.
			# A host must still inspect the final projection before accepting contact.
			var contact_start := Vector2i(int(item.point[0]),int(item.point[1]))
			var contact_end := Vector2i(int(item.get("end",item.point)[0]),int(item.get("end",item.point)[1]))
			var contact_step := Vector2i(signi(contact_end.x-contact_start.x),signi(contact_end.y-contact_start.y))
			var own_contact: Array = []
			for index: int in absi(contact_end.x-contact_start.x)+absi(contact_end.y-contact_start.y)+1:
				var contact_point := contact_start+contact_step*index
				own_contact.append([contact_point.x,contact_point.y])
			item["own_contact_cells"] = own_contact
		connections.append(item)
	var clearances: Array = []
	var protected_regions: Array = []
	for box: Array in module.clearances: clearances.append(_array_rect(transform_rect(rect(box),size,transform,origin)))
	for box: Array in module.protected_regions: protected_regions.append(_array_rect(transform_rect(rect(box),size,transform,origin)))
	var anchor := origin+transform_point(Vector2i(int(module.anchor[0]),int(module.anchor[1])),size,transform)
	return {"ok":true,"zero_writes":true,"operations":operations,"cells":exact,
		"footprint":_array_rect(footprint),"anchor":[anchor.x,anchor.y],"connections":connections,
		"clearances":clearances,"protected_regions":protected_regions,"module_id":module.id,
		"module_sha256":module.content_sha256,"placement_sha256":digest(json_bytes([module.content_sha256,placement])),
		"budget":{"requested_cells":occupied,"unique_cells":occupied,"operations":operations.size()},
		"variation":{"removed_variable_cells":varied,"seed":int(seed_value),"keep_fraction":float(keep)},
		"scope":"Zero-write compilation. Existing target occupancy, native admission and final readback are host responsibilities."}

static func summary(module: Dictionary) -> Dictionary:
	var checked := validate(module)
	if not checked.ok: return checked
	var materials := {}
	var cells: PackedByteArray = checked.cells
	for index: int in cells.size()/2: materials[cells.decode_u16(index*2)] = true
	var identities: Array = materials.keys()
	identities.sort()
	var role_names: Array = []
	for role: Dictionary in module.roles: role_names.append(role.name)
	var connections: Array = []
	for attachment: Dictionary in module.attachments:
		for kind: String in attachment.compatibility:
			if kind not in connections: connections.append(kind)
	return {"id":module.id,"name":module.name,"part_type":module.part_type,"vocabulary":module.part_type,
		"format":module.format,"connector_contract":"face-adjacent-grid-v2" if module.format==FORMAT_V2 else "legacy-point-v1",
		"tags":module.tags.duplicate(),"extent":module.extent.duplicate(),"bounds":[0,0,module.extent[0],module.extent[1]],
		"material_roles":role_names,"observed_material_ids":identities,"attachments":module.attachments.duplicate(true),
		"connectors":module.attachments.duplicate(true),"fixed_regions_count":module.get("fixed_regions",[]).size(),
		"connection_types":connections,"design_card_ids":module.design_card_ids.duplicate(),
		"content_sha256":module.content_sha256,"geometry_sha256":module.geometry.sha256,
		"allowed_transforms":module.allowed_transforms.duplicate(),"provenance":module.provenance.duplicate(true),
		"native_readback_verified":false,"native_qualification_scope":"Stored provenance is not a fresh native replay."}
