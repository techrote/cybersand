extends SceneTree

# WATER-CONTACT #362 focused regression for the CURRENT generic Rapier<->Water
# relocation law (`water_contact.impact.v1`). Observation only: it asserts what
# the unchanged coupling does, under all four admitted Water families. The full
# registered matrix is tools/water_contact/run_campaign.py, not this test.
#
# Locked Current facts (change them only with a reviewed coupling-law change):
# - a body overlap relocates a stored Water cell to Empty space with its complete
#   stored state (state_a/state_b, PF overfill/flow, IN vx/vy/ax/ay) unchanged;
# - the destination does not depend on the body's velocity;
# - an IN cell never holds vy < 0, so relocation upward is never upward momentum;
# - quantity is exact, no Water crosses the hard basin, worker 1/4 runs match.

const Apparatus = preload("res://tests/support/water_contact_impact.gd")
const MANIFEST: String = "res://tests/fixtures/water_contact/water_contact.impact.v1.json"
const SHORT_TICKS: int = 90

var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("WATER_CONTACT: " + message)
	return value


func run() -> void:
	if not expect(ClassDB.class_exists(&"CyberDemoBridge"), "native adapter available"):
		finish()
		return
	var manifest: Dictionary = Apparatus.load_manifest(MANIFEST)
	if not expect(manifest.get("ok", false), "registered manifest loads"):
		finish()
		return
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(Apparatus.runtime_identity(bridge).runtime_matches_provenance, "loaded runtime bytes match provenance")
	probes(bridge, manifest)
	refusal_and_replacement(bridge, manifest)
	await dynamic(bridge, manifest)
	finish()


func probes(bridge: Variant, manifest: Dictionary) -> void:
	for arm: Dictionary in manifest.arms:
		var signatures: Dictionary = {}
		for mode: Dictionary in manifest.kinematic_probe.modes:
			var probe: Dictionary = Apparatus.kinematic_probe(bridge, manifest, arm,
				Vector2(mode.body_velocity[0], mode.body_velocity[1]), str(mode.mode))
			var label: String = "%s %s" % [arm.id, mode.id]
			expect(bool(probe.get("ok", false)), label + " probe conserves and (overlap) relocates: " + str(probe.get("error", "")))
			if str(mode.mode) == "overlap":
				expect(int(probe.get("relocation_rows_up", 0)) == 3, label + " relocates three rows up (ceil(2.5) penetration)")
				expect(bool(probe.get("state_carried_unchanged", false)), label + " carries complete stored state unchanged")
				signatures[str(probe.get("destination")) + "|" + str(probe.get("state_after"))] = true
				if arm.family == "inertial_cellular_v1":
					var before: Dictionary = probe.inertial.before_tick
					var after: Dictionary = probe.inertial.after_tick
					expect(int(before.vy) > 0, label + " relocated IN cell keeps its downward vy")
					expect(int(after.vy) >= 0 and int(probe.next_tick_rows_up) <= 0,
						label + " next IN tick never moves the relocated cell upward")
			else:
				expect(int(probe.results.displaced) == 0 and int(probe.results.unresolved) == 1,
					label + " long sweep leaves the passed cell unresolved (no target outside the swept mask)")
		expect(signatures.size() == 1, arm.id + " relocation is independent of body velocity")


func refusal_and_replacement(bridge: Variant, manifest: Dictionary) -> void:
	var arms: Array = manifest.arms
	var in_arm: Dictionary = Apparatus.find_by_id(arms, "IN3")
	var pf_arm: Dictionary = Apparatus.find_by_id(arms, "PF3")
	var geo: Dictionary = Apparatus.geometry(manifest, {"depth":24})
	var built: Dictionary = Apparatus.build_world(bridge, manifest, in_arm, 1, Apparatus.rectangles(geo, true))
	if not expect(built.get("ok", false), "IN3 construction"):
		return
	var world: Variant = built.world
	var generation: int = int(world.get_liquid_policy_session_generation())
	# No hidden fallback: IN at radius two must refuse and keep the live session.
	var request: PackedInt32Array = Apparatus.request_for(bridge, "inertial_cellular_v1", "reference")
	var profile: Dictionary = Apparatus.Profiles.resolve(Apparatus.Profiles.preset(0))
	var refused: bool = not bridge.build_liquid_policy_world(world, Apparatus.rectangles(geo, true), profile.packed,
		PackedInt32Array(manifest.world.water_experiment_policy), PackedInt32Array(), request, 2)
	expect(refused, "IN radius two refuses")
	expect(int(world.get_liquid_policy_session_generation()) == generation, "refusal keeps the live session generation")
	expect(str(world.get_liquid_solver_policy().assignments[0].get("applied_family", "")) == "inertial_cellular_v1",
		"refusal keeps the applied IN policy (no fallback)")
	# Relocate under the live session, then replace it with PF on the same adapter.
	var size := Vector2(manifest.body.size[0], manifest.body.size[1])
	var states := PackedFloat32Array()
	var inside := Vector2(float(geo.left) + 48.0, float(geo.surface) + 3.0)
	CyberRigidBodyCoupling.append_input(states, 1, inside, 0.0, size, Vector2.ZERO, 0.0, 1.0, 1)
	world.prepare_rigid_body_coupling(states)
	var first: PackedFloat32Array = world.rigid_body_results()
	expect(first.size() == 9 and int(first[6]) > 0, "submerged pose relocates Water in the IN session")
	expect(int(world.rigid_body_id_at(int(inside.x), int(inside.y))) == 1, "IN session owns the body mask")
	var replaced: bool = bridge.build_liquid_policy_world(world, Apparatus.rectangles(geo, true), profile.packed,
		PackedInt32Array(manifest.world.water_experiment_policy), PackedInt32Array(),
		Apparatus.request_for(bridge, pf_arm.family, pf_arm.variant), 3)
	expect(replaced and int(world.get_liquid_policy_session_generation()) > generation, "PF session replaces IN")
	expect(int(world.rigid_body_id_at(int(inside.x), int(inside.y))) == 0, "replacement clears the old body mask")
	expect(int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024)).water_integer)
		== int(geo.width) * int(geo.depth) * 255, "replacement installs exactly the constructed quantity")
	# A body far above the Water: no stale sweep from the retired session's pose.
	var above := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(above, 1, Vector2(inside.x, float(geo.surface) - 40.0), 0.0, size,
		Vector2.ZERO, 0.0, 1.0, 2)
	world.prepare_rigid_body_coupling(above)
	var second: PackedFloat32Array = world.rigid_body_results()
	expect(second.size() == 9 and int(second[5]) == 0 and int(second[6]) == 0,
		"first coupling after replacement does not sweep from the retired pose")
	expect(world.simulation_tick() and not world.has_failed(), "replaced session ticks healthily")


func dynamic(bridge: Variant, manifest: Dictionary) -> void:
	var case: Dictionary = Apparatus.find_by_id(manifest.cases, "S-H-C").duplicate()
	case["ticks"] = SHORT_TICKS
	for arm_id: String in ["IN3", "PF3"]:
		var arm: Dictionary = Apparatus.find_by_id(manifest.arms, arm_id)
		var runs: Array = []
		for workers: int in [1, 4]:
			var record: Dictionary = await Apparatus.run_case(root, bridge, manifest, case, arm, workers)
			runs.append(record)
			var label: String = "%s S-H-C w%d" % [arm_id, workers]
			expect(bool(record.get("ok", false)), label + " has no invariant violation: " + str(record.get("violations", []).slice(0, 3)))
			var results: Dictionary = record.get("relocation", {}).get("results", {})
			expect(int(results.get("displaced", 0)) > 0, label + " body relocates Water")
			expect(int(record.relocation.histogram_total.total) == int(results.displaced), label + " histogram equals displaced")
			expect(int(results.get("carried_state_checks", 0)) > 0 and int(results.carried_state_mismatches) == 0,
				label + " carried-state multiset checked and unchanged")
			expect(int(record.final.global_water.quantity) == int(record.initial_water.global.quantity), label + " quantity exact")
			expect(int(record.get("stale_duplicate_probe", {}).get("stale_rejected", 0)) == 1
				and int(record.stale_duplicate_probe.duplicate_snapshot_applied) == 0, label + " duplicate/stale refused")
			if arm_id == "IN3":
				expect(int(record.inertial.negative_vy) == 0, label + " no negative IN vy")
		if runs.size() == 2:
			expect(runs[0].trace_sha256 == runs[1].trace_sha256
				and runs[0].final.physical_state_hash == runs[1].final.physical_state_hash,
				arm_id + " configured 1/4 worker traces and final state match")


func finish() -> void:
	print("WATER_CONTACT_IMPACT: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
