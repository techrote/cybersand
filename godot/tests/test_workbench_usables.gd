extends SceneTree

# Copied-contract/runtime units. The separate physical-usables fixture executes
# all32 catalogue definitions against the actual native adapter.
const Runtime = preload("res://scripts/physical_usable_runtime.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
var checks: int = 0
var failures: Array[String] = []

class Cells extends RefCounted:
	var cells: Dictionary = {}
	var masks: Dictionary = {}
	func material_at(x: int,y: int) -> int: return 1 if masks.has(Vector2i(x,y)) else int(cells.get(Vector2i(x,y),0))
	func rigid_body_id_at(x: int,y: int) -> int: return int(masks.get(Vector2i(x,y),0))
	func emit_disc(x: int,y: int,_radius: int,material: int) -> void:
		if not masks.has(Vector2i(x,y)): cells[Vector2i(x,y)] = material
	func has_failed() -> bool: return false

class Mount extends RefCounted:
	var attached: bool = true
	var fixed: bool = false
	func equipment_mount_state() -> Dictionary: return {"held_part":0}
	func capabilities() -> Dictionary: return {}
	func release_usable() -> bool:
		if not attached: return false
		attached = false
		return true
	func fix_usable() -> bool:
		if attached or fixed: return false
		fixed = true
		return true

func _init() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func actor(usable: int = 0,slot: int = 1,body: int = 2,proxy: int = 6) -> Dictionary:
	var position := Vector2(1536.5,1536.5)
	return {"actor_id":slot,"generation":0,"equipment_epoch":1,"instance_id":"same-equipment",
		"usable_index":usable,"state":"held","body_id":body,"position":position,"rotation":0.0,
		"half_extents":Vector2(2,2),"muzzle":position+Vector2(4,0),"direction":Vector2.RIGHT,
		"owner_origin":position-Vector2(8,0),"active":true,"lease_deadline":100000,
		"parts":[{"body_id":body,"position":position,"rotation":0.0,"half_extents":Vector2(2,2),"proxy_ids":PackedInt32Array([proxy])}],
		"workbench_instance_id":202,"workbench_model":"acrobat"}

func frame(usable: int = 0) -> Dictionary:
	return {"version":1,"run_id":"original-owner","epoch":4,"tick":0,"suspended":false,
		"canvas_extent":Vector2i(2048,2048),"actors":[actor(usable)],"devices":[]}

func request(value: Dictionary,operation: String = "use",sequence: int = 1) -> Dictionary:
	var row: Dictionary = value.actors[0]
	var result: Dictionary = {"version":1,"run_id":value.run_id,"epoch":value.epoch,"sequence":sequence,
		"request_id":"request-%d" % sequence,"operation":operation,"power":1.0}
	for key: String in ["actor_id","generation","equipment_epoch","instance_id","usable_index","body_id"]: result[key] = row[key]
	return result

func mask(world: Cells,proxy: int = 6) -> void:
	for y: int in range(1534,1539):
		for x: int in range(1534,1539): world.masks[Vector2i(x,y)] = proxy

func run() -> void:
	alias_and_extent()
	payload_custody()
	equipment_custody()
	atomic_sample()
	print("WORKBENCH_USABLES "+JSON.stringify({"checks":checks,"failures":failures,"scope":"copied contract/runtime unit; native catalogue qualified separately"}))
	quit(0 if failures.is_empty() else 1)

func alias_and_extent() -> void:
	var world := Cells.new(); mask(world)
	var runtime := Runtime.new(); var current: Dictionary = frame()
	check(Runtime.frame_error(current).is_empty(),"extended frame admitted")
	var outcome: Dictionary = runtime.step(1.0/60.0,world,current,[request(current)])
	check(outcome.receipts.size() == 1 and outcome.receipts[0].accepted,"canonical body2 emits through own native proxy6")
	check(outcome.write_count_last > 0 and world.cells.values().has(2),"tool changes cells beyond legacy1024 boundary")
	check(outcome.actors[0].charge < 100.0,"extended tool pays authored charge")
	var bad: Dictionary = current.duplicate(true); bad.canvas_extent = Vector2i(2049,2048)
	check(Runtime.frame_error(bad) == "canvas_extent","extent above capacity refused")
	bad = current.duplicate(true); bad.canvas_extent = Vector2(2048,2048)
	check(Runtime.frame_error(bad) == "canvas_extent","noninteger extent type refused")
	bad = current.duplicate(true); bad.actors[0].parts[0].proxy_ids = PackedInt32Array([6,6])
	check(Runtime.frame_error(bad) == "proxy_ids","duplicate own proxy refused")
	bad = current.duplicate(true); var other: Dictionary = actor(0,0,3,6); other.workbench_instance_id=303
	bad.actors.append(other)
	check(Runtime.frame_error(bad) == "duplicate_proxy_owner","one proxy cannot claim two bodies")
	var legacy: Dictionary = current.duplicate(true); legacy.erase("canvas_extent")
	var legacy_world := Cells.new(); mask(legacy_world)
	check(Runtime.new().step(1.0/60.0,legacy_world,legacy,[request(legacy)]).write_count_last == 0,"legacy extent remains1024")
	var blocked_world := Cells.new(); mask(blocked_world); blocked_world.masks[Vector2i(1539,1536)] = 2
	var blocked: Dictionary = Runtime.new().step(1.0/60.0,blocked_world,current,[request(current)])
	check(not blocked.receipts[0].accepted and blocked.write_count_last == 0,"foreign proxy/canonical number collision stays blocked")

func payload_custody() -> void:
	var world := Cells.new(); mask(world)
	var runtime := Runtime.new(); var current: Dictionary = frame(12)
	var before: Dictionary = runtime.step(1.0/60.0,world,current,[request(current)])
	check(before.projectiles.size() == 1,"payload committed")
	var next: Dictionary = current.duplicate(true); next.run_id="replacement-owner"; next.epoch=5; next.tick=0
	next.actors[0].actor_id=0; next.actors[0].body_id=3
	next.actors[0].parts[0].body_id=3; next.actors[0].parts[0].proxy_ids=PackedInt32Array([13])
	var prepared: Dictionary = runtime.prepare_workbench_transfer(next,true)
	check(prepared.ok,"payload crosses prepared graph replacement")
	if prepared.ok:
		var after: Dictionary = prepared.runtime.snapshot()
		check(after.projectiles.size() == 1 and after.projectiles[0].owner == 0,"payload remaps by stable instance")
		check(after.projectiles[0].position == before.projectiles[0].position and after.projectiles[0].velocity == before.projectiles[0].velocity,"payload motion retained")
		check(after.actors[0].charge == before.actors[0].charge and after.actors[0].cooldown == before.actors[0].cooldown,"charge/cooldown not replenished")
		check(after.run_id == next.run_id and after.epoch == 5,"new epoch owns retained entities")
	check(runtime.snapshot().run_id == current.run_id and runtime.snapshot().projectiles.size() == 1,"staging leaves retained owner unchanged")
	var removed: Dictionary = next.duplicate(true); removed.actors=[]
	check(not runtime.prepare_workbench_transfer(removed,true).ok,"removing live payload owner refused")
	check(runtime.prepare_workbench_transfer(removed,false).ok,"explicit fresh experiment may retire entities")
	# Exercise real recipe state, then hand it over without refilling its stock.
	var processor := Runtime.new(); var setup: Dictionary = frame(22); setup.actors[0].state="fixed"
	var device: Dictionary = {}
	for key: String in ["instance_id","actor_id","equipment_epoch","usable_index","body_id","position","rotation","half_extents","state"]: device[key]=setup.actors[0][key]
	setup.devices=[device]
	var deployed: Dictionary = processor.step(1.0/60.0,world,setup,[request(setup,"deploy")])
	check(deployed.objects.size() == 1,"processor admitted through proxy alias")
	world.cells[Vector2i(1533,1536)]=13; setup.tick+=1
	var processed: Dictionary = processor.step(1.0/60.0,world,setup)
	check(processed.objects.size() == 1 and processed.objects[0].cycles == 1 and processed.objects[0].stock == 15,"recipe consumes stock before handoff")
	var processor_next: Dictionary = setup.duplicate(true); processor_next.epoch=6; processor_next.run_id="processor-next"; processor_next.tick=0
	var carried: Dictionary = processor.prepare_workbench_transfer(processor_next,true)
	check(carried.ok,"deployed chassis admits custody")
	if carried.ok:
		var objects: Array = carried.runtime.snapshot().objects
		check(objects.size() == 1 and objects[0].stock == 15 and objects[0].cycles == 1,"processor stock/history survive peer rebuild")
		check(objects[0].age == processed.objects[0].age and objects[0].cooldown == processed.objects[0].cooldown,"processor lifetime/cooldown retained")

func equipment_custody() -> void:
	var gear := Equipment.new(); check(gear.configure(Mount.new(),"old",4,1,1,0),"old equipment prepared")
	gear.charge=23.0; gear.cooldown=0.7; gear.state="released"
	var custody: Dictionary = gear.custody_state()
	var mount := Mount.new(); var next := Equipment.new()
	check(next.configure(mount,"new",5,0,3,0),"candidate equipment prepared")
	check(next.restore_custody(custody.value).is_empty(),"released custody restored")
	check(not mount.attached and next.state == "released" and next.charge == 23.0 and next.cooldown == 0.7,"drop connection/resources retained")
	check(next.instance_id == gear.instance_id and next.body_id == 4,"equipment token retained with new body binding")
	gear._pending={"request_id":"pending"}
	check(not gear.custody_state().ok,"unsettled pending receipt cannot duplicate")
	gear._pending.clear()
	var retool := Equipment.new(); check(retool.configure(Mount.new(),"new",5,0,3,1),"retool candidate prepared")
	check(not retool.restore_custody(custody.value).is_empty(),"dropped chassis cannot be retooled by reconstruction")

func atomic_sample() -> void:
	var members: Array = []
	for id: int in range(1,9): members.append({"instance_id":id})
	check(Worker.workbench_roster_error({"workbench_sample":{"bodies":members},"workbench_material_players":[{"instance_id":9}]} ) == "workbench_actor_capacity","combined physical+material roster has one eight-actor bound")
	check(Worker.workbench_roster_error({"workbench_sample":{"bodies":[{"instance_id":1},{"instance_id":1}]},"workbench_material_players":[{"instance_id":1}]} ) == "workbench_actor_identity_collision","field cannot borrow a physical actor stable identity")
	check(Worker.workbench_roster_error({"workbench_sample":{"bodies":[{"instance_id":1},{"instance_id":1}]},"workbench_material_players":[{"instance_id":2}]} ).is_empty(),"articulated parts count once in shared roster")
	var worker := Worker.new(); worker._workbench_sample={"session":7,"epoch":4}
	worker._workbench_extent=Vector2i(2048,2048); worker.set_physical_actor_epoch(4)
	var current: Dictionary = frame(12)
	var states := PackedFloat64Array(); states.resize(17); states[10]=1
	var sample: Dictionary = {"session":7,"epoch":4,"states":states,"geometry":PackedFloat64Array(),
		"bodies":[],"equipment_frame":current,"equipment_requests":[request(current)],"effects":[],"emitters":[]}
	var admitted: Dictionary = worker.set_workbench_sample(sample)
	check(admitted.sample_accepted and admitted.queued == 1,"sample and request atomically admitted")
	check(worker.set_workbench_sample({"session":7,"epoch":4}).reason == "sample_layout","malformed joined sample refuses without dictionary exception")
	var malformed: Dictionary = sample.duplicate(true); malformed.effects=3
	check(worker.set_workbench_sample(malformed).reason == "sample_layout","invalid effects type cannot enter mutex-owned queue")
	current.actors[0].position=Vector2.ZERO
	check(worker._workbench_sample.equipment_frame.actors[0].position == Vector2(1536.5,1536.5) and worker._physical_usable_frame.actors[0].position == Vector2(1536.5,1536.5),"copied sample/frame do not alias caller")
	var wrong: Dictionary = sample.duplicate(true); wrong.session=8
	check(not worker.set_workbench_sample(wrong).sample_accepted,"retired coupling owner cannot replace equipment")
	worker.cancel_physical_usable_requests(4)
	check(worker._pending_physical_usables.is_empty(),"cancel retires joined request")
	worker._prepared_physical_frame_hold={"epoch":4,"serial":3}
	var retained: Dictionary = worker._physical_usable_frame.duplicate(true)
	worker.set_physical_actor_epoch(4)
	check(worker._physical_usable_frame == retained,"matching prepared epoch acknowledgement retains staged equipment frame")
	worker.set_physical_actor_epoch(0)
	check(worker._physical_effect_epoch == 4 and worker._physical_usable_frame == retained,"retiring old graph cannot clear new prepared inventory")
	worker._world=null
