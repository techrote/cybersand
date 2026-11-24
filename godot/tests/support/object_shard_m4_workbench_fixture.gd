extends RefCounted

# Tests drive the ordinary UI/worker path. No test reads the live native World
# from Main and no fixture supplies a synthetic pose or detached material body.
const Scenes = preload("res://scripts/object_shard_workbench_scenes.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var tree: SceneTree
var host: Control
var bench: Control
var checks: int = 0
var failures: Array[String] = []
var between_callback_observations: int = 0
var draw_observations: int = 0
var foreign_draw_callbacks: int = 0
var incoherent_observations: int = 0
var incoherent_examples: Array[Dictionary] = []

func _init(value: SceneTree) -> void:
	tree = value

func expect(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		push_error("M4_WORKBENCH: " + message)
	else:
		print("M4_WORKBENCH PASS: " + message.get_slice(" / ",0))
	return value

func runtime() -> Variant:
	return host.object_shard_m4_runtime if host != null else null

func diagnostics() -> Dictionary:
	return runtime().diagnostics() if runtime() != null else {}

func frame() -> Dictionary:
	return runtime().frame if runtime() != null else {}

func tick() -> int:
	return int(frame().get("tick", 0))

func body_count() -> int:
	return runtime().bridge.bodies.size() if runtime() != null else 0

func installed() -> bool:
	return host != null and host.shared_workbench != null and \
		not host.shared_workbench.applied.is_empty() and not host.shared_workbench.busy() and \
		host.pending_microscenario_apply.is_empty() and host.latest_snapshot != null

func until(predicate: Callable, message: String, timeout_ms: int = -1) -> bool:
	var allowance: int = Watchdogs.milliseconds("operation_seconds") if timeout_ms < 0 else timeout_ms
	var deadline: int = Time.get_ticks_msec() + allowance
	var next_diagnostic: int = Time.get_ticks_msec()+5000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if runtime() != null and not str(diagnostics().get("held_reason", "")).is_empty(): break
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec() >= next_diagnostic:
			var state: Dictionary = diagnostics()
			print("M4_WORKBENCH_WAIT ",JSON.stringify({"waiting":message,"phase":state.get("phase"),
				"native_tick":state.get("native_tick"),"body_count":state.get("body_count"),
				"held_reason":state.get("held_reason"),"pending_kind":state.get("pending_kind"),
				"physical_intervals":state.get("physical_intervals"),"motion_lease":state.get("motion_lease"),
				"last_motion_permit":state.get("last_motion_permit"),"last_receipt":state.get("receipt"),
				"actor_tick":host.physical_actor_session.tick if host != null and host.physical_actor_session != null else -1,
				"main_wait_sample":host._workbench_wait_sample if host != null else -1,
				"native_completed_sample":host.latest_snapshot.lab_context.get("workbench_completed_sample",-1) if host != null and host.latest_snapshot != null else -1}))
			next_diagnostic = Time.get_ticks_msec()+5000
		await tree.process_frame
	return expect(bool(predicate.call()), message + " / " + str(diagnostics()))

func open(scene_id: String) -> bool:
	if not tree.process_frame.is_connected(_observe_callback): tree.process_frame.connect(_observe_callback)
	if DisplayServer.get_name() != "headless" and not RenderingServer.frame_post_draw.is_connected(_observe_draw):
		RenderingServer.frame_post_draw.connect(_observe_draw)
	tree.set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	tree.root.add_child(host)
	if not await until(installed, "ordinary Workbench installed"): return false
	bench = host.shared_workbench
	if not expect(bench.load_object_shard_scene(scene_id), "load ordinary authored " + scene_id): return false
	if not await until(installed, "authored scene owner committed"): return false
	bench.set_camera(2)
	if host.paused:
		if not expect(bench.toggle_pause(), "Play ordinary owner for initial native tick"): return false
	if not await until(func(): return runtime() != null and diagnostics().get("attached", false) \
		and bool(diagnostics().get("physics_ready", false)), "native owner plus existing Rapier bound"): return false
	# Godot RefCounted instance IDs use the high unsigned bit, so their signed
	# GDScript representation can be negative. Zero alone is the null identity.
	expect(int(diagnostics().get("native_instance_id", 0)) != 0, "native owner identity present")
	expect(int(diagnostics().get("shared_main_space_id", 0)) == host.rapier_bridge.shared_space().get_id(),
		"shards use the ordinary Main Rapier space")
	return true

func _observe_callback() -> void:
	_observe_publication(false)

func _observe_draw() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		foreign_draw_callbacks += 1
		return
	_observe_publication(true)

func _observe_publication(rendered: bool) -> void:
	if host == null or not is_instance_valid(host) or runtime() == null or runtime().publication.is_empty(): return
	if rendered: draw_observations += 1
	else: between_callback_observations += 1
	if coherent(): return
	incoherent_observations += 1
	if incoherent_examples.size() < 8:
		incoherent_examples.append({"rendered":rendered,"phase":runtime().phase,
			"publication":runtime().visible_observation(),
			"uploaded_world_generation":host.last_uploaded_world_generation,
			"uploaded_world_revision":host.last_uploaded_revision,
			"uploaded_render_serial":host.last_uploaded_render_snapshot_serial})

func display_witness() -> Dictionary:
	return {"between_callback_observations":between_callback_observations,"draw_observations":draw_observations,
		"foreign_draw_callbacks":foreign_draw_callbacks,"incoherent_observations":incoherent_observations,
		"examples":incoherent_examples,"scope":"actual uploaded World and displayed native shard publication identity at every observed callback; frame_post_draw is renderer submission, not physical monitor presentation"}

func validate_display() -> void:
	expect(between_callback_observations > 0,"coherent ordinary presentation was actually observed between Main callbacks")
	expect(incoherent_observations == 0,"every observed displayed shard and World upload use one generation/revision/render identity / "+str(incoherent_examples))
	if DisplayServer.get_name() != "headless":
		expect(draw_observations > 0 and foreign_draw_callbacks == 0,"actual renderer submissions have Main-thread coherent publication witnesses")

func cut_supports(scene_id: String, retained_cap_rows: int = 0) -> bool:
	var manifest: Dictionary = Scenes.manifest(scene_id)
	bench._brush.value = 3
	for rect: Rect2i in manifest.get("cut_rects", []):
		# Erase the complete lower stem. A horizontal notch alone leaves a
		# tall physical stump that legitimately catches the falling facade.
		# Radius-three stamps four rows apart cover each actual narrow post;
		# their rounded ends preserve the declared upper cap and floor.
		var start_y: int = rect.position.y + retained_cap_rows + 3
		var last_y: int = rect.end.y - 4
		var centers: Array[int] = []
		for y: int in range(start_y,last_y+1,4): centers.append(y)
		if centers.is_empty() or centers.back() != last_y: centers.append(last_y)
		for y: int in centers:
			var center := Vector2i(rect.position.x + rect.size.x/2,y)
			if not expect(bench.paint(center, 0), "ordinary Erase removes lower support at " + str(center)): return false
			await tree.process_frame
	return true

func advance(count: int, message: String = "native semantic progression") -> bool:
	var target: int = tick() + count
	return await until(func(): return tick() >= target, message)

func pause() -> bool:
	if not host.paused:
		if not expect(bench.toggle_pause(), "ordinary Pause accepted"): return false
	return await until(func(): return bool(diagnostics().get("physics_ready", false)),
		"in-flight physical interval acknowledged before pause witness")

func play() -> bool:
	if host.paused: return expect(bench.toggle_pause(), "ordinary Resume accepted")
	return true

func coherent() -> bool:
	if runtime() == null or runtime().publication.is_empty(): return false
	var value: Dictionary = runtime().publication
	return int(value.get("world_generation", -1)) == int(host.last_uploaded_world_generation) and \
		int(value.get("world_revision", -1)) == int(host.last_uploaded_revision) and \
		int(value.get("render_serial", -1)) == int(host.last_uploaded_render_snapshot_serial)

func whole_canvas_coherent() -> bool:
	return coherent() and host.image != null and host.image.get_size() == Vector2i(512,512)

func material_count(material: int) -> int:
	# The uploaded ordinary native cell image is an independent inventory witness.
	# Match the visible shard publication before counting both exclusive owners.
	if not coherent() or host.image == null: return -1
	var bytes: PackedByteArray = host.image.get_data()
	var channels: int = bytes.size() / (512 * 512)
	if channels not in [1, 2, 4] or bytes.size() != 512 * 512 * channels: return -1
	var total: int = 0
	for offset: int in range(0, bytes.size(), channels):
		if int(bytes[offset]) == material: total += 1
	for shard: Dictionary in runtime().publication.get("shards", []):
		if not shard.get("owns_inventory", false): continue
		for value: int in shard.get("materials", PackedByteArray()):
			if value == material: total += 1
	return total

func validate_quantity_ledger() -> void:
	if not expect(whole_canvas_coherent(),"independent inventory sees a complete coherent ordinary cell image"): return
	var bytes: PackedByteArray = host.image.get_data()
	var channels: int = bytes.size()/(512*512)
	if not expect(channels in [1,2,4],"native image has admitted material channel layout"): return
	var counted: PackedInt64Array = PackedInt64Array()
	counted.resize(256)
	for at: int in range(0,bytes.size(),channels): counted[int(bytes[at])] += 1
	var ledger: PackedInt64Array = runtime().publication.get("world_material_counts",PackedInt64Array())
	if not expect(ledger.size()>43,"actual World quantity ledger is copied independently of shard accounting"): return
	for material: int in [2,3,6,7,43]:
		expect(int(ledger[material]) == int(counted[material]),"ordinary image agrees with independent World ledger for material "+str(material))

func moving_target(material: int = 7, internal_air: int = 0, unignited_only: bool = false) -> Dictionary:
	if not coherent(): return {}
	for shard: Dictionary in runtime().publication.get("shards", []):
		if not shard.get("owns_inventory", false): continue
		var materials: PackedByteArray = shard.get("materials", PackedByteArray())
		var roles: PackedInt32Array = shard.get("roles", PackedInt32Array())
		var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		for index: int in range(materials.size()):
			if int(materials[index]) != material or int(roles[index]) != 1: continue
			if unignited_only and int(shard.states_b[index]) != 0: continue
			if internal_air > 0:
				var air: int = 0
				var source := Vector2i(index%int(shard.width),index/int(shard.width))
				for dy: int in range(-1,2):
					for dx: int in range(-1,2):
						if dx == 0 and dy == 0: continue
						var neighbour: Vector2i = source+Vector2i(dx,dy)
						if neighbour.x >= 0 and neighbour.y >= 0 and neighbour.x < int(shard.width) and neighbour.y < int(shard.height) \
							and int(materials[neighbour.y*int(shard.width)+neighbour.x]) == 0: air += 1
				if air < internal_air: continue
			var local := Vector2(float(index % int(shard.width)) + 0.5, floorf(float(index) / float(shard.width)) + 0.5)
			var position: Vector2i = Vector2i((transform * local).floor())
			var target: Dictionary = runtime().visible_target(position)
			if target.get("owner", -1) == int(shard.id) and target.get("cell", -1) == index:
				return target
	return {}

func ignite_exposed_wood(count: int = 4) -> Array[Dictionary]:
	var witnesses: Array[Dictionary] = []
	for i: int in range(count):
		var target: Dictionary = moving_target(7,3,true)
		if not expect(not target.is_empty(),"actual displayed Wood has at least three internal empty neighbours for native emission"): break
		var request: Dictionary = bench.object_shard_m4_action(target.position,"ignite",runtime().visible_observation(),target)
		if not expect(request.get("ok",false),"exposed moving Wood ignition queues through the ordinary worker"): break
		if not await until(func(): return bench.object_shard_m4_port.pending_count() == 0 and runtime().physics_ready() \
			and coherent() and int(owned_cell_state(int(target.owner),int(target.cell)).get("state_b",0))>0,
			"exact exposed Wood ignition receipt and source state are presented"): break
		var receipt: Dictionary = bench.object_shard_m4_port.results.back().duplicate(true)
		if not expect(receipt.get("outcome") == "Applied","actual native exposed Wood ignition applies"): break
		witnesses.append({"source":target,"before":owned_cell_state(int(target.owner),int(target.cell)),"receipt":receipt})
	return witnesses

func owned_cell_state(owner: int, cell: int) -> Dictionary:
	for shard: Dictionary in runtime().publication.get("shards",[]):
		if int(shard.id) != owner or not shard.get("owns_inventory",false): continue
		if cell < 0 or cell >= shard.materials.size(): return {}
		return {"material":int(shard.materials[cell]),"state_a":int(shard.states_a[cell]),
			"state_b":int(shard.states_b[cell]),"incarnation":int(shard.incarnations[cell])}
	return {}

func validate_physics() -> void:
	var bodies: Array = diagnostics().get("physics", {}).get("bodies", [])
	for body: Dictionary in bodies:
		expect(is_finite(float(body.mass)) and float(body.mass) > 0.0, "finite positive actual Rapier mass")
		expect(is_finite(float(body.inertia)) and float(body.inertia) > 0.0, "finite positive actual Rapier inertia")
		expect(is_finite(float(body.com_x)) and is_finite(float(body.com_y)), "finite actual Rapier centre of mass")
		expect(int(body.shape_count) > 0, "actual Rapier collision shapes installed")
		var source: Dictionary = {}
		for shard: Dictionary in runtime().publication.get("shards",[]):
			if int(shard.id) == int(body.id): source = shard
		if not expect(not source.is_empty(),"actual Rapier body has one displayed native inventory owner"): continue
		expect(absf(wrapf(float(source.rotation)-float(body.backend_rotation),-PI,PI)) < 0.0001,
			"native accepted pose angle equals the actual Rapier RID transform")
		expect(Vector2(float(source.position_x),float(source.position_y)).distance_to(Vector2(float(body.x),float(body.y))) < 0.001,
			"native accepted pose translation equals the actual Rapier RID transform")
		# Recompute the declared unit-cell mass moments from owned material roles,
		# independently of the native mass/COM/inertia fields sent to Rapier.
		var positions: Array[Vector2] = []
		var sum: Vector2 = Vector2.ZERO
		for cell: int in range(source.roles.size()):
			if int(source.roles[cell]) not in [1,3]: continue
			var point := Vector2(float(cell%int(source.width))+0.5,floorf(float(cell)/float(source.width))+0.5)
			positions.append(point)
			sum += point
		if not expect(not positions.is_empty(),"physical mass has actual structural or cargo carriers"): continue
		var center: Vector2 = sum/float(positions.size())
		var inertia: float = 0.0
		for point: Vector2 in positions: inertia += (point-center).length_squared()+1.0/6.0
		expect(absf(float(body.mass)-float(positions.size())) < 0.001,"actual Rapier mass equals independent carrier count")
		expect(Vector2(float(body.com_x),float(body.com_y)).distance_to(center) < 0.001,"actual Rapier COM equals independent material centroid")
		expect(absf(float(body.inertia)-inertia) <= maxf(0.001,inertia*0.00001),"actual Rapier inertia equals independent cell-area moments")

func close() -> void:
	if tree.process_frame.is_connected(_observe_callback): tree.process_frame.disconnect(_observe_callback)
	if RenderingServer.frame_post_draw.is_connected(_observe_draw): RenderingServer.frame_post_draw.disconnect(_observe_draw)
	if host != null and is_instance_valid(host):
		host.queue_free()
		await tree.process_frame
		await tree.process_frame
	host = null
	bench = null
