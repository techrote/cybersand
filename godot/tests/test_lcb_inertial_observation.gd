extends SceneTree

const Contract=preload("res://scripts/microscenario_contract.gd")
const KEYS: Array[String]=["gravity_y","impulse_x","impulse_y","loss","support","remainder",
	"updates","unit_moves","density_swaps","contacts","rests","velocity_retired","retired_x","retired_y",
	"external_x","external_y","maximum_read_reach","maximum_write_reach","external_speed"]
const UNSIGNED: Array[String]=["updates","unit_moves","density_swaps","contacts","rests","velocity_retired",
	"maximum_read_reach","maximum_write_reach"]
var assertions: int=0
var failures: int=0
var bridge: Variant
var profile: PackedInt32Array
var request: PackedInt32Array

func _initialize() -> void: _run.call_deferred()
func expect(value: bool, message: String) -> bool:
	assertions+=1
	if not value: failures+=1;push_error("INERTIAL_OBSERVATION: "+message)
	return value

func _run() -> void:
	bridge=ClassDB.instantiate(&"CyberDemoBridge")
	var current: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
	if not expect(current.has_method(&"get_inertial_ledger"),"source-matched copied native ledger required"):
		_finish();return
	var unavailable: Dictionary=current.get_inertial_ledger()
	expect(unavailable.ok and not unavailable.available and not unavailable.has("values")
		and not unavailable.has("extension_identity"),"healthy non-IN owner has no fabricated IN ledger")
	var definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"))
	var checked: Dictionary=Contract.validate(definition)
	if not expect(checked.get("ok",false),"protected transport definition validates"): _finish();return
	profile=checked.transport.packed
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/lcb/inertial-adapter-parameters.json"))
	request=PackedInt32Array(oracle.damping_cases[1].words)
	var worlds: Array=[]
	for workers: int in [1,4]:
		var world: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":workers}),"configured worker count constructs")
		world.set_simulation_window_enabled(false)
		var rectangles:=PackedInt32Array([0,0,256,1,1,0,95,256,1,1,0,0,1,96,1,255,0,1,96,1,
			24,20,4,3,24,152,20,4,3,24])
		if not expect(bridge.build_liquid_policy_world(world,rectangles,profile,PackedInt32Array([1,8,0,0]),
			PackedInt32Array(),request,3),"actual IN fixture constructs at radius3"):
			_finish();return
		worlds.append(world)
	var parallel: bool=false
	for tick: int in range(9):
		for world: Variant in worlds:
			if tick>0: expect(world.simulation_tick(),"actual native tick succeeds")
			var observation: Dictionary=world.get_inertial_ledger()
			_check_shape(world,observation,tick)
			_check_closure(world,observation)
		parallel=parallel or worlds[1].get_scheduler_parallel_phases_last_tick()>0
		expect(worlds[0].get_inertial_ledger().values==worlds[1].get_inertial_ledger().values,
			"complete cumulative ledger agrees for configured1/4 at tick%d"%tick)
		expect(worlds[0].get_physical_state_hash()==worlds[1].get_physical_state_hash(),"worker authority agrees")
	expect(parallel and int(worlds[0].get_inertial_ledger().values.updates)>0
		and int(worlds[0].get_inertial_ledger().values.unit_moves)>0,"real parallel dispatch and actual IN work observed")
	for world: Variant in worlds:
		var moving: Vector2i=_census(world).moving
		expect(moving.x>=0,"actual moving slot exists before material retirement")
		if moving.x>=0: world.paint_disc(moving.x,moving.y,0,1)
		var retired: Dictionary=world.get_inertial_ledger()
		expect(int(retired.values.velocity_retired)>0 and int(retired.values.retired_y)>0,
			"actual external material replacement books signed retirement and L1 speed")
		_check_closure(world,retired)
	var original: Variant=worlds[0]
	var saved: PackedByteArray=bridge.export_physical_state(original)
	var hash_before: String=original.get_physical_state_hash()
	var copied: Dictionary=original.get_inertial_ledger()
	var pristine: Dictionary=copied.duplicate(true)
	copied.values.gravity_y="987654321";copied.completed_tick="999"
	expect(original.get_inertial_ledger()==pristine and bridge.export_physical_state(original)==saved
		and original.get_physical_state_hash()==hash_before,"nested copied dictionaries do not mutate authority, clocks or serialized ledger")
	var restored: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(saved.decode_u32(4)==3 and bridge.import_physical_state(restored,saved),"actual ledger restores through CYPS3")
	expect(restored.get_inertial_ledger().values==pristine.values
		and restored.get_inertial_ledger().extension_identity==pristine.extension_identity,"restore preserves every cumulative ledger field and actual law")
	for tick: int in range(4):
		expect(original.simulation_tick() and restored.simulation_tick(),"restored native continuation ticks")
		expect(original.get_inertial_ledger().values==restored.get_inertial_ledger().values
			and original.get_physical_state_hash()==restored.get_physical_state_hash(),"continuation compares ledger independently of physical hash")
		_check_closure(restored,restored.get_inertial_ledger())
	_quarantine()
	print("INERTIAL_OBSERVATION_LEDGER: ",JSON.stringify(original.get_inertial_ledger()))
	_finish()

func _check_shape(world: Variant, observation: Dictionary, tick: int) -> void:
	var actual: Array=observation.get("values",{}).keys();actual.sort()
	var expected: Array=KEYS.duplicate();expected.sort()
	expect(observation.get("schema","")=="lcb-inertial-ledger-observation-v1" and observation.ok and observation.available
		and actual==expected,"complete versioned nineteen-field ledger")
	expect(observation.completed_tick is String and observation.completed_tick==str(tick)
		and observation.session_generation is String
		and observation.session_generation==str(world.get_liquid_policy_session_generation()),"exact decimal owner/completed-tick binding")
	var policy: Dictionary=world.get_liquid_solver_policy()
	expect(observation.policy_hash==policy.policy_hash and observation.extension_identity==policy.family_parameters.inertial_cellular_v1.extension_identity,
		"copied ledger binds actual native policy and effective IN parameters")
	for key: String in KEYS:
		var text: Variant=observation.values[key]
		expect(text is String and str(int(text))==text and (int(text)>=0 if key in UNSIGNED else true),
			"canonical exact signed/unsigned decimal "+key)

func _census(world: Variant) -> Dictionary:
	var sum_x: int=0;var sum_y: int=0;var speed: int=0;var moving:=Vector2i(-1,-1)
	# Explicit closed fixture bounds. This observation never walks sparse World
	# capacity or infers future dormancy from unchanged pixels.
	for y: int in range(96):
		for x: int in range(256):
			if world.material_at(x,y)!=24: continue
			var cell: Dictionary=world.inspect_inertial_cell(Vector2i(x,y))
			sum_x+=int(cell.vx);sum_y+=int(cell.vy);speed+=absi(int(cell.vx))+absi(int(cell.vy))
			if cell.vx!=0 or cell.vy!=0: moving=Vector2i(x,y)
	return {"x":sum_x,"y":sum_y,"speed":speed,"moving":moving}

func _check_closure(world: Variant, observation: Dictionary) -> void:
	var state: Dictionary=_census(world)
	var book: Dictionary=observation.values
	expect(state.x==int(book.impulse_x)+int(book.external_x)-int(book.retired_x)
		and state.y==int(book.gravity_y)+int(book.impulse_y)+int(book.external_y)-int(book.retired_y),"independent actual state closes signed components")
	expect(state.speed==int(book.gravity_y)-int(book.loss)+int(book.external_speed)-int(book.velocity_retired)
		and int(book.loss)>=0 and int(book.support)>=0 and int(book.remainder)>=0,"independent actual state closes L1 loss and retirement")

func _quarantine() -> void:
	var previous: Variant=ProjectSettings.get_setting("cybersand/native_active_core_capacity",null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1)
	var limited: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",previous)
	limited.set_simulation_window_enabled(false)
	expect(bridge.build_world(limited,PackedInt32Array([20,20,1,1,2,160,20,1,1,2])),"retained capacity-refusal apparatus constructs")
	expect(not limited.simulation_tick() and limited.has_failed(),"real native failed tick quarantines owner")
	var attempted: int=limited.get_attempted_tick_index()
	var refused: Dictionary=limited.get_inertial_ledger()
	expect(not refused.ok and not refused.available and not refused.has("values") and not refused.has("completed_tick")
		and not refused.error.is_empty() and limited.get_attempted_tick_index()==attempted,"quarantined copy refuses without exposing partial ledger or retrying tick")

func _finish() -> void:
	print("INERTIAL_OBSERVATION: %d assertions; %d failures"%[assertions,failures])
	quit(0 if failures==0 else 1)
