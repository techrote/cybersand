extends SceneTree

# Strict CPU image payload conformance; no World/Rapier/GPU access or ACK shortcut.
const Consumer = preload("res://scripts/solid_detachment_render_consumer.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 RENDER ACK ", message)

func packet(serial: int,generation: int,full: bool,
		rects: PackedInt32Array,cells: PackedByteArray) -> CyberSimulationSnapshot:
	var result := CyberSimulationSnapshot.new()
	result.render_snapshot_serial = serial
	result.render_world_generation = generation
	result.render_channels = 2
	result.render_full_refresh = full
	result.render_patch_rectangles = rects
	result.render_patch_cells = cells
	return result

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var consumer = Consumer.new()
	var entire := PackedByteArray()
	entire.resize(CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2)
	entire[0] = 43
	entire[1] = 190
	entire[entire.size()-2] = 77
	var full := PackedInt32Array([0,0,1024,1024,0,2048])
	check(consumer.consume(packet(1,1,true,full,entire)), "complete full frame consumed")
	check(consumer.last_serial == 1, "serial advances after complete consumption")
	check(consumer.material_at(0,0) == 43 and consumer.material_at(1023,1023) == 77,
		"CPU image contains both full-frame corners")
	var patch := PackedByteArray([2,99,3,98,4,97,5,96])
	check(consumer.consume(packet(2,1,false,PackedInt32Array([7,9,2,2,0,4]),patch)),
		"incremental RG8 patch consumed")
	check(consumer.material_at(7,9) == 2 and consumer.material_at(8,10) == 5
		and consumer.material_at(0,0) == 43, "patch preserves untouched pixels")
	check(not consumer.consume(packet(3,1,false,PackedInt32Array([1023,9,2,2,0,4]),patch)),
		"out-of-bounds patch refused")
	check(consumer.last_serial == 2, "refused packet cannot advance ACK")
	check(not consumer.consume(packet(4,1,false,PackedInt32Array([7,9,2,2,0,3]),patch)),
		"invalid row stride refused")
	check(not consumer.consume(packet(5,2,false,PackedInt32Array([7,9,2,2,0,4]),patch)),
		"new-world partial packet refused")
	check(not consumer.consume(packet(2,1,false,PackedInt32Array([7,9,2,2,0,4]),patch)),
		"replayed serial refused")
	check(not consumer.consume(packet(6,2,true,PackedInt32Array([0,0,1024,1023,0,2048]),entire)),
		"incomplete alleged full-world baseline refused")
	check(consumer.last_serial == 2 and consumer.material_at(7,9) == 2,
		"all rejected packets preserve the accepted image and serial")
	check(consumer.consume(packet(7,2,true,full,entire)), "new world accepts exact full frame")
	check(consumer.last_serial == 7 and consumer.world_generation == 2,
		"world switch only after full consumption")
	var retained: PackedByteArray = entire.duplicate()
	retained.append_array(PackedByteArray([9,77,8,66]))
	var retained_rects := PackedInt32Array([0,0,1024,1024,0,2048,
		5,6,2,1,entire.size(),4])
	check(consumer.consume(packet(8,2,true,retained_rects,retained)),
		"retained full baseline plus later dirty patch is valid")
	check(consumer.material_at(5,6) == 9 and consumer.material_at(6,6) == 8
		and consumer.material_at(0,0) == 43,
		"full baseline and appended dirty patch applied in order")
	# SOL281 opt-in bounded render merger; actual RG8 byte oracle.
	var owner := CyberSimulationWorker.new()
	owner._experimental_render_full_coalescing = true
	owner._pending_render_world_generation = owner._world_generation
	var original: Dictionary = {"status":1,"serial":10,"channels":2,
		"full_refresh":true,"rectangles":full,"cells":entire}
	check(not owner._append_native_render_packet(original), "full baseline retained")
	owner._refresh_published_render_payload()
	var prior: PackedByteArray = owner._published_render_patch_cells
	var updates := PackedByteArray([91,1,92,2,93,3,94,4,125,9])
	var regions := PackedInt32Array([1022,1022,2,2,0,4,1023,1023,1,1,8,2])
	var dirty: Dictionary = {"status":1,"serial":11,"channels":2,
		"full_refresh":false,"rectangles":regions,"cells":updates}
	check(owner._append_native_render_packet(dirty), "valid dirty bytes coalesced")
	check(owner._pending_render_patch_cells.size() == entire.size()
		and owner._pending_render_patch_rectangles == full,
		"bounded result retains exactly one full-frame rectangle")
	check(owner._pending_render_snapshot_serial == 11
		and owner._pending_render_payload_generation == 2,
		"normal serial and immutable payload generation advance")
	check(prior.size() == entire.size() and prior[prior.size()-2] == 77,
		"already-published immutable bytes never change")
	var oracle = Consumer.new()
	check(oracle.consume(packet(11,1,true,owner._pending_render_patch_rectangles,
		owner._pending_render_patch_cells)), "strict consumer accepts final pixels")
	check(oracle.material_at(1022,1022) == 91 and oracle.material_at(1023,1022) == 92
		and oracle.material_at(1022,1023) == 93 and oracle.material_at(1023,1023) == 125
		and oracle.material_at(0,0) == 43, "overlapping tails, edge and untouched pixels exact")
	owner._experimental_render_full_coalescing = false
	check(not owner._append_native_render_packet({"status":1,"serial":12,"channels":2,
		"full_refresh":false,"rectangles":regions,"cells":updates})
		and owner._pending_render_patch_cells.size() > entire.size(),
		"default append/overflow remains unchanged")
	var reject := CyberSimulationWorker.new()
	reject._experimental_render_full_coalescing = true
	reject._pending_render_world_generation = reject._world_generation
	reject._append_native_render_packet(original)
	check(not reject._append_native_render_packet({"status":2,"serial":11,"channels":2,
		"full_refresh":false,"rectangles":regions,"cells":updates}),
		"backpressure is never coalesced")
	reject._append_native_render_packet(original)
	var large := PackedByteArray()
	large.resize(CyberSimulationWorker.SOL281_COALESCE_MAX_DIRTY_BYTES + 1)
	check(not reject._append_native_render_packet({"status":1,"serial":12,"channels":2,
		"full_refresh":false,"rectangles":PackedInt32Array([2,2,1,1,0,2]),"cells":large}),
		"64-KiB cap forces original fallback")
	reject._append_native_render_packet(original)
	check(not reject._append_native_render_packet({"status":1,"serial":13,"channels":2,
		"full_refresh":false,"rectangles":PackedInt32Array([1024,1,1,1,0,2]),"cells":updates}),
		"out-of-bounds metadata refused for coalescing")
	reject._append_native_render_packet(original)
	check(not reject._append_native_render_packet({"status":1,"serial":14,"channels":2,
		"full_refresh":false,"rectangles":PackedInt32Array([2,2,2,1,0,3]),"cells":updates}),
		"bad stride refused for coalescing")
	reject._append_native_render_packet(original)
	reject._pending_render_world_generation += 1
	check(not reject._append_native_render_packet(dirty), "different World never reuses pixels")
	reject._pending_render_world_generation = reject._world_generation
	reject._append_native_render_packet(original)
	var metadata := PackedInt32Array()
	for i: int in range(CyberSimulationWorker.SOL281_COALESCE_MAX_DIRTY_RECTANGLES + 1):
		metadata.append_array(PackedInt32Array([i,1,1,1,0,2]))
	check(not reject._append_native_render_packet({"status":1,"serial":15,"channels":2,
		"full_refresh":false,"rectangles":metadata,"cells":updates}),
		"64-rectangle metadata cap enforced")
	reject._append_native_render_packet(original)
	check(not reject._append_native_render_packet({"status":1,"serial":16,"channels":1,
		"full_refresh":false,"rectangles":regions,"cells":updates}),
		"RG8/R8 channel changes cannot coalesce")
	var state: Dictionary = consumer.metrics()
	check(int(state.consumed) == 4 and int(state.refused) == 5
		and int(state.rectangles) == 5 and int(state.bytes) > 0,
		"four consumed and five refused packets accounted")
	print("SOL281_RENDER_ACK_UNIT ", JSON.stringify({"checks":checks,"failures":failures,
		"platform":OS.get_name(),"consumer":state}))
	quit(0 if failures.is_empty() else 1)
