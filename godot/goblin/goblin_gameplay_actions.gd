extends RefCounted

## GIP-014-goblin-002: bounded adapters over ordinary Workbench controls.
## No mutation bypasses the normal editor, Workbench or application-local input.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const IDS := ["select_tool", "brush_radius", "stroke", "live_stroke",
	"preview_begin", "preview_cancel", "interrupt_stroke", "camera_pan", "camera_zoom",
	"camera_focus", "camera_mode", "actor_remove", "actor_move", "actor_save_spawn",
	"actor_capture_spawn", "actor_replace", "actor_release", "actor_hand_back",
	"actor_control", "actor_equipment", "actor_actuate", "actor_trigger", "response_mode",
	"actor_settings", "restore_start", "source_place", "source_burst", "source_stream",
	"replace_fixture"]
const MODELS := ["kestrel", "reference_barrel", "runner", "crawler", "monowheel", "stuntbuggy"]
const TOOLS := ["Brush", "Eraser", "Line", "Rectangle", "Outline", "Select", "Fill", "Paste"]
const MATERIALS := [0, 2, 3, 7, 8, 9, 12, 13, 14, 16, 19, 23, 25, 26, 27, 28, 29, 58]
const POWDERS := [2, 14, 29, 13, 19, 23, 25, 26, 27]
const MAX_ACTOR_ID := 64
const ARGUMENTS := {
	"select_tool": ["tool"], "brush_radius": ["radius"],
	"stroke": ["x0", "y0", "x1", "y1", "radius"],
	"live_stroke": ["x0", "y0", "x1", "y1", "radius"],
	"preview_begin": ["x0", "y0", "x1", "y1"], "preview_cancel": [],
	"interrupt_stroke": ["x0", "y0", "x1", "y1"],
	"camera_pan": ["dx", "dy"], "camera_zoom": ["direction"],
	"camera_focus": [], "camera_mode": ["mode"], "actor_remove": [],
	"actor_move": ["x", "y"], "actor_save_spawn": ["x", "y"], "actor_capture_spawn": [],
	"actor_replace": ["model"], "actor_release": [], "actor_hand_back": [],
	"actor_control": ["actor_id", "producer", "enabled"],
	"actor_equipment": ["actor_id", "usable_index"], "actor_actuate": ["port", "ticks"],
	"actor_trigger": ["button", "ticks"], "response_mode": ["mode"],
	"actor_settings": ["field", "value"], "restore_start": [], "source_place": ["x", "y"],
	"source_burst": [], "source_stream": ["enabled"], "replace_fixture": ["fixture"],
}
const PAUSED := ["stroke", "preview_begin", "preview_cancel", "interrupt_stroke",
	"actor_remove", "actor_move", "actor_save_spawn", "actor_capture_spawn", "actor_replace",
	"actor_release", "actor_hand_back", "actor_control", "actor_equipment", "response_mode",
	"actor_settings", "restore_start", "replace_fixture"]
const REPLACEMENTS := ["actor_remove", "actor_move", "actor_replace", "actor_equipment",
	"response_mode", "actor_settings", "restore_start"]
const PORT_KEYS := {"q": KEY_Q, "e": KEY_E, "boost": KEY_SHIFT, "primary": KEY_SPACE,
	"secondary": KEY_CTRL, "reel_in": KEY_Z, "reel_out": KEY_X}
const EQUIPMENT_KEYS := {"trigger": KEY_M, "alternate": KEY_ALT, "drop": KEY_N, "attach": KEY_U}


static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= low and value <= high


static func _number(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high


static func validate_action(action: Dictionary) -> Dictionary:
	var id: String = str(action.get("id", ""))
	if id not in IDS or not action.get("args") is Dictionary:
		return {"ok": false, "error": "unknown expanded action or missing args"}
	var args: Dictionary = action.args
	for key: Variant in args:
		if str(key) not in ARGUMENTS[id]: return {"ok": false, "error": "unknown expanded argument"}
	for key: String in ARGUMENTS[id]:
		if not args.has(key): return {"ok": false, "error": "missing argument " + key}
	match id:
		"select_tool":
			if args.tool not in TOOLS: return {"ok": false, "error": "unknown ordinary editor tool"}
		"brush_radius":
			if not _integer(args.radius, 0, 4): return {"ok": false, "error": "radius outside 0..4"}
		"stroke", "live_stroke", "preview_begin", "interrupt_stroke":
			for key: String in ["x0", "y0", "x1", "y1"]:
				if not _integer(args[key], 8, 503): return {"ok": false, "error": "stroke endpoint outside fixture"}
			if absf(args.x1 - args.x0) > 32 or absf(args.y1 - args.y0) > 32:
				return {"ok": false, "error": "stroke exceeds 32-cell span"}
			if id in ["stroke", "live_stroke"] and not _integer(args.radius, 0, 4):
				return {"ok": false, "error": "stroke radius outside 0..4"}
		"camera_pan":
			if not _integer(args.dx, -128, 128) or not _integer(args.dy, -128, 128):
				return {"ok": false, "error": "pan outside bounded displacement"}
		"camera_zoom":
			if not _integer(args.direction, -1, 1) or int(args.direction) == 0:
				return {"ok": false, "error": "zoom direction must be -1 or 1"}
		"camera_mode":
			if args.mode not in ["free", "follow", "overview"]:
				return {"ok": false, "error": "unsupported ordinary camera mode"}
		"actor_move", "actor_save_spawn":
			if not _integer(args.x, 32, 448) or not _integer(args.y, 32, 224):
				return {"ok": false, "error": "actor position outside disposable spawn region"}
		"actor_replace":
			if args.model not in MODELS: return {"ok": false, "error": "model outside bounded catalogue"}
		"actor_control":
			if not _integer(args.actor_id, 1, MAX_ACTOR_ID) or args.producer not in ["human", "scripted", "passive"] \
				or typeof(args.enabled) != TYPE_BOOL: return {"ok": false, "error": "unsupported actor controller"}
		"actor_equipment":
			if not _integer(args.actor_id, 1, MAX_ACTOR_ID) or not _integer(args.usable_index, -1, 31):
				return {"ok": false, "error": "equipment identity outside bounded catalogue"}
		"actor_actuate", "actor_trigger":
			var key: String = "port" if id == "actor_actuate" else "button"
			var choices: Dictionary = PORT_KEYS if id == "actor_actuate" else EQUIPMENT_KEYS
			if not args[key] is String or not choices.has(args[key]) or not _integer(args.ticks, 1, 16):
				return {"ok": false, "error": "unsupported bounded actor input"}
		"response_mode":
			if args.mode not in Setup.RESPONSES: return {"ok": false, "error": "unsupported response mode"}
		"actor_settings":
			if args.field not in ["budget", "mass_multiplier", "inertia_multiplier"]:
				return {"ok": false, "error": "unsupported typed actor setting"}
			var low: float = 5.0 if args.field == "budget" else 0.5
			var high: float = 40.0 if args.field == "budget" else 2.0
			if not _number(args.value, low, high): return {"ok": false, "error": "actor setting exceeds campaign bounds"}
		"source_place":
			if not _integer(args.x, 8, 480) or not _integer(args.y, 8, 224):
				return {"ok": false, "error": "source outside bounded fixture"}
		"source_stream":
			if typeof(args.enabled) != TYPE_BOOL: return {"ok": false, "error": "stream requires boolean"}
		"replace_fixture":
			if args.fixture not in Fixtures.IDS: return {"ok": false, "error": "unknown committed scenario"}
	return {"ok": true}


static func ports_for(model: String) -> Array[String]:
	var result: Array[String] = []
	if Catalog.Fleet.index_for_id(model) >= 0:
		return ["q", "e", "boost"]
	var profile: Dictionary = Catalog.definition(model).get("profile", {})
	for port: String in ["primary", "secondary"]:
		if str(profile.get(port, "none")) not in ["", "none"]: result.append(port)
	if profile.get("rope", false): result.append_array(["reel_in", "reel_out"])
	return result


static func _offer(menu: Array[Dictionary], id: String, args: Dictionary = {}) -> void:
	menu.append({"id": id, "args": args})


static func _pending_settings(a: Variant) -> Dictionary:
	# Apply settings reads the currently displayed fields, including values left
	# pending after an expected refusal. Preflight that actual ordinary form.
	var candidate: Dictionary = a.bench.applied.duplicate(true)
	candidate.response = str(a.bench._requested_response)
	var selected: Dictionary = a.bench.actor(candidate, a.bench.selected_id())
	if not selected.is_empty():
		for field: String in a.bench._fields:
			selected.options[field] = float(a.bench._fields[field].value)
	return candidate


static func available_actions(a: Variant) -> Array[Dictionary]:
	var menu: Array[Dictionary] = []
	var observation: Dictionary = a.observe()
	var visible := Rect2i(Vector2i(a.host.camera_origin.floor()), a.host.current_view_size)
	var from: Vector2i = visible.position + Vector2i(32, 32)
	var to: Vector2i = from + Vector2i(16, 8)
	var stroke := {"x0": from.x, "y0": from.y, "x1": to.x, "y1": to.y, "radius": 2}
	var preview := {"x0": from.x, "y0": from.y, "x1": to.x, "y1": to.y}
	var can_stroke: bool = validate_action({"id": "stroke", "args": stroke}).ok \
		and visible.encloses(_region(stroke))
	for tool: String in TOOLS:
		if not a.host.paused and tool not in ["Brush", "Eraser"]: continue
		if tool == "Paste" and a.editor.clipboard.is_empty(): continue
		if a.editor.tool_name() != tool: _offer(menu, "select_tool", {"tool": tool})
	for radius: int in [0, 2, 4]:
		if int(a.editor.radius()) != radius: _offer(menu, "brush_radius", {"radius": radius})
	for delta: Vector2i in [Vector2i(-64, 0), Vector2i(64, 0), Vector2i(0, -64), Vector2i(0, 64)]:
		var bound := Vector2(Setup.extent_of(a.bench.applied) - a.host.current_view_size)
		if Vector2(a.host.camera_origin) != (Vector2(a.host.camera_origin) + Vector2(delta)).clamp(Vector2.ZERO, bound):
			_offer(menu, "camera_pan", {"dx": delta.x, "dy": delta.y})
	if int(a.bench._zoom) > 0: _offer(menu, "camera_zoom", {"direction": -1})
	if int(a.bench._zoom) < a.bench.ZOOMS.size() - 1: _offer(menu, "camera_zoom", {"direction": 1})
	for mode: String in ["free", "overview"]:
		if int(a.bench._camera.selected) != (0 if mode == "free" else 2):
			_offer(menu, "camera_mode", {"mode": mode})
	if a.bench.selected_id() > 0:
		_offer(menu, "camera_focus")
		if int(a.bench._camera.selected) != 1: _offer(menu, "camera_mode", {"mode": "follow"})
	var source: Dictionary = observation.get("source", {}).get("receipt", {})
	var stream: bool = bool(source.get("stream_enabled", false))
	if int(a.editor.material_id) in POWDERS:
		_offer(menu, "source_place", {"x": 220, "y": 48})
	if not a.host.paused:
		if can_stroke and not stream and not a.editor.recovery_required() and int(a.editor.material_id) in Setup.MATERIALS:
			_offer(menu, "live_stroke", stroke)
		if not a.bench.applied.get("source", []).is_empty():
			_offer(menu, "source_stream", {"enabled": not stream})
			if not stream: _offer(menu, "source_burst")
		if a.bench.pilot_id() > 0:
			var pilot: Dictionary = a.bench.actor(a.bench.applied, a.bench.pilot_id())
			var model: String = str(pilot.get("model", ""))
			var ports: Array = ports_for(model)
			for port: String in ports: _offer(menu, "actor_actuate", {"port": port, "ticks": 4})
			if Catalog.entry(model).get("equipment", false) and int(Catalog.control_for(pilot).usable_index) >= 0:
				for button: String in EQUIPMENT_KEYS: _offer(menu, "actor_trigger", {"button": button, "ticks": 4})
		return menu
	if can_stroke and not stream and not a.editor.recovery_required():
		_offer(menu, "stroke", stroke)
		_offer(menu, "preview_begin", preview)
		_offer(menu, "interrupt_stroke", preview)
	if a.editor.dragging: _offer(menu, "preview_cancel")
	var selected: int = a.bench.selected_id()
	if selected > 0:
		_offer(menu, "actor_remove")
		_offer(menu, "actor_move", {"x": 256, "y": 120})
		_offer(menu, "actor_save_spawn", {"x": 224, "y": 112})
		_offer(menu, "actor_capture_spawn")
		if int(a.bench.applied.next_id) <= MAX_ACTOR_ID:
			for model: String in MODELS:
				if Catalog.has_model(model) and model in a.bench._model_ids:
					_offer(menu, "actor_replace", {"model": model})
		for field: String in ["budget", "mass_multiplier", "inertia_multiplier"]:
			if a.bench._fields.has(field) and a.bench._fields[field].editable:
				var value: float = 15.0 if field == "budget" else 1.25
				var candidate: Dictionary = _pending_settings(a)
				a.bench.actor(candidate, selected).options[field] = snappedf(value, float(a.bench._fields[field].step))
				if Setup.validate(candidate, false).is_empty():
					_offer(menu, "actor_settings", {"field": field, "value": value})
	if a.bench.pilot_id() > 0:
		_offer(menu, "actor_release")
		_offer(menu, "actor_hand_back")
	for actor: Dictionary in a.bench.applied.get("actors", []):
		var current_control: Dictionary = Catalog.control_for(actor)
		for producer: String in ["human", "scripted", "passive"]:
			if current_control.source == producer and current_control.enabled: continue
			if Catalog.supports(str(actor.model), producer):
				_offer(menu, "actor_control", {"actor_id": int(actor.id), "producer": producer, "enabled": true})
		if Catalog.entry(str(actor.model)).get("equipment", false):
			for usable: int in [-1, int(Catalog.default_control(str(actor.model)).usable_index)]:
				if int(current_control.usable_index) == usable: continue
				if Catalog.equipment_error(str(actor.model), usable).is_empty():
					_offer(menu, "actor_equipment", {"actor_id": int(actor.id), "usable_index": usable})
	for mode: String in Setup.RESPONSES:
		if mode == a.bench.applied.response: continue
		var candidate: Dictionary = _pending_settings(a)
		candidate.response = mode
		if Setup.validate(candidate, false).is_empty(): _offer(menu, "response_mode", {"mode": mode})
	_offer(menu, "restore_start")
	for fixture: String in Fixtures.IDS:
		if fixture != a.fixture_id: _offer(menu, "replace_fixture", {"fixture": fixture})
	return menu


static func _region(args: Dictionary) -> Rect2i:
	var radius: int = int(args.get("radius", 0))
	var low := Vector2i(mini(int(args.x0), int(args.x1)), mini(int(args.y0), int(args.y1))) - Vector2i.ONE * radius
	var high := Vector2i(maxi(int(args.x0), int(args.x1)), maxi(int(args.y0), int(args.y1))) + Vector2i.ONE * radius
	return Rect2i(low, high - low + Vector2i.ONE)


static func _preview(a: Variant, args: Dictionary) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = a._local(Vector2i(int(args.x0), int(args.y0)))
	a.bench._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = a._local(Vector2i(int(args.x1), int(args.y1)))
	motion.relative = motion.position - press.position
	a.bench._world_input(motion)


static func _result(a: Variant, row: Dictionary, started: int, status: String, error: String = "", classification: String = "game_observation") -> Dictionary:
	return a._finish(row, started, status, classification, error)


static func _input_pulse(a: Variant, row: Dictionary, args: Dictionary, equipment: bool) -> bool:
	if a.host.paused or a.bench.pilot_id() <= 0 or a.host.physical_actor_session == null:
		row.error = "active ordinary pilot is unavailable"
		return false
	var actor: Dictionary = a.bench.actor(a.bench.applied, a.bench.pilot_id())
	var fleet: bool = a.bench.Fleet.index_for_id(str(actor.model)) >= 0
	if equipment and (not Catalog.entry(str(actor.model)).get("equipment", false) or int(Catalog.control_for(actor).usable_index) < 0):
		row.error = "pilot has no mounted selected equipment"
		return false
	if not equipment and str(args.port) not in ports_for(str(actor.model)):
		row.error = "pilot does not expose that ordinary actuator capability"
		return false
	var focus: Control = a.get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	a._release_keys()
	if not await a._until(func() -> bool: return not a.host._actor_input_rearm, "operation_seconds"):
		row.error = a.last_error
		return false
	var before: Dictionary = a.host.physical_actor_session.workbench_control(a.bench.pilot_id())
	var key: String = str(args.button) if equipment else str(args.port)
	var code: int = int(EQUIPMENT_KEYS[key] if equipment else PORT_KEYS[key])
	if not equipment and key == "secondary" and not fleet: code = KEY_SHIFT
	a._key(code, true)
	a._admit(row, {"accepted": true, "delivery": "Godot application-local input event", "input": key})
	row.interval = await a._tick_interval(int(args.ticks), true)
	var slot: int = a.host.physical_actor_session.slot_for_instance(a.bench.pilot_id())
	row["actor_delivery"] = {"instance_id": a.bench.pilot_id(), "input": key, "before": a.json_value(before),
		"during": a.json_value(a.host.physical_actor_session.workbench_control(a.bench.pilot_id())),
		"sampled_command": a.json_value(a.host.physical_actor_session._commands[slot]) if slot >= 0 else {},
		"sampled_ports": a.json_value(a.host.physical_actor_session._workbench_ports.get(slot, {})) if slot >= 0 else {}}
	a._release_keys()
	if not row.interval.ok:
		row.error = a.last_error
		return false
	var released: Dictionary = await a._tick_interval(1, true)
	row.actor_delivery["release_interval"] = released
	row.actor_delivery["released_command"] = a.json_value(a.host.physical_actor_session._commands[slot]) if slot >= 0 else {}
	row.actor_delivery["released_ports"] = a.json_value(a.host.physical_actor_session._workbench_ports.get(slot, {})) if slot >= 0 else {}
	if not released.ok: row.error = a.last_error
	return bool(released.ok)


static func execute(a: Variant, action: Dictionary, row: Dictionary, started: int) -> Dictionary:
	var id: String = str(action.id)
	var args: Dictionary = action.args
	if id in PAUSED and not a.host.paused:
		return _result(a, row, started, "refused", "this action requires paused authoring", "not_applicable")
	var first_generation: int = int(a.worker.paint_state().generation)
	var first_epoch: int = int(a.host._physical_epoch)
	match id:
		"select_tool":
			var index: int = TOOLS.find(str(args.tool))
			a.editor._tools.select(index)
			a.editor._tools.item_selected.emit(index)
			a._admit(row, {"accepted": true, "control": "ordinary editor tool picker"})
		"brush_radius":
			a.bench._brush.value = int(args.radius)
			a._admit(row, {"accepted": true, "control": "ordinary brush radius"})
		"stroke", "live_stroke", "preview_begin", "interrupt_stroke":
			if id == "live_stroke" and a.host.paused:
				return _result(a, row, started, "refused", "live brush requires running simulation", "not_applicable")
			var region := _region(args)
			var visible := Rect2i(Vector2i(a.host.camera_origin.floor()), a.host.current_view_size)
			if not visible.encloses(region):
				return _result(a, row, started, "refused", "gesture outside current view", "not_applicable")
			if id == "live_stroke" and int(a.editor.material_id) not in Setup.MATERIALS:
				return _result(a, row, started, "refused", "material unavailable to ordinary running brush", "not_applicable")
			if id in ["stroke", "interrupt_stroke"]:
				row.capture_before = await a.capture(region)
				if row.capture_before.has("error"):
					return _result(a, row, started, "refused", row.capture_before.error, a._capture_failure_classification(row.capture_before))
			if a.stopped: return _result(a, row, started, "refused", "Stop requested", "cancelled")
			a.editor.select_tool("Rectangle" if id == "interrupt_stroke" else "Brush")
			a.bench._brush.value = int(args.get("radius", 0))
			row.before = a.observe()
			var completed: int = int(a.editor.completed_actions)
			var prior_operation: int = int(a.editor.last_receipt.get("operation_id", -1))
			var authored_count: int = a.bench.applied.edits.size()
			if id == "preview_begin":
				_preview(a, args)
				a._admit(row, {"accepted": bool(a.editor.dragging), "control": "ordinary unfinished gesture"})
				if not a.editor.dragging: return _result(a, row, started, "refused", str(a.bench.message))
			else:
				a._gesture(Vector2i(int(args.x0), int(args.y0)), Vector2i(int(args.x1), int(args.y1)))
				var accepted: bool = a.editor.busy() if id != "live_stroke" else a.bench.applied.edits.size() > authored_count
				a._admit(row, {"accepted": accepted, "control": "ordinary editor gesture"})
				if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
				if id == "interrupt_stroke":
					row["interruption"] = {"observed_busy": bool(a.editor.busy()), "native_operation_before": prior_operation}
					a.editor.cancel()
				if id == "live_stroke":
					row["live_edit"] = {"authored_before": authored_count, "authored_after": a.bench.applied.edits.size(),
						"stamps": a.json_value(a.bench.applied.edits.slice(authored_count)),
						"semantics": "ordinary running brush; no atomic before/after material equality"}
					row.interval = await a._tick_interval(4)
					if not row.interval.ok: return _result(a, row, started, "partial", a.last_error, a._wait_failure_classification())
				else:
					if not await a._until(a._settled, "operation_seconds", true):
						return _result(a, row, started, "partial", a.last_error, a._wait_failure_classification())
					if int(a.editor.last_receipt.get("operation_id", -1)) != prior_operation:
						row.native_receipt = a.json_value(a.editor.last_receipt)
					if id == "stroke" and (int(a.editor.completed_actions) <= completed or row.native_receipt.get("status", "") != "completed"):
						return _result(a, row, started, "refused", str(a.bench.message), "cancelled" if a.stopped else "game_observation")
					row.capture_after = await a.capture(region)
					if row.capture_after.has("error"):
						return _result(a, row, started, "partial", row.capture_after.error, a._capture_failure_classification(row.capture_after))
					if id == "stroke": a._last_edit_region = region
					if id == "interrupt_stroke":
						row.interruption["terminal"] = "native_partial" if int(row.native_receipt.get("applied", 0)) > 0 else "cancelled_before_native"
						row.interruption["editor_idle"] = not a.editor.busy()
		"preview_cancel":
			if not a.editor.dragging: return _result(a, row, started, "refused", "no ordinary preview is active", "not_applicable")
			a.editor._cancel_button.pressed.emit()
			a._admit(row, {"accepted": true, "control": "ordinary Cancel button"})
		"camera_pan":
			a.bench._camera.select(0)
			a.bench._set_view(Vector2(a.host.camera_origin) + Vector2(float(args.dx), float(args.dy)), a.host.current_view_size)
			a._admit(row, {"accepted": true, "control": "ordinary bounded camera navigation"})
		"camera_zoom":
			a.bench.zoom_by(int(args.direction))
			a._admit(row, {"accepted": true})
		"camera_focus":
			if a.bench.selected_id() <= 0: return _result(a, row, started, "refused", "select an actor before Focus", "not_applicable")
			a.bench.focus_selected()
			a._admit(row, {"accepted": true})
		"camera_mode":
			var index: int = ["free", "follow", "overview"].find(str(args.mode))
			if index == 1 and a.bench.selected_id() <= 0:
				return _result(a, row, started, "refused", "follow needs a selected actor", "not_applicable")
			a.bench._camera.select(index)
			a.bench._camera.item_selected.emit(index)
			a._admit(row, {"accepted": true})
		"actor_remove", "actor_move", "actor_save_spawn", "actor_capture_spawn", "actor_replace":
			if a.bench.selected_id() <= 0: return _result(a, row, started, "refused", "select an actual actor first", "not_applicable")
			if id == "actor_replace":
				if int(a.bench.applied.next_id) > MAX_ACTOR_ID:
					return _result(a, row, started, "refused", "bounded actor identity budget exhausted", "not_applicable")
				var model_index: int = a.bench._model_ids.find(str(args.model))
				if model_index < 0: return _result(a, row, started, "refused", "model absent from ordinary picker", "not_applicable")
				a.bench._model.select(model_index)
			if id in ["actor_move", "actor_save_spawn"]:
				a.bench._position[0].value = int(args.x)
				a.bench._position[1].value = int(args.y)
			var accepted := false
			match id:
				"actor_remove": accepted = a.bench.remove_selected()
				"actor_move": accepted = a.bench.move_selected()
				"actor_save_spawn": accepted = a.bench.save_spawn()
				"actor_capture_spawn": accepted = a.bench.capture_spawn()
				"actor_replace": accepted = a.bench.replace_selected()
			a._admit(row, {"accepted": accepted, "pending_serial": int(a.host.pending_microscenario_apply.get("serial", -1))})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
		"actor_release":
			if a.bench.pilot_id() <= 0: return _result(a, row, started, "refused", "no human pilot to release", "not_applicable")
			a.bench.release_pilot()
			a._admit(row, {"accepted": true})
		"actor_hand_back":
			var accepted: bool = a.bench.hand_back_pilot()
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
		"actor_control":
			var actor: Dictionary = a.bench.actor(a.bench.applied, int(args.actor_id))
			if actor.is_empty() or not Catalog.supports(str(actor.get("model", "")), str(args.producer)):
				return _result(a, row, started, "refused", "actual actor does not support producer", "not_applicable")
			var control: Dictionary = Catalog.control_for(actor)
			control.source = str(args.producer)
			control.enabled = bool(args.enabled)
			var accepted: bool = a.bench.set_actor_control(int(args.actor_id), control)
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
		"actor_equipment":
			var actor: Dictionary = a.bench.actor(a.bench.applied, int(args.actor_id))
			if actor.is_empty() or not Catalog.equipment_error(str(actor.get("model", "")), int(args.usable_index)).is_empty():
				return _result(a, row, started, "refused", "actual actor does not support requested equipment", "not_applicable")
			var accepted: bool = a.bench.apply_actor_equipment(int(args.actor_id), int(args.usable_index))
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
		"actor_actuate", "actor_trigger":
			if not await _input_pulse(a, row, args, id == "actor_trigger"):
				return _result(a, row, started, "partial" if row.admission.get("accepted", false) else "refused",
					str(row.error), a._wait_failure_classification() if row.admission.get("accepted", false) else "not_applicable")
		"response_mode", "actor_settings":
			if id == "response_mode":
				var index: int = Setup.RESPONSES.find(str(args.mode))
				a.bench._response.select(index)
				a.bench._response.item_selected.emit(index)
			else:
				if a.bench.selected_id() <= 0 or not a.bench._fields.has(args.field) or not a.bench._fields[args.field].editable:
					return _result(a, row, started, "refused", "setting not editable for actual selected actor", "not_applicable")
				a.bench._fields[args.field].value = float(args.value)
			var accepted: bool = a.bench.apply_settings()
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
		"restore_start":
			var accepted: bool = a.bench.restore_start()
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
		"source_place":
			if int(a.editor.material_id) not in POWDERS:
				return _result(a, row, started, "refused", "ordinary source supports powders only", "not_applicable")
			var accepted: bool = a.bench.place_source(Vector2i(int(args.x), int(args.y)))
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
			if not await a._until(func() -> bool:
				var observed: Dictionary = a.observe().get("source", {})
				var actual: Dictionary = observed.get("receipt", {})
				return int(observed.get("pending_commands", -1)) == 0 \
					and int(observed.get("snapshot_serial", -1)) > int(row.before.get("snapshot_serial", -1)) \
					and actual.get("material", -1) == int(a.editor.material_id) and actual.get("origin", []) == [int(args.x), int(args.y)] \
					and not actual.get("stream_enabled", true) and not actual.get("burst_queued", true) and int(actual.get("stream_ticks", -1)) == 0,
				"operation_seconds", true):
				return _result(a, row, started, "partial", a.last_error, a._wait_failure_classification())
		"source_burst", "source_stream":
			if a.host.paused or a.bench.applied.get("source", []).is_empty():
				return _result(a, row, started, "refused", "source requires a configured running fixture", "not_applicable")
			if id == "source_stream" and bool(args.enabled) and row.before.get("source", {}).get("receipt", {}).get("stream_enabled", false):
				return _result(a, row, started, "refused", "the bounded stream is already active; stop it before restarting", "not_applicable")
			if id == "source_burst" and row.before.get("source", {}).get("receipt", {}).get("stream_enabled", false):
				return _result(a, row, started, "refused", "stop the stream before the isolated burst experiment", "not_applicable")
			var accepted: bool = a.bench.burst() if id == "source_burst" else a.bench.stream(bool(args.enabled))
			a._admit(row, {"accepted": accepted})
			if not accepted: return _result(a, row, started, "refused", str(a.bench.message))
			if id == "source_stream": a.bench._stream.set_pressed_no_signal(bool(args.enabled))
			row.interval = await a._tick_interval(4)
			if not row.interval.ok: return _result(a, row, started, "partial", a.last_error, a._wait_failure_classification())
			var initial: Dictionary = row.before.get("source", {}).get("receipt", {})
			if not await a._until(func() -> bool:
				var observed: Dictionary = a.observe().get("source", {})
				var actual: Dictionary = observed.get("receipt", {})
				return int(observed.get("pending_commands", -1)) == 0 \
					and int(observed.get("snapshot_serial", -1)) > int(row.before.get("snapshot_serial", -1)) \
					and (int(actual.get("attempted", 0)) >= int(initial.get("attempted", 0)) + 96 if id == "source_burst"
					else bool(actual.get("stream_enabled", false)) == bool(args.enabled)),
				"operation_seconds", true):
				return _result(a, row, started, "partial", a.last_error, a._wait_failure_classification())
		"replace_fixture":
			var result: Dictionary = await a.install_fixture(str(args.fixture), Fixtures.build(str(args.fixture), a.policy()), row)
			if not result.get("ok", false):
				return _result(a, row, started, "partial" if row.admission.get("accepted", false) else "refused",
					str(result.get("error", "fixture replacement refused")), str(result.get("classification", "game_observation")))
			row.native_receipt = result.get("native_receipt", {}).duplicate(true)
	if id in REPLACEMENTS:
		if not await a._until(a._ready_for_action, "main_ack_seconds", true):
			return _result(a, row, started, "partial", a.last_error, a._wait_failure_classification())
		row.native_receipt = a.json_value(a.host.tower_context.get("liquid_construction_receipt", {}))
		row["replacement"] = {"generation_before": first_generation, "generation_after": int(a.worker.paint_state().generation),
			"physical_epoch_before": first_epoch, "physical_epoch_after": int(a.host._physical_epoch)}
		if int(a.worker.paint_state().generation) <= first_generation:
			return _result(a, row, started, "refused", str(a.host.microscenario_error))
		if a.bench.applied.get("actors", []).is_empty():
			if a.host.physical_actor_session != null:
				return _result(a, row, started, "partial", "empty replacement retained an actor session")
		elif int(a.host._physical_epoch) <= first_epoch or not a.host._physical_terrain_ready:
			return _result(a, row, started, "partial", "replacement has no adopted physical graph")
	if a.stopped: return _result(a, row, started, "partial", "Stop requested", "cancelled")
	return _result(a, row, started, "completed")
