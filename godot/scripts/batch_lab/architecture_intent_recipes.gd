extends RefCounted
## Small deterministic intent grammar and side-elevation proposals. This is an
## offline authoring tool, not a language model and not native execution.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const FAMILIES := {
	"industrial_hangar":["hangar","industrial","assembly"],
	"arcology":["arcology","city","tower","habitat"],
	"viaduct":["viaduct","bridge","arched"],
	"biomechanical":["biomechanical","arboretum","garden","biomech"],
	"service_network":["pipework","refinery","service","pipes"],
	"organic_cavern":["cavern","cave","grotto"]}

static func infer_family(text: String) -> Dictionary:
	var normalized := " "+text.to_lower().replace("-"," ").replace("_"," ").replace(","," ").replace("."," ")+" "
	var matches: Array=[]
	for family: String in FAMILIES:
		for term: String in FAMILIES[family]:
			if (" "+term+" ") in normalized:
				matches.append(family); break
	return {"family":matches[0] if matches.size()==1 else "","matches":matches,
		"scope":"Deterministic vocabulary match. Ambiguous or unsupported intent requires an explicit family choice."}

static func _rect(ops: Array, x: int, y: int, width: int, height: int, material: int) -> void:
	if width>0 and height>0: ops.append({"shape":"rectangle","x0":x,"y0":y,"x1":x+width-1,"y1":y+height-1,"material":material})

static func build(identity: String, family: String, variant: int, region: Rect2i, seed: int, materials: Array = [58,28]) -> Dictionary:
	if family not in FAMILIES or variant<0 or variant>2: return {"ok":false,"reason":"Unknown finite architectural alternative."}
	if region.size.x<64 or region.size.y<64 or region.size.x>512 or region.size.y>512: return {"ok":false,"reason":"The intent grammar needs a selected native region between 64 and 512 cells on each side."}
	if materials.is_empty() or int(materials[0])==0: return {"ok":false,"reason":"Choose an admitted structural material."}
	var structure_material:=int(materials[0]); var detail_material:=int(materials[-1])
	var width:=region.size.x; var height:=region.size.y; var origin:=region.position
	var left:=origin.x+4; var right:=origin.x+width-5; var roof:=origin.y+6; var floor_y:=origin.y+height-10
	var middle:=origin.x+width/2; var floor_width:=right-left+1
	var structure: Array=[]; var services: Array=[]; var details: Array=[]; var clearances: Array=[]
	_rect(structure,left,roof,floor_width,4,structure_material)
	_rect(structure,left,floor_y,floor_width,5,structure_material)
	_rect(structure,left,roof,4,floor_y-roof,structure_material)
	_rect(structure,right-3,roof,4,floor_y-roof,structure_material)
	var titles: Array=["Open central hall","Offset galleries","Twin service bays"]
	var summaries: Array=["A broad central void with a continuous outside frame and roof-mounted services.","Two unequal gallery levels supported from the outside frame, leaving a central shaft.","Two bays divided by a continuous central support, with a short service gallery on each side."]
	if variant==1:
		var low:=origin.y+height*3/5; var high:=origin.y+height*2/5; var reach:=width*2/5
		_rect(structure,left,low,reach,4,structure_material)
		_rect(structure,right-reach+1,high,reach,4,structure_material)
		_rect(structure,left+reach-4,roof,3,low-roof,structure_material)
		_rect(structure,right-reach+1,roof,3,high-roof,structure_material)
		clearances.append([middle-width/14,roof+14,maxi(6,width/7),floor_y-roof-14])
	elif variant==2:
		_rect(structure,middle-2,roof,5,floor_y-roof,structure_material)
		var level:=origin.y+height/2
		_rect(structure,left,level,width/3,4,structure_material)
		_rect(structure,right-width/3+1,level,width/3,4,structure_material)
		clearances.append([left+6,floor_y-12,middle-left-10,12])
		clearances.append([middle+5,floor_y-12,right-middle-10,12])
	else:
		clearances.append([left+6,floor_y-14,right-left-12,14])
	if family=="viaduct":
		# Stepped intrados stays genuinely orthographic. Each added shoulder
		# joins the roof or side pier; no decorative perspective surface.
		for step: int in 4:
			_rect(structure,left+4+step*3,roof+4,3,maxi(2,16-step*3),structure_material)
			_rect(structure,right-6-step*3,roof+4,3,maxi(2,16-step*3),structure_material)
	elif family=="organic_cavern":
		for step: int in 5:
			_rect(structure,left+4,roof+10+step*maxi(4,height/12),2+(step+variant)%3,4+(step%2)*3,structure_material)
			_rect(structure,right-7-(step%3),roof+12+step*maxi(4,height/13),5+(step%3),3,structure_material)
	elif family=="arcology":
		for side: int in [left+4,right-7]:
			for level: int in 3: _rect(structure,side,roof+12+level*maxi(8,(floor_y-roof-24)/3),4,6,structure_material)
	elif family=="biomechanical":
		for side: int in [left+4,right-8]:
			_rect(structure,side,floor_y-24,5,8,structure_material)
			_rect(structure,side-1,floor_y-25,7,2,structure_material)
	var service_y:=roof+10
	# Hangers touch the existing roof; the horizontal route joins the hangers.
	_rect(services,left+8,roof+4,2,7,detail_material)
	_rect(services,right-9,roof+4,2,7,detail_material)
	_rect(services,left+8,service_y,right-left-15,2,detail_material)
	if family=="service_network":
		_rect(services,left+5,service_y+2,2,maxi(2,floor_y-service_y-20),detail_material)
		_rect(services,left+5,service_y+2,5,2,detail_material)
		_rect(services,right-6,service_y+2,2,maxi(2,floor_y-service_y-20),detail_material)
		_rect(services,right-8,service_y+2,4,2,detail_material)
	var spacing:=maxi(8,width/(6+variant*2)); var offset:=posmod(seed,3)
	for x: int in range(left+8+offset,right-8,spacing):
		_rect(details,x,roof+4,2,1,detail_material)
	var stages: Array=[]; var nodes: Array=[]
	nodes.append({"id":"composition","title":titles[variant],"kind":"group","region":Compiler.rect_array(region),"depends_on":[]})
	var phases: Array=["structure","services","detail"]
	var outputs: Array=[structure,services,details]
	for index: int in phases.size():
		var phase: String=phases[index]
		var value:=Compiler.stage_defaults(phase,region)
		value["title"]=["Build structural frame","Attach bounded services","Add roof-face detail"][index]
		value.intent=str(value.title)+" for "+family.replace("_"," ")+" / "+str(titles[variant])
		value.operations=outputs[index]
		value.materials=[0,structure_material] if structure_material==detail_material else [0,structure_material,detail_material]
		value.clearances=clearances.duplicate(true)
		value.depends_on=[] if index==0 else [phases[index-1]]
		value.budget.max_checked_cells=region.get_area()
		value.expected_effects="A deterministic side-elevation proposal; host compilation calculates exact native cost and verifies clearances."
		nodes.append({"id":phase,"parent_id":"composition","title":value.title,"kind":phase,"executor":"offline-typed-grammar","region":value.region.duplicate(),
			"depends_on":value.depends_on.duplicate(),"stage":value,"raster_candidates_limit":mini(Compiler.MAX_RASTER_CANDIDATES,region.get_area()*4)})
		stages.append(value)
	var campaign: Dictionary={"format":Campaign.FORMAT,"id":identity,"title":titles[variant],"intent":summaries[variant],"region":Compiler.rect_array(region),
		"budget":{"native_checks":mini(Campaign.MAX_NATIVE_CHECKS,region.get_area()*6),"raster_candidates":mini(Campaign.MAX_RASTER_CANDIDATES,region.get_area()*12),"max_retries_per_job":1},
		"nodes":nodes,"provenance":{"kind":"offline-deterministic-intent-grammar","family":family,"variant":variant,"seed":seed,"real_model_calls":0,
			"scope":"Authored geometric strategy, not inference quality, native qualification, actor traversal or owner acceptance."}}
	var checked:=Campaign.validate(campaign)
	if not checked.ok: return checked
	return {"ok":true,"title":titles[variant],"summary":summaries[variant],"campaign":campaign,"zero_writes":true}
