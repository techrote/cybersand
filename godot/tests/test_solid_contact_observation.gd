extends SceneTree

# Actual native facade, with one exclusive synchronous owner. The scripted
# reservation/finalization is an adapter fixture, not a claim of live Rapier
# ownership or gameplay qualification; those have separate host tests.
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const GENERATION: int = 7
const PHYSICS_EPOCH: int = 17
var checks: int = 0
var failures: Array[String] = []
var workers: int = 1
var report_path: String = ""
var case_reports: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 CONTACT OBSERVATION ", message)
	return condition

func _fixture() -> Dictionary:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check(world != null and world.has_method(&"solid_detachment_contact_observation"),
		"source-matched native observation API exists"):
		return {}
	if not check(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})),
		"fresh exclusive native fixture resets"):
		return {}
	world.set_simulation_window_enabled(false)
	check(bool(world.diagnostic_fill_rect(Vector2i(40,30), Vector2i(4,2), 43)), "upper source rectangle authored")
	check(bool(world.diagnostic_fill_rect(Vector2i(40,32), Vector2i(2,2), 43)), "lower partial neighbor authored")
	check(bool(world.simulation_tick()), "initial region inclusion completes")
	var configured: Dictionary = world.solid_detachment_command({"action":"configure", "members":1024, "shapes":64})
	if not check(configured.get("ok", false), "native aggregate capacity configured"):
		return {}
	var source: Dictionary = world.solid_detachment_command({"action":"prepare",
		"domain":Rect2i(32,16,32,32), "anchors":Rect2i(0,80,128,1), "seed":Vector2i(41,31)})
	if not check(source.get("ok", false), "unanchored exact L component prepared"):
		return {}
	check(int(source.member_count) == 12 and int(source.shape_count) == 2,
		"partial shared edge fixture is exactly twelve cells and two proxies")
	var ack: Dictionary = world.solid_detachment_command({"action":"acknowledge", "token":source.token,
		"body_id":1, "body_generation":GENERATION, "shape_count":source.shape_count,
		"payload_digest":source.payload_digest, "shape_digest":source.shape_digest})
	if not check(ack.get("ok", false), "isolated adapter reservation acknowledges exact geometry"):
		return {}
	var committed: Dictionary = world.solid_detachment_command({"action":"commit", "token":source.token})
	if not check(committed.get("ok", false), "native ownership commits once"):
		return {}
	var active: Dictionary = world.solid_detachment_command({"action":"finalize", "token":source.token,
		"body_id":1, "body_generation":GENERATION, "terrain_revision":committed.commit_revision,
		"physics_epoch":PHYSICS_EPOCH})
	if not check(active.get("ok", false), "adapter fixture activates its native lease"):
		return {}
	return {"world":world, "source":source}

func _states(source: Dictionary, pose: Transform2D, sample: int) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	var rectangles: PackedInt32Array = source.rectangles
	var source_center: Vector2 = source.center
	for offset: int in range(0, rectangles.size(), 4):
		var size := Vector2(rectangles[offset + 2], rectangles[offset + 3])
		var local := Vector2(rectangles[offset], rectangles[offset + 1]) + size * 0.5 - source_center
		Coupling.append_input(states, offset / 4 + 1, pose * local, pose.get_rotation(),
			size, Vector2.ZERO, 0.0, size.x * size.y, sample)
	return states

func _observe(world: Object, states: PackedFloat32Array) -> Dictionary:
	world.prepare_rigid_body_coupling(states, false)
	return world.solid_detachment_contact_observation()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = int(argument.trim_prefix("--workers="))
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif not argument.begins_with("--") and report_path.is_empty():
			report_path = argument
	check(workers in [1,4], "native worker count is one or four")
	if not check(ClassDB.class_exists(&"CyberNativeCellWorld"), "actual native runtime loaded"):
		_finish()
		return
	var fixture: Dictionary = _fixture()
	if fixture.is_empty():
		_finish()
		return
	var world: Object = fixture.world
	var source: Dictionary = fixture.source
	var inactive_geometry: Dictionary = world.solid_detachment_contact_observation()
	check(not inactive_geometry.get("ok", true), "active lease without complete proxy input refuses")
	# A dense unchanged interior provides support without converting grains into
	# colliders. It is authored before body masks are installed and ticked once.
	check(bool(world.diagnostic_fill_rect(Vector2i(187,176), Vector2i(30,1), 1)), "dense control floor authored")
	check(bool(world.diagnostic_fill_rect(Vector2i(187,148), Vector2i(1,28), 1)), "dense control left wall authored")
	check(bool(world.diagnostic_fill_rect(Vector2i(216,148), Vector2i(1,28), 1)), "dense control right wall authored")
	check(bool(world.diagnostic_fill_rect(Vector2i(188,148), Vector2i(28,28), 2)), "dense native Sand control authored")
	check(bool(world.simulation_tick()), "dense control completes an ordinary native tick")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(180,140), Vector2i(48,48), false)
	var angle: float = 0.37
	var rotation := Transform2D(angle, Vector2.ZERO)
	# The source junction (42,32) is deliberately inside one native cell. The
	# full proxy face crosses both its internal and exterior portions there.
	var source_center: Vector2 = source.center
	var junction_local := Vector2(42,32) - source_center
	var pose := Transform2D(angle, Vector2(200.25,160.5) - rotation * junction_local)
	var states: PackedFloat32Array = _states(source, pose, 100)
	var observation: Dictionary = _observe(world, states)
	if not check(observation.get("ok", false) and observation.get("complete", false),
		"rotated supported-Sand observation completes"):
		_finish()
		return
	check(str(observation.token) == str(source.token) and str(observation.body_generation) == str(GENERATION),
		"observation binds the active native aggregate token and generation")
	check(int(observation.sample_serial) == 100 and int(observation.tick) == int(world.get_tick_index()),
		"observation binds exact body sample and completed native tick")
	check(absf(float(observation.overlap_area) - 12.0) < 1e-8,
		"rotated compound overlap area equals its exact twelve native cells")
	check(int(observation.exterior_edge_units) == 16 and int(observation.internal_edge_units_refused) == 4,
		"integer source subtraction retains sixteen exterior and removes four directed internal edge units")
	var total_length: float = 0.0
	var partial_count: int = 0
	var contacts: Array = observation.contacts
	var inverse: Transform2D = (observation.source_transform as Transform2D).affine_inverse()
	for contact: Dictionary in contacts:
		total_length += float(contact.weight)
		var a: Vector2 = contact.a
		var b: Vector2 = contact.b
		check(a.distance_to(b) > 0.0 and absf(a.distance_to(b) - float(contact.weight)) < 5e-5,
			"copied contact endpoints retain their positive segment length")
		check((contact.point as Vector2).distance_to((a + b) * 0.5) < 5e-5,
			"copied point is the exterior segment midpoint")
		if int(contact.proxy) == 1 and int(contact.face) == 2:
			var source_a: Vector2 = inverse * a + source_center
			var source_b: Vector2 = inverse * b + source_center
			check(minf(source_a.x, source_b.x) >= 42.0 - 5e-5,
				"partial shared lower edge never includes the sibling-covered half")
			if contact.cell == Vector2i(200,160):
				partial_count += 1
				check(absf(float(contact.weight) - 0.75 / cos(angle)) < 5e-5,
					"junction cell retains only its analytically known exterior subsegment")
		check(not (int(contact.proxy) == 2 and int(contact.face) == 0),
			"fully internal upper edge of lower proxy supplies no contact")
	check(partial_count == 1, "rotated junction cell exercises one partial exterior contact")
	check(absf(total_length - 16.0) < 1e-7, "complete supported perimeter is neither dropped nor counted twice")
	case_reports.append({"id":"partial_shared_edge", "contacts":contacts.size(),
		"perimeter":total_length, "area":observation.overlap_area, "partial_contacts":partial_count})

	# Float32 publication permits tiny center quantization differences. Geometry
	# must reconstruct one rigid transform rather than create shifted seams.
	var perturbed: PackedFloat32Array = states.duplicate()
	perturbed[Coupling.INPUT_STRIDE + 1] += 0.0001
	perturbed[Coupling.INPUT_STRIDE + 2] -= 0.00005
	for offset: int in range(0, perturbed.size(), Coupling.INPUT_STRIDE):
		perturbed[offset + 10] = 101.0
	var coherent: Dictionary = _observe(world, perturbed)
	check(coherent.get("ok", false), "bounded float32 center disagreement remains admissible")
	check(JSON.stringify(coherent.get("contacts", [])) == JSON.stringify(observation.contacts),
		"one common transform keeps every exterior contact exact across proxy rounding")
	check(JSON.stringify(coherent.get("proxies", [])) == JSON.stringify(observation.proxies)
		and coherent.get("overlap_area", -1.0) == observation.overlap_area,
		"one common transform keeps exact area and penetration across proxy rounding")
	case_reports.append({"id":"float32_seam", "admitted":coherent.get("ok",false),
		"exact_contacts":JSON.stringify(coherent.get("contacts",[])) == JSON.stringify(observation.contacts)})

	var huge: PackedFloat32Array = _states(source, Transform2D(0.0, Vector2(1e30,1e30)), 102)
	var escaped: Dictionary = _observe(world, huge)
	check(not escaped.get("ok", true) and escaped.get("outcome") == "UnknownBoundary",
		"large finite body coordinates refuse before any out-of-range integer conversion")
	var negative: PackedFloat32Array = _states(source, Transform2D(0.0, Vector2(-1e30,-1e30)), 103)
	var escaped_negative: Dictionary = _observe(world, negative)
	check(not escaped_negative.get("ok", true) and escaped_negative.get("outcome") == "UnknownBoundary",
		"negative large finite body coordinates refuse safely")
	var missing: PackedFloat32Array = states.slice(0, Coupling.INPUT_STRIDE)
	var incomplete: Dictionary = _observe(world, missing)
	check(not incomplete.get("ok", true) and incomplete.get("outcome") == "IncompleteOrIncoherentCompound",
		"missing compound proxy refuses rather than measuring a filled hull")
	var mixed: PackedFloat32Array = states.duplicate()
	mixed[Coupling.INPUT_STRIDE + 10] += 1.0
	var mixed_sample: Dictionary = _observe(world, mixed)
	check(not mixed_sample.get("ok", true) and mixed_sample.get("outcome") == "IncompleteOrIncoherentCompound",
		"mixed body samples refuse")
	var nonfinite: PackedFloat32Array = states.duplicate()
	nonfinite[1] = INF
	var invalid: Dictionary = _observe(world, nonfinite)
	check(not invalid.get("ok", true), "nonfinite source proxy cannot become contact evidence")
	var foreign: PackedFloat32Array = states.duplicate()
	Coupling.append_input(foreign, 64, Vector2(240,180), 0.0, Vector2(2,2), Vector2.ZERO, 0.0, 4.0, 100)
	var foreign_body: Dictionary = _observe(world, foreign)
	check(not foreign_body.get("ok", true) and foreign_body.get("outcome") == "ForeignBody",
		"a foreign proxy refuses this single-owner observation contract")
	case_reports.append({"id":"refusals", "large_positive":escaped.get("outcome"),
		"large_negative":escaped_negative.get("outcome"), "missing":incomplete.get("outcome"),
		"mixed":mixed_sample.get("outcome"), "nonfinite":invalid.get("outcome"),
		"foreign":foreign_body.get("outcome")})
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(180,140), Vector2i(48,48), false)
	check(after.get("cells") == before.get("cells") and after.get("counts") == before.get("counts")
		and after.get("water_mass") == before.get("water_mass"),
		"all complete and refused observations preserve exact copied native materials")
	var retained: Dictionary = world.solid_detachment_command({"action":"inspect"})
	check(retained.get("members") == source.members and int(retained.get("aggregate_owned",-1)) == 12
		and int(retained.get("native_source_members",-1)) == 0,
		"contact observation preserves exact aggregate payload and exclusive ownership")
	world = null
	fixture.clear()
	_finish()

func _finish() -> void:
	var report: Dictionary = {"schema":"cybersand.sol281.contact-observation-test.v1",
		"checks":checks, "failures":failures, "platform":OS.get_name(), "workers":workers,
		"cases":case_reports, "scope":"native immutable geometry/ownership side channel; no live Rapier acceptance"}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	print("SOL281_CONTACT_OBSERVATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
