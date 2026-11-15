extends RefCounted

# ENGINE-LAB-POSE-TRACE-001. Diagnostic-only, opt-in, no physics or camera
# authority. Record once at the actual Main overlay submission, never from a
# separate timer. No file IO, hashing or synchronous logging in the frame path.
const MAX_FRAMES: int = 12000
const MAX_BODIES: int = 32
const MAX_EVENTS: int = 32768
const SCHEMA: String = "cybersand-pose-trace-v1"

var active: bool = false
var _started_usec: int = 0
var _settings: Dictionary = {}
var _frames: Array[Dictionary] = []
var _dropped: int = 0
var _duplicate_frames: int = 0
var _last_process_frame: int = -1
var _previous_screen: Dictionary = {}
var _previous_source: Dictionary = {}
var _events: Array[Dictionary] = []
var _events_dropped: int = 0

static func xy(vector: Vector2) -> Array:
	return [vector.x,vector.y]


static func pose_json(value: Variant) -> Variant:
	if not value is Transform2D or not (value as Transform2D).is_finite():
		return null
	var pose: Transform2D = value
	return {"xy":xy(pose.origin),"radians":pose.get_rotation()}


# Both shader and overlay should address the same physical raster.
# A nonzero residual here implicates a spatial transform, independently of
# which sampled pose happens to have been selected for display.
static func projection(value: Variant, presented_origin: Vector2,
		content: Rect2, view: Vector2i, screen: Transform2D,
		shader_map: Transform2D) -> Variant:
	if not value is Transform2D or not (value as Transform2D).is_finite() \
			or view.x < 1 or view.y < 1 or not content.has_area():
		return null
	var at: Vector2 = (value as Transform2D).origin
	var overlay_local: Vector2 = content.position + (at-presented_origin) \
		* content.size / Vector2(view)
	var actual_screen: Vector2 = screen * overlay_local
	var shader_screen: Vector2 = shader_map * at
	var delta: Vector2 = actual_screen-shader_screen
	return {"overlay_px":xy(actual_screen),"shader_px":xy(shader_screen),
		"projection_residual_px":xy(delta),"residual_magnitude_px":delta.length()}


func begin(settings: Dictionary = {}) -> bool:
	if active: return false
	active = true
	_started_usec = Time.get_ticks_usec()
	_settings = settings.duplicate(true)
	_frames.clear()
	_dropped = 0
	_duplicate_frames = 0
	_last_process_frame = -1
	_previous_screen.clear()
	_previous_source.clear()
	_events.clear()
	_events_dropped = 0
	return true


# Actual completion/submission events, independent of graphical sampling.
# The main owner calls this; worker records are copied only at finish().
func observe_event(row: Dictionary) -> void:
	if not active: return
	if _events.size() >= MAX_EVENTS:
		_events_dropped += 1
		return
	row["type"] = "event"
	_events.append(row)


# Caller supplies copied JSON-compatible numbers/strings/dictionaries only.
# Never write during _process; discard when full with an explicit gap count.
func observe(row: Dictionary) -> void:
	if not active: return
	var process_frame: int = int(row.get("process_frame",-1))
	if process_frame <= _last_process_frame:
		_duplicate_frames += 1
		return
	_last_process_frame = process_frame
	if _frames.size() >= MAX_FRAMES:
		_dropped += 1
		return
	var sample: Dictionary = row
	sample["type"] = "frame"
	var bodies: Array = sample.get("bodies",[])
	for body: Dictionary in bodies:
		var slot: int = int(body.get("slot",-1))
		var source: String = str(body.get("source","hidden"))
		var screen: Variant = body.get("selected_screen",null)
		var previous: Variant = _previous_screen.get(slot,null)
		body["source_changed"] = _previous_source.has(slot) and _previous_source[slot] != source
		body["screen_step_px"] = [float(screen[0])-float(previous[0]),
			float(screen[1])-float(previous[1])] if screen is Array \
				and screen.size()==2 and previous is Array and previous.size()==2 else null
		if screen is Array and screen.size()==2: _previous_screen[slot] = screen
		else: _previous_screen.erase(slot)
		_previous_source[slot] = source
	_frames.append(sample)


func total_frames() -> int:
	return _frames.size()


func dropped_frames() -> int:
	return _dropped


func finish(worker_events: Dictionary = {}) -> Dictionary:
	if not active: return {"status":"inactive"}
	active = false
	var duration_usec: int = Time.get_ticks_usec()-_started_usec
	var stamp: String = Time.get_datetime_string_from_system().replace(":","-")
	var filename: String = "user://engine-lab-pose-"+stamp+"-"+str(_started_usec)+".jsonl"
	var file: FileAccess = FileAccess.open(filename,FileAccess.WRITE)
	var report: Dictionary = {"status":"saved","schema":SCHEMA,
		"frames":_frames.size(),"dropped":_dropped,"duplicates":_duplicate_frames,
		"elapsed_seconds":float(duration_usec)/1000000.0,
		"max_frames":MAX_FRAMES,"max_bodies":MAX_BODIES,
		"events":_events.size(),"events_dropped":_events_dropped,
		"max_events":MAX_EVENTS,
		"worker_events":worker_events.get("events",[]).size(),
		"worker_events_dropped":worker_events.get("dropped",0),
		"worker_event_capacity":worker_events.get("capacity",0)}
	if file == null:
		report.status = "write_error"
		report.error = FileAccess.get_open_error()
		return report
	var header: Dictionary = {"type":"header","schema":SCHEMA,
		"start_usec":_started_usec,"settings":_settings,
		"godot":Engine.get_version_info().get("string",""),
		"notice":"Opt-in diagnostic; samples actual overlay submissions, not GPU present timestamps"}
	file.store_line(JSON.stringify(header))
	for frame: Dictionary in _frames:
		file.store_line(JSON.stringify(frame))
	for event: Dictionary in _events:
		file.store_line(JSON.stringify(event))
	for event: Dictionary in worker_events.get("events",[]):
		event["type"] = "event"
		event["event"] = str(event.get("kind",event.get("event","worker")))
		if not event.has("time_usec"):
			event["time_usec"] = int(event.get("completed_usec",event.get("start_usec",0)))
		file.store_line(JSON.stringify(event))
	var footer: Dictionary = report.duplicate(true)
	footer.type = "summary"
	file.store_line(JSON.stringify(footer))
	file.close()
	report["path"] = ProjectSettings.globalize_path(filename)
	_frames.clear()
	_events.clear()
	_previous_screen.clear()
	_previous_source.clear()
	return report
