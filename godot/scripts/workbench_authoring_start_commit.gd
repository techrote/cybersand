extends RefCounted
## WB-AGENT-001: record *verified* native agent authoring in the existing
## named-start construction. This never paints the native World or saves a file.
## Stage BEFORE owner apply; commit only after an exact 'applied' readback receipt.
const Setup = preload("res://scripts/workbench_setup.gd")


static func _refused(reason: String) -> Dictionary:
	return {"status":"refused","reason":reason}


static func _signature(setup: Dictionary) -> String:
	# Serializes the complete authored construction, not mutable native runtime.
	return JSON.stringify(setup)


static func _boxes_for_changed_cells(rows: Array) -> Array:
	var cells: Dictionary = {}
	var ys: Array[int] = []
	for record: Dictionary in rows:
		if int(record.before) == int(record.after):
			continue
		var y: int = int(record.y)
		var x: int = int(record.x)
		if not cells.has(y):
			cells[y] = {}
			ys.append(y)
		cells[y][x] = int(record.after)
	ys.sort()
	var edits: Array = []
	for y: int in ys:
		var row: Dictionary = cells[y]
		var xs: Array = row.keys()
		xs.sort()
		var start: int = -1
		var length: int = 0
		var material: int = -1
		for raw_x: Variant in xs:
			var x: int = int(raw_x)
			var value: int = int(row[raw_x])
			if start >= 0 and (x != start + length or value != material):
				edits.append([start,y,length,1,material])
				start = -1
			if start < 0:
				start = x
				material = value
				length = 0
			length += 1
		if start >= 0:
			edits.append([start,y,length,1,material])
	return edits


## Proposed footprint is an Array of {x,y,before,after} from the OWNER.
## Returns an immutable plan tied to the entire existing authored setup.
static func stage(setup: Dictionary, proposal: Dictionary) -> Dictionary:
	if str(proposal.get("status","")) != "proposed" \
			or not proposal.get("footprint",null) is Array:
		return _refused("missing_authoritative_proposal")
	if Setup.validate(setup) != "":
		return _refused("invalid_existing_start")
	var rows: Array = proposal.footprint
	if rows.size() > 4096:
		return _refused("edit_exceeds_capacity")
	for row: Variant in rows:
		if not row is Dictionary:
			return _refused("invalid_proposed_cell")
		for field: String in ["x","y","before","after"]:
			if not row.has(field) or typeof(row[field]) != TYPE_INT:
				return _refused("invalid_proposed_cell")
		if int(row.after) not in [0,58] or int(row.before) not in [0,58]:
			return _refused("source_material_protected")
		var pos := Vector2i(int(row.x),int(row.y))
		if not Rect2i(Vector2i.ZERO,Setup.extent_of(setup)).has_point(pos):
			return _refused("outside_start_extent")
	var additions: Array = _boxes_for_changed_cells(rows)
	var candidate: Dictionary = setup.duplicate(true)
	candidate.edits.append_array(additions)
	# The existing authoring system can represent boxes, even though an
	# ordinary manual brush uses 4-value disc stamps.
	# Compact first: a large but highly rectangular edit can fit even when
	# its temporary unmerged one-row boxes exceed MAX_STAMPS.
	var compact: Dictionary = Setup.compact_edits(candidate)
	if compact.has("error"):
		return _refused(str(compact.error))
	if compact.edits.size() > Setup.MAX_STAMPS:
		return _refused("starting_history_capacity")
	candidate.edits = compact.edits
	if Setup.validate(candidate) != "" or Setup.rectangles(candidate).has("error"):
		return _refused("starting_history_not_representable")
	return {
		"status":"recordable",
		"proposal_id":proposal.proposal_id,
		"start_signature":_signature(setup),
		"candidate":candidate,
		"footprint":rows.duplicate(true),
		"changed_cells":int(proposal.get("changed_cells",0))
	}


## Call once on the MAIN THREAD after the exclusive worker reports 'applied'.
## Refuse if the human changed the authored setup while the model was working.
## A refusal is NOT permission to retry the native mutation.
static func commit(panel: Control, plan: Dictionary, receipt: Dictionary) -> Dictionary:
	if str(plan.get("status","")) != "recordable" \
			or str(receipt.get("status","")) != "applied" \
			or str(plan.get("proposal_id","")) != str(receipt.get("proposal_id","")):
		return _refused("no_matched_verified_native_receipt")
	if not panel.has_method(&"save_setup") or panel.applied.is_empty():
		return _refused("workbench_not_available")
	if _signature(panel.applied) != str(plan.start_signature):
		return _refused("manual_start_changed_before_recording")
	var expected: Array = plan.footprint
	var actual: Array = receipt.get("readback",[])
	if expected.size() != actual.size():
		return _refused("native_readback_size_mismatch")
	for index: int in range(expected.size()):
		var e: Dictionary = expected[index]
		var a: Dictionary = actual[index]
		if int(e.x) != int(a.x) or int(e.y) != int(a.y) \
				or int(e.before) != int(a.before) or int(e.after) != int(a.after) \
				or int(a.actual) != int(e.after):
			return _refused("native_readback_values_mismatch")
	var candidate: Dictionary = plan.candidate.duplicate(true)
	if Setup.validate(candidate) != "" or Setup.rectangles(candidate).has("error"):
		return _refused("candidate_start_failed_final_validation")
	panel.applied.edits = candidate.edits
	return {
		"status":"recorded",
		"proposal_id":plan.proposal_id,
		"changed_cells":plan.changed_cells,
		"authored_edits":panel.applied.edits.size()
	}
