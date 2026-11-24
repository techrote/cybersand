extends SceneTree

const Library = preload("res://scripts/depth/strata_authoring_library.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Plan = preload("res://scripts/depth/strata_construction_plan.gd")
const Executor = preload("res://scripts/workbench_paint_editor_executor.gd")
var checks := 0
var failures: Array[String] = []
var summaries: Array = []


func _initialize() -> void:
	var admitted: PackedInt32Array = Executor.native_materials()
	check(not admitted.is_empty(), "actual retained native catalogue is available")
	check(Library.catalogue().size() == 8, "eight fixed original parts")
	for item: Dictionary in Library.catalogue():
		var loaded := Library.module(item.id, admitted)
		check(loaded.ok, "part validates through strict codec: " + item.id + " " + str(loaded.get("error", "")))
		if not loaded.ok: continue
		var written := 0
		var no_write := 0
		var canonical_transparency := true
		for i: int in loaded.mask.size():
			if loaded.mask[i] == 0:
				no_write += 1
				canonical_transparency = canonical_transparency and loaded.cells.decode_u16(i * 2) == 0
			else: written += 1
		check(no_write > 0 and written > 0, item.id + " has deliberate no-write voids and native geometry")
		check(canonical_transparency, item.id + " transparent native storage canonical")
		for transform: String in Module.TRANSFORMS:
			var size := Module.transformed_size(loaded.extent, transform)
			var built := Module.compile(loaded.module, {"origin":[64, 64], "transform":transform, "empty_mode":"preserve"},
				{"region":[64, 64, size.x, size.y], "allowed_materials":Array(admitted)}, admitted)
			check(built.ok, item.id + " exact transform compiles: " + transform)
			if built.ok: check(built.cells.size() / 3 == written, item.id + " transform preserves exact native write count")
		var corrupted: Dictionary = loaded.module.duplicate(true)
		corrupted.content_sha256 = "0".repeat(64)
		check(not Module.validate(corrupted, admitted).ok, item.id + " altered identity refused")
		summaries.append({"id":item.id, "native_written_cells":written, "no_write_cells":no_write, "content_sha256":loaded.module.content_sha256})
	var states := {}
	for plane: String in ["scripted", "effects", "background"]:
		states[plane] = {"ok":true, "scene_id":"library-test-scene", "revision":7}
	check(Library.composition_catalogue().size() == 3, "three finite layered design presets")
	for item: Dictionary in Library.composition_catalogue():
		var built := Library.composition(item.id, Vector2i(64, 64), states, admitted)
		check(built.ok, "layered preset compiles: " + item.id + " " + str(built.get("error", "")))
		if not built.ok: continue
		var compiled := Plan.compile(built.plan, admitted)
		check(compiled.ok and compiled.zero_writes, item.id + " remains zero-write proposal")
		for stage: Dictionary in built.plan.stages:
			check(stage.plane != "play" and stage.expected_revision == 7, item.id + " binds selected native plane revision")
		check(built.plan.metadata.composition.has("atmosphere_proposal"), item.id + " keeps visual settings separate from native stages")
		check(not Library.composition(item.id, Vector2i(2000, 2000), states, admitted).ok, item.id + " overextent anchor refused")
		var stale := states.duplicate(true)
		stale.effects.scene_id = "another-scene"
		check(not Library.composition(item.id, Vector2i(64, 64), stale, admitted).ok, item.id + " mixed-scene target refused")
	check(not Library.module("../escape", admitted).ok, "part catalogue prevents arbitrary path access")
	check(not Library.composition("../escape", Vector2i.ZERO, states, admitted).ok, "preset catalogue prevents arbitrary path access")
	check(Library.fixture_catalogue().size() >= 2, "raster and native import fixtures are exposed")
	print("STRATA_AUTHORING_LIBRARY ", JSON.stringify({"checks":checks, "failures":failures,
		"scope":"Native palette plus strict value codecs/plans; no mounted World or framebuffer claim.", "parts":summaries}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
