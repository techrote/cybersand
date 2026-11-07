extends Node
## WB-AGENT #528: nonblocking Responses API transport and STRICT model/tool boundary.
## No World access. #526/#527 supply every native operation through tool_requested.
## This component is not an authority, an edit receipt, or a new simulation owner.

signal tool_requested(name: String, arguments: Dictionary, epoch: int, call_id: String)
signal status_changed(status: String, detail: String)
signal proposal_changed(footprint: Array)
signal task_finished(outcome: String)

const ENDPOINT := "https://api.openai.com/v1/responses"
const NAMES := ["observe", "prepare_edit", "apply_edit", "step"]
const MAX_TEXT := 8192
const MAX_BODY := 2 * 1024 * 1024
const MAX_TOOL_OUTPUT := 65536

var request_budget := 12
var tool_budget := 32
var token_budget := 2048
var request_timeout_seconds := 25.0

var _epoch := 0
var _serial := 0
var _active := false
var _model := ""
var _scope: Dictionary = {}
var _task_text := ""
var _response_id := ""
var _request_count := 0
var _tool_count := 0
var _pending_call_id := ""
var _pending_tool := ""
var _pending_http: HTTPRequest
var _seen_call_ids: Dictionary = {}
var _fake_transport := false
var _response_waiting := false

func configure_fake_transport_for_tests(enabled: bool) -> void:
	# Tests may deliver provider responses explicitly; never acts on World.
	if _active:
		return
	_fake_transport = enabled

func current_epoch() -> int:
	return _epoch

func is_active() -> bool:
	return _active

func is_waiting_for_tool() -> bool:
	return not _pending_call_id.is_empty()

func _field(t: String, description: String = "") -> Dictionary:
	var value := {"type": t}
	if not description.is_empty():
		value["description"] = description
	return value

func _object(properties: Dictionary, required: Array) -> Dictionary:
	return {"type": "object", "properties": properties, "required": required, "additionalProperties": false}

func strict_tools() -> Array:
	# Strict Responses function schemas: all object properties required and no extras.
	# The operation shape/keys are a provisional adapter to #526, NOT native validation.
	var region := _object({"x": _field("integer"), "y": _field("integer"),
		"width": _field("integer"), "height": _field("integer")},
		["x", "y", "width", "height"])
	var operation := _object({
		"shape": {"type": "string", "enum": ["disc", "line", "rectangle"]},
		"x": _field("integer"), "y": _field("integer"),
		"x2": _field("integer"), "y2": _field("integer"),
		"radius": _field("integer"),
		"material_id": _field("integer"),
		"replace_only_material_id": {"type": ["integer", "null"]}
	}, ["shape", "x", "y", "x2", "y2", "radius", "material_id", "replace_only_material_id"])
	return [
		{"type": "function", "name": "observe", "description": "Read a bounded, source-matched actual workbench observation. No mutation.",
			"strict": true, "parameters": _object({
				"region": {"anyOf": [region, {"type": "null"}]},
				"detail": {"type": "string", "enum": ["summary", "cells"]}
			}, ["region", "detail"])},
		{"type": "function", "name": "prepare_edit", "description": "Preflight a limited proposal; never edits World. Native owner may refuse.",
			"strict": true, "parameters": _object({
				"observation_id": _field("string"),
				"operations": {"type": "array", "items": operation}
			}, ["observation_id", "operations"])},
		{"type": "function", "name": "apply_edit", "description": "Ask authoritative owner to revalidate and apply an existing proposal. Queue acceptance is not applied.",
			"strict": true, "parameters": _object({"proposal_id": _field("string")}, ["proposal_id"])},
		{"type": "function", "name": "step", "description": "Perform 1 to 120 acknowledged native steps, subject to Stop and pause rules.",
			"strict": true, "parameters": _object({"ticks": {"type": "integer", "minimum": 1, "maximum": 120}}, ["ticks"])}
	]

func _valid_arguments(name: String, args: Variant) -> bool:
	if not args is Dictionary:
		return false
	var expected: Array = []
	match name:
		"observe": expected = ["region", "detail"]
		"prepare_edit": expected = ["observation_id", "operations"]
		"apply_edit": expected = ["proposal_id"]
		"step": expected = ["ticks"]
		_: return false
	if args.size() != expected.size():
		return false
	for key: String in expected:
		if not args.has(key):
			return false
	match name:
		"observe":
			if args.detail not in ["summary", "cells"]:
				return false
			if args.region != null:
				if not args.region is Dictionary or args.region.size() != 4:
					return false
				for k: String in ["x", "y", "width", "height"]:
					if not args.region.has(k) or typeof(args.region[k]) != TYPE_INT:
						return false
				if args.region.width < 1 or args.region.height < 1 or args.region.width > 64 or args.region.height > 64:
					return false
		"prepare_edit":
			if not args.observation_id is String or args.observation_id.is_empty():
				return false
			if not args.operations is Array or args.operations.is_empty() or args.operations.size() > 8:
				return false
			for op: Variant in args.operations:
				if not op is Dictionary or op.size() != 8:
					return false
				for field: String in ["shape", "x", "y", "x2", "y2", "radius", "material_id", "replace_only_material_id"]:
					if not op.has(field):
						return false
				if op.shape not in ["disc", "line", "rectangle"]:
					return false
				for field: String in ["x", "y", "x2", "y2", "radius", "material_id"]:
					if typeof(op[field]) != TYPE_INT:
						return false
				if op.replace_only_material_id != null and typeof(op.replace_only_material_id) != TYPE_INT:
					return false
		"apply_edit":
			if not args.proposal_id is String or args.proposal_id.is_empty():
				return false
		"step":
			if typeof(args.ticks) != TYPE_INT or args.ticks < 1 or args.ticks > 120:
				return false
	return true

func begin_task(task: String, model: String, scope: Dictionary) -> bool:
	if _active:
		status_changed.emit("refused", "Stop the current task first.")
		return false
	if task.strip_edges().is_empty() or model.strip_edges().is_empty() or scope.is_empty():
		status_changed.emit("refused", "Task, model and explicit scope are required.")
		return false
	if not _fake_transport and OS.get_environment("OPENAI_API_KEY").is_empty():
		status_changed.emit("refused", "OPENAI_API_KEY not set in this local process environment.")
		return false
	_epoch += 1
	_active = true
	_model = model.strip_edges()
	_scope = scope.duplicate(true)
	_task_text = task.strip_edges()
	_request_count = 0
	_tool_count = 0
	_pending_call_id = ""
	_pending_tool = ""
	_seen_call_ids.clear()
	_response_id = ""
	var instruction := "You operate ONLY the existing shared CyberSand workbench. Use observe before construction. " + 		"Exactly four tools exist. Never assume applied unless a native verified receipt says applied. " + 		"Do not manufacture Sand. Do not modify outside the human-authorized scope, protection, or material allowlist. " + 		"On refusal, revise safely; after Stop never issue further edits. Scope: " + JSON.stringify(_scope)
	var messages: Array = [
		{"role": "developer", "content": instruction},
		{"role": "user", "content": [{"type": "input_text", "text": _task_text}]}
	]
	status_changed.emit("running", "Task started; awaiting model response.")
	_send(messages)
	return true

func stop_task(reason: String = "Human Stop") -> void:
	_epoch += 1
	_active = false
	_pending_call_id = ""
	_pending_tool = ""
	_response_waiting = false
	if is_instance_valid(_pending_http):
		_pending_http.cancel_request()
		_pending_http.queue_free()
	_pending_http = null
	proposal_changed.emit([])
	status_changed.emit("stopped", reason)
	task_finished.emit("stopped")

func invalidate_after_human_change(reason: String) -> void:
	# #526/#527 adapter must call this BEFORE a scope/owner/revision replacement.
	if _active:
		stop_task("Superseded by human change: " + reason)

func _fail(reason: String) -> void:
	if not _active:
		return
	_active = false
	_epoch += 1
	_pending_call_id = ""
	_pending_tool = ""
	_response_waiting = false
	status_changed.emit("error", reason)
	task_finished.emit("error")

func _send(input_items: Array) -> void:
	if not _active:
		return
	if _request_count >= request_budget:
		_fail("Responses API request budget exhausted.")
		return
	_request_count += 1
	_serial += 1
	var nonce := _serial
	var identity := _epoch
	var payload: Dictionary = {
		"model": _model,
		"input": input_items,
		"tools": strict_tools(),
		"tool_choice": "auto",
		"parallel_tool_calls": false,
		"max_output_tokens": token_budget
	}
	if not _response_id.is_empty():
		payload["previous_response_id"] = _response_id
	_response_waiting = true
	if _fake_transport:
		# Only explicit receive_fake_response calls can advance tests.
		status_changed.emit("request", "Fake transport request %d" % _request_count)
		return
	var request := HTTPRequest.new()
	request.timeout = request_timeout_seconds
	request.body_size_limit = MAX_BODY
	add_child(request)
	_pending_http = request
	request.request_completed.connect(func(result: int, status: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		_handle_transport(identity, nonce, result, status, body)
		if is_instance_valid(request):
			request.queue_free()
		if _pending_http == request:
			_pending_http = null)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + OS.get_environment("OPENAI_API_KEY")
	])
	var err := request.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	# Never log request headers; they contain the local API credential.
	if err != OK:
		request.queue_free()
		_pending_http = null
		_fail("Cannot start network request (%d)." % err)

func pending_fake_payload() -> Dictionary:
	# Used by fake-provider tests; never called by live path.
	if not _fake_transport or not _response_waiting:
		return {}
	var p := {"model": _model, "tools": strict_tools(), "parallel_tool_calls": false}
	p["previous_response_id"] = _response_id
	return p

func receive_fake_response(epoch: int, serial: int, http_status: int, body: Dictionary) -> void:
	if not _fake_transport:
		return
	_handle_transport(epoch, serial, HTTPRequest.RESULT_SUCCESS, http_status, JSON.stringify(body).to_utf8_buffer())

func _handle_transport(identity: int, nonce: int, result: int, http_status: int, body: PackedByteArray) -> void:
	if not _active or identity != _epoch or nonce != _serial or not _response_waiting:
		return
	_response_waiting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Network error or timeout (%d)." % result)
		return
	if http_status < 200 or http_status >= 300:
		# Never forward response body; it could contain request-specific sensitive data.
		var kind := "API authentication" if http_status == 401 or http_status == 403 else ("API rate limit" if http_status == 429 else "API HTTP")
		_fail("%s status %d" % [kind, http_status])
		return
	if body.size() > MAX_BODY:
		_fail("Provider response exceeds bounded size.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("id", "") is not String or str(parsed.get("id", "")).is_empty():
		_fail("Malformed Responses API envelope.")
		return
	if not parsed.get("output", null) is Array:
		_fail("Missing model output list.")
		return
	if str(parsed.get("status", "completed")) not in ["completed", "in_progress"]:
		_fail("Model response incomplete or failed.")
		return
	var calls: Array = []
	var messages: Array = []
	for item: Variant in parsed.output:
		if not item is Dictionary:
			_fail("Malformed response output item.")
			return
		if item.get("type", "") == "function_call":
			calls.append(item)
		elif item.get("type", "") == "message":
			messages.append(item)
	if calls.size() > 1:
		_fail("Parallel/duplicate tool calls refused.")
		return
	_response_id = str(parsed.id)
	if calls.is_empty():
		_active = false
		status_changed.emit("completed", "Model turn ended; native result must be checked independently.")
		task_finished.emit("model_finished")
		return
	if _tool_count >= tool_budget:
		_fail("Native tool-call budget exhausted.")
		return
	var call: Dictionary = calls[0]
	var name := str(call.get("name", ""))
	var call_id := str(call.get("call_id", ""))
	if name not in NAMES or call_id.is_empty() or _seen_call_ids.has(call_id):
		_fail("Unknown or repeated tool call ID/name.")
		return
	if not call.get("arguments", null) is String:
		_fail("Malformed tool arguments.")
		return
	var args: Variant = JSON.parse_string(str(call.arguments))
	if not _valid_arguments(name, args):
		_fail("Malformed or out-of-policy tool arguments.")
		return
	_seen_call_ids[call_id] = true
	_tool_count += 1
	_pending_call_id = call_id
	_pending_tool = name
	status_changed.emit("queued", "%s proposed; awaiting authoritative dispatcher." % name)
	tool_requested.emit(name, args, _epoch, call_id)

func submit_tool_result(epoch: int, call_id: String, receipt: Dictionary) -> bool:
	# Called asynchronously only by the shared #526/#527 adapter.
	# A queue-only "success" must NOT become an applied claim.
	if not _active or epoch != _epoch or call_id != _pending_call_id or call_id.is_empty():
		return false
	if receipt.is_empty():
		_fail("Empty/unconfirmed authoritative tool result.")
		return false
	var status := str(receipt.get("status", "unconfirmed"))
	if status not in ["proposed", "queued", "applied", "refused", "error", "unconfirmed", "observed", "stepped"]:
		_fail("Invalid authoritative receipt status.")
		return false
	if _pending_tool == "apply_edit" and status == "applied" and not receipt.has("readback"):
		_fail("Apply receipt lacks native readback.")
		return false
	if _pending_tool == "prepare_edit" and status == "proposed":
		if not receipt.get("footprint", null) is Array:
			_fail("Prepared edit lacks authoritative footprint.")
			return false
		proposal_changed.emit(receipt.footprint)
	if _pending_tool == "apply_edit" and status in ["applied", "refused", "error", "unconfirmed"]:
		proposal_changed.emit([])
	var output := JSON.stringify(receipt)
	if output.length() > MAX_TOOL_OUTPUT:
		_fail("Native receipt exceeds bounded result limit.")
		return false
	status_changed.emit(status, "%s: %s" % [_pending_tool, status])
	_pending_call_id = ""
	_pending_tool = ""
	# The API receives only bounded, previously verified authoritative results.
	_send([{"type": "function_call_output", "call_id": call_id, "output": output}])
	return true

func _exit_tree() -> void:
	if _active:
		stop_task("Panel/scene exited")
