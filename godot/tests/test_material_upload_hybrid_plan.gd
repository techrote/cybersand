extends SceneTree

# Headless checks cover planning/admission only, never graphical performance.
const Hybrid = preload("res://scripts/material_upload_hybrid.gd")
var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var h := Hybrid.new()
	h._size = Vector2i(513, 257)
	h._grid = Vector2i(9, 5)
	h._channels = 2
	h._format = Image.FORMAT_RG8
	var journal := PackedByteArray()
	journal.resize(45)
	h._mark_rectangles(journal, PackedInt32Array([512, 256, 1, 1, 0, 2]))
	var edge: Dictionary = h._plan(journal)
	_expect(edge.area == 1 and edge.dirty_tiles == 1, "partial edge tile has exact clipped area")
	_expect(edge.rectangles == [Rect2i(512, 256, 1, 1)], "edge region remains in image")
	journal.fill(0)
	h._mark_rectangles(journal, PackedInt32Array([63, 63, 2, 2, 0, 4]))
	var crossing: Dictionary = h._plan(journal)
	_expect(crossing.dirty_tiles == 4 and crossing.area == 16384, "tile crossing covers all four tiles")
	_expect(crossing.rectangles == [Rect2i(0, 0, 128, 128)], "adjacent row runs coalesce exactly")
	_expect(not crossing.sparse, "coverage beyond one sixteenth requires compact path")
	h._size = Vector2i(2048, 2048)
	h._grid = Vector2i(32, 32)
	journal.resize(1024)
	journal.fill(0)
	for i: int in range(9):
		h._mark_rectangles(journal, PackedInt32Array([i * 128, 0, 1, 1, 0, 2]))
	var scattered: Dictionary = h._plan(journal)
	_expect(scattered.area == 9 * 4096 and scattered.rectangles.size() == 9,
		"scattered accounting includes every distinct region")
	_expect(not scattered.sparse and scattered.reason == "fragmentation", "bounded staging-call count")
	h.initialized = true
	h.accepted_serial = 10
	h.accepted_generation = 3
	var image := Image.create_empty(2048, 2048, false, Image.FORMAT_RG8)
	var metadata := PackedInt32Array([2047, 2047, 1, 1, 0, 2])
	_expect(h._publication_error(image, metadata, 11, 3, false).is_empty(), "final cell admitted")
	_expect(not h._publication_error(image, metadata, 10, 3, false).is_empty(), "repeated serial refused")
	_expect(not h._publication_error(image, metadata, 11, 2, false).is_empty(), "stale generation refused")
	_expect(not h._publication_error(image, metadata, 11, 4, false).is_empty(), "partial replacement refused")
	_expect(not h._publication_error(image, metadata, 11, 3, true).is_empty(), "false full coverage refused")
	var full := PackedInt32Array([0, 0, 2048, 2048, 0, 4096])
	_expect(h._publication_error(image, full, 11, 4, true).is_empty(), "complete generation replacement admitted")
	metadata[2] = 2
	_expect(not h._publication_error(image, metadata, 11, 3, false).is_empty(), "crossing last cell refused")
	h.close()
	var result := {"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"scope": "headless journal and metadata admission; no GPU evidence"}
	print("MATERIAL_UPLOAD_HYBRID_PLAN ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
