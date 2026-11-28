extends "res://tests/test_persistent_area_ramcache.gd"

## Actual persistent host refuses unsupported layered authoring before creating
## native decorative owners or changing the one-world continuation envelope.
const StrataDocument = preload("res://scripts/depth/workbench_layer_document.gd")
var boundary_witness: Dictionary = {}


func exercise_write() -> void:
	if not await configure_cache({"enabled":true,"deferred":true,"background":false,"prefetch":false}): return
	await _strata_refusals()
	if not failures.is_empty(): return
	# Refusal must leave ordinary material editing, durable Save and area travel
	# usable; these marks are independently read again by the inherited fresh
	# process reopen path, rather than trusting the visible refusal alone.
	for id: String in Fixtures.IDS:
		if controller.active_area != id and not await travel(id): return
		if not await edit_area(id): return
	await save_expectations()


func exercise_reopen() -> void:
	await super.exercise_reopen()
	if failures.is_empty(): await _strata_refusals()


func _strata_refusals() -> void:
	phase("Strata boundary preserves persistent native authority")
	var authoring: Dictionary = host.persistent_authoring_state().duplicate(true)
	var manifest: Dictionary = controller.manifest.duplicate(true)
	var before: Dictionary = worker.paint_state().duplicate(true)
	var generation := int(host.latest_snapshot.render_world_generation)
	check(not is_instance_valid(bench.strata), "ordinary persistent startup has no Strata owner")
	bench.open_strata()
	check(not is_instance_valid(bench.strata) and "requires the ordinary Workbench" in bench.message,
		"actual toolbar action visibly refuses before allocating a Strata controller")
	var strata: Node = bench.ensure_strata()
	var initial: Dictionary = strata.layer_owner.stats()
	check(initial.native_world_count == 0 and initial.pending_native_world_count == 0,
		"explicit lazy adapter construction owns no native decoration")
	strata.open_panel()
	check(not is_instance_valid(strata._window), "direct panel entry respects the persistent host boundary")
	var document := StrataDocument.default_document(Vector2i(512,512))
	document.presentation.enabled = true
	check(not strata.load_document({"setup":bench.applied.duplicate(true),"document":document}),
		"valid layered scene load is refused before native candidate construction")
	check(not strata._prepare(document), "direct native preparation cannot bypass host admission")
	check(not strata.set_enabled(true), "layer enable is refused in persistent profile")
	check(not strata.select_optics_profile("diorama"), "optics cannot implicitly create unsupported decorative state")
	var refused_name := "persistent-strata-refused-" + str(OS.get_process_id())
	check(not strata.save_named(refused_name) and not FileAccess.file_exists(Setup._path(refused_name)),
		"layered save refusal leaves no misleading authored file")
	var final: Dictionary = strata.layer_owner.stats()
	check(final == initial and not strata.has_document() and not strata.enabled(),
		"every refused path retains zero native Worlds and no adopted layered document")
	check(host.persistent_authoring_state() == authoring and controller.manifest == manifest,
		"Strata refusal leaves exact persisted authoring envelope and acknowledged manifest unchanged")
	var after: Dictionary = worker.paint_state()
	for key: String in ["generation","revision","tick","authoring_generation"]:
		check(after.get(key) == before.get(key), "Strata refusal preserves native " + key)
	check(int(host.latest_snapshot.render_world_generation) == generation and controller.active_ready and host.paused,
		"same acknowledged Play owner remains active and paused")
	boundary_witness = {"native_world_count":int(final.native_world_count),
		"pending_native_world_count":int(final.pending_native_world_count),"has_document":strata.has_document(),
		"authoring_unchanged":host.persistent_authoring_state() == authoring,"manifest_unchanged":controller.manifest == manifest,
		"native_before":before,"native_after":after,"world_generation":generation,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION")}
	await screenshot("strata-refused-" + mode)


func _finish() -> void:
	# Parent finishes the real durable scene exit before this dedicated receipt.
	# SceneTree.quit schedules exit after the current frame; no await follows.
	await super._finish()
	var result := {"schema":"ramcache-strata-boundaries-v1","mode":mode,"completed":true,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"process_id":OS.get_process_id(),
		"graphical":graphical,"checks":checks,"failures":failures,"witness":boundary_witness}
	if not output.is_empty(): write_json(output.path_join("ramcache-strata-boundaries-"+mode+".json"),result)
	print("RAMCACHE_STRATA_BOUNDARIES ",JSON.stringify(result))
