extends SceneTree

# Actual ordinary Main/Workbench/one native World UI negative test.
# Running this with --objectshard-m4-workbench asserts M4 pointer tools cannot
# silently become ordinary terrain painting while native attachment is absent.
# No synthetic physics or second owner is constructed.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var bench: Control
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("OBJECTSHARD_M4_SCENE_REFUSAL: " + label)


func _ready_workbench() -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if host != null and host.shared_workbench != null:
			bench = host.shared_workbench
			if not bench.applied.is_empty() and not bench.busy() and host.latest_snapshot != null:
				return true
		await process_frame
	return false


func _pointer(button: int, selected: int) -> void:
	bench._tool.select(selected)
	# A synthetic event travels through the actual mounted ordinary input
	# handler, while the native World, worker and Rapier are genuine.
	var press := InputEventMouseButton.new()
	press.position = host.world_view.size / 2.0
	press.button_index = button
	press.pressed = true
	bench._world_input(press)
	var release := InputEventMouseButton.new()
	release.position = press.position
	release.button_index = button
	release.pressed = false
	bench._world_input(release)


func _expect_unattached_refusal(button: int, selected: int, label: String) -> void:
	var before: Dictionary = bench.object_shard_edit_diagnostics()
	_pointer(button, selected)
	var after: Dictionary = bench.object_shard_edit_diagnostics()
	# Live editing now reports a readable refusal before attempting the port.
	# Keep the machine reason and exact admission count independently checked;
	# a changed sentence must never conceal an ordinary-brush fallback.
	_expect(bench.message.contains("Structures are not attached yet"),
		label + ": unavailable owner is visibly explained")
	_expect(int(after.counts.get("refused", 0)) == int(before.counts.get("refused", 0)) + 1 \
		and int(after.counts.get("admitted", 0)) == int(before.counts.get("admitted", 0)),
		label + ": exactly one pre-admission refusal and no admitted action")
	var matched: bool = false
	for event: Dictionary in after.recent:
		if int(event.sequence) <= int(before.sequence): continue
		if event.kind == "refused" and event.detail.get("outcome") == "OwnerNotAttached" \
			and int(event.detail.get("tool", -1)) == selected:
			matched = true
	_expect(matched, label + ": current diagnostic identifies OwnerNotAttached for the attempted tool")


func _run() -> void:
	_expect("--objectshard-m4-workbench" in OS.get_cmdline_user_args(),
		"Explicit M4 flag required; production defaults remain untouched")
	if failures:
		await _finish()
		return
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await _ready_workbench():
		_expect(false, "Real ordinary Workbench installed and worker published")
		await _finish()
		return
	var worker: CyberSimulationWorker = host.simulation_worker
	var world: Variant = worker._world
	var original_native_instance: int = world.get_instance_id()
	var initial_world_generation: int = int(host.latest_snapshot.render_world_generation)
	_expect(bench.CUT_MOVING_TOOL == bench.TOOL_NAMES.size() and bench._tool.get_item_text(5) == "Grab physical part" and bench._tool.get_item_text(6) == "Place / rotate (paused)",
		"Actor manipulation and structural edits have separate mounted controls")
	var structural_tools: Dictionary = {7:"Precision cut", 8:"Area ignition", 9:"Settle into canvas",
		10:"Structural eraser", 11:"Slice", 12:"Weathering", 13:"Drill"}
	_expect(bench._tool.item_count == bench.TOOL_NAMES.size() + structural_tools.size(),
		"Seven structural options exist behind the explicit flag")
	for index: int in structural_tools:
		_expect(bench._tool.get_item_text(index) == structural_tools[index],
			"Structural tool label and mounted index agree: " + str(structural_tools[index]))
	_expect(bench.object_shard_m4_port.enabled and host.object_shard_m4_probe.enabled == ("--objectshard-diagnostics" in OS.get_cmdline_user_args()),
		"Structures and optional performance recording obey their independent flags")
	var capability: Dictionary = bench.object_shard_m4_status()
	_expect(capability.get("outcome") == "CompetingOrUnattachedWorld" and
		not capability.get("ready", true), "No fake same-World adapter is reported as ready")
	_expect(host.paused, "Fresh ordinary Workbench remains paused before test input")
	var before_revision: int = int(host.latest_snapshot.simulation_world_revision)
	var brush_before: Dictionary = worker.paint_state()
	_expect(not bool(brush_before.get("legacy_busy", true)),
		"No ordinary brush is pending at the negative-input checkpoint")
	_expect_unattached_refusal(MOUSE_BUTTON_RIGHT, bench.CUT_MOVING_TOOL, "Paused precision erase")
	_expect(bench.object_shard_m4_port.pending_count() == 0,
		"Refused moving erase never enters native queue")
	_expect_unattached_refusal(MOUSE_BUTTON_LEFT, bench.IGNITE_MOVING_TOOL, "Paused area ignition")
	_expect(bench.object_shard_m4_port.pending_count() == 0,
		"Refused moving ignition never enters native queue")
	for frame: int in range(4):
		await process_frame
	var brush_after: Dictionary = worker.paint_state()
	_expect(not bool(brush_after.get("legacy_busy", true)),
		"No M4 pointer intent was silently dispatched to ordinary brush")
	_expect(host.latest_snapshot.simulation_world_revision == before_revision,
		"Paused native materials did not mutate after rejected M4 pointer input")
	_expect(int(host.latest_snapshot.render_world_generation) == initial_world_generation,
		"Native World generation is unchanged by M4 pointer attempts")
	_expect(worker == host.simulation_worker and worker._world == world and
		worker._world.get_instance_id() == original_native_instance,
		"Exactly the original ordinary native World remains authoritative")
	# Repeat under real continuous simulation. This is an input-refusal control,
	# NOT an ObjectShard moving-body physics or timing acceptance fixture.
	var before_live_tick: int = int(host.latest_snapshot.tick_index)
	_expect(bench.toggle_pause(), "Enter actual ordinary continuously playable World")
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while int(host.latest_snapshot.tick_index) <= before_live_tick \
			and Time.get_ticks_msec() < deadline and not worker.has_failed():
		await process_frame
	_expect(host.latest_snapshot.tick_index > before_live_tick and not worker.has_failed(),
		"Real ordinary World advances a semantic tick while M4 seam is unavailable")
	_expect_unattached_refusal(MOUSE_BUTTON_RIGHT, bench.CUT_MOVING_TOOL, "Running precision erase")
	_expect(bench.object_shard_m4_port.pending_count() == 0,
		"Running World refuses moving-cell edit without routing it into terrain")
	_expect(not worker.paint_state().get("legacy_busy", true),
		"Running World remains free of reinterpreted moving-cell brush commands")
	_expect(worker._world == world and worker._world.get_instance_id() == original_native_instance,
		"Continuously playing Workbench keeps exactly the same original native World")
	_expect(bench.toggle_pause(), "Return to paused ordinary World after live refusal")
	var old_port_epoch: int = bench.object_shard_m4_port.generation
	var old_trace_epoch: int = host.object_shard_m4_probe.epoch
	bench.object_shard_m4_port.retire("TestNavigation")
	host.object_shard_m4_probe.retire("TestNavigation")
	_expect(bench.object_shard_m4_port.generation == old_port_epoch + 1 and
		host.object_shard_m4_probe.epoch == old_trace_epoch + 1,
		"Explicit F2/reset-style fence invalidates prior M4 observations")
	await _finish()


func _finish() -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	print(JSON.stringify({"schema": "objectshard-m4-ordinary-scene-refusal-v1",
		"checks": checks, "failures": failures,
		"actual_ordinary_native_world_used": true,
		"same_world_mutation_integration": "NATIVE_ADAPTER_PRESENT_PHYSICS_UNBOUND",
		"scope": "actual ordinary Workbench negative pointer routing; no body physics proven"}))
	quit(1 if failures else 0)
