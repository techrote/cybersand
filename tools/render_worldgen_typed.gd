extends SceneTree

# Source- and runtime-labelled native proposal images, not simulation/GPU claims.
# Per-chunk receipts bind the typed values; the manifest retains native metadata.
# Colour mapping reuses the actual Workbench presentation helper.
const Workbench = preload("res://scripts/worldgen_workbench.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const CASES: Array[Dictionary] = [
	{"name":"typed-industrial-structure", "channel":"spatial:bracing"},
	{"name":"typed-vector-utilities", "channel":"spatial:tangent"},
	{"name":"typed-categorical-districts", "channel":"spatial:district"},
	{"name":"typed-reusable-decay", "channel":"spatial:north.mask"},
	{"name":"typed-multiscale-seeds", "channel":"spatial:seed_region"},
]
const ORIGIN := Vector2i(-128, 0)
const EXTENT := Vector2i(256, 192)
const SOURCE_PATHS: Array[String] = [
	"native/include/cybersand/generation_typed_fields.hpp", "native/src/generation_typed_fields.cpp",
	"native/include/cybersand/generation_spatial.hpp", "native/src/generation_spatial.cpp",
	"native/include/cybersand/world_generation.hpp", "native/src/world_generation.cpp",
	"godot/native_extension/cyber_world_generator.cpp", "godot/scripts/worldgen_workbench.gd",
	"tools/render_worldgen_typed.gd",
]

func _init() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		fail("A source-matched native generation runtime is required.")
		return
	var output: String = ProjectSettings.globalize_path("res://../build/worldgen-typed")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--output": output = args[1]
	elif not args.is_empty():
		fail("usage: -- --output /absolute/output/folder")
		return
	if not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create output directory: " + output)
		return
	var source: Dictionary = {}
	for path: String in SOURCE_PATHS:
		source[path] = FileAccess.get_sha256(ProjectSettings.globalize_path("res://../" + path))
	var runtime_name: String = "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var runtime_path: String = "res://addons/cybersand_native/bin/" + runtime_name
	var records: Array[Dictionary] = []
	for item: Dictionary in CASES:
		var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/" + str(item.name) + ".json")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			fail("Cannot parse example: " + path)
			return
		var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var accepted: Dictionary = generator.configure(parsed)
		if not bool(accepted.get("ok",false)):
			fail(str(item.name) + ": " + str(accepted.get("error","configure failed")))
			return
		var size: int = int(parsed.chunk_size)
		if EXTENT.x % size != 0 or EXTENT.y % size != 0 or ORIGIN.x % size != 0:
			fail("Render extent must divide each example's chunk size.")
			return
		var materials := Image.create(EXTENT.x, EXTENT.y, false, Image.FORMAT_RGBA8)
		var typed := Image.create(EXTENT.x, EXTENT.y, false, Image.FORMAT_RGBA8)
		var operations: int = 0
		var receipts: Array[Dictionary] = []
		var info: Dictionary = {}
		for cy: int in range(EXTENT.y / size):
			for cx: int in range(EXTENT.x / size):
				var coordinate := Vector2i(ORIGIN.x / size + cx, ORIGIN.y / size + cy)
				var packet: Dictionary = generator.generate_chunk(coordinate,str(item.channel))
				if not bool(packet.get("ok",false)) or str(packet.get("state","")) != "ready":
					fail(str(item.name) + ": " + str(packet.get("error","generation failed")))
					return
				operations += int(packet.operations)
				info = packet.diagnostic_info
				receipts.append({"chunk":[coordinate.x,coordinate.y], "hash":packet.hash, "receipt_hash":packet.receipt_hash})
				for y: int in range(size):
					for x: int in range(size):
						var index: int = y * size + x
						var color := Color.hex(int(Palette.BASE_RGBA8[int(packet.cells[index])]))
						color.a = 1
						materials.set_pixel(cx * size + x, cy * size + y,color)
						typed.set_pixel(cx * size + x, cy * size + y,Workbench.spatial_diagnostic_color(packet,index))
		if materials.save_png(output.path_join(str(item.name) + "-materials.png")) != OK or typed.save_png(output.path_join(str(item.name) + "-typed.png")) != OK:
			fail("Cannot write typed example previews.")
			return
		records.append({"name":item.name, "recipe_sha256":FileAccess.get_sha256(path), "diagnostic":item.channel, "diagnostic_info":info,
			"fingerprint":accepted.fingerprint, "operations":operations, "chunks":receipts, "origin":[ORIGIN.x,ORIGIN.y], "extent":[EXTENT.x,EXTENT.y]})
		print("Rendered GEN-003 ",item.name,": ",receipts.size()," chunks; ",operations," declared operations")
	var report := FileAccess.open(output.path_join("render-manifest.json"),FileAccess.WRITE)
	if report == null:
		fail("Cannot write typed example manifest.")
		return
	report.store_string(JSON.stringify({"schema":1, "godot_version":Engine.get_version_info(), "platform":OS.get_name(),
		"runtime":runtime_path, "runtime_sha256":FileAccess.get_sha256(runtime_path), "source_sha256":source, "cases":records},"  ",true,true) + "\n")
	report.close()
	quit(0)
