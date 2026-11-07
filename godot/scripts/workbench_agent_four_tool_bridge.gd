extends RefCounted
## WB-AGENT-002 (#527): narrow fourth-tool and Stop composition over the
## ACTUAL #526 host adapter, and the existing acknowledged workbench Step.
## No native World, second dispatcher, mutable snapshots or model/network API.
## This is an experimental dependency-join helper, not production integration.
const StepSequence = preload("res://scripts/workbench_agent_step_sequence.gd")
const FOUNDATION_PATH = "res://scripts/workbench_authoring_host.gd"
const STOP_SETTLE_TIMEOUT_MSEC: int = 30000

var _main: Control
var _workbench: Control
var _authoring: RefCounted
var _step_driver: RefCounted = StepSequence.new()
var _authorized: bool = false
var _proposal_pending: bool = false
var _busy: bool = false
var _stopping: bool = false
var _uncertain: bool = false
var _epoch: int = 0


static func _refused(reason: String) -> Dictionary:
	return {"status":"refused","reason":reason}


## Bind to #526's actual existing host ONLY after the separately owned
## foundation is materialized. Nothing falls back to a synthetic World.
func bind(main: Control) -> bool:
	if _authorized or _busy or _stopping or _uncertain or not is_instance_valid(main):
		return false
	if not ResourceLoader.exists(FOUNDATION_PATH) or main.shared_workbench == null:
		return false
	var foundation: Variant = load(FOUNDATION_PATH)
	if foundation == null:
		return false
	var adapter: RefCounted = foundation.new()
	if not adapter.bind(main):
		return false
	_main = main
	_workbench = main.shared_workbench
	_authoring = adapter
	return true


func authorize_task(task_id: String, scope: Rect2i, protected: Array,
		allowed_materials: Array) -> Dictionary:
	if _authorized or _busy or _stopping or _uncertain:
		return _refused("task_or_transition_busy")
	if not is_instance_valid(_main) or _authoring == null:
		return _refused("foundation_not_bound")
	_busy = true
	var answer: Dictionary = await _authoring.authorize_task(
		task_id,scope,protected,allowed_materials)
	_busy = false
	if answer.get("status") == "authorized":
		_authorized = true
		_epoch += 1
	return answer


## All four model-visible calls share this SINGLE serial boundary. #526
## remains the only native observe/prepare/apply owner; #527 only sequences
## its fourth tool across the existing exclusive paused native tick ACKs.
func call_tool(name: String, args: Variant) -> Dictionary:
	if not _authorized or _stopping or _uncertain:
		return _refused("task_not_authorized_or_stopping")
	if _busy:
		return _refused("agent_tool_busy")
	if name == "step" and _proposal_pending:
		return _refused("prepared_edit_must_be_applied_or_retired_before_step")
	if not args is Dictionary:
		return _refused("invalid_tool_arguments")
	if name not in ["observe","prepare_edit","apply_edit","step"]:
		return _refused("not_one_of_four_model_tools")
	_busy = true
	var epoch: int = _epoch
	var receipt: Dictionary = {}
	if name == "step":
		receipt = await _step_driver.call_step(_main,_workbench,args)
		if receipt.get("status") == "completed":
			# A successful tick receipt is not itself a fresh *matched*
			# framebuffer/native observation; #526 performs that join.
			var matched: Dictionary = await _authoring.call_tool("observe",{
				"region":null,"detail":"counts"})
			receipt["observation"] = matched
			receipt["observation_status"] = matched.get("status","unavailable")
	else:
		receipt = await _authoring.call_tool(name,args)
		if name == "prepare_edit":
			_proposal_pending = receipt.get("status") == "proposed"
		elif name in ["observe","apply_edit"]:
			# #526 supersedes proposals on observe, and consumes them on
			# apply (including a stale/refused consume).
			_proposal_pending = false
	_busy = false
	if receipt.get("status") == "unconfirmed":
		_uncertain = true
	if epoch != _epoch or _stopping:
		# Preserve actual applied/completed status; do not erase evidence of
		# an operation that finished before the Stop consume boundary.
		receipt["interrupted_by_human"] = true
	return receipt


## No further call can enter once Stop is requested. An already admitted
## edit/tick must finish (or be marked UNCONFIRMED) before task retirement.
## Only the #526 owner retirement ACK permits a truthful Stop ACK.
func stop() -> Dictionary:
	if not _authorized:
		return _refused("no_active_authorized_task")
	if _stopping:
		return _refused("stop_already_pending")
	_stopping = true
	_step_driver.request_stop()
	var deadline: int = Time.get_ticks_msec() + STOP_SETTLE_TIMEOUT_MSEC
	while _busy and Time.get_ticks_msec() < deadline:
		if not is_instance_valid(_main):
			_uncertain = true
			return {"status":"unconfirmed","reason":"host_destroyed_before_stop_ack"}
		await _main.get_tree().process_frame
	if _busy:
		_uncertain = true
		return {"status":"unconfirmed","reason":"in_flight_tool_not_settled"}
	if _uncertain:
		return {"status":"unconfirmed","reason":"prior_native_result_unconfirmed"}
	var retired: Dictionary = await _authoring.retire_task()
	if retired.get("status") != "retired":
		_uncertain = true
		return {"status":"unconfirmed","reason":"native_task_retirement_not_acknowledged",
			"owner_receipt":retired}
	_authorized = false
	_proposal_pending = false
	_epoch += 1
	_step_driver.retire()
	return {"status":"stopped","reason":"native_task_retired_after_boundary",
		"no_further_agent_mutations":true}


## Do not rebind a retired task to an old driver. A revised destination
## requires a new bridge instance and a fresh #526 native authorization.
func retire_on_scene_exit() -> void:
	_stopping = true
	_uncertain = true
	_epoch += 1
	_step_driver.retire()
