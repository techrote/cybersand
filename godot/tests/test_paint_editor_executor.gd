extends SceneTree

# Direct native owner contract checks independent of mounted GUI availability.
const Executor = preload("res://scripts/workbench_paint_editor_executor.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error("PAINT_EXECUTOR " + label)
func context(world: Variant) -> Dictionary:
	return {"epoch":1,"generation":1,"revision":int(world.revision),"tick":int(world.tick_index),"paused":true,"settings_revision":0,"error":"","paint_allowed":true,"erase_allowed":true}
func create(world: Variant, cells: PackedInt32Array) -> RefCounted:
	var request := {"kind":"edit","cells":cells,"expected_generation":1,"expected_revision":int(world.revision),"expected_tick":int(world.tick_index),"operation_id":1,"_epoch":1,"_settings_revision":0}
	var owner := Executor.new()
	owner.begin(request,Vector2i(1024,1024),Executor.native_materials())
	return owner
func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	check(ClassDB.class_exists(&"CyberNativeCellWorld"),"actual native runtime registered")
	if not ClassDB.class_exists(&"CyberNativeCellWorld"): quit(1); return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var cells := PackedInt32Array()
	for y: int in range(100,165):
		for x: int in range(100,165): cells.append_array([x,y,2])
	var owner: RefCounted = create(world,cells)
	check(owner.step(world,context(world)).is_empty(),"bounded first preflight slice")
	check(int(world.material_at(100,100))==0,"preflight does not write")
	var stopped := context(world); stopped.epoch=2
	var receipt: Dictionary = owner.step(world,stopped)
	check(receipt.status=="cancelled" and receipt.applied==0,"queued cancellation has no hidden prefix")
	owner=create(world,cells)
	owner.step(world,context(world)); owner.step(world,context(world))
	check(owner.step(world,context(world)).is_empty(),"large application yields after finite slice")
	check(int(world.material_at(100,100))==2 and int(world.material_at(164,164))==0,"bounded applied prefix only")
	world.emit_disc(90,90,0,58)
	receipt=owner.step(world,context(world))
	check(receipt.status=="partial" and receipt.applied==4096,"foreign revision fences remaining work")
	check(not receipt.recovery_possible,"foreign revision cannot advertise automatic reversal")
	owner=create(world,PackedInt32Array([10,10,58,11,10,10]))
	receipt=owner.step(world,context(world))
	check(receipt.status=="refused" and int(world.material_at(10,10))==0,"late invalid material refuses all writes")
	owner=create(world,PackedInt32Array([10,10,58,9,10,58]))
	receipt=owner.step(world,context(world))
	check(receipt.status=="refused" and int(world.material_at(10,10))==0,"noncanonical order refuses all writes")
	for field: String in ["generation","tick","settings_revision"]:
		owner=create(world,PackedInt32Array([10,10,58]))
		var changed := context(world); changed[field]+=1
		receipt=owner.step(world,changed)
		check(receipt.status=="invalidated" and receipt.applied==0,"owner fences changed "+field)
	owner=create(world,PackedInt32Array([10,10,58]))
	var playing := context(world); playing.paused=false
	receipt=owner.step(world,playing)
	check(receipt.status=="invalidated" and receipt.applied==0,"live simulation is not authored history")
	for material: int in [0,58]:
		owner=create(world,PackedInt32Array([10,10,material]))
		var denied := context(world); denied["erase_allowed" if material==0 else "paint_allowed"]=false
		receipt=owner.step(world,denied)
		check(receipt.status=="refused" and receipt.applied==0,"execution enforces scenario tool permission %d" % material)
	owner=create(world,PackedInt32Array([10,10,58]))
	owner.step(world,context(world))
	var denied := context(world); denied.paint_allowed=false
	receipt=owner.step(world,denied)
	check(receipt.status=="invalidated" and receipt.applied==0,"permission revoked after preflight is enforced")
	var request := {"kind":"edit","cells":PackedInt32Array([1,1,2]),"expected_generation":1,"expected_revision":0,"expected_tick":0}
	check(Executor.request_error(request).is_empty(),"bounded plain-value request accepted")
	request.extra=world
	check(not Executor.request_error(request).is_empty(),"native objects cannot cross value-only command boundary")
	request.erase("extra")
	var sources := PackedInt32Array(); sources.resize(257)
	request.source_allowed=sources
	check(not Executor.request_error(request).is_empty(),"source policy memory bound enforced")
	request.erase("source_allowed")
	request.kind="capture"
	request.region=Rect2i(0,0,1,1)
	request.cells=world
	check(not Executor.request_error(request).is_empty(),"unused capture fields cannot carry a World or unbounded payload")
	world=null
	print("PAINT_EXECUTOR ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
