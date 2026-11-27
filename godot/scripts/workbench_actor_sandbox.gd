extends RefCounted

# Ordinary authored starts for the actor sandbox. These contain real catalogue
# actors and material rectangles; no decorative stand-ins or secondary owner.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const IDS := ["mixed","barrels","mechanical"]
const LABELS := {"mixed":"Living Mixed Workshop", "barrels":"Barrel Crowd", "mechanical":"Mechanical Chaos"}
const MAX_BARRELS := 4096


static func build(kind: String, policy: PackedInt32Array, count: int = 64) -> Dictionary:
	match kind:
		"mixed": return living_workshop(policy)
		"barrels": return barrel_crowd(policy,count)
		"mechanical": return mechanical_chaos(policy)
	return {}


static func _capacity(data: Dictionary) -> Dictionary:
	var bodies := 0
	var proxies := 0
	for actor: Dictionary in data.actors:
		bodies += Catalog.part_count(str(actor.model))
		proxies += Catalog.proxy_count(str(actor.model))
	data["sandbox_capacity"] = {"version":1,"logical_limit":maxi(8,data.actors.size()),
		"body_limit":maxi(64,bodies),"proxy_limit":maxi(64,proxies)}
	data.next_id = data.actors.size()+1
	return data


static func living_workshop(policy: PackedInt32Array) -> Dictionary:
	# Preserve the accepted six-actor layout and equipment choices. Extend its
	# empty lower strip into a catch basin and add a suspended swing platform;
	# the open air above remains available for painting, flight and mouse grabs.
	var data := Setup.mixed_actor_workshop(policy)
	Setup._box(data.edits,Vector2i(20,476),Vector2i(1004,488),Setup.WALL)
	Setup._box(data.edits,Vector2i(20,392),Vector2i(28,476),Setup.WALL)
	Setup._box(data.edits,Vector2i(996,392),Vector2i(1004,476),Setup.WALL)
	Setup._box(data.edits,Vector2i(400,462),Vector2i(520,476),Setup.SAND)
	Setup._box(data.edits,Vector2i(424,196),Vector2i(552,202),Setup.WALL)
	data.material = Setup.WOOD
	return _capacity(data)


static func barrel_crowd(policy: PackedInt32Array, count: int) -> Dictionary:
	if count < 1 or count > MAX_BARRELS: return {}
	# Scale the staging grid and canvas together. Every barrel starts separated;
	# even 4096 barrels fit wholly inside the existing 2048-cell world bound.
	var columns := 16 if count <= 128 else (32 if count <= 1024 else 64)
	columns = mini(columns,count)
	var rows := ceili(float(count)/float(columns))
	var width := maxi(1024,ceili(float(columns*24+128)/64.0)*64)
	var height := maxi(640,ceili(float(rows*24+280)/64.0)*64)
	var data := Setup.fresh(policy,Vector2i(width,height))
	var e: Array = data.edits
	var floor_y := height-28
	Setup._box(e,Vector2i(8,floor_y),Vector2i(width-8,floor_y+12),Setup.WALL)
	Setup._box(e,Vector2i(8,24),Vector2i(16,floor_y),Setup.WALL)
	Setup._box(e,Vector2i(width-16,24),Vector2i(width-8,floor_y),Setup.WALL)
	# Opposing shallow staircase ramps funnel falling barrels into a central
	# construction area, with enough empty space to lift and arrange them.
	for step: int in 8:
		var ledge_y := floor_y-96+step*12
		Setup._box(e,Vector2i(48+step*24,ledge_y),Vector2i(72+step*24,floor_y),Setup.WALL)
		Setup._box(e,Vector2i(width-72-step*24,ledge_y),Vector2i(width-48-step*24,floor_y),Setup.WALL)
	Setup._box(e,Vector2i(width/2-64,floor_y-12),Vector2i(width/2+64,floor_y),Setup.SAND)
	var x0 := (float(width)-float(columns-1)*24.0)*0.5
	for index: int in count:
		var x := x0+float(index%columns)*24.0
		var y := 64.0+floorf(float(index)/float(columns))*24.0
		data.actors.append(Setup.instance(Setup.BARREL,index+1,Vector2(x,y)))
	data.material = Setup.WALL
	data.selected = 1
	return _capacity(data)


static func mechanical_chaos(policy: PackedInt32Array) -> Dictionary:
	var data := Setup.fresh(policy,Vector2i(1024,640))
	var e: Array = data.edits
	Setup._box(e,Vector2i(8,548),Vector2i(1016,564),Setup.WALL)
	Setup._box(e,Vector2i(8,80),Vector2i(16,548),Setup.WALL)
	Setup._box(e,Vector2i(1008,80),Vector2i(1016,548),Setup.WALL)
	# Low steps, an overhead shelf, a granular patch and a clear landing area.
	for step: int in 5:
		Setup._box(e,Vector2i(220+step*20,540-step*8),Vector2i(240+step*20,548),Setup.WALL)
	Setup._box(e,Vector2i(416,532),Vector2i(508,548),Setup.SAND)
	Setup._box(e,Vector2i(600,384),Vector2i(760,392),Setup.WALL)
	Setup._box(e,Vector2i(772,532),Vector2i(788,548),Setup.WOOD)
	var cast := [["stuntbuggy",Vector2(110,516)],["trialsbike",Vector2(350,512)],
		["inchworm",Vector2(548,516)],["rocker",Vector2(684,520)],
		["heavylift",Vector2(830,240)],["pendulum",Vector2(920,516)]]
	for index: int in cast.size():
		var actor := Setup.instance(str(cast[index][0]),index+1,cast[index][1])
		actor.control = Catalog.default_control(str(actor.model))
		actor.control.source = "human" if index == 0 else "scripted"
		if index == 3: actor.control.source = "policy"
		data.actors.append(actor)
	data.selected = 1
	data.material = Setup.WOOD
	return _capacity(data)
