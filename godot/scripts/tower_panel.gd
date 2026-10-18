class_name CyberTowerPanel
extends VBoxContainer

const H_VIEW_PRESETS: Array[Vector2i] = [
	Vector2i(320,180),
	Vector2i(480,270),
	Vector2i(640,360),
	Vector2i(960,540),
]
const H_CAMERA_PAN_SPEED: float = 150.0
const H_SEQUENCE_MAX_FRAMES: int = 1800

var host: Variant
var floor_picker: OptionButton
var tube_picker: OptionButton
var info: Label
var labels: Array[Label] = []
var label_points: Array[Vector2] = []
var shown_floor: int = -1
var water_save_button: Button
var release_buttons: Array[Button] = []
var blind_button: Button
var previous_blind_button: Button
var replay_blind_button: Button
var next_blind_button: Button
var water_policy_button: Button
var h_view_menu: MenuButton
var h_phase_menu: MenuButton

var h_recorder: CyberHGateRecorder = CyberHGateRecorder.new()
var h_rank: OptionButton
var h_judgement: OptionButton
var h_note: LineEdit
var h_note_edit_button: Button
var h_capture_button: Button
var h_sequence_button: Button
var h_sequence_arm_button: Button
var h_reveal_button: Button
var h_open_button: Button
var h_feedback: Label
var h_reveal_dialog: ConfirmationDialog
var h_run_key: String = ""
var h_retained_blind_set: Dictionary = {}
var h_candidate_reviews: Dictionary = {}
var h_blind_revealed: bool = false
var h_blind_sealed: bool = false
var h_pending_run_start: bool = false
var h_preferred_view_size: Vector2i = Vector2i.ZERO
var h_view_focus: Vector2 = Vector2.ZERO
var h_view_focus_valid: bool = false
var h_restore_pause_after_apply: bool = false
var h_restore_pause_value: bool = true
var h_sequence_active: bool = false
var h_sequence_last_render_serial: int = -1
var h_sequence_run_key: String = ""
var h_sequence_arm_next_replay: bool = false

func button(row: Node, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.pressed.connect(action)
	row.add_child(b)
	return b

func setup(controller: Control) -> void:
	host = controller
	name = "ExperimentControls"
	h_preferred_view_size=host.current_view_size
	h_view_focus=host.camera_origin+Vector2(host.current_view_size)*0.5
	h_view_focus_valid=true
	var row: HBoxContainer = HBoxContainer.new();add_child(row)
	floor_picker = OptionButton.new();floor_picker.focus_mode = Control.FOCUS_NONE
	for i: int in range(5): floor_picker.add_item("%d / %s" % [i+1,CyberExperimentTower.FLOORS[i]])
	floor_picker.item_selected.connect(func(i: int) -> void: host.tower_floor_select(i));row.add_child(floor_picker)
	button(row,"Pause / resume",_toggle_pause);button(row,"Single step",_single_step);button(row,"Fresh tower",func() -> void: host.tower_reset());button(row,"Tuning",func() -> void: host.tower_tuning());button(row,"Water Feel",_water_reset)
	water_policy_button=button(row,"Water policy",func() -> void: host.water_lab_open());water_save_button=button(row,"Save Water policy",func() -> void: host.water_lab_save_profile())
	var release: HBoxContainer = HBoxContainer.new();add_child(release)
	tube_picker = OptionButton.new();tube_picker.focus_mode = Control.FOCUS_NONE;tube_picker.item_selected.connect(func(i: int) -> void: host.tower_focus_tube(i));release.add_child(tube_picker)
	release_buttons.append(button(release,"Open plug",func() -> void: host.tower_command({"release":tube_picker.selected})));release_buttons.append(button(release,"Open neighbours",func() -> void: host.tower_command({"release":tube_picker.selected,"adjacent":true})));release_buttons.append(button(release,"Sequence +30 / +90 ticks",func() -> void: host.tower_command({"schedule":tube_picker.selected})))
	var audition: HBoxContainer=HBoxContainer.new();audition.custom_minimum_size.y=36;add_child(audition)
	var audition_label: Label=Label.new();audition_label.text="H audition:";audition.add_child(audition_label)
	blind_button=button(audition,"Blind A/B/C",_start_blind);previous_blind_button=button(audition,"Previous",_previous_blind);replay_blind_button=button(audition,"Replay / Repeat (R)",_replay_blind);next_blind_button=button(audition,"Next",_next_blind)
	h_view_menu=MenuButton.new();h_view_menu.focus_mode=Control.FOCUS_NONE;audition.add_child(h_view_menu)
	var view_popup: PopupMenu=h_view_menu.get_popup()
	for index: int in range(H_VIEW_PRESETS.size()):
		var size: Vector2i=H_VIEW_PRESETS[index];view_popup.add_item("%dx%d"%[size.x,size.y],index)
	view_popup.id_pressed.connect(_select_h_view)
	_refresh_h_view_label()
	h_phase_menu=MenuButton.new();h_phase_menu.focus_mode=Control.FOCUS_NONE;h_phase_menu.text="Test phase";audition.add_child(h_phase_menu)
	var phase_popup: PopupMenu=h_phase_menu.get_popup();var phase_ids: Array[String]=CyberWaterFeelScenarios.ids()
	for index: int in range(phase_ids.size()):phase_popup.add_item(phase_ids[index],index)
	phase_popup.id_pressed.connect(_select_h_phase)
	var h_row: HBoxContainer = HBoxContainer.new();add_child(h_row)
	h_rank=OptionButton.new();h_rank.focus_mode=Control.FOCUS_NONE;h_rank.add_item("Rank —",0);h_rank.add_item("Rank 1",1);h_rank.add_item("Rank 2",2);h_rank.add_item("Rank 3",3);h_row.add_child(h_rank)
	h_judgement=OptionButton.new();h_judgement.focus_mode=Control.FOCUS_NONE
	for value: String in ["Judgement —","Preferred","Good","Acceptable","Marginal","Reject","Anomaly"]: h_judgement.add_item(value)
	h_row.add_child(h_judgement)
	h_note=LineEdit.new();h_note.placeholder_text="Short observation / nuance";h_note.custom_minimum_size.x=280;h_note.editable=false;h_note.focus_mode=Control.FOCUS_NONE;h_note.tooltip_text="Use Edit note. Press Enter or click elsewhere to return keyboard input to gameplay.";h_note.text_submitted.connect(func(_text: String) -> void: _finish_h_note_edit());h_note.focus_exited.connect(_on_h_note_focus_exited);h_row.add_child(h_note)
	h_note_edit_button=button(h_row,"Edit note",_toggle_h_note_edit)
	h_capture_button=button(h_row,"Capture H observation",_capture_h);h_reveal_button=button(h_row,"Finish / reveal blind",_request_reveal);h_open_button=button(h_row,"Open H folder",_open_h_folder)
	var sequence_row: HBoxContainer=HBoxContainer.new();add_child(sequence_row)
	var sequence_label: Label=Label.new();sequence_label.text="Motion evidence:";sequence_row.add_child(sequence_label)
	h_sequence_button=button(sequence_row,"Start frame sequence",_toggle_frame_sequence)
	h_sequence_arm_button=button(sequence_row,"Arm next replay",_toggle_arm_next_replay)
	var sequence_help: Label=Label.new();sequence_help.text="Every distinct rendered world frame → PNG sequence (max %d frames)"%H_SEQUENCE_MAX_FRAMES;sequence_row.add_child(sequence_help)
	h_feedback=Label.new();h_feedback.text="H capture idle — append-only; blind settings remain hidden until reveal";h_feedback.add_theme_font_size_override("font_size",13);add_child(h_feedback)
	h_reveal_dialog=ConfirmationDialog.new();h_reveal_dialog.title="Reveal blind candidates?";h_reveal_dialog.dialog_text="Finish your qualitative judgements first. Revealing candidate settings cannot be undone for this H session.";h_reveal_dialog.confirmed.connect(_reveal_confirmed);add_child(h_reveal_dialog)
	info=Label.new();info.add_theme_font_size_override("font_size",14);add_child(info);visible=false
	call_deferred("_neutralize_root_tower_focus")

func _input(event: InputEvent) -> void:
	if not visible or host==null or not event is InputEventKey:return
	var key: InputEventKey=event as InputEventKey
	if not key.pressed or key.echo:return
	if h_note!=null and h_note.editable:return
	if not bool(host.tower_context.get("water_active",false)):return
	if key.keycode==KEY_R:
		_repeat_test();get_viewport().set_input_as_handled()
	elif key.keycode==KEY_V:
		_cycle_h_view();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible or host==null:return
	if not bool(host.tower_context.get("water_active",false)):return
	if not host.pending_water_apply.is_empty():return
	_capture_sequence_frame_if_due()
	if h_note!=null and h_note.editable:return
	var pan_input: Vector2=Vector2(
		(1.0 if Input.is_key_pressed(KEY_RIGHT) else 0.0)-(1.0 if Input.is_key_pressed(KEY_LEFT) else 0.0),
		(1.0 if Input.is_key_pressed(KEY_DOWN) else 0.0)-(1.0 if Input.is_key_pressed(KEY_UP) else 0.0)
	)
	if pan_input.length_squared()<=0.0:return
	_pan_h_camera(pan_input.normalized()*H_CAMERA_PAN_SPEED*delta)

func _neutralize_root_tower_focus() -> void:
	if host==null or not host.has_node("Layout"):return
	for child: Node in host.get_node("Layout").get_children():
		if child is Button and (child as Button).text=="Experiment Tower / F9":(child as Button).focus_mode=Control.FOCUS_NONE

func _ensure_h_session() -> bool:
	if not h_recorder.session_id.is_empty():return true
	var started: Dictionary=h_recorder.start_session(host.water_runtime_identity(),{"purpose":"CyberSand Water Feel H-gate","water_feel_version":CyberWaterFeelScenarios.VERSION})
	if not started.get("ok",false):h_feedback.text="H capture error: "+str(started.get("error","unknown error"));return false
	h_feedback.text="H session %s started — capture creates screenshot + metadata + breadcrumb"%h_recorder.session_id;return true

func _active_blind_set() -> Dictionary:
	if host!=null and not host.water_blind_set.is_empty():return host.water_blind_set
	return h_retained_blind_set

func _current_blind_label() -> String:
	if host==null:return ""
	return str(host.water_active_blind_label)

func _store_current_review() -> void:
	if h_rank==null or h_judgement==null or h_note==null:return
	var label: String=_current_blind_label()
	if label.is_empty():return
	h_candidate_reviews[label]={
		"rank":h_rank.get_item_id(h_rank.selected),
		"judgement":"" if h_judgement.selected<=0 else h_judgement.get_item_text(h_judgement.selected),
		"note":h_note.text,
	}

func _clear_h_form() -> void:
	if h_rank!=null:h_rank.select(0)
	if h_judgement!=null:h_judgement.select(0)
	if h_note!=null:h_note.text=""

func _restore_candidate_review(label: String) -> bool:
	_finish_h_note_edit(false)
	_clear_h_form()
	if label.is_empty() or not h_candidate_reviews.has(label):return false
	var review: Dictionary=h_candidate_reviews[label]
	var rank: int=clampi(int(review.get("rank",0)),0,3);h_rank.select(rank)
	var judgement: String=str(review.get("judgement",""))
	if not judgement.is_empty():
		for index: int in range(h_judgement.item_count):
			if h_judgement.get_item_text(index)==judgement:h_judgement.select(index);break
	h_note.text=str(review.get("note",""))
	return true

func _toggle_h_note_edit() -> void:
	if h_note.editable:_finish_h_note_edit();return
	h_note.editable=true;h_note.focus_mode=Control.FOCUS_ALL;h_note.grab_focus();h_note.caret_column=h_note.text.length();h_note_edit_button.text="Done note"
	h_feedback.text="Editing note — press Enter or click elsewhere before returning to gameplay"

func _finish_h_note_edit(store_review: bool=true) -> void:
	if h_note==null:return
	var was_editable: bool=h_note.editable
	h_note.editable=false;h_note.focus_mode=Control.FOCUS_NONE
	if h_note.has_focus():h_note.release_focus()
	if h_note_edit_button!=null:h_note_edit_button.text="Edit note"
	if store_review and was_editable:_store_current_review()

func _on_h_note_focus_exited() -> void:
	if h_note!=null and h_note.editable:_finish_h_note_edit()

func _refresh_h_view_label() -> void:
	if h_view_menu==null or host==null:return
	var size: Vector2i=host.current_view_size
	h_view_menu.text="View %dx%d (V)"%[size.x,size.y]

func _ensure_h_view_focus() -> void:
	if h_view_focus_valid or host==null:return
	h_view_focus=host.camera_origin+Vector2(host.current_view_size)*0.5
	h_view_focus_valid=true

func _apply_h_camera_focus() -> void:
	if host==null:return
	_ensure_h_view_focus()
	var desired_origin: Vector2=h_view_focus-Vector2(host.current_view_size)*0.5
	host.camera_origin=host.clamped_camera_origin(desired_origin) if host.has_method("clamped_camera_origin") else desired_origin
	if host.has_method("update_worker_frame_state"):host.update_worker_frame_state()
	if host.has_method("update_shader_parameters"):host.update_shader_parameters()

func _pan_h_camera(delta_world: Vector2) -> void:
	if host==null or delta_world==Vector2.ZERO:return
	_ensure_h_view_focus()
	h_view_focus+=delta_world
	_apply_h_camera_focus()

func _apply_h_view_size(size: Vector2i,record_event: bool=true) -> void:
	if host==null or not size in H_VIEW_PRESETS:return
	_ensure_h_view_focus()
	host.view_size_index=H_VIEW_PRESETS.find(size)
	host.current_view_size=size
	_apply_h_camera_focus()
	h_preferred_view_size=size;_refresh_h_view_label()
	if record_event and _ensure_h_session():h_recorder.record_event("view-change",{"width":size.x,"height":size.y,"blind_label":_current_blind_label(),"camera_focus":{"x":h_view_focus.x,"y":h_view_focus.y}})

func _select_h_view(index: int) -> void:
	_finish_h_note_edit()
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate/reset is still applying; wait before changing view";return
	if index<0 or index>=H_VIEW_PRESETS.size():return
	_apply_h_view_size(H_VIEW_PRESETS[index])
	h_feedback.text="View set to %dx%d — camera focus retained across sizes and repeats"%[host.current_view_size.x,host.current_view_size.y]

func _cycle_h_view() -> void:
	var current: int=H_VIEW_PRESETS.find(host.current_view_size)
	_select_h_view((current+1)%H_VIEW_PRESETS.size() if current>=0 else 0)

func _restore_h_view_after_apply() -> void:
	if h_preferred_view_size==Vector2i.ZERO:return
	if not h_view_focus_valid:
		h_view_focus=host.camera_origin+Vector2(host.current_view_size)*0.5
		h_view_focus_valid=true
	host.view_size_index=H_VIEW_PRESETS.find(h_preferred_view_size)
	host.current_view_size=h_preferred_view_size
	_apply_h_camera_focus();_refresh_h_view_label()

func _select_h_phase(index: int) -> void:
	_cancel_arm_next_replay("phase-change")
	_stop_frame_sequence("phase-change")
	_finish_h_note_edit();_store_current_review()
	if not host.water_blind_set.is_empty() or not host.water_active_blind_label.is_empty():h_feedback.text="Finish/reveal the blind set and use Fresh tower before changing test phase";return
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate/reset is still applying; wait before changing phase";return
	var phase_ids: Array[String]=CyberWaterFeelScenarios.ids()
	if index<0 or index>=phase_ids.size():return
	var scenario_id: String=phase_ids[index]
	var policy: Dictionary=host.water_policy_resolved.policy.duplicate(true);policy.scenario_id=scenario_id
	h_view_focus_valid=false
	host.water_experiment_panel.set_draft(policy)
	if not host.water_experiment_panel.submit_draft():h_feedback.text="Test phase could not be applied";return
	h_pending_run_start=true
	if _ensure_h_session():h_recorder.record_event("phase-select",{"scenario_id":scenario_id})
	h_phase_menu.text="Phase: "+scenario_id
	h_feedback.text="Applying test phase "+scenario_id

func _safe_h_metadata(context: Dictionary) -> Dictionary:
	var label: String=str(context.get("water_blind_label",""));var policy: Dictionary=context.get("water_policy",{})
	var metadata: Dictionary={"scenario_id":str(policy.get("scenario_id","")),"seed":int(policy.get("seed",0)),"blind_label":label,"blind":not label.is_empty(),"tick":int(context.get("tick",0)),"paused":bool(host.paused),"recipe_hash":str(context.get("water_recipe_hash","")),"presentation_mode":"four-level-"+str(policy.get("interface_mode","coverage")),"platform":OS.get_name(),"backend":str(host.latest_snapshot.backend_name) if host.latest_snapshot!=null else "unknown","worker_count":int(host.latest_snapshot.scheduler_thread_capacity_hint) if host.latest_snapshot!=null else 0,"render_snapshot_hz":int(host.render_snapshot_hz),"camera":{"x":float(host.camera_origin.x),"y":float(host.camera_origin.y)},"view":{"width":int(host.current_view_size.x),"height":int(host.current_view_size.y)},"water_accounting":context.get("water_accounting",{}).duplicate(true),"action_history":context.get("water_actions",[]).duplicate(true)}
	if label.is_empty():metadata["effective_policy"]=policy.duplicate(true);metadata["effective_policy_hash"]=str(context.get("water_policy_hash",""))
	else:
		var blind_set: Dictionary=_active_blind_set()
		var visible: Dictionary=CyberWaterExperimentBlind.visible_record(blind_set,label,{"scenario_id":metadata.scenario_id,"seed":metadata.seed,"recipe_hash":metadata.recipe_hash,"blind_protocol":CyberWaterExperimentBlind.VERSION,"candidate_family":"water-precision-blind"})
		if visible.get("ok",false):metadata["blind_record"]=visible
	return metadata

func _watch_h_run(context: Dictionary) -> void:
	if not context.get("water_active",false):return
	if not host.water_blind_set.is_empty():h_retained_blind_set=host.water_blind_set.duplicate(true)
	if not host.pending_water_apply.is_empty():return
	var run_key: String="%s|%s|%s"%[str(context.get("water_recipe_hash","")),str(context.get("water_blind_label","")),str(context.get("water_policy_hash",""))]
	if run_key==h_run_key and not h_pending_run_start:return
	if not _ensure_h_session():return
	var restore_pause_pending: bool=h_restore_pause_after_apply
	var restore_pause_value: bool=h_restore_pause_value
	if restore_pause_pending:
		# Armed replay must start recording while the freshly reset run is still paused,
		# then resume. This prevents the first simulation ticks escaping before capture.
		host.paused=true if h_sequence_arm_next_replay else restore_pause_value
		h_restore_pause_after_apply=false
		if host.has_method("update_worker_frame_state"):host.update_worker_frame_state()
	_restore_h_view_after_apply()
	h_run_key=run_key;h_pending_run_start=false
	var safe: Dictionary=_safe_h_metadata(context);h_recorder.begin_run(safe);h_recorder.record_event("candidate-applied",{"scenario_id":safe.scenario_id,"blind_label":safe.blind_label,"tick":safe.tick,"paused":host.paused,"view":safe.view})
	var restored: bool=_restore_candidate_review(str(safe.blind_label))
	h_phase_menu.text="Phase: "+str(safe.scenario_id);_refresh_h_view_label()
	if h_sequence_arm_next_replay:
		h_sequence_arm_next_replay=false
		if h_sequence_arm_button!=null:h_sequence_arm_button.text="Arm next replay"
		_start_frame_sequence()
		if restore_pause_pending:
			host.paused=restore_pause_value
			if host.has_method("update_worker_frame_state"):host.update_worker_frame_state()
		if h_sequence_active:h_feedback.text="Recording from first post-reset frame — %s"%h_recorder.current_sequence_id
		return
	h_feedback.text="%s / %s / %s — ready to observe%s"%[h_recorder.current_run_id,safe.scenario_id,("candidate "+safe.blind_label) if not str(safe.blind_label).is_empty() else "unblinded"," — prior review restored" if restored else ""]

func _queue_pause_restore() -> void:
	h_restore_pause_after_apply=true;h_restore_pause_value=bool(host.paused)

func _toggle_pause() -> void:
	_finish_h_note_edit()
	host.paused=not host.paused
	if _ensure_h_session():h_recorder.record_event("pause" if host.paused else "resume",{"tick":int(host.tower_context.get("tick",0))})
func _single_step() -> void:
	_finish_h_note_edit()
	if _ensure_h_session():h_recorder.record_event("single-step-request",{"tick":int(host.tower_context.get("tick",0))})
	host.tower_command({"step":true})
func _water_reset() -> void:
	_cancel_arm_next_replay("water-reset")
	_stop_frame_sequence("water-reset")
	_finish_h_note_edit()
	h_view_focus_valid=false
	if _ensure_h_session():h_recorder.record_event("water-reset-request",{})
	h_pending_run_start=true;host.water_lab_reset()
func _repeat_test() -> void:
	_stop_frame_sequence("repeat-test")
	_finish_h_note_edit();_store_current_review();_queue_pause_restore()
	var current: int=_blind_index()
	if current>=0 and not h_blind_revealed:_apply_blind_index(current,"repeat-test-request",false);return
	if _ensure_h_session():h_recorder.record_event("repeat-test-request",{"blind_label":"","paused":h_restore_pause_value})
	h_pending_run_start=true;host.water_lab_reset()
func _start_blind() -> void:
	_cancel_arm_next_replay("blind-set-start")
	_stop_frame_sequence("blind-set-start")
	_finish_h_note_edit()
	if not h_retained_blind_set.is_empty() and not h_blind_revealed:h_feedback.text="Reveal the previous blind set before starting another; mapping retained in memory";return
	if not _ensure_h_session():return
	_ensure_h_view_focus();h_preferred_view_size=host.current_view_size
	h_blind_revealed=false;h_blind_sealed=false;h_retained_blind_set.clear();h_candidate_reviews.clear();_clear_h_form();h_pending_run_start=true;_queue_pause_restore();h_recorder.record_event("blind-set-request",{"view":{"width":host.current_view_size.x,"height":host.current_view_size.y},"camera_focus":{"x":h_view_focus.x,"y":h_view_focus.y}})
	if not host.water_lab_prepare_blind():h_pending_run_start=false;h_restore_pause_after_apply=false;h_feedback.text="Blind set was not started; existing controlled run may still be active";return
	h_retained_blind_set=host.water_blind_set.duplicate(true)
	var exported: Dictionary=CyberWaterExperimentBlind.export_metadata(h_retained_blind_set,{"h_session_id":h_recorder.session_id,"varied_field":"mass_bits"})
	if not exported.get("ok",false):h_feedback.text="Blind set exists but recovery metadata failed; reveal/restart before formal capture";return
	var sealed: Dictionary=h_recorder.seal_blind_mapping(exported.metadata);h_blind_sealed=bool(sealed.get("ok",false))
	if h_blind_sealed:h_feedback.text="Blind mapping sealed for crash recovery — applying candidate A"
	else:h_feedback.text="Blind recovery key failed; reveal/restart before formal capture"

func _blind_index() -> int:
	var blind_set: Dictionary=_active_blind_set()
	var blind_labels: Array=blind_set.get("labels",[])
	if blind_labels.is_empty():return -1
	var index: int=blind_labels.find(_current_blind_label())
	if index>=0:return index
	return clampi(int(host.water_blind_index),0,blind_labels.size()-1)

func _apply_blind_index(index: int,event_name: String,queue_pause_restore: bool=true) -> void:
	if event_name!="replay-blind-request" and event_name!="repeat-test-request":_cancel_arm_next_replay("candidate-navigation")
	_stop_frame_sequence("candidate-navigation")
	if h_blind_revealed:h_feedback.text="Blind set already revealed; start a new blind set for further blind judgements";return
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate is still applying; wait for ready feedback before navigating";return
	var blind_set: Dictionary=_active_blind_set();var blind_labels: Array=blind_set.get("labels",[])
	if blind_labels.is_empty():h_feedback.text="No active blind set to navigate";return
	if index<0 or index>=blind_labels.size():h_feedback.text="Blind candidate index is out of range";return
	_store_current_review();_finish_h_note_edit(false)
	if queue_pause_restore:_queue_pause_restore()
	var from_label: String=_current_blind_label();var target_label: String=str(blind_labels[index])
	if _ensure_h_session():h_recorder.record_event(event_name,{"from":from_label,"to":target_label,"paused":h_restore_pause_value if h_restore_pause_after_apply else bool(host.paused)})
	h_pending_run_start=true
	if not host.water_lab_apply_blind(index):h_pending_run_start=false;h_restore_pause_after_apply=false;h_feedback.text="Blind candidate could not be applied";return
	h_feedback.text="Applying candidate %s — capture and navigation locked until worker acknowledgement"%target_label

func _previous_blind() -> void:
	var blind_set: Dictionary=_active_blind_set();var blind_labels: Array=blind_set.get("labels",[]);var current: int=_blind_index()
	if blind_labels.is_empty() or current<0:h_feedback.text="No active blind set to navigate";return
	_apply_blind_index((current-1+blind_labels.size())%blind_labels.size(),"previous-blind-request")
func _replay_blind() -> void:
	var current: int=_blind_index()
	if current<0:h_feedback.text="No active blind candidate to replay";return
	_apply_blind_index(current,"replay-blind-request")
func _next_blind() -> void:
	var blind_set: Dictionary=_active_blind_set();var blind_labels: Array=blind_set.get("labels",[]);var current: int=_blind_index()
	if blind_labels.is_empty() or current<0:h_feedback.text="No active blind set to navigate";return
	_apply_blind_index((current+1)%blind_labels.size(),"next-blind-request")

func _sequence_world_image() -> Image:
	if host==null:return null
	var source: Image=host.get_viewport().get_texture().get_image()
	if source==null or source.is_empty():return null
	var local_content: Rect2=host.view_content_rect()
	var world_rect: Rect2=host.world_view.get_global_rect()
	var top_left: Vector2=world_rect.position+local_content.position
	var x: int=clampi(floori(top_left.x),0,maxi(0,source.get_width()-1))
	var y: int=clampi(floori(top_left.y),0,maxi(0,source.get_height()-1))
	var width: int=clampi(roundi(local_content.size.x),1,source.get_width()-x)
	var height: int=clampi(roundi(local_content.size.y),1,source.get_height()-y)
	var frame: Image=source.get_region(Rect2i(x,y,width,height))
	if frame==null or frame.is_empty():return null
	if frame.get_width()!=host.current_view_size.x or frame.get_height()!=host.current_view_size.y:
		frame.resize(host.current_view_size.x,host.current_view_size.y,Image.INTERPOLATE_NEAREST)
	return frame

func _start_frame_sequence() -> void:
	_finish_h_note_edit();_store_current_review()
	if h_sequence_arm_next_replay:
		h_sequence_arm_next_replay=false
		if h_sequence_arm_button!=null:h_sequence_arm_button.text="Arm next replay"
	if h_sequence_active:return
	if not host.tower_context.get("water_active",false):h_feedback.text="Frame sequence requires an active Water Feel run";return
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate/reset is still applying; wait before recording";return
	if not _ensure_h_session():return
	var metadata: Dictionary=_safe_h_metadata(host.tower_context)
	metadata["frame_sequence_max_frames"]=H_SEQUENCE_MAX_FRAMES
	metadata["capture_note"]="Every distinct rendered world frame; cropped to Water Feel world view and nearest-resampled to the logical H view."
	var result: Dictionary=h_recorder.start_frame_sequence(metadata)
	if not result.get("ok",false):h_feedback.text="Frame sequence error: "+str(result.get("error","unknown error"));return
	h_sequence_active=true;h_sequence_last_render_serial=-1;h_sequence_run_key=h_run_key
	h_sequence_button.text="Stop frame sequence"
	h_feedback.text="Recording %s — every distinct rendered world frame; replay/navigation will stop it automatically"%str(result.sequence_id)

func _stop_frame_sequence(reason: String="user") -> void:
	if not h_sequence_active:return
	var result: Dictionary=h_recorder.finish_frame_sequence(reason)
	h_sequence_active=false;h_sequence_last_render_serial=-1;h_sequence_run_key=""
	if h_sequence_button!=null:h_sequence_button.text="Start frame sequence"
	if result.get("ok",false):h_feedback.text="Saved %s — %d frames / %.1fs wall / estimated missed snapshots %d — %s"%[str(result.sequence_id),int(result.frame_count),float(result.get("wall_duration_sec",0.0)),int(result.get("missed_render_snapshots_estimate",0)),reason]
	else:h_feedback.text="Frame sequence finish error: "+str(result.get("error","unknown error"))

func _toggle_frame_sequence() -> void:
	if h_sequence_active:_stop_frame_sequence("user-stop")
	else:_start_frame_sequence()

func _toggle_arm_next_replay() -> void:
	if h_sequence_active:
		h_feedback.text="Stop the active frame sequence before arming a replay"
		return
	h_sequence_arm_next_replay=not h_sequence_arm_next_replay
	if h_sequence_arm_button!=null:h_sequence_arm_button.text="Armed: next replay" if h_sequence_arm_next_replay else "Arm next replay"
	if _ensure_h_session():h_recorder.record_event("frame-sequence-arm" if h_sequence_arm_next_replay else "frame-sequence-disarm",{"blind_label":_current_blind_label()})
	h_feedback.text="Armed — press R / Replay; recording will begin before the reset run is resumed" if h_sequence_arm_next_replay else "Frame-sequence replay arm cancelled"

func _cancel_arm_next_replay(reason: String) -> void:
	if not h_sequence_arm_next_replay:return
	h_sequence_arm_next_replay=false
	if h_sequence_arm_button!=null:h_sequence_arm_button.text="Arm next replay"
	if _ensure_h_session():h_recorder.record_event("frame-sequence-disarm",{"reason":reason,"blind_label":_current_blind_label()})

func _capture_sequence_frame_if_due() -> void:
	if not h_sequence_active or host.latest_snapshot==null:return
	if h_sequence_run_key!=h_run_key:_stop_frame_sequence("run-changed");return
	var serial: int=int(host.latest_snapshot.render_snapshot_serial)
	if serial<=0 or serial==h_sequence_last_render_serial:return
	var readback_start_usec: int=Time.get_ticks_usec()
	var frame: Image=_sequence_world_image()
	var readback_ms: float=float(Time.get_ticks_usec()-readback_start_usec)/1000.0
	if frame==null or frame.is_empty():_stop_frame_sequence("frame-unavailable");return
	var metadata: Dictionary={
		"tick":int(host.tower_context.get("tick",0)),
		"render_snapshot_serial":serial,
		"readback_ms":readback_ms,
		"camera":{"x":float(host.camera_origin.x),"y":float(host.camera_origin.y)},
		"view":{"width":int(host.current_view_size.x),"height":int(host.current_view_size.y)},
	}
	var result: Dictionary=h_recorder.capture_frame_sequence_frame(frame,metadata)
	if not result.get("ok",false):_stop_frame_sequence("capture-error");return
	h_sequence_last_render_serial=serial
	if int(result.frame_index)>=H_SEQUENCE_MAX_FRAMES:_stop_frame_sequence("frame-cap-%d"%H_SEQUENCE_MAX_FRAMES)

func _capture_h() -> void:
	if not host.tower_context.get("water_active",false):h_feedback.text="Capture requires an active Water Feel run";return
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate/reset is still applying; capture is blocked until acknowledged";return
	_finish_h_note_edit();_store_current_review()
	if not _ensure_h_session():return
	var metadata: Dictionary=_safe_h_metadata(host.tower_context)
	if bool(metadata.blind) and not h_blind_sealed:h_feedback.text="Blind recovery mapping is not safely preserved; reveal/restart before formal capture";return
	metadata["blind_compromised"]=h_blind_revealed and bool(metadata.blind)
	var rank: int=h_rank.get_item_id(h_rank.selected);var judgement: String="" if h_judgement.selected<=0 else h_judgement.get_item_text(h_judgement.selected)
	var result: Dictionary=h_recorder.capture(metadata,host.get_viewport().get_texture().get_image(),rank,judgement,h_note.text.strip_edges())
	if result.get("ok",false):h_feedback.text=str(result.feedback)+" — "+str(result.screenshot)+" — review retained for candidate "+str(metadata.blind_label)+" — breadcrumb copied"
	else:h_feedback.text="H capture error: "+str(result.get("error","unknown error"))

func _request_reveal() -> void:
	_cancel_arm_next_replay("blind-reveal")
	_stop_frame_sequence("blind-reveal")
	_finish_h_note_edit();_store_current_review()
	var blind_set: Dictionary=_active_blind_set()
	if blind_set.is_empty():h_feedback.text="No retained blind set to reveal";return
	if h_blind_revealed:h_feedback.text="This blind set has already been revealed";return
	h_reveal_dialog.popup_centered()
func _reveal_confirmed() -> void:
	_finish_h_note_edit();_store_current_review()
	var blind_set: Dictionary=_active_blind_set()
	if blind_set.is_empty() or not _ensure_h_session():return
	var exported: Dictionary=CyberWaterExperimentBlind.export_metadata(blind_set,{"h_session_id":h_recorder.session_id})
	if not exported.get("ok",false):h_feedback.text="Reveal error: "+str(exported.get("error","invalid blind metadata"));return
	var saved: Dictionary=h_recorder.reveal(exported.metadata)
	if not saved.get("ok",false):h_feedback.text="Reveal save error: "+str(saved.get("error","unknown error"));return
	h_blind_revealed=true;h_retained_blind_set=blind_set.duplicate(true);var parts: Array[String]=[]
	for label: String in blind_set.labels:
		var policy: Dictionary=blind_set.hidden_mapping[label].policy;parts.append("%s=mass%d/coh%d"%[label,int(policy.mass_bits),int(policy.coherence_ticks)])
	var summary: String="Reveal: "+", ".join(parts);h_feedback.text=summary+" — mapping saved; use Fresh tower before a new blind set"
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):DisplayServer.clipboard_set(summary)
func _open_h_folder() -> void:
	_finish_h_note_edit()
	if h_recorder.session_root.is_empty():h_feedback.text="No H session folder yet — start Water Feel or capture first";return
	if OS.shell_open(ProjectSettings.globalize_path(h_recorder.session_root))!=OK:h_feedback.text="Could not open H session folder"

func refresh(active: bool,floor_index: int,context: Dictionary) -> void:
	visible=active
	if not active:
		_stop_frame_sequence("tower-exit")
		_finish_h_note_edit()
		for label: Label in labels:label.visible=false
		return
	_watch_h_run(context)
	if context.get("water_active",false):
		floor_picker.disabled=true;tube_picker.disabled=true
		var blind_active: bool=(not str(context.get("water_blind_label","")).is_empty() or not host.water_blind_set.is_empty());var applying: bool=not host.pending_water_apply.is_empty();var navigation_disabled: bool=not blind_active or h_blind_revealed or applying
		for release_button: Button in release_buttons:release_button.disabled=true;release_button.tooltip_text="Water Feel uses only registered scenario actions"
		blind_button.disabled=blind_active or applying;previous_blind_button.disabled=navigation_disabled;replay_blind_button.disabled=navigation_disabled;next_blind_button.disabled=navigation_disabled;h_reveal_button.disabled=(not blind_active and h_retained_blind_set.is_empty()) or applying;water_policy_button.disabled=blind_active or applying;water_save_button.disabled=blind_active or applying;h_capture_button.disabled=applying or (blind_active and not h_blind_sealed);h_sequence_button.disabled=applying;h_sequence_arm_button.disabled=applying or not blind_active;h_view_menu.disabled=applying;h_phase_menu.disabled=blind_active or applying
		for label: Label in labels:label.visible=false
		var policy: Dictionary=context.get("water_policy",{});var accounting: Dictionary=context.get("water_accounting",{})
		h_phase_menu.text="Phase: "+str(policy.get("scenario_id",""));_refresh_h_view_label()
		info.text="%s\nScenario %s / seed %s / recipe %s / presentation four-level %s"%[str(context.get("status","Water Feel Lab")),str(policy.get("scenario_id","")),str(policy.get("seed","")),str(context.get("water_recipe_hash","")).left(12),str(policy.get("interface_mode","coverage"))]
		info.text+="\nWater integer %s +%s -%s / H audition: arrows pan; Previous / Replay(R) / Next; V changes view without focus drift"%[str(accounting.get("current",0)),str(accounting.get("explicit_source",0)),str(accounting.get("explicit_sink",0))]
		if applying:h_feedback.text="Applying candidate/reset — capture and navigation locked until worker acknowledgement"
		return
	floor_picker.disabled=false;tube_picker.disabled=false;h_capture_button.disabled=true;h_sequence_button.disabled=true;h_sequence_arm_button.disabled=true;previous_blind_button.disabled=true;replay_blind_button.disabled=true;next_blind_button.disabled=true;h_view_menu.disabled=false;h_phase_menu.disabled=not host.water_blind_set.is_empty()
	for release_button: Button in release_buttons:release_button.disabled=false;release_button.tooltip_text=""
	blind_button.disabled=false;water_policy_button.disabled=false;water_save_button.disabled=false;_refresh_h_view_label()
	if shown_floor!=floor_index:
		shown_floor=floor_index;floor_picker.select(floor_index);tube_picker.clear()
		for label: Label in labels:label.queue_free()
		labels.clear();label_points.clear();var index: int=0
		for tube: Array in CyberExperimentTower.tubes(floor_index):
			var name_text: String=host.material_name(int(tube[1]));tube_picker.add_item("%d / %s"%[index+1,name_text+" / "+str(tube[3])]);var label: Label=Label.new();label.text=name_text;label.tooltip_text=str(tube[3]);label.add_theme_font_size_override("font_size",14);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;host.world_view.add_child(label);labels.append(label);label_points.append(Vector2(int(tube[0]),CyberExperimentTower.floor_y(floor_index)+14));index+=1
	info.text="Amber = erasable plug / arrows pan / A,D + Space navigate / 1–6 floor materials. %s"%str(context.get("status","Baseline · starts paused"));var chosen: Array=CyberExperimentTower.tubes(floor_index)[tube_picker.selected];info.text+="\n"+str(chosen[3] if str(chosen[3])!="" else CyberExperimentTower.tubes(floor_index)[maxi(0,tube_picker.selected-1)][3])+" / prepared contents below; amber mixing gates are manually erasable"
	var content: Rect2=host.view_content_rect()
	for i: int in range(labels.size()):var point: Vector2=content.position+(label_points[i]-host.camera_origin)/Vector2(host.current_view_size)*content.size;labels[i].position=point;labels[i].visible=content.has_point(point)
