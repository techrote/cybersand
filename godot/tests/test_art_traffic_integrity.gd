extends SceneTree
## Run only with isolated user data. Files created here use a per-process prefix.
const P = preload("res://scripts/art_provider.gd")
var checks := 0
var failures: Array[String] = []
var paths: Array[String] = []
var providers: Array[Node] = []
var prefix := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func path(name_text: String) -> String:
	var value := prefix + name_text + ".jsonl"
	if not paths.has(value): paths.append(value)
	return value
func write(name_text: String, content: String) -> String:
	var target := path(name_text)
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string(content); file.flush(); file = null
	return target
func line(kind: String, data: Variant) -> String: return JSON.stringify({"kind":kind,"data":data}) + "\n"
func provider() -> Node:
	var value := P.new(); root.add_child(value); providers.append(value); return value
func append(value: Node, kind: String, data: Variant) -> bool:
	var stored: bool = value.log_event(kind, data)
	if not value.log_path.is_empty() and not paths.has(value.log_path): paths.append(value.log_path)
	return stored
func refused(target: String, label: String) -> void:
	var value := provider()
	check(value.resume_traffic(target).is_empty() and not value.resume_ok and not value.resume_error.is_empty(), label)
	check(value.parent_log_path == target and not append(value, "conversation", {"role":"user","content":"must not fork"}) and value.log_path.is_empty(), label + " preserves pointer and refuses append")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	prefix = "user://art-traffic/integrity-" + Crypto.new().generate_random_bytes(8).hex_encode() + "-"
	var missing := path("missing")
	var prepared := provider()
	prepared.prepare_resume(missing)
	check(prepared.parent_log_path == missing and prepared.log_path.is_empty() and not FileAccess.file_exists(missing), "lazy prepare preserves missing reference without creating a file")
	refused(missing, "missing archive refused")
	refused(write("malformed", "{broken\n"), "malformed root refused")
	refused(write("truncated", line("conversation", {"role":"user","content":"kept"}) + "{truncated"), "legacy truncated record refused")
	var cycle_a := path("cycle-a"); var cycle_b := path("cycle-b")
	write("cycle-a", line("session_parent", {"path":cycle_b}))
	write("cycle-b", line("session_parent", {"path":cycle_a}))
	refused(cycle_a, "cyclic parents refused")
	refused(write("missing-parent", line("session_parent", {"path":missing})), "missing parent refused")
	refused(write("bad-parent", line("session_parent", {"path":42})), "malformed parent reference refused")
	var duplicate := JSON.stringify({"kind":"probe","data":{},"event_id":"duplicate"}) + "\n"
	refused(write("duplicate-event", duplicate + duplicate), "duplicate legacy event identifiers refused")
	var image := "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwnnn3PwAFVQKpTzibEAAAAABJRU5ErkJggg=="
	var request := line("request", {"body":{"input":[{"role":"user","content":[{"type":"input_image","image_url":image}]}]}})
	var legacy_bytes := request + line("conversation", {"role":"user","content":"legacy","image_offset":0})
	var legacy := write("legacy", legacy_bytes)
	var legacy_hash := FileAccess.get_sha256(legacy)
	var legacy_mtime := FileAccess.get_modified_time(legacy)
	refused(write("bad-offset", request + line("conversation", {"role":"user","content":"bad","image_offset":1})), "misaligned image offset refused")
	refused(write("bad-image-shape", line("request", {"body":null}) + line("conversation", {"role":"user","content":"bad","image_offset":0})), "malformed image payload refused safely")
	refused(write("bad-image-data", line("request", {"body":{"input":[{"content":[{"type":"input_image","image_url":"data:image/png;base64,broken"}]}]}}) + line("conversation", {"role":"user","content":"bad","image_offset":0})), "corrupt image base64 refused")
	refused(write("unrelated-image", line("conversation", {"role":"user","content":"bad","image_offset":0,"image_log_path":legacy})), "unrelated image segment refused")
	var value := provider()
	var restored: Array = value.resume_traffic(legacy)
	check(value.resume_ok and restored.size() == 1 and restored[0].image_log_path == legacy and value.historical_image(0, legacy) == image, "legacy image conversation restored read-only")
	check(value.log_path.is_empty() and FileAccess.get_sha256(legacy) == legacy_hash and FileAccess.get_modified_time(legacy) == legacy_mtime, "legacy bytes and mtime preserved during replay")
	check(append(value, "conversation", {"role":"assistant","content":"continued"}), "first continuation commits new segment")
	var child: String = value.log_path
	var child_text := FileAccess.get_file_as_string(child)
	var header: Dictionary = JSON.parse_string(child_text.get_slice("\n", 0))
	check(header.schema == 2 and header.data.parent_bytes == legacy_bytes.to_utf8_buffer().size() and header.data.parent_sha256 == legacy_hash, "child pins parent identity bytes and digest")
	check(FileAccess.get_sha256(legacy) == legacy_hash, "continuation preserves predecessor")
	var replay := provider()
	check(replay.resume_traffic(child).size() == 2 and replay.resume_ok and replay.historical_image(0, legacy) == image, "linked conversation and image restore")
	check(value.resume_traffic(legacy).is_empty() and not value.resume_ok, "active writer refuses rebind")
	var old_linked := write("old-linked", line("session_parent", {"path":legacy}) + line("conversation", {"role":"assistant","content":"pre-schema linked"}))
	var old_replay := provider()
	check(old_replay.resume_traffic(old_linked).size() == 2 and old_replay.resume_ok, "original path-only linked segments remain readable")
	write("legacy", legacy_bytes.replace('"legacy"', '"LEGACY"'))
	refused(child, "same-length predecessor replacement refused by digest")
	write("legacy", legacy_bytes)
	replay = provider()
	check(replay.resume_traffic(child).size() == 2 and replay.resume_ok, "restored parent reopens with refreshed read-only snapshot")
	# A copied segment cannot impersonate its parent identifier.
	var duplicate_header := header.duplicate(true)
	duplicate_header.data = {"path":child,"parent_id":header.segment_id,"parent_bytes":child_text.to_utf8_buffer().size(),"parent_sha256":FileAccess.get_sha256(child)}
	refused(write("duplicate-segment", JSON.stringify(duplicate_header) + "\n"), "duplicate segment identifiers refused")
	var bad_length := header.duplicate(true)
	bad_length.data.parent_bytes += 1
	refused(write("bad-length", JSON.stringify(bad_length) + "\n"), "inconsistent parent boundary refused")
	var root_value := provider()
	check(append(root_value, "conversation", {"role":"user","content":"before crash"}), "new root commits its first event")
	var crash_path: String = root_value.log_path
	var committed := FileAccess.get_file_as_string(crash_path)
	var file := FileAccess.open(crash_path, FileAccess.READ_WRITE)
	file.seek_end(); file.store_string('{"kind":"conversation","data":'); file.flush(); file = null
	var crashed_hash := FileAccess.get_sha256(crash_path)
	var recovered := provider()
	check(recovered.resume_traffic(crash_path).size() == 1 and recovered.resume_ok and not recovered.resume_warning.is_empty(), "modern interrupted tail recovers only complete events with warning")
	check(append(recovered, "conversation", {"role":"assistant","content":"after crash"}), "continuation after crash creates a separate child")
	var recovery_child: String = recovered.log_path
	var recovery_header: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(recovery_child).get_slice("\n", 0))
	check(recovery_header.data.parent_bytes == committed.to_utf8_buffer().size() and FileAccess.get_sha256(crash_path) == crashed_hash, "recovery pins committed prefix and preserves interrupted tail")
	var recovered_again := provider()
	check(recovered_again.resume_traffic(recovery_child).size() == 2 and recovered_again.resume_ok, "recovered child reopens through committed prefix")
	var recovered_export := path("recovery-export")
	check(recovered_again.export_traffic(recovered_export) == OK and FileAccess.get_file_as_string(recovered_export) == committed + FileAccess.get_file_as_string(recovery_child), "export contains only committed events after interrupted tail")
	var full_bad := write("bad-modern-record", committed + "{broken\n")
	refused(full_bad, "terminated malformed modern record refuses instead of recovering")
	# Export writes staging only until every source has validated.
	var destination := write("export", "previous export must remain\n")
	var destination_hash := FileAccess.get_sha256(destination)
	check(replay.begin_export(destination) == OK, "cooperative export starts")
	var progress: Dictionary = replay.poll_export(1)
	check(not progress.done and FileAccess.get_sha256(destination) == destination_hash, "uncommitted export leaves destination unchanged")
	check(not append(replay, "probe", {}), "active export rejects simultaneous append")
	replay.cancel_export()
	check(not replay.export_active and replay.export_error != OK and FileAccess.get_sha256(destination) == destination_hash, "cancel preserves previous destination")
	check(replay.export_traffic(destination) == OK and FileAccess.get_file_as_string(destination) == legacy_bytes + child_text, "successful export equals complete linked bytes")
	check(replay.export_traffic(legacy) == ERR_INVALID_PARAMETER and FileAccess.get_sha256(legacy) == legacy_hash, "export refuses source overwrite")
	var alias := path("alias")
	var directory := DirAccess.open("user://art-traffic")
	var link_error := directory.create_link(ProjectSettings.globalize_path(legacy), ProjectSettings.globalize_path(alias))
	if link_error == OK:
		check(replay.export_traffic(alias) == ERR_INVALID_PARAMETER and FileAccess.get_sha256(legacy) == legacy_hash, "symlink alias cannot truncate source")
	else: print("ART_TRAFFIC_SYMLINK_NOT_AVAILABLE ", link_error)
	var malformed_export := provider()
	malformed_export.prepare_resume(path("truncated"))
	var before_failed_export := FileAccess.get_sha256(destination)
	check(malformed_export.export_traffic(destination) != OK and FileAccess.get_sha256(destination) == before_failed_export, "validation failure leaves successful prior export intact")
	# Legacy linked parents are sealed once when entering the modern format.
	var grandparent := write("seal-a", line("conversation", {"role":"user","content":"old"}))
	var unsealed_parent := write("seal-b", line("session_parent", {"path":grandparent}))
	var migrated := provider()
	check(migrated.resume_traffic(unsealed_parent).size() == 1 and migrated.resume_ok, "path-only predecessor accepted before sealing")
	check(append(migrated, "conversation", {"role":"assistant","content":"sealed"}), "first modern child seals inherited legacy chain")
	var sealed_child: String = migrated.log_path
	write("seal-a", line("conversation", {"role":"user","content":"new"}))
	refused(sealed_child, "changed grandparent behind a path-only parent refused")
	# Successful writes must fit the exact same bounds as fresh-process replay.
	var capped := provider()
	check(not append(capped, "conversation", {"role":"user","content":"X".repeat(P.MAX_CONVERSATION_BYTES + 1)}) and capped.log_path.is_empty(), "oversized single turn refused before creating an archive")
	var many: Array = []
	for index: int in range(P.MAX_CONVERSATION_TURNS + 1): many.append({"role":"user","content":""})
	check(not append(capped, "conversation_edited", {"turns":many,"last_result":""}) and capped.log_path.is_empty(), "oversized edited turn count refused before creating an archive")
	capped.secrets.append("a")
	check(not append(capped, "conversation", {"role":"user","content":"a".repeat(2 * 1024 * 1024)}) and capped.log_path.is_empty(), "capacity uses sanitized content after redaction expansion")
	check(append(capped, "conversation", {"role":"user","content":"a"}), "short secret redacted without changing roles or segment IDs")
	var capped_replay := provider()
	var capped_turns: Array = capped_replay.resume_traffic(capped.log_path)
	check(capped_replay.resume_ok and capped_turns.size() == 1 and capped_turns[0].content == "[redacted]", "sanitized admitted turn reopens exactly")
	var receipt_writer := provider()
	check(append(receipt_writer, "deferred_human_stroke", {"token":42,"status":"queued"}), "numeric manual receipt token remains valid structured JSON")
	check(append(receipt_writer, "conversation", {"role":"user","content":"after receipt"}), "conversation follows real receipt shape")
	var receipt_replay := provider()
	check(receipt_replay.resume_traffic(receipt_writer.log_path).size() == 1 and receipt_replay.resume_ok, "numeric receipt and subsequent conversation reopen")
	# Read a known old writer defect without rewriting even one historical byte.
	var artifact := '{"kind":"deferred_human_stroke","data":{"token":[redacted],"status":"queued"}}\n'
	var artifact_bytes := artifact + request + line("conversation", {"role":"user","content":"after legacy receipt","image_offset":artifact.to_utf8_buffer().size()})
	var artifact_path := write("legacy-redaction", artifact_bytes)
	var artifact_hash := FileAccess.get_sha256(artifact_path)
	var artifact_reader := provider()
	check(artifact_reader.resume_traffic(artifact_path).size() == 1 and artifact_reader.resume_ok and artifact_reader.resume_warning.contains("redaction"), "known legacy unquoted redaction marker interpreted with warning")
	check(artifact_reader.export_traffic(path("legacy-redaction-export")) == OK and FileAccess.get_file_as_string(path("legacy-redaction-export")) == artifact_bytes and FileAccess.get_sha256(artifact_path) == artifact_hash, "legacy redaction read view preserves original and exported bytes")
	refused(write("unrelated-marker", '{"kind":"probe","data":{"count":[redacted]}}\n'), "unrelated malformed JSON is not repaired")
	var malformed_png := write("not-png", line("request", {"body":{"input":[{"content":[{"type":"input_image","image_url":"data:image/png;base64,YWJj"}]}]}}) + line("conversation", {"role":"user","content":"bad png","image_offset":0}))
	refused(malformed_png, "valid base64 containing non-PNG data refused")
	# Invalid UTF-8 must not turn into replacement-character conversation text.
	var invalid_utf8 := path("invalid-utf8")
	var invalid_file := FileAccess.open(invalid_utf8, FileAccess.WRITE)
	invalid_file.store_buffer('{"kind":"conversation","data":{"role":"user","content":"'.to_utf8_buffer())
	invalid_file.store_8(255)
	invalid_file.store_buffer('"}}\n'.to_utf8_buffer()); invalid_file.flush(); invalid_file = null
	refused(invalid_utf8, "invalid UTF8 archive refused without text substitution")
	var unicode_path := write("unicode", line("conversation", {"role":"user","content":"Café — 世界 🌊"}))
	var unicode_reader := provider()
	var unicode_turns: Array = unicode_reader.resume_traffic(unicode_path)
	check(unicode_reader.resume_ok and unicode_turns.size() == 1 and unicode_turns[0].content == "Café — 世界 🌊", "valid multibyte UTF8 is preserved")
	# The panel's durable pointer callback is part of committing the first event.
	var rejected_writer := provider()
	rejected_writer.commit_segment = func(_destination: String) -> bool: return false
	var before_rejection := DirAccess.get_files_at("user://art-traffic")
	check(not append(rejected_writer, "conversation", {"role":"user","content":"rejected"}) and rejected_writer.log_path.is_empty(), "failed profile pointer refuses first event")
	var orphan := ""
	for name_text: String in DirAccess.get_files_at("user://art-traffic"):
		if not before_rejection.has(name_text): orphan = "user://art-traffic/" + name_text; paths.append(orphan)
	check(not orphan.is_empty() and FileAccess.file_exists(orphan) and rejected_writer.log_warning.contains(orphan), "unreferenced complete segment remains explicitly identified")
	rejected_writer.commit_segment = func(_destination: String) -> bool: return true
	check(append(rejected_writer, "conversation", {"role":"user","content":"accepted"}), "later successful commit starts independent accepted state")
	var accepted_reader := provider()
	var accepted_turns: Array = accepted_reader.resume_traffic(rejected_writer.log_path)
	check(accepted_reader.resume_ok and accepted_turns.size() == 1 and accepted_turns[0].content == "accepted", "rejected orphan never leaks into later accepted history")
	# Lazy panels may receive native receipts before their first visible open.
	var early_writer := provider()
	check(append(early_writer, "deferred_human_stroke", {"token":1,"status":"queued"}), "hidden receipt can establish first segment")
	var early_path: String = early_writer.log_path
	var early_parent: String = early_writer.parent_log_path
	check(early_writer.resume_traffic(early_path).is_empty() and early_writer.resume_ok and early_writer.log_path == early_path and early_writer.parent_log_path == early_parent, "own active segment replays without rebinding writer or parent")
	check(append(early_writer, "conversation", {"role":"user","content":"after hidden receipt"}) and early_writer.log_path == early_path, "replayed active writer appends with continuous sequence identity")
	var early_replay := provider()
	check(early_replay.resume_traffic(early_path).size() == 1 and early_replay.resume_ok, "hidden receipt and later conversation reopen")
	var nul_path := path("embedded-nul")
	var nul_file := FileAccess.open(nul_path, FileAccess.WRITE)
	nul_file.store_string(line("conversation", {"role":"user","content":"prefix"}).trim_suffix("\n"))
	nul_file.store_8(0); nul_file.store_string("hidden trailing bytes\n"); nul_file.flush(); nul_file = null
	refused(nul_path, "embedded NUL cannot hide trailing archive bytes")
	# Cooperative restore is cancellable before its transcript commit point.
	var cooperative := provider()
	check(cooperative.begin_resume(legacy) == OK and cooperative.resume_active, "cooperative restore begins without publishing transcript")
	var restore_progress: Dictionary = cooperative.poll_resume(1)
	check(not restore_progress.done and not cooperative.resume_ok, "partial restore remains explicitly uncommitted")
	cooperative.cancel_resume()
	check(not cooperative.resume_active and not cooperative.resume_ok and cooperative.parent_log_path == legacy and FileAccess.get_sha256(legacy) == legacy_hash, "cancelled restore preserves saved pointer and bytes")
	check(cooperative.begin_resume(legacy) == OK, "cancelled restore can be retried")
	while cooperative.resume_active: restore_progress = cooperative.poll_resume(65536)
	check(restore_progress.ok and restore_progress.turns.size() == 1, "cooperative retry publishes complete validated transcript")
	var huge := write("oversized-record", "X".repeat(P.Archive.MAX_RECORD_BYTES + 1))
	refused(huge, "oversized record refused with bounded reader")
	var live_names := DirAccess.get_files_at("user://art-traffic")
	for name_text: String in live_names:
		check(not name_text.begins_with(destination.get_file() + ".partial-"), "cancelled or failed export removes its own staging file")
	for node: Node in providers: node.queue_free()
	await process_frame
	for target: String in paths: DirAccess.remove_absolute(target)
	print("ART_TRAFFIC_INTEGRITY ", JSON.stringify({"checks":checks,"failures":failures,"user_data":OS.get_user_data_dir()}))
	quit(0 if failures.is_empty() else 1)
