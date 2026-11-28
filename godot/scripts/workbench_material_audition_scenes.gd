extends RefCounted

# Ordinary, finite authored starts. No private World, solver switch, fake liquid
# or automated parameter change. Loading one is an explicit scene replacement;
# live material Apply is a different operation and never calls this module.
const Setup = preload("res://scripts/workbench_setup.gd")
const SCENES := [
	{"id":"density-sorter","label":"Density sorter · 512²","help":"Sand on the left and lighter Dust on the right fall into independent Oil basins through sloped hoppers. Compare Sand 500 below Oil's declared 800 with 1600 and 2400 above it; both heavy settings share the same exchange eligibility. Dust stays an unchanged control. Powder–powder swaps remain forbidden. Repaint a dose to compare within the continuing scene."},
	{"id":"viscosity-channel","label":"Brine flow channels · 512²","help":"Three finite Brine reservoirs feed covered horizontal throats before dropping into stepped channels. Compare lateral advance: viscosity changes sideways yield, while gravity stays unchanged. Select Brine 24 and compare 0, 96 and 240 when its generic consumer is active. High values can enter existing activity rest; changing the configuration wakes the affected cells. An inertial Brine assignment has no live viscosity control. Applied solver settings are preserved."},
	{"id":"reaction-contact","label":"Salt contact gallery · 512²","help":"Salt doses fall into Water through contact trays; a separate Salt and Ice pocket exposes another authored pair. Select Salt 23 and inspect each pair's roles and products. Active Salt can initiate its admitted Water contact even when Wave Water cannot. Compare an admitted threshold of 0 with 255. Zero remains 1/256; reactions already consumed are not undone by Revert."},
	{"id":"industrial-loop","label":"Industrial settling works · 1024×512","help":"A finite industrial apparatus combines Sand/Oil classification, a Brine raceway and Salt/Water processing among Metal supports, glass windows and a timber service deck. Paint fresh material, remove a gate, and refine one current-scene profile while the ordinary Workbench keeps running."},
]

static func description(id: String) -> Dictionary:
	for scene: Dictionary in SCENES:
		if scene.id == id: return scene.duplicate(true)
	return {}

static func build(id: String, policy: PackedInt32Array) -> Dictionary:
	var setup := create(id,policy)
	if setup.is_empty(): return {"ok":false,"error":"Unknown material audition demonstration scene."}
	var error := Setup.validate(setup)
	return {"ok":error.is_empty(),"setup":setup,"error":error}

static func create(id: String, policy: PackedInt32Array) -> Dictionary:
	if description(id).is_empty(): return {}
	var size := Vector2i(1024,512) if id == "industrial-loop" else Vector2i(512,512)
	var data := Setup.fresh(policy,size)
	data.material = Setup.SAND
	data.brush = 6
	var edits: Array = data.edits
	match id:
		"density-sorter": _density(edits)
		"viscosity-channel": _viscosity(edits)
		"reaction-contact": _reaction(edits)
		"industrial-loop": _industrial(edits)
	return data

static func _box(edits: Array, x0: int, y0: int, x1: int, y1: int, material: int) -> void:
	if x1 > x0 and y1 > y0: edits.append([x0,y0,x1-x0,y1-y0,material])

static func _basin(edits: Array, x0: int, y0: int, x1: int, y1: int, thickness: int = 6) -> void:
	_box(edits,x0,y0,x0+thickness,y1,Setup.WALL)
	_box(edits,x1-thickness,y0,x1,y1,Setup.WALL)
	_box(edits,x0,y1-thickness,x1,y1,Setup.WALL)

static func _stairs(edits: Array, x0: int, y0: int, steps: int, width: int, drop: int, direction: int = 1) -> void:
	for index: int in range(steps):
		var x := x0 + index * width * direction
		var y := y0 + index * drop
		_box(edits,x,y,x+width+2,y+5,Setup.WALL)

static func _density(edits: Array) -> void:
	# Independent, non-reactive contacts isolate ordinary directional exchange.
	# Sand's admitted density crosses Oil's 800; unchanged Dust is lighter at 420.
	for origin: int in [20,270]:
		_box(edits,origin+6,292,origin+214,474,Setup.OIL)
		_basin(edits,origin,236,origin+220,482)
		_stairs(edits,origin+14,156,6,12,9,1)
		_stairs(edits,origin+190,156,6,12,9,-1)
		_box(edits,origin+100,212,origin+106,276,Setup.WALL)
		_box(edits,origin+116,212,origin+122,276,Setup.WALL)
		# Shelves expose grain settling and cavities after painting new doses.
		_box(edits,origin+36,384,origin+84,390,Setup.WALL)
		_box(edits,origin+136,418,origin+194,424,Setup.WALL)
	_box(edits,50,92,214,142,Setup.SAND)
	_box(edits,300,92,464,142,Setup.DUST)
	_box(edits,24,488,488,496,Setup.METAL)

static func _viscosity(edits: Array) -> void:
	for index: int in range(3):
		var left := 12 + index * 168
		# All bays use the same material and geometry so there is no suggestion
		# that one material-global scene profile selectively alters a single bay.
		_box(edits,left+6,56,left+62,168,Setup.BRINE)
		_box(edits,left,28,left+6,176,Setup.WALL)
		# A tall partition and covered three-cell throat prevent gravity from
		# bypassing the actual lateral-yield consumer. The opening stays ordinary
		# erasable terrain; no hidden pump or fixture-specific motion is used.
		_box(edits,left+62,28,left+68,173,Setup.WALL)
		_box(edits,left+62,168,left+146,173,Setup.WALL)
		_box(edits,left,176,left+138,182,Setup.WALL)
		_box(edits,left+146,168,left+152,490,Setup.WALL)
		_stairs(edits,left+132,218,6,11,19,-1)
		_box(edits,left+10,372,left+104,378,Setup.WALL)
		_box(edits,left+98,340,left+104,378,Setup.WALL)
		_basin(edits,left,392,left+152,490,6)
		_box(edits,left+20,456,left+132,484,Setup.BRINE)

static func _reaction(edits: Array) -> void:
	for index: int in range(3):
		var left := 16 + index * 164
		_box(edits,left+6,316,left+142,480,Setup.WATER)
		_basin(edits,left,272,left+148,488,6)
		_box(edits,left+28,96,left+120,150,Setup.SALT)
		_box(edits,left+16,180,left+60,186,Setup.WALL)
		_box(edits,left+88,224,left+132,230,Setup.WALL)
		_box(edits,left+70,282,left+76,340,Setup.METAL)
	# An accessible Ice/Salt shelf is isolated from the broad Water trays.
	_box(edits,202,34,246,72,Setup.ICE)
	_box(edits,246,34,268,72,Setup.SALT)
	_box(edits,196,74,274,80,Setup.WALL)

static func _industrial(edits: Array) -> void:
	# Left classifier and settling basin.
	_box(edits,30,318,310,478,Setup.OIL)
	_basin(edits,24,280,318,486,8)
	_box(edits,48,64,254,126,Setup.SAND)
	_stairs(edits,40,142,7,16,11)
	_stairs(edits,266,142,7,16,11,-1)
	_box(edits,142,220,148,300,Setup.METAL)
	_box(edits,164,220,170,300,Setup.METAL)
	_box(edits,46,390,126,398,Setup.WALL)
	_box(edits,208,422,292,430,Setup.WALL)
	# Central Brine header tank, finite raceway and receiving sump.
	_box(edits,354,74,610,172,Setup.BRINE)
	_box(edits,346,40,354,180,Setup.METAL)
	_box(edits,610,40,618,180,Setup.METAL)
	_box(edits,346,174,462,182,Setup.WALL)
	_box(edits,484,174,618,182,Setup.WALL)
	_stairs(edits,462,224,7,18,17)
	_basin(edits,354,384,646,486,8)
	_box(edits,366,444,634,478,Setup.BRINE)
	# Right contact process, with a wood walkway and readable glass front.
	_box(edits,704,318,992,478,Setup.WATER)
	_basin(edits,696,288,1000,486,8)
	_box(edits,744,112,878,176,Setup.SALT)
	_box(edits,714,218,802,226,Setup.WALL)
	_box(edits,850,254,982,262,Setup.WALL)
	_box(edits,704,298,780,304,Setup.GLASS)
	_box(edits,908,298,992,304,Setup.GLASS)
	# Structural catwalks, supports and deliberate apertures: ordinary paint,
	# not inaccessible scenery or a hidden fixture-specific simulation owner.
	_box(edits,20,32,1004,40,Setup.METAL)
	_box(edits,20,32,28,496,Setup.METAL)
	_box(edits,996,32,1004,496,Setup.METAL)
	_box(edits,324,44,332,496,Setup.METAL)
	_box(edits,660,44,668,496,Setup.METAL)
	_box(edits,24,490,1004,500,Setup.WALL)
	_box(edits,682,72,982,80,Setup.WOOD)
	for x: int in range(682,984,30): _box(edits,x,48,x+4,72,Setup.METAL)
	for y: int in range(316,472,22):
		_box(edits,334,y,350,y+4,Setup.METAL)
		_box(edits,670,y,690,y+4,Setup.METAL)
