extends SceneTree
## Pure source-recipe preflight. A simulated raster is never a native harvest.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Catalogue = preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Legacy = preload("res://scripts/batch_lab/native_module_examples.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); push_error(label)

static func source_plane(recipe: Dictionary) -> Dictionary:
	var width: int = recipe.extent[0]; var height: int = recipe.extent[1]
	var cells := PackedByteArray(); cells.resize(width*height*2)
	for operation: Dictionary in recipe.operations:
		if operation.shape!="rectangle" or operation.x0<0 or operation.y0<0 or operation.x1>=width or operation.y1>=height \
			or operation.x1<operation.x0 or operation.y1<operation.y0: return {"ok":false,"reason":"invalid rectangle"}
		for y: int in range(operation.y0,operation.y1+1):
			for x: int in range(operation.x0,operation.x1+1):
				var old := cells.decode_u16((y*width+x)*2)
				if old not in [0,58] and old!=operation.material: return {"ok":false,"reason":"source recipe replaces non-Empty/non-Hardwall material"}
				cells.encode_u16((y*width+x)*2,operation.material)
	return {"ok":true,"cells":cells}

static func components(cells: PackedByteArray, extent: Vector2i) -> int:
	var seen := PackedByteArray(); seen.resize(extent.x*extent.y)
	var count := 0
	for start: int in extent.x*extent.y:
		if seen[start] or cells.decode_u16(start*2)==0: continue
		count += 1
		var queue := PackedInt32Array([start]); seen[start]=1; var cursor := 0
		while cursor<queue.size():
			var index := queue[cursor]; cursor += 1
			var x := index%extent.x; var y := index/extent.x
			for offset: Vector2i in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
				var next_x := x+offset.x; var next_y := y+offset.y
				if next_x<0 or next_x>=extent.x or next_y<0 or next_y>=extent.y: continue
				var next := next_y*extent.x+next_x
				if not seen[next] and cells.decode_u16(next*2)!=0: seen[next]=1; queue.append(next)
	return count

func _initialize() -> void:
	var recipes := Catalogue.recipes(); var originals := Legacy.recipes(); var hashes := {}; var ids := {}; var rows: Array = []
	var library := Library.new()
	check(recipes.size()==40 and Catalogue.recipes(false).size()==32,"forty recipes contain thirty-two distinct additions")
	for i: int in originals.size(): check(Module.json_bytes(recipes[i])==Module.json_bytes(originals[i]),"original source recipe unchanged "+originals[i].id)
	for recipe: Dictionary in recipes:
		check(not ids.has(recipe.id),"unique catalogue identity "+recipe.id); ids[recipe.id]=true
		var projected := source_plane(recipe)
		check(projected.ok,"native permission-compatible source operation order "+recipe.id+" "+str(projected.get("reason","")))
		if not projected.ok: continue
		var metadata: Dictionary = recipe.metadata.duplicate(true)
		metadata["provenance"] = {"kind":"synthetic-catalogue-preflight","native_status":"not-executed"}
		var extent := Vector2i(int(recipe.extent[0]),int(recipe.extent[1]))
		var harvested := Module.harvest(projected.cells,extent,Module.rect(recipe.harvest_region),metadata)
		check(harvested.ok,"curated geometry/clearance/face contracts validate "+recipe.id+" "+str(harvested.get("reason","")))
		if not harvested.ok: continue
		var module: Dictionary = harvested.module
		var size := Vector2i(int(module.extent[0]),int(module.extent[1]))
		var geometry_key := Module.digest(Module.json_bytes(module.extent)+harvested.cells)
		check(not hashes.has(geometry_key),"genuinely distinct source geometry "+recipe.id); hashes[geometry_key]=true
		var component_count := components(harvested.cells,size)
		check(component_count==1,"complete part is face connected "+recipe.id+" count="+str(component_count))
		check(library.add(module).ok,"library accepts checked recipe fixture "+recipe.id)
		for transform: String in module.allowed_transforms:
			var compiled := Module.compile(module,{"origin":[3,5],"transform":transform},
				{"region":[0,0,128,128],"protected":[],"allowed_materials":Catalogue.MATERIALS,"max_cells":16384})
			check(compiled.ok,"orthogonal transformed local contracts "+recipe.id+" "+transform+" "+str(compiled.get("reason","")))
			if not compiled.ok: continue
			var target_size: Array = [compiled.footprint[2],compiled.footprint[3]]
			var oracle := PackedByteArray(); oracle.resize(int(target_size[0])*int(target_size[1])*2)
			# Independent explicit scalar matrix, not Module.transform_point.
			for y: int in size.y:
				for x: int in size.x:
					var tx := x; var ty := y
					match transform:
						"mirror_x": tx=size.x-1-x
						"mirror_y": ty=size.y-1-y
						"rotate_90": tx=size.y-1-y; ty=x
						"rotate_180": tx=size.x-1-x; ty=size.y-1-y
						"rotate_270": tx=y; ty=size.x-1-x
					oracle.encode_u16((ty*int(target_size[0])+tx)*2,harvested.cells.decode_u16((y*size.x+x)*2))
			var actual := PackedByteArray(); actual.resize(oracle.size())
			for offset: int in range(0,compiled.cells.size(),3): actual.encode_u16(((compiled.cells[offset+1]-5)*int(target_size[0])+compiled.cells[offset]-3)*2,compiled.cells[offset+2])
			check(actual==oracle,"complete independent transformed material oracle "+recipe.id+" "+transform)
		rows.append({"id":module.id,"format":module.format,"extent":module.extent,"geometry_sha256":module.geometry.sha256,"components":component_count})
	check(library.count()==40 and library.summaries().all(func(item: Dictionary) -> bool: return not item.native_readback_verified),"all source fixtures remain metadata-only with no invented native qualification")
	var bootstrap := Catalogue.template_library()
	check(bootstrap.ok and bootstrap.count==40 and bootstrap.library.summaries().all(func(item: Dictionary) -> bool: return not item.native_readback_verified),"planner bootstrap is explicitly unexecuted and zero-write")
	if bootstrap.ok:
		for item: Dictionary in bootstrap.library.all(): check(item.geometry==library.get_module(item.id).geometry,"bootstrap matches independently rasterized recipe "+item.id)
	print("NATIVE_CATALOGUE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"recipes":rows,
		"scope":"Pure projected recipe and transform checks; source programs need actual native construction and harvest."}))
	quit(0 if failures.is_empty() else 1)
