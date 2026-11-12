extends RefCounted

# IN-TOOLS #361 liquid equipment controls for the shared development workbench.
# The authored geometry and nozzle parameters live in the starting setup's
# optional `equipment` block (saved with Save named start). Operating a device
# only queues a copied command to the worker-owned device owner; status comes
# from the worker's published receipt and the native Water ledger.

const Equipment = preload("res://scripts/workbench_liquid_equipment.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Kinetic = preload("res://scripts/workbench_kinetic_mask.gd")
const KineticUsables = preload("res://scripts/kinetic_usables.gd")
const PORTS := ["q","e","s"]
const DEFAULT_VALVE := Vector2i(4,8)
const DEFAULT_DRAIN := [12,6,16]
const DEFAULT_NOZZLE := [-135.0,4.0,2]

var host: Control
var ui: Control
var serial := 0
var message := ""
var selected_valve := 0
var _desired := {"drain":false,"nozzle":false,"launcher":false,"collector":false}
var _valves_open: Array[bool] = []
var _entered: Callable
var _status := Label.new()
var _speed := SpinBox.new()
var _rate := SpinBox.new()
var _supply := SpinBox.new()
var _pump := CheckButton.new()
var _launcher_speed := SpinBox.new()
var _kinetic_preset := OptionButton.new()
var _kinetic_radius := SpinBox.new()
var _kinetic_strength := SpinBox.new()
var _kinetic_angle := SpinBox.new()
var _kinetic_hold := false
var _port_pickers: Array[OptionButton] = []
var _last_kinetic_ms := -1000
var _launcher_rate := SpinBox.new()
var _buttons := {}


func build(owner: Control, workbench: Control, row_factory: Callable, entered_position: Callable) -> void:
	host = owner
	ui = workbench
	_entered = entered_position
	var row: Control = row_factory.call(workbench)
	var title := Label.new()
	title.text = "Liquid equipment"
	title.tooltip_text = "Valves, drain and nozzle devices (#361). Load a built-in equipment start, or place devices at X/Y."
	row.add_child(title)
	_buttons.valve = _add_button(row,"Valve 1 [V]",func() -> void: toggle("valve"))
	_add_button(row,"◀ [",func() -> void: select_valve(-1))
	_add_button(row,"▶ ]",func() -> void: select_valve(1))
	_add_button(row,"All valves",toggle_all_valves)
	_buttons.drain = _add_button(row,"Drain [G]",func() -> void: toggle("drain"))
	_buttons.nozzle = _add_button(row,"Nozzle [H]",func() -> void: toggle("nozzle"))
	_add_button(row,"Aim − [J]",func() -> void: nudge_aim(-10.0))
	_add_button(row,"Aim + [K]",func() -> void: nudge_aim(10.0))
	_add_spin(row,"Speed",_speed,0.5,6.0,0.1,DEFAULT_NOZZLE[1])
	_add_spin(row,"Rate",_rate,1,Equipment.MAX_NOZZLE_RATE,1,DEFAULT_NOZZLE[2])
	_speed.value_changed.connect(func(_v: float) -> void: tune())
	_rate.value_changed.connect(func(_v: float) -> void: tune())
	_add_button(row,"Stop all",stop_all)
	row = row_factory.call(workbench)
	var solids_title := Label.new()
	solids_title.text = "Solids"
	solids_title.tooltip_text = "Launcher, collector and conveyor (BS-001). A hopper is a valve in a powder bin's floor."
	row.add_child(solids_title)
	_buttons.launcher = _add_button(row,"Launcher [L]",func() -> void: toggle("launcher"))
	_buttons.collector = _add_button(row,"Collector [O]",func() -> void: toggle("collector"))
	_add_button(row,"L aim −",func() -> void: tune_launcher(-10.0))
	_add_button(row,"L aim +",func() -> void: tune_launcher(10.0))
	_add_spin(row,"L speed",_launcher_speed,0.5,6.0,0.1,4.5)
	_add_spin(row,"L rate",_launcher_rate,1,Equipment.MAX_LAUNCHER_RATE,1,3)
	_launcher_speed.value_changed.connect(func(_v: float) -> void: tune_launcher())
	_launcher_rate.value_changed.connect(func(_v: float) -> void: tune_launcher())
	_add_button(row,"Load solids-lab",func() -> void: ui.load_equipment_start(Setup.SOLIDS_LAB_LABEL))
	row = row_factory.call(workbench)
	var kinetic_title := Label.new()
	kinetic_title.text = "Kinetic"
	kinetic_title.tooltip_text = "Kinetic mask tools: cells of Water and solids inside the mask fly. Choose the Kinetic tool to apply at the cursor (drag to repeat)."
	row.add_child(kinetic_title)
	_kinetic_preset.focus_mode = Control.FOCUS_NONE
	for key: String in Kinetic.ORDER: _kinetic_preset.add_item(str(Kinetic.PRESETS[key].label))
	row.add_child(_kinetic_preset)
	_add_spin(row,"Radius",_kinetic_radius,2,Kinetic.MAX_RADIUS,1,10)
	_add_spin(row,"Power",_kinetic_strength,0.1,3.0,0.1,1.0)
	_add_spin(row,"Angle",_kinetic_angle,-180,180,5,-90)
	_add_button(row,"Pulse emitters [T]",pulse_emitters)
	_add_button(row,"Hold emitters [Y]",hold_emitters)
	_add_button(row,"Emitter at X/Y",func() -> void: place("kinetic"))
	_add_button(row,"Load kinetic-lab",func() -> void: ui.load_equipment_start(Setup.KINETIC_LAB_LABEL))
	row = row_factory.call(workbench)
	var ports_title := Label.new()
	ports_title.text = "Flyer ports"
	ports_title.tooltip_text = "Bind a material shooter or kinetic wand to a piloted flyer's Q, E or S port. It fires along the port's outward direction while the key is held."
	row.add_child(ports_title)
	for index: int in PORTS.size():
		var label := Label.new()
		label.text = PORTS[index].to_upper()
		row.add_child(label)
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_item("Flyer default")
		for id: String in KineticUsables.ORDER: picker.add_item(str(KineticUsables.ENTRIES[id].label))
		picker.item_selected.connect(func(choice: int) -> void: set_port(index,"" if choice == 0 else KineticUsables.ORDER[choice - 1]))
		row.add_child(picker)
		_port_pickers.append(picker)
	row = row_factory.call(workbench)
	_add_button(row,"Load liquid-lab",func() -> void: ui.load_equipment_start(Setup.LIQUID_LAB_LABEL))
	_add_button(row,"Load reservoir-lab",func() -> void: ui.load_equipment_start(Setup.RESERVOIR_LAB_LABEL))
	_add_button(row,"Valve at X/Y",func() -> void: place("valve"))
	_add_button(row,"Drain at X/Y",func() -> void: place("drain"))
	_add_button(row,"Nozzle at X/Y",func() -> void: place("nozzle"))
	_add_spin(row,"Supply cells",_supply,0,Equipment.MAX_SUPPLY_CELLS,10,150)
	_pump.text = "Pump drain → nozzle"
	_pump.focus_mode = Control.FOCUS_NONE
	_pump.button_pressed = true
	row.add_child(_pump)
	_add_button(row,"Apply supply/pump",apply_supply)
	_add_button(row,"Remove equipment",remove_all)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workbench.add_child(_status)


func _add_button(row: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = caption
	button.pressed.connect(func() -> void:
		ui._commit_field()
		action.call())
	row.add_child(button)
	return button


func _add_spin(row: Control, caption: String, field: SpinBox, low: float, high: float, step: float, value: float) -> void:
	var label := Label.new()
	label.text = caption
	row.add_child(label)
	field.min_value = low
	field.max_value = high
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 70
	row.add_child(field)


func config() -> Dictionary:
	if ui == null or ui.applied.is_empty(): return {}
	return ui.applied.get("equipment",{})


func valve_count() -> int:
	return config().get("valves",[]).size()


func _refuse(reason: String) -> bool:
	message = "Equipment refused · " + reason
	return false


# Sends the authored block to the worker under a new configuration serial.
# Every device starts closed; the pipe starts with the authored supply.
func configure() -> bool:
	var authored := config()
	if authored.is_empty(): return true
	serial += 1
	_desired = {"drain":false,"nozzle":false,"launcher":false,"collector":false}
	_valves_open = []
	for _i: int in authored.valves.size(): _valves_open.append(false)
	selected_valve = clampi(selected_valve,0,maxi(authored.valves.size()-1,0))
	var nozzle: Array = authored.get("nozzle",[])
	if not nozzle.is_empty():
		_speed.set_value_no_signal(float(nozzle[3]))
		_rate.set_value_no_signal(int(nozzle[4]))
	var launcher: Array = authored.get("launcher",[])
	if not launcher.is_empty():
		_launcher_speed.set_value_no_signal(float(launcher[3]))
		_launcher_rate.set_value_no_signal(int(launcher[4]))
	var loadout: Array = authored.get("loadout",["","",""])
	for index: int in mini(_port_pickers.size(),loadout.size()):
		_port_pickers[index].select(0 if str(loadout[index]).is_empty() else KineticUsables.ORDER.find(str(loadout[index])) + 1)
	push_loadout()
	_supply.set_value_no_signal(int(authored.supply))
	_pump.set_pressed_no_signal(bool(authored.pump))
	if not host.workbench_equipment({"command":"configure","serial":serial,"config":authored.duplicate(true)}):
		return _refuse("the worker is busy; try again when the session is installed.")
	return true


func installed(_applied: Dictionary) -> void:
	message = ""
	configure()


func _send(request: Dictionary) -> bool:
	if config().is_empty(): return _refuse("no equipment in this setup. Load an equipment start or place a device.")
	if ui.busy(): return _refuse("wait for the current owner transaction.")
	request.serial = serial
	if not host.workbench_equipment(request): return _refuse("the worker queue is full or the session is changing.")
	return true


func select_valve(step: int) -> bool:
	if valve_count() == 0: return _refuse("this setup has no valves.")
	selected_valve = posmod(selected_valve + step,valve_count())
	message = "Valve %d of %d selected." % [selected_valve + 1,valve_count()]
	return true


func toggle(device: String, index: int = -2) -> bool:
	if device == "valve":
		if valve_count() == 0: return _refuse("this setup has no valves.")
		var which := selected_valve if index == -2 else index
		if which < 0 or which >= valve_count(): return _refuse("no valve %d." % (which + 1))
		var next_open: bool = not _valves_open[which]
		if not _send({"command":"valve","index":which,"open":next_open}): return false
		_valves_open[which] = next_open
		message = "Valve %d %s." % [which + 1,"opening" if next_open else "closing"]
		return true
	if config().get(device,[]).is_empty(): return _refuse("this setup has no %s." % device)
	var next: bool = not bool(_desired.get(device,false))
	var key := "on" if device in ["nozzle","launcher"] else "open"
	if not _send({"command":device,key:next}): return false
	_desired[device] = next
	message = "%s %s." % [device.capitalize(),("on" if next else "off") if device in ["nozzle","launcher"] else ("opening" if next else "closing")]
	return true


# Launcher aim and power are authored like the nozzle's and apply live.
func tune_launcher(angle_delta: float = 0.0) -> bool:
	var authored := config()
	if authored.get("launcher",[]).is_empty(): return _refuse("this setup has no launcher.")
	var launcher: Array = authored.launcher.duplicate()
	launcher[2] = wrapf(float(launcher[2]) + angle_delta,-180.0,180.0)
	launcher[3] = float(_launcher_speed.value)
	launcher[4] = int(_launcher_rate.value)
	if not _send({"command":"tune_launcher","angle":launcher[2],"speed":launcher[3],"rate":launcher[4]}): return false
	authored.launcher = launcher
	message = "Launcher aim %.0f° · speed %.1f · rate %d." % [launcher[2],launcher[3],launcher[4]]
	return true


# The actor session reads the loadout on the main thread when it packs flyer
# port intents; the worker validates every intent again before firing.
func push_loadout() -> void:
	if host == null or host.physical_actor_session == null: return
	var loadout: Array = config().get("loadout",["","",""])
	var mapping := {}
	for index: int in PORTS.size():
		if index < loadout.size() and KineticUsables.valid(loadout[index]): mapping[PORTS[index]] = loadout[index]
	host.physical_actor_session.workbench_loadout = mapping


func set_port(index: int, usable: String) -> bool:
	var placed := _edit(func(next: Dictionary) -> void: next.loadout[index] = usable)
	if placed: message = "Port %s: %s." % [PORTS[index].to_upper(),"flyer default" if usable.is_empty() else KineticUsables.ENTRIES[usable].label]
	return placed


func kinetic_choice() -> String:
	return Kinetic.ORDER[clampi(_kinetic_preset.selected,0,Kinetic.ORDER.size()-1)]


# The pointer Kinetic tool: one application at a canvas cell (throttled while
# dragging). It needs no authored equipment.
func kinetic_at(cell: Vector2i, preset: String = "") -> bool:
	if ui.applied.is_empty() or ui.busy(): return _refuse("wait for the session.")
	if Time.get_ticks_msec() - _last_kinetic_ms < 60: return false
	_last_kinetic_ms = Time.get_ticks_msec()
	var chosen := preset if not preset.is_empty() else kinetic_choice()
	if not host.workbench_equipment({"command":"kinetic_at","at":cell,"preset":chosen,"radius":int(_kinetic_radius.value),
			"strength":float(_kinetic_strength.value),"angle":float(_kinetic_angle.value)}):
		return _refuse("the worker queue is full or the session is changing.")
	message = "%s at %s." % [Kinetic.PRESETS[chosen].label,str(cell)]
	return true


func pulse_emitters() -> bool:
	if config().get("kinetics",[]).is_empty(): return _refuse("this setup has no kinetic emitters.")
	if not _send({"command":"kinetic_pulse","index":-1}): return false
	message = "Kinetic emitters pulsed."
	return true


func hold_emitters() -> bool:
	if config().get("kinetics",[]).is_empty(): return _refuse("this setup has no kinetic emitters.")
	_kinetic_hold = not _kinetic_hold
	if not _send({"command":"kinetic_hold","index":-1,"on":_kinetic_hold}): return false
	message = "Kinetic emitters %s." % ("held (repeating)" if _kinetic_hold else "released")
	return true


# Opens every valve unless all are already open, in which case it closes them.
func toggle_all_valves() -> bool:
	if valve_count() == 0: return _refuse("this setup has no valves.")
	var open: bool = _valves_open.has(false)
	if not _send({"command":"valve","index":-1,"open":open}): return false
	for i: int in _valves_open.size(): _valves_open[i] = open
	message = "All valves %s." % ("opening" if open else "closing")
	return true


func stop_all() -> bool:
	if not _send({"command":"stop"}): return false
	_desired = {"drain":false,"nozzle":false,"launcher":false,"collector":false}
	_kinetic_hold = false
	for i: int in _valves_open.size(): _valves_open[i] = false
	message = "All devices closed."
	return true


# Aim and power are authored nozzle parameters: they apply live without
# resetting the devices and are kept by Save named start.
func tune(angle_delta: float = 0.0) -> bool:
	var authored := config()
	if authored.get("nozzle",[]).is_empty(): return _refuse("this setup has no nozzle.")
	var nozzle: Array = authored.nozzle.duplicate()
	nozzle[2] = wrapf(float(nozzle[2]) + angle_delta,-180.0,180.0)
	nozzle[3] = float(_speed.value)
	nozzle[4] = int(_rate.value)
	if not _send({"command":"tune","angle":nozzle[2],"speed":nozzle[3],"rate":nozzle[4]}): return false
	authored.nozzle = nozzle
	message = "Nozzle aim %.0f° · speed %.1f · rate %d." % [nozzle[2],nozzle[3],nozzle[4]]
	return true


func nudge_aim(delta: float) -> bool:
	return tune(delta)


func _edit(change: Callable) -> bool:
	if ui.applied.is_empty() or ui.busy(): return _refuse("wait for the session.")
	var next: Dictionary = config().duplicate(true) if not config().is_empty() else Equipment.empty_config()
	change.call(next)
	var error := Equipment.validate(next,Vector2i(int(ui.applied.extent[0]),int(ui.applied.extent[1])))
	if not error.is_empty(): return _refuse(error)
	ui.applied.equipment = next
	return configure()


# Valve at X/Y adds a gate (up to eight); Drain and Nozzle replace the single one.
func place(device: String) -> bool:
	var at := Vector2i(_entered.call())
	var speed := float(_speed.value)
	var rate := int(_rate.value)
	var supply := int(_supply.value)
	var pump := _pump.button_pressed
	var placed := _edit(func(next: Dictionary) -> void:
		if device == "valve":
			next.valves.append([at.x,at.y,DEFAULT_VALVE.x,DEFAULT_VALVE.y])
		elif device == "drain":
			next.drain = [at.x,at.y,DEFAULT_DRAIN[0],DEFAULT_DRAIN[1],DEFAULT_DRAIN[2]]
		elif device == "kinetic":
			next.kinetics.append([at.x,at.y,kinetic_choice(),int(_kinetic_radius.value),float(_kinetic_strength.value),float(_kinetic_angle.value)])
		else:
			next.nozzle = [at.x,at.y,DEFAULT_NOZZLE[0],speed,rate]
			next.supply = supply
			next.pump = pump)
	if placed and device == "valve": selected_valve = valve_count() - 1
	return placed


func apply_supply() -> bool:
	return _edit(func(next: Dictionary) -> void:
		next.supply = int(_supply.value)
		next.pump = _pump.button_pressed)


func remove_all() -> bool:
	if config().is_empty(): return _refuse("no equipment to remove.")
	if ui.busy(): return _refuse("wait for the session.")
	_send({"command":"stop"})
	ui.applied.erase("equipment")
	if host.physical_actor_session != null: host.physical_actor_session.workbench_loadout = {}
	serial += 1
	# An empty block deconfigures the worker owner without leaving a device live.
	host.workbench_equipment({"command":"configure","serial":serial,"config":Equipment.empty_config()})
	message = "Equipment removed from this setup."
	return true


func refresh(context: Dictionary) -> void:
	var receipt: Dictionary = context.get("workbench_equipment",{})
	if host.physical_actor_overlay != null and host.physical_actor_overlay.has_method(&"show_liquid_equipment"):
		host.physical_actor_overlay.show_liquid_equipment(receipt if not config().is_empty() else {},selected_valve)
	if config().is_empty():
		_status.text = "Liquid equipment · none in this setup (load liquid-lab or reservoir-lab, or place devices at X/Y)" + _suffix()
		return
	if not receipt.get("configured",false) or int(receipt.get("serial",-1)) != serial:
		_status.text = "Liquid equipment · installing…" + _suffix()
		return
	var valves: Array = receipt.valves
	for i: int in mini(valves.size(),_valves_open.size()): _valves_open[i] = bool(valves[i].open)
	_buttons.valve.disabled = valves.is_empty()
	if not valves.is_empty():
		var chosen: Dictionary = valves[selected_valve]
		_buttons.valve.text = "Valve %d/%d %s [V]" % [selected_valve + 1,valves.size(),"OPEN" if chosen.open else "shut"]
	for device: String in ["drain","nozzle","launcher","collector"]:
		var state: Dictionary = receipt.get(device,{})
		var live: bool = state.get("on",false) if device in ["nozzle","launcher"] else state.get("open",false)
		_desired[device] = live
		_buttons[device].disabled = not state.get("installed",false)
		_buttons[device].text = "%s %s [%s]" % [device.capitalize(),("ON" if live else "off") if device in ["nozzle","launcher"] else ("OPEN" if live else "shut"),
			{"nozzle":"H","drain":"G","launcher":"L","collector":"O"}[device]]
	var unit := maxi(int(receipt.water_unit),1)
	var drain: Dictionary = receipt.drain
	var nozzle: Dictionary = receipt.nozzle
	var pipe: Dictionary = receipt.pipe
	var water: Dictionary = context.get("water_spray",{}).get("water",{})
	var parts := PackedStringArray()
	if not valves.is_empty():
		var states := PackedStringArray()
		var trimmed := 0
		for i: int in valves.size():
			var mark: String = {"open":"O","opening":"o","closed":"·","closing":"c"}.get(str(valves[i].state),"?")
			states.append(("[%s]" if i == selected_valve else "%s") % mark)
			trimmed += int(valves[i].trimmed_water)
		parts.append("valves %s%s" % [" ".join(states),(" · trimmed %.1f cells" % (float(trimmed)/unit)) if trimmed > 0 else ""])
	if drain.installed:
		parts.append("drain %s · %.1f cells drained%s" % ["open" if drain.open else "shut",float(drain.drained_water)/unit,
			" · PIPE FULL" if int(drain.pipe_full) > 0 and drain.open else ""])
	if nozzle.installed:
		parts.append("nozzle %s (%s) %.0f° · %.1f cells injected%s" % ["on" if nozzle.on else "off",receipt.get("nozzle_mode",""),
			float(nozzle.angle),float(nozzle.injected_water)/unit,
			(" · %d raised the level underwater" % int(nozzle.column_injections)) if int(nozzle.column_injections) > 0 else ""])
		parts.append("%s %.1f/%.0f cells" % ["pump pipe" if pipe.pump else "supply",float(pipe.stock)/unit,float(pipe.capacity)/unit])
	var launcher_state: Dictionary = receipt.get("launcher",{})
	var collector_state: Dictionary = receipt.get("collector",{})
	var stock: Dictionary = receipt.get("solid_stock",{})
	if launcher_state.get("installed",false):
		parts.append("launcher %s (%s) %.0f° · %d fired · stock %d%s" % ["on" if launcher_state.on else "off",receipt.get("solids_mode",""),
			float(launcher_state.angle),int(launcher_state.launched),int(stock.get("stock",0)),
			" · conveyor" if stock.get("conveyor",false) else ""])
	if collector_state.get("installed",false):
		var gathered := 0
		for key: Variant in collector_state.collected: gathered += int(collector_state.collected[key])
		parts.append("collector %s · %d collected" % ["open" if collector_state.open else "shut",gathered])
	var kinetic_totals: Dictionary = receipt.get("kinetic_totals",{})
	if not receipt.get("kinetics",[]).is_empty() or int(kinetic_totals.get("applications",0)) > 0:
		parts.append("kinetic %d emitters%s · %d applied · %d water + %d solids flung" % [receipt.get("kinetics",[]).size(),
			" (held)" if _kinetic_hold else "",int(kinetic_totals.get("applications",0)),int(kinetic_totals.get("water",0)),int(kinetic_totals.get("solids",0))])
	var solids_state: Dictionary = context.get("ballistic_solids",{})
	if solids_state.get("enabled",false):
		parts.append("ballistic solids %d/%d%s" % [int(solids_state.live),int(solids_state.capacity),"" if solids_state.get("closed",true) else " · LEDGER OPEN"])
	var line := "Liquid equipment · " + " · ".join(parts)
	if not water.is_empty():
		var world_cells := float(water.total)/unit
		line += " · native Water %.1f cells (ledger %s)" % [world_cells,"closed" if int(water.total) == int(water.expected) else "OPEN %d" % (int(water.total)-int(water.expected))]
		if pipe.pump: line += " · loop total %.1f cells" % (world_cells + float(pipe.stock)/unit)
	if not str(receipt.get("last_refusal","")).is_empty(): line += " · last refusal: " + str(receipt.last_refusal)
	_status.text = line + _suffix()


func _suffix() -> String:
	return "" if message.is_empty() else "  |  " + message
