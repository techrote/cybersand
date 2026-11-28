extends SceneTree

# Hosted 12-actor empty/dense guard benchmark, with the same shared limits as
# Main. Reports p95/p99; not a substitute for physical Windows GPU acceptance.
const Oracle = preload("res://scripts/workbench_presentation_coherence.gd")
const SCAN_LIMIT: int = 24000
const USEC_LIMIT: int = 2000
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PR593_GUARD_BUDGET: "+label)

func percentile(samples: Array[int], p: float) -> int:
	var a: Array[int] = samples.duplicate()
	if a.is_empty(): return -1
	a.sort()
	return a[clampi(ceili((a.size()-1)*p),0,a.size()-1)]

func _run() -> void:
	var empty: Image = Image.create_empty(512,512,false,Image.FORMAT_RG8)
	empty.fill(Color(0,0,0,1))
	var dense: Image = Image.create_empty(512,512,false,Image.FORMAT_RG8)
	dense.fill(Color(0,0,0,1))
	for y: int in range(165,360,3):
		for x: int in range(165,360,3):
			dense.set_pixel(x,y,Color(58.0/255.0,0,0,1))
	var hull: Array = [
		{"center":Vector2.ZERO,"size":Vector2(9,6)},
		{"center":Vector2(-11,0),"size":Vector2(5,2)},
		{"center":Vector2(11,0),"size":Vector2(5,2)}]
	var max_scanned: int=0
	var admitted: int=0
	var vetoed: int=0
	var timing: Dictionary={}
	for mode: String in ["empty","dense"]:
		var world: Image=empty if mode=="empty" else dense
		var measurements: Array[int]=[]
		for frame: int in range(32):
			var started: int=Time.get_ticks_usec()
			var deadline: int=started+USEC_LIMIT
			var scanned: int=0
			for actor: int in range(12):
				var remaining: int=SCAN_LIMIT-scanned
				if remaining<=0 or Time.get_ticks_usec()>=deadline:
					vetoed+=1
					continue
				var position:=Vector2(190+actor*7,205+actor*4)
				var decision: Dictionary=Oracle.assess(
					Transform2D(0.0,position),
					Transform2D(0.12,position+Vector2(3,2)),
					hull,world,{},false,false,mini(remaining,Oracle.MAX_SCAN_CELLS),deadline)
				scanned+=int(decision.scanned)
				if decision.safe: admitted+=1
				else: vetoed+=1
				require(scanned<=SCAN_LIMIT,"shared frame scan bound holds")
			max_scanned=maxi(max_scanned,scanned)
			measurements.append(Time.get_ticks_usec()-started)
		timing[mode]={"p50_usec":percentile(measurements,0.5),
			"p95_usec":percentile(measurements,0.95),
			"p99_usec":percentile(measurements,0.99)}
	var expired: Dictionary=Oracle.assess(
		Transform2D(0.0,Vector2(230,230)),
		Transform2D(0.2,Vector2(232,232)),hull,empty,
		{},false,false,Oracle.MAX_SCAN_CELLS,Time.get_ticks_usec()-1)
	require(not expired.safe and expired.reason=="time_budget",
		"expired shared clock never authorizes an unchecked live transform")
	require(max_scanned<=SCAN_LIMIT,"12-body cohort stays inside cell work cap")
	require(int(timing["empty"].p95_usec)>=0 and int(timing["dense"].p95_usec)>=0,
		"per-mode p95 recorded")
	print("PR593_GUARD_DENSE_BUDGET_RESULT ",JSON.stringify({
		"checks":checks,"failures":failures,"platform":OS.get_name(),
		"actors":12,"frames_per_mode":32,
		"shared_scan_limit":SCAN_LIMIT,"shared_usec_limit":USEC_LIMIT,
		"maximum_cells_examined":max_scanned,"admissions":admitted,
		"conservative_vetoes":vetoed,"hosted_timing":timing,
		"note":"separate physical Windows GPU p95/p99 acceptance remains outstanding"}))
	quit(int(not failures.is_empty()))
