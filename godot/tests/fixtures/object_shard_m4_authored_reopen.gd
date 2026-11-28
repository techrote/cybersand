extends SceneTree

# A second process reopens the exact bytes produced by the ordinary M4
# completion fixture. The save contains the authored start, including edits.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const NAME = "objectshard-m4-qualification-authored-start"
var fixture: RefCounted

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	fixture = Fixture.new(self)
	var producer := OS.get_environment("CYBERSAND_M4_AUTHOR_PID").to_int()
	var file_hash := OS.get_environment("CYBERSAND_M4_AUTHORED_FILE")
	var setup_hash := OS.get_environment("CYBERSAND_M4_INSTALLED_SETUP")
	if not fixture.expect(producer > 0 and producer != OS.get_process_id() and file_hash.length() == 64 and setup_hash.length() == 64,
			"fresh-process reopen has a distinct producer and complete source identity"):
		await _finish()
		return
	if not fixture.expect(FileAccess.get_sha256(Setup._path(NAME)) == file_hash, "the original authored file is intact"):
		await _finish()
		return
	set_meta("cybersand_feature", "shared_workbench")
	fixture.host = load("res://main.tscn").instantiate()
	root.add_child(fixture.host)
	if not await fixture.until(fixture.installed, "ordinary Workbench startup acknowledged"):
		await _finish()
		return
	fixture.bench = fixture.host.shared_workbench
	fixture.bench._name.text = NAME
	var generation: int = fixture.host.latest_snapshot.render_world_generation
	if fixture.expect(fixture.bench.load_setup(), "normal Workbench Open admits saved construction") and await fixture.until(
			func(): return fixture.installed() and fixture.host.latest_snapshot.render_world_generation > generation,
			"new World owner acknowledges the authored installation"):
		fixture.expect(JSON.stringify(fixture.bench.applied).sha256_text() == setup_hash,
			"fresh process installs the same canonical setup as the original Save/Open")
		fixture.play()
		await fixture.until(func(): return fixture.tick() > 0 and fixture.diagnostics().get("attached", false),
			"reopened structure and native simulation advance together")
		fixture.expect(str(fixture.diagnostics().get("held_reason", "")) == "", "reopen has no unresolved native receipt")
	await _finish()

func _finish() -> void:
	await fixture.close()
	print(JSON.stringify({"schema":"objectshard-m4-fresh-authored-reopen-v1","checks":fixture.checks,
		"failures":fixture.failures,"process_id":OS.get_process_id()}))
	quit(0 if fixture.failures.is_empty() else 1)
