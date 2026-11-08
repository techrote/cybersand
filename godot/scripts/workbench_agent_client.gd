extends Node
## WB-AGENT #528: nonblocking Responses API transport and STRICT model/tool boundary.
## No World access. #526/#527 supply every native operation through tool_requested.
## This component is not an authority, an edit receipt, or a new simulation owner.

signal tool_requested(name: String, arguments: Dictionary, epoch: int, call_id: String)
signal status_changed(status: String, detail: String)
signal model_report_received(report: String)
signal proposal_changed(footprint: Array)
signal task_finished(outcome: String)
signal diagnostic_event(record: Dictionary)
const Diagnostics = preload("res://scripts/workbench_agent_diagnostics.gd")
var _diagnostics := Diagnostics.new()
var _stage := "Ready"
var _input_tokens := -1
var _output_tokens := -1
var _usage_ids := {}
var _usage_complete := true

const ENDPOINT := "https://api.openai.com/v1/responses"
const NAMES := ["observe", "prepare_edit", "apply_edit", "step"]
const MAX_TEXT := 8192
const MAX_MODEL_REPORT := 1024
const MAX_BODY := 2 * 1024 * 1024
## 4096 native rows may each contain two signed 32-bit coordinates and
## before/after IDs. Reserve 112 characters per row plus 64 KiB for bounded
## identity/count/palette metadata. Images have their separate existing cap.
const MAX_CELL_LIMIT := 65536
const MAX_TOOL_OUTPUT := MAX_CELL_LIMIT * 112 + 65536
# Host-selected budgets are validated and frozen together at Start.
# Neither the model nor a tool result may expand an active task's allowance.
const DEFAULT_REQUEST_BUDGET := 128
const MAX_REQUEST_BUDGET := 4096
const DEFAULT_TOOL_BUDGET := 256
const MAX_TOOL_BUDGET := 8192
const DEFAULT_TOKEN_BUDGET := 32768
const MAX_TOKEN_BUDGET := 131072
const DEFAULT_REQUEST_TIMEOUT := 180
const MAX_REQUEST_TIMEOUT := 600
const DEFAULT_TOKENS_PER_MINUTE := 50000
const MIN_TOKENS_PER_MINUTE := 1024
const MAX_TOKENS_PER_MINUTE := 10000000
const RATE_WINDOW_MSEC := 60000
const MAX_RATE_RETRIES := 2
const MAX_RETRY_DELAY_SECONDS := 60.0
const MAX_RETRY_WAIT_SECONDS := 120.0
# Permit one non-mutating model argument correction per task; no native replay.
const MAX_ARGUMENT_REPAIRS := 1
# Transport parses signed native coordinates without granting out-of-domain
# authority. #526's exclusive worker still validates its finite canvas.
const MIN_WORLD_COORD: int = -2147483648
const MAX_WORLD_COORD: int = 2147483647

var request_budget := DEFAULT_REQUEST_BUDGET
var _active_request_budget := DEFAULT_REQUEST_BUDGET
var tool_budget := DEFAULT_TOOL_BUDGET
var token_budget := DEFAULT_TOKEN_BUDGET
var _active_tool_budget := DEFAULT_TOOL_BUDGET
var _active_token_budget := DEFAULT_TOKEN_BUDGET
var request_timeout_seconds: float = DEFAULT_REQUEST_TIMEOUT
var _active_request_timeout_seconds: float = DEFAULT_REQUEST_TIMEOUT
var tokens_per_minute: int = DEFAULT_TOKENS_PER_MINUTE
var _active_tokens_per_minute: int = DEFAULT_TOKENS_PER_MINUTE
# Host-local reservation history intentionally survives Stop and task restarts.
# This is an estimate, not a discovery of the provider/project's actual limits.
var _rate_reservations: Array[Dictionary] = []
var _rate_test_now_msec: int = -1
var _context_token_estimate: int = 0
var _queued_payload: Dictionary = {}
var _queued_epoch: int = -1
var _queued_estimate: int = 0
var _queued_earliest_msec: int = 0
var _last_sent_payload: Dictionary = {}
var _last_sent_estimate: int = 0
var _rate_retries: int = 0
var _retry_wait_seconds: float = 0.0

var _epoch := 0
var _serial := 0
var _active := false
var _model := ""
var _scope: Dictionary = {}
var _task_text := ""
var _response_id := ""
var _request_count := 0
var _tool_count := 0
var _argument_repairs := 0
var _pending_call_id := ""
var _pending_tool := ""
var _pending_http: HTTPRequest
var _seen_call_ids: Dictionary = {}
var _seen_response_ids: Dictionary = {}
var _fake_transport := false
var _last_fake_payload: Dictionary = {}
var _response_waiting := false

func _init() -> void:
	status_changed.connect(func(status: String, detail: String) -> void:
		if status in ["stopped", "error", "completed", "refused"]:
			_stage = {"stopped":"Stopped", "error":"Failed - open Traffic", "completed":"Finished", "refused":"Request refused"}[status]
		record_diagnostic("task." + status, {"detail": detail}))

func record_diagnostic(kind: String, payload: Variant) -> void:
	var record := _diagnostics.append(kind, payload,
		{"epoch": _epoch, "request": _serial, "call_id": _pending_call_id}, not _fake_transport)
	diagnostic_event.emit(record)

func diagnostic_records() -> Array[Dictionary]:
	return _diagnostics.records.duplicate(true)

func diagnostic_directory() -> String:
	return ProjectSettings.globalize_path(_diagnostics.directory)

func export_diagnostics(path: String) -> Error:
	return _diagnostics.export_jsonl(path)

func activity_snapshot() -> Dictionary:
	return {"state": "active" if _active else "idle", "stage": _stage,
		"requests": _request_count, "request_limit": _active_request_budget if _active or _request_count > 0 else request_budget,
		"tools": _tool_count, "tool_limit": _active_tool_budget if _active or _request_count > 0 else tool_budget,
		"input_tokens": _input_tokens, "output_tokens": _output_tokens,
		"token_limit": _active_token_budget if _active or _request_count > 0 else token_budget,
		"timeout": _active_request_timeout_seconds, "dropped_events": _diagnostics.dropped,
		"usage_complete": _usage_complete, "log_error": _diagnostics.disk_error,
		"tokens_per_minute": _active_tokens_per_minute if _active else tokens_per_minute,
		"rate_reserved_tokens": _reserved_tokens(), "rate_estimated_request_tokens": _queued_estimate,
		"rate_wait_seconds": _rate_wait_seconds(), "rate_retries": _rate_retries}

func _cell_limit() -> int:
	return int(_scope.get("cell_limit", 4096)) if _active else 4096

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

func _disc_radius_limit() -> int:
	return mini(144, int(sqrt(float(_cell_limit()) / PI)))

func _field(t: String, description: String = "") -> Dictionary:
	var value := {"type": t}
	if not description.is_empty():
		value["description"] = description
	return value

func _object(properties: Dictionary, required: Array) -> Dictionary:
	return {"type": "object", "properties": properties, "required": required, "additionalProperties": false}

func _primitive_schema(shape: String, coordinates: Array) -> Dictionary:
	var properties: Dictionary = {
		"shape":{"type":"string","enum":[shape]},
		"material":{"type":"integer","enum":[0,58]},
		"replace_only_material":{"type":["integer","null"]}
	}
	var fields: Array = ["shape","material","replace_only_material"]
	for key: String in coordinates:
		properties[key] = _field("integer")
		fields.append(key)
	if shape == "disc":
		properties["radius"]["minimum"] = 0
		properties["radius"]["maximum"] = _disc_radius_limit()
	return _object(properties,fields)

func strict_tools() -> Array:
	# Exact #526 v1 shape-specific model envelope; #527 owns step's native
	# implementation. Strict JSON remains separate from native authorization.
	var region := _object({"x":_field("integer"),"y":_field("integer"),
		"width":_field("integer"),"height":_field("integer")},
		["x","y","width","height"])
	var operations: Dictionary = {"type":"array","items":{"anyOf":[
		_primitive_schema("disc",["x","y","radius"]),
		_primitive_schema("line",["x0","y0","x1","y1"]),
		_primitive_schema("rectangle",["x0","y0","x1","y1"])
	]}}
	return [
		{"type":"function","name":"observe","strict":true,
			"description":"Read up to the authorized cell_limit native cells AND a matching original post-draw PNG. Explicit region selects a bounded window inside task scope. null selects the whole scope if it fits, otherwise a bounded camera-centered window clamped inside scope. Read the returned exact region and viewport mapping; counts describe that inspection, not the whole canvas.",
			"parameters":_object({"region":{"anyOf":[region,{"type":"null"}]},
				"detail":{"type":"string","enum":["cells","counts"]}},
				["region","detail"])},
		{"type":"function","name":"prepare_edit","strict":true,
			"description":"Preflight 1-8 Hard Wall/Empty native operations covering at most the authorized cell_limit distinct cells inside the authorized task scope; zero mutation.",
			"parameters":_object({"observation_id":_field("string"),
				"operations":operations},["observation_id","operations"])},
		{"type":"function","name":"apply_edit","strict":true,
			"description":"Apply existing opaque proposal with authoritative native readback.",
			"parameters":_object({"proposal_id":_field("string")},["proposal_id"])},
		{"type":"function","name":"step","strict":true,
			"description":"Only after #527 owner ACK: request 1-120 bounded native ticks.",
			"parameters":_object({"ticks":{"type":"integer","minimum":1,"maximum":120}},
				["ticks"])}
	]

func _safe_integer(value: Variant) -> bool:
	# Godot JSON.parse_string can decode integer-shaped JSON numbers as floats.
	# Convert only exactly representable finite integers, NEVER truncated fractions.
	if typeof(value) == TYPE_INT:
		return abs(float(value)) <= 9007199254740991.0
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and abs(value) <= 9007199254740991.0 and floor(value) == value
	return false

func _normalise_arguments(name: String, args: Dictionary) -> Dictionary:
	var result := args.duplicate(true)
	if name == "step":
		result["ticks"] = int(args.ticks)
	elif name == "observe" and args.region is Dictionary:
		for key: String in ["x","y","width","height"]:
			result.region[key] = int(args.region[key])
	elif name == "prepare_edit":
		for op: Dictionary in result.operations:
			for key: String in op.keys():
				if key in ["x","y","x0","y0","x1","y1","radius","material"]:
					op[key] = int(op[key])
			# Typed #526 envelope: JSON null becomes ABSENT filter, never Empty.
			if op.get("replace_only_material",null) == null:
				op.erase("replace_only_material")
			else:
				op["replace_only_material"] = int(op["replace_only_material"])
	return result

func _valid_arguments(name: String, args: Variant) -> bool:
	if not args is Dictionary:
		return false
	var expected: Array = []
	match name:
		"observe": expected = ["region","detail"]
		"prepare_edit": expected = ["observation_id","operations"]
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
			if args.detail not in ["cells","counts"]:
				return false
			if args.region != null:
				if not args.region is Dictionary or args.region.size() != 4:
					return false
				for key: String in ["x","y","width","height"]:
					if not args.region.has(key) or not _safe_integer(args.region[key]):
						return false
				if args.region.x < MIN_WORLD_COORD or args.region.y < MIN_WORLD_COORD 						or args.region.width < 1 or args.region.height < 1 						or args.region.width > _cell_limit() or args.region.height > _cell_limit() 						or args.region.width * args.region.height > _cell_limit() 						or args.region.x + args.region.width > MAX_WORLD_COORD 						or args.region.y + args.region.height > MAX_WORLD_COORD:
					return false
		"prepare_edit":
			if not args.observation_id is String or args.observation_id.is_empty() 					or args.observation_id.length() > 128:
				return false
			if not args.operations is Array or args.operations.is_empty() or args.operations.size() > 8:
				return false
			for item: Variant in args.operations:
				if not item is Dictionary or not item.has("shape"):
					return false
				var coordinates: Array = []
				match item.shape:
					"disc": coordinates = ["x","y","radius"]
					"line","rectangle": coordinates = ["x0","y0","x1","y1"]
					_: return false
				var keys: Array = ["shape","material","replace_only_material"]
				keys.append_array(coordinates)
				if item.size() != keys.size():
					return false
				for key: String in keys:
					if not item.has(key):
						return false
				for key: String in coordinates:
					if not _safe_integer(item[key]):
						return false
					# Negative world positions are valid signed coordinates;
					# radius is a nonnegative length, not a position.
					if key == "radius":
						if item[key] < 0 or item[key] > _disc_radius_limit():
							return false
					elif item[key] < MIN_WORLD_COORD or item[key] > MAX_WORLD_COORD:
						return false
				if not _safe_integer(item.material) or int(item.material) not in [0,58]:
					return false
				if item.replace_only_material != null and (
						not _safe_integer(item.replace_only_material) 						or int(item.replace_only_material) not in [0,58]):
					return false
				if item.shape == "disc" and (item.x - item.radius < MIN_WORLD_COORD \
						or item.y - item.radius < MIN_WORLD_COORD \
						or item.x + item.radius > MAX_WORLD_COORD \
						or item.y + item.radius > MAX_WORLD_COORD):
					return false
				if item.shape == "rectangle" and (
						item.x1 < item.x0 or item.y1 < item.y0):
					return false
		"apply_edit":
			if not args.proposal_id is String or args.proposal_id.is_empty() 					or args.proposal_id.length() > 128:
				return false
		"step":
			if not _safe_integer(args.ticks) or args.ticks < 1 or args.ticks > 120:
				return false
	return true

# Check all local Start prerequisites BEFORE the Godot panel asks #526/#527 to
# acquire native authoring authority. No network request or World access here.
# begin_task rechecks after the asynchronous native authorization boundary.
func launch_problem(task: String, model: String, scope: Dictionary) -> String:
	if task.strip_edges().is_empty() or model.strip_edges().is_empty() or scope.is_empty():
		return "Task, model and explicit scope are required."
	if request_budget < 1 or request_budget > MAX_REQUEST_BUDGET:
		return "Request budget must be between 1 and %d." % MAX_REQUEST_BUDGET
	if tool_budget < 1 or tool_budget > MAX_TOOL_BUDGET:
		return "Tool-call budget must be between 1 and %d." % MAX_TOOL_BUDGET
	if token_budget < 1 or token_budget > MAX_TOKEN_BUDGET:
		return "Output-token budget must be between 1 and %d; choose a value supported by the model." % MAX_TOKEN_BUDGET
	if not is_finite(request_timeout_seconds) or request_timeout_seconds < 1 or request_timeout_seconds > MAX_REQUEST_TIMEOUT:
		return "Request timeout must be finite and between 1 and %d seconds." % MAX_REQUEST_TIMEOUT
	if tokens_per_minute < MIN_TOKENS_PER_MINUTE or tokens_per_minute > MAX_TOKENS_PER_MINUTE:
		return "TPM must be between %d and %d; enter your actual provider/project limit." % [MIN_TOKENS_PER_MINUTE,MAX_TOKENS_PER_MINUTE]
	if not _safe_integer(scope.get("cell_limit",4096)) or int(scope.get("cell_limit",4096)) < 1 or int(scope.get("cell_limit",4096)) > MAX_CELL_LIMIT:
		return "Cells must be between 1 and %d." % MAX_CELL_LIMIT
	if not _fake_transport and OS.get_environment("OPENAI_API_KEY").is_empty():
		return "OPENAI_API_KEY is not set. Configure the local launch environment and restart the client."
	return ""


func begin_task(task: String, model: String, scope: Dictionary) -> bool:
	if _active:
		status_changed.emit("refused", "Stop the current task first.")
		return false
	var problem: String = launch_problem(task, model, scope)
	if not problem.is_empty():
		status_changed.emit("refused", problem)
		return false
	_epoch += 1
	_active = true
	_model = model.strip_edges()
	_scope = scope.duplicate(true)
	_task_text = task.strip_edges()
	_request_count = 0
	_active_request_budget = request_budget
	_active_tool_budget = tool_budget
	_active_token_budget = token_budget
	_active_request_timeout_seconds = request_timeout_seconds
	_active_tokens_per_minute = tokens_per_minute
	_context_token_estimate = 0
	_queued_payload.clear()
	_queued_epoch = -1
	_last_sent_payload.clear()
	_rate_retries = 0
	_retry_wait_seconds = 0.0
	_tool_count = 0
	_input_tokens = -1
	_output_tokens = -1
	_usage_ids.clear()
	_usage_complete = true
	_argument_repairs = 0
	_pending_call_id = ""
	_pending_tool = ""
	_seen_call_ids.clear()
	_seen_response_ids.clear()
	_response_id = ""
	var instruction := "You operate ONLY the existing shared CyberSand workbench. Use observe before construction. " + 		"Exactly four tools exist. Never assume applied unless a native verified receipt says applied. " + 		"Do not manufacture Sand. Do not modify outside the human-authorized scope, protection, or material allowlist. " + 		"On refusal, revise safely; after Stop never issue further edits. Scope: " + JSON.stringify(_scope)
	var messages: Array = [
		{"role": "developer", "content": instruction},
		{"role": "user", "content": [{"type": "input_text", "text": _task_text}]}
	]
	status_changed.emit("running", "Task started: %d requests, %d tool calls, %d output tokens/response, %ds timeout authorized." % [_active_request_budget, _active_tool_budget, _active_token_budget, int(_active_request_timeout_seconds)])
	_send(messages)
	return true

func stop_task(reason: String = "Human Stop") -> void:
	_epoch += 1
	_active = false
	_pending_call_id = ""
	_pending_tool = ""
	_response_waiting = false
	_queued_payload.clear()
	_queued_epoch = -1
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
	_queued_payload.clear()
	_queued_epoch = -1
	# A terminal provider/client failure retires the pending native plan.
	# Clear its presentation-only footprint; never imply it was applied.
	proposal_changed.emit([])
	status_changed.emit("error", reason)
	task_finished.emit("error")

func _send(input_items: Array) -> void:
	if not _active:
		return
	if _request_count >= _active_request_budget:
		_fail("Responses API request budget exhausted.")
		return
	var payload: Dictionary = {
		"model": _model,
		"input": input_items,
		"tools": strict_tools(),
		"tool_choice": "auto",
		"parallel_tool_calls": false,
		"max_output_tokens": _active_token_budget
	}
	if not _response_id.is_empty():
		payload["previous_response_id"] = _response_id
	_queue_rate_payload(payload,_now_msec())

func _now_msec() -> int:
	return _rate_test_now_msec if _fake_transport and _rate_test_now_msec >= 0 else Time.get_ticks_msec()

func _rate_enabled() -> bool:
	return not _fake_transport or _rate_test_now_msec >= 0

func configure_rate_test_clock(now_msec: int = 0) -> bool:
	# Explicit deterministic opt-in; ordinary fake-provider/native tests stay fast.
	if not _fake_transport or _active or now_msec < 0:
		return false
	_rate_test_now_msec = now_msec
	return true

func advance_rate_test_clock(milliseconds: int) -> void:
	if not _fake_transport or _rate_test_now_msec < 0 or milliseconds < 0:
		return
	_rate_test_now_msec += milliseconds
	_pump_rate_limit()

func _process(_delta: float) -> void:
	if _active and not _queued_payload.is_empty():
		_pump_rate_limit()

func _prune_reservations() -> void:
	var cutoff: int = _now_msec() - RATE_WINDOW_MSEC
	while not _rate_reservations.is_empty() and int(_rate_reservations[0].at) <= cutoff:
		_rate_reservations.pop_front()

func _reserved_tokens() -> int:
	_prune_reservations()
	var total := 0
	for reservation: Dictionary in _rate_reservations:
		total += int(reservation.tokens)
	return total

func _estimate_value_tokens(value: Variant) -> int:
	# Low-detail images are not text/base64 tokens. Reserve a separate allowance;
	# tokenization and image accounting still vary by provider/model.
	if value is Dictionary:
		if typeof(value.get("type",null)) == TYPE_STRING and value.type == "input_image":
			return 4096
		var amount := 2
		for key: Variant in value:
			amount += int(ceil(float(str(key).length()) / 3.0)) + _estimate_value_tokens(value[key]) + 2
		return amount
	if value is Array:
		var amount := 2
		for item: Variant in value:
			amount += _estimate_value_tokens(item) + 1
		return amount
	return maxi(1,int(ceil(float(JSON.stringify(value).length()) / 3.0)))

func _estimate_request_tokens(payload: Dictionary) -> int:
	# Last provider input+output usage includes the chained context. Without
	# usage, retain the previous conservative request reservation as its basis.
	# Provider rate accounting uses max(input estimate, output allowance).
	var estimated_input: int = _context_token_estimate + _estimate_value_tokens(payload.get("input",[])) \
		+ _estimate_value_tokens(payload.get("tools",[])) + 256
	return maxi(estimated_input,int(payload.max_output_tokens))

func _queue_rate_payload(payload: Dictionary, earliest_msec: int) -> void:
	if not _active:
		return
	_queued_payload = payload.duplicate(true)
	_queued_epoch = _epoch
	_queued_estimate = _estimate_request_tokens(payload)
	_queued_earliest_msec = earliest_msec
	if _rate_enabled() and _queued_estimate > _active_tokens_per_minute:
		_fail("Estimated request needs %d tokens, above %d TPM. Reduce Toks/inspection or increase TPM to your real provider limit." % [_queued_estimate,_active_tokens_per_minute])
		return
	_pump_rate_limit()
	if _active and not _queued_payload.is_empty():
		record_diagnostic("rate.wait", {"estimated_tokens":_queued_estimate,"reserved_tokens":_reserved_tokens(),"tokens_per_minute":_active_tokens_per_minute,"wait_seconds":_rate_wait_seconds(),"local_estimate":true})
		status_changed.emit("waiting",_stage)

func _next_rate_dispatch_msec() -> int:
	var next: int = maxi(_now_msec(),_queued_earliest_msec)
	if not _rate_enabled():
		return next
	_prune_reservations()
	var total: int = _reserved_tokens()
	var retained: int = _rate_reservations.size()
	for reservation: Dictionary in _rate_reservations:
		if total + _queued_estimate <= _active_tokens_per_minute and retained < MAX_REQUEST_BUDGET:
			break
		total -= int(reservation.tokens)
		retained -= 1
		next = maxi(next,int(reservation.at) + RATE_WINDOW_MSEC)
	return next

func _rate_wait_seconds() -> int:
	if _queued_payload.is_empty() or _queued_epoch != _epoch:
		return 0
	return maxi(0,int(ceil(float(_next_rate_dispatch_msec()-_now_msec()) / 1000.0)))

func _pump_rate_limit() -> void:
	if not _active or _queued_payload.is_empty() or _queued_epoch != _epoch:
		return
	if _request_count >= _active_request_budget:
		_fail("Responses API request budget exhausted.")
		return
	var wait_seconds: int = _rate_wait_seconds()
	if wait_seconds > 0:
		_stage = "Rate limit wait: %ds" % wait_seconds
		return
	var payload: Dictionary = _queued_payload.duplicate(true)
	var estimate: int = _queued_estimate
	_queued_payload.clear()
	_queued_epoch = -1
	_dispatch_payload(payload,estimate)

func _dispatch_payload(payload: Dictionary, estimated_tokens: int) -> void:
	if not _active:
		return
	if _request_count >= _active_request_budget:
		_fail("Responses API request budget exhausted.")
		return
	_request_count += 1
	_serial += 1
	var nonce := _serial
	var identity := _epoch
	_last_sent_payload = payload.duplicate(true)
	_last_sent_estimate = estimated_tokens
	if _rate_enabled():
		_rate_reservations.append({"at":_now_msec(),"tokens":estimated_tokens,"epoch":identity,"request":nonce})
	_response_waiting = true
	_stage = "Waiting for model response"
	record_diagnostic("http.request", {"method":"POST", "url":ENDPOINT, "body":payload, "fake":_fake_transport})
	if _fake_transport:
		# Only explicit receive_fake_response calls can advance tests.
		_last_fake_payload = payload.duplicate(true)
		status_changed.emit("request", "Fake transport request %d" % _request_count)
		return
	var request := HTTPRequest.new()
	request.timeout = _active_request_timeout_seconds
	request.body_size_limit = MAX_BODY
	add_child(request)
	_pending_http = request
	request.request_completed.connect(func(result: int, status: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		_handle_transport(identity, nonce, result, status, body, headers)
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
	# Used by fake-provider tests only; never called by live transport.
	if not _fake_transport or not _response_waiting:
		return {}
	return _last_fake_payload.duplicate(true)

func receive_fake_response(epoch: int, serial: int, http_status: int, body: Dictionary, headers: PackedStringArray = PackedStringArray()) -> void:
	if not _fake_transport:
		return
	_handle_transport(epoch, serial, HTTPRequest.RESULT_SUCCESS, http_status, JSON.stringify(body).to_utf8_buffer(),headers)

func _final_model_report(messages: Array) -> String:
	# Only a completed, tool-free assistant turn is a human-visible report.
	# The report is untrusted prose, never a native receipt or edit authority.
	var parts: Array[String] = []
	for message: Variant in messages:
		if not message is Dictionary or typeof(message.get("role", "assistant")) != TYPE_STRING or message.get("role", "assistant") != "assistant":
			continue
		var content: Variant = message.get("content", null)
		if not content is Array:
			continue
		for item: Variant in content:
			if item is Dictionary and typeof(item.get("type",null)) == TYPE_STRING and item.get("type", "") == "output_text" \
					and item.get("text", null) is String:
				var part: String = str(item.text).strip_edges()
				if not part.is_empty():
					parts.append(part)
	return "\n".join(parts).substr(0, MAX_MODEL_REPORT)

func _parse_json_value(raw: String) -> Variant:
	# Invalid provider input is a handled refusal, not an engine diagnostic.
	var decoder := JSON.new()
	if decoder.parse(raw) != OK:
		return null
	return decoder.data

static func _retry_after_seconds(value: String, utc_now: float) -> float:
	var text := value.strip_edges()
	if text.is_valid_float():
		var numeric := text.to_float()
		return numeric if is_finite(numeric) and numeric >= 0 else -1.0
	# IMF-fixdate, e.g. Sun, 08 Nov 2026 19:00:00 GMT. Invalid dates fall back
	# to bounded backoff; a valid long minimum is never shortened.
	var fields := text.split(" ",false)
	var months := ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
	if fields.size() != 6 or not fields[0].ends_with(",") or fields[5] not in ["GMT","UTC"]:
		return -1.0
	var clock := fields[4].split(":")
	if clock.size() != 3 or fields[2] not in months or not fields[1].is_valid_int() or not fields[3].is_valid_int():
		return -1.0
	for number: String in clock:
		if not number.is_valid_int():
			return -1.0
	var date := {"year":fields[3].to_int(),"month":months.find(fields[2])+1,"day":fields[1].to_int(),"hour":clock[0].to_int(),"minute":clock[1].to_int(),"second":clock[2].to_int()}
	if date.year < 1970 or date.month < 1 or date.day < 1 or date.day > 31 or date.hour > 23 or date.minute > 59 or date.second > 59 or date.hour < 0 or date.minute < 0 or date.second < 0:
		return -1.0
	var stamp: int = Time.get_unix_time_from_datetime_dict(date)
	var restored: Dictionary = Time.get_datetime_dict_from_unix_time(stamp)
	for key: String in date:
		if restored[key] != date[key]:
			return -1.0
	return maxf(0.0,float(stamp)-utc_now)

func _handle_rate_error(body: PackedByteArray, safe_headers: Dictionary) -> void:
	var parsed: Variant = _parse_json_value(body.get_string_from_utf8())
	var error: Variant = parsed.get("error",{}) if parsed is Dictionary else {}
	var code := str(error.get("code","")) if error is Dictionary else ""
	var kind := str(error.get("type","")) if error is Dictionary else ""
	var classification := (code+" "+kind).to_lower()
	for permanent: String in ["insufficient_quota","credit_balance_exhausted","organization_spend_limit_exceeded","project_spend_limit_exceeded","organization_usage_limit_exceeded","usage_limit_exceeded","billing_hard_limit_reached"]:
		if classification.contains(permanent):
			_fail("API quota/billing limit (429): check project credits and spending limits; retries cannot restore access. Open Traffic for the provider error.")
			return
	if code not in ["rate_limit_exceeded","slow_down","rate_limit_error"] and kind not in ["rate_limit_exceeded","slow_down","rate_limit_error"]:
		_fail("API rate limit status 429; unclassified response was not retried. Open Traffic for the provider error.")
		return
	if _rate_retries >= MAX_RATE_RETRIES:
		_fail("API rate limit persists after two bounded retries. Reduce Toks/inspection or TPM, then retry later.")
		return
	if _request_count >= _active_request_budget:
		_fail("Responses API request budget exhausted; no rate-limit retry dispatched.")
		return
	var delay: float = _retry_after_seconds(str(safe_headers.get("retry-after","")),Time.get_unix_time_from_system())
	if delay < 0:
		delay = 10.0 * pow(2.0,_rate_retries)
		if not _fake_transport:
			delay += randf_range(0.05,0.25)
	if delay > MAX_RETRY_DELAY_SECONDS or _retry_wait_seconds + delay > MAX_RETRY_WAIT_SECONDS:
		_fail("Provider requests %.1fs before retry, beyond the bounded wait. Try later; Retry-After was not shortened." % delay)
		return
	if _last_sent_payload.is_empty():
		_fail("Rate-limit retry has no immutable request payload.")
		return
	_rate_retries += 1
	_retry_wait_seconds += delay
	record_diagnostic("rate.retry", {"attempt":_rate_retries,"delay_seconds":delay,"classification":code if not code.is_empty() else kind,"same_input":true,"local_estimate":true})
	_queue_rate_payload(_last_sent_payload,_now_msec()+int(ceil(delay*1000.0)))

func _handle_transport(identity: int, nonce: int, result: int, http_status: int, body: PackedByteArray, headers: PackedStringArray = PackedStringArray()) -> void:
	var safe_headers := {}
	for header: String in headers:
		var split := header.find(":")
		var name := header.substr(0, split).to_lower() if split > 0 else ""
		if name in ["x-request-id", "retry-after", "x-ratelimit-remaining-requests", "x-ratelimit-remaining-tokens"]:
			safe_headers[name] = header.substr(split + 1).strip_edges()
	record_diagnostic("http.response", {"epoch":identity,"request":nonce,"transport_result":result,"http_status":http_status,"headers":safe_headers,"body":body.get_string_from_utf8(),"stale":not _active or identity != _epoch or nonce != _serial or not _response_waiting})
	if not _active or identity != _epoch or nonce != _serial or not _response_waiting:
		return
	_response_waiting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Network error or timeout (%d)." % result)
		return
	if body.size() > MAX_BODY:
		_fail("Provider response exceeds bounded size.")
		return
	if http_status == 429:
		_handle_rate_error(body,safe_headers)
		return
	if http_status < 200 or http_status >= 300:
		# Error bodies remain in redacted local diagnostics, never as native authority.
		var kind := "API authentication" if http_status == 401 or http_status == 403 else ("API rate limit" if http_status == 429 else "API HTTP")
		_fail("%s status %d" % [kind, http_status])
		return
	var parsed: Variant = _parse_json_value(body.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("id", "") is not String or str(parsed.get("id", "")).is_empty():
		_fail("Malformed Responses API envelope.")
		return
	var usage: Variant = parsed.get("usage", null)
	if usage is Dictionary and _safe_integer(usage.get("input_tokens",null)) and _safe_integer(usage.get("output_tokens",null)) and usage.input_tokens >= 0 and usage.output_tokens >= 0:
		_context_token_estimate = int(usage.input_tokens) + int(usage.output_tokens)
	else:
		_context_token_estimate = _last_sent_estimate
	if not _usage_ids.has(parsed.id):
		_usage_ids[parsed.id] = true
		if usage is Dictionary and _safe_integer(usage.get("input_tokens",null)) and _safe_integer(usage.get("output_tokens",null)) and usage.input_tokens >= 0 and usage.output_tokens >= 0:
			# Reserve before dispatch, then settle to actual completed usage. This
			# is local pacing, not a claim to mirror the provider's bucket.
			for reservation: Dictionary in _rate_reservations:
				if reservation.epoch == identity and reservation.request == nonce:
					reservation.tokens = int(usage.input_tokens) + int(usage.output_tokens)
					record_diagnostic("rate.settled",{"tokens":reservation.tokens,"source":"provider_usage","local_estimate":true})
					break
			_input_tokens = maxi(_input_tokens,0) + int(usage.input_tokens)
			_output_tokens = maxi(_output_tokens,0) + int(usage.output_tokens)
		else:
			_usage_complete = false
	if not parsed.get("output", null) is Array:
		_fail("Missing model output list.")
		return
	if str(parsed.get("status", "")) != "completed":
		_fail("Model response incomplete or failed.")
		return
	# A response is a unique provider continuation, not merely a fresh call_id.
	# Refuse a repeated/stale response even when its tool call ID was changed.
	var response_id := str(parsed.id)
	if response_id.length() > 128 or _seen_response_ids.has(response_id):
		_fail("Invalid or repeated Responses API response ID.")
		return
	var calls: Array = []
	var messages: Array = []
	for item: Variant in parsed.output:
		if not item is Dictionary or typeof(item.get("type",null)) != TYPE_STRING:
			_fail("Malformed response output item.")
			return
		if item.get("type", "") == "function_call":
			calls.append(item)
		elif item.get("type", "") == "message":
			messages.append(item)
	if calls.size() > 1:
		_fail("Parallel/duplicate tool calls refused.")
		return
	_seen_response_ids[response_id] = true
	_response_id = response_id
	if calls.is_empty():
		_active = false
		# A tool-free model completion is not an apply: retire any unconsumed
		# proposed overlay before the native Stop/retirement acknowledgment.
		proposal_changed.emit([])
		var final_report: String = _final_model_report(messages)
		if not final_report.is_empty():
			model_report_received.emit(final_report)
		status_changed.emit("completed", "Model turn ended; native result must be checked independently.")
		task_finished.emit("model_finished")
		return
	if _tool_count >= _active_tool_budget:
		_fail("Native tool-call budget exhausted.")
		return
	var call: Dictionary = calls[0]
	var name := str(call.get("name", ""))
	var call_id := str(call.get("call_id", ""))
	if name not in NAMES or call_id.is_empty() or _seen_call_ids.has(call_id):
		_fail("Unknown or repeated tool call ID/name.")
		return
	var raw_args: Variant = call.get("arguments", null)
	var args: Variant = _parse_json_value(raw_args) if raw_args is String else null
	if not _valid_arguments(name, args):
		# No native dispatch has occurred. Return one truthful refused tool
		# result via the existing Responses continuation, not a forged receipt.
		# A second bad call terminates the task; repeated IDs are rejected above.
		if _argument_repairs >= MAX_ARGUMENT_REPAIRS:
			_fail("Repeated malformed or out-of-policy tool arguments.")
			return
		_argument_repairs += 1
		_seen_call_ids[call_id] = true
		_tool_count += 1
		status_changed.emit("refused", "Invalid %s arguments; one bounded model correction." % name)
		_send([{"type": "function_call_output", "call_id": call_id,
			"output": JSON.stringify({"status": "refused",
			"reason": "invalid_or_out_of_policy_arguments", "native_dispatched": false,
			"repairs_remaining": 0})}])
		return
	_seen_call_ids[call_id] = true
	_tool_count += 1
	_pending_call_id = call_id
	_pending_tool = name
	_stage = "Waiting for native " + name
	record_diagnostic("tool.request", {"name":name,"call_id":call_id,"arguments":args})
	status_changed.emit("queued", "%s proposed; awaiting authoritative dispatcher." % name)
	tool_requested.emit(name, _normalise_arguments(name, args), _epoch, call_id)

# Compact *authoritative* status for the human co-author. A bare "applied"
# or "refused" hides actionable native evidence. Never emit the 4096-cell rows
# into Activity or infer a success from the model's own prose.
func _native_receipt_detail(tool: String, receipt: Dictionary, status: String) -> String:
	var detail := "%s: %s" % [tool, status]
	if status in ["refused", "error"]:
		var reason: String = str(receipt.get("reason", "")).strip_edges()
		if not reason.is_empty():
			detail += "; reason=" + reason.substr(0, 96)
	elif tool == "observe" and status == "observed":
		var ids: Variant = receipt.get("native_material_ids", null)
		if ids is Array or ids is PackedInt32Array or ids is PackedInt64Array:
			detail += "; inspected %d native cells" % ids.size()
		if receipt.get("image_status") == "matched_post_draw":
			detail += "; framebuffer matched"
	elif tool == "prepare_edit" and status == "proposed":
		var changed: Variant = receipt.get("changed_cells", null)
		if typeof(changed) == TYPE_INT and changed >= 0:
			detail += "; %d changed cells proposed" % changed
	elif tool == "apply_edit" and status == "applied":
		var readback: Variant = receipt.get("readback", null)
		if readback is Array:
			detail += "; %d native readback cells" % readback.size()
		var authored: Variant = receipt.get("authored_start", null)
		if authored is Dictionary and authored.get("status") == "recorded":
			detail += "; authored start recorded"
	elif tool == "step" and status == "stepped":
		# submit_tool_result already validated exact native/PNG tick identity.
		detail += "; %d completed ticks; paused at tick %d; framebuffer matched" % [
			int(receipt.get("completed", 0)), int(receipt.get("after_tick", -1))]
	return detail.substr(0, 220)

func submit_tool_result(epoch: int, call_id: String, receipt: Dictionary) -> bool:
	# Called asynchronously only by the shared #526/#527 adapter.
	record_diagnostic("native.receipt", {"epoch":epoch,"call_id":call_id,"receipt":receipt,"stale":not _active or epoch != _epoch or call_id != _pending_call_id or call_id.is_empty()})
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
	if _pending_tool == "step" and status == "stepped":
		var observed: Variant = receipt.get("observation",{})
		var count: int = int(receipt.get("completed",-1))
		if not observed is Dictionary or observed.get("status") != "observed" \
				or observed.get("image_status") != "matched_post_draw" \
				or count < 1 or count != int(receipt.get("requested",-1)) \
				or int(receipt.get("after_tick",-1)) != int(receipt.get("before_tick",-2)) + count \
				or receipt.get("still_paused") != true \
				or int(observed.get("render_identity",{}).get("tick",-1)) != int(receipt.get("after_tick",-2)) \
				or not receipt.has("image_data_url"):
			_fail("Step receipt lacks exact completed native ticks and matched post-draw image.")
			return false
	if status == "unconfirmed" or (_pending_tool == "step" and status == "refused" \
			and int(receipt.get("completed",0)) > 0):
		# Ambiguous/partly executed native work is not retried by the model.
		_fail("Native tool result uncertain; human Stop/recovery required.")
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
	var bounded_receipt := receipt.duplicate(true)
	# #526 supplies original viewport PNG matched to the native observation.
	# Text-only base64 is NOT a vision input: send it as an input_image item.
	var image_url := ""
	if _pending_tool in ["observe","step"] and bounded_receipt.has("image_data_url"):
		image_url = str(bounded_receipt["image_data_url"])
		bounded_receipt.erase("image_data_url")
		if not image_url.begins_with("data:image/png;base64,") or image_url.length() > 800000:
			_fail("Invalid/oversized native viewport image.")
			return false
	var output := JSON.stringify(bounded_receipt)
	if output.length() > MAX_TOOL_OUTPUT:
		_fail("Native receipt exceeds bounded result limit.")
		return false
	status_changed.emit(status, _native_receipt_detail(_pending_tool, bounded_receipt, status))
	_pending_call_id = ""
	_pending_tool = ""
	var next_input: Array = [{"type": "function_call_output", "call_id": call_id, "output": output}]
	if not image_url.is_empty():
		next_input.append({"role": "user", "content": [
			{"type": "input_text", "text": "Native-observed viewport for this exact observation identity. Match it to the preceding facts; never infer material IDs from pixels."},
			{"type": "input_image", "image_url": image_url, "detail": "low"}
		]})
	# All authority is still in #526/#527; no native call occurs here.
	_send(next_input)
	return true

func _exit_tree() -> void:
	if _active:
		stop_task("Panel/scene exited")
