extends Node
## One cancellable inference request; native drawing remains the existing executor.
signal finished(id: int, text: String, response: Dictionary, error: String)
signal traffic_changed
var active := false
var serial := 0
var request: HTTPRequest
var secrets: Array[String] = []
var traffic := ""
var readable := ""
var log_path := ""
var log_warning := ""
var usage: Dictionary = {}
var requested_model := ""
var returned_model := ""
const INSTRUCTIONS := 'Create the user-requested subject as an original 2D pixel-art composition, filling the supplied work area. Build complex subjects from as many simple primitives as needed. Return ONLY a JSON array, no prose. Each object has shape and material. Literal shape values and required integer parameters: rectangle uses x0,y0,x1,y1 (inclusive endpoints); disc uses x,y,radius; line uses x0,y0,x1,y1; pixels uses points:[[x,y],...]. Choose your own coordinates and dimensions to depict the subject; these are field definitions, not a drawing to copy. Material 58 draws Hard Wall, material 0 erases; omitted material defaults to 58. Operations execute in order. Stay inside the supplied work area; keep every disc including its radius inside it. Existing other materials and protected regions cannot be overwritten. Do not call external tools.'

static func payload(provider: String, model: String, prompt: String, instructions: String, tokens: int, png: String = "") -> Dictionary:
	if provider == "OpenAI":
		var content: Array = [{"type":"input_text","text":prompt}]
		if not png.is_empty(): content.append({"type":"input_image","image_url":"data:image/png;base64,"+png})
		return {"model":model,"instructions":instructions,"input":[{"role":"user","content":content}],"max_output_tokens":tokens,"store":false}
	var content: Variant = prompt
	if not png.is_empty(): content = [{"type":"text","text":prompt},{"type":"image_url","image_url":{"url":"data:image/png;base64,"+png}}]
	var packet := {"model":model,"messages":[{"role":"system","content":instructions},{"role":"user","content":content}],"max_tokens":tokens,"stream":false}
	if provider == "NVIDIA" and model in ["nvidia/nemotron-3.5-lightning-30b-a3b","nvidia/nemotron-3.5-super-vl-120b-a12b"]:
		packet.chat_template_kwargs = {"enable_thinking":false}
	return packet

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

static func operations(text: String) -> Variant:
	var clean := text.strip_edges()
	if clean.contains("</think>"): clean = clean.substr(clean.rfind("</think>")+8).strip_edges()
	if clean.begins_with("```"):
		var lines := clean.split("\n")
		if lines.size()>2: clean = "\n".join(lines.slice(1,lines.size()-1))
	var parser := JSON.new()
	if parser.parse(clean)!=OK:
		# Accept a complete array followed by stray wrapper/prose, never a truncated array.
		if not clean.begins_with("[") or parser.parse(clean.left(clean.rfind("]")+1))!=OK: return null
	var value: Variant = parser.data
	if value is Dictionary and value.has("operations"): value = value.operations
	if value is Dictionary and (value.has("shape") or value.has("type")): value = [value]
	if value is Array:
		for op: Variant in value:
			if not op is Dictionary: continue
			if not op.has("shape"): op.shape = op.get("type",op.get("operation",""))
			if op.shape is String:
				op.shape = op.shape.trim_prefix("draw_")
				op.shape = {"rect":"rectangle","circle":"disc","pixel":"pixels"}.get(op.shape,op.shape)
			if not op.has("material"): op.material = 58
	return value

func redact(value: String) -> String:
	var clean := value
	for secret: String in secrets:
		if not secret.is_empty(): clean = clean.replace(secret,"[redacted]").replace(secret.uri_encode(),"[redacted]")
	for pattern: String in ['(?i)Bearer[ \t]+[A-Za-z0-9._~+/-]+=*','sk-[A-Za-z0-9_-]{12,}','nvapi-[A-Za-z0-9_-]+']:
		var regex := RegEx.new()
		regex.compile(pattern)
		clean = regex.sub(clean,"[redacted]",true)
	var fields := RegEx.new()
	fields.compile('(?i)(["?&](?:api[_-]?key|access_token|token|authorization|password)[" ]*[:=][ "]*)[^"&,}\n ]+')
	clean = fields.sub(clean,'$1[redacted]',true)
	var userinfo := RegEx.new()
	userinfo.compile('(https?://)[^/@\\s]+:[^/@\\s]+@')
	return userinfo.sub(clean,'$1[redacted]@',true)

func log_event(kind: String, data: Variant) -> void:
	var line := redact(JSON.stringify({"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"request":serial,"kind":kind,"data":data}))
	traffic += line+"\n"
	readable += "\n"+Time.get_datetime_string_from_system(true)+" #"+str(serial)+" "+kind+"\n"
	if kind=="request" and data is Dictionary:
		var body: Dictionary = data.body
		readable += "Model: "+str(body.get("model",""))+"\n"
		if body.has("instructions"): readable += "Instructions:\n"+redact(str(body.instructions))+"\n"
		for message: Dictionary in body.get("messages",body.get("input",[])):
			readable += str(message.get("role","message"))+":\n"
			var content: Variant = message.get("content","")
			if content is String: readable += redact(content)+"\n"
			elif content is Array:
				for block: Dictionary in content:
					readable += redact(str(block.text))+"\n" if block.has("text") else "[Image attached; exact bytes in Raw JSONL]\n"
	elif data is String: readable += redact(data)+"\n"
	else: readable += redact(JSON.stringify(data,"  "))+"\n"
	if readable.length()>2000000: readable = "[Earlier traffic retained on disk]\n"+readable.right(1500000)
	# The live surface is bounded independently of the durable, full-session log.
	if traffic.length()>2000000: traffic = "[Earlier traffic retained on disk]\n"+traffic.right(1500000)
	if log_path.is_empty():
		var folder := "user://art-traffic"
		if DirAccess.make_dir_recursive_absolute(folder)==OK:
			log_path = folder+"/"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(get_instance_id())+".jsonl"
	if not log_path.is_empty():
		var file := FileAccess.open(log_path,FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
		if file != null:
			file.seek_end(); file.store_line(line)
			if file.get_error()!=OK: log_warning = "Traffic disk write failed; drawing continues."
		else: log_warning = "Cannot write traffic log; live traffic remains available."
	else: log_warning = "Cannot create traffic directory; drawing continues."
	traffic_changed.emit()

func cancel(reason: String = "Human Stop") -> void:
	serial += 1
	if request != null:
		request.cancel_request(); request.queue_free(); request = null
	if active: log_event("cancelled",reason)
	active = false

func send(provider: String, endpoint: String, model: String, key: String, prompt: String, instructions: String, tokens: int, seconds: float, png: String = "") -> String:
	if active: return "A model request is already active."
	if model.strip_edges().is_empty(): return "Enter a model ID (discovery is optional)."
	if not key.is_empty() and not secrets.has(key): secrets.append(key)
	if provider != "LM Studio" and key.is_empty(): return "Enter your "+provider+" key in Key."
	serial += 1
	var id := serial
	requested_model = model
	usage = {}; returned_model = ""
	var url := endpoint.trim_suffix("/")+ ("/responses" if provider=="OpenAI" else "/chat/completions")
	var body := payload(provider,model,prompt,instructions,tokens,png)
	log_event("request",{"url":url,"provider":provider,"body":body})
	request = HTTPRequest.new()
	request.use_threads = true
	request.timeout = seconds
	request.body_size_limit = 16*1024*1024
	request.max_redirects = 0
	add_child(request)
	var current := request
	request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, bytes: PackedByteArray) -> void:
		current.queue_free()
		if id != serial: return
		request = null; active = false
		var raw := bytes.get_string_from_utf8()
		log_event("response",{"transport":result,"http":code,"headers":headers,"body":raw})
		var parser := JSON.new()
		var valid_json := parser.parse(raw)==OK
		var data: Dictionary = parser.data if valid_json and parser.data is Dictionary else {}
		usage = data.get("usage",{}) if data.get("usage") is Dictionary else {}
		returned_model = str(data.get("model","unknown"))
		log_event("usage",{"requested_model":requested_model,"returned_model":returned_model,"usage":usage,"cost":null})
		var decoded := decode(provider,data)
		log_event("assistant",decoded.text)
		var error: String = decoded.error
		if result != HTTPRequest.RESULT_SUCCESS: error = "Connection/timeout failure (%d). Check endpoint/server; inspect Traffic." % result
		elif code < 200 or code >= 300: error = "HTTP %d: %s" % [code,raw]
		finished.emit(id,redact(decoded.text),data,redact(error)))
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not key.is_empty(): headers.append("Authorization: Bearer "+key)
	var err := request.request(url,headers,HTTPClient.METHOD_POST,JSON.stringify(body))
	if err != OK:
		cancel("Request start failed")
		return "Could not start HTTP request (%d). Check the endpoint URL." % err
	active = true
	return ""
