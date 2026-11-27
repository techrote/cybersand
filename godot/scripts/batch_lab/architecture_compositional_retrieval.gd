extends RefCounted
## Finite reference + part composition retrieval. Results are bounded typed
## placement proposals; only StagePlan/StageSession can qualify actual placement.
const Design = preload("res://scripts/batch_lab/architectural_retrieval.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const FORMAT := "cybersand-compositional-query-v1"
const RESULT_FORMAT := "cybersand-compositional-retrieval-v1"
const MAX_SLOTS := 8
const MAX_MODULES := 256
const MAX_CANDIDATES_PER_SLOT := 12
const MAX_SEARCH := 2048
const MAX_CONTEXT_CHARS := 12000

static func _fail(reason: String, status := "refused", diagnostics: Array = []) -> Dictionary:
	return {"ok":false,"status":status,"reason":reason,"diagnostics":diagnostics,"zero_writes":true,"placements":[],"context_pack":{},"context_text":""}

static func _texts(value: Variant, maximum := 32) -> bool:
	return Campaign._strings(value,maximum)

static func _extent(value: Variant) -> bool:
	return value is Array and value.size()==2 and Campaign._integer(value[0],1,512) and Campaign._integer(value[1],1,512)

static func validate_query(query: Dictionary) -> Dictionary:
	if query.get("format")!=FORMAT or Compiler.canonical(query).to_utf8_buffer().size()>65536: return _fail("Unsupported or oversized compositional retrieval query.")
	if not Campaign._text(query.get("id"),128) or not Campaign._text(query.get("text"),4096): return _fail("Composition needs a bounded identity and explicit structural intent.")
	var region:=Compiler.rect(query.get("region"))
	if region.position.x<0 or region.position.y<0 or region.size.x<1 or region.size.y<1 or region.size.x>512 or region.size.y>512: return _fail("Composition retrieval covers one bounded native stage region.")
	if not query.get("slots") is Array or query.slots.is_empty() or query.slots.size()>MAX_SLOTS: return _fail("Choose one to eight explicit spatial part slots.")
	if not Campaign._integer(query.get("max_native_cells"),1,Compiler.MAX_CHECKED_CELLS) or not Campaign._integer(query.get("search_budget",256),1,MAX_SEARCH): return _fail("Composition requires finite native and search budgets.")
	if not Campaign._integer(query.get("reference_limit",3),1,5) or not Campaign._integer(query.get("context_chars",12000),1500,MAX_CONTEXT_CHARS): return _fail("Use one to five references in a bounded context pack.")
	if not query.get("require_native_geometry",true) is bool or not query.get("allow_repeat",true) is bool: return _fail("Native qualification and repeated-part choices must be explicit booleans.")
	if not query.get("reference_query",{}) is Dictionary: return _fail("Reference facets must be a query object.")
	for field: String in ["protected","clearances"]:
		if not query.get(field,[]) is Array or query.get(field,[]).size()>64: return _fail("Composition protection and negative-space lists must be bounded.")
		for raw: Variant in query.get(field,[]):
			var guard:=Compiler.rect(raw)
			if guard.size.x<1 or guard.size.y<1 or not region.encloses(guard): return _fail("A protected or clearance rectangle escapes the inspected composition.")
	var ids: Array=[]
	for slot: Variant in query.slots:
		if not slot is Dictionary or not Campaign._text(slot.get("id"),128) or slot.id in ids: return _fail("Spatial slots need unique bounded identities.")
		ids.append(slot.id)
		var bounds:=Compiler.rect(slot.get("region"))
		if bounds.size.x<1 or bounds.size.y<1 or not region.encloses(bounds): return _fail("Part slot escapes the inspected composition region.")
		if not _texts(slot.get("part_types")) or slot.part_types.is_empty(): return _fail("Each slot needs supported structural part types.")
		for kind: String in slot.part_types:
			if kind not in Module.PART_TYPES: return _fail("Unknown structural vocabulary: "+kind)
		for field: String in ["required_tags","preferred_tags","material_roles","connection_types","excluded_ids"]:
			if not _texts(slot.get(field,[])): return _fail("Malformed bounded slot facet: "+field)
		if not _extent(slot.get("target_extent",[bounds.size.x,bounds.size.y])) or not _extent(slot.get("minimum_extent",[1,1])): return _fail("Slot scale targets must fit bounded extents.")
		if slot.get("align","bottom-left") not in ["top-left","bottom-left","center"]: return _fail("Unknown finite slot alignment.")
		if not slot.get("transforms",["identity"]) is Array or slot.get("transforms",["identity"]).is_empty() or slot.get("transforms",[]).size()>6: return _fail("Slot transformation list is invalid.")
		for transform: Variant in slot.get("transforms",["identity"]):
			if transform not in Module.TRANSFORMS: return _fail("Unsupported part transform.")
		if slot.get("connector_contract","") not in ["","legacy-point-v1","face-adjacent-grid-v2"]: return _fail("Unknown versioned connector contract.")
	if not query.get("relations",[]) is Array or query.get("relations",[]).size()>16: return _fail("Composition relation list is invalid.")
	for relation: Variant in query.get("relations",[]):
		if not relation is Dictionary or relation.get("kind")!="face-contact" or relation.get("a") not in ids or relation.get("b") not in ids or relation.a==relation.b:
			return _fail("A declared contact must name two distinct slots.")
		if not Campaign._text(relation.get("role"),64) or not Campaign._text(relation.get("compatibility"),64): return _fail("Contact relation needs an authored functional role and compatibility tag.")
	return {"ok":true}

static func _summary_valid(value: Variant) -> bool:
	if not value is Dictionary or not Campaign._text(value.get("id"),128) or not Campaign._text(value.get("name",value.get("id")),256) or not _extent(value.get("extent")) or not Campaign._hash(value.get("content_sha256")): return false
	if value.get("part_type") not in Module.PART_TYPES: return false
	for field: String in ["tags","material_roles","connection_types","allowed_transforms"]:
		if not _texts(value.get(field,[]),128): return false
	var connectors: Variant=value.get("connectors",value.get("attachments",[]))
	if not connectors is Array or connectors.size()>128 or not value.get("native_readback_verified",false) is bool: return false
	for item: Variant in connectors:
		if not item is Dictionary or not Campaign._text(item.get("id"),128) or not Module._pair(item.get("point")) or not Module._pair(item.get("facing")) or not _texts(item.get("compatibility"),16): return false
		if item.get("kind") not in ["vertex","socket","receptor","line"] or item.get("source") not in ["authored","inferred"]: return false
		if item.kind=="line" and not Module._pair(item.get("end")): return false
		if item.has("contact") and (not item.contact is Dictionary or item.contact.get("policy") not in ["full","overlap"] or not Campaign._integer(item.contact.get("minimum_cells"),1,512)): return false
		if item.has("capacity") and not Campaign._integer(item.capacity,1,16): return false
		if item.has("role") and not Campaign._text(item.role,128): return false
	return true

static func _tokens(text: String) -> Array:
	return Design._tokens(text)

static func _contains(available: Array, required: Array) -> bool:
	return required.all(func(value: Variant) -> bool: return value in available)

static func _posed_connectors(module: Dictionary, origin: Vector2i, transform: String) -> Array:
	var output: Array=[]
	var extent:=Vector2i(int(module.extent[0]),int(module.extent[1]))
	for item: Variant in module.get("connectors",module.get("attachments",[])):
		if not item is Dictionary or not Module._pair(item.get("point")) or not Module._pair(item.get("facing")) or not item.get("compatibility") is Array: continue
		if item.get("kind") not in ["vertex","socket","receptor","line"]: continue
		if item.kind=="line" and not Module._pair(item.get("end")): continue
		var first:=origin+Module.transform_point(Vector2i(int(item.point[0]),int(item.point[1])),extent,transform)
		var last:=origin+Module.transform_point(Vector2i(int(item.get("end",item.point)[0]),int(item.get("end",item.point)[1])),extent,transform)
		if first.x!=last.x and first.y!=last.y: continue
		if absi(last.x-first.x)+absi(last.y-first.y)>=512: continue
		var facing:=Module.transform_direction(Vector2i(int(item.facing[0]),int(item.facing[1])),transform)
		if absi(facing.x)+absi(facing.y)!=1: continue
		output.append({"id":str(item.get("id","")),"kind":item.kind,"point":[first.x,first.y],"end":[last.x,last.y],"facing":[facing.x,facing.y],
			"role":str(item.get("role","")),"compatibility":item.compatibility.duplicate(),"polarity":str(item.get("polarity","neutral")),
			"contact":item.get("contact",{}).duplicate(true),"capacity":int(item.get("capacity",1)),"source":item.get("source","unknown"),
			"contract":module.get("connector_contract","legacy-point-v1")})
	return output

static func _prefix(inspection: Dictionary, region: Rect2i) -> Dictionary:
	if inspection.is_empty(): return {"ok":true,"present":false}
	if inspection.get("stale",false) or Compiler.rect(inspection.get("region"))!=region or not inspection.get("cells") is PackedByteArray or inspection.cells.size()!=region.get_area()*2 or Compiler.digest(inspection.cells)!=inspection.get("source_sha256"):
		return _fail("Composition inspection is stale, malformed or bound to another native region.")
	var stride:=region.size.x+1; var sums:=PackedInt32Array(); sums.resize(stride*(region.size.y+1))
	for y: int in region.size.y:
		var row:=0
		for x: int in region.size.x:
			if inspection.cells.decode_u16((y*region.size.x+x)*2)!=0: row+=1
			sums[(y+1)*stride+x+1]=sums[y*stride+x+1]+row
	return {"ok":true,"present":true,"values":sums,"stride":stride,"origin":region.position,"source_sha256":inspection.source_sha256}

static func _box_empty(area: Rect2i, prefix: Dictionary) -> bool:
	if not prefix.present: return true
	var start:=area.position-Vector2i(prefix.origin); var end:=start+area.size; var stride: int=prefix.stride
	return int(prefix.values[end.y*stride+end.x])-int(prefix.values[start.y*stride+end.x])-int(prefix.values[end.y*stride+start.x])+int(prefix.values[start.y*stride+start.x])==0

static func _candidate(module: Dictionary, slot: Dictionary, query: Dictionary, reference_parts: Array, prefix: Dictionary) -> Dictionary:
	if module.id in slot.get("excluded_ids",[]): return _fail("excluded-id")
	if module.part_type not in slot.part_types: return _fail("structural-type")
	if query.get("require_native_geometry",true) and not module.get("native_readback_verified",false): return _fail("no-current-native-observation")
	if not _contains(module.get("tags",[]),slot.get("required_tags",[])): return _fail("required-tag")
	if not _contains(module.get("material_roles",[]),slot.get("material_roles",[])): return _fail("material-role")
	if not _contains(module.get("connection_types",[]),slot.get("connection_types",[])): return _fail("connector-compatibility")
	if not str(slot.get("connector_contract","")).is_empty() and slot.connector_contract!=module.get("connector_contract","legacy-point-v1"): return _fail("connector-version")
	var box:=Compiler.rect(slot.region); var target: Array=slot.get("target_extent",[box.size.x,box.size.y]); var minimum: Array=slot.get("minimum_extent",[1,1])
	var poses: Array=[]
	for transform: String in slot.get("transforms",["identity"]):
		if transform not in module.get("allowed_transforms",["identity"]): continue
		var size:=Module.transformed_size(Vector2i(int(module.extent[0]),int(module.extent[1])),transform)
		if size.x>box.size.x or size.y>box.size.y or size.x<int(minimum[0]) or size.y<int(minimum[1]): continue
		var origin:=box.position
		if slot.get("align","bottom-left")=="bottom-left": origin.y+=box.size.y-size.y
		elif slot.get("align","bottom-left")=="center": origin+=(box.size-size)/2
		var footprint:=Rect2i(origin,size)
		if not _box_empty(footprint,prefix): continue
		var guarded:=false
		for raw: Array in query.get("protected",[])+query.get("clearances",[]):
			if footprint.intersects(Compiler.rect(raw)): guarded=true; break
		if guarded: continue
		var score:=8.0-float(slot.part_types.find(module.part_type))
		var reasons: Array=[{"criterion":"structural-intent","value":module.part_type},{"criterion":"bounded-scale-fit","extent":[size.x,size.y]}]
		for tag: String in slot.get("preferred_tags",[]):
			if tag in module.get("tags",[]): score+=4.0; reasons.append({"criterion":"preferred-motif","value":tag})
		var terms:=_tokens(str(query.text)); var searchable:=_tokens(str(module.name)+" "+" ".join(module.get("tags",[])))
		for term: String in terms:
			if term in searchable: score+=0.5
		if module.part_type in reference_parts: score+=1.5; reasons.append({"criterion":"reference-strategy-part","value":module.part_type,"authority":"curated-interpretation"})
		score+=6.0*(1.0-float(absi(size.x-int(target[0]))+absi(size.y-int(target[1])))/float(int(target[0])+int(target[1])+size.x+size.y))
		poses.append({"slot_id":slot.id,"module_id":module.id,"name":module.name,"part_type":module.part_type,"module_sha256":module.content_sha256,
			"placement":{"origin":[origin.x,origin.y],"transform":transform},"footprint":Compiler.rect_array(footprint),"score":score,"reasons":reasons,
			"native_upper_bound":size.x*size.y,"native_readback_verified":module.get("native_readback_verified",false),
			"connectors":_posed_connectors(module,origin,transform),"geometry_sha256":module.get("geometry_sha256",""),
			"scope":"Current library observation qualifies original geometry only. Proposed pose/contact still needs host native compilation."})
	if poses.is_empty(): return _fail("scale-transform-or-occupied-space")
	return {"ok":true,"poses":poses}

static func _points(connector: Dictionary) -> Array:
	var first:=Vector2i(int(connector.point[0]),int(connector.point[1])); var last:=Vector2i(int(connector.end[0]),int(connector.end[1]))
	var step:=Vector2i(signi(last.x-first.x),signi(last.y-first.y)); var output: Array=[]
	for index: int in absi(last.x-first.x)+absi(last.y-first.y)+1: output.append(first+step*index)
	return output

static func _contact(a: Dictionary, b: Dictionary, relation: Dictionary) -> Dictionary:
	for first: Dictionary in a.connectors:
		for second: Dictionary in b.connectors:
			if first.contract!="face-adjacent-grid-v2" or second.contract!=first.contract or first.source!="authored" or second.source!="authored": continue
			if (first.kind=="line")!=(second.kind=="line"): continue
			if first.role!=relation.role or second.role!=relation.role or relation.compatibility not in first.compatibility or relation.compatibility not in second.compatibility: continue
			if Vector2i(int(first.facing[0]),int(first.facing[1]))!=-Vector2i(int(second.facing[0]),int(second.facing[1])): continue
			if first.polarity=="neutral" and second.polarity!="neutral" or first.polarity!="neutral" and second.polarity!=("receptor" if first.polarity=="socket" else "socket"): continue
			var aa:=_points(first); var bb:=_points(second); var overlap:=0; var a_cells: Array=[]; var b_cells: Array=[]
			var direction:=Vector2i(int(first.facing[0]),int(first.facing[1]))
			for point: Vector2i in aa:
				if point+direction in bb: overlap+=1; a_cells.append([point.x,point.y]); b_cells.append([point.x+direction.x,point.y+direction.y])
			if overlap<maxi(int(first.contact.get("minimum_cells",1)),int(second.contact.get("minimum_cells",1))): continue
			if (first.contact.get("policy")=="full" or second.contact.get("policy")=="full") and (overlap!=aa.size() or overlap!=bb.size()): continue
			return {"ok":true,"a_slot":a.slot_id,"a_connector":first.id,"b_slot":b.slot_id,"b_connector":second.id,"declared_adjacent_cells":overlap,
				"a_capacity":first.capacity,"b_capacity":second.capacity,"a_cells":a_cells,"b_cells":b_cells,
				"scope":"Declared compatible grid-face candidate; authoritative occupied contacts and receptor capacity must be rechecked by StagePlan."}
	return {"ok":false}

static func _relations_fit(chosen: Array, relations: Array) -> bool:
	var by_slot: Dictionary={}; var reservations: Dictionary={}
	for candidate: Dictionary in chosen: by_slot[candidate.slot_id]=candidate
	for relation: Dictionary in relations:
		if not by_slot.has(relation.a) or not by_slot.has(relation.b): continue
		var joined:=_contact(by_slot[relation.a],by_slot[relation.b],relation)
		if not joined.ok: return false
		for side: String in ["a","b"]:
			var key: String=Compiler.canonical([joined[side+"_slot"],joined[side+"_connector"]])
			var existing: Dictionary=reservations.get(key,{"partners":0,"cells":[]})
			if int(existing.partners)>=int(joined[side+"_capacity"]): return false
			for point: Array in joined[side+"_cells"]:
				if point in existing.cells: return false
				existing.cells.append(point)
			existing.partners+=1; reservations[key]=existing
	return true

static func _search(at: int, slots: Array, candidates: Dictionary, relations: Array, chosen: Array, spent: int, score: float, query: Dictionary, search: Dictionary) -> void:
	if search.considered>=int(query.get("search_budget",256)): search.exhausted=true; return
	if at==slots.size():
		search.complete+=1
		if score>float(search.best_score): search.best=chosen.duplicate(true); search.best_score=score
		return
	var identity: String=slots[at].id
	for candidate: Dictionary in candidates[identity]:
		if search.considered>=int(query.get("search_budget",256)): search.exhausted=true; return
		search.considered+=1
		if spent+int(candidate.native_upper_bound)>int(query.max_native_cells): continue
		var valid:=true
		for prior: Dictionary in chosen:
			if Compiler.rect(prior.footprint).intersects(Compiler.rect(candidate.footprint)): valid=false; break
			if not query.get("allow_repeat",true) and prior.module_id==candidate.module_id: valid=false; break
			for relation: Dictionary in relations:
				if relation.a==prior.slot_id and relation.b==candidate.slot_id and not _contact(prior,candidate,relation).ok: valid=false; break
				if relation.b==prior.slot_id and relation.a==candidate.slot_id and not _contact(candidate,prior,relation).ok: valid=false; break
			if not valid: break
		if not valid: continue
		chosen.append(candidate)
		if _relations_fit(chosen,relations): _search(at+1,slots,candidates,relations,chosen,spent+int(candidate.native_upper_bound),score+float(candidate.score),query,search)
		chosen.pop_back()

static func retrieve(query: Dictionary, module_catalog: Array, corpus: Dictionary = {}, inspection: Dictionary = {}) -> Dictionary:
	var valid:=validate_query(query)
	if not valid.ok: return valid
	if module_catalog.size()>MAX_MODULES or Compiler.canonical(module_catalog).to_utf8_buffer().size()>2*1024*1024: return _fail("Module catalogue exceeds the bounded composition context.")
	var prefix:=_prefix(inspection,Compiler.rect(query.region))
	if not prefix.ok: return prefix
	var reference_query: Dictionary=query.get("reference_query",{}).duplicate(true)
	reference_query.text=str(query.text); reference_query.limit=int(query.get("reference_limit",3)); reference_query.context_chars=12000
	var references:=Design.retrieve(reference_query,[],corpus)
	if not references.ok: return _fail("Reference retrieval refused its source-bound corpus or query.","refused",references.get("errors",[]))
	var reference_parts: Array=[]
	for row: Dictionary in references.results:
		for kind: String in row.card.facets.parts:
			if kind not in reference_parts: reference_parts.append(kind)
	var candidates: Dictionary={}; var diagnostics: Array=[]; var summaries: Array=[]; var ids: Array=[]
	for module: Variant in module_catalog:
		if not _summary_valid(module) or module.id in ids: return _fail("Malformed or duplicated module summary; imported flags never authorize geometry.")
		ids.append(module.id); summaries.append(module)
	for slot: Dictionary in query.slots:
		var choices: Array=[]; var rejected: Dictionary={}
		for module: Dictionary in summaries:
			var option:=_candidate(module,slot,query,reference_parts,prefix)
			if option.ok: choices.append_array(option.poses)
			else: rejected[option.reason]=int(rejected.get(option.reason,0))+1
		choices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if not is_equal_approx(float(a.score),float(b.score)): return float(a.score)>float(b.score)
			if a.module_id!=b.module_id: return str(a.module_id)<str(b.module_id)
			return str(a.placement.transform)<str(b.placement.transform))
		candidates[slot.id]=choices.slice(0,MAX_CANDIDATES_PER_SLOT)
		diagnostics.append({"slot_id":slot.id,"candidate_count":choices.size(),"searched_candidate_count":candidates[slot.id].size(),"rejected":rejected,"omitted_candidates":maxi(0,choices.size()-MAX_CANDIDATES_PER_SLOT)})
		if choices.is_empty(): return _fail("No compatible part fits slot "+str(slot.id)+".","no-fit",diagnostics)
	var search: Dictionary={"considered":0,"complete":0,"best":[],"best_score":-INF,"exhausted":false}
	_search(0,query.slots,candidates,query.get("relations",[]),[],0,0.0,query,search)
	if search.best.is_empty(): return _fail("Finite composition search found no jointly fitting, connected, budget-admissible assignment.","exhausted" if search.exhausted else "no-fit",diagnostics)
	var contacts: Array=[]
	for relation: Dictionary in query.get("relations",[]):
		var a: Dictionary={}; var b: Dictionary={}
		for placement: Dictionary in search.best:
			if placement.slot_id==relation.a: a=placement
			if placement.slot_id==relation.b: b=placement
		contacts.append(_contact(a,b,relation))
	var compact_refs: Array=[]
	for row: Dictionary in references.results:
		var card: Dictionary=row.card
		compact_refs.append({"id":card.id,"name":card.name,"architectural_family":card.architectural_family,"ancestry_group":card.ancestry_group,"source":card.source.duplicate(true),
			"observed":{"extent":card.observed.extent,"empty_fraction":card.observed.empty_fraction},
			"interpreted":{"macro":str(card.interpreted.macro_composition).left(320),"supports":str(card.interpreted.support_relationships).left(240),"negative_space":str(card.interpreted.negative_space_and_protection).left(240)},
			"qualification":card.qualification.duplicate(true),"native_module_import":"NOT_ADMITTED_BY_RETRIEVAL"})
	var compact_parts: Array=[]
	for item: Dictionary in search.best:
		compact_parts.append({"slot_id":item.slot_id,"module_id":item.module_id,"module_sha256":item.module_sha256,"geometry_sha256":item.geometry_sha256,"part_type":item.part_type,
			"placement":item.placement.duplicate(true),"native_upper_bound":item.native_upper_bound,"native_readback_verified":item.native_readback_verified,"reason":item.reasons})
	var pack: Dictionary={"format":RESULT_FORMAT,"query_id":query.id,"authority":"REFERENCE_AND_PLACEMENT_PROPOSALS_ONLY","corpus_file_sha256":references.frozen_file_sha256,
		"references":compact_refs,"parts":compact_parts,"contacts":contacts,"omitted_reference_ids":[],
		"claim_limits":["Observed reference facts, architectural interpretation, current native module observation and owner acceptance remain separate.",
			"A proposed pose has no native completion, write permission, physical support or actor-traversal authority."]}
	var maximum:=int(query.get("context_chars",12000))
	while Compiler.canonical(pack).length()>maximum and pack.references.size()>1:
		pack.omitted_reference_ids.push_front(pack.references.pop_back().id)
	if Compiler.canonical(pack).length()>maximum: return _fail("The selected composition and minimum useful reference do not fit the requested context budget.","context-no-fit",diagnostics)
	return {"ok":true,"format":RESULT_FORMAT,"status":"selected","zero_writes":true,"query_sha256":Compiler.digest(Compiler.canonical(query).to_utf8_buffer()),
		"source_sha256":prefix.get("source_sha256",""),"module_catalog_sha256":Compiler.digest(Compiler.canonical(module_catalog).to_utf8_buffer()),
		"placements":search.best,"contacts":contacts,"context_pack":pack,"context_text":Compiler.canonical(pack),"diagnostics":diagnostics,
		"search":{"considered":search.considered,"complete_assignments":search.complete,"exhausted":search.exhausted,"budget":int(query.get("search_budget",256)),"optimality":"Best evaluated bounded candidate assignment; not an exhaustive global design optimum."},
		"qualification":"Native placement remains unexecuted; current library observation is not source-artwork admission or owner acceptance."}
