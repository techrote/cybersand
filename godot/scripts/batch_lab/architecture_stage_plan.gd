extends RefCounted
## A bounded, zero-write compiler. All geometry/costs come from host rasterization.
## The returned material plane is a compilation projection, never a simulated World.
const ArtPlan = preload("res://scripts/art_batch_plan.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Connections = preload("res://scripts/batch_lab/native_module_connections.gd")
const FORMAT := "cybersand-architecture-plan-v1"
const MAX_STAGES := 32
const MAX_OPERATIONS := 2048
const MAX_CHECKED_CELLS := 262144
const MAX_RASTER_CANDIDATES := 1048576
const MAX_INPUT_BYTES := 2*1024*1024
const MAX_SIDE := 512

var done := false
var result: Dictionary = {}
var _stage: Dictionary = {}
var _context: Dictionary = {}
var _raster: RefCounted
var _region: Rect2i
var _guards: Array[Rect2i] = []
var _clearances: Array[Rect2i] = []
var _materials: Array = []
var _operations: Array = []
var _module_refs: Array = []
var _module_connections: Array = []
var _new_module_connections: Array = []
var _module_protection: Array = []
var _protected_expected: Dictionary = {}
var _source := PackedByteArray()
var _projected := PackedByteArray()
var _seen: Dictionary = {}
var _checked := 0
var _scan_bound := 0
var _limit := MAX_CHECKED_CELLS
var _footprint := Rect2i()
var _started_usec := 0

static func error(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"zero_writes":true}

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func canonical(value: Variant) -> String:
	return JSON.stringify(_canonical_numbers(value),"",true,true)

static func _canonical_numbers(value: Variant) -> Variant:
	if value is float and ArtPlan.integer(value): return int(value)
	if value is Array:
		var output: Array = []
		for item: Variant in value: output.append(_canonical_numbers(item))
		return output
	if value is Dictionary:
		var output := {}
		for key: Variant in value: output[key] = _canonical_numbers(value[key])
		return output
	return value

static func rect(value: Variant) -> Rect2i:
	if not value is Array or value.size()!=4: return Rect2i()
	for n: Variant in value:
		if not ArtPlan.integer(n): return Rect2i()
	return Rect2i(int(value[0]),int(value[1]),int(value[2]),int(value[3]))

static func rect_array(value: Rect2i) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

static func stage_defaults(identity: String, region: Rect2i) -> Dictionary:
	return {"id":identity,"intent":"Bounded native architectural construction",
		"region":rect_array(region),"depends_on":[],"modules":[],"operations":[],
		"materials":Setup.MATERIALS.duplicate(),"protected":[],"clearances":[],"connections":[],
		"budget":{"max_checked_cells":MAX_CHECKED_CELLS},"expected_effects":"Inspect host-calculated geometry before approval.",
		"uncertainty":["Material occupancy does not prove physical stability or actor traversal."],
		"refusal_conditions":["Changed World, invalid geometry, protection, permissions or resource budget."]}

static func validate_plan(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format")!=FORMAT: return error("Unsupported architecture plan format.")
	if canonical(value).to_utf8_buffer().size()>MAX_INPUT_BYTES: return error("Architecture plan exceeds the 2 MiB input budget.")
	if not value.get("id") is String or str(value.id).is_empty(): return error("Plan needs a stable id.")
	if not value.get("intent") is String: return error("Plan needs architectural intent.")
	if not value.get("stages") is Array or value.stages.is_empty() or value.stages.size()>MAX_STAGES:
		return error("A finite plan must contain 1–32 stages.")
	var ids: Array = []
	for stage: Variant in value.stages:
		if not stage is Dictionary: return error("Each stage must be an object.")
		if not stage.get("id") is String or str(stage.id).is_empty() or stage.id in ids:
			return error("Stage ids must be nonempty and unique.")
		if not stage.get("depends_on",[]) is Array: return error("Stage dependencies must be an array.")
		for dependency: Variant in stage.get("depends_on",[]):
			if not dependency is String or dependency not in ids:
				return error("Dependencies must name an earlier stage; cycles and forward references are refused.")
		ids.append(stage.id)
	return {"ok":true,"plan":value.duplicate(true),"plan_sha256":digest(canonical(value).to_utf8_buffer()),"zero_writes":true}

func _fail(reason: String) -> Dictionary:
	done = true
	result = error(reason)
	result["checked_cells"] = _checked
	return result

func begin(stage: Dictionary, context: Dictionary, library: RefCounted = null, completed: Array = []) -> Dictionary:
	done = false
	result = {}
	_stage = stage.duplicate(true)
	_context = context.duplicate(true)
	_started_usec = Time.get_ticks_usec()
	_checked = 0
	_scan_bound = 0
	_seen.clear()
	_guards.clear()
	_clearances.clear()
	_operations.clear()
	_module_refs.clear()
	_module_connections.clear()
	_new_module_connections.clear()
	_module_protection.clear()
	_protected_expected.clear()
	_footprint = Rect2i()
	if canonical(stage).to_utf8_buffer().size()>MAX_INPUT_BYTES: return _fail("Stage exceeds its input budget.")
	for field: String in ["id","intent","expected_effects"]:
		if not stage.get(field) is String or str(stage[field]).is_empty(): return _fail("Stage needs text: "+field)
	for field: String in ["depends_on","modules","operations","materials","protected","clearances","connections","module_bindings","uncertainty","refusal_conditions"]:
		if not stage.get(field,[]) is Array: return _fail("Stage field must be an array: "+field)
	if stage.get("modules",[]).size()>64 or stage.get("operations",[]).size()>MAX_OPERATIONS \
		or stage.get("clearances",[]).size()>128 or stage.get("connections",[]).size()>128 \
		or stage.get("depends_on",[]).size()>MAX_STAGES or stage.get("module_bindings",[]).size()>512:
		return _fail("Stage exceeds bounded module (64), operation (2048), clearance/connection (128) or dependency capacity.")
	for dependency: Variant in stage.get("depends_on",[]):
		if dependency not in completed: return _fail("Dependency has no completed native stage receipt: "+str(dependency))
	_region = rect(stage.get("region"))
	var world: Rect2i = rect(context.get("world_region"))
	if _region.size.x<1 or _region.size.y<1 or _region.size.x>MAX_SIDE or _region.size.y>MAX_SIDE or not world.encloses(_region):
		return _fail("A stage region must fit the World and be at most 512 × 512 cells.")
	if rect(context.get("region"))!=_region: return _fail("Native inspection does not cover this exact stage region.")
	if not context.get("source_cells") is PackedByteArray: return _fail("Native material inspection is required.")
	_source = context.source_cells.duplicate()
	if _source.size()!=_region.size.x*_region.size.y*2: return _fail("Native inspection has the wrong material-plane size.")
	if digest(_source)!=str(context.get("source_sha256","")): return _fail("Native inspection material hash does not match.")
	# A delegated proposal is a pure computation over one inspected plane. Its
	# source pin must survive plan/session serialization and is checked again by
	# the normal compiler; accepting a fresh preview cannot silently rebase it.
	if stage.has("input_snapshot_sha256"):
		var input_hash: Variant=stage.input_snapshot_sha256
		if not input_hash is String or input_hash.length()!=64 or input_hash!=str(context.source_sha256):
			return _fail("Delegated construction input is stale or malformed. Inspect the current region and propose the local job again.")
	if stage.has("input_generation"):
		if not stage.has("input_snapshot_sha256") or not ArtPlan.integer(stage.input_generation) or int(stage.input_generation)<1 \
			or int(stage.input_generation)!=int(context.get("generation",-1)):
			return _fail("Delegated construction belongs to a different World generation. Reinspect and propose it again.")
	if not context.get("paused",false): return _fail("Pause the Workbench before approving static architecture.")
	if not stage.get("budget") is Dictionary or not ArtPlan.integer(stage.budget.get("max_checked_cells")):
		return _fail("Stage must declare an integer maximum checked-cell budget.")
	_limit = int(stage.budget.max_checked_cells)
	if _limit<1 or _limit>MAX_CHECKED_CELLS: return _fail("Stage checked-cell budget must be 1–262144.")
	_materials = []
	for material: Variant in stage.get("materials",[]):
		if not ArtPlan.integer(material) or int(material) not in Setup.MATERIALS or int(material) not in context.get("allowed_materials",Setup.MATERIALS):
			return _fail("Stage requests an unavailable native Art material.")
		if int(material) not in _materials: _materials.append(int(material))
	if _materials.is_empty(): return _fail("Stage must declare allowed material identities.")
	var all_guards: Array = stage.get("protected",[]).duplicate(true)
	all_guards.append_array(context.get("protected",[]))
	if all_guards.size()>64: return _fail("At most 64 protected regions fit one stage.")
	for value: Variant in all_guards:
		var guard: Rect2i = value if value is Rect2i else rect(value)
		if guard.size.x<1 or guard.size.y<1 or not world.encloses(guard): return _fail("Protected regions must fit the World.")
		_guards.append(guard)
	var clearance_scan := 0
	for value: Variant in stage.get("clearances",[]):
		var clearance := rect(value)
		if clearance.size.x<1 or clearance.size.y<1 or not _region.encloses(clearance): return _fail("Clearances must fit the stage region.")
		_clearances.append(clearance)
		clearance_scan += clearance.get_area()
		if clearance_scan>MAX_RASTER_CANDIDATES: return _fail("Clearance verification exceeds the bounded cell-scan budget.")
	var used_instances := {}
	var module_scan := 0
	var module_protection_scan := 0
	for selected: Variant in stage.get("modules",[]):
		if not selected is Dictionary or not selected.get("module_id") is String or not selected.get("placement") is Dictionary:
			return _fail("Selected modules need a module id and typed placement.")
		if library==null: return _fail("This stage requires a loaded native module library.")
		var module: Dictionary = library.get_module(selected.module_id)
		if module.is_empty(): return _fail("Missing native module: "+str(selected.module_id))
		var dimensions: Variant = module.get("extent")
		if not dimensions is Array or dimensions.size()!=2 or not ArtPlan.integer(dimensions[0]) or not ArtPlan.integer(dimensions[1]): return _fail("Loaded module dimensions are malformed.")
		module_scan += int(dimensions[0])*int(dimensions[1])
		if module_scan>MAX_RASTER_CANDIDATES: return _fail("Module decoding/placement exceeds the bounded 1048576-cell inspection budget.")
		if str(selected.get("module_sha256",""))!=str(module.get("content_sha256","")):
			return _fail("Selected module changed or has no pinned content hash: "+str(selected.module_id))
		var compiler: Script = load("res://scripts/batch_lab/native_module.gd")
		var compiled: Dictionary = compiler.compile(module,selected.placement,{"region":_region,"protected":_guards,
			"allowed_materials":_materials,"max_cells":_limit})
		if not compiled.get("ok",false): return _fail(str(compiled.get("reason",compiled.get("error","Module compile refused."))))
		if _operations.size()+compiled.operations.size()>MAX_OPERATIONS: return _fail("Compiled modules exceed the bounded operation capacity.")
		if _module_connections.size()+compiled.get("connections",[]).size()>512: return _fail("Compiled modules exceed 512 inspected connectors.")
		_operations.append_array(compiled.operations)
		var instance_index := _module_refs.size()
		var instance: Variant = selected.get("instance_id",instance_index if module.format==Module.FORMAT else "p-"+digest(str(stage.id).to_utf8_buffer()).left(16)+"-"+str(instance_index))
		if selected.has("instance_id") and not Module.identifier(instance): return _fail("A placed instance id must be a stable module identifier of at most 64 characters.")
		if used_instances.has(instance) or (instance is String and instance in context.get("live_module_instances",[])):
			return _fail("A stage cannot reuse an existing placed instance identity. Select its live connector or author a new instance id.")
		used_instances[instance]=true
		_module_refs.append({"id":selected.module_id,"sha256":module.content_sha256,"instance_id":instance,"placement":selected.placement.duplicate(true)})
		for connector: Dictionary in compiled.get("connections",[]):
			var item := connector.duplicate(true)
			item["module_instance"] = instance
			_module_connections.append(item)
			_new_module_connections.append(item.duplicate(true))
		var emitted := {}
		var exact_cells: PackedInt32Array = compiled.cells
		for i: int in range(0,exact_cells.size(),3): emitted[Vector2i(exact_cells[i],exact_cells[i+1])] = exact_cells[i+2]
		for value: Variant in compiled.get("protected_regions",[]):
			var guard: Rect2i = value if value is Rect2i else rect(value)
			if not _region.encloses(guard): return _fail("Module protection does not fit its host region.")
			module_protection_scan += guard.get_area()
			if module_protection_scan>MAX_RASTER_CANDIDATES or _module_protection.size()>=128: return _fail("Module protection verification exceeds its bounded inspection budget.")
			_module_protection.append(rect_array(guard))
			for y: int in range(guard.position.y,guard.end.y):
				for x: int in range(guard.position.x,guard.end.x):
					var point := Vector2i(x,y)
					var local := point-_region.position
					var expected: int = emitted.get(point,_source.decode_u16((local.y*_region.size.x+local.x)*2))
					if _protected_expected.has(point) and _protected_expected[point]!=expected: return _fail("Selected modules disagree about protected geometry.")
					_protected_expected[point] = expected
		for value: Variant in compiled.get("clearances",[]):
			var clearance: Rect2i = value if value is Rect2i else rect(value.get("region",value) if value is Dictionary else value)
			if clearance.size.x<1 or clearance.size.y<1 or not _region.encloses(clearance): return _fail("Module clearance does not fit the stage region.")
			clearance_scan += clearance.get_area()
			if clearance_scan>MAX_RASTER_CANDIDATES or _clearances.size()>=256: return _fail("Compiled module clearances exceed the bounded inspection budget.")
			_clearances.append(clearance)
	_operations.append_array(stage.get("operations",[]).duplicate(true))
	if _operations.is_empty() or _operations.size()>MAX_OPERATIONS: return _fail("Stage needs 1–2048 bounded native drawing operations.")
	_raster = ArtPlan.new()
	if not _raster.configure(_operations,world): return _fail(_raster.error)
	for operation: Dictionary in _raster.operations:
		if int(operation.material) not in _materials: return _fail("An operation requests a material outside stage permissions.")
		match str(operation.shape):
			"pixels": _scan_bound += operation.points.size()
			"rectangle": _scan_bound += (int(operation.x1)-int(operation.x0)+1)*(int(operation.y1)-int(operation.y0)+1)
			"disc","airbrush": _scan_bound += (2*int(operation.radius)+1)*(2*int(operation.radius)+1)
			"polygon": _scan_bound += operation.polygon_bounds.get_area()
			"line":
				_scan_bound += maxi(absi(int(operation.x1)-int(operation.x0)),absi(int(operation.y1)-int(operation.y0)))+1 if int(operation.width)==1 else int(operation.stroke_bounds.get_area())
		if _scan_bound>MAX_RASTER_CANDIDATES: return _fail("Conservative raster scan bound exceeds 1048576 candidates, including rejected sparse-shape samples.")
	_projected = _source.duplicate()
	return {"ok":true,"status":"compiling","zero_writes":true}

func step() -> Dictionary:
	if done: return result
	# Existing rasterizer yields after its candidate-time budget; one chunk per
	# frame keeps preview finite even for sparse polygons and thick strokes.
	var chunk: Dictionary = _raster.next_chunk(4096)
	if not chunk.is_empty():
		var points: PackedInt32Array = chunk.points
		if _checked+points.size()/2>MAX_RASTER_CANDIDATES: return _fail("Host raster work exceeds the independent 1048576-candidate compilation budget.")
		for offset: int in range(0,points.size(),2):
			var point := Vector2i(points[offset],points[offset+1])
			if not _region.has_point(point): return _fail("Actual raster footprint escapes the stage region.")
			for guard: Rect2i in _guards:
				if guard.has_point(point): return _fail("Actual raster footprint intersects protected cell (%d, %d)." % [point.x,point.y])
			var local := point-_region.position
			var index := local.y*_region.size.x+local.x
			_projected.encode_u16(index*2,int(chunk.material))
			_seen[index] = true
			_footprint = Rect2i(point,Vector2i.ONE) if _seen.size()==1 else _footprint.merge(Rect2i(point,Vector2i.ONE))
			_checked += 1
	if not _raster.exhausted(): return {"ok":true,"status":"compiling","checked_cells":_checked,"zero_writes":true}
	return _finish()

func _cell(point: Vector2i) -> int:
	var local := point-_region.position
	return _projected.decode_u16((local.y*_region.size.x+local.x)*2)

func _finish() -> Dictionary:
	for point: Vector2i in _protected_expected:
		if _cell(point)!=int(_protected_expected[point]): return _fail("Composition changes a module-declared protected cell.")
	var existing: Variant = _context.get("existing_module_connections",[])
	if not existing is Array or existing.size()+_module_connections.size()>512: return _fail("Fresh connection inventory exceeds the 512-descriptor stage bound.")
	var all_connectors: Array = _module_connections.duplicate(true)
	all_connectors.append_array(existing.duplicate(true))
	var joined := Connections.resolve(all_connectors,_stage.get("module_bindings",[]),{"region":rect_array(_region),"projected_cells":_projected})
	if not joined.ok: return _fail(str(joined.reason))
	var reserved := _check_reserved_contacts(joined.contacts,all_connectors,_context.get("reserved_module_contacts",[]))
	if not reserved.ok: return _fail(reserved.reason)
	for clearance: Rect2i in _clearances:
		for y: int in range(clearance.position.y,clearance.end.y):
			for x: int in range(clearance.position.x,clearance.end.x):
				if _cell(Vector2i(x,y))!=0: return _fail("Projected construction blocks required empty clearance at (%d, %d)."%[x,y])
	if _stage.get("connections",[]).size()>128: return _fail("At most 128 connection requirements fit one stage.")
	for connection: Variant in _stage.get("connections",[]):
		if not connection is Dictionary or connection.get("kind") not in ["solid-contact","empty-contact"]:
			return _fail("Connections must declare solid-contact or empty-contact with adjacent cell endpoints.")
		var endpoints: Array[Vector2i] = []
		for key: String in ["a","b"]:
			var pair: Variant = connection.get(key)
			if not pair is Array or pair.size()!=2 or not ArtPlan.integer(pair[0]) or not ArtPlan.integer(pair[1]): return _fail("Connection endpoints must be integer cell pairs.")
			var point := Vector2i(int(pair[0]),int(pair[1]))
			if not _region.has_point(point): return _fail("Connection endpoints must fit the inspected stage region.")
			endpoints.append(point)
		if absi(endpoints[0].x-endpoints[1].x)+absi(endpoints[0].y-endpoints[1].y)!=1: return _fail("A contact requirement needs orthogonally adjacent cells.")
		var must_be_empty: bool = connection.kind=="empty-contact"
		for point: Vector2i in endpoints:
			if (_cell(point)==0)!=must_be_empty: return _fail("Projected geometry does not satisfy a declared connection.")
	var changed := 0
	var counts: Dictionary = {}
	var by_material := {}
	var indices: Array = _seen.keys()
	indices.sort()
	for index: int in indices:
		var material := int(_projected.decode_u16(index*2))
		counts[str(material)] = int(counts.get(str(material),0))+1
		var before := int(_source.decode_u16(index*2))
		if material==before: continue
		# The accepted native Art contract replaces Empty/Hard wall only. All
		# other stored identities remain protected even if a model lists them.
		if before not in [0,58]: return _fail("Native Art cannot replace source material %d with %d at (%d, %d); use ordinary authoring to revise it first."%[before,material,_region.position.x+index%_region.size.x,_region.position.y+index/_region.size.x])
		changed += 1
		if not by_material.has(material): by_material[material] = []
		by_material[material].append([_region.position.x+index%_region.size.x,_region.position.y+index/_region.size.x])
	if changed>_limit: return _fail("Host-calculated native checked cells exceed the declared budget.")
	var native_operations: Array = []
	var ordered_materials: Array = by_material.keys()
	ordered_materials.sort()
	for material: int in ordered_materials: native_operations.append({"shape":"pixels","material":material,"points":by_material[material]})
	var identity := {"stage":_stage,"resolved_modules":_module_refs,"source_sha256":_context.source_sha256,
		"generation":_context.get("generation",-1),"operations":native_operations,"host_budget":changed,
		"module_contact_result":joined,"connection_context_sha256":_context.get("connection_context_sha256","")}
	done = true
	result = {"ok":true,"status":"previewed","zero_writes":true,"kind":"zero-write-compilation",
		"stage_id":_stage.id,"stage_sha256":digest(canonical(_stage).to_utf8_buffer()),
		"preview_sha256":digest(canonical(identity).to_utf8_buffer()),"source_sha256":_context.source_sha256,
		"generation":_context.get("generation",-1),"region":rect_array(_region),"footprint":rect_array(_footprint),
		"budget":{"checked_cells":changed,"conservative_scan_bound":_scan_bound,"emitted_input_points":_checked,"unique_cells":_seen.size(),"changed_cells":changed,"limit":_limit},
		"material_counts":counts,"operations":native_operations,"materials":_materials.duplicate(),
		"protected":_guards.duplicate(),"resolved_modules":_module_refs,"projected_cells":_projected,
		"module_connections":all_connectors,"placed_module_connections":_new_module_connections,"module_contact_result":joined,
		"connection_context_sha256":_context.get("connection_context_sha256",""),"new_protected_regions":_module_protection,
		"projected_sha256":digest(_projected),"compilation_usec":Time.get_ticks_usec()-_started_usec,
		"scope":"Exact static material-operation projection; no native writes, physical simulation, stability or actor-traversal claim."}
	return result


static func _same_contact(a: Dictionary,b: Dictionary) -> bool:
	return (a.a==b.a and a.b==b.b and a.a_cells==b.a_cells and a.b_cells==b.b_cells) or (a.a==b.b and a.b==b.a and a.a_cells==b.b_cells and a.b_cells==b.a_cells)

static func _check_reserved_contacts(contacts: Array, connectors: Array, retained: Variant) -> Dictionary:
	if not retained is Array: return error("Live contact reservation history must be a bounded array.")
	return Connections.check_reserved_contacts(contacts,connectors,retained)


static func compile(stage: Dictionary, context: Dictionary, library: RefCounted = null, completed: Array = []) -> Dictionary:
	var compiler := new()
	var answer: Dictionary = compiler.begin(stage,context,library,completed)
	if not answer.ok: return answer
	while not compiler.done: compiler.step()
	return compiler.result
