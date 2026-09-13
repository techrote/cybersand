class_name CyberHGateRecorder
extends RefCounted

const SCHEMA_VERSION: int = 1
const ROOT: String = "user://h-gate"

var session_id: String = ""
var session_root: String = ""
var timeline_path: String = ""
var observation_index: int = 0
var run_index: int = 0
var current_run_id: String = ""
var last_feedback: String = ""

func _utc_stamp() -> String:
	return "%s-%06d" % [Time.get_datetime_string_from_system(true).replace("-","").replace(":","").replace("T","-"),Time.get_ticks_usec()%1000000]
func _ensure_dir(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) == OK
func _write_json(path: String,value: Variant) -> bool:
	var f: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	if f==null:return false
	f.store_string(JSON.stringify(value,"  ")+"\n");return true
func _append_jsonl(path: String,value: Dictionary) -> bool:
	var f: FileAccess=FileAccess.open(path,FileAccess.READ_WRITE)
	if f==null:f=FileAccess.open(path,FileAccess.WRITE)
	if f==null:return false
	f.seek_end();f.store_line(JSON.stringify(value));return true

func start_session(runtime_identity: Dictionary,context: Dictionary={}) -> Dictionary:
	if not session_id.is_empty():return {"ok":true,"session_id":session_id,"root":session_root}
	session_id="H-%s"%_utc_stamp();session_root="%s/%s"%[ROOT,session_id]
	if not _ensure_dir(session_root+"/observations") or not _ensure_dir(session_root+"/reveal"):return {"ok":false,"error":"could not create H-gate session directory"}
	timeline_path=session_root+"/timeline.jsonl"
	var session: Dictionary={"schema_version":SCHEMA_VERSION,"session_id":session_id,"started_utc":Time.get_datetime_string_from_system(true),"platform":OS.get_name(),"godot":Engine.get_version_info().get("string","unknown"),"runtime_identity":runtime_identity.duplicate(true),"context":context.duplicate(true)}
	if not _write_json(session_root+"/session.json",session):return {"ok":false,"error":"could not write H-gate session metadata"}
	record_event("session-start",{"context":context.duplicate(true)});last_feedback="Started %s"%session_id
	return {"ok":true,"session_id":session_id,"root":session_root}
func begin_run(context: Dictionary) -> String:
	if session_id.is_empty():return ""
	run_index+=1;current_run_id="R%03d"%run_index;record_event("run-start",{"run_id":current_run_id,"context":context.duplicate(true)});return current_run_id
func record_event(kind: String,data: Dictionary={}) -> bool:
	if session_id.is_empty():return false
	return _append_jsonl(timeline_path,{"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,"utc":Time.get_datetime_string_from_system(true),"event":kind,"data":data.duplicate(true)})

func capture(metadata: Dictionary,screenshot: Image,rank: int,judgement: String,note: String) -> Dictionary:
	if session_id.is_empty():return {"ok":false,"error":"H-gate session has not started"}
	if screenshot==null or screenshot.is_empty():return {"ok":false,"error":"viewport screenshot was unavailable"}
	observation_index+=1;var oid: String="O%03d"%observation_index;var scenario: String=str(metadata.get("scenario_id","unknown"));var label: String=str(metadata.get("blind_label",""));var suffix: String=scenario+(("-"+label) if not label.is_empty() else "")
	var folder: String="%s/observations/%s-%s"%[session_root,oid,suffix]
	if not _ensure_dir(folder):return {"ok":false,"error":"could not create observation directory"}
	var png: String=folder+"/screenshot.png"
	if screenshot.save_png(png)!=OK:return {"ok":false,"error":"could not save observation screenshot"}
	var sha: String=FileAccess.get_sha256(png);var obs: Dictionary=metadata.duplicate(true)
	obs.merge({"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,"observation_id":oid,"captured_utc":Time.get_datetime_string_from_system(true),"rank":rank,"judgement":judgement,"note":note,"screenshot":"screenshot.png","screenshot_sha256":sha},true)
	if not _write_json(folder+"/observation.json",obs):return {"ok":false,"error":"could not write observation metadata"}
	var crumb: String="%s %s | %s | candidate %s | tick %s | rank %s | %s%s"%[session_id,oid,scenario,label if not label.is_empty() else "unblinded",str(metadata.get("tick","?")),str(rank) if rank>0 else "unranked",judgement if not judgement.is_empty() else "unrated",(" | "+note) if not note.strip_edges().is_empty() else ""]
	var bf: FileAccess=FileAccess.open(folder+"/breadcrumb.txt",FileAccess.WRITE)
	if bf!=null:bf.store_string(crumb+"\n")
	record_event("capture",{"observation_id":oid,"scenario_id":scenario,"blind_label":label,"rank":rank,"judgement":judgement,"note":note,"relative_path":"observations/%s-%s"%[oid,suffix],"screenshot_sha256":sha})
	last_feedback="Captured %s — %s — %s — tick %s"%[oid,scenario,("candidate "+label) if not label.is_empty() else "unblinded",str(metadata.get("tick","?"))]
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):DisplayServer.clipboard_set(crumb)
	return {"ok":true,"observation_id":oid,"root":folder,"breadcrumb":crumb,"feedback":last_feedback}

func reveal(metadata: Dictionary) -> Dictionary:
	if session_id.is_empty():return {"ok":false,"error":"H-gate session has not started"}
	var record: Dictionary={"schema_version":SCHEMA_VERSION,"session_id":session_id,"revealed_utc":Time.get_datetime_string_from_system(true),"blind":metadata.duplicate(true)}
	if not _write_json(session_root+"/reveal/candidate-mapping.json",record):return {"ok":false,"error":"could not write reveal mapping"}
	record_event("blind-reveal",{"labels":metadata.get("labels",[]).duplicate()});last_feedback="Blind mapping revealed and saved for %s"%session_id
	return {"ok":true,"feedback":last_feedback,"path":session_root+"/reveal/candidate-mapping.json"}
