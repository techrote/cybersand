extends VBoxContainer

## Displays stored state returned by an isolated compiled World. This Control
## owns no World, worker, shader programme or material installation.
signal test_requested(scenario: Dictionary)
signal export_requested(scenario: Dictionary)
signal cancel_requested

const MAX_CELLS: int = 65536
const MAX_JSON_INTEGER: int = 9007199254740991
const SCENARIO_FIELDS: Array[String] = ["first","second","seed","ticks","workers"]
const REQUIRED_CHECKS: Array[String] = ["deterministic_repeat","worker_1_4_equal","persistence_checkpoint","persistence_replay","quantity_balanced"]
var revision: int = 0
var receipt: Dictionary = {}
var last_error: String = ""
var _candidate: Dictionary = {}
var _materials: Dictionary = {}
var _decoded: Dictionary = {}
var _built: bool = false
var _loading: bool = false
var _pending: bool = false
var _summary := Label.new()
var _status := Label.new()
var _partner := OptionButton.new()
var _placement := OptionButton.new()
var _seed := SpinBox.new()
var _ticks := SpinBox.new()
var _workers := OptionButton.new()
var _run_button := Button.new()
var _export_button := Button.new()
var _cancel_button := Button.new()
var _stage := OptionButton.new()
var _reference_preview := TextureRect.new()
var _candidate_preview := TextureRect.new()
var _report := TextEdit.new()
var _cell_x := SpinBox.new()
var _cell_y := SpinBox.new()
var _cell_report := Label.new()

func _ready() -> void:
	_ensure_built()

func _label(parent: Node, text: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",5)
	row.add_theme_constant_override("v_separation",3)
	add_child(row)
	return row

func _spin(parent: Node, caption: String, field: SpinBox, low: int, high: int, initial: int) -> void:
	_label(parent,caption)
	field.min_value = low
	field.max_value = high
	field.step = 1
	field.value = initial
	field.custom_minimum_size.x = 80
	field.get_line_edit().text_changed.connect(func(_text: String) -> void: field.set_meta("lab_pending_text",true))
	field.value_changed.connect(func(_value: float) -> void: field.set_meta("lab_pending_text",false))
	parent.add_child(field)

func _ensure_built() -> void:
	if _built: return
	_built = true
	_loading = true
	add_theme_constant_override("separation",5)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	_label(self,"Compiles two external Worlds: unchanged reference and your candidate. No material is installed in the running application.",true)
	var setup := _row()
	_label(setup,"Candidate")
	_placement.add_item("Upper dose",0)
	_placement.add_item("Lower partner",1)
	setup.add_child(_placement)
	_label(setup,"Other material")
	_partner.custom_minimum_size.x = 150
	setup.add_child(_partner)
	_spin(setup,"Seed",_seed,0,2147483647,2)
	_spin(setup,"Ticks",_ticks,1,600,120)
	_label(setup,"Workers")
	_workers.add_item("1",1)
	_workers.add_item("4",4)
	setup.add_child(_workers)
	for picker: OptionButton in [_placement,_partner,_workers]:
		picker.item_selected.connect(func(_index: int) -> void: _scenario_changed())
	for field: SpinBox in [_seed,_ticks]:
		field.value_changed.connect(func(_value: float) -> void: _scenario_changed())
		field.get_line_edit().text_changed.connect(func(_text: String) -> void: _scenario_changed())
	var actions := _row()
	_run_button.text = "Compile + compare World"
	_run_button.pressed.connect(func() -> void: _request(false))
	actions.add_child(_run_button)
	_export_button.text = "Export World test bundle…"
	_export_button.pressed.connect(func() -> void: _request(true))
	actions.add_child(_export_button)
	_cancel_button.text = "Cancel World test"
	_cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	actions.add_child(_cancel_button)
	_label(actions,"View")
	_stage.add_item("Final",0)
	_stage.add_item("Initial",1)
	_stage.select(0)
	_stage.item_selected.connect(func(_index: int) -> void: _refresh_view())
	actions.add_child(_stage)
	_label(self,"World tests refuse capability and visual-state projection edits. Restore the template values or use the descriptor test. Preview uses native stored material/state and compiled base RGBA; it is not a shader screenshot.",true)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var previews := HBoxContainer.new()
	previews.size_flags_vertical = Control.SIZE_EXPAND_FILL
	previews.add_theme_constant_override("separation",10)
	add_child(previews)
	for side: int in range(2):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		previews.add_child(column)
		_label(column,"Reference · unchanged native source" if side == 0 else "Candidate · isolated compiled source")
		var preview: TextureRect = _reference_preview if side == 0 else _candidate_preview
		preview.custom_minimum_size = Vector2(150,184)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.mouse_filter = Control.MOUSE_FILTER_STOP
		preview.tooltip_text = "Click a cell to compare authoritative stored material, state bytes and temperature."
		preview.gui_input.connect(_preview_input.bind(preview))
		column.add_child(preview)
	var cells := _row()
	_spin(cells,"Stored cell X",_cell_x,176,307,240)
	_spin(cells,"Y",_cell_y,64,247,112)
	for field: SpinBox in [_cell_x,_cell_y]:
		field.value_changed.connect(func(_value: float) -> void:
			if not _loading: inspect_cell(Vector2i(int(_cell_x.value),int(_cell_y.value))))
	_cell_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_cell_report)
	_report.editable = false
	_report.add_theme_color_override("font_readonly_color",Color(0.86,0.89,0.93))
	_report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_report.custom_minimum_size.y = 145
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_report)
	_loading = false
	_status.text = "Duplicate a supported material, then compile a bounded comparison."
	_refresh_controls()

func set_materials(native_materials: Array) -> void:
	_ensure_built()
	var previous: int = _partner.get_selected_id() if _partner.selected >= 0 else 3
	_loading = true
	_materials.clear()
	_partner.clear()
	for value: Variant in native_materials:
		if not value is Dictionary: continue
		var row: Dictionary = value
		if not _whole(row.get("id"),0,131): continue
		var id: int = int(row.id)
		if id == 10 or not row.get("valid",false): continue
		_materials[id] = row.duplicate(true)
		_partner.add_item("%03d  %s" % [id,str(row.get("name",id))],id)
	var index: int = _partner.get_item_index(previous)
	if index < 0: index = _partner.get_item_index(3)
	if index >= 0: _partner.select(index)
	_loading = false
	if _partner.get_selected_id() != previous:
		invalidate("Available native partners changed. Compile again for the selected pair.")
	else:
		_refresh_controls()

func set_candidate(candidate: Dictionary) -> void:
	_ensure_built()
	if candidate == _candidate: return
	_candidate = candidate.duplicate(true)
	invalidate("Candidate changed. Compile again to qualify these edits.")

func scenario() -> Dictionary:
	_ensure_built()
	var id: int = int(_candidate.get("target_id",-1))
	var partner: int = _partner.get_selected_id() if _partner.selected >= 0 else -1
	var lower: bool = _placement.get_selected_id() == 1
	return {"first":partner if lower else id,"second":id if lower else partner,
		"seed":int(_seed.value),"ticks":int(_ticks.value),"workers":_workers.get_selected_id()}

func _scenario_error(value: Dictionary) -> String:
	if value.size() != SCENARIO_FIELDS.size(): return "Test recipe must contain exactly first, second, seed, ticks and workers."
	for key: String in SCENARIO_FIELDS:
		if not value.has(key): return "Test recipe is missing %s." % key
	for key: String in ["first","second"]:
		if not _whole(value[key],0,131) or int(value[key]) == 10: return "Test recipe %s must be a valid native material ID; reserved ID 10 cannot be placed." % key
	if not _whole(value.seed,0,2147483647): return "Test recipe seed must be an integer in 0..2147483647."
	if not _whole(value.ticks,1,600): return "Test recipe ticks must be an integer in 1..600."
	if not _whole(value.workers,1,4) or int(value.workers) not in [1,4]: return "Test recipe workers must be 1 or 4."
	var id: int = int(_candidate.get("target_id",-1))
	if id < 1 or id > 131 or id == 10: return "Load a supported existing material candidate before its World recipe."
	if int(value.first) != id and int(value.second) != id: return "Test recipe must place this candidate as the upper dose or lower partner."
	var partner: int = int(value.second) if int(value.first) == id else int(value.first)
	if _partner.get_item_index(partner) < 0: return "Test recipe partner is unavailable in the native catalogue."
	return ""

func set_scenario(value: Dictionary) -> bool:
	_ensure_built()
	last_error = "Cancel the pending World test before loading a recipe." if _pending else _scenario_error(value)
	if not last_error.is_empty(): return false
	var id: int = int(_candidate.target_id)
	var upper: bool = int(value.first) == id
	var partner: int = int(value.second) if upper else int(value.first)
	_loading = true
	_placement.select(0 if upper else 1)
	_partner.select(_partner.get_item_index(partner))
	_seed.value = int(value.seed)
	_ticks.value = int(value.ticks)
	_workers.select(_workers.get_item_index(int(value.workers)))
	_loading = false
	invalidate("Test recipe loaded. Compile again to qualify this candidate and configuration.")
	return true

func _scenario_changed() -> void:
	if not _loading: invalidate("Scenario changed. Compile again for this placement, seed, tick count and worker selection.")

func invalidate(reason: String) -> void:
	_ensure_built()
	revision += 1
	last_error = ""
	receipt.clear()
	_decoded.clear()
	_reference_preview.texture = null
	_candidate_preview.texture = null
	_report.text = ""
	_cell_report.text = "Stored cell comparison is available after a successful native test."
	_status.text = reason
	_refresh_controls()

func _blocked_reason() -> String:
	if _candidate.is_empty(): return "Duplicate an existing material in the Candidate tab first."
	var id: int = int(_candidate.get("target_id",-1))
	if id == 132: return "Synthetic 132 is a descriptor-only fixture. This World backend retains the 132 production slots; use Compile + native test in the Candidate tab."
	if id < 1 or id > 131 or id == 10: return "Choose a valid existing candidate identity; Empty and reserved ID 10 cannot be candidate templates."
	if _partner.selected < 0: return "Native material choices are unavailable. Reload the native catalogue."
	return ""

func _refresh_controls() -> void:
	var blocked: String = _blocked_reason()
	_summary.text = blocked if not blocked.is_empty() else "Candidate %03d · %s" % [int(_candidate.target_id),str(_candidate.get("name","Candidate"))]
	_run_button.disabled = _pending or not blocked.is_empty()
	_export_button.disabled = _run_button.disabled
	_run_button.tooltip_text = blocked
	_export_button.tooltip_text = blocked
	_cancel_button.disabled = not _pending
	_stage.disabled = receipt.is_empty()
	for picker: OptionButton in [_partner,_placement,_workers]: picker.disabled = _pending
	for field: SpinBox in [_seed,_ticks]: field.editable = not _pending
	for field: SpinBox in [_cell_x,_cell_y]: field.editable = not receipt.is_empty()

func _request(export_bundle: bool) -> void:
	if _pending or not _blocked_reason().is_empty(): return
	commit_fields()
	if export_bundle: export_requested.emit(scenario())
	else: test_requested.emit(scenario())

func commit_fields() -> void:
	for field: SpinBox in [_seed,_ticks]:
		if field.get_line_edit().has_focus() or field.get_meta("lab_pending_text",false):
			field.apply()
			field.set_meta("lab_pending_text",false)
			field.get_line_edit().release_focus()

func show_pending() -> void:
	_ensure_built()
	receipt.clear()
	_decoded.clear()
	_reference_preview.texture = null
	_candidate_preview.texture = null
	_report.text = "Building reference and candidate, then running bounded native repeats, 1/4-worker comparisons, quantity checks and same-build persistence."
	_cell_report.text = "Waiting for native stored-cell readback."
	_pending = true
	_status.text = "Compiling and testing both Worlds… Cancel remains available."
	_refresh_controls()

func show_failure(message: String) -> void:
	_ensure_built()
	_pending = false
	invalidate(message)
	last_error = message
	_report.text = message

static func _whole(value: Variant, low: int, high: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT: return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high and float(value) == floor(float(value))

func _decode(grid: Variant, palette: Variant) -> Dictionary:
	if not grid is Dictionary or grid.get("encoding","") != "row-major-rle-v1": return {"error":"Unsupported stored-grid encoding."}
	var rect: Variant = grid.get("rect")
	if not rect is Array or rect.size() != 4: return {"error":"Stored-grid rectangle is malformed."}
	if not _whole(rect[0],0,2147483647) or not _whole(rect[1],0,2147483647): return {"error":"Stored-grid origin is invalid."}
	if not _whole(rect[2],1,MAX_CELLS) or not _whole(rect[3],1,MAX_CELLS): return {"error":"Stored-grid dimensions exceed the preview bound."}
	var width: int = int(rect[2])
	var height: int = int(rect[3])
	var count: int = width * height
	if count > MAX_CELLS: return {"error":"Stored-grid preview exceeds 65536 cells."}
	if int(rect[0]) + width > 2147483647 or int(rect[1]) + height > 2147483647: return {"error":"Stored-grid rectangle exceeds native coordinate bounds."}
	if not palette is Array or palette.size() != 132: return {"error":"Compiled palette must contain exactly 132 allocated slots."}
	for colour: Variant in palette:
		if not colour is Array or colour.size() != 4: return {"error":"Compiled RGBA row is malformed."}
		for channel: Variant in colour:
			if not _whole(channel,0,255): return {"error":"Compiled RGBA channel is invalid."}
	var runs: Variant = grid.get("runs")
	if not runs is Array or runs.is_empty() or runs.size() > count: return {"error":"Stored-grid run count is invalid."}
	var cells := PackedInt32Array()
	cells.resize(count * 4)
	var pixels := PackedByteArray()
	pixels.resize(count * 4)
	var offset: int = 0
	for run: Variant in runs:
		if not run is Array or run.size() != 5: return {"error":"Stored-grid run must contain length, material, state A, state B and temperature."}
		if not _whole(run[0],1,count) or offset + int(run[0]) > count: return {"error":"Stored-grid run lengths exceed the declared rectangle."}
		if not _whole(run[1],0,131) or int(run[1]) == 10: return {"error":"Stored-grid material is invalid or reserved."}
		if not _whole(run[2],0,255) or not _whole(run[3],0,255) or not _whole(run[4],-32768,32767): return {"error":"Stored-grid state or temperature is outside its native domain."}
		var rgba: Array = palette[int(run[1])]
		for index: int in range(offset,offset + int(run[0])):
			for channel: int in range(4):
				cells[index * 4 + channel] = int(run[channel + 1])
				pixels[index * 4 + channel] = int(rgba[channel])
		offset += int(run[0])
	if offset != count: return {"error":"Stored-grid runs do not fill the declared rectangle."}
	var image := Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,pixels)
	return {"rect":Rect2i(int(rect[0]),int(rect[1]),width,height),"cells":cells,"texture":ImageTexture.create_from_image(image)}

static func _true(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value

static func _false(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and not value

static func _hex(value: Variant, length: int) -> bool:
	return typeof(value) == TYPE_STRING and value.length() == length and value.is_valid_hex_number(false)

func _receipt_error(world_receipt: Dictionary, expected_digest: String) -> String:
	if world_receipt.get("schema_id","") != "cybersand.material-lab.world-receipt" or not _whole(world_receipt.get("schema_version"),1,1) or not _false(world_receipt.get("runtime_active")):
		return "The World receipt is unsupported or incorrectly claims runtime activation."
	if not _hex(world_receipt.get("candidate_digest"),64): return "The World receipt has no valid candidate digest."
	if not expected_digest.is_empty() and world_receipt.candidate_digest != expected_digest: return "The World receipt belongs to a different candidate digest."
	var config: Variant = world_receipt.get("scenario")
	if not config is Dictionary: return "The World receipt is missing its test recipe."
	var problem: String = _scenario_error(config)
	if not problem.is_empty(): return problem
	var current: Dictionary = scenario()
	for key: String in SCENARIO_FIELDS:
		if int(config[key]) != int(current[key]): return "The World receipt does not match the current %s setting." % key
	var source: Variant = world_receipt.get("source_identity")
	if not source is Dictionary or not _hex(source.get("digest"),64): return "The World receipt has no valid source identity."
	if world_receipt.get("source_identity_after") != source.digest: return "The World source identity changed during the test."
	var checks: Variant = world_receipt.get("checks")
	if not checks is Dictionary: return "The World receipt has no qualification checks."
	for key: String in ["source_unchanged","reference_qualification","candidate_qualification"]:
		if not _true(checks.get(key)): return "World qualification did not pass: %s." % key
	if typeof(checks.get("unchanged_candidate")) != TYPE_BOOL: return "The World receipt lacks its unchanged-candidate qualification."
	if checks.unchanged_candidate and not _true(checks.get("unchanged_candidate_parity")): return "Unchanged candidate did not match the native reference."
	for side: String in ["reference","candidate"]:
		var native: Variant = world_receipt.get(side)
		if not native is Dictionary or not _true(native.get("ok")) or not _true(native.get("world_simulation")) or not _false(native.get("runtime_active")):
			return "The %s native World did not acknowledge a successful isolated simulation." % side
		var native_checks: Variant = native.get("checks")
		if not native_checks is Dictionary: return "The %s native qualification checks are missing." % side
		for key: String in REQUIRED_CHECKS:
			if not _true(native_checks.get(key)): return "%s native qualification did not pass: %s." % [side.capitalize(),key]
		if not _whole(native.get("requested_workers"),1,4) or int(native.requested_workers) != int(config.workers): return "The %s native worker request differs from the recipe." % side
		var descriptor: Variant = native.get("descriptor_readback")
		if not descriptor is Dictionary or not _whole(descriptor.get("id"),1,131) or int(descriptor.id) != int(_candidate.target_id): return "The %s descriptor readback belongs to another material." % side
		for key: String in ["density","viscosity_index"]:
			if not _whole(descriptor.get(key),0,65535 if key == "density" else 255): return "The %s descriptor %s is malformed." % [side,key]
		if side == "candidate":
			var authored: Variant = _candidate.get("descriptor")
			if not authored is Dictionary: return "The current candidate has no authored native descriptor."
			for key: String in ["density","viscosity_index","kernel"]:
				if not _whole(descriptor.get(key),0,65535) or not _whole(authored.get(key),0,65535) or int(descriptor[key]) != int(authored[key]):
					return "Compiled native %s does not match the authored candidate." % key
			var colour: Variant = descriptor.get("rgba")
			var expected_colour: Variant = authored.get("rgba")
			if not colour is Array or colour.size() != 4 or not expected_colour is Array or expected_colour.size() != 4:
				return "Compiled native RGBA is missing from the candidate descriptor."
			for channel: int in range(4):
				if not _whole(colour[channel],0,255) or not _whole(expected_colour[channel],0,255) or int(colour[channel]) != int(expected_colour[channel]):
					return "Compiled native RGBA does not match the authored candidate."
		for stage: String in ["initial","final"]:
			var snapshot: Variant = native.get(stage)
			if not snapshot is Dictionary: return "The %s %s native snapshot is missing." % [side,stage]
			var expected_tick: int = 0 if stage == "initial" else int(config.ticks)
			if not _whole(snapshot.get("completed_ticks"),expected_tick,expected_tick): return "The %s %s snapshot does not cover the requested ticks." % [side,stage]
			for key: String in ["water_quantity","active_chunks"]:
				if not _whole(snapshot.get(key),0,MAX_JSON_INTEGER): return "The %s %s native %s is malformed." % [side,stage,key]
			for key: String in ["content_hash","state_hash","physical_state_hash"]:
				if not _hex(snapshot.get(key),16): return "The %s %s native %s is malformed." % [side,stage,key]
			var ledger: Variant = snapshot.get("quantity_ledger")
			if not ledger is Dictionary or not _true(ledger.get("balanced")): return "The %s %s native quantity ledger is missing or unbalanced." % [side,stage]
			var counts: Variant = snapshot.get("material_cells")
			# Native histogram covers the complete byte domain, including unused IDs.
			if not counts is Array or counts.size() != 256: return "The %s %s material counts are malformed." % [side,stage]
			for id: int in range(counts.size()):
				if not _whole(counts[id],0,MAX_JSON_INTEGER): return "The %s %s material count is invalid." % [side,stage]
				if (id == 10 or id >= 132) and int(counts[id]) != 0: return "The %s %s World contains a reserved or unallocated material." % [side,stage]
	return ""

func show_receipt(world_receipt: Dictionary, expected_digest: String = "") -> bool:
	_ensure_built()
	_pending = false
	var problem: String = _receipt_error(world_receipt,expected_digest)
	if not problem.is_empty():
		show_failure(problem)
		return false
	var staged: Dictionary = {}
	for side: String in ["reference","candidate"]:
		var native: Dictionary = world_receipt[side]
		staged[side] = {}
		for stage: String in ["initial","final"]:
			var snapshot: Dictionary = native[stage]
			var decoded: Dictionary = _decode(snapshot.get("grid"),native.get("palette_rgba"))
			if decoded.has("error"):
				show_failure("%s %s: %s" % [side,stage,decoded.error])
				return false
			staged[side][stage] = decoded
	var expected_rect: Rect2i = staged.reference.initial.rect
	for side: String in ["reference","candidate"]:
		for stage: String in ["initial","final"]:
			if staged[side][stage].rect != expected_rect:
				show_failure("Native snapshots cover different rectangles; stored-cell comparison refused.")
				return false
	receipt = world_receipt.duplicate(true)
	_decoded = staged
	last_error = ""
	_status.text = "Compiled native World comparison complete. Preview and cell inspection use stored native readback; the running application is unchanged."
	_loading = true
	_cell_x.min_value = expected_rect.position.x
	_cell_x.max_value = expected_rect.end.x - 1
	_cell_y.min_value = expected_rect.position.y
	_cell_y.max_value = expected_rect.end.y - 1
	_loading = false
	_refresh_controls()
	_refresh_view()
	return true

func _stage_name() -> String:
	return "initial" if _stage.get_selected_id() == 1 else "final"

func _refresh_view() -> void:
	if receipt.is_empty(): return
	var stage: String = _stage_name()
	_reference_preview.texture = _decoded.reference[stage].texture
	_candidate_preview.texture = _decoded.candidate[stage].texture
	_report.text = _format_report(stage)
	inspect_cell(Vector2i(int(_cell_x.value),int(_cell_y.value)))

func _material_name(id: int) -> String:
	return "%03d %s" % [id,str(_materials.get(id,{}).get("name","material"))]

func _check_text(checks: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in REQUIRED_CHECKS:
		parts.append("%s %s" % [key.replace("_"," "),"PASS" if checks.get(key,false) == true else "unavailable/failed"])
	return " · ".join(parts)

func _format_report(stage: String) -> String:
	var reference: Dictionary = receipt.reference[stage]
	var authored: Dictionary = receipt.candidate[stage]
	var lines: PackedStringArray = []
	var unchanged: Variant = receipt.get("checks",{}).get("source_unchanged",false)
	var source_digest: String = str(receipt.get("source_identity",{}).get("digest","unavailable")).left(16)
	lines.append("Source custody %s · source %s · runtime-active false" % ["PASS" if unchanged == true else "unavailable",source_digest])
	var reference_descriptor: Dictionary = receipt.reference.get("descriptor_readback",{})
	var candidate_descriptor: Dictionary = receipt.candidate.get("descriptor_readback",{})
	lines.append("Compiled native descriptor · density %s / %s · viscosity %s / %s (reference / candidate)" % [reference_descriptor.get("density","?"),candidate_descriptor.get("density","?"),reference_descriptor.get("viscosity_index","?"),candidate_descriptor.get("viscosity_index","?")])
	lines.append("%s readback · completed ticks %s / %s · active chunks %s / %s (reference / candidate)" % [stage.capitalize(),reference.get("completed_ticks","?"),authored.get("completed_ticks","?"),reference.get("active_chunks","?"),authored.get("active_chunks","?")])
	lines.append("Water quantity %s / %s · quantity ledger balanced %s / %s" % [reference.get("water_quantity","?"),authored.get("water_quantity","?"),reference.get("quantity_ledger",{}).get("balanced","?"),authored.get("quantity_ledger",{}).get("balanced","?")])
	for side: String in ["reference","candidate"]:
		lines.append("%s checks: %s" % [side.capitalize(),_check_text(receipt[side].get("checks",{}))])
	for field: String in ["content_hash","state_hash","physical_state_hash"]:
		lines.append("%s: %s / %s" % [field,str(reference.get(field,"unavailable")).left(32),str(authored.get(field,"unavailable")).left(32)])
	var before: Variant = reference.get("material_cells")
	var after: Variant = authored.get("material_cells")
	lines.append("Material cell differences at this stage (whole World, candidate − reference):")
	var changed: int = 0
	if before is Array and after is Array and before.size() >= 132 and after.size() >= 132:
		for id: int in range(132):
			var delta: int = int(after[id]) - int(before[id])
			if delta != 0:
				changed += 1
				lines.append("  %s: %s → %s (%+d)" % [_material_name(id),str(before[id]),str(after[id]),delta])
		if changed == 0: lines.append("  No material count differences. Stored state and hashes may still differ.")
	else: lines.append("  Native material counts unavailable.")
	lines.append("Chunk activity is aggregate evidence. Per-cell sleep/deadline eligibility is not exposed. Persistence is checked within each isolated build; cross-build saved-world compatibility is not claimed.")
	return "\n".join(lines)

func inspect_cell(position: Vector2i) -> Dictionary:
	if receipt.is_empty():
		_cell_report.text = "Compile a native World comparison before inspecting stored cells."
		return {"ok":false,"error":"No compiled World receipt"}
	var stage: String = _stage_name()
	var rect: Rect2i = _decoded.reference[stage].rect
	if not rect.has_point(position):
		_cell_report.text = "Cell (%d, %d) is outside the captured native rectangle." % [position.x,position.y]
		return {"ok":false,"error":"Outside captured rectangle"}
	_loading = true
	_cell_x.value = position.x
	_cell_y.value = position.y
	_loading = false
	var index: int = (position.y - rect.position.y) * rect.size.x + position.x - rect.position.x
	var result: Dictionary = {"ok":true,"position":position,"stage":stage}
	var descriptions: PackedStringArray = []
	for side: String in ["reference","candidate"]:
		var cells: PackedInt32Array = _decoded[side][stage].cells
		var values: Dictionary = {"material":cells[index * 4],"state_a":cells[index * 4 + 1],"state_b":cells[index * 4 + 2],"temperature":cells[index * 4 + 3]}
		result[side] = values
		descriptions.append("%s: %s · A %d · B %d · temperature %d" % [side.capitalize(),_material_name(values.material),values.state_a,values.state_b,values.temperature])
	_cell_report.text = "Stored cell (%d, %d), %s — %s" % [position.x,position.y,stage," | ".join(descriptions)]
	return result

func _preview_input(event: InputEvent, preview: TextureRect) -> void:
	if receipt.is_empty() or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var rect: Rect2i = _decoded.reference[_stage_name()].rect
	var scale_factor: float = minf(preview.size.x / rect.size.x,preview.size.y / rect.size.y)
	if scale_factor <= 0.0: return
	var drawn: Vector2 = Vector2(rect.size) * scale_factor
	var origin: Vector2 = (preview.size - drawn) * 0.5
	var point: Vector2 = event.position - origin
	if point.x < 0 or point.y < 0 or point.x >= drawn.x or point.y >= drawn.y: return
	inspect_cell(rect.position + Vector2i(floori(point.x / scale_factor),floori(point.y / scale_factor)))
	preview.accept_event()
