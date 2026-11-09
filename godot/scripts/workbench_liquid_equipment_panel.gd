extends RefCounted

# IN-TOOLS #361 liquid equipment controls for the shared development workbench.
# The authored geometry and nozzle parameters live in the starting setup's
# optional `equipment` block (saved with Save named start). Operating a device
# only queues a copied command to the worker-owned device owner; status comes
# from the worker's published receipt and the native Water ledger.

const Equipment = preload("res://scripts/workbench_liquid_equipment.gd")
const DEFAULT_VALVE := Vector2i(4,8)
const DEFAULT_DRAIN := [12,6,16]
const DEFAULT_NOZZLE := [-135.0,4.0,2]

var host: Control
var ui: Control
var serial := 0
var message := ""
var _desired := {"valve":false,"drain":false,"nozzle":false}
var _entered: Callable
var _status := Label.new()
var _speed := SpinBox.new()
var _rate := SpinBox.new()
var _supply := SpinBox.new()
var _pump := CheckButton.new()
var _buttons := {}


func build(owner: Control, workbench: Control, row_factory: Callable, entered_position: Callable) -> void:
	host = owner
	ui = workbench
	_entered = entered_position
	var row: Control = row_factory.call(workbench)
	var title := Label.new()
	title.text = "Liquid equipment"
	title.tooltip_text = "Valve, drain and nozzle devices (#361). Load the built-in liquid-lab start, or place devices at X/Y."
	row.add_child(title)
	for spec: Array in [["valve","Valve [V]"],["drain","Drain [G]"],["nozzle","Nozzle [H]"]]:
		var device: String = spec[0]
		_buttons[device] = _add_button(row,spec[1],func() -> void: toggle(device))
	_add_button(row,"Aim − [J]",func() -> void: nudge_aim(-10.0))
	_add_button(row,"Aim + [K]",func() -> void: nudge_aim(10.0))
	_add_spin(row,"Speed",_speed,0.5,6.0,0.1,DEFAULT_NOZZLE[1])
	_add_spin(row,"Rate",_rate,1,Equipment.MAX_NOZZLE_RATE,1,DEFAULT_NOZZLE[2])
	_speed.value_changed.connect(func(_v: float) -> void: tune())
	_rate.value_changed.connect(func(_v: float) -> void: tune())
	_add_button(row,"Stop all",stop_all)
	row = row_factory.call(workbench)
	_add_button(row,"Load liquid-lab",func() -> void: ui.load_liquid_lab())
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


func _refuse(reason: String) -> bool:
	message = "Equipment refused · " + reason
	return false


# Sends the authored block to the worker under a new configuration serial.
# Every device starts closed; the pipe starts with the authored supply.
func configure() -> bool:
	var authored := config()
	if authored.is_empty(): return true
	serial += 1
	_desired = {"valve":false,"drain":false,"nozzle":false}
	var nozzle: Array = authored.get("nozzle",[])
	if not nozzle.is_empty():
		_speed.set_value_no_signal(float(nozzle[3]))
		_rate.set_value_no_signal(int(nozzle[4]))
	_supply.set_value_no_signal(int(authored.supply))
	_pump.set_pressed_no_signal(bool(authored.pump))
	if not host.workbench_equipment({"command":"configure","serial":serial,"config":authored.duplicate(true)}):
		return _refuse("the worker is busy; try again when the session is installed.")
	return true


func installed(_applied: Dictionary) -> void:
	message = ""
	configure()


func _send(request: Dictionary) -> bool:
	if config().is_empty(): return _refuse("no equipment in this setup. Load liquid-lab or place a device.")
	if ui.busy(): return _refuse("wait for the current owner transaction.")
	request.serial = serial
	if not host.workbench_equipment(request): return _refuse("the worker queue is full or the session is changing.")
	return true


func toggle(device: String) -> bool:
	var receipt: Dictionary = host.tower_context.get("workbench_equipment",{})
	if int(receipt.get("serial",-1)) == serial and receipt.get(device,{}).has("installed"):
		if not receipt[device].installed: return _refuse("this setup has no %s." % device)
	var next: bool = not bool(_desired.get(device,false))
	var key := "on" if device == "nozzle" else "open"
	if not _send({"command":device,key:next}): return false
	_desired[device] = next
	message = "%s %s." % [device.capitalize(),("on" if next else "off") if device == "nozzle" else ("opening" if next else "closing")]
	return true


func stop_all() -> bool:
	if not _send({"command":"stop"}): return false
	_desired = {"valve":false,"drain":false,"nozzle":false}
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


func place(device: String) -> bool:
	var at := Vector2i(_entered.call())
	var speed := float(_speed.value)
	var rate := int(_rate.value)
	var supply := int(_supply.value)
	var pump := _pump.button_pressed
	return _edit(func(next: Dictionary) -> void:
		if device == "valve":
			next.valve = [at.x,at.y,DEFAULT_VALVE.x,DEFAULT_VALVE.y]
		elif device == "drain":
			next.drain = [at.x,at.y,DEFAULT_DRAIN[0],DEFAULT_DRAIN[1],DEFAULT_DRAIN[2]]
		else:
			next.nozzle = [at.x,at.y,DEFAULT_NOZZLE[0],speed,rate]
			next.supply = supply
			next.pump = pump)


func apply_supply() -> bool:
	return _edit(func(next: Dictionary) -> void:
		next.supply = int(_supply.value)
		next.pump = _pump.button_pressed)


func remove_all() -> bool:
	if config().is_empty(): return _refuse("no equipment to remove.")
	if ui.busy(): return _refuse("wait for the session.")
	_send({"command":"stop"})
	ui.applied.erase("equipment")
	serial += 1
	# An empty block deconfigures the worker owner without leaving a device live.
	host.workbench_equipment({"command":"configure","serial":serial,"config":Equipment.empty_config()})
	message = "Equipment removed from this setup."
	return true


func refresh(context: Dictionary) -> void:
	var receipt: Dictionary = context.get("workbench_equipment",{})
	if host.physical_actor_overlay != null and host.physical_actor_overlay.has_method(&"show_liquid_equipment"):
		host.physical_actor_overlay.show_liquid_equipment(receipt if not config().is_empty() else {})
	if config().is_empty():
		_status.text = "Liquid equipment · none in this setup (load liquid-lab, or Valve/Drain/Nozzle at X/Y)" + _suffix()
		return
	if not receipt.get("configured",false) or int(receipt.get("serial",-1)) != serial:
		_status.text = "Liquid equipment · installing…" + _suffix()
		return
	for device: String in _buttons:
		var state: Dictionary = receipt.get(device,{})
		var live: bool = state.get("on",false) if device == "nozzle" else state.get("open",false)
		_desired[device] = live
		_buttons[device].disabled = not state.get("installed",false)
		_buttons[device].text = "%s %s [%s]" % [device.capitalize(),("ON" if live else "off") if device == "nozzle" else ("OPEN" if live else "shut"),
			{"valve":"V","drain":"G","nozzle":"H"}[device]]
	var unit := maxi(int(receipt.water_unit),1)
	var valve: Dictionary = receipt.valve
	var drain: Dictionary = receipt.drain
	var nozzle: Dictionary = receipt.nozzle
	var pipe: Dictionary = receipt.pipe
	var water: Dictionary = context.get("water_spray",{}).get("water",{})
	var parts := PackedStringArray()
	if valve.installed:
		parts.append("valve %s%s" % [valve.state,(" (%d cells waiting)" % int(valve.waiting)) if int(valve.waiting) > 0 else ""])
	if drain.installed:
		parts.append("drain %s · %.1f cells drained" % ["open" if drain.open else "shut",float(drain.drained_water)/unit])
	if nozzle.installed:
		parts.append("nozzle %s (%s) %.0f° · %.1f cells injected" % ["on" if nozzle.on else "off",receipt.get("nozzle_mode",""),
			float(nozzle.angle),float(nozzle.injected_water)/unit])
		parts.append("%s %.1f cells" % ["pump pipe" if pipe.pump else "supply",float(pipe.stock)/unit])
	var line := "Liquid equipment · " + " · ".join(parts)
	if not water.is_empty():
		var world_cells := float(water.total)/unit
		line += " · native Water %.1f cells (ledger %s)" % [world_cells,"closed" if int(water.total) == int(water.expected) else "OPEN %d" % (int(water.total)-int(water.expected))]
		if pipe.pump: line += " · loop total %.1f cells" % (world_cells + float(pipe.stock)/unit)
	if not str(receipt.get("last_refusal","")).is_empty(): line += " · last refusal: " + str(receipt.last_refusal)
	_status.text = line + _suffix()


func _suffix() -> String:
	return "" if message.is_empty() else "  |  " + message
