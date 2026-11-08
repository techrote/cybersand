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
var direct_stop_finished: bool = false
var direct_stop_receipt: Dictionary = {}


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


func _manual_step_ack(target: int, expected_tick: int, generation: int) -> bool:
	# Serial/flags can settle before the *new* paused native publication.
	# A previously paused snapshot is not the ACK for this manual tick.
	var snapshot: CyberSimulationSnapshot = main.latest_snapshot
	return not workbench.step_pending and not workbench.step_requested \
		and int(main.tower_context.get("workbench_step_serial",-1)) == target \
		and snapshot != null and snapshot.paused and not snapshot.simulation_failed \
		and snapshot.render_world_generation == generation \
		and snapshot.tick_index == expected_tick


func _stop_during_in_flight_step(driver: RefCounted) -> void:
	# Delivered by the engine's deferred queue after step() has admitted its
	# first native tick and yielded waiting for the real worker publication.
	check(driver.active(), "deferred Stop was not delivered to an active step sequence")
	check(workbench.step_requested or workbench.step_pending,
		"deferred Stop did not observe a pending native step request")
	driver.request_stop()


func _retire_during_in_flight_step(driver: RefCounted) -> void:
	# Task revision/scene exit may revoke authority while one native tick
	# is already admitted. This is NOT a Stop ACK: its result is unconfirmed.
	check(driver.active(), "deferred retirement missed the active sequence")
	check(workbench.step_requested or workbench.step_pending,
		"deferred retirement did not observe an admitted native tick")
	driver.retire()


func _await_direct_stop_in_flight(driver: RefCounted) -> void:
	# Exercise the public asynchronous Stop join, not merely request_stop().
	# The existing worker must complete its admitted tick before this yields ACK.
	check(driver.active(), "direct Stop missed the active native sequence")
	check(workbench.step_requested or workbench.step_pending,
		"direct Stop was not delivered during an admitted native tick")
	direct_stop_receipt = await driver.stop()
	direct_stop_finished = true


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
	if not await wait_until(_manual_step_ack.bind(
			manual_serial,initial_tick+5,source.render_world_generation),
			"manual step serial ACK did not publish its exact paused native tick"):
		var actual_snapshot: CyberSimulationSnapshot = main.latest_snapshot
		push_error("WB_AGENT_527_STEP manual pause-publication timeout: " +
			"expected_serial=%d observed_serial=%d pending=%s requested=%s " % [
				manual_serial, int(main.tower_context.get("workbench_step_serial",-1)),
				str(workbench.step_pending), str(workbench.step_requested)] +
			"host_paused=%s native_paused=%s native_tick=%d expected_tick=%d native_generation=%d expected_generation=%d" % [
				str(main.paused), str(actual_snapshot != null and actual_snapshot.paused),
				-1 if actual_snapshot == null else actual_snapshot.tick_index, initial_tick+5,
				-1 if actual_snapshot == null else actual_snapshot.render_world_generation,
				source.render_world_generation])
		finish()
		return
	var after_manual: int = main.latest_snapshot.tick_index
	check(after_manual==initial_tick+5,
		"manual tick not exactly once after refusal")
	# Failure-before controls for the serial-only/paused-only race: a valid
	# serial and paused snapshot MUST NOT acknowledge a different native tick
	# or a replacement native World generation.
	check(_manual_step_ack(manual_serial,after_manual,source.render_world_generation),
		"exact serial, paused native tick and generation were not acknowledged")
	check(not _manual_step_ack(manual_serial,after_manual+1,
			source.render_world_generation),
		"stale paused native snapshot falsely ACKed a future tick")
	check(not _manual_step_ack(manual_serial,after_manual,
			source.render_world_generation+1),
		"paused native snapshot falsely ACKed another World generation")

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

	# The fourth model-visible tool must enforce the exact #526 JSON
	# contract. Neither malformed arguments nor unknown fields may queue a
	# native tick; a genuine accepted tool call remains stoppable at a
	# completed tick ACK, not at command admission.
	var tool_driver = Driver.new()
	var tick_before_tool: int = main.latest_snapshot.tick_index
	for invalid_args: Variant in [null,[],{},{"ticks":"2"},{"ticks":2.0},
			{"ticks":0},{"ticks":121},{"ticks":2,"unexpected":true}]:
		var rejected: Dictionary = await tool_driver.call_step(
			main,workbench,invalid_args)
		check(rejected.get("status")=="refused" and rejected.get("completed",-1)==0,
			"malformed fourth-tool arguments queued native work: "+str(invalid_args))
	check(main.latest_snapshot.tick_index==tick_before_tool,
		"malformed tool arguments changed real native tick")
	var stop_tool_on_two: Callable = func(receipt: Dictionary) -> void:
		if int(receipt.completed)==2:
			tool_driver.request_stop()
	tool_driver.step_completed.connect(stop_tool_on_two)
	var tool_stopped: Dictionary = await tool_driver.call_step(
		main,workbench,{"ticks":5})
	tool_driver.step_completed.disconnect(stop_tool_on_two)
	check(tool_stopped.get("status")=="stopped"
		and tool_stopped.get("reason")=="human_stop"
		and tool_stopped.get("requested")==5 and tool_stopped.get("completed")==2
		and tool_stopped.get("before_tick")==tick_before_tool
		and tool_stopped.get("after_tick")==tick_before_tool+2
		and tool_stopped.get("still_paused")==true,
		"strict model fourth-tool Stop ACK was not actual two native ticks: "
		+str(tool_stopped))
	for _check_frame: int in 4:
		await process_frame
	check(main.latest_snapshot.tick_index==tick_before_tool+2,
		"model-tool Stop completed with an unauthorized later native tick")
	stop_tool_on_two = Callable()
	tool_driver = null

	var max_call = Driver.new()
	var cap: Dictionary = await max_call.step(main,workbench,120)
	check(cap.get("status")=="completed" and cap.get("completed")==120
		and cap.get("after_tick")==after_manual+125
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
	check(final_snapshot.tick_index==initial_tick+130
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
					"actual-paused-native-after-130-ticks.png")) == OK,
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
	# Independently interrupt a genuinely in-flight native tick from the
	# deferred human input path, NOT a synchronous completed-tick callback.
	# Use a fresh World so the original 130-tick framebuffer/proof above
	# remains byte-for-byte semantically unchanged.
	var previous_generation: int = final_snapshot.render_world_generation
	var reopened: Dictionary = Setup.fresh(
		PackedInt32Array(workbench.applied.liquid_policy),Vector2i(512,512))
	if not check(workbench.apply(reopened),"fresh native owner for pending-Stop refused"):
		finish()
		return
	if not await wait_until(
			func() -> bool:
				return _blank_ready() and \
					main.latest_snapshot.render_world_generation != previous_generation,
			"pending-Stop fresh native World was not published paused"):
		finish()
		return
	var pending_source: CyberSimulationSnapshot = main.latest_snapshot
	check(pending_source.tick_index==0 and pending_source.paused,
		"pending-Stop fresh World did not begin at paused native tick zero")
	var pending_driver = Driver.new()
	call_deferred("_stop_during_in_flight_step",pending_driver)
	var in_flight_stop: Dictionary = await pending_driver.step(main,workbench,5)
	check(in_flight_stop.get("status")=="stopped"
		and in_flight_stop.get("reason")=="human_stop"
		and in_flight_stop.get("requested")==5
		and int(in_flight_stop.get("completed",-1))>=1
		and int(in_flight_stop.get("completed",-1))<5
		and in_flight_stop.get("before_tick")==0
		and in_flight_stop.get("after_tick")==in_flight_stop.get("completed")
		and in_flight_stop.get("world_generation")==pending_source.render_world_generation
		and in_flight_stop.get("still_paused")==true,
		"deferred human Stop did not ACK a strict partial native sequence: "
		+str(in_flight_stop))
	for _late_frame: int in 5:
		await process_frame
	check(main.latest_snapshot.tick_index==in_flight_stop.get("after_tick",-1)
		and main.latest_snapshot.paused
		and main.latest_snapshot.render_world_generation==pending_source.render_world_generation,
		"native state changed after deferred human Stop acknowledgment")
	print("WB_AGENT_527_PENDING_STOP_RESULT " + JSON.stringify(in_flight_stop))
	pending_driver = null

	# Lifecycle retirement is distinct from an ACKed human Stop. A native
	# single tick may already be in flight and must settle under the old
	# exclusive World, while the retired driver must NEVER auto-retry or
	# dispatch the rest of its requested batch into this or a new task.
	var retirement_tick: int = main.latest_snapshot.tick_index
	var retirement_driver = Driver.new()
	call_deferred("_retire_during_in_flight_step",retirement_driver)
	var retired_in_flight: Dictionary = await retirement_driver.step(main,workbench,5)
	check(retired_in_flight.get("status")=="unconfirmed"
		and retired_in_flight.get("reason")=="lifecycle_retired_mid_step"
		and retired_in_flight.get("requested")==5
		and retired_in_flight.get("completed")==0
		and retired_in_flight.get("before_tick")==retirement_tick
		and retired_in_flight.get("world_generation")==pending_source.render_world_generation,
		"mid-native-tick lifecycle retirement forged a completed/Stop ACK: "
		+str(retired_in_flight))
	var retired_late: Dictionary = await retirement_driver.call_step(
		main,workbench,{"ticks":1})
	check(retired_late.get("status")=="refused"
		and retired_late.get("reason")=="task_lifecycle_retired"
		and retired_late.get("completed")==0,
		"retired task could schedule a new native Step: "+str(retired_late))
	# The admitted owner tick must finish before we assert native stability.
	# Unlike Stop, the former driver's response cannot claim this tick.
	var retirement_serial: int = workbench.step_serial
	if not await wait_until(_manual_step_ack.bind(retirement_serial,
			retirement_tick+1,pending_source.render_world_generation),
			"retired in-flight native owner did not publish its single paused tick"):
		push_error("WB_AGENT_527_RETIRED_PENDING native publication: " +
			"requested_serial=%d published_serial=%d " % [
				retirement_serial,
				int(main.tower_context.get("workbench_step_serial",-1))] +
			"expected_tick=%d actual_tick=%d native_paused=%s" % [
				retirement_tick+1,main.latest_snapshot.tick_index,
				str(main.latest_snapshot.paused)])
		finish()
		return
	for _retirement_frame: int in 5:
		await process_frame
	check(main.latest_snapshot.tick_index==retirement_tick+1
		and main.latest_snapshot.paused
		and main.latest_snapshot.render_world_generation==pending_source.render_world_generation,
		"retired task dispatched more than the one admitted native tick")
	print("WB_AGENT_527_RETIRED_PENDING_RESULT " + JSON.stringify({
		"result":retired_in_flight,
		"late_step":retired_late,
		"settled_native_tick":main.latest_snapshot.tick_index,
		"world_generation":main.latest_snapshot.render_world_generation}))
	retirement_driver = null

	# Direct trusted-host Stop is asynchronous: it must join the same actual
	# native ACK as step(), not report success at command-admission time.
	# Distinct from request_stop() and task retirement tested above.
	var direct_before: int = main.latest_snapshot.tick_index
	var direct_driver = Driver.new()
	call_deferred("_await_direct_stop_in_flight",direct_driver)
	var direct_step: Dictionary = await direct_driver.step(main,workbench,5)
	if not await wait_until(
			func() -> bool: return direct_stop_finished,
			"public Stop never returned after the admitted native tick"):
		finish()
		return
	check(direct_step.get("status")=="stopped"
		and direct_step.get("reason")=="human_stop"
		and int(direct_step.get("completed",-1))>=1
		and int(direct_step.get("completed",-1))<5
		and direct_step.get("before_tick")==direct_before
		and direct_step.get("after_tick")==direct_before+direct_step.get("completed")
		and direct_step.get("world_generation")==pending_source.render_world_generation,
		"direct asynchronous Stop did not interrupt a bounded native batch: "
		+str(direct_step))
	check(direct_stop_receipt==direct_step
		and direct_stop_receipt.get("status")=="stopped"
		and direct_stop_receipt.get("still_paused")==true,
		"public Stop did not join the truthful native Step receipt: "
		+str(direct_stop_receipt))
	for _direct_frame: int in 5:
		await process_frame
	check(main.latest_snapshot.tick_index==direct_step.get("after_tick",-1)
		and main.latest_snapshot.paused
		and main.latest_snapshot.render_world_generation==pending_source.render_world_generation,
		"public Stop ACK permitted an unauthorized extra native tick")
	print("WB_AGENT_527_DIRECT_STOP_RESULT " + JSON.stringify({
		"step":direct_step,"stop":direct_stop_receipt,
		"settled_native_tick":main.latest_snapshot.tick_index,
		"world_generation":main.latest_snapshot.render_world_generation}))
	direct_driver = null

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
