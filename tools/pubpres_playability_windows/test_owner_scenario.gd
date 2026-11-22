extends SceneTree

# Actual Workbench test of the evaluation helper, not a dropdown/state model.
# The runner starts this twice against the same isolated profile.
const Scenario = preload("res://tests/pubpres_playability_owner_scenario.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const MARKER := [123,111,2,58]
var app: Control
var problems: Array[String] = []
var evidence: Dictionary = {}
var phase := ""
var output := ""


func _initialize() -> void:
	phase = OS.get_environment("PUBPRES_OWNER_TEST_PHASE")
	output = OS.get_environment("PUBPRES_OWNER_TEST_OUTPUT")
	if phase not in ["author","reopen"] or output.is_empty():
		quit(2)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads",4)
	Engine.max_fps = 60
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	if not ok:
		problems.append(label)
		push_error("PUBPRES_OWNER_SCENARIO: " + label)
	return ok


func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if not check(await Scenario._wait(self,app,func() -> bool: return app.shared_workbench != null \
		and not app.shared_workbench.applied.is_empty()),"ordinary initial World admitted"):
		finish()
		return
	evidence = await Scenario.prepare(self,app,phase == "reopen")
	if not check(not evidence.has("error"),str(evidence.get("error","scenario ready"))):
		finish()
		return
	var ui: Control = app.shared_workbench
	check(evidence.worker_capacity == 4 and evidence.physical_tick_ready >= evidence.physical_tick_before+4 \
		and evidence.native_tick_ready >= evidence.native_tick_before+4,"actual four-worker native and Rapier startup")
	if not app.paused: check(ui.toggle_pause(),"ordinary Pause")
	if phase == "author":
		if not check(await Scenario._wait(self,app,func() -> bool: return not ui.busy()),"authoring owner settled"):
			finish()
			return
		ui.applied.brush = 2
		check(ui.paint(Vector2i(MARKER[0],MARKER[1]),MARKER[3]),"ordinary brush admission")
		check(await Scenario._wait(self,app,func() -> bool: return ui._save_block_reason().is_empty()),"native brush completion before Save")
		check(ui.applied.edits.has(MARKER),"authored marker retained")
		check(ui.save_setup(),"ordinary Save start after painting")
		check(FileAccess.get_sha256(Setup._path(Scenario.SAVE_NAME)) != evidence.saved_setup_sha256,"Save captured the owner edit")
	else:
		check(ui.applied.edits.has(MARKER),"fresh-process Load preserved owner edit instead of regenerating over it")
		check(evidence.saved_before_sha256 == evidence.saved_setup_sha256,"reopen did not rewrite saved source")
	finish()


func finish() -> void:
	var native_path := "res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so")
	var result := {"schema":"pubpres003-owner-scenario-test-v1","phase":phase,"complete":problems.is_empty(),
		"failures":problems,"scenario":evidence,"source_commit":OS.get_environment("CYBERSAND_SOURCE_SHA"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"native_sha256":FileAccess.get_sha256(native_path),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"helper_sha256":FileAccess.get_sha256("res://tests/pubpres_playability_owner_scenario.gd"),
		"test_sha256":FileAccess.get_sha256(get_script().resource_path),"process_id":OS.get_process_id(),
		"display":DisplayServer.get_name(),"scope":"Actual ordinary Workbench scenario author/Save/reopen; headless results do not establish graphical or gameplay performance acceptance."}
	var writer := FileAccess.open(output,FileAccess.WRITE)
	if writer == null:
		quit(3)
		return
	writer.store_string(JSON.stringify(result,"  ")+"\n")
	writer.close()
	print("PUBPRES_OWNER_SCENARIO_RESULT ",JSON.stringify(result))
	quit(int(not problems.is_empty()))
