extends CyberSimulationWorker

# Benchmark-only observation at the native capture boundary. Never count a
# carried transport full_refresh flag as another native capture. The private
# mutex protects copied observations only; native ownership is unchanged.
const MAX_CAPTURE_SAMPLES := 50000
var _profile_mutex := Mutex.new()
var _profile_measuring := false
var _profile_counters := {"calls":0,"forced_full_requests":0,"nonempty_packets":0,
	"full_packets":0,"logical_bytes":0,"capture_usec":0}
var _profile_samples: Array[Dictionary] = []
var _profile_dropped := 0
var _profile_ack_mode := "normal"
var _profile_ack_queue: Array[Dictionary] = [] # Main-owned delivery queue.
var _profile_ack_requests: Array[Dictionary] = [] # Guarded copied observations.
var _profile_last_requested_ack := 0
var _profile_observed_ack := 0
var _profile_next_ack_observation := 0

func profile_owner_state() -> Dictionary:
	# Requested pause intent is distinct from a publication's local_paused:
	# an already prepared Workbench actor sample legitimately pauses one local
	# iteration while waiting for Main. Both fields below are mutex-owned.
	_mutex.lock()
	var result: Dictionary={"thread_running":_running,"requested_paused":_paused}
	_mutex.unlock()
	return result

func profile_begin(ack_mode: String = "normal") -> Dictionary:
	_profile_mutex.lock()
	_profile_samples.clear()
	_profile_dropped=0
	_profile_measuring=true
	_profile_ack_mode=ack_mode
	_profile_ack_requests.clear()
	_profile_ack_queue.clear()
	_profile_last_requested_ack=0
	_profile_next_ack_observation=0
	var result: Dictionary=_profile_counters.duplicate()
	_profile_mutex.unlock()
	return result

func profile_end() -> Dictionary:
	_profile_mutex.lock()
	_profile_measuring=false
	var result: Dictionary={"counters":_profile_counters.duplicate(),
		"samples":_profile_samples.duplicate(true),"dropped_samples":_profile_dropped,
		"ack":_profile_ack_snapshot_locked()}
	_profile_mutex.unlock()
	return result

func _profile_ack_snapshot_locked() -> Dictionary:
	return {"mode":_profile_ack_mode,"requested_delay_usec":150000 if _profile_ack_mode=="delayed150" else 0,
		"requests":_profile_ack_requests.duplicate(true),"queued":_profile_ack_queue.size(),
		"last_requested_serial":_profile_last_requested_ack,"observed_serial":_profile_observed_ack}

func profile_ack_snapshot() -> Dictionary:
	_profile_mutex.lock()
	var result: Dictionary=_profile_ack_snapshot_locked()
	_profile_mutex.unlock()
	return result

func acknowledge_render_snapshot(serial: int) -> void:
	if serial<=0: return
	var now:=Time.get_ticks_usec()
	_profile_mutex.lock()
	if not _profile_measuring and _profile_ack_mode=="normal":
		_profile_mutex.unlock()
		super.acknowledge_render_snapshot(serial)
		return
	if serial<=_profile_last_requested_ack:
		_profile_mutex.unlock()
		return
	_profile_last_requested_ack=serial
	var row: Dictionary={"serial":serial,"requested_usec":now,"delivered_usec":0,"observed_usec":0}
	if _profile_ack_requests.size()>=MAX_CAPTURE_SAMPLES:
		_profile_dropped+=1
		_profile_mutex.unlock()
		super.acknowledge_render_snapshot(serial)
		return # Invalid benchmark, bounded observation storage; never gate native.
	_profile_ack_requests.append(row)
	var immediate:=_profile_ack_mode=="normal"
	if immediate: row.delivered_usec=now
	else: _profile_ack_queue.append(row)
	_profile_mutex.unlock()
	if immediate: super.acknowledge_render_snapshot(serial)

func profile_pump_acknowledgements() -> void:
	# Called only by Main. Delays affect delivery after an accepted publication,
	# never the native capture loop or material acceptance itself.
	if _profile_ack_mode!="delayed150": return
	var now:=Time.get_ticks_usec()
	var serial:=0
	_profile_mutex.lock()
	while not _profile_ack_queue.is_empty() and now-int(_profile_ack_queue[0].requested_usec)>=150000:
		var row: Dictionary=_profile_ack_queue.pop_front()
		row.delivered_usec=now
		serial=maxi(serial,int(row.serial))
	_profile_mutex.unlock()
	if serial>0: super.acknowledge_render_snapshot(serial)

func profile_recover_acknowledgements() -> Dictionary:
	var now:=Time.get_ticks_usec()
	_profile_mutex.lock()
	var result: Dictionary={"started_usec":now,"queued_before":_profile_ack_queue.size(),
		"accepted_serial":_profile_last_requested_ack,"prior_mode":_profile_ack_mode}
	for row: Dictionary in _profile_ack_queue: row.delivered_usec=now
	_profile_ack_queue.clear()
	_profile_ack_mode="normal"
	var serial:=_profile_last_requested_ack
	_profile_mutex.unlock()
	if serial>0: super.acknowledge_render_snapshot(serial)
	return result

func _observe_render_acknowledgement(serial: int) -> void:
	var now:=Time.get_ticks_usec()
	_profile_mutex.lock()
	_profile_observed_ack=maxi(_profile_observed_ack,serial)
	# A monotonic ACK acknowledges its accepted prefix. Preserve the latency
	# of every original accepted request, including coalesced deliveries.
	while _profile_next_ack_observation<_profile_ack_requests.size():
		var row: Dictionary=_profile_ack_requests[_profile_next_ack_observation]
		if int(row.delivered_usec)==0 or int(row.serial)>serial: break
		row.observed_usec=now
		_profile_next_ack_observation+=1
	_profile_mutex.unlock()

func _take_native_render_snapshot(force_full: bool) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var packet: Dictionary=super._take_native_render_snapshot(force_full)
	var ended:=Time.get_ticks_usec()
	var cells: PackedByteArray=packet.get("cells",PackedByteArray())
	var rectangles: PackedInt32Array=packet.get("rectangles",PackedInt32Array())
	var nonempty:=not cells.is_empty() and not rectangles.is_empty()
	var full:=nonempty and bool(packet.get("full_refresh",false))
	_profile_mutex.lock()
	_profile_counters.calls+=1
	_profile_counters.forced_full_requests+=int(force_full)
	_profile_counters.nonempty_packets+=int(nonempty)
	_profile_counters.full_packets+=int(full)
	_profile_counters.logical_bytes+=cells.size()
	_profile_counters.capture_usec+=ended-started
	if _profile_measuring:
		if _profile_samples.size()<MAX_CAPTURE_SAMPLES:
			_profile_samples.append({"start_usec":started,"end_usec":ended,
				"capture_usec":ended-started,"forced_full":force_full,"nonempty":nonempty,
				"full_refresh":full,"status":packet.get("status",null),
				"native_serial":int(packet.get("serial",0)),"generation":_world_generation,
				"native_revision":int(packet.get("revision",-1)),
				"logical_bytes":cells.size(),"rectangles":rectangles.size()/6})
		else: _profile_dropped+=1
	_profile_mutex.unlock()
	return packet
