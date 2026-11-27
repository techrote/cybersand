extends RefCounted
## Registered deterministic tool-arm apparatus. No adaptation to observed results.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Design=preload("res://scripts/batch_lab/architectural_retrieval.gd")
const Retrieval=preload("res://scripts/batch_lab/architecture_compositional_retrieval.gd")
const EXTENT:=Vector2i(256,192)
const ARMS:=["hand_typed","procedural_structure","random_fitting_modules","reference_guided","retrieval_guided"]
const EXCLUDED:=["bioindustrial","civic","vessel_dock"]
const MAX_NATIVE:=32768

static func box(x: int,y: int,w: int,h: int,material:=58) -> Dictionary:
	return {"shape":"rectangle","x0":x,"y0":y,"x1":x+w-1,"y1":y+h-1,"material":material}

static func development_briefs() -> Array:
	return [{"id":"development-arch-bay","cohort":"development","family":"open_arch","intent":"curved arch enclosing useful negative space",
		"slots":[{"id":"span","region":[32,32,96,64],"part_types":["beam_truss"],"preferred_tags":["arch","curved"],"target_extent":[96,52]}],
		"required_empty_regions":[[58,76,40,16]],"anchors":[[32,96,96,4,58]],"relations":[],"expectations":{"intent":"Preserve useful empty space beneath a curved span; all geometry remains an offline tool proposal."}},
		{"id":"development-lattice-bay","cohort":"development","family":"lattice_span","intent":"repeated deep lattice structural span",
		"slots":[{"id":"span","region":[32,32,96,48],"part_types":["beam_truss"],"preferred_tags":["truss","repetition"],"target_extent":[96,32]}],
		"required_empty_regions":[[16,104,224,24]],"anchors":[[32,80,96,4,58]],"relations":[],"expectations":{"intent":"Provide a repeated structural span above a separate lower corridor."}}]

static func source_rectangles(brief: Dictionary) -> Array:
	var rows: Array=[[2,2,4,4,13]]
	rows.append_array(brief.get("anchors",[]).duplicate(true))
	return rows

static func source_plane(brief: Dictionary) -> Dictionary:
	var cells:=PackedByteArray(); cells.resize(EXTENT.x*EXTENT.y*2)
	for raw: Variant in source_rectangles(brief):
		if not raw is Array or raw.size()!=5: return {"ok":false,"reason":"Malformed registered source anchor."}
		for n: Variant in raw:
			if not Module.integer(n): return {"ok":false,"reason":"Source anchor requires integer cells."}
		var area:=Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
		if area.size.x<1 or area.size.y<1 or not Rect2i(Vector2i.ZERO,EXTENT).encloses(area): return {"ok":false,"reason":"Source anchor escaped the registered arena."}
		for y: int in range(area.position.y,area.end.y):
			for x: int in range(area.position.x,area.end.x): cells.encode_u16((y*EXTENT.x+x)*2,int(raw[4]))
	return {"ok":true,"cells":cells,"sha256":Compiler.digest(cells)}

static func query_for(brief: Dictionary) -> Dictionary:
	var reference_query: Dictionary=brief.get("reference_query",{}).duplicate(true)
	reference_query.excluded_families=EXCLUDED.duplicate()
	return {"format":Retrieval.FORMAT,"id":brief.id,"text":brief.intent,"region":[0,0,256,192],"max_native_cells":MAX_NATIVE,
		"search_budget":256,"reference_limit":3,"context_chars":12000,"require_native_geometry":true,"slots":brief.slots.duplicate(true),
		"relations":brief.get("relations",[]).duplicate(true),"protected":[[2,2,4,4]],"reference_query":reference_query}

static func _outline(area: Rect2i) -> Array:
	return [box(area.position.x,area.end.y-4,area.size.x,4),box(area.position.x,area.position.y,4,area.size.y),
		box(area.end.x-4,area.position.y,4,area.size.y),box(area.position.x,area.position.y,area.size.x,4)]

static func _procedural(area: Rect2i,seed_value: int) -> Array:
	var ops: Array=[box(area.position.x,area.position.y,area.size.x,4),box(area.position.x,area.end.y-4,area.size.x,4)]
	for x: int in range(area.position.x,area.end.x,16):
		ops.append(box(x,area.position.y,mini(2,area.end.x-x),area.size.y,28))
		var span:=mini(16,area.end.x-x)
		for step: int in span:
			var relative:=step if posmod((x-area.position.x)/16+seed_value,2)==0 else span-1-step
			var y:=area.position.y+4+relative*maxi(1,area.size.y-10)/maxi(1,span-1)
			ops.append(box(x+step,y,mini(2,area.end.x-x-step),2,28))
	return ops

static func _reference_geometry(area: Rect2i,topologies: Array) -> Array:
	if "open_span" in topologies or "suspended" in topologies:
		var ops: Array=[box(area.position.x,area.end.y-4,area.size.x,4),box(area.position.x,area.position.y,area.size.x,4)]
		for index: int in 4:
			var depth:=maxi(4,(area.size.y-8)*(4-index)/5); var inset:=index*maxi(2,area.size.x/12)
			ops.append(box(area.position.x+inset,area.position.y+4,maxi(2,area.size.x/12),depth))
			ops.append(box(area.end.x-inset-maxi(2,area.size.x/12),area.position.y+4,maxi(2,area.size.x/12),depth))
		return ops
	if "multi_level" in topologies or "vertical_chain" in topologies:
		var ops:=_outline(area)
		ops.append(box(area.position.x,area.position.y+area.size.y/3,area.size.x*2/3,3,28))
		ops.append(box(area.position.x+area.size.x/3,area.position.y+area.size.y*2/3,area.size.x-area.size.x/3,3,28))
		return ops
	var ops:=_outline(area)
	for x: int in range(area.position.x+8,area.end.x-4,24): ops.append(box(x,area.position.y+4,2,area.size.y-8,28))
	return ops

static func _random_parts(brief: Dictionary,library: RefCounted,seed_value: int) -> Dictionary:
	var random:=RandomNumberGenerator.new(); random.seed=seed_value
	var parts: Array=[]
	for slot: Dictionary in brief.slots:
		var area:=Compiler.rect(slot.region); var choices: Array=[]
		for module: Dictionary in library.summaries():
			if not module.native_readback_verified or module.part_type not in slot.part_types: continue
			for transform: String in slot.get("transforms",["identity"]):
				if transform not in module.allowed_transforms: continue
				var size:=Module.transformed_size(Vector2i(int(module.extent[0]),int(module.extent[1])),transform)
				if size.x>area.size.x or size.y>area.size.y: continue
				var origin:=area.position
				if slot.get("align","bottom-left")=="bottom-left": origin.y+=area.size.y-size.y
				elif slot.get("align","bottom-left")=="center": origin+=(area.size-size)/2
				choices.append({"slot_id":slot.id,"module_id":module.id,"module_sha256":module.content_sha256,"placement":{"origin":[origin.x,origin.y],"transform":transform},
					"connectors":Retrieval._posed_connectors(module,origin,transform)})
		choices.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return str(a.module_id)+str(a.placement.transform)<str(b.module_id)+str(b.placement.transform))
		if choices.is_empty(): return {"ok":false,"reason":"Random fitting control has no current native part within slot "+str(slot.id)}
		parts.append(choices[random.randi_range(0,choices.size()-1)])
	return {"ok":true,"placements":parts}

static func build(brief: Dictionary,arm: String,seed_value: int,library: RefCounted) -> Dictionary:
	if arm not in ARMS or not brief.get("slots") is Array or brief.slots.is_empty() or brief.slots.size()>4: return {"ok":false,"reason":"Unregistered arm or spatial brief."}
	var query:=query_for(brief); var valid:=Retrieval.validate_query(query)
	if not valid.ok: return valid
	var source:=source_plane(brief)
	if not source.ok: return source
	var stage:=Compiler.stage_defaults(str(brief.id)+"-"+arm,Rect2i(Vector2i.ZERO,EXTENT))
	stage.intent=brief.intent; stage.materials=[0,7,28,58]; stage.protected=[[2,2,4,4]]
	stage.clearances=brief.get("required_empty_regions",[]).duplicate(true); stage.budget.max_checked_cells=MAX_NATIVE
	var result: Dictionary={"ok":true,"stage":stage,"query":query,"query_sha256":Compiler.digest(Compiler.canonical(query).to_utf8_buffer()),
		"arm":arm,"seed":seed_value,"selected_modules":[],"reference_ids":[],"context_pack":{},"relation_status":"not-applicable-no-authored-module-contract", "model_calls":0}
	if arm in ["retrieval_guided","random_fitting_modules"]:
		var chosen: Dictionary=Retrieval.retrieve(query,library.summaries(),{}, {"region":[0,0,256,192],"cells":source.cells,"source_sha256":source.sha256}) if arm=="retrieval_guided" else _random_parts(brief,library,seed_value)
		if not chosen.ok: return {"ok":false,"reason":str(chosen.get("reason","Composition selection refused.")),"status":str(chosen.get("status","refused")),"query":query,"selection":chosen,"stage":stage}
		result.selected_modules=chosen.placements.duplicate(true); result.context_pack=chosen.get("context_pack",{}).duplicate(true)
		result["search"]=chosen.get("search",{}).duplicate(true)
		for reference: Dictionary in result.context_pack.get("references",[]): result.reference_ids.append(reference.id)
		for item: Dictionary in chosen.placements:
			stage.modules.append({"module_id":item.module_id,"module_sha256":item.module_sha256,"instance_id":item.slot_id,"placement":item.placement.duplicate(true)})
		var bindings: Array=[]; var contacts: Array=[]
		for relation: Dictionary in brief.get("relations",[]):
			var a: Dictionary={}; var b: Dictionary={}
			for item: Dictionary in chosen.placements:
				if item.slot_id==relation.a:a=item
				if item.slot_id==relation.b:b=item
			var joined:=Retrieval._contact(a,b,relation)
			if not joined.ok: return {"ok":false,"reason":"Selected random part assignments lack the registered authored contact relation.","stage":stage,"query":query,"selected_modules":chosen.placements,"status":"no-fit"}
			bindings.append({"a":{"instance":relation.a,"connector":joined.a_connector},"b":{"instance":relation.b,"connector":joined.b_connector}})
			contacts.append(joined)
		stage["module_bindings"]=bindings; result["declared_contacts"]=contacts; result.relation_status="host-compile-required"
	else:
		var topology: Array=[]
		if arm=="reference_guided":
			var reference_query: Dictionary=query.reference_query.duplicate(true); reference_query.text=brief.intent; reference_query.limit=3
			var found:=Design.retrieve(reference_query)
			if not found.ok or found.results.is_empty():return {"ok":false,"reason":"Reference-guided deterministic strategy has no matching frozen knowledge."}
			topology=found.results[0].card.facets.topologies; result.reference_ids=found.results.map(func(row: Dictionary)->String:return row.card.id); result.context_pack=found.context_pack
		for slot: Dictionary in brief.slots:
			var area:=Compiler.rect(slot.region)
			if area.size.x<8 or area.size.y<12:return {"ok":false,"reason":"Registered typed baseline cannot build a safe outline in this very small slot."}
			if arm=="hand_typed":stage.operations.append_array(_outline(area))
			elif arm=="procedural_structure":stage.operations.append_array(_procedural(area,seed_value))
			else:stage.operations.append_array(_reference_geometry(area,topology))
	result.stage=stage
	return result
