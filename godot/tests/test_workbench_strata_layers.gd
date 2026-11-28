extends SceneTree

const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Owner = preload("res://scripts/depth/workbench_layer_owner.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")

var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native layer runtime unavailable")
	if failures > 0:
		quit(failures)
		return
	var scene := Document.default_document(Vector2i(512, 512))
	scene.presentation.enabled = true
	Document.plane(scene, "scripted").rectangles = [[20, 20, 30, 20, 13]]
	Document.plane(scene, "effects").rectangles = [[80, 80, 20, 2, 22]]
	Document.plane(scene, "background").rectangles = [[100, 100, 40, 30, 100]]
	expect(Document.validate(scene).is_empty(), "valid authored scene refused")
	var owner := Owner.new()
	var prepared := owner.prepare(scene)
	expect(prepared.get("ok", false), "native layer candidate refused: " + owner.last_error)
	if not prepared.get("ok", false):
		quit(1)
		return
	expect(owner.generation() == 0 and owner.stats().native_world_count == 0, "preparation changed live ownership")
	expect(owner.stats().pending_native_world_count == 3, "candidate does not own exactly three native Worlds")
	expect(owner.prepared_packets(prepared.token).size() == 3, "candidate has incomplete publications")
	expect(not owner.commit(int(prepared.token) + 1), "wrong candidate token committed")
	expect(owner.commit(prepared.token), "prepared candidate did not commit")
	expect(owner.stats().native_world_count == 3 and not owner.stats().owns_play_world, "layer owner took play authority")
	expect(owner.material_at("play", Vector2i(22, 22)) == -1, "layer owner exposes a play World")
	expect(owner.material_at("scripted", Vector2i(22, 22)) == 13, "native rear material differs from authored rectangle")
	expect(owner.material_at("effects", Vector2i(81, 80)) == 22, "native effects material differs")
	expect(owner.material_at("background", Vector2i(101, 101)) == 100, "native background material differs")
	var initial_stats := owner.stats()
	var packet := owner.snapshot_layer("scripted", true)
	expect(packet.extent == Vector2i(512, 512) and packet.owner_id != "" and packet.reset_generation == 1, "publication identity missing")
	var first_byte: int = packet.cells[0]
	packet.cells[0] = 255
	expect(owner.snapshot_layer("scripted", true).cells[0] == first_byte, "publication aliases retained native/cached bytes")
	var snapshot_calls: int = owner.stats().native_snapshot_calls
	for _index: int in 30: expect(owner.snapshot_layer("scripted").unchanged, "static plane repeatedly publishes bytes")
	expect(owner.stats().native_snapshot_calls == snapshot_calls, "static polling recaptures the native World")
	var invalid := scene.duplicate(true)
	invalid.unknown = "reject"
	expect(not owner.prepare(invalid, owner.generation()).ok, "unknown scene fields admitted")
	expect(owner.stats().layers.scripted.native_instance_id == initial_stats.layers.scripted.native_instance_id, "invalid candidate replaced existing native World")
	invalid = scene.duplicate(true)
	Document.plane(invalid, "effects").clock.rate_hz = 1
	expect(not owner.prepare(invalid, owner.generation()).ok, "unsupported dynamic clock admitted")
	for bad_value: Variant in [1, "true", [], {}, null]:
		invalid = scene.duplicate(true)
		Document.plane(invalid, "effects").clock.paused = bad_value
		expect(not Document.validate(invalid).is_empty(), "invalid static bool returned successful validation")
	for field: String in ["format", "content_domain"]:
		invalid = scene.duplicate(true)
		invalid[field] = 1
		expect(not Document.validate(invalid).is_empty(), "invalid scene text field returned successful validation")
	invalid = scene.duplicate(true)
	Document.plane(invalid, "scripted").id = 1
	expect(not Document.validate(invalid).is_empty(), "invalid plane text ID returned successful validation")
	invalid = scene.duplicate(true)
	Document.plane(invalid, "effects").clock.mode = 1
	expect(not Document.validate(invalid).is_empty(), "invalid clock text ID returned successful validation")
	invalid = scene.duplicate(true)
	Document.plane(invalid, "play").rectangles = [[1, 1, 1, 1, 13]]
	expect(not owner.prepare(invalid, owner.generation()).ok, "second authored play layout admitted")
	invalid = scene.duplicate(true)
	Document.plane(invalid, "background").rectangles = [[511, 511, 2, 2, 13]]
	expect(not owner.prepare(invalid, owner.generation()).ok, "out-of-bounds candidate admitted")
	expect(not owner.prepare(scene, owner.generation() - 1).ok, "stale candidate generation admitted")
	expect(owner.update_settings("scripted", {"locked": true}), "lock rejected")
	expect(not owner.paint_disc("scripted", Vector2i(24, 24), 2, 7).ok, "locked plane edited")
	expect(owner.capture_region("scripted", Rect2i(20, 20, 4, 4)).ok, "visible locked plane could not be copied")
	expect(owner.update_settings("scripted", {"locked": false, "visible": false}), "hide rejected")
	expect(not owner.paint_disc("scripted", Vector2i(24, 24), 2, 7).ok, "hidden plane edited")
	expect(not owner.capture_region("scripted", Rect2i(20, 20, 4, 4)).ok, "hidden plane copied")
	owner.update_settings("scripted", {"visible": true})
	owner.update_settings("scripted", {"opacity": 0.0})
	expect(not owner.paint_disc("scripted", Vector2i(24, 24), 2, 7).ok, "fully transparent plane edited")
	expect(not owner.capture_region("scripted", Rect2i(20, 20, 4, 4)).ok, "fully transparent plane copied")
	owner.update_settings("scripted", {"opacity": 1.0})
	owner.set_presentation({"enabled": false})
	expect(not owner.paint_disc("scripted", Vector2i(24, 24), 2, 7).ok, "disabled decorative presentation received edit")
	owner.set_presentation({"enabled": true})
	owner.set_presentation({"solo": "effects"})
	expect(not owner.paint_disc("scripted", Vector2i(24, 24), 2, 7).ok, "solo-filtered plane edited")
	owner.set_presentation({"solo": "", "mode": "flat", "active": "effects"})
	expect(not owner.paint_disc("scripted", Vector2i(24, 24), 2, 7).ok, "flat-hidden plane edited")
	owner.set_presentation({"mode": "stack", "active": "scripted"})
	var painted := owner.paint_disc("scripted", Vector2i(24, 24), 2, 7)
	expect(painted.get("ok", false), "bounded native brush failed: " + str(painted.get("error", "")))
	expect(owner.material_at("scripted", Vector2i(24, 24)) == 7, "native brush readback differs")
	expect(owner.material_at("effects", Vector2i(24, 24)) == 0, "rear brush changed effects plane")
	expect(owner.undo("scripted").ok and owner.material_at("scripted", Vector2i(24, 24)) == 13, "Undo did not restore native material")
	expect(owner.redo("scripted").ok and owner.material_at("scripted", Vector2i(24, 24)) == 7, "Redo did not restore native material")
	expect(not owner.paint_disc("scripted", Vector2i(0, 0), 2, 7).ok, "boundary-crossing brush partially applied")
	expect(not owner.paint_cells("scripted", PackedInt32Array([30, 30, 7]), 0).ok, "stale paint generation admitted")
	expect(not owner.paint_cells("scripted", PackedInt32Array([30, 30, 7, 29, 30, 7])).ok, "unordered paint admitted")
	expect(not owner.paint_cells("scripted", PackedInt32Array([30, 30, 10])).ok, "invalid native material admitted")
	expect(not owner.capture_region("scripted", Rect2i(0, 0, 129, 128)).ok, "oversized selection admitted")
	var capture := owner.capture_region("scripted", Rect2i(23, 23, 3, 3))
	expect(capture.ok and capture.materials.size() == 9 and capture.materials[4] == 7, "native selection readback differs")
	expect(owner.paint_disc("scripted", Vector2i(24, 24), 1, 0).ok, "native eraser failed")
	expect(owner.material_at("scripted", Vector2i(24, 24)) == 0, "eraser did not write Empty")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var setup := Setup.fresh(bridge.default_liquid_policy(), Vector2i(512, 512))
	setup.edits = [[8, 450, 496, 4, 58]]
	var name := "strata-layers-regression"
	expect(Document.write_named(name, setup, {}, {}, owner.document()).is_empty(), "authored composition Save failed")
	var restored := Document.read_named(name)
	expect(restored.get("layered", false), "saved composition was not recognized: " + str(restored.get("error", "")))
	if restored.get("layered", false):
		var reowner := Owner.new()
		var reload := reowner.prepare(restored.document)
		expect(reload.ok and reowner.commit(reload.token), "saved decorative composition failed native reopening")
		expect(reowner.material_at("scripted", Vector2i(24, 24)) == 0, "saved erase overlay was silently lost")
		expect(reowner.material_at("scripted", Vector2i(25, 25)) == 7, "saved paint overlay was silently lost")
		expect(reowner.stats().layers.scripted.native_tick == 0, "authored reopen claimed evolved continuation")
		reowner.retire()
	var saved_bytes := FileAccess.get_file_as_bytes(Setup._path(name))
	if saved_bytes.is_empty():
		quit(1)
		return
	var changed := saved_bytes.duplicate()
	changed[changed.size() - 1] ^= 1
	var corrupted := FileAccess.open(Setup._path(name), FileAccess.WRITE)
	corrupted.store_buffer(changed)
	corrupted.close()
	expect(Document.read_named(name).has("error"), "corrupt envelope checksum accepted")
	expect(owner.material_at("scripted", Vector2i(24, 24)) == 0, "failed load altered live native material")
	expect(Document.write_named(name, setup, {}, {}, owner.document()).is_empty(), "atomic replacement of existing scene failed")
	var replacement_read := Document.read_named(name)
	expect(replacement_read.get("layered", false), "replacement scene cannot reopen: " + str(replacement_read.get("error", "")))
	var material_bytes := PackedByteArray()
	material_bytes.resize(512 * 512 * 2)
	material_bytes.fill(0)
	material_bytes.encode_u16(0, 13)
	var baseline := {"schema": 1, "extent": Vector2i(512, 512), "cells": material_bytes,
		"sha256": GeneratedMaps.digest(material_bytes)}
	expect(Document.write_named(name, setup, {}, baseline, owner.document()).is_empty(), "GEN-008 authored baseline could not be wrapped")
	var baseline_read := Document.read_named(name)
	expect(baseline_read.get("layered", false) and baseline_read.get("baseline", {}).get("cells", PackedByteArray()) == material_bytes,
		"GEN-008 authored baseline bytes did not survive Strata envelope")
	expect(owner.stats().layers.scripted.undo > 0, "Save cleared decorative Undo history")
	var generated := _native_generated_play()
	if not generated.is_empty():
		expect(Document.write_named(name, setup, generated, {}, owner.document()).is_empty(), "Native generated play source could not be wrapped")
		var generated_read := Document.read_named(name)
		expect(generated_read.get("layered", false), "Generated Strata envelope could not reopen: " + str(generated_read.get("error", "")))
		if generated_read.get("layered", false):
			expect(generated_read.generated.cells == generated.cells, "Saved generated play bytes changed")
			# Existing generated-start identity normalizes JSON integral numbers;
			# Array/Dictionary Variant equality distinguishes parsed floats.
			expect(GeneratedMaps.recipe_hash(GeneratedMaps.provenance(generated_read.generated)) \
				== GeneratedMaps.recipe_hash(GeneratedMaps.provenance(generated)), "Saved native generated provenance changed")
		var bad_generated := generated.duplicate(true)
		bad_generated.plane_revision = 7
		expect(not Document.write_named(name, setup, bad_generated, {}, owner.document()).is_empty(), "Invalid generated scalar type bypassed save admission")
	var replacing := owner.prepare(scene, owner.generation())
	expect(replacing.ok, "valid replacement could not prepare")
	owner.cancel(replacing.token)
	expect(not owner.commit(replacing.token), "cancelled candidate committed")
	expect(owner.material_at("scripted", Vector2i(24, 24)) == 0, "cancelled replacement changed current material")
	for id: String in Owner.IDS:
		expect(owner.stats().layers[id].native_tick == 0, "static plane advanced native physics")
	owner.retire()
	expect(owner.stats().native_world_count == 0 and owner.stats().pending_native_world_count == 0, "retirement left native owners resident")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Setup._path(name)))
	print("STRATA_LAYER_REGRESSION ", JSON.stringify({"checks": checks, "failures": failures,
		"godot": Engine.get_version_info().string, "backend": "CyberNativeCellWorld", "domain": "headless-layer-owner-only"}))
	quit(1 if failures else 0)


func _native_generated_play() -> Dictionary:
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var recipe := {"schema": 1, "seed": 17, "chunk_size": 64, "candidate": "strata"}
	var configured: Dictionary = generator.configure(recipe)
	expect(configured.get("ok", false), "Native generated-source fixture configuration failed")
	if not configured.get("ok", false): return {}
	var cells := PackedByteArray()
	cells.resize(512 * 512)
	var receipts: Array = []
	for cy: int in 8:
		for cx: int in 8:
			var chunk: Dictionary = generator.generate_chunk(Vector2i(cx, cy))
			if not chunk.get("ok", false):
				expect(false, "Native generated-source fixture chunk failed")
				return {}
			for y: int in 64:
				for x: int in 64:
					cells[(cy * 64 + y) * 512 + cx * 64 + x] = chunk.cells[y * 64 + x]
			receipts.append(str(chunk.receipt_hash))
	return {"recipe": recipe, "origin": Vector2i.ZERO, "extent": Vector2i(512, 512), "cells": cells,
		"sha256": GeneratedMaps.digest(cells), "recipe_sha256": GeneratedMaps.recipe_hash(recipe),
		"generator_fingerprint": str(configured.fingerprint), "plane_revision": str(configured.get("plane_fingerprint", "")),
		"generator_revision": int(configured.revision), "receipt_hashes": receipts}
