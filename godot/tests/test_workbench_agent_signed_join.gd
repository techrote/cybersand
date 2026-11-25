extends SceneTree
## WB-AGENT #527 independent SOURCE-COMPOSED experimental signed-domain JOIN.
## Real exclusive Godot/native World, genuine post-draw PNG and native material
## readback. This is NOT the immutable signed Sand-hopper physical-parity test.
## #526 owns coordinate translation, task authoring and native receipts.
const Setup = preload("res://scripts/workbench_setup.gd")
const Bridge = preload("res://scripts/workbench_agent_four_tool_bridge.gd")
const SignedFrame = preload("res://scripts/workbench_agent_signed_frame.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var main: Control
var workbench: Control
var checks: int = 0
var failures: int = 0


func check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("WB_AGENT_527_SIGNED_JOIN: " + description)
	return condition


func _initial_ready() -> bool:
	return main != null and main.shared_workbench != null \
		and not main.shared_workbench.applied.is_empty() \
		and main.latest_snapshot != null and main.paused \
		and not main.shared_workbench.busy()


func _signed_ready() -> bool:
	return main != null and main.shared_workbench != null \
		and not main.shared_workbench.applied.is_empty() \
		and main.shared_workbench.applied.get("extent",[]) == [2048,2048] \
		and main.world_extent == Vector2i(2048,2048) \
		and main.latest_snapshot != null and main.latest_snapshot.paused \
		and main.pending_microscenario_apply.is_empty() \
		and not main.shared_workbench.busy()


func wait_for(predicate: Callable, description: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return check(predicate.call(),description)


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if not await wait_for(Callable(self,"_initial_ready"),
			"existing real Godot workbench did not initialize"):
		finish()
		return
	workbench = main.shared_workbench
	var blank: Dictionary = Setup.fresh(
		PackedInt32Array(workbench.applied.liquid_policy),Vector2i(2048,2048))
	if not check(workbench.apply(blank),"2048 native workbench apply refused"):
		finish()
		return
	if not await wait_for(Callable(self,"_signed_ready"),
			"2048 native World was not authoritatively paused"):
		finish()
		return
	var original_generation: int = main.latest_snapshot.render_world_generation
	var original_tick: int = main.latest_snapshot.tick_index
	var bridge = Bridge.new()
	if not check(bridge.bind(main),"actual #526 signed host could not bind"):
		finish()
		return
	# Trusted host-only opt-in, NOT a fifth model tool or a production default.
	var authorized: Dictionary = await bridge.authorize_task(
		"signed-join-experiment-527",Rect2i(-16,-8,64,64),
		[Rect2i(-12,4,2,2)],[0,58],SignedFrame.FRAME_ID)
	if not check(authorized.get("status")=="authorized"
			and authorized.get("coordinate_frame_id","")==SignedFrame.FRAME_ID
			and authorized.get("native_scope",Rect2i())==Rect2i(496,504,64,64),
			"real native host did not acknowledge exact signed frame: "+str(authorized)):
		finish()
		return
	var observed: Dictionary = await bridge.call_tool("observe",{
		"region":{"x":-9,"y":-4,"width":9,"height":8},"detail":"cells"})
	check(observed.get("status")=="observed"
		and observed.get("coordinate_frame_id","")==SignedFrame.FRAME_ID
		and observed.get("region",Rect2i())==Rect2i(-9,-4,9,8)
		and observed.get("native_region",Rect2i())==Rect2i(503,508,9,8)
		and observed.get("image_status")=="matched_post_draw"
		and observed.get("framebuffer_png",PackedByteArray()).size()>8
		and observed.get("native_material_ids",[]).size()==72,
		"real signed-native observe/image mismatch: "+str(observed.get("reason","")))
	if observed.get("status")!="observed":
		await bridge.stop()
		finish()
		return
	var sand_refusal: Dictionary = await bridge.call_tool("prepare_edit",{
		"observation_id":observed.observation_id,
		"operations":[{"shape":"disc","x":-8,"y":-2,"radius":0,"material":2}]})
	check(sand_refusal.get("status")=="refused",
		"signed model attempted unauthorized Sand manufacture")
	var guard_refusal: Dictionary = await bridge.call_tool("prepare_edit",{
		"observation_id":observed.observation_id,
		"operations":[{"shape":"disc","x":-12,"y":4,"radius":0,"material":58}]})
	check(guard_refusal.get("status")=="refused",
		"real native protected signed motif not refused")
	var prepared: Dictionary = await bridge.call_tool("prepare_edit",{
		"observation_id":observed.observation_id,
		"operations":[{"shape":"rectangle","x0":-8,"y0":-2,
			"x1":-6,"y1":0,"material":58,"replace_only_material":0}]})
	if not check(prepared.get("status")=="proposed"
			and prepared.get("changed_cells",-1)==9
			and prepared.get("coordinate_frame_id","")==SignedFrame.FRAME_ID,
			"native signed Hard Wall proposal failed: "+str(prepared)):
		await bridge.stop()
		finish()
		return
	var pending_step: Dictionary = await bridge.call_tool("step",{"ticks":1})
	check(pending_step.get("status")=="refused"
		and pending_step.get("reason")=="prepared_edit_must_be_applied_or_retired_before_step"
		and main.latest_snapshot.tick_index==original_tick,
		"native tick bypassed a prepared signed proposal")
	var applied: Dictionary = await bridge.call_tool("apply_edit",{
		"proposal_id":prepared.proposal_id})
	var real_rows: Array = applied.get("readback",[])
	var signed_rows: int = 0
	for row: Variant in real_rows:
		if row is Dictionary and int(row.get("x",999)) < 0 \
				and int(row.get("actual",-1))==58:
			signed_rows += 1
	check(applied.get("status")=="applied"
		and applied.get("changed_cells",-1)==9
		and applied.get("authored_start",{}).get("status")=="recorded"
		and applied.get("coordinate_frame_id","")==SignedFrame.FRAME_ID
		and signed_rows==9,
		"native signed apply/readback was not genuine: "+str(applied.get("reason","")))
	var stepped: Dictionary = await bridge.call_tool("step",{"ticks":2})
	var joined: Dictionary = stepped.get("observation",{})
	check(stepped.get("status")=="completed"
		and stepped.get("requested",-1)==2
		and stepped.get("completed",-1)==2
		and stepped.get("before_tick",-1)==original_tick
		and stepped.get("after_tick",-1)==original_tick+2
		and stepped.get("still_paused")==true
		and joined.get("status")=="observed"
		and joined.get("image_status")=="matched_post_draw"
		and joined.get("coordinate_frame_id","")==SignedFrame.FRAME_ID
		and joined.get("framebuffer_png",PackedByteArray()).size()>8
		and int(joined.get("identity",{}).get("completed_tick",-1))==original_tick+2
		and int(joined.get("render_identity",{}).get("tick",-1))==original_tick+2,
		"post-Step signed native/tick/PNG join failed: "+
		str(stepped.get("reason",""))+" / "+str(joined.get("reason","")))
	var stopped: Dictionary = await bridge.stop()
	check(stopped.get("status")=="stopped"
		and stopped.get("no_further_agent_mutations")==true
		and main.latest_snapshot.tick_index==original_tick+2
		and main.latest_snapshot.render_world_generation==original_generation,
		"native retirement lost owner identity or executed extra tick")
	var stale: Dictionary = await bridge.call_tool("step",{"ticks":1})
	check(stale.get("status")=="refused"
		and main.latest_snapshot.tick_index==original_tick+2,
		"retired signed task admitted a late model tick")
	var evidence_dir: String = OS.get_environment("WB_AGENT_527_IMAGE_DIR")
	if not evidence_dir.is_empty():
		for item: Dictionary in [
			{"name":"signed-experimental-before.png","receipt":observed},
			{"name":"signed-experimental-post-step.png","receipt":joined}
		]:
			var png: PackedByteArray = item.receipt.get(
				"framebuffer_png",PackedByteArray())
			if not check(png.size()>8,"no original signed-frame PNG"):
				continue
			var file: FileAccess = FileAccess.open(evidence_dir.path_join(item.name),
				FileAccess.WRITE)
			if check(file != null,"signed-frame PNG evidence path refused"):
				file.store_buffer(png)
				file.close()
	print("WB_AGENT_527_SIGNED_JOIN_RESULT "+JSON.stringify({
		"experimental_physics_parity":"NOT_CLAIMED",
		"frame_id":SignedFrame.FRAME_ID,"world_generation":original_generation,
		"before_tick":original_tick,"after_tick":main.latest_snapshot.tick_index,
		"native_rows_verified":signed_rows,
		"native_worker_request":main.latest_snapshot.native_worker_request,
		"checks":checks,"failures":failures}))
	finish()


func finish() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame
	print("WB_AGENT_527_SIGNED_JOIN: %d assertions, %d failures" % [
		checks,failures])
	quit(1 if failures else 0)
