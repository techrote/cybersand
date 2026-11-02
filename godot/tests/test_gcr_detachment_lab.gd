extends SceneTree

# Fresh construction/admission/lifetime only. Never cut, release or step a body.
const Lab = preload("res://scripts/solid_detachment_lab.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL COMPOUND LAB ", message)

func ready_lab(lab: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while lab.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not lab.busy, "fresh lab setup completes")

func inspect_arm(lab: Node, expected: String) -> void:
	check(lab.session != null and lab.session.worker != null, "real worker constructed: " + expected)
	if lab.session == null or lab.session.worker == null:
		return
	check(lab.session.contact_candidate == expected, "selected session arm: " + expected)
	check(not lab.session.active and not is_instance_valid(lab.session.body) and lab.session.bridge == null,
		"no physical body/release/manual trajectory: " + expected)
	var snapshot: CyberSimulationSnapshot
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		snapshot = lab.session.worker.take_latest_snapshot(-1)
		if snapshot != null:
			break
		await process_frame
	check(snapshot != null, "real copied native snapshot: " + expected)
	if snapshot == null:
		return
	if expected == "legacy":
		check(snapshot.gcr_compound_diagnostics.is_empty(), "legacy has no GCR publication")
	else:
		check(snapshot.gcr_compound_diagnostics.get("admission_variant", "") == expected,
			"actual native admission identity: " + expected)
		check(snapshot.gcr_compound_results.is_empty(), "anchored arm has no physical response")
	check(expected in lab._title.text, "visible current arm")

func _run() -> void:
	var lab := Lab.new()
	lab.workers = 1
	root.add_child(lab)
	await ready_lab(lab)
	await inspect_arm(lab, "legacy")
	for expected: String in ["R2", "A1", "legacy"]:
		var old_session: RefCounted = lab.session
		var old_worker: RefCounted = old_session.worker
		var old_generation: int = old_session.generation
		await lab._cycle_candidate()
		check(old_session.worker == null and old_session.status == "closed" and old_session.generation > old_generation,
			"arm cycle retires old session and worker")
		check(lab.session != old_session and lab.session.worker != old_worker, "fresh owner per arm")
		await inspect_arm(lab, expected)
	var reset_session: RefCounted = lab.session
	await lab._open()
	check(reset_session.worker == null and lab.session != reset_session, "ordinary reset recreates same selected arm")
	await inspect_arm(lab, "legacy")
	lab.conservative_displacement = false
	lab.contact_candidate = "R2"
	await lab._open()
	check(lab.session.worker == null and "Refused" in lab._status.text,
		"baseline plus experimental arm refuses before creating native owner")
	lab.session.close()
	lab.queue_free()
	await process_frame
	print("GCR_DETACHMENT_LAB ", JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),
		"scope":"fresh lab arm identity and session retirement; zero body releases or physics trajectories"}))
	quit(0 if failures.is_empty() else 1)
