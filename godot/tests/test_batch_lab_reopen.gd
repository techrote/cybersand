extends SceneTree
## With BATCH_LAB_SESSION_PATH, verifies an earlier process's actual native
## results by fresh native replay and exact baseline reconstruction.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Experiments = preload("res://scripts/batch_lab/batch_lab_experiments.gd")
var controller: Node
var checks := 0
var failures: Array[String] = []
var fresh_process := false
var evidence := ""
var original_count := 0
var replayed: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("BATCH_REOPEN_CHECK ",checks," ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func settle(label: String) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	return check(not controller.is_running(),label)

func run() -> void:
	evidence = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	controller = Controller.new()
	root.add_child(controller)
	await process_frame
	var path := OS.get_environment("BATCH_LAB_SESSION_PATH")
	fresh_process = not path.is_empty()
	if path.is_empty():
		# Standalone discovery remains a genuine native reconstruction test. Only
		# the scoped two-process campaign claims a fresh OS-process reopen.
		path = "user://batch-lab-reopen-self-contained.json"
		var cases := Experiments.make_grid("architecture",2,19301)
		for i: int in 4: check(controller.configure_tile(i,cases[i]).ok,"standalone configure %d" % i)
		controller.start()
		if not await settle("standalone native source fixture"): finish(); return
		check(controller.save_session(path).ok,"standalone evidence saved")
	var loaded: Dictionary = controller.load_session(path)
	if not check(loaded.ok,"saved session loads atomically / "+str(loaded.get("reason",""))): finish(); return
	original_count = controller.attempts.size()
	if fresh_process:
		# The native campaign also ends with small random controls. Replay the
		# retained sixteen-attempt architecture cohort, not only the last view.
		var cohort: Array = []
		for record: Dictionary in controller.attempts:
			if record.state=="completed" and record.config.get("control")=="procedural" and record.config.get("family")=="architecture": cohort.append(record.attempt_id)
		if not check(cohort.size()==16,"earlier process retained the full sixteen-attempt architecture cohort"): finish(); return
		check(controller.configure_grid(4,4).ok,"fresh reopen presents the full retained native cohort")
		for i: int in 16: check(controller.select_attempt(i,cohort[i]).ok,"select earlier process native result %d" % i)
	var expected: Array = []
	for tile: Dictionary in controller.tiles:
		expected.append({"hash":tile.material_sha256,"cells":tile.material_cells.duplicate(),"id":tile.attempt_id})
	for i: int in controller.tiles.size(): check(controller.replay(i).ok,"reopened native replay %d queued" % i)
	if not await settle("reopened grid actual native replay completes"): finish(); return
	for i: int in controller.tiles.size():
		var tile: Dictionary = controller.tiles[i]
		check(tile.state=="completed" and tile.material_cells==expected[i].cells,"reopened tile %d full plane equals earlier process" % i)
		check(tile.provenance.material_sha256==expected[i].hash and not tile.receipts.is_empty(),"reopened tile %d actual readback and hash" % i)
		replayed.append({"original":expected[i].id,"replay":tile.attempt_id,"sha256":tile.material_sha256})
	var partial_id := ""
	var partial := PackedByteArray()
	var refused_count := 0
	for record: Dictionary in controller.attempts:
		if record.state in ["refused","stopped"]: refused_count += 1
		if partial_id.is_empty() and record.state=="partial" and not record.material_cells.is_empty():
			partial_id = record.attempt_id
			partial = record.material_cells.duplicate()
	if fresh_process:
		check(refused_count>=3,"refused and stopped attempts remain in the reopened denominator")
		if check(not partial_id.is_empty(),"original partial attempt retained"):
			check(controller.select_attempt(0,partial_id).ok,"select retained partial for exact replay")
			check(controller.replay(0).ok,"confirmed-prefix replay queued")
			await settle("confirmed-prefix replay completes")
			check(controller.tiles[0].material_cells==partial,"partial replay excludes original unconfirmed suffix")
			check(controller.select_attempt(0,partial_id).ok and controller.redo(0).ok,"partial native baseline restoration queued")
			await settle("partial baseline restored")
			check(controller.tiles[0].material_cells==partial,"native restoration reproduces complete earlier partial plane")
	# Malformed result import must refuse as a value result, not crash or mutate.
	var before_id: String = controller.tiles[0].attempt_id
	var bad := {"format":Controller.FORMAT,"kind":"session","columns":1,"rows":1,
		"tiles":[{"config":Controller.defaults(),"attempt_id":"bad"}],
		"attempts":[{"attempt_id":"bad","state":"completed","result_extent":[128,128],"config":Controller.defaults()}]}
	var corrupt_path := "user://batch-lab-reopen-malformed.json"
	var file := FileAccess.open(corrupt_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(bad)); file.close()
	check(not controller.load_session(corrupt_path).ok and controller.tiles[0].attempt_id==before_id,"malformed import preserves current evidence")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	if not evidence.is_empty(): check(controller.save_session(evidence.path_join("reopened-session.json")).ok,"fresh native reopen evidence retained")
	finish()

func finish() -> void:
	var value := {"checks":checks,"failures":failures,"fresh_os_process":fresh_process,
		"original_attempts":original_count,"final_attempts":controller.attempts.size(),"native_replays":replayed}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("reopen-summary.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(value,"  ")); file.close()
	print("BATCH_REOPEN_RESULT ",JSON.stringify(value))
	controller.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
