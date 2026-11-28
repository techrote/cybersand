extends RefCounted
## Immutable experimental input. The interactive owner catalogue may evolve;
## the registered comparison reads only this pre-reveal recipe/metadata export.
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Library=preload("res://scripts/batch_lab/native_module_library.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const PATH:="res://data/batch_lab/m67/comparison-catalogue.v1.json"
const SHA256:="f47321fa74664d2cd16ee6624e7814751182fb08be20aa2fe58715ad29f16fd8"
const RECIPE_SHA256:="f3c9c09dbff564e8830a785e9d6a3b87111dd47c2afa15327882486843d917e2"
const SOURCE_COMMIT:="3ef69c8645ab2aefa8189dac39195043824e824f"
const CATALOGUE_ID:="cybersand-curated-parts-2026-11-v2"
const MATERIALS:=[0,7,28,58]
const SEMANTIC_FIELDS:=["allowed_transforms","anchor","attachments","clearances","design_card_ids","extent",
	"fixed_regions","format","id","name","part_type","protected_regions","roles","tags","variation_regions"]

static func load_frozen() -> Dictionary:
	if FileAccess.get_sha256(PATH)!=SHA256:return {"ok":false,"reason":"Frozen comparison catalogue bytes changed."}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATH))!=OK:return {"ok":false,"reason":"Frozen comparison catalogue is not JSON."}
	var value: Variant=parser.data
	if not value is Dictionary or value.get("format")!="cybersand-m67-frozen-comparison-catalogue-v1" \
		or value.get("source_catalogue_commit")!=SOURCE_COMMIT or value.get("recipe_sha256")!=RECIPE_SHA256 \
		or not value.get("recipes") is Array or value.recipes.size()!=40 \
		or Compiler.digest(Compiler.canonical(value.recipes).to_utf8_buffer())!=RECIPE_SHA256:
		return {"ok":false,"reason":"Frozen comparison catalogue identity or recipe digest differs."}
	return {"ok":true,"recipes":value.recipes.duplicate(true),"sha256":SHA256,"recipe_sha256":RECIPE_SHA256,
		"source_commit":SOURCE_COMMIT,"native_readback_verified":false,"zero_writes":true}

static func recipes() -> Array:
	var loaded:=load_frozen()
	return loaded.get("recipes",[])

static func source_plane(recipe: Dictionary) -> Dictionary:
	var width: int=int(recipe.extent[0]);var height: int=int(recipe.extent[1])
	var cells:=PackedByteArray();cells.resize(width*height*2)
	for operation: Dictionary in recipe.operations:
		if operation.shape!="rectangle" or operation.x0<0 or operation.y0<0 or operation.x1>=width or operation.y1>=height \
			or operation.x1<operation.x0 or operation.y1<operation.y0:return Module.failure("Invalid frozen source rectangle.")
		for y: int in range(int(operation.y0),int(operation.y1)+1):
			for x: int in range(int(operation.x0),int(operation.x1)+1):
				var old:=cells.decode_u16((y*width+x)*2)
				if old not in [0,58] and old!=int(operation.material):return Module.failure("Frozen source violates material replacement permissions.")
				cells.encode_u16((y*width+x)*2,int(operation.material))
	return {"ok":true,"cells":cells,"sha256":Compiler.digest(cells)}

static func semantic_identity(module: Dictionary) -> String:
	var value:={}
	for field: String in SEMANTIC_FIELDS:value[field]=module.get(field)
	return Compiler.digest(Compiler.canonical(value).to_utf8_buffer())

static func template_library() -> Dictionary:
	var frozen:=load_frozen()
	if not frozen.ok:return frozen
	var library:=Library.new()
	for recipe: Dictionary in frozen.recipes:
		var projected:=source_plane(recipe)
		if not projected.ok:return projected
		var metadata: Dictionary=recipe.metadata.duplicate(true)
		metadata["provenance"]={"kind":"unexecuted-frozen-comparison-projection","source_commit":SOURCE_COMMIT,
			"recipe_sha256":RECIPE_SHA256,"native_construction_status":"not-executed"}
		var harvested:=Module.harvest(projected.cells,Vector2i(int(recipe.extent[0]),int(recipe.extent[1])),Module.rect(recipe.harvest_region),metadata)
		if not harvested.ok:return harvested
		var added:=library.add(harvested.module)
		if not added.ok:return added
	return {"ok":true,"library":library,"count":library.count(),"recipe_sha256":RECIPE_SHA256,"zero_writes":true,"native_readback_verified":false}
