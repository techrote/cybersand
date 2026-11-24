extends SceneTree

const Codec = preload("res://scripts/depth/strata_import_codec.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Executor = preload("res://scripts/workbench_paint_editor_executor.gd")
const ROOT := "res://data/strata2/reference-imports/"
var checks := 0
var failures: Array[String] = []
var receipts: Array = []


func _initialize() -> void:
	var admitted := Executor.native_materials()
	check(not admitted.is_empty(), "current native material catalogue available")
	for id: String in ["asteroid-service-gallery", "rocket-hangar-frame"]:
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + ".fixture.json"))
		var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + ".provenance.json"))
		var bytes := FileAccess.get_file_as_bytes(fixture.path)
		var mask := FileAccess.get_file_as_bytes(fixture.options.mask_path)
		check(Module.digest(bytes) == provenance.crop_file_sha256, id + " shipped exact crop file identity")
		check(Module.digest(mask) == provenance.mask_sha256, id + " separate authored mask identity")
		var inspection := Codec.inspect_png(bytes)
		check(inspection.ok, id + " source PNG admitted")
		if not inspection.ok: continue
		var options: Dictionary = fixture.options.duplicate(true)
		options.erase("plane")
		options.erase("mask_path")
		var codec := Codec.new()
		var result := codec.begin_png(bytes, options, admitted, mask)
		var steps := 0
		while result.status == "preparing" and steps < 64:
			result = codec.step(4096)
			steps += 1
		check(result.status == "ready" and result.ok, id + " bounded real-source proposal prepares")
		if not result.ok: continue
		check(result.zero_writes, id + " conversion performs zero native writes")
		check(result.module.geometry.sha256 == provenance.proposed_uint16le_sha256, id + " independently generated exact material bytes")
		check(result.module.geometry.mask_sha256 == provenance.proposed_write_mask_sha256, id + " independently generated no-write mask")
		check(result.mapped == provenance.proposal_counts.mapped, id + " complete mapped-pixel accounting")
		check(result.mask_skipped == provenance.proposal_counts.mask_no_write, id + " complete mask exclusion accounting")
		check(result.unmapped == provenance.proposal_counts.unmapped_skipped, id + " complete unknown-colour accounting")
		check(result.explicit_empty == 0 and result.alpha_skipped == 0, id + " opaque original never invents alpha or clears geometry")
		check(result.no_write > result.mapped, id + " large internal selection voids remain no-write")
		var proposal_sha: String = result.module.geometry.sha256
		options.unmapped = "refuse"
		result = codec.begin_png(bytes, options, admitted, mask)
		while result.status == "preparing": result = codec.step(4096)
		check(result.status == "refused" and not result.ok and result.zero_writes,
			id + " explicit unknown-colour refusal preserves zero-write contract")
		receipts.append({"id":id, "source_sha256":provenance.original_sha256,
			"crop_file_sha256":provenance.crop_file_sha256, "proposal_geometry_sha256":proposal_sha,
			"bounded_conversion_steps":steps, "source_pixels":provenance.proposal_counts.source_pixels,
			"mapped":provenance.proposal_counts.mapped, "unknown_refusal":result.error})
	print("STRATA_REFERENCE_IMPORTS ", JSON.stringify({"checks":checks, "failures":failures,
		"scope":"Exact input and zero-write proposal fidelity; actual native admission/readback remains a separate gate.", "receipts":receipts}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
