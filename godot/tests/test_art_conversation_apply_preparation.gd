extends SceneTree
## Actual Workbench, existing complete audit and real value-worker lifecycle.
## Draft values are deterministic fixtures; no HTTP/model or fake native writes.
const Setup = preload("res://scripts/workbench_setup.gd")
const Provider = preload("res://scripts/art_provider.gd")
const CANARY := "ART-APPLY-PRIVATE-2026-11-25"
const SIZE := 1024*1024
var host: Control
var wb: Control
var panel: Window
var checks := 0
var failures: Array[String] = []
var outcomes: Array = []
var observer_adopted := false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks += 1
	print("ART_CONVERSATION_APPLY_CHECK ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func until(predicate: Callable,label: String,timeout_ms: int = 90000) -> bool:
	var end := Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return check(bool(predicate.call()),label)

func ready() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and not wb.paint_editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy

func audit_offset() -> int:
	if panel.provider.log_path.is_empty(): return 0
	var file := FileAccess.open(panel.provider.log_path,FileAccess.READ)
	return int(file.get_length()) if file != null else -1

func event_count(after: int,kind: String) -> int:
	var file := FileAccess.open(panel.provider.log_path,FileAccess.READ)
	if file == null or after < 0: return -1
	file.seek(after)
	var count := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.get("kind") == kind: count += 1
	return count

func drain() -> void:
	await until(func() -> bool: return not panel.conversation_apply_pending() \
		and not panel.provider.conversation_edit_active(),"prepared edit retires and worker is reaped")
	for frame: int in 2: await process_frame

func seed() -> void:
	await drain()
	panel._open_conversation()
	panel.conversation_editor.draft.clear()
	panel._apply_conversation_edits()
	check(panel.conversation.is_empty(),"small explicit Apply clears future context and retains earlier audit")
	check(panel.remember_turn("user","x".repeat(SIZE)),"complete fixture conversation is admitted through Art")
	panel._open_conversation()
	for frame: int in 2: await process_frame
	var dialog = panel.conversation_editor
	dialog.content.text = "Z"+dialog.content.text.substr(1)
	dialog.content.text_changed.emit()

func apply() -> Dictionary:
	var before := {"revision":panel.conversation_revision,"offset":audit_offset(),
		"native":host.simulation_worker.paint_state().duplicate(true),"sequence":panel.executor.batch_sequence}
	panel.conversation_editor.get_ok_button().pressed.emit()
	check(panel.conversation_apply_pending(),"large Apply enters bounded preparation before owner commit")
	check(panel.conversation_editor.visible and panel.conversation_editor.apply_pending,
		"pending Apply remains visible with an explicit preparation state")
	check(not panel.conversation_editor.content.editable and panel.conversation_editor.get_ok_button().disabled
		and not panel.conversation_editor.get_cancel_button().disabled,
		"pending draft is read-only while Cancel remains available")
	check(panel.conversation_editor.content.text.length() <= 4096,
		"pending Apply keeps the visible message within4096characters")
	before.handle = panel._conversation_apply_handle
	before.identity = panel._conversation_apply_identity.duplicate(true)
	return before

func unchanged(before: Dictionary,label: String) -> void:
	check(event_count(int(before.offset),"conversation_edited")==0,label+" appends no edited snapshot")
	check(panel.executor.batch_sequence==before.sequence
		and host.simulation_worker.paint_state().revision==before.native.revision,
		label+" performs no native authoring")

func cancellation_checks() -> void:
	await seed()
	panel.last_image = "retained image marker"
	var before := apply()
	var snapshot: Array = panel.conversation_editor.draft.duplicate(true)
	panel.conversation_editor.note_button.pressed.emit()
	panel.conversation_editor.clear_button.pressed.emit()
	panel.conversation_editor.remove_button.pressed.emit()
	panel._apply_conversation_edits()
	check(panel.conversation_editor.draft==snapshot and panel._conversation_apply_handle==before.handle,
		"mutating draft actions and duplicate Apply cannot alter or duplicate pending work")
	check(panel.conversation_editor.content.intercept_paste.call("must not enter",0,false,false),
		"pending draft refuses a mutating paste")
	panel.conversation_editor.get_cancel_button().pressed.emit()
	await drain()
	check(not panel.conversation_editor.visible and panel.conversation_revision==before.revision
		and str(panel.conversation[0].content).begins_with("xx"),"ordinary Cancel preserves complete original live context")
	check(panel.last_image=="retained image marker","Cancel preserves existing admitted image context")
	panel._conversation_apply_ready(int(before.handle),before.identity,"")
	unchanged(before,"cancelled and deliberately late preparation completion")
	outcomes.append({"case":"cancel-and-late-completion","timing":panel.last_conversation_apply_timing.duplicate(true)})

	await seed()
	before = apply()
	panel.stop_all("Owner Stop during conversation preparation")
	await drain()
	check(panel.conversation_revision==before.revision and not panel.conversation_editor.apply_pending,
		"ordinary Stop retires preparation and unlocks the retained draft")
	unchanged(before,"Stop")
	panel.conversation_editor.hide()

	await seed()
	before = apply()
	panel.conversation_editor.hide()
	await drain()
	check(panel.conversation_revision==before.revision,"editor Hide retires pending Apply without adopting it")
	unchanged(before,"editor Hide")

func stale_checks() -> void:
	await seed()
	var before := apply()
	check(panel.remember_turn("assistant","newer acknowledged turn"),
		"real newer conversation turn is admitted during pure-value preparation")
	await drain()
	check(panel.conversation.size()==2 and panel.conversation[-1].content=="newer acknowledged turn"
		and panel.conversation_revision==before.revision+1,
		"stale prepared draft cannot overwrite a newer acknowledged turn")
	unchanged(before,"stale conversation")
	panel.conversation_editor.hide()

	await seed()
	before = apply()
	check(wb.new_canvas(),"actual World replacement admitted during preparation")
	await until(ready,"replacement native World is ready")
	await drain()
	check(host.simulation_worker.art_state().epoch!=int(before.identity.world_epoch),
		"the native World epoch actually changes")
	check(panel.conversation_revision==before.revision and event_count(int(before.offset),"conversation_edited")==0,
		"replacement World invalidates the pending edited snapshot")
	panel.conversation_editor.hide()

	await seed()
	before = apply()
	panel.provider.secrets.append(CANARY)
	await drain()
	check(panel.conversation_revision==before.revision and panel.conversation_editor.visible
		and panel.conversation_editor.content.editable,
		"changed credentials refuse old preparation and leave the draft available for fresh Apply")
	unchanged(before,"changed secret snapshot")
	panel.conversation_editor.hide()

func success_checks() -> void:
	await seed()
	var dialog = panel.conversation_editor
	var replacement := "prefix "+CANARY+" suffix"
	dialog.content.text = replacement+dialog.content.text.substr(1)
	dialog.content.text_changed.emit()
	var expected := "prefix [redacted] suffix"+"x".repeat(SIZE-1)
	var before := apply()
	await drain()
	check(not dialog.visible and panel.conversation_revision==before.revision+1,
		"successful owner commit closes the draft and advances its revision once")
	check(panel.conversation.size()==1 and panel.conversation[0].content==expected,
		"complete edited message is redacted before live adoption, including all unshown parts")
	check(event_count(int(before.offset),"conversation_edited")==1,
		"successful preparation appends exactly one complete edited snapshot")
	check(panel.executor.batch_sequence==before.sequence
		and host.simulation_worker.paint_state().revision==before.native.revision,
		"conversation Apply preserves native cells and native history")
	var reader := Provider.new()
	root.add_child(reader)
	var replayed: Array = reader.resume_traffic(panel.provider.log_path)
	check(replayed==panel.conversation,"independent archive replay reconstructs the complete committed conversation")
	reader.queue_free()
	outcomes.append({"case":"complete-redacted-success","characters":str(panel.conversation[0].content).length(),
		"sha256":str(panel.conversation[0].content).sha256_text(),
		"timing":panel.last_conversation_apply_timing.duplicate(true)})

	panel._open_conversation()
	before = apply()
	await drain()
	check(not dialog.visible and panel.conversation_revision==before.revision,
		"redacted no-op Apply closes without a new conversation revision")
	unchanged(before,"complete no-op Apply")

	await seed()
	before = {"revision":panel.conversation_revision,"offset":audit_offset()}
	observer_adopted = false
	var target_revision: int = panel.conversation_revision+1
	var observe_commit := func() -> void:
		if not observer_adopted and panel.conversation_revision==target_revision:
			observer_adopted = true
			check(not panel.conversation_apply_pending() and str(panel.conversation[0].content).begins_with("Zx"),
				"durable adoption is visible before traffic observers run")
			check(panel.remember_turn("assistant","observer after committed edit"),
				"audit observer can append a subsequent live turn")
	panel.provider.traffic_changed.connect(observe_commit)
	apply()
	await drain()
	panel.provider.traffic_changed.disconnect(observe_commit)
	check(observer_adopted and panel.conversation.size()==2
		and panel.conversation[-1].content=="observer after committed edit",
		"reentrant later turn survives without stale post-append replacement")
	check(event_count(int(before.offset),"conversation_edited")==1,
		"reentrant observer still sees only one edited snapshot")
	reader = Provider.new()
	root.add_child(reader)
	check(reader.resume_traffic(panel.provider.log_path)==panel.conversation,
		"full archive and live conversation agree after reentrant adoption")
	reader.queue_free()

func failed_append_check() -> void:
	await seed()
	var before := apply()
	var path := ProjectSettings.globalize_path(panel.provider.log_path)
	var backup := path+".apply-fixture-backup"
	check(DirAccess.rename_absolute(path,backup)==OK,"actual audit file is temporarily moved for append failure")
	check(DirAccess.make_dir_recursive_absolute(path)==OK,"a directory occupies the actual append destination")
	await drain()
	check(panel.conversation_revision==before.revision and panel.conversation_editor.visible
		and panel.conversation_editor.content.editable,
		"failed durable append never adopts prepared live changes and leaves editable draft")
	check(DirAccess.remove_absolute(path)==OK and DirAccess.rename_absolute(backup,path)==OK,
		"the original complete audit file is restored after the isolated failure")
	unchanged(before,"real append-destination failure")
	panel.conversation_editor.hide()

func run() -> void:
	root.size=Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
	wb=host.shared_workbench
	panel=wb._ensure_art_batches()
	if not await until(ready,"ordinary native Workbench ready"): quit(1); return
	var fresh: Dictionary=Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	check(wb.apply(fresh),"fresh512native World is admitted")
	if not await until(ready,"fresh native World installed"): quit(1); return
	wb.open_art_batches()
	await cancellation_checks()
	await stale_checks()
	await success_checks()
	await failed_append_check()
	check(event_count(0,"request")==0 and not panel.provider.active,
		"all conversation preparation cases send zero HTTP/model requests")
	check(panel.executor.batch_sequence==0,"no conversation preparation creates a native drawing batch")
	var metadata := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),
		"model_calls":0,"outcomes":outcomes,"evidence_kind":"ordinary Workbench and actual value workers; deterministic text fixtures"}
	host.queue_free()
	await process_frame
	await process_frame
	print("ART_CONVERSATION_APPLY_RESULT ",JSON.stringify(metadata))
	quit(0 if failures.is_empty() else 1)
