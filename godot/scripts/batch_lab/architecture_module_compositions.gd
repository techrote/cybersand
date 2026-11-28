extends RefCounted
## Orthographic compositions of actual library modules. This factory never builds
## or admits geometry: every reference pins the caller's harvested module hash.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const NAMES := ["Modular assembly hangar","Modular service stack","Modular transfer viaduct"]
const IDS := ["modular-assembly-hangar","modular-service-stack","modular-transfer-viaduct"]
const REQUIRED := ["buttressed-column","warren-beam","ribbed-floor","service-doorway",
	"return-pipe","suspended-gallery","machine-housing","stepped-transition"]

static func families() -> Array[String]:
	var output: Array[String] = []
	output.assign(NAMES)
	return output

static func extent(family: String) -> Vector2i:
	return Vector2i(384,256) if family in [NAMES[1],IDS[1]] else Vector2i(480,320)

static func _place(output: Array, library: RefCounted, identity: String, x: int, y: int,
	origin: Vector2i, transform := "identity", seed := 0, keep := 1.0) -> void:
	var module: Dictionary = library.get_module(identity)
	var placement := {"origin":[origin.x+x,origin.y+y],"transform":transform,"palette":{}}
	if keep<1.0: placement["variation"] = {"seed":seed,"keep_fraction":keep}
	output.append({"module_id":identity,"module_sha256":module.content_sha256,"placement":placement})

static func _shift_rects(rectangles: Array, origin: Vector2i) -> Array:
	var result: Array = []
	for box: Array in rectangles:
		result.append([origin.x+int(box[0]),origin.y+int(box[1]),int(box[2]),int(box[3])])
	return result

static func plans(library: RefCounted, origin := Vector2i(16,16), seed := 44013) -> Array:
	var result: Array = []
	for family: String in NAMES:
		var candidate := plan(family,library,origin,seed)
		if candidate.is_empty(): return []
		result.append(candidate)
	return result

static func plan(family: String, library: RefCounted, origin := Vector2i(16,16), seed := 44013) -> Dictionary:
	var index := NAMES.find(family)
	if index<0: index = IDS.find(family)
	if index<0 or library==null: return {}
	for identity: String in REQUIRED:
		if library.get_module(identity).is_empty(): return {}
	var structure: Array = []
	var services: Array = []
	var detail: Array = []
	var clearances: Array = []
	match index:
		0:
			# The broad central void is deliberately retained. Cap-to-cap column
			# stacks meet the roof and foundation; equipment rests below the void.
			for i: int in 7:
				_place(structure,library,"ribbed-floor",16+64*i,276,origin)
				_place(structure,library,"warren-beam",16+64*i,24,origin)
			for x: int in [24,432]:
				for y: int in [40,88,136,184,232]:
					_place(structure,library,"buttressed-column",x,y,origin)
			for x: int in [54,390]:
				_place(services,library,"service-doorway",x,228,origin)
			for x: int in [120,216,312]:
				_place(services,library,"return-pipe",x,40,origin)
			for i: int in 3:
				_place(detail,library,"machine-housing",112+96*i,248,origin,
					"mirror_x" if i%2 else "identity")
			clearances = [[48,128,384,100]]
		1:
			# Three decks divide the tall frame. Suspended galleries occupy the
			# upper service zones; full-width passage bands stay visibly open.
			for x: int in [0,368]:
				for y: int in [32,80,128,176]:
					_place(structure,library,"buttressed-column",x,y,origin)
			for i: int in 6:
				_place(structure,library,"warren-beam",64*i,16,origin)
				for y: int in [64,144,224]:
					_place(structure,library,"ribbed-floor",64*i,y,origin)
			for y: int in [72,152]:
				for x: int in [48,144,240]:
					_place(services,library,"suspended-gallery",x,y,origin)
			for i: int in 3:
				_place(detail,library,"machine-housing",320,36+80*i,origin,
					"mirror_x" if i%2 else "identity")
			clearances = [[32,40,272,20],[32,120,272,20],[32,200,272,20]]
		2:
			# The long deck bridges four paired supports. Opposed step modules
			# frame the upper route; pipe returns and housings sit below the deck.
			for i: int in 7:
				_place(structure,library,"ribbed-floor",16+64*i,268,origin)
			for x: int in [32,160,288,416]:
				for y: int in [176,224]:
					_place(structure,library,"buttressed-column",x,y,origin)
			for i: int in 7:
				_place(services,library,"warren-beam",16+64*i,152,origin)
				_place(services,library,"ribbed-floor",16+64*i,168,origin)
			_place(services,library,"stepped-transition",16,136,origin)
			_place(services,library,"stepped-transition",416,136,origin,"mirror_x")
			for i: int in 3:
				_place(detail,library,"return-pipe",80+128*i,176,origin,"mirror_x" if i%2 else "identity")
				_place(detail,library,"machine-housing",112+128*i,240,origin,
					"mirror_x" if i%2 else "identity")
			clearances = [[80,128,320,24]]
	var stages: Array = []
	var descriptions := ["Repeat load-path modules into a primary frame.",
		"Connect service, span or access modules to the established frame.",
		"Place bounded equipment and pipework without filling the reserved passages."]
	var layers: Array = [structure,services,detail]
	for i: int in 3:
		var stage := Compiler.stage_defaults(IDS[index]+"-"+str(i+1),Rect2i(origin,extent(family)))
		stage.intent = descriptions[i]
		stage.modules = layers[i]
		stage.materials = [0,7,28,58]
		stage.clearances = _shift_rects(clearances,origin)
		stage.depends_on = [] if i==0 else [stages[i-1].id]
		stage.expected_effects = "%d pinned harvested module placements; host computes the exact net material patch." % layers[i].size()
		stage.uncertainty = ["Module metadata states authored intent; physical stability and actor traversal require owner inspection.",
			"Reserved rectangular space is a geometric clearance, not a complete route or gameplay certificate."]
		stages.append(stage)
	return {"format":Compiler.FORMAT,"id":IDS[index],"name":NAMES[index],"intent":NAMES[index]+" assembled from reusable native structural parts.",
		"origin":[origin.x,origin.y],"extent":[extent(family).x,extent(family).y],"seed":seed,"stages":stages,
		"provenance":{"kind":"typed-native-module-composition","source":"Actual caller library identities; no imported artwork or model inference.",
			"native_construction_status":"proposed","model_calls":0},
		"scope":"True orthographic side elevation. Approval and actual native readback are required for every stage."}
