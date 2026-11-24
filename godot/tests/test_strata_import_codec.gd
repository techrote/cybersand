extends SceneTree

## Deterministic source/mask/transform and metadata refusal witnesses. This test
## is deliberately value-only; it does not claim native application or display.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Codec = preload("res://scripts/depth/strata_import_codec.gd")
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
var ADMITTED := PackedInt32Array([0, 26, 58, 66])
const PALETTE := [{"rgb": [64, 80, 96], "material": 58, "role": "structure"}, {"rgb": [32, 192, 224], "material": 66, "role": "accent"}]
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("STRATA_IMPORT " + label)


func prepare(image: Image, options: Dictionary, mask: Image = null) -> Dictionary:
	var codec := Codec.new()
	var state: Dictionary = codec.begin_png(image.save_png_to_buffer(), options, ADMITTED, mask.save_png_to_buffer() if mask != null else PackedByteArray())
	while state.get("status") == "preparing": state = codec.step(3)
	return state


func record() -> Dictionary:
	var sha := "a".repeat(64)
	return {"version": 1, "id": "proof-1", "kind": "raster_import", "plane": "scripted", "scene_id": "scene-1", "owner_id": "owner:9223372036854775806", "generation": 1,
		"before_revision": 2, "after_revision": 3, "status": "completed", "requested_cells": 1, "applied_cells": 1, "changed_cells": 1, "requested_chunks": 1, "completed_chunks": 1,
		"source_sha256": sha, "proposal_sha256": sha, "geometry_sha256": sha, "before_sha256": sha, "projected_sha256": sha, "actual_sha256": sha,
		"published": true, "metadata": {"source": "synthetic-test"}, "error": "", "historical": true, "scope": "authored-material-operation-history"}


func run() -> void:
	var image := Image.create(5, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color8(64, 80, 96))
	image.set_pixel(2, 1, Color8(255, 12, 190, 0)) # Central cutout retains hidden RGB.
	image.set_pixel(3, 1, Color8(32, 192, 224, 127))
	image.set_pixel(4, 1, Color8(32, 192, 224, 128))
	var bytes := image.save_png_to_buffer()
	var source_sha := Module.digest(bytes)
	var options := Codec.defaults(image.get_size(), PALETTE)
	var result := prepare(image, options)
	check(result.ok and result.status == "ready" and result.zero_writes, "overlay produces only a zero-write proposal")
	if not result.ok:
		print("STRATA_IMPORT_PREPARATION_REFUSAL ", result.get("error", "missing reason"))
		quit(1)
		return
	check(result.mapped == 13 and result.no_write == 2 and result.unmapped == 0 and result.explicit_empty == 0, "threshold and alpha0 counts match exact source")
	check(result.mask[7] == 0 and result.cells.decode_u16(14) == 0 and result.mask[8] == 0 and result.cells.decode_u16(18) == 66, "interior alpha cutout is canonical no-write; threshold128 included")
	check(result.source_sha256 == source_sha and Module.digest(bytes) == source_sha, "original PNG byte identity is retained unchanged")
	var repeated := prepare(image, options)
	check(repeated.module == result.module, "deterministic replay gives the exact masked native proposal")
	var roundtrip := Module.read_json(Module.json_bytes(result.module), ADMITTED)
	check(roundtrip.ok and roundtrip.module == result.module, "canonical JSON roundtrip preserves material IDs and no-write mask")
	options.alpha_mode = "replace"
	var replaced := prepare(image, options)
	check(replaced.ok and replaced.mapped == 15 and replaced.explicit_empty == 2 and replaced.mask[7] == 1 and replaced.cells.decode_u16(14) == 0, "explicit replacement creates Empty writes")
	var mask := Image.create(5, 3, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	mask.set_pixel(2, 1, Color.BLACK)
	mask.set_pixel(0, 0, Color8(255, 255, 255, 0))
	var masked := prepare(image, options, mask)
	check(masked.ok and masked.mask_skipped == 2 and masked.mask[7] == 0 and masked.mask[0] == 0 and masked.explicit_empty == 1, "explicit mask excludes pixels even in replacement mode")
	check(masked.provenance.mask_sha256 == Module.digest(mask.save_png_to_buffer()), "mask source digest retained")
	var mismatch := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	check(not prepare(image, options, mismatch).ok, "differently sized masks refused without resampling")
	image.set_pixel(1, 1, Color8(255, 0, 0))
	options.alpha_mode = "overlay"
	var unknown := prepare(image, options)
	check(not unknown.ok and unknown.status == "refused" and unknown.unmapped == 1 and unknown.no_write == 3 and unknown.has("module"), "unknown opaque colour refusal retains visible proposed mapping")
	options.unmapped = "skip"
	check(prepare(image, options).ok, "explicit skip admits accounted unmapped no-write pixels")
	options.palette.append({"rgb": [255, 0, 0], "material": 26, "role": "inset"})
	options.unmapped = "refuse"
	check(prepare(image, options).ok, "explicit palette resolves unknown colour")
	var tie_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	tie_image.fill(Color8(10, 10, 10))
	var tie_options := Codec.defaults(Vector2i.ONE, [{"rgb": [9, 10, 10], "material": 58, "role": "a"}, {"rgb": [11, 10, 10], "material": 66, "role": "b"}])
	tie_options.color_distance = 1
	check(prepare(tie_image, tie_options).cells.decode_u16(0) == 58, "RGB distance tie deterministically chooses earlier explicit row")
	tie_options.color_distance = 0
	check(not prepare(tie_image, tie_options).ok, "distance threshold refuses distant colours")
	var grid := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	grid.fill(Color.TRANSPARENT)
	grid.set_pixel(0, 0, Color8(64, 80, 96))
	grid.set_pixel(2, 1, Color8(32, 192, 224))
	var expected := {"identity": [[0, 0], [2, 1]], "mirror_x": [[2, 0], [0, 1]], "mirror_y": [[0, 1], [2, 0]], "rotate_90": [[1, 0], [0, 2]], "rotate_180": [[2, 1], [0, 0]], "rotate_270": [[0, 2], [1, 0]]}
	for transform: String in expected:
		var transformed_options := Codec.defaults(grid.get_size(), PALETTE)
		transformed_options.transform = transform
		transformed_options.scale = 2
		var transformed := prepare(grid, transformed_options)
		check(transformed.ok and transformed.mapped == 8 and transformed.no_write == 16, transform + " duplicates exact integer grid only")
		for i: int in 2:
			for dy: int in 2:
				for dx: int in 2:
					var index := (int(expected[transform][i][1]) * 2 + dy) * int(transformed.extent[0]) + int(expected[transform][i][0]) * 2 + dx
					check(transformed.mask[index] == 1 and transformed.cells.decode_u16(index * 2) == [58, 66][i], transform + " exact material and coordinate")
	var wide := Image.create(512, 2, false, Image.FORMAT_RGBA8)
	wide.fill(Color8(64, 80, 96))
	var wide_options := Codec.defaults(wide.get_size(), PALETTE)
	wide_options.scale = 4
	var wide_result := prepare(wide, wide_options)
	check(wide_result.ok and wide_result.extent == [2048, 8], "wide masked interchange preserves2048-side exact-grid output")
	var too_many := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var too_many_options := Codec.defaults(too_many.get_size(), PALETTE)
	too_many_options.scale = 2
	check(not prepare(too_many, too_many_options).ok, "output area refuses before allocating oversized native proposal")
	var oversized_png := bytes.duplicate()
	oversized_png[16] = 0; oversized_png[17] = 0; oversized_png[18] = 8; oversized_png[19] = 1
	check(not Codec.inspect_png(oversized_png).ok, "oversized PNG IHDR refuses before decompression")
	var trailing := bytes.duplicate(); trailing.append(0)
	check(not Codec.inspect_png(trailing).ok and not Codec.inspect_png(bytes.slice(0, bytes.size() - 2)).ok, "trailing and truncated PNG payloads refuse")
	var codec := Codec.new()
	check(codec.begin_png(bytes, Codec.defaults(Vector2i(5, 3), PALETTE), ADMITTED).busy, "incremental preparation starts")
	check(codec.cancel().status == "cancelled" and codec.state().zero_writes, "Stop during raster preparation performs no writes")
	check(not codec.begin_png(PackedByteArray(), {}, ADMITTED).ok and codec.state().source_image == null and codec.state().output_image == null, "new refused source does not retain previous preview")
	codec.begin_png(bytes, Codec.defaults(Vector2i(5, 3), PALETTE), ADMITTED)
	codec.state().source_image.set_pixel(0, 0, Color.RED)
	check(not codec.step().ok, "mutable display reference cannot silently change bound source bytes")
	var bad: Dictionary = result.module.duplicate(true)
	bad.geometry.sha256 = "0".repeat(64); bad.content_sha256 = Module.content_digest(bad)
	check(not Module.validate(bad, ADMITTED).ok, "tampered material bytes checksum refuses")
	check(not Module.validate(result.module, PackedInt32Array([0, 26])).ok, "current native material admission required")
	bad = result.module.duplicate(true); bad.protected_regions = [[0, 0, 1, 1]]; bad.content_sha256 = Module.content_digest(bad)
	check(not Module.validate(bad, ADMITTED).ok, "module cannot write inside its own protection")
	bad = result.module.duplicate(true); bad.clearances = [Rect2i(2, 1, 1, 1)]; bad.content_sha256 = Module.content_digest(bad)
	check(not Module.validate(bad, ADMITTED).ok, "persisted module rejects native Variant rectangles instead of throwing")
	var placement := {"origin": [100, 80], "transform": "rotate_90", "palette": {}, "empty_mode": "preserve"}
	var constraints := {"region": [90, 70, 40, 40], "allowed_materials": Array(ADMITTED), "protected": []}
	var compiled := Module.compile(result.module, placement, constraints, ADMITTED)
	check(compiled.ok and compiled.cells.size() == 13 * 3 and compiled.footprint == [100, 80, 3, 5], "native placement retains exact IDs and transformed footprint")
	var unknown_constraints: Dictionary = constraints.duplicate(true); unknown_constraints.allow_unreviewed_transfer = true
	check(not Module.compile(result.module, placement, unknown_constraints, ADMITTED).ok, "unknown native target constraint refuses explicitly")
	constraints.protected = [[102, 80, 1, 1]]
	check(not Module.compile(result.module, placement, constraints, ADMITTED).ok, "one protected write refuses entire placement; no clipping")
	constraints.protected = []; placement.origin = [120, 110]
	check(not Module.compile(result.module, placement, constraints, ADMITTED).ok, "complete source footprint must fit explicit admitted region")
	var architecture: Dictionary = result.module.duplicate(true)
	architecture.format = Module.ARCHITECTURE_FORMAT
	architecture.geometry.erase("write_mask_base64"); architecture.geometry.erase("mask_sha256")
	architecture.tags = ["synthetic"]; architecture.part_type = "wall_facade"; architecture.attachments = []; architecture.variation_regions = []; architecture.recipe = {}; architecture.design_card_ids = []
	architecture.content_sha256 = Module.content_digest(architecture)
	var adapted := Module.from_architecture(architecture, source_sha, ADMITTED)
	check(adapted.ok and adapted.mask[7] == 0 and adapted.module.provenance.reader_contract_source == Module.ARCHITECTURE_SOURCE, "source-pinned architecture adapter preserves IDs and Empty no-write")
	architecture.attachments = [{"id": "a", "kind": "socket", "point": [0, 0], "facing": [1, 0], "compatibility": ["beam"], "required": true, "source": "authored"}]
	architecture.content_sha256 = Module.content_digest(architecture)
	check(not Module.from_architecture(architecture, source_sha, ADMITTED).ok, "required attachments refuse; no implied solver")
	architecture.attachments[0].required = false; architecture.attachments[0].facing = [0, 0]; architecture.content_sha256 = Module.content_digest(architecture)
	check(not Module.from_architecture(architecture, source_sha, ADMITTED).ok, "malformed optional attachment metadata also refuses")
	var valid := record()
	check(Provenance.validate_record(valid).is_empty(), "complete historical native outcome validates")
	var history := Provenance.append(Provenance.defaults(), valid)
	check(history.ok and Provenance.canonical(JSON.parse_string(JSON.stringify(history.authoring))).records[0].version is int, "provenance roundtrip canonicalizes numeric fields")
	for field: String in valid:
		for wrong: Variant in [[], {}, null, NAN, INF]:
			var candidate := valid.duplicate(true); candidate[field] = wrong
			if field == "metadata" and wrong is Dictionary: continue
			check(not Provenance.validate_record(candidate).is_empty(), "malformed scalar/container refused " + field + ":" + str(typeof(wrong)))
	for field: String in ["id", "kind", "plane", "scene_id", "owner_id", "status", "scope", "historical", "published"]:
		var candidate := valid.duplicate(true); candidate[field] = 1.0
		check(not Provenance.validate_record(candidate).is_empty(), "wrong semantic scalar refuses " + field)
	var forged := valid.duplicate(true); forged.applied_cells = 0
	check(not Provenance.validate_record(forged).is_empty(), "incomplete native prefix cannot claim completed")
	forged = valid.duplicate(true); forged.published = false
	check(not Provenance.validate_record(forged).is_empty(), "native commit cannot silently claim successful pixels")
	forged.status = "committed_stale_pixels"
	check(Provenance.validate_record(forged).is_empty(), "committed cells with stale display remain explicitly committed")
	var full := Provenance.defaults()
	for i: int in 64:
		var item := valid.duplicate(true); item.id = "record-%d" % i; full.records.append(item)
	check(Provenance.validate(full).is_empty() and not Provenance.append(full, valid).ok and full.records.size() == 64, "provenance cap refuses new records without eviction")
	print("STRATA_IMPORT ", JSON.stringify({"checks": checks, "failures": failures, "completed": true, "source_sha256": source_sha, "proposal_sha256": result.module.content_sha256, "scope": "value-only mapping; native/session and framebuffer qualify separately"}))
	quit(0 if failures.is_empty() else 1)
