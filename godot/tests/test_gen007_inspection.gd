extends SceneTree

var assertions: int = 0
var failures: int = 0
var completed: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL GEN007_INSPECTION: ", message)

func _finish() -> void:
	print("GEN007_INSPECTION: %d assertions; %d failures; completed=%s" % [assertions, failures, completed])
	quit(0 if failures == 0 else 1)

func _recipe(name: String) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://../examples/worldgen/" + name + ".json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "valid fixture recipe " + name)
	return parsed if parsed is Dictionary else {}

func _run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		_check(false, "required source-matched native generator")
		_finish()
		return
	var g: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	if not g.has_method(&"adopt_configuration"):
		_check(false, "required GEN-007 inspection/adoption API")
		_finish()
		return
	_base(g)
	_planes(g)
	_adoption(g)
	_check(completed.size() == 3, "all inspection/adoption sections ran to completion")
	_finish()

func _base(g: Object) -> void:
	var recipe: Dictionary = {"schema": 1, "seed": 193, "chunk_size": 8,
		"paths": [{"id": "clear", "points": [[1, 3], [6, 3]], "width": 1, "material": 0}],
		"overrides": [{"id": "last", "bounds": [3, 3, 1, 1], "material": 39}],
		"fields": [{"id": "one", "kind": "constant", "parameters": {"value": 1}}],
		"modifiers": [{"id": "fill", "application": "one", "material": 2}]}
	var configured: Dictionary = g.configure(recipe)
	_check(configured.get("ok", false), "base configure " + str(configured))
	if not configured.get("ok", false): return
	var before: Dictionary = g.generate_chunk(Vector2i.ZERO)
	var trace: Dictionary = g.inspect_generation(Vector2i(3, 3), "", configured.revision, configured.fingerprint)
	_check(trace.get("ok", false) and trace.get("identity_checked", false), "inspection requires matching serial and fingerprint")
	if not trace.get("ok", false): return
	_check(trace.material == before.cells[3*8+3] and trace.stages.final == trace.material, "replay equals independently accepted payload cell")
	_check(trace.mode == "deterministic_replay" and trace.proposal_hash.length() == 16 and not trace.truncated, "explicit replay identity and trace extent")
	_check(trace.scalar_fields.one == 1.0 and trace.contributions[-1].stage == "hard_override", "actual field value and final precedence")
	for stage: String in ["candidate", "guided_candidate", "grammar", "modifiers", "connectivity", "final"]:
		var result: Dictionary = g.generate_chunk(Vector2i.ZERO, "stage:" + stage)
		_check(result.get("ok", false) and result.cells == before.cells and result.stage_cells[3*8+3] == trace.stages[stage], "real stage " + stage)
	_check(not g.inspect_generation(Vector2i(3, 3), "", configured.revision - 1, configured.fingerprint).ok, "stale serial rejected")
	_check(not g.inspect_generation(Vector2i(3, 3), "", configured.revision, "wrong").ok, "stale fingerprint rejected")
	_check(not g.inspect_generation(Vector2i(3, 3), "background", configured.revision, configured.fingerprint).ok, "unconfigured plane explicit failure")
	var after: Dictionary = g.generate_chunk(Vector2i.ZERO)
	_check(before.cells == after.cells and before.receipt_hash == after.receipt_hash, "inspection does not mutate later native generation")
	var current: Dictionary = g.configure(recipe)
	_check(current.ok and current.revision > configured.revision, "identical recipe still retires request serial")
	_check(not g.inspect_generation(Vector2i(3, 3), "", configured.revision, configured.fingerprint).ok, "old identical-recipe trace rejected")
	completed.append("base-stages-and-identity")

func _planes(g: Object) -> void:
	var configured: Dictionary = g.configure(_recipe("semantic-refinery"))
	_check(configured.get("ok", false), "semantic plane configure")
	if not configured.get("ok", false): return
	var plan: Dictionary = g.get_plane_plan()
	var point: Vector2i = plan.bounds.position + Vector2i(12, 12)
	var region := Rect2i(point, Vector2i(8, 8))
	var accepted: Dictionary = g.generate_plane_region(region)
	_check(accepted.get("ok", false), "native plane proposal")
	if not accepted.get("ok", false): return
	for plane: String in ["play", "scripted", "effects", "background"]:
		var trace: Dictionary = g.inspect_generation(point, plane, configured.revision, configured.fingerprint)
		_check(trace.get("ok", false) and trace.material == accepted.materials[plane][0], "plane replay matches accepted native cell " + plane)
		_check(trace.mode == "deterministic_replay" and trace.plane_fingerprint == accepted.fingerprint, "plane identity " + plane)
		for stage: String in ["policy", "base", "projections", "final"]:
			var pending: Dictionary = g.begin_stage_region(region, plane, stage)
			_check(pending.get("ok", false) and pending.state == "running" and not pending.has("cells"), "stage private while pending")
			var guard: int = 0
			while pending.get("ok", false) and pending.get("state") == "running" and guard < 100:
				pending = g.advance_stage_region(7)
				guard += 1
			_check(pending.get("ok", false) and pending.get("state") == "ready", "bounded stage completes " + plane + ":" + stage)
			if pending.get("ok", false) and pending.get("state") == "ready":
				_check(pending.final_cells == accepted.materials[plane] and pending.cells[0] == trace.stages[stage], "stage retains original final payload and actual intermediate")
				_check(pending.revision == configured.revision and pending.fingerprint == configured.fingerprint and pending.projection_checks.size() == 64, "stage identity and measured index checks")
	_check(not g.begin_stage_region(region, "background", "grammar").ok, "unavailable base stage on far plane fails explicitly")
	var started: Dictionary = g.begin_stage_region(region, "play", "final")
	var refused: Dictionary = g.begin_stage_region(Rect2i(point, Vector2i(257, 1)), "play", "final")
	_check(started.ok and not refused.ok and g.advance_stage_region(1).completed_cells == 1, "invalid stage request preserves pending valid job")
	_check(g.cancel_stage_region().ok and not g.advance_stage_region(1).ok, "cancelled stage cannot publish late data")
	_check(g.begin_stage_region(region, "play", "final").ok, "prepare pending job for retirement")
	var changed: Dictionary = g.configure(_recipe("semantic-flooded-cavern"))
	_check(changed.ok and not g.advance_stage_region(1).ok, "successful recipe change retires stage job")
	_check(not g.inspect_generation(point, "play", configured.revision, configured.fingerprint).ok, "plane trace old serial rejected")
	completed.append("plane-stage-and-cancellation")

func _adoption(g: Object) -> void:
	var prepared: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var initial: Dictionary = g.configure({"seed": 21, "chunk_size": 8})
	var candidate: Dictionary = prepared.configure({"seed": 193, "chunk_size": 8})
	var expected: Dictionary = prepared.generate_chunk(Vector2i.ZERO)
	_check(not g.adopt_configuration(null, initial.revision).ok, "null prepared owner rejects")
	_check(not g.adopt_configuration(g, initial.revision).ok, "self adoption rejects")
	var empty: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	_check(not g.adopt_configuration(empty, initial.revision).ok, "unconfigured owner rejects")
	_check(not g.adopt_configuration(prepared, initial.revision - 1).ok, "stale expected receiver rejects")
	_check(prepared.begin_chunk(Vector2i.ZERO).ok and not g.adopt_configuration(prepared, initial.revision).ok, "pending candidate work rejects")
	_check(prepared.advance(64).ok, "complete prepared private work")
	var old_stage: Dictionary = g.begin_stage_region(Rect2i(0, 0, 8, 8), "", "grammar")
	_check(old_stage.ok, "receiver pending stage")
	var adopted: Dictionary = g.adopt_configuration(prepared, initial.revision)
	_check(adopted.get("ok", false) and adopted.revision == initial.revision + 1 and adopted.fingerprint == candidate.fingerprint, "adopt immutable native identity with fresh receiving serial")
	if not adopted.get("ok", false): return
	var actual: Dictionary = g.generate_chunk(Vector2i.ZERO)
	_check(actual.cells == expected.cells and actual.hash == expected.hash and actual.receipt_hash == expected.receipt_hash, "native result receipt remains bound to original native recipe revision")
	_check(actual.revision == adopted.revision and not g.advance_stage_region(1).ok, "adapter serial independent of native receipt and old stage retired")
	_check(not g.inspect_generation(Vector2i.ZERO, "", initial.revision, initial.fingerprint).ok, "old receiver trace rejected after adoption")
	var isolated: Dictionary = prepared.get_configuration()
	isolated.seed = 999
	_check(g.get_configuration().seed == 193 and prepared.configure(isolated).ok, "receiving config copy is independent")
	_check(g.generate_chunk(Vector2i.ZERO).cells == expected.cells, "subsequent prepared-owner mutation cannot change accepted immutable plan")
	var same: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	_check(same.configure(g.get_configuration()).ok, "prepare content-identical undo recipe")
	var again: Dictionary = g.adopt_configuration(same, adopted.revision)
	_check(again.ok and again.revision == adopted.revision + 1 and g.generate_chunk(Vector2i.ZERO).cells == actual.cells, "content-identical adoption fresh serial and reproducible baseline")
	_check(not g.inspect_generation(Vector2i.ZERO, "", adopted.revision, adopted.fingerprint).ok, "same-content prior trace serial cannot reenter")
	completed.append("immutable-adoption")
