class_name CyberPlayerPlaygroundExpeditions
extends RefCounted

const D = preload("res://scripts/player_playground_districts.gd")
const VIEW := Rect2i(0,0,1024,768)
const IDS: Array[StringName] = [&"stormbreak_viaduct",&"rootbound_conservatory",&"prism_archive",
	&"eventide_station",&"buried_baths",&"saltglass_sinkhole",&"starfall_amphitheatre"]
const NAMES: Array[String] = ["Stormbreak Viaduct · buggy","Rootbound Conservatory · trials bike",
	"Prism Archive · acrobat","Eventide Station · lander","Buried Baths · Sand cloud",
	"Saltglass Sinkhole · Water blob","Starfall Amphitheatre · jet barrel"]
const HINTS: Array[String] = [
	"Follow the coastal overpass into the service yard and lighthouse road. Test the low launch crest, push salvage into the catch court, or score the marked Water valve.",
	"Climb the outer root bridge, cross the greenhouse court and descend the irrigation return. The narrow timber garden and real loose cargo reward controlled hops and lean.",
	"Descend the gallery beside the open atrium. Connected double-jump shelves lead to a compact slide passage; the preservation vault below the road is an optional excavation challenge.",
	"Drive over the mountain saddle or fly through the calibration court and asymmetric weather mast. Brake above the lower reservoir court; cyan glass marks the drain valve.",
	"Enter the buried bathhouse, cross the collapsed hall and descend to the lake court. Cut the visible sand stopper and guide grains through the real grille into its catch trough.",
	"Descend the karst road into the sinkhole and climb the far rim. Open the high Water store, follow its visible channel, and gather through the side-cavern apertures.",
	"Cross the backstage terrace, open auditorium and reservoir stage. Fly the offset scenery apertures and return onto the broad stage apron; ground players have a continuous route."]
const SUGGESTED: Array[StringName] = [&"stuntbuggy",&"trialsbike",&"acrobat",&"arcadelander",
	&"dryswarm",&"liquidswarm",&"jetbarrel"]

# Every map owns its road silhouette and start elevation. The profiles describe
# the actual native surface, not a rendered line or a hidden navigation floor.
const PROFILES: Dictionary = {
	&"stormbreak_viaduct":[Vector2i(6,608),Vector2i(320,608),Vector2i(576,672),Vector2i(604,672),Vector2i(660,660),Vector2i(704,660),Vector2i(752,672),Vector2i(984,720),Vector2i(1018,720)],
	&"rootbound_conservatory":[Vector2i(6,704),Vector2i(320,704),Vector2i(592,636),Vector2i(672,636),Vector2i(944,704),Vector2i(1018,704)],
	&"prism_archive":[Vector2i(6,432),Vector2i(320,432),Vector2i(640,512),Vector2i(704,512),Vector2i(1016,590),Vector2i(1018,590)],
	&"eventide_station":[Vector2i(6,672),Vector2i(320,672),Vector2i(608,600),Vector2i(896,672),Vector2i(1018,672)],
	&"buried_baths":[Vector2i(6,528),Vector2i(320,528),Vector2i(592,596),Vector2i(752,596),Vector2i(1008,660),Vector2i(1018,660)],
	&"saltglass_sinkhole":[Vector2i(6,656),Vector2i(320,656),Vector2i(576,720),Vector2i(752,720),Vector2i(1008,656),Vector2i(1018,656)],
	&"starfall_amphitheatre":[Vector2i(6,592),Vector2i(320,592),Vector2i(608,664),Vector2i(736,664),Vector2i(1016,594),Vector2i(1018,594)]}


static func floor_y(id: StringName) -> int:
	return int(PROFILES.get(id,PROFILES[IDS[0]])[0].y)


static func spawn(id: StringName) -> Vector2:
	return Vector2(88,floor_y(id)-64)


static func road_y(id: StringName, x: int) -> int:
	var profile: Array = PROFILES.get(id,PROFILES[IDS[0]])
	for i: int in range(1,profile.size()):
		var a: Vector2i = profile[i-1]
		var b: Vector2i = profile[i]
		if x < b.x:
			var step: int = maxi(0,(x-a.x)/4)*4
			if b.y < a.y: return a.y-maxi(1,roundi(float(step+4)*(a.y-b.y)/(b.x-a.x)))
			return a.y+roundi(float(step)*(b.y-a.y)/(b.x-a.x))
	return profile[-1].y


static func _road(out: Array, id: StringName, material: int) -> void:
	var profile: Array = PROFILES[id]
	for i: int in range(1,profile.size()):
		var a: Vector2i = profile[i-1]
		var b: Vector2i = profile[i]
		if a.y == b.y:
			D.rect(out,a.x,a.y,b.x-a.x,12,material)
			D.rect(out,a.x,a.y,b.x-a.x,1,61 if material in [38,41] else 59)
		elif b.y < a.y: D.ramp(out,a.x,a.y,b.x-a.x,a.y-b.y,material)
		else: D.ramp_down(out,a.x,a.y,b.x-a.x,b.y-a.y,material)


static func _edge(out: Array) -> void:
	D.rect(out,0,0,1024,6,1)
	D.rect(out,0,0,6,768,1)
	D.rect(out,1018,0,6,768,1)
	D.rect(out,0,762,1024,6,1)


static func _sill(out: Array, x: int, y: int, w: int, m: int = 46) -> void:
	D.rect(out,x,y,w,6,m)
	D.rect(out,x+2,y,w-4,1,79)


static func _tiles(out: Array, x: int, y: int, cols: int, rows: int, m: int) -> void:
	# Inset masonry/material bands give architecture readable scale; gaps are
	# intentional grout, not a substitute for the structural backing wall.
	for row: int in range(rows):
		for col: int in range(cols):
			D.rect(out,x+col*18+(4 if row%2 else 0),y+row*12,13,7,m)


static func _arch(out: Array, x: int, y: int, w: int, h: int, m: int) -> void:
	D.rect(out,x,y+28,10,h-28,m)
	D.rect(out,x+w-10,y+28,10,h-28,m)
	for i: int in range(6):
		D.rect(out,x+i*10,y+28-i*5,10,10,m)
		D.rect(out,x+w-10-i*10,y+28-i*5,10,10,m)
	D.rect(out,x+60,y-2,w-120,10,m)


static func _light(out: Array, x: int, y: int, color: int = 77) -> void:
	D.rect(out,x,y,14,3,color)
	D.rect(out,x+4,y-8,6,8,50)


static func _branch(out: Array, x: int, y: int, w: int, rise: int, descending: bool) -> void:
	# Broad timber limbs need fewer edges than the four-cell wheel road. These
	# remain solid native wedges, with eight-cell bark steps and visible ribs.
	for step: int in range(0,w,8):
		var offset: int = roundi(float(step)*rise/w)
		D.rect(out,x+step,y+offset if descending else y-offset,mini(8,w-step),rise+12-offset if descending else offset+12,83)


static func layout(id: StringName) -> Array:
	var out: Array = []
	_edge(out)
	match id:
		&"rootbound_conservatory": _rootbound(out)
		&"prism_archive": _prism(out)
		&"eventide_station": _eventide(out)
		&"buried_baths": _baths(out)
		&"saltglass_sinkhole": _saltglass(out)
		&"starfall_amphitheatre": _starfall(out)
		_: _stormbreak(out)
	return out


static func _stormbreak(out: Array) -> void:
	var id: StringName = &"stormbreak_viaduct"
	# Three different spatial beats: exposed overpass, open service court and
	# lighthouse descent. Pillars continue below the road into a tidal undercroft.
	_road(out,id,58)
	for x: int in [34,178,574,744,982]:
		var y: int = road_y(id,x)+14
		D.rect(out,x,y,12,752-y,58)
		D.rect(out,x-6,744,24,8,40)
	D.rect(out,6,750,1012,12,100)
	D.tank(out,382,282,190,156,3,71)
	D.tank(out,654,318,168,136,24,120)
	D.drain(out,482,438,road_y(id,482)-52)
	# An elevated maintenance promenade frames the open road; fixtures are
	# attached to walls/decks and leave the entire vehicle clearance envelope.
	_sill(out,338,246,256,62)
	for i: int in range(8):
		D.rect(out,350+i*30,202,16,36,[64,113,65,62][i%4])
		_light(out,350+i*30,190,79)
	D.pipe(out,350,470,218,5,69)
	D.pipe(out,606,242,6,250,68)
	D.canopy(out,42,318,212,64)
	_sill(out,36,418,232,57)
	D.windows(out,52,350,6,32,72)
	for i: int in range(5):
		D.cargo(out,48+i*42,448,32,32,[81,87,102,110,91][i])
		D.rect(out,54+i*42,438,20,8,[13,2,23,27,29][i])
	# Lighthouse is a stepped solid spine with an accessible exterior ledge
	# sequence, not a full-height rectangular tower copy.
	D.rect(out,890,138,14,332,98)
	for i: int in range(9):
		D.rect(out,872-i*2,150+i*34,48+i*4,28,98)
		D.rect(out,878-i*2,158+i*34,36+i*4,3,54)
		if i%2 == 0: _sill(out,836,176+i*34,34,50)
	D.rect(out,852,124,90,15,50)
	D.rect(out,862,100,70,24,55)
	D.rect(out,876,88,42,12,80)
	_sill(out,828,470,136,38)
	D.windows(out,836,494,4,30,55)
	D.route_frame(out,618,480,42,42,79)
	# The low crest is part of the supported road: drive its gentle approach
	# and return, or hop from the top into the marked braking zone. The former
	# workshop island stood116cells above the road and had no wheel approach.
	D.rect(out,668,660,28,1,76)
	for x: int in range(770,814,4): D.rect(out,x,road_y(id,x)+2,4,2,76)
	# Suspended inspection baskets keep heavy salvage clear of the shared road
	# and place it within usable range rather than making it a compulsory wall.
	_sill(out,668,624,28,62)
	_sill(out,788,642,32,62)
	for x: int in [670,692]: D.rect(out,x,461,2,163,50)
	for x: int in [788,818]: D.rect(out,x,461,2,181,50)
	_tiles(out,34,656,13,3,39)
	_tiles(out,802,718,10,3,40)
	for i: int in range(7): _light(out,316+i*76,82+(i%3)*18,77)


static func _rootbound(out: Array) -> void:
	var id: StringName = &"rootbound_conservatory"
	_road(out,id,41)
	D.rect(out,6,746,1012,16,109)
	D.tank(out,366,256,194,150,3,35)
	D.tank(out,728,218,178,156,24,71)
	D.drain(out,470,406,road_y(id,470)-52)
	# Giant bifurcated trunk leaves a broad negative-volume greenhouse nave.
	for i: int in range(11):
		D.rect(out,606-i*3,102+i*36,26+i*2,28,83)
		D.rect(out,644+i*3,126+i*34,20+i,25,82)
		D.rect(out,612-i*3,109+i*36,4,14,97)
	D.rect(out,610,110,10,380,83)
	D.rect(out,588,210,22,16,83)
	D.rect(out,664,202,14,12,83)
	_branch(out,388,246,204,44,false)
	_branch(out,674,202,54,42,true)
	_sill(out,320,456,242,46)
	_sill(out,674,430,260,46)
	for i: int in range(8):
		var x: int = 52+i*28
		D.rect(out,x,214+(i%3)*8,24,18,97)
		D.rect(out,x+4,232+(i%3)*8,16,10,86)
		D.rect(out,x+9,242+(i%3)*8,4,42,86)
	D.canopy(out,30,302,260,55)
	D.rect(out,36,306,6,148,50)
	D.rect(out,278,306,6,148,50)
	_sill(out,30,454,260,46)
	D.windows(out,48,338,7,32,55)
	for i: int in range(6):
		D.rect(out,46+i*40,398,30,18,102)
		D.rect(out,50+i*40,388,22,10,[2,56,23,13,27,29][i])
		D.rect(out,58+i*40,378,6,10,86)
	# A connected upper balancing garden is close to the road saddle, with a
	# broad catch shelf below it and low timber approaches at either end.
	_sill(out,570,578,128,46)
	for i: int in range(4):
		D.rect(out,580+i*30,554-(i%2)*8,18,6,83)
		D.rect(out,584+i*30,560-(i%2)*8,10,18,86)
	D.route_frame(out,596,518,60,22,79)
	D.pipe(out,294,286,6,250,54)
	D.pipe(out,712,398,5,128,69)
	_tiles(out,26,718,10,2,56)
	_tiles(out,752,728,9,2,102)
	for i: int in range(6): _light(out,322+i*96,140+(i%2)*20,79)


static func _prism(out: Array) -> void:
	var id: StringName = &"prism_archive"
	_road(out,id,111)
	D.rect(out,6,724,1012,38,100)
	# The descending gallery borders a genuinely open atrium. A second archive
	# lies below the road, with its own broad vault and preservation apparatus.
	D.tank(out,406,160,188,142,16,71)
	D.tank(out,746,176,180,144,3,35)
	D.drain(out,840,320,road_y(id,840)-52)
	_sill(out,28,252,242,98)
	D.canopy(out,36,108,224,55)
	D.rect(out,30,112,6,130,98)
	D.rect(out,258,112,6,130,98)
	for shelf: int in range(4):
		_sill(out,46,142+shelf*26,192,84)
		for book: int in range(7):
			D.rect(out,52+book*20,126+shelf*26,11,15,[84,85,94,87,55,52][(book+shelf)%6])
	_arch(out,660,82,320,238,98)
	D.windows(out,694,110,7,34,55)
	D.pipe(out,354,86,5,232,69)
	D.pipe(out,606,102,5,282,68)
	# The optional compact passage is connected through double-jump shelves.
	# Every shelf underside clears the independent lower gallery.
	_sill(out,316,388,54,63)
	_sill(out,372,364,64,63)
	_sill(out,420,340,142,63)
	D.rect(out,440,320,116,8,64) #12-cell passage, both mouths open.
	D.route_frame(out,448,354,98,20,78)
	_sill(out,578,340,54,63)
	_sill(out,632,364,58,63)
	_sill(out,694,388,58,63)
	_sill(out,854,448,118,63)
	# Below the road, isolated framed vault bays have open transverse passages.
	# They are excavation scenery; active cargo stays on the accessible gallery.
	_arch(out,58,520,240,182,38)
	_arch(out,366,576,250,126,98)
	_sill(out,700,680,278,98)
	for i: int in range(7):
		D.cargo(out,714+i*36,640,26,32,[35,120,87,102,98,91,84][i])
		D.rect(out,718+i*36,630,18,10,[9,13,23,27,2,29,28][i])
	_tiles(out,44,704,12,1,98)
	_tiles(out,700,708,12,1,55)
	for i: int in range(8): _light(out,310+i*82,78+(i%3)*16,78)


static func _eventide(out: Array) -> void:
	var id: StringName = &"eventide_station"
	_road(out,id,58)
	D.rect(out,6,744,1012,18,100)
	D.tank(out,366,300,190,150,3,71)
	D.tank(out,740,348,190,150,24,120)
	D.drain(out,480,450,road_y(id,480)-52)
	# A mountain saddle opens into a broad calibration court; asymmetry and
	# protruding weather vanes give flight an actual sequence of spatial beats.
	for i: int in range(10):
		D.rect(out,6,330-i*16,40+i*14,24,100)
		D.rect(out,896+i*10,174+i*16,122-i*10,26,40)
		D.rect(out,32+i*14,338-i*16,12,3,105)
	_sill(out,42,418,234,114)
	D.canopy(out,48,280,220,113)
	D.rect(out,48,288,6,122,117)
	D.rect(out,262,288,6,122,117)
	D.windows(out,68,318,5,36,72)
	for i: int in range(5):
		D.cargo(out,56+i*42,450,32,34,[62,87,128,131,102][i])
		_light(out,62+i*42,438,77)
	_sill(out,332,246,270,130)
	_sill(out,624,430,116,114)
	_sill(out,786,258,190,130)
	D.ribs(out,652,116,16,196,117,18)
	D.rect(out,574,174,86,8,114)
	D.rect(out,660,244,92,8,114)
	D.rect(out,640,104,42,8,79)
	D.route_frame(out,690,168,62,62,77)
	D.route_frame(out,566,332,52,66,79)
	D.pipe(out,292,308,5,212,69)
	D.pipe(out,730,280,5,230,68)
	for i: int in range(8):
		D.rect(out,338+i*30,208,16,24,[104,131,113,130][i%4])
		D.rect(out,342+i*30,198,8,10,[77,78,79,80][i%4])
	_tiles(out,34,714,14,2,40)
	_tiles(out,730,708,14,3,105)
	for i: int in range(7): _light(out,310+i*98,78+(i%2)*18,77)


static func _baths(out: Array) -> void:
	var id: StringName = &"buried_baths"
	_road(out,id,38)
	D.rect(out,6,744,1012,18,39)
	D.tank(out,366,182,196,154,3,35)
	D.tank(out,758,318,190,158,24,71)
	D.drain(out,476,336,road_y(id,476)-52)
	_arch(out,34,100,250,246,38)
	D.windows(out,58,148,6,34,55)
	_sill(out,34,350,250,98)
	_tiles(out,50,292,12,4,70)
	# Broken domes alternate with collapsed slabs, leaving a large unroofed hall.
	for i: int in range(7):
		D.rect(out,316+i*12,110-i*8,12,12,38)
		D.rect(out,554-i*12,110-i*8,12,12,38)
		D.rect(out,672+i*20,196+i*5,14,8,98)
	_sill(out,598,280,132,38)
	D.ribs(out,648,112,18,162,40,18)
	# Sand sits in a real overhead bath with a narrow editable bottom. It can
	# fall through the downstream grille and collect in a broad catch trough.
	D.rect(out,582,312,5,110,38)
	D.rect(out,712,312,5,110,38)
	D.rect(out,582,418,135,5,87)
	D.rect(out,588,330,123,88,2)
	for x: int in range(580,720,20):
		D.rect(out,x,446,12,7,66)
		D.rect(out,x+3,453,4,24,50)
	D.rect(out,576,494,6,34,38)
	D.rect(out,718,494,6,34,38)
	D.rect(out,576,528,148,6,38)
	D.route_frame(out,610,258,66,32,79)
	D.pipe(out,294,146,5,240,54)
	for i: int in range(7):
		D.cargo(out,38+i*34,380,26,30,[81,87,102,91,98,120,110][i])
		D.rect(out,43+i*34,372,16,8,[13,23,27,29,2,9,28][i])
	D.windows(out,780,212,5,32,55)
	_sill(out,748,248,220,98)
	_tiles(out,38,684,14,2,38)
	_tiles(out,752,702,14,1,70)
	for i: int in range(7): _light(out,316+i*94,66+(i%3)*18,79)


static func _saltglass(out: Array) -> void:
	var id: StringName = &"saltglass_sinkhole"
	_road(out,id,40)
	D.rect(out,6,750,1012,12,100)
	D.tank(out,368,286,210,176,3,35)
	D.tank(out,752,196,192,182,24,71)
	D.drain(out,490,462,road_y(id,490)-52)
	# Strong terraced concavity and open side caverns rather than an industrial
	# room with another set of towers. Salt/glass seams expose native materials.
	for i: int in range(11):
		D.rect(out,24+i*10,180+i*24,14,18,40)
		D.rect(out,950+i*5,160+i*25,68-i*5,18,100)
		D.rect(out,28+i*10,186+i*24,8,3,106)
		D.rect(out,954+i*5,166+i*25,8,3,122)
	_arch(out,38,300,250,180,40)
	_sill(out,36,482,254,38)
	D.windows(out,60,344,6,34,55)
	for i: int in range(7):
		D.rect(out,50+i*32,420,20,28,[106,35,38,98,101,122,120][i])
		D.rect(out,56+i*32,410,8,10,79)
	# The higher side passage leads through wide broken ribs to a lower catch
	# chamber. Both ends open onto broad shelves for ordinary field steering.
	_sill(out,600,518,120,38)
	for i: int in range(6): D.rect(out,612+i*17,474,5,30,35)
	_sill(out,626,588,104,98)
	D.rect(out,622,560,4,34,120)
	D.rect(out,730,560,4,34,120)
	D.route_frame(out,648,538,54,28,77)
	D.pipe(out,606,272,5,152,54)
	D.pipe(out,690,190,5,210,69)
	_sill(out,636,158,122,54)
	D.canopy(out,644,110,106,55)
	_tiles(out,36,690,14,4,39)
	_tiles(out,754,736,14,2,106)
	for i: int in range(8): _light(out,312+i*84,78+(i%3)*22,77)


static func _starfall(out: Array) -> void:
	var id: StringName = &"starfall_amphitheatre"
	_road(out,id,111)
	D.rect(out,6,744,1012,18,100)
	D.tank(out,362,220,196,154,3,71)
	D.tank(out,764,412,190,142,16,35)
	D.drain(out,470,374,road_y(id,470)-52)
	# Curved seating is offset on both sides of an immense central auditorium.
	# The stage has its own playable road; scenery can be approached and passed.
	D.rect(out,220,144,8,248,98)
	D.rect(out,978,126,8,262,98)
	for i: int in range(9):
		_sill(out,36+i*12,144+i*30,192-i*12,98)
		D.rect(out,42+i*12,132+i*30,20,10,84)
		_sill(out,818-i*8,126+i*32,168+i*8,98)
		D.rect(out,948,114+i*32,28,10,85)
	_sill(out,30,452,250,46)
	D.canopy(out,36,330,238,94)
	D.rect(out,42,338,6,106,50)
	D.rect(out,260,338,6,106,50)
	D.windows(out,62,368,6,32,55)
	for i: int in range(5):
		D.cargo(out,44+i*44,410,34,32,[81,87,84,91,102][i])
		_light(out,52+i*44,398,78)
	# Three flight beats have broad approach/recovery pads and asymmetric
	# apertures. There is no full-height cage around the shared road spawn.
	_sill(out,328,486,132,130)
	_sill(out,530,420,126,130)
	_sill(out,642,496,118,130)
	D.rect(out,608,276,7,112,117)
	D.rect(out,660,174,7,170,117)
	D.route_frame(out,484,406,42,50,79)
	D.route_frame(out,664,354,48,46,78)
	D.pipe(out,288,202,5,284,69)
	D.pipe(out,710,116,5,230,68)
	_tiles(out,34,690,14,2,98)
	_tiles(out,752,698,14,2,55)
	for i: int in range(9):
		_light(out,306+i*76,88+(i%3)*18,[77,78,79][i%3])
		D.rect(out,310+i*76,72+(i%3)*18,6,7,74)


static func checkpoints(id: StringName) -> PackedVector2Array:
	var result := PackedVector2Array()
	for x: int in [262,450,720,990]: result.append(Vector2(x,road_y(id,x)-12))
	return result


static func reservoir_outlet(id: StringName) -> Vector2i:
	var x: int = {&"stormbreak_viaduct":482,&"rootbound_conservatory":470,&"prism_archive":840,
		&"eventide_station":480,&"buried_baths":476,&"saltglass_sinkhole":490,&"starfall_amphitheatre":470}.get(id,482)
	return Vector2i(x,road_y(id,x)-52)


static func props(id: StringName) -> Array[Dictionary]:
	match id:
		&"rootbound_conservatory": return [_prop(352,440,20,20,4.0,"b58b56"),_prop(754,414,20,20,3.0,"c7aa70"),_prop(840,410,24,26,5.0,"98ad9b")]
		&"prism_archive": return [_prop(588,322,18,18,3.0,"b2cbd7"),_prop(720,368,20,22,4.0,"ba9b73"),_prop(950,432,20,24,5.0,"98aebf")]
		&"eventide_station": return [_prop(644,414,20,20,5.0,"99b5c4"),_prop(802,240,24,22,6.0,"c7a774"),_prop(882,238,20,24,4.0,"b3bdc1")]
		&"buried_baths": return [_prop(612,514,18,18,3.0,"b89d72"),_prop(684,512,20,20,4.0,"8eb6bf"),_prop(944,230,24,26,5.0,"b1a78e")]
		&"saltglass_sinkhole": return [_prop(650,576,20,20,4.0,"b5cbd0"),_prop(702,576,18,20,3.0,"b8a179"),_prop(690,146,20,20,5.0,"93b3b6")]
		&"starfall_amphitheatre": return [_prop(354,470,20,20,4.0,"ac9778"),_prop(554,404,22,20,5.0,"a9bdcb"),_prop(732,480,20,20,4.0,"aa8d72")]
	return [_prop(682,610,20,20,5.0,"b0bcc4"),_prop(802,628,22,20,5.0,"c49a66"),_prop(952,454,20,24,4.0,"a8bcc7")]


static func _prop(x: int, y: int, w: int, h: int, mass: float, color: String) -> Dictionary:
	return {"position":Vector2(x,y),"size":Vector2(w,h),"mass":mass,"color":Color(color)}


static func npc_spawns(id: StringName) -> PackedVector2Array:
	if id == &"prism_archive":
		return PackedVector2Array([Vector2(620,road_y(id,620)-42),Vector2(940,road_y(id,940)-42)])
	return PackedVector2Array([Vector2(350,road_y(id,350)-42),Vector2(866,road_y(id,866)-42)])
