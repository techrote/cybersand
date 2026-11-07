extends SceneTree
## #527: REAL Godot/native four-tool 32-Sand hopper experiment on #526's
## explicitly EXPERIMENTAL +512 finite mapping. Frozen TSV is read verbatim.
## Not a proof of strict parity with the original signed infinite World:
## independent #537 documented 26 different NORMAL intermediate states.
## Never use this result as an admitted live agent or human acceptance gate.
const Setup = preload("res://scripts/workbench_setup.gd")
const Bridge = preload("res://scripts/workbench_agent_four_tool_bridge.gd")
const SignedFrame = preload("res://scripts/workbench_agent_signed_frame.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const TOTAL_TICKS: int = 480
const TICKS_PER_CALL: int = 120
const FROZEN_FIXTURE: String = "res://tests/wb-agent-527-v2-runtime.tsv"
const SOURCE_OBSERVATION: Dictionary = {
	"x":-8,"y":0,"width":8,"height":4}
const AUTHORING_OBSERVATION: Dictionary = {
	"x":-40,"y":5,"width":80,"height":38}
const PROTECTION: Array[Rect2i] = [
	Rect2i(30,-3,1,7),Rect2i(30,-3,5,1),
	Rect2i(34,-2,1,3),Rect2i(30,0,5,1)
]

var main: Control
var workbench: Control
var checks: int = 0
var failures: int = 0


func check(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_AGENT_527_HOPPER_GODOT: " + detail)
	return ok


func _initialized() -> bool:
	return main != null and main.shared_workbench != null \
		and not main.shared_workbench.applied.is_empty() \
		and main.latest_snapshot != null and main.paused \
		and not main.shared_workbench.busy()


func _native_ready() -> bool:
	return _initialized() and main.world_extent==Vector2i(2048,2048) \
		and main.shared_workbench.applied.get("extent",[])==[2048,2048] \
		and main.pending_microscenario_apply.is_empty() \
		and main.latest_snapshot.paused


func wait_for(predicate: Callable, message: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return check(predicate.call(),message)


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()


func read_fixture() -> Array:
	var file: FileAccess = FileAccess.open(FROZEN_FIXTURE,FileAccess.READ)
	if not check(file != null,"immutable fixture file missing"):
		return []
	var rows: Array = []
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var pieces: PackedStringArray = line.split(" ",false)
		if not check(pieces.size()==7,"immutable TSV row malformed: "+line):
			continue
		var row: Dictionary = {
			"variant":pieces[0],"phase":pieces[1],"shape":pieces[2],
			"a":pieces[3].to_int(),"b":pieces[4].to_int(),
			"c":pieces[5].to_int(),"d":pieces[6].to_int()
		}
		rows.append(row)
	file.close()
	check(rows.size()==22,
		"frozen fixture row inventory changed: "+str(rows.size()))
	return rows


func applies(row: Dictionary, variant: String) -> bool:
	return row.variant=="both" or row.variant==variant


func initial_start(rows: Array, variant: String) -> Dictionary:
	var setup: Dictionary = Setup.fresh(
		PackedInt32Array(workbench.applied.liquid_policy),Vector2i(2048,2048))
	for phase: String in ["manual_wall","protected_wall","initial_sand"]:
		for row: Dictionary in rows:
			if not applies(row,variant) or row.phase!=phase:
				continue
			if not check(row.shape=="rect","manual source must use literal rect"):
				continue
			var material: int = 2 if phase=="initial_sand" else 58
			setup.edits.append([row.a+SignedFrame.ORIGIN.x,
				row.b+SignedFrame.ORIGIN.y,row.c,row.d,material])
	return setup


func author_ops(rows: Array, variant: String) -> Array:
	var operations: Array = []
	for phase: String in ["agent_wall","agent_empty"]:
		for row: Dictionary in rows:
			if not applies(row,variant) or row.phase!=phase:
				continue
			var material: int = 0 if phase=="agent_empty" else 58
			var replace_only: int = 58 if material==0 else 0
			if row.shape=="rect":
				operations.append({
					"shape":"rectangle","x0":row.a,"y0":row.b,
					"x1":row.a+row.c-1,"y1":row.b+row.d-1,
					"material":material,"replace_only_material":replace_only})
			else:
				for dy: int in range(row.d):
					var left: int = row.a if row.shape=="wedge_right" else row.c-dy
					var right: int = row.c+dy if row.shape=="wedge_right" else row.a
					operations.append({
						"shape":"rectangle","x0":left,"y0":row.b+dy,
						"x1":right,"y1":row.b+dy,
						"material":material,"replace_only_material":replace_only})
	return operations


func target_region(rows: Array, variant: String) -> Dictionary:
	for row: Dictionary in rows:
		if row.phase=="target" and applies(row,variant):
			return {"x":row.a,"y":row.b,"width":row.c,"height":row.d}
	return {}


func preserve_png(variant: String, label: String, answer: Dictionary) -> void:
	var dir: String = OS.get_environment("WB_AGENT_527_IMAGE_DIR")
	if dir.is_empty():
		return
	var bytes: PackedByteArray = answer.get("framebuffer_png",PackedByteArray())
	if not check(bytes.size()>8,"missing original PNG "+variant+" "+label):
		return
	var file: FileAccess = FileAccess.open(
		dir.path_join("signed-hopper-%s-%s.png" % [variant,label]),
		FileAccess.WRITE)
	if check(file != null,"cannot retain original native framebuffer"):
		file.store_buffer(bytes)
		file.close()


func run_variant(rows: Array, variant: String) -> void:
	var previous_generation: int = main.latest_snapshot.render_world_generation
	var setup: Dictionary = initial_start(rows,variant)
	if not check(workbench.apply(setup),
			"native fixture authored start refused for "+variant):
		return
	if not await wait_for(
			func() -> bool:
				return _native_ready() and \
					main.latest_snapshot.render_world_generation!=previous_generation,
			"real 2048 World did not install immutable authored start "+variant):
		return
	var generation: int = main.latest_snapshot.render_world_generation
	var initial_tick: int = main.latest_snapshot.tick_index
	check(initial_tick==0,"fixture must begin at native tick zero")
	var bridge = Bridge.new()
	if not check(bridge.bind(main),"#526 native owner did not bind "+variant):
		return
	var auth: Dictionary = await bridge.authorize_task(
		"fixture-527-"+variant,Rect2i(-40,-5,80,48),
		Array(PROTECTION),[0,58],SignedFrame.FRAME_ID)
	if not check(auth.get("status")=="authorized"
			and auth.get("coordinate_frame_id","")==SignedFrame.FRAME_ID,
			"signed fixture authorization refused "+variant+" "+str(auth)):
		return
	var source: Dictionary = await bridge.call_tool("observe",{
		"region":SOURCE_OBSERVATION,"detail":"cells"})
	check(source.get("status")=="observed"
		and source.get("image_status")=="matched_post_draw"
		and int(source.get("native_counts",{}).get(2,-1))==32
		and source.get("native_material_ids",[]).size()==32,
		"initial authored Sand !=32 from native readback "+variant)
	preserve_png(variant,"initial",source)
	# The SAME native hopper used for acceptance must reject an agent
	# attempt to manufacture Sand and a mutating edit to the pre-existing
	# human-protected Hard Wall. A mere refused status is insufficient:
	# re-read the wall cells and retain the exact authored-start edit list.
	var human_edits: Array = workbench.applied.edits.duplicate(true)
	var unauthorized_sand: Dictionary = await bridge.call_tool("prepare_edit",{
		"observation_id":source.get("observation_id",""),
		"operations":[{"shape":"rectangle","x0":-8,"y0":0,
			"x1":-8,"y1":0,"material":2}]})
	check(unauthorized_sand.get("status")=="refused"
		and main.latest_snapshot.tick_index==initial_tick
		and workbench.applied.edits==human_edits,
		"agent manufactured Sand or changed authored start on refused preflight "
		+variant+" "+str(unauthorized_sand))
	var protected_before: Dictionary = await bridge.call_tool("observe",{
		"region":{"x":30,"y":-3,"width":5,"height":7},"detail":"cells"})
	check(protected_before.get("status")=="observed"
		and protected_before.get("image_status")=="matched_post_draw"
		and int(protected_before.get("native_counts",{}).get(58,-1))==17,
		"human-protected 17 native Hard Walls missing before refusal "+variant)
	var unauthorized_wall: Dictionary = await bridge.call_tool("prepare_edit",{
		"observation_id":protected_before.get("observation_id",""),
		"operations":[{"shape":"rectangle","x0":30,"y0":-3,
			"x1":30,"y1":-3,"material":0,"replace_only_material":58}]})
	check(unauthorized_wall.get("status")=="refused"
		and main.latest_snapshot.tick_index==initial_tick,
		"agent proposed removal of a human-protected Wall "+variant+
		" "+str(unauthorized_wall))
	var protected_after: Dictionary = await bridge.call_tool("observe",{
		"region":{"x":30,"y":-3,"width":5,"height":7},"detail":"cells"})
	check(protected_after.get("status")=="observed"
		and protected_after.get("image_status")=="matched_post_draw"
		and protected_after.get("native_material_ids",[]) ==
			protected_before.get("native_material_ids",[])
		and int(protected_after.get("native_counts",{}).get(58,-1))==17
		and main.latest_snapshot.tick_index==initial_tick
		and workbench.applied.edits==human_edits,
		"native protected material or authored start mutated during refusals "
		+variant)
	var operations: Array = author_ops(rows,variant)
	check(operations.size()==26,
		"frozen reference construction operations changed "+variant+
		" count="+str(operations.size()))
	var applied_batches: int = 0
	for begin: int in range(0,operations.size(),8):
		var observe: Dictionary = await bridge.call_tool("observe",{
			"region":AUTHORING_OBSERVATION,"detail":"counts"})
		if not check(observe.get("status")=="observed"
				and observe.get("image_status")=="matched_post_draw",
				"real construction observation failed "+variant+" "+str(observe)):
			break
		var batch: Array = operations.slice(begin,mini(begin+8,operations.size()))
		var prepared: Dictionary = await bridge.call_tool("prepare_edit",{
			"observation_id":observe.observation_id,"operations":batch})
		if not check(prepared.get("status")=="proposed",
				"reference batch preflight refused "+variant+
				" at="+str(begin)+" "+str(prepared)):
			break
		var apply: Dictionary = await bridge.call_tool("apply_edit",{
			"proposal_id":prepared.proposal_id})
		if not check(apply.get("status")=="applied"
				and apply.get("authored_start",{}).get("status")=="recorded"
				and apply.get("coordinate_frame_id","")==SignedFrame.FRAME_ID,
				"native source readback apply failed "+variant+
				" at="+str(begin)+" "+str(apply)):
			break
		applied_batches += 1
		if begin==0:
			# Repeating a successfully consumed ID is an idempotent *receipt
			# replay*, not a second native edit or an error. Preserve that
			# distinction and require the exact original apply/readback.
			var saved_edits: Array = workbench.applied.edits.duplicate(true)
			var applied_revision: int = main.simulation_worker.agent_manual_intent_revision()
			var replay: Dictionary = await bridge.call_tool("apply_edit",{
				"proposal_id":prepared.proposal_id})
			check(replay.get("status")=="applied"
				and replay.get("proposal_id","")==apply.get("proposal_id","")
				and replay.get("readback",[])==apply.get("readback",[])
				and replay.get("authored_start",{})==apply.get("authored_start",{})
				and replay.get("changed_cells",-1)==apply.get("changed_cells",-2)
				and workbench.applied.edits==saved_edits
				and main.simulation_worker.agent_manual_intent_revision()==applied_revision
				and main.latest_snapshot.tick_index==initial_tick
				and main.latest_snapshot.render_world_generation==generation,
				"duplicate apply changed real native/material/start state "+variant+
				" "+str(replay.get("reason","")))
	if not check(applied_batches==4,"incomplete four-tool native apparatus "+variant):
		await bridge.stop()
		return
	# Agent was allowed to author ONLY material 0 (Empty) and 58 (Hard Wall).
	# Initial authored Sand was placed by the host BEFORE task authorization.
	check(main.latest_snapshot.tick_index==initial_tick,
		"authoring unexpectedly stepped the Sand fixture "+variant)
	var completed_total: int = 0
	for _round: int in range(4):
		var stepped: Dictionary = await bridge.call_tool("step",{
			"ticks":TICKS_PER_CALL})
		var after: Dictionary = stepped.get("observation",{})
		if not check(stepped.get("status")=="completed"
				and stepped.get("requested",-1)==TICKS_PER_CALL
				and stepped.get("completed",-1)==TICKS_PER_CALL
				and stepped.get("before_tick",-1)==initial_tick+completed_total
				and stepped.get("after_tick",-1)==initial_tick+completed_total+TICKS_PER_CALL
				and stepped.get("still_paused")==true
				and after.get("status")=="observed"
				and after.get("image_status")=="matched_post_draw"
				and int(after.get("identity",{}).get("completed_tick",-1))==
					initial_tick+completed_total+TICKS_PER_CALL
				and int(after.get("render_identity",{}).get("tick",-1))==
					initial_tick+completed_total+TICKS_PER_CALL,
				"actual step/native-render mismatch "+variant+" "+
				str(stepped.get("reason",""))+"/"+str(after.get("reason",""))):
			break
		completed_total += TICKS_PER_CALL
	if not check(completed_total==TOTAL_TICKS,
			"frozen TOTAL budget not completed "+variant+
			" actual="+str(completed_total)):
		await bridge.stop()
		return
	var target: Dictionary = target_region(rows,variant)
	var final: Dictionary = await bridge.call_tool("observe",{
		"region":target,"detail":"cells"})
	check(final.get("status")=="observed"
		and final.get("image_status")=="matched_post_draw"
		and int(final.get("native_counts",{}).get(2,-1))==32
		and final.get("native_material_ids",[]).size()==target.width*target.height,
		"translated native Godot catchment does not hold 32 Sand "+variant+
		" "+str(final.get("native_counts",{})))
	preserve_png(variant,"terminal",final)
	var guard: Dictionary = await bridge.call_tool("observe",{
		"region":{"x":30,"y":-3,"width":5,"height":7},"detail":"cells"})
	check(guard.get("status")=="observed"
		and int(guard.get("native_counts",{}).get(58,-1))==17,
		"native protected wall motif changed "+variant)
	# Leave a valid proposal deliberately UNCONSUMED across Stop and named
	# authored-start reload. A late model apply must never survive retirement
	# into either the old World or the freshly loaded native generation.
	var pending_site: Dictionary = {"x":-39,"y":-4,"width":1,"height":1}
	var pending_before: Dictionary = await bridge.call_tool("observe",{
		"region":pending_site,"detail":"cells"})
	check(pending_before.get("status")=="observed"
		and pending_before.get("image_status")=="matched_post_draw"
		and int(pending_before.get("native_counts",{}).get(0,-1))==1,
		"unconsumed proposal control site is not real native Empty "+variant)
	var unconsumed: Dictionary = await bridge.call_tool("prepare_edit",{
		"observation_id":pending_before.get("observation_id",""),
		"operations":[{
			"shape":"rectangle","x0":-39,"y0":-4,"x1":-39,"y1":-4,
			"material":58,"replace_only_material":0}]})
	check(unconsumed.get("status")=="proposed"
		and not str(unconsumed.get("proposal_id","")).is_empty(),
		"valid pending Hard Wall proposal was not prepared "+variant+
		" "+str(unconsumed.get("reason","")))
	var pending_tick: int = main.latest_snapshot.tick_index
	check(pending_tick==TOTAL_TICKS,
		"prepare without apply changed the frozen tick budget "+variant)
	var stopped: Dictionary = await bridge.stop()
	check(stopped.get("status")=="stopped"
		and stopped.get("no_further_agent_mutations")==true
		and main.latest_snapshot.tick_index==TOTAL_TICKS
		and main.latest_snapshot.render_world_generation==generation,
		"native Stop did not acknowledge after fixed budget "+variant)
	var late_unconsumed: Dictionary = await bridge.call_tool("apply_edit",{
		"proposal_id":unconsumed.get("proposal_id","")})
	check(late_unconsumed.get("status")=="refused"
		and main.latest_snapshot.tick_index==pending_tick
		and main.latest_snapshot.render_world_generation==generation,
		"retired task consumed a pending authoring proposal after Stop ACK "+variant)
	# An authored-start save is a *construction recipe*, not a checkpoint
	# of the evolved physics. Preserve the completed 480-tick receipts, then
	# save and reopen the FULL agent-authored apparatus in a fresh native World.
	# Only the trusted workbench Save/Load APIs may perform this operation.
	var evolved_generation: int = main.latest_snapshot.render_world_generation
	var name: String = "wb-agent-527-hopper-" + variant
	workbench._name.text = name
	if not check(workbench.save_setup(),
			"agent-authored hopper could not be saved as named start " + variant):
		return
	var saved_start: Dictionary = Setup.read_named(name)
	if not check(saved_start.has("setup"),
			"saved hopper start did not reopen from named disk file " +
			variant + " " + str(saved_start)):
		return
	check(saved_start.setup.edits == workbench.applied.edits,
		"saved authored-start edits changed on disk " + variant)
	check(saved_start.setup.edits.size() > 0,
		"saved hopper lost all authored edit geometry " + variant)
	if not check(workbench.load_setup(),
			"real shared workbench refused named hopper start reload " + variant):
		return
	if not await wait_for(
			func() -> bool:
				return _native_ready() and \
					main.latest_snapshot.render_world_generation != evolved_generation \
					and main.latest_snapshot.tick_index == 0,
			"named hopper reopen did not reset a new paused native World " + variant):
		return
	var reopened_generation: int = main.latest_snapshot.render_world_generation
	var reopened = Bridge.new()
	if not check(reopened.bind(main),
			"reopened hopper failed to bind exclusive native authoring " + variant):
		return
	var reopened_auth: Dictionary = await reopened.authorize_task(
		"fixture-527-reopened-" + variant, Rect2i(-40,-5,80,48),
		Array(PROTECTION), [0,58], SignedFrame.FRAME_ID)
	if not check(reopened_auth.get("status")=="authorized",
			"reopened hopper rejected new task authorization " + variant +
			" " + str(reopened_auth)):
		return
	var reopened_sand: Dictionary = await reopened.call_tool("observe",{
		"region":SOURCE_OBSERVATION,"detail":"cells"})
	check(reopened_sand.get("status")=="observed"
		and reopened_sand.get("image_status")=="matched_post_draw"
		and reopened_sand.get("native_material_ids",[]).size()==32
		and int(reopened_sand.get("native_counts",{}).get(2,-1))==32
		and int(reopened_sand.get("identity",{}).get("completed_tick",-1))==0,
		"reopened authored start did not restore the original 32 Sand at tick zero " +
		variant + " " + str(reopened_sand.get("reason","")))
	preserve_png(variant,"reopened-authored-start",reopened_sand)
	var reopened_protection: Dictionary = await reopened.call_tool("observe",{
		"region":{"x":30,"y":-3,"width":5,"height":7},"detail":"cells"})
	check(reopened_protection.get("status")=="observed"
		and int(reopened_protection.get("native_counts",{}).get(58,-1))==17,
		"reopened authored start changed the protected 17-cell motif " + variant)
	var reopened_pending_site: Dictionary = await reopened.call_tool("observe",{
		"region":pending_site,"detail":"cells"})
	check(reopened_pending_site.get("status")=="observed"
		and reopened_pending_site.get("image_status")=="matched_post_draw"
		and int(reopened_pending_site.get("native_counts",{}).get(0,-1))==1
		and reopened_pending_site.get("native_material_ids",[]).size()==1,
		"pending pre-Stop Hard Wall leaked into the named authored start "+variant)
	var obsolete_apply: Dictionary = await bridge.call_tool("apply_edit",{
		"proposal_id":unconsumed.get("proposal_id","")})
	check(obsolete_apply.get("status")=="refused"
		and main.latest_snapshot.tick_index==0
		and main.latest_snapshot.render_world_generation==reopened_generation,
		"retired pre-reload proposal applied to a new native generation "+variant)
	var stale_step: Dictionary = await bridge.call_tool("step",{"ticks":1})
	check(stale_step.get("status")=="refused"
		and main.latest_snapshot.tick_index==0
		and main.latest_snapshot.render_world_generation==reopened_generation,
		"retired hopper task executed an extra tick after named start reload " + variant)
	var reopened_stop: Dictionary = await reopened.stop()
	check(reopened_stop.get("status")=="stopped"
		and reopened_stop.get("no_further_agent_mutations")==true
		and main.latest_snapshot.tick_index==0,
		"reopened hopper task did not retire without evolved physics " + variant)
	print("WB_AGENT_527_HOPPER_AUTHORED_START_REOPEN " + JSON.stringify({
		"variant":variant, "saved_named_start":name,
		"previous_completed_ticks":TOTAL_TICKS,
		"reopened_native_tick":main.latest_snapshot.tick_index,
		"reopened_generation":reopened_generation,
		"reopened_initial_sand":reopened_sand.get("native_counts",{}).get(2,-1),
		"protected_hard_wall":reopened_protection.get("native_counts",{}).get(58,-1),
		"reopened_framebuffer":reopened_sand.get("image_status","")}))
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(
		Setup._path(name)))==OK,
		"test-only named authored-start file could not be cleaned " + variant)

	print("WB_AGENT_527_HOPPER_GODOT_RESULT "+JSON.stringify({
		"variant":variant,
		"experimental_translation_not_strict_physical_parity":true,
		"completed_ticks":completed_total,"frozen_total_budget":TOTAL_TICKS,
		"terminal_catchment":final.get("native_counts",{}).get(2,-1),
		"source_generation":generation,
		"actual_native_worker_request":main.latest_snapshot.native_worker_request,
		"applied_native_batches":applied_batches,
		"matched_framebuffer":final.get("image_status",""),
		"source_fixture":"wb_agent_sand_hopper_v2.tsv"}))


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	if not await wait_for(Callable(self,"_initialized"),
			"actual shared workbench did not initialize"):
		finish()
		return
	workbench = main.shared_workbench
	var rows: Array = read_fixture()
	if rows.size()!=22:
		finish()
		return
	await run_variant(rows,"normal")
	await run_variant(rows,"revised")
	finish()


func finish() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await process_frame
		await process_frame
	print("WB_AGENT_527_HOPPER_GODOT: %d assertions, %d failures" %
		[checks,failures])
	quit(1 if failures else 0)
