extends "res://tests/run_driv3r_stage_a.gd"
## M3-HISTORY-001 only: inherit the accepted Stage A native Workbench
## transport/permissions. Add host-owned logical cursor/anchor RPC and the
## real shared PAINT editor Undo/Redo route. This is NOT a native cursor tool
## and neither relocation nor brush-up motion ever mutates native materials.


# Godot reports the inherited parent script in parent.run()'s ready receipt.
# A separate, immutable child marker binds *this derived harness* to the
# exact source bytes before the inherited request loop is ever started.
func _initialize() -> void:
	var output: String = OS.get_environment("DRIV3R_NATIVE_DIRECTORY")
	if output.is_empty():
		quit(2)
		return
	if not write_json(output+"/m3-harness-active.json",{
			"kind":"driv3r_m3_derived_history",
			"script_sha256":FileAccess.get_sha256("res://tests/run_driv3r_m3_history.gd"),
			"brush_up_logical_cursor_only":true}):
		quit(2)
		return
	super._initialize()

const M3_START := Vector2i(12, 24)
const M3_MAX_LOGICAL_MOVES := 12
var m3_cursor := M3_START
var m3_anchors: Dictionary = {}
var m3_moves := 0
var m3_history_events: Array = []

func _m3_history_done(event: Dictionary) -> void:
	m3_history_events.append(event.duplicate(true))

func _m3_cursor_array(point: Vector2i) -> Array:
	return [point.x, point.y]

func _m3_status() -> Dictionary:
	var anchor_list: Array = []
	for key: String in m3_anchors:
		var anchor: Dictionary = m3_anchors[key]
		anchor_list.append({"name":key,"cursor":_m3_cursor_array(anchor.cursor),
			"generation":int(anchor.generation)})
	anchor_list.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.name < b.name)
	return {"cursor":_m3_cursor_array(m3_cursor),"anchors":anchor_list,
		"logical_moves":m3_moves,"brush_lifted":true,
		"cursor_kind":"host_logical_no_native_pointer",
		"authority":"native_materials_host_only"}

func _m3_in_focus(pair: Variant) -> bool:
	return pair is Array and pair.size() == 2 \
		and bounded_integer(pair[0],0,95) and bounded_integer(pair[1],0,95)

func _m3_fence(request: Dictionary) -> String:
	if request.get("protocol_version") != 1 or request.get("request_id") != request_id \
			or request.get("kind") not in ["m3_cursor_move","m3_branch_save","m3_branch_relocate","m3_undo"]:
		return "M3 request protocol or order invalid"
	if not request.has("expires_unix") or not integer(request.expires_unix) \
			and not request.expires_unix is float:
		return "M3 missing real deadline"
	request_deadline = float(request.expires_unix)
	if not is_finite(request_deadline) or request_deadline <= Time.get_unix_time_from_system() \
			or request_deadline > Time.get_unix_time_from_system()+120:
		return "M3 expired or excessive deadline"
	if request.keys().size() != 8:
		return "M3 requires exact eight-envelope fields"
	if retired or cancelled() or not host.paused:
		return "M3 native episode retired, cancelled or unpaused"
	if not await until(ready,30000,true):
		return "M3 native Workbench not settled at admission"
	var state: Dictionary = worker.paint_state()
	for field: String in ["generation","revision","tick"]:
		var expected: Variant = request.get("expected_"+field)
		if not bounded_integer(expected,0,2147483647) or int(expected) != int(state[field]):
			return "M3 stale native "+field
	return ""

func _m3_refuse(reason: String, before: PackedInt32Array) -> Dictionary:
	var snapshot := observation(before)
	return {"status":"refused","reason":reason,"m3":_m3_status(),
		"observation":snapshot,
		"receipt":{"actual_changed_cells":0,"readback_matches":true,
			"before_world_sha256":material_hash(before),
			"after_world_sha256":material_hash(before),
			"history_events":[],"brush_lifted":true}}

func _m3_dispatch(request: Dictionary) -> Dictionary:
	var before: PackedInt32Array = await capture()
	if before.is_empty(): return {"status":"failed","reason":"Cannot capture M3 before state"}
	observation(before,"before")
	var reason: String = await _m3_fence(request)
	if not reason.is_empty(): return _m3_refuse(reason,before)
	var kind: String = str(request.kind)
	var payload: Variant = request.get("m3_payload")
	if not payload is Dictionary or payload.size() > 6:
		return _m3_refuse("M3 malformed payload",before)
	var state: Dictionary = worker.paint_state()
	var history_event: Dictionary = {}
	var native_changed := 0
	if kind == "m3_cursor_move":
		if payload.size()!=3 or not _m3_in_focus(payload.get("from")) \
				or not _m3_in_focus(payload.get("to")) or payload.get("brush_lifted") != true:
			return _m3_refuse("M3 illegal logical movement encoding",before)
		var origin := Vector2i(int(payload["from"][0]),int(payload["from"][1]))
		var target := Vector2i(int(payload["to"][0]),int(payload["to"][1]))
		if m3_cursor != origin or abs(target.x-origin.x)+abs(target.y-origin.y) != 1 \
				or m3_moves >= M3_MAX_LOGICAL_MOVES:
			return _m3_refuse("M3 cursor move is not cardinal or out of ordered budget",before)
		m3_cursor = target
		m3_moves += 1
	elif kind == "m3_branch_save":
		if payload.size()!=3 or not payload.get("name") is String \
				or not _m3_in_focus(payload.get("cursor")) \
				or payload.get("brush_lifted") != true:
			return _m3_refuse("M3 invalid anchor encoding",before)
		var name: String = str(payload.name)
		if name.is_empty() or name.length()>64 or m3_anchors.has(name) \
				or m3_anchors.size()>=4 \
				or Vector2i(int(payload.cursor[0]),int(payload.cursor[1])) != m3_cursor:
			return _m3_refuse("M3 anchor duplication or cursor mismatch",before)
		m3_anchors[name] = {"cursor":m3_cursor,"generation":int(state.generation)}
	elif kind == "m3_branch_relocate":
		if payload.size()!=3 or not payload.get("name") is String \
				or not _m3_in_focus(payload.get("from")) \
				or payload.get("brush_lifted") != true:
			return _m3_refuse("M3 invalid branch relocation encoding",before)
		var name: String = str(payload.name)
		if not m3_anchors.has(name):
			return _m3_refuse("M3 unknown branch anchor",before)
		var anchor: Dictionary = m3_anchors[name]
		var from := Vector2i(int(payload["from"][0]),int(payload["from"][1]))
		if int(anchor.generation) != int(state.generation) \
				or from != m3_cursor or m3_moves >= M3_MAX_LOGICAL_MOVES:
			return _m3_refuse("M3 stale branch anchor or logical cursor",before)
		m3_cursor = anchor.cursor
		m3_moves += 1
	elif kind == "m3_undo":
		if payload.size()!=2 or payload.get("history_action") != "undo" \
				or payload.get("brush_lifted") != true:
			return _m3_refuse("M3 malformed real history request",before)
		if not editor.history_available("undo"):
			return _m3_refuse("M3 real PAINT Undo unavailable at native source fence",before)
		m3_history_events.clear()
		if not editor.history_action_finished.is_connected(_m3_history_done):
			editor.history_action_finished.connect(_m3_history_done)
		if not editor.undo():
			return _m3_refuse("M3 PAINT history owner refused Undo admission",before)
		if not await until(settled,30000,true):
			return {"status":"failed","reason":"M3 native Undo did not settle",
				"m3":_m3_status()}
		if m3_history_events.is_empty():
			return {"status":"failed","reason":"M3 PAINT Undo missing native completion receipt",
				"m3":_m3_status()}
		history_event = m3_history_events.back().duplicate(true)
		if str(history_event.get("action","")) != "undo" \
				or str(history_event.get("status","")) != "completed" \
				or not bool(history_event.get("recorded",false)) \
				or bool(history_event.get("remaining_group",false)):
			return {"status":"failed","reason":"M3 native PAINT Undo incomplete or unrecorded",
				"m3":_m3_status(),"history_receipts":m3_history_events.duplicate(true)}
	var after: PackedInt32Array = await capture()
	if after.size()!=before.size(): return {"status":"failed","reason":"M3 incomplete native after readback"}
	for i: int in after.size():
		if after[i] != before[i]: native_changed += 1
	var is_undo := kind == "m3_undo"
	if is_undo:
		if native_changed != int(history_event.get("changed",-1)) or native_changed != 1:
			fatal = "M3 native Undo cell delta does not equal receipt and bound"
	else:
		if native_changed != 0 or material_hash(before) != material_hash(after):
			fatal = "M3 brush-up logical operation unexpectedly changed native material"
	var response := {"status":"completed" if fatal.is_empty() else "failed",
		"reason":fatal,"m3":_m3_status(),"observation":observation(after),
		"receipt":{"actual_changed_cells":native_changed,
			"readback_matches":fatal.is_empty(),
			"before_world_sha256":material_hash(before),
			"after_world_sha256":material_hash(after),
			"history_events":m3_history_events.duplicate(true) if is_undo else [],
			"brush_lifted":true,
			"operation":"actual_native_PAINT_history_undo" if is_undo \
				else "host_logical_brush_up_only"}}
	if is_undo and not history_event.is_empty(): response["history_receipt"] = history_event
	return response

func dispatch(request: Dictionary) -> Dictionary:
	var kind: String = str(request.get("kind",""))
	if kind in ["m3_cursor_move","m3_branch_save","m3_branch_relocate","m3_undo"]:
		return await _m3_dispatch(request)
	var base: Dictionary = await super.dispatch(request)
	if kind == "reset" and str(base.get("status","")) == "completed":
		m3_cursor = M3_START
		m3_anchors.clear()
		m3_moves = 0
		m3_history_events.clear()
	if kind == "reset" or kind == "observe":
		base["m3"] = _m3_status()
	return base
