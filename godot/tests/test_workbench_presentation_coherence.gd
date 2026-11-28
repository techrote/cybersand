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

func _paint(image: Image, x: int, y: int, id: int) -> void:
	image.set_pixel(x,y,Color(float(id)/255.0,0.0,0.0,1.0))

func _run() -> void:
	var image: Image = _world()
	var rectangles: Array = [{"center":Vector2.ZERO,"size":Vector2(10,6)}]
	var original := Transform2D(0.0,Vector2(85,90))
	var moved := Transform2D(0.0,Vector2(94,90))
	var pilot_area := Rect2i(67,68,48,48)
	var far_patch := PackedInt32Array([150,85,4,4,0,8])
	check(Coherence.patches_preserve_region(pilot_area,far_patch),
		"a complete disjoint published patch preserves dry pixels")
	far_patch.append_array(PackedInt32Array([70,70,1,1,32,2]))
	check(not Coherence.patches_preserve_region(pilot_area,far_patch),
		"a single authored cell intersecting the region revokes inherited clearance")
	check(not Coherence.patches_preserve_region(pilot_area,PackedInt32Array())
		and not Coherence.patches_preserve_region(pilot_area,PackedInt32Array([0,0,512,512,0,1024])),
		"missing patch evidence or a full refresh cannot imply a dry region")
	check(Coherence.region_is_empty(image,pilot_area) and Coherence.empty_region_covers_sweep(
		pilot_area,original,Transform2D(PI/3.0,moved.origin),rectangles),
		"a wholly Empty published area covers the continuous rotating pilot")
	var old_plane := image.duplicate()
	for material: int in [2,3]:
		_paint(old_plane,91,90,material)
		check(not Coherence.region_is_empty(old_plane,pilot_area),
			"Sand or Water in either active plane cannot authorize dry presentation")
	_paint(old_plane,91,90,0)
	old_plane.set_pixel(91,90,Color(0,1,0,1))
	check(Coherence.region_is_empty(old_plane,pilot_area),"material state is separate from material ID")
	check(not Coherence.empty_region_covers_sweep(pilot_area,original,Transform2D(0,Vector2(112,90)),rectangles),
		"the whole moving footprint must remain inside the certified area")
	check(not Coherence.empty_region_covers_sweep(pilot_area,original,moved,[{}])
		and not Coherence.empty_region_covers_sweep(pilot_area,original,moved.scaled(Vector2(2,1)),rectangles),
		"malformed collider or transform cannot reuse a published Empty area")
	check(not Coherence.region_is_empty(image,Rect2i(-1,0,48,48)),
		"out-of-image bounds refuse even when returned pixels might be padded Empty")
	check(Coherence.assess(original,moved,rectangles,image).safe,
		"clear swept ordinary body admits live pose")
	check(Coherence.assess(original,original,rectangles,image).reason == "same_pose",
		"exact same pose does not consume a scan")
	_paint(image,91,90,6)
	check(Coherence.assess(original,moved,rectangles,image).reason == "material_in_swept_mask",
		"Fire in intermediate swept footprint blocks speculative live pose")
	_paint(image,91,90,4)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"Smoke blocks just like Fire")
	_paint(image,91,90,2)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"granular Sand mask penetration blocked")
	_paint(image,91,90,3)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"Water mask penetration blocked")
	_paint(image,91,90,58)
	check(not Coherence.assess(original,moved,rectangles,image).safe,
		"hard Wall penetration blocked")
	_paint(image,91,90,0)
	_paint(image,150,150,6)
	check(Coherence.assess(original,moved,rectangles,image).safe,
		"distant Fire never freezes clean flyer")
	_paint(image,150,150,0)
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
	_paint(image,74,130,6)
	check(not Coherence.assess(wings_bound,wings_live,wings,image).safe,
		"material in just one compound rectangle blocks entire body")
	_paint(image,74,130,0)
	var rotate := [{"center":Vector2(10,0),"size":Vector2(10,4)}]
	var rotation_bound := Transform2D(0.0,Vector2(128,128))
	var rotation_live := Transform2D(PI/2.0,Vector2(128,128))
	check(Coherence.assess(rotation_bound,rotation_live,rotate,image).safe,
		"rotated collider sweep passes clear World")
	_paint(image,135,135,6)
	check(not Coherence.assess(rotation_bound,rotation_live,rotate,image).safe,
		"intermediate rotation checks all swept material, not only endpoints")
	_paint(image,135,135,0)
	# Exact counterexample from 2026-11-14 independent review. All samples at
	# t=0,1/3,2/3,1 miss this material cell, yet the true moving rectangle
	# contains the *cell centre* at t=0.1833333333.
	var counter_start := Transform2D(0.25,Vector2(100,100))
	var counter_end := Transform2D(0.75,Vector2(98,98))
	var witness_t: float = 0.18333333333333333
	var witness_pose := Transform2D(0.25 + 0.5 * witness_t,
		Vector2(100,100).lerp(Vector2(98,98),witness_t))
	var witness_local: Vector2 = witness_pose.affine_inverse() * Vector2(94.5,100.5)
	check(absf(witness_local.x)<5.0 and absf(witness_local.y)<3.0,
		"pre-fix counterexample actually penetrates full continuous sweep")
	_paint(image,94,100,58)
	var counter_result: Dictionary = Coherence.assess(
		counter_start,counter_end,rectangles,image)
	print("PR593_SWEEP_COUNTEREXAMPLE ",JSON.stringify({
		"start":[100,100,0.25],"end":[98,98,0.75],
		"cell":[94,100],"cell_centre":[94.5,100.5],
		"witness_t":witness_t,
		"witness_local":[witness_local.x,witness_local.y],
		"result":counter_result}))
	check(not counter_result.safe and counter_result.reason=="material_in_swept_mask",
		"continuous swept coverage rejects material missed by four sampled poses")
	_paint(image,94,100,0)
	# Pure sub-cell translation: neither endpoint contains the cell centre;
	# the continuous path does. One sample per endpoint is not a proof.
	var point_rect: Array = [{"center":Vector2.ZERO,"size":Vector2(0.2,0.2)}]
	var point_start := Transform2D(0.0,Vector2(100.1,100.5))
	var point_end := Transform2D(0.0,Vector2(100.9,100.5))
	_paint(image,100,100,3)
	check(Coherence.assess(point_start,point_end,point_rect,image).reason=="material_in_swept_mask",
		"subcell translation catches material between two outside endpoints")
	_paint(image,100,100,0)

	# Rotation alone: a long, thin offset rectangle crosses a material
	# centre exactly halfway through, while both endpoints and intermediate
	# original 1-cell pose samples miss the pixel.
	var thin: Array = [{"center":Vector2(5.0,0.0),"size":Vector2(8.0,0.15)}]
	var rot_start := Transform2D(-0.15,Vector2(128.5,128.5))
	var rot_end := Transform2D(0.15,Vector2(128.5,128.5))
	_paint(image,133,128,6)
	check(Coherence.assess(rot_start,rot_end,thin,image).reason=="material_in_swept_mask",
		"pure rotation catches thin off-axis intermediate cell")
	_paint(image,133,128,0)

	# Independent Kestrel-sized 9x6 analogue to the reported 10x6 example;
	# a real native Kestrel is 9x6, so this also becomes a production-path
	# adversarial case in the authored native-World integration fixture.
	var kestrel_size: Array = [{"center":Vector2.ZERO,"size":Vector2(9,6)}]
	var kestrel_start := Transform2D(0.0,Vector2(40,60))
	var kestrel_end := Transform2D(0.5,Vector2(42,58))
	_paint(image,37,55,58)
	check(Coherence.assess(kestrel_start,kestrel_end,kestrel_size,image).reason=="material_in_swept_mask",
		"combined translate/rotate 9x6 Kestrel blocks intermittent wall cell")
	_paint(image,37,55,0)

	# False-refusal cost is deliberately visible and bounded. Here the
	# continuously translated body ends at y=102 while the material cell's
	# centre is at y=102.5, yet rectangular dilation safely rejects it.
	var straight_rect: Array = [{"center":Vector2.ZERO,"size":Vector2(4,4)}]
	_paint(image,101,102,6)
	var padding_cost: Dictionary = Coherence.assess(Transform2D(0,Vector2(100,100)),
		Transform2D(0,Vector2(102,100)),straight_rect,image)
	check(not padding_cost.safe and padding_cost.reason=="material_in_swept_mask",
		"conservative dilation can refuse a nonintersecting near-graze")
	print("PR593_SWEEP_DILATION_FALSE_REFUSAL ",JSON.stringify(padding_cost))
	_paint(image,101,102,0)

	# Arbitrary non-rigid input must not be silently normalized into a
	# smaller untested rigid sweep. Main-thread Rapier supplies rigid poses.
	var scaled := Transform2D(0.0,Vector2(85,90))
	scaled.x *= 1.01
	check(Coherence.assess(scaled,moved,rectangles,image).reason=="nonrigid_pose",
		"scaled pose fails closed")
	var sheared := Transform2D(0.0,Vector2(85,90))
	sheared.y += Vector2(0.1,0.0)
	check(Coherence.assess(sheared,moved,rectangles,image).reason=="nonrigid_pose",
		"skewed pose fails closed")
	check(Coherence.assess(original,moved,rectangles,image,{},false,false,0).reason=="scan_budget",
		"zero scan budget fails closed")
	var expired_deadline: int = Time.get_ticks_usec()-1
	var timed_out: Dictionary = Coherence.assess(original,moved,rectangles,image,
		{},false,false,Coherence.MAX_SCAN_CELLS,expired_deadline)
	check(not timed_out.safe and timed_out.reason=="time_budget" and
			int(timed_out.scanned)<=32,
		"expired global time deadline fails closed before admitting live pose")
	check(Coherence.assess(original,moved,rectangles,image,
			{},false,false,Coherence.MAX_SCAN_CELLS,0).safe,
		"unlimited diagnostic guard remains backward-compatible")
	check(Coherence.assess(original,moved,[],image).reason=="missing_world_or_geometry",
		"missing collider geometry fails closed")
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
