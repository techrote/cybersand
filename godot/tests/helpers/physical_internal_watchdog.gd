extends RefCounted

# Fixture-only observer. No SceneTree/World/Rapier access or self-termination:
# the independent Python 45s idle guard/180s outer deadline captures before kill.
const LIMIT_MS: int = 120000
const POLL_MS: int = 10
const JOIN_MS: int = 1000
var _thread: Thread = Thread.new()
var _mutex: Mutex = Mutex.new()
var _case: String = ""
var _context: String = "not_published"
var _started_ms: int = 0
var _limit_ms: int = LIMIT_MS
var _stop_requested: bool = false
var _expired: bool = false
var _joined: bool = false

func start(name: String, limit_ms: int = LIMIT_MS) -> Error:
	if name.is_empty() or limit_ms < 1 or limit_ms > LIMIT_MS or _thread.is_started():
		return ERR_INVALID_PARAMETER
	_case = name
	_limit_ms = limit_ms
	_started_ms = Time.get_ticks_msec()
	return _thread.start(_observe)

func publish(value: String) -> void:
	_mutex.lock()
	_context = value.left(1024)
	_mutex.unlock()

func _observe() -> void:
	while true:
		_mutex.lock()
		var stopping: bool = _stop_requested
		var elapsed: int = Time.get_ticks_msec() - _started_ms
		var expired: bool = not stopping and elapsed >= _limit_ms
		if expired:
			_expired = true
		var copied_context: String = _context
		_mutex.unlock()
		if expired:
			printerr("ERROR: REGRESSION_WATCHDOG case=", _case, " limit_ms=", _limit_ms,
				" elapsed_ms=", elapsed, " last_main_progress=", copied_context)
			return
		if stopping:
			return
		OS.delay_msec(POLL_MS)

func stop() -> bool:
	_mutex.lock()
	# Completion racing expiry cannot turn an exceeded deadline into a pass.
	if Time.get_ticks_msec() - _started_ms >= _limit_ms:
		_expired = true
	_stop_requested = true
	var expired: bool = _expired
	_mutex.unlock()
	if _thread.is_started():
		var deadline: int = Time.get_ticks_msec() + JOIN_MS
		while _thread.is_alive() and Time.get_ticks_msec() < deadline:
			OS.delay_msec(1)
		if _thread.is_alive():
			printerr("ERROR: REGRESSION_WATCHDOG join_failed case=", _case)
			return false
		_thread.wait_to_finish()
	_joined = true
	if expired:
		printerr("ERROR: REGRESSION_WATCHDOG expired_at_completion case=", _case)
	return not expired

func joined() -> bool:
	return _joined
