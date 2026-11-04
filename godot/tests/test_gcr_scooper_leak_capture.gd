extends SceneTree
const Historical=preload("res://tests/support/gcr_historical_scooper.gd")

# Diagnostic validity controls: distinguishes sample/current frames, hull
# penetration versus true far-side escape, and exact packed-byte coordinates.
const Capture=preload("res://qualification/gcr_scooper_leak_capture.gd")
const Authoring=preload("res://scripts/gcr_flyer_authoring.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
var checks: int=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason)

func _run() -> void:
	var installed: bool=Historical.install()
	check(installed,"retain registered stepped classifier fixture")
	if not installed: quit(1);return
	var index: int=Fleet.index_for_id("scooper")
	var rectangles: Array=Fleet.collision_rects(index)
	var resolved: Dictionary=Authoring.resolve_record(Fleet.authoring_record(index))
	var com: Vector2=resolved.resolved_com
	var examples: Array=[
		[Vector2(0,0),"cavity",true,false],
		[Vector2(0,2.5),"deck",false,false],
		[Vector2(0,4.5),"below_closed_deck",false,true],
		[Vector2(-14,0),"closed_stop",false,false],
		[Vector2(-16,0),"beyond_closed_stop",false,false],
		[Vector2(18.5,0),"beyond_open_nose",false,false],
		[Vector2(0,-5.5),"above_rim",false,false],
		[Vector2(17.5,-1.5),"nose",false,false]]
	for example: Array in examples:
		var result: Dictionary=Capture.classify_local(example[0]-com,rectangles,com)
		check(result["class"]==example[1],"distinct local class "+str(example[1]))
		check(result.primary_cavity==example[2] and result.below_closed_deck==example[3],"primary cavity/closed escape are independent "+str(example[1]))
	# One cell can be above the sampled deck yet inside the moved current deck.
	# This is the retained tick180 observation, not a far-side leak by itself.
	var point: Vector2=Vector2(0,1.75)-com
	var sampled: Dictionary=Capture.classify_local(point,rectangles,com)
	var current: Dictionary=Capture.classify_local(point+Vector2(0,0.6),rectangles,com)
	check(sampled.primary_cavity and not sampled.below_closed_deck,"sampled load is in the cavity")
	check(current["class"]=="deck" and not current.primary_cavity and not current.below_closed_deck,"current-pose overlap cannot be called far-side leakage")
	for angle: float in [0.0,0.3,-0.7,PI*0.5]:
		var pose:=Transform2D(angle,Vector2(512.25,250.125))
		for example: Array in examples:
			var local: Vector2=example[0]-com
			var world: Vector2=pose*local
			var recovered: Vector2=pose.affine_inverse()*world
			check(recovered.distance_to(local)<0.0002,"translated/rotated inverse frame closes")
			check(Capture.classify_local(recovered,rectangles,com)["class"]==example[1],"rotation does not change a separated class")
	var cells:=PackedByteArray([0,2,0,0,2,0,0,2,0,0,0,2])
	var points: Array[Vector2i]=Capture.points_from_snapshot({"cells":cells},Vector2i(10,20),Vector2i(4,3),2)
	check(points==[Vector2i(11,20),Vector2i(10,21),Vector2i(13,21),Vector2i(13,22)],"packed-byte search preserves exact world grid coordinates")
	check(Capture.points_from_snapshot({"cells":PackedByteArray([2])},Vector2i.ZERO,Vector2i(4,3),2).is_empty(),"truncated snapshot refuses rather than inventing coordinates")
	var geometry: Array=[{"center":Vector2.ZERO,"size":Vector2(26,2)}]
	var roi: Rect2i=Capture.observation_roi(Transform2D(0,Vector2(512,250)),geometry,[Vector2i(490,249),Vector2i(536,249)])
	check(roi.size==Vector2i(128,128) and roi.has_point(Vector2i(490,249)) and roi.has_point(Vector2i(536,249)),"bounded ROI contains current hull and preceding near cloud")
	for centre: Vector2 in [Vector2(-10,-20),Vector2(1020,510)]:
		roi=Capture.observation_roi(Transform2D(0,centre),geometry,[])
		check(Capture.WORLD_RECT.encloses(roi),"ROI clamps to exact fixture bounds")
	var schedule: Dictionary={"move_from":120,"move_to":240,"brake_to":330}
	var spec: Dictionary={"move":[1,-1],"boost":true}
	for tick: int in [0,119,120,239,240,329,330,449]:
		var request: Dictionary=Capture.command(schedule,spec,tick)
		var moving: bool=tick in [120,239]
		check(request.action.move==(Vector2(1,-1) if moving else Vector2.ZERO),"exact command interval at "+str(tick))
		check(request.action.secondary==(tick in [240,329]) and request.ports.boost==moving,"brake and boost retirement at "+str(tick))
		check(float(request.action.trim)==0 and not request.ports.q and not request.ports.e,"no intended tip in leakage controls")
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--protocol="): path=arg.trim_prefix("--protocol=")
	if not path.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(parsed is Dictionary and Capture.configuration_protocol_error(parsed).is_empty(),"actual frozen protocol is admitted")
		if parsed is Dictionary:
			for field: String in ["ticks","grains","move_from"]:
				var bad: Dictionary=parsed.duplicate(true);bad[field]=int(bad[field])+1
				check(not Capture.configuration_protocol_error(bad).is_empty(),"registered bound corruption refuses "+field)
			var bad: Dictionary=parsed.duplicate(true);bad.cases[0].boost=true
			check(not Capture.configuration_protocol_error(bad).is_empty(),"case actuation corruption refuses")
			bad=parsed.duplicate(true);bad.cases[1]=bad.cases[0].duplicate(true)
			check(not Capture.configuration_protocol_error(bad).is_empty(),"duplicate case identity refuses")
	print("GCR_SCOOPER_LEAK_APPARATUS ",JSON.stringify({"checks":checks,"failures":failures,"protocol_checked":not path.is_empty(),"scope":"Copied coordinate/classification/phase validation; no physics efficacy acceptance"}))
	quit(0 if failures.is_empty() else 1)
