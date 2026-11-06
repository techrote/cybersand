extends SceneTree

const MASS: float = 520.0
const INERTIA: float = 109907693.0/1560.0
var centers := PackedVector2Array()
var sizes := PackedVector2Array()
var pose := Transform2D.IDENTITY
var observation: Dictionary = {}
var offset := Vector2.ZERO
var checks: int = 0
var failures: Array[String] = []
var modules: Dictionary = {}
var records: Array = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason);printerr("SOL_ENERGY: "+reason)

func f64(value: float) -> Dictionary:
	var bytes := PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	return {"value":value if is_finite(value) else str(value),"f64le":bytes.hex_encode()}

func exact(value: Variant) -> Variant:
	if value is float: return f64(value)
	if value is Vector2:
		var bytes := PackedByteArray();bytes.resize(8)
		bytes.encode_float(0,value.x);bytes.encode_float(4,value.y)
		return {"type":"Vector2","x":f64(value.x),"y":f64(value.y),"f32le":bytes.hex_encode()}
	if value is Vector2i: return [value.x,value.y]
	if value is Transform2D: return {"type":"Transform2D","x":exact(value.x),"y":exact(value.y),"origin":exact(value.origin)}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:result[str(key)]=exact(value[key])
		return result
	if value is Array or value is PackedVector2Array:
		var result: Array = []
		for item: Variant in value:result.append(exact(item))
		return result
	return value

func setup() -> void:
	var source_center := Vector2(32.0+3293.0/130.0,16.0+175.0/8.0)
	var area: float = 0
	for rectangle: Rect2 in [Rect2(44,27,29,5),Rect2(44,32,16,1),Rect2(61,32,12,1),Rect2(44,33,29,7),Rect2(50,40,15,4),Rect2(50,44,4,21)]:
		centers.append(rectangle.get_center()-source_center);sizes.append(rectangle.size);area+=rectangle.get_area()
	check(area==520,"exact six-proxy area")
	pose=Transform2D(0,source_center+Vector2(0,.25));offset=Vector2(52.5,65.25)-pose.origin
	observation={"schema":"cybersand.sol281.sand-contact.v1","ok":true,"complete":true,"sample_serial":1,"token":"precision:1","body_generation":"1","tick":1,"revision":"1","source_transform":pose,
		"contacts":[{"proxy":6,"face":2,"cell":Vector2i(52,65),"point":Vector2(52.5,65.25),"normal":Vector2.DOWN,"a":Vector2(53,65.25),"b":Vector2(52,65.25),"depth":.25,"area":.25,"weight":1.0}]}

func evaluate(name: String, velocity: Vector2, omega: float, mass: float=MASS, inertia: float=INERTIA, obs: Dictionary={}, current: Transform2D=Transform2D.IDENTITY) -> void:
	if obs.is_empty():obs=observation
	if current==Transform2D.IDENTITY:current=pose
	var results: Dictionary = {};var traces: Dictionary = {}
	for arm: String in modules:
		var module: Variant = modules[arm]
		if arm.ends_with("trace"):module.numeric_trace.clear()
		var untouched: Dictionary = obs.duplicate(true)
		var result: Dictionary = module.plan(obs,current,velocity,omega,mass,inertia,centers,sizes)
		check(obs==untouched,"immutable input "+name+" "+arm)
		check(result.accepted or result.impulses.is_empty(),"atomic refusal "+name+" "+arm)
		var trace: Array = module.numeric_trace.duplicate(true) if arm.ends_with("trace") else []
		for replay: int in 2:
			if arm.ends_with("trace"):module.numeric_trace.clear()
			check(module.plan(obs,current,velocity,omega,mass,inertia,centers,sizes)==result,"exact replay "+name+" "+arm)
			if arm.ends_with("trace"):check(module.numeric_trace==trace,"exact trace replay "+name+" "+arm)
		results[arm]=result;traces[arm]=trace
	check(results.baseline==results["baseline-trace"],"algebra-neutral baseline trace "+name)
	check(results.scalar64==results["scalar64-trace"],"algebra-neutral scalar trace "+name)
	records.append({"name":name,"input":exact({"velocity":velocity,"omega":omega,"mass":mass,"inertia":inertia,"observation":obs,"current":current}),"results":exact(results),"traces":exact(traces)})

func run() -> void:
	for arm: String in ["baseline","baseline-trace","scalar64","scalar64-trace"]:modules[arm]=load("res://"+arm+".gd")
	setup()
	for omega: float in [-10.0,-1.0,-.1,0,.1,1,10]:
		for delta: float in [1e-6,1e-5,1e-4,1e-3,.01,.1]:
			for vx: float in [0.0,3.0]:evaluate("grid/"+str(omega)+"/"+str(delta)+"/"+str(vx),Vector2(vx,-omega*offset.x+delta),omega)
	for item: Array in [["approaching",Vector2(0,12)],["separating",Vector2(0,-12)],["stationary",Vector2.ZERO],["sub-approach",Vector2(0,1e-7)]]:evaluate(item[0],item[1],0)
	for mass: float in [0,-1,INF,NAN]:evaluate("invalid-mass/"+str(mass),Vector2(0,12),0,mass)
	for inertia: float in [0,-1,INF,NAN]:evaluate("invalid-inertia/"+str(inertia),Vector2(0,12),0,MASS,inertia)
	for omega: float in [INF,NAN]:evaluate("invalid-omega/"+str(omega),Vector2(0,12),omega)
	for velocity: Vector2 in [Vector2(INF,0),Vector2(NAN,0)]:evaluate("invalid-velocity/"+str(velocity),velocity,0)
	evaluate("finite-overflow",Vector2(2,0),0,1e308)
	var corner: Dictionary = observation.duplicate(true)
	var shift := Vector2(.25,0)
	corner.source_transform=Transform2D(0,pose.origin+shift)
	corner.contacts.append({"proxy":4,"face":1,"cell":Vector2i(73,35),"a":Vector2(73.25,35),"b":Vector2(73.25,36),"point":Vector2(73.25,35.5),"normal":Vector2.RIGHT,"area":.25,"depth":.25,"weight":1.0})
	for omega: float in [-1,0,1]:evaluate("two-normal/"+str(omega),Vector2(3,12),omega,MASS,INERTIA,corner,corner.source_transform)
	var ranges: Dictionary = {}
	for arm: String in ["baseline","scalar64"]:
		ranges[arm]=[]
		for value: float in [1e20,1e-30]:ranges[arm].append(exact({"velocity":Vector2(value,0),"energy":modules[arm]._energy(Vector2(value,0),0,MASS,INERTIA)}))
	var timings: Array = []
	for order: Array in [["baseline","scalar64"],["scalar64","baseline"],["baseline","scalar64"]]:
		for arm: String in order:
			var start: int = Time.get_ticks_usec();var accepted: int = 0;var calls: int = 0
			for cycle: int in 30:
				for omega: float in [-10.0,-1.0,-.1,0,.1,1,10]:
					for delta: float in [1e-6,1e-5,1e-4,1e-3,.01,.1]:
						for vx: float in [0.0,3.0]:
							var result: Dictionary = modules[arm].plan(observation,pose,Vector2(vx,-omega*offset.x+delta),omega,MASS,INERTIA,centers,sizes)
							accepted+=int(result.accepted);calls+=1
			timings.append({"arm":arm,"calls":calls,"accepted":accepted,"microseconds":Time.get_ticks_usec()-start})
	var output: Dictionary = {"registration":"SOL-ENERGY-001","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"engine":Engine.get_version_info(),"shape":exact({"centers":centers,"sizes":sizes,"pose":pose,"offset":offset}),"records":records,"ranges":ranges,"timings":timings,"checks":checks,"failures":failures}
	var file := FileAccess.open("res://results.json",FileAccess.WRITE);file.store_string(JSON.stringify(output));file.close()
	print("SOL_ENERGY checks=",checks," failures=",failures.size()," cases=",records.size())
	quit(int(not failures.is_empty()))
