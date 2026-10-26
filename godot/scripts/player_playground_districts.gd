class_name CyberPlayerPlaygroundDistricts
extends RefCounted

# All districts occupy 1024 x 768 (six times the previous 512 x 256 area).
# Authored bounded rectangles, not decorative collision meshes or random noise.
const VIEW := Rect2i(0, 0, 1024, 768)
const FLOOR: int = 736
const SPAWN := Vector2(96, 688)

static func rect(out: Array, x: int, y: int, w: int, h: int, material: int) -> void:
	out.append({"origin":Vector2i(x,y), "size":Vector2i(w,h), "material":material})

static func platform(out: Array, x: int, y: int, w: int, material: int = 63) -> void:
	rect(out,x,y,w,6,material)
	rect(out,x,y,w,1,77)
	for xx: int in range(x+6,x+w-4,24): rect(out,xx,y+6,3,12,28)

static func ramp(out: Array, x: int, y: int, width: int, rise: int, material: int = 58) -> void:
	for step: int in range(0,width,4):
		var height: int = maxi(1,roundi(float(step+4)*rise/width))
		rect(out,x+step,y-height,4,height,material)

static func basin(out: Array, x: int, y: int, width: int, depth: int, liquid: int, wall: int = 35) -> void:
	rect(out,x,y,4,depth+5,wall); rect(out,x+width-4,y,4,depth+5,wall)
	rect(out,x,y+depth,width,5,wall)
	rect(out,x+4,y+depth-12,width-8,12,liquid)

static func tower(out: Array, x: int, y: int, w: int, h: int, material: int) -> void:
	# Open floors, windows and an exterior climb route, rather than a solid slab.
	rect(out,x,y,6,h,material); rect(out,x+w-6,y,6,h,material)
	for yy: int in range(y,y+h,56):
		platform(out,x,yy,w,material)
		for xx: int in range(x+15,x+w-12,25): rect(out,xx,yy+16,3,16,79)

static func layout(id: StringName) -> Array:
	var out: Array = []
	rect(out,0,0,1024,6,1);rect(out,0,0,6,768,1);rect(out,1018,0,6,768,1)
	rect(out,0,FLOOR,1024,32,58)
	rect(out,0,766,1024,2,1)
	# Common service bay, reachable without solving the main route: editable
	# materials and apparatus for every tool/projectile/processor category.
	platform(out,24,560,196,57)
	for i: int in range(8):
		rect(out,30+i*23,538,16,22,[56,35,13,7,28,81,98,102][i])
	basin(out,24,590,72,38,3);basin(out,112,590,84,38,24)
	rect(out,30,646,32,10,2);rect(out,76,646,24,10,23);rect(out,114,646,24,10,29)
	rect(out,152,646,24,10,27);platform(out,24,658,172,104)
	# Safe common start bay, signs and broad access to the lower ground lane.
	# Ground vehicles can test tools immediately without first reaching the
	# upper workbenches. The tallest targets invite cutting or a charged hop.
	for i: int in range(3): rect(out,146+i*24,724-i*3,10,12+i*3,[56,35,7][i])
	for x: int in range(24,1000,32): rect(out,x,744,12,2,79 if (x/32)%2 else 77)
	for x: int in [32,200,976]:
		rect(out,x,680,3,56,28);rect(out,x-5,674,13,5,80)
	match id:
		&"cannon_run":
			ramp(out,224,FLOOR,128,64);platform(out,352,672,64,57)
			ramp(out,432,FLOOR,144,96);platform(out,576,640,100,59)
			ramp(out,704,FLOOR,128,48);platform(out,858,666,128,130)
			for i: int in range(5): rect(out,450+i*24,722-i*2,12,14+i*2,81+i)
			tower(out,300,386,112,166,57);platform(out,450,450,156,113)
			basin(out,610,686,76,50,3);basin(out,844,690,64,46,16)
			for i: int in range(3): platform(out,480+i*150,548-i*54,74,63)
		&"rat_steps":
			for i: int in range(10): rect(out,230+i*24,730-i*7,24,6+i*7,38+i%3)
			platform(out,470,660,96,130);platform(out,594,634,46,120)
			for i: int in range(6): platform(out,664+i*48,650+(i%2)*24,26,58)
			for i: int in range(5): platform(out,268+i*132,560-i*54,58,89)
			tower(out,810,258,140,224,117);basin(out,520,686,64,50,3)
			rect(out,744,714,38,22,2);rect(out,752,708,22,6,13)
		&"afterimage_works":
			platform(out,236,708,116,63);rect(out,234,706,120,2,76)
			for i: int in range(6): platform(out,374+i*98,640-(i%3)*66,62,81+i)
			tower(out,270,244,112,224,57);tower(out,774,150,136,280,113)
			for i: int in range(4): platform(out,418+i*86,328+(i%2)*64,54,120)
			rect(out,624,668,4,68,35);rect(out,702,684,4,52,7)
			basin(out,550,700,56,36,3);basin(out,878,694,80,42,24)
		&"vector_port":
			for i: int in range(4):
				var x: int = 286+i*166
				var gap: int = 240+(i%2)*164
				rect(out,x,96,8,gap-96,113);rect(out,x,gap+100,8,596-gap,113)
				platform(out,x+28,gap+126,88,130)
				basin(out,x+24,688,92,48,[3,24,16,3][i])
			platform(out,64,310,136,104);platform(out,804,156,164,131)
			for i: int in range(7): rect(out,230+i*100,98,30,3,77 if i%2 else 78)
		&"dust_foundry":
			for i: int in range(4):
				var x: int = 280+i*164
				for tooth: int in range(10): rect(out,x,460+tooth*24,8,17,62)
				platform(out,x+22,518-(i%2)*112,86,117)
				rect(out,x+34,700,44,36,[2,14,23,13][i])
				basin(out,x+20,574,86,48,[3,24,3,24][i])
			tower(out,326,140,138,224,57);tower(out,684,170,150,224,100)
			rect(out,516,390,76,14,2);platform(out,510,404,88,120)
		&"undertow_lab":
			for i: int in range(4):
				var x: int = 250+i*178
				basin(out,x,654-(i%2)*48,136,82,[3,24,16,3][i],120)
				platform(out,x+20,478-i*64,102,113)
				rect(out,x+56,572,7,44,35);rect(out,x+32,616,60,5,35)
				# Open bypasses above each reservoir, with shallow scooping shelves.
				platform(out,x+2,620-(i%2)*48,38,63)
			basin(out,314,208,104,76,3);basin(out,556,180,104,104,24)
			platform(out,414,322,144,120);rect(out,462,290,44,32,9)
		&"rocket_yard":
			for i: int in range(8):
				var x: int = 250+i*92
				var y: int = 644-(i%4)*110
				platform(out,x,y,44,131);rect(out,x+6,y-7,32,7,78)
				if i%2==0: rect(out,x+58,y-100,5,120,117)
			tower(out,342,108,144,168,57);basin(out,534,690,114,46,3)
			rect(out,704,680,48,56,81);rect(out,764,692,40,44,35)
		_:
			# The expanded mixed course joins driving, folded-body, flight, granular
			# and usable challenges in one district; the old fixture stays separate.
			ramp(out,230,FLOOR,128,64);platform(out,372,672,92,63)
			platform(out,492,708,110,63);rect(out,490,706,114,2,76)
			for i: int in range(5): platform(out,630+i*66,620-(i%3)*68,44,81+i)
			tower(out,270,208,130,224,57);tower(out,820,142,124,224,113)
			for i: int in range(6): rect(out,704,470+i*30,6,23,62)
			basin(out,422,490,118,70,3);basin(out,574,490,96,70,24)
			platform(out,460,336,152,120);rect(out,510,306,38,30,2)
	# Upper salvage bridges and service conduits make all districts multi-level.
	platform(out,48,190,152,81);platform(out,500,112,190,113)
	for i: int in range(6):
		rect(out,520+i*25,88,12,24,[81,98,102,113,120,130][i])
	return out

static func checkpoints(id: StringName) -> PackedVector2Array:
	match id:
		&"cannon_run": return PackedVector2Array([Vector2(206,716),Vector2(380,652),Vector2(620,620),Vector2(948,646)])
		&"rat_steps": return PackedVector2Array([Vector2(206,716),Vector2(490,640),Vector2(616,614),Vector2(934,652)])
		&"afterimage_works": return PackedVector2Array([Vector2(206,716),Vector2(288,728),Vector2(502,556),Vector2(894,350)])
		&"vector_port": return PackedVector2Array([Vector2(206,660),Vector2(290,290),Vector2(456,454),Vector2(788,454)])
		&"dust_foundry": return PackedVector2Array([Vector2(220,680),Vector2(284,479),Vector2(448,551),Vector2(776,671)])
		&"undertow_lab": return PackedVector2Array([Vector2(220,680),Vector2(300,630),Vector2(476,564),Vector2(838,630)])
		&"rocket_yard": return PackedVector2Array([Vector2(272,624),Vector2(364,514),Vector2(456,404),Vector2(916,294)])
	return PackedVector2Array([Vector2(206,716),Vector2(410,652),Vector2(546,728),Vector2(890,532)])
