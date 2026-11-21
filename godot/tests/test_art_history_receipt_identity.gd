extends SceneTree
## Pending-only commit tracking at the real archive boundary. Use isolated user data.
const P = preload("res://scripts/art_provider.gd")
var checks := 0
var failures: Array[String] = []
var providers: Array[Node] = []
var paths: Array[String] = []
var next_identity := 1

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func provider() -> Node:
	var value := P.new(); root.add_child(value); providers.append(value); return value
func append(value: Node, kind: String, data: Variant) -> bool:
	var stored: bool = value.log_event(kind,data)
	if not value.log_path.is_empty() and not paths.has(value.log_path): paths.append(value.log_path)
	return stored
func session() -> Node:
	var value := provider()
	check(append(value,"conversation",{"role":"user","content":"original fixture"}),"real initial archive commits")
	return value
func item(source: String, epoch: Variant = 7) -> Dictionary:
	var number := next_identity; next_identity += 1
	var identity := str(number).pad_zeros(20)+"-"+str(number).pad_zeros(32)
	# Model the actual durable-journal boundary, including JSON's numeric types.
	return JSON.parse_string(JSON.stringify({"id":identity,"source":source,"epoch":epoch,"receipt":{"_history_receipt_id":identity,"action":"undo","status":"completed","applied":1,"token":number,"label":"fixture"}}))
func turn(value: Node, receipt: Dictionary) -> Dictionary:
	var recorded: Dictionary = value._sanitized_event_data("history_result",receipt.receipt)
	return {"role":"user","content":value.redact("Canvas result (world epoch %d): Human %s: %s" % [int(receipt.epoch),str(recorded.action),JSON.stringify(recorded)]),"_history_receipt_id":receipt.id}
func frozen_item(value: Node, source: String, epoch: int = 7) -> Dictionary:
	var candidate := item(source,epoch)
	candidate.schema = 2
	var recorded: Dictionary = value._sanitized_event_data("history_result",candidate.receipt)
	recorded._history_world_epoch = epoch
	recorded = JSON.parse_string(JSON.stringify(recorded))
	var content: String = value.redact("Canvas result (world epoch %d): Human %s: %s" % [epoch,str(recorded.action),JSON.stringify(recorded)])
	candidate.turn = {"role":"user","content":content,"_history_receipt_id":candidate.id}
	recorded._history_turn_sha256 = content.sha256_text()
	candidate.receipt = recorded
	return JSON.parse_string(JSON.stringify(candidate))
func state_is(value: Node, identity: String, raw: bool, visible: bool) -> bool:
	var status: Dictionary = value.history_receipt_state(identity)
	return bool(status.raw) == raw and bool(status.turn) == visible
func legacy_path() -> String:
	var path := "user://art-traffic/receipt-identity-"+Crypto.new().generate_random_bytes(12).hex_encode()+".jsonl"
	paths.append(path)
	return path
func write(path: String, content: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	check(file != null,"fixture file opens")
	if file == null: return
	file.store_string(content); file.flush(); file = null
func line(kind: String, data: Variant) -> String:
	return JSON.stringify({"kind":kind,"data":data})+"\n"

func checkpoint_retry_case() -> void:
	var original := session()
	var original_path: String = original.log_path
	var original_hash := FileAccess.get_sha256(original_path)
	var path := "user://receipt-checkpoint-"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	var backup := path+".original"
	var config := ConfigFile.new(); config.set_value("session","traffic_path",original_path)
	check(config.save(path) == OK,"checkpoint fixture starts with a real profile")
	var profile_hash := FileAccess.get_sha256(path)
	check(DirAccess.rename_absolute(path,backup) == OK and DirAccess.make_dir_absolute(path) == OK,"profile replacement directory injects real atomic-checkpoint failure")
	var sentinel := path.path_join("obstruction")
	write(sentinel,"keep this directory intact\n")
	var continuation := provider()
	check(continuation.resume_traffic(original_path).size() == 1 and continuation.resume_ok,"checkpoint test restores original immutable archive")
	var pending := frozen_item(continuation,original_path,31)
	check(continuation.watch_history_receipt(pending),"checkpoint test registers the durable receipt identity")
	var checkpoint_calls: Array[int] = [0]
	continuation.commit_segment = func(destination: String) -> bool:
		checkpoint_calls[0] += 1
		var next := ConfigFile.new(); next.set_value("session","traffic_path",destination)
		var temporary := path+".partial"
		if next.save(temporary) != OK: return false
		var result: Dictionary = P.Archive.atomic_replace(temporary,path)
		if not bool(result.get("ok",false)): DirAccess.remove_absolute(temporary)
		return bool(result.get("ok",false))
	var count_before := DirAccess.get_files_at("user://art-traffic").size()
	check(not append(continuation,"history_result",pending.receipt) and continuation.log_path.is_empty() and not continuation.last_event_stored,"first profile refusal leaves the receipt explicitly pending")
	var retained: String = continuation._pending_history_segment.get("destination","")
	check(not retained.is_empty() and FileAccess.file_exists(retained),"exactly one complete first-history segment is retained for checkpoint retry")
	if retained.is_empty(): return
	paths.append(retained)
	var retained_bytes := FileAccess.get_file_as_string(retained)
	var retained_hash := FileAccess.get_sha256(retained)
	var bounded := true
	for _attempt in range(5):
		bounded = not append(continuation,"history_result",pending.receipt) and bounded
		bounded = DirAccess.get_files_at("user://art-traffic").size() == count_before+1 and bounded
		bounded = FileAccess.get_sha256(retained) == retained_hash and continuation.log_path.is_empty() and bounded
	check(bounded and checkpoint_calls[0] == 6,"five further real profile refusals reuse the one unchanged raw-only segment")
	var different := frozen_item(continuation,original_path,32)
	continuation.watch_history_receipt(different)
	check(not append(continuation,"history_result",different.receipt) and not append(continuation,"probe",{"text":"later unrelated traffic"}) and DirAccess.get_files_at("user://art-traffic").size() == count_before+1,"different traffic cannot allocate another segment while the original checkpoint waits")
	check(FileAccess.get_sha256(backup) == profile_hash and FileAccess.get_sha256(original_path) == original_hash and FileAccess.get_file_as_string(sentinel) == "keep this directory intact\n","repeated checkpoint failures preserve original profile, archive and obstruction bytes")
	var tampered := retained_bytes.replace('"fixture"','"fixturE"')
	check(tampered != retained_bytes and tampered.to_utf8_buffer().size() == retained_bytes.to_utf8_buffer().size(),"tamper fixture changes content without changing segment length")
	write(retained,tampered)
	var calls_before := checkpoint_calls[0]
	check(not append(continuation,"history_result",pending.receipt) and checkpoint_calls[0] == calls_before and DirAccess.get_files_at("user://art-traffic").size() == count_before+1,"changed retained segment refuses adoption before checkpoint and without allocating a replacement")
	write(retained,retained_bytes)
	check(FileAccess.get_sha256(retained) == retained_hash,"restoring retained bytes restores its exact original identity")
	check(DirAccess.remove_absolute(sentinel) == OK and DirAccess.remove_absolute(path) == OK and DirAccess.rename_absolute(backup,path) == OK,"checkpoint filesystem becomes writable without repeating the native operation")
	check(append(continuation,"history_result",pending.receipt) and continuation.log_path == retained and continuation._pending_history_segment.is_empty() and state_is(continuation,pending.id,true,false),"successful checkpoint adopts the original segment without another raw append")
	check(append(continuation,"conversation",pending.turn) and state_is(continuation,pending.id,true,true),"the one pending result commits its visible conversation turn after checkpoint repair")
	var raw_count := 0; var turn_count := 0
	for text: String in FileAccess.get_file_as_string(retained).split("\n",false):
		var event: Dictionary = JSON.parse_string(text)
		if event.kind == "history_result": raw_count += 1
		if event.kind == "conversation": turn_count += 1
	check(raw_count == 1 and turn_count == 1 and DirAccess.get_files_at("user://art-traffic").size() == count_before+1,"six failed checkpoints plus recovery produce exactly one raw event and one visible result")
	var saved := ConfigFile.new()
	check(saved.load(path) == OK and saved.get_value("session","traffic_path","") == retained,"repaired profile names the verified retained segment")
	var reopened := provider(); reopened.watch_history_receipt(pending)
	var restored: Array = reopened.resume_traffic(retained)
	check(reopened.resume_ok and restored.size() == 2 and restored[1] == pending.turn and state_is(reopened,pending.id,true,true),"fresh provider replay confirms exactly one recovered result")
	check(FileAccess.get_sha256(original_path) == original_hash,"checkpoint repair never rewrites the original archive")
	# Losing the in-process pending checkpoint may leave one immutable orphan;
	# recovery follows the durable receipt and saved parent, never adopts it by guess.
	var parent_hash := FileAccess.get_sha256(retained)
	check(DirAccess.rename_absolute(path,backup) == OK and DirAccess.make_dir_absolute(path) == OK,"restart-boundary profile obstruction is real")
	write(sentinel,"restart checkpoint obstruction\n")
	var interrupted := provider(); interrupted.resume_traffic(retained)
	interrupted.commit_segment = continuation.commit_segment
	var next_pending := frozen_item(interrupted,retained,33)
	interrupted.watch_history_receipt(next_pending)
	var restart_count := DirAccess.get_files_at("user://art-traffic").size()
	check(not append(interrupted,"history_result",next_pending.receipt),"interrupted-provider fixture retains one unpublished-to-profile history segment")
	var orphan: String = interrupted._pending_history_segment.get("destination","")
	var orphan_hash := FileAccess.get_sha256(orphan)
	paths.append(orphan)
	providers.erase(interrupted); interrupted.free()
	check(FileAccess.file_exists(orphan) and DirAccess.get_files_at("user://art-traffic").size() == restart_count+1,"provider shutdown preserves the one bounded orphan and saved parent")
	check(DirAccess.remove_absolute(sentinel) == OK and DirAccess.remove_absolute(path) == OK and DirAccess.rename_absolute(backup,path) == OK,"profile repair restores its pre-interruption parent checkpoint")
	var recovery := provider(); recovery.watch_history_receipt(next_pending)
	check(recovery.resume_traffic(retained).size() == 2 and recovery.resume_ok,"fresh provider restores the committed parent without importing orphan history")
	recovery.commit_segment = continuation.commit_segment
	check(append(recovery,"history_result",next_pending.receipt) and append(recovery,"conversation",next_pending.turn) and recovery.log_path != orphan,"fresh provider commits the durable result into one new reachable segment")
	var last_reader := provider(); last_reader.watch_history_receipt(next_pending)
	var final_turns: Array = last_reader.resume_traffic(recovery.log_path)
	check(last_reader.resume_ok and final_turns.size() == 3 and final_turns[2] == next_pending.turn and state_is(last_reader,next_pending.id,true,true),"fresh-provider recovery has exactly one new result in model context")
	check(DirAccess.get_files_at("user://art-traffic").size() == restart_count+2 and FileAccess.get_sha256(orphan) == orphan_hash and FileAccess.get_sha256(retained) == parent_hash,"restart recovery preserves bounded orphan and original parent bytes")
	DirAccess.remove_absolute(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	var writer := session()
	var pending := item(writer.log_path)
	check(P.valid_history_receipt_id(pending.id),"generated stable identity is accepted")
	for invalid: Variant in ["",42,"-"+pending.id.substr(1),pending.id+"0",pending.id.replace("-","/"),"00000000000000000001-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]:
		check(not P.valid_history_receipt_id(invalid),"malformed history identity is refused")
	check(writer.watch_history_receipt(pending) and writer.watch_history_receipt(pending),"same immutable pending receipt registers idempotently")
	for key: String in ["source","epoch","receipt"]:
		var changed: Dictionary = pending.duplicate(true)
		if key == "source": changed.source = "user://art-traffic/unrelated.jsonl"
		elif key == "epoch": changed.epoch = 8
		else: changed.receipt.applied = 2
		check(not writer.watch_history_receipt(changed),"same ID cannot change "+key)
	for invalid_epoch: Variant in [-1,0.5,9007199254740992.0]:
		check(not writer.watch_history_receipt(item(writer.log_path,invalid_epoch)),"invalid epoch refuses before registration")
	var oversized := item(writer.log_path)
	oversized.receipt.label = "x".repeat(P.MAX_HISTORY_RECEIPT_BYTES)
	check(not writer.watch_history_receipt(oversized),"oversized pending payload refuses")
	var unsafe := item("user://art-traffic/../unrelated.jsonl")
	check(not writer.watch_history_receipt(unsafe),"noncanonical pending source refuses")
	var archive_before := FileAccess.get_sha256(writer.log_path)
	var unregistered := item(writer.log_path)
	check(not append(writer,"history_result",unregistered.receipt),"unregistered native receipt refuses append")
	check(not append(writer,"conversation",turn(writer,unregistered)),"unregistered explicit conversation receipt refuses append")
	var malformed: Dictionary = pending.receipt.duplicate(true); malformed._history_receipt_id = ""
	check(not append(writer,"history_result",malformed),"empty explicit receipt ID refuses append")
	check(not append(writer,"conversation",turn(writer,pending)),"visible result cannot precede its raw native receipt")
	var altered: Dictionary = pending.receipt.duplicate(true); altered.applied = 99
	check(not append(writer,"history_result",altered),"raw payload substitution refuses append")
	check(FileAccess.get_sha256(writer.log_path) == archive_before,"all refused writes preserve exact archive bytes")
	var observed: Array[bool] = [false]
	var inspect_commit := func() -> void:
		if writer.last_event_stored: observed[0] = state_is(writer,pending.id,true,false)
	writer.traffic_changed.connect(inspect_commit)
	check(append(writer,"history_result",pending.receipt),"registered native raw result commits")
	writer.traffic_changed.disconnect(inspect_commit)
	check(observed[0] and state_is(writer,pending.id,true,false),"raw commit is observable before filesystem-fault signal callbacks")
	archive_before = FileAccess.get_sha256(writer.log_path)
	for field: String in ["role","content","image_offset"]:
		var wrong := turn(writer,pending)
		if field == "role": wrong.role = "assistant"
		elif field == "content": wrong.content = wrong.content.replace("epoch 7","epoch 8")
		else: wrong.image_offset = 0
		check(not append(writer,"conversation",wrong),"wrong result "+field+" refuses append")
	check(FileAccess.get_sha256(writer.log_path) == archive_before,"invalid visible representations preserve committed raw event")
	var expected_turn := turn(writer,pending)
	check(append(writer,"conversation",expected_turn) and state_is(writer,pending.id,true,true),"exact user-visible turn commits independently")
	check(P.checked_conversation([expected_turn])[0]._history_receipt_id == pending.id,"conversation validation preserves structural receipt ID")
	var invalid_turn := expected_turn.duplicate(true); invalid_turn._history_receipt_id = "bad"
	check(P.checked_conversation([invalid_turn]) == null,"malformed structural turn ID refuses")
	var complete_bytes := FileAccess.get_file_as_string(writer.log_path)
	var complete_hash := FileAccess.get_sha256(writer.log_path)
	var reader := provider()
	check(reader.watch_history_receipt(pending) and reader.begin_resume(writer.log_path) == OK,"watched receipt starts incremental replay")
	var raw_end: int = complete_bytes.find('"kind":"conversation"',complete_bytes.find('"kind":"history_result"'))
	var progress: Dictionary = reader.poll_resume(maxi(1,raw_end))
	check(not progress.done and state_is(reader,pending.id,false,false),"partial raw observation is not published as trusted commit")
	reader.cancel_resume()
	check(state_is(reader,pending.id,false,false),"cancelled replay publishes no provisional receipt state")
	check(reader.resume_traffic(writer.log_path).size() == 2 and reader.resume_ok and state_is(reader,pending.id,true,true),"complete restart replay recovers raw and visible commits")
	check(FileAccess.get_sha256(writer.log_path) == complete_hash,"restart tracking never rewrites source archive")
	# A valid prefix followed by corruption must not establish commit state.
	write(writer.log_path,complete_bytes+"{bad trailing committed record}\n")
	var failed_reader := provider(); failed_reader.watch_history_receipt(pending)
	check(failed_reader.resume_traffic(writer.log_path).is_empty() and not failed_reader.resume_ok and state_is(failed_reader,pending.id,false,false),"late archive failure does not publish provisional commit state")
	write(writer.log_path,complete_bytes)
	check(FileAccess.get_sha256(writer.log_path) == complete_hash,"fault fixture restores exact original source")
	# A similarly shaped receipt in a different session cannot discharge this one.
	var foreign := session()
	var foreign_item: Dictionary = pending.duplicate(true); foreign_item.source = foreign.log_path
	check(foreign.watch_history_receipt(foreign_item) and append(foreign,"history_result",foreign_item.receipt) and append(foreign,"conversation",turn(foreign,foreign_item)),"independent session fixture has complete same-ID representation")
	var foreign_hash := FileAccess.get_sha256(foreign.log_path)
	var isolated := provider(); isolated.watch_history_receipt(pending)
	check(isolated.resume_traffic(foreign.log_path).is_empty() and not isolated.resume_ok and state_is(isolated,pending.id,false,false),"unrelated source cannot satisfy pending receipt")
	check(FileAccess.get_sha256(foreign.log_path) == foreign_hash,"source isolation refusal preserves foreign archive")
	var unrelated_writer := session(); unrelated_writer.watch_history_receipt(pending)
	archive_before = FileAccess.get_sha256(unrelated_writer.log_path)
	check(not append(unrelated_writer,"history_result",pending.receipt) and FileAccess.get_sha256(unrelated_writer.log_path) == archive_before,"live append rejects unrelated journal source")
	# Explicit user edits do not undo the fact that a journalled turn committed.
	check(append(writer,"conversation_cleared",{}),"explicit clear commits append-only")
	var cleared := provider(); cleared.watch_history_receipt(pending)
	check(cleared.resume_traffic(writer.log_path).is_empty() and cleared.resume_ok and state_is(cleared,pending.id,true,true),"cleared visible turn remains committed and must not resurrect")
	check(append(writer,"conversation_edited",{"turns":[{"role":"assistant","content":"replacement context"}],"last_result":""}),"explicit edited snapshot commits")
	var edited := provider(); edited.watch_history_receipt(pending)
	var edited_turns: Array = edited.resume_traffic(writer.log_path)
	check(edited.resume_ok and edited_turns.size() == 1 and edited_turns[0].content == "replacement context" and state_is(edited,pending.id,true,true),"edited-away result remains committed independently of current model context")
	# Legacy journal writer representation (ID only inside exact result text).
	var legacy := legacy_path()
	var legacy_item := item(legacy)
	var legacy_turn := turn(writer,legacy_item); legacy_turn.erase("_history_receipt_id")
	write(legacy,line("history_result",legacy_item.receipt)+line("conversation",legacy_turn)+line("conversation",legacy_turn))
	var legacy_hash := FileAccess.get_sha256(legacy)
	var legacy_reader := provider(); legacy_reader.watch_history_receipt(legacy_item)
	check(legacy_reader.resume_traffic(legacy).size() == 1 and legacy_reader.resume_ok and state_is(legacy_reader,legacy_item.id,true,true),"legacy exact-result markers deduplicate repeated visible archive results")
	check(FileAccess.get_sha256(legacy) == legacy_hash,"deduplication changes no historical archive bytes")
	var spoof := legacy_path()
	var spoof_item := item(spoof)
	var spoof_turn := turn(writer,spoof_item); spoof_turn.erase("_history_receipt_id")
	write(spoof,line("conversation",spoof_turn))
	var spoof_reader := provider(); spoof_reader.watch_history_receipt(spoof_item)
	check(spoof_reader.resume_traffic(spoof).is_empty() and not spoof_reader.resume_ok and state_is(spoof_reader,spoof_item.id,false,false),"an ID in text without matching preceding native event cannot fake a commit")
	# Newly captured IDs can join an active restore without waiting for a scan.
	var during := provider(); during.begin_resume(writer.log_path); during.poll_resume(1)
	var during_item := item(writer.log_path)
	check(during.resume_active and during.watch_history_receipt(during_item),"new immutable receipt registers during asynchronous restoration")
	while during.resume_active: during.poll_resume(256)
	check(during.resume_ok and state_is(during,during_item.id,false,false),"new receipt remains uncommitted after earlier archive replay")
	check(append(during,"history_result",during_item.receipt) and append(during,"conversation",turn(during,during_item)) and state_is(during,during_item.id,true,true),"new asynchronous receipt commits into a source-bound child segment")
	var redacted_writer := session()
	redacted_writer.secrets.assign(["a"])
	var redacted_item := item(redacted_writer.log_path)
	redacted_item.id = redacted_item.id.left(21)+"a".repeat(32)
	redacted_item.receipt._history_receipt_id = redacted_item.id
	redacted_item.receipt.api_key = "private-test-value"
	check(redacted_writer.watch_history_receipt(redacted_item),"redacted native receipt registers with structural identity intact")
	check(append(redacted_writer,"history_result",redacted_item.receipt) and append(redacted_writer,"conversation",turn(redacted_writer,redacted_item)),"credential redaction cannot alter stable raw or visible receipt identity")
	var redacted_bytes := FileAccess.get_file_as_string(redacted_writer.log_path)
	check(not redacted_bytes.contains("private-test-value") and redacted_bytes.contains(redacted_item.id),"archive keeps structural identity and excludes credential bytes")
	# Frozen schema-2 projection survives lost/changed process-local secrets.
	var frozen_writer := session()
	frozen_writer.secrets.assign(["Canvas","fixture"])
	var frozen := frozen_item(frozen_writer,frozen_writer.log_path,19)
	check(frozen.turn.content.begins_with("[redacted] result (") and frozen.receipt.label == "[redacted]","schema-2 fixture freezes sanitized text and native payload at capture")
	check(frozen_writer.watch_history_receipt(frozen),"schema-2 pending projection registers")
	frozen_writer.secrets.assign(["Human","completed"])
	check(frozen_writer.watch_history_receipt(frozen),"changing process secrets cannot change watched transaction identity")
	check(append(frozen_writer,"history_result",frozen.receipt),"frozen raw receipt commits without applying later secrets")
	var frozen_source: String = frozen_writer.log_path
	var frozen_raw_hash := FileAccess.get_sha256(frozen_source)
	var fresh_secret_state := provider()
	check(fresh_secret_state.secrets.is_empty() and fresh_secret_state.watch_history_receipt(frozen),"fresh process secret state accepts exact persisted projection")
	check(fresh_secret_state.resume_traffic(frozen_source).size() == 1 and fresh_secret_state.resume_ok and state_is(fresh_secret_state,frozen.id,true,false),"fresh secret state restores committed raw event awaiting its frozen visible result")
	var substituted_turn: Dictionary = frozen.turn.duplicate(true)
	substituted_turn.content += " uncommitted alteration"
	check(not append(fresh_secret_state,"conversation",substituted_turn),"frozen projection alteration refuses before append")
	substituted_turn = frozen.turn.duplicate(true); substituted_turn.extra = "unredacted credential"
	check(not append(fresh_secret_state,"conversation",substituted_turn),"extra fields cannot bypass redaction through frozen history write")
	check(append(fresh_secret_state,"conversation",frozen.turn) and state_is(fresh_secret_state,frozen.id,true,true),"recovery appends the exact captured visible result after secrets disappear")
	check(FileAccess.get_sha256(frozen_source) == frozen_raw_hash,"frozen result recovery preserves original raw-only archive bytes")
	var frozen_child: String = fresh_secret_state.log_path
	var frozen_child_hash := FileAccess.get_sha256(frozen_child)
	var restarted := provider(); restarted.secrets.assign(["Human","undo","completed"])
	check(restarted.watch_history_receipt(frozen),"second changed-secret restart registers unchanged frozen identity")
	var frozen_turns: Array = restarted.resume_traffic(frozen_child)
	check(restarted.resume_ok and frozen_turns.size() == 2 and frozen_turns[1] == frozen.turn and state_is(restarted,frozen.id,true,true),"second restart restores one exact visible result with no duplicate")
	check(restarted.resumed_last_result == frozen.turn.content,"redacted result prefix still restores last-result context via structural ID")
	for field: String in ["content","epoch","role","id","extra"]:
		var corrupted: Dictionary = frozen.duplicate(true)
		if field == "content": corrupted.turn.content += "tamper"
		elif field == "epoch": corrupted.epoch = 20
		elif field == "role": corrupted.turn.role = "assistant"
		elif field == "id": corrupted.turn._history_receipt_id = pending.id
		else: corrupted.turn.extra = "not a native projection"
		var validator := provider()
		check(not validator.watch_history_receipt(corrupted),"schema-2 journal rejects mismatched frozen "+field)
	var rebound_projection: Dictionary = frozen.duplicate(true)
	rebound_projection.turn.content += "tampered and rehashed"
	rebound_projection.receipt._history_turn_sha256 = rebound_projection.turn.content.sha256_text()
	var projection_validator := provider()
	check(projection_validator.watch_history_receipt(rebound_projection) and projection_validator.resume_traffic(frozen_child).is_empty() and not projection_validator.resume_ok and state_is(projection_validator,frozen.id,false,false),"already committed raw event rejects a replaced and rehashed projection")
	var rebound_epoch: Dictionary = frozen.duplicate(true)
	rebound_epoch.epoch = 20; rebound_epoch.receipt._history_world_epoch = 20.0
	var epoch_validator := provider()
	check(epoch_validator.watch_history_receipt(rebound_epoch) and epoch_validator.resume_traffic(frozen_child).is_empty() and not epoch_validator.resume_ok and state_is(epoch_validator,frozen.id,false,false),"already committed raw event rejects a rebound world epoch")
	check(FileAccess.get_sha256(frozen_child) == frozen_child_hash and FileAccess.get_sha256(frozen_source) == frozen_raw_hash,"all frozen-projection refusals preserve both original archive hashes")
	check(append(restarted,"probe",{"text":"Human undo completed"}),"ordinary traffic still writes through current credential redaction")
	var ordinary_bytes := FileAccess.get_file_as_string(restarted.log_path)
	check(not ordinary_bytes.contains("Human undo completed") and ordinary_bytes.contains("[redacted]"),"frozen-history exception does not bypass redaction for ordinary traffic")
	checkpoint_retry_case()
	var capped := provider()
	var admitted := true
	var first_id := ""
	for index: int in range(P.MAX_HISTORY_RECEIPTS):
		var candidate := item(writer.log_path)
		if index == 0: first_id = candidate.id
		admitted = capped.watch_history_receipt(candidate) and admitted
	check(admitted,"bounded tracker admits exactly 4096 pending receipt identities")
	var overflow := item(writer.log_path)
	check(not capped.watch_history_receipt(overflow),"tracker refuses overflow explicitly")
	capped.forget_history_receipt(first_id)
	check(capped.watch_history_receipt(overflow) and not capped.has_history_receipt(first_id) and state_is(capped,first_id,false,false),"completed cleanup releases exactly one tracking slot")
	for value: Node in providers: value.free()
	for path: String in paths: DirAccess.remove_absolute(path)
	print("ART_HISTORY_RECEIPT_IDENTITY_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
