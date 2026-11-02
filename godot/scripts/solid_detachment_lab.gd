extends Node2D

const Session = preload("res://scripts/solid_detachment_session.gd")
const Consumer = preload("res://scripts/solid_detachment_render_consumer.gd")
const SURROUNDINGS: Array[String] = ["empty", "packed_sand", "embedded_sand", "mixed"]
const SURROUNDINGS_LABELS: Array[String] = ["dry control", "packed Sand", "partially embedded Sand", "mixed Sand / Water"]
var session: RefCounted
var consumer: RefCounted
var cells := PackedByteArray()
var channels: int = 2
var snapshot_serial: int = -1
var cell_tick: int = 0
var busy: bool = true
var surroundings: int = 0
var workers: int = 4
var conservative_displacement: bool = true
var contact_candidate: String = "legacy"
const CONTACT_CANDIDATES: Array[String] = ["legacy", "R2", "A1"]
var _captured: Dictionary = {}
var _capture_prefix: String = ""
var _title: Label
var _status: Label
var _stats: Label
var _material_stats: Label
var _frame_ms: float = 0.0

func _ready() -> void:
	get_window().size = Vector2i(1200, 850)
	RenderingServer.set_default_clear_color(Color("10171d"))
	_title = _label(Vector2(35, 22), 24)
	_title.text = "SOL-281  /  NATIVE STRUCTURAL DETACHMENT"
	_status = _label(Vector2(35, 62), 15)
	_stats = _label(Vector2(35, 730), 14)
	_material_stats = _label(Vector2(35, 755), 14)
	var help := _label(Vector2(35, 790), 13)
	help.text = "SPACE cut  |  P pause  |  R reset  |  1 dry  2 packed Sand  3 embedded  4 mixed  |  W workers 1/4\nC fresh contact arm: legacy / experimental R2 / experimental A1\nX excavate below body  |  I inspect conservation  |  ESC exit"
	var args := OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--capture" and i + 1 < args.size():
			_capture_prefix = args[i + 1]
		elif args[i].begins_with("--surroundings="):
			var choice: int = SURROUNDINGS.find(args[i].trim_prefix("--surroundings="))
			if choice >= 0:
				surroundings = choice
		elif args[i].begins_with("--candidate="):
			contact_candidate = args[i].trim_prefix("--candidate=")
		elif args[i] == "--baseline":
			conservative_displacement = false
		elif args[i] == "--workers=1":
			workers = 1
	await _open()
	if not _capture_prefix.is_empty() and not busy and session != null and session.worker != null:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_capture("anchored")
		await _release()

func _label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("cbd9df"))
	add_child(label)
	return label

func _arm_label() -> String:
	if contact_candidate == "legacy":
		return "legacy / conservative relocation" if conservative_displacement else "legacy / historical contact control"
	return "experimental GCR " + contact_candidate

func _cycle_candidate() -> void:
	if busy:
		return
	if not conservative_displacement:
		_status.text = "Experimental R2/A1 require conservative relocation; --baseline remains legacy"
		return
	contact_candidate = CONTACT_CANDIDATES[(CONTACT_CANDIDATES.find(contact_candidate) + 1) % CONTACT_CANDIDATES.size()]
	await _open() # Existing close/new-session path; never mutate a live response arm.

func _open() -> void:
	busy = true
	if session != null:
		session.close()
	session = Session.new()
	consumer = Consumer.new()
	cells.clear()
	snapshot_serial = -1
	_captured.clear()
	_title.text = "SOL-281 / NATIVE STRUCTURAL DETACHMENT / " + _arm_label()
	_material_stats.text = "520-cell RedBrick tree; one pixel hole + open concavity; one aggregate; " + SURROUNDINGS_LABELS[surroundings]
	if contact_candidate not in CONTACT_CANDIDATES or (not conservative_displacement and contact_candidate != "legacy"):
		_status.text = "Refused contact configuration: --candidate=legacy|R2|A1; --baseline requires legacy"
		busy = false
		queue_redraw()
		return
	if await session.open(self, workers, SURROUNDINGS[surroundings], conservative_displacement, contact_candidate):
		var intact: Dictionary = await session.observe_intact()
		_status.text = "%s / %s / %s / workers %d — SPACE cuts the actual native trunk" % [
			_arm_label(), str(intact.get("outcome")), SURROUNDINGS_LABELS[surroundings], workers]
		busy = false
	else:
		_status.text = session.last_error
	queue_redraw()

func _release() -> void:
	if busy or session == null or session.active:
		return
	busy = true
	_status.text = "Cutting native support; transferring exact payload and collision authority…"
	if not await session.cut_and_release():
		_status.text = session.last_error
	else:
		_status.text = _arm_label() + " / Moving Rapier aggregate / 520 exact payload cells / 6 compound shapes / " + SURROUNDINGS_LABELS[surroundings]
	busy = false

func _inspect() -> void:
	if busy or session == null:
		return
	busy = true
	var observation: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0, 0, 160, 128))
	if observation.get("ok", false):
		var material: Dictionary = observation.get("diagnostic_snapshot", {})
		var counts: Array = material.get("counts", [])
		var sand: int = int(counts[2]) if counts.size() > 2 else -1
		_material_stats.text = "Sand cells %d | Water mass %d | aggregate cells %d | native-source cells %d" % [
			sand, int(material.get("water_mass", -1)), int(observation.get("aggregate_owned", 0)),
			int(observation.get("native_source_members", 0))]
		print("SOL281_LAB_INSPECTION ", JSON.stringify(observation))
	else:
		_material_stats.text = "Inspection refused: " + str(observation.get("outcome"))
	busy = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_release()
		KEY_P:
			if not busy and session != null and session.active:
				session.set_paused(not session.physics_paused)
		KEY_R:
			if not busy:
				_open()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if not busy:
				surroundings = event.keycode - KEY_1
				_open()
		KEY_W:
			if not busy:
				workers = 1 if workers == 4 else 4
				_open()
		KEY_C:
			_cycle_candidate()
		KEY_X:
			if not busy and session != null:
				_status.text = "Excavation queued through the native owner" if session.excavate_support() else "Excavation refused"
		KEY_I:
			_inspect()
		KEY_ESCAPE:
			get_tree().quit()

func _physics_process(_delta: float) -> void:
	if session != null:
		session.physics_step()

func _process(delta: float) -> void:
	_frame_ms = delta * 1000.0
	if session == null or session.worker == null:
		return
	var snapshot: CyberSimulationSnapshot = session.worker.take_latest_snapshot(snapshot_serial)
	if snapshot != null:
		snapshot_serial = snapshot.serial
		cell_tick = snapshot.tick_index
		# Acknowledge only a complete validated material image, including each
		# dirty patch. No full-refresh-only reader may silently discard live Sand.
		if snapshot.render_snapshot_serial > consumer.last_serial:
			if consumer.consume(snapshot):
				cells = consumer.copied_pixels()
				channels = consumer.channels
				session.worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
			else:
				session.worker.request_render_full_refresh()
	var physics_ticks: int = session.bridge.manual_step_count() if session.bridge != null else 0
	var angle: float = rad_to_deg(session.body_transform().get_rotation()) if session.active else 0.0
	var coupling: Dictionary = session.coupling_metrics()
	_stats.text = "Native %d / Rapier %d | angle %.1f° | contact %d / moved %d / unresolved %d | worker %.2f ms | frame %.1f ms%s" % [
		cell_tick, physics_ticks, angle, int(coupling.get("contacts", 0)),
		int(coupling.get("displaced", 0)), int(coupling.get("unresolved", 0)),
		float(coupling.get("worker_step_ms", 0.0)), _frame_ms,
		" | PAUSED" if session.physics_paused else ""]
	queue_redraw()
	if not _capture_prefix.is_empty() and session.active:
		for t: int in [60, 120, 240]:
			if physics_ticks >= t and not _captured.has(t):
				_captured[t] = true
				_capture_after_draw("tick%03d" % t)
		if physics_ticks >= 300:
			get_tree().quit()

func _capture_after_draw(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	_capture(suffix)

func _capture(suffix: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(_capture_prefix + "-" + suffix + ".png")
	print("SOL281_RENDER_CAPTURE ", suffix, " error=", error)

func _draw() -> void:
	const ORIGIN := Vector2(35, 104)
	const SCALE := Vector2(7, 7)
	draw_set_transform(ORIGIN, 0, SCALE)
	if cells.size() >= 1024 * 128 * channels:
		for y: int in range(88):
			for x: int in range(160):
				var material: int = cells[(y * 1024 + x) * channels]
				if material == 0:
					continue
				var color := Color("b78862")
				match material:
					1: color = Color("435b66")
					2: color = Color("e5ce72")
					3: color = Color("3b8cc5")
				draw_rect(Rect2(x, y, 1, 1), color)
	if session != null and session.active:
		var transform: Transform2D = session.body_transform()
		draw_set_transform(ORIGIN + transform.origin * SCALE, transform.get_rotation(), SCALE)
		var members: PackedInt32Array = session.source_payload
		for i: int in range(0, members.size(), 6):
			var point: Vector2 = Vector2(members[i], members[i + 1]) - session.source_center
			draw_rect(Rect2(point, Vector2.ONE), Color("d2a179"))
		draw_circle(Vector2.ZERO, 0.7, Color("75cece"))
	draw_set_transform(Vector2.ZERO)

func _exit_tree() -> void:
	if session != null:
		session.close()
		session = null
