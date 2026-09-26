extends SceneTree

class FakeHost:
	extends Control
	var water_blind_set: Dictionary={}
	var water_active_blind_label: String=""
	var water_blind_index: int=0
	var pending_water_apply: Dictionary={}
	var tower_context: Dictionary={}
	var latest_snapshot: Variant=null
	var camera_origin: Vector2=Vector2.ZERO
	var current_view_size: Vector2i=Vector2i(480,270)
	var view_size_index: int=1
	var render_snapshot_hz: int=60
	var paused: bool=true
	var applied_blind_indices: Array[int]=[]
	var worker_frame_updates: int=0
	var shader_updates: int=0

	func water_runtime_identity() -> Dictionary:
		return {"source_commit":"test"}

	func water_lab_apply_blind(index: int=-1) -> bool:
		if not water_blind_set.get("ok",false):return false
		var labels: Array=water_blind_set.get("labels",[])
		if labels.is_empty():return false
		if index<0:index=(water_blind_index+1)%labels.size()
		if index<0 or index>=labels.size():return false
		water_blind_index=index
		water_active_blind_label=str(labels[index])
		applied_blind_indices.append(index)
		return true

	func clamped_camera_origin(value: Vector2) -> Vector2:
		return Vector2(
			clampf(value.x,0.0,1024.0-float(current_view_size.x)),
			clampf(value.y,0.0,1024.0-float(current_view_size.y))
		)

	func update_worker_frame_state() -> void:
		worker_frame_updates+=1

	func update_shader_parameters() -> void:
		shader_updates+=1

var _failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_recorder_files()
	_test_panel_blind_redaction()
	_test_panel_review_memory_navigation_focus_view_and_repeat()
	if _failures==0: print("H-gate capture tests passed")
	quit(_failures)

func _test_recorder_files() -> void:
	var recorder: CyberHGateRecorder=CyberHGateRecorder.new()
	var started: Dictionary=recorder.start_session({"source_commit":"test"},{"purpose":"H recorder test"})
	_expect(started.get("ok",false),"session did not start")
	_expect(not recorder.session_id.is_empty(),"session id missing")
	var session_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(recorder.session_root+"/session.json"))
	_expect(session_value is Dictionary,"session metadata did not parse")
	if session_value is Dictionary:
		var apparatus: Dictionary=session_value.get("apparatus_identity",{})
		var apparatus_files: Dictionary=apparatus.get("files",{})
		_expect(apparatus_files.size()==CyberHGateRecorder.APPARATUS_FILES.size(),"apparatus fingerprint set incomplete")
		for path: String in CyberHGateRecorder.APPARATUS_FILES:
			_expect(str(apparatus_files.get(path,"missing"))!="missing","apparatus source missing from fingerprint: "+path)
			_expect(str(apparatus_files.get(path,"")).length()==64,"apparatus source fingerprint was not SHA-256: "+path)
	var run_id: String=recorder.begin_run({"scenario_id":"shallow-pool","blind_label":"A"})
	_expect(run_id=="R001","first run id was not R001")
	var sealed: Dictionary=recorder.seal_blind_mapping({"labels":["A","B"],"hidden_mapping":{"A":{"policy":{"mass_bits":5}},"B":{"policy":{"mass_bits":8}}}})
	_expect(sealed.get("ok",false),"blind recovery mapping was not sealed")
	if sealed.get("ok",false):
		var sealed_text: String=FileAccess.get_file_as_string(str(sealed.path))
		_expect(not "mass_bits" in sealed_text,"sealed blind mapping exposed mass precision as plaintext")
		var lines: PackedStringArray=sealed_text.split("\n",false)
		_expect(lines.size()>=2 and lines[0]=="CYBERSAND-H-BLIND-V1","sealed blind mapping header missing")
		if lines.size()>=2:
			var decoded: String=Marshalls.base64_to_raw(lines[1]).get_string_from_utf8()
			_expect("mass_bits" in decoded,"sealed blind mapping did not preserve recoverable metadata")
	var image: Image=Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.1,0.3,0.8,1.0))
	var capture: Dictionary=recorder.capture({"scenario_id":"shallow-pool","blind_label":"A","blind":true,"tick":123,"blind_record":{"ok":true,"label":"A","scenario_id":"shallow-pool","seed":7,"revealed":false}},image,1,"Preferred","good surface")
	_expect(capture.get("ok",false),"capture failed")
	_expect(str(capture.get("observation_id",""))=="O001","first observation id was not O001")
	var folder: String=str(capture.get("root",""));var screenshot_name: String=str(capture.get("screenshot",""))
	_expect(screenshot_name.begins_with("O001-shallow-pool-A"),"screenshot filename lost observation/scenario/candidate identity")
	_expect(FileAccess.file_exists(folder+"/"+screenshot_name),"screenshot missing")
	_expect(FileAccess.file_exists(folder+"/observation.json"),"observation metadata missing")
	_expect(FileAccess.file_exists(folder+"/breadcrumb.txt"),"breadcrumb missing")
	var visible_text: String=FileAccess.get_file_as_string(folder+"/observation.json")
	_expect(not "hidden_mapping" in visible_text,"blind capture leaked hidden mapping")
	_expect(not "mass_bits" in visible_text,"blind capture leaked mass precision")
	var sequence: Dictionary=recorder.start_frame_sequence({"scenario_id":"shallow-pool","blind_label":"A","blind":true,"view":{"width":8,"height":8},"camera":{"x":0.0,"y":0.0}})
	_expect(sequence.get("ok",false),"frame sequence did not start")
	if sequence.get("ok",false):
		var frame1: Dictionary=recorder.capture_frame_sequence_frame(image,{"tick":124,"render_snapshot_serial":7,"readback_ms":1.25,"camera":{"x":0.0,"y":0.0},"view":{"width":8,"height":8}})
		var frame2: Dictionary=recorder.capture_frame_sequence_frame(image,{"tick":126,"render_snapshot_serial":9,"readback_ms":1.50,"camera":{"x":0.0,"y":0.0},"view":{"width":8,"height":8}})
		_expect(frame1.get("ok",false) and frame2.get("ok",false),"frame sequence PNG capture failed")
		_expect(FileAccess.file_exists(str(sequence.root)+"/F000001-t00000124.png"),"first frame-sequence PNG missing")
		_expect(FileAccess.file_exists(str(sequence.root)+"/F000002-t00000126.png"),"second frame-sequence PNG missing")
		_expect(FileAccess.file_exists(str(sequence.root)+"/sequence.json"),"frame-sequence header missing")
		_expect(FileAccess.file_exists(str(sequence.root)+"/frames.jsonl"),"frame-sequence manifest missing")
		var finished: Dictionary=recorder.finish_frame_sequence("test")
		_expect(finished.get("ok",false) and int(finished.get("frame_count",0))==2,"frame sequence did not finish with two frames")
		_expect(int(finished.get("missed_render_snapshots_estimate",-1))==1,"frame sequence did not report the skipped render serial")
		_expect(int(finished.get("max_tick_step",0))==2,"frame sequence did not retain the maximum tick gap")
		_expect(FileAccess.file_exists(str(sequence.root)+"/finished.json"),"frame-sequence finish record missing")
		var finish_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(sequence.root)+"/finished.json"))
		_expect(finish_value is Dictionary and float(finish_value.get("average_readback_ms",0.0))>1.0,"frame-sequence timing diagnostics missing")
	var reveal: Dictionary=recorder.reveal({"labels":["A","B"],"hidden_mapping":{"A":{"policy":{"mass_bits":5}},"B":{"policy":{"mass_bits":8}}}})
	_expect(reveal.get("ok",false),"explicit reveal failed")
	_expect(FileAccess.file_exists(recorder.session_root+"/reveal/candidate-mapping.json"),"reveal mapping missing")
	var timeline: String=FileAccess.get_file_as_string(recorder.timeline_path)
	_expect("session-start" in timeline and "run-start" in timeline and "blind-key-sealed" in timeline and "capture" in timeline and "frame-sequence-start" in timeline and "frame-sequence-finish" in timeline and "blind-reveal" in timeline,"timeline breadcrumbs incomplete")

func _test_panel_blind_redaction() -> void:
	var base: Dictionary=CyberWaterExperimentProfiles.resolve()
	var low: Dictionary=base.policy.duplicate(true);low.mass_bits=3
	var high: Dictionary=base.policy.duplicate(true);high.mass_bits=8
	var blind: Dictionary=CyberWaterExperimentBlind.create([CyberWaterExperimentProfiles.resolve({},{},low),CyberWaterExperimentProfiles.resolve({},{},high)],1234)
	_expect(blind.get("ok",false),"blind fixture did not construct")
	if not blind.get("ok",false): return
	var label: String=str(blind.labels[0])
	var fake: FakeHost=FakeHost.new();fake.water_blind_set=blind
	var panel: CyberTowerPanel=CyberTowerPanel.new();panel.host=fake
	var hidden: Dictionary=blind.hidden_mapping[label]
	var safe: Dictionary=panel._safe_h_metadata({"water_blind_label":label,"water_policy":hidden.policy,"tick":42,"paused":true,"water_recipe_hash":"recipe","water_accounting":{},"water_actions":[]})
	var serialized: String=JSON.stringify(safe)
	_expect(not "hidden_mapping" in serialized,"panel safe metadata leaked hidden mapping")
	_expect(not "mass_bits" in serialized,"panel safe metadata leaked blind mass precision")
	_expect(str(safe.get("blind_label",""))==label,"panel safe metadata lost blind label")
	_expect(int(safe.get("render_snapshot_hz",0))==60,"panel safe metadata lost render snapshot rate")
	_expect(safe.get("blind_record",{}).get("revealed",true)==false,"panel visible blind record was marked revealed")
	panel.free();fake.free()

func _test_panel_review_memory_navigation_focus_view_and_repeat() -> void:
	var fake: FakeHost=FakeHost.new()
	fake.name="FakeHost"
	var layout: VBoxContainer=VBoxContainer.new();layout.name="Layout";fake.add_child(layout)
	root.add_child(fake)
	var panel: CyberTowerPanel=CyberTowerPanel.new();fake.add_child(panel);panel.setup(fake)
	fake.water_blind_set={"ok":true,"labels":["A","B","C"]}
	fake.water_active_blind_label="A";fake.water_blind_index=0
	panel.h_rank.select(2);panel.h_judgement.select(3);panel.h_note.text="fine edge breakup"
	panel._store_current_review()
	panel._clear_h_form()
	_expect(panel._restore_candidate_review("A"),"stored candidate review was not found")
	_expect(panel.h_rank.get_item_id(panel.h_rank.selected)==2,"candidate rank was not restored")
	_expect(panel.h_judgement.get_item_text(panel.h_judgement.selected)=="Acceptable","candidate judgement was not restored")
	_expect(panel.h_note.text=="fine edge breakup","candidate note was not restored")
	panel._toggle_h_note_edit()
	_expect(panel.h_note.editable and panel.h_note.focus_mode==Control.FOCUS_ALL,"explicit note editing did not acquire keyboard focus")
	panel._finish_h_note_edit()
	_expect(not panel.h_note.editable and panel.h_note.focus_mode==Control.FOCUS_NONE,"note field retained gameplay keyboard focus after editing")

	# A full small->large->small view cycle must return to the exact same
	# camera origin even though the large view clamps against world bounds.
	fake.current_view_size=Vector2i(320,180);fake.view_size_index=0;fake.camera_origin=Vector2(12,18)
	panel.h_view_focus=Vector2(172,108);panel.h_view_focus_valid=true
	for view_index: int in [1,2,3,0]:panel._select_h_view(view_index)
	_expect(fake.current_view_size==Vector2i(320,180),"H view cycle did not return to the starting size")
	_expect(fake.camera_origin.is_equal_approx(Vector2(12,18)),"H view cycle drifted the retained camera focus")
	var before_pan: Vector2=fake.camera_origin
	panel._pan_h_camera(Vector2(25,15))
	_expect(fake.camera_origin.is_equal_approx(before_pan+Vector2(25,15)),"H-test camera pan did not move the viewport")
	_expect(fake.worker_frame_updates>0 and fake.shader_updates>0,"H view/pan did not update worker/shader presentation")

	panel._select_h_view(2)
	_expect(fake.current_view_size==Vector2i(640,360),"H view selector did not change view during testing")
	panel._toggle_arm_next_replay()
	_expect(panel.h_sequence_arm_next_replay,"frame sequence did not arm for next replay")
	_expect(panel.h_sequence_arm_button.text=="Armed: next replay","frame sequence arm button did not show armed state")
	_expect(panel.h_preferred_view_size==Vector2i(640,360),"H view selection was not retained for replay")
	panel._next_blind()
	_expect(not panel.h_sequence_arm_next_replay,"candidate navigation did not cancel an armed replay capture")
	_expect(fake.applied_blind_indices.back()==1 and fake.water_active_blind_label=="B","Next blind did not apply candidate B")
	panel.h_pending_run_start=false
	panel._previous_blind()
	_expect(fake.applied_blind_indices.back()==0 and fake.water_active_blind_label=="A","Previous blind did not return to candidate A")
	panel.h_pending_run_start=false
	fake.paused=false
	panel._replay_blind()
	_expect(fake.applied_blind_indices.back()==0 and fake.water_active_blind_label=="A","Replay blind did not reapply candidate A")
	_expect(panel.h_restore_pause_after_apply and not panel.h_restore_pause_value,"Replay did not preserve the pre-repeat playing state")
	panel._clear_h_form()
	_expect(panel._restore_candidate_review("A"),"candidate review was lost after back/forward replay")
	_expect(panel.h_note.text=="fine edge breakup","re-audition did not repopulate the prior comment")
	fake.free()

func _expect(condition: bool,message: String) -> void:
	if condition:return
	_failures+=1
	push_error(message)
