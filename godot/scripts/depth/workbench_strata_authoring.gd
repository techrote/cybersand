extends RefCounted

## Ordinary Workbench adapter for copied native observations and bounded writes.
## It never stores a Play World reference or consumes the worker's result slot.
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const History = preload("res://scripts/workbench_paint_editor_history.gd")

var controller: Node
var _serial := 0
var _results: Dictionary = {}
var _pending_operations: Dictionary = {}


func mount(value: Node) -> void:
	controller = value
	controller.wb.paint_editor.strata_operation_finished.connect(_play_finished)


func _error(message: String) -> Dictionary:
	return {"ok":false, "error":message, "status":"refused", "applied":0}


func _materials() -> PackedInt32Array:
	return controller.wb.host.simulation_worker.paint_materials()


func authoring_materials() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: int in _materials():
		result.append({"id":id, "label":controller.wb.host.material_name(id)})
	return result


func authoring_plane_state(id: String) -> Dictionary:
	if not controller.has_document() or id not in Document.IDS:
		return _error("Enable Strata and select an initialized native plane.")
	var doc: Dictionary = controller.document()
	var row: Dictionary = Document.plane(doc, id)
	var owner: Dictionary = controller.layer_owner.stats()
	var worker: Dictionary = controller.wb.host.simulation_worker.paint_state()
	var visible: bool = controller.enabled() and controller.presenter.effective_visible(id)
	var allowed: bool = visible and not bool(row.locked) and controller._pending.is_empty() and controller._apply_serial == 0
	var source: Dictionary = worker if id == "play" else owner.layers.get(id, {})
	var generation: int = int(worker.get("generation", -1)) if id == "play" else int(owner.generation)
	var revision: int = int(worker.get("revision", -1)) if id == "play" else int(row.revision)
	var owner_id: String = "ordinary-play:%d:%d" % [controller.wb.host.simulation_worker.get_instance_id(), generation] if id == "play" else str(source.get("owner_id", ""))
	var error := ""
	if id == "play":
		if not controller.wb.host.paused: error = "Pause Play before native import, capture or construction."
		elif controller.active_layer() != "play": error = "Select Play explicitly before approving Play geometry."
		elif controller.wb.paint_editor._save_hold: error = "Restore or undo the unrecorded Play prefix before authoring."
		elif bool(worker.get("art_busy", false)) or bool(worker.get("legacy_busy", false)) or bool(worker.get("transition_busy", false)) or bool(worker.get("flatten_busy", false)):
			error = "Wait for the ordinary native owner transaction."
	else:
		error = controller.layer_owner.edit_error(id)
		if controller._publication_errors.has(id): error = "The committed plane has stale pixels; save and reopen before another edit."
	allowed = allowed and error.is_empty()
	var permission := {"plane":id, "visible":visible, "locked":row.locked,
		"paint":allowed and bool(worker.get("paint_allowed", true)) if id == "play" else allowed,
		"erase":allowed and bool(worker.get("erase_allowed", true)) if id == "play" else allowed,
		"materials":Array(_materials()), "source":controller.wb.applied.get("source", []) if id == "play" else [],
		"authoring_generation":int(worker.get("authoring_generation", 1)) if id == "play" else 1}
	var rectangles: Array = controller.wb.applied.get("edits", []) if id == "play" else row.rectangles
	var writes := 0
	for rectangle: Array in rectangles:
		if rectangle.size() == 5: writes += int(rectangle[2]) * int(rectangle[3])
		elif rectangle.size() == 4: writes += (int(rectangle[2]) * 2 + 1) * (int(rectangle[2]) * 2 + 1)
	return {"ok":true, "error":error, "scene_id":"%s:%d" % [owner.session_id, owner.generation],
		"owner_id":owner_id, "generation":generation, "revision":revision,
		"extent":doc.extent.duplicate(), "paint_allowed":permission.paint, "erase_allowed":permission.erase,
		"permission_sha256":Module.digest(Module.json_bytes(permission)),
		"authored_rectangles":rectangles.size(), "authored_layout_writes":writes,
		"max_rectangles":Setup.MAX_STAMPS if id == "play" else Document.MAX_RECTANGLES,
		"max_layout_writes":Document.MAX_LAYOUT_WRITES,
		"remaining_authoring_records":Provenance.MAX_RECORDS - doc.get("authoring", Provenance.default_configuration()).records.size(),
		"tick":int(worker.get("tick", 0)) if id == "play" else 0,
		"authoring_generation":int(worker.get("authoring_generation", 1)) if id == "play" else 1}


func _fence_error(id: String, expected: Dictionary) -> String:
	var current := authoring_plane_state(id)
	if not current.get("ok", false): return str(current.get("error", "Native plane unavailable."))
	if not current.paint_allowed and not current.erase_allowed: return str(current.get("error", "The target is excluded or locked."))
	for key: String in ["scene_id", "owner_id", "generation", "revision", "permission_sha256"]:
		if not expected.has(key) or expected[key] != current[key]: return "Native target or permission changed after preview: " + key
	return ""


func authoring_capture(id: String, region: Rect2i, expected: Dictionary) -> Dictionary:
	var error := _fence_error(id, expected)
	if not error.is_empty(): return _error(error)
	if region.get_area() < 1 or region.get_area() > 4096: return _error("Native preview captures are bounded to 4096 cells.")
	if id != "play": return controller.layer_owner.capture_region(id, region)
	_serial += 1
	var token := _serial
	_pending_operations[token] = {"plane":id, "kind":"capture", "expected":expected.duplicate(true)}
	if not controller.wb.paint_editor.strata_capture(region, token):
		_pending_operations.erase(token)
		return _error(controller.wb.paint_editor._message)
	return {"ok":true, "pending":true, "operation_id":token}


func authoring_apply(id: String, cells: PackedInt32Array, expected: Dictionary) -> Dictionary:
	var error := _fence_error(id, expected)
	if not error.is_empty(): return _error(error)
	if cells.is_empty() or cells.size() % 3 != 0 or cells.size() > 4096 * 3:
		return _error("Native import chunks contain at most 4096 complete cells.")
	if id != "play":
		var receipt: Dictionary = controller.layer_owner.paint_cells(id, cells, int(expected.generation), expected.get("before", PackedInt32Array()))
		controller._document = controller.layer_owner.document()
		controller.last_edit_receipt = receipt.duplicate(true)
		return receipt
	_serial += 1
	var token := _serial
	_pending_operations[token] = {"plane":id, "kind":"edit", "expected":expected.duplicate(true)}
	if not controller.wb.paint_editor.strata_commit(cells, token, expected.get("before", PackedInt32Array())):
		_pending_operations.erase(token)
		return _error(controller.wb.paint_editor._message)
	return {"ok":true, "pending":true, "operation_id":token}


func authoring_preflight(id: String, cells: PackedInt32Array, expected: Dictionary) -> Dictionary:
	var error := _fence_error(id, expected)
	if not error.is_empty(): return _error(error)
	if id != "play": return {"ok":true, "error":""}
	var prepared: Dictionary = History.prepare(controller.wb.applied, cells, controller.wb._generated_active, controller.wb._material_baseline)
	return {"ok":bool(prepared.get("accepted", false)), "error":str(prepared.get("error", ""))}


func _play_finished(token: int, receipt: Dictionary) -> void:
	if not _pending_operations.has(token): return
	var operation: Dictionary = _pending_operations[token]
	_pending_operations.erase(token)
	var result := receipt.duplicate(true)
	result.ok = result.get("status", "") == "completed" and (operation.kind == "capture" or bool(result.get("recorded", false)))
	result.error = str(result.get("reason", ""))
	result.owner_id = operation.expected.owner_id
	result.layer_id = "play"
	result.authored_revision = int(controller.wb.host.simulation_worker.paint_state().get("revision", -1))
	_results[token] = result


func authoring_poll(operation_id: int) -> Dictionary:
	if not _results.has(operation_id): return {}
	var result: Dictionary = _results[operation_id]
	_results.erase(operation_id)
	return result


func authoring_flush(id: String) -> Dictionary:
	if id == "play":
		# Read the accepted host's upload witness; do not consume a publication or
		# claim that a native ACK by itself means the current pixels were shown.
		var state: Dictionary = controller.wb.host.simulation_worker.paint_state()
		var current: bool = controller.wb.host.last_uploaded_world_generation == int(state.get("generation", -1)) \
			and controller.wb.host.last_uploaded_revision >= int(state.get("revision", -1))
		return {"ok":true, "published":current, "publication_owner":"ordinary-workbench",
			"observed_generation":controller.wb.host.last_uploaded_world_generation,
			"observed_revision":controller.wb.host.last_uploaded_revision,
			"observed_serial":controller.wb.host.last_uploaded_render_snapshot_serial,
			"error":"" if current else "Native Play edit committed; a current ordinary upload has not yet been observed."}
	var published: bool = controller._publish(id)
	return {"ok":true, "published":published, "error":"" if published else controller.status_text()}


func authoring_record(record: Dictionary) -> Dictionary:
	var document: Dictionary = controller.layer_owner.document()
	var appended: Dictionary = Provenance.append(document.get("authoring", Provenance.default_configuration()), record)
	if not appended.get("ok", false): return appended
	if not controller.layer_owner.update_extensions({"authoring":appended.authoring}): return _error(controller.layer_owner.last_error)
	controller._document = controller.layer_owner.document()
	controller._refresh_panel()
	return {"ok":true, "error":""}
