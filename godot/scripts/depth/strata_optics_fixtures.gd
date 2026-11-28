extends RefCounted

## Deliberately ambiguous orthographic composition. Exact native probes declare
## what is physically occupied; appearance never supplies collision authority.
const Setup = preload("res://scripts/workbench_setup.gd")
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const ID := "optics-readability-challenge"
const EXTENT := Vector2i(1024,768)


static func metadata() -> Dictionary:
	return {"id":ID,"title":"Optics Readability Challenge",
		"label":"Optics Readability Challenge · 1024 × 768",
		"description":"Identical-colour false platforms, rear stair and ladder, blocked-looking open passage, detailed overlap and a live Sand/Water basin. Use Solo Play to inspect the actual geometry.",
		"extent":[1024,768],"spawn":[410,600],
		"detail_views":[{"id":"false-platform-passage","center":[470,285],"zoom":1.0},
			{"id":"actor-and-moving-material","center":[420,600],"zoom":1.0}],
		"physical_claim":"Only the Play recipe has physical authority. Rear stair, ladder and blocked-looking passage are decorative. Static probe expectations are checked against actual native readback in qualification.",
		"probes":[
			{"id":"real-platform","point":[160,214],"materials":{"play":58,"scripted":0}},
			{"id":"false-platform-extension","point":[350,214],"materials":{"play":0,"scripted":58}},
			{"id":"apparently-blocked-passage","point":[560,360],"materials":{"play":0,"scripted":58}},
			{"id":"decorative-step","point":[798,260],"materials":{"play":0,"scripted":58}},
			{"id":"decorative-ladder","point":[890,180],"materials":{"play":0,"effects":58}},
			{"id":"real-ground","point":[420,694],"materials":{"play":58}},
			{"id":"water-basin","point":[130,640],"materials":{"play":3}},
			{"id":"falling-sand","point":[550,575],"materials":{"play":2}}]}


static func make(policy: PackedInt32Array) -> Dictionary:
	var setup := Setup.fresh(policy,EXTENT)
	setup.edits = [
		[20,20,984,8,58],[20,20,8,700,58],[996,20,8,700,58],[20,712,984,8,58],
		[64,690,896,8,58],
		[80,210,180,8,58],[80,210,8,124,58],[240,210,8,124,58],
		[480,288,180,8,58],[480,288,8,160,58],[652,288,8,160,58],
		[70,580,8,110,58],[70,682,180,8,58],[242,580,8,110,58],
		[80,620,156,62,3],
		[500,664,136,8,58],[500,630,8,42,58],[628,630,8,42,58],
		[532,562,40,30,2],
		[700,520,160,8,58],[700,520,8,72,58],[852,520,8,72,58]]
	setup.material = 58
	setup.brush = 2
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0),1,Vector2(410,600))]
	setup.selected = 1
	setup.next_id = 2
	var document := Document.default_document(EXTENT)
	document.presentation.enabled = true
	document.presentation.mode = "stack"
	document.presentation.parallax_strength = 0.0
	document.presentation.fog_strength = 0.0
	var rear: Array = [
		[260,210,208,8,58],[460,210,8,124,58],
		[488,296,164,144,58],
		[742,300,120,8,58],[766,280,96,8,58],[790,260,72,8,58],[814,240,48,8,58],
		[862,240,8,124,58],
		[288,480,8,184,58],[460,480,8,184,58],[288,480,180,8,58],[288,656,180,8,58]]
	# Same-material repeated beams deliberately compete with physical ledges.
	for y: int in range(88,180,16): rear.append([64,y,620,2,58])
	for x: int in range(92,688,32): rear.append([x,88,2,92,58])
	for y: int in range(498,650,14): rear.append([298,y,160,2,58])
	var effects: Array = [[884,100,4,220,58],[914,100,4,220,58]]
	for y: int in range(108,318,18): effects.append([884,y,34,3,58])
	# Identical material highlights defeat a colour-only classification rule.
	for x: int in range(312,458,16): effects.append([x,512,3,116,58])
	var background: Array = [[44,48,656,8,58],[44,48,8,410,58],[692,48,8,410,58]]
	for x: int in range(64,976,64):
		background.append([x,52,6,620,58])
		background.append([x,452,40,4,58])
	for plane: Dictionary in document.planes:
		match str(plane.id):
			"scripted":
				plane.rectangles = rear
				plane.depth = 0.0
				plane.opacity = 1.0
			"effects":
				plane.rectangles = effects
				plane.depth = 0.0
				plane.opacity = 1.0
			"background":
				plane.rectangles = background
				plane.depth = 0.0
				plane.opacity = 1.0
	var error := Setup.validate(setup)
	if not error.is_empty(): return {"error":"Optics fixture Play recipe: " + error}
	error = Document.validate(document)
	if not error.is_empty(): return {"error":"Optics fixture decoration: " + error}
	var info := metadata()
	return {"id":ID,"title":info.title,"description":info.description,
		"setup":setup,"document":document,"source_metadata":info}
