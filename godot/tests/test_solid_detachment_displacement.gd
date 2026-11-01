extends SceneTree

# Execute the actual native conservative-contact transaction on intact frozen
# contacts and separate analytical boundary controls. Rapier trajectory/worker
# interleavings belong to the actual-host tests; this suite freezes the geometry.
const FIXTURE_PATH: String = "res://tests/fixtures/sol281/conservative_contacts.json"
const AMBIENT: int = 200
var checks: int = 0
var failures: Array[String] = []
var workers: int = 1
var report_path: String = ""
var case_reports: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 DISPLACEMENT ", message)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = int(argument.trim_prefix("--workers="))
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif not argument.begins_with("--") and report_path.is_empty():
			report_path = argument
	check(workers in [1, 4], "configured worker count is 1 or 4")
	check(ClassDB.class_exists(&"CyberNativeCellWorld"), "source-matched native class exists")
	if not failures.is_empty():
		_finish({})
		return
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	check(fixture is Dictionary, "frozen contact fixture parses as a dictionary")
	if not fixture is Dictionary:
		_finish({})
		return
	check(int(fixture.get("schema_version", 0)) == 1, "fixture schema version is supported")
	var cases: Array = fixture.get("fixtures", [])
	check(cases.size() == 17, "all eight frozen and nine boundary cases are present")
	for record: Dictionary in cases:
		_run_case(record)
	_finish(fixture.get("source", {}))

func _run_case(record: Dictionary) -> void:
	var label: String = str(record.id)
	var start_failures: int = failures.size()
	var capsule: Dictionary = record.capsule.duplicate(true)
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world != null and world.has_method("diagnostic_replay_conservative_contact"),
		label + ": real production replay API is available")
	if world == null or not world.has_method("diagnostic_replay_conservative_contact"):
		return
	check(bool(world.diagnostic_reset({"workers":workers})), label + ": isolated native owner resets")
	var input_before: String = JSON.stringify(capsule)
	var result: Dictionary = world.diagnostic_replay_conservative_contact(capsule)
	check(JSON.stringify(capsule) == input_before, label + ": immutable caller capsule is not modified")
	check(bool(result.get("ok", false)), label + ": complete capsule imports without malformed-input refusal")
	check(not bool(result.get("fatal", false)), label + ": contact transaction does not quarantine its native owner")
	check(int(result.get("workers", -1)) == workers, label + ": replay preserves configured native worker count")
	var before: Array = result.get("before", [])
	var after: Array = result.get("after", [])
	var bounds: Array = capsule.bounds
	check(before.size() == capsule.cells.size() and after.size() == before.size(),
		label + ": complete copied before/after domain returned")
	if before.size() != capsule.cells.size() or after.size() != before.size():
		case_reports.append({"id":label, "origin":record.origin, "outcome":result.get("outcome", "missing"),
			"failure_count":failures.size() - start_failures})
		world = null
		return
	var exact_input: bool = true
	var masks_unchanged: bool = true
	for index: int in range(before.size()):
		var input_row: Array = capsule.cells[index]
		var prior: Array = before[index]
		var following: Array = after[index]
		if prior.size() < 5 or following.size() < 5:
			exact_input = false
			masks_unchanged = false
			continue
		for field: int in range(5):
			if int(prior[field]) != int(input_row[field]):
				exact_input = false
		if int(prior[4]) != int(following[4]):
			masks_unchanged = false
	check(exact_input, label + ": source material/state/temperature and positional mask import exactly")
	check(masks_unchanged, label + ": contact displacement never transfers body masks")
	check(_parcels(before) == _parcels(after), label + ": full nonempty semantic parcel multiset is conserved")
	check(_water_quantity(before) == _water_quantity(after), label + ": fractional Water quantity is conserved")
	var moved: int = int(result.get("moved_cells", -1))
	var path: Array = result.get("path", [])
	var expected_accepted: bool = bool(record.expected_accepted)
	if expected_accepted:
		check(str(result.get("outcome", "")) == "Applied", label + ": successful result has the admitted outcome")
		check(moved == int(record.expected_minimum_moves), label + ": declared multi-parcel chain really moves")
		check(path.size() == moved + 1 and moved > 0, label + ": committed path describes every parcel move")
		check(_same_path(path, record.expected_path), label + ": unique conservative path matches the independent fixture")
		check(bool(result.get("geometry_clear", false)), label + ": native full-square geometry admitted every destination")
		_verify_path(label, capsule, before, after, path)
		# Reconstruct the resulting semantic state and repeat the identical source
		# contact. This proves replay-state idempotence, not an asynchronous lease.
		var repeat_capsule: Dictionary = capsule.duplicate(true)
		for index: int in range(after.size()):
			var row: Array = repeat_capsule.cells[index]
			for field: int in range(5):
				row[field] = int(after[index][field])
			row[5] = false # These fixtures contain only Empty, Sand and Current Water.
			row[6] = int(row[0]) in [2, 3]
			row[7] = int(row[1]) if int(row[0]) == 3 else 0
			row[8] = "%016x" % (int(row[0]) | (int(row[1]) << 16) | (int(row[2]) << 32))
		var repeated: Dictionary = world.diagnostic_replay_conservative_contact(repeat_capsule)
		check(bool(repeated.get("ok", false)), label + ": resulting-state repeat imports successfully")
		check(int(repeated.get("moved_cells", -1)) == 0, label + ": repeated vacated source displaces no parcel")
		check(repeated.get("before", []) == repeated.get("after", ["missing"]),
			label + ": repeated vacated-source refusal leaves all tuples unchanged")
	else:
		if label == "source_square_foreign_body_despite_first_writer_mask":
			check(str(result.get("outcome", "")) == "SourceOwnership", label + ": foreign source geometry is the actual refusal cause")
		if label in ["same_path_second_proxy_square_overlap", "same_path_exact_touch"]:
			check(str(result.get("outcome", "")) == "GeometryBlocked", label + ": destination geometry is the actual refusal cause")
		check(moved == 0 and path.is_empty(), label + ": unsafe contact has no committed path")
		check(before == after, label + ": refused contact leaves every copied tuple unchanged")
	case_reports.append({"id":label, "origin":record.origin, "expected_accepted":expected_accepted,
		"outcome":result.get("outcome", "missing"), "moved_cells":moved, "path":path,
		"geometry_clear":result.get("geometry_clear", false), "water_quantity":_water_quantity(after),
		"before_sha256":JSON.stringify(before).sha256_text(), "after_sha256":JSON.stringify(after).sha256_text(),
		"normal":capsule.normal, "bounds":bounds, "counters":result.get("counters", {}),
		"failure_count":failures.size() - start_failures})
	world = null

func _verify_path(label: String, capsule: Dictionary, before: Array, after: Array, path: Array) -> void:
	if path.size() < 2:
		return
	var bounds: Array = capsule.bounds
	var source: Array = capsule.source
	var normal := Vector2(float(capsule.normal[0]), float(capsule.normal[1]))
	check(_same_point(path[0], source), label + ": chain starts at the captured contact")
	var sites: Dictionary = {}
	var all_local: bool = true
	var all_forward: bool = true
	var exact_permutation: bool = true
	var all_clear: bool = true
	var net_progress: float = 0.0
	var bodies: Array = capsule.get("all_current_bodies", [capsule.current_body])
	for index: int in range(path.size()):
		var point: Array = path[index]
		var cell_index: int = _index(point, bounds)
		if cell_index < 0 or cell_index >= before.size():
			check(false, label + ": chain remains inside copied domain")
			return
		var key: String = "%d,%d" % [int(point[0]), int(point[1])]
		check(not sites.has(key), label + ": chain contains no repeated site")
		sites[key] = true
		if index == 0:
			exact_permutation = exact_permutation and int(after[cell_index][0]) == 0
			continue
		var prior: Array = path[index - 1]
		var previous_index: int = _index(prior, bounds)
		var delta := Vector2i(int(point[0]) - int(prior[0]), int(point[1]) - int(prior[1]))
		all_local = all_local and absi(delta.x) + absi(delta.y) == 1
		var projection: float = float(delta.x) * normal.x + float(delta.y) * normal.y
		all_forward = all_forward and projection >= 0.0
		net_progress += projection
		for field: int in range(4):
			exact_permutation = exact_permutation and int(after[cell_index][field]) == int(before[previous_index][field])
		all_clear = all_clear and int(before[cell_index][4]) == 0
		for body: Array in bodies:
			all_clear = all_clear and _square_clear(point, body)
	check(all_local, label + ": each parcel moves exactly one cardinal cell")
	check(all_forward and net_progress > 0.0, label + ": every step is nonrearward with positive net progress")
	check(exact_permutation, label + ": tail-first commit is the exact declared semantic parcel permutation")
	check(all_clear, label + ": independently calculated full-square clearance holds for every proxy")
	var outside_unchanged: bool = true
	for index: int in range(before.size()):
		var x: int = int(bounds[0]) + index % int(bounds[2])
		var y: int = int(bounds[1]) + index / int(bounds[2])
		if not sites.has("%d,%d" % [x,y]) and before[index] != after[index]:
			outside_unchanged = false
	check(outside_unchanged, label + ": cells outside the committed path remain exact")

func _same_point(left: Array, right: Array) -> bool:
	# Godot JSON numbers are floats; native replay coordinates are integers.
	# Compare their exact numeric values, without truncating a fractional value.
	return left.size() == 2 and right.size() == 2 and float(left[0]) == float(right[0]) and float(left[1]) == float(right[1])

func _same_path(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if not _same_point(left[index], right[index]):
			return false
	return true

func _index(point: Array, bounds: Array) -> int:
	var x: int = int(point[0]) - int(bounds[0])
	var y: int = int(point[1]) - int(bounds[1])
	if x < 0 or y < 0 or x >= int(bounds[2]) or y >= int(bounds[3]):
		return -1
	return y * int(bounds[2]) + x

func _square_clear(point: Array, body: Array) -> bool:
	var dx: float = float(point[0]) + 0.5 - float(body[1])
	var dy: float = float(point[1]) + 0.5 - float(body[2])
	var cosine: float = cos(float(body[3]))
	var sine: float = sin(float(body[3]))
	var hx: float = float(body[4])
	var hy: float = float(body[5])
	var projected_square: float = 0.5 * (absf(cosine) + absf(sine))
	var gap: float = maxf(absf(dx*cosine + dy*sine) - hx - projected_square,
		absf(-dx*sine + dy*cosine) - hy - projected_square)
	gap = maxf(gap, absf(dx) - (0.5 + hx*absf(cosine) + hy*absf(sine)))
	gap = maxf(gap, absf(dy) - (0.5 + hx*absf(sine) + hy*absf(cosine)))
	return gap > 0.000000001

func _parcels(rows: Array) -> Dictionary:
	var histogram: Dictionary = {}
	for row: Array in rows:
		if row.size() < 5 or int(row[0]) == 0:
			continue
		var key: String = "%d:%d:%d:%d" % [int(row[0]), int(row[1]), int(row[2]), int(row[3])]
		histogram[key] = int(histogram.get(key, 0)) + 1
	return histogram

func _water_quantity(rows: Array) -> int:
	var amount: int = 0
	for row: Array in rows:
		if row.size() >= 5 and int(row[0]) == 3:
			amount += int(row[1])
	return amount

func _finish(source: Dictionary) -> void:
	var report: Dictionary = {"schema":"cybersand.sol281.conservative-displacement-replay.v1",
		"checks":checks, "failures":failures, "platform":OS.get_name(), "configured_workers":workers,
		"fixture_sha256":FileAccess.get_sha256(FIXTURE_PATH), "historical_source":source, "cases":case_reports,
		"scope":"real native transaction with frozen geometry; no actual Rapier trajectory, asynchronous race or frame-rate claim"}
	if not report_path.is_empty():
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		check(output != null, "result report can be written")
		if output != null:
			report.checks = checks
			report.failures = failures
			output.store_string(JSON.stringify(report, "\t", true, true) + "\n")
			output.close()
	print("SOL281_CONSERVATIVE_DISPLACEMENT ", JSON.stringify({"checks":checks, "failures":failures,
		"platform":OS.get_name(), "configured_workers":workers, "cases":case_reports.size()}))
	quit(0 if failures.is_empty() else 1)
