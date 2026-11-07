extends RefCounted
## #528 opt-in attachment for the existing shared Godot workbench.
## The native authority stays in #526 WorkbenchAuthoringHost; this class
## only binds UI, converts copied receipts and enforces local response fences.
const AgentPanel = preload("res://scripts/workbench_agent_panel.gd")
const AuthoringHost = preload("res://scripts/workbench_authoring_host.gd")
# Source-identical #527 handoff; native World remains exclusively #526-owned.
const FourToolBridge = preload("res://scripts/workbench_agent_four_tool_bridge.gd")

const MAX_IMAGE_BYTES: int = 590000
const RETIRE_TIMEOUT_MSEC: int = 35000

var _workbench: Control
var _host: Control
var _agent_panel: Control
var _bridge: RefCounted
var _toggle: Button
var _authorizing: bool = false
var _authorised: bool = false
var _pending_retirement: bool = false
var _task_serial: int = 0

func mount(workbench: Control) -> bool:
	if workbench == null or workbench.host == null:
		return false
	_workbench = workbench
	_host = workbench.host
	_bridge = FourToolBridge.new()
	if not _bridge.bind(_host):
		return false
	_agent_panel = AgentPanel.new()
	_workbench.add_child(_agent_panel)
	_agent_panel.hide()
	var row: HFlowContainer = _workbench._row(_workbench)
	_toggle = Button.new()
	_toggle.text = "Agent authoring (opt-in)"
	_toggle.toggle_mode = true
	_toggle.button_pressed = false
	_toggle.toggled.connect(func(enabled: bool) -> void:
		if not is_instance_valid(_agent_panel):
			return
		if not enabled:
			# The overlay is parented under world_view, not the panel: hiding
			# the controls alone would leave a live, invisible agent editing.
			# Revoke pending model/authorization work and require native Stop
			# acknowledgement before another task can be authorized.
			_agent_panel.invalidate_due_to_owner_change("agent panel opted out")
			_agent_panel.proposal_overlay.set_footprint([])
		_agent_panel.visible = enabled)
	row.add_child(_toggle)
	_agent_panel.bind_authoritative_dispatcher(
		Callable(self,"dispatch"),Callable(self,"project_cell"),
		Callable(self,"authorize"),Callable(self,"retire"))
	_host.world_view.add_child(_agent_panel.proposal_overlay)
	_agent_panel.proposal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.world_view.resized.connect(_agent_panel.proposal_overlay.queue_redraw)
	return true

func panel() -> Control:
	return _agent_panel

func project_cell(cell: Vector2i) -> Variant:
	if not is_instance_valid(_host) or not is_instance_valid(_host.world_view):
		return null
	var content: Rect2 = _host.view_content_rect()
	var dimensions: Vector2i = _host.current_view_size
	if not content.has_area() or dimensions.x <= 0 or dimensions.y <= 0:
		return null
	var offset: Vector2 = Vector2(cell) - _host.camera_origin
	if offset.x < 0 or offset.y < 0 or offset.x >= dimensions.x or offset.y >= dimensions.y:
		return null
	var scale: Vector2 = content.size / Vector2(dimensions)
	return Rect2(content.position + offset * scale, scale)

func authorize(scope: Dictionary) -> Dictionary:
	if _bridge == null:
		return {"status":"refused","reason":"authoring_bridge_not_bound"}
	if _pending_retirement or _authorizing or _authorised:
		return {"status":"refused","reason":"prior_authoring_task_not_retired"}
	if not is_instance_valid(_host) or not _host.paused:
		return {"status":"refused","reason":"workbench_must_be_paused"}
	var r: Variant = AuthoringHost._typed_region(scope.get("region",null))
	if not r is Rect2i or r.size.x * r.size.y > 4096:
		return {"status":"refused","reason":"invalid_or_oversized_authorized_region"}
	var protected: Array = []
	var raw_protected: Variant = scope.get("protected_regions",null)
	if not raw_protected is Array or raw_protected.size() > 32:
		return {"status":"refused","reason":"invalid_protection"}
	for item: Variant in raw_protected:
		var region: Variant = AuthoringHost._typed_region(item)
		if not region is Rect2i:
			return {"status":"refused","reason":"invalid_protected_region"}
		protected.append(region)
	var selected: Variant = scope.get("allowed_materials",null)
	if not selected is Array or selected.is_empty() or selected.size() > 2:
		return {"status":"refused","reason":"invalid_material_selection"}
	var materials: Array = []
	for item: Variant in selected:
		match item:
			"Hard Wall":
				if not materials.has(58): materials.append(58)
			"Empty":
				if not materials.has(0): materials.append(0)
			_:
				return {"status":"refused","reason":"material_not_allowlisted"}
	_task_serial += 1
	_authorizing = true
	var receipt: Dictionary = await _bridge.authorize_task(
		"wb528-%d" % _task_serial,r,protected,materials)
	_authorizing = false
	_authorised = receipt.get("status") == "authorized"
	return receipt

func retire() -> Dictionary:
	if _pending_retirement:
		return {"status":"unconfirmed","reason":"retirement_already_pending"}
	_pending_retirement = true
	var deadline: int = Time.get_ticks_msec() + RETIRE_TIMEOUT_MSEC
	var answer: Dictionary = {}
	while Time.get_ticks_msec() < deadline and is_instance_valid(_host):
		if _authorizing:
			await _host.get_tree().process_frame
			continue
		if not _authorised:
			answer = {"status":"retired","reason":"no_native_task"}
			break
		answer = await _bridge.stop()
		if answer.get("status") == "stopped" and answer.get("no_further_agent_mutations") == true:
			_authorised = false
			# #527's StepSequence is permanently retired after Stop and its
			# bridge deliberately remains in the stopping state. Reuse would
			# refuse EVERY later authoring session. Only after the exclusive
			# native owner acknowledges retirement may this #528 host adapter
			# bind a fresh bridge for deliberate human reauthorization.
			var native_ack: Dictionary = answer.duplicate(true)
			var replacement: RefCounted = FourToolBridge.new()
			if is_instance_valid(_host) and replacement.bind(_host):
				_bridge = replacement
				answer = {"status":"retired","reason":"native_527_stop_ack",
					"ready_for_new_task":true,"owner_receipt":native_ack}
			else:
				_bridge = null # Fail closed; never fall back to a retired bridge.
				answer = {"status":"retired","reason":"native_ack_but_new_bridge_unavailable",
					"ready_for_new_task":false,"owner_receipt":native_ack}
			break
		if str(answer.get("reason","")) not in [
			"authoring_host_quarantined_or_busy","host_tool_busy"]:
			break
		await _host.get_tree().process_frame
	_pending_retirement = false
	# A timed out retirement must not enable a new session. The worker could
	# still have the previous task; keep _authorised as a fail-closed fence.
	if answer.is_empty():
		answer = {"status":"unconfirmed","reason":"native_retirement_timeout"}
	return answer

func invalidate_human(reason: String) -> void:
	if is_instance_valid(_agent_panel):
		_agent_panel.invalidate_due_to_owner_change(reason)

func dispatch(name: String, args: Dictionary, epoch: int, call_id: String, client: Node) -> void:
	if not is_instance_valid(client) or not client.is_active() 			or client.current_epoch() != epoch or not _authorised:
		return
	# All four tools execute through the SAME qualified #527 bridge, which
	# delegates first three to #526 and sequences native ACKed workbench ticks.
	var result: Dictionary = await _bridge.call_tool(name,args)
	if not is_instance_valid(client) or not client.is_active() 			or client.current_epoch() != epoch:
		# In-flight native work may have completed; retirement fences the
		# next task. Never synthesize a cancellation/rollback receipt.
		return
	client.submit_tool_result(epoch,call_id,to_model_receipt(result,name))

static func _json_safe(value: Variant) -> Variant:
	if value is Vector2i:
		return {"x":value.x,"y":value.y}
	if value is Rect2i:
		return {"x":value.position.x,"y":value.position.y,
			"width":value.size.x,"height":value.size.y}
	if value is Array:
		var output: Array = []
		for item: Variant in value:
			output.append(_json_safe(item))
		return output
	if value is Dictionary:
		var output: Dictionary = {}
		for key: Variant in value.keys():
			output[str(key)] = _json_safe(value[key])
		return output
	if value is PackedInt32Array or value is PackedInt64Array:
		return Array(value)
	return value

static func to_model_receipt(native: Dictionary, tool: String = "") -> Dictionary:
	# #527 completed ticks are only model-visible as "stepped" with a genuine
	# #526 post-draw observation at EXACTLY the completed native tick.
	if tool == "step":
		var step_result: Dictionary = native.duplicate(true)
		if step_result.get("status") == "stopped":
			step_result["status"] = "refused"
			return _json_safe(step_result)
		if step_result.get("status") != "completed":
			return _json_safe(step_result)
		var observed: Variant = step_result.get("observation",{})
		var requested: int = int(step_result.get("requested",-1))
		var completed: int = int(step_result.get("completed",-1))
		var before: int = int(step_result.get("before_tick",-1))
		var after: int = int(step_result.get("after_tick",-1))
		if requested < 1 or requested > 120 or completed != requested \
				or before < 0 or after != before + completed \
				or step_result.get("still_paused") != true \
				or not observed is Dictionary \
				or observed.get("status") != "observed" \
				or observed.get("image_status") != "matched_post_draw" \
				or int(observed.get("identity",{}).get("completed_tick",-1)) != after \
				or int(observed.get("render_identity",{}).get("tick",-1)) != after:
			return {"status":"unconfirmed","reason":"step_missing_exact_matched_observation",
				"requested":requested,"completed":completed,
				"before_tick":before,"after_tick":after}
		var png: Variant = observed.get("framebuffer_png",null)
		if not png is PackedByteArray or png.size() < 8 or png.size() > MAX_IMAGE_BYTES:
			return {"status":"unconfirmed","reason":"step_matched_image_missing_or_oversized",
				"requested":requested,"completed":completed,
				"before_tick":before,"after_tick":after}
		step_result["observation"].erase("framebuffer_png")
		step_result["status"] = "stepped"
		step_result["image_data_url"] = "data:image/png;base64," + Marshalls.raw_to_base64(png)
		return _json_safe(step_result)
	# Preserve original matched PNG bytes, never generate a fake screenshot.
	# Sending a copied PNG to OpenAI does not give it any native World authority.
	var result: Dictionary = native.duplicate(true)
	if result.has("framebuffer_png"):
		var png: Variant = result["framebuffer_png"]
		result.erase("framebuffer_png")
		if result.get("status") != "observed" 				or result.get("image_status") != "matched_post_draw" 				or not png is PackedByteArray or png.size() < 8 				or png.size() > MAX_IMAGE_BYTES:
			return {"status":"unconfirmed","reason":"matched_image_absent_or_over_limit"}
		result["image_data_url"] = "data:image/png;base64," + Marshalls.raw_to_base64(png)
	return _json_safe(result)
