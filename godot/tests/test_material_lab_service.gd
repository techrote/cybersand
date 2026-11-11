extends SceneTree

# Real subprocess lifecycle fixtures. Native authoring and World acceptance
# remain in test_material_lab_ui.gd; these cases exercise failed process edges.
const Service = preload("res://scripts/material_lab_service.gd")
class FixtureService extends Service:
	var fixture_path: String = ""
	func source_tool() -> String:
		return fixture_path

const FIXTURE: String = """import argparse, json, pathlib, sys, time
p=argparse.ArgumentParser()
p.add_argument('--request', required=True)
p.add_argument('--response', required=True)
p.add_argument('--cancel-file', required=True)
a=p.parse_args()
mode=json.loads(pathlib.Path(a.request).read_text())['mode']
if mode=='cooperate':
    while not pathlib.Path(a.cancel_file).exists(): time.sleep(.01)
if mode=='ignore': time.sleep(30)
if mode=='large':
    pathlib.Path(a.response).write_text(' '*(8*1024*1024+1))
else:
    result={'ok':True,'state':'draft','runtime_active':False,'marker':mode}
    if mode=='active': result['runtime_active']=True
    if mode=='state_type': result['state']=['compiled_tested']
    if mode=='missing_receipt': result['state']='compiled_tested'
    if mode=='receipt_type': result['receipt']=[]
    if mode=='candidate_type': result['candidate']='invalid'
    if mode=='changes_type': result['changes']={'path':'wrong'}
    if mode=='change_entry': result['changes']=[{'path':'/density'}]
    if mode=='errors_type': result.update(ok=False,errors='error text is not an array')
    if mode=='error_entry': result.update(ok=False,errors=[7])
    pathlib.Path(a.response).write_text('[]' if mode=='invalid' else json.dumps(result))
sys.exit(7 if mode=='bad_exit' else 0)
"""
var checks: int = 0
var failures: int = 0
var result: Dictionary = {}
var fixture: FixtureService
var python: String = "python" if OS.get_name() == "Windows" else "python3"

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)

func wait_idle(service: Node, limit_msec: int = 6000) -> int:
	var deadline: int = Time.get_ticks_msec() + limit_msec
	var frames: int = 0
	while service.busy and Time.get_ticks_msec() < deadline:
		await process_frame
		frames += 1
	expect(not service.busy,"Subprocess finished within the test bound")
	return frames

func run() -> void:
	var directory: String = ProjectSettings.globalize_path("user://materials_lab/service-test-%d" % Time.get_ticks_usec())
	expect(DirAccess.make_dir_recursive_absolute(directory) == OK,"Process fixture directory created")
	var path: String = directory.path_join("process_fixture.py")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(FIXTURE)
	file.close()
	fixture = FixtureService.new()
	fixture.fixture_path = path
	root.add_child(fixture)
	fixture.completed.connect(func(value: Dictionary) -> void: result = value)
	for mode: String in ["normal","bad_exit","invalid","large","active","state_type","missing_receipt","receipt_type","candidate_type","changes_type","change_entry","errors_type","error_entry"]:
		result = {}
		expect(fixture.request({"mode":mode},python),"Launch real process: " + mode)
		var pid: int = fixture.process_id()
		expect(pid > 0 and fixture.busy,"Process has an explicit live owner")
		await wait_idle(fixture)
		expect(not OS.is_process_running(pid),"Finished process has been reaped")
		if mode == "normal":
			expect(result.get("ok",false) and result.get("marker") == mode,"Valid response comes from the actual child")
		else:
			expect(not result.get("ok",true),"Refuse malformed/oversized/nonzero-success response: " + mode)
			if mode == "bad_exit": expect(result.get("process_exit_code") == 7,"Nonzero exit is retained")
			if mode == "large": expect(str(result.get("errors",[])).contains("8 MiB"),"Response limit is actionable")
	result = {}
	expect(fixture.request({"mode":"cooperate"},python),"Launch cancellable real process")
	var cancelled_pid: int = fixture.process_id()
	await create_timer(0.10).timeout
	expect(fixture.busy,"Desktop continues while authoring waits")
	expect(not fixture.request({"mode":"normal"},python),"Only one authoring process is admitted")
	expect(fixture.cancel(),"Cancellation marker accepted")
	await wait_idle(fixture)
	expect(result.get("cancelled",false) and not result.get("ok",true),"Cancelled job never accepts even a late success response")
	expect(not OS.is_process_running(cancelled_pid),"Cooperative child exited")
	fixture.job_timeout_msec = 100
	result = {}
	var started: int = Time.get_ticks_msec()
	expect(fixture.request({"mode":"ignore"},python),"Launch unresponsive process fixture")
	var frames: int = await wait_idle(fixture)
	expect(frames >= 3,"Desktop frames continue during deadline and termination grace")
	expect(Time.get_ticks_msec() - started < 5000,"Unresponsive process cannot outlive the bounded deadline and grace")
	expect(result.get("cancelled",false) and str(result.get("errors",[])).contains("deadline"),"Deadline failure retires any tested status")
	expect(result.get("forced_termination",false) and fixture.process_id() == -1,"OS.kill acknowledged termination and released the process handle")
	fixture.job_timeout_msec = 300000
	expect(fixture.request({"mode":"normal"},python),"Service reusable after timeout")
	await wait_idle(fixture)
	expect(result.get("ok",false) and result.get("marker") == "normal","Late old responses cannot replace the next job")
	expect(fixture.request({"mode":"cooperate"},python),"Launch close-during-work fixture")
	var closed_pid: int = fixture.process_id()
	await create_timer(0.05).timeout
	started = Time.get_ticks_msec()
	fixture.free()
	expect(Time.get_ticks_msec() - started < 3000,"Closing has a fixed cleanup bound")
	expect(not OS.is_process_running(closed_pid),"Closing cancels and reaps the child")
	print("Materials Lab process lifecycle: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
