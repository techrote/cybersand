extends SceneTree

var failures: int = 0
func check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error(reason)
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene: Control = load("res://gcr_crash_playground.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	check(scene.runtime.active(),"active rocket owner")
	check(scene.runtime.selection == &"jetbarrel","rocket selected")
	var world: Object = scene.runtime._arena._world
	check(world.get_gcr_admission_variant()=="R2","actual retained RFT variant")
	check(scene._surface.material_surface_size==Vector2i(992,480),"large pixel surface")
	for i: int in range(9):
		check(world.material_at(90+i*100,470)==scene.MATERIALS[i],"authored material bank")
	check(scene.paint_at(Vector2i(400,100),14),"paint admitted")
	check(world.material_at(400,100)==14,"native painted Dust")
	check(scene.paint_at(Vector2i(400,100),0),"erase admitted")
	check(world.material_at(400,100)==0,"native erased")
	check(not scene.paint_at(Vector2i(16,475),0),"boundary protected")
	check(not scene.paint_at(Vector2i(400,100),255),"invalid material refused")
	for tick: int in range(120):
		scene.advance_frame({"move":Vector2.ZERO,"aim":Vector2.UP,"primary":false,"secondary":false,"auxiliary":false},false)
	check(not scene.runtime.failed,"120 live GCR/terrain/controller ticks")
	check(scene.paint_at(Vector2i(400,100),58),"hard terrain painting")
	scene.advance_frame({},false)
	check(not scene.runtime.failed,"hard edit collider update")
	check(scene.select_preset(6),"fresh reset")
	check(scene.runtime._arena._world.material_at(400,100)==0,"reset discards authored edits")
	scene.queue_free()
	await process_frame
	print("GCR_CRASH_PLAYGROUND failures=",failures)
	quit(0 if failures==0 else 1)
