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
var inventory_witnesses: Array[Dictionary] = []

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
	if not await until(func(): return runtime() != null and diagnostics().get("attached", false),
		"native owner plus existing Rapier bound"): return false
	# While playing, Ready may exist only between Main's process callback and
	# the next physical callback. Low renderer cadence must not starve this
	# observation. Park the genuinely attached owner, then require its exact
	# native/physics/display barrier; callers explicitly choose when to Resume.
	if not await pause(): return false
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
	return await until(func(): return runtime().physics_ready() and coherent() \
		and not bench.busy() \
		and int(runtime().publication.get("publication_sequence",-1))==int(frame().get("publication_sequence",-2)) \
		and bench.object_shard_m4_port.pending_count()==0 \
		and not host.simulation_worker.paint_state().get("legacy_busy",true) \
		and host.simulation_worker.object_shard_owner_frame(int(frame().get("publication_sequence",-1))).is_empty(),
		"paused native, physical and latest displayed publications finish at one owner boundary")

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
	# For structural materials the ordinary image is an independent inventory
	# witness. Water presentation additionally projects native ballistic parcels;
	# validate_quantity_ledger obtains raw grid and quantity witnesses for Water.
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

func _retain_inventory_bytes(name: String, bytes: PackedByteArray) -> Dictionary:
	var directory: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if directory.is_empty(): return {"retained":false,"reason":"runner did not request raw artifact retention","bytes":bytes.size()}
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("inventory-%03d-"%inventory_witnesses.size()+name)
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not expect(file != null,"raw inventory witness artifact can be written"): return {"retained":false,"path":path}
	file.store_buffer(bytes)
	file.close()
	return {"retained":true,"path":path,"bytes":bytes.size(),"sha256":FileAccess.get_sha256(path)}

func validate_quantity_ledger() -> Dictionary:
	# Only this explicit paused diagnostic asks the exclusive native worker for
	# a full grid copy. Ordinary motion/snapshot traffic stays compact.
	if not await pause(): return {}
	var before_tick: int = tick()
	var before_steps: int = int(runtime().physical_steps)
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	var request: Dictionary = {}
	while Time.get_ticks_msec()<deadline:
		request = runtime().request_inventory_inspection()
		if request.get("ok",false): break
		await tree.process_frame
	if not expect(request.get("ok",false),"paused exact owner admits one bounded raw inventory inspection / "+str(request)): return {}
	var receipt: Dictionary = {}
	while Time.get_ticks_msec()<deadline:
		receipt = runtime().take_inventory_inspection(int(request.token))
		if not receipt.is_empty(): break
		await tree.process_frame
	if not expect(receipt.get("ok",false) and receipt.get("schema")=="objectshard-m4-inventory-inspection-v1",
		"exclusive native owner returns the source-bound raw inventory witness / "+str(receipt.get("outcome"))): return {}
	expect(tick()==before_tick and int(runtime().physical_steps)==before_steps,
		"explicit paused inventory read advances neither native chemistry nor physical time")
	expect(receipt.get("native_before",{})==receipt.get("native_after",{}) and not receipt.get("native_before",{}).is_empty(),
		"raw native identity remains unchanged throughout the complete owner inspection")
	var repeated: Dictionary = runtime().take_inventory_inspection(int(request.token))
	expect(not repeated.get("ok",false) and repeated.get("outcome")=="InventoryInspectionRetired",
		"copied inventory witness is consumed once and cannot be replayed as a new inspection")
	var source: Dictionary = receipt.get("source",{})
	var report: Dictionary = {"source":source.duplicate(true),"schema":"objectshard-m4-independent-inventory-v1",
		"scope":"raw native stored-material census plus owned carriers; independently scanned Water state/overfill and complete parcel sum; rendered parcel pixels are separate from stored grid inventory"}
	for key: String in ["world_generation","world_revision","publication_sequence","tick"]:
		expect(source.get(key)==runtime().publication.get(key),"raw inventory and displayed materials retain exact "+key)
	var snapshot: Dictionary = receipt.get("raw_snapshot",{})
	var raw: PackedByteArray = snapshot.get("world_materials",PackedByteArray())
	var extent: Vector2i = receipt.get("extent",Vector2i.ZERO)
	if not expect(extent==Vector2i(512,512) and raw.size()==extent.x*extent.y,
		"owner diagnostic copies every actual stored cell in the complete ordinary canvas"): return report
	var counts: PackedInt64Array = PackedInt64Array()
	counts.resize(256)
	for material: int in raw: counts[material] += 1
	var ledger: PackedInt64Array = snapshot.get("world_material_counts",PackedInt64Array())
	var ledger_mismatches: Array = []
	# Empty is canvas coverage, not an owned inventory entry in the native
	# quantity ledger. Every nonempty material is compared independently.
	for material: int in range(1,ledger.size()):
		if int(ledger[material])!=int(counts[material]): ledger_mismatches.append({"material":material,"raw":counts[material],"ledger":ledger[material]})
	expect(ledger.size()>43 and ledger_mismatches.is_empty(),"independently counted raw grid agrees with every native World material cell total / "+str(ledger_mismatches))
	report.raw_world_material_counts = counts
	report.raw_grid = _retain_inventory_bytes("stored-materials.bin",raw)
	var total: PackedInt64Array = counts.duplicate()
	total[0] = 0 # Empty contributes canvas coverage, never material inventory.
	var owners: Dictionary = {}
	report.owned_inventory = []
	for shard: Dictionary in snapshot.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var id: int = int(shard.id)
		expect(not owners.has(id),"one native inventory owner occupies each mutable body slot")
		owners[id] = true
		var materials: PackedByteArray = shard.materials
		var owned_water: int = 0
		for material: int in materials:
			if material != 0: total[material] += 1
			if material == 3: owned_water += 1
		expect(owned_water==0,"Water remains exclusively in native grid, overfill or parcel custody")
		var displayed: Dictionary = {}
		for item: Dictionary in runtime().publication.get("shards",[]):
			if int(item.id)==id: displayed=item
		expect(not displayed.is_empty() and displayed.get("generation")==shard.generation \
			and displayed.get("body_generation")==shard.body_generation and displayed.get("materials")==materials,
			"source-bound displayed body carries exactly the independently inspected native inventory")
		report.owned_inventory.append({"id":id,"generation":shard.generation,"body_generation":shard.body_generation,
			"materials":_retain_inventory_bytes("owner-%d-materials.bin"%id,materials)})
	report.total_material_counts = total
	var observation: Dictionary = receipt.get("water_observation",{})
	var spray: Dictionary = receipt.get("water_spray",{})
	var water: Dictionary = spray.get("water",{})
	var parcels: PackedFloat64Array = receipt.get("ballistic_parcels",PackedFloat64Array())
	expect(parcels.size()%5==0 and parcels.size()/5==int(spray.get("live",-1)) \
		and parcels.size()/5<=int(receipt.get("bounded_maximum_parcels",0)),"raw native parcel copy accounts for every live ballistic owner within its declared bound")
	var parcel_quantity: int = 0
	var parcel_pixels: Dictionary = {}
	var invalid_parcels: int = 0
	for offset: int in range(0,parcels.size(),5):
		if not (is_finite(parcels[offset]) and is_finite(parcels[offset+1]) \
			and is_finite(parcels[offset+2]) and is_finite(parcels[offset+3]) \
			and is_finite(parcels[offset+4]) and parcels[offset+4]>0 \
			and parcels[offset+4]==float(int(parcels[offset+4]))):
			invalid_parcels += 1
			continue
		parcel_quantity += int(parcels[offset+4])
		var point := Vector2i(floori(parcels[offset]),floori(parcels[offset+1]))
		if Rect2i(Vector2i.ZERO,extent).has_point(point):
			var at: int = point.y*extent.x+point.x
			if raw[at]==0: parcel_pixels[at] = true
	expect(invalid_parcels==0,"every actual parcel has finite kinematics and exact positive integer quantity")
	var scanned_quantity: int = int(observation.get("water_visible",-1))+int(observation.get("water_overfill",-1))+parcel_quantity
	expect(int(observation.get("water_integer",-1))==int(observation.get("water_visible",-2))+int(observation.get("water_overfill",-2)) \
		and parcel_quantity==int(spray.get("in_flight_quantity",-1)),"independent grid and parcel subtotals reconcile their separate native observations")
	expect(int(observation.get("water_cells",-1))==int(counts[3]),"independent stored-state Water scan agrees with the raw material census")
	expect(int(observation.get("water_visible",-1))==int(water.get("visible",-2)) \
		and int(observation.get("water_overfill",-1))==int(water.get("overfill",-2)) \
		and parcel_quantity==int(water.get("ballistic",-1)),"independent raw grid, pressure overfill and complete parcel sum agree with separate native quantity owners")
	expect(scanned_quantity==int(water.get("total",-1)) and scanned_quantity==int(water.get("expected",-2)),
		"independent total Water quantity closes against the actual native source and sink ledger")
	report.water = {"raw_state_scan":observation,"native_ledger":water,"parcel_count":parcels.size()/5,
		"independent_parcel_quantity":parcel_quantity,"independent_total_quantity":scanned_quantity,
		"parcel_material_pixels":parcel_pixels.size(),"raw_parcels_float64":_retain_inventory_bytes("parcels-float64.bin",parcels.to_byte_array())}
	var pixels: PackedByteArray = host.image.get_data()
	var channels: int = pixels.size()/(extent.x*extent.y)
	if expect(channels==2,"native RG8 image preserves material identity before ballistic presentation projection"):
		var projection_mismatches: Array = []
		for at: int in range(raw.size()):
			var expected: int = 3 if parcel_pixels.has(at) else int(raw[at])
			if int(pixels[at*channels])!=expected and projection_mismatches.size()<8:
				projection_mismatches.append({"x":at%extent.x,"y":at/extent.x,"raw":raw[at],"projected":expected,"rendered":pixels[at*channels]})
		expect(projection_mismatches.is_empty(),"ordinary material pixels equal the exact raw grid plus actual ballistic Water projection / "+str(projection_mismatches))
		report.presentation_projection_mismatches = projection_mismatches
	report.rendered_grid = _retain_inventory_bytes("rendered-rg8.bin",pixels)
	inventory_witnesses.append(report)
	return report

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
