extends RefCounted

# Main-thread stroke/handoff coordinator. Only copied values cross to native.
const Setup=preload("res://scripts/workbench_setup.gd")
const Prepared=preload("res://scripts/prepared_physical_session.gd")
const Bridge=preload("res://scripts/workbench_physics_bridge.gd")
var panel
var busy: bool=false
var capture_count: int=0
var dabs:=PackedInt32Array()
var overflow: bool=false
var receipts: Array[Dictionary]=[]
var _prior_paused: bool=true
var _token: String=""
var _committed: bool=false
var _candidate: RefCounted
var _staged: Dictionary={}
var _sample: Dictionary={}
var _recipe: Dictionary={}
var _retired: bool=false
var _native_session: int=0
var _native_epoch: int=0

func _alive() -> bool:
	return not _retired and is_instance_valid(panel) and is_instance_valid(panel.host)

func retire() -> void:
	_retired=true
	# Whole-owner teardown retires the staged graph and native World together;
	# no captured payload is restored into cells.
	_discard()
	busy=false;panel=null

func note_erase(position: Vector2i, radius: int) -> void:
	if dabs.size()>=256*3: overflow=true;return
	dabs.append_array(PackedInt32Array([position.x,position.y,radius]))

func cancel_stroke() -> void:
	dabs.clear();overflow=false

func finish_stroke(owner) -> bool:
	if _retired or busy or dabs.is_empty(): return false
	panel=owner
	var input: PackedInt32Array=dabs.duplicate()
	var exceeded: bool=overflow
	cancel_stroke()
	if exceeded: return panel.refuse("Cut discovery exceeds 256 dabs; the erase itself is retained.")
	busy=true;receipts.clear();_prior_paused=panel.host.paused
	panel.host.paused=true
	panel.host.cancel_playable_course_input()
	panel.host.update_worker_frame_state()
	if panel.host.physical_actor_session!=null: panel.host.physical_actor_session.set_suspended(true)
	_run(input)
	return true

func _rpc(command: Dictionary) -> Dictionary:
	if not _alive(): return {"ok":false,"outcome":"Retired"}
	var worker=panel.host.simulation_worker
	var tree: SceneTree=panel.get_tree()
	var serial: int=worker.queue_workbench_cut(command)
	if serial==0: return {"ok":false,"outcome":"Worker admission refused"}
	var deadline: int=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		if not _alive(): return {"ok":false,"outcome":"Retired"}
		var reply: Dictionary=worker.take_workbench_cut_reply(serial)
		if not reply.is_empty():
			receipts.append(reply.duplicate(true))
			return reply
		await tree.process_frame
	return {"ok":false,"outcome":"Worker reply timeout; clocks remain held"}

func _prepare_recipe(payload: Dictionary) -> bool:
	_recipe=panel.applied.duplicate(true)
	if _recipe.actors.size()>=Setup.MAX_BODIES: return false
	var rectangles: PackedInt32Array=payload.rectangles
	var origin:=Vector2i(2048,2048)
	for i: int in range(0,rectangles.size(),4): origin=origin.min(Vector2i(rectangles[i],rectangles[i+1]))
	var local: Array=[]
	for i: int in range(0,rectangles.size(),4):
		local.append([rectangles[i]-origin.x,rectangles[i+1]-origin.y,rectangles[i+2],rectangles[i+3]])
		_recipe.edits.append([rectangles[i],rectangles[i+1],rectangles[i+2],rectangles[i+3],0])
	var body: Dictionary={"name":"Freed %d" % int(_recipe.next_id),"rectangles":local}
	var actor: Dictionary=Setup.instance(Setup.CanvasBody.MODEL,int(_recipe.next_id),payload.center)
	actor["body"]=body;actor.hash=Setup.CanvasBody.digest(body)
	_recipe.actors.append(actor);_recipe.next_id+=1;_recipe.version=4
	if not Setup.validate(_recipe).is_empty() or JSON.stringify(_recipe).to_utf8_buffer().size()>Setup.BYTE_LIMIT: return false
	return not Setup.rectangles(_recipe).has("error")

func _stage() -> bool:
	var host=panel.host
	var epoch: int=maxi(host._physical_epoch,_native_epoch)+1
	var definitions: Array=Setup.physical_definitions(_recipe)
	if host.physical_actor_session==null:
		var loop: MainLoop=Engine.get_main_loop()
		loop.set_meta(Bridge.SESSION_META,maxi(int(loop.get_meta(Bridge.SESSION_META,0)),_native_session))
		_candidate=Prepared.new()
		if not _candidate.prepare(host,definitions,epoch): return false
		_sample=_candidate.initial_workbench_sample()
	else:
		_staged=host.physical_actor_session.stage_workbench_piece(definitions.back(),epoch)
		if _staged.is_empty(): return false
		_sample=host.rapier_bridge.pack_held_sample()
	return not _sample.is_empty()

func _discard() -> void:
	if _candidate!=null: _candidate.close();_candidate=null
	if not _staged.is_empty(): panel.host.physical_actor_session.discard_workbench_piece(_staged);_staged={}
	_sample={};_recipe={}

func _abort(reason: String) -> void:
	if not _alive(): return
	panel.refuse(reason)
	if _committed:
		await _rpc({"action":"fail","token":_token})
		return
	if not _token.is_empty():
		var cancelled: Dictionary=await _rpc({"action":"cancel","token":_token})
		if not _alive(): return
		if not cancelled.get("ok",false): return
	_discard()
	var ended: Dictionary=await _end()
	if not _alive(): return
	if ended.get("ok",false): _finish()

func _finish() -> void:
	if not _alive(): return
	busy=false;_token="";_committed=false
	panel.host.paused=_prior_paused
	panel.host.update_worker_frame_state()

func _end() -> Dictionary:
	var host=panel.host
	var sample: Dictionary={} if host.physical_actor_session==null else host.rapier_bridge.pack_held_sample()
	var reply: Dictionary=await _rpc({"action":"end","sample":sample})
	if _alive() and reply.get("ok",false) and not sample.is_empty():
		host._workbench_wait_sample=int(sample.states[10])
		host._workbench_cut_wait=true
		host._workbench_cut_prepare_sent=false
	return reply

func _run(input: PackedInt32Array) -> void:
	var host=panel.host
	var old_sample: Dictionary={} if host.physical_actor_session==null else host.rapier_bridge.pack_held_sample()
	var begun: Dictionary=await _rpc({"action":"begin","dabs":input,"sample":old_sample})
	if not _alive(): return
	if not begun.get("ok",false):
		panel.refuse(str(begun.outcome))
		if not str(begun.outcome).contains("timeout"):
			var ended: Dictionary=await _end()
			if _alive() and ended.get("ok",false): _finish()
		return
	_native_session=int(begun.roster_session);_native_epoch=int(begun.roster_epoch)
	var released: int=0
	var refused: Dictionary={}
	for attempt: int in range(65):
		var payload: Dictionary=await _rpc({"action":"next"})
		if not _alive(): return
		if payload.get("done",false): break
		if not payload.get("ok",false):
			var reason: String=str(payload.outcome)
			refused[reason]=int(refused.get(reason,0))+1
			if reason in ["WorldFailed","Quarantined"] or reason.contains("timeout"):
				panel.refuse(reason);return
			continue
		_token=payload.token
		if not _prepare_recipe(payload) or not _stage():
			await _abort("The piece exceeds the saved-canvas or physical-owner budget.");return
		for frame: int in range(2):
			await panel.get_tree().physics_frame
			if not _alive(): return
			if _candidate!=null and not _candidate.verify_physics_frame():
				await _abort("Staged body pose changed before handoff.");return
		var ack: Dictionary=await _rpc({"action":"acknowledge","token":_token,"sample":_sample})
		if not _alive(): return
		if not ack.get("ok",false): await _abort("Body reservation: "+str(ack.outcome));return
		var committed: Dictionary=await _rpc({"action":"commit","token":_token})
		if not _alive(): return
		if not committed.get("ok",false):
			_committed=true
			await _abort("Native commit: "+str(committed.outcome));return
		_committed=true
		if not committed.get("terrain_chunks_valid",false) or committed.terrain_snapshot_revision!=committed.commit_revision:
			await _abort("Post-cut terrain publication does not match native retirement.");return
		var bridge=host.rapier_bridge if _candidate==null else _candidate.physics_bridge()
		if not bridge.queue_hard_surface_chunk_snapshot(committed.terrain_chunks):
			await _abort("Post-cut terrain installation refused.");return
		while bridge.pending_hard_surface_chunks()>0:
			bridge.process_hard_surface_collider_budget(8,2000)
			await panel.get_tree().process_frame
			if not _alive(): return
		var final: Dictionary=await _rpc({"action":"finalize","token":_token,"terrain_revision":committed.commit_revision,"sample":_sample})
		if not _alive(): return
		if not final.get("ok",false): await _abort("Ownership finalization: "+str(final.outcome));return
		if _candidate!=null:
			host._pending_physical_candidate=_candidate
			host._adopt_prepared_physical_candidate()
			_candidate=null
		else:
			host.physical_actor_session.adopt_workbench_piece(_staged)
			host._physical_epoch=host.physical_actor_session.epoch
			host.rigid_bodies=host.physical_actor_session.bodies()
			host.simulation_worker.set_physical_actor_epoch(host._physical_epoch)
			_staged={}
		host.last_hard_surface_revision=int(committed.commit_revision)
		host._physical_terrain_ready=true
		panel.adopt_cut_recipe(_recipe)
		_sample={};_recipe={};_committed=false;_token=""
		released+=1;capture_count=int(final.active_count)
	var ended: Dictionary=await _end()
	if not _alive(): return
	if not ended.get("ok",false): panel.refuse(str(ended.outcome));return
	panel.message="Cut: %d piece(s) freed" % released
	if not refused.is_empty(): panel.message+=" · retained checks "+str(refused)
	if refused.has("Excluded"): panel.message+=" · Step or Play first to apply the requested simulation region."
	_finish()
