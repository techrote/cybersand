extends "res://tools/qualify_gentek80_workbench.gd"

# Exercise the actual inherited report and production serializer in Godot.
# This is a serialization regression, not catalogue generation or qualification.
func run() -> void:
	check(typeof(report.schema) == TYPE_INT and report.schema == 1, "real parent starts with the generic integer schema")
	var control: Dictionary = report.duplicate(true)
	control.merge({"schema": "gentek80-workbench-phase-v1"})
	check(typeof(control.schema) == TYPE_INT and control.schema == 1, "Godot non-overwriting merge reproduces the rejected inherited schema")
	var fixture_case := {"case": "serialization-fixture-only", "sentinel": "preserved"}
	report.cases.append(fixture_case)
	completed_styles = 80
	catalogue_size = 93
	complete = true
	var author: Dictionary = _assemble_phase_report("author", Time.get_ticks_usec()).duplicate(true)
	check(typeof(author.schema) == TYPE_STRING and author.schema == "gentek80-workbench-phase-v1", "real producer replaces the inherited schema")
	check(author.phase == "author" and author.completed and author.complete, "author phase completion is retained")
	check(author.styles == 80 and author.catalogue_choices == 93, "style and ordinary selector counts are retained")
	check(author.catalogue_ids.size() == 80 and author.catalogue_ids[0] == Project.builtin_presets()[13].id, "actual catalogue identities are retained")
	check(author.cases == [fixture_case], "assembly preserves existing case evidence")
	check(author.process_id == OS.get_process_id(), "assembly records the actual producing process")
	check(author.source_commit == OS.get_environment("CYBERSAND_SOURCE_REVISION"), "assembly preserves supplied source identity")
	var decoded: Variant = JSON.parse_string(JSON.stringify(author, "\t", true, true))
	check(decoded is Dictionary and typeof(decoded.schema) == TYPE_STRING and decoded.schema == "gentek80-workbench-phase-v1", "serialized JSON preserves the phase schema type")
	check(decoded.cases == [fixture_case] and decoded.catalogue_ids == author.catalogue_ids, "serialized case and catalogue data remain intact")
	# Re-exercise the production method with inherited and stale phase fields.
	report.schema = 1
	report.phase = "author"
	report.completed = false
	var reopened: Dictionary = _assemble_phase_report("reopen", Time.get_ticks_usec())
	check(reopened.schema == "gentek80-workbench-phase-v1" and reopened.phase == "reopen" and reopened.completed, "reopen replaces inherited schema and stale phase fields")
	check(reopened.cases == [fixture_case] and reopened.styles == 80, "reopen keeps original case evidence and style count")
	print("GENTEK80_WORKBENCH_RECEIPT checks=", checks, " failures=", failures, " complete=true")
	quit(1 if failures else 0)
