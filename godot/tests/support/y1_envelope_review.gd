extends Control

const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
var fixture: RefCounted
var cases: Array = []
var chooser: OptionButton
var arm: OptionButton
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

func _ready() -> void:
	protocol_path = ProjectSettings.globalize_path("res://").path_join("../docs/audits/y1-envelope-2026-11-01/protocol.json").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--protocol="): protocol_path = argument.trim_prefix("--protocol=")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not parsed is Dictionary:
		last_error = "Registered protocol unavailable: " + protocol_path
		push_error(last_error)
		return
	cases = parsed.cases
	var panel := VBoxContainer.new()
	panel.position = Vector2(20,12)
	add_child(panel)
	var title := Label.new()
	title.text = "EXPERIMENTAL granular bearing — B0 / Y1 owner review — no production default change"
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
	var help := Label.new()
	help.position = Vector2(20,675)
	help.text = "Select a case and B0/Y1, then Reset. Each reset creates a fresh native World and Rapier space.\nLeft/right: existing bounded lateral impulse. E: remove current bed. Space: pause. R: reset.\nJudge impact rigidity, sinking, late withdrawal, light/heavy support, lateral motion, edge rotation and excavation.\nAWAITING OWNER GAMEPLAY ACCEPTANCE — test automation supplies no human verdict."
	add_child(help)
	await reset_case()
	DisplayServer.window_set_title("CyberSand Y1 envelope owner review")

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
	if not await fixture.setup(self,spec,"B0" if arm.selected == 0 else "Y1"):
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

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_SPACE: toggle_pause()
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
			image.set_pixel(x,y,color)
	texture = ImageTexture.create_from_image(image)
	scale_factor = minf(4.0,540.0/float(fixture.floor_y-Fixture.SURFACE+85))
	status.text = "%s | %s | tick %d / %d | %s%s\nsource %s | Godot %s | %s | native %s" % [fixture.spec.id,fixture.candidate,fixture.tick,int(fixture.spec.ticks),"paused" if paused else "running"," · scripted edit at tick600" if fixture.spec.group=="support-change" else "",OS.get_environment("CYBERSAND_SOURCE_REVISION"),Engine.get_version_info().string,ProjectSettings.get_setting("physics/2d/physics_engine"),native_sha256.left(16)]
	queue_redraw()

func _draw() -> void:
	if resetting or fixture == null or fixture.bridge == null or texture == null: return
	var crop_top: float = Fixture.SURFACE-70.0
	draw_texture_rect_region(texture,Rect2(origin,Vector2(fixture.width+2,fixture.floor_y-crop_top+1)*scale_factor),Rect2(0,crop_top,fixture.width+2,fixture.floor_y-crop_top+1))
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
