extends RefCounted
## Typed source recipes, not harvested or native-qualified module documents.
## Build each in a real Batch Lab tile, then harvest its declared local region.
const Module = preload("res://scripts/batch_lab/native_module.gd")

static func box(x: int, y: int, width: int, height: int, material: int) -> Dictionary:
	return {"shape":"rectangle","x0":x,"y0":y,"x1":x+width-1,"y1":y+height-1,"material":material}

static func socket(identity: String, point: Array, facing: Array, compatible: String) -> Dictionary:
	return {"id":identity,"kind":"socket","point":point,"facing":facing,
		"compatibility":[compatible],"required":false,"source":"authored"}

static func part(identity: String, name: String, kind: String, extent: Array, operations: Array,
	attachments: Array, clearances: Array = [], variable: Array = [], transforms: Array = ["identity","mirror_x"]) -> Dictionary:
	return {"id":identity,"name":name,"extent":[64,64],"harvest_region":[0,0,extent[0],extent[1]],
		"operations":operations,"native_readback_verified":false,
		"metadata":{"id":identity,"name":name,"tags":["industrial","structural-parts",kind],"part_type":kind,
			"anchor":[0,extent[1]-1],"allowed_transforms":transforms,"attachments":attachments,
			"clearances":clearances,"variation_regions":variable,"design_card_ids":[],
			"roles":[{"name":"structure","material_ids":[58],"compatible_materials":[58,28],"source":"authored"},
				{"name":"service","material_ids":[28],"compatible_materials":[28],"source":"authored"},
				{"name":"timber","material_ids":[7],"compatible_materials":[7,28],"source":"authored"}],
			"provenance":{"kind":"unexecuted-typed-recipe","authoring_scope":"Explicit orthographic part intent; no physical support certificate."}}}

static func recipes() -> Array:
	var result: Array = []
	result.append(part("buttressed-column","Buttressed service column","column_support",[16,48],
		[box(0,0,16,4,58),box(6,4,4,40,28),box(0,44,16,4,58)],
		[socket("head",[8,0],[0,-1],"support"),socket("foot",[8,47],[0,1],"support")]))
	var truss: Array = [box(0,0,64,3,58),box(0,13,64,3,58)]
	for segment: int in 4:
		for step: int in 10:
			var x := segment*16+3+step
			var y := 3+step if segment%2==0 else 12-step
			# A two-cell staircase keeps the diagonal face-connected at native
			# cell resolution; a one-pixel diagonal touches only at corners.
			truss.append(box(x,y,2,1,28))
	result.append(part("warren-beam","Warren service beam","beam_truss",[64,16],truss,
		[socket("west",[0,14],[-1,0],"beam"),socket("east",[63,14],[1,0],"beam")]))
	result.append(part("ribbed-floor","Ribbed floor section","floor_ceiling",[64,8],
		[box(0,4,64,4,58),box(4,0,4,4,28),box(20,0,4,4,28),box(36,0,4,4,28),box(52,0,4,4,28)],
		[socket("west",[0,6],[-1,0],"floor"),socket("east",[63,6],[1,0],"floor")]))
	result.append(part("service-doorway","Open service doorway","window_door",[32,48],
		[box(0,0,32,4,58),box(0,4,4,44,58),box(28,4,4,44,58)],
		[socket("west-foot",[1,47],[0,1],"support"),socket("east-foot",[30,47],[0,1],"support")],[[4,4,24,44]]))
	result.append(part("return-pipe","Service return pipe","pipework",[48,32],
		[box(0,0,48,3,28),box(45,3,3,26,28),box(0,29,48,3,28)],
		[socket("inlet",[0,1],[-1,0],"pipe"),socket("outlet",[0,30],[-1,0],"pipe")],[[0,3,45,26]],[],Module.TRANSFORMS))
	result.append(part("suspended-gallery","Suspended service gallery","service_gallery",[64,24],
		[box(0,20,64,4,58),box(0,0,64,3,28),box(8,3,2,17,28),box(54,3,2,17,28)],
		[socket("west-deck",[0,21],[-1,0],"floor"),socket("east-deck",[63,21],[1,0],"floor")],[[10,3,44,17]]))
	result.append(part("machine-housing","Vented mechanical housing","mechanical_housing",[32,32],
		[box(0,0,32,3,28),box(0,29,32,3,28),box(0,3,3,26,28),box(29,3,3,26,28),
			box(7,3,3,22,7),box(15,3,3,22,7),box(23,3,3,22,7)],
		[socket("base",[16,31],[0,1],"equipment")],[],[[3,3,26,26]],Module.TRANSFORMS))
	result.append(part("stepped-transition","Stepped deck transition","irregular_transition",[48,32],
		[box(0,28,16,4,58),box(16,20,16,12,58),box(32,12,16,20,58)],
		[socket("low",[0,30],[-1,0],"floor"),socket("high",[47,14],[1,0],"floor")],[[0,0,48,12]]))
	return result
