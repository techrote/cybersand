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
	return int(diagnostics().get("body_count", 0))

func installed() -> bool:
	return host != null and host.shared_workbench != null and \
		not host.shared_workbench.applied.is_empty() and not host.shared_workbench.busy() and \
		host.pending_microscenario_apply.is_empty() and host.latest_snapshot != null

func until(predicate: Callable, message: String, timeout_ms: int = -1) -> bool:
	var allowance: int = Watchdogs.milliseconds("operation_seconds") if timeout_ms < 0 else timeout_ms
	var deadline: int = Time.get_ticks_msec() + allowance
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if runtime() != null and not str(diagnostics().get("held_reason", "")).is_empty(): break
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		await tree.process_frame
	return expect(bool(predicate.call()), message + " / " + str(diagnostics()))

func open(scene_id: String) -> bool:
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

func cut_supports(scene_id: String, retained_cap_rows: int = 0) -> bool:
	var manifest: Dictionary = Scenes.manifest(scene_id)
	bench._brush.value = 3
	for rect: Rect2i in manifest.get("cut_rects", []):
		var center: Vector2i = rect.position + rect.size / 2
		center.y += retained_cap_rows
		if not expect(bench.paint(center, 0), "ordinary Erase severs support at " + str(center)): return false
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

func moving_target(material: int = 7) -> Dictionary:
	if not coherent(): return {}
	for shard: Dictionary in runtime().publication.get("shards", []):
		if not shard.get("owns_inventory", false): continue
		var materials: PackedByteArray = shard.get("materials", PackedByteArray())
		var roles: PackedInt32Array = shard.get("roles", PackedInt32Array())
		var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		for index: int in range(materials.size()):
			if int(materials[index]) != material or int(roles[index]) != 1: continue
			var local := Vector2(float(index % int(shard.width)) + 0.5, floorf(float(index) / float(shard.width)) + 0.5)
			var position: Vector2i = Vector2i((transform * local).floor())
			var target: Dictionary = runtime().visible_target(position)
			if target.get("owner", -1) == int(shard.id) and target.get("cell", -1) == index:
				return target
	return {}

func validate_physics() -> void:
	var bodies: Array = diagnostics().get("physics", {}).get("bodies", [])
	for body: Dictionary in bodies:
		expect(is_finite(float(body.mass)) and float(body.mass) > 0.0, "finite positive actual Rapier mass")
		expect(is_finite(float(body.inertia)) and float(body.inertia) > 0.0, "finite positive actual Rapier inertia")
		expect(is_finite(float(body.com_x)) and is_finite(float(body.com_y)), "finite actual Rapier centre of mass")
		expect(int(body.shape_count) > 0, "actual Rapier collision shapes installed")

func close() -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
		await tree.process_frame
		await tree.process_frame
	host = null
	bench = null
