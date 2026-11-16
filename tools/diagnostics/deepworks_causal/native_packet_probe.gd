extends SceneTree

const Map = preload("res://scripts/exhibition/deepworks_map.gd")
const Runtime = preload("res://scripts/exhibition/deepworks_runtime.gd")
const Cell = preload("res://scripts/cell_world.gd")
const SOURCE: String = "93a5e85dc9d5459a5f9cce00839b64090a1a0573"
const VARIANTS: Dictionary = {
	"authored_q": {
		"counterfactual": false,
		"recipe_hash": "828f5174b41aa5fa3ed693dae9bb463f24c49d8ce18b506af7573152afd83caa",
		"effects_sha256": "fce342d9416c3f01b7be762fc402238a6933a830763cd599c64d3f2176875d29",
		"source_x": 235,
		"smoke_cells": [[235,929,240],[236,929,240],[234,930,240],[237,930,240],[234,931,240],[237,931,239]],
	},
	"d1_x238_counterfactual": {
		"counterfactual": true,
		"recipe_hash": "ec7d8a8988883446028a3b08cb4d2f9e00b59eec656409fd6b38a0dad06e4648",
		"effects_sha256": "135f4e1119c7f7f46ac0a88f80fd3af90d9a15af9a17766331b8d1a50589d51e",
		"source_x": 238,
		"smoke_cells": [[238,929,239],[239,929,240],[237,930,240],[240,930,240],[237,931,240],[240,931,240]],
	},
}
const BASE_PACKET_HASHES: Dictionary = {
	"play": "eb6aeb8255fd298d8408869dc687480a5d59f96d38d7cefe3eb69d3746c67e86",
	"scripted": "7d2b2ac02bd9f47f952c81113dba0f1470c4a278345b3e970c830a09b93c7953",
	"background": "0649a8edcde12cfebade2af77eab30c8ceb2b8d6a22eb799737f98008ec95c79",
}
var scene_variant: String = ""
var witness := Rect2i(230,925,12,13)
var output: String = ""
var runtime = Runtime.new()
var planes: Dictionary = {}
var evidence: Dictionary = {"schema":"deepworks-native-packet-diagnostic-v2", "source_commit":SOURCE, "scope": "Diagnostic-only native packet and geometric mask readback; no rendering or pixel acceptance", "stages": [], "initial_wave": {}, "errors": []}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-output="):
			output = arg.trim_prefix("--probe-output=")
		if arg.begins_with("--scene-variant="):
			scene_variant = arg.trim_prefix("--scene-variant=")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var started := Time.get_ticks_msec()
	if not VARIANTS.has(scene_variant):
		_abort("Exactly one registered --scene-variant is required")
		return
	evidence["scene_variant"] = scene_variant
	evidence["counterfactual"] = VARIANTS[scene_variant]["counterfactual"]
	evidence["recipe_changes"] = []
	evidence["probe_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	witness.position.x = int(VARIANTS[scene_variant]["source_x"])-5
	evidence["witness_rect"] = [witness.position.x,witness.position.y,witness.size.x,witness.size.y]
	var definition: Dictionary = Map.build()
	if Map.recipe_hash(definition) != VARIANTS["authored_q"]["recipe_hash"]:
		_abort("Unmodified Q recipe authentication failed")
		return
	if scene_variant == "d1_x238_counterfactual" and not _override_d1(definition):
		return
	evidence["recipe_hash"] = Map.recipe_hash(definition)
	if evidence["recipe_hash"] != VARIANTS[scene_variant]["recipe_hash"]:
		_abort("Declared variant recipe authentication failed")
		return
	if not runtime.install(definition["layers"], definition["events"]):
		_abort("Install: " + runtime.last_error)
		return
	runtime.configure_rates({"play": 30.0, "scripted": 20.0, "effects": 15.0, "background": 0.0})
	runtime.set_layer_paused("play", true)
	runtime.set_layer_paused("scripted", true)
	for id: String in Map.LAYERS:
		planes[id] = Image.create(1024, 1024, false, Image.FORMAT_RG8)
		planes[id].fill(Color(0, 0, 0, 1))
		evidence["initial_wave"][id] = runtime._worlds[id].get_wave_flow_status()
		if evidence["initial_wave"][id].get("enabled", true):
			_abort("Unexpected Wave owner: " + id)
			return
		_apply_packet(id, runtime.snapshot_layer(id, true))
	_record_stage("initial", 0)
	for target: int in [10, 13, 16, 19, 22, 25, 28, 31, 34, 37, 40, 43, 45, 46]:
		while runtime.layer_tick("effects") < target:
			var stepped: Dictionary = runtime.step_once()
			if not bool(stepped.get("ok", false)):
				_abort("Tick: " + runtime.last_error)
				return
		for id: String in Map.LAYERS:
			_apply_packet(id, runtime.snapshot_layer(id))
		_record_stage("effects", target)
	var full: Dictionary = runtime.snapshot_layer("effects", true)
	var previous: PackedByteArray = planes["effects"].get_data()
	_apply_packet("effects", full)
	evidence["incremental_equals_full_at_46"] = previous == planes["effects"].get_data()
	evidence["native_d1"] = runtime._worlds["effects"].diagnostic_snapshot(Vector2i(230, 840), Vector2i(20, 115))
	evidence["native_d1"].erase("cells")
	evidence["events"] = runtime.event_stats()
	evidence["final_layer_ticks"] = {}
	evidence["packet_sha256"] = {}
	for id: String in Map.LAYERS:
		evidence["final_layer_ticks"][id] = runtime.layer_tick(id)
		var bytes: PackedByteArray = planes[id].get_data()
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		evidence["packet_sha256"][id] = hashing.finish().hex_encode()
		var expected: String = VARIANTS[scene_variant]["effects_sha256"] if id=="effects" else BASE_PACKET_HASHES[id]
		if evidence["packet_sha256"][id] != expected:
			_abort("Declared variant packet authentication failed: "+id)
			return
		var file := FileAccess.open(output.path_join(id + "-tick46.rg8"),FileAccess.WRITE)
		if file == null:
			_abort("Could not open packet output: "+id)
			return
		file.store_buffer(bytes)
		file.flush()
		var write_error: Error = file.get_error()
		file.close()
		if write_error != OK:
			_abort("Could not flush packet output: "+id)
			return
	var expected_cells: Array = VARIANTS[scene_variant]["smoke_cells"]
	var actual_cells: Array = []
	for cell: Dictionary in evidence["stages"][-1]["cells"]:
		actual_cells.append([cell["position"][0],cell["position"][1],cell["visual_state_a"]])
	if actual_cells != expected_cells:
		_abort("Native Smoke coordinates/lifetimes differ from declared variant")
		return
	evidence["elapsed_ms"] = Time.get_ticks_msec() - started
	evidence["engine"] = Engine.get_version_info()
	evidence["display"] = DisplayServer.get_name()
	if not _write():
		quit(2)
		return
	print("DEEPWORKS_NATIVE_PACKET_DIAGNOSTIC ", JSON.stringify({"scene_variant":scene_variant,"counterfactual":evidence["counterfactual"],"recipe_hash":evidence["recipe_hash"],"ok": evidence["errors"].is_empty(), "elapsed_ms": evidence["elapsed_ms"], "incremental_equals_full": evidence["incremental_equals_full_at_46"], "last_stage": evidence["stages"][-1]}))
	quit(0 if evidence["errors"].is_empty() else 1)

func _apply_packet(id: String, packet: Dictionary) -> void:
	if bool(packet.get("failed", false)):
		evidence["errors"].append("Failed packet " + id)
		return
	var rectangles: PackedInt32Array = packet["rectangles"]
	var bytes: PackedByteArray = packet["cells"]
	for offset: int in range(0, rectangles.size(), 6):
		var width: int = rectangles[offset + 2]
		var height: int = rectangles[offset + 3]
		var begin: int = rectangles[offset + 4]
		var stride: int = rectangles[offset + 5]
		var packed := PackedByteArray()
		if stride == width * 2:
			packed = bytes.slice(begin, begin + width * height * 2)
		else:
			for row: int in range(height):
				packed.append_array(bytes.slice(begin + row * stride, begin + row * stride + width * 2))
		var patch := Image.create_from_data(width, height, false, Image.FORMAT_RG8, packed)
		planes[id].blit_rect(patch, Rect2i(Vector2i.ZERO, Vector2i(width, height)), Vector2i(rectangles[offset], rectangles[offset + 1]))

func _material(id: String, p: Vector2i) -> int:
	if p.x < 0 or p.y < 0 or p.x >= 1024 or p.y >= 1024:
		return 0
	return roundi(planes[id].get_pixelv(p).r * 255.0)

func _depth(id: int) -> float:
	if id == 96 or (id >= 120 and id <= 124) or id == 129: return 0.38
	if (id >= 81 and id <= 94) or id == 125 or id == 128: return 0.70
	if id >= 81 and id <= 131: return 1.0
	if id in [9,35,43,44,68,69]: return 0.38
	if id in [7,41,42]: return 0.70
	if id in [1,13,28,29,31] or (id >= 38 and id <= 80): return 1.0
	return 0.0

func _record_stage(label: String, tick: int) -> void:
	var active: Array[Dictionary] = []
	for y: int in range(witness.position.y, witness.end.y):
		for x: int in range(witness.position.x, witness.end.x):
			var p := Vector2i(x,y)
			var material: int = _material("effects", p)
			if material == Cell.EMPTY or material == Cell.WALL:
				continue
			var slices: Array[Dictionary] = []
			for index: int in range(4,0,-1):
				var depth: float = float(index)/4.0
				var point: Vector2 = (Vector2(p)+Vector2(0.5,0.5)-Vector2(512,512))/(1.0-depth*0.018)+Vector2(512,512)-Vector2(0.78,0.42)*5.0*depth
				var sample: Vector2i = Vector2i(point.floor())
				var id: int = _material("play", sample)
				slices.append({"depth":depth,"sample":[sample.x,sample.y],"material":id,"passes_material_depth":_depth(id)+0.001 >= depth})
			active.append({"position":[x,y],"material":material,"visual_state_a":roundi(planes["effects"].get_pixelv(p).g*255.0),"play":_material("play",p),"scripted":_material("scripted",p),"background":_material("background",p),"neighbours":[_material("effects",p+Vector2i.UP),_material("effects",p+Vector2i.DOWN),_material("effects",p+Vector2i.LEFT),_material("effects",p+Vector2i.RIGHT)],"relief_slices":slices})
	evidence["stages"].append({"label":label,"tick":tick,"native_active_cells_in_witness":active.size(),"cells":active})

func _abort(message: String) -> void:
	evidence["errors"].append(message)
	_write()
	push_error(message)
	quit(2)

func _override_d1(definition: Dictionary) -> bool:
	# Counterfactual recipe only. No Q resource or native law is modified.
	var old := Rect2i(235,930,2,3)
	var after := Rect2i(238,930,2,3)
	var initial: PackedInt32Array = definition["layers"]["effects"].duplicate()
	var initial_matches: int = 0
	for offset: int in range(0,initial.size(),5):
		if initial[offset]==old.position.x and initial[offset+1]==old.position.y and initial[offset+2]==2 and initial[offset+3]==3 and initial[offset+4]==4:
			initial[offset]=after.position.x
			initial_matches+=1
	var event_matches: int = 0
	for event: Dictionary in definition["events"]:
		if event["id"] != "deepworks-12-effects-local-atmosphere": continue
		if event["district"]!=12 or event["layer"]!="effects" or event["rect"]!=old or event["material"]!=4 or event["first_tick"]!=45 or event["period"]!=39 or event["repeat"]!=0:
			_abort("Counterfactual D1 event does not match authenticated Q declaration")
			return false
		event["rect"]=after
		event_matches+=1
	if initial_matches!=1 or event_matches!=1:
		_abort("Counterfactual D1 declaration must match exactly one initial rectangle and event")
		return false
	definition["layers"]["effects"]=initial
	evidence["recipe_changes"].append({"district":"D1","material":4,"initial_rectangle_and_repeated_event":true,"old_rect":[235,930,2,3],"new_rect":[238,930,2,3],"first_tick":45,"period":39,"repeat":0})
	return true

func _write() -> bool:
	var file := FileAccess.open(output.path_join("native-packet-diagnostic.json"),FileAccess.WRITE)
	if file == null:
		push_error("Could not open native diagnostic evidence output")
		return false
	file.store_string(JSON.stringify(evidence,"  ")+"\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		push_error("Could not flush native diagnostic evidence output")
		return false
	return true
