extends SceneTree

const Contract=preload("res://scripts/microscenario_contract.gd")
const DAM="res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var failures:Array[String]=[]
var checked:Dictionary
var bridge:Variant
var world:Variant

func check(value:bool, detail:String)->void:
	if not value:
		failures.append(detail)
		push_error(detail)

func _initialize()->void:
	call_deferred("run")

func candidate(rects:PackedInt32Array, origin:Vector2, angle:float, shapes:Array, session:int)->int:
	var states:=PackedFloat64Array()
	var geometry:=PackedFloat64Array()
	for index:int in shapes.size():
		var r:Vector4=shapes[index]
		var point:=origin+Vector2(r.x,r.y).rotated(angle)
		states.append_array(PackedFloat64Array([index+1,point.x,point.y,angle,r.z,r.w,0,0,0,1,1,20,origin.x,origin.y,0.4,1./60,session]))
		geometry.append_array(PackedFloat64Array([r.x,r.y,r.z,r.w]))
	var owner:Dictionary={"id":1,"instance_id":42,"generation":session,"first_proxy":1,
		"count":shapes.size(),"budget":20,"gravity":92,"external_drive":false}
	var sample:Dictionary={"session":session,"epoch":session,"states":states,"geometry":geometry,"bodies":[owner]}
	return bridge.prepare_liquid_world(world,rects,checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(),bridge.default_liquid_policy(),{"workbench_extent":Vector2i(256,256),
		"workbench_response":"LA-SELECTIVE","workbench_sample":sample,"region":PackedInt32Array([0,0,256,256]),
		"intent":"exploratory","definition_hash":checked.hash,"initial_bodies":
		PackedFloat32Array([1,origin.x,origin.y,angle,8,8,0,0,0,1,1])})

func run()->void:
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	bridge=ClassDB.instantiate(&"CyberDemoBridge")
	world=ClassDB.instantiate(&"CyberNativeCellWorld")
	var single:Array=[Vector4(0,0,8,8)]
	var hull:Array=[Vector4(0,1.5,8,2),Vector4(-3,-1.5,2,4),Vector4(3,-1.5,2,4)]
	var origin:=Vector2(50,50)
	var token:int=candidate(PackedInt32Array([49,47,1,1,1]),origin,0,hull,1)
	check(token>0 and bridge.commit_liquid_world(world,token),"hard in U cavity must be admissible")
	var generation:int=world.get_liquid_policy_session_generation()
	var before:String=world.get_physical_state_hash()
	for spec:Array in [[50,50,0.0],[54,50,PI/4.0],[55,50,PI/4.0]]:
		token=candidate(PackedInt32Array([spec[0],spec[1],1,1,1]),origin,float(spec[2]),single,2)
		check(token==0 and "hard terrain" in str(bridge.get_last_error()),"reject full/partial rotated hard intersection")
		if token>0: bridge.discard_liquid_world(world,token)
		check(world.get_physical_state_hash()==before and world.get_liquid_policy_session_generation()==generation,"refused placement preserves owner")
	for material:int in [2,3]:
		token=candidate(PackedInt32Array([50,50,1,1,material]),origin,0,single,2)
		check(token>0,"ordinary powder and Water remain material coupling inputs")
		if token>0: bridge.discard_liquid_world(world,token)
	token=candidate(PackedInt32Array([54,50,1,1,1]),origin,0,single,2)
	check(token>0,"touching hard pixel is not overlapping it")
	if token>0: bridge.discard_liquid_world(world,token)
	print("WORKBENCH_HARD_PLACEMENT failures=",failures)
	quit(int(not failures.is_empty()))
