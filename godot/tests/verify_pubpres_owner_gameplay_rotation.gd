extends SceneTree

const Recorder = preload("res://scripts/workbench_owner_gameplay.gd")


func _initialize() -> void:
	var error := _check()
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	print("PUBPRES_OWNER_GAMEPLAY_ROTATION_OK")
	quit(0)


func _check() -> String:
	var recorder := Recorder.new()
	# This test creates only process-private files, independent of an owner profile.
	recorder._where = ProjectSettings.globalize_path("user://pubpres-recorder-test-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	recorder._identity = {"schema":Recorder.SCHEMA,"launch_receipt":"rotation-fixture"}
	var payload := "x".repeat(Recorder.SEGMENT_BYTES / 2)
	for serial in range(Recorder.SEGMENTS+2):
		recorder._queue.append([["rotation_fixture",serial,payload]])
	recorder._ending = true
	recorder._wake.post()
	recorder._write_loop()
	if recorder._next_sequence() != Recorder.SEGMENTS+2:
		return "A reopened recorder did not find the next segment sequence"
	for sequence in range(2,Recorder.SEGMENTS+2):
		var file := FileAccess.open(recorder._segment_path(sequence),FileAccess.READ)
		if file == null or file.get_length() > Recorder.SEGMENT_BYTES:
			return "A rotated segment is absent or exceeds the bound"
		var header: Dictionary = JSON.parse_string(file.get_line())
		var columns: Dictionary = JSON.parse_string(file.get_line())
		var row: Array = JSON.parse_string(file.get_line())
		if header.sequence != sequence or header.launch_receipt != "rotation-fixture" \
				or not columns.fields.has("body") or row[1] != sequence:
			return "A rotated segment lost its identity, fields or event"
		file.close()

	# A busy writer cannot block Main. Both types of discarded row are
	# accounted and close is retained even if the producer batch is full.
	recorder._ending = false
	var draw := ["draw",10,0,0,false,-1]
	for serial in range(Recorder.BATCH_ROWS): recorder._batch.append(draw)
	for serial in range(Recorder.QUEUE_BATCHES): recorder._queue.append([draw])
	recorder._append(["drop_a",20])
	recorder._append(["drop_b",21])
	if recorder._thread.start(recorder._write_loop) != OK: return "Could not start fixture writer"
	recorder.close()
	var final_file := FileAccess.open(recorder._segment_path(Recorder.SEGMENTS+2),FileAccess.READ)
	var events := []
	while final_file.get_position() < final_file.get_length():
		var value: Variant = JSON.parse_string(final_file.get_line())
		if value is Array: events.append(value)
	final_file.close()
	if events.size() < 2 or events[-1][0] != "close" or events[-2][0] != "loss" \
			or int(events[-2][1]) != 21 or int(events[-2][2]) != 20 \
			or events[-2][3].size() != 2 or int(events[-2][3].get("drop_a",-1)) != 1 \
			or int(events[-2][3].get("drop_b",-1)) != 1:
		return "Full-queue loss interval, counts or normal close were lost"
	for slot in range(Recorder.SEGMENTS):
		DirAccess.remove_absolute(recorder._segment_path(slot))
	DirAccess.remove_absolute(recorder._where)
	return ""
