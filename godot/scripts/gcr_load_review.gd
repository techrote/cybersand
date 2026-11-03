extends "res://tests/support/y1_envelope_review.gd"

var parameters: Dictionary = {}
var parameter_status: Label
var load_controls: VBoxContainer
var budget_input: SpinBox
var rest_mode_input: OptionButton
const REST_MODES: Array[String] = ["control","P","R","C","PRC"]
var _arms: Array[String] = ["GCR-A1","GCR-LA"]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var base: String = ProjectSettings.globalize_path("res://")
	for suffix: String in ["../docs/audits/gcr-load-2026-11-02/protocol.json","../../docs/audits/gcr-load-2026-11-02/protocol.json"]:
		var path: String = base.path_join(suffix).simplify_path()
		if FileAccess.file_exists(path): protocol_path=path; break
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not parsed is Dictionary or parsed.get("registration","")!="GCR-LA-001-2026-11-02":
		last_error="Registered LA protocol unavailable"
		push_error(last_error)
		return
	for entry: Dictionary in parsed.cases:
		if entry.kind=="barrel":
			var spec: Dictionary = entry.spec.duplicate(true)
			spec.id=entry.id
			spec.ticks=1800 # Manual30s observation; registered acquisition remains1200.
			cases.append(spec)
	# Keep the original eight references and expose the new registered motion
	# mechanisms without creating a second force-law implementation.
	for suffix: String in ["../docs/audits/gcr-rest-2026-11-02/protocol.json","../../docs/audits/gcr-rest-2026-11-02/protocol.json"]:
		var rest_path: String = base.path_join(suffix).simplify_path()
		if not FileAccess.file_exists(rest_path): continue
		var rest_protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(rest_path))
		if rest_protocol is Dictionary and rest_protocol.get("registration","")=="GCR-REST-001-2026-11-02":
			for entry: Dictionary in rest_protocol.cases:
				if entry.kind=="barrel" and entry.mode=="control" and entry.comparison in ["gentle-drive","edge","salt-gentle"]:
					var spec: Dictionary = entry.spec.duplicate(true)
					spec.id="rest/"+str(entry.comparison)
					cases.append(spec)
		break
	var panel := VBoxContainer.new()
	panel.position=Vector2(20,12)
	add_child(panel)
	var title := Label.new()
	title.text="EXPERIMENTAL LOAD-AWARE BARRELS — A1 control / LA candidate — no default promotion"
	panel.add_child(title)
	var row := HBoxContainer.new()
	panel.add_child(row)
	chooser=OptionButton.new()
	for spec: Dictionary in cases: chooser.add_item(str(spec.id))
	chooser.select(3) # mass1 / speed90; preserved feel reference.
	row.add_child(chooser)
	arm=OptionButton.new()
	arm.add_item("A1 · existing GCR RFT response")
	arm.add_item("LA · experimental mass-scaled capacity")
	arm.select(1)
	row.add_child(arm)
	var reset := Button.new()
	reset.text="Reset / apply selected case (R)"
	reset.focus_mode=Control.FOCUS_NONE
	reset.pressed.connect(reset_case)
	row.add_child(reset)
	var structure := Button.new()
	structure.text="Structure comparison (F6)"
	structure.focus_mode=Control.FOCUS_NONE
	structure.pressed.connect(_structure_room)
	row.add_child(structure)
	status=Label.new()
	panel.add_child(status)
	presentation=OptionButton.new()
	presentation.add_item("Vector diagnostic")
	presentation.add_item("Cell-grid body outline")
	presentation.add_item("Cell-grid fill")
	presentation.select(1)
	presentation.position=Vector2(710,125)
	presentation.item_selected.connect(func(_index: int) -> void: refresh_view())
	add_child(presentation)
	load_controls=VBoxContainer.new()
	load_controls.position=Vector2(710,175)
	load_controls.custom_minimum_size=Vector2(450,0)
	add_child(load_controls)
	for key: String in ["gravity","mass","friction","inertia_multiplier"]:
		var caption := Label.new()
		caption.text={"gravity":"Gravity (cell/s²)","mass":"Actual barrel mass","friction":"Friction coefficient (granular and hard)","inertia_multiplier":"Inertia × rectangle value (independent)"}[key]
		load_controls.add_child(caption)
		var input := SpinBox.new()
		input.min_value=0.01 if key in ["mass","inertia_multiplier"] else 0.0
		input.max_value=368.48 if key=="gravity" else (32.0 if key=="mass" else (64.0 if key=="inertia_multiplier" else 4.0))
		input.step=.01
		input.value={"gravity":92.12,"mass":1.0,"friction":.78,"inertia_multiplier":1.0}[key]
		load_controls.add_child(input)
		parameters[key]=input
	var budget_label := Label.new()
	budget_label.text="Base impulse budget (LA/rest only)"
	load_controls.add_child(budget_label)
	budget_input=SpinBox.new()
	budget_input.min_value=5.0; budget_input.max_value=80.0; budget_input.step=1.0; budget_input.value=20.0
	load_controls.add_child(budget_input)
	rest_mode_input=OptionButton.new()
	for mode: String in REST_MODES: rest_mode_input.add_item({"control":"LA control","P":"Contact persistence","R":"Rest-aware correction","C":"Residual catch","PRC":"Persistence + correction + catch"}[mode])
	load_controls.add_child(rest_mode_input)
	var apply := Button.new()
	apply.text="Apply parameter overrides and reset"
	apply.focus_mode=Control.FOCUS_NONE
	apply.pressed.connect(_apply_parameters)
	load_controls.add_child(apply)
	parameter_status=Label.new()
	load_controls.add_child(parameter_status)
	var help := Label.new()
	help.position=Vector2(20,675)
	help.text="Space pause / resume | R restores the selected registered case | E excavates | arrows bounded lateral input\nF6 structure room (original test and isolated support); each room closes its old simulation.\nParameter overrides are exploratory. Default cases preserve the registered gravity/friction/inertia.\nAWAITING OWNER GAMEPLAY ACCEPTANCE — sleep unchanged; PR349 unmerged."
	add_child(help)
	await reset_case()
	DisplayServer.window_set_title("CyberSand load-aware barrel comparison — experimental")

func reset_case() -> void:
	if resetting or cases.is_empty(): return
	for input: SpinBox in parameters.values(): input.get_line_edit().release_focus()
	parameters.gravity.value=92.12
	parameters.mass.value=float(cases[chooser.selected].mass)
	parameters.friction.value=.78
	parameters.inertia_multiplier.value=1.0
	await _apply_parameters(false)

func _apply_parameters(read_editor: bool = true) -> void:
	if resetting: return
	resetting=true
	for input: SpinBox in parameters.values():
		if read_editor:
			input.apply()
			input.get_line_edit().release_focus()
	if fixture!=null:
		fixture.close()
		fixture=null
		await get_tree().process_frame
	fixture=Fixture.new()
	var spec: Dictionary = cases[chooser.selected].duplicate(true)
	spec.mass=float(parameters.mass.value)
	if read_editor:
		budget_input.apply()
		budget_input.get_line_edit().release_focus()
	if arm.selected==0 and (budget_input.value!=20.0 or rest_mode_input.selected!=0):
		last_error="Rest modes and budget overrides require LA selection"
		resetting=false
		return
	spec.gravity=float(parameters.gravity.value)
	spec.friction=float(parameters.friction.value)
	spec.inertia_multiplier=float(parameters.inertia_multiplier.value)
	if arm.selected==1:
		spec.rest_mode=REST_MODES[rest_mode_input.selected]
		spec.base_budget=budget_input.value
	if not await fixture.setup(self,spec,"GCR-REST" if arm.selected==1 else _arms[arm.selected]):
		last_error="Load-aware barrel setup refused: "+fixture.error
		push_error(last_error)
		resetting=false
		return
	var body: RigidBody2D = fixture.bodies[0]
	body.gravity_scale=float(parameters.gravity.value)/980.0
	PhysicsServer2D.body_set_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_FRICTION,float(parameters.friction.value))
	var inertia_scale: float = float(parameters.inertia_multiplier.value)
	if inertia_scale!=1.0:
		body.inertia=body.mass*fixture.body_size.length_squared()/12.0*inertia_scale
	fixture.bridge.refresh_all_states()
	native_sha256=FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
	parameter_status.text="Applied: mass %.3f | g %.2f\nfriction %.2f | inertia scale %.3f\n%s" % [body.mass,parameters.gravity.value,parameters.friction.value,inertia_scale,"Registered body defaults" if spec.mass==cases[chooser.selected].mass and parameters.gravity.value==92.12 and parameters.friction.value==.78 and inertia_scale==1.0 else "EXPLORATORY OVERRIDE"]
	parameter_status.text += "\nBudget %.1f | mode %s | mass scale %.1f" % [budget_input.value,REST_MODES[rest_mode_input.selected],minf(4096.0,maxf(1.0,body.mass))]
	if spec.has("drive_impulse_schedule"):
		parameter_status.text += "\nScripted small push at10s; breakaway pulse at15s"
	paused=true
	last_rows=[]
	resetting=false
	refresh_view()

func _structure_room() -> void:
	if not resetting: get_tree().change_scene_to_file("res://solid_detachment_lab.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F6:
		_structure_room()
		return
	super._unhandled_key_input(event)
