extends SceneTree

## Native laboratory lifecycle with separately labelled synthetic negative
## controls. All game activity is confined to the launcher's marked profile.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const Findings = preload("res://goblin/goblin_findings.gd")
const Corpus = preload("res://goblin/goblin_corpus.gd")
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
	if Time.get_ticks_msec() - started_msec > 90000:
		check(false, "actual laboratory lifecycle completed within its 90-second local bound")
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
	var archive_path := str(stepped.get("controller", {}).get("run_archive", ""))
	var archive_digest := FileAccess.get_sha256(archive_path) if not archive_path.is_empty() else ""
	check(not archive_digest.is_empty(), "stepped tape has a durable archive before memory controls")
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
	var reused_options := config(4, "OBSESSIVE_REPRODUCER")
	reused_options.reuse_memory = true
	phase = "reuse"
	started_msec = Time.get_ticks_msec()
	var reused: Dictionary = await controller.run_campaign(reused_options, launch.provenance)
	check(reused.get("summary", {}).get("termination") == "budget_complete", "a fresh disposable episode completes after memory import")
	check(int(reused.get("policy_summary", {}).get("retained_prefix_actions_proposed", 0)) > 0, "explicit matching-memory reuse proposes a retained authored prefix")
	check(reused.get("policy_summary", {}).get("coverage", {}).get("completed_admitted_actions") == reused.get("summary", {}).get("completed_actions"), "reused prefix earns coverage only from this episode's actual observations")
	check(FileAccess.get_sha256(archive_path) == archive_digest, "new episode preserves the first stepped archive")
	cases.append({"case":"native_explicit_prefix_reuse", "transcript":reused.duplicate(true)})
	_reduction_controls(reused)
	var package: Dictionary = controller.export_reproduction(stepped)
	check(package.get("ok", false), "valid native tape exports a reproduction bundle in the fixed profile")
	var package_digest := FileAccess.get_sha256(Controller.REPRODUCTION_PATH)
	var foreign: Dictionary = stepped.duplicate(true)
	foreign.header.provenance.native_sha256 = "0".repeat(64)
	var unrelated: Dictionary = controller.export_reproduction(stepped, foreign)
	check(not unrelated.get("ok", true), "unrelated reduced runtime cannot be bundled with original tape", true)
	check(FileAccess.get_sha256(Controller.REPRODUCTION_PATH) == package_digest, "refused unrelated export preserves the prior valid bundle", true)
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

func _synthetic_failed_tape(real_tape: Dictionary, action_id: String) -> Dictionary:
	var header: Dictionary = real_tape.header.duplicate(true)
	header.budget = 1
	header.evidence_kind = "unit_fixture"
	var tape: Dictionary = Transcript.create(header)
	var row: Dictionary = real_tape.steps[0].duplicate(true)
	row.action = {"id":action_id, "args":{}}
	Transcript.append(tape, row, [{"id":"deliberately_injected_invariant", "kind":"gameplay", "status":"fail"}])
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
			file.store_string(JSON.stringify({"evidence_kind":"actual_headless_godot_with_separate_synthetic_controls",
				"checks":checks, "failures":failures, "native_cases":cases, "synthetic_controls":controls,
				"profile":Adapter.verify_profile()}, "", true) + "\n")
			file.close()
	print("GOBLIN_LABORATORY " + JSON.stringify({"checks":checks, "failures":failures, "native_cases":cases.size(),
		"synthetic_controls":controls.size(), "evidence_kind":"actual_headless_godot_with_separate_synthetic_controls"}))
	quit(0 if failures.is_empty() else 1)
