extends SceneTree

# Graphical owner-rate control. An unpaced native test lives in pool_throughput.gd.
const Setup = preload("res://scripts/workbench_setup.gd")
var host
var measuring := false
var callbacks := 0
var stale_render_acks := 0

func _initialize() -> void:
	run.call_deferred()

func wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func observe_physics() -> void:
	if not measuring: return
	callbacks += 1
	var awaited: int = host._workbench_wait_sample
	if awaited < 0: return
	var latest: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
	if latest != null and latest.lab_context.get("workbench_completed_sample",-1) == awaited \
			and host.tower_context.get("workbench_completed_sample",-1) != awaited:
		stale_render_acks += 1

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	var panel = host.shared_workbench
	if not await wait_until(func(): return not panel.applied.is_empty()):
		quit(1)
		return
	var setup: Dictionary = panel.applied.duplicate(true)
	setup.actors = [Setup.instance("scooper",1,Vector2(1400,1250)),
		Setup.instance("needle",2,Vector2(80,150)),Setup.instance(Setup.BARREL,3,Vector2(1480,1250))]
	setup.selected = 1
	setup.next_id = 4
	var stamps := int(OS.get_environment("WORKBENCH_PACE_STAMPS"))
	match stamps:
		0: pass
		16:
			for y: int in 2:
				for x: int in 8: setup.edits.append([64+x*256,90+y*960,20,2 if (x+y)%2==0 else 14])
		96:
			for y: int in 8:
				for x: int in 12: setup.edits.append([700+x*36,500+y*36,20,2 if (x+y)%2==0 else 14])
		_:
			push_error("Choose 0, 16 or 96 powder stamps.")
			quit(1)
			return
	if not panel.apply(setup) or not await wait_until(func(): return host.physical_actor_session != null and not panel.busy()):
		quit(1)
		return
	host.simulation_worker.set_worker_participation_sampling(true)
	if not panel.toggle_pause() or not await wait_until(func(): return host.latest_snapshot.tick_index >= 3):
		quit(1)
		return
	physics_frame.connect(observe_physics)
	var native_start: int = host.latest_snapshot.tick_index
	var rapier_start: int = host.physical_actor_session.tick
	var frames := 0
	var start := Time.get_ticks_usec()
	print("PACE_BEGIN")
	measuring = true
	while Time.get_ticks_usec()-start < 5000000:
		await process_frame
		frames += 1
	measuring = false
	var elapsed := (Time.get_ticks_usec()-start)/1e6
	print("PACE_END ",JSON.stringify({"stamps":stamps,"seconds":elapsed,"render_fps":frames/elapsed,
		"native_ticks":host.latest_snapshot.tick_index-native_start,"rapier_steps":host.physical_actor_session.tick-rapier_start,
		"physics_callbacks":callbacks,"completed_ahead_of_render":stale_render_acks,"failed":host.latest_snapshot.simulation_failed}))
	var failed: bool = host.latest_snapshot.simulation_failed
	host.free()
	quit(1 if failed else 0)
