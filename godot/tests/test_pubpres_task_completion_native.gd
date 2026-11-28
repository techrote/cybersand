extends SceneTree

const SETTING := "cybersand/pubpres_task_completion_barrier"
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM := "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var saved: Variant

func _initialize() -> void:
	run.call_deferred()

func require(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("PUBPRES_TASK_COMPLETION_NATIVE: "+label)
	return value

func create(enabled: bool) -> Variant:
	ProjectSettings.set_setting(SETTING,enabled)
	return ClassDB.instantiate(&"CyberNativeCellWorld")

func mode(world: Variant, enabled: bool, label: String) -> bool:
	var state: Dictionary = world.get_wave_flow_status()
	var completion: Dictionary = state.get("task_completion",{})
	return require(state.get("healthy",false) and completion.get("schema") == "PUBPRES-TASK-COMPLETION-V1" \
		and completion.get("mode") == ("actual_tasks" if enabled else "all_workers"),label)

func configure(world: Variant) -> bool:
	if not require(world.diagnostic_reset({"extent":Vector2i(256,256),"workers":4,
		"wave_flow":true,"wave_substeps":2}),"actual native diagnostic World rebuild"): return false
	world.set_simulation_window_enabled(false)
	for rectangle: Array in [[0,0,256,1,1],[0,255,256,1,1],[0,0,1,256,1],
			[255,0,1,256,1],[1,160,200,95,3]]:
		if not require(world.diagnostic_fill_rect(Vector2i(rectangle[0],rectangle[1]),
			Vector2i(rectangle[2],rectangle[3]),int(rectangle[4])),"actual native basin fill"): return false
	return true

func prepared_replacement(world: Variant, enabled: bool) -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var checked: Dictionary = Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var options := {"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]},
		"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":PackedFloat32Array(),"workbench_wave_flow":true,"workbench_worker_threads":4}
	var cells := PackedInt32Array([0,240,256,16,58,0,0,8,240,58,248,0,8,240,58,8,140,240,100,3])
	var token: int = bridge.prepare_liquid_world(world,cells,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),bridge.default_liquid_policy(),options)
	if not require(token > 0 and bridge.commit_liquid_world(world,token),
		"actual prepared Workbench owner replaces World: "+str(bridge.get_last_error())): return
	mode(world,enabled,"prepared owner inherits immutable actual pool policy")
	var before: Dictionary = world.get_wave_flow_status().task_completion
	require(before.completed_dispatches == 0 and before.completed_tasks == 0,
		"new World counters never borrow predecessor completion credit")
	for ignored: int in range(8): require(world.simulation_tick(),"prepared native owner really progresses")
	var after: Dictionary = world.get_wave_flow_status().task_completion
	require(after.completed_dispatches > 0 and after.completed_tasks > 0,
		"prepared World actually exercises the selected pool")
	observations.append({"stage":"prepared_owner","enabled":enabled,"before":before,"after":after,
		"physical_hash":world.get_physical_state_hash(),"completed_tick":world.get_wave_flow_status().completed_tick})

func run() -> void:
	saved = ProjectSettings.get_setting(SETTING) if ProjectSettings.has_setting(SETTING) else null
	if not require(ClassDB.class_exists(&"CyberNativeCellWorld"),"actual GDExtension runtime loaded"):
		finish(); return
	ProjectSettings.set_setting(SETTING,null)
	var default_world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	mode(default_world,false,"absent selector keeps original all-worker policy")
	var control: Variant = create(false)
	var candidate: Variant = create(true)
	ProjectSettings.set_setting(SETTING,false)
	mode(candidate,true,"existing native owner captures selection exactly once")
	mode(control,false,"existing control does not follow another owner's selection")
	if not configure(control) or not configure(candidate): finish(); return
	mode(control,false,"control rebuild keeps original policy")
	mode(candidate,true,"candidate rebuild retains actual-task policy")
	var first: Dictionary = candidate.get_wave_flow_status().task_completion
	for tick: int in range(32):
		require(control.simulation_tick() and candidate.simulation_tick(),"both actual native Worlds complete required work")
		require(control.get_physical_state_hash() == candidate.get_physical_state_hash(),
			"same actual complete native physics at tick "+str(tick))
		require(control.take_render_snapshot(true).cells == candidate.take_render_snapshot(true).cells,
			"same real native material plane at tick "+str(tick))
	var last: Dictionary = candidate.get_wave_flow_status().task_completion
	require(first.completed_dispatches == 0 and first.completed_tasks == 0,
		"retained initial readback remains immutable")
	require(last.completed_dispatches > 0 and last.completed_tasks >= last.completed_dispatches,
		"actual selected pool executes nonzero task batches")
	observations.append({"stage":"matched_native","control":control.get_wave_flow_status().task_completion,
		"candidate":last.duplicate(true),"physical_hash":candidate.get_physical_state_hash(),
		"control_completed_tick":control.get_wave_flow_status().completed_tick,
		"candidate_completed_tick":candidate.get_wave_flow_status().completed_tick})
	last.completed_tasks = -1
	require(candidate.get_wave_flow_status().task_completion.completed_tasks > 0,
		"readback cannot modify native completion authority")
	prepared_replacement(control,false)
	prepared_replacement(candidate,true)
	for value: Variant in [1,"true",1.0]:
		ProjectSettings.set_setting(SETTING,value)
		var refused: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		require(refused.has_failed() and str(refused.get_last_tick_error()).contains("must be boolean"),
			"nonboolean selector refuses native owner initialization")
		require(not refused.simulation_tick(),"refused owner cannot fabricate a completed turn")
		require(not refused.get_wave_flow_status().get("healthy",true),"refused diagnostic is explicitly unhealthy")
		observations.append({"stage":"refused_selector","type":typeof(value),"error":refused.get_last_tick_error()})
	finish()

func finish() -> void:
	ProjectSettings.set_setting(SETTING,saved)
	var native_path := "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" \
		if OS.get_name() == "Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	var report := {"schema":"pubpres-task-completion-native-v1","checks":checks,"failures":failures,
		"observations":observations,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine":Engine.get_version_info(),"test_sha256":FileAccess.get_sha256(get_script().resource_path),
		"process_id":OS.get_process_id(),"platform":OS.get_name(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"native_resource":native_path,"native_sha256":FileAccess.get_sha256(native_path),
		"native_descriptor_sha256":FileAccess.get_sha256("res://addons/cybersand_native/cybersand_native.gdextension")}
	var output := OS.get_environment("CYBERSAND_TASK_COMPLETION_NATIVE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")+"\n")
		else: require(false,"native task-completion receipt opens")
	print("PUBPRES_TASK_COMPLETION_NATIVE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
