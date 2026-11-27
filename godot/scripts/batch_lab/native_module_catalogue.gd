extends RefCounted
## Forty curated source recipes: the original eight are retained exactly and
## thirty-two distinct v2 parts add authored occupied-face connection contracts.
## Recipes are not modules and never carry current-session native qualification.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Legacy = preload("res://scripts/batch_lab/native_module_examples.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const CATALOGUE_ID := "cybersand-curated-parts-2026-11-v2"
const MATERIALS := [0,7,28,58]

static func box(x: int, y: int, width: int, height: int, material := 58) -> Dictionary:
	return Legacy.box(x,y,width,height,material)

static func line(identity: String, start: Array, end: Array, facing: Array, tag: String, role: String,
	policy := "full", minimum := 0, capacity := 1, required := false) -> Dictionary:
	var length := absi(int(end[0])-int(start[0]))+absi(int(end[1])-int(start[1]))+1
	return {"id":identity,"kind":"line","point":start,"end":end,"facing":facing,
		"compatibility":[tag],"required":required,"source":"authored","role":role,"approach":"face",
		"polarity":"neutral","capacity":capacity,
		"contact":{"policy":policy,"minimum_cells":length if minimum==0 else minimum,"tolerance":0}}

static func part(identity: String, name: String, kind: String, size: Array, operations: Array,
	attachments: Array, intent: String, tags: Array, clearances: Array = [], variable: Array = [], fixed: Array = [],
	transforms: Array = Module.TRANSFORMS) -> Dictionary:
	return {"id":identity,"name":name,"extent":[128,128],"harvest_region":[0,0,size[0],size[1]],
		"operations":operations,"native_readback_verified":false,"catalogue_id":CATALOGUE_ID,
		"construction_intent":intent,"distinct_geometry":true,
		"metadata":{"format":Module.FORMAT_V2,"id":identity,"name":name,"part_type":kind,
			"tags":["curated-v2","orthographic",kind]+tags,"anchor":[0,size[1]-1],
			"allowed_transforms":transforms,"attachments":attachments,"clearances":clearances,
			"protected_regions":[],"fixed_regions":fixed,"variation_regions":variable,"design_card_ids":[],
			"roles":[{"name":"structure","material_ids":[58],"compatible_materials":[58,28],"source":"authored"},
				{"name":"service","material_ids":[28],"compatible_materials":[28],"source":"authored"},
				{"name":"infill","material_ids":[7],"compatible_materials":[7,28],"source":"authored"}],
			"provenance":{"kind":"unexecuted-curated-typed-recipe","catalogue_id":CATALOGUE_ID,
				"architectural_intent":intent,"semantic_scope":"Authored contact and material roles; no physical support certificate."}}}

static func _deck_west(y: int) -> Dictionary:
	return line("west-deck",[0,y],[0,y+3],[-1,0],"deck-4","floor")

static func _deck_east(width: int, y: int) -> Dictionary:
	return line("east-deck",[width-1,y],[width-1,y+3],[1,0],"deck-4","floor")

static func _pipe(identity: String, point: Array, end: Array, facing: Array) -> Dictionary:
	return line(identity,point,end,facing,"pipe-4","pipe")

static func recipes(include_legacy := true) -> Array:
	var result: Array = Legacy.recipes() if include_legacy else []
	_foundations(result)
	_spans(result)
	_floors(result)
	_envelopes(result)
	_access(result)
	_services(result)
	_detail(result)
	return result

static func _foundations(result: Array) -> void:
	result.append(part("stepped-foundation","Stepped bearing foundation","column_support",[48,16],
		[box(12,0,24,4),box(6,4,36,4),box(0,8,48,8)],
		[line("bearing",[12,0],[35,0],[0,-1],"bearing-24","support"),line("ground",[0,15],[47,15],[0,1],"foundation-48","support")],
		"A broad three-course footing receives a narrower 24-cell pier.",["foundation","bearing","large-footprint"]))
	result.append(part("tapered-pier","Tapered monumental pier","column_support",[24,64],
		[box(0,0,24,4),box(8,4,8,20),box(6,24,12,16),box(3,40,18,16),box(0,56,24,8)],
		[line("head",[0,0],[23,0],[0,-1],"bearing-24","support"),line("foot",[0,63],[23,63],[0,1],"bearing-24","support")],
		"A stepped taper gives a tall support a readable crown, shaft and base.",["pier","vertical","monumental"]))
	result.append(part("offset-buttress","Offset side buttress","column_support",[40,56],
		[box(0,0,8,56),box(8,16,8,40),box(16,28,8,28),box(24,40,8,16),box(0,48,40,8)],
		[line("wall",[0,0],[0,55],[-1,0],"wall-56","wall"),line("foot",[0,55],[39,55],[0,1],"foundation-40","support")],
		"An asymmetric mass steps away from a tall wall into a broad footing.",["buttress","asymmetric","transition"]))
	var fork: Array = [box(0,0,40,4),box(12,32,16,32)]
	for y: int in range(4,33):
		var inset := (y-4)/3
		fork.append(box(inset,y,5,1,28)); fork.append(box(35-inset,y,5,1,28))
	result.append(part("forked-column","Forked service column","column_support",[40,64],fork,
		[line("crown",[0,0],[39,0],[0,-1],"bearing-40","support"),line("foot",[12,63],[27,63],[0,1],"bearing-16","support")],
		"A narrow pedestal splits into two face-connected branches below a wide crown.",["fork","splayed-support","industrial"],[[15,6,10,20]]))

static func _spans(result: Array) -> void:
	var girder: Array = [box(0,0,96,4),box(0,20,96,4),box(0,4,4,16),box(92,4,4,16)]
	for x: int in [24,48,72]: girder.append(box(x,4,3,16,28))
	result.append(part("deep-box-girder","Deep cellular box girder","beam_truss",[96,24],girder,
		[_deck_west(20),_deck_east(96,20),line("west-bearing",[0,23],[15,23],[0,1],"bearing-16","support"),
			line("east-bearing",[80,23],[95,23],[0,1],"bearing-16","support")],
		"A deep hollow span separates repeated cells with narrow service webs.",["long-span","cellular","industrial"],[[4,4,20,16],[27,4,21,16],[51,4,21,16],[75,4,17,16]]))
	var truss: Array = [box(0,0,96,4),box(0,28,96,4)]
	for bay: int in 4:
		truss.append(box(bay*24,4,3,24,28))
		for step: int in 24:
			truss.append(box(bay*24+step,4+step if bay%2==0 else 27-step,2 if step<23 else 1,2,28))
	result.append(part("alternating-lattice-truss","Alternating deep lattice truss","beam_truss",[96,32],truss,
		[_deck_west(28),_deck_east(96,28),line("west-bearing",[0,31],[15,31],[0,1],"bearing-16","support"),
			line("east-bearing",[80,31],[95,31],[0,1],"bearing-16","support")],
		"A long four-bay truss alternates diagonals with visible upright boundaries.",["truss","repetition","deep-span"]))
	var arch: Array = [box(0,44,8,8),box(88,44,8,8),box(40,0,16,6)]
	for x: int in 96:
		var normalized := absf(float(x)-47.5)/47.5
		var y := 3+int(round(44.0*normalized*normalized))
		arch.append(box(x,y,1,5,28))
	result.append(part("parabolic-arch-rib","Parabolic arch rib","beam_truss",[96,52],arch,
		[line("west-foot",[0,51],[7,51],[0,1],"bearing-8","support"),line("east-foot",[88,51],[95,51],[0,1],"bearing-8","support"),
			line("crown",[40,0],[55,0],[0,-1],"bearing-16","support")],
		"A continuous curved rib encloses a large clear arch without perspective geometry.",["arch","curved","macro-void"],[[24,28,48,24]]))
	var bracket: Array = [box(0,0,48,4),box(0,4,4,36)]
	for step: int in 39: bracket.append(box(step,38-step,3,2,28))
	result.append(part("cantilever-bracket","Triangulated cantilever bracket","beam_truss",[48,40],bracket,
		[line("wall-mount",[0,0],[0,31],[-1,0],"wall-32","wall"),_deck_east(48,0)],
		"A side-mounted triangular bracket supports an offset deck edge.",["cantilever","asymmetric","wall-mount"],[[32,20,16,20]]))

static func _floors(result: Array) -> void:
	result.append(part("double-deck-frame","Double-deck passage frame","floor_ceiling",[80,32],
		[box(0,0,80,4),box(0,28,80,4),box(0,4,4,24),box(76,4,4,24)],
		[_deck_west(28),_deck_east(80,28),line("roof-mount",[4,0],[75,0],[0,-1],"mount-rail","mount","overlap",4,4)],
		"An upper and lower deck bound an explicit empty service passage.",["double-deck","passage","repetition"],[[4,4,72,24]]))
	result.append(part("ceiling-service-tray","Ceiling service tray","floor_ceiling",[80,20],
		[box(0,0,80,4),box(4,4,3,13,28),box(73,4,3,13,28),box(0,14,80,3,28),box(4,17,3,3,28),box(73,17,3,3,28)],
		[_deck_west(0),_deck_east(80,0),line("roof-mount",[0,0],[79,0],[0,-1],"mount-rail","mount","overlap",4,4)],
		"A shallow beam carries a suspended service rail while preserving its intervening space.",["ceiling","suspended","service"],[[8,4,64,10]]))
	var ramp: Array = []; var ramp_clearances: Array = []
	for step: int in 8:
		var y := 28-step*4
		ramp.append(box(step*8,y,8,4))
		if step>0: ramp.append(box(step*8-1,y,2,8,28))
		if y>0: ramp_clearances.append([step*8+1,0,6,y])
	result.append(part("shallow-stair-ramp","Shallow stepped access ramp","irregular_transition",[64,32],ramp,
		[_deck_west(28),_deck_east(64,0)],"Eight shallow connected steps change deck height across a long run.",
		["ramp","steps","level-change"],ramp_clearances))
	result.append(part("offset-half-landing","Offset half landing","irregular_transition",[48,32],
		[box(0,28,24,4),box(22,12,4,20),box(24,12,24,4),box(24,0,24,3,28),box(44,3,2,9,28)],
		[_deck_west(28),_deck_east(48,12)],
		"Two offset open decks join through a short riser and suspended upper landing.",["landing","asymmetric","open-underneath"],[[26,16,22,16],[0,0,22,28]]))

static func _envelopes(result: Array) -> void:
	result.append(part("paired-window-facade","Paired window facade","wall_facade",[64,64],
		[box(0,0,64,6),box(0,58,64,6),box(0,6,6,52),box(58,6,6,52),box(29,6,6,52),box(6,30,23,4,28),box(35,30,23,4,28)],
		[line("west-wall",[0,0],[0,63],[-1,0],"wall-64","wall"),line("east-wall",[63,0],[63,63],[1,0],"wall-64","wall")],
		"A two-bay facade distinguishes heavy jambs from finer cross-members and four clear lights.",["facade","window","repetition"],
		[[6,6,23,24],[6,34,23,24],[35,6,23,24],[35,34,23,24]]))
	result.append(part("tall-blast-door","Tall open blast-door frame","window_door",[48,80],
		[box(0,0,48,8),box(0,8,6,72),box(42,8,6,72),box(6,8,3,12,28),box(39,8,3,12,28)],
		[line("west-jamb",[0,0],[0,79],[-1,0],"wall-80","wall"),line("east-jamb",[47,0],[47,79],[1,0],"wall-80","wall"),
			line("west-foot",[0,79],[5,79],[0,1],"bearing-6","support"),line("east-foot",[42,79],[47,79],[0,1],"bearing-6","support")],
		"A tall vehicle-scale opening has a deep lintel and thick side jambs without a painted door leaf.",["door","tall-opening","hangar"],[[9,8,30,72],[6,20,3,60],[39,20,3,60]]))
	var shutter: Array = [box(0,0,48,4),box(0,44,48,4),box(0,4,4,40),box(44,4,4,40)]
	for y: int in range(8,41,8): shutter.append(box(4,y,40,3,28))
	result.append(part("louvered-shutter-bay","Louvered shutter bay","wall_facade",[48,48],shutter,
		[line("west-jamb",[0,0],[0,47],[-1,0],"wall-48","wall"),line("east-jamb",[47,0],[47,47],[1,0],"wall-48","wall")],
		"Five narrow louvers give a bounded machinery wall a different density from an open window.",["louver","infill","mechanical"],[],[[4,4,40,40]],
		[[0,0,48,4],[0,44,48,4],[0,4,4,40],[44,4,4,40]]))
	result.append(part("narrow-pressure-bulkhead","Narrow pressure bulkhead","window_door",[24,64],
		[box(0,0,24,6),box(0,58,24,6),box(0,6,4,52),box(20,6,4,52),box(4,6,4,8,28),box(16,6,4,8,28)],
		[line("west-wall",[0,0],[0,63],[-1,0],"wall-64","wall"),line("east-wall",[23,0],[23,63],[1,0],"wall-64","wall")],
		"A compact framed opening includes a visible sill and reinforced upper corners.",["bulkhead","narrow-opening","service"],[[8,6,8,52],[4,14,4,44],[16,14,4,44]]))

static func _access(result: Array) -> void:
	var viaduct: Array = [box(0,0,96,8),box(0,8,12,56),box(84,8,12,56)]
	for x: int in range(12,84):
		var normalized := absf(float(x)-47.5)/35.5
		var depth := 10+int(round(36.0*normalized*normalized))
		viaduct.append(box(x,8,1,depth))
	result.append(part("vaulted-viaduct","Vaulted masonry viaduct","viaduct_segment",[96,64],viaduct,
		[_deck_west(0),_deck_east(96,0),line("west-foot",[0,63],[11,63],[0,1],"bearing-12","support"),
			line("east-foot",[84,63],[95,63],[0,1],"bearing-12","support")],
		"A heavy continuous deck opens into a deep arched void between two piers.",["bridge","arch","macro-void"],[[28,40,40,24]]))
	result.append(part("asymmetric-cable-gallery","Asymmetric cable gallery","service_gallery",[96,32],
		[box(0,28,96,4),box(0,0,96,3,28),box(8,3,2,25,28),box(78,3,2,25,28),box(80,12,16,3,28),box(94,3,2,9,28)],
		[_deck_west(28),_deck_east(96,28),line("roof-rail",[0,0],[95,0],[0,-1],"mount-rail","mount","overlap",4,4)],
		"Long clear gallery space is balanced by a compact service pocket at one end.",["gallery","asymmetric","suspended"],[[10,3,68,25],[80,15,16,13]]))
	var ladder: Array = [box(0,0,3,64,28),box(13,0,3,64,28)]
	for y: int in range(4,61,8): ladder.append(box(3,y,10,2,28))
	result.append(part("service-ladder","Service access ladder","service_gallery",[16,64],ladder,
		[line("west-rail",[0,0],[0,63],[-1,0],"mount-rail","mount","overlap",4,4),
			line("east-rail",[15,0],[15,63],[1,0],"mount-rail","mount","overlap",4,4)],
		"Two continuous rails and repeated rungs form a narrow service-access motif; actor climbing is not asserted.",["ladder","vertical-service","repetition"]))
	var diagonal: Array = [box(0,40,8,8),box(56,0,8,8)]
	for step: int in 56:
		var y := 40-int(floor(float(step)*40.0/55.0))
		diagonal.append(box(step+4,y,2,5,28))
	result.append(part("diagonal-transfer-spine","Diagonal transfer spine","irregular_transition",[64,48],diagonal,
		[_deck_west(40),_deck_east(64,0)],
		"A narrow sloping infrastructure spine links unequal landing elevations without filling its underside.",["diagonal","transfer","asymmetric"],[[0,0,16,28],[44,24,20,24]]))

static func _services(result: Array) -> void:
	result.append(part("pipe-elbow","Square service elbow","pipework",[32,32],
		[box(0,0,32,4,28),box(28,4,4,28,28)],
		[_pipe("inlet",[0,0],[0,3],[-1,0]),_pipe("outlet",[28,31],[31,31],[0,1])],
		"A thick right-angle return joins horizontal and vertical service runs.",["pipe","elbow","connector"],[[0,4,28,28]]))
	result.append(part("pipe-tee","Three-way service tee","pipework",[48,32],
		[box(0,14,48,4,28),box(22,0,4,14,28)],
		[_pipe("west",[0,14],[0,17],[-1,0]),_pipe("east",[47,14],[47,17],[1,0]),_pipe("branch",[22,0],[25,0],[0,-1])],
		"Three distinct face ports split one horizontal service spine into a vertical branch.",["pipe","junction","three-way"]))
	result.append(part("pipe-cross","Four-way service crossing","pipework",[40,40],
		[box(0,18,40,4,28),box(18,0,4,40,28)],
		[_pipe("west",[0,18],[0,21],[-1,0]),_pipe("east",[39,18],[39,21],[1,0]),_pipe("north",[18,0],[21,0],[0,-1]),_pipe("south",[18,39],[21,39],[0,1])],
		"A physical four-port junction declares separate exclusive connectors instead of reusing one socket.",["pipe","junction","four-way"]))
	result.append(part("valve-chamber","Service valve chamber","mechanical_housing",[48,40],
		[box(0,18,48,4,28),box(12,8,24,3,28),box(12,29,24,3,28),box(12,11,3,18,28),box(33,11,3,18,28),box(22,0,4,8,28),box(16,0,16,3,28)],
		[_pipe("west",[0,18],[0,21],[-1,0]),_pipe("east",[47,18],[47,21],[1,0])],
		"A framed in-line chamber and top spindle distinguish a valve assembly from plain pipework.",["valve","service","mechanical"],[[15,11,18,7],[15,22,18,7]]))
	result.append(part("offset-manifold","Offset three-branch manifold","pipework",[64,48],
		[box(0,22,28,4,28),box(24,4,4,40,28),box(28,4,36,4,28),box(28,22,36,4,28),box(28,40,36,4,28)],
		[_pipe("feed",[0,22],[0,25],[-1,0]),_pipe("upper",[63,4],[63,7],[1,0]),_pipe("middle",[63,22],[63,25],[1,0]),_pipe("lower",[63,40],[63,43],[1,0])],
		"An offset header feeds three spaced service branches with independent ports.",["manifold","asymmetric","branching"],[[28,8,36,14],[28,26,36,14]]))
	result.append(part("pipe-expansion-loop","Raised expansion loop","pipework",[64,48],
		[box(0,28,16,4,28),box(12,4,4,24,28),box(16,4,32,4,28),box(48,4,4,28,28),box(52,28,12,4,28)],
		[_pipe("west",[0,28],[0,31],[-1,0]),_pipe("east",[63,28],[63,31],[1,0])],
		"A raised rectangular loop introduces a clear service bypass between aligned ports.",["pipe","bypass","negative-space"],[[16,8,32,40]]))
	result.append(part("vertical-service-stack","Triple vertical service stack","pipework",[24,80],
		[box(0,36,24,3,58),box(0,0,24,4,28),box(0,76,24,4,28),box(2,4,4,72,28),box(10,4,4,72,28),box(18,4,4,72,28)],
		[line("head",[0,0],[23,0],[0,-1],"service-header-24","pipe"),line("foot",[0,79],[23,79],[0,1],"service-header-24","pipe")],
		"Three vertical risers share broad top and bottom headers and a central support strap.",["riser","parallel-services","tall"]))
	var tray: Array = []
	for x: int in [8,32,56,72]: tray.append(box(x,0,2,16,58))
	tray.append(box(0,2,80,4,28)); tray.append(box(0,10,80,4,28))
	result.append(part("twin-pipe-tray","Twin parallel pipe tray","pipework",[80,16],tray,
		[_pipe("west-upper",[0,2],[0,5],[-1,0]),_pipe("east-upper",[79,2],[79,5],[1,0]),
			_pipe("west-lower",[0,10],[0,13],[-1,0]),_pipe("east-lower",[79,10],[79,13],[1,0])],
		"Two parallel lines remain individually addressable while repeated straps tie the assembly together.",["parallel-services","tray","repetition"]))

static func _detail(result: Array) -> void:
	result.append(part("pump-on-plinth","Offset pump on plinth","mechanical_housing",[56,40],
		[box(0,32,56,8),box(8,8,28,4,28),box(8,28,28,4,28),box(8,12,4,16,28),box(32,12,4,16,28),box(36,18,20,4,28),box(16,0,12,8,28)],
		[line("base",[0,39],[55,39],[0,1],"equipment-56","equipment"),_pipe("outlet",[55,18],[55,21],[1,0])],
		"A machine enclosure sits on a broad base, with an offset outlet and distinct top housing.",["pump","asymmetric","mounted-equipment"],[[12,12,20,16]]))
	var rack: Array = [box(0,0,32,4,28),box(0,52,32,4,28),box(0,4,4,48,28),box(28,4,4,48,28)]
	for y: int in [16,32,48]: rack.append(box(4,y,24,3,28))
	for y: int in [5,21,37]: rack.append(box(4,y,12,10,7))
	result.append(part("instrument-rack","Open instrument rack","mechanical_housing",[32,56],rack,
		[line("base",[0,55],[31,55],[0,1],"equipment-32","equipment"),line("wall-mount",[0,0],[0,55],[-1,0],"mount-rail","mount","overlap",4,4)],
		"Three shelves alternate dense instrument blocks with visible empty service access.",["rack","instrument","local-detail"],
		[[16,4,12,12],[16,19,12,13],[16,35,12,13]],[[4,5,12,10],[4,21,12,10],[4,37,12,10]],
		[[0,0,32,4],[0,52,32,4],[0,4,4,48],[28,4,4,48],[4,16,24,3],[4,32,24,3],[4,48,24,3]]))
	var grille: Array = [box(0,0,48,3,28),box(0,21,48,3,28),box(0,3,3,18,28),box(45,3,3,18,28)]
	for x: int in range(6,43,6): grille.append(box(x,3,2,18,7))
	result.append(part("framed-vent-grille","Framed vent grille","greeble_cluster",[48,24],grille,
		[line("mount",[0,0],[47,0],[0,-1],"mount-rail","mount","overlap",4,4)],
		"A bounded field of thin fins fits a clearly framed mechanical surface.",["vent","grille","local-detail"],[],[[3,3,42,18]],
		[[0,0,48,3],[0,21,48,3],[0,3,3,18],[45,3,3,18]]))
	result.append(part("fractured-wall-transition","Fractured wall-to-deck transition","irregular_transition",[64,64],
		[box(0,0,20,56),box(20,0,8,16),box(20,16,16,12),box(20,28,10,16),box(20,44,20,12),box(0,56,64,8),
			box(28,8,8,4,28),box(36,20,10,3,28),box(30,34,8,4,28),box(40,48,12,3,28)],
		[line("wall",[0,0],[0,63],[-1,0],"wall-64","wall"),_deck_east(64,60)],
		"An irregular structural shoulder resolves a tall wall into a deck while expendable edge fragments carry local wear.",["irregular","broken-edge","asymmetric"],
		[[46,0,18,44]],[[28,8,8,4],[36,20,10,3],[30,34,8,4],[40,48,12,3],[28,44,12,12]],[[0,0,20,56],[0,56,64,8]]))

static func descriptions() -> Array:
	var result: Array = []
	for recipe: Dictionary in recipes():
		result.append({"id":recipe.id,"name":recipe.name,"part_type":recipe.metadata.part_type,
			"extent":[recipe.harvest_region[2],recipe.harvest_region[3]],"format":recipe.metadata.get("format",Module.FORMAT),
			"tags":recipe.metadata.tags.duplicate(),"construction_intent":recipe.get("construction_intent","Preserved original starter recipe."),
			"attachments":recipe.metadata.attachments.duplicate(true),"native_readback_verified":false,
			"scope":"Unexecuted typed source definition; construct and harvest before native qualification."})
	return result

static func template_library(include_legacy := true) -> Dictionary:
	# A pure bootstrap for planning/offline fixtures. These projected documents
	# deliberately have no volatile native qualification; they are not a shortcut
	# around the private native Build-and-Harvest pathway.
	var library := Library.new()
	var definitions := recipes(include_legacy)
	for recipe: Dictionary in definitions:
		var extent := Vector2i(int(recipe.extent[0]),int(recipe.extent[1]))
		var cells := PackedByteArray(); cells.resize(extent.x*extent.y*2)
		for operation: Dictionary in recipe.operations:
			if operation.shape!="rectangle" or int(operation.x0)<0 or int(operation.y0)<0 \
				or int(operation.x1)>=extent.x or int(operation.y1)>=extent.y:
				return Module.failure("Curated source definition has an invalid bounded rectangle.")
			for y: int in range(int(operation.y0),int(operation.y1)+1):
				for x: int in range(int(operation.x0),int(operation.x1)+1):
					var old := cells.decode_u16((y*extent.x+x)*2)
					if old not in [0,58] and old!=int(operation.material): return Module.failure("Curated source ordering violates native material replacement permission.")
					cells.encode_u16((y*extent.x+x)*2,int(operation.material))
		var metadata: Dictionary = recipe.metadata.duplicate(true)
		metadata["provenance"] = {"kind":"unexecuted-typed-recipe-projection","catalogue_id":CATALOGUE_ID,
			"native_construction_status":"not-executed","scope":"Pure code-owned proposal geometry; no native receipt or current-session observation."}
		metadata["recipe"] = {"kind":"curated-source-program","catalogue_id":CATALOGUE_ID,"extent":recipe.extent.duplicate(),
			"operations":recipe.operations.duplicate(true),"recipe_sha256":Module.digest(Module.json_bytes(recipe))}
		var projected := Module.harvest(cells,extent,Module.rect(recipe.harvest_region),metadata)
		if not projected.ok: return projected
		var added := library.add(projected.module)
		if not added.ok: return added
	return {"ok":true,"library":library,"catalogue_id":CATALOGUE_ID,"recipe_sha256":Module.digest(Module.json_bytes(definitions)),
		"count":library.count(),"native_readback_verified":false,"zero_writes":true,
		"scope":"Unexecuted pure source projections for planning. Build and harvest through the native executor before claiming native-qualified parts."}
