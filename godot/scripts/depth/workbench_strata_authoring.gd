extends RefCounted

## Ordinary Workbench adapter for copied native observations and bounded writes.
## It never stores a Play World reference or consumes the worker's result slot.
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const History = preload("res://scripts/workbench_paint_editor_history.gd")
const Codec = preload("res://scripts/depth/strata_import_codec.gd")
const Plan = preload("res://scripts/depth/strata_construction_plan.gd")
const Session = preload("res://scripts/depth/strata_construction_session.gd")
const Library = preload("res://scripts/depth/strata_authoring_library.gd")

var controller: Node
var _serial := 0
var _results: Dictionary = {}
var _pending_operations: Dictionary = {}
var _session: RefCounted
var _codec: RefCounted
var _preview_serial := 0
var _preview: Dictionary = {}
var _conversion_options: Dictionary = {}
var _harvest: Dictionary = {}
var _harvested: Dictionary = {}
var _issuing_native := false
var _preflight_play_setup: Dictionary = {}
var _observed_play_setup: Dictionary = {}
var _play_authored_serial := 0


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


func _observe_play_authored_layout() -> int:
	# Native revision can remain unchanged after a no-op material write while
	# the ordinary saved Setup/history still changes. Compare exact copied
	# authored state, including legacy and Art recorders, without modifying any
	# of their authorities. Equality is checked natively; copies occur on change.
	if _observed_play_setup != controller.wb.applied:
		_observed_play_setup = controller.wb.applied.duplicate(true)
		_play_authored_serial += 1
	return _play_authored_serial


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
		"native_tick":int(worker.get("tick", 0)) if id == "play" else 0,
		"paused":bool(controller.wb.host.paused) if id == "play" else true,
		"authoring_generation":int(worker.get("authoring_generation", 1)) if id == "play" else 1}
	var rectangles: Array = controller.wb.applied.get("edits", []) if id == "play" else row.rectangles
	var writes := 0
	for rectangle: Array in rectangles:
		if rectangle.size() == 5: writes += int(rectangle[2]) * int(rectangle[3])
		elif rectangle.size() == 4: writes += (int(rectangle[2]) * 2 + 1) * (int(rectangle[2]) * 2 + 1)
	return {"ok":true, "error":error, "scene_id":"%s:%d" % [owner.session_id, owner.generation],
		"owner_id":owner_id, "generation":generation, "revision":revision,
		"authored_serial":_observe_play_authored_layout() if id == "play" else revision,
		"history_limit":32, "undo_count":controller.wb.paint_editor._undo_stack.size() if id == "play" else int(source.get("undo",0)),
		"extent":doc.extent.duplicate(), "paint_allowed":permission.paint, "erase_allowed":permission.erase,
		"permission_sha256":Module.digest(Module.json_bytes(permission)),
		"authored_rectangles":rectangles.size(), "authored_layout_writes":writes,
		"max_rectangles":Setup.MAX_STAMPS if id == "play" else Document.MAX_RECTANGLES,
		"max_layout_writes":Document.MAX_LAYOUT_WRITES,
		"remaining_authoring_records":Provenance.MAX_RECORDS - doc.get("authoring", Provenance.default_configuration()).records.size(),
		"remaining_authoring_bytes":Provenance.MAX_BYTES - Module.json_bytes(doc.get("authoring", Provenance.default_configuration())).size(),
		"tick":int(worker.get("tick", 0)) if id == "play" else 0,
		"authoring_generation":int(worker.get("authoring_generation", 1)) if id == "play" else 1}


func _fence_error(id: String, expected: Dictionary) -> String:
	var current := authoring_plane_state(id)
	if not current.get("ok", false): return str(current.get("error", "Native plane unavailable."))
	if not current.paint_allowed and not current.erase_allowed:
		return str(current.error) if not str(current.get("error", "")).is_empty() else "The target is excluded or locked."
	for key: String in ["scene_id", "owner_id", "generation", "revision", "authored_serial", "permission_sha256"]:
		if not expected.has(key) or expected[key] != current[key]: return "Native target or permission changed after preview: " + key
	return ""


func authoring_capture(id: String, region: Rect2i, expected: Dictionary) -> Dictionary:
	var error := _fence_error(id, expected)
	if not error.is_empty(): return _error(error)
	if region.get_area() < 1 or region.get_area() > 4096: return _error("Native preview captures are bounded to 4096 cells.")
	if id != "play":
		var captured: Dictionary = controller.layer_owner.capture_region(id, region)
		captured.authored_serial = int(captured.get("authored_revision", -1))
		return captured
	_serial += 1
	var token := _serial
	_pending_operations[token] = {"plane":id, "kind":"capture", "expected":expected.duplicate(true)}
	_issuing_native = true
	var accepted: bool = controller.wb.paint_editor.strata_capture(region, token)
	_issuing_native = false
	if not accepted:
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
		receipt.authored_serial = int(receipt.get("authored_revision", Document.plane(controller.layer_owner.document(), id).revision))
		controller._document = controller.layer_owner.document()
		controller.last_edit_receipt = receipt.duplicate(true)
		return receipt
	_serial += 1
	var token := _serial
	_pending_operations[token] = {"plane":id, "kind":"edit", "expected":expected.duplicate(true)}
	_issuing_native = true
	var accepted: bool = controller.wb.paint_editor.strata_commit(cells, token, expected.get("before", PackedInt32Array()))
	_issuing_native = false
	if not accepted:
		_pending_operations.erase(token)
		return _error(controller.wb.paint_editor._message)
	return {"ok":true, "pending":true, "operation_id":token}


func authoring_preflight(id: String, cells: PackedInt32Array, expected: Dictionary) -> Dictionary:
	var error := _fence_error(id, expected)
	if not error.is_empty(): return _error(error)
	if id != "play": return {"ok":true, "error":""}
	var setup: Dictionary = _preflight_play_setup if not _preflight_play_setup.is_empty() else controller.wb.applied
	# The existing history authority records each acknowledged bounded chunk.
	# A whole-stage stamp can coalesce across those boundaries and understate
	# the eventual Setup byte/rectangle cost. Replay the exact write partition
	# against a private cumulative Setup before any owner approval or mutation.
	for offset: int in range(0, cells.size(), Plan.CHUNK_CELLS * 3):
		var chunk: PackedInt32Array = cells.slice(offset, mini(cells.size(), offset + Plan.CHUNK_CELLS * 3))
		var prepared: Dictionary = History.prepare(setup, chunk, controller.wb._generated_active, controller.wb._material_baseline)
		if not prepared.get("accepted", false):
			return _error("Play chunk %d exceeds the existing authored Setup admission: %s" % [offset / (Plan.CHUNK_CELLS * 3) + 1, str(prepared.get("error", ""))])
		setup = prepared.setup
	_preflight_play_setup = setup.duplicate(true)
	return {"ok":true, "error":""}


func _play_finished(token: int, receipt: Dictionary) -> void:
	if not _pending_operations.has(token): return
	var operation: Dictionary = _pending_operations[token]
	_pending_operations.erase(token)
	var result := receipt.duplicate(true)
	result.ok = result.get("status", "") == "completed" and (operation.kind == "capture" or bool(result.get("recorded", false)))
	result.error = str(result.get("reason", ""))
	result.owner_id = operation.expected.owner_id
	result.layer_id = "play"
	# Preserve the original ACK fence. A later worker state must not make an old
	# receipt appear to acknowledge unrelated native changes.
	result.authored_revision = int(receipt.get("revision", -1))
	# The existing editor has synchronously accepted/refused the original ACK
	# and recorded its authored Setup before emitting this owned completion.
	result.authored_serial = _observe_play_authored_layout()
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


func busy() -> bool:
	return (_session != null and bool(_session.state().get("busy", false))) \
		or (_codec != null and bool(_codec.state().get("busy", false))) or not _harvest.is_empty()


func retire_scene() -> void:
	for token: int in _pending_operations:
		if is_instance_valid(controller.wb.paint_editor): controller.wb.paint_editor.strata_stop(token)
	# Break Session -> adapter -> Session references explicitly on scene exit.
	_session = null
	_codec = null
	_harvest.clear()
	_results.clear()
	_pending_operations.clear()
	_preflight_play_setup.clear()
	_preview_serial += 1
	_preview = {"status":"idle", "busy":false, "can_approve":false, "cancellable":false,
		"token":"", "error":"Previous scene observations retired; prepare a fresh native preview.", "output_image":null}


func shutdown() -> void:
	retire_scene()
	if is_instance_valid(controller.wb.paint_editor) and controller.wb.paint_editor.strata_operation_finished.is_connected(_play_finished):
		controller.wb.paint_editor.strata_operation_finished.disconnect(_play_finished)
	_harvested.clear()


func _new_preview() -> bool:
	if busy():
		controller._refuse("Stop the active preparation or native prefix before starting another preview.")
		return false
	# Retire the old review BEFORE reading a new path or validating options.
	# A failed Preview B can never leave Preview A's approval token alive.
	_preview_serial += 1
	_session = null
	_codec = null
	_conversion_options.clear()
	_preflight_play_setup.clear()
	_preview = {"ok":false, "status":"idle", "busy":false, "can_approve":false,
		"cancellable":false, "token":"", "preview_serial":_preview_serial,
		"output_image":null, "source_image":null, "mask_image":null, "zero_writes":true}
	if not controller.enabled():
		_fail_preview("Enable Strata in Layers before importing or composing native geometry.")
		return false
	if controller.wb.busy():
		_fail_preview("Wait for the ordinary Workbench transaction before preparing a native preview.")
		return false
	controller.set_process(true)
	return true


func _fail_preview(message: String) -> Dictionary:
	_session = null
	_codec = null
	_preview.merge({"ok":false, "status":"refused", "busy":false, "cancellable":false,
		"can_approve":false, "token":"", "error":message, "output_image":null}, true)
	controller._refuse(message)
	return authoring_state()


func authoring_inspect_source(path: String) -> Dictionary:
	# Inspection is read-only and does not instantiate a decorative owner.
	return Codec.inspect_source(path, _materials())


func _read_png(path: String, expected_sha: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > Codec.MAX_PNG_BYTES:
		return _error("PNG source changed or exceeds its bounded input budget.")
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if Module.digest(bytes) != expected_sha: return _error("Source bytes changed after inspection; inspect the file again.")
	return {"ok":true, "bytes":bytes}


func preview_import(path: String, options: Dictionary) -> Dictionary:
	if not _new_preview(): return authoring_state()
	if not Module.keys(options, Codec.OPTION_KEYS + ["plane"], ["mask_path"]):
		return _fail_preview("Import contains unsupported or incomplete source/mapping controls.")
	if not options.get("plane") is String or options.plane not in Document.IDS:
		return _fail_preview("Choose one explicit native target plane.")
	var inspected: Dictionary = authoring_inspect_source(path)
	if not inspected.get("ok", false): return _fail_preview(str(inspected.get("error", "Source refused.")))
	if not controller.select_layer(str(options.plane)): return _fail_preview(controller.status_text())
	_preview.merge({"source_image":inspected.get("source_image"), "source_sha256":inspected.get("source_sha256", ""),
		"plane":str(options.plane), "source_path":path}, true)
	if inspected.kind == "native_module":
		# Native IDs never pass through raster sampling, palette distance or alpha.
		if not Module.integer(options.scale, 1, 1): return _fail_preview("Native material IDs cannot be resampled.")
		if not options.crop is Array or options.crop != [0,0,inspected.extent[0],inspected.extent[1]]:
			return _fail_preview("Native modules preserve their full exact grid. Harvest a smaller native region to create a new part.")
		if options.has("mask_path") and options.mask_path != "": return _fail_preview("Native modules carry their own exact no-write mask; external raster masks are not applied.")
		if not options.alpha_mode is String or options.alpha_mode not in ["overlay", "replace"]:
			return _fail_preview("Choose preserve or explicit clear for native no-write cells.")
		var placement := {"origin":options.get("origin", [0,0]), "transform":options.get("transform", "identity"),
			"empty_mode":"clear" if options.get("alpha_mode", "overlay") == "replace" else "preserve"}
		return _start_module(inspected.module, str(options.plane), placement)
	var raster_options := options.duplicate(true)
	raster_options.erase("plane")
	raster_options.erase("mask_path")
	var mask := PackedByteArray()
	var source: Dictionary = _read_png(path, str(inspected.source_sha256))
	if not source.get("ok", false): return _fail_preview(str(source.error))
	if options.has("mask_path"):
		if not options.mask_path is String: return _fail_preview("Choose an explicit local PNG mask.")
		var mask_checked: Dictionary = Codec.inspect_source(options.mask_path, _materials())
		if not mask_checked.get("ok", false) or mask_checked.get("kind", "") != "png": return _fail_preview("Mask source is not an admitted PNG.")
		var mask_source: Dictionary = _read_png(options.mask_path, str(mask_checked.source_sha256))
		if not mask_source.get("ok", false): return _fail_preview(str(mask_source.error))
		mask = mask_source.bytes
	_codec = Codec.new()
	_conversion_options = options.duplicate(true)
	var converted: Dictionary = _codec.begin_png(source.bytes, raster_options, _materials(), mask)
	if not converted.get("ok", false): return _fail_preview(str(converted.get("error", "Raster proposal refused.")))
	controller._say("Preparing a bounded material proposal; no native cells have been written.")
	return authoring_state()


func _start_module(module: Dictionary, plane: String, options: Dictionary) -> Dictionary:
	var planned: Dictionary = Plan.from_module(module, plane, options, authoring_plane_state(plane))
	if not planned.get("ok", false): return _fail_preview(str(planned.get("error", "Module placement refused.")))
	return _start_plan(planned.plan)


func _start_plan(plan: Dictionary) -> Dictionary:
	_session = Session.new()
	var started: Dictionary = _session.begin(self, plan, _materials())
	if not started.get("ok", false): return _fail_preview(str(started.get("error", "Native preview refused.")))
	controller._say("Reading the actual target planes for zero-write preview. Approval is required before construction.")
	return authoring_state()


func module_catalogue() -> Array:
	var entries: Array = Library.catalogue()
	for module: Dictionary in _harvested.values():
		entries.append({"id":module.id, "label":module.name + " · harvested", "name":module.name,
			"description":"Copied native materials; Empty defaults to no-write. Export to retain this reusable part."})
	return entries


func composition_catalogue() -> Array:
	return Library.composition_catalogue()


func import_fixture_catalogue() -> Array:
	return Library.fixture_catalogue()


func preview_module(id: String, options: Dictionary) -> Dictionary:
	if not _new_preview(): return authoring_state()
	if not Module.keys(options, ["plane", "origin"], ["transform", "palette", "empty_mode", "count", "step"]):
		return _fail_preview("Native placement has unsupported controls.")
	var plane: Variant = options.plane
	if not plane is String or plane not in Document.IDS: return _fail_preview("Choose an explicit native plane.")
	if not controller.select_layer(plane): return _fail_preview(controller.status_text())
	var loaded: Dictionary = Module.validate(_harvested[id], _materials()) if _harvested.has(id) else Library.module(id, _materials())
	if not loaded.get("ok", false): return _fail_preview(str(loaded.get("error", "Unknown native part.")))
	var placement := options.duplicate(true)
	for key: String in ["plane", "count", "step"]: placement.erase(key)
	var planned: Dictionary = Plan.from_module(loaded.module, plane, placement, authoring_plane_state(plane))
	if not planned.get("ok", false): return _fail_preview(str(planned.get("error", "Native placement refused.")))
	var count: Variant = options.get("count", 1)
	var step: Variant = options.get("step", [0, 0])
	if not Module.integer(count, 1, 16) or not Module.pair(step, -2048, 2048): return _fail_preview("Repeat uses 1–16 copies with an exact integer step.")
	var stage: Dictionary = planned.plan.stages[0]
	var origin := Vector2i(int(options.origin[0]), int(options.origin[1]))
	var region: Rect2i = Module.rectangle(stage.region)
	var base: Dictionary = stage.placements[0].duplicate(true)
	for index: int in range(1, int(count)):
		var position := origin + Vector2i(int(step[0]), int(step[1])) * index
		var copy := base.duplicate(true)
		copy.origin = [position.x, position.y]
		stage.placements.append(copy)
		region = region.merge(Rect2i(position, Module.rectangle(stage.region).size))
	stage.region = Module.rect_array(region)
	_preview.plane = plane
	_preview.source_image = Codec.module_image(loaded.module, _materials())
	return _start_plan(planned.plan)


func preview_composition(id: String, options: Dictionary) -> Dictionary:
	if not _new_preview(): return authoring_state()
	if not Module.keys(options, ["origin"]) or not Module.pair(options.origin, 0, 2047): return _fail_preview("Composition needs one explicit shared anchor.")
	var states := {}
	for plane: String in Document.IDS: states[plane] = authoring_plane_state(plane)
	var planned: Dictionary = Library.composition(id, Vector2i(int(options.origin[0]), int(options.origin[1])), states, _materials())
	if not planned.get("ok", false): return _fail_preview(str(planned.get("error", "Composition refused.")))
	var metadata: Dictionary = planned.plan.metadata.composition
	var visual: Dictionary = metadata.get("visual_proposal", {"planes":[],"presentation":{}}).duplicate(true)
	if not Module.keys(visual,["planes","presentation"]): return _fail_preview("Composition visual proposal contains unsupported fields.")
	visual.atmosphere = metadata.get("atmosphere_proposal",{}).get("configuration",controller.atmosphere_state()).duplicate(true)
	if not visual.atmosphere is Dictionary or not visual.atmosphere.get("effects") is Array:
		return _fail_preview("Composition atmosphere proposal is invalid.")
	for effect: Variant in visual.atmosphere.effects:
		if not effect is Dictionary or not effect.get("region") is Array or effect.region.size() != 4:
			return _fail_preview("Composition atmosphere region is invalid.")
		effect.region[0] += int(options.origin[0])
		effect.region[1] += int(options.origin[1])
	var prepared: Dictionary = controller.layer_owner.preview_visual_settings(visual)
	if not prepared.ok: return _fail_preview(str(prepared.error))
	# Review and hash the exact admitted representation, including canonical
	# float types in direction/colour arrays, rather than the source JSON types.
	visual.atmosphere = prepared.document.atmosphere.duplicate(true)
	for row: Dictionary in visual.planes:
		var admitted: Dictionary = Document.plane(prepared.document,row.id)
		row.opacity = admitted.opacity
		row.depth = admitted.depth
	for key: String in visual.presentation: visual.presentation[key] = prepared.document.presentation[key]
	_preview.visual_settings_proposal = visual
	_preview.visual_settings_token = Module.digest(Module.json_bytes({"source":planned.plan.source_sha256,
		"settings":visual,"serial":_preview_serial,"scene":states.scripted.scene_id}))
	_preview.visual_settings_applied = false
	_preview.visual_settings_original_sha256 = _visual_settings_identity()
	_preview.visual_settings_scene_id = states.scripted.scene_id
	_preview.visual_settings_summary = "%d layer opacity/depth settings, parallax %.2f, haze %.2f and %d presentation-only regions. This separate approval replaces the current atmosphere configuration; it writes no material cells." % [
		visual.planes.size(),float(visual.presentation.get("parallax_strength",controller.document().presentation.parallax_strength)),
		float(visual.presentation.get("fog_strength",controller.document().presentation.fog_strength)),visual.atmosphere.effects.size()]
	return _start_plan(planned.plan)


func _visual_settings_identity() -> String:
	var doc: Dictionary = controller.document()
	var rows: Array = []
	for id: String in ["scripted","effects","background"]:
		var row: Dictionary = Document.plane(doc,id)
		rows.append({"id":id,"opacity":row.opacity,"depth":row.depth})
	return Module.digest(Module.json_bytes({"planes":rows,"parallax":doc.presentation.parallax_strength,
		"haze":doc.presentation.fog_strength,"atmosphere":controller.atmosphere_state()}))


func _visual_settings_error() -> String:
	if _session == null or not _preview.has("visual_settings_proposal"): return "Preview a layered composition first."
	if _preview.get("visual_settings_applied",false): return "These reviewed visual settings have already been applied."
	var state: Dictionary = _session.state()
	if state.status != "completed": return "Complete and read back all native composition stages before applying visual settings."
	if _visual_settings_identity() != _preview.visual_settings_original_sha256: return "Visual settings changed after preview; review the composition again."
	var latest := {}
	for stage: Dictionary in state.stages: latest[stage.plane] = stage.after_revision
	for id: String in ["scripted","effects","background"]:
		var current := authoring_plane_state(id)
		if not current.ok or current.scene_id != _preview.visual_settings_scene_id: return "The reviewed composition belongs to a retired scene."
		if not current.paint_allowed: return "Show and unlock each decorative target before applying its preset settings."
		if latest.has(id) and current.revision != latest[id]: return "Native geometry changed after the completed composition; review again."
	return ""


func apply_composition_settings(token: String) -> Dictionary:
	if token.is_empty() or token != str(_preview.get("visual_settings_token","")): return _error("Approve the current exact visual settings proposal.")
	var error := _visual_settings_error()
	if not error.is_empty():
		controller._refuse(error)
		return _error(error)
	if not controller.layer_owner.apply_visual_settings(_preview.visual_settings_proposal): return _error(controller.layer_owner.last_error)
	controller._document = controller.layer_owner.document()
	_preview.visual_settings_applied = true
	var published: bool = controller.presenter.apply_document(controller._document)
	controller.presenter.sync_view()
	controller._say("Reviewed depth and atmosphere settings committed; authored geometry and Undo history are unchanged." if published else "Visual settings committed but display update failed; save and reopen the composition.")
	controller._refresh_panel()
	return {"ok":true,"published":published,"applied":true,"material_writes":0,"error":"" if published else controller.presenter.last_error}


func approve_plan(token: String) -> Dictionary:
	if _session == null: return _fail_preview("No current native preview is awaiting approval.")
	var result: Dictionary = _session.approve(token)
	controller._say("Native construction admitted; queued chunks count only after their actual owner ACK." if result.get("ok", false) else str(result.get("error", "Approval refused.")))
	return authoring_state()


func stop_authoring() -> Dictionary:
	if _codec != null:
		_preview.merge(_codec.cancel(), true)
		_codec = null
	if _session != null: _session.stop()
	if not _harvest.is_empty(): _harvest.stop = true
	for token: int in _pending_operations:
		controller.wb.paint_editor.strata_stop(token)
	if busy():
		controller._say("Stop requested. Any acknowledged native prefix remains explicit; readback and history finish before another job.")
	else:
		var stopped: Dictionary = authoring_state()
		controller._say("Native preview cancelled; no pending native writes." if stopped.get("status", "") == "cancelled" else "Native authoring: %s; no pending owner operation." % str(stopped.get("status", "idle")))
	return authoring_state()


func step() -> void:
	if _codec != null:
		var converted: Dictionary = _codec.step()
		_preview.merge(converted, true)
		if converted.get("status", "") == "ready":
			_codec = null
			_start_module(converted.module, str(_conversion_options.plane), {"origin":_conversion_options.origin, "transform":"identity", "empty_mode":"preserve"})
		elif not converted.get("busy", false):
			_codec = null
			_fail_preview(str(converted.get("error", "Raster proposal refused.")))
	elif _session != null and bool(_session.state().get("busy", false)):
		var previous_status: String = str(_session.state().get("status", ""))
		var current: Dictionary = _session.step()
		var current_status: String = str(current.get("status", ""))
		if current_status == "ready" and not _preview.has("composite_image"):
			_build_composite_preview()
		if current_status != previous_status:
			# The always-visible Workbench footer must agree with the actual
			# native session. Announce transitions once, never every frame.
			var message: String = str(current.get("error", ""))
			if message.is_empty(): message = str(current.get("message", ""))
			if message.is_empty():
				message = "Native construction complete: %d cells acknowledged and read back." % int(current.get("applied_cells", 0)) if current_status == "completed" else "Native authoring: %s; %d cells acknowledged." % [current_status, int(current.get("applied_cells", 0))]
			controller._say(message)
	elif not _harvest.is_empty(): _step_harvest()


func authoring_state() -> Dictionary:
	var state := _preview.duplicate(true)
	if _codec != null: state.merge(_codec.state(), true)
	if _session != null:
		state.merge(_session.state(), true)
		if _preview.get("source_image") is Image: state.source_image = _preview.source_image
	state.preview_serial = _preview_serial
	if state.get("error", "") == "": state.error = str(state.get("status", "idle"))
	state.harvested_modules = _harvested.keys()
	if _preview.has("visual_settings_proposal"):
		state.can_apply_visual_settings = _visual_settings_error().is_empty()
	return state


func _build_composite_preview() -> void:
	# Reuse the current copied material images. This is an explicitly labelled
	# native-ID proposal, not a GPU readback or the production palette shader.
	var projections: Array = _session.projections()
	if projections.is_empty(): return
	var bounds: Rect2i = Module.rectangle(projections[0].region)
	for projection: Dictionary in projections: bounds = bounds.merge(Module.rectangle(projection.region))
	var stride := maxi(1, int(ceil(maxi(bounds.size.x, bounds.size.y) / 256.0)))
	var size := Vector2i(int(ceil(bounds.size.x / float(stride))), int(ceil(bounds.size.y / float(stride))))
	var composite := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	composite.fill(Color.TRANSPARENT)
	var document: Dictionary = controller.document()
	var images := {"play":controller.wb.host.image}
	for id: String in ["scripted", "effects", "background"]:
		images[id] = controller.presenter._surfaces[id].cell_image
	var colours := {}
	var start := Time.get_ticks_usec()
	for id: String in ["background", "effects", "scripted", "play"]:
		var plane: Dictionary = Document.plane(document, id)
		if not controller.presenter.effective_visible(id): continue
		var source: Image = images[id]
		var local: Array = []
		for projection: Dictionary in projections:
			if projection.plane == id: local.append(projection)
		for y: int in size.y:
			for x: int in size.x:
				var point := bounds.position + Vector2i(x, y) * stride
				var material := int(round(source.get_pixelv(point).r * 255.0)) if source != null and Rect2i(Vector2i.ZERO, source.get_size()).has_point(point) else 0
				for projection: Dictionary in local:
					var region: Rect2i = Module.rectangle(projection.region)
					if region.has_point(point): material = projection.after[(point.y - region.position.y) * region.size.x + point.x - region.position.x]
				if material == 0: continue
				if not colours.has(material): colours[material] = Codec._colour(material)
				var colour: Color = colours[material]
				colour.a *= float(plane.opacity)
				composite.set_pixel(x, y, composite.get_pixel(x, y).blend(colour))
	_preview.composite_image = composite
	_preview.composite_region = Module.rect_array(bounds)
	_preview.composite_sampling_stride = stride
	_preview.composite_usec = Time.get_ticks_usec() - start
	_preview.composite_scope = "Native ID proposal and current copied context; fixed plane order/visibility/opacity. One displayed sample per %d native cells. Depth, haze, glow and atmosphere are inspected in Workbench after approval." % stride


func harvest_module(plane: String, raw_region: Array, title: String) -> Dictionary:
	if not _new_preview(): return authoring_state()
	if plane not in Document.IDS or title.strip_edges().is_empty() or title.length() > 128:
		return _fail_preview("Choose an explicit plane and a part name of 1–128 characters.")
	var region: Rect2i = Module.rectangle(raw_region)
	var state := authoring_plane_state(plane)
	if not state.get("ok", false): return _fail_preview(str(state.get("error", "Target unavailable.")))
	if not controller.select_layer(plane): return _fail_preview(controller.status_text())
	state = authoring_plane_state(plane)
	if not state.paint_allowed or int(state.remaining_authoring_records) < 1 or int(state.remaining_authoring_bytes) < 4096:
		return _fail_preview("Harvest needs a visible unlocked plane and room for its source receipt.")
	if region.get_area() < 1 or region.size.x < 1 or region.size.y < 1 or region.get_area() > 262144 \
			or not Rect2i(Vector2i.ZERO, Vector2i(int(state.extent[0]), int(state.extent[1]))).encloses(region):
		return _fail_preview("Harvest an in-bounds native region of at most 262144 cells.")
	var tiles: Array[Rect2i] = []
	for y: int in range(region.position.y, region.end.y, 64):
		for x: int in range(region.position.x, region.end.x, 64):
			tiles.append(Rect2i(x, y, mini(64, region.end.x - x), mini(64, region.end.y - y)))
	var cells := PackedByteArray()
	cells.resize(region.get_area() * 2)
	_harvest = {"plane":plane, "region":region, "title":title.strip_edges(), "expected":state,
		"tiles":tiles, "index":0, "cells":cells, "pending":0, "stop":false}
	_preview.merge({"ok":true, "status":"harvesting", "busy":true, "cancellable":true,
		"processed":0, "total":region.get_area(), "plane":plane, "region":raw_region.duplicate(),
		"can_approve":false, "error":"Copying actual native materials; no cells will be written."}, true)
	return authoring_state()


func _step_harvest() -> void:
	var job: Dictionary = _harvest
	var receipt := {}
	if int(job.pending) > 0:
		receipt = authoring_poll(int(job.pending))
		if receipt.is_empty(): return
		job.pending = 0
	elif job.stop:
		_harvest.clear()
		_preview.merge({"status":"cancelled", "busy":false, "cancellable":false, "error":"Harvest stopped; no native cells were written."}, true)
		return
	elif int(job.index) >= job.tiles.size():
		_finish_harvest()
		return
	else:
		receipt = authoring_capture(str(job.plane), job.tiles[int(job.index)], job.expected)
		if receipt.get("pending", false):
			job.pending = int(receipt.operation_id)
			return
	if not receipt.get("ok", false):
		_harvest.clear()
		_fail_preview(str(receipt.get("error", "Native harvest refused.")))
		return
	var tile: Rect2i = job.tiles[int(job.index)]
	var region: Rect2i = job.region
	if receipt.get("status", "") != "completed" or receipt.get("region") != tile \
			or receipt.get("owner_id", "") != job.expected.owner_id \
			or int(receipt.get("generation", -1)) != int(job.expected.generation) \
			or int(receipt.get("authored_revision", -1)) != int(job.expected.revision) \
			or int(receipt.get("authored_serial", -1)) != int(job.expected.authored_serial):
		_harvest.clear()
		_fail_preview("Stale or misdirected native harvest receipt; no reusable part was adopted.")
		return
	var materials: Variant = receipt.get("materials")
	if not materials is PackedInt32Array or materials.size() != tile.get_area():
		_harvest.clear()
		_fail_preview("Incomplete native harvest receipt.")
		return
	for index: int in materials.size():
		var local := tile.position - region.position + Vector2i(index % tile.size.x, index / tile.size.x)
		job.cells.encode_u16((local.y * region.size.x + local.x) * 2, materials[index])
	_preview.processed = int(_preview.processed) + materials.size()
	job.index = int(job.index) + 1


func _finish_harvest() -> void:
	var job: Dictionary = _harvest
	_harvest = {}
	var fence_error := _fence_error(str(job.plane), job.expected)
	if not fence_error.is_empty(): _fail_preview(fence_error); return
	var region: Rect2i = job.region
	var mask := PackedByteArray()
	mask.resize(region.get_area())
	for index: int in mask.size(): mask[index] = 1 if job.cells.decode_u16(index * 2) != 0 else 0
	var native_sha: String = Module.digest(job.cells)
	var id := "harvest-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var source := {"source_kind":"native-harvest", "source_sha256":native_sha,
		"scene_id":job.expected.scene_id, "owner_id":job.expected.owner_id, "plane":job.plane,
		"generation":job.expected.generation, "revision":job.expected.revision,
		"region":Module.rect_array(region), "empty_policy":"Empty captured as zero, no-write mask by default; explicit clear is a separate placement choice.",
		"scope":"Copied authored native material occupancy; no actor, physical continuation or structural solver."}
	var built: Dictionary = Module.create(id, str(job.title), region.size, job.cells, mask, source, _materials())
	if not built.get("ok", false): _fail_preview(str(built.get("error", "Harvest module refused."))); return
	var record := {"version":1, "id":id, "kind":"harvest", "plane":job.plane,
		"scene_id":job.expected.scene_id, "owner_id":job.expected.owner_id, "generation":job.expected.generation,
		"before_revision":job.expected.revision, "after_revision":job.expected.revision,
		"status":"completed", "requested_cells":0, "applied_cells":0, "changed_cells":0,
		"requested_chunks":0, "completed_chunks":0, "source_sha256":native_sha,
		"proposal_sha256":built.module.content_sha256, "geometry_sha256":built.module.geometry.sha256,
		"before_sha256":native_sha, "projected_sha256":native_sha, "actual_sha256":native_sha,
		"published":true, "metadata":source, "error":"", "historical":true,
		"scope":"authored-material-operation-history"}
	var saved := authoring_record(record)
	if not saved.get("ok", false): _fail_preview(str(saved.get("error", "Harvest source receipt refused."))); return
	_harvested[id] = built.module
	_preview.merge({"ok":true, "status":"completed", "busy":false, "cancellable":false, "can_approve":false,
		"output_image":Codec.module_image(built.module, _materials()), "module_id":id,
		"geometry_sha256":built.module.geometry.sha256, "source_sha256":native_sha,
		"error":"Native part copied with no material writes. Choose it in Compose or Export to retain the reusable module."}, true)
	controller._say(str(_preview.error))


func export_module(id: String, path: String) -> Dictionary:
	var loaded: Dictionary = Module.validate(_harvested[id], _materials()) if _harvested.has(id) else Library.module(id, _materials())
	if not loaded.get("ok", false): return _error(str(loaded.get("error", "Unknown native part.")))
	if path.is_empty() or path.get_extension().to_lower() != "json": return _error("Choose a local .json module destination.")
	var bytes: PackedByteArray = Module.json_bytes(loaded.module)
	var temporary := path + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _error("Could not create a module export beside the chosen destination.")
	file.store_buffer(bytes)
	file.flush()
	var complete: bool = file.get_error() == OK and file.get_position() == bytes.size()
	file.close()
	if not complete:
		DirAccess.remove_absolute(temporary)
		return _error("Module export failed; previous destination retained.")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var replaced: Dictionary = bridge.replace_material_baseline_file(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if not replaced.get("ok", false):
		DirAccess.remove_absolute(temporary)
		return _error("Atomic module replacement refused: " + str(replaced.get("error", "")))
	controller._say("Exported exact native module and source provenance · " + path.get_file())
	return {"ok":true, "path":path, "sha256":Module.digest(bytes), "content_sha256":loaded.module.content_sha256, "error":""}
