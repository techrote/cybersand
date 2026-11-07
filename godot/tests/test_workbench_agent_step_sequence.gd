extends SceneTree

## WB-AGENT #527: actual Godot shared workbench + GDExtension World.
## Unlike the #527 pure C++ reference, this exercises existing manual
## Step -> physics callback -> exclusive simulation worker -> tick/ACK.
## No mock World, mock native tick, network/model, or new scheduler.
const Setup = preload("res://scripts/workbench_setup.gd")
const Driver = preload("res://scripts/workbench_agent_step_sequence.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var main: Control
var workbench: Control
var failures: int = 0
var checks: int = 0


func check(condition: bool, reason: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("WB_AGENT_527_STEP: " + reason)
	return condition


func wait_until(predicate: Callable, reason: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return check(predicate.call(), reason)


func _ready() -> bool:
	return is_instance_valid(main) and main.shared_workbench != null \
		and not main.shared_workbench.applied.is_empty() \
		and main.paused and main.latest_snapshot != null \
		and not main.shared_workbench.busy()


func _blank_ready() -> bool:
	return main.pending_microscenario_apply.is_empty() \
		and not workbench.applied.is_empty() \
		and workbench.applied.extent == [512,512] \
		and main.world_extent == Vector2i(512,512) \
		and not workbench.busy() and main.paused \
		and main.latest_snapshot != null and main.latest_snapshot.paused


func _manual_step_ack(target: int) -> bool:
	return not workbench.step_pending and not workbench.step_requested \
		and int(main.tower_context.get("workbench_step_serial",-1)) == target


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if not await wait_until(Callable(self,"_ready"),"shared workbench did not initialize"):
		finish()
		return
	workbench = main.shared_workbench
	var fresh: Dictionary = Setup.fresh(
		PackedInt32Array(workbench.applied.liquid_policy), Vector2i(512,512))
	if not check(workbench.apply(fresh),"real blank native session was refused"):
		finish()
		return
	if not await wait_until(Callable(self,"_blank_ready"),"native blank setup did not install paused"):
		finish()
		return
	var source: CyberSimulationSnapshot = main.latest_snapshot
	check(source.render_world_generation > 0 and not source.simulation_failed,
		"no authoritative native generation")
	print("WB_AGENT_527_STEP_RUNTIME generation=%d initial_tick=%d backend=%s" % [
		source.render_world_generation, source.tick_index,source.backend_name])

	var driver = Driver.new()
	var initial_tick: int = main.latest_snapshot.tick_index
	for invalid: Variant in [0,-1,121,1.5,"3",null]:
		var rejection: Dictionary = await driver.step(main,workbench,invalid)
		check(rejection.get("status")=="refused" and rejection.get("completed",0)==0,
			"invalid tick count was accepted: "+str(invalid))
	check(main.latest_snapshot.tick_index==initial_tick,
		"invalid count mutated native ticks")

	var first: Dictionary = await driver.step(main,workbench,1)
	check(first.get("status")=="completed" and first.get("completed")==1
		and first.get("after_tick",-1)==initial_tick+1
		and first.get("still_paused")==true,
		"actual native one-tick ACK failed: "+str(first))
	var triple: Dictionary = await driver.step(main,workbench,3)
	check(triple.get("status")=="completed" and triple.get("completed")==3
		and triple.get("before_tick",-1)==initial_tick+1
		and triple.get("after_tick",-1)==initial_tick+4,
		"actual native three-tick ACK failed: "+str(triple))

	# One real human Step in flight must block the agent Step dispatcher.
	check(workbench.step_once(),"manual one-tick request refused")
	var busy_result: Dictionary = await driver.step(main,workbench,2)
	check(busy_result.get("status")=="refused"
		and busy_result.get("reason")=="owner_step_or_edit_busy"
		and busy_result.get("completed")==0,
		"agent stepped concurrently with manual owner step: "+str(busy_result))
	var manual_serial: int = workbench.step_serial
	await wait_until(_manual_step_ack.bind(manual_serial),
		"manual step did not complete with actual native ACK")
	var after_manual: int = main.latest_snapshot.tick_index
	check(after_manual==initial_tick+5,
		"manual tick not exactly once after refusal")

	# Stop after the third *ACKed real native tick*, not after scheduling.
	# The callback is synchronous at this acknowledgment boundary; it
	# deterministically revokes ticks 4..10 without a polling race.
	var interrupted = Driver.new()
	var stop_on_third: Callable = func(receipt: Dictionary) -> void:
		if int(receipt.completed)==3:
			interrupted.request_stop()
	interrupted.step_completed.connect(stop_on_third)
	var stopped: Dictionary = await interrupted.step(main,workbench,10)
	interrupted.step_completed.disconnect(stop_on_third)
	check(stopped.get("status")=="stopped"
		and stopped.get("reason")=="human_stop" and stopped.get("completed")==3
		and stopped.get("before_tick")==after_manual
		and stopped.get("after_tick")==after_manual+3
		and stopped.get("still_paused")==true,
		"Stop passed an extra boundary or acknowledged early: "+str(stopped))
	for _frame: int in 5:
		await process_frame
	check(main.latest_snapshot.tick_index==after_manual+3,
		"native World continued AFTER Stop ACK")

	var max_call = Driver.new()
	var cap: Dictionary = await max_call.step(main,workbench,120)
	check(cap.get("status")=="completed" and cap.get("completed")==120
		and cap.get("after_tick")==after_manual+123
		and cap.get("still_paused")==true,
		"maximum bounded real native 120-tick call failed: "+str(cap))
	var idle_stop: Dictionary = await max_call.stop()
	check(idle_stop.get("status")=="refused" and idle_stop.get("reason")=="no_active_step_sequence",
		"idle local Stop forged a native boundary ACK")
	# Task revision / scene lifecycle must fence *all* future delayed uses of
	# the old driver even if no native tick was in flight at retirement.
	max_call.retire()
	var stale_driver: Dictionary = await max_call.step(main,workbench,1)
	check(stale_driver.get("status")=="refused"
		and stale_driver.get("reason")=="task_lifecycle_retired"
		and stale_driver.get("completed",0)==0,
		"retired task re-admitted late native Step: "+str(stale_driver))
	var final_snapshot: CyberSimulationSnapshot = main.latest_snapshot
	check(final_snapshot.tick_index==initial_tick+128
		and final_snapshot.paused and not final_snapshot.simulation_failed,
		"native completed tick total differs from ACKs")
	# Original OpenGL viewport evidence; image is a visual receipt, not
	# independent proof of matching native material IDs. #526 owns that join.
	var image_dir: String = OS.get_environment("WB_AGENT_527_IMAGE_DIR")
	if not image_dir.is_empty():
		await RenderingServer.frame_post_draw
		var image: Image = main.get_viewport().get_texture().get_image()
		if check(image != null and not image.is_empty(),
				"actual OpenGL viewport capture returned no image"):
			check(image.save_png(image_dir.path_join(
					"actual-paused-native-after-128-ticks.png")) == OK,
				"could not preserve original workbench PNG")
	print("WB_AGENT_527_STEP_RESULT " + JSON.stringify({
		"checks":checks,"failures":failures,
		"world_generation":final_snapshot.render_world_generation,
		"initial_native_tick":initial_tick,
		"final_native_tick":final_snapshot.tick_index,
		"configured_workers":final_snapshot.native_worker_request,
		"backend":final_snapshot.backend_name,
		"stop_completed":stopped.get("completed",-1),
		"bounded_call_completed":cap.get("completed",-1),
		"paused":final_snapshot.paused}))
	# Release the test's self-capturing Stop callback before shutting down:
	# RefCounted signal -> closure -> driver otherwise retains a cycle.
	stop_on_third = Callable()
	interrupted = null
	driver = null
	max_call = null
	finish()


func finish() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame
	print("WB_AGENT_527_STEP: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
