extends RefCounted
## Read-only projections of recorded traffic. Never supplies API/native input.

const FILTERS := ["Messages","Errors","Metrics","ACKs","Tools","Raw"]
const DEFAULT_FILTERS := {"Messages":true,"Errors":true,"Metrics":false,"ACKs":true,"Tools":true,"Raw":false}
const MAX_CONVERSATION_CHARS := 2 * 1024 * 1024

static func _json(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	if value is String:
		var parsed := JSON.new()
		if parsed.parse(value) == OK and parsed.data is Dictionary:
			return parsed.data
	return {}

static func _display(value: Variant) -> Variant:
	# JSON parsing turns integral numbers into floats. Normalize display only.
	if value is float and is_finite(value) and value == floor(value) and abs(value) <= 9007199254740991.0:
		return int(value)
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _display(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_display(item))
		return result
	return value

static func _pretty(value: Variant) -> String:
	return JSON.stringify(_display(value),"  ",true)

static func _body(record: Dictionary) -> Dictionary:
	var payload: Variant = record.get("payload",{})
	return _chat_body(_json(payload.get("body",{})),str(record.get("kind",""))) if payload is Dictionary else {}

static func _chat_call(value: Dictionary) -> Dictionary:
	var fn: Variant = value.get("function",{})
	if not fn is Dictionary:
		return {"type":[]}
	return {"type":"function_call","call_id":str(value.get("id","")),"name":str(fn.get("name","")),"arguments":fn.get("arguments",{})}

static func _chat_body(body: Dictionary, kind: String) -> Dictionary:
	# Display-only translation. Original Chat/Responses bytes stay unchanged.
	if kind == "http.request" and body.get("messages") is Array:
		var result := body.duplicate(false)
		var input: Array = []
		for message: Variant in body.messages:
			if not message is Dictionary:
				continue
			var role := str(message.get("role",""))
			if role == "tool":
				input.append({"type":"function_call_output","call_id":message.get("tool_call_id",""),"output":message.get("content","")})
			else:
				input.append({"role":role,"content":message.get("content",""),"_chat_history":true})
				if message.get("tool_calls") is Array:
					for call: Variant in message.tool_calls:
						if call is Dictionary:
							input.append(_chat_call(call))
		result["input"] = input
		return result
	if kind == "http.response" and body.has("choices"):
		var result := body.duplicate(false)
		var output: Array = []
		if body.choices is Array:
			for choice: Variant in body.choices:
				if not choice is Dictionary or not choice.get("message") is Dictionary:
					output.append({"type":[]})
					continue
				var message: Dictionary = choice.message
				output.append({"type":"message","content":message.get("content","")})
				if message.get("tool_calls") is Array:
					for call: Variant in message.tool_calls:
						output.append(_chat_call(call) if call is Dictionary else {"type":[]})
		else:
			output.append({"type":[]})
		result["output"] = output
		return result
	return body

static func _scope(record: Dictionary) -> String:
	var identity: Variant = record.get("identity",{})
	return "%s:%s" % [str(record.get("session","legacy")),str(identity.get("epoch",0)) if identity is Dictionary else "0"]

static func stable_id(record: Dictionary) -> String:
	return "%s:%s:%s" % [str(record.get("session","legacy")),str(record.get("sequence",-1)),str(record.get("kind",""))]

static func _text(content: Variant) -> String:
	if content is String:
		return content
	if not content is Array:
		return ""
	var parts := PackedStringArray()
	for part: Variant in content:
		if part is Dictionary and str(part.get("type","")) in ["input_text","output_text","text","summary_text","refusal"]:
			var value: Variant = part.get("text",part.get("refusal",""))
			if value is String and not value.is_empty():
				parts.append(value)
	return "\n".join(parts)

static func _add(blocks: Array, category: String, heading: String, content: String, key: String = "") -> void:
	if not content.is_empty():
		blocks.append({"category":category,"heading":heading,"text":content,"key":key})

static func _call(blocks: Array, item: Dictionary, scope: String) -> void:
	var call_id := str(item.get("call_id",item.get("id","")))
	var name := str(item.get("name","unnamed tool"))
	var args: Variant = item.get("arguments",{})
	var parsed := _json(args)
	var content: String = _pretty(parsed) if not parsed.is_empty() else str(args)
	_add(blocks,"Tools","Model → tool · %s [%s]" % [name,call_id],content,
		scope+":call:"+call_id+":"+name if not call_id.is_empty() else "")

static func _result(value: Variant) -> String:
	var parsed := _json(value)
	if parsed.is_empty():
		return str(value).substr(0,4096)
	# Full arrays and cell readbacks remain available in Content/Event/raw export.
	var compact := {}
	for key: String in ["status","reason","detail","confirmed_writes","changed_cells","completed_ticks","completed_tick","native_counts","observation_id","proposal_id","image_status"]:
		if parsed.has(key):
			compact[key] = parsed[key]
	if compact.is_empty():
		return _pretty(parsed).substr(0,4096)
	return _pretty(compact).substr(0,4096)

static func _failed_status(value: Variant) -> bool:
	return value is String and value in ["error","failed","refused","unconfirmed","cancelled","canceled","incomplete"]

static func blocks(record: Dictionary) -> Array:
	var result: Array = []
	var kind := str(record.get("kind",""))
	var payload: Variant = record.get("payload",{})
	if not payload is Dictionary:
		payload = {"value":payload}
	var body := _body(record)
	var scope := _scope(record)
	if kind == "http.request":
		var input: Variant = body.get("input",[])
		if input is String:
			_add(result,"Messages","Human → model",input,scope+":human:"+input.sha256_text())
		elif input is Array:
			for item: Variant in input:
				if not item is Dictionary:
					continue
				if str(item.get("type","")) == "function_call_output":
					var call_id := str(item.get("call_id",""))
					var output: Variant = item.get("output","")
					_add(result,"Tools","Tool → model [%s] · result summary" % call_id,_result(output),
						scope+":output:"+call_id+":"+JSON.stringify(output).sha256_text())
				elif str(item.get("type","")) == "function_call":
					_call(result,item,scope)
				elif item.has("role"):
					var role := str(item.role)
					var text := _text(item.get("content",""))
					var heading: String = {"user":"Human → model","developer":"Developer instructions","system":"System instructions","assistant":"Model"}.get(role,role.capitalize())
					var key := scope+":assistant-history:"+text.sha256_text() if role == "assistant" and item.get("_chat_history",false) else scope+":message:"+role+":"+text.sha256_text()
					_add(result,"Messages",heading,text,key)
	elif kind == "http.response":
		var output: Variant = body.get("output",[])
		var has_prose := false
		var has_call := false
		var invalid_output := not output is Array
		if output is Array:
			for index: int in range(output.size()):
				var item: Variant = output[index]
				if not item is Dictionary:
					invalid_output = true
					continue
				if not item.get("type") is String:
					invalid_output = true
				if str(item.get("type","")) == "function_call":
					has_call = true
					_call(result,item,scope)
				elif str(item.get("type","")) == "reasoning":
					# Only provider-returned summaries are available. Never infer hidden reasoning.
					_add(result,"Messages","Model reasoning summary (provider supplied)",_text(item.get("summary",[])))
				elif str(item.get("type","")) == "message":
					var text := _text(item.get("content",[]))
					has_prose = has_prose or not text.is_empty()
					_add(result,"Messages","Model",text,scope+":response:"+str(body.get("id",stable_id(record)))+":"+str(index))
					if body.has("choices") and not text.is_empty():
						result[-1]["record_alias"] = scope+":assistant-history:"+text.sha256_text()
		if has_call and not has_prose:
			_add(result,"Messages","Model","No assistant prose returned; this response contains tool calls.",scope+":no-prose:"+str(body.get("id",stable_id(record))))
		if body.get("usage") is Dictionary:
			_add(result,"Metrics","Provider usage",_pretty(body.usage))
		var error: Variant = body.get("error")
		var malformed := payload.get("body") is String and body.is_empty()
		if int(payload.get("http_status",200)) >= 400 or int(payload.get("transport_result",0)) != 0 or error != null or _failed_status(body.get("status")) or malformed or invalid_output:
			var description := {"http_status":payload.get("http_status"),"transport_result":payload.get("transport_result"),"status":body.get("status")}
			if error != null:
				description.error = error
			if invalid_output:
				description.detail = "Response output has malformed item types; original content remains in Content/Event."
			if malformed:
				description.detail = "Response JSON is malformed, empty or not an object; original body remains in Content/Event."
			_add(result,"Errors","Response error",_pretty(description))
	elif kind == "runner.finished" and payload.get("model_final_unverified_report") is String:
		_add(result,"Messages","Model report (unverified)",payload.model_final_unverified_report)
	elif kind == "tool.request":
		_call(result,payload,scope)
	elif kind in ["native.receipt","native_authorization_request","native_authorization_ack","native_retirement_request","native_retirement_ack"] or kind.ends_with(".ack"):
		var receipt: Variant = payload.get("receipt",payload)
		_add(result,"ACKs",kind.replace("_"," ").replace("."," ").capitalize(),_result(receipt))
		if receipt is Dictionary and _failed_status(receipt.get("status")):
			_add(result,"Errors","Native refusal or unconfirmed result",_result(receipt))
	if kind.contains("error") or kind.contains("refused") or kind.contains("failure"):
		_add(result,"Errors",kind,_result(payload))
	if kind.contains("metrics") or kind.contains("usage") or kind.begins_with("rate."):
		_add(result,"Metrics",("Local rate limiter (estimate) · " + kind) if kind.begins_with("rate.") else kind,_pretty(payload))
		if kind.begins_with("rate.") and (payload.get("error") != null or body.get("error") != null or int(payload.get("http_status",200)) >= 400):
			_add(result,"Errors","Rate-limit retry/error",_result(payload))
	return result

static func categories(record: Dictionary) -> Array[String]:
	var result: Array[String] = ["Raw"]
	for block: Dictionary in blocks(record):
		if not result.has(block.category):
			result.append(block.category)
	return result

static func matches(record: Dictionary, enabled: Dictionary) -> bool:
	if enabled.get("Raw",false):
		return true
	for category: String in categories(record):
		if enabled.get(category,false):
			return true
	return false

static func conversation(records: Array, enabled: Dictionary) -> String:
	var sections := PackedStringArray()
	var seen := {}
	var length := 0
	var clipped := false
	for record: Variant in records:
		if not record is Dictionary:
			continue
		var entries := blocks(record)
		if entries.is_empty() and enabled.get("Raw",false):
			var raw_text := "No readable message or tool content; inspect the original envelope in Content/Event." if str(record.get("kind","")) == "http.response" else _pretty(record.get("payload",{}))
			_add(entries,"Raw",str(record.get("kind","Raw event")),raw_text)
		for block: Dictionary in entries:
			if not enabled.get(block.category,false) and not enabled.get("Raw",false):
				continue
			var key := str(block.get("key",""))
			if not key.is_empty() and seen.has(key):
				continue
			if not key.is_empty():
				seen[key] = true
			if block.has("record_alias"):
				seen[block.record_alias] = true
			var heading := str(block.heading)
			var payload: Variant = record.get("payload",{})
			if payload is Dictionary and typeof(payload.get("stale",false)) == TYPE_BOOL and payload.get("stale",false):
				heading = "Ignored stale event · " + heading
			var section := "%s  ·  %s\n%s" % [str(record.get("utc","")),heading,str(block.text)]
			sections.append(section)
			length += section.length()+2
			while sections.size() > 1 and length > MAX_CONVERSATION_CHARS:
				length -= sections[0].length()+2
				sections.remove_at(0)
				clipped = true
	var text := "\n\n".join(sections)
	if text.length() > MAX_CONVERSATION_CHARS:
		clipped = true
		text = text.right(MAX_CONVERSATION_CHARS)
	if clipped:
		text = "[Conversation view clipped; complete retained events remain in raw export.]\n" + text
	return text
