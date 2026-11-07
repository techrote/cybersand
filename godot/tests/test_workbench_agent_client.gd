extends SceneTree
## Fake-provider protocol tests; NO real OpenAI calls and NO simulated native acceptance.
const Client = preload("res://scripts/workbench_agent_client.gd")
const Panel = preload("res://scripts/workbench_agent_panel.gd")

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, detail: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WB_AGENT_528: " + detail)

func _scope() -> Dictionary:
	return {"region": {"x": 1025, "y": -34, "width": 32, "height": 32},
		"allowed_materials": ["Hard Wall", "Empty"],
		"protected_regions": [{"x": 1030, "y": -25, "width": 2, "height": 2}]}

func _response(id: String, calls: Array) -> Dictionary:
	return {"id": id, "status": "completed", "output": calls}

func _tool(name: String, id: String, arguments: Dictionary) -> Dictionary:
	return {"type": "function_call", "call_id": id, "name": name,
		"arguments": JSON.stringify(arguments)}

func _deliver(client: Node, message: Dictionary, status: int = 200) -> void:
	client.receive_fake_response(client.current_epoch(), client._serial, status, message)

func _new_client() -> Node:
	var client := Client.new()
	root.add_child(client)
	client.configure_fake_transport_for_tests(true)
	return client

func _run() -> void:
	await process_frame
	_test_tool_loop_and_stop()
	_test_provider_errors()
	_test_budget_and_duplicates()
	_test_ui_shell()
	print("WB_AGENT_528 fake-provider checks %d, failures %d" % [assertions, failures])
	quit(1 if failures else 0)

func _test_tool_loop_and_stop() -> void:
	var c := _new_client()
	var invocations: Array = []
	var statuses: Array = []
	c.status_changed.connect(func(state: String, _detail: String) -> void: statuses.append(state))
	c.tool_requested.connect(func(name: String, args: Dictionary, epoch: int, call_id: String) -> void:
		invocations.append({"name": name, "args": args, "epoch": epoch, "call_id": call_id}))
	var schemas: Array = c.strict_tools()
	_expect(schemas.size() == 4, "must offer exactly four tools")
	for i: int in range(4):
		_expect(schemas[i].strict and schemas[i].parameters.additionalProperties == false,
			"top-level tool schema must be strict")
		_expect(schemas[i].parameters.required.size() == schemas[i].parameters.properties.size(),
			"strict schema must require all properties")
	_expect(c.begin_task("Build chute", "configured-vision-model", _scope()), "fake task should start")
	_expect(c.pending_fake_payload().parallel_tool_calls == false, "parallel dispatch must be off")
	_deliver(c, _response("response-1", [_tool("observe", "call-1", {"region": null, "detail": "cells"})]))
	_expect(invocations.size() == 1 and invocations[0].name == "observe", "observe not dispatched")
	_expect(c.is_waiting_for_tool(), "native handoff should be pending")
	_expect(c.submit_tool_result(invocations[0].epoch, "call-1",
		{"status": "observed", "observation_id": "native-1", "native_counts": {"Sand": 32}}),
		"native observation result should continue")
	_expect(c._response_id == "response-1" and c._serial == 2, "continuation must retain previous response")
	var op := {"shape": "line", "x": 1028, "y": -25, "x2": 1031, "y2": -25,
		"radius": 0, "material_id": 3, "replace_only_material_id": null}
	_deliver(c, _response("response-2",
		[_tool("prepare_edit", "call-2", {"observation_id": "native-1", "operations": [op]})]))
	_expect(invocations.size() == 2 and invocations[1].name == "prepare_edit", "prepare not dispatched")
	_expect(c.submit_tool_result(invocations[1].epoch, "call-2",
		{"status": "proposed", "proposal_id": "p-1",
		"footprint": [{"x": 1028, "y": -25}, {"x": 1029, "y": -25}]}),
		"prepared footprint not continued")
	_deliver(c, _response("response-3", [_tool("apply_edit", "call-3", {"proposal_id": "p-1"})]))
	_expect(invocations.size() == 3 and invocations[2].name == "apply_edit", "apply not delegated")
	_expect(not c.submit_tool_result(invocations[2].epoch, "wrong-call",
		{"status": "applied", "readback": {}}), "wrong call ID accepted")
	_expect(not c.submit_tool_result(invocations[2].epoch, "call-3",
		{"status": "applied"}), "queue-only applied without readback accepted")
	_expect(not c.is_active(), "unverified apply should fail closed")
	c.queue_free()
	var c2 := _new_client()
	var old_calls: Array = []
	c2.tool_requested.connect(func(n: String, _a: Dictionary, _e: int, _id: String) -> void: old_calls.append(n))
	_expect(c2.begin_task("Test Stop", "configured-vision-model", _scope()), "second task start")
	var e := c2.current_epoch()
	var s := c2._serial
	c2.stop_task("slow response")
	c2.receive_fake_response(e, s, 200, _response("late", [_tool("step", "late-1", {"ticks": 1})]))
	_expect(old_calls.is_empty() and not c2.is_active(), "late response after Stop dispatched")
	_expect(not c2.submit_tool_result(e, "late-1", {"status": "stepped"}),
		"late native receipt after Stop was admitted")
	c2.queue_free()

func _test_provider_errors() -> void:
	for http_status: int in [401, 403, 429, 500]:
		var c := _new_client()
		var states: Array = []
		c.status_changed.connect(func(state: String, _detail: String) -> void: states.append(state))
		_expect(c.begin_task("Attempt", "model", _scope()), "error fixture start")
		_deliver(c, {"id": "failure", "output": []}, http_status)
		_expect(not c.is_active() and states.has("error"), "HTTP %d must fail closed" % http_status)
		c.queue_free()
	var m := _new_client()
	_expect(m.begin_task("Attempt", "model", _scope()), "malformed fixture start")
	_deliver(m, {"id": "bad", "output": "not-an-array"})
	_expect(not m.is_active(), "malformed envelope did not stop")
	m.queue_free()
	var n := _new_client()
	_expect(n.begin_task("Attempt", "model", _scope()), "network fixture start")
	n._handle_transport(n.current_epoch(), n._serial, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
	_expect(not n.is_active(), "timeout did not stop")
	n.queue_free()

func _test_budget_and_duplicates() -> void:
	var c := _new_client()
	c.request_budget = 1
	_expect(c.begin_task("Attempt", "model", _scope()), "budget fixture start")
	_deliver(c, _response("r1", [_tool("observe", "c1", {"region": null, "detail": "summary"})]))
	_expect(c.submit_tool_result(c.current_epoch(), "c1", {"status": "observed", "observation_id": "o"}),
		"observed continuation accepted")
	_expect(not c.is_active(), "second request should be refused at budget")
	c.queue_free()
	var d := _new_client()
	_expect(d.begin_task("Attempt", "model", _scope()), "duplicate fixture start")
	_deliver(d, _response("r1", [_tool("observe", "c1", {"region": null, "detail": "summary"})]))
	_expect(d.submit_tool_result(d.current_epoch(), "c1", {"status": "observed", "observation_id": "o"}),
		"duplicate setup accepted")
	_deliver(d, _response("r2", [_tool("observe", "c1", {"region": null, "detail": "summary"})]))
	_expect(not d.is_active(), "replayed call ID should fail closed")
	d.queue_free()
	var p := _new_client()
	_expect(p.begin_task("Attempt", "model", _scope()), "parallel fixture start")
	_deliver(p, _response("r1", [
		_tool("observe", "c1", {"region": null, "detail": "summary"}),
		_tool("step", "c2", {"ticks": 1})]))
	_expect(not p.is_active(), "parallel model calls should fail closed")
	p.queue_free()

func _test_ui_shell() -> void:
	var panel := Panel.new()
	root.add_child(panel)
	await process_frame
	_expect(panel._start.disabled, "unbound panel must refuse Start")
	panel.bind_authoritative_dispatcher(func(_name: String, _args: Dictionary,
			_epoch: int, _id: String, _client: Node) -> void: pass)
	panel.client.configure_fake_transport_for_tests(true)
	panel._task.text = "Build native chute"
	panel._model.text = "local-test-model"
	panel._on_start()
	_expect(panel.client.is_active(), "bound panel Start should begin")
	panel._model.text = "revised-test-model"
	panel._retire_on_human_change()
	_expect(not panel.client.is_active(), "human task revision must invalidate pending response")
	panel.queue_free()
