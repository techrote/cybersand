extends SceneTree

# Bounded native-only runner. The same JSON and host are consumed by both game
# controllers. Character/Rapier-enabled definitions need their live owner and
# are refused here rather than silently relabelled as full interactive runs.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Host = preload("res://scripts/microscenario_host.gd")
var error_message: String = ""

func _init() -> void:
	call_deferred("_run")

func _number(text: String, maximum: int) -> int:
	if not text.is_valid_int(): return -1
	var value: int = int(text)
	return value if value >= 0 and value <= maximum else -1

func _run() -> void:
	var options: Dictionary = {"scenario":"fixtures/unequal-head", "seed":"0",
		"ticks":"120", "workers":"1", "mode":"Benchmark", "observers":"on",
		"definition":"", "output":"user://microscenario-benchmark.json", "source-sha":"unavailable"}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or pair.size() != 2 or not options.has(pair[0]):
			_finish("Unknown argument; use --scenario=ID --ticks=0..3600 --output=PATH")
			return
		options[pair[0]] = pair[1]
	var ticks: int = _number(options.ticks, Contract.MAX_TICK)
	var seed: int = _number(options.seed, 0x7FFFFFFF)
	var workers: int = _number(options.workers, 32)
	if ticks < 0 or seed < 0 or workers < 1 or not options.mode in Contract.MODES or not options.observers in ["on", "off"]:
		_finish("Invalid tick/seed/worker/mode/observer option")
		return
	if options["source-sha"] != "unavailable":
		var sha: String = options["source-sha"]
		if sha.length() != 40:
			_finish("Source SHA must be a full 40-character revision or unavailable")
			return
		for character: String in sha:
			if not character in "0123456789abcdef":
				_finish("Source SHA is not hexadecimal")
				return
	var checked: Dictionary
	if str(options.definition).is_empty():
		checked = Contract.validate(Catalogue.definition(options.scenario, seed))
	else:
		var file := FileAccess.open(options.definition, FileAccess.READ)
		if file == null or file.get_length() > Contract.MAX_JSON_BYTES:
			_finish("Definition unavailable or exceeds byte budget")
			return
		checked = Contract.parse(file.get_as_text())
	if not checked.get("ok", false):
		_finish(str(checked.get("error", "Definition rejected")))
		return
	if checked.definition.body_enabled or checked.definition.player_enabled:
		_finish("This runner is native-only; live player/body definitions require the controller")
		return
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		_finish("Current native extension is required")
		return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers":workers}):
		_finish("Native worker configuration rejected")
		return
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world, checked.definition, options.mode, options.observers == "on"):
		_finish(host.last_error)
		return
	var completed: int = 0
	var start: int = Time.get_ticks_usec()
	while completed < ticks:
		if not host.advance():
			error_message = host.last_error
			break
		completed += 1
	var elapsed: int = Time.get_ticks_usec() - start
	var report: Dictionary = host.capture(CyberMicroScenarioIdentity.current(options["source-sha"]))
	report["runner"] = {"scope":"native-only, no character, Rapier or render", "requested_ticks":ticks,
		"completed_ticks":completed, "run_wall_usec":elapsed, "error":error_message,
		"wall_scope":"advance loop including enabled observers; setup/export excluded"}
	var temporary: String = str(options.output) + ".tmp"
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		_finish("Cannot create output; parent directory must exist")
		return
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.flush()
	var write_error: Error = output.get_error()
	output.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, options.output) != OK:
		_finish("Could not commit result file")
		return
	print("MICROSCENARIO_RESULT ", options.output, " / ", completed, " ticks / ", report.definition_hash)
	quit(0 if error_message.is_empty() and report.outcome != "fail" else 1)

func _finish(message: String) -> void:
	printerr("MICROSCENARIO_ERROR: ", message)
	quit(2)
