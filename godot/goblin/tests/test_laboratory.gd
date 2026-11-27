extends SceneTree

## Native laboratory lifecycle with separately labelled synthetic negative
## controls. All game activity is confined to the launcher's marked profile.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const Findings = preload("res://goblin/goblin_findings.gd")
const Corpus = preload("res://goblin/goblin_corpus.gd")
const State = preload("res://goblin/goblin_state.gd")
const REPORT_PATH := "user://goblin/laboratory-test.json"
var controller: Node
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var controls: Array[Dictionary] = []
var phase := ""
var step_stage := 0
var boundary_frame := 0
var boundary_msec := 0
var started_msec := 0
var profile_root := ""
var contracts_only := false
var watchdog_fired := false

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String, synthetic: bool = false) -> bool:
	checks += 1
	if synthetic: controls.append({"label":label, "passed":condition, "evidence_kind":"deliberately_synthetic_control"})
	if not condition:
		failures.append(label)
		push_error("GOBLIN_LABORATORY " + label)
	return condition

func _process(_delta: float) -> bool:
	if controller == null or not controller.running: return false
	if Time.get_ticks_msec() - started_msec > 240000 and not watchdog_fired:
		watchdog_fired = true
		check(false, "actual laboratory lifecycle completed within its 240-second local bound")
		controller.stop()
		phase = "watchdog"
		return false
	if phase != "stepping" or controller.state != "paused": return false
	if boundary_frame == 0:
		boundary_frame = Engine.get_process_frames()
		boundary_msec = Time.get_ticks_msec()
		return false
	if Engine.get_process_frames() < boundary_frame + 5 or Time.get_ticks_msec() < boundary_msec + 80: return false
	boundary_frame = Engine.get_process_frames()
	boundary_msec = Time.get_ticks_msec()
	match step_stage:
		0:
			check(controller.attempted == 0 and controller.completed == 0, "start-paused dispatches no action across real process frames")
			check(controller.decisions_paused, "decision pause is explicit before Step")
			controller.step_decision()
			step_stage = 1
		1:
			check(controller.attempted == 1 and controller.completed == 1, "first Step completes exactly one actual operation then pauses")
			check(controller.decisions_paused and controller._step_tokens == 0, "first Step returns to bounded decision pause")
			controller.step_decision()
			step_stage = 2
		2:
			check(controller.attempted == 2 and controller.completed == 2, "second Step completes exactly one additional actual operation")
			check(controller.decisions_paused and controller._step_tokens == 0, "second Step does not leave an automatic action credit")
			controller.stop()
			step_stage = 3
	return false

func config(budget: int, policy: String = "CONTROL") -> Dictionary:
	return {"fixture_id":"construction", "policy":policy, "seed":13, "budget":budget, "pacing_ms":0,
		"evidence_kind":"headless_godot", "start_paused":false, "reuse_memory":false}

func run() -> void:
	var launch: Dictionary = Controller.read_launch()
	if not check(launch.get("ok", false), "verified isolated launcher profile is present"):
		await finish()
		return
	profile_root = str(launch.profile.root)
	controller = Controller.new()
	root.add_child(controller)
	_findings_controls()
	_candidate_controls()
	contracts_only = OS.get_environment("CYBERSAND_GOBLIN_LAB_CONTRACTS_ONLY") == "1"
	if contracts_only:
		_reduction_controls(_synthetic_passed_tape())
		await _synthetic_candidate_capture()
		await finish()
		return
	print("GOBLIN_LABORATORY_SYNTHETIC_PREFLIGHT ", JSON.stringify({"checks":checks, "failures":failures, "native_gameplay_evidence":false}))
	var options := config(8)
	options.start_paused = true
	phase = "stepping"
	started_msec = Time.get_ticks_msec()
	var stepped: Dictionary = await controller.run_campaign(options, launch.provenance)
	phase = "memory"
	check(step_stage == 3, "both real bounded Step operations reached their paused boundaries")
	check(stepped.get("summary", {}).get("termination") == "stopped" and stepped.get("steps", []).size() == 2, "Stop preserves the two-action stepped tape")
	check(Transcript.validate(stepped).get("ok", false), "stepped native tape validates")
	check(stepped.get("summary", {}).get("failures", ["missing"]).is_empty(), "stepped ordinary game actions satisfy independent oracles")
	cases.append({"case":"native_bounded_step", "transcript":stepped.duplicate(true)})
	if stepped.get("steps", []).size() != 2 or not Transcript.validate(stepped).get("ok", false):
		await finish()
		return
	var archive_path := str(stepped.get("controller", {}).get("run_archive", ""))
	var archive_digest := FileAccess.get_sha256(archive_path) if not archive_path.is_empty() else ""
	check(not archive_digest.is_empty(), "stepped tape has a durable archive before memory controls")
	# Cultivate a useful prefix through four ordinary admitted Workbench actions.
	# No corpus entry or game state is fabricated to supply this edit.
	phase = "cultivating_edit_prefix"
	started_msec = Time.get_ticks_msec()
	var cultivated: Dictionary = await controller.run_campaign(config(4), launch.provenance)
	var cultivated_actions: Array = Transcript.replay_actions(cultivated)
	var expected_ids: Array[String] = ["pause", "camera", "select_material", "rectangle"]
	var cultivated_ok: bool = cultivated.get("summary", {}).get("termination") == "budget_complete" \
		and cultivated_actions.size() == 4 and Transcript.validate(cultivated).get("ok", false)
	if cultivated_ok:
		for index: int in range(4):
			cultivated_ok = cultivated_ok and cultivated_actions[index].get("id") == expected_ids[index]
	check(cultivated_ok, "ordinary CONTROL campaign cultivates the four-action edit prefix")
	var cultivated_changed := _changed_native_cells(cultivated.get("steps", []).back()) if cultivated_ok else -1
	check(cultivated_changed > 0, "cultivated rectangle actually changes source-matched native material cells")
	cases.append({"case":"native_cultivated_edit_prefix", "transcript":cultivated.duplicate(true),
		"actual_changed_cells":cultivated_changed})
	if not cultivated_ok or cultivated_changed <= 0:
		await finish()
		return
	var cultivated_archive := str(cultivated.get("controller", {}).get("run_archive", ""))
	var cultivated_digest := FileAccess.get_sha256(cultivated_archive)
	check(not cultivated_digest.is_empty(), "cultivated native edit tape has its own durable archive")
	var before_records: int = int(controller.corpus.summary().records)
	check(before_records > 0, "actual admitted novelty supplies isolated experimental memory")
	var exported: Dictionary = controller.export_memory()
	check(exported.get("ok", false) and FileAccess.file_exists(Controller.CORPUS_EXPORT_PATH), "corpus exports to its fixed disposable location")
	var exported_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Controller.CORPUS_EXPORT_PATH))
	var cleared: Dictionary = controller.clear_memory()
	check(cleared.get("ok", false) and controller.corpus.summary().records == 0, "explicit Clear retires corpus memory")
	check(FileAccess.get_sha256(archive_path) == archive_digest, "Clear leaves the original game tape byte-identical")
	if check(exported_data is Dictionary, "exported memory is a supported JSON object"):
		check(_write_corpus_input(exported_data), "test stages only the fixed corpus import record")
		var imported: Dictionary = controller.import_memory()
		check(imported.get("ok", false) and int(controller.corpus.summary().records) == before_records, "Import restores actual retained observation hints")
		check(int(controller.corpus.summary().imported_unverified) == before_records, "imported records carry no inherited verification authority")
		var corrupted: Dictionary = exported_data.duplicate(true)
		if not corrupted.get("records", []).is_empty():
			corrupted.records[0].actions[0] = {"id":"external_command", "args":{}}
			corrupted.records[0].id = Corpus._entry_id(corrupted.records[0])
			_write_corpus_input(corrupted)
			var refused: Dictionary = controller.import_memory()
			check(not refused.get("ok", true), "deliberately invalid imported action is refused before game dispatch", true)
			check(int(controller.corpus.summary().records) == before_records, "failed import leaves previous memory intact", true)
			check(FileAccess.get_sha256(archive_path) == archive_digest, "failed import does not alter archived game evidence", true)
		_write_corpus_input(exported_data)
	# Select only an existing imported record whose complete four-action prefix
	# came from the actual cultivation tape. The seed chooses the supported
	# corpus offset; it does not insert actions or restore physical state.
	var retained_context: Dictionary = {}
	var retained_record_id := ""
	if exported_data is Dictionary:
		for record: Dictionary in exported_data.get("records", []):
			if record.get("reusable") == true and record.get("prefix_complete") == true \
				and _same_action_inputs(record.get("actions", []), cultivated_actions):
				retained_context = record.get("context", {}).duplicate(true)
				retained_record_id = str(record.get("id", ""))
				break
	var reuse_seed := -1
	if not retained_context.is_empty():
		for offset: int in range(64):
			if _same_action_inputs(controller.corpus.reuse_actions(retained_context, offset), cultivated_actions):
				reuse_seed = offset
				break
	check(reuse_seed >= 0 and not retained_record_id.is_empty(), "a bounded seed selects the imported actual four-action prefix")
	if reuse_seed < 0:
		await finish()
		return
	var reused_options := config(4, "OBSESSIVE_REPRODUCER")
	reused_options.seed = reuse_seed
	reused_options.reuse_memory = true
	phase = "reuse"
	started_msec = Time.get_ticks_msec()
	var reused: Dictionary = await controller.run_campaign(reused_options, launch.provenance)
	check(reused.get("summary", {}).get("termination") == "budget_complete", "a fresh disposable episode completes after memory import")
	check(int(reused.get("policy_summary", {}).get("retained_prefix_actions_proposed", 0)) == 4,
		"exactly four retained candidates are actually proposed in the fresh episode")
	check(_same_action_inputs(Transcript.replay_actions(reused), cultivated_actions),
		"all four actual reused action IDs and arguments match the cultivated prefix")
	var reused_changed := _changed_native_cells(reused.get("steps", []).back()) if reused.get("steps", []).size() == 4 else -1
	check(reused_changed > 0 and reused_changed == cultivated_changed,
		"reused rectangle independently reproduces the cultivated native material changes")
	check(reused.get("policy_summary", {}).get("coverage", {}).get("completed_admitted_actions") == reused.get("summary", {}).get("completed_actions"), "reused prefix earns coverage only from this episode's actual observations")
	check(FileAccess.get_sha256(archive_path) == archive_digest, "new episode preserves the first stepped archive")
	check(FileAccess.get_sha256(cultivated_archive) == cultivated_digest, "memory roundtrip and reuse preserve the original cultivated edit archive")
	cases.append({"case":"native_explicit_prefix_reuse", "transcript":reused.duplicate(true),
		"retained_record_id":retained_record_id, "selected_seed_offset":reuse_seed,
		"expected_action_inputs":cultivated_actions.duplicate(true), "actual_changed_cells":reused_changed})
	if reused.get("summary", {}).get("termination") != "budget_complete" or reused.get("steps", []).is_empty():
		await finish()
		return
	_reduction_controls(reused)
	var package: Dictionary = controller.export_reproduction(reused)
	check(package.get("ok", false), "valid native tape exports a reproduction bundle in the fixed profile")
	var package_digest := FileAccess.get_sha256(Controller.REPRODUCTION_PATH)
	var foreign: Dictionary = reused.duplicate(true)
	foreign.header.provenance.native_sha256 = "0".repeat(64)
	var unrelated: Dictionary = controller.export_reproduction(reused, foreign)
	check(not unrelated.get("ok", true), "unrelated reduced runtime cannot be bundled with original tape", true)
	check(FileAccess.get_sha256(Controller.REPRODUCTION_PATH) == package_digest, "refused unrelated export preserves the prior valid bundle", true)
	await _actual_reduction(stepped, launch.provenance)
	phase = "finished"
	await finish()

func _findings_controls() -> void:
	var findings: RefCounted = Findings.new()
	findings.begin_episode({"source_sha":"0".repeat(40), "fixture_id":"synthetic-control"}, 99)
	var row := {"index":0, "action":{"id":"pause", "args":{}}, "status":"completed", "classification":"game_observation",
		"observation_sha256":"a".repeat(64), "semantic_sha256":"b".repeat(64), "assertions":[]}
	findings.observe(row, {"score":2})
	check(findings.records.size() == 1 and findings.records[0].classification == "legal_unusual_gameplay", "synthetic novel success stays legal gameplay", true)
	row.index = 1
	row.status = "refused"
	row.classification = "not_applicable"
	findings.observe(row)
	check(findings.records.back().classification == "expected_refusal", "explicit inapplicability can be triaged as expected refusal", true)
	row.index = 2
	row.classification = "game_observation"
	row.error = "ordinary operation unexpectedly refused"
	findings.observe(row)
	check(findings.records.back().classification == "unresolved_observation", "unexamined gameplay refusal remains unresolved", true)
	row.index = 3
	row.status = "completed"
	row.assertions = [{"id":"deliberately_injected_failure", "kind":"gameplay", "status":"fail"}]
	findings.observe(row)
	check(findings.records.back().classification == "unresolved_observation", "injected assertion failure is never automatically a confirmed bug", true)
	var selected_id := str(findings.records.back().id)
	check(not findings.classify(selected_id, "confirmed_production_gameplay_defect", "unit control").get("ok", true), "manual menu cannot confirm a production defect", true)
	check(findings.classify(selected_id, "deliberate_negative_control", "synthetic invariant supplied by this unit test").get("ok", false), "supported manual triage preserves its explicit review note", true)
	check(findings.summary().confirmed_production_defects == 0, "synthetic controls leave confirmed production findings at zero", true)

func _reduction_controls(real_tape: Dictionary) -> void:
	var target: Dictionary = Controller._reduction_target(real_tape)
	check(target.get("kind") == "semantic_outcome", "successful tape reduction targets a legal semantic outcome", true)
	check(Controller._accept_reduction(real_tape, target), "matching completed semantic outcome is accepted as an observation", true)
	var timeout: Dictionary = real_tape.duplicate(true)
	Transcript.finish(timeout, "campaign_timeout")
	check(not Controller._accept_reduction(timeout, target), "infrastructure-incomplete tape cannot qualify a successful reduced observation", true)
	var failed := _synthetic_failed_tape(real_tape, "pause")
	var failure_target: Dictionary = Controller._reduction_target(failed)
	check(failure_target.get("kind") == "failed_invariant", "explicit injected assertion supplies a failure reduction target", true)
	check(Controller._accept_reduction(failed, failure_target), "same synthetic action and invariant satisfy the stated acceptance rule", true)
	var other := _synthetic_failed_tape(real_tape, "single_step")
	check(not Controller._accept_reduction(other, failure_target), "same-named failure on another action cannot replace the original target", true)
	Transcript.finish(failed, "campaign_timeout")
	check(not Controller._accept_reduction(failed, failure_target), "timeout cannot masquerade as a clean invariant reproduction", true)
	check(not Controller._accept_reduction(real_tape, {}), "missing reduction rule refuses", true)
	var numeric := _synthetic_failed_tape(real_tape, "brush", {"x":20, "y":20, "radius":1}, {"material":2, "cells":3})
	var numeric_target: Dictionary = Controller._reduction_target(numeric)
	var loaded: Variant = JSON.parse_string(JSON.stringify(numeric))
	check(loaded is Dictionary and Controller._accept_reduction(loaded, numeric_target),
		"JSON integral numeric representation preserves the same reduction contract", true)
	var different_args := _synthetic_failed_tape(real_tape, "brush", {"x":21, "y":20, "radius":1}, {"material":2, "cells":3})
	check(not Controller._accept_reduction(different_args, numeric_target),
		"same named failure under different action arguments cannot replace its target", true)
	var different_expected := _synthetic_failed_tape(real_tape, "brush", {"x":20, "y":20, "radius":1}, {"material":3, "cells":3})
	check(not Controller._accept_reduction(different_expected, numeric_target),
		"same named failure with a different expected contract cannot replace its target", true)

func _synthetic_failed_tape(real_tape: Dictionary, action_id: String, arguments: Dictionary = {}, expected: Variant = null) -> Dictionary:
	var header: Dictionary = real_tape.header.duplicate(true)
	header.budget = 1
	header.evidence_kind = "unit_fixture"
	var tape: Dictionary = Transcript.create(header)
	var row: Dictionary = real_tape.steps[0].duplicate(true)
	row.action = {"id":action_id, "args":arguments}
	Transcript.append(tape, row, [{"id":"deliberately_injected_invariant", "kind":"gameplay", "status":"fail", "expected":expected}])
	Transcript.finish(tape, "assertion_failure")
	return tape

func _write_corpus_input(value: Dictionary) -> bool:
	if not Adapter.verify_profile().get("ok", false): return false
	var file := FileAccess.open(profile_root.path_join("goblin-corpus.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.close()
	return true

func finish() -> void:
	if controller != null:
		await controller.close()
		controller.queue_free()
		await process_frame
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute(Controller.OUTPUT_DIR)
		var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"evidence_kind":"synthetic_laboratory_controls" if contracts_only else "actual_headless_godot_with_separate_synthetic_controls",
				"checks":checks, "failures":failures, "native_cases":cases, "synthetic_controls":controls,
				"profile":Adapter.verify_profile()}, "", true) + "\n")
			file.close()
	print("GOBLIN_LABORATORY " + JSON.stringify({"checks":checks, "failures":failures, "native_cases":cases.size(),
		"synthetic_controls":controls.size(), "evidence_kind":"synthetic_laboratory_controls" if contracts_only else "actual_headless_godot_with_separate_synthetic_controls"}))
	quit(0 if failures.is_empty() else 1)


func _synthetic_passed_tape() -> Dictionary:
	var header := {"fixture_id":"construction", "fixture_version":2, "fixture_state":"installed",
		"initial_scene_identity":"synthetic-unit-scene", "policy":"CONTROL", "seed":13, "budget":1,
		"evidence_kind":"unit_fixture", "provenance":{"source_commit":"1".repeat(40), "source_tree":"2".repeat(40),
			"godot_sha256":"3".repeat(64), "native_sha256":"4".repeat(64), "rapier_sha256":"5".repeat(64)}}
	var tape: Dictionary = Transcript.create(header)
	var row := {"action":{"id":"pause", "args":{}}, "status":"completed", "classification":"game_observation",
		"before":{}, "after":{"paused":true}, "admission":{"accepted":true}, "native_receipt":{},
		"interval":{}, "duration_usec":0}
	Transcript.append(tape, row, [{"id":"synthetic_unit_pass", "kind":"evidence", "status":"pass"}])
	Transcript.finish(tape, "budget_complete")
	return tape


func _actual_reduction(template: Dictionary, provenance: Dictionary) -> void:
	phase = "legal_outcome_reduction"
	started_msec = Time.get_ticks_msec()
	var actions: Array = []
	for _index: int in range(4): actions.append({"id":"pause", "args":{}, "goal":"Observe an already paused authored fixture"})
	var reproduction: Dictionary = Controller._action_fixture(template, actions)
	var original: Dictionary = await controller.run_campaign(config(4), provenance, {}, reproduction)
	check(original.get("summary", {}).get("termination") == "budget_complete" and original.get("steps", []).size() == 4,
		"legal-outcome reduction starts with four actual ordinary pause operations")
	if original.get("summary", {}).get("termination") != "budget_complete":
		cases.append({"case":"native_positive_semantic_reduction", "status":"initial_campaign_failed", "original_tape":original, "gameplay_defect_confirmed":false})
		return
	var archive := str(original.get("controller", {}).get("run_archive", ""))
	var original_digest := FileAccess.get_sha256(archive)
	var result: Dictionary = await controller.reduce_tape(original, provenance)
	check(result.get("ok", false) and result.get("reduction_success", false), "actual in-game reduction retains a reproducible legal semantic outcome")
	var confirmations := 0
	for probe: Dictionary in result.get("probes", []):
		if probe.get("kind") == "baseline_confirmation" and probe.get("accepted", false): confirmations += 1
	check(confirmations == 2, "positive reduction performs two independently restarted native baseline observations")
	check(int(result.get("reduced_actions", 4)) < 4 and int(result.get("reduced_actions", 0)) >= 1,
		"reduction removes redundant actual pause operations without erasing its observation")
	check(result.get("classification") == "legal_unusual_gameplay" and result.get("gameplay_defect_confirmed") == false,
		"positive reduction is explicitly legal gameplay, not a discovered bug")
	var reduced: Dictionary = result.get("reduced_tape", {})
	var target: Dictionary = Controller._reduction_target(original)
	check(not reduced.is_empty() and Controller._accept_reduction(reduced, target), "reduced native tape satisfies the original exact semantic acceptance rule")
	check(FileAccess.get_sha256(archive) == original_digest, "automatic reduction preserves its original archived tape byte-for-byte")
	var exported: Dictionary = controller.export_reproduction(original, reduced)
	check(exported.get("ok", false), "matching observed reduction exports a developer reproduction bundle")
	if exported.get("ok", false):
		var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string(Controller.REPRODUCTION_PATH))
		check(bundle is Dictionary and bundle.get("classification") == "legal_unusual_gameplay"
			and bundle.get("gameplay_defect_confirmed") == false
			and bundle.get("reduced_tape", {}).get("steps", []).size() < 4,
			"portable bundle carries actual reduced tape and legal-outcome classification")
	cases.append({"case":"native_positive_semantic_reduction", "classification":"legal_unusual_gameplay",
		"original_tape":original, "reduction":result, "export":exported, "gameplay_defect_confirmed":false})

# These deliberately invented records test evidence custody only. They never
# mount a World, invoke game actions, or count as a production defect.
func _candidate_controls() -> void:
	var failed := _synthetic_failed_tape(_synthetic_passed_tape(), "pause")
	failed["initial_authored_fixture"] = {"synthetic_control":true, "not_a_native_fixture":true}
	var before_hash := Adapter.digest(failed)
	var bundle: Dictionary = Controller._reproduction_bundle(failed, {}, {}, true)
	check(bundle.get("captured_automatically") == true, "synthetic automatic candidate records its capture origin", true)
	check(bundle.get("classification") == "unresolved_observation" and bundle.get("gameplay_defect_confirmed") == false,
		"automatic capture never promotes an injected failure to a production defect", true)
	check(Adapter.digest(bundle.get("original_tape", {})) == before_hash and Adapter.digest(failed) == before_hash,
		"automatic bundle retains the complete original tape without mutating it", true)
	check(bundle.get("exact_provenance") == failed.header.provenance and bundle.get("initial_authored_fixture") == failed.initial_authored_fixture,
		"automatic bundle retains exact source and original authored fixture evidence", true)
	var target: Dictionary = bundle.get("expected_invariant", {})
	check(target.get("kind") == "failed_invariant" and target.get("action_id") == "pause"
		and target.get("id") == "deliberately_injected_invariant",
		"automatic candidate target binds the injected invariant and observed action", true)
	check(bundle.get("action_fixture", {}).get("actions") == Transcript.replay_actions(failed)
		and bundle.get("reduced_tape", {}).is_empty() and bundle.get("reduction", {}).is_empty(),
		"uncorroborated automatic candidate contains replay input without invented reduction", true)


func _synthetic_candidate_capture() -> void:
	# Contracts-only mode executes the ordinary fixed-path finish writer using
	# an explicitly synthetic tape. The default native laboratory never enters it.
	var failed := _synthetic_failed_tape(_synthetic_passed_tape(), "pause")
	failed["initial_authored_fixture"] = {"synthetic_control":true, "not_a_native_fixture":true}
	controller.transcript = failed
	controller._run_serial = 1
	controller._run_archive = Controller.OUTPUT_DIR + "/run-001.json"
	controller._candidate_archive = Controller.OUTPUT_DIR + "/candidate-001.json"
	controller._started_msec = Time.get_ticks_msec()
	controller.running = true
	controller.attempted = 1
	controller.completed = 1
	controller.budget = 1
	var finished_tape: Dictionary = await controller._finish("assertion_failure", {})
	check(not controller.export_path.is_empty() and FileAccess.file_exists(controller._candidate_archive),
		"synthetic finish actually writes the fixed automatic candidate file", true)
	var candidate: Variant = JSON.parse_string(FileAccess.get_file_as_string(controller._candidate_archive))
	check(candidate is Dictionary and candidate.get("captured_automatically") == true
		and candidate.get("classification") == "unresolved_observation"
		and candidate.get("gameplay_defect_confirmed") == false,
		"fixed synthetic candidate file keeps unresolved classification and no game-bug claim", true)
	if candidate is Dictionary:
		check(Adapter.digest(Transcript._json_value(candidate.get("original_tape", {}))) == Adapter.digest(Transcript._json_value(finished_tape)),
			"written candidate contains the exact final synthetic tape", true)
		check(candidate.get("original_tape", {}).get("controller", {}).get("automatic_candidate_bundle") == controller._candidate_archive
			and candidate.get("original_tape", {}).get("header", {}).get("evidence_kind") == "unit_fixture",
			"retained candidate identifies its fixed path and synthetic evidence origin", true)
	var archived: Variant = JSON.parse_string(FileAccess.get_file_as_string(controller._run_archive))
	check(archived is Dictionary and Adapter.digest(Transcript._json_value(archived)) == Adapter.digest(Transcript._json_value(finished_tape)),
		"automatic capture also retains the separate original archive unchanged", true)


func _same_action_inputs(first: Array, second: Array) -> bool:
	if first.size() != second.size(): return false
	for index: int in range(first.size()):
		if not first[index] is Dictionary or not second[index] is Dictionary: return false
		var a := {"id":first[index].get("id"), "args":first[index].get("args")}
		var b := {"id":second[index].get("id"), "args":second[index].get("args")}
		if Controller.evidence_digest(a) != Controller.evidence_digest(b): return false
	return true


func _changed_native_cells(row: Dictionary) -> int:
	var before: Dictionary = row.get("capture_before", {})
	var after: Dictionary = row.get("capture_after", {})
	var receipt: Dictionary = row.get("native_receipt", {})
	if row.get("status") != "completed" or row.get("action", {}).get("id") != "rectangle" \
		or receipt.get("backend") != "CyberNativeCellWorld" or receipt.get("kind") != "edit" or receipt.get("status") != "completed":
		return -1
	if not State.valid_capture(before, row.get("before", {}).get("native", {})) \
		or not State.valid_capture(after, row.get("after", {}).get("native", {})) or before.region != after.region:
		return -1
	var changed := 0
	for index: int in range(before.materials.size()):
		if before.materials[index] != after.materials[index]: changed += 1
	return changed if int(receipt.get("changed", -1)) == changed else -1
