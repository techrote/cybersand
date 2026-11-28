extends SceneTree

# Real native ownership tests. Every equality is a complete CYPS comparison;
# diagnostic serialization is outside the timed hot handoff interval.
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
var failures: Array[String] = []
var assertions := 0
var sequence := 0
var timings_us: Array[int] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	assertions += 1
	if not ok:
		failures.append(detail)
		push_error("GEN006 native residency: " + detail)

func identity(fixture: Dictionary, area: String) -> Dictionary:
	return {"session_id":"native-residency-session", "area_id":area, "incarnation":"incarnation-" + area,
		"runtime_sha256":"a".repeat(64), "authored_source_sha256":fixture.checked.hash}

func status(fixture: Dictionary) -> Dictionary:
	return fixture.bridge.resident_status(fixture.world)

func receipt(fixture: Dictionary, area: String) -> Dictionary:
	for entry: Dictionary in status(fixture).get("entries", []):
		if entry.identity.area_id == area: return entry
	return {}

func switch(fixture: Dictionary, area: String) -> Dictionary:
	sequence += 1
	var before := status(fixture)
	var target := receipt(fixture, area)
	var started := Time.get_ticks_usec()
	var result: Dictionary = fixture.bridge.resident_activate(fixture.world, target, before.active,
		"native-switch-%d" % sequence)
	timings_us.append(Time.get_ticks_usec() - started)
	check(result.get("ok", false), "native hot activation %s: %s" % [area, result.get("error", "")])
	if not result.get("ok", false): return result
	var after := status(fixture)
	check(after.active.identity.area_id == area and result.target_receipt == after.active,
		"fresh active receipt matches actual native owner")
	for key: String in ["source_constructions", "native_restorations", "captures"]:
		check(before.counters[key] == after.counters[key], "hot handoff performs zero " + key)
	check(result.native_deserializations == 0 and result.source_constructions == 0 and
		result.checkpoint_captures == 0, "hot authority explicitly excludes restore/build/capture")
	return result

func expect_unchanged_refusal(fixture: Dictionary, target: Dictionary, source: Dictionary, label: String) -> void:
	var before: PackedByteArray = fixture.bridge.export_physical_state(fixture.world)
	sequence += 1
	var denied: Dictionary = fixture.bridge.resident_activate(fixture.world, target, source, "attack-%d" % sequence)
	check(not denied.get("ok", true), label + " is refused")
	check(fixture.bridge.export_physical_state(fixture.world) == before, label + " preserves active native state")

func run() -> void:
	if not ClassDB.class_has_method(&"CyberDemoBridge", &"resident_activate"):
		check(false, "source-matched native residency API is required")
		quit(1)
		return
	var owner: Dictionary = Fixture.create()
	check(not owner.has("error"), "native source fixture created")
	if owner.has("error"): quit(1); return
	owner.world.paint_disc(65, 60, 0, 0)
	for index: int in 17: check(owner.world.simulation_tick(), "real Fire/Water/Sand initial tick")
	var bounds := Rect2i(0, 0, 512, 512)
	var structural: Dictionary = owner.world.object_shard_attach(bounds)
	check(structural.get("ok", false), "real structural coordinator attaches before area admission")
	var before_refusal: PackedByteArray = owner.bridge.export_physical_state(owner.world)
	var denied: Dictionary = owner.bridge.resident_admit(owner.world, identity(owner, "A"))
	check(not denied.get("ok", true) and "structural body coordinator" in str(denied.get("error", "")),
		"an attached coordinator pins residency even with zero structural bodies")
	check(owner.bridge.capture_workbench_continuation(owner.world).is_empty() and
		"structural body coordinator" in str(owner.bridge.get_last_error()),
		"durable capture refuses retained structural ownership")
	check(owner.world.object_shard_status().get("attached", false) and
		owner.bridge.export_physical_state(owner.world) == before_refusal,
		"refused capture and parking preserve the actual World and its coordinator")
	check(owner.world.object_shard_retire(), "structural retirement releases the World")
	var admitted: Dictionary = owner.bridge.resident_admit(owner.world, identity(owner, "A"))
	var refused_attachment: Dictionary = owner.world.object_shard_attach(bounds)
	check(not refused_attachment.get("ok", true) and "Persistent Areas" in str(refused_attachment.get("detail", "")),
		"resident World refuses structural attachment before borrowing native authority")
	check(admitted.get("ok", false), "active A first native residency admission")
	if not admitted.get("ok", false): quit(1); return
	var expected := {"A":owner.bridge.export_physical_state(owner.world)}
	var original_handle: int = admitted.receipt.handle
	var recaptured: Dictionary = owner.bridge.resident_admit(owner.world, identity(owner, "A"))
	check(recaptured.ok and recaptured.receipt.handle == original_handle,
		"admission refresh preserves the instantiated World handle")
	var b: Dictionary = Fixture.create()
	b.world.paint_disc(101, 61, 1, 58)
	for index: int in 5: check(b.world.simulation_tick(), "B native initial progression")
	expected["B"] = b.bridge.export_physical_state(b.world)
	var b_admission: Dictionary = b.bridge.resident_admit(b.world, identity(b, "B"))
	var imported: Dictionary = owner.bridge.resident_import(owner.world, b.world, b_admission.receipt)
	check(imported.get("ok", false) and imported.get("candidate_consumed", false),
		"independent prepared native World imported by unique ownership")
	check(status(b).ok and status(b).entries.is_empty(), "spent preparation adapter has no resident allocation")
	var duplicate: Dictionary = owner.bridge.resident_import(owner.world, b.world, b_admission.receipt)
	check(not duplicate.ok, "private candidate cannot be imported twice")
	check(owner.bridge.export_physical_state(owner.world) == expected.A,
		"private import leaves active A byte identical")
	var c: Dictionary = Fixture.create()
	c.world.paint_disc(141, 61, 2, 9)
	expected["C"] = c.bridge.export_physical_state(c.world)
	var c_admission: Dictionary = c.bridge.resident_admit(c.world, identity(c, "C"))
	check(owner.bridge.resident_import(owner.world, c.world, c_admission.receipt).get("ok", false),
		"third independently prepared native area imported")
	var presentation: Dictionary = owner.world.take_render_snapshot(true)
	var retained_presentation: PackedByteArray = var_to_bytes(presentation)
	for area: String in ["B", "C", "A", "B", "A"]:
		if not switch(owner, area).get("ok", false): quit(1); return
		check(owner.bridge.export_physical_state(owner.world) == expected[area],
			"complete retained state survives required A/B/C travel: " + area)
	check(var_to_bytes(presentation) == retained_presentation,
		"already published immutable presentation survives native owner handoffs")
	check(owner.world.stored_material_at(65,60) == 0, "destructive Empty edit did not resurrect")
	var a_receipt := receipt(owner, "A")
	var b_receipt := receipt(owner, "B")
	for key: String in ["session_id", "area_id", "incarnation", "runtime_sha256", "authored_source_sha256"]:
		var wrong: Dictionary = b_receipt.duplicate(true)
		wrong.identity[key] = "b".repeat(64) if key.ends_with("sha256") else "wrong-identity"
		expect_unchanged_refusal(owner, wrong, a_receipt, "wrong " + key)
	for key: String in ["handle", "resident_generation", "mutation_generation", "completed_tick"]:
		var wrong: Dictionary = b_receipt.duplicate(true)
		wrong[key] = int(wrong[key]) + 1
		expect_unchanged_refusal(owner, wrong, a_receipt, "stale " + key)
	var wrong_physics: Dictionary = b_receipt.duplicate(true)
	wrong_physics.physics_profile_sha256 = "b".repeat(64)
	expect_unchanged_refusal(owner, wrong_physics, a_receipt, "wrong native physics profile")
	expect_unchanged_refusal(owner, a_receipt, a_receipt, "active World activated twice")
	check(not owner.bridge.resident_release(owner.world, a_receipt).get("ok", true),
		"eviction cannot release active World")
	check(not owner.bridge.resident_advance(owner.world, a_receipt, 1, 1000).get("ok", true),
		"private catch-up cannot mutate active gameplay")
	check(not owner.world.reset_demo_world(), "ordinary reset cannot silently discard bound resident authority")
	check(owner.bridge.export_physical_state(owner.world) == expected.A, "refused reset preserves active native state")
	owner.world.paint_disc(90,90,0,58)
	expected["A"] = owner.bridge.export_physical_state(owner.world)
	expect_unchanged_refusal(owner, b_receipt, a_receipt, "stale active mutation fence")
	check(switch(owner, "B").get("ok", false), "fresh mutation fence admits transition")
	a_receipt = receipt(owner, "A")
	var reference: Dictionary = Fixture.create()
	check(reference.bridge.import_physical_state(reference.world, expected.A), "independent continuation reference restored")
	var bad_slice: Dictionary = owner.bridge.resident_advance(owner.world, a_receipt, 33, 1000)
	check(not bad_slice.ok and receipt(owner, "A") == a_receipt, "invalid private slice retains World and fence")
	var progressed: Dictionary = owner.bridge.resident_advance(owner.world, a_receipt, 7, 100000)
	check(progressed.ok and int(progressed.completed_ticks) > 0, "real private hot World progresses")
	for index: int in int(progressed.get("completed_ticks", 0)):
		check(reference.world.simulation_tick(), "reference completed private tick")
	expected["A"] = reference.bridge.export_physical_state(reference.world)
	check(owner.bridge.export_physical_state(owner.world) == expected.B,
		"inactive catch-up leaves actively selected B byte identical")
	var captured: Dictionary = owner.bridge.resident_capture(owner.world, progressed.receipt)
	check(captured.ok and captured.capsule.bytes == expected.A,
		"inactive real native ticks equal uninterrupted reference including all CYPS state")
	check(not owner.bridge.resident_capture(owner.world, a_receipt).get("ok", true),
		"stale pre-catch-up capture cannot supersede newer state")
	check(switch(owner, "A").get("ok", false), "partly advanced hot World activates")
	check(owner.bridge.export_physical_state(owner.world) == expected.A,
		"hot activation does not double-run native catch-up")
	# Sustained zero-debt native handoff samples, with exact state after every
	# operation. UI/profile I/O timing is separately qualified by Main tests.
	var churn_bytes: int = status(owner).native_bytes
	for index: int in 180:
		var area := "B" if index % 2 == 0 else "A"
		check(switch(owner, area).get("ok", false), "bounded repeated hot churn")
		check(owner.bridge.export_physical_state(owner.world) == expected[area], "churn never reapplies ticks or edits")
	check(status(owner).native_bytes == churn_bytes and status(owner).entries.size() == 3,
		"180 handoffs do not grow resident allocations or native handle count")
	var before_release := status(owner)
	var stale_c := receipt(owner, "C")
	check(owner.bridge.resident_release(owner.world, stale_c).get("ok", false), "inactive release succeeds")
	check(status(owner).native_bytes < before_release.native_bytes and status(owner).entries.size() == 2,
		"release removes actual native allocations from ownership accounting")
	check(not owner.bridge.resident_release(owner.world, stale_c).get("ok", true), "retired handle cannot release twice")
	check(var_to_bytes(presentation) == retained_presentation, "old presentation remains immutable after eviction")
	var old_capacity: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity", 1024)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var failing: Dictionary = Fixture.create()
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", old_capacity)
	var failure_admission: Dictionary = failing.bridge.resident_admit(failing.world, identity(failing, "F"))
	var failure_import: Dictionary = owner.bridge.resident_import(owner.world, failing.world, failure_admission.receipt)
	check(failure_import.ok, "bounded private failure fixture admitted without disturbing active area")
	var failure_step: Dictionary = owner.bridge.resident_advance(owner.world, failure_import.receipt, 1, 100000)
	check(not failure_step.ok and receipt(owner, "F").failed, "failed private tick is quarantined and remains observable")
	check(owner.bridge.export_physical_state(owner.world) == expected.A, "private native failure preserves active World")
	check(not owner.bridge.resident_capture(owner.world, receipt(owner,"F")).get("ok", true),
		"partly failed native state cannot become a valid checkpoint")
	check(owner.bridge.resident_release(owner.world, receipt(owner,"F")).get("ok", false),
		"fenced quarantined private allocation can be released for durable recovery")
	# Ordinary cold constructor retains the old active World when RAM mode owns
	# it. Binding the new area happens only after successful constructor commit.
	var cold_token: int = Fixture.prepare(owner, owner.options)
	check(cold_token > 0 and owner.bridge.commit_liquid_world(owner.world, cold_token),
		"ordinary prepared cold replacement remains available")
	check(status(owner).active.is_empty() and not receipt(owner, "A").active,
		"cold replacement retained prior A instead of destroying it")
	var d_admission: Dictionary = owner.bridge.resident_admit(owner.world, identity(owner, "D"))
	check(d_admission.ok, "cold destination gets its own native identity")
	check(switch(owner, "A").get("ok", false), "old A remains available after cold construction")
	check(owner.bridge.export_physical_state(owner.world) == expected.A, "cold path preserved complete previous World")
	timings_us.sort()
	var summary := {"schema":1,"assertions":assertions,"failures":failures,"native_hot_samples":timings_us.size(),
		"native_hot_p50_us":timings_us[timings_us.size()/2],
		"native_hot_p95_us":timings_us[mini(timings_us.size()-1,int(ceil(timings_us.size()*0.95))-1)],
		"native_hot_worst_us":timings_us.back(),"residency":status(owner)}
	print("GEN006_NATIVE_RESIDENCY_RESULT " + JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
