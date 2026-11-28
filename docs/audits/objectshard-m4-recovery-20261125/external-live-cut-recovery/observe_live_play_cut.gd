extends SceneTree

# NEW external observer after executor loss. This is not a reconstruction of
# the previously executed observer bytes. The packaged application is unchanged.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const EXPECTED_SOURCE: String = "5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a"
const EXPECTED_TREE: String = "51ff1e6a0949dff3b2b17cdca7a40d4943b05f78"
const SCHEMA: String = "objectshard-m4-live-play-cut-recovery-v1"

class BoundarySampler:
	extends Node
	var callback: Callable
	func _process(_delta: float) -> void:
		callback.call()

var f: RefCounted
var output: String = ""
var nonce: String = ""
var evidence: Dictionary = {}
var early: BoundarySampler
var late: BoundarySampler
var armed: bool = false
var attempted: bool = false
var delivered: bool = false
var minimum_cut_tick: int = 0
var owner: int = 0
var survivor_cell: int = -1
var survivor_local: Vector2 = Vector2.ZERO
var target: Dictionary = {}
var before_results: int = 0
var early_state: Dictionary = {}
var geometry_pair: Dictionary = {}
var continued_from: int = 0
var continuing_observation: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--nonce="): nonce = arg.trim_prefix("--nonce=")
	_run.call_deferred()

func _shard() -> Dictionary:
	for row: Dictionary in f.runtime().publication.get("shards", []):
		if int(row.id) == owner and row.get("owns_inventory", false): return row
	return {}

func _shard_summary() -> Dictionary:
	var shard: Dictionary = _shard()
	if shard.is_empty(): return {}
	var value: Dictionary = {}
	for key: String in ["id","generation","body_generation","geometry_revision","applied_physics_revision",
		"geometry_pending","pose_serial","material_revision","width","height","mass","com_x","com_y","inertia","lifecycle"]:
		value[key] = shard.get(key)
	value.selected_material = int(shard.materials[int(target.cell)])
	value.selected_incarnation = int(shard.incarnations[int(target.cell)])
	value.survivor_material = int(shard.materials[survivor_cell])
	value.survivor_role = int(shard.roles[survivor_cell])
	value.survivor_incarnation = int(shard.incarnations[survivor_cell])
	return value

func _physics() -> Dictionary:
	if owner <= 0 or not f.runtime().bridge.bodies.has(owner): return {}
	var row: Dictionary = f.runtime().bridge.bodies[owner]
	var rid: RID = row.rid
	var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var com: Vector2 = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
	return {"owner":owner, "rid":rid.get_id(), "generation":int(row.generation), "body_generation":int(row.body_generation),
		"physical_step":int(f.runtime().physical_steps),
		"bridge_step":int(f.runtime().bridge.steps), "native_tick":f.tick(),
		"geometry_revision":int(row.geometry_revision), "last_geometry_step":int(row.last_geometry_step),
		"x":pose.origin.x, "y":pose.origin.y, "rotation":pose.get_rotation(),
		"vx":velocity.x, "vy":velocity.y,
		"angular_velocity":float(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)),
		"com_x":com.x, "com_y":com.y, "mass":float(PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_MASS)),
		"inertia":float(PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_INERTIA)),
		"shape_count":PhysicsServer2D.body_get_shape_count(rid),
		"sleeping":bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)),
		"paused":f.host.paused}

func _point_velocity(value: Dictionary) -> Vector2:
	var pose := Transform2D(float(value.rotation), Vector2(float(value.x), float(value.y)))
	var offset: Vector2 = pose.basis_xform(survivor_local - Vector2(float(value.com_x), float(value.com_y)))
	return Vector2(float(value.vx), float(value.vy)) + Vector2(-offset.y, offset.x) * float(value.angular_velocity)

func _pointer_local(position: Vector2i) -> Vector2:
	var area: Rect2 = f.host.view_content_rect()
	return area.position + (Vector2(position) - Vector2(f.host.camera_origin.floor()) + Vector2(0.5,0.5)) \
		* area.size / Vector2(f.host.current_view_size)

func _pointer(position: Vector2i, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = _pointer_local(position)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	f.host.world_view.gui_input.emit(event)

func _before_main() -> void:
	if attempted and geometry_pair.is_empty(): early_state = _physics()

func _after_main() -> void:
	if armed and not attempted: _try_click()
	if not attempted: return
	var actual: Dictionary = _physics()
	if geometry_pair.is_empty() and not early_state.is_empty() and not actual.is_empty() \
		and int(actual.geometry_revision) != int(early_state.geometry_revision):
		geometry_pair = {"before":early_state.duplicate(true), "after":actual.duplicate(true),
			"survivor_cell":survivor_cell, "survivor_local":[survivor_local.x, survivor_local.y]}
	if not delivered and f.bench.object_shard_m4_port.results.size() == before_results + 1 \
		and f.runtime().physics_ready() and f.coherent() \
		and f.runtime().frame.get("publication_sequence") == f.runtime().publication.get("publication_sequence"):
		var terminal: Dictionary = f.bench.object_shard_m4_port.results.back().duplicate(true)
		var native: Dictionary = terminal.get("native_receipt", {})
		if terminal.get("outcome") != "Applied" or int(f.runtime().publication.get("next_transaction",0)) > int(native.get("transaction_id",0)):
			evidence.terminal = terminal
			evidence.delivered = {"physics":actual, "native_shard":_shard_summary(),
				"publication":f.runtime().visible_observation(), "next_transaction":f.runtime().publication.get("next_transaction"),
				"native_tick":f.tick(), "paused":f.host.paused}
			delivered = true
			continued_from = f.tick()
	if delivered and continuing_observation.is_empty() and f.tick() >= continued_from + 8 \
		and not actual.is_empty() and not f.host.paused:
		continuing_observation = actual.duplicate(true)

func _try_click() -> void:
	if f.host.paused or f.tick() < minimum_cut_tick or f.body_count() != 1 \
		or not f.runtime().physics_ready() or not f.coherent() \
		or f.runtime().frame.get("publication_sequence") != f.runtime().publication.get("publication_sequence") \
		or f.bench.object_shard_m4_port.pending_count() != 0: return
	var found: Dictionary = f.moving_target(7)
	if found.is_empty(): return
	owner = int(found.owner)
	var actual: Dictionary = _physics()
	if actual.is_empty() or bool(actual.sleeping) \
		or Vector2(float(actual.vx),float(actual.vy)).length() <= 5.0 \
		or absf(float(actual.angular_velocity)) <= 0.05: return
	var shard: Dictionary = _shard()
	var materials: PackedByteArray = shard.get("materials", PackedByteArray())
	var roles: PackedInt32Array = shard.get("roles", PackedInt32Array())
	survivor_cell = -1
	for cell: int in range(int(found.cell)+1,materials.size()):
		if int(materials[cell]) == 7 and int(roles[cell]) == 1:
			survivor_cell = cell
			break
	if survivor_cell < 0: return
	survivor_local = Vector2(float(survivor_cell % int(shard.width))+0.5,
		floorf(float(survivor_cell)/float(shard.width))+0.5)
	target = found.duplicate(true)
	before_results = f.bench.object_shard_m4_port.results.size()
	f.bench._tool.select(5)
	f.bench._tool.item_selected.emit(5)
	evidence.dispatch = {"target":target.duplicate(true), "observation":f.runtime().visible_observation().duplicate(true),
		"physics":actual, "native_tick":f.tick(), "paused":f.host.paused,
		"pointer_local":[_pointer_local(target.position).x,_pointer_local(target.position).y],
		"roundtrip":f.host.view_pixel_from_local_point(_pointer_local(target.position)),
		"mode":f.bench._tool.selected, "survivor_cell":survivor_cell,
		"survivor_local":[survivor_local.x,survivor_local.y], "survivor_incarnation":int(shard.incarnations[survivor_cell]),
		"source_width":int(shard.width), "source_height":int(shard.height)}
	attempted = true
	armed = false
	_pointer(target.position,true)
	evidence.dispatch.pending_after_press = f.bench.object_shard_m4_port.pending_count()
	evidence.dispatch.results_after_press = f.bench.object_shard_m4_port.results.size() - before_results
	_pointer(target.position,false)
	evidence.dispatch.drag_after_release = f.bench._drag_button

func _runtime_identity() -> bool:
	var path: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	if not f.expect(not path.is_empty() and FileAccess.file_exists(path), "exact packaged manifest is provided"): return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not f.expect(manifest is Dictionary and manifest.get("source_commit") == EXPECTED_SOURCE \
		and manifest.get("source_tree") == EXPECTED_TREE, "package names the exact frozen application and tree"): return false
	var native: Dictionary = manifest.get("native", {})
	var rapier: Dictionary = manifest.get("rapier", {})
	var package_root: String = path.get_base_dir()
	var native_sha: String = FileAccess.get_sha256(package_root.path_join(str(native.get("path",""))))
	var rapier_sha: String = FileAccess.get_sha256(package_root.path_join(str(rapier.get("path",""))))
	var script_path: String = get_script().resource_path
	var engine_sha: String = FileAccess.get_sha256(OS.get_executable_path())
	var engine_expected: String = str(manifest.get("files_sha256",{}).get(OS.get_executable_path().get_file(),""))
	evidence.identity = {"manifest_path":path, "manifest_sha256":FileAccess.get_sha256(path),
		"application_source":manifest.source_commit, "application_tree":manifest.get("source_tree"),
		"native_path":native.get("path"), "native_sha256":native_sha, "rapier_path":rapier.get("path"), "rapier_sha256":rapier_sha,
		"engine_path":OS.get_executable_path(), "engine_sha256":engine_sha,
		"observer_path":script_path, "observer_sha256":FileAccess.get_sha256(script_path),
		"platform":OS.get_name(), "display_driver":DisplayServer.get_name(), "process_id":OS.get_process_id(),
		"scope":"External runner independently verifies the complete immutable package before and after this process."}
	return f.expect(native_sha.length() == 64 and native_sha == native.get("sha256") \
		and rapier_sha.length() == 64 and rapier_sha == rapier.get("sha256") \
		and engine_sha.length() == 64 and engine_sha == engine_expected \
		and str(evidence.identity.observer_sha256).length() == 64,
		"actual packaged engine/native/Rapier and new observer bytes have explicit identities")

func _run() -> void:
	f = Fixture.new(self)
	if not f.expect(nonce.length() >= 16 and not output.is_empty() \
		and not OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR").is_empty(), "external witness has nonce, receipt and raw artifact destinations") \
		or not f.expect(OS.get_environment("CYBERSAND_SOURCE_REVISION") == EXPECTED_SOURCE, "launched source is the frozen candidate"):
		await _finish(); return
	if not _runtime_identity() or not await f.open("tower") or not await f.cut_supports("tower"):
		await _finish(); return
	f.play()
	if not await f.until(func(): return f.body_count() == 1, "ordinary support removal detaches one actual material body"):
		await _finish(); return
	evidence.inventory_before = await f.validate_quantity_ledger()
	if not f.failures.is_empty(): await _finish(); return
	early = BoundarySampler.new()
	early.callback = _before_main
	early.process_priority = f.host.process_priority - 1000
	root.add_child(early)
	late = BoundarySampler.new()
	late.callback = _after_main
	late.process_priority = f.host.process_priority + 1000
	root.add_child(late)
	evidence.observer_priorities = {"before":early.process_priority,"main":f.host.process_priority,"after":late.process_priority}
	minimum_cut_tick = f.tick() + 60
	armed = true
	f.play()
	if not await f.until(func(): return attempted, "one mounted live Cut is attempted on a translating and rotating Tower"):
		await _finish(); return
	if not f.expect(not bool(evidence.dispatch.paused) and int(evidence.dispatch.mode) == 5 \
		and int(evidence.dispatch.pending_after_press) == 1 and int(evidence.dispatch.results_after_press) == 0,
		"mounted press queues exactly one genuine pending edit during Play"):
		await _finish(); return
	if not await f.until(func(): return delivered, "real native edit receipt and its current coherent geometry are delivered during Play"):
		await _finish(); return
	var native: Dictionary = evidence.terminal.get("native_receipt", {})
	if not f.expect(evidence.terminal.get("outcome") == "Applied" and native.get("accepted",false) \
		and native.get("operation") == "erase" and native.get("source_target",{}) == target,
		"Applied native transaction retains the complete exact displayed source-cell witness"):
		await _finish(); return
	if not f.expect(not geometry_pair.is_empty(), "early/late observers captured the actual geometry transition"):
		await _finish(); return
	var old: Dictionary = geometry_pair.before
	var changed: Dictionary = geometry_pair.after
	var same_step: bool = int(old.physical_step) == int(changed.physical_step) \
		and int(old.bridge_step) == int(changed.bridge_step) and old.rid == changed.rid \
		and int(changed.last_geometry_step) == int(changed.bridge_step)
	f.expect(same_step, "geometry replacement is bracketed at the same actual physical step and RID")
	f.expect(int(old.geometry_revision) == int(target.geometry_revision) \
		and int(native.get("geometry_revision",-1)) == int(changed.geometry_revision),
		"actual geometry transition binds the exact selected source revision and resulting native transaction")
	f.expect(int(old.generation) == int(target.generation) and int(changed.generation) == int(target.generation) \
		and int(old.body_generation) == int(target.body_generation) and int(changed.body_generation) == int(target.body_generation),
		"both actual geometry samples retain the dispatched native body incarnation")
	f.expect(not bool(old.paused) and not bool(changed.paused), "same-step geometry observation occurs while Play")
	var point_before: Vector2 = _point_velocity(old)
	var point_after: Vector2 = _point_velocity(changed)
	var residual: float = point_before.distance_to(point_after)
	geometry_pair.point_velocity_before = [point_before.x,point_before.y]
	geometry_pair.point_velocity_after = [point_after.x,point_after.y]
	geometry_pair.point_velocity_residual = residual
	f.expect(same_step and is_finite(residual) and residual <= 0.001,
		"surviving material point preserves its velocity across same-step COM and geometry installation")
	f.expect(Vector2(float(old.x),float(old.y)).distance_to(Vector2(float(changed.x),float(changed.y))) <= 0.0001 \
		and absf(wrapf(float(changed.rotation)-float(old.rotation),-PI,PI)) <= 0.0001 \
		and absf(float(changed.angular_velocity)-float(old.angular_velocity)) <= 0.0001,
		"geometry change preserves actual origin pose and angular velocity")
	f.expect(int(changed.geometry_revision) > int(old.geometry_revision) and int(changed.shape_count) > 0 \
		and absf(float(old.mass)-float(changed.mass)-1.0) <= 0.0001,
		"one structural cell debit changes actual collider geometry and unit mass")
	var shown: Dictionary = evidence.delivered.native_shard
	f.expect(int(shown.get("generation",-1)) == int(target.generation) \
		and int(shown.get("body_generation",-1)) == int(target.body_generation) \
		and int(shown.get("width",-1)) == int(evidence.dispatch.source_width) \
		and int(shown.get("height",-1)) == int(evidence.dispatch.source_height) \
		and int(shown.get("survivor_incarnation",-1)) == int(evidence.dispatch.survivor_incarnation),
		"delivered owner, stable source lattice and surviving material incarnation match the dispatched witness")
	f.expect(int(shown.get("geometry_revision",-1)) == int(changed.geometry_revision) \
		and int(shown.get("applied_physics_revision",-1)) == int(changed.geometry_revision) \
		and not shown.get("geometry_pending",true) and not bool(evidence.delivered.paused),
		"native geometry ACK and actual installed revision agree while Play")
	f.expect(int(shown.selected_material) == 0 and int(shown.survivor_material) == 7 \
		and int(shown.survivor_role) == 1, "exact selected cell is gone and the witnessed surviving Wood cell remains")
	if not await f.until(func(): return not continuing_observation.is_empty(), "actual motion continues for eight native ticks after delivered edit"):
		await _finish(); return
	var previous: Dictionary = evidence.delivered.physics
	f.expect(int(continuing_observation.physical_step) > int(previous.physical_step) \
		and not bool(continuing_observation.sleeping) \
		and Vector2(float(previous.x),float(previous.y)).distance_to(Vector2(float(continuing_observation.x),float(continuing_observation.y))) > 0.01 \
		and absf(wrapf(float(continuing_observation.rotation)-float(previous.rotation),-PI,PI)) > 0.0001,
		"genuine Rapier translation and rotation continue after the live edit")
	evidence.continued_motion = continuing_observation
	evidence.geometry_transition = geometry_pair
	evidence.inventory_after = await f.validate_quantity_ledger()
	if f.failures.is_empty():
		var counts_before: PackedInt64Array = evidence.inventory_before.total_material_counts
		var counts_after: PackedInt64Array = evidence.inventory_after.total_material_counts
		var mismatches: Array[Dictionary] = []
		for material: int in range(1,256):
			var expected: int = int(counts_before[material]) - (1 if material == 7 else 0)
			if int(counts_after[material]) != expected:
				mismatches.append({"material":material,"before":counts_before[material],"after":counts_after[material],"expected":expected})
		evidence.census_mismatches = mismatches
		f.expect(mismatches.is_empty(), "independent raw World plus every carrier proves exactly one Wood debit and no other material change")
		f.expect(f.bench.object_shard_m4_port.results.size() == before_results+1 \
			and f.bench.object_shard_m4_port.pending_count() == 0, "single released click creates exactly one terminal edit")
		f.validate_physics()
	await _finish()

func _finish() -> void:
	armed = false
	if early != null: early.set_process(false)
	if late != null: late.set_process(false)
	if f != null:
		f.validate_display()
		evidence.display_coherence = f.display_witness()
		evidence.inventory_witnesses = f.inventory_witnesses
		if not geometry_pair.is_empty(): evidence.geometry_transition = geometry_pair
		await f.close()
	if early != null: early.queue_free()
	if late != null: late.queue_free()
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE) if not output.is_empty() else null
	if f != null: f.expect(file != null, "external receipt output can be retained")
	var result: Dictionary = {"schema":SCHEMA,"nonce":nonce,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":f.checks,"failures":f.failures,"evidence":evidence,
		"scope":"NEW external headless/graphical event observer against unchanged packaged application; actual native/Rapier motion, mounted live Cut, same-step material-point velocity and independent raw census; physical owner presentation remains HOLD"}
	var text: String = JSON.stringify(result)
	if file != null:
		file.store_string(text+"\n")
		file.close()
	print(text)
	quit(0 if f.failures.is_empty() else 1)
