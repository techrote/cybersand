class_name CyberPlayerPlaygroundNeonStreets
extends RefCounted

# Existing Water/BareIron reactions reset fractional Water quantity. These
# comparison maps use already-rusted steel65 instead of bare iron117. See the
# dated cyberpunk audit; the native reaction semantics are unchanged.

const D = preload("res://scripts/player_playground_districts.gd")
const H = preload("res://scripts/player_playground_neon_detail.gd")
const VIEW := Rect2i(0,0,1024,768)
const IDS: Array[StringName] = [&"debtline_interchange",&"patchbay_tenements",&"afterhours_arcade"]
const NAMES: Array[String] = ["Debtline Interchange · buggy","Patchbay Tenements · trials bike","Afterhours Arcade · acrobat"]
const SUGGESTED: Array[StringName] = [&"stuntbuggy",&"trialsbike",&"acrobat"]
const HINTS: Array[String] = [
	"Drive the rising interchange beneath the toll block. The supported amber crest has a gentle return: hop into the striped braking zone or drive through it. Explore the cutaway repair shops, score the visible Water valve and test loose service cargo off the main lane.",
	"Climb through the tenement underpass, charge a bike hop across the shallow transfer court and recover on its broad landing. Connected apartments, washing galleries and the communal bath surround the road; all players can take the supported route.",
	"Descend past the aquarium arcade into the night court. A running double jump from the descending street reaches the open service entrance, two twelve-cell compact passages and a standing repair bay. The lower street remains open; score the aquarium's remote glass valve to release its real Water."]
const PROFILES: Dictionary = {
	&"debtline_interchange":[Vector2i(6,704),Vector2i(320,704),Vector2i(576,640),Vector2i(620,640),Vector2i(684,624),Vector2i(724,624),Vector2i(788,640),Vector2i(1018,640)],
	&"patchbay_tenements":[Vector2i(6,688),Vector2i(320,688),Vector2i(576,624),Vector2i(640,624),Vector2i(656,628),Vector2i(672,628),Vector2i(688,624),Vector2i(752,624),Vector2i(1018,668)],
	&"afterhours_arcade":[Vector2i(6,560),Vector2i(320,560),Vector2i(576,624),Vector2i(688,624),Vector2i(944,560),Vector2i(1018,560)]}


static func floor_y(id: StringName) -> int:
	return int(PROFILES.get(id,PROFILES[IDS[0]])[0].y)


static func spawn(id: StringName) -> Vector2:
	return Vector2(88,floor_y(id)-64)


static func road_y(id: StringName, x: int) -> int:
	return H.road_y(PROFILES.get(id,PROFILES[IDS[0]]),x)


static func checkpoints(id: StringName) -> PackedVector2Array:
	var result := PackedVector2Array()
	for x: int in [262,450,720,990]: result.append(Vector2(x,road_y(id,x)-12))
	return result


static func reservoirs(id: StringName) -> Array[Dictionary]:
	match id:
		&"patchbay_tenements": return [{"bounds":Rect2i(386,294,240,96),"material":3},{"bounds":Rect2i(829,92,146,182),"material":24}]
		&"afterhours_arcade": return [{"bounds":Rect2i(42,172,232,148),"material":3},{"bounds":Rect2i(815,348,160,122),"material":16}]
	return [{"bounds":Rect2i(358,192,216,154),"material":3},{"bounds":Rect2i(795,128,150,152),"material":24}]


static func reservoir_outlet(id: StringName) -> Vector2i:
	var x: int = {&"debtline_interchange":500,&"patchbay_tenements":516,&"afterhours_arcade":324}.get(id,500)
	return Vector2i(x,road_y(id,x)-52)


static func props(id: StringName) -> Array[Dictionary]:
	match id:
		&"patchbay_tenements": return [_prop(266,488,20,20,4.0,"bb9973"),_prop(704,462,20,22,4.0,"97bdc9"),_prop(986,514,20,22,5.0,"c4a985")]
		&"afterhours_arcade": return [_prop(266,408,18,20,3.0,"86b9c8"),_prop(762,540,20,22,4.0,"a6bfd0"),_prop(974,282,20,22,4.0,"c3a57b")]
	return [_prop(272,536,20,22,5.0,"bba37c"),_prop(586,538,20,20,4.0,"8db9c4"),_prop(968,510,22,24,5.0,"bd9e78")]


static func _prop(x: int,y: int,w: int,h: int,mass: float,color: String) -> Dictionary:
	return {"position":Vector2(x,y),"size":Vector2(w,h),"mass":mass,"color":Color(color)}


static func npc_spawns(id: StringName) -> PackedVector2Array:
	if id == &"afterhours_arcade":
		return PackedVector2Array([Vector2(400,road_y(id,400)-42),Vector2(866,road_y(id,866)-42)])
	return PackedVector2Array([Vector2(350,road_y(id,350)-42),Vector2(866,road_y(id,866)-42)])


static func _shell(out: Array,x: int,y: int,w: int,h: int,m: int,rooms: Array[Rect2i]) -> void:
	# Cutaway rooms are actual traversable native air, with retained shared
	# masonry/piers between them. They are not visual backdrops over solid cells.
	D.rect(out,x,y,w,h,m)
	for room: Rect2i in rooms: D.rect(out,room.position.x,room.position.y,room.size.x,room.size.y,0)
	D.rect(out,x,y,w,4,62)
	D.rect(out,x,y+h-4,w,4,50)
	for yy: int in range(y+24,y+h-10,52):
		D.rect(out,x+2,yy,3,14,64)
		D.rect(out,x+w-5,yy+5,3,9,53)


static func _sill(out: Array,x: int,y: int,w: int,m: int = 62) -> void:
	D.rect(out,x,y,w,6,m)
	D.rect(out,x+2,y,w-4,1,77)


static func _cabinet(out: Array,x: int,y: int,w: int,h: int,m: int,label: String,ink: int = 77) -> void:
	D.cargo(out,x,y,w,h,m)
	H.sign(out,x+4,y+4,label,ink,1)
	D.rect(out,x+5,y+h-7,w-10,2,50)


static func _ribbon(out: Array,x: int,y: int,w: int,m: int) -> void:
	D.rect(out,x,y,w,3,50)
	D.rect(out,x+2,y+1,w-4,1,m)
	for xx: int in range(x+12,x+w-10,36): D.rect(out,xx,y-3,2,3,68)


static func _footings(out: Array,id: StringName,columns: Array[int],m: int) -> void:
	for x: int in columns:
		var top: int = road_y(id,x)+14
		D.rect(out,x,top,10,752-top,m)
		D.rect(out,x-4,748,18,6,58)
	D.rect(out,6,754,1012,8,58)


static func layout(id: StringName) -> Array:
	var out: Array = []
	H.edge(out)
	H.road(out,PROFILES.get(id,PROFILES[IDS[0]]),58)
	match id:
		&"patchbay_tenements": _patchbay(out)
		&"afterhours_arcade": _afterhours(out)
		_: _debtline(out)
	return out


static func _debtline(out: Array) -> void:
	var id: StringName = &"debtline_interchange"
	_footings(out,id,[26,298,572,788,996],62)
	# A three-storey repair hall is physically attached to the west boundary.
	_shell(out,6,164,300,408,57,[Rect2i(24,184,264,98),Rect2i(24,306,264,100),Rect2i(24,430,264,124)])
	for y: int in [238,362,510]: D.rect(out,288,y,18,44,0)
	D.rect(out,262,270,26,36,0)
	D.rect(out,24,394,26,36,0)
	H.sign(out,36,190,"PARTS / 24",79,2)
	H.sign(out,38,314,"AXLE",77,2)
	H.sign(out,36,438,"OPEN",78,2)
	for i: int in range(4):
		_cabinet(out,36+i*52,238,44,44,[64,113,65,65][i],["A1","B2","C3","D4"][i],79)
		_cabinet(out,44+i*50,366,40,40,[87,81,102,91][i],["01","02","03","04"][i])
		D.rect(out,38+i*52,506,38,10,46)
		D.rect(out,42+i*52,490,30,16,[27,28,13,23][i])
	D.windows(out,42,108,7,34,72)
	D.rect(out,6,138,300,18,58)
	D.rect(out,22,156,10,8,50)
	D.rect(out,278,156,10,8,50)
	D.pipe(out,12,62,6,92,68)
	_ribbon(out,34,288,230,79)
	_ribbon(out,32,412,244,77)
	# Central toll block: L-shaped storage above a visible service gallery.
	_shell(out,330,112,290,460,62,[Rect2i(346,166,244,196),Rect2i(346,382,244,172)])
	D.rect(out,330,504,16,50,0)
	D.rect(out,590,504,30,50,0)
	D.rect(out,306,138,24,18,58)
	D.rect(out,620,112,122,12,58)
	D.rect(out,644,124,12,32,62)
	D.rect(out,710,124,12,32,62)
	H.sign(out,356,122,"DEBTLINE",77,2)
	H.sign(out,634,164,"TOLL",79,3)
	H.sign(out,354,394,"SERVICE",78,2)
	_cabinet(out,354,474,48,80,65,"08",79)
	_cabinet(out,418,506,48,48,64,"09",77)
	D.rect(out,552,526,22,28,131)
	D.rect(out,558,516,10,10,104)
	D.pipe(out,318,194,6,344,69)
	_ribbon(out,350,366,236,77)
	for i: int in range(4):
		D.rect(out,640+i*20,226,12,6,[53,54,62,65][i])
		D.rect(out,644+i*20,232,4,20,50)
	# The east tower encloses real rooms and a differently proportioned cistern.
	_shell(out,742,48,276,506,58,[Rect2i(760,68,240,36),Rect2i(774,108,190,192),Rect2i(762,332,238,92),Rect2i(762,448,238,84)])
	D.rect(out,742,360,20,64,0)
	D.rect(out,742,482,20,50,0)
	D.rect(out,964,220,36,80,0)
	H.sign(out,762,72,"EAST / 7",78,2)
	H.sign(out,776,306,"BRINE",77,2)
	H.sign(out,778,342,"BRAKES",79,2)
	for i: int in range(4):
		_cabinet(out,774+i*50,382,42,42,[128,131,113,130][i],["R1","R2","R3","R4"][i],79)
		D.rect(out,774+i*48,494,32,38,[81,87,102,91][i])
		D.rect(out,778+i*48,484,24,10,[29,23,27,13][i])
	D.pipe(out,1006,82,6,442,68)
	_ribbon(out,766,432,224,78)
	# Authored lane surface distinguishes takeoff and recovery without adding
	# walls. The universal route remains supported under an optional hop.
	D.rect(out,690,624,26,1,76)
	for x: int in range(760,800,4): D.rect(out,x,road_y(id,x)+2,4,2,79)
	# Reservoir interiors are stamped last. No facade, sign or repair seam is
	# allowed to partition them. The western floor step intentionally shapes L.
	D.rect(out,352,184,6,104,71)
	D.rect(out,352,282,44,6,71)
	D.rect(out,390,282,6,70,71)
	D.rect(out,574,184,6,168,71)
	D.rect(out,390,346,190,6,71)
	D.rect(out,358,192,216,90,3)
	D.rect(out,396,282,178,64,3)
	D.tank(out,790,120,160,160,24,120)
	D.drain(out,500,346,reservoir_outlet(id).y)


static func _patchbay(out: Array) -> void:
	var id: StringName = &"patchbay_tenements"
	_footings(out,id,[30,288,570,754,992],57)
	# Rooms are offset around stair/utility voids. Shared walls and crossbeams
	# make one dense housing block rather than another collection of platforms.
	_shell(out,6,48,286,480,57,[Rect2i(22,68,118,86),Rect2i(158,68,116,86),Rect2i(22,178,252,88),Rect2i(22,290,116,94),Rect2i(156,290,118,94),Rect2i(22,408,252,102)])
	D.rect(out,140,118,18,36,0)
	D.rect(out,138,336,18,48,0)
	for y: int in [118,218,336,464]: D.rect(out,274,y,18,46,0)
	D.rect(out,238,254,36,36,0)
	D.rect(out,22,372,28,36,0)
	H.sign(out,28,76,"PATCH",77,2)
	H.sign(out,166,76,"BAY",78,2)
	H.sign(out,32,188,"ROOMS / 8",79,2)
	H.sign(out,30,302,"FIX",77,2)
	H.sign(out,164,302,"RAT",78,2)
	H.sign(out,30,420,"WASH",77,2)
	for i: int in range(4):
		D.rect(out,36+i*56,244,36,20,[84,85,94,87][i])
		D.rect(out,42+i*56,236,24,8,[98,110,46,102][i])
		_cabinet(out,36+i*50,468,40,42,[65,128,131,113][i],["W1","W2","W3","W4"][i])
	D.rect(out,38,354,78,26,94)
	D.rect(out,170,356,88,24,84)
	D.windows(out,38,106,2,52,55)
	D.windows(out,170,108,2,50,72)
	D.pipe(out,12,174,5,330,69)
	_ribbon(out,28,274,238,78)
	_ribbon(out,30,392,236,79)
	# A low, wide communal bath sits between two inhabited utility galleries.
	_shell(out,330,208,326,302,98,[Rect2i(348,228,290,40),Rect2i(372,272,266,134),Rect2i(348,430,290,62)])
	D.rect(out,330,448,18,44,0)
	D.rect(out,638,446,18,46,0)
	D.rect(out,348,256,26,150,0)
	D.rect(out,292,224,38,12,62)
	H.sign(out,356,232,"PUBLIC / BATH",77,2)
	H.sign(out,352,440,"WATER / 2",79,2)
	D.rect(out,358,476,54,16,110)
	D.rect(out,566,476,54,16,46)
	D.rect(out,294,316,24,6,50)
	D.rect(out,308,322,4,108,68)
	D.rect(out,294,424,36,6,50)
	# The high service tower is tied to the ceiling and west housing by a
	# substantial bridge with open room doors and visible edge repairs.
	_shell(out,756,48,262,502,62,[Rect2i(804,68,188,220),Rect2i(774,310,228,100),Rect2i(774,434,228,98)])
	D.rect(out,756,138,48,56,0)
	D.rect(out,756,354,18,56,0)
	D.rect(out,756,480,18,52,0)
	D.rect(out,656,208,100,14,58)
	D.rect(out,674,222,8,54,62)
	D.rect(out,736,222,8,54,62)
	_sill(out,658,276,98,62)
	D.rect(out,292,48,464,10,62)
	D.rect(out,330,58,10,150,50)
	D.rect(out,646,58,10,150,50)
	H.sign(out,668,226,"NORTH",78,2)
	H.sign(out,774,72,"9",79,3)
	H.sign(out,788,314,"RENT / 0",78,2)
	H.sign(out,790,442,"LIFT",77,2)
	for i: int in range(4):
		_cabinet(out,788+i*50,368,40,42,[81,87,91,102][i],["A","B","C","D"][i],79)
		D.rect(out,788+i*46,496,30,36,[128,131,113,65][i])
		D.rect(out,792+i*46,486,22,10,[23,27,29,13][i])
	D.pipe(out,1006,96,6,428,68)
	_ribbon(out,780,416,212,77)
	# Small laundry galleries have rail gaps and full support at the buildings;
	# none is a heavy obstacle placed on the road's mandatory baseline.
	_sill(out,660,478,94,46)
	D.rect(out,656,390,4,88,50)
	D.rect(out,750,390,4,88,50)
	D.rect(out,656,390,100,4,50)
	for i: int in range(4):
		D.rect(out,664+i*22,398,16,24,[94,47,87,81][i])
		D.rect(out,670+i*22,394,3,5,50)
	D.rect(out,606,624,26,1,76)
	D.rect(out,700,624,36,1,79)
	D.tank(out,380,286,250,104,3,35)
	D.tank(out,824,84,156,190,24,120)
	D.drain(out,516,390,reservoir_outlet(id).y)


static func _afterhours(out: Array) -> void:
	var id: StringName = &"afterhours_arcade"
	_footings(out,id,[28,298,574,690,992],62)
	# Aquarium frontage: actual rooms above/below a large glass service cistern,
	# joined to the boundary and connected by a narrow service side gallery.
	_shell(out,6,106,294,332,64,[Rect2i(22,124,260,32),Rect2i(24,160,258,176),Rect2i(22,354,260,66)])
	D.rect(out,282,370,18,50,0)
	H.sign(out,28,126,"AFTERHOURS",78,2)
	H.sign(out,30,362,"TOKENS",79,2)
	D.rect(out,28,396,44,24,113)
	D.rect(out,80,396,44,24,128)
	D.rect(out,134,396,44,24,131)
	H.sign(out,32,398,"1",77,1)
	H.sign(out,84,398,"2",78,1)
	H.sign(out,138,398,"3",79,1)
	_ribbon(out,24,340,254,77)
	D.rect(out,6,74,294,16,62)
	D.rect(out,22,90,8,16,50)
	D.rect(out,276,90,8,16,50)
	H.sign(out,42,26,"OPEN / 24",77,3)
	D.rect(out,62,52,4,22,50)
	D.rect(out,190,52,4,22,50)
	# The arcade is a single connected cutaway building. Its grounded exterior
	# descending street supplies the service annex approach: jump before road
	# separation to gain the reachable entrance, rather than a34-cell wall hop.
	_shell(out,420,138,300,350,65,[Rect2i(436,158,268,96),Rect2i(436,278,268,114),Rect2i(436,412,268,36)])
	D.rect(out,420,310,16,82,0)
	D.rect(out,704,312,16,80,0)
	D.rect(out,456,488,264,76,65)
	D.rect(out,456,532,20,26,0)
	D.rect(out,476,546,90,12,0)
	D.rect(out,566,514,60,44,0)
	D.rect(out,626,546,78,12,0)
	D.rect(out,704,532,16,26,0)
	_sill(out,720,558,78,62)
	D.rect(out,786,398,12,160,65)
	D.rect(out,720,398,78,8,62)
	H.sign(out,448,172,"NIGHT / PLAY",78,2)
	H.sign(out,448,288,"PRIZE / 4",79,2)
	H.sign(out,472,500,"SERVICE",77,1)
	H.sign(out,570,500,"CTRL",78,1)
	for i: int in range(5):
		_cabinet(out,448+i*48,214,38,40,[113,65,128,131,130][i],["1","2","3","4","5"][i],[77,78,79,78,77][i])
		_cabinet(out,448+i*48,350,38,42,[64,113,65,128,131][i],["A","B","C","D","E"][i],[78,77,79,77,78][i])
	_ribbon(out,436,262,268,78)
	_ribbon(out,438,398,264,79)
	D.rect(out,300,106,120,12,62)
	D.rect(out,420,118,12,20,65)
	D.rect(out,312,118,8,24,50)
	H.sign(out,326,150,"DIVE",77,2)
	# The opposite block has real shopfronts and a wide glazed Oil service bay.
	_shell(out,806,110,212,402,62,[Rect2i(822,130,180,88),Rect2i(822,242,180,60),Rect2i(806,320,196,170)])
	D.rect(out,806,174,16,44,0)
	D.rect(out,806,264,16,38,0)
	H.sign(out,830,140,"BYTE",77,2)
	H.sign(out,830,250,"OIL",79,2)
	for i: int in range(3):
		D.rect(out,834+i*48,188,34,30,[81,87,102][i])
		D.rect(out,838+i*48,178,26,10,[23,13,27][i])
	D.rect(out,720,110,86,12,58)
	D.rect(out,744,122,6,54,50)
	H.sign(out,736,182,"RUSH",78,2)
	D.pipe(out,1006,138,6,346,68)
	_ribbon(out,826,226,172,77)
	# Stamp complete liquid interiors after all architecture. The Water feeder
	# exits east above the protected spawn promenade, then descends beyond it.
	D.rect(out,36,164,6,162,35)
	D.rect(out,274,164,6,162,35)
	D.rect(out,36,320,244,6,35)
	D.rect(out,42,172,232,148,3)
	D.rect(out,274,308,56,4,69)
	D.rect(out,274,324,56,4,69)
	D.rect(out,266,312,64,12,3)
	D.tank(out,810,340,170,130,16,35)
	D.drain(out,324,324,reservoir_outlet(id).y)
