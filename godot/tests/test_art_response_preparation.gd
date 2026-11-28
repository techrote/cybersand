extends SceneTree
## Real loopback response bodies exercise the asynchronous value boundary.
const P = preload("res://scripts/art_provider.gd")
const Preparation = preload("res://scripts/art_response_preparation.gd")
const LATE_KEY := "fixture-key-registered-during-response-preparation"
var checks := 0
var failures: Array[String] = []
var completions := 0
var provider: Node
var timings: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_PREPARATION_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func until(predicate: Callable, seconds: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func serve(listener: TCPServer, response: PackedByteArray, fixture: Dictionary) -> void:
	if not await until(listener.is_connection_available):
		fixture.done = true
		return
	var peer := listener.take_connection()
	var incoming := ""
	while not incoming.contains("\r\n\r\n"):
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0: incoming += (peer.get_data(available)[1] as PackedByteArray).get_string_from_utf8()
		await process_frame
	var sent := 0
	while sent < response.size():
		peer.poll()
		var receipt := peer.put_partial_data(response.slice(sent,mini(sent+65536,response.size())))
		if int(receipt[0]) != OK: break
		sent += int(receipt[1])
		await process_frame
	fixture.sent = sent == response.size()
	for _frame: int in range(3): await process_frame
	peer.disconnect_from_host()
	listener.stop()
	fixture.done = true

func begin(body: String, mutate_source: bool = false) -> Dictionary:
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1") == OK,"real preparation fixture binds")
	var data := body.to_utf8_buffer()
	var response := ("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % data.size()).to_utf8_buffer()
	response.append_array(data)
	var fixture := {"sent":false,"done":false,"mutated":false}
	serve.call_deferred(listener,response,fixture)
	check(provider.send("LM Studio","http://127.0.0.1:%d/v1" % listener.get_local_port(),"preparation-fixture","","Return []","rules",4096,10).is_empty(),"large response request dispatches")
	if mutate_source:
		provider.request.request_completed.connect(func(_result: int, _code: int, received_headers: PackedStringArray, received_bytes: PackedByteArray) -> void:
			received_bytes.fill(88)
			if not received_headers.is_empty(): received_headers[0] = "Mutated-After-Handoff: yes"
			fixture.mutated = true)
	check(await until(provider.response_preparation_active),"complete real body enters observable value preparation")
	check(provider.last_request_timing.status == "preparing_response" and provider.response_preparation_jobs == 1,"one pending preparation has explicit status")
	return fixture

func run() -> void:
	for short_key: String in ["body","bo"]:
		var probe := Preparation.new()
		probe.provider_name = "LM Studio"
		probe.transport_result = HTTPRequest.RESULT_SUCCESS
		probe.http_code = 200
		probe.secrets_snapshot = [short_key]
		probe.bytes = '{"choices":[{"message":{"content":"[]"}}]}'.to_utf8_buffer()
		probe.prepare_inline()
		check(probe.valid_object and probe.decoded.text == "[]","short configured key does not erase prepared body access")
		check(not probe.sanitized.has("body") and not probe.sanitized_body.is_empty(),"response property names stay redacted while preview retains an explicit body")
		probe.http_code = 404
		probe.bytes = ("failure "+short_key+" private detail").to_utf8_buffer()
		probe.prepare_inline()
		check(probe.sanitized_body.contains("[redacted]") and not probe.sanitized_body.contains(short_key),"short-key HTTP error preview remains redacted")
	provider = P.new()
	root.add_child(provider)
	provider.finished.connect(func(_id: int, _text: String, _data: Dictionary, _error: String) -> void: completions += 1)
	var body := JSON.stringify({"model":"synthetic","choices":[{"message":{"content":"[]"}}],"usage":{"prompt_tokens":2,"completion_tokens":1},"padding":"Bearer ! sk- nvapi- https:// token authorization api_key "+"x".repeat(4*1024*1024)+LATE_KEY})
	var fixture: Dictionary = await begin(body,true)
	provider.secrets.append(LATE_KEY)
	check(await until(func() -> bool: return not provider.active and Preparation.pending_count() == 0 and fixture.done),"key-change reprepare completes and reaps all handles")
	check(completions == 1 and int(provider.last_request_timing.get("response_preparation_restarts",0)) >= 1,"new key repeats preparation without a second network request or assistant")
	var archive := FileAccess.get_file_as_string(provider.log_path)
	check(not archive.contains(LATE_KEY) and archive.contains("[redacted]"),"key registered during preparation is redacted before publication")
	check(archive.contains("x".repeat(4*1024*1024)),"completed response archive retains the entire admitted body")
	check(fixture.mutated and not archive.contains("Mutated-After-Handoff"),"later transport observers cannot mutate owned worker body or header snapshots")
	timings.completed_callback_usec = provider.last_request_timing.callback_usec
	timings.preparation_usec = provider.last_request_timing.response_preparation_usec
	fixture = await begin(body)
	var count_before := completions
	var cancel_begin := Time.get_ticks_usec()
	provider.cancel("Stop during response preparation")
	timings.stop_usec = Time.get_ticks_usec()-cancel_begin
	check(int(timings.stop_usec) < 1000000 and not provider.active,"Stop does not join response preparation")
	for _attempt: int in range(6):
		check(not provider.send("LM Studio","http://127.0.0.1:1/v1","retry","","hello","rules",4096,1).is_empty(),"rapid Send while cancelled task drains does not queue another body")
	check(provider.peak_response_preparation_jobs == 1,"provider preparation capacity remains one")
	check(await until(func() -> bool: return Preparation.pending_count() == 0 and fixture.done),"cancelled value task is cooperatively stopped and reaped")
	check(completions == count_before and provider.last_request_timing.status == "cancelled","cancelled preparation emits no assistant completion")
	archive = FileAccess.get_file_as_string(provider.log_path)
	check(archive.contains('"response_receipt_committed":false') and archive.contains('"phase":"response_preparation"'),"cancellation honestly records received but unpublished response")
	check(provider.last_request_timing.response_preparation_reaped and provider.last_request_timing.response_preparation_cancelled,"cancelled request records reaping without changing generation outcome")
	fixture = await begin(body)
	var path: String = provider.log_path
	var shutdown_begin := Time.get_ticks_usec()
	provider.queue_free()
	await process_frame
	await process_frame
	timings.owner_free_usec = Time.get_ticks_usec()-shutdown_begin
	check(not is_instance_valid(provider) and int(timings.owner_free_usec) < 1000000,"owner teardown does not wait for the value worker")
	check(await until(func() -> bool: return Preparation.pending_count() == 0 and fixture.done),"independent reaper retires task after provider destruction")
	check(completions == count_before,"destroyed provider receives no late completion")
	DirAccess.remove_absolute(path)
	print("ART_RESPONSE_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}))
	quit(0 if failures.is_empty() else 1)
