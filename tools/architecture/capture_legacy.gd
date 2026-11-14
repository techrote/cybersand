extends SceneTree

# Run this same probe with separately built baseline and candidate runtimes.
# It records native material bytes, never rendered screenshots as an oracle.
const Store = preload("res://scripts/workbench_generated_map.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func fail(detail: String) -> void:
	failures += 1
	push_error(detail)

func capture(name: String, bounds: Rect2i) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://../examples/worldgen/" + name + ".json")
	var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not recipe is Dictionary:
		fail("Missing legacy recipe " + path)
		return {}
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var accepted: Dictionary = generator.configure(recipe)
	if not accepted.get("ok", false):
		fail("Legacy configure refused " + name + ": " + str(accepted))
		return {}
	var cells := PackedByteArray()
	var receipts: Array = []
	if accepted.has("plane_fingerprint"):
		var result: Dictionary = generator.begin_plane_region(bounds)
		var turns := 0
		while result.get("ok", false) and result.get("state", "") == "running" and turns < 10000:
			result = generator.advance_plane_region(4096)
			turns += 1
		if not result.get("ok", false) or result.get("state", "") != "ready":
			fail("Legacy plane generation failed " + name + ": " + str(result))
			return {}
		cells = result.materials.play
		receipts.append(result.receipt_hash)
	else:
		cells.resize(bounds.size.x * bounds.size.y)
		var side: int = int(recipe.get("chunk_size", 128))
		var first := Vector2i(floori(float(bounds.position.x) / side), floori(float(bounds.position.y) / side))
		var last := Vector2i(floori(float(bounds.end.x - 1) / side), floori(float(bounds.end.y - 1) / side))
		for cy: int in range(first.y, last.y + 1):
			for cx: int in range(first.x, last.x + 1):
				var result: Dictionary = generator.generate_chunk(Vector2i(cx, cy))
				if not result.get("ok", false):
					fail("Legacy chunk generation failed " + name + ": " + str(result))
					return {}
				receipts.append(result.receipt_hash)
				for y: int in side:
					for x: int in side:
						var p := Vector2i(cx * side + x, cy * side + y)
						if bounds.has_point(p):
							cells[(p.y - bounds.position.y) * bounds.size.x + p.x - bounds.position.x] = result.cells[y * side + x]
	return {"recipe_sha256": Store.recipe_hash(recipe), "schema": recipe.get("schema", 1),
		"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"material_sha256": Store.digest(cells), "cells": cells.size(),
		"fingerprint": accepted.fingerprint, "receipt_sha256": Store.recipe_hash({"receipts": receipts})}

func run() -> void:
	var output: Dictionary = {"schema": 1, "godot": Engine.get_version_info().string, "profiles": {}}
	for item: Array in [
		["district-arcology", Rect2i(-256, -128, 512, 512)],
		["sidechained-arcology", Rect2i(-256, 0, 512, 512)],
		["typed-categorical-districts", Rect2i(-64, -64, 128, 128)],
		["hierarchy-multi-district", Rect2i(-128, -128, 256, 256)],
		["gen007-deepworks", Rect2i(0, 0, 256, 256)]]:
		output.profiles[item[0]] = capture(item[0], item[1])
	var destination := OS.get_environment("CYBERSAND_LEGACY_OUTPUT")
	if destination.is_empty(): destination = "user://architectural-legacy-materials.json"
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null: fail("Cannot write legacy receipt " + destination)
	else: file.store_string(JSON.stringify(output, "\t", true, true) + "\n")
	print("ARCHITECTURE_LEGACY checks=5 failures=", failures)
	quit(1 if failures else 0)
