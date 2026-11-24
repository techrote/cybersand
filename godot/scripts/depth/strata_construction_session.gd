extends RefCounted

## One finite owner-approved job. The host owns every native World and existing
## history path. This session holds copied observations, proposed cells and ACKs.
## Stop is a bounded suffix cancellation, never a cross-plane rollback promise.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Plan = preload("res://scripts/depth/strata_construction_plan.gd")
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
const History = preload("res://scripts/workbench_paint_editor_history.gd")
const Codec = preload("res://scripts/depth/strata_import_codec.gd")
const TILE_SIDE := 64
const ACK_NOTICE_USEC := 15000000
const ACK_NOTICE_MESSAGE := "The owner ACK exceeded 15 seconds. Outcome remains pending; no zero-write or completed claim is inferred from a timeout."
const FENCE_KEYS := ["scene_id", "owner_id", "generation", "revision", "authored_serial", "permission_sha256"]

var _host: Object
var _compiled: Dictionary = {}
var _stages: Array = []
var _initial: Dictionary = {}
var _live: Dictionary = {}
var _projected: Dictionary = {}
var _budgets: Dictionary = {}
var _status := "idle"
var _phase := ""
var _error := ""
var _token := ""
var _job_id := ""
var _index := 0
var _tiles: Array[Rect2i] = []
var _tile_index := 0
var _pending: Dictionary = {}
var _stop := false
var _approved := false
var _processed := 0
var _inspected := 0
var _changed := 0
var _receipts: Array = []
var _started_usec := 0
var _maximum_step_usec := 0
var _capture_count := 0
var _apply_count := 0
var _record_bytes := 0
var _unverified_outcome := false
var _history_summary: Array = []
var _history_warnings: Array[String] = []
var _source_image: Image
var _output_image: Image


func begin(host: Object, plan: Dictionary, admitted: PackedInt32Array) -> Dictionary:
	if state().busy: return Module.failure("Finish or stop the active finite authoring job.")
	_reset()
	_host = host
	if host == null: return _refuse("An ordinary Workbench owner adapter is required.")
	for method: String in ["authoring_plane_state", "authoring_capture", "authoring_apply", "authoring_poll", "authoring_flush", "authoring_record"]:
		if not host.has_method(method): return _refuse("The owner adapter lacks " + method)
	_compiled = Plan.compile(plan, admitted)
	if not _compiled.ok: return _refuse(str(_compiled.error))
	_stages = _compiled.stages.duplicate(true)
	_started_usec = Time.get_ticks_usec()
	_job_id = "strata-" + Module.digest((_compiled.proposal_sha256 + ":" + str(_started_usec) + ":" + str(get_instance_id())).to_utf8_buffer()).left(24)
	for stage: Dictionary in _stages:
		var id: String = stage.plane
		if not _initial.has(id):
			var source: Dictionary = host.authoring_plane_state(id)
			var error := _state_error(source)
			if not error.is_empty(): return _refuse(error)
			if source.scene_id != _compiled.plan.scene_id: return _refuse("The finite plan belongs to a different live scene.")
			if int(source.get("remaining_authoring_records", 0)) < _stages.size(): return _refuse("Retained provenance capacity cannot cover every finite stage; no native writes occurred.")
			_initial[id] = source.duplicate(true)
			_live[id] = source.duplicate(true)
			_projected[id] = {}
			_budgets[id] = {"rectangles": int(source.get("authored_rectangles", 0)), "writes": int(source.get("authored_layout_writes", 0)), "chunks": 0}
		if int(stage.expected_revision) != int(_initial[id].revision): return _refuse("A stage's expected authored revision is stale.")
		var bounds := Rect2i(0, 0, int(_initial[id].extent[0]), int(_initial[id].extent[1]))
		if not bounds.encloses(Module.rectangle(stage.region)): return _refuse("The complete finite stage must fit the actual target plane extent.")
		for i: int in range(2, stage.cells.size(), 3):
			if not bool(_initial[id].erase_allowed if int(stage.cells[i]) == 0 else _initial[id].paint_allowed): return _refuse("Current plane permissions refuse a proposed paint or explicit Empty cell.")
		stage.status = "pending"
		stage.applied = 0
		stage.changed = 0
		stage.completed_chunks = 0
		stage.before_revision = int(_initial[id].revision)
		stage.after_revision = int(_initial[id].revision)
		stage.before_sha256 = ""
		stage.projected_sha256 = ""
		stage.actual_sha256 = ""
		stage.published = false
		stage.error = ""
		stage.receipts = []
		stage.recorded = false
		stage.readback_error = ""
		stage.metadata["verified_prefix_sha256"] = ""
		stage.metadata["readback_scope"] = "pending actual native capture"
		stage.metadata["authored_serial_before"] = int(_initial[id].authored_serial)
		stage.metadata["authored_serial_after"] = int(_initial[id].authored_serial)
		var budget_record := _record(stage, "refused")
		budget_record.metadata.verified_prefix_sha256 = "f".repeat(64)
		budget_record.metadata.readback_scope = "actual full stage-region native readback after the acknowledged operation"
		budget_record.metadata.authored_serial_before = 2147483647
		budget_record.metadata.authored_serial_after = 2147483647
		var record_error := Provenance.validate_record(budget_record)
		if not record_error.is_empty(): return _refuse("Retained stage provenance is invalid before writing: " + record_error)
		# Reserve complete fixed-width hashes/revisions before writes. The final
		# record only replaces these values; it never grows unbounded diagnostics.
		for key: String in ["source_sha256", "proposal_sha256", "geometry_sha256", "before_sha256", "projected_sha256", "actual_sha256"]: budget_record[key] = "f".repeat(64)
		for key: String in ["generation", "before_revision", "after_revision", "requested_cells", "applied_cells", "changed_cells", "requested_chunks", "completed_chunks"]: budget_record[key] = 2147483647
		# Final diagnostics retain at most512 codepoints. JSON's longest escaped
		# codepoint needs6 bytes; reserve that representation prospectively.
		budget_record.error = String.chr(1).repeat(512)
		_record_bytes += Module.json_bytes(budget_record).size() + 64 # Longest terminal status and array punctuation.
	for id: String in _initial:
		if int(_initial[id].get("remaining_authoring_bytes", Provenance.MAX_BYTES)) < _record_bytes: return _refuse("Retained provenance byte budget cannot cover this complete finite plan.")
	_status = "preparing"
	_phase = "prepare_stage"
	return state()


func _reset() -> void:
	_compiled = {}; _stages = []; _initial = {}; _live = {}; _projected = {}; _budgets = {}
	_status = "idle"; _phase = ""; _error = ""; _token = ""; _job_id = ""; _index = 0
	_tiles.clear(); _tile_index = 0; _pending = {}; _stop = false; _approved = false
	_processed = 0; _inspected = 0; _changed = 0; _receipts = []; _started_usec = 0
	_maximum_step_usec = 0; _capture_count = 0; _apply_count = 0; _record_bytes = 0
	_unverified_outcome = false
	_history_summary.clear(); _history_warnings.clear()
	_source_image = null; _output_image = null


func _state_error(source: Dictionary) -> String:
	if not source.get("ok", false): return str(source.get("error", "The native target is unavailable."))
	if not source.has_all(FENCE_KEYS + ["extent", "paint_allowed", "erase_allowed"]): return "The owner adapter returned incomplete source fences."
	if not source.scene_id is String or source.scene_id.is_empty() or not source.owner_id is String or source.owner_id.is_empty() or not Module.integer(source.generation, 0, 2147483647) or not Module.integer(source.revision, 0, 2147483647) or not Module.integer(source.authored_serial, 0, 2147483647) or not Module.hex_digest(source.permission_sha256) or not Module.pair(source.extent, 512, 2048): return "The owner adapter returned malformed source identity."
	if not source.paint_allowed is bool or not source.erase_allowed is bool or (not source.paint_allowed and not source.erase_allowed): return _receipt_error(source, "The plane is hidden, locked or otherwise excluded from editing.")
	return ""


func _receipt_error(receipt: Dictionary, fallback: String) -> String:
	var error := str(receipt.get("error", receipt.get("reason", "")))
	return fallback if error.is_empty() else error


func _fence_error(id: String, expected: Dictionary) -> String:
	var current: Dictionary = _host.authoring_plane_state(id)
	var error := _state_error(current)
	if not error.is_empty(): return error
	for key: String in FENCE_KEYS:
		if current[key] != expected[key]: return "Authoring source or permission changed after preview: " + key
	return ""


func _refuse(message: String) -> Dictionary:
	_status = "refused"
	_error = message
	_phase = ""
	_token = ""
	return state()


func _make_tiles(region: Rect2i) -> void:
	_tiles.clear(); _tile_index = 0
	for y: int in range(region.position.y, region.end.y, TILE_SIDE):
		for x: int in range(region.position.x, region.end.x, TILE_SIDE):
			_tiles.append(Rect2i(x, y, mini(TILE_SIDE, region.end.x - x), mini(TILE_SIDE, region.end.y - y)))


func _region_index(stage: Dictionary, x: int, y: int) -> int:
	return (y - int(stage.region[1])) * int(stage.region[2]) + x - int(stage.region[0])


func _image(materials: PackedInt32Array, size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for i: int in materials.size():
		if materials[i] != 0: image.set_pixel(i % size.x, i / size.x, Codec._colour(materials[i]))
	return image


func _prepare_stage() -> void:
	if _index >= _stages.size():
		for id: String in _initial:
			var limit := int(_initial[id].get("history_limit", 32))
			var existing := int(_initial[id].get("undo_count", 0))
			var chunks := int(_budgets[id].chunks)
			var displaced := maxi(0, existing + chunks - limit)
			_history_summary.append({"plane": id, "limit": limit, "existing_entries": existing if _initial[id].has("undo_count") else -1,
				"proposed_entries": chunks, "displaced_entries": displaced, "retained_plan_entries": mini(chunks, limit)})
			if displaced > 0:
				_history_warnings.append("%s needs %d history chunks; the existing %d-entry window will displace at least %d earlier entries. Undo retains the newest chunks only." % [id.capitalize(), chunks, limit, displaced])
		var identities: Array = []
		for stage: Dictionary in _stages: identities.append({"id": stage.id, "plane": stage.plane, "before": stage.before_sha256, "projected": stage.projected_sha256})
		_token = Module.digest(Module.json_bytes({"proposal": _compiled.proposal_sha256, "sources": _initial, "observations": identities, "job": _job_id}))
		_status = "ready"; _phase = ""
		return
	var stage: Dictionary = _stages[_index]
	var error := _fence_error(stage.plane, _initial[stage.plane])
	if not error.is_empty(): _refuse(error); return
	stage.status = "observing"
	stage.before_region = PackedInt32Array()
	stage.before_region.resize(int(stage.region[2]) * int(stage.region[3]))
	_make_tiles(Module.rectangle(stage.region))
	_phase = "capture_preview"


func _request_capture(kind: String) -> void:
	var stage: Dictionary = _stages[_index]
	var expected: Dictionary = _initial[stage.plane] if kind == "preview" else _live[stage.plane]
	var error := _fence_error(stage.plane, expected)
	if not error.is_empty():
		if kind == "preview": _refuse(error)
		else: _readback_failed(error)
		return
	var tile: Rect2i = _tiles[_tile_index]
	_capture_count += 1
	var receipt: Dictionary = _host.authoring_capture(stage.plane, tile, expected.duplicate(true))
	var operation := {"kind": kind, "tile": tile, "expected": expected.duplicate(true), "started_usec": Time.get_ticks_usec()}
	if receipt.get("pending", false):
		if not receipt.get("ok", false) or not Module.integer(receipt.get("operation_id"), 1):
			_handle_capture(Module.failure("Malformed pending native capture receipt."), operation); return
		operation.operation_id = int(receipt.operation_id); _pending = operation
	else: _handle_capture(receipt, operation)


func _handle_capture(receipt: Dictionary, operation: Dictionary) -> void:
	var stage: Dictionary = _stages[_index]
	var tile: Rect2i = operation.tile
	var error := ""
	if not receipt.get("ok", false) or receipt.get("status", "") != "completed": error = _receipt_error(receipt, "Native capture refused.")
	elif not receipt.get("materials") is PackedInt32Array or receipt.materials.size() != tile.get_area(): error = "Native capture returned incomplete material bytes."
	elif receipt.get("region") != tile: error = "Native capture returned a different or unspecified region."
	elif not receipt.get("owner_id") is String or receipt.owner_id != operation.expected.owner_id: error = "Native capture returned a retired or unspecified owner identity."
	elif not Module.integer(receipt.get("generation"), 0, 2147483647) or int(receipt.generation) != int(operation.expected.generation): error = "Native capture returned a stale or unspecified generation."
	elif not Module.integer(receipt.get("authored_revision"), 0, 2147483647) or int(receipt.authored_revision) != int(operation.expected.revision): error = "Native capture returned a stale or unspecified authored revision."
	elif not Module.integer(receipt.get("authored_serial"), 0, 2147483647) or int(receipt.authored_serial) != int(operation.expected.authored_serial): error = "Native capture returned a stale or unspecified authored history serial."
	else: error = _fence_error(stage.plane, operation.expected)
	if not error.is_empty():
		if operation.kind == "preview": _refuse(error)
		else: _readback_failed(error)
		return
	var field := "before_region" if operation.kind == "preview" else "actual_region"
	for i: int in tile.get_area():
		var x := tile.position.x + i % tile.size.x
		var y := tile.position.y + i / tile.size.x
		stage[field][_region_index(stage, x, y)] = int(receipt.materials[i])
	_tile_index += 1
	if operation.kind == "preview": _inspected += tile.get_area()
	if _tile_index == _tiles.size(): _phase = "finish_preview" if operation.kind == "preview" else "finish_readback"


func _finish_preview() -> void:
	var stage: Dictionary = _stages[_index]
	var region := Module.rectangle(stage.region)
	var previously_projected: Dictionary = _projected[stage.plane]
	for key: int in previously_projected:
		var point := Vector2i(key % 2048, key / 2048)
		if region.has_point(point): stage.before_region[_region_index(stage, point.x, point.y)] = int(previously_projected[key])
	stage.before_sha256 = Module.digest(stage.before_region.to_byte_array())
	stage.after_region = stage.before_region.duplicate()
	stage.before_cells = PackedInt32Array()
	stage.before_cells.resize(stage.cells.size() / 3)
	var changed := 0
	for i: int in stage.cells.size() / 3:
		var x: int = stage.cells[i * 3]; var y: int = stage.cells[i * 3 + 1]; var material: int = stage.cells[i * 3 + 2]
		var index := _region_index(stage, x, y)
		stage.before_cells[i] = int(stage.before_region[index])
		if int(stage.before_region[index]) != material: changed += 1
		stage.after_region[index] = material
	for clearance: Array in stage.clearances:
		var box := Module.rectangle(clearance)
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				if int(stage.before_region[_region_index(stage, x, y)]) != 0: _refuse("A declared native module clearance is occupied in the actual target plane."); return
	var source: Dictionary = _initial[stage.plane]
	for offset: int in range(0, stage.cells.size(), Plan.CHUNK_CELLS * 3):
		var chunk: PackedInt32Array = stage.cells.slice(offset, mini(stage.cells.size(), offset + Plan.CHUNK_CELLS * 3))
		var encoded := History.stamps(chunk, Vector2i(int(source.extent[0]), int(source.extent[1])))
		if not encoded.accepted: _refuse(str(encoded.error)); return
		_budgets[stage.plane].rectangles += encoded.stamps.size()
		_budgets[stage.plane].writes += chunk.size() / 3
		_budgets[stage.plane].chunks += 1
	if int(_budgets[stage.plane].rectangles) > int(source.get("max_rectangles", 32768)) or int(_budgets[stage.plane].writes) > int(source.get("max_layout_writes", 16777216)) or int(source.revision) + int(_budgets[stage.plane].chunks) > 2147483647:
		_refuse("The projected acknowledged chunks exceed existing target authored-layout or revision capacity."); return
	if _host.has_method("authoring_preflight"):
		var expected: Dictionary = source.duplicate(true); expected.before = stage.before_cells.duplicate()
		var preflight: Dictionary = _host.authoring_preflight(stage.plane, stage.cells.duplicate(), expected)
		if not preflight.get("ok", false): _refuse(str(preflight.get("error", "Existing authored-layout authority refused this projected stage."))); return
	stage.projected_sha256 = Module.digest(stage.after_region.to_byte_array())
	stage.preview_changed = changed
	stage.status = "previewed"
	for i: int in range(0, stage.cells.size(), 3): previously_projected[int(stage.cells[i + 1]) * 2048 + int(stage.cells[i])] = int(stage.cells[i + 2])
	stage.before_image = _image(stage.before_region, region.size)
	stage.output_image = _image(stage.after_region, region.size)
	if _index == 0:
		_source_image = stage.before_image
		_output_image = stage.output_image
	_index += 1
	_phase = "prepare_stage"


func approve(token: String) -> Dictionary:
	if _status != "ready" or token.is_empty() or token != _token: return Module.failure("Approve the current exact finite proposal token after its native preview.")
	for id: String in _initial:
		var error := _fence_error(id, _initial[id])
		if not error.is_empty(): return _refuse(error)
	_approved = true; _status = "applying"; _phase = "start_stage"; _index = 0
	return state()


func stop() -> Dictionary:
	if _status in ["preparing", "ready"]:
		_stop = true
		if _pending.is_empty(): _status = "cancelled"; _phase = ""; _token = ""; _error = "Preparation cancelled; no native writes occurred."
	elif _status in ["applying", "stopping", "awaiting_ack"]:
		_stop = true; _status = "stopping"
		_error = "Stop requested; the current <=4096-cell owner operation must acknowledge before the unapplied suffix is abandoned."
	return state()


func _start_stage() -> void:
	if _index >= _stages.size(): _status = "completed"; _phase = ""; return
	var stage: Dictionary = _stages[_index]
	for dependency: String in stage.depends_on:
		var completed := false
		for previous: Dictionary in _stages:
			if previous.id == dependency: completed = previous.status == "completed"
		if not completed: _error = "A required stage was not completed and acknowledged."; _status = "partial" if _processed > 0 else "refused"; _phase = ""; return
	var error := _fence_error(stage.plane, _live[stage.plane])
	if not error.is_empty(): _error = error; _status = "partial" if _processed > 0 else "refused"; _phase = ""; return
	stage.before_revision = int(_live[stage.plane].revision)
	stage.after_revision = int(_live[stage.plane].revision)
	stage.metadata.authored_serial_before = int(_live[stage.plane].authored_serial)
	stage.metadata.authored_serial_after = int(_live[stage.plane].authored_serial)
	stage.status = "applying"
	stage.prefix_region = stage.before_region.duplicate()
	_phase = "apply_chunk"


func _request_apply() -> void:
	var stage: Dictionary = _stages[_index]
	if _stop or int(stage.applied) >= stage.cells.size() / 3: _begin_readback(); return
	var error := _fence_error(stage.plane, _live[stage.plane])
	if not error.is_empty(): stage.error = error; _error = error; _stop = true; _begin_readback(); return
	var offset := int(stage.applied)
	var end := mini(stage.cells.size() / 3, offset + Plan.CHUNK_CELLS)
	var chunk: PackedInt32Array = stage.cells.slice(offset * 3, end * 3)
	var expected: Dictionary = _live[stage.plane].duplicate(true)
	expected.before = stage.before_cells.slice(offset, end)
	_apply_count += 1
	var receipt: Dictionary = _host.authoring_apply(stage.plane, chunk, expected)
	var operation := {"kind": "apply", "cells": chunk, "expected": expected, "started_usec": Time.get_ticks_usec()}
	if receipt.get("pending", false):
		if not receipt.get("ok", false) or not Module.integer(receipt.get("operation_id"), 1): _handle_apply(Module.failure("Malformed pending native edit receipt."), operation); return
		operation.operation_id = int(receipt.operation_id); _pending = operation
	else: _handle_apply(receipt, operation)


func _handle_apply(receipt: Dictionary, operation: Dictionary) -> void:
	var stage: Dictionary = _stages[_index]
	var requested: int = operation.cells.size() / 3
	var applied: int = int(receipt.get("applied", 0)) if Module.integer(receipt.get("applied", 0), 0, requested) else 0
	var receipt_error := ""
	if receipt.has("applied") and not Module.integer(receipt.applied, 0, requested): receipt_error = "The native ACK contains a malformed applied-prefix count."
	if not receipt.has("applied") and receipt.get("status", "") in ["completed", "partial"]: receipt_error = "The native ACK claims a mutation without its applied-prefix count."
	if receipt.has("owner_id") and receipt.owner_id != operation.expected.owner_id: receipt_error = "The native ACK identifies a different or retired owner."
	if receipt.has("generation") and (not Module.integer(receipt.generation, 0, 2147483647) or int(receipt.generation) != int(operation.expected.generation)): receipt_error = "The native ACK belongs to a different or invalid generation."
	if applied > 0 and not receipt.has_all(["owner_id", "generation"]): receipt_error = "The native mutation ACK lacks its owner identity."
	if receipt.has("authored_revision") and not Module.integer(receipt.authored_revision, 0, 2147483647): receipt_error = "The native ACK contains an invalid authored revision."
	if applied > 0:
		if not receipt.get("cells") is PackedInt32Array or not receipt.get("before") is PackedInt32Array or not receipt.get("after") is PackedInt32Array or receipt.cells.size() != applied * 3 or receipt.before.size() != applied or receipt.after.size() != applied: receipt_error = "The native owner reported writes without a complete acknowledged material prefix."
		else:
			for i: int in applied:
				if int(receipt.cells[i * 3]) != int(operation.cells[i * 3]) or int(receipt.cells[i * 3 + 1]) != int(operation.cells[i * 3 + 1]) or int(receipt.before[i]) != int(operation.expected.before[i]) or int(receipt.cells[i * 3 + 2]) != int(receipt.after[i]): receipt_error = "The native owner acknowledgement does not identify the requested cell prefix."; break
	if not receipt_error.is_empty():
		# Unknown native outcome is explicitly blocked, never relabelled zero-write.
		stage.error = receipt_error; _error = receipt_error; stage.status = "failed"; _status = "failed"; _phase = ""; _stop = true
		_unverified_outcome = true
		_receipts.append(receipt.duplicate(true)); return
	var actual_changed := 0
	for i: int in applied:
		var x: int = receipt.cells[i * 3]; var y: int = receipt.cells[i * 3 + 1]; var actual: int = receipt.after[i]
		stage.prefix_region[_region_index(stage, x, y)] = actual
		if int(receipt.before[i]) != actual: actual_changed += 1
	stage.applied += applied; stage.changed += actual_changed
	_processed += applied; _changed += actual_changed
	var complete: bool = receipt.get("status", "") == "completed" and receipt.get("ok", false) and applied == requested
	if complete:
		for i: int in applied:
			if int(receipt.after[i]) != int(operation.cells[i * 3 + 2]): complete = false; receipt_error = "Native ACK material differs from the reviewed proposal."; break
	if complete: stage.completed_chunks += 1
	var current: Dictionary = _host.authoring_plane_state(stage.plane)
	for key: String in ["scene_id", "owner_id", "generation", "permission_sha256"]:
		if current.get(key) != operation.expected[key]: complete = false; receipt_error = "Native source or permissions changed while an operation was pending."
	if current.has("revision") and Module.integer(current.revision, int(operation.expected.revision), 2147483647):
		_live[stage.plane].revision = int(current.revision)
		stage.after_revision = int(current.revision)
		if receipt.has("authored_revision") and int(receipt.authored_revision) != int(current.revision): complete = false; receipt_error = "Native ACK authored revision is stale."
	else: complete = false; receipt_error = "Native owner lost its acknowledged authored revision."
	if not Module.integer(current.get("authored_serial"), int(operation.expected.authored_serial), 2147483647):
		complete = false; receipt_error = "The owner lost its authored history serial."
	elif applied > 0 and (not Module.integer(receipt.get("authored_serial"), int(operation.expected.authored_serial), 2147483647) or int(receipt.authored_serial) != int(current.authored_serial)):
		complete = false; receipt_error = "An authored operation changed outside this native ACK."
	elif applied == 0 and int(current.authored_serial) != int(operation.expected.authored_serial):
		complete = false; receipt_error = "An unrelated authored operation changed during a refused chunk."
	else:
		_live[stage.plane].authored_serial = int(current.authored_serial)
		stage.metadata.authored_serial_after = int(current.authored_serial)
	var retained := receipt.duplicate(true)
	retained.stage_id = stage.id; retained.plane = stage.plane
	retained.session_applied = applied; retained.session_changed = actual_changed
	_receipts.append(retained); stage.receipts.append(retained)
	if not complete:
		stage.error = receipt_error if not receipt_error.is_empty() else str(receipt.get("error", receipt.get("reason", "The native owner refused or stopped the remaining chunk.")))
		_error = stage.error; _stop = true
		_begin_readback()
	elif _stop or int(stage.applied) == stage.cells.size() / 3: _begin_readback()


func _begin_readback() -> void:
	var stage: Dictionary = _stages[_index]
	if int(stage.applied) == 0: _phase = "flush_stage"; return
	stage.actual_region = PackedInt32Array()
	stage.actual_region.resize(int(stage.region[2]) * int(stage.region[3]))
	_make_tiles(Module.rectangle(stage.region))
	_phase = "capture_readback"


func _readback_failed(message: String) -> void:
	var stage: Dictionary = _stages[_index]
	stage.readback_error = message
	stage.error = message if str(stage.error).is_empty() else str(stage.error) + " " + message
	_error = stage.error; _stop = true; _phase = "flush_stage"


func _finish_readback() -> void:
	var stage: Dictionary = _stages[_index]
	stage.actual_sha256 = Module.digest(stage.actual_region.to_byte_array())
	stage.metadata.verified_prefix_sha256 = Module.digest(stage.prefix_region.to_byte_array())
	stage.metadata.readback_scope = "actual full stage-region native readback after the acknowledged operation"
	if stage.actual_sha256 != stage.metadata.verified_prefix_sha256:
		stage.error = "Actual native region differs from the acknowledged prefix, including protected/no-write cells."
		_error = stage.error; _stop = true
	_phase = "flush_stage"


func _record(stage: Dictionary, outcome: String) -> Dictionary:
	var source: Dictionary = _initial[stage.plane]
	return {"version": 1, "id": _job_id + "-" + Module.digest(str(stage.id).to_utf8_buffer()).left(16), "kind": _compiled.plan.kind, "plane": stage.plane,
		"scene_id": source.scene_id, "owner_id": source.owner_id, "generation": int(source.generation),
		"before_revision": int(stage.before_revision), "after_revision": int(stage.after_revision), "status": outcome,
		"requested_cells": stage.cells.size() / 3, "applied_cells": int(stage.applied), "changed_cells": int(stage.changed),
		"requested_chunks": int(stage.chunks), "completed_chunks": int(stage.completed_chunks),
		"source_sha256": _compiled.plan.source_sha256, "proposal_sha256": _compiled.proposal_sha256, "geometry_sha256": stage.geometry_sha256,
		"before_sha256": stage.before_sha256, "projected_sha256": stage.projected_sha256, "actual_sha256": stage.actual_sha256,
		"published": bool(stage.published), "metadata": stage.metadata.duplicate(true), "error": str(stage.error).left(512),
		"historical": true, "scope": "authored-material-operation-history"}


func _flush_stage() -> void:
	var stage: Dictionary = _stages[_index]
	if int(stage.applied) > 0:
		var flush: Dictionary = _host.authoring_flush(stage.plane)
		stage.published = bool(flush.get("published", false))
		if not stage.published:
			stage.error = str(stage.error) + (" " if not str(stage.error).is_empty() else "") + str(flush.get("error", "Native cells committed; display publication is stale."))
	var native_complete: bool = int(stage.applied) == stage.cells.size() / 3 and int(stage.completed_chunks) == int(stage.chunks) and not str(stage.actual_sha256).is_empty() and stage.actual_sha256 == stage.projected_sha256 and str(stage.readback_error).is_empty()
	var outcome := "completed" if native_complete and stage.published else ("committed_stale_pixels" if native_complete else ("partial" if int(stage.applied) > 0 else ("cancelled" if _stop and str(stage.error).is_empty() else "refused")))
	stage.status = outcome
	var record := _record(stage, outcome)
	var error := Provenance.validate_record(record)
	if error.is_empty():
		var recorded: Dictionary = _host.authoring_record(record)
		stage.recorded = bool(recorded.get("ok", false))
		if not stage.recorded: error = str(recorded.get("error", "The native outcome could not be retained in authored provenance."))
	if not error.is_empty():
		stage.error = str(stage.error) + " " + error
		_error = stage.error; _status = "partial" if _processed > 0 else "failed"; _phase = ""; return
	if outcome == "completed" and _stop and _index == _stages.size() - 1:
		_status = "completed"; _phase = ""; _error = "Stop arrived after the complete native plan had committed and been read back."
		return
	if outcome != "completed" or _stop:
		_error = str(stage.error) if not str(stage.error).is_empty() else ("Stopped after the acknowledged native prefix; unapplied stages remain pending." if _stop else "")
		_status = "committed_stale_pixels" if outcome == "committed_stale_pixels" else ("partial" if _processed > 0 else "cancelled")
		_phase = ""; return
	_index += 1
	_phase = "start_stage"


func step() -> Dictionary:
	var start := Time.get_ticks_usec()
	if not _pending.is_empty():
		var receipt: Dictionary = _host.authoring_poll(int(_pending.operation_id))
		if receipt.is_empty():
			if Time.get_ticks_usec() - int(_pending.started_usec) > ACK_NOTICE_USEC:
				_error = ACK_NOTICE_MESSAGE
				if _approved: _status = "awaiting_ack"
		else:
			# A delayed reply resolves only the provisional waiting notice. The
			# normal receipt handlers still validate identity and native outcome.
			if _error == ACK_NOTICE_MESSAGE: _error = ""
			if _status == "awaiting_ack": _status = "stopping" if _stop else "applying"
			var operation := _pending; _pending = {}
			if operation.kind == "apply": _handle_apply(receipt, operation)
			else: _handle_capture(receipt, operation)
			if _stop and not _approved: _status = "cancelled"; _phase = ""; _error = "Preparation cancelled; no native writes occurred."
	elif _stop and not _approved and _status == "preparing": _status = "cancelled"; _phase = ""; _error = "Preparation cancelled; no native writes occurred."
	elif _status in ["preparing", "applying", "stopping", "awaiting_ack"]:
		match _phase:
			"prepare_stage": _prepare_stage()
			"capture_preview": _request_capture("preview")
			"finish_preview": _finish_preview()
			"start_stage":
				if _stop: _status = "partial" if _processed > 0 else "cancelled"; _phase = ""
				else: _start_stage()
			"apply_chunk": _request_apply()
			"capture_readback": _request_capture("readback")
			"finish_readback": _finish_readback()
			"flush_stage": _flush_stage()
	_maximum_step_usec = maxi(_maximum_step_usec, Time.get_ticks_usec() - start)
	return state()


func projections() -> Array:
	var result: Array = []
	for stage: Dictionary in _stages:
		if stage.has("before_region") and stage.has("after_region"):
			result.append({"id": stage.id, "plane": stage.plane, "region": stage.region.duplicate(),
				"before": stage.before_region.duplicate(), "after": stage.after_region.duplicate()})
	return result


func state() -> Dictionary:
	var stages: Array = []
	var previews: Array = []
	var preview_changed := 0
	for stage: Dictionary in _stages:
		preview_changed += int(stage.get("preview_changed", 0))
		stages.append({"id": stage.id, "plane": stage.plane, "region": stage.region.duplicate(), "status": stage.get("status", "pending"),
			"total": stage.cells.size() / 3, "applied": int(stage.get("applied", 0)), "changed": int(stage.get("changed", 0)),
			"chunks": int(stage.chunks), "completed_chunks": int(stage.get("completed_chunks", 0)),
			"before_revision": int(stage.get("before_revision", 0)), "after_revision": int(stage.get("after_revision", 0)),
			"before_sha256": stage.get("before_sha256", ""), "projected_sha256": stage.get("projected_sha256", ""), "actual_sha256": stage.get("actual_sha256", ""),
			"published": bool(stage.get("published", false)), "recorded": bool(stage.get("recorded", false)), "error": stage.get("error", "")})
		if stage.has("before_image"):
			previews.append({"id": stage.id, "plane": stage.plane, "region": stage.region.duplicate(),
				"before_image": stage.before_image, "output_image": stage.output_image})
	var busy := _status in ["preparing", "applying", "stopping", "awaiting_ack"]
	return {"ok": _status in ["preparing", "ready", "applying", "completed"], "status": _status, "busy": busy,
		"cancellable": busy or _status == "ready", "can_approve": _status == "ready", "token": _token,
		"processed": _processed if _approved else _inspected, "total": int(_compiled.get("total", 0)) if _approved else int(_compiled.get("inspected_cells", 0)),
		"applied_cells": _processed, "changed_cells": _changed if _approved else preview_changed,
		"source_sha256": _compiled.get("plan", {}).get("source_sha256", ""), "proposal_sha256": _compiled.get("proposal_sha256", ""),
		"geometry_sha256": _stages[0].geometry_sha256 if _stages.size() == 1 else "",
		"source_image": _source_image, "output_image": _output_image, "stages": stages, "preview_regions": previews, "receipts": _receipts.duplicate(true),
		"history_summary": _history_summary.duplicate(true), "history_warnings": _history_warnings.duplicate(),
		"zero_writes": not _approved, "native_outcome_unverified": _unverified_outcome, "pixels_pending": _approved and busy and _processed > 0,
		"phase": _phase, "pending_owner_ack": not _pending.is_empty(), "error": _error,
		"message": ("Review exact material-ID projection, then Approve. Existing owner history records each <=4096-cell chunk. " + " ".join(_history_warnings)) if _status == "ready" else "",
		"preview_kind": "Copied native materials and projected material-ID colours; production framebuffer appearance qualifies separately.",
		"metrics": {"capture_calls": _capture_count, "apply_calls": _apply_count, "maximum_step_usec": _maximum_step_usec,
			"elapsed_usec": Time.get_ticks_usec() - _started_usec if _started_usec > 0 else 0, "reserved_provenance_bytes": _record_bytes}}
