extends SceneTree

var _failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var recorder: CyberHGateRecorder=CyberHGateRecorder.new()
	var started: Dictionary=recorder.start_session({"source_commit":"test"},{"purpose":"H recorder test"})
	_expect(started.get("ok",false),"session did not start")
	_expect(not recorder.session_id.is_empty(),"session id missing")
	var run_id: String=recorder.begin_run({"scenario_id":"shallow-pool","blind_label":"A"})
	_expect(run_id=="R001","first run id was not R001")
	var image: Image=Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.1,0.3,0.8,1.0))
	var capture: Dictionary=recorder.capture({"scenario_id":"shallow-pool","blind_label":"A","blind":true,"tick":123,"blind_record":{"ok":true,"label":"A","scenario_id":"shallow-pool","seed":7,"revealed":false}},image,1,"Preferred","good surface")
	_expect(capture.get("ok",false),"capture failed")
	_expect(str(capture.get("observation_id",""))=="O001","first observation id was not O001")
	var folder: String=str(capture.get("root",""))
	_expect(FileAccess.file_exists(folder+"/screenshot.png"),"screenshot missing")
	_expect(FileAccess.file_exists(folder+"/observation.json"),"observation metadata missing")
	_expect(FileAccess.file_exists(folder+"/breadcrumb.txt"),"breadcrumb missing")
	var visible_text: String=FileAccess.get_file_as_string(folder+"/observation.json")
	_expect(not "hidden_mapping" in visible_text,"blind capture leaked hidden mapping")
	_expect(not "mass_bits" in visible_text,"blind capture leaked mass precision")
	var reveal: Dictionary=recorder.reveal({"labels":["A","B"],"hidden_mapping":{"A":{"policy":{"mass_bits":5}},"B":{"policy":{"mass_bits":8}}}})
	_expect(reveal.get("ok",false),"explicit reveal failed")
	_expect(FileAccess.file_exists(recorder.session_root+"/reveal/candidate-mapping.json"),"reveal mapping missing")
	var timeline: String=FileAccess.get_file_as_string(recorder.timeline_path)
	_expect("session-start" in timeline and "run-start" in timeline and "capture" in timeline and "blind-reveal" in timeline,"timeline breadcrumbs incomplete")
	if _failures==0: print("H-gate recorder tests passed")
	quit(_failures)

func _expect(condition: bool,message: String) -> void:
	if condition:return
	_failures+=1
	push_error(message)
