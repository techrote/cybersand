extends SceneTree

# Every starting World now carries ballistic Water/solids (hash and snapshot
# format 4). Older format-2 continuation snapshots and level saves made by a
# World without ballistic owners must still load into it with every cell intact.
var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("BALLISTIC_OLD_SNAPSHOTS: " + message)
	return ok

func cells(world: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y: int in range(0, 180, 3):
		for x: int in range(0, 320, 3): out.append(world.material_at(x, y))
	return out

func _initialize() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var old: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	# diagnostic_reset builds a World without ballistic owners: the old format.
	expect(old.diagnostic_reset({"workers":1}), "old-format World")
	expect(bridge.build_world(old, PackedInt32Array([0,0,1,1,2])), "old-format content")
	for _t: int in range(6): old.simulation_tick()
	expect(old.get_physical_state_hash_version() == 2, "reference World uses the old format 2")
	var snapshot: PackedByteArray = bridge.export_physical_state(old)
	var level: PackedByteArray = bridge.export_level(old)
	expect(not snapshot.is_empty() and snapshot.decode_u32(4) == 2, "old snapshot is format 2")
	var current: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(current.get_physical_state_hash_version() == 4, "starting World is ballistic (format 4)")
	if expect(bridge.import_physical_state(current, snapshot), "format-2 snapshot loads into the ballistic starting World"):
		expect(cells(current) == cells(old), "loaded snapshot keeps every sampled cell")
		expect(current.simulation_tick(), "loaded snapshot keeps simulating")
	var fresh: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if expect(bridge.import_level(fresh, level), "level saved by an old-format World loads"):
		expect(cells(fresh) == cells(old), "loaded level keeps every sampled cell")
	# Render cadence: with the grid at rest, a ballistic cell in flight must still
	# advance the presentation revision every tick (otherwise it looks frozen).
	var still: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	# Erase the demo content so nothing on the grid keeps moving.
	for y: int in range(0, 1024, 48):
		for x: int in range(0, 1024, 48): still.paint_disc(x, y, 40, 0)
	var settled := false
	for _t: int in range(3000):
		var before: int = still.revision
		still.simulation_tick()
		if still.revision == before:
			settled = true
			break
	if expect(settled, "starting World settles"):
		var outcome: Variant = still.inject_solid_parcel(Vector2(500.0, 100.0), Vector2(1.5, -0.5), 2)
		expect(still.get_ballistic_solids().get("live", 0) == 1, "ballistic Sand launched: " + str(outcome))
		var frozen := 0
		for _t: int in range(6):
			var before: int = still.revision
			still.simulation_tick()
			if still.revision == before: frozen += 1
		expect(frozen == 0, "every in-flight tick advances the render revision (%d frozen)" % frozen)
	print("BALLISTIC_OLD_SNAPSHOTS %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))
