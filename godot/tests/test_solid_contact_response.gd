extends SceneTree

# Registered narrow mechanical gate: identical zero-gravity Rapier bodies and
# initial velocity, a fixed native-material half-plane, twelve 1/60 s steps.
# Compare the old 3-unit aggregate bridge ceiling (generously offered entirely
# upward on EVERY step) with the new normal planner. Require >=25% reduction in
# added overlap-area-steps. This is an impulse/geometry mechanism control, not a
# substituted granular simulator, asynchronous trajectory match or feel pass.
const Response = preload("res://scripts/solid_contact_response.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const SIZE := Vector2(4.0, 2.0)
const MASS: float = 520.0
const INERTIA: float = MASS * (4.0 * 4.0 + 2.0 * 2.0) / 12.0
const INITIAL_SPEED: float = 12.0
const STEPS: int = 12
const REQUIRED_REDUCTION: float = 0.25

var checks: int = 0
var failures: Array[String] = []
var cases: Dictionary = {}
var mechanical: Dictionary = {}


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 CONTACT RESPONSE ", message)


func _init() -> void:
	call_deferred("_run")


func _observation(pose: Transform2D, contacts: Array) -> Dictionary:
	return {"schema":"cybersand.sol281.sand-contact.v1", "ok":true, "complete":true,
		"sample_serial":1, "token":"23:1", "body_generation":"7", "tick":19,
		"revision":"31", "source_transform":pose, "contacts":contacts}


func _bottom(cell_x: int, center_x: float = 20.5) -> Dictionary:
	# Body x=[center_x-2,center_x+2], y=[19.25,21.25]. These interior
	# bottom-face cells have exact area/depth .25 and one-cell face length.
	return {"proxy":1, "face":2, "cell":Vector2i(cell_x, 21),
		"point":Vector2(float(cell_x) + 0.5, 21.25), "normal":Vector2.DOWN,
		"a":Vector2(float(cell_x) + 1.0, 21.25), "b":Vector2(float(cell_x), 21.25),
		"depth":0.25, "area":0.25, "weight":1.0,
		"fixture_center_x":center_x}


func _plan(observation: Dictionary, velocity: Vector2 = Vector2(0.0, INITIAL_SPEED),
		omega: float = 0.0, current: Transform2D = Transform2D.IDENTITY,
		mass: float = MASS, inertia: float = INERTIA) -> Dictionary:
	var pose: Transform2D = observation.source_transform if current == Transform2D.IDENTITY else current
	return Response.plan(observation, pose, velocity, omega, mass, inertia,
		PackedVector2Array([Vector2.ZERO]), PackedVector2Array([SIZE]))


func _empty_refusal(result: Dictionary, message: String) -> void:
	check(not result.get("accepted", true) and result.get("impulses", [1]).is_empty(), message)


func _pure_cases() -> void:
	var pose := Transform2D(0.0, Vector2(20.5, 20.25))
	var input: Dictionary = _observation(pose, [_bottom(20)])
	var untouched: Dictionary = input.duplicate(true)
	var central: Dictionary = _plan(input)
	check(central.get("accepted", false), "mass-520 central loaded face is admitted")
	if central.get("accepted", false):
		check((central.velocity as Vector2).length() < 0.00001 and absf(float(central.omega)) < 0.00001,
			"effective-mass normal impulse arrests the mass-520 approach")
		check(absf((central.total_impulse as Vector2).y + MASS * INITIAL_SPEED) < 0.001,
			"load response has the required mass-times-velocity impulse, not a unit-mass cap")
		check(float(central.energy_after) <= float(central.energy_before) + float(central.energy_tolerance),
			"normal arrest does not create kinetic energy")
		check(int(central.group_count) == 1 and int(central.solver_sweeps) == 4,
			"registered parallel grouping and fixed four-sweep policy")
		cases["central"] = {"impulse_y":(central.total_impulse as Vector2).y,
			"energy_before":central.energy_before, "energy_after":central.energy_after}
	check(input == untouched, "planner retains all immutable observation bytes/values")
	_reclip_cases()
	var separating: Dictionary = _plan(input, Vector2(0, -4))
	check(separating.get("accepted", false) and separating.impulses.is_empty()
		and separating.velocity == Vector2(0, -4), "separating face gets no impulse")
	var tangent: Dictionary = _plan(input, Vector2(3, 0))
	check(tangent.get("accepted", false) and tangent.impulses.is_empty()
		and tangent.velocity == Vector2(3, 0), "candidate introduces no tangential friction")
	var empty: Dictionary = _plan(_observation(pose, []))
	check(empty.get("accepted", false) and empty.impulses.is_empty(),
		"complete empty contact observation has no mechanical action")
	var off_center: Dictionary = _plan(_observation(pose, [_bottom(21)]))
	check(off_center.get("accepted", false), "off-centre supported face admitted")
	if off_center.get("accepted", false):
		check(float(off_center.omega) < -0.1 and float(off_center.torque_impulse) < 0.0,
			"right-side upward reaction gives the correct negative angular response")
		var response_velocity: Vector2 = off_center.velocity
		check(absf(response_velocity.y + float(off_center.omega)) < 0.0001,
			"off-centre contact point is arrested with its true inertia lever")
		check(float(off_center.energy_after) < float(off_center.energy_before),
			"off-centre rotation is paid for by dissipated incoming kinetic energy")
		cases["off_center"] = {"velocity_y":response_velocity.y, "omega":off_center.omega,
			"torque_impulse":off_center.torque_impulse,
			"energy_before":off_center.energy_before, "energy_after":off_center.energy_after}
	var turning: Dictionary = _plan(_observation(pose, [_bottom(21)]), Vector2.ZERO, 4.0)
	check(turning.get("accepted", false) and turning.get("approaching_count", 0) > 0
		and float(turning.energy_after) < float(turning.energy_before),
		"a rotating approach uses contact-point velocity instead of only COM velocity")
	# Generic inertia deliberately differs from M*r^2. Independent point impulses
	# would leave an artificial separating spin after the first left/right pass.
	var symmetric_input: Dictionary = _observation(pose, [_bottom(19), _bottom(21)])
	var symmetric: Dictionary = _plan(symmetric_input, Vector2(0, 12), 0.0, pose, MASS, 3000.0)
	check(symmetric.get("accepted", false), "symmetric loaded face admitted at generic inertia")
	if symmetric.get("accepted", false):
		check(int(symmetric.contact_count) == 2 and int(symmetric.group_count) == 1,
			"parallel surface segments share one pressure-length-weighted resultant")
		check(absf(float(symmetric.omega)) <= 0.000001 and (symmetric.velocity as Vector2).length() <= 0.00001,
			"symmetric pressure has zero spurious torque or rebound")
		symmetric_input.contacts.reverse()
		var reordered: Dictionary = _plan(symmetric_input, Vector2(0, 12), 0.0, pose, MASS, 3000.0)
		check(reordered == symmetric, "canonical contact order makes input reordering deterministic")
		cases["symmetric"] = {"omega":symmetric.omega, "velocity_y":(symmetric.velocity as Vector2).y,
			"groups":symmetric.group_count}
	# The independent review found that a fixed COM resultant can erase a pure
	# angular approach: the right segment approaches while the left separates.
	# Falling plus spin must reclassify its segments after COM arrest as well.
	for spinning_case: Dictionary in [{"id":"grouped_pure_spin", "velocity":Vector2.ZERO},
		{"id":"grouped_falling_spin", "velocity":Vector2(0, 12)}]:
		var spin: Dictionary = _plan(symmetric_input, spinning_case.velocity, 4.0, pose, MASS, 3000.0)
		check(spin.get("accepted", false), str(spinning_case.id) + " observation is admitted")
		if spin.get("accepted", false):
			var spin_velocity: Vector2 = spin.velocity
			var maximum_approach: float = maxf(0.0, spin_velocity.y + absf(float(spin.omega)))
			check(int(spin.approaching_count) > 0, str(spinning_case.id) + " cannot disappear at the group COM")
			check(maximum_approach <= 0.0001, str(spinning_case.id) + " arrests both sampled segment approaches")
			check(float(spin.energy_after) < float(spin.energy_before), str(spinning_case.id) + " response is dissipative")
			cases[spinning_case.id] = {"velocity_y":spin_velocity.y, "omega":spin.omega,
				"maximum_sampled_approach":maximum_approach, "impulses":spin.impulses.size(),
				"energy_before":spin.energy_before, "energy_after":spin.energy_after}
	var malformed: Dictionary = input.duplicate(true)
	var late: Dictionary = _bottom(21)
	late.point = Vector2(NAN, 21.25)
	malformed.contacts.append(late)
	_empty_refusal(_plan(malformed), "malformed final contact refuses the entire planned impulse set")
	malformed = input.duplicate(true)
	malformed.contacts.append(_bottom(20))
	_empty_refusal(_plan(malformed), "duplicate proxy/face/cell cannot multiply support weight")
	var short_segment: Dictionary = _bottom(20)
	short_segment.a = Vector2(20.50001, 21.25)
	short_segment.b = Vector2(20.5, 21.25)
	short_segment.point = (short_segment.a + short_segment.b) * 0.5
	short_segment.weight = (short_segment.a as Vector2).distance_to(short_segment.b)
	_empty_refusal(_plan(_observation(pose, [short_segment, short_segment.duplicate(true)])),
		"exact duplicate subsegment shorter than geometry tolerance is still refused")
	for mutation: Dictionary in [{"normal":Vector2(0, 2)}, {"normal":Vector2.UP},
		{"weight":2.0}, {"weight":0.5}, {"area":0.9}, {"depth":1.0},
		{"face":1}, {"proxy":2}, {"point":Vector2(20.5, 21.0)}]:
		malformed = input.duplicate(true)
		for key: Variant in mutation:
			malformed.contacts[0][key] = mutation[key]
		_empty_refusal(_plan(malformed), "invalid contact witness refuses: " + str(mutation))
	malformed = input.duplicate(true)
	malformed.complete = false
	_empty_refusal(_plan(malformed), "incomplete observation is not a partial response")
	malformed = input.duplicate(true)
	malformed.sample_serial = 1000000
	_empty_refusal(_plan(malformed), "out-of-contract sample identity refuses")
	_empty_refusal(_plan(input, Vector2(0, 12), 0.0, pose, 0.0, INERTIA), "zero mass refuses")
	_empty_refusal(_plan(input, Vector2(0, 12), 0.0, pose, MASS, 0.0), "zero inertia refuses")
	_empty_refusal(_plan(input, Vector2(NAN, 0)), "nonfinite live velocity refuses")
	_empty_refusal(_plan(input, Vector2(0, 12), INF), "nonfinite live angular velocity refuses")
	_empty_refusal(_plan(input, Vector2(0, 12), 0.0,
		Transform2D(0.0, pose.origin + Vector2(0.251, 0))), "translation beyond quarter-cell corner drift refuses")
	_empty_refusal(_plan(input, Vector2(0, 12), 0.0,
		Transform2D(0.12, pose.origin)), "rotation is included in maximum vertex drift")
	_empty_refusal(_plan(input, Vector2(0, 12), 0.0,
		Transform2D(Vector2(2, 0), Vector2(0, 1), pose.origin)), "scaled transform cannot masquerade as rigid geometry")
	var shallow_pose := Transform2D(0.0, Vector2(20.5, 20.1))
	var shallow_contact: Dictionary = _bottom(20)
	shallow_contact.point = Vector2(20.5, 21.1)
	shallow_contact.a = Vector2(21.0, 21.1)
	shallow_contact.b = Vector2(20.0, 21.1)
	shallow_contact.area = 0.1
	shallow_contact.depth = 0.1
	var shallow: Dictionary = _observation(shallow_pose, [shallow_contact])
	_empty_refusal(_plan(shallow, Vector2(0, 12), 0.0,
		Transform2D(0.0, shallow_pose.origin - Vector2(0, 0.15))),
		"already-cleared contact refuses even inside the quarter-cell age envelope")
	var current := Transform2D(0.02, pose.origin)
	var small_turn: Dictionary = _plan(input, Vector2(0, 12), 0.0, current)
	check(small_turn.get("accepted", false), "small current-pose turn retains a verified contact segment")
	if small_turn.get("accepted", false):
		var impulse: Vector2 = small_turn.total_impulse
		check(impulse.normalized().dot(-current.y) > 0.99999,
			"current response normal rotates with the verified real face")
		check(float(small_turn.energy_after) <= float(small_turn.energy_before) + float(small_turn.energy_tolerance),
			"current-pose normal transport remains dissipative")
	# A diamond cuts an exact half-square triangle at x+y=43. The material
	# square's centre is ON the proxy edge; a centre-only mask is not this oracle.
	var diamond_pose := Transform2D(PI * 0.25, Vector2(20.5, 20.5))
	var diamond_contact := {"proxy":1, "face":1, "cell":Vector2i(21, 21),
		"point":Vector2(21.5, 21.5), "normal":Vector2(1, 1).normalized(),
		"a":Vector2(22, 21), "b":Vector2(21, 22),
		"depth":sqrt(0.5), "area":0.5, "weight":sqrt(2.0)}
	var diamond: Dictionary = Response.plan(_observation(diamond_pose, [diamond_contact]),
		diamond_pose, Vector2(5, 5), 0.0, 10.0, 10.0,
		PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2.ONE * sqrt(8.0)]))
	check(diamond.get("accepted", false), "exact rotated proxy/whole-square intersection is admitted")
	if diamond.get("accepted", false):
		check((diamond.velocity as Vector2).length() < 0.00001 and absf(float(diamond.omega)) < 0.00001,
			"rotated central face arrests its diagonal incoming velocity without spin")
	# A neighboring proxy covers HALF of this face/cell intersection. The
	# remaining exact exterior subset is valid; the midpoint of the full face
	# would incorrectly discard it (or admit covered seam support).
	var partial_centers := PackedVector2Array([Vector2.ZERO, Vector2(0.5, 1.5)])
	var partial_sizes := PackedVector2Array([SIZE, Vector2.ONE])
	var partial: Dictionary = _bottom(21)
	partial.a = Vector2(22, 21.25)
	partial.b = Vector2(21.5, 21.25)
	partial.point = Vector2(21.75, 21.25)
	partial.weight = 0.5
	var partial_plan: Dictionary = Response.plan(_observation(pose, [partial]), pose,
		Vector2(0, 12), 0.0, MASS, INERTIA, partial_centers, partial_sizes)
	check(partial_plan.get("accepted", false), "exact exterior subset of a partly covered face is admitted")
	_empty_refusal(Response.plan(_observation(pose, [_bottom(21)]), pose,
		Vector2(0, 12), 0.0, MASS, INERTIA, partial_centers, partial_sizes),
		"a contact spanning an internal sibling seam is refused in full")
	# A 45-degree cell can contain two exterior runs separated by a one-unit
	# sibling face. Same proxy/face/cell therefore is not alone a duplicate key.
	var split_pose := Transform2D(PI * 0.25, Vector2(21.5, 21.5) - Vector2.ONE.normalized() * 1.5)
	var split_centers := PackedVector2Array([Vector2.ZERO, Vector2(2, 0)])
	var split_sizes := PackedVector2Array([Vector2(3, 3), Vector2.ONE])
	var split_contacts: Array = []
	for interval: Vector2 in [Vector2(-sqrt(0.5), -0.5), Vector2(0.5, sqrt(0.5))]:
		var segment_a: Vector2 = split_pose * Vector2(1.5, interval.x)
		var segment_b: Vector2 = split_pose * Vector2(1.5, interval.y)
		split_contacts.append({"proxy":1, "face":1, "cell":Vector2i(21, 21),
			"a":segment_a, "b":segment_b, "point":(segment_a + segment_b) * 0.5,
			"normal":Vector2.ONE.normalized(), "weight":interval.y - interval.x,
			"depth":sqrt(0.5), "area":0.5})
	var split: Dictionary = Response.plan(_observation(split_pose, split_contacts), split_pose,
		Vector2(5, 5), 0.0, 10.0, 10.0, split_centers, split_sizes)
	check(split.get("accepted", false) and split.get("contact_count", 0) == 2,
		"separated exterior spans in one proxy/face/cell both retain valid ownership")
	if split.get("accepted", false):
		check(int(split.group_count) == 1 and absf(float(split.omega)) < 0.0001,
			"separated symmetric exterior spans use their true weighted resultant")
	split_contacts.append(split_contacts[0].duplicate(true))
	_empty_refusal(Response.plan(_observation(split_pose, split_contacts), split_pose,
		Vector2(5, 5), 0.0, 10.0, 10.0, split_centers, split_sizes),
		"duplicated exterior subsegment cannot multiply pressure weight")
	# Six non-overlapping proxies enclose TWO holes. Their rotated bounding box
	# contains these cells; neither hole is a valid contact with any chosen proxy.
	var hole_centers := PackedVector2Array([Vector2(0, -2), Vector2(0, 2), Vector2(-3, 0),
		Vector2(3, 0), Vector2(0, -1), Vector2(0, 0.5)])
	var hole_sizes := PackedVector2Array([Vector2(7, 1), Vector2(7, 1), Vector2(1, 3),
		Vector2(1, 3), Vector2(1, 1), Vector2(1, 2)])
	var hole_pose := Transform2D(PI * 0.5, Vector2(30.5, 30.5))
	var empty_holes: Dictionary = Response.plan(_observation(hole_pose, []), hole_pose,
		Vector2(0, 12), 0.0, 23.0, 100.0, hole_centers, hole_sizes)
	check(empty_holes.get("accepted", false) and empty_holes.impulses.is_empty(),
		"two-hole six-proxy union does not infer contact from its bounding rectangle")
	for hole: Vector2i in [Vector2i(30, 28), Vector2i(30, 32)]:
		var false_contact: Dictionary = _bottom(20)
		false_contact.face = 1
		false_contact.cell = hole
		false_contact.point = Vector2(hole) + Vector2(0.5, 0.5)
		false_contact.a = false_contact.point + Vector2(0.5, 0.0)
		false_contact.b = false_contact.point - Vector2(0.5, 0.0)
		false_contact.normal = Vector2.DOWN
		_empty_refusal(Response.plan(_observation(hole_pose, [false_contact]), hole_pose,
			Vector2(0, 12), 0.0, 23.0, 100.0, hole_centers, hole_sizes),
			"rotated interior hole is not filled by proxy validation: " + str(hole))


func _reclip_cases() -> void:
	# SOL364: the same source-witnessed segment survives inside this cell even
	# though its transported midpoint leaves. This is a matched geometry input,
	# separate from the existing frozen whole-body physical controls below.
	var source := Transform2D(0.0, Vector2(22.75, 20.25))
	var partial := {"proxy":1, "face":2, "cell":Vector2i(20, 21),
		"point":Vector2(20.875, 21.25), "normal":Vector2.DOWN,
		"a":Vector2(21.0, 21.25), "b":Vector2(20.75, 21.25),
		"depth":0.25, "area":0.0625, "weight":0.25}
	var current := Transform2D(0.0, source.origin + Vector2(0.1875, 0))
	var observation: Dictionary = _observation(source, [partial])
	var saved: Dictionary = observation.duplicate(true)
	var reclip: Dictionary = _plan(observation, Vector2(0, 12), 0.0, current)
	check(reclip.get("accepted", false), "retained exterior subsegment survives a lost old midpoint")
	if reclip.get("accepted", false):
		check(reclip.impulses.size() == 1 and int(reclip.source_contact_count) == 1 \
			and int(reclip.contact_count) == 1 and int(reclip.cleared_contact_count) == 0,
			"reclip applies exactly the one validated source contact")
		check((reclip.impulses[0].offset as Vector2).distance_to(Vector2(-1.96875, 1.0)) < 0.00001,
			"reclip lever uses the surviving segment midpoint, not the old midpoint or full face")
		check(float(reclip.energy_after) <= float(reclip.energy_before) + float(reclip.energy_tolerance),
			"reclipped impulse preserves the unchanged response-energy bound")
	check(observation == saved, "reclip does not mutate source witnesses")
	var clearing := Transform2D(0.0, source.origin + Vector2(0.25, 0))
	var complete_clear: Dictionary = _plan(observation, Vector2(0, 12), 0.0, clearing)
	check(not complete_clear.get("accepted", true) and complete_clear.get("outcome") == "ClearedContact",
		"an actually cleared source segment still refuses")
	var interior: Dictionary = _bottom(21, 22.75)
	var mixed: Dictionary = _plan(_observation(source, [partial, interior]), Vector2(0, 12), 0.0, clearing)
	check(mixed.get("accepted", false) and int(mixed.get("cleared_contact_count", -1)) == 1 \
		and int(mixed.get("contact_count", -1)) == 1 and int(mixed.get("source_contact_count", -1)) == 2,
		"one cleared record cannot suppress a different still-valid contact")
	var malformed: Dictionary = interior.duplicate(true)
	malformed.point = Vector2(NAN, 21.25)
	var later_invalid: Dictionary = _plan(_observation(source, [partial, malformed]), Vector2(0, 12), 0.0, clearing)
	check(not later_invalid.get("accepted", true) and later_invalid.get("outcome") == "InvalidContact" \
		and later_invalid.get("impulses", [1]).is_empty(),
		"cleared-record filtering cannot hide a later malformed witness")
	var duplicated_clear: Dictionary = _plan(_observation(source, [partial, partial.duplicate(true), interior]),
		Vector2(0, 12), 0.0, clearing)
	check(not duplicated_clear.get("accepted", true) and duplicated_clear.get("outcome") == "DuplicateContact" \
		and duplicated_clear.get("impulses", [1]).is_empty(),
		"duplicate source records refuse before cleared-contact filtering")
	var narrow_source := Transform2D(0.0, Vector2(20.5, 20.25))
	var narrow: Dictionary = _bottom(20)
	narrow.a = Vector2(21, 21.25)
	narrow.b = Vector2(20.9, 21.25)
	narrow.point = (narrow.a + narrow.b) * 0.5
	narrow.weight = (narrow.a as Vector2).distance_to(narrow.b)
	var full_face_still_present: Dictionary = _plan(_observation(narrow_source, [narrow]), Vector2(0, 12),
		0.0, Transform2D(0.0, narrow_source.origin + Vector2(0.25, 0)))
	check(not full_face_still_present.get("accepted", true) \
		and full_face_still_present.get("outcome") == "ClearedContact",
		"reclip cannot extend a cleared source subset to previously unobserved portions of the face")
	var stale: Dictionary = _plan(observation, Vector2(0, 12), 0.0,
		Transform2D(0.0, source.origin + Vector2(0.25001, 0)))
	check(not stale.get("accepted", true) and stale.get("outcome") == "PoseDrift",
		"reclip retains the quarter-cell pose-drift fence")
	cases["transported_original_segment"] = {"source_length":0.25, "remaining_length":0.0625,
		"current_area":0.015625, "current_depth":0.0625, "vertex_drift":0.1875,
		"outcome":reclip.get("outcome"), "mixed_clearance_outcome":mixed.get("outcome"),
		"position_work":0.0}


func _body(parent: Node, x: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = Vector2(x, 20.25)
	body.mass = MASS
	body.inertia = INERTIA
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector2.ZERO
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body


func _read(body: RigidBody2D) -> Dictionary:
	return {"transform":PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM),
		"velocity":PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
		"omega":float(PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))}


func _apply(body: RigidBody2D, planned: Dictionary) -> void:
	# Test main-thread owner, with no intervening physics step. Production invokes
	# the same PhysicsServer operation through CyberRapierPhysicsBridge.
	if not planned.get("accepted", false):
		return
	for item: Dictionary in planned.impulses:
		PhysicsServer2D.body_apply_impulse(body.get_rid(), item.impulse, item.offset)


func _metric_clip(polygon: PackedVector2Array, axis: int, edge: float,
		greater: bool) -> PackedVector2Array:
	# Independent observation of the real Rapier polygon, not planner feedback.
	var result := PackedVector2Array()
	if polygon.is_empty(): return result
	var a: Vector2 = polygon[polygon.size() - 1]
	var a_inside: bool = a[axis] >= edge if greater else a[axis] <= edge
	for b: Vector2 in polygon:
		var b_inside: bool = b[axis] >= edge if greater else b[axis] <= edge
		if a_inside != b_inside:
			result.append(a + (b - a) * ((edge - a[axis]) / (b[axis] - a[axis])))
		if b_inside: result.append(b)
		a = b
		a_inside = b_inside
	return result


func _region_overlap(pose: Transform2D, region: Rect2) -> float:
	var polygon := PackedVector2Array()
	for local: Vector2 in [Vector2(-2, -1), Vector2(2, -1), Vector2(2, 1), Vector2(-2, 1)]:
		polygon.append(pose * local - region.position)
	polygon = _metric_clip(polygon, 0, 0.0, true)
	polygon = _metric_clip(polygon, 0, region.size.x, false)
	polygon = _metric_clip(polygon, 1, 0.0, true)
	polygon = _metric_clip(polygon, 1, region.size.y, false)
	var twice_area: float = 0.0
	for i: int in range(polygon.size()):
		twice_area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(twice_area) * 0.5


func _actual_rapier() -> void:
	check(ClassDB.class_exists(&"RapierPhysicsServer2D"), "actual Rapier extension is present")
	if not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		return
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var baseline := _body(viewport, 20.5)
	var candidate := _body(viewport, 80.5)
	var off_baseline := _body(viewport, 140.5)
	var off_center := _body(viewport, 200.5)
	await process_frame
	var bridge = Bridge.new()
	var bodies: Array[RigidBody2D] = [baseline, candidate, off_baseline, off_center]
	var initialized: bool = bridge.initialize(viewport.world_2d.space, bodies,
		PackedVector2Array([SIZE, SIZE, SIZE, SIZE])) == OK
	check(initialized, "existing Rapier bridge owns actual matched mechanical controls")
	if not initialized:
		viewport.queue_free()
		return
	for body: RigidBody2D in bodies:
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
			Vector2(0, INITIAL_SPEED))
	bridge.refresh_all_states()
	var candidate_pose: Transform2D = _read(candidate).transform
	var candidate_plan: Dictionary = _plan(_observation(candidate_pose, [_bottom(80, 80.5)]),
		Vector2(0, INITIAL_SPEED), 0.0, candidate_pose)
	check(candidate_plan.get("accepted", false), "actual mass-520 Rapier body's exact pose is admitted")
	_apply(candidate, candidate_plan)
	var candidate_read: Dictionary = _read(candidate)
	if candidate_plan.get("accepted", false):
		check((candidate_read.velocity as Vector2).distance_to(candidate_plan.velocity) <= 0.0001,
			"actual Rapier central velocity agrees with the pure effective-mass plan")
		check(absf(float(candidate_read.omega) - float(candidate_plan.omega)) <= 0.0001,
			"actual Rapier central angular velocity agrees with the plan")
		var actual_energy: float = 0.5 * MASS * (candidate_read.velocity as Vector2).length_squared() \
			+ 0.5 * INERTIA * pow(float(candidate_read.omega), 2)
		check(absf(actual_energy - float(candidate_plan.energy_after)) <= 0.0001 * maxf(1.0, float(candidate_plan.energy_after)),
			"actual central Rapier energy agrees within registered 1e-4 relative tolerance")
	var off_pose: Transform2D = _read(off_center).transform
	var off_plan: Dictionary = _plan(_observation(off_pose, [_bottom(201, 200.5)]),
		Vector2(0, INITIAL_SPEED), 0.0, off_pose)
	check(off_plan.get("accepted", false), "actual off-centre Rapier contact is admitted")
	_apply(off_center, off_plan)
	var off_read: Dictionary = _read(off_center)
	if off_plan.get("accepted", false):
		check((off_read.velocity as Vector2).distance_to(off_plan.velocity) <= 0.0001,
			"actual off-centre linear response agrees with the predicted impulse")
		check(absf(float(off_read.omega) - float(off_plan.omega)) <= 0.0001 \
			and float(off_read.omega) < 0.0,
			"actual Rapier supplies the predicted off-centre torque and angular response")
		var actual_energy: float = 0.5 * MASS * (off_read.velocity as Vector2).length_squared() \
			+ 0.5 * INERTIA * pow(float(off_read.omega), 2)
		check(absf(actual_energy - float(off_plan.energy_after)) <= 0.0001 * maxf(1.0, float(off_plan.energy_after)),
			"actual off-centre Rapier energy agrees within registered 1e-4 relative tolerance")
	var initial_area: float = 4.0 * 0.25
	var baseline_added_area_steps: float = 0.0
	var candidate_added_area_steps: float = 0.0
	var baseline_max_depth: float = 0.25
	var candidate_max_depth: float = 0.25
	var off_baseline_added: float = 0.0
	var off_candidate_added: float = 0.0
	var off_baseline_region := Rect2(141, 21, 1, 32)
	var off_candidate_region := Rect2(201, 21, 1, 32)
	var off_initial_area: float = _region_overlap(off_pose, off_candidate_region)
	check(absf(off_initial_area - 0.25) < 0.00001, "off-centre support-column initial exact area is registered")
	var off_max_rotation: float = 0.0
	var trajectory: Array[Dictionary] = []
	for tick: int in range(STEPS):
		PhysicsServer2D.body_apply_central_impulse(baseline.get_rid(), Vector2(0, -3.0))
		PhysicsServer2D.body_apply_central_impulse(off_baseline.get_rid(), Vector2(0, -3.0))
		bridge.step()
		var a: Dictionary = _read(baseline)
		var b: Dictionary = _read(candidate)
		var a_pose: Transform2D = a.transform
		var b_pose: Transform2D = b.transform
		check(absf(a_pose.get_rotation()) < 0.00001 and absf(b_pose.get_rotation()) < 0.00001,
			"single-plane central control remains axis aligned at step " + str(tick + 1))
		# Exact rectangle/half-plane area in this registered zero-rotation case.
		var a_depth: float = maxf(0.0, a_pose.origin.y + 1.0 - 21.0)
		var b_depth: float = maxf(0.0, b_pose.origin.y + 1.0 - 21.0)
		var a_area: float = 4.0 * minf(2.0, a_depth)
		var b_area: float = 4.0 * minf(2.0, b_depth)
		baseline_added_area_steps += maxf(0.0, a_area - initial_area)
		candidate_added_area_steps += maxf(0.0, b_area - initial_area)
		baseline_max_depth = maxf(baseline_max_depth, a_depth)
		candidate_max_depth = maxf(candidate_max_depth, b_depth)
		var off_a_pose: Transform2D = _read(off_baseline).transform
		var off_b_pose: Transform2D = _read(off_center).transform
		var off_a_area: float = _region_overlap(off_a_pose, off_baseline_region)
		var off_b_area: float = _region_overlap(off_b_pose, off_candidate_region)
		off_baseline_added += maxf(0.0, off_a_area - off_initial_area)
		off_candidate_added += maxf(0.0, off_b_area - off_initial_area)
		off_max_rotation = maxf(off_max_rotation, absf(off_b_pose.get_rotation()))
		trajectory.append({"step":tick + 1, "baseline_depth":a_depth, "candidate_depth":b_depth,
			"baseline_area":a_area, "candidate_area":b_area,
			"off_center_baseline_area":off_a_area, "off_center_candidate_area":off_b_area,
			"off_center_candidate_rotation":off_b_pose.get_rotation()})
	var reduction: float = 1.0 - candidate_added_area_steps / baseline_added_area_steps \
		if baseline_added_area_steps > 0.0 else -1.0
	check(baseline_added_area_steps > 1.0, "fixed-load legacy ceiling has measurable added penetration")
	check(reduction >= REQUIRED_REDUCTION,
		"registered actual-Rapier added-overlap reduction is at least 25 percent")
	check(candidate_max_depth <= 0.2501,
		"candidate preserves its initial penetration without position correction or extra motion")
	var off_reduction: float = 1.0 - off_candidate_added / off_baseline_added \
		if off_baseline_added > 0.0 else -1.0
	check(off_baseline_added > 1.0, "off-centre legacy ceiling has measurable added overlap")
	check(off_reduction >= REQUIRED_REDUCTION, "registered actual-Rapier off-centre added-overlap reduction is at least 25 percent")
	check(off_max_rotation > 0.1, "off-centre physical comparison retains actual Rapier rotation")
	mechanical = {"fixture":"single-plane-zero-gravity-actual-Rapier", "steps":STEPS,
		"step_seconds":bridge.fixed_delta(), "mass":MASS, "inertia":INERTIA,
		"initial_velocity_y":INITIAL_SPEED, "initial_penetration":0.25,
		"baseline":"3-unit aggregate impulse ceiling, fully upward on every step",
		"baseline_added_overlap_area_steps":baseline_added_area_steps,
		"candidate_added_overlap_area_steps":candidate_added_area_steps,
		"baseline_max_penetration":baseline_max_depth, "candidate_max_penetration":candidate_max_depth,
		"reduction":reduction, "proposed_gate_minimum_reduction":REQUIRED_REDUCTION,
		"gate_passed":reduction >= REQUIRED_REDUCTION, "trajectory":trajectory,
		"off_center":{"fixture":"one-cell-wide-supported-column-zero-gravity-actual-Rapier",
			"initial_overlap_area":off_initial_area, "baseline_added_overlap_area_steps":off_baseline_added,
			"candidate_added_overlap_area_steps":off_candidate_added, "reduction":off_reduction,
			"maximum_rotation":off_max_rotation, "proposed_gate_minimum_reduction":REQUIRED_REDUCTION,
			"gate_passed":off_reduction >= REQUIRED_REDUCTION},
		"scope":"controlled impulse/overlap mechanism; populated native and asynchronous acceptance are separate"}
	bridge.shutdown()
	viewport.queue_free()
	await process_frame


func _run() -> void:
	_pure_cases()
	await _actual_rapier()
	var report := {"schema":"cybersand.sol281.contact-response.v1", "checks":checks,
		"failures":failures, "platform":OS.get_name(), "engine":Engine.get_version_info(),
		"planner_source_sha256":FileAccess.get_sha256("res://scripts/solid_contact_response.gd"),
		"test_source_sha256":FileAccess.get_sha256("res://tests/test_solid_contact_response.gd"),
		"cases":cases, "mechanical":mechanical,
		"scope":"pure complete-record planner plus actual Rapier impulse readback and registered mechanism control"}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			continue
		var file := FileAccess.open(argument, FileAccess.WRITE)
		if file == null:
			check(false, "requested response report can be opened")
		else:
			file.store_string(JSON.stringify(report, "\t"))
	print("SOL281_CONTACT_RESPONSE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
