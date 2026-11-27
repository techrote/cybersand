extends SceneTree
## Real keyless loopback transport. Adversarial failures must never become an
## assistant turn, leak a partial credential, or overwrite a successor's timing.
const P = preload("res://scripts/art_provider.gd")
const SECRET := "owner-fixture-credential-crossing-the-excerpt-boundary-unique"
var checks := 0
var failures: Array[String] = []
var provider: Node
var completions: Array[Dictionary] = []
var measured: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_FAILURE_LIFECYCLE_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func until(predicate: Callable, timeout_ms: int = 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func receive_request(listener: TCPServer) -> StreamPeerTCP:
	if not await until(listener.is_connection_available): return null
	var peer := listener.take_connection()
	var incoming := ""
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			var received := peer.get_data(available)
			if received[0] == OK: incoming += (received[1] as PackedByteArray).get_string_from_utf8()
		if incoming.contains("\r\n\r\n"):
			var headers := incoming.get_slice("\r\n\r\n",0)
			var length := 0
			for line: String in headers.split("\r\n"):
				if line.to_lower().begins_with("content-length:"):
					length = line.substr(15).strip_edges().to_int()
			if incoming.to_utf8_buffer().size() >= headers.to_utf8_buffer().size()+4+length:
				return peer
		await process_frame
	return null

func serve(listener: TCPServer, body: String, code: int, receipt: Dictionary) -> void:
	var peer: StreamPeerTCP = await receive_request(listener)
	if peer != null:
		var reply := "HTTP/1.1 %d Fixture\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [code,body.to_utf8_buffer().size(),body]
		receipt.sent = peer.put_data(reply.to_utf8_buffer()) == OK
		for i: int in range(8): await process_frame
		peer.disconnect_from_host()
	listener.stop()
	receipt.finished = true

func exchange(body: String, code: int = 200) -> Dictionary:
	var listener := TCPServer.new()
	if listener.listen(0,"127.0.0.1") != OK:
		check(false,"real loopback listener binds")
		return {}
	var fixture := {"sent":false,"finished":false}
	serve.call_deferred(listener,body,code,fixture)
	var before := completions.size()
	var endpoint := "http://127.0.0.1:%d/v1" % listener.get_local_port()
	check(provider.send("LM Studio",endpoint,"fixture",SECRET,"Return []","rules",4096,3).is_empty(),"loopback request dispatches")
	check(await until(func() -> bool: return not provider.active and fixture.finished),"loopback request completes")
	check(fixture.sent,"fixture sent a real HTTP response")
	check(completions.size() == before+1,"response emits exactly one terminal callback")
	return completions.back() if completions.size() > before else {}

func event_count(kind: String) -> int:
	return FileAccess.get_file_as_string(provider.log_path).count('"kind":"'+kind+'"')

func stop_during_audit(kind: String, body: String) -> void:
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,kind+" callback fixture binds")
	var fixture := {"sent":false,"finished":false}
	serve.call_deferred(listener,body,200,fixture)
	var previous_count := event_count(kind)
	var before := completions.size()
	var guard := {"armed":true}
	var handler := func() -> void:
		if guard.armed and event_count(kind) > previous_count:
			guard.armed = false
			provider.cancel("Stop during "+kind+" observer")
	provider.traffic_changed.connect(handler)
	provider.send("LM Studio","http://127.0.0.1:%d/v1" % listener.get_local_port(),"audit-cancel","","Return []","rules",4096,3)
	check(await until(func() -> bool: return fixture.finished and not provider.active),kind+" callback cancellation ends the real request")
	provider.traffic_changed.disconnect(handler)
	check(not guard.armed and completions.size() == before,kind+" observer Stop prevents finished/native application")
	check(provider.last_request_timing.status == "cancelled",kind+" observer retains cancelled generation timing")

func stalled_server(mode: String, partial_body: bool = false) -> void:
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,mode+" listener binds")
	var before := completions.size()
	var seconds := 0.15 if mode == "timeout" else 5.0
	provider.send("LM Studio","http://127.0.0.1:%d/v1" % listener.get_local_port(),mode,"","Return []","rules",4096,seconds)
	var peer: StreamPeerTCP = await receive_request(listener)
	check(peer != null and provider.active,mode+" receives actual POST before control action")
	if peer != null and partial_body:
		peer.put_data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 1024\r\n\r\n{".to_utf8_buffer())
	for i: int in range(3): await process_frame
	var began_usec := Time.get_ticks_usec()
	if mode == "timeout":
		check(await until(func() -> bool: return not provider.active,1500),"header-blackhole timeout remains bounded")
		check(completions.size() == before+1 and str(completions.back().error).contains("timeout"),"blackhole timeout has exactly one explicit failure")
	else:
		provider.cancel("Fixture Stop")
		check(not provider.active and completions.size() == before,mode+" cancels without an assistant callback")
	var elapsed_usec := Time.get_ticks_usec() - began_usec
	measured[mode] = elapsed_usec
	check(elapsed_usec < 1000000,mode+" does not wait for the server to finish")
	if peer != null: peer.disconnect_from_host()
	listener.stop()
	for i: int in range(3): await process_frame
	check(completions.size() == before+(1 if mode == "timeout" else 0),mode+" fences any late transport callback")

func run() -> void:
	provider = P.new()
	root.add_child(provider)
	provider.finished.connect(func(id: int, text: String, _data: Dictionary, error: String) -> void:
		completions.append({"id":id,"text":text,"error":error}))
	for invalid: float in [0.0,-1.0,INF,NAN,3601.0]:
		check(not provider.send("LM Studio","http://127.0.0.1:1/v1","fixture","","hello","rules",4096,invalid).is_empty(),"invalid timeout explicitly refused")
	check(not provider.active and provider.log_path.is_empty(),"invalid timeout neither dispatches nor writes traffic")
	check(P.request_url("LM Studio","http://[::1]:1234/v1") == "http://[0:0:0:0:0:0:0:1]:1234/v1/chat/completions","dispatch expands only the equivalent IPv6 loopback authority")
	check(P.request_url("LM Studio","http://127.0.0.1:1234/custom/[::1]/v1") == "http://127.0.0.1:1234/custom/[::1]/v1/chat/completions","custom endpoint paths are not rewritten by the IPv6 workaround")
	var reply: Dictionary = await exchange("x".repeat(500)+SECRET+"\n"+"y".repeat(2048),404)
	check(str(reply.get("error","")).contains("HTTP 404") and str(reply.get("error","")).length() < 600,"HTTP failure projection is bounded and actionable")
	check(not str(reply.get("error","")).contains(SECRET.left(12)),"redaction precedes excerpt so no partial key escapes")
	check(provider.traffic.contains("[redacted]") and not provider.traffic.contains(SECRET),"full failed response remains redacted in Traffic")
	check(event_count("assistant") == 0 and event_count("usage") == 0,"HTTP failure creates no fictitious assistant or usage")
	check(provider.last_request_timing.status == "completed" and provider.last_request_timing.callback_usec > 0,"failure records complete callback timing")
	check(provider.last_request_timing.signal_usec > 0 and provider.last_request_timing.transport_wait_usec >= 0,"transport wait and synchronous signal cost are separate")
	for body: String in ["<html>bad gateway</html>","[]",'{"choices":null}']:
		reply = await exchange(body)
		check(not str(reply.get("error","")).is_empty() and str(reply.get("text","")).is_empty(),"malformed response is an explicit failure")
	check(event_count("assistant") == 0 and event_count("usage") == 0,"malformed200 creates no invented assistant or usage")
	var large_error := JSON.stringify({"error":{"message":"x".repeat(500)+SECRET+"y".repeat(1024*1024)}})
	reply = await exchange(large_error)
	check(str(reply.get("error","")).length() < 600 and not str(reply.get("error","")).contains(SECRET.left(12)),"large HTTP200 error is redacted before its bounded UI projection")
	check(FileAccess.get_file_as_string(provider.log_path).contains("y".repeat(1024*1024)),"admitted large response remains complete in the audit")
	check(event_count("assistant") == 0 and event_count("usage") == 0,"large HTTP200 error still creates no artificial assistant/usage")
	measured.large_error_callback = int(provider.last_request_timing.callback_usec)
	measured.large_error_parse = int(provider.last_request_timing.json_parse_usec)
	measured.large_error_audit = int(provider.last_request_timing.response_log_usec)
	measured.large_error_projection = int(provider.last_request_timing.projection_redact_usec)
	var valid := JSON.stringify({"choices":[{"message":{"content":"[]"},"finish_reason":"stop"}],"model":"deployment-fixture","usage":{"prompt_tokens":2,"completion_tokens":1}})
	reply = await exchange(valid)
	check(reply.get("text") == "[]" and reply.get("error") == "","valid request still produces its ordinary assistant reply")
	check(event_count("assistant") == 1 and event_count("usage") == 1,"valid reply retains success audit semantics")
	check(provider.last_audit_timing.stored and provider.last_audit_timing.total_usec >= provider.last_audit_timing.write_usec,"audit receipt isolates synchronous persistence cost")
	var idle_status: String = provider.last_request_timing.status
	provider.cancel("Already idle")
	check(provider.last_request_timing.status == idle_status,"idle Stop does not relabel a completed request as cancelled")
	# A finished observer is allowed to dispatch the next request immediately.
	# The first callback's final timing write must not replace that new request.
	var reserved := TCPServer.new()
	check(reserved.listen(0,"127.0.0.1") == OK,"reserve a verified closed loopback port")
	var closed_endpoint := "http://127.0.0.1:%d/v1" % reserved.get_local_port()
	reserved.stop()
	var successor := {"armed":true,"serial":-1,"old_timing":{}}
	var handler := func(_id: int, _text: String, _data: Dictionary, _error: String) -> void:
		if not successor.armed: return
		successor.armed = false
		successor.old_timing = provider.last_request_timing
		provider.send("LM Studio",closed_endpoint,"successor","","hello","rules",4096,1)
		successor.serial = provider.serial
	provider.finished.connect(handler)
	var completion_start := completions.size()
	provider.send("LM Studio",closed_endpoint,"first","","hello","rules",4096,1)
	check(await until(func() -> bool: return completions.size() >= completion_start+2 and not provider.active),"immediate successor finishes without dropping callbacks")
	provider.finished.disconnect(handler)
	check(provider.last_request_timing.serial == successor.serial and provider.last_request_timing.status == "completed","successor owns its own terminal timing")
	check(successor.old_timing.serial != successor.serial and successor.old_timing.callback_usec > 0,"preceding callback retains a distinct completed receipt")
	check(event_count("assistant") == 1 and event_count("usage") == 1,"absent server receipts do not become assistant replies")
	check(P.usage_projection({"input_tokens":SECRET,"output_tokens":"x".repeat(8192),"total_tokens":INF,"prompt_tokens":-1,"completion_tokens":1.5}).is_empty(),"usage projection rejects text, nonfinite, negative and fractional counters")
	check(P.usage_projection({"input_tokens":3,"output_tokens":4.0}) == {"input_tokens":3,"output_tokens":4.0},"usage projection retains valid finite integer counters")
	var malformed_usage := JSON.stringify({"choices":[{"message":{"content":"[]"}}],"usage":{"input_tokens":SECRET,"output_tokens":"x".repeat(8192)}})
	reply = await exchange(malformed_usage)
	check(reply.get("text") == "[]" and provider.usage.is_empty(),"malformed usage cannot become secret or giant status text")
	check(FileAccess.get_file_as_string(provider.log_path).contains("x".repeat(8192)) and not FileAccess.get_file_as_string(provider.log_path).contains(SECRET),"malformed usage remains complete and redacted in raw response archive")
	var large_model := JSON.stringify({"choices":[{"message":{"content":"[]"}}],"model":SECRET+"m".repeat(1024*1024)})
	reply = await exchange(large_model)
	check(reply.get("text") == "[]" and provider.returned_model.length() < 100 and not provider.returned_model.contains(SECRET.left(12)),"oversized provider model metadata is a bounded truthful projection")
	check(FileAccess.get_file_as_string(provider.log_path).contains("m".repeat(1024*1024)),"complete oversized model metadata remains in redacted response archive")
	check(provider._model_projection({"arbitrary":"metadata"}).begins_with("unknown") and provider._model_projection(SECRET) == "[redacted]","non-string metadata is not stringified and short model IDs remain redacted")
	var pre_dispatch := {"armed":true}
	var pre_dispatch_handler := func() -> void:
		if not pre_dispatch.armed: return
		pre_dispatch.armed = false
		provider.cancel("Stop during request audit")
	provider.traffic_changed.connect(pre_dispatch_handler)
	var refused: String = provider.send("LM Studio",closed_endpoint,"before-dispatch","","hello","rules",4096,1)
	provider.traffic_changed.disconnect(pre_dispatch_handler)
	check(not refused.is_empty() and not provider.active and provider.request == null,"Stop from request audit prevents HTTP dispatch")
	check(provider.last_request_timing.status == "cancelled","pre-dispatch Stop preserves its cancelled timing")
	for kind: String in ["response","usage","assistant"]:
		await stop_during_audit(kind,valid)
	await stalled_server("stop-headers")
	await stalled_server("stop-body",true)
	await stalled_server("timeout")
	var live_probe := P.new()
	root.add_child(live_probe)
	live_probe.log_event("large_live_tail",{"body":"z".repeat(3*1024*1024)})
	check(live_probe.traffic.contains('"kind":"large_live_tail"') and live_probe.traffic.contains('"request":0') and live_probe.traffic.contains('"utc":'),"bounded giant raw tail preserves complete small event metadata")
	check(live_probe.traffic.length() < 1600000 and FileAccess.get_file_as_string(live_probe.log_path).contains("z".repeat(3*1024*1024)),"giant event stays complete on disk while live tail remains bounded")
	var live_archive: String = live_probe.log_path
	live_probe.queue_free()
	await process_frame
	DirAccess.remove_absolute(live_archive)
	# Remove an active provider directly, without relying on panel Stop.
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,"shutdown listener binds")
	provider.send("LM Studio","http://127.0.0.1:%d/v1" % listener.get_local_port(),"shutdown","","hello","rules",4096,10)
	var peer: StreamPeerTCP = await receive_request(listener)
	check(peer != null and provider.active,"shutdown occurs during a genuinely outstanding request")
	var archive: String = provider.log_path
	var count_before_shutdown := completions.size()
	var shutdown_begin_usec := Time.get_ticks_usec()
	provider.queue_free()
	for i: int in range(5): await process_frame
	measured.shutdown = Time.get_ticks_usec() - shutdown_begin_usec
	check(int(measured.shutdown) < 1000000,"outstanding-request teardown stays bounded")
	check(not is_instance_valid(provider) and completions.size() == count_before_shutdown,"provider teardown fences callbacks without a next panel tick")
	check(FileAccess.get_file_as_string(archive).contains('"kind":"cancelled"'),"shutdown records cancellation in the existing session log")
	if peer != null: peer.disconnect_from_host()
	listener.stop()
	DirAccess.remove_absolute(archive)
	print("ART_FAILURE_LIFECYCLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timing_usec":measured}))
	quit(0 if failures.is_empty() else 1)
