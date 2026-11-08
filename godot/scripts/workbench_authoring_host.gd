extends RefCounted
## WB-AGENT-001 main-thread bridge for the EXISTING paused shared workbench.
## No World access. No model access to host-only authorization or render ACKs.
## All mutations are serialized and read back by CyberSimulationWorker.
const RenderJoin = preload("res://scripts/workbench_authoring_render_join.gd")
const StartCommit = preload("res://scripts/workbench_authoring_start_commit.gd")
const SignedFrame = preload("res://scripts/workbench_agent_signed_frame.gd")

const RESPONSE_TIMEOUT_MSEC: int = 10000
const MAX_LOCAL_RECEIPTS: int = 64
const MAX_OBSERVATION_CELLS: int = 4096

var _host: Control
var _panel: Control
var _busy: bool = false
var _tool_busy: bool = false
var _quarantined: bool = false
var _task_id: String = ""
# Copied only from acknowledged native task admission, never model arguments.
var _native_task_scope: Rect2i = Rect2i()
var _cell_limit: int = MAX_OBSERVATION_CELLS
var _task_generation: int = -1
# Experimental opt-in host-only frame: NEVER silently reinterpret an ordinary task.
var _coordinate_frame_id: String = ""
var _coordinate_frame_generation: int = -1
var _plan: Dictionary = {}
var _receipts: Dictionary = {}


static func _refused(reason: String) -> Dictionary:
	return {"status":"refused","reason":reason}


## Call on main before using this bridge. The panel/client never sees the World.
func bind(host: Control) -> bool:
	if _busy or _tool_busy or not _task_id.is_empty() \
			or not is_instance_valid(host) or host.simulation_worker == null \
			or host.shared_workbench == null:
		return false
	_host = host
	_panel = host.shared_workbench
	_native_task_scope = Rect2i()
	_cell_limit = MAX_OBSERVATION_CELLS
	_task_generation = -1
	_coordinate_frame_id = ""
	_coordinate_frame_generation = -1
	_plan.clear()
	return true


static func _keys_only(value: Dictionary, names: Array) -> bool:
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or key not in names:
			return false
	return true


## Convert strict Responses JSON world-cell rectangle to typed Rect2i.
## Reject before Vector2i narrowing; null is resolved separately from task scope.
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


static func _region_value(rect: Rect2i) -> Dictionary:
	return {"x":rect.position.x,"y":rect.position.y,
		"width":rect.size.x,"height":rect.size.y}


func _signed_frame_available() -> bool:
	return _panel != null and not _panel.applied.is_empty() \
		and _panel.applied.get("extent",[]) == [2048,2048] \
		and _host != null and _host.world_extent == SignedFrame.EXTENT


func _frame_matches_owner(native: Dictionary) -> bool:
	var identity: Dictionary = native.get("identity",
		native.get("identity_after",{}))
	if _task_generation < 0 or int(identity.get("world_generation",-1)) != _task_generation:
		return false
	if _coordinate_frame_id.is_empty():
		return true
	return _task_generation == _coordinate_frame_generation \
		and _coordinate_frame_id == SignedFrame.FRAME_ID and _signed_frame_available()


func _default_observation_region() -> Rect2i:
	if _native_task_scope.size.x * _native_task_scope.size.y <= _cell_limit:
		return _native_task_scope
	var width: int = mini(_native_task_scope.size.x,maxi(1,int(sqrt(float(_cell_limit)))))
	var height: int = mini(_native_task_scope.size.y,maxi(1,_cell_limit / width))
	var size := Vector2i(width,height)
	var center: Vector2 = _host.camera_origin + Vector2(_host.current_view_size) * 0.5
	var origin: Vector2i = Vector2i((center - Vector2(size) * 0.5).floor())
	origin = origin.clamp(_native_task_scope.position,_native_task_scope.end-size)
	return Rect2i(origin,size)


func _viewport_mapping() -> Dictionary:
	if not is_instance_valid(_host) or not is_instance_valid(_host.world_view):
		return {}
	var viewport: Viewport = _host.get_viewport()
	if viewport == null or _host.current_view_size.x <= 0 or _host.current_view_size.y <= 0:
		return {}
	var visible: Rect2 = viewport.get_visible_rect()
	var content: Rect2 = _host.world_view.get_global_transform_with_canvas() * _host.view_content_rect()
	if not visible.has_area() or not content.has_area():
		return {}
	return {
		"native_region":Rect2i(Vector2i(_host.camera_origin.floor()),_host.current_view_size),
		# Normalize now, then use the actual original PNG dimensions below.
		"normalized_content":Rect2((content.position-visible.position)/visible.size,
			content.size/visible.size)
	}


func _signed_rows(native_rows: Variant) -> Dictionary:
	if _coordinate_frame_id.is_empty():
		return {"status":"mapped","logical":native_rows}
	return SignedFrame.readback_to_logical(native_rows,_cell_limit)


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
		allowed_materials: Array, coordinate_frame_id: String = "",
		cell_limit: int = MAX_OBSERVATION_CELLS) -> Dictionary:
	if cell_limit < 1 or cell_limit > 65536:
		return _refused("invalid_authorized_cell_limit")
	if _quarantined or _tool_busy:
		return _refused("authoring_host_quarantined_or_busy")
	if not _task_id.is_empty():
		return _refused("retire_previous_task_first")
	if not _receipts.is_empty() and _receipts.size() >= MAX_LOCAL_RECEIPTS:
		return _refused("receipt_history_full")

	# Only a trusted host can explicitly opt in; model dispatch cannot supply
	# this parameter.  Do not conflate independently measured end-state equivalence
	# with exact native physical parity of the frozen original negative-world run.
	if coordinate_frame_id != "" and coordinate_frame_id != SignedFrame.FRAME_ID:
		return _refused("unsupported_coordinate_frame")
	var native_scope: Rect2i = scope
	var native_protection: Array = protected.duplicate(true)
	if coordinate_frame_id != "":
		if not _signed_frame_available():
			return _refused("signed_frame_requires_2048_finite_workbench")
		var checked: Dictionary = SignedFrame.region(_region_value(scope))
		if checked.get("status") != "mapped":
			return _refused("invalid_signed_task_scope:" + str(checked.get("reason","")))
		native_scope = checked.native
		native_protection.clear()
		if protected.size() > 32:
			return _refused("invalid_signed_protection")
		for guard: Variant in protected:
			if not guard is Rect2i:
				return _refused("invalid_signed_protection")
			checked = SignedFrame.region(_region_value(guard))
			if checked.get("status") != "mapped":
				return _refused("invalid_signed_protection:" + str(checked.get("reason","")))
			native_protection.append(checked.native)
	var answer: Dictionary = await _owner({
		"action":"authorize_task","task_id":task_id,"scope":native_scope,
		"protected":native_protection,"allowed_materials":allowed_materials,
		"cell_limit":cell_limit
	})
	if answer.get("status") == "authorized":
		var acknowledged_scope: Variant = answer.get("scope",null)
		var generation: int = int(answer.get("generation",-1))
		if not acknowledged_scope is Rect2i or acknowledged_scope != native_scope or generation < 0 \
				or typeof(answer.get("cell_limit",null)) != TYPE_INT or answer.cell_limit != cell_limit:
			_quarantined = true
			return {"status":"unconfirmed","reason":"native_authorization_identity_mismatch"}
		_task_id = task_id
		_native_task_scope = acknowledged_scope
		_cell_limit = int(answer.cell_limit)
		_task_generation = generation
		_plan.clear()
		_coordinate_frame_id = coordinate_frame_id
		_coordinate_frame_generation = int(answer.get("generation",-1))
		if coordinate_frame_id != "":
			answer["coordinate_frame_id"] = coordinate_frame_id
			answer["logical_scope"] = scope
			answer["logical_protection"] = protected.duplicate(true)
			answer["native_scope"] = native_scope
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
		_native_task_scope = Rect2i()
		_cell_limit = MAX_OBSERVATION_CELLS
		_task_generation = -1
		_plan.clear()
		_coordinate_frame_id = ""
		_coordinate_frame_generation = -1
	return answer


func _observe(args: Dictionary) -> Dictionary:
	# Only a successful native observation supersedes the pending worker proposal.
	# A refused or invalid observation must not discard the host's recordable plan.
	if not _available():
		return _refused("paused_workbench_unavailable")
	var command: Dictionary = {"action":"observe"}
	if _task_generation < 0 or not _native_task_scope.has_area():
		return _refused("missing_acknowledged_task_scope")
	if _host.latest_snapshot == null \
			or _host.latest_snapshot.render_world_generation != _task_generation:
		return _refused("authorized_task_world_epoch_changed")
	if not _coordinate_frame_id.is_empty() and not _signed_frame_available():
		return _refused("signed_frame_lost_finite_world")
	var selection: String = "explicit_region"
	if args.has("region") and args.region != null:
		var region: Variant = null
		if _coordinate_frame_id.is_empty():
			region = _typed_region(args.region)
		else:
			var mapped: Dictionary = SignedFrame.region(args.region)
			if mapped.get("status") == "mapped":
				region = mapped.native
		if region == null:
			return _refused("invalid_observation_region")
		command["region"] = region
	else:
		command["region"] = _default_observation_region()
		selection = "task_scope" if command.region == _native_task_scope else "camera_window"
	if args.has("detail"):
		command["detail"] = args.detail
	var native: Dictionary = await _owner(command)
	if native.get("status") != "native_observed":
		return native
	# The worker has now retired its former proposal; retire the host plan too.
	_plan.clear()
	if not _frame_matches_owner(native):
		_quarantined = true
		return {"status":"unconfirmed","reason":"coordinate_frame_world_epoch_changed"}
	var deadline: int = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MSEC
	var joined: Dictionary = {}
	var captured_mapping: Dictionary = {}
	var requested_fresh_render: bool = false
	while Time.get_ticks_msec() < deadline and _available():
		var projection: Dictionary = _viewport_mapping()
		if projection.is_empty():
			return {"status":"pending","reason":"viewport_mapping_unavailable",
				"observation_id":native.observation_id}
		joined = await RenderJoin.join_after_draw(_host,native)
		if joined.get("status") == "observed":
			if projection == _viewport_mapping():
				captured_mapping = projection
				break
			joined = {"status":"pending","reason":"viewport_projection_changed_during_capture"}
		var reason: String = str(joined.get("reason",""))
		if reason not in [
			"native_and_uploaded_render_not_matched",
			"publication_changed_during_draw",
			"publication_changed_after_capture",
			"viewport_projection_changed_during_capture"
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
	var frame_origin: Vector2i = SignedFrame.ORIGIN if not _coordinate_frame_id.is_empty() else Vector2i.ZERO
	var captured_view: Rect2i = captured_mapping.native_region
	var normalized: Rect2 = captured_mapping.normalized_content
	var png_size: Vector2 = Vector2(joined.render_identity.viewport_width,joined.render_identity.viewport_height)
	var pixels: Rect2 = Rect2(normalized.position*png_size,normalized.size*png_size)
	joined["region_selection"] = selection
	joined["observation_cell_limit"] = _cell_limit
	joined["authorized_scope"] = Rect2i(_native_task_scope.position-frame_origin,_native_task_scope.size)
	joined["viewport_native_region"] = captured_view
	joined["viewport_logical_region"] = Rect2i(captured_view.position-frame_origin,captured_view.size)
	joined["viewport_framebuffer_rect"] = {
		"x":pixels.position.x,"y":pixels.position.y,
		"width":pixels.size.x,"height":pixels.size.y}
	if not _coordinate_frame_id.is_empty():
		var local_region: Rect2i = joined.region
		joined["native_region"] = local_region
		joined["region"] = Rect2i(local_region.position-SignedFrame.ORIGIN,
			local_region.size)
		joined["coordinate_frame_id"] = _coordinate_frame_id
		joined["coordinate_frame_generation"] = _coordinate_frame_generation
	return joined


func _prepare(args: Dictionary) -> Dictionary:
	# Never replace a native-owned pending proposal or lose its saved-start plan.
	if not _plan.is_empty():
		return _refused("proposal_already_pending")
	var operations: Variant = args.get("operations",null)
	if not operations is Array:
		return _refused("invalid_operations")
	var typed: Array = operations.duplicate(true)
	for index: int in range(typed.size()):
		if typed[index] is Dictionary and typed[index].get("replace_only_material",false) == null:
			typed[index].erase("replace_only_material")
	if not _coordinate_frame_id.is_empty():
		var mapped: Dictionary = SignedFrame.operations(typed,_cell_limit)
		if mapped.get("status") != "mapped":
			return _refused("invalid_signed_operations:" + str(mapped.get("reason","")))
		typed = mapped.native
	var native: Dictionary = await _owner({
		"action":"prepare_edit",
		"observation_id":args.get("observation_id",null),
		"operations":typed
	})
	if native.get("status") != "proposed":
		return native
	if not _frame_matches_owner(native):
		_quarantined = true
		return {"status":"unconfirmed","reason":"coordinate_frame_world_epoch_changed"}
	# Preflight the NAMED-START history *before* any native mutation. A
	# readback-applied edit that cannot be saved is not a usable authoring tool.
	var plan: Dictionary = StartCommit.stage(_panel.applied,native,_cell_limit)
	if plan.get("status") != "recordable":
		return _refused("authored_start_preflight_failed:" + str(plan.get("reason","unknown")))
	_plan = plan.duplicate(true)
	if not _coordinate_frame_id.is_empty():
		var translated: Dictionary = _signed_rows(native.footprint)
		if translated.get("status") != "mapped":
			_plan.clear()
			_quarantined = true
			return {"status":"unconfirmed","reason":"native_footprint_unmappable"}
		native["footprint"] = translated.logical
		native["coordinate_frame_id"] = _coordinate_frame_id
		native["coordinate_frame_generation"] = _coordinate_frame_generation
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
	if not _coordinate_frame_id.is_empty() and native.get("status") == "applied" \
			and not _frame_matches_owner(native):
		_quarantined = true
		answer["status"] = "unconfirmed"
		answer["reason"] = "coordinate_frame_world_epoch_changed"
	if answer.get("status") == "applied":
		var recorded: Dictionary = StartCommit.commit(_panel,planned,native)
		answer["authored_start"] = recorded
		if recorded.get("status") != "recorded":
			# Native cells might already be changed. Do not report success or
			# allow a new proposal to conceal the unsaved authored state.
			answer["status"] = "unconfirmed"
			answer["reason"] = "verified_native_apply_but_start_record_failed"
			_task_id = ""
	if not _coordinate_frame_id.is_empty():
		answer["coordinate_frame_id"] = _coordinate_frame_id
		answer["coordinate_frame_generation"] = _coordinate_frame_generation
		if answer.has("readback"):
			var translated: Dictionary = _signed_rows(answer.readback)
			if translated.get("status") != "mapped":
				answer["status"] = "unconfirmed"
				answer["reason"] = "native_readback_unmappable"
			else:
				answer["readback"] = translated.logical
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
