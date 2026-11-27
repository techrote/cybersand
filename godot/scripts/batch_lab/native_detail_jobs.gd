extends RefCounted
## Code-owned bounded procedural executors. Inputs and outputs are typed values;
## this registry cannot dispatch inference, run code, access files or write World.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const FORMAT := "cybersand-native-detail-job-v1"
const MAX_SIDE := 128
const MAX_CELLS := 16384
const MAX_SCAN_CELLS := 1048576
const MAX_COMPONENTS := 128
const MAX_STAGE_GUARDS := 64
const NORMALS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const FACING := {"up":Vector2i.UP,"right":Vector2i.RIGHT,"down":Vector2i.DOWN,"left":Vector2i.LEFT}
const KINDS := ["contextual_ribs","surface_trim","anchored_clutter","service_panel","mechanical_infill","short_pipe","framed_opening","edge_wear"]
const FIELDS := {
	"contextual_ribs":["facing","width","depth","spacing","density"],
	"surface_trim":["facing","length","depth","spacing","density"],
	"anchored_clutter":["facing","width","depth","spacing","density","irregularity"],
	"service_panel":["frame_thickness","ribs"],
	"mechanical_infill":["orientation","thickness","spacing"],
	"short_pipe":["waypoints","width"],
	"framed_opening":["opening","frame_thickness"],
	"edge_wear":["amount"]}

static func describe_jobs() -> Array:
	var descriptions := [
		["contextual_ribs","Mounted ribs","Repeated short ribs project from observed structural faces."],
		["surface_trim","Surface trim","Thin tangent strips follow an existing observed supporting face."],
		["anchored_clutter","Anchored service clutter","Seeded small connected bosses stay attached to prior material."],
		["service_panel","Framed service panel","A compact framed panel has bounded cross ribs and a genuine source anchor."],
		["mechanical_infill","Mechanical infill","Repeated thin fins occupy an explicit empty bay and touch its prior frame."],
		["short_pipe","Short service route","A finite orthogonal route connects two observed source faces."],
		["framed_opening","Door or window frame","A bounded connected frame preserves an explicit empty interior."],
		["edge_wear","Noncritical edge wear","Remove only declared variable Hard wall boundary cells while preserving local four-neighbor connectivity."]]
	var result: Array = []
	for row: Array in descriptions:
		result.append({"kind":row[0],"name":row[1],"intent":row[2],"executor":"code-owned-procedural-v1",
			"common_fields":["region","material","seed","max_cells"],"specific_fields":FIELDS[row[0]].duplicate(),
			"controls":_controls(row[0]),"default_material":0 if row[0]=="edge_wear" else 28,
			"requires_variable_scope":row[0]=="edge_wear","source_rule":"Hard wall removal" if row[0]=="edge_wear" else "Empty-only source-anchored addition",
			"max_side":MAX_SIDE,"max_cells":MAX_CELLS,"max_scan_cells":MAX_SCAN_CELLS,"output_schema":FORMAT,
			"native_writes":false,"requires_native_preview":true,"model_calls":0})
	return result

static func _controls(kind: String) -> Array:
	var result: Array=[]
	if kind in ["contextual_ribs","surface_trim","anchored_clutter"]:
		result.append({"key":"facing","type":"choice","options":["any","up","right","down","left"],"default":"any"})
		result.append({"key":"length" if kind=="surface_trim" else "width","type":"integer","min":1,"max":32 if kind=="surface_trim" else 4,"default":12 if kind=="surface_trim" else 2})
		result.append({"key":"depth","type":"integer","min":1,"max":3 if kind=="surface_trim" else 12,"default":1 if kind=="surface_trim" else 5})
		result.append({"key":"spacing","type":"integer","min":2,"max":64,"default":16 if kind=="surface_trim" else 8})
		result.append({"key":"density","type":"number","min":0.0,"max":1.0,"default":0.35 if kind=="anchored_clutter" else 1.0})
		if kind=="anchored_clutter": result.append({"key":"irregularity","type":"integer","min":0,"max":4,"default":2})
	elif kind in ["service_panel","framed_opening"]:
		result.append({"key":"frame_thickness","type":"integer","min":1,"max":4,"default":2})
		if kind=="service_panel": result.append({"key":"ribs","type":"integer","min":0,"max":6,"default":2})
		else: result.append({"key":"opening","type":"choice","options":["door","window"],"default":"door"})
	elif kind=="mechanical_infill":
		result=[{"key":"orientation","type":"choice","options":["vertical","horizontal"],"default":"vertical"},
			{"key":"thickness","type":"integer","min":1,"max":3,"default":1},{"key":"spacing","type":"integer","min":2,"max":32,"default":5}]
	elif kind=="short_pipe":
		result=[{"key":"waypoints","type":"cell-path","minimum_points":2,"maximum_points":8,"orthogonal":true},
			{"key":"width","type":"integer","min":1,"max":4,"default":2}]
	elif kind=="edge_wear": result=[{"key":"amount","type":"integer","min":1,"max":256,"default":16}]
	return result

static func _failure(reason: String, code := "invalid_job", status := "refused") -> Dictionary:
	return {"ok":false,"status":status,"reason":reason,"code":code,"zero_writes":true,"operations":[],"model_calls":0}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return Module.integer(value) and int(value)>=low and int(value)<=high

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func _material(point: Vector2i, context: Dictionary, projected := false) -> int:
	var region: Rect2i=context.region
	if not region.has_point(point): return -1
	var local := point-region.position
	var cells: PackedByteArray=context.projected if projected else context.source
	return cells.decode_u16((local.y*region.size.x+local.x)*2)

static func _attachment_guards(points: Array, region: Rect2i, existing: Array) -> Array:
	# Exact row runs with identical vertically adjacent runs merged. Never use a
	# bounding box over a sparse point set: that would silently protect holes.
	var unique: Dictionary={}
	for raw: Array in points:
		var point:=Vector2i(int(raw[0]),int(raw[1]))
		if region.has_point(point) and not Module._in_regions(point,existing): unique[point]=true
	var ordered: Array=unique.keys()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i)->bool:return a.x<b.x if a.y==b.y else a.y<b.y)
	var runs: Array[Rect2i]=[]
	for point: Vector2i in ordered:
		if not runs.is_empty() and runs[-1].position.y==point.y and runs[-1].end.x==point.x: runs[-1].size.x+=1
		else: runs.append(Rect2i(point,Vector2i.ONE))
	var result: Array=[]; var last: Dictionary={}
	for run: Rect2i in runs:
		var key:=Vector2i(run.position.x,run.size.x)
		if last.has(key) and result[last[key]][1]+result[last[key]][3]==run.position.y: result[last[key]][3]+=1
		else: last[key]=result.size(); result.append(Module._array_rect(run))
	return result

static func _prepare(kind: String, params: Dictionary, host: Dictionary) -> Dictionary:
	if kind not in KINDS: return _failure("Unknown code-owned detail executor.","unknown_executor")
	if not Module._keys(params,["region"],["material","seed","max_cells"]+FIELDS[kind]): return _failure("Detail parameters contain unknown or executable fields.")
	var region := Module.rect(host.get("region")); var area := Module.rect(params.region)
	if region.position.x<0 or region.position.y<0 or region.position.x>4095 or region.position.y>4095 or region.size.x<1 or region.size.y<1 or region.size.x>512 or region.size.y>512 \
		or region.end.x>4096 or region.end.y>4096 or not host.get("source_cells") is PackedByteArray \
		or host.source_cells.size()!=region.get_area()*2 or Module.digest(host.source_cells)!=host.get("source_sha256"):
		return _failure("Detail compilation needs complete bounded copied source materials and their exact hash.","invalid_source")
	if area.size.x<1 or area.size.y<1 or area.size.x>MAX_SIDE or area.size.y>MAX_SIDE or not region.encloses(area):
		return _failure("Detail region must fit the inspected plane and the 128-cell side bound.","invalid_region")
	var material: Variant=params.get("material",0 if kind=="edge_wear" else 28)
	var seed_value: Variant=params.get("seed",0)
	var limit: Variant=params.get("max_cells",host.get("max_cells",MAX_CELLS))
	if not _integer(host.get("max_cells",MAX_CELLS),1,MAX_CELLS) or not _integer(limit,1,int(host.get("max_cells",MAX_CELLS))) \
		or not Module.integer(seed_value): return _failure("Detail seed and host/worker resource ceilings must be finite integers.","invalid_budget")
	var allowed: Variant=host.get("allowed_materials",[])
	if not allowed is Array or allowed.is_empty() or allowed.size()>256 or not Module.integer(material) \
		or int(material) not in allowed or int(material) not in Setup.MATERIALS or (kind!="edge_wear" and int(material)==0) \
		or (kind=="edge_wear" and int(material)!=0): return _failure("Detail material is outside explicit host permission or job semantics.","material_permission")
	for identity: Variant in allowed:
		if not _integer(identity,0,65535): return _failure("Host detail material palette is malformed.","material_permission")
	var support: Variant=host.get("support_materials",[58,28,13,7])
	if not support is Array or support.is_empty() or support.size()>32: return _failure("Declare a bounded support-material observation policy.")
	for value: Variant in support:
		if not _integer(value,1,65535): return _failure("Support identities must be explicit non-Empty uint16 values.")
	var guards: Array = []; var variable: Array = []; var guard_count := 0; var guard_scan := 0
	for field: String in ["protected","clearances","fixed_regions","variable_regions"]:
		var rectangles: Variant=host.get(field,[])
		if not rectangles is Array: return _failure("Detail guard/variable regions must be bounded rectangle arrays.")
		guard_count += rectangles.size()
		if guard_count>256: return _failure("Combined detail scope exceeds 256 rectangles.","scope_budget")
		for raw: Variant in rectangles:
			var box := Module.rect(raw)
			if box.position.x<0 or box.position.y<0 or box.position.x>4095 or box.position.y>4095 \
				or box.size.x<1 or box.size.y<1 or box.size.x>4096 or box.size.y>4096 or box.end.x>4096 or box.end.y>4096:
				return _failure("Invalid detail guard or variable rectangle.")
			if field=="clearances":
				if not region.encloses(box): return _failure("Declared clearance needs its complete inspected source region.","uninspected_clearance")
				guard_scan+=box.get_area()
				if guard_scan>MAX_SCAN_CELLS: return _failure("Clearance inspection exceeds the bounded worker scan budget.","scan_budget","exhausted")
				for y: int in range(box.position.y,box.end.y):
					for x: int in range(box.position.x,box.end.x):
						if host.source_cells.decode_u16(((y-region.position.y)*region.size.x+x-region.position.x)*2)!=0:
							return _failure("A declared source clearance already contains observed material.","blocked_clearance")
			if field=="variable_regions": variable.append(Module._array_rect(box))
			else: guards.append(Module._array_rect(box))
	var fixed_cells: Variant=host.get("attachment_cells",[])
	if not fixed_cells is Array or fixed_cells.size()>8192: return _failure("Attachment preservation exceeds 8,192 declared cells.","scope_budget")
	var fixed := {}
	for raw: Variant in fixed_cells:
		if not Module._pair(raw): return _failure("Attachment cells must be exact integer coordinates.")
		fixed[Vector2i(int(raw[0]),int(raw[1]))]=true
	var native_guard_count: Variant=host.get("native_protected_region_count",host.get("protected",[]).size())
	if not _integer(native_guard_count,0,MAX_STAGE_GUARDS): return _failure("Native host protection already exceeds one bounded stage.","stage_scope_budget","exhausted")
	var exact_guards: Array=[]
	for guard: Array in guards:
		if guard not in exact_guards: exact_guards.append(guard)
	exact_guards.append_array(_attachment_guards(fixed_cells,region,exact_guards))
	if exact_guards.size()+int(native_guard_count)>MAX_STAGE_GUARDS:
		return _failure("Exact attachment and retained guard rectangles exceed the native stage's combined 64-region protection bound. Inspect a smaller scope.","stage_scope_budget","exhausted")
	guards=exact_guards
	if host.get("clearances",[]).size()>128: return _failure("Detail clearances exceed the native stage's 128-region bound.","stage_scope_budget","exhausted")
	var random := RandomNumberGenerator.new(); random.seed=int(seed_value)
	if host.has("generation") and (not Module.integer(host.generation) or int(host.generation)<1): return _failure("A supplied native generation must be a positive host integer.","invalid_source")
	return {"ok":true,"region":region,"area":area,"source":host.source_cells,"projected":host.source_cells.duplicate(),
		"generation":host.get("generation",0),"source_clearances":host.get("clearances",[]).duplicate(true),
		"source_sha256":host.source_sha256,"material":int(material),"limit":int(limit),"seed":int(seed_value),"random":random,
		"guards":guards,"variable":variable,"fixed_cells":fixed,"support":support.duplicate(),"points":{},"contacts":[],
		"scan_cells":guard_scan,"components":0,"omitted_components":0,"generated_clearances":[],"diagnostics":[]}

static func _blocked(point: Vector2i, context: Dictionary) -> bool:
	return not context.area.has_point(point) or context.fixed_cells.has(point) or Module._in_regions(point,context.guards)

static func _anchor(points: Array[Vector2i], context: Dictionary) -> Dictionary:
	for point: Vector2i in points:
		for delta: Vector2i in NORMALS:
			var source := point+delta
			if _material(source,context) in context.support:
				return {"kind":"solid-contact","a":[point.x,point.y],"b":[source.x,source.y]}
	return {}

static func _add_component(points: Array[Vector2i], context: Dictionary) -> bool:
	context.scan_cells += points.size()*5
	if context.scan_cells>MAX_SCAN_CELLS or context.components>=MAX_COMPONENTS:
		context.omitted_components += 1; return false
	var unique := {}
	for point: Vector2i in points:
		if _blocked(point,context) or _material(point,context)!=0: context.omitted_components += 1; return false
		unique[point]=true
	var extra := 0
	for point: Vector2i in unique:
		if not context.points.has(point): extra+=1
	if extra==0 or context.points.size()+extra>context.limit: context.omitted_components += 1; return false
	var anchor := _anchor(points,context)
	if anchor.is_empty(): context.omitted_components += 1; return false
	for point: Vector2i in unique: context.points[point]=context.material
	context.components += 1
	if anchor not in context.contacts: context.contacts.append(anchor)
	return true

static func _rectangle(box: Rect2i) -> Array[Vector2i]:
	var points: Array[Vector2i]=[]
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x): points.append(Vector2i(x,y))
	return points

static func _shuffle(items: Array, random: RandomNumberGenerator) -> void:
	for index: int in range(items.size()-1,0,-1):
		var other := random.randi_range(0,index); var held: Variant=items[index]
		items[index]=items[other]; items[other]=held

static func _surface(kind: String, params: Dictionary, context: Dictionary) -> Dictionary:
	var facing: Variant=params.get("facing","any")
	var width: Variant=params.get("length",12) if kind=="surface_trim" else params.get("width",2)
	var depth: Variant=params.get("depth",1 if kind=="surface_trim" else 5)
	var spacing: Variant=params.get("spacing",16 if kind=="surface_trim" else 8)
	var density: Variant=params.get("density",0.35 if kind=="anchored_clutter" else 1.0)
	var irregularity: Variant=params.get("irregularity",2)
	if not facing is String or (facing!="any" and not FACING.has(facing)) or not _integer(width,1,32 if kind=="surface_trim" else 4) \
		or not _integer(depth,1,3 if kind=="surface_trim" else 12) or not _integer(spacing,2,64) \
		or not _number(density,0.0,1.0) or not _integer(irregularity,0,4): return _failure("Invalid bounded face, strip/rib dimensions, spacing or density.")
	var candidates: Array = []; var phase: int=posmod(context.seed,int(spacing)); var normals: Array=NORMALS if facing=="any" else [FACING[facing]]
	for y: int in range(context.area.position.y,context.area.end.y):
		for x: int in range(context.area.position.x,context.area.end.x):
			var point := Vector2i(x,y)
			if _blocked(point,context) or _material(point,context)!=0: continue
			for normal: Vector2i in normals:
				context.scan_cells += 1
				var tangent := Vector2i(-normal.y,normal.x)
				var axis := x if tangent.x!=0 else y
				if posmod(axis,int(spacing))!=phase or _material(point-normal,context) not in context.support: continue
				candidates.append({"point":point,"normal":normal,"tangent":tangent})
	_shuffle(candidates,context.random)
	var desired := int(ceil(float(candidates.size())*float(density)))
	for candidate: Dictionary in candidates:
		if context.components>=desired or context.points.size()>=context.limit: break
		var actual_width := int(width); var actual_depth := int(depth)
		if kind=="anchored_clutter":
			actual_width=context.random.randi_range(1,int(width))
			actual_depth=clampi(int(depth)+context.random.randi_range(-int(irregularity),int(irregularity)),1,12)
		var points: Array[Vector2i]=[]; var supported := true
		for across: int in actual_width:
			if _material(candidate.point+candidate.tangent*across-candidate.normal,context) not in context.support: supported=false; break
			for length: int in actual_depth: points.append(candidate.point+candidate.tangent*across+candidate.normal*length)
		if supported: _add_component(points,context)
	return {"ok":true}

static func _panel(params: Dictionary, context: Dictionary, opening := false) -> Dictionary:
	var thickness: Variant=params.get("frame_thickness",2)
	var ribs: Variant=params.get("ribs",2)
	var type: Variant=params.get("opening","door")
	if not _integer(thickness,1,4) or not _integer(ribs,0,6) or (opening and type not in ["door","window"]): return _failure("Invalid frame thickness, panel rib count or opening type.")
	var area: Rect2i=context.area
	if area.size.x<int(thickness)*2+2 or area.size.y<int(thickness)*2+2: return _failure("Frame needs a positive interior after its authored border.","no_fit")
	if not opening and (area.size.x>48 or area.size.y>64): return _failure("A local service panel is bounded to 48 × 64 cells.","invalid_region")
	var points: Array[Vector2i]=[]
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			var border := x<area.position.x+int(thickness) or x>=area.end.x-int(thickness) or y<area.position.y+int(thickness)
			if not opening or type=="window": border=border or y>=area.end.y-int(thickness)
			if border: points.append(Vector2i(x,y))
	if not opening:
		for rib: int in int(ribs):
			var y := area.position.y+int(thickness)+((rib+1)*(area.size.y-int(thickness)*2))/(int(ribs)+1)
			for x: int in range(area.position.x+int(thickness),area.end.x-int(thickness)): points.append(Vector2i(x,y))
	var interior := Rect2i(area.position+Vector2i.ONE*int(thickness),area.size-Vector2i.ONE*int(thickness)*2)
	if opening and type=="door": interior.size.y+=int(thickness)
	if opening:
		for point: Vector2i in _rectangle(interior):
			context.scan_cells+=1
			if _material(point,context)!=0: return _failure("Proposed opening contains actual source material; erasure is not implicit.","blocked_clearance")
	if not _add_component(points,context): return _failure("The complete frame does not fit, lacks source contact, or exceeds its exact budget.","no_fit")
	if opening: context.generated_clearances.append(Module._array_rect(interior))
	return {"ok":true}

static func _infill(params: Dictionary, context: Dictionary) -> Dictionary:
	var orientation: Variant=params.get("orientation","vertical"); var thickness: Variant=params.get("thickness",1); var spacing: Variant=params.get("spacing",5)
	if orientation not in ["vertical","horizontal"] or not _integer(thickness,1,3) or not _integer(spacing,int(thickness)+1,32): return _failure("Invalid bounded infill orientation, thickness or spacing.")
	var area: Rect2i=context.area; var phase: int=posmod(context.seed,int(spacing))
	var span := area.size.x if orientation=="vertical" else area.size.y
	for offset: int in range(phase,span-int(thickness)+1,int(spacing)):
		var box := Rect2i(area.position+Vector2i(offset,0),Vector2i(int(thickness),area.size.y)) if orientation=="vertical" \
			else Rect2i(area.position+Vector2i(0,offset),Vector2i(area.size.x,int(thickness)))
		_add_component(_rectangle(box),context)
	return {"ok":true}

static func _pipe(params: Dictionary, context: Dictionary) -> Dictionary:
	var waypoints: Variant=params.get("waypoints"); var width: Variant=params.get("width",2)
	if not waypoints is Array or waypoints.size()<2 or waypoints.size()>8 or not _integer(width,1,4): return _failure("A short pipe needs 2–8 orthogonal waypoints and width 1–4.")
	var points: Array[Vector2i]=[]; var unique := {}; var length := 0; var previous := Vector2i.ZERO
	var parsed: Array[Vector2i]=[]; var directions: Array[Vector2i]=[]; var offset: int=(int(width)-1)/2
	for i: int in waypoints.size():
		if not Module._pair(waypoints[i]): return _failure("Pipe waypoints must be exact integer pairs.")
		var point := Vector2i(int(waypoints[i][0]),int(waypoints[i][1]))
		if not context.area.has_point(point): return _failure("Pipe waypoint escapes its assigned region.","outside_region")
		parsed.append(point)
		if i>0:
			if point==previous or (point.x!=previous.x and point.y!=previous.y): return _failure("Pipe segments must be nonzero orthogonal runs.","unsupported_route")
			var step := Vector2i(signi(point.x-previous.x),signi(point.y-previous.y)); var count := absi(point.x-previous.x)+absi(point.y-previous.y)+1
			directions.append(step)
			length+=count
			if length>512: return _failure("A local pipe route exceeds 512 centerline cells.","route_budget")
			# Terminal faces are butt capped, so width never projects into a
			# source anchor. Only the transverse band grows around a centerline.
			var tangent:=Vector2i.DOWN if step.x!=0 else Vector2i.RIGHT
			for distance: int in count:
				var center := previous+step*distance
				for band: int in int(width): unique[center+tangent*(band-offset)]=true
		previous=point
	# Square interior elbows make the entire bent pipe face-connected at width.
	for index: int in range(1,parsed.size()-1):
		var start:=parsed[index]-Vector2i.ONE*offset
		for cell: Vector2i in _rectangle(Rect2i(start,Vector2i.ONE*int(width))): unique[cell]=true
	for point: Vector2i in unique: points.append(point)
	var contacts: Array=[]
	for terminal: int in 2:
		var center: Vector2i=parsed[0] if terminal==0 else parsed[-1]
		var outward: Vector2i=-directions[0] if terminal==0 else directions[-1]
		var tangent:=Vector2i.DOWN if outward.x!=0 else Vector2i.RIGHT
		for band: int in int(width):
			var point:=center+tangent*(band-offset); var anchor:=point+outward
			if _material(anchor,context) not in context.support:
				return _failure("Every cell across both pipe terminal faces must meet observed longitudinal source material.","unanchored_endpoint")
			contacts.append({"kind":"solid-contact","a":[point.x,point.y],"b":[anchor.x,anchor.y]})
	if not _add_component(points,context): return _failure("The complete pipe conflicts with guards, occupied material or its exact budget.","no_fit")
	context.contacts=contacts
	return {"ok":true}

static func _safe_removal(point: Vector2i, context: Dictionary) -> bool:
	# Sufficient local topology guard: all occupied cardinal neighbors remain
	# connected around the 3×3 ring. This never adds a new component after removal;
	# it deliberately refuses some globally safe removals requiring a wider path.
	var neighbors: Array[Vector2i]=[]; var ring := {}
	for y: int in range(point.y-1,point.y+2):
		for x: int in range(point.x-1,point.x+2):
			var at := Vector2i(x,y)
			if at!=point and _material(at,context,true)>0: ring[at]=true
	for normal: Vector2i in NORMALS:
		if ring.has(point+normal): neighbors.append(point+normal)
	if neighbors.is_empty(): return false
	var seen := {neighbors[0]:true}; var queue: Array[Vector2i]=[neighbors[0]]; var cursor := 0
	while cursor<queue.size():
		var at := queue[cursor]; cursor+=1
		for normal: Vector2i in NORMALS:
			var next := at+normal
			if ring.has(next) and not seen.has(next): seen[next]=true; queue.append(next)
	for at: Vector2i in neighbors:
		if not seen.has(at): return false
	return true

static func _wear(params: Dictionary, context: Dictionary) -> Dictionary:
	var amount: Variant=params.get("amount",16)
	if not _integer(amount,1,256) or context.variable.is_empty(): return _failure("Edge wear needs 1–256 removals and explicit noncritical variable regions.","missing_variable_scope")
	var candidates: Array = []
	for point: Vector2i in _rectangle(context.area):
		context.scan_cells+=1
		if _blocked(point,context) or not Module._in_regions(point,context.variable) or _material(point,context)!=58: continue
		for normal: Vector2i in NORMALS:
			if _material(point+normal,context)==0: candidates.append(point); break
	_shuffle(candidates,context.random)
	for point: Vector2i in candidates:
		if context.points.size()>=mini(int(amount),context.limit): break
		context.scan_cells+=40
		if not _safe_removal(point,context): continue
		var local: Vector2i = point-context.region.position
		context.projected.encode_u16((local.y*context.region.size.x+local.x)*2,0)
		context.points[point]=0
	context.components=1 if not context.points.is_empty() else 0
	return {"ok":true}

static func compile_job(kind: String, params: Dictionary, host: Dictionary) -> Dictionary:
	var context := _prepare(kind,params,host)
	if not context.ok: return context
	var built: Dictionary
	match kind:
		"contextual_ribs","surface_trim","anchored_clutter": built=_surface(kind,params,context)
		"service_panel": built=_panel(params,context)
		"framed_opening": built=_panel(params,context,true)
		"mechanical_infill": built=_infill(params,context)
		"short_pipe": built=_pipe(params,context)
		"edge_wear": built=_wear(params,context)
		_: return _failure("Unknown bounded procedural job.")
	if not built.ok: return built
	if context.scan_cells>MAX_SCAN_CELLS: return _failure("Detail scan budget exhausted before a complete proposal could be certified.","scan_budget","exhausted")
	if context.points.is_empty(): return _failure("No permitted source-grounded geometry fits this detail job and finite budget.","no_fit")
	var points: Array=context.points.keys()
	points.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x<b.x if a.y==b.y else a.y<b.y)
	var output: Array=[]; var footprint := Rect2i(points[0],Vector2i.ONE)
	for point: Vector2i in points: output.append([point.x,point.y]); footprint=footprint.merge(Rect2i(point,Vector2i.ONE))
	var proposal := {"ok":true,"status":"proposed","format":FORMAT,"kind":kind,"executor":"code-owned-procedural-v1","zero_writes":true,
		"operations":[{"shape":"pixels","material":context.material,"points":output}],"materials":[context.material],
		"footprint":Module._array_rect(footprint),"required_region":Module._array_rect(context.region),"seed":context.seed,
		"source_sha256":context.source_sha256,"input_generation":context.generation,"params_sha256":Module.digest(Module.json_bytes([kind,params])),
		"budget":{"requested_cells":output.size(),"unique_cells":output.size(),"operations":1,"scan_cells":context.scan_cells,
			"limit":context.limit,"components":context.components,"omitted_components":context.omitted_components},
		"connections":context.contacts,"clearances":context.source_clearances+context.generated_clearances,"guard_scopes":context.guards,
		"checks":{"within_region":true,"protected_unchanged":true,"fixed_unchanged":true,"attachment_cells_unchanged":true,
			"source_rule":"declared variable Hard wall to Empty with sufficient local topology guard" if kind=="edge_wear" else "Empty-only additions; each component touches original observed source"},
		"diagnostics":context.diagnostics,"model_calls":0,
		"scope":"Code-owned zero-write typed proposal over supplied material bytes. The ordinary stage host must recapture, preview, obtain approval, apply native operations and inspect exact receipts."}
	proposal["proposal_sha256"]=Module.digest(Module.json_bytes(proposal))
	return proposal

static func stage_from_job(job: Dictionary, identity: String, intent: String) -> Dictionary:
	if not job.get("ok",false) or job.get("format")!=FORMAT or job.get("status")!="proposed" or not job.get("zero_writes",false):
		return _failure("Only a successful typed worker proposal can become a native stage.")
	var checked := job.duplicate(true); checked.erase("proposal_sha256")
	if Module.json_bytes(job).size()>2*1024*1024 or Module.digest(Module.json_bytes(checked))!=job.get("proposal_sha256"):
		return _failure("Typed worker output changed after compilation; regenerate it from the current source.","worker_output_changed")
	if not Module.identifier(identity) or not Module._text(intent,8192): return _failure("A detail stage needs a finite authored identity and intent.")
	var stage := Compiler.stage_defaults(identity,Module.rect(job.required_region))
	stage.intent=intent; stage.operations=job.operations.duplicate(true); stage.materials=job.materials.duplicate()
	stage.protected=job.guard_scopes.duplicate(true); stage.clearances=job.clearances.duplicate(true); stage.connections=job.connections.duplicate(true)
	stage.budget.max_checked_cells=int(job.budget.limit)
	stage["input_snapshot_sha256"]=job.source_sha256
	if int(job.get("input_generation",0))>0: stage["input_generation"]=int(job.input_generation)
	stage.expected_effects="Bounded "+str(job.kind)+" proposal: "+str(job.budget.unique_cells)+" host-inspected material cells."
	stage.uncertainty=["Static source contact and local geometry only; no physical stability, machine flow or actor traversal guarantee."]
	return {"ok":true,"stage":stage,"zero_writes":true,"source_sha256":job.source_sha256,"worker_params_sha256":job.params_sha256}
