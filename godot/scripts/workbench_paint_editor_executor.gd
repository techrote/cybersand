extends RefCounted

## Bounded value-only construction operation, called only by the existing
## CyberSimulationWorker owner. No native World escapes in a result.
## Single pending operation / consumed receipt follows WB-ART-002's lifecycle;
## caller material and source-protection policies remain independent.
const MAX_CELLS: int = 262144
const SLICE_CELLS: int = 4096
const MAX_GUARDS: int = 64

var command: Dictionary = {}
var status: String = "idle"
var checked: int = 0
var applied: int = 0
var changed: int = 0
var count: int = 0
var slices: int = 0
var maximum_slice_usec: int = 0
var _cells := PackedInt32Array()
var _before := PackedInt32Array()
var _after := PackedInt32Array()
var _expected := PackedInt32Array()
var _allowed := PackedByteArray()
var _bounds: Rect2i
var _region: Rect2i
var _guards: Array = []
var _source_allowed := PackedInt32Array()
var _last_key: int = -1
var _revision: int = -1
var _started_usec: int = 0
var _slice_started_usec: int = 0


static func native_materials() -> PackedInt32Array:
	# Compiled interaction inspection validates the complete byte domain. Tool
	# slots, appearance tables and the shadow catalogue grant no native authority.
	var result := PackedInt32Array()
	if not ClassDB.class_exists(&"CyberDemoBridge"): return result
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"inspect_interaction"): return result
	for id: int in range(256):
		var row: Dictionary = bridge.inspect_interaction(id, id, 0)
		if row.get("ok", false): result.append(id)
	return result


static func request_error(request: Dictionary) -> String:
	for key: Variant in request:
		if key not in ["kind","cells","region","rect","expected_generation","expected_revision","expected_tick","expected_authoring_generation","expected_before","protected","source_allowed"]:
			return "Unknown paint request field."
	if request.get("kind", "") not in ["edit", "capture"]:
		return "Unknown paint request."
	for field: String in ["expected_generation", "expected_revision", "expected_tick"]:
		if not request.get(field) is int or int(request[field]) < 0:
			return "A current native generation, revision and tick are required."
	if request.has("expected_authoring_generation") and (not request.expected_authoring_generation is int \
			or int(request.expected_authoring_generation) < 1):
		return "A current authored-baseline generation is required."
	var guards: Variant = request.get("protected", [])
	if not guards is Array or guards.size() > MAX_GUARDS:
		return "Protection rectangle capacity exceeded."
	for guard: Variant in guards:
		if not guard is Rect2i or guard.size.x < 0 or guard.size.y < 0:
			return "Invalid protection rectangle."
	if request.has("source_allowed") and (not request.source_allowed is PackedInt32Array \
		or request.source_allowed.size() > 256):
		return "Source material policy must contain at most 256 native IDs."
	if request.kind == "capture":
		if request.has("cells") or request.has("expected_before"):
			return "Capture accepts only its bounded rectangle, not edit payloads."
		if request.has("rect") and (not request.rect is Rect2i or request.rect != request.get("region")):
			return "Conflicting native capture rectangles."
		if not request.get("region") is Rect2i: return "A native capture rectangle is required."
		var region: Rect2i = request.region
		if region.size.x <= 0 or region.size.y <= 0 or region.size.x > 2048 or region.size.y > 2048 \
			or region.size.x * region.size.y > MAX_CELLS:
			return "Capture exceeds the 262144-cell operation budget."
	else:
		if request.has("region") or request.has("rect"):
			return "An edit contains exact cells, not a capture rectangle."
		if not request.get("cells") is PackedInt32Array:
			return "Paint cells must be exact integer x/y/material triples."
		var values: PackedInt32Array = request.cells
		if values.is_empty() or values.size() % 3 != 0 or values.size() / 3 > MAX_CELLS:
			return "Paint exceeds the 262144-cell operation budget."
		if request.has("expected_before") and (not request.expected_before is PackedInt32Array \
			or request.expected_before.size() != values.size() / 3):
			return "Undo source values do not cover the complete operation."
	return ""


func begin(request: Dictionary, extent: Vector2i, materials: PackedInt32Array) -> void:
	command = request
	_cells = request.get("cells", PackedInt32Array())
	_region = request.get("region", Rect2i())
	_bounds = Rect2i(Vector2i.ZERO, extent)
	_guards = request.get("protected", [])
	_source_allowed = request.get("source_allowed", PackedInt32Array())
	_expected = request.get("expected_before", PackedInt32Array())
	count = _region.size.x * _region.size.y if request.kind == "capture" else _cells.size() / 3
	_before.resize(count)
	_after.resize(count)
	_allowed.resize(256)
	_allowed.fill(0)
	for id: int in materials:
		if id >= 0 and id < 256: _allowed[id] = 1
	_revision = int(request.expected_revision)
	_started_usec = Time.get_ticks_usec()
	status = "capturing" if request.kind == "capture" else "validating"


func progress() -> Dictionary:
	return {"status": status, "operation_id": int(command.get("operation_id",0)), "checked": checked, "applied": applied,
		"changed": changed, "requested_cells": count, "slices": slices}


func _point(index: int) -> Vector2i:
	if command.kind == "capture":
		return _region.position + Vector2i(index % _region.size.x, index / _region.size.x)
	return Vector2i(_cells[index * 3], _cells[index * 3 + 1])


func _protection_error(world: Variant, point: Vector2i) -> String:
	if not _bounds.has_point(point): return "Operation crosses the native canvas boundary."
	for guard: Rect2i in _guards:
		if guard.has_point(point): return "Operation intersects protected source cells."
	# Stored identity does not remove body protection: copying and mutation both
	# refuse the complete operation when a transient body covers any source cell.
	if int(world.rigid_body_id_at(point.x, point.y)) != 0:
		return "Move or remove the body before editing or copying its covered cells."
	return ""


func step(world: Variant, context: Dictionary) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	_slice_started_usec = start
	slices += 1
	var failure: String = str(context.get("error", ""))
	var termination := "invalidated"
	if int(context.epoch) != int(command._epoch):
		failure = "Operation cancelled."
		termination = "cancelled"
	elif int(context.generation) != int(command.expected_generation): failure = "Native World was replaced."
	elif int(context.get("authoring_generation",1)) != int(command.get("expected_authoring_generation",1)):
		failure = "Authoring history was replaced."
	elif int(context.tick) != int(command.expected_tick): failure = "Simulation advanced; source state is no longer current."
	elif int(context.revision) != _revision: failure = "Another edit changed the native source."
	elif int(context.settings_revision) != int(command._settings_revision): failure = "Construction settings changed."
	elif not bool(context.paused): failure = "Pause the simulation before authoring."
	if not failure.is_empty(): return _finish(termination, failure, context)
	if str(world.get_class()) != "CyberNativeCellWorld":
		return _finish("refused", "PAINT requires the source-matched native runtime.", context)
	if not world.has_method("stored_material_at") or not world.has_method("rigid_body_id_at"):
		return _finish("refused", "Native runtime lacks stored-material readback. Install the source-matched Workbench native library and restart.", context)
	if command.kind == "capture" and not _bounds.encloses(_region):
		return _finish("refused", "Capture crosses the native canvas boundary.", context)
	var stop: int = mini(count, (applied if status == "executing" else checked) + SLICE_CELLS)
	if status != "executing":
		while checked < stop:
			var point: Vector2i = _point(checked)
			failure = _protection_error(world, point)
			if not failure.is_empty(): return _finish("refused", failure, context)
			if command.kind == "edit":
				var key: int = point.y * _bounds.size.x + point.x
				if key <= _last_key:
					return _finish("refused", "Paint cells must be unique and in row-major order.", context)
				_last_key = key
				var material: int = _cells[checked * 3 + 2]
				if not bool(context.get("erase_allowed" if material == 0 else "paint_allowed", false)):
					return _finish("refused", "The installed scenario does not allow this painting tool.", context)
				if material < 0 or material >= 256 or _allowed[material] == 0:
					return _finish("refused", "Material is not supported by the loaded native runtime.", context)
			var before: int = int(world.stored_material_at(point.x, point.y))
			if not _source_allowed.is_empty() and before not in _source_allowed:
				return _finish("refused", "Source material is protected by this caller's policy.", context)
			if not _expected.is_empty() and before != _expected[checked]:
				return _finish("refused", "Undo source material changed; operation was not applied.", context)
			_before[checked] = before
			checked += 1
		if checked == count:
			if command.kind == "capture":
				maximum_slice_usec = maxi(maximum_slice_usec, Time.get_ticks_usec() - start)
				return _finish("completed", "", context)
			status = "executing"
	else:
		while applied < stop:
			var point: Vector2i = _point(applied)
			failure = _protection_error(world, point)
			if not failure.is_empty(): return _finish("invalidated", failure, context)
			var before: int = int(world.stored_material_at(point.x, point.y))
			if before != _before[applied]:
				return _finish("invalidated", "A source cell changed after preflight.", context)
			var desired: int = _cells[applied * 3 + 2]
			if not bool(context.get("erase_allowed" if desired == 0 else "paint_allowed", false)):
				return _finish("invalidated", "The installed scenario changed its painting permission.", context)
			if before != desired: world.emit_disc(point.x, point.y, 0, desired)
			var actual: int = int(world.stored_material_at(point.x, point.y))
			_after[applied] = actual
			applied += 1
			if actual != before: changed += 1
			_revision = int(world.revision)
			context.revision = _revision
			if actual != desired:
				return _finish("failed", "Native readback did not match the requested material.", context)
		if applied == count:
			maximum_slice_usec = maxi(maximum_slice_usec, Time.get_ticks_usec() - start)
			return _finish("completed", "", context)
	maximum_slice_usec = maxi(maximum_slice_usec, Time.get_ticks_usec() - start)
	return {}


func _finish(termination: String, reason: String, context: Dictionary) -> Dictionary:
	status = "partial" if applied > 0 and termination != "completed" else termination
	var result := {"operation_id": command.operation_id, "kind": command.kind,
		"status": status, "termination": termination, "reason": reason,
		"requested_cells": count, "checked": checked, "applied": applied, "changed": changed,
		"generation": int(command.expected_generation), "revision": _revision,
		"authoring_generation":int(context.get("authoring_generation",1)),
		"tick": int(command.expected_tick), "observed_generation": int(context.generation),
		"backend": "CyberNativeCellWorld", "slices": slices,
		"maximum_slice_usec": maximum_slice_usec, "elapsed_usec": Time.get_ticks_usec() - _started_usec,
		"recovery_possible": int(context.generation) == int(command.expected_generation) \
			and int(context.tick) == int(command.expected_tick) and int(context.revision) == _revision and bool(context.paused) \
			and str(context.get("error", "")).is_empty()}
	if command.kind == "capture":
		result.region = _region
		result.materials = _before if status == "completed" else PackedInt32Array()
	else:
		var committed: PackedInt32Array = _cells.slice(0, applied * 3)
		# Every earlier actual ID was checked against the request. Only the last
		# attempted cell can differ (a native mismatch terminates immediately).
		if applied > 0: committed[(applied - 1) * 3 + 2] = _after[applied - 1]
		result.cells = committed
		result.before = _before.slice(0, applied)
		result.after = _after.slice(0, applied)
	maximum_slice_usec = maxi(maximum_slice_usec, Time.get_ticks_usec() - _slice_started_usec)
	result.maximum_slice_usec = maximum_slice_usec
	result.elapsed_usec = Time.get_ticks_usec() - _started_usec
	return result
