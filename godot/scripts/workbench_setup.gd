extends RefCounted

# A starting construction recipe. Native runtime state and command leases are never serialized.
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const BARREL := "reference_barrel"
const RESPONSES := ["LA-SELECTIVE", "LA", "LA-EVENT-OFF", "RFT"]
# The first nine are the powders a 4 x 24 source may emit; later entries are
# paint-only (liquids, reactive and thermal materials) and stay appended.
const MATERIALS := [2,14,29,13,19,23,25,26,27,3,58,0,8,16,12,7,9,28]
const MATERIAL_NAMES := ["Sand","Dust","Rust","Stone","Seed","Salt","Sodium","Gunpowder","Coal","Water","Hard wall","Erase",
	"Lava","Oil","Acid","Wood","Ice","Metal"]
const MAX_BODIES := 8
const MAX_RUNS := 4096
# Starting paint records. When the brush fills them, the history is compacted
# into box stamps of its merged rectangles (compact_edits), so the practical
# bound is the native construction budget of MAX_RUNS rectangles.
const MAX_STAMPS := 4096
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

const DEFAULT_LABEL := "my-canvas"
const BENCH_LABEL := "bench-canvas"
const WATER := 3
const SAND := 2
const WALL := 58
const STONE := 13
const LAVA := 8
const OIL := 16
const ACID := 12
const WOOD := 7
const ICE := 9
const METAL := 28
const SALT := 23
const SODIUM := 25
const GUNPOWDER := 26
const COAL := 27
const STRESS_LABEL := "stress-canvas"
const BUILTIN_LABELS := [DEFAULT_LABEL,BENCH_LABEL,STRESS_LABEL]
const SMOKE := 4
const FIRE := 6
const PLANT := 11
const DUST := 14
const MITE := 15
const ROCKET := 17
const FUNGUS := 18
const SEED := 19
const SLUSH := 21
const STEAM := 22
const BRINE := 24
const RUST := 29
const CEMENT := 30
const TOXIC_SLUDGE := 32
const MERCURY := 33
const SPARK := 34
const GLASS := 35
const MOLTEN_GLASS := 36
const OAK_TIMBER := 46
const THATCH := 47
const PINE_PLANKS := 81
const CARDBOARD := 93
const MARBLE := 98
const CHALK := 99
const BASALT := 100
const OBSIDIAN := 101
const ADOBE := 102
const RAW_CLAY := 103
const PACKED_SNOW := 105
const ROCK_SALT := 106
const GYPSUM := 107
const QUICKLIME := 108
const RAMMED_EARTH := 109
const SANDBAG := 110
const ZINC := 113
const MAGNESIUM := 115
const THERMITE := 116
const BARE_IRON := 117
const GLASS_BLOCK := 120
const FROSTED_GLASS := 121
const QUARTZ := 122
const URANIUM_GLASS := 123
const SUGAR_GLASS := 124
const WAX := 125
const SULFUR := 126
const PHOSPHOR := 127
const POLYMER := 128
# Starting paint may also use these staged materials (built-in stress canvas);
# the brush palette and powder sources stay limited to MATERIALS.
const STAGED_MATERIALS := [SMOKE,FIRE,PLANT,MITE,ROCKET,FUNGUS,SLUSH,STEAM,BRINE,CEMENT,TOXIC_SLUDGE,
	MERCURY,SPARK,GLASS,MOLTEN_GLASS,OAK_TIMBER,THATCH,PINE_PLANKS,CARDBOARD,MARBLE,CHALK,BASALT,OBSIDIAN,
	ADOBE,RAW_CLAY,PACKED_SNOW,ROCK_SALT,GYPSUM,QUICKLIME,RAMMED_EARTH,SANDBAG,ZINC,MAGNESIUM,THERMITE,
	BARE_IRON,GLASS_BLOCK,FROSTED_GLASS,QUARTZ,URANIUM_GLASS,SUGAR_GLASS,WAX,SULFUR,PHOSPHOR,POLYMER]

static func _box(edits: Array, from: Vector2i, to: Vector2i, material: int) -> void:
	edits.append([from.x,from.y,to.x-from.x,to.y-from.y,material])

static func _fill(edits: Array, from: Vector2i, to: Vector2i, radius: int, material: int) -> void:
	# Disc centres stay inset by the radius, so a fill never paints outside its box.
	for x: int in range(from.x+radius,to.x-radius+1,radius):
		for y: int in range(from.y+radius,to.y-radius+1,radius):
			edits.append([x,y,radius,material])

static func _wall(edits: Array, from: Vector2i, to: Vector2i, radius: int = 4) -> void:
	var length := maxi(absi(to.x-from.x),absi(to.y-from.y))
	for step: int in range(0,length+1,radius):
		var at := Vector2(from).lerp(Vector2(to),float(step)/float(maxi(length,1)))
		edits.append([int(at.x),int(at.y),radius,WALL])

# Built-in "my-canvas" water evaluation start (used only while no user file of
# that name exists). One 480 × 270 view at the default camera holds, left to
# right: a free-standing dam-break column (wall of water / face release), a sand
# bank in its path (LA-Selective × Water), a pool under two staggered barrels
# (Rapier impact splash) and an unequal U-tube (pressure equalization; equal
# final levels are the vented/shared-pressure control). The Water family and
# the experimental spray controls stay whatever the panels select.
static func water_evaluation(policy: PackedInt32Array) -> Dictionary:
	var data := fresh(policy,Vector2i(512,512))
	var edits: Array = data.edits
	_fill(edits,Vector2i(8,112),Vector2i(84,258),8,WATER)        # dam-break column
	_fill(edits,Vector2i(150,214),Vector2i(328,258),8,WATER)     # barrel pool
	_fill(edits,Vector2i(338,120),Vector2i(398,258),6,WATER)     # U-tube high limb
	_fill(edits,Vector2i(398,228),Vector2i(472,258),6,WATER)     # U-tube low limb and bend
	for x: int in range(92,140,4):                               # sand ramp rising to the weir
		_fill(edits,Vector2i(x,258-(x-86)*3/5),Vector2i(x+6,258),3,SAND)
	_wall(edits,Vector2i(0,264),Vector2i(511,264))               # floor
	_wall(edits,Vector2i(3,24),Vector2i(3,264))                  # left boundary
	_wall(edits,Vector2i(477,24),Vector2i(477,264))              # right boundary
	_wall(edits,Vector2i(146,200),Vector2i(146,264),3)           # pool weir (dam surge spills over)
	_wall(edits,Vector2i(333,108),Vector2i(333,264))             # pool / U-tube wall
	_wall(edits,Vector2i(404,112),Vector2i(404,240),3)           # U-tube divider, open below
	data.actors = [instance(BARREL,1,Vector2(206,36)),instance(BARREL,2,Vector2(270,124))]
	data.next_id = 3
	data.material = WATER
	return data

# Built-in "bench-canvas" whole-engine benchmark start (used only while no user
# file of that name exists). 1024 x 512 with eight barrels over four reacting
# zones, left to right: a Water dam column against a sand dune under a falling
# sand curtain; a lava basin fed by a Water shelf and hanging ice; an oil-on-
# Water tank under a wood deck with gunpowder, coal and a lava drip; an acid
# bath taking falling metal beside a brine pool with salt and sodium. Powder,
# liquid, thermal, combustion, chemistry and body coupling all run at once.
static func engine_benchmark(policy: PackedInt32Array) -> Dictionary:
	var data := fresh(policy,Vector2i(1024,512))
	var edits: Array = data.edits
	# A: dam and dune.
	_fill(edits,Vector2i(8,296),Vector2i(92,500),12,WATER)
	for x: int in range(98,246,6):
		_fill(edits,Vector2i(x,500-(x-92)*6/10),Vector2i(x+8,500),4,SAND)
	_fill(edits,Vector2i(132,150),Vector2i(232,214),8,SAND)
	# B: lava basin, Water shelf and hanging ice.
	_fill(edits,Vector2i(268,436),Vector2i(494,500),10,LAVA)
	_fill(edits,Vector2i(272,236),Vector2i(398,296),10,WATER)
	_fill(edits,Vector2i(420,360),Vector2i(472,412),8,ICE)
	# C: oil on Water, wood deck, gunpowder, coal and a lava drip.
	_fill(edits,Vector2i(518,462),Vector2i(754,500),8,WATER)
	_fill(edits,Vector2i(518,418),Vector2i(754,462),8,OIL)
	_fill(edits,Vector2i(690,340),Vector2i(742,366),6,GUNPOWDER)
	_fill(edits,Vector2i(530,342),Vector2i(586,366),6,COAL)
	_fill(edits,Vector2i(616,292),Vector2i(660,332),8,LAVA)
	# D: acid bath with falling metal; brine pool with salt and sodium.
	_fill(edits,Vector2i(778,448),Vector2i(890,500),8,ACID)
	_fill(edits,Vector2i(800,380),Vector2i(864,428),8,METAL)
	_fill(edits,Vector2i(902,440),Vector2i(1010,500),8,WATER)
	_fill(edits,Vector2i(916,356),Vector2i(964,404),8,SALT)
	_fill(edits,Vector2i(978,376),Vector2i(1002,400),4,SODIUM)
	# Structure, painted last.
	_wall(edits,Vector2i(0,506),Vector2i(1023,506))
	_wall(edits,Vector2i(3,24),Vector2i(3,506))
	_wall(edits,Vector2i(1020,24),Vector2i(1020,506))
	_wall(edits,Vector2i(262,404),Vector2i(262,506))
	_wall(edits,Vector2i(500,404),Vector2i(500,506))
	_wall(edits,Vector2i(270,302),Vector2i(400,302),3)
	_wall(edits,Vector2i(512,376),Vector2i(512,506))
	_wall(edits,Vector2i(760,376),Vector2i(760,506))
	for x: int in range(520,752,4): edits.append([x,372,3,WOOD])
	_wall(edits,Vector2i(772,404),Vector2i(772,506))
	_wall(edits,Vector2i(896,404),Vector2i(896,506),3)
	_wall(edits,Vector2i(1014,404),Vector2i(1014,506))
	var spots := [[60,240],[176,96],[330,190],[452,300],[600,250],[716,300],[832,320],[950,300]]
	data.actors = []
	for i: int in spots.size():
		data.actors.append(instance(BARREL,i+1,Vector2(spots[i][0],spots[i][1])))
	data.next_id = spots.size()+1
	data.material = LAVA
	return data

# Built-in "stress-canvas" heavy-activity start (used only while no user file
# of that name exists). 2048 x 1024, two tiers of eight zones; the shelf
# between them has pour gaps so upper-tier products fall into the lower tier.
# Most simulated materials and every reactive building material are staged
# against their authored pair partners, thermal sources or combustion, with
# eight barrels dropped into the pools. Cloner is excluded (unbounded growth).
static func stress_canvas(policy: PackedInt32Array) -> Dictionary:
	var data := fresh(policy,Vector2i(2048,1024))
	var e: Array = data.edits
	# ---- Upper tier (shelf at y 512). ----
	# U0 snowfield: packed snow and ice under salt, with a steam pocket.
	_box(e,Vector2i(12,420),Vector2i(244,508),PACKED_SNOW)
	_box(e,Vector2i(40,330),Vector2i(120,410),ICE)
	_box(e,Vector2i(150,360),Vector2i(230,410),STEAM)
	_box(e,Vector2i(60,200),Vector2i(200,240),SALT)
	# U1 glassworks: glass pillars under a hanging lava slab.
	var glasses := [GLASS,GLASS_BLOCK,FROSTED_GLASS,QUARTZ,URANIUM_GLASS]
	for i: int in glasses.size():
		_box(e,Vector2i(268+i*46,400),Vector2i(306+i*46,508),glasses[i])
	_box(e,Vector2i(272,250),Vector2i(496,310),LAVA)
	# U2 pyrotechnics: woods, gunpowder, magnesium and thermite under fire.
	var fuels := [PINE_PLANKS,OAK_TIMBER,THATCH,CARDBOARD,WOOD,GUNPOWDER,MAGNESIUM,THERMITE]
	for i: int in fuels.size():
		_box(e,Vector2i(524+i*30,420),Vector2i(552+i*30,508),fuels[i])
	_box(e,Vector2i(524,404),Vector2i(672,420),FIRE)              # fire on the woods
	_box(e,Vector2i(674,410),Vector2i(762,420),SPARK)             # sparks on the charges
	_box(e,Vector2i(560,300),Vector2i(720,330),OIL)               # oil slick dripping onto the fire
	# U3 foundry: wax, sulfur, polymer, phosphor and sugar glass under lava.
	var melts := [WAX,SULFUR,POLYMER,PHOSPHOR,SUGAR_GLASS]
	_box(e,Vector2i(918,420),Vector2i(956,430),FIRE)              # phosphor needs open fire
	for i: int in melts.size():
		_box(e,Vector2i(780+i*46,430),Vector2i(818+i*46,508),melts[i])
	_box(e,Vector2i(790,300),Vector2i(1010,350),LAVA)
	_box(e,Vector2i(960,200),Vector2i(1010,250),WATER)
	# U4 avalanche: sand, dust, rust and coal hills over a pour gap.
	_box(e,Vector2i(1036,120),Vector2i(1150,360),SAND)
	_box(e,Vector2i(1150,160),Vector2i(1268,360),DUST)
	_box(e,Vector2i(1060,380),Vector2i(1140,470),RUST)
	_box(e,Vector2i(1160,380),Vector2i(1250,470),COAL)
	# U5 biology: plant, seed, fungus and mites by a pool.
	_box(e,Vector2i(1292,440),Vector2i(1420,508),WATER)
	_box(e,Vector2i(1430,400),Vector2i(1524,508),PLANT)
	_box(e,Vector2i(1300,360),Vector2i(1400,400),SEED)
	_box(e,Vector2i(1440,330),Vector2i(1520,380),FUNGUS)
	_box(e,Vector2i(1320,250),Vector2i(1500,290),MITE)
	# U6 sludge: toxic sludge, Water, mercury and slush.
	_box(e,Vector2i(1548,450),Vector2i(1660,508),TOXIC_SLUDGE)
	_box(e,Vector2i(1560,300),Vector2i(1660,380),WATER)
	_box(e,Vector2i(1680,450),Vector2i(1780,508),MERCURY)
	_box(e,Vector2i(1690,330),Vector2i(1780,400),SLUSH)
	# U7 oil depot: oil tank under sparks, cement with Water, a rocket stack.
	_box(e,Vector2i(1804,430),Vector2i(1940,508),OIL)
	_box(e,Vector2i(1820,330),Vector2i(1920,360),SPARK)
	_box(e,Vector2i(1950,440),Vector2i(2036,508),CEMENT)
	_box(e,Vector2i(1956,300),Vector2i(2030,360),WATER)
	_box(e,Vector2i(1860,412),Vector2i(1900,430),ROCKET)          # rockets on the oil tank
	# ---- Lower tier (floor at y 1016). ----
	# L0 volcano: lava lake, basalt and obsidian under Water rain.
	_box(e,Vector2i(12,930),Vector2i(244,1012),LAVA)
	_box(e,Vector2i(30,850),Vector2i(110,930),BASALT)
	_box(e,Vector2i(140,850),Vector2i(220,930),OBSIDIAN)
	_box(e,Vector2i(40,600),Vector2i(220,680),WATER)
	# L1 quench trough under the glassworks pour gap, with molten glass.
	_box(e,Vector2i(268,930),Vector2i(496,1012),WATER)
	_box(e,Vector2i(300,700),Vector2i(460,760),MOLTEN_GLASS)
	# L2 chemistry: acid bath taking metals, marble and chalk.
	_box(e,Vector2i(524,900),Vector2i(760,1012),ACID)
	var reagents := [METAL,BARE_IRON,ZINC,MARBLE,CHALK]
	for i: int in reagents.size():                                # submerged blocks
		_box(e,Vector2i(536+i*46,950),Vector2i(566+i*46,1012),reagents[i])
	_box(e,Vector2i(560,780),Vector2i(720,820),METAL)             # falling metal powder
	# L3 salt lake: Water with salt, rock salt and sodium; brine under fire.
	_box(e,Vector2i(780,930),Vector2i(890,1012),WATER)
	_box(e,Vector2i(900,930),Vector2i(1010,1012),BRINE)
	_box(e,Vector2i(800,960),Vector2i(840,1012),ROCK_SALT)        # submerged rock salt
	_box(e,Vector2i(790,860),Vector2i(850,900),SALT)
	_box(e,Vector2i(860,820),Vector2i(890,850),SODIUM)
	_box(e,Vector2i(920,840),Vector2i(1000,880),FIRE)
	# L4 earthworks: Water released over clays, earths, gypsum and quicklime.
	var earths := [ADOBE,RAW_CLAY,RAMMED_EARTH,GYPSUM,QUICKLIME,SANDBAG]
	for i: int in earths.size():
		_box(e,Vector2i(1036+i*38,930),Vector2i(1068+i*38,1012),earths[i])
	_box(e,Vector2i(1040,700),Vector2i(1260,780),WATER)
	# L5 refinery fire: oil on Water with coal and a fire front.
	_box(e,Vector2i(1292,960),Vector2i(1524,1012),WATER)
	_box(e,Vector2i(1292,910),Vector2i(1524,960),OIL)
	_box(e,Vector2i(1300,860),Vector2i(1380,910),COAL)
	_box(e,Vector2i(1420,896),Vector2i(1510,910),FIRE)            # fire front on the oil
	# L6 dam break against a sand bank.
	_box(e,Vector2i(1548,620),Vector2i(1650,1012),WATER)
	for x: int in range(1660,1780,8):                              # stepped bank
		_box(e,Vector2i(x,1012-(x-1650)*5/8),Vector2i(x+8,1012),SAND)
	# L7 thermal clash: lava against ice and packed snow, glass shards.
	_box(e,Vector2i(1804,940),Vector2i(1920,1012),LAVA)
	_box(e,Vector2i(1930,900),Vector2i(2036,1012),PACKED_SNOW)
	_box(e,Vector2i(1830,760),Vector2i(1920,840),ICE)
	_box(e,Vector2i(1940,760),Vector2i(2020,820),GLASS)
	# ---- Structure, painted last. ----
	_box(e,Vector2i(0,1012),Vector2i(2048,1024),WALL)              # floor
	_box(e,Vector2i(0,16),Vector2i(8,1012),WALL)                   # sides
	_box(e,Vector2i(2040,16),Vector2i(2048,1012),WALL)
	# Shelf with pour gaps under the glassworks, avalanche and sludge zones.
	for span: Array in [[8,380],[400,1180],[1220,1600],[1620,2040]]:
		_box(e,Vector2i(span[0],508),Vector2i(span[1],516),WALL)
	for x: int in range(256,2048,256):                             # zone dividers
		_box(e,Vector2i(x-4,420),Vector2i(x+4,508),WALL)
		_box(e,Vector2i(x-4,880),Vector2i(x+4,1012),WALL)
	_box(e,Vector2i(268,316),Vector2i(496,322),GLASS)              # glass shelf under the lava slab (melts)
	var spots := [[350,560],[640,700],[840,700],[960,760],[1150,600],[1400,700],[1600,540],[1980,640]]
	for i: int in spots.size():
		data.actors.append(instance(BARREL,i+1,Vector2(spots[i][0],spots[i][1])))
	data.next_id = spots.size()+1
	data.material = WATER
	return data

static func builtin(label: String, policy: PackedInt32Array) -> Dictionary:
	if label == DEFAULT_LABEL: return water_evaluation(policy)
	if label == BENCH_LABEL: return engine_benchmark(policy)
	if label == STRESS_LABEL: return stress_canvas(policy)
	return {}

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

static func _keys(obj: Variant, fields: Array) -> bool:
	return obj is Dictionary and obj.size() == fields.size() and obj.has_all(fields)

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= low and value <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and floor(value) == value

static func _actor_error(a: Variant, size: Vector2i, response: String) -> String:
	if not _keys(a,["id","model","hash","spawn","options"]) or not _integer(a.id,1,2147483646) or not a.model is String:
		return "Invalid actor fields or instance ID."
	var model := str(a.model)
	var index := Fleet.index_for_id(model)
	if model != BARREL and index < 0:
		return "Unavailable actor definition: " + model
	if a.hash != (Fleet.definition_hash(index) if index >= 0 else "reference-barrel-v1"):
		return "Definition changed for " + model + ". Reload definitions or use its original authoring records."
	if not a.spawn is Array or a.spawn.size() != 2 or not _number(a.spawn[0],0,size.x) or not _number(a.spawn[1],0,size.y):
		return "Invalid saved spawn."
	var body_bounds := bounds(model)
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

# A stamp is a brush disc [x, y, radius, material] or an axis-aligned box
# [x, y, width, height, material] (built-in starts; never produced by the brush).
static func _stamp_valid(stamp: Variant, size: Vector2i) -> bool:
	if not stamp is Array or not _integer(stamp[0] if stamp.size() > 0 else null,0,size.x-1) 			or not _integer(stamp[1] if stamp.size() > 1 else null,0,size.y-1):
		return false
	if stamp.size() == 4:
		return _integer(stamp[2],2,24) and _stamp_material(stamp[3])
	return stamp.size() == 5 and _integer(stamp[2],1,size.x-int(stamp[0])) 		and _integer(stamp[3],1,size.y-int(stamp[1])) and _stamp_material(stamp[4])

# Rows a stamp can touch (the brush's coalesced-capacity estimate).
static func stamp_rows(stamp: Array) -> int:
	return int(stamp[3]) if stamp.size() == 5 else 2*int(stamp[2])+1

static func _stamp_material(value: Variant) -> bool:
	return _material(value) or (_integer(value,0,255) and int(value) in STAGED_MATERIALS)

static func validate(value: Variant, check_starting_paint: bool = true) -> String:
	if not _keys(value,ROOT_KEYS) or not _integer(value.version,2,2):
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
		var error := _actor_error(a,size,str(value.response))
		if not error.is_empty(): return error
		if ids.has(int(a.id)) or a.id >= value.next_id: return "Duplicate or retired instance ID."
		ids[int(a.id)] = true
	if not _integer(value.selected,0,2147483646) or (value.selected != 0 and not ids.has(int(value.selected))):
		return "Selected instance does not exist."
	if not value.edits is Array: return "Invalid starting paint history."
	if check_starting_paint:
		if value.edits.size() > MAX_STAMPS: return "Starting paint capacity exhausted."
		for stamp: Variant in value.edits:
			if not _stamp_valid(stamp,size): return "Invalid brush stamp."
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
		result.append({"model":actor.model,"instance_id":int(actor.id),"producer":"passive" if actor.model == BARREL else "human",
			"position":point(actor.spawn),"workbench_options":options,"canvas_extent":extent_of(setup)})
	return result

# Discs use the same integer circle and clipped extent as native paint_disc.
# Coalesce each affected row; repeated edits over the same area do not consume
# a rectangle for every historical stamp. Empty spans vanish from a blank recipe.
static func rectangles(setup: Dictionary) -> Dictionary:
	var size := extent_of(setup)
	var rows := {}
	for stamp: Array in setup.edits:
		if stamp.size() == 5:
			for row_y: int in range(int(stamp[1]),int(stamp[1])+int(stamp[3])):
				if not rows.has(row_y):
					var blank := PackedByteArray()
					blank.resize(size.x)
					rows[row_y] = blank
				var box_row: PackedByteArray = rows[row_y]
				for column: int in range(int(stamp[0]),int(stamp[0])+int(stamp[2])): box_row[column] = int(stamp[4])
			continue
		var x := int(stamp[0])
		var y := int(stamp[1])
		var radius := int(stamp[2])
		for dy: int in range(maxi(-radius,-y),mini(radius,size.y-1-y)+1):
			var half := floori(sqrt(radius*radius-dy*dy))
			var row_y := y+dy
			if not rows.has(row_y):
				var empty := PackedByteArray()
				empty.resize(size.x)
				rows[row_y] = empty
			var row: PackedByteArray = rows[row_y]
			for column: int in range(maxi(0,x-half),mini(size.x,x+half+1)):
				row[column] = int(stamp[3])
	# A run identical (start, width, material) to one ending on the previous
	# row extends that rectangle downward, so painted boxes cost one record.
	# The rectangles never overlap; they cover exactly the painted cells.
	var runs := []
	var open := {}
	var row_keys := rows.keys()
	row_keys.sort()
	for y: int in row_keys:
		var row: PackedByteArray = rows[y]
		var x := 0
		while x < size.x:
			var start := x
			var mat := int(row[x])
			while x < size.x and row[x] == mat: x += 1
			if mat == 0: continue
			var key := Vector3i(start,x-start,mat)
			var index: int = open.get(key,-1)
			if index >= 0 and int(runs[index+1])+int(runs[index+3]) == y:
				runs[index+3] = int(runs[index+3])+1
				continue
			if runs.size() >= MAX_RUNS*5: return {"error":"Starting terrain exceeds 4096 rectangles."}
			open[key] = runs.size()
			runs.append_array([start,y,x-start,1,mat])
	return {"runs":runs}


# The same starting cells as box stamps of the merged rectangles: erased and
# overpainted strokes disappear (Erase runs are never recorded).
static func compact_edits(setup: Dictionary) -> Dictionary:
	var result := rectangles(setup)
	if result.has("error"): return result
	var runs: Array = result.runs
	var edits := []
	for i: int in range(0, runs.size(), 5):
		edits.append([int(runs[i]), int(runs[i+1]), int(runs[i+2]), int(runs[i+3]), int(runs[i+4])])
	return {"edits": edits}

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
