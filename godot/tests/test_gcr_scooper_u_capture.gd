extends SceneTree

const Capture=preload("res://qualification/gcr_scooper_u_capture.gd")
const Authoring=preload("res://scripts/gcr_flyer_authoring.gd")
var checks: int=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok: failures.append(why)
func closed_paths(value: Dictionary) -> int:
	var total: int=0
	for name: String in value.exit_paths:
		if not value.exit_paths[name].open_side: total+=1
	return total

func _run() -> void:
	var protocol_path: String=ProjectSettings.globalize_path("res://../docs/audits/gcr-u-hull-2026-11-04/protocol.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--protocol="): protocol_path=arg.trim_prefix("--protocol=")
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	check(parsed is Dictionary and Capture.configuration_error(parsed).is_empty(),"registered protocol admitted")
	if not parsed is Dictionary: quit(1);return
	var protocol: Dictionary=parsed
	for key: String in ["ticks","move_from","workers"]:
		var corrupted: Dictionary=protocol.duplicate(true);corrupted[key]=int(corrupted[key])+1
		check(not Capture.configuration_error(corrupted).is_empty(),"frozen configuration corruption refuses "+key)
	var corrupted: Dictionary=protocol.duplicate(true);corrupted.cases[1].id=corrupted.cases[0].id
	check(not Capture.configuration_error(corrupted).is_empty(),"duplicate case refuses")
	corrupted=protocol.duplicate(true);corrupted.cases[0].material=2.5
	check(not Capture.configuration_error(corrupted).is_empty(),"fractional material is not truncated into an admitted ID")
	corrupted=protocol.duplicate(true);corrupted.profiles[1].corner_indices=[3.5]
	check(not Capture.configuration_error(corrupted).is_empty(),"fractional corner index is not truncated into a proxy")
	for profile: Dictionary in protocol.profiles:
		var definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile.definition_path))
		var resolved: Dictionary=Authoring.resolve_record(definition)
		check(not resolved.has("error"),"explicit profile validates")
		if resolved.has("error"): continue
		var com: Vector2=resolved.resolved_com
		var geometry: Array=resolved.resolved_rects
		var floor_rect: Rect2=Capture.rect(definition.hull.rects[profile.floor_index])
		var core: Rect2=Capture.rect(profile.core)
		var centre: Vector2=core.get_center()
		var inside: Dictionary=Capture.classify_local(centre-com,geometry,com,definition,profile)
		check(inside.primary_cavity and inside.core_cavity and inside.inside_rectangles.is_empty(),"core is actually open, not an AABB solid")
		var floor_point:=Vector2(centre.x,floor_rect.get_center().y)
		check(Capture.classify_local(floor_point-com,geometry,com,definition,profile).get("class")=="floor","floor classification follows actual geometry")
		var grain:=Vector2(centre.x,floor_rect.position.y-.25)
		var old: Dictionary=Capture.classify_local(grain-com,geometry,com,definition,profile)
		var phase: Dictionary=Capture.classify_local(grain+Vector2(0,.5)-com,geometry,com,definition,profile)
		var escaped: Dictionary=Capture.classify_local(grain+Vector2(0,floor_rect.size.y+1)-com,geometry,com,definition,profile)
		check(old.inside_rectangles.is_empty() and not phase.inside_rectangles.is_empty() and not phase.below_closed_floor,"one-boundary overlap is not a far-side escape")
		check(escaped.below_closed_floor and escaped.inside_rectangles.is_empty(),"genuine far-side point is measured separately")
		for angle: float in [0.,.4,1.2]:
			var pose:=Transform2D(angle,Vector2(512.25,250.75))
			var local: Vector2=floor_point-com
			var recovered: Vector2=pose.affine_inverse()*(pose*local)
			check(recovered.distance_to(local)<.0002 and Capture.classify_local(recovered,geometry,com,definition,profile).get("class")=="floor","copied rotation/translation frame closes")
		if profile.id=="u_corners":
			var toe: Dictionary=Capture.classify_local(Vector2(-11,-2)-com,geometry,com,definition,profile)
			check(toe.inside_corner and not toe.primary_cavity,"corner fill is real hull, excluded from cavity")
		var packet: PackedFloat64Array=Capture.raster_packet(geometry,Transform2D(0,Vector2(512,250)),.18,float(resolved.resolved_inertia),1)
		check(packet.size()==17*geometry.size(),"one copied sample record per actual rectangle")
	# A static graph control with a known closed U and an intentionally removed
	# floor column detects a real mask path rather than merely proxy-ID seams.
	var bounds:=Rect2(-5,-5,10,7)
	var profile: Dictionary={"core":[-3,-5,6,5],"rim_y":-5,"left_index":1,"right_index":2,"floor_span":[-5,5]}
	var pose:=Transform2D(0,Vector2(20,20))
	var roi:=Rect2i(10,10,20,20)
	var mask: Dictionary={}
	for y: int in range(15,22):
		for x: int in range(15,25):
			if y>=20 or x<17 or x>=23: mask[Vector2i(x,y)]=1 if y>=20 else 2 if x<17 else 3
	for diagonal: bool in [false,true]:
		check(closed_paths(Capture.mask_connectivity(mask,pose,Vector2.ZERO,bounds,profile,roi,diagonal))==0,"sealed U mask has no closed-side path")
		var broken: Dictionary=mask.duplicate();broken.erase(Vector2i(20,20));broken.erase(Vector2i(20,21))
		var hole: Dictionary=Capture.mask_connectivity(broken,pose,Vector2.ZERO,bounds,profile,roi,diagonal)
		check(hole.exit_paths.has("bottom") and not hole.exit_paths.bottom.open_side,"intentional through-floor hole has an actual graph path")
		var open: Dictionary=mask.duplicate()
		for y: int in range(15,20):
			for x: int in [23,24]: open.erase(Vector2i(x,y))
		var open_profile: Dictionary=profile.duplicate(true);open_profile.right_index=-1
		var mouth: Dictionary=Capture.mask_connectivity(open,pose,Vector2.ZERO,bounds,open_profile,roi,diagonal)
		check(mouth.exit_paths.has("right") and mouth.exit_paths.right.open_side and not mouth.exit_paths.has("bottom"),"open-side exit cannot wrap around to masquerade as a floor hole")
	for tick: int in [0,119,120,239,240,329,330,449]:
		var spec: Dictionary={"move":[1,-1],"trim":1,"boost":true}
		var request: Dictionary=Capture.command(protocol,spec,tick)
		var moving: bool=tick in [120,239]
		check(request.action.move==(Vector2(1,-1) if moving else Vector2.ZERO) and request.ports.boost==moving,"exact move/boost interval")
		check(request.ports.e==moving and not request.ports.q and request.action.secondary==(tick in [240,329]),"tip and brake retirement")
	print("GCR_SCOOPER_U_APPARATUS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Exact profile geometry/frame, overlap-vs-escape and static connectivity validity controls; no gameplay acceptance"}))
	quit(0 if failures.is_empty() else 1)
