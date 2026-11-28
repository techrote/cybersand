extends Node

signal action_admitted(action: Dictionary, admission: Dictionary, observation: Dictionary)

## GIP-014 development-only adapter. Every command stays inside the mounted
## ordinary Workbench; native receipts and readbacks retain their actual values.
## No production scene references this script.
const Setup = preload("res://scripts/workbench_setup.gd")
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Gameplay = preload("res://goblin/goblin_gameplay_actions.gd")
const GameplayOracles = preload("res://goblin/goblin_gameplay_oracles.gd")
const Capabilities = preload("res://goblin/goblin_capabilities.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const MaterialLineage = preload("res://goblin/goblin_material_lineage.gd")
const SAVE_NAME := "goblin-layout"
const PROFILE_SCHEMA := "cybersand-goblin-profile-v1"
const BODY_CAPTURE_REFUSAL := "Move or remove the body before editing or copying its covered cells."
const MATERIALS := Gameplay.MATERIALS
const ACTION_IDS := ["pause", "play", "wait_ticks", "select_material", "brush", "erase",
	"rectangle", "outline", "line", "select_region", "copy", "paste", "undo", "redo",
	"fill", "camera", "actor_select", "actor_drive", "panel", "save_layout",
	"reopen_layout", "reset_fixture", "actor_place", "actor_pilot", "actor_reset", "single_step"] + Gameplay.IDS
const EDIT_IDS := ["brush", "erase", "rectangle", "outline", "line", "paste", "fill", "undo", "redo"]
const ARGUMENTS := {
	"pause": [], "play": ["ticks"], "wait_ticks": ["ticks"], "select_material": ["material"],
	"brush": ["x", "y", "radius"], "erase": ["x", "y", "radius"],
	"rectangle": ["x0", "y0", "x1", "y1"], "outline": ["x0", "y0", "x1", "y1"],
	"line": ["x0", "y0", "x1", "y1"], "select_region": ["x0", "y0", "x1", "y1"],
	"copy": [], "paste": ["x", "y"], "undo": [], "redo": [], "fill": ["x", "y"],
	"camera": ["x", "y", "width", "height"], "actor_select": ["actor_id"],
	"actor_drive": ["direction", "ticks"], "panel": ["panel", "open"],
	"save_layout": [], "reopen_layout": [], "reset_fixture": [],
	"actor_place": ["model", "x", "y"], "actor_pilot": ["actor_id"], "actor_reset": [], "single_step": [],
}

# The existing application-local headless tests use this same focus seam.
# Graphical runs retain the real window-focus predicate.
class GoblinHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool:
		return true if DisplayServer.get_name() == "headless" else super._actor_window_has_focus()

var host: Control
var bench: Control
var editor: Control
var worker: RefCounted
var fixture_id := ""
var fixture_data: Dictionary = {}
var fixture_digest := ""
var mounted := false
var stopped := false
var executing := false
var profile: Dictionary = {}
var last_error := ""
var last_capture: Dictionary = {}
var _brush_token := 0
var _brush_receipts: Dictionary = {}
var _history_receipts: Array = []
var _details_button: Button
var _held_keys: Array[int] = []
var _saved_authored_digest := ""
var _saved_material_digest := ""
var _saved_native_tick := -1
var _saved_capture: Dictionary = {}
var _saved_material_lineage: Dictionary = {}
var _material_history := MaterialLineage.new()
var _last_edit_region := Rect2i(32, 32, 64, 64)
var _probe_key := ""
var _probe_counts: Dictionary = {}
var _model_capabilities: Dictionary = {}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= low and value <= high

static func validate_action(action: Variant) -> Dictionary:
	if not action is Dictionary: return {"ok": false, "error": "action must be an object"}
	for key: Variant in action:
		if str(key) not in ["id", "args", "goal"]: return {"ok": false, "error": "unknown action field"}
	if not action.get("id") is String or action.id not in ACTION_IDS:
		return {"ok": false, "error": "unsupported action id", "unsupported": true}
	if not action.get("args") is Dictionary: return {"ok": false, "error": "args must be an explicit object"}
	if action.has("goal") and (not action.goal is String or action.goal.length() > 240):
		return {"ok": false, "error": "goal must be a bounded string"}
	if str(action.id) in Gameplay.IDS: return Gameplay.validate_action(action)
	var id: String = action.id
	var args: Dictionary = action.get("args", {})
	for key: Variant in args:
		if str(key) not in ARGUMENTS[id]: return {"ok": false, "error": "unknown argument for " + id}
	for key: String in ARGUMENTS[id]:
		if not args.has(key) and not (id == "play" and key == "ticks"):
			return {"ok": false, "error": "missing argument " + key}
	match id:
		"play", "wait_ticks":
			if not _integer(args.get("ticks", 4), 1, 32): return {"ok": false, "error": "ticks outside 1..32"}
		"select_material":
			if not _integer(args.material, 0, 58) or int(args.material) not in MATERIALS:
				return {"ok": false, "error": "material outside the goblin palette"}
		"brush", "erase", "fill", "paste":
			if not _integer(args.x, 8, 503) or not _integer(args.y, 8, 503):
				return {"ok": false, "error": "point outside the fixture's bounded editing area"}
			if id in ["brush", "erase"] and not _integer(args.radius, 0, 4):
				return {"ok": false, "error": "radius outside 0..4"}
		"rectangle", "outline", "line", "select_region":
			for key: String in ["x0", "y0", "x1", "y1"]:
				if not _integer(args[key], 8, 503): return {"ok": false, "error": "endpoint outside fixture"}
			if absf(args.x1 - args.x0) >= 64 or absf(args.y1 - args.y0) >= 64:
				return {"ok": false, "error": "shape exceeds 64 by 64 cells"}
		"camera":
			if not _integer(args.x, 0, 256) or not _integer(args.y, 0, 256) \
				or not _integer(args.width, 240, 480) or not _integer(args.height, 135, 270) \
				or int(args.width) not in [240, 480] or int(args.height) not in [135, 270]:
				return {"ok": false, "error": "camera outside bounded views"}
		"actor_select", "actor_pilot":
			if not _integer(args.actor_id, 1, Gameplay.MAX_ACTOR_ID): return {"ok": false, "error": "actor id outside bounded identity budget"}
		"actor_place":
			if args.model not in Gameplay.MODELS or not _integer(args.x, 32, 448) or not _integer(args.y, 32, 224):
				return {"ok": false, "error": "actor placement outside the admitted fixture models and spawn region"}
		"actor_drive":
			if args.direction not in ["left", "right", "up", "down"] or not _integer(args.ticks, 1, 16):
				return {"ok": false, "error": "actor drive outside bounded controls"}
		"panel":
			if args.panel != "details" or typeof(args.open) != TYPE_BOOL:
				return {"ok": false, "error": "only the ordinary details panel is admitted"}
	return {"ok": true}

static func json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = json_value(value[key])
		return out
	if value is Array or value is PackedInt32Array or value is PackedInt64Array \
		or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray \
		or value is PackedByteArray:
		var out: Array = []
		for item: Variant in value: out.append(json_value(item))
		return out
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Rect2 or value is Rect2i: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is StringName: return str(value)
	if value is float and not is_finite(value): return str(value)
	if value is Object: return "[nonserialized object]"
	return value

static func digest(value: Variant) -> String:
	return JSON.stringify(json_value(value), "", true).sha256_text()

static func verify_profile() -> Dictionary:
	var supplied: String = OS.get_environment("CYBERSAND_GOBLIN_PROFILE").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual: String = OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if supplied.is_empty() or not supplied.is_absolute_path():
		return {"ok": false, "error": "start goblin through its isolated-profile launcher"}
	var comparison_root := supplied.to_lower() if OS.get_name() == "Windows" else supplied
	var comparison_actual := actual.to_lower() if OS.get_name() == "Windows" else actual
	if not comparison_actual.begins_with(comparison_root + "/"):
		return {"ok": false, "error": "Godot user data is outside the dedicated goblin profile"}
	var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(supplied.path_join("goblin-profile.json")))
	if not marker is Dictionary or marker.get("schema", "") != PROFILE_SCHEMA:
		return {"ok": false, "error": "dedicated test-profile marker missing or invalid"}
	return {"ok": true, "root": supplied, "user_data_dir": actual, "schema": PROFILE_SCHEMA}

func mount() -> Dictionary:
	if mounted: return {"ok": true, "observation": observe(), "profile": profile}
	profile = verify_profile()
	if not profile.ok: return profile.duplicate(true)
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		return {"ok": false, "error": "native extension unavailable", "classification": "not_applicable"}
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	get_tree().set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(GoblinHost)
	add_child(host)
	bench = host.shared_workbench
	worker = host.simulation_worker
	if bench == null or worker == null:
		return {"ok": false, "error": "ordinary Workbench did not mount", "classification": "adapter_failure"}
	editor = bench.paint_editor
	if editor == null: return {"ok": false, "error": "ordinary paint editor unavailable", "classification": "not_applicable"}
	for button: Button in bench.find_children("*", "Button", true, false):
		if button.text == "Details":
			_details_button = button
			break
	editor.deferred_brush_finished.connect(_on_brush_finished)
	editor.history_action_finished.connect(_on_history_finished)
	if not await _until(_ready_for_action, "main_ack_seconds"):
		return {"ok": false, "error": last_error, "classification": _wait_failure_classification()}
	mounted = true
	return {"ok": true, "observation": observe(), "profile": profile.duplicate(true)}

func policy() -> PackedInt32Array:
	return PackedInt32Array(bench.applied.liquid_policy) if bench != null and not bench.applied.is_empty() else PackedInt32Array()

func initialize(id: String, data: Dictionary) -> Dictionary:
	var result: Dictionary = await mount()
	if not result.get("ok", false): return result
	return await install_fixture(id, data)

func install_fixture(id: String, data: Dictionary, admission_row: Dictionary = {}) -> Dictionary:
	if not mounted: return {"ok": false, "error": "adapter is not mounted"}
	if id not in Fixtures.IDS:
		return {"ok": false, "error": "unknown committed fixture"}
	if Setup.extent_of(data) != Vector2i(512, 512) or not Setup.validate(data).is_empty():
		return {"ok": false, "error": "fixture must be a valid 512 by 512 authored setup"}
	stopped = false
	_release_keys()
	if not host.paused and not bench.toggle_pause(): return {"ok": false, "error": str(bench.message)}
	if not await _until(_settled, "operation_seconds"):
		return {"ok": false, "error": last_error, "classification": _wait_failure_classification()}
	var generation: int = int(worker.paint_state().get("generation", -1))
	if not bench.apply(data.duplicate(true)): return {"ok": false, "error": str(bench.message), "classification": "game_observation"}
	if not admission_row.is_empty():
		_admit(admission_row, {"accepted": true, "requested_fixture": id,
			"pending_serial": int(host.pending_microscenario_apply.get("serial", -1))})
	if not await _until(_ready_for_action, "main_ack_seconds", true):
		return {"ok": false, "error": last_error, "classification": _wait_failure_classification()}
	if int(worker.paint_state().get("generation", -1)) <= generation:
		return {"ok": false, "error": str(host.microscenario_error), "classification": "game_observation",
			"native_attempt": json_value(host.tower_context.get("liquid_construction_attempt", {}))}
	fixture_id = id
	fixture_data = data.duplicate(true)
	fixture_digest = digest(data)
	bench._name.text = SAVE_NAME
	bench._set_view(Vector2.ZERO, Vector2i(480, 270))
	bench._brush.value = 0
	editor.select_material(2)
	editor.select_tool("Brush")
	_saved_authored_digest = ""
	_saved_material_digest = ""
	_saved_native_tick = -1
	_saved_capture.clear()
	_saved_material_lineage.clear()
	_material_history.authored(_capture_source(), json_value(host.tower_context.get("liquid_construction_receipt", {})), "fixture_install", host.paused)
	_last_edit_region = Rect2i(32, 32, 64, 64)
	return {"ok": true, "observation": observe(), "native_receipt": json_value(host.tower_context.get("liquid_construction_receipt", {}))}

func observe() -> Dictionary:
	if host == null or worker == null: return {"mounted": false, "fixture_id": fixture_id}
	var source: Dictionary = worker.paint_state()
	# Read the bounded worker queue under its actual owner mutex; never mutate
	# it. An unchanged configure still needs observed command consumption.
	worker._mutex.lock()
	var pending_source_commands: int = worker._workbench_source_commands.size()
	# Keep command identity and current source state with this exact count.
	# A later callback can see a drained queue at the same native tick. Copy
	# only bounded data here; conversion and all other observations stay
	# outside the owner's critical section.
	var source_queue_evidence := {"schema": "cybersand-goblin-source-queue-v1",
		"command_count": pending_source_commands, "copy_complete": pending_source_commands <= 16,
		"commands": worker._workbench_source_commands.duplicate(true) if pending_source_commands <= 16 else [],
		"owner_generation": worker._world_generation, "owner_paused": worker._paused,
		"current_source_receipt": worker._workbench_source.receipt().duplicate(true)}
	worker._mutex.unlock()
	var native := {"generation": int(source.get("generation", -1)), "revision": int(source.get("revision", -1)),
		"tick": int(source.get("tick", -1)), "paused": bool(source.get("paused", false)),
		"busy": bool(source.get("busy", true)), "failed": worker.has_failed()}
	var lineage: Dictionary = _material_history.observe(native, host.paused)
	var actors: Array = []
	var actor_ids: Array = []
	var controllable_ids: Array = []
	var physical_body_count := 0
	var physical_proxy_count := 0
	if host.physical_actor_session != null:
		physical_body_count = host.physical_actor_session.bodies().size()
		for record: Dictionary in bench.applied.get("actors", []):
			var slot: int = host.physical_actor_session.slot_for_instance(int(record.id))
			physical_proxy_count += int(host.physical_actor_session.bridge.actor_proxy_range(slot).get("count", 0))
	if bench != null:
		for record: Dictionary in bench.applied.get("actors", []):
			var id: int = int(record.id)
			actor_ids.append(id)
			if str(record.model) != Setup.BARREL: controllable_ids.append(id)
			var actual: Dictionary = bench.body_state(id)
			actors.append({"id": id, "model": str(record.model), "state": json_value(actual),
				"authored_spawn": json_value(record.get("spawn", [])),
				"control_observation": json_value(bench.actor_observation(id, false)),
				"authored_control": json_value(Setup.ActorCatalog.control_for(record)),
				"options": json_value(record.get("options", {})),
				"capabilities": json_value(_capabilities_for(str(record.model))),
				"position": json_value(actual.get("position")),
				"rotation": actual.get("rotation"), "linear_velocity": json_value(actual.get("linear_velocity")),
				"controller": json_value(actual.get("controller", {})), "observed": not actual.is_empty()})
	var undo: bool = editor != null and editor.history_available("undo")
	var redo: bool = editor != null and editor.history_available("redo")
	return {"mounted": mounted, "fixture_id": fixture_id, "scene_identity": fixture_digest,
		"progress_refusal": _observed_progress_refusal(source),
		"world_size": json_value(Setup.extent_of(bench.applied)),
		"adapter_version": 3, "material_lineage": lineage, "feature_capabilities": Capabilities.negotiate(host, bench),
		"configuration": {"response": str(bench.applied.get("response", "")), "thruster_fire": bool(bench.applied.get("fire", false))},
		"source": {"authored": json_value(bench.applied.get("source", [])),
			"pending_commands": pending_source_commands,
			"queue_evidence": json_value(source_queue_evidence),
			"snapshot_serial": int(host.latest_snapshot.serial) if host.latest_snapshot != null else -1,
			"receipt": json_value(host.latest_snapshot.lab_context.get("workbench_source", {})) if host.latest_snapshot != null else {},
			"snapshot_tick": int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else -1},
		"paint_preview": {"dragging": bool(editor.dragging), "samples": editor.stroke.size(),
			"anchor": json_value(editor.anchor), "cursor": json_value(editor.cursor)},
		"material_probe": _material_probe(source),
		"native": native,
		"paused": host.paused, "material": int(editor.material_id) if editor != null else -1,
		"tool": editor.tool_name() if editor != null else "", "brush_radius": editor.radius() if editor != null else -1,
		"selection": json_value(editor.selection) if editor != null else [],
		"clipboard_size": json_value(editor.clipboard.get("size", Vector2i.ZERO)) if editor != null else [0, 0],
		"clipboard_digest": digest(editor.clipboard.get("materials", [])) if editor != null else "",
		"clipboard": {"region": json_value(Rect2i(editor.clipboard.get("origin", Vector2i.ZERO), editor.clipboard.get("size", Vector2i.ZERO))),
			"materials": json_value(editor.clipboard.get("materials", []))} if editor != null else {},
		"undo_available": undo, "redo_available": redo, "can_undo": undo, "can_redo": redo,
		"editor_completed_actions": int(editor.completed_actions) if editor != null else 0,
		"selected_actor": bench.selected_id() if bench != null else 0,
		"pilot_actor": bench.pilot_id() if bench != null else 0, "actors": actors, "actor_ids": actor_ids,
		"controllable_actor_ids": controllable_ids,
		"next_actor_id": int(bench.applied.get("next_id", -1)) if bench != null else -1,
		"actor_tick": int(host.physical_actor_session.tick) if host.physical_actor_session != null else -1,
		"camera": {"origin": json_value(host.camera_origin), "size": json_value(host.current_view_size),
			"mode": int(bench._camera.selected), "zoom_index": int(bench._zoom)},
		"panels": {"details": bench._details.visible if bench != null else false},
		"details_open": bench._details.visible if bench != null else false,
		"authored_digest": digest(bench.applied) if bench != null else "",
		"saved_authored_digest": _saved_authored_digest, "saved_material_digest": _saved_material_digest,
		"saved_native_tick": _saved_native_tick,
		"saved_material_lineage": _saved_material_lineage.duplicate(true),
		"snapshot_tick": int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else -1,
		"snapshot_serial": int(host.latest_snapshot.serial) if host.latest_snapshot != null else -1,
		"native_worker_request": int(host.latest_snapshot.native_worker_request) if host.latest_snapshot != null else -1,
		"physical_epoch": int(host._physical_epoch),
		"physical_session_active": host.physical_actor_session != null,
		"physical_body_count": physical_body_count, "physical_proxy_count": physical_proxy_count,
		"physical_ready": bool(host._physical_terrain_ready),
		"step_serial": int(bench.step_serial) if bench != null else -1,
		"step_observed_serial": int(host.tower_context.get("workbench_step_serial", -1)),
		"message": str(bench.message) if bench != null else "", "stopped": stopped}

func available_actions() -> Array[Dictionary]:
	var menu: Array[Dictionary] = []
	if not mounted or stopped or executing or not _ready_for_action(): return menu
	if not host.paused:
		menu.append({"id": "pause", "args": {}})
		menu.append({"id": "wait_ticks", "args": {"ticks": 4}})
		if bench.pilot_id() > 0:
			for direction: String in ["left", "right", "up", "down"]:
				menu.append({"id": "actor_drive", "args": {"direction": direction, "ticks": 8}})
		menu.append_array(Gameplay.available_actions(self))
		return menu
	menu.append({"id": "play", "args": {"ticks": 4}})
	menu.append({"id": "pause", "args": {}})
	menu.append({"id": "single_step", "args": {}})
	for material: int in MATERIALS:
		if material in worker.paint_materials(): menu.append({"id": "select_material", "args": {"material": material}})
	for cell: Vector2i in [Vector2i(48, 48), Vector2i(112, 80), Vector2i(176, 112), Vector2i(240, 80), Vector2i(304, 112), Vector2i(368, 80)]:
		menu.append({"id": "brush", "args": {"x": cell.x, "y": cell.y, "radius": 2}})
		menu.append({"id": "erase", "args": {"x": cell.x, "y": cell.y, "radius": 2}})
		for kind: String in ["rectangle", "outline", "line", "select_region"]:
				var visible_region := Rect2i(Vector2i(host.camera_origin.floor()), host.current_view_size)
				if visible_region.encloses(Rect2i(cell, Vector2i(13, 9))):
					menu.append({"id": kind, "args": {"x0": cell.x, "y0": cell.y, "x1": cell.x + 12, "y1": cell.y + 8}})
	if editor.selection.has_area():
		menu.append({"id": "copy", "args": {}})
		# The normal editor may expand a connected Fill beyond its first
		# capture. execute() preflights the actual component and refuses an
		# unread edge before submitting any ordinary Fill operation.
		var centre: Vector2i = editor.selection.position + editor.selection.size / 2
		menu.append({"id": "fill", "args": {"x": centre.x, "y": centre.y}})
	if not editor.clipboard.is_empty(): menu.append({"id": "paste", "args": {"x": 192, "y": 144}})
	if editor.history_available("undo"): menu.append({"id": "undo", "args": {}})
	if editor.history_available("redo"): menu.append({"id": "redo", "args": {}})
	for x: int in [0, 64, 128]: menu.append({"id": "camera", "args": {"x": x, "y": 0, "width": 240, "height": 135}})
	menu.append({"id": "camera", "args": {"x": 0, "y": 0, "width": 480, "height": 270}})
	for record: Dictionary in bench.applied.get("actors", []): menu.append({"id": "actor_select", "args": {"actor_id": int(record.id)}})
	for actor_id: int in observe().controllable_actor_ids:
		menu.append({"id": "actor_pilot", "args": {"actor_id": actor_id}})
	if bench.selected_id() > 0: menu.append({"id": "actor_reset", "args": {}})
	if bench.applied.actors.size() < 8 and int(bench.applied.next_id) <= Gameplay.MAX_ACTOR_ID:
		for model: String in Gameplay.MODELS:
			if Setup.ActorCatalog.has_model(model):
				menu.append({"id": "actor_place", "args": {"model": model, "x": 256, "y": 96}})
	menu.append({"id": "panel", "args": {"panel": "details", "open": not bench._details.visible}})
	menu.append({"id": "save_layout", "args": {}})
	if not _saved_authored_digest.is_empty(): menu.append({"id": "reopen_layout", "args": {}})
	menu.append({"id": "reset_fixture", "args": {}})
	menu.append_array(Gameplay.available_actions(self))
	return menu

func execute(action: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var row := {"action": action.duplicate(true), "before": observe(), "after": {}, "admission": {},
		"native_receipt": {}, "status": "proposed", "classification": "game_observation", "error": "",
		"duration_usec": 0, "capture_before": {}, "capture_after": {}, "interval": {}, "_owns_execution": false}
	var valid: Dictionary = validate_action(action)
	if not valid.ok:
		return _finish(row, started, "refused", "not_applicable" if valid.get("unsupported", false) else "invalid_action", valid.error)
	if not mounted or stopped or executing:
		return _finish(row, started, "refused", "cancelled" if stopped else "adapter_failure", "adapter is not available")
	if not _ready_for_action(): return _finish(row, started, "refused", "game_observation", "Workbench is busy")
	executing = true
	row._owns_execution = true
	var id: String = action.id
	var args: Dictionary = action.get("args", {})
	if id in Gameplay.IDS: return await Gameplay.execute(self, action, row, started)
	if id in EDIT_IDS + ["select_region", "copy", "save_layout", "reopen_layout", "reset_fixture",
		"actor_place", "actor_pilot", "actor_reset", "single_step"] and not host.paused:
		return _finish(row, started, "refused", "not_applicable", "this goblin action requires paused authoring")
	var region: Rect2i = _action_region(action)
	if id == "copy" and editor.selection.has_area():
		row.capture_before = await capture(editor.selection)
		if row.capture_before.has("error"):
			return _finish(row, started, "refused", _capture_failure_classification(row.capture_before), row.capture_before.error)
	if id in EDIT_IDS and region.has_area():
		row.capture_before = await capture(region)
		if row.capture_before.has("error"):
			return _finish(row, started, "refused", _capture_failure_classification(row.capture_before), row.capture_before.error)
	if stopped: return _finish(row, started, "refused", "cancelled", "Stop requested before game action submission")
	if id == "fill" and region.has_area():
		var bounded: Dictionary = Shapes.fill_connected(Vector2i(int(args.x), int(args.y)),
			region.position, region.size, PackedInt32Array(row.capture_before.get("materials", [])), Vector2i(512, 512), 4096)
		if not bounded.get("accepted", false) or not str(bounded.get("unread_edge", "")).is_empty():
			return _finish(row, started, "refused", "not_applicable", "Fill is not wholly contained in the independently captured 4096-cell budget")
	row.before = observe()
	match id:
		"pause":
			if not host.paused and not bench.toggle_pause(): return _finish(row, started, "refused", "game_observation", bench.message)
			_admit(row, {"accepted": true})
			if not await _until(func() -> bool: return _settled() and bool(worker.paint_state().get("paused", false)), "operation_seconds"):
				return _finish(row, started, "partial", _wait_failure_classification(), last_error)
			row.interval = await _paused_interval()
		"play", "wait_ticks":
			if id == "wait_ticks" and host.paused: return _finish(row, started, "refused", "not_applicable", "native play is paused")
			if host.paused and not bench.toggle_pause(): return _finish(row, started, "refused", "game_observation", bench.message)
			_admit(row, {"accepted": true})
			row.interval = await _tick_interval(int(args.get("ticks", 4)))
			if not row.interval.ok: return _finish(row, started, "partial", "cancelled" if stopped else "timeout", last_error)
		"single_step":
			var first: Dictionary = observe()
			var frames: int = Engine.get_process_frames()
			var accepted: bool = bench.step_once()
			_admit(row, {"accepted": accepted, "requested_step_serial": int(bench.step_serial)})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			var expected_serial: int = int(bench.step_serial)
			if not await _until(func() -> bool:
				return not bench.step_pending and int(host.tower_context.get("workbench_step_serial", -1)) == expected_serial,
				"operation_seconds", true): return _finish(row, started, "partial", _wait_failure_classification(), last_error)
			var last: Dictionary = observe()
			row.interval = {"start_tick": first.native.tick, "end_tick": last.native.tick,
				"observed_frames": Engine.get_process_frames() - frames,
				"start_actor_tick": first.actor_tick, "end_actor_tick": last.actor_tick}
			row["step_observation"] = {"requested_serial": expected_serial,
				"observed_serial": int(host.tower_context.get("workbench_step_serial", -1)),
				"native_tick": last.native.tick, "actor_tick": last.actor_tick, "paused": host.paused}
		"select_material":
			if int(args.material) not in worker.paint_materials(): return _finish(row, started, "refused", "not_applicable", "native material unavailable")
			var selected := false
			for index: int in bench._material.item_count:
				if bench._material.get_item_id(index) == int(args.material):
					bench._material.select(index)
					bench._material.item_selected.emit(index)
					selected = true
					break
			if not selected: return _finish(row, started, "refused", "not_applicable", "material absent from ordinary palette control")
			_admit(row, {"accepted": true})
		"brush", "erase":
			_brush_token += 1
			var material: int = 0 if id == "erase" else int(editor.material_id)
			bench._brush.value = int(args.radius)
			editor.select_tool("Eraser" if id == "erase" else "Brush")
			var accepted: bool = editor.begin_deferred_brush(Vector2i(int(args.x), int(args.y)), material, int(args.radius), _brush_token)
			_admit(row, {"accepted": accepted, "token": _brush_token})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			if not await _until(func() -> bool: return _brush_receipts.has(_brush_token), "operation_seconds", true):
				return _finish(row, started, "partial", "cancelled" if stopped else "timeout", last_error)
			row["editor_receipt"] = _brush_receipts[_brush_token]
			# Planning can be refused/cancelled before any native edit exists.
			# Keep that genuine editor terminal separate from a native receipt.
			if row.editor_receipt.get("backend", "") == "CyberNativeCellWorld":
				row.native_receipt = row.editor_receipt.duplicate(true)
			_brush_receipts.erase(_brush_token)
		"rectangle", "outline", "line", "select_region":
			var visible_region := Rect2i(Vector2i(host.camera_origin.floor()), host.current_view_size)
			if not visible_region.encloses(region):
				return _finish(row, started, "refused", "not_applicable", "shape endpoints are outside the current camera view")
			var tool: String = {"rectangle": "Rectangle", "outline": "Outline", "line": "Line", "select_region": "Select"}[id]
			editor.select_tool(tool)
			bench._brush.value = 0
			var count: int = editor.completed_actions
			_gesture(Vector2i(int(args.x0), int(args.y0)), Vector2i(int(args.x1), int(args.y1)))
			_admit(row, {"accepted": editor.busy() or id == "select_region"})
			if not await _until(_settled, "operation_seconds", true): return _finish(row, started, "partial", "cancelled" if stopped else "timeout", last_error)
			if id != "select_region":
				if editor.completed_actions <= count:
					# A stopped planner may have submitted no native edit at all.
					# Keep the absent native receipt absent and label the actual
					# cancellation, rather than borrowing the previous edit receipt.
					return _finish(row, started, "refused", "cancelled" if stopped else "game_observation", bench.message)
				row.native_receipt = json_value(editor.last_receipt)
		"copy", "paste", "fill", "undo", "redo":
			if id == "copy" and not editor.selection.has_area(): return _finish(row, started, "refused", "not_applicable", "select a bounded region first")
			if id == "paste" and editor.clipboard.is_empty(): return _finish(row, started, "refused", "not_applicable", "clipboard is empty")
			if id == "fill" and (not editor.selection.has_area() or not editor.selection.has_point(Vector2i(int(args.x), int(args.y)))):
				return _finish(row, started, "refused", "not_applicable", "Fill requires a bounded selected region containing the seed")
			if id in ["undo", "redo"] and not editor.history_available(id): return _finish(row, started, "refused", "not_applicable", "history action unavailable")
			var accepted := false
			var previous_operation: int = int(editor.last_receipt.get("operation_id", -1))
			_history_receipts.clear()
			match id:
				"copy": accepted = editor.copy_selection()
				"paste": accepted = editor.paste_at(Vector2i(int(args.x), int(args.y)))
				"fill": accepted = editor.fill_at(Vector2i(int(args.x), int(args.y)))
				"undo": accepted = editor.undo()
				"redo": accepted = editor.redo()
			_admit(row, {"accepted": accepted})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			if not await _until(_settled, "operation_seconds", true): return _finish(row, started, "partial", "cancelled" if stopped else "timeout", last_error)
			# A cancelled planner leaves last_receipt at the preceding action.
			# Only a new native operation can belong to this action.
			if editor.last_receipt.get("backend", "") == "CyberNativeCellWorld" \
				and int(editor.last_receipt.get("operation_id", -1)) != previous_operation:
				row.native_receipt = json_value(editor.last_receipt)
			if not _history_receipts.is_empty(): row["history_receipt"] = _history_receipts.back().duplicate(true)
		"camera":
			bench._set_view(Vector2(float(args.x), float(args.y)), Vector2i(int(args.width), int(args.height)))
			_admit(row, {"accepted": true})
		"actor_select":
			if int(args.actor_id) not in observe().actor_ids: return _finish(row, started, "refused", "not_applicable", "actor absent in fixture")
			var accepted: bool = bench.select_instance(int(args.actor_id))
			_admit(row, {"accepted": accepted})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
		"actor_pilot":
			if int(args.actor_id) not in observe().controllable_actor_ids:
				return _finish(row, started, "refused", "not_applicable", "actor has no supported human controls")
			var accepted: bool = bench.pilot_instance(int(args.actor_id))
			_admit(row, {"accepted": accepted})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			row["actor_authoring"] = {"instance_id": int(args.actor_id),
				"model": str(bench.actor(bench.applied, int(args.actor_id)).get("model", "")),
				"spawn": json_value(bench.actor(bench.applied, int(args.actor_id)).get("spawn", [])),
				"control": json_value(host.physical_actor_session.workbench_control(int(args.actor_id))),
				"body": json_value(bench.body_state(int(args.actor_id)))}
		"actor_place", "actor_reset":
			if id == "actor_place" and (bench.applied.actors.size() >= 8 or int(bench.applied.next_id) > Gameplay.MAX_ACTOR_ID):
				return _finish(row, started, "refused", "not_applicable", "fixture's eight live actors or 64 identities budget is full")
			if id == "actor_reset" and bench.selected_id() <= 0:
				return _finish(row, started, "refused", "not_applicable", "select an actual actor first")
			var instance_id: int = int(bench.applied.next_id) if id == "actor_place" else bench.selected_id()
			var original_actor: Dictionary = bench.actor(bench.applied, instance_id).duplicate(true)
			var generation: int = int(worker.paint_state().generation)
			var epoch: int = int(host._physical_epoch)
			var accepted: bool = bench.place(str(args.model), Vector2(float(args.x), float(args.y))) if id == "actor_place" else bench.reset_selected()
			_admit(row, {"accepted": accepted, "requested_instance_id": instance_id,
				"pending_serial": int(host.pending_microscenario_apply.get("serial", -1))})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			if not await _until(_ready_for_action, "main_ack_seconds", true): return _finish(row, started, "partial", _wait_failure_classification(), last_error)
			if int(worker.paint_state().generation) <= generation:
				row["native_attempt"] = json_value(host.tower_context.get("liquid_construction_attempt", {}))
				return _finish(row, started, "refused", "game_observation", str(host.microscenario_error))
			row.native_receipt = json_value(host.tower_context.get("liquid_construction_receipt", {}))
			row["actor_authoring"] = {"instance_id": instance_id, "authored_before": json_value(original_actor),
				"authored_after": json_value(bench.actor(bench.applied, instance_id)),
				"model": str(bench.actor(bench.applied, instance_id).get("model", "")),
				"spawn": json_value(bench.actor(bench.applied, instance_id).get("spawn", [])),
				"body": json_value(bench.body_state(instance_id)),
				"physical_epoch_before": epoch, "physical_epoch_after": int(host._physical_epoch)}
			if int(host._physical_epoch) <= epoch or not host._physical_terrain_ready:
				return _finish(row, started, "partial", "game_observation", "native replacement completed without an adopted physical actor graph")
		"actor_drive":
			if host.paused or bench.pilot_id() <= 0 or host.physical_actor_session == null:
				return _finish(row, started, "refused", "not_applicable", "active ordinary pilot is unavailable")
			var focus: Control = get_viewport().gui_get_focus_owner()
			if focus != null: focus.release_focus()
			_release_keys()
			if not await _until(func() -> bool: return not host._actor_input_rearm, "operation_seconds"):
				return _finish(row, started, "refused", "not_applicable", "ordinary pilot did not rearm")
			var code: int = {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S}[args.direction]
			var control_before: Dictionary = host.physical_actor_session.workbench_control(bench.pilot_id())
			_key(code, true)
			_admit(row, {"accepted": true, "delivery": "Godot application-local input event"})
			row.interval = await _tick_interval(int(args.ticks), true)
			row["actor_input_observation"] = observe()
			var slot: int = host.physical_actor_session.slot_for_instance(bench.pilot_id())
			row["actor_delivery"] = {"instance_id": bench.pilot_id(), "requested_direction": args.direction,
				"before": json_value(control_before),
				"during": json_value(host.physical_actor_session.workbench_control(bench.pilot_id())),
				"sampled_command": json_value(host.physical_actor_session._commands[slot]) if slot >= 0 else {},
				"sampled_ports": json_value(host.physical_actor_session._workbench_ports.get(slot, {})) if slot >= 0 else {}}
			_release_keys()
			if not row.interval.ok: return _finish(row, started, "partial", "cancelled" if stopped else "timeout", last_error)
			if not stopped:
				var released: Dictionary = await _tick_interval(1, true)
				row.actor_delivery["release_interval"] = released
				row.actor_delivery["released_command"] = json_value(host.physical_actor_session._commands[slot]) if slot >= 0 else {}
				row.actor_delivery["released_ports"] = json_value(host.physical_actor_session._workbench_ports.get(slot, {})) if slot >= 0 else {}
				if not released.ok: return _finish(row, started, "partial", "cancelled" if stopped else "timeout", last_error)
		"panel":
			if _details_button == null: return _finish(row, started, "refused", "not_applicable", "ordinary Details control unavailable")
			if bench._details.visible != bool(args.open): _details_button.pressed.emit()
			_admit(row, {"accepted": true})
		"save_layout":
			var material: Dictionary = await capture(Rect2i(0, 0, 512, 512), false)
			row["persistence_capture"] = material.duplicate(true)
			# The ordinary capture API protects body-covered cells. Authored Save
			# remains a supported normal operation, so only this exact observed
			# refusal makes the optional full-layout material comparison N/A.
			if material.has("error") and not _body_protected_capture(material):
				return _finish(row, started, "refused", _capture_failure_classification(material), material.error)
			bench._name.text = SAVE_NAME
			var accepted: bool = bench.save_setup()
			_admit(row, {"accepted": accepted})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			var saved: Dictionary = Setup.read_named(SAVE_NAME)
			if saved.has("error"): return _finish(row, started, "partial", "adapter_failure", saved.error)
			_saved_authored_digest = digest(saved.setup)
			_saved_material_digest = str(material.get("material_sha256", ""))
			_saved_native_tick = int(worker.paint_state().get("tick", -1))
			_saved_capture = material.duplicate(true)
			_saved_material_lineage = observe().get("material_lineage", {}).duplicate(true)
			var comparison: bool = _saved_material_lineage.get("state") == "authored_compatible" and not material.has("error")
			row["persistence"] = {"name": SAVE_NAME, "read_authored_digest": _saved_authored_digest,
				"material_sha256": _saved_material_digest, "saved_native_tick": _saved_native_tick,
				"saved_material_lineage": _saved_material_lineage.duplicate(true),
				"native_material_equality_applicable": comparison,
				"native_material_equality_reason": "available" if comparison else ("native_body_protection" if _body_protected_capture(material) else (
					"simulation_exposed_lineage" if _saved_material_lineage.get("state") == "simulation_exposed" else "unknown_material_lineage")),
				"semantics": "authored start, not evolved simulation"}
		"reopen_layout":
			if _saved_authored_digest.is_empty(): return _finish(row, started, "refused", "not_applicable", "no layout saved in this campaign")
			var generation: int = int(worker.paint_state().generation)
			bench._name.text = SAVE_NAME
			var accepted: bool = bench.load_setup()
			_admit(row, {"accepted": accepted, "pending_serial": int(host.pending_microscenario_apply.get("serial", -1))})
			if not accepted: return _finish(row, started, "refused", "game_observation", bench.message)
			if not await _until(_ready_for_action, "main_ack_seconds", true):
				return _finish(row, started, "partial", _wait_failure_classification(), last_error)
			if int(worker.paint_state().generation) <= generation:
				row["native_attempt"] = json_value(host.tower_context.get("liquid_construction_attempt", {}))
				return _finish(row, started, "refused", "game_observation", str(host.microscenario_error))
			row.native_receipt = json_value(host.tower_context.get("liquid_construction_receipt", {}))
			var material: Dictionary = await capture(Rect2i(0, 0, 512, 512), false)
			row["persistence_capture"] = material.duplicate(true)
			var comparison: bool = _saved_material_lineage.get("state") == "authored_compatible" and not _saved_material_digest.is_empty() and not material.has("error")
			row["persistence"] = {"name": SAVE_NAME, "expected_authored_digest": _saved_authored_digest,
				"reopened_authored_digest": digest(bench.applied), "saved_material_sha256": _saved_material_digest,
				"reopened_material_sha256": material.get("material_sha256", ""),
				"saved_native_tick": _saved_native_tick, "saved_capture": _saved_capture.duplicate(true),
				"saved_material_lineage": _saved_material_lineage.duplicate(true),
				"native_material_equality_applicable": comparison,
				"native_material_equality_reason": "available" if comparison else ("native_body_protection" if _body_protected_capture(_saved_capture) or _body_protected_capture(material) else (
					"simulation_exposed_lineage" if _saved_material_lineage.get("state") == "simulation_exposed" else "unknown_material_lineage")),
				"semantics": "authored start, not evolved simulation"}
			if material.has("error") and not _body_protected_capture(material):
				return _finish(row, started, "partial", _capture_failure_classification(material), material.error)
		"reset_fixture":
			var result: Dictionary = await install_fixture(fixture_id, fixture_data.duplicate(true), row)
			if not result.get("ok", false):
				return _finish(row, started, "partial" if row.admission.get("accepted", false) else "refused",
					result.get("classification", "game_observation"), result.get("error", "fixture reset refused"))
			row.native_receipt = result.get("native_receipt", {}).duplicate(true)
	if id in EDIT_IDS:
		var receipt_status: String = str(row.native_receipt.get("status", ""))
		if receipt_status != "completed":
			var terminal: Dictionary = row.native_receipt if not row.native_receipt.is_empty() else row.get("editor_receipt", row.get("history_receipt", {}))
			return _finish(row, started, "partial" if int(terminal.get("applied", 0)) > 0 else "refused",
				"cancelled" if stopped else "game_observation", str(terminal.get("error", terminal.get("reason", receipt_status))))
		row.capture_after = await capture(region)
		if row.capture_after.has("error"):
			return _finish(row, started, "partial", _capture_failure_classification(row.capture_after), row.capture_after.error)
		if id not in ["undo", "redo"]: _last_edit_region = region
	if stopped: return _finish(row, started, "partial", "cancelled", "Stop requested")
	return _finish(row, started, "completed", "game_observation", "")

func _admit(row: Dictionary, admission: Dictionary) -> void:
	row.admission = admission.duplicate(true)
	if row.get("_admission_announced", false): return
	if admission.get("accepted", false) != true and admission.get("status", "") != "queued": return
	row._admission_announced = true
	row.status = "accepted"
	action_admitted.emit(row.action.duplicate(true), admission.duplicate(true), observe())

func _finish(row: Dictionary, started: int, status: String, classification: String, error: String) -> Dictionary:
	if stopped and bench != null and host != null and not host.paused and not bench.busy(): bench.toggle_pause()
	if worker != null and worker.has_failed():
		classification = "native_failure"
		if status == "completed": status = "partial"
	row.status = status
	row.classification = classification
	row.error = error
	if worker != null and host != null: _material_history.finish(row, _capture_source(), host.paused)
	row.after = observe()
	if status == "partial" and classification != "native_failure":
		var interval: Dictionary = row.get("interval", {})
		if interval.get("progress_refusal", {}).is_empty():
			interval = row.get("actor_delivery", {}).get("release_interval", {})
		if not interval.get("progress_refusal", {}).is_empty():
			row["expected_refusal"] = interval.progress_refusal.duplicate(true)
			row.classification = "game_observation"
			if GameplayOracles.expected_boundary_refusal(row):
				row.error = str(row.expected_refusal.reason)
			else:
				# A stale publication or a different owner never downgrades failure.
				row.erase("expected_refusal")
				row.classification = classification
	row.duration_usec = Time.get_ticks_usec() - started
	if row.get("_owns_execution", false): executing = false
	row.erase("_owns_execution")
	row.erase("_admission_announced")
	return row

func capture(region: Rect2i, include_materials: bool = true) -> Dictionary:
	if worker == null or editor == null or not host.paused or editor.busy(): return {"error": "capture requires an idle paused native owner"}
	if region.size.x <= 0 or region.size.y <= 0 or not Rect2i(0, 0, 512, 512).encloses(region):
		return {"error": "capture region outside the fixture"}
	var state: Dictionary = _capture_source()
	var admission: Dictionary = worker.paint_queue({"kind": "capture", "region": region,
		"expected_generation": int(state.generation), "expected_revision": int(state.revision), "expected_tick": int(state.tick)})
	var result := {"region": json_value(region), "admission": json_value(admission), "native_receipt": {},
		"source_before": json_value(state), "source_after": {}}
	if admission.get("status", "") != "queued":
		result.source_after = _capture_source()
		result.error = "native capture refused"
		if admission.get("status") == "refused" and admission.get("reason") == GameplayOracles.FINITE_CANVAS_REFUSAL:
			var proof := _observed_progress_refusal(result.source_after)
			if not proof.is_empty(): result["progress_refusal"] = proof
			if GameplayOracles.expected_boundary_capture_refusal(result): result.error = str(admission.reason)
		return result
	if not await _until(func() -> bool: return worker.paint_state().get("receipt_ready", false), "operation_seconds", true):
		result.source_after = _capture_source()
		result.error = last_error
		result.wait_failure_classification = _wait_failure_classification()
		return result
	var receipt: Dictionary = worker.paint_take_result()
	result.source_after = _capture_source()
	var metadata: Dictionary = receipt.duplicate()
	metadata.erase("materials")
	result.native_receipt = json_value(metadata)
	var same_operation: bool = int(receipt.get("operation_id", -1)) == int(admission.operation_id) \
		and int(receipt.get("generation", -1)) == int(state.generation) \
		and int(receipt.get("observed_generation", -1)) == int(state.generation) \
		and int(receipt.get("revision", -1)) == int(state.revision) \
		and int(receipt.get("tick", -1)) == int(state.tick)
	result["source_matches"] = same_operation
	if not same_operation:
		result.error = "native capture receipt belongs to a different operation or source"
		return result
	if receipt.get("status", "") != "completed" or receipt.get("kind", "") != "capture":
		result.error = "native capture did not complete: " + str(receipt.get("reason", receipt.get("status", "missing receipt")))
		return result
	var materials: PackedInt32Array = receipt.get("materials", PackedInt32Array())
	if materials.size() != region.get_area():
		result.error = "native capture size differs from requested region"
		result.received_count = materials.size()
		return result
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(materials.to_byte_array())
	result.material_sha256 = hash.finish().hex_encode()
	result.count = materials.size()
	if include_materials: result["materials"] = Array(materials)
	last_capture = result.duplicate(true)
	return result

func _capture_source() -> Dictionary:
	var state: Dictionary = worker.paint_state()
	return {"generation": state.get("generation"), "revision": state.get("revision"), "tick": state.get("tick"),
		"paused": state.get("paused"), "failed": worker.has_failed()}

static func _body_protected_capture(captured: Dictionary) -> bool:
	var receipt: Dictionary = captured.get("native_receipt", {})
	var admission: Dictionary = captured.get("admission", {})
	var before: Dictionary = captured.get("source_before", {})
	var after: Dictionary = captured.get("source_after", {})
	return captured.has("error") and captured.get("source_matches", false) \
		and before.get("paused") == true and before.get("failed") == false \
		and after.get("paused") == true and after.get("failed") == false and before == after \
		and admission.get("status", "") == "queued" \
		and receipt.get("operation_id", -1) == admission.get("operation_id", -2) \
		and receipt.get("backend", "") == "CyberNativeCellWorld" \
		and receipt.get("kind", "") == "capture" and receipt.get("status", "") == "refused" \
		and receipt.get("reason", "") == BODY_CAPTURE_REFUSAL \
		and int(receipt.get("applied", -1)) == 0 and int(receipt.get("changed", -1)) == 0 \
		and receipt.get("generation", -1) == receipt.get("observed_generation", -2)

static func _capture_failure_classification(captured: Dictionary) -> String:
	var wait_failure: String = str(captured.get("wait_failure_classification", ""))
	if wait_failure in ["timeout", "cancelled", "native_failure"]: return wait_failure
	return "not_applicable" if _body_protected_capture(captured) \
		or GameplayOracles.expected_boundary_capture_refusal(captured) else "adapter_failure"

func _action_region(action: Dictionary) -> Rect2i:
	var id: String = action.id
	var args: Dictionary = action.get("args", {})
	if id in ["brush", "erase"]:
		var radius: int = int(args.radius)
		return Rect2i(int(args.x) - radius, int(args.y) - radius, radius * 2 + 1, radius * 2 + 1)
	if id in ["rectangle", "outline", "line", "select_region"]:
		return Rect2i(mini(int(args.x0), int(args.x1)), mini(int(args.y0), int(args.y1)),
			absi(int(args.x1) - int(args.x0)) + 1, absi(int(args.y1) - int(args.y0)) + 1)
	if id == "paste":
		var size: Vector2i = editor.clipboard.get("size", Vector2i.ZERO)
		return Rect2i(Vector2i(int(args.x), int(args.y)), size).intersection(Rect2i(0, 0, 512, 512))
	if id == "fill": return editor.selection
	if id in ["undo", "redo"]:
		var stack: Array = editor._undo_stack if id == "undo" else editor._redo_stack
		if stack.is_empty(): return Rect2i()
		# Choose only the affected area from the ordinary history record. The
		# expected materials come from independent captures, never this stack.
		var cells: PackedInt32Array = stack.back().get("cells", PackedInt32Array())
		if cells.is_empty(): return Rect2i()
		var low := Vector2i(cells[0], cells[1])
		var high := low
		for index: int in range(0, cells.size(), 3):
			var point := Vector2i(cells[index], cells[index + 1])
			low = low.min(point)
			high = high.max(point)
		return Rect2i(low, high - low + Vector2i.ONE)
	return Rect2i()

func _gesture(from: Vector2i, to: Vector2i) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = _local(from)
	bench._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = _local(to)
	motion.relative = motion.position - press.position
	bench._world_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = _local(to)
	bench._world_input(release)

func _local(cell: Vector2i) -> Vector2:
	var area: Rect2 = host.view_content_rect()
	return area.position + (Vector2(cell) + Vector2(0.5, 0.5) - host.camera_origin.floor()) * area.size / Vector2(host.current_view_size)

func _ready_for_action() -> bool:
	return bench != null and worker != null and not bench.applied.is_empty() and not bench.busy() \
		and not bool(worker.paint_state().get("busy", true)) and host.pending_microscenario_apply.is_empty()

func _settled() -> bool:
	return editor != null and not editor.busy() and not bool(worker.paint_state().get("busy", true))

func _until(predicate: Callable, watchdog: String, drain_after_stop: bool = false) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds(watchdog)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if stopped and not drain_after_stop:
			last_error = "Stop requested"
			return false
		if worker != null and worker.has_failed():
			last_error = "native World failed"
			return false
		await get_tree().process_frame
	last_error = "test watchdog expired while waiting for the actual game"
	return false

func _wait_failure_classification() -> String:
	if worker != null and worker.has_failed(): return "native_failure"
	return "cancelled" if stopped else "timeout"


func _observed_progress_refusal(state: Dictionary) -> Dictionary:
	if host == null or host.latest_snapshot == null or worker == null: return {}
	var snapshot: Variant = host.latest_snapshot
	var published: Dictionary = snapshot.lab_context
	var native: Dictionary = {"generation": state.get("generation"), "revision": state.get("revision"),
		"tick": state.get("tick"), "paused": state.get("paused"), "failed": worker.has_failed()}
	return GameplayOracles.finite_canvas_refusal(native, {
		"reason": str(published.get("workbench_refusal", "")),
		"generation": published.get("liquid_construction_receipt", {}).get("session_generation", -1),
		"tick": int(snapshot.tick_index), "serial": int(snapshot.serial),
		"paused": bool(host.paused), "failed": bool(snapshot.simulation_failed)})


func _tick_interval(ticks: int, require_actor: bool = false) -> Dictionary:
	var start: Dictionary = observe()
	var frames: int = Engine.get_process_frames()
	var refusal := {}
	var ok: bool = await _until(func() -> bool:
		var state: Dictionary = worker.paint_state()
		var published_refusal := _observed_progress_refusal(state)
		if not published_refusal.is_empty():
			refusal.merge(published_refusal, true)
			return true
		return int(state.get("tick", -1)) >= int(start.native.tick) + ticks \
			and (not require_actor or (host.physical_actor_session != null and host.physical_actor_session.tick >= int(start.actor_tick) + ticks)),
		"operation_seconds")
	var end: Dictionary = observe()
	if not refusal.is_empty():
		ok = false
		last_error = str(refusal.reason)
	return {"ok": ok, "requested_ticks": ticks, "start_tick": start.native.tick, "end_tick": end.native.tick,
		"observed_frames": Engine.get_process_frames() - frames,
		"start_actor_tick": start.actor_tick, "end_actor_tick": end.actor_tick, "progress_refusal": refusal}

func _paused_interval() -> Dictionary:
	var start: Dictionary = observe()
	var frames: int = Engine.get_process_frames()
	var until: int = Time.get_ticks_msec() + 40
	while not stopped and (Time.get_ticks_msec() < until or Engine.get_process_frames() < frames + 3):
		await get_tree().process_frame
	var end: Dictionary = observe()
	return {"start_tick": start.native.tick, "end_tick": end.native.tick,
		"observed_frames": Engine.get_process_frames() - frames,
		"start_actor_tick": start.actor_tick, "end_actor_tick": end.actor_tick}

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed and code not in _held_keys: _held_keys.append(code)
	if not pressed: _held_keys.erase(code)

func _release_keys() -> void:
	for code: int in _held_keys.duplicate(): _key(code, false)

func _on_brush_finished(token: int, receipt: Dictionary) -> void:
	_brush_receipts[token] = json_value(receipt)

func _on_history_finished(receipt: Dictionary) -> void:
	_history_receipts.append(json_value(receipt))

func request_stop() -> void:
	stopped = true
	_release_keys()
	if editor != null: editor.cancel()
	if bench != null and host != null and not host.paused and not bench.busy(): bench.toggle_pause()

func resume_actions() -> void:
	stopped = false

func close() -> void:
	request_stop()
	if host != null and is_instance_valid(host):
		host.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	host = null
	bench = null
	editor = null
	_details_button = null
	worker = null
	mounted = false
	if get_tree().get_meta("cybersand_feature", "") == "shared_workbench": get_tree().remove_meta("cybersand_feature")

# The probe is a retained native observation, explicitly marked stale after any
# source change. It is never reconstructed from authored edits or palette choice.
func _material_probe(source: Dictionary) -> Dictionary:
	if last_capture.is_empty() or last_capture.has("error") or not last_capture.get("materials") is Array:
		return {}
	var receipt: Dictionary = last_capture.get("native_receipt", {})
	var observed_key: String = "%s:%s" % [receipt.get("generation", -1), receipt.get("operation_id", -1)]
	if observed_key != _probe_key:
		_probe_key = observed_key
		_probe_counts.clear()
		for material: Variant in last_capture.materials:
			var key: String = str(int(material))
			_probe_counts[key] = int(_probe_counts.get(key, 0)) + 1
	return {"region": last_capture.get("region", []).duplicate(), "counts": _probe_counts.duplicate(),
		"generation": receipt.get("generation", -1), "revision": receipt.get("revision", -1), "tick": receipt.get("tick", -1),
		"current": receipt.get("generation") == source.get("generation") and receipt.get("revision") == source.get("revision") and receipt.get("tick") == source.get("tick"),
		"evidence_kind": "actual_native_material_capture"}

func _capabilities_for(model: String) -> Dictionary:
	if not _model_capabilities.has(model):
		_model_capabilities[model] = Setup.ActorCatalog.entry(model)
		_model_capabilities[model]["actuators"] = Gameplay.ports_for(model)
	return _model_capabilities[model]
