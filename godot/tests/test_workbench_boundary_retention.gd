extends SceneTree

# Real native transport crosses the last visible row before the next owner is prepared.
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const SIZE := 256
var world:Variant
var bridge:Variant
var checked:Dictionary
var failures:Array[String]=[]

func check(ok:bool, what:String)->void:
	if not ok:
		failures.append(what)
		push_error(what)

func _initialize()->void:
	run.call_deferred()

func prepare(request:PackedInt32Array, epoch:int, retained:bool, convert:bool)->int:
	var options:Dictionary={"workbench_extent":Vector2i(SIZE,SIZE),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":epoch,"epoch":epoch,"states":PackedFloat64Array(),
		"geometry":PackedFloat64Array(),"bodies":[]},"region":PackedInt32Array([0,0,SIZE,SIZE]),
		"intent":"exploratory","definition_hash":checked.hash,"initial_bodies":PackedFloat32Array(),
		"workbench_retain_cells":retained,"workbench_convert_liquid_inventory":convert,
		"simulation_window_enabled":false}
	# Bracket free-falling Water so the first tick attempts a downward move.
	var cells:=PackedInt32Array([31,254,1,2,1,33,254,1,2,1,32,255,1,1,2,
		47,254,1,2,1,49,254,1,2,1,48,255,1,1,3,10,10,1,1,1])
	return bridge.prepare_liquid_world(world,cells,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),request,options)

func run()->void:
	world=ClassDB.instantiate(&"CyberNativeCellWorld")
	bridge=ClassDB.instantiate(&"CyberDemoBridge")
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var fm:PackedInt32Array=bridge.default_liquid_policy()
	var token:=prepare(fm,1,false,false)
	if token<=0 or not bridge.commit_liquid_world(world,token):
		check(false,"initial World: "+str(bridge.get_last_error())); quit(1); return
	var before:int=world.water_experiment_observation(Vector2i.ZERO,Vector2i(SIZE,SIZE)).water_visible
	check(world.simulation_tick(),"real native edge transport tick")
	var visible:int=world.water_experiment_observation(Vector2i.ZERO,Vector2i(SIZE,SIZE)).water_visible
	check(world.material_at(32,255)==0 and visible<before,"Sand and Water cross the canvas")
	if not failures.is_empty(): quit(1); return
	var pf:PackedInt32Array=fm.duplicate()
	pf[21]=3
	for step:int in 3:
		var actual=fm if step==0 else pf
		token=prepare(actual,step+2,true,step==1)
		if token<=0 or not bridge.commit_liquid_world(world,token):
			check(false,"edge transfer "+str(step)+": "+str(bridge.get_last_error())); quit(1); return
		var r:Dictionary=world.get_applied_liquid_construction_receipt().workbench_conversion
		check(r.preserved_halo_materials.get(2,0)==1 and r.preserved_halo_materials.get(3,0)>0 and
			r.preserved_halo_visible_water==before-visible,"real material and visible Water retained in halo")
		check(r.clipped_visible_water==0 and r.clipped_material_cells==0 and r.water_before==r.water_after,
			"native retained quantity closes")
		check(world.material_at(10,10)==1 and world.material_at(32,255)==0,"in-canvas marker retained without reseeding edge")
		print("BOUNDARY_TRANSFER ",step," ",r)
	print("WORKBENCH_BOUNDARY_RETENTION failures=",failures)
	quit(int(not failures.is_empty()))
