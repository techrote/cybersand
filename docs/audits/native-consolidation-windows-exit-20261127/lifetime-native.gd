extends SceneTree
func _initialize() -> void:
	finish.call_deferred()
func finish() -> void:
	var refs: Array[WeakRef] = []
	for i in range(4):
		var world = ClassDB.instantiate("CyberNativeCellWorld")
		refs.append(weakref(world))
		assert(world.diagnostic_reset({"workers":1,"extent":Vector2i(2048,1024)}))
		var x := 2044.5 if i == 3 else 1800.5
		world.prepare_rigid_body_coupling(PackedFloat32Array([1,x,100.5,0,4,4,0,0,0,1,1]),false)
		assert(world.rigid_body_id_at(int(x),100) == 1)
		world = null
	for ref in refs:
		assert(ref.get_ref() == null)
	print("NATIVE_WORLDS_RETIRED")
	quit()
