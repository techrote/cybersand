class_name CyberPlayerPlaygroundNeonWorks
extends RefCounted

# Existing Water/BareIron reactions reset fractional Water quantity. These
# comparison maps use already-rusted steel65 instead of bare iron117. See the
# dated cyberpunk audit; the native reaction semantics are unchanged.

# Connected cutaway works: every apparatus belongs to an accessible room,
# supported gantry or maintenance bay. The ordinary road remains independent.
const D = preload("res://scripts/player_playground_districts.gd")
const Detail = preload("res://scripts/player_playground_neon_detail.gd")
const VIEW := Rect2i(0,0,1024,768)
const IDS: Array[StringName] = [&"zero_stamp_customs",&"last_byte_reclamation",&"rain_ledger_exchange",&"pirate_uplink"]
const NAMES: Array[String] = ["Zero-Stamp Customs · lander","Last Byte Reclamation · Sand cloud",
	"Rain Ledger Exchange · Water blob","Pirate Uplink · jet barrel"]
const HINTS: Array[String] = [
	"Enter the inspection canyon through its open underside, brake in the numbered bays and cross the overhead customs hall. The stamped service road and recovery courts remain open to everyone.",
	"Score the marked side seal and guide reclaimed grains sideways through the sorting arcade into the real catch. The processing rooms and loose deflectors are optional; the loading road has a graded return.",
	"Open the Water seal, follow the broad stepped exchange channels and collect in the open shared catch. Brine has its own sealed branch. These are vented gravity experiments, without a sealed equal-level or siphon claim.",
	"Fly the irregular rooftop dishes and flue gaps, cross the open relay rooms and leave through the lateral uplink hatch. Broad recovery roofs and the undercroft road provide a continuous return."]
const SUGGESTED: Array[StringName] = [&"arcadelander",&"dryswarm",&"liquidswarm",&"jetbarrel"]
const PROFILES: Dictionary = {
	&"zero_stamp_customs":[Vector2i(6,704),Vector2i(320,704),Vector2i(576,640),Vector2i(700,640),Vector2i(956,704),Vector2i(1018,704)],
	&"last_byte_reclamation":[Vector2i(6,552),Vector2i(320,552),Vector2i(592,620),Vector2i(744,620),Vector2i(1016,552),Vector2i(1018,552)],
	&"rain_ledger_exchange":[Vector2i(6,640),Vector2i(320,640),Vector2i(576,704),Vector2i(744,704),Vector2i(1000,640),Vector2i(1018,640)],
	&"pirate_uplink":[Vector2i(6,712),Vector2i(320,712),Vector2i(576,648),Vector2i(720,648),Vector2i(976,712),Vector2i(1018,712)]}


static func floor_y(id: StringName) -> int:
	return int(PROFILES.get(id,PROFILES[IDS[0]])[0].y)


static func spawn(id: StringName) -> Vector2:
	return Vector2(88,floor_y(id)-64)


static func road_y(id: StringName, x: int) -> int:
	return Detail.road_y(PROFILES.get(id,PROFILES[IDS[0]]),x)


static func checkpoints(id: StringName) -> PackedVector2Array:
	var points := PackedVector2Array()
	for x: int in [262,450,720,990]: points.append(Vector2(x,road_y(id,x)-12))
	return points


static func npc_spawns(id: StringName) -> PackedVector2Array:
	# A full stage also clears the six-cell rise across a 48-cell graded patch.
	var first: int = 456 if id == &"rain_ledger_exchange" else 366
	return PackedVector2Array([Vector2(first,road_y(id,first)-42),Vector2(918,road_y(id,918)-42)])


static func reservoirs(id: StringName) -> Array[Dictionary]:
	match id:
		&"last_byte_reclamation": return [{"bounds":Rect2i(741,286,198,146),"material":3},{"bounds":Rect2i(363,654,198,96),"material":16}]
		&"rain_ledger_exchange": return [{"bounds":Rect2i(335,176,218,146),"material":3},{"bounds":Rect2i(739,204,222,166),"material":24}]
		&"pirate_uplink": return [{"bounds":Rect2i(365,384,200,138),"material":3},{"bounds":Rect2i(757,314,192,146),"material":16}]
	return [{"bounds":Rect2i(377,438,180,128),"material":3},{"bounds":Rect2i(751,280,180,170),"material":24}]


static func reservoir_outlet(id: StringName) -> Vector2i:
	var x: int = 470
	if id == &"last_byte_reclamation": x = 848
	elif id == &"rain_ledger_exchange": x = 400
	return Vector2i(x,road_y(id,x)-52)


static func props(id: StringName) -> Array[Dictionary]:
	match id:
		&"last_byte_reclamation": return [_prop(304,326,20,24,3.0,"bfa56b"),_prop(608,368,20,24,3.2,"a39ec4"),_prop(986,418,24,26,4.5,"9bb8be")]
		&"rain_ledger_exchange": return [_prop(264,456,20,22,2.4,"9abfc9"),_prop(938,480,24,26,4.0,"baa4cc"),_prop(360,576,20,22,2.0,"aaa9be")]
		&"pirate_uplink": return [_prop(250,266,20,24,3.0,"ae96ca"),_prop(618,446,20,24,3.4,"8ab5c1"),_prop(930,544,24,24,4.5,"b69c6d")]
	return [_prop(412,340,22,22,4.0,"b1b8c6"),_prop(688,444,20,24,3.5,"9ec4ca"),_prop(954,442,18,28,5.0,"bda3c8")]


static func _prop(x: float, y: float, w: float, h: float, mass: float, color: String) -> Dictionary:
	return {"position":Vector2(x,y),"size":Vector2(w,h),"mass":mass,"color":Color(color)}


static func _slab(out: Array, x: int, y: int, w: int, material: int = 62, trim: int = 77) -> void:
	D.rect(out,x,y,w,8,material)
	D.rect(out,x+3,y,w-6,2,trim)
	for xx: int in range(x+8,x+w-5,30): D.rect(out,xx,y+3,3,3,50)


static func _room(out: Array, x: int, y: int, w: int, h: int, label: String, ink: int = 77) -> void:
	_slab(out,x,y,w,62,ink)
	_slab(out,x,y+h,w,62,ink)
	D.rect(out,x,y+8,8,h-8,113)
	D.rect(out,x+w-8,y+8,8,h-8,113)
	# Both sides have genuine doors. The front is a cutaway, not a solid fill
	# with painted windows that the player could mistake for accessible space.
	D.rect(out,x,y+h-76,8,60,0)
	D.rect(out,x+w-8,y+h-76,8,60,0)
	Detail.sign(out,x+18,y+18,label,ink,2)
	for yy: int in range(y+14,y+h-80,28):
		D.rect(out,x+2,yy,4,8,50)
		D.rect(out,x+w-6,yy+10,4,8,50)
	for xx: int in range(x+20,x+w-38,54):
		D.cargo(out,xx,y+h-30,30,22,81)
		D.rect(out,xx+4,y+h-36,22,4,ink)
		D.rect(out,xx+4,y+h-8,4,8,50)
		D.rect(out,xx+22,y+h-8,4,8,50)


static func _beam(out: Array, x: int, y: int, w: int, ink: int = 78) -> void:
	_slab(out,x,y,w,65,ink)
	for xx: int in range(x+10,x+w-14,24):
		for step: int in range(4): D.rect(out,xx+step*3,y+8+step*2,3,2,50)


static func layout(id: StringName) -> Array:
	var out: Array = []
	Detail.edge(out)
	Detail.road(out,PROFILES.get(id,PROFILES[IDS[0]]),58)
	match id:
		&"last_byte_reclamation": _reclamation(out)
		&"rain_ledger_exchange": _exchange(out)
		&"pirate_uplink": _uplink(out)
		_: _customs(out)
	return out


static func _customs(out: Array) -> void:
	var id: StringName = &"zero_stamp_customs"
	# A long overhead terminal contains three inspection bays. Open floor
	# mouths connect its canyon to the service road, without a sealed shaft.
	_room(out,36,202,252,300,"ARRIVALS",77)
	_room(out,324,100,650,484,"ZERO-STAMP",78)
	# Wall anchors and roof hangers make the elevated terminal deliberately
	# suspended; the dry service road is a clear undercroft, not a fake pier.
	D.rect(out,6,202,30,10,65)
	for x: int in [324,966]: D.rect(out,x,6,8,94,65)
	for x: int in [358,388,418,448,478,508]:
		D.rect(out,x,112,18,4,72)
		D.rect(out,x+3,113,5,2,77)
	D.rect(out,324,370,8,110,0)
	D.rect(out,966,350,8,110,0)
	D.rect(out,442,584,100,8,0)
	D.rect(out,850,584,100,8,0)
	_beam(out,276,292,144,77)
	D.rect(out,276,300,8,202,65)
	# Bay partitions hang from the real roof and stop above broad cross doors.
	for x: int in [596,714]:
		D.rect(out,x,108,10,274,113)
		D.rect(out,x-7,374,24,8,78)
	_slab(out,348,352,210,130,77)
	_slab(out,628,458,100,130,79)
	_slab(out,728,458,238,62,78)
	for x: int in [348,548]: D.rect(out,x,360,8,70,65)
	for x: int in [628,720]: D.rect(out,x,466,8,118,65)
	# Shallow inspection refuges have actual flat landing surfaces and repair
	# access under them; scan frames are open corners rather than filled caps.
	D.route_frame(out,476,182,86,118,77)
	D.route_frame(out,614,198,86,124,78)
	Detail.sign(out,360,150,"BAY 01",77,2)
	Detail.sign(out,620,400,"BAY 02",79,2)
	Detail.sign(out,814,506,"RECOVERY",78,2)
	for x: int in [342,566,738,958]: D.pipe(out,x,500,4,76,68)
	for x: int in [382,450,484]: D.rect(out,x,344,18,3,77)
	for x: int in [758,804,850,896]:
		D.rect(out,x,130,28,20,72)
		D.rect(out,x+3,138,22,2,79)
		D.rect(out,x+12,108,3,22,50)
	D.tank(out,372,430,190,136,3,71)
	D.tank(out,746,272,190,178,24,120)
	for x: int in [372,557]: D.rect(out,x,573,5,11,50)
	for x: int in [746,931]: D.rect(out,x,457,5,1,50)
	D.drain(out,470,566,reservoir_outlet(id).y)
	# Ground-level lamps stay above the entire mechanical envelope.
	Detail.sign(out,46,532,"SERVICE >",77,2)
	Detail.sign(out,844,112,"NO STAMP",78,2)
	for x: int in [350,590,966]: D.rect(out,x,750,12,6,79)


static func _reclamation(out: Array) -> void:
	var id: StringName = &"last_byte_reclamation"
	_room(out,36,124,252,286,"LAST BYTE",79)
	_room(out,704,150,306,282,"RECLAIM",78)
	D.rect(out,6,124,30,10,65)
	D.rect(out,1010,150,8,10,65)
	for x: int in [706,1002]: D.rect(out,x,6,6,144,65)
	_beam(out,280,410,434,79)
	D.rect(out,286,418,8,20,65)
	D.rect(out,690,418,8,20,65)
	_slab(out,288,438,416,104,79)
	# The featured material route crosses two SIDE apertures. Its useful void
	# is a walk-through sorting room, not another repeated vertical comb.
	D.rect(out,60,212,212,8,104)
	D.rect(out,60,220,8,134,104)
	D.rect(out,264,220,8,134,104)
	_slab(out,60,354,212,104,79)
	D.ramp_down(out,272,344,188,34,104)
	D.rect(out,68,232,196,112,2)
	D.rect(out,264,318,8,26,35)
	D.rect(out,450,260,8,118,104)
	D.rect(out,450,350,8,28,0)
	D.rect(out,272,252,186,8,62)
	D.rect(out,326,300,12,32,104)
	D.rect(out,370,274,8,58,104)
	_slab(out,464,382,176,104,77)
	D.rect(out,460,384,4,6,104)
	D.rect(out,640,344,4,46,104)
	Detail.sign(out,286,268,"SIDE SEAL",77,1)
	Detail.sign(out,472,396,"CATCH 02",79,2)
	# A clear maintenance walk surrounds the lower catch and returns through
	# both room doors. Equipment is mounted on beams and actual work benches.
	for x: int in [310,428,488,632,674]:
		D.rect(out,x,386,6,52,50)
		D.rect(out,x-4,402,14,3,78)
	for x: int in [754,798,842,886,930]:
		D.rect(out,x,178,26,20,72)
		D.rect(out,x+11,158,3,20,50)
		D.rect(out,x+3,184,20,2,78)
	D.tank(out,736,278,208,154,3,71)
	D.tank(out,358,646,208,104,16,104)
	for x: int in [736,939]: D.rect(out,x,439,5,8,50)
	D.drain(out,848,432,reservoir_outlet(id).y)
	Detail.sign(out,44,420,"LOADING >",79,2)
	Detail.sign(out,738,220,"WASH STORE",77,2)
	for x: int in range(362,560,24): D.rect(out,x,754,12,3,79)


static func _exchange(out: Array) -> void:
	var id: StringName = &"rain_ledger_exchange"
	_room(out,36,236,252,232,"RAIN DESK",77)
	_room(out,714,116,296,378,"LEDGER",78)
	D.rect(out,6,236,30,10,65)
	D.rect(out,1010,116,8,10,65)
	for x: int in [714,1002]: D.rect(out,x,6,8,110,65)
	_beam(out,278,468,154,77)
	_slab(out,320,332,256,62,77)
	D.rect(out,320,340,10,248,65)
	D.rect(out,566,340,10,10,65)
	_slab(out,720,384,270,62,78)
	D.rect(out,980,392,10,158,65)
	_slab(out,342,588,72,62,77)
	# Both large stores are open to gas. Two broad stepped branches descend
	# into one visibly empty shared catch; neither branch is a sealed siphon.
	D.tank(out,330,168,228,154,3,71)
	D.tank(out,734,196,232,174,24,120)
	D.tank(out,436,432,256,144,0,120)
	D.rect(out,532,322,20,7,35)
	D.rect(out,532,332,20,8,0)
	D.rect(out,518,332,4,48,69)
	# Each long leg has a slight real grade. Current FreeMass alone does not
	# promise pressure-driven transport along an arbitrarily long flat gutter.
	D.ramp_down(out,522,374,154,20,69)
	D.ramp(out,596,424,130,14,69)
	D.rect(out,724,370,4,46,69)
	D.rect(out,758,370,20,7,35)
	D.rect(out,672,430,228,6,69)
	D.rect(out,896,378,4,58,69)
	D.rect(out,672,436,8,6,0)
	Detail.sign(out,344,124,"WATER",77,2)
	Detail.sign(out,800,152,"BRINE",78,2)
	Detail.sign(out,484,580,"SHARED CATCH",77,1)
	for x: int in [532,758]:
		D.rect(out,x-4,318 if x == 532 else 366,4,15,50)
		D.rect(out,x+20,318 if x == 532 else 366,4,15,50)
	for x: int in [354,398,442,486,530]:
		D.rect(out,x,150,14,4,77)
		D.rect(out,x+5,140,3,10,50)
	D.drain(out,400,322,reservoir_outlet(id).y)
	Detail.sign(out,44,508,"DRY ROUTE >",77,2)
	Detail.sign(out,744,526,"VENTED",78,2)
	for x: int in [342,412,706,978]: D.rect(out,x,746,20,4,70)


static func _dish(out: Array, x: int, y: int, ink: int) -> void:
	# Faceted dish, two rim lamps and a real mast down to its roof footing.
	for i: int in range(5):
		D.rect(out,x+i*10,y+i*6,10,4,130)
		D.rect(out,x+90-i*10,y+i*6,10,4,130)
	D.rect(out,x+46,y+28,8,24,50)
	D.rect(out,x+38,y+48,24,6,62)
	D.rect(out,x,y-3,7,3,ink)
	D.rect(out,x+93,y-3,7,3,ink)


static func _uplink(out: Array) -> void:
	var id: StringName = &"pirate_uplink"
	_room(out,40,280,244,260,"PIRATE",78)
	_room(out,320,304,280,264,"RELAY",77)
	_room(out,650,148,324,410,"UPLINK",78)
	D.rect(out,6,280,34,10,65)
	_beam(out,284,304,36,78)
	for x: int in [650,966]: D.rect(out,x,6,8,142,65)
	# The lateral exit and recovery pad are unlike the Customs vertical bays.
	D.rect(out,966,350,8,64,0)
	_slab(out,934,414,74,130,77)
	_slab(out,938,470,70,130,79)
	_beam(out,276,420,76,78)
	_beam(out,592,460,82,77)
	D.rect(out,276,428,8,112,65)
	D.rect(out,592,468,8,100,65)
	D.rect(out,658,468,8,90,65)
	# Irregular roof furniture gives broad recoverable landings between masts,
	# rather than another regular central silo or repeated flight gate stamp.
	_dish(out,110,226,78)
	_dish(out,696,94,77)
	D.pipe(out,216,140,6,140,68)
	D.pipe(out,452,182,10,122,68)
	D.rect(out,442,174,30,8,65)
	D.rect(out,448,152,18,22,104)
	for yy: int in [188,216,244,272]: D.rect(out,446,yy,22,3,78)
	D.pipe(out,882,60,8,88,68)
	D.rect(out,870,56,32,6,65)
	_slab(out,846,114,84,130,77)
	D.rect(out,884,122,8,26,50)
	Detail.sign(out,330,238,"NO OWNER",77,2)
	Detail.sign(out,782,188,"SIDE EXIT >",78,2)
	Detail.sign(out,58,316,"ROOF ACCESS",78,1)
	for x: int in [72,116,160,204]:
		D.rect(out,x,358,26,20,72)
		D.rect(out,x+11,288,3,70,50)
		D.rect(out,x+3,366,20,2,78)
	D.tank(out,360,376,210,146,3,71)
	D.tank(out,752,306,202,154,16,104)
	for x: int in [360,565]: D.rect(out,x,529,5,39,50)
	for x: int in [752,949]: D.rect(out,x,467,5,91,50)
	D.rect(out,460,568,20,8,0)
	D.drain(out,470,522,reservoir_outlet(id).y)
	Detail.sign(out,48,580,"PUBLIC ROAD >",77,2)
	for x: int in [344,620,978]: D.rect(out,x,750,18,5,78)
