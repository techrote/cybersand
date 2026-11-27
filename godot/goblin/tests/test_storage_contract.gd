extends SceneTree

## Guarded fixed-output contract; actual gameplay and semantic replay have their
## separate native tests. This test uses only its fresh Goblin profile.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Corpus = preload("res://goblin/goblin_corpus.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("GOBLIN_STORAGE_CONTRACT: " + label)


func run() -> void:
	if not Adapter.verify_profile().get("ok", false):
		check(false, "actual disposable-profile guard")
		finish()
		return
	var controller := Controller.new()
	controller._run_archive = Controller.OUTPUT_DIR + "/run-storage-contract.json"
	controller._candidate_archive = Controller.OUTPUT_DIR + "/candidate-storage-contract.json"
	var paths: Array[String] = [Controller.TRANSCRIPT_PATH, Controller.SUMMARY_PATH,
		Controller.REPLAY_RESULT_PATH, Controller.CORPUS_PATH, Controller.CORPUS_EXPORT_PATH,
		Controller.FINDINGS_PATH, Controller.REPRODUCTION_PATH, Controller.REDUCTION_PATH,
		controller._run_archive, controller._candidate_archive]
	var value := {"sequence":7, "text":"Complete compact UTF-8: π, ñ, 🌊", "nested":{"value":true}}
	var encoded := JSON.stringify(value, "", true) + "\n"
	for path: String in paths:
		check(controller._write_fixed(path, value), "admitted fixed path commits: " + path)
		check(FileAccess.get_file_as_string(path) == encoded, "exact compact UTF-8 bytes: " + path)
		var old_digest := FileAccess.get_sha256(path)
		var stale := FileAccess.open(path + ".partial", FileAccess.WRITE)
		stale.store_string("Unrelated retained staging")
		stale.close()
		check(controller._write_fixed(path, value), "same value replacement succeeds: " + path)
		check(FileAccess.get_sha256(path) == old_digest, "complete replacement remains exact: " + path)
		check(FileAccess.get_file_as_string(path + ".partial") == "Unrelated retained staging",
			"unrelated stale partial is retained: " + path)
	var corpus_digest := FileAccess.get_sha256(Controller.CORPUS_PATH)
	check(not controller._write_fixed(Controller.CORPUS_PATH, {"oversized":"x".repeat(Corpus.MAX_BYTES)}),
		"actual 2 MiB corpus serialized-byte bound refuses overflow")
	check(FileAccess.get_sha256(Controller.CORPUS_PATH) == corpus_digest,
		"corpus overflow preserves complete prior file")
	var export_digest := FileAccess.get_sha256(Controller.CORPUS_EXPORT_PATH)
	check(not controller._write_fixed(Controller.CORPUS_EXPORT_PATH, {"oversized":"x".repeat(Corpus.MAX_BYTES)}),
		"corpus export retains its separate 2 MiB bound")
	check(FileAccess.get_sha256(Controller.CORPUS_EXPORT_PATH) == export_digest,
		"corpus export overflow preserves complete prior file")
	var transcript_digest := FileAccess.get_sha256(Controller.TRANSCRIPT_PATH)
	check(not controller._write_fixed(Controller.TRANSCRIPT_PATH, {"oversized":"x".repeat(Transcript.MAX_BYTES)}),
		"actual 32 MiB transcript serialized-byte bound refuses overflow")
	check(FileAccess.get_sha256(Controller.TRANSCRIPT_PATH) == transcript_digest,
		"transcript overflow preserves complete prior file")
	for path: String in [controller._run_archive, controller._candidate_archive]:
		controller._archive_bytes = Controller.MAX_PROFILE_EVIDENCE_BYTES - encoded.to_utf8_buffer().size()
		check(controller._write_fixed(path, value), "exact cumulative archive budget is admitted: " + path)
		var old_digest := FileAccess.get_sha256(path)
		controller._archive_bytes += 1
		check(not controller._write_fixed(path, value), "one byte above cumulative archive budget is refused: " + path)
		check(FileAccess.get_sha256(path) == old_digest, "cumulative refusal preserves complete prior archive: " + path)
	controller._archive_bytes = 0
	check(not controller._write_fixed("user://outside-goblin-storage-contract.json", value), "unlisted output is refused")
	check(not FileAccess.file_exists("user://outside-goblin-storage-contract.json"), "unlisted output is not created")
	check(not controller._write_fixed("", value), "empty output is refused")
	var supplied := OS.get_environment("CYBERSAND_GOBLIN_PROFILE")
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE", supplied.path_join("not-selected"))
	check(not controller._write_fixed(Controller.TRANSCRIPT_PATH, value), "actual mismatched profile is refused")
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE", supplied)
	check(FileAccess.get_sha256(Controller.TRANSCRIPT_PATH) == transcript_digest,
		"profile refusal preserves complete prior transcript")
	controller.free()
	finish()


func finish() -> void:
	print("GOBLIN_STORAGE_CONTRACT_RESULT ", JSON.stringify({"checks":checks, "failed":failures.size(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)
