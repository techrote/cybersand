extends RefCounted

# PAINT-001 authored-start preflight. These are copied recipes, not native
# receipts. The host installs a returned setup only after actual worker ACK.
# No evolved World capture, standalone baseline or Flatten is performed here.
const Setup = preload("res://scripts/workbench_setup.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")
const MAX_CELLS := 262144


static func _refuse(reason: String) -> Dictionary:
	return {"accepted":false,"error":reason,"setup":{},"stamps":[],"cell_count":0}


# Input uses the worker's exact xyz triplets, strictly row-major and unique.
# Equal adjacent materials become horizontal runs; equal runs on adjacent
# rows extend one box. Empty is retained, including when it erases GEN terrain.
static func stamps(cells: PackedInt32Array, extent: Vector2i) -> Dictionary:
	if cells.is_empty() or cells.size() % 3 != 0 or cells.size() / 3 > MAX_CELLS:
		return _refuse("Paint needs 1–262144 complete cell/material triplets.")
	if extent.x < 512 or extent.y < 512 or extent.x > 2048 or extent.y > 2048 \
			or extent.x % 64 != 0 or extent.y % 64 != 0:
		return _refuse("Paint needs an admitted 512–2048 canvas extent.")
	var previous := -1
	var admitted := {}
	for index: int in range(0,cells.size(),3):
		var x := int(cells[index])
		var y := int(cells[index+1])
		var material := int(cells[index+2])
		if x < 0 or y < 0 or x >= extent.x or y >= extent.y:
			return _refuse("The complete paint operation must fit inside the canvas.")
		var position := y*extent.x+x
		if position <= previous:
			return _refuse("Paint cells must be unique and in exact row-major order.")
		previous = position
		if not admitted.has(material):
			if not Setup._stamp_material(material):
				return _refuse("Native material %d is not supported for starting paint." % material)
			admitted[material] = true
	var result: Array = []
	var open := {}
	var cursor := 0
	while cursor < cells.size():
		var x := int(cells[cursor])
		var y := int(cells[cursor+1])
		var material := int(cells[cursor+2])
		var width := 1
		cursor += 3
		while cursor < cells.size() and cells[cursor] == x+width \
				and cells[cursor+1] == y and cells[cursor+2] == material:
			width += 1
			cursor += 3
		var key := Vector3i(x,width,material)
		var existing: int = int(open.get(key,-1))
		if existing >= 0 and int(result[existing][1])+int(result[existing][3]) == y:
			result[existing][3] = int(result[existing][3])+1
			continue
		if result.size() >= Setup.MAX_STAMPS:
			return _refuse("Paint is too detailed for the saved-start limit of %d rectangles." % Setup.MAX_STAMPS)
		open[key] = result.size()
		result.append([x,y,width,1,material])
	return {"accepted":true,"error":"","stamps":result,"cell_count":cells.size()/3}


# Full persistence admission precedes native writes. Ordinary Setup-v2 can
# compact against its blank baseline. A generated start keeps ordered Empty
# and material overlays; compacting those as a blank canvas would lose erasure.
# For a partial native receipt, call this again with only the confirmed prefix.
# If that prefix cannot fit, the host must block Save and offer Restore start.
static func prepare(setup: Dictionary, cells: PackedInt32Array,
		generated_packet: Dictionary = {}) -> Dictionary:
	var error: String = Setup.validate(setup)
	if not error.is_empty(): return _refuse(error)
	var native_limit: int = Setup.native_rectangle_budget()
	var encoded := stamps(cells,Setup.extent_of(setup))
	if not encoded.accepted: return encoded
	var candidate := setup.duplicate(true)
	candidate.edits.append_array(encoded.stamps)
	if generated_packet.is_empty():
		var row_bound := 0
		for stamp: Array in candidate.edits:
			# Each overwritten interval can split an older run into two. At
			# most two boundaries per stamp/row bound the final row segments.
			row_bound += 2*Setup.stamp_rows(stamp)
		if candidate.edits.size() > native_limit or row_bound > native_limit:
			var compacted := Setup.compact_edits(candidate)
			if compacted.has("error"): return _refuse(str(compacted.error))
			candidate.edits = compacted.edits
		if candidate.edits.size() > native_limit:
			return _refuse("This installed native runtime supports only %d starting rectangles; rebuild the GDExtension." % native_limit)
	elif candidate.edits.size() > native_limit:
		return _refuse("Generated-map starting paint exceeds the installed native limit of %d rectangles; rebuild the GDExtension." % native_limit)
	if not generated_packet.is_empty():
		error = GeneratedMaps.edit_work_error(candidate)
		if not error.is_empty(): return _refuse(error)
	error = Setup.validate(candidate)
	if not error.is_empty(): return _refuse(error)
	var body: String
	if generated_packet.is_empty():
		body = JSON.stringify(candidate)
	else:
		if not generated_packet.has_all(["recipe","origin","extent","sha256","recipe_sha256",
				"generator_fingerprint","plane_revision","generator_revision","receipt_hashes","cells"]) \
				or not generated_packet.recipe is Dictionary or not generated_packet.origin is Vector2i \
				or not generated_packet.extent is Vector2i or not generated_packet.receipt_hashes is Array \
				or not generated_packet.cells is PackedByteArray:
			return _refuse("Generated starting source is incomplete.")
		var metadata := GeneratedMaps.provenance(generated_packet)
		error = GeneratedMaps.valid_provenance(metadata,Setup.extent_of(candidate))
		if not error.is_empty(): return _refuse(error)
		var extent := Setup.extent_of(candidate)
		if generated_packet.cells.size() != extent.x*extent.y \
				or GeneratedMaps.digest(generated_packet.cells) != metadata.sha256:
			return _refuse("Generated starting material source has changed.")
		body = JSON.stringify({"format":GeneratedMaps.FORMAT,"version":1,
			"generation":metadata,"starting_setup":candidate})
	if body.to_utf8_buffer().size() > Setup.BYTE_LIMIT:
		return _refuse("The completed paint operation would exceed the 1 MiB saved-start budget.")
	return {"accepted":true,"error":"","setup":candidate,
		"stamps":encoded.stamps,"cell_count":encoded.cell_count}
