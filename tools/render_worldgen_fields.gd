extends SceneTree

# Reproducible, native-material/diagnostic evidence. This does not run simulation
# or establish rendered GPU, Windows or frame-time acceptance.
const Palette = preload("res://scripts/material_appearance_lut.gd")
const CASES: Array[Dictionary] = [
	{"name": "hilbert-seams", "channel": "modifier:cyan_hilbert_traces"},
	{"name": "weathered-aggregate", "channel": "modifier:weathered_surface"},
	{"name": "sidechained-arcology", "channel": "module:weathered_arcology"},
]
const ORIGIN := Vector2i(-256, 0)
const EXTENT := Vector2i(512, 384)

func _init() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		fail("A source-matched native generation runtime is required.")
		return
	var output: String = ProjectSettings.globalize_path("res://../build/worldgen-fields")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--output":
		output = args[1]
	elif not args.is_empty():
		fail("usage: -- --output /absolute/output/folder")
		return
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create absolute output directory: " + output)
		return
	var records: Array[Dictionary] = []
	for item: Dictionary in CASES:
		var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/" + str(item.name) + ".json")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			fail("Cannot parse generation example: " + path)
			return
		var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var accepted: Dictionary = generator.configure(parsed)
		if not bool(accepted.get("ok", false)):
			fail(str(item.name) + ": " + str(accepted.get("error", "configure failed")))
			return
		var size: int = int(parsed.get("chunk_size", 128))
		if EXTENT.x % size != 0 or EXTENT.y % size != 0 or ORIGIN.x % size != 0:
			fail("Example extent must divide its configured chunk size.")
			return
		var materials := Image.create(EXTENT.x, EXTENT.y, false, Image.FORMAT_RGBA8)
		var mask := Image.create(EXTENT.x, EXTENT.y, false, Image.FORMAT_RGBA8)
		var operations: int = 0
		var receipts: Array[Dictionary] = []
		for cy: int in range(EXTENT.y / size):
			for cx: int in range(EXTENT.x / size):
				var coordinate := Vector2i(ORIGIN.x / size + cx, ORIGIN.y / size + cy)
				var packet: Dictionary = generator.generate_chunk(coordinate, str(item.channel))
				if not bool(packet.get("ok", false)) or str(packet.get("state", "")) != "ready":
					fail(str(item.name) + ": " + str(packet.get("error", "generation failed")))
					return
				operations += int(packet.operations)
				receipts.append({"chunk": [coordinate.x, coordinate.y], "hash": packet.hash, "receipt_hash": packet.receipt_hash})
				for y: int in range(size):
					for x: int in range(size):
						var index: int = y * size + x
						var color := Color.hex(int(Palette.BASE_RGBA8[int(packet.cells[index])]))
						color.a = 1.0
						materials.set_pixel(cx * size + x, cy * size + y, color)
						var value: float = float(packet.diagnostics[index])
						mask.set_pixel(cx * size + x, cy * size + y, Color(value, value, value, 1.0))
		if materials.save_png(output.path_join(str(item.name) + "-materials.png")) != OK or mask.save_png(output.path_join(str(item.name) + "-mask.png")) != OK:
			fail("Cannot write example images.")
			return
		records.append({"name": item.name, "diagnostic": item.channel, "fingerprint": accepted.fingerprint,
			"revision": accepted.revision, "operations": operations, "chunks": receipts,
			"origin": [ORIGIN.x, ORIGIN.y], "extent": [EXTENT.x, EXTENT.y]})
		print("Rendered native example ", item.name, ": ", receipts.size(), " chunks; ", operations, " logical operations")
	var report := FileAccess.open(output.path_join("render-manifest.json"), FileAccess.WRITE)
	if report == null:
		fail("Cannot write render manifest.")
		return
	report.store_string(JSON.stringify({"schema": 1, "algorithm_version": 2, "cases": records}, "  ") + "\n")
	report.close()
	quit(0)
