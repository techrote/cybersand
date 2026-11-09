extends SceneTree
## Deterministic fake Responses and monotonic clock; no sleeping or API calls.
const Client = preload("res://scripts/workbench_agent_client.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_RATE_LIMIT: "+reason)

func _initialize() -> void:
	_run.call_deferred()

func _scope() -> Dictionary:
	return {"region":{"x":0,"y":0,"width":32,"height":32},"allowed_materials":["Hard Wall","Empty"],"protected_regions":[]}

func _client(tpm: int = 50000, output_cap: int = 128) -> Node:
	var client := Client.new()
	root.add_child(client)
	client.configure_fake_transport_for_tests(true)
	check(client.configure_rate_test_clock(0),"clock injection failed")
	client.tokens_per_minute = tpm
	client.token_budget = output_cap
	return client

func _start(client: Node) -> void:
	check(client.begin_task("Test bounded local pacing.","fake-no-service",_scope()),"task launch failed")

func _rate_error(code: String = "rate_limit_exceeded") -> Dictionary:
	return {"error":{"type":code,"code":code,"message":"Request was rate limited."}}

func _deliver(client: Node, status: int, body: Dictionary, headers: PackedStringArray = PackedStringArray()) -> void:
	client.receive_fake_response(client.current_epoch(),client._serial,status,body,headers)

func _tool_response(id: String, call: String = "observe-call") -> Dictionary:
	return {"id":id,"status":"completed","usage":{"input_tokens":1000,"output_tokens":100},"output":[{"type":"function_call","name":"observe","call_id":call,"arguments":JSON.stringify({"region":null,"detail":"counts"})}]}

func _errors(client: Node) -> String:
	var text := ""
	for record: Dictionary in client.diagnostic_records():
		if record.get("kind","") == "task.error":
			text += JSON.stringify(record)
	return text

func _run() -> void:
	_test_limits_and_estimates()
	_test_usage_settlement()
	_test_rolling_window()
	_test_stop_and_task_history()
	_test_retry_identity()
	_test_retry_limits()
	_test_classification_and_headers()
	await process_frame
	await process_frame
	print("WB_RATE_LIMIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_limits_and_estimates() -> void:
	var c := _client()
	for invalid: int in [0,1023,10000001]:
		c.tokens_per_minute = invalid
		check(not c.launch_problem("task","model",_scope()).is_empty(),"invalid TPM accepted")
	c.tokens_per_minute = 1024
	c.token_budget = 32768
	_start(c)
	check(not c.is_active() and c._request_count == 0,"impossible single request dispatched or waited indefinitely")
	check(_errors(c).contains("Reduce Toks/inspection"),"impossible request lacks useful action")
	c.queue_free()
	c = _client()
	_start(c)
	check(c._request_count == 1 and c._rate_reservations.size() == 1,"initial HTTP attempt not reserved")
	check(c._estimate_value_tokens({"type":["integer","null"]}) > 0,"JSON-schema array type breaks estimator")
	check(c._estimate_value_tokens({"type":"input_image","image_url":"data:image/png;base64,"+"x".repeat(100000)}) == 4096,"image base64 counted as text tokens")
	c.tokens_per_minute = 10000000
	check(c.activity_snapshot().tokens_per_minute == 50000,"public TPM mutation enlarged active grant")
	c.stop_task()
	c.queue_free()

func _test_rolling_window() -> void:
	var c := _client(15000,10000)
	_start(c)
	var first_serial: int = c._serial
	check(c._request_count == 1,"first actual attempt missing")
	var response: Dictionary = _tool_response("rolling-1")
	response.usage.input_tokens = 7000
	_deliver(c,200,response)
	check(c._context_token_estimate == 7100,"provider usage did not ground chained context")
	check(c.submit_tool_result(c.current_epoch(),"observe-call",{"status":"refused","reason":"test-only"}),"tool continuation refused")
	check(c._queued_estimate <= 15000 and c._queued_estimate >= 10000,"input plus output incorrectly summed")
	check(c.is_active() and c._request_count == 1 and c.pending_fake_payload().is_empty(),"queued wait charged/dispatched another request")
	check(c.activity_snapshot().stage.begins_with("Rate limit wait:"),"waiting state invisible")
	c.tokens_per_minute = 10000000
	c.advance_rate_test_clock(59999)
	check(c._serial == first_serial and c._request_count == 1,"window expired early or active cap changed")
	c.advance_rate_test_clock(1)
	check(c._request_count == 2 and c._serial == first_serial+1,"window expiry failed to dispatch exactly once")
	check(c.pending_fake_payload().get("previous_response_id") == "rolling-1","continuation lost last successful provider identity")
	check(c._rate_reservations.size() == 1,"expired reservations not pruned")
	c.stop_task()
	c.queue_free()

func _test_stop_and_task_history() -> void:
	var c := _client(15000,10000)
	_start(c)
	var obsolete_epoch: int = c.current_epoch()
	var obsolete_serial: int = c._serial
	c.stop_task()
	_start(c)
	check(c._request_count == 0 and c.activity_snapshot().rate_wait_seconds > 0,"task restart reset rolling quota history")
	c.advance_rate_test_clock(1000)
	c.stop_task()
	c.advance_rate_test_clock(120000)
	check(c._request_count == 0 and c.pending_fake_payload().is_empty(),"Stop failed to fence queued dispatch")
	c.receive_fake_response(obsolete_epoch,obsolete_serial,200,_tool_response("obsolete"))
	check(not c.is_waiting_for_tool() and not c.is_active(),"late callback resurrected stopped authority")
	c.queue_free()

func _test_retry_identity() -> void:
	var c := _client(10000000)
	var native_calls := [0]
	c.tool_requested.connect(func(_name: String,_args: Dictionary,_epoch: int,_call: String) -> void: native_calls[0] += 1)
	_start(c)
	var initial: Dictionary = c.pending_fake_payload()
	var old_epoch: int = c.current_epoch()
	var old_serial: int = c._serial
	_deliver(c,429,_rate_error(),PackedStringArray(["Retry-After: 11.852"]))
	check(c._rate_retries == 1 and c._request_count == 1 and c.is_active(),"positive rate error not queued boundedly")
	c.receive_fake_response(old_epoch,old_serial,429,_rate_error(),PackedStringArray(["Retry-After: 11.852"]))
	check(c._rate_retries == 1,"duplicate callback consumed another retry")
	c.advance_rate_test_clock(11851)
	check(c._request_count == 1,"valid Retry-After was shortened")
	c.advance_rate_test_clock(1)
	check(c._request_count == 2 and c.pending_fake_payload() == initial,"retry changed immutable initial input")
	_deliver(c,200,_tool_response("retry-tool"))
	check(native_calls[0] == 1,"valid tool was not dispatched once")
	check(c.submit_tool_result(c.current_epoch(),"observe-call",{"status":"refused","reason":"native-once"}),"native receipt could not continue")
	var continuation: Dictionary = c.pending_fake_payload()
	check(continuation.get("previous_response_id") == "retry-tool","continuation identity missing")
	_deliver(c,429,_rate_error())
	c.advance_rate_test_clock(19999)
	check(c._request_count == 3,"fallback delay shortened")
	c.advance_rate_test_clock(1)
	check(c._request_count == 4 and c.pending_fake_payload() == continuation,"receipt retry changed payload")
	check(native_calls[0] == 1,"HTTP retry replayed a native tool")
	c.receive_fake_response(old_epoch,old_serial,200,_tool_response("obsolete-success"))
	check(native_calls[0] == 1,"stale retry callback dispatched native work")
	c.stop_task()
	c.queue_free()

func _test_retry_limits() -> void:
	var c := _client(10000000)
	_start(c)
	_deliver(c,429,_rate_error())
	c.advance_rate_test_clock(10000)
	_deliver(c,429,_rate_error())
	c.advance_rate_test_clock(20000)
	_deliver(c,429,_rate_error())
	check(not c.is_active() and c._request_count == 3 and c._rate_retries == 2,"retry count not bounded to two")
	c.queue_free()
	c = _client(10000000)
	c.request_budget = 1
	_start(c)
	_deliver(c,429,_rate_error())
	check(not c.is_active() and c._request_count == 1 and c._rate_retries == 0,"retry escaped request budget")
	c.advance_rate_test_clock(120000)
	check(c._request_count == 1,"budget failure dispatched later")
	c.queue_free()
	c = _client(10000000)
	_start(c)
	_deliver(c,429,_rate_error(),PackedStringArray(["Retry-After: 60.001"]))
	check(not c.is_active() and c._rate_retries == 0,"long Retry-After clamped to earlier retry")
	check(_errors(c).contains("not shortened"),"long server delay lacks explicit disposition")
	c.queue_free()

func _test_classification_and_headers() -> void:
	for code: String in ["insufficient_quota","credit_balance_exhausted","project_spend_limit_exceeded","organization_usage_limit_exceeded","unknown_error"]:
		var c := _client(10000000)
		_start(c)
		_deliver(c,429,_rate_error(code))
		check(not c.is_active() and c._rate_retries == 0,"permanent/unclassified429 retried: "+code)
		c.queue_free()
	for code: String in ["slow_down","rate_limit_error"]:
		var c := _client(10000000)
		_start(c)
		_deliver(c,429,_rate_error(code))
		check(c.is_active() and c._rate_retries == 1,"known positive rate error not retried: "+code)
		c.stop_task()
		c.advance_rate_test_clock(120000)
		check(c._request_count == 1,"Stop failed during retry wait")
		c.queue_free()
	check(Client._retry_after_seconds("11.852",0) == 11.852,"numeric Retry-After precision lost")
	check(Client._retry_after_seconds("Sun, 08 Nov 2026 12:00:30 GMT",1794139200.0) == 30.0,"HTTP-date Retry-After not understood")
	check(Client._retry_after_seconds("invalid",0) < 0 and Client._retry_after_seconds("-1",0) < 0,"malformed/negative Retry-After accepted")

func _test_usage_settlement() -> void:
	var c := _client(50000,32768)
	_start(c)
	_deliver(c,200,_tool_response("settled"))
	check(c._rate_reservations[0].tokens == 1100,"completed request kept unused output reservation")
	check(c.submit_tool_result(c.current_epoch(),"observe-call",{"status":"refused","reason":"test"}),"settled continuation failed")
	check(c._request_count == 2 and not c.pending_fake_payload().is_empty(),"small successful reply forced one request/minute")
	c.stop_task()
	c.queue_free()
