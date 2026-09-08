extends SceneTree

# Setup regression: exercise the demo/save adapters through the real native DLL.
# The browser's opt-in startup probe also exercises a native exception in WASM.
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not CyberWebCapabilities.native_available():
		push_error("Native demo classes unavailable")
		quit(1)
		return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	for id: String in ["material_lab", "waterworks", "foundry", "neon_works"]:
		expect(bridge.build_world(world, CyberDemoWorlds.rectangles(id)), "Demo construction: " + id)
		world.set_simulation_window(Vector2i.ZERO, Vector2i(480, 270), 32, 32)
		expect(world.simulation_tick(), "Native step: " + id)
	var original: PackedByteArray = bridge.export_level(world)
	expect(original.size() == CyberDemoSaveCodec.WORLD_BYTES, "Bulk snapshot length")
	var metadata: Dictionary = {"demo": "neon_works", "player": [24.0, 222.0, 0.0, 0.0], "material": 2, "quality": 1, "coherent": false, "adhesion": true, "glow": true, "bodies": []}
	var encoded: Dictionary = CyberDemoSaveCodec.encode(original, metadata)
	expect(encoded.ok, "CYSD1 encode")
	if not encoded.ok:
		quit(1)
		return
	var decoded: Dictionary = CyberDemoSaveCodec.decode_text(encoded.text)
	expect(decoded.ok, "CYSD1 decode")
	if decoded.ok:
		expect(decoded.world == original, "CYSD1 exact bulk round trip")
		expect(bridge.build_world(world, CyberDemoWorlds.rectangles("waterworks")), "Switch world")
		expect(bridge.import_level(world, decoded.world), "Native restore")
		expect(bridge.export_level(world) == original, "Restored native level differs")
	expect(not CyberDemoSaveCodec.decode_text("a").ok, "Malformed Base64 accepted")
	var corrupt: PackedByteArray = encoded.binary.duplicate()
	corrupt[corrupt.size() - 1] ^= 1
	expect(not CyberDemoSaveCodec.decode_binary(corrupt).ok, "Corrupt digest accepted")
	expect(not bridge.import_level(world, PackedByteArray()), "Invalid native length accepted")
	expect(bridge.get_last_error() == "Wrong world payload length", "Native exception was not caught")
	var invalid: PackedByteArray = original.duplicate()
	invalid[0] = 255
	expect(not bridge.import_level(world, invalid), "Invalid material accepted")
	expect(bridge.export_level(world) == original, "Invalid native import changed level")
	print("Web demo setup fixture: four constructors, stepping, CYSD1 and native rejection; failures=", failures)
	quit(0 if failures == 0 else 1)
