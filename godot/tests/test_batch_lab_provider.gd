extends SceneTree
## Self-contained loopback HTTP protocol fixture, not real model inference.
## Accepted fixture responses still execute through the actual native owner.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const SECRET := "batch-fixture-secret-opaque"
var controller: Node
var server := TCPServer.new()
var peers: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var checks := 0
var failures: Array[String] = []
var port := 0
var evidence := ""
var fixture_thread := Thread.new()
var fixture_mutex := Mutex.new()
var fixture_stopping := false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("BATCH_PROVIDER_CHECK ",checks," ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func _serve() -> void:
	while server.is_connection_available():
		peers.append({"peer":server.take_connection(),"buffer":PackedByteArray(),"ready":false})
	for index: int in range(peers.size()-1,-1,-1):
		var entry: Dictionary = peers[index]
		var peer: StreamPeerTCP = entry.peer
		peer.poll()
		if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
			peers.remove_at(index)
			continue
		if not entry.ready:
			var available := peer.get_available_bytes()
			if available>0:
				var incoming := peer.get_data(available)
				if incoming[0]!=OK: continue
				entry.buffer.append_array(incoming[1])
			var text: String = entry.buffer.get_string_from_utf8()
			var boundary := text.find("\r\n\r\n")
			if boundary<0: continue
			var expected := 0
			for header: String in text.left(boundary).split("\r\n"):
				if header.to_lower().begins_with("content-length:"): expected = int(header.get_slice(":",1).strip_edges())
			if entry.buffer.size()<boundary+4+expected: continue
			var packet: Variant = JSON.parse_string(entry.buffer.slice(boundary+4,boundary+4+expected).get_string_from_utf8())
			if not packet is Dictionary:
				peer.disconnect_from_host(); peers.remove_at(index); continue
			fixture_mutex.lock()
			requests.append(packet.duplicate(true))
			fixture_mutex.unlock()
			entry.ready = true
			entry.packet = packet
			entry.due = Time.get_ticks_msec()+(1800 if packet.model=="protocol-timeout" else (400 if packet.model=="protocol-cancel" else 0))
		if entry.ready and Time.get_ticks_msec()>=int(entry.due):
			var program: Array = [{"shape":"rectangle","x0":12,"y0":12,"x1":14,"y1":14,"material":58}]
			if entry.packet.model=="protocol-oversized-program":
				program.clear()
				for ignored: int in 4097: program.append({"shape":"pixels","points":[[1,1]],"material":58})
			var content := "invalid drawing output "+SECRET if entry.packet.model=="protocol-malformed" else JSON.stringify(program)
			var body := JSON.stringify({"model":"loopback-protocol-fixture-only",
				"choices":[{"message":{"content":content},"finish_reason":"stop"}],
				"usage":{"prompt_tokens":123,"completion_tokens":9,"credential_echo":SECRET,"authorization":SECRET}}).to_utf8_buffer()
			var header := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: %d\r\n\r\n" % body.size()
			var wire := header.to_utf8_buffer(); wire.append_array(body)
			peer.put_data(wire)
			peer.disconnect_from_host()
			peers.remove_at(index)

func _server_loop() -> void:
	while true:
		fixture_mutex.lock()
		var stopping := fixture_stopping
		fixture_mutex.unlock()
		if stopping: break
		_serve()
		OS.delay_msec(1)
	for entry: Dictionary in peers: entry.peer.disconnect_from_host()
	peers.clear()
	server.stop()

func _request_count() -> int:
	fixture_mutex.lock()
	var count := requests.size()
	fixture_mutex.unlock()
	return count

func _last_request() -> Dictionary:
	fixture_mutex.lock()
	var value: Dictionary = requests.back().duplicate(true) if not requests.is_empty() else {}
	fixture_mutex.unlock()
	return value

func _close_server() -> void:
	fixture_mutex.lock(); fixture_stopping=true; fixture_mutex.unlock()
	if fixture_thread.is_started(): fixture_thread.wait_to_finish()
	else: server.stop()

func settle(label: String, timeout_ms := 15000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while controller.is_running() and Time.get_ticks_msec()<deadline:
		await process_frame
	return check(not controller.is_running(),label)

func run_case(model: String) -> void:
	var config := Controller.defaults()
	config.provider = "LM Studio"
	config.model = model
	config.endpoint = "http://127.0.0.1:%d/v1" % port
	config.max_output_tokens = 64
	config.timeout_seconds = 1
	config.source_rectangles = [[13,13,1,1,28]]
	config.protection = [[20,20,3,3]]
	check(controller.configure_tile(0,config).ok and controller.start([0]).ok,"queued "+model)
	await settle(model+" terminal")

func run() -> void:
	evidence = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	controller = Controller.new(); root.add_child(controller)
	await process_frame
	for candidate: int in range(46000+OS.get_process_id()%1000,48000):
		if server.listen(candidate,"127.0.0.1")==OK: port=candidate; break
	if not check(port!=0,"keyless loopback protocol fixture started"): finish(); return
	if not check(fixture_thread.start(_server_loop)==OK,"loopback server runs independently of HTTP cancellation callbacks"): finish(); return
	controller.set_credential("LM Studio",SECRET)
	for endpoint: String in ["http://[::1]evil/v1","http://localhost:/v1","http://localhost:99999/v1","http://user:pass@localhost/v1","http://localhost/v1?api_key=test","https://api.openai.com/v1"]:
		check(not Controller.local_endpoint(endpoint),"unsafe or public endpoint refused")
	check(Controller.local_endpoint("http://[::1]:1234/v1") and Controller.local_endpoint("http://192.168.1.9:1234/v1"),"bounded literal local endpoints supported")
	check(not controller.configure_tile(0,{"endpoint":"http://localhost/v1?token=private"}).ok,"credential-bearing endpoint refused before persistence")
	check(not controller.configure_tile(0,{"prompt":"contains "+SECRET}).ok,"configured secret cannot enter prompt provenance")
	await run_case("protocol-malformed")
	check(controller.tiles[0].state=="refused" and controller.tiles[0].material_cells.is_empty(),"malformed provider output never becomes native edits")
	check(controller.tiles[0].model_response.contains("[redacted]") and not JSON.stringify(controller.attempts.back()).contains(SECRET),"response and usage echoes redact volatile credentials")
	check(not controller.replay(0).ok,"refused response cannot replay unrelated configuration placeholders")
	await run_case("protocol-oversized-program")
	check(controller.tiles[0].state=="refused" and controller.tiles[0].reason.contains("4096") and controller.tiles[0].material_cells.is_empty(),"returned program obeys bounded admission before native writes")
	await run_case("protocol-timeout")
	check(controller.tiles[0].state=="refused" and controller.tiles[0].reason.contains("timeout"),"slow local endpoint timeout is visible and recoverable")
	var config := Controller.defaults()
	config.provider="LM Studio"; config.model="protocol-cancel"; config.endpoint="http://127.0.0.1:%d/v1" % port
	config.source_rectangles=[[13,13,1,1,28]]; config.timeout_seconds=5
	var prior_requests := _request_count()
	check(controller.configure_tile(0,config).ok and controller.start([0]).ok,"slow cancellation request queued")
	var deadline := Time.get_ticks_msec()+5000
	while _request_count()==prior_requests and Time.get_ticks_msec()<deadline: await process_frame
	check(_request_count()==prior_requests+1,"slow request actually reached loopback transport")
	var stop_started := Time.get_ticks_msec()
	controller.stop([0])
	check(Time.get_ticks_msec()-stop_started<1000,"local inference Stop returns within its bounded responsiveness gate")
	check(controller.tiles[0].state=="stopped" and controller.tiles[0].material_cells.is_empty(),"Stop during inference retains no queued native edits")
	var stopped_id: String = controller.tiles[0].attempt_id
	await run_case("protocol-valid")
	var tile: Dictionary = controller.tiles[0]
	check(tile.state=="completed" and int(tile.metrics.get("changed",0))==8 and tile.material_cells.decode_u16((13*128+13)*2)==28,
		"protocol fixture output performs eight actual native changes and protects original Metal")
	check(tile.attempt_id!=stopped_id and not tile.receipts.is_empty(),"cancelled request cannot replace the retry's actual native receipt")
	var actual_request := _last_request()
	var instructions := str(actual_request.messages[0].content)
	check(instructions.contains(JSON.stringify([13,13,1,28])) and instructions.contains(JSON.stringify([[20,20,3,3]])) \
		and instructions.contains(str(tile.provenance.source_material_sha256)),"local provider receives exact bounded source runs, hash and protection")
	check(int(actual_request.max_tokens)==64,"requested output budget is enforced on actual transport")
	var hash: String = tile.material_sha256
	deadline = Time.get_ticks_msec()+700
	while Time.get_ticks_msec()<deadline: await process_frame
	check(controller.tiles[0].material_sha256==hash and not controller.is_running(),"retired slow callbacks cannot alter a completed retry")
	_close_server()
	await run_case("protocol-unavailable")
	check(controller.tiles[0].state=="refused" and controller.tiles[0].material_cells.is_empty(),"missing local server refuses without native changes")
	var path := "user://batch-lab-provider-protocol.json" if evidence.is_empty() else evidence.path_join("provider-session.json")
	check(controller.save_session(path).ok,"all malformed, oversized, timeout, stopped and successful attempts saved")
	var file := FileAccess.open(path,FileAccess.READ)
	check(file!=null and not file.get_as_text().contains(SECRET),"session export contains no volatile key")
	if file!=null: file.close()
	var count: int = controller.attempts.size()
	var loaded: Dictionary = controller.load_session(path)
	check(loaded.ok and controller.attempts.size()==count,"rejected returned programs remain safely reopenable / "+str(loaded.get("reason","")))
	finish()

func finish() -> void:
	_close_server()
	var summary := {"checks":checks,"failures":failures,"actual_model_calls":0,
		"scope":"loopback HTTP protocol fixture; accepted fixture program executes on actual CyberNativeCellWorld",
		"requests":requests.size(),"retained_attempts":controller.attempts.size()}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("provider-summary.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(summary,"  ")); file.close()
	print("BATCH_PROVIDER_RESULT ",JSON.stringify(summary))
	controller.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
