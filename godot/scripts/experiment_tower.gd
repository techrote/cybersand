class_name CyberExperimentTower
extends RefCounted

const VERSION: int = 4
const FLOORS: Array[String] = ["Flowing powders", "Water and erosion", "Liquid gallery", "Mercury references", "Chemistry observations"]
const QUICK: Array = [[2,14,29,13,1,0], [3,2,14,29,1,0], [3,16,24,33,20,21], [33,2,1,0,3,13], [3,23,8,12,28,6]]

static func floor_y(floor_index: int) -> int:
	return 8 + clampi(floor_index, 0, 4) * 198

static func landing(floor_index: int) -> Vector2:
	return Vector2(20, floor_y(floor_index) + 158)

static func tubes(floor_index: int) -> Array:
	# x, material, width, purpose. Every tube has 82 cells of contents and
	# a three-cell amber plug, more than five player heights above its pit.
	match floor_index:
		0: return [[90,2,34,"Sand / Dust coflow"],[130,14,34,""],[390,2,34,"Sand / Rust avalanche"],[430,29,34,""],[690,13,34,"Stone / Sand collapse"],[730,2,34,""]]
		1: return [[90,3,34,"Water / Sand coflow"],[130,2,34,""],[390,3,34,"Narrow stream / Sand slope"],[430,2,34,""],[690,3,56,"Broad stream / settling"],[752,2,34,""]]
		2: return [[85,3,30,"Water"],[163,16,30,"Oil"],[241,24,30,"Brine"],[319,33,30,"Mercury"],[397,20,30,"Paste"],[475,21,30,"Slush"],[553,8,30,"Lava"],[631,12,30,"Acid"],[709,30,30,"Cement"],[787,32,30,"Toxic Sludge"],[865,36,30,"Molten Glass"]]
		3: return [[110,33,34,"Packed Sand / period 30"],[410,2,34,"Pour Sand, then Mercury"],[455,33,34,""],[710,33,34,"Void / excavation control"]]
		_: return [[90,3,30,"Water / Salt"],[126,23,30,""],[240,3,30,"Water / Lava"],[276,8,30,""],[390,12,30,"Acid / Metal"],[426,28,30,""],[540,7,30,"Wood / ignite manually"],[690,16,30,"Oil / ignite manually"],[840,27,30,"Coal / ignite manually"]]

static func plugs(floor_index: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for tube: Array in tubes(floor_index):
		var width: int = int(tube[2]) - 6
		var x: int = int(tube[0]) + 3
		if floor_index == 1 and int(tube[0]) == 390:
			x += 11
			width = 6
		out.append(Rect2i(x, floor_y(floor_index)+110, width, 3))
	return out

static func rectangles() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	CyberDemoWorlds._rect(out, 0, 0, 1024, 8, 1)
	CyberDemoWorlds._rect(out, 0, 0, 8, 1024, 1)
	CyberDemoWorlds._rect(out, 992, 0, 32, 1024, 1)
	CyberDemoWorlds._rect(out, 0, 998, 1024, 26, 1)
	for f: int in range(5):
		var y: int = floor_y(f)
		# Open vertical shaft at x=8..57, with safe landing shelves. Wall is
		# deliberately inert: reactive contents cannot dissolve the separation.
		CyberDemoWorlds._rect(out, 8, y+174, 28, 5, 1) # x36..57 continuous jetpack passage
		CyberDemoWorlds._rect(out, 58, y, 934, 5, 1)
		CyberDemoWorlds._rect(out, 58, y+188, 934, 10, 1)
		CyberDemoWorlds._rect(out, 58, y+115, 5, 73, 1)
		var walls: Array = [360,660,960]
		if f == 2: walls = [151,229,307,385,463,541,619,697,775,853,960]
		if f == 4: walls = [210,360,510,660,810,960]
		for x: int in walls:
			CyberDemoWorlds._rect(out, x, y+5, 4, 183, 1)
		for tube: Array in tubes(f):
			CyberDemoWorlds._tank(out,int(tube[0]),y+25,int(tube[2]),88,1,int(tube[1]),82)
		for plug: Rect2i in plugs(f):
			CyberDemoWorlds._rect(out,plug.position.x,plug.position.y,plug.size.x,plug.size.y,79)
		# Acid can dissolve the visible amber material. An inert facing keeps
		# release manual; the same three-row erase command removes both layers.
		var floor_tubes: Array=tubes(f)
		var floor_plugs: Array[Rect2i]=plugs(f)
		for index: int in range(floor_tubes.size()):
			if int(floor_tubes[index][1])==12:
				var plug: Rect2i=floor_plugs[index]
				CyberDemoWorlds._rect(out,plug.position.x,plug.position.y,plug.size.x,1,1)
		if f == 0:
			# Converge separated tube outlets into a shared falling stream. This
			# makes actual-motion mixing visible before ordinary packing resumes.
			for i: int in range(34):
				CyberDemoWorlds._rect(out,90+i,y+119+i/2,1,3,1)
				CyberDemoWorlds._rect(out,165-i,y+119+i/2,1,3,1)
			for i: int in range(60):
				CyberDemoWorlds._rect(out,380+i,y+140+i/3,1,3,1)
			CyberDemoWorlds._rect(out,170,y+133,55,3,1) # baffle
			CyberDemoWorlds._rect(out,680,y+170,200,3,79) # removable support
		if f == 1:
			for start: int in [375,675]:
				for i: int in range(100):
					CyberDemoWorlds._rect(out,start+i,y+139+i/4,1,49-i/4,2)
			CyberDemoWorlds._rect(out,845,y+175,90,13,3)
		if f == 2:
			# Four-cell manually erasable mixing gates between otherwise isolated bays.
			for x: int in walls:
				if x < 853: CyberDemoWorlds._rect(out,x,y+176,4,12,79)
			CyberDemoWorlds._rect(out,622,y+176,1,12,1) # Acid-facing gate walls
			CyberDemoWorlds._rect(out,697,y+176,1,12,1)
			CyberDemoWorlds._rect(out,90,y+145,30,3,1) # ledge / spray
		if f == 3:
			CyberDemoWorlds._rect(out,110,y+113,3,75,1)
			CyberDemoWorlds._rect(out,141,y+113,3,75,1)
			CyberDemoWorlds._rect(out,113,y+133,28,55,2)
			for i: int in range(110):
				CyberDemoWorlds._rect(out,380+i,y+145+i/4,1,3,1)
			CyberDemoWorlds._rect(out,700,y+148,100,40,2)
			CyberDemoWorlds._rect(out,719,y+148,12,40,0)
			CyberDemoWorlds._rect(out,680,y+185,160,3,79)
		if f == 4:
			# Solid Metal does not drain from a tube. Put a separate target bed
			# in Acid's catch pit so opening its plug actually initiates contact.
			CyberDemoWorlds._rect(out,390,y+176,66,12,28)
	return out
