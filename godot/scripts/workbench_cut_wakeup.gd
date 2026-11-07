extends RefCounted

# One main-thread continuation per request. Notifications carry no World, Node,
# RID or mutable reply. The deferred keepalive argument owns this latch in flight.
signal completed
var done: bool=false
var outcome: String=""
var serial: int=0
var generation: int=0

func resolve(reason: String, _keepalive: RefCounted=null) -> void:
	if done: return
	done=true;outcome=reason
	completed.emit()
