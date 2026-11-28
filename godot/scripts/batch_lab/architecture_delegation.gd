extends RefCounted
## A finite task descriptor for the code-owned procedural worker registry.
## Serialized prepared metadata is structural provenance, never approval or
## current-source authority. The live host must prepare, preview and approve.
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Jobs=preload("res://scripts/batch_lab/native_detail_jobs.gd")
const FORMAT:="cybersand-architecture-delegation-v1"
const MAX_BYTES:=65536
const GUARD_FIELDS:=["protected","clearances","connections"]

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"status":"refused","reason":reason,"zero_writes":true,"model_calls":0}

static func _integer(value: Variant,low: int,high: int) -> bool:
	return Module.integer(value) and int(value)>=low and int(value)<=high

static func _array_contains(values: Array,needed: Array) -> bool:
	for item: Variant in needed:
		var encoded:=Compiler.canonical(item)
		if not values.any(func(candidate: Variant)->bool:return Compiler.canonical(candidate)==encoded):return false
	return true

static func _merge(values: Array,additional: Array) -> Array:
	var result:=values.duplicate(true)
	for item: Variant in additional:
		if not _array_contains(result,[item]):result.append(item.duplicate(true) if item is Array or item is Dictionary else item)
	return result

static func _contract(stage: Dictionary) -> Dictionary:
	return {"region":stage.get("region",[]).duplicate(),"materials":stage.get("materials",[]).duplicate(),
		"max_checked_cells":stage.get("budget",{}).get("max_checked_cells",0),
		"protected":stage.get("protected",[]).duplicate(true),"clearances":stage.get("clearances",[]).duplicate(true),
		"connections":stage.get("connections",[]).duplicate(true)}

static func declare(stage: Dictionary,job_kind: String,params: Dictionary,instance_id: String="") -> Dictionary:
	if not stage.get("region") is Array or not stage.get("materials") is Array or not stage.get("budget") is Dictionary:
		return _fail("Delegation declaration needs a structurally valid native stage contract.")
	for field: String in GUARD_FIELDS:
		if not stage.get(field,[]) is Array:return _fail("Delegation stage guard fields must be arrays.")
	var descriptor:={"format":FORMAT,"worker":"procedural","job_kind":job_kind,"params":params.duplicate(true),
		"instance_id":instance_id,"contract":_contract(stage)}
	var checked:=validate({"id":stage.get("id",""),"kind":"detail","region":stage.get("region",[]),"stage":stage,"delegation":descriptor})
	if not checked.ok:return checked
	return {"ok":true,"delegation":descriptor,"descriptor_sha256":checked.descriptor_sha256,"zero_writes":true}

static func validate(node: Dictionary) -> Dictionary:
	if not node.get("stage") is Dictionary or not node.get("delegation") is Dictionary:return _fail("Delegation needs a native stage and typed worker descriptor.")
	var stage: Dictionary=node.stage;var value: Dictionary=node.delegation
	if Compiler.canonical(stage).to_utf8_buffer().size()>Compiler.MAX_INPUT_BYTES:return _fail("Delegated stage exceeds the existing native input bound.")
	if not Module._text(stage.get("intent"),8192):return _fail("Delegated stage requires bounded architectural intent.")
	for field: String in ["depends_on","uncertainty","refusal_conditions"]:
		var values: Variant=stage.get(field,[])
		if not values is Array or values.size()>128:return _fail("Delegated stage text arrays exceed their bounded shape.")
		for item: Variant in values:
			if not Module._text(item,2048):return _fail("Delegated stage dependencies and caveats must be bounded strings.")
	if Compiler.canonical(value).to_utf8_buffer().size()>MAX_BYTES:return _fail("Delegation descriptor exceeds its 64 KiB bound.")
	if not Module._keys(value,["format","worker","job_kind","params","contract"],["instance_id"]) \
		or value.format!=FORMAT or value.worker!="procedural" or value.job_kind not in Jobs.KINDS:
		return _fail("Only the versioned code-owned procedural registry may execute delegated work.")
	if not Module.identifier(node.get("id")) or stage.get("id")!=node.id or node.get("kind")=="group":return _fail("A delegated leaf must retain its native stage identity.")
	var instance: Variant=value.get("instance_id","")
	if not instance is String or instance.length()>128 or (not instance.is_empty() and not Module.identifier(instance)):return _fail("Selected native instance identity is malformed.")
	var contract: Variant=value.contract
	if not contract is Dictionary or not Module._keys(contract,["region","materials","max_checked_cells","protected","clearances","connections"],[]):
		return _fail("Delegation must retain its original stage ceilings and protected contract.")
	var region:=Compiler.rect(contract.region)
	if region.position.x<0 or region.position.y<0 or region.size.x<1 or region.size.y<1 or region.size.x>512 or region.size.y>512 \
		or region.end.x>4096 or region.end.y>4096 or Compiler.rect(stage.get("region"))!=region or Compiler.rect(node.get("region"))!=region:
		return _fail("Delegation cannot widen or move its declared inspected stage region.")
	if not contract.materials is Array or contract.materials.is_empty() or contract.materials.size()>256 \
		or not stage.get("materials") is Array or stage.materials.is_empty() or not _array_contains(contract.materials,stage.materials):
		return _fail("Delegation cannot widen its explicit material permissions.")
	for material: Variant in contract.materials:
		if not _integer(material,0,65535):return _fail("Delegation material identities must be uint16 integers.")
	if not _integer(contract.max_checked_cells,1,Compiler.MAX_CHECKED_CELLS) or not stage.get("budget") is Dictionary \
		or not _integer(stage.budget.get("max_checked_cells"),1,int(contract.max_checked_cells)):
		return _fail("Delegation cannot increase the declared native resource ceiling.")
	for field: String in GUARD_FIELDS:
		var guard_limit:=64 if field=="protected" else 128
		if not contract[field] is Array or contract[field].size()>guard_limit or not stage.get(field,[]) is Array \
			or stage.get(field,[]).size()>guard_limit or not _array_contains(stage.get(field,[]),contract[field]):
			return _fail("Delegation cannot remove an original protected, clearance or connection requirement.")
		if field!="connections":
			for raw: Variant in contract[field]:
				var guarded:=Compiler.rect(raw)
				if not guarded.has_area() or not region.encloses(guarded):return _fail("Delegated original guards require complete inspected source coverage.")
	var params: Variant=value.params
	if not params is Dictionary or not Module._keys(params,["region","material","seed","max_cells"],Jobs.FIELDS[value.job_kind]):
		return _fail("Worker parameters must explicitly declare region, material, seed and cell limit without executable extras.")
	var job_area:=Compiler.rect(params.region)
	if job_area.size.x<1 or job_area.size.y<1 or job_area.size.x>Jobs.MAX_SIDE or job_area.size.y>Jobs.MAX_SIDE or not region.encloses(job_area):
		return _fail("Delegated local work must fit 128 cells per side inside its inspected stage.")
	if not Module.integer(params.seed) or not _integer(params.max_cells,1,mini(Jobs.MAX_CELLS,int(stage.budget.max_checked_cells))) \
		or not _integer(params.material,0,65535) or params.material not in stage.materials:
		return _fail("Delegated worker parameters exceed stage material or native ceilings.")
	if (value.job_kind=="edge_wear" and (params.material!=0 or instance.is_empty())) or (value.job_kind!="edge_wear" and params.material==0):
		return _fail("Wear requires Empty material and a selected live native instance; additive workers require non-Empty material.")
	for control: Dictionary in Jobs._controls(value.job_kind):
		if not params.has(control.key):continue
		var supplied: Variant=params[control.key]
		match control.type:
			"choice":
				if supplied not in control.options:return _fail("Delegated worker choice is outside the typed registry: "+str(control.key))
			"integer":
				if not _integer(supplied,int(control.min),int(control.max)):return _fail("Delegated worker integer is outside its finite range: "+str(control.key))
			"number":
				if not (supplied is int or supplied is float) or not is_finite(float(supplied)) or float(supplied)<float(control.min) or float(supplied)>float(control.max):return _fail("Delegated worker number is outside its finite range.")
			"cell-path":
				if not supplied is Array or supplied.size()<2 or supplied.size()>8:return _fail("Delegated pipe route requires 2–8 explicit cells.")
				for point: Variant in supplied:
					if not Module._pair(point) or not job_area.has_point(Vector2i(int(point[0]),int(point[1]))):return _fail("Delegated pipe waypoint escapes its local region.")
	if not stage.get("operations",[]) is Array or not stage.get("modules",[]) is Array or not stage.get("modules",[]).is_empty():
		return _fail("A delegated leaf contains only its code-owned worker output, never additional module placements.")
	if not stage.get("module_bindings",[]) is Array or not stage.get("module_bindings",[]).is_empty():
		return _fail("Delegate module assembly bindings through a separate explicit construction stage.")
	var descriptor_sha:=Compiler.digest(Compiler.canonical(value).to_utf8_buffer())
	var prepared: bool=not stage.get("operations",[]).is_empty()
	if prepared:
		if stage.get("delegation_descriptor_sha256")!=descriptor_sha or not stage.get("input_snapshot_sha256") is String \
			or stage.input_snapshot_sha256.length()!=64 or not stage.input_snapshot_sha256.is_valid_hex_number(false) \
			or not _integer(stage.get("input_generation"),1,2147483647):return _fail("Prepared worker output needs the exact descriptor, native source and generation identities.")
	elif stage.has("delegation_descriptor_sha256") or stage.has("input_snapshot_sha256") or stage.has("input_generation"):
		return _fail("An empty planned delegation cannot masquerade as a prepared source-bound result.")
	return {"ok":true,"descriptor_sha256":descriptor_sha,"prepared_shape":prepared,"instance_id":instance,"zero_writes":true,
		"scope":"Structural validation only. A live host prepare/preview/approval is required even for serialized prepared geometry."}

static func compile(node: Dictionary,detail_context_result: Dictionary) -> Dictionary:
	var checked:=validate(node)
	if not checked.ok:return checked
	if not detail_context_result.get("ok",false) or not detail_context_result.get("context") is Dictionary:
		return _fail("Delegation requires an actual host detail-context result.")
	var stage: Dictionary=node.stage;var descriptor: Dictionary=node.delegation
	var context: Dictionary=detail_context_result.context.duplicate(true)
	if Compiler.rect(context.get("region"))!=Compiler.rect(stage.region) or not _integer(context.get("generation"),1,2147483647):
		return _fail("Delegated source capture must exactly cover the stage at a positive native generation.")
	if detail_context_result.get("selected_instance","")!=checked.instance_id:return _fail("Host native-instance selection differs from the delegated contract.")
	if not checked.instance_id.is_empty():
		var instances: Variant=detail_context_result.get("instances",[])
		if not instances is Array or instances.size()>128 or not instances.any(func(item: Variant)->bool:return item is Dictionary and item.get("instance_id")==checked.instance_id and item.get("current_geometry_verified",false)):
			return _fail("Selected native instance lacks current complete host geometry verification.")
	if not context.get("allowed_materials") is Array or descriptor.params.material not in context.allowed_materials:return _fail("Current host material permission refuses the delegated material.")
	context.allowed_materials=stage.materials.filter(func(material: Variant)->bool:return material in context.allowed_materials)
	if not _integer(context.get("max_cells"),1,Jobs.MAX_CELLS) or int(descriptor.params.max_cells)>int(context.max_cells):return _fail("Current host worker capacity is smaller than the declared request.")
	context.max_cells=mini(int(context.max_cells),int(stage.budget.max_checked_cells))
	for field: String in ["protected","clearances"]:
		if not context.get(field,[]) is Array:return _fail("Current host guard arrays are malformed.")
		context[field]=_merge(context.get(field,[]),stage.get(field,[]))
	var proposal:=Jobs.compile_job(descriptor.job_kind,descriptor.params,context)
	if not proposal.ok:return proposal
	var generated:=Jobs.stage_from_job(proposal,str(stage.id),str(stage.intent))
	if not generated.ok:return generated
	var result: Dictionary=generated.stage
	result.depends_on=stage.get("depends_on",[]).duplicate()
	for field: String in GUARD_FIELDS:result[field]=_merge(result.get(field,[]),stage.get(field,[]))
	result.uncertainty=_merge(stage.get("uncertainty",[]),result.get("uncertainty",[]))
	result.refusal_conditions=stage.get("refusal_conditions",[]).duplicate(true)
	result["delegation_descriptor_sha256"]=checked.descriptor_sha256
	result["delegation_worker_proposal_sha256"]=proposal.proposal_sha256
	var prepared_node:=node.duplicate(true);prepared_node.stage=result
	var validated:=validate(prepared_node)
	if not validated.ok:return validated
	return {"ok":true,"stage":result,"proposal":proposal,"descriptor_sha256":checked.descriptor_sha256,
		"source_sha256":proposal.source_sha256,"stage_sha256":Compiler.digest(Compiler.canonical(result).to_utf8_buffer()),
		"worker_scan_cells":proposal.budget.scan_cells,"native_cells":proposal.budget.unique_cells,"zero_writes":true,"model_calls":0}
