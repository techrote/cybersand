extends SceneTree
## #526 production-path pure adapter regression (physical parity is NOT assumed).
## No native material action, physics equivalence or live agent is claimed.
const Frame = preload("res://scripts/workbench_agent_signed_frame.gd")
var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, reason: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(reason)

func _run() -> void:
	var sand: Dictionary = Frame.region({"x":-8,"y":0,"width":8,"height":4})
	check(sand.status=="mapped" and sand.native==Rect2i(504,512,8,4),
		"frozen original 32-Sand rectangle translation")
	var normal: Dictionary = Frame.region({"x":10,"y":29,"width":13,"height":11})
	check(normal.status=="mapped" and normal.native==Rect2i(522,541,13,11),
		"normal original catchment translation")
	var revised: Dictionary = Frame.region({"x":-31,"y":29,"width":13,"height":11})
	check(revised.status=="mapped" and revised.native==Rect2i(481,541,13,11),
		"revised negative catchment translation")
	var motif: Dictionary = Frame.regions([
		{"x":30,"y":-3,"width":1,"height":7},
		{"x":30,"y":-3,"width":5,"height":1}
	])
	check(motif.status=="mapped" and motif.native[0]==Rect2i(542,509,1,7)
		and motif.native[1]==Rect2i(542,509,5,1),
		"protected motif must map in same physical frame")
	check(normal.frame_id==revised.frame_id and revised.frame_id==sand.frame_id
		and sand.frame_id==Frame.FRAME_ID,
		"all task values must bind an identical immutable frame")
	check(Frame.point(-512,-512).native==Vector2i(0,0),
		"left/top legal boundary must remain addressable")
	check(Frame.point(1535,1535).native==Vector2i(2047,2047),
		"right/bottom legal boundary must remain addressable")
	check(Frame.point(-513,0).status=="refused"
		and Frame.point(0,-513).status=="refused"
		and Frame.point(1536,0).status=="refused"
		and Frame.point(0,1536).status=="refused",
		"out-of-range positions must refuse, never clip or wrap")
	check(Frame.point(9223372036854775807,0).status=="refused",
		"adversarial int64 must refuse before Vector2i narrowing")
	check(Frame.point(-8.0,0).status=="refused",
		"floating-point model arguments must not silently truncate")
	check(Frame.region({"x":1535,"y":0,"width":2,"height":1}).status=="refused"
		and Frame.region({"x":-512,"y":0,"width":0,"height":1}).status=="refused",
		"partially clipped/empty authorized region must refuse")
	check(Frame.region({"x":-512,"y":-512,"width":2048,"height":2048}).status=="mapped",
		"maximal exact finite logical domain")
	check(Frame.regions([{"x":30,"y":-3,"width":1,"height":7},
		{"x":-513,"y":0,"width":1,"height":1}]).status=="refused",
		"single bad protection region must refuse whole request")
	var edits: Dictionary = Frame.operations([
		{"shape":"rectangle","x0":-8,"y0":6,"x1":-1,"y1":6,
			"material":0,"replace_only_material":58},
		{"shape":"line","x0":-35,"y0":8,"x1":-7,"y1":8,"material":58},
		{"shape":"disc","x":10,"y":29,"radius":1,"material":58}
	])
	check(edits.status=="mapped" and edits.native.size()==3,
		"three frozen operation classes must map as one ordered batch")
	if edits.status=="mapped":
		check(edits.native[0].x0==504 and edits.native[0].x1==511
			and edits.native[0].y0==518 and edits.native[0].replace_only_material==58,
			"outlet Empty filter, coordinates and order must be unchanged")
		check(edits.native[1].x0==477 and edits.native[1].x1==505
			and edits.native[1].y0==520,
			"signed chute line must preserve world-space geometry")
		check(edits.native[2].x==522 and edits.native[2].y==541
			and edits.native[2].radius==1,
			"disc center and radius must map without rescaling")
	check(Frame.operations([{"shape":"disc","x":0,"y":0,"radius":0,
		"material":2}]).status=="refused",
		"agent must never manufacture Sand")
	check(Frame.operations([{"shape":"disc","x":0,"y":0,"radius":37,
		"material":58}]).status=="refused",
		"over-capacity disc must refuse before allocation")
	check(Frame.operations([{"shape":"disc","x":-512,"y":-512,"radius":1,
		"material":58}]).status=="refused",
		"partially clipped disc must not silently shrink")
	check(Frame.operations([{"shape":"line","x0":-513,"y0":0,
		"x1":-510,"y1":0,"material":58}]).status=="refused",
		"line outside finite domain must refuse")
	check(Frame.operations([{"shape":"rectangle","x0":-1,"y0":0,
		"x1":-2,"y1":1,"material":58}]).status=="refused",
		"reversed rectangle must refuse")
	var too_many: Array = []
	for i: int in range(9):
		too_many.append({"shape":"disc","x":i,"y":0,"radius":0,"material":58})
	check(Frame.operations(too_many).status=="refused",
		"ninth primitive must refuse")
	check(Frame.operations([{"shape":"disc","x":0,"y":0,"radius":0,
		"material":0,"replace_only_material":2}]).status=="refused",
		"Sand filter must not be admitted for authoring")
	var material_readback: Dictionary = Frame.readback_to_logical([
		{"x":481,"y":541,"before":0,"after":58,"actual":58},
		{"x":511,"y":512,"before":0,"after":58,"actual":58}
	])
	check(material_readback.status=="mapped"
		and material_readback.logical[0].x==-31
		and material_readback.logical[0].y==29
		and material_readback.logical[0].before==0
		and material_readback.logical[0].actual==58
		and material_readback.logical[1].x==-1
		and material_readback.logical[1].y==0,
		"native readback must return signed coordinates without altering material IDs")
	check(Frame.readback_to_logical([{"x":2048,"y":0}]).status=="refused",
		"out-of-range native receipt must not become a signed valid readback")
	check(Frame.readback_to_logical([{"x":512.0,"y":512}]).status=="refused",
		"native receipt coordinates must be exact integers")
	# Native readback must refuse huge int64 values BEFORE Godot's 32-bit
	# Vector2i construction could alias them to a plausible native cell.
	check(Frame.readback_to_logical([{"x":4294967808,"y":512}]).status=="refused"
		and Frame.readback_to_logical([{"x":512,"y":4294967808}]).status=="refused",
		"positive int64 overflow must not wrap to a valid 512 native cell")
	check(Frame.readback_to_logical([{"x":-4294966784,"y":512}]).status=="refused"
		and Frame.readback_to_logical([{"x":512,"y":-4294966784}]).status=="refused",
		"negative int64 underflow must not wrap to a valid 512 native cell")
	check(Frame.readback_to_logical([{"x":9223372036854775807,"y":512}]).status=="refused",
		"maximal int64 native readback must be rejected without narrowing")
	var extreme_valid: Dictionary = Frame.readback_to_logical([
		{"x":0,"y":0,"before":0,"after":58,"actual":58},
		{"x":2047,"y":2047,"before":58,"after":0,"actual":0}
	])
	check(extreme_valid.status=="mapped"
		and extreme_valid.logical[0].x==-512
		and extreme_valid.logical[0].y==-512
		and extreme_valid.logical[1].x==1535
		and extreme_valid.logical[1].y==1535
		and extreme_valid.logical[1].actual==0,
		"both exact native extrema and material IDs must survive reversible mapping")
	var back: Dictionary = Frame.point(material_readback.logical[0].x,
		material_readback.logical[0].y)
	check(back.status=="mapped" and back.native==Vector2i(481,541),
		"coordinate frame roundtrip must be bijective")
	print("WB_AGENT_SIGNED_FRAME: %d assertions, %d failures" %
		[assertions,failures])
	quit(1 if failures else 0)
