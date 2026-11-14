extends RefCounted

# A bounded authoring preprocessor, not a terrain rasterizer. The only output
# accepted by preview/install is an ordinary native GEN-007 schema-4 recipe.
const FORMAT := "cybersand.architectural-project"
const PRESET_FORMAT := "cybersand.architectural-style"
const PLANNER := "connected-hilbert-v1"
const MAX_BYTES := 262144
const MAX_STYLES := 5
const Generated = preload("res://scripts/workbench_generated_map.gd")

static func _preset(identity: String, label: String, module: String, theme: String,
		room: int, floor_height: int, wall: int, door: int, shaft: int,
		wall_material: int, floor_material: int, window_material: int, damage: float) -> Dictionary:
	return {"format":PRESET_FORMAT,"version":1,"id":identity,"name":label,
		"module":module,"module_version":2,"theme":theme,
		"geometry":{"room_size":room,"floor_height":floor_height,
			"wall_thickness":wall,"door_width":door,"shaft_width":shaft},
		"materials":{"wall":wall_material,"floor":floor_material,"window":window_material},
		"apertures":{},"deterioration":damage}

static func builtin_presets() -> Array:
	return [
		_preset("industrial-service","Industrial Service","vault","industrial",32,32,2,8,12,62,66,72,0.0),
		_preset("habitation-arcology","Habitation / Arcology","arcology","industrial",64,48,3,12,16,58,70,121,0.0),
		_preset("overgrown-ruins","Overgrown / Ruined Construction","arcology","garden",96,64,3,14,10,42,97,55,0.20),
        _preset("civic-atrium","Civic Atrium","arcology","ruins",80,56,2,18,0,98,111,120,0.0),
        _preset("transit-spine","Transit Spine","arcology","industrial",128,32,3,12,20,114,66,72,0.0),
        _preset("basalt-archive","Basalt Archive","vault","basalt",64,64,4,12,0,100,101,123,0.05),
        _preset("solar-conservatory","Solar Conservatory","arcology","garden",48,96,2,10,0,113,129,120,0.04),
        _preset("thermal-foundry","Thermal Foundry","vault","industrial",16,24,2,4,0,104,131,72,0.0),
        _preset("earthen-terraces","Earthen Terraces","arcology","ruins",128,80,4,20,0,102,109,55,0.30),
        _preset("orbital-observatory","Orbital Observatory","arcology","industrial",96,64,2,14,12,130,114,121,0.0)
	]

static func default_project() -> Dictionary:
	var presets := builtin_presets()
	return {"format":FORMAT,"version":1,"planner":PLANNER,"seed":161803,
		"origin":[0,0],"extent":[1024,1024],"zone_scale":64,
		"automatic_tunnels":true,"automatic_doors":true,"automatic_windows":true,
		"corridor_width":12,
		"styles":[{"enabled":true,"share":45.0,"preset":presets[0]},
			{"enabled":true,"share":30.0,"preset":presets[1]},
			{"enabled":true,"share":25.0,"preset":presets[2]}]}

static func _failure(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func _keys(value: Variant, allowed: Array, required: Array, context: String) -> String:
	if not value is Dictionary: return context + " must be an object."
	for key: Variant in value:
		if not key is String or key not in allowed:
			return context + ": unsupported field '" + str(key) + "'."
	for key: String in required:
		if not value.has(key): return context + ": missing '" + key + "'."
	return ""

static func _number(value: Variant, low: float, high: float, integral: bool = true) -> bool:
	if not value is int and not value is float: return false
	var number := float(value)
	return is_finite(number) and number >= low and number <= high and (not integral or floor(number) == number)

static func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789-_": return false
	return true

static func validate_preset(preset: Variant) -> String:
	var keys := ["format","version","id","name","module","module_version","theme","geometry","materials","apertures","deterioration"]
	var error := _keys(preset,keys,keys,"Style preset")
	if not error.is_empty(): return error
	if not preset.format is String or preset.format != PRESET_FORMAT or not _number(preset.version,1,1):
		return "Unsupported style format/version; expected cybersand.architectural-style v1."
	if not _identifier(preset.id): return "Style id must be 1–64 lowercase letters, digits, hyphens or underscores."
	if not preset.name is String or preset.name.strip_edges().is_empty() or preset.name.length() > 128:
		return "Style name must be a nonempty string of at most 128 characters."
	if not preset.module is String or preset.module not in ["arcology","vault"] or not _number(preset.module_version,2,2):
		return "Styles require the native arcology or vault module, version 2."
	if not preset.theme is String or preset.theme not in ["industrial","ruins","garden","basalt","dry_cavern","wet_cavern"]:
		return "Unknown native style theme."
	var dimensions := ["room_size","floor_height","wall_thickness","door_width","shaft_width"]
	error = _keys(preset.geometry,dimensions,dimensions,"Style geometry")
	if not error.is_empty(): return error
	var g: Dictionary = preset.geometry
	var vault: bool = preset.module == "vault"
	if not _number(g.room_size,12 if vault else 16,128 if vault else 256):
		return "Room/bay size is outside the native module range (Vault 12–128; Arcology 16–256)."
	if not _number(g.floor_height,16,256): return "Floor height must be an integer from 16 to 256 cells."
	if not _number(g.wall_thickness,1,4 if vault else 5): return "Wall thickness is outside the native module range."
	if not _number(g.door_width,2,64): return "Door opening width must be an integer from 2 to 64 cells."
	if int(g.door_width) > int(g.room_size) - 2 * int(g.wall_thickness):
		return "Door opening must fit inside the room/bay between its walls."
	if not vault and int(g.door_width) > int(g.floor_height) - 2 * int(g.wall_thickness):
		return "Door opening must fit between Arcology floors."
	if not _number(g.shaft_width,0,64): return "Service shaft width must be 0 (disabled) or 4–64 cells."
	if int(g.shaft_width) > 0 and int(g.shaft_width) < 4: return "Service shaft width must be 0 (disabled) or 4–64 cells."
	error = _keys(preset.materials,["wall","floor","window"],["wall","floor","window"],"Style materials")
	if not error.is_empty(): return error
	for key: String in preset.materials:
		if not _number(preset.materials[key],1,255): return "Style materials must be integer material identifiers."
	# Native admission is authoritative for material existence and solid capability.
	error = _keys(preset.apertures,["automatic_doors","automatic_windows"],[],"Style apertures")
	if not error.is_empty(): return error
	for key: String in preset.apertures:
		if not preset.apertures[key] is bool: return "Style aperture overrides must be booleans."
	if not _number(preset.deterioration,0,0.6,false): return "Deterioration must be a finite fraction from 0 to 0.6."
	return ""

static func _rank(seed: int, lane: String) -> int:
	# Explicit SHA-256 lanes avoid dependence on Godot's evolving RNG algorithm.
	return Generated.digest(("%d:%s" % [seed,lane]).to_utf8_buffer()).left(8).hex_to_int()

static func _hilbert(side: int, distance: int) -> Vector2i:
	var x := 0
	var y := 0
	var remaining := distance
	var scale := 1
	while scale < side:
		var rx := 1 & (remaining >> 1)
		var ry := 1 & (remaining ^ rx)
		if ry == 0:
			if rx == 1:
				x = scale - 1 - x
				y = scale - 1 - y
			var previous_x := x
			x = y
			y = previous_x
		x += scale * rx
		y += scale * ry
		remaining >>= 2
		scale <<= 1
	return Vector2i(x,y)

static func _zone_bounds(cells: Array, side: int, scale: int, origin: Array, slot: int) -> Array:
	var low := Vector2i(side,side)
	var high := Vector2i(-1,-1)
	for index: int in cells.size():
		if cells[index] != slot: continue
		var point := Vector2i(index % side,index / side)
		low = low.min(point)
		high = high.max(point)
	return [int(origin[0])+low.x*scale,int(origin[1])+low.y*scale,
		(high.x-low.x+1)*scale,(high.y-low.y+1)*scale]

static func compile(input: Variant) -> Dictionary:
	var started := Time.get_ticks_usec()
	var keys := ["format","version","planner","seed","origin","extent","zone_scale",
		"automatic_tunnels","automatic_doors","automatic_windows","corridor_width","styles"]
	var error := _keys(input,keys,keys,"Architectural project")
	if not error.is_empty(): return _failure(error)
	if not input.format is String or input.format != FORMAT or not _number(input.version,1,1) or \
			not input.planner is String or input.planner != PLANNER:
		return _failure("Unsupported architectural project or planner version.")
	if not _number(input.seed,0,9007199254740991): return _failure("Seed must be an exact nonnegative JSON integer (at most 2^53−1).")
	for key: String in ["automatic_tunnels","automatic_doors","automatic_windows"]:
		if not input[key] is bool: return _failure(key + " must be On or Off.")
	if not _number(input.corridor_width,2,64): return _failure("Automatic tunnel corridor width must be 2–64 cells.")
	for key: String in ["origin","extent"]:
		if not input[key] is Array or input[key].size() != 2:
			return _failure(key + " must contain two integer coordinates.")
		for value: Variant in input[key]:
			if not _number(value,-1000000,1000000): return _failure(key + " contains an invalid coordinate.")
	var extent := Vector2i(int(input.extent[0]),int(input.extent[1]))
	if extent.x != extent.y or extent.x not in [256,512,1024]:
		return _failure("This prototype supports square 256, 512 or 1024-cell maps.")
	if int(input.origin[0]) > 1000000-extent.x or int(input.origin[1]) > 1000000-extent.y:
		return _failure("The complete source region must fit within ±1,000,000 world cells.")
	if not _number(input.zone_scale,16,1024): return _failure("Zone scale must be an integer from 16 to 1024 cells.")
	var scale := int(input.zone_scale)
	if extent.x % scale != 0: return _failure("Zone scale must divide the map size exactly.")
	var side := extent.x / scale
	if side < 2 or side > 16 or (side & (side-1)) != 0:
		return _failure("Choose a zone scale giving a square 2×2, 4×4, 8×8 or 16×16 planning grid (native limit: 256 blocks).")
	if not input.styles is Array or input.styles.is_empty() or input.styles.size() > MAX_STYLES:
		return _failure("Select one to five architectural style slots.")
	var selected: Array[int] = []
	var total_share := 0.0
	for slot: int in input.styles.size():
		var style: Variant = input.styles[slot]
		error = _keys(style,["enabled","share","preset"],["enabled","share","preset"],"Style slot")
		if not error.is_empty(): return _failure(error)
		if not style.enabled is bool or not _number(style.share,0,100,false):
			return _failure("Style selection must be a boolean and share must be between 0 and 100 percent.")
		error = validate_preset(style.preset)
		if not error.is_empty(): return _failure("Style %d: %s" % [slot+1,error])
		if not style.enabled: continue
		if float(style.share) <= 0: return _failure("Give each selected style a positive share, or deselect it.")
		selected.append(slot)
		total_share += float(style.share)
	if selected.is_empty(): return _failure("Select at least one style.")
	if absf(total_share-100.0) > 0.000001: return _failure("Selected style shares must total 100%% (currently %.4f%%)." % total_share)
	if JSON.stringify(input).to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Architectural project exceeds the 256 KiB authoring limit.")
	var project: Dictionary = input.duplicate(true)
	# Canonical public JSON types, including fresh-process imports.
	project.seed = int(project.seed)
	project.version = 1
	project.origin = [int(project.origin[0]),int(project.origin[1])]
	project.extent = [extent.x,extent.y]
	project.zone_scale = scale
	project.corridor_width = int(project.corridor_width)
	for style: Dictionary in project.styles:
		style.preset.version = 1
		style.preset.module_version = 2
		for key: String in style.preset.geometry: style.preset.geometry[key] = int(style.preset.geometry[key])
		for key: String in style.preset.materials: style.preset.materials[key] = int(style.preset.materials[key])
	var count: int = side*side
	var quotas: Dictionary = {}
	var remainders: Array = []
	var allocated := 0
	for slot: int in selected:
		var ideal: float = float(project.styles[slot].share)*count/100.0
		quotas[slot] = floori(ideal)
		allocated += int(quotas[slot])
		remainders.append({"slot":slot,"fraction":ideal-floor(ideal)})
	remainders.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.fraction > b.fraction if a.fraction != b.fraction else a.slot < b.slot)
	for index: int in count-allocated: quotas[remainders[index].slot] += 1
	var coverage: Array = []
	for slot: int in selected:
		var achieved := 100.0*int(quotas[slot])/count
		var style: Dictionary = project.styles[slot]
		if int(quotas[slot]) < 1 or absf(achieved-float(style.share)) > 2.0+0.000001:
			return _failure("Infeasible coverage for %s on %d blocks: requested %.3f%%, nearest quota %.3f%%. Use a finer zone scale." % [style.preset.name,count,style.share,achieved])
		coverage.append({"slot":slot,"id":style.preset.id,"name":style.preset.name,
			"requested_percent":float(style.share),"achieved_percent":achieved,
			"blocks":int(quotas[slot]),"components":1})
	var ordering := selected.duplicate()
	ordering.sort_custom(func(a: int,b: int) -> bool:
		var aa := _rank(project.seed,"style-%d" % a)
		var bb := _rank(project.seed,"style-%d" % b)
		return aa < bb if aa != bb else a < b)
	var transform := _rank(project.seed,"orientation") % 8
	var reverse := (_rank(project.seed,"direction") & 1) == 1
	var cells: Array = []
	cells.resize(count)
	var distance := 0
	for slot: int in ordering:
		for _block: int in int(quotas[slot]):
			var point := _hilbert(side,count-1-distance if reverse else distance)
			if (transform & 1) != 0: point = Vector2i(point.y,point.x)
			if (transform & 2) != 0: point.x = side-1-point.x
			if (transform & 4) != 0: point.y = side-1-point.y
			cells[point.y*side+point.x] = slot
			distance += 1
	var categories: Array = []
	var domains: Array = []
	var adjacency: Array = []
	var all_mask: int = (1 << selected.size())-1
	for slot: int in selected: categories.append("%016x" % (slot+1))
	for cell: int in cells: domains.append(1 << selected.find(cell))
	for _direction: int in 4:
		var row: Array = []
		for _style: int in selected.size(): row.append(all_mask)
		adjacency.append(row)
	var recipe := {"schema":4,"seed":project.seed,"chunk_size":128,"candidate":"district_grammar",
		"architecture":{"version":1,"automatic_tunnels":project.automatic_tunnels,
			"automatic_doors":project.automatic_doors,"door_width":0},
		"parameters":{"district_size":256,"corridor_width":project.corridor_width,
			"room_size":48,"wall_thickness":3,"detail":0.0},
		"themes":{"weights":{"industrial":1}},
		"spatial":{"assignments":[{"id":PLANNER,"specification":{
			"width":side,"height":side,"cell_size":scale,
			"origin_x":project.origin[0],"origin_y":project.origin[1],"seed":"%016x" % project.seed,
			"categories":categories,"adjacency":adjacency,"domains":domains},
			"limits":{"max_work":1000000,"max_scratch_bytes":262144}}],
			"nodes":[{"id":"architectural-zone","kind":"assigned_region","reference":PLANNER}]},
		"modules":[],"fields":[],"modifiers":[]}
	for slot: int in selected:
		var preset: Dictionary = project.styles[slot].preset
		var g: Dictionary = preset.geometry
		var prefix := "style-%d-%s" % [slot,preset.id]
		var mask := prefix+"-mask"
		recipe.spatial.nodes.append({"id":prefix+"-selected","kind":"category_is","inputs":["architectural-zone"],
			"value":{"type":"category","category":{"x":slot+1,"y":0,"domain":"0000000000000000"}}})
		recipe.spatial.nodes.append({"id":mask,"kind":"to_mask","inputs":[prefix+"-selected"]})
		var bounds := _zone_bounds(cells,side,scale,project.origin,slot)
		var doors: bool = preset.apertures.get("automatic_doors",project.automatic_doors)
		var windows: bool = preset.apertures.get("automatic_windows",project.automatic_windows)
		if preset.module == "arcology" and windows and int(g.floor_height) < 2*int(g.wall_thickness)+int(g.door_width)+7:
			return _failure("%s: windows need floor height at least 2 × wall thickness + door width + 7 cells; increase the floor height or disable windows." % preset.name)
		var parameters := {"wall":g.wall_thickness,"door_width":g.door_width,
			"automatic_doors":1 if doors else 0,"wall_material":preset.materials.wall,
			"accent_material":preset.materials.floor}
		if preset.module == "vault":
			# One prepared maze, clipped by an immutable category mask; never a
			# different district_size or room solver for every sampled cell.
			bounds = [project.origin[0],project.origin[1],extent.x,extent.y]
			if extent.x % int(g.room_size) != 0 or extent.x / int(g.room_size) > 64:
				return _failure("%s: Vault room size must divide the map extent, with at most 64 rooms per axis." % preset.name)
			parameters.cell_size = g.room_size
		else:
			parameters.merge({"bay_width":g.room_size,"floor_height":g.floor_height,
				"shaft_width":g.shaft_width,"automatic_windows":1 if windows else 0,
				"floor_material":preset.materials.floor,"partition_material":preset.materials.wall,
				"window_material":preset.materials.window,"shaft_material":preset.materials.floor})
		recipe.modules.append({"id":prefix,"module":preset.module,"version":2,
			"bounds":bounds,"parameters":parameters,"application":"spatial:"+mask})
		recipe.modifiers.append({"id":prefix+"-theme","bounds":bounds,
			"application":"spatial:"+mask,"themes":{"weights":{preset.theme:1}}})
		if float(preset.deterioration) > 0:
			var noise := prefix+"-damage"
			var keep := prefix+"-retained"
			recipe.fields.append({"id":noise,"kind":"value_noise",
				"parameters":{"scale":maxi(int(g.room_size),int(g.floor_height)),"salt":701+slot}})
			recipe.fields.append({"id":keep,"kind":"band","inputs":[noise],
				"parameters":{"low":0,"high":1.0-float(preset.deterioration),"feather":0}})
			recipe.modifiers.append({"id":prefix+"-voids","priority":10,"bounds":bounds,
				"application":"spatial:"+mask,"exclusion":keep,"material":0})
	return {"ok":true,"error":"","recipe":recipe,"project":project,
		"project_hash":Generated.recipe_hash(project),"planner_us":Time.get_ticks_usec()-started,
		"coverage":coverage,"zones":{"width":side,"height":side,"cell_size":scale,
			"origin":project.origin.duplicate(),"cells":cells}}

static func import_preset(project: Variant, preset: Variant, slot: int = 0) -> Dictionary:
	var validated := compile(project)
	if not validated.ok: return validated
	var error := validate_preset(preset)
	if not error.is_empty(): return _failure(error)
	if slot < 0 or slot >= validated.project.styles.size(): return _failure("Select an existing style slot for the imported preset.")
	var replaced: Dictionary = validated.project.duplicate(true)
	replaced.styles[slot].preset = preset.duplicate(true)
	return compile(replaced)
