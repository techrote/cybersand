extends Node2D
const Session = preload("res://scripts/solid_detachment_session.gd")
var session: RefCounted
var cells := PackedByteArray()
var channels: int = 2
var snapshot_serial: int = -1
var cell_tick: int = 0
var busy: bool = true
var _captured: Dictionary = {}
var _capture_prefix: String = ""
var _title: Label
var _status: Label
var _stats: Label

func _ready() -> void:
	get_window().size = Vector2i(1200,820)
	RenderingServer.set_default_clear_color(Color("10171d"))
	_title = _label(Vector2(35,24),26)
	_title.text = "SOL-281  /  NATIVE SOLID DETACHMENT"
	_status = _label(Vector2(35,65),16)
	_stats = _label(Vector2(35,760),16)
	var help := _label(Vector2(35,788),13)
	help.text = "SPACE cut  ·  P pause  ·  R reset  ·  ESC exit    |    Exact compound Sand/Water coupling; reactive Wood and arbitrary desoliding not admitted"
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--capture":
		_capture_prefix = args[1]
	await _open()
	if not _capture_prefix.is_empty() and not busy:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_capture("anchored")
		await _release()

func _label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("cbd9df"))
	add_child(label)
	return label

func _open() -> void:
	busy = true
	if session != null:
		session.close()
	session = Session.new()
	cells.clear()
	snapshot_serial = -1
	_captured.clear()
	if await session.open(self,4):
		var intact: Dictionary = await session.observe_intact()
		_status.text = "ANCHORED / 520 source pixels native / " + str(intact.get("outcome")) + " — press SPACE to cut the actual trunk"
		busy = false
	else:
		_status.text = session.last_error
	queue_redraw()

func _release() -> void:
	if busy or session == null or session.active:
		return
	busy = true
	_status.text = "Native cut → reserve inactive body → transfer payload → repair terrain → acknowledge contact"
	if not await session.cut_and_release():
		_status.text = session.last_error
	else:
		_status.text = "AGGREGATE / 520 pixels native-owned / 6 exact Rapier + native proxy rectangles / Sand-Water coupling active"
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
		KEY_ESCAPE:
			get_tree().quit()

func _physics_process(_delta: float) -> void:
	if session != null:
		session.physics_step()

func _process(_delta: float) -> void:
	if session == null or session.worker == null:
		return
	var snapshot: CyberSimulationSnapshot = session.worker.take_latest_snapshot(snapshot_serial)
	if snapshot != null:
		snapshot_serial = snapshot.serial
		cell_tick = snapshot.tick_index
		if snapshot.render_full_refresh and not snapshot.cells.is_empty():
			cells = snapshot.cells
			channels = snapshot.render_channels
		# This dry fixture changes only on cut/transfer, each of which explicitly
		# requests a full native render publication. No live World is read here.
		session.worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
	var physics_ticks: int = session.bridge.manual_step_count() if session.bridge != null else 0
	var angle: float = rad_to_deg(session.body_transform().get_rotation()) if session.active else 0.0
	var coupling: Dictionary = session.coupling_metrics()
	_stats.text = "Native %d | Rapier %d | angle %.1f° | proxies %d | contacts %d / displaced %d | %s" % [
		cell_tick, physics_ticks, angle, int(coupling.get("proxy_count", 0)),
		int(coupling.get("contacts", 0)), int(coupling.get("displaced", 0)),
		"PAUSED" if session.physics_paused else "independent clocks"]
	queue_redraw()
	if not _capture_prefix.is_empty() and session.active:
		for t: int in [60,120,240]:
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
	print("SOL281_RENDER_CAPTURE ",suffix," error=",error)

func _draw() -> void:
	const ORIGIN := Vector2(35,116)
	const SCALE := Vector2(7,7)
	draw_set_transform(ORIGIN,0,SCALE)
	# Native material image is a copied immutable publication, not the authoring
	# recipe. It therefore visibly loses exactly the transferred source pixels.
	if cells.size() >= 1024 * 128 * channels:
		for y: int in range(90):
			for x: int in range(160):
				var material: int = cells[(y*1024+x)*channels]
				if material == 0:
					continue
				var color := Color("435b66") if material == 1 else Color("b78862")
				draw_rect(Rect2(x,y,1,1),color)
	if session != null and session.active:
		var t: Transform2D = session.body_transform()
		draw_set_transform(ORIGIN + t.origin*SCALE,t.get_rotation(),SCALE)
		var members: PackedInt32Array = session.source_payload
		for i: int in range(0,members.size(),6):
			var p: Vector2 = Vector2(members[i],members[i+1]) - session.source_center
			draw_rect(Rect2(p,Vector2.ONE),Color("d2a179"))
		draw_circle(Vector2.ZERO,0.7,Color("75cece"))
	draw_set_transform(Vector2.ZERO)

func _exit_tree() -> void:
	if session != null:
		session.close()
		session = null
