extends SceneTree

## Independent, preconditioned gameplay relationships. These positive controls
## qualify the observer; they are never reported as discovered production bugs.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Assertions = preload("res://goblin/goblin_assertions.gd")
const GameplayOracles = preload("res://goblin/goblin_gameplay_oracles.gd")
var adapter: Node
var oracle: RefCounted
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var experiments: Array[Dictionary] = []
var _boundary_deadline := 0
var _boundary_native_limit := 0
var _boundary_actor_limit := 0
var _boundary_limit_reason := ""


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_METAMORPHIC " + label)


func action(id: String, args: Dictionary = {}, allow_boundary: bool = false) -> Dictionary:
	print("GOBLIN_METAMORPHIC_PROPOSED ", JSON.stringify({"index": records.size(), "id": id, "args": args}))
	var row: Dictionary = await adapter.execute({"id": id, "args": args})
	row["assertions"] = oracle.evaluate(row)
	records.append(row)
	check(row.status == "completed" or (allow_boundary and GameplayOracles.expected_boundary_refusal(row)),
		id + " completed or explicitly expected boundary partial: " + str(row.error))
	for result: Dictionary in row.assertions:
		check(result.status != "fail", id + " / " + result.id + " / " + str(result.actual))
	return row


func _boundary_watchdog() -> void:
	if _boundary_deadline <= 0 or adapter == null: return
	var observed: Dictionary = adapter.observe()
	if Time.get_ticks_msec() >= _boundary_deadline:
		_boundary_limit_reason = "20-second boundary experiment wall limit"
	elif int(observed.native.tick) >= _boundary_native_limit:
		_boundary_limit_reason = "256 observed native ticks boundary experiment limit"
	elif int(observed.actor_tick) >= _boundary_actor_limit:
		_boundary_limit_reason = "160 observed physical ticks boundary experiment limit"
	if not _boundary_limit_reason.is_empty():
		_boundary_deadline = 0
		adapter.request_stop()


func finite_boundary_experiment() -> void:
	# This fixture has no upper retaining wall. Ordinary placement, pilot
	# selection and W input alone move the Kestrel toward the finite canvas.
	if not await install("history_edges"): return
	var first_record := records.size()
	var placed := await action("actor_place", {"model": "kestrel", "x": 256, "y": 32})
	if placed.status != "completed":
		experiments.append({"id": "finite_canvas_refusal_recovery", "status": "coverage_unqualified",
			"reason": "ordinary placement did not complete", "first_record": first_record, "gameplay_defect_confirmed": false})
		return
	var pilot := await action("actor_pilot", {"actor_id": 1})
	if pilot.status != "completed":
		experiments.append({"id": "finite_canvas_refusal_recovery", "status": "coverage_unqualified",
			"reason": "ordinary pilot selection did not complete", "first_record": first_record, "gameplay_defect_confirmed": false})
		return
	var initial: Dictionary = adapter.observe()
	var start_msec := Time.get_ticks_msec()
	_boundary_deadline = start_msec + 20000
	_boundary_native_limit = int(initial.native.tick) + 256
	_boundary_actor_limit = int(initial.actor_tick) + 160
	_boundary_limit_reason = ""
	process_frame.connect(_boundary_watchdog)
	var refusal := {}
	var first_play := await action("play", {"ticks": 1}, true)
	if GameplayOracles.expected_boundary_refusal(first_play): refusal = first_play
	var pulses := 0
	for _pulse: int in 8:
		if not refusal.is_empty() or not _boundary_limit_reason.is_empty(): break
		# An edge may be published between two ordinary inputs. A bounded Play
		# attempt then exercises the same current-publication interval path.
		var observed: Dictionary = adapter.observe()
		if not observed.get("progress_refusal", {}).is_empty():
			var retry := await action("play", {"ticks": 1}, true)
			if GameplayOracles.expected_boundary_refusal(retry): refusal = retry
			break
		var driven := await action("actor_drive", {"direction": "up", "ticks": 16}, true)
		pulses += 1
		if GameplayOracles.expected_boundary_refusal(driven): refusal = driven
		elif driven.status != "completed": break
	_boundary_deadline = 0
	process_frame.disconnect(_boundary_watchdog)
	var stopped: Dictionary = adapter.observe()
	var elapsed_to_stop: int = Time.get_ticks_msec() - start_msec
	var reached := not refusal.is_empty()
	check(reached, "actual finite-edge refusal exercised within the bounded ordinary input experiment")
	if reached:
		check(stopped.paused and stopped.native.paused and not stopped.native.failed,
			"finite-edge refusal leaves an actually healthy paused native owner")
		check(int(stopped.native.generation) == int(initial.native.generation), "edge refusal preserves native World identity")
		check(stopped.actors.size() == 1 and stopped.actors[0].position[1] < initial.actors[0].position[1],
			"ordinary Kestrel input produced actual upward movement before the edge stop")
		# A later ordinary paint proposal must retain the worker's legal edge
		# refusal without ending the campaign as a broken capture adapter.
		var blocked: Dictionary = await adapter.execute({"id": "brush", "args": {"x": 48, "y": 48, "radius": 0}})
		blocked["assertions"] = oracle.evaluate(blocked)
		records.append(blocked)
		check(blocked.status == "refused" and blocked.classification == "not_applicable" and blocked.admission.is_empty(),
			"ordinary brush after finite-edge stop is an expected unadmitted refusal")
		check(GameplayOracles.expected_boundary_capture_refusal(blocked.capture_before),
			"actual follow-up capture retains exact current publication and native source")
		check(blocked.before.native == blocked.after.native, "refused follow-up brush leaves native state unchanged")
		for assertion: Dictionary in blocked.assertions:
			check(assertion.status != "fail", "boundary follow-up brush / " + str(assertion.id))
	var recovery_ok := false
	if not stopped.native.failed:
		adapter.resume_actions()
		if not stopped.paused: await action("pause")
		var reset := await action("actor_reset")
		if reset.status == "completed":
			var resumed := await action("play", {"ticks": 2})
			recovery_ok = resumed.status == "completed" and int(resumed.after.native.generation) > int(stopped.native.generation) \
				and int(resumed.after.native.tick) > int(resumed.before.native.tick) \
				and resumed.after.get("progress_refusal", {}).is_empty() and not resumed.after.native.failed
			check(recovery_ok, "ordinary reset adopts a new healthy owner and resumed native ticks")
			await action("pause")
	experiments.append({"id": "finite_canvas_refusal_recovery",
		"status": "qualified" if reached and recovery_ok else "coverage_unqualified",
		"preconditions": "open upper history_edges fixture; ordinary Kestrel placement at (256,32), pilot and up input",
		"classification": "expected_refusal" if reached else "unresolved_observation", "gameplay_defect_confirmed": false,
		"first_record": first_record, "last_record": records.size() - 1, "up_pulses": pulses,
		"max_up_pulses": 8, "requested_ticks_per_pulse": 16, "wall_limit_msec": 20000,
		"native_tick_limit": 256, "physical_tick_limit": 160, "limit_reason": _boundary_limit_reason,
		"elapsed_to_stop_msec": elapsed_to_stop,
		"initial": initial, "at_stop": stopped, "expected_refusal": refusal.get("expected_refusal", {}),
		"recovery_observed": recovery_ok})


func install(id: String) -> bool:
	var result: Dictionary = await adapter.install_fixture(id, Fixtures.build(id, adapter.policy()))
	check(result.get("ok", false), "actual fixture installed: " + id)
	oracle.reset(result)
	return bool(result.get("ok", false))


func capture(region: Rect2i) -> Dictionary:
	var observed: Dictionary = await adapter.capture(region)
	check(not observed.has("error") and observed.get("source_matches", false), "source-matched native capture: " + str(observed.get("error", "")))
	return observed


func count_material(captured: Dictionary, material: int) -> int:
	var count := 0
	for cell: Variant in captured.get("materials", []):
		if int(cell) == material: count += 1
	return count


func run() -> void:
	adapter = Adapter.new()
	root.add_child(adapter)
	oracle = Assertions.new()
	var mounted: Dictionary = await adapter.mount()
	check(mounted.get("ok", false), "actual ordinary Workbench mounted")
	if not mounted.get("ok", false):
		await finish()
		return
	if await install("history_edges"):
		# Both empty translated regions are wholly interior, paused, actor-free
		# and have identical initial materials. Only native cell arrays compare.
		var first_region := Rect2i(200, 64, 24, 24)
		var translated_region := Rect2i(248, 112, 24, 24)
		var first_start: Dictionary = await capture(first_region)
		var second_start: Dictionary = await capture(translated_region)
		check(first_start.get("materials") == second_start.get("materials"), "translation control precondition: equal initial native planes")
		await action("select_material", {"material": 7})
		await action("outline", {"x0": 204, "y0": 68, "x1": 219, "y1": 83})
		await action("outline", {"x0": 252, "y0": 116, "x1": 267, "y1": 131})
		var first_result: Dictionary = await capture(first_region)
		var translated_result: Dictionary = await capture(translated_region)
		check(first_result.get("materials") == translated_result.get("materials"), "interior translated outline has equal relative materials")
		experiments.append({"id": "translated_paused_outline", "preconditions": "equal empty interior planes, no actors, paused",
			"before": [first_start, second_start], "after": [first_result, translated_result]})
		var expected: Array = translated_result.get("materials", []).duplicate()
		await action("undo")
		var reversed: Dictionary = await capture(translated_region)
		check(reversed.get("materials") == second_start.get("materials"), "Undo restores actual observed preimage")
		await action("redo")
		var repeated: Dictionary = await capture(translated_region)
		check(repeated.get("materials") == expected, "Redo restores actual observed postimage")
		experiments.append({"id": "undo_redo_roundtrip", "preconditions": "same paused native owner and uninterrupted history",
			"before": translated_result, "undo": reversed, "redo": repeated})
		var identity: Dictionary = adapter.observe()
		var rejected: Dictionary = await adapter.execute({"id": "stroke", "args": {"x0": -1, "y0": 64, "x1": 16, "y1": 64, "radius": 2}})
		records.append(rejected)
		var after_rejection: Dictionary = await capture(first_region)
		check(rejected.status == "refused" and rejected.admission.is_empty(), "invalid boundary action refused before gameplay admission")
		check(after_rejection.get("materials") == first_result.get("materials") and identity.native == rejected.after.native,
			"rejected action has no forbidden native mutation")
		experiments.append({"id": "invalid_action_nonmutation", "preconditions": "paused settled World, no admission",
			"record": rejected, "readback": after_rejection})
		await action("save_layout")
		var saved_native: Dictionary = await capture(first_region)
		await action("erase", {"x": 204, "y": 68, "radius": 2})
		await action("reopen_layout")
		var reopened_native: Dictionary = await capture(first_region)
		check(saved_native.get("materials") == reopened_native.get("materials"), "authored Save/Reopen at tick zero preserves native material plane")
		experiments.append({"id": "authored_roundtrip", "preconditions": "saved at native tick zero, actor-free complete capture",
			"saved": saved_native, "reopened": reopened_native})
	if await install("conservation_cell"):
		# The 48x48 hard enclosure is the entire connected local system. Sand
		# has no reactive partner, emitter, actor or open edge in this region.
		var enclosure := Rect2i(48, 48, 48, 48)
		var before: Dictionary = await capture(enclosure)
		check(count_material(before, 2) == 64, "independently counted initial Sand = 64")
		check(count_material(before, 58) == 368, "independently counted hard enclosure = 368")
		for _step: int in 16: await action("single_step")
		var after: Dictionary = await capture(enclosure)
		check(count_material(after, 2) == count_material(before, 2), "isolated nonreactive Sand cell count conserved")
		check(count_material(after, 58) == count_material(before, 58), "hard enclosure count unchanged")
		check(after.get("materials") != before.get("materials"), "native Sand actually moved during exact steps")
		var sum_y_before := 0
		var sum_y_after := 0
		for index: int in before.get("materials", []).size():
			if int(before.materials[index]) == 2: sum_y_before += int(index / 48)
			if int(after.materials[index]) == 2: sum_y_after += int(index / 48)
		check(sum_y_after > sum_y_before, "independent Sand centre of mass moves downward")
		experiments.append({"id": "closed_sand_conservation", "preconditions": "hard sealed enclosure, 64 Sand, no reactions, actors or sources",
			"before": before, "after": after, "sum_y_before": sum_y_before, "sum_y_after": sum_y_after})
		# These readonly stale-source requests are diagnostic negative controls,
		# not ordinary gameplay actions and never action-vocabulary coverage.
		var stable: Dictionary = adapter.observe().native
		var stale_controls: Array[Dictionary] = []
		for field: String in ["generation", "revision", "tick"]:
			var request := {"kind": "capture", "region": Rect2i(48, 48, 8, 8),
				"expected_generation": int(stable.generation), "expected_revision": int(stable.revision), "expected_tick": int(stable.tick)}
			check(int(stable[field]) > 0, "positive source identity permits stale " + field + " control")
			request["expected_" + field] -= 1
			var admission: Dictionary = adapter.worker.paint_queue(request)
			check(admission.get("status") == "refused", "actual worker refuses stale " + field + " before native capture")
			var unexpected_receipt := {}
			if admission.get("status") == "queued":
				if await adapter._until(func() -> bool: return adapter.worker.paint_state().get("receipt_ready", false), "operation_seconds", true):
					unexpected_receipt = adapter.worker.paint_take_result()
			stale_controls.append({"field": field, "request": Adapter.json_value(request),
				"admission": Adapter.json_value(admission), "unexpected_receipt": Adapter.json_value(unexpected_receipt)})
		var unchanged: Dictionary = await capture(enclosure)
		check(adapter.observe().native == stable and unchanged.get("materials") == after.get("materials"),
			"stale readonly diagnostic controls preserve current native owner and material plane")
		experiments.append({"id": "stale_native_identity_refusal", "classification": "deliberately injected negative control",
			"preconditions": "paused settled source; stale generation, revision and tick independently decremented",
			"controls": stale_controls, "before": after, "after": unchanged})
	await finite_boundary_experiment()
	await finish()


func finish() -> void:
	var report := {"evidence_kind": "actual_headless_godot", "checks": checks, "failures": failures,
		"records": records, "experiments": experiments, "godot": Engine.get_version_info(),
		"profile": Adapter.verify_profile(), "classification": "positive metamorphic qualification"}
	if Adapter.verify_profile().get("ok", false):
		DirAccess.make_dir_recursive_absolute("user://goblin")
		var file := FileAccess.open("user://goblin/metamorphic-test.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	if adapter != null:
		await adapter.close()
		adapter.queue_free()
		await process_frame
	print("GOBLIN_METAMORPHIC_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "experiments": experiments.size(), "records": records.size()}))
	quit(1 if not failures.is_empty() else 0)
