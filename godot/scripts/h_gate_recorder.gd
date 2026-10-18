class_name CyberHGateRecorder
extends RefCounted

const SCHEMA_VERSION: int = 1
const ROOT: String = "user://h-gate"
const APPARATUS_FILES: Array[String] = [
	"res://scripts/h_gate_recorder.gd",
	"res://scripts/tower_panel.gd",
	"res://scripts/main.gd",
	"res://scripts/water_experiment_blind.gd",
	"res://scripts/water_experiment_profiles.gd",
	"res://scripts/water_feel_scenarios.gd",
]

var session_id: String = ""
var session_root: String = ""
var timeline_path: String = ""
var observation_index: int = 0
var run_index: int = 0
var blind_set_index: int = 0
var sequence_index: int = 0
var sequence_frame_index: int = 0
var current_sequence_id: String = ""
var current_sequence_root: String = ""
var current_sequence_frames_path: String = ""
var sequence_started_usec: int = 0
var sequence_first_tick: int = -1
var sequence_last_tick: int = -1
var sequence_first_render_serial: int = -1
var sequence_last_render_serial: int = -1
var sequence_missed_render_snapshots: int = 0
var sequence_max_render_serial_step: int = 0
var sequence_max_tick_step: int = 0
var sequence_total_readback_ms: float = 0.0
var sequence_max_readback_ms: float = 0.0
var sequence_total_write_ms: float = 0.0
var sequence_max_write_ms: float = 0.0
var current_run_id: String = ""
var last_feedback: String = ""

func _utc_stamp() -> String:
	return "%s-%06d" % [Time.get_datetime_string_from_system(true).replace("-","").replace(":","").replace("T","-"),Time.get_ticks_usec()%1000000]
func _ensure_dir(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) == OK
func _write_text(path: String,text: String) -> bool:
	var f: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	if f==null:return false
	f.store_string(text);return true
func _write_json(path: String,value: Variant) -> bool:
	return _write_text(path,JSON.stringify(value,"  ")+"\n")
func _append_jsonl(path: String,value: Dictionary) -> bool:
	var f: FileAccess=FileAccess.open(path,FileAccess.READ_WRITE)
	if f==null:f=FileAccess.open(path,FileAccess.WRITE)
	if f==null:return false
	f.seek_end();f.store_line(JSON.stringify(value));return true
func _apparatus_identity() -> Dictionary:
	var files: Dictionary={}
	for path: String in APPARATUS_FILES:
		files[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return {"schema_version":SCHEMA_VERSION,"files":files}

func start_session(runtime_identity: Dictionary,context: Dictionary={}) -> Dictionary:
	if not session_id.is_empty():return {"ok":true,"session_id":session_id,"root":session_root}
	var base_id: String="H-%s"%_utc_stamp();session_id=base_id;var suffix: int=0
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("%s/%s"%[ROOT,session_id])):
		suffix+=1;session_id="%s-%02d"%[base_id,suffix]
	session_root="%s/%s"%[ROOT,session_id]
	if not _ensure_dir(session_root+"/observations") or not _ensure_dir(session_root+"/reveal"):return {"ok":false,"error":"could not create H-gate session directory"}
	timeline_path=session_root+"/timeline.jsonl"
	var session: Dictionary={"schema_version":SCHEMA_VERSION,"session_id":session_id,"started_utc":Time.get_datetime_string_from_system(true),"platform":OS.get_name(),"godot":Engine.get_version_info().get("string","unknown"),"runtime_identity":runtime_identity.duplicate(true),"apparatus_identity":_apparatus_identity(),"context":context.duplicate(true)}
	if not _write_json(session_root+"/session.json",session):return {"ok":false,"error":"could not write H-gate session metadata"}
	record_event("session-start",{"context":context.duplicate(true)});last_feedback="Started %s"%session_id
	return {"ok":true,"session_id":session_id,"root":session_root}
func begin_run(context: Dictionary) -> String:
	if session_id.is_empty():return ""
	run_index+=1;current_run_id="R%03d"%run_index;record_event("run-start",{"run_id":current_run_id,"context":context.duplicate(true)});return current_run_id
func record_event(kind: String,data: Dictionary={}) -> bool:
	if session_id.is_empty():return false
	return _append_jsonl(timeline_path,{"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,"utc":Time.get_datetime_string_from_system(true),"event":kind,"data":data.duplicate(true)})

func seal_blind_mapping(metadata: Dictionary) -> Dictionary:
	if session_id.is_empty():return {"ok":false,"error":"H-gate session has not started"}
	blind_set_index+=1;var blind_id: String="B%03d"%blind_set_index
	var raw: PackedByteArray=JSON.stringify(metadata).to_utf8_buffer();var encoded: String=Marshalls.raw_to_base64(raw)
	var relative: String="reveal/.sealed-%s.b64"%blind_id;var path: String=session_root+"/"+relative
	if not _write_text(path,"CYBERSAND-H-BLIND-V1\n"+encoded+"\n"):return {"ok":false,"error":"could not preserve sealed blind mapping"}
	var sha: String=FileAccess.get_sha256(path);record_event("blind-key-sealed",{"blind_id":blind_id,"relative_path":relative,"sha256":sha})
	return {"ok":true,"blind_id":blind_id,"path":path,"sha256":sha}

func capture(metadata: Dictionary,screenshot: Image,rank: int,judgement: String,note: String) -> Dictionary:
	if session_id.is_empty():return {"ok":false,"error":"H-gate session has not started"}
	if screenshot==null or screenshot.is_empty():return {"ok":false,"error":"viewport screenshot was unavailable"}
	observation_index+=1;var oid: String="O%03d"%observation_index;var scenario: String=str(metadata.get("scenario_id","unknown"));var label: String=str(metadata.get("blind_label",""));var suffix: String=scenario+(("-"+label) if not label.is_empty() else "")
	var stem: String="%s-%s"%[oid,suffix];var folder: String="%s/observations/%s"%[session_root,stem]
	if not _ensure_dir(folder):return {"ok":false,"error":"could not create observation directory"}
	var screenshot_name: String=stem+".png";var png: String=folder+"/"+screenshot_name
	if screenshot.save_png(png)!=OK:return {"ok":false,"error":"could not save observation screenshot"}
	var sha: String=FileAccess.get_sha256(png);var obs: Dictionary=metadata.duplicate(true)
	obs.merge({"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,"observation_id":oid,"captured_utc":Time.get_datetime_string_from_system(true),"rank":rank,"judgement":judgement,"note":note,"screenshot":screenshot_name,"screenshot_sha256":sha},true)
	if not _write_json(folder+"/observation.json",obs):return {"ok":false,"error":"could not write observation metadata"}
	var crumb: String="%s %s | %s | candidate %s | tick %s | rank %s | %s%s"%[session_id,oid,scenario,label if not label.is_empty() else "unblinded",str(metadata.get("tick","?")),str(rank) if rank>0 else "unranked",judgement if not judgement.is_empty() else "unrated",(" | "+note) if not note.strip_edges().is_empty() else ""]
	if not _write_text(folder+"/breadcrumb.txt",crumb+"\n"):return {"ok":false,"error":"could not write observation breadcrumb"}
	record_event("capture",{"observation_id":oid,"scenario_id":scenario,"blind_label":label,"rank":rank,"judgement":judgement,"note":note,"relative_path":"observations/"+stem,"screenshot":screenshot_name,"screenshot_sha256":sha})
	last_feedback="Captured %s — %s — %s — tick %s"%[oid,scenario,("candidate "+label) if not label.is_empty() else "unblinded",str(metadata.get("tick","?"))]
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):DisplayServer.clipboard_set(crumb)
	return {"ok":true,"observation_id":oid,"root":folder,"screenshot":screenshot_name,"breadcrumb":crumb,"feedback":last_feedback}

func start_frame_sequence(metadata: Dictionary) -> Dictionary:
	if session_id.is_empty():return {"ok":false,"error":"H-gate session has not started"}
	if not current_sequence_id.is_empty():return {"ok":false,"error":"frame sequence is already active"}
	sequence_index+=1;sequence_frame_index=0
	sequence_started_usec=Time.get_ticks_usec()
	sequence_first_tick=-1;sequence_last_tick=-1
	sequence_first_render_serial=-1;sequence_last_render_serial=-1
	sequence_missed_render_snapshots=0;sequence_max_render_serial_step=0;sequence_max_tick_step=0
	sequence_total_readback_ms=0.0;sequence_max_readback_ms=0.0
	sequence_total_write_ms=0.0;sequence_max_write_ms=0.0
	current_sequence_id="S%03d"%sequence_index
	var scenario: String=str(metadata.get("scenario_id","unknown"))
	var label: String=str(metadata.get("blind_label",""))
	var suffix: String=scenario+(("-"+label) if not label.is_empty() else "")
	current_sequence_root="%s/sequences/%s-%s"%[session_root,current_sequence_id,suffix]
	if not _ensure_dir(current_sequence_root):current_sequence_id="";current_sequence_root="";return {"ok":false,"error":"could not create frame-sequence directory"}
	current_sequence_frames_path=current_sequence_root+"/frames.jsonl"
	var header: Dictionary=metadata.duplicate(true)
	header.merge({"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,"sequence_id":current_sequence_id,"started_utc":Time.get_datetime_string_from_system(true),"capture_mode":"distinct-render-frame-png","frame_images":"cropped-world-view-resampled-nearest-to-logical-view"},true)
	if not _write_json(current_sequence_root+"/sequence.json",header):
		current_sequence_id="";current_sequence_root="";current_sequence_frames_path=""
		return {"ok":false,"error":"could not write frame-sequence metadata"}
	record_event("frame-sequence-start",{"sequence_id":current_sequence_id,"scenario_id":scenario,"blind_label":label,"relative_path":current_sequence_root.trim_prefix(session_root+"/")})
	return {"ok":true,"sequence_id":current_sequence_id,"root":current_sequence_root}

func capture_frame_sequence_frame(frame: Image,metadata: Dictionary) -> Dictionary:
	if current_sequence_id.is_empty():return {"ok":false,"error":"no frame sequence is active"}
	if frame==null or frame.is_empty():return {"ok":false,"error":"frame image was unavailable"}
	sequence_frame_index+=1
	var tick: int=int(metadata.get("tick",0))
	var render_serial: int=int(metadata.get("render_snapshot_serial",0))
	var readback_ms: float=float(metadata.get("readback_ms",0.0))
	if sequence_first_tick<0:sequence_first_tick=tick
	if sequence_first_render_serial<0:sequence_first_render_serial=render_serial
	if sequence_last_tick>=0:sequence_max_tick_step=maxi(sequence_max_tick_step,tick-sequence_last_tick)
	if sequence_last_render_serial>=0:
		var serial_step: int=render_serial-sequence_last_render_serial
		sequence_max_render_serial_step=maxi(sequence_max_render_serial_step,serial_step)
		if serial_step>1:sequence_missed_render_snapshots+=serial_step-1
	sequence_last_tick=tick;sequence_last_render_serial=render_serial
	sequence_total_readback_ms+=readback_ms;sequence_max_readback_ms=maxf(sequence_max_readback_ms,readback_ms)
	var frame_name: String="F%06d-t%08d.png"%[sequence_frame_index,tick]
	var frame_path: String=current_sequence_root+"/"+frame_name
	var write_start_usec: int=Time.get_ticks_usec()
	if frame.save_png(frame_path)!=OK:return {"ok":false,"error":"could not save frame-sequence PNG"}
	var write_ms: float=float(Time.get_ticks_usec()-write_start_usec)/1000.0
	sequence_total_write_ms+=write_ms;sequence_max_write_ms=maxf(sequence_max_write_ms,write_ms)
	var sha: String=FileAccess.get_sha256(frame_path)
	var row: Dictionary={"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,"sequence_id":current_sequence_id,"frame_index":sequence_frame_index,"utc":Time.get_datetime_string_from_system(true),"tick":tick,"render_snapshot_serial":render_serial,"frame":frame_name,"sha256":sha,"readback_ms":readback_ms,"png_write_ms":write_ms,"camera":metadata.get("camera",{}).duplicate(true),"view":metadata.get("view",{}).duplicate(true)}
	if not _append_jsonl(current_sequence_frames_path,row):return {"ok":false,"error":"could not append frame-sequence metadata"}
	return {"ok":true,"frame_index":sequence_frame_index,"frame":frame_name,"sha256":sha}

func finish_frame_sequence(reason: String="user") -> Dictionary:
	if current_sequence_id.is_empty():return {"ok":false,"error":"no frame sequence is active"}
	var sequence_id: String=current_sequence_id
	var root: String=current_sequence_root
	var wall_duration_sec: float=float(Time.get_ticks_usec()-sequence_started_usec)/1000000.0 if sequence_started_usec>0 else 0.0
	var summary: Dictionary={
		"schema_version":SCHEMA_VERSION,"session_id":session_id,"run_id":current_run_id,
		"sequence_id":sequence_id,"finished_utc":Time.get_datetime_string_from_system(true),
		"frame_count":sequence_frame_index,"reason":reason,"wall_duration_sec":wall_duration_sec,
		"first_tick":sequence_first_tick,"last_tick":sequence_last_tick,
		"simulation_tick_span":maxi(0,sequence_last_tick-sequence_first_tick) if sequence_first_tick>=0 and sequence_last_tick>=0 else 0,
		"first_render_snapshot_serial":sequence_first_render_serial,"last_render_snapshot_serial":sequence_last_render_serial,
		"missed_render_snapshots_estimate":sequence_missed_render_snapshots,
		"max_render_snapshot_serial_step":sequence_max_render_serial_step,
		"max_tick_step":sequence_max_tick_step,
		"average_readback_ms":sequence_total_readback_ms/float(sequence_frame_index) if sequence_frame_index>0 else 0.0,
		"max_readback_ms":sequence_max_readback_ms,
		"average_png_write_ms":sequence_total_write_ms/float(sequence_frame_index) if sequence_frame_index>0 else 0.0,
		"max_png_write_ms":sequence_max_write_ms,
	}
	_write_json(root+"/finished.json",summary)
	record_event("frame-sequence-finish",{"sequence_id":sequence_id,"frame_count":sequence_frame_index,"reason":reason,"relative_path":root.trim_prefix(session_root+"/")})
	current_sequence_id="";current_sequence_root="";current_sequence_frames_path="";sequence_frame_index=0
	return {"ok":true,"sequence_id":sequence_id,"root":root,"frame_count":int(summary.frame_count),"wall_duration_sec":wall_duration_sec,"missed_render_snapshots_estimate":sequence_missed_render_snapshots,"max_tick_step":sequence_max_tick_step}

func reveal(metadata: Dictionary) -> Dictionary:
	if session_id.is_empty():return {"ok":false,"error":"H-gate session has not started"}
	var record: Dictionary={"schema_version":SCHEMA_VERSION,"session_id":session_id,"revealed_utc":Time.get_datetime_string_from_system(true),"blind":metadata.duplicate(true)}
	if not _write_json(session_root+"/reveal/candidate-mapping.json",record):return {"ok":false,"error":"could not write reveal mapping"}
	record_event("blind-reveal",{"labels":metadata.get("labels",[]).duplicate()});last_feedback="Blind mapping revealed and saved for %s"%session_id
	return {"ok":true,"feedback":last_feedback,"path":session_root+"/reveal/candidate-mapping.json"}
