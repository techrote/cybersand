extends SceneTree
## Real large outbound loopback requests: snapshot/offset handshake, late
## admission guard, cooperative Stop and async start errors, without paid calls.
const P = preload("res://scripts/art_provider.gd")
const Preparation = preload("res://scripts/art_response_preparation.gd")
const LATE_KEY := "fixture-key-added-during-outgoing-preparation"
var provider: Node
var checks := 0
var failures: Array[String] = []
var starts: Array[Dictionary] = []
var completions: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_REQUEST_PREPARATION_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func until(predicate: Callable, seconds: float = 10.0) -> bool:
	var end := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < end: await process_frame
	return predicate.call()

func serve(listener: TCPServer, receipt: Dictionary) -> void:
	if not await until(listener.is_connection_available):
		receipt.done = true
		return
	var peer := listener.take_connection()
	var incoming := PackedByteArray()
	var header_end := -1
	var expected := -1
	while expected < 0 or incoming.size() < expected:
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0: incoming.append_array(peer.get_data(available)[1])
		if header_end < 0:
			var prefix := incoming.get_string_from_utf8()
			header_end = prefix.find("\r\n\r\n")
			if header_end >= 0:
				var length := 0
				for line: String in prefix.left(header_end).split("\r\n"):
					if line.to_lower().begins_with("content-length:"): length = line.substr(15).strip_edges().to_int()
				expected = header_end+4+length
		await process_frame
	receipt.body = JSON.parse_string(incoming.slice(header_end+4,expected).get_string_from_utf8())
	var response := '{"choices":[{"message":{"content":"[]"}}]}'
	peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [response.length(),response]).to_utf8_buffer())
	for _i: int in range(5): await process_frame
	peer.disconnect_from_host()
	listener.stop()
	receipt.done = true

func invalid_endpoint_checks(context: Array) -> void:
	# These malformed authorities previously reached HTTPRequest and emitted an
	# engine ERROR before returning. Exercise both real provider dispatch paths;
	# the strict regression runner rejects any remaining native diagnostic.
	for bad: String in ["http://localhost:abc","http://:80","http://[",
			"http://[::1]:abc","http://127.0.0.1:65536","http://127.0.0.1:0"]:
		var start_count := starts.size()
		var completion_count := completions.size()
		var error: String = provider.send("LM Studio",bad,"invalid-authority","","Return []","rules",16,1)
		check(error.contains("Could not start") and not provider.active and provider.request == null
			and starts.size() == start_count and completions.size() == completion_count
			and provider.last_request_timing.status == "start_failed",
			"synchronous malformed authority refuses without a false start or completion: "+bad)
		error = provider.send("LM Studio",bad,"invalid-authority","","Return []","rules",16,1,"",context)
		check(error.is_empty() and provider.request_preparation_active(),"malformed authority genuinely enters asynchronous preparation: "+bad)
		check(await until(func() -> bool: return not provider.active and Preparation.pending_count() == 0),"asynchronous malformed authority settles: "+bad)
		check(starts.size() == start_count and completions.size() == completion_count+1
			and completions.back().error.contains("Could not start") and provider.request == null
			and provider.last_request_timing.status == "start_failed",
			"asynchronous malformed authority emits one refusal and no started handshake: "+bad)
	for bad: String in ["http://localhost:","http://localhost:-1","http://localhost:+80",
			"http://[::1]evil","http://[host]:1234","http://::1:1234"]:
		check(not P._has_http_endpoint(P.request_url("LM Studio",bad)),"ambiguous authority is not admitted: "+bad)
	for good: String in ["https://api.example/v1","http://localhost:1234/v1",
			"http://127.0.0.1:65535/v1","http://[::1]:1234/v1","http://[2001:db8::1]/v1"]:
		check(P._has_http_endpoint(P.request_url("LM Studio",good)),"valid endpoint syntax remains supported without probing it: "+good)

func run() -> void:
	provider = P.new()
	root.add_child(provider)
	provider.request_started.connect(func(id: int, offset: int) -> void:
		starts.append({"id":id,"offset":offset,"path":provider.log_path}))
	provider.finished.connect(func(id: int, text: String, _data: Dictionary, error: String) -> void:
		completions.append({"id":id,"text":text,"error":error}))
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,"large outbound listener binds")
	var endpoint := "http://127.0.0.1:%d/v1" % listener.get_local_port()
	var receipt := {"done":false,"body":{}}
	serve.call_deferred(listener,receipt)
	var original := "x".repeat(1024*1024)+LATE_KEY
	var packed := PackedStringArray(["packed-original"])
	var context: Array = [{"role":"user","content":original,"fixture_packed":packed}]
	var begin_usec := Time.get_ticks_usec()
	check(provider.send("LM Studio",endpoint,"outbound-fixture","","Return []","rules",4096,5,"synthetic-png",context).is_empty(),"large request is accepted before CPU preparation completes")
	check(provider.request_preparation_active() and provider.request == null and starts.is_empty(),"no HTTP request or started handshake precedes value preparation")
	check(provider.last_request_offset == -1,"pending request cannot reuse a predecessor's image offset")
	check(Time.get_ticks_usec()-begin_usec < 1000000,"large Send returns without synchronous full request encoding")
	context[0].content = "mutated after Send"
	packed[0] = "packed-mutated"
	provider.secrets.append(LATE_KEY)
	check(await until(func() -> bool: return receipt.done and not provider.active and Preparation.pending_count() == 0),"actual large HTTP request and response complete")
	check(receipt.body.messages[1].content == original,"later caller mutation cannot alter owned request context")
	check(receipt.body.messages[1].fixture_packed == ["packed-original"],"deep request snapshot isolates nested packed-string arrays")
	check(starts.size() == 1 and completions.size() == 1 and completions[0].error.is_empty(),"one successful request has one started handshake and completion")
	check(int(provider.last_request_timing.get("request_preparation_restarts",0)) >= 1 and not FileAccess.get_file_as_string(provider.log_path).contains(LATE_KEY),"key registration reparses the same outgoing snapshot before redacted audit publication")
	var file := FileAccess.open(starts[0].path,FileAccess.READ)
	file.seek(int(starts[0].offset))
	var event: Variant = JSON.parse_string(file.get_line())
	check(event is Dictionary and event.kind == "request" and event.data.body.messages[-1].content[1].image_url.url == "data:image/png;base64,synthetic-png","started handshake supplies this request's committed image offset")
	file = null
	var start_count := starts.size()
	var completion_count := completions.size()
	listener = TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,"cancelled preparation listener binds")
	endpoint = "http://127.0.0.1:%d/v1" % listener.get_local_port()
	context = [{"role":"user","content":original}]
	provider.send("LM Studio",endpoint,"cancel-fixture","","Return []","rules",4096,5,"",context)
	check(provider.request_preparation_active(),"Stop fixture genuinely has CPU preparation outstanding")
	provider.cancel("Stop before outgoing audit")
	for _attempt: int in range(6):
		check(not provider.send("LM Studio",endpoint,"retry","","Return []","rules",4096,5,"",context).is_empty(),"rapid restart cannot accumulate preparation jobs")
	check(await until(func() -> bool: return Preparation.pending_count() == 0),"cancelled outgoing task is reaped")
	check(not listener.is_connection_available() and starts.size() == start_count and completions.size() == completion_count,"Stop before dispatch sends no POST or fictitious completion")
	check(provider.peak_request_preparation_jobs == 1 and FileAccess.get_file_as_string(provider.log_path).contains('"request_receipt_committed":false'),"single-slot cancellation receipt is explicit")
	var guard_state := {"allowed":true}
	var guard := func() -> bool: return guard_state.allowed
	provider.send("LM Studio",endpoint,"world-fixture","","Return []","rules",4096,5,"",context,guard)
	guard_state.allowed = false
	check(await until(func() -> bool: return not provider.active and Preparation.pending_count() == 0),"late World/admission guard cancels prepared request")
	check(not listener.is_connection_available() and starts.size() == start_count,"pre-dispatch guard prevents stale context reaching HTTP")
	guard_state.allowed = true
	var audit_guard := {"armed":true}
	var guard_handler := func() -> void:
		if audit_guard.armed:
			audit_guard.armed = false
			guard_state.allowed = false
	provider.traffic_changed.connect(guard_handler)
	provider.send("LM Studio",endpoint,"audit-guard-fixture","","Return []","rules",4096,5,"",context,guard)
	check(await until(func() -> bool: return not provider.active and Preparation.pending_count() == 0),"admission guard is rechecked after signal-emitting request audit")
	provider.traffic_changed.disconnect(guard_handler)
	check(not audit_guard.armed and not listener.is_connection_available() and starts.size() == start_count,"post-audit context change still prevents HTTP dispatch")
	var guard_owner := Node.new()
	root.add_child(guard_owner)
	provider.send("LM Studio",endpoint,"lost-guard-fixture","","Return []","rules",4096,5,"",context,guard_owner.is_inside_tree)
	guard_owner.free()
	check(await until(func() -> bool: return not provider.active and Preparation.pending_count() == 0),"destroyed guard target cancels prepared request")
	check(not listener.is_connection_available() and starts.size() == start_count,"a supplied invalid guard cannot become unguarded HTTP dispatch")
	listener.stop()
	provider.send("LM Studio","invalid://fixture","bad-url","","Return []","rules",4096,5,"",context)
	check(await until(func() -> bool: return not provider.active and Preparation.pending_count() == 0),"asynchronous start failure terminates cleanly")
	check(starts.size() == start_count and completions.size() == completion_count+1 and completions.back().error.contains("Could not start"),"async start failure emits one truthful error and no started handshake")
	check(provider.last_request_timing.status == "start_failed","async start failure keeps its explicit terminal status")
	await invalid_endpoint_checks(context)
	provider.send("LM Studio",endpoint,"shutdown-fixture","","Return []","rules",4096,5,"",context)
	check(provider.request_preparation_active(),"owner shutdown fixture has outgoing CPU work pending")
	var archive: String = provider.log_path
	var shutdown_usec := Time.get_ticks_usec()
	provider.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(provider) and Time.get_ticks_usec()-shutdown_usec < 1000000,"owner destruction never joins outgoing value work")
	check(await until(func() -> bool: return Preparation.pending_count() == 0),"outgoing handle is reaped after its provider is destroyed")
	DirAccess.remove_absolute(archive)
	print("ART_REQUEST_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
