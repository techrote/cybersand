extends SceneTree
## Native observations are volatile capabilities, never imported JSON assertions.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
var checks := 0
var failures: Array[String] = []
var controller: Node

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("BATCH_NATIVE_CUSTODY_CHECK ",label," ",value)

func settle() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	check(not controller.is_running(),"bounded native owner retired")

func run() -> void:
	controller = Controller.new()
	root.add_child(controller)
	await process_frame
	controller.configure_grid(1,1)
	var config := Controller.defaults()
	config.extent = [64,64]
	config.source_region = [0,0,64,64]
	config.operations = [{"shape":"rectangle","x0":8,"y0":8,"x1":55,"y1":11,"material":58}]
	check(controller.configure_tile(0,config).ok and controller.start([0]).ok,"real native construction queued")
	check(not controller.tiles[0].get("_native_readback_current_process",false),"queued work has no native observation")
	await settle()
	var tile: Dictionary = controller.tiles[0]
	check(tile.state=="completed" and tile.get("_native_readback_current_process",false),"completed native capture establishes volatile observation")
	var record: Dictionary = controller._record(tile)
	var encoded: Dictionary = Controller._encode(record)
	check(not encoded.has("_native_readback_current_process"),"export omits volatile native observation")
	encoded["_native_readback_current_process"] = true
	var decoded: Dictionary = controller._decode_record(encoded)
	check(decoded.ok and not decoded.record.get("_native_readback_current_process",true),"forged imported flag cannot establish current-process native observation")
	var path := "user://batch-native-custody/session.json"
	check(controller.save_session(path).ok,"original native session saves")
	var text := FileAccess.get_file_as_string(path)
	check(not text.contains("_native_readback_current_process"),"saved session contains no volatile native observation")
	check(controller.load_session(path).ok,"original source-bound evidence reopens")
	check(not controller.tiles[0].get("_native_readback_current_process",true),"reopened tile retains evidence without live native status")
	check(controller.replay(0).ok,"reopened evidence can request fresh native replay")
	check(not controller.tiles[0].get("_native_readback_current_process",false),"replay queue stays unqualified until native capture")
	await settle()
	check(controller.tiles[0].state=="completed" and controller.tiles[0].get("_native_readback_current_process",false),"fresh replay re-establishes observed native status")
	controller.queue_free()
	await process_frame
	print("BATCH_NATIVE_CUSTODY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"fresh native readback versus retained imported provenance"}))
	quit(0 if failures.is_empty() else 1)
