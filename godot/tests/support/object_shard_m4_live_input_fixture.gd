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
	return await f.until(func(): return f.bench.object_shard_m4_port.pending_count()==0 \
		and f.runtime().physics_ready() and f.coherent() \
		and f.bench.object_shard_m4_port.latest_edit_presented(f.runtime().publication,f.runtime().capabilities),
		"native edit receipt, physical geometry and authoritative material publication finish together")

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
