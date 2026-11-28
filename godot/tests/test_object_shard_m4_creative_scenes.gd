extends SceneTree

# Independent authored-geometry census. No body or native pose is invented by
# these fixtures; connected material and real holes precede ordinary discovery.
const Scenes = preload("res://scripts/object_shard_workbench_scenes.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var checks: int = 0
var failures: Array[String] = []
var observed: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("M4_CREATIVE_SCENES: "+label)

func _raster(data: Dictionary) -> PackedByteArray:
	var pixels := PackedByteArray()
	pixels.resize(512*512)
	var packed: Dictionary = Setup.rectangles(data)
	_check(packed.get("error","") == "", "authored paint compacts within ordinary rectangle capacity")
	var rectangles: Variant = packed.get("rectangles",packed.get("runs",PackedInt32Array()))
	# Setup.rectangles is the production authored-start compiler. A separate
	# row-major raster below checks the compiled recipe, never live World state.
	for i: int in range(0,rectangles.size(),5):
		for y: int in range(int(rectangles[i+1]),int(rectangles[i+1])+int(rectangles[i+3])):
			for x: int in range(int(rectangles[i]),int(rectangles[i])+int(rectangles[i+2])):
				pixels[y*512+x] = int(rectangles[i+4])
	return pixels

func _run() -> void:
	var native: Object = ClassDB.instantiate("CyberDemoBridge")
	if native == null:
		_check(false,"actual ordinary native adapter available for the default policy")
		_finish()
		return
	var policy: PackedInt32Array = native.default_liquid_policy()
	_check(Scenes.IDS.size()==Scenes.LABELS.size(),"every demo has one visible label")
	for id: String in Scenes.IDS:
		var data: Dictionary = Scenes.create(id,policy)
		_check(not data.is_empty() and Setup.validate(data).is_empty(),id+": valid ordinary authored recipe")
		if data.is_empty(): continue
		_check(not data.has("object_shards") and not data.has("moving_inventory"),id+": no live-body checkpoint is implied")
		_check(not Scenes.manifest(id).is_empty(),id+": instructions and support route available")
		var pixels: PackedByteArray = _raster(data)
		var material_cells: int = 0
		for material: int in pixels:
			if material in [7,43]: material_cells += 1
		_check(material_cells>0,id+": real authored structural material")
		if id == "perforated":
			for y: int in [288,316,344]:
				for x: int in [148,176,204]:
					_check(pixels[y*512+x]==0,id+": circular opening is Empty at "+str(Vector2i(x,y)))
			_check(pixels[316*512+162]==43,"perforated: material remains between adjacent openings")
		if id == "weathered":
			_check(pixels[282*512+131]==0 and pixels[282*512+135]==7,"weathered: pitted edge and surviving timber are both authoritative")
		if id == "editing_yard":
			_check(pixels[450*512+259]==7 and pixels[463*512+259]==7,"editing yard: fixed wing remains rooted in terrain")
			_check(pixels[300*512+176]==7 and pixels[450*512+144]==1,"editing yard: separate removable supports hold movable panel")
		observed.append({"scene":id,"structural_cells":material_cells,"recipe_sha256":JSON.stringify(data).sha256_text()})
	var raw: String = FileAccess.get_file_as_string(Scenes.OWNER_TOWER_PATH)
	var owner: Dictionary = JSON.parse_string(raw)
	_check(Scenes.create("owner_tower",policy)==owner,"owner recipe preserved exactly, including earlier authored brush marks")
	_check(FileAccess.get_sha256(Scenes.OWNER_TOWER_PATH)=="ad00c753b10c0a1372f2a12ef0e81300ad335ca6d5cdb81290586e13f1dad19a","owner recipe matches uploaded file bytes")
	_finish()

func _finish() -> void:
	print(JSON.stringify({"schema":"objectshard-m4-creative-scenes-v1","checks":checks,
		"failures":failures,"scenes":observed,"scope":"authored-start recipe and material geometry; live physics qualification is separate"}))
	quit(0 if failures.is_empty() else 1)
