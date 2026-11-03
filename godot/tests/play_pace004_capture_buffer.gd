extends RefCounted

# Only the existing production owner calls retain(). Main reads the copied
# receipt after join. Startup keeps one actual boundary packet, never an
# elapsed-time-sized history; every publication inside the measured window is
# retained in serial order under the unchanged explicit capacity.
const MAX_ROWS: int = 12000
var publications: Array[Dictionary] = []
var boundary: Dictionary = {}
var startup_publications: int = 0
var window_publications: int = 0
var after_window_publications: int = 0
var overflow: bool = false
var started_usec: int = 0
var ended_usec: int = 0


func retain(row: Dictionary, started: int, ended: int) -> bool:
	started_usec = started
	ended_usec = ended
	if started == 0 or int(row.published_usec) < started:
		startup_publications += 1
		boundary = row
		return false
	var completion_in_window: bool = bool(row.native_completed) \
		and int(row.completed_usec) >= started \
		and (ended == 0 or int(row.completed_usec) < ended)
	if ended > 0 and int(row.published_usec) >= ended and not completion_in_window:
		after_window_publications += 1
		return false
	if publications.is_empty() and not boundary.is_empty():
		publications.append(boundary)
		boundary = {}
	if publications.size() >= MAX_ROWS:
		overflow = true
		return false
	publications.append(row)
	window_publications += 1
	return completion_in_window


func report() -> Dictionary:
	return {"schema":"play-pace004-window-retention-v1", "started_usec":started_usec,
		"ended_usec":ended_usec, "startup_publications_observed":startup_publications,
		"startup_boundary_capacity":1, "window_capacity":MAX_ROWS,
		"retained_boundary_publications":publications.filter(func(row: Dictionary) -> bool:
			return int(row.published_usec) < started_usec).size(),
		"retained_window_publications":window_publications,
		"after_window_publications_observed":after_window_publications,
		"overflow":overflow, "read_after_owner_join":true}
