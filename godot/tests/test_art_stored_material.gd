extends SceneTree

## Real native stored identity and mask policy, plus explicitly synthetic
## refusal fixtures. The worker's owner-only drain is called synchronously:
## no main-thread read races a running simulation thread in this test.
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var checks := 0
var failures := 0
var worker_witnesses: Array = []

class OldRuntime extends RefCounted:
	var tick_index := 0
	var revision := 0
	var writes := 0
	func material_at(_x: int, _y: int) -> int: return 0
	func rigid_body_id_at(_x: int, _y: int) -> int: return 0
	func emit_disc(_x: int, _y: int, _radius: int, _material: int) -> void: writes += 1

class RefusingRuntime extends OldRuntime:
	var cells: Dictionary = {}
	var fail_x := 11
	var wrong_write := false
	func stored_material_at(x: int, y: int) -> int: return int(cells.get(Vector2i(x,y),0))
	func emit_disc(x: int, y: int, _radius: int, material: int) -> void:
		writes += 1
		if x == fail_x and not wrong_write: return
		cells[Vector2i(x,y)] = 2 if x == fail_x else material
		revision += 1

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_STORED_CHECK ",label," ",ok)
	if not ok:
		failures += 1
		push_error(label)

func owner(world: Variant) -> RefCounted:
	var worker := Worker.new()
	worker._world = world
	worker._workbench_extent = Vector2i(128,128)
	return worker

func apply(worker: RefCounted, points: PackedInt32Array, material: int,
		guards: Array = [], allowed: Array = [0,58]) -> Dictionary:
	var answer: Dictionary = worker.art_queue(points,material,Rect2i(0,0,96,96),guards,worker.art_state().epoch,allowed)
	check(answer.status == "queued","native owner admits bounded command as queued")
	worker._consume_art()
	var receipt: Dictionary = worker.art_take_result()
	check(not receipt.is_empty(),"native owner publishes a consumed receipt")
	return receipt

func masks(world: Variant) -> void:
	var states := PackedFloat32Array()
	Coupling.append_input(states,1,Vector2(22,22),0.0,Vector2(8,8),Vector2.ZERO,0.0,1.0,1)
	world.prepare_rigid_body_coupling(states,false)

func native_case(workers: int) -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world != null and world.has_method("stored_material_at"),"source-built native stored_material_at API is loaded")
	if world == null or not world.has_method("stored_material_at"): return
	check(world.diagnostic_reset({"workers":workers}),"native fixture configured for %d workers" % workers)
	check(world.get_worker_threads() == workers,"actual native worker count is %d" % workers)
	world.emit_disc(11,10,0,58)
	world.emit_disc(12,10,0,2)
	world.emit_disc(13,10,0,1)
	world.emit_disc(21,20,0,58)
	world.emit_disc(22,20,0,1)
	masks(world)
	for point: Vector2i in [Vector2i(20,20),Vector2i(21,20),Vector2i(22,20)]:
		check(world.rigid_body_id_at(point.x,point.y)==1 and world.material_at(point.x,point.y)==1,
			"native transient body overlays effective Wall at %s" % point)
	check(world.stored_material_at(20,20)==0 and world.stored_material_at(21,20)==58
		and world.stored_material_at(22,20)==1,"stored Empty / Hard wall / Wall remain distinguishable below a body")
	check(world.stored_material_at(-1,0)==1 and world.stored_material_at(1024,0)==1,
		"stored query retains existing out-of-bounds Wall convention")
	# Existing native physics deliberately permits Empty through a mask. The
	# authoring boundary below must protect it explicitly rather than changing physics.
	world.emit_disc(20,20,0,58)
	check(world.stored_material_at(20,20)==0,"native nonempty write under a body is refused")
	world.emit_disc(21,20,0,0)
	check(world.stored_material_at(21,20)==0 and world.material_at(21,20)==1,
		"native erase exposes the stored/effective readback distinction")
	world.prepare_rigid_body_coupling(PackedFloat32Array(),false)
	world.emit_disc(21,20,0,58)
	masks(world)
	var worker := owner(world)
	var before_revision: int = world.revision
	var receipt := apply(worker,PackedInt32Array([10,10,11,10,12,10,13,10,20,20,21,20,22,20,40,40,130,20,100,100]),58,[Rect2i(40,40,1,1)])
	check(receipt.status=="completed" and receipt.backend=="CyberNativeCellWorld","completed receipt comes from the actual native World")
	check(receipt.requested==10 and receipt.checked==10 and receipt.changed==1 and receipt.unchanged==1
		and receipt.excluded==8 and receipt.refused==0 and receipt.confirmed==2,"paint exact changed/unchanged/excluded/refused accounting")
	check(receipt.readback==[[10,10,0,58],[11,10,58,58]],"paint receipt contains actual before/after stored material IDs")
	check(receipt.revision==world.revision and receipt.revision==before_revision+1,
		"confirmed receipt revision excludes the unchanged no-op")
	check(world.stored_material_at(20,20)==0 and world.stored_material_at(21,20)==58
		and world.stored_material_at(22,20)==1,"agent paint preserves every masked source identity")
	check(world.stored_material_at(12,10)==2 and world.stored_material_at(13,10)==1
		and world.stored_material_at(40,40)==0,"occupied and human-protected cells were not written")
	var paint_rows: Array = receipt.readback.duplicate(true)
	receipt = apply(worker,PackedInt32Array([10,10,14,10,11,10,20,20,21,20,22,20,12,10,13,10]),0)
	check(receipt.status=="completed" and receipt.checked==8 and receipt.changed==2 and receipt.unchanged==1
		and receipt.excluded==5 and receipt.refused==0 and receipt.confirmed==3,"erase exact changed/unchanged/excluded/refused accounting")
	check(receipt.readback==[[10,10,58,0],[14,10,0,0],[11,10,58,0]],"erase receipt contains stored identity rather than body overlay")
	check(world.stored_material_at(20,20)==0 and world.stored_material_at(21,20)==58
		and world.stored_material_at(22,20)==1,"agent erase preserves masked Empty, Hard wall and Wall")
	var erase_rows: Array = receipt.readback.duplicate(true)
	receipt = apply(worker,PackedInt32Array([15,10]),28,[],[0,58,28])
	check(receipt.changed==1 and receipt.readback==[[15,10,0,28]],"human-enabled Metal destination remains available to agent drawing")
	receipt = apply(worker,PackedInt32Array([15,10]),0)
	check(receipt.excluded==1 and receipt.changed==0 and world.stored_material_at(15,10)==28,
		"enabling a destination never weakens protected source policy")
	var denied: Dictionary = worker.art_queue(PackedInt32Array([16,10]),28,Rect2i(0,0,96,96),[],worker.art_state().epoch,[0,58])
	check(denied.status=="refused" and denied.refused==1 and denied.checked==0
		and world.stored_material_at(16,10)==0,"disabled destination is explicitly refused before native writes")
	denied = worker.art_queue(PackedInt32Array([16,10]),1,Rect2i(0,0,96,96),[],worker.art_state().epoch,[1])
	check(denied.status=="refused" and denied.refused==1,"unsupported destination is refused without changing the palette")
	var queued: Dictionary = worker.art_queue(PackedInt32Array([16,10]),58,Rect2i(0,0,96,96),[],worker.art_state().epoch)
	check(queued.status=="queued" and world.stored_material_at(16,10)==0,"queue admission does not claim application")
	worker._consume_art()
	denied = worker.art_queue(PackedInt32Array([17,10]),58,Rect2i(0,0,96,96),[],worker.art_state().epoch)
	check(denied.status=="refused" and denied.refused==1 and worker.art_state().receipt_ready,
		"unconsumed receipt keeps its exclusive slot and is not overwritten")
	receipt = worker.art_take_result()
	check(receipt.readback==[[16,10,0,58]] and world.stored_material_at(17,10)==0,
		"retained receipt reports only the actually applied command")
	var old_epoch: int = worker.art_state().epoch
	queued = worker.art_queue(PackedInt32Array([17,10]),58,Rect2i(0,0,96,96),[],old_epoch)
	check(queued.status=="queued","Stop fixture admits an unstarted native chunk")
	worker.art_stop()
	worker._consume_art()
	receipt = worker.art_take_result()
	check(receipt.status=="cancelled" and receipt.requested==1 and receipt.changed==0
		and receipt.unchanged==0 and receipt.refused==0 and world.stored_material_at(17,10)==0,
		"Stop retains truthful zero-write cancellation accounting")
	denied = worker.art_queue(PackedInt32Array([17,10]),58,Rect2i(0,0,96,96),[],old_epoch)
	check(denied.status=="refused" and denied.refused==1,"late old-epoch submission remains fenced")
	worker_witnesses.append([paint_rows,erase_rows,world.stored_material_at(20,20),world.stored_material_at(21,20),world.stored_material_at(22,20)])

func failure_fixtures() -> void:
	var old := OldRuntime.new()
	var worker := owner(old)
	var receipt := apply(worker,PackedInt32Array([10,10,11,10]),58)
	check(receipt.status=="refused" and receipt.refused==2 and receipt.checked==0 and old.writes==0
		and receipt.reason.contains("source-matched") and receipt.readback.is_empty(),
		"synthetic stale runtime refuses every cell with actionable feedback before writing")
	var refusing := RefusingRuntime.new()
	worker = owner(refusing)
	receipt = apply(worker,PackedInt32Array([10,10,11,10,12,10]),58)
	check(receipt.status=="partial" and receipt.requested==3 and receipt.checked==2 and receipt.changed==1
		and receipt.unchanged==0 and receipt.refused==1 and receipt.confirmed==1 and refusing.writes==2,
		"synthetic rejection reports the exact completed prefix and leaves the suffix unattempted")
	check(receipt.readback==[[10,10,0,58],[11,10,0,0]] and refusing.stored_material_at(12,10)==0,
		"synthetic rejection preserves actual failed-write readback")
	refusing = RefusingRuntime.new()
	refusing.fail_x = 10
	worker = owner(refusing)
	receipt = apply(worker,PackedInt32Array([10,10,11,10]),58)
	check(receipt.status=="refused" and receipt.changed==0 and receipt.refused==1 and receipt.confirmed==0,
		"synthetic first-write refusal is not reported as successful completion")
	refusing = RefusingRuntime.new()
	refusing.wrong_write = true
	worker = owner(refusing)
	receipt = apply(worker,PackedInt32Array([10,10,11,10,12,10]),58)
	check(receipt.status=="partial" and receipt.changed==2 and receipt.confirmed==1 and receipt.refused==1
		and receipt.readback==[[10,10,0,58],[11,10,0,2]],
		"synthetic wrong-material mutation remains visible in history rather than claiming requested success")

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		check(false,"source-built native GDExtension is required")
		quit(1)
		return
	native_case(1)
	native_case(4)
	check(worker_witnesses.size()==2 and worker_witnesses[0]==worker_witnesses[1],
		"one and four native workers produce identical stored material receipts")
	failure_fixtures()
	print("ART_STORED_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"native_workers":[1,4],"native_backend":"CyberNativeCellWorld","synthetic_failure_fixtures":4}))
	quit(1 if failures else 0)
