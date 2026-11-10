extends SceneTree

# Kinetic usables on workbench flyer ports, through the real Main keyboard path
# (FocusHost replaces only the focused-window predicate, as in
# test_workbench_input.gd). kinetic-lab binds Q gravel shotgun, E water cannon
# and S blast glove. Requires a native runtime built from this source.
const Setup = preload("res://scripts/workbench_setup.gd")
const KineticUsables = preload("res://scripts/kinetic_usables.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
class FocusHost extends "res://scripts/main.gd":
	var test_focus := true
	func _actor_window_has_focus() -> bool: return test_focus

var host: Control
var ui: Control
var checks := 0
var failures: Array[String] = []
var rows: Dictionary = {}   # "port/usable" -> {shots, launched, reasons}
var evidence := {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("FLYER_PORTS " + reason)
	return ok

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for code: Key in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_Q,KEY_E,KEY_SHIFT,KEY_CTRL,KEY_SPACE]: key(code,false)

var _seen := {}
func collect() -> void:
	for row: Dictionary in host.tower_context.get("workbench_emitters",[]):
		if not row.has("usable"): continue
		var mark := "%s/%s/%s" % [str(row.tick),str(row.nozzle),str(row.sequence)]
		if _seen.has(mark): continue
		_seen[mark] = true
		var k := "%s/%s" % [row.nozzle,row.usable]
		var entry: Dictionary = rows.get(k,{"shots":0,"launched":0,"water":0,"solids":0,"reasons":{}})
		entry.shots += 1
		entry.launched += int(row.changed_cells)
		entry.water += int(row.get("water",0))
		entry.solids += int(row.get("solids",0))
		if not str(row.reason).is_empty(): entry.reasons[row.reason] = int(entry.reasons.get(row.reason,0)) + 1
		rows[k] = entry

func wait_for(predicate: Callable, timeout_ms: int = 30000) -> bool:
	var until := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < until:
		collect()
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return false

func ticks(count: int) -> bool:
	var target: int = host.physical_actor_session.tick + count
	return await wait_for(func() -> bool: return host.physical_actor_session.tick >= target)

func installed() -> bool:
	var receipt: Dictionary = host.tower_context.get("workbench_equipment",{})
	return not ui.applied.is_empty() and not ui.busy() and host.pending_microscenario_apply.is_empty() \
		and receipt.get("configured",false) and int(receipt.get("serial",-1)) == ui.equipment.serial

func launched(prefix: String) -> int:
	var total := 0
	for k: String in rows:
		if k.begins_with(prefix): total += int(rows[k].launched)
	return total

func test_ports() -> void:
	check(Setup.validate(Setup.kinetic_lab(PackedInt32Array([0]))).is_empty(),"kinetic-lab with loadout validates")
	var bad := Setup.kinetic_lab(PackedInt32Array([0]))
	bad.equipment.loadout = ["death_ray","",""]
	check(not Setup.validate(bad).is_empty(),"unknown port usable refused")
	if not check(ui.load_equipment_start(Setup.KINETIC_LAB_LABEL),"kinetic-lab requested"): return
	if not check(await wait_for(installed,90000),"kinetic-lab installed"): return
	check(host.physical_actor_session.workbench_loadout == {"q":"gravel_shotgun","e":"water_cannon","s":"blast_glove"},
		"loadout reached the actor session " + str(host.physical_actor_session.workbench_loadout))
	if not check(ui.select_instance(3) and ui.pilot_slot >= 0,"pilot the flyer"): return
	if not check(ui.toggle_pause() and await ticks(6) and not host._actor_input_rearm,"neutral rearm in play"): return
	var spray: Dictionary = host.tower_context.get("water_spray",{}).get("ledger",{}).duplicate()
	var solids: Dictionary = host.tower_context.get("ballistic_solids",{}).get("ledger",{}).duplicate()
	key(KEY_Q,true)
	await ticks(36)
	key(KEY_Q,false)
	key(KEY_E,true)
	await ticks(36)
	key(KEY_E,false)
	key(KEY_S,true)
	await ticks(36)
	release()
	await ticks(12)
	var spray_after: Dictionary = host.tower_context.get("water_spray",{}).get("ledger",{})
	var solids_after: Dictionary = host.tower_context.get("ballistic_solids",{}).get("ledger",{})
	evidence.rows = rows.duplicate(true)
	check(launched("q-left/gravel_shotgun") > 0,"Q fires the gravel shotgun (%s)" % str(rows.get("q-left/gravel_shotgun")))
	check(launched("e-right/water_cannon") > 0,"E fires the water cannon (%s)" % str(rows.get("e-right/water_cannon")))
	check(rows.has("s-rear/blast_glove"),"S uses the blast glove (%s)" % str(rows.get("s-rear/blast_glove")))
	check(int(solids_after.injected) - int(solids.get("injected",0)) >= launched("q-left/gravel_shotgun"),
		"every shotgun pellet is a native flying solid")
	check(int(spray_after.injected_parcels) - int(spray.get("injected_parcels",0)) == launched("e-right/water_cannon"),
		"every water-cannon shot is a native ballistic parcel")
	evidence.blast_launched = launched("s-rear/blast_glove")
	check(bool(host.tower_context.get("ballistic_solids",{}).get("closed",false)),"native flying-cell ledger closed")
	var water: Dictionary = host.tower_context.get("water_spray",{}).get("water",{})
	check(not water.is_empty() and int(water.total) == int(water.expected),"native Water ledger closed")
	# Rebinding a port live: Q back to the flyer's own dispenser.
	if not host.paused: ui.toggle_pause()
	check(ui.equipment.set_port(0,""),"Q rebound to the flyer default")
	await wait_for(installed)
	check(not host.physical_actor_session.workbench_loadout.has("q"),"rebinding reached the session")
	check(ui.applied.equipment.loadout[0] == "","rebinding is authored data")

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	ui = host.shared_workbench
	for id: String in KineticUsables.ORDER: check(KineticUsables.valid(id),"catalogue entry " + id)
	if check(await wait_for(func() -> bool: return not ui.applied.is_empty(),60000),"workbench installed"): await test_ports()
	release()
	print("FLYER_PORTS_EVIDENCE " + JSON.stringify(evidence))
	print("FLYER_PORTS %d checks, %d failures" % [checks, failures.size()])
	host.queue_free()
	await process_frame
	await process_frame
	quit(int(not failures.is_empty()))
