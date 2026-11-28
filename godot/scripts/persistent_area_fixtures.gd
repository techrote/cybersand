extends RefCounted

# GEN-006's first profile deliberately uses three ordinary authored starts.
# These recipes initialize an area once. Re-entry must use its native CYPS
# continuation, including Empty edits and simulation-only changes.
const Setup = preload("res://scripts/workbench_setup.gd")
const EXTENT := Vector2i(512,512)
const IDS := ["a","b","c"]
const AREAS := [
	{"id":"a","letter":"A","label":"Industrial fire",
		"help":"Watch the timber and Oil burn. Erase part of the timber or paint a firebreak, visit another area, then return to its retained fire and smoke.",
		"landmark":[248,236],"empty_edit":[120,384],"paint_edit":[248,472]},
	{"id":"b","letter":"B","label":"Waterworks",
		"help":"Water and Sand settle in the terraces. Erase the marked wooden gate at the lower reservoir, then return after spending game time elsewhere.",
		"landmark":[270,432],"empty_edit":[270,432],"paint_edit":[448,472]},
	{"id":"c","letter":"C","label":"Foundry gallery",
		"help":"The twin arches and glass tower identify this area. Sand falls through the central chute. Leave a material mark or remove a piece of the gallery and revisit it.",
		"landmark":[252,312],"empty_edit":[58,390],"paint_edit":[400,472]},
]


static func description(area_id: String) -> Dictionary:
	for area: Dictionary in AREAS:
		if area.id == area_id: return area.duplicate(true)
	return {}


static func create(area_id: String, policy: PackedInt32Array) -> Dictionary:
	if not area_id in IDS: return {}
	var authored := Setup.fresh(policy,EXTENT)
	authored.brush = 6
	var edits: Array = authored.edits
	# A finite hard frame keeps all three scenes visually and mechanically
	# bounded. It is native material, not a renderer-only outline.
	_box(edits,8,32,16,500,Setup.WALL)
	_box(edits,496,32,504,500,Setup.WALL)
	_box(edits,8,488,504,500,Setup.WALL)
	match area_id:
		"a":
			_industrial(edits)
			authored.material = Setup.WOOD
		"b":
			_waterworks(edits)
			authored.material = Setup.WATER
		"c":
			_gallery(edits)
			authored.material = Setup.SAND
	return authored


static func _industrial(edits: Array) -> void:
	# Two metal process bays, joined by an elevated walkway. Existing native
	# Wood/Oil/Coal combustion and Fire->Smoke lifecycle supply progression.
	_box(edits,36,232,44,488,Setup.METAL)
	_box(edits,232,232,240,488,Setup.METAL)
	_box(edits,280,304,288,488,Setup.METAL)
	_box(edits,464,304,472,488,Setup.METAL)
	_box(edits,36,232,472,240,Setup.METAL)
	_box(edits,36,472,240,488,Setup.METAL)
	_box(edits,280,472,472,488,Setup.METAL)
	_box(edits,60,352,216,432,Setup.WOOD)
	for x: int in range(64,216,32):
		_box(edits,x,432,x+12,472,Setup.WOOD)
	_box(edits,64,336,216,352,Setup.FIRE)
	_box(edits,288,404,464,472,Setup.OIL)
	_box(edits,304,388,448,404,Setup.FIRE)
	_box(edits,70,274,134,300,Setup.COAL)
	_box(edits,60,300,144,308,Setup.METAL)
	_box(edits,76,264,124,274,Setup.FIRE)
	# Chimneys and inspection windows make A distinct before any dynamics.
	for x: int in [88,184,328,424]:
		_box(edits,x,112,x+8,232,Setup.METAL)
		_box(edits,x+8,136,x+24,184,Setup.GLASS)
		_box(edits,x+24,112,x+32,232,Setup.METAL)


static func _waterworks(edits: Array) -> void:
	# The upper finite reservoir spills over a ledge; the lower wooden gate
	# admits a clear, repeatable destructive edit without a host-owned valve.
	_box(edits,20,96,136,240,Setup.WATER)
	_box(edits,16,240,168,248,Setup.WALL)
	_box(edits,136,192,144,240,Setup.WALL)
	_box(edits,188,304,328,312,Setup.WALL)
	_box(edits,312,272,320,304,Setup.WALL)
	_box(edits,352,360,480,368,Setup.WALL)
	_box(edits,20,400,264,488,Setup.WATER)
	_box(edits,264,376,276,408,Setup.WALL)
	_box(edits,264,456,276,488,Setup.WALL)
	_box(edits,264,408,276,456,Setup.WOOD)
	# Metal trim marks the gate without blocking the erasable wooden cells.
	_box(edits,254,402,286,408,Setup.METAL)
	_box(edits,254,456,286,462,Setup.METAL)
	for step: int in range(7):
		_box(edits,304+step*20,480-step*12,324+step*20,488,Setup.SAND)
	_box(edits,192,128,252,204,Setup.SAND)
	_box(edits,376,224,424,276,Setup.SAND)
	# Distinct blue glass measuring staff beside the lower basin.
	_box(edits,464,392,472,472,Setup.GLASS)
	for y: int in range(392,472,16):
		_box(edits,460,y,480,y+3,Setup.METAL)


static func _gallery(edits: Array) -> void:
	# Two stepped arches, central glass tower and a real falling Sand chute.
	for left: int in [48,296]:
		_box(edits,left,368,left+20,488,Setup.WOOD)
		_box(edits,left+136,368,left+156,488,Setup.WOOD)
		for step: int in range(5):
			_box(edits,left+step*12,356-step*12,left+step*12+24,380-step*12,Setup.METAL)
			_box(edits,left+132-step*12,356-step*12,left+156-step*12,380-step*12,Setup.METAL)
		_box(edits,left+48,296,left+108,308,Setup.METAL)
		_box(edits,left+40,420,left+116,428,Setup.WOOD)
	_box(edits,232,288,240,488,Setup.METAL)
	_box(edits,272,288,280,488,Setup.METAL)
	_box(edits,240,288,272,324,Setup.GLASS)
	_box(edits,240,344,272,380,Setup.GLASS)
	_box(edits,224,280,288,288,Setup.METAL)
	_box(edits,224,400,288,408,Setup.METAL)
	_box(edits,228,68,284,132,Setup.SAND)
	_box(edits,216,60,224,176,Setup.METAL)
	_box(edits,288,60,296,176,Setup.METAL)
	_box(edits,216,176,248,184,Setup.METAL)
	_box(edits,264,176,296,184,Setup.METAL)
	# Side pockets continue moving even after the central chute has settled.
	_box(edits,80,180,128,240,Setup.SAND)
	_box(edits,376,204,424,252,Setup.DUST)
	_box(edits,48,264,176,272,Setup.METAL)
	_box(edits,336,264,464,272,Setup.METAL)


static func _box(edits: Array, x0: int, y0: int, x1: int, y1: int, material: int) -> void:
	edits.append([x0,y0,x1-x0,y1-y0,material])
