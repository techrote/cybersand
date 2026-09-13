class_name CyberSolidingDynamicProbe
extends RefCounted

static func shape_body(size: Vector2, center: Vector2, dynamic: bool, space: RID) -> Dictionary:
	var shape: RID = PhysicsServer2D.rectangle_shape_create()
	if not shape.is_valid():return {}
	PhysicsServer2D.shape_set_data(shape,size*0.5)
	var body: RID = PhysicsServer2D.body_create()
	if not body.is_valid():
		PhysicsServer2D.free_rid(shape);return {}
	PhysicsServer2D.body_set_mode(body,PhysicsServer2D.BODY_MODE_RIGID_LINEAR if dynamic else PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_add_shape(body,shape)
	PhysicsServer2D.body_set_state(body,PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0,center))
	PhysicsServer2D.body_set_collision_layer(body,0)
	PhysicsServer2D.body_set_collision_mask(body,0)
	PhysicsServer2D.body_set_space(body,space)
	var item: Dictionary = {"body":body,"shape":shape}
	if not valid_body(item,space):
		dispose(item);return {}
	return item

static func valid_body(item: Dictionary, space: RID) -> bool:
	return item.has("body") and item.has("shape") and item.body.is_valid() and item.shape.is_valid() and PhysicsServer2D.body_get_shape_count(item.body)==1 and PhysicsServer2D.body_get_space(item.body)==space

static func enabled(item: Dictionary, value: bool) -> void:
	PhysicsServer2D.body_set_collision_layer(item.body,1 if value else 0)
	PhysicsServer2D.body_set_collision_mask(item.body,1 if value else 0)

static func dispose(item: Dictionary) -> void:
	if item.is_empty():return
	PhysicsServer2D.free_rid(item.body)
	PhysicsServer2D.free_rid(item.shape)

static func sample(body: RID) -> PackedFloat64Array:
	var transform: Transform2D = PhysicsServer2D.body_get_state(body,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(body,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var omega: float = PhysicsServer2D.body_get_state(body,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	return PackedFloat64Array([transform.origin.x,transform.origin.y,transform.get_rotation(),velocity.x,velocity.y,omega])

# All failures before commit leave old collider layers untouched. Caller disposes
# disabled prepared resources. Only a confirmed commit permits the topology switch.
static func handoff(session: Object, old: Dictionary, replacement: Dictionary, floor_body: Dictionary, space: RID, promotion: bool, fault: String = "") -> Dictionary:
	var token: PackedInt64Array = session.token()
	if not valid_body(replacement,space) or not valid_body(old,space) or not valid_body(floor_body,space) or fault=="resource":
		session.cancel(token)
		return {"ok":false,"committed":false,"reason":"resource"}
	if not session.acknowledge(token):
		session.cancel(token)
		return {"ok":false,"committed":false,"reason":"ack"}
	var commit_token: PackedInt64Array = token.duplicate()
	if fault=="commit":commit_token[0]+=1
	if not session.commit(commit_token):
		session.cancel(token)
		return {"ok":false,"committed":false,"reason":"commit"}
	enabled(old,false)
	enabled(replacement,true)
	var mask: Dictionary = {"complete":true,"required":0,"written":0}
	if promotion:mask=session.occupancy(sample(replacement.body))
	var census: Dictionary = session.status()
	var topology: bool = mask.complete and PhysicsServer2D.body_get_collision_layer(old.body)==0 and PhysicsServer2D.body_get_collision_layer(replacement.body)==1 and PhysicsServer2D.body_get_collision_layer(floor_body.body)==1
	topology = topology and census.cell_members==(0 if promotion else census.members) and census.slot_members==(census.members if promotion else 0)
	var finished: bool = session.finalize(token,topology)
	return {"ok":finished,"committed":true,"reason":"" if finished else "topology","mask":mask}

# Every motion loop, including re-entry, uses this gate before touching Rapier.
static func motion_step(session: Object, body: RID, space: RID, serial: int, bad_mask: bool = false) -> Dictionary:
	var endpoint: PackedFloat64Array = sample(body)
	if bad_mask:endpoint[0]=1.0;endpoint[1]=1.0
	var mask: Dictionary = session.occupancy(endpoint)
	if not mask.complete:return {"ok":false,"stepped":0,"reason":"mask"}
	if not session.tick():return {"ok":false,"stepped":0,"reason":"native tick"}
	ClassDB.class_call_static(&"RapierPhysicsServer2D",&"space_step",space,1.0/60.0)
	var current: PackedFloat64Array = sample(body)
	var observed: bool = session.observe_motion(current,serial)
	if not observed:session.quarantine()
	return {"ok":observed,"stepped":1,"sample":current,"mask":mask}

static func run(host: Node, workers: int, height: int) -> Dictionary:
	var backend: Dictionary = CyberWebCapabilities.rapier_probe()
	if not backend.ok:return {"ok":false,"error":"Rapier admission: "+str(backend.reason)}
	var session: Object = ClassDB.instantiate(&"CyberSolidingSession")
	await host.get_tree().process_frame
	if not session.configure(8,height,workers):return {"ok":false,"error":"configure"}
	await host.get_tree().process_frame
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d=World2D.new();host.add_child(viewport)
	var space: RID = viewport.world_2d.space
	PhysicsServer2D.space_set_active(space,false)
	var floor_body: Dictionary = shape_body(Vector2(96,2),Vector2(64,97),false,space)
	var static_body: Dictionary = shape_body(Vector2(8,height),Vector2(40,96-height*0.5),false,space)
	var dynamic_body: Dictionary = {}
	var restored: Dictionary = {}
	var ok: bool = valid_body(floor_body,space) and valid_body(static_body,space)
	var error: String = ""
	var cycles: Array = []
	var fault_checks: int = 0
	var original: Dictionary = session.status()
	if ok:
		enabled(floor_body,true);enabled(static_body,true)
		ok = not session.configure(8,height,workers) and not session.edit(40,80,1,200)
	for cycle: int in range(4):
		if not ok:break
		for tick: int in range(310):
			if not session.tick():ok=false;error="candidate tick";break
		if not ok:break
		var before: Dictionary = session.status()
		var rectangle: Rect2i = before.rectangle
		var begin: int = Time.get_ticks_usec()
		if not session.prepare_promotion():ok=false;error="promotion prepare";break
		dynamic_body=shape_body(Vector2(rectangle.size),Vector2(rectangle.position)+Vector2(rectangle.size)*0.5,true,space)
		if not valid_body(dynamic_body,space):
			session.cancel(session.token());ok=false;error="dynamic resources";break
		var mass: float = float(before.members)/112.0
		PhysicsServer2D.body_set_param(dynamic_body.body,PhysicsServer2D.BODY_PARAM_MASS,mass)
		PhysicsServer2D.body_set_param(dynamic_body.body,PhysicsServer2D.BODY_PARAM_INERTIA,mass*Vector2(rectangle.size).length_squared()/12.0)
		PhysicsServer2D.body_set_param(dynamic_body.body,PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE,0.094)
		PhysicsServer2D.body_set_param(dynamic_body.body,PhysicsServer2D.BODY_PARAM_FRICTION,0.78)
		if cycle==0:
			for fault: String in ["resource","commit"]:
				var denied: Dictionary = handoff(session,static_body,{} if fault=="resource" else dynamic_body,floor_body,space,true,fault)
				ok = not denied.ok and not denied.committed and session.status().cell_members==before.members and PhysicsServer2D.body_get_collision_layer(static_body.body)==1 and PhysicsServer2D.body_get_collision_layer(dynamic_body.body)==0
				if not ok or not session.prepare_promotion():ok=false;error="promotion refusal changed topology";break
				fault_checks+=1
		if not ok:break
		var result: Dictionary = handoff(session,static_body,dynamic_body,floor_body,space,true)
		if not result.ok:ok=false;error="promotion "+result.reason;break
		var promotion_usec: int = Time.get_ticks_usec()-begin
		PhysicsServer2D.body_set_state(dynamic_body.body,PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(PI*0.5,Vector2(60,70)))
		PhysicsServer2D.body_set_state(dynamic_body.body,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2.ZERO)
		PhysicsServer2D.body_set_state(dynamic_body.body,PhysicsServer2D.BODY_STATE_SLEEPING,false)
		var current: PackedFloat64Array
		var mask: Dictionary
		var steps: int = 0
		var saw_fall: bool = false
		var peak_downward_speed: float = 0.0
		var expected_contact_y: float = 96.0-float(rectangle.size.x)*0.5
		for tick: int in range(1500):
			result=motion_step(session,dynamic_body.body,space,steps+1)
			if not result.ok:ok=false;error="motion gate";break
			steps+=result.stepped;current=result.sample;mask=result.mask
			peak_downward_speed=maxf(peak_downward_speed,current[4])
			saw_fall=saw_fall or (current[1]>72.0 and current[4]>0.5)
			if saw_fall and absf(current[1]-expected_contact_y)<=0.02 and steps>300 and session.status().motion_rest>=300:break
		if ok and (not saw_fall or absf(current[1]-expected_contact_y)>0.02 or session.status().motion_rest<300):
			ok=false;error="isolated space did not demonstrate falling/contact"
		if not ok:break
		if not session.set_excluded(true) or session.tick() or not session.set_excluded(false):ok=false;error="exclusion";break
		# An injected incomplete mask must permit zero native/Rapier steps.
		var prior: PackedFloat64Array = sample(dynamic_body.body)
		result=motion_step(session,dynamic_body.body,space,1,true)
		if result.ok or result.stepped!=0 or prior!=sample(dynamic_body.body):ok=false;error="reentry rejection stepped";break
		fault_checks+=1
		for tick: int in range(301):
			result=motion_step(session,dynamic_body.body,space,tick+1)
			if not result.ok:ok=false;error="reentry gate";break
			current=result.sample;mask=result.mask
		if not ok:break
		begin=Time.get_ticks_usec()
		if not session.prepare_reversal(current):ok=false;error="near-rest reversal";break
		restored=shape_body(Vector2(rectangle.size.y,rectangle.size.x),Vector2(round(current[0]),round(current[1])),false,space)
		if cycle==0:
			for fault: String in ["resource","commit"]:
				result=handoff(session,dynamic_body,{} if fault=="resource" else restored,floor_body,space,false,fault)
				ok = not result.ok and not result.committed and session.status().slot_members==before.members and PhysicsServer2D.body_get_collision_layer(dynamic_body.body)==1 and valid_body(restored,space) and PhysicsServer2D.body_get_collision_layer(restored.body)==0
				if not ok or not session.prepare_reversal(current):ok=false;error="reverse refusal changed topology";break
				fault_checks+=1
		if not ok:break
		result=handoff(session,dynamic_body,restored,floor_body,space,false)
		if not result.ok:ok=false;error="reversal "+result.reason;break
		var census: Dictionary = session.status()
		ok = census.payload_hash==original.payload_hash
		cycles.append({"cycle":cycle,"members":before.members,"mass":mass,"inertia":mass*Vector2(rectangle.size).length_squared()/12.0,"motion_steps":steps,"saw_fall":saw_fall,"peak_downward_speed":peak_downward_speed,"contact_y":current[1],"sample":Array(current),"promotion_usec":promotion_usec,"reversal_usec":Time.get_ticks_usec()-begin,"snap_y":census.snap_y,"speed_bound":census.speed_bound,"discarded_energy":census.discarded_energy,"mask_required":mask.required,"mask_written":mask.written,"conserved":ok})
		dispose(static_body);static_body=restored;restored={}
		dispose(dynamic_body);dynamic_body={}
		if not ok:error="payload conservation";break
	var final_status: Dictionary = session.status()
	if not ok:session.quarantine()
	dispose(restored);dispose(dynamic_body);dispose(static_body);dispose(floor_body)
	viewport.queue_free();session=null
	await host.get_tree().process_frame
	return {"ok":ok,"error":error,"workers":workers,"height":height,"cycles":cycles,"fault_checks":fault_checks,"status":final_status,"backend":backend,"coupling":"Rapier hard contact only","owner_schedule":"isolated manual main thread"}
