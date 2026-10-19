extends SceneTree

const Worker = preload("res://scripts/simulation_worker.gd")
const Catalog = preload("res://scripts/usable_catalog.gd")
const SPAWN := Vector2(800.0, 20.0)

var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_USABLE_INTEGRATION: " + message)

func _wait_for(predicate: Callable, timeout_ms: int = 15000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call():
			return true
	return false

func _frame(worker: CyberSimulationWorker, paused: bool) -> void:
	worker.set_frame_state(0.0, false, paused, Vector2i(800,40),
		Vector2i(720,0), Vector2i(160,100), 0, 0, true, true, true)

func _worker_integration() -> void:
	var worker := Worker.new()
	_frame(worker,true)
	_expect(worker.start_worker(SPAWN) == OK, "worker did not start")
	var receipt: int = worker.queue_actor_prototype_reset(
		[{"model":&"runner","producer":&"human","position":SPAWN}], SPAWN
	)
	_expect(receipt > 0, "actor reset was refused")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_prototype_reset_serial >= receipt
	), "actor reset receipt was not published")
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(initial != null and initial.actor_prototype_reset_applied, "actor reset did not apply")
	_expect(not initial.actor_usables.is_empty(), "worker did not publish usable session")
	_expect(int(initial.actor_usables.catalogue_size) == 32, "published catalogue size is wrong")
	_expect(int(initial.actor_usables.equipped[0]) == -1, "fresh actor reset unexpectedly retained equipment")

	_frame(worker,false)
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and int(snapshot.actor_prototypes.get("tick",0)) >= 3
	), "actor session did not advance")
	var live: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var actors: Dictionary = live.actor_prototypes
	var brick: int = Catalog.index_for(&"brick_stamper")
	_expect(not worker.submit_actor_usable_action(0,int(actors.epoch),1,int(actors.tick),
		brick,Vector2.RIGHT,1.0,false,false,6,&"policy"), "wrong producer equipment command was accepted")
	_expect(worker.submit_actor_usable_action(0,int(actors.epoch),1,int(actors.tick),
		brick,Vector2.RIGHT,1.0,false,false,6,&"human"), "human equipment selection was refused")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and not snapshot.actor_usables.is_empty() 			and int(snapshot.actor_usables.equipped[0]) == brick
	), "worker did not acknowledge equipped Brick Stamper")
	live = worker.take_latest_snapshot(0)
	actors = live.actor_prototypes
	var equipment: Dictionary = live.actor_usables
	var retained: Dictionary = equipment.duplicate(true)
	var seq: int = int(equipment.sequences[0]) + 1
	_expect(worker.submit_actor_usable_action(0,int(actors.epoch),seq,int(actors.tick),
		brick,Vector2.RIGHT,1.0,true,false,6,&"human"), "short usable press was refused")
	_expect(worker.submit_actor_usable_action(0,int(actors.epoch),seq+1,int(actors.tick),
		brick,Vector2.RIGHT,1.0,false,false,6,&"human"), "short usable release was refused")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		if snapshot == null or snapshot.actor_usables.is_empty():
			return false
		var actor_rows: Array = snapshot.actor_usables.get("actors", [])
		return not actor_rows.is_empty() and str(actor_rows[0].get("last_result", "")) == "applied"
	), "quick click did not produce owner-side material work")
	_expect(equipment == retained, "later owner tick mutated retained usable snapshot")

	# A committed timer projectile persists across input cancellation and freezes on pause.
	live = worker.take_latest_snapshot(0)
	actors = live.actor_prototypes
	equipment = live.actor_usables
	var airburst: int = Catalog.index_for(&"timer_airburst")
	seq = int(equipment.sequences[0]) + 1
	_expect(worker.submit_actor_usable_action(0,int(actors.epoch),seq,int(actors.tick),
		airburst,Vector2.RIGHT,1.0,false,false,6,&"human"), "airburst equip was refused")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		if snapshot == null or snapshot.actor_usables.is_empty():
			return false
		var rows: Array = snapshot.actor_usables.get("actors", [])
		return (
			not rows.is_empty()
			and int(snapshot.actor_usables.equipped[0]) == airburst
			and float(rows[0].get("cooldown", 1.0)) <= 0.0
		)
	), "airburst equip/cooldown did not become ready")
	live = worker.take_latest_snapshot(0)
	actors = live.actor_prototypes
	equipment = live.actor_usables
	seq = int(equipment.sequences[0]) + 1
	_expect(worker.submit_actor_usable_action(0,int(actors.epoch),seq,int(actors.tick),
		airburst,Vector2.RIGHT,0.7,true,false,6,&"human"), "airburst press was refused")
	_expect(worker.submit_actor_usable_action(0,int(actors.epoch),seq+1,int(actors.tick),
		airburst,Vector2.RIGHT,0.7,false,false,6,&"human"), "airburst release was refused")
	var committed_visible: bool = await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_usables.projectiles.size() == 1
	)
	_expect(committed_visible, "committed airburst did not appear")
	if not committed_visible:
		worker.stop_worker()
		return
	_frame(worker,true)
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.paused and snapshot.actor_prototypes.suspended
	), "pause did not publish")
	var paused: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var paused_projectiles: Array = paused.actor_usables.get("projectiles", [])
	_expect(paused_projectiles.size() == 1, "pause did not retain committed projectile")
	if paused_projectiles.size() != 1:
		worker.stop_worker()
		return
	var age: float = float(paused_projectiles[0].age)
	await create_timer(0.12).timeout
	var still_paused: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var still_projectiles: Array = still_paused.actor_usables.get("projectiles", [])
	_expect(still_projectiles.size() == 1, "pause deleted committed projectile")
	if still_projectiles.size() == 1:
		_expect(is_equal_approx(float(still_projectiles[0].age), age), "pause advanced usable simulation time")
	worker.stop_worker()

func _desktop_surface() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_expect(packed != null, "main scene did not load")
	if packed == null:
		return
	var desktop = packed.instantiate()
	root.add_child(desktop)
	await process_frame
	_expect(desktop.actor_prototype_panel != null, "actor panel missing")
	_expect(desktop.actor_prototype_panel.usable_choice.item_count == 33, "F5 equipment picker does not expose None + 32 usables")
	_expect(desktop.usable_overlay != null, "usable overlay missing")
	desktop.paused = true
	_expect(not desktop.apply_actor_equipment_configuration(0,1.0), "paused desktop accepted equip-only command")
	desktop.queue_free()
	await process_frame

func _run() -> void:
	await _worker_integration()
	await _desktop_surface()
	print("ACTOR_USABLE_INTEGRATION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
