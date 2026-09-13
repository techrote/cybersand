extends SceneTree

class FakeHost:
	extends Control
	var water_blind_set: Dictionary={}
	var latest_snapshot: Variant=null
	var camera_origin: Vector2=Vector2.ZERO
	var current_view_size: Vector2i=Vector2i(480,270)
	var paused: bool=true

var _failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_recorder_files()
	_test_panel_blind_redaction()
	if _failures==0: print("H-gate capture tests passed")
	quit(_failures)

func _test_recorder_files() -> void:
	var recorder: CyberHGateRecorder=CyberHGateRecorder.new()
	var started: Dictionary=recorder.start_session({"source_commit":"test"},{"purpose":"H recorder test"})
	_expect(started.get("ok",false),"session did not start")
	_expect(not recorder.session_id.is_empty(),"session id missing")
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
	var reveal: Dictionary=recorder.reveal({"labels":["A","B"],"hidden_mapping":{"A":{"policy":{"mass_bits":5}},"B":{"policy":{"mass_bits":8}}}})
	_expect(reveal.get("ok",false),"explicit reveal failed")
	_expect(FileAccess.file_exists(recorder.session_root+"/reveal/candidate-mapping.json"),"reveal mapping missing")
	var timeline: String=FileAccess.get_file_as_string(recorder.timeline_path)
	_expect("session-start" in timeline and "run-start" in timeline and "blind-key-sealed" in timeline and "capture" in timeline and "blind-reveal" in timeline,"timeline breadcrumbs incomplete")

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
	_expect(safe.get("blind_record",{}).get("revealed",true)==false,"panel visible blind record was marked revealed")
	panel.free();fake.free()

func _expect(condition: bool,message: String) -> void:
	if condition:return
	_failures+=1
	push_error(message)
