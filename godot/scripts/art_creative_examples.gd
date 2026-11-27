extends RefCounted
## Deterministic host-authored demonstration fixtures, never a model or an
## inference result. Nothing is applied until the owner previews and approves.
const Proposal = preload("res://scripts/art_authoring_proposal.gd")

static func catalogue() -> Array:
	return [
		{"id":"industrial_repair","title":"Repair the relay hall","description":"Extend a damaged industrial room while preserving its lower service passage."},
		{"id":"structural_facade","title":"A braced civic facade","description":"Build piers, floor bands and separate material accents around open windows."},
		{"id":"scifi_interior","title":"Orbital transit interior","description":"Upper workshops and lower machinery flank a protected clear concourse."},
		{"id":"revised_arcology","title":"Terraced arcology study","description":"A staged composition ready for taller, leaner or material-focused revisions."},
		{"id":"protected_courtyard","title":"Build around the old monument","description":"A protected central structure remains untouched inside a new courtyard frame."},
		{"id":"palette_foundry","title":"Palette-led foundry","description":"Structural frames, apparatus bodies and bounded repeated details have distinct roles."},
		{"id":"stopped_workshop","title":"Interrupted fabrication hall","description":"A substantial roof and finite fixtures support Stop, acknowledged-prefix review and replan."},
		{"id":"staged_megaframe","title":"Four-storey megaframe","description":"Six separately approved native stages form a large industrial environment."},
		{"id":"xeno_vault","title":"Alien rib vault","description":"Irregular rounded ribs and suspended forms use the same finite native authorities."}
	]

static func _x(region: Rect2i, percent: int) -> int:
	return region.position.x+clampi(percent*region.size.x/100,0,region.size.x-1)

static func _y(region: Rect2i, percent: int) -> int:
	return region.position.y+clampi(percent*region.size.y/100,0,region.size.y-1)

static func _rect(region: Rect2i, x: int, y: int, width: int, height: int, material: int = 58) -> Dictionary:
	return {"shape":"rectangle","x0":_x(region,x),"y0":_y(region,y),
		"x1":maxi(_x(region,x),_x(region,x+width)-1),
		"y1":maxi(_y(region,y),_y(region,y+height)-1),"material":material}

static func _line(region: Rect2i, x0: int, y0: int, x1: int, y1: int, width: int = 2, material: int = 58) -> Dictionary:
	return {"shape":"line","x0":_x(region,x0),"y0":_y(region,y0),"x1":_x(region,x1),"y1":_y(region,y1),
		"width":maxi(1,width*mini(region.size.x,region.size.y)/100),"material":material}

static func _guard(region: Rect2i, x: int, y: int, width: int, height: int) -> Rect2i:
	return Rect2i(_x(region,x),_y(region,y),maxi(1,_x(region,x+width)-_x(region,x)),maxi(1,_y(region,y+height)-_y(region,y)))

static func _stage(id: String, title: String, operations: Array, dependencies: Array = []) -> Dictionary:
	return {"id":id,"title":title,"depends_on":dependencies,"operations":operations}

static func make(id: String, region: Rect2i, palette: Array = [0,58]) -> Dictionary:
	if region.size.x < 128 or region.size.y < 128 or region.size.x*region.size.y > 262144:
		return {"ok":false,"error":"Offline examples need a selected region at least 128 by 128 and at most 262144 cells."}
	if 58 not in palette: return {"ok":false,"error":"These editable examples need Hard Wall (58) in the owner palette."}
	var entry: Dictionary = {}
	for candidate: Dictionary in catalogue():
		if candidate.id == id: entry = candidate; break
	if entry.is_empty(): return {"ok":false,"error":"Unknown offline example."}
	var accent := 58
	for material: int in palette:
		if material not in [0,58]: accent = material; break
	var setup_operations: Array = [_rect(region,0,96,100,4)]
	var stages: Array = []
	var protected: Array = []
	var routes: Array = []
	var pins: Array = ["Keep construction inside the selected region.","Retain explicit protected areas.","Use real native geometry; decorative mechanisms do not imply functional machinery."]
	match id:
		"industrial_repair":
			setup_operations.append_array([_rect(region,8,62,22,4),_rect(region,70,62,22,4),
				_rect(region,8,28,4,34),_rect(region,88,28,4,34)])
			stages.append(_stage("repair","Bridge the missing beam and add supports",[
				_rect(region,30,62,40,4),_rect(region,8,24,84,4),
				_rect(region,22,28,3,34),_rect(region,75,28,3,34),
				_line(region,12,40,22,28),_line(region,78,28,88,40)]))
			stages.append(_stage("apparatus","Add bounded upper workshop fixtures",[
				_rect(region,30,46,14,10,accent),_rect(region,50,42,18,14,accent),
				_rect(region,30,34,38,2,accent)],["repair"]))
			protected.append(_guard(region,5,74,90,16))
			routes.append(_guard(region,5,74,90,16))
			pins.append("Preserve the lower service passage.")
		"structural_facade":
			stages.append(_stage("frame","Build legible piers and floor bands",[
				_rect(region,8,8,4,80),_rect(region,88,8,4,80),_rect(region,8,8,84,4),
				_rect(region,12,32,76,3),_rect(region,12,58,76,3),_rect(region,12,84,76,4),
				_rect(region,30,12,3,72),_rect(region,67,12,3,72)]))
			stages.append(_stage("bracing","Brace the outer bays",[
				_line(region,13,14,28,30),_line(region,72,30,86,14),
				_line(region,13,38,28,56),_line(region,72,56,86,38)],["frame"]))
			stages.append(_stage("accents","Differentiate upper windows and lintels",[
				_rect(region,38,18,22,2,accent),_rect(region,38,42,22,2,accent),
				_rect(region,17,70,8,2,accent),_rect(region,75,70,8,2,accent)],["bracing"]))
			protected.append(_guard(region,37,64,26,18))
			routes.append(_guard(region,37,64,26,18))
			pins.append("Keep the central lower opening clear.")
		"scifi_interior":
			setup_operations.append_array([_rect(region,4,4,92,3),_rect(region,4,7,3,86),_rect(region,93,7,3,86)])
			stages.append(_stage("decks","Frame upper labs and lower plant",[
				_rect(region,10,38,80,4),_rect(region,10,66,80,4),
				_rect(region,28,10,3,28),_rect(region,68,10,3,28),
				_rect(region,28,70,3,22),_rect(region,68,70,3,22)]))
			stages.append(_stage("services","Add machinery with a readable hierarchy",[
				_rect(region,12,18,10,12,accent),_rect(region,36,22,23,8,accent),
				_rect(region,76,16,10,14,accent),_rect(region,36,78,23,9,accent)],["decks"]))
			protected.append(_guard(region,10,46,80,16))
			routes.append(_guard(region,10,46,80,16))
			pins.append("Preserve the continuous central concourse.")
		"revised_arcology":
			stages.append(_stage("terraces","Build three receding terraces",[
				_rect(region,8,85,84,4),_rect(region,20,60,64,4),_rect(region,35,35,42,4)]))
			stages.append(_stage("supports","Connect terraces with visible supports",[
				_rect(region,14,64,4,21),_rect(region,78,64,4,21),
				_rect(region,27,39,4,21),_rect(region,70,39,4,21),
				_line(region,18,80,25,66),_line(region,74,66,78,80)],["terraces"]))
			stages.append(_stage("crown","Give the upper tier a distinct profile",[
				_rect(region,39,18,3,17),_rect(region,69,13,3,22),_line(region,41,18,70,13,2),
				_rect(region,46,24,16,2,accent)],["supports"]))
			protected.append(_guard(region,32,68,36,13))
			routes.append(_guard(region,32,68,36,13))
			pins.append("Later revisions must preserve the central lower passage.")
		"protected_courtyard":
			setup_operations.append(_rect(region,44,40,12,30))
			protected.append(_guard(region,40,35,20,40))
			stages.append(_stage("enclosure","Frame the preserved central monument",[
				_rect(region,12,18,76,4),_rect(region,12,22,4,66),_rect(region,84,22,4,66),
				_rect(region,16,46,19,3),_rect(region,65,46,19,3)]))
			stages.append(_stage("galleries","Add side galleries without crossing the protected volume",[
				_line(region,18,26,30,42),_line(region,70,42,82,26),
				_rect(region,20,59,9,11,accent),_rect(region,71,59,9,11,accent)],["enclosure"]))
			routes.append(_guard(region,20,78,60,10))
			pins.append("The old central monument and its protected surrounding void are immutable.")
		"palette_foundry":
			stages.append(_stage("structure","Lay out the foundry frame",[
				_rect(region,6,10,88,4),_rect(region,6,14,4,78),_rect(region,90,14,4,78),
				_rect(region,10,70,80,4),_rect(region,26,35,3,35),_rect(region,71,35,3,35)]))
			stages.append(_stage("machines","Place differentiated apparatus bodies",[
				_rect(region,14,44,8,16,accent),_rect(region,36,48,22,12,accent),
				_rect(region,79,40,7,20,accent)],["structure"]))
			stages.append(_stage("details","Repeat finite suspended panels",[
				{"shape":"repeat","count":6,"step":[maxi(1,10*region.size.x/100),0],
					"item":_rect(region,17,23,3,6,accent)}],["machines"]))
			protected.append(_guard(region,12,80,76,10))
			routes.append(_guard(region,12,80,76,10))
			pins.append("Use the selected accent only for apparatus and suspended panels.")
		"stopped_workshop":
			stages.append(_stage("roof","Construct the substantial roof in native chunks",[
				_rect(region,4,8,92,24),_rect(region,4,32,5,60),_rect(region,91,32,5,60)]))
			stages.append(_stage("workbays","Add separated work bays after the roof",[
				_rect(region,15,58,18,4),_rect(region,41,58,18,4),_rect(region,67,58,18,4),
				_rect(region,20,44,8,7,accent),_rect(region,46,40,8,11,accent),
				_rect(region,72,46,8,5,accent)],["roof"]))
			protected.append(_guard(region,12,74,76,15))
			routes.append(_guard(region,12,74,76,15))
			pins.append("Stop preserves only the actual acknowledged prefix; resume requires a fresh proposal and approval.")
		"staged_megaframe":
			stages.append(_stage("foundation","Install the foundation and outer piers",[
				_rect(region,4,90,92,5),_rect(region,4,6,4,84),_rect(region,92,6,4,84)]))
			stages.append(_stage("columns","Raise internal structural columns",[
				{"shape":"repeat","count":4,"step":[maxi(1,20*region.size.x/100),0],
					"item":_rect(region,18,12,3,78)}],["foundation"]))
			stages.append(_stage("storeys","Connect the four storeys",[
				_rect(region,8,12,84,3),_rect(region,8,33,84,3),
				_rect(region,8,54,84,3),_rect(region,8,75,84,3)],["columns"]))
			stages.append(_stage("braces","Brace alternating perimeter bays",[
				_line(region,9,17,16,30),_line(region,84,30,90,17),
				_line(region,9,59,16,72),_line(region,84,72,90,59)],["storeys"]))
			stages.append(_stage("canopy","Add a stepped canopy and short upper rails",[
				_rect(region,13,5,74,2),_rect(region,26,2,48,3),
				_rect(region,24,18,10,1),_rect(region,64,60,10,1)],["braces"]))
			stages.append(_stage("apparatus","Differentiate six bounded machines and control strips",[
				_rect(region,25,22,9,7,accent),_rect(region,45,41,9,8,accent),
				_rect(region,65,22,9,7,accent),_rect(region,25,64,9,7,accent),
				_rect(region,45,83,9,4,accent),_rect(region,65,64,9,7,accent)],["canopy"]))
			routes.append(_guard(region,24,37,12,3))
			pins.append("Approve each finite stage separately; no cross-stage atomicity is promised.")
		"xeno_vault":
			stages.append(_stage("ribs","Sweep irregular native ribs around an open chamber",[
				{"shape":"polyline","points":[[_x(region,12),_y(region,90)],[_x(region,18),_y(region,48)],
					[_x(region,35),_y(region,18)],[_x(region,58),_y(region,12)],[_x(region,80),_y(region,34)],
					[_x(region,90),_y(region,90)]],"width":maxi(2,3*mini(region.size.x,region.size.y)/100),"material":58},
				_line(region,23,42,38,29,2),_line(region,66,26,80,47,2),
				_rect(region,20,85,62,3)]))
			stages.append(_stage("organs","Suspend finite distinct organic forms",[
				{"shape":"disc","x":_x(region,43),"y":_y(region,44),"radius":maxi(2,6*mini(region.size.x,region.size.y)/100),"material":accent},
				{"shape":"disc","x":_x(region,66),"y":_y(region,57),"radius":maxi(2,8*mini(region.size.x,region.size.y)/100),"material":accent}],["ribs"]))
			protected.append(_guard(region,28,72,46,9))
			routes.append(_guard(region,28,72,46,9))
			pins.append("Preserve the broad lower chamber; unusual silhouette is preferable to uniform filler.")
	return {"ok":true,"error":"","scenario":id,"evidence_kind":"deterministic host-authored fixture; zero model inference",
		"brief":{"objective":entry.description,"style":"organic alien" if id=="xeno_vault" else "industrial science fiction",
			"complexity":"balanced","variation":0.25,"allow_destructive":false,"pinned_constraints":pins},
		"proposal":{"schema":Proposal.SCHEMA,"title":entry.title,"summary":entry.description,
			"region":[region.position.x,region.position.y,region.size.x,region.size.y],
			"assumptions":["Decorative apparatus is native material geometry, not a functional machine."],
			"unresolved":[],"stages":stages},
		"setup_operations":setup_operations,"protected":protected,"expected_routes":routes,
		"route_claim":"Exact empty-rectangle diagnostic only; not actor reachability, flight or playfeel."}
