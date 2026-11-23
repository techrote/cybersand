extends SceneTree
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
## #744: real localhost HTTP failure + X/Hide while request remains active.
## Uses the ordinary Workbench/Art panel and no paid, external, or model API.
var checks := 0
var failures: Array[String] = []
var host: Control
var wb: Control
var panel: Window
var server_request := ""
var server_ok := false

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
	print("ART_INVALID_MODEL_CHECK ",label," ",value)

func ready() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() and not wb.paint_editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy

func until(predicate: Callable, limit_ms: int = 15000) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return predicate.call()

func serve_invalid_model(listener: TCPServer) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and not listener.is_connection_available():
		await process_frame
	if not listener.is_connection_available():
		listener.stop()
		return
	var peer: StreamPeerTCP = listener.take_connection()
	var incoming := ""
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var count := peer.get_available_bytes()
		if count > 0:
			var chunk := peer.get_data(count)
			if chunk[0] == OK: incoming += (chunk[1] as PackedByteArray).get_string_from_utf8()
		if incoming.contains("\r\n\r\n"):
			var headers := incoming.get_slice("\r\n\r\n",0)
			var length := 0
			for line: String in headers.split("\r\n"):
				if line.to_lower().begins_with("content-length:"):
					length = line.substr(15).strip_edges().to_int()
			if incoming.to_utf8_buffer().size() >= headers.to_utf8_buffer().size() + 4 + length: break
		await process_frame
	server_request = incoming
	# The request must still be alive while the Art window is hidden.
	for i: int in range(12): await process_frame
	var response_body := JSON.stringify({"error":{"message":"model not found " + ("x".repeat(4096)),"type":"invalid_model"}})
	var reply := "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [response_body.to_utf8_buffer().size(),response_body]
	server_ok = peer.put_data(reply.to_utf8_buffer()) == OK
	for i: int in range(16): await process_frame
	peer.disconnect_from_host()
	listener.stop()

func run() -> void:
	root.size = Vector2i(1280,900)
	# Select the same ordinary Shared Workbench route as the established
	# test_art_panel_ui suite; a bare main.tscn otherwise starts another mode.
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	wb = host.shared_workbench
	if not await until(ready,60000):
		check(false,"native Workbench can start")
		finish()
		return
	panel = wb._ensure_art_batches()
	var listener := TCPServer.new()
	if listener.listen(0,"127.0.0.1") != OK:
		check(false,"loopback HTTP server can bind")
		finish()
		return
	panel.change_provider(0)
	panel.input_mode.select(1)
	panel.image_input.button_pressed = false
	panel.endpoint.text = "http://127.0.0.1:%d/v1" % listener.get_local_port()
	panel.model.text = "missing-art-local-model-744"
	panel.input.text = "Return []"
	panel.turn_limit.value = 1
	panel.run_seconds.value = 20
	panel.seconds.value = 10
	panel.minimum_interval.value = 0
	panel.show()
	for i: int in range(3): await process_frame
	var turns_before: int = panel.conversation.size()
	serve_invalid_model.call_deferred(listener)
	var started_usec := Time.get_ticks_usec()
	panel.send_prompt()
	check(panel.provider.active,"real invalid-model HTTP request started")
	panel.hide()
	check(not panel.visible and panel.provider.active,"X/Hide keeps in-flight request active")
	var last := Time.get_ticks_usec()
	var worst_gap_usec := 0
	while Time.get_ticks_usec() - started_usec < 15000000 and panel.provider.active:
		await process_frame
		var now := Time.get_ticks_usec()
		worst_gap_usec = maxi(worst_gap_usec,now-last)
		last = now
	for i: int in range(4): await process_frame
	check(not panel.provider.active and panel.remaining_turns == 0,"failed hidden request terminates without retry")
	check(server_ok and server_request.contains("/v1/chat/completions"),"actual local HTTP POST served")
	check(not panel.visible,"request completion does not reopen hidden Art window")
	check(panel.input_error.begins_with("HTTP 404:"),"missing model surfaces the real HTTP error")
	check(panel.input_error.length() < 750,"error projection remains bounded regardless of response size")
	check(panel.conversation.size() == turns_before+2,"request and failure are each recorded exactly once")
	var archive := FileAccess.get_file_as_string(panel.provider.log_path)
	check(archive.contains("invalid_model") and archive.contains("model not found"),"full error response preserved in session archive")
	var kinds: Array[String] = []
	for line: String in archive.strip_edges().split("\n"):
		var item: Variant = JSON.parse_string(line)
		if item is Dictionary and item.get("kind") is String: kinds.append(item.kind)
	check(kinds.count("response") == 1,"single raw HTTP response receipt")
	check(not kinds.has("assistant") and not kinds.has("usage"),"failed HTTP request writes no fictitious assistant or usage")
	check(worst_gap_usec < 2000000,"hidden invalid-model failure causes no multi-second frame stall")
	print("ART_INVALID_MODEL_METRICS ",JSON.stringify({"max_frame_gap_usec":worst_gap_usec,"request_to_terminal_usec":Time.get_ticks_usec()-started_usec,"logged_events":kinds.size(),"error_length":panel.input_error.length(),"http":404,"hidden":not panel.visible}))
	finish()

func finish() -> void:
	if is_instance_valid(host):
		host.queue_free()
	print("ART_INVALID_MODEL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"ordinary-workbench-localhost"}))
	quit(0 if failures.is_empty() else 1)
