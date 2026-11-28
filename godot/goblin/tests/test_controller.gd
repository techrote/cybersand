extends SceneTree

## Real controller lifecycle over the mounted Workbench/native owner.
## Run only through tools/gip014/run_goblin.py --case controller, which creates
## a fresh profile. No simulated World, native receipt or completion is supplied.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const REPORT_PATH := "user://goblin/controller-test.json"

var controller: Node
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var mode := ""
var pause_seen := false
var pause_verified := false
var pause_started_msec := 0
var pause_started_frame := 0
var paused_attempts := 0
var paused_completed := 0
var paused_action := ""
var stopped_after_observation := false
var inflight_armed := false
var inflight_stop_seen := false
var pending_evidence: Dictionary = {}
var initialization_stop_seen := false


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("GOBLIN_CONTROLLER " + label)
	return condition


func _process(_delta: float) -> bool:
	if controller == null or not controller.running:
		return false
	if mode == "pause_resume" and pause_seen and not pause_verified \
		and Engine.get_process_frames() >= pause_started_frame + 5 \
		and Time.get_ticks_msec() >= pause_started_msec + 80:
		check(controller.decisions_paused, "Pause remains active until an explicit resume")
		check(controller.attempted == paused_attempts and controller.completed == paused_completed,
			"paused controller submits no additional actions across five real process frames")
		check(controller.latest_action == paused_action, "paused controller retains its latest actual action")
		pause_verified = true
		controller.pause_decisions()
		check(not controller.decisions_paused, "explicit resume releases the decision pause")
	if mode == "stop_inflight" and inflight_armed and not inflight_stop_seen \
		and controller.adapter != null and controller.adapter.executing \
		and controller.adapter.editor != null and controller.adapter.editor.busy():
		var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(Controller.TRANSCRIPT_PATH))
		if stored is Dictionary:
			pending_evidence = stored.get("pending_action", {}).duplicate(true)
		check(not pending_evidence.is_empty(), "actual pending paint has already been exported before completion")
		check(pending_evidence.get("status") in ["proposed", "accepted"] \
			and pending_evidence.get("action", {}).get("id") == controller.latest_action,
			"pending evidence names the actual in-flight action without claiming completion")
		if pending_evidence.get("status") == "accepted":
			check(pending_evidence.get("admission", {}).get("accepted") == true,
				"pending accepted state retains the actual application admission")
		check(pending_evidence.get("before", {}).get("native", {}).has_all(["generation", "revision", "tick"]),
			"pending evidence retains the actual pre-action native observation")
		inflight_stop_seen = true
		controller.stop()
	return false


func _on_started(action: Dictionary) -> void:
	if mode == "stop_inflight" and str(action.get("id", "")) in ["brush", "rectangle"]:
		inflight_armed = true


func _on_observed(_record: Dictionary) -> void:
	if mode != "pause_resume": return
	if controller.attempted == 2 and not pause_seen:
		pause_seen = true
		paused_attempts = controller.attempted
		paused_completed = controller.completed
		paused_action = controller.latest_action
		pause_started_msec = Time.get_ticks_msec()
		pause_started_frame = Engine.get_process_frames()
		controller.pause_decisions()
	elif controller.attempted == 4 and pause_verified and not stopped_after_observation:
		stopped_after_observation = true
		controller.stop()


func _on_changed() -> void:
	if mode == "stop_initialization" and controller.running and controller.state == "initializing" \
		and not initialization_stop_seen:
		initialization_stop_seen = true
		controller.stop()


func configuration(fixture_id: String, action_budget: int, seed_value: int = 13) -> Dictionary:
	return {"fixture_id":fixture_id, "policy":"CONTROL", "seed":seed_value,
		"budget":action_budget, "pacing_ms":0, "evidence_kind":"headless_godot"}


func retain(label: String, tape: Dictionary) -> void:
	var valid: Dictionary = Transcript.validate(tape)
	check(valid.get("ok", false), label + " produces a structurally valid transcript: " + str(valid.get("errors", [])))
	check(tape.get("summary", {}).get("attempted_actions", -1) == tape.get("steps", []).size(),
		label + " summary accounts for every terminal attempt")
	cases.append({"case":label, "transcript":tape.duplicate(true)})


func storage_contract() -> void:
	# Retain the accepted writer's shared-path and same-controller retry checks.
	# The separate storage case covers the successor's ten paths and byte budgets.
	var previous_archive: String = controller._run_archive
	controller._run_archive = "user://goblin/run-storage-contract.json"
	var value := {"seed":13, "nested":{"label":"preserve compact representation"}}
	var expected := JSON.stringify(value, "", true) + "\n"
	for path: String in [Controller.TRANSCRIPT_PATH, Controller.SUMMARY_PATH,
			Controller.REPLAY_RESULT_PATH, controller._run_archive]:
		check(controller._write_fixed(path, value), "fixed output succeeds: " + path)
		check(FileAccess.get_file_as_string(path) == expected,
			"fixed output retains exact accepted serialization: " + path)
	var previous_digest := FileAccess.get_sha256(Controller.TRANSCRIPT_PATH)
	for path: String in ["", "user://outside-goblin.json",
			"user://goblin/../outside-goblin.json"]:
		check(not controller._write_fixed(path, value), "non-allowlisted output refuses: " + path)
	check(FileAccess.get_sha256(Controller.TRANSCRIPT_PATH) == previous_digest,
		"path refusals preserve the existing complete audit")
	var supplied := OS.get_environment("CYBERSAND_GOBLIN_PROFILE")
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE", supplied.path_join("not-selected"))
	check(not controller._write_fixed(Controller.TRANSCRIPT_PATH, {"seed":99}),
		"mismatched isolated profile refuses an otherwise allowed output")
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE", supplied)
	check(FileAccess.get_sha256(Controller.TRANSCRIPT_PATH) == previous_digest,
		"profile refusal preserves the existing complete audit")
	# A genuine native destination refusal followed by recovery on the SAME
	# controller must retire the prior error as well as returning true.
	check(DirAccess.remove_absolute(Controller.REPLAY_RESULT_PATH) == OK,
		"isolated replay fixture file removed")
	check(DirAccess.make_dir_absolute(Controller.REPLAY_RESULT_PATH) == OK,
		"isolated native directory-collision fixture created")
	check(not controller._write_fixed(Controller.REPLAY_RESULT_PATH, value)
		and not controller.last_error.is_empty(), "native collision truthfully refuses")
	check(DirAccess.dir_exists_absolute(Controller.REPLAY_RESULT_PATH),
		"native refusal preserves the colliding destination")
	check(DirAccess.remove_absolute(Controller.REPLAY_RESULT_PATH) == OK,
		"isolated collision removed before retry")
	check(controller._write_fixed(Controller.REPLAY_RESULT_PATH, value)
		and controller.last_error.is_empty(), "same-controller retry clears the prior failure")
	check(FileAccess.get_file_as_string(Controller.REPLAY_RESULT_PATH) == expected,
		"same-controller retry publishes complete accepted bytes")
	controller._run_archive = previous_archive


func run() -> void:
	var launch: Dictionary = Controller.read_launch()
	if not check(launch.get("ok", false), "dedicated launcher profile is available"):
		await finish()
		return
	var original_profile := OS.get_environment("CYBERSAND_GOBLIN_PROFILE")
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE", "")
	var refused: Dictionary = Controller.read_launch()
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE", original_profile)
	check(not refused.get("ok", true), "missing dedicated-profile marker refuses before mounting a game")
	check(Controller.read_launch().get("ok", false), "profile refusal leaves the authorized test profile reusable")
	var actual_profile: Dictionary = Adapter.verify_profile()
	var export_directory := ProjectSettings.globalize_path(Controller.OUTPUT_DIR).replace("\\", "/").simplify_path()
	var profile_root := str(actual_profile.get("root", "")).replace("\\", "/").simplify_path().trim_suffix("/")
	if OS.get_name() == "Windows":
		export_directory = export_directory.to_lower()
		profile_root = profile_root.to_lower()
	check(export_directory.begins_with(profile_root + "/"), "fixed controller exports stay inside this disposable profile")
	controller = Controller.new()
	root.add_child(controller)
	storage_contract()
	controller.action_started.connect(_on_started)
	controller.action_observed.connect(_on_observed)
	controller.changed.connect(_on_changed)

	mode = "pause_resume"
	var first: Dictionary = await controller.run_campaign(configuration("construction", 8), launch.provenance)
	retain("pause_resume_stop", first)
	check(pause_seen and pause_verified, "decision Pause/resume was exercised during a real campaign")
	check(stopped_after_observation, "Stop was issued after a real completed observation")
	check(first.get("summary", {}).get("termination") == "stopped", "ordinary Stop has its own terminal classification")
	check(controller.attempted == 4 and first.get("steps", []).size() == 4, "Stop prevents the fifth game action")
	check(not controller.running and not controller.decisions_paused, "stopped campaign releases its lifecycle flags")
	check(controller.adapter.observe().get("paused", false), "Stop leaves the actual Workbench paused")
	var previous_adapter_id: int = controller.adapter.get_instance_id()
	var completed_at_stop: int = controller.completed
	for _frame: int in range(5): await process_frame
	check(controller.completed == completed_at_stop, "no late completed action appears after Stop")

	mode = "repeat"
	var second: Dictionary = await controller.run_campaign(configuration("material_playground", 4, 605), launch.provenance)
	retain("fresh_campaign_after_stop", second)
	check(second.get("summary", {}).get("termination") == "budget_complete", "a new campaign works after Stop")
	check(controller.attempted == 4 and controller.completed == 4, "new campaign resets its action counters")
	check(controller.adapter.get_instance_id() != previous_adapter_id, "new campaign creates a separate real application adapter")
	check(second.get("header", {}).get("fixture_id") == "material_playground" \
		and second.get("header", {}).get("seed") == 605, "new campaign retains its own fixture and seed")
	check(second.get("steps", []).is_empty() or second.steps[0].action.id == "pause", "policy goal restarts from its authored first action")
	var archive_one: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://goblin/run-001.json"))
	var archive_two: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://goblin/run-002.json"))
	check(archive_one is Dictionary and archive_two is Dictionary \
		and archive_one.get("summary", {}).get("termination") == "stopped" \
		and archive_two.get("summary", {}).get("termination") == "budget_complete",
		"fixed per-run archives preserve the stopped and succeeding campaigns")

	# Exercise the exact in-memory route used by the developer UI. The tape's
	# canonical integral values and JSON-loaded launch provenance must compare
	# by complete value identity, while every source/runtime field stays fenced.
	mode = "in_memory_replay"
	var before_replay_adapter_id: int = controller.adapter.get_instance_id()
	var replayed: Dictionary = await controller.run_campaign(configuration("material_playground", 4, 605), launch.provenance, second)
	retain("in_memory_replay", replayed)
	check(replayed.get("header", {}).get("replay") == true \
		and replayed.get("summary", {}).get("termination") == "budget_complete" \
		and controller.attempted == 4 and controller.completed == 4 \
		and controller.adapter.get_instance_id() != before_replay_adapter_id,
		"an actual in-memory tape replays four operations in a fresh mounted application")
	check(controller.replay_result.get("semantic_match") == true \
		and controller.replay_result.get("same_source_runtime") == true \
		and controller.replay_result.get("same_action_count") == true,
		"in-memory replay matches independently observed semantic state and exact source/runtime identity")
	var replay_export: Variant = JSON.parse_string(FileAccess.get_file_as_string(Controller.REPLAY_RESULT_PATH)) \
		if FileAccess.file_exists(Controller.REPLAY_RESULT_PATH) else null
	check(replay_export is Dictionary and replay_export.get("semantic_match") == true,
		"successful in-memory replay exports its actual comparison result")
	var replay_tape: Variant = JSON.parse_string(FileAccess.get_file_as_string(Controller.TRANSCRIPT_PATH))
	check(not controller.export_path.is_empty() and replay_tape is Dictionary \
		and replay_tape.get("header", {}).get("replay") == true \
		and replay_tape.get("summary", {}).get("completed_actions") == 4,
		"fixed transcript export contains the newly completed replay rather than the earlier campaign")
	var archive_three: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://goblin/run-003.json")) \
		if FileAccess.file_exists("user://goblin/run-003.json") else null
	check(archive_three is Dictionary and archive_three.get("header", {}).get("replay") == true \
		and archive_three.get("summary", {}).get("completed_actions") == 4 \
		and replayed.get("controller", {}).get("run_archive") == "user://goblin/run-003.json",
		"in-memory replay receives its own third archive without overwriting the original tapes")

	# Deliberately inconsistent replay HEADER only: this is an infrastructure
	# refusal control, not an injected application defect or a runtime result.
	var mismatched: Dictionary = second.duplicate(true)
	mismatched.header.provenance.native_sha256 = "0".repeat(64)
	var held_adapter_id: int = controller.adapter.get_instance_id()
	var held_attempts: int = controller.attempted
	var source_refusal: Dictionary = await controller.run_campaign(configuration("construction", 4), launch.provenance, mismatched)
	check(source_refusal.has("error"), "test-only mismatched runtime identity refuses replay before mounting")
	check(controller.adapter.get_instance_id() == held_adapter_id and controller.attempted == held_attempts \
		and not controller.running, "replay identity refusal performs no new game action or application mount")

	mode = "stop_inflight"
	var third: Dictionary = await controller.run_campaign(configuration("construction", 8, 1701), launch.provenance)
	retain("stop_pending_real_paint", third)
	check(inflight_stop_seen, "Stop was exercised while the actual editor was busy")
	check(third.get("summary", {}).get("termination") == "stopped", "in-flight Stop remains a cancellation outcome")
	var interrupted: Dictionary = third.steps.back() if not third.get("steps", []).is_empty() else {}
	check(interrupted.get("classification") == "cancelled" and interrupted.get("status") in ["partial", "refused"],
		"interrupted native/edit attempt retains a cancelled terminal record")
	if interrupted.get("native_receipt", {}).is_empty():
		# A normal shape can be cancelled in its asynchronous planner before it
		# queues any native edit. A nonexistent native receipt must stay absent.
		var before_native: Dictionary = interrupted.get("before", {}).get("native", {})
		var after_native: Dictionary = interrupted.get("after", {}).get("native", {})
		check(before_native.has_all(["generation", "revision", "tick"]) \
			and before_native.get("generation") == after_native.get("generation") \
			and before_native.get("revision") == after_native.get("revision") \
			and before_native.get("tick") == after_native.get("tick"),
			"pre-native planner cancellation retains absent receipt and observed unchanged native state")
		check(interrupted.get("before", {}).get("editor_completed_actions") \
			== interrupted.get("after", {}).get("editor_completed_actions"),
			"cancelled planner does not invent a completed editor operation")
	else:
		check(interrupted.native_receipt.get("status") in ["cancelled", "refused", "completed", "invalidated"],
			"Stop after native submission preserves its actual terminal receipt")
	check(not third.has("pending_action"), "terminal record retires the exported pending proposal")
	check(not controller.adapter.editor.busy() and not bool(controller.adapter.worker.paint_state().get("busy", true)),
		"controller Stop drains the actual editor and native owner")

	mode = "stop_initialization"
	var fourth: Dictionary = await controller.run_campaign(configuration("construction", 4), launch.provenance)
	retain("stop_during_initialization", fourth)
	check(initialization_stop_seen, "Stop was requested at the real initialization boundary")
	check(fourth.get("summary", {}).get("termination") == "stopped", "initialization Stop is distinguished from a fixture or game failure")
	check(fourth.get("steps", []).is_empty(), "initialization Stop dispatches no game action")
	check(fourth.get("header", {}).get("seed") == 13 and fourth.get("header", {}).get("budget") == 4,
		"initialization Stop records the new campaign rather than reusing an earlier tape")
	mode = "finished"
	await finish()


func finish() -> void:
	if controller != null:
		await controller.close()
		controller.queue_free()
		await process_frame
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute(Controller.OUTPUT_DIR)
		var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"evidence_kind":"actual_headless_godot",
				"checks":checks, "failures":failures, "cases":cases, "pending_evidence":pending_evidence,
				"profile":Adapter.verify_profile()}, "\t", true) + "\n")
			file.close()
	print("GOBLIN_CONTROLLER " + JSON.stringify({"checks":checks, "failures":failures,
		"cases":cases.size(), "evidence_kind":"actual_headless_godot"}))
	quit(0 if failures.is_empty() else 1)
