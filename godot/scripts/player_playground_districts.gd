class_name CyberPlayerPlaygroundDistricts
extends RefCounted

# Only the outside extent is shared. Each street, silhouette, material apparatus
# and route is authored independently rather than composed from a tower stamp.
const VIEW := Rect2i(0, 0, 1024, 768)
const FLOOR: int = 736 # Compatibility only; new callers use floor_y(id).
const SPAWN := Vector2(96, 672)
const IDS: Array[StringName] = [&"mixed", &"cannon_run", &"rat_steps", &"afterimage_works",
	&"vector_port", &"dust_foundry", &"undertow_lab", &"rocket_yard"]


static func rect(out: Array, x: int, y: int, w: int, h: int, material: int) -> void:
	assert(w > 0 and h > 0 and x >= 0 and y >= 0 and x+w <= 1024 and y+h <= 768)
	out.append({"origin":Vector2i(x,y), "size":Vector2i(w,h), "material":material})


static func deck(out: Array, x: int, y: int, w: int, material: int, trim: int = 79) -> void:
	rect(out,x,y,w,7,material)
	rect(out,x+2,y,w-4,1,trim)
	for xx: int in range(x+8,x+w-6,28): rect(out,xx,y+7,3,9,68)


static func ramp(out: Array, x: int, y: int, width: int, rise: int, material: int = 58) -> void:
	for step: int in range(0,width,4):
		var height: int = maxi(1,roundi(float(step+4)*rise/width))
		rect(out,x+step,y-height,mini(4,width-step),height,material)


static func ramp_down(out: Array, x: int, y: int, width: int, drop: int, material: int) -> void:
	for step: int in range(0,width,4):
		var top: int = y+roundi(float(step)*drop/width)
		rect(out,x+step,top,mini(4,width-step),y+drop-top+1,material)


static func route_frame(out: Array, x: int, y: int, w: int, h: int, material: int = 78) -> void:
	# Optional skill routes are marked with open corners, not sealed doorways.
	for xx: int in [x,x+w-8]:
		for yy: int in [y,y+h-2]: rect(out,xx,yy,8,2,material)


static func drain(out: Array, x: int, base: int, plug: int) -> void:
	# A visible narrow glass valve connects a real reservoir to the lower road.
	# Glass Scorer opens it without deleting Water; gravity supplies the effect.
	if plug > base+7:
		rect(out,x-6,base,12,plug-base,3)
		rect(out,x-10,base+7,4,plug-base-7,69)
		rect(out,x+6,base+7,4,plug-base-7,69)
	rect(out,x-10,plug,20,7,35)
	rect(out,x-14,plug-4,4,11,76)
	rect(out,x+10,plug-4,4,11,76)
	rect(out,x-8,plug+10,16,2,77)


static func tank(out: Array, x: int, y: int, w: int, depth: int, liquid: int, wall: int = 71) -> void:
	# Open tops, eight cells of freeboard and substantial finite liquid depth.
	rect(out,x,y,5,depth+7,wall)
	rect(out,x+w-5,y,5,depth+7,wall)
	rect(out,x,y+depth,w,7,wall)
	rect(out,x+5,y+8,w-10,depth-8,liquid)
	for yy: int in range(y+12,y+depth-6,24):
		rect(out,x-2,yy,2,4,53)
		rect(out,x+w,yy,2,4,53)


static func ribs(out: Array, x: int, y: int, w: int, h: int, material: int, spacing: int = 24) -> void:
	rect(out,x,y,w,h,material)
	for yy: int in range(y+5,y+h-3,spacing): rect(out,x+2,yy,w-4,2,65)


static func windows(out: Array, x: int, y: int, count: int, spacing: int, material: int = 55) -> void:
	for i: int in range(count):
		rect(out,x+i*spacing,y,14,20,material)
		rect(out,x+i*spacing+3,y+3,8,14,72)
		rect(out,x+i*spacing-1,y+20,16,2,50)


static func pipe(out: Array, x: int, y: int, w: int, h: int, material: int = 68) -> void:
	rect(out,x,y,w,h,material)
	if w > h:
		for xx: int in range(x+8,x+w-4,32): rect(out,xx,y-2,3,h+4,50)
	else:
		for yy: int in range(y+8,y+h-4,32): rect(out,x-2,yy,w+4,3,50)


static func canopy(out: Array, x: int, y: int, w: int, cloth: int) -> void:
	rect(out,x,y,w,4,cloth)
	for xx: int in range(x+3,x+w-4,16): rect(out,xx,y+4,8,4,cloth)
	rect(out,x+4,y+8,3,24,46)
	rect(out,x+w-7,y+8,3,24,46)


static func cargo(out: Array, x: int, y: int, w: int, h: int, material: int) -> void:
	rect(out,x,y,w,h,material)
	rect(out,x+2,y+2,w-4,2,50)
	rect(out,x+2,y+h-4,w-4,2,50)
	rect(out,x+3,y+3,2,h-6,50)
	rect(out,x+w-5,y+3,2,h-6,50)


static func lamps(out: Array, points: Array, color: int = 77) -> void:
	for point: Vector2i in points:
		# Suspended wayfinding lights keep the lower vehicle lane clear.
		rect(out,point.x,point.y-24,2,12,50)
		rect(out,point.x-3,point.y-24,8,2,color)


static func spawn(id: StringName) -> Vector2:
	match id:
		&"cannon_run": return Vector2(80,656)
		&"rat_steps": return Vector2(92,632)
		&"afterimage_works": return Vector2(80,636)
		&"vector_port": return Vector2(112,646)
		&"dust_foundry": return Vector2(88,640)
		&"undertow_lab": return Vector2(80,636)
		&"rocket_yard": return Vector2(112,656)
	return Vector2(80,640)


static func floor_y(id: StringName) -> int:
	return int(spawn(id).y)+64


static func layout(id: StringName) -> Array:
	var out: Array = []
	rect(out,0,0,1024,6,1)
	rect(out,0,0,6,768,1)
	rect(out,1018,0,6,768,1)
	rect(out,0,762,1024,6,1)
	match id:
		&"cannon_run": _cannon(out)
		&"rat_steps": _rat(out)
		&"afterimage_works": _afterimage(out)
		&"vector_port": _vector(out)
		&"dust_foundry": _dust(out)
		&"undertow_lab": _undertow(out)
		&"rocket_yard": _rocket(out)
		_: _mixed(out)
	match id:
		&"cannon_run": drain(out,450,600,640)
		&"rat_steps": drain(out,400,428,618)
		&"afterimage_works": drain(out,600,646,646)
		&"vector_port": drain(out,470,646,658)
		&"dust_foundry": _dust_drain(out)
		&"undertow_lab": drain(out,470,646,646)
		&"rocket_yard": drain(out,744,646,668)
		_: drain(out,430,652,652)
	return out


static func _mixed(out: Array) -> void:
	# FLOOD MARKET: a canal below the broad continuous road, a separate covered
	# bazaar walk and a roof-to-roof courier route with distinct stepped facades.
	rect(out,6,704,330,58,41)
	rect(out,6,704,326,3,61)
	deck(out,332,704,354,62,77)
	rect(out,686,704,332,58,43)
	rect(out,690,704,324,3,61)
	tank(out,342,526,154,126,3,38)
	tank(out,524,528,148,124,24,120)
	deck(out,322,504,386,50,79)
	rect(out,318,516,8,120,43)
	rect(out,704,516,8,120,43)
	for i: int in range(5):
		var x: int = 354+i*64
		canopy(out,x,446,46,[47,94,87,89,91][i])
		rect(out,x+7,480,31,10,[81,84,102,98,87][i])
		rect(out,x+11,474,8,6,[2,23,27,13,29][i])
		rect(out,x+26,472,6,8,35)
	rect(out,38,318,174,22,43)
	rect(out,42,340,8,136,43)
	rect(out,200,340,8,136,43)
	deck(out,36,472,182,46,79)
	windows(out,60,350,4,34,55)
	canopy(out,46,402,154,47)
	pipe(out,216,300,5,170,69)
	deck(out,258,392,106,46,78)
	rect(out,266,360,74,22,45)
	windows(out,274,360,2,34,55)
	deck(out,414,304,116,52,77)
	rect(out,432,242,82,52,43)
	windows(out,442,254,2,38,55)
	deck(out,578,350,126,81,79)
	route_frame(out,542,326,28,26,78)
	canopy(out,596,314,92,94)
	deck(out,744,266,120,54,77)
	ribs(out,768,164,80,94,54)
	windows(out,780,184,2,30,55)
	deck(out,890,394,106,46,78)
	rect(out,904,416,8,180,43)
	rect(out,982,416,8,180,43)
	canopy(out,738,580,162,47)
	for i: int in range(4): cargo(out,750+i*36,628,28,32,[81,87,102,91][i])
	pipe(out,730,616,210,4,69)
	lamps(out,[Vector2i(32,672),Vector2i(290,672),Vector2i(734,672),Vector2i(1008,616)])
	for i: int in range(4):
		rect(out,78+i*34,284,22,10,[77,78,79,80][i])
		rect(out,82+i*34,287,14,4,72)
	for i: int in range(5): rect(out,742+i*44,734,24,3,[53,52,50,56,98][i])
	# An eastern service stair connects the street, canopy and covered bazaar.
	# Its first tread is beyond the universal bypass; subsequent treads remain
	# overhead, so a missed jump always returns to the open market street.
	# The first thin shelf leaves38cells above the full street; the light loose
	# crate beside it is an optional movable step, never a static road barrier.
	rect(out,984,662,30,4,46)
	for step: Vector2i in [Vector2i(946,654),Vector2i(982,628),
		Vector2i(934,602),Vector2i(978,576),Vector2i(914,550),Vector2i(866,526)]:
		deck(out,step.x,step.y,30,46,79)
	deck(out,704,504,150,46,79)
	rect(out,982,540,8,56,0)


static func _cannon(out: Array) -> void:
	# QUARRY RALLY: broad ascent, crest and suspended landing road, flooded
	# excavation, terraced rock faces and a diagonal mineral conveyor skyline.
	rect(out,6,720,354,42,58)
	rect(out,6,720,350,3,59)
	ramp(out,330,720,208,52,40)
	deck(out,538,668,150,58,76)
	ramp(out,660,668,48,12,58)
	# A real44-cell air gap follows the lip. Missed jumps recover on the lower
	# pit road and can still reach the shared finish beyond the landing deck.
	deck(out,752,684,196,62,79)
	rect(out,360,736,658,26,40)
	route_frame(out,724,566,24,20,79)
	tank(out,374,442,170,158,3,40)
	tank(out,574,470,146,126,16,71)
	for i: int in range(6):
		var x: int = 20+i*38
		var y: int = 358+i*18
		rect(out,x,y,42,24,39 if i%2 else 40)
		rect(out,x+4,y+24,10,12,13)
		rect(out,x+7,y+5,23,3,106)
	deck(out,32,520,244,112,79)
	for i: int in range(5):
		cargo(out,42+i*42,486,32,27,[57,81,87,102,110][i])
		rect(out,47+i*42,474,18,9,[13,27,2,23,29][i])
	for i: int in range(12):
		var x: int = 292+i*30
		var y: int = 344-i*9
		rect(out,x,y,32,7,65)
		rect(out,x+7,y+7,4,14,68)
		rect(out,x+12,y-8,13,8,13)
	deck(out,678,220,206,64,79)
	ribs(out,686,152,72,62,113)
	windows(out,696,168,2,26,72)
	pipe(out,766,172,116,4)
	rect(out,870,176,5,198,68)
	deck(out,780,376,194,58,76)
	rect(out,956,384,8,184,117)
	cargo(out,802,340,42,30,62)
	cargo(out,858,344,62,26,87)
	for i: int in range(5):
		rect(out,758+i*43,594,26,16,[35,7,81,104,98][i])
		rect(out,758+i*43,610,26,5,50)
	lamps(out,[Vector2i(24,688),Vector2i(286,688),Vector2i(558,636),Vector2i(952,652)],79)
	for i: int in range(7): rect(out,36+i*39,740,24,2,77 if i%2 else 79)
	pipe(out,300,538,5,112,69)
	rect(out,280,650,46,8,76)
	# The first landing remains clear; these flush braking stripes lead into
	# the loose-load bay, with the lower pit road available after any overshoot.
	for x: int in [836,876,916]: rect(out,x,684,10,1,104)


static func _rat(out: Array) -> void:
	# TERRACED AQUEDUCT: gentle lower road, rising bike spine, open bridge
	# pillars and old stone cisterns, copper plumbing and a hanging garden.
	rect(out,6,696,1012,66,38)
	rect(out,6,696,1012,2,61)
	# A shallow graded approach is the universal road. Square first risers
	# stopped wheel rigs; the narrow upper shelves remain the bike challenge.
	ramp(out,306,696,264,66,41)
	deck(out,568,630,132,46,79)
	ramp_down(out,700,630,264,66,41)
	route_frame(out,604,588,38,22,79)
	deck(out,304,444,638,38,79)
	for x: int in [312,466,620,774,928]:
		rect(out,x,451,10,128,38)
		rect(out,x-5,451,20,8,98)
		rect(out,x-6,574,22,7,41)
	tank(out,352,286,206,142,3,38)
	tank(out,646,298,188,130,24,120)
	for i: int in range(6):
		deck(out,358+i*86,556-i*12,38,[46,49,50,81,98,52][i],79)
		if i%2==0: rect(out,365+i*86,534-i*12,7,16,83)
	deck(out,58,452,164,46,77)
	rect(out,66,336,10,108,43)
	rect(out,204,336,10,108,43)
	ramp(out,62,336,80,20,48)
	for i: int in range(4):
		windows(out,86+i*27,366,1,27,55)
		rect(out,88+i*27,418,20,6,97)
	canopy(out,64,472,148,47)
	pipe(out,232,310,6,228,54)
	deck(out,264,248,108,46,77)
	rect(out,282,212,70,30,45)
	windows(out,290,212,2,34)
	deck(out,568,218,112,52,78)
	canopy(out,578,184,92,94)
	deck(out,860,230,126,98,77)
	ribs(out,900,106,72,116,54,18)
	for i: int in range(5):
		rect(out,742+i*43,560,26,23,[81,82,88,87,91][i])
		rect(out,746+i*43,549,18,11,[2,23,13,27,29][i])
	pipe(out,284,268,630,4,69)
	lamps(out,[Vector2i(26,664),Vector2i(306,664),Vector2i(706,664),Vector2i(994,664)],79)
	for i: int in range(10): rect(out,34+i*27,724,16,2,40 if i%2 else 39)
	# Optional balance branch above the graded road: entry shelves, a broad
	# refuge, then an open descent back to the road. No ceiling is added within
	# the vehicle envelope of the proven shallow universal ascent/descent.
	deck(out,706,580,34,46,79)
	deck(out,788,548,42,46,79)
	deck(out,744,516,38,46,79)
	deck(out,842,530,100,46,77)
	deck(out,940,594,54,46,79)
	rect(out,928,500,10,80,0)


static func _afterimage(out: Array) -> void:
	# TEXTILE MILL: loading street, optional slide vent and zig-zag roof route.
	# Open-ended ducts, cloth spools and stepped roofs replace the old towers.
	rect(out,6,700,1012,62,57)
	rect(out,6,700,1012,3,59)
	deck(out,334,630,118,63,76)
	rect(out,320,630,14,7,63)
	rect(out,338,610,110,8,64)
	# Both mouths stay open; the former left cheek filled the entire gap.
	route_frame(out,346,582,94,18,78)
	tank(out,514,532,176,114,3,71)
	tank(out,756,502,160,144,24,35)
	deck(out,286,536,172,57,78)
	rect(out,286,402,8,134,57)
	rect(out,450,426,8,110,57)
	deck(out,290,392,146,64,78)
	windows(out,306,422,4,30,55)
	for i: int in range(4):
		rect(out,304+i*34,484,22,30,[81,84,87,94][i])
		rect(out,308+i*34,480,14,3,79)
	deck(out,492,450,134,66,77)
	deck(out,664,364,104,130,77)
	deck(out,808,270,160,63,78)
	rect(out,948,278,8,164,57)
	ribs(out,864,154,92,108,113)
	windows(out,878,178,2,38,72)
	deck(out,546,244,118,46,79)
	canopy(out,554,208,102,94)
	deck(out,354,186,110,62,78)
	rect(out,362,110,88,68,43)
	windows(out,374,128,2,38,55)
	deck(out,74,316,166,46,79)
	canopy(out,82,270,150,47)
	for i: int in range(6):
		var x: int = 64+i*27
		rect(out,x,362,18,20,[84,81,87,94,89,91][i])
		rect(out,x+3,358,12,4,53)
		rect(out,x+3,382,12,4,53)
	pipe(out,252,180,5,300,68)
	pipe(out,252,180,86,5,68)
	pipe(out,478,292,142,5,69)
	for i: int in range(6):
		rect(out,700+i*42,450,24,4,50)
		rect(out,710+i*42,424,3,26,74)
		rect(out,704+i*42,414,16,9,[77,78,80,79,77,78][i])
	for i: int in range(4): cargo(out,34+i*56,510,44,36,[81,87,102,91][i])
	lamps(out,[Vector2i(24,668),Vector2i(340,668),Vector2i(472,668),Vector2i(978,668)],78)
	for i: int in range(6): rect(out,726+i*43,730,26,3,[53,52,98,38,81,50][i])
	# A light loose crate beside the thin entry shelf supplies the optional
	# twenty-cell first step. Every static shelf leaves the full street clear;
	# a wheeled player can push the crate aside instead of entering the course.
	rect(out,304,656,30,7,63)
	rect(out,282,640,18,5,63)
	deck(out,458,598,38,63,78)
	deck(out,476,566,40,63,78)


static func _vector(out: Array) -> void:
	# CRATER PORT: broad low taxiway, a large open launch void and asymmetric
	# cantilever arms. Flight apertures are between structures, not wall stamps.
	rect(out,6,710,1012,52,100)
	rect(out,6,710,1012,3,59)
	deck(out,40,528,186,114,77)
	for i: int in range(6): rect(out,52+i*28,516,18,6,80 if i%2 else 77)
	ribs(out,30,270,52,250,113)
	deck(out,54,258,204,130,77)
	rect(out,222,160,8,98,117)
	deck(out,222,154,222,62,79)
	for i: int in range(6):
		rect(out,248+i*28,162,8,24+i%2*10,68)
		rect(out,247+i*28,192+i%2*10,10,3,79)
	deck(out,404,366,142,130,77)
	rect(out,530,218,8,148,117)
	deck(out,638,238,318,114,78)
	route_frame(out,560,270,64,80,77)
	ribs(out,900,246,46,190,113)
	deck(out,710,438,246,130,79)
	tank(out,384,518,194,128,3,71)
	tank(out,622,512,182,134,24,120)
	deck(out,838,630,144,114,77)
	# Edge cargo frames a broad, genuinely empty touchdown area instead of
	# filling the entire landing deck with static boxes.
	cargo(out,842,592,24,30,62)
	cargo(out,956,592,20,30,131)
	route_frame(out,868,552,84,68,77)
	for i: int in range(4): windows(out,702+i*46,286,1,46,72)
	for i: int in range(8):
		rect(out,626+i*12,134+i*6,12,4,129)
		rect(out,626+i*12,138+i*6,3,12,50)
	rect(out,652,184,8,46,117)
	pipe(out,846,458,5,102,69)
	pipe(out,812,558,80,5,69)
	deck(out,274,454,66,104,79)
	for i: int in range(5):
		rect(out,284+i*6,422-i*5,5,30+i*5,131)
		rect(out,54+i*33,576,22,17,[81,102,35,98,87][i])
	lamps(out,[Vector2i(26,678),Vector2i(328,678),Vector2i(854,678),Vector2i(994,678)],77)
	for i: int in range(8): rect(out,34+i*38,738,22,2,79 if i%2 else 77)
	for i: int in range(4): rect(out,444+i*34,394,18,14,[53,52,50,28][i])


static func _dust(out: Array) -> void:
	# INVERTED FOUNDRY: mineral feed hoppers, hanging combs and discharge
	# terraces over a clear floor. Sand can cross sieves or take broad bypasses.
	rect(out,6,704,1012,58,104)
	rect(out,6,704,1012,3,59)
	tank(out,64,166,180,140,3,71)
	tank(out,738,120,208,166,16,104)
	for i: int in range(8):
		rect(out,310+i*8,196+i*12,8,20,62)
		rect(out,538-i*8,196+i*12,8,20,62)
		rect(out,334+i*8,210+i*10,188-i*16,10,[2,14,23,13][i%4])
	rect(out,376,302,96,5,87)
	rect(out,404,308,4,70,68)
	rect(out,436,308,4,70,68)
	# Open grates let the broken hopper actually feed the combs below.
	for x: int in range(280,610,22):
		rect(out,x,394,14,7,66)
		rect(out,x,394,14,1,79)
	for i: int in range(14): rect(out,286+i*22,402,5,30+(i%3)*12,62)
	for x: int in range(322,534,26): rect(out,x,502,16,7,117)
	for i: int in range(8): rect(out,328+i*26,510,4,42-(i%3)*8,50)
	for x: int in range(666,974,26): rect(out,x,354,14,7,117)
	for i: int in range(11): rect(out,672+i*26,362,6,32+(i%2)*28,62)
	route_frame(out,450,316,42,44,79)
	for i: int in range(5):
		deck(out,604+i*72,486+(i%3)*42,54,[100,104,117,65,98][i],79)
		rect(out,610+i*72,462+(i%3)*42,36,24,[2,23,27,14,29][i])
	deck(out,38,474,194,102,77)
	canopy(out,48,428,174,64)
	for i: int in range(5):
		cargo(out,48+i*34,516,26,30,[81,87,91,102,110][i])
		windows(out,52+i*32,382,1,32,72)
	pipe(out,258,184,5,394,69)
	pipe(out,36,340,204,5,68)
	pipe(out,590,166,5,170,68)
	deck(out,566,152,116,64,79)
	ribs(out,602,76,72,68,113)
	for i: int in range(4):
		rect(out,340+i*44,640,30,24,[7,35,81,98][i])
		rect(out,342+i*44,632,26,8,76)
	lamps(out,[Vector2i(26,672),Vector2i(310,672),Vector2i(576,672),Vector2i(992,672)],79)
	for i: int in range(6): rect(out,760+i*35,730,20,3,[53,52,28,50,100,131][i])
	# Separate open receiving trays make the two comb stages visibly useful.
	# The first tray stays below the existing y452 powder-flow observation.
	deck(out,368,468,114,104,79)
	rect(out,364,450,4,25,104)
	rect(out,482,450,4,25,104)
	deck(out,638,612,110,104,77)
	rect(out,634,594,4,25,104)
	rect(out,748,594,4,25,104)


static func _undertow(out: Array) -> void:
	# FILTRATION CATHEDRAL: dry nave beside deep cisterns, high water organ,
	# layered material experiments, grand asymmetric stone/glass arch.
	rect(out,6,700,1012,62,111)
	rect(out,6,700,1012,3,70)
	tank(out,348,462,236,184,3,120)
	tank(out,666,438,242,208,24,71)
	tank(out,418,184,192,154,3,35)
	deck(out,320,436,292,52,77)
	deck(out,644,412,292,52,77)
	deck(out,376,358,278,120,78)
	rect(out,366,364,8,184,38)
	rect(out,644,364,8,70,38)
	for i: int in range(6):
		rect(out,50+i*14,164-i*12,14,28,98)
		rect(out,300-i*14,164-i*12,14,28,98)
	rect(out,134,92,96,14,55)
	deck(out,34,340,260,98,79)
	for i: int in range(5):
		pipe(out,52+i*42,192+(i%2)*22,7,130-(i%2)*22,69)
		rect(out,50+i*42,190+(i%2)*22,11,5,52)
	# (212,250) stays empty for the native authoring contract fixture.
	for i: int in range(8):
		rect(out,336+i*32,394,18,10,[66,67,35,87,9,13,23,106][i])
		rect(out,342+i*32,404,6,20,50)
	deck(out,700,246,266,54,78)
	route_frame(out,596,478,34,80,77)
	windows(out,720,188,6,38,55)
	for i: int in range(7):
		rect(out,710+i*34,278,26,4,70)
		rect(out,719+i*34,282,7,56+(i%3)*24,69)
	pipe(out,616,128,5,196,68)
	pipe(out,620,126,288,5,68)
	deck(out,46,500,236,81,79)
	for i: int in range(5):
		cargo(out,56+i*42,458,32,34,[81,87,102,91,110][i])
		rect(out,62+i*42,450,20,8,[2,23,27,13,29][i])
	lamps(out,[Vector2i(26,668),Vector2i(286,668),Vector2i(616,668),Vector2i(982,668)],77)
	for i: int in range(8): rect(out,46+i*30,730,18,3,[98,55,54,52,53,50,70,111][i])
	# The upper water organ has a visible glass outlet into a real filter comb
	# and catch terrace. A dry western lip lets any visitor retreat to the nave.
	rect(out,500,338,16,7,35)
	for x: int in [476,492,524,540]: rect(out,x,358,8,7,66)
	rect(out,508,358,8,7,0)
	deck(out,468,382,84,120,78)
	deck(out,302,570,38,38,77)
	deck(out,288,622,40,38,77)


static func _rocket(out: Array) -> void:
	# SILO LAUNCH FACILITY: nested launch wells, cantilever precision pads and
	# an exposed coolant farm. The low western transit road stays open.
	rect(out,6,720,1012,42,58)
	rect(out,6,720,1012,3,59)
	tank(out,664,474,154,172,3,131)
	tank(out,846,456,146,190,16,71)
	ribs(out,346,292,18,370,131,20)
	# A full-height right wall trapped the inner slalom. The mid-height opening
	# now connects its378 pad and permits a controlled retreat into the well.
	ribs(out,526,220,18,94,131,20)
	ribs(out,526,410,18,180,131,20)
	deck(out,348,664,138,131,79)
	deck(out,424,542,118,131,77)
	deck(out,348,418,110,131,78)
	deck(out,424,292,120,131,79)
	deck(out,568,378,116,130,77)
	route_frame(out,466,580,44,46,79)
	deck(out,708,290,112,130,78)
	deck(out,852,206,130,130,77)
	rect(out,966,212,8,176,117)
	deck(out,702,398,280,62,79)
	for i: int in range(6):
		rect(out,714+i*42,366,30,26,[81,87,62,128,104,131][i])
		rect(out,718+i*42,358,22,4,76)
	deck(out,36,444,250,58,77)
	rect(out,42,304,8,132,58)
	rect(out,268,304,8,132,58)
	deck(out,42,294,234,113,79)
	windows(out,66,332,6,32,72)
	for i: int in range(5):
		rect(out,64+i*42,396,30,16,[128,53,98,87,102][i])
		rect(out,70+i*42,388,18,5,[77,78,80,79,77][i])
	pipe(out,296,190,5,358,69)
	pipe(out,304,192,276,5,68)
	ribs(out,598,86,68,126,113,18)
	for i: int in range(5):
		rect(out,614+i*8,72-i*6,8,14,129)
		rect(out,612+i*8,84-i*6,12,2,50)
	deck(out,740,134,112,114,77)
	for i: int in range(5): cargo(out,38+i*49,528,36,38,[81,87,110,102,91][i])
	lamps(out,[Vector2i(28,688),Vector2i(332,688),Vector2i(578,688),Vector2i(994,688)],79)
	for i: int in range(8): rect(out,42+i*31,742,18,2,78 if i%2 else 77)


static func checkpoints(id: StringName) -> PackedVector2Array:
	var first := Vector2(spawn(id).x+174, floor_y(id)-12)
	match id:
		&"cannon_run": return PackedVector2Array([first,Vector2(570,656),Vector2(650,656),Vector2(986,724)])
		&"rat_steps": return PackedVector2Array([first,Vector2(590,618),Vector2(780,638),Vector2(978,684)])
		&"afterimage_works": return PackedVector2Array([first,Vector2(350,688),Vector2(650,688),Vector2(992,688)])
		&"vector_port": return PackedVector2Array([first,Vector2(450,698),Vector2(704,698),Vector2(992,698)])
		&"dust_foundry": return PackedVector2Array([first,Vector2(360,692),Vector2(650,692),Vector2(992,692)])
		&"undertow_lab": return PackedVector2Array([first,Vector2(360,688),Vector2(704,688),Vector2(992,688)])
		&"rocket_yard": return PackedVector2Array([first,Vector2(392,708),Vector2(716,708),Vector2(992,708)])
	# Keep the final marker reachable by the complete wide buggy before its
	# front assembly contacts the boundary; the checkpoint radius stays15.
	return PackedVector2Array([first,Vector2(360,692),Vector2(666,692),Vector2(992,692)])


static func reservoir_outlet(id: StringName) -> Vector2i:
	match id:
		&"cannon_run": return Vector2i(450,640)
		&"rat_steps": return Vector2i(400,618)
		&"afterimage_works": return Vector2i(600,646)
		&"vector_port": return Vector2i(470,658)
		&"dust_foundry": return Vector2i(320,652)
		&"undertow_lab": return Vector2i(470,646)
		&"rocket_yard": return Vector2i(744,668)
	return Vector2i(430,652)


static func _dust_drain(out: Array) -> void:
	# The west store routes overhead before turning down beyond the clear start.
	rect(out,214,306,12,256,3)
	rect(out,210,313,4,233,69)
	rect(out,226,313,4,233,69)
	rect(out,214,550,112,12,3)
	rect(out,234,546,96,4,69)
	rect(out,210,562,104,4,69)
	rect(out,310,566,4,86,69)
	rect(out,326,550,4,102,69)
	rect(out,314,562,12,90,3)
	drain(out,320,652,652)


static func props(id: StringName) -> Array[Dictionary]:
	# These stages avoid the first 200 route cells, liquids and checkpoints.
	match id:
		&"cannon_run": return [_prop(846,668,20,16,5.0,"d7a65f"),_prop(888,668,16,16,3.0,"b7c9d3"),_prop(932,662,24,28,7.0,"a56e4d")]
		&"rat_steps": return [_prop(376,522,18,18,3.0,"a47b51"),_prop(806,470,20,18,4.0,"8d8f92"),_prop(888,518,16,18,2.5,"b79d65")]
		&"afterimage_works": return [_prop(290,690,16,20,0.25,"d0a16a"),_prop(496,554,20,22,4.5,"939cb1"),_prop(836,252,24,30,6.0,"af7751")]
		&"vector_port": return [_prop(430,355,18,20,5.0,"9baebb"),_prop(748,426,22,20,6.0,"cdaf6c"),_prop(854,580,24,24,7.0,"7e9da5")]
		&"dust_foundry": return [_prop(420,456,22,22,5.0,"a87443"),_prop(700,598,20,26,4.5,"8f98a0"),_prop(584,140,22,22,5.0,"af8b55")]
		&"undertow_lab": return [_prop(270,488,18,22,4.0,"a6cbd4"),_prop(750,234,22,22,5.0,"bc9f67"),_prop(924,398,24,26,7.0,"84b6aa")]
		&"rocket_yard": return [_prop(598,366,20,20,5.0,"9cacb4"),_prop(238,430,18,28,5.5,"c89860"),_prop(930,340,20,22,4.0,"91aeb8")]
	return [_prop(954,695,20,18,0.25,"a8885d"),_prop(929,534,24,30,6.0,"a6bcc3"),_prop(996,653,18,18,3.0,"c6a264")]


static func _prop(x: float, y: float, w: float, h: float, mass: float, color: String) -> Dictionary:
	return {"position":Vector2(x,y),"size":Vector2(w,h),"mass":mass,"color":Color(color)}


static func npc_spawns(id: StringName) -> PackedVector2Array:
	# Empty ground-side stage points; the host supplies rig-specific clearance.
	var x: float = spawn(id).x
	return PackedVector2Array([Vector2(x+102,floor_y(id)-30),Vector2(x+178,floor_y(id)-30)])
