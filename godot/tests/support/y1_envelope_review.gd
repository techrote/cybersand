extends Control

const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
var fixture: RefCounted
var cases: Array = []
var chooser: OptionButton
var arm: OptionButton
var presentation: OptionButton
var status: Label
var paused: bool = false
var resetting: bool = false
var last_error: String = ""
var texture: ImageTexture
var observation: Dictionary = {}
var scale_factor: float = 4.0
var origin := Vector2(32,120)
var last_rows: Array = []
var native_sha256: String
var protocol_path: String
var admission_enabled: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	protocol_path = ProjectSettings.globalize_path("res://").path_join("../docs/audits/gcr001-2026-11-01/protocol.json").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--protocol="): protocol_path = argument.trim_prefix("--protocol=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not parsed is Dictionary:
		last_error = "Registered protocol unavailable: " + protocol_path
		push_error(last_error)
		return
	cases = parsed.cases.duplicate(true)
	cases.append_array(parsed.get("controls",[]))
	admission_enabled = str(parsed.get("registration","")) == Fixture.ADMISSION_TOKEN
	var panel := VBoxContainer.new()
	panel.position = Vector2(20,12)
	add_child(panel)
	var title := Label.new()
	title.text = "EXPERIMENTAL category contact — B0 / Y1 / GCR comparison — no production default change"
	panel.add_child(title)
	var row := HBoxContainer.new()
	panel.add_child(row)
	chooser = OptionButton.new()
	for spec: Dictionary in cases: chooser.add_item(str(spec.id))
	chooser.select(1)
	row.add_child(chooser)
	arm = OptionButton.new()
	arm.add_item("B0 · 0.18")
	arm.add_item("Y1 · 1.0 · experimental")
	arm.add_item("GCR · resistance / friction / torque · experimental")
	if admission_enabled: arm.add_item("GCR-A1 · admission only · R2 law unchanged")
	arm.select(1)
	row.add_child(arm)
	var reset := Button.new()
	reset.text = "Reset / apply selection (R)"
	reset.pressed.connect(reset_case)
	row.add_child(reset)
	var pause := Button.new()
	pause.text = "Pause / resume (Space)"
	pause.pressed.connect(toggle_pause)
	row.add_child(pause)
	var excavate := Button.new()
	excavate.text = "Excavate beneath body (E)"
	excavate.pressed.connect(excavate_now)
	row.add_child(excavate)
	status = Label.new()
	panel.add_child(status)
	var visual_panel := VBoxContainer.new()
	visual_panel.position = Vector2(710,180)
	add_child(visual_panel)
	var visual_title := Label.new()
	visual_title.text = "Review-only body presentation (applies immediately)"
	visual_panel.add_child(visual_title)
	presentation = OptionButton.new()
	presentation.add_item("Vector diagnostic · original")
	presentation.add_item("Cell grid · one-cell inner outline")
	presentation.add_item("Cell grid · fill only")
	presentation.item_selected.connect(func(_index: int) -> void: refresh_view())
	visual_panel.add_child(presentation)
	var visual_note := Label.new()
	visual_note.text = "Both grid modes use the material image's pixel grid.\nNo pose smoothing, physics snapping or tick/reset.\nPause, switch display, then resume to compare motion."
	visual_panel.add_child(visual_note)
	var help := Label.new()
	help.position = Vector2(20,675)
	help.text = "Select a material case and Y1/GCR, then Reset. Each reset creates a fresh native World and Rapier space.\nLeft/right: existing bounded lateral impulse. E: remove current bed. Space: pause. R: reset.\nJudge impact rigidity, sinking, late withdrawal, light/heavy support, lateral motion, edge rotation and excavation.\nAWAITING OWNER GAMEPLAY ACCEPTANCE — test automation supplies no human verdict."
	add_child(help)
	await reset_case()
	DisplayServer.window_set_title("CyberSand GCR generic-body owner review")

func toggle_pause() -> void:
	paused = not paused
	refresh_view()

func reset_case() -> void:
	if resetting or cases.is_empty(): return
	resetting = true
	if fixture != null:
		fixture.close()
		fixture = null
		await get_tree().process_frame
	fixture = Fixture.new()
	var spec: Dictionary = cases[chooser.selected].duplicate(true)
	if not await fixture.setup(self,spec,["B0","Y1","GCR","GCR-A1"][arm.selected]):
		last_error = "Review fixture setup refused"
		push_error(last_error)
	native_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
	paused = false
	last_rows = []
	resetting = false
	refresh_view()

func excavate_now() -> void:
	if fixture == null or resetting: return
	fixture.fill(fixture.left,Fixture.SURFACE,fixture.width,fixture.floor_y-Fixture.SURFACE,0)
	fixture.expected = fixture.observation()
	# Manual review can also erase the hard negative-control bed. Rapier owns
	# hard contact, so retire its old shapes at this same main-thread boundary.
	fixture.bridge.rebuild_hard_surface_colliders_from_rectangles(fixture.world.get_hard_surface_rectangles())
	refresh_view()

func _input(event: InputEvent) -> void:
	# Space is a scene shortcut even when Reset/Pause/OptionButton has focus.
	# Consume press, auto-repeat and release before GUI ui_accept can activate
	# a focused button on release and undo the scene's first toggle.
	if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo: toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_R: reset_case()
	if event.keycode == KEY_E: excavate_now()

func _physics_process(_delta: float) -> void:
	if fixture == null or resetting or paused: return
	if fixture.tick >= int(fixture.spec.ticks):
		paused = true
		refresh_view()
		return
	var horizontal: float = float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
	last_rows = fixture.step(true,horizontal if horizontal != 0 else NAN)
	refresh_view()

func refresh_view() -> void:
	if fixture == null: return
	observation = fixture.observation(true)
	var image := Image.create(fixture.width+2,fixture.floor_y+1, false,Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = observation.cells
	for y: int in range(fixture.floor_y+1):
		for x: int in range(fixture.width+2):
			var material: int = bytes[y*(fixture.width+2)+x]
			var color := Color(0.055,0.065,0.09)
			if material == 1: color = Color(0.4,0.46,0.55)
			elif material == 2: color = Color(0.85,0.68,0.35)
			elif material == 23: color = Color(0.86,0.8,0.96)
			elif material == 3: color = Color(0.2,0.5,0.95)
			elif material != 0: color = Color.from_hsv(fmod(float(material)*0.137,1.0),0.45,0.85)
			image.set_pixel(x,y,color)
	if presentation != null and presentation.selected != 0:
		for i: int in range(fixture.bodies.size()):
			var pose: Array = fixture.pose(i)
			raster_body(image,Vector2(pose[0]-fixture.left+1,pose[1]),fixture.body_size,float(pose[2]),presentation.selected == 1)
	texture = ImageTexture.create_from_image(image)
	scale_factor = minf(4.0,540.0/float(fixture.floor_y-Fixture.SURFACE+85))
	status.text = "%s | %s | tick %d / %d | %s%s\nsource %s | Godot %s | %s | native %s" % [fixture.spec.id,fixture.candidate,fixture.tick,int(fixture.spec.ticks),"paused" if paused else "running"," · scripted edit at tick600" if str(fixture.spec.get("group",""))=="support-change" else "",OS.get_environment("CYBERSAND_SOURCE_REVISION"),Engine.get_version_info().string,ProjectSettings.get_setting("physics/2d/physics_engine"),native_sha256.left(16)]
	status.text += " | admission " + str(fixture.runtime_identity().admission_variant)
	queue_redraw()

func raster_body(image: Image, center: Vector2, body_size: Vector2, angle: float, outline: bool) -> void:
	# Copied presentation only: sample a rotated rectangle at material-cell
	# centres, then enlarge the combined image with nearest filtering.
	# Never round or write the Rapier transform or authoritative native cells.
	var half: Vector2 = body_size*0.5
	var extent := Vector2(absf(cos(angle))*half.x+absf(sin(angle))*half.y,
		absf(sin(angle))*half.x+absf(cos(angle))*half.y)
	for y: int in range(maxi(0,floori(center.y-extent.y)),mini(image.get_height(),ceili(center.y+extent.y))):
		for x: int in range(maxi(0,floori(center.x-extent.x)),mini(image.get_width(),ceili(center.x+extent.x))):
			var local := (Vector2(x+0.5,y+0.5)-center).rotated(-angle)
			if absf(local.x) >= half.x or absf(local.y) >= half.y: continue
			var border: bool = outline and (absf(local.x) >= half.x-1.0 or absf(local.y) >= half.y-1.0)
			image.set_pixel(x,y,Color(0.25,0.07,0.08) if border else Color(0.95,0.18,0.2))

func _draw() -> void:
	if resetting or fixture == null or fixture.bridge == null or texture == null: return
	var crop_top: float = Fixture.SURFACE-70.0
	draw_texture_rect_region(texture,Rect2(origin,Vector2(fixture.width+2,fixture.floor_y-crop_top+1)*scale_factor),Rect2(0,crop_top,fixture.width+2,fixture.floor_y-crop_top+1))
	if presentation != null and presentation.selected != 0: return
	for i: int in range(fixture.bodies.size()):
		var pose: Array = fixture.pose(i)
		var center := origin+Vector2(pose[0]-fixture.left+1,pose[1]-crop_top)*scale_factor
		var corners := PackedVector2Array()
		for corner: Vector2 in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
			corners.append(center+(corner*fixture.body_size).rotated(float(pose[2]))*scale_factor)
		draw_colored_polygon(corners,Color(0.95,0.18,0.2))
		draw_polyline(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]),Color.WHITE,1.0)

func _exit_tree() -> void:
	if fixture != null: fixture.close()
