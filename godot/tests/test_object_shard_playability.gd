extends SceneTree

const Session = preload("res://scripts/object_shard_lab_session.gd")
const Presets = preload("res://scripts/object_shard_lab_presets.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
var checks: int = 0
var failures: int = 0
var results: Array[Dictionary] = []
var output: String = ""
var trace_path: String = ""


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-playability-report="):
			output = argument.trim_prefix("--objectshard-playability-report=")
		elif argument.begins_with("--objectshard-playability-trace="):
			trace_path = argument.trim_prefix("--objectshard-playability-trace=")
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberObjectShardLab"), "Actual source-matched Lab is required")
	if failures == 0:
		await _priority_scene()
		await _canvas_and_fixtures()
		await _queue_and_capture()
	var report: Dictionary = {"schema": "objectshard-playability-contract-test-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks": checks, "failures": failures, "cases": results,
		"physical_owner_acceptance": "not established by automated host execution"}
	if not output.is_empty():
		var stream: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if stream != null:
			stream.store_string(JSON.stringify(Capture.json_value(report), "\t") + "\n")
			stream.close()
		else:
			failures += 1
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)


func _priority_scene() -> void:
	var session = Session.new()
	var preset: Dictionary = Presets.definition(7)
	_expect(session.open(0, 12).get("ok", false), "Offcut scene opens a real empty World")
	_expect(Presets.author(session, preset).get("ok", false), "Offcut fixtures use admitted ordinary native mutations")
	var y: int = int(session.frame.height) - 18 - 20
	for x: int in range(1, int(session.frame.width) - 1):
		if int(session.frame.world_materials[y * int(session.frame.width) + x]) == 7:
			session.edit(Vector2i(x, y), 0)
	var first_cells: int = 0
	for tick: int in range(120):
		session.advance(true)
		if first_cells == 0 and not session.frame.shards.is_empty():
			first_cells = int(session.frame.shards[0].structural)
		if session.failed:
			break
	_expect(not session.failed, "Scarce slots and deferred candidates do not make ordinary play fatal")
	_expect(first_cells > 400, "The significant disconnected crown wins admission before tiny offcuts")
	var admission: Dictionary = session.frame.get("admission", {})
	_expect(int(admission.get("slots_used", 0)) == 3 and int(admission.get("deferred", 0)) > 0,
		"Exact occupied-slot and deferred-component pressure is published")
	_expect(not str(admission.get("reason", "")).is_empty(), "A held component has a readable admission reason")
	results.append({"case": "large_plus_offcuts", "first_structural_cells": first_cells, "report": session.export_result()})
	session.close()
	await process_frame


func _canvas_and_fixtures() -> void:
	var session = Session.new()
	for number: int in [8, 9, 10, 11]:
		var preset: Dictionary = Presets.definition(number)
		var started: int = Time.get_ticks_usec()
		_expect(session.open(int(preset.scenario), 12, preset).get("ok", false), "Expanded scene opens: " + str(preset.title))
		_expect(Presets.author(session, preset).get("ok", false), "Expanded scene ordinary authoring completes")
		var setup_usec: int = Time.get_ticks_usec() - started
		_expect(int(session.frame.width) == int(preset.width) and int(session.frame.height) == int(preset.height), "Requested canvas dimensions are real native bounds")
		if number == 10:
			var before: int = session.authored_fixture_fire
			for tick: int in range(24):
				session.advance(true)
			_expect(not session.failed and session.authored_fixture_fire > before,
				"Sustained fixture creates actual World Fire with separate authored accounting")
			var excessive: Array[Vector2i] = []
			for index: int in range(65):
				excessive.append(Vector2i(index, 2))
			_expect(not session.set_burner(excessive, true).get("ok", true), "Burner work is bounded to64 cells")
		results.append({"case": str(preset.title), "width": session.frame.width, "height": session.frame.height,
			"setup_usec": setup_usec, "authored_fixture_fire": session.authored_fixture_fire, "metrics": session.frame.get("metrics", {})})
		await process_frame
	session.close()


func _queue_and_capture() -> void:
	var session = Session.new()
	_expect(session.open(1, 12).get("ok", false), "Input/capture session opens")
	var dimensions: Vector2i = Vector2i(int(session.frame.width), int(session.frame.height))
	if not trace_path.is_empty():
		session.capture.begin({"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "scenario": 1,
			"seed": 12, "width": dimensions.x, "height": dimensions.y, "session": session.frame.session}, trace_path)
	for index: int in range(session.MAX_PENDING_EDITS):
		session.queue_edit(Vector2i(1 + index % 80, 2 + index / 80), 0)
	_expect(session.pending_edits.size() == 256, "Input queue admits its bounded capacity")
	_expect(not session.queue_edit(Vector2i(100, 5), 0).get("ok", true), "Saturation is an explicit nonmutating refusal")
	_expect(session.drain_edits() == 16 and session.pending_edits.size() == 240, "One frame drains at most16 edits")
	session.set_paused(true)
	_expect(not session.export_result().is_empty(), "Pause and bug export remain live under input saturation")
	while not session.pending_edits.is_empty():
		session.drain_edits()
	var y: int = dimensions.y - 18 - 6
	for x: int in range(dimensions.x):
		if int(session.frame.world_materials[y * dimensions.x + x]) == 7:
			session.edit(Vector2i(x, y), 0)
	for tick: int in range(50):
		session.advance(true)
		if session.failed:
			break
	_expect(not session.failed and not session.bridge.bodies.is_empty(), "Recorded ordinary cuts lead to actual moving ownership")
	var before: int = 0
	for owner: Dictionary in session.frame.shards:
		before += int(owner.structural)
	var erased: bool = false
	for owner: Dictionary in session.frame.shards:
		var pose: Transform2D = session._pose(owner)
		for at: int in range(owner.materials.size()):
			if int(owner.roles[at]) != 1:
				continue
			var center: Vector2 = pose * Vector2(float(at % int(owner.width)) + 0.5, float(at / int(owner.width)) + 0.5)
			var point := Vector2i(floori(center.x), floori(center.y))
			var actual: Dictionary = session.inspect(point)
			if int(actual.get("id", 0)) == int(owner.id) and int(actual.get("cell", -1)) == at:
				erased = session.edit(point, 0).get("ok", false)
				break
		if erased:
			break
	var after: int = 0
	for owner: Dictionary in session.frame.shards:
		after += int(owner.structural)
	_expect(erased and after == before - 1, "Moving erase removes exactly one cell from its actual native owner")
	_expect(not session.failed, "Moving edit installs revised geometry between physics steps")
	var report: Dictionary = session.export_result()
	_expect(int(report.observation_window.events_total) >= int(report.observation_window.events_retained), "Event truncation is explicitly counted")
	results.append({"case": "bounded_input_and_trace", "report": report})
	if not trace_path.is_empty():
		_expect(Capture.read_trace(trace_path, OS.get_environment("CYBERSAND_SOURCE_REVISION")).get("ok", false), "Actual action trace is source-bound and replay-admissible")
	var process_steps: int = int(session.frame.get("lifetime_metrics", {}).get("steps", 0))
	session.open(1, 12)
	_expect(int(session.frame.metrics.get("steps", -1)) == 0, "Reset clears current-session native counters")
	_expect(int(session.frame.get("lifetime_metrics", {}).get("steps", 0)) >= process_steps,
		"Process lifetime metrics remain separately labelled")
	session.close()
	await process_frame
