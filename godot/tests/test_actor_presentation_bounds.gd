extends SceneTree

const Bounds = preload("res://scripts/actor_presentation_bounds.gd")
var checks := 0
var failures := 0


func expect(value: bool, message: String) -> void:
	checks += 1
	if value: return
	failures += 1
	push_error(message)


func same(a: Rect2, b: Rect2) -> bool:
	return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)


func _initialize() -> void:
	expect(Bounds.physical([]).is_empty(), "Retired physical publication produces no reveal")
	expect(Bounds.prototype(PackedFloat32Array(),PackedFloat32Array()).is_empty(), "Empty prototype publication produces no reveal")
	var parts := [
		{"actor_id":7,"transform":Transform2D(0.0,Vector2(50,50)),"size":Vector2(8,8)},
		{"actor_id":2,"transform":Transform2D(PI*0.5,Vector2(10,20)),"size":Vector2(4,10)},
		{"actor_id":2,"transform":Transform2D(0.0,Vector2(30,20)),"size":Vector2(4,4)}]
	var source := parts.duplicate(true)
	var result := Bounds.physical(parts)
	expect(result.size() == 2, "Multiple physical parts merge into one bound per actor")
	expect(same(result[0],Rect2(5,18,27,4)), "Rotated and compound displayed parts use the correct world-space union")
	expect(same(result[1],Rect2(46,46,8,8)), "Published actor identity order is deterministic")
	expect(parts == source, "Bounds read never mutates published physical transforms")
	expect(Bounds.physical(parts,1).size() == 1, "Physical bounds respect remaining actor slots")
	expect(Bounds.physical(parts,0).is_empty() and Bounds.physical(parts,-1).is_empty(), "Zero and negative limit produce no bounds")
	var invalid := [{}, {"actor_id":0,"transform":Transform2D.IDENTITY,"size":Vector2(-1,8)},
		{"actor_id":0,"transform":Transform2D.IDENTITY,"size":Vector2(NAN,8)},
		{"actor_id":0,"transform":Transform2D(0.0,Vector2(INF,2)),"size":Vector2(8,8)},
		{"actor_id":-1,"transform":Transform2D.IDENTITY,"size":Vector2(8,8)},
		{"actor_id":"0","transform":Transform2D.IDENTITY,"size":Vector2(8,8)}]
	expect(Bounds.physical(invalid).is_empty(), "Malformed, nonfinite and negative actor identities are omitted")
	var high_ids := [{"actor_id":100,"transform":Transform2D(0.0,Vector2(40,40)),"size":Vector2(4,4)},
		{"actor_id":8,"transform":Transform2D(0.0,Vector2(20,20)),"size":Vector2(4,4)},
		{"actor_id":100,"transform":Transform2D(0.0,Vector2(48,40)),"size":Vector2(4,4)}]
	var high_bounds := Bounds.physical(high_ids)
	expect(high_bounds.size() == 2 and same(high_bounds[0],Rect2(18,18,4,4)), "Eighth and later monotonically increasing instance IDs remain eligible")
	expect(same(high_bounds[1],Rect2(38,38,12,4)), "High instance ID parts merge and sort without a slot-number assumption")
	var identities := []
	for identity: int in range(100,120):
		identities.append({"actor_id":identity,"transform":Transform2D(0.0,Vector2(identity,20)),"size":Vector2(2,2)})
	expect(Bounds.physical(identities).size() == 8, "Eight distinct active identities remain the hard limit irrespective of ID magnitude")
	var bounded := []
	for index: int in 80:
		bounded.append({"actor_id":index%8,"transform":Transform2D(0.0,Vector2(index*2,0)),"size":Vector2(2,2)})
	var limited := Bounds.physical(bounded,99)
	expect(limited.size() == 8, "Eight actor rectangles are the hard upper bound")
	for bounds: Rect2 in limited:
		expect(bounds.end.x <= 127.0, "Physical publication inspection never exceeds 64 admitted render parts")
	var legacy := PackedFloat32Array()
	legacy.resize(32)
	legacy[0] = 12.0; legacy[1] = 24.0
	legacy[16] = 44.0; legacy[17] = 66.0
	var before := legacy.duplicate()
	var old_bounds := Bounds.prototype(legacy,PackedFloat32Array())
	expect(old_bounds.size() == 2 and same(old_bounds[0],Rect2(12,24,8,14)), "Legacy published sampled dimensions remain supported")
	expect(same(old_bounds[1],Rect2(44,66,8,14)), "Legacy actor position uses its own record stride")
	var rigs := PackedFloat32Array()
	rigs.resize(40)
	rigs[0] = 100.0; rigs[1] = 200.0; rigs[16] = PI*0.5
	rigs[35] = 4.0; rigs[36] = 10.0
	var extended := Bounds.prototype(legacy,rigs)
	expect(same(extended[0],Rect2(97,203,10,4)), "Published prototype rotation and dimensions match overlay body bounds")
	expect(same(extended[1],old_bounds[1]), "An incomplete later rig record safely falls back to the legacy record")
	expect(legacy == before and is_equal_approx(rigs[0],100.0), "Prototype assistance leaves publication inputs unchanged")
	rigs[16] = NAN
	expect(Bounds.prototype(legacy,rigs,1).is_empty(), "Nonfinite published rig angle is refused")
	rigs[16] = 0.0; rigs[35] = 0.0
	expect(Bounds.prototype(legacy,rigs,1).is_empty(), "Empty published rig dimensions are refused")
	expect(Bounds.prototype(legacy,PackedFloat32Array(),0).is_empty(), "Prototype query respects zero remaining slots")
	print("STRATA003_ACTOR_BOUNDS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
