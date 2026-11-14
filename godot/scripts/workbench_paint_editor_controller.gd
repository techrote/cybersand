extends HFlowContainer

signal deferred_brush_finished(token: int, receipt: Dictionary)
signal history_action_finished(receipt: Dictionary)
signal selection_changed(region: Rect2i)

# One human editor over the existing host and exclusive native worker.
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const History = preload("res://scripts/workbench_paint_editor_history.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const MaterialBaseline = preload("res://scripts/workbench_material_baseline.gd")
const TOOLS := ["Brush","Eraser","Line","Rectangle","Outline","Select","Fill","Paste"]
const MAX_CELLS := 262144
const MAX_HISTORY := 32
const HISTORY_CELLS := 1048576
var bench: Control
var host: Control
var selection := Rect2i()
var cursor := Vector2i(-1,-1)
var anchor := Vector2i(-1,-1)
var dragging := false
var drag_erase := false
var stroke: Array[Vector2i] = []
var clipboard: Dictionary = {}
var material_id := 2
var _tools := OptionButton.new()
var tools: OptionButton = _tools
var _status := Label.new()
var _copy := Button.new()
var _paste := Button.new()
var _undo_button := Button.new()
var _redo_button := Button.new()
var _cancel_button := Button.new()
var _overlay: Control
var _planner: Thread
var _planning_job: Dictionary = {}
var _planning_cancelled := false
var _operation: Dictionary = {}
var _undo_stack: Array = []
var _redo_stack: Array = []
var _history_fence: Dictionary = {}
var _save_hold := false
var _message := "Drag to paint · paused construction"
var last_result: Dictionary = {}
var last_receipt: Dictionary = {}
var _retired_operation := 0
var _retired_history_job: Dictionary = {}
var completed_actions := 0
var _agent_history: Dictionary = {}
var _agent_submission := -1
var _agent_group := 0
var _next_history_group := 0
var _history_replay: Dictionary = {}
var history_notice := ""

func mount(workbench: Control) -> void:
	bench = workbench
	host = bench.host
	add_theme_constant_override("h_separation",5)
	for text: String in TOOLS: _tools.add_item(text)
	_tools.tooltip_text = "B Brush · E Eraser · L Line · R Rectangle · O Outline · S Select · G Fill · V Paste"
	_tools.item_selected.connect(func(index: int) -> void: select_tool(TOOLS[index]))
	add_child(_tools)
	for entry: Array in [[_copy,"Copy",copy_selection],[_paste,"Paste",func() -> void: select_tool("Paste")],
			[_undo_button,"Undo",undo],[_redo_button,"Redo",redo],[_cancel_button,"Cancel",cancel]]:
		var button: Button = entry[0]
		button.text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[2])
		add_child(button)
	_copy.tooltip_text = "Ctrl+C · capture exact native materials in the selection"
	_paste.tooltip_text = "Ctrl+V · drag a multi-material stamp; Empty is included"
	_undo_button.tooltip_text = "Ctrl+Z · undo manual or agent edits; Stop the agent first; simulation invalidates history"
	_redo_button.tooltip_text = "Ctrl+Y / Ctrl+Shift+Z"
	_cancel_button.tooltip_text = "Escape · cancel preview or stop after the current native slice"
	_status.text = _message
	_status.custom_minimum_size = Vector2(300,20)
	add_child(_status)
	var overlay_script: Script = load("res://scripts/workbench_paint_editor_overlay.gd")
	if overlay_script != null:
		_overlay = overlay_script.new()
		_overlay.editor = self
		host.world_view.add_child(_overlay)
	for id: int in host.simulation_worker.paint_materials(): Setup._stamp_material(id)

func busy() -> bool:
	return _planner != null or not _operation.is_empty() or not _history_replay.is_empty()

func history_replaying() -> bool:
	return not _history_replay.is_empty() or str(_planning_job.get("history_action","")) != "" \
		or str(_operation.get("job",{}).get("history_action","")) != ""

func history_available(action: String) -> bool:
	if action not in ["undo","redo"] or busy() or host == null or not host.paused: return false
	if bench.is_flatten_pending(): return false
	if bench.has_method("art_history_guard") and not str(bench.art_history_guard()).is_empty(): return false
	if action == "redo" and _save_hold: return false
	var stack: Array = _undo_stack if action == "undo" else _redo_stack
	var state := _current()
	return not stack.is_empty() and not _history_fence.is_empty() and _source(state) == _history_fence \
		and not bool(state.get("busy",true)) and not bool(state.get("art_busy",false)) \
		and not bool(state.get("legacy_busy",false)) and not bool(state.get("transition_busy",false))

func recovery_required() -> bool:
	return _save_hold

func save_allowed() -> bool:
	var state := _current()
	if busy() or bool(state.get("busy",false)) or bool(state.get("art_busy",false)) \
			or bool(state.get("legacy_busy",false)) or bool(state.get("transition_busy",false)):
		_say("Wait for all native edits and their completion receipts before saving.")
		return false
	if _save_hold:
		_say("Partial edit cannot be saved. Undo it or Restore start first.")
		return false
	return true

func paint_mode_active() -> bool:
	return bench != null and not bench.applied.is_empty() and bench._tool.selected == 0

func tool_name() -> String:
	return TOOLS[maxi(0,_tools.selected)]

func radius() -> int:
	return clampi(int(bench._brush.value),0,24) if bench != null else 0

func extent() -> Vector2i:
	return Setup.extent_of(bench.applied) if bench != null and not bench.applied.is_empty() else Vector2i.ZERO

func drag_region() -> Rect2i:
	return Rect2i(anchor.min(cursor),anchor.max(cursor)-anchor.min(cursor)+Vector2i.ONE)

func select_material(id: int) -> void:
	if host != null and id not in host.simulation_worker.paint_materials():
		_say("That material is unavailable in the loaded native runtime.")
		return
	material_id = id
	cancel_preview()
	if bench != null:
		for index: int in bench._material.item_count:
			if bench._material.get_item_id(index) == id:
				bench._material.select(index)
				break
	if host != null: _say("%s · %s · radius %d" % [tool_name(),host.material_name(id),radius()])

func select_tool(tool: String) -> void:
	var index := TOOLS.find(tool)
	if index < 0: return
	cancel_preview()
	_tools.select(index)
	if bench != null: bench._tool.select(0)
	if tool == "Paste" and clipboard.is_empty(): _say("Select a region, then Copy before pasting.")

func _say(message: String) -> void:
	_message = message
	_status.text = message
	if bench != null: bench.message = message

func invalidate_history(reason: String = "Source changed") -> void:
	var had_history := not _undo_stack.is_empty() or not _redo_stack.is_empty() or not _agent_history.is_empty()
	_undo_stack.clear()
	_redo_stack.clear()
	_history_fence.clear()
	_agent_history.clear()
	_agent_submission = -1
	_agent_group = 0
	_history_replay.clear()
	history_notice = ""
	if had_history: _say(reason+" · undo history cleared.")

# Called on the main thread around the existing agent's authored-stamp recorder.
# Native ownership and material policy stay in their original executors.
func before_agent_receipt(receipt: Dictionary, submission: int) -> void:
	if int(receipt.get("changed",0)) == 0: return
	var before: Dictionary = receipt.get("before_source",{})
	var after := _source(receipt)
	if not host.paused or before.is_empty() or _source(_current()) != after \
			or int(before.get("generation",-1)) != int(after.generation) \
			or int(before.get("tick",-1)) != int(after.tick):
		invalidate_history("Agent drawing overlapped simulation or a World change")
		return
	if not _history_fence.is_empty() and _source(before) != _history_fence:
		invalidate_history("Another edit changed the source before agent drawing")
	if submission != _agent_submission:
		finish_agent_history()
		_agent_submission = submission
	# Each retained part fits one existing PAINT request. A single Undo drains
	# adjacent parts of this group; a human interleave starts another group.
	if not _agent_history.is_empty() \
			and _agent_history.rows.size()+receipt.get("readback",[]).size() > MAX_CELLS:
		_seal_agent_history()
	if _agent_group == 0:
		_next_history_group += 1
		_agent_group = _next_history_group
	if _agent_history.is_empty():
		_agent_history = {"rows":{},"before_edits":bench.applied.edits.duplicate(true),
			"agent_group":_agent_group,"submission":submission}

func after_agent_receipt(receipt: Dictionary) -> void:
	if int(receipt.get("changed",0)) == 0 or _agent_history.is_empty(): return
	var width := extent().x
	for row: Array in receipt.get("readback",[]):
		if row[2] == row[3]: continue
		var key := int(row[1])*width+int(row[0])
		var pair: Vector2i = _agent_history.rows.get(key,Vector2i(int(row[2]),int(row[3])))
		pair.y = int(row[3])
		_agent_history.rows[key] = pair
	_history_fence = _source(receipt)

func _seal_agent_history() -> void:
	if _agent_history.is_empty(): return
	var pending := _agent_history
	_agent_history = {}
	var ordered: Array = pending.rows.keys()
	ordered.sort()
	var cells := PackedInt32Array()
	var before := PackedInt32Array()
	var after := PackedInt32Array()
	cells.resize(ordered.size()*3)
	before.resize(ordered.size())
	after.resize(ordered.size())
	var width := extent().x
	var count := 0
	for key: int in ordered:
		var pair: Vector2i = pending.rows[key]
		if pair.x == pair.y: continue
		cells[count*3] = key%width
		cells[count*3+1] = key/width
		cells[count*3+2] = pair.y
		before[count] = pair.x
		after[count] = pair.y
		count += 1
	cells.resize(count*3)
	before.resize(count)
	after.resize(count)
	if cells.is_empty():
		# A paused paint/erase round trip has no net effect. Its redundant
		# stamps must not consume Undo or erase an existing Redo branch.
		bench.applied.edits = pending.before_edits.duplicate(true)
		return
	_redo_stack.clear()
	_undo_stack.append({"label":"Agent drawing","origin":"agent","agent_group":pending.agent_group,
		"cells":cells,"before":before,"after":after,"before_edits":pending.before_edits,
		"after_edits":bench.applied.edits.duplicate(true),"recover_only":false})
	_trim_history()

func finish_agent_history() -> void:
	if not _agent_history.is_empty():
		if host.paused and _source(_current()) == _history_fence:
			_seal_agent_history()
		else:
			invalidate_history("Simulation or another edit changed the agent result")
	_agent_submission = -1
	_agent_group = 0

func installed() -> void:
	cancel_preview()
	if not _operation.is_empty():
		_finish_deferred(_operation.get("job",{}), {"status":"invalidated","reason":"World replaced before human edit completion."})
		_retired_operation = int(_operation.operation_id)
		_retired_history_job = _operation.get("job",{})
		host.simulation_worker.paint_stop()
	if _planner != null: _planning_cancelled = true
	_operation.clear()
	selection = Rect2i()
	clipboard.clear()
	_save_hold = false
	invalidate_history("World replaced")
	if _overlay != null: _overlay.invalidate()

func flattened() -> void:
	# Admission guarantees no planner/edit/receipt remains. Retire only the old
	# construction history; preserve tools, clipboard and the current native World.
	cancel_preview()
	_save_hold = false
	invalidate_history("Authored baseline flattened")
	if _overlay != null: _overlay.invalidate()

func cancel_preview() -> void:
	dragging = false
	drag_erase = false
	stroke.clear()
	if _overlay != null: _overlay.queue_redraw()

func cancel() -> void:
	cancel_preview()
	_history_replay.clear()
	if _planner != null: _planning_cancelled = true
	if host != null and not _operation.is_empty():
		# A completed capture can already be waiting in the worker's receipt
		# slot. Stop fences future native slices, but that successful read must
		# not start a new Fill planner after the user cancelled this action.
		_operation.cancel_requested = true
		host.simulation_worker.paint_stop()
	_say("Stopping paint…" if busy() else "Preview cancelled.")

func _source(state: Dictionary) -> Dictionary:
	return {"generation":int(state.get("generation",-1)),"revision":int(state.get("revision",-1)),
		"tick":int(state.get("tick",-1)),"authoring_generation":int(state.get("authoring_generation",1))}

func _current() -> Dictionary:
	return host.simulation_worker.paint_state() if host != null else {}

func _ready_to_author(allow_hold: bool = false, continuing_history: bool = false) -> bool:
	if host == null or bench.applied.is_empty(): return false
	if bench.is_flatten_pending() or bool(_current().get("flatten_busy",false)):
		_say("Wait for Flatten material capture and baseline adoption.")
		return false
	if _planner != null or not _operation.is_empty() or (not continuing_history and not _history_replay.is_empty()) \
			or not host.pending_microscenario_apply.is_empty() or bench.step_pending \
			or host.simulation_worker.has_failed() or bool(_current().get("busy",true)) \
			or bool(_current().get("art_busy",false)) or bool(_current().get("legacy_busy",false)):
		_say("Wait for the current native operation.")
		return false
	if host.water_controlled_run_active() or host._microscenario_execution_locked():
		_say("This controlled session does not admit painting.")
		return false
	if bench._stream.button_pressed or bool(host.tower_context.get("workbench_source",{}).get("stream_enabled",false)):
		_say("Stop the active powder stream before authoring.")
		return false
	if not host.paused:
		_say("Pause the simulation before drawing, copying or filling.")
		return false
	if _save_hold and not allow_hold:
		_say("Undo the partial edit or Restore start before continuing.")
		return false
	return true

func _pixel(event: InputEventMouse) -> Vector2i:
	var pixel: Vector2i = host.view_pixel_from_local_point(event.position)
	if pixel.x < 0: return Vector2i(-1,-1)
	return pixel+Vector2i(host.camera_origin.floor())

func world_input(event: InputEvent) -> bool:
	if not paint_mode_active() or not event is InputEventMouse: return false
	if event is InputEventMouseButton and event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if event.pressed: cancel_preview()
		return false
	if event is InputEventMouseMotion and bench._pan: return false
	var position := _pixel(event)
	if position.x >= 0: cursor = position
	if event is InputEventMouseMotion:
		if dragging and position.x >= 0 and (tool_name() in ["Brush","Eraser"] or drag_erase):
			if stroke.is_empty() or stroke.back() != cursor:
				if stroke.size() >= 4096:
					cancel_preview()
					_say("Stroke sample budget reached; draw a shorter gesture.")
				else: stroke.append(cursor)
		return true
	if not event is InputEventMouseButton: return false
	if event.pressed:
		if position.x < 0 or not _ready_to_author(): return true
		anchor = cursor
		drag_erase = event.button_index == MOUSE_BUTTON_RIGHT or tool_name() == "Eraser"
		if tool_name() == "Fill" and not drag_erase:
			fill_at(cursor)
			return true
		dragging = true
		stroke = [cursor]
		return true
	if not dragging: return true
	if position.x < 0:
		cancel_preview()
		_say("Drawing cancelled outside the canvas.")
		return true
	var job := {"tool":"Brush" if drag_erase else tool_name(),"anchor":anchor,"cursor":cursor,
		"radius":radius(),"material":0 if drag_erase else material_id,"stroke":stroke.duplicate()}
	dragging = false
	stroke.clear()
	if job.tool == "Select":
		selection = Rect2i(anchor.min(cursor),anchor.max(cursor)-anchor.min(cursor)+Vector2i.ONE)
		selection_changed.emit(selection)
		_say("Selected %d × %d · Ctrl+C captures native materials." % [selection.size.x,selection.size.y])
	elif job.tool == "Paste": paste_at(cursor)
	else: _begin_plan(job,str(job.tool))
	return true

func key_input(event: InputEvent) -> bool:
	if not paint_mode_active() or not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
		bench._commit_field()
		bench.save_setup()
		return true
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return false
	if event.keycode == KEY_ESCAPE:
		if busy() or dragging or host.paused:
			cancel()
			return true
		return false
	if not host.paused: return false
	if event.ctrl_pressed or event.meta_pressed:
		match event.keycode:
			KEY_C: copy_selection()
			KEY_V: select_tool("Paste")
			KEY_Z:
				if event.shift_pressed: redo()
				else: undo()
			KEY_Y: redo()
			_: return false
		return true
	var key_tools := {KEY_B:"Brush",KEY_E:"Eraser",KEY_L:"Line",KEY_R:"Rectangle",
		KEY_O:"Outline",KEY_S:"Select",KEY_G:"Fill",KEY_V:"Paste"}
	if key_tools.has(event.keycode):
		select_tool(key_tools[event.keycode])
		return true
	if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		bench._brush.value = clampi(radius()+(-1 if event.keycode == KEY_BRACKETLEFT else 1),0,24)
		return true
	return false

func _request(kind: String, state: Dictionary) -> Dictionary:
	var guards: Array = []
	if bench.applied.get("source",[]).size() == 3:
		guards.append(Rect2i(int(bench.applied.source[0]),int(bench.applied.source[1]),4,24))
	return {"kind":kind,"expected_generation":int(state.generation),
		"expected_revision":int(state.revision),"expected_tick":int(state.tick),
		"expected_authoring_generation":int(state.get("authoring_generation",1)),"protected":guards}

func _queue_capture(kind: String, region: Rect2i, seed: Vector2i = Vector2i.ZERO,
		expected_source: Dictionary = {}) -> bool:
	if not _ready_to_author(): return false
	if not region.has_area() or region.size.x*region.size.y > MAX_CELLS \
			or not Rect2i(Vector2i.ZERO,extent()).encloses(region):
		_say("Select a complete region of at most 262144 cells inside the canvas.")
		return false
	var state := _current()
	if not expected_source.is_empty() and _source(state) != expected_source:
		_say("Native source changed during fill expansion; no paint applied.")
		return false
	var request := _request("capture",state)
	request.region = region
	var admitted: Dictionary = host.simulation_worker.paint_queue(request)
	if admitted.get("status","") != "queued":
		_say(str(admitted.get("reason","Native capture refused.")))
		return false
	_operation = {"kind":kind,"operation_id":admitted.operation_id,"seed":seed,
		"material":material_id,"generation":state.generation}
	_say("Capturing native materials…")
	return true

func copy_selection() -> bool:
	return _queue_capture("copy",selection)

func fill_at(point: Vector2i) -> bool:
	var region := selection
	if not region.has_area() or not region.has_point(point):
		var size := Vector2i(256,256).min(extent())
		region = Rect2i((point-size/2).clamp(Vector2i.ZERO,extent()-size),size)
	return _queue_capture("fill",region,point)

func paste_at(point: Vector2i) -> bool:
	if clipboard.is_empty():
		_say("Select a region and Copy first.")
		return false
	if int(clipboard.generation) != int(_current().get("generation",-1)):
		clipboard.clear()
		_say("The source World changed. Copy a new selection.")
		return false
	return _begin_plan({"tool":"Paste","cursor":point,"clipboard":clipboard.duplicate(true)},"Paste")

func commit_cells(cells: PackedInt32Array, label: String = "Paint") -> bool:
	return _begin_plan({"tool":"Cells","cells":cells.duplicate()},label)

func begin_deferred_brush(point: Vector2i, material: int, brush_radius: int, token: int) -> bool:
	if material not in host.simulation_worker.paint_materials() or brush_radius < 0 or brush_radius > 24:
		_say("Deferred human brush has an unsupported material or radius.")
		return false
	return _begin_plan({"tool":"Brush","anchor":point,"cursor":point,"stroke":[point],
		"radius":brush_radius,"material":material,"deferred_art_token":token},"Human brush")

func _finish_deferred(job: Dictionary, receipt: Dictionary) -> void:
	if job.has("deferred_art_token"):
		deferred_brush_finished.emit(int(job.deferred_art_token),receipt.duplicate(true))

func _begin_plan(job: Dictionary, label: String) -> bool:
	if not _ready_to_author(): return false
	finish_agent_history()
	job.setup = bench.applied.duplicate(true)
	job.generated = bench._generated_active.duplicate(true)
	job.material_baseline = bench._material_baseline.duplicate(false)
	job.extent = extent()
	job.fence = _source(_current())
	job.label = label
	return _start_planner(job)

func _start_planner(job: Dictionary) -> bool:
	_planning_job = job
	_planning_cancelled = false
	_planner = Thread.new()
	var error: Error = _planner.start(_plan.bind(job))
	if error != OK:
		_planner = null
		_planning_job = {}
		_history_replay.clear()
		_say("Could not start bounded paint planning.")
		_notify_history(job,{"status":"refused","reason":_message},false)
		return false
	_say("Planning "+str(job.label)+"…")
	return true

# Copied values only: this thread never reads a World or scene object.
func _plan(job: Dictionary) -> Dictionary:
	var cells := PackedInt32Array()
	var shape: Dictionary = {}
	var dimensions: Vector2i = job.extent
	match str(job.tool):
		"Cells": cells = job.cells
		"Line": shape = Shapes.line(job.anchor,job.cursor,int(job.radius),dimensions,MAX_CELLS)
		"Rectangle","Outline":
			shape = Shapes.rectangle(job.anchor,job.cursor,job.tool == "Rectangle",dimensions,MAX_CELLS)
		"Brush","Eraser":
			var samples: Array = job.stroke.duplicate()
			if samples.is_empty(): samples.append(job.anchor)
			if samples.back() != job.cursor: samples.append(job.cursor)
			var keys := {}
			var work_bound := 0
			for index: int in maxi(1,samples.size()-1):
				var from: Vector2i = samples[mini(index,samples.size()-1)]
				var to: Vector2i = samples[mini(index+1,samples.size()-1)]
				work_bound += (maxi(absi(to.x-from.x),absi(to.y-from.y))+1)*(2*int(job.radius)+1)*(2*int(job.radius)+1)
				if work_bound > 16000000: return {"accepted":false,"error":"Stroke planning budget reached; draw a shorter gesture."}
				var segment: Dictionary = Shapes.line(from,to,int(job.radius),dimensions,MAX_CELLS)
				if not segment.accepted: return segment
				var pairs: PackedInt32Array = segment.cells
				for i: int in range(0,pairs.size(),2):
					keys[pairs[i+1]*dimensions.x+pairs[i]] = true
					if keys.size() > MAX_CELLS: return {"accepted":false,"error":"Stroke exceeds 262144 cells."}
			var ordered: Array = keys.keys()
			ordered.sort()
			cells.resize(ordered.size()*3)
			for i: int in ordered.size():
				cells[i*3] = int(ordered[i])%dimensions.x
				cells[i*3+1] = int(ordered[i])/dimensions.x
				cells[i*3+2] = int(job.material)
		"Paste":
			var clip: Dictionary = job.clipboard
			var clip_size: Vector2i = clip.size
			var source := PackedInt32Array()
			source.resize(clip.materials.size()*2)
			for i: int in clip.materials.size():
				source[i*2] = i%clip_size.x
				source[i*2+1] = i/clip_size.x
			shape = Shapes.stamp_materials(source,clip.materials,Vector2i.ZERO,job.cursor,dimensions,MAX_CELLS)
			if not shape.accepted: return shape
			cells.resize(clip.materials.size()*3)
			for i: int in clip.materials.size():
				cells[i*3] = shape.cells[i*2]
				cells[i*3+1] = shape.cells[i*2+1]
				cells[i*3+2] = clip.materials[i]
		"Fill":
			shape = Shapes.fill_connected(job.seed,job.region.position,job.region.size,
				job.materials,dimensions,MAX_CELLS)
		_: return {"accepted":false,"error":"Unknown paint tool."}
	if cells.is_empty():
		if not shape.get("accepted",false): return shape
		cells.resize(int(shape.count)*3)
		for i: int in int(shape.count):
			cells[i*3] = shape.cells[i*2]
			cells[i*3+1] = shape.cells[i*2+1]
			cells[i*3+2] = int(job.material)
	var candidate: Dictionary
	if job.has("override_edits"):
		candidate = job.setup.duplicate(true)
		candidate.edits = job.override_edits.duplicate(true)
		var error: String = Setup.validate(candidate)
		if not error.is_empty(): return {"accepted":false,"error":error}
		var body: String = JSON.stringify(candidate)
		if not job.get("material_baseline",{}).is_empty():
			error = MaterialBaseline.validate_document(candidate,job.material_baseline)
			if not error.is_empty(): return {"accepted":false,"error":error}
		elif not job.generated.is_empty():
			body = JSON.stringify({"format":Store.FORMAT,"version":1,
				"generation":Store.provenance(job.generated),"starting_setup":candidate})
		elif Setup.rectangles(candidate).has("error"):
			return {"accepted":false,"error":"Restored authoring state exceeds its rectangle budget."}
		if body.to_utf8_buffer().size() > Setup.BYTE_LIMIT:
			return {"accepted":false,"error":"Restored authoring state exceeds the file budget."}
	else:
		var prepared: Dictionary = History.prepare(job.setup,cells,job.generated,job.get("material_baseline",{}))
		if not prepared.accepted: return prepared
		candidate = prepared.setup
	return {"accepted":true,"error":"","cells":cells,"setup":candidate}

func _consume_plan() -> void:
	if _planner == null or _planner.is_alive(): return
	var planned: Variant = _planner.wait_to_finish()
	_planner = null
	var job := _planning_job
	_planning_job = {}
	if _planning_cancelled:
		_history_replay.clear()
		_say("Planning cancelled; no cells queued.")
		_finish_deferred(job,{"status":"cancelled","applied":0,"reason":_message})
		_notify_history(job,{"status":"cancelled","reason":_message},false)
		return
	if planned is Dictionary and str(job.get("tool","")) == "Fill" \
			and str(planned.get("unread_edge","")) != "":
		# No edit has been queued; grow one bounded native capture toward the
		# actual unread component boundary and retry against the same source.
		if _source(_current()) != job.fence or not host.paused:
			_say("Native source changed during fill expansion; no paint applied.")
			return
		var expanded: Rect2i = Shapes.grow_fill_capture(job.region,
			str(planned.unread_edge),job.extent,MAX_CELLS,planned.get("component_bounds",Rect2i()))
		if not expanded.has_area():
			_say("Fill requires more than 262144 sampled cells. Use a smaller enclosed region.")
			return
		if _queue_capture("fill",expanded,job.seed,job.fence):
			_say("Expanding fill capture to %d × %d cells…" % [expanded.size.x,expanded.size.y])
		return
	if not planned is Dictionary or not planned.get("accepted",false):
		_history_replay.clear()
		_say(str(planned.get("error","Paint planning failed.")) if planned is Dictionary else "Paint planning failed.")
		_finish_deferred(job,{"status":"refused","applied":0,"reason":_message})
		_notify_history(job,{"status":"refused","reason":_message},false)
		return
	if _source(_current()) != job.fence or not host.paused or not host.pending_microscenario_apply.is_empty():
		_history_replay.clear()
		_say("Native source changed during planning; draw again.")
		_finish_deferred(job,{"status":"invalidated","applied":0,"reason":_message})
		_notify_history(job,{"status":"invalidated","reason":_message},false)
		return
	var request := _request("edit",job.fence)
	request.cells = planned.cells
	if job.has("expected_before"): request.expected_before = job.expected_before
	var admitted: Dictionary = host.simulation_worker.paint_queue(request)
	if admitted.get("status","") != "queued":
		_history_replay.clear()
		_say(str(admitted.get("reason","Native paint refused.")))
		_finish_deferred(job,{"status":"refused","applied":0,"reason":_message})
		_notify_history(job,{"status":"refused","reason":_message},false)
		return
	_operation = {"kind":"edit","operation_id":admitted.operation_id,"job":job,"planned":planned}
	_say(str(job.label)+" queued · awaiting native confirmation…")

func _process(_delta: float) -> void:
	if host == null: return
	_consume_plan()
	var state := _current()
	var receipt_id: int = int(state.get("result_operation_id",0))
	var owned_id: int = int(_operation.get("operation_id",-1))
	if bool(state.get("receipt_ready",false)) and (receipt_id == owned_id or (receipt_id > 0 and receipt_id == _retired_operation)):
		var receipt: Dictionary = host.simulation_worker.paint_take_result()
		if not receipt.is_empty(): _receive(receipt)
		if receipt_id == _retired_operation: _retired_operation = 0
		state = _current()
	# The agent's acknowledged before/after fence is recorded when its owner
	# consumes the receipt. Do not clear history in the publication/consume gap.
	if not busy() and not bool(state.get("art_busy",false)) \
			and not _history_fence.is_empty() and _source(state) != _history_fence:
		invalidate_history("Simulation or another edit changed the source")
	if not clipboard.is_empty() and int(clipboard.generation) != int(state.get("generation",-1)):
		clipboard.clear()
	_copy.disabled = busy() or not selection.has_area()
	_paste.disabled = busy() or clipboard.is_empty()
	_undo_button.disabled = not history_available("undo")
	_redo_button.disabled = not history_available("redo")
	_undo_button.tooltip_text = "Ctrl+Z · "+(str(_undo_stack.back().label) if not _undo_stack.is_empty() else "No recorded edit") \
		+" · Stop the agent first. "+history_notice
	_cancel_button.disabled = not busy() and not dragging
	if not _operation.is_empty():
		_status.text = "%s · %s · %d / %d cells" % [_operation.get("kind","Paint"),state.get("status","queued"),
			int(state.get("applied",state.get("checked",0))),int(state.get("requested_cells",0))]

func _receive(receipt: Dictionary) -> void:
	last_result = receipt.duplicate(true)
	last_receipt = last_result
	if int(receipt.get("operation_id",-1)) == _retired_operation:
		var retired := receipt.duplicate(true)
		retired.status = "invalidated"
		retired.reason = "History result belongs to the previous World; current start is unchanged."
		retired.recorded = false
		_notify_history(_retired_history_job,retired,false)
		_retired_history_job = {}
		return
	if _operation.is_empty() or int(receipt.get("operation_id",-1)) != int(_operation.operation_id): return
	var operation := _operation
	_operation = {}
	var current := _current()
	if int(receipt.generation) != int(current.get("generation",-1)) \
			or int(receipt.get("observed_generation",-1)) != int(receipt.generation):
		invalidate_history("Old World result retired")
		_say("Paint result belongs to the previous World; current start is unchanged.")
		var retired := receipt.duplicate(true)
		retired.status = "invalidated"
		retired.reason = _message
		retired.recorded = false
		_finish_deferred(operation.get("job",{}),retired)
		_notify_history(operation.get("job",{}),retired,false)
		return
	if str(operation.kind) != "edit":
		if bool(operation.get("cancel_requested",false)):
			_say("Capture cancelled; no follow-up paint was queued.")
			return
		if str(receipt.status) != "completed":
			_say(str(receipt.get("reason","Native capture cancelled.")))
			return
		if operation.kind == "copy":
			clipboard = {"size":receipt.region.size,"materials":receipt.materials.duplicate(),
				"generation":receipt.generation,"origin":receipt.region.position}
			_say("Copied %d native cells including Empty · Ctrl+V to paste." % receipt.materials.size())
		else:
			var job := {"tool":"Fill","region":receipt.region,"materials":receipt.materials,
				"seed":operation.seed,"material":operation.material,"setup":bench.applied.duplicate(true),
				"generated":bench._generated_active.duplicate(true),"extent":extent(),
				"material_baseline":bench._material_baseline.duplicate(false),
				"fence":_source(receipt),"label":"Fill"}
			_start_planner(job)
		return
	_receive_edit(operation,receipt,current)
	var completed := receipt.duplicate(true)
	completed.recorded = not _save_hold
	if _save_hold: completed.reason = _message
	_finish_deferred(operation.job,completed)

func _receive_edit(operation: Dictionary, receipt: Dictionary, current: Dictionary) -> void:
	var job: Dictionary = operation.job
	var applied_count := int(receipt.get("applied",0))
	if applied_count == 0:
		_history_replay.clear()
		_say(str(receipt.get("reason","No cells applied.")))
		_notify_history(job,receipt,false)
		return
	if bench.applied.edits != job.setup.edits:
		_save_hold = true
		invalidate_history("Authoring record changed during native editing")
		_say("Native edit completed against a changed authoring record. Restore start before saving.")
		var unrecorded := receipt.duplicate(true)
		unrecorded.status = "invalidated"
		unrecorded.reason = _message
		unrecorded.recorded = false
		_notify_history(job,unrecorded,false)
		return
	var complete: bool = str(receipt.status) == "completed" and applied_count*3 == operation.planned.cells.size()
	var action: String = str(job.get("history_action",""))
	if not complete and action == "undo" and bool(job.get("history_record",{}).get("recover_only",false)):
		# A restored prefix does not describe the remaining unsaved suffix.
		_save_hold = true
		invalidate_history("Partial recovery was stopped")
		_say("Recovery stopped part way. Restore start before saving or continuing.")
		completed_actions += 1
		_notify_history(job,receipt,false)
		return
	var prepared: Dictionary = {"accepted":true,"setup":operation.planned.setup} if complete \
		else History.prepare(job.setup,receipt.cells,job.generated,job.get("material_baseline",{}))
	var before_edits: Array = job.setup.edits.duplicate(true)
	if prepared.accepted:
		bench.applied.edits = prepared.setup.edits.duplicate(true)
		_save_hold = false
	else:
		_save_hold = true
	if complete and not action.is_empty() and prepared.accepted:
		var record: Dictionary = job.history_record
		if action == "undo":
			if not _undo_stack.is_empty(): _undo_stack.pop_back()
			if not record.get("recover_only",false): _redo_stack.append(record)
		else:
			if not _redo_stack.is_empty(): _redo_stack.pop_back()
			_undo_stack.append(record)
		_history_fence = _source(receipt)
	else:
		_history_replay.clear()
		if not action.is_empty(): invalidate_history("History operation stopped part way")
		_redo_stack.clear()
		if bool(receipt.get("recovery_possible",false)) and _source(receipt) == _source(current):
			var record := {"label":str(job.label),"cells":receipt.cells.duplicate(),
				"before":receipt.before.duplicate(),"after":receipt.after.duplicate(),
				"before_edits":before_edits,"after_edits":bench.applied.edits.duplicate(true),
				"recover_only":not prepared.accepted}
			_undo_stack.append(record)
			_trim_history()
			_history_fence = _source(receipt)
		else:
			invalidate_history("Source changed after partial editing")
	completed_actions += 1
	if _save_hold:
		_say("%d native cells applied; prefix exceeds save capacity. Undo or Restore start." % applied_count)
	elif complete:
		_say("%s completed · %d cells confirmed and recorded." % [job.label,applied_count])
	else:
		_say("%s stopped · %d / %d cells confirmed and recorded. Undo reverses this prefix." % [
			job.label,applied_count,int(receipt.requested_cells)])
	if not action.is_empty():
		var stack: Array = _undo_stack if action == "undo" else _redo_stack
		var group := int(job.history_record.get("agent_group",0))
		var more: bool = complete and not _save_hold and not _history_replay.is_empty() \
			and group > 0 and not stack.is_empty() and int(stack.back().get("agent_group",0)) == group
		_notify_history(job,receipt,more)
		if more:
			# Receipt listeners may Stop or replace the World at this boundary.
			# Never recreate the replay token that their cancellation just retired.
			if str(_history_replay.get("action","")) != action or int(_history_replay.get("group",0)) != group:
				var replaced := int(_current().get("generation",-1)) != int(job.fence.generation)
				_notify_history(job,{"status":"invalidated" if replaced else "cancelled",
					"reason":"World replaced at the confirmed part boundary." if replaced else "History stopped at the confirmed part boundary.",
					"recorded":not replaced and not _save_hold},false)
			elif not _start_reverse(action,true):
				_history_replay.clear()
		else:
			_history_replay.clear()

func _notify_history(job: Dictionary, receipt: Dictionary, more: bool) -> void:
	if str(job.get("history_action","")) == "": return
	history_action_finished.emit({"action":str(job.history_action),"status":str(receipt.get("status","refused")),
		"label":str(job.get("label","History")),"origin":str(job.get("history_record",{}).get("origin","manual")),
		"applied":int(receipt.get("applied",0)),"changed":int(receipt.get("changed",0)),
		"reason":str(receipt.get("reason","")),"remaining_group":more,
		"recorded":bool(receipt.get("recorded",not _save_hold))})

func _trim_history() -> void:
	var total := 0
	for record: Dictionary in _undo_stack: total += record.before.size()
	while _undo_stack.size() > MAX_HISTORY or total > HISTORY_CELLS:
		var oldest: Dictionary = _undo_stack.pop_front()
		total -= oldest.before.size()
		var group := int(oldest.get("agent_group",0))
		if group > 0:
			for record: Dictionary in _undo_stack:
				if int(record.get("agent_group",0)) != group: continue
				record.partial_history = true
				record.label = "Agent drawing (retained tail)"
				history_notice = "History is limited to 32 parts / 1048576 cells; the oldest part of this agent drawing is no longer undoable."
				_say(history_notice)

func undo() -> bool:
	return _reverse("undo")

func redo() -> bool:
	return _reverse("redo")

func _reverse(action: String) -> bool:
	if bench != null and bench.has_method("art_history_guard"):
		var reason: String = bench.art_history_guard()
		if not reason.is_empty():
			_say(reason)
			return false
	finish_agent_history()
	return _start_reverse(action)

func _start_reverse(action: String, continuing_history: bool = false) -> bool:
	var stack: Array = _undo_stack if action == "undo" else _redo_stack
	var record: Dictionary = stack.back() if not stack.is_empty() else {}
	var notification := {"history_action":action,"history_record":record,
		"label":action.capitalize()+" "+str(record.get("label","history"))}
	if not _ready_to_author(action == "undo",continuing_history):
		if continuing_history: _notify_history(notification,{"status":"refused","reason":_message},false)
		return false
	if _history_fence.is_empty() or _source(_current()) != _history_fence:
		invalidate_history("Native source changed")
		if continuing_history: _notify_history(notification,{"status":"invalidated","reason":_message},false)
		return false
	if stack.is_empty():
		if continuing_history: _notify_history(notification,{"status":"invalidated","reason":"No further recorded history part."},false)
		return false
	var group := int(record.get("agent_group",0))
	_history_replay = {"action":action,"group":group} if group > 0 else {}
	var target: PackedInt32Array = record.before if action == "undo" else record.after
	var expected: PackedInt32Array = record.after if action == "undo" else record.before
	var cells: PackedInt32Array = record.cells.duplicate()
	for i: int in target.size(): cells[i*3+2] = target[i]
	var job := {"tool":"Cells","cells":cells,"expected_before":expected.duplicate(),
		"override_edits":record.before_edits if action == "undo" else record.after_edits,
		"history_action":action,"history_record":record,"setup":bench.applied.duplicate(true),
		"generated":bench._generated_active.duplicate(true),"extent":extent(),
		"material_baseline":bench._material_baseline.duplicate(false),
		"fence":_source(_current()),"label":action.capitalize()+" "+str(record.label)}
	return _start_planner(job)

func local_to_cell(position: Vector2) -> Vector2i:
	var pixel: Vector2i = host.view_pixel_from_local_point(position)
	return pixel+Vector2i(host.camera_origin.floor()) if pixel.x >= 0 else Vector2i(-1,-1)

func _exit_tree() -> void:
	if host != null and is_instance_valid(host) and not _operation.is_empty(): host.simulation_worker.paint_stop()
	_finish_deferred(_operation.get("job",{}),{"status":"invalidated","reason":"Workbench closed before the human completion receipt was consumed."})
	if _planner != null:
		_planner.wait_to_finish()
		_planner = null
		_finish_deferred(_planning_job,{"status":"cancelled","applied":0,"reason":"Workbench closed during human stroke planning."})
