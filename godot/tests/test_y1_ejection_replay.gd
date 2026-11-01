extends SceneTree

# Replay compact declarative current-main inputs through the real adapter.
# No historical diagnostic API/corpus or alternate ejection implementation.
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func capture(material: int, barrier: String, arm: String) -> Dictionary:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers":1,"bearing_candidate":arm,"bearing_experiment":"Y1-ENVELOPE-2026-11-01"}):
		failed = true
		return {}
	world.diagnostic_fill_rect(Vector2i(104,113),Vector2i.ONE,material)
	if barrier == "hard": world.diagnostic_fill_rect(Vector2i(90,114),Vector2i(32,1),1)
	var states := PackedFloat32Array([1,104,107,0,8,14,0,0,0,1,1])
	if barrier == "foreign": states.append_array(PackedFloat32Array([2,104,115,0,32,1,0,0,0,1,1]))
	world.prepare_rigid_body_coupling(states,true)
	var value: Dictionary = world.diagnostic_snapshot(Vector2i(80,80),Vector2i(64,64))
	var metrics: Array = world.diagnostic_body_metrics()
	var census: Dictionary = metrics[0][20].duplicate(true)
	census.erase("candidate")
	census.erase("yield_factor")
	var result: PackedFloat32Array = world.rigid_body_results()
	var conserved: bool = int(value.water_mass) == (255 if material == 3 else 0) and int(value.counts[material]) == 1
	var expected_success: int = 1 if barrier == "open" else 0
	if not conserved or int(result[6]) != expected_success or int(result[7]) != 1-expected_success or int(census.relocation_refused) != 0:
		failed = true
		push_error("Y1 ejection replay conservation/path outcome: %s/%s/%s" % [material,barrier,arm])
	return {"state_hash":value.hash,"cells":value.cells,"water":value.water_mass,"counts":value.counts,
		"result":result,"census":census}

func _run() -> void:
	var matched: int = 0
	for material: int in [2,23,3]:
		for barrier: String in ["open","hard","foreign"]:
			var baseline: Dictionary = capture(material,barrier,"B0")
			for arm: String in ["B0","Y1"]:
				for _repeat: int in range(2):
					if capture(material,barrier,arm) != baseline:
						failed = true
						push_error("Current-main ejection input replay differs")
					else: matched += 1
	print("Y1_CURRENT_EJECTION_REPLAY matched=",matched," expected=36; complete World state hashes, copied cells, results and endpoint census")
	quit(1 if failed else 0)
