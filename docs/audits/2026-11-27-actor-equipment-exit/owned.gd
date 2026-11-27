extends SceneTree

# Real native 2048x1024 material/mask qualification through the production
# worker consumers. No sampled actor extent contract is widened by this path.
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const SampledEffects = preload("res://scripts/actor_rig_effects.gd")
const SampledUsables = preload("res://scripts/usable_runtime.gd")
const EXTENT := Vector2i(2048,1024)
const EPOCH: int = 29
var world_lifetimes: Array[WeakRef] = []
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WB_EQUIPMENT_EXTENT: " + label)


func create() -> CyberSimulationWorker:
	var worker := Worker.new()
	world_lifetimes.append(weakref(worker._world))
	check(worker._world.get_class() == "CyberNativeCellWorld","real native extension required")
	check(worker._world.diagnostic_reset({"workers":1,"extent":EXTENT}),"2048x1024 native landscape initialized")
	worker._workbench_extent = EXTENT
	worker.set_physical_actor_epoch(EPOCH)
	return worker


func mask(worker: CyberSimulationWorker, center: Vector2) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	Coupling.append_input(states,1,center,0.0,Vector2(4,4),Vector2.ZERO,0.0,1.0,1)
	worker._world.prepare_rigid_body_coupling(states,false)
	check(worker._world.rigid_body_id_at(int(center.x),int(center.y)) == 1,"native source body exists at far-right coordinate")
	return states


func effect(sequence: int, kind: String, origin: Vector2 = Vector2(1806.5,100.5)) -> Dictionary:
	return {"actor_slot":0,"epoch":EPOCH,"sequence":sequence,"kind":kind,
		"source":Vector2(1800.5,100.5),"origin":origin,"source_body_id":1,
		"source_part":0,"radius":2,"strength":1.0,"material":2}


func consume_effect(worker: CyberSimulationWorker, request: Dictionary, states: PackedFloat32Array) -> Array:
	check(worker.set_rigid_body_states(states,EPOCH,[request]).queued == 1,"physical ability queued through existing owner")
	var packets: Array = worker._pending_physical_effects.duplicate(true)
	worker._pending_physical_effects.clear()
	worker._consume_physical_effects(packets,EPOCH)
	return worker._physical_effect_receipts.duplicate(true)


func equipment_frame(index: int, center: Vector2) -> Dictionary:
	return {"version":1,"run_id":"landscape-equipment","epoch":EPOCH,"tick":0,"suspended":false,
		"devices":[],"actors":[{"actor_id":0,"generation":0,"equipment_epoch":1,
			"instance_id":"landscape-item","usable_index":index,"state":"held","body_id":1,
			"position":center,"rotation":0.0,"half_extents":Vector2(2,2),
			"muzzle":center+Vector2(4,0),"direction":Vector2.RIGHT,"owner_origin":center-Vector2(8,0),
			"active":true,"lease_deadline":100,"parts":[{"body_id":1,"position":center,
				"rotation":0.0,"half_extents":Vector2(2,2)}]}]}


func consume_equipment(worker: CyberSimulationWorker, frame: Dictionary, states: PackedFloat32Array) -> Dictionary:
	var request: Dictionary = {"version":1,"run_id":frame.run_id,"epoch":EPOCH,"sequence":1,
		"request_id":"landscape-request","operation":"use","power":1.0}
	for key: String in ["actor_id","generation","equipment_epoch","instance_id","usable_index","body_id"]:
		request[key] = frame.actors[0][key]
	var admitted: Dictionary = worker.set_physical_usable_state(frame,[request],states)
	check(admitted.queued == 1,"ACT005 request admitted against exact current physical frame")
	var copied: Array = worker._pending_physical_usables.duplicate(true)
	worker._pending_physical_usables.clear()
	worker._consume_physical_usables(copied,EPOCH,true)
	return worker._physical_usables.snapshot()


func run() -> void:
	var worker := create()
	var states := mask(worker,Vector2(1800.5,100.5))
	var receipts := consume_effect(worker,effect(1,"deposit"),states)
	check(receipts.size() == 1 and receipts[0].changed_cells == 13 and worker._world.material_at(1806,100) == 2,
		"ACT004 depositor changes real far-right native cells")
	receipts = consume_effect(worker,effect(2,"dig"),states)
	check(receipts[0].changed_cells > 0 and worker._world.material_at(1806,100) == 0,
		"ACT004 reuses existing bounded excavation beyond x1024")
	receipts = consume_effect(worker,effect(3,"blast",Vector2(1806.5,108.5)),states)
	check(receipts[0].changed_cells > 0 and worker._world.material_at(1806,108) == 6,
		"ACT004 existing blast keeps its legitimate far-right material effect")
	var before: int = worker._world.get_revision()
	receipts = consume_effect(worker,effect(4,"deposit",Vector2(2048.0,100.0)),states)
	check(receipts[0].reason == "position" and worker._world.get_revision() == before,
		"outside accepted finite canvas refuses before any native material write")
	var sampled := SampledEffects.new()
	sampled.apply(worker._world,SampledEffects.BLAST,Vector2(1806.5,116.5),2)
	check(sampled.kind == SampledEffects.NONE and worker._world.material_at(1806,116) == 0,
		"sampled effect default remains the existing1024-square contract")
	check(not SampledUsables.new()._inside_world(Vector2i(1800,100)),"sampled usable extent remains unchanged")
	worker = create()
	states = mask(worker,Vector2(1800.5,100.5))
	var result := consume_equipment(worker,equipment_frame(2,Vector2(1800.5,100.5)),states)
	check(result.receipts.size() == 1 and result.receipts[0].accepted and result.write_count_last > 0,
		"ACT005 Cement Extruder writes real material in the far-right landscape")
	check(worker._world.rigid_body_id_at(1800,100) == 1 and worker._world.stored_material_at(1800,100) == 0,
		"far-right equipment cannot edit beneath its native source mask")
	worker = create()
	states = mask(worker,Vector2(1800.5,100.5))
	result = consume_equipment(worker,equipment_frame(12,Vector2(1800.5,100.5)),states)
	check(result.receipts[0].accepted and result.projectiles.size() == 1 \
		and result.projectiles[0].position.x > 1024,"ACT005 projectile launch retains real far-right physical muzzle")
	worker = create()
	states = mask(worker,Vector2(2044.5,100.5))
	before = worker._world.get_revision()
	result = consume_equipment(worker,equipment_frame(2,Vector2(2044.5,100.5)),states)
	check(not result.receipts[0].accepted and result.write_count_last == 0 and worker._world.get_revision() == before,
		"ACT005 muzzle outside exact2048 boundary refuses without material mutation")
	worker = null
	sampled = null
	await process_frame
	await process_frame
	for entry in world_lifetimes:
		check(entry.get_ref() == null,"native equipment World retired")
	print("Workbench actor equipment extent: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
