extends "res://scripts/gcr_crash_playground.gd"

const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const FleetOverlay = preload("res://scripts/gcr_review_fleet_overlay.gd")
const PowderTest = preload("res://scripts/gcr_powder_review_test.gd")
const RoomSource = preload("res://scripts/gcr_painting_powder_source.gd")
var room_source = RoomSource.new()
var room_source_enabled: CheckButton
var room_stream: CheckButton
var room_source_status: Label
var room_source_buttons: Array[Button] = []
var powder_test = PowderTest.new()
var powder_test_status: Label
var _restoring_defaults: bool = false
var applied_controls: Dictionary = {"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
var control_fields: Dictionary = {}
var response_select: OptionButton
var control_status: Label
var control_error: String = ""
var thruster_fire: CheckButton
var event_runtime_identity: String = ""
var spawn_position := Vector2(178,304)
var spawn_fields: Dictionary = {}
var review_column: VBoxContainer
var review_details: VBoxContainer
var roster_header: HFlowContainer

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color=Color("0a101a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	add_child(margin)
	review_column=VBoxContainer.new()
	review_column.add_theme_constant_override("separation",4)
	margin.add_child(review_column)
	var header:=HFlowContainer.new()
	roster_header=header
	header.add_theme_constant_override("h_separation",4)
	header.add_theme_constant_override("v_separation",2)
	review_column.add_child(header)
	_label(header,"EXPERIMENTAL",12,Color("f7c579"))
	for index: int in range(Fleet.count()):
		var button:=_button(header,"%d %s" % [index+1,Fleet.NAMES[index]],func() -> void: select_preset(index))
		_buttons.append(button)
	_button(header,"Reset [R]",_restart)
	_pause_button=_button(header,"Pause [P]",_toggle_pause)
	_button(header,"Camera [F]",_toggle_camera)
	_button(header,"Details",func() -> void: review_details.visible=not review_details.visible)
	_button(header,"Reload + reset",reload_flyer_definitions).tooltip_text="Reload validated JSON flyer definitions, then rebuild this craft at the saved spawn. Invalid authoring preserves the current owner."
	_button(header,"Menu [F2]",func() -> void: get_tree().change_scene_to_file("res://feature_launcher.tscn"))
	var right:=VBoxContainer.new()
	right.add_theme_constant_override("separation",2)
	right.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	review_column.add_child(right)
	_canvas=Control.new()
	_canvas.custom_minimum_size=Vector2(512,256)
	_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter=Control.MOUSE_FILTER_STOP
	right.add_child(_canvas)
	_terrain=TextureRect.new()
	_terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_terrain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_terrain.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_terrain.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_terrain)
	_overlay=Overlay.new()
	_canvas.add_child(_overlay)
	_status=_label(right,"",12,Color("e0e8ed"))
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_hint=_label(right,"",12,Color("9bb0bf"))
	_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	review_details=VBoxContainer.new()
	review_details.visible=false
	review_column.add_child(review_details)
	_title=_label(review_details,"",14,Color.WHITE)
	_tagline=_label(review_details,"",12,Color("adc0ce"))
	_controls=_label(review_details,"",12,Color("e0e8ed"))
	_timing=_label(review_details,"",12,Color("a3e8f4"))
	_label(review_details,"Gamepad: stick WASD · A/B/X Space/Ctrl/C · shoulders Q/E · Start pause. Keyboard 1–9 / Tab selects available flyers. B bursts at the fixed source; Shift boosts; Ctrl brakes.",12,Color("adc0ce"))

func _button(parent: Node, text: String, pressed: Callable) -> Button:
	var button: Button=super._button(parent,text,pressed)
	button.custom_minimum_size.y=24
	button.add_theme_font_size_override("font_size",12)
	for state: String in ["normal","hover","pressed"]:
		var style: StyleBoxFlat=button.get_theme_stylebox(state).duplicate()
		style.content_margin_left=6
		style.content_margin_right=6
		style.set_corner_radius_all(2)
		button.add_theme_stylebox_override(state,style)
	return button

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	return super._label(parent,text,mini(font_size,13),color)

func _ready() -> void:
	super._ready()
	_overlay.free()
	_overlay = FleetOverlay.new()
	_canvas.add_child(_overlay)
	_build_comparison_controls()
	select_preset(0)
	DisplayServer.window_set_title("CyberSand — flyer budget playground + painting")
	call_deferred("_set_review_window_title")

func _set_review_window_title() -> void:
	DisplayServer.window_set_title("CyberSand — flyer review · "+OS.get_environment("CYBERSAND_SOURCE_REVISION").left(12))

func _build_comparison_controls() -> void:
	var column: Control = review_column
	var panel := VBoxContainer.new()
	column.add_child(panel)
	column.move_child(panel,1)
	panel.add_theme_constant_override("separation",2)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",8)
	row.add_theme_constant_override("v_separation",2)
	panel.add_child(row)
	response_select=OptionButton.new()
	response_select.focus_mode=Control.FOCUS_NONE
	response_select.add_theme_font_size_override("font_size",12)
	response_select.add_item("LA / A1")
	response_select.add_item("RFT / R2 · fixed 20")
	response_select.add_item("LA · events OFF")
	response_select.add_item("LA · selective arrivals")
	response_select.tooltip_text="Experimental response. Changes apply with Apply/reset; native material laws remain unchanged."
	response_select.set_item_tooltip(3,"Retained experiment: misses registered creep, finite-batch loading and late edge-rebound gates. Recovers continuous-stream response. Compare with LA and events OFF; applies on reset.")
	response_select.set_item_tooltip(2,"Reduces measured bank burial. Moving-grain loading and torque are deficient; late barrel motion can increase. Compare with LA. Applies on reset.")
	response_select.select(["LA","RFT","LA-EVENT-OFF","LA-SELECTIVE"].find(applied_controls.response))
	row.add_child(response_select)
	for key: String in ["budget","mass_multiplier","inertia_multiplier","thrust_multiplier","torque_multiplier","boost_multiplier"]:
		var field := HBoxContainer.new()
		field.add_theme_constant_override("separation",3)
		row.add_child(field)
		_label(field,{"budget":"Budget","mass_multiplier":"Mass ×","inertia_multiplier":"Inertia ×","thrust_multiplier":"Thrust ×","torque_multiplier":"Torque ×","boost_multiplier":"Shift ×"}[key],12,Color("adc0ce"))
		var input := SpinBox.new()
		input.min_value=5.0 if key=="budget" else (1.0 if key=="boost_multiplier" else (0.0 if key in ["thrust_multiplier","torque_multiplier"] else 0.01))
		input.max_value=80.0 if key=="budget" else (8.0 if key=="boost_multiplier" else 64.0)
		input.step=1.0 if key=="budget" else (0.25 if key=="boost_multiplier" else 0.01)
		input.value=float(applied_controls.get(key,2.0 if key=="boost_multiplier" else 1.0))
		input.custom_minimum_size.x=86
		input.add_theme_font_size_override("font_size",12)
		input.get_line_edit().add_theme_font_size_override("font_size",12)
		input.get_line_edit().focus_entered.connect(_cancel_input)
		input.tooltip_text="Staged %s; Apply rebuilds terrain and flyer at the saved spawn." % key
		field.add_child(input)
		control_fields[key]=input
	_button(row,"Apply + reset",apply_controls)
	_button(row,"Defaults",restore_controls)
	var source_row := HFlowContainer.new()
	source_row.add_theme_constant_override("h_separation",6)
	source_row.add_theme_constant_override("v_separation",2)
	panel.add_child(source_row)
	_label(source_row,"Reset spawn",12,Color("adc0ce"))
	for axis: String in ["x","y"]:
		var field:=HBoxContainer.new()
		field.add_theme_constant_override("separation",2)
		source_row.add_child(field)
		_label(field,axis.to_upper(),12,Color("adc0ce"))
		var input:=SpinBox.new()
		input.min_value=22; input.max_value=1002 if axis=="x" else 475
		input.step=0.01; input.value=spawn_position.x if axis=="x" else spawn_position.y
		input.custom_minimum_size.x=96
		input.get_line_edit().add_theme_font_size_override("font_size",12)
		input.get_line_edit().focus_entered.connect(_cancel_input)
		input.tooltip_text="Flyer centre in world cells (0.01 precision), applied on reset/selection. Saved across response and craft changes."
		field.add_child(input)
		spawn_fields[axis]=input
	_button(source_row,"Use flyer",capture_spawn_position).tooltip_text="Save the current centre without moving the flyer. Reset starts upright with zero velocity."
	_button(source_row,"Default spawn",reset_spawn_position)
	thruster_fire=CheckButton.new()
	thruster_fire.text="Fire"
	thruster_fire.add_theme_font_size_override("font_size",12)
	thruster_fire.focus_mode=Control.FOCUS_NONE
	thruster_fire.tooltip_text="Live developer toggle. Fire reacts with the world; blocked nozzles do not overwrite material."
	thruster_fire.toggled.connect(func(enabled: bool) -> void:
		if runtime != null: runtime.set_review_thruster_fire(enabled))
	source_row.add_child(thruster_fire)
	room_source_enabled=CheckButton.new()
	room_source_enabled.text="Powder source"
	room_source_enabled.add_theme_font_size_override("font_size",12)
	room_source_enabled.focus_mode=Control.FOCUS_NONE
	room_source_enabled.toggled.connect(_toggle_room_source)
	source_row.add_child(room_source_enabled)
	room_source_buttons.append(_button(source_row,"Place above flyer",place_room_source))
	room_source_buttons[0].tooltip_text="Capture palette material and a fixed world origin above the flyer."
	room_source_buttons.append(_button(source_row,"Burst [B]",emit_room_burst))
	room_stream=CheckButton.new()
	room_stream.text="Stream ≤10s"
	room_stream.add_theme_font_size_override("font_size",12)
	room_stream.focus_mode=Control.FOCUS_NONE
	room_stream.toggled.connect(set_room_stream)
	source_row.add_child(room_stream)
	var powder_row := HFlowContainer.new()
	powder_row.add_theme_constant_override("h_separation",6)
	panel.add_child(powder_row)
	_label(powder_row,"Isolated Kestrel fixtures:",12,Color("adc0ce"))
	_button(powder_row,"Burst test",func() -> void: start_powder_test("burst"))
	_button(powder_row,"Stream test",func() -> void: start_powder_test("stream"))
	_button(powder_row,"Painting room",return_to_painting)
	powder_test_status=_label(review_details,"",12,Color("adc0ce"))
	powder_test_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	room_source_status=_label(panel,"Room source off. Choose a powder in the palette, then place above any flyer.",13,Color("adc0ce"))
	room_source_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	control_status=_label(panel,"",12,Color("f7c579"))
	control_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://addons/cybersand_native/runtime-provenance.json" if OS.get_name()=="Windows" else "res://addons/cybersand_native/runtime-provenance.linux.json"))
	if provenance is Dictionary:
		var actual: String = FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
		event_runtime_identity="Native %s · binary %s %s · room %s" % [str(provenance.get("source_commit","unknown")).left(8),actual.left(12),"verified" if actual==provenance.get("sha256") else "MISMATCH",FileAccess.get_sha256("res://scripts/gcr_fleet_playground.gd").left(12)]

func _release_edit_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		if focused is LineEdit and focused.get_parent() is SpinBox: focused.get_parent().apply()
		focused.release_focus()

func _valid_room_spawn(point: Vector2, index: int) -> bool:
	if not preload("res://scripts/physical_actor_arena.gd").valid_review_fleet_spawn(point,index): return false
	for shape: Dictionary in Fleet.collision_rects(index):
		var hull:=Rect2(point+Vector2(shape.center)-Vector2(shape.size)*0.5,Vector2(shape.size))
		for rect: Rect2i in crash_hard_rects():
			if hull.intersects(Rect2(rect)): return false
	return true

func _presentation_preset() -> StringName: return &"arcadelander"
func _presentation_color() -> Color: return Fleet.COLORS[selected] if Fleet.valid_index(selected) else Color.WHITE
func _course_targets() -> PackedVector2Array: return PackedVector2Array()

func reload_flyer_definitions(manifest_path: String = Fleet.DEFAULT_MANIFEST) -> bool:
	_release_edit_focus()
	var previous: Dictionary=Fleet.registry_snapshot()
	var id: String=Fleet.stable_id(selected)
	if not Fleet.reload_definitions(manifest_path):
		control_error="Flyer reload refused: "+Fleet.last_error()
		_present(runtime.snapshot(),true)
		return false
	var target: int=Fleet.index_for_id(id)
	if target<0 or not select_preset(target):
		Fleet.restore_registry(previous)
		if control_error.is_empty(): control_error="Reload refused: selected flyer no longer exists."
		_present(runtime.snapshot(),true)
		return false
	# Rebuild only the roster controls after successful construction. The rest
	# of the compact UI, source settings and saved spawn remain in place.
	for button: Button in _buttons:
		roster_header.remove_child(button)
		button.queue_free()
	_buttons.clear()
	for index: int in range(Fleet.count()):
		var button:=_button(roster_header,"%d %s" % [index+1,Fleet.NAMES[index]],func() -> void: select_preset(index))
		roster_header.move_child(button,index+1)
		_buttons.append(button)
	_present(runtime.snapshot(),true)
	return true

func set_spawn_position(point: Vector2) -> bool:
	# Store the same authoring precision shown by the fields, so capturing a
	# subpixel pose cannot silently change its spawn on the following reset.
	if point.is_finite(): point=point.snapped(Vector2(0.01,0.01))
	if not _valid_room_spawn(point,selected):
		control_error="Spawn refused: upright hull must fit inside the room without overlapping hard terrain."
		if control_status!=null: control_status.text=control_error
		return false
	spawn_position=point
	if not spawn_fields.is_empty():
		spawn_fields.x.set_value_no_signal(point.x)
		spawn_fields.y.set_value_no_signal(point.y)
	control_error=""
	return true

func capture_spawn_position() -> bool:
	_release_edit_focus()
	if runtime==null or not runtime.active() or runtime._arena==null: return false
	var body: RigidBody2D=runtime._arena.session.bodies()[0]
	var pose: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	return set_spawn_position(pose.origin)

func reset_spawn_position() -> void:
	_release_edit_focus()
	set_spawn_position(Vector2(178,304))

func apply_controls() -> bool:
	_release_edit_focus()
	control_error=""
	var staged: Dictionary = {"response":["LA","RFT","LA-EVENT-OFF","LA-SELECTIVE"][response_select.selected]}
	for key: String in control_fields: staged[key]=control_fields[key].value
	if staged.response=="RFT" and staged.budget!=20.0:
		control_error="RFT reference uses budget 20. Select LA to compare budgets 20 / 40 / 80."
		control_status.text=control_error
		return false
	var previous: Dictionary = applied_controls
	var previous_arena_id: int = runtime._arena.get_instance_id() if is_instance_valid(runtime._arena) else 0
	applied_controls=staged
	var restarted: bool = _reset_powder_test(powder_test.mode) if powder_test.active() and not _restoring_defaults else select_preset(selected)
	if not restarted:
		# A refused constructor retains the old owner. A later setup failure has
		# already installed the new owner, so its settings must remain labelled.
		if is_instance_valid(runtime._arena) and runtime._arena.get_instance_id()==previous_arena_id: applied_controls=previous
		if powder_test.active():
			runtime.set_paused(true)
			_pause_button.text="Resume  ·  P"
		if control_error.is_empty(): control_error=runtime.last_error if not runtime.last_error.is_empty() else "Review setup refused."
		_present(runtime.snapshot(),true)
		return false
	return true

func restore_controls() -> void:
	response_select.select(0)
	control_fields.budget.value=20.0
	control_fields.mass_multiplier.value=1.0
	control_fields.inertia_multiplier.value=1.0
	control_fields.thrust_multiplier.value=1.0
	control_fields.torque_multiplier.value=1.0
	control_fields.boost_multiplier.value=2.0
	_restoring_defaults=true
	apply_controls()
	_restoring_defaults=false

func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE]:
			_release_edit_focus()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key: Key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.pressed and not event.echo and key>=KEY_1 and key<=KEY_9:
			var index: int=int(key-KEY_1)
			if Fleet.valid_index(index): select_preset(index)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo and key==KEY_TAB:
			if Fleet.count()>0: select_preset(posmod(selected+(-1 if event.shift_pressed else 1),Fleet.count()))
			get_viewport().set_input_as_handled()
			return
		if key==KEY_B:
			if event.pressed and not event.echo and _focused and runtime!=null and runtime.active() and not runtime.failed and not powder_test.active(): emit_room_burst()
			get_viewport().set_input_as_handled()
			return
	# Review buttons do not revoke a held flight command. SpinBox editor focus
	# cancels immediately; OS focus loss/pause/reset keep their existing rearm.
	if event is InputEventMouseButton and not _content_rect().has_point(_canvas.get_local_mouse_position()): return
	super._input(event)

func _review_ports() -> Dictionary:
	# Keep independent buttons: Q+E may dispense both sides, W+S may
	# thrust while dropping powder. Signed steering axes cannot retain this.
	var ports: Dictionary = {"q":Input.is_physical_key_pressed(KEY_Q),"e":Input.is_physical_key_pressed(KEY_E),"s":Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)}
	var pads: Array[int] = Input.get_connected_joypads()
	if not pads.is_empty():
		var pad: int = pads[0]
		ports.q = ports.q or Input.is_joy_button_pressed(pad,JOY_BUTTON_LEFT_SHOULDER)
		ports.e = ports.e or Input.is_joy_button_pressed(pad,JOY_BUTTON_RIGHT_SHOULDER)
		ports.s = ports.s or Input.get_joy_axis(pad,JOY_AXIS_LEFT_Y) > 0.2
	ports["boost"]=Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)
	return ports

func _sample_action() -> Dictionary:
	if powder_test.active(): return {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":0.0,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
	var action: Dictionary = super._sample_action()
	var gamepad_brake: bool=false
	var pads: Array[int]=Input.get_connected_joypads()
	if not pads.is_empty(): gamepad_brake=Input.is_joy_button_pressed(pads[0],JOY_BUTTON_B)
	action=remap_fleet_brake(action,Input.is_physical_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_CTRL),gamepad_brake)
	if int(Fleet.capabilities(selected).get("dispenser_s",0))!=0:
		# Kestrel S is a dispenser rather than reverse. Retain W when both
		# keys are held; primary/Space independently keeps its normal thrust.
		var move: Vector2 = action.move
		move.y=minf(0.0,move.y)
		if _thrust_up_pressed(): move.y=-1.0
		action.move=move
	return action

static func remap_fleet_brake(action: Dictionary, control_held: bool, gamepad_brake: bool = false) -> Dictionary:
	var result: Dictionary=action.duplicate(true)
	result.secondary=control_held or gamepad_brake
	return result

func _thrust_up_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)

func _submit_action(action: Dictionary) -> bool:
	if powder_test.active(): return false
	return runtime.submit_review_action(action,_review_ports())

func advance_frame(action: Dictionary, allowed: bool) -> void:
	if powder_test.active():
		# No leased command: even neutral fleet commands would apply authored drag.
		if runtime == null or runtime.paused or runtime.failed: return
		if not powder_test.before_step(runtime._arena._world):
			runtime.set_paused(true)
			_pause_button.text="Resume  ·  P"
			_present(runtime.snapshot(),true)
			return
		runtime.cancel()
		var before: int = runtime.tick
		var state: Dictionary = runtime.step()
		if runtime.tick==before+1: powder_test.after_step()
		else: powder_test.error="owner step did not advance exactly once"
		if runtime.failed or not powder_test.error.is_empty() or powder_test.ticks>=PowderTest.TOTAL_TICKS:
			runtime.set_paused(true)
			_pause_button.text="Resume  ·  P"
		_present(state,true)
		return
	# A held dispenser must be released after focus/edit/pause cancellation,
	# even when Q+E cancels the signed trim or Kestrel S leaves move neutral.
	var ports: Dictionary = _review_ports()
	if _rearm and (ports.q or ports.e or ports.s or ports.get("boost",false)): allowed=false
	if room_source.armed and runtime!=null and runtime.active() and not runtime.paused and not runtime.failed:
		if not room_source.before_step(runtime._arena):
			control_error=room_source.error
			_stop_room_source()
	super.advance_frame(action,allowed)

func select_preset(index: int) -> bool:
	if not Fleet.valid_index(index): return false
	_release_edit_focus()
	var point: Vector2=spawn_position if spawn_fields.is_empty() else Vector2(spawn_fields.x.value,spawn_fields.y.value)
	if not _valid_room_spawn(point,index):
		control_error="Spawn refused for %s: choose a centre clear of hard terrain and room walls." % Fleet.NAMES[index]
		if _status!=null: _status.text=control_error
		return false
	_cancel_input()
	if not runtime.configure_review_fleet(index,applied_controls,point):
		_status.text = "Fleet refused: "+runtime.last_error
		if powder_test.active():
			runtime.set_paused(true)
			_pause_button.text="Resume  ·  P"
		return false
	spawn_position=point
	control_error=""
	powder_test.clear()
	_reset_room_source(false)
	if thruster_fire != null: thruster_fire.disabled=false
	runtime.set_review_thruster_fire(thruster_fire != null and thruster_fire.button_pressed)
	selected = index
	_target = 0
	_lap_ticks = 0
	_lap_started = false
	_last_draw_tick = -1
	_last_packet_epoch = -1
	_pause_button.text = "Pause  ·  P"
	if _surface != null: _surface.set_render_enabled(true)
	var seeded: bool = seed_crash_room()
	if not seeded:
		runtime.set_paused(true)
		control_error="Painting room authoring refused."
	return seeded

func _check_targets(_state: Dictionary) -> void:
	pass # Free play has no course gate or score.

func start_powder_test(mode: String) -> bool:
	if mode not in ["burst","stream"]: return false
	_release_edit_focus()
	var staged: Dictionary = {"response":["LA","RFT","LA-EVENT-OFF","LA-SELECTIVE"][response_select.selected]}
	for key: String in control_fields: staged[key]=control_fields[key].value
	if staged.response=="RFT":
		control_error="Powder tests compare LA, events OFF and selective arrivals. Select one of those responses."
		_present(runtime.snapshot(),true)
		return false
	var previous: Dictionary = applied_controls
	var previous_arena_id: int = runtime._arena.get_instance_id() if is_instance_valid(runtime._arena) else 0
	applied_controls=staged
	if not _reset_powder_test(mode):
		if is_instance_valid(runtime._arena) and runtime._arena.get_instance_id()==previous_arena_id: applied_controls=previous
		if powder_test.active():
			runtime.set_paused(true)
			_pause_button.text="Resume  ·  P"
		_present(runtime.snapshot(),true)
		return false
	return true

func _reset_powder_test(mode: String) -> bool:
	if applied_controls.response=="RFT":
		control_error="Powder tests require LA, events OFF or selective arrivals."
		return false
	_cancel_input()
	if not runtime.configure_review_powder_test(applied_controls):
		control_error=runtime.last_error
		return false
	selected=2
	if thruster_fire != null:
		thruster_fire.button_pressed=false
		thruster_fire.disabled=true
	runtime.set_review_thruster_fire(false)
	_reset_room_source(true)
	var setup_ok: bool = powder_test.setup(runtime._arena,mode,applied_controls)
	runtime.set_paused(true)
	_pause_button.text="Resume  ·  P"
	_target=0; _lap_ticks=0; _lap_started=false
	_last_draw_tick=-1; _last_packet_epoch=-1
	_follow=true
	control_error="" if setup_ok else powder_test.error
	if _surface != null: _surface.set_render_enabled(true)
	_present(runtime.snapshot(),true)
	return setup_ok

func return_to_painting() -> bool:
	return select_preset(selected)

func powder_test_receipt() -> Dictionary:
	return powder_test.receipt(runtime.paused if runtime!=null else true)

func _restart() -> void:
	if powder_test.active(): _reset_powder_test(powder_test.mode)
	else: super._restart()

func _toggle_pause() -> void:
	if powder_test.active() and (powder_test.modified or not powder_test.error.is_empty() or powder_test.ticks>=PowderTest.TOTAL_TICKS):
		control_error="Reset the powder test with R or Apply before running again."
		_present(runtime.snapshot(),true)
		return
	super._toggle_pause()

func _notification(what: int) -> void:
	super._notification(what)
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: _stop_room_source()
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and powder_test.active() and runtime!=null and runtime.active():
		runtime.set_paused(true)
		if _pause_button!=null: _pause_button.text="Resume  ·  P"

func paint_at(cell: Vector2i, material: int) -> bool:
	if powder_test.active() and runtime!=null and runtime._arena!=null and CRASH_VIEW.grow(-brush_radius-6).has_point(cell) and material in MATERIALS:
		powder_test.modified=true
		runtime.set_paused(true)
		_pause_button.text="Resume  ·  P"
	return super.paint_at(cell,material)

func _present(state: Dictionary, force: bool = false) -> void:
	super._present(state,force)
	if _surface == null: return
	_title.text = Fleet.NAMES[selected]
	_title.add_theme_color_override("font_color",Fleet.COLORS[selected])
	_tagline.text = Fleet.DESCRIPTIONS[selected]
	_controls.text = Fleet.controls(selected)
	_overlay.preset = &"arcadelander"
	if _overlay is FleetOverlay: _overlay.fleet_index = selected
	for index: int in range(_buttons.size()):
		_buttons[index].modulate = Fleet.COLORS[selected] if index==selected else Color.WHITE
	_timing.text = "FLIGHT FLEET  ·  %s  ·  F overview / follow" % Fleet.NAMES[selected]
	if control_status != null and runtime._arena != null:
		var body: RigidBody2D = runtime._arena.session.bodies()[0]
		var profile: Dictionary = runtime._arena.session._rigs[0]._profile
		control_status.text="%s · %s / %.0f · mass %.5f · inertia %.5f · force %.3f · torque %.3f · Shift ×%.2f · spawn (%.2f, %.2f)" % [Fleet.NAMES[selected],applied_controls.response,applied_controls.budget,body.mass,body.inertia,profile.fleet_force,profile.fleet_torque,float(applied_controls.get("boost_multiplier",2.0)),spawn_position.x,spawn_position.y]
		if not control_error.is_empty(): control_status.text+="\n"+control_error
		control_status.tooltip_text="Applied settings; Apply/reset rebuilds terrain and craft. Saved spawn persists for this room session. Ctrl brakes. Material laws and sleep unchanged.\n"+event_runtime_identity
		_timing.text+="\n"+event_runtime_identity
		_timing.text+="\nFlyer %s · definition %s · registry %s" % [Fleet.stable_id(selected),str(profile.get("fleet_definition_hash","")).left(16),Fleet.registry_hash().left(16)]
		_timing.text+="\nAttitude gain %.2f · damping %.2f · angular acceleration %.2f · trim ±%.1f°" % [float(profile.get("fleet_attitude_gain",10.0)),float(profile.get("fleet_attitude_damping",4.0)),float(profile.fleet_turn_accel),rad_to_deg(float(profile.get("fleet_trim_angle",.4)))]
	if _overlay is FleetOverlay:
		_overlay.room_source_origin=Vector2(room_source.origin) if room_source.armed else Vector2.INF
	if room_source_status!=null:
		room_source_enabled.set_pressed_no_signal(room_source.armed)
		room_stream.set_pressed_no_signal(room_source.stream_enabled)
		if room_source.armed:
			var material_name: String=MATERIAL_NAMES[MATERIALS.find(room_source.material)]
			room_source_status.text="Source %s at (%d,%d) · fixed in world · %d inserted / %d attempted (%d blocked) · stream %d/600%s" % [material_name,room_source.origin.x,room_source.origin.y,room_source.inserted,room_source.attempted,room_source.blocked,room_source.stream_ticks," · burst queued" if room_source.burst_queued else ""]
		else: room_source_status.text="Source off · palette → Place / B to arm · fixed world origin · focus loss disarms"
		if not room_source.error.is_empty(): room_source_status.text+=" "+room_source.error
	if powder_test_status!=null:
		if powder_test.active():
			powder_test_status.text="%s · %s · tick %d/%d · inserted %d / attempted %d (%d blocked) · Kestrel, Sand, body gravity OFF, pilot OFF. P run/pause; R repeat." % [powder_test.mode.to_upper(),powder_test.status(runtime.paused),powder_test.ticks,PowderTest.TOTAL_TICKS,powder_test.inserted,powder_test.attempted,powder_test.blocked]
			_hint.text="Manual painting remains available; editing pauses and marks this run modified. Reset to compare. Response/physical controls apply through a fresh paused reset."
			_controls.text="LOADING TEST\nBody gravity OFF · pilot OFF\nSand falls under native rules\nP  Run / pause\nR  Repeat from tick zero\nPainting room  Return to flight"
		else:
			powder_test_status.text="Repeatable loading tests: Kestrel, body gravity off, pilot off. P starts/pauses; R repeats."
			_hint.text="WASD / Space fly · Shift boost · Ctrl brake · B burst · LMB paint / RMB erase · wheel brush · R reset at saved spawn · P pause · F camera"
		if powder_test.active():
			_hint.text=powder_test_status.text

func _reset_room_source(disabled: bool) -> void:
	room_source.clear()
	if room_source_enabled!=null:
		room_source_enabled.set_pressed_no_signal(false)
		room_source_enabled.disabled=disabled
	if room_stream!=null:
		room_stream.set_pressed_no_signal(false)
		room_stream.disabled=disabled
	for button: Button in room_source_buttons: button.disabled=disabled

func _stop_room_source() -> void:
	room_source.stop()
	if room_source_enabled!=null: room_source_enabled.set_pressed_no_signal(false)
	if room_stream!=null: room_stream.set_pressed_no_signal(false)

func _toggle_room_source(enabled: bool) -> void:
	if enabled: place_room_source()
	else: _stop_room_source()
	if runtime!=null and runtime.active(): _present(runtime.snapshot(),true)

func place_room_source() -> bool:
	if powder_test.active() or runtime==null or runtime._arena==null: return false
	var rig=runtime._arena.session._rigs[0]
	var body: RigidBody2D=rig.bodies()[0]
	var pose: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	var half: Vector2=rig.body_sizes()[0]*0.5
	var top: float=pose.origin.y-absf(sin(pose.get_rotation()))*half.x-absf(cos(pose.get_rotation()))*half.y
	var point:=Vector2i(floori(pose.origin.x)-2,floori(top)-48)
	var accepted: bool=room_source.configure(point,paint_material)
	control_error="" if accepted else room_source.error
	if room_source_enabled!=null: room_source_enabled.set_pressed_no_signal(accepted)
	if room_stream!=null: room_stream.set_pressed_no_signal(false)
	_present(runtime.snapshot(),true)
	return accepted

func emit_room_burst() -> bool:
	if powder_test.active(): return false
	_release_edit_focus()
	if not room_source.armed and not place_room_source(): return false
	var accepted: bool=room_source.queue_burst()
	_present(runtime.snapshot(),true)
	return accepted

func set_room_stream(enabled: bool) -> bool:
	if powder_test.active(): return false
	if enabled and not room_source.armed and not place_room_source():
		room_stream.set_pressed_no_signal(false)
		return false
	var accepted: bool=room_source.set_stream(enabled)
	if room_stream!=null: room_stream.set_pressed_no_signal(accepted and enabled)
	_present(runtime.snapshot(),true)
	return accepted

func room_source_receipt() -> Dictionary: return room_source.receipt()
