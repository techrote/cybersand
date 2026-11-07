extends SceneTree

## #526 source-matched integration: real shared-workbench owner and native World.
## Not a mock; this exercises the same worker command queue and real GDExtension.
const Setup = preload("res://scripts/workbench_setup.gd")
const RenderJoin = preload("res://scripts/workbench_authoring_render_join.gd")
const StartCommit = preload("res://scripts/workbench_authoring_start_commit.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var main: Control
var ui
var worker: CyberSimulationWorker
var checks: int = 0
var failures: int = 0
var last_serial: int = 0


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()


func check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("WB_AGENT_OWNER: " + description)
	return condition


func wait_for(test: Callable, description: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if test.call(): return true
		await process_frame
	return check(test.call(),description)


func issue(command: Dictionary) -> Dictionary:
	command["schema_version"] = 1
	var serial: int = worker.queue_agent_authoring_command(command)
	if not check(serial > 0,"owner rejected request admission: "+str(command.get("action",""))):
		return {}
	if not await wait_for(
		func() -> bool:
			return int(worker.latest_agent_authoring_result(last_serial).get("request_serial",0)) == serial,
		"worker never returned serial "+str(serial)
	):
		return {}
	var result: Dictionary = worker.latest_agent_authoring_result(last_serial)
	last_serial = serial
	return result


func authorize() -> Dictionary:
	return await issue({
		"action":"authorize_task", "task_id":"fixture-526",
		"scope":Rect2i(Vector2i(1120,220),Vector2i(160,180)),
		"protected":[Rect2i(Vector2i(1240,240),Vector2i(6,6))],
		"allowed_materials":[0,58]
	})


func observe(x: int, y: int, width: int, height: int) -> Dictionary:
	var native: Dictionary = await issue({
		"action":"observe",
		"region":Rect2i(Vector2i(x,y),Vector2i(width,height))
	})
	if native.get("status")!="native_observed":
		return native
	var joined: Dictionary = await RenderJoin.join_after_draw(main,native)
	if not check(joined.get("status")=="observed",
			"native/render post-draw join refused: "+str(joined.get("reason",""))):
		return native
	var confirmed: Dictionary = await issue({
		"action":"confirm_observation_frame",
		"observation_id":native.observation_id,
		"render_identity":joined.render_identity
	})
	check(confirmed.get("status")=="observation_confirmed",
		"worker did not confirm actual ACKed framebuffer: "+str(confirmed))
	return native


# Named predicates avoid a multiline anonymous-function argument whose
# unparenthesized return-expression continuation Godot 4.7 cannot parse.
func _initial_workbench_ready() -> bool:
	return ui != null and not ui.applied.is_empty() and not ui.busy() \
		and main.latest_snapshot != null and main.paused


func _new_workbench_ready() -> bool:
	return not ui.applied.is_empty() and ui.applied.extent == [2048,2048] \
		and not ui.busy() and main.pending_microscenario_apply.is_empty() \
		and main.world_extent == Vector2i(2048,2048)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	ui = main.shared_workbench
	worker = main.simulation_worker
	if not await wait_for(Callable(self, "_initial_workbench_ready"),
			"shared workbench did not initialize paused"):
		finish()
		return
	var new_setup: Dictionary = Setup.fresh(
		PackedInt32Array(ui.applied.liquid_policy),Vector2i(2048,2048))
	if not check(ui.apply(new_setup),"blank real native owner was not accepted"):
		finish()
		return
	if not await wait_for(Callable(self, "_new_workbench_ready"),
			"fresh 2048-square native workbench did not install"):
		finish()
		return

	var opened: Dictionary = await authorize()
	check(opened.get("status")=="authorized","task authorization: "+str(opened))
	var original: Dictionary = await observe(1144,260,12,8)
	check(original.get("status")=="native_observed"
		and original.get("native_material_ids",[]).size()==96,
		"actual bounded owner-side read did not return IDs")
	check(original.get("image_status")=="awaiting_matched_framebuffer",
		"native-only observation fabricated a matched frame")
	check(original.get("identity",{}).get("world_generation",-1)>0,
		"native observation omitted World identity")
	var joined: Dictionary = await RenderJoin.join_after_draw(main,original)
	check(joined.get("status")=="observed"
		and joined.get("image_status")=="matched_post_draw"
		and joined.get("framebuffer_png",PackedByteArray()).size()>8,
		"real post-draw framebuffer was not matched to the native observation: "+str(joined.get("reason","")))
	if joined.get("status")=="observed":
		check(joined.render_identity.world_revision == original.identity.world_revision
			and joined.render_identity.world_generation == original.identity.world_generation,
			"native/frame render generation and revision differed")
	var source_counts: Dictionary = original.get("native_counts",{})
	check(int(source_counts.get(0,0))==96,
		"blank fixture should contain 96 native Empty cells, observed "+str(source_counts))

	var prepared: Dictionary = await issue({
		"action":"prepare_edit", "observation_id":original.observation_id,
		"operations":[
			{"shape":"disc","x":1148,"y":263,"radius":2,"material":58},
			{"shape":"line","x0":1145,"y0":265,"x1":1152,"y1":265,
				"material":58,"replace_only_material":0},
			{"shape":"rectangle","x0":1145,"y0":266,"x1":1148,"y1":267,
				"material":58}
		]
	})
	check(prepared.get("status")=="proposed" and prepared.get("changed_cells",0)>0,
		"prepare must inspect native IDs and predict changed cell counts")
	var before_apply: Dictionary = await observe(1144,260,12,8)
	check(int(before_apply.get("native_counts",{}).get(58,0))==0,
		"prepare must cause ZERO native writes")
	# A later observation ordinarily retires the pending prepared proposal.
	# Prepare a fresh proposal from that new exact observation.
	prepared = await issue({
		"action":"prepare_edit", "observation_id":before_apply.observation_id,
		"operations":[
			{"shape":"disc","x":1148,"y":263,"radius":2,"material":58},
			{"shape":"line","x0":1145,"y0":265,"x1":1152,"y1":265,
				"material":58,"replace_only_material":0},
			{"shape":"rectangle","x0":1145,"y0":266,"x1":1148,"y1":267,
				"material":58}
		]
	})
	if not check(prepared.get("status")=="proposed","second prepare refused"):
		finish()
		return
	var record_plan: Dictionary = StartCommit.stage(ui.applied,prepared)
	check(record_plan.get("status")=="recordable",
		"accepted native footprint must fit authored-start representation: "+str(record_plan))
	var applied: Dictionary = await issue({
		"action":"apply_edit","proposal_id":prepared.proposal_id
	})
	check(applied.get("status")=="applied"
		and applied.get("confirmed_writes",0)>0,
		"native apply was not readback-verified: "+str(applied))
	if record_plan.get("status")=="recordable":
		var recorded: Dictionary = StartCommit.commit(ui,record_plan,applied)
		check(recorded.get("status")=="recorded",
			"native applied geometry was not admitted to authored-start: "+str(recorded))
		var saved_label := "wb-agent-526-source-matched"
		ui._name.text = saved_label
		check(ui.save_setup(),"verified agent edit did not save named authored start")
		var reopened: Dictionary = Setup.read_named(saved_label)
		check(not reopened.has("error") and reopened.get("setup",{}).get("edits",[]).size()>0,
			"named authored start did not reopen agent geometry")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Setup._path(saved_label)))
	var repeated: Dictionary = await issue({
		"action":"apply_edit","proposal_id":prepared.proposal_id
	})
	var original_receipt: Dictionary = applied.duplicate(true)
	var duplicate_receipt: Dictionary = repeated.duplicate(true)
	original_receipt.erase("request_serial")
	duplicate_receipt.erase("request_serial")
	check(duplicate_receipt == original_receipt,
		"duplicate apply must return identical retained native receipt")
	check(repeated.get("status")=="applied"
		and repeated.get("identity_after",{})==applied.get("identity_after",{}),
		"duplicate apply must return original native state identity")
	var after_apply: Dictionary = await observe(1144,260,12,8)
	check(int(after_apply.get("native_counts",{}).get(58,0))>0,
		"real World material IDs not changed after applied receipt")

	var protected: Dictionary = await issue({
		"action":"prepare_edit","observation_id":after_apply.observation_id,
		"operations":[{"shape":"disc","x":1240,"y":240,"radius":0,"material":58}]
	})
	check(protected.get("status")=="refused" and protected.get("reason")=="protected_region",
		"protected motif must refuse rather than clip")
	var untouched: Dictionary = await observe(1200,300,8,8)
	check(untouched.get("status")=="native_observed","manual race observation missing")
	var pending: Dictionary = await issue({
		"action":"prepare_edit","observation_id":untouched.observation_id,
		"operations":[{"shape":"rectangle","x0":1201,"y0":301,
			"x1":1204,"y1":304,"material":58}]
	})
	if check(pending.get("status")=="proposed","manual race proposal missing"):
		check(ui.paint(Vector2i(1202,302),58),
			"human edit between prepare and consume not admitted")
		var stale: Dictionary = await issue({
			"action":"apply_edit","proposal_id":pending.proposal_id
		})
		check(stale.get("status")=="refused",
			"human edit must invalidate old proposal at owner boundary: "+str(stale))
		var manual: Dictionary = await observe(1201,301,4,4)
		check(int(manual.get("native_counts",{}).get(58,0))>0,
			"manual native edit disappeared during stale proposal refusal")
		var replay_refusal: Dictionary = await issue({
			"action":"apply_edit","proposal_id":pending.proposal_id
		})
		check(replay_refusal.get("status")=="refused",
			"stale proposal unexpectedly mutated on duplicate")

	var sand_observation: Dictionary = await observe(1220,270,6,6)
	check(sand_observation.get("status")=="native_observed","pre-Sand observation")
	check(ui.paint(Vector2i(1222,272),2),"manual Sand paint should remain available")
	var sand: Dictionary = await observe(1220,270,6,6)
	check(int(sand.get("native_counts",{}).get(2,0))>0,
		"actual Sand not present in new owner observation")
	var no_sand: Dictionary = await issue({
		"action":"prepare_edit","observation_id":sand.observation_id,
		"operations":[{"shape":"disc","x":1222,"y":272,"radius":1,
			"material":0}]
	})
	check(no_sand.get("status")=="refused"
		and no_sand.get("reason")=="source_material_protected",
		"agent attempted to erase an actual native Sand cell")
	finish()


func finish() -> void:
	if main != null:
		main.queue_free()
		await process_frame
		await process_frame
	print("WB_AGENT_OWNER: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
