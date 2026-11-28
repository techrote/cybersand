extends RefCounted
## One finite, value-only provider preparation job. The worker owns no Node,
## native adapter, filesystem writer or mutable provider configuration.
const Redactor = preload("res://scripts/art_redaction.gd")
static var _pending: Dictionary = {} # Main-thread registry survives owner free.
var request_id := 0
var direction := "response"
var provider_name := ""
var request_body: Dictionary = {}
var request_url := ""
var request_key := "" # Main-thread dispatch only; never read by the worker.
var request_seconds := 0.0
var conversation_turns: Array = []
var conversation_last_result := ""
var conversation_bytes := 0
var preparation_error := ""
var encoded_payload := ""
var encoded_payload_bytes := PackedByteArray()
var transport_result := 0
var http_code := 0
var headers := PackedStringArray()
var bytes := PackedByteArray()
var secrets_snapshot: Array[String] = []
var timing: Dictionary = {} # Main-thread receipt; worker never reads/writes it.
var received_usec := 0
var owner: WeakRef # Read only by the deferred main-thread reaper.
var task_id := -1
var asynchronous := false
var reaped := false
var sanitized: Dictionary = {}
var sanitized_body := ""
var encoded_data := ""
var encoded_data_bytes := PackedByteArray()
var data: Dictionary = {}
var valid_object := false
var decoded := {"text":"","error":""}
var encoded_assistant := ""
var encoded_conversation := ""
var encoded_assistant_bytes := PackedByteArray()
var encoded_conversation_bytes := PackedByteArray()
var metrics: Dictionary = {}
var _cancel_mutex := Mutex.new()
var _cancelled := false

static func decode(provider: String, data: Dictionary) -> Dictionary:
	if data.has("error") and data.error != null: return {"text":"","error":JSON.stringify(data.error)}
	var text := ""
	var error := ""
	if provider == "OpenAI":
		var output: Variant = data.get("output",[])
		if not output is Array: return {"text":"","error":"Malformed Responses output; inspect Traffic."}
		for item: Variant in output:
			if not item is Dictionary or not item.get("content",[]) is Array: continue
			for block: Variant in item.get("content",[]):
				if not block is Dictionary: continue
				if block.get("type")=="output_text": text += str(block.get("text",""))
				elif block.get("type")=="refusal": error = str(block.get("refusal","Provider refused."))
		if data.get("status")=="incomplete": error = "Response incomplete: "+JSON.stringify(data.get("incomplete_details",{}))+". Increase Toks if output was truncated; nothing drawn."
	else:
		var choices: Variant = data.get("choices",[])
		if not choices is Array: return {"text":"","error":"Malformed Chat Completions choices; inspect Traffic."}
		if not choices.is_empty() and choices[0] is Dictionary:
			var message: Variant = choices[0].get("message",{})
			if not message is Dictionary: return {"text":"","error":"Malformed assistant message; inspect Traffic."}
			var content: Variant = message.get("content","")
			if content is String: text = content
			elif content is Array:
				for block: Variant in content:
					if block is Dictionary: text += str(block.get("text",""))
			if choices[0].get("finish_reason")=="length": error = "Response reached Toks limit; nothing drawn. Increase Toks and retry."
	if text.is_empty() and error.is_empty(): error = "Provider returned no text. Inspect Traffic for refusal, reasoning usage or provider details."
	return {"text":text,"error":error}

static func pending_count() -> int:
	return _pending.size()

func cancel() -> void:
	_cancel_mutex.lock()
	_cancelled = true
	_cancel_mutex.unlock()

func is_cancelled() -> bool:
	_cancel_mutex.lock()
	var result := _cancelled
	_cancel_mutex.unlock()
	return result

func start(provider: Node) -> void:
	owner = weakref(provider)
	asynchronous = true
	task_id = WorkerThreadPool.add_task(_run,false,"Art "+direction+" preparation")
	_pending[task_id] = self

func prepare_inline() -> void:
	var began := Time.get_ticks_usec()
	_prepare_values()
	metrics.total_usec = Time.get_ticks_usec()-began
	reaped = true

func _run() -> void:
	var began := Time.get_ticks_usec()
	_prepare_values()
	metrics.total_usec = Time.get_ticks_usec()-began
	# The registry holds this RefCounted until this deferred MAIN-thread method
	# reaps the completed task. No worker callback touches the provider/World.
	_reap.call_deferred()

func _prepare_values() -> void:
	var began := Time.get_ticks_usec()
	metrics = {"utf8_decode_usec":0,"sanitize_usec":0,"encode_usec":0,"json_parse_usec":0,"total_usec":0}
	if is_cancelled(): return
	if direction == "request":
		_prepare_request_values()
		return
	if direction == "conversation_edit":
		_prepare_conversation_values()
		return
	var stage := Time.get_ticks_usec()
	var raw := bytes.get_string_from_utf8()
	metrics.utf8_decode_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	# Architecture's provider contract redacts decoded JSON values as well as
	# raw spellings. Do that once in this same finite value worker, so escaped
	# credentials cannot reach the durable audit and no main-thread reparse is
	# reintroduced by the integration.
	stage = Time.get_ticks_usec()
	var parser := JSON.new()
	var valid_json := parser.parse(raw) == OK
	metrics.json_parse_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	var redactor := Redactor.new()
	redactor.secrets = secrets_snapshot
	redactor.cancellation = is_cancelled
	stage = Time.get_ticks_usec()
	# Property names are redacted too. Keep a separate body projection so a
	# valid arbitrary key such as "body"/"bo" cannot erase our preview lookup.
	# Insert it last, preserving the original response-envelope collision order.
	var clean: Variant = redactor.redacted_value({"transport":transport_result,"http":http_code,"headers":headers})
	if is_cancelled(): return
	sanitized_body = redactor.redact(raw)
	if is_cancelled(): return
	if valid_json:
		var safe_body: Variant = redactor.redacted_value(parser.data)
		if is_cancelled(): return
		if safe_body != parser.data: sanitized_body = JSON.stringify(safe_body)
	clean[redactor.redact("body")] = sanitized_body
	metrics.sanitize_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	sanitized = clean
	stage = Time.get_ticks_usec()
	encoded_data = JSON.stringify(sanitized)
	metrics.encode_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	if asynchronous:
		stage = Time.get_ticks_usec()
		encoded_data_bytes = encoded_data.to_utf8_buffer()
		metrics.utf8_encode_usec = Time.get_ticks_usec()-stage
		if is_cancelled(): return
	if transport_result == HTTPRequest.RESULT_SUCCESS and (http_code >= 200 and http_code < 300 or provider_name == "OpenAI" and http_code == 429):
		valid_object = valid_json and parser.data is Dictionary
		if valid_object: data = parser.data
	if is_cancelled(): return
	if valid_object and http_code >= 200 and http_code < 300:
		stage = Time.get_ticks_usec()
		var safe_raw: String = sanitized_body
		if data.has("error") and data.error != null:
			decoded = {"text":"","error":"Provider error: "+safe_raw.left(512)+(" … (full response in Traffic)" if safe_raw.length() > 512 else "")}
		else:
			decoded = decode(provider_name,data)
			if str(decoded.error).length() > 512:
				decoded.error = "Provider response was incomplete or refused: "+safe_raw.left(512)+" … (full response in Traffic)"
		metrics.envelope_decode_usec = Time.get_ticks_usec()-stage
		if is_cancelled(): return
		stage = Time.get_ticks_usec()
		decoded.text = redactor.redact(str(decoded.text))
		decoded.error = redactor.redact(str(decoded.error))
		metrics.assistant_redact_usec = Time.get_ticks_usec()-stage
		if is_cancelled(): return
		stage = Time.get_ticks_usec()
		encoded_assistant = JSON.stringify(decoded.text)
		encoded_conversation = "".join(['{"content":',encoded_assistant,',"role":"assistant"}'])
		metrics.assistant_encode_usec = Time.get_ticks_usec()-stage
		if is_cancelled(): return
		if asynchronous:
			stage = Time.get_ticks_usec()
			encoded_assistant_bytes = encoded_assistant.to_utf8_buffer()
			encoded_conversation_bytes = encoded_conversation.to_utf8_buffer()
			metrics.assistant_utf8_encode_usec = Time.get_ticks_usec()-stage
	metrics.total_usec = Time.get_ticks_usec()-began

func _prepare_request_values() -> void:
	var redactor := Redactor.new()
	redactor.secrets = secrets_snapshot
	redactor.cancellation = is_cancelled
	var stage := Time.get_ticks_usec()
	encoded_payload = JSON.stringify(request_body)
	metrics.payload_encode_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	if asynchronous:
		stage = Time.get_ticks_usec()
		encoded_payload_bytes = encoded_payload.to_utf8_buffer()
		encoded_payload = "" # HTTPRequest.request_raw owns the prepared bytes.
		metrics.payload_utf8_encode_usec = Time.get_ticks_usec()-stage
		if is_cancelled(): return
	stage = Time.get_ticks_usec()
	var clean: Variant = redactor.redacted_value({"url":request_url,"provider":provider_name,"body":request_body})
	metrics.sanitize_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	sanitized = clean
	stage = Time.get_ticks_usec()
	encoded_data = JSON.stringify(sanitized)
	metrics.encode_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	if asynchronous:
		stage = Time.get_ticks_usec()
		encoded_data_bytes = encoded_data.to_utf8_buffer()
		metrics.utf8_encode_usec = Time.get_ticks_usec()-stage

func _prepare_conversation_values() -> void:
	# The provider admitted a finite typed snapshot. This worker owns only
	# copied values; current image/history authority is checked on the owner.
	var redactor := Redactor.new()
	redactor.secrets = secrets_snapshot
	redactor.cancellation = is_cancelled
	var stage := Time.get_ticks_usec()
	var turns: Array = []
	for original: Dictionary in conversation_turns:
		if is_cancelled(): return
		var turn := original.duplicate(true)
		turn.content = redactor.redact(str(turn.content))
		if is_cancelled(): return
		conversation_bytes += str(turn.content).to_utf8_buffer().size()
		if conversation_bytes > 16*1024*1024:
			preparation_error = "Conversation exceeds the 16 MiB replay limit; nothing written."
			return
		turns.append(turn)
	var result := redactor.redact(conversation_last_result)
	if is_cancelled(): return
	sanitized = {"turns":turns,"last_result":result}
	metrics.sanitize_usec = Time.get_ticks_usec()-stage
	stage = Time.get_ticks_usec()
	encoded_data = JSON.stringify(sanitized)
	metrics.encode_usec = Time.get_ticks_usec()-stage
	if is_cancelled(): return
	stage = Time.get_ticks_usec()
	encoded_data_bytes = encoded_data.to_utf8_buffer()
	metrics.utf8_encode_usec = Time.get_ticks_usec()-stage
	if encoded_data_bytes.size() > 32*1024*1024:
		preparation_error = "Conversation edit exceeds the 32 MiB audit record limit; nothing written."

func _reap() -> void:
	# No GUI-thread wait for CPU work: a notification can overtake the final
	# worker return, so retry on the next frame until the pool confirms completion.
	if not WorkerThreadPool.is_task_completed(task_id):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null: tree.process_frame.connect(_reap,CONNECT_ONE_SHOT)
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	var keep_alive: RefCounted = self
	_pending.erase(task_id)
	reaped = true
	var provider: Variant = owner.get_ref() if owner != null else null
	if is_instance_valid(provider) and provider.is_inside_tree() and not provider.is_queued_for_deletion():
		provider._preparation_finished(keep_alive)
