extends RefCounted
## A finite, owner-reviewable workshop composition with three real local workers.
## Demonstration decisions are made by the test harness or owner, never this factory.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign=preload("res://scripts/batch_lab/architecture_campaign.gd")
const Delegation=preload("res://scripts/batch_lab/architecture_delegation.gd")
const AREA:=Rect2i(0,0,512,512)
const PASSAGE:=[208,336,96,80]
const RECOVERY_AREA:=Rect2i(64,160,384,160)

static func rectangle(x: int,y: int,w: int,h: int,material:=58) -> Dictionary:
	return {"shape":"rectangle","x0":x,"y0":y,"x1":x+w-1,"y1":y+h-1,"material":material}

static func stage(identity: String,intent: String,region:=AREA,ceiling:=32768) -> Dictionary:
	var value:=Compiler.stage_defaults(identity,region)
	value.intent=intent; value.materials=[0,7,28,58]; value.budget.max_checked_cells=ceiling
	if region.encloses(Compiler.rect(PASSAGE)): value.clearances=[PASSAGE.duplicate()]
	return value

static func leaf(value: Dictionary,title: String,kind: String,deps: Array=[],parent:="structure") -> Dictionary:
	return {"id":value.id,"parent_id":parent,"title":title,"kind":kind,"executor":"authored-typed",
		"region":value.region.duplicate(),"depends_on":deps.duplicate(),"stage":value,"raster_candidates_limit":1048576}

static func delegated(value: Dictionary,title: String,kind: String,params: Dictionary,deps: Array,instance:="") -> Dictionary:
	var node:=leaf(value,title,"detail",deps,"local-work")
	var declared:=Delegation.declare(value,kind,params,instance)
	if not declared.ok:return declared
	node["executor"]="procedural"; node["delegation"]=declared.delegation
	return node

static func build(library: RefCounted) -> Dictionary:
	var frame:=stage("workshop-frame","A load-looking frame encloses a clear working floor; physical structural stability is not inferred.")
	frame.operations=[rectangle(16,416,480,16),rectangle(32,144,16,272),rectangle(464,144,16,272),rectangle(32,128,448,16),
		rectangle(16,432,32,48),rectangle(464,432,32,48)]
	var parts:=stage("service-parts","Place a worn wall transition and two opposed mechanical pipe faces.")
	for item: Array in [["fractured-wall-transition","workshop-transition",32,352],["valve-chamber","workshop-valve",352,352],["pipe-tee","workshop-tee",416,356]]:
		var module: Dictionary=library.get_module(item[0])
		if module.is_empty():return {"ok":false,"reason":"Missing curated part: "+str(item[0])}
		parts.modules.append({"module_id":module.id,"module_sha256":module.content_sha256,"instance_id":item[1],"placement":{"origin":[item[2],item[3]],"transform":"identity"}})
	var repair:=stage("access-gallery","An intentionally conflicting first access proposal must be revised around the protected passage.",AREA,8192)
	repair.operations=[rectangle(196,376,120,8)]
	var rejected:=stage("optional-screen","Optional dense screen for an explicit owner Skip demonstration.",AREA,8192)
	rejected.operations=[rectangle(80,176,64,96)]
	var ribs:=stage("mounted-ribs","Delegate scale-appropriate ribs mounted on the actual working floor.",Rect2i(96,320,112,112),2048)
	var pipe:=stage("service-connection","Delegate a four-cell service connection between two observed complete terminal faces.",Rect2i(320,320,160,96),256)
	var wear:=stage("controlled-wear","Delegate bounded wear only on the selected live part's noncritical Hard wall shoulder.",Rect2i(32,352,64,64),64)
	var cladding:=stage("cladding-trial","An intentionally excessive panel trial is stopped after a real acknowledged prefix.",RECOVERY_AREA,65536)
	cladding.operations=[rectangle(64,160,384,160)]
	var nodes: Array=[
		{"id":"structure","parent_id":"","title":"Primary workshop and service parts","kind":"group","region":[0,0,512,512],"depends_on":[]},
		{"id":"local-work","parent_id":"","title":"Bounded source-grounded workers","kind":"group","region":[0,0,512,512],"depends_on":[]},
		leaf(frame,"Primary frame","structure"),leaf(parts,"Mechanical kit assembly","modules",[frame.id]),
		leaf(repair,"Revise the access gallery","structure",[frame.id]),leaf(rejected,"Optional opaque screen","typed",[frame.id]),
		delegated(ribs,"Mounted floor ribs","contextual_ribs",{"region":[104,336,96,80],"material":28,"seed":47017,"max_cells":512,"facing":"up","width":2,"depth":12,"spacing":12,"density":0.65},[parts.id,repair.id]),
		delegated(pipe,"Connect the full service faces","short_pipe",{"region":[400,370,16,4],"material":28,"seed":47017,"max_cells":64,"waypoints":[[400,371],[415,371]],"width":4},[parts.id]),
		delegated(wear,"Vary the noncritical shoulder","edge_wear",{"region":[60,396,12,12],"material":0,"seed":47017,"max_cells":8,"amount":8},[parts.id],"workshop-transition"),
		leaf(cladding,"Stop the dense cladding trial","typed",[ribs.id,pipe.id,wear.id],"local-work")]
	for node: Dictionary in nodes:
		if node.has("ok") and not node.ok:return node
	var campaign:={"format":Campaign.FORMAT,"id":"delegated-workshop","title":"Delegated workshop with owner decisions",
		"intent":"Construct a small coherent workshop through authored structure, reusable parts and independently bounded procedural jobs. Rejection, revision and Stop require explicit decisions.",
		"region":[0,0,512,512],"budget":{"native_checks":262144,"raster_candidates":8388608,"max_retries_per_job":2},"nodes":nodes}
	var checked:=Campaign.validate(campaign)
	return {"ok":true,"campaign":campaign} if checked.ok else checked

static func repaired_gallery() -> Dictionary:
	var value:=stage("access-gallery","The revised side gallery leaves the central floor passage clear.",AREA,8192)
	value.operations=[rectangle(64,328,112,8),rectangle(104,336,4,80),rectangle(172,336,4,80)]
	return value

static func recovery_attachments() -> Dictionary:
	var value:=stage("attach-workshop-bays","Connect the recovered bays and their service fins to the observed roof with complete face contacts.",Rect2i(32,128,448,192),1024)
	value.materials=[28,58]
	for x: int in [64,440]:
		value.operations.append(rectangle(x,144,8,16))
		for dx: int in 8:
			value.connections.append({"kind":"solid-contact","a":[x+dx,143],"b":[x+dx,144]})
			value.connections.append({"kind":"solid-contact","a":[x+dx,159],"b":[x+dx,160]})
	for x: int in [88,112,136,360,384,408]:
		value.operations.append(rectangle(x,168,8,16,28))
		for dx: int in 8:
			value.connections.append({"kind":"solid-contact","a":[x+dx,167],"b":[x+dx,168]})
			value.connections.append({"kind":"solid-contact","a":[x+dx,183],"b":[x+dx,184]})
	return value

static func recovery(snapshot: Dictionary) -> Dictionary:
	if Compiler.rect(snapshot.get("region"))!=RECOVERY_AREA or not snapshot.get("source_sha256") is String or int(snapshot.get("generation",0))<1:
		return {"ok":false,"reason":"Recovery requires a new actual inspection of the stopped cladding region."}
	var clear:=stage("clear-stopped-prefix","Remove the observed stopped cladding prefix inside its original approved trial region.",RECOVERY_AREA,65536)
	clear.operations=[rectangle(64,160,384,160,0)]; clear.input_snapshot_sha256=snapshot.source_sha256; clear.input_generation=snapshot.generation
	var resolved:=stage("open-workshop-bays","Replace the rejected dense wall with three readable service bays and a clear central hall.",RECOVERY_AREA,16384)
	resolved.operations=[rectangle(64,304,384,8),rectangle(64,160,8,144),rectangle(440,160,8,144),rectangle(64,160,112,8),rectangle(336,160,112,8)]
	for x: int in [88,112,136,360,384,408]:resolved.operations.append(rectangle(x,184,8,64,28))
	var campaign:={"format":Campaign.FORMAT,"id":"workshop-fresh-recovery","title":"Freshly inspected recovery",
		"intent":"Retain completed native structure and local work; recover the inspected stopped trial, then separately approve its declared roof and fin attachments.",
		"region":[0,0,512,512],"budget":{"native_checks":82944,"raster_candidates":3145728,"max_retries_per_job":1},
		"nodes":[leaf(clear,"Clear the witnessed partial prefix","typed",[],""),leaf(resolved,"Build open service bays","structure",[clear.id],""),leaf(recovery_attachments(),"Attach the recovered bays","connection",[resolved.id],"")]}
	var checked:=Campaign.validate(campaign)
	return {"ok":true,"campaign":campaign} if checked.ok else checked
