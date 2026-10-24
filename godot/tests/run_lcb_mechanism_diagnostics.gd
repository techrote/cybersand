extends SceneTree

# Reproduces the LCB physics prepass mechanism diagnostics on Current liquids
# (characterization only; not a regression). Prints one LCB_DIAG JSON line per
# experiment. Usage:
#   godot --headless --path godot --script res://tests/run_lcb_mechanism_diagnostics.gd
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const M = preload("res://tests/lcb_physics_metrics.gd")
const LADDER: Array[String] = ["lcb.dam.water.freemass.depth-48.v1", "lcb.dam.water.freemass.depth-96.v1",
	"lcb.dam.water.freemass.depth-160.v1"]

func _init() -> void:
	call_deferred("_run")

func _text(id: String) -> String:
	return Runner.read_text("res://tests/fixtures/lcb/scenarios/" + id + ".json").text

func _emit(name: String, value: Variant) -> void:
	print("LCB_DIAG ", JSON.stringify({"experiment":name, "result":value}))

# A failed install, tick or capture stops the runner: no measurement from a
# failed run is ever emitted.
func _abort(message: String) -> void:
	printerr("LCB_DIAG_FAILURE ", message)
	quit(1)

func _install(text: String) -> Dictionary:
	var inst: Dictionary = Runner.install(text, 1)
	if not inst.ok: _abort("install refused: " + str(inst.get("error", "")))
	return inst

func _tick(inst: Dictionary) -> bool:
	if inst.host.advance(): return true
	_abort("tick faulted: " + str(inst.host.last_error))
	return false

func _run() -> void:
	# A. Front distance from the gate face and surface heights against time.
	for id: String in LADDER:
		var inst: Dictionary = _install(_text(id))
		if not inst.ok: return
		var rows: Array = []
		for tick: int in range(1, 1801):
			if not _tick(inst): return
			if tick in [15, 30, 60, 120, 240, 480, 960, 1800]:
				rows.append({"tick":tick, "front":M.front_x(inst.world, 255, 240, 983) - 240,
					"gate_surface_y":M.surface_y(inst.world, 236, 64, 256),
					"reservoir_surface_y":M.surface_y(inst.world, 100, 64, 256)})
		_emit("front-vs-time/" + id, rows)
	# A. Adhesion hypothesis: identical setup with the supported-film rule off.
	for id: String in [LADDER[0], LADDER[2]]:
		for adhesion: bool in [true, false]:
			var definition: Dictionary = JSON.parse_string(_text(id))
			definition.execution.liquid_surface_adhesion_enabled = adhesion
			var result: Dictionary = Runner.run_text(JSON.stringify(definition), 1, 1800)
			if result.status != "completed":
				_abort(id + " adhesion run " + str(result.status) + ": " + str(result.get("error", "")))
				return
			var observed: Dictionary = {}
			for entry: Dictionary in result.capture.observations: observed[entry.id] = entry.value
			_emit("adhesion/" + id, {"adhesion":adhesion, "status":result.status,
				"reservoir_t1800":observed.get("reservoir-t1800"), "band2_t1200":observed.get("band2-t1200"),
				"moved_cells_total":result.work.moved_cells_total})
	# C. Retained activity versus interest region in a resting pool.
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	for region: Array in [[0, 0, 1024, 1024], [16, 16, 992, 272], [40, 96, 944, 160]]:
		var definition: Dictionary = JSON.parse_string(_text("lcb.rest.deep-quiet-pool.v1"))
		definition.interest.region = region
		var inst: Dictionary = _install(JSON.stringify(definition))
		if not inst.ok: return
		var series: Array = []
		for tick: int in range(1, 21):
			if not _tick(inst): return
			if tick in [1, 3, 4, 20]:
				var values: Dictionary = bridge.inspect_statistics(inst.world)["values"]
				series.append({"tick":tick, "visited":values.visited_cells, "scheduled_cores":values.scheduled_cores,
					"active_blocks":values.active_blocks_after, "active_chunks":values.active_chunks})
		_emit("activity-vs-interest", {"interest":region, "series":series})
	quit(0)
