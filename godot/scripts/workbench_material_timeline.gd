extends RefCounted
## Presentation-only delivery clock for the two textures actually uploaded.
## No requested Hz, World reads, physics mutation, prediction or growing queue.

const MIN_BLEND_USEC: int = 1000
const MAX_BLEND_USEC: int = 100000

var _current: Dictionary = {}
var _previous: Dictionary = {}
var _upload_interval_usec: int = 0
var _publication_interval_usec: int = 0
var _blend_duration_usec: int = 0
var _timing_source: String = "no_upload"


func reset() -> void:
	_current.clear()
	_previous.clear()
	_upload_interval_usec = 0
	_publication_interval_usec = 0
	_blend_duration_usec = 0
	_timing_source = "no_upload"


func accept_upload(generation: int, revision: int, serial: int, native_tick: int,
		generated_usec: int, native_completed_usec: int, uploaded_usec: int) -> bool:
	if generation < 0 or revision < 0 or serial < 0 or uploaded_usec <= 0:
		return false
	var same_world: bool = not _current.is_empty() and int(_current.generation) == generation
	if same_world and (serial <= int(_current.serial) or uploaded_usec <= int(_current.uploaded_usec)):
		return false
	# Unknown or cross-clock stamps remain unknown. They cannot lengthen a fade.
	if generated_usec <= 0 or generated_usec > uploaded_usec:
		generated_usec = -1
	if native_completed_usec <= 0 or generated_usec < 0 or native_completed_usec > generated_usec:
		native_completed_usec = -1
	_previous = _current if same_world else {}
	_current = {"generation":generation,"revision":revision,"serial":serial,
		"native_tick":native_tick,"generated_usec":generated_usec,
		"native_completed_usec":native_completed_usec,"uploaded_usec":uploaded_usec}
	_upload_interval_usec = 0
	_publication_interval_usec = 0
	_blend_duration_usec = 0
	_timing_source = "initial_upload" if not same_world else "upload_interval"
	# Never blend an old World into a replacement, or manufacture an interval
	# from a configured rate when there is only one accepted upload.
	if _previous.is_empty():
		return true
	_upload_interval_usec = uploaded_usec-int(_previous.uploaded_usec)
	var measured_interval: int = _upload_interval_usec
	if int(_previous.generated_usec) > 0 and generated_usec > int(_previous.generated_usec):
		_publication_interval_usec = generated_usec-int(_previous.generated_usec)
		# A delayed packet may arrive immediately before another one. Do not
		# replay the old producer gap as additional latency on the new upload.
		measured_interval = mini(measured_interval,_publication_interval_usec)
		_timing_source = "publication_and_upload"
	_blend_duration_usec = clampi(measured_interval,MIN_BLEND_USEC,MAX_BLEND_USEC)
	return true


func frame(now_usec: int, enabled: bool = true) -> Dictionary:
	var elapsed: int = maxi(0,now_usec-int(_current.get("uploaded_usec",now_usec)))
	var blend: float = 1.0
	if enabled and _blend_duration_usec > 0:
		blend = clampf(float(elapsed)/float(_blend_duration_usec),0.0,1.0)
	var generated: int = int(_current.get("generated_usec",-1))
	return {"snapshot_blend":blend,"previous_blend_active":blend < 1.0,
		"blend_duration_usec":_blend_duration_usec,
		"upload_interval_usec":_upload_interval_usec,
		"publication_interval_usec":_publication_interval_usec,
		"material_age_usec":maxi(0,now_usec-generated) if generated > 0 else -1,
		"upload_age_usec":elapsed if not _current.is_empty() else -1,
		"timing_source":_timing_source,"current":_current.duplicate(),
		"previous":_previous.duplicate()}
