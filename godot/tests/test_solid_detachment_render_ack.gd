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
	retained.append_array(PackedByteArray([9, 77, 8, 66]))
	var retained_rects := PackedInt32Array([0, 0, 1024, 1024, 0, 2048,
		5, 6, 2, 1, entire.size(), 4])
	check(consumer.consume(packet(8, 2, true, retained_rects, retained)),
		"retained full baseline plus later dirty patch consumed completely")
	check(consumer.material_at(5, 6) == 9 and consumer.material_at(6, 6) == 8
		and consumer.material_at(0, 0) == 43, "full and dirty data applied in order")
	var state: Dictionary = consumer.metrics()
	check(int(state.consumed) == 4 and int(state.refused) == 5
		and int(state.rectangles) == 5 and int(state.bytes) > 0,
		"consumed and refused packets accounted")
	print("SOL281_RENDER_ACK_UNIT ", JSON.stringify({"checks":checks,"failures":failures,
		"platform":OS.get_name(),"consumer":state}))
	quit(0 if failures.is_empty() else 1)
