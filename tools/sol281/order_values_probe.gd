extends SceneTree
const Planner=preload("res://planner.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("SOL_ORDER_VALUES ",why)
func vec(a: Array) -> Vector2:return Vector2(a[0],a[1])
func pose(a: Array) -> Transform2D:return Transform2D(vec(a.slice(0,2)),vec(a.slice(2,4)),vec(a.slice(4,6)))
func scalars(hex: String) -> Array:
	var b: PackedByteArray=hex.hex_decode();var out: Array=[]
	check(b.size()==88,"body11double envelope")
	for i: int in 11:out.append(b.decode_double(i*8))
	return out
func bits(a: Array) -> String:
	var b:=PackedByteArray();b.resize(a.size()*8)
	for i: int in a.size():b.encode_double(i*8,float(a[i]))
	return b.hex_encode()
func restore(raw: Dictionary) -> Dictionary:
	var out: Dictionary=raw.duplicate(true);out.source_transform=pose(out.source_transform)
	for key: String in ["sample_serial","tick","snapshot_serial","physics_epoch","published_usec"]:
		if out.has(key):out[key]=int(out[key])
	for c: Dictionary in out.get("contacts",[]):
		c.proxy=int(c.proxy);c.face=int(c.face);c.cell=Vector2i(c.cell[0],c.cell[1])
		for key: String in ["point","a","b","normal"]:c[key]=vec(c[key])
	return out
func plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	if value is Array:
		var out: Array=[]
		for x: Variant in value:out.append(plain(x))
		return out
	if value is Dictionary:
		var out: Dictionary={}
		for key: Variant in value:out[str(key)]=plain(value[key])
		return out
	return value
func wrapper(item: Dictionary,obs: Dictionary,current: int,last: Dictionary) -> String:
	if not item.invoked:return "NOT_EXECUTED"
	if not item.ordinary_accepted:return "CompoundResponseRefused"
	if not obs.get("ok",false) or not obs.get("complete",false):return "IdentityRefused"
	for key: String in ["snapshot_serial","tick","physics_epoch","sample_serial","published_usec"]:
		if not obs.get(key) is int:return "IdentityRefused"
	if obs.snapshot_serial!=int(item.snapshot) or obs.tick!=int(item.tick) or obs.physics_epoch!=int(item.epoch) or obs.get("token")!=item.token or obs.get("body_generation")!=str(item.generation) or obs.get("revision")!=item.revision or obs.sample_serial!=int(item.sample) or obs.published_usec<0 or obs.published_usec>int(item.capture_usec):return "IdentityRefused"
	if current<0 or current>=1000000 or int(item.sample)<0 or int(item.sample)>=1000000:return "IdentityRefused"
	if (current-int(item.sample)+1000000)%1000000>1:return "StaleContactSample"
	if not last.is_empty():
		var delta: int=(int(item.sample)-int(last.sample)+1000000)%1000000
		if int(item.snapshot)<=int(last.snapshot) or int(item.tick)<int(last.tick) or delta==0 or delta>500000:return "DuplicateOrOldContact"
	return "Admitted"
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var folder: String=OS.get_environment("SOL_ORDER_INPUT");var output: String=OS.get_environment("SOL_ORDER_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):printerr("SOL_ORDER_VALUES refuses output");quit(1);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")));var sessions: Array=[]
	for session_file: String in manifest.sessions:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(session_file)))
		var centres:=PackedVector2Array();var sizes:=PackedVector2Array()
		for x: Array in data.centres:centres.append(vec(x))
		for x: Array in data.sizes:sizes.append(vec(x))
		var leases: Dictionary={"current":{},"prediction":{},"post":{}};var rows: Array=[]
		for item: Dictionary in data.steps:
			var a: Array=scalars(item.s1);var c: Array=scalars(item.s3);var predicted: Array=a.duplicate()
			var pv: Vector2=(Vector2(a[6],a[7])+vec(item.gravity)*float(item.dt))/(1.+float(item.ld)*float(item.dt))
			predicted[6]=pv.x;predicted[7]=pv.y;predicted[8]=float(a[8])/(1.+float(item.ad)*float(item.dt))
			var obs: Dictionary=restore(item.observation);var arms: Dictionary={}
			for arm: String in ["current","prediction","post"]:
				var input: Array=a if arm=="current" else predicted if arm=="prediction" else c
				var serial: int=int(item.post_current) if arm=="post" else int(item.current)
				var admission: String=wrapper(item,obs,serial,leases[arm]);var plan: Dictionary=Planner.plan(obs,pose(input),Vector2(input[6],input[7]),input[8],input[9],input[10],centres,sizes)
				var result: Dictionary={"admission":admission,"input_bits":bits(input),"plan":plain(plan)}
				if plan.get("accepted",false):
					var after: Array=input.duplicate();after[6]=plan.velocity.x;after[7]=plan.velocity.y;after[8]=plan.omega;result["output_bits"]=bits(after)
					var hv:=Vector2(a[6],a[7]);var hw: float=a[8];var com: Vector2=pose(a).basis_xform(vec(item.local_com))
					for action: Dictionary in plan.impulses:
						hv+=action.impulse/float(a[9]);hw+=(action.offset-com).cross(action.impulse)/float(a[10])
					var virtual: Array=a.duplicate();virtual[6]=hv.x;virtual[7]=hv.y;virtual[8]=hw;result["unapplied_s1_bits"]=bits(virtual)
					if admission=="Admitted":leases[arm]={"sample":int(item.sample),"snapshot":int(item.snapshot),"tick":int(item.tick)}
				var outcome: String=plan.get("outcome","Unknown") if admission=="Admitted" else admission
				result["effective_outcome"]=outcome;arms[arm]=result
				if arm=="current" and item.recorded_new:
					check(outcome==item.recorded_outcome,"current source outcome reproduces "+str(data.id)+"/"+str(item.step))
					if plan.get("accepted",false) and admission=="Admitted":check(plain(plan.total_impulse)==item.recorded_impulse and plan.torque_impulse==item.recorded_torque,"current wrench reproduces")
			rows.append({"step":item.step,"arms":arms})
		sessions.append({"id":data.id,"rows":rows})
	var handle:=FileAccess.open(output,FileAccess.WRITE);check(handle!=null,"output writable")
	if handle==null:quit(1);return
	handle.store_string(JSON.stringify({"registration":manifest.registration,"checks":checks,"failures":failures,"sessions":sessions},"",true,true));handle.flush();var error: Error=handle.get_error();handle.close()
	print("SOL_ORDER_VALUES checks=",checks," failures=",failures.size());quit(int(not failures.is_empty() or error!=OK))
