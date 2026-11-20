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
	var host: Control = load("res://web_main.tscn").instantiate()
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	expect(host.ready_to_play and host.native_world.get_wave_flow_status().enabled
		and host.native_world.get_wave_flow_status().spill.parcels, "Ordinary Web controller starts Wave with spray")
	expect(not host._encode_current().ok and host._encode_current().error.contains("FreeMass"), "Wave save explains the CYSD1 boundary")
	host.ui.next_water.item_selected.emit(1)
	expect(host.native_world.get_wave_flow_status().enabled, "Web law selection is staged until a new demo")
	host.select_demo("waterworks",false)
	expect(not host.native_world.get_wave_flow_status().enabled and host._encode_current().ok,"explicit FreeMass game may save")
	host.ui.next_water.item_selected.emit(0)
	host.select_demo("neon_works",false)
	expect(host.native_world.get_wave_flow_status().enabled, "new demo returns to Wave on request")
	host.import_save(encoded.text)
	expect(host.last_save_error.is_empty() and not host.gameplay_water and host.ui.next_water.selected == 1
		and not host.native_world.get_wave_flow_status().enabled and bridge.export_level(host.native_world) == original,
		"actual controller imports the legacy slot exactly and retains its law for restart")
	host.restart_world()
	expect(not host.native_world.get_wave_flow_status().enabled, "explicit legacy law survives restart")
	host.queue_free()
	await process_frame
	print("Web demo setup fixture: four constructors, stepping, CYSD1 and native rejection; failures=", failures)
	quit(0 if failures == 0 else 1)
