extends RefCounted
## WB-AGENT-001 main-thread bridge for the EXISTING paused shared workbench.
## No World access. No model access to host-only authorization or render ACKs.
## All mutations are serialized and read back by CyberSimulationWorker.
const RenderJoin = preload("res://scripts/workbench_authoring_render_join.gd")
const StartCommit = preload("res://scripts/workbench_authoring_start_commit.gd")

const RESPONSE_TIMEOUT_MSEC: int = 10000
const MAX_LOCAL_RECEIPTS: int = 64

var _host: Control
var _panel: Control
var _busy: bool = false
var _tool_busy: bool = false
var _quarantined: bool = false
var _task_id: String = ""
var _plan: Dictionary = {}
var _receipts: Dictionary = {}


static func _refused(reason: String) -> Dictionary:
	return {"status":"refused","reason":reason}


## Call on main before using this bridge. The panel/client never sees the World.
func bind(host: Control) -> bool:
	if _busy or host == null or host.simulation_worker == null \
			or host.shared_workbench == null:
		return false
	_host = host
	_panel = host.shared_workbench
	return true


static func _keys_only(value: Dictionary, names: Array) -> bool:
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or key not in names:
			return false
	return true


## Convert strict Responses JSON world-cell rectangle to typed Rect2i.
## Reject before Vector2i narrowing; a null region selects task scope.
static func _typed_region(value: Variant) -> Variant:
	if value is Rect2i:
		return value
	if not value is Dictionary:
		return null
	if value.size() != 4 or not _keys_only(value,["x","y","width","height"]):
		return null
	for key: String in ["x","y","width","height"]:
		if not value.has(key) or typeof(value[key]) != TYPE_INT:
			return null
	var x: int = value.x
	var y: int = value.y
	var width: int = value.width
	var height: int = value.height
	if x < 0 or y < 0 or width <= 0 or height <= 0:
		return null
	if x > 2147483647 or y > 2147483647 \
			or width > 2147483647 - x or height > 2147483647 - y:
		return null
	return Rect2i(x,y,width,height)


func _available() -> bool:
	return is_instance_valid(_host) and is_instance_valid(_panel) \
		and _host.simulation_worker != null and _host.paused \
		and not _panel.applied.is_empty() and not _panel.busy()


## This is ONE request/one result across the existing worker mutex.
## A fresh serial comparison prevents a result from an older caller being
## consumed as a newer acknowledgement.
func _owner(command: Dictionary) -> Dictionary:
	if _busy:
		return _refused("host_tool_busy")
	if not _available():
		return _refused("paused_workbench_unavailable")
	_busy = true
	var payload: Dictionary = command.duplicate(true)
	payload["schema_version"] = 1
	var worker: CyberSimulationWorker = _host.simulation_worker
	var serial: int = worker.queue_agent_authoring_command(payload)
	if serial <= 0:
		_busy = false
		return _refused("worker_command_not_admitted")
	var deadline: int = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MSEC
	var response: Dictionary = {}
	while Time.get_ticks_msec() < deadline and is_instance_valid(_host):
		response = worker.latest_agent_authoring_result(serial-1)
		if not response.is_empty():
			break
		await _host.get_tree().process_frame
	_busy = false
	if int(response.get("request_serial",-1)) != serial:
		# Never retry a timed-out mutation. Completion could be late/partial.
		_plan.clear()
		return {"status":"unconfirmed","reason":"worker_receipt_missing_or_mismatched",
			"request_serial":serial}
	return response


## Host-only authorization. NEVER route this through model tool dispatch.
func authorize_task(task_id: String, scope: Rect2i, protected: Array,
		allowed_materials: Array) -> Dictionary:
	if _quarantined or _tool_busy:
		return _refused("authoring_host_quarantined_or_busy")
	if not _task_id.is_empty():
		return _refused("retire_previous_task_first")
	if not _receipts.is_empty() and _receipts.size() >= MAX_LOCAL_RECEIPTS:
		return _refused("receipt_history_full")
	var answer: Dictionary = await _owner({
		"action":"authorize_task","task_id":task_id,"scope":scope,
		"protected":protected,"allowed_materials":allowed_materials
	})
	if answer.get("status") == "authorized":
		_task_id = task_id
		_plan.clear()
	return answer


## Host-only task retirement; receipt history is intentionally retained.
func retire_task() -> Dictionary:
	if _quarantined or _tool_busy:
		return _refused("authoring_host_quarantined_or_busy")
	if _task_id.is_empty():
		return _refused("no_active_task")
	var answer: Dictionary = await _owner({"action":"retire_task"})
	if answer.get("status") == "retired":
		_task_id = ""
		_plan.clear()
	return answer


func _observe(args: Dictionary) -> Dictionary:
	# An observation supersedes the previous worker-side proposal.
	_plan.clear()
	var command: Dictionary = {"action":"observe"}
	if args.has("region") and args.region != null:
		var region: Variant = _typed_region(args.region)
		if region == null:
			return _refused("invalid_observation_region")
		command["region"] = region
	if args.has("detail"):
		command["detail"] = args.detail
	var native: Dictionary = await _owner(command)
	if native.get("status") != "native_observed":
		return native
	var deadline: int = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MSEC
	var joined: Dictionary = {}
	var requested_fresh_render: bool = false
	while Time.get_ticks_msec() < deadline and _available():
		joined = await RenderJoin.join_after_draw(_host,native)
		if joined.get("status") == "observed":
			break
		var reason: String = str(joined.get("reason",""))
		if reason not in [
			"native_and_uploaded_render_not_matched",
			"publication_changed_during_draw",
			"publication_changed_after_capture"
		]:
			return joined
		# A paused native step can complete without changing any material ID.
		# Normal render publication is revision-driven in that case, leaving an
		# older render tick even though the owner returned a fresh observation.
		# Request ONE normal full-refresh packet through the existing owner;
		# never relabel old pixels or weaken the exact tick/render ACK check.
		if reason == "native_and_uploaded_render_not_matched" \
				and not requested_fresh_render:
			_host.simulation_worker.request_render_full_refresh()
			requested_fresh_render = true
		await _host.get_tree().process_frame
	if joined.get("status") != "observed":
		return {"status":"pending","reason":"matching_post_draw_frame_not_available",
			"observation_id":native.get("observation_id","")}
	var ack: Dictionary = await _owner({
		"action":"confirm_observation_frame",
		"observation_id":native.observation_id,
		"render_identity":joined.render_identity
	})
	if ack.get("status") != "observation_confirmed":
		# Do not disclose an apparently trustworthy PNG with unconfirmed IDs.
		return {"status":"pending","reason":"owner_did_not_confirm_frame",
			"observation_id":native.observation_id,"owner_receipt":ack}
	return joined


func _prepare(args: Dictionary) -> Dictionary:
	_plan.clear()
	var operations: Variant = args.get("operations",null)
	if not operations is Array:
		return _refused("invalid_operations")
	var typed: Array = operations.duplicate(true)
	for index: int in range(typed.size()):
		if typed[index] is Dictionary and typed[index].get("replace_only_material",false) == null:
			typed[index].erase("replace_only_material")
	var native: Dictionary = await _owner({
		"action":"prepare_edit",
		"observation_id":args.get("observation_id",null),
		"operations":typed
	})
	if native.get("status") != "proposed":
		return native
	# Preflight the NAMED-START history *before* any native mutation. A
	# readback-applied edit that cannot be saved is not a usable authoring tool.
	var plan: Dictionary = StartCommit.stage(_panel.applied,native)
	if plan.get("status") != "recordable":
		return _refused("authored_start_preflight_failed:" + str(plan.get("reason","unknown")))
	_plan = plan.duplicate(true)
	return native


func _apply(args: Dictionary) -> Dictionary:
	var proposal_id: Variant = args.get("proposal_id",null)
	if typeof(proposal_id) != TYPE_STRING or proposal_id.is_empty():
		return _refused("invalid_proposal_id")
	if _receipts.has(proposal_id):
		return _receipts[proposal_id].duplicate(true)
	if _receipts.size() >= MAX_LOCAL_RECEIPTS:
		return _refused("receipt_history_full")
	if _plan.is_empty() or str(_plan.get("proposal_id","")) != proposal_id:
		return _refused("proposal_not_preflight_recordable")
	var planned: Dictionary = _plan.duplicate(true)
	_plan.clear()
	var native: Dictionary = await _owner({
		"action":"apply_edit","proposal_id":proposal_id
	})
	var answer: Dictionary = native.duplicate(true)
	if native.get("status") == "applied":
		var recorded: Dictionary = StartCommit.commit(_panel,planned,native)
		answer["authored_start"] = recorded
		if recorded.get("status") != "recorded":
			# Native cells might already be changed. Do not report success or
			# allow a new proposal to conceal the unsaved authored state.
			answer["status"] = "unconfirmed"
			answer["reason"] = "verified_native_apply_but_start_record_failed"
			_task_id = ""
	# On any uncertain owner result, bar all new authoring in this host;
	# the native request might have completed after a missing ACK.
	if answer.get("status") == "unconfirmed":
		_quarantined = true
	# The original native receipt remains visible even on a storage failure.
	_receipts[proposal_id] = answer.duplicate(true)
	return answer


## Exactly three model-visible #526 methods. #527 exclusively adds step.
## Authorization/retirement/frame confirmation are deliberately not tools.
func call_tool(name: String, args: Dictionary) -> Dictionary:
	if name == "apply_edit" and _receipts.has(args.get("proposal_id","")):
		return _receipts[args.proposal_id].duplicate(true)
	if _quarantined:
		return _refused("authoring_host_quarantined_after_uncertain_outcome")
	if _task_id.is_empty():
		return _refused("no_host_authorized_task")
	if _busy or _tool_busy:
		return _refused("host_tool_busy")
	var expected_keys: Array = []
	match name:
		"observe":
			expected_keys = ["region","detail"]
		"prepare_edit":
			expected_keys = ["observation_id","operations"]
		"apply_edit":
			expected_keys = ["proposal_id"]
		_:
			return _refused("not_a_model_visible_526_tool")
	if not _keys_only(args,expected_keys):
		return _refused("unexpected_model_tool_argument")
	_tool_busy = true
	var result: Dictionary = {}
	match name:
		"observe":
			result = await _observe(args)
		"prepare_edit":
			result = await _prepare(args)
		"apply_edit":
			result = await _apply(args)
	_tool_busy = false
	return result
