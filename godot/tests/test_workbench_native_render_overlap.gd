extends "res://tests/test_workbench_native_rendezvous.gd"

# Reuse the exact immutable sample/owner fixtures. This gate tests marker
# ownership and admission conditions; it is not a throughput measurement.
class HeldRendezvous extends "res://scripts/workbench_native_rendezvous.gd":
	var separate: bool = true
	var queued: Array[Callable] = []
	func _separate_render_thread() -> bool: return separate
	func _queue_render_marker(callback: Callable) -> void: queued.append(callback)
	func release_marker() -> void:
		var callback: Callable = queued.pop_front()
		callback.call()


class NativeQueueGate extends RefCounted:
	var entered := Semaphore.new()
	var resume := Semaphore.new()
	var cancel := Semaphore.new()
	var watcher := Thread.new()
	var expired: bool = false
	func watch() -> void:
		var deadline: int = Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline:
			if cancel.try_wait(): return
			OS.delay_msec(1)
		expired = true
		entered.post()
		resume.post()
	func begin() -> Error:
		var error: Error = watcher.start(watch.unbind(1).bind(self))
		if error != OK: return error
		# These callbacks invoke only native Semaphore methods. The bound
		# Variant leases retain their targets even across owner retirement.
		RenderingServer.call_on_render_thread(Rendezvous.retained_native_post(entered))
		RenderingServer.call_on_render_thread(resume.wait.unbind(1).bind(resume))
		entered.wait()
		return OK
	func end() -> void:
		resume.post()
		cancel.post()
		watcher.wait_to_finish()


func overlap_waiter(frame: int = 1) -> HeldRendezvous:
	var waiter := HeldRendezvous.new()
	waiter.begin_callback(frame,true)
	waiter.begin_callback(frame,true)
	return waiter


func weak_target_alive(reference: WeakRef) -> bool:
	# GDScript may retain the returned Ref in a temporary until this function
	# exits. Keep that observation out of the owner's retirement scope.
	return reference.get_ref() != null


func consume_single_post(reference: WeakRef) -> bool:
	var marker: Semaphore = reference.get_ref()
	return marker != null and marker.try_wait() and not marker.try_wait()


func native_callable_lifetime() -> WeakRef:
	var marker := Semaphore.new()
	var reference: WeakRef = weakref(marker)
	var callback: Callable = Rendezvous.retained_native_post(marker)
	marker = null
	check(weak_target_alive(reference) and callback.is_valid(),
		"native callable's bound Variant retains its Semaphore after local retirement")
	callback.call()
	check(consume_single_post(reference),
		"bind/unbind invokes native post with its default count exactly once")
	callback = Callable()
	# Construction and call-return temporaries can also retain references in
	# this VM frame. Return only WeakRef; the caller observes after all of the
	# producing frame's actual local ownership has ended.
	return reference


func marker_conditions() -> void:
	var calls: Array[int] = [0]
	var poll: Callable = func() -> Dictionary:
		calls[0] += 1
		return active(snapshot())
	var waiter := HeldRendezvous.new()
	waiter.separate = false
	waiter.begin_callback(1,true)
	waiter.begin_callback(1,true)
	var result: Dictionary = waiter.wait_for_sample(poll,expected)
	check(result.status == "render_unavailable" and calls[0] == 0 and result.sleeps == 0,
		"Safe rendering cannot add a render-overlap wait or mailbox poll")
	check(waiter.queued.is_empty() and waiter.deadline_usec == 0,
		"Safe rendering queues no marker and creates no wait budget")
	retain("safe-unavailable",result)

	waiter = HeldRendezvous.new()
	waiter.begin_callback(2,true)
	check(waiter.queued.size() == 1,"first scheduled callback enqueues one marker")
	result = waiter.wait_for_sample(poll,expected)
	check(result.status == "not_catchup" and calls[0] == 0 and result.sleeps == 0,
		"the first callback never gains a blocking wait")
	var old_id: int = waiter._render_marker.get_instance_id()
	waiter.release_marker()
	waiter.begin_callback(2,true)
	result = waiter.wait_for_sample(poll,expected)
	check(result.status == "render_complete" and calls[0] == 0 and result.sleeps == 0,
		"an already reached marker prevents polling or sleeping")
	waiter.begin_callback(2,true)
	result = waiter.wait_for_sample(poll,expected)
	check(result.status == "render_complete" and calls[0] == 0 and result.sleeps == 0,
		"consumed Semaphore readiness is latched for every later callback")
	check(waiter.queued.is_empty(),"later callbacks do not enqueue additional frame markers")
	retain("completed-marker-latched",result)
	waiter.begin_callback(3,true)
	check(waiter.queued.size() == 1 and waiter._render_marker.get_instance_id() != old_id,
		"a new process frame uses a distinct Semaphore without stale post counts")
	waiter.begin_callback(4,true)
	waiter.begin_callback(4,true)
	result = waiter.wait_for_sample(poll,expected)
	check(result.status == "render_marker_backlog" and waiter.queued.size() == 1 \
		and calls[0] == 0 and result.sleeps == 0,
		"unexpected frame advance cannot grow the outstanding marker queue")
	waiter.release_marker()
	waiter.begin_callback(4,true)
	result = waiter.wait_for_sample(poll,expected)
	check(result.status == "render_marker_backlog" and result.sleeps == 0,
		"an old frame's completed marker is not current-frame overlap authority")
	waiter.begin_callback(5,true)
	check(waiter.queued.size() == 1 and waiter._render_marker_frame == 5,
		"a later frame can retire the old marker and enqueue its own")
	waiter.release_marker()

	waiter = overlap_waiter(6)
	result = waiter.wait_for_sample(func() -> Dictionary:
		waiter.release_marker()
		return active(snapshot(5)),expected)
	check(result.status == "render_complete" and not result.has("snapshot") and result.sleeps == 0,
		"marker completion during mailbox observation ends overlap before admission or sleep")
	retain("marker-completes-during-poll",result)

	waiter = overlap_waiter(7)
	var publisher := Thread.new()
	var marker: Semaphore = waiter._render_marker
	check(publisher.start(func() -> void:
		OS.delay_usec(2500)
		marker.post()) == OK,"asynchronous native marker publisher starts")
	result = waiter.wait_for_sample(poll,expected)
	publisher.wait_to_finish()
	check(result.status == "render_complete" and result.sleeps > 0 and not result.has("snapshot"),
		"a newly reached marker stops the polling wait without fabricating a packet")
	check(result.requested_sleep_usec <= Rendezvous.MAX_RENDER_OVERLAP_WAIT_USEC,
		"marker polling requests no more than the finite overlap cap")
	retain("asynchronous-marker",result)
	# Discard the simulated queue's still-owned callback rather than posting
	# twice; the real RenderingServer queue invokes each callback exactly once.
	waiter.queued.clear()
	marker = null

	waiter = overlap_waiter(8)
	var mailbox := Mailbox.new()
	mailbox.value = active(snapshot())
	check(mailbox.change_after(active(snapshot(5)),2500) == OK,"asynchronous native completion starts")
	result = waiter.wait_for_sample(mailbox.poll,expected)
	mailbox.join()
	check(result.status == "ready" and result.snapshot == mailbox.value.snapshot \
		and result.render_marker_observed_complete_usec == 0,
		"only an exact native completion is granted while the render marker remains pending")
	retain("sample-during-render-overlap",result)
	var deadline: int = waiter.deadline_usec
	waiter.begin_callback(8,true)
	var next: Dictionary = expected.duplicate(); next.sample = 6
	result = waiter.wait_for_sample(mailbox.poll,next)
	check(result.status == "timeout" and waiter.deadline_usec == deadline,
		"success and later waits share the same finite frame deadline")
	check(result.frame_wait_usec >= 0 and result.requested_sleep_usec <= Rendezvous.MAX_RENDER_OVERLAP_WAIT_USEC,
		"overlap timeout retains its bounded requested sleep budget")
	retain("overlap-cap",result)
	waiter.begin_callback(8,true)
	result = waiter.wait_for_sample(mailbox.poll,next)
	check(result.status == "timeout" and result.polls == 0 and result.sleeps == 0,
		"an exhausted overlap frame cannot obtain another budget")
	waiter.release_marker()
	for item: Dictionary in [
		{"value":{"status":"retired"},"status":"retired"},
		{"value":{"status":"transition"},"status":"transition"},
		{"value":{"status":"active","epoch":8,"session":11,"snapshot":snapshot(5)},"status":"owner_changed"}]:
		waiter = overlap_waiter(9)
		mailbox.value = item.value
		result = waiter.wait_for_sample(mailbox.poll,expected)
		check(result.status == item.status and not result.has("snapshot") and result.sleeps == 0,
			"render overlap preserves immediate " + str(item.status) + " refusal")
		waiter.release_marker()


func queue_retiring_owner(mailbox: RefCounted) -> WeakRef:
	var waiter = Rendezvous.new()
	waiter.begin_callback(100,true)
	waiter.begin_callback(100,true)
	mailbox.value = active(snapshot())
	check(mailbox.change_after(active(snapshot(5)),2500) == OK,"native completion runs beside the held rendering owner")
	var result: Dictionary = waiter.wait_for_sample(mailbox.poll,expected)
	mailbox.join()
	check(result.status == "ready" and result.sleeps > 0 \
		and result.render_marker_observed_complete_usec == 0,
		"actual queued marker permits exact completion while prior render commands are held")
	retain("actual-queue-native-completion",result)
	var reference: WeakRef = weakref(waiter._render_marker)
	waiter = null
	return reference


func real_render_queue() -> void:
	if RenderingServer.is_on_render_thread():
		observations.append({"case":"actual-native-render-queue","executed":false,
			"reason":"Safe/headless server has no separate rendering owner; pure native-lease and marker checks still executed."})
		return
	var gate := NativeQueueGate.new()
	var begun: Error = gate.begin()
	check(begun == OK,"bounded native render-queue gate starts")
	if begun != OK: return
	var mailbox := Mailbox.new()
	# All marker/helper construction temporaries leave scope before this
	# assertion. Only RenderingServer's queued native Callable owns it now.
	var reference: WeakRef = queue_retiring_owner(mailbox)
	check(weak_target_alive(reference),"RenderingServer's native callable retains the marker after helper retirement")
	gate.end()
	RenderingServer.force_sync() # Test-only drain after the bounded gate has opened.
	check(not gate.expired,"native queue was released explicitly, not by the watchdog")
	check(not weak_target_alive(reference),"queued native marker is freed after its callback and owner retire")
	var waiter = Rendezvous.new()
	waiter.begin_callback(101,true)
	RenderingServer.force_sync() # Test-only completion proof, never production.
	waiter.begin_callback(101,true)
	var result: Dictionary = waiter.wait_for_sample(mailbox.poll,expected)
	check(result.status == "render_complete" and result.polls == 0 and result.sleeps == 0,
		"an actually completed render marker gives no wait or extra native admission")
	waiter.begin_callback(101,true)
	result = waiter.wait_for_sample(mailbox.poll,expected)
	check(result.status == "render_complete" and result.polls == 0,
		"actual marker consumption remains latched")
	observations.append({"case":"actual-native-render-queue","executed":true,
		"render_callbacks":"Native Semaphore.post/wait only; no GDScript or scene access on rendering owner.",
		"meaning":"FIFO rendering-command completion only; no GPU or scanout claim."})


func _run() -> void:
	var retired: WeakRef = native_callable_lifetime()
	check(not weak_target_alive(retired),"native callback and Semaphore retire after their ownership scope ends")
	marker_conditions()
	real_render_queue()
	var report := {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":checks,"failures":failures,"observations":observations,
		"separate_render_thread":not RenderingServer.is_on_render_thread(),
		"scope":"Native marker lifetime, queue ordering, finite wait and unchanged sample/owner fences; actual Main physical equivalence is a separate gate."}
	var output: String = OS.get_environment("CYBERSAND_NATIVE_RENDER_OVERLAP_OUTPUT")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ") + "\n")
	print("NATIVE_RENDER_OVERLAP_RESULT ",JSON.stringify(report))
	print("NATIVE_RENDER_OVERLAP: %d assertions, %d failures" % [checks,failures.size()])
	quit(int(not failures.is_empty()))
