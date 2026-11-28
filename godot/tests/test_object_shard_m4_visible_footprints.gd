extends SceneTree

# Independent bounded geometry and foreground selection contracts. Publications
# here are synthetic values; this test makes no native mutation/physics claim.
const Footprint = preload("res://scripts/object_shard_live_edit_footprint.gd")
const Runtime = preload("res://scripts/object_shard_m4_runtime.gd")
class ImageHost extends Control:
	var image: Image
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("M4_VISIBLE_FOOTPRINTS: "+label)

func _shard(id: int, material: int) -> Dictionary:
	return {"id":id,"owns_inventory":true,"width":2,"height":2,"position_x":5.0,"position_y":5.0,
		"rotation":0.0,"generation":1,"body_generation":1,"geometry_revision":2,
		"applied_physics_revision":2,"pose_serial":3,"material_revision":4,
		"roles":PackedInt32Array([1,1,1,1]),"materials":PackedByteArray([material,material,material,material]),
		"states_a":PackedByteArray([0,0,0,0]),"states_b":PackedByteArray([0,0,0,0]),
		"temperature":PackedInt32Array([0,0,0,0]),"incarnations":PackedInt64Array([1,1,1,1])}

func _run() -> void:
	var single: Dictionary = Footprint.build(Vector2i(5,5),Vector2i(5,5),0,Vector2i(64,64))
	_check(single.ok and single.cells==[Vector2i(5,5)],"zero-radius footprint is one exact cell")
	var circle: Dictionary = Footprint.build(Vector2i(10,10),Vector2i(10,10),3,Vector2i(64,64))
	_check(circle.ok and circle.cells.size()==29,"radius-three circle has independently known 29-cell lattice area")
	var sweep: Dictionary = Footprint.build(Vector2i(10,10),Vector2i(15,10),1,Vector2i(64,64))
	_check(sweep.ok and sweep.cells.size()==20,"swept radius-one brush covers a gap-free capsule without duplicate cells")
	var clip: Dictionary = Footprint.build(Vector2i.ZERO,Vector2i.ZERO,2,Vector2i(64,64))
	_check(clip.ok and clip.cells.size()==6,"edge-clipped circle admits only its six in-canvas lattice cells")
	var diagonal: Dictionary = Footprint.build(Vector2i(0,0),Vector2i(4,4),0,Vector2i(64,64))
	_check(diagonal.ok and diagonal.cells==[Vector2i(0,0),Vector2i(1,1),Vector2i(2,2),Vector2i(3,3),Vector2i(4,4)],
		"thin diagonal slice follows the intended discrete line")
	var wide: Dictionary = Footprint.build(Vector2i(0,0),Vector2i(1023,1023),24,Vector2i(1024,1024))
	_check(wide.ok and wide.partial and wide.cells.size()<=4096 and wide.probes<=65536,
		"maximum-radius long freehand input produces a bounded partial capsule")
	_check(wide.end!=Vector2i.ZERO and wide.end!=Vector2i(1023,1023),"partial capsule advances to a finite explicit remainder")
	var too_large: Dictionary = Footprint.build(Vector2i(0,0),Vector2i(1023,1023),24,Vector2i(1024,1024),false)
	_check(not too_large.ok and too_large.outcome=="FootprintCapacity" and too_large.cells.is_empty(),
		"oversized deliberate slice refuses the entire footprint without partial cells")
	_check(not Footprint.build(Vector2i.ZERO,Vector2i.ONE,25,Vector2i(64,64)).ok,"radius beyond declared maximum refuses")
	var outline: PackedVector2Array = Footprint.outline(Vector2(10.5,10.5),Vector2(15.5,10.5),1)
	_check(outline.size()>4 and outline[0]==outline[-1],"swept preview is a closed bounded outline")
	var runtime := Runtime.new()
	var host := ImageHost.new()
	host.image = Image.create(16,16,false,Image.FORMAT_R8)
	host.image.fill(Color(1.0/255.0,0,0,1))
	runtime._host = host
	var behind: Dictionary = _shard(1,7)
	var front: Dictionary = _shard(2,43)
	runtime.publication = {"session":1,"owner_epoch":1,"shard_session":1,"world_incarnation":1,
		"transport_generation":1,"publication_sequence":1,"shards":[behind,front]}
	var point := Vector2i(5,5)
	_check(runtime.visible_target(point).get("owner")==2,"overlapping owners choose the foreground render order")
	var groups: Dictionary = runtime.visible_edit_groups([point])
	_check(groups.size()==1 and groups.has(2),"foreground structural material occludes both lower owner and ordinary terrain")
	front.roles[0] = 3
	front.materials[0] = 2
	groups = runtime.visible_edit_groups([point])
	_check(runtime.visible_target(point).is_empty() and groups.is_empty(),
		"ineligible but visibly owned Cargo occludes lower material instead of erasing through it")
	front.roles[0] = 2
	front.materials[0] = 4
	_check(runtime.visible_edit_groups([point]).is_empty(),"visible Product also blocks hidden terrain and structural owners")
	front.roles[0] = 0
	front.materials[0] = 0
	_check(runtime.visible_target(point).get("owner")==1,"a genuine Empty hole reveals the next structural owner")
	behind.roles[0] = 0
	behind.materials[0] = 0
	groups = runtime.visible_edit_groups([point])
	_check(groups.size()==1 and groups.has(0) and groups[0]==[point],"ordinary terrain becomes editable only through real material openings")
	front.roles[0] = 1
	front.materials[0] = 43
	front.position_x = 6.0
	front.rotation = PI/2.0
	var rotated: Dictionary = runtime.visible_target(point)
	_check(rotated.get("owner")==2 and rotated.get("cell")==0 and rotated.get("position")==point,
		"rotated foreground acquisition preserves the inverse-transform cell witness")
	runtime.publication.shards = [front,behind]
	_check(runtime.visible_target(point)==rotated,"publication enumeration order cannot change foreground targeting")
	runtime.publication.clear()
	_check(runtime.visible_edit_groups([point]).is_empty(),"retired publication exposes no target domain")
	runtime._host = null
	host.free()
	print(JSON.stringify({"schema":"objectshard-m4-visible-footprints-v1","checks":checks,"failures":failures,
		"scope":"bounded pure footprint geometry and synthetic copied-publication occlusion; no native or physical execution claim"}))
	quit(0 if failures.is_empty() else 1)
