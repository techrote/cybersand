extends SceneTree
## Compare admitted bounds with Godot's actual Variant encoder for normal pure
## values. Oversized aliases are deliberately never handed to that encoder.
const Store = preload("res://scripts/persistent_area_store.gd")
var checks := 0
var failures := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Metadata admission: "+label)


func bounded(value: Variant) -> void:
	var admitted := Store.metadata_size(value)
	check(admitted.get("ok",false),"ordinary pure value remains admitted: "+type_string(typeof(value)))
	if admitted.get("ok",false):
		check(var_to_bytes(value).size()<=int(admitted.bytes),"actual Godot encoding fits its conservative admission")


func _initialize() -> void:
	var typed_array: Array[int] = [1,2,3]
	var typed_dictionary: Dictionary[String,int] = {"first":1,"second":2}
	var ordinary: Array = [null,false,true,0,2147483648,-9223372036854775807,0.25,1.0e100,
		"","plain ASCII","é / € / 😀",Vector2(1,2),Vector2i(1,2),Vector3(1,2,3),Vector3i(1,2,3),
		Vector4(1,2,3,4),Vector4i(1,2,3,4),Rect2(1,2,3,4),Rect2i(1,2,3,4),Color(0.1,0.2,0.3,0.4),
		PackedByteArray([0,1,2,255]),PackedInt32Array([0,-1,2147483647]),PackedInt64Array([2147483648,-2147483649]),
		PackedFloat32Array([0.25,-1]),PackedFloat64Array([1.0e100,0.25]),PackedStringArray(["","ASCII","é😀"]),
		PackedVector2Array([Vector2(1,2)]),PackedVector3Array([Vector3(1,2,3)]),PackedColorArray([Color.RED]),
		[],{},typed_array,typed_dictionary,{"nested":[{"values":[1,2,3]},["UTF-8","😀"]]}]
	for value: Variant in ordinary: bounded(value)
	for length: int in [1,2,3,4,5,31,32,33,255,256,257]:
		var bytes := PackedByteArray()
		bytes.resize(length)
		bounded(bytes)
		bounded("😀".repeat(length))
		bounded({"data":bytes,"text":"ascii".repeat(length)})
	var shared := PackedByteArray()
	shared.resize(5*1024*1024)
	check(Store._pure([shared,shared],[Store.MAX_VALUE_ITEMS]),"two shared buffers fit the old pure-item contract")
	var refusal := Store.metadata_size([shared,shared])
	check(not refusal.get("ok",false) and int(refusal.visited_items)<=3,
		"two aliased packed buffers are charged twice and refused before encoding")
	var repeats: Array = []
	repeats.resize(4096)
	repeats.fill(shared)
	refusal = Store.metadata_size(repeats)
	check(not refusal.get("ok",false) and int(refusal.visited_items)<=3,
		"logical twenty-GiB alias expansion stops after its first over-budget occurrence")
	var strings: Array = []
	strings.resize(1024)
	strings.fill("x".repeat(65536))
	check(not Store.metadata_size(strings).get("ok",false),"repeated bounded strings cannot evade aggregate bytes")
	var typed_objects: Array[Node] = []
	var typed_object_dictionary: Dictionary[String,Node] = {}
	check(not Store.metadata_size(typed_objects).get("ok",false),"empty typed Object array cannot carry a hidden live type")
	check(not Store.metadata_size(typed_object_dictionary).get("ok",false),"empty typed Object dictionary cannot carry a hidden live type")
	check(not Store.metadata_size({"bad":NAN}).get("ok",false),"non-finite scalar refuses")
	check(not Store.metadata_size(PackedFloat32Array([NAN])).get("ok",false),"non-finite packed scalar refuses")
	check(not Store.metadata_size(PackedVector3Array([Vector3(INF,0,0)])).get("ok",false),"non-finite packed vector refuses")
	check(not Store.metadata_size([1,2,3],1024,2).get("ok",false),"item admission is independent of byte capacity")
	var nested: Variant = 1
	for index: int in 26: nested=[nested]
	check(not Store.metadata_size(nested).get("ok",false),"recursion depth remains bounded")
	print("GEN006_RAMCACHE_METADATA_BOUNDS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
