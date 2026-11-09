extends "res://scripts/workbench_agent_client.gd"
## Desktop transport only. Python Runner owns provider/cost/tool policy.
const MAX_CONTROL_BYTES := 32768
const MAX_IPC_FILE_BYTES := 10 * 1024 * 1024
const MAX_IPC_TOTAL_BYTES := 128 * 1024 * 1024
const MAX_READ_PER_FRAME := 256 * 1024
const STARTUP_TIMEOUT_MSEC := 75000
var profile_path := ""
var provider_mode := ""
var allow_live := false
var compute_consent := false
var fixture_mode := false
var fixture_script_path := ""
var acceptance: Dictionary = {}
var fixture_turns: Array = []
var _rate_history_by_endpoint := {}
var _rate_endpoint := ""
var _runner_wait_seconds := 0
var _profile_hash := ""
var _profile: Dictionary = {}
var _authorization: Dictionary = {}
var _retirement_ack: Dictionary = {}
var _runner_epoch := -1
var _runner_pid := 0
var _stdio: FileAccess
var _stderr: FileAccess
var _incoming := PackedByteArray()
var _bridge_root := ""
var _bridge_bytes := 0
var _file_counter := 0
var _native_stop_id := ""
var _native_stop_requested := false
var _finished_receipt: Dictionary = {}
var _closing_deadline := 0
var _runner_failing := false
var _startup_deadline := 0
var _writer := Thread.new()
var _write_mutex := Mutex.new()
var _write_queue: Array[PackedByteArray] = []
var _writer_halt := false
var _writer_error := ""

func python_executable() -> String:
 var selected := OS.get_environment("CYBERSAND_PYTHON")
 return selected if not selected.is_empty() else ("python" if OS.get_name() == "Windows" else "python3")

func runner_script() -> String:
 return ProjectSettings.globalize_path("res://../tools/workbench_api_agent/desktop.py")

func launch_problem(task: String, model: String, scope: Dictionary) -> String:
 if _fake_transport: return super.launch_problem(task,model,scope)
 var problem := super.launch_problem(task,model,scope)
 if not problem.is_empty() and not problem.begins_with("OPENAI_API_KEY is not set"): return problem
 if _runner_pid != 0: return "Previous provider runner is still shutting down. Wait before Start."
 if not FileAccess.file_exists(runner_script()): return "Python provider bridge is missing from this checkout."
 if profile_path.is_empty() or not FileAccess.file_exists(profile_path): return "Choose a trusted profile with Profile… before Start. Key presence alone does not authorize spending."
 var file := FileAccess.open(profile_path,FileAccess.READ)
 if file == null or file.get_length() > 65536: return "Provider profile is unreadable or exceeds 64 KiB."
 var raw := file.get_buffer(file.get_length())
 var parsed := JSON.new()
 if parsed.parse(raw.get_string_from_utf8()) != OK or not parsed.data is Dictionary: return "Provider profile must be a JSON object."
 _profile = parsed.data
 _profile_hash = _hash(raw)
 var provider := str(_profile.get("provider",""))
 if provider not in ["openai_responses","nvidia_chat","ollama_chat","fixture"]: return "Unsupported profile provider. Select OpenAI, NVIDIA, local Ollama or explicit Fixture."
 if not provider_mode.is_empty() and provider_mode != provider: return "Selected provider does not match the chosen profile."
 if provider == "fixture" and not fixture_mode: return "Select Fixture explicitly for keyless scripted qualification."
 if provider != "fixture" and not allow_live: return "Enable Live to authorize inference. Profile funding, credit and rate gates still apply."
 if provider in ["fixture","ollama_chat"] and not compute_consent: return "Explicit local compute consent required. Select Fixture or enable Live, then Start."
 var credentials: Variant = _profile.get("credentials",{})
 if credentials is Dictionary:
  var env_name := str(credentials.get("env",""))
  if not env_name.is_empty() and not _diagnostics.secret_environment_names.has(env_name): _diagnostics.secret_environment_names.append(env_name)
 return ""

func record_diagnostic(kind: String, payload: Variant) -> void:
 if kind == "native_authorization_ack" and payload is Dictionary: _authorization = payload.duplicate(true)
 if kind == "native_retirement_ack" and payload is Dictionary and (_native_stop_requested or not _active):
  _retirement_ack = payload.duplicate(true)
  if not _native_stop_id.is_empty() and not _fake_transport: _send_retirement_result()
  if not _active: _closing_deadline = Time.get_ticks_msec()+2000
 super.record_diagnostic(kind,payload)

func _send(input_items: Array) -> void:
 if _fake_transport:
  super._send(input_items)
  return
 _start_runner()

func _start_runner() -> void:
 _runner_epoch = _epoch
 _rate_endpoint = str(_profile.get("provider",""))+":"+str(_profile.get("endpoint",""))
 _retirement_ack.clear()
 _finished_receipt.clear()
 _native_stop_requested = false
 _native_stop_id = ""
 _closing_deadline = 0
 _bridge_root = ProjectSettings.globalize_path("user://agent-runner/%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()])
 if DirAccess.dir_exists_absolute(_bridge_root) or DirAccess.make_dir_recursive_absolute(_bridge_root.path_join("native")) != OK:
  _runner_fail("Cannot create a fresh private runner session directory.")
  return
 _bridge_bytes = 0
 _file_counter = 0
 var child := OS.execute_with_pipe(python_executable(),PackedStringArray(["-X","utf8","-u",runner_script()]),false)
 if child.is_empty():
  _runner_fail("Could not launch Python. Set CYBERSAND_PYTHON to the qualified interpreter path.")
  return
 _runner_pid = int(child.pid)
 _stdio = child.stdio
 _stderr = child.stderr
 _incoming.clear()
 _writer_halt = false
 _writer_error = ""
 _write_queue.clear()
 _writer = Thread.new()
 if _writer.start(_writer_loop.bind(_stdio)) != OK:
  _runner_fail("Could not start bounded runner pipe writer.")
  return
 var materials: Array = []
 for value: Variant in _scope.get("allowed_materials",[]): materials.append(58 if value == "Hard Wall" else 0)
 var document := {"type":"start","protocol":1,"profile_path":profile_path,"profile_sha256":_profile_hash,
  "bridge_root":_bridge_root,"fixture_mode":fixture_mode,"allow_live":allow_live,"compute_consent":compute_consent,
  "overrides":{"model":_model,"max_model_calls":_active_request_budget,"max_tools":_active_tool_budget,
   "max_output_tokens":_active_token_budget,"request_timeout_seconds":int(_active_request_timeout_seconds),"tokens_per_minute":_active_tokens_per_minute},
  "task":{"prompt":_task_text,"scope":_scope.get("region",{}),"allowed_materials":materials,"protected_regions":_scope.get("protected_regions",[]),"cell_limit":_scope.get("cell_limit",4096)},
  "session":{"task_id":str(_authorization.get("task_id","desktop-%d" % _runner_epoch)),"authorized":_authorization.get("status") == "authorized","authorization_receipt":_authorization.duplicate(true)}}
 if not fixture_script_path.is_empty(): document["fixture_script_path"] = fixture_script_path
 if not acceptance.is_empty(): document.task["acceptance"] = acceptance.duplicate(true)
 if fixture_mode and not fixture_turns.is_empty(): document["fixture_turns"] = fixture_turns.duplicate(true)
 document["rate_history"] = _rate_history_for_start()
 _stage = "Starting Python provider runner"
 _startup_deadline = Time.get_ticks_msec()+STARTUP_TIMEOUT_MSEC
 record_diagnostic("runner.started",{"pid":_runner_pid,"provider":_profile.get("provider"),"profile_sha256":_profile_hash,"bridge_root":_bridge_root})
 _queue_frame(document)

func _writer_loop(pipe: FileAccess) -> void:
 var current := PackedByteArray()
 var offset := 0
 var stalled := 0
 while true:
  _write_mutex.lock()
  var halt := _writer_halt
  if current.is_empty() and not _write_queue.is_empty():
   current = _write_queue.pop_front()
   offset = 0
  _write_mutex.unlock()
  if halt: break
  if current.is_empty():
   OS.delay_msec(2)
   continue
  # One-byte Windows writes are unambiguous; POSIX <=PIPE_BUF is atomic.
  var length := 1 if OS.get_name() == "Windows" else mini(4096,current.size()-offset)
  if pipe.store_buffer(current.slice(offset,offset+length)):
   stalled = 0
   offset += length
   if offset == current.size(): current = PackedByteArray()
  else:
   if stalled == 0: stalled = Time.get_ticks_msec()
   if Time.get_ticks_msec()-stalled > 5000:
    _write_mutex.lock()
    _writer_error = "Provider runner input pipe stalled."
    _write_mutex.unlock()
    break
   OS.delay_msec(2)

func _queue_frame(frame: Dictionary) -> bool:
 var raw := (JSON.stringify(frame)+"\n").to_utf8_buffer()
 if raw.size() > MAX_CONTROL_BYTES:
  _runner_fail("Runner control frame exceeds32KiB; large receipts must use owned files.")
  return false
 _write_mutex.lock()
 if _write_queue.size() >= 16:
  _write_mutex.unlock()
  _runner_fail("Runner control queue capacity exceeded.")
  return false
 _write_queue.append(raw)
 _write_mutex.unlock()
 return true

func _process(delta: float) -> void:
 if _fake_transport:
  super._process(delta)
  return
 if _runner_pid == 0: return
 # Nonblocking pipes: short/empty reads never wait for provider or native work.
 if _stderr != null:
  var error_bytes := _stderr.get_buffer(16384)
  if not error_bytes.is_empty(): record_diagnostic("runner.stderr",{"text":error_bytes.get_string_from_utf8()})
 if _stdio != null: _incoming.append_array(_stdio.get_buffer(MAX_READ_PER_FRAME))
 var frames := 0
 while frames < 16:
  var newline := _incoming.find(10)
  if newline < 0: break
  var raw := _incoming.slice(0,newline).get_string_from_utf8()
  _incoming = _incoming.slice(newline+1)
  if raw.to_utf8_buffer().size() > MAX_CONTROL_BYTES:
   _runner_fail("Oversized runner control line.")
   break
  var parsed := JSON.new()
  if parsed.parse(raw) != OK or not parsed.data is Dictionary:
   _runner_fail("Malformed provider runner frame.")
   break
  _handle_frame(parsed.data)
  frames += 1
 if _incoming.find(10) < 0 and _incoming.size() > MAX_CONTROL_BYTES: _runner_fail("Unterminated runner control frame.")
 _write_mutex.lock()
 var write_error := _writer_error
 _write_mutex.unlock()
 if not write_error.is_empty() and _active: _runner_fail(write_error)
 _check_startup_deadline()
 if _closing_deadline > 0 and Time.get_ticks_msec() >= _closing_deadline and _native_stop_acknowledged():
  _dispose_child(true)
  return
 if not OS.is_process_running(_runner_pid) and _incoming.is_empty():
  var unfinished := _active
  _dispose_child(false)
  if unfinished: _runner_fail("Provider runner exited before final receipt; native Stop requested. Inspect Traffic.")

func _check_startup_deadline() -> void:
 if _active and _startup_deadline > 0 and Time.get_ticks_msec() >= _startup_deadline:
  _startup_deadline = 0
  _runner_fail("Python startup timed out during: " + _stage + ". Native Stop requested; inspect Traffic.")

func _handle_frame(frame: Dictionary) -> void:
 var kind := str(frame.get("type",""))
 if kind == "event":
  var payload: Variant = frame.get("payload",{})
  if frame.has("payload_file"): payload = _load_owned_json(str(frame.payload_file),str(frame.get("payload_sha256","")))
  if payload is Dictionary and payload.get("rate_history") is Array: _accept_rate_history(payload.rate_history)
  if payload is Dictionary and (not _active or _runner_epoch != _epoch):
   payload = payload.duplicate(true)
   payload["stale"] = true
  record_diagnostic(str(frame.get("event","runner.event")),payload)
  if not _active: return
  var event_name := str(frame.get("event",""))
  if event_name == "runner.preflight" and payload is Dictionary:
   var phases := {"waiting_for_start":"Waiting for Python startup","start_received":"Starting checks",
    "validate_profile":"Checking profile","credential_check":"Checking API key",
    "source_check":"Checking local source","funding_check":"Checking spend limits",
    "model_probe":"Checking model access","model_probe_complete":"Model access checked",
    "runner_ready":"Python runner ready"}
   _stage = str(phases.get(str(payload.get("phase","")),payload.get("detail","Checking Python startup")))
  if event_name == "runner.native_session_open": _startup_deadline = 0
  if event_name == "http.request":
   _startup_deadline = 0
   _request_count += 1
   _serial += 1
   _runner_wait_seconds = 0
   _stage = "Waiting for provider response"
  if event_name in ["rate.wait","rate.retry"] and payload is Dictionary:
   _runner_wait_seconds = int(ceil(float(payload.get("wait_seconds",payload.get("delay_seconds",0)))))
   _stage = "Waiting for provider allowance" if event_name == "rate.wait" else "Rate limited; bounded retry"
  if event_name == "http.response" and payload is Dictionary:
   var response: Variant = payload.get("body",{})
   if response is String: response = _parse_json_value(response)
   if response is Dictionary:
    var usage: Variant = response.get("usage")
    if usage is Dictionary:
     var a: Variant = usage.get("input_tokens",usage.get("prompt_tokens"))
     var b: Variant = usage.get("output_tokens",usage.get("completion_tokens"))
     if _safe_integer(a) and _safe_integer(b) and a >= 0 and b >= 0:
      _input_tokens = maxi(0,_input_tokens)+int(a)
      _output_tokens = maxi(0,_output_tokens)+int(b)
     else: _usage_complete = false
    else: _usage_complete = false
  status_changed.emit("runner",_stage)
  return
 if kind == "native_request":
  var id := str(frame.get("id",""))
  var tool := str(frame.get("tool",""))
  _startup_deadline = 0
  if tool == "stop":
   _native_stop_id = id
   if not _retirement_ack.is_empty(): _send_retirement_result()
   elif not _native_stop_requested:
    _native_stop_requested = true
    _stage = "Waiting for native Stop acknowledgement"
    task_finished.emit("runner_requests_native_stop")
   return
  if not _active or _runner_epoch != _epoch:
   record_diagnostic("runner.ignored_stale",frame)
   return
  var args: Variant = frame.get("args")
  if tool == "prepare_edit" and args is Dictionary and args.get("operations") is Array:
   args = args.duplicate(true)
   for op: Variant in args.operations:
    if op is Dictionary and not op.has("replace_only_material"): op["replace_only_material"] = null
  if id.is_empty() or _seen_call_ids.has(id) or not _pending_call_id.is_empty() or tool not in NAMES or not args is Dictionary or not _valid_arguments(tool,args):
   _runner_fail("Invalid, duplicate or out-of-policy runner native request.")
   return
  if _tool_count >= _active_tool_budget:
   _runner_fail("Authorized native tool allowance exhausted.")
   return
  _seen_call_ids[id] = true
  _pending_call_id = id
  _pending_tool = tool
  _tool_count += 1
  _stage = "Native " + tool
  tool_requested.emit(tool,_normalise_arguments(tool,args),_epoch,id)
 elif kind == "finished":
  _startup_deadline = 0
  var report: Variant = frame.get("receipt",{})
  if frame.has("receipt_file"): report = _load_owned_json(str(frame.receipt_file),str(frame.get("receipt_sha256","")))
  _finished_receipt = report if report is Dictionary else {}
  if _finished_receipt.get("rate_history") is Array: _accept_rate_history(_finished_receipt.rate_history)
  record_diagnostic("runner.finished",_finished_receipt)
  if _active and _runner_epoch == _epoch:
   _active = false
   _stage = "Finished" if _finished_receipt.get("stop_acknowledged") == true else "Unconfirmed native Stop"
   var outcome := "completed" if str(_finished_receipt.get("status","")) in ["passed","unverified_native_acceptance"] and _finished_receipt.get("stop_acknowledged") == true else "error"
   status_changed.emit(outcome,str(_finished_receipt.get("reason",_stage)))
   if not _native_stop_requested: task_finished.emit("runner_finished")
  _closing_deadline = Time.get_ticks_msec()+1000
 elif kind in ["error","blocked"]:
  _runner_fail(str(frame.get("reason",frame.get("error","Provider runner blocked. Inspect Traffic/profile funding settings."))))

func _hash(bytes: PackedByteArray) -> String:
 var context := HashingContext.new()
 context.start(HashingContext.HASH_SHA256)
 context.update(bytes)
 return context.finish().hex_encode()

func _write_owned(name: String, bytes: PackedByteArray) -> String:
 if bytes.size() > MAX_IPC_FILE_BYTES or _bridge_bytes+bytes.size() > MAX_IPC_TOTAL_BYTES:
  _runner_fail("Bounded desktop IPC evidence capacity exceeded.")
  return ""
 var file := FileAccess.open(_bridge_root.path_join(name),FileAccess.WRITE)
 if file == null or not file.store_buffer(bytes):
  _runner_fail("Could not write owned desktop IPC evidence.")
  return ""
 file.close()
 _bridge_bytes += bytes.size()
 return _hash(bytes)

func _load_owned_json(relative: String, expected_hash: String) -> Variant:
 if relative.is_absolute_path() or relative.contains("..") or relative.contains("\\") or not (relative.begins_with("events/") or relative.begins_with("reports/") or relative == "receipt.json"):
  _runner_fail("Runner event path escaped its owned session directory.")
  return {}
 var directory := DirAccess.open(_bridge_root)
 if directory == null or directory.is_link("events") or directory.is_link(relative):
  _runner_fail("Runner event file symlink refused.")
  return {}
 var path := _bridge_root.path_join(relative)
 var file := FileAccess.open(path,FileAccess.READ)
 if file == null or file.get_length() > MAX_IPC_FILE_BYTES:
  _runner_fail("Runner event file missing or oversized.")
  return {}
 var bytes := file.get_buffer(file.get_length())
 if _hash(bytes) != expected_hash:
  _runner_fail("Runner event file hash mismatch.")
  return {}
 var parsed := JSON.new()
 if parsed.parse(bytes.get_string_from_utf8()) != OK:
  _runner_fail("Malformed runner event file.")
  return {}
 return parsed.data

func submit_tool_result(epoch: int, call_id: String, receipt: Dictionary) -> bool:
 if _fake_transport: return super.submit_tool_result(epoch,call_id,receipt)
 var stale := not _active or epoch != _epoch or call_id != _pending_call_id or call_id.is_empty()
 record_diagnostic("native.receipt",{"epoch":epoch,"call_id":call_id,"receipt":receipt,"stale":stale})
 if stale: return false
 _file_counter += 1
 var clean := receipt.duplicate(true)
 var image_url := str(clean.get("image_data_url",""))
 clean.erase("image_data_url")
 var name := "native/%06d.json" % _file_counter
 var hash_value := _write_owned(name,JSON.stringify(clean).to_utf8_buffer())
 if hash_value.is_empty(): return false
 var result := {"type":"native_result","id":call_id,"receipt_file":name,"receipt_sha256":hash_value}
 if not image_url.is_empty():
  if not image_url.begins_with("data:image/png;base64,"):
   _runner_fail("Original native image is not a PNG data URL.")
   return false
  var png := Marshalls.base64_to_raw(image_url.trim_prefix("data:image/png;base64,"))
  var png_name := "native/%06d.png" % _file_counter
  var png_hash := _write_owned(png_name,png)
  if png_hash.is_empty(): return false
  result["png_file"] = png_name
  result["png_sha256"] = png_hash
 if _pending_tool == "prepare_edit" and receipt.get("footprint") is Array: proposal_changed.emit(receipt.footprint)
 elif _pending_tool == "apply_edit": proposal_changed.emit([])
 _pending_call_id = ""
 _pending_tool = ""
 return _queue_frame(result)

func _native_stop_acknowledged() -> bool:
 var owner: Variant = _retirement_ack.get("owner_receipt",{})
 return owner is Dictionary and str(owner.get("status","")) == "stopped" and owner.get("no_further_agent_mutations") == true

func _send_retirement_result() -> void:
 if _native_stop_id.is_empty(): return
 _queue_frame({"type":"native_result","id":_native_stop_id,"receipt":_retirement_ack.duplicate(true)})
 _native_stop_id = ""

func stop_task(reason: String = "Human Stop") -> void:
 if _fake_transport:
  super.stop_task(reason)
  return
 _startup_deadline = 0
 if _runner_pid != 0: _queue_frame({"type":"stop","reason":reason})
 super.stop_task(reason)

func _runner_fail(reason: String) -> void:
 if _runner_failing: return
 _runner_failing = true
 record_diagnostic("runner.error",{"reason":reason})
 if _runner_pid != 0: _queue_frame({"type":"stop","reason":"host_transport_failure"})
 if _active: super._fail(reason)
 else: status_changed.emit("error",reason)
 _runner_failing = false

func _dispose_child(kill_owned: bool) -> void:
 _startup_deadline = 0
 var pid := _runner_pid
 _runner_pid = 0
 _write_mutex.lock()
 _writer_halt = true
 _write_mutex.unlock()
 if _writer.is_started(): _writer.wait_to_finish()
 if _stdio != null: _stdio.close()
 if _stderr != null: _stderr.close()
 _stdio = null
 _stderr = null
 if kill_owned and pid > 0 and OS.is_process_running(pid): OS.kill(pid)
 record_diagnostic("runner.process_closed",{"owned_pid":pid,"native_stop_acknowledged":_native_stop_acknowledged()})

func _exit_tree() -> void:
 if _active: stop_task("Panel/scene exited")
 # EOF also causes Python's owned reader to cancel and exit. It is not a native ACK.
 _dispose_child(_native_stop_acknowledged())

func activity_snapshot() -> Dictionary:
 var result := super.activity_snapshot()
 if not _fake_transport:
  result["rate_wait_seconds"] = _runner_wait_seconds
  result["runner_pid"] = _runner_pid
  result["provider"] = _profile.get("provider","")
 return result

func _accept_rate_history(history: Array) -> void:
 if history.size() > 4096:
  _runner_fail("Malformed provider pacing history capacity.")
  return
 var accepted: Array = []
 var now := Time.get_unix_time_from_system()
 for row: Variant in history:
  if not row is Dictionary or not _safe_integer(row.get("tokens")) or int(row.tokens) < 0 or int(row.tokens) > MAX_TOKENS_PER_MINUTE or not (row.get("expires_utc") is int or row.get("expires_utc") is float) or not is_finite(float(row.expires_utc)):
   _runner_fail("Malformed provider pacing history.")
   return
  if float(row.expires_utc) > now:
   accepted.append({"expires_utc":float(row.expires_utc),"tokens":int(row.tokens)})
 _rate_history_by_endpoint[_rate_endpoint] = accepted

func _rate_history_for_start() -> Array:
 var buckets := {}
 var now := Time.get_unix_time_from_system()
 for row: Dictionary in _rate_history_by_endpoint.get(_rate_endpoint,[]):
  if float(row.expires_utc) <= now: continue
  var expiry := int(ceil(float(row.expires_utc)))
  buckets[expiry] = int(buckets.get(expiry,0))+int(row.tokens)
 var result: Array = []
 for expiry: int in buckets:
  result.append({"expires_utc":expiry,"tokens":buckets[expiry]})
 return result
