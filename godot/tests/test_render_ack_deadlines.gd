extends SceneTree

# Production Main ACK scheduler and real worker mailbox. The historical
# restart-on-upload control must starve under the same continuous stream.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("RENDER_ACK_DEADLINES: "+label)

func _stream(legacy: bool, delay: int) -> void:
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","legacy" if legacy else "")
	# Do not mount a scene or forge successful texture upload. This regression
	# exercises the ACK boundary given a sequence of accepted upload serials;
	# test_render_cadence_worker covers the real publication/ACK handshake.
	var host: Control = load("res://scripts/main.gd").new()
	host.engine_lab_set_ack_delay(delay)
	var observed_frames: Dictionary = {}
	var serial: int = 0
	var due: Array[Dictionary] = []
	var maximum_pending: int = 0
	for i: int in range(16):
		await process_frame
		host._engine_lab_pump_ack()
		var now: int = Engine.get_process_frames()
		observed_frames[now] = true
		var expected: int = 0
		for item: Dictionary in due:
			if int(item.frame) <= now: expected=maxi(expected,int(item.serial))
		if legacy:
			check(host._engine_lab_last_ack_serial==0,
				"legacy continuous uploads reproduce deadline starvation at %d" % i)
		else:
			check(host._engine_lab_last_ack_serial==expected,
				"accepted serial acknowledged at its original due frame: %d" % i)
		serial += 1
		host._engine_lab_ack_uploaded_snapshot(serial)
		due.append({"serial":serial,"frame":now+delay})
		# A second accepted upload in the same callback must not add an
		# unbounded bucket or ACK an unuploaded serial.
		serial += 1
		host._engine_lab_ack_uploaded_snapshot(serial)
		due.append({"serial":serial,"frame":now+delay})
		maximum_pending=maxi(maximum_pending,host._engine_lab_ack_queue.size())
		check(host._engine_lab_last_ack_serial<serial,
			"no acknowledgement precedes the requested delay")
	check(observed_frames.size()==16,"sixteen distinct real process-frame deadlines exercised")
	check(maximum_pending<=delay,"same-frame coalescing bounds pending storage")
	host.engine_lab_set_ack_delay(0)
	check(host._engine_lab_last_ack_serial==serial and host._engine_lab_ack_queue.is_empty(),
		"zero-delay setting flushes accepted serials and clears deadlines")
	check(host._engine_lab_pending_ack_serial==0,"flushed ACK has no pending serial")
	host.free()

func _run() -> void:
	var original: String=OS.get_environment("CYBERSAND_DIAG_RENDER_CADENCE")
	await _stream(true,3)
	await _stream(false,3)
	await _stream(false,4)
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE",original)
	print("RENDER_ACK_DEADLINES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
