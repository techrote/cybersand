extends SceneTree

const Lab = preload("res://scripts/material_lab_experiment.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")

# Only the file-identity observation is controlled in these refusal tests.
# Installation, ticks and preserved-state readback still use a real native World.
class SourceDriftLab:
	extends "res://scripts/material_lab_experiment.gd"
	var drift_field: String = ""
	var identity_reads: int = 0
	var drift_at_read: int = 0

	func _current_source_identity() -> Dictionary:
		var identity: Dictionary = super._current_source_identity()
		identity_reads += 1
		if not drift_field.is_empty() and (drift_at_read == 0 or identity_reads >= drift_at_read):
			identity[drift_field] = "0".repeat(64)
		return identity

var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("MATERIAL_LAB_EXPERIMENT: " + message)

func _initialize() -> void:
	run.call_deferred()

func advance_to_end(experiment: RefCounted) -> bool:
	while not experiment.completed():
		if not experiment.step(32):
			expect(false, experiment.last_error)
			return false
	return true

func semantic(readback: Dictionary) -> Dictionary:
	return {"tick":readback.completed_tick,"content_hash":readback.native.content_hash,
		"water_integer":readback.native.water_integer,"counts":readback.material_counts}

func check_construction_provenance() -> void:
	var experiment := SourceDriftLab.new()
	var fixture: Dictionary = Lab.definition_for_pair(23,3,2,120)
	expect(experiment.start(fixture), "Provenance regression starts a real native experiment: " + experiment.last_error)
	if not experiment.active(): return
	expect(experiment.step(2), "Provenance regression advances actual native ticks")
	var retained: Dictionary = semantic(experiment.readback())
	var saved: String = experiment.case_json()
	var envelope: Dictionary = JSON.parse_string(saved)
	var captured: Dictionary = experiment.capture()
	expect(captured.ok and envelope.native_sha256 == captured.runtime_identity.native_sha256
		and envelope.host_scripts_sha256 == captured.runtime_identity.script_set_sha256
		and envelope.lab_script_sha256 == captured.runtime_identity.material_lab_experiment_sha256,
		"Saved case and capture bind the same construction-time native and source fingerprints")
	for field: String in ["native_sha256", "script_set_sha256", "material_lab_experiment_sha256"]:
		experiment.drift_field = field
		expect(experiment.case_json().is_empty() and experiment.last_error.contains("changed since"),
			"Case export refuses post-construction identity drift: " + field)
		var refused_capture: Dictionary = experiment.capture()
		expect(not refused_capture.ok and str(refused_capture.error).contains("changed since"),
			"Capture refuses to relabel an old native run with new source bytes: " + field)
		var refused_repeat: Dictionary = experiment.repeat_reference()
		expect(not refused_repeat.ok and str(refused_repeat.error).contains("changed since"),
			"Same-source comparison refuses identity drift: " + field)
		expect(semantic(experiment.readback()) == retained, "Identity refusal preserves actual native state: " + field)
		experiment.drift_field = ""
		expect(experiment.case_json() == saved and experiment.capture().ok,
			"Restored matching source retains the original deterministic case identity: " + field)
	# The first observation matches, then the post-install check observes a
	# changed native artifact. The speculative owner must not replace our run.
	experiment.drift_field = "native_sha256"
	experiment.drift_at_read = experiment.identity_reads + 2
	expect(not experiment.start(fixture) and experiment.last_error.contains("during native construction"),
		"Source drift during native construction refuses the new owner")
	expect(semantic(experiment.readback()) == retained, "Construction-time source drift preserves the prior native run")
	experiment.drift_field = ""
	experiment.drift_at_read = 0
	expect(experiment.case_json() == saved, "Refused replacement does not rewrite construction provenance")
	# An imported envelope can match at preflight and become stale before its
	# native owner is built; the expected fingerprint is carried across both.
	experiment.drift_field = "script_set_sha256"
	experiment.drift_at_read = experiment.identity_reads + 2
	expect(not experiment.start_case_json(saved) and experiment.last_error.contains("before reconstruction"),
		"Import keeps its expected source identity through native construction")
	expect(semantic(experiment.readback()) == retained, "Source drift after import preflight preserves the prior native run")
	experiment.drift_field = ""
	experiment.drift_at_read = 0
	expect(experiment.case_json() == saved, "Rejected import preserves the deterministic construction-bound case")
	experiment.close()

func check_incremental_reference() -> void:
	var experiment := SourceDriftLab.new()
	var fixture: Dictionary = Lab.definition_for_pair(23,3,29,48)
	expect(experiment.start(fixture,4,"cellular_yield_v1"),"Incremental comparison prepares an actual native owner")
	if not experiment.active(): return
	var configuration: Dictionary = experiment.configuration()
	expect(configuration.seed == 29 and configuration.duration_ticks == 48 and configuration.workers == 4
		and configuration.water_family_request == "cellular_yield_v1" and configuration.pair == {"first":23,"second":3},
		"Prepared configuration exposes the actual stored execution request and recognized pair")
	configuration.pair.first = 2
	expect(experiment.configuration().pair.first == 23,"Configuration readback cannot mutate the retained pair")
	expect(experiment.step(17),"Source owner advances to a partial comparison boundary")
	var retained: Dictionary = semantic(experiment.readback())
	var begun: Dictionary = experiment.begin_reference()
	expect(begun.ok and begun.status == "running" and begun.completed_tick == 0 and begun.target_tick == 17,
		"Beginning comparison only constructs the reference and does not replay the window")
	var progress: Dictionary = experiment.advance_reference(3)
	expect(progress.ok and progress.status == "running" and progress.completed_tick == 3,
		"One reference advance consumes only its explicit tick budget")
	expect(semantic(experiment.readback()) == retained,"Reference replay preserves the source owner exactly")
	expect(not experiment.advance_reference(65).ok and experiment.reference_progress().completed_tick == 3,
		"Invalid reference budget preserves the live comparison")
	experiment.cancel_reference()
	expect(not experiment.reference_running() and experiment.reference_progress().status == "cancelled"
		and semantic(experiment.readback()) == retained,"Cancelling the reference releases it without changing the source run")
	expect(experiment.begin_reference().ok,"Cancelled comparison can restart")
	while experiment.reference_running(): progress = experiment.advance_reference(4)
	expect(progress.ok and progress.equal and progress.status == "complete" and progress.completed_tick == 17,
		"Incremental replay compares native content and quantity at the exact partial source tick")
	expect(semantic(experiment.readback()) == retained,"Completed comparison leaves source state unchanged")
	expect(experiment.begin_reference().ok and experiment.advance_reference(2).ok,"A second partial replay starts")
	expect(experiment.step(1) and not experiment.reference_running()
		and experiment.reference_progress().status == "cancelled","Advancing the source invalidates its in-flight comparison")
	retained = semantic(experiment.readback())
	expect(experiment.begin_reference().ok and experiment.advance_reference(1).ok,"Source-bound replay starts before identity drift")
	experiment.drift_field = "native_sha256"
	var failed: Dictionary = experiment.advance_reference(64)
	expect(not failed.ok and str(failed.error).contains("changed since") and not experiment.reference_running(),
		"Source drift during yielded replay prevents a successful comparison receipt")
	expect(semantic(experiment.readback()) == retained,"Failed replay retains original native state")
	experiment.drift_field = ""
	var custom: Dictionary = fixture.duplicate(true)
	custom.presentation.title = "Custom imported fixture"
	expect(experiment.start(custom,4,"cellular_yield_v1") and experiment.configuration().pair.is_empty(),
		"A modified complete definition is never guessed to be the generated pair")
	expect(experiment.begin_reference().ok,"Zero-tick replay can be requested")
	var zero: Dictionary = experiment.advance_reference(1)
	expect(zero.ok and zero.equal and zero.completed_tick == 0,"Zero-tick comparison completes without advancing either native owner")
	experiment.close()

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false,"Current native extension is required; no mocked acceptance.")
		quit(1)
		return
	var baseline: Dictionary = {}
	for workers: int in [1,4]:
		var experiment := Lab.new()
		var fixture: Dictionary = Lab.definition_for_pair(23,3,2,120)
		expect(Contract.validate(fixture).ok,"Salt/Water generated definition must validate")
		if not experiment.start(fixture,workers):
			expect(false,experiment.last_error)
			continue
		var initial: Dictionary = experiment.readback()
		expect(initial.ok and initial.workers == workers and initial.completed_tick == 0,"Native test owner starts at exact requested worker boundary")
		expect(int(initial.material_counts.get("23",0)) == 384,"Native initial Salt dose is 384 cells")
		expect(initial.stored_probe.ok and initial.stored_probe.material == 3,"Stored native reservoir state is Water")
		var encoded: String = experiment.definition_json()
		var saved_case: String = experiment.case_json()
		var parsed: Dictionary = Contract.parse(encoded)
		expect(parsed.ok and parsed.hash == initial.definition_hash,"Test-case JSON preserves complete canonical identity")
		var image: Image = experiment.preview_image()
		expect(image != null and image.get_size() == Vector2i(148,200),"Copied native material preview has bounded expected geometry")
		var before_probe: Dictionary = experiment.inspect_cell(Vector2i(226,134))
		expect(before_probe.material == 23 and before_probe.has("state_a") and before_probe.has("state_b"),"Stored dose includes native registers")
		expect(not experiment.inspect_cell(Vector2i(-1,0)).ok,"Invalid stored probe rejected")
		expect(not experiment.step(65) and semantic(experiment.readback()) == semantic(initial),"Oversized step preserves native state")
		var bad: Dictionary = fixture.duplicate(true)
		bad.rectangles[4] = 10
		expect(not experiment.start(bad,workers),"Reserved material import rejected")
		expect(semantic(experiment.readback()) == semantic(initial),"Invalid import preserves prior native run")
		expect(not experiment.start(fixture,2),"Unsupported worker setting rejected")
		expect(not experiment.start(fixture,workers,"imaginary_solver"),"Unsupported family rejected")
		expect(not experiment.start_json(encoded.replace('"seed":2','"seed":2,"seed":3'),workers),"Duplicate JSON field rejected rather than last-write-wins")
		var malformed_case: String = saved_case.replace('"schema_version": 1','"schema_version": 1, "schema_version": 1')
		expect(not experiment.start_case_json(malformed_case),"Duplicate test-case wrapper field rejected")
		var changed_case: Dictionary = JSON.parse_string(saved_case)
		changed_case.workers = 4 if workers == 1 else 1
		expect(not experiment.start_case_json(JSON.stringify(changed_case)),"Saved-case digest rejects altered execution configuration")
		expect(semantic(experiment.readback()) == semantic(initial),"Invalid execution setting preserves prior native run")
		if not advance_to_end(experiment): continue
		var result: Dictionary = experiment.readback()
		expect(result.completed and result.completed_tick == 120,"Bounded native simulation reached exact window")
		expect(int(result.material_counts.get("24",0)) == 768 and int(result.material_counts.get("23",0)) == 0,"Authoritative native Salt/Water reaction yields 768 Brine cells and no Salt")
		expect(result.native.content_hash != initial.native.content_hash,"Native state actually changed")
		if baseline.is_empty(): baseline = semantic(result)
		else: expect(semantic(result) == baseline,"One- and four-worker content/quantity/count parity")
		var report: Dictionary = experiment.capture()
		expect(report.ok and report.completed_tick == 120,"Existing host emitted successful completed capture")
		expect(report.runtime_identity.native_sha256 != "unavailable", "Capture has native artifact fingerprint")
		expect(report.definition_hash == parsed.hash and report.definition == parsed.definition,"Capture retains exact reusable test definition")
		expect(report.readback.statistics.unavailable.has("per-cell sleeping status"),"Readback preserves unavailable per-cell sleep status")
		var repeated: Dictionary = experiment.repeat_reference()
		expect(repeated.ok and repeated.equal,"Clean same-source reconstruction reproduces content and quantity")
		expect(experiment.start_json(encoded,workers),"Exported test definition imports")
		expect(semantic(experiment.readback()) == semantic(initial),"Imported complete definition reconstructs exact initial state")
		expect(experiment.start_case_json(saved_case),"Saved case restores full workers/family/native-source contract")
		expect(experiment.readback().workers == workers and experiment.case_json() == saved_case,"Saved case has stable deterministic round-trip bytes")
		experiment.close()
		expect(not experiment.active() and not experiment.step(),"Closed experiment releases owner and cannot advance")
	for material: int in [3,2,21,36,131]:
		var fixture: Dictionary = Lab.definition_for_pair(material,1,9,24)
		expect(not fixture.is_empty() and Contract.validate(fixture).ok,"Generic supported material fixture validates: %d" % material)
	for material: int in [-1,10,132,256]:
		expect(Lab.definition_for_pair(material,3).is_empty(),"Unallocated/reserved candidate cannot enter production test World")
	expect(Lab.definition_for_pair(2,3,-1).is_empty(),"Invalid fixture seed rejected")
	expect(Lab.definition_for_pair(2,3,2,601).is_empty(),"Unbounded fixture duration rejected")
	var no_rule: Dictionary = Lab.resolver_diagnostic(2,3,0)
	expect(no_rule.ok and no_rule.outcome == "no_matching_rule","Sand/Water reports native no-rule result")
	var selected: Dictionary = Lab.resolver_diagnostic(23,3,0)
	expect(selected.ok and selected.outcome == "selected_reaction","Salt/Water zero roll selects native reaction")
	var rejected: Dictionary = Lab.resolver_diagnostic(22,9,255)
	expect(rejected.ok and rejected.outcome == "failed_probability_roll","Steam/Ice high roll distinguishes matched failed probability")
	var boundary_selected: Dictionary = Lab.resolver_diagnostic(22,9,32)
	var boundary_failed: Dictionary = Lab.resolver_diagnostic(22,9,33)
	expect(boundary_selected.selected and not boundary_failed.selected,"Native exact probability boundary uses roll <= threshold")
	expect(selected.probability_numerator == int(selected.probability_threshold)+1 and selected.probability_denominator == 256,"Probability keeps historical threshold-plus-one semantics")
	expect(selected.world_eligibility.begins_with("unobserved"),"Pair resolver never claims World eligibility")
	expect(not Lab.resolver_diagnostic(10,3,0).ok and not Lab.resolver_diagnostic(23,3,256).ok,"Invalid native resolver inputs rejected")
	var runtime := Lab.new()
	var water_fixture: Dictionary = Lab.definition_for_pair(3,1,2,32)
	expect(runtime.start(water_fixture,1,"cellular_yield_v1"),"Supported Water CY runtime test construction: " + runtime.last_error)
	if runtime.active():
		var applied: Dictionary = runtime.readback().applied_policy
		var water_found: bool = false
		for assignment: Dictionary in applied.assignments:
			if int(assignment.material) == 3:
				water_found = assignment.applied_family == "cellular_yield_v1" and assignment.requested_family == "cellular_yield_v1"
		expect(water_found and int(applied.session_generation) >= 0,"Native owner acknowledges actually installed Water CY family")
		expect(applied.admission == "qualified_candidate","Non-default test policy is labeled candidate")
		expect(advance_to_end(runtime),"Actual CY test World advances")
		var cy: Dictionary = runtime.readback()
		expect(cy.completed and cy.completed_tick == 32,"CY simulation completes bounded window")
		expect(runtime.repeat_reference().equal,"Applied runtime family survives exact test reproduction")
		var saved_cy: String = runtime.case_json()
		expect(runtime.start_case_json(saved_cy),"Saved case restores native CY policy, not default policy")
		var restored_cy: Dictionary = runtime.readback().applied_policy
		expect(restored_cy.policy_hash == applied.policy_hash,"Runtime family round trip has native policy-hash acknowledgment")
		runtime.close()
	check_construction_provenance()
	check_incremental_reference()
	print("MATERIAL_LAB_EXPERIMENT: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
