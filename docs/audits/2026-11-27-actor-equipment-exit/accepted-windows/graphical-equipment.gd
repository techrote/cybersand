extends "res://tests/capture_workbench_actor_sandbox.gd"

var equipment_frame_row := {}
var takeover_id := -1
var handback_id := -1
var start_ticks := Vector2i.ZERO
var end_ticks := Vector2i.ZERO

func run() -> void:
	output = OS.get_environment("WB_ACTOR_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var ok := await check_play()
	var old = weakref(host) if is_instance_valid(host) else null
	if is_instance_valid(host):
		host.queue_free()
	ui = null
	host = null
	await process_frame
	await process_frame
	ok = require(old != null and old.get_ref() == null, "Workbench scene failed to retire") and ok
	var data: Dictionary = {"pid": OS.get_process_id(), "ok": ok, "failure": failure,
		"renderer": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(),
		"start_ticks": [start_ticks.x, start_ticks.y], "end_ticks": [end_ticks.x, end_ticks.y],
		"takeover_id": takeover_id, "handback_id": handback_id, "retired": old != null and old.get_ref() == null,
		"equipment": equipment_frame_row, "captures": images}
	var f := FileAccess.open(output.path_join("graphical-equipment.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
	print("ACCEPTED_GRAPHICAL_EQUIPMENT ", JSON.stringify(data))
	quit(0 if ok else 1)

func check_play() -> bool:
	if not require(DisplayServer.get_name() != "headless", "Graphical Workbench required"):
		return false
	set_meta("cybersand_feature", "shared_workbench")
	root.size = Vector2i(1280, 960)
	root.gui_embed_subwindows = true
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty() and not host.shared_workbench.busy(), "Ordinary startup"):
		return false
	ui = host.shared_workbench
	if not await load_playground("mixed"):
		return false
	start_ticks = Vector2i(host.latest_snapshot.tick_index, host.physical_actor_session.tick)
	if not await mixed_interaction():
		return false
	if not require(ui.pilot_instance(5), "Physical stuntbuggy takeover refused"):
		return false
	takeover_id = ui.pilot_id()
	if not await progress(4,"Piloted rig and cells progress"):
		return false
	if not require(takeover_id == 5 and ui.hand_back_pilot(), "Pilot handback refused"):
		return false
	handback_id = ui.pilot_id()
	if not require(handback_id != 5, "Old pilot retains the control lease"):
		return false
	if not await paused():
		return false
	if not require(ui.apply_actor_equipment(2, 2), "Runner authored equipment refused: " + ui.message):
		return false
	if not await until(func() -> bool: return not ui.busy() and host._physical_terrain_ready and int(ui.actor(ui.applied,2).control.usable_index) == 2, "Re-equipped runner installed"):
		return false
	if not require(ui.toggle_pause(), "Re-equipped session cannot play"):
		return false
	if not await progress(8, "Re-equipped rig and material simulation advance"):
		return false
	var slot: int = host.physical_actor_session.slot_for_instance(2)
	for actor: Dictionary in host.physical_actor_session.equipment_frame().actors:
		if actor.actor_id == slot:
			equipment_frame_row = {"actor_id":actor.actor_id, "usable_index":actor.usable_index,
				"body_id":actor.body_id, "equipment_epoch":actor.equipment_epoch}
	if not require(equipment_frame_row.get("usable_index",-1) == 2 and int(equipment_frame_row.get("body_id",0)) > 0, "Equipment not mounted on admitted Rapier body"):
		return false
	end_ticks = Vector2i(host.latest_snapshot.tick_index, host.physical_actor_session.tick)
	return await capture("06-equipped-runner", "Admitted physical equipment in the mixed workshop after pilot handback and release.")
