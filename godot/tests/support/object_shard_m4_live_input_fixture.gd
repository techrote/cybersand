extends RefCounted

# Faithful injected mouse events enter the connected production canvas signal.
# Tests inspect native publications/receipts but never call an edit action API.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var events: int = 0
var last_local := Vector2.ZERO
var button: int = 0

func _init(tree: SceneTree) -> void:
	f = Fixture.new(tree)

func local(position: Vector2) -> Vector2:
	var area: Rect2 = f.host.view_content_rect()
	return area.position+(position-Vector2(f.host.camera_origin.floor())+Vector2(0.5,0.5)) \
		*area.size/Vector2(f.host.current_view_size)

func select_tool(index: int, radius: int = 4) -> void:
	f.bench._tool.select(index)
	f.bench._tool.item_selected.emit(index)
	f.bench._brush.value = radius

func press(position: Vector2, which: int = MOUSE_BUTTON_LEFT) -> void:
	button = which
	var event := InputEventMouseButton.new()
	event.position = local(position)
	event.global_position = event.position+f.host.world_view.global_position
	event.button_index = which
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if which==MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	last_local = event.position
	events += 1
	f.host.world_view.gui_input.emit(event)

func move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = local(position)
	event.global_position = event.position+f.host.world_view.global_position
	event.relative = event.position-last_local
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if button==MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT if button!=0 else 0
	last_local = event.position
	events += 1
	f.host.world_view.gui_input.emit(event)

func release(outside: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(-20,-20) if outside else last_local
	event.global_position = event.position+f.host.world_view.global_position
	event.button_index = button if button!=0 else MOUSE_BUTTON_LEFT
	event.button_mask = 0
	event.pressed = false
	button = 0
	events += 1
	if outside: f.bench._input(event)
	else: f.host.world_view.gui_input.emit(event)

func admission_serial() -> int:
	return int(f.bench.object_shard_m4_port._next_action)

func admitted_count() -> int:
	return int(f.bench.object_shard_edit_diagnostics().get("counts",{}).get("admitted",0))

func tap(position: Vector2, which: int = MOUSE_BUTTON_LEFT) -> bool:
	var before: int = admitted_count()
	press(position,which)
	var admitted: bool = await f.until(func(): return admitted_count()>before,
		"actual pointer gesture receives a fresh bounded native admission")
	release()
	if not admitted: return false
	return await drain()

func drain() -> bool:
	var action_id: int = admission_serial()
	var port_generation: int = f.bench.object_shard_m4_port.generation
	var owner: Dictionary = f.runtime().capabilities.duplicate(true)
	var completed: bool = await f.until(func(): return _action_completed(action_id,port_generation,owner),
		"selected native action retains its actual geometry and coherent presentation completion")
	if not completed:
		print("M4_INPUT_COMPLETION_WAIT ",JSON.stringify({"action_id":action_id,"port_generation":port_generation,
			"last_presented_action":f.bench._object_shard_last_presented_action,
			"current_port_generation":f.bench.object_shard_m4_port.generation,
			"editing":f.bench.object_shard_edit_diagnostics()}))
	return completed

func _action_completed(action_id: int, port_generation: int, owner: Dictionary) -> bool:
	var port: RefCounted = f.bench.object_shard_m4_port
	var runtime: RefCounted = f.runtime()
	if port.generation!=port_generation or port.pending_count()!=0 or not port.held_reason().is_empty(): return false
	for key: String in ["native_instance_id","world_generation","session","owner_epoch","shard_session","world_incarnation","transport_generation"]:
		if runtime.capabilities.get(key)!=owner.get(key): return false
	# Main latches this only while genuine physics/geometry readiness and the
	# exact later publication agree. It remains true when the next legitimate
	# interval starts before this lower-cadence test callback can observe Ready.
	if f.bench._object_shard_last_presented_action<action_id or not f.coherent() \
			or not port.latest_edit_presented(runtime.publication,runtime.capabilities): return false
	var native: Dictionary = {}
	for terminal: Dictionary in port.results:
		if int(terminal.get("action_id",-1))!=action_id or int(terminal.get("port_generation",-1))!=port_generation: continue
		if terminal.get("outcome")!="Applied" or terminal.get("ok")!=true: return false
		native = terminal.get("native_receipt",{})
		break
	if native.is_empty() or native.get("ok")!=true: return false
	for shard: Dictionary in runtime.publication.get("shards",[]):
		if shard.get("geometry_pending",false): return false
	if native.get("domain","")=="terrain": return true
	var id: int = int(native.get("owner",-1))
	if runtime.bridge.bodies.has(id):
		var installed: Dictionary = runtime.bridge.bodies[id]
		return int(installed.body_generation)==int(native.get("body_generation",-1)) \
			and int(installed.geometry_revision)>=int(native.get("geometry_revision",0))
	# Complete removal is a real installed retirement. The existing native
	# capacity policy can retain an empty Draining storage slot until the next
	# semantic tick, so owns_inventory alone is not a nonempty-material census.
	for shard: Dictionary in runtime.publication.get("shards",[]):
		if int(shard.id)!=id: continue
		if shard.get("has_body",false) or int(shard.get("body_generation",-1))!=int(native.get("body_generation",-1)) \
				or int(shard.get("geometry_revision",0))<int(native.get("geometry_revision",0)): return false
		for material: int in shard.get("materials",PackedByteArray()):
			if material!=0: return false
	return true

func install_panel(kind: String = "panel") -> bool:
	if not await f.pause(): return false
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1]]
	if kind=="sleeping":
		authored.edits.append_array([[140,440,48,12,7],[162,452,4,12,1]])
	elif kind=="tiny":
		authored.edits.append_array([[140,440,12,12,7],[144,452,4,12,1]])
	else:
		authored.edits.append_array([[140,392,64,48,7],[170,440,4,24,1]])
	if not f.expect(f.bench.apply(authored),"fresh "+kind+" authored construction admitted"): return false
	if not await f.until(f.installed,"fresh "+kind+" ordinary World installed"): return false
	f.bench.set_camera(2)
	f.play()
	if not await f.until(func(): return f.runtime().owns_terrain(),"new ordinary structural owner attached"): return false
	return await f.pause()

func source_target(position: Vector2i) -> Dictionary:
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var cell: Vector2i = position-Vector2i(int(shard.origin_x),int(shard.origin_y))
		if cell.x<0 or cell.y<0 or cell.x>=int(shard.width) or cell.y>=int(shard.height): continue
		var index: int = cell.y*int(shard.width)+cell.x
		if int(shard.roles[index])!=1: continue
		var transform := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		var point: Vector2i = Vector2i((transform*(Vector2(cell)+Vector2(0.5,0.5))).floor())
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var target: Dictionary = f.runtime().visible_target(point+Vector2i(x,y))
				if target.get("owner")==int(shard.id) and target.get("cell")==index: return target
	return {}

func owned_material() -> Dictionary:
	# Stable capture-space coordinates permit deterministic weathering comparison
	# across fresh owner sessions without equating their owner IDs or poses.
	var result: Dictionary = {}
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		for index: int in range(shard.materials.size()):
			if int(shard.materials[index])==0: continue
			var at := Vector2i(int(shard.origin_x)+index%int(shard.width),int(shard.origin_y)+index/int(shard.width))
			result[str(at)] = int(shard.materials[index])
	return result

func release_during_physical_transaction() -> Dictionary:
	# A completed Rapier interval still owns its semantic boundary until the
	# native tick finishes. Fast rendered schedules can expose that phase while
	# consuming every per-segment receipt between process_frame observations.
	# Both branches require actual unfinished production work, never just Play.
	var witness: Dictionary = {}
	var observed: bool = await f.until(func():
		var state: Dictionary = f.diagnostics()
		var fence: Dictionary = state.get("worker_profile",{}).get("motion_fence",{})
		var segment_pending: bool = f.runtime()._interval_active and int(state.get("pending_serial",0))>0
		var native_tick_pending: bool = str(state.get("phase",""))=="AwaitingCompletedNativeTick" \
			and bool(fence.get("tick_due",false)) and bool(fence.get("owner_busy",false))
		if f.host.paused or not str(state.get("held_reason","")).is_empty() \
			or not (segment_pending or native_tick_pending): return false
		witness.assign({"scope":"actual unfinished physical/semantic transaction at pointer release",
			"kind":"segment_receipt_pending" if segment_pending else "completed_interval_native_tick_pending",
			"phase":state.get("phase"),"interval_active":f.runtime()._interval_active,
			"pending_serial":state.get("pending_serial"),"pending_kind":state.get("pending_kind"),
			"motion_lease":state.get("motion_lease"),"native_tick":state.get("native_tick"),
			"physical_intervals":state.get("physical_intervals"),"world_generation":state.get("world_generation"),
			"native_instance_id":state.get("native_instance_id"),"motion_fence":fence.duplicate(true)})
		return true,
		"slice release is captured during an actual unfinished physical/semantic transaction")
	if not observed: return {}
	witness.release_usec = Time.get_ticks_usec()
	release()
	return witness
