extends SceneTree

# Execute through the real GDExtension; never substitute a scripted solver.
# CYSD1 payload equality checks stored state, not exact tick continuation.
var failures: int = 0
var assertions: int = 0

func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh_world() -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers": 1, "telemetry": false}), "Phase fixture reset failed")
	world.set_simulation_window_enabled(false)
	expect(world.diagnostic_fill_rect(Vector2i(7, 7), Vector2i(4, 3), 1), "Phase fixture walls failed")
	return world

func await_material(world: Variant, bridge: Variant, point: Vector2i, material: int, limit: int) -> Dictionary:
	var cell: Dictionary = bridge.inspect_cell(world, point)
	for tick: int in range(limit):
		if int(cell.material) == material:
			break
		expect(world.simulation_tick(), "Phase fixture tick failed")
		cell = bridge.inspect_cell(world, point)
	expect(int(cell.material) == material, "Expected phase material %d at %s; got %s" % [material, point, cell])
	return cell

func _initialize() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		push_error("The current rebuilt native runtime is required for MAT-002")
		quit(1)
		return
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var profile: Dictionary = bridge.inspect_interaction_profile()
	expect(int(profile.profile_version) == 2, "Stale interaction profile: MAT-002 requires version 2")
	for quantity: int in [1, 32, 255]:
		for reversed: bool in [false, true]:
			var world: Variant = fresh_world()
			var hot: Vector2i = Vector2i(9, 8) if reversed else Vector2i(8, 8)
			var wet: Vector2i = Vector2i(8, 8) if reversed else Vector2i(9, 8)
			expect(world.diagnostic_fill_rect(hot, Vector2i.ONE, 8), "Lava setup failed")
			expect(world.water_experiment_fill_rect(wet, Vector2i.ONE, quantity, 0), "Partial Water setup failed")
			var vapour: Dictionary = await_material(world, bridge, wet, 22, 32)
			var lava: Dictionary = bridge.inspect_cell(world, hot)
			expect(int(vapour.state_b) == (0 if quantity == 255 else quantity), "Steam lost the original Water quantity")
			expect(int(lava.material) == (13 if quantity == 255 else 8), "Quench ignored actual coolant quantity")
			if quantity < 255:
				expect(int(lava.state_b) == quantity, "Lava did not retain cumulative quench progress")
			expect(world.diagnostic_fill_rect(hot, Vector2i.ONE, 1), "Hot-source removal failed")
			var liquid: Dictionary = await_material(world, bridge, wet, 3, 256)
			expect(int(liquid.state_a) == quantity, "Condensation refilled a partial parcel")
			var observation: Dictionary = world.water_experiment_observation(Vector2i(8, 8), Vector2i(2, 1))
			expect(int(observation.water_integer) == quantity, "Liquid observation disagrees with restored quantity")

	var saved_world: Variant = fresh_world()
	expect(saved_world.diagnostic_fill_rect(Vector2i(8, 8), Vector2i.ONE, 8, 17), "Quench save fixture failed")
	expect(saved_world.diagnostic_fill_rect(Vector2i(9, 8), Vector2i.ONE, 22, 32), "Steam save fixture failed")
	expect(saved_world.diagnostic_fill_rect(Vector2i(16, 8), Vector2i.ONE, 9, 13), "Ice save fixture failed")
	var original: PackedByteArray = bridge.export_level(saved_world)
	expect(original.size() == 1024 * 1024 * 5, "Phase snapshot length is wrong")
	var restored: Variant = fresh_world()
	expect(bridge.import_level(restored, original), "Valid quantity-bearing phase snapshot rejected")
	var roundtrip: PackedByteArray = bridge.export_level(restored)
	expect(roundtrip == original, "Phase payload or quench state changed on save/load")
	var restored_steam: Dictionary = bridge.inspect_cell(restored, Vector2i(9, 8))
	var restored_ice: Dictionary = bridge.inspect_cell(restored, Vector2i(16, 8))
	var restored_lava: Dictionary = bridge.inspect_cell(restored, Vector2i(8, 8))
	expect(int(restored_steam.state_b) == 32 and int(restored_ice.state_b) == 13 and int(restored_lava.state_b) == 17, "Save/load changed material-local quantity semantics")

	var revision: int = int(restored.get_revision())
	var invalid: PackedByteArray = original.duplicate()
	invalid[(8 * 1024 + 8) * 5 + 2] = 255 # Invalid unfinished Lava progress.
	expect(not bridge.import_level(restored, invalid), "Invalid quench payload was installed")
	expect(int(restored.get_revision()) == revision and not restored.has_failed(), "Rejected import changed active-world ownership")
	expect(bridge.export_level(restored) == original, "Rejected phase import partially replaced stored state")
	for material: int in [8, 36]:
		expect(not restored.diagnostic_fill_rect(Vector2i(8, 8), Vector2i(2, 1), material, 255), "Godot diagnostic input accepted invalid quench state")
	expect(not restored.diagnostic_fill_rect(Vector2i(8, 8), Vector2i(2, 1), 3, 13), "Godot diagnostic input accepted invalid Water coherence")
	expect(int(restored.get_revision()) == revision and bridge.export_level(restored) == original, "Rejected diagnostic rectangle partially mutated phase payload")

	# Legacy/painted Steam has b=0 and still condenses to one full cell.
	var legacy: Variant = fresh_world()
	expect(legacy.diagnostic_fill_rect(Vector2i(9, 8), Vector2i.ONE, 22), "Legacy Steam setup failed")
	var legacy_water: Dictionary = await_material(legacy, bridge, Vector2i(9, 8), 3, 256)
	expect(int(legacy_water.state_a) == 255, "Legacy zero quantity sentinel stopped representing a full parcel")
	print("MAT002_PHASE_QUANTITY: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
