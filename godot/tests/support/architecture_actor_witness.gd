extends RefCounted
## Test-side bounded pilot for the accepted Midge controller. It emits only
## leased actor actions; no pose, velocity, collision or World mutation API.
const FORMAT := "cybersand-architecture-actor-witness-v1"
const CONTROLLER := "midge-observed-waypoint-pd-v1"
const NATIVE_TICK_SOURCE := "CyberSimulationWorker.take_latest_snapshot(0).tick_index"

static func descriptor(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.get("witness",value).duplicate(true)
	result["id"]=str(value.get("id",result.get("family",result.get("id","witness"))))
	if not result.has("waypoints") and result.get("goal") is Array: result["waypoints"]=[result.goal.duplicate()]
	if not result.has("max_ticks"): result["max_ticks"]=int(result.get("tick_budget",2400))
	if not result.has("landing") and result.get("landing_pad") is Array and result.landing_pad.size()==4:
		var pad: Array=result.landing_pad
		result["landing"]=[float(pad[0])+float(pad[2])*0.5,float(pad[1])-2.0]
	if not result.has("start_path") and value.has("start_path"): result["start_path"]=value.start_path
	for key: String in ["plane","sha256","extent"]:
		if value.has(key): result["original_"+key]=value[key]
	return result

static func inspection_region(value: Dictionary,extent: Vector2i) -> Rect2i:
	var raw: Array=value.get("corridor",[])
	if raw.size()!=4: return Rect2i()
	var region:=Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
	var landing: Array=value.get("landing",[])
	if landing.size()==2:
		region=region.merge(Rect2i(int(landing[0])-16,int(landing[1])-8,32,24))
	region=region.grow(16).intersection(Rect2i(Vector2i.ZERO,extent))
	return region if region.get_area()>0 and region.size.x<=512 and region.size.y<=512 else Rect2i()

static func action(view: Dictionary, target: Vector2, landing := false) -> Dictionary:
	var position: Vector2=view.get("position",Vector2.ZERO)
	var velocity: Vector2=view.get("velocity",Vector2.ZERO)
	var angle: float=view.get("rotation",0.0)
	var angular_velocity: float=view.get("angular_velocity",0.0)
	if not position.is_finite() or not velocity.is_finite() or not target.is_finite() or not is_finite(angle) or not is_finite(angular_velocity): return {}
	var error:=target-position
	# Midge uses body thrust: X steers angular rate, negative Y requests
	# collective thrust. This controller deliberately uses no dispenser actions.
	var acceleration:=Vector2(clampf(error.x*0.55-velocity.x*1.6,-32.0,32.0),clampf(error.y*0.65-velocity.y*1.8,-42.0,24.0))
	var thrust:=acceleration-Vector2(0,38.0)
	var wanted_angle:=clampf(atan2(thrust.x,-thrust.y),-0.65,0.65)
	var wanted_alpha:=wrapf(wanted_angle-angle,-PI,PI)*18.0-angular_velocity*7.0
	var steering:=clampf((wanted_alpha/4.0+angular_velocity)/8.0,-0.85,0.85)
	var throttle:=clampf(thrust.length()/180.0,0.0,0.65)
	if landing and absf(error.x)<8.0 and error.y<7.0:
		return {"move":Vector2.ZERO,"effort":1.0,"primary":false,"secondary":true,"auxiliary":true}
	return {"move":Vector2(steering,-throttle).limit_length(1.0),"effort":1.0,"primary":false,"secondary":false,"auxiliary":false}

static func sample(view: Dictionary, native_tick: int, command: Dictionary, accepted: bool, render_cached_tick: int = -1) -> Dictionary:
	var position: Vector2=view.get("position",Vector2.ZERO)
	var velocity: Vector2=view.get("velocity",Vector2.ZERO)
	var normal: Vector2=view.get("contact_normal",Vector2.ZERO)
	return {"native_tick":native_tick,"render_cached_native_tick":render_cached_tick,"actor_tick":int(view.get("tick",-1)),
		"observation_id":view.get("observation_id",""),"run_id":view.get("run_id",""),"epoch":view.get("epoch",-1),
		"position":[position.x,position.y],"velocity":[velocity.x,velocity.y],
		"rotation":view.get("rotation",0.0),"angular_velocity":view.get("angular_velocity",0.0),
		"grounded":view.get("grounded",false),"contact_normal":[normal.x,normal.y],
		"action":_json(command.get("action",{})),"sequence":command.get("sequence",-1),
		"lease_ticks":command.get("lease_ticks",0),"accepted":accepted,"fault":view.get("fault","")}

static func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value: result[str(key)]=_json(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value: result.append(_json(item))
		return result
	return value
