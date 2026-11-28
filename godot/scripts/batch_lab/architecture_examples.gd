extends RefCounted
## Authored side-elevation construction recipes. Source cards inform design
## strategy; these are independent geometry, not traced or admitted GOLDMAPS.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const ContextDetail = preload("res://scripts/batch_lab/architecture_context_detail.gd")
const NAMES := ["Assembly hangar","Interconnected arcology","Biomechanical arboretum", "Irregular megastructure","Service and pipework network","Constructed cavern"]
const IDS := ["assembly-hangar","interconnected-arcology","biomechanical-arboretum","irregular-megastructure","service-network","constructed-cavern"]

static func families() -> Array[String]:
	var output: Array[String] = []
	output.assign(NAMES)
	return output

static func extent(family: String) -> Vector2i:
	return Vector2i(384,256) if family in [NAMES[2],NAMES[5],IDS[2],IDS[5]] else Vector2i(480,320)

static func _rect(ops: Array, x: int, y: int, w: int, h: int, material := 58) -> void:
	if w<1 or h<1: return
	ops.append({"shape":"rectangle","x0":x,"y0":y,"x1":x+w-1,"y1":y+h-1,"material":material})

static func _line(ops: Array, a: Vector2i, b: Vector2i, width := 3, material := 28) -> void:
	ops.append({"shape":"line","x0":a.x,"y0":a.y,"x1":b.x,"y1":b.y,"width":width,"material":material})

static func _truss(ops: Array, x: int, y: int, w: int, depth: int, spacing := 32) -> void:
	_rect(ops,x,y,w,4,28)
	_rect(ops,x,y+depth,w,4,28)
	var index := 0
	for at: int in range(x,x+w-spacing+1,spacing):
		_line(ops,Vector2i(at,y+2 if index%2==0 else y+depth+1),Vector2i(at+spacing,y+depth+1 if index%2==0 else y+2),2)
		index += 1

static func _room(ops: Array, x: int, y: int, w: int, h: int, door_left := true, material := 58) -> void:
	_rect(ops,x,y,w,5,material)
	_rect(ops,x,y+h-5,w,5,material)
	_rect(ops,x if door_left else x+w-5,y,5,h-28,material)
	_rect(ops,x+w-5 if door_left else x,y,5,h,material)

static func _shift(ops: Array, origin: Vector2i) -> Array:
	var shifted: Array = ops.duplicate(true)
	for operation: Dictionary in shifted:
		if operation.get("shape")=="pixels":
			for point: Array in operation.points:
				point[0] = int(point[0])+origin.x
				point[1] = int(point[1])+origin.y
		for key: String in ["x0","x1"]:
			if operation.has(key): operation[key] = int(operation[key])+origin.x
		for key: String in ["y0","y1"]:
			if operation.has(key): operation[key] = int(operation[key])+origin.y
	return shifted

static func _shift_rects(rects: Array, origin: Vector2i) -> Array:
	var output: Array = []
	for box: Array in rects: output.append([int(box[0])+origin.x,int(box[1])+origin.y,int(box[2]),int(box[3])])
	return output

static func plan(family: String, origin := Vector2i(16,16), seed := 37901) -> Dictionary:
	var index := NAMES.find(family)
	if index<0: index = IDS.find(family)
	if index<0: return {}
	var size := extent(NAMES[index])
	var structure: Array = []
	var services: Array = []
	var detail: Array = []
	var corridors: Array = []
	var zones: Array = []
	var anchors: Array = []
	var cards: Array = []
	match index:
		0:
			_rect(structure,16,288,448,12)
			_rect(structure,32,42,12,246)
			_rect(structure,436,42,12,246)
			_truss(structure,24,28,432,24,36)
			for x: int in [44,394]:
				_rect(structure,x,226,42,7,28)
				_line(structure,Vector2i(x,245),Vector2i(x+42,231),3)
			for spec: Array in [[88,60,52,38],[210,60,72,42],[342,60,42,28]]:
				_rect(services,spec[0],spec[1],spec[2],spec[3],28)
				_rect(services,spec[0]+7,spec[1]+8,spec[2]-14,spec[3]-16,13)
				# Visible roof hangers join each housing to the lower truss chord.
				_rect(services,spec[0]+spec[2]/2-2,56,4,spec[1]-56,28)
			_rect(services,20,128,12,116,28)
			_rect(services,448,84,10,170,28)
			_rect(services,44,256,38,6,28)
			_rect(services,398,256,38,6,28)
			corridors = [[92,104,296,150],[48,264,384,24]]
			zones = [[48,60,30,130],[394,62,32,128],[86,18,300,8]]
			anchors = [[32,42,12,246],[436,42,12,246],[24,28,432,28]]
			cards = ["gold146","gold159"]
		1:
			_rect(structure,16,290,448,10)
			# The continuous lower route rules out founded interior columns.
			# Exterior piers and a roof truss visibly suspend the three pods.
			for x: int in [8,464]: _rect(structure,x,20,8,280)
			_truss(structure,12,20,456,18,38)
			for hanger: Array in [[78,42,4,62],[246,42,4,6],[406,42,4,86]]:
				_rect(structure,hanger[0],hanger[1],hanger[2],hanger[3],28)
			_room(structure,24,104,116,142,true)
			_room(structure,188,48,128,176,true)
			_room(structure,360,128,96,128,false)
			for spec: Array in [[24,174,116],[188,128,128],[360,192,96]]: _rect(structure,spec[0],spec[1],spec[2],5)
			_truss(services,136,174,56,12,28)
			_truss(services,312,192,52,10,26)
			_rect(services,140,218,40,6,28)
			_rect(services,320,250,40,6,28)
			for x: int in [32,196,368]:
				for y: int in range(66 if x==196 else 142,101 if x==196 else 164,12): _rect(services,x-3,y,45,3,28)
			corridors = [[16,266,448,24],[144,96,24,72],[328,106,24,80]]
			zones = [[32,110,92,44],[198,58,104,52],[368,136,72,38]]
			anchors = [[24,104,116,5],[188,48,128,5],[360,128,96,5]]
			cards = ["gold174","gold130","gold131"]
		2:
			_rect(structure,12,226,360,12,13)
			_rect(structure,12,14,360,8,13)
			# Rock shoulders join ceiling and floor outside the broad mid-level route.
			for x: int in [4,372]: _rect(structure,x,14,8,224,13)
			for spec: Array in [[38,22,28,62],[114,22,40,86],[218,22,26,54],[304,22,46,72]]:
				_rect(structure,spec[0]+spec[2]/2-4,spec[1],8,spec[3],7)
				_rect(structure,spec[0],spec[1]+spec[3]-22,spec[2],26,7)
				_rect(structure,spec[0]+5,spec[1]+spec[3]-17,spec[2]-10,16,0)
				_rect(services,spec[0]+5,spec[1]+spec[3]-17,spec[2]-10,16,19)
				_rect(services,spec[0]+spec[2]/2+5,28,3,spec[3]-30,28)
				_rect(services,spec[0]+spec[2]/2+4,28,1,3,28)
			for spec: Array in [[32,180,56,46],[254,174,74,52]]:
				_room(structure,spec[0],spec[1],spec[2],spec[3],spec[0]<100,13)
			_rect(services,88,202,166,5,28)
			corridors = [[16,122,352,40],[92,211,152,15]]
			zones = [[28,90,48,20],[108,112,52,8],[212,84,38,24],[296,100,60,18],[38,186,42,12],[260,180,58,14]]
			anchors = [[12,14,360,8],[32,180,56,5],[254,174,74,5]]
			cards = ["gold143","gold150"]
		3:
			_rect(structure,12,290,456,12)
			_rect(structure,28,44,20,246)
			_rect(structure,420,148,22,142)
			_truss(structure,40,232,388,28,32)
			_truss(structure,40,76,164,24,32)
			_truss(structure,288,114,146,20,28)
			_room(services,60,164,94,62,true)
			_room(services,334,166,80,60,false)
			_line(services,Vector2i(46,112),Vector2i(110,164),4)
			_line(services,Vector2i(350,136),Vector2i(420,168),4)
			_rect(services,184,104,20,28,28)
			_rect(services,288,138,22,20,28)
			corridors = [[208,56,72,156],[52,266,360,24]]
			zones = [[52,48,116,24],[292,140,34,20],[64,168,82,28],[340,170,64,26]]
			anchors = [[28,44,20,246],[40,232,388,4],[420,148,22,142]]
			cards = ["gold207","gold109","gold193"]
		4:
			_rect(structure,16,290,448,10)
			for y: int in [96,184]:
				_rect(structure,20,y,174 if y==96 else 270,6)
				_rect(structure,224 if y==96 else 320,y,236 if y==96 else 140,6)
			for x: int in [20,450]: _rect(structure,x,34,10,256)
			for spec: Array in [[36,24,80,40],[270,116,96,38],[88,220,64,60]]: _room(services,spec[0],spec[1],spec[2],spec[3],true,28)
			for spec: Array in [[42,106,150],[226,106,206],[42,194,246],[320,194,96],[162,278,254]]:
				_rect(services,spec[0],spec[1],spec[2],4,28)
				for x: int in range(spec[0]+14,spec[0]+spec[2]-14,54): _rect(services,x,spec[1]-4,4,12,28)
			# Housings meet the pillar/pipework; lower rail feet meet the base.
			_rect(services,30,34,6,2,28)
			_rect(services,282,110,4,6,28)
			_rect(services,108,198,4,22,28)
			for x: int in range(176,402,54): _rect(services,x,286,4,4,28)
			_rect(services,444,62,5,204,28)
			corridors = [[32,68,160,24],[224,68,218,24],[32,156,228,24],[368,156,74,24],[162,246,254,24],
				[196,72,24,70],[292,160,24,72]]
			zones = [[38,28,72,22],[274,118,84,24],[92,222,52,20],[44,112,144,18],[228,112,28,18],[368,112,52,18],[44,200,236,16],[324,200,62,16]]
			anchors = [[20,96,174,6],[224,96,236,6],[20,184,270,6],[320,184,140,6]]
			cards = ["gold159","gold179","gold168"]
		5:
			_rect(structure,0,232,384,24,13)
			_rect(structure,0,0,384,16,13)
			_rect(structure,0,16,18,216,13)
			_rect(structure,362,16,22,216,13)
			for spec: Array in [[18,16,64,26],[18,42,26,46],[18,160,24,72],[312,16,50,36],[338,52,24,50],[322,180,40,52]]:
				_rect(structure,spec[0],spec[1],spec[2],spec[3],13)
			_room(services,24,92,72,54,true)
			_room(services,276,66,62,64,false)
			_room(services,270,168,52,44,false)
			_rect(services,92,150,54,5,28)
			_rect(services,238,146,84,5,28)
			_rect(services,18,100,6,4,28)
			_rect(services,92,146,4,4,28)
			_rect(services,320,130,2,16,28)
			_line(services,Vector2i(43,160),Vector2i(64,146),3)
			_line(services,Vector2i(320,151),Vector2i(320,176),3)
			corridors = [[152,50,80,150],[44,214,276,18],[96,124,48,20],[238,124,38,20]]
			zones = [[28,96,60,22],[282,72,48,26],[274,172,42,18],[44,50,18,30],[342,116,16,48]]
			anchors = [[24,92,72,5],[276,66,62,5],[270,168,52,5]]
			cards = ["gold125","gold175","gold130"]
	# The independent helper chooses only actual Empty faces of authored
	# supports/services. Randomness selects among valid anchors, never space.
	var anchored: Dictionary = ContextDetail.build(structure,services,size,zones,corridors,seed,512)
	if anchored.get("ok",false): detail=anchored.operations
	var inputs := [structure,services,detail]
	for i: int in cards.size(): cards[i] = str(cards[i]).replace("gold","goldmaps-pr")
	var names := ["structure","services","detail"]
	var intents := ["Build connected primary supports, slabs and macro space.","Fit architectural service assemblies around protected traversal spaces.","Add sparse seeded details to declared architectural zones."]
	var stages: Array = []
	for stage_index: int in 3:
		var value := Compiler.stage_defaults(IDS[index]+"-"+names[stage_index],Rect2i(origin,size))
		value.intent = intents[stage_index]
		value.materials = [0,58,28,13,7,19]
		value.operations = _shift(inputs[stage_index],origin)
		value.clearances = _shift_rects(corridors,origin)
		value.protected = value.clearances.duplicate(true)
		value.depends_on = [] if stage_index==0 else [stages[stage_index-1].id]
		value.expected_effects = "%s: %s No writes are authorized before a valid host preview." % [NAMES[index],intents[stage_index]]
		value["reference_card_ids"] = cards
		stages.append(value)
	return {"format":Compiler.FORMAT,"id":IDS[index]+"-"+str(seed),"recipe_revision":"support-contact-v2","intent":NAMES[index]+" with purposeful playable negative space and contextual detail.",
		"seed":seed,"origin":[origin.x,origin.y],"extent":[size.x,size.y],"family":IDS[index],"stages":stages,
		"provenance":{"kind":"independently-authored-native-recipe","source":"WORLD-STEER-BATCH-M3-M5-001","reference_card_ids":cards,
			"scope":"Architectural interpretations only; GOLDMAPS source art and original native refusal identities are not copied or promoted."},
		"evaluation_context":{"schema_version":"cybersand.architectural-stage-role-context.v1","structural_materials":[58,28,13,7],"detail_materials":[28],"anchor_rects":anchors,
			"material_roles_disjoint":false,"disjoint_material_reducer_compatible":false,
			"detail_isolation":{"method":"native-stage-delta","before_stage":IDS[index]+"-services","after_stage":IDS[index]+"-detail","before_material":0,"after_material":28},
			"clearance_rects":corridors,"protection_rects":corridors,"requested_detail_zones":zones,"detail_zones":anchored.get("expanded_detail_zones",zones),
			"detail_generation":{"kind":"occupied-face-context","emitted_cells":anchored.get("emitted_cells",0),"eligible_faces":anchored.get("eligible_faces",0),
				"zone_expansion_cells":anchored.get("zone_expansion_cells",0),"scope":anchored.get("scope","")},
			"detail_identity":"Metal is also structural in these demonstrations; compare the services-stage and detail-stage native planes to isolate additions. Do not apply a disjoint-material detail classifier.",
			"scope":"Static geometry proxies. Actor traversal, physical stability, human preference and model quality remain unqualified."}}
