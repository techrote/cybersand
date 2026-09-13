class_name CyberTowerPanel
extends VBoxContainer

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
var next_blind_button: Button
var water_policy_button: Button

var h_recorder: CyberHGateRecorder = CyberHGateRecorder.new()
var h_rank: OptionButton
var h_judgement: OptionButton
var h_note: LineEdit
var h_capture_button: Button
var h_reveal_button: Button
var h_open_button: Button
var h_feedback: Label
var h_reveal_dialog: ConfirmationDialog
var h_run_key: String = ""
var h_retained_blind_set: Dictionary = {}
var h_blind_revealed: bool = false
var h_blind_sealed: bool = false
var h_pending_run_start: bool = false

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
	var row: HBoxContainer = HBoxContainer.new();add_child(row)
	floor_picker = OptionButton.new();floor_picker.focus_mode = Control.FOCUS_NONE
	for i: int in range(5): floor_picker.add_item("%d / %s" % [i+1,CyberExperimentTower.FLOORS[i]])
	floor_picker.item_selected.connect(func(i: int) -> void: host.tower_floor_select(i));row.add_child(floor_picker)
	button(row,"Pause / resume",_toggle_pause);button(row,"Single step",_single_step);button(row,"Fresh tower",func() -> void: host.tower_reset());button(row,"Tuning",func() -> void: host.tower_tuning());button(row,"Water Feel",_water_reset)
	water_policy_button=button(row,"Water policy",func() -> void: host.water_lab_open());water_save_button=button(row,"Save Water policy",func() -> void: host.water_lab_save_profile())
	var release: HBoxContainer = HBoxContainer.new();add_child(release)
	tube_picker = OptionButton.new();tube_picker.focus_mode = Control.FOCUS_NONE;tube_picker.item_selected.connect(func(i: int) -> void: host.tower_focus_tube(i));release.add_child(tube_picker)
	release_buttons.append(button(release,"Open plug",func() -> void: host.tower_command({"release":tube_picker.selected})));release_buttons.append(button(release,"Open neighbours",func() -> void: host.tower_command({"release":tube_picker.selected,"adjacent":true})));release_buttons.append(button(release,"Sequence +30 / +90 ticks",func() -> void: host.tower_command({"schedule":tube_picker.selected})))
	blind_button=button(release,"Blind A/B/C",_start_blind);next_blind_button=button(release,"Next blind",_next_blind)
	var h_row: HBoxContainer = HBoxContainer.new();add_child(h_row)
	h_rank=OptionButton.new();h_rank.focus_mode=Control.FOCUS_NONE;h_rank.add_item("Rank —",0);h_rank.add_item("Rank 1",1);h_rank.add_item("Rank 2",2);h_rank.add_item("Rank 3",3);h_row.add_child(h_rank)
	h_judgement=OptionButton.new();h_judgement.focus_mode=Control.FOCUS_NONE
	for value: String in ["Judgement —","Preferred","Good","Acceptable","Marginal","Reject","Anomaly"]: h_judgement.add_item(value)
	h_row.add_child(h_judgement)
	h_note=LineEdit.new();h_note.placeholder_text="Short observation / nuance";h_note.custom_minimum_size.x=280;h_row.add_child(h_note)
	h_capture_button=button(h_row,"Capture H observation",_capture_h);h_reveal_button=button(h_row,"Finish / reveal blind",_request_reveal);h_open_button=button(h_row,"Open H folder",_open_h_folder)
	h_feedback=Label.new();h_feedback.text="H capture idle — append-only; blind settings remain hidden until reveal";h_feedback.add_theme_font_size_override("font_size",13);add_child(h_feedback)
	h_reveal_dialog=ConfirmationDialog.new();h_reveal_dialog.title="Reveal blind candidates?";h_reveal_dialog.dialog_text="Finish your qualitative judgements first. Revealing candidate settings cannot be undone for this H session.";h_reveal_dialog.confirmed.connect(_reveal_confirmed);add_child(h_reveal_dialog)
	info=Label.new();info.add_theme_font_size_override("font_size",14);add_child(info);visible=false
	call_deferred("_neutralize_root_tower_focus")

func _neutralize_root_tower_focus() -> void:
	if host==null or not host.has_node("Layout"):return
	for child: Node in host.get_node("Layout").get_children():
		if child is Button and (child as Button).text=="Experiment Tower / F9":(child as Button).focus_mode=Control.FOCUS_NONE

func _ensure_h_session() -> bool:
	if not h_recorder.session_id.is_empty():return true
	var started: Dictionary=h_recorder.start_session(host.water_runtime_identity(),{"purpose":"CyberSand Water Feel H-gate","water_feel_version":CyberWaterFeelScenarios.VERSION})
	if not started.get("ok",false):h_feedback.text="H capture error: "+str(started.get("error","unknown error"));return false
	h_feedback.text="H session %s started — capture creates screenshot + metadata + breadcrumb"%h_recorder.session_id;return true

func _safe_h_metadata(context: Dictionary) -> Dictionary:
	var label: String=str(context.get("water_blind_label",""));var policy: Dictionary=context.get("water_policy",{})
	var metadata: Dictionary={"scenario_id":str(policy.get("scenario_id","")),"seed":int(policy.get("seed",0)),"blind_label":label,"blind":not label.is_empty(),"tick":int(context.get("tick",0)),"paused":bool(context.get("paused",host.paused)),"recipe_hash":str(context.get("water_recipe_hash","")),"presentation_mode":"four-level-"+str(policy.get("interface_mode","coverage")),"platform":OS.get_name(),"backend":str(host.latest_snapshot.backend_name) if host.latest_snapshot!=null else "unknown","worker_count":int(host.latest_snapshot.scheduler_thread_capacity_hint) if host.latest_snapshot!=null else 0,"camera":{"x":float(host.camera_origin.x),"y":float(host.camera_origin.y)},"view":{"width":int(host.current_view_size.x),"height":int(host.current_view_size.y)},"water_accounting":context.get("water_accounting",{}).duplicate(true),"action_history":context.get("water_actions",[]).duplicate(true)}
	if label.is_empty():metadata["effective_policy"]=policy.duplicate(true);metadata["effective_policy_hash"]=str(context.get("water_policy_hash",""))
	else:
		var blind_set: Dictionary=host.water_blind_set if not host.water_blind_set.is_empty() else h_retained_blind_set
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
	h_run_key=run_key;h_pending_run_start=false
	var safe: Dictionary=_safe_h_metadata(context);h_recorder.begin_run(safe);h_recorder.record_event("candidate-applied",{"scenario_id":safe.scenario_id,"blind_label":safe.blind_label,"tick":safe.tick});h_feedback.text="%s / %s / %s — ready to observe"%[h_recorder.current_run_id,safe.scenario_id,("candidate "+safe.blind_label) if not str(safe.blind_label).is_empty() else "unblinded"]

func _toggle_pause() -> void:
	host.paused=not host.paused
	if _ensure_h_session():h_recorder.record_event("pause" if host.paused else "resume",{"tick":int(host.tower_context.get("tick",0))})
func _single_step() -> void:
	if _ensure_h_session():h_recorder.record_event("single-step-request",{"tick":int(host.tower_context.get("tick",0))})
	host.tower_command({"step":true})
func _water_reset() -> void:
	if _ensure_h_session():h_recorder.record_event("water-reset-request",{})
	h_pending_run_start=true;host.water_lab_reset()
func _start_blind() -> void:
	if not h_retained_blind_set.is_empty() and not h_blind_revealed:h_feedback.text="Reveal the previous blind set before starting another; mapping retained in memory";return
	if not _ensure_h_session():return
	h_blind_revealed=false;h_blind_sealed=false;h_retained_blind_set.clear();h_pending_run_start=true;h_recorder.record_event("blind-set-request",{})
	if not host.water_lab_prepare_blind():h_pending_run_start=false;h_feedback.text="Blind set was not started; existing controlled run may still be active";return
	h_retained_blind_set=host.water_blind_set.duplicate(true)
	var exported: Dictionary=CyberWaterExperimentBlind.export_metadata(h_retained_blind_set,{"h_session_id":h_recorder.session_id,"varied_field":"mass_bits"})
	if not exported.get("ok",false):h_feedback.text="Blind set exists but recovery metadata failed; reveal/restart before formal capture";return
	var sealed: Dictionary=h_recorder.seal_blind_mapping(exported.metadata);h_blind_sealed=bool(sealed.get("ok",false))
	if h_blind_sealed:h_feedback.text="Blind mapping sealed for crash recovery — applying candidate A"
	else:h_feedback.text="Blind recovery key failed; reveal/restart before formal capture"
func _next_blind() -> void:
	if h_blind_revealed:h_feedback.text="Blind set already revealed; start a new blind set for further blind judgements";return
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate is still applying; wait for ready feedback before advancing";return
	if _ensure_h_session():h_recorder.record_event("next-blind-request",{"from":str(host.water_active_blind_label)})
	h_pending_run_start=true
	if not host.water_lab_apply_blind():h_pending_run_start=false;h_feedback.text="No active blind set to advance"

func _capture_h() -> void:
	if not host.tower_context.get("water_active",false):h_feedback.text="Capture requires an active Water Feel run";return
	if not host.pending_water_apply.is_empty():h_feedback.text="Candidate/reset is still applying; capture is blocked until acknowledged";return
	if not _ensure_h_session():return
	var metadata: Dictionary=_safe_h_metadata(host.tower_context)
	if bool(metadata.blind) and not h_blind_sealed:h_feedback.text="Blind recovery mapping is not safely preserved; reveal/restart before formal capture";return
	metadata["blind_compromised"]=h_blind_revealed and bool(metadata.blind)
	var rank: int=h_rank.get_item_id(h_rank.selected);var judgement: String="" if h_judgement.selected<=0 else h_judgement.get_item_text(h_judgement.selected)
	var result: Dictionary=h_recorder.capture(metadata,host.get_viewport().get_texture().get_image(),rank,judgement,h_note.text.strip_edges())
	if result.get("ok",false):h_feedback.text=str(result.feedback)+" — "+str(result.screenshot)+" — breadcrumb copied";h_rank.select(0);h_judgement.select(0);h_note.clear()
	else:h_feedback.text="H capture error: "+str(result.get("error","unknown error"))

func _request_reveal() -> void:
	var blind_set: Dictionary=host.water_blind_set if not host.water_blind_set.is_empty() else h_retained_blind_set
	if blind_set.is_empty():h_feedback.text="No retained blind set to reveal";return
	if h_blind_revealed:h_feedback.text="This blind set has already been revealed";return
	h_reveal_dialog.popup_centered()
func _reveal_confirmed() -> void:
	var blind_set: Dictionary=host.water_blind_set if not host.water_blind_set.is_empty() else h_retained_blind_set
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
	if h_recorder.session_root.is_empty():h_feedback.text="No H session folder yet — start Water Feel or capture first";return
	if OS.shell_open(ProjectSettings.globalize_path(h_recorder.session_root))!=OK:h_feedback.text="Could not open H session folder"

func refresh(active: bool,floor_index: int,context: Dictionary) -> void:
	visible=active
	if not active:
		for label: Label in labels:label.visible=false
		return
	_watch_h_run(context)
	if context.get("water_active",false):
		floor_picker.disabled=true;tube_picker.disabled=true
		var blind_active: bool=(not str(context.get("water_blind_label","")).is_empty() or not host.water_blind_set.is_empty());var applying: bool=not host.pending_water_apply.is_empty()
		for release_button: Button in release_buttons:release_button.disabled=true;release_button.tooltip_text="Water Feel uses only registered scenario actions"
		blind_button.disabled=blind_active or applying;next_blind_button.disabled=not blind_active or h_blind_revealed or applying;h_reveal_button.disabled=(not blind_active and h_retained_blind_set.is_empty()) or applying;water_policy_button.disabled=blind_active or applying;water_save_button.disabled=blind_active or applying;h_capture_button.disabled=applying or (blind_active and not h_blind_sealed)
		for label: Label in labels:label.visible=false
		var policy: Dictionary=context.get("water_policy",{});var accounting: Dictionary=context.get("water_accounting",{})
		info.text="%s\nScenario %s / seed %s / recipe %s / presentation four-level %s"%[str(context.get("status","Water Feel Lab")),str(policy.get("scenario_id","")),str(policy.get("seed","")),str(context.get("water_recipe_hash","")).left(12),str(policy.get("interface_mode","coverage"))]
		info.text+="\nWater integer %s +%s -%s / H capture records screenshot + safe metadata; ordinary Tower releases disabled"%[str(accounting.get("current",0)),str(accounting.get("explicit_source",0)),str(accounting.get("explicit_sink",0))]
		if applying:h_feedback.text="Applying candidate/reset — capture and candidate advance locked until worker acknowledgement"
		return
	floor_picker.disabled=false;tube_picker.disabled=false;h_capture_button.disabled=true
	for release_button: Button in release_buttons:release_button.disabled=false;release_button.tooltip_text=""
	blind_button.disabled=false;next_blind_button.disabled=true;water_policy_button.disabled=false;water_save_button.disabled=false
	if shown_floor!=floor_index:
		shown_floor=floor_index;floor_picker.select(floor_index);tube_picker.clear()
		for label: Label in labels:label.queue_free()
		labels.clear();label_points.clear();var index: int=0
		for tube: Array in CyberExperimentTower.tubes(floor_index):
			var name_text: String=host.material_name(int(tube[1]));tube_picker.add_item("%d / %s"%[index+1,name_text+" / "+str(tube[3])]);var label: Label=Label.new();label.text=name_text;label.tooltip_text=str(tube[3]);label.add_theme_font_size_override("font_size",14);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;host.world_view.add_child(label);labels.append(label);label_points.append(Vector2(int(tube[0]),CyberExperimentTower.floor_y(floor_index)+14));index+=1
	info.text="Amber = erasable plug / arrows pan / A,D + Space navigate / 1–6 floor materials. %s"%str(context.get("status","Baseline · starts paused"));var chosen: Array=CyberExperimentTower.tubes(floor_index)[tube_picker.selected];info.text+="\n"+str(chosen[3] if str(chosen[3])!="" else CyberExperimentTower.tubes(floor_index)[maxi(0,tube_picker.selected-1)][3])+" / prepared contents below; amber mixing gates are manually erasable"
	var content: Rect2=host.view_content_rect()
	for i: int in range(labels.size()):var point: Vector2=content.position+(label_points[i]-host.camera_origin)/Vector2(host.current_view_size)*content.size;labels[i].position=point;labels[i].visible=content.has_point(point)
