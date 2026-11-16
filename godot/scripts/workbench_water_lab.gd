extends RefCounted

# One Water control surface for the ordinary Shared Workbench. This owns only
# presentation: existing solver, spray, equipment and policy objects are moved
# into its tabs without creating a second native owner or changing their APIs.
# Kept non-modal so Water can be tuned while the user sees and edits the canvas.

var window: Window
var tabs: TabContainer
var pages: Dictionary = {}
var _workbench: Control

const GROUPS := [
	["solvers","Solvers & scenes","Choose a Water law, a repeatable authored scene and the native pool size. A request is not active until native acknowledges Apply."],
	["wave","Wave tuning","Experimental FreeMass-carried Wave Flow. Tune the 18 native parameters; presets stage values. The active World is reported below."],
	["transport","Transport & spray","Ballistic Water, inertial motion, face release, gas and fine scheduling are law-specific. Spray and jets are separate live effects."],
	["equipment","Equipment","Operate valves, drains and nozzles, or create a reusable equipment start. These devices are saved with the authored canvas."],
	["advanced","Advanced policy","Per-material liquid assignments, normalization and comparison policy. These are construction requests, not a second simulation."],
]

func build(workbench: Control) -> void:
	_workbench = workbench
	window = Window.new()
	window.title = "CyberSand / Water Lab"
	window.size = Vector2i(1120,730)
	window.min_size = Vector2i(740,470)
	window.transient = true
	window.exclusive = false
	# Embedded-capable like the former Wave dialogs; suitable for headless
	# qualification and physical Windows with the same Workbench owner.
	window.force_native = false
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.theme = workbench.theme
	window.hide()
	workbench.add_child(window)
	window.close_requested.connect(window.hide)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	window.add_child(margin)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation",8)
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "WATER LAB"
	heading.add_theme_font_size_override("font_size",19)
	root.add_child(heading)
	var guidance := Label.new()
	guidance.text = "One place for Water solvers, authored experiments, Wave tuning, transport and apparatus. Nothing changes natively until acknowledged."
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(guidance)

	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	pages["tabs"] = tabs
	for group: Array in GROUPS:
		var scroll := ScrollContainer.new()
		scroll.name = str(group[1])
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tabs.add_child(scroll)
		var inset := MarginContainer.new()
		inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for side: String in ["left","right","top","bottom"]:
			inset.add_theme_constant_override("margin_"+side,8)
		scroll.add_child(inset)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation",8)
		inset.add_child(body)
		var explanation := Label.new()
		explanation.text = str(group[2])
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(explanation)
		pages[str(group[0])] = body

	var separator := HSeparator.new()
	root.add_child(separator)
	# Native readback lives outside the tabs; users can always distinguish
	# STAGED/REFUSED/APPLIED while editing in any section of the Water Lab.
	var status := VBoxContainer.new()
	root.add_child(status)
	pages["status"] = status

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation",10)
	root.add_child(actions)
	_button(actions,"Apply solver / tuning",func() -> void: workbench.water_spray._apply_wave())
	_button(actions,"Restore native Wave values",func() -> void: workbench.water_spray._revert_wave())
	_button(actions,"Close Water Lab",window.hide)
	var note := Label.new()
	note.text = "Apply may rebuild the native World. Comparison Load replaces the authored canvas; save it first. Wave reconfiguration resets face momentum."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)

func _button(parent: Control, label: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = label
	control.focus_mode = Control.FOCUS_NONE
	control.pressed.connect(func() -> void:
		if _workbench != null: _workbench._commit_field()
		action.call())
	parent.add_child(control)
	return control

func select_tab(index: int) -> void:
	if tabs != null:
		tabs.current_tab = clampi(index,0,tabs.get_tab_count()-1)

func open() -> void:
	if window == null: return
	window.popup_centered_clamped(Vector2i(1120,730),0.92)
