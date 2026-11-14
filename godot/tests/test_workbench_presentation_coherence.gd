extends SceneTree

# Exact world-cell-centre oriented rectangles. No native World or renderer
# required for the helper's fail-closed material/geometry decisions.
const Coherence = preload("res://scripts/workbench_presentation_coherence.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("WORKBENCH_PRESENTATION_COHERENCE: "+message)

func _world() -> Image:
	var image: Image = Image.create_empty(256,256,false,Image.FORMAT_RG8)
	image.fill(Color(0,0,0,1))
	return image

func _set(image: Image, x: int, y: int, id: int) -> void:
	image.set_pixel(x,y,Color(float(id)/255.0,0.0,0.0,1.0))

func _run() -> void:
	var image: Image = _world()
	var rectangles: Array = [{"center":Vector2.ZERO,"size":Vector2(10,6)}]
	var original := Transform2D(0.0,Vector2(85,90))
	var moved := Transform2D(0.0,Vector2(94,90))
	check(Coherence.assess(original,moved,rectangles,image).safe,
		"clear swept ordinary body admits live pose")
	check(Coherence.assess(original,original,rectangles,image).reason == "same_pose",
		"exact same pose does not consume a scan")
	_set(image,91,90,6)
	check(Coherence.assess(original,moved,rectangles,image).reason == "material_in_swept_mask",
		"Fire in intermediate swept footprint blocks speculative live pose")
	_set(image,91,90,4)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"Smoke blocks just like Fire")
	_set(image,91,90,2)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"granular Sand mask penetration blocked")
	_set(image,91,90,3)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"Water mask penetration blocked")
	_set(image,91,90,58)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"hard Wall penetration blocked")
	_set(image,91,90,0)
	_set(image,150,150,6)
	check(Coherence.assess(original,moved,rectangles,image).safe,
		"distant Fire never freezes clean flyer")
	_set(image,150,150,0)
	var old := {90*image.get_width()+91:true}
	check(not Coherence.assess(original,moved,rectangles,image,old,false,true).safe,
		"previous material retained by palette crossfade blocks live pose")
	check(Coherence.assess(original,moved,rectangles,image,old,false,false).safe,
		"old-only Fire does not block after crossfade has completed")
	check(Coherence.assess(original,moved,rectangles,image,{},true,true).reason=="previous_texture_unbounded",
		"uncertain full previous texture fails closed")
	check(Coherence.assess(original,moved,rectangles,image,{},true,false).safe,
		"expired previous texture no longer blocks current empty footprint")
	check(Coherence.assess(original,moved,rectangles,image,{},false,false,10).reason=="scan_budget",
		"bounded scan refuses unbounded geometry work")
	check(Coherence.assess(original,Transform2D(0,Vector2(160,90)),rectangles,image).reason=="bounded_pose_delta",
		"large pose jump is not extrapolated")
	check(Coherence.assess(Transform2D(0,Vector2(1,90)),Transform2D(0,Vector2(2,90)),
		rectangles,image).reason=="outside_world",
		"escaping world boundary refuses live pose")
	var wings: Array = [
		{"center":Vector2(-8,0),"size":Vector2(4,4)},
		{"center":Vector2(8,0),"size":Vector2(4,4)}]
	var wings_bound := Transform2D(0.0,Vector2(80,130))
	var wings_live := Transform2D(0.0,Vector2(85,130))
	check(Coherence.assess(wings_bound,wings_live,wings,image).safe,
		"compound body with multiple rectangles passes in free air")
	_set(image,74,130,6)
	check(not Coherence.assess(wings_bound,wings_live,wings,image).safe,
		"material in just one compound rectangle blocks entire body")
	_set(image,74,130,0)
	var rotate := [{"center":Vector2(10,0),"size":Vector2(10,4)}]
	var rotation_bound := Transform2D(0.0,Vector2(128,128))
	var rotation_live := Transform2D(PI/2.0,Vector2(128,128))
	check(Coherence.assess(rotation_bound,rotation_live,rotate,image).safe,
		"rotated collider sweep passes clear World")
	_set(image,135,135,6)
	check(not Coherence.assess(rotation_bound,rotation_live,rotate,image).safe,
		"intermediate rotation checks all swept material, not only endpoints")
	_set(image,135,135,0)
	check(not Coherence.assess(original,moved,[],image).safe,"empty collider set refused")
	check(not Coherence.assess(original,moved,rectangles,null).safe,"missing World refused")
	var results := {"schema":"workbench-presentation-coherence-v1",
		"checks":checks,"failures":failures,"production_source":"res://scripts/workbench_presentation_coherence.gd"}
	var output: String = OS.get_environment("CYBERSAND_PRESENTATION_REPORT")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
		check(file != null,"report destination")
		if file != null:
			file.store_string(JSON.stringify(results,"  ")+"\n")
			file.close()
	print("WORKBENCH_PRESENTATION_COHERENCE_RESULT ",JSON.stringify(results))
	quit(int(not failures.is_empty()))
