extends RefCounted

# Starting construction only. Positions are body origins in native cell coordinates.
const Contract = preload("res://scripts/microscenario_contract.gd")
const MAPS = ["workbench/landing-yard", "workbench/quarry"]
const TITLES = ["A · Landing yard", "B · Quarry"]
const FLYER = "arcadelander"
const BARREL = "reference_barrel"
const BRUSH_RADIUS = 4
const MAX_STROKES = 440 # Nine horizontal runs per disc stay inside the scenario budget.
const ROOM = Rect2i(0, 0, 480, 270)
const DIRECTORY = "user://workbench"
const BYTE_LIMIT = 128 * 1024

static func fresh(map: String, policy: PackedInt32Array) -> Dictionary:
	return {"version":1, "recipe_version":1, "map":map, "controlled":FLYER,
		"actors":{FLYER:[160,150], BARREL:[190,185]}, "edits":[], "liquid_policy":Array(policy)}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and floor(value) == value and value >= low and value <= high

static func validate(value: Variant) -> String:
	var keys := ["version","recipe_version","map","controlled","actors","edits","liquid_policy"]
	if not value is Dictionary or value.size() != keys.size() or not value.has_all(keys):
		return "Missing or unknown starting-setup fields."
	if not _integer(value.version,1,1) or not _integer(value.recipe_version,1,1) or value.map not in MAPS:
		return "Unsupported setup version, map or map recipe."
	if value.controlled not in [FLYER, "observer"]:
		return "Only the Arcade Lander admits pilot commands."
	if not value.actors is Dictionary or value.actors.size() != 2 or not value.actors.has_all([FLYER,BARREL]):
		return "Choose one Arcade Lander and one passive reference barrel."
	for model: String in value.actors:
		var xy: Variant = value.actors[model]
		if not xy is Array or xy.size() != 2 or not _integer(xy[0],12,467) or not _integer(xy[1],10,259):
			return "Body origin must be inside the workbench room."
	var flyer := point(value.actors[FLYER])
	var barrel := point(value.actors[BARREL])
	if absi(flyer.x - barrel.x) < 15 and absi(flyer.y - barrel.y) < 14:
		return "Separate the flyer and barrel starting positions."
	if not value.edits is Array or value.edits.size() > MAX_STROKES:
		return "Starting brush history exceeds %d stamps." % MAX_STROKES
	for stamp: Variant in value.edits:
		if not stamp is Array or stamp.size() != 3 or not _integer(stamp[0],4,475) or not _integer(stamp[1],4,265) \
			or not _integer(stamp[2],0,3) or int(stamp[2]) not in [CyberCellWorld.EMPTY,CyberCellWorld.SAND,CyberCellWorld.WATER]:
			return "Unsupported brush stamp or position outside the room."
	if not value.liquid_policy is Array or value.liquid_policy.is_empty() or value.liquid_policy.size() > 4096:
		return "Invalid liquid policy envelope."
	for word: Variant in value.liquid_policy:
		if not _integer(word,-2147483648,2147483647):
			return "Invalid liquid policy word."
	return ""

static func point(xy: Array) -> Vector2i:
	return Vector2i(int(xy[0]),int(xy[1]))

static func physical_definitions(setup: Dictionary) -> Array:
	return [{"model":FLYER, "producer":"human", "position":Vector2(point(setup.actors[FLYER]))},
		{"model":BARREL, "producer":"passive", "position":Vector2(point(setup.actors[BARREL]))}]

# Compare only the small spawn footprints against the final ordered recipe.
# Starting an actor inside authored cells would move or mask them on rebuild.
static func spawn_footprint(actor: Dictionary) -> Rect2i:
	var rig := CyberPhysicalUsableEquipment.definition(CyberPhysicalActorCatalog.entry(actor.model))
	var bounds: Rect2 = rig.bounds
	var origin := Vector2(actor.position) + bounds.position
	return Rect2i(Vector2i(origin.floor()),Vector2i((origin+bounds.size).ceil()) - Vector2i(origin.floor()))

static func spawn_error(setup: Dictionary, rectangles: Array) -> String:
	for actor: Dictionary in physical_definitions(setup):
		var footprint := spawn_footprint(actor)
		var cells := PackedByteArray()
		cells.resize(footprint.get_area())
		for i in range(0,rectangles.size(),5):
			var overlap := footprint.intersection(Rect2i(rectangles[i],rectangles[i+1],rectangles[i+2],rectangles[i+3]))
			for y in range(overlap.position.y,overlap.end.y):
				for x in range(overlap.position.x,overlap.end.x):
					cells[(y-footprint.position.y)*footprint.size.x + x-footprint.position.x] = rectangles[i+4]
		for material: int in cells:
			if material != CyberCellWorld.EMPTY:
				return "Place the %s clear of terrain and authored materials." % actor.model
	return ""

static func definition(setup: Dictionary) -> Dictionary:
	var result := Contract.base(setup.map)
	result.schema_version = 2
	result.camera_origin = [0,0]
	result.player_start = setup.actors[FLYER].duplicate()
	result.tools = ["paint","erase","player"]
	result.source_recipe = "Workbench/v1/" + str(setup.map)
	var wall := CyberCellWorld.WALL
	var rects := [0,0,4,270,wall, 476,0,4,270,wall, 0,258,480,12,wall]
	if setup.map == MAPS[0]:
		rects.append_array([4,212,472,8,wall, 40,185,68,8,wall, 328,179,48,33,wall])
	else:
		rects.append_array([4,210,106,48,wall, 110,230,225,28,wall, 335,194,141,64,wall, 50,125,66,7,wall])
	for stamp: Array in setup.edits:
		for dy: int in range(-BRUSH_RADIUS, BRUSH_RADIUS + 1):
			var half := floori(sqrt(BRUSH_RADIUS * BRUSH_RADIUS - dy * dy))
			rects.append_array([int(stamp[0])-half,int(stamp[1])+dy,2*half+1,1,int(stamp[2])])
	result.rectangles = rects
	result.source_recipe_hash = JSON.stringify(rects).sha256_text()
	result["presentation"] = {"title":TITLES[MAPS.find(setup.map)], "instructions":"Paint and place while paused.",
		"duration_ticks":Contract.MAX_TICK, "baseline":"Starting construction", "profile":"Shared desktop", "regions":[]}
	return result

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
	return {"error":reason} if not reason.is_empty() else {"setup":parser.data}
