extends RefCounted
## Proposal-only collaboration boundary. No provider object, credential, World,
## executor or approval method exists here. An explicit host transport may answer
## transport_requested; ordinary Art finished/auto-apply is never intercepted.
signal changed(summary: Dictionary)
signal proposed(result: Dictionary)
signal transport_requested(request: Dictionary)
signal planning_cancelled(request_id: String)

const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const Recipes = preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const Retrieval = preload("res://scripts/batch_lab/architectural_retrieval.gd")
const Composition = preload("res://scripts/batch_lab/architecture_compositional_retrieval.gd")
const FORMAT := "cybersand-architecture-proposal-v1"
const REQUEST_FORMAT := "cybersand-architecture-proposal-request-v1"
const HISTORY_FORMAT := "cybersand-architecture-planning-history-v1"
const MAX_REQUESTS := 32
const MAX_RESPONSE_BYTES := 4*1024*1024
const MAX_HISTORY_BYTES := 2*1024*1024
const MAX_INTENT_CHARS := 4096
const MAX_MODULES := 256

var _serial := 0
var _lifetime := Crypto.new().generate_random_bytes(12).hex_encode()
var _active: Dictionary = {}
var _result: Dictionary = {}
var _history: Array = []
var _state := "idle"
var _message := "Describe a construction intent, inspect a region, then review a finite proposal."

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"status":"refused","reason":reason,"zero_writes":true}

static func _inspection(value: Dictionary) -> Dictionary:
	if value.get("kind")!="native-inspection-snapshot" or value.get("ok")!=true or value.get("stale")!=false:
		return _fail("A fresh copied host native inspection is required before proposing architecture.")
	var area:=Compiler.rect(value.get("region"))
	if area.position.x<0 or area.position.y<0 or area.size.x<64 or area.size.y<64 or area.size.x>512 or area.size.y>512:
		return _fail("Select an actual 64–512 cell region on each side for this finite intent workflow.")
	if not value.get("cells") is PackedByteArray or value.cells.size()!=area.get_area()*2 or Compiler.digest(value.cells)!=value.get("source_sha256"):
		return _fail("Inspected material bytes must match their complete source identity.")
	if not Campaign._integer(value.get("generation"),0,9223372036854775807) or not Campaign._integer(value.get("captured_revision"),0,9223372036854775807):
		return _fail("Native inspection lacks a bounded World generation and host revision.")
	var occupied:=0
	var materials: Dictionary={}
	for index: int in area.get_area():
		var material: int=value.cells.decode_u16(index*2)
		if material!=0: occupied+=1
		materials[material]=int(materials.get(material,0))+1
	return {"ok":true,"region":value.region.duplicate(),"source_sha256":value.source_sha256,"generation":int(value.generation),
		"captured_revision":int(value.captured_revision),"occupied_cells":occupied,"empty_cells":area.get_area()-occupied,"material_counts":materials,
		"scope":"Copied native material inspection at a recorded instant; model plans confer no permissions or completion."}

static func _intent(value: Dictionary, options: Dictionary) -> Dictionary:
	if not Campaign._text(value.get("text"),MAX_INTENT_CHARS): return _fail("Describe a bounded architectural intent before requesting proposals.")
	if not Campaign._integer(value.get("seed",37901),0,2147483647): return _fail("Seed must be a finite nonnegative integer.")
	if not Campaign._integer(options.get("max_alternatives",3),1,Campaign.MAX_ALTERNATIVES): return _fail("Choose one to three finite alternatives.")
	if options.get("mode","offline") not in ["offline","proposal_transport"]: return _fail("Unknown planning mode; ordinary Art painting is a separate interaction.")
	if not value.get("family","") is String or (not str(value.get("family","")).is_empty() and value.family not in Recipes.FAMILIES): return _fail("Unknown authored architectural family.")
	var materials: Variant=options.get("materials",[58,28])
	if not materials is Array or materials.is_empty() or materials.size()>8: return _fail("Choose a bounded proposed palette.")
	for material: Variant in materials:
		if not Campaign._integer(material,1,65535): return _fail("Proposed structural palette needs integer material identities; the host still decides admission.")
	return {"ok":true,"text":str(value.text).strip_edges(),"seed":int(value.get("seed",37901)),"family":str(value.get("family","")),
		"max_alternatives":int(options.get("max_alternatives",3)),"mode":str(options.get("mode","offline")),"materials":materials.map(func(material: Variant)->int:return int(material))}

func submit_intent(intent: Dictionary, inspection: Dictionary, module_summaries: Array = [], options: Dictionary = {}) -> Dictionary:
	if _serial>=MAX_REQUESTS: return _fail("Planning request budget is exhausted. Preserve this history before starting a new planning session.")
	var checked:=_intent(intent,options)
	if not checked.ok: return checked
	var captured:=_inspection(inspection)
	if not captured.ok: return captured
	if module_summaries.size()>MAX_MODULES: return _fail("Module context exceeds 256 inspected summaries.")
	if not _active.is_empty():
		var previous: String=_active.request_id
		_retire("replaced","Revised intent retires the earlier request; late responses remain historical.")
		planning_cancelled.emit(previous)
	_serial+=1
	var identity:="architecture-"+_lifetime+"-"+str(_serial)
	var inferred:=Recipes.infer_family(checked.text)
	var family: String=checked.family if not checked.family.is_empty() else inferred.family
	var query: Dictionary={"text":checked.text,"limit":3,"context_chars":12000}
	# Existing frozen retrieval stays an explicitly read-only knowledge source.
	# Its own schema rejects unknown fields, so use only its established fields.
	var retrieved:=Retrieval.retrieve(query,module_summaries)
	var context: Dictionary=retrieved.get("context_pack",{}) if retrieved.get("ok",false) else {}
	var composition:=_composition_context(checked,family,captured,inspection,module_summaries)
	if composition.get("ok",false): context=composition.context_pack.duplicate(true)
	_active={"format":REQUEST_FORMAT,"request_id":identity,"intent":checked.text,"seed":checked.seed,"family":family,"mode":checked.mode,
		"max_alternatives":checked.max_alternatives,"materials":checked.materials,"inspection":captured,"context_pack":context,
		"module_summary_sha256":Compiler.digest(Compiler.canonical(module_summaries).to_utf8_buffer()),
		"library_retrieval":{"status":composition.get("status","no-fit"),"reason":composition.get("reason","Current native library part selected for a separately reviewable option.")},
		"scope":"Proposal only. A later exact native preview and owner approval are mandatory for every executable stage."}
	_result={}; _state="planning"; _message="Inspected source is bound to this proposal request; no construction is queued."
	if family.is_empty():
		_state="needs-clarification"
		_result={"ok":true,"format":FORMAT,"request_id":identity,"status":_state,"zero_writes":true,"alternatives":[],
			"questions":[{"id":"family","question":"Which architectural family should organize the selected space?","choices":Recipes.FAMILIES.keys(),"matched_families":inferred.matches}],
			"inspection":captured.duplicate(true),"scope":"Unknown or ambiguous vocabulary was not silently assigned an architectural intent."}
		_message="Choose a family to make the finite proposal concrete."
		changed.emit(summary()); return _result.duplicate(true)
	if checked.mode=="proposal_transport":
		_state="awaiting-proposal"
		changed.emit(summary())
		transport_requested.emit(_active.duplicate(true))
		# An owner seam may synchronously answer, refuse or cancel during emission.
		# A different reentrant request must not be returned as this request's result.
		if _active.is_empty():
			if _result.get("request_id")==identity: return _result.duplicate(true)
			return _fail(_message)
		if _active.get("request_id")!=identity: return _fail("This proposal was replaced during owner dispatch.")
		return {"ok":true,"status":"awaiting-proposal","request_id":identity,"zero_writes":true,"real_model_calls":0,
			"scope":"A proposal-only request was emitted. The injected host transport must separately witness any genuine model call."}
	var alternatives: Array=[]
	for index: int in checked.max_alternatives:
		var built:=Recipes.build(identity+"-"+str(index+1),family,index,Compiler.rect(captured.region),checked.seed,checked.materials)
		if not built.ok: return _finish_refusal(identity,built.reason)
		alternatives.append({"id":"option-"+str(index+1),"title":built.title,"summary":built.summary,"campaign":built.campaign,
			"strategy_source":"offline-deterministic-intent-grammar","real_model_calls":0})
	if composition.get("ok",false):
		var composed:=_composition_alternative(identity,family,checked,captured,composition)
		if composed.get("ok",false): alternatives[alternatives.size()-1]=composed.alternative
	var response: Dictionary={"format":FORMAT,"request_id":identity,"inspection_sha256":captured.source_sha256,"generation":captured.generation,
		"alternatives":alternatives,"uncertainty":["Host compilation may refuse existing material, blocked clearances, connectors, changed source or actual cost.",
			"These deterministic proposals do not establish language-model performance, physics or actor traversal."],"provenance":{"mode":"offline","real_model_calls":0}}
	return accept_response(identity,response)

static func _composition_context(intent: Dictionary,family: String,captured: Dictionary,inspection: Dictionary,summaries: Array) -> Dictionary:
	if family.is_empty(): return {"ok":false,"status":"needs-clarification","reason":"Choose an architectural family before part composition."}
	var vocabulary: Dictionary={"industrial_hangar":["beam_truss","mechanical_housing","service_gallery","window_door"],
		"arcology":["wall_facade","window_door","floor_ceiling"],"viaduct":["viaduct_segment","beam_truss"],
		"biomechanical":["column_support","irregular_transition","pipework"],"service_network":["pipework","mechanical_housing"],
		"organic_cavern":["irregular_transition","wall_facade","beam_truss"]}
	var area:=Compiler.rect(captured.region)
	# An interior region below the roof and above the protected lower passage.
	# Source occupancy is checked now; the later two-stage host preview checks
	# the proposed frame and exact native part together at their execution times.
	var slot:=Rect2i(area.position+Vector2i(8,10),area.size-Vector2i(16,34))
	var terms:=Retrieval._tokens(intent.text);var preferred: Array=[]
	var palette_compatible: Array=[]
	for module: Variant in summaries:
		if not module is Dictionary or not module.get("tags",[]) is Array or not module.get("observed_material_ids",[]) is Array:continue
		if module.get("observed_material_ids",[]).any(func(material: Variant)->bool:return material!=0 and material not in intent.materials):continue
		palette_compatible.append(module)
		for tag: Variant in module.get("tags",[]):
			if tag is String and tag in terms and tag not in preferred and preferred.size()<8:preferred.append(tag)
	var query: Dictionary={"format":Composition.FORMAT,"id":"intent-library-feature","text":intent.text,"region":captured.region.duplicate(),
		"max_native_cells":area.get_area(),"search_budget":256,"reference_limit":3,"context_chars":12000,"require_native_geometry":true,
		"slots":[{"id":"library-feature","region":Compiler.rect_array(slot),"part_types":vocabulary.get(family,[]),"preferred_tags":preferred,"target_extent":[slot.size.x,slot.size.y],"align":"top-left"}]}
	return Composition.retrieve(query,palette_compatible,{},inspection)

static func _composition_alternative(identity: String,family: String,intent: Dictionary,captured: Dictionary,composition: Dictionary) -> Dictionary:
	var built:=Recipes.build(identity+"-library",family,0,Compiler.rect(captured.region),intent.seed,intent.materials)
	if not built.ok:return built
	var campaign: Dictionary=built.campaign
	var selected: Dictionary=composition.placements[0]
	var structural: Dictionary=campaign.nodes[1].duplicate(true)
	var module_stage:=Compiler.stage_defaults("library-feature",Compiler.rect(captured.region))
	module_stage.intent="Place the reference-matched current-session native part beneath the structural roof."
	module_stage.materials=structural.stage.materials.duplicate()
	module_stage.depends_on=["structure"]
	module_stage.clearances=structural.stage.clearances.duplicate(true)
	module_stage.budget.max_checked_cells=Compiler.rect(captured.region).get_area()
	module_stage.modules=[{"module_id":selected.module_id,"module_sha256":selected.module_sha256,"instance_id":"library-feature","placement":selected.placement.duplicate(true)}]
	module_stage.expected_effects="A distinct harvested structural element, revalidated for exact pose, source, native material permission and lower-passage protection before owner approval."
	campaign.title="Native library composition"
	campaign.intent="Combine a finite outside frame with "+str(selected.name)+" selected from current native module observations."
	campaign.nodes=[campaign.nodes[0],structural,{"id":"library-feature","parent_id":"composition","title":"Place "+str(selected.name),"kind":"modules","executor":"compositional-retrieval",
		"region":captured.region.duplicate(),"depends_on":["structure"],"stage":module_stage,"raster_candidates_limit":Compiler.MAX_RASTER_CANDIDATES}]
	campaign.budget.raster_candidates=mini(Campaign.MAX_RASTER_CANDIDATES,int(structural.raster_candidates_limit)+Compiler.MAX_RASTER_CANDIDATES)
	campaign.provenance["kind"]="offline-typed-frame-and-compositional-native-library-selection"
	campaign.provenance["retrieval_query_sha256"]=composition.query_sha256
	campaign.provenance["module_catalog_sha256"]=composition.module_catalog_sha256
	var valid:=Campaign.validate(campaign)
	if not valid.ok:return valid
	return {"ok":true,"alternative":{"id":"option-library","title":"Native library composition","summary":"A continuous outside frame and protected lower passage, with "+str(selected.name)+" selected for the inspected region. Each of the two stages requires its own native preview and approval.","campaign":campaign}}

func revise_intent(intent: Dictionary, inspection: Dictionary, module_summaries: Array = [], options: Dictionary = {}) -> Dictionary:
	return submit_intent(intent,inspection,module_summaries,options)

func _finish_refusal(identity: String, reason: String) -> Dictionary:
	if not _active.is_empty() and _active.request_id==identity: _retire("refused",reason)
	_state="refused"; _message=reason.left(2048); _result={}
	changed.emit(summary())
	return _fail(reason)

func accept_response(identity: String, response: Variant) -> Dictionary:
	if _active.is_empty() or _active.request_id!=identity or _state not in ["planning","awaiting-proposal"]:
		return _fail("Late, duplicate, cancelled or uncorrelated architecture response was not admitted.")
	if response is String:
		if response.to_utf8_buffer().size()>MAX_RESPONSE_BYTES: return _finish_refusal(identity,"Proposal response exceeds four MiB.")
		var parser:=JSON.new()
		if parser.parse(response)!=OK: return _finish_refusal(identity,"Proposal response is not valid JSON at line "+str(parser.get_error_line())+".")
		response=parser.data
	if not response is Dictionary or Compiler.canonical(response).to_utf8_buffer().size()>MAX_RESPONSE_BYTES or response.get("format")!=FORMAT:
		return _finish_refusal(identity,"Proposal response must be one bounded typed architecture object.")
	if response.get("request_id")!=identity or response.get("inspection_sha256")!=_active.inspection.source_sha256 or response.get("generation")!=_active.inspection.generation:
		return _finish_refusal(identity,"Proposal response does not match this exact request and native inspection.")
	if not response.get("alternatives") is Array or response.alternatives.is_empty() or response.alternatives.size()>int(_active.max_alternatives):
		return _finish_refusal(identity,"Proposal must contain one to the requested finite number of alternatives.")
	if not response.get("uncertainty",[]) is Array or response.get("uncertainty",[]).size()>16: return _finish_refusal(identity,"Proposal uncertainty must be a bounded text list.")
	for value: Variant in response.get("uncertainty",[]):
		if not Campaign._text(value,1024): return _finish_refusal(identity,"Proposal uncertainty text is invalid.")
	var alternatives: Array=[]; var identities: Array=[]
	for candidate: Variant in response.alternatives:
		if not candidate is Dictionary or not Campaign._text(candidate.get("id"),128) or candidate.id in identities or not Campaign._text(candidate.get("title"),256) or not Campaign._text(candidate.get("summary"),2048):
			return _finish_refusal(identity,"Alternative identity, title or summary is malformed or duplicated.")
		var checked:=Campaign.validate(candidate.get("campaign"))
		if not checked.ok: return _finish_refusal(identity,checked.reason)
		if Compiler.rect(checked.campaign.region)!=Compiler.rect(_active.inspection.region): return _finish_refusal(identity,"A response cannot expand the host-selected inspected region.")
		for node: Dictionary in checked.campaign.nodes:
			if node.kind=="group": continue
			for material: Variant in node.stage.get("materials",[]):
				if not Campaign._integer(material,0,65535) or (int(material)!=0 and int(material) not in _active.materials): return _finish_refusal(identity,"A response cannot expand the host-proposed material palette.")
		identities.append(candidate.id)
		alternatives.append({"id":candidate.id,"title":candidate.title,"summary":candidate.summary,"campaign":checked.campaign,
			"campaign_sha256":Compiler.digest(Compiler.canonical(checked.campaign).to_utf8_buffer()),"strategy_source":str(_active.mode),
			"native_completion":"not-executed","owner_approval":"required-for-each-stage"})
	_result={"ok":true,"format":FORMAT,"request_id":identity,"status":"proposed","zero_writes":true,"alternatives":alternatives,
		"uncertainty":response.get("uncertainty",[]).duplicate(),"inspection":_active.inspection.duplicate(true),"context_pack":_active.context_pack.duplicate(true),
		"library_retrieval":_active.library_retrieval.duplicate(true),
		"provenance":{"mode":_active.mode,"response_sha256":Compiler.digest(Compiler.canonical(response).to_utf8_buffer()),
			"real_model_calls":0 if _active.mode=="offline" else null,"model_call_scope":"Only an injected host transport's witnessed evidence can qualify a genuine model call."}}
	_retire("proposed","Finite proposals admitted for owner review; no native operation was queued.")
	_state="proposed"; _message="Review an alternative, then compile each stage against current World geometry before approval."
	changed.emit(summary()); proposed.emit(_result.duplicate(true))
	return _result.duplicate(true)

func _retire(status: String, reason: String) -> void:
	if _active.is_empty(): return
	_history.append({"request_id":_active.request_id,"intent":_active.intent,"mode":_active.mode,"inspection":_active.inspection.duplicate(true),
		"status":status,"reason":reason.left(2048),"proposal_sha256":Compiler.digest(Compiler.canonical(_result).to_utf8_buffer()) if not _result.is_empty() else ""})
	_active={}

func cancel_planning() -> Dictionary:
	var identity: String=_active.get("request_id","")
	_retire("cancelled","Owner cancelled this planning request; no late response can become current.")
	_result={}; _state="cancelled"; _message="Planning cancelled. No native writes were requested by this adapter."
	if not identity.is_empty(): planning_cancelled.emit(identity)
	changed.emit(summary())
	return {"ok":true,"request_id":identity,"zero_writes":true}

func result() -> Dictionary:
	return _result.duplicate(true)

func alternative(identity: String) -> Dictionary:
	for value: Dictionary in _result.get("alternatives",[]):
		if value.id==identity: return value.duplicate(true)
	return {}

func summary() -> Dictionary:
	var alternatives: Array=[]
	for value: Dictionary in _result.get("alternatives",[]):
		alternatives.append({"id":value.id,"title":value.title,"summary":value.summary,"campaign_sha256":value.campaign_sha256,
			"job_count":value.campaign.nodes.filter(func(node: Dictionary) -> bool: return node.kind!="group").size(),"state":"proposed"})
	return {"state":_state,"message":_message,"request_id":_active.get("request_id",_result.get("request_id","")),
		"mode":_active.get("mode",_result.get("provenance",{}).get("mode","offline")),"alternatives":alternatives,
		"questions":_result.get("questions",[]).duplicate(true),"requests_used":_serial,"requests_limit":MAX_REQUESTS,
		"library_retrieval":_active.get("library_retrieval",_result.get("library_retrieval",{})).duplicate(true),
		"history_count":_history.size(),"zero_writes":true,"scope":"Planning and proposal status only; never a native completion record."}

func export_history() -> Dictionary:
	return {"format":HISTORY_FORMAT,"requests":_history.duplicate(true),"scope":"Historical planning identities only. No transport request, proposal selection, approval or native work resumes on reopen."}

func open_history(value: Variant) -> Dictionary:
	if not _active.is_empty(): return _fail("Cancel the current planning request before reopening historical records.")
	if not value is Dictionary or value.get("format")!=HISTORY_FORMAT or Compiler.canonical(value).to_utf8_buffer().size()>MAX_HISTORY_BYTES or not value.get("requests") is Array or value.requests.size()>MAX_REQUESTS:
		return _fail("Unsupported or oversized planning history.")
	_history=value.requests.duplicate(true); _serial=_history.size(); _result={}; _state="historical"; _message="Historical planning records loaded; no request or approval resumed."
	_lifetime=Crypto.new().generate_random_bytes(12).hex_encode()
	changed.emit(summary())
	return {"ok":true,"historical_only":true,"zero_writes":true}
