extends SceneTree

# Export a catalogue-produced complete definition without reimplementing any
# fixture generation in Python/tooling. The emitted canonical JSON is accepted
# unchanged by Materials Laboratory and run_microscenario.gd --definition.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = {"scenario":"materials/salt-water", "seed":"0", "output":"interaction-definition.json"}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or pair.size() != 2 or not options.has(pair[0]):
			_fail("Use --scenario=ID --seed=N --output=PATH")
			return
		options[pair[0]] = pair[1]
	if not str(options.seed).is_valid_int() or int(options.seed) < 0 or int(options.seed) > 0x7fffffff:
		_fail("Invalid seed")
		return
	var checked: Dictionary = Contract.validate(Catalogue.definition(str(options.scenario), int(options.seed)))
	if not checked.get("ok",false):
		_fail(str(checked.get("error","Definition rejected")))
		return
	var temporary: String = str(options.output) + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_fail("Cannot create output; parent directory must exist")
		return
	file.store_string(str(checked.canonical_json) + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, str(options.output)) != OK:
		_fail("Could not commit definition output")
		return
	print("MICROSCENARIO_DEFINITION ", options.output, " / ", checked.hash)
	quit(0)

func _fail(message: String) -> void:
	printerr("MICROSCENARIO_DEFINITION_ERROR: ", message)
	quit(2)
