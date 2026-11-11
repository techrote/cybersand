extends SceneTree

const Lab = preload("res://scripts/material_lab_experiment.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
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
	print("MATERIAL_LAB_EXPERIMENT: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
