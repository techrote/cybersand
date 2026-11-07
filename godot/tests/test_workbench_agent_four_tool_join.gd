extends SceneTree
## #527: compositional *real Godot/native* proof against qualified #526
## foundation at a separately pinned source SHA. No standalone mock World.
const Setup = preload("res://scripts/workbench_setup.gd")
const Bridge = preload("res://scripts/workbench_agent_four_tool_bridge.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var main: Control
var workbench: Control
var checks: int = 0
var failures: int = 0


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_AGENT_527_JOIN: "+message)
	return ok


func wait_until(condition: Callable, message: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return check(condition.call(),message)


func _ready() -> bool:
	return main != null and main.shared_workbench != null \
		and not main.shared_workbench.applied.is_empty() \
		and main.paused and main.latest_snapshot != null \
		and not main.shared_workbench.busy()


func _blank_ready() -> bool:
	return main.pending_microscenario_apply.is_empty() \
		and not workbench.applied.is_empty() \
		and main.world_extent == Vector2i(512,512) \
		and not workbench.busy() and main.paused \
		and main.latest_snapshot != null and main.latest_snapshot.paused


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if not await wait_until(Callable(self,"_ready"),
			"actual Godot workbench did not initialize"):
		finish()
		return
	workbench = main.shared_workbench
	var blank: Dictionary = Setup.fresh(
		PackedInt32Array(workbench.applied.liquid_policy),Vector2i(512,512))
	if not check(workbench.apply(blank),"actual native blank canvas refused"):
		finish()
		return
	if not await wait_until(Callable(self,"_blank_ready"),
			"blank native owner did not acknowledge pause"):
		finish()
		return
	var first_generation: int = main.latest_snapshot.render_world_generation
	var before_tick: int = main.latest_snapshot.tick_index
	var bridge = Bridge.new()
	if not check(bridge.bind(main),"qualified #526 host adapter missing/unavailable"):
		finish()
		return
	# Only the human host authorizes this task. Never expose this call as a
	# model tool; protected motif remains outside the editable rectangle.
	var authorized: Dictionary = await bridge.authorize_task(
		"joined-real-native-527",Rect2i(24,24,48,48),
		[Rect2i(66,66,3,3)],[0,58])
	check(authorized.get("status")=="authorized",
		"real #526 worker did not authorize task: "+str(authorized))
	var invalid: Dictionary = await bridge.call_tool("step",{"ticks":1.0})
	check(invalid.get("status")=="refused"
		and invalid.get("completed",0)==0,
		"fourth tool accepted float count")
	var observation: Dictionary = await bridge.call_tool("observe",{
		"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"})
	check(observation.get("status")=="observed"
		and observation.get("image_status")=="matched_post_draw"
		and observation.get("framebuffer_png",PackedByteArray()).size()>8,
		"real native/render observe refused: "+str(observation.get("reason","")))
	var prepared: Dictionary = {}
	var applied: Dictionary = {}
	if observation.get("status")=="observed":
		prepared = await bridge.call_tool("prepare_edit",{
			"observation_id":observation.observation_id,
			"operations":[{"shape":"rectangle","x0":30,"y0":30,
				"x1":32,"y1":32,"material":58,
				"replace_only_material":null}]})
		check(prepared.get("status")=="proposed"
			and prepared.get("changed_cells",-1)==9,
			"prepare mutated/refused real native nine-cell construction: "+str(prepared))
		if prepared.get("status")=="proposed":
			# Regression: wrong-ID apply is host-refused before #526 can
			# consume the genuine native proposal; Step must remain fenced.
			var wrong_apply: Dictionary = await bridge.call_tool("apply_edit",{
				"proposal_id":"wrong-proposal-id-527"})
			check(wrong_apply.get("status")=="refused"
				and wrong_apply.get("reason")=="proposal_not_preflight_recordable",
				"wrong-ID proposal was not refused by #526 owner: "+str(wrong_apply))
			var refused_step: Dictionary = await bridge.call_tool("step",{"ticks":1})
			check(refused_step.get("status")=="refused"
				and refused_step.get("reason")==
				"prepared_edit_must_be_applied_or_retired_before_step"
				and main.latest_snapshot.tick_index==before_tick,
				"wrong-ID apply unlocked native Step across pending proposal")
			var blocked_step: Dictionary = await bridge.call_tool("step",{"ticks":1})
			check(blocked_step.get("status")=="refused"
				and blocked_step.get("reason")=="prepared_edit_must_be_applied_or_retired_before_step"
				and main.latest_snapshot.tick_index==before_tick,
				"agent Step ran despite a live unconsumed native edit proposal")
			applied = await bridge.call_tool("apply_edit",{
				"proposal_id":prepared.proposal_id})
			check(applied.get("status")=="applied"
				and applied.get("authored_start",{}).get("status")=="recorded"
				and applied.get("changed_cells",-1)==9,
				"prepared real native material was not applied and saved: "+str(applied))
	var stepped: Dictionary = await bridge.call_tool("step",{"ticks":4})
	check(stepped.get("status")=="completed"
		and stepped.get("completed")==4
		and stepped.get("requested")==4
		and stepped.get("before_tick")==before_tick
		and stepped.get("after_tick")==before_tick+4
		and stepped.get("still_paused")==true,
		"fourth tool did not ACK exactly four completed native ticks: "+str(stepped))
	# The exact #526 source may not republish a frame on a paused tick
	# without a material change. Do not fabricate a matched image. Native
	# Step is separately executable; post-step visual identity stays HOLD
	# until #526 provides an actual same-tick render publication.
	var matched: Dictionary = stepped.get("observation",{})
	var matched_frame: bool = stepped.get("observation_status")=="observed"
	if matched_frame:
		check(matched.get("image_status")=="matched_post_draw"
			and int(matched.get("native_counts",{}).get(58,0))>=9,
			"Step's purported matched observation lacked real native facts")
	else:
		check(stepped.get("observation_status")=="pending"
			and matched.get("reason")=="matching_post_draw_frame_not_available"
			and matched.get("framebuffer_png",PackedByteArray()).is_empty(),
			"Step returned an unexpected or falsely matched post-tick frame: "+str(matched))
		print("WB_AGENT_527_POST_STEP_RENDER_HOLD "+
			JSON.stringify({"reason":matched.get("reason"),"native_ticks":4}))
	# Human Stop while the REAL fourth tool is inside a native tick
	# sequence. The Stop coroutine begins at the second published ACK,
	# prohibits a third command, then waits for #526 retirement before it
	# signals acknowledgement. No main/worker/native source is patched.
	var stop_receipts: Array = []
	var native_step_driver: RefCounted = bridge.get("_step_driver")
	var stop_at_second: Callable = func(ack: Dictionary) -> void:
		if int(ack.completed)==2:
			bridge.stop()
	var consume_stop: Callable = func(answer: Dictionary) -> void:
		stop_receipts.append(answer.duplicate(true))
	native_step_driver.step_completed.connect(stop_at_second)
	bridge.stop_acknowledged.connect(consume_stop)
	var interrupted: Dictionary = await bridge.call_tool("step",{"ticks":10})
	native_step_driver.step_completed.disconnect(stop_at_second)
	check(interrupted.get("status")=="stopped"
		and interrupted.get("reason")=="human_stop"
		and interrupted.get("requested")==10
		and interrupted.get("completed")==2
		and interrupted.get("before_tick")==before_tick+4
		and interrupted.get("after_tick")==before_tick+6,
		"concurrent Stop did not fence remaining eight native ticks: "+str(interrupted))
	await wait_until(func() -> bool: return stop_receipts.size()==1,
		"Stop never received genuine #526 native retirement ACK")
	var stopped: Dictionary = stop_receipts[0] if not stop_receipts.is_empty() else {}
	check(stopped.get("status")=="stopped"
		and stopped.get("no_further_agent_mutations")==true,
		"Stop did not consume real #526 task retirement ACK: "+str(stopped))
	bridge.stop_acknowledged.disconnect(consume_stop)
	stop_at_second = Callable()
	consume_stop = Callable()
	for _frame: int in 4:
		await process_frame
	check(main.latest_snapshot.tick_index==before_tick+6
		and main.latest_snapshot.render_world_generation==first_generation
		and main.paused,"Stop ACK allowed a seventh native tick")
	var late: Dictionary = await bridge.call_tool("apply_edit",{
		"proposal_id":prepared.get("proposal_id","old")})
	check(late.get("status")=="refused",
		"late model tool mutated after human Stop ACK")
	# A revised task must be a new owner binding, not a stale callback on the
	# retired driver. No physics World reset or saved-authoring rollback.
	var second = Bridge.new()
	check(second.bind(main),"revised task could not rebind actual native host")
	var revised: Dictionary = await second.authorize_task(
		"joined-revised-task-527",Rect2i(24,24,48,48),[],[0,58])
	check(revised.get("status")=="authorized",
		"new task authorization incorrectly retained old revoked proposal")
	var new_observation: Dictionary = await second.call_tool("observe",{
		"region":{"x":28,"y":28,"width":8,"height":8},"detail":"counts"})
	var revised_matched: bool = new_observation.get("status")=="observed"
	if revised_matched:
		check(int(new_observation.get("native_counts",{}).get(58,0))==9,
			"revised task lost nine authenticated Hard Wall cells")
	else:
		check(new_observation.get("status")=="pending"
			and new_observation.get("reason")=="matching_post_draw_frame_not_available"
			and new_observation.get("framebuffer_png",PackedByteArray()).is_empty(),
			"revised task returned stale/invalid post-step framebuffer: "+
			str(new_observation))
		print("WB_AGENT_527_REVISED_RENDER_HOLD "+
			JSON.stringify({"reason":new_observation.get("reason"),
				"native_ticks":main.latest_snapshot.tick_index}))
	# A real human paint admission BETWEEN model calls must retire the
	# previous authorized model task. The old Step driver would otherwise
	# capture the already-changed owner revision as a new baseline and
	# incorrectly step on the human's canvas. No native tick may be queued.
	var paint_revision: int = main.simulation_worker.agent_manual_intent_revision()
	var paint_tick: int = main.latest_snapshot.tick_index
	check(main.simulation_worker.queue_emit_disc(44,44,0,58),
		"real human Hard Wall brush intent was refused")
	check(main.simulation_worker.agent_manual_intent_revision()==paint_revision+1,
		"human brush did not advance exclusive native manual-intent fence")
	var stale_step: Dictionary = await second.call_tool("step",{"ticks":1})
	check(stale_step.get("status")=="refused"
		and stale_step.get("reason")=="manual_intent_changed_requires_reauthorization"
		and main.latest_snapshot.tick_index==paint_tick,
		"stale model Step ran across human brush admission: "+str(stale_step))
	var stale_observe: Dictionary = await second.call_tool("observe",{
		"region":{"x":28,"y":28,"width":8,"height":8},"detail":"counts"})
	check(stale_observe.get("status")=="refused"
		and stale_observe.get("reason")=="manual_intent_changed_requires_reauthorization",
		"old task received a new observation after human brush: "+str(stale_observe))
	for _settle: int in 12:
		await process_frame
	check(main.latest_snapshot.tick_index==paint_tick,
		"agent left an unacknowledged native tick after human brush refusal")
	var second_stopped: Dictionary = await second.stop()
	check(second_stopped.get("status")=="stopped",
		"revised task retirement was not acknowledged")
	if observation.get("status")=="observed":
		var evidence_dir: String = OS.get_environment("WB_AGENT_527_IMAGE_DIR")
		if not evidence_dir.is_empty():
			var png: PackedByteArray = observation.framebuffer_png
			var file: FileAccess = FileAccess.open(evidence_dir.path_join(
				"original-native-matched-before-step.png"),FileAccess.WRITE)
			if check(file != null,"could not open original screenshot evidence"):
				file.store_buffer(png)
				file.close()
	print("WB_AGENT_527_FOUR_TOOL_RESULT "+JSON.stringify({
		"checks":checks,"failures":failures,
		"generation":first_generation,
		"before_tick":before_tick,
		"after_tick":main.latest_snapshot.tick_index,
		"stop_mid_sequence_completed":interrupted.get("completed",-1),
		"native_backend":main.latest_snapshot.backend_name,
		"configured_workers":main.latest_snapshot.native_worker_request,
		"first_task_status":stopped.get("status"),
		"revised_task_status":second_stopped.get("status"),
		"post_step_matched_render_gate":"PASS" if matched_frame else "HOLD",
		"revised_matched_render_gate":"PASS" if revised_matched else "HOLD"}))
	finish()


func finish() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame
	print("WB_AGENT_527_JOIN: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
