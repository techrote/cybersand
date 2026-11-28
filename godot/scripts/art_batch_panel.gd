extends Window
## Compact direct/model drawing over the shared native editor; no provider/Git preflight.
const Executor = preload("res://scripts/art_batch_executor.gd")
var executor := Executor.new()
var wb: Node
var input := TextEdit.new()
var state := Label.new()
var fields: Array[SpinBox] = []
var protected_fields: Array[SpinBox] = []
var protect := CheckBox.new()
var draw := Button.new()
var stop := Button.new()
var undo_button := Button.new()
var redo_button := Button.new()
var input_error := ""
var paint_material := OptionButton.new()
var request_material := 58
var erase := CheckBox.new()
const Provider = preload("res://scripts/art_provider.gd")
var provider := Provider.new()
# Last close/stop operation only; no unbounded UI event journal or credentials.
var last_close_timing: Dictionary = {}
var last_stop_timing: Dictionary = {}
var last_send_timing: Dictionary = {}
var last_finished_timing: Dictionary = {}
# Captured user turn for the current provider admission only. Large request
# preparation may finish after controls change or Art is hidden/reopened.
var _pending_provider_send: Dictionary = {}
var last_native_poll_usec := 0
var last_request_epoch_usec := 0
var last_send_epoch_usec := 0
# GDScript control/status projection only, excluding deferred engine layout/render.
# Zero when Art is hidden; native/provider lifetime work has separate receipts.
var last_visible_ui_usec := 0
var input_mode := OptionButton.new()
var source := OptionButton.new()
var model := LineEdit.new()
var history := OptionButton.new()
var endpoint := LineEdit.new()
var tokens := SpinBox.new()
var seconds := SpinBox.new()
var image_input := CheckBox.new()
var key_dialog := ConfirmationDialog.new()
var key_field := LineEdit.new()
var key_button := Button.new()
var key_dialog_provider := ""
var traffic_window := Window.new()
var traffic_text := TextEdit.new()
var traffic_dirty := false
var traffic_refresh_after := 0
var raw_traffic := CheckBox.new()
var traffic_path := Label.new()
var export_button := Button.new()
var export_cancel := Button.new()
var export_message := ""
var export_destination := ""
var settings := ConfigFile.new()
var _saved_settings_text := ""
var _settings_were_saved := false
var keys: Dictionary = {}
var rows: Array[Control] = []
var prompt_text := "Draw a cyberpunk robot statue using a few rectangles, discs and lines."
var json_text := '[{"shape":"rectangle","x0":32,"y0":32,"x1":95,"y1":159,"material":58},{"shape":"disc","x":64,"y":70,"radius":12,"material":0}]'
var current_provider := "LM Studio"
var request_epoch := 0
var request_local := false
const ArtPlan = preload("res://scripts/art_batch_plan.gd")
# Curated menu entries are convenience choices, not a request allowlist.
# Preserve exact user-specified local names and NVIDIA Build identifiers.
const LM_STUDIO_MODELS := {
	"KAT Coder V2.5 Dev REAP-50 · local": "kat-coder-v2.5-dev-reap-50@q6_k",
	"Daisyrose 27B · local": "daisyrose-27b",
	"LFM2.5 24B Turbo-Brilliance · local": "lfm2.5-24b-a2b-turbo-brilliance-50x-neo-max-imatrix",
}
const NVIDIA_MODELS := {
	"Kimi K3.1 Pro": "moonshotai/kimi-k3_1-pro",
	"Mistral Large 4": "mistralai/mistral-large-4-1t-a52b",
	"Nemotron 3.5 Super VL": "nvidia/nemotron-3.5-super-vl-120b-a12b",
}
const INVALID_LEGACY_MODEL := "astra5-6"
var ui_epoch := 0
var capturing := false
var request_area: Rect2i
var request_guards: Array = []
var request_materials: Array = []
const SHAPES := ArtPlan.SHAPES
var tool_checks: Dictionary = {}
var pixel_limit := SpinBox.new()
var request_shapes: Array = []
var request_pixel_limit := 0
var tools_button := Button.new()
var provider_message := "Idle"
var log_draw := false
var _manual_log_pending := false
var _manual_submission_sequence := 0
var _manual_active_submission := -1
var _manual_active_batch_sequence := -1
var conversation: Array = []
var conversation_revision := 0
var conversation_editor_revision := -1
var _pending_traffic_path := ""
var conversation_loaded := true
var history_load_error := ""
# Small, durable per-receipt files keep native Undo/Redo independent of the
# potentially multi-gigabyte immutable Art transcript. They are replayed only
# after explicit Art restoration, and never treated as an archive themselves.
const HISTORY_RECEIPT_DIR := "user://art-pending-history"
const MAX_HISTORY_RECEIPT_BYTES := 262144
const MAX_HISTORY_RECEIPTS := 4096
const MAX_HISTORY_JOURNAL_BYTES := 64 * 1024 * 1024
const MAX_VOLATILE_HISTORY_RECEIPTS := 64
const MAX_VOLATILE_HISTORY_BYTES := 4 * 1024 * 1024
const MAX_PROFILE_BYTES := 1024 * 1024
static var _history_receipt_clock_us := 0
var pending_history_receipts: Array[Dictionary] = []
var _history_draining := false
var _history_retry_after_ms := 0
var _history_retry_needed := false
var _history_persistence_error := ""
var _history_lost_receipt_error := ""
var _history_live_turns := {}
var _profile_session_error := ""
var _profile_creation_allowed := false
var context_mode := OptionButton.new()
var turn_limit := SpinBox.new()
var guidance := TextEdit.new()
var remaining_turns := 0
var sent_turns := 0
var traffic_filter := LineEdit.new()
var task_prompt := ""
var run_mode := 1
var last_image := ""
var full_image := CheckBox.new()
var last_result := ""
var request_scanline := false
var run_epoch := 0
var next_request_ms := 0
var provider_wait_ms := 0
var provider_wait_url := ""
var request_url := ""
var run_deadline_ms := 0
var run_seconds := SpinBox.new()
var spend_limit := SpinBox.new()
var input_price := SpinBox.new()
var output_price := SpinBox.new()
var run_spend := 0.0
var spend_status := ""
var run_spend_limit := 0.0
var sent_input_price := 0.0
var sent_output_price := 0.0

var waiting_until_ms := 0
var minimum_interval := SpinBox.new()
var stencil_guidance := TextEdit.new()
var stencil_prompt := ""
const STENCIL_INSTRUCTIONS := "Return a JSON array of rows. Each row is {y, repeat, scale, spans}. y is the local row index. repeat and scale default to 1. Each span is [x,length,material]. Scale multiplies x, y, length and repeat. Use the selected drawing material ID. Material 0 erases when enabled. Omitted spans preserve existing cells. Use local coordinates inside the stated area. Return [] when finished."


const ConversationEditor = preload("res://scripts/art_conversation_editor.gd")
var conversation_editor := ConversationEditor.new()
var conversation_button := Button.new()
var selection_editor: Control
var protected_row := HBoxContainer.new()
var conversation_error := ""
const CONVERSATION_PREPARATION_CHARACTERS := 262144
var _conversation_apply_preparing := false
var _conversation_apply_generation := 0
var _conversation_apply_handle := -1
var _conversation_apply_identity: Dictionary = {}
var _conversation_apply_snapshot: Array = []
var _conversation_apply_last_result := ""
var _conversation_apply_started_usec := 0
var last_conversation_apply_timing: Dictionary = {}
var model_controls: Array[Control] = []
const CollaborationWorkspace = preload("res://scripts/art_collaboration_workspace.gd")
const CollaborationSession = preload("res://scripts/art_collaboration_session.gd")
var collaboration: RefCounted
var collaboration_workspace: Control
var collaboration_button := Button.new()
var collaboration_page := false
var provider_credentials_revision := 0
var _collaboration_opened := false
var _direct_controls: Array[Control] = []

func _ready() -> void:
	title = "Art workbench"
	size = Vector2i(640,400)
	min_size = Vector2i(520,320)
	size_changed.connect(_sync_window_minimum.bind(self,Vector2i(520,320)))
	transient = true
	exclusive = false
	close_requested.connect(_close_art_window)
	visibility_changed.connect(_selection_visibility_changed)
	var dense := Theme.new()
	dense.default_font_size = 14
	for type_name: String in ["HBoxContainer","VBoxContainer"]:
		dense.set_constant("separation",type_name,2)
	theme = dense
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,4)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var actions := HBoxContainer.new()
	draw.text = "Draw"
	draw.pressed.connect(func() -> void:
		if input_mode.selected==0: submit_text()
		else: send_prompt())
	actions.add_child(draw)
	stop.text = "Stop"
	stop.pressed.connect(stop_all)
	actions.add_child(stop)
	input_mode.add_item("Direct JSON")
	input_mode.add_item("Model prompt")
	input_mode.add_item("Scanline")
	input_mode.select(1)
	input_mode.item_selected.connect(change_mode)
	actions.add_child(input_mode)
	mount_tools(actions)
	for entry: Array in [[undo_button,"Undo","undo"],[redo_button,"Redo","redo"]]:
		var button: Button = entry[0]
		button.text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_history_action.bind(str(entry[2])))
		actions.add_child(button)
	undo_button.tooltip_text = "Undo the latest paused Workbench edit, including agent drawing. Stop active agent runs first."
	redo_button.tooltip_text = "Redo the latest undone Workbench edit while the native source remains unchanged."
	collaboration_button.text = "Collaborate"
	collaboration_button.tooltip_text = "Discuss native context, develop a proposal and approve bounded stages. Uses this same Art provider, conversation and native history."
	collaboration_button.pressed.connect(func() -> void: show_collaboration(not collaboration_page))
	actions.add_child(collaboration_button)
	column.add_child(actions)
	mount_provider_controls(column)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.max_lines_visible = 2
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var row := HBoxContainer.new()
	var focus_label := Label.new()
	focus_label.text = "Focus"
	focus_label.tooltip_text = "Select a rectangle on the canvas to set X/Y/W/H while this panel is open. Applies to subsequent requests only."
	row.add_child(focus_label)
	add_rectangle(row,fields,[0,0,2048,2048])
	column.add_child(row)
	row = HBoxContainer.new()
	for i: int in ArtPlan.Setup.MATERIALS.size():
		var id: int = ArtPlan.Setup.MATERIALS[i]
		if id != 0: paint_material.add_item("%s (%d)" % [ArtPlan.Setup.MATERIAL_NAMES[i],id],id)
	paint_material.select(paint_material.get_item_index(58))
	paint_material.fit_to_longest_item = false
	paint_material.clip_text = true
	paint_material.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_material.tooltip_text = "Material available for art drawing. Erase is controlled separately."
	erase.text = "Erase"
	erase.button_pressed = true
	row.add_child(paint_material)
	row.add_child(erase)
	protect.text = "Protect"
	protect.tooltip_text = "Exclude this protected rectangle from agent drawing."
	protect.toggled.connect(func(on: bool) -> void: protected_row.visible = on)
	row.add_child(protect)
	column.add_child(row)
	add_rectangle(protected_row,protected_fields,[0,0,4,4])
	column.add_child(protected_row)
	protected_row.hide()
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.text = prompt_text
	input.custom_minimum_size.y = 64
	column.add_child(input)
	column.add_child(state)

	# Help lives in tooltips/Guidance rather than permanently consuming canvas space.
	input_mode.tooltip_text = "Direct JSON, model prompts or scanlines; use Guidance for drawing instructions."
	add_child(conversation_editor)
	conversation_editor.hide()
	conversation_editor.confirmed.connect(_apply_conversation_edits)
	conversation_editor.visibility_changed.connect(_conversation_editor_visibility_changed)
	conversation_editor.canceled.connect(func() -> void: _cancel_conversation_apply("Conversation Apply cancelled."))
	for node: Node in column.get_children():
		if node != actions and node is Control: _direct_controls.append(node)
	collaboration_workspace = CollaborationWorkspace.new()
	collaboration_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(collaboration_workspace)
	collaboration_workspace.hide()
	collaboration = CollaborationSession.new()
	collaboration.bind(self,collaboration_workspace)
	if collaboration_workspace.has_method("set_material_options"):
		var choices: Array = []
		for i: int in ArtPlan.Setup.MATERIALS.size():
			choices.append({"id":ArtPlan.Setup.MATERIALS[i],"name":ArtPlan.Setup.MATERIAL_NAMES[i]})
		collaboration_workspace.set_material_options(choices)

func show_collaboration(on: bool = true) -> void:
	if on: _size_collaboration_first_open()
	collaboration_page = on
	collaboration_button.text = "Direct" if on else "Collaborate"
	for control: Control in _direct_controls: control.visible = not on
	if not on:
		protected_row.visible = protect.button_pressed
		for row: Control in rows: row.visible = input_mode.selected != 0
		for control: Control in model_controls: control.visible = input_mode.selected != 0
	collaboration_workspace.visible = on
	draw.visible = not on
	input_mode.visible = not on
	tools_button.visible = not on and input_mode.selected != 2
	if collaboration != null and collaboration.overlay != null:
		collaboration.overlay.visible = on

func _size_collaboration_first_open() -> void:
	if _collaboration_opened: return
	_collaboration_opened = true
	# Direct keeps its compact default. The first explicit Collaborate action
	# needs enough space for an inspectable context/proposal and its footer.
	# Preserve an existing larger layout and all later owner resizing. An
	# ordinary popup may have clamped the compact default to its minimum.
	var compact := Vector2i((Vector2(640,400)*content_scale_factor).ceil())
	if size.x > compact.x or size.y > compact.y: return
	var bounds := Rect2i()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Viewport and ancestor.gui_embed_subwindows:
			bounds = Rect2i(Vector2i.ZERO,Vector2i(ancestor.get_visible_rect().size))
			break
		ancestor = ancestor.get_parent()
	if not bounds.has_area():
		bounds = DisplayServer.screen_get_usable_rect(current_screen)
	var preferred := Vector2i((Vector2(820,620)*content_scale_factor).ceil())
	if bounds.has_area():
		preferred = preferred.min(Vector2i((Vector2(bounds.size)*0.9).floor()))
	size = preferred.max(min_size)
	if bounds.has_area():
		position = bounds.position+(bounds.size-size)/2

func _bind_selection() -> void:
	if wb == null or wb.paint_editor == null or selection_editor == wb.paint_editor: return
	if is_instance_valid(selection_editor) and selection_editor.selection_changed.is_connected(focus_selection):
		selection_editor.selection_changed.disconnect(focus_selection)
	selection_editor = wb.paint_editor
	selection_editor.selection_changed.connect(focus_selection)

func _close_art_window() -> void:
	# Preserve the existing policy: closing hides the window but does not Stop.
	# This diagnostic measures just the synchronous UI close path, not the first
	# responsive subsequent frame; the isolated regression measures that gap.
	var began_usec := Time.get_ticks_usec()
	var pending_request: bool = provider.active
	hide()
	last_close_timing = {"close_usec":Time.get_ticks_usec() - began_usec,
		"hidden":not visible, "provider_active_before":pending_request,
		"provider_active_after":provider.active}


func _selection_visibility_changed() -> void:
	# A new Workbench session never reopens an earlier model conversation.
	# Hiding/revealing Art changes only the selection binding.
	_bind_selection()

func _ensure_history_loaded() -> bool:
	# In-memory turns belong exclusively to this Workbench session.
	return true

func focus_selection(region: Rect2i) -> void:
	if not visible or fields.size() != 4 or wb == null or wb.applied.is_empty(): return
	var bounds := Rect2i(Vector2i.ZERO,ArtPlan.Setup.extent_of(wb.applied))
	region = region.abs().intersection(bounds)
	if not region.has_area(): return
	var values := [region.position.x,region.position.y,region.size.x,region.size.y]
	for i: int in range(4): fields[i].set_value_no_signal(values[i])
	# Do not change request_area, request_guards or the executor's captured scope.

func _open_conversation() -> void:
	_cancel_conversation_apply("Conversation reopened; the earlier prepared draft was discarded.")
	conversation_error = ""
	conversation_editor_revision = conversation_revision
	conversation_editor.open_history(conversation)
	_update_conversation_guard()

func _conversation_block_reason(check_contents: bool = false) -> String:
	if not conversation_loaded: return "Open the saved conversation successfully before editing it."
	var blocked := history_block_reason()
	if not blocked.is_empty(): return "Stop the agent and wait for its confirmed result before applying history edits."
	if wb != null and (wb.busy() or (wb.paint_editor != null and wb.paint_editor.busy())):
		return "Wait for the current Workbench operation before applying history edits."
	# Ordinary UI polling must not compare every byte of a long conversation
	# each frame. All live turn admissions increment the revision; Apply also
	# checks the full snapshot to reject an unexpected out-of-band mutation.
	if conversation_revision != conversation_editor_revision \
			or conversation.size() != conversation_editor.baseline.size() \
			or (check_contents and conversation != conversation_editor.baseline):
		return "Conversation changed while this editor was open. Reopen it to edit the latest history."
	return ""

func _update_conversation_guard() -> void:
	if _conversation_apply_preparing:
		if not _conversation_apply_guard(_conversation_apply_identity):
			_cancel_conversation_apply("Conversation, World or authoring state changed. Review the draft and Apply again.")
		else:
			conversation_editor.get_ok_button().disabled = true
			conversation_editor.notice.text = "Preparing complete conversation changes… Cancel discards this preparation; no edited snapshot has been committed."
			return
	if is_queued_for_deletion() or not is_instance_valid(conversation_editor) \
			or conversation_editor.is_queued_for_deletion(): return
	if wb != null and not is_instance_valid(wb): return
	if conversation_editor.visible:
		var blocked := _conversation_block_reason()
		conversation_editor.get_ok_button().disabled = not blocked.is_empty()
		conversation_editor.notice.text = blocked if not blocked.is_empty() else (conversation_error if not conversation_error.is_empty() else ConversationEditor.HELP)

func _apply_conversation_edits() -> void:
	if _conversation_apply_preparing: return
	var apply_began_usec := Time.get_ticks_usec()
	conversation_editor.flush_message()
	conversation_error = ""
	var blocked := _conversation_block_reason(true)
	if not blocked.is_empty():
		conversation_editor.notice.text = blocked
		return
	var clean: Variant = Provider.checked_conversation(conversation_editor.draft)
	if clean == null:
		conversation_error = "Invalid conversation. Only user/assistant text and retained image references are supported."
		_update_conversation_guard()
		return
	var characters := 0
	for entry: Dictionary in clean: characters += str(entry.content).length()
	if characters >= CONVERSATION_PREPARATION_CHARACTERS:
		_begin_conversation_apply(clean,apply_began_usec)
		return
	for entry: Dictionary in clean: entry.content = provider.redact(entry.content)
	if clean == conversation:
		conversation_editor.hide()
		return
	# One append-only snapshot: never truncate original requests, replies or native receipts.
	if not provider.log_event("conversation_edited",{"turns":clean,"last_result":last_result}):
		conversation_error = "Could not save conversation edits; live history is unchanged. "+provider.log_warning
		_update_conversation_guard()
		return
	if not persist_traffic_path():
		conversation_error = "Could not save the conversation checkpoint; live history is unchanged."
		_update_conversation_guard()
		return
	conversation = clean
	conversation_revision += 1
	last_image = "" # The next request must not rely on an image removed from context.
	conversation_editor.hide()
	input_error = "Conversation updated for future requests; no canvas edits were executed."

func conversation_apply_pending() -> bool:
	return _conversation_apply_preparing

func _conversation_editor_visibility_changed() -> void:
	if not is_instance_valid(conversation_editor) or not conversation_editor.visible:
		_cancel_conversation_apply("Conversation closed; prepared changes were discarded.")

func _conversation_world_epoch() -> int:
	if wb == null or wb.host == null or wb.host.simulation_worker == null: return -1
	return int(wb.host.simulation_worker.art_state().epoch)

func _conversation_apply_guard(identity: Dictionary, full: bool = false) -> bool:
	# queue_free is an owner-lifetime boundary even before the deferred deletion
	# flush. A ready worker must not append or adopt for a retiring UI hierarchy.
	if is_queued_for_deletion() or not is_inside_tree() \
			or not is_instance_valid(conversation_editor) or conversation_editor.is_queued_for_deletion() \
			or not conversation_editor.is_inside_tree() \
			or not is_instance_valid(provider) or provider.is_queued_for_deletion():
		return false
	if wb != null:
		if not is_instance_valid(wb) or wb.is_queued_for_deletion() or not wb.is_inside_tree(): return false
		if wb.host != null and (not is_instance_valid(wb.host) or wb.host.is_queued_for_deletion() \
				or not wb.host.is_inside_tree()): return false
	if not _conversation_apply_preparing or identity != _conversation_apply_identity \
			or int(identity.get("generation",-1)) != _conversation_apply_generation \
			or not conversation_editor.visible:
		return false
	if int(identity.get("revision",-1)) != conversation_revision \
			or int(identity.get("editor_revision",-1)) != conversation_editor_revision \
			or int(identity.get("world_epoch",-1)) != _conversation_world_epoch() \
			or int(identity.get("provider_serial",-1)) != provider.serial:
		return false
	if last_result != _conversation_apply_last_result: return false
	if not _conversation_block_reason(full).is_empty(): return false
	if full and conversation_editor.draft != _conversation_apply_snapshot: return false
	return true

func _begin_conversation_apply(clean: Array, began_usec: int) -> void:
	_conversation_apply_generation += 1
	_conversation_apply_started_usec = began_usec
	_conversation_apply_preparing = true
	_conversation_apply_snapshot = conversation_editor.draft.duplicate(true)
	_conversation_apply_last_result = last_result
	_conversation_apply_identity = {"generation":_conversation_apply_generation,
		"revision":conversation_revision,"editor_revision":conversation_editor_revision,
		"world_epoch":_conversation_world_epoch(),"provider_serial":provider.serial}
	conversation_editor.set_apply_pending(true,"Preparing complete conversation changes… Cancel remains available.")
	var identity := _conversation_apply_identity.duplicate(true)
	last_conversation_apply_timing = {"asynchronous":true,"status":"preparing",
		"admission_usec":0,"handle":-1}
	var result: Dictionary = provider.begin_conversation_edit(clean,last_result,identity,
		_conversation_apply_ready,_conversation_apply_guard.bind(identity))
	if not result.get("ok",false):
		_conversation_apply_failed(str(result.get("error","Conversation preparation was refused.")))
		return
	if not _conversation_apply_preparing or identity != _conversation_apply_identity:
		provider.cancel_conversation_edit(int(result.handle),identity,"Conversation preparation was superseded during admission.")
		return
	_conversation_apply_handle = int(result.handle)
	last_conversation_apply_timing.admission_usec = Time.get_ticks_usec()-began_usec
	last_conversation_apply_timing.handle = _conversation_apply_handle
	_update_conversation_guard()

func _conversation_apply_ready(handle: int, identity: Dictionary, error: String) -> void:
	if not _conversation_apply_preparing or handle != _conversation_apply_handle \
			or identity != _conversation_apply_identity: return
	if not error.is_empty():
		_conversation_apply_failed(error)
		return
	if not _conversation_apply_guard(identity,true):
		_cancel_conversation_apply("Conversation or World changed before Apply could commit. Reopen and review the latest conversation.")
		return
	var clean: Variant = provider.prepared_conversation_edit_turns(handle,identity)
	if clean == null:
		_conversation_apply_failed("Prepared conversation is no longer valid. Review and Apply again.")
		return
	if clean == conversation:
		provider.cancel_conversation_edit(handle,identity,"No conversation changes")
		last_conversation_apply_timing.status = "unchanged"
		last_conversation_apply_timing.total_usec = Time.get_ticks_usec()-_conversation_apply_started_usec
		_clear_conversation_apply()
		conversation_editor.hide()
		return
	var commit_began := Time.get_ticks_usec()
	var timing := last_conversation_apply_timing
	timing.prepared_after_usec = commit_began-_conversation_apply_started_usec
	var result: Dictionary = provider.commit_conversation_edit(handle,identity,
		_adopt_conversation_apply.bind(identity),_conversation_apply_guard.bind(identity,true))
	# The provider calls adoption after durable append and before any audit
	# observers. Those observers may already start later owner work here.
	if result.get("committed",false) and result.get("adopted",false):
		timing.commit_usec = Time.get_ticks_usec()-commit_began
		return
	if _conversation_apply_preparing and identity == _conversation_apply_identity:
		_conversation_apply_failed(str(result.get("error","Conversation changes could not be committed.")))

func _adopt_conversation_apply(clean: Array, identity: Dictionary) -> bool:
	# Provider has just durably appended the exact prepared value under its
	# private capability and final guard. No observer runs before this adoption.
	if not _conversation_apply_preparing or identity != _conversation_apply_identity: return false
	conversation = clean
	conversation_revision += 1
	last_image = ""
	last_conversation_apply_timing.status = "committed"
	last_conversation_apply_timing.total_usec = Time.get_ticks_usec()-_conversation_apply_started_usec
	_clear_conversation_apply()
	conversation_editor.hide()
	input_error = "Conversation updated for future requests; no canvas edits were executed."
	return true

func _clear_conversation_apply() -> void:
	_conversation_apply_preparing = false
	_conversation_apply_handle = -1
	_conversation_apply_identity = {}
	_conversation_apply_snapshot = []
	_conversation_apply_last_result = ""
	if is_instance_valid(conversation_editor) and not conversation_editor.is_queued_for_deletion():
		conversation_editor.set_apply_pending(false)

func _conversation_apply_failed(message: String) -> void:
	if not _conversation_apply_preparing: return
	var handle := _conversation_apply_handle
	var identity := _conversation_apply_identity.duplicate(true)
	last_conversation_apply_timing.status = "refused"
	last_conversation_apply_timing.total_usec = Time.get_ticks_usec()-_conversation_apply_started_usec
	_conversation_apply_generation += 1
	_clear_conversation_apply()
	if handle >= 0 and is_instance_valid(provider) and not provider.is_queued_for_deletion():
		provider.cancel_conversation_edit(handle,identity,message)
	conversation_error = message
	input_error = message
	_update_conversation_guard()

func _cancel_conversation_apply(reason: String) -> void:
	if not _conversation_apply_preparing: return
	var handle := _conversation_apply_handle
	var identity := _conversation_apply_identity.duplicate(true)
	last_conversation_apply_timing.status = "cancelled"
	last_conversation_apply_timing.total_usec = Time.get_ticks_usec()-_conversation_apply_started_usec
	_conversation_apply_generation += 1
	_clear_conversation_apply()
	if handle >= 0 and is_instance_valid(provider) and not provider.is_queued_for_deletion():
		provider.cancel_conversation_edit(handle,identity,reason)
	conversation_error = reason
	input_error = reason

func mount_tools(actions: HBoxContainer) -> void:
	var options := Window.new()
	options.title = "Drawing tools"
	options.close_requested.connect(options.hide)
	options.size_changed.connect(_sync_window_minimum.bind(options,Vector2i(480,145)))
	add_child(options)
	options.hide()
	var fields_box := VBoxContainer.new()
	fields_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options.add_child(fields_box)
	var toggles := GridContainer.new()
	toggles.columns = 4
	fields_box.add_child(toggles)
	for shape: String in SHAPES:
		var toggle := CheckBox.new()
		toggle.text = shape.capitalize()
		toggle.button_pressed = true
		tool_checks[shape] = toggle
		toggles.add_child(toggle)
	pixel_limit.prefix = "Pixels per operation"
	pixel_limit.max_value = 2147483647
	pixel_limit.tooltip_text = "Zero leaves the point count unrestricted by this setting."
	fields_box.add_child(pixel_limit)
	var hint := Label.new()
	hint.text = "Line and polyline widths are in cells. Pixel limit 0 adds no cap."
	fields_box.add_child(hint)
	tools_button.text = "Tools…"
	tools_button.pressed.connect(_show_scaled_window.bind(options,Vector2i(480,145)))
	actions.add_child(tools_button)

func enabled_shapes() -> Array:
	var enabled: Array = []
	for shape: String in SHAPES:
		if tool_checks[shape].button_pressed: enabled.append(shape)
	return enabled

func tool_error(operations: Variant, enabled: Array, max_pixels: int) -> String:
	if not operations is Array: return ""
	for op: Variant in operations:
		if not op is Dictionary: continue
		var shape: String = str(op.get("shape",""))
		if shape in SHAPES and shape not in enabled: return shape.capitalize()+" is disabled in Tools."
		if shape == "pixels" and max_pixels > 0 and op.get("points") is Array and op.points.size() > max_pixels:
			return "Pixels operation exceeds the Tools limit of %d points." % max_pixels
	return ""

func add_rectangle(parent: Control, target: Array[SpinBox], values: Array) -> void:
	for i: int in range(4):
		var field := SpinBox.new()
		field.prefix = ["X","Y","W","H"][i]
		field.min_value = 0 if i<2 else 1
		field.max_value = 2147483647
		field.value = values[i]
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.custom_minimum_size.x = 85
		parent.add_child(field)
		target.append(field)

func rectangle(values: Array[SpinBox]) -> Rect2i:
	return Rect2i(int(values[0].value),int(values[1].value),int(values[2].value),int(values[3].value))

func _register_provider_keys_for_redaction() -> void:
	# Keep earlier and currently selected credentials in memory for the entire
	# session. Never write raw Key-dialog values to the audit.
	for value: Variant in keys.values():
		if value is String and not value.is_empty() and not provider.secrets.has(value):
			provider.secrets.append(value)

func _finish_manual_audit(on_shutdown: bool = false) -> void:
	if not _manual_log_pending: return
	if executor.active and not on_shutdown: return
	# No native completion is invented when the scene is closing. The last
	# acknowledged prefix is evidence; a queued suffix may remain unresolved.
	var native_terminal := not executor.active
	var record := {
		"submission_id":_manual_active_submission,
		"batch_sequence":_manual_active_batch_sequence,
		"audit_state":"terminal" if native_terminal else "shutdown_cancel_requested_unconfirmed",
		"native_terminal":native_terminal,
		"result":executor.result.duplicate(true)}
	if not native_terminal:
		record["reason"] = "Workbench closed after Stop request; native suffix outcome is not confirmed."
	_register_provider_keys_for_redaction()
	if not provider.log_event("manual_result",record):
		input_error = "Manual drawing audit could not be saved. "+provider.log_warning
		# A live panel can retry when storage becomes available.
		if not on_shutdown: return
	_manual_log_pending = false
	_manual_active_submission = -1
	_manual_active_batch_sequence = -1

func submit_text() -> void:
	if conversation_apply_pending():
		input_error = "Wait for conversation Apply, or Cancel it, before direct drawing."
		return
	if collaboration != null and collaboration.busy():
		input_error = "Finish or Stop collaborative work before direct drawing."
		return
	var epoch := ui_epoch
	executor.wb = wb
	_register_provider_keys_for_redaction()
	executor.poll()
	_finish_manual_audit()
	if epoch != ui_epoch: return
	input_error = ""
	var parsed := JSON.new()
	if parsed.parse(input.text) != OK:
		input_error = "Invalid JSON at line%d: %s" % [parsed.get_error_line(),parsed.get_error_message()]
		return
	input_error = tool_error(parsed.data,enabled_shapes(),int(pixel_limit.value))
	if not input_error.is_empty(): return
	var selected := paint_material.get_selected_id()
	var allowed: Array = [selected]
	if parsed.data is Array:
		for op: Variant in parsed.data:
			if op is Dictionary and not op.has("material"): op.material = selected
	if erase.button_pressed: allowed.append(0)
	var bounds := rectangle(fields)
	var guards := [rectangle(protected_fields)] if protect.button_pressed else []
	_manual_submission_sequence += 1
	var submission_id := _manual_submission_sequence
	provider.log_event("manual_program",{
		"submission_id":submission_id,
		"mode":"Direct JSON","program":parsed.data,"focus_xywh":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
		"protected":[[guards[0].position.x,guards[0].position.y,guards[0].size.x,guards[0].size.y]] if not guards.is_empty() else [],
		"materials":allowed,"shapes":enabled_shapes(),"pixel_limit":int(pixel_limit.value)})
	# Audit observers can Stop direct drawing too. Preserve the intent record,
	# but never admit a new native batch after that generation was cancelled.
	if epoch != ui_epoch: return
	# A rejected overlapping Draw cannot retire the existing native batch's
	# pending terminal audit. Do not enter submit() while it remains active.
	var answer: Dictionary
	if _manual_log_pending:
		answer = {"status":"refused","reason":"Finish or Stop the current manual batch first."}
	else:
		answer = executor.submit(parsed.data,bounds,guards,allowed)
	var batch_id := int(executor.batch_sequence) if answer.status == "queued" else -1
	provider.log_event("manual_admission",{"submission_id":submission_id,
		"batch_sequence":batch_id,"result":answer})
	if answer.status == "queued":
		_manual_active_submission = submission_id
		_manual_active_batch_sequence = batch_id
		_manual_log_pending = true
	if answer.status == "refused": input_error = str(answer.reason)

func _process(_delta: float) -> void:
	last_visible_ui_usec = 0
	_poll_traffic_export()
	if wb == null: return
	_bind_selection()
	executor.wb = wb
	var native_poll_begin_usec := Time.get_ticks_usec()
	executor.poll()
	last_native_poll_usec = Time.get_ticks_usec() - native_poll_begin_usec
	if collaboration != null: collaboration.poll()
	_finish_manual_audit()
	_update_conversation_guard()
	if traffic_dirty and traffic_window.visible and Time.get_ticks_msec() >= traffic_refresh_after: refresh_traffic()
	if run_deadline_ms > 0 and Time.get_ticks_msec() >= run_deadline_ms:
		if provider.active or capturing or executor.active or remaining_turns != 0: stop_all("Run time limit reached")
		run_deadline_ms = 0
	# Hidden requests retain the same World lifetime guard as visible requests.
	# Hide is allowed to continue; a replacement World invalidates the old work.
	if provider.active:
		var epoch_begin_usec := Time.get_ticks_usec()
		var current_epoch: int = wb.host.simulation_worker.art_state().epoch
		last_request_epoch_usec = Time.get_ticks_usec() - epoch_begin_usec
		if current_epoch != request_epoch: stop_all("Canvas changed")
	# Native receipts and model-turn chaining must continue even while Art is
	# hidden. Handle them before skipping the window-only controls below.
	if log_draw and not executor.active:
		provider.log_event("native_result",executor.result)
		log_draw = false
		model_feedback(JSON.stringify(executor.result))
	if remaining_turns == 0 and not provider.active and not capturing and not log_draw:
		run_deadline_ms = 0
	# Closing Art is Hide, not Stop. Keep HTTP/authoritative native work live,
	# but avoid repeatedly rebuilding model controls, tooltips and status text
	# while the model-mode window is invisible.
	if not visible and input_mode.selected != 0:
		return
	var visible_ui_begin_usec := Time.get_ticks_usec()
	draw.disabled = executor.active
	var history_replaying: bool = wb.paint_editor != null and wb.paint_editor.history_replaying()
	stop.disabled = not executor.active and not provider.active and not capturing \
		and remaining_turns == 0 and not history_replaying and not provider.export_active and not provider.resume_active \
		and (collaboration == null or not collaboration.busy()) and not conversation_apply_pending()
	draw.disabled = executor.active or provider.active or capturing or remaining_turns != 0 \
		or provider.export_active or provider.resume_active or conversation_apply_pending() or (wb.paint_editor != null and wb.paint_editor.busy())
	export_button.disabled = not history_block_reason().is_empty()
	export_cancel.disabled = not provider.export_active
	conversation_button.disabled = provider.resume_active
	var history_blocked := not history_block_reason().is_empty() or wb.paint_editor == null
	undo_button.disabled = history_blocked or not wb.paint_editor.history_available("undo")
	redo_button.disabled = history_blocked or not wb.paint_editor.history_available("redo")
	var history_notice: String = str(wb.paint_editor.history_notice) if wb.paint_editor != null else ""
	undo_button.tooltip_text = "Undo the latest paused Workbench edit, including agent drawing. Stop active agent runs first. " + history_notice
	tools_button.visible = input_mode.selected != 2
	draw.text = "Draw" if input_mode.selected==0 else "Send"
	for row: Control in rows: row.visible = input_mode.selected!=0
	for control: Control in model_controls: control.visible = input_mode.selected!=0
	if collaboration_page:
		for control: Control in _direct_controls: control.hide()
		tools_button.hide()
	key_button.text = "Key ✓" if not str(keys.get(current_provider,"")).is_empty() else "Key…"
	input_mode.tooltip_text = "Turns limits requests per Send. Image attaches a canvas crop. Select a vision model to use it." if input_mode.selected!=0 else "Ordered JSON: see enabled shapes under Tools. Use the selected material ID. 0 erases when enabled. Large drawings stream in native-sized chunks."
	var status_text := "Idle"
	if provider.active:
		match str(provider.last_request_timing.get("status","")):
			"preparing_request": status_text = "Preparing request · Stop available"
			"preparing_response": status_text = "Preparing response · Stop available"
			_: status_text = "Waiting for model · Stop available"
	elif waiting_until_ms > Time.get_ticks_msec():
		status_text = "Waiting to send · %.1fs · Stop available" % ((waiting_until_ms-Time.get_ticks_msec())/1000.0)
	elif capturing: status_text = "Capturing current view · Stop available"
	elif wb.paint_editor != null and wb.paint_editor.busy(): status_text = wb.message
	elif not input_error.is_empty():
		status_text = input_error.left(500)+(" … See Traffic for full details." if input_error.length()>500 else "")
	elif executor.active or executor.result.status != "idle":
		var r: Dictionary = executor.result
		status_text = "%s · %d checked · %d changed · %d unchanged · %d protected/outside skipped · %d refused%s" % [str(r.status).capitalize(),r.checked,r.changed,int(r.get("unchanged",0)),r.excluded,int(r.get("refused",0))," · "+str(r.reason) if not str(r.reason).is_empty() else ""]
		if r.status == "completed" and r.checked > 0 and r.checked == r.excluded:
			status_text = "No pixels applied · all %d outside the current work area or protected" % r.checked
		if int(r.get("human_pending",0)) > 0: status_text += " · %d human strokes waiting" % int(r.human_pending)
		if int(r.get("human_applied",0)) > 0: status_text += " · %d human strokes confirmed" % int(r.human_applied)
		if int(r.get("human_partial",0)) > 0: status_text += " · %d human strokes partial; see PAINT recovery" % int(r.human_partial)
		if int(r.get("human_refused",0)) > 0: status_text += " · %d human strokes refused; retry them" % int(r.human_refused)

	if input_mode.selected != 0 and not provider.requested_model.is_empty():
		var u: Dictionary = provider.usage
		status_text += " · In %s Out %s · Cost ?" % [str(u.get("input_tokens",u.get("prompt_tokens","?"))),str(u.get("output_tokens",u.get("completion_tokens","?")))]
	if run_spend_limit > 0: status_text += " · Est. $%.4f / $%.4f" % [run_spend,run_spend_limit]
	if input_mode.selected != 0 and not spend_status.is_empty(): status_text += " · "+spend_status
	if not provider.log_warning.is_empty(): status_text += " · "+provider.log_warning
	if not history_notice.is_empty(): status_text += " · "+history_notice
	if state.text != status_text:
		state.text = status_text
		state.tooltip_text = status_text
	if visible: last_visible_ui_usec = Time.get_ticks_usec() - visible_ui_begin_usec

func _exit_tree() -> void:
	if wb != null:
		stop_all("Workbench closed")
		# No additional _process tick is guaranteed during orderly shutdown.
		# Record an explicitly unconfirmed cancellation if native work remains.
		_finish_manual_audit(true)

func mount_provider_controls(column: VBoxContainer) -> void:
	# Provider preferences persist, but conversation turns and archive pointers do
	# not. Never inspect old traffic or attach an old session during construction.
	var profile_error := settings.load("user://art-provider.cfg")
	if profile_error == OK:
		_saved_settings_text = settings.encode_to_text()
		_settings_were_saved = true
	if profile_error != OK and FileAccess.file_exists("user://art-provider.cfg"):
		_profile_session_error = "Saved Art preferences are unreadable. Existing settings are preserved; session logging and Send remain available."
	if settings.has_section_key("session","traffic_path"):
		settings.erase_section_key("session","traffic_path")
	# An unbound provider creates exactly one new root log lazily on first event.
	# No commit_segment callback means it never publishes a cross-session pointer.
	add_child(provider)
	provider.finished.connect(provider_finished)
	provider.request_started.connect(_provider_request_started)
	executor.native_receipt.connect(func(receipt: Dictionary) -> void:
		if log_draw: provider.log_event("native_receipt",receipt))
	executor.manual_receipt.connect(func(receipt: Dictionary) -> void:
		provider.log_event("deferred_human_stroke",receipt))
	provider.traffic_changed.connect(func() -> void:
		traffic_dirty = true
		if provider.last_event_stored: persist_traffic_path())
	var row := HBoxContainer.new()
	for name_text: String in ["LM Studio","OpenAI","NVIDIA"]: source.add_item(name_text)
	source.item_selected.connect(change_provider)
	row.add_child(source)
	model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model.placeholder_text = "Model ID (custom names allowed)"
	row.add_child(model)
	history.tooltip_text = "Provider presets followed by saved/custom model IDs. Presets do not confirm API access, local model loading or image support; check your configured endpoint. Model ID and URL remain editable."
	history.fit_to_longest_item = false
	history.clip_text = true
	history.custom_minimum_size.x = 34
	history.item_selected.connect(func(i: int) -> void:
		if i>0: model.text = str(history.get_item_metadata(i)) if history.get_item_metadata(i) != null else history.get_item_text(i)
		history.select(0))
	row.add_child(history)
	key_button.text = "Key…"
	key_button.pressed.connect(_open_key_dialog)
	row.add_child(key_button)
	var traffic_button := Button.new()
	traffic_button.text = "Traffic…"
	traffic_button.pressed.connect(func() -> void: _show_scaled_window(traffic_window,Vector2i(900,600)); refresh_traffic())
	row.add_child(traffic_button)
	column.add_child(row); rows.append(row)
	row = HBoxContainer.new()
	endpoint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endpoint.placeholder_text = "API base URL, including /v1"
	row.add_child(endpoint)
	tokens.prefix = "Toks"
	tokens.min_value = 1; tokens.max_value = 262144; tokens.value = 8192
	tokens.custom_minimum_size.x = 100
	row.add_child(tokens)
	seconds.prefix = "Secs"
	seconds.min_value = 1; seconds.max_value = 3600; seconds.value = 180
	seconds.custom_minimum_size.x = 85
	row.add_child(seconds)
	image_input.text = "Image"
	image_input.tooltip_text = "Send the rendered current canvas view; use a vision-capable model."
	row.add_child(image_input)
	full_image.text = "Full view"
	full_image.tooltip_text = "Send the whole visible canvas instead of its intersection with the work area."
	row.add_child(full_image)
	column.add_child(row); rows.append(row)
	row = HBoxContainer.new()
	for label: String in ["Full","Compacted","Custom","None"]: context_mode.add_item(label)
	context_mode.select(clampi(int(settings.get_value("session","context",1)),0,3))
	context_mode.tooltip_text = "Conversation context for the next request. Custom currently uses Compacted."
	row.add_child(context_mode)
	turn_limit.prefix = "Turns"
	turn_limit.min_value = 0
	turn_limit.value = 1
	turn_limit.tooltip_text = "Maximum requests per Send. Zero requires a positive Run s limit; Stop remains available."
	turn_limit.max_value = 1000
	row.add_child(turn_limit)
	minimum_interval.prefix = "Gap s"
	minimum_interval.custom_minimum_size.x = 100
	minimum_interval.max_value = 3600
	minimum_interval.step = 0.1
	minimum_interval.tooltip_text = "Minimum seconds between model requests. Zero disables local pacing."
	run_seconds.prefix = "Run s"
	run_seconds.custom_minimum_size.x = 100
	run_seconds.max_value = 86400
	run_seconds.tooltip_text = "Maximum seconds for this run. Zero requires a positive Turns limit."
	var spending := Window.new()
	spending.title = "Run limits and estimated spending"
	add_child(spending)
	spending.hide()
	spending.close_requested.connect(spending.hide)
	spending.size_changed.connect(_sync_window_minimum.bind(spending,Vector2i(400,280)))
	var spending_fields := VBoxContainer.new()
	spending.add_child(spending_fields)
	spending_fields.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spending_fields.add_child(minimum_interval)
	spending_fields.add_child(run_seconds)
	var spending_help := Label.new()
	spending_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spending_help.text = "Enter your own rates. A zero ceiling disables spending control. The estimate uses reported tokens after each response and can exceed the ceiling by one request."
	spending_fields.add_child(spending_help)
	for field: SpinBox in [spend_limit,input_price,output_price]:
		field.min_value = 0
		field.max_value = 1000000
		field.step = 0.001
		spending_fields.add_child(field)
	spend_limit.prefix = "Run USD"
	input_price.prefix = "Input USD / 1M"
	output_price.prefix = "Output USD / 1M"
	var spending_button := Button.new()
	spending_button.text = "Limits…"
	spending_button.tooltip_text = "Request pacing, run duration and estimated spending. Zero disables each limit."
	spending_button.pressed.connect(_show_scaled_window.bind(spending,Vector2i(400,280)))
	row.add_child(spending_button)
	conversation_button.text = "Conversation…"
	conversation_button.tooltip_text = "View, edit or remove conversation messages used as future model context. Raw traffic and native receipts are retained."
	conversation_button.pressed.connect(_open_conversation)
	row.add_child(conversation_button)
	var guidance_window := Window.new()
	guidance_window.title = "Drawing guidance"
	add_child(guidance_window)
	guidance_window.hide()
	guidance_window.close_requested.connect(guidance_window.hide)
	guidance_window.add_child(guidance)
	guidance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guidance.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_window.min_size = Vector2i(360,220)
	guidance_window.size_changed.connect(_sync_window_minimum.bind(guidance_window,Vector2i(360,220)))
	guidance.text = settings.get_value("session","guidance",Provider.INSTRUCTIONS)
	var stencil_window := Window.new()
	stencil_window.title = "Scanline guidance"
	add_child(stencil_window)
	stencil_window.hide()
	stencil_window.close_requested.connect(stencil_window.hide)
	stencil_window.add_child(stencil_guidance)
	stencil_guidance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stencil_guidance.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	stencil_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stencil_window.min_size = Vector2i(360,220)
	stencil_window.size_changed.connect(_sync_window_minimum.bind(stencil_window,Vector2i(360,220)))
	stencil_guidance.text = settings.get_value("session","scanline_guidance",STENCIL_INSTRUCTIONS)
	var edit_guidance := Button.new()
	edit_guidance.text = "Guidance…"
	edit_guidance.pressed.connect(func() -> void:
		var window := stencil_window if input_mode.selected == 2 else guidance_window
		_show_scaled_window(window,Vector2i(700,400)))
	row.add_child(edit_guidance)
	model_controls.assign([context_mode,turn_limit,spending_button,edit_guidance])
	column.add_child(row)
	key_field.secret = true
	key_field.placeholder_text = "Paste API key; never saved in profiles or traffic"
	key_field.custom_minimum_size.x = 360
	key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_dialog.add_child(key_field)
	key_dialog.confirmed.connect(_apply_provider_key)
	key_dialog.canceled.connect(key_field.clear)
	key_dialog.close_requested.connect(key_field.clear)
	key_dialog.size_changed.connect(_sync_window_minimum.bind(key_dialog,Vector2i(380,90)))
	key_dialog.visibility_changed.connect(func() -> void:
		if not key_dialog.visible: _clear_hidden_key.call_deferred())
	add_child(key_dialog)
	traffic_window.title = "Art traffic · complete redacted requests / responses / native results"
	traffic_window.min_size = Vector2i(600,350)
	traffic_window.size_changed.connect(_sync_window_minimum.bind(traffic_window,Vector2i(600,350)))
	traffic_window.close_requested.connect(traffic_window.hide)
	add_child(traffic_window)
	traffic_window.hide()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	traffic_window.add_child(box)
	var actions := HBoxContainer.new()
	var copy := Button.new(); copy.text = "Copy visible"
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(traffic_text.text))
	actions.add_child(copy)
	raw_traffic.text = "Raw JSONL"
	raw_traffic.toggled.connect(func(_on: bool) -> void: refresh_traffic())
	actions.add_child(raw_traffic)
	traffic_filter.placeholder_text = "Filter traffic"
	traffic_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traffic_filter.text_changed.connect(func(_value: String) -> void: refresh_traffic())
	actions.add_child(traffic_filter)
	export_button.text = "Save full JSONL…"
	var save := FileDialog.new()
	save.file_mode = FileDialog.FILE_MODE_SAVE_FILE; save.access = FileDialog.ACCESS_FILESYSTEM
	save.current_file = "cybersand-art-traffic.jsonl"
	traffic_window.add_child(save)
	save.file_selected.connect(_begin_traffic_export)
	export_button.pressed.connect(func() -> void: save.popup_centered_ratio(0.7))
	actions.add_child(export_button)
	export_cancel.text = "Cancel export"
	export_cancel.disabled = true
	export_cancel.pressed.connect(_cancel_traffic_export)
	actions.add_child(export_cancel)
	box.add_child(actions)
	traffic_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	traffic_path.max_lines_visible = 3
	traffic_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(traffic_path)
	traffic_text.editable = false
	traffic_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	traffic_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(traffic_text)
	load_profile()

func _sync_window_minimum(window: Window, logical_minimum: Vector2i) -> void:
	# Window sizes are pixels; controls lay out in content-scaled coordinates.
	# Raising UI scale must raise the matching minimum, rather than clip rows.
	var scaled := Vector2i((Vector2(logical_minimum)*window.content_scale_factor).ceil())
	if window.min_size != scaled: window.min_size = scaled

func _show_scaled_window(window: Window, logical_size: Vector2i) -> void:
	# Traffic and guidance are independently useful windows, often larger than
	# compact Art. Preserve their preferred size when the actual host can fit
	# it; clamp to the embedding viewport or native screen, not Art's own box.
	var available := Vector2i.ZERO
	var ancestor := window.get_parent()
	while ancestor != null:
		if ancestor is Viewport and ancestor.gui_embed_subwindows:
			available = Vector2i(ancestor.get_visible_rect().size)
			break
		ancestor = ancestor.get_parent()
	if available == Vector2i.ZERO:
		available = DisplayServer.screen_get_usable_rect(window.current_screen).size
	var preferred := Vector2i((Vector2(logical_size)*window.content_scale_factor).ceil())
	if available.x > 0 and available.y > 0:
		preferred = preferred.min(Vector2i((Vector2(available)*0.9).floor()))
	window.popup_centered(preferred)

func _open_key_dialog() -> void:
	# A nonexclusive dialog can outlive a provider switch. Bind the credential
	# to the provider named in its title, never to the later menu selection.
	key_dialog_provider = current_provider
	key_dialog.title = key_dialog_provider+" key · memory only"
	key_field.text = keys.get(key_dialog_provider,"")
	_show_scaled_window(key_dialog,Vector2i(540,100))
	key_field.grab_focus()

func _apply_provider_key() -> void:
	if key_dialog_provider.is_empty(): return
	keys[key_dialog_provider] = key_field.text.strip_edges()
	provider_credentials_revision += 1
	_register_provider_keys_for_redaction()
	key_field.clear()

func proposal_configuration_identity() -> Dictionary:
	# Public, credential-free identity for an explicit host disclosure. The key
	# itself remains in this Art owner and enters only the dispatch snapshot.
	return {"provider":current_provider,"endpoint":endpoint.text.strip_edges(),
		"model":model.text.strip_edges(),"tokens":int(tokens.value),"seconds":float(seconds.value),
		"credentials_revision":provider_credentials_revision,"ui_epoch":ui_epoch}

func proposal_configuration_snapshot() -> Dictionary:
	request_epoch = _send_request_epoch()
	_register_provider_keys_for_redaction()
	return {"provider":current_provider,"endpoint":endpoint.text.strip_edges(),
		"model":model.text.strip_edges(),"key":str(keys.get(current_provider,"")),
		"tokens":int(tokens.value),"seconds":float(seconds.value),"context":[],"png":""}

func proposal_transport_block_reason() -> String:
	if provider.active or provider.request_preparation_active() or provider.response_preparation_active():
		return "Finish or Stop the current Art request first."
	if provider.export_active or provider.resume_active or conversation_apply_pending():
		return "Finish the current Art conversation or archive operation first."
	if executor.active or capturing or remaining_turns != 0 or waiting_until_ms > Time.get_ticks_msec() or log_draw:
		return "Finish or Stop ordinary Art drawing before requesting Architecture options."
	if collaboration != null and collaboration.busy():
		return "Finish or Stop collaborative Art work before requesting Architecture options."
	return ""

func _clear_hidden_key() -> void:
	# ConfirmationDialog may hide before emitting confirmed. Defer the generic
	# cleanup so confirmation reads the value, while X/Cancel still clear it.
	if not key_dialog.visible: key_field.clear()

func _set_traffic_path(text: String) -> void:
	if traffic_path.text == text: return
	traffic_path.text = text
	traffic_path.tooltip_text = text

func _begin_traffic_export(path: String) -> void:
	var blocked := history_block_reason()
	if not blocked.is_empty():
		input_error = blocked
		return
	var err := provider.begin_export(path)
	if err == OK: export_destination = path
	export_message = "Exporting full session · Cancel export or Stop to interrupt" if err == OK else "Export refused (%d): %s" % [err,provider.export_message]
	_set_traffic_path(export_message)

func _poll_traffic_export() -> void:
	if not provider.export_active: return
	var progress: Dictionary = provider.poll_export()
	if bool(progress.get("done",false)):
		var err := int(progress.get("error",FAILED))
		export_message = "Full session export completed: "+export_destination if err == OK else "Export refused (%d). %s" % [err,provider.export_message]
		if err == OK and not provider.export_message.is_empty(): export_message += " · "+provider.export_message
	else:
		var phase := "Verifying closed export" if progress.get("phase", "") == "verify" else "Exporting"
		export_message = "%s · %.1f / %.1f MiB · Cancel export or Stop to interrupt" % [phase,float(progress.get("bytes",0))/1048576.0,float(progress.get("total",0))/1048576.0]
	_set_traffic_path(export_message)

func _cancel_traffic_export() -> void:
	if not provider.export_active: return
	provider.cancel_export()
	export_message = provider.export_message if not provider.export_message.is_empty() else "Export cancelled; this export did not replace the destination."
	_set_traffic_path(export_message)

func _save_settings() -> Error:
	if not _profile_session_error.is_empty():
		input_error = _profile_session_error
		return ERR_FILE_CANT_READ
	var serialized := settings.encode_to_text()
	if _settings_were_saved and serialized == _saved_settings_text \
			and FileAccess.file_exists("user://art-provider.cfg"):
		if input_error.begins_with("Could not save Art preferences; "): input_error = ""
		return OK
	# ConfigFile.save can report success after a buffered short write. Verify the
	# complete encoded configuration after close before replacing the old file.
	# Reuse the current no-op cache, but only remember verified successful writes.
	var saved: Dictionary = preload("res://scripts/workbench_file_transaction.gd").write_text(
		"user://art-provider.cfg", serialized, MAX_PROFILE_BYTES)
	if not bool(saved.get("ok",false)):
		input_error = "Could not save Art preferences; " + str(saved.error)
		return ERR_FILE_CANT_WRITE
	_saved_settings_text = serialized
	_settings_were_saved = true
	if input_error.begins_with("Could not save Art preferences; "): input_error = ""
	return OK

var previous_mode := 1

func change_mode(index: int) -> void:
	match previous_mode:
		0: json_text = input.text
		1: prompt_text = input.text
		2: stencil_prompt = input.text
	match index:
		0: input.text = json_text
		1: input.text = prompt_text
		2: input.text = stencil_prompt
	previous_mode = index
	input_error = ""

func save_profile() -> void:
	settings.set_value(current_provider,"endpoint",endpoint.text)
	settings.set_value(current_provider,"model",model.text)
	settings.set_value(current_provider,"tokens",int(tokens.value))
	settings.set_value(current_provider,"seconds",int(seconds.value))
	var names: Array = settings.get_value(current_provider,"history",[])
	if not model.text.is_empty() and not names.has(model.text): names.append(model.text)
	settings.set_value(current_provider,"history",names)
	settings.set_value("session","context",context_mode.selected)
	settings.set_value("session","guidance",guidance.text)
	settings.set_value("session","scanline_guidance",stencil_guidance.text)
	# Drop the obsolete pointer on the next settings save, without opening,
	# modifying or deleting any historical archive.
	if settings.has_section_key("session","traffic_path"):
		settings.erase_section_key("session","traffic_path")
	_save_settings()

func change_provider(index: int) -> void:
	save_profile()
	current_provider = source.get_item_text(index)
	load_profile()

func load_profile() -> void:
	# Defaults seed new profiles only. Availability and modality are properties
	# of the configured service; a menu entry makes no live capability promise.
	var defaults := {"LM Studio":["http://127.0.0.1:1234/v1","kat-coder-v2.5-dev-reap-50@q6_k"],
		"OpenAI":["https://api.openai.com/v1","gpt-5.6-luna"],
		"NVIDIA":["https://integrate.api.nvidia.com/v1","nvidia/nemotron-3.5-super-vl-120b-a12b"]}
	endpoint.text = settings.get_value(current_provider,"endpoint",defaults[current_provider][0])
	var saved_model: String = str(settings.get_value(current_provider,"model",defaults[current_provider][1]))
	# A retired, nonexistent built-in ID must not reappear as the active choice.
	# Do not rewrite disk settings or delete historical records during display.
	model.text = defaults[current_provider][1] if saved_model == INVALID_LEGACY_MODEL else saved_model
	tokens.value = settings.get_value(current_provider,"tokens",8192)
	seconds.value = settings.get_value(current_provider,"seconds",180)
	history.clear()
	history.add_item("▾")
	var curated: Dictionary = NVIDIA_MODELS if current_provider == "NVIDIA" else (
		LM_STUDIO_MODELS if current_provider == "LM Studio" else {})
	var offered_ids: Dictionary = {}
	for label: String in curated:
		history.add_item(label)
		history.set_item_metadata(history.item_count-1,curated[label])
		offered_ids[str(curated[label])] = true
	# Display saved/custom names separately. Keep the stored history untouched,
	# including historical retired IDs, without suggesting invalid astra5-6.
	var custom: Array[String] = []
	for value: Variant in settings.get_value(current_provider,"history",[]):
		if not value is String or value == INVALID_LEGACY_MODEL or offered_ids.has(value) or custom.has(value):
			continue
		custom.append(value)
	if not custom.is_empty():
		var separator := history.item_count
		history.add_item("— Saved / custom —")
		history.set_item_disabled(separator,true)
		for value: String in custom: history.add_item(value)

func stop_all(reason: String = "Human Stop") -> void:
	var began_usec := Time.get_ticks_usec()
	_cancel_conversation_apply(reason)
	if collaboration != null: collaboration.stop(reason)
	if provider.resume_active:
		provider.cancel_resume()
		history_load_error = "Conversation restoration cancelled; saved history preserved. Reopen Art or Conversation to retry."
	_cancel_traffic_export()
	remaining_turns = 0
	run_deadline_ms = 0
	waiting_until_ms = 0
	ui_epoch += 1; capturing = false
	_pending_provider_send = {}
	provider.cancel(reason)
	executor.stop(reason)
	if wb != null and wb.paint_editor != null and wb.paint_editor.history_replaying():
		wb.paint_editor.cancel()
	provider_message = reason
	input_error = history_load_error if not history_load_error.is_empty() else reason
	last_stop_timing = {"stop_usec":Time.get_ticks_usec() - began_usec,
		"provider_cancel_usec":int(provider.last_request_timing.get("cancel_usec",0)),
		"active_after":provider.active}

func native_authoring_pending() -> bool:
	return (collaboration != null and collaboration.busy()) or executor.active or executor.waiting \
		or not executor.manual.is_empty() or not executor.manual_inflight.is_empty() \
		or provider.active or provider.request_preparation_active() or provider.response_preparation_active() \
		or capturing or remaining_turns != 0 or waiting_until_ms > Time.get_ticks_msec() or log_draw

# Shared PAINT shortcuts call the same guard as these buttons. A native-idle
# gap is not permission to undo while a provider or another turn can still write.
func history_block_reason() -> String:
	if collaboration != null and collaboration.busy(): return "Stop collaborative work and wait for its native receipt before Undo or Redo."
	if not _history_lost_receipt_error.is_empty(): return _history_lost_receipt_error
	if not _history_persistence_error.is_empty(): return _history_persistence_error
	if provider.resume_active: return "Finish or stop conversation restoration before changing history."
	if provider.export_active: return "Finish or cancel the traffic export before changing history."
	if executor.active or executor.waiting or not executor.manual.is_empty() \
			or not executor.manual_inflight.is_empty() or provider.active or capturing \
			or remaining_turns != 0 or waiting_until_ms > Time.get_ticks_msec():
		return "Stop the active agent run and wait for its confirmed result before Undo or Redo."
	if log_draw:
		return "Wait for the confirmed agent result before Undo or Redo."
	return ""

func _history_action(action: String) -> void:
	var blocked := history_block_reason()
	if not blocked.is_empty():
		input_error = blocked
		return
	if wb == null or wb.paint_editor == null:
		input_error = "The shared editor is not ready."
		return
	var admitted: bool = wb.paint_editor.undo() if action == "undo" else wb.paint_editor.redo()
	input_error = "" if admitted else str(wb.message)

# Each confirmed receipt is durably staged as its own small atomically
# published file, not as an in-memory queue with a silent 64-item overflow.
# No previous conversation is opened, copied or scanned on this path.
func _history_receipt_source() -> String:
	if not provider.log_path.is_empty(): return provider.log_path
	if not _pending_traffic_path.is_empty(): return _pending_traffic_path
	return provider.parent_log_path

# Only the small profile is read here. In particular, a failed load is not
# evidence that the user has no saved conversation. A source captured earlier
# by this Workbench remains usable during a later profile outage.
static func read_history_session() -> Dictionary:
	var directory := DirAccess.open("user://")
	if directory == null or directory.list_dir_begin() != OK:
		return {"state":"error","source":"","error":"Cannot inspect the Art profile directory; restore access before changing history."}
	var present := false
	var filename := directory.get_next()
	while not filename.is_empty():
		if filename == "art-provider.cfg": present = true; break
		filename = directory.get_next()
	directory.list_dir_end()
	if not present:
		# Missing configuration is a virgin profile only when there is no
		# evidence of previous Art persistence. Inspect names, never transcripts.
		for folder: String in ["user://art-traffic",HISTORY_RECEIPT_DIR]:
			if directory.is_link(folder.get_file()) or FileAccess.file_exists(folder):
				return {"state":"error","source":"","error":"Art profile is missing while prior storage is unavailable; restore the original art-provider.cfg."}
			if not DirAccess.dir_exists_absolute(folder): continue
			var prior := DirAccess.open(folder)
			if prior == null or prior.list_dir_begin() != OK:
				return {"state":"error","source":"","error":"Art profile is missing and prior storage cannot be inspected; restore access and the original profile."}
			var name := prior.get_next()
			while not name.is_empty():
				if name.ends_with(".jsonl") or name.ends_with(".json"):
					prior.list_dir_end()
					return {"state":"error","source":"","error":"Art profile is missing but saved history exists; restore its original art-provider.cfg. No session has been guessed."}
				name = prior.get_next()
			prior.list_dir_end()
		return {"state":"no_session","source":"","error":"","absent":true}
	if directory.is_link("art-provider.cfg") or directory.dir_exists("art-provider.cfg"):
		return {"state":"error","source":"","error":"Art profile exists but is not a regular readable file; restore art-provider.cfg and retry."}
	var file := FileAccess.open("user://art-provider.cfg",FileAccess.READ)
	if file == null:
		return {"state":"error","source":"","error":"Art profile exists but cannot be read; restore access to art-provider.cfg and retry."}
	var length := file.get_length()
	file = null
	if length > MAX_PROFILE_BYTES:
		return {"state":"error","source":"","error":"Art profile exceeds the 1 MiB limit; original profile preserved."}
	var config := ConfigFile.new()
	if config.load("user://art-provider.cfg") != OK:
		return {"state":"error","source":"","error":"Art profile is corrupt or unreadable; repair art-provider.cfg before retrying. No conversation has been guessed."}
	if not config.has_section_key("session","traffic_path"):
		return {"state":"error","source":"","error":"Art profile has incomplete session metadata; restore its traffic_path before retrying."}
	var path: Variant = config.get_value("session","traffic_path")
	if not path is String or (not path.is_empty() and not Provider.valid_traffic_path(path)):
		return {"state":"error","source":"","error":"Art profile has an invalid session path; original profile and archives are preserved."}
	return {"state":"no_session" if path.is_empty() else "session","source":path,"error":"","absent":false}

static func _journal_directory() -> DirAccess:
	var parent := DirAccess.open("user://")
	if parent == null or parent.is_link(HISTORY_RECEIPT_DIR.get_file()): return null
	if DirAccess.make_dir_recursive_absolute(HISTORY_RECEIPT_DIR) != OK: return null
	return DirAccess.open(HISTORY_RECEIPT_DIR)

static func _history_journal_name(filename: String) -> Dictionary:
	if not filename.ends_with(".json"): return {}
	var base := filename.trim_suffix(".json")
	if Provider.valid_history_receipt_id(base):
		return {"id":base,"order":base.substr(0,20),"legacy":true}
	if base.length() < 22 or base[20] != "_": return {}
	var order := base.substr(0,20)
	var identity := base.substr(21)
	if not order.is_valid_int() or int(order) < 0 or "%020d" % int(order) != order \
			or not Provider.valid_history_receipt_id(identity): return {}
	return {"id":identity,"order":order,"legacy":false}

static func _history_journal_names(directory: DirAccess) -> Dictionary:
	# Opening an execute-only directory can succeed while listing it fails.
	# Never mistake that failure for an empty journal or bypass its quota.
	if directory == null or directory.list_dir_begin() != OK:
		return {"ok":false,"names":[],"error":"Cannot list pending Art history; restore directory read access."}
	var names: Array[String] = []
	var filename := directory.get_next()
	var error := ""
	while not filename.is_empty():
		if filename.ends_with(".json"):
			if directory.current_is_dir() or directory.is_link(filename):
				error = "Pending Art history record is not a regular file: "+filename
				break
			if _history_journal_name(filename).is_empty():
				error = "Invalid pending Art history filename; original file preserved."
				break
			if names.size() >= MAX_HISTORY_RECEIPTS:
				error = "Pending Art history exceeds its bounded record capacity; originals preserved."
				break
			names.append(filename)
		filename = directory.get_next()
	directory.list_dir_end()
	return {"ok":error.is_empty(),"names":names,"error":error}

static func _valid_frozen_history_turn(item: Dictionary) -> bool:
	return item.get("turn") is Dictionary and item.turn.size() == 3 \
		and item.turn.get("role") == "user" and item.turn.get("content") is String \
		and item.turn.get("_history_receipt_id") == item.id \
		and Provider.Archive.integer(item.receipt.get("_history_world_epoch")) \
		and item.receipt._history_world_epoch == item.epoch \
		and item.turn.content.sha256_text() == item.receipt.get("_history_turn_sha256")

static func _persist_history_receipt(item: Dictionary) -> bool:
	if not Provider.valid_history_receipt_id(item.get("id")) or not item.get("source") is String \
			or not Provider.valid_traffic_path(item.source) or not Provider.Archive.integer(item.get("epoch")) \
			or not item.get("receipt") is Dictionary or item.receipt.get("_history_receipt_id") != item.id: return false
	var schema: Variant = item.get("schema",1)
	if (schema != 1 and schema != 2) or (schema == 2 and not _valid_frozen_history_turn(item)): return false
	var directory := _journal_directory()
	if directory == null: return false
	var listing := _history_journal_names(directory)
	if not bool(listing.ok): return false
	# Identity is immutable at capture; ordering is assigned only when the
	# complete existing journal is listable. A clock rollback during an outage
	# must not publish a newer volatile result before an older durable result.
	var tick := maxi(int(Time.get_unix_time_from_system()*1000000.0),_history_receipt_clock_us+1)
	for filename: String in listing.names:
		var prior := _history_journal_name(filename)
		if str(prior.id) == str(item.id): return false
		tick = maxi(tick,int(prior.order)+1)
	var order := "%020d" % tick
	var filename := order+"_"+str(item.id)+".json" if schema == 2 else str(item.id)+".json"
	var destination := HISTORY_RECEIPT_DIR.path_join(filename)
	if directory.file_exists(filename) or directory.dir_exists(filename) or directory.is_link(filename): return false
	var record := {"schema":schema,"id":item.id,"source":item.source,"epoch":item.epoch,"receipt":item.receipt}
	if schema == 2:
		record["turn"] = item.turn
		record["order"] = order
	var text := JSON.stringify(record)+"\n"
	var payload := text.to_utf8_buffer()
	if payload.size() > MAX_HISTORY_RECEIPT_BYTES: return false
	var count := 0
	var bytes := payload.size()
	for prior_filename: String in listing.names:
		count += 1
		if count >= MAX_HISTORY_RECEIPTS or directory.is_link(prior_filename): return false
		var existing := FileAccess.open(HISTORY_RECEIPT_DIR.path_join(prior_filename),FileAccess.READ)
		if existing == null: return false
		bytes += existing.get_length()
		if bytes > MAX_HISTORY_JOURNAL_BYTES: return false
	# Keep the independent same-directory temporary name short on Windows.
	# Retain a pending receipt only after its complete closed bytes verify;
	# get_error() alone does not observe every buffered short write.
	var temporary := HISTORY_RECEIPT_DIR.path_join("pending-"+Crypto.new().generate_random_bytes(16).hex_encode()+".partial")
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	var stored := file.store_buffer(payload)
	file.flush()
	var error := file.get_error()
	file.close()
	var verification := preload("res://scripts/workbench_file_transaction.gd").FileOperations.new()
	if stored and error == OK and verification.verify(temporary,payload).is_empty() \
			and bool(Provider.Archive.atomic_replace(temporary,destination).get("ok",false)):
		_history_receipt_clock_us = maxi(_history_receipt_clock_us,tick)
		if schema == 2: item["order"] = order
		item["file"] = destination
		return true
	DirAccess.remove_absolute(temporary)
	return false

static func _make_history_receipt(receipt: Dictionary, epoch: int, source: String, masker: Node) -> Dictionary:
	var tick := maxi(int(Time.get_unix_time_from_system()*1000000.0),_history_receipt_clock_us+1)
	# Names provide a clock floor when available, never transcript contents.
	# Durable publication separately establishes order after an unavailable
	# listing recovers; the captured identity and projection never change.
	if DirAccess.dir_exists_absolute(HISTORY_RECEIPT_DIR):
		var listing := _history_journal_names(DirAccess.open(HISTORY_RECEIPT_DIR))
		for filename: String in listing.names:
			var prior := _history_journal_name(filename)
			if not prior.is_empty(): tick = maxi(tick,int(prior.order)+1)
	_history_receipt_clock_us = tick
	var identity := "%020d-%s" % [tick,Crypto.new().generate_random_bytes(16).hex_encode()]
	var recorded: Dictionary = masker._sanitized_event_data("history_result",receipt)
	recorded["_history_receipt_id"] = identity
	recorded["_history_world_epoch"] = epoch
	# Freeze JSON numbers and the sanitized visible projection once. In-memory
	# secrets may change before retry or disappear entirely after a restart.
	recorded = JSON.parse_string(JSON.stringify(recorded))
	var content: String = masker.redact("Canvas result (world epoch %d): Human %s: %s" % [epoch,str(recorded.get("action","undo")),JSON.stringify(recorded)])
	recorded["_history_turn_sha256"] = content.sha256_text()
	return {"schema":2,"id":identity,"source":source,"epoch":epoch,"receipt":recorded,
		"turn":{"role":"user","content":content,"_history_receipt_id":identity}}

# A completed native edit is never repeated during persistence recovery. This
# returns its immutable receipt to the caller even if the journal is unwritable.
static func capture_unopened_history_receipt(receipt: Dictionary, epoch: int, association: Dictionary = {}, defer_staging: bool = false) -> Dictionary:
	var session := association if not association.is_empty() else read_history_session()
	if session.get("state","") == "no_session": return {"ok":true,"status":"no_session","error":"","item":{}}
	if session.get("state","") != "session":
		return {"ok":false,"status":"unassociated","error":"Native history completed, but its Art receipt was not retained: no trustworthy session is available. Do not repeat the native edit. "+str(session.get("error","Restore the saved profile before further history actions.")),"item":{}}
	var masker := Provider.new()
	var item := _make_history_receipt(receipt,epoch,str(session.source),masker)
	masker.free()
	var durable := not defer_staging and _persist_history_receipt(item)
	item["volatile"] = not durable
	if not durable: item["file"] = ""
	return {"ok":durable,"status":"staged" if durable else "pending_write","item":item,
		"error":"" if durable else "Confirmed Art history receipt could not be saved. Restore access/free space for art-pending-history; keep Workbench open for retry."}

static func stage_unopened_history_receipt(receipt: Dictionary, epoch: int, association: Dictionary = {}) -> bool:
	return bool(capture_unopened_history_receipt(receipt,epoch,association).ok)

static func retain_volatile_receipt(queue: Array[Dictionary], item: Dictionary) -> bool:
	var count := 0
	var bytes := JSON.stringify(item).to_utf8_buffer().size()
	for prior: Dictionary in queue:
		if not bool(prior.get("volatile",false)): continue
		count += 1
		bytes += JSON.stringify(prior).to_utf8_buffer().size()
	if count >= MAX_VOLATILE_HISTORY_RECEIPTS or bytes > MAX_VOLATILE_HISTORY_BYTES: return false
	queue.append(item)
	return true

func _queue_history_receipt(receipt: Dictionary, epoch: int) -> bool:
	var source_path := _history_receipt_source()
	if source_path.is_empty():
		if not _profile_session_error.is_empty():
			_history_persistence_error = "Confirmed native receipt cannot be associated. "+_profile_session_error
			input_error = _history_persistence_error
			return false
		input_error = "Native history completed; no saved Art conversation is associated."
		return true
	var item := _make_history_receipt(receipt,epoch,source_path,provider)
	# Grouped native completions can arrive before the periodic retry. Preserve
	# capture order by staging all earlier volatile results before this one.
	var earlier_volatile := false
	for prior: Dictionary in pending_history_receipts:
		if bool(prior.get("volatile",false)): earlier_volatile = true; break
	var durable := not earlier_volatile and _persist_history_receipt(item)
	item["volatile"] = not durable
	if not durable: item["file"] = ""
	if durable: pending_history_receipts.append(item)
	elif not retain_volatile_receipt(pending_history_receipts,item):
		_history_lost_receipt_error = "Confirmed Art receipt exceeded bounded recovery capacity. Free space/restore journal access; this receipt could not be retained. Further history is blocked for this Workbench."
		input_error = _history_lost_receipt_error
		return false
	_history_retry_needed = true
	if not provider.watch_history_receipt(item):
		_history_persistence_error = provider.log_warning
		input_error = _history_persistence_error
		return false
	if not durable:
		_history_persistence_error = "Confirmed Art receipt awaits a verified journal file. Restore access/free space; keep Workbench open for automatic retry."
		input_error = _history_persistence_error
	return durable

func _retry_history_journal() -> bool:
	for item: Dictionary in pending_history_receipts:
		if not bool(item.get("volatile",false)): continue
		if not _persist_history_receipt(item): return false
		item.volatile = false
	_history_persistence_error = ""
	return true

func _read_pending_history_receipts() -> Dictionary:
	var result: Dictionary = {"ok":true,"rows":[],"error":""}
	var parent := DirAccess.open("user://")
	if parent == null or parent.is_link(HISTORY_RECEIPT_DIR.get_file()):
		return {"ok":false,"rows":[],"error":"Pending Art history directory is unavailable or aliased; original data preserved."}
	if not DirAccess.dir_exists_absolute(HISTORY_RECEIPT_DIR):
		if FileAccess.file_exists(HISTORY_RECEIPT_DIR): return {"ok":false,"rows":[],"error":"Pending Art history directory is obstructed; restore directory access."}
		return result
	var directory := DirAccess.open(HISTORY_RECEIPT_DIR)
	var listing := _history_journal_names(directory)
	if not bool(listing.ok): return {"ok":false,"rows":[],"error":str(listing.error)}
	var bytes := 0
	for filename: String in listing.names: # Unpublished partials are not committed receipts.
		var name := _history_journal_name(filename)
		var identity := str(name.id)
		var path := HISTORY_RECEIPT_DIR.path_join(filename)
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null: return {"ok":false,"rows":[],"error":"Pending Art history is unreadable: "+filename}
		bytes += file.get_length()
		if file.get_length() > MAX_HISTORY_RECEIPT_BYTES or bytes > MAX_HISTORY_JOURNAL_BYTES or result.rows.size() >= MAX_HISTORY_RECEIPTS:
			return {"ok":false,"rows":[],"error":"Pending Art history exceeds its bounded receipt/count/byte capacity; originals preserved."}
		var length := file.get_length()
		var raw := file.get_buffer(length)
		var read_error := file.get_error()
		file = null
		if read_error != OK or raw.size() != length or raw.is_empty() or raw[-1] != 10 or Provider.Archive.utf8_text(raw) == null:
			return {"ok":false,"rows":[],"error":"Partial or invalid UTF-8 pending Art history record: "+filename}
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if not parsed is Dictionary:
			return {"ok":false,"rows":[],"error":"Malformed pending Art history record: "+filename}
		var item: Dictionary = parsed
		if (item.get("schema") != 1 and item.get("schema") != 2) or item.get("id") != identity or not item.get("source") is String or not Provider.valid_traffic_path(item.source) \
				or not item.get("receipt") is Dictionary or not Provider.Archive.integer(item.get("epoch")) \
				or str(item.receipt.get("_history_receipt_id","")) != identity:
			return {"ok":false,"rows":[],"error":"Invalid pending Art history source or receipt: "+filename}
		if item.schema == 2 and not _valid_frozen_history_turn(item):
			return {"ok":false,"rows":[],"error":"Invalid frozen pending Art history projection: "+filename}
		if (item.schema == 1 and not bool(name.legacy)) or (item.schema == 2 and (bool(name.legacy) or item.get("order") != name.order)):
			return {"ok":false,"rows":[],"error":"Invalid pending Art history publication order: "+filename}
		item["order"] = name.order
		item["file"] = path
		item["volatile"] = false
		result.rows.append(item)
	result.rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return str(a.id)<str(b.id) if str(a.order) == str(b.order) else str(a.order)<str(b.order))
	return result

func _drain_pending_history_receipts() -> void:
	if _history_draining or not conversation_loaded or provider.resume_active or provider.export_active: return
	_history_draining = true
	_drain_history_journal()
	_history_draining = false

func _drain_history_journal() -> void:
	if not _retry_history_journal(): return
	var disk := _read_pending_history_receipts()
	if not bool(disk.ok):
		_history_persistence_error = str(disk.error)
		input_error = _history_persistence_error
		_history_retry_needed = true
		return
	var pending: Array = disk.rows
	pending_history_receipts = [] # Every remaining item is now durably on disk.
	var sources := {}
	if not provider.log_path.is_empty(): sources[provider.log_path] = true
	for segment: Dictionary in provider._validated_segments: sources[str(segment.path)] = true
	_history_retry_needed = false
	for item: Dictionary in pending:
		if not sources.has(str(item.source)): continue # Never migrate an orphan to an unrelated session.
		if not provider.has_history_receipt(str(item.id)):
			# A disk record appearing after replay may already have committed its
			# turn. Discover that through the same incremental reader, not a fresh
			# empty deduplication state or synchronous transcript scan.
			conversation_loaded = false
			_history_retry_needed = true
			# Old journal receipts never cross into a new game-session log.
			return
			return
		if not provider.watch_history_receipt(item) or not _record_history_receipt(item.receipt,int(item.epoch),item.get("turn",{})):
			_history_retry_needed = true
			_history_persistence_error = "Art history remains safely pending. Restore archive/profile access, then retry. "+provider.log_warning
			input_error = _history_persistence_error
			return # Later receipts must not overtake this one.
		var path := str(item.file)
		if DirAccess.remove_absolute(path) != OK:
			_history_retry_needed = true
			_history_persistence_error = "History committed; journal cleanup failed. Retry will deduplicate this receipt."
			input_error = _history_persistence_error
			return
		provider.forget_history_receipt(str(item.id))
	_history_persistence_error = ""
	if not _history_lost_receipt_error.is_empty(): input_error = _history_lost_receipt_error

# Append a new human result; never rewrite the model's historical receipts or
# use model_feedback(), which can schedule another request in an active run.
func _record_history_receipt(_receipt: Dictionary, _epoch: int, _frozen_turn: Dictionary = {}) -> bool:
	# Compatibility with the dormant legacy journal drain method. Never
	# attach old pending receipts to a fresh game-session conversation.
	# Old journal files remain untouched for separate forensic inspection.
	_history_persistence_error = "Legacy cross-session Art receipt replay is retired. Original journal preserved."
	return false

func history_edited(receipt: Dictionary, captured_epoch: int = -1) -> void:
	# A PAINT Undo/Redo completed in this live session is recorded once in this
	# session's log. No receipt journal or prior-session transcript is required
	# to continue using Art; the native paint history remains authoritative.
	var epoch := captured_epoch if captured_epoch >= 0 else (int(wb.host.simulation_worker.art_state().epoch) if wb != null else request_epoch)
	var event := receipt.duplicate(true)
	event["world_epoch"] = epoch
	if not provider.log_event("native_history_action",event):
		input_error = "Native history completed, but its session log write failed. "+provider.log_warning
		return
	remember_turn("user","Canvas result (world epoch %d): Human %s: %s" % [epoch,str(receipt.get("action","undo")),JSON.stringify(receipt)])

func model_context() -> Array:
	if not _ensure_history_loaded(): return []
	if context_mode.selected == 3: return []
	var full := context_mode.selected == 0
	var first := 0 if full else maxi(0,conversation.size()-12)
	var context: Array = []
	if first > 0:
		context.append({"role":"user","content":"Earlier turns omitted from this request; latest confirmed result: "+last_result})
	for entry: Dictionary in conversation.slice(first):
		var content: String = entry.content
		if not full and entry.role == "assistant" and content.contains("</think>"):
			content = content.substr(content.rfind("</think>")+8).strip_edges()
		var message := {"role":entry.role,"content":content}
		if full and entry.has("image_offset") and not image_input.button_pressed:
			message.content += "\nHistorical image omitted because Image is off."
		elif full and entry.has("image_offset"):
			var url := provider.historical_image(int(entry.image_offset),str(entry.get("image_log_path","")))
			if url.is_empty():
				message.content += "\nThis turn's image is unavailable in saved traffic."
			elif current_provider == "OpenAI":
				message.content = [{"type":"input_text","text":entry.content},{"type":"input_image","image_url":url}]
			else:
				message.content = [{"type":"text","text":entry.content},{"type":"image_url","image_url":{"url":url}}]
		context.append(message)
	return context

func model_feedback(feedback: String) -> void:
	last_result = feedback
	remember_turn("user","Canvas result (world epoch %d): %s" % [request_epoch,feedback])
	if remaining_turns != 0:
		send_next.call_deferred(ui_epoch)

func remember_turn(role: String, content: String, image_offset: int = -1) -> bool:
	var entry := {"role":role,"content":provider.redact(content)}
	if image_offset >= 0:
		entry.image_offset = image_offset
		entry.image_log_path = provider.log_path
	if not provider.log_event("conversation",entry) or not persist_traffic_path():
		input_error = "Conversation turn was not saved to this session's log. "+provider.log_warning
		remaining_turns = 0
		return false
	conversation.append(entry)
	conversation_revision += 1
	return true

func _can_dispatch_provider_request(epoch: int, world_epoch: int) -> bool:
	# A deferred worker completion can run before the next _process epoch poll.
	# Check the captured World at the actual main-thread dispatch boundary too.
	if epoch != ui_epoch or not is_inside_tree() or is_queued_for_deletion():
		if int(_pending_provider_send.get("ui_epoch",-1)) == epoch: _pending_provider_send = {}
		return false
	if not is_instance_valid(wb) or not is_instance_valid(wb.host): return false
	if world_epoch != _send_request_epoch():
		stop_all("Canvas changed")
		return false
	return true

func _provider_request_started(id: int, request_offset: int) -> void:
	if _pending_provider_send.is_empty() or int(_pending_provider_send.id) != id: return
	var pending := _pending_provider_send
	_pending_provider_send = {}
	if id != provider.serial or not _can_dispatch_provider_request(int(pending.ui_epoch),int(pending.world_epoch)): return
	var began_usec := Time.get_ticks_usec()
	# The offset belongs to this admitted request. Never consult a previous
	# request's offset while outbound value preparation is still pending.
	remember_turn("user",str(pending.prompt),request_offset if bool(pending.has_image) else -1)
	var timing: Dictionary = pending.timing
	timing.conversation_log_usec = Time.get_ticks_usec()-began_usec
	timing.request_started_after_usec = Time.get_ticks_usec()-int(pending.began_usec)
	timing.request_started = true

func _commit_traffic_path(path: String) -> bool:
	# Compatibility for existing in-session edit/receipt call sites. No profile
	# writes and no adoption of a predecessor archive.
	return not path.is_empty() and path == provider.log_path

func persist_traffic_path() -> bool:
	return provider.last_event_stored and not provider.log_path.is_empty()

func send_prompt() -> void:
	if conversation_apply_pending():
		input_error = "Wait for conversation Apply, or Cancel it, before sending."
		return
	if collaboration != null and collaboration.busy():
		input_error = "Finish or Stop collaborative work before direct model painting."
		return
	if executor.active or provider.active or capturing or remaining_turns != 0 or provider.export_active: return
	if wb.paint_editor != null and wb.paint_editor.busy():
		input_error = "Wait for the shared edit to finish before sending another model request."
		return
	if wb.busy() or wb.applied.is_empty():
		input_error = "Canvas is not ready."
		return
	# A spending estimate alone cannot bound requests or elapsed time.
	# Keep direct authoring convenient while refusing indefinite automatic turns.
	if turn_limit.value <= 0 and run_seconds.value <= 0:
		input_error = "Set Turns or Run s above zero so this run has a finite limit."
		return
	sent_turns = 0
	run_spend = 0.0
	spend_status = ""
	run_spend_limit = spend_limit.value
	if run_spend_limit > 0 and (input_price.value <= 0 and output_price.value <= 0):
		input_error = "Set a token rate in Limits, or set the spending ceiling to zero."
		return
	task_prompt = input.text
	run_mode = input_mode.selected
	last_send_epoch_usec = 0
	run_epoch = _send_request_epoch()
	last_image = ""
	remaining_turns = int(turn_limit.value) if turn_limit.value > 0 else -1
	run_deadline_ms = Time.get_ticks_msec()+int(run_seconds.value*1000) if run_seconds.value > 0 else 0
	send_next(ui_epoch)

func _send_request_epoch() -> int:
	var began_usec := Time.get_ticks_usec()
	var epoch: int = wb.host.simulation_worker.art_state().epoch
	last_send_epoch_usec += Time.get_ticks_usec() - began_usec
	return epoch

func send_next(expected_epoch: int) -> void:
	if expected_epoch != ui_epoch or remaining_turns == 0: return
	if run_epoch != _send_request_epoch():
		stop_all("Canvas changed")
		return
	var due := next_request_ms
	if endpoint.text.strip_edges() == provider_wait_url: due = maxi(due,provider_wait_ms)
	var delay := due - Time.get_ticks_msec()
	if delay > 0:
		waiting_until_ms = due
		provider.log_event("pace_wait",{"milliseconds":delay})
		await get_tree().create_timer(delay/1000.0).timeout
		if expected_epoch == ui_epoch:
			waiting_until_ms = 0
			send_next(expected_epoch)
		return
	if executor.active or provider.active or capturing: return
	if wb.busy() or wb.applied.is_empty():
		remaining_turns = 0
		input_error = "Canvas is not ready."
		return
	executor.wb = wb
	input_error = ""
	ui_epoch += 1
	var epoch := ui_epoch
	request_epoch = _send_request_epoch()
	request_area = rectangle(fields)
	request_guards = [rectangle(protected_fields)] if protect.button_pressed else []
	request_shapes = enabled_shapes()
	request_pixel_limit = int(pixel_limit.value)
	request_material = paint_material.get_selected_id()
	request_materials = [request_material]
	if erase.button_pressed: request_materials.append(0)
	var png := ""
	var observation := ""
	if image_input.button_pressed:
		if DisplayServer.get_name()=="headless": input_error = "Image capture needs a graphical window. Turn Image off for text-only inference."; return
		capturing = true
		# Capture the actual canvas without our floating windows covering it.
		var reopen := visible
		var reopen_traffic := traffic_window.visible
		hide(); traffic_window.hide()
		await RenderingServer.frame_post_draw
		var frame: Image = wb.host.get_viewport().get_texture().get_image()
		if reopen: show()
		if reopen_traffic: traffic_window.show()
		if epoch != ui_epoch: return
		var logical: Vector2 = wb.host.get_viewport().get_visible_rect().size
		var scale := Vector2(frame.get_width(),frame.get_height())/logical
		var rect: Rect2 = wb.host.view_content_rect()
		rect.position += wb.host.world_view.get_global_rect().position
		var visible_cells := Rect2(wb.host.presentation_camera_origin(),Vector2(wb.host.current_view_size))
		var image_cells := visible_cells
		if not full_image.button_pressed:
			var intersection := visible_cells.intersection(Rect2(request_area))
			if intersection.has_area(): image_cells = intersection
		var pixels_per_cell := rect.size/visible_cells.size
		var image_rect := Rect2(rect.position+(image_cells.position-visible_cells.position)*pixels_per_cell,image_cells.size*pixels_per_cell)
		var crop := Rect2i(image_rect.position*scale,image_rect.size*scale).intersection(Rect2i(Vector2i.ZERO,frame.get_size()))
		if not crop.has_area(): capturing = false; input_error = "Canvas capture is empty."; return
		# Pixel cropping rounds the requested rectangle. Describe the actual
		# captured pixel edges, including fractional cells, to the agent.
		image_cells = Rect2(visible_cells.position+(Vector2(crop.position)/scale-rect.position)/pixels_per_cell,
			Vector2(crop.size)/scale/pixels_per_cell)
		var view := frame.get_region(crop)
		if maxi(view.get_width(),view.get_height())>768:
			var ratio := 768.0/maxi(view.get_width(),view.get_height())
			view.resize(maxi(1,int(view.get_width()*ratio)),maxi(1,int(view.get_height()*ratio)),Image.INTERPOLATE_NEAREST)
		png = Marshalls.raw_to_base64(view.save_png_to_buffer())
		observation = "Image world rectangle x=%.6f y=%.6f w=%.6f h=%.6f, image %d by %d pixels, world epoch %d." % [image_cells.position.x,image_cells.position.y,image_cells.size.x,image_cells.size.y,view.get_width(),view.get_height(),request_epoch]
		provider.log_event("observation",{"mapping":observation,"sha256":png.sha256_text()})
		capturing = false
	if epoch != ui_epoch or request_epoch != _send_request_epoch(): return
	var preparation_begin_usec := Time.get_ticks_usec()
	last_send_timing = {"schema":1,"profile_usec":0,"context_usec":0,
		"parameters_log_usec":0,"provider_send_usec":0,"conversation_log_usec":0,"total_usec":0,
		"request_started":false,"request_started_after_usec":0}
	var send_timing := last_send_timing
	var profile_begin_usec := Time.get_ticks_usec()
	save_profile()
	send_timing.profile_usec = Time.get_ticks_usec() - profile_begin_usec
	var instructions := guidance.text+" Work area XYWH="+JSON.stringify([request_area.position.x,request_area.position.y,request_area.size.x,request_area.size.y])+"; allowed materials="+JSON.stringify(request_materials)+"; protected rectangles="+str(request_guards)+"."
	request_scanline = run_mode == 2
	request_local = current_provider == "LM Studio" or request_scanline
	if request_local:
		instructions = guidance.text+" Coordinates are LOCAL: top-left is (0,0), never add a world offset. XYWH="+JSON.stringify([0,0,request_area.size.x,request_area.size.y])+". Allowed materials="+JSON.stringify(request_materials)+". Use compact rectangles, discs and lines. Every rectangle and line requires all four endpoint fields. Do not enumerate filled areas as pixels."
	if request_scanline:
		instructions = stencil_guidance.text+" Local area width %d, height %d. Allowed materials %s." % [request_area.size.x,request_area.size.y,str(request_materials)]
	if not request_scanline:
		instructions += "\nEnabled shapes: "+JSON.stringify(request_shapes)+". Use only these shapes. Line and polyline accept optional integer width (default 1) with rounded ends. Polyline and filled polygon use points:[[x,y],...]. Airbrush uses x,y,radius, optional density and hardness in [0,1], and an integer seed."
		if request_pixel_limit > 0:
			instructions += " Maximum %d points per pixels operation." % request_pixel_limit
	instructions += "\nUse only the current work area above, even when previous turns used a different area.\nSelected drawing material: %d. Use it for drawing. Return [] when finished." % request_material
	var context_begin_usec := Time.get_ticks_usec()
	var context := model_context()
	send_timing.context_usec = Time.get_ticks_usec() - context_begin_usec
	var prompt := task_prompt
	if not observation.is_empty(): prompt += "\n"+observation
	if sent_turns > 0:
		prompt += "\nContinue revising the current artwork. Latest confirmed result: "+last_result+"\nReturn [] when finished."
	var image_hash := png.sha256_text()
	if not png.is_empty() and image_hash == last_image and context_mode.selected != 3:
		png = ""
		prompt += "\nThe current view matches the last capture. Image bytes omitted from this request."
	last_image = image_hash
	next_request_ms = Time.get_ticks_msec() + int(minimum_interval.value*1000)
	if remaining_turns > 0: remaining_turns -= 1
	sent_turns += 1
	request_url = endpoint.text.strip_edges()
	sent_input_price = input_price.value
	sent_output_price = output_price.value
	# Selected and previously entered credentials must already be known to the
	# redactor before any request snapshot, including rotated keys.
	_register_provider_keys_for_redaction()
	var request_key: String = str(keys.get(current_provider,""))
	# The snapshot is sufficient to manually reproduce the request from this
	# session's standalone JSONL, without an old chat transcript or profile link.
	var parameters_begin_usec := Time.get_ticks_usec()
	provider.log_event("request_parameters",{
		"provider":current_provider,"model":model.text.strip_edges(),"endpoint":request_url,
		"mode":input_mode.get_item_text(run_mode),"prompt":task_prompt,
		"guidance":guidance.text,"scanline_guidance":stencil_guidance.text,
		"focus_xywh":[request_area.position.x,request_area.position.y,request_area.size.x,request_area.size.y],
		"protected":[[request_guards[0].position.x,request_guards[0].position.y,request_guards[0].size.x,request_guards[0].size.y]] if not request_guards.is_empty() else [],
		"materials":request_materials,"shapes":request_shapes,"pixel_limit":request_pixel_limit,
		"image":image_input.button_pressed,"full_view":full_image.button_pressed,
		"context_mode":context_mode.get_item_text(context_mode.selected),
		"tokens":int(tokens.value),"timeout_seconds":seconds.value,
		"turns":int(turn_limit.value),"run_seconds":run_seconds.value,
		"minimum_interval_seconds":minimum_interval.value,"spend_limit":spend_limit.value,
		"world_epoch":request_epoch})
	send_timing.parameters_log_usec = Time.get_ticks_usec() - parameters_begin_usec
	# Audit observers can invoke Stop synchronously. A cancelled run must not
	# create a new provider generation after its request snapshot was written.
	# remaining_turns can already be zero for the last admitted turn, so the
	# generation is the cancellation authority here.
	if epoch != ui_epoch:
		send_timing.total_usec = Time.get_ticks_usec() - preparation_begin_usec
		return
	var expected_id: int = provider.serial+1
	_pending_provider_send = {"id":expected_id,"ui_epoch":epoch,"world_epoch":request_epoch,
		"prompt":prompt,"has_image":not png.is_empty(),"timing":send_timing,"began_usec":preparation_begin_usec}
	var provider_send_begin_usec := Time.get_ticks_usec()
	var send_error: String = provider.send(current_provider,request_url,model.text.strip_edges(),request_key,prompt,instructions,int(tokens.value),seconds.value,png,context,_can_dispatch_provider_request.bind(epoch,request_epoch))
	send_timing.provider_send_usec = Time.get_ticks_usec() - provider_send_begin_usec
	# total_usec measures this Send callback; a later request_started callback
	# reports its own conversation work and elapsed admission wait separately.
	send_timing.total_usec = Time.get_ticks_usec() - preparation_begin_usec
	if epoch != ui_epoch: return
	if not send_error.is_empty():
		if int(_pending_provider_send.get("id",-1)) == expected_id: _pending_provider_send = {}
		input_error = send_error
		remaining_turns = 0

func provider_finished(_id: int, text: String, _response: Dictionary, error: String) -> void:
	# A prior finished observer can Stop or replace the request while the
	# signal is being delivered. Only the current generation may edit the World.
	if _id != provider.serial: return
	if int(_pending_provider_send.get("id",-1)) == _id: _pending_provider_send = {}
	var began_usec := Time.get_ticks_usec()
	var timing := {"schema":1,"total_usec":0,"world_check_usec":0,"operations_parse_usec":0,"native_submit_usec":0}
	_apply_provider_response(_id,text,error,timing)
	timing.total_usec = Time.get_ticks_usec() - began_usec
	last_finished_timing = timing

func _apply_provider_response(id: int, text: String, error: String, timing: Dictionary) -> void:
	var epoch_begin_usec := Time.get_ticks_usec()
	var current_epoch: int = wb.host.simulation_worker.art_state().epoch
	timing.world_check_usec = Time.get_ticks_usec() - epoch_begin_usec
	if request_epoch != current_epoch:
		provider.log_event("discarded","Canvas changed or Stop requested; no drawing")
		return
	var received_input: Variant = provider.usage.get("input_tokens",provider.usage.get("prompt_tokens"))
	var received_output: Variant = provider.usage.get("output_tokens",provider.usage.get("completion_tokens"))
	if ArtPlan.integer(received_input) and ArtPlan.integer(received_output) and received_input >= 0 and received_output >= 0 and (sent_input_price > 0 or sent_output_price > 0):
		run_spend += (float(received_input)*sent_input_price+float(received_output)*sent_output_price)/1000000.0
		provider.log_event("estimated_spend",{"run_usd":run_spend,"ceiling_usd":run_spend_limit})
		if id != provider.serial: return
		if run_spend_limit > 0 and run_spend >= run_spend_limit:
			remaining_turns = 0
			spend_status = "Estimated spending ceiling reached"
			provider.log_event("run_limit",spend_status)
			if id != provider.serial: return
	elif run_spend_limit > 0 and error.is_empty():
		remaining_turns = 0
		spend_status = "Provider usage unavailable; spending ceiling cannot be tracked"
		provider.log_event("run_limit",spend_status)
		if id != provider.serial: return
	if provider.retry_after_seconds > 0:
		provider_wait_ms = Time.get_ticks_msec()+int(provider.retry_after_seconds*1000)
		provider_wait_url = request_url
		provider.log_event("provider_rate_wait",{"seconds":provider.retry_after_seconds})
		if id != provider.serial: return
	if not error.is_empty():
		if provider.retry_after_seconds > 0 and remaining_turns != 0:
			send_next.call_deferred(ui_epoch)
			return
		input_error = error
		if error.containsn("context_length") or error.containsn("context window"):
			input_error = "Provider context limit reached. Choose Compacted or None and resend. "+error
		remaining_turns = 0
		remember_turn("user","Request failed: "+error)
		return
	provider.log_event("message",text)
	if id != provider.serial: return
	remember_turn("assistant",text)
	if id != provider.serial: return
	var operations_begin_usec := Time.get_ticks_usec()
	var operations: Variant = Provider.operations(text,request_material)
	timing.operations_parse_usec = Time.get_ticks_usec() - operations_begin_usec
	if not request_scanline:
		input_error = tool_error(operations,request_shapes,request_pixel_limit)
		if not input_error.is_empty():
			model_feedback(input_error)
			return
	if request_scanline and operations is Array and not operations.is_empty():
		operations = stencil_operations(operations)
		if operations.is_empty():
			input_error = "No usable scanline spans. Check y, repeat, scale, x, length and material."
			model_feedback(input_error)
			return
	if operations is Array and operations.is_empty():
		remaining_turns = 0
		input_error = "Model finished."
		return
	if request_local and operations is Array:
		var fitted := local_operations(operations)
		provider.log_event("local_geometry",{"accepted":fitted.size(),"returned":operations.size(),"origin":str(request_area.position)})
		if id != provider.serial: return
		if fitted.is_empty():
			input_error = "No usable shapes in the local response. See Traffic."
			model_feedback(input_error)
			return
		operations = fitted
	if id != provider.serial: return
	var submit_begin_usec := Time.get_ticks_usec()
	var answer: Dictionary = executor.submit(operations,request_area,request_guards,request_materials)
	timing.native_submit_usec = Time.get_ticks_usec() - submit_begin_usec
	provider.log_event("drawing_admission",answer)
	if answer.status=="refused":
		input_error = answer.reason+" · See Traffic."
		model_feedback(input_error)
	else: log_draw = true

func stencil_operations(rows_data: Array) -> Array:
	var operations: Array = []
	for row: Variant in rows_data:
		if not row is Dictionary or not row.get("spans") is Array: continue
		var y: Variant = row.get("y")
		var repeat: Variant = row.get("repeat",1)
		var scale: Variant = row.get("scale",1)
		if not ArtPlan.integer(y) or not ArtPlan.integer(repeat) or not ArtPlan.integer(scale): continue
		if y < 0 or repeat < 1 or scale < 1: continue
		var top := int(y)*int(scale)
		var bottom := (int(y)+int(repeat))*int(scale)-1
		for raw_span: Variant in row.spans:
			var span: Variant = raw_span
			if raw_span is Dictionary:
				span = [raw_span.get("x"),raw_span.get("length"),raw_span.get("material")]
			if not span is Array or span.size() != 3: continue
			if not ArtPlan.integer(span[0]) or not ArtPlan.integer(span[1]) or span[0] < 0 or span[1] < 1: continue
			var material: Variant = span[2]
			if material is String and material.is_valid_int(): material = int(material)
			operations.append({"shape":"rectangle","x0":int(span[0])*int(scale),"x1":(int(span[0])+int(span[1]))*int(scale)-1,"y0":top,"y1":bottom,"material":material})
	return operations

func local_operations(operations: Array) -> Array:
	var fitted: Array = []
	var bounds := Rect2i(Vector2i.ZERO,request_area.size)
	for raw: Variant in operations:
		if not raw is Dictionary: continue
		var candidates: Array = [raw]
		if raw.get("shape") == "pixels" and not raw.has("points") and raw.has("x") and raw.has("y"):
			raw.points = [[raw.x,raw.y]]
		if raw.get("shape") == "line" and not raw.has("x0") and raw.get("points") is Array:
			candidates = []
			for i: int in range(1,raw.points.size()):
				var a: Variant = raw.points[i-1]
				var b: Variant = raw.points[i]
				if a is Array and b is Array and a.size()==2 and b.size()==2:
					candidates.append({"shape":"line","material":raw.material,"x0":a[0],"y0":a[1],"x1":b[0],"y1":b[1]})
		for candidate: Dictionary in candidates:
			var op := fit_local_operation(candidate,bounds)
			if not op.is_empty(): fitted.append(op)
	return fitted

func fit_local_operation(raw: Dictionary,bounds: Rect2i) -> Dictionary:
	var plan := ArtPlan.new()
	if not plan.configure([raw],bounds): return {}
	var op: Dictionary = raw.duplicate(true)
	op.material = int(op.material)
	if op.material not in request_materials: return {}
	match op.shape:
		"pixels","polyline","polygon":
			for pair: Array in op.points:
				pair[0] += request_area.position.x
				pair[1] += request_area.position.y
		"disc","airbrush":
			op.x += request_area.position.x
			op.y += request_area.position.y
		_:
			for key: String in ["x0","x1"]: op[key] += request_area.position.x
			for key: String in ["y0","y1"]: op[key] += request_area.position.y
	return op

func refresh_traffic() -> void:
	if not traffic_window.visible: return
	traffic_dirty = false
	traffic_refresh_after = Time.get_ticks_msec()+500
	var content: String = provider.traffic if raw_traffic.button_pressed else provider.readable
	var query := traffic_filter.text.strip_edges()
	if not query.is_empty():
		var matches := PackedStringArray()
		for line: String in content.split("\n"):
			if line.containsn(query): matches.append(line)
		content = "\n".join(matches)
	if content.length() > 120000: content = "[Showing latest matching traffic; Save JSONL exports the complete session]\n"+content.right(120000)
	traffic_text.text = content
	var active_path: String = provider.log_path if not provider.log_path.is_empty() else provider.parent_log_path
	_set_traffic_path(export_message if not export_message.is_empty() else (ProjectSettings.globalize_path(active_path) if not active_path.is_empty() else "No traffic file yet")+(" · "+provider.log_warning if not provider.log_warning.is_empty() else ""))
