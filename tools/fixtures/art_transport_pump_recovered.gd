extends SceneTree
## Reconstructed, separately identified mechanism fixture after /tmp reset.
## Production Art provider; real loopback HTTP; no native World or model inference.
const Provider = preload("res://scripts/art_provider.gd")
var provider: Node
var checks := 0
var failures: Array[String] = []
var ordinary := 0
var completions: Array = []
var frames: Array[float] = []
var increments: Array[int] = []
var measuring := false
var last_frame_usec := 0
var last_downloaded := 0
var endpoint := ""
var fixture_key := ""

func _initialize() -> void:
	Engine.max_fps = int(OS.get_environment("ART_PUMP_FPS"))
	process_frame.connect(sample)
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print("ART_PUMP_RECOVERED_CHECK ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value

func digest(value: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not value.is_empty(): hash.update(value)
	return hash.finish().hex_encode()

func until(predicate: Callable, timeout_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func sample() -> void:
	var now := Time.get_ticks_usec()
	if measuring:
		if last_frame_usec>0: frames.append(float(now-last_frame_usec)/1000.0)
		if is_instance_valid(provider) and is_instance_valid(provider.request):
			var count: int = provider.request.get_downloaded_bytes()
			if count>last_downloaded: increments.append(count-last_downloaded)
			last_downloaded=count
	last_frame_usec=now

func completed(identity: int, text: String, response: Dictionary, error: String) -> void:
	var arrived := Time.get_ticks_usec()
	completions.append({"id":identity,"text":text,"error":error,"receipt":response,
		"callback_usec":arrived})

func send(kind: String) -> Dictionary:
	return provider.send_owned({"request_id":"pump-"+kind,"mode":"discuss",
		"provider":"LM Studio","endpoint":endpoint,"model":"deterministic-pump-fixture",
		"key":fixture_key,"prompt":kind,"instructions":"Fixture only; no native authoring.",
		"tokens":8192,"seconds":90.0},completed,func()->bool:return true)

func audit_success() -> Dictionary:
	var raw := FileAccess.get_file_as_string(provider.log_path)
	var expected := OS.get_environment("ART_PUMP_TEXT_SHA256")
	var assistant := ""
	var response := ""
	for line: String in raw.split("\n",false):
		var item: Variant = JSON.parse_string(line)
		if not item is Dictionary: continue
		if item.get("kind")=="assistant" and item.get("data") is String: assistant=item.data
		if item.get("kind")=="response" and item.get("data") is Dictionary:
			var decoded: Variant = JSON.parse_string(str(item.data.get("body","")))
			if decoded is Dictionary and decoded.get("choices") is Array and not decoded.choices.is_empty():
				response=str(decoded.choices[0].message.content)
	check(not raw.contains(fixture_key),"complete admitted audit excludes the synthetic credential")
	check(digest(assistant.to_utf8_buffer())==expected,"complete assistant audit value matches every expected byte")
	check(digest(response.to_utf8_buffer())==expected,"complete response audit retains its full assistant envelope")
	return {"bytes":raw.to_utf8_buffer().size(),"sha256":digest(raw.to_utf8_buffer()),
		"assistant_sha256":digest(assistant.to_utf8_buffer()),"response_assistant_sha256":digest(response.to_utf8_buffer())}

func run() -> void:
	endpoint=OS.get_environment("ART_PUMP_ENDPOINT")
	fixture_key=OS.get_environment("ART_PUMP_KEY")
	provider=Provider.new(); root.add_child(provider)
	provider.finished.connect(func(_id: int,_text: String,_response: Dictionary,_error: String)->void:ordinary+=1)
	check(ClassDB.class_exists(&"CyberDemoBridge"),"actual pinned native audit bridge is loaded")
	check(provider.serial==0 and provider.request==null and provider.log_path.is_empty(),"provider construction starts no request or audit")
	var begin := Time.get_ticks_usec()
	measuring=true; last_frame_usec=begin
	var admitted:=send("success")
	check(admitted.get("ok")==true,"bounded successful owned request admitted")
	check(provider.request!=null and not provider.request.use_threads,"transport remains the nonthreaded cancellable owner")
	check(provider.request.download_chunk_size==int(OS.get_environment("ART_PUMP_CHUNK")),"actual HTTPRequest chunk equals this arm")
	check(provider.request.body_size_limit==16*1024*1024,"actual transport retains the 16 MiB cap")
	if not check(await until(func()->bool:return completions.size()==1 and not provider.active),"complete successful owned response arrives"):
		provider.cancel("Fixture deadline"); finish({}); return
	await process_frame
	measuring=false
	var timing: Dictionary = provider.last_request_timing.duplicate(true)
	var first: Dictionary = completions[0]
	var received_text: String = first.text
	first.erase("text")
	first.bytes=received_text.to_utf8_buffer().size()
	first.sha256=digest(received_text.to_utf8_buffer())
	check(first.error.is_empty() and first.receipt.state=="success","one authoritative owned consumer receives success")
	check(first.bytes==int(OS.get_environment("ART_PUMP_TEXT_BYTES")) and first.sha256==OS.get_environment("ART_PUMP_TEXT_SHA256"),"complete owned assistant value matches byte count and digest")
	check(ordinary==0,"owned successful response never reaches ordinary paint completion")
	check(timing.http_code==200 and timing.transport_result==HTTPRequest.RESULT_SUCCESS,"real transport completed HTTP 200")
	check(timing.response_bytes==int(OS.get_environment("ART_PUMP_RESPONSE_BYTES")),"real transport response byte count equals server payload")
	var observed:=frames.duplicate(); observed.sort()
	var successful:={"transport_ms":float(timing.transport_wait_usec)/1000.0,
		"complete_callback_ms":float(int(first.callback_usec)-begin)/1000.0,
		"maximum_frame_ms":observed.back() if not observed.is_empty() else 0,
		"p95_frame_ms":observed[mini(observed.size()-1,int(ceil(observed.size()*0.95))-1)] if not observed.is_empty() else 0,
		"frame_count":observed.size(),"download_increments":increments,
		"maximum_observed_increment":increments.max() if not increments.is_empty() else 0,
		"provider_timing":timing,"completion":first}
	successful.audit=audit_success()
	admitted=send("stalled")
	check(admitted.get("ok")==true,"real accepted-socket Stop request admitted")
	check(await until(func()->bool:return FileAccess.file_exists(OS.get_environment("ART_PUMP_STALL_READY")),10000),"loopback server acknowledged the actual socket without response headers")
	var stop_begin:=Time.get_ticks_usec()
	var cancelled: bool = provider.cancel_owned(int(admitted.provider_id),"pump-stalled","Explicit fixture owner Stop")
	var stop_ms:=float(Time.get_ticks_usec()-stop_begin)/1000.0
	check(cancelled and not provider.active and provider.request==null,"scoped Stop immediately retires the actual transport")
	check(completions.size()==2 and not completions[1].error.is_empty() and completions[1].receipt.state=="cancelled","scoped Stop has one owned terminal consumer")
	check(stop_ms<2000.0,"actual no-headers Stop remains below inherited two-second interaction bound")
	admitted=send("oversize")
	check(admitted.get("ok")==true,"oversized-response refusal request admitted")
	check(await until(func()->bool:return completions.size()==3 and not provider.active,10000),"oversized HTTP response retires through the owned route")
	check(completions.size()==3 and completions[2].error.contains("16 MiB") and provider.last_request_timing.transport_result==HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED,"response beyond the unchanged cap is refused")
	check(ordinary==0 and completions.size()==3,"all three requests have exactly one exclusive terminal consumer")
	check(not FileAccess.get_file_as_string(provider.log_path).contains(fixture_key),"final complete audit remains credential-free")
	finish({"success":successful,"stop_ms":stop_ms,"oversize":provider.last_request_timing.duplicate(true),
		"audit_path":ProjectSettings.globalize_path(provider.log_path),"audit_sha256":FileAccess.get_sha256(provider.log_path),
		"owned_completions":completions.size(),"ordinary_completions":ordinary})

func finish(details: Dictionary) -> void:
	details.merge({"format":"cybersand-art-pump-recovered-v1","checks":checks,"failures":failures,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"model_calls":0,"native_worlds":0,
		"provider_sha256":FileAccess.get_sha256("res://scripts/art_provider.gd"),
		"fixture_sha256":FileAccess.get_sha256("res://art_transport_pump_recovered.gd"),
		"platform":OS.get_name(),"godot":Engine.get_version_info().string,"fps":Engine.max_fps,
		"chunk_bytes":int(OS.get_environment("ART_PUMP_CHUNK"))})
	print("ART_PUMP_RECOVERED_RESULT ",JSON.stringify(details))
	if is_instance_valid(provider): provider.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
