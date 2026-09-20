extends SceneTree

const FIXTURE := "res://tests/fixtures/wex001_water_body_baseline.json"

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("WEX-001: " + message)
	quit(1)

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not parsed is Array:
		_fail("fixture JSON is not an array")
		return
	var result: Dictionary = await CyberPhysicsCharacterisation.run(root,parsed)
	if not result.get("ok",false):
		_fail("characterisation execution failed")
		return
	var by_id: Dictionary = {}
	for report: Dictionary in result.results:
		var id: String = str(report.spec.get("id",""))
		if id.is_empty() or by_id.has(id):
			_fail("missing or duplicate case id")
			return
		by_id[id] = report
		if not report.has("wex001"):
			_fail(id + " did not emit WEX-001 evidence")
			return
		if not bool(report.wex001.mass_conserved):
			_fail(id + " changed exact finite-world Water mass")
			return

	for id: String in ["W0","W1","H0"]:
		if int(by_id[id].wex001.max_forbidden_water_mass) != 0:
			_fail(id + " entered the forbidden below-floor band")
			return

	if int(by_id.W0.wex001.peak_above_surface_mass) != 0 or int(by_id.W1.wex001.peak_above_surface_mass) != 0:
		_fail("no-body Water controls created above-surface mass")
		return
	if float(by_id.H0.wex001.max_body_floor_penetration) > 2.0:
		_fail("isolated hard-floor body control exceeded retained two-cell characterization tolerance")
		return
	if int(by_id.Dn.floor_contact_tick) != -1:
		_fail("registered deep short-horizon control reached the floor")
		return
	if int(by_id.Dn.wex001.max_forbidden_water_mass) != 0:
		_fail("deep short-horizon control crossed the floor before body contact")
		return

	var shallow_control_peak: int = int(by_id.W0.wex001.peak_above_surface_mass)
	if int(by_id.Sm.displaced) <= 0 or int(by_id.Sm.wex001.peak_above_surface_mass) <= shallow_control_peak:
		_fail("moderate shallow body did not reproduce useful Water displacement")
		return
	# This is deliberately a characterization lock on a known defect, not an
	# acceptance requirement. A semantic fix must intentionally reconcile #91.
	if int(by_id.Sm.wex001.max_forbidden_water_mass) <= 0:
		_fail("registered current floor-crossing defect no longer reproduces; reconcile the WEX-001 baseline")
		return

	for id: String in ["Sg","Sm","Sh","Dm","Dl","M-","M+","T","P1","P2","O0","O1"]:
		if int(by_id[id].displaced) <= 0:
			_fail(id + " produced no body-driven cell displacement")
			return

	for pair: Array in [["Sm","P1"],["Dm","P2"]]:
		var one: Dictionary = by_id[pair[0]]
		var four: Dictionary = by_id[pair[1]]
		if str(one.final.hash) != str(four.final.hash):
			_fail("%s/%s worker-count final state hashes differ" % pair)
			return
		if int(one.displaced) != int(four.displaced) or int(one.unresolved) != int(four.unresolved):
			_fail("%s/%s worker-count coupling totals differ" % pair)
			return
		if int(one.wex001.max_forbidden_water_mass) != int(four.wex001.max_forbidden_water_mass):
			_fail("%s/%s worker-count forbidden-boundary totals differ" % pair)
			return

	if str(by_id.O0.final.hash) != str(by_id.O1.final.hash):
		_fail("telemetry on/off changed final cellular state")
		return
	if int(by_id.O0.displaced) != int(by_id.O1.displaced) or int(by_id.O0.unresolved) != int(by_id.O1.unresolved):
		_fail("telemetry on/off changed coupling totals")
		return
	if absf(float(by_id.O0.final_depth)-float(by_id.O1.final_depth)) > 0.000001:
		_fail("telemetry on/off changed body depth")
		return

	var summary: Dictionary = {
		"schema":"wex001-summary-v1",
		"cases":by_id.size(),
		"shallow_control_peak_above":shallow_control_peak,
		"moderate_displaced":int(by_id.Sm.displaced),
		"moderate_peak_above":int(by_id.Sm.wex001.peak_above_surface_mass),
		"moderate_forbidden_peak":int(by_id.Sm.wex001.max_forbidden_water_mass),
		"moderate_first_forbidden_tick":int(by_id.Sm.wex001.first_forbidden_tick),
		"moderate_body_floor_penetration":float(by_id.Sm.wex001.max_body_floor_penetration),
		"hard_control_body_floor_penetration":float(by_id.H0.wex001.max_body_floor_penetration),
		"deep_short_floor_contact":int(by_id.Dn.floor_contact_tick),
		"mirror_left_peak_above":int(by_id["M-"].wex001.peak_above_surface_mass),
		"mirror_right_peak_above":int(by_id["M+"].wex001.peak_above_surface_mass),
		"translated_peak_above":int(by_id.T.wex001.peak_above_surface_mass),
		"worker_shallow_hash":str(by_id.Sm.final.hash),
		"worker_deep_hash":str(by_id.Dm.final.hash),
		"observer_hash":str(by_id.O0.final.hash),
	}
	print("WEX001_SUMMARY ",JSON.stringify(summary))
	quit(0)
