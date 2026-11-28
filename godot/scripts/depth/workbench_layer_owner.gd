extends RefCounted

## Adapted from DepthLayerRuntime's private-candidate/adopt/copied-publication
## ownership pattern. The ordinary asynchronous owner keeps the only play World.
## This owner constructs exactly three static native decorative Worlds, without
## actors, cross-plane commands, simulation ticks or a second play authority.
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const PaintExecutor = preload("res://scripts/workbench_paint_editor_executor.gd")
const PaintHistory = preload("res://scripts/workbench_paint_editor_history.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const IDS := ["scripted", "effects", "background"]
const MAX_EDIT_CELLS := 16384
const MAX_HISTORY := 32

var last_error := ""
var _document: Dictionary = {}
var _worlds: Dictionary = {}
var _pending: Dictionary = {}
var _cache: Dictionary = {}
var _dirty: Dictionary = {}
var _published: Dictionary = {}
var _failed: Dictionary = {}
var _undo: Dictionary = {}
var _redo: Dictionary = {}
var _generation := 0
var _token_serial := 0
var _operation_serial := 0
var _session_id := Crypto.new().generate_random_bytes(16).hex_encode()
var _native_materials := PackedInt32Array()
var _snapshot_calls := 0
var _cache_hits := 0
var _construction_usec := 0
var _edit_usec := 0
var _retired_worlds := 0


func generation() -> int:
	return _generation


func document() -> Dictionary:
	return _document.duplicate(true)


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "accepted": false, "error": message, "generation": _generation}


func _copy_packet(packet: Dictionary) -> Dictionary:
	var copied := packet.duplicate(true)
	if copied.get("cells") is PackedByteArray: copied.cells = copied.cells.duplicate()
	if copied.get("rectangles") is PackedInt32Array: copied.rectangles = copied.rectangles.duplicate()
	return copied


func _owner_id(id: String, owner_generation: int = -1) -> String:
	return "%s:%d:%s" % [_session_id, _generation if owner_generation < 0 else owner_generation, id]


func _decorate(packet: Dictionary, id: String, scene: Dictionary, owner_generation: int, serial: int) -> Dictionary:
	var row := Document.plane(scene, id)
	packet.layer_id = id
	packet.owner_id = _owner_id(id, owner_generation)
	packet.generation = owner_generation
	packet.reset_generation = owner_generation
	packet.revision = int(row.revision)
	packet.extent = Document.extent_of(scene)
	packet.layer_tick = 0
	packet.serial = serial
	packet.unchanged = false
	return packet


func prepare(candidate: Dictionary, expected_generation: int = -1) -> Dictionary:
	if not _pending.is_empty(): return _error("A Strata candidate is already prepared; commit or cancel it first.")
	if expected_generation != -1 and expected_generation != _generation:
		return _error("Stale Strata candidate generation.")
	if not _document.is_empty() and expected_generation == -1:
		return _error("Replacing Strata requires the current generation.")
	var error := Document.validate(candidate)
	if not error.is_empty(): return _error(error)
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		return _error("Strata requires the current CyberNativeCellWorld extension.")
	if _native_materials.is_empty(): _native_materials = PaintExecutor.native_materials()
	if _native_materials.is_empty(): return _error("The native material catalogue is unavailable.")
	var started := Time.get_ticks_usec()
	var scene := Document.canonical(candidate)
	var extent := Document.extent_of(scene)
	var worlds: Dictionary = {}
	var packets: Dictionary = {}
	for id: String in IDS:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		if world == null or not world.has_method(&"diagnostic_reset") \
				or not world.has_method(&"stored_material_at"):
			return _error("The native Strata material adapter is unavailable.")
		if not world.diagnostic_reset({"extent": extent, "workers": 1, "telemetry": false}):
			return _error("Could not prepare the native %s plane." % id)
		world.set_cadence_lod_enabled(false)
		world.set_simulation_window(Vector2i.ZERO, extent, 16, 16)
		world.set_simulation_window_enabled(true)
		for rectangle: Array in Document.plane(scene, id).rectangles:
			if not world.diagnostic_fill_rect(Vector2i(rectangle[0], rectangle[1]),
					Vector2i(rectangle[2], rectangle[3]), int(rectangle[4])):
				return _error("Native preparation rejected the complete %s layout." % id)
		if world.has_failed(): return _error("The candidate %s plane entered native quarantine." % id)
		var packet: Dictionary = _take_snapshot(world)
		_snapshot_calls += 1
		if bool(packet.get("failed", false)) or not packet.get("cells") is PackedByteArray \
				or not packet.get("rectangles") is PackedInt32Array \
				or packet.cells.size() != extent.x * extent.y * 2 \
				or int(packet.get("channels", 0)) != 2 or not packet.get("full_refresh", false):
			return _error("Native preparation did not publish a complete %s material plane." % id)
		worlds[id] = world
		packets[id] = _decorate(packet, id, scene, _generation + 1, 1)
	_token_serial += 1
	_pending = {"token": _token_serial, "expected_generation": _generation,
		"document": scene, "worlds": worlds, "packets": packets}
	_construction_usec = Time.get_ticks_usec() - started
	last_error = ""
	return {"ok": true, "token": _token_serial, "generation": _generation,
		"candidate_generation": _generation + 1, "extent": extent,
		"construction_usec": _construction_usec}


func commit(token: int) -> bool:
	# All fallible construction and initial publications precede this boundary.
	# Root commits only after the existing play owner has acknowledged its own
	# authored-start transaction; this method allocates no additional native owner.
	if _pending.is_empty() or token != int(_pending.token) \
			or int(_pending.expected_generation) != _generation:
		last_error = "Stale or cancelled Strata candidate token."
		return false
	_retired_worlds += _worlds.size()
	_worlds = _pending.worlds
	_document = _pending.document
	_cache = _pending.packets
	_generation += 1
	_pending = {}
	_dirty = {}
	_published = {}
	_failed = {}
	_undo = {}
	_redo = {}
	for id: String in IDS:
		_dirty[id] = false
		_published[id] = false
		_undo[id] = []
		_redo[id] = []
	last_error = ""
	return true


func candidate_packets(token: int) -> Dictionary:
	# Allows the presentation owner to validate/allocate all surfaces before the
	# ordinary play transaction. No candidate World escapes its exclusive owner.
	if _pending.is_empty() or token != int(_pending.token): return {}
	var result: Dictionary = {}
	for id: String in IDS: result[id] = _copy_packet(_pending.packets[id])
	return result


func prepared_packets(token: int) -> Dictionary:
	return candidate_packets(token)


func cancel(token: int = -1) -> void:
	if _pending.is_empty() or (token != -1 and token != int(_pending.token)): return
	_retired_worlds += _pending.worlds.size()
	_pending = {}


func retire() -> void:
	cancel()
	_retired_worlds += _worlds.size()
	_worlds = {}
	_document = {}
	_cache = {}
	_dirty = {}
	_published = {}
	_failed = {}
	_undo = {}
	_redo = {}
	_generation += 1


func update_settings(id: String, patch: Dictionary) -> bool:
	if _document.is_empty() or id not in Document.IDS:
		last_error = "Unknown Strata plane."
		return false
	for key: Variant in patch:
		if key not in ["visible", "locked", "opacity", "depth", "clock"]:
			last_error = "A settings edit cannot change a plane's identity or authored layout."
			return false
	var candidate := _document.duplicate(true)
	var row := Document.plane(candidate, id)
	for key: Variant in patch: row[key] = patch[key].duplicate(true) if patch[key] is Dictionary else patch[key]
	last_error = Document.validate(candidate)
	if not last_error.is_empty(): return false
	_document = candidate
	return true


func set_presentation(patch: Dictionary) -> bool:
	if _document.is_empty():
		last_error = "Strata has not been initialized."
		return false
	for key: Variant in patch:
		if key not in Document.PRESENTATION_KEYS:
			last_error = "Unknown Strata presentation field."
			return false
	var candidate := _document.duplicate(true)
	for key: Variant in patch: candidate.presentation[key] = patch[key]
	last_error = Document.validate(candidate)
	if not last_error.is_empty(): return false
	_document = candidate
	return true


func update_extensions(patch: Dictionary) -> bool:
	if _document.is_empty() or not _pending.is_empty():
		last_error = "Finish scene preparation before changing authored extensions."
		return false
	for key: Variant in patch:
		if key not in Document.EXTENSION_KEYS:
			last_error = "An extension edit cannot change native geometry or plane ownership."
			return false
	var candidate := Document.upgraded(_document)
	for key: Variant in patch: candidate[key] = patch[key].duplicate(true) if patch[key] is Dictionary else patch[key]
	last_error = Document.validate(candidate)
	if not last_error.is_empty(): return false
	_document = Document.canonical(candidate)
	return true


func set_optics(configuration: Dictionary) -> bool:
	# Settings-only commit: no native call, publication, history or revision edit.
	if _document.is_empty() or not _pending.is_empty():
		last_error = "Finish scene preparation before changing optical settings."
		return false
	last_error = Document.Optics.validate(configuration)
	if not last_error.is_empty(): return false
	# The admitted private document already has valid geometry. Live sliders
	# replace only a copied optical value; do not rescan/copy every rectangle.
	if int(_document.version) == Document.LEGACY_VERSION:
		_document = Document.upgraded(_document)
	_document.version = Document.OPTICAL_VERSION
	_document.optics = Document.Optics.canonical(configuration)
	return true


func preview_visual_settings(patch: Dictionary) -> Dictionary:
	# Validate one complete visual candidate before adopting any settings. This
	# operation cannot replace native layouts, owners, revision or history.
	if _document.is_empty() or not _pending.is_empty():
		return {"ok":false,"error":"Finish scene admission before preparing visual settings."}
	if not Module.keys(patch,["planes","presentation","atmosphere"]) \
			or not patch.planes is Array or patch.planes.size() > 3 or not patch.presentation is Dictionary:
		return {"ok":false,"error":"Visual settings have unsupported fields."}
	var candidate := Document.upgraded(_document)
	var seen := {}
	for item: Variant in patch.planes:
		if not Module.keys(item,["id","opacity","depth"]) or item.id not in IDS or seen.has(item.id):
			return {"ok":false,"error":"A visual preset must name unique decorative planes and only opacity/depth."}
		seen[item.id] = true
		var row := Document.plane(candidate,item.id)
		row.opacity = item.opacity
		row.depth = item.depth
	for key: Variant in patch.presentation:
		if key not in ["parallax_strength","fog_strength"]:
			return {"ok":false,"error":"A visual preset cannot change edit target, mode or visibility."}
		candidate.presentation[key] = patch.presentation[key]
	candidate.atmosphere = patch.atmosphere.duplicate(true) if patch.atmosphere is Dictionary else patch.atmosphere
	var error := Document.validate(candidate)
	return {"ok":error.is_empty(),"error":error,"document":Document.canonical(candidate) if error.is_empty() else {}}


func apply_visual_settings(patch: Dictionary) -> bool:
	var prepared := preview_visual_settings(patch)
	last_error = str(prepared.error)
	if not prepared.ok: return false
	_document = prepared.document
	return true


func _make_executor() -> RefCounted:
	# A narrow factory lets mounted test subclasses exercise containment with
	# actual native prefixes. Production always uses the existing paint executor.
	return PaintExecutor.new()


func _take_snapshot(world: Object) -> Dictionary:
	return world.take_render_snapshot(true)


func _visibility_error(id: String) -> String:
	if _document.is_empty() or id not in IDS or not _worlds.has(id):
		return "Decorative authoring requires one of the three initialized native planes."
	if _failed.has(id): return str(_failed[id])
	if _worlds[id].has_failed(): return "This native plane is quarantined; reload its retained authored composition."
	var row := Document.plane(_document, id)
	var presentation: Dictionary = _document.presentation
	if not presentation.enabled or not row.visible or float(row.opacity) <= 0.0 \
			or (presentation.solo != "" and presentation.solo != id) \
			or (presentation.mode == "flat" and presentation.active != id):
		return "Hidden or solo-filtered planes cannot receive edits or copied selections."
	return ""


func edit_error(id: String) -> String:
	var error := _visibility_error(id)
	if not error.is_empty(): return error
	if bool(Document.plane(_document, id).locked): return "This plane is locked."
	if not _pending.is_empty(): return "Finish or cancel the prepared Strata composition first."
	return ""


func can_edit(id: String) -> bool:
	return edit_error(id).is_empty()


func _context(world: Object) -> Dictionary:
	return {"epoch": _generation, "generation": _generation, "authoring_generation": _generation,
		"tick": int(world.get_tick_index()), "revision": int(world.revision), "settings_revision": 0,
		"paused": true, "paint_allowed": true, "erase_allowed": true, "error": ""}


func _run(id: String, kind: String, cells: PackedInt32Array, region: Rect2i,
		expected: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var world: Object = _worlds[id]
	var context := _context(world)
	_operation_serial += 1
	var request := {"kind": kind, "expected_generation": _generation,
		"expected_authoring_generation": _generation, "expected_revision": context.revision,
		"expected_tick": context.tick}
	if kind == "capture": request.region = region
	else:
		request.cells = cells.duplicate()
		if not expected.is_empty(): request.expected_before = expected.duplicate()
	var error := PaintExecutor.request_error(request)
	if not error.is_empty(): return _error(error)
	request._epoch = _generation
	request._settings_revision = 0
	request.operation_id = _operation_serial
	var executor: RefCounted = _make_executor()
	executor.begin(request, Document.extent_of(_document), _native_materials)
	var receipt: Dictionary = {}
	# Existing executor retains its 4096-cell validation/application slices. The
	# caller's smaller 16384-cell admission bounds this synchronous static edit.
	for _slice: int in 10:
		receipt = executor.step(world, context)
		if not receipt.is_empty(): break
	if receipt.is_empty(): return _error("The bounded native layer operation did not terminate.")
	receipt.ok = receipt.status == "completed"
	receipt.accepted = receipt.ok
	receipt.owner_id = _owner_id(id)
	receipt.layer_id = id
	receipt.error = str(receipt.get("reason", ""))
	if not receipt.ok and int(receipt.get("applied", 0)) > 0:
		_failed[id] = "Native layer edit was partial; reload the retained authored composition before continuing."
	_edit_usec = int(receipt.get("elapsed_usec", 0))
	return receipt


func paint_disc(id: String, cell: Vector2i, radius: int, material: int) -> Dictionary:
	if _document.is_empty(): return _error("Strata has not been initialized.")
	var planned := Shapes.line(cell, cell, radius, Document.extent_of(_document), MAX_EDIT_CELLS)
	if not planned.accepted: return _error(str(planned.error))
	if planned.get("clipped", false): return _error("The complete brush must fit inside the selected plane.")
	var triples := PackedInt32Array()
	triples.resize(planned.count * 3)
	for index: int in int(planned.count):
		triples[index * 3] = planned.cells[index * 2]
		triples[index * 3 + 1] = planned.cells[index * 2 + 1]
		triples[index * 3 + 2] = material
	return paint_cells(id, triples, _generation)


func paint_cells(id: String, cells: PackedInt32Array, expected_generation: int = -1, expected_before: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var error := edit_error(id)
	if not error.is_empty(): return _error(error)
	if expected_generation != -1 and expected_generation != _generation:
		return _error("The layer edit belongs to a retired generation.")
	if cells.is_empty() or cells.size() % 3 != 0 or cells.size() / 3 > MAX_EDIT_CELLS:
		return _error("A decorative edit admits at most 16384 exact cell/material triplets.")
	var row := Document.plane(_document, id)
	if int(row.revision) >= Document.MAX_REVISION: return _error("Layer revision capacity exhausted.")
	var encoded := PaintHistory.stamps(cells, Document.extent_of(_document))
	if not encoded.accepted: return _error(str(encoded.error))
	var candidate := _document.duplicate(true)
	var candidate_row := Document.plane(candidate, id)
	var previous_count: int = candidate_row.rectangles.size()
	candidate_row.rectangles.append_array(encoded.stamps)
	candidate_row.revision = int(candidate_row.revision) + 1
	error = Document.validate(candidate)
	if not error.is_empty(): return _error(error)
	var receipt := _run(id, "edit", cells, Rect2i(), expected_before)
	if not receipt.get("ok", false): return receipt
	_document = candidate
	_dirty[id] = true
	_undo[id].append({"cells": cells.duplicate(), "before": receipt.before.duplicate(),
		"after": receipt.after.duplicate(), "stamps": encoded.stamps.duplicate(true),
		"previous_count": previous_count})
	if _undo[id].size() > MAX_HISTORY: _undo[id].pop_front()
	_redo[id].clear()
	receipt.authored_revision = int(candidate_row.revision)
	last_error = ""
	return receipt


func capture_region(id: String, region: Rect2i) -> Dictionary:
	var error := _visibility_error(id)
	if not error.is_empty(): return _error(error)
	if region.size.x <= 0 or region.size.y <= 0 or region.size.x * region.size.y > MAX_EDIT_CELLS \
			or not Rect2i(Vector2i.ZERO, Document.extent_of(_document)).encloses(region):
		return _error("A copied decorative selection must fit inside the plane and contain at most 16384 cells.")
	var receipt := _run(id, "capture", PackedInt32Array(), region)
	receipt.extent = Document.extent_of(_document)
	receipt.authored_revision = int(Document.plane(_document, id).revision)
	return receipt


func _history(id: String, redo_action: bool) -> Dictionary:
	var error := edit_error(id)
	if not error.is_empty(): return _error(error)
	var source: Array = _redo[id] if redo_action else _undo[id]
	if source.is_empty(): return _error("No decorative %s operation is available." % ("Redo" if redo_action else "Undo"))
	var entry: Dictionary = source.back()
	var candidate := _document.duplicate(true)
	var row := Document.plane(candidate, id)
	if int(row.revision) >= Document.MAX_REVISION: return _error("Layer revision capacity exhausted.")
	var required_count: int = int(entry.previous_count) + (0 if redo_action else entry.stamps.size())
	if row.rectangles.size() != required_count:
		return _error("Decorative authored history no longer matches this operation.")
	if redo_action: row.rectangles.append_array(entry.stamps.duplicate(true))
	else: row.rectangles.resize(int(entry.previous_count))
	row.revision = int(row.revision) + 1
	error = Document.validate(candidate)
	if not error.is_empty(): return _error(error)
	var triples: PackedInt32Array = entry.cells.duplicate()
	var desired: PackedInt32Array = entry.after if redo_action else entry.before
	for index: int in desired.size(): triples[index * 3 + 2] = desired[index]
	var receipt := _run(id, "edit", triples, Rect2i(), entry.before if redo_action else entry.after)
	if not receipt.get("ok", false): return receipt
	source.pop_back()
	var destination: Array = _undo[id] if redo_action else _redo[id]
	destination.append(entry)
	_document = candidate
	_dirty[id] = true
	receipt.authored_revision = int(row.revision)
	last_error = ""
	return receipt


func undo(id: String) -> Dictionary:
	return _history(id, false)


func redo(id: String) -> Dictionary:
	return _history(id, true)


func material_at(id: String, cell: Vector2i) -> int:
	if not _worlds.has(id) or not Rect2i(Vector2i.ZERO, Document.extent_of(_document)).has_point(cell): return -1
	return int(_worlds[id].stored_material_at(cell.x, cell.y))


func snapshot_layer(id: String, force: bool = false) -> Dictionary:
	if not _worlds.has(id): return {"failed": true, "error": "Unknown decorative plane."}
	if _failed.has(id): return {"failed": true, "error": _failed[id], "layer_id": id,
		"owner_id": _owner_id(id), "generation": _generation}
	if _dirty.get(id, false):
		var packet: Dictionary = _take_snapshot(_worlds[id])
		_snapshot_calls += 1
		if bool(packet.get("failed", false)):
			_failed[id] = str(packet.get("error", "Native publication failed."))
			return {"failed": true, "error": _failed[id], "layer_id": id}
		_cache[id] = _decorate(packet, id, _document, _generation, int(_cache[id].serial) + 1)
		_dirty[id] = false
		_published[id] = false
	if not force and _published.get(id, false):
		_cache_hits += 1
		return {"failed": false, "unchanged": true, "layer_id": id, "owner_id": _owner_id(id),
			"generation": _generation, "reset_generation": _generation,
			"revision": int(Document.plane(_document, id).revision), "extent": Document.extent_of(_document),
			"serial": int(_cache[id].serial), "channels": 2, "full_refresh": false,
			"layer_tick": 0, "rectangles": PackedInt32Array(), "cells": PackedByteArray()}
	_published[id] = true
	return _copy_packet(_cache[id])


func stats() -> Dictionary:
	var layers: Dictionary = {}
	for id: String in IDS:
		if not _worlds.has(id): continue
		var world: Object = _worlds[id]
		layers[id] = {"owner_id": _owner_id(id), "native_instance_id": world.get_instance_id(),
			"native_tick": int(world.get_tick_index()), "native_revision": int(world.revision),
			"revision": int(Document.plane(_document, id).revision), "ready": not _failed.has(id),
			"failed": _failed.has(id), "error": _failed.get(id, ""), "clock_mode": "static", "rate_hz": 0,
			"paused": true, "dirty": bool(_dirty[id]), "undo": _undo[id].size(), "redo": _redo[id].size(),
			"publication_serial": int(_cache[id].serial), "cached_bytes": _cache[id].cells.size()}
	return {"session_id": _session_id, "generation": _generation, "native_world_count": _worlds.size(),
		"owns_play_world": false, "pending_native_world_count": 0 if _pending.is_empty() else _pending.worlds.size(),
		"pending_token": -1 if _pending.is_empty() else int(_pending.token), "retired_worlds": _retired_worlds,
		"native_snapshot_calls": _snapshot_calls, "cache_hits": _cache_hits,
		"construction_usec": _construction_usec, "last_edit_usec": _edit_usec, "layers": layers}
